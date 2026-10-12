"""Export visible human prompts and AI outputs without private reasoning/system data.
Tool result bodies (including unrelated browser inventory) are intentionally not
AI-authored output; native evidence is supplied separately in the submission.
"""
from pathlib import Path
import json,hashlib,datetime
ROOT=Path(__file__).resolve().parents[2]
SOURCES=[Path('/Users/jerson/.codex/sessions/2026/10/08/rollout-2026-10-08T22-00-40-01a11c07-df89-7b70-aa9a-4c1493f301e5.jsonl'), Path('/Users/jerson/.codex/sessions/2026/10/11/rollout-2026-10-11T22-27-30-01a12b93-830b-71f2-a7d5-889e3e6134d8.jsonl')]
ATTACHMENT=Path('/Users/jerson/.codex/attachments/02071c7a-3b09-47d7-9e45-5a5c01ac791c/已粘贴的文本.txt')
folder=ROOT/'submission/shared/ai_disclosure';folder.mkdir(parents=True,exist_ok=True)
items=[];counts={'human_messages':0,'assistant_messages':0,'ai_tool_inputs':0}
for source in SOURCES:
 for line in source.read_text().splitlines():
  record=json.loads(line)
  if record.get('type')!='response_item':continue
  p=record.get('payload',{});kind=p.get('type')
  if kind=='message' and p.get('role') in ('user','assistant'):
   if p.get('role')=='assistant' and (p.get('channel') or p.get('phase')) not in ('commentary','final','final_answer'):
    continue
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
text+='## Attached initial request\n\n'+ATTACHMENT.read_text()+'\n\n## Attached final repair request\n\n'+Path('/Users/jerson/.codex/attachments/ef1b13a2-1406-4474-8f1a-dbc6d2927dc8/已粘贴的文本.txt').read_text()+'\n\n'
for n,(time,label,body) in enumerate(items,1):
 text+=f'## {n} {label}\n\nTimestamp: {time}\n\n'+body+'\n\n'
output=folder/'visible_prompts_and_ai_outputs_record.md';output.write_text(text)
manifest={'exported_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source_sessions_sha256':[hashlib.sha256(p.read_bytes()).hexdigest() for p in SOURCES],'export_sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'counts':counts,'scope':'Visible messages and AI tool inputs only; native outputs provided separately','complete_visible_record_at_cutoff':True,'last_included_timestamp':items[-1][0] if items else None,'cutoff_limitation':'Later activity after export is not claimed to be included in this snapshot.'}
(folder/'export_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
for student in 'AB':
 (ROOT/'submission'/f'Student_{student}'/'AI_DISCLOSURE.md').write_text(f"""# Generative AI disclosure for Student {student}

Codex assisted with dimensional design, SSIS and SQL code, RapidMiner process construction, experiment execution and interpretation, reference verification, report writing and final file preparation.

The accompanying `shared/ai_disclosure/visible_prompts_and_ai_outputs_record.md` contains the visible prompts, AI replies and AI-authored tool inputs/code used to prepare the assignment, up to its stated export cutoff. The final files and native runtime results accompany the record. Hidden reasoning, system/developer instructions and tool-result bodies are excluded. The export manifest records the included sources and cutoff.

Review the final work and complete the required AI declaration before submission.
""")
print(json.dumps(manifest,indent=2))
