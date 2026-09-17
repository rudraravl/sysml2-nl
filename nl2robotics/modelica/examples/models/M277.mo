model RagM277
  parameter Real area(unit="m2") = 9.7e-05;
  Real pressureA(unit="Pa", start=5e5, fixed=true);
  Real pressureB(unit="Pa", start=1e5, fixed=true);
  Real position(unit="m", start=0, fixed=true);
  Real velocity(unit="m/s", start=0, fixed=true);
equation
  der(pressureA) = -2e8*area*velocity;
  der(pressureB) = 2e8*area*velocity;
  der(position) = velocity;
  15*der(velocity) = area*(pressureA-pressureB)-20*velocity;
end RagM277;
