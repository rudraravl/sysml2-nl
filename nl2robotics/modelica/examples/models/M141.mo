model RagM141
  parameter Real target = 1.0;
  parameter Real inertia = 0.36;
  Real position(start=0, fixed=true);
  Real velocity(start=0, fixed=true);
  Real integralError(start=0, fixed=true);
  Real reference;
  Real torque;
equation
  reference = target;
  der(integralError) = if abs(torque) < 1.99 then reference - position else 0;
  torque = max(-2, min(2, 8 * (reference - position) + 2 * integralError));
  der(position) = velocity;
  inertia * der(velocity) = torque - 0.4 * velocity;
end RagM141;
