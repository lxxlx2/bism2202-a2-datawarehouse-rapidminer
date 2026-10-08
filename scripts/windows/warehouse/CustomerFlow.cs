using System;
using System.Text.RegularExpressions;
using Microsoft.SqlServer.Dts.Runtime;
using Microsoft.SqlServer.Dts.Pipeline.Wrapper;
using DT=Microsoft.SqlServer.Dts.Runtime.Wrapper.DataType;

// Native SSIS components only. All joins, key normalisation and target casts
// occur in the Data Flow; source SQL projects original fields without joins.
public class BismCustomerFlow {
 Package pkg; MainPipe pipe; ConnectionManager sourceConnection,targetConnection;
 IDTSComponentMetaData100 New(string display,string prog,string name) {
  string id=null;int rank=-1;
  foreach(PipelineComponentInfo info in new Application().PipelineComponentInfos) {
   if(info.Name!=display && !info.CreationName.StartsWith(prog))continue;
   int n=0;var suffix=info.CreationName.Substring(Math.Min(info.CreationName.Length,prog.Length));
   if(suffix.StartsWith("."))Int32.TryParse(suffix.Substring(1),out n);
   if(id==null || n>rank){id=info.CreationName;rank=n;}
  }
  if(id==null)throw new Exception("Missing native component "+display);
  var m=pipe.ComponentMetaDataCollection.New();m.ComponentClassID=id;
  m.Instantiate().ProvideComponentProperties();m.Name=name;return m;
 }
 void Connect(IDTSComponentMetaData100 m,ConnectionManager c) {
  m.RuntimeConnectionCollection[0].ConnectionManager=DtsConvert.GetExtendedInterface(c);
  m.RuntimeConnectionCollection[0].ConnectionManagerID=c.ID;
 }
 IDTSOutput100 Source(string sql,bool reference=false) {
  var m=New("OLE DB Source","DTSAdapter.OleDbSource","Read original customer fields");var w=m.Instantiate();Connect(m,reference ? targetConnection : sourceConnection);
  w.SetComponentProperty("AccessMode",2);w.SetComponentProperty("SqlCommand",sql);
  w.AcquireConnections(null);w.ReinitializeMetaData();w.ReleaseConnections();return m.OutputCollection[0];
 }
 string Lineages(IDTSVirtualInput100 v,string expression) {
  foreach(IDTSVirtualInputColumn100 c in v.VirtualInputColumnCollection)
   expression=Regex.Replace(expression,@"\b"+Regex.Escape(c.Name)+@"\b","#"+c.LineageID);
  return expression;
 }
 IDTSOutput100 Derived(IDTSOutput100 previous,string name,string expression,DT type,int length) {
  var m=New("Derived Column","DTSTransform.DerivedColumn","Normalise education key (retain original)");var w=m.Instantiate();
  pipe.PathCollection.New().AttachPathAndPropagateNotifications(previous,m.InputCollection[0]);
  var i=m.InputCollection[0];var v=i.GetVirtualInput();
  foreach(IDTSVirtualInputColumn100 c in v.VirtualInputColumnCollection)w.SetUsageType(i.ID,v,c.LineageID,DTSUsageType.UT_READONLY);
  var o=w.InsertOutputColumnAt(m.OutputCollection[0].ID,0,name,"Explicit derived field");
  w.SetOutputColumnDataTypeProperties(m.OutputCollection[0].ID,o.ID,type,length,0,0,0);
  w.SetOutputColumnProperty(m.OutputCollection[0].ID,o.ID,"Expression",Lineages(v,expression));
  w.SetOutputColumnProperty(m.OutputCollection[0].ID,o.ID,"FriendlyExpression",expression);
  o.ErrorRowDisposition=DTSRowDisposition.RD_FailComponent;o.TruncationRowDisposition=DTSRowDisposition.RD_FailComponent;
  return m.OutputCollection[0];
 }
 IDTSOutput100 Lookup(IDTSOutput100 previous,string sql,string inputKey,string refKey,string refValue,string outputName,bool sourceReference=false) {
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
  o.SetDataTypeProperties(DT.DT_WSTR,sourceReference ? 50 : 256,0,0,0);
  w.SetOutputColumnProperty(m.OutputCollection[0].ID,o.ID,"CopyFromReferenceColumn",refValue);
  m.InputCollection[0].ErrorRowDisposition=DTSRowDisposition.RD_NotUsed;
  m.InputCollection[0].TruncationRowDisposition=DTSRowDisposition.RD_NotUsed;
  m.OutputCollection[0].ErrorRowDisposition=DTSRowDisposition.RD_FailComponent;
  o.TruncationRowDisposition=DTSRowDisposition.RD_FailComponent;
  return m.OutputCollection[0];
 }
 IDTSOutput100 Sort(IDTSOutput100 previous,string key) {
  var m=New("Sort","DTSTransform.Sort","Sort by "+key);var w=m.Instantiate();
  pipe.PathCollection.New().AttachPathAndPropagateNotifications(previous,m.InputCollection[0]);
  var i=m.InputCollection[0];var v=i.GetVirtualInput();
  foreach(IDTSVirtualInputColumn100 c in v.VirtualInputColumnCollection) {
   var selected=w.SetUsageType(i.ID,v,c.LineageID,DTSUsageType.UT_READONLY);
   w.SetInputColumnProperty(i.ID,selected.ID,"SortKeyPosition",c.Name==key ? 1 : 0);
  }
  return m.OutputCollection[0];
 }
 IDTSOutput100 MergeEducation(IDTSOutput100 previous) {
  var left=Sort(previous,"EducationCode");
  var right=Sort(Source("SELECT EDU_ID AS EducationJoinKey,Education_level AS EducationLevel FROM dbo.RefEducation",true),"EducationJoinKey");
  var m=New("Merge Join","DTSTransform.MergeJoin","Merge education CSV on normalised key");var w=m.Instantiate();
  w.SetComponentProperty("JoinType",2);w.SetComponentProperty("NumKeyColumns",1);w.SetComponentProperty("TreatNullsAsEqual",false);
  pipe.PathCollection.New().AttachPathAndPropagateNotifications(left,m.InputCollection[0]);
  pipe.PathCollection.New().AttachPathAndPropagateNotifications(right,m.InputCollection[1]);
  foreach(IDTSInput100 i in m.InputCollection) {
   var v=i.GetVirtualInput();
   foreach(IDTSVirtualInputColumn100 c in v.VirtualInputColumnCollection) {
    w.SetUsageType(i.ID,v,c.LineageID,DTSUsageType.UT_READONLY);
    if(c.Name=="EducationJoinKey")continue;
    var o=w.InsertOutputColumnAt(m.OutputCollection[0].ID,m.OutputCollection[0].OutputColumnCollection.Count,c.Name,"");
    o.SetDataTypeProperties(c.DataType,c.Length,c.Precision,c.Scale,c.CodePage);
    w.SetOutputColumnProperty(m.OutputCollection[0].ID,o.ID,"InputColumnID",c.LineageID);
   }
  }
  return m.OutputCollection[0];
 }
 void Destination(IDTSOutput100 previous,string table) {
  var m=New("OLE DB Destination","DTSAdapter.OleDbDestination","Load "+table);var w=m.Instantiate();Connect(m,targetConnection);
  w.SetComponentProperty("AccessMode",3);w.SetComponentProperty("OpenRowset","[dbo].["+table+"]");
  w.AcquireConnections(null);w.ReinitializeMetaData();w.ReleaseConnections();
  var convert=New("Data Conversion","DTSTransform.DataConvert","Explicit target column types");var cw=convert.Instantiate();
  pipe.PathCollection.New().AttachPathAndPropagateNotifications(previous,convert.InputCollection[0]);
  var ci=convert.InputCollection[0];var v=ci.GetVirtualInput();
  foreach(IDTSExternalMetadataColumn100 target in m.InputCollection[0].ExternalMetadataColumnCollection) {
   if(target.Name=="CustomerKey" && table=="DimCustomer" || target.Name=="ProductKey" && table=="DimProduct" || target.Name=="GeographyKey" && table=="DimGeography")continue;
   IDTSVirtualInputColumn100 source=null;
   foreach(IDTSVirtualInputColumn100 c in v.VirtualInputColumnCollection)if(c.Name==target.Name)source=c;
   if(source==null)throw new Exception("Missing mapped target "+target.Name);
   cw.SetUsageType(ci.ID,v,source.LineageID,DTSUsageType.UT_READONLY);
   var o=cw.InsertOutputColumnAt(convert.OutputCollection[0].ID,convert.OutputCollection[0].OutputColumnCollection.Count,"Load_"+target.Name,"");
   cw.SetOutputColumnProperty(convert.OutputCollection[0].ID,o.ID,"SourceInputColumnLineageID",source.LineageID);
   cw.SetOutputColumnDataTypeProperties(convert.OutputCollection[0].ID,o.ID,target.DataType,target.Length,target.Precision,target.Scale,target.CodePage);
   o.ErrorRowDisposition=DTSRowDisposition.RD_FailComponent;o.TruncationRowDisposition=DTSRowDisposition.RD_FailComponent;
  }
  var count=New("Row Count","DTSTransform.RowCount","Audit loaded rows");count.Instantiate().SetComponentProperty("VariableName","User::RowsCopied");
  pipe.PathCollection.New().AttachPathAndPropagateNotifications(convert.OutputCollection[0],count.InputCollection[0]);
  pipe.PathCollection.New().AttachPathAndPropagateNotifications(count.OutputCollection[0],m.InputCollection[0]);
  var di=m.InputCollection[0];var dv=di.GetVirtualInput();
  foreach(IDTSVirtualInputColumn100 c in dv.VirtualInputColumnCollection) {
   if(!c.Name.StartsWith("Load_"))continue;var selected=w.SetUsageType(di.ID,dv,c.LineageID,DTSUsageType.UT_READONLY);
   w.MapInputColumn(di.ID,selected.ID,di.ExternalMetadataColumnCollection[c.Name.Substring(5)].ID);
  }
 }
 static BismCustomerFlow Create(string source,string target,string name) {
  var b=new BismCustomerFlow();b.pkg=new Package();b.pkg.Name=name;b.pkg.ProtectionLevel=DTSProtectionLevel.DontSaveSensitive;
  b.pkg.Variables.Add("RowsCopied",false,"User",0L);
  b.sourceConnection=b.pkg.Connections.Add("OLEDB");b.sourceConnection.Name="Read only OzMart";b.sourceConnection.ConnectionString=source;
  b.targetConnection=b.pkg.Connections.Add("OLEDB");b.targetConnection.Name="Student warehouse";b.targetConnection.ConnectionString=target;
  var task=(TaskHost)b.pkg.Executables.Add("STOCK:PipelineTask");task.Name="DFT "+name;b.pipe=(MainPipe)task.InnerObject;return b;
 }
 long Finish(string path) {
  new Application().SaveToXml(path,pkg,null);
  if(pkg.Execute()!=DTSExecResult.Success) {string errors="";foreach(DtsError e in pkg.Errors)errors+="\n"+e.Description;throw new Exception(errors);}
  return Convert.ToInt64(pkg.Variables["User::RowsCopied"].Value);
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
  var o=seller ? b.Source("SELECT location_id AS LocationID,postcode AS Postcode,suburb AS Suburb,state AS StateCode,region AS RegionCode,type AS LocationType FROM dbo.RefSellerLocation",true)
   : b.Source("SELECT address_id AS LocationID,postcode AS Postcode,suburb AS Suburb,state AS StateCode,region AS RegionCode,type AS LocationTypeID FROM dbo.customer_address");
  o=b.Derived(o,"GeographyRole",seller ? "\"Seller\"" : "\"Customer\"",DT.DT_WSTR,16);
  if(!seller)o=b.Lookup(o,"SELECT type_id,location_type FROM dbo.address_type","LocationTypeID","type_id","location_type","LocationType",true);
  o=b.Lookup(o,"SELECT state_code,state_name FROM dbo.RefState","StateCode","state_code","state_name","StateName");
  b.Destination(o,"DimGeography");return b.Finish(path);
 }
 public static long Execute(string source,string target,string path,string student) {
  var b=new BismCustomerFlow();b.pkg=new Package();b.pkg.Name="Student_"+student+"_DimCustomer_"+(student=="B" ? "MergeJoin" : "Lookup");b.pkg.ProtectionLevel=DTSProtectionLevel.DontSaveSensitive;
  b.pkg.Variables.Add("RowsCopied",false,"User",0L);
  b.sourceConnection=b.pkg.Connections.Add("OLEDB");b.sourceConnection.Name="Read only OzMart";b.sourceConnection.ConnectionString=source;
  b.targetConnection=b.pkg.Connections.Add("OLEDB");b.targetConnection.Name="Student warehouse and CSV references";b.targetConnection.ConnectionString=target;
  var task=(TaskHost)b.pkg.Executables.Add("STOCK:PipelineTask");task.Name="DFT DimCustomer - two CSV lookups";b.pipe=(MainPipe)task.InnerObject;
  var output=b.Source("SELECT customer_id AS CustomerID, Gender, Age_key AS AgeSourceKey, EDU_id AS EducationSourceCode, location_id AS CustomerLocationID FROM dbo.customer_table");
  output=b.Derived(output,"EducationCode","(DT_WSTR,256)(\"EDU_\"+RIGHT(\"00\"+(DT_WSTR,4)(DT_I4)SUBSTRING(EducationSourceCode,5,8),2))",DT.DT_WSTR,256);
  output=b.Lookup(output,"SELECT Age_Id,Age FROM dbo.RefAge","AgeSourceKey","Age_Id","Age","Age");
  if(student=="B")output=b.MergeEducation(output);
  else output=b.Lookup(output,"SELECT EDU_ID,Education_level FROM dbo.RefEducation","EducationCode","EDU_ID","Education_level","EducationLevel");
  b.Destination(output,"DimCustomer");new Application().SaveToXml(path,b.pkg,null);
  if(b.pkg.Execute()!=DTSExecResult.Success) {string errors="";foreach(DtsError e in b.pkg.Errors)errors+="\n"+e.Description;throw new Exception(errors);}
  return Convert.ToInt64(b.pkg.Variables["User::RowsCopied"].Value);
 }
}
