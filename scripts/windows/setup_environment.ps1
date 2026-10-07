param()
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Root = 'C:\BISM2202'
$LogDir = Join-Path $Root 'logs'
New-Item -ItemType Directory -Force $Root,$LogDir | Out-Null
$Log = Join-Path $LogDir ('setup-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')

function Is-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Is-Admin)) {
    Write-Host 'ERROR: Open PowerShell with Run as administrator, then run this script again.' -ForegroundColor Red
    exit 2
}

Start-Transcript -Path $Log -Force | Out-Null
$Results = [ordered]@{}
$RebootNeeded = $false

function Mark([string]$Name,[string]$State) {
    $script:Results[$Name] = $State
    Write-Host ('[' + $State + '] ' + $Name)
}

function Stage([string]$Name) {
    Write-Host ''
    Write-Host ('=' * 70)
    Write-Host $Name
    Write-Host ('=' * 70)
}

function Download([string]$Url,[string]$Path) {
    if ((Test-Path $Path) -and ((Get-Item $Path).Length -ge 102400)) {
        Write-Host ('Using existing file: ' + $Path)
        return
    }

    if (Test-Path $Path) { Remove-Item $Path -Force }
    $part = $Path + '.part'
    if (Test-Path $part) { Remove-Item $part -Force }

    Write-Host ('Downloading: ' + $Url)

    for ($i=1; $i -le 3; $i++) {
        try {
            if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
                & curl.exe -L --fail --retry 3 --retry-delay 2 --connect-timeout 20 --output $part $Url
                if ($LASTEXITCODE -ne 0) {
                    throw ('curl.exe failed with exit code ' + $LASTEXITCODE)
                }
            } else {
                Invoke-WebRequest -Uri $Url -OutFile $part -UseBasicParsing -MaximumRedirection 10
            }

            if ((Test-Path $part) -and ((Get-Item $part).Length -ge 102400)) {
                Move-Item $part $Path -Force
                return
            }

            throw 'Downloaded file is missing or unexpectedly small.'
        } catch {
            Write-Warning ('Attempt ' + $i + ' failed: ' + $_.Exception.Message)
            if (Test-Path $part) { Remove-Item $part -Force }
            Start-Sleep -Seconds (3*$i)
        }
    }

    throw ('Download failed: ' + $Url)
}

function Sql-Table([string]$Db,[string]$Sql) {
    $cs = 'Server=.;Database=' + $Db + ';Integrated Security=True;Encrypt=False;TrustServerCertificate=True;'
    $c = New-Object System.Data.SqlClient.SqlConnection $cs
    $c.Open()
    try {
        $cmd = $c.CreateCommand(); $cmd.CommandTimeout = 0; $cmd.CommandText = $Sql
        $da = New-Object System.Data.SqlClient.SqlDataAdapter $cmd
        $dt = New-Object System.Data.DataTable
        [void]$da.Fill($dt)
        Write-Output -NoEnumerate $dt
        return
    } finally { $c.Close() }
}

function Sql-Exec([string]$Db,[string]$Sql) {
    $cs = 'Server=.;Database=' + $Db + ';Integrated Security=True;Encrypt=False;TrustServerCertificate=True;'
    $c = New-Object System.Data.SqlClient.SqlConnection $cs
    $c.Open()
    try {
        $cmd = $c.CreateCommand(); $cmd.CommandTimeout = 0; $cmd.CommandText = $Sql
        [void]$cmd.ExecuteNonQuery()
    } finally { $c.Close() }
}

function Wait-Sql([int]$Seconds=180) {
    $end = (Get-Date).AddSeconds($Seconds)
    do {
        $c = $null
        try {
            $cs = 'Server=.;Database=master;Integrated Security=True;Encrypt=False;TrustServerCertificate=True;Connection Timeout=5;'
            $c = New-Object System.Data.SqlClient.SqlConnection $cs
            $c.Open()
            return $true
        } catch {
            Start-Sleep -Seconds 3
        } finally {
            if ($c) { try { $c.Close() } catch {} }
        }
    } while ((Get-Date) -lt $end)
    return $false
}

