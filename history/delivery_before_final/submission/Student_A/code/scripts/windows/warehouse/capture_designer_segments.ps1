# Genuine native desktop segments; visual review is required before acceptance.
param([ValidateSet('A','B')][string]$Student='A',[ValidateSet('DimCustomer_Lookup','DimCustomer_MergeJoin','DimDate','DimGeography_Customer','DimGeography_Seller','DimProduct','DimSeller','FactSales')][string]$Flow='FactSales')
$ErrorActionPreference='Stop'
try{
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

 $ids=@((Get-Process devenv).Id)
 $roots=@([System.Windows.Automation.AutomationElement]::RootElement.FindAll([System.Windows.Automation.TreeScope]::Children,[System.Windows.Automation.Condition]::TrueCondition)|Where-Object{$_.Current.ProcessId -in $ids -and $_.Current.Name -like "*STUDENT_${Student}_ID_SSIS*"})
 if($roots.Count -ne 1){throw 'Own student native root not unique'}
 $p=@([pscustomobject]@{Id=$roots[0].Current.ProcessId;MainWindowHandle=[IntPtr]$roots[0].Current.NativeWindowHandle})
 [void][NativeDesigner]::SetForegroundWindow($p[0].MainWindowHandle)
 [uint32]$pidCheck=0
 [void][NativeDesigner]::GetWindowThreadProcessId([NativeDesigner]::GetForegroundWindow(),[ref]$pidCheck)
 if($pidCheck -ne $p[0].Id){throw 'Foreground not own A'}

 $root=$roots[0]
 $combo=$root.FindFirst([System.Windows.Automation.TreeScope]::Descendants,(New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty,'Data Flow Task')))
 $value=([System.Windows.Automation.ValuePattern]$combo.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)).Current.Value
 if($value -ne "DFT Student_${Student}_$Flow"){throw "Own selected $Flow task required"}
 $graph=$root.FindFirst([System.Windows.Automation.TreeScope]::Descendants,(New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::AutomationIdProperty,'graphControl')))
 $gb=$graph.Current.BoundingRectangle
 [void][NativeDesigner]::SetForegroundWindow($p[0].MainWindowHandle)
 Start-Sleep -Seconds 1
 [uint32]$zoomPid=0
 $zoomPoint=New-Object System.Drawing.Point ([int]($gb.Right-46)),([int]($gb.Bottom-57))
 for($attempt=0;$attempt -lt 6;$attempt++){
  [void][NativeDesigner]::SetForegroundWindow($p[0].MainWindowHandle)
  Start-Sleep -Seconds 1
  [void][NativeDesigner]::GetWindowThreadProcessId([NativeDesigner]::WindowFromPoint($zoomPoint),[ref]$zoomPid)
  if($zoomPid -eq $p[0].Id){break}
 }
 if($zoomPid -ne $p[0].Id){throw 'Zoom point is outside the own Visual Studio process'}
 [void][NativeDesigner]::SetCursorPos([int]($gb.Right-46),[int]($gb.Bottom-57))
 [NativeDesigner]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
 [NativeDesigner]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
 [System.Windows.Forms.SendKeys]::SendWait('{DOWN 24}')
 Start-Sleep -Seconds 2
 [System.Windows.Forms.SendKeys]::SendWait('{UP 9}')
 Start-Sleep -Seconds 3
 $sp=[System.Windows.Automation.ScrollPattern]$graph.GetCurrentPattern([System.Windows.Automation.ScrollPattern]::Pattern)
 $view=$sp.Current.VerticalViewSize
 $horizontalView=$sp.Current.HorizontalViewSize
 function PageSteps($size){if($size -ge 100){return 0};return [int][Math]::Ceiling(100/(80*$size/(100-$size)))}
 $n=PageSteps $view
 $nx=PageSteps $horizontalView
 if(($n+1)*($nx+1) -gt 40){throw 'Excessive number of native capture pages'}
 [xml]$pkg=Get-Content "C:\BISM2202\submission\Student_$Student\ssis\STUDENT_${Student}_ID_SSIS\Master.dtsx" -Raw
 $fn=@($pkg.SelectNodes("//*[local-name()='Executable']")|Where-Object{$_.GetAttribute('ObjectName','www.microsoft.com/SqlServer/Dts') -eq $value})
 $expected=@($fn[0].SelectNodes(".//*[local-name()='component']")|ForEach-Object{$_.GetAttribute('name')})
 $out="C:\BISM2202\submission\Student_$Student\evidence\gui"
 $prefix=@{DimCustomer_Lookup='ssis_dimcustomer';DimCustomer_MergeJoin='ssis_dimcustomer';DimDate='ssis_dimdate';DimGeography_Customer='ssis_geography_customer';DimGeography_Seller='ssis_geography_seller';DimProduct='ssis_dimproduct';DimSeller='ssis_dimseller';FactSales='ssis_fact'}[$Flow]
 $records=@()
 for($x=0;$x -le $nx;$x++){for($i=0;$i -le $n;$i++){
  $percent=if($n -eq 0){0}else{100.0*$i/$n}
  $xp=if($nx -eq 0){[System.Windows.Automation.ScrollPattern]::NoScroll}else{100.0*$x/$nx}
  $yp=if($n -eq 0){[System.Windows.Automation.ScrollPattern]::NoScroll}else{$percent}
  if($sp.Current.VerticallyScrollable -or $sp.Current.HorizontallyScrollable){$sp.SetScrollPercent($xp,$yp)}
  Start-Sleep -Seconds 2
  [void][NativeDesigner]::SetForegroundWindow($p[0].MainWindowHandle)
  [void][NativeDesigner]::GetWindowThreadProcessId([NativeDesigner]::GetForegroundWindow(),[ref]$pidCheck)
  if($pidCheck -ne $p[0].Id){throw 'Foreground changed before segment capture'}
  if(([System.Windows.Automation.ValuePattern]$combo.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)).Current.Value -ne $value){throw 'Selected student flow changed during capture'}
  $gb=$graph.Current.BoundingRectangle
  $nodes=@($graph.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition)|Where-Object{$_.Current.Name -in $expected})
  $visible=@(foreach($e in $nodes){$b=$e.Current.BoundingRectangle;if($b.Width -gt 0 -and $b.Height -gt 0 -and $b.Bottom -gt $gb.Top -and $b.Top -lt $gb.Bottom -and $b.Right -gt $gb.Left -and $b.Left -lt $gb.Right){$e.Current.Name}})
  $fullyVisible=@(foreach($e in $nodes){$b=$e.Current.BoundingRectangle;if($b.Width -gt 0 -and $b.Height -gt 0 -and $b.Top -ge $gb.Top -and $b.Bottom -le $gb.Bottom -and $b.Left -ge $gb.Left -and $b.Right -le $gb.Right){$e.Current.Name}})
  $bounds=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds
  $bmp=New-Object System.Drawing.Bitmap $bounds.Width,$bounds.Height
  $g=[System.Drawing.Graphics]::FromImage($bmp)
  $file=("${prefix}_detail_{0:d2}.png" -f ($records.Count+1))
  try{$g.CopyFromScreen($bounds.Location,[System.Drawing.Point]::Empty,$bounds.Size);$bmp.Save((Join-Path $out $file),[System.Drawing.Imaging.ImageFormat]::Png)}finally{$g.Dispose();$bmp.Dispose()}
  $records+= [pscustomobject]@{Utc=(Get-Date).ToUniversalTime().ToString('o');File=$file;VerticalScrollPercent=$sp.Current.VerticalScrollPercent;HorizontalScrollPercent=$sp.Current.HorizontalScrollPercent;VisibleComponents=$visible;FullyVisibleComponents=$fullyVisible;Sha256=(Get-FileHash (Join-Path $out $file)).Hash}
 }}
 $uncovered=@($expected|Where-Object{$_ -notin @($records|ForEach-Object{$_.FullyVisibleComponents})})
 [pscustomobject]@{Student=$Student;Flow=$Flow;Task=$value;ProcessId=$p[0].Id;VerticalViewSize=$view;HorizontalViewSize=$horizontalView;ExpectedComponents=$expected;ComponentsWithoutFullViewportCoverage=$uncovered;Captures=$records;Status='NATIVE_SEGMENTS_SAVED_VISUAL_REVIEW_REQUIRED'}|ConvertTo-Json -Depth 8|Set-Content (Join-Path $out "$Flow-segments.json")
 (Get-Date).ToUniversalTime().ToString('o')|Set-Content (Join-Path $out "$Flow-segments-status.txt")
}catch{$_.Exception.ToString()|Set-Content "C:\BISM2202\submission\Student_$Student\evidence\gui\$Flow-segments-error.txt";exit 1}
