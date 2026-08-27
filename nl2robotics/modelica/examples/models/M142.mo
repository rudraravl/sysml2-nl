model RagM142
  parameter Real target = 0.7;
  parameter Real inertia = 0.36;
  Real position(start=0, fixed=true);
  Real velocity(start=0, fixed=true);
  Real integralError(start=0, fixed=true);
  Real reference;
  Real torque;
equation
  reference = target;
  der(integralError) = 0;
  torque = 12 * (reference - position) - 4 * velocity + 2 * sin(position);
  der(position) = velocity;
  inertia * der(velocity) = torque - 0.4 * velocity - 2 * sin(position);
end RagM142;
