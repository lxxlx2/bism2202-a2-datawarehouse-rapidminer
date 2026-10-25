param([string]$ProjectRoot = '')
$ErrorActionPreference = 'Stop'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$base = Join-Path $env:TEMP ('BISM2202_code_'+$stamp)
$download = Join-Path $base 'source.zip'
$unpack = Join-Path $base 'unpack'
New-Item -ItemType Directory -Force -Path $base,$unpack | Out-Null
try {
  Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/lxxlx2/bism2202-a2-datawarehouse-rapidminer/e7118f04fefa507e946dd1ac752fe9b36192ed2b/deliveries/BISM2202_A2_%E6%93%8D%E4%BD%9C%E6%89%8B%E5%86%8C%E4%B8%8E%E6%8A%A5%E5%91%8A_%E4%BF%AE%E8%AE%A2%E7%89%88.zip' -OutFile $download
  $sha = (Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash.ToLowerInvariant()
  if($sha -ne '5623ce2f5105cafbf728f61138e998d8d28da149f1d0dd053f07b8f82834b480'){ throw 'ARCHIVE_HASH_MISMATCH' }
  Expand-Archive -LiteralPath $download -DestinationPath $unpack -Force
  $top = @(Get-ChildItem -LiteralPath $unpack -Directory | Select-Object -First 1)
  if($top.Count -ne 1){ throw 'ARCHIVE_LAYOUT_ERROR' }
  $from = $top[0].FullName
  if(-not $ProjectRoot){
    foreach($parent in @('H:\',(Get-Location).Path,$env:OneDriveCommercial,$env:OneDrive)){
      if(-not $parent -or -not (Test-Path -LiteralPath $parent)){ continue }
      foreach($dir in @($parent)+@(Get-ChildItem -LiteralPath $parent -Directory -ErrorAction SilentlyContinue | Where-Object {$_.Name -match 'BISM2202'} | Select-Object -ExpandProperty FullName)){
        if(Test-Path -LiteralPath (Join-Path $dir 'rapidminer\NaiveBayes_Full.rmp')){$ProjectRoot=$dir;break}
      }
      if($ProjectRoot){break}
    }
  }
  if(-not $ProjectRoot){throw 'PROJECT_NOT_FOUND: cannot locate rapidminer directory'}
  $ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
  $code = Join-Path $ProjectRoot ('_CodeOnly_'+$stamp)
  foreach($part in @('rapidminer','programs','scripts','sql')){New-Item -ItemType Directory -Force -Path (Join-Path $code $part) | Out-Null}
  foreach($name in @('NaiveBayes_Full.rmp','GradientBoostedTrees_Full.rmp')){
     Copy-Item -LiteralPath (Join-Path $from ('rapidminer\'+$name)) -Destination (Join-Path $code ('programs\'+$name)) -ErrorAction Stop
  }
  foreach($name in @('01_schema.sql','02_queries.sql','03_validation.sql','04_backup.sql')) {
    Copy-Item -LiteralPath (Join-Path $from ('sql\'+$name)) -Destination (Join-Path $code ('sql\'+$name)) -ErrorAction Stop
  }
  foreach($name in @('Start-Warehouse-Windows.ps1','generate_warehouse_windows.py','make_visual_studio_project.py','prepare_teacher_data.py')) {
    Copy-Item -LiteralPath (Join-Path $from ('scripts\'+$name)) -Destination (Join-Path $code ('scripts\'+$name)) -ErrorAction Stop
  }
  $runner = Join-Path $code 'Run-BISM2202.ps1'
  Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/lxxlx2/bism2202-a2-datawarehouse-rapidminer/13cbc60fac34799bc77a1d0dc31f6c44c64594f7/deliveries/code_only/Run-BISM2202-School-Windows-v6.ps1' -OutFile $runner
  $tokens=$null;$errors=$null
  [void][System.Management.Automation.Language.Parser]::ParseFile($runner,[ref]$tokens,[ref]$errors)
  if($errors.Count -ne 0){throw ('PARSER_ERROR: '+($errors[0].Message))}
  $codezip = Join-Path $ProjectRoot ('BISM2202_Code_Only_'+$stamp+'.zip')
  Compress-Archive -Path (Join-Path $code '*') -DestinationPath $codezip -Force
  Write-Host ('CODE_ONLY_ZIP='+$codezip)
  & $runner -ProjectRoot $ProjectRoot
  if($LASTEXITCODE -ne 0){throw ('RUNNER_FAILED_EXIT_CODE='+$LASTEXITCODE)}
} finally {
  Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
}
