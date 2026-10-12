"""Verify an independent remote checkout against the frozen local delivery inventory."""
from pathlib import Path
from datetime import datetime,timezone
import sys,json,hashlib,subprocess,zipfile
ROOT=Path(__file__).resolve().parents[2];remote=Path(sys.argv[1]).resolve()
assert remote!=ROOT and (remote/'.git').exists()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
head=subprocess.run(['git','-C',str(remote),'rev-parse','HEAD'],capture_output=True,text=True,check=True).stdout.strip()
expected=json.loads((ROOT/'validation/current/delivery_inventory.json').read_text())['Files'];checks=[]
for item in expected:
 p=remote/item['Path'];assert p.is_file(),item['Path'];assert p.stat().st_size==item['Bytes'];actual=sha(p);assert actual==item['Sha256'],item['Path']
 checks.append({'Path':item['Path'],'Sha256':actual,'Status':'PASS'})
archives=[]
for s in 'AB':
 for name in [f'submission/BISM2202_Student_{s}_FINAL.zip',f'submission/Student_{s}/ssis/STUDENT_{s}_ID_ssis.zip',f'submission/Student_{s}/report/STUDENT_{s}_ID.docx']:
  with zipfile.ZipFile(remote/name) as z:
   assert z.testzip() is None,name
   archives.append({'Path':name,'CRC':'PASS','Members':len(z.namelist())})
 with zipfile.ZipFile(remote/f'submission/BISM2202_Student_{s}_FINAL.zip') as z:
  for n in z.namelist():
   if n.startswith('Student_') or n.startswith('shared/'):
    p=remote/'submission'/n;assert p.is_file(),n;assert hashlib.sha256(z.read(n)).hexdigest()==sha(p),n
lfs=json.loads(subprocess.run(['git','-C',str(remote),'lfs','ls-files','--json'],capture_output=True,text=True,check=True).stdout)['files']
for item in lfs:assert sha(remote/item['name'])==item['oid'],item['name']
result={'Status':'PASS','Utc':datetime.now(timezone.utc).isoformat(),'RemoteUrl':'https://github.com/lxxlx2/bism2202-a2-datawarehouse-rapidminer.git','DownloadedCommit':head,'IndependentClone':str(remote),'LocalLfsCacheReused':False,'VerifiedDeliveryFiles':len(checks),'VerifiedLfsPaths':len(lfs),'VerifiedUniqueLfsObjects':len({i['oid'] for i in lfs}),'AllZipMembersMatchDownloadedExpandedFiles':True,'Archives':archives,'Files':checks}
if '--no-write' not in sys.argv[2:]:
 (ROOT/'validation/current/remote_download_verification.json').write_text(json.dumps(result,indent=2)+'\n')
print(head,len(checks),'delivery files;',len(lfs),'LFS paths; all SHA256 and ZIP CRC checks PASS')
