model RagM415
  parameter Real samplePeriod(unit="s") = 0.05;
  parameter Real targetAngle(unit="rad") = 1;
  parameter Real inertia(unit="kg.m2") = 0.44;
  parameter Real damping(unit="N.m.s/rad") = 0.8;
  parameter Real gain(unit="N.m/rad") = 5;
  Real angle(unit="rad", start=0, fixed=true);
  Real angularVelocity(unit="rad/s", start=0, fixed=true);
  discrete Real torqueCommand(unit="N.m", start=0, fixed=true);
equation
  when sample(0, samplePeriod) then
    torqueCommand = gain * (targetAngle - angle);
  end when;
  der(angle) = angularVelocity;
  inertia * der(angularVelocity) = torqueCommand - damping * angularVelocity;
end RagM415;
