model RagM227
  parameter Real mass(unit="kg") = 3;
  parameter Real damping(unit="N.s/m") = 3.88;
  parameter Real force(unit="N") = 10;
  Real position(unit="m", start=0, fixed=true);
  Real velocity(unit="m/s", start=0, fixed=true);
equation
  der(position) = velocity;
  mass * der(velocity) = force - damping * velocity;
end RagM227;
