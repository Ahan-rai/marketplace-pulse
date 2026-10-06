-- Layers: raw (as loaded) -> staging (typed/cleaned) -> dw (star schema) -> mart (dashboard tables)
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS dw;
CREATE SCHEMA IF NOT EXISTS mart;
CREATE SCHEMA IF NOT EXISTS ops;

-- One row per data-quality check per pipeline run.
CREATE TABLE IF NOT EXISTS ops.dq_log (
    run_id       BIGINT,
    run_ts       TIMESTAMP DEFAULT now(),
    check_name   TEXT,
    severity     TEXT,        -- error | warn | info
    failing_rows BIGINT,
    total_rows   BIGINT
);

-- Row counts per table per layer per run (evidence for "rows processed" claims).
CREATE TABLE IF NOT EXISTS ops.row_counts (
    run_id     BIGINT,
    run_ts     TIMESTAMP DEFAULT now(),
    layer      TEXT,
    table_name TEXT,
    row_count  BIGINT
);
