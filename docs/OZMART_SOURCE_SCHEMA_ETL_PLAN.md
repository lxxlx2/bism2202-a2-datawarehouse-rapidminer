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


## 2026-10-08 actual source profile (user's Windows VM output)

Source: the user's `ozmart-source-profile.json` generated by read-only `profile_ozmart_source.ps1`. Verified **from the output file**, not independently rerun against the VM here.

| Source | Rows | Key uniqueness |
| --- | ---: | --- |
| `address_type` | 3 | not checked |
| `customer_address` | 1,500 | 1,500 distinct `address_id` |
| `customer_table` | 21,000 | 21,000 distinct `customer_id` |
| `order_items_table` | 137,901 | 137,901 distinct `order_item_id` |
| `orders_table` | 25,000 | 25,000 distinct `order_id` |
| `product_category` | 19 | 19 distinct category IDs |
| `product_subcategory` | 94 | 94 distinct subcategory IDs |
| `product_table` | 2,199 | 2,199 distinct product IDs |
| `sellers_table` | 100 | 100 distinct seller IDs |

- `order_items_table`: 0 nonpositive quantities, 0 negative `line_total`, 0 nonnumeric `freight_price` values counted by the query. **49,179** of 137,901 rows differ by more than 0.01 between `line_total` and `sales_price*item_quantity`. Do not silently overwrite the source `line_total`; the teacher data dictionary defines `sales_price` as unit price and `line_total` as line amount. Further investigation of sample deltas and status is required before revenue calculations.
- `orders_table`: shipped 4,262; delivered 4,190; processing 4,164; approved 4,160; invoiced 4,158; created 4,066. Purchase dates 2021-10-31 through 2023-03-12.
- Customer addresses cover NSW 444, QLD 329, VIC 308, SA 184, WA 137, TAS 59, NT 29, ACT 10. `region` is stored as `money` with 3 distinct values 1 to 3; the teacher dictionary calls it a region code, so treat as an encoded category, not an AUD amount.
- External files are present: `Age_Table.csv`, `Customer_Education.csv`, `seller_location.csv`, and `State_code.csv`.
- Data mapping caveat: database `Edu_1`...`Edu_6` but teacher's education CSV `EDU_01`...`EDU_06`; normalize zero padding during SSIS lookup, keep original data unchanged.
- **Source relationship audit FAILED TO RUN**, due to illegal aggregate-subquery SQL in the first profiling script. No conclusions about FK match rates or missing lookups should be drawn from this error. The script has now been repaired using LEFT JOIN plus COUNT_BIG and additionally checks external CSV key coverage. Its corrected results are **pending rerun**.

Rubric constraint remains mandatory: SSIS data-flow sources, transformations, destinations, and actual execution screenshots with green ticks, rows/columns; no SQL-only substitute for loading the dimensional model. Track status filters explicitly in the business definitions.


## 2026-10-08 second source profile: verified closure of the relational audit

The user provided `ozmart-source-profile(1).json`, generated 2026-10-08 12:45:09 UTC. Evidence is from the actual uploaded output; the model has no direct access to the Windows VM.

### Confirmed FK relationship coverage
- Item → order: 137,901 / 137,901 matched; 0 missing.
- Order → customer: 25,000 / 25,000 matched; 0 missing.
- Item → product: 137,901 / 137,901 matched; 0 missing.
- Item → seller: 137,901 / 137,901 matched; 0 missing.
- Customer → address: 21,000 / 21,000 matched; 0 missing.
- Product → subcategory: 2,199 / 2,199 matched; 0 missing.
- Subcategory → category: 94 / 94 matched; 0 missing.

### Confirmed external CSV key coverage
- Age: 78 CSV rows, 78 distinct source age keys, 0 missing age keys.
- Education: 6 CSV rows, 6 distinct source education keys, 0 missing after zero-padding normalization.
- Seller location: 100 CSV rows, 100 seller-source rows, 0 missing location keys.
- State code: 8 CSV rows, 0 customer state-code misses.
- `check_errors: []`: script audits completed with no captured errors.

### Sales detail observations and design decisions
- 137,901 items totaling 688,367 units in six order-status groups.
- Raw `line_total` sums across all statuses to 31,485,964.3760, **not** necessarily realized revenue; only 4,190 orders have `delivered` status. Define the status policy before declaring actual sales revenue.
- 49,179 line items differ > 0.01 from `sales_price*item_quantity`; examples max abs delta 0.045, especially qty 9. This is consistent with but does not prove rounding or differing precision. Preserve raw fields, use `line_total` for the supplied line amount, and disclose this caveat.
- No duplicate natural keys in the eight checked entities. `order_item_id` (137,901 distinct / 137,901) is a supported grain for `FactSales`.

**Next action:** build a first real SSIS Data Flow with OLE DB Source → Row Count transformation → OLE DB Destination into isolated sandbox tables and run with SSIS 160. Do not mark this or the assignment ETL PASS until actual package execution returns success **and** destination row counts match. Include proper SSIS transformation steps for each dimension and fact in the final project.

