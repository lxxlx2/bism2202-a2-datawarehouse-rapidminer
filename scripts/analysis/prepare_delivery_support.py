"""Copy unchanged run support into each delivery; this does not grant FINAL status."""
from pathlib import Path
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[2]
LOAN = ROOT / 'requirements/extracted/RapidMiner/BISM2202_A2_Loan_Data_Set_RapidMiner2026S2.csv'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


for student in ('A', 'B'):
    dest = ROOT / f'submission/Student_{student}'
    copied = []
    sources = sorted((ROOT / 'scripts/windows/warehouse').glob('*'))
    sources += sorted((ROOT / 'scripts/rapidminer').glob('*'))
    sources += [ROOT / 'scripts/analysis/audit_loan_csv.py']
    for source in sources:
        if not source.is_file() or source.suffix not in ('.py', '.ps1', '.cs', '.sql', '.java', '.sh'):
            continue
        target = dest / 'code' / source.relative_to(ROOT)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        assert sha(source) == sha(target)
        copied.append({'file': str(target.relative_to(dest)), 'source': str(source.relative_to(ROOT)), 'sha256': sha(target)})
    target = dest / 'rapidminer/data' / LOAN.name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(LOAN, target)
    assert sha(LOAN) == sha(target)
    copied.append({'file': str(target.relative_to(dest)), 'source': str(LOAN.relative_to(ROOT)), 'sha256': sha(target)})
    (dest / 'code/README.md').write_text('''# Execution support and provenance

These are byte-identical copies of the project's implementation and audit code.
The recorded experiments and database checks are the execution evidence; copying
code is not a new execution or an acceptance result.

Use the Visual Studio solution and its `ssis/README_RUN.md` for the verified
native SSIS route. The PowerShell warehouse scripts use the existing Windows
layout `C:\\BISM2202\\assignment_work` and `C:\\BISM2202\\submission`, local
SQL Server and an already authorised Windows SQL login. They create/load only
the named assignment warehouses; read each script before running it. The source
`ozmart_db` comes from the teacher's original backup, which is not duplicated in
this delivery. Earlier individual loaders preserve the implementation history;
`load_warehouse_master.ps1` is the final full data-flow loader.

The Python generators and Java native runner are repository-oriented audit
companions. Their relative paths assume the original repository layout and the
installed AI Studio version recorded in the validation evidence. These copied
sources are not claimed to be a standalone rebuild system. For ordinary model
reopening, use the supplied `.rmp` files and `rapidminer/README_RUN.md`.

Do not rerun the holdout to choose settings or candidates. Preserve the frozen
pre-holdout decision, seeds, feature lists and training-only preprocessing.
''')
    (dest / 'rapidminer/README_RUN.md').write_text(f'''# Native AI Studio reopening — Student {student}

Open `STUDENT_{student}_ID_rapidminer.rmp` in the installed Altair AI Studio.
The default branch is Logistic Regression training-only cross-validation.
Follow `SWITCH_MODELS.md` for the second model. The separately supplied CV and
holdout processes preserve the fixed native experiments.

The original teacher CSV is supplied unchanged in `data/{LOAN.name}`.
SHA256: `{sha(LOAN)}`. Keep its Windows-1252 encoding and original malformed
value; the process performs the documented exclusion rather than editing data.

The preserved `source_csv` macro currently contains the absolute source path
used for the recorded runs. After moving this delivery, set only that macro
to the absolute location of the supplied CSV in each process being opened.
Do not change any seed, partition, filter, preprocessing or model parameter.
Macro relocation is a portability step, not a new model experiment.

The named process leaves the holdout partition unconnected. Read the saved
native metrics and identity validation before any viewing replay. No held-out
model detected a default at its fixed classification threshold; undefined
native F1 values are preserved. GUI evidence acceptance remains separately
recorded in the manifest.
''')
    record = {'status': 'SUPPORT_COPY_HASH_CHECK_PASS_NOT_FINAL_ACCEPTANCE', 'student': student, 'files': copied}
    (dest / 'code/support_copy_validation.json').write_text(json.dumps(record, indent=2) + '\n')
    print(f'Student {student}: {len(copied)} unchanged support files verified')
