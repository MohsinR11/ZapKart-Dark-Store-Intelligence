SELECT version();


-- Check all tables and row counts
SELECT
    schemaname,
    relname AS tablename,
    n_live_tup AS row_count
FROM pg_stat_user_tables
ORDER BY n_live_tup DESC;


-- Sanity Check Across All Tables

SELECT 'dim_stores'           AS table_name, COUNT(*) AS rows FROM dim_stores
UNION ALL
SELECT 'dim_skus',                           COUNT(*) FROM dim_skus
UNION ALL
SELECT 'dim_customers',                      COUNT(*) FROM dim_customers
UNION ALL
SELECT 'dim_pickers',                        COUNT(*) FROM dim_pickers
UNION ALL
SELECT 'fact_orders',                        COUNT(*) FROM fact_orders
UNION ALL
SELECT 'fact_order_items',                   COUNT(*) FROM fact_order_items
UNION ALL
SELECT 'fact_picker_activity',               COUNT(*) FROM fact_picker_activity
UNION ALL
SELECT 'fact_substitutions',                 COUNT(*) FROM fact_substitutions
ORDER BY rows DESC;


-- SLA Achievement by Store

SELECT
    s.store_name,
    s.city,
    COUNT(o.order_id)                                    AS total_orders,
    ROUND(AVG(o.total_delivery_mins)::NUMERIC, 2)        AS avg_delivery_mins,
    ROUND(AVG(o.pick_time_mins)::NUMERIC, 2)             AS avg_pick_mins,
    ROUND(AVG(o.pack_time_mins)::NUMERIC, 2)             AS avg_pack_mins,
    ROUND(AVG(o.dispatch_time_mins)::NUMERIC, 2)         AS avg_dispatch_mins,
    ROUND(AVG(o.travel_time_mins)::NUMERIC, 2)           AS avg_travel_mins,
    ROUND(SUM(CASE WHEN o.sla_met = TRUE
              THEN 1 ELSE 0 END) * 100.0
              / COUNT(o.order_id), 2)                    AS sla_pct,
    ROUND(AVG(o.distance_km)::NUMERIC, 2)                AS avg_distance_km
FROM fact_orders o
JOIN dim_stores s ON o.store_id = s.store_id
WHERE o.order_status = 'Delivered'
GROUP BY s.store_name, s.city
ORDER BY sla_pct ASC;


-- SLA by Hour of Day

SELECT
    order_hour,
    COUNT(order_id)                                      AS total_orders,
    ROUND(AVG(total_delivery_mins)::NUMERIC, 2)          AS avg_delivery_mins,
    ROUND(SUM(CASE WHEN sla_met = TRUE
              THEN 1 ELSE 0 END) * 100.0
              / COUNT(order_id), 2)                      AS sla_pct,
    ROUND(AVG(travel_time_mins)::NUMERIC, 2)             AS avg_travel_mins,
    ROUND(AVG(pick_time_mins)::NUMERIC, 2)               AS avg_pick_mins
FROM fact_orders
WHERE order_status = 'Delivered'
GROUP BY order_hour
ORDER BY order_hour;


-- Delivery Percentiles by Store

SELECT
    s.store_name,
    s.city,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP
          (ORDER BY o.total_delivery_mins)::NUMERIC, 2)  AS p50_delivery,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP
          (ORDER BY o.total_delivery_mins)::NUMERIC, 2)  AS p75_delivery,
    ROUND(PERCENTILE_CONT(0.90) WITHIN GROUP
          (ORDER BY o.total_delivery_mins)::NUMERIC, 2)  AS p90_delivery,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP
          (ORDER BY o.total_delivery_mins)::NUMERIC, 2)  AS p95_delivery,
    COUNT(o.order_id)                                    AS total_orders
FROM fact_orders o
JOIN dim_stores s ON o.store_id = s.store_id
WHERE o.order_status = 'Delivered'
GROUP BY s.store_name, s.city
ORDER BY p90_delivery DESC;


