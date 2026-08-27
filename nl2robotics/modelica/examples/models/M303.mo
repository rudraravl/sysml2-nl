model RagM303
  parameter Real mass(unit="kg") = 1.2;
  parameter Real length(unit="m") = 0.6;
  parameter Real gravity(unit="m/s2") = 9.81;
  parameter Real damping(unit="N.m.s/rad") = 0.2575;
  Real angle(unit="rad", start=0.4, fixed=true);
  Real angularVelocity(unit="rad/s", start=0, fixed=true);
equation
  der(angle) = angularVelocity;
  mass * length ^ 2 * der(angularVelocity) =
    -mass * gravity * length * sin(angle) - damping * angularVelocity;
end RagM303;
