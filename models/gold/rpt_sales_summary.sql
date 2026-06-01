{{
  config(
    materialized = 'table',
    tags         = ['gold', 'reporting', 'sales']
  )
}}

SELECT
    order_month,
    country,
    customer_segment,
    payment_method,

    COUNT(order_id)                     AS total_orders,
    COUNT(DISTINCT customer_id)         AS unique_customers,

    SUM(order_amount)                   AS gross_revenue,
    SUM(discount_amount)                AS total_discounts,
    SUM(final_amount)                   AS net_revenue,
    ROUND(AVG(final_amount), 2)         AS avg_order_value,
    ROUND(AVG(discount_pct), 2)         AS avg_discount_pct,

    SUM(CASE WHEN is_delivered  THEN 1 ELSE 0 END) AS delivered_orders,
    SUM(CASE WHEN is_cancelled  THEN 1 ELSE 0 END) AS cancelled_orders,
    SUM(CASE WHEN is_refunded   THEN 1 ELSE 0 END) AS refunded_orders,
    SUM(CASE WHEN is_open       THEN 1 ELSE 0 END) AS open_orders,

    ROUND(
        SUM(CASE WHEN is_delivered THEN 1 ELSE 0 END)::FLOAT
        / NULLIF(COUNT(order_id), 0) * 100, 2
    )                                   AS delivery_rate_pct,

    ROUND(
        SUM(CASE WHEN is_cancelled THEN 1 ELSE 0 END)::FLOAT
        / NULLIF(COUNT(order_id), 0) * 100, 2
    )                                   AS cancellation_rate_pct,

    CURRENT_TIMESTAMP()                 AS _loaded_at

FROM {{ ref('fct_orders') }}

GROUP BY
    order_month,
    country,
    customer_segment,
    payment_method

ORDER BY
    order_month DESC,
    net_revenue  DESC