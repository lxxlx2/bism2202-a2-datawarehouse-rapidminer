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
output = {'status': 'TECHNICAL_PASS_HUMAN_REVIEW_PENDING', 'scope': 'Current local file integrity; prior runtime evidence remains separate', 'students': {}}


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
        'status': 'TECHNICAL_PASS_HUMAN_REVIEW_PENDING', 'backup_hash_matches_actual_restore_record': True, 'backup': backup,
        'ssis_project_zip': describe(archive), 'ssis_project_zip_crc': 'PASS',
        'rmp_xml_readability': 'PASS_NOT_GUI_ACCEPTANCE', 'rmp_files': models,
        'unchanged_support_copies': len(copies), 'support_hashes': 'PASS',
        'required_report_images': images,
        'missing_report_images': sum(not item['exists'] for item in images),
        'final_report_files': [describe(base / f'report/STUDENT_{s}_ID.{ext}') for ext in ('docx', 'pdf')],
        'final_assignment_zip': describe(ROOT / f'submission/BISM2202_Student_{s}_FINAL.zip'),
        'pending': ['Real student ID confirmation', 'Student review and course AI/collaboration acceptance', 'School submission (not performed)']}
    qa = json.loads((base / 'report/RENDER_QA.json').read_text())
    assert qa['Status'] == 'PASS'
    assert qa['DocxSha256'] == describe(base / f'report/STUDENT_{s}_ID.docx')['sha256']
    assert qa['PdfSha256'] == describe(base / f'report/STUDENT_{s}_ID.pdf')['sha256']
    assert all(x['exists'] for x in images)
    package = json.loads((ROOT / 'submission/shared/validation/final_package_verification.json').read_text())
    record = next(x for x in package['Packages'] if x['Student'] == s)
    assert record['Sha256'] == output['students'][s]['final_assignment_zip']['sha256']
    assert record['CRC'] == 'PASS' and record['EveryMemberMatchesCurrentSource'] == 'PASS'
    output['students'][s]['render_review'] = qa['Status']
    output['students'][s]['render_pages'] = qa['Pages']
    output['students'][s]['final_package_integrity'] = 'PASS'
    print(f"Student {s}: backup/project/code/images/report/final package integrity PASS; human review pending")
(ROOT / 'submission/shared/validation/delivery_inventory.json').write_text(json.dumps(output, indent=2) + '\n')