-- Weekend vs Weekday SLA

SELECT
    s.store_name,
    o.is_weekend,
    COUNT(o.order_id)                                    AS total_orders,
    ROUND(AVG(o.total_delivery_mins)::NUMERIC, 2)        AS avg_delivery_mins,
    ROUND(SUM(CASE WHEN o.sla_met = TRUE
              THEN 1 ELSE 0 END) * 100.0
              / COUNT(o.order_id), 2)                    AS sla_pct
FROM fact_orders o
JOIN dim_stores s ON o.store_id = s.store_id
WHERE o.order_status = 'Delivered'
GROUP BY s.store_name, o.is_weekend
ORDER BY s.store_name, o.is_weekend;


-- Rolling 7-Day SLA Trend

SELECT
    store_id,
    order_date,
    daily_orders,
    daily_sla_pct,
    ROUND(AVG(daily_sla_pct) OVER (
        PARTITION BY store_id
        ORDER BY order_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    )::NUMERIC, 2)                                       AS rolling_7day_sla_pct
FROM (
    SELECT
        store_id,
        order_date::DATE                                 AS order_date,
        COUNT(order_id)                                  AS daily_orders,
        ROUND(SUM(CASE WHEN sla_met = TRUE
                  THEN 1 ELSE 0 END) * 100.0
                  / COUNT(order_id), 2)                  AS daily_sla_pct
    FROM fact_orders
    WHERE order_status = 'Delivered'
    GROUP BY store_id, order_date::DATE
) daily
ORDER BY store_id, order_date;


-- Monthly P&L per Store

SELECT
    s.store_name,
    s.city,
    DATE_TRUNC('month', o.order_date::DATE)               AS month,
    COUNT(o.order_id)                                     AS total_orders,
    ROUND(SUM(o.net_order_value_inr)::NUMERIC, 0)         AS gross_revenue,
    ROUND(SUM(o.delivery_cost_inr)::NUMERIC, 0)           AS total_delivery_cost,
    ROUND(SUM(o.discount_amount_inr)::NUMERIC, 0)         AS total_discounts,
    s.monthly_fixed_cost_inr,
    ROUND(SUM(o.gross_profit_inr)::NUMERIC, 0)            AS gross_profit,
    ROUND(SUM(o.gross_profit_inr)::NUMERIC
          - s.monthly_fixed_cost_inr, 0)                  AS net_profit,
    ROUND(
        (SUM(o.gross_profit_inr)::NUMERIC
         - s.monthly_fixed_cost_inr)
        / NULLIF(SUM(o.net_order_value_inr)::NUMERIC, 0)
        * 100
    , 2)                                                  AS net_margin_pct
FROM fact_orders o
JOIN dim_stores s ON o.store_id = s.store_id
WHERE o.order_status = 'Delivered'
GROUP BY s.store_name, s.city,
         DATE_TRUNC('month', o.order_date::DATE),
         s.monthly_fixed_cost_inr
ORDER BY s.store_name, month;


-- Store P&L Summary with Status

SELECT
    s.store_name,
    s.city,
    COUNT(DISTINCT monthly.month)                        AS months_active,
    ROUND(AVG(monthly.monthly_revenue)::NUMERIC, 0)      AS avg_monthly_revenue,
    ROUND(AVG(monthly.monthly_profit)::NUMERIC, 0)       AS avg_monthly_profit,
    s.monthly_fixed_cost_inr                             AS fixed_cost,
    CASE
        WHEN AVG(monthly.monthly_profit) > 0      THEN 'PROFITABLE'
        WHEN AVG(monthly.monthly_profit) > -50000 THEN 'MARGINAL'
        ELSE 'LOSS MAKING'
    END                                                  AS store_status
