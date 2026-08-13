model DualChamberCylinder
  parameter Real area(unit="m2") = 1e-4;
  Real pressureA(unit="Pa", start=5e5, fixed=true);
  Real pressureB(unit="Pa", start=1e5, fixed=true);
  Real position(unit="m", start=0, fixed=true);
  Real velocity(unit="m/s", start=0, fixed=true);
equation
  der(pressureA) = -2e8*area*velocity;
  der(pressureB) = 2e8*area*velocity;
  der(position) = velocity;
  15*der(velocity) = area*(pressureA-pressureB)-20*velocity;
end DualChamberCylinder;
