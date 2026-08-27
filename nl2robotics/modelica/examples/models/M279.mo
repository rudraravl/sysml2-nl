model RagM279
  parameter Real dynamicRateScale = 0.97;
  parameter Real targetFlow(unit="m3/s") = 8e-5;
  Real valveCommand(start=0, fixed=true);
  Real flowRate(unit="m3/s", start=0, fixed=true);
  Real flowError(unit="m3/s");
equation
  flowError = targetFlow-flowRate;
  der(valveCommand) = dynamicRateScale * (20*(1e5*flowError-valveCommand));
  der(flowRate) = (1e-4*max(0,min(1,valveCommand))-flowRate)/0.05;
end RagM279;
