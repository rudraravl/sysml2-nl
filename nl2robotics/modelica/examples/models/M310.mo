model RagM310
  parameter Real motorInertia(unit="kg.m2") = 0.03;
  parameter Real jointInertia(unit="kg.m2") = 0.3;
  parameter Real stiffness(unit="N.m/rad") = 20.6;
  parameter Real couplingDamping(unit="N.m.s/rad") = 0.8;
  parameter Real motorTorque(unit="N.m") = 1;
  Real motorAngle(unit="rad", start=0, fixed=true);
  Real motorVelocity(unit="rad/s", start=0, fixed=true);
  Real jointAngle(unit="rad", start=0, fixed=true);
  Real jointVelocity(unit="rad/s", start=0, fixed=true);
  Real couplingTorque(unit="N.m");
equation
  couplingTorque = stiffness * (motorAngle - jointAngle)
    + couplingDamping * (motorVelocity - jointVelocity);
  der(motorAngle) = motorVelocity;
  der(jointAngle) = jointVelocity;
  motorInertia * der(motorVelocity) = motorTorque - couplingTorque;
  jointInertia * der(jointVelocity) = couplingTorque;
end RagM310;