FROM (
    SELECT
        o.store_id,
        DATE_TRUNC('month', o.order_date::DATE)          AS month,
        SUM(o.net_order_value_inr)                       AS monthly_revenue,
        SUM(o.gross_profit_inr)::NUMERIC
        - MAX(s2.monthly_fixed_cost_inr)                 AS monthly_profit
    FROM fact_orders o
    JOIN dim_stores s2 ON o.store_id = s2.store_id
    WHERE o.order_status = 'Delivered'
    GROUP BY o.store_id,
             DATE_TRUNC('month', o.order_date::DATE)
) monthly
JOIN dim_stores s ON monthly.store_id = s.store_id
GROUP BY s.store_name, s.city,
         s.monthly_fixed_cost_inr
ORDER BY avg_monthly_profit DESC;


-- Break-Even Analysis

SELECT
    s.store_name,
    s.city,
    s.monthly_fixed_cost_inr,
    ROUND(AVG(o.gross_profit_inr)::NUMERIC, 2)           AS avg_profit_per_order,
    CEIL(s.monthly_fixed_cost_inr
         / NULLIF(AVG(o.gross_profit_inr), 0))           AS orders_to_breakeven_monthly,
    CEIL(s.monthly_fixed_cost_inr
         / NULLIF(AVG(o.gross_profit_inr), 0)
         / 30.0)                                         AS orders_to_breakeven_daily,
    ROUND(AVG(daily_orders), 0)                          AS actual_avg_daily_orders,
    CASE
        WHEN ROUND(AVG(daily_orders), 0) >=
             CEIL(s.monthly_fixed_cost_inr
             / NULLIF(AVG(o.gross_profit_inr), 0) / 30.0)
        THEN 'ABOVE BREAKEVEN'
        ELSE 'BELOW BREAKEVEN'
    END                                                  AS breakeven_status
FROM fact_orders o
JOIN dim_stores s ON o.store_id = s.store_id
JOIN (
    SELECT
        store_id,
        order_date::DATE      AS order_date,
        COUNT(order_id)       AS daily_orders
    FROM fact_orders
    WHERE order_status = 'Delivered'
    GROUP BY store_id, order_date::DATE
) daily ON o.store_id = daily.store_id
WHERE o.order_status = 'Delivered'
GROUP BY s.store_name, s.city,
         s.monthly_fixed_cost_inr
ORDER BY orders_to_breakeven_daily ASC;


-- Revenue Per Square Foot

SELECT
    s.store_name,
    s.city,
    s.store_area_sqft,
    ROUND(CAST(SUM(o.net_order_value_inr) AS NUMERIC), 0)
                                                          AS total_revenue,
    ROUND(CAST(SUM(o.net_order_value_inr) AS NUMERIC)
          / CAST(s.store_area_sqft AS NUMERIC), 2)        AS revenue_per_sqft,
    RANK() OVER (
        ORDER BY SUM(o.net_order_value_inr) DESC
    )                                                     AS efficiency_rank
FROM fact_orders o
JOIN dim_stores s
    ON o.store_id = s.store_id
WHERE o.order_status = 'Delivered'
GROUP BY
    s.store_name,
    s.city,
    s.store_area_sqft
ORDER BY revenue_per_sqft DESC;


-- Top Pickers by Productivity

SELECT
    p.picker_name,
    p.skill_level,
    p.shift,
    s.store_name,
    COUNT(pa.activity_id)                                 AS total_picks,
    ROUND(CAST(AVG(pa.pick_rate_per_min) AS NUMERIC), 3)  AS avg_pick_rate,
    ROUND(CAST(AVG(pa.pick_duration_mins) AS NUMERIC), 2) AS avg_pick_duration,
    ROUND(CAST(AVG(pa.items_picked) AS NUMERIC), 1)       AS avg_items_per_order,
    CAST(SUM(pa.errors_made) AS INT)                      AS total_errors,
    ROUND(
        CAST(SUM(pa.errors_made) AS NUMERIC) * 100.0
        / NULLIF(CAST(COUNT(pa.activity_id) AS NUMERIC), 0)
    , 2)                                                  AS error_rate_pct,
    RANK() OVER (
        ORDER BY AVG(pa.pick_rate_per_min) DESC
    )                                                     AS productivity_rank
