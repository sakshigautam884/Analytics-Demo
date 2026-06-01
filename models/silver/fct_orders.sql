{{
  config(
    materialized = 'table',
    tags         = ['silver', 'orders']
  )
}}

/*
  Silver / fct_orders
  ───────────────────
  Clean, enriched orders fact table.
  Joins bronze orders with the customer dimension and applies business rules.
*/

WITH orders AS (
    SELECT * FROM {{ ref('raw_order') }}
),

customers AS (
    SELECT
        customer_id,
        customer_segment,
        country         AS customer_country
    FROM {{ ref('dim_customers') }}
),

enriched AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.customer_name,
        o.country,
        c.customer_segment,

        -- Amounts
        o.order_amount,
        o.discount_amount,
        o.final_amount,
        ROUND(
            CASE
                WHEN o.order_amount = 0 THEN 0
                ELSE o.discount_amount / o.order_amount * 100
            END, 2
        )                                       AS discount_pct,

        -- Payment & status
        o.payment_method,
        o.status,

        -- Status flags
        (o.status = 'delivered')                AS is_delivered,
        (o.status = 'cancelled')                AS is_cancelled,
        (o.status = 'refunded')                 AS is_refunded,
        (o.status IN ('pending','processing'))  AS is_open,

        -- Dates
        o.created_at                            AS order_date,
        o.updated_at                            AS last_updated_date,
        DATE_TRUNC('month', o.created_at)       AS order_month,
        DATE_TRUNC('week',  o.created_at)       AS order_week,
        DAYOFWEEK(o.created_at)                 AS order_day_of_week,

        -- Audit
        o._loaded_at,
        o._dbt_run_id

    FROM orders o
    LEFT JOIN customers c USING (customer_id)
)

SELECT * FROM enriched
