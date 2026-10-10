# Student A acceptance report

**Overall status: PARTIAL — no final school submission or FINAL assignment ZIP.**

This evidence summary was generated at 2026-10-10T02:39:21.447976+00:00. That is the report snapshot
time, not an invented execution timestamp. The preserved successful backend
Master log records its start as **2026-10-08T22:18:33.4435630-07:00**. The native AI runner's result log
does not provide a precise execution timestamp; that timestamp is UNKNOWN.

## Runtime and implementation

The recorded environment is macOS on Apple Silicon with the UTM
`BISM2202-Windows` x86_64 Windows Server 2025 VM, SQL Server 2022 Developer,
SSIS Runtime 16, Visual Studio 2022 Community with SSIS Projects 2.2, and SSMS 22.
The model runs used the installed macOS Altair AI Studio 2026.1.1 native engine
12.1.001 and Java 17. These are the preserved execution baseline; this report
does not claim a new software inventory or reinstall.

- Real SSIS Master execution: PASS at all 11 recorded flow counts.
- Native Visual Studio build and ISPAC semantic comparison: PASS.
- Native Designer GUI: PASS: native project reopened and full Master execution success captured; individual image acceptance is incomplete.
- Source fields, four monetary measures, relationships and trusted constraints:
  PASS in the executed SQL validator.
- Original source data and teacher materials: preserved.

## Actual warehouse records

| Table | Recorded rows |
|---|---:|
| FactSales | 137,901 |
| DimCustomer | 21,000 |
| DimProduct | 2,199 |
| DimSeller | 100 |
| DimGeography | 1,599 |
| DimDate | 493 |

Total item quantity across all preserved statuses: **688,367**. Delivered
analysis and all-status warehouse totals are separate definitions. Revenue
uses the supplied line amount; recalculated extended amounts remain a separate
measure. Missing freight and the conflicting seller-location mapping remain
explicit source limitations. No cost data exists to establish profit.

The four reference flows recorded 78 Age, 6 Education, 8 State and 100 raw
SellerLocation records; the seller geography role has 99 distinct locations.

## Database restoration and SQL

The actual backup was restored to a separate validation database. CHECKDB,
ten bidirectional full-row table comparisons and four restored analytical
query comparisons passed. This is actual restoration, beyond VERIFYONLY.

- Backup: `database/STUDENT_A_ID_dw.bak`
- Bytes: 28447232
- SHA256: `dd92262915ce8c0426582ce0c50a7fdb06fd838d74d24d378b55ba4207db5ec1`
- Current local backup matches that recorded hash: PASS.
- Real SQL result exports: `evidence/sql/`; reproducible queries: `sql/`.
- Native SSMS result-grid screenshots: PENDING.

| Executed result export | Recorded result rows |
|---|---:|
| Q4_1 | 8 |
| Q4_2 | 40 |
| Q4_3 | 17 |
| Q4_3_customer_destination_sensitivity | 21 |

Q4.3 defines NSW by supplier origin. Customer destination is a separately
labelled sensitivity. Student A uses DENSE_RANK with included fifth-rank ties;
Student B uses deterministic ROW_NUMBER. Shared source facts agree; ranking
rules account for the supplier result-count difference.

## Native model evaluation

The pre-holdout decision was frozen in commit
`7afc833dca81d220f0801c79ac723c4aaf092b23`. Fold-fitted preprocessing, disjoint
train/holdout identities, matched candidate cohorts and unchanged CV text
passed validation. The named teaching process replay reproduced the original
CV performance; that packaging replay did not repeat the holdout.

| Fixed model | Training rows | Holdout rows | Accuracy | AUC | TN/FP/FN/TP |
|---|---:|---:|---:|---:|---|
| logistic_regression | 7999 | 1999 | 0.893447 | 0.624587 | 1786/1/212/0 |
| decision_tree | 7999 | 1999 | 0.893947 | 0.500000 | 1787/0/212/0 |

Native F1 is undefined in these holdout outputs and is preserved as such.
The separately calculated confusion-count F1 is zero. Every model has zero
holdout default recall at the fixed native classification threshold. No model
is accepted for lending decisions. Required native model GUI panels remain
PENDING; XML readability alone is not GUI acceptance.

## Delivery integrity and remaining gates

The native SSIS project ZIP passed CRC integrity. Five RMP files per student
are XML-readable. 26 unchanged code/data support copies passed
source-to-copy SHA256 comparison. Original-template report drafts have a
completed nine-page layout review, but final image-filled reports require
another full render and page review. Student IDs remain placeholders.

Missing required report screenshots at this snapshot:

- `ssis_fact.png`
- `sql_Q4_1.png`
- `sql_Q4_2.png`
- `sql_Q4_3.png`
- `model1_process.png`
- `model1_cv.png`
- `model2_process.png`
- `model2_cv.png`
- `model1_result.png`
- `model2_result.png`
- `model1_performance.png`
- `model2_performance.png`

Other incomplete items: final image-filled DOCX/PDF, final visible AI record
snapshot and student review, final manifests and FINAL assignment ZIP.
The AI declaration discloses substantial design, code, execution, analysis
and drafting assistance; student confirmation of course AI/cooperation rules
is required. No manual student execution or independent authorship is invented.

## Preserved failures and limitations

- `evidence/ssis/initial_DimSeller_failure_date_conversion.txt`

UTM mouse input does not reliably reach the Windows guest. After explicit
command-takeover authorisation, Windows native messages successfully selected
and fitted the Customer Geography flow; its complete native screenshot was
visually reviewed. Further flow captures remain subject to visual acceptance.
The Cua launcher binding still cannot attach AI Studio's running Java window.
Native macOS Accessibility control using an already trusted Swift process now
reads and controls that actual window. AI Studio is at its EULA page; accepting
the agreement awaits explicit human confirmation. Model GUI captures remain
pending. Native runtime evidence has not
been replaced by reconstructed screenshots or Python-generated model visuals.
