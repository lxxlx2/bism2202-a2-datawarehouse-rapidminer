# Student B technical acceptance

Technical implementation and report evidence: PASS. School submission: NOT PERFORMED. Student ID confirmation, personal review and course AI/collaboration acceptance remain PENDING; they are human decisions, separate from execution checks.

Snapshot: 2026-10-11T10:30:22.114160+00:00. Final native Designer build validation: 2026-10-11T05:04:24.9365571Z through 2026-10-11T05:05:50.6297172Z. These are recorded execution times, not the snapshot time.

## Warehouse and native evidence

Actual SSIS Master execution passed all eleven flow counts. Independent Customer integration uses sorted Merge Join; the master integrates through native transformations. Native Visual Studio project/build and ISPAC semantic comparison passed. All seven required dimension/fact native GUI overview images plus readable native flow details are supplied and inserted in the teacher template. The original success screen is retained.

| Table | Rows |
|---|---:|
| FactSales | 137,901 |
| DimCustomer | 21,000 |
| DimProduct | 2,199 |
| DimSeller | 100 |
| DimGeography | 1,599 |
| DimDate | 493 |

The warehouse preserves 137,901 source items and 688,367 units across all statuses. Delivered-only analytical results use original LineAmount, with ExtendedAmount separately reconciled. All missing freight remains NULL. The conflicting seller location remains UNK; two sellers and 2,797 fact rows are affected. Profit is UNKNOWN because costs are absent. Original source data and teacher materials remain unchanged.

## Actual backup restore and SQL

Backup bytes: 28923904. SHA256: `9a2387133085592470b19f06fe9e1869f8f634cc0315cc06e83d02a67213a23a`. Actual isolated restore to `STUDENT_B_ID_dw_restore_validation_20261010220514` passed CHECKDB, ten bidirectional full-row comparisons and all four restored query comparisons. Local backup hash equals the native record. Original immutable SQL results were compared against fresh exports from this final build.

Native SSMS screenshots show Q4.1 eight rows, Q4.2 forty rows and Q4.3 fifteen deterministic rows; additional native result frames cover all rows. Q4.3 uses supplier origin in NSW, with customer destination documented separately. A DENSE_RANK and B ROW_NUMBER explain the supplier-count difference. No manufactured business differences were introduced.

## Native AI Studio

AI Studio 2026.1.1 / engine 12.1.001 / Java 17 performed the native experiments. The frozen pre-holdout choice is recorded in `7afc833dca81d220f0801c79ac723c4aaf092b23`. Training-only fold-fitted preprocessing, disjoint train/holdout identities and unchanged RMP files passed validation. Native GUI process, CV, fitted model and performance screenshots are visually reviewed and included. Fixed holdout display replay reproduced original outputs; it did not retune or reselect models. B's forest image shows the first constituent tree, while native text audits all fifty trees.

| Model | Train | Holdout | Accuracy | AUC | TN/FP/FN/TP |
|---|---:|---:|---:|---:|---|
| logistic_regression | 6999 | 2999 | 0.893965 | 0.594811 | 2681/0/318/0 |
| random_forest | 6999 | 2999 | 0.893965 | 0.500000 | 2681/0/318/0 |

Every model has zero holdout default recall at the fixed threshold. Native F1 is undefined and preserved; separately count-derived F1 is zero. Neither model is accepted for lending decisions.

## Reports and local delivery

The final DOCX retains the immutable teacher template's sections and unchanged package parts. All nineteen required image slots are filled. Every final rendered page was visually reviewed: 56 pages, PASS. Word counts: `{"process": 89, "recommendations": 168, "ethics": 207, "predictors": 89, "comparison": 117, "dimensions": 283, "implementation": 207, "executive_summary": 210, "query_4_1": 92, "query_4_2": 88, "query_4_3": 114}`. Ten authentic APA references, five per task, and substantial AI disclosure are included. See `report/RENDER_QA.json` and `authoring_validation.json` for hashes and checks.

The named SSIS project ZIP, actual backup, schema and fact PNG aliases, native RMP, final Word/PDF, executable code, complete SQL outputs and evidence are packaged separately for this student. The final ZIP CRC and every member hash are checked by the final packaging script; see `shared/validation/final_package_verification.json`. Full visible AI prompts/tool inputs are exported at the declared UTC cutoff and kept locally for review, not published to Git. Hidden reasoning and unrelated private tool results are excluded.

## Evidence limitations and human steps

Historical failure logs remain preserved. Invalid file-dialog or empty-editor captures were rejected, never inserted as SQL results. Earlier reviewed native overview images are deliberately preserved even where a later guest working filename was overwritten; their local and current guest hashes are distinguished. No synthetic screenshot or Python model visual replaced native evidence.

Real student IDs remain STUDENT_B_ID placeholders. Each student must review and understand the work and accurately declare extensive AI assistance. The course discourages AI beyond proofreading; technical PASS does not establish permission from the course. The convenience ZIP does not replace the separate Turnitin report, SSIS project and DW backup submission boxes. No school upload is claimed.
