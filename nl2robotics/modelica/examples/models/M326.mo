model RagM326
  parameter Real mass(unit="kg") = 1.03;
  parameter Real length(unit="m") = 0.5;
  parameter Real target(unit="rad") = 0.6;
  Real angle(unit="rad", start=0, fixed=true);
  Real angularVelocity(unit="rad/s", start=0, fixed=true);
  Real controlTorque(unit="N.m");
equation
  controlTorque = 12 * (target - angle) - 4 * angularVelocity
    + mass * 9.81 * length * sin(target);
  der(angle) = angularVelocity;
  mass * length ^ 2 * der(angularVelocity) = controlTorque
    - mass * 9.81 * length * sin(angle);
end RagM326;
