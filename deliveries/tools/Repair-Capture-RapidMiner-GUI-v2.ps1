param([string]$Root = '')
$ErrorActionPreference = 'Stop'
if (-not $Root) {
  $candidates = @(Get-ChildItem -LiteralPath 'H:\' -Directory -Filter 'BISM2202_Ready_*' -ErrorAction SilentlyContinue |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'program\scripts\Capture-RapidMiner-Windows.ps1') -PathType Leaf } |
    Sort-Object LastWriteTime -Descending)
  if ($candidates.Count -eq 0) { throw 'READY_PROJECT_NOT_FOUND_ON_H_DRIVE' }
  $Root = $candidates[0].FullName
}
$original = Join-Path $Root 'program\scripts\Capture-RapidMiner-Windows.ps1'
if (-not (Test-Path -LiteralPath $original -PathType Leaf)) { throw 'CAPTURE_SCRIPT_NOT_FOUND' }
$content = [IO.File]::ReadAllText($original)
$target1 = 'ShowWindow($p.MainWindowHandle,9)'
$target2 = @'
if($r.Right-$r.Left -lt 600 -or $r.Bottom-$r.Top -lt 400){throw 'WINDOW_NOT_FULL_SIZE'}
'@
$target2=$target2.Trim()
$target3 = @'
if($null -eq $p -or $p.MainWindowTitle -notmatch $wanted){Note ('MODEL_WINDOW_NOT_CONFIRMED '+$code);return}
'@
$target3=$target3.Trim()
foreach ($t in @($target1,$target2,$target3)) {
  if (-not $content.Contains($t)) { throw 'UNEXPECTED_BASE_CAPTURE_SCRIPT: refusing unsafe patch' }
}
$content = $content.Replace($target1,'ShowWindow($p.MainWindowHandle,3)')
$replacement2 = @'
 $script:virtualCapture=$false
 if($r.Right-$r.Left -lt 600 -or $r.Bottom-$r.Top -lt 400){
   [void][RMNativeWindow]::ShowWindow($p.MainWindowHandle,3)
   Start-Sleep -Milliseconds 900
   [void][RMNativeWindow]::GetWindowRect($p.MainWindowHandle,[ref]$r)
   if($r.Right-$r.Left -lt 600 -or $r.Bottom-$r.Top -lt 400){
     $screen=[System.Windows.Forms.SystemInformation]::VirtualScreen
     $r.Left=$screen.Left;$r.Top=$screen.Top;$r.Right=$screen.Right;$r.Bottom=$screen.Bottom
     $script:virtualCapture=$true
     Note ('REMOTE_WINDOW_SIZE_FALLBACK: screenshot only; UI location not verified')
   }
 }
'@
$content=$content.Replace($target2,$replacement2)
$targetClick = '$r=Rect $p; $x=$r.Left+'
$replacementClick = @'
$r=Rect $p; if($script:virtualCapture){throw 'WINDOW_NOT_READY_FOR_CLICK'}; $x=$r.Left+
'@
$replacementClick=$replacementClick.Trim()
if (-not $content.Contains($targetClick)) {throw 'CLICK_FUNCTION_NOT_FOUND'}
$content=$content.Replace($targetClick,$replacementClick)
$oldPNG = '$path=Join-Path $out $name'
$newPNG = @'
$path=Join-Path $out $(if($script:virtualCapture){'DIAGNOSTIC_'+$name}else{$name})
'@
$newPNG=$newPNG.Trim()
if (-not $content.Contains($oldPNG)) {throw 'SCREENSHOT_FUNCTION_NOT_FOUND'}
$content=$content.Replace($oldPNG,$newPNG)
$replacement3=@'
 if($null -eq $p -or $p.MainWindowTitle -notmatch $wanted){
   $existing=Find-RM ''
   if($existing){
     try {
       Fore $existing
       $ready=PrepareModel $code
       [System.Windows.Forms.Clipboard]::SetText($ready)
       [System.Windows.Forms.SendKeys]::SendWait('^o')
       Start-Sleep -Seconds 2
       [System.Windows.Forms.SendKeys]::SendWait('^v')
       [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
       Note ('OPEN_GUI_SHORTCUT_REQUESTED '+$code)
       $limit=(Get-Date).AddSeconds($WaitSeconds)
       do {
         Start-Sleep -Seconds 2
         $p=Find-RM $code
       } while(($null -eq $p -or $p.MainWindowTitle -notmatch $wanted) -and (Get-Date) -lt $limit)
     } catch {Note ('OPEN_GUI_SHORTCUT_ERROR '+$code+' '+$_.Exception.Message)}
   }
 }
 if($null -eq $p -or $p.MainWindowTitle -notmatch $wanted){
   Note ('MODEL_WINDOW_NOT_CONFIRMED '+$code)
   return
 }
'@
$content=$content.Replace($target3,$replacement3)
$fixed = Join-Path $Root 'program\scripts\Capture-RapidMiner-Windows-Fixed-v2.ps1'
[IO.File]::WriteAllText($fixed,$content,[Text.UTF8Encoding]::new($false))
$tokens=$null;$errors=$null
[void][System.Management.Automation.Language.Parser]::ParseFile($fixed,[ref]$tokens,[ref]$errors)
if($errors.Count -gt 0){
  Write-Host ('PARSER_ERROR_COUNT='+$errors.Count)
  foreach($e in $errors){Write-Host ($e.Message+' line='+$e.Extent.StartLineNumber)}
  throw 'PATCHED_SCRIPT_SYNTAX_ERROR'
}
Write-Host ('PATCHED_SCRIPT='+$fixed)
Write-Host ('PROJECT='+$Root)
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File $fixed -Root $Root
Write-Host ('CAPTURE_CHILD_EXITCODE='+$LASTEXITCODE)
