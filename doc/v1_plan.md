# v1 开发计划

> 基于 [ux_design.md](./ux_design.md) 重构应用架构。
> v0 已跑通基础 CRUD，v1 聚焦于：目标-里程碑-习惯三层模型 + 引导式 onboarding + 一体两面导航。

---

## 一、v0 → v1 变化总览

| | v0 | v1 |
|------|------|------|
| **入口** | 空列表 + "定义你的身份" | 5 步 onboarding 引导 |
| **顶层概念** | 身份声明 → 习惯 | 目标 → 里程碑 → 行动计划 → 习惯 |
| **身份** | 用户手动填写 | 系统基于数据生成洞察（v1 后期实现） |
| **主页** | 单页面列表 | 左右滑动双面（习惯面 + 目标面） |
| **习惯结构** | 单行项 | 容器，内含多个行动项 + 两分钟安全阀 |
| **进度** | 7 天累计 | 里程碑级进度 + 目标级总进度 |
| **数据表** | identities / habits / logs / reviews | goals / milestones / action_plans / habits / habit_actions / logs / reviews |
| **架构分层** | Pages 直接调用 AppDatabase | Pages → Services → AppDatabase（前后端隔离） |

### 架构分层原则

> 即使当前纯 Dart 实现，页面前端与数据后端必须通过 Service 层隔离。后续 Go 替换后端时，仅替换 Service 实现，Pages 和 CLI 不改。

```
┌────────────────────────────────────────────┐
│  Pages (UI)                                │
│  habit_face_page, goal_face_page, ...      │
│  只 import services，不 import database    │
└────────────┬───────────────────────────────┘
             │ 调用接口，不关心实现
┌────────────┴───────────────────────────────┐
│  Services (业务逻辑)                        │
│  goal_service, milestone_service,          │
│  habit_service, review_service,            │
│  identity_service                          │
│                                            │
│  v1 实现：直接调用 AppDatabase (SQLite)      │
│  v3 实现：通过 HTTP/WebSocket 调用 Go 后端   │
└────────────┬───────────────────────────────┘
             │ 仅 Service 层调用
┌────────────┴───────────────────────────────┐
│  AppDatabase (数据访问)                     │
│  纯 SQLite CRUD，不含业务逻辑               │
└────────────────────────────────────────────┘
```

**约束**：
- `lib/pages/` 下的任何文件 **不 import `lib/db/database.dart`**
- `lib/pages/` 只 import `lib/services/` 下的 service 类
- 每个 service 类封装一个领域（GoalService / HabitService / ReviewService / MilestoneService）
- Service 类通过构造函数或 Provider 注入 AppDatabase 实例（不自行 new 单例）
- CLI Bridge 同样通过 Service 层操作，**不直接操作 AppDatabase**

---

## 二、数据层变更

### 2.1 新增表

```sql
-- 目标
CREATE TABLE goals (
    id      INTEGER PRIMARY KEY AUTOINCREMENT,
    name    TEXT NOT NULL,
    status  TEXT DEFAULT 'active',  -- active | completed | archived
    created TEXT DEFAULT (datetime('now'))
);

-- 里程碑
CREATE TABLE milestones (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    goal_id       INTEGER NOT NULL,
    name          TEXT NOT NULL,
    sort_order    INTEGER DEFAULT 0,
    status        TEXT DEFAULT 'waiting',  -- waiting | active | completed
    target_desc   TEXT,                    -- 可量化的目标描述
    current_value REAL,                    -- 当前进度值（手动更新）
    target_value  REAL,                    -- 目标值
    created       TEXT DEFAULT (datetime('now')),
    completed_at  TEXT,
    FOREIGN KEY (goal_id) REFERENCES goals(id)
);

-- 行动计划（属于里程碑的原始行为清单）
CREATE TABLE action_plans (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    milestone_id  INTEGER NOT NULL,
    name          TEXT NOT NULL,
    sort_order    INTEGER DEFAULT 0,
    created       TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (milestone_id) REFERENCES milestones(id)
);
```

### 2.2 修改现有表

```sql
-- habits 表：移除 identity_id/cue/plan_time/plan_place，新增 milestone_id/frequency/two_min_ver
-- 方案：删旧表重建（v0 数据量小，无需迁移）
DROP TABLE IF EXISTS habits;

CREATE TABLE habits (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    milestone_id  INTEGER NOT NULL,
    name          TEXT NOT NULL,
    frequency     TEXT DEFAULT 'daily',   -- daily | every_other | weekly | twice_week | custom
    frequency_desc TEXT,                  -- 自定义频率描述
    two_min_ver   TEXT,                   -- 两分钟安全阀
    archived      INTEGER DEFAULT 0,
    created       TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (milestone_id) REFERENCES milestones(id)
);

-- habit_actions：多对多关联表
CREATE TABLE habit_actions (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    habit_id       INTEGER NOT NULL,
    action_plan_id INTEGER NOT NULL,
    sort_order     INTEGER DEFAULT 0,
    FOREIGN KEY (habit_id) REFERENCES habits(id),
    FOREIGN KEY (action_plan_id) REFERENCES action_plans(id)
);
```

### 2.3 保留并修改

```sql
-- identities 表暂不删除，后续改造为 identity_insights（v1 后期）
```

```sql
-- reviews 表：增加 goal_id，支持按目标维度回顾
DROP TABLE IF EXISTS reviews;

CREATE TABLE reviews (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    goal_id   INTEGER,                          -- NULL 时为全局回顾
    week      TEXT NOT NULL,                    -- YYYY-Www
    notes     TEXT,
    created   TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (goal_id) REFERENCES goals(id),
    UNIQUE(goal_id, week)
);
```

```sql
-- logs 表：保留三态不变，新增 action_completions 字段
DROP TABLE IF EXISTS logs;

CREATE TABLE logs (
    id                 INTEGER PRIMARY KEY AUTOINCREMENT,
    habit_id           INTEGER NOT NULL,
    date               TEXT NOT NULL,            -- YYYY-MM-DD
    status             TEXT NOT NULL,            -- two_min | full | skipped
    action_completions TEXT,                     -- JSON: {action_plan_id: bool, ...}
    note               TEXT,
    created            TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (habit_id) REFERENCES habits(id),
    UNIQUE(habit_id, date)
);
```

### 2.4 新增表（v1 后期）

```sql
-- 身份洞察（系统生成，非用户创建）
CREATE TABLE identity_insights (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    goal_id       INTEGER,
    text          TEXT NOT NULL,           -- 建议的身份表述
    accepted      INTEGER DEFAULT 0,       -- 用户是否认可
    triggered_by  TEXT,                    -- 触发条件描述
    created       TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (goal_id) REFERENCES goals(id)
);
```

---

## 三、页面与路由变更

