model RagM301
  parameter Real inertia(unit="kg.m2") = 0.515;
  parameter Real damping(unit="N.m.s/rad") = 0.1;
  parameter Real appliedTorque(unit="N.m") = 1.0;
  Real angle(unit="rad", start=0, fixed=true);
  Real angularVelocity(unit="rad/s", start=0, fixed=true);
equation
  der(angle) = angularVelocity;
  inertia * der(angularVelocity) = appliedTorque - damping * angularVelocity;
end RagM301;
