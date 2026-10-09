# Execution checkpoint — working delivery, PARTIAL

Host session date: 2026-10-09 (Asia/Bangkok). Guest clock is recorded separately.

Verified runtime evidence:

- A/B native SSIS seller and all four CSV reference flows passed, with original
  fields and CSV duplicate multiplicities reconciled.
- A/B customer flows passed at 21,000 rows. A uses Lookup; B uses native Sort and
  Merge Join for the education integration. Original source fields reconciled.
- A/B product (2,199), customer geography (1,500), seller geography (99), and date
  (493) flows passed. The 100 raw seller-location CSV rows remain intact; one
  contradictory location is represented once with explicitly unresolved state.
- A/B fact flows passed at 137,901 items and 688,367 units, with raw source measure
  fields reconciled. Freight is missing in every source item and remains NULL.
- All above are real SSIS Data Flows, saved as native packages. SQL joins are
  confined to read-only validation; no SQL INSERT SELECT implements ETL.
- AI Studio native engine CV and fixed holdout outputs for A LR/DT and B LR/RF
  are complete. Identity-level validation passed; every holdout default recall
  is zero. Native undefined F1 is preserved alongside count-derived F1 zero.

In progress:

- Full Master package combines the guarded warehouse reset and 11 native data
  flows, with success precedence constraints and individual row counters.
  First construction failed because a Flat File Source name contained a period;
  the repair is executing in Windows. This combined package is not yet PASS.
- Portable Visual Studio project generator, SQL execution/export runner and
  actual backup/restore runner are prepared and await their runtime gates.
- Q4.3 now explicitly uses supplier-origin NSW. Customer-destination NSW remains
  a separately named sensitivity query; neither result has yet been executed.

Pending completion:

- Full Master runtime, project build/reopen, native Designer screenshots, warehouse
  measure/relationship validation, query outputs and native SSMS screenshots,
  actual backup and restore, AI Studio GUI reopen/screenshots, original-template
  reports and rendered QA, complete AI disclosure, final manifests and ZIPs.
- Mac unlocked, but UTM captured input remains unreliable through the UI tool;
  a manual cursor-release request is pending. Native guest CLI remains usable.

This is a partial technical checkpoint, not a submission-ready assignment or a
model validated for lending. Student IDs remain explicit placeholders until
provided by the students.
