import com.rapidminer.RapidMiner;
import com.rapidminer.tools.OperatorService;
import com.rapidminer.operator.Operator;
import com.rapidminer.parameter.ParameterType;
public class NativeOperatorProbe {
 public static void main(String[] args) throws Exception {
  RapidMiner.setExecutionMode(RapidMiner.ExecutionMode.COMMAND_LINE);
  RapidMiner.init();
  if(args.length==0) {
   for(String key:OperatorService.getOperatorKeys()) if(key.matches(".*(read_csv|logistic|random_forest|decision_tree|validation|split_data|nominal_to|missing_values|performance_binominal|filter_examples|normalize|set_role|select_attributes|apply_model).*")) System.out.println("REGISTERED="+key);
  }
  for(String key:args) {
   Operator op=OperatorService.createOperator(key);
   System.out.println("OPERATOR="+key);
   if(op instanceof com.rapidminer.operator.OperatorChain) {
    int i=0;
    for(var unit:((com.rapidminer.operator.OperatorChain)op).getSubprocesses()) {
     for(var port:unit.getInnerSources().getAllPorts()) System.out.println("SUB_"+i+"_SOURCE="+port.getName());
     for(var port:unit.getInnerSinks().getAllPorts()) System.out.println("SUB_"+i+"_SINK="+port.getName());
     i++;
    }
   }
   for(var port:op.getInputPorts().getAllPorts()) System.out.println("INPUT="+port.getName());
   for(var port:op.getOutputPorts().getAllPorts()) System.out.println("OUTPUT="+port.getName());
   for(ParameterType p:op.getParameterTypes()) System.out.println("PARAM="+p.getKey()+" DEFAULT="+p.getDefaultValueAsString()+" TYPE="+p.getClass().getSimpleName());
  }
  System.out.println("NATIVE_OPERATOR_PROBE=PASS");
 }
}
