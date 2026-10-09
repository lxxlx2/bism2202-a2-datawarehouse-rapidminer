# Requirements traceability and acceptance matrix

Intake date: 2026-10-08 Asia/Bangkok. Authoritative baseline: the four immutable teacher originals, SHA-256 verified against requirements/README.md. Git main synchronized to 501d370. A/B mean separate real implementations, not renamed copies. PENDING is not a successful execution.

| ID | Teacher requirement and marks | Required evidence | Student A | Student B | Acceptance condition |
|---|---|---|---|---|---|
| R01 | Executive Summary, 2 | Report section 1 | 194-word results draft | 210-word results draft | <=250 words; evidence from both tasks; business audience |
| R02 | Star schema and Kimball four steps, 6 | Section 2.1 image, 2.2 rationale, DDL | DDL-derived image and 280-word draft; report pending | DDL-derived image and 283-word draft; report pending | Process, grain, keys, all dimension attributes, facts and hierarchies; <=400 words; no snowflake required |
| R03 | All dimensions integrated in SSIS, part of 6 | Section 3.1: one genuine Data Flow image per dimension; .dtsx and project | All dimension flows runtime PASS; GUI pending | All dimension flows runtime PASS; GUI pending | Toolbox transforms; no SQL substitute; successful execution and reconciled target records |
| R04 | Fact integrated in SSIS, part of 6 | Section 3.2 fact Data Flow image; .dtsx | Native runtime and source fields PASS; corrected full master PASS; GUI pending | Native runtime and source fields PASS; corrected full master PASS; GUI pending | Real source, transformations, destination; grain unique; no heavy SQL ingestion |
| R05 | ETL screenshots | Every dimension and fact screenshot | PENDING | PENDING | Green ticks, components, columns, row numbers/data; show any source query used |
| R06 | Implementation explanation | Section 3.3 | 213-word draft; full native master PASS | 207-word draft; full native master PASS | <=300 words; corresponds to actual SSIS implementation |
| R07 | Warehouse matches model | DDL, catalog, diagram, validation | DDL/source/constraint gates and native build PASS; report pending | DDL/source/constraint gates and native build PASS; report pending | Tables, keys and attributes match report; executable project |
| R08 | Q4.1 customer age profile by revenue in each state, part of 6 | SQL text and actual output screenshot in 4.1; .sql and result | Executed 8 rows; screenshot pending | Executed 8 rows; screenshot pending | Query DW; clear amount/status/geography/tie policy; every state considered |
| R09 | Q4.2 top five product types per state, part of 6 | SQL text and actual output screenshot in 4.2; .sql and result | Executed 40 rows; screenshot pending | Executed 40 rows; screenshot pending | Query DW; product type and best-selling measure explicit; partition by state |
| R10 | Q4.3 top five suppliers in NSW each year, part of 6 | SQL text and actual output screenshot in 4.3; .sql and result | Executed 17 tied-rank rows; screenshot pending | Executed 15 deterministic rows; screenshot pending | Query DW; quantity measure; explicit NSW role; partition by year |
| R11 | Backup/restore validation | student ID DW .bak; restore log and restored queries | Actual restore/full-row/query checks PASS; local hash verified | Actual restore/full-row/query checks PASS; local hash verified | Actual restore to isolated DB successful; counts and measures equal; VERIFYONLY alone insufficient |
| R12 | Explore original loan data, relevant preparation, part of 10 | Data audit; native RapidMiner process | Data audit + native prep PASS | Data audit + native prep PASS | Target 1=default, 0=fully paid; types/missingness/relevance checked; no leakage |
| R13 | Two supervised models and train/test split, part of 10 | A LR/DT 80/20, B LR/RF 70/30 preference; independent .rmp/results | Native LR/DT CV + holdout and named RMP default replay PASS; GUI pending | Native LR/RF CV + holdout and named RMP default replay PASS; GUI pending | Actual native runs; only two best models reported; models switched by connecting/enabling operators as teacher instructs |
| R14 | Overall process and CV subprocess for model 1 | Section 5 two screenshots | PENDING | PENDING | Genuine RapidMiner screenshots; CV training uses training partition only |
| R15 | Overall process and CV subprocess for model 2 | Section 5 two screenshots | PENDING | PENDING | Genuine RapidMiner screenshots; fold-fit preprocessing; untouched holdout |
| R16 | Preparation/process description | Section 5 | 87-word draft; report pending | 89-word draft; report pending | <=100 words total |
| R17 | Results of both models | Section 5 two native result screenshots | PENDING | PENDING | Real output traceable to seeds, split, process and model |
| R18 | Decisive predictor interpretation | Section 5 | Verified draft; report pending | Verified draft; report pending | <=100 words total; actual model evidence and business significance |
| R19 | Comparison and recommended bank model, 5 | Section 6 two performance screenshots and explanation | PENDING | PENDING | <=150 words total; justified by correct classification metrics and limitations |
| R20 | Recommendations and further analysis, part of 3 | Section 7.1 | PENDING | PENDING | <=200 words total; findings-based actions and validation/additional data |
| R21 | Ethical implications of selected model, part of 3 | Section 7.2 | PENDING | PENDING | <=250 words total; referenced and specific to actual selected model |
| R22 | Writing and references, 2 | Section 8; references audit | 10 source-verified references; final report pending | 10 source-verified references; final report pending | >=10 authentic APA7 sources, >=5 per task, actually cited; readable business English |
| R23 | Preserve original template | Word report | PENDING | PENDING | Original section sequence 1–8 and subsections retained; images in teacher designated locations |
| R24 | Prohibited automated visuals in Part 2 | Native visualization/screenshots and provenance | PENDING | PENDING | No Python/Matplotlib/generated UI screenshots replacing native visuals |
| R25 | Declare generative AI prompts and all outputs | Disclosure plus complete conversation/export record | PENDING | PENDING | Teacher discourages AI beyond proofreading; students review AI involvement and course/cooperation rules; no claims of student authorship of AI work |
| R26 | Naming and separate submission boxes | Named files and submission instructions | PENDING | PENDING | STUDENT_A_ID/STUDENT_B_ID placeholders until confirmed; ID_ssis.zip, ID_dw.bak and DB ID_dw, ID_dm.png, ID_fact.png, ID_rapidminer.rmp, ID.docx |
| R27 | Report to Turnitin; project ZIP to SSIS box; backup to DW box | Submission README | PENDING | PENDING | Final convenience ZIP does not replace separate required school submissions |
| R28 | UQ digital workspace persistence guidance | README if applicable | N/A local VM | N/A local VM | Teacher says use H: in UQ workspace because C: erased at logout; current VM is local |
| U01 | Two independent complete deliverables (user) | Two projects, DWs, models, run logs, reports, manifests and final ZIPs | PENDING | PENDING | Real independent designs/runs; common source facts reconcile; no manufactured differences |
| U02 | Review PDF and Word word-count/render QA (user) | Per-student DOCX/PDF; page QA; word audit | PENDING | PENDING | Every page inspected, no placeholders in final report except unconfirmed IDs |
| U03 | Runtime and reproducibility verification (user) | Acceptance reports; reopen .rmp/SSIS; restore; SQL execution | PENDING | PENDING | Actual evidence, no script-prepared substitution for PASS |
| U04 | Source integrity and anomalous amount preservation (user) | Original hashes; business definitions; reconciliation | INTAKE PASS | INTAKE PASS | Originals unchanged; raw line amount preserved; education padding normalized only in ETL; region coded |
| U05 | Git and delivery hygiene (user) | SHAs, clean scoped commit, manifests, credential scan | PENDING | PENDING | Preserve unrelated files; exclude VM/ISO/secrets/temp; no large backups in Git |

Total rubric: 2+6+6+6+10+5+3+2 = 40. Items sharing marks are subrequirements, not additional marks. No teacher-specified 80/20 versus 70/30 ratio was found; these are user design preferences. No precise CV fold count or mandatory metric list was specified in the original brief; justify choices and capture actual outputs.

## Initial evidence boundary

Source rows and 19-row SSIS sandbox PASS are recorded in existing repository notes and user evidence. They do not pass any student assignment ETL gate. No final student artifacts existed in tracked main at intake. Original sample screenshots illustrate requirements and cannot be submitted as execution evidence.

## Additional original material

Both package ZIP inventories inspected. SSIS package includes ERD, data dictionary XLSX, four lookup CSVs, backup, sample process screenshot, and backup/restore PDF. RapidMiner package includes original CSV and dictionary DOCX. Verify embedded images/layout against the originals before final reports; plain-text extraction alone is not layout verification.
