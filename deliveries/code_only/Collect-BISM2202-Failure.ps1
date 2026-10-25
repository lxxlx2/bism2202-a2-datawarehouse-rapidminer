param([string]$ProjectRoot = '')
$ErrorActionPreference = 'Stop'
$runName = 'run_20261025_192403'
$roots = @()
if ($ProjectRoot) { $roots += $ProjectRoot }
foreach ($r in @('H:\', $env:OneDriveCommercial, $env:OneDrive)) {
 if ($r -and (Test-Path -LiteralPath $r)) { $roots += $r }
}
$project = $null
foreach ($r in $roots) {
 $candidates = @($r)
 try { $candidates += @(Get-ChildItem -LiteralPath $r -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'BISM2202*' } | Select-Object -ExpandProperty FullName) } catch {}
 foreach ($candidate in $candidates) {
  if (Test-Path -LiteralPath (Join-Path $candidate ('evidence\rapidminer\' + $runName))) {
   $project = $candidate; break
  }
 }
 if ($project) { break }
}
if (-not $project) { throw 'RUN_FOLDER_NOT_FOUND: specify -ProjectRoot or check H: drive.' }
$source = Join-Path $project ('evidence\rapidminer\' + $runName)
$out = Join-Path $project ('BISM2202_DIAGNOSTIC_' + $runName)
New-Item -ItemType Directory -Path $out -Force | Out-Null
$include = @('*.log','*.err','*.txt','manifest.json','ready_*.rmp','*_AutoEvidence.rmp','*_RUN.rmp','*_Diagnostic*.png','*_Import_Failed.png')
$copied = @()
foreach ($pattern in $include) {
 foreach ($item in @(Get-ChildItem -LiteralPath $source -File -Filter $pattern -ErrorAction SilentlyContinue)) {
  if (-not (Test-Path -LiteralPath (Join-Path $out $item.Name))) {
   Copy-Item -LiteralPath $item.FullName -Destination (Join-Path $out $item.Name)
   $copied += $item.Name
  }
 }
}
if ($copied.Count -eq 0) { throw 'NO_DIAGNOSTIC_FILES_FOUND' }
$summary = Join-Path $out 'summary.txt'
$lines = @('PROJECT=' + $project, 'SOURCE=' + $source, 'FILES=' + $copied.Count, 'COPIED=' + ($copied -join '; '))
foreach ($name in @('GBT_NativeBatch.log','GBT_NativeBatch.err','NB_NativeBatch.log','NB_NativeBatch.err','GBT_batch_stdout.log','GBT_batch_stderr.log','NB_batch_stdout.log','NB_batch_stderr.log','execution.log','run.log')) {
 $file = Join-Path $source $name
 if (Test-Path -LiteralPath $file) {
  $lines += '--- ' + $name + ' ---'
  $lines += @(Get-Content -LiteralPath $file -Tail 80 -ErrorAction SilentlyContinue)
 }
}
[IO.File]::WriteAllLines($summary,[string[]]$lines,[Text.UTF8Encoding]::new($true))
$zip = $out + '.zip'
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
Compress-Archive -Path (Join-Path $out '*') -DestinationPath $zip
Write-Host 'DIAGNOSTIC_ZIP_CREATED' -ForegroundColor Green
Write-Host ('ZIP=' + $zip)
Write-Host ('FILES=' + $copied.Count)
Write-Host 'Review logs for paths or personal data before sharing the archive.'
