"""
测试报告工具: 逐步记录测试过程，生成 Markdown + HTML 详细报告
支持: 流程说明、分组(section)、操作返回vs验证反馈(左右对比)
"""

import os
import json
from datetime import datetime
from typing import Any, Optional


class StepResult:
    """单步测试结果"""

    def __init__(self, step_no: int, action: str, side: str = "left",
                 operation: Any = None,
                 expected: Any = None, actual: Any = None,
                 passed: bool = True, detail: str = "", section: str = "",
                 readable_title: str = "", api_name: str = ""):
        self.step_no = step_no
        self.action = action              # 操作标识 (内部用)
        self.readable_title = readable_title or action  # 卡片显示的标题（人类可读）
        self.api_name = api_name or action   # 执行的 API 接口名
        self.side = side                  # "left"=写操作(增改删), "right"=读验证(查询)
        self.operation = operation        # 左侧详情: 操作直接返回值 (API response)
        self.expected = expected          # 右侧: 预期数据
        self.actual = actual              # 右侧: 实际数据 (通常来自查询)
        self.passed = passed
        self.detail = detail
        self.section = section

    @property
    def mark(self) -> str:
        return "✓" if self.passed else "✗"

    @property
    def status_cls(self) -> str:
        return "passed" if self.passed else "failed"


class TestReport:
    """测试报告收集器"""

    def __init__(self, title: str, flow_desc: str = ""):
        self.title = title
        self.flow_desc = flow_desc
        self.steps: list[StepResult] = []
        self._step_counter = 0
        self._current_section = ""

    def set_section(self, name: str):
        """设置当前分组"""
        self._current_section = name

    # ── 核心记录方法 ──

    def add_step(self, action: str, side: str = "left",
                 operation: Any = None,
                 expected: Any = None, actual: Any = None,
                 passed: bool = True, detail: str = "",
                 readable_title: str = "", api_name: str = "") -> StepResult:
        """
        记录一步测试（三栏布局）
        - action: 操作标识
        - side: "left"=写操作(增改删, 卡片在左), "right"=读验证(查询, 卡片在右)
        - operation: 操作的 API 返回值（左侧卡片展开详情）
        - readable_title: 卡片标题显示的人类可读名称（默认用 action）
        - api_name: 执行的 API 接口名（详情面板中显示）
        - expected/actual/passed/detail
        """
        self._step_counter += 1
        step = StepResult(
            self._step_counter, action, side, operation,
            expected, actual, passed, detail, self._current_section,
            readable_title, api_name
        )
        self.steps.append(step)
        return step

    def record(self, action: str, expected: Any, actual: Any,
               passed: bool, detail: str = "", operation: Any = None,
               side: str = "right"):
        """兼容旧接口：记录一步（默认 right，因为旧用法多用于验证）"""
        self.add_step(action, side=side, operation=operation,
                      expected=expected, actual=actual,
                      passed=passed, detail=detail)

    def check(self, action: str, expected: Any, actual: Any,
              detail: str = "", operation: Any = None) -> bool:
        """记录并断言 equal"""
        passed = actual == expected
        self.record(action, expected, actual, passed, detail, operation)
        if not passed:
            raise AssertionError(
                f"Step {self._step_counter} 失败: {action}\n"
                f"  预期: {expected}\n"
                f"  实际: {actual}")
        return True

    def check_contains(self, action: str, expected_in: Any, actual: Any,
                       detail: str = "", operation: Any = None) -> bool:
        """记录并断言 contains"""
        passed = expected_in in actual
        self.record(action, f"包含 '{expected_in}'", _truncate(actual),
                    passed, detail, operation)
        if not passed:
            raise AssertionError(
                f"Step {self._step_counter} 失败: {action}\n"
                f"  预期包含: {expected_in}\n"
                f"  实际: {actual}")
        return True

    def check_true(self, action: str, condition: bool,
                   expected: str = "True", actual: str = "False",
                   detail: str = "", operation: Any = None) -> bool:
        """记录并断言 condition == True"""
        self.record(action, expected, actual, condition, detail, operation)
        if not condition:
            raise AssertionError(
                f"Step {self._step_counter} 失败: {action}\n"
                f"  预期: {expected}\n"
                f"  实际: {actual}")
        return True

    # ── 统计 ──

    @property
    def passed_count(self) -> int:
        return sum(1 for s in self.steps if s.passed)

    @property
    def failed_count(self) -> int:
        return sum(1 for s in self.steps if not s.passed)

    @property
    def all_passed(self) -> bool:
        return self.failed_count == 0

    # ── Markdown 报告 ──

    def generate_md(self) -> str:
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        lines = [
            f"# {self.title}", "",
        ]
        if self.flow_desc:
            lines.append(f"> **流程**: {self.flow_desc}")
            lines.append("")
        lines += [
            f"> 生成时间: {now}",
            f"> 总步骤: {len(self.steps)} | 通过: {self.passed_count} | 失败: {self.failed_count}",
            f"> 最终结果: {'✓ 全部通过' if self.all_passed else '✗ 存在失败'}",
            "",
            f"| # | 结果 | 分组 | 操作 | 操作返回 | 预期 | 实际 |",
            f"|---|------|------|------|----------|------|------|",
        ]
        for s in self.steps:
            sec = f"【{s.section}】" if s.section else ""
            op = _truncate(s.operation, 40) if s.operation else "-"
            exp = _truncate(s.expected, 30)
            act = _truncate(s.actual, 30)
            lines.append(f"| {s.step_no} | {s.mark} | {sec} | {s.readable_title} | {op} | {exp} | {act} |")

        lines.append("")
        failed_steps = [s for s in self.steps if not s.passed]
        if failed_steps:
            lines.append("## 失败步骤详情")
            for s in failed_steps:
                lines.append(f"\n### Step {s.step_no}: {s.action}")
                if s.operation:
                    lines.append(f"- **操作返回**: `{s.operation}`")
                lines.append(f"- **预期**: `{s.expected}`")
                lines.append(f"- **实际**: `{s.actual}`")
                if s.detail:
                    lines.append(f"- **说明**: {s.detail}")

        return "\n".join(lines)

    def save_md(self, filepath: str):
        os.makedirs(os.path.dirname(filepath) or ".", exist_ok=True)
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(self.generate_md())

    # ── HTML 报告 ──

    def save_html(self, filepath: str):
        from report_html import generate_html
        os.makedirs(os.path.dirname(filepath) or ".", exist_ok=True)
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(generate_html(self))

    # ── 控制台 ──

    def print_summary(self):
        print(f"\n{'═' * 50}")
        print(f"  {self.title}")
        print(f"{'═' * 50}")
        for s in self.steps:
            sec = f"[{s.section}] " if s.section else ""
            op_info = f" → {_truncate(str(s.operation), 30)}" if s.operation else ""
            print(f"  {s.mark} Step {s.step_no}: {sec}{s.readable_title}{op_info}")
        print(f"{'─' * 50}")
        print(f"  通过: {self.passed_count}/{len(self.steps)}"
              f"{' ✓ 全部通过' if self.all_passed else ' ✗ 存在失败'}")
        print(f"{'═' * 50}")


def _truncate(val: Any, max_len: int = 80) -> str:
    s = json.dumps(val, ensure_ascii=False) if not isinstance(val, str) else val
    if len(s) > max_len:
        return s[:max_len - 3] + "..."
    return s
