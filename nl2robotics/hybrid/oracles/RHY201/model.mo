model ClosedLoopShoulderController
  parameter Real targetAngle(unit="rad") = Modelica.Constants.pi / 6;
  parameter Real kp(unit="N.m/rad") = 12.0;
  parameter Real kd(unit="N.m.s/rad") = 2.0;
  parameter Real torqueLimit(unit="N.m") = 5.0;
  input Real shoulderAngle(unit="rad");
  input Real shoulderAngularVelocity(unit="rad/s");
  output Real shoulderTorque(unit="N.m");
equation
  shoulderTorque = max(-torqueLimit, min(torqueLimit,
    kp * (targetAngle - shoulderAngle) - kd * shoulderAngularVelocity));
end ClosedLoopShoulderController;
