/*
===============================================================================
Silver Layer - Data Quality Validation
===============================================================================
Purpose:
    Validate source data before and during transformation into the Silver
    layer. These checks identify data quality issues that could impact
    reporting, analytics, and downstream processing.

Validation Categories:
    • Duplicate Records
    • Null & Missing Values
    • Whitespace Validation
    • Domain & Standardization Checks
    • Data Integrity Validation
    • Business Rule Validation
    • Date Validation
===============================================================================
*/


-- ============================================================================
-- Duplicate Record Checks
-- ============================================================================

-- Check for duplicate Sales Order Numbers
SELECT
    sls_ordr_num,
    COUNT(*) AS record_count
FROM bronze.crm_sales_details
GROUP BY sls_ordr_num
HAVING COUNT(*) > 1;

-- Check for duplicate Product Category IDs
SELECT
    id,
    COUNT(*) AS record_count
FROM bronze.erp_px_cat_g1v2
GROUP BY id
HAVING COUNT(*) > 1;


-- ============================================================================
-- Whitespace Validation
-- ============================================================================

-- Customer IDs with leading/trailing spaces
SELECT
    sls_cust_id
FROM bronze.crm_sales_details
WHERE sls_cust_id <> TRIM(sls_cust_id);

-- Product Keys with leading/trailing spaces
SELECT
    prd_key
FROM bronze.crm_prd_info
WHERE prd_key <> TRIM(prd_key);

-- Customer Gender values with leading/trailing spaces
SELECT DISTINCT
    cst_gndr
FROM bronze.crm_cust_info
WHERE cst_gndr <> TRIM(cst_gndr);


-- ============================================================================
-- Null & Missing Value Checks
-- ============================================================================

-- Invalid Product Cost
SELECT
    prd_cost
FROM bronze.crm_prd_info
WHERE prd_cost IS NULL
   OR prd_cost < 0;

-- Missing or Invalid Sales Information
SELECT
    sls_sales,
    sls_quantity,
    sls_price
FROM bronze.crm_sales_details
WHERE sls_sales IS NULL
   OR sls_quantity IS NULL
   OR sls_price IS NULL;


-- ============================================================================
-- Date Validation
-- ============================================================================

-- Sales Order Date must not exceed Due Date
SELECT *
FROM bronze.crm_sales_details
WHERE sls_order_dt > sls_due_dt;

-- Invalid Birth Dates
SELECT
    bdate
FROM silver.erp_cust_az12
WHERE bdate < '1926-01-01'
   OR bdate > GETDATE();


-- ============================================================================
-- Business Rule Validation
-- ============================================================================

-- Validate Sales Amount
SELECT
    sls_sales,
    sls_quantity,
    sls_price
FROM bronze.crm_sales_details
WHERE sls_sales <> (sls_quantity * sls_price)
   OR sls_sales <= 0
   OR sls_quantity <= 0
   OR sls_price <= 0
ORDER BY sls_sales;


-- ============================================================================
-- Domain Validation
-- ============================================================================

-- Product Line Values
SELECT DISTINCT
    prd_lin
FROM bronze.crm_prd_info;

-- Customer Gender Standardization
SELECT
    gen,
    CASE
        WHEN UPPER(TRIM(gen)) IN ('M','MALE') THEN 'Male'
        WHEN UPPER(TRIM(gen)) IN ('F','FEMALE') THEN 'Female'
        ELSE 'N/A'
    END AS standardized_gender
FROM bronze.erp_cust_az12;

-- Country Standardization
SELECT
    cntry,
    CASE
        WHEN UPPER(TRIM(cntry)) = 'DE' THEN 'Germany'
        WHEN UPPER(TRIM(cntry)) IN ('US','USA','UNITED STATES') THEN 'USA'
        WHEN cntry IS NULL OR TRIM(cntry) = '' THEN 'N/A'
        ELSE TRIM(cntry)
    END AS standardized_country
FROM bronze.erp_loc_a101;


-- ============================================================================
-- Key Transformation Validation
-- ============================================================================

-- Customer IDs after removing hyphens
SELECT
    cid,
    REPLACE(cid, '-', '') AS cleaned_customer_id
FROM bronze.erp_loc_a101;
