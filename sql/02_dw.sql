-- Star schema.
--   dim_date, dim_customer, dim_seller, dim_product, dim_geo
--   fact_orders        grain: one row per order
--   fact_order_items   grain: one row per order item
--   fact_reviews       grain: one row per order (after dedupe)
--   fact_payments      grain: one row per payment sequence
-- Known limitation: carrier handoff time exists per ORDER, not per seller. Seller-level
-- delivery metrics therefore use single-seller orders only (n_sellers = 1). Document the
-- share of multi-seller orders in your write-up (see dq check multi_seller_orders_...).

DROP TABLE IF EXISTS dw.dim_date CASCADE;
CREATE TABLE dw.dim_date AS
SELECT
    to_char(d, 'YYYYMMDD')::int                    AS date_key,
    d::date                                        AS full_date,
    EXTRACT(year FROM d)::int                      AS year,
    EXTRACT(quarter FROM d)::int                   AS quarter,
    EXTRACT(month FROM d)::int                     AS month,
    to_char(d, 'Mon')                              AS month_name,
    date_trunc('week', d)::date                    AS week_start,
    EXTRACT(isodow FROM d)::int                    AS iso_dow,
    (EXTRACT(isodow FROM d) IN (6, 7))             AS is_weekend
FROM generate_series(
        (SELECT MIN(purchase_ts)::date FROM staging.orders),
        (SELECT GREATEST(MAX(estimated_ts), MAX(delivered_ts))::date FROM staging.orders),
        interval '1 day') AS g(d);
ALTER TABLE dw.dim_date ADD PRIMARY KEY (date_key);

DROP TABLE IF EXISTS dw.dim_geo CASCADE;
CREATE TABLE dw.dim_geo AS
SELECT
    zip_prefix,
    AVG(lat)                                  AS lat,
    AVG(lng)                                  AS lng,
    MODE() WITHIN GROUP (ORDER BY city)       AS city,
    MODE() WITHIN GROUP (ORDER BY state)      AS state
FROM staging.geolocation
WHERE zip_prefix IS NOT NULL
GROUP BY zip_prefix;
ALTER TABLE dw.dim_geo ADD PRIMARY KEY (zip_prefix);

DROP TABLE IF EXISTS dw.dim_customer CASCADE;
CREATE TABLE dw.dim_customer AS
SELECT customer_id, customer_unique_id, zip_prefix, city, state FROM staging.customers;
ALTER TABLE dw.dim_customer ADD PRIMARY KEY (customer_id);

DROP TABLE IF EXISTS dw.dim_seller CASCADE;
CREATE TABLE dw.dim_seller AS
SELECT seller_id, zip_prefix, city, state FROM staging.sellers;
ALTER TABLE dw.dim_seller ADD PRIMARY KEY (seller_id);

DROP TABLE IF EXISTS dw.dim_product CASCADE;
CREATE TABLE dw.dim_product AS
SELECT
    p.product_id,
    p.category_pt,
    COALESCE(t.category_en, p.category_pt, 'unknown') AS category_en,
    p.weight_g,
    p.photos_qty
FROM staging.products p
LEFT JOIN staging.category_translation t ON t.category_pt = p.category_pt;
ALTER TABLE dw.dim_product ADD PRIMARY KEY (product_id);

DROP TABLE IF EXISTS dw.fact_order_items CASCADE;
CREATE TABLE dw.fact_order_items AS
SELECT
    i.order_id,
    i.item_seq,
    i.product_id,
    i.seller_id,
    o.customer_id,
    to_char(o.purchase_ts, 'YYYYMMDD')::int AS purchase_date_key,
    i.price,
    i.freight_value,
    i.shipping_limit_ts,
    (o.carrier_ts IS NOT NULL
        AND i.shipping_limit_ts IS NOT NULL
        AND o.carrier_ts > i.shipping_limit_ts)  AS is_late_handoff
FROM staging.order_items i
LEFT JOIN staging.orders o ON o.order_id = i.order_id;
ALTER TABLE dw.fact_order_items ADD PRIMARY KEY (order_id, item_seq);

DROP TABLE IF EXISTS dw.fact_reviews CASCADE;
CREATE TABLE dw.fact_reviews AS
SELECT
    order_id,
    review_id,
    review_score,
    comment_title,
    comment_message,
    (comment_message IS NOT NULL)                                   AS has_comment,
    review_creation_ts,
    review_answer_ts,
    ROUND((EXTRACT(EPOCH FROM (review_answer_ts - review_creation_ts)) / 3600)::numeric, 1) AS response_hours
FROM staging.reviews;
ALTER TABLE dw.fact_reviews ADD PRIMARY KEY (order_id);

DROP TABLE IF EXISTS dw.fact_payments CASCADE;
CREATE TABLE dw.fact_payments AS
SELECT order_id, payment_seq, payment_type, installments, payment_value FROM staging.payments;
ALTER TABLE dw.fact_payments ADD PRIMARY KEY (order_id, payment_seq);

