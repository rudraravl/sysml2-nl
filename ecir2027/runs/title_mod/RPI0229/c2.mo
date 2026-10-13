model AssemblyArmCarryA
  "Fixed-base 4-DOF articulated manipulator with computed-torque control"
  import Modelica;
  import Modelica.Units.SI;

  // === Link parameters ===
  parameter SI.Length L1 = 0.50 "Link 1 length [m]";
  parameter SI.Length L2 = 0.40 "Link 2 length [m]";
  parameter SI.Length L3 = 0.28 "Link 3 length [m]";
  parameter SI.Length L4 = 0.16 "Link 4 length [m]";
  parameter SI.Mass m1 = 7 "Link 1 mass [kg]";
  parameter SI.Mass m2 = 5 "Link 2 mass [kg]";
  parameter SI.Mass m3 = 3 "Link 3 mass [kg]";
  parameter SI.Mass m4 = 1 "Link 4 mass [kg]";
  parameter SI.Mass mPayload = 6 "Payload disturbance mass [kg]";

  // === Control parameters ===
  parameter SI.Torque tauMax = 79.2 "Command magnitude limit [N.m]";
  parameter SI.Force wristForceLimit = 60 "Wrist force limit [N]";
  parameter Real Kp[4] = {500, 900, 600, 200} "Position feedback gains";
  parameter Real Kd[4] = {50, 45, 35, 15} "Velocity feedback gains";
  parameter Real Kf = 0.5 "Wrist-force correction gain";
  parameter Real forceCorrMax = 15.0 "Maximum wrist-force correction [N.m]";
  parameter SI.Time tauForceFilter = 0.01 "Wrist force filter time constant [s]";

  // === Scenario parameters ===
  parameter SI.Acceleration g = 9.81 "Gravitational acceleration [m/s^2]";
  parameter SI.Time tEnd = 8 "Scenario duration [s]";
  parameter SI.Time tDistStart = tEnd/3 "Disturbance start [s]";
  parameter SI.Time tDistEnd = 2*tEnd/3 "Disturbance end [s]";
  parameter SI.Time tRamp = 4.0 "Trajectory ramp completion [s]";

  // === Trajectory parameters ===
  parameter SI.Angle q_start[4] = {0, -0.3, 0.8, 0} "Initial joint angles [rad]";
  parameter SI.Angle q_end[4] = {0.6, -0.4, 0.7, 0} "Final joint angles [rad]";

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
  output Boolean payloadRetained "Payload retention flag";

  // === Internal variables ===
  SI.Torque tau_raw[4] "Unsaturated torques [N.m]";
  SI.Angle q_des[4] "Desired joint angles [rad]";
  SI.AngularVelocity qd_des[4] "Desired joint velocities [rad/s]";
  Real e_pos[4] "Position errors [rad]";
  Real e_vel[4] "Velocity errors [rad/s]";
  SI.Force F_payload "Payload disturbance force [N]";
  SI.Position eePos[3] "End-effector position [m]";
  Real F_ext[3] "Collision force [N]";
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

  // === Joint 1: Z axis ===
  Modelica.Mechanics.MultiBody.Joints.Revolute j1(
    n={0,0,1}, useAxisFlange=true,
    phi(fixed=true, start=q_start[1]), w(fixed=true, start=0))
    annotation(Placement(transformation(extent={{-40,0},{-20,20}})));

  Modelica.Mechanics.MultiBody.Parts.BodyBox l1(
    r={0,0,L1}, width=0.06, height=0.06,
    density=m1/(L1*0.06*0.06))
    annotation(Placement(transformation(extent={{-10,0},{10,20}})));

  // === Joint 2: Y axis ===
  Modelica.Mechanics.MultiBody.Joints.Revolute j2(
    n={0,1,0}, useAxisFlange=true,
    phi(fixed=true, start=q_start[2]), w(fixed=true, start=0))
    annotation(Placement(transformation(extent={{20,0},{40,20}})));

  Modelica.Mechanics.MultiBody.Parts.BodyBox l2(
    r={L2,0,0}, width=0.05, height=0.05,
    density=m2/(L2*0.05*0.05))
    annotation(Placement(transformation(extent={{50,0},{70,20}})));

  // === Joint 3: Y axis ===
  Modelica.Mechanics.MultiBody.Joints.Revolute j3(
    n={0,1,0}, useAxisFlange=true,
    phi(fixed=true, start=q_start[3]), w(fixed=true, start=0))
    annotation(Placement(transformation(extent={{80,0},{100,20}})));

  Modelica.Mechanics.MultiBody.Parts.BodyBox l3(
    r={L3,0,0}, width=0.04, height=0.04,
    density=m3/(L3*0.04*0.04))
    annotation(Placement(transformation(extent={{110,0},{130,20}})));

  // === Wrist force sensor (six-axis: CutForce provides force; torque not used in control) ===
  Modelica.Mechanics.MultiBody.Sensors.CutForce wristSensor(
    resolveInFrame=Modelica.Mechanics.MultiBody.Types.ResolveInFrameA.world)
    annotation(Placement(transformation(extent={{140,0},{160,20}})));

  // === Joint 4: X axis ===
  Modelica.Mechanics.MultiBody.Joints.Revolute j4(
    n={1,0,0}, useAxisFlange=true,
    phi(fixed=true, start=q_start[4]), w(fixed=true, start=0))
    annotation(Placement(transformation(extent={{170,0},{190,20}})));

  Modelica.Mechanics.MultiBody.Parts.BodyBox l4(
    r={L4,0,0}, width=0.03, height=0.03,
    density=m4/(L4*0.03*0.03))
    annotation(Placement(transformation(extent={{200,0},{220,20}})));

  // === External force (payload disturbance + collision) ===
  Modelica.Mechanics.MultiBody.Forces.WorldForce extForce
    annotation(Placement(transformation(extent={{260,0},{280,20}})));

  // === Torque actuators ===
  Modelica.Mechanics.Rotational.Sources.Torque act1
    annotation(Placement(transformation(extent={{-40,30},{-20,50}})));
  Modelica.Mechanics.Rotational.Sources.Torque act2
    annotation(Placement(transformation(extent={{20,30},{40,50}})));
  Modelica.Mechanics.Rotational.Sources.Torque act3
    annotation(Placement(transformation(extent={{80,30},{100,50}})));
  Modelica.Mechanics.Rotational.Sources.Torque act4
    annotation(Placement(transformation(extent={{170,30},{190,50}})));

  // === Fixed supports for joint reaction ===
  Modelica.Mechanics.Rotational.Components.Fixed sup1
    annotation(Placement(transformation(extent={{-40,60},{-20,80}})));
  Modelica.Mechanics.Rotational.Components.Fixed sup2
    annotation(Placement(transformation(extent={{20,60},{40,80}})));
  Modelica.Mechanics.Rotational.Components.Fixed sup3
    annotation(Placement(transformation(extent={{80,60},{100,80}})));
  Modelica.Mechanics.Rotational.Components.Fixed sup4
    annotation(Placement(transformation(extent={{170,60},{190,80}})));

  // === Joint angle encoders ===
  Modelica.Mechanics.Rotational.Sensors.AngleSensor ang1
    annotation(Placement(transformation(extent={{-40,-30},{-20,-10}})));
  Modelica.Mechanics.Rotational.Sensors.AngleSensor ang2
    annotation(Placement(transformation(extent={{20,-30},{40,-10}})));
  Modelica.Mechanics.Rotational.Sensors.AngleSensor ang3
    annotation(Placement(transformation(extent={{80,-30},{100,-10}})));
  Modelica.Mechanics.Rotational.Sensors.AngleSensor ang4
    annotation(Placement(transformation(extent={{170,-30},{190,-10}})));

  // === Velocity sensors ===
  Modelica.Mechanics.Rotational.Sensors.SpeedSensor spd1
    annotation(Placement(transformation(extent={{-40,-60},{-20,-40}})));
  Modelica.Mechanics.Rotational.Sensors.SpeedSensor spd2
    annotation(Placement(transformation(extent={{20,-60},{40,-40}})));
  Modelica.Mechanics.Rotational.Sensors.SpeedSensor spd3
    annotation(Placement(transformation(extent={{80,-60},{100,-40}})));
  Modelica.Mechanics.Rotational.Sensors.SpeedSensor spd4
    annotation(Placement(transformation(extent={{170,-60},{190,-40}})));

  // === Rigid workcell floor ===
  Modelica.Mechanics.MultiBody.Visualizers.FixedShape floor(
    r_shape={0,0,-0.01}, lengthDirection={1,0,0}, widthDirection={0,1,0},
    length=3, width=3, height=0.02, shapeType="box", color={100,100,100})
    annotation(Placement(transformation(extent={{-80,-80},{-60,-60}})));

  // === Fixed table with collision ===
  Modelica.Mechanics.MultiBody.Visualizers.FixedShape table(
    r_shape={tableCenterX,0,tableHeight/2}, lengthDirection={1,0,0},
    widthDirection={0,1,0},
    length=tableLength, width=tableWidth, height=tableHeight, shapeType="box",
    color={150,100,50})
    annotation(Placement(transformation(extent={{-50,-80},{-30,-60}})));

  // === RealExpression blocks for driving actuator inputs ===
  Modelica.Blocks.Sources.RealExpression tauCmd1(y=tau[1])
    annotation(Placement(transformation(extent={{-70,30},{-50,50}})));
  Modelica.Blocks.Sources.RealExpression tauCmd2(y=tau[2])
    annotation(Placement(transformation(extent={{-10,30},{10,50}})));
  Modelica.Blocks.Sources.RealExpression tauCmd3(y=tau[3])
    annotation(Placement(transformation(extent={{50,30},{70,50}})));
  Modelica.Blocks.Sources.RealExpression tauCmd4(y=tau[4])
    annotation(Placement(transformation(extent={{140,30},{160,50}})));

  // === RealExpression blocks for driving external force ===
  Modelica.Blocks.Sources.RealExpression extFx(y=F_ext[1])
    annotation(Placement(transformation(extent={{230,-30},{250,-10}})));
  Modelica.Blocks.Sources.RealExpression extFy(y=F_ext[2])
    annotation(Placement(transformation(extent={{230,-50},{250,-30}})));
  Modelica.Blocks.Sources.RealExpression extFz(y=-F_payload + F_ext[3])
    annotation(Placement(transformation(extent={{230,-70},{250,-50}})));

