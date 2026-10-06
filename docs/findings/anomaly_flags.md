# Rule-Based Monitoring Flags

Generated from the validated Olist analysis outputs.

## Rules
- Monthly/lane lateness: robust z-score >= 3.
- Seller risk: project-defined HIGH defect rate (>=25%) with at least 100 closed single-seller orders.

Total flags: **16**

| Type | Period | Metric | Value | Rule |
|---|---|---|---:|---|
| monthly_late_rate | 2016-09 | late_rate_pct | 100.00 | robust_z >= 3 |
| monthly_late_rate | 2017-11 | late_rate_pct | 12.40 | robust_z >= 3 |
| monthly_late_rate | 2018-02 | late_rate_pct | 14.13 | robust_z >= 3 |
| monthly_late_rate | 2018-03 | late_rate_pct | 18.96 | robust_z >= 3 |
| lane_late_rate | SP->AL | late_rate_pct | 23.92 | robust_z >= 3 |
| lane_late_rate | MA->SP | late_rate_pct | 20.33 | robust_z >= 3 |
| seller_high_risk | all | defect_rate_pct | 61.32 | HIGH defect risk + >=100 closed orders |
| seller_high_risk | all | defect_rate_pct | 50.81 | HIGH defect risk + >=100 closed orders |
| seller_high_risk | all | defect_rate_pct | 34.65 | HIGH defect risk + >=100 closed orders |
| seller_high_risk | all | defect_rate_pct | 32.56 | HIGH defect risk + >=100 closed orders |
| seller_high_risk | all | defect_rate_pct | 28.64 | HIGH defect risk + >=100 closed orders |
| seller_high_risk | all | defect_rate_pct | 28.15 | HIGH defect risk + >=100 closed orders |
| seller_high_risk | all | defect_rate_pct | 27.62 | HIGH defect risk + >=100 closed orders |
| seller_high_risk | all | defect_rate_pct | 27.52 | HIGH defect risk + >=100 closed orders |
| seller_high_risk | all | defect_rate_pct | 27.42 | HIGH defect risk + >=100 closed orders |
| seller_high_risk | all | defect_rate_pct | 25.42 | HIGH defect risk + >=100 closed orders |