FROM fact_picker_activity pa
JOIN dim_pickers p
    ON pa.picker_id = p.picker_id
JOIN dim_stores s
    ON pa.store_id = s.store_id
GROUP BY
    p.picker_name,
    p.skill_level,
    p.shift,
    s.store_name
ORDER BY avg_pick_rate DESC;


-- Picker vs Store Average

SELECT
    sub.picker_name,
    sub.store_name,
    sub.skill_level,
    ROUND(CAST(sub.picker_avg AS NUMERIC), 3)             AS picker_avg_rate,
    ROUND(CAST(sub.store_avg AS NUMERIC), 3)              AS store_avg_rate,
    ROUND(CAST(sub.picker_avg - sub.store_avg AS NUMERIC), 3)
                                                          AS variance_from_store_avg,
    CASE
        WHEN sub.picker_avg > sub.store_avg * 1.1
            THEN 'HIGH PERFORMER'
        WHEN sub.picker_avg < sub.store_avg * 0.9
            THEN 'NEEDS COACHING'
        ELSE 'ON TRACK'
    END                                                   AS performance_flag
FROM (
    SELECT
        p.picker_name,
        s.store_name,
        p.skill_level,
        pa.store_id,
        AVG(pa.pick_rate_per_min)                         AS picker_avg,
        AVG(AVG(pa.pick_rate_per_min)) OVER (
            PARTITION BY pa.store_id
        )                                                 AS store_avg
    FROM fact_picker_activity pa
    JOIN dim_pickers p
        ON pa.picker_id = p.picker_id
    JOIN dim_stores s
        ON pa.store_id = s.store_id
    GROUP BY
        p.picker_name,
        s.store_name,
        p.skill_level,
        pa.store_id
) sub
ORDER BY sub.store_name, picker_avg_rate DESC;


-- Pick Time Contribution to SLA Breach

SELECT
    s.store_name,
    CASE
        WHEN o.sla_met = TRUE THEN 'SLA Met'
        ELSE 'SLA Breached'
    END                                                   AS sla_status,
    COUNT(o.order_id)                                     AS order_count,
    ROUND(CAST(AVG(o.pick_time_mins) AS NUMERIC), 2)      AS avg_pick_time,
    ROUND(CAST(AVG(o.pack_time_mins) AS NUMERIC), 2)      AS avg_pack_time,
    ROUND(CAST(AVG(o.travel_time_mins) AS NUMERIC), 2)    AS avg_travel_time,
    ROUND(CAST(AVG(o.total_delivery_mins) AS NUMERIC), 2) AS avg_total_delivery
FROM fact_orders o
JOIN dim_stores s
    ON o.store_id = s.store_id
WHERE o.order_status = 'Delivered'
GROUP BY
    s.store_name,
    o.sla_met
ORDER BY s.store_name, sla_status;


-- Hourly Picker Workload

SELECT
    o.order_hour,
    COUNT(o.order_id)                                     AS total_orders,
    ROUND(CAST(AVG(o.pick_time_mins) AS NUMERIC), 2)      AS avg_pick_time,
    ROUND(
        CAST(COUNT(o.order_id) AS NUMERIC)
        * CAST(AVG(o.pick_time_mins) AS NUMERIC)
        / 60.0
    , 1)                                                  AS picker_hours_needed,
    CASE
        WHEN o.order_hour BETWEEN 7  AND 11 THEN 'Morning Peak'
        WHEN o.order_hour BETWEEN 12 AND 17 THEN 'Afternoon'
        WHEN o.order_hour BETWEEN 18 AND 21 THEN 'Evening Peak'
        ELSE 'Off Peak'
    END                                                   AS time_band
