# Student A delivery status

PARTIAL. This is a working delivery directory, not a completed school submission.

Confirmed student ID: pending; use STUDENT_A_ID. Warehouse implementation and execution, native SSIS project/screenshots, restored backup, Word/PDF report, references review and final ZIP are not yet verified.

Prepared warehouse analysis SQL follows docs/DW_BUSINESS_DEFINITIONS.md. It must run against [STUDENT_A_ID_dw] after all dimensions and FactSales have passed real SSIS validation. No result files or execution screenshots are provided until execution happens.

For the first seller-dimension runtime milestone, use scripts/windows/warehouse/initial_dimseller.ps1 -Student A, with schema.sql next to it. That shared base loader is not the final independent project.

Final required names: STUDENT_A_ID_ssis.zip, STUDENT_A_ID_dw.bak, STUDENT_A_ID_dm.png, STUDENT_A_ID_fact.png, STUDENT_A_ID_rapidminer.rmp, STUDENT_A_ID.docx. Review PDF is additional. School submission boxes are separate; a convenience final ZIP is not a substitute.

Native AI Studio execution verified: Logistic Regression and Decision Tree; 80/20 stratified split; 5-fold training-only CV. Real process files and native metrics/predictions are in rapidminer/ and evidence/native/. Frozen CV decisions and disjoint-cohort validation are in submission/shared/validation/. Native GUI reopening and required screenshots are still pending. All held-out models have zero default recall at their fixed default classification threshold; no model is validated for lending decisions. Native F1 unknown is preserved where emitted, with separate count-derived F1 explicitly defined as zero.