function Latest-SSIS {
    $body = @{
        filters = @(@{
            criteria = @(@{ filterType = 7; value = 'SSIS.MicrosoftDataToolsIntegrationServices' })
            pageNumber = 1; pageSize = 1; sortBy = 0; sortOrder = 0
        })
        assetTypes = @('Microsoft.VisualStudio.Services.VSIXPackage')
        flags = 914
    } | ConvertTo-Json -Depth 8
    $r = Invoke-RestMethod -Method Post -Uri 'https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery' -Headers @{Accept='application/json;api-version=3.0-preview.1'} -ContentType 'application/json' -Body $body
    $v = $r.results[0].extensions[0].versions | Select-Object -First 1
    $f = $v.files | Where-Object { $_.assetType -eq 'Microsoft.VisualStudio.Services.VSIXPackage' } | Select-Object -First 1
    if (-not $f.source) { throw 'Could not resolve current SSIS package from Visual Studio Marketplace.' }
    return [pscustomobject]@{ Version=$v.version; Url=$f.source }
}

try {
    Stage '0. PRECHECK'
    $os = Get-CimInstance Win32_OperatingSystem
    Write-Host ('OS: ' + $os.Caption + ' ' + $os.Version)
    Write-Host ('Architecture: ' + $env:PROCESSOR_ARCHITECTURE)
    if ($env:PROCESSOR_ARCHITECTURE -ne 'AMD64') { throw 'This setup requires x64 Windows.' }
    $null = Invoke-WebRequest -Uri 'https://www.microsoft.com' -UseBasicParsing -TimeoutSec 20
    Mark 'Internet access' 'PASS'

    Stage '1. TEACHER MATERIALS'
    $zip = Join-Path $Root 'BISM2202_SSIS.zip'
    $teacher = Join-Path $Root 'teacher'
    Download 'https://raw.githubusercontent.com/lxxlx2/bism2202-a2-datawarehouse-rapidminer/main/requirements/original/BISM2202_2026S2_Assignment2_SSIS_Package.zip' $zip
    if (-not (Test-Path $teacher)) { Expand-Archive -Path $zip -DestinationPath $teacher -Force }
    $srcBak = Get-ChildItem $teacher -Recurse -File | Where-Object { $_.Name -eq 'ozmart_db_bism2202' -or $_.Name -eq 'ozmart_db_bism2202.bak' } | Select-Object -First 1
    if (-not $srcBak) { throw 'Teacher backup not found.' }
    $bak = Join-Path $Root 'ozmart_db_bism2202.bak'
    Copy-Item $srcBak.FullName $bak -Force
    Mark 'Teacher materials' 'PASS'

    Stage '2. SQL SERVER 2022 DEVELOPER + SSIS RUNTIME'
    if (-not (Get-Service MSSQLSERVER -ErrorAction SilentlyContinue)) {
        $iso = Join-Path $Root 'SQLServer2022-x64-ENU-Dev.iso'
        Download 'https://download.microsoft.com/download/3/8/d/38de7036-2433-4207-8eae-06e247e17b25/SQLServer2022-x64-ENU-Dev.iso' $iso
        $img = Mount-DiskImage -ImagePath $iso -PassThru
        Start-Sleep 3
        $vol = $img | Get-Volume
        $setup = $vol.DriveLetter + ':\setup.exe'
        if (-not (Test-Path $setup)) { throw 'SQL Server setup.exe not found.' }
        $admin = $env:COMPUTERNAME + '\' + $env:USERNAME
        $args = @(
            '/Q','/ACTION=Install','/FEATURES=SQLEngine,IS','/INSTANCENAME=MSSQLSERVER',
            '/SQLSVCACCOUNT="NT Service\MSSQLSERVER"','/SQLSVCSTARTUPTYPE=Automatic',
            ('/SQLSYSADMINACCOUNTS="' + $admin + '"'),
            '/ISSVCACCOUNT="NT AUTHORITY\NETWORK SERVICE"','/ISSVCSTARTUPTYPE=Automatic',
            '/TCPENABLED=1','/IACCEPTSQLSERVERLICENSETERMS','/SUPPRESSPRIVACYSTATEMENTNOTICE','/UpdateEnabled=False'
        )
        $p = Start-Process -FilePath $setup -ArgumentList $args -Wait -PassThru
        Dismount-DiskImage -ImagePath $iso -ErrorAction SilentlyContinue
        Write-Host ('SQL setup exit code: ' + $p.ExitCode)
        if ($p.ExitCode -eq 3010) { $RebootNeeded = $true }
        elseif ($p.ExitCode -ne 0) { throw ('SQL Server setup failed. Exit code ' + $p.ExitCode) }
    }
    if ((Get-Service MSSQLSERVER).Status -ne 'Running') { Start-Service MSSQLSERVER }
    if (-not (Wait-Sql)) { throw 'SQL Server service exists but local SQL connection failed.' }
    $ver = Sql-Table 'master' 'SELECT @@VERSION AS v;'
    Write-Host $ver.Rows[0].v
    if ($ver.Rows[0].v -notmatch 'SQL Server 2022') { throw 'Expected SQL Server 2022.' }
    Mark 'SQL Server 2022 service' 'PASS'
    Mark 'SELECT @@VERSION' 'PASS'

    Stage '3. RESTORE OZMart'
    $fl = Sql-Table 'master' ("RESTORE FILELISTONLY FROM DISK = N'" + $bak + "';")
    $mf = Sql-Table 'master' "SELECT type_desc,physical_name FROM sys.master_files WHERE database_id=DB_ID(N'master');"
    $dataDir = Split-Path -Parent (($mf | Where-Object {$_.type_desc -eq 'ROWS'} | Select-Object -First 1).physical_name)
    $logDirSql = Split-Path -Parent (($mf | Where-Object {$_.type_desc -eq 'LOG'} | Select-Object -First 1).physical_name)
    $moves = @()
    foreach ($row in $fl.Rows) {
        $logical = [string]$row.LogicalName
        $safe = $logical -replace '[^\w\-]','_'
        $ext = [IO.Path]::GetExtension([string]$row.PhysicalName)
        if ([string]::IsNullOrWhiteSpace($ext)) { if ($row.Type -eq 'L') {$ext='.ldf'} else {$ext='.mdf'} }
        if ($row.Type -eq 'L') {$target=Join-Path $logDirSql ($safe+$ext)} else {$target=Join-Path $dataDir ($safe+$ext)}
        $moves += "MOVE N'$logical' TO N'$target'"
    }
    $sql = "IF DB_ID(N'ozmart_db') IS NOT NULL BEGIN ALTER DATABASE [ozmart_db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; END;" + [Environment]::NewLine
    $sql += "RESTORE DATABASE [ozmart_db] FROM DISK = N'$bak' WITH REPLACE,RECOVERY,STATS=10," + [Environment]::NewLine
    $sql += ($moves -join (',' + [Environment]::NewLine)) + ';' + [Environment]::NewLine
    $sql += 'ALTER DATABASE [ozmart_db] SET MULTI_USER;'
    Sql-Exec 'master' $sql
    $st = Sql-Table 'master' "SELECT name,state_desc FROM sys.databases WHERE name=N'ozmart_db';"
    $tables = Sql-Table 'ozmart_db' "SELECT TABLE_SCHEMA,TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' ORDER BY TABLE_NAME;"
    $st | Format-Table
    $tables | Format-Table
    if ($st.Rows.Count -ne 1 -or $st.Rows[0].state_desc -ne 'ONLINE') { throw 'ozmart_db not ONLINE.' }
    if ($tables.Rows.Count -lt 1) { throw 'No source tables found after restore.' }
    Mark 'ozmart_db restore' 'PASS'
    Mark 'Source tables query' 'PASS'

    Stage '4. SSMS'
    $ssms = Join-Path $Root 'vs_SSMS.exe'
    Download 'https://aka.ms/ssmsfullsetup' $ssms
    $p = Start-Process $ssms -ArgumentList @('--quiet','--wait','--norestart') -Wait -PassThru
    if ($p.ExitCode -eq 3010) {$RebootNeeded=$true} elseif ($p.ExitCode -ne 0) {throw ('SSMS install failed: '+$p.ExitCode)}
    Mark 'SSMS installer' 'PASS'

    Stage '5. VISUAL STUDIO 2022 COMMUNITY'
    $vs = Join-Path $Root 'vs_Community.exe'
    Download 'https://aka.ms/vs/17/release/vs_community.exe' $vs
    $vsPath = 'C:\Program Files\Microsoft Visual Studio\2022\Community'
    $devenv = Join-Path $vsPath 'Common7\IDE\devenv.exe'
    if (-not (Test-Path $devenv)) {
        $p = Start-Process $vs -ArgumentList @('--installPath',$vsPath,'--add','Microsoft.VisualStudio.Workload.Data','--includeRecommended','--quiet','--wait','--norestart') -Wait -PassThru
        if ($p.ExitCode -eq 3010) {$RebootNeeded=$true} elseif ($p.ExitCode -ne 0) {throw ('VS install failed: '+$p.ExitCode)}
    }
    if (-not (Test-Path $devenv)) { throw 'Visual Studio devenv.exe not found.' }
    Mark 'Visual Studio 2022' 'PASS'

    Stage '6. CURRENT SSIS PROJECTS EXTENSION'
    $ssis = Latest-SSIS
    Write-Host ('Marketplace SSIS version: ' + $ssis.Version)
    $pkg = Join-Path $Root ('SSIS-' + $ssis.Version + '.pkg')
    Download $ssis.Url $pkg
    $fs = [IO.File]::OpenRead($pkg)
    try {$b1=$fs.ReadByte();$b2=$fs.ReadByte()} finally {$fs.Close()}
    if ($b1 -eq 0x4D -and $b2 -eq 0x5A) {
        $exe = [IO.Path]::ChangeExtension($pkg,'.exe'); Move-Item $pkg $exe -Force
        $p = Start-Process $exe -ArgumentList @('/quiet','/norestart') -Wait -PassThru
        if ($p.ExitCode -eq 3010) {$RebootNeeded=$true} elseif ($p.ExitCode -ne 0) {throw ('SSIS installer failed: '+$p.ExitCode)}
    } elseif ($b1 -eq 0x50 -and $b2 -eq 0x4B) {
        $vsix = [IO.Path]::ChangeExtension($pkg,'.vsix'); Move-Item $pkg $vsix -Force
        $vi = Join-Path $vsPath 'Common7\IDE\VSIXInstaller.exe'
        if (-not (Test-Path $vi)) {throw 'VSIXInstaller.exe not found.'}
        $p = Start-Process $vi -ArgumentList @('/quiet',$vsix) -Wait -PassThru
        if ($p.ExitCode -notin @(0,1001)) {throw ('SSIS VSIX install failed: '+$p.ExitCode)}
    } else { throw 'Unknown SSIS package format.' }
    Mark 'SSIS Projects package install' 'PASS'

    Stage '7. RESULT'
    $out = Join-Path $Root 'environment-result.txt'
    $lines = @('BISM2202 environment setup','Generated: '+(Get-Date -Format o),'')
    foreach ($k in $Results.Keys) {$lines += ($k + ' = ' + $Results[$k])}
    $lines += ''
    $lines += ('RebootNeeded = ' + $RebootNeeded)
    $lines += ''
    $lines += 'Manual validation still required:'
    $lines += '1. SSMS connect localhost with Windows Authentication.'
    $lines += '2. Visual Studio: confirm Integration Services Project template.'
    $lines += '3. Run a real SSIS Data Flow against ozmart_db and verify green success plus row counts.'
    $lines += '4. On macOS: run AI Studio classification smoke test and save/reopen .rmp.'
    Set-Content $out $lines -Encoding UTF8
    Write-Host ('DONE. Result: ' + $out)
    Write-Host ('Log: ' + $Log)
    if ($RebootNeeded) {Write-Warning 'Reboot Windows before final GUI smoke tests.'}
}
catch {
    Mark 'Overall setup' 'FAIL'
    Write-Error $_
    Write-Host ('Log: ' + $Log)
    Write-Host 'Fix the reported failure and rerun. Completed stages are reusable.'
    exit 1
}
finally {
    try {Stop-Transcript | Out-Null} catch {}
}
