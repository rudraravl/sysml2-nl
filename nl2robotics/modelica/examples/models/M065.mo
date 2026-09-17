model SampledEncoder
  Real trueSignal;
  Real measuredSignal(start=0, fixed=true);
  Real bias(start=0, fixed=true);
  Real error;
equation
  trueSignal = sin(time);
  der(bias) = 0;
  der(measuredSignal) = (trueSignal - measuredSignal) / 0.02;
  error = measuredSignal - trueSignal;
end SampledEncoder;
