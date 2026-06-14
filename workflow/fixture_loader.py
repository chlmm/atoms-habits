"""
数据准备工具: 读取 fixture.json，通过 CLI 创建完整数据集
每个测试调用 load_fixture() 即可获得干净的独立数据
"""

import json
import os
from cli_client import AtomsClient

FIXTURE_PATH = os.path.join(os.path.dirname(__file__), "fixture.json")


def _load_fixture_json() -> dict:
    with open(FIXTURE_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def load_fixture(client: AtomsClient = None) -> dict:
    """
    重置数据库并按 fixture.json 创建完整数据。
    返回结构化数据供测试使用:
    {
        "goal": {...},
        "milestones": [{...}, ...],
        "action_plans": [{...}, ...],
        "habits": [{...}, ...]
    }
    """
    if client is None:
        client = AtomsClient()

    client.reset_db()
    fx = _load_fixture_json()

    # 创建目标
    goal = client.create_goal(fx["goal"]["name"])
    assert goal.get("id"), f"创建目标失败: {goal}"

    # 创建里程碑
    milestones = []
    for ms in fx["milestones"]:
        m = client.create_milestone(goal["id"], ms["name"],
                                    target_desc=ms.get("target_desc"),
                                    target_value=ms.get("target_value"))
        assert m.get("id"), f"创建里程碑失败: {m}"
        milestones.append(m)

    # 创建行动计划
    ap_config = fx["action_plans"]
    ms_idx = ap_config["milestone_index"]
    action_plans = []
    for ap_name in ap_config["items"]:
        ap = client.create_action_plan(milestones[ms_idx]["id"], ap_name)
        assert ap.get("id"), f"创建行动计划失败: {ap}"
        action_plans.append(ap)

    # 创建习惯
    habits = []
    for hb in fx["habits"]:
        ap_ids = [action_plans[i]["id"] for i in hb.get("action_plan_indices", [])]
        h = client.create_habit(
            milestones[hb["milestone_index"]]["id"],
            hb["name"],
            frequency=hb["frequency"],
            action_plan_ids=ap_ids if ap_ids else None,
            two_min_ver=hb.get("two_min_ver"),
        )
        assert h.get("id"), f"创建习惯失败: {h}"
        habits.append(h)

    return {
        "goal": goal,
        "milestones": milestones,
        "action_plans": action_plans,
        "habits": habits,
    }
