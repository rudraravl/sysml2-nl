model RagM172
  parameter Real supplyPressure(unit="Pa") = 900000;
  Real command;
  Real spoolPosition(start=0, fixed=true);
  Real loadPressure(unit="Pa", start=1e5, fixed=true);
  Real flowRate(unit="m3/s");
equation
  command = 0.8;
  der(spoolPosition) = (command-spoolPosition)/0.05;
  flowRate = 2e-4*spoolPosition*sqrt(max(0,(supplyPressure-loadPressure)/supplyPressure));
  der(loadPressure) = 5e8*(flowRate-1e-10*loadPressure);
end RagM172;