FROM fact_orders o
WHERE o.order_status = 'Delivered'
GROUP BY o.order_hour
ORDER BY o.order_hour;


-- Top 20 SKUs by Revenue

SELECT
    sk.sku_name,
    sk.category,
    sk.velocity_class,
    COUNT(DISTINCT oi.order_id)                           AS orders_containing_sku,
    CAST(SUM(oi.quantity) AS INT)                         AS total_qty_sold,
    ROUND(CAST(SUM(oi.item_total_inr) AS NUMERIC), 0)     AS total_revenue,
    ROUND(CAST(SUM(oi.item_margin_inr) AS NUMERIC), 0)    AS total_margin,
    ROUND(CAST(AVG(oi.item_margin_pct) AS NUMERIC), 3)    AS avg_margin_pct,
    RANK() OVER (
        ORDER BY SUM(oi.item_total_inr) DESC
    )                                                     AS revenue_rank
FROM fact_order_items oi
JOIN dim_skus sk
    ON oi.sku_id = sk.sku_id
GROUP BY
    sk.sku_name,
    sk.category,
    sk.velocity_class
ORDER BY total_revenue DESC
LIMIT 20;


-- Category Performance by Store

SELECT
    sub.store_name,
    sub.city,
    sub.category,
    sub.orders,
    sub.total_qty,
    sub.revenue,
    ROUND(
        CAST(sub.revenue AS NUMERIC) * 100.0
        / NULLIF(CAST(sub.store_total_revenue AS NUMERIC), 0)
    , 2)                                                  AS revenue_share_pct
FROM (
    SELECT
        s.store_name,
        s.city,
        oi.category,
        COUNT(DISTINCT oi.order_id)                       AS orders,
        CAST(SUM(oi.quantity) AS INT)                     AS total_qty,
        ROUND(CAST(SUM(oi.item_total_inr) AS NUMERIC), 0) AS revenue,
        SUM(SUM(oi.item_total_inr)) OVER (
            PARTITION BY s.store_name
        )                                                 AS store_total_revenue
    FROM fact_order_items oi
    JOIN dim_stores s
        ON oi.store_id = s.store_id
    GROUP BY
        s.store_name,
        s.city,
        oi.category
) sub
ORDER BY sub.store_name, sub.revenue DESC;


-- Substitution Acceptance Rate

SELECT
    sub.original_category,
    sub.same_category,
    sub.reason_for_sub,
    COUNT(sub.substitution_id)                            AS total_substitutions,
    SUM(CASE WHEN sub.customer_accepted = TRUE
             THEN 1 ELSE 0 END)                           AS accepted_count,
    ROUND(
        CAST(SUM(CASE WHEN sub.customer_accepted = TRUE
                      THEN 1 ELSE 0 END) AS NUMERIC)
        * 100.0
        / NULLIF(COUNT(sub.substitution_id), 0)
    , 2)                                                  AS acceptance_rate_pct,
    ROUND(CAST(AVG(sub.price_difference_inr) AS NUMERIC), 2)
                                                          AS avg_price_diff
FROM fact_substitutions sub
GROUP BY
    sub.original_category,
    sub.same_category,
    sub.reason_for_sub
ORDER BY acceptance_rate_pct DESC;


-- SKU Stockout Proxy

SELECT
    sk.sku_name,
    sk.category,
    sk.velocity_class,
    COUNT(sub.substitution_id)                            AS times_substituted,
    ROUND(
        CAST(SUM(CASE WHEN sub.customer_accepted = FALSE
                      THEN 1 ELSE 0 END) AS NUMERIC)
        * 100.0
        / NULLIF(COUNT(sub.substitution_id), 0)
    , 2)                                                  AS rejection_rate_pct,
    ROUND(
        CAST(COUNT(sub.substitution_id) AS NUMERIC)
        * 100.0
        / NULLIF(
            (SELECT COUNT(*)
             FROM fact_orders
             WHERE order_status = 'Delivered')
        , 0)
    , 4)                                                  AS sub_rate_per_order_pct
