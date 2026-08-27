model RagM128
  parameter Real limit(unit="rad") = 1;
  parameter Real inertia(unit="kg.m2") = 0.225;
  Real angle(unit="rad", start=0, fixed=true);
  Real angularVelocity(unit="rad/s", start=0, fixed=true);
  Real stopTorque(unit="N.m");
equation
  stopTorque = if angle > limit then 40 * (angle - limit) else 0;
  der(angle) = angularVelocity;
  inertia * der(angularVelocity) = 1 - 0.5 * angularVelocity - stopTorque;
end RagM128;
