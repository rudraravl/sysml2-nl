model RagM186
  Real reference;
  Real position(start=0, fixed=true);
  Real velocity;
  Real trackingError;
equation
  reference = cos(time);
  velocity = 3.6 * (reference - position);
  der(position) = velocity;
  trackingError = reference - position;
end RagM186;
