model PiVelocityControllerFMU
  parameter Real targetVelocity(unit="rad/s") = 2.0;
  parameter Real kp(unit="N.m.s/rad") = 1.0;
  parameter Real ki(unit="N.m/rad") = 0.5;
  parameter Real effortLimit(unit="N.m") = 3.0;
  input Real jointAngularVelocity(unit="rad/s", start=0.0);
  output Real commandedEffort(unit="N.m");
  Real integralError(unit="rad", start=0.0, fixed=true);
  Real rawEffort(unit="N.m");
equation
  der(integralError) = targetVelocity - jointAngularVelocity;
  rawEffort = kp * (targetVelocity - jointAngularVelocity)
    + ki * integralError;
  commandedEffort = max(-effortLimit, min(effortLimit, rawEffort));
end PiVelocityControllerFMU;
