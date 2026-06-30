```sql
/*
===============================================================================
 Project      : SQL Server Modern Data Warehouse
 Script       : 01_create_database.sql
 Author       : Muhammad Faizan
 Created Date : YYYY-MM-DD

 Purpose
 ------------------------------------------------------------------------------
 This script creates the DataWarehouse database and initializes the three
 schemas used throughout the project.

 The architecture follows the Medallion design pattern:

    • Bronze  : Raw data imported from source systems.
    • Silver  : Cleansed, standardized, and transformed data.
    • Gold    : Business-ready dimensional model optimized for reporting
                and analytics.

 Warning
 ------------------------------------------------------------------------------
 • Running this script will DROP the existing DataWarehouse database if it
   already exists.

 • All objects, tables, views, stored procedures, and data within the
   DataWarehouse database will be permanently deleted.

 • Execute this script only if you intend to recreate the database from
   scratch.

===============================================================================
*/

USE master;
GO

/*----------------------------------------------------------------------------
    Drop existing database (if it exists)
----------------------------------------------------------------------------*/

IF DB_ID('DataWarehouse') IS NOT NULL
BEGIN
    ALTER DATABASE DataWarehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DataWarehouse;
END;
GO

/*----------------------------------------------------------------------------
    Create Database
----------------------------------------------------------------------------*/

CREATE DATABASE DataWarehouse;
GO

USE DataWarehouse;
GO

/*----------------------------------------------------------------------------
    Create Schemas
----------------------------------------------------------------------------*/

CREATE SCHEMA bronze;
GO

CREATE SCHEMA silver;
GO

CREATE SCHEMA gold;
GO

/*----------------------------------------------------------------------------
    Verification
----------------------------------------------------------------------------*/

PRINT '==============================================';
PRINT 'Database created successfully.';
PRINT 'Database : DataWarehouse';
PRINT 'Schemas  : bronze, silver, gold';
PRINT '==============================================';
GO
```
