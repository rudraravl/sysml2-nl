model RagM323
  Modelica.Blocks.Sources.Ramp requestedTorque(height=4, duration=1);
  Modelica.Blocks.Nonlinear.Limiter torqueLimiter(uMax=1.5, uMin=-1.5);
  Modelica.Mechanics.Rotational.Sources.Torque actuator;
  Modelica.Mechanics.Rotational.Components.Inertia joint(
    J=0.206, phi(start=0, fixed=true), w(start=0, fixed=true));
  Modelica.Mechanics.Rotational.Components.Damper damping(d=0.1);
  Modelica.Mechanics.Rotational.Components.Fixed housing;
  Real commandedTorque(unit="N.m");
  Real angularVelocity(unit="rad/s");
equation
  connect(requestedTorque.y, torqueLimiter.u);
  connect(torqueLimiter.y, actuator.tau);
  connect(actuator.flange, joint.flange_a);
  connect(joint.flange_b, damping.flange_a);
  connect(damping.flange_b, housing.flange);
  commandedTorque = torqueLimiter.y;
  angularVelocity = joint.w;
end RagM323;
