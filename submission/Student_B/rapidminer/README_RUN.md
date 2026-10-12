# Running the Student B RapidMiner process

Extract the complete delivery before opening `STUDENT_B_ID_rapidminer.rmp` in Altair AI Studio. Keep the `data` folder beside the process. The `source_csv` macro uses `data/BISM2202_A2_Loan_Data_Set_RapidMiner2026S2.csv`, resolved relative to the process file. No developer path is required.

Press Run. Both model branches perform five-fold cross-validation on training data, fit the final training model and evaluate the fixed test partition. The ten result tabs contain, for each model, cross-validation performance, test performance, the fitted model, test predictions and training records.

The `cv_only_*.rmp` files show training-only validation. The `holdout_*.rmp` files show one complete model branch and its test evaluation. Use these smaller processes to inspect operators and the Cross-Validation training/testing subprocesses. They preserve the same data, parameters and partition seed as the main process.

The CSV is unchanged (SHA256 `b333abef401d01dce2b0115b65649400238c01d9362b328c8ca1c4c19876d00a`), including its Windows-1252 encoding and malformed target. The process excludes missing and invalid labels, assigns Customer_id the identifier role and fits preprocessing within training data. Keep seeds and model parameters unchanged to reproduce the reported results. Test replays display existing experiments and do not provide a new independent validation.

Student B uses Logistic Regression and Random Forest, a 70/30 split and seed 2203. Both tested classifiers have zero default recall. The report explains why overall accuracy does not establish suitability for lending.
