# Marketplace Pulse: Seller Defect & Delivery-Promise Monitoring

A PostgreSQL warehouse, Python ETL, and SQL analysis for a public marketplace dataset
(Olist Brazilian E-Commerce, 9 related tables). The goal is the kind of weekly monitoring a
seller-experience team would run: which sellers and delivery lanes hurt customers, whether
lateness is the seller's handoff or the carrier's transit, and what to flag this week.

> **Status: analysis-ready / PostgreSQL parity pending.** The uploaded Olist data has been independently
> reproduced with Python. Run the PostgreSQL pipeline locally before describing the outputs as PostgreSQL-executed results.

## Data
Download the Olist dataset from Kaggle ("Brazilian E-Commerce Public Dataset by Olist") and put the
9 CSVs in `data/raw/`. Check the dataset's terms of use on Kaggle. This is public marketplace data,
not Amazon data; describe it that way everywhere.

## Setup
```bash
python -m venv .venv && source .venv/bin/activate     # Windows: .venv\Scripts\activate
pip install -r requirements.txt
createdb marketplace_pulse                            # or create it in pgAdmin
cp .env.example .env                                  # then edit DATABASE_URL
python etl/load_raw.py                                # CSVs -> raw schema (all TEXT)
python etl/run_pipeline.py                            # staging -> dw -> mart + DQ checks + row counts
```
Run `python tests/make_smoke_data.py` then `python etl/load_raw.py --data-dir tests/smoke_data`
to check your setup with a tiny SYNTHETIC dataset first. Never use that for results.

## Layers
| Schema | Purpose |
|---|---|
| `raw` | CSVs as loaded, every column TEXT |
| `staging` | typed, trimmed, deduplicated (reviews: latest per order) |
| `dw` | star schema: `dim_date/customer/seller/product/geo`, `fact_orders/order_items/reviews/payments` |
| `mart` | `seller_week`, `lane_week` for the dashboard |
| `ops` | `dq_log` and `row_counts` per run |

## Key modeling decisions (be ready to defend these)
- `customer_id` is per order; `customer_unique_id` is the person. Repeat-customer logic must use the latter.
- Geolocation is aggregated to one row per zip prefix before joining, to avoid row multiplication.
- Handoff time exists per order, so seller metrics use single-seller orders only. Report the excluded share.
- "Defective order" = canceled OR late OR 1-2 star review, among closed orders. It is our own proxy.

## What is built vs. what is next
- [x] Raw load, staging, star schema, marts, DQ checks, row-count logging
- [x] First 5 analysis queries (`sql/analysis/01_first_questions.sql`)
- [x] Additional analysis queries (`sql/analysis/02_additional_questions.sql`)
- [x] Rule-based anomaly detection (`analytics/anomaly.py`)
- [x] Real-data findings memo (`docs/findings/real_data_findings.md`)
- [ ] PostgreSQL parity validation
- [ ] Weekly automation + Excel/VBA scorecard
- [ ] Power BI dashboard

## Reproducible outputs

The checked-in CSVs under `data/analysis_outputs/` are analysis artifacts generated from the real Olist dataset. They include the first five analyses, additional analyses, DQ results, and anomaly flags so reviewers can inspect measured outcomes without downloading the raw dataset. The raw CSVs remain gitignored.

See [`docs/validation.md`](docs/validation.md) for the distinction between Python reproduction and PostgreSQL execution.

## Publishing

See [`PUSH_TO_GITHUB.md`](PUSH_TO_GITHUB.md) for the final commit and push commands.
