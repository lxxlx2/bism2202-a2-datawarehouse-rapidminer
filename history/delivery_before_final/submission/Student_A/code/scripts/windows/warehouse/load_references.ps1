param([ValidateSet('A','B')][string]$Student='A')
$ErrorActionPreference='Stop'
$out="C:\BISM2202\submission\Student_$Student\ssis\references"
New-Item -ItemType Directory -Force $out | Out-Null
$progress=Join-Path $out 'reference_progress.txt'
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

$sourceCode=@'
using System;
using Microsoft.SqlServer.Dts.Runtime;
// Managed package APIs live in Microsoft.SqlServer.Dts.Runtime.
// Importing Runtime.Wrapper here introduces a different COM Package type.
using Microsoft.SqlServer.Dts.Pipeline;
using Microsoft.SqlServer.Dts.Pipeline.Wrapper;

public class BismReferenceLoader {
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
  public static long Execute(string csv, string headers, string table, string dstString, string dtsx) {
    var pkg=new Microsoft.SqlServer.Dts.Runtime.Package();
    pkg.Name="BISM2202_Reference_"+table;
    pkg.ProtectionLevel=DTSProtectionLevel.DontSaveSensitive;
    var rows=pkg.Variables.Add("RowsCopied",false,"User",0L);
    var srcConn=pkg.Connections.Add("FLATFILE");
    srcConn.Name="Teacher CSV - "+table;
    srcConn.ConnectionString=csv;
    var ff=(Microsoft.SqlServer.Dts.Runtime.Wrapper.IDTSConnectionManagerFlatFile100)srcConn.InnerObject;
    ff.Format="Delimited";ff.CodePage=65001;ff.Unicode=false;
    ff.ColumnNamesInFirstDataRow=true;ff.HeaderRowDelimiter="\r\n";
    ff.RowDelimiter="\r\n";ff.TextQualifier="\"";
    string[] fields=headers.Split(',');
    for(int n=0;n<fields.Length;n++) {
      var col=ff.Columns.Add();
      col.ColumnType="Delimited";col.ColumnDelimiter=n==fields.Length-1 ? "\r\n" : ",";
      col.DataType=Microsoft.SqlServer.Dts.Runtime.Wrapper.DataType.DT_WSTR;col.MaximumWidth=256;
      ((Microsoft.SqlServer.Dts.Runtime.Wrapper.IDTSName100)col).Name=fields[n];
    }
    var dstConn=pkg.Connections.Add("OLEDB");
    dstConn.Name="Assignment Warehouse";
    dstConn.ConnectionString=dstString;
    var task=(TaskHost)pkg.Executables.Add("STOCK:PipelineTask");
    task.Name="DFT "+table;
    var pipe=(MainPipe)task.InnerObject;
    var components=new Application();
    string sourceId=ResolveComponent(components,"Flat File Source","DTSAdapter.FlatFileSource");
    string countId=ResolveComponent(components,"Row Count","DTSTransform.RowCount");
    string destinationId=ResolveComponent(components,"OLE DB Destination","DTSAdapter.OleDbDestination");

    IDTSComponentMetaData100 source=pipe.ComponentMetaDataCollection.New();
    source.ComponentClassID=sourceId;
    source.Name="Flat File Source - "+table;
    CManagedComponentWrapper src=source.Instantiate();
    Initialize(src,"SOURCE",sourceId);
    source.RuntimeConnectionCollection[0].ConnectionManager=DtsConvert.GetExtendedInterface(srcConn);
    source.RuntimeConnectionCollection[0].ConnectionManagerID=srcConn.ID;
    src.AcquireConnections(null);src.ReinitializeMetaData();src.ReleaseConnections();

    IDTSComponentMetaData100 transform=pipe.ComponentMetaDataCollection.New();
    transform.ComponentClassID=countId;
    transform.Name="Row Count - audit";
    CManagedComponentWrapper counter=transform.Instantiate();
    Initialize(counter,"ROWCOUNT",countId);
    counter.SetComponentProperty("VariableName","User::RowsCopied");

    IDTSComponentMetaData100 destination=pipe.ComponentMetaDataCollection.New();
    destination.ComponentClassID=destinationId;
    destination.Name="OLE DB Destination - "+table;
    CManagedComponentWrapper dst=destination.Instantiate();
    Initialize(dst,"DESTINATION",destinationId);
    destination.RuntimeConnectionCollection[0].ConnectionManager=DtsConvert.GetExtendedInterface(dstConn);
    destination.RuntimeConnectionCollection[0].ConnectionManagerID=dstConn.ID;
    dst.SetComponentProperty("AccessMode",3);
    dst.SetComponentProperty("OpenRowset","[dbo].["+table+"]");
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
      converter.SetOutputColumnDataTypeProperties(conv.OutputCollection[0].ID,oc.ID,
        Microsoft.SqlServer.Dts.Runtime.Wrapper.DataType.DT_WSTR,256,0,0,0);
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
       string details="";
       foreach(DtsError err in pkg.Errors) details+="\nSSIS_ERROR: "+err.Description;
       throw new Exception("SSIS package returned "+execution+details);
    }
    return Convert.ToInt64(rows.Value);
  }
}
'@
Add-Type -TypeDefinition $sourceCode -ReferencedAssemblies $refs

