model RagM218
  parameter Real mass(unit="kg") = 1.455;
  parameter Real gravity(unit="m/s2") = 9.81;
  parameter Real targetAltitude(unit="m") = 2;
  parameter Real kp(unit="N/m") = 8;
  parameter Real kd(unit="N.s/m") = 5;
  Real altitude(unit="m", start=0, fixed=true);
  Real verticalVelocity(unit="m/s", start=0, fixed=true);
  Real thrust(unit="N");
equation
  thrust = mass * gravity + kp * (targetAltitude - altitude)
    - kd * verticalVelocity;
  der(altitude) = verticalVelocity;
  mass * der(verticalVelocity) = thrust - mass * gravity;
end RagM218;
