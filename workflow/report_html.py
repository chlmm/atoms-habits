"""
HTML 报告生成器: 时间线居中 + 卡片按方向左右分布
布局:
    ┌── [左] create_goal ──────┐  ●  ┌── [右] ✓ get_goals 验证 ─────┐
    │  {'id':79,'name':'...'}  │  │  │  预期: 含 id    实际: 匹配1个  │
    │              ▶ 查看返回值│  │  │                    ▶ 详情      │
    └──────────────────────────┘     └───────────────────────────────┘

side="left"  → 写操作(增改删), 卡片在时间线左侧
side="right" → 读验证(查询),   卡片在时间线右侧
"""

import json
from datetime import datetime
from typing import Any


def generate_html(report) -> str:
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    steps_html = _build_timeline(report.steps)
    summary_html = _build_summary(report)

    return f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{_esc(report.title)}</title>
<style>
  :root {{
    --bg: #0d1117;
    --card: #161b22;
    --card-hover: #1c2128;
    --border: #30363d;
    --border-light: #21262d;
    --text: #c9d1d9;
    --text-dim: #8b949e;
    --text-bright: #f0f6fc;
    --pass: #3fb950;
    --pass-bg: rgba(63,185,80,0.10);
    --fail: #f85149;
    --fail-bg: rgba(248,81,73,0.10);
    --accent: #58a6ff;
    --accent-bg: rgba(88,166,255,0.10);
    --op-color: #a371f7;
    --op-bg: rgba(163,113,247,0.08);
    --op-border: rgba(163,113,247,0.30);
    --verify-color: #79c0ff;
    --verify-bg: rgba(121,192,255,0.06);
    --verify-border: rgba(121,192,255,0.25);
    --timeline-line: #30363d;
    --timeline-dot: #58a6ff;
  }}

  * {{ margin: 0; padding: 0; box-sizing: border-box; }}

  body {{
    font-family: -apple-system, "SF Pro Text", "Helvetica Neue", "Segoe UI", sans-serif;
    background: var(--bg);
    color: var(--text);
    line-height: 1.6;
    padding: 32px 16px;
  }}

  .container {{
    max-width: 1200px;
    margin: 0 auto;
  }}

  /* ── Header ── */
  .header {{
    text-align: center;
    margin-bottom: 36px;
  }}
  .header h1 {{
    font-size: 22px;
    font-weight: 700;
    color: var(--text-bright);
    margin-bottom: 8px;
  }}
  .header .flow-desc {{
    font-size: 13px;
    color: var(--text-dim);
    max-width: 700px;
    margin: 0 auto 12px;
    line-height: 1.8;
  }}
  .header .meta {{
    font-size: 11px;
    color: var(--text-dim);
  }}

  /* ── Summary ── */
  .summary {{
    display: flex;
    justify-content: center;
    gap: 16px;
    margin-bottom: 40px;
    flex-wrap: wrap;
  }}
  .summary-item {{
    background: var(--card);
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 14px 28px;
    text-align: center;
    min-width: 100px;
  }}
  .summary-item .num {{
    font-size: 26px;
    font-weight: 700;
  }}
  .summary-item .label {{
    font-size: 11px;
    color: var(--text-dim);
    margin-top: 2px;
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }}
  .summary-item.pass .num {{ color: var(--pass); }}
  .summary-item.fail .num {{ color: var(--fail); }}
  .summary-item.total .num {{ color: var(--accent); }}

  /* ═══════════ Timeline — 居中时间线 + 卡片左右分布 ═══════════ */

  .timeline {{
    position: relative;
    max-width: 1100px;
    margin: 0 auto;
  }}
  /* 时间线竖线 */
  .timeline::before {{
    content: '';
    position: absolute;
    left: 50%;
    top: 0;
    bottom: 0;
    width: 2px;
    background: var(--timeline-line);
    transform: translateX(-50%);
  }}

  /* Section 分隔 */
  .section-divider {{
    position: relative;
    margin: 28px 0 16px;
    padding: 8px 20px;
    font-size: 13px;
    font-weight: 600;
    color: var(--accent);
    letter-spacing: 0.03em;
    background: linear-gradient(90deg, transparent, var(--accent-bg), transparent);
    border-radius: 6px;
    text-align: center;
  }}

  /* ══ Step row — 占满整行，卡片按 side 偏移 ══ */
  .step-row {{
    position: relative;
    width: 100%;
    margin-bottom: 8px;
    display: flex;
    align-items: flex-start;
  }}

  /* 时间线节点 */
  .tl-node {{
    position: absolute;
    left: 50%;
    top: 16px;
    transform: translateX(-50%);
    width: 14px;
    height: 14px;
    border-radius: 50%;
    background: var(--timeline-dot);
    border: 3px solid var(--bg);
    z-index: 3;
    transition: transform 0.2s, box-shadow 0.2s;
  }}
  .step-row:hover .tl-node {{
    transform: translateX(-50%) scale(1.3);
    box-shadow: 0 0 10px rgba(88,166,255,0.4);
  }}
  .step-row.failed .tl-node {{
    background: var(--fail);
    box-shadow: 0 0 8px rgba(248,81,73,0.3);
  }}

  /* 连接线: 从节点到卡片 */
  .tl-connector {{
    position: absolute;
    top: 22px;
    height: 2px;
    background: var(--timeline-line);
    z-index: 2;
  }}
  .step-row.side-left .tl-connector {{
    left: calc(50% - 30px);
    width: 24px;
    background: var(--op-border);
  }}
  .step-row.side-right .tl-connector {{
    left: calc(50% + 7px);
    width: 24px;
    background: var(--verify-border);
  }}

  /* ── 卡片（通用） ── */
  .card {{
    width: calc(50% - 40px);
    border-radius: 10px;
    overflow: hidden;
    cursor: pointer;
    transition: border-color 0.2s, box-shadow 0.2s, transform 0.15s;
  }}
  .card:hover {{
    transform: translateY(-1px);
  }}

  /* 左侧卡片 */
  .step-row.side-left .card {{
    margin-right: auto;
    border: 1px solid var(--op-border);
    background: var(--card);
  }}
  .step-row.side-left .card:hover,
  .step-row.side-left.expanded .card {{
    border-color: var(--op-color);
    box-shadow: 0 2px 12px rgba(163,113,247,0.12);
  }}

  /* 右侧卡片 */
  .step-row.side-right .card {{
    margin-left: auto;
    border: 1px solid var(--verify-border);
    background: var(--card);
  }}
  .step-row.side-right .card:hover,
  .step-row.side-right.expanded .card {{
    border-color: var(--accent);
    box-shadow: 0 2px 12px rgba(88,166,255,0.12);
  }}

  /* ── 卡片内部 ── */
  .card-header {{
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 10px 14px;
    border-bottom: 1px solid var(--border-light);
  }}
  .card-badge {{
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 22px;
    height: 22px;
    border-radius: 6px;
    font-size: 11px;
    font-weight: 700;
    flex-shrink: 0;
  }}
  /* 左侧 badge */
  .side-left .card-badge {{
    background: var(--op-bg);
    color: var(--op-color);
  }}
  /* 右侧 badge */
  .side-right .card-badge {{
    background: var(--accent-bg);
    color: var(--accent);
  }}
  .card-title {{
    font-size: 13px;
    font-weight: 600;
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }}
  .side-left .card-title {{ color: var(--op-color); }}
  .side-right .card-title {{ color: var(--verify-color); }}

  .card-tag {{
    font-size: 10px;
    color: var(--text-dim);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    flex-shrink: 0;
  }}

  /* 卡片内容区 */
  .card-body {{
    padding: 10px 14px;
    font-family: "SF Mono", "Fira Code", "Cascadia Code", monospace;
    font-size: 11.5px;
    color: var(--text-dim);
    min-height: 18px;
  }}

  /* 左侧: 操作返回值预览 */
  .op-preview {{
    word-break: break-all;
    color: var(--text);
    opacity: 0.8;
  }}

  /* 右侧: 预期 vs 实际 预览 */
  .verify-preview {{
    display: flex;
    align-items: center;
    gap: 16px;
    flex-wrap: wrap;
  }}
  .vp-field {{
    display: flex;
    align-items: center;
    gap: 5px;
    min-width: 0;
  }}
  .vp-label {{
    font-size: 10px;
    color: var(--text-dim);
    flex-shrink: 0;
    text-transform: uppercase;
  }}
  .vp-val {{
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    max-width: 200px;
  }}
  .vp-val.exp-c {{ color: var(--accent); }}
  .vp-val.act-c {{ color: var(--text); }}

  /* 右侧: 通过/失败图标 */
  .status-icon {{
    font-size: 15px;
    font-weight: 700;
    flex-shrink: 0;
  }}
  .step-row.passed .status-icon {{ color: var(--pass); }}
  .step-row.failed .status-icon {{ color: var(--fail); }}

  /* 展开提示 */
  .card-expand {{
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 4px;
    padding: 6px 14px;
    font-size: 11px;
    color: var(--text-dim);
    border-top: 1px solid var(--border-light);
    opacity: 0;
    transition: opacity 0.2s;
  }}
  .card:hover .card-expand,
  .step-row.expanded .card-expand {{
    opacity: 1;
  }}
  .arrow-ic {{
    transition: transform 0.2s;
    display: inline-block;
  }}
  .step-row.expanded .arrow-ic {{
    transform: rotate(90deg);
  }}

  /* ── 展开详情面板 ── */
  .card-detail {{
    display: none;
    border-top: 1px solid var(--border-light);
    padding: 14px;
    background: rgba(0,0,0,0.2);
  }}
  .step-row.expanded .card-detail {{
    display: block;
  }}

  /* 左侧详情: 双栏 — 执行操作 | 返回值 */
  .left-detail-grid {{
    display: grid;
    grid-template-columns: auto 1fr;
    gap: 12px;
  }}
  .ld-api-box {{
    border-radius: 8px;
    overflow: hidden;
    border: 1px solid var(--op-border);
    background: rgba(163,113,247,0.04);
  }}
  .ld-api-box .dp-head {{
    padding: 6px 12px;
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    background: var(--op-bg);
    color: var(--op-color);
  }}
  .ld-api-box .dp-body {{
    padding: 10px 12px;
  }}
  .ld-api-name {{
    font-family: "SF Mono", "Fira Code", monospace;
    font-size: 12px;
    color: var(--op-color);
    font-weight: 600;
  }}
  .ld-ret-box {{
    border-radius: 8px;
    overflow: hidden;
    border: 1px solid var(--border-light);
  }}
  .ld-ret-box .dp-head {{
    padding: 6px 12px;
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    background: rgba(139,148,158,0.08);
    color: var(--text-dim);
  }}
  .ld-ret-pre {{
    font-family: "SF Mono", "Fira Code", monospace;
    font-size: 11.5px;
    line-height: 1.65;
    white-space: pre-wrap;
    word-break: break-all;
    color: var(--text-bright);
    margin: 0;
    max-height: 280px;
    overflow-y: auto;
    padding: 10px 12px;
    background: rgba(255,255,255,0.01);
  }}

  /* 右侧详情: 三栏 — API接口 | 预期数据 | 实际数据 */
  .right-detail-grid {{
    display: grid;
    grid-template-columns: auto 1fr 1fr;
    gap: 10px;
  }}
  .rd-api-box {{
    border-radius: 8px;
    overflow: hidden;
    border: 1px solid var(--verify-border);
    background: rgba(121,192,255,0.04);
  }}
  .rd-api-box .dp-head {{
    padding: 5px 10px;
    font-size: 9px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    background: var(--verify-bg);
    color: var(--verify-color);
  }}
  .rd-api-body {{
    padding: 8px 10px;
  }}
  .rd-api-name {{
    font-family: "SF Mono", "Fira Code", monospace;
    font-size: 11px;
    color: var(--verify-color);
    font-weight: 600;
  }}
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
  }}
  .dp-box {{
    border-radius: 8px;
    overflow: hidden;
    border: 1px solid var(--border-light);
  }}
  .dp-head {{
    padding: 6px 12px;
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }}
  .dp-box.expected .dp-head {{
    background: var(--accent-bg);
    color: var(--accent);
  }}
  .dp-box.actual .dp-head {{
    background: rgba(139,148,158,0.08);
    color: var(--text-dim);
  }}
  .dp-body {{
    padding: 10px 12px;
    background: rgba(255,255,255,0.01);
  }}
  .dp-body pre {{
    font-family: "SF Mono", "Fira Code", monospace;
    font-size: 11.5px;
    line-height: 1.65;
    white-space: pre-wrap;
    word-break: break-all;
    color: var(--text);
    margin: 0;
    max-height: 260px;
    overflow-y: auto;
  }}

  /* ── 响应式 ── */
  @media (max-width: 800px) {{
    .timeline::before {{
      left: 20px;
    }}
    .tl-node {{
      left: 20px !important;
    }}
    .tl-connector {{
      display: none;
    }}
    .step-row {{
      flex-direction: column;
      padding-left: 44px;
    }}
    .card {{
      width: 100%;
    }}
    .step-row.side-left .card,
    .step-row.side-right .card {{
      margin: 0;
    }}
    .detail-grid,
    .left-detail-grid,
    .right-detail-grid {{
      grid-template-columns: 1fr;
    }}
  }}
