# BISM2202 OzMart read-only source-data profiling. Windows PowerShell 5.1.
# No SQL writes and no changes to the existing SSIS project.
param([string]$OutDir='C:\BISM2202\analysis')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$target=Join-Path $OutDir 'ozmart-source-profile.json'
$conn=New-Object System.Data.SqlClient.SqlConnection('Server=.;Database=ozmart_db;Integrated Security=True;Encrypt=False;TrustServerCertificate=True;Connection Timeout=15')

function Read-Query([string]$Sql) {
    $cmd=$conn.CreateCommand()
    $cmd.CommandText=$Sql
    $cmd.CommandTimeout=180
    $ad=New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
    $dt=New-Object System.Data.DataTable
    $items=New-Object 'System.Collections.Generic.List[object]'
    try {
        [void]$ad.Fill($dt)
        foreach($row in $dt.Rows) {
            $v=[ordered]@{}
            foreach($col in $dt.Columns) {
                $cell=$row[$col.ColumnName]
                if($cell -is [System.DBNull]){$cell=$null}
                elseif($cell -is [datetime]){$cell=$cell.ToString('s')}
                $v[$col.ColumnName]=$cell
            }
            $items.Add([pscustomobject]$v)
        }
    } finally {$ad.Dispose();$cmd.Dispose();$dt.Dispose()}
    return ,($items.ToArray())
}
function Capture([string]$Name,[string]$Sql) {
    Write-Host "CHECK $Name"
    try {return ,(Read-Query $Sql)}
    catch {Write-Warning "$Name : $($_.Exception.Message)";return ,@([pscustomobject]@{error=$_.Exception.Message})}
}

