model RagM230
  parameter Real target(unit="rad") = 1;
  parameter Real inertia(unit="kg.m2") = 0.388;
  Real angle(unit="rad", start=0, fixed=true);
  Real angularVelocity(unit="rad/s", start=0, fixed=true);
  Real disturbance(unit="N.m");
  Real controlTorque(unit="N.m");
equation
  disturbance = if time >= 1 then 0.4 else 0;
  controlTorque = 10 * (target - angle) - 3 * angularVelocity;
  der(angle) = angularVelocity;
  inertia * der(angularVelocity) = controlTorque - disturbance;
end RagM230;
