# BISM2202 Assignment 2

Two independent student deliveries use the unchanged teacher data and report template.

| Student | Warehouse education integration | Loan models | Stratified train/test |
|---|---|---|---|
| A | SSIS Lookup | Logistic regression and decision tree | 80/20, seed 2202 |
| B | SSIS Sort/Merge Join | Logistic regression and random forest | 70/30, seed 2203 |

Final packages are `submission/BISM2202_Student_A_FINAL.zip` and `submission/BISM2202_Student_B_FINAL.zip`. The expanded student folders contain the same reports, diagrams, SSIS solution, warehouse backup, SQL, RapidMiner processes and native evidence. Required visible AI prompts/outputs are in `submission/shared/ai_disclosure/` and accompany each package. Fill the real student ID in the report before school submission.

Each RapidMiner main process runs both models, five-fold cross-validation confined to its training partition, and evaluation on the fixed holdout. Keep the supplied `data/` directory beside the `.rmp`; see each student's run instructions. Q4.3 returns exactly five NSW-origin suppliers per year, using SellerID to resolve equal quantities. All four tested classifiers have zero default recall; the reports explain why their accuracy does not support operational lending.

The SSIS solution requires Visual Studio with SSIS Projects and SQL Server 2022. The native flows, frozen backups and complete table comparisons have been verified. The original source backup remains in the teacher assets under `requirements/original/`. Follow `ssis/README_RUN.md` for source restoration, reference CSV paths, database configuration and execution.

Use Git LFS to obtain binary files:

```sh
git clone https://github.com/lxxlx2/bism2202-a2-datawarehouse-rapidminer.git
cd bism2202-a2-datawarehouse-rapidminer
git lfs pull
```

`validation/current/` records final technical checks and archive hashes. `history/` preserves earlier versions and failed or superseded checks outside the student deliveries. `scripts/` and `docs/report_source/` contain the reproducible authoring and verification sources. These internal materials are excluded from the final assignment ZIPs.