```
app_root（PageView，左右滑动）
├── goal_face_page            # 目标面（左）
│   ├── 目标进度总览
│   ├── 里程碑时间线
│   └── 系统诊断
│
└── habit_face_page           # 习惯面（右，默认）
    ├── 当前里程碑 + 进度条
    ├── 习惯卡片列表
    │   ├── 行动项勾选框
    │   ├── [全部完成] [只做两分钟] [跳过]
    │   └── 点击 → habit_detail_page
    └── [+ 添加习惯]

独立页面（push 进入）：
├── onboarding_flow           # 首次使用引导（5 步 PageView）
├── bootstrap_habit_page      # R2 过渡方案：最小可用习惯列表（R3 升级为 habit_face_page）
├── habit_create_page         # 创建习惯（从 action_plans 勾选）
├── habit_edit_page           # 编辑习惯（调整行动项、频率、安全阀，含行动计划维护）
├── habit_detail_page         # 习惯详情 + 累计数据 + 七天条 + 安全阀
├── milestone_plan_page       # 为里程碑设计/编辑行动计划
├── review_page               # 每周回顾（按目标维度）
└── goal_create_page          # 新增目标（含里程碑规划）
```

**路由表：**

| 路由 | 页面 | 参数 | 说明 |
|------|------|------|------|
| `/` | 两面板 PageView | — | 默认展示习惯面 |
| `/onboarding` | onboarding_flow | — | 首次启动 |
| `/create-goal` | goal_create_page | — | 新增目标 |
| `/milestone-plan` | milestone_plan_page | milestoneId | 卡片 3 |
| `/create-habit` | habit_create_page | milestoneId | 卡片 4 风格 |
| `/edit-habit` | habit_edit_page | habitId | 编辑习惯 |
| `/habit-detail` | habit_detail_page | habitId | 详情 |
| `/review` | review_page | — | 周回顾 |

---

## 四、开发轮次

### R1：数据层 + 模型类 + Service 层骨架
- 建立新表结构（goals / milestones / action_plans / habits / habit_actions / logs）
- 创建对应 Dart 模型类（toMap / fromMap / copyWith）
- 重写 `database.dart` 的 CRUD 方法（按目标-里程碑-习惯三层组织查询）
- **创建 Service 层骨架**（前后端隔离的契约）：
  - `GoalService`：目标 CRUD + 查询（封装 `AppDatabase` 的 goals/milestones 方法）
  - `HabitService`：习惯 CRUD + 频率判定 + 执行/跳过/日志查询（封装 habits/habit_actions/action_plans/logs 方法）
  - `ReviewService`：回顾保存/查询（封装 reviews 方法）
  - 每个 Service 接受 `AppDatabase` 构造函数参数（可注入，可替换）
  - Pages 层只调 Service，不碰 AppDatabase
- 更新 `main.dart` 初始化逻辑（建新表 + 实例化 Services + preferences 存储 first_launch 标志 + CLI 服务启动）
- **数据库迁移策略**：
  - 启动时检测数据库版本（在 preferences 存 `db_version` 键）
  - 如果版本 < 1（v0 残留）→ 重命名旧文件为 `atoms_v0_backup.db`，用新 schema 建库
  - 如果版本 ≥ 1 → 正常打开
  - 如果旧文件不存在 → 首次创建，标记 `db_version = 1`
  - 数据库操作包裹在 `openDatabase` 的 `onCreate`/`onUpgrade` 回调中

**产出：**
- `lib/models/goal.dart`
- `lib/models/milestone.dart`
- `lib/models/action_plan.dart`
- `lib/models/habit.dart`（v1 版本）
- `lib/models/log_entry.dart`（v1 版本，新增 action_completions）
- `lib/models/review.dart`（v1 版本，新增 goal_id）
- `lib/db/database.dart`（v1 版本）
- `lib/services/goal_service.dart`（封装目标+里程碑+行动计划的 CRUD）
- `lib/services/habit_service.dart`（封装习惯+行动关联+日志的 CRUD，含频率判定）
- `lib/services/review_service.dart`（封装回顾的 CRUD）
- 所有模型通过静态分析；Pages 层不 import database.dart

### R2：Onboarding 演示流程（用预设数据走通全流程）

**设计理念**：不让用户在 onboarding 中边想边填。用一个预设好的完整示例（"完成双力臂"），让用户**看完**整个目标-里程碑-行动计划-习惯的链条，理解这套方法论之后，再引导他创建自己的目标。

#### 5 步演示卡片

每张卡片展示预设数据，用户只需"下一步"，不需要输入。

##### 卡片 1：目标

```
┌──────────────────────────────────────┐
│                                      │
│    一切从你想达成的结果开始。          │
│                                      │
│    ╔══════════════════════════════╗  │
│    ║    完成双力臂                  ║  │
│    ╚══════════════════════════════╝  │
│                                      │
│    比如可以是一个具体的成果：        │
│    · 减掉 10 公斤                   │
│    · 完成一个双力臂                 │
│    · 读完 20 本书                   │
│                                      │
│    [ 跳过演示，我自己来 ]            │
│              [ 下一步 → ]            │
└──────────────────────────────────────┘
```

- "跳过演示" → 直接跳到一个简化版创建流程（自己填目标）
- 这一步告诉用户：**出发点是目标，不是习惯**

##### 卡片 2：里程碑

```
┌──────────────────────────────────────┐
│                                      │
│    然后拆成阶段性关口。               │
│    每过一个，你就前进一截。           │
│                                      │
│    ● ① 完成 1 个引体向上             │
│    │                                 │
│    ○ ② 完成 10 个标准引体            │
│    │                                 │
│    ○ ③ 完成 10 个变体引体            │
│    │                                 │
│    ○ ④ 完成 1 个双力臂               │
│                                      │
│    第一个自动激活，                         │
│    后面的达标后才解锁。               │
│                                      │
│            [ 上一步 ]  [ 下一步 → ]  │
└──────────────────────────────────────┘
```

- 展示里程碑的链式结构
- 演示状态：active / waiting

##### 卡片 3：行动计划

```
┌──────────────────────────────────────┐
│                                      │
│    针对第一个关口                     │
│    "完成 1 个引体向上"                │
│    列出所有需要做的行为。             │
│                                      │
│    · 负重悬吊 30秒                   │
│    · 弹力带辅助引体 5×3             │
│    · 离心引体下降 5×3                │
│    · 拉伸 30秒                       │
│    · 平板支撑 60秒                   │
│    · 死虫式 3×10                     │
│                                      │
│    先列出来，不急打包。               │
│                                      │
│            [ 上一步 ]  [ 下一步 → ]  │
└──────────────────────────────────────┘
```

- 强调"罗列"而非"组织"
- 这一步是思考层，不是执行层

