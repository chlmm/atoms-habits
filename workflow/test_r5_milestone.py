"""
R5 里程碑推进: 用户坚持打卡 → 当前里程碑完成 → 下一个自动解锁 → 查看整体进度
布局: 时间线居中，写操作(左) | 读验证(右)
"""

import os
from cli_client import AtomsClient
from report import TestReport
from fixture_loader import load_fixture

REPORT_DIR = os.path.join(os.path.dirname(__file__), "reports")


def test_r5():
    c = AtomsClient()
    report = TestReport("R5 里程碑推进",
                        flow_desc="用户坚持打卡一段时间，当前里程碑完成后自动解锁下一个，最终查看目标整体进度从 0% → 100%")

    # ═══════════════ 准备数据 ═══════════════
    report.set_section("初始状态")
    data = load_fixture(c)
    goal_id = data["goal"]["id"]
    milestones = data["milestones"]
    m1, m2, m3, m4 = milestones

    # [读] 初始里程碑状态
    ms = c.get_milestones(goal_id)
    report.add_step(
        action="get_milestones 初始",
        readable_title="查看所有里程碑的初始状态",
        api_name="get_milestones",
        side="right",
        expected="m1=active, m2~4=waiting",
        actual=f"m1={ms[0]['status']}, m2={ms[1]['status']}, m3={ms[2]['status']}, m4={ms[3]['status']}",
        passed=ms[0]["status"] == "active" and all(m["status"] == "waiting" for m in ms[1:]),
    )

    progress = c.call("get_goal_progress", goal_id=goal_id)
    report.add_step(
        action="get_goal_progress 初始",
        readable_title="查看当前目标的整体进度（应为0%）",
        api_name="get_goal_progress",
        side="right",
        expected="0/4, 0.0%",
        actual=f"{progress['completed_milestones']}/{progress['total_milestones']}, {progress['progress_percent']}%",
        passed=progress["completed_milestones"] == 0 and progress["progress_percent"] == 0.0,
    )

    # ═══════════════ 里程碑①: 完成 1 个引体向上 ═══════════════
    report.set_section("里程碑①: 完成 1 个引体向上")

    r = c.call("update_milestone", id=m1["id"], current_value=1.0)
    report.add_step(
        action="update_milestone m1",
        readable_title="更新「引体向上」进度为 100%",
        api_name="update_milestone(current_value=1.0)",
        side="left",
        operation=r,
        expected=1.0,
        actual=r["current_value"],
        passed=r["current_value"] == 1.0,
    )

    r = c.call("complete_milestone", id=m1["id"])
    report.add_step(
        action="complete_milestone m1",
        readable_title="标记里程碑①为已完成",
        api_name="complete_milestone",
        side="left",
        operation=r,
        expected="status=completed",
        actual=r["status"],
        passed=r["status"] == "completed",
    )

    ms = c.get_milestones(goal_id)
    report.add_step(
        action="get_milestones after m1",
        readable_title="确认 m1 已完成、m2 自动激活",
        api_name="get_milestones",
        side="right",
        expected="m1=completed, m2=active, m3/m4=waiting",
        actual=f"m1={ms[0]['status']}, m2={ms[1]['status']}, m3={ms[2]['status']}, m4={ms[3]['status']}",
        passed=ms[0]["status"] == "completed" and ms[1]["status"] == "active",
    )

    progress = c.call("get_goal_progress", goal_id=goal_id)
    report.add_step(
        action="get_goal_progress 1/4",
        readable_title="查看当前进度（1个里程碑完成）",
        api_name="get_goal_progress",
        side="right",
        expected="1/4, >0%",
        actual=f"{progress['completed_milestones']}/{progress['total_milestones']}, {progress['progress_percent']}%",
        passed=progress["completed_milestones"] == 1,
    )

    # ═══════════════ 里程碑②: 完成 10 个标准引体 ═══════════════
    report.set_section("里程碑②: 完成 10 个标准引体")

    r = c.call("update_milestone", id=m2["id"], current_value=10.0)
    report.add_step(
        action="update_milestone m2",
        readable_title="更新「标准引体」进度为 100%",
        api_name="update_milestone(current_value=10.0)",
        side="left",
        operation=r,
        expected=10.0,
        actual=r["current_value"],
        passed=r["current_value"] == 10.0,
    )

    r = c.call("complete_milestone", id=m2["id"])
    report.add_step(
        action="complete_milestone m2",
        readable_title="标记里程碑②为已完成",
        api_name="complete_milestone",
        side="left",
        operation=r,
        expected="status=completed",
        actual=r["status"],
        passed=r["status"] == "completed",
    )

    ms = c.get_milestones(goal_id)
    report.add_step(
        action="get_milestones after m2",
        readable_title="确认 m2 已完成、m3 自动激活",
        api_name="get_milestones",
        side="right",
        expected="m2=completed, m3=active",
        actual=f"m2={ms[1]['status']}, m3={ms[2]['status']}",
        passed=ms[1]["status"] == "completed" and ms[2]["status"] == "active",
    )

    progress = c.call("get_goal_progress", goal_id=goal_id)
    report.add_step(
        action="get_goal_progress 2/4",
        readable_title="查看当前进度（2个里程碑完成）",
        api_name="get_goal_progress",
        side="right",
        expected="2/4, 50%",
        actual=f"{progress['completed_milestones']}/{progress['total_milestones']}, {progress['progress_percent']}%",
        passed=progress["completed_milestones"] == 2,
    )

    # ═══════════════ 里程碑③④: 连续完成 ═══════════════
    report.set_section("里程碑③④: 变体引体 → 双力臂")

    c.call("update_milestone", id=m3["id"], current_value=10.0)
    r = c.call("complete_milestone", id=m3["id"])
    report.add_step(
        action="complete_milestone m3",
        readable_title="标记里程碑③「变体引体」为已完成",
        api_name="complete_milestone",
        side="left",
        operation=r,
        expected="status=completed",
        actual=r["status"],
        passed=r["status"] == "completed",
    )

    ms = c.get_milestones(goal_id)
    report.add_step(
        action="get_milestones after m3",
        readable_title="确认 m3 已完成、m4 自动激活",
        api_name="get_milestones",
        side="right",
        expected="m3=completed, m4=active",
        actual=f"m3={ms[2]['status']}, m4={ms[3]['status']}",
        passed=ms[2]["status"] == "completed" and ms[3]["status"] == "active",
    )

    c.call("update_milestone", id=m4["id"], current_value=1.0)
    r = c.call("complete_milestone", id=m4["id"])
    report.add_step(
        action="complete_milestone m4",
        readable_title="标记里程碑④「双力臂」为已完成",
        api_name="complete_milestone",
        side="left",
        operation=r,
        expected="status=completed",
        actual=r["status"],
        passed=r["status"] == "completed",
    )

    # 最终验证
    progress = c.call("get_goal_progress", goal_id=goal_id)
    report.add_step(
        action="get_goal_progress 最终",
        readable_title="查看最终进度（应 100% 全部完成）",
        api_name="get_goal_progress",
        side="right",
        expected="4/4, 100%",
        actual=f"{progress['completed_milestones']}/{progress['total_milestones']}, {progress['progress_percent']}%",
        passed=progress["completed_milestones"] == 4 and progress["progress_percent"] == 100.0,
    )

    report.save_md(os.path.join(REPORT_DIR, "r5_milestone.md"))
    report.save_html(os.path.join(REPORT_DIR, "r5_milestone.html"))
    report.print_summary()


if __name__ == "__main__":
    test_r5()
