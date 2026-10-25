$ErrorActionPreference = 'Stop'
$url = 'https://raw.githubusercontent.com/lxxlx2/bism2202-a2-datawarehouse-rapidminer/9a65a07df45cc8ca2238f6a4b10a1686d06d8daf/deliveries/tools/Run-BISM2202-School-Windows.ps1'
$path = Join-Path $env:TEMP 'BISM2202_school_runner.ps1'
Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $path
$text = [IO.File]::ReadAllText($path,[Text.Encoding]::UTF8)
$tokens = $null
$errors = $null
[void][Management.Automation.Language.Parser]::ParseInput($text,[ref]$tokens,[ref]$errors)
if ($errors.Count -ne 0) { $errors | ForEach-Object { Write-Host $_.Message -ForegroundColor Red }; throw 'Script syntax check failed.' }
& ([ScriptBlock]::Create($text)) @args
