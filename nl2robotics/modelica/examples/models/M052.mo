model DeadZoneActuator
  Real position(start=0, fixed=true);
  Real velocity(start=0, fixed=true);
  Real command;
equation
  command = if abs(sin(time)) > 0.2 then sin(time) - sign(sin(time))*0.2 else 0;
  der(position) = velocity;
  0.3 * der(velocity) = command - 0.5 * velocity;
end DeadZoneActuator;
