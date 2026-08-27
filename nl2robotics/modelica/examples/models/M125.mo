model RagM125
  parameter Real inertia(unit="kg.m2") = 0.36;
  parameter Real torque(unit="N.m") = 1;
  parameter Real viscous(unit="N.m.s/rad") = 0.12;
  parameter Real coulomb(unit="N.m") = 0.18;
  Real angle(unit="rad", start=0, fixed=true);
  Real angularVelocity(unit="rad/s", start=0, fixed=true);
equation
  der(angle) = angularVelocity;
  inertia * der(angularVelocity) = torque - viscous * angularVelocity
    - coulomb * tanh(angularVelocity / 0.01);
end RagM125;
