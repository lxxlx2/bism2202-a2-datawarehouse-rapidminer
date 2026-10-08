param([ValidateSet('A','B')][string]$Student='A')
$ErrorActionPreference='Stop'
$out="C:\BISM2202\submission\Student_$Student\ssis\customer_lookup"
New-Item -ItemType Directory -Force $out | Out-Null
$log=New-Object 'System.Collections.Generic.List[string]'
function Say([string]$m){Write-Host $m;$script:log.Add($m)}
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
if((Sql 'SELECT COUNT_BIG(*) FROM dbo.FactSales') -ne 0){throw 'Refuse customer reset when FactSales is populated'}
[void](Sql 'DELETE FROM dbo.DimCustomer; DBCC CHECKIDENT ("dbo.DimCustomer", RESEED, 0) WITH NO_INFOMSGS; SELECT 1;')
$prefix='Provider=MSOLEDBSQL;Data Source=.;Integrated Security=SSPI;TrustServerCertificate=Yes;Initial Catalog='
$rows=[BismCustomerFlow]::Execute(($prefix+'ozmart_db;'),($prefix+"STUDENT_${Student}_ID_dw;"),(Join-Path $out '02_DimCustomer.dtsx'),$Student)
$actual=Sql 'SELECT COUNT_BIG(*) FROM dbo.DimCustomer'
Say "DIMCUSTOMER SSIS_ROWS=$rows TARGET_ROWS=$actual EXPECTED=21000"
if($rows -ne 21000 -or $actual -ne 21000){throw 'Customer count mismatch'}
$diff=Sql @'
SELECT COUNT_BIG(*) FROM (
 SELECT CustomerID,Age,AgeSourceKey,EducationSourceCode,EducationCode,EducationLevel,CustomerLocationID FROM dbo.DimCustomer
 EXCEPT
 SELECT c.customer_id,CONVERT(smallint,a.Age),c.Age_key,c.EDU_id,e.EDU_ID,e.Education_level,c.location_id
 FROM ozmart_db.dbo.customer_table c
 JOIN dbo.RefAge a ON c.Age_key=a.Age_Id
 JOIN dbo.RefEducation e ON CONVERT(int,SUBSTRING(c.EDU_id,5,8))=CONVERT(int,SUBSTRING(e.EDU_ID,5,8))
) mismatched;
'@
if($diff -ne 0){throw "Customer field mismatch $diff"}
Say 'DIMCUSTOMER_RECONCILIATION=PASS'
Say 'DIMCUSTOMER_RUNTIME=PASS'
} catch {Say ('DIMCUSTOMER_RUNTIME=FAIL '+$_.Exception.ToString())}
$log | Set-Content (Join-Path $out 'customer_results.txt') -Encoding UTF8
