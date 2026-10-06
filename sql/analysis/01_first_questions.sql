-- First five business questions. Run each on its own and save the output in docs/findings/.
-- Write your OWN interpretation under each query. Do not copy numbers into the resume until you
-- have run these on the real Olist data and can explain every line.

-- Q1. Monthly order volume, GMV and on-time rate. Where does the trend break?
SELECT
    date_trunc('month', purchase_ts)::date                                  AS month,
    COUNT(*)                                                                AS orders,
    ROUND(SUM(items_value), 0)                                              AS gmv,
    COUNT(*) FILTER (WHERE is_delivered)                                    AS delivered,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_delivered AND NOT is_late)
          / NULLIF(COUNT(*) FILTER (WHERE is_delivered), 0), 2)             AS on_time_pct
FROM dw.fact_orders
WHERE purchase_ts IS NOT NULL
GROUP BY 1
ORDER BY 1;

-- Q2. Late rate by customer state, and the worst lanes (seller state -> customer state).
SELECT
    customer_state,
    COUNT(*) FILTER (WHERE is_delivered)                                    AS delivered,
    COUNT(*) FILTER (WHERE is_late)                                         AS late,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_late)
          / NULLIF(COUNT(*) FILTER (WHERE is_delivered), 0), 2)             AS late_pct
FROM dw.fact_orders
GROUP BY customer_state
ORDER BY late_pct DESC NULLS LAST;

SELECT
    lane,
    COUNT(*) FILTER (WHERE is_delivered)                                    AS delivered,
    COUNT(*) FILTER (WHERE is_late)                                         AS late,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_late)
          / NULLIF(COUNT(*) FILTER (WHERE is_delivered), 0), 2)             AS late_pct
FROM dw.fact_orders
WHERE lane IS NOT NULL
GROUP BY lane
HAVING COUNT(*) FILTER (WHERE is_delivered) >= 30      -- ignore tiny lanes; justify your threshold
ORDER BY late_pct DESC;

-- Q3. Split lateness: late handoff by the seller vs slow carrier transit vs both.
-- A late order is "seller-driven" if the seller handed off after the limit date, and "carrier-driven"
-- if the handoff was on time but the order was still late. Check the share that is both.
SELECT
    CASE WHEN has_late_handoff THEN 'late handoff' ELSE 'on-time handoff' END AS handoff,
    COUNT(*)                                                                  AS late_orders,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)                        AS pct_of_late_orders,
    ROUND(AVG(seller_handoff_days), 2)                                        AS avg_handoff_days,
    ROUND(AVG(carrier_transit_days), 2)                                       AS avg_transit_days
FROM dw.fact_orders
WHERE is_late
GROUP BY has_late_handoff;

-- Q4. Review score by how late the order was. Where does the rating cliff start?
SELECT
    CASE
        WHEN days_late <= -1  THEN '1. early'
        WHEN days_late = 0    THEN '2. on the day'
        WHEN days_late <= 3   THEN '3. 1-3 days late'
        WHEN days_late <= 7   THEN '4. 4-7 days late'
        ELSE                       '5. 8+ days late'
    END                                                       AS lateness_bucket,
    COUNT(*)                                                  AS orders,
    ROUND(AVG(review_score), 2)                               AS avg_review,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_low_review)
          / NULLIF(COUNT(review_score), 0), 2)                AS low_review_pct
FROM dw.fact_orders
WHERE is_delivered AND review_score IS NOT NULL
GROUP BY 1
ORDER BY 1;

-- Q5. Seller ranking: raw defect rate vs a confidence-adjusted rate (Wilson interval, 95%).
-- A seller with 3 orders and 2 defects should not outrank a seller with 400 orders and 120 defects.
-- Rank by the Wilson UPPER bound of the defect rate to flag "plausibly bad" sellers conservatively,
-- or by the lower bound to flag "confidently bad" ones. Decide which fits the business question.
WITH seller AS (
    SELECT
        seller_id,
        COUNT(*) FILTER (WHERE is_closed)                                AS n,
        COUNT(*) FILTER (WHERE is_closed AND is_defective)               AS x
    FROM dw.fact_orders
    WHERE n_sellers = 1 AND seller_id IS NOT NULL
    GROUP BY seller_id
),
calc AS (
    SELECT
        seller_id, n, x,
        x::numeric / n AS p,
        1.96::numeric  AS z
    FROM seller
    WHERE n >= 1
)
SELECT
    seller_id, n AS closed_orders, x AS defective_orders,
    ROUND(100 * p, 2) AS raw_defect_pct,
    ROUND(100 * ((p + z*z/(2*n) - z * sqrt((p*(1-p) + z*z/(4*n)) / n)) / (1 + z*z/n)), 2) AS wilson_lower_pct,
    ROUND(100 * ((p + z*z/(2*n) + z * sqrt((p*(1-p) + z*z/(4*n)) / n)) / (1 + z*z/n)), 2) AS wilson_upper_pct,
    RANK() OVER (ORDER BY p DESC)                                                       AS rank_raw,
    RANK() OVER (ORDER BY ((p + z*z/(2*n) - z * sqrt((p*(1-p) + z*z/(4*n)) / n)) / (1 + z*z/n)) DESC) AS rank_wilson_lower
FROM calc
ORDER BY rank_wilson_lower
LIMIT 50;
