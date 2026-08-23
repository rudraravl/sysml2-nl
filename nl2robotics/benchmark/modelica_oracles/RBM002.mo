model EvaluationServo
  parameter Real inertia(unit="kg.m2") = 1.0;
  parameter Real damping(unit="N.m.s/rad") = 1.0;
  parameter Real kp(unit="N.m/rad") = 20.0;
  parameter Real kd(unit="N.m.s/rad") = 8.0;
  parameter Real target(unit="rad") = 0.75;
  output Real angle(unit="rad", start=0, fixed=true);
  Real angularVelocity(unit="rad/s", start=0, fixed=true);
  Real torque(unit="N.m");
equation
  torque = kp * (target - angle) - kd * angularVelocity;
  der(angle) = angularVelocity;
  inertia * der(angularVelocity) = torque - damping * angularVelocity;
end EvaluationServo;
