model ComponentPositionServo
  Modelica.Blocks.Sources.Step reference(height=1, startTime=0.1);
  Modelica.Blocks.Math.Feedback error;
  Modelica.Blocks.Math.Gain proportionalGain(k=6);
  Modelica.Mechanics.Rotational.Sources.Torque actuator;
  Modelica.Mechanics.Rotational.Components.Inertia joint(
    J=0.5, phi(start=0, fixed=true), w(start=0, fixed=true));
  Modelica.Mechanics.Rotational.Components.Damper damping(d=1.2);
  Modelica.Mechanics.Rotational.Components.Fixed housing;
  Modelica.Mechanics.Rotational.Sensors.AngleSensor angleSensor;
  Real angle(unit="rad");
equation
  connect(reference.y, error.u1);
  connect(angleSensor.phi, error.u2);
  connect(error.y, proportionalGain.u);
  connect(proportionalGain.y, actuator.tau);
  connect(actuator.flange, joint.flange_a);
  connect(joint.flange_b, damping.flange_a);
  connect(damping.flange_b, housing.flange);
  connect(angleSensor.flange, joint.flange_a);
  angle = angleSensor.phi;
end ComponentPositionServo;