##### 卡片 4：打包成习惯 + 两分钟安全阀

```
┌──────────────────────────────────────┐
│                                      │
│    把这些行动按频率组织成习惯。        │
│                                      │
│    ┌─ 练背计划 · 每两天 ─────────┐  │
│    │ ☑ 负重悬吊 30秒              │  │
│    │ ☑ 弹力带辅助引体 5×3        │  │
│    │ ☑ 离心引体下降 5×3           │  │
│    │ ☑ 拉伸 30秒                  │  │
│    │                              │  │
│    │ 如果太累：挂上单杠 30秒       │  │
│    └──────────────────────────────┘  │
│                                      │
│    ┌─ 核心训练 · 每周两次 ─────────┐  │
│    │ ☑ 平板支撑 60秒              │  │
│    │ ☑ 死虫式 3×10                │  │
│    └──────────────────────────────┘  │
│                                      │
│    还有安全阀：不想动时也有退路。      │
│                                      │
│            [ 上一步 ]  [ 下一步 → ]  │
└──────────────────────────────────────┘
```

- 展示"行动项 → 习惯容器"的组织过程
- 展示两分钟安全阀的位置和意义

##### 卡片 5：开始使用

```
┌──────────────────────────────────────┐
│                                      │
│    这套演示数据已经存好了。           │
│                                      │
│    你现在有两个选择：                 │
│                                      │
│    ┌────────────────────────────┐    │
│    │  先玩一遍演示目标            │    │
│    │  用预设的"双力臂"体验几天    │    │
│    │  感受打勾、看进度、做回顾    │    │
│    └────────────────────────────┘    │
│                                      │
│    ┌────────────────────────────┐    │
│    │  创建我自己的目标            │    │
│    │  走一遍刚才的流程            │    │
│    │  设定属于我的目标            │    │
│    └────────────────────────────┘    │
│                                      │
│    两个都可以，随时切换。             │
│                                      │
└──────────────────────────────────────┘
```

- **"先玩演示目标"** → 用预设数据进入主界面，用户可以直接开始打卡、看进度、做回顾，完整体验
- **"创建我自己的"** → 立即走一遍同样的流程，但这次是自己填内容
- 用户后续随时可以从主界面新建目标

#### 预设演示数据

```
goal: "完成双力臂"
  └── milestones:
      ├── "完成 1 个引体向上" [active]
      │   ├── action_plans: 负重悬吊 30秒, 弹力带辅助引体 5×3, 
      │   │                离心引体下降 5×3, 拉伸 30秒, 平板支撑 60秒, 死虫式 3×10
      │   └── habits:
      │       ├── "练背计划" (每两天) → 悬吊, 辅助引体, 离心下降, 拉伸
      │       │   two_min_ver: "挂上单杠 30秒"
      │       └── "核心训练" (每周两次) → 平板支撑, 死虫式
      │           two_min_ver: "平板支撑 20秒"
      │
      ├── "完成 10 个标准引体" [waiting]
      ├── "完成 10 个变体引体" [waiting]
      └── "完成 1 个双力臂" [waiting]
```

#### 实现要点

- 演示数据在**用户点击"先玩演示目标"时**调用数据库写入，而非 onboarding 完成时
- 选"创建我自己的"不写演示数据，直接进入 goal_create_page
- 写入使用数据库事务（transaction），goals → milestones → action_plans → habits → habit_actions 一条失败则全部回滚
- 用户可以像操作自己的目标一样操作演示目标（打卡、推进里程碑、归档）
- 数据库加入 `is_demo` 标记字段（可选），方便后续清理或区分
- **过渡方案**：
  - "先玩演示目标"进入 `bootstrap_habit_page.dart`：一个**最小可用**的习惯列表页
    - 顶部：当前活跃里程碑名称
    - 中间：习惯卡片列表，展示行动项 + 三个按钮（全部完成/只做两分钟/跳过）
    - 没有 PageView、没有目标面、没有频率引擎——就是能打卡的纯列表
  - R3 开发时，将 `bootstrap_habit_page.dart` 的核心 widget 提取到 `habit_face_page.dart`，
    外层包裹 PageView 容器 + 目标面 + 频率引擎。不丢代码，是渐进升级

#### 子任务：goal_create_page（用户自建目标流程）

与 onboarding 演示结构相同，但字段由用户填写：

```
goal_create_page（4 步 PageView）
  Step 1：输入目标名称
  Step 2：添加里程碑列表
  Step 3：为第一个里程碑列行动计划（逐条输入）
  Step 4：从行动计划勾选打包成习惯（命名 + 频率 + 安全阀）
  → 写入数据库 → 跳转主界面
```

- 与 onboarding 复用相同的卡片 UI 布局，仅将"预设展示"改为"可输入"
- 后续从主界面 `/create-goal` 进入同一页面

**产出：**
- `lib/pages/onboarding_page.dart`（5 步演示 + 跳转逻辑）
- `lib/pages/bootstrap_habit_page.dart`（R2 过渡：最小可用习惯列表，R3 升级为 habit_face_page）
- `lib/pages/goal_create_page.dart`（用户自建目标的 4 步交互版本）
- `lib/data/demo_data.dart`（预设数据工厂方法）
- 首次启动可走完演示 → 选择路径 → 进入主界面

### R3：一体两面主框架
- 实现基于 PageView 的两面滑动导航
- **习惯面（默认）**：
  - 顶部：目标选择器（多个目标时下拉切换） + 当前活跃里程碑名称 + 进度
  - 习惯卡片列表，按 milestone 分组
  - **频率判定引擎**：根据 habits.frequency + 上次 logs 日期，判定今天是否应该展示该习惯。非训练日习惯灰色显示（保留位置但不激活，降低认知负载）
  - 空状态引导文案
- **目标面（左滑）**：
  - 目标名称 + 总进度条
  - 里程碑时间线（竖向）
  - 各里程碑状态标识（waiting / active / completed）
  - 基础系统诊断文本
- 顶部 AppBar 共用，含目标选择器和回顾入口按钮
- FAB 根据当前面切换行为（习惯面→创建习惯，目标面→创建新目标）

#### 子任务：目标选择与切换机制

- 习惯面顶部显示当前活跃目标名称
- 多个目标时，点击可下拉选择切换
- 切换目标后，习惯面和目标面数据联动刷新
- 首次启动单目标时不下拉（只有一个选项，显示名称即可）

#### 子任务：习惯频率判定引擎

- 输入：habit.frequency + 上次执行日期（查 logs 最新 full/two_min 记录）
- 计算：根据 frequency 值判定今天是否应该执行
  - `daily` → 每天
  - `every_other` → 隔天（距上次执行 ≥ 1 天）
  - `weekly` / `twice_week` → 按自然周计算目标次数
  - `custom` → 根据 frequency_desc 手动判定（v1 简化：视为 daily）
