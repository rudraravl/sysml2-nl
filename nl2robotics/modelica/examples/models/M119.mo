model RagM119
  Modelica.Mechanics.Rotational.Sources.ConstantTorque drive(tau_constant=1);
  Modelica.Mechanics.Rotational.Components.Inertia joint(
    J=0.45, phi(start=0, fixed=true), w(start=0, fixed=true));
  Modelica.Mechanics.Rotational.Components.Damper damping(d=0.1);
  Modelica.Mechanics.Rotational.Components.Fixed housing;
  Real angle(unit="rad");
  Real angularVelocity(unit="rad/s");
equation
  connect(drive.flange, joint.flange_a);
  connect(joint.flange_b, damping.flange_a);
  connect(damping.flange_b, housing.flange);
  angle = joint.phi;
  angularVelocity = joint.w;
end RagM119;
