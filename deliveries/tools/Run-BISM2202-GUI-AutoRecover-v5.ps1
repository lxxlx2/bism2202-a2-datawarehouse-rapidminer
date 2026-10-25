param([string]$Root='H:\BISM2202_Ready_20261025_223139')
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class BismClick {
 [StructLayout(LayoutKind.Sequential)] public struct RECT {public int Left,Top,Right,Bottom;}
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd,out RECT rect);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hwnd,int mode);
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")] public static extern void mouse_event(uint flags,uint dx,uint dy,uint data,UIntPtr extra);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string className,string windowName);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h,System.Text.StringBuilder b,int max);
 [DllImport("user32.dll")] public static extern bool EnumWindows(Callback cb,IntPtr param);
 [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h,uint msg,IntPtr w,IntPtr l);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h,out uint pid);
 public delegate bool Callback(IntPtr h,IntPtr param);
}
'@
if(-not (Test-Path -LiteralPath $Root -PathType Container)){throw 'PROJECT_ROOT_NOT_FOUND'}
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
$out=Join-Path $Root ('BISM2202_GUI_Review_'+$stamp)
New-Item -ItemType Directory -Path $out -Force | Out-Null
$script:log=Join-Path $out 'execution.log'
$script:images=New-Object 'System.Collections.Generic.List[string]'
$script:seen=@{}
$script:state='INCOMPLETE'
function Say([string]$m){
 $line=(Get-Date -Format 'HH:mm:ss')+' '+$m
 Write-Host $line
 Add-Content -LiteralPath $script:log -Value $line -Encoding ASCII
}
function GetGui {
 $p=@(Get-Process -ErrorAction SilentlyContinue | Where-Object {
  $_.MainWindowHandle -ne [IntPtr]::Zero -and $_.MainWindowTitle -match 'RapidMiner Studio'
 } | Sort-Object StartTime -Descending)
 if($p.Count -eq 0){return $null}
 return $p[0]
}
function EnsureGui {
 $p=GetGui
 if($p){Say ('GUI_PRESENT '+$p.MainWindowTitle);return $p}
 $possible=@('C:\Program Files\RapidMiner\RapidMiner Studio\RapidMiner Studio.exe',
             'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\RapidMiner Studio.lnk',
             (Join-Path $env:PUBLIC 'Desktop\RapidMiner Studio.lnk'),
             (Join-Path $env:USERPROFILE 'Desktop\RapidMiner Studio.lnk'))
 $possible=@($possible|Where-Object{Test-Path -LiteralPath $_ -PathType Leaf})
 if($possible.Count -eq 0){
  $d='C:\Program Files\RapidMiner\RapidMiner Studio'
  if(Test-Path -LiteralPath $d){
   $possible=@(Get-ChildItem -LiteralPath $d -File -Filter '*.exe' -ErrorAction SilentlyContinue|
     Where-Object{$_.Name -match 'RapidMiner' -and $_.Name -notmatch 'uninstall'} |
     Select-Object -ExpandProperty FullName)
  }
 }
 if($possible.Count -eq 0){throw 'RAPIDMINER_START_FILE_NOT_FOUND'}
 Say ('AUTO_START_RAPIDMINER '+$possible[0])
 Start-Process -FilePath $possible[0] | Out-Null
 $until=(Get-Date).AddSeconds(110)
 do{Start-Sleep -Seconds 3;$p=GetGui}while(-not $p -and (Get-Date) -lt $until)
 if(-not $p){throw 'RAPIDMINER_GUI_START_TIMEOUT'}
 return $p
}
function OtherWindows {
 $main=GetGui
 if(-not $main){return @()}
 $list=New-Object 'System.Collections.Generic.List[object]'
 $callback=[BismClick+Callback]{
  param([IntPtr]$h,[IntPtr]$none)
  if([BismClick]::IsWindowVisible($h)){
   [uint32]$windowProcessId=0
   [void][BismClick]::GetWindowThreadProcessId($h,[ref]$windowProcessId)
   if($windowProcessId -eq $main.Id){
    $b=[System.Text.StringBuilder]::new(400)
    [void][BismClick]::GetWindowText($h,$b,400)
    if($b.Length){[void]$list.Add([pscustomobject]@{handle=$h;title=$b.ToString()})}
   }
  }
  return $true
 }
 [void][BismClick]::EnumWindows($callback,[IntPtr]::Zero)
 return @($list.ToArray())
}
function SafeDialogs {
 $windows=@(OtherWindows)
 $save=@($windows|Where-Object{$_.title -match 'Save Changes|Do you want to save|Save Process|Unsaved'})
 if($save.Count){Say ('SAVE_CHANGES_PRESERVED '+$save[0].title);throw 'UNSAVED_WORK_DIALOG: manual review required'}
 foreach($info in @($windows|Where-Object{$_.title -match '^(Process Import Messages|Information)$'})){
  [void][BismClick]::SetForegroundWindow($info.handle)
  [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
  Say ('INFO_DIALOG_CLOSED '+$info.title)
 }
}
function ModelReady([string]$model,[int]$seconds) {
 $wanted=if($model -eq 'GBT'){'GradientBoostedTrees_Full\.rmp'}else{'NaiveBayes_Full\.rmp'}
 $limit=(Get-Date).AddSeconds($seconds)
 do{
  $p=GetGui
  if($p -and $p.MainWindowTitle -match $wanted){
   Say ('MODEL_TITLE_CONFIRMED '+$model+' '+$p.MainWindowTitle);return $true
  }
  Start-Sleep -Seconds 2
 }while((Get-Date) -lt $limit)
 return $false
}
function Recent([string]$model,[int]$row) {
 $wins=@(OtherWindows|Where-Object{$_.title -match '^Welcome to RapidMiner Studio!?$'})
 if(-not $wins.Count){return $false}
 $dlg=$wins[0];$r=[BismClick+RECT]::new()
 if(-not [BismClick]::GetWindowRect($dlg.handle,[ref]$r)){return $false}
 $dw=$r.Right-$r.Left;$dh=$r.Bottom-$r.Top
 if($dw -lt 650 -or $dh -lt 450){return $false}
 [void][BismClick]::SetForegroundWindow($dlg.handle)
 Start-Sleep -Milliseconds 650
 $y=if($model -eq 'GBT'){if($row -eq 1){.358}else{.393}}else{if($row -eq 1){.252}else{.287}}
 [void][BismClick]::SetCursorPos(($r.Left+[int]($dw*.105)),($r.Top+[int]($dh*$y)))
 [BismClick]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
 [BismClick]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
 Say ('WELCOME_RECENT_SELECT '+$model+' row='+$row)
 return $true
}
function ClearOldCompletion {
 foreach($title in @('BISM2202 GBT Capture Finished','BISM2202 Capture Finished')){
  $h=[BismClick]::FindWindow($null,$title)
  if($h -ne [IntPtr]::Zero){
   [void][BismClick]::SendMessage($h,16,[IntPtr]::Zero,[IntPtr]::Zero)
   Say ('OLD_FINISHED_DIALOG_CLOSED '+$title)
  }
 }
}
function NativeChooser([string]$model) {
 $dialogs=@(OtherWindows|Where-Object {$_.title -match '^(Import Process|Open Process|Open File)$'})
 if($dialogs.Count -eq 0){return $false}
 $dlg=$dialogs[0];$r=[BismClick+RECT]::new()
 if(-not [BismClick]::GetWindowRect($dlg.handle,[ref]$r)){return $false}
 $w=$r.Right-$r.Left;$h=$r.Bottom-$r.Top
 if($w -lt 450 -or $h -lt 350){return $false}
 $name=if($model -eq 'GBT'){'GradientBoostedTrees_Full.rmp'}else{'NaiveBayes_Full.rmp'}
 $file=Join-Path $Root ('program\rapidminer\'+$name)
 if(-not (Test-Path -LiteralPath $file -PathType Leaf)){throw ('MODEL_FILE_MISSING '+$file)}
 [void][BismClick]::SetForegroundWindow($dlg.handle)
 Start-Sleep -Milliseconds 550
 [void][BismClick]::SetCursorPos(($r.Left+[int]($w*.35)),($r.Top+[int]($h*.844)))
 [BismClick]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
 [BismClick]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
 [System.Windows.Forms.SendKeys]::SendWait('^a')
 [System.Windows.Forms.Clipboard]::SetText($file)
 [System.Windows.Forms.SendKeys]::SendWait('^v')
 [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
 Say ('NATIVE_FILE_CHOOSER_SUBMITTED '+$model)
 return $true
}

function OpenModel([string]$model) {
 $p=EnsureGui
 if(ModelReady $model 2){return $true}
 SafeDialogs
 # RapidMiner 10.3: File > Import Process. Ctrl+O opens Welcome instead.
 # Close only the non-destructive Welcome page before using the File menu.
 $welcome=@(OtherWindows|Where-Object {$_.title -match '^Welcome to RapidMiner Studio!?$'})
 if($welcome.Count){
  Diagnostic ($model+'_00_Before_Import')
  foreach($w in $welcome){
   [void][BismClick]::SendMessage($w.handle,16,[IntPtr]::Zero,[IntPtr]::Zero)
  }
  Start-Sleep -Seconds 2
  Say ('WELCOME_PAGE_CLOSED '+$model)
 }
 [void][BismClick]::ShowWindow($p.MainWindowHandle,3)
 [void][BismClick]::SetForegroundWindow($p.MainWindowHandle)
 Start-Sleep -Milliseconds 600
 [System.Windows.Forms.SendKeys]::SendWait('%f')
 Start-Sleep -Milliseconds 450
 [System.Windows.Forms.SendKeys]::SendWait('m')
 Start-Sleep -Seconds 2
 if(-not (NativeChooser $model)){
  Say ('IMPORT_MENU_SHORTCUT_NOT_CONFIRMED '+$model)
  # Retry opening the File menu by clicking its visible top-left location.
  ClickXY .018 .047
  [System.Windows.Forms.SendKeys]::SendWait('m')
  Start-Sleep -Seconds 2
 }
 if(NativeChooser $model){
  if(ModelReady $model 30){return $true}
  Say ('IMPORT_SUBMITTED_TITLE_UNCONFIRMED '+$model)
  Diagnostic ($model+'_00_After_Import')
 } else {
  Say ('IMPORT_DIALOG_NOT_FOUND '+$model)
  Diagnostic ($model+'_00_File_Menu_Unable')
 }
 # The Recent page is a fallback only. Use its actual hyperlink positions
 # from the previously captured 10.3 school instance, not blank row spaces.
 SafeDialogs
 [void][BismClick]::SetForegroundWindow($p.MainWindowHandle)
 [System.Windows.Forms.SendKeys]::SendWait('^o')
 Start-Sleep -Seconds 3
 for($row=1;$row -le 2;$row++){
  if(Recent $model $row){
   if(ModelReady $model 15){return $true}
   SafeDialogs
  }
 }
 Diagnostic ($model+'_00_Open_Failed')
 Say ('MODEL_NOT_OPENED '+$model)
 return $false
}
function CollectModel([string]$model) {
 if(-not (OpenModel $model)){return $false}
 [void](FocusGui)
 SafeDialogs
 ClickXY .4 .082
 Image ($model+'_01_Overall_CANDIDATE')
 try{
  ClickXY .598 .324 2
  Image ($model+'_02_CV_Inner_CANDIDATE')
  ClickXY .205 .32
  Image ($model+'_03_CV_Training_CANDIDATE')
  ClickXY .205 .40
  Image ($model+'_04_CV_Testing_CANDIDATE')
 }catch{Say ('CV_CANDIDATE_UNVERIFIED '+$model+' '+$_.Exception.Message)}
 SafeDialogs
 ClickXY .4 .082
 ClickXY .155 .082
 Say ('GUI_RUN_REQUESTED '+$model)
 Start-Sleep -Seconds $(if($model -eq 'GBT'){100}else{45})
 if(-not (ModelReady $model 3)){throw ('MODEL_TITLE_LOST '+$model)}
 SafeDialogs
 ClickXY .455 .082
 Image ($model+'_05_Results_Overview_CANDIDATE')
 $tabs=@(@(.3,.145),@(.6,.145),@(.3,.185),@(.6,.185),@(.45,.145),@(.74,.145))
 for($i=0;$i -lt $tabs.Count;$i++){
  SafeDialogs
  ClickXY $tabs[$i][0] $tabs[$i][1]
  Image ($model+'_06_Results_'+('{0:D2}' -f ($i+1))+'_CANDIDATE')
 }
 Say ('MODEL_CAPTURE_FINISHED '+$model)
 return $true
}

function FocusGui {
 $p=GetGui
 if(-not $p){throw 'RAPIDMINER_GUI_NOT_RUNNING'}
 [void][BismClick]::ShowWindow($p.MainWindowHandle,3)
 [void][BismClick]::SetForegroundWindow($p.MainWindowHandle)
 Start-Sleep -Milliseconds 900
 $r=[BismClick+RECT]::new()
 if(-not [BismClick]::GetWindowRect($p.MainWindowHandle,[ref]$r)){throw 'WINDOW_RECT_FAILED'}
 $width=$r.Right-$r.Left;$height=$r.Bottom-$r.Top
 if($width -lt 1100 -or $height -lt 650){throw ('WINDOW_TOO_SMALL '+$width+'x'+$height)}
 return @{process=$p;rect=$r;width=$width;height=$height}
}
function ClickXY([double]$x,[double]$y,[int]$n=1){
 $w=FocusGui
 $px=$w.rect.Left+[int]($w.width*$x)
 $py=$w.rect.Top+[int]($w.height*$y)
 [void][BismClick]::SetCursorPos($px,$py)
 for($j=0;$j -lt $n;$j++){
  [BismClick]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
  [BismClick]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
  Start-Sleep -Milliseconds 180
 }
 Start-Sleep -Milliseconds 1000
}
function Diagnostic([string]$name) {
 $p=GetGui
 if(-not $p){return}
 $r=[BismClick+RECT]::new()
 if(-not [BismClick]::GetWindowRect($p.MainWindowHandle,[ref]$r)){return}
 $w=$r.Right-$r.Left;$h=$r.Bottom-$r.Top
 if($w -lt 500 -or $h -lt 400){return}
 $file=Join-Path $out ('DIAGNOSTIC_'+$name+'.png')
 $bmp=[System.Drawing.Bitmap]::new($w,$h)
 $graphics=[Drawing.Graphics]::FromImage($bmp)
 try {
  $graphics.CopyFromScreen($r.Left,$r.Top,0,0,$bmp.Size)
  $bmp.Save($file,[Drawing.Imaging.ImageFormat]::Png)
  Say ('DIAGNOSTIC_SAVED '+$file)
 } finally {$graphics.Dispose();$bmp.Dispose()}
}
function Image([string]$name) {
 SafeDialogs
 $block=@(OtherWindows|Where-Object{$_.title -match '^(Import Process|Open Process|Create Folder|Welcome to RapidMiner Studio!|Save Changes)$'})
 if($block.Count){Say ('CAPTURE_BLOCKED_DIALOG '+$name+' '+$block[0].title);return}
 $w=FocusGui
 $p=Join-Path $out ($name+'.png')
 $bmp=[System.Drawing.Bitmap]::new($w.width,$w.height)
 $g=[Drawing.Graphics]::FromImage($bmp)
 try{$g.CopyFromScreen($w.rect.Left,$w.rect.Top,0,0,$bmp.Size);$bmp.Save($p,[Drawing.Imaging.ImageFormat]::Png)}
 finally{$g.Dispose();$bmp.Dispose()}
 $hash=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash
 if($script:seen.ContainsKey($hash)){
  Remove-Item -LiteralPath $p -Force
  Say ('DUPLICATE '+$name)
  return
 }
 $script:seen[$hash]=$name
 [void]$script:images.Add($name+'.png')
 Say ('IMAGE_REVIEW '+$name)
}
function GbtTitle {
 $p=GetGui
 return ($p -and $p.MainWindowTitle -match 'GradientBoostedTrees_Full\.rmp')
}
function WaitGbt([int]$seconds) {
 $stop=(Get-Date).AddSeconds($seconds)
 do {
  if(GbtTitle){Say ('GBT_TITLE_CONFIRMED '+(GetGui).MainWindowTitle);return $true}
  Start-Sleep -Seconds 2
 }while((Get-Date) -lt $stop)
 return $false
}
try {
 Say ('BEGIN PROJECT='+$Root)
 ClearOldCompletion
 $script:state='PARTIAL_DONE_REVIEW_REQUIRED'
 $okGBT=$false;$okNB=$false
 try{$okGBT=CollectModel 'GBT'}catch{Say ('GBT_ERROR '+$_.Exception.Message)}
 try{$okNB=CollectModel 'NB'}catch{Say ('NB_ERROR '+$_.Exception.Message)}
 if($okGBT -and $okNB -and $script:images.Count -gt 0){$script:state='EXECUTION_COMPLETE_REVIEW_REQUIRED'}
 if((-not $okGBT -and -not $okNB) -or $script:images.Count -eq 0){$script:state='FAILED'}
 Say 'SQL_AND_SSIS_NOT_VERIFIED'

} catch{
 Say ('ERROR '+$_.Exception.Message+' LINE='+$_.InvocationInfo.ScriptLineNumber)
 try{Image '99_Error_Diagnostic'}catch{}
} finally {
 $zip=$out+'.zip'
 $status=Join-Path $out 'STATUS.txt'
 [IO.File]::WriteAllLines($status,[string[]]@(
  'EXECUTION_FINISHED',
  ('STATUS='+$script:state),
  ('IMAGES='+$script:images.Count),
  'All images are candidates until visually reviewed against RapidMiner UI.'
 ),[Text.UTF8Encoding]::new($false))
 try{Compress-Archive -Path (Join-Path $out '*') -DestinationPath $zip -CompressionLevel Optimal -Force}catch{Say ('ZIP_ERROR '+$_.Exception.Message)}
 Say ('EXECUTION_FINISHED status='+$script:state+' images='+$script:images.Count)
 Write-Host ('RESULT_ZIP='+$zip)
 try{[System.Media.SystemSounds]::Asterisk.Play()}catch{}
 $msg='Capture finished.'+[Environment]::NewLine+('Status: '+$script:state)+[Environment]::NewLine+
 ('Images: '+$script:images.Count)+[Environment]::NewLine+('ZIP: '+$zip)
 [void][System.Windows.Forms.MessageBox]::Show($msg,'BISM2202 Capture Finished',
  [System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information)
}
