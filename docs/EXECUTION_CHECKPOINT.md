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

- A project reopened in native Visual Studio and its Master completed successfully in the Designer. The genuine success capture is saved. A SQL validation/query export was refreshed after this GUI execution; the new backup actually restored to STUDENT_A_ID_dw_restore_validation_20261009042850 and passed ten full-table comparisons, CHECKDB and all four restored queries. Its downloaded SHA-256 is dd92262915ce8c0426582ce0c50a7fdb06fd838d74d24d378b55ba4207db5ec1.
- A/B original-template review DOCX/PDF drafts are built and their nine pages each were visually reviewed. The review drafts were rendered before native report images were added; FINAL mode refuses incomplete output. Editable SQL boxes use native Word cells with the original purple border; the teacher source remains immutable.
- A/B SSIS project ZIPs now include the actual native projects, ISPACs, unchanged reference CSVs, schema and run instructions; ZIP integrity passed. These are project archives, not final assignment ZIPs.
- Pending: complete Designer and SSMS images, B GUI reopen/run evidence, AI Studio GUI screenshots, image-filled report render QA, final AI export/manifests and assignment ZIPs.
- Mac unlocked and UTM capture manually released. Get-Date was visibly executed
  through the native UI. Background scheduled jobs still steal foreground focus;
  GUI evidence will follow completion of the CLI work.
- AI Studio GUI attachment fails because the UI tool resolves the launcher bundle
  separately from its running Java application. No GUI evidence is fabricated.

This remains a partial technical checkpoint, not a submission-ready assignment.
No model is validated for lending. Student IDs remain explicit placeholders.

## Native Customer evidence and delivery support update

- A complete Customer Data Flow was captured directly from UTM after the real successful Designer execution. Native paths show 21,000 rows; the package success bar remains visible. Components are grey after completion, with an unused-column warning on Derived Column; these native visuals were preserved without editing.
- Keyboard navigation and Visual Studio full-screen view allowed a complete 60% flow capture; mouse clicks still do not reliably reach Windows. Other required native flows and query/model panels remain pending.
- Both local deliveries now contain unchanged implementation code copies and the immutable loan CSV, with 24 source-to-copy SHA256 comparisons passing per student. RMP files remain unchanged; relocation instructions require editing only source_csv.

## Command takeover and native Geography evidence

- The human explicitly authorised command takeover. Native Windows UI Automation and real desktop CopyFromScreen capture were used in the existing Administrator interactive session; no access rights or software were added.
- The UTM CLI accepts the executable and arguments after a single --cmd option. Repeating --cmd did not execute the intended helper. A written/read-back probe established the working syntax. CLI exit zero is not accepted as execution proof.
- A complete native Customer Geography screenshot was visually reviewed at 80%: all six components, 1,500 rows and package-success bar are visible. Selector-only changes and RPC-error-dialog captures were rejected. Native Date and Customer metadata screenshots were also saved.
- Native script output denotes capture creation, not final visual acceptance. A Seller Geography image whose selector said Seller while the canvas still showed 1,500 Customer rows was rejected. Further selection repair and screenshots remain pending.
- Unchanged support copies now total 26 per student. Current acceptance reports remain PARTIAL, and remaining images are recorded by the live delivery inventory.
- Computer Use reported the Mac locked again; manual unlock was requested. Windows command work continued independently. No FINAL report or assignment ZIP was promoted.

## Native command control and current GUI gates

- Human confirmed Mac unlocked. Command takeover remains authorised. Native asynchronous combo keyboard messages changed the actual canvas, verified against all component names in the own Master package.
- Student A Product screenshot shows all seven components and 2,199 rows at 60%; Seller shows all four components and 100 rows at 120%. Seller Geography overview contains all thirteen components at 30%, but small row text is not claimed as readable; a larger detail is pending.
- FactSales overview was created and its component guard passed. Native 100% viewing displayed real 137,901-row paths. After transient terminal interference cleared, a clean partial measure-conversion screenshot was saved with the package-success bar visible. Full overview and source/target detail remain pending for final report acceptance.
- Native macOS AX reads the actual Java EULA window using an already trusted Swift process. Use RapidMiner License restarted the existing GUI; no new security permissions or software were added. Acceptance of the EULA awaits explicit action-time human confirmation.
- Support copies were refreshed and all 26 per-student source hashes verified. Current inventory remains PARTIAL: A has twelve required report images missing, B eighteen. These counts do not represent completion of visual acceptance.