FROM fact_substitutions sub
JOIN dim_skus sk
    ON sub.original_sku_id = sk.sku_id
GROUP BY
    sk.sku_name,
    sk.category,
    sk.velocity_class
ORDER BY times_substituted DESC
LIMIT 20;


-- Monthly Revenue Growth Rate

SELECT
    growth.store_name,
    growth.city,
    growth.month,
    growth.monthly_revenue,
    growth.prev_month_revenue,
    CASE
        WHEN growth.prev_month_revenue IS NULL THEN NULL
        ELSE ROUND(
            (CAST(growth.monthly_revenue AS NUMERIC)
             - CAST(growth.prev_month_revenue AS NUMERIC))
            / NULLIF(CAST(growth.prev_month_revenue AS NUMERIC), 0)
            * 100
        , 2)
    END                                                   AS mom_growth_pct
FROM (
    SELECT
        s.store_name,
        s.city,
        DATE_TRUNC('month', o.order_date::DATE)           AS month,
        ROUND(CAST(SUM(o.net_order_value_inr) AS NUMERIC), 0)
                                                          AS monthly_revenue,
        LAG(ROUND(CAST(SUM(o.net_order_value_inr) AS NUMERIC), 0))
            OVER (
                PARTITION BY s.store_name
                ORDER BY DATE_TRUNC('month', o.order_date::DATE)
            )                                             AS prev_month_revenue
    FROM fact_orders o
    JOIN dim_stores s
        ON o.store_id = s.store_id
    WHERE o.order_status = 'Delivered'
    GROUP BY
        s.store_name,
        s.city,
        DATE_TRUNC('month', o.order_date::DATE)
) growth
ORDER BY growth.store_name, growth.month;


-- Day of Week Demand Pattern

SELECT
    day_of_week,
    COUNT(order_id)                                       AS total_orders,
    ROUND(CAST(AVG(net_order_value_inr) AS NUMERIC), 2)   AS avg_order_value,
    ROUND(CAST(AVG(total_delivery_mins) AS NUMERIC), 2)   AS avg_delivery_mins,
    ROUND(
        CAST(SUM(CASE WHEN sla_met = TRUE
                      THEN 1 ELSE 0 END) AS NUMERIC)
        * 100.0
        / NULLIF(COUNT(order_id), 0)
    , 2)                                                  AS sla_pct
FROM fact_orders
WHERE order_status = 'Delivered'
GROUP BY day_of_week
ORDER BY
    CASE day_of_week
        WHEN 'Monday'    THEN 1
        WHEN 'Tuesday'   THEN 2
        WHEN 'Wednesday' THEN 3
        WHEN 'Thursday'  THEN 4
        WHEN 'Friday'    THEN 5
        WHEN 'Saturday'  THEN 6
        WHEN 'Sunday'    THEN 7
    END;


-- Customer Frequency Segments

SELECT
    seg.frequency_segment,
    COUNT(seg.customer_id)                                AS customer_count,
    ROUND(CAST(AVG(seg.total_orders) AS NUMERIC), 1)      AS avg_orders,
    ROUND(CAST(AVG(seg.avg_order_value) AS NUMERIC), 2)   AS avg_order_value,
    ROUND(CAST(AVG(seg.total_spend) AS NUMERIC), 0)       AS avg_total_spend
FROM (
    SELECT
        customer_id,
        COUNT(order_id)                                   AS total_orders,
        AVG(net_order_value_inr)                          AS avg_order_value,
        SUM(net_order_value_inr)                          AS total_spend,
        CASE
            WHEN COUNT(order_id) >= 20 THEN 'Power User'
            WHEN COUNT(order_id) >= 10 THEN 'Regular'
            WHEN COUNT(order_id) >= 4  THEN 'Occasional'
            ELSE 'One-Time'
        END                                               AS frequency_segment
    FROM fact_orders
    WHERE order_status = 'Delivered'
    GROUP BY customer_id
) seg
GROUP BY seg.frequency_segment
ORDER BY avg_total_spend DESC;


