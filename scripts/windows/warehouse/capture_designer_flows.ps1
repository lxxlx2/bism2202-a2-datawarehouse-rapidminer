# Native screenshot work in progress. File creation is not visual acceptance.
# Reviewed evidence and rejected attempts are recorded separately in the manifest.
param([ValidateSet('A','B')][string]$Student='A',[string]$Flow='DimGeography_Customer')
$ErrorActionPreference='Stop'
$out="C:\BISM2202\submission\Student_$Student\evidence\gui"
New-Item -ItemType Directory -Force $out | Out-Null
try {
 Add-Type -AssemblyName UIAutomationClient
 Add-Type -AssemblyName UIAutomationTypes
 Add-Type -AssemblyName System.Drawing
 Add-Type -AssemblyName System.Windows.Forms
 Add-Type -ReferencedAssemblies 'System.Drawing' -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class NativeDesigner {
 [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h,out uint pid);
 [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(System.Drawing.Point p);
 [DllImport("user32.dll")] public static extern bool ScreenToClient(IntPtr h,ref System.Drawing.Point p);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string cls,string title);
 [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h,uint m,IntPtr w,IntPtr l);
 [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h,uint m,IntPtr w,IntPtr l);
 [DllImport("user32.dll",CharSet=CharSet.Unicode,EntryPoint="SendMessageW")] public static extern IntPtr TextMessage(IntPtr h,uint m,IntPtr w,StringBuilder l);
 [DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
 [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr h);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")] public static extern void mouse_event(uint flags,uint x,uint y,uint data,UIntPtr extra);
}
'@
 [void][NativeDesigner]::SetProcessDPIAware()
 $p=@(Get-Process devenv|Where-Object{$_.MainWindowTitle -like "*STUDENT_${Student}_ID_SSIS*"})
 if($p.Count -eq 1){$windowHandle=$p[0].MainWindowHandle}else{
  $prior=Get-Content "C:\BISM2202\analysis\native_ui_$Student\processes.json" -Raw|ConvertFrom-Json
  $root=[System.Windows.Automation.AutomationElement]::FromHandle([IntPtr]$prior.MainWindowHandle)
  if($root.Current.ProcessId -ne $prior.Id -or (Get-Process -Id $prior.Id).ProcessName -ne 'devenv'){throw 'Previously verified own designer window no longer exists'}
  $windowHandle=[IntPtr]$prior.MainWindowHandle
 }
 $root=[System.Windows.Automation.AutomationElement]::FromHandle($windowHandle)
 $dialogCondition=New-Object System.Windows.Automation.AndCondition (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty,'Microsoft Visual Studio')),(New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty,$root.Current.ProcessId))
 $de=[System.Windows.Automation.AutomationElement]::RootElement.FindFirst([System.Windows.Automation.TreeScope]::Descendants,$dialogCondition)
 if($null -ne $de){
  $dialogNames=@($de.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition)|ForEach-Object{$_.Current.Name})
  if(-not @($dialogNames|Where-Object{$_ -like '*RPC_E_CANTCALLOUT_ININPUTSYNCCALL*'}).Count){throw 'Unexpected Visual Studio dialog; do not dismiss it'}

  @($de.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition)|ForEach-Object{[pscustomobject]@{Name=$_.Current.Name;Type=$_.Current.ControlType.ProgrammaticName;Handle=$_.Current.NativeWindowHandle;Patterns=@($_.GetSupportedPatterns()|ForEach-Object{$_.ProgrammaticName})}})|ConvertTo-Json -Depth 5|Set-Content "$out\dialog_diagnostic.json"
  $ok=$de.FindFirst([System.Windows.Automation.TreeScope]::Descendants,(New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty,'OK')))
  if($null -eq $ok -or $ok.Current.NativeWindowHandle -eq 0){throw 'Error dialog native OK control unavailable'}
  $okHandle=[IntPtr]$ok.Current.NativeWindowHandle
  [void][NativeDesigner]::PostMessage($okHandle,0xF5,[IntPtr]::Zero,[IntPtr]::Zero)
  [void][NativeDesigner]::PostMessage($okHandle,0x201,[IntPtr]1,[IntPtr]655370)
  [void][NativeDesigner]::PostMessage($okHandle,0x202,[IntPtr]::Zero,[IntPtr]655370)
  Start-Sleep -Seconds 3
 }
 "TIME=$(Get-Date -Format o) ROOT=$($root.Current.Name) ROOTPID=$($root.Current.ProcessId)" | Set-Content "$out\ui_diagnostic.txt"
 Start-Sleep -Seconds 1
 $combo=$root.FindFirst([System.Windows.Automation.TreeScope]::Descendants,(New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty,[System.Windows.Automation.ControlType]::ComboBox)))
 if($null -eq $combo -or $combo.Current.Name -ne 'Data Flow Task'){throw 'Expected native Data Flow Task combo'}
 $h=[IntPtr]$combo.Current.NativeWindowHandle
 $count=[NativeDesigner]::SendMessage($h,0x146,[IntPtr]::Zero,[IntPtr]::Zero).ToInt32()
 $items=@(for($i=0;$i -lt $count;$i++){$sb=New-Object System.Text.StringBuilder 512;[void][NativeDesigner]::TextMessage($h,0x148,[IntPtr]$i,$sb);$sb.ToString()})
 $wanted="DFT Student_${Student}_$Flow"
 $index=[Array]::IndexOf($items,$wanted)
 if($index -lt 0){throw "Actual combo does not contain $wanted; found $($items -join ', ')"}
 [void][NativeDesigner]::SetForegroundWindow($windowHandle)
 $combo.SetFocus()
 [void][NativeDesigner]::PostMessage($h,0x100,[IntPtr]36,[IntPtr]::Zero)
 [void][NativeDesigner]::PostMessage($h,0x101,[IntPtr]36,[IntPtr]::Zero)
 Start-Sleep -Seconds 2
 for($i=0;$i -lt $index;$i++){
  [void][NativeDesigner]::PostMessage($h,0x100,[IntPtr]40,[IntPtr]::Zero)
  [void][NativeDesigner]::PostMessage($h,0x101,[IntPtr]40,[IntPtr]::Zero)
  Start-Sleep -Seconds 2
 }
 Start-Sleep -Seconds 3
 $dialogCondition=New-Object System.Windows.Automation.AndCondition (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty,'Microsoft Visual Studio')),(New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty,$root.Current.ProcessId))
 $de=[System.Windows.Automation.AutomationElement]::RootElement.FindFirst([System.Windows.Automation.TreeScope]::Descendants,$dialogCondition)
 if($null -ne $de){
  $dialogNames=@($de.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition)|ForEach-Object{$_.Current.Name})
  if(-not @($dialogNames|Where-Object{$_ -like '*RPC_E_CANTCALLOUT_ININPUTSYNCCALL*'}).Count){throw 'Unexpected Visual Studio dialog; do not dismiss it'}

  @($de.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition)|ForEach-Object{[pscustomobject]@{Name=$_.Current.Name;Type=$_.Current.ControlType.ProgrammaticName;Handle=$_.Current.NativeWindowHandle;Patterns=@($_.GetSupportedPatterns()|ForEach-Object{$_.ProgrammaticName})}})|ConvertTo-Json -Depth 5|Set-Content "$out\dialog_diagnostic.json"
  $ok=$de.FindFirst([System.Windows.Automation.TreeScope]::Descendants,(New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty,'OK')))
  if($null -eq $ok -or $ok.Current.NativeWindowHandle -eq 0){throw 'Error dialog native OK control unavailable'}
  $okHandle=[IntPtr]$ok.Current.NativeWindowHandle
  [void][NativeDesigner]::PostMessage($okHandle,0xF5,[IntPtr]::Zero,[IntPtr]::Zero)
  [void][NativeDesigner]::PostMessage($okHandle,0x201,[IntPtr]1,[IntPtr]655370)
  [void][NativeDesigner]::PostMessage($okHandle,0x202,[IntPtr]::Zero,[IntPtr]655370)
  Start-Sleep -Seconds 3
 }
 $value=([System.Windows.Automation.ValuePattern]$combo.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)).Current.Value
 if($value -ne $wanted){throw "Native selection mismatch: $value"}
 $graph=$root.FindFirst([System.Windows.Automation.TreeScope]::Descendants,(New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::AutomationIdProperty,'graphControl')))
 if($null -eq $graph){throw 'Graph canvas not found'}
 $b=$graph.Current.BoundingRectangle
 if(@($items|Where-Object{$_ -notlike "DFT Student_${Student}_*"}).Count -gt 0){throw 'Task items are not exclusively the own student project'}
 $pt=New-Object System.Drawing.Point ([int]($b.Right-40)),([int]($b.Bottom-34))
 "GRAPH=$b POINT=$pt" | Add-Content "$out\ui_diagnostic.txt"
 $target=[NativeDesigner]::WindowFromPoint($pt)
 [void][NativeDesigner]::ScreenToClient($target,[ref]$pt)
 $lp=[IntPtr](($pt.Y -shl 16) -bor ($pt.X -band 65535))
 [void][NativeDesigner]::PostMessage($target,0x200,[IntPtr]::Zero,$lp)
 [void][NativeDesigner]::PostMessage($target,0x201,[IntPtr]1,$lp)
 [void][NativeDesigner]::PostMessage($target,0x202,[IntPtr]::Zero,$lp)
 Start-Sleep -Seconds 1
 [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
 Start-Sleep -Seconds 2
 [uint32]$foregroundPid=0
 [void][NativeDesigner]::GetWindowThreadProcessId([NativeDesigner]::GetForegroundWindow(),[ref]$foregroundPid)
 if($foregroundPid -ne $root.Current.ProcessId){throw 'Student Visual Studio process is not foreground; do not capture other windows'}
 "FOREGROUND_PID=$foregroundPid" | Add-Content "$out\ui_diagnostic.txt"
 $names=@($root.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition)|ForEach-Object{$_.Current.Name})
 if(@($names|Where-Object{$_ -like '*RPC_E_CANTCALLOUT_ININPUTSYNCCALL*'}).Count){throw 'RPC error dialog remains; no accepted capture'}
 $packagePath="C:\BISM2202\submission\Student_$Student\ssis\STUDENT_${Student}_ID_SSIS\Master.dtsx"
 [xml]$package=Get-Content $packagePath -Raw
 $flowNode=@($package.SelectNodes("//*[local-name()='Executable']")|Where-Object{$_.GetAttribute('ObjectName','www.microsoft.com/SqlServer/Dts') -eq $wanted})
 if($flowNode.Count -ne 1){throw 'Exactly one own native package flow definition required'}
 $expected=@($flowNode[0].SelectNodes(".//*[local-name()='component']")|ForEach-Object{$_.GetAttribute('name')})
 $missingComponents=@($expected|Where-Object{$_ -notin $names})
 if($missingComponents.Count){throw "Stale or incomplete canvas controls: $($missingComponents -join ', ')"}
 $names | ConvertTo-Json | Set-Content -Encoding UTF8 "$out\$Flow-controls.json"
 $map=@{DimCustomer_Lookup='ssis_dimcustomer';DimCustomer_Merge='ssis_dimcustomer';DimDate='ssis_dimdate';DimGeography_Customer='ssis_geography_customer';DimGeography_Seller='ssis_geography_seller';DimProduct='ssis_dimproduct';DimSeller='ssis_dimseller';FactSales='ssis_fact'}
 if(-not $map.ContainsKey($Flow)){throw 'Capture filename is not allowlisted'}
 $bounds=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds
 $bitmap=New-Object System.Drawing.Bitmap $bounds.Width,$bounds.Height
 $graphics=[System.Drawing.Graphics]::FromImage($bitmap)
 try{$graphics.CopyFromScreen($bounds.Location,[System.Drawing.Point]::Empty,$bounds.Size);$bitmap.Save((Join-Path $out ($map[$Flow]+'.png')),[System.Drawing.Imaging.ImageFormat]::Png)}finally{$graphics.Dispose();$bitmap.Dispose()}
 [pscustomobject]@{Student=$Student;SelectedTask=$value;ActualComboItems=$items;Capture=$map[$Flow]+'.png';Method='Actual Windows desktop pixels via CopyFromScreen; native controls selected without altering package';ScreenWidth=$bounds.Width;ScreenHeight=$bounds.Height;Status='NATIVE_SCREEN_CAPTURE_SAVED_VISUAL_REVIEW_REQUIRED'} | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 "$out\$Flow-capture.json"
 "NATIVE_FLOW_CAPTURE=SAVED_REVIEW_REQUIRED FLOW=$Flow TIME=$(Get-Date -Format o)" | Set-Content -Encoding UTF8 "$out\capture_status.txt"
}catch{
 "NATIVE_FLOW_CAPTURE=FAIL FLOW=$Flow $($_.Exception.ToString())" | Set-Content -Encoding UTF8 "$out\capture_status.txt"
 exit 1
}
