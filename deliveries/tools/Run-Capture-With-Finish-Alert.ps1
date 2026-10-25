param([string]$Root = '')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
if ([string]::IsNullOrWhiteSpace($Root)) {
    $matches = @(Get-ChildItem -LiteralPath 'H:\' -Directory -Filter 'BISM2202_Ready_*' -ErrorAction SilentlyContinue |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'program\scripts\Capture-RapidMiner-Windows-Fixed-v2.ps1') -PathType Leaf } |
        Sort-Object LastWriteTime -Descending)
    if ($matches.Count -eq 0) { throw 'CAPTURE_PROJECT_NOT_FOUND' }
    $Root = $matches[0].FullName
}
$runner=Join-Path $Root 'program\scripts\Capture-RapidMiner-Windows-Fixed-v2.ps1'
if (-not (Test-Path -LiteralPath $runner -PathType Leaf)) { throw 'FIXED_CAPTURE_SCRIPT_NOT_FOUND' }
$started=Get-Date
Write-Host ('CAPTURE_STARTED='+$started.ToString('o'))
Write-Host ('PROJECT='+$Root)
$childExit=99
$errorText=''
try {
    & powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File $runner -Root $Root
    $childExit=$LASTEXITCODE
} catch {
    $errorText=$_.Exception.Message
}
$finished=Get-Date
$folders=@(Get-ChildItem -LiteralPath $Root -Directory -Filter 'BISM2202_Screenshots_*' -ErrorAction SilentlyContinue |
    Where-Object { $_.CreationTime -ge $started.AddSeconds(-5) } |
    Sort-Object CreationTime -Descending)
$folder=if($folders.Count -gt 0){$folders[0].FullName}else{''}
$pngCount=0
$gbtCount=0
$nbCount=0
$warnings=@()
if($folder){
    $pngs=@(Get-ChildItem -LiteralPath $folder -File -Filter '*.png' -ErrorAction SilentlyContinue)
    $pngCount=$pngs.Count
    $gbtCount=@($pngs | Where-Object { $_.Name -like 'GBT_*' }).Count
    $nbCount=@($pngs | Where-Object { $_.Name -like 'NB_*' }).Count
    $manifest=Join-Path $folder 'capture_manifest.txt'
    if(Test-Path -LiteralPath $manifest){
        $warnings=@(Get-Content -LiteralPath $manifest | Where-Object { $_ -match 'MODEL_WINDOW_NOT_CONFIRMED|CAPTURE_ERROR|SKIPPED_WRONG_MODEL' })
    }
}
$state=if($childExit -eq 0 -and $folder){'CAPTURE FINISHED - REVIEW REQUIRED'}else{'CAPTURE FAILED OR INCOMPLETE'}
$details=@(
    $state,
    ('PNG saved: '+$pngCount+' (NB='+$nbCount+', GBT='+$gbtCount+')'),
    ('Warnings: '+$warnings.Count),
    ('Child exit code: '+$childExit),
    ('Screenshots: '+$(if($folder){$folder}else{'NOT FOUND'})),
    ('Completed: '+$finished.ToString('o'))
)
if($errorText){$details+=('Error: '+$errorText)}
$stamp=$finished.ToString('yyyyMMdd_HHmmss')
$flag=Join-Path $Root ('BISM2202_CAPTURE_FINISHED_'+$stamp+'.txt')
[IO.File]::WriteAllLines($flag,[string[]]$details,[Text.UTF8Encoding]::new($false))
Write-Host 'CAPTURE_EXECUTION_FINISHED' -ForegroundColor Cyan
$details | ForEach-Object { Write-Host $_ }
Write-Host ('FINISH_FLAG='+$flag)
try{[System.Media.SystemSounds]::Asterisk.Play()}catch{}
$form=New-Object System.Windows.Forms.Form
$form.Text='BISM2202 Capture Finished'
$form.TopMost=$true
$form.StartPosition='CenterScreen'
$form.FormBorderStyle='FixedDialog'
$form.MaximizeBox=$false
$form.MinimizeBox=$false
$form.ClientSize=[System.Drawing.Size]::new(650,240)
$label=New-Object System.Windows.Forms.Label
$label.AutoSize=$false
$label.Location=[System.Drawing.Point]::new(16,15)
$label.Size=[System.Drawing.Size]::new(615,170)
$label.Font=[System.Drawing.Font]::new('Segoe UI',10)
$label.Text=($details -join [Environment]::NewLine)
$form.Controls.Add($label)
$button=New-Object System.Windows.Forms.Button
$button.Text='OK - Close'
$button.Location=[System.Drawing.Point]::new(500,195)
$button.Size=[System.Drawing.Size]::new(125,30)
$button.Add_Click({$form.Close()})
$form.Controls.Add($button)
[void]$form.ShowDialog()
$form.Dispose()
if($childExit -ne 0){exit $childExit}
exit 0
