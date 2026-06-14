"""
Atoms CLI Bridge 客户端库
协议: TCP JSON line-delimited, 默认端口 9999
"""

import json
import socket
import time
from typing import Any

DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 9999
RECV_BUF = 65536


class AtomsClient:
    def __init__(self, host: str = DEFAULT_HOST, port: int = DEFAULT_PORT, timeout: float = 10.0):
        self.host = host
        self.port = port
        self.timeout = timeout

    def _send(self, cmd: dict) -> dict:
        """发送一条命令并等待响应。"""
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(self.timeout)
            s.connect((self.host, self.port))
            s.sendall((json.dumps(cmd) + "\n").encode())
            data = b""
            while True:
                chunk = s.recv(RECV_BUF)
                if not chunk:
                    break
                data += chunk
                if b"\n" in data:
                    break
        line = data.decode().strip()
        return json.loads(line)

    def call(self, cmd: str, **params) -> dict:
        """发送命令，返回 data 字段。出错抛 AssertionError。"""
        payload = {"cmd": cmd, **params}
        resp = self._send(payload)
        assert resp.get("status") == "ok", f"CLI error: {resp}"
        return resp.get("data", {})

    # ── R1 基础命令 ──────────────────────────────────

    def ping(self) -> dict:
        return self.call("ping")

    def get_db_stats(self) -> dict:
        return self.call("get_db_stats")

    def reset_db(self) -> dict:
        return self.call("reset_db")

    def shutdown(self) -> dict:
        return self.call("shutdown")

    # ── R2 数据命令 ──────────────────────────────────

    def insert_demo_data(self) -> dict:
        return self.call("insert_demo_data")

    def create_goal(self, name: str) -> dict:
        return self.call("create_goal", name=name)

    def create_milestone(self, goal_id: int, name: str,
                         target_desc: str = None, target_value: float = None) -> dict:
        p = {"goal_id": goal_id, "name": name}
        if target_desc is not None:
            p["target_desc"] = target_desc
        if target_value is not None:
            p["target_value"] = target_value
        return self.call("create_milestone", **p)

    def create_action_plan(self, milestone_id: int, name: str) -> dict:
        return self.call("create_action_plan", milestone_id=milestone_id, name=name)

    def create_habit(self, milestone_id: int, name: str, frequency: str = "daily",
                     action_plan_ids: list = None, two_min_ver: str = None) -> dict:
        p = {"milestone_id": milestone_id, "name": name, "frequency": frequency}
        if action_plan_ids is not None:
            p["action_plan_ids"] = action_plan_ids
        if two_min_ver is not None:
            p["two_min_ver"] = two_min_ver
        return self.call("create_habit", **p)

    def get_goals(self) -> list:
        return self.call("get_goals")

    def get_milestones(self, goal_id: int) -> list:
        return self.call("get_milestones", goal_id=goal_id)

    def get_action_plans(self, milestone_id: int) -> list:
        return self.call("get_action_plans", milestone_id=milestone_id)

    def get_habits(self, milestone_id: int) -> list:
        return self.call("get_habits", milestone_id=milestone_id)

    # ── R3 导航命令 ──────────────────────────────────

    def nav(self, route: str) -> dict:
        return self.call("nav", route=route)

    def switch_face(self, face: str) -> dict:
        return self.call("switch_face", face=face)

    def switch_goal(self, goal_id: int) -> dict:
        return self.call("switch_goal", goal_id=goal_id)

    def navigate_back(self) -> dict:
        return self.call("navigate_back")

    def get_current_state(self) -> dict:
        return self.call("get_current_state")
