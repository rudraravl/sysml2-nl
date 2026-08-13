model ComplementaryFilter
  Real trueSignal;
  Real measuredSignal(start=0, fixed=true);
  Real bias(start=0, fixed=true);
  Real error;
equation
  trueSignal = sin(time);
  der(bias) = 0;
  der(measuredSignal) = (0.98 * trueSignal + 0.02 * sin(time) - measuredSignal) / 0.1;
  error = measuredSignal - trueSignal;
end ComplementaryFilter;
