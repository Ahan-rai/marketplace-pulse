"""Generate a TINY, SYNTHETIC, Olist-shaped dataset to smoke-test the pipeline.

!! Never use this for analysis or for any number on a resume. It exists only to check that
!! the loader and SQL run end to end before you point them at the real Olist files.

Usage:
    python tests/make_smoke_data.py                 # writes tests/smoke_data/
    python etl/load_raw.py --data-dir tests/smoke_data
"""
import csv
import random
from datetime import datetime, timedelta
from pathlib import Path

random.seed(7)
OUT = Path(__file__).resolve().parent / "smoke_data"
OUT.mkdir(exist_ok=True)

STATES = ["SP", "RJ", "MG", "RS", "BA"]
ZIPS = {s: [1000 + i * 100 + k for k in range(3)] for i, s in enumerate(STATES)}
FMT = "%Y-%m-%d %H:%M:%S"


def w(name, header, rows):
    with open(OUT / name, "w", newline="", encoding="utf-8") as f:
        cw = csv.writer(f)
        cw.writerow(header)
        cw.writerows(rows)


# geolocation: several rows per zip prefix
geo = []
for s, zs in ZIPS.items():
    for z in zs:
        for _ in range(3):
            geo.append([z, -23 + random.random(), -46 + random.random(), "city" + str(z), s])
w("olist_geolocation_dataset.csv",
  ["geolocation_zip_code_prefix", "geolocation_lat", "geolocation_lng", "geolocation_city", "geolocation_state"], geo)

sellers = []
for i in range(20):
    s = STATES[i % len(STATES)]
    sellers.append([f"seller{i:03d}", random.choice(ZIPS[s]), "city", s])
w("olist_sellers_dataset.csv", ["seller_id", "seller_zip_code_prefix", "seller_city", "seller_state"], sellers)

cats = ["bed_bath_table", "health_beauty", "computers", None]
w("product_category_name_translation.csv", ["product_category_name", "product_category_name_english"],
  [["bed_bath_table", "bed_bath_table"], ["health_beauty", "health_beauty"], ["computers", "computers"]])
products = [[f"prod{i:03d}", random.choice(cats) or "", 20, 100, 2, random.randint(100, 3000), 10, 10, 10] for i in range(60)]
w("olist_products_dataset.csv",
  ["product_id", "product_category_name", "product_name_lenght", "product_description_lenght", "product_photos_qty",
   "product_weight_g", "product_length_cm", "product_height_cm", "product_width_cm"], products)

customers, orders, items, pays, reviews = [], [], [], [], []
base = datetime(2017, 6, 1)
for i in range(300):
    cid = f"cust{i:04d}"
    uid = f"uniq{random.randint(0, 220):04d}"
    cs = random.choice(STATES)
    customers.append([cid, uid, random.choice(ZIPS[cs]), "city", cs])

    oid = f"order{i:04d}"
    purchase = base + timedelta(days=random.randint(0, 200), hours=random.randint(0, 23))
    approved = purchase + timedelta(hours=random.randint(1, 12))
    carrier = approved + timedelta(days=random.randint(1, 6))
    delivered = carrier + timedelta(days=random.randint(2, 20))
    estimated = purchase + timedelta(days=random.randint(10, 25))
    status = "delivered"
    r = random.random()
    if r < 0.05:
        status, carrier, delivered = "canceled", None, None
    elif r < 0.08:
        status = "shipped"; delivered = None
    elif r < 0.10:
        delivered = None  # status delivered, missing delivery ts (messy case)
    orders.append([oid, cid, status, purchase.strftime(FMT), approved.strftime(FMT),
                   carrier.strftime(FMT) if carrier else "", delivered.strftime(FMT) if delivered else "",
                   estimated.strftime(FMT)])

    n_items = random.choice([1, 1, 1, 2, 3])
    multi = random.random() < 0.06
    first_seller = random.choice(sellers)[0]
    for k in range(1, n_items + 1):
        sid = random.choice(sellers)[0] if (multi and k > 1) else first_seller
        limit = approved + timedelta(days=random.randint(1, 5))
        items.append([oid, k, random.choice(products)[0], sid, limit.strftime(FMT),
                      round(random.uniform(10, 300), 2), round(random.uniform(5, 40), 2)])
    total = sum(x[5] + x[6] for x in items if x[0] == oid)
    pays.append([oid, 1, random.choice(["credit_card", "boleto", "voucher"]), random.randint(1, 6), round(total, 2)])

    if random.random() < 0.9:
        score = random.choices([1, 2, 3, 4, 5], [10, 6, 10, 24, 50])[0]
        created = (delivered or purchase + timedelta(days=15))
        reviews.append([f"rev{i:04d}", oid, score, "", "otimo produto" if random.random() < 0.4 else "",
                        created.strftime(FMT), (created + timedelta(days=1)).strftime(FMT)])
        if random.random() < 0.04:  # duplicate review row for the same order
            reviews.append([f"rev{i:04d}b", oid, random.randint(1, 5), "", "",
                            created.strftime(FMT), (created + timedelta(days=2)).strftime(FMT)])

w("olist_customers_dataset.csv",
  ["customer_id", "customer_unique_id", "customer_zip_code_prefix", "customer_city", "customer_state"], customers)
w("olist_orders_dataset.csv",
  ["order_id", "customer_id", "order_status", "order_purchase_timestamp", "order_approved_at",
   "order_delivered_carrier_date", "order_delivered_customer_date", "order_estimated_delivery_date"], orders)
w("olist_order_items_dataset.csv",
  ["order_id", "order_item_id", "product_id", "seller_id", "shipping_limit_date", "price", "freight_value"], items)
w("olist_order_payments_dataset.csv",
  ["order_id", "payment_sequential", "payment_type", "payment_installments", "payment_value"], pays)
w("olist_order_reviews_dataset.csv",
  ["review_id", "order_id", "review_score", "review_comment_title", "review_comment_message",
   "review_creation_date", "review_answer_timestamp"], reviews)
print(f"Wrote synthetic smoke data to {OUT}")
