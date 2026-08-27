model RagM339
  parameter Real target = 0.8;
  parameter Real inertia = 0.412;
  Real position(start=0, fixed=true);
  Real velocity(start=0, fixed=true);
  Real integralError(start=0, fixed=true);
  Real reference;
  Real torque;
equation
  reference = 0.8 * (1 - exp(-time));
  der(integralError) = 0;
  torque = 10 * (reference - position) - 3 * velocity + 0.8 * exp(-time);
  der(position) = velocity;
  inertia * der(velocity) = torque - 0.4 * velocity;
end RagM339;
