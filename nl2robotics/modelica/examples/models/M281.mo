model RagM281
  Real reference;
  Real position(start=0, fixed=true);
  Real velocity;
  Real trackingError;
equation
  reference = sin(time);
  velocity = 3.88 * (reference - position);
  der(position) = velocity;
  trackingError = reference - position;
end RagM281;
