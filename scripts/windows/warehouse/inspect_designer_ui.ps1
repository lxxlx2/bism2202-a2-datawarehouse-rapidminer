param([ValidateSet('A','B')][string]$Student='A')
$ErrorActionPreference='Stop'
$out="C:\BISM2202\analysis\native_ui_$Student"
New-Item -ItemType Directory -Force $out | Out-Null
try {
 Add-Type -AssemblyName UIAutomationClient
 Add-Type -AssemblyName UIAutomationTypes
 $processes=@(Get-Process devenv | Where-Object {$_.MainWindowTitle -like "*STUDENT_${Student}_ID_SSIS*"})
 $processes | Select-Object Id,MainWindowTitle,MainWindowHandle,SessionId | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 "$out\processes.json"
 if($processes.Count -ne 1){throw 'Expected exactly one matching student Visual Studio window'}
 $root=[System.Windows.Automation.AutomationElement]::FromHandle($processes[0].MainWindowHandle)
 $elements=$root.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition)
 $rows=@(foreach($e in $elements){
  try{
   $c=$e.Current;$b=$c.BoundingRectangle
   [pscustomobject]@{Name=$c.Name;Type=$c.ControlType.ProgrammaticName;Id=$c.AutomationId;Class=$c.ClassName;Handle=$c.NativeWindowHandle;Offscreen=$c.IsOffscreen;Enabled=$c.IsEnabled;X=$b.X;Y=$b.Y;Width=$b.Width;Height=$b.Height;Patterns=@($e.GetSupportedPatterns()|ForEach-Object{$_.ProgrammaticName})}
  }catch{}
 })
 $rows | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 "$out\controls.json"
 "NATIVE_UI_INSPECTION=PASS SESSION=$((Get-Process -Id $PID).SessionId) CONTROLS=$($rows.Count)" | Set-Content -Encoding UTF8 "$out\status.txt"
}catch{
 "NATIVE_UI_INSPECTION=FAIL $($_.Exception.ToString())" | Set-Content -Encoding UTF8 "$out\status.txt"
 exit 1
}