**Academic policy:** teacher's brief says all AI prompts and outputs must be disclosed and AI use is discouraged beyond proofreading. User must review original instructions and submissions.


## Isolated SSIS Data Flow smoke runner available (execution pending)

- Script: `scripts/windows/ssis_category_dataflow_smoke.ps1`, committed on main.
- Designed to create `BISM2202_ETL_SANDBOX.dbo.ProductCategorySmoke` using schema only, then load 19 real `ozmart_db.dbo.product_category` rows through an actual SSIS task: **OLE DB Source → Row Count transformation → OLE DB Destination**.
- It saves `C:\BISM2202\analysis\product_category_dataflow_smoke.dtsx` and `...\product_category_dataflow_result.txt`.
- It checks both the SSIS Row Count variable and physical SQL destination row count.
- The script intentionally does not modify `ozmart_db` or overwrite the Visual Studio `Package.dtsx`.
- **UNTESTED ON WINDOWS VM**: Do not report PASS until the user returns actual `DATA_FLOW_SMOKE = PASS` and `SOURCE_ROWS = SSIS_ROW_COUNT = DESTINATION_ROWS = 19`.
- This checks the runtime pipeline but does not constitute completed dimensional warehouse ETL or the required final screenshots.

### 2026-10-08 diagnostic and patch status

- User's first sandbox Data Flow run: `SOURCE_ROWS = 19`, `DATA_FLOW_SMOKE = FAIL` because SDK DLLs were searched only under SQL Server `160` directories. Script was patched to search and select .NET GAC assembly version 16.
- User's next run: all four assemblies were discovered from GAC; `OLEDB_PROVIDER = MSOLEDBSQL`. Actual failure was **C# compile-time**: `'Package' is an ambiguous reference between Microsoft.SqlServer.Dts.Runtime.Package and Microsoft.SqlServer.Dts.Runtime.Wrapper.Package`.
- Existing script is now patched on main to avoid importing `Runtime.Wrapper` and instantiate `Microsoft.SqlServer.Dts.Runtime.Package` explicitly. Emits `CSHARP_COMPILE = PASS` only if compilation completes.
- **Neither of the two observed runs executed a real SSIS Data Flow.** The new patch has not yet been run in the user's Windows VM. Do not mark the Data Flow smoke test PASS on the basis of DLL discovery or successful C# compilation alone.

### 2026-10-08 third SSIS smoke attempt: COM component initialization failure (pending rerun)

Observed user screenshot: source 19 rows; 64-bit SQL Server 2022 assemblies resolved; MSOLEDBSQL available; C# compiled successfully.
Failure: COMException HRESULT 0xC0048021 during CManagedComponentWrapperClass.ProvideComponentProperties(). Actual SSIS data-flow execution has NOT succeeded.
Microsoft defines 0xC0048021 as a missing, unregistered, or incompatible component. The earlier script used unversioned ComponentClassID values with SQL Server 2016 and 2022 installed side-by-side, which MAY select an older component; this cause remains unconfirmed until the next run.
Existing SSIS smoke script now consults Application.PipelineComponentInfos, selects installed CreationName per component, and emits SSIS_COMPONENT_CANDIDATE, SSIS_COMPONENT_SELECTED, and SSIS_STAGE progress markers.
STATUS: script patch committed; runtime rerun pending. No source-to-destination Data Flow or destination row count has been verified.


### 2026-10-08 isolated real Data Flow: PASS

The user-provided Windows VM screenshot now confirms an actual execution of the existing SSIS Data Flow smoke script. It is no longer a pending rerun:

```text
CSHARP_COMPILE = PASS
SSIS_STAGE=SOURCE INITIALIZED
SSIS_STAGE=ROWCOUNT INITIALIZED
SSIS_STAGE=DESTINATION INITIALIZED
SSIS_PACKAGE_EXECUTION = PASS
SSIS_ROW_COUNT = 19
DESTINATION_ROWS = 19
DATA_FLOW_SMOKE = PASS
SCRIPT EXIT CODE = 0
```

The installed SSIS component catalog selected `DTSAdapter.OLEDBSource.8`, `DTSTransform.RowCount.8`, `DTSAdapter.OLEDBDestination.8`, resolving the COM initialization error from the preceding runs. Source `ozmart_db.dbo.product_category` and sandbox destination `BISM2202_ETL_SANDBOX.dbo.ProductCategorySmoke` each have 19 rows, and the runtime Row Count variable reports 19. Package file: `C:\BISM2202\analysis\product_category_dataflow_smoke.dtsx`.

**Verified outcome**: basic, isolated Source → Row Count → Destination SSIS pipeline, including database row counts. **Not yet verified**: complete Kimball dimensions, fact loading, formal SSIS screenshots, full assignment query outputs, or macOS RapidMiner/Altair deliverable. Historical notes above describe earlier attempts and are retained as diagnostic history. Next work should go directly to rubric-specific SSIS warehouse ETL; do not repeat the environment installation loop.
