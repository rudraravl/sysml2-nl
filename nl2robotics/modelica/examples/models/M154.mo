model RagM154
  Real position(start=0, fixed=true);
  Real velocity(start=0, fixed=true);
  Real command;
equation
  command = 0.9 - (if position > 1 then 50*(position-1) else 0);
  der(position) = velocity;
  0.3 * der(velocity) = command - 0.5 * velocity;
end RagM154;
