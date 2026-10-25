param(
    [string]$ProjectRoot = '',
    [int]$TimeoutMinutes = 12
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$script:events = New-Object 'System.Collections.Generic.List[object]'
$script:logfile = $null
$script:out = $null
$script:workspace = $null
$script:foundFolders = New-Object 'System.Collections.Generic.List[string]'
$script:foundZips = New-Object 'System.Collections.Generic.List[string]'
$script:visited = @{}
$csvName = 'BISM2202_A2_Loan_Data_Set_RapidMiner2026S2.csv'
$csvHash = 'B333ABEF401D01DCE2B0115B65649400238C01D9362B328C8CA1C4C19876D00A'
$zipNames = @('BISM2202_Evidence_20261025_192403.zip', 'BISM2202_RapidMiner_Evidence_20261025_181546.zip', '13(1).zip')

function Log([string]$text) {
    $s = (Get-Date -Format 'HH:mm:ss') + ' ' + $text
    Write-Host $s
    if ($script:logfile) { Add-Content -LiteralPath $script:logfile -Value $s -Encoding UTF8 }
}
function Step([string]$name,[string]$status,[string]$detail) {
    $script:events.Add([pscustomobject]@{ name=$name; status=$status; detail=$detail })
    Log ($name+' | '+$status+' | '+$detail)
}
function AddFolder([string]$path) {
    if ([string]::IsNullOrWhiteSpace($path)) { return }
    if (-not (Test-Path -LiteralPath $path -PathType Container)) { return }
    try {
        $resolved = (Resolve-Path -LiteralPath $path).Path
        $key = $resolved.ToLowerInvariant()
        if (-not $script:visited.ContainsKey($key)) {
            $script:visited[$key] = $true
            $script:foundFolders.Add($resolved)
        }
    } catch {}
}
function Discover {
    if ($ProjectRoot) { AddFolder $ProjectRoot }
    AddFolder (Get-Location).Path
    AddFolder 'H:\'
    AddFolder 'H:\12'
    AddFolder 'D:\'
    AddFolder $env:OneDrive
    AddFolder $env:OneDriveCommercial
    AddFolder (Join-Path $env:USERPROFILE 'Downloads')
    AddFolder (Join-Path $env:USERPROFILE 'Documents')
    AddFolder (Join-Path $env:USERPROFILE 'Desktop')
    # Bounded enumeration: at most three directory levels, no full-drive recursion.
    $index = 0
    $limit = 1500
    while ($index -lt $script:foundFolders.Count -and $index -lt $limit) {
        $dir = $script:foundFolders[$index]
        $index++
        foreach ($name in $zipNames) {
            $file = Join-Path $dir $name
            if (Test-Path -LiteralPath $file -PathType Leaf) {
                if (-not $script:foundZips.Contains($file)) { $script:foundZips.Add($file) }
            }
        }
        # Traversal is limited to BISM folders, numbered folders like H:\12, and OneDrive project roots.
        $relativeDepth = ($dir -split '[\\/]').Count
        if ($relativeDepth -gt 10) { continue }
        $children = @(Get-ChildItem -LiteralPath $dir -Directory -ErrorAction SilentlyContinue)
        foreach ($child in $children) {
            if ($child.Name -match '^(BISM2202|\d{1,4}$|rapidminer$|evidence$|run_20261025|ready_rmp$|data$|13$)' -or ($dir -match '^H:\\\d{1,4}$' -and $script:foundFolders.Count -lt 500)) {
                AddFolder $child.FullName
            }
        }
    }
    Log ('FOLDERS_CHECKED='+$script:foundFolders.Count+' ZIPS_FOUND='+$script:foundZips.Count)
}
function FindTeacherAndPrograms {
    $found = @{csv=$null;GBT=$null;NB=$null;source=$null}
    foreach ($dir in $script:foundFolders) {
        foreach ($relative in @(
            ('rapidminer\data\'+$csvName),
            ('data\'+$csvName),
            ('ready_rmp\data\'+$csvName),
            $csvName
        )) {
            $file=Join-Path $dir $relative
            if (-not $found.csv -and (Test-Path -LiteralPath $file -PathType Leaf)) { $found.csv=$file }
        }
        foreach ($name in @('GBT','NB')) {
            if ($found[$name]) { continue }
            foreach ($relative in @(
                ($name+'_AutoEvidence.rmp'),
                ('evidence\rapidminer\run_20261025_192403\'+$name+'_AutoEvidence.rmp')
            )) {
                $file=Join-Path $dir $relative
                if (Test-Path -LiteralPath $file -PathType Leaf) { $found[$name]=$file;break }
            }
        }
        if ($found.csv -and $found.GBT -and $found.NB) { break }
    }
    # ZIP fallback supports earlier evidence archives as well as imported project archives.
    if (-not ($found.csv -and $found.GBT -and $found.NB)) {
        $count=0
        foreach ($zip in $script:foundZips) {
            if ($count -ge 5) { break }
            $count++
            $dir=Join-Path $script:workspace ('archive_'+$count)
            try {
                Expand-Archive -LiteralPath $zip -DestinationPath $dir -ErrorAction Stop
                Step 'archive' 'EXTRACTED' $zip
            } catch {
                Step 'archive' 'FAILED' ($zip+' '+$_.Exception.Message)
                continue
            }
            if (-not $found.csv) {
                $data=@(Get-ChildItem -LiteralPath $dir -Recurse -File -Filter $csvName -ErrorAction SilentlyContinue | Select-Object -First 1)
                if ($data.Count -gt 0) { $found.csv=$data[0].FullName }
            }
            foreach ($name in @('GBT','NB')) {
                if ($found[$name]) { continue }
                $rmp=@(Get-ChildItem -LiteralPath $dir -Recurse -File -Filter ($name+'_AutoEvidence.rmp') -ErrorAction SilentlyContinue | Select-Object -First 1)
                if ($rmp.Count -gt 0) { $found[$name]=$rmp[0].FullName }
            }
            if ($found.csv -and $found.GBT -and $found.NB) { break }
        }
    }
    return $found
}
function LocateBatch {
    foreach ($path in @(
      'C:\Program Files\RapidMiner\RapidMiner Studio\scripts\rapidminer-batch.bat',
      'C:\Program Files\RapidMiner\RapidMiner Studio 10.3\scripts\rapidminer-batch.bat',
      'C:\Program Files\Altair\RapidMiner Studio\scripts\rapidminer-batch.bat'
    )) { if (Test-Path -LiteralPath $path -PathType Leaf) { return $path } }
    return $null
}
function LogTail([string]$file) {
    if (Test-Path -LiteralPath $file) {
        foreach($line in @(Get-Content -LiteralPath $file -Tail 15 -ErrorAction SilentlyContinue)) { Log ('   '+$line) }
    }
}
function AddConnection([xml]$doc,[System.Xml.XmlNode]$body,[string]$src,[string]$srcPort,[string]$dest,[string]$destPort) {
    $edge=$doc.CreateElement('connect')
    $edge.SetAttribute('from_op',$src)
    $edge.SetAttribute('from_port',$srcPort)
    if($dest){$edge.SetAttribute('to_op',$dest)}
    $edge.SetAttribute('to_port',$destPort)
    [void]$body.AppendChild($edge)
}
function SaveRmpUTF8([xml]$doc,[string]$path) {
    $settings=New-Object System.Xml.XmlWriterSettings
    $settings.Encoding=[System.Text.UTF8Encoding]::new($false)
    $settings.Indent=$true
    $settings.CloseOutput=$true
    $writer=[System.Xml.XmlWriter]::Create($path,$settings)
    try{$doc.Save($writer)}finally{$writer.Dispose()}
    $bytes=[IO.File]::ReadAllBytes($path)
    if($bytes.Length -lt 5 -or $bytes[0] -ne 60 -or $bytes[1] -ne 63 -or $bytes[2] -ne 120 -or $bytes[3] -ne 109 -or $bytes[4] -ne 108) {
        throw ('INVALID_RMP_PROLOG '+$path)
    }
}
function ProbeNativeCSV([string]$source,[string]$batch) {
    [xml]$doc=Get-Content -LiteralPath $source -Raw -Encoding UTF8
    $body=$doc.SelectSingleNode('/process/operator/process')
    if(-not $body){throw 'PROBE_NO_MAIN_PROCESS'}
    $reads=@($body.SelectNodes('./operator[@class="read_csv"]'))
    $writers=@($body.SelectNodes('./operator[@class="write_csv"]'))
    if($reads.Count -lt 1 -or $writers.Count -lt 1){throw 'PROBE_MISSING_READ_OR_WRITE_OPERATOR'}
    $read=$reads[0];$writer=$writers[0]
    $teacher=Join-Path $script:workspace 'teacher.csv'
    $csv=Join-Path $script:workspace 'PROBE_WriteCSV.csv'
    foreach($op in @($read,$writer)) {
        $param=$op.SelectSingleNode('./parameter[@key="csv_file"]')
        if(-not $param){throw ('PROBE_CSV_PARAMETER_MISSING_'+$op.GetAttribute('name'))}
        $param.SetAttribute('value', $(if($op -eq $read){$teacher}else{$csv}))
    }
    foreach($op in @($body.SelectNodes('./operator'))) {
        if(-not [object]::ReferenceEquals($op,$read) -and -not [object]::ReferenceEquals($op,$writer)){[void]$body.RemoveChild($op)}
    }
    foreach($wire in @($body.SelectNodes('./connect'))){[void]$body.RemoveChild($wire)}
    AddConnection $doc $body $read.GetAttribute('name') 'output' $writer.GetAttribute('name') 'input'
    AddConnection $doc $body $writer.GetAttribute('name') 'through' '' 'result 1'
    $probe=Join-Path $script:workspace 'PROBE_WriteCSV.rmp'
    SaveRmpUTF8 $doc $probe
    $cmd=Join-Path $script:workspace 'run_probe.cmd'
    $crlf=[string][char]13+[string][char]10
    $text='@echo off'+$crlf+'call "'+$batch+'" -f "'+$probe+'"'+$crlf+'exit /b %ERRORLEVEL%'+$crlf
    [IO.File]::WriteAllText($cmd,$text,[Text.ASCIIEncoding]::new())
    $log=Join-Path $script:out 'PROBE_Batch.log'
    $err=Join-Path $script:out 'PROBE_Batch.err'
    $proc=Start-Process -FilePath 'cmd.exe' -ArgumentList @('/d','/c',('"'+$cmd+'"')) -PassThru -RedirectStandardOutput $log -RedirectStandardError $err -WindowStyle Hidden
    $limit=(Get-Date).AddMinutes(2)
    while(-not $proc.HasExited -and (Get-Date) -lt $limit){Start-Sleep -Seconds 2;$proc.Refresh()}
    if(-not $proc.HasExited){try{& taskkill.exe /PID $proc.Id /T /F *> $null}catch{};throw 'PROBE_TIMEOUT'}
    $proc.Refresh()
    if(-not (Test-Path -LiteralPath $csv -PathType Leaf) -or (Get-Item -LiteralPath $csv -ErrorAction SilentlyContinue).Length -lt 200) {
        Step 'probe' 'FAILED' ('CSV was not created; exit='+$proc.ExitCode)
        LogTail $err
        throw 'PROBE_WRITECSV_FAILED: inspect PROBE_Batch.err and PROBE_Batch.log'
    }
    Copy-Item -LiteralPath $csv -Destination (Join-Path $script:out 'PROBE_WriteCSV.csv')
    Step 'probe' 'CSV_PASS' 'Read CSV > Write CSV > result 1; native file exists'
}

function RunOne([string]$name,[string]$source,[string]$bat) {
    if (-not $source) { Step $name 'BLOCKED' 'EVIDENCE_RMP_MISSING'; return $false }
    $working=Join-Path $script:workspace ($name+'_Native.rmp')
    [xml]$doc = Get-Content -LiteralPath $source -Raw -Encoding UTF8
    $macros = @{
        source_csv=(Join-Path $script:workspace 'teacher.csv');
        cv_results_path=(Join-Path $script:workspace ($name+'_CV_Metrics.csv'));
        holdout_results_path=(Join-Path $script:workspace ($name+'_Holdout_Metrics.csv'));
        holdout_predictions_path=(Join-Path $script:workspace ($name+'_Holdout_Predictions.csv'))
    }
    foreach($key in $macros.Keys) {
        $node=$doc.SelectSingleNode('/process/context/macros/macro[key="'+$key+'"]')
        if (-not $node) { Step $name 'BLOCKED' ('MACRO_MISSING_'+$key); return $false }
        $node.SelectSingleNode('./value').InnerText=$macros[$key]
    }
    # Use explicit output paths and make all exports part of process output chain.
    $body=$doc.SelectSingleNode('/process/operator/process')
    foreach($pair in @(
        @{operator='Save CV Metrics';macro='cv_results_path';result='result 1'},
        @{operator='Save Holdout Metrics';macro='holdout_results_path';result='result 2'},
        @{operator='Save Holdout Predictions';macro='holdout_predictions_path';result='result 3'}
    )) {
        $items=@($body.SelectNodes('./operator[@name="'+$pair.operator+'"]'))
        if($items.Count -ne 1){throw ('EXPORT_WRITER_MISSING_'+$pair.operator)}
        $fileParam=$items[0].SelectSingleNode('./parameter[@key="csv_file"]')
        if(-not $fileParam){throw ('EXPORT_PATH_PARAM_MISSING_'+$pair.operator)}
        $fileParam.SetAttribute('value',$macros[$pair.macro])
        $existing=@($body.SelectNodes('./connect[@to_port="'+$pair.result+'"]') |
            Where-Object {-not $_.HasAttribute('to_op')})
        foreach($connection in $existing){[void]$body.RemoveChild($connection)}
        AddConnection $doc $body $pair.operator 'through' '' $pair.result
    }
    Step $name 'EXPORT_WIRING_READY' '3 Write CSV through ports attached to Process results'
    # The original teacher RMPs are BOM-free UTF-8. XmlDocument.Save(path)
    # writes EF BB BF on Windows PowerShell/.NET Framework, and RapidMiner 10.3
    # Java batch fails at SAX parser line 1 column 1 with that BOM.
    # Write using an explicit UTF8Encoding(false), then verify the actual bytes.
    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Encoding = [System.Text.UTF8Encoding]::new($false)
    $settings.Indent = $true
    $settings.CloseOutput = $true
    $writer = [System.Xml.XmlWriter]::Create($working, $settings)
    try { $doc.Save($writer) } finally { $writer.Dispose() }
    $bytes = [IO.File]::ReadAllBytes($working)
    if ($bytes.Length -lt 5) { throw ('RMP_EMPTY_OR_TRUNCATED_' + $name) }
    if ($bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) {
        throw ('RMP_UTF8_BOM_NOT_REMOVED_' + $name)
    }
    if ($bytes[0] -ne 60 -or $bytes[1] -ne 63 -or $bytes[2] -ne 120 -or $bytes[3] -ne 109 -or $bytes[4] -ne 108) {
        throw ('RMP_INVALID_XML_PROLOG_' + $name)
    }
    [xml]$nativeProbe = Get-Content -LiteralPath $working -Raw -Encoding UTF8
    if ($null -eq $nativeProbe.DocumentElement -or $nativeProbe.DocumentElement.Name -ne 'process') {
        throw ('RMP_XML_STRUCTURE_ERROR_' + $name)
    }
    Step $name 'XML_ENCODING_PASS' 'UTF8_WITHOUT_BOM; starts with 3C 3F 78 6D 6C'
    # Verify the actual four filesystem paths instead of rejecting harmless Unicode in model text.
    foreach($key in $macros.Keys) {
        if($macros[$key] -match '[^\x20-\x7e]') { throw ('NON_ASCII_RUNTIME_PATH_'+$key) }
    }
    Copy-Item -LiteralPath $working -Destination (Join-Path $script:out ($name+'_Native.rmp'))
    Step $name 'PROCESS_PREPARED' (Join-Path $script:out ($name+'_Native.rmp'))
    $cmdFile=Join-Path $script:workspace ('run_'+$name+'.cmd')
    $line='@echo off' + "`r`n" + 'call "'+$bat+'" -f "'+$working+'"' + "`r`n" + 'exit /b %ERRORLEVEL%' + "`r`n"
    [IO.File]::WriteAllText($cmdFile,$line,(New-Object Text.ASCIIEncoding))
    $stdout=Join-Path $script:out ($name+'_NativeBatch.log')
    $stderr=Join-Path $script:out ($name+'_NativeBatch.err')
    $proc=Start-Process -FilePath 'cmd.exe' -ArgumentList @('/d','/c',('"'+$cmdFile+'"')) -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr -WindowStyle Hidden
    $deadline=(Get-Date).AddMinutes($TimeoutMinutes)
    $last=Get-Date
    while (-not $proc.HasExited -and (Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 5
        $proc.Refresh()
        if (((Get-Date)-$last).TotalSeconds -ge 30) {
            Log ($name+' RUNNING PID='+$proc.Id)
            $last=Get-Date
        }
    }
    if (-not $proc.HasExited) {
        try { & taskkill.exe /PID $proc.Id /T /F *> $null } catch { try { $proc.Kill() } catch {} }
        Step $name 'TIMEOUT' 'RapidMiner Batch did not finish'
        LogTail $stderr
        return $false
    }
    $outputNames=@($name+'_CV_Metrics.csv',$name+'_Holdout_Metrics.csv',$name+'_Holdout_Predictions.csv')
    $missing=@()
    foreach($file in $outputNames) {
        $src=Join-Path $script:workspace $file
        if (-not (Test-Path -LiteralPath $src -PathType Leaf) -or (Get-Item -LiteralPath $src -ErrorAction SilentlyContinue).Length -le 12) { $missing+=$file }
        else { Copy-Item -LiteralPath $src -Destination (Join-Path $script:out $file) }
    }
    if ($missing.Count -eq 0 -and $proc.ExitCode -eq 0) {
        Step $name 'NATIVE_CSV_PASS' 'All 3 CSV outputs exist; batch exit 0'
        return $true
    }
    Step $name 'FAILED' ('ExitCode='+$proc.ExitCode+' Missing='+($missing -join ',')+' WORKSPACE='+$script:workspace)
    LogTail $stderr
    return $false
}

$complete=$false
try {
    if([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'WINDOWS_ONLY' }
    $workParent = $env:TEMP
    if ($workParent -match '[^\x20-\x7e]') { $workParent='C:\Windows\Temp' }
    if($workParent -match '[^\x20-\x7e]') { throw 'ASCII_TEMP_UNAVAILABLE' }
    $script:workspace = Join-Path $workParent ('BISM2202_NATIVE_'+$stamp)
    New-Item -ItemType Directory -Path $script:workspace -Force | Out-Null
    Discover
    $assets=FindTeacherAndPrograms
    # Do not derive a project root by repeatedly calling Split-Path: a shallow
    # teacher CSV such as H:\12\teacher.csv eventually yields an empty string.
    Log ('DISCOVERY_ASSETS csv=' + [string]$assets.csv + ' GBT=' + [string]$assets.GBT + ' NB=' + [string]$assets.NB)
    $saveRoot = ''
    if (-not [string]::IsNullOrWhiteSpace($ProjectRoot) -and (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
        $saveRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
    }
    if ([string]::IsNullOrWhiteSpace($saveRoot) -and $script:foundZips.Count -gt 0) {
        foreach ($archive in $script:foundZips) {
            if ([string]::IsNullOrWhiteSpace($archive)) { continue }
            $candidate = Split-Path -Parent $archive
            if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate -PathType Container)) {
                $saveRoot = $candidate
                break
            }
        }
    }
    if ([string]::IsNullOrWhiteSpace($saveRoot) -and $assets.csv -and $assets.csv -notlike ($script:workspace+'*')) {
        $candidate = Split-Path -Parent ([string]$assets.csv)
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate -PathType Container)) {
            $saveRoot = $candidate
        }
    }
    if ([string]::IsNullOrWhiteSpace($saveRoot)) {
        $candidate = Join-Path $env:USERPROFILE 'Documents'
        if (Test-Path -LiteralPath $candidate -PathType Container) { $saveRoot = $candidate }
        else { $saveRoot = $script:workspace }
    }
    Log ('SAVE_ROOT=' + $saveRoot)
    if ([string]::IsNullOrWhiteSpace($saveRoot)) { throw 'OUTPUT_ROOT_EMPTY' }
    $script:out=Join-Path -Path $saveRoot -ChildPath ('BISM2202_NativeASCII_'+$stamp)
    try { New-Item -ItemType Directory -Path $script:out -Force | Out-Null }
    catch { $script:out=Join-Path $env:TEMP ('BISM2202_NativeASCII_'+$stamp); New-Item -ItemType Directory -Path $script:out -Force | Out-Null }
    $script:logfile=Join-Path $script:out 'execution.log'
    Step 'discovery' 'COMPLETE' ('OUTPUT='+$script:out)
    if (-not $assets.csv) { throw 'TEACHER_CSV_NOT_FOUND_IN_FOLDERS_OR_AVAILABLE_ZIPS' }
    if (-not $assets.GBT -or -not $assets.NB) { throw 'AUTOEVIDENCE_RMP_NOT_FOUND_IN_FOLDERS_OR_AVAILABLE_ZIPS' }
    Step 'assets' 'READY' ('csv='+[string]$assets.csv+' GBT='+[string]$assets.GBT+' NB='+[string]$assets.NB)
    $hash=(Get-FileHash -LiteralPath $assets.csv -Algorithm SHA256).Hash
    if($hash -ne $csvHash) { throw ('TEACHER_CSV_HASH_MISMATCH actual='+$hash) }
    Copy-Item -LiteralPath $assets.csv -Destination (Join-Path $script:workspace 'teacher.csv')
    Step 'teacher' 'PASS' 'Original data SHA256 confirmed'
    $bat=LocateBatch
    if(-not $bat) { throw 'RAPIDMINER_BATCH_NOT_INSTALLED_OR_NOT_FOUND' }
    Step 'batch' 'FOUND' $bat
    ProbeNativeCSV $assets.NB $bat
    $okGBT=RunOne 'GBT' $assets.GBT $bat
    $okNB=RunOne 'NB' $assets.NB $bat
    $complete=($okGBT -and $okNB)
} catch {
    $details = $_.Exception.Message
    if ($_.InvocationInfo) {
        $details += ' | SCRIPT_LINE=' + $_.InvocationInfo.ScriptLineNumber
        if ($_.InvocationInfo.Line) { $details += ' | COMMAND=' + $_.InvocationInfo.Line.Trim() }
    }
    if ($_.ScriptStackTrace) { $details += ' | STACK=' + ($_.ScriptStackTrace -replace '[\r\n]+',' ; ') }
    Step 'fatal' 'FAILED' $details
} finally {
    if ($script:out -and (Test-Path -LiteralPath $script:out)) {
        $manifest=[ordered]@{result= $(if($complete){'NATIVE_CSV_PASS'}else{'PARTIAL_OR_FAILED'});events=($script:events.ToArray());output=$script:out;workspace=$script:workspace}
        $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $script:out 'manifest.json') -Encoding UTF8
        $zip=$script:out+'.zip'
        try { Compress-Archive -Path (Join-Path $script:out '*') -DestinationPath $zip -CompressionLevel Optimal -Force;Log ('LOCAL_ZIP='+$zip) } catch { Log ('ZIP_FAILED='+$_.Exception.Message) }
        Log ('RESULTS_DIR='+$script:out)
    }
}
if($complete){Write-Host 'NATIVE_CSV_PASS' -ForegroundColor Green;exit 0}
Write-Host 'PARTIAL_OR_FAILED: inspect execution.log and NativeBatch.err in results folder' -ForegroundColor Yellow
exit 2