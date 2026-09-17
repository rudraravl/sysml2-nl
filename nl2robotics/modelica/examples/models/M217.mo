model RagM217
  parameter Real targetHeading(unit="rad") = 1.0;
  parameter Real forwardSpeed(unit="m/s") = 0.485;
  parameter Real headingGain(unit="1/s") = 2.5;
  Real x(unit="m", start=0, fixed=true);
  Real y(unit="m", start=0, fixed=true);
  Real heading(unit="rad", start=0, fixed=true);
  Real turnRate(unit="rad/s");
equation
  turnRate = headingGain * (targetHeading - heading);
  der(x) = forwardSpeed * cos(heading);
  der(y) = forwardSpeed * sin(heading);
  der(heading) = turnRate;
end RagM217;
