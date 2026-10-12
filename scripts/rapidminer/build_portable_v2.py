"""Create portable native RMP v2 without altering frozen experiment settings."""
from pathlib import Path
from lxml import etree as E
import copy,json,hashlib,subprocess,shutil
ROOT=Path(__file__).resolve().parents[2]
DATA='data/BISM2202_A2_Loan_Data_Set_RapidMiner2026S2.csv'
manifest=[]
for s,second in [('A','decision_tree'),('B','random_forest')]:
 folder=ROOT/f'submission/Student_{s}/rapidminer';history=ROOT/f'history/rapidminer/v1/Student_{s}';history.mkdir(parents=True,exist_ok=True)
 frozen={}
 for p in sorted(folder.glob('*.rmp')):
  original=subprocess.run(['git','show','c81fb86face6339bdc25460e6c1f5fc8f127a911:'+str(p.relative_to(ROOT))],check=True,capture_output=True).stdout
  (history/p.name).write_bytes(original);frozen[p.name]=original
  t=E.fromstring(original);t.find('context/macros/macro/value').text=DATA
  E.ElementTree(t).write(str(p),encoding='UTF-8',xml_declaration=True,pretty_print=True)
  manifest.append({'Student':s,'File':str(p.relative_to(ROOT)),'V1Sha256':hashlib.sha256(original).hexdigest(),'V2Sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'Change':'source_csv uses process-file-relative data path only','Settings':'Unchanged'})
 root=E.fromstring(frozen['holdout_logistic_regression.rmp']);outer=root.find('operator/process')
 for child in list(outer):outer.remove(child)
 for index,model in enumerate(['logistic_regression',second]):
  source=E.fromstring(frozen[f'holdout_{model}.rmp']).find('operator/process');prefix='LR ' if index==0 else ('DT ' if s=='A' else 'RF ')
  names={op.get('name'):prefix+op.get('name') for op in source.iter('operator')}
  for child in source:
   node=copy.deepcopy(child)
   if node.tag=='operator':node.set('y',str(int(node.get('y','45'))+index*300))
   for op in ([node] if node.tag=='operator' else [])+list(node.iterdescendants('operator')):
    op.set('name',names[op.get('name')])
   for c in ([node] if node.tag=='connect' else [])+list(node.iterdescendants('connect')):
    for key in ['from_op','to_op']:
     if c.get(key) in names:c.set(key,names[c.get(key)])
   if node.tag=='connect' and node.get('to_op') is None and node.get('to_port','').startswith('result '):node.set('to_port','result '+str(int(node.get('to_port').split()[1])+index*5))
   outer.append(node)
 root.find('context/macros/macro/value').text=DATA
 main=folder/f'STUDENT_{s}_ID_rapidminer.rmp';E.ElementTree(root).write(str(main),encoding='UTF-8',xml_declaration=True,pretty_print=True)
 manifest=[m for m in manifest if m['File']!=str(main.relative_to(ROOT))]
 manifest.append({'Student':s,'File':str(main.relative_to(ROOT)),'V1Sha256':hashlib.sha256(frozen[main.name]).hexdigest(),'V2Sha256':hashlib.sha256(main.read_bytes()).hexdigest(),'Change':'Both preserved candidates run CV plus fixed holdout display replay; ten native outputs; portable relative data path','Settings':'Original learner/preprocessing/split/CV parameters and seeds unchanged; not a new model-selection experiment'})
 # Main combined native process contains both complete pipelines; single-candidate
 # companions provide simple GUI inspection and enabling/disabling exercises.
 print(s,main.name,'portable v2, both original models and holdout outputs')
p=ROOT/'validation/current/portable_rmp_v2_source.json';p.write_text(json.dumps({'Status':'SOURCE_PREPARED_RUNTIME_PENDING','BaselineCommit':'c81fb86face6339bdc25460e6c1f5fc8f127a911','Version':'v2 portability and viewing replay, not new research validation','Files':manifest},indent=2)+'\n')
