param([ValidateSet('A','B')][string]$Student='A')
$ErrorActionPreference='Stop'
$out="C:\BISM2202\submission\Student_$Student\ssis\fact"
New-Item -ItemType Directory -Force $out | Out-Null
$progress=Join-Path $out 'fact_progress.txt'
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
# The assignment target is an isolated rebuildable warehouse. No source writes.
[void](Sql 'DELETE FROM dbo.FactSales; DBCC CHECKIDENT ("dbo.FactSales", RESEED, 0) WITH NO_INFOMSGS; SELECT 1;')
$prefix='Provider=MSOLEDBSQL;Data Source=.;Integrated Security=SSPI;TrustServerCertificate=Yes;Initial Catalog='
$rows=[BismCustomerFlow]::Fact(($prefix+'ozmart_db;'),($prefix+"STUDENT_${Student}_ID_dw;"),(Join-Path $out '06_FactSales.dtsx'),$Student)
$actual=Sql 'SELECT COUNT_BIG(*) FROM dbo.FactSales'
Say "FACTSALES SSIS_ROWS=$rows TARGET_ROWS=$actual EXPECTED=137901"
if($rows -ne 137901 -or $actual -ne 137901){throw 'Fact grain count mismatch'}
$diff=Sql @'
SELECT COUNT_BIG(*) FROM (
 SELECT OrderItemID,OrderID,ItemSequence,ItemQuantity,SourceUnitSalesPrice,SourceLineTotal FROM dbo.FactSales
 EXCEPT
 SELECT order_item_id,order_id,item_sequence,item_quantity,sales_price,line_total FROM ozmart_db.dbo.order_items_table
) t;
'@
if($diff -ne 0){throw 'Fact raw source fields differ'}
$qty=Sql 'SELECT SUM(CONVERT(bigint,ItemQuantity)) FROM dbo.FactSales'
$sourceqty=Sql 'SELECT SUM(CONVERT(bigint,item_quantity)) FROM ozmart_db.dbo.order_items_table'
if($qty -ne $sourceqty){throw 'Fact quantity differs'}
Say "QUANTITY=$qty"
Say 'FACT_RAW_FIELDS_RECONCILIATION=PASS'
$success=$true
Say 'FACT_RUNTIME=PASS'
} catch {Say ('FACT_RUNTIME=FAIL '+$_.Exception.ToString())}
$log | Set-Content (Join-Path $out 'fact_results.txt') -Encoding UTF8
if(-not $success){exit 1}
