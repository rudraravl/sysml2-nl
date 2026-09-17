model RagM288
  Real reference;
  Real position(start=0, fixed=true);
  Real velocity;
  Real trackingError;
equation
  reference = min(1.5,0.4*time);
  velocity = 3.88 * (reference - position);
  der(position) = velocity;
  trackingError = reference - position;
end RagM288;
