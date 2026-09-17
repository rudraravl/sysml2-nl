model RagM389
  Real reference;
  Real position(start=0, fixed=true);
  Real velocity;
  Real trackingError;
equation
  reference = 2.06*(10*(time/5)^3-15*(time/5)^4+6*(time/5)^5);
  velocity = 4 * (reference - position);
  der(position) = velocity;
  trackingError = reference - position;
end RagM389;
