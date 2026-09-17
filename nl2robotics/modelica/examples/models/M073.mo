model PneumaticChamber
  parameter Real ambientPressure(unit="Pa") = 1e5;
  Real pressure(unit="Pa", start=1e5, fixed=true);
  Real inletMassFlow(unit="kg/s");
  Real outletMassFlow(unit="kg/s");
equation
  inletMassFlow = 0.02;
  outletMassFlow = 1e-7*max(0,pressure-ambientPressure);
  der(pressure) = 8e6*(inletMassFlow-outletMassFlow);
end PneumaticChamber;
