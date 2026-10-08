# Verified fitted-model interpretation

Native fitted logistic weights show Age (−0.214 per training-standardised unit) as the strongest continuous coefficient by absolute magnitude. Education contrasts include Assoc-acdm (−0.235) and Masters (−0.181), while Income >250K is −0.129. These are conditional model associations, not causal effects; dummy contrasts and continuous weights are not interchangeable importance measures. The decision tree is a single non-default leaf and supplies no split-based predictor explanation. Despite logistic discrimination above chance, the held-out classifier misses all 212 defaults. Predictor narratives therefore cannot establish reliable creditworthiness or justify deployment.

Source: corresponding native holdout_result_2.txt model export. This interpretation is based on fitted training models; no holdout-driven refit was performed.
