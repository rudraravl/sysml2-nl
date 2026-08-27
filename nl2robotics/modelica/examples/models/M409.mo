model RagM409
  parameter Real targetAngle(unit="rad") = 0.5;
  parameter Real kp(unit="N.m/rad") = 5.5;
  parameter Real effortLimit(unit="N.m") = 2.0;
  input Real jointAngleDegrees(unit="deg", start=0.0);
  output Real commandedEffort(unit="N.m");
  Real jointAngle(unit="rad");
  Real rawEffort(unit="N.m");
equation
  jointAngle = jointAngleDegrees * Modelica.Constants.pi / 180.0;
  rawEffort = kp * (targetAngle - jointAngle);
  commandedEffort = max(-effortLimit, min(effortLimit, rawEffort));
end RagM409;
