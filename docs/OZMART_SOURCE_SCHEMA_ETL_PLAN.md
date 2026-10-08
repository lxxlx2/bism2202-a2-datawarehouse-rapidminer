# OzMart source schema and SSIS ETL plan

Status: **PROVISIONAL SCHEMA DESIGN**. Based on the verified 2026-10-08 exported SQL schema (10 tables / 62 columns), plus the course assignment brief. Data profiling and an actual SSIS Data Flow remain outstanding.

## Source database (verified column metadata)

Business tables: `address_type` (2), `customer_address` (9), `customer_table` (8), `order_items_table` (10), `orders_table` (8), `product_category` (2), `product_subcategory` (3), `product_table` (9), `sellers_table` (6). `sysdiagrams` (5) is SQL Server diagram metadata and is excluded from ETL.

Important exact source column names:

- `customer_table.Age_key`, `customer_table.EDU_id`, `customer_table.location_id`
- `customer_address.address_id`, `customer_address.state`, `customer_address.region`
- `order_items_table.order_item_id`, `item_quantity`, `sales_price`, `line_total`, `freight_price`
- `product_table.product_subcategorey_id`, `product_table.poduct_descriptions`
- `product_subcategory.Product_Subcategorey_ID`, `product_subcategory.Product_Category_ID`
- `product_category.Product_Categorey_ID`

The spellings above are intentional reflections of the supplied schema; rename only in target DW columns or SSIS outputs.

Source type cautions:

- `order_items_table.sales_price`, `line_total`: SQL `float`. Validate monetary semantics and cast to target `decimal(19,4)` using SSIS transformations.
- `order_items_table.freight_price`: `nvarchar`. Verify TRY_CONVERT failures / blank handling before ingesting as numeric.
- `customer_address.region`: `money`, unexpected for a geography code. Check actual values and the teacher's data dictionary; do not treat it as a state name.
- `orders_table.delivered_carrier_date` and `delivered_customer_date`: `nvarchar`, potentially malformed dates; check before date conversions.

## Proposed Kimball dimensional design (pending profile)

**Process:** OzMart item-level sales. **Grain:** one order-item record per fact (verify `order_item_id` uniqueness).

- `FactSales`: order identifier (degenerate), quantity, unit price, line amount, optional validated freight and cost, FK to customer, product, seller, purchase date, and customer/seller location roles.
- `DimCustomer`: customer ID, name, gender, age/age group, education. Match `Age_key` to external `Age_Table.csv` and `EDU_id` to `Customer_Education.csv`.
- `DimProduct`: product ID, name, subcategory and parent category. Flatten `product_table -> product_subcategory -> product_category` into one star dimension.
- `DimSeller`: seller ID, name, seller registration attributes. The external `seller_location.csv` may provide seller state.
- `DimDate`: calendar date, month, quarter, year (purchase date role).
- `DimGeography`: address/state/postcode/suburb; potentially used twice as role-playing customer and seller locations. The external `State_code.csv` can standardize state labels. Final location representation depends on observed key coverage and data-dictionary meanings.

Do not conflate supplier location in NSW with sales delivered to NSW. The assignment's supplier question must be interpreted consistently and clearly using location-role FKs.

## Analysis requirements

1. Highest revenue customer-age profile by Australian state.
2. Five best-selling product types by state (specify whether the ranking uses units/revenue).
3. Five largest suppliers by units sold in New South Wales **each year**.

All dimensions and fact records must be loaded using **SSIS Data Flow components**, with images showing green success ticks, visible transformation components and evidence of rows/columns. SQL DDL may create empty target tables; bulk joins/transforms for the assignment must not be replaced with SQL-only ingestion.

## Next check: source profiling

Run the Git-managed script `scripts/windows/profile_ozmart_source.ps1` in the installed Windows VM. This is read-only. It writes `C:\BISM2202\analysis\ozmart-source-profile.json` and reports:

- exact source row counts and uniqueness
- source join coverage for all main SQL relationships
- money/conversion anomalies, order status and date ranges
- age/education keys and customer state values
- presence of the four external teacher CSV lookup files in the filesystem or source ZIP

**No row counts, join-match rates, customer ages, or actual fact measures have been verified from live source data at the time of this note.**

## Verified environment boundary

Visual Studio 2022 shows Integration Services Project; `BISM2202_SSIS` and `Package.dtsx` exist. SQL Server 2022 `DTExec` 160 executed the blank starter package with exit code 0, as evidenced by the user's VM screenshot. A real Data Flow with OLE DB / Flat File sources, SSIS transforms, destinations, green ticks and verified row counts is **pending**.

Submission caution: the provided course brief requires disclosure of generative-AI use including prompts and outputs. Follow the university's assessment rules.
