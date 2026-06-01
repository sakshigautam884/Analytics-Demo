# Analytics POC – dbt + Snowflake

End-to-end dbt project implementing a **Medallion architecture** (Bronze → Silver → Gold)
on top of the `DBT_POC.RAW.RAW_ORDERS` Snowflake table.

---

## Project Structure

```
dbt_analytics_poc/
├── dbt_project.yml          # Project config + layer materializations
├── profiles.yml             # Snowflake connection (copy to ~/.dbt/)
├── packages.yml             # dbt-utils, dbt_expectations
│
├── models/
│   ├── sources.yml          # Source: DBT_POC.RAW.RAW_ORDERS
│   │
│   ├── bronze/              # Incremental, type-cast only
│   │   ├── raw_order.sql
│   │   └── schema.yml
│   │
│   ├── silver/              # Business logic, joins, enrichment
│   │   ├── dim_customers.sql
│   │   ├── fct_orders.sql
│   │   └── schema.yml
│   │
│   └── gold/                # BI-ready aggregates
│       ├── rpt_sales_summary.sql
│       ├── rpt_customer_360.sql
│       └── schema.yml
│
├── macros/
│   └── grant_privileges.sql # generate_schema_name override + GRANT helper
│
├── snapshots/
│   └── orders_snapshot.sql  # SCD Type-2 order status history
│
├── tests/
│   ├── generic/
│   │   └── positive_values.sql
│   └── assert_final_amount_equals_order_minus_discount.sql
│
└── analyses/
    └── revenue_by_payment_method.sql
```

---

## Data Lineage

```
DBT_POC.RAW.RAW_ORDERS  (Snowflake source)
        │
        ▼
  [Bronze] raw_order              ← incremental, cast & audit cols
        │
        ├──────────────────────┐
        ▼                      ▼
  [Silver] dim_customers    [Silver] fct_orders
        │                      │
        └──────────┬───────────┘
                   ▼
        [Gold] rpt_sales_summary
        [Gold] rpt_customer_360
```

---

## ⚡ Quickstart

### 1. Prerequisites
```bash
pip install dbt-snowflake
```

### 2. Configure connection
```bash
# Copy profiles.yml to your dbt home directory
cp profiles.yml ~/.dbt/profiles.yml

# Set required environment variables
export SNOWFLAKE_ACCOUNT="xy12345.us-east-1"   # your Snowflake account locator
export SNOWFLAKE_USER="your_username"
export SNOWFLAKE_PASSWORD="your_password"
export SNOWFLAKE_WAREHOUSE="COMPUTE_WH"
```

### 3. Install packages & verify connection
```bash
cd dbt_analytics_poc
dbt deps                   # install dbt-utils, dbt_expectations
dbt debug                  # verify Snowflake connection
```

### 4. First full run
```bash
dbt run                    # build all models
dbt test                   # run all tests
dbt snapshot               # capture order status history
dbt docs generate && dbt docs serve   # view lineage + docs
```

---

## 🔴 Fix: Snowflake Privilege Error

**Error you saw:**
```
[Snowflake] 003001 (42501): SQL access control error:
Insufficient privileges to operate on schema 'DBT_SGAUTAM'.
Your primary role DEV_ENGINEER_FR must have CREATE TABLE
granted on SCHEMA DBT_PROJECT.DBT_SGAUTAM.
```

**Root cause:** The dev role `DEV_ENGINEER_FR` lacks `CREATE TABLE` on your
personal dev schema `DBT_PROJECT.DBT_SGAUTAM`.

**Fix – run this in a Snowflake worksheet as ACCOUNTADMIN or SYSADMIN:**

```sql
-- 1. Grant CREATE TABLE on the personal dev schema
GRANT CREATE TABLE   ON SCHEMA DBT_PROJECT.DBT_SGAUTAM TO ROLE DEV_ENGINEER_FR;
GRANT CREATE VIEW    ON SCHEMA DBT_PROJECT.DBT_SGAUTAM TO ROLE DEV_ENGINEER_FR;
GRANT CREATE STAGE   ON SCHEMA DBT_PROJECT.DBT_SGAUTAM TO ROLE DEV_ENGINEER_FR;
GRANT USAGE          ON SCHEMA DBT_PROJECT.DBT_SGAUTAM TO ROLE DEV_ENGINEER_FR;
GRANT USAGE          ON DATABASE DBT_PROJECT            TO ROLE DEV_ENGINEER_FR;

-- 2. Also grant for the layer sub-schemas dbt will create in dev
--    (e.g. DBT_PROJECT.DBT_SGAUTAM_bronze / _silver / _gold)
GRANT CREATE SCHEMA  ON DATABASE DBT_PROJECT            TO ROLE DEV_ENGINEER_FR;

-- 3. Grant READ on the source (already working, but add for completeness)
GRANT USAGE  ON DATABASE DBT_POC         TO ROLE DEV_ENGINEER_FR;
GRANT USAGE  ON SCHEMA   DBT_POC.RAW     TO ROLE DEV_ENGINEER_FR;
GRANT SELECT ON TABLE    DBT_POC.RAW.RAW_ORDERS TO ROLE DEV_ENGINEER_FR;
```

**Why the `generate_schema_name` macro helps:**
The macro in `macros/grant_privileges.sql` prefixes dev schemas with your
personal schema name (`DBT_SGAUTAM_bronze`, `DBT_SGAUTAM_silver`, etc.)
so dev runs never touch shared production schemas.

---

## Running Specific Layers

```bash
# Bronze only
dbt run --select bronze

# Silver only
dbt run --select silver

# Gold only
dbt run --select gold

# Single model
dbt run --select raw_order
dbt run --select fct_orders

# Model + all upstream dependencies
dbt run --select +rpt_sales_summary

# Full refresh (rebuild incremental from scratch)
dbt run --full-refresh --select bronze
```

---

## Schemas Created

| Layer   | Dev Schema                  | Prod Schema |
|---------|-----------------------------|-------------|
| Bronze  | DBT_SGAUTAM_bronze          | BRONZE      |
| Silver  | DBT_SGAUTAM_silver          | SILVER      |
| Gold    | DBT_SGAUTAM_gold            | GOLD        |

---

## Key Models

| Model                | Layer  | Type        | Description                              |
|----------------------|--------|-------------|------------------------------------------|
| `raw_order`          | Bronze | Incremental | Type-cast orders, new rows only          |
| `dim_customers`      | Silver | Table       | Customer dim with lifetime stats         |
| `fct_orders`         | Silver | Table       | Enriched orders with flags & date parts  |
| `rpt_sales_summary`  | Gold   | Table       | Monthly revenue by country/segment/PMT   |
| `rpt_customer_360`   | Gold   | Table       | Customer 360 with RFM scores & churn risk|
| `orders_snapshot`    | —      | Snapshot    | SCD Type-2 order status history          |
