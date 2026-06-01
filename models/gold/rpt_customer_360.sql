{{
  config(
    materialized = 'table',
    tags         = ['gold', 'reporting', 'customers']
  )
}}

WITH rfm_raw AS (
    SELECT
        customer_id,
        MAX(order_date)         AS last_order_date,
        COUNT(order_id)         AS frequency,
        SUM(final_amount)       AS monetary
    FROM {{ ref('fct_orders') }}
    WHERE is_cancelled = FALSE
      AND is_refunded  = FALSE
    GROUP BY 1
),

rfm_scores AS (
    SELECT
        customer_id,
        last_order_date,
        frequency,
        monetary,
        DATEDIFF('day', last_order_date, CURRENT_DATE()) AS recency_days,
        NTILE(5) OVER (ORDER BY last_order_date DESC)    AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC)           AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)            AS m_score
    FROM rfm_raw
),

customer_details AS (
    SELECT * FROM {{ ref('dim_customers') }}
),

favorite_payment AS (
    SELECT
        customer_id,
        payment_method,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY COUNT(*) DESC
        ) AS rn
    FROM {{ ref('fct_orders') }}
    GROUP BY 1, 2
)

SELECT
    c.customer_id,
    c.customer_name,
    c.country,
    c.customer_segment,
    c.total_orders,
    c.first_order_date,
    c.last_order_date,
    c.lifetime_value,
    c.avg_order_value,
    c.delivered_orders,
    c.cancelled_orders,
    c.refunded_orders,
    c.days_since_last_order,
    r.recency_days,
    r.frequency                AS active_orders,
    r.monetary                 AS active_revenue,
    r.r_score,
    r.f_score,
    r.m_score,
    ROUND(
        (r.r_score + r.f_score + r.m_score) / 3.0
    , 1)                       AS rfm_avg_score,
    fp.payment_method          AS preferred_payment_method,
    CASE
        WHEN r.recency_days > 180 THEN 'High'
        WHEN r.recency_days > 90  THEN 'Medium'
        ELSE 'Low'
    END                        AS churn_risk,
    CURRENT_TIMESTAMP()        AS _loaded_at

FROM customer_details c
LEFT JOIN rfm_scores r       USING (customer_id)
LEFT JOIN favorite_payment fp ON c.customer_id = fp.customer_id
    AND fp.rn = 1

ORDER BY c.lifetime_value DESC