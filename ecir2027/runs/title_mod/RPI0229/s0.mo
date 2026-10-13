model AssemblyArmCarryA
  "Fixed-base 4-DOF articulated manipulator with computed-torque control"
  import Modelica;
  import Modelica.Units.SI;

  // === Link and mass parameters ===
  parameter SI.Length L1 = 0.50 "Link 1 length [m]";
  parameter SI.Length L2 = 0.40 "Link 2 length [m]";
  parameter SI.Length L3 = 0.28 "Link 3 length [m]";
  parameter SI.Length L4 = 0.16 "Link 4 length [m]";
  parameter SI.Mass m1 = 7 "Link 1 mass [kg]";
  parameter SI.Mass m2 = 5 "Link 2 mass [kg]";
  parameter SI.Mass m3 = 3 "Link 3 mass [kg]";
  parameter SI.Mass m4 = 1 "Link 4 tool mass [kg]";
  parameter SI.Mass mPayload = 6 "Payload disturbance mass [kg]";

  // === Control parameters ===
  parameter SI.Torque tauMax = 79.2 "Command magnitude limit [N.m]";
  parameter SI.Force wristForceLimit = 60 "Wrist force limit [N]";
  parameter Real Kp[4] = {300, 250, 180, 80} "Position feedback gains";
  parameter Real Kd[4] = {25, 22, 15, 8} "Velocity feedback gains";
  parameter Real Kf = 0.5 "Wrist-force correction gain";
  parameter SI.Time tauForceFilter = 0.01 "Wrist force filter time constant [s]";

  // === Scenario parameters ===
  parameter SI.Acceleration g = 9.81 "Gravitational acceleration [m/s^2]";
  parameter SI.Time tEnd = 8 "Scenario duration [s]";
  parameter SI.Time tDistStart = tEnd/3 "Disturbance start [s]";
  parameter SI.Time tDistEnd = 2*tEnd/3 "Disturbance end [s]";
  parameter SI.Time tRamp = 4.0 "Trajectory ramp completion [s]";

  // === Trajectory parameters ===
  parameter SI.Angle q_start[4] = {0, 0.3, 0.5, 0} "Initial joint angles [rad]";
  parameter SI.Angle q_end[4] = {0.6, -0.2, 0.9, 0} "Final joint angles [rad]";

  // === Collision parameters ===
  parameter SI.Position tableHeight = 0.40 "Table top height [m]";
  parameter SI.Length tableLength = 0.60 "Table length [m]";
  parameter SI.Length tableWidth = 0.40 "Table width [m]";
  parameter SI.Position tableCenterX = 0.50 "Table center X [m]";
  parameter Real kCollision = 8000 "Collision stiffness [N/m]";

  // === Observable outputs ===
  output SI.Angle q[4] "Joint angles [rad]";
  output SI.AngularVelocity qd[4] "Joint velocities [rad/s]";
  output SI.Torque tau[4] "Saturated joint torques [N.m]";
  output SI.Force wristForceMag "Wrist force magnitude [N]";
  output Real trackingError "Primary tracking error [rad-or-m]";

  // === Internal variables ===
  SI.Torque tau_raw[4] "Unsaturated torques [N.m]";
  SI.Angle q_des[4] "Desired joint angles [rad]";
  SI.AngularVelocity qd_des[4] "Desired joint velocities [rad/s]";
  Real e_pos[4] "Position errors [rad]";
  Real e_vel[4] "Velocity errors [rad/s]";
  SI.Force F_payload "Payload disturbance force [N]";
  SI.Position eePos[3] "End-effector position [m]";
  Real F_ext[3] "Collision force [N]";
  Boolean payloadRetained "Payload retention flag";
  Real tau_grav[4] "Gravity compensation [N.m]";
  Real forceCorr[4] "Bounded wrist-force correction [N.m]";
  Real sTraj "Trajectory parameter";
  Real sTrajDot "Trajectory parameter derivative";
  Boolean inDisturbance "Disturbance active";
  Real wristForceRaw[3] "Raw wrist force [N]";
  Real wristForceFilt[3](each start=0.0, each fixed=true) "Filtered wrist force [N]";
  SI.Force wristForceMagFilt "Filtered wrist force magnitude [N]";

  // === Multibody world ===
  inner Modelica.Mechanics.MultiBody.World world(g=g, n={0,0,-1})
    annotation(Placement(transformation(extent={{-80,0},{-60,20}})));

  Modelica.Mechanics.MultiBody.Parts.Fixed base
    annotation(Placement(transformation(extent={{-50,0},{-30,20}})));

  // === Joint 1: Z axis ===
  Modelica.Mechanics.MultiBody.Joints.Revolute j1(
    n={0,0,1}, useAxisFlange=true,
    phi(fixed=true, start=q_start[1]), w(fixed=true, start=0))
    annotation(Placement(transformation(extent={{-20,0},{0,20}})));

  Modelica.Mechanics.MultiBody.Parts.BodyBox l1(
    r={0,0,L1}, width=0.06, height=0.06, widthDirection={0,1,0},
    density=m1/(L1*0.06*0.06))
    annotation(Placement(transformation(extent={{10,0},{30,20}})));

  // === Joint 2: Y axis ===
  Modelica.Mechanics.MultiBody.Joints.Revolute j2(
    n={0,1,0}, useAxisFlange=true,
    phi(fixed=true, start=q_start[2]), w(fixed=true, start=0))
    annotation(Placement(transformation(extent={{40,0},{60,20}})));

  Modelica.Mechanics.MultiBody.Parts.BodyBox l2(
    r={0,L2,0}, width=0.05, height=0.05, widthDirection={0,0,1},
    density=m2/(L2*0.05*0.05))
    annotation(Placement(transformation(extent={{70,0},{90,20}})));

  // === Joint 3: Y axis ===
  Modelica.Mechanics.MultiBody.Joints.Revolute j3(
    n={0,1,0}, useAxisFlange=true,
    phi(fixed=true, start=q_start[3]), w(fixed=true, start=0))
    annotation(Placement(transformation(extent={{100,0},{120,20}})));

  Modelica.Mechanics.MultiBody.Parts.BodyBox l3(
    r={0,L3,0}, width=0.04, height=0.04, widthDirection={0,0,1},
    density=m3/(L3*0.04*0.04))
    annotation(Placement(transformation(extent={{130,0},{150,20}})));

  // === Wrist wrench sensor (six-axis: force + torque) ===
  Modelica.Mechanics.MultiBody.Sensors.CutForce wristSensor(
    resolveInFrame=Modelica.Mechanics.MultiBody.Types.ResolveInFrameA.world)
    annotation(Placement(transformation(extent={{160,0},{180,20}})));

  // === Joint 4: X axis ===
  Modelica.Mechanics.MultiBody.Joints.Revolute j4(
    n={1,0,0}, useAxisFlange=true,
    phi(fixed=true, start=q_start[4]), w(fixed=true, start=0))
    annotation(Placement(transformation(extent={{190,0},{210,20}})));

  Modelica.Mechanics.MultiBody.Parts.BodyBox l4(
    r={0,L4,0}, width=0.03, height=0.03, widthDirection={0,0,1},
    density=m4/(L4*0.03*0.03))
    annotation(Placement(transformation(extent={{220,0},{240,20}})));

  // === End-effector position sensor ===
  Modelica.Mechanics.MultiBody.Sensors.AbsolutePosition eePosSensor
    annotation(Placement(transformation(extent={{250,0},{270,20}})));

  // === External force (payload disturbance + collision) ===
  Modelica.Mechanics.MultiBody.Forces.WorldForce extForce
    annotation(Placement(transformation(extent={{280,0},{300,20}})));

  // === Torque actuators ===
  Modelica.Mechanics.Rotational.Sources.Torque act1
    annotation(Placement(transformation(extent={{-20,30},{0,50}})));
  Modelica.Mechanics.Rotational.Sources.Torque act2
    annotation(Placement(transformation(extent={{40,30},{60,50}})));
  Modelica.Mechanics.Rotational.Sources.Torque act3
    annotation(Placement(transformation(extent={{100,30},{120,50}})));
  Modelica.Mechanics.Rotational.Sources.Torque act4
    annotation(Placement(transformation(extent={{190,30},{210,50}})));

  // === Fixed supports for joint reaction ===
  Modelica.Mechanics.Rotational.Components.Fixed sup1
    annotation(Placement(transformation(extent={{-20,60},{0,80}})));
  Modelica.Mechanics.Rotational.Components.Fixed sup2
    annotation(Placement(transformation(extent={{40,60},{60,80}})));
  Modelica.Mechanics.Rotational.Components.Fixed sup3
    annotation(Placement(transformation(extent={{100,60},{120,80}})));
  Modelica.Mechanics.Rotational.Components.Fixed sup4
    annotation(Placement(transformation(extent={{190,60},{210,80}})));

  // === Joint encoders ===
  Modelica.Mechanics.Rotational.Sensors.AngleSensor ang1
    annotation(Placement(transformation(extent={{-20,-30},{0,-10}})));
  Modelica.Mechanics.Rotational.Sensors.AngleSensor ang2
    annotation(Placement(transformation(extent={{40,-30},{60,-10}})));
  Modelica.Mechanics.Rotational.Sensors.AngleSensor ang3
    annotation(Placement(transformation(extent={{100,-30},{120,-10}})));
  Modelica.Mechanics.Rotational.Sensors.AngleSensor ang4
    annotation(Placement(transformation(extent={{190,-30},{210,-10}})));

  // === Velocity sensors ===
  Modelica.Mechanics.Rotational.Sensors.SpeedSensor spd1
    annotation(Placement(transformation(extent={{-20,-60},{0,-40}})));
  Modelica.Mechanics.Rotational.Sensors.SpeedSensor spd2
    annotation(Placement(transformation(extent={{40,-60},{60,-40}})));
  Modelica.Mechanics.Rotational.Sensors.SpeedSensor spd3
    annotation(Placement(transformation(extent={{100,-60},{120,-40}})));
  Modelica.Mechanics.Rotational.Sensors.SpeedSensor spd4
    annotation(Placement(transformation(extent={{190,-60},{210,-40}})));

  // === Rigid workcell floor ===
  Modelica.Mechanics.MultiBody.Visualizers.FixedShape floor(
    r={0,0,-0.01}, lengthDirection={1,0,0}, widthDirection={0,1,0},
    length=3, width=3, height=0.02, shapeType="box", color={100,100,100})
    annotation(Placement(transformation(extent={{-80,-80},{-60,-60}})));

  // === Fixed table with collision ===
  Modelica.Mechanics.MultiBody.Visualizers.FixedShape table(
    r={tableCenterX,0,tableHeight/2}, lengthDirection={1,0,0}, widthDirection={0,1,0},
    length=tableLength, width=tableWidth, height=tableHeight, shapeType="box",
    color={150,100,50})
    annotation(Placement(transformation(extent={{-50,-80},{-30,-60}})));

  // === RealExpression blocks for driving actuator inputs ===
  Modelica.Blocks.Sources.RealExpression tauCmd1(y=tau[1])
    annotation(Placement(transformation(extent={{-50,30},{-30,50}})));
  Modelica.Blocks.Sources.RealExpression tauCmd2(y=tau[2])
    annotation(Placement(transformation(extent={{10,30},{30,50}})));
  Modelica.Blocks.Sources.RealExpression tauCmd3(y=tau[3])
    annotation(Placement(transformation(extent={{70,30},{90,50}})));
  Modelica.Blocks.Sources.RealExpression tauCmd4(y=tau[4])
    annotation(Placement(transformation(extent={{160,30},{180,50}})));

  // === RealExpression blocks for driving external force ===
  Modelica.Blocks.Sources.RealExpression extFx(y=F_ext[1])
    annotation(Placement(transformation(extent={{250,-30},{270,-10}})));
  Modelica.Blocks.Sources.RealExpression extFy(y=F_ext[2])
    annotation(Placement(transformation(extent={{250,-50},{270,-30}})));
  Modelica.Blocks.Sources.RealExpression extFz(y=-F_payload + F_ext[3])
    annotation(Placement(transformation(extent={{250,-70},{270,-50}})));

