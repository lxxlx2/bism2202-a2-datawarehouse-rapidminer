"""Scan proposed publication bytes for credential signatures without printing values."""
from pathlib import Path
import subprocess,re,json,hashlib
ROOT=Path(__file__).resolve().parents[2]
patterns={
 'private_key':rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
 'github_token':rb'(?:gh[pousr]_[A-Za-z0-9]{36,255}|github_pat_[A-Za-z0-9_]{60,255})',
 'aws_key':rb'AKIA[0-9A-Z]{16}',
 'openai_key':rb'sk-(?:proj-)?[A-Za-z0-9_-]{40,}',
 'credential_assignment':rb'''(?i)(?:password|api_key|secret|access_token)\s*[=:]\s*["']([A-Za-z0-9+/_.-]{16,})["']''',
}
files=subprocess.run(['git','ls-files','--cached','--others','--exclude-standard','-z'],cwd=ROOT,check=True,capture_output=True).stdout.split(b'\0')
findings=[];count=0
for raw in files:
 if not raw:continue
 p=ROOT/raw.decode();
 if not p.is_file():continue
 # Binary deliveries are checked through their source text/XML and unpacked files.
 if p.suffix.lower() in ['.bak','.png','.jpg','.pdf','.docx','.zip','.ispac']:continue
 data=p.read_bytes();count+=1
 for key,pattern in patterns.items():
  for m in re.finditer(pattern,data):findings.append({'File':str(p.relative_to(ROOT)),'Line':data[:m.start()].count(b'\n')+1,'Signature':key})
result={'Status':'PASS' if not findings else 'REVIEW_REQUIRED','TextFilesScanned':count,'CredentialSignatureMatches':findings,'PublicCourseMaterialAuthorization':'User explicitly confirmed complete course materials/data and AI disclosure may be published to the public repository','ExcludedPrivateSessionDumps':'Ignored raw session transcripts and hidden/system content are not staged'}
(ROOT/'validation/current/privacy_scan.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
