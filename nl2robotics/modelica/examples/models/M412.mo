model RagM412
  parameter Real fingerMass(unit="kg") = 0.2;
  parameter Real damping(unit="N.s/m") = 4.4;
  parameter Real commandedForce(unit="N") = 3;
  parameter Real maximumOpening(unit="m") = 0.08;
  Real opening(unit="m", start=0.08, fixed=true);
  Real openingVelocity(unit="m/s", start=0, fixed=true);
  Real actuatorForce(unit="N");
equation
  actuatorForce = if opening > 0 then -commandedForce else 0;
  der(opening) = openingVelocity;
  fingerMass * der(openingVelocity) = actuatorForce - damping * openingVelocity;
end RagM412;
