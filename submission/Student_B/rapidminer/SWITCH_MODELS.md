# Native model switch

Open `STUDENT_B_ID_rapidminer.rmp` in AI Studio. The named process includes
logistic regression and random forest in separate Cross Validation
operators, preserving each learner's training-only preprocessing. The default
active operator is `Training Only Cross Validation` (logistic regression).

To run the second model in the GUI:

1. Uncheck **Enable Operator** on `Training Only Cross Validation`.
2. Enable `Alternative Training Only Cross Validation`.
3. Connect `Independent Stratified Split` output `partition 1` to the
   alternative Cross Validation input `training`.
4. Connect its output `averagable 1` to `result 1` and output `model` to
   `result 2`. Remove the corresponding connections to the disabled operator.
5. Open the selected Cross Validation operator to inspect both subprocesses.

The unused `partition 2` is the reserved holdout. This named teaching process
performs training-only CV. The fixed original holdout process and its recorded
outputs are supplied separately; do not use them to retune or reselect models.
The `source_csv` macro points to the immutable teacher CSV in the local project;
when moving the project, set that macro to its new absolute location.
