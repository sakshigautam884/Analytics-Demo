{% snapshot orders_snapshot %}

{{
  config(
    target_schema = 'snapshots',
    unique_key    = 'order_id',
    strategy      = 'check',
    check_cols    = ['status', 'final_amount', 'updated_at']
  )
}}

WITH deduped AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY updated_at DESC
        ) AS rn
    FROM {{ ref('raw_order') }}
)

SELECT
    order_id,
    customer_id,
    status,
    final_amount,
    payment_method,
    created_at,
    updated_at
FROM deduped
WHERE rn = 1

{% endsnapshot %}