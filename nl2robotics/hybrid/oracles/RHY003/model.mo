model PortableHorizontalCarriage
  parameter Real mass(unit="kg") = 3.0;
  parameter Real stiffness(unit="N/m") = 75.0;
  parameter Real damping(unit="N.s/m") = 30.0;
  parameter Real targetPosition(unit="m") = 0.4;
  output Real carriagePosition(unit="m", start=0, fixed=true);
  output Real carriageVelocity(unit="m/s", start=0, fixed=true);
equation
  der(carriagePosition) = carriageVelocity;
  mass * der(carriageVelocity) =
    stiffness * (targetPosition - carriagePosition) - damping * carriageVelocity;
end PortableHorizontalCarriage;
