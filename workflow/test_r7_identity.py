"""
R7 身份洞察测试: 用户坚持打卡 3 周以上 → 系统触发身份洞察 → 用户认可身份
布局: 时间线居中，写操作(左) | 读验证(右)
"""

import os
from datetime import date, timedelta
from cli_client import AtomsClient
from report import TestReport
from fixture_loader import load_fixture

REPORT_DIR = os.path.join(os.path.dirname(__file__), "reports")


def test_r7_identity():
    c = AtomsClient()
    report = TestReport("R7 身份洞察",
                        flow_desc="用户坚持打卡超过 3 周（≥15 次完成 + ≥21 天），系统自动浮现身份洞察，用户认可后身份标签写入记录")
    today = date.today()

    # ═══════════════ 准备数据 ═══════════════
    report.set_section("准备数据")
    data = load_fixture(c)
    goal_id = data["goal"]["id"]
    goal_name = data["goal"]["name"]
    h1, h2 = data["habits"]
    h1_id, h2_id = h1["id"], h2["id"]
    h1_name, h2_name = h1["name"], h2["name"]

    report.add_step(
        action="load_fixture",
        readable_title="初始化目标、里程碑、习惯数据",
        api_name="load_fixture",
        side="left",
        operation=f"goal={goal_name}, habits=[{h1_name}, {h2_name}]",
        expected="返回含 goal + habits",
        actual=f"goal_id={goal_id}, h1_id={h1_id}, h2_id={h2_id}",
        passed=bool(goal_id and h1_id and h2_id),
    )

    # ═══════════════ 模拟 3 周打卡数据 ═══════════════
    report.set_section("模拟 3 周打卡")

    # 习惯1: 22 天内完成 16 次（满足 ≥15次 + ≥21天 触发条件）
    # 从 22 天前开始，隔天打卡
    h1_dates = []
    for i in range(16):
        d = (today - timedelta(days=22 - i * 2)).isoformat()
        h1_dates.append(d)
        log = c.call("complete_habit", habit_id=h1_id, status="full", date=d)

    report.add_step(
        action="simulate_h1_logs",
        readable_title=f"模拟「{h1_name}」3 周打卡（16次）",
        api_name="complete_habit",
        side="left",
        operation=f"16 次打卡, 日期范围 {h1_dates[0]} ~ {h1_dates[-1]}",
        expected="16 条日志写入",
        actual=f"最后一条: id={log.get('id')}, date={log.get('date')}",
        passed=bool(log.get("id")),
    )

    # 习惯2: 10 次打卡（不满足 15 次条件，不触发）
    h2_dates = []
    for i in range(10):
        d = (today - timedelta(days=20 - i * 2)).isoformat()
        h2_dates.append(d)
        log = c.call("complete_habit", habit_id=h2_id, status="full", date=d)

    report.add_step(
        action="simulate_h2_logs",
        readable_title=f"模拟「{h2_name}」2 周打卡（10次，不触发）",
        api_name="complete_habit",
        side="left",
        operation=f"10 次打卡, 日期范围 {h2_dates[0]} ~ {h2_dates[-1]}",
        expected="10 条日志写入",
        actual=f"最后一条: id={log.get('id')}, date={log.get('date')}",
        passed=bool(log.get("id")),
    )

    # ═══════════════ 验证打卡数据 ═══════════════
    report.set_section("验证打卡数据")

    # 验证习惯1完成次数
    total_h1 = c.call("get_total_completed", habit_id=h1_id)
    total_h1_count = total_h1.get("count", 0) if isinstance(total_h1, dict) else total_h1
    report.add_step(
        action="get_total_completed_h1",
        readable_title=f"查看「{h1_name}」总完成次数",
        api_name="get_total_completed",
        side="right",
        expected="≥ 15 次（满足触发条件）",
        actual=f"{total_h1_count} 次",
        passed=total_h1_count >= 15,
    )

    # 验证习惯2完成次数
    total_h2 = c.call("get_total_completed", habit_id=h2_id)
    total_h2_count = total_h2.get("count", 0) if isinstance(total_h2, dict) else total_h2
    report.add_step(
        action="get_total_completed_h2",
        readable_title=f"查看「{h2_name}」总完成次数",
        api_name="get_total_completed",
        side="right",
        expected="< 15 次（不触发）",
        actual=f"{total_h2_count} 次",
        passed=total_h2_count < 15,
    )

    # ═══════════════ 检查身份触发 ═══════════════
    report.set_section("检查身份触发")

    triggers = c.call("check_identity_triggers")
    h1_triggered = any(t.get("habit_id") == h1_id for t in triggers)
    h2_triggered = any(t.get("habit_id") == h2_id for t in triggers)

    report.add_step(
        action="check_identity_triggers",
        readable_title="检查哪些习惯触发了身份洞察",
        api_name="check_identity_triggers",
        side="right",
        expected=f"{h1_name} 触发, {h2_name} 不触发",
        actual=f"触发 {len(triggers)} 个: {[t.get('habit_name') for t in triggers]}",
        passed=h1_triggered and not h2_triggered,
    )

    # ═══════════════ 创建身份洞察 ═══════════════
    report.set_section("创建身份洞察")

    # 获取触发的习惯信息
    h1_trigger = next(t for t in triggers if t.get("habit_id") == h1_id)
    suggested_identity = "爱运动的人"  # 练背 → 爱运动的人

    insight = c.call("create_identity_insight",
                     text=suggested_identity,
                     goal_id=goal_id,
                     triggered_by=f"habit:{h1_id}")
    report.add_step(
        action="create_identity_insight",
        readable_title=f"创建身份洞察「{suggested_identity}」",
        api_name="create_identity_insight",
        side="left",
        operation=insight,
        expected=f"返回含 id, text={suggested_identity}",
        actual=f"id={insight.get('id')}, text={insight.get('text')}, accepted={insight.get('accepted')}",
        passed=bool(insight.get("id")) and insight.get("text") == suggested_identity,
    )

    # ═══════════════ 查看身份洞察 ═══════════════
    report.set_section("查看身份洞察")

    # 全局查询
    insights_all = c.call("get_identity_insights")
    report.add_step(
        action="get_identity_insights_all",
        readable_title="查看所有身份洞察记录",
        api_name="get_identity_insights",
        side="right",
        expected="至少 1 条",
        actual=f"{len(insights_all)} 条",
        passed=len(insights_all) >= 1,
    )

    # 按 goal_id 查询
    insights_goal = c.call("get_identity_insights", goal_id=goal_id)
    report.add_step(
        action="get_identity_insights_by_goal",
        readable_title="查看目标下的身份洞察",
        api_name="get_identity_insights",
        side="right",
        expected=f"包含 goal_id={goal_id}",
        actual=f"{len(insights_goal)} 条",
        passed=len(insights_goal) >= 1,
    )

    # ═══════════════ 认可身份 ═══════════════
    report.set_section("认可身份")

    insight_id = insight["id"]
    accepted = c.call("accept_identity_insight", id=insight_id)
    report.add_step(
        action="accept_identity_insight",
        readable_title=f"认可身份「{suggested_identity}」",
        api_name="accept_identity_insight",
        side="left",
        operation=accepted,
        expected=f"accepted=1 (true)",
        actual=f"accepted={accepted.get('accepted')}",
        passed=accepted.get("accepted") == 1,
    )

    # 验证认可后状态
    insights_after = c.call("get_identity_insights", goal_id=goal_id)
    accepted_insight = next((i for i in insights_after if i.get("id") == insight_id), None)
    report.add_step(
        action="verify_accepted",
        readable_title="确认身份已标记为认可",
        api_name="get_identity_insights",
        side="right",
        expected="accepted=1",
        actual=f"accepted={accepted_insight.get('accepted') if accepted_insight else 'not found'}",
        passed=accepted_insight is not None and accepted_insight.get("accepted") == 1,
    )

    # ═══════════════ 不满足条件的习惯不触发 ═══════════════
    report.set_section("验证未触发条件")

    report.add_step(
        action="verify_h2_no_trigger",
        readable_title=f"确认「{h2_name}」未触发身份洞察",
        api_name="check_identity_triggers",
        side="right",
        expected=f"{h2_name} 不在触发列表中（完成 {total_h2_count} 次 < 15）",
        actual=f"触发列表: {[t.get('habit_name') for t in triggers]}",
        passed=not h2_triggered,
    )

    # ═══════════════ 保存报告 ═══════════════
    report.save_md(os.path.join(REPORT_DIR, "r7_identity.md"))
    report.save_html(os.path.join(REPORT_DIR, "r7_identity.html"))
    report.print_summary()


if __name__ == "__main__":
    test_r7_identity()
