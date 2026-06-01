{{
  config(
    materialized = 'table',
    tags         = ['silver', 'customers']
  )
}}

/*
  Silver / dim_customers
  ──────────────────────
  Customer dimension derived from bronze orders.
  Uses the most recent record per customer to resolve slowly changing attributes.
*/

WITH ranked AS (
    SELECT
        customer_id,
        customer_name,
        country,

        -- pick the latest non-null values
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY created_at DESC, order_id DESC
        ) AS rn

    FROM {{ ref('raw_order') }}
    WHERE customer_id IS NOT NULL
),

deduped AS (
    SELECT
        customer_id,
        customer_name,
        country
    FROM ranked
    WHERE rn = 1
),

order_stats AS (
    SELECT
        customer_id,
        COUNT(*)                        AS total_orders,
        MIN(created_at)                 AS first_order_date,
        MAX(created_at)                 AS last_order_date,
        SUM(final_amount)               AS lifetime_value,
        AVG(final_amount)               AS avg_order_value,
        COUNT(CASE WHEN status = 'delivered'  THEN 1 END) AS delivered_orders,
        COUNT(CASE WHEN status = 'cancelled'  THEN 1 END) AS cancelled_orders,
        COUNT(CASE WHEN status = 'refunded'   THEN 1 END) AS refunded_orders
    FROM {{ ref('raw_order') }}
    GROUP BY 1
)

SELECT
    d.customer_id,
    d.customer_name,
    d.country,
    s.total_orders,
    s.first_order_date,
    s.last_order_date,
    s.lifetime_value,
    ROUND(s.avg_order_value, 2)         AS avg_order_value,
    s.delivered_orders,
    s.cancelled_orders,
    s.refunded_orders,

    -- Derived segments
    CASE
        WHEN s.lifetime_value >= 10000  THEN 'Platinum'
        WHEN s.lifetime_value >= 5000   THEN 'Gold'
        WHEN s.lifetime_value >= 1000   THEN 'Silver'
        ELSE 'Bronze'
    END                                 AS customer_segment,

    DATEDIFF('day', s.last_order_date, CURRENT_DATE()) AS days_since_last_order,

    CURRENT_TIMESTAMP()                 AS _loaded_at

FROM deduped d
LEFT JOIN order_stats s USING (customer_id)
