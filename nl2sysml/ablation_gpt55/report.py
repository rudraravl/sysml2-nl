"""HTML report rendering for the GPT-5.5 executable-rule study."""

from __future__ import annotations

import csv
import html
from pathlib import Path

from config import HTML_REPORT, RESULT_CSV


def render_html(csv_path: Path = RESULT_CSV, html_path: Path = HTML_REPORT) -> None:
    rows = list(csv.DictReader(csv_path.open("r", encoding="utf-8")))
    rule_ids = [
        "ACCEPTEVENTOUTPUT",
        "MESSAGEFLOWNEEDED",
        "MESSAGESIGNATURE",
        "STMINTEGRITY",
        "SUBMACHINESTR",
    ]

    totals = {
        "prompts": len(rows),
        "compiler_valid": sum(1 for r in rows if r.get("compiler_valid") == "true"),
        "rule_pass": sum(int(r.get("rule_pass_count", 0) or 0) for r in rows),
        "rule_fail": sum(int(r.get("rule_fail_count", 0) or 0) for r in rows),
        "rule_na": sum(int(r.get("rule_not_applicable_count", 0) or 0) for r in rows),
        "rule_unsupported": sum(int(r.get("rule_unsupported_count", 0) or 0) for r in rows),
    }

    by_rule = []
    for rule in rule_ids:
        counts = {
            "pass": sum(1 for r in rows if r.get(f"{rule}_status") == "pass"),
            "fail": sum(1 for r in rows if r.get(f"{rule}_status") == "fail"),
            "not_applicable": sum(1 for r in rows if r.get(f"{rule}_status") == "not_applicable"),
            "unsupported": sum(1 for r in rows if r.get(f"{rule}_status") == "unsupported"),
        }
        by_rule.append((rule, counts))

    def esc(value: object) -> str:
        return html.escape(str(value if value is not None else ""))

    summary_cards = f"""
      <section class="summary">
        <div><span>{totals['prompts']}</span><label>Prompts</label></div>
        <div><span>{totals['compiler_valid']}</span><label>Compiler valid</label></div>
        <div><span>{totals['rule_pass']}</span><label>Rule passes</label></div>
        <div><span>{totals['rule_fail']}</span><label>Rule failures</label></div>
        <div><span>{totals['rule_na']}</span><label>Not applicable</label></div>
        <div><span>{totals['rule_unsupported']}</span><label>Unsupported</label></div>
      </section>
    """

    rule_rows = "\n".join(
        "<tr>"
        f"<th>{esc(rule)}</th>"
        f"<td>{counts['pass']}</td>"
        f"<td>{counts['fail']}</td>"
        f"<td>{counts['not_applicable']}</td>"
        f"<td>{counts['unsupported']}</td>"
        "</tr>"
        for rule, counts in by_rule
    )

    prompt_rows = []
    for row in rows:
        cells = [
            f"<th>{esc(row.get('prompt_id'))}</th>",
            f"<td class='desc'>{esc(row.get('description'))}</td>",
            f"<td>{esc(row.get('compiler_valid'))}</td>",
            f"<td>{esc(row.get('compiler_error_count'))}</td>",
        ]
        for rule in rule_ids:
            status = row.get(f"{rule}_status", "")
            rationale = row.get(f"{rule}_rationale", "")
            cells.append(f"<td class='status {esc(status)}' title='{esc(rationale)}'>{esc(status)}</td>")
        prompt_rows.append("<tr>" + "".join(cells) + "</tr>")

    document = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>GPT-5.5 Executable Rule Ablation</title>
  <style>
    :root {{
      color-scheme: light;
      --bg: #f7f8fa;
      --panel: #ffffff;
      --text: #18202a;
      --muted: #667085;
      --line: #d9dee7;
      --pass: #0f7b45;
      --fail: #b42318;
      --na: #667085;
      --unsupported: #8a5a00;
    }}
    body {{
      margin: 0;
      font: 14px/1.45 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: var(--bg);
      color: var(--text);
    }}
    header, main {{ max-width: 1240px; margin: 0 auto; padding: 24px; }}
    header {{ padding-bottom: 8px; }}
    h1 {{ margin: 0 0 6px; font-size: 28px; letter-spacing: 0; }}
    p {{ margin: 0; color: var(--muted); }}
    .summary {{
      display: grid;
      grid-template-columns: repeat(6, minmax(120px, 1fr));
      gap: 12px;
      margin: 16px 0 24px;
    }}
    .summary div {{
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 14px;
    }}
    .summary span {{ display: block; font-size: 24px; font-weight: 700; }}
    .summary label {{ color: var(--muted); font-size: 12px; }}
    section.table {{
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 8px;
      margin-bottom: 22px;
      overflow: hidden;
    }}
    h2 {{ margin: 0; padding: 14px 16px; font-size: 16px; border-bottom: 1px solid var(--line); }}
    .scroll {{ overflow-x: auto; }}
    table {{ width: 100%; border-collapse: collapse; }}
    th, td {{ padding: 10px 12px; border-bottom: 1px solid var(--line); text-align: left; vertical-align: top; }}
    tr:last-child th, tr:last-child td {{ border-bottom: 0; }}
    th {{ white-space: nowrap; }}
    .desc {{ min-width: 280px; max-width: 520px; }}
    .status {{ font-weight: 650; white-space: nowrap; }}
    .pass {{ color: var(--pass); }}
    .fail {{ color: var(--fail); }}
    .not_applicable {{ color: var(--na); }}
    .unsupported {{ color: var(--unsupported); }}
    @media (max-width: 900px) {{
      .summary {{ grid-template-columns: repeat(2, minmax(120px, 1fr)); }}
      header, main {{ padding: 18px; }}
    }}
  </style>
</head>
<body>
  <header>
    <h1>GPT-5.5 Executable Rule Ablation</h1>
    <p>Compiler validity plus the five Executable Rules from the SysML 2 Rule Verification Guide.</p>
  </header>
  <main>
    {summary_cards}
    <section class="table">
      <h2>Rule Summary</h2>
      <div class="scroll">
        <table>
          <thead><tr><th>Rule</th><th>Pass</th><th>Fail</th><th>Not applicable</th><th>Unsupported</th></tr></thead>
          <tbody>{rule_rows}</tbody>
        </table>
      </div>
    </section>
    <section class="table">
      <h2>Prompt Results</h2>
      <div class="scroll">
        <table>
          <thead>
            <tr>
              <th>ID</th><th>Description</th><th>Compiler valid</th><th>Compiler errors</th>
              {''.join(f'<th>{esc(rule)}</th>' for rule in rule_ids)}
            </tr>
          </thead>
          <tbody>{''.join(prompt_rows)}</tbody>
        </table>
      </div>
    </section>
  </main>
</body>
</html>
"""
    html_path.write_text(document, encoding="utf-8")
