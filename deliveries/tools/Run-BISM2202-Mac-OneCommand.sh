#!/bin/bash
set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
  echo '错误：此命令仅用于 macOS 终端。' >&2
  exit 2
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo '错误：未找到 python3，请先安装 Python 3。' >&2
  exit 2
fi
if ! command -v screencapture >/dev/null 2>&1; then
  echo '错误：当前没有 macOS screencapture。' >&2
  exit 2
fi

if [ "\${1:-}" != "" ]; then
  ROOT="$1"
elif [ -d "$PWD/rapidminer" ]; then
  ROOT="$PWD/rapidminer"
else
  ROOT="$PWD"
fi
if [ ! -d "$ROOT" ]; then
  echo "找不到 RapidMiner 文件夹：$ROOT" >&2
  exit 2
fi
ROOT="$(cd "$ROOT" && pwd -P)"
for name in NaiveBayes_CV.rmp NaiveBayes_Full.rmp GradientBoostedTrees_CV.rmp GradientBoostedTrees_Full.rmp BISM2202_A2_rapidminer.rmp; do
  if [ ! -f "$ROOT/$name" ]; then
    echo "缺少 $ROOT/$name；请从包含 rapidminer 的项目目录执行。" >&2
    exit 2
  fi
done

TEMP_SCRIPT="$(mktemp "\${TMPDIR:-/tmp/}bism2202-mac-check.XXXXXX")"
trap 'rm -f "$TEMP_SCRIPT"' EXIT
CHECK_URL='https://raw.githubusercontent.com/lxxlx2/bism2202-a2-datawarehouse-rapidminer/a82ffa696234c981a42840c35c80100e11729bbc/deliveries/tools/Repair-RapidMiner-Mac.py'
if ! curl -fsSL "$CHECK_URL" -o "$TEMP_SCRIPT"; then
  echo '无法下载已审核的 macOS RapidMiner 检查脚本。文件未修改。' >&2
  exit 3
fi

echo "正在检查 Mac 本地 .rmp：$ROOT"
python3 "$TEMP_SCRIPT" --root "$ROOT" --no-capture

PROJECT="$(dirname "$ROOT")"
STAMP="$(date '+%Y%m%d_%H%M%S')"
OUT="$PROJECT/evidence/rapidminer/mac_capture_$STAMP"
mkdir -p "$OUT"
cat <<INFO

已完成本机 XML 检查/修复，原始文件如有修改已自动备份。
注意：学校 RapidMiner 在远程 Windows 的 H: 盘。修复 Mac 文件不会直接修改 H: 盘！
请先在学校 OneDrive 中同步/上传 Mac 的 rapidminer/*.rmp，远程重新打开相应文件并运行。

接下来是截图向导：每一步先把学校远程桌面切换到对应的 RapidMiner 页面，
回 Mac 终端按回车后选择学校软件的窗口或区域；按 Esc 可跳过当前截图。
截图只保存当前真实可见画面，不会自动操作学校远程 RapidMiner。
截图保存位置：$OUT
INFO

STAGES=(
'GBT_01_Overall.png|打开 GradientBoostedTrees_Full.rmp，Design 外层流程（全图）'
'GBT_02_CV_Training.png|双击 Five-Fold Training CV，展示 Training 内层'
'GBT_03_CV_Testing.png|在该 CV 内切换 Testing 内层'
'GBT_04_Fold_Performance.png|运行后 Results 选择 PerformanceVector (Evaluate Folds)'
'GBT_05_Holdout_Performance.png|Results 选择 PerformanceVector (Evaluate Untouched Holdout)，展示混淆矩阵和指标'
'GBT_06_Model.png|Results 选择 GroupedModel/Gradient Boosted Model（如树节点重叠可用 Description）'
'GBT_07_Predictions.png|Results 选择 ExampleSet (Apply Frozen Holdout)，展示预测列'
'NB_01_Overall.png|打开 NaiveBayes_Full.rmp，Design 外层流程（全图）'
'NB_02_CV_Training.png|双击 Five-Fold Training CV，展示 Training 内层'
'NB_03_CV_Testing.png|在该 CV 内切换 Testing 内层'
'NB_04_Fold_Performance.png|运行后 Results 选择 PerformanceVector (Evaluate Folds)'
'NB_05_Holdout_Performance.png|Results 选择 PerformanceVector (Evaluate Untouched Holdout)'
'NB_06_Model.png|Results 选择 Naive Bayes 模型结果'
'NB_07_Predictions.png|Results 选择 ExampleSet (Apply Frozen Holdout)'
)

printf '\n准备截图，输入 s 跳过全部截图，直接回车开始：'
IFS= read -r start || start=s
if [ "$start" = s ] || [ "$start" = S ]; then
  echo "已结束。本机检查目录：$ROOT"
  exit 0
fi
printf '文件名\t状态\n' > "$OUT/截图记录.tsv"
for item in "\${STAGES[@]}"; do
  name="\${item%%|*}"
  instruction="\${item#*|}"
  printf '\n[%s] %s\n按 Enter 进入系统截图选区（输入 q 结束）：' "$name" "$instruction"
  IFS= read -r response || response=q
  if [ "$response" = q ] || [ "$response" = Q ]; then
    break
  fi
  path="$OUT/$name"
  screencapture -i -x "$path" || true
  if [ -s "$path" ]; then
    echo "已保存：$path"
    printf '%s\tSAVED\n' "$name" >> "$OUT/截图记录.tsv"
  else
    echo '本张未保存。请检查 macOS 屏幕录制权限、软件画面及截图选区。'
    printf '%s\tNOT_SAVED\n' "$name" >> "$OUT/截图记录.tsv"
  fi
done
printf '\n完成。证据目录：%s\n' "$OUT"
echo '如果仍有 RapidMiner 红色报错，请保留原始导入/运行报错截图，不能据此认定模型已通过。'
