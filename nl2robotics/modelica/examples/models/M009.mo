model SaturatedVelocityControl
  parameter Real targetVelocity(unit="rad/s") = 4;
  parameter Real inertia(unit="kg.m2") = 0.2;
  parameter Real damping(unit="N.m.s/rad") = 0.1;
  parameter Real gain(unit="N.m.s/rad") = 2;
  parameter Real torqueLimit(unit="N.m") = 1.5;
  Real angularVelocity(unit="rad/s", start=0, fixed=true);
  Real rawTorque(unit="N.m");
  Real commandedTorque(unit="N.m");
equation
  rawTorque = gain * (targetVelocity - angularVelocity);
  commandedTorque = max(-torqueLimit, min(torqueLimit, rawTorque));
  inertia * der(angularVelocity) = commandedTorque - damping * angularVelocity;
end SaturatedVelocityControl;
