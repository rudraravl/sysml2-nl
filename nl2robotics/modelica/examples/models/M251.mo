model RagM251
  parameter Real dynamicRateScale = 0.97;
  Real position(start=0, fixed=true);
  Real velocity(start=0, fixed=true);
  Real command;
equation
  command = if velocity > 2 then -3 else 1;
  der(position) = dynamicRateScale * (velocity);
  0.3 * der(velocity) = command - 0.5 * velocity;
end RagM251;
