model RagM484
  Real reference;
  Real position(start=0, fixed=true);
  Real velocity;
  Real trackingError;
equation
  reference = 11*(time/4)^3-15*(time/4)^4+6*(time/4)^5;
  velocity = 4 * (reference - position);
  der(position) = velocity;
  trackingError = reference - position;
end RagM484;
