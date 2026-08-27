model RagM304
  parameter Real resistance(unit="Ohm") = 2.0;
  parameter Real inductance(unit="H") = 0.4;
  parameter Real torqueConstant(unit="N.m/A") = 0.12;
  parameter Real backEmfConstant(unit="V.s/rad") = 0.12;
  parameter Real inertia(unit="kg.m2") = 0.0309;
  parameter Real damping(unit="N.m.s/rad") = 0.02;
  parameter Real voltage(unit="V") = 12.0;
  Real current(unit="A", start=0, fixed=true);
  Real angularVelocity(unit="rad/s", start=0, fixed=true);
  Real angle(unit="rad", start=0, fixed=true);
equation
  inductance * der(current) = voltage - resistance * current
    - backEmfConstant * angularVelocity;
  inertia * der(angularVelocity) = torqueConstant * current
    - damping * angularVelocity;
  der(angle) = angularVelocity;
end RagM304;
