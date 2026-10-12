"""Package clean student deliveries; verify CRC and every archive member hash."""
from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,zipfile,shutil
ROOT=Path(__file__).resolve().parents[2]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
validation=ROOT/'validation/current';records=[];allfiles=[]
shared=sorted(p for p in (ROOT/'submission/shared/ai_disclosure').rglob('*') if p.is_file())
assert {p.name for p in shared}=={'visible_prompts_and_ai_outputs_record.md','export_manifest.json'}
for s in 'AB':
 base=ROOT/f'submission/Student_{s}'
 qa=json.loads((validation/f'report_render_{s}.json').read_text());assert qa['Status']=='PASS'
 assert qa['DocxSha256']==sha(base/f'report/STUDENT_{s}_ID.docx')
 assert qa['PdfSha256']==sha(base/f'report/STUDENT_{s}_ID.pdf')
 for src,name in [(base/f'evidence/schema/STUDENT_{s}_ID_dm.png',f'STUDENT_{s}_ID_dm.png'),(base/'evidence/gui/ssis_fact.png',f'STUDENT_{s}_ID_fact.png')]:
  dest=base/'diagrams'/name;dest.parent.mkdir(exist_ok=True);shutil.copyfile(src,dest)
 # Rebuild the native solution archive from the unchanged required project files.
 project=base/f'ssis/STUDENT_{s}_ID_SSIS';inner=base/f'ssis/STUDENT_{s}_ID_ssis.zip'
 history=ROOT/f'history/delivery_before_final/submission/Student_{s}/ssis/{inner.name}';history.parent.mkdir(parents=True,exist_ok=True)
 if not history.exists():shutil.copyfile(inner,history)
 with zipfile.ZipFile(inner,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
  for p in sorted(project.rglob('*')):
   if p.is_file():z.write(p,str(p.relative_to(base/'ssis')))
  z.write(base/'ssis/README_RUN.md','README_RUN.md')
 with zipfile.ZipFile(inner) as z:assert z.testzip() is None
 files=sorted(p for p in base.rglob('*') if p.is_file())
 for p in files:
  assert not any(k in p.name.lower() for k in ['draft','debug','capture_validation','review_validation','render_qa','build_status']),p
  assert p.suffix!='.log',p
  assert p.name!='.DS_Store',p
 target=ROOT/f'submission/BISM2202_Student_{s}_FINAL.zip'
 with zipfile.ZipFile(target,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
  for p in files:z.write(p,f'Student_{s}/'+str(p.relative_to(base)))
  for p in shared:z.write(p,'shared/ai_disclosure/'+p.name)
 with zipfile.ZipFile(target) as z:
  assert z.testzip() is None
  assert len(z.namelist())==len(set(z.namelist()))
  for p in files:assert hashlib.sha256(z.read(f'Student_{s}/'+str(p.relative_to(base)))).hexdigest()==sha(p)
  for p in shared:assert hashlib.sha256(z.read('shared/ai_disclosure/'+p.name)).hexdigest()==sha(p)
  members=len(z.namelist())
 records.append({'Student':s,'File':str(target.relative_to(ROOT)),'Bytes':target.stat().st_size,'Sha256':sha(target),'Members':members,'CRC':'PASS','EveryMemberMatchesCurrentSource':'PASS','ReportPages':qa['Pages']})
 allfiles.extend(files+[target])
 print(s,target,records[-1]['Bytes'],'bytes',members,'members PASS')
allfiles.extend(shared)
(validation/'final_package_verification.json').write_text(json.dumps({'Utc':datetime.now(timezone.utc).isoformat(),'Status':'PASS','SchoolSubmission':'NOT_PERFORMED','Packages':records},indent=2)+'\n')
(validation/'delivery_inventory.json').write_text(json.dumps({'Status':'PASS','Files':[{'Path':str(p.relative_to(ROOT)),'Bytes':p.stat().st_size,'Sha256':sha(p)} for p in allfiles]},indent=2)+'\n')