- 非训练日习惯：灰色显示，勾选框禁用，不展示 [全部完成] 按钮，仅展示 [跳过]
- 频率引擎封装为独立函数，方便后续扩展

**产出：**
- `lib/pages/habit_face_page.dart`
- `lib/pages/goal_face_page.dart`
- `lib/pages/main_page.dart`（PageView 容器）
- `lib/services/frequency_service.dart`（频率判定引擎）
- `lib/app.dart` 更新路由

### R4：习惯创建与执行
- 实现卡片 4 风格的习惯创建页：
  - 习惯名称 + 频率选择
  - 从当前里程碑的 action_plans 勾选
  - 两分钟安全阀输入
- 习惯编辑页（调整行动项关联、频率、安全阀、删除/归档）
- 习惯执行流程：
  - 逐项勾选行动项
  - [全部完成] 按钮 → 全打勾，status = full
  - [只做两分钟] 按钮 → 卡片折叠为安全阀文本 + 一键确认，status = two_min；确认后弹窗提示升级
  - [跳过今天] 按钮 → status = skipped
- 累计算法：不追踪连续天数，追踪习惯执行总次数
- habit_detail_page 内容：
  - 习惯信息区：名称、频率、所属里程碑、两分钟安全阀文本（可编辑入口）
  - 关联行动项列表（展示当前关联的 action_plans）
  - 累计完成次数（total completed count）
  - 最近 7 天执行条（彩色圆点，复用 v0 的七日条逻辑）
  - "绝不连续错过两次"状态（橙色/绿色指示）
  - 快速操作：归档/取消归档

#### 子任务：行动计划后期维护

- 习惯编辑页 (`habit_edit_page`) 增加：
  - **从当前里程碑的 action_plans 池中勾选/取消**（与创建时相同的交互）
  - **直接新建行动项**（单行输入 → 写入 action_plans 表 → 自动关联到当前习惯）
  - 调整行动项 sort_order（拖拽或上下箭头）
- 存量里程碑也可进入 `milestone_plan_page` 补充计划（目标面点击里程碑 → 编辑计划）

**产出：**
- `lib/pages/habit_create_page.dart`（v1 版本）
- `lib/pages/habit_edit_page.dart`
- 习惯面交互完整可用

### R5：里程碑推进与目标追踪
- 里程碑状态机：
  - 同一目标下，第一个里程碑初始为 active，其余 waiting
  - 当前里程碑标记为 completed 时，下一个自动变为 active
  - 所有里程碑 completed → 目标自动变为 completed
- 手动更新里程碑进度（如 current_value 更新，在目标面点击进行中里程碑触发）
- 目标面完整数据展示
- "绝不连续错过两次"规则：
  - 按习惯逐条判定，**由频率引擎参与计算**（复用 R3 的 `frequency_service.dart`）
  - 只计算该习惯**应执行的日子**：休息日不算"错过"，不参与判定
  - 昨日应执行但未执行 + 今日应执行但未执行 → 目标面显示橙色警告
  - 不强制阻止，纯提示

#### 子任务：里程碑编辑

- 目标面长按里程碑弹出操作菜单：重命名 / 重排（上移/下移）/ 删除
- 重排后 sort_order 自动更新
- 删除已完成的里程碑需二次确认，关联的 action_plans 和 habits 保留（数据不丢，习惯改为关联到目标或归档）
- 新增里程碑（在目标面底部 [+ 添加里程碑]）

**产出：**
- `lib/services/milestone_service.dart`（状态机逻辑 + 里程碑 CRUD）
- 目标面数据联动

### R6：每周回顾适配
- 基于新数据模型更新回顾页：
  - **按目标维度保存**：reviews 表新增 `goal_id` 字段，每个目标有独立的回顾记录
  - 用户在回顾页选择回顾哪个目标（下拉切换），或选择"全部目标"全局视角
  - 按里程碑分组展示本周习惯完成率
  - 7 天彩色圆点条
  - 保持引导式反思问题
- 支持保存和查看历史回顾记录（按目标筛选）

**产出：**
- `lib/pages/review_page.dart`（v1 版本）
- 回顾数据正确关联到新模型

### R7：身份洞察系统（v1 后期）
- 触发条件：某个习惯累计完成 ≥ 15 次 且 ≥ 3 周
- 基于目标名称和习惯完成数据生成身份建议文本
- 身份认可/修改/忽略交互
- 认可后主界面顶部显示身份标签
- 新建习惯时引用身份作为提示

**产出：**
- `lib/services/identity_service.dart`
- `lib/widgets/identity_insight_dialog.dart`
- 身份数据存入 identity_insights 表

### R8：清理与打磨
- 移除 v0 遗留：identity_page、旧的 habit_create_page 等不再使用的文件
- 处理 identities 表（若不再需要则改为 identity_insights）
- 空状态、加载态、错误态补充
- 交互反馈（触觉、动画、snackbar）
- 代码整理：按 service / model / page 目录分层

---

## 五、不做的（延后到 v2+）

| 项 | 原因 |
|------|------|
| 里程碑模板推荐 | 需要数据积累，v2 再做 |
| 自动进度推算（习惯→里程碑） | 算法复杂，先手动更新 |
| 身份反哺新增习惯的引导面板 | 等身份系统跑通后再设计 |
| fl_chart 图表 | 数据量不足，里程碑时间线已够用 |
| Android 适配 | 桌面端验证后再做 |
| 同步 / 后端 | v3 |
| 环境设计画布 / 合约 / 群体 | v3 |

---

## 六、文件变更清单

### 新增文件

```
lib/models/goal.dart
lib/models/milestone.dart
lib/models/action_plan.dart
lib/models/identity_insight.dart          # R7

lib/data/demo_data.dart                   # R2 — 演示数据工厂

lib/services/goal_service.dart            # R1 — 目标/里程碑/行动计划业务逻辑（前后端隔离层）
lib/services/habit_service.dart           # R1 — 习惯/日志业务逻辑（前后端隔离层）
lib/services/review_service.dart          # R1 — 回顾业务逻辑（前后端隔离层）
lib/services/frequency_service.dart       # R3 — 习惯频率判定引擎（独立于 habit_service）
lib/services/milestone_service.dart       # R5
lib/services/identity_service.dart        # R7
lib/services/cli_service.dart             # R1 起 — CLI Bridge TCP 服务

lib/pages/onboarding_page.dart            # R2
lib/pages/bootstrap_habit_page.dart        # R2 — 过渡方案：最小可用习惯列表（R3 升级）
lib/pages/goal_create_page.dart           # R2 — 用户自建目标流程
lib/pages/main_page.dart                  # R3
lib/pages/habit_face_page.dart            # R3
lib/pages/goal_face_page.dart             # R3
lib/pages/habit_edit_page.dart            # R4
lib/pages/milestone_plan_page.dart        # R5 附属

lib/widgets/identity_insight_dialog.dart   # R7
```

