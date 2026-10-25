$ErrorActionPreference = 'Stop'
$repo = 'lxxlx2/bism2202-a2-datawarehouse-rapidminer'
$branch = 'evidence/rapidminer-20261025-review'
$api = 'https://api.github.com/repos/' + $repo

function Api([string]$method, [string]$url, $payload = $null) {
    $params = @{ Method = $method; Uri = $url; Headers = $script:headers; ErrorAction = 'Stop'; TimeoutSec = 180 }
    if ($null -ne $payload) {
        $params.ContentType = 'application/json'
        $params.Body = ConvertTo-Json -InputObject $payload -Compress -Depth 5
    }
    return Invoke-RestMethod @params
}

$found = @()
$roots = @( 'H:\', (Join-Path $HOME 'OneDrive') )
foreach ($root in $roots) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    $found += @(Get-ChildItem -Path (Join-Path $root 'BISM2202_RapidMiner_Evidence_*.zip') -File -ErrorAction SilentlyContinue)
    $dirs = @(Get-ChildItem -LiteralPath $root -Directory -Filter 'BISM2202*' -ErrorAction SilentlyContinue)
    foreach ($dir in $dirs) {
        $found += @(Get-ChildItem -Path (Join-Path $dir.FullName 'BISM2202_RapidMiner_Evidence_*.zip') -File -ErrorAction SilentlyContinue)
        $found += @(Get-ChildItem -Path (Join-Path $dir.FullName 'evidence\rapidminer\BISM2202_RapidMiner_Evidence_*.zip') -File -ErrorAction SilentlyContinue)
    }
}
$found = @($found | Where-Object { $_ -and $_.Exists } | Sort-Object LastWriteTime -Descending -Unique)
if ($found.Count -eq 0) { throw 'EVIDENCE_ZIP_NOT_FOUND: Check H: drive and OneDrive.' }
$preferred = @($found | Where-Object { $_.Name -eq 'BISM2202_RapidMiner_Evidence_20261025_181546.zip' })
$file = if ($preferred.Count -gt 0) { $preferred[0] } else { $found[0] }
Write-Host ('FILE=' + $file.FullName)
Write-Host ('BYTES=' + $file.Length)
if ($file.Length -gt 25MB) { throw 'FILE_TOO_LARGE_FOR_THIS_UPLOADER: limit 25MB.' }
if ($file.Length -le 0) { throw 'EMPTY_ZIP' }

Write-Host 'WARNING: The destination GitHub repository is PUBLIC.' -ForegroundColor Yellow
Write-Host 'Only upload if the ZIP contains no credentials, private records, or personal data.'
$choice = Read-Host 'Upload the evidence ZIP to the PUBLIC repository? Type YES to continue'
if ($choice -cne 'YES') { Write-Host 'CANCELLED'; exit 2 }

$token = $null
if (Get-Command gh -ErrorAction SilentlyContinue) {
    $token = (& gh auth token 2>$null | Select-Object -First 1)
}
if ([string]::IsNullOrWhiteSpace($token)) {
    Write-Host 'GitHub fine-grained PAT is required (Contents: Read and write). Input is hidden.'
    $secure = Read-Host 'Paste GitHub token' -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}
if ([string]::IsNullOrWhiteSpace($token)) { throw 'NO_GITHUB_AUTH' }
$headers = @{
    Authorization = 'Bearer ' + $token.Trim()
    Accept = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
    'User-Agent' = 'BISM2202-Evidence-Uploader'
}

$branchUrl = $api + '/git/ref/heads/' + $branch
$exists = $false
try { $null = Api 'GET' $branchUrl; $exists = $true }
catch {
    if (-not $_.Exception.Response -or [int]$_.Exception.Response.StatusCode -ne 404) { throw }
}
if (-not $exists) {
    $base = Api 'GET' ($api + '/git/ref/heads/main')
    $null = Api 'POST' ($api + '/git/refs') @{ ref = 'refs/heads/' + $branch; sha = $base.object.sha }
}
$target = 'review_evidence/rapidminer/' + $file.Name
$contentsUrl = $api + '/contents/' + $target
$oldSha = $null
try { $current = Api 'GET' ($contentsUrl + '?ref=' + $branch); $oldSha = $current.sha }
catch {
    if (-not $_.Exception.Response -or [int]$_.Exception.Response.StatusCode -ne 404) { throw }
}
$data = [IO.File]::ReadAllBytes($file.FullName)
$body = @{
    message = 'evidence(rapidminer): upload school GUI results for review'
    branch = $branch
    content = [Convert]::ToBase64String($data)
}
if ($oldSha) { $body.sha = $oldSha }
$result = Api 'PUT' $contentsUrl $body
if (-not $result.content.sha) { throw 'UPLOAD_RESPONSE_MISSING_BLOB_SHA' }

$blob = Api 'GET' ($api + '/git/blobs/' + $result.content.sha)
if ($blob.encoding -ne 'base64' -or -not $blob.content) { throw 'REMOTE_READBACK_UNAVAILABLE' }
$remoteData = [Convert]::FromBase64String(($blob.content -replace '\s',''))
$sha = [Security.Cryptography.SHA256]::Create()
try {
    $localHash = [BitConverter]::ToString($sha.ComputeHash($data)).Replace('-','').ToLowerInvariant()
    $remoteHash = [BitConverter]::ToString($sha.ComputeHash($remoteData)).Replace('-','').ToLowerInvariant()
} finally { $sha.Dispose() }
if ($localHash -ne $remoteHash) { throw 'UPLOAD_HASH_MISMATCH' }
Write-Host 'UPLOAD_AND_READBACK=PASS' -ForegroundColor Green
Write-Host ('SHA256=' + $localHash)
Write-Host ('COMMIT=' + $result.commit.sha)
Write-Host ('URL=https://github.com/' + $repo + '/blob/' + $branch + '/' + $target)
