# Initial formal warehouse DimSeller milestone, NOT the complete assignment.
# Shared correct base load for A/B; independent full ETL designs are still pending.
# Real SSIS: OLE DB Source -> Data Conversion -> Row Count -> OLE DB Destination.
# SQL creates target schema, clears only this dimension when FactSales is empty, and verifies.
# No source writes and no modification of the existing Visual Studio project.
# Runtime validation is pending. Run in a fresh 64-bit Windows PowerShell process.
param([ValidateSet('A','B')][string]$Student='A', [string]$OutRoot='C:\BISM2202\submission')
$ErrorActionPreference='Stop'
$targetDB="STUDENT_${Student}_ID_dw"
$root=Join-Path $OutRoot "Student_$Student\ssis\initial_seller"
New-Item -Force -ItemType Directory $root | Out-Null
$packageFile=Join-Path $root '01_DimSeller.dtsx'
$resultFile=Join-Path $root '01_DimSeller_result.txt'
Start-Transcript -Path (Join-Path $root ('execution-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.log')) -Force | Out-Null
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
  $expected=[long](Scalar 'ozmart_db' 'SELECT COUNT_BIG(*) FROM dbo.sellers_table')
  if($expected -ne 100){throw "Unexpected seller source count: $expected; expected 100."}
  Say "SOURCE_ROWS = $expected"
  [void](Scalar 'master' ("IF DB_ID(N'"+$targetDB+"') IS NULL EXEC(N'CREATE DATABASE ["+$targetDB+"]'); SELECT 1;"))
  $ddl=Join-Path $PSScriptRoot 'schema.sql'
  if(-not (Test-Path -LiteralPath $ddl)){throw "Missing schema.sql next to this script."}
  [void](Scalar $targetDB ((Get-Content -Raw -LiteralPath $ddl)+"`nSELECT 1;"))
  # An initial milestone only. Never erase an already populated assignment fact.
  if([long](Scalar $targetDB 'SELECT COUNT_BIG(*) FROM dbo.FactSales') -ne 0){
    throw 'FactSales is populated; refuse initial dimension reset. Use the reviewed full ETL project.'
  }
  [void](Scalar $targetDB 'DELETE FROM dbo.DimSeller; DBCC CHECKIDENT ("dbo.DimSeller", RESEED, 0) WITH NO_INFOMSGS; SELECT 1;')
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
// Managed package APIs live in Microsoft.SqlServer.Dts.Runtime.
// Importing Runtime.Wrapper here introduces a different COM Package type.
using Microsoft.SqlServer.Dts.Pipeline;
using Microsoft.SqlServer.Dts.Pipeline.Wrapper;

