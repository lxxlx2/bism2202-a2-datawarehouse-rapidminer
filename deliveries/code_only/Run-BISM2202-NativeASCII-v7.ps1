param([string]$ProjectRoot = '', [int]$TimeoutMinutes = 12)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$script:logFile = $null
$script:manifest = [ordered]@{ generated_at=(Get-Date).ToString('o'); source='RapidMiner 10.3 native batch'; stages=@(); output=''; status='STARTED' }

function Say([string]$message) {
  $line = (Get-Date -Format 'HH:mm:ss') + ' ' + $message
  Write-Host $line
  if ($script:logFile) { Add-Content -LiteralPath $script:logFile -Value $line -Encoding UTF8 }
}
function Stage([string]$name,[string]$state,[string]$detail) {
  $script:manifest.stages += [ordered]@{name=$name;state=$state;detail=$detail}
  Say ($name + ' ' + $state + ' ' + $detail)
}
function LocateProject {
  if ($ProjectRoot) {
    $r=(Resolve-Path -LiteralPath $ProjectRoot).Path
    if (Test-Path -LiteralPath (Join-Path $r 'rapidminer\data\BISM2202_A2_Loan_Data_Set_RapidMiner2026S2.csv')) { return $r }
    throw 'PROJECT_ROOT_INVALID'
  }
  $candidates = @('H:\', $env:OneDrive, $env:OneDriveCommercial, (Get-Location).Path)
  foreach ($r in $candidates) {
    if (-not $r -or -not (Test-Path -LiteralPath $r)) { continue }
    $items = @($r)
    $items += @(Get-ChildItem -LiteralPath $r -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'BISM2202*' } | Select-Object -ExpandProperty FullName)
    foreach ($x in $items) {
      if (Test-Path -LiteralPath (Join-Path $x 'rapidminer\data\BISM2202_A2_Loan_Data_Set_RapidMiner2026S2.csv')) { return $x }
    }
  }
  throw 'PROJECT_NOT_FOUND: Specify -ProjectRoot.'
}
function LocateBatch {
  $options = @(
    'C:\Program Files\RapidMiner\RapidMiner Studio\scripts\rapidminer-batch.bat',
    'C:\Program Files\RapidMiner\RapidMiner Studio 10.3\scripts\rapidminer-batch.bat',
    'C:\Program Files\Altair\RapidMiner Studio\scripts\rapidminer-batch.bat'
  )
  foreach ($p in $options) { if (Test-Path -LiteralPath $p) { return $p } }
  throw 'RAPIDMINER_BATCH_NOT_FOUND: RapidMiner 10.3 batch script unavailable.'
}
function Get-ExitReason([string]$err,[string]$out) {
  $content = ''
  foreach ($p in @($err,$out)) { if (Test-Path -LiteralPath $p) { $content += [IO.File]::ReadAllText($p) + "`n" } }
  if ($content -match 'Cannot read process definition file|Cannot read process setup|FileNotFoundException') { return 'PROCESS_FILE_UNREADABLE' }
  if ($content -match 'license|licence') { if ($content -match '(?i)(exceeded|denied|invalid|not licensed|expired)') { return 'LICENSE_FAILURE_POSSIBLE' } }
  if ($content -match '(?i)(process failed|operator exception|usererror|processsetupfailed|exception in thread)') { return 'NATIVE_OPERATOR_ERROR' }
  return 'NATIVE_EXPORT_MISSING_OR_UNKNOWN'
}
function CopyResults([string]$code,[string]$work,[string]$destination) {
  $names=@($code+'_CV_Metrics.csv',$code+'_Holdout_Metrics.csv',$code+'_Holdout_Predictions.csv')
  $missing=@()
  foreach ($name in $names) {
    $p=Join-Path $work $name
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { $missing += $name; continue }
    if ((Get-Item -LiteralPath $p).Length -le 12) { $missing += $name; continue }
  }
  if ($missing.Count -gt 0) { return $missing }
  foreach ($name in $names) { Copy-Item -LiteralPath (Join-Path $work $name) -Destination (Join-Path $destination $name) }
  return @()
}

