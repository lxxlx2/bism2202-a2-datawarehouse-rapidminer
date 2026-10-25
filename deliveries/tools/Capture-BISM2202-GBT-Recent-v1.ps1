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
}
'@
if(-not (Test-Path -LiteralPath $Root -PathType Container)){throw 'PROJECT_ROOT_NOT_FOUND'}
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
$out=Join-Path $Root ('GBT_GUI_Review_'+$stamp)
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
function Image([string]$name) {
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
 # Ctrl+O is observed to display "Welcome to RapidMiner Studio",
 # with two "GradientBoostedTrees_Full.rmp" entries in the Recent list.
 if(-not (GbtTitle)){
  $w=FocusGui
  [System.Windows.Forms.SendKeys]::SendWait('^o')
  Start-Sleep -Seconds 3
  Image '01_Recent_Diagnostic'
  # In the observed 1450x870 school desktop: first GBT row at (410,342).
  ClickXY .285 .395
  if(-not (WaitGbt 16)){
   # If switching from an edited process triggers Save Changes, preserve it.
   if([BismClick]::FindWindow($null,'Save Changes') -ne [IntPtr]::Zero){
    throw 'SAVE_CHANGES_DIALOG: user work is preserved; no automatic discard'
   }
   # Second GBT entry in the same Recent list at (410,367).
   ClickXY .285 .422
   if(-not (WaitGbt 17)){throw 'GBT_RECENT_ENTRY_NOT_OPENED'}
  }
 }
 $script:state='GBT_WINDOW_CONFIRMED'
 # A verified GBT window title is mandatory before classifying screenshots.
 ClickXY .401 .083
 Start-Sleep -Seconds 2
 Image '02_GBT_Design_Overall_REVIEW'
 # Optional extra fit-to-view action if the canvas is offset.
 try{ClickXY .847 .177;Image '03_GBT_Design_Fit_REVIEW'}
 catch{Say ('FIT_VIEW_UNVERIFIED '+$_.Exception.Message)}
 # CV node location can vary with zoom; preserve candidate without claiming inner view.
 try{ClickXY .600 .287 2;Image '04_GBT_CV_Subprocess_CANDIDATE_REVIEW'}
 catch{Say ('CV_NAVIGATION_UNVERIFIED '+$_.Exception.Message)}
 # Return to Design and click RapidMiner's native Run button.
 ClickXY .400 .083
 ClickXY .155 .083
 Say 'GBT_GUI_RUN_REQUESTED'
 # Native batch GBT completed in approx 29s; the GUI can take longer.
 Start-Sleep -Seconds 75
 if(-not (GbtTitle)){throw 'GBT_TITLE_LOST_AFTER_RUN'}
 ClickXY .455 .083
 Start-Sleep -Seconds 2
 Image '05_GBT_Results_Overview_REVIEW'
 foreach($pair in @(
  @(.30,.135),@(.60,.135),@(.30,.173),@(.61,.173),@(.46,.135),@(.77,.135)
 )){
  try{
   ClickXY $pair[0] $pair[1]
   Image ('06_GBT_ResultTab_'+('{0:D2}' -f ($script:images.Count))+'_REVIEW')
  }catch{Say ('RESULT_TAB_UNVERIFIED '+$_.Exception.Message)}
 }
 $script:state='GBT_GUI_CAPTURE_REVIEW'
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
 [void][System.Windows.Forms.MessageBox]::Show($msg,'BISM2202 GBT Capture Finished',
  [System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information)
}
