"""Summarise preserved runtime evidence and current incomplete delivery gates."""
from pathlib import Path
from datetime import datetime, timezone
import json

ROOT = Path(__file__).resolve().parents[2]
inventory = json.loads((ROOT / 'submission/shared/validation/delivery_inventory.json').read_text())
native = json.loads((ROOT / 'submission/shared/validation/native_holdout_validation.json').read_text())
backup = json.loads((ROOT / 'submission/shared/validation/backup_and_project_verification.json').read_text())
snapshot = datetime.now(timezone.utc).isoformat()

for s in ('A', 'B'):
    base = ROOT / f'submission/Student_{s}'
    run = (base / 'evidence/ssis/warehouse_master_run2.txt').read_text(encoding='utf-8-sig')
    started = next(line.removeprefix('START ') for line in run.splitlines() if line.startswith('START '))
    assert 'WAREHOUSE_MASTER_RUNTIME=PASS' in run
    assert 'WAREHOUSE_VALIDATION_AND_QUERIES=PASS' in (base / 'evidence/sql/execution_status.txt').read_text(encoding='utf-8-sig')
    counts = json.loads((base / 'evidence/sql/warehouse-validation-0.json').read_text(encoding='utf-8-sig'))
    units = sum(r['Units'] for r in json.loads((base / 'evidence/sql/warehouse-validation-1.json').read_text(encoding='utf-8-sig')))
    rows = [f"| {r['ObjectName']} | {r['Rows']:,} |" for r in counts]
    query_rows = []
    for name in ('Q4_1', 'Q4_2', 'Q4_3', 'Q4_3_customer_destination_sensitivity'):
        result = json.loads((base / f'evidence/sql/{name}-0.json').read_text(encoding='utf-8-sig'))
        query_rows.append(f'| {name} | {len(result)} |')
    models = []
    for r in native['results']:
        if r['student'] != s:
            continue
        c = r['confusion']
        models.append(f"| {r['model']} | {r['train_rows']} | {r['holdout_rows']} | {r['native_accuracy']:.6f} | {r['native_auc']:.6f} | {c['TN']}/{c['FP']}/{c['FN']}/{c['TP']} |")
    missing = [f"- `{Path(r['file']).name}`" for r in inventory['students'][s]['required_report_images'] if not r['exists']]
    failures = [f"- `{p.relative_to(base)}`" for p in sorted((base / 'evidence').rglob('*failure*')) if p.is_file()]
    if not failures:
        failures = ['- No separately named failure artifact is present in this student directory. Historical project logs and the shared execution checkpoint preserve the development history.']
    designer = 'PASS: native project reopened and full Master execution success captured; individual image acceptance is incomplete.' if s == 'A' else 'PENDING: native Designer reopening/execution screenshots; backend Master and native project build passed.'
    text = f'''# Student {s} acceptance report

**Overall status: PARTIAL — no final school submission or FINAL assignment ZIP.**

This evidence summary was generated at {snapshot}. That is the report snapshot
time, not an invented execution timestamp. The preserved successful backend
Master log records its start as **{started}**. The native AI runner's result log
does not provide a precise execution timestamp; that timestamp is UNKNOWN.

## Runtime and implementation

The recorded environment is macOS on Apple Silicon with the UTM
`BISM2202-Windows` x86_64 Windows Server 2025 VM, SQL Server 2022 Developer,
SSIS Runtime 16, Visual Studio 2022 Community with SSIS Projects 2.2, and SSMS 22.
The model runs used the installed macOS Altair AI Studio 2026.1.1 native engine
12.1.001 and Java 17. These are the preserved execution baseline; this report
does not claim a new software inventory or reinstall.

- Real SSIS Master execution: PASS at all 11 recorded flow counts.
- Native Visual Studio build and ISPAC semantic comparison: PASS.
- Native Designer GUI: {designer}
- Source fields, four monetary measures, relationships and trusted constraints:
  PASS in the executed SQL validator.
- Original source data and teacher materials: preserved.

## Actual warehouse records

| Table | Recorded rows |
|---|---:|
{chr(10).join(rows)}

Total item quantity across all preserved statuses: **{units:,}**. Delivered
analysis and all-status warehouse totals are separate definitions. Revenue
uses the supplied line amount; recalculated extended amounts remain a separate
measure. Missing freight and the conflicting seller-location mapping remain
explicit source limitations. No cost data exists to establish profit.

The four reference flows recorded 78 Age, 6 Education, 8 State and 100 raw
SellerLocation records; the seller geography role has 99 distinct locations.

## Database restoration and SQL

The actual backup was restored to a separate validation database. CHECKDB,
ten bidirectional full-row table comparisons and four restored analytical
query comparisons passed. This is actual restoration, beyond VERIFYONLY.

- Backup: `database/STUDENT_{s}_ID_dw.bak`
- Bytes: {backup[s]['bytes']}
- SHA256: `{backup[s]['sha256']}`
- Current local backup matches that recorded hash: PASS.
- Real SQL result exports: `evidence/sql/`; reproducible queries: `sql/`.
- Native SSMS result-grid screenshots: PENDING.

| Executed result export | Recorded result rows |
|---|---:|
{chr(10).join(query_rows)}

Q4.3 defines NSW by supplier origin. Customer destination is a separately
labelled sensitivity. Student A uses DENSE_RANK with included fifth-rank ties;
Student B uses deterministic ROW_NUMBER. Shared source facts agree; ranking
rules account for the supplier result-count difference.

## Native model evaluation

The pre-holdout decision was frozen in commit
`{native['pre_holdout_lock_commit']}`. Fold-fitted preprocessing, disjoint
train/holdout identities, matched candidate cohorts and unchanged CV text
passed validation. The named teaching process replay reproduced the original
CV performance; that packaging replay did not repeat the holdout.

| Fixed model | Training rows | Holdout rows | Accuracy | AUC | TN/FP/FN/TP |
|---|---:|---:|---:|---:|---|
{chr(10).join(models)}

Native F1 is undefined in these holdout outputs and is preserved as such.
The separately calculated confusion-count F1 is zero. Every model has zero
holdout default recall at the fixed native classification threshold. No model
is accepted for lending decisions. All eight required native model GUI images
per student are now saved and visually inspected. Training-only CV GUI replay
and fixed holdout display replay reproduce the recorded confusion counts.
The RMP files remain byte-identical to the committed frozen files.
`shared/validation/native_ai_gui_capture_validation.json` records screenshot
hashes, scope and limitations; B's model image shows the first forest tree.

## Delivery integrity and remaining gates

The native SSIS project ZIP passed CRC integrity. Five RMP files per student
are XML-readable. {inventory["students"][s]["unchanged_support_copies"]} unchanged code/data support copies passed
source-to-copy SHA256 comparison. Original-template report drafts have a
completed nine-page layout review, but final image-filled reports require
another full render and page review. Student IDs remain placeholders.

Missing required report screenshots at this snapshot:

{chr(10).join(missing)}

Other incomplete items: final image-filled DOCX/PDF, final visible AI record
snapshot and student review, final manifests and FINAL assignment ZIP.
The AI declaration discloses substantial design, code, execution, analysis
and drafting assistance; student confirmation of course AI/cooperation rules
is required. No manual student execution or independent authorship is invented.

## Preserved failures and limitations

{chr(10).join(failures)}

UTM mouse input does not reliably reach the Windows guest. After explicit
command-takeover authorisation, Windows native messages successfully selected
and fitted the Customer Geography flow; its complete native screenshot was
visually reviewed. Further flow captures remain subject to visual acceptance.
The Cua launcher binding still cannot attach AI Studio's running Java window.
Native macOS Accessibility control using an already trusted Swift process now
reads and controls that actual window. The user explicitly authorised the EULA
and completed login; the actual window now shows Trial 2026.1.1. Native model
GUI captures are saved. A later UTM RPC timeout also prevented pause/resume;
the guest stopped and was started again using utmctl. Windows session recovery
and remaining screenshots are still pending. Native runtime evidence has not
been replaced by reconstructed screenshots or Python-generated model visuals.
'''
    target = base / 'evidence/ACCEPTANCE_REPORT.md'
    target.write_text(text)
    print(f'Student {s}: PARTIAL acceptance report written; {len(missing)} native images missing')
