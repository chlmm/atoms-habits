# MVP 阶段开发计划 (v0)

> 目标：**Linux 桌面端单机运行，验证核心方法论闭环。**
> 不联网、不同步、不搞社交、不分析 — 只做习惯系统的设计+执行+反馈。

---

## 一、MVP 范围界定

### 做什么

| 模块 | 内容 |
|------|------|
| 身份声明 | 用户设定"我想成为 ____ 的人" |
| 习惯定义 | 创建习惯，含 叠加线索 + 两分钟版本 + 具体化信息 |
| 习惯列表 | 按上下文/时间分组展示 |
| 两分钟模式 | 每日执行的是两分钟版本，非完整版 |
| 累计进步曲线 | 累计完成次数图表，非连续天数 |
| 绝不连续错过两次 | 规则逻辑 + 告警提示 |
| 每周回顾 | 简单的回顾面板：这周哪些在自动运行 |

### 不做什么

| 砍掉的 | 原因 |
|--------|------|
| 环境设计画布 | 复杂度高，P2 再做 |
| 喜好绑定 / 合约 / 群体 | 社交类功能，MVP 后再说 |
| 专注计时器 | 可以用两分钟替代 |
| 数据云同步 / 多设备 | 先本地跑通 |
| 统计分析引擎 | Go 后端能力，P3 |
| Android 端 | 桌面端验证好再适配 |

---

## 二、页面结构

```
app_root
├── identity_page        # 身份声明（首次/可修改）
├── habit_list_page      # 今日习惯列表（主页面）
│   ├── habit_create_page    # 新建/编辑习惯
│   └── habit_detail_page    # 习惯详情 + 历史曲线
└── review_page          # 每周回顾面板
```

### 页面详情

#### 1. identity_page（身份声明）

- 一个核心问题："我想成为____的人"
- 显示在应用主界面顶部，作为日常锚点
- 首次启动时引导用户填写，之后可修改
- 可以有多条身份声明（如"我是一个健康的人"+"我是一个持续学习的人"）

#### 2. habit_list_page（主页）

- 顶部显示身份声明
- 今日习惯列表，每条显示：
  - 习惯名称 + 两分钟版本描述
  - 叠加线索（"在 [X] 之后，我会 [Y]"）
  - 今日状态：未开始 / 已完成（两分钟）/ 已跳过
- 底部浮动按钮 → 新建习惯
- 点击进入 habit_detail_page

#### 3. habit_create_page / habit_edit_page

创建习惯的表单字段：
- 习惯名称（必填）
- 两分钟版本（必填）— 引导文案"如果只能做 2 分钟，你会做什么？"
- 叠加线索（选填）— "在 [现有习惯] 之后，我会 [此习惯]"
- 时间（选填）— "我计划在 [几点] 做这件事"
- 地点（选填）— "我计划在 [哪里] 做这件事"
- 所属身份（选填）— 关联到已有的身份声明

#### 4. habit_detail_page

- 习惯基本信息（可编辑）
- 累计完成次数曲线（简易折线图）
- 最近 7 天的完成记录
- "绝不连续错过两次" 状态指示
- 两分钟版 vs 完整版的切换记录

#### 5. review_page（每周回顾）

- 简单的回顾面板（非图表仪表盘，MVP 用列表即可）
- 几条引导性问题：
  - "这周哪些习惯在自动运行？"
  - "哪些习惯需要重新设计系统？"
  - "有没有连续错过两次的习惯？"
- 用户可以写简短笔记

---

## 三、数据模型（本地 SQLite）

```sql
-- 身份声明
CREATE TABLE identities (
    id      INTEGER PRIMARY KEY,
    text    TEXT NOT NULL,
    sort    INTEGER DEFAULT 0,
    created TEXT DEFAULT (datetime('now'))
);

-- 习惯
CREATE TABLE habits (
    id          INTEGER PRIMARY KEY,
    name        TEXT NOT NULL,
    two_min_ver TEXT NOT NULL,
    cue         TEXT,          -- 叠加线索
    plan_time   TEXT,          -- 计划时间
    plan_place  TEXT,          -- 计划地点
    identity_id INTEGER,       -- 所属身份
    archived    INTEGER DEFAULT 0,
    created     TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (identity_id) REFERENCES identities(id)
);

-- 执行日志
CREATE TABLE logs (
    id         INTEGER PRIMARY KEY,
    habit_id   INTEGER NOT NULL,
    date       TEXT NOT NULL,          -- YYYY-MM-DD
    status     TEXT NOT NULL,          -- 'two_min' | 'full' | 'skipped'
    note       TEXT,
    created    TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (habit_id) REFERENCES habits(id),
    UNIQUE(habit_id, date)
);

-- 每周回顾
CREATE TABLE reviews (
    id        INTEGER PRIMARY KEY,
    week      TEXT NOT NULL UNIQUE,    -- YYYY-Www
    notes     TEXT,
    created   TEXT DEFAULT (datetime('now'))
);
```

---

## 四、核心逻辑

### 两分钟模式的判定

```
每日执行：
  1. 用户看到的始终是两分钟版本
  2. 完成两分钟 → 标记 status='two_min'
  3. 用户自主选择是否继续做完整版
     如果继续 → 额外标记 status='full'
```

### 累计进步曲线

```
横轴：日期
纵轴：累计完成次数（从第一天开始累加）
不中断、不清零
```

### 绝不连续错过两次

```
规则：
  if 昨天未完成 AND 今天也未完成 → 告警
  if 昨天未完成 AND 今天完成了 → 正常，不告警
  if 昨天完成了 AND 今天未完成 → 不告警（允许错过一次）
```

### 每周回顾触发

```
每周日提示用户进行回顾
显示过去7天的习惯完成概览
```

---

## 五、技术选型（MVP）

| 层 | 选型 | 理由 |
|---|------|------|
| UI | Flutter (Linux 桌面) | 跨平台，后续平滑迁移 Android |
| 本地存储 | SQLite (sqflite) | 轻量，无需服务端 |
| 图表 | fl_chart | 累计曲线 |
| 状态管理 | Riverpod | 简单可测试 |
| 后端 | 无（纯前端 MVP） | 先跑通逻辑，Go 后端后续接入 |

> MVP 阶段 Go 不参与，纯 Dart 本地实现。等数据模型和交互跑通后，再按 FFI 方案接入 Go。

---

## 六、开发顺序

| 轮次 | 内容 | 完成标志 |
|------|------|---------|
| **R1** | 项目骨架 + 数据层（SQLite） | 能创建身份和习惯，数据持久化 |
| **R2** | 身份声明页面 + 习惯列表页面 | 能看到今日习惯 |
| **R3** | 习惯创建/编辑页面 | 完整的习惯 CRUD |
| **R4** | 两分钟执行 + 打卡逻辑 | 能记录完成状态 |
| **R5** | 累计进步曲线 + 习惯详情页 | 看到自己的进步 |
| **R6** | 绝不连续错过两次 + 告警 | 规则逻辑生效 |
| **R7** | 每周回顾面板 | 回顾流程可用 |
| **R8** | 打磨 UI + 交互动效 | MVP 成品 |

---

## 七、MVP 完成标准

- [ ] 用户能声明"我想成为 ____ 的人"
- [ ] 用户能创建习惯，含两分钟版本和叠加线索
- [ ] 主页展示今日习惯，一键完成两分钟版本
- [ ] 累计进步曲线正常显示
- [ ] "绝不连续错过两次"规则生效
- [ ] 每周回顾面板可用
- [ ] Linux 桌面端正常运行，无崩溃

---

*最后更新：2026-06-13*