equation
  // === Kinematic chain ===
  connect(world.frame_b, j1.frame_a);
  connect(j1.frame_b, l1.frame_a);
  connect(l1.frame_b, j2.frame_a);
  connect(j2.frame_b, l2.frame_a);
  connect(l2.frame_b, j3.frame_a);
  connect(j3.frame_b, l3.frame_a);
  connect(l3.frame_b, wristSensor.frame_a);
  connect(wristSensor.frame_b, j4.frame_a);
  connect(j4.frame_b, l4.frame_a);
  connect(l4.frame_b, extForce.frame_b);

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

  // === Analytical forward kinematics for end-effector position ===
  eePos[1] = (L2*cos(q[2]) + L3*cos(q[2]+q[3]) + L4) * cos(q[1]);
  eePos[2] = (L2*cos(q[2]) + L3*cos(q[2]+q[3]) + L4) * sin(q[1]);
  eePos[3] = L1 - L2*sin(q[2]) - L3*sin(q[2]+q[3]);

  // === Wrist force sensor reading with safe norm ===
  wristForceRaw[1] = wristSensor.force[1];
  wristForceRaw[2] = wristSensor.force[2];
  wristForceRaw[3] = wristSensor.force[3];
  wristForceMag = sqrt(wristForceRaw[1]^2 + wristForceRaw[2]^2
    + wristForceRaw[3]^2 + 1e-12);

  // === Filtered wrist force (breaks algebraic loop) ===
  der(wristForceFilt[1]) = (wristForceRaw[1] - wristForceFilt[1]) / tauForceFilter;
  der(wristForceFilt[2]) = (wristForceRaw[2] - wristForceFilt[2]) / tauForceFilter;
  der(wristForceFilt[3]) = (wristForceRaw[3] - wristForceFilt[3]) / tauForceFilter;
  wristForceMagFilt = sqrt(wristForceFilt[1]^2 + wristForceFilt[2]^2
    + wristForceFilt[3]^2 + 1e-12);

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
    F_ext[1] = 0.0;
    F_ext[2] = 0.0;
    F_ext[3] = kCollision * (-eePos[3]);
  elseif (eePos[3] < tableHeight) and
         (abs(eePos[1] - tableCenterX) < tableLength/2) and
         (abs(eePos[2]) < tableWidth/2) then
    F_ext[1] = 0.0;
    F_ext[2] = 0.0;
    F_ext[3] = kCollision * (tableHeight - eePos[3]);
  else
    F_ext[1] = 0.0;
    F_ext[2] = 0.0;
    F_ext[3] = 0.0;
  end if;

  // === Gravity compensation (computed-torque feedforward) ===
  tau_grav[1] = 0.0;
  tau_grav[2] = g*cos(q[2])*(m2*L2/2 + (m3+m4)*L2)
             + g*cos(q[2]+q[3])*(m3*L3/2 + m4*(L3+L4/2));
  tau_grav[3] = g*cos(q[2]+q[3])*(m3*L3/2 + m4*(L3+L4/2));
  tau_grav[4] = 0.0;

  // === Bounded wrist-force correction ===
  forceCorr[1] = max(-forceCorrMax, min(forceCorrMax, Kf * wristForceFilt[1]));
  forceCorr[2] = max(-forceCorrMax, min(forceCorrMax, Kf * wristForceFilt[3]));
  forceCorr[3] = max(-forceCorrMax, min(forceCorrMax, 0.7 * Kf * wristForceFilt[3]));
  forceCorr[4] = 0.0;

  // === Computed-torque control with saturation ===
  for i in 1:4 loop
    tau_raw[i] = tau_grav[i] + Kp[i] * e_pos[i] + Kd[i] * e_vel[i] + forceCorr[i];
    tau[i] = max(-tauMax, min(tauMax, tau_raw[i]));
  end for;

  // === Tracking error (combined joint-space Euclidean error) ===
  trackingError = sqrt(e_pos[1]^2 + e_pos[2]^2 + e_pos[3]^2
    + e_pos[4]^2 + 1e-12);

  // === Payload retention check ===
  payloadRetained = wristForceMag < wristForceLimit;

  annotation(
    experiment(StopTime=8, Interval=0.0125, Tolerance=1e-6),
    Documentation(info="<html>
    <p><b>AssemblyArmCarryA</b>: Fixed-base articulated manipulator with four serial
    revolute joints (Z, Y, Y, X axes) and capsule links (0.50, 0.40, 0.28, 0.16 m).</p>
    <p>Link masses: 7, 5, 3, 1 kg. Computed-torque control with PD feedback and bounded
    wrist-force correction. Saturated effort drives (79.2 N.m limit). Wrist force sensor
    (CutForce, resolved in world frame). Rigid floor and fixed table with penalty-based
    collision.</p>
    <p>6 kg payload disturbance during middle third (2.67-5.33 s). 80 Hz output rate
    (Interval=0.0125 s). 8 s scenario. Trajectory completes at 4 s for settling.</p>
    <p>End-effector position computed analytically from joint angles (no AbsolutePosition
    sensor needed). Wrist force filtered to break algebraic loop.</p>
    </html>"));
end AssemblyArmCarryA;