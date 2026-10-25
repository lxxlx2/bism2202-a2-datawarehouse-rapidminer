#!/usr/bin/env python3
"""Safely inspect/repair a BISM2202 RapidMiner project on macOS.

Uses Python 3 standard library and macOS screencapture. No package installation.
Keeps a backup of each file before any modification. Does not launch or run RapidMiner.
"""
import argparse
import datetime
import json
import os
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

EXPECTED = (
    'NaiveBayes_CV.rmp', 'NaiveBayes_Full.rmp',
    'GradientBoostedTrees_CV.rmp', 'GradientBoostedTrees_Full.rmp',
    'BISM2202_A2_rapidminer.rmp',
)
FULL = {'NaiveBayes_Full.rmp', 'GradientBoostedTrees_Full.rmp', 'BISM2202_A2_rapidminer.rmp'}


def directories():
    cwd = Path.cwd().resolve()
    candidates = [cwd, cwd / 'rapidminer', cwd.parent,
                  Path.home() / 'Downloads', Path.home() / 'Desktop']
    seen = set()
    for root in candidates:
        if not root.exists() or not root.is_dir():
            continue
        root = root.resolve()
        if root in seen:
            continue
        seen.add(root)
        if set(EXPECTED).issubset({p.name for p in root.glob('*.rmp')}):
            yield root
        if root == cwd or root == cwd.parent:
            max_depth = 4
        else:
            max_depth = 3
        for dirpath, dirs, files in os.walk(root):
            curr = Path(dirpath)
            try:
                depth = len(curr.relative_to(root).parts)
            except ValueError:
                continue
            dirs[:] = [d for d in dirs if not d.startswith('.') and d not in {
                'node_modules', '.git', '__pycache__', 'venv', '.venv', 'Library',
                '_RapidMiner_backup', '_RapidMiner_检查与截图'
            } and depth < max_depth]
            if depth > max_depth or not set(EXPECTED).issubset(set(files)):
                continue
            found = curr.resolve()
            if found not in seen:
                seen.add(found)
                yield found


def select_folder(given):
    if given:
        folder = Path(given).expanduser().resolve()
        if not folder.is_dir():
            raise RuntimeError('指定的文件夹不存在: ' + str(folder))
        missing = set(EXPECTED) - {p.name for p in folder.glob('*.rmp')}
        if missing:
            raise RuntimeError('缺少 RapidMiner 文件: ' + ', '.join(sorted(missing)))
        return folder
    found = list(directories())
    if not found:
        raise RuntimeError('没有找到包含全部五份 .rmp 的 rapidminer 文件夹。请在项目目录运行命令，或传入 --root /路径/rapidminer')
    if len(found) > 1:
        print('找到多个候选目录，请用 --root 指定准确路径：')
        for folder in found:
            print('  ', folder)
        raise RuntimeError('有多个候选项目，为避免修改错误项目，本次未写入')
    return found[0]


def operators(parent, class_name):
    return [item for item in parent.findall('operator') if item.get('class') == class_name]


def param(node, key, expected, changes):
    item = next((x for x in node.findall('parameter') if x.get('key') == key), None)
    if item is None:
        item = ET.SubElement(node, 'parameter', {'key': key})
    actual = item.get('value')
    if actual != expected:
        item.set('value', expected)
        changes.append('设置 ' + key + ': ' + str(actual) + ' -> ' + expected)


def ensure_wire(proc, from_op, from_port, to_op, to_port, changes):
    matches = [c for c in proc.findall('connect')
               if c.get('from_op') == from_op and c.get('from_port') == from_port]
    if len(matches) == 1 and matches[0].get('to_op') == to_op and matches[0].get('to_port') == to_port:
        return
    for c in matches:
        proc.remove(c)
    attrs = {'from_port': from_port, 'to_port': to_port}
    if from_op is not None:
        attrs['from_op'] = from_op
    if to_op is not None:
        attrs['to_op'] = to_op
    ET.SubElement(proc, 'connect', attrs)
    changes.append('修正连接 {}.{} -> {}.{}'.format(from_op or '入口', from_port, to_op or '结果', to_port))


