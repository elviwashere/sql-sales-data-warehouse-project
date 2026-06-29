/*
===============================================================================
Identify Data Quality Issue: Bronze Layer
===============================================================================
Purpose:
    Validate data quality in the bronze schema before records are transformed and
    loaded into the silver schema. These checks identify source data issues that
    must be handled by the transformation logic in silver.load_silver.

Checks:
    - NULL or duplicate primary keys
    - Unwanted leading and trailing spaces
    - Data consistency and standardization
    - Invalid or inconsistent date values
    - Data consistency between related fields

Usage Notes:
    - Run this script before creating or executing silver.load_silver.
    - Each result note documents the actual finding observed during development
      and should be used as input for the silver transformation logic.
===============================================================================
*/

-- ====================================================================
-- Checking 'bronze.crm_cust_info'
-- ====================================================================
-- Check for NULLs or Duplicates in Primary Key
-- Expectation: No results.
SELECT
    cst_id,
    COUNT(*)
FROM bronze.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;
-- Result: NULL and duplicate cst_id values were found. Deduplication is required by keeping the latest customer record.

-- Check for Unwanted Spaces
-- Expectation: No Results
SELECT
    cst_firstname
FROM bronze.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname);
-- Result: Extra spaces were found.

SELECT
    cst_lastname
FROM bronze.crm_cust_info
WHERE cst_lastname != TRIM(cst_lastname);
-- Result: Extra spaces were found.

SELECT
    cst_material_status
FROM bronze.crm_cust_info
WHERE cst_material_status != TRIM(cst_material_status);
-- Result: No issues found.

SELECT
    cst_gndr
FROM bronze.crm_cust_info
WHERE cst_gndr != TRIM(cst_gndr);
-- Result: No issues found.

SELECT
    cst_key
FROM bronze.crm_cust_info
WHERE cst_key != TRIM(cst_key);
-- Result: No issues found.

-- Data Standardization & Consistency
SELECT DISTINCT
    cst_gndr
FROM bronze.crm_cust_info;
-- Result: NULL values and abbreviated codes (F/M) were found. Values must be mapped to clear labels such as Female, Male, and n/a.

SELECT DISTINCT
    cst_material_status
FROM bronze.crm_cust_info;
-- Result: NULL values were found. Values must be mapped to clear labels such as Single, Married, and n/a.

-- cst_create_date is already defined as DATE in the DDL, so no additional data type check is required.

-- ====================================================================
-- Checking 'bronze.crm_prd_info'
-- ====================================================================
-- Check for NULLs or Duplicates in Primary Key
-- Expectation: No Results
SELECT
    prd_id,
    COUNT(*)
FROM bronze.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;
-- Result: No duplicate values found.

-- Check for Unwanted Spaces
-- Expectation: No Results
SELECT
    prd_nm
FROM bronze.crm_prd_info
WHERE TRIM(prd_nm) != prd_nm;
-- Result: No issues found.

-- Check for NULLs or Negative Values in Cost
-- Expectation: No Results
SELECT
    prd_cost
FROM bronze.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL;
-- Result: NULL values were found. Missing costs must default to 0.

-- Data Standardization & Consistency
SELECT DISTINCT
    prd_line
FROM bronze.crm_prd_info;
-- Result: NULL values and abbreviated codes were found. Values must be mapped to descriptive labels.

-- Check for Invalid Date Orders (Start Date > End Date)
-- Expectation: No Results
SELECT
    *
FROM bronze.crm_prd_info
WHERE prd_end_dt < prd_start_dt;
-- Result: Invalid date sequences were found. prd_end_dt must be rebuilt as the next record start date minus one day.

-- ====================================================================
-- Checking 'bronze.crm_sales_details'
-- ====================================================================
-- Check for Unwanted Spaces
-- Expectation: No Results
SELECT
    sls_ord_num
FROM bronze.crm_sales_details
WHERE TRIM(sls_ord_num) != sls_ord_num;
-- Result: No issues found.

-- Check for related field
SELECT
    sls_prd_key
FROM bronze.crm_sales_details
WHERE sls_prd_key NOT IN 
    (SELECT
        prd_key
    FROM silver.crm_prd_info);
-- Result: No issues found. Product keys successfully relate to silver.crm_prd_info.

