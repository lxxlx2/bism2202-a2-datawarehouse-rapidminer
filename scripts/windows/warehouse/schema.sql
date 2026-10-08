-- Execute only in the selected STUDENT_A_ID_dw or STUDENT_B_ID_dw assignment DB.
-- Non-destructive schema creation. This file does not load any source data.
SET XACT_ABORT ON;
IF DB_NAME() NOT IN ('STUDENT_A_ID_dw','STUDENT_B_ID_dw')
 THROW 51000, 'Wrong target database; edit and audit the allowlist after real student IDs are confirmed.', 1;
IF OBJECT_ID('dbo.DimSeller','U') IS NULL
CREATE TABLE dbo.DimSeller (
 SellerKey int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimSeller PRIMARY KEY,
 SellerID nvarchar(64) NOT NULL CONSTRAINT UQ_DimSeller_NK UNIQUE,
 SellerName nvarchar(256) NULL,
 SellerLocationID nvarchar(64) NOT NULL,
 CreatedAt datetime2 NULL,
 EndAt nvarchar(100) NULL
);
IF OBJECT_ID('dbo.DimCustomer','U') IS NULL
CREATE TABLE dbo.DimCustomer (
 CustomerKey int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimCustomer PRIMARY KEY,
 CustomerID nvarchar(64) NOT NULL CONSTRAINT UQ_DimCustomer_NK UNIQUE,
 Gender nvarchar(32) NULL, Age smallint NOT NULL,
 AgeSourceKey nvarchar(32) NOT NULL, EducationSourceCode nvarchar(32) NOT NULL,
 EducationCode nvarchar(32) NOT NULL, EducationLevel nvarchar(128) NOT NULL,
 CustomerLocationID nvarchar(64) NOT NULL,
 CONSTRAINT CK_DimCustomer_Age CHECK (Age BETWEEN 0 AND 120)
);
IF OBJECT_ID('dbo.DimProduct','U') IS NULL
CREATE TABLE dbo.DimProduct (
 ProductKey int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimProduct PRIMARY KEY,
 ProductID nvarchar(64) NOT NULL CONSTRAINT UQ_DimProduct_NK UNIQUE,
 ProductName nvarchar(1024) NULL,
 SubcategoryID nvarchar(64) NOT NULL, SubcategoryName nvarchar(256) NOT NULL,
 CategoryID nvarchar(64) NOT NULL, CategoryName nvarchar(256) NOT NULL
);
IF OBJECT_ID('dbo.DimDate','U') IS NULL
CREATE TABLE dbo.DimDate (
 DateKey int NOT NULL CONSTRAINT PK_DimDate PRIMARY KEY,
 CalendarDate date NOT NULL CONSTRAINT UQ_DimDate_Date UNIQUE,
 CalendarYear smallint NOT NULL, CalendarQuarter tinyint NOT NULL,
 CalendarMonth tinyint NOT NULL, DayOfMonth tinyint NOT NULL,
 CONSTRAINT CK_DimDate_Quarter CHECK (CalendarQuarter BETWEEN 1 AND 4),
 CONSTRAINT CK_DimDate_Month CHECK (CalendarMonth BETWEEN 1 AND 12)
);
IF OBJECT_ID('dbo.DimGeography','U') IS NULL
CREATE TABLE dbo.DimGeography (
 GeographyKey int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimGeography PRIMARY KEY,
 GeographyRole nvarchar(16) NOT NULL,
 LocationID nvarchar(64) NOT NULL,
 Postcode nvarchar(16) NULL, Suburb nvarchar(256) NULL,
 StateCode nvarchar(3) NOT NULL, StateName nvarchar(64) NOT NULL,
 RegionCode nvarchar(16) NULL, LocationType nvarchar(32) NULL,
 CONSTRAINT UQ_DimGeography_NK UNIQUE(GeographyRole,LocationID),
 CONSTRAINT CK_DimGeography_Role CHECK (GeographyRole IN ('Customer','Seller')),
 CONSTRAINT CK_DimGeography_State CHECK (StateCode IN ('ACT','NSW','NT','QLD','SA','TAS','VIC','WA'))
);
IF OBJECT_ID('dbo.FactSales','U') IS NULL
CREATE TABLE dbo.FactSales (
 SalesKey bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_FactSales PRIMARY KEY,
 OrderItemID nvarchar(64) NOT NULL CONSTRAINT UQ_FactSales_Grain UNIQUE,
 OrderID nvarchar(64) NOT NULL, ItemSequence int NULL,
 CustomerKey int NOT NULL CONSTRAINT FK_Fact_Customer REFERENCES dbo.DimCustomer(CustomerKey),
 ProductKey int NOT NULL CONSTRAINT FK_Fact_Product REFERENCES dbo.DimProduct(ProductKey),
 SellerKey int NOT NULL CONSTRAINT FK_Fact_Seller REFERENCES dbo.DimSeller(SellerKey),
 PurchaseDateKey int NOT NULL CONSTRAINT FK_Fact_Date REFERENCES dbo.DimDate(DateKey),
 CustomerGeographyKey int NOT NULL CONSTRAINT FK_Fact_CustomerGeo REFERENCES dbo.DimGeography(GeographyKey),
 SellerGeographyKey int NOT NULL CONSTRAINT FK_Fact_SellerGeo REFERENCES dbo.DimGeography(GeographyKey),
 OrderStatus nvarchar(32) NOT NULL,
 ItemQuantity int NOT NULL,
 SourceUnitSalesPrice float NOT NULL, SourceLineTotal float NOT NULL,
 UnitSalesPrice decimal(19,4) NOT NULL, LineAmount decimal(19,4) NOT NULL,
 ExtendedAmount decimal(19,4) NOT NULL, AmountDifference decimal(19,4) NOT NULL,
 FreightAmount decimal(19,4) NULL,
 CONSTRAINT CK_FactSales_Quantity CHECK (ItemQuantity>0)
);
