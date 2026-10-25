param([string]$Root = '', [int]$OpenTimeoutSeconds=55, [int]$RunTimeoutSeconds=85)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class BismWindow {
 [StructLayout(LayoutKind.Sequential)]
 public struct RECT { public int Left,Top,Right,Bottom; }
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")] public static extern void mouse_event(uint flag,uint x,uint y,uint z,UIntPtr extra);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h,StringBuilder b,int size);
 [DllImport("user32.dll")] public static extern bool EnumWindows(EnumCallback callback,IntPtr value);
 public delegate bool EnumCallback(IntPtr h,IntPtr value);
}
'@
$script:started=Get-Date
$script:messages=New-Object 'System.Collections.Generic.List[string]'
$script:seen=@{}
$script:captures=New-Object 'System.Collections.Generic.List[object]'
$script:missing=New-Object 'System.Collections.Generic.List[string]'
$script:out=''
$script:guiTitle=''
function Note([string]$message) {
 $line=(Get-Date -Format 'HH:mm:ss')+' '+$message
 Write-Host $line
 [void]$script:messages.Add($line)
 if($script:out){Add-Content -LiteralPath (Join-Path $script:out 'execution.log') -Value $line -Encoding ASCII}
}
function Get-Project {
 if($Root -and (Test-Path -LiteralPath (Join-Path $Root 'program\rapidminer\NaiveBayes_Full.rmp') -PathType Leaf)){return $Root}
 $list=@(Get-ChildItem -LiteralPath 'H:\' -Directory -Filter 'BISM2202_Ready_*' -ErrorAction SilentlyContinue |
 Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'program\rapidminer\NaiveBayes_Full.rmp') -PathType Leaf} |
 Sort-Object LastWriteTime -Descending)
 if($list.Count -gt 0){return $list[0].FullName}
 throw 'READY_PROJECT_NOT_FOUND: use -Root with the extracted program and report folder'
}
function Get-Rapid {
 $p=@(Get-Process -ErrorAction SilentlyContinue |
 Where-Object {$_.MainWindowHandle -ne [IntPtr]::Zero -and $_.MainWindowTitle -match '(RapidMiner|AI Studio Educational)'} |
 Sort-Object StartTime -Descending)
 if($p.Count -eq 0){return $null}
 return $p[0]
}
function Ensure-Rapid {
 $p=Get-Rapid
 if($p){return $p}
 $folders=@('C:\Program Files\RapidMiner\RapidMiner Studio','C:\Program Files\Altair\AI Studio','C:\Program Files\RapidMiner')
 $exes=@()
 foreach($f in $folders){
  if(Test-Path -LiteralPath $f -PathType Container){
   $exes+=@(Get-ChildItem -LiteralPath $f -File -Filter '*.exe' -ErrorAction SilentlyContinue |
    Where-Object {$_.Name -match '(RapidMiner|AI Studio|RapidMiner Studio)'})
  }
 }
 if($exes.Count -eq 0){Note 'RAPIDMINER_GUI_EXE_NOT_FOUND';return $null}
 try {
  Start-Process -FilePath $exes[0].FullName
  Note ('RAPIDMINER_GUI_START_REQUESTED '+$exes[0].FullName)
 } catch{Note ('RAPIDMINER_GUI_START_FAILED '+$_.Exception.Message);return $null}
 $deadline=(Get-Date).AddSeconds(75)
 do{
  Start-Sleep -Seconds 3
  $p=Get-Rapid
 }while(-not $p -and (Get-Date) -lt $deadline)
 return $p
}
function WindowBounds($p) {
 $p.Refresh()
 $r=New-Object 'BismWindow+RECT'
 if(-not [BismWindow]::GetWindowRect($p.MainWindowHandle,[ref]$r)){throw 'WINDOW_RECT_UNAVAILABLE'}
 return $r
}
function Focus-Rapid($p) {
 if(-not $p){throw 'RAPIDMINER_WINDOW_MISSING'}
 [void][BismWindow]::ShowWindow($p.MainWindowHandle,3)
 [void][BismWindow]::SetForegroundWindow($p.MainWindowHandle)
 Start-Sleep -Milliseconds 900
 $r=WindowBounds $p
 if($r.Right-$r.Left -lt 700 -or $r.Bottom-$r.Top -lt 500){
  throw ('RAPIDMINER_WINDOW_TOO_SMALL '+($r.Right-$r.Left)+'x'+($r.Bottom-$r.Top))
 }
 return $r
}
function Send([string]$keys) {
 [System.Windows.Forms.SendKeys]::SendWait($keys)
 Start-Sleep -Milliseconds 480
}
function Click($p,[double]$x,[double]$y,[int]$times=1){
 $r=Focus-Rapid $p
 $cx=$r.Left+[int](($r.Right-$r.Left)*$x)
 $cy=$r.Top+[int](($r.Bottom-$r.Top)*$y)
 [void][BismWindow]::SetCursorPos($cx,$cy)
 for($i=0;$i -lt $times;$i++){
  [BismWindow]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
  [BismWindow]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
  Start-Sleep -Milliseconds 155
 }
 Start-Sleep -Milliseconds 950
}
function Popups {
 $titles=New-Object 'System.Collections.Generic.List[string]'
 $callback=[BismWindow+EnumCallback]{
  param([IntPtr]$h,[IntPtr]$v)
  $b=New-Object System.Text.StringBuilder 512
  [void][BismWindow]::GetWindowText($h,$b,512)
  $t=$b.ToString()
  if($t -match '(Import Process|Create Folder|Process Import Messages|Open File|Open Process|Error|Warning)'){
   [void]$titles.Add($t)
  }
  return $true
 }
 [void][BismWindow]::EnumWindows($callback,[IntPtr]::Zero)
 return @($titles.ToArray())
}
function Snapshot($p,[string]$model,[string]$stage,[string]$suffix=''){
 $r=Focus-Rapid $p
 $w=$r.Right-$r.Left;$h=$r.Bottom-$r.Top
 $bitmap=New-Object System.Drawing.Bitmap($w,$h)
 $graphics=[Drawing.Graphics]::FromImage($bitmap)
 $rel=$model+'_'+$stage+$suffix+'.png'
 $target=Join-Path $script:out $rel
 try{
  $graphics.CopyFromScreen($r.Left,$r.Top,0,0,$bitmap.Size)
  $bitmap.Save($target,[Drawing.Imaging.ImageFormat]::Png)
 } finally {$graphics.Dispose();$bitmap.Dispose()}
 $sha=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
 if($script:seen.ContainsKey($sha)){
  $other=$script:seen[$sha]
  Remove-Item -LiteralPath $target -Force
  Note ('DUPLICATE_SKIPPED '+$rel+' matches '+$other)
  return $false
 }
 $script:seen[$sha]=$rel
 $pop=@()
 try {$pop=@(Popups)}catch {Note ('POPUP_SCAN_UNAVAILABLE '+$_.Exception.Message)}
 $status=if($pop.Count){'DIALOG_REVIEW'}else{'CAPTURE_REVIEW'}
 $title=(Get-Rapid).MainWindowTitle
 [void]$script:captures.Add([pscustomobject]@{file=$rel;model=$model;stage=$stage;status=$status;title=$title;sha256=$sha;popup=($pop -join '|')})
 Note ($status+' '+$rel+' '+$sha.Substring(0,10))
 return $true
}
function Prepare($model) {
 $file=if($model -eq 'NB'){'NaiveBayes_Full.rmp'}else{'GradientBoostedTrees_Full.rmp'}
 $source=Join-Path $script:root ('program\rapidminer\'+$file)
 $csv=Join-Path $script:root 'program\rapidminer\data\BISM2202_A2_Loan_Data_Set_RapidMiner2026S2.csv'
 if(-not (Test-Path -LiteralPath $source -PathType Leaf)){throw ('MODEL_RMP_MISSING '+$file)}
 if(-not (Test-Path -LiteralPath $csv -PathType Leaf)){throw 'LOAN_CSV_MISSING'}
 [xml]$doc=Get-Content -LiteralPath $source -Raw -Encoding UTF8
 $value=$doc.SelectSingleNode('/process/context/macros/macro[key="source_csv"]/value')
 if(-not $value){throw 'RMP_SOURCE_MACRO_MISSING'}
 $value.InnerText=$csv
 $target=Join-Path $script:out ($model+'_Native_Ready.rmp')
 $settings=New-Object System.Xml.XmlWriterSettings
 $settings.Encoding=[Text.UTF8Encoding]::new($false)
 $settings.Indent=$true
 $writer=[System.Xml.XmlWriter]::Create($target,$settings)
 try {$doc.Save($writer)}finally{$writer.Dispose()}
 $bytes=[IO.File]::ReadAllBytes($target)
 if($bytes.Length -lt 5 -or $bytes[0] -ne 60 -or $bytes[1] -ne 63){throw 'RMP_XML_ENCODING_FAILED'}
 return $target
}
function OpenProcess($model,$file) {
 $p=Ensure-Rapid
 if(-not $p){Note ('BLOCKED_RAPIDMINER_NOT_OPEN '+$model);return $false}
 [void](Focus-Rapid $p)
 Note ('OPEN_START '+$model+' '+$file)
 Send '^o'
 Start-Sleep -Seconds 3
 # File-name access key of the native/Swing file chooser.
 Send '%n'
 Send '^a'
 [System.Windows.Forms.Clipboard]::SetText($file)
 Send '^v'
 Send '{ENTER}'
 $deadline=(Get-Date).AddSeconds([math]::Min(14,$OpenTimeoutSeconds))
 $pattern=if($model -eq 'NB'){'NaiveBayes'}else{'GradientBoostedTrees'}
 do {
  Start-Sleep -Seconds 2
  $p=Get-Rapid
  if($p){$p.Refresh();if($p.MainWindowTitle -match $pattern){
   Note ('MODEL_TITLE_CONFIRMED '+$model+' '+$p.MainWindowTitle);return $true
  }}
 }while((Get-Date) -lt $deadline)
 # A previous failed keystroke may have opened the Create Folder error dialog.
 # Close that modal first; never paste the path while an error is on top.
 $before=@()
 try {$before=@(Popups)}catch{}
 if(($before -join '|') -match '(Create Folder|Error)'){
  Send '{ESC}'
  Start-Sleep -Seconds 1
  Note ('MODAL_ERROR_DISMISSED '+$model)
 }
 # Java file choosers sometimes ignore Alt+N. Retry using the actual
 # named dialog's file-name edit field instead of typing into the folder list.
 $dialog=$null
 $search=[BismWindow+EnumCallback]{
  param([IntPtr]$h,[IntPtr]$v)
  $sb=New-Object System.Text.StringBuilder 256
  [void][BismWindow]::GetWindowText($h,$sb,256)
  if($sb.ToString() -match '^(Import Process|Open Process|Open File)
}
function CaptureModel($model) {
 $path=Prepare $model
 if(-not (OpenProcess $model $path)) {
  [void]$script:missing.Add($model+': model import')
  return
 }
 $p=Get-Rapid
 [void](Focus-Rapid $p)
 Click $p .382 .070
 Start-Sleep -Seconds 2
 # Use RapidMiner fit-to-view button, and keep the original GUI window in view.
 try{Click $p .633 .170}catch{Note ('FIT_TO_VIEW_FAILED '+$model)}
 [void](Snapshot $p $model '01_Design_Overall_REVIEW')
 # CV candidate location: fit-to-view of the frozen full pipeline.
 try{
  Click $p .575 .327 2
  [void](Snapshot $p $model '02_CV_Inner_Candidate_REVIEW')
  # If inner CV is visible, the Training and Testing selections differ.
  Click $p .202 .320
  [void](Snapshot $p $model '03_CV_Training_Candidate_REVIEW')
  Click $p .202 .400
  [void](Snapshot $p $model '04_CV_Testing_Candidate_REVIEW')
 }catch{Note ('CV_NAVIGATION_UNVERIFIED '+$model+' '+$_.Exception.Message)}
 # Run only the actual loaded process, not a reconstructed image or model.
 Click $p .382 .070
 Click $p .149 .073
 Note ('GUI_RUN_REQUESTED '+$model)
 $deadline=(Get-Date).AddSeconds($(if($model -eq 'GBT'){$RunTimeoutSeconds}else{35}))
 Start-Sleep -Seconds 8
 while((Get-Date) -lt $deadline){
  $p=Get-Rapid
  if(-not $p){break}
  $p.Refresh()
  # Explicit time limit instead of looping forever or promising model completion.
  Start-Sleep -Seconds 3
 }
 if(-not $p) { [void]$script:missing.Add($model+': RapidMiner window missing after run');return }
 [void](Focus-Rapid $p)
 Click $p .445 .070
 Start-Sleep -Seconds 2
 [void](Snapshot $p $model '05_Results_Start_REVIEW')
 # Tab labels can occupy one or two rows depending on resolution.
 # Capture multiple real views with neutral names, then classify from images.
 $points=@(
   @(0.29,0.145),@(0.59,0.145),@(0.30,0.185),@(0.61,0.185),
   @(0.44,0.145),@(0.73,0.145),@(0.47,0.185),@(0.77,0.185)
 )
 for($i=0;$i -lt $points.Count;$i++){
  try{
   Click $p $points[$i][0] $points[$i][1]
   [void](Snapshot $p $model ('06_ResultTab_'+('{0:D2}' -f ($i+1))+'_REVIEW'))
  }catch{Note ('RESULT_TAB_FAILED '+$model+' '+$i+' '+$_.Exception.Message)}
 }
 Note ('MODEL_CAPTURE_FINISHED '+$model)
}
function WindowInventory {
 foreach($pattern in @('SSMS','SQL Server Management Studio','Microsoft Visual Studio','Integration Services')){
  $found=@(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -match [regex]::Escape($pattern) })
  if($found.Count){Note ('EXTERNAL_APP_PRESENT '+$pattern+' '+$found.Count)}
 }
 $ssis=@(Get-ChildItem -LiteralPath (Join-Path $script:root 'program\ssis') -File -Filter '*.dtsx' -ErrorAction SilentlyContinue)
 if($ssis.Count -eq 0){[void]$script:missing.Add('SSIS: no built .dtsx project in the supplied package')}
 try{
  $c=New-Object System.Data.SqlClient.SqlConnection('Server=.;Database=BISM2202_A2_dw;Integrated Security=True;Connect Timeout=3;Encrypt=False')
  $c.Open();$c.Close();$c.Dispose()
  Note 'WAREHOUSE_DATABASE_CONNECTION=PASS'
  [void]$script:missing.Add('SQL: native SSMS screenshots require executing the report queries in SSMS')
 }catch{
  Note ('WAREHOUSE_DATABASE_CONNECTION=FAILED '+$_.Exception.Message)
  [void]$script:missing.Add('SQL: school DW database unavailable; no SSMS query screenshots')
 }
}
$exitStatus='INCOMPLETE_REVIEW_REQUIRED'
try {
 $script:root=Get-Project
 $stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
 $script:out=Join-Path $script:root ('BISM2202_Report_Evidence_'+$stamp)
 New-Item -ItemType Directory -Path $script:out -Force | Out-Null
 Note ('PROJECT='+$script:root)
 Note ('OUTPUT='+$script:out)
 foreach($model in @('NB','GBT')){
  try { CaptureModel $model }
  catch {
   Note ('MODEL_EXCEPTION '+$model+' '+$_.Exception.Message+' LINE='+$_.InvocationInfo.ScriptLineNumber)
   [void]$script:missing.Add($model+': capture error '+$_.Exception.Message)
  }
 }
 WindowInventory
} catch {
 if($script:out){Note ('FATAL '+$_.Exception.Message+' LINE='+$_.InvocationInfo.ScriptLineNumber)}
 else{Write-Host ('FATAL '+$_.Exception.Message)}
} finally {
 if($script:out -and (Test-Path -LiteralPath $script:out)){
  $evidence=[ordered]@{
   status=$exitStatus; started=$script:started.ToString('o'); finished=(Get-Date).ToString('o')
   screenshot_count=$script:captures.Count; screenshots=@($script:captures.ToArray())
   missing=@($script:missing.ToArray()); result_note='All screenshots are unverified candidates until reviewed against native UI'
  }
  $json=$evidence | ConvertTo-Json -Depth 8
  [IO.File]::WriteAllText((Join-Path $script:out 'evidence_manifest.json'),$json,[Text.UTF8Encoding]::new($false))
  $archive=$script:out+'.zip'
  try { Compress-Archive -Path (Join-Path $script:out '*') -DestinationPath $archive -CompressionLevel Optimal -Force }
  catch { Note ('ZIP_FAILED '+$_.Exception.Message) }
  $notice=Join-Path $script:root ('BISM2202_CAPTURE_FINISHED_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'.txt')
  $final=@('EXECUTION_FINISHED',('SCREENSHOT_COUNT='+$script:captures.Count),('MISSING_COUNT='+$script:missing.Count),('ZIP='+$archive),'REVIEW_REQUIRED')
  [IO.File]::WriteAllLines($notice,[string[]]$final,[Text.UTF8Encoding]::new($false))
  Write-Host ('CAPTURE_EXECUTION_FINISHED screenshot_count='+$script:captures.Count+' missing='+$script:missing.Count) -ForegroundColor Cyan
  Write-Host ('RESULT_ZIP='+$archive)
  try{[System.Media.SystemSounds]::Asterisk.Play()}catch{}
  try{
   $msg='Capture execution finished.'+[Environment]::NewLine+'Images: '+$script:captures.Count+
    [Environment]::NewLine+'Unresolved items: '+$script:missing.Count+
    [Environment]::NewLine+'The images still require review.'+
    [Environment]::NewLine+'ZIP: '+$archive
   [void][System.Windows.Forms.MessageBox]::Show($msg,'BISM2202 Capture Finished',
    [System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information)
  }catch{}
 }
}
){$script:dialogFound=$h;return $false}
  return $true
 }
 $script:dialogFound=[IntPtr]::Zero
 [void][BismWindow]::EnumWindows($search,[IntPtr]::Zero)
 if($script:dialogFound -ne [IntPtr]::Zero){
  $dr=New-Object 'BismWindow+RECT'
  if([BismWindow]::GetWindowRect($script:dialogFound,[ref]$dr)){
   [void][BismWindow]::ShowWindow($script:dialogFound,9)
   [void][BismWindow]::SetForegroundWindow($script:dialogFound)
   $dx=$dr.Left+[int](($dr.Right-$dr.Left)*0.32)
   $dy=$dr.Top+[int](($dr.Bottom-$dr.Top)*0.82)
   [void][BismWindow]::SetCursorPos($dx,$dy)
   [BismWindow]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
   [BismWindow]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
   Start-Sleep -Milliseconds 400
   Send '^a'
   [System.Windows.Forms.Clipboard]::SetText($file)
   Send '^v'
   Send '{ENTER}'
   Note ('DIALOG_FILE_FIELD_RETRY '+$model)
  }
 } else {Note ('OPEN_DIALOG_NOT_FOUND '+$model)}
 $deadline=(Get-Date).AddSeconds($OpenTimeoutSeconds)
 do {
  Start-Sleep -Seconds 2
  $p=Get-Rapid
  if($p){$p.Refresh();if($p.MainWindowTitle -match $pattern){
   Note ('MODEL_TITLE_CONFIRMED '+$model+' '+$p.MainWindowTitle);return $true
  }}
 }while((Get-Date) -lt $deadline)
 if($p){
  try {[void](Snapshot $p $model 'DIAGNOSTIC_Open_Failed')}
  catch {Note ('DIAGNOSTIC_CAPTURE_FAILED '+$_.Exception.Message)}
 }
 Note ('MODEL_TITLE_NOT_CONFIRMED '+$model)
 return $false
}
function CaptureModel($model) {
 $path=Prepare $model
 if(-not (OpenProcess $model $path)) {
  [void]$script:missing.Add($model+': model import')
  return
 }
 $p=Get-Rapid
 [void](Focus-Rapid $p)
 Click $p .382 .070
 Start-Sleep -Seconds 2
 # Use RapidMiner fit-to-view button, and keep the original GUI window in view.
 try{Click $p .633 .170}catch{Note ('FIT_TO_VIEW_FAILED '+$model)}
 [void](Snapshot $p $model '01_Design_Overall_REVIEW')
 # CV candidate location: fit-to-view of the frozen full pipeline.
 try{
  Click $p .575 .327 2
  [void](Snapshot $p $model '02_CV_Inner_Candidate_REVIEW')
  # If inner CV is visible, the Training and Testing selections differ.
  Click $p .202 .320
  [void](Snapshot $p $model '03_CV_Training_Candidate_REVIEW')
  Click $p .202 .400
  [void](Snapshot $p $model '04_CV_Testing_Candidate_REVIEW')
 }catch{Note ('CV_NAVIGATION_UNVERIFIED '+$model+' '+$_.Exception.Message)}
 # Run only the actual loaded process, not a reconstructed image or model.
 Click $p .382 .070
 Click $p .149 .073
 Note ('GUI_RUN_REQUESTED '+$model)
 $deadline=(Get-Date).AddSeconds($(if($model -eq 'GBT'){$RunTimeoutSeconds}else{35}))
 Start-Sleep -Seconds 8
 while((Get-Date) -lt $deadline){
  $p=Get-Rapid
  if(-not $p){break}
  $p.Refresh()
  # Explicit time limit instead of looping forever or promising model completion.
  Start-Sleep -Seconds 3
 }
 if(-not $p) { [void]$script:missing.Add($model+': RapidMiner window missing after run');return }
 [void](Focus-Rapid $p)
 Click $p .445 .070
 Start-Sleep -Seconds 2
 [void](Snapshot $p $model '05_Results_Start_REVIEW')
 # Tab labels can occupy one or two rows depending on resolution.
 # Capture multiple real views with neutral names, then classify from images.
 $points=@(
   @(0.29,0.145),@(0.59,0.145),@(0.30,0.185),@(0.61,0.185),
   @(0.44,0.145),@(0.73,0.145),@(0.47,0.185),@(0.77,0.185)
 )
 for($i=0;$i -lt $points.Count;$i++){
  try{
   Click $p $points[$i][0] $points[$i][1]
   [void](Snapshot $p $model ('06_ResultTab_'+('{0:D2}' -f ($i+1))+'_REVIEW'))
  }catch{Note ('RESULT_TAB_FAILED '+$model+' '+$i+' '+$_.Exception.Message)}
 }
 Note ('MODEL_CAPTURE_FINISHED '+$model)
}
function WindowInventory {
 foreach($pattern in @('SSMS','SQL Server Management Studio','Microsoft Visual Studio','Integration Services')){
  $found=@(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -match [regex]::Escape($pattern) })
  if($found.Count){Note ('EXTERNAL_APP_PRESENT '+$pattern+' '+$found.Count)}
 }
 $ssis=@(Get-ChildItem -LiteralPath (Join-Path $script:root 'program\ssis') -File -Filter '*.dtsx' -ErrorAction SilentlyContinue)
 if($ssis.Count -eq 0){[void]$script:missing.Add('SSIS: no built .dtsx project in the supplied package')}
 try{
  $c=New-Object System.Data.SqlClient.SqlConnection('Server=.;Database=BISM2202_A2_dw;Integrated Security=True;Connect Timeout=3;Encrypt=False')
  $c.Open();$c.Close();$c.Dispose()
  Note 'WAREHOUSE_DATABASE_CONNECTION=PASS'
  [void]$script:missing.Add('SQL: native SSMS screenshots require executing the report queries in SSMS')
 }catch{
  Note ('WAREHOUSE_DATABASE_CONNECTION=FAILED '+$_.Exception.Message)
  [void]$script:missing.Add('SQL: school DW database unavailable; no SSMS query screenshots')
 }
}
$exitStatus='INCOMPLETE_REVIEW_REQUIRED'
try {
 $script:root=Get-Project
 $stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
 $script:out=Join-Path $script:root ('BISM2202_Report_Evidence_'+$stamp)
 New-Item -ItemType Directory -Path $script:out -Force | Out-Null
 Note ('PROJECT='+$script:root)
 Note ('OUTPUT='+$script:out)
 foreach($model in @('NB','GBT')){
  try { CaptureModel $model }
  catch {
   Note ('MODEL_EXCEPTION '+$model+' '+$_.Exception.Message+' LINE='+$_.InvocationInfo.ScriptLineNumber)
   [void]$script:missing.Add($model+': capture error '+$_.Exception.Message)
  }
 }
 WindowInventory
} catch {
 if($script:out){Note ('FATAL '+$_.Exception.Message+' LINE='+$_.InvocationInfo.ScriptLineNumber)}
 else{Write-Host ('FATAL '+$_.Exception.Message)}
} finally {
 if($script:out -and (Test-Path -LiteralPath $script:out)){
  $evidence=[ordered]@{
   status=$exitStatus; started=$script:started.ToString('o'); finished=(Get-Date).ToString('o')
   screenshot_count=$script:captures.Count; screenshots=@($script:captures.ToArray())
   missing=@($script:missing.ToArray()); result_note='All screenshots are unverified candidates until reviewed against native UI'
  }
  $json=$evidence | ConvertTo-Json -Depth 8
  [IO.File]::WriteAllText((Join-Path $script:out 'evidence_manifest.json'),$json,[Text.UTF8Encoding]::new($false))
  $archive=$script:out+'.zip'
  try { Compress-Archive -Path (Join-Path $script:out '*') -DestinationPath $archive -CompressionLevel Optimal -Force }
  catch { Note ('ZIP_FAILED '+$_.Exception.Message) }
  $notice=Join-Path $script:root ('BISM2202_CAPTURE_FINISHED_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'.txt')
  $final=@('EXECUTION_FINISHED',('SCREENSHOT_COUNT='+$script:captures.Count),('MISSING_COUNT='+$script:missing.Count),('ZIP='+$archive),'REVIEW_REQUIRED')
  [IO.File]::WriteAllLines($notice,[string[]]$final,[Text.UTF8Encoding]::new($false))
  Write-Host ('CAPTURE_EXECUTION_FINISHED screenshot_count='+$script:captures.Count+' missing='+$script:missing.Count) -ForegroundColor Cyan
  Write-Host ('RESULT_ZIP='+$archive)
  try{[System.Media.SystemSounds]::Asterisk.Play()}catch{}
  try{
   $msg='Capture execution finished.'+[Environment]::NewLine+'Images: '+$script:captures.Count+
    [Environment]::NewLine+'Unresolved items: '+$script:missing.Count+
    [Environment]::NewLine+'The images still require review.'+
    [Environment]::NewLine+'ZIP: '+$archive
   [void][System.Windows.Forms.MessageBox]::Show($msg,'BISM2202 Capture Finished',
    [System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information)
  }catch{}
 }
}
