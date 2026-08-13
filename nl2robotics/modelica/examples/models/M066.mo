model RateLimitedSensor
  Real trueSignal;
  Real measuredSignal(start=0, fixed=true);
  Real bias(start=0, fixed=true);
  Real error;
equation
  trueSignal = sin(time);
  der(bias) = 0;
  der(measuredSignal) = max(-1, min(1, (trueSignal - measuredSignal) / 0.1));
  error = measuredSignal - trueSignal;
end RateLimitedSensor;
