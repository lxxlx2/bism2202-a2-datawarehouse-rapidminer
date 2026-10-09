param([ValidateSet('A','B')][string]$Student='A')
$ErrorActionPreference='Stop'
$db="STUDENT_${Student}_ID_dw"
$out="C:\BISM2202\submission\Student_$Student\evidence\sql"
New-Item -ItemType Directory -Force $out|Out-Null
function Query([string]$sql,[string]$database=$db){
 $c=New-Object System.Data.SqlClient.SqlConnection("Server=.;Database=$database;Integrated Security=True;Encrypt=False")
 try{$c.Open();$cmd=$c.CreateCommand();$cmd.CommandText=$sql;$cmd.CommandTimeout=300;$a=New-Object System.Data.SqlClient.SqlDataAdapter $cmd;$d=New-Object System.Data.DataSet;[void]$a.Fill($d);return ,$d}finally{$c.Dispose()}
}
function ExportTables($data,[string]$name){
 $index=0
 foreach($t in $data.Tables){
  $rows=@(foreach($r in $t.Rows){$o=[ordered]@{};foreach($col in $t.Columns){$v=$r[$col.ColumnName];if($v -is [DBNull]){$v=$null};$o[$col.ColumnName]=$v};[pscustomobject]$o})
  $rows|Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $out "$name-$index.csv")
  ConvertTo-Json -InputObject $rows -Depth 5|Set-Content -Encoding UTF8 (Join-Path $out "$name-$index.json")
  $index++
 }
}
try{
 $runtime=Get-Content -Raw "C:\BISM2202\submission\Student_$Student\ssis\STUDENT_${Student}_ID_SSIS\warehouse_results.txt"
 if($runtime -notmatch 'WAREHOUSE_MASTER_RUNTIME=PASS'){throw 'Full master runtime must pass first'}
 $sql=Get-Content -Raw "C:\BISM2202\assignment_work\sql\Student_$Student\warehouse_validation.sql"
 $sql=$sql -replace '(?m)^GO\s*$',''
 ExportTables (Query $sql) 'warehouse-validation'
 $checks=Query @'
IF EXISTS (SELECT 1 FROM dbo.FactSales f JOIN dbo.DimGeography cg ON cg.GeographyKey=f.CustomerGeographyKey JOIN dbo.DimGeography sg ON sg.GeographyKey=f.SellerGeographyKey WHERE cg.GeographyRole<>'Customer' OR sg.GeographyRole<>'Seller') THROW 51010,'Geography role mismatch',1;
IF EXISTS (SELECT 1 FROM dbo.FactSales f JOIN dbo.DimCustomer c ON c.CustomerKey=f.CustomerKey JOIN dbo.DimGeography g ON g.GeographyKey=f.CustomerGeographyKey WHERE c.CustomerLocationID<>g.LocationID) THROW 51011,'Customer geography mismatch',1;
IF EXISTS (SELECT 1 FROM dbo.FactSales f JOIN dbo.DimSeller s ON s.SellerKey=f.SellerKey JOIN dbo.DimGeography g ON g.GeographyKey=f.SellerGeographyKey WHERE s.SellerLocationID<>g.LocationID) THROW 51012,'Seller geography mismatch',1;
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE is_disabled=1 OR is_not_trusted=1) THROW 51013,'Foreign keys disabled or untrusted',1;
SELECT COUNT_BIG(*) Items,SUM(CONVERT(bigint,ItemQuantity)) Units,SUM(LineAmount) LineAmount,SUM(ExtendedAmount) ExtendedAmount,SUM(CASE WHEN FreightAmount IS NULL THEN 1 ELSE 0 END) NullFreight,SUM(CASE WHEN ABS(AmountDifference)>0.01 THEN 1 ELSE 0 END) AmountMismatch FROM dbo.FactSales;
SELECT g.StateCode,COUNT_BIG(*) Items,COUNT(DISTINCT f.SellerKey) Sellers FROM dbo.FactSales f JOIN dbo.DimGeography g ON g.GeographyKey=f.SellerGeographyKey GROUP BY g.StateCode ORDER BY g.StateCode;
SELECT 'NATURAL_KEYS_AND_ROLES_PASS' Gate;
'@
 ExportTables $checks 'business-audit'
 foreach($name in @('Q4_1','Q4_2','Q4_3','Q4_3_customer_destination_sensitivity')){
  $sql=(Get-Content -Raw "C:\BISM2202\assignment_work\sql\Student_$Student\$name.sql") -replace '(?m)^GO\s*$',''
  ExportTables (Query $sql) $name
 }
 'WAREHOUSE_VALIDATION_AND_QUERIES=PASS'|Set-Content -Encoding UTF8 (Join-Path $out 'execution_status.txt')
}catch{$_|Out-String|Set-Content -Encoding UTF8 (Join-Path $out 'execution_status.txt');exit 1}
