-- PREPARED, NOT EXECUTED. Requires completed and verified SSIS warehouse.
USE [STUDENT_A_ID_dw];
GO
SET NOCOUNT ON;
-- Product type is parent category; best-selling is completed item quantity.
WITH grouped AS (
 SELECT g.StateCode,p.CategoryID,p.CategoryName,
 SUM(CONVERT(bigint,f.ItemQuantity)) AS UnitsSold,SUM(f.LineAmount) AS Revenue
 FROM dbo.FactSales f
 JOIN dbo.DimProduct p ON p.ProductKey=f.ProductKey
 JOIN dbo.DimGeography g ON g.GeographyKey=f.CustomerGeographyKey
 WHERE f.OrderStatus=N'delivered' AND g.GeographyRole=N'Customer'
 GROUP BY g.StateCode,p.CategoryID,p.CategoryName
), ranked AS (
 SELECT *,DENSE_RANK() OVER(PARTITION BY StateCode ORDER BY UnitsSold DESC) AS Position
 FROM grouped
)
SELECT StateCode,CategoryID,CategoryName,UnitsSold,Revenue,Position
FROM ranked WHERE Position<=5 ORDER BY StateCode,Position,CategoryID;
