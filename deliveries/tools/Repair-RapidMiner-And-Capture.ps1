param(
  [string]$Root = '',
  [switch]$SkipCapture
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$script:LogPath = $null
$script:Output = $null
$script:Stamp = $null

function Log([string]$message) {
  Write-Host $message
  if ($script:LogPath) { Add-Content -LiteralPath $script:LogPath -Value $message -Encoding UTF8 }
}

function Find-RapidMinerFolder {
  $roots = New-Object 'System.Collections.Generic.List[string]'
  if ($Root) { $roots.Add($Root) }
  $roots.Add((Get-Location).Path)
  foreach ($drive in @('H:\', 'D:\', 'C:\')) {
    if (-not (Test-Path -LiteralPath $drive)) { continue }
    Get-ChildItem -LiteralPath $drive -Directory -ErrorAction SilentlyContinue | Where-Object {
      $_.Name -match 'BISM2202'
    } | ForEach-Object { $roots.Add($_.FullName) }
  }
  $downloads = Join-Path $env:USERPROFILE 'Downloads'
  if (Test-Path -LiteralPath $downloads) {
    Get-ChildItem -LiteralPath $downloads -Directory -ErrorAction SilentlyContinue | Where-Object {
      $_.Name -match 'BISM2202'
    } | ForEach-Object { $roots.Add($_.FullName) }
  }
  $seen = @{}
  foreach ($rootPath in $roots) {
    if (-not (Test-Path -LiteralPath $rootPath)) { continue }
    $item = Get-Item -LiteralPath $rootPath
    if (-not $item.PSIsContainer) { $item = $item.Directory }
    if ($seen.ContainsKey($item.FullName.ToLowerInvariant())) { continue }
    $seen[$item.FullName.ToLowerInvariant()] = $true
    $files = @(Get-ChildItem -LiteralPath $item.FullName -File -Filter '*.rmp' -Recurse -ErrorAction SilentlyContinue)
    $groups = @($files | Group-Object DirectoryName)
    foreach ($g in $groups) {
      $names = @($g.Group | ForEach-Object { $_.Name })
      if ($names -contains 'NaiveBayes_Full.rmp' -and $names -contains 'GradientBoostedTrees_Full.rmp') {
        return $g.Group[0].Directory.FullName
      }
    }
  }
  throw '找不到两个 Full.rmp。请先解压交付包，再在 rapidminer 文件夹内运行命令，或指定 -Root 文件夹路径。'
}

function ParamValue($node, [string]$key) {
  $p = $node.SelectSingleNode('./parameter[@key="' + $key + '"]')
  if ($null -eq $p) { return '' }
  return $p.GetAttribute('value')
}
function EnsureParam($doc, $node, [string]$key, [string]$value) {
  $p = $node.SelectSingleNode('./parameter[@key="' + $key + '"]')
  if ($null -eq $p) {
    $p = $doc.CreateElement('parameter'); $p.SetAttribute('key',$key)
    [void]$node.AppendChild($p)
  }
  if ($p.GetAttribute('value') -ne $value) { $p.SetAttribute('value', $value); $script:Edits++ }
}
function Connections($proc, [string]$source, [string]$fromPort) {
  $out = New-Object System.Collections.ArrayList
  foreach ($c in $proc.SelectNodes('./connect')) {
    if ($c.GetAttribute('from_op') -eq $source -and $c.GetAttribute('from_port') -eq $fromPort) {
      [void]$out.Add($c)
    }
  }
  return @($out.ToArray())
}
function EnsureWire($doc, $proc, [string]$source, [string]$fromPort, [string]$target, [string]$toPort) {
  $matches = @(Connections $proc $source $fromPort)
  if ($matches.Count -eq 1 -and $matches[0].GetAttribute('to_op') -eq $target -and $matches[0].GetAttribute('to_port') -eq $toPort) { return }
  foreach ($c in $matches) { [void]$proc.RemoveChild($c) }
  $c = $doc.CreateElement('connect')
  if ($source) { $c.SetAttribute('from_op',$source) }
  $c.SetAttribute('from_port',$fromPort)
  if ($target) { $c.SetAttribute('to_op',$target) }
  $c.SetAttribute('to_port',$toPort)
  [void]$proc.AppendChild($c)
  $script:Edits++
}
function Repair-Rmp([System.IO.FileInfo]$file) {
  $doc = New-Object System.Xml.XmlDocument
  $doc.PreserveWhitespace = $true
  $doc.Load($file.FullName)
  $proc = $doc.SelectSingleNode('/process/operator/process')
  if ($null -eq $proc) { throw "$($file.Name): 找不到主流程" }
  $splits = @($proc.SelectNodes('./operator[@class="split_data"]'))
  $cvs = @($proc.SelectNodes('./operator[@class="x_validation"]'))
  $allName = 'BISM2202_A2_rapidminer.rmp'
  $fullNames = @($allName, 'NaiveBayes_Full.rmp', 'GradientBoostedTrees_Full.rmp')
  $expected = if ($file.Name -eq $allName) { 2 } else { 1 }
  if ($splits.Count -ne $expected -or $cvs.Count -ne $expected) {
    throw "$($file.Name): Split/CV 数量不符合预期，已停止安全修复"
  }
  $script:Edits = 0
  for ($i=0; $i -lt $expected; $i++) {
    $split = $splits[$i]; $cv = $cvs[$i]
    EnsureParam $doc $split 'sampling_type' 'stratified sampling'
    EnsureParam $doc $split 'use_local_random_seed' 'true'
    EnsureParam $doc $split 'local_random_seed' '73421'
    $enum = $split.SelectSingleNode('./enumeration[@key="partitions"]')
    if ($null -eq $enum) { $enum=$doc.CreateElement('enumeration');$enum.SetAttribute('key','partitions');[void]$split.AppendChild($enum);$script:Edits++ }
    $ratios = @($enum.SelectNodes('./parameter'))
    if ($ratios.Count -ne 2 -or $ratios[0].GetAttribute('value') -ne '0.75' -or $ratios[1].GetAttribute('value') -ne '0.25') {
      foreach ($child in @($enum.ChildNodes)) { [void]$enum.RemoveChild($child) }
      foreach ($v in @('0.75','0.25')) { $p=$doc.CreateElement('parameter');$p.SetAttribute('key','ratio');$p.SetAttribute('value',$v);[void]$enum.AppendChild($p) }
      $script:Edits++
    }
    EnsureParam $doc $cv 'number_of_validations' '5'
    EnsureParam $doc $cv 'sampling_type' 'stratified sampling'
    EnsureParam $doc $cv 'use_local_random_seed' 'true'
    EnsureParam $doc $cv 'local_random_seed' '74219'
    EnsureParam $doc $cv 'create_complete_model' 'true'
    $splitName=$split.GetAttribute('name');$cvName=$cv.GetAttribute('name')
    EnsureWire $doc $proc $splitName 'partition 1' $cvName 'training'
    $subs = @($cv.SelectNodes('./process'))
    if ($subs.Count -ne 2) { throw "$($file.Name): CV 内层必须有 Training/Testing 两个子流程" }
    $test=$subs[1]; $apply = @($test.SelectNodes('./operator[@class="apply_model"]')); $perf=@($test.SelectNodes('./operator[@class="performance_binominal_classification"]'))
    if ($apply.Count -ne 1 -or $perf.Count -ne 1) { throw "$($file.Name): CV Testing 算子不完整，已停止" }
    EnsureWire $doc $test '' 'model' $apply[0].GetAttribute('name') 'model'
    EnsureWire $doc $test '' 'test set' $apply[0].GetAttribute('name') 'unlabelled data'
    EnsureWire $doc $test $apply[0].GetAttribute('name') 'labelled data' $perf[0].GetAttribute('name') 'labelled data'
    if ($fullNames -contains $file.Name) {
      $prefix = if ($file.Name -eq $allName) { if ($i -eq 0) {'NB '} else {'GBT '} } else { '' }
      $outerApps=@($proc.SelectNodes('./operator[@class="apply_model"]') | Where-Object { $_.GetAttribute('name').StartsWith($prefix) })
      $outerPerf=@($proc.SelectNodes('./operator[@class="performance_binominal_classification"]') | Where-Object { $_.GetAttribute('name').StartsWith($prefix) })
      if ($outerApps.Count -ne 1 -or $outerPerf.Count -ne 1) { throw "$($file.Name): Holdout 模型/评估算子不唯一，无法安全修复" }
      $appName=$outerApps[0].GetAttribute('name');$perfName=$outerPerf[0].GetAttribute('name')
      # 将 CV.model 的额外结果连接转移到 Apply Model 的模型透传端口。
      foreach ($wire in @(Connections $proc $cvName 'model')) {
        if ($wire.GetAttribute('to_op') -eq '' -and $wire.GetAttribute('to_port') -like 'result *') {
          $wire.SetAttribute('from_op',$appName);$script:Edits++
        }
      }
      EnsureWire $doc $proc $cvName 'model' $appName 'model'
      EnsureWire $doc $proc $splitName 'partition 2' $appName 'unlabelled data'
      EnsureWire $doc $proc $appName 'labelled data' $perfName 'labelled data'
    }
  }
  if ($script:Edits -gt 0) {
    $backup = $file.FullName + '.pre_fix_' + $script:Stamp + '.bak'
    Copy-Item -LiteralPath $file.FullName -Destination $backup -ErrorAction Stop
    $doc.Save($file.FullName)
    # 保存后重新读入确认 XML 可用。
    $verify = New-Object System.Xml.XmlDocument
    $verify.Load($file.FullName)
    Log ("已修复: {0}; 修改 {1} 项; 备份 {2}" -f $file.Name,$script:Edits,$backup)
  } else { Log ("已检查: {0}; 无须修改" -f $file.Name) }
}

function Capture-RapidMiner([string]$filename) {
  $candidates=@(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero -and $_.MainWindowTitle -match 'RapidMiner|AI Studio' })
  if ($candidates.Count -eq 0) { Log '未发现 RapidMiner 窗口，截图未生成。请先打开 RapidMiner。'; return $false }
  $app=$candidates[0]
  if (-not ('RMWin32' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class RMWin32 {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
}
'@
  }
  Add-Type -AssemblyName System.Drawing
  [void][RMWin32]::ShowWindow($app.MainWindowHandle,9)
  [void][RMWin32]::SetForegroundWindow($app.MainWindowHandle)
  Start-Sleep -Milliseconds 900
  $rect=New-Object RMWin32+RECT
  if (-not [RMWin32]::GetWindowRect($app.MainWindowHandle,[ref]$rect)) { throw '获取 RapidMiner 窗口边界失败' }
  $w=$rect.Right-$rect.Left;$h=$rect.Bottom-$rect.Top
  if ($w -lt 200 -or $h -lt 200) { throw 'RapidMiner 窗口尺寸过小，请先最大化' }
  $bitmap=New-Object System.Drawing.Bitmap -ArgumentList $w,$h
  $graphics=[System.Drawing.Graphics]::FromImage($bitmap)
  try { $graphics.CopyFromScreen($rect.Left,$rect.Top,0,0,$bitmap.Size);$bitmap.Save((Join-Path $script:Output $filename),[System.Drawing.Imaging.ImageFormat]::Png) }
  finally { $graphics.Dispose();$bitmap.Dispose() }
  Log ('已截图: ' + (Join-Path $script:Output $filename))
  return $true
}

try {
  $folder=Find-RapidMinerFolder
  $script:Stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
  $script:Output=Join-Path $folder ('_RapidMiner_检查与截图_' + $script:Stamp)
  New-Item -ItemType Directory -Force -Path $script:Output | Out-Null
  $script:LogPath=Join-Path $script:Output '检查记录.txt'
  Log ('项目目录: '+$folder)
  $names=@('NaiveBayes_CV.rmp','NaiveBayes_Full.rmp','GradientBoostedTrees_CV.rmp','GradientBoostedTrees_Full.rmp','BISM2202_A2_rapidminer.rmp')
  foreach ($name in $names) {
    $file=Get-Item -LiteralPath (Join-Path $folder $name) -ErrorAction Stop
    Repair-Rmp $file
  }
  Log 'RMP 静态检查及必要修复已完成。注意：此步骤不执行训练，也不判断界面黄色警告的实际原因。'
  if (-not $SkipCapture) {
    Log '截图前请关闭 RapidMiner 中已经打开的旧流程标签；如果它处于未保存状态，请确认是否保留你的手工修改，然后重新打开磁盘上的修复版 RMP。'
    [void](Read-Host '在 RapidMiner 中打开 Full.rmp，切到 Design 外层流程并最大化窗口，按 Enter 截图')
    if (-not (Capture-RapidMiner '01_Design_外层流程.png')) { throw '未能捕获 RapidMiner 窗口' }
    [void](Read-Host '双击 Cross Validation，展示 Training 和 Testing 子流程，按 Enter 截图')
    if (-not (Capture-RapidMiner '02_CV_内层流程.png')) { throw '未能捕获 RapidMiner 窗口' }
    [void](Read-Host '运行模型并打开 Results 窗口，选中 PerformanceVector，按 Enter 截图')
    if (-not (Capture-RapidMiner '03_Results_指标.png')) { throw '未能捕获 RapidMiner 窗口' }
  }
  Log ('完成。检查记录和截图位于: '+$script:Output)
  exit 0
} catch {
  $m='执行失败: '+$_.Exception.Message
  Write-Host $m -ForegroundColor Red
  if ($script:LogPath) { Add-Content -LiteralPath $script:LogPath -Value $m -Encoding UTF8 }
  exit 1
}