DROP TABLE IF EXISTS dw.fact_orders CASCADE;
CREATE TABLE dw.fact_orders AS
WITH items AS (
    SELECT
        order_id,
        COUNT(*)                         AS n_items,
        COUNT(DISTINCT seller_id)        AS n_sellers,
        SUM(price)                       AS items_value,
        SUM(freight_value)               AS freight_value,
        MIN(seller_id)                   AS any_seller_id,
        BOOL_OR(is_late_handoff)         AS has_late_handoff
    FROM dw.fact_order_items
    GROUP BY order_id
),
pay AS (
    SELECT
        order_id,
        SUM(payment_value)                                          AS payment_value,
        MAX(installments)                                           AS max_installments,
        (ARRAY_AGG(payment_type ORDER BY payment_seq))[1]           AS primary_payment_type
    FROM dw.fact_payments
    GROUP BY order_id
),
base AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.order_status,
        o.purchase_ts, o.approved_ts, o.carrier_ts, o.delivered_ts, o.estimated_ts,
        COALESCE(it.n_items, 0)     AS n_items,
        COALESCE(it.n_sellers, 0)   AS n_sellers,
        it.items_value, it.freight_value,
        CASE WHEN it.n_sellers = 1 THEN it.any_seller_id END AS seller_id,
        COALESCE(it.has_late_handoff, false) AS has_late_handoff,
        pay.payment_value, pay.max_installments, pay.primary_payment_type,
        r.review_score,
        s.state       AS seller_state,
        c.state       AS customer_state,
        gs.lat AS s_lat, gs.lng AS s_lng,
        gc.lat AS c_lat, gc.lng AS c_lng
    FROM staging.orders o
    LEFT JOIN items it            ON it.order_id = o.order_id
    LEFT JOIN pay                 ON pay.order_id = o.order_id
    LEFT JOIN dw.fact_reviews r   ON r.order_id = o.order_id
    LEFT JOIN dw.dim_customer c   ON c.customer_id = o.customer_id
    LEFT JOIN dw.dim_seller s     ON s.seller_id = CASE WHEN it.n_sellers = 1 THEN it.any_seller_id END
    LEFT JOIN dw.dim_geo gs       ON gs.zip_prefix = s.zip_prefix
    LEFT JOIN dw.dim_geo gc       ON gc.zip_prefix = c.zip_prefix
),
derived AS (
    SELECT
        b.*,
        ROUND((EXTRACT(EPOCH FROM (approved_ts - purchase_ts)) / 3600)::numeric, 2)    AS approval_hours,
        ROUND((EXTRACT(EPOCH FROM (carrier_ts - approved_ts)) / 86400)::numeric, 2)    AS seller_handoff_days,
        ROUND((EXTRACT(EPOCH FROM (delivered_ts - carrier_ts)) / 86400)::numeric, 2)   AS carrier_transit_days,
        ROUND((EXTRACT(EPOCH FROM (delivered_ts - purchase_ts)) / 86400)::numeric, 2)  AS total_delivery_days,
        ROUND((EXTRACT(EPOCH FROM (estimated_ts - purchase_ts)) / 86400)::numeric, 2)  AS promised_days,
        (delivered_ts::date - estimated_ts::date)                                      AS days_late,
        (order_status = 'delivered' AND delivered_ts IS NOT NULL)                      AS is_delivered,
        (order_status IN ('delivered', 'canceled'))                                    AS is_closed,
        CASE WHEN delivered_ts IS NULL THEN NULL
             ELSE delivered_ts::date > estimated_ts::date END                          AS is_late,
        (order_status = 'canceled')                                                    AS is_cancelled,
        CASE WHEN review_score IS NULL THEN NULL ELSE review_score <= 2 END            AS is_low_review,
        CASE WHEN seller_state IS NOT NULL AND customer_state IS NOT NULL
             THEN seller_state || '->' || customer_state END                           AS lane,
        CASE WHEN s_lat IS NOT NULL AND c_lat IS NOT NULL THEN
            ROUND((2 * 6371 * asin(LEAST(1.0, sqrt(
                power(sin(radians(c_lat - s_lat) / 2), 2) +
                cos(radians(s_lat)) * cos(radians(c_lat)) *
                power(sin(radians(c_lng - s_lng) / 2), 2)
            ))))::numeric, 1) END                                                      AS distance_km
    FROM base b
)
SELECT
    d.order_id, d.customer_id, d.seller_id, d.order_status,
    d.purchase_ts, d.approved_ts, d.carrier_ts, d.delivered_ts, d.estimated_ts,
    d.n_items, d.n_sellers, d.items_value, d.freight_value,
    d.payment_value, d.max_installments, d.primary_payment_type,
    d.review_score,
    d.approval_hours, d.seller_handoff_days, d.carrier_transit_days,
    d.total_delivery_days, d.promised_days, d.days_late,
    d.is_delivered, d.is_closed, d.is_late, d.has_late_handoff,
    d.is_cancelled, d.is_low_review,
    -- Defective order (our own proxy, not any company's official metric):
    -- cancelled OR delivered late OR low review (1-2 stars). Only meaningful when is_closed.
    (COALESCE(d.is_cancelled, false) OR COALESCE(d.is_late, false) OR COALESCE(d.is_low_review, false)) AS is_defective,
    d.seller_state, d.customer_state, d.lane, d.distance_km
FROM derived d;
ALTER TABLE dw.fact_orders ADD PRIMARY KEY (order_id);
CREATE INDEX ix_fact_orders_seller ON dw.fact_orders (seller_id);
CREATE INDEX ix_fact_orders_purchase ON dw.fact_orders (purchase_ts);
