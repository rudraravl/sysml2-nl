model RagM282
  Real reference;
  Real position(start=0, fixed=true);
  Real velocity;
  Real trackingError;
equation
  reference = if time < 1 then 0.5*time^2 else if time < 3 then time-0.5 else 2.5;
  velocity = 3.88 * (reference - position);
  der(position) = velocity;
  trackingError = reference - position;
end RagM282;
