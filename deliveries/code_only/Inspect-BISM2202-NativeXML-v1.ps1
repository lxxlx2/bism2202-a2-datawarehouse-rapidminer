param([string]$RunRoot = '')
$ErrorActionPreference = 'Stop'
$roots = @('H:\13','H:\12','H:\',$env:OneDriveCommercial,$env:OneDrive)
$folders = @()
if ($RunRoot) {
 if (-not (Test-Path -LiteralPath $RunRoot -PathType Container)) { throw 'INVALID_RUNROOT' }
 $folders += Get-Item -LiteralPath $RunRoot
} else {
 foreach ($root in $roots) {
  if ([string]::IsNullOrWhiteSpace($root) -or -not (Test-Path -LiteralPath $root -PathType Container)) { continue }
  $folders += @(Get-ChildItem -LiteralPath $root -Filter 'BISM2202_NativeASCII_*' -Directory -ErrorAction SilentlyContinue)
  if ($root -eq 'H:\') {
   foreach ($sub in @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^(\d{1,3}|BISM2202.*)$' })) {
    $folders += @(Get-ChildItem -LiteralPath $sub.FullName -Directory -Filter 'BISM2202_NativeASCII_*' -ErrorAction SilentlyContinue)
   }
  }
 }
}
$folders = @($folders | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'GBT_NativeBatch.err') -PathType Leaf } | Sort-Object LastWriteTime -Descending)
if ($folders.Count -eq 0) { throw 'BATCH_LOGS_NOT_FOUND: specify -RunRoot' }
$source = $folders[0].FullName
$target = Join-Path (Split-Path -Parent $source) ('BISM2202_XML_DIAGNOSTIC_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Path $target -Force | Out-Null
$summary = New-Object 'System.Collections.Generic.List[string]'
$summary.Add('SOURCE=' + $source)
$summary.Add('MODE=DIAGNOSTIC_ONLY')
$pattern = '(?i)SAXParseException|Caused by|lineNumber|columnNumber|Content is not allowed|Premature|Cannot read process|XMLException|fatal error|Exception in thread|FileNotFoundException|XML document|XML parse|Error parsing|markup|entity reference|Expected'
foreach ($model in @('GBT','NB')) {
 $summary.Add('=== ' + $model + ' ===')
 foreach ($suffix in @('_NativeBatch.err','_NativeBatch.log','_Native.rmp')) {
  $p = Join-Path $source ($model + $suffix)
  if (Test-Path -LiteralPath $p -PathType Leaf) { Copy-Item -LiteralPath $p -Destination (Join-Path $target (Split-Path -Leaf $p)) -Force }
 }
 $err = Join-Path $source ($model + '_NativeBatch.err')
 if (-not (Test-Path -LiteralPath $err -PathType Leaf)) { $summary.Add('NO_ERR_LOG'); continue }
 $lines = @(Get-Content -LiteralPath $err)
 $indices = New-Object 'System.Collections.Generic.SortedSet[int]'
 for ($i=0; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match $pattern) {
   for ($j=[math]::Max(0,$i-2); $j -le [math]::Min($lines.Count-1,$i+4); $j++) { [void]$indices.Add($j) }
  }
 }
 if ($indices.Count -eq 0) {
  for ($j=0; $j -lt [math]::Min(45,$lines.Count); $j++) { [void]$indices.Add($j) }
 }
 $count=0
 foreach ($i in $indices) {
  if ($count -ge 100) { $summary.Add('TRUNCATED'); break }
  $summary.Add(([string]($i+1) + ': ' + $lines[$i])); $count++
 }
 $rmp=Join-Path $source ($model + '_Native.rmp')
 if (Test-Path -LiteralPath $rmp -PathType Leaf) {
  try {
   [xml]$doc=Get-Content -LiteralPath $rmp -Raw -Encoding UTF8
   $summary.Add('DOTNET_XML_PARSE=PASS')
   $summary.Add('PROCESS_VERSION=' + $doc.DocumentElement.GetAttribute('version'))
  } catch { $summary.Add('DOTNET_XML_PARSE=FAILED ' + $_.Exception.Message) }
 }
}
foreach ($f in @('execution.log','manifest.json')) {
 $p=Join-Path $source $f
 if (Test-Path -LiteralPath $p -PathType Leaf) { Copy-Item -LiteralPath $p -Destination (Join-Path $target $f) -Force }
}
$summaryPath=Join-Path $target 'diagnostic_summary.txt'
[IO.File]::WriteAllLines($summaryPath,[string[]]$summary.ToArray(),(New-Object Text.UTF8Encoding($true)))
Write-Host ('SOURCE=' + $source)
Write-Host 'ERROR_SUMMARY_START'
Get-Content -LiteralPath $summaryPath | Select-Object -First 75
Write-Host 'ERROR_SUMMARY_END'
$zip=$target+'.zip'
Compress-Archive -Path (Join-Path $target '*') -DestinationPath $zip -Force
if (-not (Test-Path -LiteralPath $zip -PathType Leaf) -or (Get-Item -LiteralPath $zip).Length -le 200) { throw 'ZIP_FAILED' }
Write-Host ('DIAGNOSTIC_ZIP=' + $zip) -ForegroundColor Green
Write-Host 'NO_MODEL_EXECUTION_PERFORMED'
