# Data and SQL validation status

## Source
The project uses the public **Olist Brazilian E-Commerce** dataset: 9 CSV tables and roughly 100K orders. It is not Amazon data.

## Current validation
The repository's analysis outputs were independently reproduced from the uploaded Olist CSVs with Python/pandas. These outputs are stored under `data/analysis_outputs/` so the findings are inspectable and reproducible.

The current execution environment did **not** have a running PostgreSQL server, so the numbers must not be described as PostgreSQL execution results yet.

## PostgreSQL parity check
Run the following on a machine with PostgreSQL available:

```bash
python etl/load_raw.py
python etl/run_pipeline.py --strict
```

Then run the SQL in `sql/analysis/01_first_questions.sql` and `sql/analysis/02_additional_questions.sql` and compare the results with `data/analysis_outputs/`.

A successful parity check means the repository's PostgreSQL pipeline reproduces the independently validated numbers.

## Important modeling rules
- Reviews are deduplicated to the latest review per order.
- Geolocation is aggregated by zip prefix before joining.
- Seller handoff analysis is restricted to single-seller orders because carrier handoff is stored at order level.
- Multi-seller orders are reported separately rather than silently assigned to a seller.
- Defective order is a project-defined proxy: cancelled OR late OR 1–2 star review, among closed orders.
- Small samples are not treated as strong evidence; seller monitoring uses volume thresholds and, where appropriate, Wilson lower bounds.
