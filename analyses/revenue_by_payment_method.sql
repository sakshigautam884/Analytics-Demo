-- analyses/revenue_by_payment_method.sql
-- Ad-hoc analysis: run with `dbt compile` then execute in Snowflake worksheet

SELECT
    payment_method,
    COUNT(*)            AS order_count,
    SUM(final_amount)   AS total_revenue,
    AVG(final_amount)   AS avg_order_value,
    MIN(final_amount)   AS min_order,
    MAX(final_amount)   AS max_order
FROM {{ ref('fct_orders') }}
WHERE NOT is_cancelled
GROUP BY 1
ORDER BY total_revenue DESC
