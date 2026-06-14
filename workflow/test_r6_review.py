"""
R6 每周回顾测试: 用户坚持一周打卡 → 查看本周概览 → 保存周回顾 → 查看/更新回顾
布局: 时间线居中，写操作(左) | 读验证(右)
"""

import os
from datetime import date, timedelta
from cli_client import AtomsClient
from report import TestReport
from fixture_loader import load_fixture

REPORT_DIR = os.path.join(os.path.dirname(__file__), "reports")


def _week_dates(today: date) -> list[str]:
    """返回本周一到周日共 7 天的日期字符串列表"""
    # Monday=0, Sunday=6
    monday = today - timedelta(days=today.weekday())
    return [(monday + timedelta(days=i)).isoformat() for i in range(7)]


def _week_label(today: date) -> str:
    """返回本周的 week 标识, 如 2026-W24"""
    return today.strftime("%G-W%V")


def test_r6_review():
    c = AtomsClient()
    report = TestReport("R6 每周回顾",
                        flow_desc="用户坚持一周打卡后，查看本周习惯完成概览，写下反思保存周回顾，然后查看和更新回顾记录")
    today = date.today()
    week = _week_dates(today)
    week_label = _week_label(today)

    # ═══════════════ 准备数据 ═══════════════
    report.set_section("准备数据")
    data = load_fixture(c)
    goal_id = data["goal"]["id"]
    h1, h2 = data["habits"]
    h1_id, h2_id = h1["id"], h2["id"]
    h1_name, h2_name = h1["name"], h2["name"]

    report.add_step(
        action="load_fixture",
        readable_title="初始化目标、里程碑、习惯数据",
        api_name="load_fixture",
        side="left",
        operation=f"goal_id={goal_id}, habits=[{h1_name}, {h2_name}]",
        expected="返回含 goal + habits",
        actual=f"goal_id={goal_id}, h1_id={h1_id}, h2_id={h2_id}",
        passed=bool(goal_id and h1_id and h2_id),
    )

    # ═══════════════ 模拟一周打卡 ═══════════════
    report.set_section("模拟一周打卡")

    # 习惯1「练背计划」(every_other): 周一full, 周三full, 周五full, 周四skip, 其余空
    h1_schedule = {
        0: "full",   # 周一
        2: "full",   # 周三
        3: "skipped",  # 周四 skip
        4: "full",   # 周五
    }

    # 习惯2「核心训练」(twice_week): 周二full, 周四two_min, 其余空
    h2_schedule = {
        1: "full",    # 周二
        3: "two_min", # 周四
    }

    # 打卡习惯1
    for day_idx, status in h1_schedule.items():
        d = week[day_idx]
        log = c.call("complete_habit", habit_id=h1_id, status=status, date=d)
        day_name = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"][day_idx]
        status_cn = {"full": "完整完成", "skipped": "跳过", "two_min": "两分钟版"}[status]
        report.add_step(
            action=f"complete_habit_h1_{d}",
            readable_title=f"打卡「{h1_name}」— {day_name}{status_cn}",
            api_name="complete_habit",
            side="left",
            operation=log,
            expected=f"date={d}, status={status}",
            actual=f"date={log.get('date')}, status={log.get('status')}",
            passed=log.get("date") == d and log.get("status") == status,
        )

    # 打卡习惯2
    for day_idx, status in h2_schedule.items():
        d = week[day_idx]
        log = c.call("complete_habit", habit_id=h2_id, status=status, date=d)
        day_name = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"][day_idx]
        status_cn = {"full": "完整完成", "skipped": "跳过", "two_min": "两分钟版"}[status]
        report.add_step(
            action=f"complete_habit_h2_{d}",
            readable_title=f"打卡「{h2_name}」— {day_name}{status_cn}",
            api_name="complete_habit",
            side="left",
            operation=log,
            expected=f"date={d}, status={status}",
            actual=f"date={log.get('date')}, status={log.get('status')}",
            passed=log.get("date") == d and log.get("status") == status,
        )

    # ═══════════════ 查看本周概览 ═══════════════
    report.set_section("查看本周概览")

    # 习惯1本周日志
    logs_h1 = c.call("get_logs_week", habit_id=h1_id)
    h1_full_count = sum(1 for l in logs_h1 if l.get("status") == "full")
    h1_total = len(logs_h1)
    report.add_step(
        action="get_logs_week_h1",
        readable_title=f"查看「{h1_name}」本周打卡记录",
        api_name="get_logs_week",
        side="right",
        expected=f"至少 3 条(full), 共 4 条",
        actual=f"full={h1_full_count}, 共 {h1_total} 条",
        passed=h1_full_count >= 3 and h1_total == 4,
    )

    # 习惯2本周日志
    logs_h2 = c.call("get_logs_week", habit_id=h2_id)
    h2_count = len(logs_h2)
    report.add_step(
        action="get_logs_week_h2",
        readable_title=f"查看「{h2_name}」本周打卡记录",
        api_name="get_logs_week",
        side="right",
        expected=f"2 条记录",
        actual=f"共 {h2_count} 条",
        passed=h2_count == 2,
    )

    # ═══════════════ 保存周回顾 ═══════════════
    report.set_section("保存周回顾")

    notes = "练背计划坚持得不错，核心训练周四只做了两分钟版，下周争取完整完成。"
    review = c.call("save_review", goal_id=goal_id, week=week_label, notes=notes)
    report.add_step(
        action="save_review",
        readable_title=f"保存本周回顾（{week_label}）",
        api_name="save_review",
        side="left",
        operation=review,
        expected="返回含 id, week, notes",
        actual=f"id={review.get('id')}, week={review.get('week')}, notes={review.get('notes', '')[:20]}...",
        passed=bool(review.get("id")) and review.get("week") == week_label,
    )

    # [读] 查看回顾记录
    reviews = c.call("get_reviews", goal_id=goal_id)
    review_match = [r for r in reviews if r.get("week") == week_label]
    report.add_step(
        action="get_reviews",
        readable_title=f"查看目标下的回顾记录",
        api_name="get_reviews",
        side="right",
        expected=f"包含 week={week_label} 的回顾",
        actual=f"共 {len(reviews)} 条, 匹配={len(review_match)}",
        passed=len(review_match) >= 1,
    )

    # ═══════════════ 更新回顾 ═══════════════
    report.set_section("更新回顾")

    updated_notes = notes + "\n补充：周六加练了一次悬吊，感觉进步明显。"
    review2 = c.call("save_review", goal_id=goal_id, week=week_label, notes=updated_notes)
    report.add_step(
        action="save_review_update",
        readable_title=f"更新本周回顾内容",
        api_name="save_review",
        side="left",
        operation=review2,
        expected="notes 包含补充内容",
        actual=f"notes长度 {len(review2.get('notes', ''))} 字符",
        passed="补充" in review2.get("notes", ""),
    )

    # [读] 确认更新生效
    reviews2 = c.call("get_reviews", goal_id=goal_id)
    updated_review = next((r for r in reviews2 if r.get("week") == week_label), None)
    report.add_step(
        action="get_reviews_verify",
        readable_title="确认回顾内容已更新",
        api_name="get_reviews",
        side="right",
        expected="notes 包含「补充」",
        actual=f"包含补充={'是' if updated_review and '补充' in updated_review.get('notes', '') else '否'}",
        passed=updated_review is not None and "补充" in updated_review.get("notes", ""),
    )

    # ═══════════════ 全局回顾 ═══════════════
    report.set_section("全局回顾")

    all_reviews = c.call("get_reviews")
    report.add_step(
        action="get_reviews_all",
        readable_title="查看所有目标的回顾记录",
        api_name="get_reviews",
        side="right",
        expected=f"至少 1 条",
        actual=f"共 {len(all_reviews)} 条",
        passed=len(all_reviews) >= 1,
    )

    # ═══════════════ 保存报告 ═══════════════
    report.save_md(os.path.join(REPORT_DIR, "r6_review.md"))
    report.save_html(os.path.join(REPORT_DIR, "r6_review.html"))
    report.print_summary()


if __name__ == "__main__":
    test_r6_review()
