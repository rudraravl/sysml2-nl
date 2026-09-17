model RagM260
  parameter Real dynamicRateScale = 0.97;
  Real x(start=0, fixed=true);
  Real y(start=0, fixed=true);
  Real heading(start=0, fixed=true);
  Real linearVelocity;
  Real angularVelocity;
equation
  linearVelocity = y;
  angularVelocity = 0;
  der(x) = dynamicRateScale * (linearVelocity);
  der(y) = 2 * (1 - y);
  der(heading) = 0;
end RagM260;
