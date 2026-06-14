"""
R2-A 用户自建流程测试: 模拟用户一步步创建目标→里程碑→行动计划→习惯
每步创建后 get 验证数据符合预期，才进入下一步
布局: 时间线居中，写操作(左) | 读验证(右)
"""

import os
from cli_client import AtomsClient
from report import TestReport
from fixture_loader import _load_fixture_json

REPORT_DIR = os.path.join(os.path.dirname(__file__), "reports")


def test_r2_create():
    c = AtomsClient()
    report = TestReport("R2-A 用户自建流程",
                        flow_desc="用户首次进入应用，手动创建目标→里程碑→行动计划→习惯，每步创建后通过查询接口验证操作是否生效")
    fx = _load_fixture_json()

    # ═══════════════ 创建目标 ═══════════════
    report.set_section("创建目标")

    # [写] create_goal
    goal = c.create_goal(fx["goal"]["name"])
    report.add_step(
        action="create_goal",
        readable_title="创建目标「完成双力臂」",
        api_name="create_goal",
        side="left",
        operation=goal,
        expected="返回含 id",
        actual=f"id={goal.get('id')}, name={goal.get('name')}",
        passed=bool(goal.get("id")),
    )
    goal_id = goal["id"]

    # [读] get_goals 查询验证
    goals = c.get_goals()
    matched = [g for g in goals if g["id"] == goal_id]
    report.add_step(
        action="get_goals 验证",
        readable_title="查看目标列表确认已创建",
        api_name="get_goals",
        side="right",
        expected=f"包含 id={goal_id} 的目标",
        actual=f"匹配到 {len(matched)} 个, name={matched[0].get('name') if matched else '无'}",
        passed=len(matched) == 1,
    )

    # ═══════════════ 创建里程碑 ═══════════════
    report.set_section("创建里程碑")
    milestone_ids = []

    for ms in fx["milestones"]:
        m = c.create_milestone(goal_id, ms["name"],
                               target_desc=ms.get("target_desc"),
                               target_value=ms.get("target_value"))
        report.add_step(
            action=f"create_milestone_{ms['name']}",
            readable_title=f"创建里程碑「{ms['name']}」",
            api_name="create_milestone",
            side="left",
            operation=m,
            expected="返回含 id",
            actual=f"id={m.get('id')}",
            passed=bool(m.get("id")),
        )
        milestone_ids.append(m["id"])

    # [读] get_milestones 查询验证
    milestones_db = c.get_milestones(goal_id)
    names_match = all(
        milestones_db[i].get("name") == fx["milestones"][i]["name"]
        for i in range(min(len(milestones_db), len(fx["milestones"])))
    )
    report.add_step(
        action="get_milestones 验证",
        readable_title="查看里程碑列表确认全部创建",
        api_name="get_milestones",
        side="right",
        expected=f"{len(fx['milestones'])} 个, 名称均匹配",
        actual=f"{len(milestones_db)} 个, 名称匹配={names_match}",
        passed=len(milestones_db) == len(fx["milestones"]) and names_match,
    )

    # ═══════════════ 创建行动计划 ═══════════════
    report.set_section("创建行动计划")
    ap_config = fx["action_plans"]
    m1_id = milestone_ids[ap_config["milestone_index"]]
    action_plan_ids = []

    for ap_name in ap_config["items"]:
        ap = c.create_action_plan(m1_id, ap_name)
        report.add_step(
            action=f"create_action_plan_{ap_name}",
            readable_title=f"创建计划「{ap_name}」",
            api_name="create_action_plan",
            side="left",
            operation=ap,
            expected="返回含 id",
            actual=f"id={ap.get('id')}",
            passed=bool(ap.get("id")),
        )
        action_plan_ids.append(ap["id"])

    # [读] get_action_plans
    action_plans_db = c.get_action_plans(m1_id)
    report.add_step(
        action="get_action_plans 验证",
        readable_title="查看行动计划列表确认数量",
        api_name="get_action_plans",
        side="right",
        expected=len(ap_config["items"]),
        actual=len(action_plans_db),
        passed=len(action_plans_db) == len(ap_config["items"]),
    )

    # ═══════════════ 创建习惯 ═══════════════
    report.set_section("创建习惯")
    habit_ids = []

    for hb in fx["habits"]:
        ap_ids = [action_plan_ids[idx] for idx in hb.get("action_plan_indices", [])] if hb.get("action_plan_indices") else None
        h = c.create_habit(milestones_db[hb["milestone_index"]]["id"], hb["name"],
                           frequency=hb["frequency"],
                           action_plan_ids=ap_ids,
                           two_min_ver=hb.get("two_min_ver"))
        report.add_step(
            action=f"create_habit_{hb['name']}",
            readable_title=f"创建习惯「{hb['name']}」({hb['frequency']})",
            api_name="create_habit",
            side="left",
            operation=h,
            expected="返回含 id",
            actual=f"id={h.get('id')}, freq={h.get('frequency')}",
            passed=bool(h.get("id")),
        )
        habit_ids.append(h["id"])

    habits_db = c.get_habits(milestones_db[0]["id"])
    report.add_step(
        action="get_habits 验证",
        readable_title="查看习惯列表确认已创建",
        api_name="get_habits",
        side="right",
        expected=len(fx["habits"]),
        actual=len(habits_db),
        passed=len(habits_db) >= len(fx["habits"]),
    )

    # ═══════════════ 验证数据库统计 ═══════════════
    report.set_section("验证数据库统计")
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

    report.save_md(os.path.join(REPORT_DIR, "r2_create.md"))
    report.save_html(os.path.join(REPORT_DIR, "r2_create.html"))
    report.print_summary()


if __name__ == "__main__":
    test_r2_create()
