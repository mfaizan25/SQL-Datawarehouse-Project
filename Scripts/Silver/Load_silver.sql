/*
===============================================================================
Silver Layer - Data Load & Transformation
===============================================================================
Description:
    Loads data into the Silver layer by extracting records from the Bronze
    layer, applying data cleansing, standardization, validation, and business
    transformation rules before inserting them into the target tables.

Process:
    - Truncate target Silver tables
    - Transform and cleanse source data
    - Load transformed data into Silver tables

Warning:
    This script uses TRUNCATE TABLE to perform a full reload of the Silver
    layer. All existing data in the target tables will be permanently removed
    before new data is loaded.

Prerequisites:
    - Bronze layer tables must exist and contain the latest source data.
    - Execute only after confirming the Bronze layer load has completed
      successfully.
===============================================================================
*/

CREATE OR ALTER PROCEDURE Silver.load_silver AS 
BEGIN
	DECLARE @start_time DATETIME, @end_time DATETIME, @start_batch_time DATETIME, @end_batch_time DATETIME 
	BEGIN TRY
		SET @start_batch_time = GETDATE()
		PRINT '========================================================='
		PRINT 'Loading The Silver Layer'
		PRINT '========================================================='

		PRINT '---------------------------------------------------------'
		PRINT 'Loading CRM Tables'
		PRINT '---------------------------------------------------------'

		SET @start_time = GETDATE()
		PRINT '=======Truncating The Table silver.crm_cust_info=======';
		TRUNCATE TABLE silver.crm_cust_info;
		PRINT '=======Loading The Table silver.crm_cust_info=======';
		INSERT INTO silver.crm_cust_info ( 
			cst_id,
			cst_key,
			cst_firstname,
			cst_lastname,
			cst_gndr,
			cst_marital_status,
			cst_create_date
		)

		SELECT 
			cst_id,
			cst_key,
			TRIM(cst_firstname) AS cst_firstname,
			TRIM(cst_lastname) AS cst_lastname,
			CASE 
				WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
				WHEN UPPER(TRIM(cst_gndr))  = 'M' THEN 'Male'
				ELSE 'N/A'
			END cst_gndr,
			CASE 
				WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
				WHEN UPPER(TRIM(cst_marital_status))  = 'M' THEN 'Married'
				ELSE 'N/A'
			END cst_marital_status,
			cst_create_date
		FROM (
			SELECT
				*,
				RANK() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS cst_id_flag
			FROM bronze.crm_cust_info
			WHERE cst_id IS NOT NULL
		)t WHERE cst_id_flag = 1;
		SET @end_time = GETDATE()
		PRINT '>> LOAD DURATION ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' Seconds';
		Print '------------------------------------------------------------'

		SET @start_time = GETDATE()
		PRINT '=======Truncating The Table silver.crm_prd_info=======';
		TRUNCATE TABLE silver.crm_prd_info;
		PRINT '=======Loading The Table silver.crm_prd_info=======';
		INSERT INTO silver.crm_prd_info (
			prd_id,
			prd_key,
			cat_id,
			prd_nm,
			prd_cost,
			prd_line,
			prd_start_dt,
			prd_end_dt
		)
		SELECT
			prd_id,
			REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
			SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,
			prd_nm,
			COALESCE(prd_cost, 0) AS Prd_cost,
			CASE UPPER(TRIM(prd_line))
				WHEN 'M' THEN 'Mountain'
				WHEN 'S' THEN 'Other Sales'
				WHEN 'R' THEN 'Road'
				WHEN 'T' THEN 'Touring'
				ELSE 'N/A'
			END prd_line,
			CAST(prd_start_dt AS DATE) AS prd_start_dt,
			CAST(LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) AS DATE) AS prd_end_dt
		FROM bronze.crm_prd_info;

		SET @end_time = GETDATE()
		PRINT '>> LOAD Duration ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' Second';

		SET @start_time = GETDATE()
		PRINT '=======Truncating The Table silver.crm_sales_details=======';
		TRUNCATE TABLE silver.crm_sales_details;
		PRINT '=======Loading The Table silver.crm_sales_details=======';
		INSERT INTO silver.crm_sales_details ( 
			sls_ordr_num,
			sls_prd_key,
			sls_cust_id,
			sls_order_dt,
			sls_ship_dt,
			sls_due_dt,
			sls_sales,
			sls_price,
			sls_quantity
		)
		SELECT 
			sls_ordr_num,
			sls_prd_key,
			sls_cust_id,
			CASE 
				WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
				ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
			END sls_order_dt,
			sls_ship_dt,
			sls_due_dt,
			CASE 
				WHEN sls_sales <= 0 OR sls_sales IS NULL OR sls_sales != sls_price * sls_quantity
				THEN sls_quantity * ABS(sls_price)
				ELSE sls_sales
			END AS sls_sales,
			CASE 
				WHEN sls_price <= 0 OR sls_price IS NULL 
				THEN sls_sales / NULLIF(sls_quantity, 0)
				ELSE sls_price
			END AS sls_price,
			sls_quantity
		FROM bronze.crm_sales_details;
		SET @end_time = GETDATE()
		PRINT '>> LOAD Duration ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' Second';

		PRINT '---------------------------------------------------------'
		PRINT 'Loading ERP Tables'
		PRINT '---------------------------------------------------------'

		SET @start_time  = GETDATE()
		PRINT '=======Truncating The Table silver.erp_cust_az12=======';
		TRUNCATE TABLE silver.erp_cust_az12;
		PRINT '=======Loading The Table silver.erp_cust_az12=======';
		INSERT INTO silver.erp_cust_az12 (
			cid,
			bdate,
			gen
		)

		SELECT 
		CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
			ELSE cid
			END AS cid,
		CASE 
			WHEN bdate > GETDATE() THEN NULL 
			ELSE bdate
		END bdate,
		CASE 
			WHEN UPPER(TRIM(gen)) IN ( 'F', 'FEMALE') THEN 'Female'
			WHEN UPPER(TRIM(gen)) IN ( 'M', 'MALE') THEN 'Male'
			ELSE 'N/A'
		END AS Gen
		FROM bronze.erp_cust_az12;
		SET @end_time = GETDATE()
		PRINT '>> LOAD Duration ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' Second';
		
		SET @start_time = GETDATE()
		PRINT '=======Truncating The Table silver.erp_loc_a101=======';
		TRUNCATE TABLE silver.erp_loc_a101;
		PRINT '=======Loading The Table silver.erp_loc_a101=======';
		INSERT INTO silver.erp_loc_a101 (
			cid, 
			cntry
		)
		SELECT
			REPLACE(cid, '-', '') cid,
			CASE 
				WHEN UPPER(TRIM(cntry)) = 'DE' THEN 'Germany'
				WHEN UPPER(TRIM(cntry)) IN ('US', 'United States', 'USA') THEN 'USA'
				WHEN UPPER(TRIM(cntry)) = '' OR cntry IS NULL THEN 'N/A'
				ELSE TRIM(cntry)
			END AS cntry
		FROM bronze.erp_loc_a101;
		SET @end_time = GETDATE()
		PRINT '>> LOAD Duration ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' Second';

		SET @start_time = GETDATE()
		PRINT '=======Truncating The Table silver.erp_px_cat_g1v2=======';
		TRUNCATE TABLE silver.erp_px_cat_g1v2;
		PRINT '=======Loading The Table silver.erp_px_cat_g1v2=======';
		INSERT INTO silver.erp_px_cat_g1v2 (
			id, 
			cat, 
			subcat, 
			maintenance
		)
		SELECT 
			id,
			cat,
			subcat,
			maintenance
		FROM bronze.erp_px_cat_g1v2;
		SET @end_time = GETDATE()
		PRINT '>> LOAD Duration ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' Second';

		SET @end_batch_time = GETDATE()
		PRINT 'LOADING TIME ' + CAST(DATEDIFF(SECOND, @start_batch_time, @end_batch_time) AS NVARCHAR) + ' Second';
	END TRY
	BEGIN CATCH
		PRINT '==========================================================='
		PRINT 'Error ouccured durig Loading Silver Layer'
		PRINT 'Error Message' + ERROR_MESSAGE()
		PRINT 'Erroe Message' + CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error Message' + CAST (ERROR_STATE() AS NVARCHAR);
		PRINT '==========================================================='
	END CATCH
		PRINT '======Data Laod Successfully======'
END;
