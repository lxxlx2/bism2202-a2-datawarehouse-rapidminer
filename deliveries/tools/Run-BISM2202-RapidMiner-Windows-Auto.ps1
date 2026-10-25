param(
 [string]$Project = '',
 [int]$RunWaitSeconds = 240,
 [switch]$NoRun,
 [switch]$DiagnosticsOnly
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class B2202Gui {
 [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left,Top,Right,Bottom; }
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT rect);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
 [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint cButtons, UIntPtr extraInfo);
 [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc fn, IntPtr lParam);
 public delegate bool EnumProc(IntPtr h, IntPtr lParam);
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, System.Text.StringBuilder text, int max);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
}
'@
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$script:work = $null
$script:log = $null
$script:screenshots = @()
$script:errors = New-Object 'System.Collections.Generic.List[string]'
$script:warns = New-Object 'System.Collections.Generic.List[string]'
function Log([string]$message) {
 $entry = (Get-Date -Format 'HH:mm:ss') + ' ' + $message
 Write-Host $entry
 if ($script:log) { Add-Content -LiteralPath $script:log -Encoding UTF8 -Value $entry }
}
function Warn([string]$message) { $script:warns.Add($message); Log ('WARN '+$message) }
function Error-Record([string]$message) { $script:errors.Add($message); Log ('ERROR '+$message) }
function Find-Source {
 if ($Project -and (Test-Path -LiteralPath $Project -PathType Container)) {
  if (Test-Path -LiteralPath (Join-Path $Project 'GradientBoostedTrees_Full.rmp')) { return (Resolve-Path -LiteralPath $Project).Path }
  if (Test-Path -LiteralPath (Join-Path $Project 'rapidminer\GradientBoostedTrees_Full.rmp')) { return (Resolve-Path -LiteralPath (Join-Path $Project 'rapidminer')).Path }
 }
 $roots = @('H:\','D:\', $env:OneDriveCommercial,$env:OneDrive, (Get-Location).Path,(Join-Path $env:USERPROFILE 'Documents')) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) }
 $seen = @{}
 foreach($root in $roots) {
  $queue = New-Object System.Collections.Queue
  $queue.Enqueue(@($root,0))
  while($queue.Count) {
   $it=$queue.Dequeue(); $dir=[string]$it[0]; $depth=[int]$it[1]
   if($seen.ContainsKey($dir.ToLowerInvariant())){continue};$seen[$dir.ToLowerInvariant()]=$true
   if(Test-Path -LiteralPath (Join-Path $dir 'GradientBoostedTrees_Full.rmp') -PathType Leaf){return $dir}
   if($depth -ge 4){continue}
   try {$children=@(Get-ChildItem -LiteralPath $dir -Directory -ErrorAction Stop)}catch{continue}
   foreach($child in $children) {
    if($child.Attributes -band [IO.FileAttributes]::ReparsePoint){continue}
    if($child.Name -match '^(Windows|Program Files|Program Files \(x86\)|Users|ProgramData|AppData|node_modules|\.git|\.venv)$'){continue}
    if($depth -eq 0 -and $root -match '^[A-Z]:\\$' -and $child.Name -notmatch '(BISM|2202|OneDrive|同事|副本|Documents)'){continue}
    $queue.Enqueue(@($child.FullName,$depth+1))
   }
  }
 }
 throw '找不到 GradientBoostedTrees_Full.rmp；请在 rapidminer 文件夹中运行，或通过 -Project 指定路径。'
}
function Repair-Process([string]$src,[string]$dest) {
 $xml=New-Object System.Xml.XmlDocument;$xml.PreserveWhitespace=$true;$xml.Load($src)
 $body=$xml.SelectSingleNode('/process/operator/process')
 if(-not $body){throw "XML结构缺失 $src"}
 $cvs=@($body.SelectNodes('./operator[@class="x_validation"]'))
 if($cvs.Count -ne 1){throw "需要单模型Full流程 $src"}
 $cv=$cvs[0];$cvname=$cv.GetAttribute('name')
 $splits=@($body.SelectNodes('./operator[@class="split_data"]'))
 if($splits.Count -ne 1){throw 'Split Data数量不正确'}
 $ratios=@($splits[0].SelectNodes('./enumeration[@key="partitions"]/parameter') | ForEach-Object { $_.GetAttribute('value') })
 if($ratios.Count -ne 2 -or $ratios[0] -ne '0.75' -or $ratios[1] -ne '0.25'){throw '75/25划分参数不匹配，拒绝推断修改'}
 $cvN=$cv.SelectSingleNode('./parameter[@key="number_of_validations"]')
 if(-not $cvN -or $cvN.GetAttribute('value') -ne '5'){throw '五折交叉验证参数不匹配'}
 $app=@($body.SelectNodes('./operator[@class="apply_model"]'))
 if($app.Count -ne 1){throw 'Apply Model数量不正确'}
 $appname=$app[0].GetAttribute('name')
 $wires=@($body.SelectNodes('./connect'))
 $toApp=@($wires | Where-Object {$_.GetAttribute('from_op') -eq $cvname -and $_.GetAttribute('from_port') -eq 'model' -and $_.GetAttribute('to_op') -eq $appname -and $_.GetAttribute('to_port') -eq 'model'})
 if($toApp.Count -ne 1){throw '交叉验证模型没有接到最终测试，拒绝自动猜测连接'}
 $removed=0;$added=0
 foreach($c in $wires) {
  if($c.GetAttribute('from_op') -eq $cvname -and $c.GetAttribute('from_port') -eq 'model' -and
     -not $c.HasAttribute('to_op') -and $c.GetAttribute('to_port') -match '^result ') {
   $port=$c.GetAttribute('to_port');[void]$body.RemoveChild($c);$removed++
   $existing=@($body.SelectNodes('./connect') | Where-Object { -not $_.HasAttribute('to_op') -and $_.GetAttribute('to_port') -eq $port })
   if($existing.Count -eq 0){
    $new=$xml.CreateElement('connect');$new.SetAttribute('from_op',$appname);$new.SetAttribute('from_port','model');$new.SetAttribute('to_port',$port);[void]$body.AppendChild($new);$added++
   }
  }
 }
 $xml.Save($dest)
 $verified=New-Object System.Xml.XmlDocument;$verified.Load($dest)
 Log "REPAIRED $([IO.Path]::GetFileName($src)) removed=$removed added=$added"
}
function Rapid-Process {
 $apps=@(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero -and $_.MainWindowTitle -match 'RapidMiner|AI Studio' })
 if($apps.Count -lt 1){throw '学校Windows桌面没有找到已打开的RapidMiner Studio窗口'}
 return $apps[0]
}
function Focus-Rapid {
 $p=Rapid-Process
 [void][B2202Gui]::ShowWindow($p.MainWindowHandle,3)
 [void][B2202Gui]::SetForegroundWindow($p.MainWindowHandle)
 Start-Sleep -Milliseconds 500
 return $p
}
function Window-Rect {
 $p=Rapid-Process
 $r=New-Object B2202Gui+RECT
 if(-not [B2202Gui]::GetWindowRect($p.MainWindowHandle,[ref]$r)){throw '无法读取RapidMiner窗口坐标'}
 if(($r.Right-$r.Left) -lt 950 -or ($r.Bottom-$r.Top) -lt 610){throw 'RapidMiner窗口过小，至少需要950x610'}
 return $r
}
function Win-Click([double]$xx,[double]$yy,[int]$times=1) {
 $r=Window-Rect
 $x=$r.Left+[int]$xx;$y=$r.Top+[int]$yy
 [void][B2202Gui]::SetCursorPos($x,$y)
 for($j=0;$j -lt $times;$j++){
  [B2202Gui]::mouse_event(0x0002,0,0,0,[UIntPtr]::Zero)
  [B2202Gui]::mouse_event(0x0004,0,0,0,[UIntPtr]::Zero)
  Start-Sleep -Milliseconds 85
 }
 Start-Sleep -Milliseconds 380
}
function Type-Key([string]$key){[System.Windows.Forms.SendKeys]::SendWait($key);Start-Sleep -Milliseconds 400}
function Shot([string]$name,[string]$stage) {
 $r=Window-Rect;$w=$r.Right-$r.Left;$h=$r.Bottom-$r.Top
 $path=Join-Path $script:work ($name+'.png')
 $bmp=New-Object System.Drawing.Bitmap($w,$h)
 $g=[System.Drawing.Graphics]::FromImage($bmp)
 try { $g.CopyFromScreen($r.Left,$r.Top,0,0,$bmp.Size);$bmp.Save($path,[System.Drawing.Imaging.ImageFormat]::Png) }
 finally {$g.Dispose();$bmp.Dispose()}
 if((Get-Item -LiteralPath $path).Length -lt 15000){Warn "SCREEN_SMALL $name 可能是空白截图"}
 $script:screenshots+=@{file=$name+'.png';stage=$stage;sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash}
 Log "SCREEN $name [$stage] $path"
}
function Check-Modal {
 $script:modalTitles=New-Object 'System.Collections.Generic.List[string]'
 $fn=[B2202Gui+EnumProc]{param([IntPtr]$h,[IntPtr]$l)
  if([B2202Gui]::IsWindowVisible($h)) {
   $s=New-Object System.Text.StringBuilder(260)
   [void][B2202Gui]::GetWindowText($h,$s,260)
   if($s.ToString() -match 'Process Import Messages|Errors|Import Messages'){$script:modalTitles.Add($s.ToString())}
  }
  return $true
 }
 [void][B2202Gui]::EnumWindows($fn,[IntPtr]::Zero)
 return @($script:modalTitles)
}
function Tab-Pixel {
 $r=Window-Rect
 # Small pixels on the inactive/active Results tab, away from lettering.
 $bmp=New-Object System.Drawing.Bitmap(1,1)
 $g=[System.Drawing.Graphics]::FromImage($bmp)
 try { $g.CopyFromScreen(($r.Left+695),($r.Top+59),0,0,$bmp.Size);return $bmp.GetPixel(0,0).ToArgb() }
 finally { $g.Dispose();$bmp.Dispose() }
}
function Wait-ForResults([string]$model,[int]$timeout,[int]$initialPixel) {
 $deadline=(Get-Date).AddSeconds($timeout)
 $streak=0
 while((Get-Date) -lt $deadline) {
  Start-Sleep -Seconds 3
  $modal=@(Check-Modal)
  if($modal.Count -gt 0){Warn "GUI_MODAL $model : $($modal -join '|')";Shot ($model+'_runtime_dialog') 'possible_error';return $false}
  try{$pix=Tab-Pixel}catch{Warn "RESULT_TAB_PIXEL_UNAVAILABLE $($_.Exception.Message)";return $false}
  if($pix -ne $initialPixel){$streak++}else{$streak=0}
  if($streak -ge 3){Log "RESULT_TAB_SWITCH_DETECTED $model (pixel heuristic, not proof of model success)";return $true}
 }
 Warn "RESULTS_NOT_DETECTED $model after ${timeout}s; probable runtime error or GUI layout changed"
 return $false
}
function Import-File([string]$path) {
 $p=Focus-Rapid
 Log "IMPORT_START $path"
 $clip='';try{$clip=[System.Windows.Forms.Clipboard]::GetText()}catch{}
 try {
  # Official File > Import Process action uses menu mnemonic M.
  Type-Key '%f';Type-Key 'm';Start-Sleep -Milliseconds 1300
  [System.Windows.Forms.Clipboard]::SetText($path)
  Type-Key '^a';Type-Key '^v';Type-Key '{ENTER}'
  Start-Sleep -Seconds 3
  $modal=@(Check-Modal)
  if($modal.Count -gt 0) {
   Shot 'import_message' 'warning_dialog'
   Warn ('IMPORT_MODAL '+($modal -join '|'))
   Type-Key '{ESC}'
  }
  $title=(Rapid-Process).MainWindowTitle
  if($title -notmatch [regex]::Escape([IO.Path]::GetFileName($path))) {
   Error-Record ("IMPORT_NOT_VERIFIED 文件名不在窗口标题中：$title")
   return $false
  }
  Log "IMPORT_TITLE_OK $title";return $true
 }finally{
  try{[System.Windows.Forms.Clipboard]::SetText($clip)}catch{}
 }
}
function Go-Design {
 [void](Focus-Rapid)
 Win-Click 570 70
 Start-Sleep -Milliseconds 500
}
function Go-Results {
 [void](Focus-Rapid)
 Win-Click 686 70
 Start-Sleep -Milliseconds 500
}
function Result-Captures([string]$name) {
 Go-Results
 Shot ($name+'_results_overview') 'results_unclassified'
 $targets=@(
  @{name='holdout_performance';x=375;y=120},
  @{name='fold_performance';x=1080;y=120},
  @{name='model';x=330;y=150},
  @{name='prediction_records';x=1170;y=150}
 )
 foreach($t in $targets){
  Win-Click ([double]$t.x) ([double]$t.y)
  Start-Sleep -Milliseconds 750
  Shot ($name+'_'+$t.name) ('tab_click_approx_'+$t.name)
 }
}
function Run-And-Capture([string]$code,[string]$file) {
 [void](Focus-Rapid)
 if(-not (Import-File $file)){return}
 Go-Design; Shot ($code+'_design') 'design'
 if($DiagnosticsOnly){return}
 if(-not $NoRun) {
  $before=Tab-Pixel
  # Run Process Locally toolbar at roughly 230,70 in the 10.3 Windows UI.
  Win-Click 230 70
  Log "RUN_REQUESTED $code (GUI toolbar click)"
  $resultDetected=Wait-ForResults $code $RunWaitSeconds $before
  if(-not $resultDetected){ Shot ($code+'_needs_attention') 'not_confirmed_results';return }
 }else{Warn "NO_RUN $code user requested to skip training; no result proof";return}
 Result-Captures $code
}
try {
 if([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT){throw '这个脚本只能在学校Windows远程桌面内部运行，不能在Mac终端运行'}
 $root=Find-Source
 $projectDir=Split-Path -Parent $root
 $script:work=Join-Path $projectDir ('evidence\rapidminer\auto_windows_'+$stamp)
 $ready=Join-Path $script:work 'ready_rmp';[void](New-Item -Path $ready -ItemType Directory -Force)
 $script:log=Join-Path $script:work 'execution.log'
 Log "SOURCE=$root";Log "OUTPUT=$script:work";Log 'OS=Windows; Captures from real interactive desktop'
 $files=@(@{name='GradientBoostedTrees_Full.rmp';code='GBT'},@{name='NaiveBayes_Full.rmp';code='NB'})
 foreach($f in $files) {
  $src=Join-Path $root $f.name
  if(-not (Test-Path -LiteralPath $src -PathType Leaf)){throw "缺少 $src"}
  Repair-Process $src (Join-Path $ready $f.name)
 }
 $data=Join-Path $root 'data'
 if(Test-Path -LiteralPath $data -PathType Container){Copy-Item -LiteralPath $data -Destination $ready -Recurse -Force}
 $csv=@(Get-ChildItem -Path (Join-Path $ready 'data') -Filter '*.csv' -File -ErrorAction SilentlyContinue)
 if($csv.Count -lt 1){throw '没有找到教师贷款CSV：请先把data中的原始CSV复制到学校Windows的rapidminer/data目录'}
 $envInfo=[ordered]@{time=$stamp;windows=$env:COMPUTERNAME;user=$env:USERNAME;source=$root;out=$script:work;csv_hash=(Get-FileHash -LiteralPath $csv[0].FullName -Algorithm SHA256).Hash;original_files=@{};repaired_files=@{}}
 foreach($f in $files){$envInfo.original_files[$f.name]=(Get-FileHash -LiteralPath (Join-Path $root $f.name) -Algorithm SHA256).Hash;$envInfo.repaired_files[$f.name]=(Get-FileHash -LiteralPath (Join-Path $ready $f.name) -Algorithm SHA256).Hash}
 $envInfo | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $script:work 'environment.json') -Encoding UTF8
 [void](Focus-Rapid)
 # Require live interactive session; no remote screenshot through Mac mirror or headless process.
 foreach($f in $files){Run-And-Capture $f.code (Join-Path $ready $f.name)}
 $summary=[ordered]@{time=$stamp;capture_count=$script:screenshots.Count;screenshots=$script:screenshots;warnings=@($script:warns);errors=@($script:errors);native_run_verified=$false;notes='Images were captured from school Windows interactive RapidMiner window. Validate content and performance before report use.'}
 $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $script:work 'evidence_manifest.json') -Encoding UTF8
 $zip=Join-Path $projectDir ('BISM2202_RapidMiner_Windows_Evidence_'+$stamp+'.zip')
 Compress-Archive -Path (Join-Path $script:work '*') -DestinationPath $zip -Force
 Log "PACKAGE=$zip"
 $onedrive=$env:OneDriveCommercial
 if(-not $onedrive){$onedrive=$env:OneDrive}
 if($onedrive -and (Test-Path -LiteralPath $onedrive -PathType Container)) {
  $dst=Join-Path $onedrive 'BISM2202_Evidence';[void](New-Item -ItemType Directory -Force -Path $dst)
  $copy=Join-Path $dst ([IO.Path]::GetFileName($zip));Copy-Item -LiteralPath $zip -Destination $copy -Force
  if((Get-FileHash -LiteralPath $copy -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash){Log "ONEDRIVE_LOCAL_COPY=$copy; CLOUD_SYNC_UNVERIFIED"}
 }else{Warn '学校Windows账户没有检测到本地OneDrive同步文件夹，压缩包已保存在项目目录。可在学校OneDrive网页版上传。'}
 Log 'FINISHED: 截图已保存；截图内容和模型指标须检查。'
 if($script:errors.Count -gt 0){exit 2}
 exit 0
} catch {
 $message='FATAL '+$_.Exception.ToString()
 Write-Host $message -ForegroundColor Red
 if($script:log){Add-Content -LiteralPath $script:log -Value $message -Encoding UTF8}
 exit 1
}