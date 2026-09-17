model ComponentFlexibleTransmission
  Modelica.Mechanics.Rotational.Sources.ConstantTorque drive(tau_constant=1);
  Modelica.Mechanics.Rotational.Components.Inertia motor(
    J=0.03, phi(start=0, fixed=true), w(start=0, fixed=true));
  Modelica.Mechanics.Rotational.Components.SpringDamper shaft(c=20, d=0.8);
  Modelica.Mechanics.Rotational.Components.Inertia joint(
    J=0.3, phi(start=0, fixed=true), w(start=0, fixed=true));
  Modelica.Mechanics.Rotational.Components.Damper loadDamping(d=0.1);
  Modelica.Mechanics.Rotational.Components.Fixed housing;
  Real motorAngle(unit="rad");
  Real jointAngle(unit="rad");
equation
  connect(drive.flange, motor.flange_a);
  connect(motor.flange_b, shaft.flange_a);
  connect(shaft.flange_b, joint.flange_a);
  connect(joint.flange_b, loadDamping.flange_a);
  connect(loadDamping.flange_b, housing.flange);
  motorAngle = motor.phi;
  jointAngle = joint.phi;
end ComponentFlexibleTransmission;
