model RagM486
  Real reference;
  Real position(start=0, fixed=true);
  Real velocity;
  Real trackingError;
equation
  reference = cos(time);
  velocity = 4.4 * (reference - position);
  der(position) = velocity;
  trackingError = reference - position;
end RagM486;
