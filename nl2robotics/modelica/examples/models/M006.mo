model ThermallyLimitedMotor
  parameter Real inertia(unit="kg.m2") = 0.05;
  parameter Real damping(unit="N.m.s/rad") = 0.04;
  parameter Real torque(unit="N.m") = 0.8;
  parameter Real heatCapacity(unit="J/K") = 80;
  parameter Real cooling(unit="W/K") = 1.5;
  parameter Real ambientTemperature(unit="K") = 293.15;
  Real angularVelocity(unit="rad/s", start=0, fixed=true);
  Real temperature(unit="K", start=293.15, fixed=true);
  Real mechanicalPower(unit="W");
equation
  inertia * der(angularVelocity) = torque - damping * angularVelocity;
  mechanicalPower = torque * angularVelocity;
  heatCapacity * der(temperature) = 0.15 * abs(mechanicalPower)
    - cooling * (temperature - ambientTemperature);
end ThermallyLimitedMotor;