### 修改文件

```
lib/main.dart                  # R1 — 初始化逻辑重写（新表 + first_launch + CLI 服务启动）
lib/db/database.dart           # R1 — 整套重写
lib/models/habit.dart          # R1 — 字段大幅变更
lib/models/log_entry.dart      # R1 — 新增 action_completions 字段
lib/models/review.dart         # R1 — 新增 goal_id 字段
lib/app.dart                   # R3 — 路由表更新

lib/pages/habit_create_page.dart  # R4 — 重写
lib/pages/habit_detail_page.dart  # R4 附属 — 适配新模型
lib/pages/review_page.dart        # R6 — 适配新模型
```

### 删除文件

```
lib/models/identity.dart      # R8 — 替换为 identity_insight
lib/pages/identity_page.dart  # R8 — 融入 onboarding
```

---

## 七、轮次验收条件

> "编译通过"不是验收。每轮必须通过下面列出的**可执行验证**才算完成。

### R1 验收：数据层 + 分层隔离

- [ ] **建库正确**：首次启动后，atoms.db 中存在 7 张表，结构与 DDL 一致
- [ ] **CRUD 闭环**：通过 Service 方法写入 goal → 查出来 → 改 status → 再查 → 删掉 → 不再存在
- [ ] **分层隔离**：`grep -r "database.dart" lib/pages/` 返回空（Pages 层不碰数据库）
- [ ] **依赖注入**：Services 接受 AppDatabase 构造函数参数，不内部 new 单例；可 mock 测试
- [ ] **迁移生效**：旧 atoms.db 存在时备份；不存在时创建新库；db_version 存入 preferences
- [ ] **演示数据工厂走 Service 层**：调用 `insertDemoData()` 不绕过 Services，写入后 7 张表数据完整

### R2 验收：Onboarding + 引导流程

- [ ] **5 步卡片顺序正确**：卡片 1→2→3→4→5 均可独立展示，前进/后退不丢状态
- [ ] **跳过演示**：卡片 1 点"跳过演示" → 进入 goal_create_page，里程碑/行动计划/习惯均可新建
- [ ] **演示数据只在点按钮时写入**：卡片 5 不自动写库；点"先玩演示目标"后 DB 中确有数据；点"创建自己的"后 DB 中无演示数据
- [ ] **写入事务**：演示数据写入中途模拟崩溃（手动断点） → DB 无脏数据残留
- [ ] **自建目标完整路径**：从卡片 5 →"创建自己的"→ 输入目标名 → 加 2 条里程碑 → 加 3 条行动 → 打包 1 个习惯 → 数据入库 → 进入主界面
- [ ] **first_launch 标志**：走完 onboarding 后重启应用不再触发演示

### R3 验收：一体两面主框架

- [ ] **左右滑动**：习惯面为默认；左滑到目标面；右滑回习惯面；过渡动画流畅无闪烁
- [ ] **数据联动**：同一时刻习惯面和目标面展示同一目标的数据（改目标选择器，两面同步刷新）
- [ ] **目标切换**：多目标时下拉可切换；切目标后两面数据更新；单目标时不显示下拉（仅展示名称）
- [ ] **频率判定正确**（至少换 3 个不同日期验证）：
  - daily 习惯：每天都展示，勾选框激活
  - every_other 习惯：执行日后一天灰色、不可勾选；再下一天激活
  - weekly 习惯：本周未执行时激活；已执行满目标次数后灰色
- [ ] **空状态**：无目标时习惯面/目标面不崩溃，显示引导文案而非白屏
- [ ] **FAB 行为**：习惯面点 FAB → 创建习惯（传入当前 milestoneId）；目标面点 FAB → 创建新目标

### R4 验收：习惯创建与执行

- [ ] **创建习惯**：输入名称 + 选频率 + 从 action_plans 勾选 + 输入安全阀 → 入库后习惯面出现新卡片
- [ ] **逐项打勾**：点击单个行动项 → 仅该项打勾；同一卡片其他行动项不变；不可在当日取消已完成项
- [ ] **全部完成**：点 [全部完成] → 所有行动项打勾 → 弹出确认 toast → logs 写入 status=full，action_completions 全 true
- [ ] **只做两分钟**：点 [只做两分钟] → 卡片折叠为安全阀文本 + 一键确认 → logs 写入 status=two_min → **立即弹升级对话框**；点了"继续完整版"后 status 变为 full；点"今天就到这里"不变
- [ ] **跳过今天**：点 [跳过] → 二次确认 → logs 写入 status=skipped → 习惯卡片灰色 + 删除线
- [ ] **累计次数正确**：连续 3 天执行 full → 查数据库 getTotalCompletedCount() = 3；混入 1 天 two_min → = 4；混入 skipped 不算
- [ ] **编辑习惯**：habit_edit_page 可改名称/频率/安全阀；可从 action_plans 池加/删行动项；可新建行动项写入 action_plans 表；可拖拽调整行动项排序
- [ ] **habit_detail_page**：展示名称/频率/里程碑/安全阀/行动项/累计次数/七天条/不连续错过状态；归档按钮可用

### R5 验收：里程碑与目标追踪

- [ ] **里程碑状态机**：
  - 同一目标下第 1 个里程碑初始 active，其余 waiting
  - 标记第 1 个为 completed → 第 2 个自动变 active
  - 全部 completed → 目标 status 变 completed
- [ ] **手动更新进度**：点进行中里程碑 → 弹输入框 → 改 current_value → 目标面进度条更新
- [ ] **里程碑编辑**：长按 → 可重命名/上移/下移/删除；排序持久化；删除已完成里程碑二次确认
- [ ] **绝不连续错过两次**：
  - 昨天的执行日 skipped + 今天的执行日未执行 → 目标面出现橙色警告
  - daily 习惯连续两天 skipped → 触发
  - every_other 习惯：执行日 A skipped + 下一个执行日 B skipped → 触发；中间休息日不参与判定
  - 触发后如果当天补上了（two_min 或 full）→ 警告消失
- [ ] **目标面诊断**：完成率 < 50% 的习惯显示异常提示；完成率 ≥ 80% 的习惯显示正向反馈

### R6 验收：每周回顾

- [ ] **按目标维度**：回顾页顶部可切换目标（下拉）；切换后数据刷新；有"全部目标"选项
- [ ] **正确统计**：本周 daily 习惯应出现 7 天 → 展示 7 次；every_other 习惯应出现 3-4 天 → 展示对应次数
- [ ] **七日条正确**：彩色圆点与 logs 数据一一对应（green=full, orange=two_min, grey=skipped, hollow=未执行）
- [ ] **反思保存**：3 个问题填写后点保存 → reviews 表写入 goal_id + week + notes；下次进入该周可回读
- [ ] **历史回顾**：可查看过去周的回顾记录，内容只读

