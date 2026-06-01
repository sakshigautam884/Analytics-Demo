{{ config(materialized='incremental', unique_key='order_id') }}

SELECT
    TRY_TO_NUMBER(customer_id) AS customer_id,
    TRY_TO_NUMBER(order_id) AS order_id,
    customer_name::STRING AS customer_name,
    country::STRING AS country,
    TRY_TO_DOUBLE(order_amount) AS order_amount,
    TRY_TO_DOUBLE(discount_amount) AS discount_amount,
    TRY_TO_DOUBLE(final_amount) AS final_amount,
    payment_method::STRING AS payment_method,
    status::STRING AS status,
    TO_DATE(created_at) AS created_at,
    TO_DATE(updated_at) AS updated_at

FROM {{ source('raw', 'RAW_ORDERS') }}

{% if is_incremental() %}

WHERE TO_DATE(created_at) >
(
    SELECT COALESCE(MAX(created_at), '1900-01-01')
    FROM {{ this }}
)

{% endif %}