public class Bism2202InitialSeller {
  // Use the component catalog installed on THIS VM, not an unversioned ProgID
  // that can resolve to a 2016 component on a side-by-side 2016/2022 machine.
  private static string ResolveComponent(Application app, string displayName, string progId) {
    string chosen=null;
    int rank=-1;
    foreach(PipelineComponentInfo info in app.PipelineComponentInfos) {
      string name=info.Name ?? "";
      string id=info.CreationName ?? "";
      if(name.Equals(displayName,StringComparison.OrdinalIgnoreCase)
          || id.StartsWith(progId,StringComparison.OrdinalIgnoreCase)) {
        Console.WriteLine("SSIS_COMPONENT_CANDIDATE " + displayName + " : " + name + " : " + id);
        int n=0;
        if(id.StartsWith(progId+".",StringComparison.OrdinalIgnoreCase)) {
          if(!Int32.TryParse(id.Substring(progId.Length+1),out n)) n=0;
        }
        if(chosen==null || n>rank){chosen=id;rank=n;}
      }
    }
    if(String.IsNullOrEmpty(chosen))
      throw new InvalidOperationException("SSIS component missing from 64-bit runtime catalog: "+displayName+". Check SSIS 160 component registration, not the SQL service.");
    Console.WriteLine("SSIS_COMPONENT_SELECTED "+displayName+" : "+chosen);
    return chosen;
  }
  private static void Initialize(CManagedComponentWrapper wrapper,string stage,string classId) {
    Console.WriteLine("SSIS_STAGE="+stage+" PROVIDE_PROPERTIES; ID="+classId);
    try {wrapper.ProvideComponentProperties();}
    catch(Exception ex){throw new InvalidOperationException("SSIS "+stage+" component initialization failed; ComponentClassID="+classId,ex);}
    Console.WriteLine("SSIS_STAGE="+stage+" INITIALIZED");
  }
  public static long Execute(string srcString, string dstString, string dtsx) {
    var pkg=new Microsoft.SqlServer.Dts.Runtime.Package();
    pkg.Name="BISM2202_Initial_DimSeller";
    pkg.ProtectionLevel=DTSProtectionLevel.DontSaveSensitive;
    var rows=pkg.Variables.Add("RowsCopied",false,"User",0L);
    var srcConn=pkg.Connections.Add("OLEDB");
    srcConn.Name="OzMart";
    srcConn.ConnectionString=srcString;
    var dstConn=pkg.Connections.Add("OLEDB");
    dstConn.Name="Assignment Warehouse";
    dstConn.ConnectionString=dstString;
    var task=(TaskHost)pkg.Executables.Add("STOCK:PipelineTask");
    task.Name="DFT DimSeller";
    var pipe=(MainPipe)task.InnerObject;
    var components=new Application();
    string sourceId=ResolveComponent(components,"OLE DB Source","DTSAdapter.OleDbSource");
    string countId=ResolveComponent(components,"Row Count","DTSTransform.RowCount");
    string destinationId=ResolveComponent(components,"OLE DB Destination","DTSAdapter.OleDbDestination");

    IDTSComponentMetaData100 source=pipe.ComponentMetaDataCollection.New();
    source.ComponentClassID=sourceId;
    source.Name="OLE DB Source - sellers_table";
    CManagedComponentWrapper src=source.Instantiate();
    Initialize(src,"SOURCE",sourceId);
    source.RuntimeConnectionCollection[0].ConnectionManager=DtsConvert.GetExtendedInterface(srcConn);
    source.RuntimeConnectionCollection[0].ConnectionManagerID=srcConn.ID;
    src.SetComponentProperty("AccessMode",2);
    src.SetComponentProperty("SqlCommand","SELECT seller_id AS SellerID, name AS SellerName, location_id AS SellerLocationID, creation_date AS CreatedAt, end_date AS EndAt FROM dbo.sellers_table");
    src.AcquireConnections(null);src.ReinitializeMetaData();src.ReleaseConnections();

    IDTSComponentMetaData100 transform=pipe.ComponentMetaDataCollection.New();
    transform.ComponentClassID=countId;
    transform.Name="Row Count - audit";
    CManagedComponentWrapper counter=transform.Instantiate();
    Initialize(counter,"ROWCOUNT",countId);
    counter.SetComponentProperty("VariableName","User::RowsCopied");

    IDTSComponentMetaData100 destination=pipe.ComponentMetaDataCollection.New();
    destination.ComponentClassID=destinationId;
    destination.Name="OLE DB Destination - DimSeller";
    CManagedComponentWrapper dst=destination.Instantiate();
    Initialize(dst,"DESTINATION",destinationId);
    destination.RuntimeConnectionCollection[0].ConnectionManager=DtsConvert.GetExtendedInterface(dstConn);
    destination.RuntimeConnectionCollection[0].ConnectionManagerID=dstConn.ID;
    dst.SetComponentProperty("AccessMode",3);
    dst.SetComponentProperty("OpenRowset","[dbo].[DimSeller]");
    dst.AcquireConnections(null);dst.ReinitializeMetaData();dst.ReleaseConnections();

    var conv=pipe.ComponentMetaDataCollection.New();
    conv.ComponentClassID=ResolveComponent(components,"Data Conversion","DTSTransform.DataConvert");
    conv.Name="Data Conversion - Unicode identity and timestamp types";
    var converter=conv.Instantiate();
    Initialize(converter,"DATA_CONVERSION",conv.ComponentClassID);
    pipe.PathCollection.New().AttachPathAndPropagateNotifications(source.OutputCollection[0],conv.InputCollection[0]);
    var ci=conv.InputCollection[0];
    var cv=ci.GetVirtualInput();
    foreach(IDTSVirtualInputColumn100 vc in cv.VirtualInputColumnCollection) {
      converter.SetUsageType(ci.ID,cv,vc.LineageID,DTSUsageType.UT_READONLY);
      var oc=converter.InsertOutputColumnAt(conv.OutputCollection[0].ID,conv.OutputCollection[0].OutputColumnCollection.Count,"Target_"+vc.Name,"Explicit target type conversion");
      converter.SetOutputColumnProperty(conv.OutputCollection[0].ID,oc.ID,"SourceInputColumnLineageID",vc.LineageID);
      bool text=vc.Name=="SellerID" || vc.Name=="SellerName" || vc.Name=="SellerLocationID";
      int length=vc.Name=="SellerName" ? 256 : 64;
      converter.SetOutputColumnDataTypeProperties(conv.OutputCollection[0].ID,oc.ID,
        text ? Microsoft.SqlServer.Dts.Runtime.Wrapper.DataType.DT_WSTR : Microsoft.SqlServer.Dts.Runtime.Wrapper.DataType.DT_DBTIMESTAMP2,
        text ? length : 0,0,text ? 0 : 7,0);
      oc.ErrorRowDisposition=DTSRowDisposition.RD_FailComponent;
      oc.TruncationRowDisposition=DTSRowDisposition.RD_FailComponent;
    }
    pipe.PathCollection.New().AttachPathAndPropagateNotifications(conv.OutputCollection[0],transform.InputCollection[0]);
    pipe.PathCollection.New().AttachPathAndPropagateNotifications(transform.OutputCollection[0],destination.InputCollection[0]);
    IDTSInput100 input=destination.InputCollection[0];
    IDTSVirtualInput100 vir=input.GetVirtualInput();
    foreach(IDTSVirtualInputColumn100 col in vir.VirtualInputColumnCollection){
       if(!col.Name.StartsWith("Target_",StringComparison.Ordinal)) continue;
       IDTSInputColumn100 selected=dst.SetUsageType(input.ID,vir,col.LineageID,DTSUsageType.UT_READONLY);
       IDTSExternalMetadataColumn100 external=input.ExternalMetadataColumnCollection[selected.Name.Substring(7)];
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
  Say 'CSHARP_COMPILE = PASS'
  $prefix="Provider=$provider;Data Source=.;Integrated Security=SSPI;TrustServerCertificate=Yes;"
  $count=[long][Bism2202InitialSeller]::Execute(
    ($prefix+'Initial Catalog=ozmart_db;'),
    ($prefix+'Initial Catalog='+$targetDB+';'),
    $packageFile
  )
  Say 'SSIS_PACKAGE_EXECUTION = PASS'
  $actual=[long](Scalar $targetDB 'SELECT COUNT_BIG(*) FROM dbo.DimSeller')
  Say "SSIS_ROW_COUNT = $count"
  Say "DESTINATION_ROWS = $actual"
  if($count -ne $expected -or $actual -ne $expected){throw "Count mismatch: source $expected; SSIS $count; destination $actual"}
  $diff=[long](Scalar $targetDB @'
SELECT COUNT_BIG(*) FROM (
 SELECT SellerID,SellerName,SellerLocationID,CreatedAt,EndAt FROM dbo.DimSeller
 EXCEPT
 SELECT seller_id,name,location_id,creation_date,end_date FROM ozmart_db.dbo.sellers_table
) d;
'@)
  if($diff -ne 0){throw "DimSeller values differ from immutable source: $diff"}
  Say 'DIMSELLER_NATURAL_FIELDS_RECONCILIATION = PASS'
  Say 'INITIAL_DIMSELLER_RUNTIME = PASS'
  Say 'FULL_ASSIGNMENT_ETL = PENDING'
  Say 'SSIS_DESIGNER_SCREENSHOTS = PENDING'
  # Export exact source catalog for subsequent Data Flow design; read only.
  $sc=New-Object System.Data.SqlClient.SqlConnection('Server=.;Database=ozmart_db;Integrated Security=True;Encrypt=False;TrustServerCertificate=True')
  try {
    $sc.Open();$cmd=$sc.CreateCommand()
    $cmd.CommandText="SELECT t.name AS table_name,c.column_id,c.name AS column_name,ty.name AS data_type,c.max_length,c.precision,c.scale,c.is_nullable FROM sys.tables t JOIN sys.columns c ON c.object_id=t.object_id JOIN sys.types ty ON ty.user_type_id=c.user_type_id ORDER BY t.name,c.column_id"
    $ad=New-Object System.Data.SqlClient.SqlDataAdapter($cmd);$dt=New-Object System.Data.DataTable
    [void]$ad.Fill($dt)
    $catalog=@(foreach($r in $dt.Rows){[pscustomobject]@{table_name=$r.table_name;column_name=$r.column_name;data_type=$r.data_type;max_length=$r.max_length;precision=$r.precision;scale=$r.scale;is_nullable=$r.is_nullable}})
    $catalog|ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $root 'source-catalog.json') -Encoding UTF8
    $ad.Dispose();$cmd.Dispose();$dt.Dispose()
  } finally {$sc.Dispose()}

  $good=$true
} catch {
  $good=$false
  Say ("INITIAL_DIMSELLER_RUNTIME = FAIL: "+$_.Exception.ToString())
}
Say "PACKAGE = $packageFile"
Say "LOG = $resultFile"
$log|Set-Content -LiteralPath $resultFile -Encoding UTF8
Stop-Transcript | Out-Null
if(-not $good){exit 1}
