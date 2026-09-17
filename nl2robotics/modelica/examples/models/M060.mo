model GroundRobotSpeedController
  Real x(start=0, fixed=true);
  Real y(start=0, fixed=true);
  Real heading(start=0, fixed=true);
  Real linearVelocity;
  Real angularVelocity;
equation
  linearVelocity = y;
  angularVelocity = 0;
  der(x) = linearVelocity;
  der(y) = 2 * (1 - y);
  der(heading) = 0;
end GroundRobotSpeedController;