$p=[ordered]@{report='OzMart source profile';generated_utc=[datetime]::UtcNow.ToString('o');database='ozmart_db';scope='read-only profiling; no SSIS ETL executed'}
$conn.Open()
try {
$p.table_counts=Capture 'table_counts' @'
SELECT 'address_type' AS table_name,COUNT_BIG(*) AS row_count FROM dbo.address_type
UNION ALL SELECT 'customer_address',COUNT_BIG(*) FROM dbo.customer_address
UNION ALL SELECT 'customer_table',COUNT_BIG(*) FROM dbo.customer_table
UNION ALL SELECT 'order_items_table',COUNT_BIG(*) FROM dbo.order_items_table
UNION ALL SELECT 'orders_table',COUNT_BIG(*) FROM dbo.orders_table
UNION ALL SELECT 'product_category',COUNT_BIG(*) FROM dbo.product_category
UNION ALL SELECT 'product_subcategory',COUNT_BIG(*) FROM dbo.product_subcategory
UNION ALL SELECT 'product_table',COUNT_BIG(*) FROM dbo.product_table
UNION ALL SELECT 'sellers_table',COUNT_BIG(*) FROM dbo.sellers_table;
'@
$p.key_uniqueness=Capture 'key_uniqueness' @'
SELECT 'customer_address' AS table_name,COUNT_BIG(*) AS row_count,COUNT_BIG(DISTINCT address_id) AS distinct_keys FROM dbo.customer_address
UNION ALL SELECT 'customer_table',COUNT_BIG(*),COUNT_BIG(DISTINCT customer_id) FROM dbo.customer_table
UNION ALL SELECT 'orders_table',COUNT_BIG(*),COUNT_BIG(DISTINCT order_id) FROM dbo.orders_table
UNION ALL SELECT 'order_items_table',COUNT_BIG(*),COUNT_BIG(DISTINCT order_item_id) FROM dbo.order_items_table
UNION ALL SELECT 'product_table',COUNT_BIG(*),COUNT_BIG(DISTINCT product_id) FROM dbo.product_table
UNION ALL SELECT 'sellers_table',COUNT_BIG(*),COUNT_BIG(DISTINCT seller_id) FROM dbo.sellers_table
UNION ALL SELECT 'product_category',COUNT_BIG(*),COUNT_BIG(DISTINCT Product_Categorey_ID) FROM dbo.product_category
UNION ALL SELECT 'product_subcategory',COUNT_BIG(*),COUNT_BIG(DISTINCT Product_Subcategorey_ID) FROM dbo.product_subcategory;
'@
$p.relationships=Capture 'relationships' @'
SELECT 'item -> order' AS relation, COUNT_BIG(*) AS source_rows, COUNT_BIG(t.order_id) AS matched, COUNT_BIG(*)-COUNT_BIG(t.order_id) AS unmatched
FROM dbo.order_items_table s LEFT JOIN dbo.orders_table t ON s.order_id=t.order_id
UNION ALL
SELECT 'order -> customer', COUNT_BIG(*), COUNT_BIG(t.customer_id), COUNT_BIG(*)-COUNT_BIG(t.customer_id)
FROM dbo.orders_table s LEFT JOIN dbo.customer_table t ON s.customer_id=t.customer_id
UNION ALL
SELECT 'item -> product', COUNT_BIG(*), COUNT_BIG(t.product_id), COUNT_BIG(*)-COUNT_BIG(t.product_id)
FROM dbo.order_items_table s LEFT JOIN dbo.product_table t ON s.product_id=t.product_id
UNION ALL
SELECT 'item -> seller', COUNT_BIG(*), COUNT_BIG(t.seller_id), COUNT_BIG(*)-COUNT_BIG(t.seller_id)
FROM dbo.order_items_table s LEFT JOIN dbo.sellers_table t ON s.seller_id=t.seller_id
UNION ALL
SELECT 'customer -> address', COUNT_BIG(*), COUNT_BIG(t.address_id), COUNT_BIG(*)-COUNT_BIG(t.address_id)
FROM dbo.customer_table s LEFT JOIN dbo.customer_address t ON s.location_id=t.address_id
UNION ALL
SELECT 'product -> subcategory', COUNT_BIG(*), COUNT_BIG(t.Product_Subcategorey_ID), COUNT_BIG(*)-COUNT_BIG(t.Product_Subcategorey_ID)
FROM dbo.product_table s LEFT JOIN dbo.product_subcategory t ON s.product_subcategorey_id=t.Product_Subcategorey_ID
UNION ALL
SELECT 'subcategory -> category', COUNT_BIG(*), COUNT_BIG(t.Product_Categorey_ID), COUNT_BIG(*)-COUNT_BIG(t.Product_Categorey_ID)
FROM dbo.product_subcategory s LEFT JOIN dbo.product_category t ON s.Product_Category_ID=t.Product_Categorey_ID;
'@
$p.item_quality=Capture 'item_quality' @'
SELECT COUNT_BIG(*) AS rows_total,
SUM(CONVERT(bigint,CASE WHEN item_quantity<=0 THEN 1 ELSE 0 END)) AS nonpositive_qty,
SUM(CONVERT(bigint,CASE WHEN line_total<0 THEN 1 ELSE 0 END)) AS negative_line_total,
SUM(CONVERT(bigint,CASE WHEN ABS(line_total-sales_price*CONVERT(float,item_quantity))>0.01 THEN 1 ELSE 0 END)) AS inconsistent_unit_price_extension,
SUM(CONVERT(bigint,CASE WHEN NULLIF(LTRIM(RTRIM(freight_price)),'') IS NOT NULL AND TRY_CONVERT(decimal(19,4),freight_price) IS NULL THEN 1 ELSE 0 END)) AS nonnumeric_freight,
MIN(line_total) AS min_total,MAX(line_total) AS max_total
FROM dbo.order_items_table;
'@
$p.order_statuses=Capture 'order_statuses' @'
SELECT status,COUNT_BIG(*) AS order_count FROM dbo.orders_table GROUP BY status ORDER BY order_count DESC;
'@
$p.order_dates=Capture 'order_dates' @'
SELECT MIN(purchase_timestamp) AS earliest_purchase,MAX(purchase_timestamp) AS latest_purchase,
SUM(CONVERT(bigint,CASE WHEN delivered_carrier_date IS NOT NULL AND TRY_CONVERT(datetime2,delivered_carrier_date) IS NULL THEN 1 ELSE 0 END)) AS invalid_carrier_date,
SUM(CONVERT(bigint,CASE WHEN delivered_customer_date IS NOT NULL AND TRY_CONVERT(datetime2,delivered_customer_date) IS NULL THEN 1 ELSE 0 END)) AS invalid_customer_delivery_date
FROM dbo.orders_table;
'@
$p.age_keys=Capture 'age_keys' @'
SELECT TOP (15) Age_key,COUNT_BIG(*) AS customer_count FROM dbo.customer_table GROUP BY Age_key ORDER BY customer_count DESC;
'@
$p.education_keys=Capture 'education_keys' @'
SELECT EDU_id,COUNT_BIG(*) AS customer_count FROM dbo.customer_table GROUP BY EDU_id ORDER BY customer_count DESC;
'@
$p.states=Capture 'states' @'
SELECT [state],COUNT_BIG(*) AS address_count FROM dbo.customer_address GROUP BY [state] ORDER BY address_count DESC;
'@
$p.region_values=Capture 'region_values' @'
SELECT MIN(region) AS min_region_money,MAX(region) AS max_region_money,COUNT_BIG(DISTINCT region) AS distinct_regions FROM dbo.customer_address;
'@
$p.line_total_examples=Capture 'line_total_examples' @'
SELECT TOP (12) item_quantity, sales_price, line_total,
    CONVERT(decimal(19,4),sales_price*CONVERT(float,item_quantity)) AS unit_times_quantity,
    CONVERT(decimal(19,4),line_total-sales_price*CONVERT(float,item_quantity)) AS difference
FROM dbo.order_items_table
WHERE ABS(line_total-sales_price*CONVERT(float,item_quantity))>0.01
ORDER BY ABS(line_total-sales_price*CONVERT(float,item_quantity)) DESC;
'@
$p.line_total_by_quantity=Capture 'line_total_by_quantity' @'
SELECT item_quantity,COUNT_BIG(*) AS row_count,
    SUM(CONVERT(bigint,CASE WHEN ABS(line_total-sales_price*CONVERT(float,item_quantity))>0.01 THEN 1 ELSE 0 END)) AS mismatched_rows,
    CONVERT(decimal(19,4),SUM(CONVERT(decimal(19,4),line_total))) AS line_total_sum
FROM dbo.order_items_table GROUP BY item_quantity ORDER BY item_quantity;
'@
$p.revenue_by_status=Capture 'revenue_by_status' @'
SELECT o.status,COUNT_BIG(*) AS item_rows,
    SUM(CONVERT(bigint,i.item_quantity)) AS units,
    CONVERT(decimal(19,4),SUM(CONVERT(decimal(19,4),i.line_total))) AS line_revenue
FROM dbo.orders_table o INNER JOIN dbo.order_items_table i ON o.order_id=i.order_id
GROUP BY o.status ORDER BY item_rows DESC;
'@
$p.seller_location_keys=Capture 'seller_location_keys' 'SELECT location_id FROM dbo.sellers_table;'
$p.education_key_counts=Capture 'education_key_counts' 'SELECT EDU_id, COUNT_BIG(*) AS customer_count FROM dbo.customer_table GROUP BY EDU_id;'
$p.age_key_counts=Capture 'age_key_counts' 'SELECT Age_key, COUNT_BIG(*) AS customer_count FROM dbo.customer_table GROUP BY Age_key;'
} finally {$conn.Close();$conn.Dispose()}

