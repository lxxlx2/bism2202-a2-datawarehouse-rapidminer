"""Inventory real delivery files without promoting incomplete work to FINAL."""
from pathlib import Path
import hashlib
import json
import runpy
import zipfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
slots = runpy.run_path(str(ROOT / 'scripts/analysis/build_template_reports.py'))['IMAGE_SLOTS']
verified = json.loads((ROOT / 'submission/shared/validation/backup_and_project_verification.json').read_text())
output = {'status': 'PARTIAL', 'scope': 'Current local file integrity; prior runtime evidence remains separate', 'students': {}}


def describe(path):
    if not path.is_file():
        return {'file': str(path.relative_to(ROOT)), 'exists': False}
    return {'file': str(path.relative_to(ROOT)), 'exists': True, 'bytes': path.stat().st_size,
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


for s in ('A', 'B'):
    base = ROOT / f'submission/Student_{s}'
    images = [describe(base / 'evidence' / rel.format(s=s)) for rels in slots.values() for rel in rels]
    backup = describe(base / f'database/STUDENT_{s}_ID_dw.bak')
    assert backup['exists'] and backup['sha256'] == verified[s]['sha256'] and backup['bytes'] == verified[s]['bytes']
    archive = base / f'ssis/STUDENT_{s}_ID_ssis.zip'
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
        members = z.namelist()
        assert any(n.endswith('Master.dtsx') for n in members)
        assert any(n.endswith('.sln') for n in members)
        assert any(n.endswith('.ispac') for n in members)
        assert sum(n.endswith('.csv') for n in members) == 4
    models = []
    for p in sorted((base / 'rapidminer').glob('*.rmp')):
        ET.parse(p)
        models.append(describe(p))
    copies = json.loads((base / 'code/support_copy_validation.json').read_text())['files']
    for item in copies:
        assert describe(base / item['file'])['sha256'] == item['sha256']
        assert (base / item['file']).read_bytes() == (ROOT / item['source']).read_bytes()
    output['students'][s] = {
        'status': 'PARTIAL', 'backup_hash_matches_actual_restore_record': True, 'backup': backup,
        'ssis_project_zip': describe(archive), 'ssis_project_zip_crc': 'PASS',
        'rmp_xml_readability': 'PASS_NOT_GUI_ACCEPTANCE', 'rmp_files': models,
        'unchanged_support_copies': len(copies), 'support_hashes': 'PASS',
        'required_report_images': images,
        'missing_report_images': sum(not item['exists'] for item in images),
        'final_report_files': [describe(base / f'report/STUDENT_{s}_ID.{ext}') for ext in ('docx', 'pdf')],
        'final_assignment_zip': describe(ROOT / f'submission/BISM2202_Student_{s}_FINAL.zip'),
        'pending': ['remaining native screenshots', 'image-filled final report and page review',
                    'final AI disclosure snapshot and student review', 'final packaging and acceptance']}
    print(f"Student {s}: backup/ZIP/support file integrity PASS; {output['students'][s]['missing_report_images']} required images missing; PARTIAL")
(ROOT / 'submission/shared/validation/delivery_inventory.json').write_text(json.dumps(output, indent=2) + '\n')
