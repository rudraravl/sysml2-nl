model RagM214
  parameter Real maximumTemperature(unit="K") = 300;
  parameter Real ambientTemperature(unit="K") = 293.15;
  parameter Real heatCapacity(unit="J/K") = 19.4;
  parameter Real cooling(unit="W/K") = 0.5;
  parameter Real heatingPower(unit="W") = 15;
  parameter Real restartTemperature(unit="K") = 298;
  Real temperature(unit="K", start=293.15, fixed=true);
  discrete Boolean enabled(start=true, fixed=true);
equation
  when temperature >= maximumTemperature then
    enabled = false;
  elsewhen temperature <= restartTemperature then
    enabled = true;
  end when;
  heatCapacity * der(temperature) = (if enabled then heatingPower else 0)
    - cooling * (temperature - ambientTemperature);
end RagM214;
