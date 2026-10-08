# BISM2202 real SSIS Data Flow smoke. Run in 64-bit Windows PowerShell as Administrator.
# SQL data movement is performed by SSIS OLE DB Source -> Row Count -> OLE DB Destination.
# The SQL commands only create and clear an isolated sandbox destination, and verify counts.
# Never changes ozmart_db or the existing Package.dtsx project.
$ErrorActionPreference='Stop'
$root='C:\BISM2202\analysis'
New-Item -Force -ItemType Directory $root | Out-Null
$packageFile=Join-Path $root 'product_category_dataflow_smoke.dtsx'
$resultFile=Join-Path $root 'product_category_dataflow_result.txt'
$log = New-Object 'System.Collections.Generic.List[string]'
function Say([string]$message){Write-Host $message;$script:log.Add($message)}
function Scalar([string]$db,[string]$sql) {
    $c=New-Object System.Data.SqlClient.SqlConnection("Server=.;Database=$db;Integrated Security=True;Encrypt=False;TrustServerCertificate=True;Connection Timeout=15")
    try {
        $c.Open()
        $q=$c.CreateCommand()
        try {$q.CommandText=$sql;$q.CommandTimeout=120;return $q.ExecuteScalar()}
        finally {$q.Dispose()}
    } finally {$c.Dispose()}
}
try {
  if(-not [Environment]::Is64BitProcess){throw 'Use 64-bit Windows PowerShell.'}
  $expected=[long](Scalar 'ozmart_db' 'SELECT COUNT_BIG(*) FROM dbo.product_category')
  if($expected -ne 19){throw "Unexpected product category source count: $expected; expected 19."}
  Say "SOURCE_ROWS = $expected"
  [void](Scalar 'master' "IF DB_ID(N'BISM2202_ETL_SANDBOX') IS NULL EXEC(N'CREATE DATABASE BISM2202_ETL_SANDBOX'); SELECT 1;")
  [void](Scalar 'BISM2202_ETL_SANDBOX' @'
IF OBJECT_ID(N'dbo.ProductCategorySmoke',N'U') IS NULL
 SELECT TOP (0) * INTO dbo.ProductCategorySmoke FROM ozmart_db.dbo.product_category;
TRUNCATE TABLE dbo.ProductCategorySmoke;
SELECT 1;
'@)
  # Microsoft installs SSIS interop/programming DLLs in the .NET 4 GAC on many
  # installations, *not* inside the SQL Server 160 directory. Look in both.
  # Do not silently select an older SSIS binary installed side-by-side.
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
  $provider=$null
  foreach($candidate in @('MSOLEDBSQL','MSOLEDBSQL19','SQLNCLI11','SQLOLEDB')){
    try {
      $probe=New-Object -ComObject ADODB.Connection
      $probe.ConnectionTimeout=8
      $probe.Open("Provider=$candidate;Data Source=.;Initial Catalog=ozmart_db;Integrated Security=SSPI;TrustServerCertificate=Yes;")
      if($probe.State -eq 1){$probe.Close();$provider=$candidate;break}
    } catch {}
  }
  if(-not $provider){throw 'No working OLE DB provider (MSOLEDBSQL or SQLOLEDB).'}
  Say "OLEDB_PROVIDER = $provider"

  $sourceCode=@'
using System;
using Microsoft.SqlServer.Dts.Runtime;
using Microsoft.SqlServer.Dts.Runtime.Wrapper;
using Microsoft.SqlServer.Dts.Pipeline;
using Microsoft.SqlServer.Dts.Pipeline.Wrapper;

public class Bism2202SsisCategorySmoke {
  public static long Execute(string srcString, string dstString, string dtsx) {
    var pkg=new Package();
    pkg.Name="BISM2202_ProductCategory_DataFlow_Smoke";
    pkg.ProtectionLevel=DTSProtectionLevel.DontSaveSensitive;
    var rows=pkg.Variables.Add("RowsCopied",false,"User",0L);
    var srcConn=pkg.Connections.Add("OLEDB");
    srcConn.Name="OzMart";
    srcConn.ConnectionString=srcString;
    var dstConn=pkg.Connections.Add("OLEDB");
    dstConn.Name="BISM2202 Sandbox";
    dstConn.ConnectionString=dstString;
    var task=(TaskHost)pkg.Executables.Add("STOCK:PipelineTask");
    task.Name="DFT Category";
    var pipe=(MainPipe)task.InnerObject;

    IDTSComponentMetaData100 source=pipe.ComponentMetaDataCollection.New();
    source.ComponentClassID="DTSAdapter.OleDbSource";
    source.Name="OLE DB Source - product_category";
    CManagedComponentWrapper src=source.Instantiate();
    src.ProvideComponentProperties();
    source.RuntimeConnectionCollection[0].ConnectionManager=DtsConvert.GetExtendedInterface(srcConn);
    source.RuntimeConnectionCollection[0].ConnectionManagerID=srcConn.ID;
    src.SetComponentProperty("AccessMode",0);
    src.SetComponentProperty("OpenRowset","[dbo].[product_category]");
    src.AcquireConnections(null);src.ReinitializeMetaData();src.ReleaseConnections();

    IDTSComponentMetaData100 transform=pipe.ComponentMetaDataCollection.New();
    transform.ComponentClassID="DTSTransform.RowCount";
    transform.Name="Row Count - audit";
    CManagedComponentWrapper counter=transform.Instantiate();
    counter.ProvideComponentProperties();
    counter.SetComponentProperty("VariableName","User::RowsCopied");

    IDTSComponentMetaData100 destination=pipe.ComponentMetaDataCollection.New();
    destination.ComponentClassID="DTSAdapter.OleDbDestination";
    destination.Name="OLE DB Destination - CategorySmoke";
    CManagedComponentWrapper dst=destination.Instantiate();
    dst.ProvideComponentProperties();
    destination.RuntimeConnectionCollection[0].ConnectionManager=DtsConvert.GetExtendedInterface(dstConn);
    destination.RuntimeConnectionCollection[0].ConnectionManagerID=dstConn.ID;
    dst.SetComponentProperty("AccessMode",3);
    dst.SetComponentProperty("OpenRowset","[dbo].[ProductCategorySmoke]");
    dst.AcquireConnections(null);dst.ReinitializeMetaData();dst.ReleaseConnections();

    pipe.PathCollection.New().AttachPathAndPropagateNotifications(source.OutputCollection[0],transform.InputCollection[0]);
    pipe.PathCollection.New().AttachPathAndPropagateNotifications(transform.OutputCollection[0],destination.InputCollection[0]);
    IDTSInput100 input=destination.InputCollection[0];
    IDTSVirtualInput100 vir=input.GetVirtualInput();
    foreach(IDTSVirtualInputColumn100 col in vir.VirtualInputColumnCollection){
       IDTSInputColumn100 selected=dst.SetUsageType(input.ID,vir,col.LineageID,DTSUsageType.UT_READONLY);
       IDTSExternalMetadataColumn100 external=input.ExternalMetadataColumnCollection[selected.Name];
       dst.MapInputColumn(input.ID,selected.ID,external.ID);
    }
    var app=new Application();
    app.SaveToXml(dtsx,pkg,null);
    DTSExecResult execution=pkg.Execute();
    if(execution!=DTSExecResult.Success){
       foreach(DtsError err in pkg.Errors) Console.Error.WriteLine("SSIS_ERROR: "+err.Description);
       throw new Exception("SSIS package returned "+execution);
    }
    return Convert.ToInt64(rows.Value);
  }
}
'@
  Add-Type -TypeDefinition $sourceCode -ReferencedAssemblies $refs -ErrorAction Stop
  $prefix="Provider=$provider;Data Source=.;Integrated Security=SSPI;TrustServerCertificate=Yes;"
  $count=[long][Bism2202SsisCategorySmoke]::Execute(
    ($prefix+'Initial Catalog=ozmart_db;'),
    ($prefix+'Initial Catalog=BISM2202_ETL_SANDBOX;'),
    $packageFile
  )
  $actual=[long](Scalar 'BISM2202_ETL_SANDBOX' 'SELECT COUNT_BIG(*) FROM dbo.ProductCategorySmoke')
  Say "SSIS_ROW_COUNT = $count"
  Say "DESTINATION_ROWS = $actual"
  if($count -ne $expected -or $actual -ne $expected){throw "Count mismatch: source $expected; SSIS $count; destination $actual"}
  Say 'DATA_FLOW_SMOKE = PASS'
  $good=$true
} catch {
  $good=$false
  Say ("DATA_FLOW_SMOKE = FAIL: "+$_.Exception.ToString())
}
Say "PACKAGE = $packageFile"
Say "LOG = $resultFile"
$log|Set-Content -LiteralPath $resultFile -Encoding UTF8
if(-not $good){exit 1}
