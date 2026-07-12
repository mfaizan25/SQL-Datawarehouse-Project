/*
===============================================================================
Create View: Gold Layer - Customer Performance Report
===============================================================================
Script Purpose:
    This view provides a comprehensive customer performance report by combining
    sales transactions with customer dimension data. It generates business-ready
    metrics and KPIs that help analyze purchasing behavior, customer value,
    engagement, and segmentation.

Business Objectives:
    • Analyze customer purchasing behavior.
    • Identify high-value and loyal customers.
    • Segment customers based on spending and activity.
    • Measure customer engagement and retention.
    • Support business reporting and BI dashboards.

Data Sources:
    • gold.fact_sales
    • gold.dim_customers

Key Features:
    • Retrieves customer information including customer number, full name,
      and age.
    • Categorizes customers into predefined age groups.
    • Segments customers as:
        - VIP
        - Regular
        - New
    • Aggregates customer-level sales metrics:
        - Total Orders
        - Total Sales
        - Total Quantity Purchased
        - Total Unique Products Purchased
    • Calculates customer lifespan based on transaction history.
    • Computes customer recency using the latest purchase date.
    • Calculates Average Order Value (AOV).
    • Calculates Average Monthly Spend.

Output:
    View Name: gold.report_customers

===============================================================================
*/

CREATE VIEW gold.report_customers AS

With base_query AS (    --Base Query
SELECT 
	f.order_number,
	f.product_key,
	f.order_date,
	f.sales,
	f.quantity,
	c.customer_number,
	c.customer_key,
	CONCAT(c.first_name, ' ' , c.last_name) AS customer_name,
	DATEDIFF(YEAR, c.birthday, GETDATE()) AS age
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON f.customer_key = c.customer_key
WHERE f.order_date IS NOT NULL
),
customer_aggregation AS ( -- Customer Aggregation
SELECT 
	customer_key,
	customer_number,
	customer_name,
	age,
	COUNT(DISTINCT order_number) AS total_order,
	SUM(sales) AS total_sales,
	SUM(quantity) AS total_quantity,
	COUNT(DISTINCT product_key) AS total_product,
	MAX(order_date) AS last_order_Date,
	DATEDIFF(Month, MIN(order_date), MAX(order_date)) AS lifespan
FROM base_query
GROUP BY customer_key,
	customer_number,
	customer_name,
	age
)
SELECT
	customer_key,
	customer_number,
	customer_name,
	Age,
CASE 
	WHEN age < 20 THEN 'UNDER 20'
	WHEN age BETWEEN 20 AND 29 THEN '20-29'
	WHEN age BETWEEN 30 AND 39 THEN '30-39'
	WHEN age BETWEEN 40 AND 49 THEN '40-49'
	ELSE 'Above 50'
END AS age_group,
CASE
	WHEN lifespan >= 12 AND Total_sales > 5000 THEN 'VIP'
	WHEN lifespan <= 12 AND Total_sales < 5000 THEN 'Regular'
	ELSE 'New'
END AS customer_sgment,
	DATEDIFF(MONTH, Last_order_Date, GETDATE()) AS recency,
CASE 
	WHEN total_order = 0 THEN 0
	ELSE total_sales / total_order 
END AS avg_monthly_order,
CASE 
	WHEN lifespan = 0 THEN total_sales
	ELSE total_sales / lifespan
END AS monthly_avg,
	total_order,
	total_sales,
	total_quantity,
	total_product,
	last_order_Date,
	lifespan
FROM customer_aggregation
