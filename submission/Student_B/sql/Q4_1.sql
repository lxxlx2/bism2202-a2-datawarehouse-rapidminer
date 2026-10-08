-- PREPARED, NOT EXECUTED. Requires completed and verified SSIS warehouse.
USE [STUDENT_B_ID_dw];
GO
SET NOCOUNT ON;
-- Completed-sales proxy. Exact age at source snapshot; customer-address state.
WITH grouped AS (
 SELECT g.StateCode,c.Age,SUM(f.LineAmount) AS Revenue
 FROM dbo.FactSales f
 JOIN dbo.DimCustomer c ON c.CustomerKey=f.CustomerKey
 JOIN dbo.DimGeography g ON g.GeographyKey=f.CustomerGeographyKey
 WHERE f.OrderStatus=N'delivered' AND g.GeographyRole=N'Customer'
 GROUP BY g.StateCode,c.Age
), ranked AS (
 SELECT *,ROW_NUMBER() OVER(PARTITION BY StateCode ORDER BY Revenue DESC, Age ASC) AS Position
 FROM grouped
)
SELECT StateCode,Age,Revenue,Position FROM ranked WHERE Position=1
ORDER BY StateCode,Age;
