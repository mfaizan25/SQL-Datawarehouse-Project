/*
===============================================================================
Gold Layer -DDL Scripts - Create Gold Views
===============================================================================
Purpose:
    This script creates the Gold Layer views of the Data Warehouse.
    The Gold Layer contains clean, business-ready, and analytics-focused
    datasets built from the Silver Layer. These views serve as the single
    source of truth for reporting, dashboards, KPI tracking, and business
    intelligence.

Objects Created:
    - Dimension Views (Customers, Products)
    - Fact Views (Sales)

Data Quality:
    - Built exclusively from validated Silver Layer data.
    - Business rules and transformations are standardized.
    - Optimized for querying and analytical workloads.

Warning:
    - Execute this script only after the Silver Layer has been successfully
      loaded and validated.
    - Do not modify these views directly in production without assessing
      downstream reports, dashboards, and dependent objects.
    - Structural changes to Silver Layer objects may require corresponding
      updates to these views.
Usage :
    - These views can be directly queried fro analytics and reporting.

Author : Muhammad Faizan
Project: SQL Server Modern Data Warehouse
Layer  : Gold
===============================================================================
*/

-- ============================================================================
-- Creating Dimensions: gold.dim_customers 
-- ============================================================================

IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
    DROP VIEW gold.dim_customers;
GO

CREATE VIEW gold.dim_customers AS 
	SELECT 
		ROW_NUMBER() OVER( ORDER BY cst_id ) AS customer_key,
		ci.cst_id AS customer_id,
		ci.cst_key AS customer_number,
		ci.cst_firstname AS first_name,
		ci.cst_lastname AS last_name,
		la.cntry AS country,
		ci.cst_marital_status AS marital_status,
		CASE 
			WHEN ci.cst_gndr != 'N/A' THEN ci.cst_gndr --CRM is the Master for Gender Info
			ELSE COALESCE(ca.gen, 'N/A')
		END AS gender,
			ca.bdate AS birthday,
		ci.cst_create_date AS create_date
	FROM silver.crm_cust_info ci
	LEFT JOIN silver.erp_cust_az12 ca
	ON ci.cst_key = ca.cid
	LEFT JOIN silver.erp_loc_a101 la
	ON ci.cst_key = la.cid;

-- ============================================================================
-- Creating Dimensions: gold.dim_products 
-- ============================================================================

IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
    DROP VIEW gold.dim_products;
GO

CREATE VIEW gold.dim_products AS 
SELECT 
	ROW_NUMBER() OVER( ORDER BY pd.prd_start_dt, pd.cat_id) AS product_key,
	pd.prd_id AS product_id,
	pd.cat_id AS product_number,
	pd.prd_nm AS product_name,
	pd.prd_key AS category_id,
	pc.cat AS category,
	pc.subcat AS sub_category,
	pc.maintenance AS maintenance,
	pd.prd_cost AS product_cost,
	pd.prd_line AS product_line,
	pd.prd_start_dt AS start_date
	FROM silver.crm_prd_info pd
LEFT JOIN silver.erp_px_cat_g1v2 pc
ON pd.prd_key = pc.id
WHERE prd_end_dt IS NULL;

-- ============================================================================
-- Creating Facts: gold.fact_sales
-- ============================================================================

IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL
    DROP VIEW gold.fact_sales;
GO

CREATE VIEW gold.fact_sales AS 
SELECT 
    sd.sls_ordr_num AS order_number,
    pr.product_key,
    cu.customer_key,
    sd.sls_order_dt AS order_date,
    sd.sls_ship_dt AS ship_date,
    sd.sls_due_dt AS due_date,
    sd.sls_sales AS Sales,
    sd.sls_quantity AS quantity,
    sd.sls_price AS price
FROM silver.crm_sales_details sd
LEFT JOIN gold.dim_products pr
ON sd.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customers cu
ON sd.sls_cust_id = cu.customer_id
SELECT * FROM gold.fact_sales f
LEFT JOIN gold.dim_customers cu
ON f.customer_key = cu.customer_key
WHERE cu.customer_key IS NULL; 

-- ============================================================================
-- Gold Layer Done : Data Is Ready For Analytics & Reporting
-- ============================================================================
