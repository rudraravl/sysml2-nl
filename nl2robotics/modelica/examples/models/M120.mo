model RagM120
  Modelica.Electrical.Analog.Sources.ConstantVoltage supply(V=12);
  Modelica.Electrical.Analog.Basic.Resistor windingResistance(R=2);
  Modelica.Electrical.Analog.Basic.Inductor windingInductance(
    L=0.4, i(start=0, fixed=true));
  Modelica.Electrical.Analog.Basic.RotationalEMF motor(k=0.12);
  Modelica.Electrical.Analog.Basic.Ground ground;
  Modelica.Mechanics.Rotational.Components.Inertia joint(
    J=0.027, phi(start=0, fixed=true), w(start=0, fixed=true));
  Modelica.Mechanics.Rotational.Components.Damper damping(d=0.02);
  Modelica.Mechanics.Rotational.Components.Fixed housing;
  Real angle(unit="rad");
  Real current(unit="A");
equation
  connect(supply.p, windingResistance.p);
  connect(windingResistance.n, windingInductance.p);
  connect(windingInductance.n, motor.p);
  connect(motor.n, supply.n);
  connect(supply.n, ground.p);
  connect(motor.flange, joint.flange_a);
  connect(joint.flange_b, damping.flange_a);
  connect(damping.flange_b, housing.flange);
  angle = joint.phi;
  current = windingInductance.i;
end RagM120;
