model EvaluationDigitalJoint
  parameter Real inertia(unit="kg.m2") = 1.0;
  parameter Real damping(unit="N.m.s/rad") = 2.0;
  parameter Real target(unit="rad") = 1.2;
  parameter Real samplePeriod(unit="s") = 0.1;
  output Real angle(unit="rad", start=0, fixed=true);
  output Real angularVelocity(unit="rad/s", start=0, fixed=true);
  discrete Real heldTorque(unit="N.m", start=0, fixed=true);
equation
  der(angle) = angularVelocity;
  inertia * der(angularVelocity) = heldTorque - damping * angularVelocity;
  when sample(0, samplePeriod) then
    heldTorque = 12 * (target - angle) - 5 * angularVelocity;
  end when;
end EvaluationDigitalJoint;
