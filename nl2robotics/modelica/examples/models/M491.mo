model RagM491
  Real q1(start=0.2, fixed=true);
  Real q2(start=0.3, fixed=true);
  Real q3(start=0.1, fixed=true);
  Real x;
  Real y;
  Real radius;
equation
  der(q1) = 0.1;
  der(q2) = -0.05;
  der(q3) = 0.03;
  x = 0.66*cos(q1)+0.4*cos(q1+q2);
  y = 0.6*sin(q1)+0.4*sin(q1+q2);
  radius = sqrt(x^2 + y^2);
end RagM491;
