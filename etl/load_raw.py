"""Load the Olist CSV files into the `raw` schema exactly as they arrive.

Every column is TEXT on purpose: typing and cleaning happen in sql/01_staging.sql, so a bad
value shows up in a data-quality check instead of crashing the load.

Usage:
    python etl/load_raw.py                 # reads data/raw/*.csv
    python etl/load_raw.py --data-dir path/to/csvs
"""
import argparse
import csv
import os
import sys
from pathlib import Path

import psycopg2
from psycopg2 import sql
from dotenv import load_dotenv

EXPECTED = {
    "olist_customers_dataset.csv": "customers",
    "olist_geolocation_dataset.csv": "geolocation",
    "olist_order_items_dataset.csv": "order_items",
    "olist_order_payments_dataset.csv": "order_payments",
    "olist_order_reviews_dataset.csv": "order_reviews",
    "olist_orders_dataset.csv": "orders",
    "olist_products_dataset.csv": "products",
    "olist_sellers_dataset.csv": "sellers",
    "product_category_name_translation.csv": "product_category_name_translation",
}


def read_header(path: Path):
    # utf-8-sig strips a BOM if the file has one (some Kaggle files do).
    with open(path, newline="", encoding="utf-8-sig") as f:
        return next(csv.reader(f))


def load_file(conn, path: Path, table: str) -> int:
    cols = read_header(path)
    cols = [c.strip() for c in cols]
    with conn.cursor() as cur:
        cur.execute(sql.SQL("DROP TABLE IF EXISTS raw.{} CASCADE").format(sql.Identifier(table)))
        cur.execute(
            sql.SQL("CREATE TABLE raw.{} ({})").format(
                sql.Identifier(table),
                sql.SQL(", ").join(sql.SQL("{} TEXT").format(sql.Identifier(c)) for c in cols),
            )
        )
        copy_sql = sql.SQL(
            "COPY raw.{} ({}) FROM STDIN WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')"
        ).format(
            sql.Identifier(table),
            sql.SQL(", ").join(sql.Identifier(c) for c in cols),
        )
        with open(path, "r", encoding="utf-8-sig", newline="") as f:
            cur.copy_expert(copy_sql, f)
        cur.execute(sql.SQL("SELECT COUNT(*) FROM raw.{}").format(sql.Identifier(table)))
        return cur.fetchone()[0]


def main():
    load_dotenv()
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-dir", default="data/raw")
    args = ap.parse_args()

    dsn = os.environ.get("DATABASE_URL")
    if not dsn:
        sys.exit("Set DATABASE_URL in .env (see .env.example).")

    data_dir = Path(args.data_dir)
    missing = [f for f in EXPECTED if not (data_dir / f).exists()]
    if missing:
        sys.exit(f"Missing files in {data_dir}: {', '.join(missing)}")

    conn = psycopg2.connect(dsn)
    try:
        with conn.cursor() as cur:
            cur.execute("CREATE SCHEMA IF NOT EXISTS raw")
        for fname, table in EXPECTED.items():
            n = load_file(conn, data_dir / fname, table)
            print(f"raw.{table:<40} {n:>10,} rows")
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    main()
