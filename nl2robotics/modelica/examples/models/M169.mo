model RagM169
  parameter Real dynamicRateScale = 0.9;
  Real trueSignal;
  Real measuredSignal(start=0, fixed=true);
  Real bias(start=0, fixed=true);
  Real error;
equation
  trueSignal = max(0, 2 - 0.3*time);
  der(bias) = dynamicRateScale * (0);
  der(measuredSignal) = (max(0, 2 - 0.3*time) - measuredSignal) / 0.05;
  error = measuredSignal - trueSignal;
end RagM169;
