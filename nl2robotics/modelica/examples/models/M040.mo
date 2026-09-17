model CascadeServoController
  parameter Real target = 1.0;
  parameter Real inertia = 0.4;
  Real position(start=0, fixed=true);
  Real velocity(start=0, fixed=true);
  Real integralError(start=0, fixed=true);
  Real reference;
  Real torque;
equation
  reference = target;
  der(integralError) = 0;
  torque = 3 * (4 * (reference - position) - velocity);
  der(position) = velocity;
  inertia * der(velocity) = torque - 0.4 * velocity;
end CascadeServoController;
