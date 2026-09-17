model RagM413
  parameter Real inertia(unit="kg.m2") = 0.22;
  parameter Real driveTorque(unit="N.m") = 0.8;
  parameter Real damping(unit="N.m.s/rad") = 0.2;
  parameter Real angleLimit(unit="rad") = 1.0;
  parameter Real brakeGain(unit="N.m/rad") = 30;
  Real angle(unit="rad", start=0, fixed=true);
  Real angularVelocity(unit="rad/s", start=0, fixed=true);
  Real brakeTorque(unit="N.m");
equation
  brakeTorque = if angle > angleLimit then
    brakeGain * (angle - angleLimit) else 0;
  der(angle) = angularVelocity;
  inertia * der(angularVelocity) = driveTorque - damping * angularVelocity
    - brakeTorque;
end RagM413;
