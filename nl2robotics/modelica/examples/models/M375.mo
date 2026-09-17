model RagM375
  parameter Real pumpPressure(unit="Pa") = 1030000;
  Real pressure(unit="Pa", start=1e5, fixed=true);
  Real pumpFlow(unit="m3/s");
  Real leakageFlow(unit="m3/s");
equation
  pumpFlow = 8e-5*max(0,1-pressure/pumpPressure);
  leakageFlow = 2e-11*pressure;
  der(pressure) = 5e8*(pumpFlow-leakageFlow);
end RagM375;
