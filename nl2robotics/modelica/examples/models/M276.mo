model RagM276
  parameter Real reliefPressure(unit="Pa") = 679000;
  Real pressure(unit="Pa", start=1e5, fixed=true);
  Real inletFlow(unit="m3/s");
  Real reliefFlow(unit="m3/s");
equation
  inletFlow = 1e-4;
  reliefFlow = 2e-9*max(0,pressure-reliefPressure);
  der(pressure) = 2e8*(inletFlow-reliefFlow-1e-10*pressure);
end RagM276;