</style>
</head>
<body>
<div class="container">
  <div class="header">
    <h1>{_esc(report.title)}</h1>
    {f'<p class="flow-desc">{_esc(report.flow_desc)}</p>' if report.flow_desc else ''}
    <div class="meta">生成时间: {now}</div>
  </div>

  {summary_html}

  <div class="timeline">
    {steps_html}
  </div>
</div>

<script>
document.querySelector('.timeline').addEventListener('click', function(e) {{
  var row = e.target.closest('.step-row');
  if (row) row.classList.toggle('expanded');
}});
document.querySelectorAll('.step-row.failed').forEach(function(el) {{
  el.classList.add('expanded');
}});
</script>
</body>
</html>"""


def _build_summary(report) -> str:
    total = len(report.steps)
    passed = report.passed_count
    failed = report.failed_count
    status = "✓ 全部通过" if failed == 0 else "✗ 存在失败"
    sc = "pass" if failed == 0 else "fail"

    return f"""
  <div class="summary">
    <div class="summary-item total"><div class="num">{total}</div><div class="label">总步骤</div></div>
    <div class="summary-item pass"><div class="num">{passed}</div><div class="label">通过</div></div>
    <div class="summary-item fail"><div class="num">{failed}</div><div class="label">失败</div></div>
    <div class="summary-item {sc}"><div class="num" style="font-size:17px">{status}</div><div class="label">结果</div></div>
  </div>"""


def _build_timeline(steps) -> str:
    parts = []
    last_section = None

    for s in steps:
        # Section 分隔线
        if s.section and s.section != last_section:
            parts.append(f'<div class="section-divider">{_esc(s.section)}</div>')
            last_section = s.section

        status_cls = s.status_cls
        side_cls = f"side-{s.side}"
        icon = "✓" if s.passed else "✗"

        if s.side == "left":
            card_html = _build_left_card(s)
        else:
            card_html = _build_right_card(s, icon)

        parts.append(f"""<div class="step-row {status_cls} {side_cls}">
  <div class="tl-node"></div>
  <div class="tl-connector"></div>
  {card_html}