### R7 验收：身份洞察

- [ ] **触发条件正确**：某习惯 full/two_min 累计 ≥ 15 次 且首次记录距今 ≥ 21 天 → 触发；不足时不触发
- [ ] **弹窗内容**：mention 习惯名称 + 累计数据 + 身份建议文本 → 三个按钮可用
- [ ] **认可**：点[认可] → identity_insights 表写入 accepted=1 → 主界面顶部出现身份标签
- [ ] **修改**：点[换一个说法] → 弹输入框 → 修改后写入
- [ ] **忽略**：点[暂时不要] → 不写入；下次满足条件可再次触发
- [ ] **已认领的身份不再重复触发**

### R8 验收：清理与打磨

- [ ] **v0 遗留文件已删除**：identity.dart / identity_page.dart 不再存在；import 路径无残留引用
- [ ] **数据库表清洁**：identities 表已删除；identity_insights 表存在且正确
- [ ] **空状态**：无目标/无习惯/无里程碑/无回顾时，每个页面展示引导文案，不白屏不崩溃
- [ ] **错误态**：数据库操作失败时显示 snackbar 提示，不静默失败
- [ ] **加载态**：数据加载中显示 CircularProgressIndicator，不闪屏
- [ ] **目录结构**：lib 下有 models/ services/ pages/ data/ widgets/ 分层清晰
- [ ] **完整冷启动流程**：删掉 atoms.db → 启动 → 走 onboarding → 选演示 → 打卡 → 左滑看进度 → 切目标 → 建自己的目标 → 全流程不崩溃

---

## 八、v1 整体完成标准

- [ ] R1–R8 所有轮次验收条件全部通过
- [ ] Python 自动化脚本可走通完整用户旅程并通过 CLI 逐一验证 get 数据正确
- [ ] 连接 VNC 可观看自动化操作全流程，无闪烁无崩溃

---

## 九、CLI Bridge — 自动化验证体系

> 在 Flutter 应用内嵌入 TCP CLI 服务，Python 脚本通过网络协议直接操作应用、查询状态、验证数据。配合 VNC 可视化，形成**操作 → 截图可见 → get 校验 → 下一操作**的闭环自动化验证。

### 架构

```
┌─────────────────┐     TCP Socket      ┌──────────────────────┐
│  Python 脚本     │ ←───────────────→  │  Flutter App          │
│  (自动化/验证)   │   localhost:9999    │  (UI 线程 + CLI 线程) │
│                 │   JSON 协议          │                      │
│  · 发命令        │                     │  · 显示 UI (VNC 可见)  │
│  · get 校验      │                     │  · 监听 CLI 端口       │
│  · assert 断言   │                     │  · 操作 DB / UI        │
└─────────────────┘                     └──────────────────────┘
                                               │
                                          VNC 观看
```

- CLI 服务随应用启动，监听 `localhost:9999`（可配置，命令行参数 `--cli-port`）
- 每个命令携带操作指令 → 应用执行 → 返回 JSON 结果
- UI 同步刷新，VNC 可见操作效果
- Python 脚本 step-by-step：**发操作 → 等响应 → get 查询状态 → assert 断言 → 下一步**

**v1 → v3 迁移路径**：CLI 服务在 v1 嵌入 Flutter（直接操作 AppDatabase），
v3 时 Go 后端接管同一端口和协议。Python 脚本的 `atoms_cli.py` 一行不改，
只需更换连接目标。v1 的 `cli_service.dart` 在 v3 作为废弃文件删除。

### 通信协议

JSON-line 协议，一行一条命令，一行一条响应：

```
→ {"cmd": "create_goal", "name": "减掉10公斤"}
← {"status": "ok", "data": {"id": 1, "name": "减掉10公斤", ...}}

→ {"cmd": "get_goals"}
← {"status": "ok", "data": [{"id": 1, "name": "减掉10公斤", ...}]}

→ {"cmd": "no_such_cmd"}
← {"status": "error", "message": "unknown command: no_such_cmd"}
```

所有命令： `{"cmd": "<command>", ...params}`  
所有响应： `{"status": "ok"|"error", "data": ..., "message": "..."}` 

### 命令清单

#### 导航类 — 控制页面跳转

| 命令 | 参数 | 说明 |
|------|------|------|
| `nav` | `route` (str), `args` (obj, 可选) | 跳转到指定路由，如 `{"cmd":"nav","route":"/create-goal"}` |
| `switch_face` | `face` ("goal"\|"habit") | 切换到目标面或习惯面 |
| `switch_goal` | `goal_id` (int) | 切换活跃目标 |
| `navigate_back` | — | 返回上一页（模拟系统返回键） |

#### 数据写入类 — 操作数据库 + UI 刷新

| 命令 | 参数 | 返回 data | 说明 |
|------|------|-----------|------|
| `insert_demo_data` | — | `{goals, milestones, ...}` | 写入预设演示数据（R2 demo_data） |
| `create_goal` | `name` (str) | `{id, name, status, created}` | 创建目标 |
| `create_milestone` | `goal_id` (int), `name` (str), `target_desc` (str, 可选), `target_value` (num, 可选) | `{id, name, status, ...}` | 创建里程碑 |
| `create_action_plan` | `milestone_id` (int), `name` (str) | `{id, name, ...}` | 创建行动计划项 |
| `create_habit` | `milestone_id` (int), `name` (str), `frequency` (str), `action_plan_ids` ([int]), `two_min_ver` (str, 可选) | `{id, name, frequency, actions, ...}` | 创建习惯 |
| `complete_habit` | `habit_id` (int), `status` ("full"\|"two_min"), `action_completions` (obj, 可选) | `{log_id, status, ...}` | 完成/两分钟完成习惯 |
| `skip_habit` | `habit_id` (int) | `{log_id, status: "skipped"}` | 跳过习惯 |
| `update_milestone` | `id` (int), `current_value` (num) | `{id, current_value, ...}` | 更新里程碑进度 |
| `complete_milestone` | `id` (int) | `{id, status: "completed", ...}` | 标记里程碑完成 |
| `archive_habit` | `id` (int) | `{id, archived: true}` | 归档习惯 |
| `save_review` | `goal_id` (int), `week` (str), `notes` (str) | `{id, ...}` | 保存周回顾 |
| `reset_db` | — | `{}` | 清空所有数据后重建空库 |
| `shutdown` | — | `{}` | 关闭应用 |

#### 查询类 (GET) — 纯读，不做 UI 变更

