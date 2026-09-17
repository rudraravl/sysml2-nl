model RagM463
  parameter Real dynamicRateScale = 1.1;
  Real trueSignal;
  Real measuredSignal(start=0, fixed=true);
  Real bias(start=0, fixed=true);
  Real error;
equation
  trueSignal = sin(time);
  der(bias) = dynamicRateScale * (0.002);
  der(measuredSignal) = (trueSignal + bias - measuredSignal) / 0.05;
  error = measuredSignal - trueSignal;
end RagM463;