</div>""")

    return "\n".join(parts)


def _build_left_card(s) -> str:
    """左侧卡片: 写操作 + 返回值，详情双栏[执行操作|返回值]"""
    op_preview = _preview(s.operation, 80) if s.operation is not None else '<em>—</em>'
    op_full = _fmt(s.operation)
    api_name = s.api_name or s.action

    return f"""<div class="card">
  <div class="card-header">
    <span class="card-badge">{s.step_no}</span>
    <span class="card-title">{_esc(s.readable_title)}</span>
    <span class="card-tag">操作</span>
  </div>
  <div class="card-body">
    <div class="op-preview">{op_preview}</div>
  </div>
  <div class="card-expand"><span class="arrow-ic">▶</span> 查看返回值</div>
  <div class="card-detail">
    <div class="left-detail-grid">
      <div class="ld-api-box">
        <div class="dp-head">执行操作</div>
        <div class="dp-body"><span class="ld-api-name">{_esc(api_name)}</span></div>
      </div>
      <div class="ld-ret-box">
        <div class="dp-head">返回值</div>
        <pre class="ld-ret-pre">{op_full}</pre>
      </div>
    </div>
  </div>
</div>"""


def _build_right_card(s, icon: str) -> str:
    """右侧卡片: 验证反馈 + 预期vs实际，详情三栏[API接口|预期|实际]"""
    exp_preview = _preview(s.expected, 55) if s.expected is not None else '<em>—</em>'
    act_preview = _preview(s.actual, 55) if s.actual is not None else '<em>—</em>'
    exp_full = _fmt(s.expected)
    act_full = _fmt(s.actual)
    api_name = s.api_name or s.action

    return f"""<div class="card">
  <div class="card-header">
    <span class="card-badge">{s.step_no}</span>
    <span class="card-title">{_esc(s.readable_title)}</span>
    <span class="status-icon">{icon}</span>
    <span class="card-tag">验证</span>
  </div>
  <div class="card-body">
    <div class="verify-preview">
      <span class="vp-field">
        <span class="vp-label">预期:</span>
        <span class="vp-val exp-c">{exp_preview}</span>
      </span>
      <span class="vp-field">
        <span class="vp-label">实际:</span>
        <span class="vp-val act-c">{act_preview}</span>
      </span>
    </div>
  </div>
  <div class="card-expand"><span class="arrow-ic">▶</span> 详情</div>
  <div class="card-detail">
    <div class="right-detail-grid">
      <div class="rd-api-box">
        <div class="dp-head">执行接口</div>
        <div class="rd-api-body"><span class="rd-api-name">{_esc(api_name)}</span></div>
      </div>
      <div class="dp-box expected">
        <div class="dp-head">预期数据</div>
        <div class="dp-body"><pre>{exp_full}</pre></div>
      </div>
      <div class="dp-box actual">
        <div class="dp-head">实际数据</div>
        <div class="dp-body"><pre>{act_full}</pre></div>
      </div>
    </div>
  </div>