-- Dark Store Scorecard ⭐ Most Important

SELECT
    s.store_name,
    s.city,
    m.total_orders,
    ROUND(CAST(m.total_revenue AS NUMERIC) / 100000, 1)   AS revenue_lac,
    ROUND(CAST(m.avg_delivery_mins AS NUMERIC), 2)        AS avg_delivery_mins,
    ROUND(CAST(m.sla_pct AS NUMERIC), 1)                  AS sla_pct,
    ROUND(CAST(m.avg_order_value AS NUMERIC), 0)          AS avg_order_value,
    ROUND(CAST(m.avg_profit_per_order AS NUMERIC), 2)     AS avg_profit_per_order,
    RANK() OVER (ORDER BY m.total_revenue        DESC)    AS revenue_rank,
    RANK() OVER (ORDER BY m.sla_pct              DESC)    AS sla_rank,
    RANK() OVER (ORDER BY m.avg_profit_per_order DESC)    AS profit_rank,
    ROUND(
        CAST(
            RANK() OVER (ORDER BY m.total_revenue        DESC) +
            RANK() OVER (ORDER BY m.sla_pct              DESC) +
            RANK() OVER (ORDER BY m.avg_profit_per_order DESC)
        AS NUMERIC) / 3.0
    , 1)                                                  AS composite_rank_score
FROM (
    SELECT
        o.store_id,
        COUNT(o.order_id)                                 AS total_orders,
        SUM(o.net_order_value_inr)                        AS total_revenue,
        AVG(o.total_delivery_mins)                        AS avg_delivery_mins,
        CAST(SUM(CASE WHEN o.sla_met = TRUE
                      THEN 1 ELSE 0 END) AS NUMERIC)
            * 100.0
            / NULLIF(COUNT(o.order_id), 0)                AS sla_pct,
        AVG(o.net_order_value_inr)                        AS avg_order_value,
        AVG(o.gross_profit_inr)                           AS avg_profit_per_order
    FROM fact_orders o
    WHERE o.order_status = 'Delivered'
    GROUP BY o.store_id
) m
JOIN dim_stores s
    ON m.store_id = s.store_id
ORDER BY composite_rank_score ASC;


--

SELECT
    sla_met,
    COUNT(*) AS row_count
FROM fact_orders
GROUP BY sla_met;


--

SELECT
    ROUND(AVG(total_delivery_mins)::NUMERIC, 2)  AS avg_delivery,
    MIN(total_delivery_mins)                      AS min_delivery,
    MAX(total_delivery_mins)                      AS max_delivery,
    PERCENTILE_CONT(0.50) WITHIN GROUP
        (ORDER BY total_delivery_mins)            AS median_delivery
FROM fact_orders
WHERE order_status = 'Delivered';


--

UPDATE fact_orders
SET
    pick_time_mins     = ROUND((RANDOM() * 2 + 1.5)::NUMERIC, 2),
    pack_time_mins     = ROUND((RANDOM() * 1 + 0.5)::NUMERIC, 2),
    dispatch_time_mins = ROUND((RANDOM() * 0.5 + 0.3)::NUMERIC, 2),
    travel_time_mins   = ROUND((RANDOM() * 4 + 2.5)::NUMERIC, 2);


--

UPDATE fact_orders
SET total_delivery_mins = ROUND(
    (pick_time_mins + pack_time_mins +
     dispatch_time_mins + travel_time_mins)::NUMERIC, 2
);


--

UPDATE fact_orders
SET sla_met = (total_delivery_mins <= 10);


--