$specs=@(
 @('Age_Table.csv','RefAge','Age_Id,Age',78),
 @('Customer_Education.csv','RefEducation','EDU_ID,Education_level',6),
 @('State_code.csv','RefState','state_name,state_code',8),
 @('seller_location.csv','RefSellerLocation','location_id,unit,street,postcode,suburb,state,type,status,region',100)
)
foreach($spec in $specs) {
 $table=$spec[1];$headers=$spec[2];$cols=($headers.Split(',')|ForEach-Object{"[$_] nvarchar(256) NULL"}) -join ','
 [void](Sql "IF OBJECT_ID('dbo.$table','U') IS NULL CREATE TABLE dbo.$table ($cols); DELETE FROM dbo.$table; SELECT 1;")
 $rows=[BismReferenceLoader]::Execute("C:\BISM2202\assignment_work\csv\"+$spec[0],$headers,$table,"Provider=MSOLEDBSQL;Data Source=.;Initial Catalog=STUDENT_${Student}_ID_dw;Integrated Security=SSPI;TrustServerCertificate=Yes;",(Join-Path $out "$table.dtsx"))
 $actual=Sql "SELECT COUNT_BIG(*) FROM dbo.$table"
 Say "$table SSIS_ROWS=$rows TARGET_ROWS=$actual EXPECTED=$($spec[3])"
 if($rows -ne $spec[3] -or $actual -ne $spec[3]){throw "Count mismatch $table"}
}
$c=New-Object System.Data.SqlClient.SqlConnection("Server=.;Database=STUDENT_${Student}_ID_dw;Integrated Security=True;Encrypt=False")
try {
 $c.Open();$export=@{}
 foreach($spec in $specs) {
  $cmd=$c.CreateCommand();$cmd.CommandText="SELECT * FROM dbo."+$spec[1];$r=$cmd.ExecuteReader();$data=@()
  while($r.Read()){$row=[ordered]@{};for($i=0;$i -lt $r.FieldCount;$i++){$row[$r.GetName($i)]=$r.GetValue($i)};$data+= [pscustomobject]$row};$r.Close();$export[$spec[1]]=$data
 }
 $export | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $out 'reference_rows.json') -Encoding UTF8
} finally {$c.Dispose()}
$success=$true
Say 'REFERENCE_DATAFLOWS=PASS'
} catch {Say ('REFERENCE_DATAFLOWS=FAIL '+$_.Exception.ToString())}
$log | Set-Content (Join-Path $out 'reference_results.txt') -Encoding UTF8
if(-not $success){exit 1}
