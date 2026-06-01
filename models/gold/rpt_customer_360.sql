version: 2

models:
  - name: rpt_sales_summary
    description: >
      Monthly sales summary aggregated by country, customer segment, and payment method.
      Primary BI reporting table for the sales dashboard.
    columns:
      - name: order_month
        description: "First day of the month (DATE_TRUNC)."
        tests:
          - not_null
      - name: net_revenue
        description: "Sum of final_amount for the period/slice."
      - name: delivery_rate_pct
        description: "% of orders that reached delivered status."
      - name: cancellation_rate_pct
        description: "% of orders that were cancelled."

  - name: rpt_customer_360
    description: >
      Customer 360 view with lifetime value, RFM scores, churn risk,
      and preferred payment method. One row per customer.
    columns:
      - name: customer_id
        description: "Unique customer identifier."
        tests:
          - unique
          - not_null
      - name: rfm_avg_score
        description: "Average of Recency, Frequency, Monetary NTILE(5) scores."
      - name: churn_risk
        description: "Low / Medium / High based on days since last order."
        tests:
          - accepted_values:
              values: ['Low', 'Medium', 'High']
