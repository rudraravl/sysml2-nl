model RagM270
  Real trueSignal;
  Real measuredSignal(start=0, fixed=true);
  Real bias(start=0, fixed=true);
  Real error;
equation
  trueSignal = 4.85 + sin(time);
  der(bias) = 0;
  der(measuredSignal) = (5 + sin(time) - measuredSignal) / 0.1;
  error = measuredSignal - trueSignal;
end RagM270;
