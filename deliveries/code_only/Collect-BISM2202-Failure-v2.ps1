param(
    [string]$ProjectRoot = '',
    [string]$SourceZip = '',
    [string]$RunName = 'run_20261025_192403'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
$runStamp = $RunName -replace '^run_', ''
$expectedZip = 'BISM2202_Evidence_' + $runStamp + '.zip'
$roots = New-Object 'System.Collections.Generic.List[string]'

function Add-Root([string]$p) {
    if (-not [string]::IsNullOrWhiteSpace($p) -and (Test-Path -LiteralPath $p -PathType Container)) {
        $full = (Resolve-Path -LiteralPath $p).Path
        if (-not $script:roots.Contains($full)) { $script:roots.Add($full) }
    }
}
function Check-Archive([string]$p) {
    if (-not [string]::IsNullOrWhiteSpace($p) -and (Test-Path -LiteralPath $p -PathType Leaf)) {
        $item = Get-Item -LiteralPath $p
        if ($item.Length -gt 0 -and $item.Extension -ieq '.zip') { return $item.FullName }
    }
    return $null
}

$sourceFolder = $null
$source = Check-Archive $SourceZip
if (-not $source) {
    Add-Root $ProjectRoot
    Add-Root 'H:\'
    Add-Root 'D:\'
    Add-Root (Get-Location).Path
    Add-Root $env:OneDrive
    Add-Root $env:OneDriveCommercial
    Add-Root (Join-Path $env:USERPROFILE 'Downloads')
    Add-Root (Join-Path $env:USERPROFILE 'Documents')
    foreach ($drive in @(Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue)) {
        if ($drive.Name -match '^[A-Za-z]$' -and $drive.Name -notin @('C','D','H')) {
            Add-Root ($drive.Name + ':\')
        }
    }
    $projects = New-Object 'System.Collections.Generic.List[string]'
    foreach ($root in $roots) {
        if (-not $projects.Contains($root)) { $projects.Add($root) }
        $dirs = @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like 'BISM2202*' })
        foreach ($dir in $dirs) {
            if (-not $projects.Contains($dir.FullName)) { $projects.Add($dir.FullName) }
        }
    }
    foreach ($project in $projects) {
        foreach ($candidate in @(
            (Join-Path $project $expectedZip),
            (Join-Path $project ('evidence\rapidminer\' + $expectedZip)),
            (Join-Path $project ('BISM2202_Evidence\' + $expectedZip))
        )) {
            $source = Check-Archive $candidate
            if ($source) { break }
        }
        if ($source) { break }
    }
    if (-not $source) {
        foreach ($project in $projects) {
            $folder = Join-Path $project ('evidence\rapidminer\' + $RunName)
            if (Test-Path -LiteralPath $folder -PathType Container) {
                Write-Host ('FOUND_EVIDENCE_FOLDER=' + $folder)
                $sourceFolder = $folder
                break
            }
        }
    }
}
if (-not $source -and -not $sourceFolder) {
    Write-Host ('Could not locate ' + $expectedZip + ' automatically.') -ForegroundColor Yellow
    Write-Host 'Select the saved BISM2202 evidence ZIP in the file picker.'
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = 'Select BISM2202 evidence ZIP'
    $dialog.Filter = 'ZIP archive (*.zip)|*.zip'
    $dialog.FileName = $expectedZip
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $source = Check-Archive $dialog.FileName
    }
}
if (-not $source -and -not $sourceFolder) {
    throw 'SOURCE_NOT_FOUND: H: or OneDrive may be unavailable in this Windows session. No files were modified.'
}

$destinationRoot = if ($source) { Split-Path -Parent $source } else { Split-Path -Parent $sourceFolder }
$out = Join-Path $destinationRoot ('BISM2202_DIAGNOSTIC_' + $runStamp)
$zipOut = $out + '.zip'
if (Test-Path -LiteralPath $out) {
    $out = $out + '_' + (Get-Date -Format 'HHmmss')
    $zipOut = $out + '.zip'
}
New-Item -ItemType Directory -Path $out -Force | Out-Null
$temp = Join-Path $env:TEMP ('BISM2202_diag_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp -Force | Out-Null
try {
    if ($source) {
        Write-Host ('SOURCE_ZIP=' + $source) -ForegroundColor Cyan
        Expand-Archive -LiteralPath $source -DestinationPath $temp -Force
        $searchRoot = $temp
    } else {
        Write-Host ('SOURCE_FOLDER=' + $sourceFolder) -ForegroundColor Cyan
        $searchRoot = $sourceFolder
    }
    $files = @(Get-ChildItem -LiteralPath $searchRoot -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -match '(^execution\.log$|^manifest\.json$|^EVIDENCE_REQUIREMENTS\.txt$|^.*(NativeBatch|_batch_|_Batch\.|Diagnostic|Import_Failed).*\.(log|err|txt|png)$|^(ready_|ORIGINAL_|GBT_|NB_).+\.rmp$|^.*\.csv$)'
    })
    $index = 0
    foreach ($file in $files) {
        $index++
        $dest = Join-Path $out $file.Name
        if (Test-Path -LiteralPath $dest) {
            $dest = Join-Path $out (([IO.Path]::GetFileNameWithoutExtension($file.Name)) + '_' + $index + $file.Extension)
        }
        Copy-Item -LiteralPath $file.FullName -Destination $dest
    }
    $summary = New-Object 'System.Collections.Generic.List[string]'
    $summary.Add('RUN=' + $RunName)
    $summary.Add('SOURCE=' + $(if ($source) { $source } else { $sourceFolder }))
    $summary.Add('MATCHED_FILES=' + $files.Count)
    foreach ($f in $files) { $summary.Add('FILE=' + $f.FullName) }
    foreach ($key in @('GBT_NativeBatch.log','GBT_NativeBatch.err','NB_NativeBatch.log','NB_NativeBatch.err','execution.log')) {
        $logs = @($files | Where-Object { $_.Name -eq $key })
        foreach ($l in $logs) {
            $summary.Add('===== ' + $l.Name + ' =====')
            $summary.AddRange([string[]]@(Get-Content -LiteralPath $l.FullName -Tail 120 -ErrorAction SilentlyContinue))
        }
    }
    [IO.File]::WriteAllLines((Join-Path $out 'summary.txt'),[string[]]$summary.ToArray(),([Text.UTF8Encoding]::new($true)))
    if ($files.Count -eq 0) { throw 'SOURCE_OPENED_BUT_NO_DIAGNOSTIC_FILES_FOUND' }
    Compress-Archive -Path (Join-Path $out '*') -DestinationPath $zipOut -CompressionLevel Optimal
    if (-not (Test-Path -LiteralPath $zipOut) -or (Get-Item -LiteralPath $zipOut).Length -le 0) { throw 'DIAGNOSTIC_ZIP_WRITE_FAILED' }
    Write-Host 'DIAGNOSTIC_CREATED=PASS' -ForegroundColor Green
    Write-Host ('ZIP=' + $zipOut)
    Write-Host ('FILES=' + $files.Count)
    Write-Host 'The source evidence was preserved. Check for account data before sharing.'
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
