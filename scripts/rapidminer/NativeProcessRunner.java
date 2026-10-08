import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;
import com.rapidminer.RapidMiner;
import com.rapidminer.operator.IOContainer;
import com.rapidminer.operator.IOObject;
import com.rapidminer.example.ExampleSet;
public class NativeProcessRunner {
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
    Files.writeString(out.resolve("result_"+index+"_summary.txt"),"Class="+object.getClass().getName()+"\nRows="+e.size()+"\n"+e.toString());
   } else {
    String text=object.toString();
    Files.writeString(out.resolve("result_"+index+".txt"),text+"\n");
    System.out.println(text);
   }
   index++;
  }
  System.out.println("NATIVE_PROCESS_EXECUTION=PASS");
  System.out.println("GUI_REOPEN_AND_SCREENSHOTS=PENDING");
 }
}
