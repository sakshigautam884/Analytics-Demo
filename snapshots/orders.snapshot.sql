{% snapshot orders_snapshot %}

{{
  config(
    target_schema = 'snapshots',
    unique_key    = 'order_id',
    strategy      = 'check',
    check_cols    = ['status', 'final_amount', 'updated_at']
  )
}}

/*
  Snapshot tracks every status change on an order over time.
  Enables SCD Type-2 history for order lifecycle analytics.
*/

SELECT
    order_id,
    customer_id,
    status,
    final_amount,
    payment_method,
    created_at,
    updated_at
FROM {{ ref('raw_order') }}

{% endsnapshot %}
