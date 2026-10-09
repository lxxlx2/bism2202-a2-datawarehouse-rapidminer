using System;
using System.Text.RegularExpressions;
using System.Collections.Generic;
using Microsoft.SqlServer.Dts.Runtime;
using Microsoft.SqlServer.Dts.Pipeline.Wrapper;
using DT=Microsoft.SqlServer.Dts.Runtime.Wrapper.DataType;

// Native SSIS components only. All joins, key normalisation and target casts
// occur in the Data Flow; source SQL projects original fields without joins.
public class BismCustomerFlow {
 Package pkg; MainPipe pipe; ConnectionManager sourceConnection,targetConnection;
 static Package sharedPackage; static Executable sharedLast; string countVariable="RowsCopied";
 static Dictionary<string,string> componentIds=new Dictionary<string,string>();
 IDTSComponentMetaData100 New(string display,string prog,string name) {
  string id=null;int rank=-1;
  if(componentIds.ContainsKey(prog))id=componentIds[prog];
  else {
  foreach(PipelineComponentInfo info in new Application().PipelineComponentInfos) {
   if(info.Name!=display && !info.CreationName.StartsWith(prog))continue;
   int n=0;var suffix=info.CreationName.Substring(Math.Min(info.CreationName.Length,prog.Length));
   if(suffix.StartsWith("."))Int32.TryParse(suffix.Substring(1),out n);
   if(id==null || n>rank){id=info.CreationName;rank=n;}
  }
  if(id==null)throw new Exception("Missing native component "+display);
  componentIds[prog]=id;
  }
  var m=pipe.ComponentMetaDataCollection.New();m.ComponentClassID=id;
  m.Instantiate().ProvideComponentProperties();m.Name=name;return m;
 }
 void Connect(IDTSComponentMetaData100 m,ConnectionManager c) {
  m.RuntimeConnectionCollection[0].ConnectionManager=DtsConvert.GetExtendedInterface(c);
  m.RuntimeConnectionCollection[0].ConnectionManagerID=c.ID;
 }
 IDTSOutput100 Source(string sql,bool reference=false) {
  var m=New("OLE DB Source","DTSAdapter.OleDbSource",(reference ? "Read warehouse references " : "Read OzMart fields ")+pipe.ComponentMetaDataCollection.Count);var w=m.Instantiate();Connect(m,reference ? targetConnection : sourceConnection);
  w.SetComponentProperty("AccessMode",2);w.SetComponentProperty("SqlCommand",sql);
  w.AcquireConnections(null);w.ReinitializeMetaData();w.ReleaseConnections();return m.OutputCollection[0];
 }
 string Lineages(IDTSVirtualInput100 v,string expression) {
  foreach(IDTSVirtualInputColumn100 c in v.VirtualInputColumnCollection)
   expression=Regex.Replace(expression,@"\b"+Regex.Escape(c.Name)+@"\b","#"+c.LineageID);
  return expression;
 }
 IDTSOutput100 Derived(IDTSOutput100 previous,string name,string expression,DT type,int length,int precision=0,int scale=0) {
  var m=New("Derived Column","DTSTransform.DerivedColumn","Derive "+name);var w=m.Instantiate();
  pipe.PathCollection.New().AttachPathAndPropagateNotifications(previous,m.InputCollection[0]);
  var i=m.InputCollection[0];var v=i.GetVirtualInput();
  foreach(IDTSVirtualInputColumn100 c in v.VirtualInputColumnCollection)w.SetUsageType(i.ID,v,c.LineageID,DTSUsageType.UT_READONLY);
  var o=w.InsertOutputColumnAt(m.OutputCollection[0].ID,0,name,"Explicit derived field");
  w.SetOutputColumnDataTypeProperties(m.OutputCollection[0].ID,o.ID,type,length,precision,scale,0);
  w.SetOutputColumnProperty(m.OutputCollection[0].ID,o.ID,"Expression",Lineages(v,expression));
  w.SetOutputColumnProperty(m.OutputCollection[0].ID,o.ID,"FriendlyExpression",expression);
  o.ErrorRowDisposition=DTSRowDisposition.RD_FailComponent;o.TruncationRowDisposition=DTSRowDisposition.RD_FailComponent;
  return m.OutputCollection[0];
 }
 IDTSOutput100 Lookup(IDTSOutput100 previous,string sql,string inputKey,string refKey,string refValue,string outputName,bool sourceReference=false,DT type=DT.DT_WSTR,int length=-1,int scale=0) {
  var m=New("Lookup","DTSTransform.Lookup","Lookup "+outputName+" (fail unmatched)");var w=m.Instantiate();Connect(m,sourceReference ? sourceConnection : targetConnection);
  w.SetComponentProperty("SqlCommand",sql);w.SetComponentProperty("CacheType",0);w.SetComponentProperty("NoMatchBehavior",0);
  w.SetComponentProperty("TreatDuplicateKeysAsError",true);
  pipe.PathCollection.New().AttachPathAndPropagateNotifications(previous,m.InputCollection[0]);
  w.AcquireConnections(null);w.ReinitializeMetaData();w.ReleaseConnections();
  var i=m.InputCollection[0];var v=i.GetVirtualInput();
  bool found=false;
  foreach(IDTSVirtualInputColumn100 c in v.VirtualInputColumnCollection) {
   if(c.Name!=inputKey)continue;var selected=w.SetUsageType(i.ID,v,c.LineageID,DTSUsageType.UT_READONLY);
   w.SetInputColumnProperty(i.ID,selected.ID,"JoinToReferenceColumn",refKey);found=true;
  }
  if(!found)throw new Exception("Missing lookup input "+inputKey);
  var o=w.InsertOutputColumnAt(m.OutputCollection[0].ID,0,outputName,"Reference attribute");
  o.SetDataTypeProperties(type,length>=0 ? length : (type==DT.DT_WSTR ? (sourceReference ? 50 : 256) : 0),0,scale,0);
  w.SetOutputColumnProperty(m.OutputCollection[0].ID,o.ID,"CopyFromReferenceColumn",refValue);
  m.InputCollection[0].ErrorRowDisposition=DTSRowDisposition.RD_NotUsed;
  m.InputCollection[0].TruncationRowDisposition=DTSRowDisposition.RD_NotUsed;
  m.OutputCollection[0].ErrorRowDisposition=DTSRowDisposition.RD_FailComponent;
  o.TruncationRowDisposition=DTSRowDisposition.RD_FailComponent;
  return m.OutputCollection[0];
 }
 IDTSOutput100 Sort(IDTSOutput100 previous,string key,bool unique=false) {
  var m=New("Sort","DTSTransform.Sort","Sort by "+key);var w=m.Instantiate();
  w.SetComponentProperty("EliminateDuplicates",unique);
  pipe.PathCollection.New().AttachPathAndPropagateNotifications(previous,m.InputCollection[0]);
  var i=m.InputCollection[0];var v=i.GetVirtualInput();
  foreach(IDTSVirtualInputColumn100 c in v.VirtualInputColumnCollection) {
   var selected=w.SetUsageType(i.ID,v,c.LineageID,DTSUsageType.UT_READONLY);
   w.SetInputColumnProperty(i.ID,selected.ID,"NewSortKeyPosition",c.Name==key ? 1 : 0);
  }
  return m.OutputCollection[0];
 }
 IDTSOutput100 MergeEducation(IDTSOutput100 previous) {
  var left=Sort(previous,"EducationCode");
  var right=Sort(Source("SELECT EDU_ID AS EducationJoinKey,Education_level AS EducationLevel FROM dbo.RefEducation",true),"EducationJoinKey");
  var m=New("Merge Join","DTSTransform.MergeJoin","Merge education CSV on normalised key");var w=m.Instantiate();
  w.SetComponentProperty("JoinType",2);
  m.CustomPropertyCollection["NumKeyColumns"].Value=1;
  w.SetComponentProperty("TreatNullsAsEqual",false);
  pipe.PathCollection.New().AttachPathAndPropagateNotifications(left,m.InputCollection[0]);
  pipe.PathCollection.New().AttachPathAndPropagateNotifications(right,m.InputCollection[1]);
  foreach(IDTSInput100 i in m.InputCollection) {
   var v=i.GetVirtualInput();
   foreach(IDTSVirtualInputColumn100 c in v.VirtualInputColumnCollection) {
    w.SetUsageType(i.ID,v,c.LineageID,DTSUsageType.UT_READONLY);
    // Native Merge Join creates the mapped output column when usage is set.
    // Do not add a second output column with the same name.

   }
  }
  return m.OutputCollection[0];
 }
 void Destination(IDTSOutput100 previous,string table) {
  var m=New("OLE DB Destination","DTSAdapter.OleDbDestination","Load "+table);var w=m.Instantiate();Connect(m,targetConnection);
  w.SetComponentProperty("AccessMode",3);w.SetComponentProperty("OpenRowset","[dbo].["+table+"]");
  w.SetComponentProperty("FastLoadOptions","TABLOCK,CHECK_CONSTRAINTS");
  w.AcquireConnections(null);w.ReinitializeMetaData();w.ReleaseConnections();
  var convert=New("Data Conversion","DTSTransform.DataConvert","Explicit target column types");var cw=convert.Instantiate();
  pipe.PathCollection.New().AttachPathAndPropagateNotifications(previous,convert.InputCollection[0]);
  var ci=convert.InputCollection[0];var v=ci.GetVirtualInput();
  foreach(IDTSExternalMetadataColumn100 target in m.InputCollection[0].ExternalMetadataColumnCollection) {
   if(target.Name=="CustomerKey" && table=="DimCustomer" || target.Name=="ProductKey" && table=="DimProduct" || target.Name=="GeographyKey" && table=="DimGeography" || target.Name=="SalesKey" && table=="FactSales" || target.Name=="SellerKey" && table=="DimSeller")continue;
   IDTSVirtualInputColumn100 source=null;
   foreach(IDTSVirtualInputColumn100 c in v.VirtualInputColumnCollection)if(c.Name==target.Name)source=c;
   if(source==null)throw new Exception("Missing mapped target "+target.Name);
   cw.SetUsageType(ci.ID,v,source.LineageID,DTSUsageType.UT_READONLY);
   var o=cw.InsertOutputColumnAt(convert.OutputCollection[0].ID,convert.OutputCollection[0].OutputColumnCollection.Count,"Load_"+target.Name,"");
   cw.SetOutputColumnProperty(convert.OutputCollection[0].ID,o.ID,"SourceInputColumnLineageID",source.LineageID);
   cw.SetOutputColumnDataTypeProperties(convert.OutputCollection[0].ID,o.ID,target.DataType,target.Length,target.Precision,target.Scale,target.CodePage);
   o.ErrorRowDisposition=DTSRowDisposition.RD_FailComponent;o.TruncationRowDisposition=DTSRowDisposition.RD_FailComponent;
  }
  var count=New("Row Count","DTSTransform.RowCount","Audit loaded rows");count.Instantiate().SetComponentProperty("VariableName","User::"+countVariable);
  pipe.PathCollection.New().AttachPathAndPropagateNotifications(convert.OutputCollection[0],count.InputCollection[0]);
  pipe.PathCollection.New().AttachPathAndPropagateNotifications(count.OutputCollection[0],m.InputCollection[0]);
  var di=m.InputCollection[0];var dv=di.GetVirtualInput();
  foreach(IDTSVirtualInputColumn100 c in dv.VirtualInputColumnCollection) {
   if(!c.Name.StartsWith("Load_"))continue;var selected=w.SetUsageType(di.ID,dv,c.LineageID,DTSUsageType.UT_READONLY);
   w.MapInputColumn(di.ID,selected.ID,di.ExternalMetadataColumnCollection[c.Name.Substring(5)].ID);
  }
 }
 static BismCustomerFlow Create(string source,string target,string name) {
  var b=new BismCustomerFlow();b.pkg=sharedPackage ?? new Package();
  if(sharedPackage==null){b.pkg.Name=name;b.pkg.ProtectionLevel=DTSProtectionLevel.DontSaveSensitive;}
  b.countVariable=sharedPackage==null ? "RowsCopied" : "Rows_"+b.pkg.Executables.Count;
  b.pkg.Variables.Add(b.countVariable,false,"User",0L);
  b.sourceConnection=b.pkg.Connections.Add("OLEDB");b.sourceConnection.Name=name+" OzMart";b.sourceConnection.ConnectionString=source;
  b.targetConnection=b.pkg.Connections.Add("OLEDB");b.targetConnection.Name=name+" warehouse";b.targetConnection.ConnectionString=target;
  var task=(TaskHost)b.pkg.Executables.Add("STOCK:PipelineTask");task.Name="DFT "+name;b.pipe=(MainPipe)task.InnerObject;
  if(sharedPackage!=null){if(sharedLast!=null)b.pkg.PrecedenceConstraints.Add(sharedLast,task).Value=DTSExecResult.Success;sharedLast=task;}
  return b;
 }
 long Finish(string path) {
  if(sharedPackage!=null)return 0L;
  new Application().SaveToXml(path,pkg,null);
  if(pkg.Execute()!=DTSExecResult.Success) {string errors="";foreach(DtsError e in pkg.Errors)errors+="\n"+e.Description;throw new Exception(errors);}
  return Convert.ToInt64(pkg.Variables["User::"+countVariable].Value);
 }
 IDTSOutput100 FlatCSV(string csv,string headers) {
  var c=pkg.Connections.Add("FLATFILE");c.Name="CSV "+headers.Split(',')[0];c.ConnectionString=csv;
  var ff=(Microsoft.SqlServer.Dts.Runtime.Wrapper.IDTSConnectionManagerFlatFile100)c.InnerObject;
  ff.Format="Delimited";ff.CodePage=65001;ff.Unicode=false;ff.ColumnNamesInFirstDataRow=true;
  ff.HeaderRowDelimiter="\r\n";ff.RowDelimiter="\r\n";ff.TextQualifier="\"";
  var fields=headers.Split(',');
  for(int n=0;n<fields.Length;n++){var col=ff.Columns.Add();col.ColumnType="Delimited";col.ColumnDelimiter=n==fields.Length-1 ? "\r\n" : ",";col.DataType=DT.DT_WSTR;col.MaximumWidth=256;((Microsoft.SqlServer.Dts.Runtime.Wrapper.IDTSName100)col).Name=fields[n];}
  var m=New("Flat File Source","DTSAdapter.FlatFileSource","Read original "+System.IO.Path.GetFileNameWithoutExtension(csv));Connect(m,c);
  var w=m.Instantiate();w.AcquireConnections(null);w.ReinitializeMetaData();w.ReleaseConnections();return m.OutputCollection[0];
 }
 public static string Warehouse(string source,string target,string csvRoot,string path,string student) {
  if(student!="A" && student!="B")throw new Exception("Unapproved student target");
  string expected="STUDENT_"+student+"_ID_dw";
  if(!target.Contains("Initial Catalog="+expected+";"))throw new Exception("Unexpected warehouse connection");
  var pkg=new Package();pkg.Name="Student_"+student+"_Warehouse_ETL";pkg.ProtectionLevel=DTSProtectionLevel.DontSaveSensitive;pkg.DelayValidation=true;
  var resetConn=pkg.Connections.Add("OLEDB");resetConn.Name="Isolated warehouse reset";resetConn.ConnectionString=target;
  var reset=(TaskHost)pkg.Executables.Add("STOCK:SQLTask");reset.Name="Reset isolated assignment warehouse";
  reset.Properties["Connection"].SetValue(reset,resetConn.ID);
  reset.Properties["SqlStatementSource"].SetValue(reset,"IF DB_NAME() <> '"+expected+"' THROW 51000,'Unexpected database',1; SET XACT_ABORT ON; BEGIN TRAN; DELETE FROM dbo.FactSales; DELETE FROM dbo.DimCustomer; DELETE FROM dbo.DimProduct; DELETE FROM dbo.DimSeller; DELETE FROM dbo.DimDate; DELETE FROM dbo.DimGeography; DELETE FROM dbo.RefAge; DELETE FROM dbo.RefEducation; DELETE FROM dbo.RefState; DELETE FROM dbo.RefSellerLocation; ALTER TABLE dbo.FactSales WITH CHECK CHECK CONSTRAINT ALL; ALTER TABLE dbo.DimCustomer WITH CHECK CHECK CONSTRAINT ALL; ALTER TABLE dbo.DimProduct WITH CHECK CHECK CONSTRAINT ALL; ALTER TABLE dbo.DimSeller WITH CHECK CHECK CONSTRAINT ALL; ALTER TABLE dbo.DimDate WITH CHECK CHECK CONSTRAINT ALL; ALTER TABLE dbo.DimGeography WITH CHECK CHECK CONSTRAINT ALL; COMMIT;");
  try {
   sharedPackage=pkg;sharedLast=reset;
   string[][] refs=new string[][] {
    new string[]{"Age_Table.csv","RefAge","Age_Id,Age"},new string[]{"Customer_Education.csv","RefEducation","EDU_ID,Education_level"},
    new string[]{"State_code.csv","RefState","state_name,state_code"},new string[]{"seller_location.csv","RefSellerLocation","location_id,unit,street,postcode,suburb,state,type,status,region"}};
   foreach(var spec in refs){var b=Create(source,target,"Student_"+student+"_"+spec[1]);b.Destination(b.FlatCSV(System.IO.Path.Combine(csvRoot,spec[0]),spec[2]),spec[1]);}
   var seller=Create(source,target,"Student_"+student+"_DimSeller");seller.Destination(seller.Source("SELECT seller_id AS SellerID,name AS SellerName,location_id AS SellerLocationID,creation_date AS CreatedAt,end_date AS EndAt FROM dbo.sellers_table"),"DimSeller");
   Execute(source,target,"",student);Product(source,target,"",student);Geography(source,target,"",student,false);Geography(source,target,"",student,true);Date(source,target,"",student);Fact(source,target,"",student);
  } finally {sharedPackage=null;sharedLast=null;}
  new Application().SaveToXml(path,pkg,null);
  if(pkg.Execute()!=DTSExecResult.Success){string errors="";foreach(DtsError e in pkg.Errors)errors+="\n"+e.Description;throw new Exception(errors);}
  string audit="WAREHOUSE_NATIVE_EXECUTION=PASS\n";
  foreach(Variable v in pkg.Variables)if(v.Namespace=="User")audit+=v.Name+"="+v.Value+"\n";
  return audit;
 }
 public static long Fact(string source,string target,string path,string student) {
  var b=Create(source,target,"Student_"+student+"_FactSales");
  var o=b.Source("SELECT order_item_id AS OrderItemID,order_id AS OrderID,product_id AS ProductID,seller_id AS SellerID,item_sequence AS ItemSequence,item_quantity AS ItemQuantity,sales_price AS SourceUnitSalesPrice,line_total AS SourceLineTotal FROM dbo.order_items_table");
  o=b.Lookup(o,"SELECT order_id,customer_id FROM dbo.orders_table","OrderID","order_id","customer_id","CustomerID",true);
  o=b.Lookup(o,"SELECT order_id,status FROM dbo.orders_table","OrderID","order_id","status","OrderStatus",true);
  o=b.Lookup(o,"SELECT order_id,purchase_timestamp FROM dbo.orders_table","OrderID","order_id","purchase_timestamp","PurchaseTimestamp",true,DT.DT_DBTIMESTAMP2,0,7);
  o=b.Lookup(o,"SELECT CustomerID,CustomerKey FROM dbo.DimCustomer","CustomerID","CustomerID","CustomerKey","CustomerKey",false,DT.DT_I4,0);
  o=b.Lookup(o,"SELECT CustomerID,CustomerLocationID FROM dbo.DimCustomer","CustomerID","CustomerID","CustomerLocationID","CustomerLocationID",false,DT.DT_WSTR,64);
  o=b.Lookup(o,"SELECT ProductID,ProductKey FROM dbo.DimProduct","ProductID","ProductID","ProductKey","ProductKey",false,DT.DT_I4,0);
  o=b.Lookup(o,"SELECT SellerID,SellerKey FROM dbo.DimSeller","SellerID","SellerID","SellerKey","SellerKey",false,DT.DT_I4,0);
  o=b.Lookup(o,"SELECT SellerID,SellerLocationID FROM dbo.DimSeller","SellerID","SellerID","SellerLocationID","SellerLocationID",false,DT.DT_WSTR,64);
  o=b.Lookup(o,"SELECT LocationID,GeographyKey FROM dbo.DimGeography WHERE GeographyRole='Customer'","CustomerLocationID","LocationID","GeographyKey","CustomerGeographyKey",false,DT.DT_I4,0);
  o=b.Lookup(o,"SELECT LocationID,GeographyKey FROM dbo.DimGeography WHERE GeographyRole='Seller'","SellerLocationID","LocationID","GeographyKey","SellerGeographyKey",false,DT.DT_I4,0);
  o=b.Derived(o,"PurchaseDateKey","YEAR(PurchaseTimestamp)*10000+MONTH(PurchaseTimestamp)*100+DAY(PurchaseTimestamp)",DT.DT_I4,0);
  // Round scaled floats to integral ten-thousandths before exact numeric division.
  // A direct float-to-DT_NUMERIC cast truncates and failed source reconciliation.
  o=b.Derived(o,"UnitSalesPrice",Money("SourceUnitSalesPrice"),DT.DT_NUMERIC,0,19,4);
  o=b.Derived(o,"LineAmount",Money("SourceLineTotal"),DT.DT_NUMERIC,0,19,4);
  o=b.Derived(o,"ExtendedAmount",Money("SourceUnitSalesPrice*ItemQuantity"),DT.DT_NUMERIC,0,19,4);
  o=b.Derived(o,"AmountDifference",Money("SourceLineTotal-SourceUnitSalesPrice*ItemQuantity"),DT.DT_NUMERIC,0,19,4);
  // Verified source freight_price is NULL for all 137901 rows.
  o=b.Derived(o,"FreightAmount","NULL(DT_NUMERIC,19,4)",DT.DT_NUMERIC,0,19,4);
  b.Destination(o,"FactSales");return b.Finish(path);
 }
 static string Money(string value) {
  return "(DT_NUMERIC,19,4)((DT_NUMERIC,19,0)ROUND(("+value+")*10000.0,0)/(DT_NUMERIC,5,0)10000)";
 }
 public static long Date(string source,string target,string path,string student) {
  var b=Create(source,target,"Student_"+student+"_DimDate");
  var o=b.Source("SELECT purchase_timestamp AS PurchaseTimestamp FROM dbo.orders_table");
  o=b.Derived(o,"DateKey","YEAR(PurchaseTimestamp)*10000+MONTH(PurchaseTimestamp)*100+DAY(PurchaseTimestamp)",DT.DT_I4,0);
  o=b.Derived(o,"CalendarDate","(DT_DBDATE)PurchaseTimestamp",DT.DT_DBDATE,0);
  o=b.Derived(o,"CalendarYear","(DT_I2)YEAR(PurchaseTimestamp)",DT.DT_I2,0);
  o=b.Derived(o,"CalendarQuarter","(DT_UI1)DATEPART(\"qq\",PurchaseTimestamp)",DT.DT_UI1,0);
  o=b.Derived(o,"CalendarMonth","(DT_UI1)MONTH(PurchaseTimestamp)",DT.DT_UI1,0);
  o=b.Derived(o,"DayOfMonth","(DT_UI1)DAY(PurchaseTimestamp)",DT.DT_UI1,0);
  o=b.Sort(o,"DateKey",true);b.Destination(o,"DimDate");return b.Finish(path);
 }
 public static long Product(string source,string target,string path,string student) {
  var b=Create(source,target,"Student_"+student+"_DimProduct");
  var o=b.Source("SELECT product_id AS ProductID,product_name AS ProductName,product_subcategorey_id AS SubcategoryID FROM dbo.product_table");
  o=b.Lookup(o,"SELECT Product_Subcategorey_ID,Product_Subcategory FROM dbo.product_subcategory","SubcategoryID","Product_Subcategorey_ID","Product_Subcategory","SubcategoryName",true);
  o=b.Lookup(o,"SELECT Product_Subcategorey_ID,Product_Category_ID FROM dbo.product_subcategory","SubcategoryID","Product_Subcategorey_ID","Product_Category_ID","CategoryID",true);
  o=b.Lookup(o,"SELECT Product_Categorey_ID,Product_Category FROM dbo.product_category","CategoryID","Product_Categorey_ID","Product_Category","CategoryName",true);
  b.Destination(o,"DimProduct");return b.Finish(path);
 }
 public static long Geography(string source,string target,string path,string student,bool seller) {
  var b=Create(source,target,"Student_"+student+"_DimGeography_"+(seller ? "Seller" : "Customer"));
  IDTSOutput100 o;
  if(seller) {
   o=b.Source("SELECT location_id AS LocationID,postcode AS RawPostcode,suburb AS RawSuburb,state AS RawStateCode,region AS RawRegionCode,type AS RawLocationType FROM dbo.RefSellerLocation",true);
   o=b.Lookup(o,"SELECT state_code,state_name FROM dbo.RefState","RawStateCode","state_code","state_name","RawStateName");
   // Verified immutable source conflict; both raw candidate rows remain in RefSellerLocation.
   string conflict="LocationID==\"ece22fa5b9e06f5b\"";
   o=b.Derived(o,"StateCode","(DT_WSTR,3)("+conflict+" ? \"UNK\" : RawStateCode)",DT.DT_WSTR,3);
   o=b.Derived(o,"StateName","(DT_WSTR,64)("+conflict+" ? \"Unresolved conflicting CSV mapping\" : RawStateName)",DT.DT_WSTR,64);
   o=b.Derived(o,"Postcode",conflict+" ? NULL(DT_WSTR,16) : (DT_WSTR,16)RawPostcode",DT.DT_WSTR,16);
   o=b.Derived(o,"Suburb",conflict+" ? NULL(DT_WSTR,256) : RawSuburb",DT.DT_WSTR,256);
   o=b.Derived(o,"RegionCode",conflict+" ? NULL(DT_WSTR,16) : (DT_WSTR,16)RawRegionCode",DT.DT_WSTR,16);
   o=b.Derived(o,"LocationType",conflict+" ? NULL(DT_WSTR,32) : (DT_WSTR,32)RawLocationType",DT.DT_WSTR,32);
   o=b.Sort(o,"LocationID",true);
  } else {
   o=b.Source("SELECT address_id AS LocationID,postcode AS Postcode,suburb AS Suburb,state AS StateCode,region AS RegionCode,type AS LocationType FROM dbo.customer_address");
   o=b.Lookup(o,"SELECT state_code,state_name FROM dbo.RefState","StateCode","state_code","state_name","StateName");
  }
  o=b.Derived(o,"GeographyRole",seller ? "\"Seller\"" : "\"Customer\"",DT.DT_WSTR,16);
  b.Destination(o,"DimGeography");return b.Finish(path);
 }
 public static long Execute(string source,string target,string path,string student) {
  var b=Create(source,target,"Student_"+student+"_DimCustomer_"+(student=="B" ? "MergeJoin" : "Lookup"));
  var output=b.Source("SELECT customer_id AS CustomerID, Gender, Age_key AS AgeSourceKey, EDU_id AS EducationSourceCode, location_id AS CustomerLocationID FROM dbo.customer_table");
  output=b.Derived(output,"EducationCode","(DT_WSTR,256)(\"EDU_\"+RIGHT(\"00\"+(DT_WSTR,4)(DT_I4)SUBSTRING(EducationSourceCode,5,8),2))",DT.DT_WSTR,256);
  output=b.Lookup(output,"SELECT Age_Id,Age FROM dbo.RefAge","AgeSourceKey","Age_Id","Age","Age");
  if(student=="B")output=b.MergeEducation(output);
  else output=b.Lookup(output,"SELECT EDU_ID,Education_level FROM dbo.RefEducation","EducationCode","EDU_ID","Education_level","EducationLevel");
  b.Destination(output,"DimCustomer");return b.Finish(path);
 }
}
