model RagM311
  parameter Real inertia1(unit="kg.m2") = 0.5;
  parameter Real inertia2(unit="kg.m2") = 0.25;
  parameter Real damping(unit="N.m.s/rad") = 0.412;
  parameter Real coupling(unit="N.m/rad") = 1.5;
  Real angle1(unit="rad", start=0, fixed=true);
  Real velocity1(unit="rad/s", start=0, fixed=true);
  Real angle2(unit="rad", start=0, fixed=true);
  Real velocity2(unit="rad/s", start=0, fixed=true);
equation
  der(angle1) = velocity1;
  der(angle2) = velocity2;
  inertia1 * der(velocity1) = 1 - damping * velocity1
    - coupling * (angle1 - angle2);
  inertia2 * der(velocity2) = -damping * velocity2
    + coupling * (angle1 - angle2);
end RagM311;
