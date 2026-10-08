"""Read teacher CSV only. No model execution or automated visual generation."""
import argparse, collections, csv, hashlib, json
from pathlib import Path

def audit(path):
    raw = path.read_bytes()
    try:
        raw.decode('utf-8-sig')
        encoding = 'utf-8-sig'
    except UnicodeDecodeError:
        encoding = 'cp1252'
    with path.open(encoding=encoding, newline='') as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
        fields = reader.fieldnames
    if 'Loan_defaulted' not in fields:
        raise ValueError('Required original target column missing')
    columns = {}
    for name in fields:
        values = [row[name] for row in rows]
        frequencies = collections.Counter(values)
        numeric = []
        for value in values:
            try:
                numeric.append(float(value))
            except ValueError:
                pass
        stats = {'missing_markers': sum(v.strip().lower() in ('', '?', 'na', 'n/a', 'null', 'nan') for v in values),
                 'distinct': len(frequencies), 'numeric_parse_count': len(numeric)}
        if len(numeric) == len(rows):
            stats.update(min=min(numeric), max=max(numeric))
        elif len(frequencies) <= 50:
            stats['values'] = dict(frequencies)
        columns[name] = stats
    targets = collections.Counter(row['Loan_defaulted'] for row in rows)
    valid = [row for row in rows if row['Loan_defaulted'] in ('0', '1')]
    return {'status': 'CSV_STATIC_AUDIT_ONLY_NO_MODEL_EXECUTION', 'encoding': encoding,
            'source_sha256': hashlib.sha256(raw).hexdigest(), 'rows': len(rows), 'columns': columns,
            'target_counts': dict(targets), 'supervised_eligible_rows': len(valid),
            'default_prevalence_labeled': targets['1'] / len(valid),
            'quarantined_invalid_labels': [{'csv_line': i+2, 'customer_id': row['Customer_id'], 'target': row['Loan_defaulted']}
                for i, row in enumerate(rows) if row['Loan_defaulted'].strip() and row['Loan_defaulted'] not in ('0', '1')],
            'duplicate_rows': len(rows)-len(set(tuple(row.values()) for row in rows))}

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    data = audit(args.source)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(data, indent=2) + '\n')
    print(json.dumps({k: data[k] for k in ('status', 'rows', 'target_counts', 'supervised_eligible_rows', 'default_prevalence_labeled', 'quarantined_invalid_labels')}, indent=2))
