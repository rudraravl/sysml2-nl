model RagM437
  parameter Real target = 3.0;
  parameter Real inertia = 0.44;
  Real position(start=0, fixed=true);
  Real velocity(start=0, fixed=true);
  Real integralError(start=0, fixed=true);
  Real reference;
  Real torque;
equation
  reference = target;
  der(integralError) = reference - velocity;
  torque = 2 * (reference - velocity) + 3 * integralError;
  der(position) = velocity;
  inertia * der(velocity) = torque - 0.4 * velocity;
end RagM437;
