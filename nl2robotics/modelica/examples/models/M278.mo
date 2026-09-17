model RagM278
  parameter Real ambientTemperature(unit="K") = 293.15;
  parameter Real pressureDrop(unit="Pa") = 485000;
  parameter Real flowRate(unit="m3/s") = 1e-4;
  Real temperature(unit="K", start=293.15, fixed=true);
  Real lossPower(unit="W");
equation
  lossPower = pressureDrop*flowRate;
  500*der(temperature) = lossPower-4*(temperature-ambientTemperature);
end RagM278;
