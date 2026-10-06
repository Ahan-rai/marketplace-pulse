"""Run the warehouse build: staging -> dw -> marts -> data-quality checks.

Assumes `python etl/load_raw.py` has already loaded the raw schema.
Every run is logged: row counts per table per layer (ops.row_counts) and
data-quality results (ops.dq_log), keyed by run_id.

Usage:
    python etl/run_pipeline.py
    python etl/run_pipeline.py --strict     # exit code 1 if any 'error' check has failing rows
"""
import argparse
import os
import sys
import time
from pathlib import Path

import psycopg2
from psycopg2 import sql
from dotenv import load_dotenv

SQL_DIR = Path(__file__).resolve().parent.parent / "sql"
STEPS = [
    ("00_schemas.sql", None),
    ("01_staging.sql", "staging"),
    ("02_dw.sql", "dw"),
    ("03_marts.sql", "mart"),
    ("04_dq_checks.sql", None),
]


def snapshot_counts(cur, run_id: int, layer: str):
    cur.execute(
        "SELECT table_name FROM information_schema.tables "
        "WHERE table_schema = %s AND table_type = 'BASE TABLE' ORDER BY table_name",
        (layer,),
    )
    for (t,) in cur.fetchall():
        cur.execute(sql.SQL("SELECT COUNT(*) FROM {}.{}").format(sql.Identifier(layer), sql.Identifier(t)))
        n = cur.fetchone()[0]
        cur.execute(
            "INSERT INTO ops.row_counts (run_id, layer, table_name, row_count) VALUES (%s, %s, %s, %s)",
            (run_id, layer, t, n),
        )


def main():
    load_dotenv()
    ap = argparse.ArgumentParser()
    ap.add_argument("--strict", action="store_true")
    args = ap.parse_args()

    dsn = os.environ.get("DATABASE_URL")
    if not dsn:
        sys.exit("Set DATABASE_URL in .env (see .env.example).")

    run_id = int(time.time())
    conn = psycopg2.connect(dsn)
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT set_config('pulse.run_id', %s, false)", (str(run_id),))
            for fname, layer in STEPS:
                t0 = time.time()
                cur.execute((SQL_DIR / fname).read_text(encoding="utf-8"))
                if fname == "00_schemas.sql":
                    snapshot_counts(cur, run_id, "raw")
                if layer:
                    snapshot_counts(cur, run_id, layer)
                print(f"{fname:<20} done in {time.time() - t0:5.1f}s")
        conn.commit()

        with conn.cursor() as cur:
            print("\nRow counts by layer")
            cur.execute(
                "SELECT layer, table_name, row_count FROM ops.row_counts "
                "WHERE run_id = %s ORDER BY layer, table_name",
                (run_id,),
            )
            for layer, t, n in cur.fetchall():
                print(f"  {layer:<8} {t:<36} {n:>12,}")

            print("\nData-quality checks")
            cur.execute(
                "SELECT check_name, severity, failing_rows, total_rows FROM ops.dq_log "
                "WHERE run_id = %s ORDER BY CASE severity WHEN 'error' THEN 0 WHEN 'warn' THEN 1 ELSE 2 END, check_name",
                (run_id,),
            )
            rows = cur.fetchall()
            bad_errors = 0
            for name, sev, fail, total in rows:
                pct = (100.0 * fail / total) if total else 0.0
                flag = "!!" if (sev == "error" and fail > 0) else "  "
                print(f" {flag}[{sev:<5}] {name:<52} {fail:>8,} / {total:>9,} ({pct:5.2f}%)")
                if sev == "error" and fail > 0:
                    bad_errors += 1
        if args.strict and bad_errors:
            sys.exit(1)
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    main()
