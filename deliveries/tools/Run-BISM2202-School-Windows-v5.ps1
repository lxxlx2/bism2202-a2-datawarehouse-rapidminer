param([string]$ProjectRoot = '', [int]$TimeoutMinutes = 8)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class BW {
 [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h,int code);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")] public static extern void mouse_event(uint f,uint x,uint y,uint d,UIntPtr e);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h,StringBuilder text,int max);
}
'@
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
$script:records=New-Object System.Collections.ArrayList
$script:files=@{}
$script:output=$null
$script:logfile=$null
function Log([string]$message) {
 $s=(Get-Date -Format 'HH:mm:ss')+' '+$message
 Write-Host $s
 if($script:logfile){Add-Content -LiteralPath $script:logfile -Value $s -Encoding UTF8}
}
function Mark([string]$code,[string]$category,[string]$status,[string]$detail){
 [void]$script:records.Add([pscustomobject]@{model=$code;category=$category;status=$status;detail=$detail})
 Log ($code+' | '+$category+' | '+$status+' | '+$detail)
}
function FindProject {
 if($ProjectRoot) {
  $base=(Resolve-Path -LiteralPath $ProjectRoot).Path
  if(Test-Path -LiteralPath (Join-Path $base 'rapidminer\GradientBoostedTrees_Full.rmp')){return $base}
  if((Split-Path -Leaf $base) -eq 'rapidminer'){return (Split-Path -Parent $base)}
  throw 'ProjectRoot does not contain a rapidminer folder.'
 }
 $candidate=New-Object System.Collections.ArrayList
 foreach($root in @('H:\',$env:OneDriveCommercial,$env:OneDrive,(Get-Location).Path)){
  if(-not $root -or -not (Test-Path -LiteralPath $root)){continue}
  if(Test-Path -LiteralPath (Join-Path $root 'rapidminer\GradientBoostedTrees_Full.rmp')){[void]$candidate.Add($root)}
  foreach($d in @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | Where-Object {$_.Name -match 'BISM2202'})){
   if(Test-Path -LiteralPath (Join-Path $d.FullName 'rapidminer\GradientBoostedTrees_Full.rmp')){[void]$candidate.Add($d.FullName)}
  }
 }
 if($candidate.Count -eq 0){throw 'PROJECT_NOT_FOUND: Expected H:\BISM2202*\rapidminer\GradientBoostedTrees_Full.rmp'}
 return [string]$candidate[0]
}
function SetMacro([xml]$doc,[string]$name,[string]$value) {
 $macros=$doc.SelectSingleNode('/process/context/macros')
 if(-not $macros){throw 'RMP does not define macros'}
 $n=$macros.SelectSingleNode('./macro[key="'+$name+'"]')
 if(-not $n){$n=$doc.CreateElement('macro');$k=$doc.CreateElement('key');$k.InnerText=$name;[void]$n.AppendChild($k);$v=$doc.CreateElement('value');[void]$n.AppendChild($v);[void]$macros.AppendChild($n)}
 $n.SelectSingleNode('./value').InnerText=$value
}
function NewOperator([xml]$xml,[System.Xml.XmlNode]$body,[string]$class,[string]$name,[int]$x,[int]$y,[hashtable]$parameters){
 $node=$xml.CreateElement('operator')
 foreach($p in @{activated='true';class=$class;compatibility='10.3.001';expanded='true';height='68';width='90';name=$name;x=[string]$x;y=[string]$y}.GetEnumerator()){$node.SetAttribute([string]$p.Key,[string]$p.Value)}
 foreach($entry in $parameters.GetEnumerator()){$a=$xml.CreateElement('parameter');$a.SetAttribute('key',[string]$entry.Key);$a.SetAttribute('value',[string]$entry.Value);[void]$node.AppendChild($a)}
 [void]$body.AppendChild($node)
}
function Edge([xml]$xml,[System.Xml.XmlNode]$body,[string]$from,[string]$port,[string]$to,[string]$target){
 $e=$xml.CreateElement('connect');$e.SetAttribute('from_op',$from);$e.SetAttribute('from_port',$port)
 if($to){$e.SetAttribute('to_op',$to)}
 $e.SetAttribute('to_port',$target);[void]$body.AppendChild($e)
}
function Prepare([string]$code,[string]$source,[string]$csv,[string]$folder) {
 [xml]$xml=Get-Content -LiteralPath $source -Raw -Encoding UTF8
 $b=$xml.SelectSingleNode('/process/operator/process')
 if(-not $b){throw 'RMP_INVALID_ROOT'}
 $cv=@($b.SelectNodes('./operator[@class="x_validation"]'));$split=@($b.SelectNodes('./operator[@class="split_data"]'))
 $app=@($b.SelectNodes('./operator[@class="apply_model"]'));$perf=@($b.SelectNodes('./operator[@class="performance_binominal_classification"]'))
 if($cv.Count -ne 1 -or $split.Count -ne 1 -or $app.Count -ne 1 -or $perf.Count -ne 1){throw 'RMP_INVALID_OPERATORS'}
 $cv=$cv[0];$split=$split[0];$app=$app[0];$perf=$perf[0]
 $ratios=@($split.SelectNodes('./enumeration[@key="partitions"]/parameter') | ForEach-Object {$_.GetAttribute('value')})
 $n=$cv.SelectSingleNode('./parameter[@key="number_of_validations"]')
 if($ratios.Count -ne 2 -or [math]::Abs(([double]$ratios[0])-0.75) -gt .0001 -or [math]::Abs(([double]$ratios[1])-0.25) -gt .0001 -or -not $n -or $n.GetAttribute('value') -ne '5'){throw 'RMP_INVALID_SPLIT_OR_CV'}
 $base=Join-Path $folder ('ready_'+$code+'.rmp')
 SetMacro $xml 'source_csv' $csv
 $old=@($b.SelectNodes('./connect[@to_port="result 4"]') | Where-Object {-not $_.HasAttribute('to_op')})
 foreach($e in $old){[void]$b.RemoveChild($e)}
 Edge $xml $b $app.GetAttribute('name') 'model' '' 'result 4'
 $xml.Save($base)
 $probe=New-Object System.Xml.XmlDocument;$probe.Load($base)
 Mark $code 'baseline_program' 'PREPARED' $base

 $paths=@{cv_results=(Join-Path $folder ($code+'_CV_Metrics.csv'));holdout_results=(Join-Path $folder ($code+'_Holdout_Metrics.csv'));holdout_predictions=(Join-Path $folder ($code+'_Holdout_Predictions.csv'))}
 foreach($k in $paths.Keys){Param $xml ($k+'_path') $paths[$k]}
 $edgeCv=@($b.SelectNodes('./connect')|Where-Object {$_.GetAttribute('from_op') -eq $cv.GetAttribute('name') -and $_.GetAttribute('from_port') -eq 'averagable 1' -and $_.GetAttribute('to_port') -eq 'result 1' -and -not $_.HasAttribute('to_op')})
 $edgePerf=@($b.SelectNodes('./connect')|Where-Object {$_.GetAttribute('from_op') -eq $perf.GetAttribute('name') -and $_.GetAttribute('from_port') -eq 'performance' -and $_.GetAttribute('to_port') -eq 'result 2' -and -not $_.HasAttribute('to_op')})
 $edgePred=@($b.SelectNodes('./connect')|Where-Object {$_.GetAttribute('from_op') -eq $perf.GetAttribute('name') -and $_.GetAttribute('from_port') -eq 'example set' -and $_.GetAttribute('to_port') -eq 'result 3' -and -not $_.HasAttribute('to_op')})
 if($edgeCv.Count -ne 1 -or $edgePerf.Count -ne 1 -or $edgePred.Count -ne 1){throw 'RMP_UNEXPECTED_RESULT_WIRING'}
 foreach($e in @($edgeCv[0],$edgePerf[0],$edgePred[0])){[void]$b.RemoveChild($e)}
 NewOperator $xml $b 'performance_to_data' 'Audit CV Performance' 1330 65 @{}
 NewOperator $xml $b 'performance_to_data' 'Audit Holdout Performance' 1330 200 @{}
 NewOperator $xml $b 'write_csv' 'Save CV Metrics' 1480 65 @{csv_file='%{cv_results_path}';write_attribute_names='true'}
 NewOperator $xml $b 'write_csv' 'Save Holdout Metrics' 1480 200 @{csv_file='%{holdout_results_path}';write_attribute_names='true'}
 NewOperator $xml $b 'write_csv' 'Save Holdout Predictions' 1480 335 @{csv_file='%{holdout_predictions_path}';write_attribute_names='true'}
 Edge $xml $b $cv.GetAttribute('name') 'averagable 1' 'Audit CV Performance' 'performance vector'
 Edge $xml $b 'Audit CV Performance' 'performance vector' '' 'result 1'
 Edge $xml $b 'Audit CV Performance' 'example set' 'Save CV Metrics' 'input'
 Edge $xml $b $perf.GetAttribute('name') 'performance' 'Audit Holdout Performance' 'performance vector'
 Edge $xml $b 'Audit Holdout Performance' 'performance vector' '' 'result 2'
 Edge $xml $b 'Audit Holdout Performance' 'example set' 'Save Holdout Metrics' 'input'
 Edge $xml $b $perf.GetAttribute('name') 'example set' 'Save Holdout Predictions' 'input'
 Edge $xml $b 'Save Holdout Predictions' 'through' '' 'result 3'
 $prepared=Join-Path $folder ($code+'_AutoEvidence.rmp')
 $xml.Save($prepared)
 $probe.Load($prepared)
 Mark $code 'metrics_export_program' 'PREPARED_UNTESTED' $prepared
 return @{baseline=$base;export=$prepared;outputs=$paths}
}
function RMProcess {
 $items=@(Get-Process -ErrorAction SilentlyContinue | Where-Object {$_.MainWindowHandle -ne [IntPtr]::Zero -and $_.MainWindowTitle -match 'RapidMiner|AI Studio'})
 if($items.Count -eq 0){return $null}
 return $items[0]
}
function ForegroundTitle {
 $h=[BW]::GetForegroundWindow();$s=New-Object System.Text.StringBuilder(500)
 [void][BW]::GetWindowText($h,$s,500);return $s.ToString()
}
function FocusRM {
 $r=RMProcess
 if(-not $r){throw 'RAPIDMINER_WINDOW_NOT_FOUND'}
 [void][BW]::ShowWindow($r.MainWindowHandle,3);[void][BW]::SetForegroundWindow($r.MainWindowHandle)
 Start-Sleep -Milliseconds 900
 return $r
}
function Rect {
 $r=RMProcess
 if(-not $r){throw 'RAPIDMINER_WINDOW_NOT_FOUND'}
 $rect=New-Object BW+RECT
 if(-not [BW]::GetWindowRect($r.MainWindowHandle,[ref]$rect)){throw 'CANNOT_READ_WINDOW_RECT'}
 if(($rect.Right-$rect.Left) -lt 900 -or ($rect.Bottom-$rect.Top) -lt 550){throw 'WINDOW_TOO_SMALL'}
 return $rect
}
function Press([string]$keys){[System.Windows.Forms.SendKeys]::SendWait($keys);Start-Sleep -Milliseconds 500}
function Click([double]$x,[double]$y,[int]$count=1){
 $r=Rect
 $xx=$r.Left+[int](($r.Right-$r.Left)*$x);$yy=$r.Top+[int](($r.Bottom-$r.Top)*$y)
 [void][BW]::SetCursorPos($xx,$yy)
 for($i=0;$i -lt $count;$i++){[BW]::mouse_event(2,0,0,0,[UIntPtr]::Zero);[BW]::mouse_event(4,0,0,0,[UIntPtr]::Zero);Start-Sleep -Milliseconds 150}
 Start-Sleep -Milliseconds 600
}
function Fingerprint([Drawing.Bitmap]$bm) {
 $small=New-Object Drawing.Bitmap(36,24)
 $g=[Drawing.Graphics]::FromImage($small)
 try {$g.DrawImage($bm,0,0,36,24)}finally{$g.Dispose()}
 $buffer=New-Object System.Collections.ArrayList
 try {for($yy=0;$yy -lt 24;$yy++){for($xx=0;$xx -lt 36;$xx++){$c=$small.GetPixel($xx,$yy);[void]$buffer.Add(([int]($c.R/24)*100+[int]($c.G/24)*10+[int]($c.B/24)))}}}finally{$small.Dispose()}
 return (($buffer | ForEach-Object {"$_"}) -join ',')
}
function Capture([string]$code,[string]$tag) {
 if(-not (RMProcess)){Mark $code $tag 'SKIPPED_NO_WINDOW' '';return}
 $r=Rect
 $bm=New-Object Drawing.Bitmap(($r.Right-$r.Left),($r.Bottom-$r.Top))
 $g=[Drawing.Graphics]::FromImage($bm)
 $name=($code+'_'+$tag+'_REVIEW.png')
 try {
  $g.CopyFromScreen($r.Left,$r.Top,0,0,$bm.Size)
  $fp=Fingerprint $bm
  $key=($code+'|'+$fp)
  if($script:files.ContainsKey($key)){Mark $code $tag 'SKIPPED_DUPLICATE_IMAGE' $script:files[$key];return}
  $script:files[$key]=$name
  $path=Join-Path $script:output $name
  $bm.Save($path,[System.Drawing.Imaging.ImageFormat]::Png)
  Mark $code $tag 'CAPTURED_REVIEW_REQUIRED' $path
 }finally{$g.Dispose();$bm.Dispose()}
}
function OpenRM([string]$path,[string]$code){
 [void](FocusRM)
 # Use File > Import Process. Ctrl+O opens a repository chooser in Studio 10.3.
 Press '{ESC}';Press '{ESC}';Press '%f';Press 'm';Start-Sleep -Seconds 1
 $saved='';try{$saved=[System.Windows.Forms.Clipboard]::GetText()}catch{}
 try {
  [System.Windows.Forms.Clipboard]::SetText($path)
  Press '%n';Press '^a';Press '^v';Press '{ENTER}'
  Start-Sleep -Seconds 5
  if((ForegroundTitle) -match 'Process Import Messages'){Press '{ENTER}';Start-Sleep -Seconds 1}
  $title=(RMProcess).MainWindowTitle
  if($title -match [regex]::Escape([IO.Path]::GetFileNameWithoutExtension($path))){Mark $code 'gui_import' 'TITLE_VERIFIED' $title;return $true}
  Capture $code '00_Import_Diagnostic'
  Mark $code 'gui_import' 'FAILED' $title
  Press '{ESC}'
  return $false
 } finally {try{[System.Windows.Forms.Clipboard]::SetText($saved)}catch{}}
}
function TryBatch([string]$code,[hashtable]$set) {
 $bat=$null
 foreach($root in @($env:ProgramFiles,${env:ProgramFiles(x86)},$env:LOCALAPPDATA)) {
  if(-not $root){continue}
  foreach($path in @('RapidMiner\RapidMiner Studio\scripts\rapidminer-batch.bat','RapidMiner\RapidMiner Studio 10.3\scripts\rapidminer-batch.bat','Altair\RapidMiner Studio\scripts\rapidminer-batch.bat')){
   $x=Join-Path $root $path;if(Test-Path -LiteralPath $x){$bat=$x;break}
  }
  if($bat){break}
 }
 if(-not $bat){Mark $code 'batch' 'NOT_AVAILABLE' 'No installed rapidminer-batch.bat';return}
 $log=Join-Path $script:output ($code+'_NativeBatch.log')
 $err=Join-Path $script:output ($code+'_NativeBatch.err')
 $args='/d /s /c ""'+$bat+'" -f "'+$set.export+'""'
 $proc=Start-Process -FilePath 'cmd.exe' -ArgumentList $args -PassThru -RedirectStandardOutput $log -RedirectStandardError $err -WindowStyle Hidden
 $stop=(Get-Date).AddMinutes($TimeoutMinutes)
 while(-not $proc.HasExited -and (Get-Date) -lt $stop){Start-Sleep -Seconds 3;$proc.Refresh()}
 if(-not $proc.HasExited){try{$proc.Kill()}catch{};Mark $code 'batch' 'TIMEOUT' $log;return}
 $expected=@($set.outputs.Values)
 $missing=@($expected|Where-Object {-not (Test-Path -LiteralPath $_) -or (Get-Item -LiteralPath $_).Length -le 5})
 if($proc.ExitCode -eq 0 -and $missing.Count -eq 0){Mark $code 'batch' 'NATIVE_CSV_PASS' $log}
 else{Mark $code 'batch' 'FAILED_OR_NO_CSV' ('exit='+$proc.ExitCode+' missing='+$missing.Count+' log='+$log)}
}
function TryGui([string]$code,[hashtable]$set){
 if(-not (RMProcess)){Mark $code 'gui' 'NOT_AVAILABLE' 'RapidMiner Studio is not open';return}
 $candidate=$set.export
 if(-not (OpenRM $candidate $code)) {
  Mark $code 'gui_import' 'TRY_BASELINE_FALLBACK' $set.baseline
  if(-not (OpenRM $set.baseline $code)){return}
 }
 Click 0.39 0.073
 # Studio 10.3 process canvas Fit-to-Window button in upper right of Process panel.
 Click 0.607 0.245
 Capture $code '01_Process_Overview'
 # CV GUI controls are Java/Swing; probe a known area but keep all results review-only.
 Click 0.52 0.345 2
 Capture $code '02_CV_Training_Probe'
 Click 0.49 0.285
 Capture $code '03_CV_Testing_Probe'
 Press '{ESC}'
 Click 0.39 0.073
 $start=Get-Date
 Click 0.155 0.075
 Mark $code 'gui_run' 'CLICKED_UNVERIFIED' ''
 $deadline=(Get-Date).AddMinutes($TimeoutMinutes)
 while((Get-Date) -lt $deadline){
  Start-Sleep -Seconds 4
  $done=@($set.outputs.Values|Where-Object {(Test-Path -LiteralPath $_ -PathType Leaf) -and ((Get-Item -LiteralPath $_).LastWriteTime -ge $start)})
  if($done.Count -eq 3){$ok=$true;foreach($f in $done){if((Get-Item -LiteralPath $f).Length -le 5){$ok=$false}}
   if($ok){Mark $code 'gui_run' 'RESULT_CSV_PRESENT' '';break}}
  if((ForegroundTitle) -match 'Error|Exception|Import Process|Open Process'){Capture $code '00_Runtime_Diagnostic';Mark $code 'gui_run' 'BLOCKED_BY_DIALOG' (ForegroundTitle);return}
 }
 # Results tabs are only captured when the exported CSV files exist.
 $ok=@($set.outputs.Values|Where-Object {(Test-Path -LiteralPath $_ -PathType Leaf) -and (Get-Item -LiteralPath $_).Length -gt 5 -and (Get-Item -LiteralPath $_).LastWriteTime -ge $start}).Count
 if($ok -ne 3){Mark $code 'gui_results' 'NOT_VERIFIED' 'Missing one or more CSV outputs';Capture $code '00_Results_Diagnostic';return}
 Click 0.47 0.075
 Capture $code '04_Results_Overview'
 foreach($tab in @(@{label='05_Holdout_Metrics';x=.28;y=.14},@{label='06_CV_Metrics';x=.75;y=.14},@{label='07_Model';x=.29;y=.19},@{label='08_Predictions';x=.75;y=.19})){
  Click $tab.x $tab.y
  Capture $code $tab.label
 }
}
function CarryPriorEvidence([string]$project) {
 $area=Join-Path $project 'evidence'
 if(-not (Test-Path -LiteralPath $area)){return}
 $target=Join-Path $script:output 'prior_evidence_review'
 $patterns=@('NB_05_Holdout_Performance.png','NB_06_CV_Performance.png','NB_08_Prediction_Table.png')
 foreach($name in $patterns) {
  $files=@(Get-ChildItem -LiteralPath $area -Recurse -File -Filter $name -ErrorAction SilentlyContinue | Where-Object {$_.FullName -notlike ($script:output+'*')} | Sort-Object LastWriteTime -Descending)
  if($files.Count -eq 0){continue}
  $file=$files[0]
  [void](New-Item -ItemType Directory -Path $target -Force)
  $dst=Join-Path $target $name
  Copy-Item -LiteralPath $file.FullName -Destination $dst -Force
  Mark 'PRIOR' $name 'COPIED_REVIEW_REQUIRED' ($file.FullName+' -> '+$dst)
 }
}
function InspectDB([string]$root) {
 $sqlFile=Join-Path $root 'sql\02_queries.sql'
 if(-not (Test-Path -LiteralPath $sqlFile)){Mark 'DW' 'sql_queries' 'MISSING' $sqlFile;return}
 $cn=New-Object System.Data.SqlClient.SqlConnection('Server=.;Database=BISM2202_A2_dw;Integrated Security=True;Encrypt=False;Connection Timeout=5')
 try {
  $cn.Open()
  $check=$cn.CreateCommand();$check.CommandText="SELECT COUNT_BIG(*) FROM sys.tables WHERE name IN ('FactOrderItem','DimCustomer','DimProduct')"
  $count=[int]$check.ExecuteScalar()
  if($count -ne 3){Mark 'DW' 'sql_database' 'INCOMPLETE_SCHEMA' ('tables='+$count);return}
  $rows=$cn.CreateCommand();$rows.CommandText='SELECT COUNT_BIG(*) FROM dbo.FactOrderItem'
  $factCount=[long]$rows.ExecuteScalar()
  if($factCount -ne 137901){Mark 'DW' 'sql_database' 'FACT_NOT_RECONCILED' ('FactOrderItem='+$factCount);return}
  Mark 'DW' 'sql_database' 'CONNECTED_RECONCILED_FACT_COUNT' $cn.Database
  # Export query results as actual data files; no synthetic SSMS screenshots.
  $raw=[IO.File]::ReadAllText($sqlFile)
  $batches=@([regex]::Split($raw,'(?im)^\s*GO\s*(?:\r?\n|$)')|Where-Object {$_.Trim()})
  $i=0
  foreach($batch in $batches){
   if($batch -notmatch '(?is)\bSELECT\b'){continue}
   $i++
   $cmd=$cn.CreateCommand();$cmd.CommandText=$batch;$cmd.CommandTimeout=120
   $table=New-Object System.Data.DataTable
   $adapter=New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
   [void]$adapter.Fill($table)
   $target=Join-Path $script:output ('Q4_'+$i+'_Native_SQL_Results.csv')
   $lines=New-Object System.Collections.ArrayList
   [void]$lines.Add((($table.Columns|ForEach-Object {'"'+$_.ColumnName.Replace('"','""')+'"'}) -join ','))
   foreach($row in $table.Rows){[void]$lines.Add((($table.Columns|ForEach-Object {'"'+([string]$row[$_.ColumnName]).Replace('"','""')+'"'}) -join ','))}
   [IO.File]::WriteAllLines($target,[string[]]$lines.ToArray(),[Text.UTF8Encoding]::new($true))
   Mark 'DW' ('query_'+$i) 'NATIVE_SQL_CSV' ($target+' rows='+$table.Rows.Count)
  }
 }catch{Mark 'DW' 'sql_database' 'NOT_VERIFIED' $_.Exception.Message}
 finally{$cn.Dispose()}
}
try {
 if([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT){throw 'WINDOWS_ONLY'}
 $project=FindProject
 $source=Join-Path $project 'rapidminer'
 $csv=Join-Path $source 'data\BISM2202_A2_Loan_Data_Set_RapidMiner2026S2.csv'
 if(-not (Test-Path -LiteralPath $csv)){throw 'MISSING_TEACHER_LOAN_CSV'}
 $hash=(Get-FileHash -LiteralPath $csv -Algorithm SHA256).Hash
 if($hash -ne 'B333ABEF401D01DCE2B0115B65649400238C01D9362B328C8CA1C4C19876D00A'){throw 'TEACHER_CSV_HASH_MISMATCH'}
 $script:output=Join-Path $project ('evidence\rapidminer\run_'+$stamp)
 [void](New-Item -ItemType Directory -Force -Path $script:output)
 $script:logfile=Join-Path $script:output 'execution.log'
 $programs=@{}
 Log ('PROJECT='+$project)
 Log ('OUTPUT='+$script:output)
 CarryPriorEvidence $project
 foreach($code in @('GBT','NB')){
  $name=if($code -eq 'GBT'){'GradientBoostedTrees_Full.rmp'}else{'NaiveBayes_Full.rmp'}
  $src=Join-Path $source $name
  if(-not (Test-Path -LiteralPath $src)){throw ('MISSING_RMP '+$name)}
  $dest=Join-Path $script:output ('ORIGINAL_'+$name)
  Copy-Item -LiteralPath $src -Destination $dest
  $programs[$code]=Prepare $code $src $csv $script:output
 }
 foreach($code in @('GBT','NB')){
  TryBatch $code $programs[$code]
  $expected=@($programs[$code].outputs.Values|Where-Object {Test-Path -LiteralPath $_ -PathType Leaf})
  if($expected.Count -eq 3){
   $batchFolder=Join-Path $script:output 'native_batch_results'
   [void](New-Item -ItemType Directory -Force -Path $batchFolder)
   foreach($file in $expected){Copy-Item -LiteralPath $file -Destination (Join-Path $batchFolder ([IO.Path]::GetFileName($file))) -Force}
  }
  TryGui $code $programs[$code]
 }
 InspectDB $project
 $required=@('01_DW_Star_Schema','02_SSIS_Dimensions','03_SSIS_Fact','04_SQL_Q4_1','05_SQL_Q4_2','06_SQL_Q4_3','07_NB_Overall','08_NB_CV_Training','09_NB_CV_Testing','10_NB_Model','11_NB_Test_Performance','12_GBT_Overall','13_GBT_CV_Training','14_GBT_CV_Testing','15_GBT_Model','16_GBT_Test_Performance')
 $text=New-Object System.Collections.ArrayList
 [void]$text.Add('Evidence requirements. Files are never treated as verified based only on their filename.')
 foreach($item in $required){[void]$text.Add(('[ ] '+$item+' | verify native software screenshot separately'))}
 [IO.File]::WriteAllLines((Join-Path $script:output 'EVIDENCE_REQUIREMENTS.txt'),[string[]]$text.ToArray())
 $manifest=@{scope='RapidMiner program repair, native export attempt, GUI capture attempt, read-only DW SQL if available';project=$project;output=$script:output;teacher_csv_sha256=$hash;records=@($script:records);native_gui_screenshots_not_auto_verified=$true;ssis_screenshots_not_auto_verified=$true}
 $manifest|ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $script:output 'manifest.json') -Encoding UTF8
 $zip=Join-Path $project ('BISM2202_Evidence_'+$stamp+'.zip')
 Compress-Archive -Path (Join-Path $script:output '*') -DestinationPath $zip -Force
 Log ('LOCAL_ZIP='+$zip)
 Write-Host ('FINISHED. RESULTS='+$script:output) -ForegroundColor Green
 Write-Host ('ZIP='+$zip) -ForegroundColor Green
}catch{
 $err=$_.Exception.ToString()
 Write-Host ('FAILED='+$err) -ForegroundColor Red
 if($script:logfile){Log ('FAILED='+$err)}
 exit 1
}