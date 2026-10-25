param([string]$Root = '',[switch]$SkipScreenshots)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$script:logFile = $null
$script:report = New-Object 'System.Collections.Generic.List[string]'
function Write-Log([string]$message) {
  Write-Host $message
  [void]$script:report.Add($message)
  if ($script:logFile) { Add-Content -LiteralPath $script:logFile -Value $message -Encoding UTF8 }
}
function Locate-Folder {
  $seeds = New-Object 'System.Collections.Generic.List[string]'
  if ($Root) { $seeds.Add($Root) }
  $seeds.Add((Get-Location).Path)
  foreach ($p in @('H:\','D:\','C:\', $env:OneDrive, $env:OneDriveCommercial, (Join-Path $env:USERPROFILE 'Downloads'))) {
    if ($p -and (Test-Path -LiteralPath $p -PathType Container)) { $seeds.Add($p) }
  }
  $visited = @{}
  foreach ($seed in $seeds) {
    if (-not (Test-Path -LiteralPath $seed -PathType Container)) { continue }
    $q=New-Object System.Collections.Queue
    $q.Enqueue(@($seed,0))
    while ($q.Count -gt 0) {
      $node=$q.Dequeue();$p=[string]$node[0];$depth=[int]$node[1]
      try { $real=(Resolve-Path -LiteralPath $p).Path } catch { continue }
      if ($visited.ContainsKey($real.ToLowerInvariant())) { continue }
      $visited[$real.ToLowerInvariant()]=$true
      if ((Test-Path -LiteralPath (Join-Path $real 'NaiveBayes_Full.rmp') -PathType Leaf) -and
          (Test-Path -LiteralPath (Join-Path $real 'GradientBoostedTrees_Full.rmp') -PathType Leaf)) { return $real }
      if ($depth -ge 5) { continue }
      try { $kids = @(Get-ChildItem -LiteralPath $real -Directory -ErrorAction Stop) } catch { continue }
      foreach ($child in $kids) {
        if ($child.Name -match '^(Windows|Program Files|ProgramData|AppData|\.git|node_modules|\.venv|Library)$') { continue }
        if ($depth -eq 0 -and $seed -match '^[A-Z]:\\$' -and $child.Name -notmatch 'BISM|2202|OneDrive|Document|Users|同事|副本|作业') { continue }
        if ($child.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
        $q.Enqueue(@($child.FullName,$depth+1))
      }
    }
  }
  throw '未找到 NaiveBayes_Full.rmp 和 GradientBoostedTrees_Full.rmp。请在项目 rapidminer 文件夹打开 PowerShell 后重新运行。'
}
function Connect-Exists($process,[string]$fromOp,[string]$fromPort,[string]$toOp,[string]$toPort) {
  foreach ($c in @($process.SelectNodes('./connect'))) {
    if ($c.GetAttribute('from_op') -eq $fromOp -and $c.GetAttribute('from_port') -eq $fromPort -and
        $c.GetAttribute('to_op') -eq $toOp -and $c.GetAttribute('to_port') -eq $toPort) { return $true }
  }
  return $false
}
function Add-Wire($doc,$process,[string]$fromOp,[string]$fromPort,[string]$toOp,[string]$toPort) {
  if (Connect-Exists $process $fromOp $fromPort $toOp $toPort) { return }
  foreach ($c in @($process.SelectNodes('./connect'))) {
    if ($c.GetAttribute('from_op') -eq $fromOp -and $c.GetAttribute('from_port') -eq $fromPort) {
      throw "连接冲突: $fromOp.$fromPort 已连接到 $($c.GetAttribute('to_op')).$($c.GetAttribute('to_port'))"
    }
  }
  $c=$doc.CreateElement('connect')
  if ($fromOp) { $c.SetAttribute('from_op',$fromOp) }
  $c.SetAttribute('from_port',$fromPort)
  if ($toOp) { $c.SetAttribute('to_op',$toOp) }
  $c.SetAttribute('to_port',$toPort)
  [void]$process.AppendChild($c)
  $script:changes++
}
function Fix-Rmp([string]$file,[string]$dest) {
  $doc=New-Object System.Xml.XmlDocument
  $doc.PreserveWhitespace=$true
  $doc.Load($file)
  $body=$doc.SelectSingleNode('/process/operator/process')
  if (-not $body) { throw "RMP 结构不正确: $file" }
  $filename=[IO.Path]::GetFileName($file)
  $isMain=($filename -eq 'BISM2202_A2_rapidminer.rmp')
  $isFull=$isMain -or ($filename -match '_Full\.rmp$')
  $cvs=@($body.SelectNodes('./operator[@class="x_validation"]'))
  $splits=@($body.SelectNodes('./operator[@class="split_data"]'))
  $n=if($isMain){2}else{1}
  if ($cvs.Count -ne $n -or $splits.Count -ne $n) { throw "${filename}: 预期 $n 个 Split/CV，实际 $($splits.Count)/$($cvs.Count)" }
  $script:changes=0
  for($i=0;$i -lt $n;$i++) {
    $cv=$cvs[$i];$split=$splits[$i]
    $cvName=$cv.GetAttribute('name');$splitName=$split.GetAttribute('name')
    $parts=@($split.SelectNodes('./enumeration[@key="partitions"]/parameter'))
    $ratios=@($parts | ForEach-Object {$_.GetAttribute('value')})
    if ($ratios.Count -ne 2 -or $ratios[0] -ne '0.75' -or $ratios[1] -ne '0.25') { throw "${filename}: 划分比例异常，拒绝自动改变实验设计" }
    $fold=$cv.SelectSingleNode('./parameter[@key="number_of_validations"]')
    if (-not $fold -or $fold.GetAttribute('value') -ne '5') { throw "${filename}: 交叉验证不是5折，拒绝改变实验设计" }
    if (-not (Connect-Exists $body $splitName 'partition 1' $cvName 'training')) { throw "${filename}: 训练集未进入 CV，拒绝自动推断线路" }
    $cvSub=@($cv.SelectNodes('./process'))
    if($cvSub.Count -ne 2){throw "${filename}: CV Training/Testing 子流程不完整"}
    if (-not $isFull) { continue }
    $prefix=if($isMain){if($i -eq 0){'NB '}else{'GBT '}}else{''}
    $apps=@($body.SelectNodes('./operator[@class="apply_model"]') | Where-Object {$_.GetAttribute('name').StartsWith($prefix)})
    $perfs=@($body.SelectNodes('./operator[@class="performance_binominal_classification"]') | Where-Object {$_.GetAttribute('name').StartsWith($prefix)})
    if($apps.Count -ne 1 -or $perfs.Count -ne 1){throw "${filename}: Apply Model 或 Performance 不唯一"}
    $appName=$apps[0].GetAttribute('name');$perfName=$perfs[0].GetAttribute('name')
    if(-not (Connect-Exists $body $splitName 'partition 2' $appName 'unlabelled data')){throw "${filename}: 测试集连接异常"}
    if(-not (Connect-Exists $body $appName 'labelled data' $perfName 'labelled data')){throw "${filename}: 测试性能连接异常"}
    # RapidMiner 10.3 may reject an extra CV.model -> Process.result connection on import.
    # Preserve CV.model -> Apply Model.model; route optional displayed model from Apply Model.model instead.
    $rootModelPorts=New-Object 'System.Collections.Generic.List[string]'
    foreach ($w in @($body.SelectNodes('./connect'))) {
      if($w.GetAttribute('from_op') -eq $cvName -and $w.GetAttribute('from_port') -eq 'model' -and
         -not $w.HasAttribute('to_op') -and $w.GetAttribute('to_port') -match '^result [0-9]+$') {
         $rootModelPorts.Add($w.GetAttribute('to_port'));[void]$body.RemoveChild($w);$script:changes++
      }
    }
    Add-Wire $doc $body $cvName 'model' $appName 'model'
    foreach($outPort in $rootModelPorts) {
      if(-not (Connect-Exists $body $appName 'model' '' $outPort)) {
        # If another user-supplied connection already occupies the model output, avoid a destructive repair.
        Add-Wire $doc $body $appName 'model' '' $outPort
      }
    }
  }
  # Count dangling root-result wires and invalid duplicate target ports.
  $targets=@{}
  foreach($w in @($body.SelectNodes('./connect'))) {
    if(-not $w.HasAttribute('to_op') -and $w.GetAttribute('to_port') -match '^result ') {
      $k=$w.GetAttribute('to_port')
      if($targets.ContainsKey($k)){throw "${filename}: 结果端口 $k 被重复占用"}
      $targets[$k]=$true
    }
  }
  $doc.Save($dest)
  $v=New-Object System.Xml.XmlDocument;$v.Load($dest)
  Write-Log ("XML_OK {0}: 已生成修订副本; 修复连接 {1} 处" -f $filename,$script:changes)
}
function Capture([string]$outfile) {
  $wins=@(Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $_.MainWindowHandle -ne [IntPtr]::Zero -and $_.MainWindowTitle -match 'RapidMiner|AI Studio'
  })
  if($wins.Count -eq 0) { Write-Log "CAPTURE_FAIL $outfile 未找到 RapidMiner 窗口";return $false }
  $app=$wins[0]
  if(-not ('Bism2202Win' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Bism2202Win {
 [StructLayout(LayoutKind.Sequential)] public struct Rect {public int L,T,R,B;}
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h,out Rect r);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h,int c);
}
'@
  }
  Add-Type -AssemblyName System.Drawing
  [void][Bism2202Win]::ShowWindow($app.MainWindowHandle,9)
  [void][Bism2202Win]::SetForegroundWindow($app.MainWindowHandle)
  Start-Sleep -Milliseconds 1100
  $r=New-Object Bism2202Win+Rect
  if(-not [Bism2202Win]::GetWindowRect($app.MainWindowHandle,[ref]$r)) { Write-Log "CAPTURE_FAIL $outfile 不能获取窗口位置";return $false }
  $w=$r.R-$r.L;$h=$r.B-$r.T
  if($w -lt 500 -or $h -lt 350){Write-Log "CAPTURE_FAIL $outfile 窗口尺寸异常";return $false}
  $bmp=New-Object System.Drawing.Bitmap -ArgumentList $w,$h
  $g=[System.Drawing.Graphics]::FromImage($bmp)
  try{$g.CopyFromScreen($r.L,$r.T,0,0,$bmp.Size);$bmp.Save($outfile,[System.Drawing.Imaging.ImageFormat]::Png)}
  finally{$g.Dispose();$bmp.Dispose()}
  Write-Log ("CAPTURE_SAVED " + $outfile)
  return $true
}
function Capture-Guide([string]$name,[string]$instruction,[string]$outDir) {
  Write-Host "`n[$name] $instruction" -ForegroundColor Cyan
  $ans=Read-Host '切到 RapidMiner 对应页面后按 Enter 截图，输入 S 跳过'
  if($ans -match '^[Ss]$'){Write-Log "CAPTURE_SKIPPED $name";return}
  [void](Capture (Join-Path $outDir ($name+'.png')))
}
try {
  $folder=Locate-Folder
  $project=Split-Path -Parent $folder
  $runDir=Join-Path $folder ('_自动整理_' + $stamp)
  $ready=Join-Path $runDir 'ready_rmp'
  $shots=Join-Path $project ('evidence\rapidminer\auto_' + $stamp)
  [void](New-Item -ItemType Directory -Force -Path $ready,$shots)
  $script:logFile=Join-Path $runDir '执行记录.txt'
  Write-Log "SOURCE=$folder"
  Write-Log "READY=$ready"
  Write-Log "SCREENSHOTS=$shots"
  $names=@('NaiveBayes_CV.rmp','NaiveBayes_Full.rmp','GradientBoostedTrees_CV.rmp','GradientBoostedTrees_Full.rmp','BISM2202_A2_rapidminer.rmp')
  foreach($name in $names) {
    $from=Join-Path $folder $name
    if(-not (Test-Path -LiteralPath $from -PathType Leaf)){throw "缺少必要文件 $from"}
    Fix-Rmp $from (Join-Path $ready $name)
  }
  $sourceData=Join-Path $folder 'data'
  if(Test-Path -LiteralPath $sourceData -PathType Container) {
    Copy-Item -LiteralPath $sourceData -Destination $ready -Recurse -Force
  }
  $csv=@(Get-ChildItem -LiteralPath (Join-Path $ready 'data') -Filter '*.csv' -File -ErrorAction SilentlyContinue)
  if($csv.Count -eq 0) { Write-Log 'INPUT_BLOCKED: ready_rmp/data 缺少 CSV。将老师的原始贷款 CSV 放到 ready_rmp/data 后再执行模型。' }
  else { Write-Log ("CSV_FOUND="+$csv[0].FullName) }
  foreach($name in $names){$p=Join-Path $ready $name; Write-Log ("SHA256 "+$name+" "+(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash)}
  Write-Log 'RMP_REPAIR_PREPARED: 已生成独立修复副本，原文件未修改。GUI 导入、训练结果仍需在软件中验证。'
  if(-not $SkipScreenshots){
    foreach($model in @('GradientBoostedTrees','NaiveBayes')){
      $file=Join-Path $ready ($model+'_Full.rmp')
      Write-Host "`n=== $model ===" -ForegroundColor Yellow
      Write-Host "在 RapidMiner 10.3 使用 File > Import Process 打开：$file" -ForegroundColor Yellow
      $go=Read-Host '确认已打开该修复副本，按 Enter 继续；输入 S 跳过此模型'
      if($go -match '^[Ss]$'){Write-Log "MODEL_SKIPPED $model";continue}
      $pre=if($model -eq 'GradientBoostedTrees'){'GBT'}else{'NB'}
      Capture-Guide ($pre+'_01_Overall') 'Design：外层流程完整显示 Split Data、Five-Fold Training CV、Apply Model 和 Performance' $shots
      Capture-Guide ($pre+'_02_CV_Training') 'Design：双击 Five-Fold Training CV，选 Training 子流程，完整显示预处理和训练算法' $shots
      Capture-Guide ($pre+'_03_CV_Testing') 'Design：在 CV 里选 Testing 子流程，完整显示 Apply Model 和 Performance' $shots
      Write-Host '回到最外层，点击 Run（三角形）；必须等待 RapidMiner 本身运行完成并出现 Results。' -ForegroundColor Yellow
      Capture-Guide ($pre+'_04_Fold_Performance') 'Results：点击 PerformanceVector (Evaluate Folds) 的性能表' $shots
      Capture-Guide ($pre+'_05_Holdout_Performance') 'Results：点击 PerformanceVector (Evaluate Untouched Holdout) 的独立测试性能与混淆矩阵' $shots
      Capture-Guide ($pre+'_06_Model') 'Results：打开模型 Description/Graph，保证关键节点可读' $shots
      Capture-Guide ($pre+'_07_Predictions') 'Results：打开 ExampleSet (Apply Frozen Holdout)，显示 prediction 与 confidence' $shots
      Write-Log "MODEL_SCREENSHOT_GUIDE_FINISHED=$model；请核对图片实际内容，不能把自动截图视为原生运行成功。"
    }
  }
  Write-Log 'SSIS_SQL_STAGE: 需要学校 Windows 安装 SQL Server 2022 + SSIS SDK、恢复老师原始数据库并运行 ETL。此脚本未运行或更改数据库。'
  Write-Log 'FINISHED: 文件检查和截图向导已结束。请打开执行记录查看 SKIPPED/FAIL 项。'
  Write-Host "`n文件已整理：$runDir`n截图保存：$shots" -ForegroundColor Green
  exit 0
} catch {
  $msg='FAILED: '+$_.Exception.Message
  Write-Host $msg -ForegroundColor Red
  if($script:logFile){Add-Content -LiteralPath $script:logFile -Value $msg -Encoding UTF8}
  exit 1
}