model EvaluationFlexibleJoint
  parameter Real motorInertia(unit="kg.m2") = 0.2;
  parameter Real loadInertia(unit="kg.m2") = 0.8;
  parameter Real stiffness(unit="N.m/rad") = 30;
  parameter Real transmissionDamping(unit="N.m.s/rad") = 2;
  parameter Real motorDamping(unit="N.m.s/rad") = 0.2;
  parameter Real appliedTorque(unit="N.m") = 1.0;
  output Real motorAngle(unit="rad", start=0, fixed=true);
  output Real jointAngle(unit="rad", start=0, fixed=true);
  Real motorVelocity(unit="rad/s", start=0, fixed=true);
  Real jointVelocity(unit="rad/s", start=0, fixed=true);
  Real transmissionTorque(unit="N.m");
equation
  transmissionTorque = stiffness * (motorAngle - jointAngle)
    + transmissionDamping * (motorVelocity - jointVelocity);
  der(motorAngle) = motorVelocity;
  der(jointAngle) = jointVelocity;
  motorInertia * der(motorVelocity) =
    appliedTorque - transmissionTorque - motorDamping * motorVelocity;
  loadInertia * der(jointVelocity) = transmissionTorque;
end EvaluationFlexibleJoint;
