model RagM416
  parameter Real mobileGeometryScale = 1.1;
  parameter Real wheelRadius(unit="m") = 0.08 * mobileGeometryScale;
  parameter Real axleTrack(unit="m") = 0.4 * mobileGeometryScale;
  parameter Real leftWheelSpeed(unit="rad/s") = 5;
  parameter Real rightWheelSpeed(unit="rad/s") = 7;
  Real x(unit="m", start=0, fixed=true);
  Real y(unit="m", start=0, fixed=true);
  Real heading(unit="rad", start=0, fixed=true);
  Real linearVelocity(unit="m/s");
  Real angularVelocity(unit="rad/s");
equation
  linearVelocity = wheelRadius * (rightWheelSpeed + leftWheelSpeed) / 2;
  angularVelocity = wheelRadius * (rightWheelSpeed - leftWheelSpeed) / axleTrack;
  der(x) = linearVelocity * cos(heading);
  der(y) = linearVelocity * sin(heading);
  der(heading) = angularVelocity;
end RagM416;