</div>"""


# ── 工具函数 ──

def _preview(val: Any, max_len: int = 60) -> str:
    if val is None:
        return "<em>null</em>"
    if isinstance(val, bool):
        return str(val).lower()
    if isinstance(val, (int, float)):
        return str(val)
    if isinstance(val, str):
        try:
            parsed = json.loads(val)
            s = json.dumps(parsed, ensure_ascii=False)
        except (json.JSONDecodeError, TypeError):
            s = val
    elif isinstance(val, (dict, list)):
        s = json.dumps(val, ensure_ascii=False)
    else:
        s = str(val)
    if len(s) > max_len:
        return s[:max_len - 3] + "..."
    return s


def _fmt(val: Any) -> str:
    if val is None:
        return "<em style='color:var(--text-dim)'>null / 无</em>"
    if isinstance(val, bool):
        v = "true" if val else "false"
        return f"<strong>{v}</strong>"
    if isinstance(val, (int, float)):
        return str(val)
    if isinstance(val, str):
        try:
            parsed = json.loads(val)
            return _esc(json.dumps(parsed, ensure_ascii=False, indent=2))
        except (json.JSONDecodeError, TypeError):
            return _esc(val)
    if isinstance(val, (dict, list)):
        return _esc(json.dumps(val, ensure_ascii=False, indent=2))
    return _esc(str(val))


def _esc(text: str) -> str:
    return (str(text)
            .replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace('"', "&quot;"))