SELECT
    sls_cust_id
FROM bronze.crm_sales_details
WHERE sls_cust_id NOT IN (SELECT
    cst_id
FROM silver.crm_cust_info);
-- Result: No issues found. Customer IDs successfully connect to silver.crm_cust_info.

-- Check for Invalid Dates
-- Expectation: No Invalid Dates
-- Note: Date columns are stored as INT/STRING values in the bronze layer, so length is checked before casting.
SELECT sls_order_dt
FROM bronze.crm_sales_details
WHERE   sls_order_dt <= 0
        OR LEN(sls_order_dt) != 8
        OR sls_order_dt > 20500101 OR sls_order_dt < 19000101;
-- Result: Values of 0 and values with invalid length were found. Invalid dates must be set to NULL.

SELECT sls_ship_dt
FROM bronze.crm_sales_details
WHERE   sls_ship_dt <= 0
        OR LEN(sls_ship_dt) != 8
        OR sls_ship_dt > 20500101 OR sls_ship_dt < 19000101;
-- Result: No issues found.

SELECT sls_due_dt
FROM bronze.crm_sales_details
WHERE   sls_due_dt <= 0
        OR LEN(sls_due_dt) != 8
        OR sls_due_dt > 20500101 OR sls_due_dt < 19000101;
-- Result: No issues found.

-- Check for Invalid Date Orders (Order Date > Shipping/Due Dates)
-- Expectation: No Results
SELECT
    *
FROM bronze.crm_sales_details
WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt;
-- Result: No issues found.

-- Check Data Consistency: Sales = Quantity * Price
-- Expectation: No Results
SELECT DISTINCT
    sls_sales,
    sls_quantity,
    sls_price
FROM bronze.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
        OR sls_sales IS NULL 
        OR sls_quantity IS NULL 
        OR sls_price IS NULL
        OR sls_sales <= 0 
        OR sls_quantity <= 0 
        OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price;
-- Result: Data quality issues were found. Sales and price must be recalculated or derived when invalid.

-- ====================================================================
-- Checking 'bronze.erp_cust_az12'
-- ====================================================================
--Check for related field
SELECT
    *
FROM silver.crm_cust_info;

SELECT
    *
FROM bronze.erp_cust_az12
WHERE cid LIKE '%AW00011000';
-- Result: The NAS prefix must be removed from cid to align with CRM customer keys.

-- Identify Out-of-Range Dates
-- Expectation: Birthdates between 1924-01-01 and Today
SELECT DISTINCT
    bdate
FROM bronze.erp_cust_az12
WHERE bdate < '1924-01-01' OR bdate > GETDATE();
-- Result: Future birth dates were found. Invalid birth dates must be set to NULL.

-- Data Standardization & Consistency
SELECT DISTINCT
    gen
FROM bronze.erp_cust_az12;
-- Result: Issues were found. Values must be normalized.

-- ====================================================================
-- Checking 'bronze.erp_loc_a101'
-- ====================================================================
-- Check for related field
SELECT
    cst_key
FROM silver.crm_cust_info;

SELECT
    cid
FROM bronze.erp_loc_a101;
-- Result: Hyphen characters must be removed from cid to align with CRM customer keys.

-- Data Standardization & Consistency
SELECT DISTINCT
    cntry
FROM bronze.erp_loc_a101
ORDER BY cntry ASC;
-- Result: Issues were found. Values must be normalized.

-- ====================================================================
-- Checking 'bronze.erp_px_cat_g1v2'
-- ====================================================================
-- Check for Unwanted Spaces
-- Expectation: No Results
SELECT
    *
FROM bronze.erp_px_cat_g1v2
WHERE TRIM(cat) != cat
   OR TRIM(subcat) != subcat
   OR TRIM(maintenance) != maintenance;
-- Result: No issues found.

-- Data Standardization & Consistency
SELECT DISTINCT
    cat
FROM bronze.erp_px_cat_g1v2;
-- Result: No issues found.

SELECT DISTINCT
    subcat
FROM bronze.erp_px_cat_g1v2;
-- Result: No issues found.

SELECT DISTINCT
    maintenance
FROM bronze.erp_px_cat_g1v2;
-- Result: No issues found.
