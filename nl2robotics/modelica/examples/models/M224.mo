model RagM224
  parameter Real mobileGeometryScale = 0.97;
  parameter Real wheelRadius(unit="m") = 0.08 * mobileGeometryScale;
  parameter Real axleTrack(unit="m") = 0.4 * mobileGeometryScale;
  Modelica.Blocks.Sources.Constant leftCommand(k=5);
  Modelica.Blocks.Sources.Constant rightCommand(k=7);
  Modelica.Mechanics.Rotational.Sources.Speed leftWheel(exact=true);
  Modelica.Mechanics.Rotational.Sources.Speed rightWheel(exact=true);
  Modelica.Mechanics.Rotational.Sensors.SpeedSensor leftSensor;
  Modelica.Mechanics.Rotational.Sensors.SpeedSensor rightSensor;
  Real x(unit="m", start=0, fixed=true);
  Real y(unit="m", start=0, fixed=true);
  Real heading(unit="rad", start=0, fixed=true);
  Real linearVelocity(unit="m/s");
  Real angularVelocity(unit="rad/s");
equation
  connect(leftCommand.y, leftWheel.w_ref);
  connect(rightCommand.y, rightWheel.w_ref);
  connect(leftWheel.flange, leftSensor.flange);
  connect(rightWheel.flange, rightSensor.flange);
  linearVelocity = wheelRadius * (rightSensor.w + leftSensor.w) / 2;
  angularVelocity = wheelRadius * (rightSensor.w - leftSensor.w) / axleTrack;
  der(x) = linearVelocity * cos(heading);
  der(y) = linearVelocity * sin(heading);
  der(heading) = angularVelocity;
end RagM224;
