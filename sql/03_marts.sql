-- Marts: pre-aggregated tables the dashboard reads. Seller marts use single-seller orders only (see 02_dw.sql).

DROP TABLE IF EXISTS mart.seller_week CASCADE;
CREATE TABLE mart.seller_week AS
SELECT
    seller_id,
    date_trunc('week', purchase_ts)::date                  AS week_start,
    COUNT(*)                                               AS orders,
    COUNT(*) FILTER (WHERE is_closed)                      AS closed_orders,
    COUNT(*) FILTER (WHERE is_delivered)                   AS delivered_orders,
    COUNT(*) FILTER (WHERE is_late)                        AS late_orders,
    COUNT(*) FILTER (WHERE has_late_handoff)               AS late_handoff_orders,
    COUNT(*) FILTER (WHERE is_cancelled)                   AS cancelled_orders,
    COUNT(*) FILTER (WHERE is_low_review)                  AS low_review_orders,
    COUNT(*) FILTER (WHERE is_closed AND is_defective)     AS defective_orders,
    SUM(items_value)                                       AS gmv
FROM dw.fact_orders
WHERE n_sellers = 1 AND seller_id IS NOT NULL AND purchase_ts IS NOT NULL
GROUP BY seller_id, date_trunc('week', purchase_ts)::date;
CREATE INDEX ix_seller_week ON mart.seller_week (seller_id, week_start);

DROP TABLE IF EXISTS mart.lane_week CASCADE;
CREATE TABLE mart.lane_week AS
SELECT
    lane,
    date_trunc('week', purchase_ts)::date                  AS week_start,
    COUNT(*)                                               AS orders,
    COUNT(*) FILTER (WHERE is_delivered)                   AS delivered_orders,
    COUNT(*) FILTER (WHERE is_late)                        AS late_orders,
    COUNT(*) FILTER (WHERE is_closed AND is_defective)     AS defective_orders,
    COUNT(*) FILTER (WHERE is_closed)                      AS closed_orders,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY carrier_transit_days) AS median_transit_days,
    AVG(promised_days - total_delivery_days)               AS avg_days_early
FROM dw.fact_orders
WHERE lane IS NOT NULL AND purchase_ts IS NOT NULL
GROUP BY lane, date_trunc('week', purchase_ts)::date;
CREATE INDEX ix_lane_week ON mart.lane_week (lane, week_start);
