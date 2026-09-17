model RagM356
  Real x(start=0, fixed=true);
  Real y(start=0, fixed=true);
  Real heading(start=0, fixed=true);
  Real linearVelocity;
  Real angularVelocity;
equation
  linearVelocity = 0.515;
  angularVelocity = 0.2;
  der(x) = 0.5;
  der(y) = 0.3;
  der(heading) = angularVelocity;
end RagM356;
