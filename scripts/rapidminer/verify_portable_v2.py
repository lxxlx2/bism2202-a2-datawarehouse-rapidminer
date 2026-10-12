"""Check native v2 replay against frozen outputs, identities and XML settings."""
from pathlib import Path
from lxml import etree as E
import json,csv,math,hashlib,collections
ROOT=Path(__file__).resolve().parents[2]
records=[]
for s,second in [('A','decision_tree'),('B','random_forest')]:
 run=ROOT/f'work/final_repair/{s}_combined';log=ROOT/f'work/final_repair/{s}_combined.log';assert 'NATIVE_PROCESS_EXECUTION=PASS' in log.read_text()
 for index,model in enumerate(['logistic_regression',second]):
  offset=index*5;historical=ROOT/f'work/native_ai/{s}_{model}_holdout'
  for current,old in [(offset,0),(offset+1,1)]:
   with (run/f'result_{current}_metrics.csv').open() as f:a={r['criterion']:r for r in csv.DictReader(f)}
   with (historical/f'result_{old}_metrics.csv').open() as f:b={r['criterion']:r for r in csv.DictReader(f)}
   assert a.keys()==b.keys()
   for key in a:
    for metric in ['native_average','native_macro','native_micro','standard_deviation']:
     v,w=float(a[key][metric]),float(b[key][metric]);assert (math.isnan(v) and math.isnan(w)) or abs(v-w)<1e-12,(s,model,key,metric,v,w)
  test=list(csv.DictReader((run/f'result_{offset+3}_identities.csv').open()));train=list(csv.DictReader((run/f'result_{offset+4}_identities.csv').open()))
  oldtest=list(csv.DictReader((historical/'result_3_identities.csv').open()));oldtrain=list(csv.DictReader((historical/'result_4_identities.csv').open()))
  assert test==oldtest and train==oldtrain
  ti={x['id'] for x in test};tr={x['id'] for x in train};assert not ti&tr and len(ti|tr)==9998
  c=collections.Counter((x['label'],x['prediction']) for x in test)
  base=ROOT/f'submission/Student_{s}/evidence/native/v2';base.mkdir(parents=True,exist_ok=True)
  for p in run.glob(f'result_*'):
   n=int(p.name.split('_')[1].split('.')[0]);
   if offset<=n<offset+5:(base/f'{model}_{p.name}').write_bytes(p.read_bytes())
  (base/'combined_execution.log').write_bytes(log.read_bytes())
  records.append({'Student':s,'Model':model,'TrainRows':len(train),'HoldoutRows':len(test),'SplitOverlap':0,'NativeMetricsMatchFrozenOutputs':'PASS','AllIdentitiesPredictionsAndScoresMatchFrozenOutputs':'PASS','Confusion':{'TN':c['false','false'],'FP':c['false','true'],'FN':c['true','false'],'TP':c['true','true']},'ReplayNotNewHoldoutValidation':True})
 for p in (ROOT/f'submission/Student_{s}/rapidminer').glob('*.rmp'):
  t=E.parse(str(p));assert t.find('context/macros/macro/value').text.startswith('data/')
  assert '/Users/' not in p.read_text()
  if p.name.startswith('STUDENT_'):continue
  original=E.parse(str(ROOT/f'history/rapidminer/v1/Student_{s}/{p.name}'));original.find('context/macros/macro/value').text=t.find('context/macros/macro/value').text
  assert E.tostring(t)==E.tostring(original),'Unexpected setting change'
p=ROOT/'validation/current/portable_rmp_v2_runtime.json';p.write_text(json.dumps({'Status':'NATIVE_REPLAY_PASS','Version':'v2 portability and result access only','Records':records},indent=2)+'\n')
print('Four native models: CV, holdout metrics, exact identities/predictions/scores, unchanged companion settings PASS')
