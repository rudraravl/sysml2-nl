model RagM158
  Real x(start=0, fixed=true);
  Real y(start=0, fixed=true);
  Real heading(start=0, fixed=true);
  Real linearVelocity;
  Real angularVelocity;
equation
  linearVelocity = 0;
  angularVelocity = 4.5 * (0.4 - heading) - 2 * der(heading);
  der(x) = 0;
  der(y) = 0;
  der(heading) = angularVelocity;
end RagM158;
