model RagM450
  parameter Real dynamicRateScale = 1.1;
  Real position(start=0, fixed=true);
  Real velocity(start=0, fixed=true);
  Real command;
equation
  command = (if abs(1-position) > 0.2 then 10 else 4) * (1-position) - 3*velocity;
  der(position) = dynamicRateScale * (velocity);
  0.3 * der(velocity) = command - 0.5 * velocity;
end RagM450;