$expected=@('Age_Table.csv','Customer_Education.csv','seller_location.csv','State_code.csv')
$found=@(Get-ChildItem 'C:\BISM2202' -Filter '*.csv' -File -Recurse -ErrorAction SilentlyContinue)
$p.external_csvs=@(foreach($name in $expected){
    $m=@($found|Where-Object{$_.Name -ieq $name})
    [pscustomobject]@{name=$name;found=($m.Count -gt 0);path=@($m|ForEach-Object FullName)}
})
$p.external_csvs_in_zip=@()
try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $all=New-Object 'System.Collections.Generic.List[object]'
    foreach($zip in @(Get-ChildItem 'C:\BISM2202' -Filter '*.zip' -File -Recurse -ErrorAction SilentlyContinue)) {
        try {
            $arc=[System.IO.Compression.ZipFile]::OpenRead($zip.FullName)
            try {
                foreach($e in $arc.Entries) {
                    if($expected -contains [IO.Path]::GetFileName($e.FullName)){
                        $all.Add([pscustomobject]@{zip=$zip.FullName;entry=$e.FullName})
                    }
                }
            } finally {$arc.Dispose()}
        } catch {Write-Warning "Unable to read ZIP $($zip.FullName)"}
    }
    $p.external_csvs_in_zip=$all.ToArray()
} catch {Write-Warning 'ZIP inventory unavailable'}

