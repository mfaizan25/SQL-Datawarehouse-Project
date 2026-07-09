/*
===============================================================================
Gold Layer - Quality Checks
===============================================================================
Purpose:
    Validate the Gold Layer views to ensure they are complete, accurate,
    and ready for reporting and analytics.

Checks Performed:
    - Record counts
    - Duplicate key validation
    - NULL key validation
    - Referential integrity
===============================================================================
*/

-- =====================================================
-- Record Counts
-- =====================================================

SELECT 'gold.dim_customers' AS View_Name, COUNT(*) AS Total_Records
FROM gold.dim_customers

UNION ALL

SELECT 'gold.dim_products', COUNT(*)
FROM gold.dim_products

UNION ALL

SELECT 'gold.fact_sales', COUNT(*)
FROM gold.fact_sales;


-- =====================================================
-- Duplicate Customer Keys
-- =====================================================

SELECT customer_key, COUNT(*) AS duplicate_count
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;


-- =====================================================
-- Duplicate Product Keys
-- =====================================================

SELECT product_key, COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;


-- =====================================================
-- NULL Customer Keys
-- =====================================================

SELECT *
FROM gold.dim_customers
WHERE customer_key IS NULL;


-- =====================================================
-- NULL Product Keys
-- =====================================================

SELECT *
FROM gold.dim_products
WHERE product_key IS NULL;


-- =====================================================
-- NULL Foreign Keys in Fact Table
-- =====================================================

SELECT *
FROM gold.fact_sales
WHERE customer_key IS NULL
   OR product_key IS NULL;


-- =====================================================
-- Orphan Customer References
-- =====================================================

SELECT f.*
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON f.customer_key = c.customer_key
WHERE c.customer_key IS NULL;


-- =====================================================
-- Orphan Product References
-- =====================================================

SELECT f.*
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
    ON f.product_key = p.product_key
WHERE p.product_key IS NULL;


-- =====================================================
-- Negative or Invalid Sales Values
-- =====================================================

SELECT *
FROM gold.fact_sales
WHERE sales_amount < 0
   OR quantity <= 0
   OR price < 0;


-- =====================================================
-- Date Validation
-- =====================================================

SELECT *
FROM gold.fact_sales
WHERE order_date IS NULL;
