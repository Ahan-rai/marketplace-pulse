# Marketplace Pulse — Real Olist Outcome Data

Dataset: Brazilian E-Commerce Public Dataset by Olist (9 CSV files).
Analysis performed locally against the uploaded real CSVs. The transformations mirror the repository's staging/star-schema logic; this run was executed with pandas because PostgreSQL is not available in the current execution environment. Synthetic smoke-test values were not used.

## Source row counts

| Table | Rows |
|---|---:|
| orders | 99,441 |
| customers | 99,441 |
| order_items | 112,650 |
| payments | 103,886 |
| reviews | 99,224 |
| products | 32,951 |
| sellers | 3,095 |
| geolocation | 1,000,163 |
| category_translation | 71 |

Reviews after latest-per-order dedupe: 98,673 (551 rows removed).

## Core outcomes

- Delivered orders: 96,470
- Closed orders: 97,103
- Late delivered orders: 6,535
- Late rate among delivered orders: 6.77%
- Reviewed orders with 1–2 stars: 14.69%
- Defective closed orders using project proxy (cancelled OR late OR 1–2 stars): 15,450
- Defect rate among closed orders: 15.91%
- Multi-seller orders: 1,278 of 98,666 orders with at least one seller (1.30%); these are excluded from seller-level handoff metrics.

## Q1 — Monthly order volume / GMV / on-time rate

| Month | Orders | GMV | Delivered | On-time % |
|---|---:|---:|---:|---:|
| 2016-09 | 4 | 267 | 1 | 0.00 |
| 2016-10 | 324 | 49,508 | 265 | 99.25 |
| 2016-12 | 1 | 11 | 1 | 100.00 |
| 2017-01 | 800 | 120,313 | 750 | 97.07 |
| 2017-02 | 1,780 | 247,303 | 1,653 | 97.04 |
| 2017-03 | 2,682 | 374,344 | 2,546 | 95.44 |
| 2017-04 | 2,404 | 359,927 | 2,303 | 93.44 |
| 2017-05 | 3,700 | 506,071 | 3,545 | 97.01 |
| 2017-06 | 3,245 | 433,039 | 3,135 | 96.97 |
| 2017-07 | 4,026 | 498,031 | 3,872 | 97.21 |
| 2017-08 | 4,331 | 573,972 | 4,193 | 97.09 |
| 2017-09 | 4,285 | 624,402 | 4,150 | 95.61 |
| 2017-10 | 4,631 | 664,219 | 4,478 | 95.82 |
| 2017-11 | 7,544 | 1,010,271 | 7,288 | 87.60 |
| 2017-12 | 5,673 | 743,914 | 5,513 | 92.54 |
| 2018-01 | 7,269 | 950,030 | 7,069 | 94.30 |
| 2018-02 | 6,728 | 844,179 | 6,555 | 85.86 |
| 2018-03 | 7,211 | 983,213 | 7,003 | 81.04 |
| 2018-04 | 6,939 | 996,648 | 6,798 | 95.50 |
| 2018-05 | 6,873 | 996,518 | 6,749 | 93.44 |
| 2018-06 | 6,167 | 865,124 | 6,096 | 98.84 |
| 2018-07 | 6,292 | 895,507 | 6,156 | 96.62 |
| 2018-08 | 6,512 | 854,686 | 6,351 | 93.81 |
| 2018-09 | 16 | 145 | 0 | — |
| 2018-10 | 4 | 0 | 0 | — |

Operational breakpoints: on-time performance fell to 87.60% in Nov-2017, 85.86% in Feb-2018 and 81.04% in Mar-2018 before recovering to 95.50% in Apr-2018.

## Q2 — Late rate by customer state

Top states by late rate among delivered orders:

| State | Delivered | Late | Late % |
|---|---:|---:|---:|
| AL | 397 | 85 | 21.41 |
| MA | 717 | 125 | 17.43 |
| SE | 335 | 51 | 15.22 |
| PI | 476 | 66 | 13.87 |
| CE | 1,279 | 176 | 13.76 |
| BA | 3,256 | 396 | 12.16 |
| RJ | 12,350 | 1,495 | 12.11 |
| PA | 946 | 106 | 11.21 |

## Q2 — Worst lanes, minimum 30 delivered orders

| Lane | Delivered | Late | Late % |
|---|---:|---:|---:|
| PR->AL | 35 | 11 | 31.43 |
| SP->AL | 256 | 61 | 23.83 |
| RJ->CE | 54 | 11 | 20.37 |
| MA->SP | 124 | 25 | 20.16 |
| SP->MA | 493 | 94 | 19.07 |
| MG->AL | 35 | 6 | 17.14 |
| PR->MA | 41 | 7 | 17.07 |
| SP->SE | 207 | 34 | 16.43 |
| SP->PI | 329 | 54 | 16.41 |
| SP->RR | 33 | 5 | 15.15 |
| SP->RJ | 8,157 | 1,152 | 14.12 |
| SP->CE | 970 | 133 | 13.71 |