# Diagnose external keys without updating the teacher CSVs.
function Get-TeacherCsv([string]$Name) {
    $f=$found|Where-Object{$_.Name -ieq $Name}|Select-Object -First 1
    if(-not $f){return ,@()}
    try {return ,@(Import-Csv -LiteralPath $f.FullName -Encoding UTF8)}
    catch {Write-Warning "$Name CSV parse failed: $($_.Exception.Message)";return ,@()}
}
$ageCsv=Get-TeacherCsv 'Age_Table.csv'
$eduCsv=Get-TeacherCsv 'Customer_Education.csv'
$sellerCsv=Get-TeacherCsv 'seller_location.csv'
$stateCsv=Get-TeacherCsv 'State_code.csv'

function Edu-Key([string]$v) {
    if($v -match '^EDU_0*([0-9]+)$'){return 'EDU_'+[int]$Matches[1]}
    return $v.Trim().ToUpperInvariant()
}
$eduKeys=@{}
foreach($r in $eduCsv){$eduKeys[(Edu-Key ([string]$r.EDU_ID))]=$true}
$eduMissing=@($p.education_key_counts|Where-Object{ -not $eduKeys.ContainsKey((Edu-Key ([string]$_.EDU_id))) })
$ageKeys=@{}
foreach($r in $ageCsv){$ageKeys[([string]$r.Age_Id).Trim().ToUpperInvariant()]=$true}
$ageMissing=@($p.age_key_counts|Where-Object{ -not $ageKeys.ContainsKey(([string]$_.Age_key).Trim().ToUpperInvariant()) })
$sellerKeys=@{}
foreach($r in $sellerCsv){$sellerKeys[([string]$r.location_id).Trim().ToUpperInvariant()]=$true}
$sellerMissing=@($p.seller_location_keys|Where-Object{-not $sellerKeys.ContainsKey(([string]$_.location_id).Trim().ToUpperInvariant())})
$stateKeys=@{}
foreach($r in $stateCsv){$stateKeys[([string]$r.state_code).Trim().ToUpperInvariant()]=$true}
$stateMissing=@($p.states|Where-Object{-not $stateKeys.ContainsKey(([string]$_.state).Trim().ToUpperInvariant())})
$p.external_lookup_coverage=[ordered]@{
    age_csv_rows=$ageCsv.Count
    age_distinct_source_codes=@($p.age_key_counts).Count
    age_missing_source_codes=@($ageMissing|Select-Object -ExpandProperty Age_key)
    education_csv_rows=$eduCsv.Count
    education_source_codes=@($p.education_key_counts).Count
    education_missing_after_zero_pad_normalization=@($eduMissing|Select-Object -ExpandProperty EDU_id)
    seller_csv_rows=$sellerCsv.Count
    seller_source_rows=@($p.seller_location_keys).Count
    seller_missing_location_ids=@($sellerMissing|Select-Object -ExpandProperty location_id)
    state_csv_rows=$stateCsv.Count
    customer_state_codes_missing=@($stateMissing|Select-Object -ExpandProperty state)
}
$p.check_errors=@(
    foreach($entry in $p.GetEnumerator()){
        if($entry.Value -is [array]){
            foreach($value in $entry.Value){
                if($value -and ($value.PSObject.Properties.Name -contains 'error')){
                    "$($entry.Key): $($value.error)"
                }
            }
        }
    }
)
$p|ConvertTo-Json -Depth 12|Set-Content -Encoding UTF8 $target
Write-Host "PROFILE_SAVED = $target"
Write-Host 'READ_ONLY = YES'
Write-Host "CHECK_FAILURES = $(@($p.check_errors).Count)"
if(@($p.check_errors).Count -gt 0){exit 1}
