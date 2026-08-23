model PdEffortControllerFMU
  parameter Real targetAngle(unit="rad") = 0.6;
  parameter Real kp(unit="N.m/rad") = 8.0;
  parameter Real kd(unit="N.m.s/rad") = 1.5;
  parameter Real effortLimit(unit="N.m") = 4.0;
  input Real jointAngle(unit="rad", start=0.0);
  input Real jointAngularVelocity(unit="rad/s", start=0.0);
  output Real commandedEffort(unit="N.m");
  Real rawEffort(unit="N.m");
equation
  rawEffort = kp * (targetAngle - jointAngle)
    - kd * jointAngularVelocity;
  commandedEffort = max(-effortLimit, min(effortLimit, rawEffort));
end PdEffortControllerFMU;
