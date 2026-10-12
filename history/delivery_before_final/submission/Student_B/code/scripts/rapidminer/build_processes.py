"""Create native RapidMiner XML only; no model metrics or visuals generated."""
from pathlib import Path
from lxml import etree as E
import csv
ROOT=Path(__file__).resolve().parents[2]
DATA=ROOT/'requirements/extracted/RapidMiner/BISM2202_A2_Loan_Data_Set_RapidMiner2026S2.csv'
VER='12.1.001'

def op(parent, cls, name, params=None, x=45, y=45):
    node=E.SubElement(parent,'operator',activated='true',**{'class':cls,'compatibility':VER,'expanded':'true','height':'68','name':name,'width':'90','x':str(x),'y':str(y)})
    for k,v in (params or {}).items(): E.SubElement(node,'parameter',key=k,value=str(v))
    return node

def connect(parent,source,sp,target,tp):
    a={'from_port':sp,'to_port':tp}
    if source: a['from_op']=source
    if target: a['to_op']=target
    E.SubElement(parent,'connect',**a)

def base():
    root=E.Element('process',version=VER)
    context=E.SubElement(root,'context'); E.SubElement(context,'input'); E.SubElement(context,'output')
    macros=E.SubElement(context,'macros'); macro=E.SubElement(macros,'macro'); E.SubElement(macro,'key').text='source_csv';E.SubElement(macro,'value').text=str(DATA)
    outer=op(root,'process','Process',{'logverbosity':'init','random_seed':'2202','send_mail':'never'})
    inner=E.SubElement(outer,'process',expanded='true')
    reader=op(inner,'read_csv','Read Original Loan CSV',{'csv_file':'%{source_csv}','column_separators':',','encoding':'windows-1252','use_header_row':'true','read_not_matching_values_as_missings':'true','read_all_values_as_polynominal':'false'})
    meta=E.SubElement(reader,'list',key='data_set_meta_data_information')
    with DATA.open(encoding='cp1252') as handle: fields=next(csv.reader(handle))
    nominal={'Customer_id','Work_class','Education','Marital_status','Occupation','Race','Gender','State','Country/area_of_origin','Income','Loan_purpose'}
    integer={'Age','Years_of_education','Capital_gain','Capital_loss','Weekly_work_hours','Current_mortgage','Student_debt','Number_of_homes_owned','Past_bankruptcy','Loan_defaulted'}
    for i,c in enumerate(fields):
        dtype='polynominal' if c in nominal else 'integer' if c in integer else 'real'
        E.SubElement(meta,'parameter',key=str(i),value=f'{c}.true.{dtype}.attribute')
    op(inner,'set_role','Set Loan Default Label',{'attribute_name':'Loan_defaulted','target_role':'label'},180)
    op(inner,'set_role','Set Customer ID',{'attribute_name':'Customer_id','target_role':'id'},315)
    op(inner,'filter_examples','Keep Verified Labels',{'condition_class':'no_missing_labels'},450)
    op(inner,'numerical_to_binominal','Default 1 Is True',{'attribute_filter_type':'single','attribute':'Loan_defaulted','include_special_attributes':'true','min':'0.0','max':'0.0'},585)
    chain=['Read Original Loan CSV','Set Loan Default Label','Set Customer ID','Keep Verified Labels','Default 1 Is True']
    connect(inner,chain[0],'output',chain[1],'example set input')
    for a,b in zip(chain[1:],chain[2:]):connect(inner,a,'example set output',b,'example set input')
    return root,inner

def save(root,path):
    path.parent.mkdir(parents=True,exist_ok=True)
    E.ElementTree(root).write(str(path),encoding='UTF-8',xml_declaration=True,pretty_print=True)

if __name__=='__main__':
    root,inner=base()
    connect(inner,'Default 1 Is True','example set output',None,'result 1')
    save(root,ROOT/'work/native_ai/loan_import_smoke.rmp')

FEATURES_A=['Age','Loan_amount','Education','Capital_gain','Capital_loss','Weekly_work_hours','Income','Current_mortgage','Student_debt','Number_of_homes_owned','Bank_balance','Loan_purpose','Credit_history','Past_bankruptcy']

def perf(parent,name,x,y):
    return op(parent,'performance_binominal_classification',name,{
        'manually_set_positive_class':'true','positive_class':'true','main_criterion':'f_measure',
        'accuracy':'true','precision':'true','recall':'true','f_measure':'true','AUC':'true',
        'false_positive':'true','false_negative':'true','true_positive':'true','true_negative':'true',
        'skip_undefined_labels':'false'},x,y)

