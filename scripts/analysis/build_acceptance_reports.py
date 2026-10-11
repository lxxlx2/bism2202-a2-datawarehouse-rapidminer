"""Build acceptance summaries from actual runtime and final local evidence."""
from pathlib import Path
from datetime import datetime, timezone
import json,hashlib
ROOT=Path(__file__).resolve().parents[2]
load=lambda p:json.loads((ROOT/p).read_text(encoding='utf-8-sig'))
backup=load('submission/shared/validation/backup_and_project_verification.json')
native=load('submission/shared/validation/native_holdout_validation.json')
for s in 'AB':
 base=ROOT/f'submission/Student_{s}'
 qa=json.loads((base/'report/RENDER_QA.json').read_text())
 assert qa['Status']=='PASS'
 for ext,key in [('docx','DocxSha256'),('pdf','PdfSha256')]:assert hashlib.sha256((base/f'report/STUDENT_{s}_ID.{ext}').read_bytes()).hexdigest()==qa[key]
 author=json.loads((base/'report/authoring_validation.json').read_text());assert not author['missing_genuine_images']
 counts=json.loads((base/'evidence/sql/warehouse-validation-0.json').read_text(encoding='utf-8-sig'))
 rows='\n'.join(f"| {r['ObjectName']} | {r['Rows']:,} |" for r in counts)
 models=[]
 for r in native['results']:
  if r['student']==s:
   c=r['confusion'];models.append(f"| {r['model']} | {r['train_rows']} | {r['holdout_rows']} | {r['native_accuracy']:.6f} | {r['native_auc']:.6f} | {c['TN']}/{c['FP']}/{c['FN']}/{c['TP']} |")
 models='\n'.join(models)
 gui=load(f'submission/shared/validation/final_gui_build_{s}_validation.json')
 text=f'''# Student {s} technical acceptance

Technical implementation and report evidence: PASS. School submission: NOT PERFORMED. Student ID confirmation, personal review and course AI/collaboration acceptance remain PENDING; they are human decisions, separate from execution checks.

Snapshot: {datetime.now(timezone.utc).isoformat()}. Final native Designer build validation: {gui['StartedUtc']} through {gui['FinishedUtc']}. These are recorded execution times, not the snapshot time.

## Warehouse and native evidence

Actual SSIS Master execution passed all eleven flow counts. Independent Customer integration uses {'Lookup' if s=='A' else 'sorted Merge Join'}; the master integrates through native transformations. Native Visual Studio project/build and ISPAC semantic comparison passed. All seven required dimension/fact native GUI overview images plus readable native flow details are supplied and inserted in the teacher template. The original success screen is retained.

| Table | Rows |
|---|---:|
{rows}

The warehouse preserves 137,901 source items and 688,367 units across all statuses. Delivered-only analytical results use original LineAmount, with ExtendedAmount separately reconciled. All missing freight remains NULL. The conflicting seller location remains UNK; two sellers and 2,797 fact rows are affected. Profit is UNKNOWN because costs are absent. Original source data and teacher materials remain unchanged.

## Actual backup restore and SQL

Backup bytes: {backup[s]['bytes']}. SHA256: `{backup[s]['sha256']}`. Actual isolated restore to `{backup[s]['restore_database']}` passed CHECKDB, ten bidirectional full-row comparisons and all four restored query comparisons. Local backup hash equals the native record. Original immutable SQL results were compared against fresh exports from this final build.

Native SSMS screenshots show Q4.1 eight rows, Q4.2 forty rows and Q4.3 {'seventeen tied-rank' if s=='A' else 'fifteen deterministic'} rows; additional native result frames cover all rows. Q4.3 uses supplier origin in NSW, with customer destination documented separately. A DENSE_RANK and B ROW_NUMBER explain the supplier-count difference. No manufactured business differences were introduced.

## Native AI Studio

AI Studio 2026.1.1 / engine 12.1.001 / Java 17 performed the native experiments. The frozen pre-holdout choice is recorded in `{native['pre_holdout_lock_commit']}`. Training-only fold-fitted preprocessing, disjoint train/holdout identities and unchanged RMP files passed validation. Native GUI process, CV, fitted model and performance screenshots are visually reviewed and included. Fixed holdout display replay reproduced original outputs; it did not retune or reselect models. B's forest image shows the first constituent tree, while native text audits all fifty trees.

| Model | Train | Holdout | Accuracy | AUC | TN/FP/FN/TP |
|---|---:|---:|---:|---:|---|
{models}

Every model has zero holdout default recall at the fixed threshold. Native F1 is undefined and preserved; separately count-derived F1 is zero. Neither model is accepted for lending decisions.

## Reports and local delivery

The final DOCX retains the immutable teacher template's sections and unchanged package parts. All nineteen required image slots are filled. Every final rendered page was visually reviewed: {qa['Pages']} pages, PASS. Word counts: `{json.dumps(author['word_counts'])}`. Ten authentic APA references, five per task, and substantial AI disclosure are included. See `report/RENDER_QA.json` and `authoring_validation.json` for hashes and checks.

The named SSIS project ZIP, actual backup, schema and fact PNG aliases, native RMP, final Word/PDF, executable code, complete SQL outputs and evidence are packaged separately for this student. The final ZIP CRC and every member hash are checked by the final packaging script; see `shared/validation/final_package_verification.json`. Full visible AI prompts/tool inputs are exported at the declared UTC cutoff and kept locally for review, not published to Git. Hidden reasoning and unrelated private tool results are excluded.

## Evidence limitations and human steps

Historical failure logs remain preserved. Invalid file-dialog or empty-editor captures were rejected, never inserted as SQL results. Earlier reviewed native overview images are deliberately preserved even where a later guest working filename was overwritten; their local and current guest hashes are distinguished. No synthetic screenshot or Python model visual replaced native evidence.

Real student IDs remain STUDENT_{s}_ID placeholders. Each student must review and understand the work and accurately declare extensive AI assistance. The course discourages AI beyond proofreading; technical PASS does not establish permission from the course. The convenience ZIP does not replace the separate Turnitin report, SSIS project and DW backup submission boxes. No school upload is claimed.
'''
 (base/'evidence/ACCEPTANCE_REPORT.md').write_text(text)
 print(s,'technical acceptance PASS; human review pending')
