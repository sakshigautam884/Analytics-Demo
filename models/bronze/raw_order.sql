{{
  config(
    materialized = 'incremental',
    unique_key   = 'order_id',
    on_schema_change = 'sync_all_columns',
    tags         = ['bronze', 'orders']
  )
}}

WITH source AS (
    SELECT * FROM {{ source('raw', 'RAW_ORDERS') }}
),

deduped AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY updated_at DESC
        ) AS rn
    FROM source
),

final AS (
    SELECT
        TRY_TO_NUMBER(customer_id)      AS customer_id,
        TRY_TO_NUMBER(order_id)         AS order_id,
        customer_name::STRING           AS customer_name,
        country::STRING                 AS country,
        TRY_TO_DOUBLE(order_amount)     AS order_amount,
        TRY_TO_DOUBLE(discount_amount)  AS discount_amount,
        TRY_TO_DOUBLE(final_amount)     AS final_amount,
        payment_method::STRING          AS payment_method,
        status::STRING                  AS status,
        TO_DATE(created_at)             AS created_at,
        TO_DATE(updated_at)             AS updated_at,
        CURRENT_TIMESTAMP()             AS _loaded_at,
        '{{ invocation_id }}'           AS _dbt_run_id
    FROM deduped
    WHERE rn = 1
     AND customer_id IS NOT NULL
     AND order_id    IS NOT NULL
     AND created_at  IS NOT NULL
)

SELECT * FROM final

{% if is_incremental() %}
    WHERE created_at > (
        SELECT COALESCE(MAX(created_at), '{{ var("start_date") }}')
        FROM {{ this }}
    )
{% endif %}