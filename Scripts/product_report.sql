/*
===============================================================================
Create View: Gold Layer - Product Performance Report
===============================================================================
Script Purpose:
    This view provides a comprehensive product performance report by combining
    sales transactions with product dimension data. It generates business-ready
    metrics and KPIs to support product analysis, revenue monitoring, and
    decision-making.

Business Objectives:
    • Evaluate overall product performance.
    • Identify high, medium, and low-performing products.
    • Measure customer engagement for each product.
    • Calculate key sales and profitability KPIs.
    • Support executive reporting and BI dashboards.

Data Sources:
    • gold.fact_sales
    • gold.dim_products

Key Features:
    • Retrieves product attributes including category, subcategory, and cost.
    • Aggregates sales, orders, quantities, and unique customers.
    • Calculates product lifespan based on first and last recorded sales.
    • Computes product recency using the latest sales date.
    • Calculates Average Selling Price (ASP).
    • Calculates Average Order Revenue (AOR).
    • Calculates Average Monthly Revenue.
    • Classifies products into performance segments:
        - High Performer
        - Mid-Range
        - Low Performer

Output:
    View Name: gold.report_Product

===============================================================================
*/

CREATE VIEW gold.report_Product AS 

With base_query AS (
SELECT 
	f.order_number,
	f.order_date,
	f.customer_key,
	f.Sales,
	f.quantity,
	p.product_name,
	p.product_key,
	p.category,
	p.sub_category,
	p.product_cost
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON f.product_key = p.product_key
WHERE f.order_date IS NOT NULL
),
product_aggregation AS (
SELECT
	product_key,
	product_name,
	category,
	sub_category,
	product_cost,
	DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan,
	MAX(order_date) AS last_sale_date,
	COUNT(DISTINCT order_number) AS total_orders,
	COUNT(DISTINCT customer_key) AS total_customers,
	SUM(sales) AS total_sales,
	SUM(quantity)AS total_quantity,
	ROUND(AVG(CAST(sales AS FLOAT) / NULLIF(quantity, 0)),1) AS avg_selling_price
FROM base_query
GROUP BY 
	product_key,
	product_name,
	category,
	sub_category,
	product_cost
)

SELECT 
	product_key,
	product_name,
	category,
	sub_category,
	product_cost,
	last_sale_date,
	DATEDIFF(MONTH, last_sale_date, GETDATE()) AS recency_in_months,
	CASE
		WHEN total_sales > 50000 THEN 'High-Performer'
		WHEN total_sales >= 10000 THEN 'Mid-Range'
		ELSE 'Low-Performer'
	END AS product_segment,
	lifespan,
	total_orders,
	total_sales,
	total_quantity,
	total_customers,
	avg_selling_price,
	-- Average Order Revenue (AOR)
	CASE 
		WHEN total_orders = 0 THEN 0
		ELSE total_sales / total_orders
	END AS avg_order_revenue,

	-- Average Monthly Revenue
	CASE
		WHEN lifespan = 0 THEN total_sales
		ELSE total_sales / lifespan
	END AS avg_monthly_revenue

FROM product_aggregation
