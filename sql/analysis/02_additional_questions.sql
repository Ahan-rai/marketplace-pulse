-- Additional operational analysis questions 06-15.
-- These queries run against the star schema created by sql/02_dw.sql.
-- Thresholds are analysis choices, not company policy.

-- Q06. Cancellation rate by purchase month.
SELECT
    date_trunc('month', purchase_ts)::date AS month_start,
    COUNT(*) AS orders,
    COUNT(*) FILTER (WHERE is_cancelled) AS cancelled_orders,
    COUNT(*) FILTER (WHERE is_closed) AS closed_orders,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_cancelled) / NULLIF(COUNT(*),0), 2) AS cancellation_rate_pct
FROM dw.fact_orders
WHERE purchase_ts IS NOT NULL
GROUP BY 1
ORDER BY 1;

-- Q07. Delivery-promise performance by month.
SELECT
    date_trunc('month', purchase_ts)::date AS month_start,
    COUNT(*) AS delivered_orders,
    ROUND(AVG(promised_days), 2) AS avg_promised_days,
    ROUND(AVG(total_delivery_days), 2) AS avg_actual_delivery_days,
    ROUND(AVG(promised_days - total_delivery_days), 2) AS avg_promise_slack_days,
    COUNT(*) FILTER (WHERE is_late) AS late_orders,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_late) / NULLIF(COUNT(*),0), 2) AS late_rate_pct,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_late) FILTER (WHERE is_late AND days_late > 0), 2) AS median_days_late_among_late
FROM dw.fact_orders
WHERE is_delivered AND purchase_ts IS NOT NULL
GROUP BY 1
ORDER BY 1;

-- Q08. Seller handoff compliance by month, restricted to single-seller orders.
SELECT
    date_trunc('month', purchase_ts)::date AS month_start,
    COUNT(*) AS orders_with_carrier_handoff,
    COUNT(*) FILTER (WHERE has_late_handoff) AS late_handoff_orders,
    ROUND(100.0 * COUNT(*) FILTER (WHERE has_late_handoff) / NULLIF(COUNT(*),0), 2) AS late_handoff_rate_pct,
    ROUND(AVG(seller_handoff_days), 2) AS avg_handoff_days
FROM dw.fact_orders
WHERE n_sellers = 1
  AND seller_id IS NOT NULL
  AND approved_ts IS NOT NULL
  AND carrier_ts IS NOT NULL
  AND purchase_ts IS NOT NULL
GROUP BY 1
ORDER BY 1;

-- Q09. Closed-order performance by primary payment type.
SELECT
    primary_payment_type,
    COUNT(*) AS orders,
    ROUND(SUM(items_value), 2) AS gmv,
    ROUND(AVG(items_value), 2) AS avg_order_value,
    COUNT(*) FILTER (WHERE is_cancelled) AS cancelled_orders,
    COUNT(*) FILTER (WHERE is_late) AS late_orders,
    COUNT(*) FILTER (WHERE is_low_review) AS low_review_orders,
    COUNT(*) FILTER (WHERE is_defective) AS defective_orders,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_defective) / NULLIF(COUNT(*),0), 2) AS defect_rate_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_cancelled) / NULLIF(COUNT(*),0), 2) AS cancellation_rate_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_late) / NULLIF(COUNT(*),0), 2) AS late_rate_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_low_review) / NULLIF(COUNT(*),0), 2) AS low_review_rate_pct
FROM dw.fact_orders
WHERE is_closed AND primary_payment_type IS NOT NULL
GROUP BY 1
ORDER BY defect_rate_pct DESC;

-- Q10. Freight burden by month for delivered orders.
SELECT
    date_trunc('month', purchase_ts)::date AS month_start,
    COUNT(*) AS delivered_orders,
    ROUND(SUM(items_value), 2) AS item_value,
    ROUND(SUM(freight_value), 2) AS freight_value,
    ROUND(AVG(freight_value), 2) AS avg_freight_per_order,
    ROUND(AVG(items_value), 2) AS avg_item_value_per_order,
    ROUND(100.0 * SUM(freight_value) / NULLIF(SUM(items_value),0), 2) AS freight_to_item_value_pct
FROM dw.fact_orders
WHERE is_delivered AND purchase_ts IS NOT NULL
GROUP BY 1
ORDER BY 1;

