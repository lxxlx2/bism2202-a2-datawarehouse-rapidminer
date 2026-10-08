"""Compare actual warehouse reference-table exports to immutable teacher CSVs."""
import argparse,collections,csv,json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('export',type=Path);p.add_argument('output',type=Path);a=p.parse_args()
actual=json.loads(a.export.read_text(encoding='utf-8-sig'))
source=Path('requirements/extracted/SSIS')
result={}
for table,file in [('RefAge','Age_Table.csv'),('RefEducation','Customer_Education.csv'),('RefState','State_code.csv'),('RefSellerLocation','seller_location.csv')]:
 with (source/file).open(encoding='utf-8-sig',newline='') as f: expected=list(csv.DictReader(f))
 columns=list(expected[0]);norm=lambda rows:collections.Counter(tuple(str(r[c]) for c in columns) for r in rows)
 assert norm(actual[table])==norm(expected),(table,'field-level mismatch')
 result[table]={'rows':len(expected),'all_source_fields_multiset':'PASS'}
a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
