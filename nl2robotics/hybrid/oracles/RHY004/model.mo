model PortableInspectionArm
  parameter Real inertia(unit="kg.m2") = 0.8;
  parameter Real stiffness(unit="N.m/rad") = 6.0;
  parameter Real damping(unit="N.m.s/rad") = 4.0;
  parameter Real targetAngle(unit="rad") = Modelica.Constants.pi / 4;
  Real angle(unit="rad", start=0, fixed=true);
  Real angularVelocity(unit="rad/s", start=0, fixed=true);
  output Real jointAngleDeg(unit="deg");
equation
  der(angle) = angularVelocity;
  inertia * der(angularVelocity) =
    stiffness * (targetAngle - angle) - damping * angularVelocity;
  jointAngleDeg = angle * 180 / Modelica.Constants.pi;
end PortableInspectionArm;
