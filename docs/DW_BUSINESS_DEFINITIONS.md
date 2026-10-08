# Warehouse business definitions and independent designs

Status: DESIGN, not executed. Requirements baseline 501d370. Teacher ERD, dictionaries, lookup CSVs and original case inspected. Source database remains immutable.

## Kimball four steps

1. Business process: OzMart order-item sales analysis.
2. Grain: one supplied `order_items_table.order_item_id`; never aggregate before fact ingestion. Persist OrderID and ItemSequence as degenerate identifiers.
3. Dimensions: Customer (age and education flattened), Product (subcategory and category flattened), Seller (identity and seller business/private classification), Date (purchase date, day/month/quarter/year hierarchy), Geography (customer and seller location roles; suburb/postcode/state hierarchy). Fact holds both geography role keys. No dimension-to-dimension relationships in the star.
4. Facts: ItemQuantity, supplied UnitSalesPrice, supplied LineAmount, numeric FreightAmount, recalculated ExtendedAmount, signed AmountDifference. Preserve source floating values separately where needed for precision audit. OrderStatus is retained with each fact. No claim of profit because current product cost is not a historical transaction cost.

## Shared measurement contract

Load all 137,901 original items and preserve all six statuses. For the three primary queries, use delivered orders only as a disclosed completed-sales proxy; it is not proof of accounting revenue recognition. Revenue = source line_total, excluding freight, converted to decimal(19,4). Never replace line_total by sales_price*quantity. Display the rounding discrepancy as a caveat. A sensitivity query may compare other statuses without altering the primary filter.

Q4.1 uses exact customer age from Age_Table.csv, not invented age bands. State means customer address state. Q4.2 product type means parent product category; best-selling means sum of item quantity, with revenue supplementary. Q4.3 primary interpretation means sales to customer addresses in NSW, ranked by supplier identity in each purchase year. Seller-location NSW is a separate sensitivity question; do not mix the two meanings. Source customer locations and ages are current snapshots: historical customer changes cannot be reconstructed.

## Student A

Separate DB STUDENT_A_ID_dw and SSIS project. Full-cache Lookup resolves age, normalized education, category hierarchy, seller attributes, customer/seller geography and fact surrogate keys. DENSE_RANK uses the primary metric alone: rank <=5 can produce more than five rows when ties exist. Q4.1 rank=1 includes all ties.

## Student B

Separate DB STUDENT_B_ID_dw and SSIS project. Use actual Sort and Merge Join for product hierarchy and/or CSV geography where the join is naturally many-to-one; remaining key resolution may use Lookup for correctness. Both streams must be truly sorted using matching SSIS comparison semantics; marking unsorted inputs as sorted is invalid. ROW_NUMBER uses the same primary metric, then deterministic natural ID ascending; exact five where at least five groups exist. Exact-age ties use age ascending. Differences in ranking reflect tie policy only, not altered source facts.

## Keys and null/error policy

SQL IDENTITY surrogate keys for customer/product/seller/geography; integer YYYYMMDD date key derived in Data Flow. UNIQUE natural keys; Geography natural key is (GeographyRole, LocationID). Lookup CSV duplicate keys or unmatched mandatory keys fail the run and retain errors; do not silently drop rows or force known missing values into arbitrary members. Optional attributes may retain NULL with an explicit missing flag. Normalize education with case and zero padding in Derived Column only; preserve original education code. Preserve postcode as text, region as code; avoid converting postcode to numeric or region to AUD.

## Load and rerun strategy

Create empty schema with DDL, load four raw CSV references through Flat File Source Data Flows, then dimensions, then FactSales. Core joins, derived values, type conversion and movement occur in SSIS components. SQL is restricted to DDL, non-transforming source projections/reference lookups, controlled clear of the named assignment target, and read-only verification. Do not clear another DB or source. Full refresh must clear fact before dimensions and reset only assignment surrogate identities; invalid run must not yield a delivery PASS.

## Acceptance

Each package must save/open in designer, execute with SSIS 160, reconcile source/SSIS/destination counts and measures, rerun with identical natural-key facts and totals, capture native designer execution evidence, and subsequently backup and restore the completed DB. Design and prepared scripts alone do not satisfy these gates.
