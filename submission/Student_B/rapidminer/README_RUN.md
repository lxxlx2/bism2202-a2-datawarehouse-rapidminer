# Native AI Studio reopening — Student B

Open `STUDENT_B_ID_rapidminer.rmp` in the installed Altair AI Studio.
The default branch is Logistic Regression training-only cross-validation.
Follow `SWITCH_MODELS.md` for the second model. The separately supplied CV and
holdout processes preserve the fixed native experiments.

The original teacher CSV is supplied unchanged in `data/BISM2202_A2_Loan_Data_Set_RapidMiner2026S2.csv`.
SHA256: `b333abef401d01dce2b0115b65649400238c01d9362b328c8ca1c4c19876d00a`. Keep its Windows-1252 encoding and original malformed
value; the process performs the documented exclusion rather than editing data.

The preserved `source_csv` macro currently contains the absolute source path
used for the recorded runs. After moving this delivery, set only that macro
to the absolute location of the supplied CSV in each process being opened.
Do not change any seed, partition, filter, preprocessing or model parameter.
Macro relocation is a portability step, not a new model experiment.

The named process leaves the holdout partition unconnected. Read the saved
native metrics and identity validation before any viewing replay. No held-out
model detected a default at its fixed classification threshold; undefined
native F1 values are preserved. GUI evidence acceptance remains separately
recorded in the manifest.