-- Q11. Weekly seller defect spikes. Minimum 30 closed single-seller orders avoids tiny samples.
SELECT
    seller_id,
    date_trunc('week', purchase_ts)::date AS week_start,
    COUNT(*) AS closed_orders,
    COUNT(*) FILTER (WHERE is_defective) AS defective_orders,
    COUNT(*) FILTER (WHERE is_late) AS late_orders,
    COUNT(*) FILTER (WHERE is_cancelled) AS cancelled_orders,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_defective) / NULLIF(COUNT(*),0), 2) AS defect_rate_pct
FROM dw.fact_orders
WHERE n_sellers = 1
  AND seller_id IS NOT NULL
  AND is_closed
  AND purchase_ts IS NOT NULL
GROUP BY 1,2
HAVING COUNT(*) >= 30
ORDER BY defect_rate_pct DESC, closed_orders DESC;

-- Q12. Delivery-lane performance. Minimum 100 delivered orders.
SELECT
    lane,
    COUNT(*) AS delivered_orders,
    COUNT(*) FILTER (WHERE is_late) AS late_orders,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_late) / NULLIF(COUNT(*),0), 2) AS late_rate_pct,
    ROUND(AVG(carrier_transit_days), 2) AS avg_transit_days,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY carrier_transit_days), 2) AS median_transit_days
FROM dw.fact_orders
WHERE is_delivered AND lane IS NOT NULL
GROUP BY 1
HAVING COUNT(*) >= 100
ORDER BY late_rate_pct DESC;

-- Q13. Review response time by review score.
SELECT
    review_score,
    COUNT(*) AS reviews,
    ROUND(AVG(response_hours), 2) AS avg_response_hours,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY response_hours), 2) AS median_response_hours,
    ROUND(100.0 * COUNT(*) FILTER (WHERE has_comment) / NULLIF(COUNT(*),0), 2) AS comment_rate_pct
FROM dw.fact_reviews
GROUP BY 1
ORDER BY 1;

-- Q14. Category performance using unique closed orders containing the category.
-- This avoids counting one multi-item order multiple times within the category.
WITH order_category AS (
    SELECT DISTINCT
        i.order_id,
        p.category_en
    FROM dw.fact_order_items i
    JOIN dw.dim_product p ON p.product_id = i.product_id
)
SELECT
    oc.category_en,
    COUNT(*) AS unique_closed_orders,
    ROUND(SUM(f.items_value), 2) AS order_value,
    COUNT(*) FILTER (WHERE f.is_late) AS late_orders,
    COUNT(*) FILTER (WHERE f.is_low_review) AS low_review_orders,
    COUNT(*) FILTER (WHERE f.is_defective) AS defective_orders,
    ROUND(100.0 * COUNT(*) FILTER (WHERE f.is_defective) / NULLIF(COUNT(*),0), 2) AS defect_rate_pct
FROM order_category oc
JOIN dw.fact_orders f ON f.order_id = oc.order_id
WHERE f.is_closed
GROUP BY 1
HAVING COUNT(*) >= 100
ORDER BY defect_rate_pct DESC;

-- Q15. Seller risk quadrant. Minimum 100 closed single-seller orders.
-- Thresholds are project monitoring thresholds: HIGH >=25%, WATCH 15-25%.
WITH seller_perf AS (
    SELECT
        seller_id,
        COUNT(*) AS closed_orders,
        COUNT(*) FILTER (WHERE is_defective) AS defective_orders,
        COUNT(*) FILTER (WHERE is_late) AS late_orders,
        COUNT(*) FILTER (WHERE is_cancelled) AS cancelled_orders,
        SUM(items_value) AS gmv
    FROM dw.fact_orders
    WHERE n_sellers = 1
      AND seller_id IS NOT NULL
      AND is_closed
    GROUP BY seller_id
)
SELECT
    *,
    ROUND(100.0 * defective_orders / NULLIF(closed_orders,0), 2) AS defect_rate_pct,
    ROUND(100.0 * late_orders / NULLIF(closed_orders,0), 2) AS late_rate_pct,
    CASE
        WHEN 100.0 * defective_orders / NULLIF(closed_orders,0) >= 25 THEN 'HIGH'
        WHEN 100.0 * defective_orders / NULLIF(closed_orders,0) >= 15 THEN 'WATCH'
        ELSE 'NORMAL'
    END AS risk_flag
FROM seller_perf
WHERE closed_orders >= 100
ORDER BY defect_rate_pct DESC;
