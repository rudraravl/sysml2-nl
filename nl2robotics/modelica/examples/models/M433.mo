model RagM433
  parameter Real resistance(unit="Ohm") = 1.5;
  parameter Real inductance(unit="H") = 0.2;
  parameter Real torqueConstant(unit="N.m/A") = 0.15;
  parameter Real inertia(unit="kg.m2") = 0.055;
  parameter Real heatCapacity(unit="J/K") = 60;
  parameter Real thermalConductance(unit="W/K") = 1;
  Real current(unit="A", start=0, fixed=true);
  Real angularVelocity(unit="rad/s", start=0, fixed=true);
  Real angle(unit="rad", start=0, fixed=true);
  Real jointAngle(unit="rad");
  Real temperature(unit="K", start=293.15, fixed=true);
  Real voltage(unit="V");
equation
  voltage = max(-12, min(12, 8 * (1 - jointAngle)));
  inductance * der(current) = voltage - resistance * current
    - torqueConstant * angularVelocity;
  inertia * der(angularVelocity) = torqueConstant * current - 0.03 * angularVelocity;
  der(angle) = angularVelocity;
  jointAngle = angle / 5;
  heatCapacity * der(temperature) = resistance * current ^ 2
    - thermalConductance * (temperature - 293.15);
end RagM433;
