-- Staging: cast types, trim text, dedupe. Everything here is re-runnable (DROP + CREATE).

DROP TABLE IF EXISTS staging.orders CASCADE;
CREATE TABLE staging.orders AS
SELECT
    order_id,
    customer_id,
    order_status,
    NULLIF(order_purchase_timestamp, '')::timestamp        AS purchase_ts,
    NULLIF(order_approved_at, '')::timestamp               AS approved_ts,
    NULLIF(order_delivered_carrier_date, '')::timestamp    AS carrier_ts,
    NULLIF(order_delivered_customer_date, '')::timestamp   AS delivered_ts,
    NULLIF(order_estimated_delivery_date, '')::timestamp   AS estimated_ts
FROM raw.orders;

DROP TABLE IF EXISTS staging.customers CASCADE;
CREATE TABLE staging.customers AS
SELECT
    customer_id,                      -- one per ORDER, not per person
    customer_unique_id,               -- the actual person
    NULLIF(customer_zip_code_prefix, '')::int AS zip_prefix,
    TRIM(customer_city)  AS city,
    UPPER(TRIM(customer_state)) AS state
FROM raw.customers;

DROP TABLE IF EXISTS staging.sellers CASCADE;
CREATE TABLE staging.sellers AS
SELECT
    seller_id,
    NULLIF(seller_zip_code_prefix, '')::int AS zip_prefix,
    TRIM(seller_city) AS city,
    UPPER(TRIM(seller_state)) AS state
FROM raw.sellers;

DROP TABLE IF EXISTS staging.order_items CASCADE;
CREATE TABLE staging.order_items AS
SELECT
    order_id,
    order_item_id::int                                  AS item_seq,
    product_id,
    seller_id,
    NULLIF(shipping_limit_date, '')::timestamp          AS shipping_limit_ts,
    price::numeric(12,2)                                AS price,
    freight_value::numeric(12,2)                        AS freight_value
FROM raw.order_items;

DROP TABLE IF EXISTS staging.payments CASCADE;
CREATE TABLE staging.payments AS
SELECT
    order_id,
    payment_sequential::int       AS payment_seq,
    payment_type,
    payment_installments::int     AS installments,
    payment_value::numeric(12,2)  AS payment_value
FROM raw.order_payments;

-- Some orders have more than one review row. Keep the most recent one per order.
DROP TABLE IF EXISTS staging.reviews CASCADE;
CREATE TABLE staging.reviews AS
SELECT DISTINCT ON (order_id)
    review_id,
    order_id,
    review_score::int                                    AS review_score,
    NULLIF(TRIM(review_comment_title), '')               AS comment_title,
    NULLIF(TRIM(review_comment_message), '')             AS comment_message,
    NULLIF(review_creation_date, '')::timestamp          AS review_creation_ts,
    NULLIF(review_answer_timestamp, '')::timestamp       AS review_answer_ts
FROM raw.order_reviews
ORDER BY order_id,
         NULLIF(review_creation_date, '')::timestamp DESC NULLS LAST,
         NULLIF(review_answer_timestamp, '')::timestamp DESC NULLS LAST,
         review_id;

DROP TABLE IF EXISTS staging.products CASCADE;
CREATE TABLE staging.products AS
SELECT
    product_id,
    NULLIF(TRIM(product_category_name), '')   AS category_pt,
    NULLIF(product_weight_g, '')::numeric     AS weight_g,
    NULLIF(product_photos_qty, '')::numeric   AS photos_qty
FROM raw.products;

DROP TABLE IF EXISTS staging.category_translation CASCADE;
CREATE TABLE staging.category_translation AS
SELECT
    TRIM(product_category_name)          AS category_pt,
    TRIM(product_category_name_english)  AS category_en
FROM raw.product_category_name_translation;

-- Geolocation has many lat/lng rows per zip prefix: cast here, aggregate in dw.dim_geo.
DROP TABLE IF EXISTS staging.geolocation CASCADE;
CREATE TABLE staging.geolocation AS
SELECT
    NULLIF(geolocation_zip_code_prefix, '')::int  AS zip_prefix,
    geolocation_lat::double precision             AS lat,
    geolocation_lng::double precision             AS lng,
    TRIM(geolocation_city)                        AS city,
    UPPER(TRIM(geolocation_state))                AS state
FROM raw.geolocation;
