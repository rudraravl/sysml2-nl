model RagM490
  Real reference;
  Real position(start=0, fixed=true);
  Real velocity;
  Real trackingError;
equation
  reference = if time < 2 then 0.5*time else if time < 3 then 1 else max(0,1-0.5*(time-3));
  velocity = 4.4 * (reference - position);
  der(position) = velocity;
  trackingError = reference - position;
end RagM490;
