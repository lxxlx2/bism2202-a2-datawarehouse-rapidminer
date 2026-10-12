-- Executed on the verified native-SSIS warehouse; outputs are in evidence/sql.
USE [STUDENT_A_ID_dw];
GO
SET NOCOUNT ON;
-- NSW means customer-address sales destination, not supplier registration location.
-- Year is purchase year. Seller-location NSW is a separate sensitivity analysis.
WITH grouped AS (
 SELECT d.CalendarYear,s.SellerID,s.SellerName,
 SUM(CONVERT(bigint,f.ItemQuantity)) AS UnitsSold,SUM(f.LineAmount) AS Revenue
 FROM dbo.FactSales f
 JOIN dbo.DimDate d ON d.DateKey=f.PurchaseDateKey
 JOIN dbo.DimSeller s ON s.SellerKey=f.SellerKey
 JOIN dbo.DimGeography g ON g.GeographyKey=f.CustomerGeographyKey
 WHERE f.OrderStatus=N'delivered' AND g.StateCode=N'NSW' AND g.GeographyRole=N'Customer'
 GROUP BY d.CalendarYear,s.SellerID,s.SellerName
), ranked AS (
 SELECT *,DENSE_RANK() OVER(PARTITION BY CalendarYear ORDER BY UnitsSold DESC) AS Position
 FROM grouped
)
SELECT CalendarYear,SellerID,SellerName,UnitsSold,Revenue,Position
FROM ranked WHERE Position<=5 ORDER BY CalendarYear,Position,SellerID;
