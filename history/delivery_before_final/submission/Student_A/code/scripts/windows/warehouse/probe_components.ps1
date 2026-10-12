$ErrorActionPreference='Stop'
function Say([string]$m){Write-Host $m}
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

$code=@'
using System;
using Microsoft.SqlServer.Dts.Runtime;
using Microsoft.SqlServer.Dts.Pipeline.Wrapper;
public class BismComponentProbe {
 public static string Run() {
 var p=new Package();var t=(TaskHost)p.Executables.Add("STOCK:PipelineTask");var pipe=(MainPipe)t.InnerObject;
 string output="";
 foreach(string wanted in new string[]{"Lookup","Derived Column","Sort","Merge Join","Flat File Source","Aggregate"}) {
 foreach(PipelineComponentInfo info in new Application().PipelineComponentInfos) {
 if(info.Name!=wanted)continue;
 var m=pipe.ComponentMetaDataCollection.New();m.ComponentClassID=info.CreationName;m.Name=wanted;var w=m.Instantiate();w.ProvideComponentProperties();
 output+="COMPONENT "+wanted+" "+info.CreationName+"\n";
 foreach(IDTSCustomProperty100 v in m.CustomPropertyCollection)output+=" PROPERTY "+v.Name+"="+v.Value+"\n";
 foreach(IDTSInput100 i in m.InputCollection){output+=" INPUT "+i.Name+"\n";foreach(IDTSCustomProperty100 v in i.CustomPropertyCollection)output+="   "+v.Name+"="+v.Value+"\n";}
 foreach(IDTSOutput100 o in m.OutputCollection){output+=" OUTPUT "+o.Name+"\n";foreach(IDTSCustomProperty100 v in o.CustomPropertyCollection)output+="   "+v.Name+"="+v.Value+"\n";}
 break;
 }
 }
 return output;
 }
}
'@
Add-Type -TypeDefinition $code -ReferencedAssemblies $refs
[BismComponentProbe]::Run() | Set-Content C:\BISM2202\analysis\component-probe.txt
} catch { $_.Exception.ToString() | Set-Content C:\BISM2202\analysis\component-probe.txt }
