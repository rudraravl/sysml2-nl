model JointInterpolation
  Real reference;
  Real position(start=0, fixed=true);
  Real velocity;
  Real trackingError;
equation
  reference = 0.2 + (1.2-0.2)*min(time/3,1);
  velocity = 4 * (reference - position);
  der(position) = velocity;
  trackingError = reference - position;
end JointInterpolation;
