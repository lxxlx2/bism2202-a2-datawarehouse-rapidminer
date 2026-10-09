param([ValidateSet('A','B')][string]$Student='A')
$ErrorActionPreference='Stop'
$out="C:\BISM2202\submission\Student_$Student\ssis\date"
New-Item -ItemType Directory -Force $out | Out-Null
$progress=Join-Path $out 'date_progress.txt'
('START '+(Get-Date -Format o)) | Set-Content $progress -Encoding UTF8
$success=$false
$log=New-Object 'System.Collections.Generic.List[string]'
function Say([string]$m){Write-Host $m;$script:log.Add($m);Add-Content $script:progress $m -Encoding UTF8}
function Sql([string]$q){
 $c=New-Object System.Data.SqlClient.SqlConnection("Server=.;Database=STUDENT_${Student}_ID_dw;Integrated Security=True;Encrypt=False")
 try {$c.Open();$cmd=$c.CreateCommand();$cmd.CommandText=$q;$cmd.CommandTimeout=120;return $cmd.ExecuteScalar()} finally {$c.Dispose()}
}
try {
  $names=@(
    'Microsoft.SqlServer.ManagedDTS.dll',
    'Microsoft.SqlServer.DTSRuntimeWrap.dll',
    'Microsoft.SqlServer.DTSPipelineWrap.dll',
    'Microsoft.SqlServer.PipelineHost.dll'
  )
  $sdk=@(
    'C:\Program Files\Microsoft SQL Server\160\SDK\Assemblies',
    'C:\Program Files (x86)\Microsoft SQL Server\160\SDK\Assemblies'
  )
  $gacRoots=@(
    (Join-Path $env:windir 'Microsoft.NET\assembly\GAC_MSIL'),
    (Join-Path $env:windir 'Microsoft.NET\assembly\GAC_64'),
    (Join-Path $env:windir 'assembly\GAC_MSIL'),
    (Join-Path $env:windir 'assembly\GAC_64')
  )
  $refs=@()
  foreach($name in $names){
    $baseName=[IO.Path]::GetFileNameWithoutExtension($name)
    $possible=New-Object 'System.Collections.Generic.List[System.IO.FileInfo]'
    foreach($dir in $sdk){
      $p=Join-Path $dir $name
      if(Test-Path -LiteralPath $p){$possible.Add((Get-Item -LiteralPath $p))}
    }
    foreach($rootDir in $gacRoots){
      $sub=Join-Path $rootDir $baseName
      if(Test-Path -LiteralPath $sub){
        foreach($item in (Get-ChildItem -LiteralPath $sub -Filter $name -File -Recurse -ErrorAction SilentlyContinue)){
          $possible.Add($item)
        }
      }
    }
    $choices=@(foreach($item in $possible){
      try {
        $major=[Reflection.AssemblyName]::GetAssemblyName($item.FullName).Version.Major
        [pscustomobject]@{File=$item.FullName;Major=$major}
      } catch {
        Say "WARNING unreadable assembly version: $($item.FullName)"
      }
    })
    $chosen=$choices|Where-Object{$_.Major -eq 16}|Select-Object -First 1
    if(-not $chosen){
      Say "FOUND_ASSEMBLY_VERSIONS_$($baseName) = $((($choices|ForEach-Object{ "$($_.Major):$($_.File)" }) -join ' | '))"
      throw "Missing SQL Server 2022 (major version 16) assembly $name in SDK and .NET GAC. Do not reinstall SQL Server yet; review this log."
    }
    $refs+= $chosen.File
    Say "DLL = $($chosen.File)"
  }

Add-Type -TypeDefinition (Get-Content -Raw (Join-Path $PSScriptRoot 'CustomerFlow.cs')) -ReferencedAssemblies $refs
if((Sql 'SELECT COUNT_BIG(*) FROM dbo.FactSales') -ne 0){throw 'Refuse date reset when FactSales is populated'}
[void](Sql 'DELETE FROM dbo.DimDate; SELECT 1;')
$prefix='Provider=MSOLEDBSQL;Data Source=.;Integrated Security=SSPI;TrustServerCertificate=Yes;Initial Catalog='
$rows=[BismCustomerFlow]::Date(($prefix+'ozmart_db;'),($prefix+"STUDENT_${Student}_ID_dw;"),(Join-Path $out '05_DimDate.dtsx'),$Student)
$actual=Sql 'SELECT COUNT_BIG(*) FROM dbo.DimDate'
$expected=Sql 'SELECT COUNT_BIG(*) FROM (SELECT CAST(purchase_timestamp AS date) AS d FROM ozmart_db.dbo.orders_table GROUP BY CAST(purchase_timestamp AS date)) t'
Say "DIMDATE SSIS_ROWS=$rows TARGET_ROWS=$actual EXPECTED=$expected"
if($rows -ne $expected -or $actual -ne $expected){throw 'Date count mismatch'}
$diff=Sql @'
SELECT COUNT_BIG(*) FROM (
 SELECT DateKey,CalendarDate,CalendarYear,CalendarQuarter,CalendarMonth,DayOfMonth FROM dbo.DimDate
 EXCEPT
 SELECT YEAR(purchase_timestamp)*10000+MONTH(purchase_timestamp)*100+DAY(purchase_timestamp),CAST(purchase_timestamp AS date),YEAR(purchase_timestamp),DATEPART(quarter,purchase_timestamp),MONTH(purchase_timestamp),DAY(purchase_timestamp)
 FROM ozmart_db.dbo.orders_table
) t;
'@
if($diff -ne 0){throw 'Date fields mismatch'}
Say 'DIMDATE_RECONCILIATION=PASS'
$success=$true
Say 'DIMDATE_RUNTIME=PASS'
} catch {Say ('DIMDATE_RUNTIME=FAIL '+$_.Exception.ToString())}
$log | Set-Content (Join-Path $out 'date_results.txt') -Encoding UTF8
if(-not $success){exit 1}