def repair(raw, filename):
    doc = ET.fromstring(raw)
    top = doc.find('operator/process')
    if top is None:
        raise ValueError('没有找到外层 Process')
    splits, cvs = operators(top, 'split_data'), operators(top, 'x_validation')
    count = 2 if filename == 'BISM2202_A2_rapidminer.rmp' else 1
    if len(splits) != count or len(cvs) != count:
        raise ValueError('Split / CV 结构与预期不符，拒绝修改')
    changes = []
    for index, (split, cv) in enumerate(zip(splits, cvs)):
        split_name = split.get('name')
        cv_name = cv.get('name')
        if not split_name or not cv_name:
            raise ValueError('Split/CV 缺少算子名称')
        for key, value in [('sampling_type','stratified sampling'),('use_local_random_seed','true'),('local_random_seed','73421')]:
            param(split,key,value,changes)
        part = split.find("enumeration[@key='partitions']")
        if part is None:
            part = ET.SubElement(split, 'enumeration', {'key': 'partitions'})
        ratios = part.findall('parameter')
        if len(ratios)!=2 or [a.get('value') for a in ratios]!=['0.75','0.25']:
            for el in list(part):part.remove(el)
            for ratio in ['0.75','0.25']:
                ET.SubElement(part,'parameter',{'key':'ratio','value':ratio})
            changes.append('设置训练/测试比例 75%/25%')
        for key,value in [('number_of_validations','5'),('sampling_type','stratified sampling'),
                          ('use_local_random_seed','true'),('local_random_seed','74219'),('create_complete_model','true')]:
            param(cv,key,value,changes)
        if len(cv.findall('process')) != 2:
            raise ValueError('CV 内层训练/测试结构不完整，拒绝修改')
        cv_test = cv.findall('process')[1]
        app, perf = operators(cv_test,'apply_model'),operators(cv_test,'performance_binominal_classification')
        if len(app)!=1 or len(perf)!=1:
            raise ValueError('CV 内层模型应用或性能评估算子不唯一，拒绝修改')
        ensure_wire(top,split_name,'partition 1',cv_name,'training',changes)
        ensure_wire(cv_test,None,'model',app[0].get('name'),'model',changes)
        ensure_wire(cv_test,None,'test set',app[0].get('name'),'unlabelled data',changes)
        ensure_wire(cv_test,app[0].get('name'),'labelled data',perf[0].get('name'),'labelled data',changes)
        if filename in FULL:
            prefix = ('NB ' if index==0 else 'GBT ') if count==2 else ''
            holdouts=[op for op in operators(top,'apply_model') if op.get('name','').startswith(prefix)]
            metrics=[op for op in operators(top,'performance_binominal_classification') if op.get('name','').startswith(prefix)]
            if len(holdouts)!=1 or len(metrics)!=1:
                raise ValueError('外层 Apply Model 或 Performance 结构不唯一，拒绝修改')
            holdout_name, perf_name = holdouts[0].get('name'),metrics[0].get('name')
            for c in top.findall('connect'):
                if c.get('from_op')==cv_name and c.get('from_port')=='model' and not c.get('to_op') and c.get('to_port','').startswith('result '):
                    c.set('from_op',holdout_name)
                    changes.append('修复重复 CV.model 结果输出')
            ensure_wire(top,cv_name,'model',holdout_name,'model',changes)
            ensure_wire(top,split_name,'partition 2',holdout_name,'unlabelled data',changes)
            ensure_wire(top,holdout_name,'labelled data',perf_name,'labelled data',changes)
            training=[c for c in top.findall('connect') if c.get('to_op')==cv_name and c.get('to_port')=='training']
            if len(training)!=1 or training[0].get('from_op')!=split_name or training[0].get('from_port')!='partition 1':
                raise ValueError('CV Training 输入检查失败，拒绝修改')
    if changes:
        ET.indent(doc, space='  ')
        result=ET.tostring(doc,encoding='utf-8',xml_declaration=True)
        ET.fromstring(result)
        return result,changes
    return raw, changes


def capture(folder):
    if not shutil.which('screencapture'):
        print('当前环境无 screencapture，跳过截图')
        return
    labels=[('01_外层流程.png','将 RapidMiner 切换到 Design 外层流程'),
            ('02_交叉验证内部.png','双击 Cross Validation，打开 Training / Testing 子流程'),
            ('03_模型结果.png','运行模型，切换 Results 到 PerformanceVector')]
    print('\n下面进行三张截图：每次先切换到目标界面，再回终端按 Enter。')
    print('截图时用鼠标框选目标区域，完成选区即可保存。按 Esc 可取消该张截图。')
    for filename,prompt in labels:
        input('\n'+prompt+'，按 Enter 开始截取: ')
        dest=folder/filename
        proc=subprocess.run(['screencapture','-i','-x',str(dest)],check=False)
        if proc.returncode==0 and dest.exists():
            print('已保存:',dest)
        else:
            print('本张截图已取消或系统拒绝屏幕录制权限:',filename)


def main():
    parser=argparse.ArgumentParser(description='macOS RapidMiner XML 检查、备份、修复及引导截图')
    parser.add_argument('--root', help='包含五个 .rmp 的文件夹，缺省自动发现')
    parser.add_argument('--no-capture',action='store_true',help='仅检查修复，不启动截图')
    args=parser.parse_args()
    folder=select_folder(args.root)
    stamp=datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
    output=folder/('_RapidMiner_检查与截图_'+stamp)
    output.mkdir(exist_ok=False)
    log={'folder':str(folder),'checked':[],'modified':[],'backup':{},'notes':[]}
    staged=[]
    for filename in EXPECTED:
        path=folder/filename
        if not path.is_file() or path.is_symlink():
            raise RuntimeError('文件不存在或是符号链接: '+str(path))
        new,changes=repair(path.read_bytes(), filename)
        staged.append((path,new,changes))
        log['checked'].append(filename)
    # Only write after all five files pass structural inspection.
    backup_dir=output/'原始文件备份'
    for path,new,changes in staged:
        if new != path.read_bytes():
            backup_dir.mkdir(exist_ok=True)
            saved=backup_dir/path.name
            shutil.copy2(path,saved)
            log['backup'][path.name]=str(saved)
            tmp=path.with_name(path.name+'.repair_tmp')
            try:
                tmp.write_bytes(new)
                ET.parse(tmp)
                tmp.replace(path)
            finally:
                if tmp.exists(): tmp.unlink()
            log['modified'].append({'file':path.name,'changes':changes})
            print('修复:',path.name, '修改项数:',len(changes))
        else:
            print('检查通过，无需修改:',path.name)
    log['notes'].append('静态 XML 检查不代表 RapidMiner 原生执行通过。')
    report=output/'检查记录.json'
    report.write_text(json.dumps(log,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('检查完成:',len(log['checked']),'文件；修改:',len(log['modified']),'文件')
    print('检查与备份路径:',output)
    if not args.no_capture:
        capture(output)
    return 0

if __name__=='__main__':
    try:sys.exit(main())
    except KeyboardInterrupt:
        print('\n已取消')
        sys.exit(130)
    except Exception as ex:
        print('执行失败:',ex,file=sys.stderr)
        sys.exit(1)