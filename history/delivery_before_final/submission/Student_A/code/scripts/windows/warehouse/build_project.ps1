param([ValidateSet('A','B')][string]$Student='A')
$ErrorActionPreference='Stop'
$out="C:\BISM2202\submission\Student_$Student\ssis\STUDENT_${Student}_ID_SSIS"
('RUNNING '+(Get-Date -Format o))|Set-Content -Encoding UTF8 (Join-Path $out 'build_status.txt')
try{
 $vs=$null
 $vswhere='C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
 $installations=@()
 if(Test-Path $vswhere){$installations=@(& $vswhere -all -products '*' -property installationPath)}
 foreach($installation in $installations){
  $candidate=Join-Path $installation 'Common7\IDE\devenv.com'
  if(Test-Path $candidate){$vs=Get-Item $candidate;break}
 }
 if(-not $vs){$vs=Get-ChildItem 'C:\Program Files\Microsoft Visual Studio','C:\Program Files (x86)\Microsoft Visual Studio' -Filter devenv.com -File -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1}
 if(-not $vs){throw 'Existing Visual Studio command-line compiler not found'}
 & $vs.FullName (Join-Path $out "STUDENT_${Student}_ID_SSIS.sln") /Build Development /Out (Join-Path $out 'native_build.log') /Log (Join-Path $out 'native_load_activity.xml')
 $code=$LASTEXITCODE
 if($code -ne 0){throw "Native Visual Studio build failed, exit $code"}
 $ispac=Get-ChildItem (Join-Path $out 'bin') -Filter *.ispac -Recurse -File|Select-Object -First 1
 if(-not $ispac){throw 'Build returned success without an ispac'}
 ('VISUAL_STUDIO_NATIVE_BUILD=PASS'+"`nISPAC="+$ispac.FullName)|Set-Content -Encoding UTF8 (Join-Path $out 'build_status.txt')
}catch{$_|Out-String|Set-Content -Encoding UTF8 (Join-Path $out 'build_status.txt');exit 1}
