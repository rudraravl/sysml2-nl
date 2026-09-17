model PortableLiftPlant
  parameter Real mass(unit="kg") = 5.0;
  parameter Real stiffness(unit="N/m") = 100.0;
  parameter Real damping(unit="N.s/m") = 20.0;
  parameter Real targetPosition(unit="m") = 0.6;
  output Real liftPosition(unit="m", start=0, fixed=true);
  output Real liftVelocity(unit="m/s", start=0, fixed=true);
equation
  der(liftPosition) = liftVelocity;
  mass * der(liftVelocity) =
    stiffness * (targetPosition - liftPosition) - damping * liftVelocity;
end PortableLiftPlant;
