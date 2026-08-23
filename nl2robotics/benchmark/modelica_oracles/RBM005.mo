model EvaluationHydraulicAxis
  parameter Real pistonArea(unit="m2") = 0.01;
  parameter Real movingMass(unit="kg") = 20;
  parameter Real damping(unit="N.s/m") = 80;
  parameter Real bulkCompliance(unit="m3/Pa") = 2e-10;
  parameter Real supplyFlow(unit="m3/s") = 2e-4;
  output Real pressure(unit="Pa", start=0, fixed=true);
  output Real flowRate(unit="m3/s");
  output Real position(unit="m", start=0, fixed=true);
  output Real velocity(unit="m/s", start=0, fixed=true);
equation
  flowRate = supplyFlow;
  der(pressure) = (flowRate - pistonArea * velocity) / bulkCompliance;
  der(position) = velocity;
  movingMass * der(velocity) = pistonArea * pressure - damping * velocity;
end EvaluationHydraulicAxis;
