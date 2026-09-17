model EvaluationJoint
  parameter Real inertia(unit="kg.m2") = 0.6;
  parameter Real damping(unit="N.m.s/rad") = 0.15;
  parameter Real appliedTorque(unit="N.m") = 1.2;
  output Real angle(unit="rad", start=0, fixed=true);
  output Real angularVelocity(unit="rad/s", start=0, fixed=true);
equation
  der(angle) = angularVelocity;
  inertia * der(angularVelocity) = appliedTorque - damping * angularVelocity;
end EvaluationJoint;