| 命令 | 参数 | 返回 data | 说明 |
|------|------|-----------|------|
| `get_goals` | — | `[{id, name, status, ...}]` | 所有目标 |
| `get_goal` | `id` (int) | `{id, name, status, milestones_count, ...}` | 单个目标详情 |
| `get_milestones` | `goal_id` (int) | `[{id, name, status, sort_order, ...}]` | 目标下所有里程碑 |
| `get_milestone` | `id` (int) | `{id, name, status, action_plans_count, ...}` | 单个里程碑详情 |
| `get_action_plans` | `milestone_id` (int) | `[{id, name, sort_order}]` | 里程碑的行动计划 |
| `get_habits` | `milestone_id` (int) | `[{id, name, frequency, actions, ...}]` | 里程碑的习惯列表 |
| `get_habit` | `id` (int) | `{id, name, frequency, actions, two_min_ver, ...}` | 单个习惯详情 |
| `get_logs` | `habit_id` (int), `limit` (int, 可选) | `[{id, date, status, action_completions}]` | 习惯的执行日志（最近 N 条） |
| `get_logs_today` | `habit_id` (int) | `{id, date, status, ...} \| null` | 今天该习惯的日志 |
| `get_logs_week` | `habit_id` (int) | `[{date, status}]` | 最近 7 天日志 |
| `get_total_completed` | `habit_id` (int) | `{count: int}` | 累计完成次数 |
| `get_goal_progress` | `goal_id` (int) | `{total_progress, milestones: [...]}` | 目标总进度 + 里程碑明细 |
| `get_reviews` | `goal_id` (int, 可选) | `[{id, week, notes, ...}]` | 周回顾列表 |
| `get_identity_insights` | `goal_id` (int, 可选) | `[{id, text, accepted, ...}]` | 身份洞察记录 |
| `get_current_state` | — | `{current_face, active_goal_id, current_route, milestones_status}` | 当前应用状态快照 |
| `get_db_stats` | — | `{goals, milestones, action_plans, habits, logs, reviews}` | 各表行数统计 |
| `ping` | — | `{timestamp, uptime}` | 服务健康检查 |

### Python SDK 示例

```
scripts/
├── atoms_cli.py          # CLI 客户端封装
└── demo_automation.py    # 完整自动化演示脚本
```

`atoms_cli.py` 核心类：

```python
import socket, json, time

class AtomsCLI:
    def __init__(self, host='localhost', port=9999, timeout=5):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.settimeout(timeout)
        self.sock.connect((host, port))
        self._buf = ''

    def _send(self, cmd):
        """发送 JSON 命令，返回解析后的响应"""
        payload = json.dumps(cmd, ensure_ascii=False) + '\n'
        self.sock.sendall(payload.encode())
        while '\n' not in self._buf:
            chunk = self.sock.recv(4096)
            if not chunk:
                raise ConnectionError("CLI 连接断开")
            self._buf += chunk.decode()
        line, self._buf = self._buf.split('\n', 1)
        resp = json.loads(line)
        if resp.get('status') == 'error':
            raise RuntimeError(f"CLI 命令失败: {resp.get('message')}")
        return resp.get('data')

    # ── 便捷方法 ──
    def insert_demo_data(self):
        return self._send({"cmd": "insert_demo_data"})
    
    def get_goals(self):
        return self._send({"cmd": "get_goals"})
    
    def create_goal(self, name):
        return self._send({"cmd": "create_goal", "name": name})
    
    def get_milestones(self, goal_id):
        return self._send({"cmd": "get_milestones", "goal_id": goal_id})
    
    def complete_habit(self, habit_id, status="full"):
        return self._send({"cmd": "complete_habit", "habit_id": habit_id, "status": status})
    
    def get_logs_today(self, habit_id):
        return self._send({"cmd": "get_logs_today", "habit_id": habit_id})
    
    def get_total_completed(self, habit_id):
        return self._send({"cmd": "get_total_completed", "habit_id": habit_id})
    
    def get_db_stats(self):
        return self._send({"cmd": "get_db_stats"})
    
    def reset_db(self):
        return self._send({"cmd": "reset_db"})
    
    def shutdown(self):
        try:
            self._send({"cmd": "shutdown"})
        except:
            pass
        finally:
            self.sock.close()

    # ── 辅助 ──
    def wait_for(self, seconds):
        """等待 N 秒（让 UI 动画完成，VNC 可见）"""
        time.sleep(seconds)
```

`demo_automation.py` 自动化演示脚本：

