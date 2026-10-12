param([ValidateSet('A','B')][string]$Student='A')
$ErrorActionPreference='Stop'
$out="C:\BISM2202\submission\Student_$Student\ssis\STUDENT_${Student}_ID_SSIS"
New-Item -ItemType Directory -Force $out | Out-Null
$progress=Join-Path $out 'warehouse_progress.txt'
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
[void](Sql ((Get-Content -Raw (Join-Path $PSScriptRoot 'schema.sql'))+"`nSELECT 1;"))
foreach($spec in @(
 @('RefAge','Age_Id,Age'),@('RefEducation','EDU_ID,Education_level'),@('RefState','state_name,state_code'),
 @('RefSellerLocation','location_id,unit,street,postcode,suburb,state,type,status,region')
)) {
 $table=$spec[0];$cols=($spec[1].Split(',')|ForEach-Object{"[$_] nvarchar(256) NULL"}) -join ','
 [void](Sql "IF OBJECT_ID('dbo.$table','U') IS NULL CREATE TABLE dbo.$table ($cols); SELECT 1;")
}
$prefix='Provider=MSOLEDBSQL;Data Source=.;Integrated Security=SSPI;TrustServerCertificate=Yes;Initial Catalog='
$audit=[BismCustomerFlow]::Warehouse(($prefix+'ozmart_db;'),($prefix+"STUDENT_${Student}_ID_dw;"),'C:\BISM2202\assignment_work\csv',(Join-Path $out 'Master.dtsx'),$Student)
Say $audit
$expected=@{DimSeller=100;DimCustomer=21000;DimProduct=2199;DimGeography=1599;FactSales=137901;RefAge=78;RefEducation=6;RefState=8;RefSellerLocation=100}
foreach($table in $expected.Keys) {
 $actual=Sql "SELECT COUNT_BIG(*) FROM dbo.$table"
 Say "$table ROWS=$actual EXPECTED=$($expected[$table])"
 if($actual -ne $expected[$table]){throw "Warehouse count mismatch: $table"}
}
$sourceqty=Sql 'SELECT SUM(CONVERT(bigint,item_quantity)) FROM ozmart_db.dbo.order_items_table'
$qty=Sql 'SELECT SUM(CONVERT(bigint,ItemQuantity)) FROM dbo.FactSales'
if($sourceqty -ne $qty){throw 'Quantity mismatch'}
Say "QUANTITY=$qty"
$dates=Sql 'SELECT COUNT_BIG(*) FROM dbo.DimDate'
$expectedDates=Sql 'SELECT COUNT_BIG(*) FROM (SELECT CAST(purchase_timestamp AS date) d FROM ozmart_db.dbo.orders_table GROUP BY CAST(purchase_timestamp AS date)) t'
if($dates -ne $expectedDates){throw 'Date count mismatch'}
Say "DIMDATE_ROWS=$dates EXPECTED=$expectedDates"
$success=$true
Say 'WAREHOUSE_MASTER_RUNTIME=PASS'
Say 'DESIGNER_PROJECT_AND_SCREENSHOTS=PENDING'
} catch {Say ('WAREHOUSE_MASTER_RUNTIME=FAIL '+$_.Exception.ToString())}
$log | Set-Content (Join-Path $out 'warehouse_results.txt') -Encoding UTF8
if(-not $success){exit 1}
