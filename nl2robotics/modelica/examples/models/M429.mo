model RagM429
  parameter Real inertia(unit="kg.m2") = 0.33;
  parameter Real stiffness(unit="N.m/rad") = 3;
  parameter Real damping(unit="N.m.s/rad") = 0.4;
  Real angle(unit="rad", start=0.5, fixed=true);
  Real angularVelocity(unit="rad/s", start=0, fixed=true);
equation
  der(angle) = angularVelocity;
  inertia * der(angularVelocity) = -stiffness * angle - damping * angularVelocity;
end RagM429;
