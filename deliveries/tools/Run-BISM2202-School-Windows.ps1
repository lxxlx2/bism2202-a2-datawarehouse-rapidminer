param([string]$Root = '', [int]$RunSeconds = 150, [switch]$PrepareOnly)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class BismWin32 {
 [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left,Top,Right,Bottom; }
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h,out RECT r);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h,int cmd);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")] public static extern void mouse_event(uint f,uint x,uint y,uint d,UIntPtr e);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h,StringBuilder b,int n);
 [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f,IntPtr l);
 public delegate bool EnumProc(IntPtr h,IntPtr l);
}
'@
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$script:dir = $null
$script:logFile = $null
$script:records = New-Object System.Collections.ArrayList
$script:status = 'NOT_STARTED'
function Note([string]$msg) {
 $line = (Get-Date -Format 'HH:mm:ss')+' '+$msg
 Write-Host $line
 if($script:logFile) { Add-Content -LiteralPath $script:logFile -Value $line -Encoding UTF8 }
}
function Record([string]$code,[string]$kind,[string]$state,[string]$name) {
 [void]$script:records.Add([ordered]@{model=$code;step=$kind;status=$state;file=$name})
 Note ($code+' '+$kind+' '+$state+' '+$name)
}
function Resolve-Project {
 if($Root) {
  $a=Resolve-Path -LiteralPath $Root -ErrorAction Stop
  if((Test-Path -LiteralPath (Join-Path $a.Path 'GradientBoostedTrees_Full.rmp'))){return $a.Path}
  if((Test-Path -LiteralPath (Join-Path $a.Path 'rapidminer\GradientBoostedTrees_Full.rmp'))){return (Join-Path $a.Path 'rapidminer')}
  throw 'The specified Root does not contain rapidminer models.'
 }
 $homePaths=@('H:\','D:\',$env:OneDriveCommercial,$env:OneDrive,(Get-Location).Path)
 foreach($base in $homePaths) {
  if(-not $base -or -not (Test-Path -LiteralPath $base)){continue}
  $dirs=New-Object System.Collections.Queue
  $dirs.Enqueue(@([string]$base,0))
  $seen=@{}
  while($dirs.Count -gt 0){
   $a=$dirs.Dequeue(); $path=[string]$a[0]; $level=[int]$a[1]
   if($seen.ContainsKey($path)){continue};$seen[$path]=$true
   if(Test-Path -LiteralPath (Join-Path $path 'GradientBoostedTrees_Full.rmp') -PathType Leaf) {return $path}
   if($level -ge 5){continue}
   try{$children=@(Get-ChildItem -LiteralPath $path -Directory -ErrorAction Stop)}catch{continue}
   foreach($item in $children){
    if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){continue}
    if($item.Name -match '^(Windows|Program Files|Program Files \(x86\)|ProgramData|Users|AppData|\.git|node_modules)$'){continue}
    if(($level -eq 0) -and ($base -match '^[A-Z]:\\$') -and ($item.Name -notmatch 'BISM|2202|OneDrive|Document|School|Course')){continue}
    $dirs.Enqueue(@($item.FullName,($level+1)))
   }
  }
 }
 throw 'Cannot find GradientBoostedTrees_Full.rmp on H: or available folders.'
}
function Repair([string]$from,[string]$to) {
 $x=New-Object System.Xml.XmlDocument
 $x.PreserveWhitespace=$false
 $x.Load($from)
 $b=$x.SelectSingleNode('/process/operator/process')
 if($null -eq $b){throw 'Invalid RMP body'}
 $split=@($b.SelectNodes('./operator[@class="split_data"]'))
 $cv=@($b.SelectNodes('./operator[@class="x_validation"]'))
 $app=@($b.SelectNodes('./operator[@class="apply_model"]'))
 if($split.Count -ne 1 -or $cv.Count -ne 1 -or $app.Count -ne 1){throw 'Expected exactly one Split, CV and Apply'}
 $ratios=@($split[0].SelectNodes('./enumeration[@key="partitions"]/parameter') | ForEach-Object {$_.GetAttribute('value')})
 if($ratios.Count -ne 2 -or [math]::Abs([double]$ratios[0]-0.75) -gt 0.001 -or [math]::Abs([double]$ratios[1]-0.25) -gt 0.001){throw 'Unexpected partition ratios'}
 $fold=$cv[0].SelectSingleNode('./parameter[@key="number_of_validations"]')
 if($null -eq $fold -or $fold.GetAttribute('value') -ne '5'){throw 'Unexpected CV fold count'}
 $cvName=$cv[0].GetAttribute('name')
 $appName=$app[0].GetAttribute('name')
 $edges=@($b.SelectNodes('./connect'))
 $modelToApply=@($edges | Where-Object {($_.GetAttribute('from_op') -eq $cvName) -and ($_.GetAttribute('from_port') -eq 'model') -and ($_.GetAttribute('to_op') -eq $appName)})
 if($modelToApply.Count -ne 1){throw 'CV model is not connected to Apply Model'}
 $removed=0;$added=0
 foreach($e in $edges){
  if(($e.GetAttribute('from_op') -eq $cvName) -and ($e.GetAttribute('from_port') -eq 'model') -and (-not $e.HasAttribute('to_op')) -and ($e.GetAttribute('to_port') -match '^result [0-9]+$')){
   $target=$e.GetAttribute('to_port');[void]$b.RemoveChild($e);$removed++
   $taken=@($b.SelectNodes('./connect') | Where-Object {-not $_.HasAttribute('to_op') -and $_.GetAttribute('to_port') -eq $target})
   if($taken.Count -eq 0){
    $new=$x.CreateElement('connect');$new.SetAttribute('from_op',$appName);$new.SetAttribute('from_port','model');$new.SetAttribute('to_port',$target)
    [void]$b.AppendChild($new);$added++
   }
  }
 }
 $x.Save($to)
 $test=New-Object System.Xml.XmlDocument;$test.Load($to)
 if(-not $test.SelectSingleNode('/process/operator/process')){throw 'XML roundtrip failed'}
 Note ('RMP_READY '+[IO.Path]::GetFileName($to)+' removed='+$removed+' added='+$added)
}
function Rapid {
 $ps=@(Get-Process -ErrorAction SilentlyContinue | Where-Object {($_.MainWindowHandle -ne [IntPtr]::Zero) -and ($_.MainWindowTitle -match 'RapidMiner|AI Studio')})
 if($ps.Count -eq 0){throw 'RapidMiner Studio must be open on this Windows desktop.'}
 return $ps[0]
}
function Activate {
 $p=Rapid
 [void][BismWin32]::ShowWindow($p.MainWindowHandle,3)
 [void][BismWin32]::SetForegroundWindow($p.MainWindowHandle)
 Start-Sleep -Milliseconds 900
 return $p
}
function Rect {
 $p=Rapid;$r=New-Object BismWin32+RECT
 if(-not [BismWin32]::GetWindowRect($p.MainWindowHandle,[ref]$r)){throw 'Cannot read RapidMiner window rectangle'}
 if(($r.Right-$r.Left) -lt 980 -or ($r.Bottom-$r.Top) -lt 600){throw 'RapidMiner window size is smaller than 980x600'}
 return $r
}
function Click([double]$fx,[double]$fy,[int]$count=1){
 $r=Rect;$w=$r.Right-$r.Left;$h=$r.Bottom-$r.Top
 $xx=$r.Left+[int]($w*$fx);$yy=$r.Top+[int]($h*$fy)
 [void][BismWin32]::SetCursorPos($xx,$yy)
 for($i=0;$i -lt $count;$i++){
  [BismWin32]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
  [BismWin32]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
  Start-Sleep -Milliseconds 130
 }
 Start-Sleep -Milliseconds 500
}
function Key([string]$s){[System.Windows.Forms.SendKeys]::SendWait($s);Start-Sleep -Milliseconds 650}
function Shot([string]$code,[string]$step,[string]$file) {
 $r=Rect;$w=$r.Right-$r.Left;$h=$r.Bottom-$r.Top
 $full=Join-Path $script:dir $file
 $bmp=New-Object System.Drawing.Bitmap($w,$h)
 $graphics=[System.Drawing.Graphics]::FromImage($bmp)
 try{$graphics.CopyFromScreen($r.Left,$r.Top,0,0,$bmp.Size);$bmp.Save($full,[System.Drawing.Imaging.ImageFormat]::Png)}
 finally{$graphics.Dispose();$bmp.Dispose()}
 $size=(Get-Item -LiteralPath $full).Length
 $state='CAPTURED_UNVERIFIED'
 if($size -lt 10000){$state='REVIEW_SMALL_IMAGE'}
 Record $code $step $state $file
}
function ModalTitles {
 $script:foundModals=New-Object System.Collections.ArrayList
 $cb=[BismWin32+EnumProc]{param([IntPtr]$h,[IntPtr]$l)
  if([BismWin32]::IsWindowVisible($h)){
   $s=New-Object System.Text.StringBuilder(350)
   [void][BismWin32]::GetWindowText($h,$s,350)
   if($s.ToString() -match 'Process Import Messages|Errors|Import Messages|License Error') {[void]$script:foundModals.Add($s.ToString())}
  }
  return $true
 }
 [void][BismWin32]::EnumWindows($cb,[IntPtr]::Zero)
 return @($script:foundModals)
}
function TabColor {
 $r=Rect;$x=$r.Left+[int](($r.Right-$r.Left)*0.47);$y=$r.Top+[int](($r.Bottom-$r.Top)*0.096)
 $bmp=New-Object Drawing.Bitmap(1,1)
 $g=[Drawing.Graphics]::FromImage($bmp)
 try {$g.CopyFromScreen($x,$y,0,0,$bmp.Size);return $bmp.GetPixel(0,0).ToArgb()}
 finally {$g.Dispose();$bmp.Dispose()}
}
function Open-Process([string]$file,[string]$code) {
 [void](Activate)
 $saved='';try{$saved=[System.Windows.Forms.Clipboard]::GetText()}catch{}
 try {
  # Ctrl+O is the RapidMiner Open Process shortcut, based on RapidMiner menu resource.
  Key '^o';Start-Sleep -Seconds 2
  [System.Windows.Forms.Clipboard]::SetText($file)
  Key '^a';Key '^v';Key '{ENTER}'
  Start-Sleep -Seconds 5
  $modals=@(ModalTitles)
  if($modals.Count -gt 0){
   Shot $code 'import_warning' ($code+'_00_Import_Warning.png')
   Key '{ESC}'
   Start-Sleep -Milliseconds 350
  }
  $name=[IO.Path]::GetFileNameWithoutExtension($file)
  $title=(Rapid).MainWindowTitle
  if($title -notmatch [regex]::Escape($name)){
   Note 'Ctrl+O did not open target RMP. Trying File > Import Process.'
   [void](Activate)
   Key '{ESC}';Key '%f';Key 'm';Start-Sleep -Seconds 2
   [System.Windows.Forms.Clipboard]::SetText($file)
   Key '^a';Key '^v';Key '{ENTER}';Start-Sleep -Seconds 5
   $m=@(ModalTitles)
   if($m.Count -gt 0){Shot $code 'import_warning_retry' ($code+'_00_Import_Warning_Retry.png');Key '{ESC}'}
   $title=(Rapid).MainWindowTitle
   if($title -notmatch [regex]::Escape($name)){
    Shot $code 'import_failed' ($code+'_00_Import_Failed.png')
    Record $code 'open' 'NOT_VERIFIED' $title
    return $false
   }
  }
  Record $code 'open' 'WINDOW_TITLE_MATCH' $name
  return $true
 }finally{try{[System.Windows.Forms.Clipboard]::SetText($saved)}catch{}}
}
function Design { [void](Activate); Click 0.38 0.085 }
function Results { [void](Activate); Click 0.47 0.085 }
function Run-Model([string]$code,[string]$path){
 Note ('BEGIN_MODEL '+$code)
 if(-not (Open-Process $path $code)){return}
 Design;Start-Sleep -Seconds 1
 Click 0.645 0.17
 Start-Sleep -Milliseconds 700
 Shot $code 'design' ($code+'_01_Process_Overview.png')
 # A full CV flow should be around the 70% portion of the editor after auto-fit.
 # Probe a double click and capture; contents must still be visually verified.
 Click 0.56 0.29 2
 Shot $code 'cv_probe' ($code+'_02_CV_Training_Check.png')
 Click 0.59 0.20
 Shot $code 'cv_other_probe' ($code+'_03_CV_Testing_Check.png')
 Key '{ESC}';Design;Start-Sleep -Seconds 1
 if($PrepareOnly){Record $code 'run' 'SKIPPED_PREPARE_ONLY' '';return}
 # The 10.3 Run Process Locally toolbar button is near x=0.15,y=0.085.
 $tabBefore=TabColor
 Click 0.152 0.085
 Record $code 'run' 'REQUESTED_NOT_VERIFIED' ''
 $end=(Get-Date).AddSeconds($RunSeconds)
 $tabChanged=0
 while((Get-Date) -lt $end){
  Start-Sleep -Seconds 5
  $m=@(ModalTitles)
  if($m.Count -gt 0){Shot $code 'runtime_dialog' ($code+'_09_Runtime_Dialog.png');Record $code 'run' 'DIALOG_DETECTED' ($m -join '|');return}
  if((TabColor) -ne $tabBefore){$tabChanged++} else {$tabChanged=0}
  if($tabChanged -ge 3){Note 'Results tab color changed; capturing UI (not proof of training completion).';break}
 }
 Results;Start-Sleep -Seconds 2
 Shot $code 'results_overview' ($code+'_04_Results_Overview.png')
 # The following are best-effort result tab selections in known 10.3 layout.
 $tabs=@(
  @{name='05_Holdout_Performance'; x=0.30; y=0.13},
  @{name='06_CV_Performance'; x=0.77; y=0.13},
  @{name='07_Trained_Model'; x=0.29; y=0.175},
  @{name='08_Prediction_Table'; x=0.76; y=0.175}
 )
 foreach($t in $tabs){
  Click $t.x $t.y
  Shot $code 'result_tab_probe' ($code+'_'+$t.name+'.png')
 }
 Record $code 'run' 'RESULT_CAPTURED_NATIVE_SUCCESS_UNVERIFIED' ''
}
try {
 if([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT){throw 'Run only in the school Windows desktop, not macOS Terminal.'}
 $source=Resolve-Project
 $project=Split-Path -Parent $source
 $script:dir=Join-Path $project ('evidence\rapidminer\run_'+$stamp)
 $ready=Join-Path $script:dir 'ready_rmp'
 [void](New-Item -Path $ready -ItemType Directory -Force)
 $script:logFile=Join-Path $script:dir 'execution.log'
 Note ('SOURCE='+$source)
 Note ('OUTPUT='+$script:dir)
 $models=@(@{code='GBT';file='GradientBoostedTrees_Full.rmp'},@{code='NB';file='NaiveBayes_Full.rmp'})
 foreach($m in $models){
  $src=Join-Path $source $m.file
  if(-not (Test-Path -LiteralPath $src -PathType Leaf)){throw ('Missing source RMP '+$src)}
  Copy-Item -LiteralPath $src -Destination (Join-Path $script:dir ('ORIGINAL_'+$m.file))
  Repair $src (Join-Path $ready $m.file)
 }
 $inputData=Join-Path $source 'data'
 if(-not (Test-Path -LiteralPath $inputData -PathType Container)){throw 'Missing data subfolder'}
 $csv=@(Get-ChildItem -LiteralPath $inputData -File -Filter '*.csv')
 if($csv.Count -lt 1){throw 'Missing teacher CSV in rapidminer/data'}
 Copy-Item -LiteralPath $inputData -Destination $ready -Recurse -Force
 $sourceHash=(Get-FileHash -LiteralPath $csv[0].FullName -Algorithm SHA256).Hash
 Note ('TEACHER_CSV_SHA256='+$sourceHash)
 [void](Activate)
 foreach($m in $models){
  try{Run-Model $m.code (Join-Path $ready $m.file)}
  catch{Record $m.code 'model' 'ERROR' $_.Exception.Message}
 }
 $state='PARTIAL_GUI_CAPTURE_ONLY'
 $manifest=[ordered]@{state=$state;time=$stamp;school_windows=$env:COMPUTERNAME;source=$source;source_csv_sha256=$sourceHash;items=@($script:records);note='Raw screenshots are unverified GUI captures. No native success is asserted without machine-readable results.'}
 $manifest | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath (Join-Path $script:dir 'manifest.json') -Encoding UTF8
 $zip=Join-Path $project ('BISM2202_RapidMiner_Evidence_'+$stamp+'.zip')
 Compress-Archive -Path (Join-Path $script:dir '*') -DestinationPath $zip -Force
 Note ('ZIP='+$zip)
 $destination=$env:OneDriveCommercial
 if(-not $destination){$destination=$env:OneDrive}
 if($destination -and (Test-Path -LiteralPath $destination -PathType Container)){
  $target=Join-Path $destination 'BISM2202_Evidence'
  [void](New-Item -Path $target -ItemType Directory -Force)
  Copy-Item -LiteralPath $zip -Destination $target -Force
  Note ('ONEDRIVE_LOCAL_COPY='+$target)
  Note 'ONEDRIVE_CLOUD_SYNC_UNVERIFIED'
 } else {Note 'NO_ONEDRIVE_LOCAL_SYNC_FOLDER: ZIP remains in project directory'}
 Note 'FINISHED: all screenshots must be content-reviewed; run success is unverified.'
} catch {
 $msg='FATAL '+$_.Exception.Message
 Write-Host $msg -ForegroundColor Red
 if($script:logFile){Add-Content -LiteralPath $script:logFile -Value $msg -Encoding UTF8}
 exit 1
}