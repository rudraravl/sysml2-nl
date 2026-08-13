model SineReference
  Real reference;
  Real position(start=0, fixed=true);
  Real velocity;
  Real trackingError;
equation
  reference = sin(time);
  velocity = 4 * (reference - position);
  der(position) = velocity;
  trackingError = reference - position;
end SineReference;
