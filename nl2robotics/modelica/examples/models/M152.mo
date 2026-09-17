model RagM152
  parameter Real dynamicRateScale = 0.9;
  Real position(start=0, fixed=true);
  Real velocity(start=0, fixed=true);
  Real command;
equation
  command = if abs(sin(time)) > 0.2 then sin(time) - sign(sin(time))*0.2 else 0;
  der(position) = dynamicRateScale * (velocity);
  0.3 * der(velocity) = command - 0.5 * velocity;
end RagM152;