UPDATE fact_orders
SET gross_profit_inr = ROUND(
    (net_order_value_inr - delivery_cost_inr)::NUMERIC, 2
);


--

UPDATE fact_orders
SET is_profitable = (gross_profit_inr > 0);


--

SELECT
    sla_met,
    COUNT(*)                                             AS row_count,
    ROUND(COUNT(*) * 100.0
          / SUM(COUNT(*)) OVER(), 1)                    AS pct
FROM fact_orders
GROUP BY sla_met;


--

SELECT
    ROUND(AVG(total_delivery_mins)::NUMERIC, 2)          AS avg_delivery,
    ROUND(MIN(total_delivery_mins)::NUMERIC, 2)          AS min_delivery,
    ROUND(MAX(total_delivery_mins)::NUMERIC, 2)          AS max_delivery
FROM fact_orders
WHERE order_status = 'Delivered';


--

SELECT
    is_profitable,
    COUNT(*)                                             AS row_count,
    ROUND(COUNT(*) * 100.0
          / SUM(COUNT(*)) OVER(), 1)                    AS pct
FROM fact_orders
GROUP BY is_profitable;


--

-- Make ~12% of orders unprofitable by increasing delivery cost
UPDATE fact_orders
SET
    delivery_cost_inr = net_order_value_inr * (0.85 + RANDOM() * 0.3),
    gross_profit_inr  = ROUND((net_order_value_inr - 
                        (net_order_value_inr * (0.85 + RANDOM() * 0.3)))::NUMERIC, 2),
    is_profitable     = (net_order_value_inr - 
                        (net_order_value_inr * (0.85 + RANDOM() * 0.3))) > 0
WHERE order_id IN (
    SELECT order_id FROM fact_orders
    ORDER BY RANDOM()
    LIMIT (SELECT ROUND(COUNT(*) * 0.12)::INT FROM fact_orders)
);


--

SELECT
    is_profitable,
    COUNT(*)                                             AS row_count,
    ROUND(COUNT(*) * 100.0
          / SUM(COUNT(*)) OVER(), 1)                    AS pct
FROM fact_orders
GROUP BY is_profitable;



-- Reset all to FALSE first
UPDATE fact_orders SET sla_met = FALSE;

-- Set specific % of rows to TRUE per store
UPDATE fact_orders
SET sla_met = TRUE
WHERE order_id IN (
    SELECT order_id FROM (
        SELECT
            order_id,
            store_id,
            ROW_NUMBER() OVER (
                PARTITION BY store_id
                ORDER BY RANDOM()
            )                                            AS rn,
            COUNT(*) OVER (
                PARTITION BY store_id
            )                                            AS total
        FROM fact_orders
        WHERE order_status = 'Delivered'
    ) ranked
    WHERE CASE store_id
        WHEN 'STR_001' THEN rn <= total * 0.78
        WHEN 'STR_002' THEN rn <= total * 0.82
        WHEN 'STR_003' THEN rn <= total * 0.65
        WHEN 'STR_004' THEN rn <= total * 0.85
        WHEN 'STR_005' THEN rn <= total * 0.72
        WHEN 'STR_006' THEN rn <= total * 0.91
        WHEN 'STR_007' THEN rn <= total * 0.61
        WHEN 'STR_008' THEN rn <= total * 0.76
        WHEN 'STR_009' THEN rn <= total * 0.69
        WHEN 'STR_010' THEN rn <= total * 0.88
        ELSE FALSE
    END
);


--

SELECT
    s.store_name,
    ROUND(SUM(CASE WHEN o.sla_met = TRUE
              THEN 1 ELSE 0 END) * 100.0
              / COUNT(*), 1)                             AS sla_pct
FROM fact_orders o
JOIN dim_stores s ON o.store_id = s.store_id
WHERE order_status = 'Delivered'
GROUP BY s.store_name
ORDER BY sla_pct ASC;