$work = $null
$out = $null
try {
  if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'WINDOWS_ONLY' }
  $project = LocateProject
  $outputRoot = Join-Path $project 'evidence\rapidminer'
  $out = Join-Path $outputRoot ('native_ascii_' + $stamp)
  New-Item -ItemType Directory -Path $out -Force | Out-Null
  $script:logFile = Join-Path $out 'execution.log'
  $script:manifest.output=$out
  Say ('PROJECT=' + $project)
  Say ('RESULTS=' + $out)

  $work = Join-Path $env:TEMP ('BISM2202_NATIVE_' + $stamp)
  if ($work -match '[^\x20-\x7E]') {
    $work = Join-Path 'C:\Windows\Temp' ('BISM2202_NATIVE_' + $stamp)
  }
  if ($work -match '[^\x20-\x7E]') { throw 'NO_ASCII_WORK_PATH' }
  New-Item -ItemType Directory -Path $work -Force | Out-Null
  Say ('ASCII_WORKSPACE=' + $work)

  $teacher = Join-Path $project 'rapidminer\data\BISM2202_A2_Loan_Data_Set_RapidMiner2026S2.csv'
  $expectedHash = 'B333ABEF401D01DCE2B0115B65649400238C01D9362B328C8CA1C4C19876D00A'
  $actualHash = (Get-FileHash -LiteralPath $teacher -Algorithm SHA256).Hash
  if ($actualHash -ne $expectedHash) { throw 'TEACHER_CSV_SHA256_MISMATCH' }
  Copy-Item -LiteralPath $teacher -Destination (Join-Path $work 'teacher.csv')
  Stage 'teacher_csv' 'PASS' ('sha256=' + $actualHash)

  $batch=LocateBatch
  Stage 'rapidminer_batch' 'FOUND' $batch

  $oldRun=Join-Path $outputRoot 'run_20261025_192403'
  $oldZip=Join-Path $project 'BISM2202_Evidence_20261025_192403.zip'
  $unpacked=$null
  if (-not (Test-Path -LiteralPath (Join-Path $oldRun 'GBT_AutoEvidence.rmp'))) {
    if (Test-Path -LiteralPath $oldZip) {
      $unpacked=Join-Path $work 'prior_zip'
      Expand-Archive -LiteralPath $oldZip -DestinationPath $unpacked -Force
      $oldRun=$unpacked
    } else { throw 'PRIOR_AUTOEVIDENCE_NOT_FOUND: old RMP files or old evidence ZIP required' }
  }

  $failed=$false
  foreach ($code in @('GBT','NB')) {
    $source=Join-Path $oldRun ($code+'_AutoEvidence.rmp')
    if (-not (Test-Path -LiteralPath $source)) {
      $candidates=@(Get-ChildItem -LiteralPath $oldRun -Filter ($code+'_AutoEvidence.rmp') -Recurse -File -ErrorAction SilentlyContinue)
      if ($candidates.Count -gt 0) { $source=$candidates[0].FullName }
    }
    if (-not (Test-Path -LiteralPath $source)) { Stage $code 'BLOCKED' 'AUTOEVIDENCE_RMP_MISSING'; $failed=$true; continue }
    [xml]$doc=Get-Content -LiteralPath $source -Raw -Encoding UTF8
    $macroValues=@{
      source_csv=(Join-Path $work 'teacher.csv');
      cv_results_path=(Join-Path $work ($code+'_CV_Metrics.csv'));
      holdout_results_path=(Join-Path $work ($code+'_Holdout_Metrics.csv'));
      holdout_predictions_path=(Join-Path $work ($code+'_Holdout_Predictions.csv'))
    }
    foreach ($k in $macroValues.Keys) {
      $node=$doc.SelectSingleNode('/process/context/macros/macro[key="'+$k+'"]')
      if (-not $node) { throw ('RMP_MACRO_NOT_FOUND_'+$code+'_'+$k) }
      $node.SelectSingleNode('./value').InnerText=$macroValues[$k]
    }
    $processFile=Join-Path $work ($code+'_Native.rmp')
    $doc.Save($processFile)
    [xml]$verify=Get-Content -LiteralPath $processFile -Raw -Encoding UTF8
    if ($verify.OuterXml -match 'BISM2202 \?\?' -or $verify.OuterXml -match '[^\x20-\x7E]') { throw 'NON_ASCII_REFERENCE_REMAINS' }
    Copy-Item -LiteralPath $processFile -Destination (Join-Path $out ($code+'_Native.rmp'))
    Stage $code 'PREPARED' $processFile

    $cmdFile=Join-Path $work ('run_'+$code+'.cmd')
    $line='@echo off' + "`r`n" + 'call "' + $batch + '" -f "' + $processFile + '"' + "`r`n" + 'exit /b %ERRORLEVEL%' + "`r`n"
    [IO.File]::WriteAllText($cmdFile,$line,(New-Object Text.ASCIIEncoding))
    $stdout=Join-Path $out ($code+'_NativeBatch.log')
    $stderr=Join-Path $out ($code+'_NativeBatch.err')
    $p=Start-Process -FilePath 'cmd.exe' -ArgumentList @('/d','/c',('"'+$cmdFile+'"')) -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr -WindowStyle Hidden
    $deadline=(Get-Date).AddMinutes($TimeoutMinutes)
    $lastProgress=Get-Date
    while (-not $p.HasExited -and (Get-Date) -lt $deadline) {
      Start-Sleep -Seconds 5
      $p.Refresh()
      if (((Get-Date)-$lastProgress).TotalSeconds -ge 30) { Say ($code+' BATCH_STILL_RUNNING elapsed_seconds='+[int]((Get-Date)-($deadline.AddMinutes(-$TimeoutMinutes))).TotalSeconds); $lastProgress=Get-Date }
    }
    if (-not $p.HasExited) {
      try { & taskkill.exe /PID $p.Id /T /F *> $null } catch { try { $p.Kill() } catch {} }
      Stage $code 'TIMEOUT' ('batch exceeded '+$TimeoutMinutes+' minutes; check logs')
      $failed=$true; continue
    }
    $missing=@(CopyResults $code $work $out)
    if ($missing.Count -eq 0) {
      Stage $code 'CSV_PASS' ('exit='+$p.ExitCode+'; three real CSV exports copied to local evidence')
    } else {
      $reason=Get-ExitReason $stderr $stdout
      Stage $code 'FAILED' ('exit='+$p.ExitCode+'; missing='+($missing -join ',')+'; reason='+$reason)
      $failed=$true
    }
  }
  $script:manifest.status=if($failed){'PARTIAL_OR_FAILED'}else{'NATIVE_CSV_PASS'}
} catch {
  $script:manifest.status='FAILED'
  Stage 'fatal' 'FAILED' $_.Exception.Message
} finally {
  if ($out -and (Test-Path -LiteralPath $out)) {
    $manifestPath=Join-Path $out 'manifest.json'
    $script:manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    $archive=Join-Path (Split-Path -Parent $out) ('BISM2202_NativeASCII_'+$stamp+'.zip')
    try {
      Compress-Archive -Path (Join-Path $out '*') -DestinationPath $archive -CompressionLevel Optimal -Force
      Say ('LOCAL_EVIDENCE_ZIP=' + $archive)
    } catch { Say ('ZIP_CREATION_FAILED='+$_.Exception.Message) }
  }
  if ($work -and (Test-Path -LiteralPath $work)) { Say ('ASCII_WORKSPACE_KEPT=' + $work) }
}
if ($script:manifest.status -eq 'NATIVE_CSV_PASS') { Write-Host 'NATIVE_CSV_PASS' -ForegroundColor Green; exit 0 }
Write-Host ('RESULT=' + $script:manifest.status) -ForegroundColor Yellow
exit 2