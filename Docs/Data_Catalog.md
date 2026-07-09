# Data Catalog — Gold Layer

## Overview
The Gold Layer is the business-ready, analytics-facing layer of the warehouse. It consists of SQL views built on top of the Silver Layer, modeled as a star schema (2 dimensions + 1 fact). These views are the single source of truth for reporting, dashboards, and BI tools (e.g. Power BI).

---

## 1. `gold.dim_customers`
**Type:** Dimension View
**Grain:** One row per customer
**Source tables:** `silver.crm_cust_info` (primary/master), `silver.erp_cust_az12`, `silver.erp_loc_a101`

| Column Name | Data Type | Description | Source |
|---|---|---|---|
| `customer_key` | INT | Surrogate key generated via `ROW_NUMBER()` ordered by `cst_id`. Used as the join key from `fact_sales`. | Generated |
| `customer_id` | INT | Unique customer identifier from the CRM system. | `crm_cust_info.cst_id` |
| `customer_number` | NVARCHAR(50) | Alphanumeric customer tracking code, used to join to ERP tables. | `crm_cust_info.cst_key` |
| `first_name` | NVARCHAR(50) | Customer's first name. | `crm_cust_info.cst_firstname` |
| `last_name` | NVARCHAR(50) | Customer's last name. | `crm_cust_info.cst_lastname` |
| `country` | NVARCHAR(50) | Country of residence. | `erp_loc_a101.cntry` |
| `marital_status` | NVARCHAR(50) | Marital status (e.g. Married, Single). | `crm_cust_info.cst_marital_status` |
| `gender` | NVARCHAR(50) | Gender. CRM is treated as the master source; if CRM value is `'N/A'`, falls back to ERP value, defaulting to `'N/A'` if both are missing. | `crm_cust_info.cst_gndr` (primary), `erp_cust_az12.gen` (fallback) |
| `birthday` | DATE | Date of birth. | `erp_cust_az12.bdate` |
| `create_date` | DATE | Date the customer record was created in the source CRM system. | `crm_cust_info.cst_create_date` |

**Join logic:** LEFT JOIN from `crm_cust_info` to `erp_cust_az12` and `erp_loc_a101` on `cst_key = cid`.

---

## 2. `gold.dim_products`
**Type:** Dimension View
**Grain:** One row per active product (historical/discontinued products excluded)
**Source tables:** `silver.crm_prd_info` (primary), `silver.erp_px_cat_g1v2`

| Column Name | Data Type | Description | Source |
|---|---|---|---|
| `product_key` | INT | Surrogate key generated via `ROW_NUMBER()` ordered by `prd_start_dt, cat_id`. Used as the join key from `fact_sales`. | Generated |
| `product_id` | INT | Internal product identifier. | `crm_prd_info.prd_id` |
| `product_number` | NVARCHAR(50) | Category ID field, also used as a join key to `fact_sales.sls_prd_key`. | `crm_prd_info.cat_id` |
| `product_name` | NVARCHAR(50) | Descriptive product name. | `crm_prd_info.prd_nm` |
| `category_id` | NVARCHAR(50) | Product key, joined against the ERP category table. | `crm_prd_info.prd_key` |
| `category` | NVARCHAR(50) | High-level product category (e.g. Bikes, Accessories). | `erp_px_cat_g1v2.cat` |
| `sub_category` | NVARCHAR(50) | Product sub-category. | `erp_px_cat_g1v2.subcat` |
| `maintenance` | NVARCHAR(50) | Whether the product requires maintenance (Yes/No). | `erp_px_cat_g1v2.maintenance` |
| `product_cost` | INT | Standard cost of the product. | `crm_prd_info.prd_cost` |
| `product_line` | NVARCHAR(50) | Product line/family classification. | `crm_prd_info.prd_line` |
| `start_date` | DATE | Date the product became active/available for sale. | `crm_prd_info.prd_start_dt` |

**Filter:** `WHERE prd_end_dt IS NULL` — only current/active products are included; historical product versions are excluded.
**Join logic:** LEFT JOIN from `crm_prd_info` to `erp_px_cat_g1v2` on `prd_key = id`.

---

## 3. `gold.fact_sales`
**Type:** Fact View
**Grain:** One row per sales order line
**Source tables:** `silver.crm_sales_details`, `gold.dim_products`, `gold.dim_customers`

| Column Name | Data Type | Description | Source |
|---|---|---|---|
| `order_number` | NVARCHAR(50) | Sales order number. | `crm_sales_details.sls_ordr_num` |
| `product_key` | INT | Foreign key to `gold.dim_products.product_key`. | Derived (join) |
| `customer_key` | INT | Foreign key to `gold.dim_customers.customer_key`. | Derived (join) |
| `order_date` | NVARCHAR(20) | Date the order was placed. **Stored as text, not DATE** — see Known Issues below. | `crm_sales_details.sls_order_dt` |
| `ship_date` | DATE | Date the order was shipped. | `crm_sales_details.sls_ship_dt` |
| `due_date` | DATE | Date payment/delivery was due. | `crm_sales_details.sls_due_dt` |
| `Sales` | INT | Total sales value for the line item. | `crm_sales_details.sls_sales` |
| `quantity` | INT | Quantity of units sold. | `crm_sales_details.sls_quantity` |
| `price` | INT | Unit price. | `crm_sales_details.sls_price` |

**Join logic:**
- LEFT JOIN `gold.dim_products` on `sls_prd_key = product_number`
- LEFT JOIN `gold.dim_customers` on `sls_cust_id = customer_id`

---

## Known Issues (flagged for fixing before this is presented as "clean")

1. **`order_date` type mismatch.** In `Scripts/Silver/ddl_silver.sql`, `sls_order_dt` is declared `NVARCHAR(20)` while `sls_ship_dt` and `sls_due_dt` are `DATE`. This means `order_date` in `fact_sales` is a string, not a date — it will sort/filter incorrectly and won't work with date functions in Power BI/DAX until cast. Fix: either convert `sls_order_dt` to `DATE` in the Silver DDL, or cast it explicitly in the Gold view (`CAST(sd.sls_order_dt AS DATE)`).
2. **`ddl_gold.sql` has a dangling query appended to `fact_sales`.** After the `CREATE VIEW gold.fact_sales AS SELECT ...` block, there's a second `SELECT * FROM gold.fact_sales f LEFT JOIN gold.dim_customers cu ... WHERE cu.customer_key IS NULL` with no `GO` batch separator before it. As written, this will either fail to execute or get silently swallowed depending on how the script is run — it looks like a leftover orphan-check query that was meant to be a separate validation script, not part of the view definition. Move it to `tests/quailty_checks_gold.sql` (where your orphan checks belong) or add a `GO` before it.
3. **Column casing inconsistency.** `Sales` is capitalized while every other column in the fact view is lowercase (`quantity`, `price`). Inconsistent with the `snake_case` convention used everywhere else in the project — rename to `sales_amount` or `sales` for consistency.

---

*Layer: Gold | Source repo: SQL-Datawarehouse-Project | Author: Muhammad Faizan*
