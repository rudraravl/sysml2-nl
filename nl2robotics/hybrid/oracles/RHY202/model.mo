model MixedJointController
  parameter Real shoulder_kp(unit="N.m/rad") = 10.0;
  parameter Real shoulder_kd(unit="N.m.s/rad") = 1.5;
  parameter Real shoulder_target(unit="rad") = Modelica.Constants.pi / 9;
  parameter Real shoulder_limit(unit="N.m") = 4.0;
  parameter Real extension_kp(unit="N/m") = 50.0;
  parameter Real extension_kd(unit="N.s/m") = 8.0;
  parameter Real extension_target(unit="m") = 0.08;
  parameter Real extension_limit(unit="N") = 12.0;
  input Real shoulderPosition(unit="rad");
  input Real shoulderVelocity(unit="rad/s");
  output Real shoulderEffort(unit="N.m");
  input Real extensionPosition(unit="m");
  input Real extensionVelocity(unit="m/s");
  output Real extensionEffort(unit="N");
equation
  shoulderEffort = max(-shoulder_limit, min(shoulder_limit,
    shoulder_kp * (shoulder_target - shoulderPosition)
    - shoulder_kd * shoulderVelocity));
  extensionEffort = max(-extension_limit, min(extension_limit,
    extension_kp * (extension_target - extensionPosition)
    - extension_kd * extensionVelocity));
end MixedJointController;
