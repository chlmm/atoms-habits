"""
Atoms CLI 客户端 — 基于通用 CliClient 框架的业务封装。
"""

import sys
import os

# 所有通用模块统一放在 /workspace/dart-modules 下
sys.path.insert(0, '/workspace/dart-modules/cli_bridge/lib/src')

from base_client import CliClient, CliError  # noqa: E402


class AtomsClient:
    """Atoms 项目 CLI 客户端 — 封装 CliClient 为 Atoms 专用方法"""

    def __init__(self, host: str = '127.0.0.1', port: int = 9999, timeout: float = 10.0):
        self._cli = CliClient(host=host, port=port, timeout=timeout)

    # ── R1 基础 ──────────────────────────────────

    def ping(self) -> dict:
        return self._cli.call('ping')

    def get_db_stats(self) -> dict:
        return self._cli.call('get_db_stats')

    def reset_db(self) -> dict:
        return self._cli.call('reset_db')

    def shutdown(self) -> dict:
        return self._cli.call('shutdown')

    # ── R2 数据写入 ───────────────────────────────

    def insert_demo_data(self) -> dict:
        return self._cli.call('insert_demo_data')

    def create_goal(self, name: str) -> dict:
        return self._cli.call('create_goal', name=name)

    def create_milestone(self, goal_id: int, name: str,
                         target_desc: str = None, target_value: float = None) -> dict:
        p = {'goal_id': goal_id, 'name': name}
        if target_desc is not None:
            p['target_desc'] = target_desc
        if target_value is not None:
            p['target_value'] = target_value
        return self._cli.call('create_milestone', **p)

    def create_action_plan(self, milestone_id: int, name: str) -> dict:
        return self._cli.call('create_action_plan', milestone_id=milestone_id, name=name)

    def create_habit(self, milestone_id: int, name: str, frequency: str = 'daily',
                     action_plan_ids: list = None, two_min_ver: str = None) -> dict:
        p = {'milestone_id': milestone_id, 'name': name, 'frequency': frequency}
        if action_plan_ids is not None:
            p['action_plan_ids'] = action_plan_ids
        if two_min_ver is not None:
            p['two_min_ver'] = two_min_ver
        return self._cli.call('create_habit', **p)

    # ── 查询 ──────────────────────────────────────

    def get_goals(self) -> list:
        return self._cli.call('get_goals')

    def get_milestones(self, goal_id: int) -> list:
        return self._cli.call('get_milestones', goal_id=goal_id)

    def get_action_plans(self, milestone_id: int) -> list:
        return self._cli.call('get_action_plans', milestone_id=milestone_id)

    def get_habits(self, milestone_id: int) -> list:
        return self._cli.call('get_habits', milestone_id=milestone_id)

    # ── R3 导航 ──────────────────────────────────

    def nav(self, route: str) -> dict:
        return self._cli.call('nav', route=route)

    def switch_face(self, face: str) -> dict:
        return self._cli.call('switch_face', face=face)

    def switch_goal(self, goal_id: int) -> dict:
        return self._cli.call('switch_goal', goal_id=goal_id)

    def navigate_back(self) -> dict:
        return self._cli.call('navigate_back')

    def get_current_state(self) -> dict:
        return self._cli.call('get_current_state')

    # ── 通用 call（测试脚本直接用）─────────────────

    def call(self, cmd: str, **params) -> dict:
        """透传任意命令到 CliClient.call()"""
        return self._cli.call(cmd, **params)
