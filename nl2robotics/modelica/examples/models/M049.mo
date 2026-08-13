model EmergencyStopJoint
  Real position(start=0, fixed=true);
  Real velocity(start=0, fixed=true);
  Real command;
equation
  command = if time < 2 then 1 else -4 * velocity;
  der(position) = velocity;
  0.3 * der(velocity) = command - 0.5 * velocity;
end EmergencyStopJoint;
