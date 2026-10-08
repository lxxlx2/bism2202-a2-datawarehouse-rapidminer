# Execution checkpoint — working delivery, PARTIAL

Host session date: 2026-10-09 (Asia/Bangkok). Guest clock is recorded separately
by Windows; do not treat its date as the host session date.

Verified runtime evidence:

- A and B initial DimSeller native SSIS packages executed successfully:
  100 source rows, 100 SSIS rows, 100 destination rows, source-field EXCEPT
  reconciliation passed. EndAt retains nvarchar source text, including None.
- A and B four native Flat File Source reference packages executed successfully:
  RefAge 78, RefEducation 6, RefState 8, RefSellerLocation 100.
  All fields and duplicate multiplicities match the immutable teacher CSVs.
- A reference loading was rerun successfully; no doubled destination counts.
- Native AI Studio engine CV and one fixed holdout execution passed for each of
  A LR/DT and B LR/RF. Prediction identities confirm train/test disjointness,
  same-student paired cohorts, exact CV-stage consistency and exclusion of the
  malformed target row. All holdout default recalls are zero. Native undefined
  F1 remains undefined; separately defined count-form F1 is zero.

Pending:

- CustomerFlow development currently fails native Lookup disposition validation;
  original errors retained under local work/windows_results. Latest repair is
  being tested. No customer milestone PASS is claimed yet.
- All remaining dimension/fact runtime validation, full independent SSIS projects,
  required native Designer screenshots, warehouse SQL results/screenshots,
  real backup/restore checks, native AI Studio GUI reopen and screenshots,
  final reports/references/disclosure QA and final ZIPs.

The initial seller and reference flows are shared base components. A/B
independence is established for model experiments; complete independent SSIS
implementation remains to be demonstrated. Never describe this checkpoint as a
complete assignment or a lending model validated for production.
