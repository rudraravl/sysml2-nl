model HydraulicGripper
  parameter Real pressure(unit="Pa") = 4e5;
  parameter Real area(unit="m2") = 2e-5;
  Real opening(unit="m", start=0.08, fixed=true);
  Real openingVelocity(unit="m/s", start=0, fixed=true);
  Real stopForce(unit="N");
equation
  stopForce = if opening < 0 then -500*opening else 0;
  der(opening) = openingVelocity;
  0.5*der(openingVelocity) = -pressure*area-8*openingVelocity+stopForce;
end HydraulicGripper;
