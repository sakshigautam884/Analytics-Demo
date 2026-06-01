{{
  config(
    materialized = 'table',
    tags         = ['silver', 'orders']
  )
}}

WITH orders AS (
    SELECT * FROM {{ ref('raw_order') }}
),

customers AS (
    SELECT
        customer_id,
        customer_segment
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

        -- Payment
        o.payment_method,

        -- Status (map to standard values)
        CASE UPPER(o.status)
            WHEN 'ACTIVE'   THEN 'active'
            WHEN 'INACTIVE' THEN 'inactive'
            WHEN 'PENDING'  THEN 'pending'
            WHEN 'UNKNOWN'  THEN 'unknown'
            ELSE LOWER(o.status)
        END                                     AS status,

        -- Status flags
        (UPPER(o.status) = 'ACTIVE')            AS is_delivered,
        (UPPER(o.status) = 'INACTIVE')          AS is_cancelled,
        (UPPER(o.status) = 'UNKNOWN')           AS is_refunded,
        (UPPER(o.status) = 'PENDING')           AS is_open,

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