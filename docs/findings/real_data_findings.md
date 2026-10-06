# Marketplace Pulse — Real Data Findings

These findings come from the uploaded Olist dataset and the project's reproducible Python transformation logic. They are not Amazon operational data.

## Dataset scale

| Table | Rows |
|---|---:|
| Orders | 99,441 |
| Customers | 99,441 |
| Order items | 112,650 |
| Payments | 103,886 |
| Reviews | 99,224 |
| Products | 32,951 |
| Sellers | 3,095 |
| Geolocation | 1,000,163 |
| Category translation | 71 |

Reviews were reduced to 98,673 latest-per-order records, removing 551 duplicate review rows.

## Core operational results

- Delivered orders: **96,470**.
- Closed orders: **97,103**.
- Late delivered orders: **6,535**, or **6.77%** of delivered orders.
- Low-review orders (1–2 stars): **14.69%** of reviewed orders.
- Defective closed orders under the project proxy: **15,450**, or **15.91%** of closed orders.
- Multi-seller orders: **1,278 of 98,666 orders with a seller (1.30%)**; excluded from seller-level handoff attribution.

## Operational breakpoints

Monthly on-time performance dropped to:

- **87.60% in Nov-2017**
- **85.86% in Feb-2018**
- **81.04% in Mar-2018**

It recovered to **95.50% in Apr-2018**.

## Geographic concentration

Among lanes with at least 30 delivered orders, examples of elevated lateness included:

- **PR→AL: 31.43%** (35 delivered; small volume)
- **SP→AL: 23.83%** (256 delivered)
- **SP→RJ: 14.12%** (8,157 delivered)

The SP→RJ lane is especially useful for prioritization because the problem is material at high volume; PR→AL should be treated as a small-sample signal rather than a definitive network conclusion.

## Seller handoff vs downstream transit

Of 6,535 late delivered orders:

- **1,814 (27.76%)** were classified as late seller handoff.
- **4,721 (72.24%)** had an on-time seller handoff.

Under this project's attribution rule, most late deliveries therefore occurred despite an on-time seller handoff, pointing analysts toward downstream carrier/transit investigation rather than treating sellers as the sole cause.

## Customer experience

Average review score changed sharply with lateness:

| Delivery timing | Avg review | 1–2 star share |
|---|---:|---:|
| Early | 4.29 | 9.22% |
| On day | 4.03 | 12.42% |
| 1–3 days late | 3.29 | 32.13% |
| 4–7 days late | 2.10 | 67.62% |
| 8+ days late | 1.70 | 79.29% |

The strongest deterioration occurs once lateness moves beyond three days.

## Data-quality observations

Five error-severity checks had zero failing rows. Warnings included missing delivery timestamps on 8 delivered-status orders, 1,359 carrier timestamps earlier than approval timestamps, 775 orders without an order-item row, 610 products without a category, and 278 customers without matching aggregated geolocation.

These are retained as DQ signals rather than silently discarded.