def candidate(student,learner,holdout=False):
    root,inner=base()
    features=FEATURES_A if student=='A' else [f for f in FEATURES_A if f not in ('Education','Weekly_work_hours')]
    op(inner,'select_attributes','Financial Predictors',{'attribute_filter_type':'subset','attributes':'|'.join(features),'include_special_attributes':'false'},720)
    connect(inner,'Default 1 Is True','example set output','Financial Predictors','example set input')
    ratio='0.8' if student=='A' else '0.7'; seed='2202' if student=='A' else '2203'
    split=op(inner,'split_data','Independent Stratified Split',{'sampling_type':'stratified sampling','use_local_random_seed':'true','local_random_seed':seed},855)
    partitions=E.SubElement(split,'enumeration',key='partitions')
    E.SubElement(partitions,'parameter',key='ratio',value=ratio)
    E.SubElement(partitions,'parameter',key='ratio',value='0.2' if student=='A' else '0.3')
    connect(inner,'Financial Predictors','example set output','Independent Stratified Split','example set')
    cv=op(inner,'x_validation','Training Only Cross Validation',{'number_of_validations':'5','sampling_type':'stratified sampling','use_local_random_seed':'true','local_random_seed':'5501' if student=='A' else '5502','create_complete_model':'true'},990)
    connect(inner,'Independent Stratified Split','partition 1','Training Only Cross Validation','training')
    training=E.SubElement(cv,'process',expanded='true')
    op(training,'replace_missing_values','Fit Training Imputer',{'return_preprocessing_model':'true','attribute_filter_type':'all','default':'average'},45)
    op(training,'remove_unused_values','Training Vocabulary Only',{'return_preprocessing_model':'true','attribute_filter_type':'all','include_special_attributes':'false'},180)
    connect(training,None,'training','Fit Training Imputer','example set input')
    connect(training,'Fit Training Imputer','example set output','Training Vocabulary Only','example set input')
    models=['Fit Training Imputer','Training Vocabulary Only']; previous='Training Vocabulary Only'
    if learner=='logistic_regression':
        op(training,'nominal_to_numerical','Fit Training Dummy Coding',{'return_preprocessing_model':'true','attribute_filter_type':'all','include_special_attributes':'false','coding_type':'dummy coding','unexpected_value_handling':'all 0 and warning'},315)
        op(training,'normalize','Fit Training Z Scores',{'return_preprocessing_model':'true','attribute_filter_type':'all','method':'Z-transformation','include_special_attributes':'false'},450)
        connect(training,previous,'example set output','Fit Training Dummy Coding','example set input')
        connect(training,'Fit Training Dummy Coding','example set output','Fit Training Z Scores','example set input')
        models+=['Fit Training Dummy Coding','Fit Training Z Scores'];previous='Fit Training Z Scores'
        params={'kernel_type':'dot','C':'1.0','scale':'false','calculate_weights':'true'}
    elif learner=='decision_tree':params={'criterion':'gain_ratio','maximal_depth':'10','minimal_leaf_size':'8'}
    else:params={'number_of_trees':'50','criterion':'gain_ratio','maximal_depth':'10','minimal_leaf_size':'8','use_local_random_seed':'true','local_random_seed':seed}
    op(training,learner,'Chosen Classifier',params,585)
    connect(training,previous,'example set output','Chosen Classifier','training set')
    op(training,'group_models','Training Transformations And Classifier',None,720)
    for i,name in enumerate(models,1): connect(training,name,'preprocessing model','Training Transformations And Classifier',f'models in {i}')
    connect(training,'Chosen Classifier','model','Training Transformations And Classifier',f'models in {len(models)+1}')
    connect(training,'Training Transformations And Classifier','model out',None,'model')
    testing=E.SubElement(cv,'process',expanded='true')
    op(testing,'apply_model','Apply Fold Training Model',None,45)
    perf(testing,'Default Class Fold Performance',180,45)
    connect(testing,None,'model','Apply Fold Training Model','model')
    connect(testing,None,'test set','Apply Fold Training Model','unlabelled data')
    connect(testing,'Apply Fold Training Model','labelled data','Default Class Fold Performance','labelled data')
    connect(testing,'Default Class Fold Performance','performance',None,'averagable 1')
    connect(inner,'Training Only Cross Validation','averagable 1',None,'result 1')
    if holdout:
        op(inner,'apply_model','Untouched Holdout Predictions',None,1125,180)
        perf(inner,'Untouched Holdout Performance',1260,180)
        connect(inner,'Training Only Cross Validation','model','Untouched Holdout Predictions','model')
        connect(inner,'Independent Stratified Split','partition 2','Untouched Holdout Predictions','unlabelled data')
        connect(inner,'Untouched Holdout Predictions','labelled data','Untouched Holdout Performance','labelled data')
        connect(inner,'Untouched Holdout Performance','performance',None,'result 2')
        connect(inner,'Untouched Holdout Predictions','model',None,'result 3')
        connect(inner,'Untouched Holdout Performance','example set',None,'result 4')
    else:
        connect(inner,'Training Only Cross Validation','model',None,'result 2')
    return root

if __name__=='__main__':
    for student,learners in [('A',['logistic_regression','decision_tree']),('B',['logistic_regression','random_forest'])]:
        for learner in learners:
            save(candidate(student,learner),ROOT/f'submission/Student_{student}/rapidminer/cv_only_{learner}.rmp')
