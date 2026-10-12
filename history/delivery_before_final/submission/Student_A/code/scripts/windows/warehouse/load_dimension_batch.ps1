param([ValidateSet('A','B')][string]$Student='A')
$ErrorActionPreference='Stop'
$log="C:\BISM2202\submission\Student_$Student\ssis\dimension_batch.txt"
('BATCH_START '+(Get-Date -Format o)) | Set-Content $log -Encoding UTF8
foreach($loader in @('load_customer.ps1','load_product_geography.ps1','load_date.ps1')) {
 ('START '+$loader) | Add-Content $log -Encoding UTF8
 & C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot $loader) -Student $Student
 if($LASTEXITCODE -ne 0){('FAIL '+$loader) | Add-Content $log -Encoding UTF8;exit 1}
 ('PASS '+$loader) | Add-Content $log -Encoding UTF8
}
'DIMENSION_BATCH=PASS' | Add-Content $log -Encoding UTF8
