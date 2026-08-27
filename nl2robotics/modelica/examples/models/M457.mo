model RagM457
  Real x(start=0, fixed=true);
  Real y(start=0, fixed=true);
  Real heading(start=0, fixed=true);
  Real linearVelocity;
  Real angularVelocity;
equation
  linearVelocity = 0.66;
  angularVelocity = 0.31;
  der(x) = linearVelocity * cos(heading);
  der(y) = linearVelocity * sin(heading);
  der(heading) = angularVelocity;
end RagM457;