equation
  // === Kinematic chain ===
  connect(world.frame_b, base.frame_b);
  connect(base.frame_b, j1.frame_a);
  connect(j1.frame_b, l1.frame_a);
  connect(l1.frame_b, j2.frame_a);
  connect(j2.frame_b, l2.frame_a);
  connect(l2.frame_b, j3.frame_a);
  connect(j3.frame_b, l3.frame_a);
  connect(l3.frame_b, wristSensor.frame_a);
  connect(wristSensor.frame_b, j4.frame_a);
  connect(j4.frame_b, l4.frame_a);
  connect(l4.frame_b, eePosSensor.frame_a);
  connect(eePosSensor.frame_b, extForce.frame_b);

  // === Actuators to joint axes ===
  connect(tauCmd1.y, act1.tau);
  connect(tauCmd2.y, act2.tau);
  connect(tauCmd3.y, act3.tau);
  connect(tauCmd4.y, act4.tau);
  connect(act1.flange, j1.axis);
  connect(act2.flange, j2.axis);
  connect(act3.flange, j3.axis);
  connect(act4.flange, j4.axis);

  // === Fixed supports for reaction torque ===
  connect(sup1.flange, j1.support);
  connect(sup2.flange, j2.support);
  connect(sup3.flange, j3.support);
  connect(sup4.flange, j4.support);

  // === Joint encoders and velocity sensors ===
  connect(j1.axis, ang1.flange);
  connect(j2.axis, ang2.flange);
  connect(j3.axis, ang3.flange);
  connect(j4.axis, ang4.flange);
  connect(j1.axis, spd1.flange);
  connect(j2.axis, spd2.flange);
  connect(j3.axis, spd3.flange);
  connect(j4.axis, spd4.flange);

  // === External force input ===
  connect(extFx.y, extForce.force[1]);
  connect(extFy.y, extForce.force[2]);
  connect(extFz.y, extForce.force[3]);

  // === Floor and table visualization ===
  connect(floor.frame_a, world.frame_b);
  connect(table.frame_a, world.frame_b);

  // === Sensor readings ===
  q[1] = ang1.phi;
  q[2] = ang2.phi;
  q[3] = ang3.phi;
  q[4] = ang4.phi;
  qd[1] = spd1.w;
  qd[2] = spd2.w;
  qd[3] = spd3.w;
  qd[4] = spd4.w;
  eePos[1] = eePosSensor.r[1];
  eePos[2] = eePosSensor.r[2];
  eePos[3] = eePosSensor.r[3];

  // === Wrist wrench sensor with safe norm ===
  wristForceRaw[1] = wristSensor.force[1];
  wristForceRaw[2] = wristSensor.force[2];
  wristForceRaw[3] = wristSensor.force[3];
  wristForceMag = sqrt(wristForceRaw[1]^2 + wristForceRaw[2]^2 + wristForceRaw[3]^2 + 1e-12);

  // === Filtered wrist force (breaks algebraic loop) ===
  der(wristForceFilt[1]) = (wristForceRaw[1] - wristForceFilt[1]) / tauForceFilter;
  der(wristForceFilt[2]) = (wristForceRaw[2] - wristForceFilt[2]) / tauForceFilter;
  der(wristForceFilt[3]) = (wristForceRaw[3] - wristForceFilt[3]) / tauForceFilter;
  wristForceMagFilt = sqrt(wristForceFilt[1]^2 + wristForceFilt[2]^2 + wristForceFilt[3]^2 + 1e-12);

  // === Desired trajectory: 5th order polynomial, completes at tRamp ===
  if time <= tRamp then
    sTraj = 10*(time/tRamp)^3 - 15*(time/tRamp)^4 + 6*(time/tRamp)^5;
    sTrajDot = (30*(time/tRamp)^2 - 60*(time/tRamp)^3 + 30*(time/tRamp)^4) / tRamp;
  else
    sTraj = 1.0;
    sTrajDot = 0.0;
  end if;

  for i in 1:4 loop
    q_des[i] = q_start[i] + (q_end[i] - q_start[i]) * sTraj;
    qd_des[i] = (q_end[i] - q_start[i]) * sTrajDot;
  end for;

  // === Control errors ===
  for i in 1:4 loop
    e_pos[i] = q_des[i] - q[i];
    e_vel[i] = qd_des[i] - qd[i];
  end for;

  // === Payload disturbance (middle third of scenario) ===
  inDisturbance = time >= tDistStart and time <= tDistEnd;
  if inDisturbance then
    F_payload = mPayload * g;
  else
    F_payload = 0.0;
  end if;

  // === Collision detection: floor and table (penalty-based) ===
  if eePos[3] < 0.0 then
    // Floor penetration: upward penalty force
    F_ext[1] = 0.0;
    F_ext[2] = 0.0;
    F_ext[3] = kCollision * (-eePos[3]);
  elseif (eePos[3] < tableHeight) and
         (abs(eePos[1] - tableCenterX) < tableLength/2) and
         (abs(eePos[2]) < tableWidth/2) then
    // Table penetration: upward penalty force
    F_ext[1] = 0.0;
    F_ext[2] = 0.0;
    F_ext[3] = kCollision * (tableHeight - eePos[3]);
  else
    F_ext[1] = 0.0;
    F_ext[2] = 0.0;
    F_ext[3] = 0.0;
  end if;

  // === Gravity compensation (simplified computed-torque feedforward) ===
  tau_grav[1] = 0.0;  // Z-axis: no gravity torque
  tau_grav[2] = (m2*L2/2 + (m3+m4)*L2) * g * Modelica.Math.cos(j2.phi)
              + (m3*L3/2 + m4*L3) * g * Modelica.Math.cos(j2.phi + j3.phi)
              + m4*L4 * g * Modelica.Math.cos(j2.phi + j3.phi);
  tau_grav[3] = (m3*L3/2 + m4*L3) * g * Modelica.Math.cos(j3.phi)
              + m4*L4 * g * Modelica.Math.cos(j3.phi);
  tau_grav[4] = 0.0;  // X-axis roll: minimal gravity torque

  // === Bounded wrist-force correction ===
  for i in 1:4 loop
    forceCorr[i] = Kf * wristForceFilt[min(i, 3)] / max(wristForceMagFilt, 1.0);
  end for;

  // === Computed-torque control with saturation ===
  for i in 1:4 loop
    tau_raw[i] = tau_grav[i] + Kp[i] * e_pos[i] + Kd[i] * e_vel[i] + forceCorr[i];
    tau[i] = max(-tauMax, min(tauMax, tau_raw[i]));
  end for;

  // === Tracking error (combined joint-space error) ===
  trackingError = sqrt(e_pos[1]^2 + e_pos[2]^2 + e_pos[3]^2 + e_pos[4]^2 + 1e-12);

  // === Payload retention check ===
  payloadRetained = wristForceMag < wristForceLimit;

  annotation(
    experiment(StopTime=8, Interval=0.0125, Tolerance=1e-6),
    Documentation(info="<html>
    <p><b>AssemblyArmCarryA</b>: Fixed-base articulated manipulator with four serial
    revolute joints (Z, Y, Y, X axes) and capsule links (0.50, 0.40, 0.28, 0.16 m).</p>
    <p>Link masses: 7, 5, 3, 1 kg. Computed-torque control with PD feedback and bounded
    wrist-force correction. Saturated effort drives (79.2 N.m limit). Six-axis wrist
    wrench sensor (CutForce). Rigid floor and fixed table with penalty-based collision.</p>
    <p>6 kg payload disturbance during middle third (2.67-5.33 s). 80 Hz control rate
    (Interval=0.0125 s). 8 s scenario. Trajectory completes at 4 s for settling.</p>
    <p>Requirements: joint/effort bounds, wrist force &lt; 60 N, payload retention,
    primary tracking error &lt; 0.061 rad-or-m after 5.2 s, no NaN/infinite values.</p>
    </html>"));
end AssemblyArmCarryA;