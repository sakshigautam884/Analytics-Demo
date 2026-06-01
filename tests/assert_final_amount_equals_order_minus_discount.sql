-- tests/assert_final_amount_equals_order_minus_discount.sql
-- Warn only — source data mein rounding differences ho sakti hain

{{
  config(
    severity = 'warn'
  )
}}

SELECT
    order_id,
    order_amount,
    discount_amount,
    final_amount,
    (order_amount - discount_amount)        AS expected_final_amount,
    ABS(final_amount - (order_amount - discount_amount)) AS diff
FROM {{ ref('raw_order') }}
WHERE
    order_amount    IS NOT NULL
    AND discount_amount IS NOT NULL
    AND final_amount    IS NOT NULL
    AND ABS(final_amount - (order_amount - discount_amount)) > 1.00