"""Create simple monitoring anomalies from the validated analysis outputs.

This is intentionally rule-based: no ML model, no external API, and no hidden
training step. Thresholds are monitoring heuristics, not business policy.
"""
from pathlib import Path
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "data" / "analysis_outputs"
FINDINGS = ROOT / "docs" / "findings"


def robust_z(series: pd.Series) -> pd.Series:
    s = pd.to_numeric(series, errors="coerce")
    med = s.median()
    mad = (s - med).abs().median()
    if pd.isna(mad) or mad == 0:
        return pd.Series(0.0, index=s.index)
    return 0.6745 * (s - med) / mad


def main() -> None:
    FINDINGS.mkdir(parents=True, exist_ok=True)
    rows = []

    monthly = pd.read_csv(OUT / "q07_monthly_promise_performance.csv")
    monthly["z_late_rate"] = robust_z(monthly["late_rate_pct"])
    flagged = monthly[monthly["z_late_rate"] >= 3].copy()
    for _, r in flagged.iterrows():
        rows.append({"type": "monthly_late_rate", "period": r["month"], "metric": "late_rate_pct", "value": r["late_rate_pct"], "rule": "robust_z >= 3"})

    lanes = pd.read_csv(OUT / "q12_lane_performance.csv")
    lanes["z_late_rate"] = robust_z(lanes["late_rate_pct"])
    flagged = lanes[lanes["z_late_rate"] >= 3].copy()
    for _, r in flagged.iterrows():
        rows.append({"type": "lane_late_rate", "period": r["lane"], "metric": "late_rate_pct", "value": r["late_rate_pct"], "rule": "robust_z >= 3"})

    sellers = pd.read_csv(OUT / "q15_seller_risk_quadrant.csv")
    high = sellers[(sellers["risk_flag"] == "HIGH") & (sellers["closed_orders"] >= 100)].copy()
    high = high.sort_values(["defect_rate_pct", "closed_orders"], ascending=[False, False])
    for _, r in high.head(20).iterrows():
        rows.append({"type": "seller_high_risk", "period": "all", "metric": "defect_rate_pct", "value": r["defect_rate_pct"], "rule": "HIGH defect risk + >=100 closed orders"})

    out = pd.DataFrame(rows, columns=["type", "period", "metric", "value", "rule"])
    out.to_csv(OUT / "anomalies.csv", index=False)

    md = ["# Rule-Based Monitoring Flags", "", "Generated from the validated Olist analysis outputs.", "", "## Rules", "- Monthly/lane lateness: robust z-score >= 3.", "- Seller risk: project-defined HIGH defect rate (>=25%) with at least 100 closed single-seller orders.", "", f"Total flags: **{len(out)}**", ""]
    if out.empty:
        md.append("No flags met the configured thresholds.")
    else:
        md += ["| Type | Period | Metric | Value | Rule |", "|---|---|---|---:|---|"]
        for _, r in out.iterrows():
            md.append(f"| {r['type']} | {r['period']} | {r['metric']} | {r['value']:.2f} | {r['rule']} |" if isinstance(r['value'], float) else f"| {r['type']} | {r['period']} | {r['metric']} | {r['value']} | {r['rule']} |")
    (FINDINGS / "anomaly_flags.md").write_text("\n".join(md) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
