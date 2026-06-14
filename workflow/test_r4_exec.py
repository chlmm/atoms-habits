"""
R4 每日习惯打卡测试: 模拟用户每天对习惯进行打勾完成
布局: 时间线居中，写操作(左) | 读验证(右)
"""

import os
from cli_client import AtomsClient
from report import TestReport
from fixture_loader import load_fixture

REPORT_DIR = os.path.join(os.path.dirname(__file__), "reports")


def test_r4():
    c = AtomsClient()
    report = TestReport("R4 每日习惯打卡",
                        flow_desc="用户每天打开应用，看到习惯列表，逐个打勾完成(full)、做两分钟版(two_min)、跳过(skip)，最后可归档习惯")

    # ═══════════════ 准备数据 ═══════════════
    report.set_section("准备数据")
    data = load_fixture(c)
    goal_id = data["goal"]["id"]
    ms_id = data["milestones"][0]["id"]
    habits = data["habits"]

    report.add_step(
        action="load_fixture",
        readable_title="加载测试 fixture 数据",
        api_name="load_fixture (reset+insert)",
        side="left",
        operation={"goal_id": goal_id, "ms_id": ms_id, "habits": len(habits)},
        expected="≥2 个习惯",
        actual=f"{len(habits)} 个",
        passed=len(habits) >= 2,
    )

    h1_id = habits[0]["id"]
    h1_name = habits[0]["name"]
    h2_id = habits[1]["id"]
    h2_name = habits[1]["name"]

    # ═══════════════ 打勾完成 (full) ═══════════════
    report.set_section("打勾完成")
    log = c.call("complete_habit", habit_id=h1_id, status="full")
    report.add_step(
        action="complete_habit full",
        readable_title=f"打卡完成「{h1_name}」（完整版）",
        api_name="complete_habit(status='full')",
        side="left",
        operation=log,
        expected="status=full",
        actual=log.get("status"),
        passed=log.get("status") == "full",
    )

    # ═══════════════ 查看今日日志 ═══════════════
    report.set_section("查看日志")
    today_log = c.call("get_logs_today", habit_id=h1_id)
    report.add_step(
        action="get_logs_today",
        readable_title=f"查看「{h1_name}」的今日打卡日志",
        api_name="get_logs_today",
        side="right",
        expected="存在且 status=full",
        actual=f"存在={today_log is not None}, status={today_log.get('status') if today_log else '无'}",
        passed=today_log is not None and today_log.get("status") == "full",
    )

    # ═══════════════ 两分钟版 (two_min) ═══════════════
    report.set_section("两分钟版")
    log = c.call("complete_habit", habit_id=h2_id, status="two_min")
    report.add_step(
        action="complete_habit two_min",
        readable_title=f"两分钟版打卡「{h2_name}」",
        api_name="complete_habit(status='two_min')",
        side="left",
        operation=log,
        expected="status=two_min",
        actual=log.get("status"),
        passed=log.get("status") == "two_min",
    )

    # ═══════════════ 累计完成 ═══════════════
    report.set_section("累计完成")
    total = c.call("get_total_completed", habit_id=h1_id)
    report.add_step(
        action="get_total_completed",
        readable_title=f"查看「{h1_name}」累计完成次数",
        api_name="get_total_completed",
        side="right",
        expected="count ≥ 1",
        actual=f"count={total.get('count', 0)}",
        passed=total.get("count", 0) >= 1,
    )

    # ═══════════════ 跳过习惯 (skip) ═══════════════
    report.set_section("跳过习惯")
    h3 = c.create_habit(ms_id, "临时测试习惯", frequency="daily")
    report.add_step(
        action="create_habit_skip",
        readable_title="新建临时习惯用于跳过测试",
        api_name="create_habit",
        side="left",
        operation=h3,
        expected="返回含 id",
        actual=f"id={h3.get('id')}",
        passed=bool(h3.get("id")),
    )
    h3_id = h3["id"]

    log = c.call("skip_habit", habit_id=h3_id)
    report.add_step(
        action="skip_habit",
        readable_title="跳过临时习惯",
        api_name="skip_habit",
        side="left",
        operation=log,
        expected="status=skipped",
        actual=log.get("status"),
        passed=log.get("status") == "skipped",
    )

    # ═══════════════ 本周日志 ═══════════════
    report.set_section("本周日志")
    logs = c.call("get_logs_week", habit_id=h1_id)
    report.add_step(
        action="get_logs_week",
        readable_title=f"查看「{h1_name}」本周打卡记录",
        api_name="get_logs_week",
        side="right",
        expected="返回 list",
        actual=type(logs).__name__,
        passed=isinstance(logs, list),
    )

    # ═══════════════ 归档习惯 ═══════════════
    report.set_section("归档习惯")
    r = c.call("archive_habit", id=h3_id)
    report.add_step(
        action="archive_habit",
        readable_title="归档临时习惯",
        api_name="archive_habit",
        side="left",
        operation=r,
        expected="archived=True",
        actual=r.get("archived"),
        passed=r.get("archived") == True,
    )

    # ═══════════════ 习惯详情 ═══════════════
    report.set_section("习惯详情")
    detail = c.call("get_habit", id=h1_id)
    report.add_step(
        action="get_habit",
        readable_title=f"查看「{h1_name}」详情",
        api_name="get_habit",
        side="right",
        expected=f"name={h1_name}",
        actual=f"name={detail.get('name') if detail else '无'}",
        passed=detail is not None and detail.get("name") == h1_name,
    )

    report.save_md(os.path.join(REPORT_DIR, "r4_daily_checkin.md"))
    report.save_html(os.path.join(REPORT_DIR, "r4_daily_checkin.html"))
    report.print_summary()


if __name__ == "__main__":
    test_r4()
