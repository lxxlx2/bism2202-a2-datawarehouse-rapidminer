# Verified fitted-model interpretation

Native logistic weights include Age (−0.142), Capital_gain (−0.096), Income >250K (−0.174), and Loan_purpose small_business (−0.235). Continuous coefficients use training-standardised values; categorical weights refer to encoded contrasts. They describe conditional associations rather than causal or fair lending effects. All 50 random-forest trees are non-default leaves, so this fit provides no meaningful split-based variable ranking. Both held-out classifiers miss all 318 defaults. The logistic AUC advantage indicates limited score discrimination but does not establish a useful operating threshold or justify automatic lending decisions.

Source: corresponding native holdout_result_2.txt model export. This interpretation is based on fitted training models; no holdout-driven refit was performed.
