model UnderwaterDepthController
  Real x(start=0, fixed=true);
  Real y(start=0, fixed=true);
  Real heading(start=0, fixed=true);
  Real linearVelocity;
  Real angularVelocity;
equation
  linearVelocity = der(x);
  angularVelocity = 0;
  der(x) = y;
  der(y) = 3 * (1.5 - x) - 2 * y;
  der(heading) = 0;
end UnderwaterDepthController;
