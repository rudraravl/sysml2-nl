model RagM461
  parameter Real dynamicRateScale = 1.1;
  Real trueSignal;
  Real measuredSignal(start=0, fixed=true);
  Real bias(start=0, fixed=true);
  Real error;
equation
  trueSignal = sin(time);
  der(bias) = dynamicRateScale * (0);
  der(measuredSignal) = (trueSignal - measuredSignal) / 0.1;
  error = measuredSignal - trueSignal;
end RagM461;