## Q3 — Lateness split

Among 6,535 late delivered orders:

| Handoff classification | Late orders | Share | Avg seller handoff days | Avg carrier transit days |
|---|---:|---:|---:|---:|
| Late handoff | 1,814 | 27.76% | 13.37 | 18.34 |
| On-time handoff | 4,721 | 72.24% | 2.54 | 31.56 |

Interpretation: under the project's classification, most late orders were late despite an on-time seller handoff, pointing toward the downstream transit portion as the larger contributor to lateness in this dataset.

## Q4 — Review score vs lateness

| Lateness bucket | Orders | Avg review | Low review % |
|---|---:|---:|---:|
| Early | 88,163 | 4.29 | 9.22 |
| On the day | 1,280 | 4.03 | 12.42 |
| 1–3 days late | 1,852 | 3.29 | 32.13 |
| 4–7 days late | 1,748 | 2.10 | 67.62 |
| 8+ days late | 2,781 | 1.70 | 79.29 |

The strongest rating deterioration appears once delivery is more than 3 days late: average review falls from 3.29 at 1–3 days late to 2.10 at 4–7 days late.

## Q5 — Seller defect ranking

Seller metrics use single-seller closed orders. The project uses the Wilson lower bound to avoid treating tiny samples as equally reliable.

Top sellers by Wilson lower bound, restricting the displayed table to sellers with at least 30 closed single-seller orders:

| Seller | Closed | Defective | Raw defect % | Wilson lower % | Wilson upper % |
|---|---:|---:|---:|---:|---:|
| 1ca7077d890b907f89be8c954a02686a | 106 | 65 | 61.32 | 51.81 | 70.04 |
| 2eb70248d66e0e3ef83659f71b244378 | 185 | 94 | 50.81 | 43.66 | 57.92 |
| 2a1348e9addc1af5aaa619b1a3679d6b | 46 | 22 | 47.83 | 34.12 | 61.86 |
| a49928bcdf77c55c6d6e05e09a9b4ca5 | 93 | 39 | 41.94 | 32.42 | 52.09 |
| 712e6ed8aa4aa1fa65abd41fed5737e4 | 77 | 33 | 42.86 | 32.40 | 53.99 |
| 972d0f9cf61b499a4812cf0bfa3ad3c4 | 75 | 32 | 42.67 | 32.10 | 53.95 |
| ad781527c93d00d89a11eecd9dcad7c1 | 34 | 16 | 47.06 | 31.45 | 63.26 |
| 54965bbe3e4f07ae045b90b0b8541f52 | 72 | 30 | 41.67 | 30.99 | 53.19 |
| 88460e8ebdecbfecb5f9601833981930 | 228 | 79 | 34.65 | 28.77 | 41.03 |
| 835f0f7810c76831d6c7d24c7a646d4d | 41 | 17 | 41.46 | 27.76 | 56.63 |

## Data-quality results

All 5 error-severity checks passed with zero failing rows. Non-zero warnings/info:

- 8 delivered-status orders missing delivery timestamp
- 6 orders have delivery timestamp but non-delivered status
- 1,359 carrier timestamps precede approval timestamps
- 775 orders have no order-item row
- 9 payment rows have zero/negative payment value
- 551 review rows removed by latest-per-order dedupe
- 610 products have missing category
- 13 non-null product categories have no translation row
- 278 customers have no matching aggregated geolocation row
- 7 sellers have no matching aggregated geolocation row
- 1,278 multi-seller orders are excluded from seller-level handoff metrics

## Resume-safe facts from this run

These can now be described as measured results from the real Olist data, provided the final implementation uses the same definitions:

- 99,441 orders across 9 source tables were analyzed.
- The pipeline's real data-quality review surfaced 19 checks, with zero failures on the error-severity checks.
- 6,535 delivered orders were late (6.77% of delivered orders).
- 72.24% of late delivered orders had an on-time seller handoff under the project's classification.
- Average review score fell to 1.70 for orders delivered 8+ days late, with 79.29% receiving a 1–2 star review.
- The highest-volume lane shown in the minimum-30-delivered lane analysis, SP->RJ, had 8,157 delivered orders and a 14.12% late rate.

Do not claim that PostgreSQL itself produced these figures until the same data is loaded into the repository's PostgreSQL pipeline and the SQL outputs are checked against this analysis.
