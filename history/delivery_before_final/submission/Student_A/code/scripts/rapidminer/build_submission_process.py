"""Assemble the required named RMP with two native CV operators to toggle.
Frozen individual experiment files remain unchanged. Default uses LR and only
training data. The holdout partition is unconnected in this teaching process.
"""
from pathlib import Path
import copy
from lxml import etree as E
root=Path(__file__).resolve().parents[2]
for s,other in [('A','decision_tree'),('B','random_forest')]:
 folder=root/'submission'/f'Student_{s}'/'rapidminer'
 tree=E.parse(str(folder/'cv_only_logistic_regression.rmp'))
 parent=tree.find('operator/process')
 alternative=copy.deepcopy(E.parse(str(folder/f'cv_only_{other}.rmp')).find(".//operator[@class='x_validation']"))
 names={op.get('name'):'Alternative '+op.get('name') for op in alternative.iter('operator')}
 for op in alternative.iter('operator'):op.set('name',names[op.get('name')])
 for c in alternative.iter('connect'):
  for key in ('from_op','to_op'):
   if c.get(key) in names:c.set(key,names[c.get(key)])
 alternative.set('activated','false');alternative.set('x','990');alternative.set('y','260')
 parent.insert(list(parent).index(parent.find("operator[@class='x_validation']"))+1,alternative)
 path=folder/f'STUDENT_{s}_ID_rapidminer.rmp'
 tree.write(str(path),encoding='UTF-8',xml_declaration=True,pretty_print=True)
 (folder/'SWITCH_MODELS.md').write_text(f'''# Native model switch

Open `STUDENT_{s}_ID_rapidminer.rmp` in AI Studio. The named process includes
logistic regression and {other.replace('_',' ')} in separate Cross Validation
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
''')
 print(path.name)
