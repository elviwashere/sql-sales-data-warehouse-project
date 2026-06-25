/*
=============================================================
Create Database and Schemas
=============================================================
Purpose:
    Creates the 'DataWarehouse' database and the 'bronze', 'silver',
    and 'gold' schemas. If the database already exists, it will be
    dropped and recreated.

Warning:
    This script permanently deletes the existing database and all data.
    Ensure you have a backup before running it.
*/

USE master;
GO

-- Drop and recreate the 'DataWarehouse' database
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'DataWarehouse')
BEGIN
    ALTER DATABASE DataWarehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DataWarehouse;
END;
GO

-- Create the 'DataWarehouse' database
CREATE DATABASE DataWarehouse;
GO

USE DataWarehouse;
GO

-- Create Schemas
CREATE SCHEMA bronze;
GO

CREATE SCHEMA silver;
GO

CREATE SCHEMA gold;
GO
