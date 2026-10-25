param(
 [Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_-]{2,95}$')][string]$Name,
 [string]$Root='H:\BISM2202_Ready_20261025_223139'
)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class RapidCaptureWin32 {
 [StructLayout(LayoutKind.Sequential)]
 public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
 [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int maxCount);
}
'@
if(-not (Test-Path -LiteralPath $Root -PathType Container)){throw ('PROJECT_ROOT_NOT_FOUND: '+$Root)}
$dir=Join-Path $Root 'BISM2202_Manual_Screenshots'
New-Item -ItemType Directory -Path $dir -Force | Out-Null
$targets=@(Get-Process -ErrorAction SilentlyContinue | Where-Object {
 $_.MainWindowHandle -ne [IntPtr]::Zero -and $_.MainWindowTitle -match 'RapidMiner Studio'
} | Sort-Object StartTime -Descending)
if($targets.Count -eq 0){throw 'RAPIDMINER_NOT_OPEN: Open RapidMiner and select the report screen first.'}
if($targets.Count -gt 1){throw 'MULTIPLE_RAPIDMINER_WINDOWS: Close extra RapidMiner instances, then retry.'}
$app=$targets[0]
$handle=$app.MainWindowHandle
if([RapidCaptureWin32]::IsIconic($handle)){[void][RapidCaptureWin32]::ShowWindow($handle,9)}
[void][RapidCaptureWin32]::SetForegroundWindow($handle)
Start-Sleep -Milliseconds 1100
$foreground=[RapidCaptureWin32]::GetForegroundWindow()
if($foreground -ne $handle){
 $title=[System.Text.StringBuilder]::new(400)
 [void][RapidCaptureWin32]::GetWindowText($foreground,$title,400)
 throw ('FOREGROUND_NOT_RAPIDMINER: '+$title.ToString()+'; close any dialogs and retry.')
}
$rect=[RapidCaptureWin32+RECT]::new()
if(-not [RapidCaptureWin32]::GetWindowRect($handle,[ref]$rect)){throw 'WINDOW_BOUNDS_UNAVAILABLE'}
$width=$rect.Right-$rect.Left
$height=$rect.Bottom-$rect.Top
if($width -lt 800 -or $height -lt 500){throw ('WINDOW_TOO_SMALL '+$width+'x'+$height+'; maximize RapidMiner manually.')}
$screen=[System.Windows.Forms.SystemInformation]::VirtualScreen
$left=[Math]::Max($rect.Left,$screen.Left)
$top=[Math]::Max($rect.Top,$screen.Top)
$right=[Math]::Min($rect.Right,$screen.Right)
$bottom=[Math]::Min($rect.Bottom,$screen.Bottom)
$visibleWidth=$right-$left
$visibleHeight=$bottom-$top
if($visibleWidth -lt 800 -or $visibleHeight -lt 500 -or ($visibleWidth/$width) -lt .95 -or ($visibleHeight/$height) -lt .94){
 throw 'WINDOW_CLIPPED: move the whole RapidMiner window onto the visible desktop before retrying.'
}
$width=$visibleWidth
$height=$visibleHeight
$saveTo=Join-Path $dir ($Name+'.png')
if(Test-Path -LiteralPath $saveTo -PathType Leaf){
 $saveTo=Join-Path $dir ($Name+'_'+(Get-Date -Format 'HHmmssfff')+'.png')
}
$bmp=[System.Drawing.Bitmap]::new($width,$height)
$graphics=[System.Drawing.Graphics]::FromImage($bmp)
try {
 $graphics.CopyFromScreen($left,$top,0,0,$bmp.Size)
 $colorSet=[System.Collections.Generic.HashSet[int]]::new()
 foreach($fractionX in @(.08,.24,.50,.76,.92)){
  foreach($fractionY in @(.07,.22,.43,.67,.88)){
   $x=[int](($width-1)*$fractionX)
   $y=[int](($height-1)*$fractionY)
   [void]$colorSet.Add($bmp.GetPixel($x,$y).ToArgb())
  }
 }
 if($colorSet.Count -lt 4){throw 'CAPTURE_LOOKS_BLANK: remote screen may be locked or not rendering.'}
 $graphics.Dispose()
 $graphics=$null
 $bmp.Save($saveTo,[System.Drawing.Imaging.ImageFormat]::Png)
} finally {
 if($graphics){$graphics.Dispose()}
 $bmp.Dispose()
}
$bytes=[System.IO.File]::ReadAllBytes($saveTo)
if($bytes.Length -lt 1000 -or $bytes[0] -ne 137 -or $bytes[1] -ne 80 -or $bytes[2] -ne 78 -or $bytes[3] -ne 71){
 Remove-Item -LiteralPath $saveTo -Force -ErrorAction SilentlyContinue
 throw 'INVALID_PNG_OUTPUT'
}
$sha=(Get-FileHash -LiteralPath $saveTo -Algorithm SHA256).Hash
$other=@(Get-ChildItem -LiteralPath $dir -Filter '*.png' -File | Where-Object {$_.FullName -ne $saveTo})
$duplicates=@($other | Where-Object {(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash -eq $sha})
$log=Join-Path $dir 'capture_manifest.csv'
$entry=[pscustomobject]@{CapturedAt=(Get-Date).ToString('s');File=[IO.Path]::GetFileName($saveTo);Width=$width;Height=$height;SHA256=$sha;WindowTitle=$app.MainWindowTitle;DuplicateCount=$duplicates.Count}
if(Test-Path -LiteralPath $log){$entry | Export-Csv -Path $log -Append -NoTypeInformation -Encoding UTF8}
else{$entry | Export-Csv -Path $log -NoTypeInformation -Encoding UTF8}
Write-Host ('SCREENSHOT_SAVED='+$saveTo) -ForegroundColor Green
Write-Host ('SIZE='+$width+'x'+$height+'  BYTES='+$bytes.Length)
Write-Host ('IMAGE_CONTENT_REQUIRES_REVIEW=YES')
if($duplicates.Count){Write-Warning ('DUPLICATE_OF='+($duplicates.Name -join ','))}
try{[System.Media.SystemSounds]::Asterisk.Play()}catch{}
