import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;
import com.rapidminer.RapidMiner;
import com.rapidminer.operator.IOContainer;
import com.rapidminer.operator.IOObject;
import com.rapidminer.example.ExampleSet;
import com.rapidminer.example.Attribute;
import com.rapidminer.example.Example;
import com.rapidminer.operator.performance.PerformanceVector;
public class NativeProcessRunner {
 private static String quote(String text) { return "\""+text.replace("\"","\"\"")+"\""; }
 public static void main(String[] args) throws Exception {
  if(args.length!=2) throw new IllegalArgumentException("process.rmp output-directory");
  Path out=Path.of(args[1]);Files.createDirectories(out);
  RapidMiner.setExecutionMode(RapidMiner.ExecutionMode.COMMAND_LINE);
  RapidMiner.init();
  com.rapidminer.Process p=new com.rapidminer.Process(new File(args[0]));
  System.out.println("PROCESS_XML_OPEN=PASS");
  IOContainer result=p.run();
  int index=0;
  for(IOObject object:result.getIOObjects()) {
   System.out.println("RESULT_"+index+"_CLASS="+object.getClass().getName());
   if(object instanceof ExampleSet) {
    ExampleSet e=(ExampleSet)object;
    System.out.println("RESULT_"+index+"_ROWS="+e.size());
    StringBuilder csv=new StringBuilder("id,label,prediction,confidence_true\n");
    Attribute id=e.getAttributes().getId();
    Attribute label=e.getAttributes().getLabel();
    Attribute prediction=e.getAttributes().getPredictedLabel();
    Attribute confidence=e.getAttributes().getConfidence("true");
    for(Example row:e) {
     csv.append(quote(id==null ? "" : row.getValueAsString(id))).append(',');
     csv.append(quote(label==null ? "" : row.getValueAsString(label))).append(',');
     csv.append(quote(prediction==null ? "" : row.getValueAsString(prediction))).append(',');
     csv.append(confidence==null ? "" : Double.toString(row.getValue(confidence))).append('\n');
    }
    Files.writeString(out.resolve("result_"+index+"_identities.csv"),csv.toString());
    Files.writeString(out.resolve("result_"+index+"_summary.txt"),"Class="+object.getClass().getName()+"\nRows="+e.size()+"\n"+e.toString());
   } else {
    String text=object.toString();
    Files.writeString(out.resolve("result_"+index+".txt"),text+"\n");
    System.out.println(text);
    if(object instanceof PerformanceVector) {
     PerformanceVector pv=(PerformanceVector)object;
     StringBuilder csv=new StringBuilder("criterion,native_average,native_macro,native_micro,standard_deviation\n");
     for(String name:pv.getCriteriaNames()) {
      var c=pv.getCriterion(name);
      csv.append(quote(name)).append(',').append(c.getAverage()).append(',').append(c.getMakroAverage()).append(',').append(c.getMikroAverage()).append(',').append(c.getStandardDeviation()).append('\n');
     }
     Files.writeString(out.resolve("result_"+index+"_metrics.csv"),csv.toString());
    }
   }
   index++;
  }
  System.out.println("NATIVE_PROCESS_EXECUTION=PASS");
  System.out.println("GUI_REOPEN_AND_SCREENSHOTS=PENDING");
 }
}
