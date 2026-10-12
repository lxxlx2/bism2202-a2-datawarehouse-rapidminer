-- Executed on the verified native-SSIS warehouse; outputs are in evidence/sql.
USE [STUDENT_B_ID_dw];
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
IF EXISTS (
 SELECT 1 FROM dbo.FactSales f
 WHERE f.UnitSalesPrice<>CONVERT(decimal(19,4),f.SourceUnitSalesPrice)
 OR f.ExtendedAmount<>CONVERT(decimal(19,4),f.SourceUnitSalesPrice*f.ItemQuantity)
 OR f.AmountDifference<>CONVERT(decimal(19,4),f.SourceLineTotal-f.SourceUnitSalesPrice*f.ItemQuantity)
 OR f.FreightAmount IS NOT NULL)
 THROW 51004,'Derived monetary or missing-freight reconciliation failed',1;
IF EXISTS (
 SELECT 1 FROM dbo.FactSales f
 JOIN ozmart_db.dbo.order_items_table i ON i.order_item_id=f.OrderItemID
 JOIN ozmart_db.dbo.orders_table o ON o.order_id=i.order_id
 JOIN dbo.DimCustomer c ON c.CustomerKey=f.CustomerKey
 JOIN dbo.DimProduct p ON p.ProductKey=f.ProductKey
 JOIN dbo.DimSeller s ON s.SellerKey=f.SellerKey
 JOIN dbo.DimDate d ON d.DateKey=f.PurchaseDateKey
 WHERE f.OrderID<>i.order_id OR c.CustomerID<>o.customer_id
 OR p.ProductID<>i.product_id OR s.SellerID<>i.seller_id
 OR f.OrderStatus<>o.status OR d.CalendarDate<>CAST(o.purchase_timestamp AS date)
 OR f.ItemSequence<>i.item_sequence
 OR f.SourceUnitSalesPrice<>i.sales_price OR f.SourceLineTotal<>i.line_total)
 THROW 51005,'Fact natural-key relationship or source-field reconciliation failed',1;
SELECT 'MEASURE_AND_SOURCE_RELATIONSHIP_RECONCILIATION_PASS' AS Gate;
