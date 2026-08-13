model ProportionalPositionControl
  parameter Real targetAngle(unit="rad") = 1.0;
  parameter Real inertia(unit="kg.m2") = 0.5;
  parameter Real damping(unit="N.m.s/rad") = 1.2;
  parameter Real gain(unit="N.m/rad") = 6.0;
  Real angle(unit="rad", start=0, fixed=true);
  Real angularVelocity(unit="rad/s", start=0, fixed=true);
  Real commandedTorque(unit="N.m");
equation
  commandedTorque = gain * (targetAngle - angle);
  der(angle) = angularVelocity;
  inertia * der(angularVelocity) = commandedTorque - damping * angularVelocity;
end ProportionalPositionControl;
