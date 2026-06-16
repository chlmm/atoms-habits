"""
R2-B 引导模式测试: 模拟用户进入引导流程，插入预设数据后逐页验证
布局: 时间线居中，写操作(左) | 读验证(右)
"""

import os
from cli_client import AtomsClient
from report import TestReport
from fixture_loader import _load_fixture_json

REPORT_DIR = os.path.join(os.path.dirname(__file__), "reports")


def test_r2_demo():
    c = AtomsClient()
    c.reset_db()  # 从干净状态开始
    report = TestReport("R2-B 引导模式",
                        flow_desc="用户选择引导模式，应用插入预设数据后，用户逐页查看目标→里程碑→行动计划→习惯，每页数据与预期一致才进入下一页")
    fx = _load_fixture_json()

    # ═══════════════ 插入演示数据 ═══════════════
    report.set_section("插入演示数据")
    r = c.insert_demo_data()
    report.add_step(
        action="insert_demo_data",
        readable_title="插入演示数据",
        api_name="insert_demo_data",
        side="left",
        operation=r,
        expected=True,
        actual=r.get("inserted"),
        passed=r.get("inserted") == True,
    )

    # ═══════════════ 第1页: 目标 ═══════════════
    report.set_section("第1页: 目标")
    goals = c.get_goals()
    report.add_step(
        action="get_goals 查看",
        readable_title="查看引导目标是否生成",
        api_name="get_goals",
        side="right",
        expected="≥1 个目标",
        actual=f"{len(goals)} 个目标",
        passed=len(goals) >= 1,
    )
    goal = goals[0]
    report.add_step(
        action="目标名称校验",
        readable_title="检查目标名称是否符合预设",
        api_name="(内部校验)",
        side="right",
        expected=fx["goal"]["name"],
        actual=goal["name"],
        passed=goal["name"] == fx["goal"]["name"],
    )
    goal_id = goal["id"]

    # ═══════════════ 第2页: 里程碑 ═══════════════
    report.set_section("第2页: 里程碑")
    milestones = c.get_milestones(goal_id)
    report.add_step(
        action="get_milestones 查看",
        readable_title="查看引导里程碑列表",
        api_name="get_milestones",
        side="right",
        expected=len(fx["milestones"]),
        actual=len(milestones),
        passed=len(milestones) == len(fx["milestones"]),
    )
    for i, ms in enumerate(milestones):
        report.add_step(
            action=f"m{i}_名称校验",
            readable_title=f"检查里程碑[{i}]名称「{fx['milestones'][i]['name']}」",
            api_name="(内部校验)",
            side="right",
            expected=fx["milestones"][i]["name"],
            actual=ms["name"],
            passed=ms["name"] == fx["milestones"][i]["name"],
        )

    # ═══════════════ 第3页: 行动计划 ═══════════════
    report.set_section("第3页: 行动计划")
    m1_id = milestones[0]["id"]
    action_plans = c.get_action_plans(m1_id)
    actual_names = [ap["name"] for ap in action_plans]
    report.add_step(
        action="get_action_plans 查看",
        readable_title="查看引导行动计划列表",
        api_name="get_action_plans",
        side="right",
        expected=len(fx["action_plans"]["items"]),
        actual=len(action_plans),
        passed=len(action_plans) == len(fx["action_plans"]["items"]),
    )
    for expected_name in fx["action_plans"]["items"]:
        report.add_step(
            action=f"包含_{expected_name}",
            readable_title=f"检查包含计划「{expected_name}」",
            api_name="(内部校验)",
            side="right",
            expected=f"包含 '{expected_name}'",
            actual=str(expected_name in actual_names),
            passed=expected_name in actual_names,
        )

    # ═══════════════ 第4页: 习惯 ═══════════════
    report.set_section("第4页: 习惯")
    habits = c.get_habits(m1_id)
    expected_habits = [hb for hb in fx["habits"] if hb["milestone_index"] == 0]
    report.add_step(
        action="get_habits 查看",
        readable_title="查看引导习惯列表",
        api_name="get_habits",
        side="right",
        expected=len(expected_habits),
        actual=len(habits),
        passed=len(habits) == len(expected_habits),
    )
    for i, ht in enumerate(habits):
        if i < len(expected_habits):
            report.add_step(
                action=f"h{i}_名称校验",
                readable_title=f"检查习惯[{i}]名称「{expected_habits[i]['name']}」",
                api_name="(内部校验)",
                side="right",
                expected=expected_habits[i]["name"],
                actual=ht["name"],
                passed=ht["name"] == expected_habits[i]["name"],
            )

    # ═══════════════ 验证数据库 ═══════════════
    report.set_section("验证数据库")
    stats = c.get_db_stats()
    report.add_step(
        action="get_db_stats",
        readable_title="查看数据库统计信息",
        api_name="get_db_stats",
        side="right",
        expected="非空 dict",
        actual=f"{len(stats)} 个字段" if isinstance(stats, dict) else type(stats).__name__,
        passed=isinstance(stats, dict) and len(stats) > 0,
    )

    report.save_md(os.path.join(REPORT_DIR, "r2_demo.md"))
    report.save_html(os.path.join(REPORT_DIR, "r2_demo.html"))
    report.print_summary()


if __name__ == "__main__":
    test_r2_demo()
