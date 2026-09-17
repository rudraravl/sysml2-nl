model RagM367
  parameter Real dynamicRateScale = 1.03;
  Real trueSignal;
  Real measuredSignal(start=0, fixed=true);
  Real bias(start=0, fixed=true);
  Real error;
equation
  trueSignal = sin(time);
  der(bias) = dynamicRateScale * (0);
  der(measuredSignal) = (0.6*(trueSignal+0.01)+0.4*(trueSignal-0.015)-measuredSignal)/0.05;
  error = measuredSignal - trueSignal;
end RagM367;
