model RagM162
  parameter Real dynamicRateScale = 0.9;
  Real trueSignal;
  Real measuredSignal(start=0, fixed=true);
  Real bias(start=0, fixed=true);
  Real error;
equation
  trueSignal = sin(time);
  der(bias) = dynamicRateScale * (0);
  der(measuredSignal) = (trueSignal + 0.02 - measuredSignal) / 0.05;
  error = measuredSignal - trueSignal;
end RagM162;
