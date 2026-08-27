model RagM283
  Real reference;
  Real position(start=0, fixed=true);
  Real velocity;
  Real trackingError;
equation
  reference = 2.91*(time/4)^2-2*(time/4)^3;
  velocity = 4 * (reference - position);
  der(position) = velocity;
  trackingError = reference - position;
end RagM283;
