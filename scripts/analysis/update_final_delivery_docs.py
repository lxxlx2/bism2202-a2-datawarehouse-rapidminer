"""Publish local technical-delivery status only after current report QA passes."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[2]
for s in 'AB':
 base=ROOT/f'submission/Student_{s}';qa=json.loads((base/'report/RENDER_QA.json').read_text());assert qa['Status']=='PASS'
 model='Logistic Regression / Decision Tree; 80/20 stratified split, seed 2202' if s=='A' else 'Logistic Regression / Random Forest; 70/30 stratified split, seed 2203'
 text=f'''# Student {s} final local delivery

Technical status: PASS. Student ID confirmation and student review of AI/collaboration rules: PENDING. No school upload has been performed.

Open `report/STUDENT_{s}_ID.docx` for the editable report and `report/STUDENT_{s}_ID.pdf` for the reviewed rendering ({qa['Pages']} pages). Both retain the teacher template; native screenshots and ten APA references are included. Word limits and every rendered page passed review.

## Required named artifacts

- Report: `report/STUDENT_{s}_ID.docx` (Turnitin report box).
- Native project: `ssis/STUDENT_{s}_ID_ssis.zip` (SSIS box); open the solution inside it and follow `ssis/README_RUN.md`.
- Actual restored/verified backup: `database/STUDENT_{s}_ID_dw.bak` (DW box); database name is `STUDENT_{s}_ID_dw`.
- Diagrams: `diagrams/STUDENT_{s}_ID_dm.png` and `diagrams/STUDENT_{s}_ID_fact.png`. Fact is the genuine native overview; readable native stage images accompany it in `evidence/gui/`.
- Native model process: `rapidminer/STUDENT_{s}_ID_rapidminer.rmp`; model switching and unchanged CSV path relocation instructions are supplied.
- SQL: `sql/`; complete actual query exports: `evidence/sql/`; original native GUI images: `evidence/gui/`.
- Technical acceptance: `evidence/ACCEPTANCE_REPORT.md`; file hashes: `FILE_HASHES.json`; shared validation proofs accompany each convenience ZIP.

The outer `BISM2202_Student_{s}_FINAL.zip` is a convenience delivery archive. It does not replace the separate school submission boxes. IDs remain explicit placeholders because real IDs have not been confirmed. Changing only a filename is insufficient to change internal warehouse/project/report IDs; do not invent an ID or claim this step is complete.

## Reproducibility and limitations

Actual independent SSIS Master, native Designer execution, all source/monetary/relationship/constraint checks, final SQL results and isolated actual backup restoration passed. Q4.3 defines NSW by supplier origin; destination sensitivity is separately labelled. A preserves fifth-rank ties with DENSE_RANK; B returns deterministic five rows per year with ROW_NUMBER. Original missing freight and conflicting geography are preserved.

Native models: {model}; five-fold training-only CV. Original RMP files, preprocessing, splits and candidate decisions remain frozen. All four held-out classifiers have zero default recall at their fixed threshold. Native undefined F1 remains undefined; separately count-derived F1 is zero. No classifier is accepted for operational lending. GUI viewing replays did not retune or reselect the model.

Read `AI_DISCLOSURE.md` and `shared/ai_disclosure/visible_prompts_and_ai_outputs_record.md`. Codex substantially assisted design, code, execution, analysis and drafting. The export states its actual UTC cutoff; later packaging/Git/handoff activity is not claimed to be included. Students must understand and review the work and make a truthful declaration under the course's AI/cooperation rules. Technical verification is separate from that human acceptance.

No fabricated screenshot, source value, result or student authorship is used. Failed captures remain outside report evidence. Teacher originals are SHA256-verified unchanged. Local backup, archive, reports, original data copy and full AI record remain local; Git contains code and bounded evidence/manifests.
'''
 (base/'README.md').write_text(text)
 (base/'MANIFEST.md').write_text(f'''# Student {s} artifact manifest

Technical delivery: PASS. Human ID/course-policy review: PENDING. School submission: NOT PERFORMED.

`FILE_HASHES.json` lists actual files, sizes and SHA256s. `shared/validation/final_package_verification.json` records the outer ZIP CRC, member count, member-to-source byte verification and archive SHA256. `shared/validation/delivery_inventory.json` records final backup, SSIS, native RMP, code-copy, required images, report and package checks. These checks do not establish student authorship or course approval.

| Artifact | Evidence |
|---|---|
| Full native SSIS project and ISPAC | Native build and semantic comparison PASS; full Designer success and seven data-flow overviews plus readable detail screenshots |
| Actual DW backup | Actual isolated restore, CHECKDB, ten full-row table and four query comparisons PASS |
| SQL queries/results | Actual complete CSV/JSON plus native SSMS result grids; all requested rows covered |
| Native AI Studio | Two native model processes, CV, model outputs and fixed holdout screens; unchanged RMP and disjoint identity validation PASS |
| Teacher-template Word/PDF | Nineteen required image slots, word-limit checks and {qa['Pages']}-page visual QA PASS |
| Named schema/fact PNGs | Byte-identical aliases of verified schema and original native fact overview |
| Full visible AI record | Local export with explicit cutoff; substantial AI assistance disclosed; personal review pending |
| Final independent ZIP | CRC and every-member source hash checked by packaging script |

See README for separate submission-box instructions and unresolved real IDs.
''')
 p=base/'ssis/README_RUN.md';t=p.read_text();t=t.replace('The current overall delivery is PARTIAL because genuine required screenshots and final report/package acceptance remain outstanding. Native runtime/build/restore passes are recorded separately from this remaining evidence work.','Technical delivery is PASS: native screenshots, final teacher-template report rendering and package integrity have passed. Real student ID confirmation and personal course AI/collaboration review remain pending; no school upload is claimed.');p.write_text(t)
 print(s,'final delivery documentation prepared')
