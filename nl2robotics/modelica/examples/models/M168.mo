model RagM168
  parameter Real dynamicRateScale = 0.9;
  Real trueSignal;
  Real measuredSignal(start=0, fixed=true);
  Real bias(start=0, fixed=true);
  Real error;
equation
  trueSignal = cos(time);
  der(bias) = dynamicRateScale * (0);
  der(measuredSignal) = (cos(time) - measuredSignal) / 0.08;
  error = measuredSignal - trueSignal;
end RagM168;
