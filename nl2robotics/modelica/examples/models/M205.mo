model RagM205
  parameter Real motorInertia(unit="kg.m2") = 0.002;
  parameter Real loadInertia(unit="kg.m2") = 0.4;
  parameter Real ratio = 40;
  parameter Real efficiency = 0.9;
  parameter Real motorTorque(unit="N.m") = 0.2;
  parameter Real damping(unit="N.m.s/rad") = 0.291;
  Real jointAngle(unit="rad", start=0, fixed=true);
  Real jointVelocity(unit="rad/s", start=0, fixed=true);
  Real outputTorque(unit="N.m");
equation
  outputTorque = ratio * efficiency * motorTorque;
  der(jointAngle) = jointVelocity;
  (loadInertia + motorInertia * ratio ^ 2) * der(jointVelocity) =
    outputTorque - damping * jointVelocity;
end RagM205;
