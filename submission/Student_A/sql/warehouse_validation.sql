-- PREPARED, NOT EXECUTED. Requires completed and verified SSIS warehouse.
USE [STUDENT_A_ID_dw];
GO
SET NOCOUNT ON;
-- Counts and FK violations. Source joins here are verification only, never ETL.
SELECT 'FactSales' AS ObjectName,COUNT_BIG(*) AS Rows FROM dbo.FactSales
UNION ALL SELECT 'DimCustomer',COUNT_BIG(*) FROM dbo.DimCustomer
UNION ALL SELECT 'DimProduct',COUNT_BIG(*) FROM dbo.DimProduct
UNION ALL SELECT 'DimSeller',COUNT_BIG(*) FROM dbo.DimSeller
UNION ALL SELECT 'DimGeography',COUNT_BIG(*) FROM dbo.DimGeography
UNION ALL SELECT 'DimDate',COUNT_BIG(*) FROM dbo.DimDate;
DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS;
SELECT OrderStatus,COUNT_BIG(*) AS Items,SUM(CONVERT(bigint,ItemQuantity)) AS Units,
 SUM(LineAmount) AS SuppliedLineAmount,SUM(ExtendedAmount) AS RecalculatedAmount
FROM dbo.FactSales GROUP BY OrderStatus ORDER BY OrderStatus;
IF (SELECT COUNT_BIG(*) FROM dbo.FactSales)<>
 (SELECT COUNT_BIG(*) FROM ozmart_db.dbo.order_items_table)
 THROW 51001,'Fact/source row mismatch',1;
IF EXISTS (
 SELECT i.order_item_id,i.item_quantity,CONVERT(decimal(19,4),i.line_total)
 FROM ozmart_db.dbo.order_items_table i
 EXCEPT SELECT OrderItemID,ItemQuantity,LineAmount FROM dbo.FactSales)
 THROW 51002,'Source item measures missing or changed',1;
IF EXISTS (
 SELECT OrderItemID,ItemQuantity,LineAmount FROM dbo.FactSales
 EXCEPT SELECT i.order_item_id,i.item_quantity,CONVERT(decimal(19,4),i.line_total)
 FROM ozmart_db.dbo.order_items_table i)
 THROW 51003,'Unexpected fact item measures',1;
SELECT 'MEASURE_RECONCILIATION_PASS' AS Gate;
