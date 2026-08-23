model PortableArmPlant
  parameter Real inertia(unit="kg.m2") = 0.5;
  parameter Real stiffness(unit="N.m/rad") = 8.0;
  parameter Real damping(unit="N.m.s/rad") = 2.0;
  parameter Real targetAngle(unit="rad") = Modelica.Constants.pi / 6;
  output Real jointAngle(unit="rad", start=0, fixed=true);
  output Real jointAngularVelocity(unit="rad/s", start=0, fixed=true);
equation
  der(jointAngle) = jointAngularVelocity;
  inertia * der(jointAngularVelocity) =
    stiffness * (targetAngle - jointAngle) - damping * jointAngularVelocity;
end PortableArmPlant;
