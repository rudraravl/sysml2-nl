model RagM238
  parameter Real target = 1.2;
  parameter Real inertia = 0.388;
  Real position(start=0, fixed=true);
  Real velocity(start=0, fixed=true);
  Real integralError(start=0, fixed=true);
  Real reference;
  Real torque;
equation
  reference = target;
  der(integralError) = reference - position;
  torque = 10 * (reference - position) + 4 * integralError - 3 * velocity;
  der(position) = velocity;
  inertia * der(velocity) = torque - 0.4 * velocity;
end RagM238;
