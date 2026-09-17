model RagM155
  Real x(start=0, fixed=true);
  Real y(start=0, fixed=true);
  Real heading(start=0, fixed=true);
  Real linearVelocity;
  Real angularVelocity;
equation
  linearVelocity = 0.54;
  angularVelocity = 0.22;
  der(x) = linearVelocity * cos(heading);
  der(y) = linearVelocity * sin(heading);
  der(heading) = angularVelocity;
end RagM155;
