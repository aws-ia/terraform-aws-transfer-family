"""Summary stage — generate a human-readable HTML report from the processed claim.

This runs as the final stage after classification. It reads the fully-processed
claim record from DynamoDB and writes a self-contained HTML file to S3 at
`{claim_id}/summary.html`.

Claims reviewers can view this file directly in the Transfer Family web app,
via a pre-signed S3 URL, or by downloading it from the console.

The HTML is intentionally self-contained (inline CSS, no external assets, no
JavaScript) so it renders correctly from S3 without any additional configuration.
"""

import html
import json
import logging
import os
from datetime import datetime, timezone
from decimal import Decimal

import boto3

logger = logging.getLogger(__name__)

CLAIMS_BUCKET = os.environ.get("CLAIMS_BUCKET", "")

s3_client = boto3.client("s3")


# ── Formatting helpers ───────────────────────────────────────────────────────


def _to_plain(obj):
    """Convert DynamoDB Decimals / nested structures into JSON-serializable values."""
    if isinstance(obj, Decimal):
        num = float(obj)
        return int(num) if num.is_integer() else num
    if isinstance(obj, dict):
        return {k: _to_plain(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_to_plain(v) for v in obj]
    return obj


def _fmt_currency(value) -> str:
    try:
        n = float(value)
        return f"${n:,.2f}" if n % 1 else f"${int(n):,}"
    except (TypeError, ValueError):
        return html.escape(str(value))


def _fmt_dt(iso: str) -> str:
    if not iso:
        return "—"
    try:
        dt = datetime.fromisoformat(iso.replace("Z", "+00:00"))
        return dt.strftime("%Y-%m-%d %H:%M UTC")
    except (ValueError, TypeError):
        return html.escape(str(iso))


def _esc(value) -> str:
    """HTML-escape a value, handling None and non-strings."""
    if value is None:
        return "—"
    return html.escape(str(value))


def _unwrap(field):
    """Unwrap a `{value, confidence}` envelope to just the value (or pass through)."""
    if isinstance(field, dict) and "value" in field:
        return field["value"]
    return field


def _confidence(field):
    """Extract the confidence from a `{value, confidence}` envelope, or None."""
    if isinstance(field, dict) and "confidence" in field:
        try:
            return float(field["confidence"])
        except (TypeError, ValueError):
            return None
    return None


# ── Section builders ─────────────────────────────────────────────────────────


_STATUS_CLASSES = {
    "approved": "ok",
    "completed": "ok",
    "requires_review": "warn",
    "rejected": "err",
    "error": "err",
}


def _render_header(claim: dict) -> str:
    claim_id = _esc(claim.get("claim_id"))
    classification = claim.get("classification") or {}
    outcome = str(classification.get("outcome", claim.get("status", "unknown"))).lower()
    outcome_class = _STATUS_CLASSES.get(outcome, "neutral")
    return f"""
<header>
  <div class="brand">AnyCompany Insurance — Claims Review</div>
  <div class="claim-header">
    <h1>Claim {claim_id}</h1>
    <span class="badge badge-{outcome_class}">{outcome.replace("_", " ").upper()}</span>
  </div>
  <div class="meta">
    <span>Created: {_fmt_dt(claim.get("created_at"))}</span>
    <span>Last updated: {_fmt_dt(claim.get("updated_at"))}</span>
  </div>
</header>
"""


def _render_summary(claim: dict) -> str:
    classification = claim.get("classification") or {}
    summary_text = classification.get("summary") or ""
    if not summary_text:
        return ""
    return f"""
<section class="card">
  <h2>Summary</h2>
  <p class="summary">{_esc(summary_text)}</p>
</section>
"""


def _render_documents(claim: dict) -> str:
    documents = claim.get("documents") or []
    if not documents:
        return ""
    rows = []
    for doc in documents:
        s3_path = _esc(doc.get("s3_path"))
        doc_type = _esc(doc.get("doc_type"))
        extracted = doc.get("extracted") or {}
        highlights = []
        for key, field in extracted.items():
            value = _unwrap(field)
            conf = _confidence(field)
            if value is None or value == "":
                continue
            display = value
            if isinstance(value, list):
                display = ", ".join(str(v) for v in value[:3])
                if len(value) > 3:
                    display += ", …"
            conf_suffix = f" <span class=\"conf\">({conf:.2f})</span>" if conf is not None else ""
            highlights.append(f"<li><strong>{_esc(key)}:</strong> {_esc(display)}{conf_suffix}</li>")
            if len(highlights) >= 4:
                break
        highlights_html = (
            f"<ul class=\"kv\">{''.join(highlights)}</ul>"
            if highlights
            else "<span class=\"muted\">No fields extracted.</span>"
        )
        rows.append(
            f"""
<tr>
  <td class="mono">{s3_path}</td>
  <td>{doc_type}</td>
  <td>{highlights_html}</td>
</tr>
"""
        )
    return f"""
<section class="card">
  <h2>Documents <span class="count">({len(documents)})</span></h2>
  <table class="docs">
    <thead><tr><th>File</th><th>Type</th><th>Key fields</th></tr></thead>
    <tbody>{''.join(rows)}</tbody>
  </table>
</section>
"""


def _render_damage(claim: dict) -> str:
    damage = claim.get("damage_assessment") or {}
    if not damage:
        return ""
    items = damage.get("damage_items") or []
    cost_estimate = damage.get("cost_estimate") or {}
    items_html = []
    for item in items:
        dtype = _esc(item.get("damage_type"))
        severity = _esc(item.get("severity"))
        affected = _esc(item.get("affected_area"))
        desc = _esc(item.get("description"))
        items_html.append(
            f"""
<div class="damage-item">
  <div class="damage-head">
    <span class="damage-type">{dtype}</span>
    <span class="damage-sev">{severity}</span>
  </div>
  <div class="muted">{affected}</div>
  <p>{desc}</p>
</div>
"""
        )
    line_rows = []
    for li in cost_estimate.get("line_items") or []:
        desc = _esc(li.get("description"))
        cost = _fmt_currency(li.get("cost"))
        line_rows.append(f"<tr><td>{desc}</td><td class=\"num\">{cost}</td></tr>")
    total = cost_estimate.get("total")
    total_row = (
        f"<tr class=\"total\"><td>Total</td><td class=\"num\">{_fmt_currency(total)}</td></tr>"
        if total is not None
        else ""
    )
    line_table = (
        f"<table class=\"lineitems\"><tbody>{''.join(line_rows)}{total_row}</tbody></table>"
        if line_rows
        else ""
    )
    return f"""
<section class="card">
  <h2>Damage Assessment</h2>
  {''.join(items_html)}
  {line_table}
</section>
"""


def _render_fraud(claim: dict) -> str:
    fraud = claim.get("fraud_assessment") or {}
    if not fraud:
        return ""
    try:
        risk_score = float(fraud.get("risk_score") or 0)
    except (TypeError, ValueError):
        risk_score = 0.0
    risk_level = str(fraud.get("risk_level", "unknown")).lower()
    risk_class = {
        "low": "ok",
        "moderate": "warn",
        "low-moderate": "warn",
        "high": "err",
        "critical": "err",
    }.get(risk_level, "neutral")
    pct = max(0, min(100, int(round(risk_score * 100))))
    triggered_flags = [f for f in (fraud.get("flags") or []) if f.get("triggered")]
    flag_rows = []
    for f in triggered_flags:
        rid = _esc(f.get("rule_id"))
        detail = _esc(f.get("detail"))
        conf = _confidence({"confidence": f.get("confidence")})
        conf_str = f" <span class=\"conf\">({conf:.2f})</span>" if conf is not None else ""
        flag_rows.append(f"<li><strong>{rid}</strong>{conf_str}<br><span class=\"muted\">{detail}</span></li>")
    flags_html = (
        f"<ul class=\"flags\">{''.join(flag_rows)}</ul>"
        if flag_rows
        else "<p class=\"muted\">No fraud flags triggered.</p>"
    )
    return f"""
<section class="card">
  <h2>Fraud Assessment</h2>
  <div class="risk">
    <div class="risk-label">
      Risk score: <strong>{risk_score:.2f}</strong> / 1.00
      <span class="badge badge-{risk_class}">{risk_level.upper()}</span>
    </div>
    <div class="risk-bar"><div class="risk-fill" style="width:{pct}%"></div></div>
  </div>
  {flags_html}
</section>
"""


def _render_classification(claim: dict) -> str:
    classification = claim.get("classification") or {}
    if not classification:
        return ""
    outcome = str(classification.get("outcome", "")).lower()
    outcome_class = _STATUS_CLASSES.get(outcome, "neutral")
    conditions = classification.get("conditions_evaluated") or []
    triggered = [c for c in conditions if c.get("triggered")]
    cond_rows = []
    for c in triggered:
        cid = _esc(c.get("id"))
        group = _esc(c.get("outcome_group"))
        detail = _esc(c.get("detail"))
        cond_rows.append(
            f"<li><strong>{cid}</strong> "
            f"<span class=\"tag\">{group}</span><br>"
            f"<span class=\"muted\">{detail}</span></li>"
        )
    cond_html = (
        f"<ul class=\"conds\">{''.join(cond_rows)}</ul>"
        if cond_rows
        else "<p class=\"muted\">No conditions triggered.</p>"
    )
    return f"""
<section class="card">
  <h2>Classification</h2>
  <div class="outcome">
    Outcome: <span class="badge badge-{outcome_class}">{outcome.replace("_", " ").upper()}</span>
    <span class="muted">({len(triggered)} of {len(conditions)} conditions triggered)</span>
  </div>
  {cond_html}
</section>
"""


def _render_error(claim: dict) -> str:
    err = claim.get("processing_error") or {}
    if not err:
        return ""
    return f"""
<section class="card err-card">
  <h2>Processing Error</h2>
  <p><strong>Stage:</strong> {_esc(err.get("stage"))}</p>
  <p><strong>Message:</strong> <span class="mono">{_esc(err.get("message"))}</span></p>
</section>
"""


_CSS = """
:root {
  --bg: #f6f7f9;
  --fg: #1a1f2c;
  --muted: #6b7280;
  --card: #ffffff;
  --border: #e5e7eb;
  --ok-bg: #e6f5ea; --ok-fg: #166534;
  --warn-bg: #fef3c7; --warn-fg: #92400e;
  --err-bg: #fee2e2; --err-fg: #991b1b;
  --neutral-bg: #e5e7eb; --neutral-fg: #374151;
  --accent: #2563eb;
}
* { box-sizing: border-box; }
body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  background: var(--bg); color: var(--fg);
  margin: 0; padding: 2rem; line-height: 1.5;
}
.container { max-width: 960px; margin: 0 auto; }
header {
  background: var(--card);
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 1.5rem 1.75rem;
  margin-bottom: 1rem;
}
.brand { font-size: 0.85rem; color: var(--muted); letter-spacing: 0.05em; text-transform: uppercase; }
.claim-header { display: flex; align-items: center; gap: 1rem; margin: 0.25rem 0; }
.claim-header h1 { margin: 0; font-size: 1.75rem; }
.meta { display: flex; gap: 1.5rem; color: var(--muted); font-size: 0.875rem; flex-wrap: wrap; }
.card {
  background: var(--card);
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 1.25rem 1.75rem;
  margin-bottom: 1rem;
}
.card h2 { margin: 0 0 0.75rem 0; font-size: 1.15rem; }
.card h2 .count { color: var(--muted); font-weight: 400; }
.summary { margin: 0; }
.muted { color: var(--muted); font-size: 0.9rem; }
.mono { font-family: ui-monospace, "SFMono-Regular", Menlo, monospace; font-size: 0.85rem; }
.badge {
  display: inline-block;
  padding: 0.15rem 0.6rem;
  border-radius: 999px;
  font-size: 0.75rem;
  font-weight: 600;
  letter-spacing: 0.02em;
}
.badge-ok { background: var(--ok-bg); color: var(--ok-fg); }
.badge-warn { background: var(--warn-bg); color: var(--warn-fg); }
.badge-err { background: var(--err-bg); color: var(--err-fg); }
.badge-neutral { background: var(--neutral-bg); color: var(--neutral-fg); }
.tag {
  background: var(--neutral-bg); color: var(--neutral-fg);
  padding: 0.05rem 0.5rem;
  border-radius: 4px;
  font-size: 0.7rem;
  font-weight: 500;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
table { width: 100%; border-collapse: collapse; }
th, td { text-align: left; padding: 0.5rem 0.75rem; border-bottom: 1px solid var(--border); vertical-align: top; }
th { font-size: 0.8rem; color: var(--muted); font-weight: 600; text-transform: uppercase; letter-spacing: 0.03em; }
table.docs td.mono { max-width: 260px; word-break: break-all; }
.num { text-align: right; font-variant-numeric: tabular-nums; }
.lineitems .total td { font-weight: 700; border-top: 2px solid var(--border); border-bottom: none; }
.kv { margin: 0; padding-left: 1rem; font-size: 0.9rem; }
.kv li { margin-bottom: 0.15rem; }
.conf { color: var(--muted); font-size: 0.8rem; }
.damage-item { padding: 0.5rem 0; border-bottom: 1px solid var(--border); }
.damage-item:last-of-type { border-bottom: none; }
.damage-head { display: flex; gap: 0.5rem; align-items: center; font-weight: 600; margin-bottom: 0.2rem; }
.damage-sev { font-size: 0.75rem; padding: 0.1rem 0.5rem; border-radius: 4px; background: var(--neutral-bg); color: var(--neutral-fg); }
.damage-item p { margin: 0.25rem 0 0 0; }
.risk { margin-bottom: 1rem; }
.risk-label { margin-bottom: 0.4rem; font-size: 0.95rem; }
.risk-bar { background: var(--border); height: 8px; border-radius: 4px; overflow: hidden; }
.risk-fill { background: var(--accent); height: 100%; }
.flags, .conds { margin: 0; padding-left: 1.1rem; }
.flags li, .conds li { margin-bottom: 0.6rem; }
.outcome { margin-bottom: 0.75rem; display: flex; gap: 0.5rem; align-items: center; flex-wrap: wrap; }
.err-card { border-color: var(--err-fg); }
footer { color: var(--muted); font-size: 0.8rem; text-align: center; padding: 2rem 0 0 0; }
"""


# ── Public stage interface ───────────────────────────────────────────────────


def should_run(claim: dict) -> bool:
    """Always runs as the final stage — even on pipeline errors we still want a report."""
    return True


def invoke(claim_id: str, claim: dict) -> dict:
    """Read the claim record and render summary.html; no agent invocation."""
    plain_claim = _to_plain(dict(claim))
    html_body = "".join(
        [
            _render_header(plain_claim),
            _render_summary(plain_claim),
            _render_documents(plain_claim),
            _render_damage(plain_claim),
            _render_fraud(plain_claim),
            _render_classification(plain_claim),
            _render_error(plain_claim),
        ]
    )
    html_doc = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Claim {html.escape(str(claim_id))} — Summary</title>
  <style>{_CSS}</style>
</head>
<body>
<div class="container">
{html_body}
<footer>Generated by claims-orchestrator · claim {html.escape(str(claim_id))}</footer>
</div>
</body>
</html>
"""
    key = f"{claim_id}/summary.html"
    s3_client.put_object(
        Bucket=CLAIMS_BUCKET,
        Key=key,
        Body=html_doc.encode("utf-8"),
        ContentType="text/html; charset=utf-8",
        CacheControl="no-cache",
    )
    logger.info("Wrote summary HTML to s3://%s/%s (%d bytes)", CLAIMS_BUCKET, key, len(html_doc))
    return {"summary_key": key, "summary_size": len(html_doc)}


def update(claim_id: str, result: dict, table, **kwargs) -> None:
    """Record where the summary was written."""
    if result.get("skipped"):
        return
    table.update_item(
        Key={"claim_id": claim_id},
        UpdateExpression="SET summary_s3_key = :k, updated_at = :ts",
        ExpressionAttributeValues={
            ":k": result.get("summary_key", ""),
            ":ts": datetime.now(timezone.utc).isoformat(),
        },
    )
    logger.info("Claim %s: summary key recorded", claim_id)