```python
from atoms_cli import AtomsCLI

def test_demo_flow():
    cli = AtomsCLI()
    cli.reset_db()
    
    # ═══ 阶段 1：写入演示数据 ═══
    print("[1/6] 写入演示数据...")
    cli.insert_demo_data()
    
    # 验证
    goals = cli.get_goals()
    assert len(goals) == 1, f"应有 1 个目标，实际 {len(goals)}"
    assert goals[0]['name'] == "完成双力臂"
    print(f"  ✓ 目标正确: {goals[0]['name']}")
    
    milestones = cli.get_milestones(goal_id=1)
    assert len(milestones) == 4, f"应有 4 个里程碑，实际 {len(milestones)}"
    assert milestones[0]['status'] == 'active', "第1个里程应active"
    assert milestones[1]['status'] == 'waiting', "第2个里程应waiting"
    print(f"  ✓ 里程碑: active={milestones[0]['name']}, waiting={milestones[1]['name']}")
    
    habits = cli.get_habits(milestone_id=1)
    assert len(habits) == 2, f"应有 2 个习惯，实际 {len(habits)}"
    print(f"  ✓ 习惯: {habits[0]['name']} ({habits[0]['frequency']}), {habits[1]['name']} ({habits[1]['frequency']})")
    
    stats = cli.get_db_stats()
    print(f"  ✓ 数据库状态: {stats}")
    
    cli.wait_for(2)  # VNC 可观察
    
    # ═══ 阶段 2：执行打卡 ═══
    print("\n[2/6] 执行打卡...")
    cli.navigate("/")  # 确保在习惯面
    
    # 全部完成练背计划
    cli.complete_habit(habit_id=1, status="full")
    log = cli.get_logs_today(habit_id=1)
    assert log is not None, "今日日志应存在"
    assert log['status'] == 'full', f"状态应为full，实际{log['status']}"
    print(f"  ✓ 练背计划: 完成 (status=full)")
    
    # 两分钟安全阀（核心训练）
    cli.complete_habit(habit_id=2, status="two_min")
    log = cli.get_logs_today(habit_id=2)
    assert log['status'] == 'two_min', f"状态应为two_min，实际{log['status']}"
    print(f"  ✓ 核心训练: 两分钟完成 (status=two_min)")
    
    cli.wait_for(1)
    
    # ═══ 阶段 3：累计次数验证 ═══
    print("\n[3/6] 累计次数验证...")
    total = cli.get_total_completed(habit_id=1)
    assert total['count'] >= 1, f"练背计划累计应≥1，实际{total['count']}"
    print(f"  ✓ 练背计划累计: {total['count']} 次")
    
    cli.wait_for(1)
    
    # ═══ 阶段 4：切换目标面看进度 ═══
    print("\n[4/6] 切换目标面...")
    cli.switch_face("goal")
    progress = cli.get_goal_progress(goal_id=1)
    assert progress is not None
    print(f"  ✓ 目标进度: {progress}")
    
    cli.wait_for(2)
    
    # ═══ 阶段 5：里程碑推进 ═══
    print("\n[5/6] 里程碑推进...")
    cli.update_milestone(id=1, current_value=1.0)
    cli.complete_milestone(id=1)
    
    milestones = cli.get_milestones(goal_id=1)
    assert milestones[0]['status'] == 'completed', "第1个里程应completed"
    assert milestones[1]['status'] == 'active', "第2个里程应变active"
    print(f"  ✓ 里程碑① completed → 里程碑② active")
    
    cli.wait_for(2)
    
    # ═══ 阶段 6：创建自己的目标 ═══
    print("\n[6/6] 创建自己的目标...")
    goal = cli.create_goal("减掉10公斤")
    assert goal['name'] == "减掉10公斤"
    
    m = cli.create_milestone(goal_id=goal['id'], name="戒掉含糖饮料")
    assert m['status'] == 'active'
    
    a = cli.create_action_plan(milestone_id=m['id'], name="下午想喝可乐时先喝一杯水")
    h = cli.create_habit(
        milestone_id=m['id'],
        name="饮水替代",
        frequency="daily",
        action_plan_ids=[a['id']],
        two_min_ver="喝一口水"
    )
    assert h['name'] == "饮水替代"
    print(f"  ✓ 新目标: {goal['name']} → 里程碑: {m['name']} → 习惯: {h['name']}")
    
    cli.wait_for(2)
    
    # ═══ 最终验证 ═══
    goals = cli.get_goals()
    assert len(goals) == 2, f"应有 2 个目标，实际 {len(goals)}"
    print(f"\n{'='*50}")
    print(f"全部 6 步验证通过 ✓")
    print(f"目标数: {len(goals)}, 数据库: {cli.get_db_stats()}")
    print(f"{'='*50}")
    
    cli.shutdown()

if __name__ == "__main__":
    test_demo_flow()
```

### Flutter 实现

新增文件和修改：

**新增**：
```
lib/services/cli_service.dart        # TCP CLI 服务器（随 app 启动）
```

**实现要点**：
- 使用 `dart:io` 的 `HttpServer` 或 `ServerSocket` 监听 localhost:9999
- 每个连接按行读取 JSON 命令，解析 cmd 字段后路由到处理函数
- 处理函数直接调用 Service 层方法操作数据**（不直接调 AppDatabase，遵循架构分层）**
- 导航类命令通过回调或全局 key 操作 Navigator
- 导航类命令通过回调或全局 key 操作 Navigator
- UI 刷新：数据变更后触发页面 setState（通过 callback 或 Provider 通知）
- 服务随 app 启动，后台运行不阻塞 UI 线程
- 命令行参数 `--cli-port` 可指定端口，默认 9999

**`cli_service.dart` 核心结构**：

```dart
class CliService {
  final GoalService _goalService;       // 不直接拿 AppDatabase
  final HabitService _habitService;
  final ReviewService _reviewService;
  final void Function(String route, {Object? args}) _navigator;
  
  CliService(this._goalService, this._habitService, 
             this._reviewService, this._navigator);
  
  Future<void> start({int port = 9999}) async {
    final server = await ServerSocket.bind(
      InternetAddress.loopbackIPv4, port);
    
    server.listen((socket) {
      socket.transform(utf8.decoder).transform(LineSplitter()).listen(
        (line) => _handleCommand(line, socket));
    });
  }
  
  Future<void> _handleCommand(String line, Socket socket) async {
    try {
      final cmd = jsonDecode(line);
      final result = await _route(cmd);
      _respond(socket, {'status': 'ok', 'data': result});
    } catch (e) {
      _respond(socket, {'status': 'error', 'message': e.toString()});
    }
  }
  
  Future<dynamic> _route(Map<String, dynamic> cmd) async {
    switch (cmd['cmd']) {
      case 'get_goals':         return _goalService.getAllGoals();
      case 'create_goal':       return _goalService.createGoal(cmd['name']);
      case 'complete_habit':    return _habitService.completeHabit(...);
      case 'switch_face':       return _navigateToFace(cmd['face']);
      // ... 其余命令
      default: throw Exception('unknown command: ${cmd['cmd']}');
    }
  }
}
```

### 启动方式

```bash
# 构建
flutter build linux --debug

# 启动（带 CLI）
./build/linux/x64/debug/atoms --cli-port 9999

# 另开终端运行自动化
python3 scripts/demo_automation.py

# 同时连接 VNC 观看全程
```

### CLI Bridge 自身验收

- [ ] `ping` 返回时间戳，证明服务存活
- [ ] `reset_db` 后 `get_db_stats` 返回全 0
- [ ] `insert_demo_data` 后 `get_db_stats` 返回 goals=1, milestones=4, action_plans=6, habits=2
- [ ] `demo_automation.py` 全程 6 步全部通过，无异常退出
- [ ] 运行期间 VNC 可见 UI 自动跳转、打卡、进度条变化
- [ ] 异常命令返回 `{"status":"error","message":"..."}` 不崩溃
- [ ] 断开 Python 后重新连接，服务正常
- [ ] 多次 `reset_db` 再 `insert_demo_data`，数据完整无残留

### 轮次归属

CLI Bridge 为横向基础设施，**不绑死某一轮**：

| 轮次 | CLI 相关工作 |
|------|-------------|
| R1 | CLI 服务骨架启动 + `ping` / `reset_db` / `get_db_stats` / `shutdown` |
| R2 | `insert_demo_data` / `create_goal` / `create_milestone` / `create_action_plan` / `create_habit` / 对应 get 方法 |
| R3 | `switch_face` / `switch_goal` / `get_current_state` / `nav` |
| R4 | `complete_habit` / `skip_habit` / `get_logs_today` / `get_total_completed` / `get_habits` |
| R5 | `update_milestone` / `complete_milestone` / `get_goal_progress` |
| R6 | `save_review` / `get_reviews` |
| R7 | `get_identity_insights` |

每轮开发完成后，对应 Python 脚本步骤即可跑通验证。

---

*创建于 2026-06-14*
*基于 ux_design.md v1*
