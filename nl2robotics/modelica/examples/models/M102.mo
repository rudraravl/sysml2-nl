model RagM102
  parameter Real inertia(unit="kg.m2") = 0.36;
  parameter Real stiffness(unit="N.m/rad") = 2.0;
  parameter Real damping(unit="N.m.s/rad") = 0.5;
  parameter Real appliedTorque(unit="N.m") = 1.0;
  Real angle(unit="rad", start=0, fixed=true);
  Real angularVelocity(unit="rad/s", start=0, fixed=true);
equation
  der(angle) = angularVelocity;
  inertia * der(angularVelocity) = appliedTorque - stiffness * angle
    - damping * angularVelocity;
end RagM102;
