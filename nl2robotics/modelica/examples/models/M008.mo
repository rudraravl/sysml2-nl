model PdTrajectoryTracking
  parameter Real inertia(unit="kg.m2") = 0.3;
  parameter Real damping(unit="N.m.s/rad") = 0.2;
  parameter Real kp(unit="N.m/rad") = 12;
  parameter Real kd(unit="N.m.s/rad") = 3;
  Real reference(unit="rad");
  Real referenceVelocity(unit="rad/s");
  Real angle(unit="rad", start=0, fixed=true);
  Real angularVelocity(unit="rad/s", start=0, fixed=true);
  Real commandedTorque(unit="N.m");
  Real trackingError(unit="rad");
equation
  reference = 0.5 * sin(time);
  referenceVelocity = 0.5 * cos(time);
  trackingError = reference - angle;
  commandedTorque = kp * trackingError + kd * (referenceVelocity - angularVelocity);
  der(angle) = angularVelocity;
  inertia * der(angularVelocity) = commandedTorque - damping * angularVelocity;
end PdTrajectoryTracking;
