model RagM371
  parameter Real supplyPressure(unit="Pa") = 824000;
  parameter Real pistonArea(unit="m2") = 1e-4;
  Real pressure(unit="Pa", start=1e5, fixed=true);
  Real flowRate(unit="m3/s");
  Real position(unit="m", start=0, fixed=true);
  Real velocity(unit="m/s", start=0, fixed=true);
equation
  flowRate = 1e-4 * max(0, supplyPressure-pressure) / supplyPressure;
  der(pressure) = 2e8 * (flowRate-pistonArea*velocity);
  der(position) = velocity;
  20*der(velocity) = pressure*pistonArea-25*velocity-5;
end RagM371;
