model RagM274
  parameter Real displacement(unit="m3/rad") = 1.94e-05;
  parameter Real pressureDifference(unit="Pa") = 6e5;
  Real angle(unit="rad", start=0, fixed=true);
  Real angularVelocity(unit="rad/s", start=0, fixed=true);
  Real flowRate(unit="m3/s");
  Real torque(unit="N.m");
equation
  torque = displacement*pressureDifference;
  flowRate = displacement*angularVelocity+1e-11*pressureDifference;
  der(angle) = angularVelocity;
  0.2*der(angularVelocity) = torque-0.5*angularVelocity;
end RagM274;
