# Native GUI evidence completion

Current state: real SSIS masters, native Visual Studio builds, native AI Studio experiments and actual database restore checks passed. Required GUI captures remain separate acceptance gates. A process loading or a prepared script is not an execution screenshot.

## Windows SSIS and SSMS

Open the student solution, open Master.dtsx in SSIS Designer and run the master. Keep the debugger open after successful completion so each Data Flow shows green components and actual path counts. Capture Customer, Product, Seller, Date, both Geography roles and FactSales. Capture source projections/column mappings where necessary. Each target has its own package, database and actual execution.

Save genuine, unedited captures in `submission/Student_A/evidence/gui` or `submission/Student_B/evidence/gui` using the filenames in `scripts/analysis/build_template_reports.py`. Do not substitute the teacher's sample or a programmatically drawn flow.

Execute Q4.1, Q4.2 and Q4.3 against the same frozen build in SSMS; save actual result-grid screenshots. Include all rows through additional captures if they do not fit in one view. After the final GUI ETL run, execute validation again, create a new backup, actually restore it to a new isolated database, compare full rows and queries and verify the downloaded backup SHA256.

## AI Studio

The native control tool currently cannot bind AI Studio's Java window: inventory reports the running ID `net.java.openjdk.java`, but `getApp` rejects it; the installed launcher resolves `com.rapidminer.studio` and cannot attach to the Java process. This is a UI-control limitation. Native engine results are independently preserved. Do not alter the signed app bundle or reinstall the working engine to disguise this limitation.

Student A's named process and four frozen evaluation processes are in `submission/Student_A/rapidminer`; Student B's are in the corresponding Student_B directory. The current `source_csv` macro points to the actual immutable CSV in this repository. For a moved delivery, edit only that macro to the unchanged supplied CSV path. Model switching is documented in each `SWITCH_MODELS.md`.

Required genuine native screenshots for each student:

- `model1_process.png`: active Logistic Regression overall process.
- `model1_cv.png`: its Cross Validation training/testing subprocesses, including fold-fitted preprocessing.
- `model2_process.png`: active Decision Tree (A) or Random Forest (B) overall process.
- `model2_cv.png`: that model's Cross Validation subprocesses.
- `model1_result.png`: actual Logistic Regression model result/weights.
- `model2_result.png`: actual Decision Tree single leaf (A) or Random Forest result (B).
- `model1_performance.png`: actual fixed evaluation, metrics and confusion matrix.
- `model2_performance.png`: actual fixed evaluation, metrics and confusion matrix.

Use the existing frozen settings, seeds and cohorts. Any replay for viewing must reproduce the saved native metrics and customer identities; never retune using the holdout. If several panels are necessary to show all metrics, save extra captures rather than omitting undefined values. Native F1 unknown remains undefined in native evidence; the separately calculated confusion-count F1 is zero. No classifier detected a holdout default.

No Python-generated chart, reconstructed UI or edited metric display can satisfy this capture gate. The final report builder refuses FINAL mode if designated genuine images are absent. Students must review the substantial AI disclosure and course/cooperation rules before submission.
