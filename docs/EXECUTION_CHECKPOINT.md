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

Current full-package milestone:

- The combined Master package passed all eleven native row counters for A/B.
  The first complete build exposed 64,108 LineAmount truncations of 0.0001 in
  SQL reconciliation. A scaled-integer ROUND/exact numeric division repair
  eliminated the discrepancy and passed all derived monetary/source checks.
- SQL validation then rejected untrusted foreign keys after fast loading.
  The final master adds CHECK_CONSTRAINTS on destinations and WITH CHECK CHECK
  on empty reset tables. Both corrected full masters executed successfully;
  overall SQL validation and all query exports passed.
- Complete Visual Studio projects exist. The first native build failed project
  loading; the project ProtectionLevel was incorrectly numeric rather than its
  enum name. The generator now corrects the actual
  manifest ProtectionLevel attribute and both Database name nodes. Native
  Visual Studio builds passed for A and B and generated actual ispac files.
  Previous native failure logs remain preserved.
- Both actual backups restored successfully, passed CHECKDB and full-row checks
  for ten tables, and reproduced the four warehouse query outputs. Downloaded
  backup hashes match the guest records. B was re-downloaded after a truncated
  local transfer was detected; the verified replacement is now present.
- Required named RapidMiner processes now contain two selectable native CV
  operators. Default native replay performance exactly matches frozen CV bytes
  for both students. The holdout was not repeated for this packaging check.
- DDL-derived star-schema images and independent report-section drafts exist.
  All section word limits checked. Ten references per student are source-verified.
- Visible AI prompt/output export and declarations exist as a working snapshot.
  Final export and student review remain pending. Private reasoning and unrelated
  browser/tool-response state are excluded.

Pending completion:

- Genuine Designer and SSMS screenshots; GUI project reopen;
  native AI Studio GUI screenshots; original-template reports and every-page
  rendered QA; final AI export, manifests and ZIPs.
- Mac unlocked and UTM capture manually released. Get-Date was visibly executed
  through the native UI. Background scheduled jobs still steal foreground focus;
  GUI evidence will follow completion of the CLI work.
- AI Studio GUI attachment fails because the UI tool resolves the launcher bundle
  separately from its running Java application. No GUI evidence is fabricated.

This remains a partial technical checkpoint, not a submission-ready assignment.
No model is validated for lending. Student IDs remain explicit placeholders.
