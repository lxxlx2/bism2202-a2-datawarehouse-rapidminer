"""Verify native engine outputs and identities. No model retraining or visuals."""
from pathlib import Path
import csv,json,math,hashlib,collections
ROOT=Path(__file__).resolve().parents[2]
summary=[]
manifest=[]
for student,models in [('A',['logistic_regression','decision_tree']),('B',['logistic_regression','random_forest'])]:
    cohort=None
    for model in models:
        source=ROOT/f'work/native_ai/{student}_{model}_holdout'
        log=ROOT/f'work/native_ai/{student}_{model}_holdout.log'
        if 'NATIVE_PROCESS_EXECUTION=PASS' not in log.read_text():
            raise RuntimeError(f'Native execution did not complete: {student} {model}')
        target=ROOT/f'submission/Student_{student}/evidence/native'
        target.mkdir(parents=True,exist_ok=True)
        (target/f'{model}_holdout_execution.log').write_bytes(log.read_bytes())
        for f in source.iterdir():
            if f.is_file():
                dest=target/f'{model}_holdout_{f.name}'
                dest.write_bytes(f.read_bytes())
                manifest.append({'file':str(dest.relative_to(ROOT)),'sha256':hashlib.sha256(dest.read_bytes()).hexdigest()})
        with (source/'result_3_identities.csv').open() as h: test=list(csv.DictReader(h))
        with (source/'result_4_identities.csv').open() as h: train=list(csv.DictReader(h))
        test_ids={r['id'] for r in test};train_ids={r['id'] for r in train}
        assert len(test_ids)==len(test) and len(train_ids)==len(train)
        assert not test_ids & train_ids and len(test_ids|train_ids)==9998
        assert 'C_5822' not in test_ids|train_ids
        if cohort is None:cohort=(test_ids,train_ids)
        else:assert cohort==(test_ids,train_ids),'Candidate cohorts differ within a student'
        with (source/'result_1_metrics.csv').open() as h:
            metrics={r['criterion']:float(r['native_average']) for r in csv.DictReader(h)}
        confusion=collections.Counter((r['label'],r['prediction']) for r in test)
        tp=confusion[('true','true')];fp=confusion[('false','true')]
        fn=confusion[('true','false')];tn=confusion[('false','false')]
        assert tp+fp+fn+tn==len(test)
        for name,val in [('true_positive',tp),('false_positive',fp),('false_negative',fn),('true_negative',tn)]:assert metrics[name]==val
        accuracy=(tp+tn)/len(test);recall=tp/(tp+fn) if tp+fn else None
        assert abs(metrics['accuracy']-accuracy)<1e-12 and abs(metrics['recall']-recall)<1e-12
        derived_f1=2*tp/(2*tp+fp+fn) if 2*tp+fp+fn else None
        original_cv=(ROOT/f'work/native_ai/{student}_{model}_cv/result_0.txt').read_bytes()
        repeat_cv=(source/'result_0.txt').read_bytes()
        assert original_cv==repeat_cv,'Native CV result changed between frozen and holdout process'
        summary.append({'student':student,'model':model,'train_rows':len(train),'holdout_rows':len(test),
          'split_overlap':0,'cohort_union_rows':9998,'positive_class':'true = original Loan_defaulted 1',
          'native_accuracy':accuracy,'native_precision':metrics['precision'] if math.isfinite(metrics['precision']) else None,
          'native_recall':recall,'native_f1':metrics['f_measure'] if math.isfinite(metrics['f_measure']) else None,
          'native_auc':metrics['AUC'],'confusion':{'TN':tn,'FP':fp,'FN':fn,'TP':tp},
          'confusion_formula_f1':derived_f1,'metric_definition_note':'Native f_measure is undefined in these outputs; direct count formula 2TP/(2TP+FP+FN) is independently 0. Preserve both; do not replace native output.',
          'majority_nondefault_holdout_baseline':(tn+fp)/len(test),'frozen_cv_exact_text_match':True})
result={'status':'NATIVE_ENGINE_RUN_AND_IDENTITY_VALIDATION_PASS_GUI_ACCEPTANCE_PENDING',
 'pre_holdout_lock_commit':'7afc833dca81d220f0801c79ac723c4aaf092b23',
 'results':summary,'files':manifest}
(ROOT/'submission/shared/validation/native_holdout_validation.json').write_text(json.dumps(result,indent=2,allow_nan=False)+'\n')
print(json.dumps(summary,indent=2,allow_nan=False))
