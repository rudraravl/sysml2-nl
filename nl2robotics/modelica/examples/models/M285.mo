model RagM285
  Real reference;
  Real position(start=0, fixed=true);
  Real velocity;
  Real trackingError;
equation
  reference = if time < 2 then 0.5*time else 1-0.25*(time-2);
  velocity = 3.88 * (reference - position);
  der(position) = velocity;
  trackingError = reference - position;
end RagM285;
