"""Package reviewed student artifacts and verify every archive member byte-for-byte."""
from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,zipfile,shutil
ROOT=Path(__file__).resolve().parents[2]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
validation=ROOT/'submission/shared/validation'
records=[]
for s in 'AB':
 base=ROOT/f'submission/Student_{s}'
 qa=json.loads((base/'report/RENDER_QA.json').read_text());assert qa['Status']=='PASS'
 assert qa['DocxSha256']==sha(base/f'report/STUDENT_{s}_ID.docx')
 assert qa['PdfSha256']==sha(base/f'report/STUDENT_{s}_ID.pdf')
 for ext in ['docx','pdf']:assert (base/f'report/STUDENT_{s}_ID.{ext}').is_file()
 for src,name in [(base/f'evidence/schema/STUDENT_{s}_ID_dm.png',f'STUDENT_{s}_ID_dm.png'),(base/'evidence/gui/ssis_fact.png',f'STUDENT_{s}_ID_fact.png')]:
  dest=base/'diagrams'/name;dest.parent.mkdir(exist_ok=True);shutil.copyfile(src,dest);assert sha(src)==sha(dest)
 files=sorted(p for p in base.rglob('*') if p.is_file() and not any(x in p.parts for x in ['.vs','bin','obj','__pycache__']) and p.suffix not in ['.suo','.user','.pyc'] and p.name!='FILE_HASHES.json')
 manifest={'Student':s,'Status':'TECHNICAL_PASS_HUMAN_REVIEW_PENDING','Files':[{'Path':str(p.relative_to(base)),'Bytes':p.stat().st_size,'Sha256':sha(p)} for p in files]}
 m=base/'FILE_HASHES.json';m.write_text(json.dumps(manifest,indent=2)+'\n');files.append(m)
 shared=sorted(p for p in (ROOT/'submission/shared').rglob('*') if p.is_file() and 'academic_integrity' not in p.parts and p.name not in ['final_package_verification.json','delivery_inventory.json'] and p.suffix not in ['.jsonl','.bak','.zip'] and not p.name.startswith('transcript'))
 target=ROOT/f'submission/BISM2202_Student_{s}_FINAL.zip'
 with zipfile.ZipFile(target,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
  for p in files:z.write(p,f'Student_{s}/'+str(p.relative_to(base)))
  for p in shared:z.write(p,'shared/'+str(p.relative_to(ROOT/'submission/shared')))
 with zipfile.ZipFile(target) as z:
  assert z.testzip() is None
  assert len(z.namelist())==len(set(z.namelist()))
  for p in files:assert hashlib.sha256(z.read(f'Student_{s}/'+str(p.relative_to(base)))).hexdigest()==sha(p)
  for p in shared:assert hashlib.sha256(z.read('shared/'+str(p.relative_to(ROOT/'submission/shared')))).hexdigest()==sha(p)
  members=len(z.namelist())
 records.append({'Student':s,'File':str(target.relative_to(ROOT)),'Bytes':target.stat().st_size,'Sha256':sha(target),'Members':members,'CRC':'PASS','EveryMemberMatchesCurrentSource':'PASS','ReportPages':qa['Pages']})
 print(s,target,records[-1]['Bytes'],'bytes',members,'members PASS')
(validation/'final_package_verification.json').write_text(json.dumps({'Utc':datetime.now(timezone.utc).isoformat(),'Status':'PASS','SchoolSubmission':'NOT_PERFORMED','HumanReview':'PENDING','Packages':records},indent=2)+'\n')
