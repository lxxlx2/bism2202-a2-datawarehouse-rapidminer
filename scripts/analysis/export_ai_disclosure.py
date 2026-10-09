"""Export visible human prompts and AI outputs without private reasoning/system data.
Tool result bodies (including unrelated browser inventory) are intentionally not
AI-authored output; native evidence is supplied separately in the submission.
"""
from pathlib import Path
import json,hashlib,datetime
ROOT=Path(__file__).resolve().parents[2]
SOURCE=Path('/Users/jerson/.codex/sessions/2026/10/08/rollout-2026-10-08T22-00-40-01a11c07-df89-7b70-aa9a-4c1493f301e5.jsonl')
ATTACHMENT=Path('/Users/jerson/.codex/attachments/02071c7a-3b09-47d7-9e45-5a5c01ac791c/已粘贴的文本.txt')
folder=ROOT/'submission/shared/ai_disclosure';folder.mkdir(parents=True,exist_ok=True)
items=[];counts={'human_messages':0,'assistant_messages':0,'ai_tool_inputs':0}
for line in SOURCE.read_text().splitlines():
 record=json.loads(line)
 if record.get('type')!='response_item':continue
 p=record.get('payload',{});kind=p.get('type')
 if kind=='message' and p.get('role') in ('user','assistant'):
  texts=[c.get('text','') for c in p.get('content',[]) if c.get('type') in ('input_text','output_text','text')]
  text='\n'.join(texts)
  if p.get('role')=='user' and text.startswith('<environment_context>'):continue
  if not text:continue
  label='Human prompt' if p['role']=='user' else 'AI visible reply'
  counts['human_messages' if p['role']=='user' else 'assistant_messages']+=1
  items.append((record.get('timestamp',''),label,text))
 elif kind in ('function_call','custom_tool_call'):
  value=p.get('arguments',p.get('input',''))
  if not isinstance(value,str):value=json.dumps(value,ensure_ascii=False)
  items.append((record.get('timestamp',''),'AI tool input '+p.get('name',''),value))
  counts['ai_tool_inputs']+=1
text='# Visible prompts and AI outputs\n\n'
text+='This record includes visible human messages, AI replies and AI-authored tool inputs/code. Hidden reasoning, system/developer instructions and tool-result bodies are excluded. Native runtime results and final generated files are supplied separately. The attached initial request follows verbatim.\n\n'
text+='## Attached initial request\n\n'+ATTACHMENT.read_text()+'\n\n'
for n,(time,label,body) in enumerate(items,1):
 text+=f'## {n} {label}\n\nTimestamp: {time}\n\n'+body+'\n\n'
output=folder/'visible_prompts_and_ai_outputs_record.md';output.write_text(text)
manifest={'exported_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source_session_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'export_sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'counts':counts,'scope':'Visible messages and AI tool inputs only; native outputs provided separately','student_review':'PENDING','complete_final_snapshot':False}
(folder/'export_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
for student in 'AB':
 (ROOT/'submission'/f'Student_{student}'/'AI_DISCLOSURE.md').write_text(f'''# Generative AI disclosure for Student {student}

Codex assisted with source auditing, dimensional design, SSIS and SQL code,
model experiment planning and execution, troubleshooting, reference verification,
report drafting and package verification. This involvement extends beyond
proofreading. Native execution evidence does not imply that the student manually
performed every operation or independently authored the AI-assisted material.

The shared visible prompt/output record is provided under
`shared/ai_disclosure/visible_prompts_and_ai_outputs_record.md`, accompanied by its
export manifest. AI-authored code and generated report sections are also preserved
in the assignment files. Native runtime outputs are supplied separately. Hidden
reasoning, system instructions and unrelated private machine/browser state are not
part of the visible AI-output record.

Student review remains pending. Each student must inspect the work, understand
its methods and limitations, check the assessment's AI/cooperation requirements,
and make an accurate declaration before school submission. The teacher discourages
AI beyond proofreading and requires declared prompts and outputs. This working
folder is not evidence of student review or permission from the course.
''')
print(json.dumps(manifest,indent=2))
