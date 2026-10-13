model ContactArmGraspC
  "Contact-rich manipulation: impedance motion then force regulation. "
  "Six-revolute Z-Y-Y-X-Y-X arm with capsule(cylinder) links, six-axis wrist "
  "sensor, replaceable rigid tool, six saturated joint effort actuators (<=110 N.m), "
  "rigid support table (mu=0.78, e=0.03), 7.2 N tangential disturbance in middle third, "
  "125 Hz controller over 12 s. Facts not stated in the requirement are treated as "
  "nominal/unknown and are flagged in comments.";

  extends Modelica.Icons.Example;

  // ---------------- Requirement-bound parameters ----------------
  parameter Real tau_max       = 110.0  "Maximum joint command magnitude (N.m) [requirement]";
  parameter Real mu_table      = 0.78   "Table-object friction coefficient [requirement]";
  parameter Real e_rest        = 0.03   "Coefficient of restitution [requirement]";
  parameter Real Ts            = 1.0/125.0 "Controller sample period (s) [requirement: 125 Hz]";
  parameter Real t_end         = 12.0   "Mission duration (s) [requirement]";
  parameter Real t_dist_start  = t_end/3.0     "Tangential disturbance start (s) [middle third]";
  parameter Real t_dist_end    = 2.0*t_end/3.0  "Tangential disturbance end (s) [middle third]";
  parameter Real F_dist        = 7.2    "Tangential disturbance magnitude (N) [requirement]";

  // ---------------- Nominal parameters (not specified by requirement) ----------------
  parameter Real Fn_desired     = 25.0   "Desired grasp normal force (N) [nominal]";
  parameter Real F_contact_thresh= 1.0   "Contact detection threshold (N) [nominal]";
  parameter Real k_c            = 5.0e4 "Contact normal stiffness (N/m) [nominal]";
  parameter Real d_c            = 2.0*(-Modelica.Math.log(e_rest)/
                                sqrt(Modelica.Constants.pi*Modelica.Constants.pi +
                                     Modelica.Math.log(e_rest)*Modelica.Math.log(e_rest)))*
                                sqrt(k_c*m_obj) "Contact damping (N.s/m) derived from e_rest [nominal]";
  parameter Real z_table        = 0.0    "Table surface height (m) [nominal]";
  parameter Real obj_half_h     = 0.04   "Object half-height (m) [nominal]";
  parameter Real obj_radius     = 0.04   "Object half-width (m) [nominal]";
  parameter Real m_obj          = 1.5    "Object mass (kg) [nominal]";
  parameter Real d_link         = 0.05   "Link capsule diameter (m) [nominal]";
  parameter Real L[6]           = {0.30,0.22,0.14,0.08,0.05,0.03} "Link lengths (m) [nominal]";
  parameter Real Kp[6]          = {120,120,80,40,25,15} "Impedance stiffness (N.m/rad) [nominal]";
  parameter Real Kd[6]          = {8.0,8.0,5.0,3.0,1.5,1.0} "Impedance damping (N.m.s/rad) [nominal]";
  parameter Real Kf             = 0.05   "Force-regulation integral gain (m/N) [nominal]";
  parameter Real q_grasp[6]     = {0.0,0.25,-0.15,0.0,0.0,0.0} "Grasp joint reference (rad) [nominal]";
  parameter Real q_init[6]      = {0.0,0.9,0.6,0.0,0.4,0.0}    "Initial joint configuration (rad) [nominal]";
  parameter Real t_approach     = 4.0    "Approach duration (s) [nominal]";

  // ---------------- World ----------------
  inner Modelica.Mechanics.MultiBody.World world(
    g=9.81, n={0,0,-1}, enableAnimation=false)
    annotation (Placement(transformation(extent={{-380,60},{-360,80}})));

  // ---------------- Base + pedestal ----------------
  Modelica.Mechanics.MultiBody.Parts.Fixed base(r={0,0,0})
    annotation (Placement(transformation(extent={{-340,60},{-320,80}})));
  Modelica.Mechanics.MultiBody.Parts.BodyCylinder pedestal(
    r={0,0,0.8}, r_shape={0,0,0}, length=0.8, diameter=0.10, density=3000)
    annotation (Placement(transformation(extent={{-300,60},{-280,80}})));

  // ---------------- Six revolute joints: Z-Y-Y-X-Y-X ----------------
  Modelica.Mechanics.MultiBody.Joints.Revolute j1(useAxisFlange=true, axis={0,0,1},
    phi(start=q_init[1], fixed=true), w(start=0, fixed=true))
    annotation (Placement(transformation(extent={{-260,60},{-240,80}})));
  Modelica.Mechanics.MultiBody.Joints.Revolute j2(useAxisFlange=true, axis={0,1,0},
    phi(start=q_init[2], fixed=true), w(start=0, fixed=true))
    annotation (Placement(transformation(extent={{-220,60},{-200,80}})));
  Modelica.Mechanics.MultiBody.Joints.Revolute j3(useAxisFlange=true, axis={0,1,0},
    phi(start=q_init[3], fixed=true), w(start=0, fixed=true))
    annotation (Placement(transformation(extent={{-180,60},{-160,80}})));
  Modelica.Mechanics.MultiBody.Joints.Revolute j4(useAxisFlange=true, axis={1,0,0},
    phi(start=q_init[4], fixed=true), w(start=0, fixed=true))
    annotation (Placement(transformation(extent={{-140,60},{-120,80}})));
  Modelica.Mechanics.MultiBody.Joints.Revolute j5(useAxisFlange=true, axis={0,1,0},
    phi(start=q_init[5], fixed=true), w(start=0, fixed=true))
    annotation (Placement(transformation(extent={{-100,60},{-80,80}})));
  Modelica.Mechanics.MultiBody.Joints.Revolute j6(useAxisFlange=true, axis={1,0,0},
    phi(start=q_init[6], fixed=true), w(start=0, fixed=true))
    annotation (Placement(transformation(extent={{-60,60},{-40,80}})));

  // ---------------- Capsule(cylinder) links ----------------
  Modelica.Mechanics.MultiBody.Parts.BodyCylinder link1(r={0,0,-L[1]}, r_shape={0,0,0}, length=L[1], diameter=d_link, density=1500)
    annotation (Placement(transformation(extent={{-260,30},{-240,50}})));
  Modelica.Mechanics.MultiBody.Parts.BodyCylinder link2(r={0,0,-L[2]}, r_shape={0,0,0}, length=L[2], diameter=d_link, density=1500)
    annotation (Placement(transformation(extent={{-220,30},{-200,50}})));
  Modelica.Mechanics.MultiBody.Parts.BodyCylinder link3(r={0,0,-L[3]}, r_shape={0,0,0}, length=L[3], diameter=d_link, density=1500)
    annotation (Placement(transformation(extent={{-180,30},{-160,50}})));
  Modelica.Mechanics.MultiBody.Parts.BodyCylinder link4(r={0,0,-L[4]}, r_shape={0,0,0}, length=L[4], diameter=d_link, density=1500)
    annotation (Placement(transformation(extent={{-140,30},{-120,50}})));
  Modelica.Mechanics.MultiBody.Parts.BodyCylinder link5(r={0,0,-L[5]}, r_shape={0,0,0}, length=L[5], diameter=d_link, density=1500)
    annotation (Placement(transformation(extent={{-100,30},{-80,50}})));
  Modelica.Mechanics.MultiBody.Parts.BodyCylinder link6(r={0,0,-L[6]}, r_shape={0,0,0}, length=L[6], diameter=d_link, density=1500)
    annotation (Placement(transformation(extent={{-60,30},{-40,50}})));

  // ---------------- Six-axis wrist sensor (force + torque) ----------------
  Modelica.Mechanics.MultiBody.Sensors.CutForce    wristForce(
    resolveInFrame=Modelica.Mechanics.MultiBody.Types.ResolveInFrameA.frame_a)
    annotation (Placement(transformation(extent={{-20,60},{0,80}})));
  Modelica.Mechanics.MultiBody.Sensors.CutTorque   wristTorque(
    resolveInFrame=Modelica.Mechanics.MultiBody.Types.ResolveInFrameA.frame_a)
    annotation (Placement(transformation(extent={{20,60},{40,80}})));

  // ---------------- Replaceable rigid tool ----------------
  Modelica.Mechanics.MultiBody.Parts.BodyCylinder tool(
    r={0,0,-0.06}, r_shape={0,0,0}, length=0.06, diameter=0.03, density=7700)
    annotation (Placement(transformation(extent={{60,60},{80,80}})));

  // ---------------- Rigid object (free body) ----------------
  Modelica.Mechanics.MultiBody.Parts.Body object(
    m=m_obj, r_CM={0,0,0}, I11=0.0016, I22=0.0016, I33=0.0016,
    r_0(start={0,0,obj_half_h}, each fixed=true),
    angles(start={0,0,0}, each fixed=true),
    v_0(start={0,0,0}, each fixed=true),
    w_a(start={0,0,0}, each fixed=true))
    annotation (Placement(transformation(extent={{60,10},{80,30}})));

  // ---------------- Sensors ----------------
  Modelica.Mechanics.MultiBody.Sensors.AbsoluteSensor tipSensor(get_r=true, get_v=true)
    annotation (Placement(transformation(extent={{60,90},{80,110}})));
  Modelica.Mechanics.MultiBody.Sensors.AbsoluteSensor objSensor(get_r=true, get_v=true, get_angles=true)
    annotation (Placement(transformation(extent={{100,10},{120,30}})));

  // ---------------- Force elements ----------------
  Modelica.Mechanics.MultiBody.Forces.WorldForce tableForce(
    resolveInFrame=Modelica.Mechanics.MultiBody.Types.ResolveInFrameB.world)
    annotation (Placement(transformation(extent={{20,-20},{0,0}})));
  Modelica.Mechanics.MultiBody.Forces.WorldForce distForce(
    resolveInFrame=Modelica.Mechanics.MultiBody.Types.ResolveInFrameB.world)
    annotation (Placement(transformation(extent={{60,-20},{40,0}})));
  Modelica.Mechanics.MultiBody.Forces.Force contactForce(
    resolveInFrame=Modelica.Mechanics.MultiBody.Types.ResolveInFrameA.world)
    annotation (Placement(transformation(extent={{120,40},{100,60}})));

  // ---------------- Real-expression drivers for force inputs ----------------
  Modelica.Blocks.Sources.RealExpression rex_table_x(expr=F_table_x) annotation (Placement(transformation(extent={{60,-20},{40,0}})));
  Modelica.Blocks.Sources.RealExpression rex_table_y(expr=F_table_y) annotation (Placement(transformation(extent={{60,-40},{40,-20}})));
  Modelica.Blocks.Sources.RealExpression rex_table_z(expr=F_table_z) annotation (Placement(transformation(extent={{60,-60},{40,-40}})));
  Modelica.Blocks.Sources.RealExpression rex_dist_x(expr=F_dist*dist_active) annotation (Placement(transformation(extent={{100,-20},{80,0}})));
  Modelica.Blocks.Sources.RealExpression rex_dist_y(expr=0.0) annotation (Placement(transformation(extent={{100,-40},{80,-20}})));
  Modelica.Blocks.Sources.RealExpression rex_dist_z(expr=0.0) annotation (Placement(transformation(extent={{100,-60},{80,-40}})));
  Modelica.Blocks.Sources.RealExpression rex_contact_x(expr=F_contact_x) annotation (Placement(transformation(extent={{160,50},{140,70}})));
  Modelica.Blocks.Sources.RealExpression rex_contact_y(expr=F_contact_y) annotation (Placement(transformation(extent={{160,30},{140,50}})));
  Modelica.Blocks.Sources.RealExpression rex_contact_z(expr=F_contact_z) annotation (Placement(transformation(extent={{160,10},{140,30}})));

  // ---------------- Six saturated joint effort actuators ----------------
  Modelica.Mechanics.Rotational.Sources.Torque act1(useSupport=true) annotation (Placement(transformation(extent={{-260,100},{-240,120}})));
  Modelica.Mechanics.Rotational.Sources.Torque act2(useSupport=true) annotation (Placement(transformation(extent={{-220,100},{-200,120}})));
  Modelica.Mechanics.Rotational.Sources.Torque act3(useSupport=true) annotation (Placement(transformation(extent={{-180,100},{-160,120}})));
  Modelica.Mechanics.Rotational.Sources.Torque act4(useSupport=true) annotation (Placement(transformation(extent={{-140,100},{-120,120}})));
  Modelica.Mechanics.Rotational.Sources.Torque act5(useSupport=true) annotation (Placement(transformation(extent={{-100,100},{-80,120}})));
  Modelica.Mechanics.Rotational.Sources.Torque act6(useSupport=true) annotation (Placement(transformation(extent={{-60,100},{-40,120}})));

  Modelica.Blocks.Sources.RealExpression rex_act1(expr=cmd[1]) annotation (Placement(transformation(extent={{-300,100},{-280,120}})));
  Modelica.Blocks.Sources.RealExpression rex_act2(expr=cmd[2]) annotation (Placement(transformation(extent={{-260,100},{-240,120}})));
  Modelica.Blocks.Sources.RealExpression rex_act3(expr=cmd[3]) annotation (Placement(transformation(extent={{-220,100},{-200,120}})));
  Modelica.Blocks.Sources.RealExpression rex_act4(expr=cmd[4]) annotation (Placement(transformation(extent={{-180,100},{-160,120}})));
  Modelica.Blocks.Sources.RealExpression rex_act5(expr=cmd[5]) annotation (Placement(transformation(extent={{-140,100},{-120,120}})));
  Modelica.Blocks.Sources.RealExpression rex_act6(expr=cmd[6]) annotation (Placement(transformation(extent={{-100,100},{-80,120}})));

  // ---------------- Discrete controller state ----------------
  discrete Real q_ref_d[6](start=q_init)  "Sampled joint reference (rad)";
  discrete Real z_corr_d(start=0.0)       "Force-regulation position correction (rad)";
  discrete Real phase_d(start=0.0)        "0=approach, 1=contact-seek, 2=force-regulate";
  discrete Real Fn_meas_d(start=0.0)      "Sampled normal contact force (N)";

  // ---------------- Continuous computed / trace variables ----------------
  Real r_tip[3]     "Tool tip position in world (m)";
  Real v_tip[3]     "Tool tip velocity in world (m/s)";
  Real r_obj[3]     "Object center position in world (m)";
  Real v_obj[3]     "Object center velocity in world (m/s)";
  Real ang_obj[3]   "Object orientation (rad)";

  Real pen_table    "Object-table penetration (m)";
  Real Fn_table     "Object-table normal force (N)";
  Real F_table_x, F_table_y, F_table_z "Object-table force components (N)";

  Real pen_tool     "Tool-object penetration (m)";
  Real Fn_tool      "Tool-object normal contact force (N)";
  Real F_contact_x, F_contact_y, F_contact_z "Tool-object force on tool (N)";

  Real dist_active  "Disturbance activation (0/1)";
  Real cmd_unsat[6] "Un-saturated joint command (N.m)";
  Real cmd[6]       "Saturated joint command trace (N.m)";
  Real q_meas[6]    "Actuator joint-angle trace (rad)";
  Real w_meas[6]    "Actuator joint-velocity trace (rad/s)";
  Real wrist_f[3]   "Wrist force trace (N)";
  Real wrist_t[3]   "Wrist torque trace (N.m)";
  Real track_err    "Primary tracking error proxy (m)";
  Boolean grasp_ok  "Grasp integrity indicator";

protected
  Real vt_mag_table, vt_mag_tool;
  Real vtx_rel, vty_rel;

equation
  // ---- Instrumentation: actuator state ----
  q_meas = {j1.phi, j2.phi, j3.phi, j4.phi, j5.phi, j6.phi};
  w_meas = {j1.w, j2.w, j3.w, j4.w, j5.w, j6.w};

  // ---- Instrumentation: object pose and tool tip ----
  r_tip   = tipSensor.r;
  v_tip   = tipSensor.v;
  r_obj   = objSensor.r;
  v_obj   = objSensor.v;
  ang_obj = objSensor.angles;

  // ---- Six-axis wrist sensor ----
  wrist_f = wristForce.force;
  wrist_t = wristTorque.torque;

  // ---- Object-table contact (compliant normal + Coulomb friction) ----
  pen_table = max(0.0, obj_half_h - r_obj[3]);
  Fn_table  = if pen_table > 0.0 then k_c*pen_table - d_c*v_obj[3] else 0.0;
  vt_mag_table = sqrt(v_obj[1]*v_obj[1] + v_obj[2]*v_obj[2] + 1.0e-9);
  F_table_x = if pen_table > 0.0 then -mu_table*Fn_table*v_obj[1]/vt_mag_table else 0.0;
  F_table_y = if pen_table > 0.0 then -mu_table*Fn_table*v_obj[2]/vt_mag_table else 0.0;
  F_table_z = max(0.0, Fn_table);

  // ---- Tool-object contact (normal + tangential grasp friction) ----
  pen_tool = max(0.0, (r_obj[3] + obj_half_h) - r_tip[3]);
  Fn_tool  = max(0.0, if pen_tool > 0.0 then k_c*pen_tool - d_c*(v_tip[3] - v_obj[3]) else 0.0);
  vtx_rel  = v_tip[1] - v_obj[1];
  vty_rel  = v_tip[2] - v_obj[2];
  vt_mag_tool = sqrt(vtx_rel*vtx_rel + vty_rel*vty_rel + 1.0e-9);
  // Force on object from tool = {mu*Fn*vtrel/|vtrel|, mu*Fn*vtrel/|vtrel|, -Fn}
  // Force on tool from object = -that.
  F_contact_x = -mu_table*Fn_tool*vtx_rel/vt_mag_tool;
  F_contact_y = -mu_table*Fn_tool*vty_rel/vt_mag_tool;
  F_contact_z = Fn_tool;

  // ---- Disturbance window (middle third) ----
  dist_active = if time >= t_dist_start and time <= t_dist_end then 1.0 else 0.0;

  // ---- Impedance + force-regulation command (saturated) ----
  for i in 1:6 loop
    cmd_unsat[i] = Kp[i]*(q_ref_d[i] - q_meas[i]) - Kd[i]*w_meas[i];
    cmd[i]       = max(-tau_max, min(tau_max, cmd_unsat[i]));
  end for;

  // ---- Primary tracking error proxy (end-effector-referenced joint error) ----
  track_err = sqrt(
      (L[1]*(q_meas[1]-q_grasp[1]))^2 + (L[2]*(q_meas[2]-q_grasp[2]))^2 +
      (L[3]*(q_meas[3]-q_grasp[3]))^2 + (L[4]*(q_meas[4]-q_grasp[4]))^2 +
      (L[5]*(q_meas[5]-q_grasp[5]))^2 + (L[6]*(q_meas[6]-q_grasp[6]))^2 + 1.0e-12);

  // ---- Grasp integrity (friction capacity exceeds disturbance) ----
  grasp_ok = (pen_tool <= 0.0) or (mu_table*Fn_tool >= abs(F_dist) - 1.0e-6);

  // ---- Requirement checks (non-blocking) ----
  assert(track_err < 0.016 or time < 7.8,
    "Primary tracking error exceeds 0.016 m after 7.8 s", AssertionLevel.warning);
  assert(grasp_ok, "Grasp loss risk: friction capacity below disturbance", AssertionLevel.warning);
  assert(abs(r_obj[1]) < 0.05 and abs(r_obj[2]) < 0.05 and r_obj[3] >= -1.0e-4,
    "Object displacement bound violated", AssertionLevel.warning);

  // ---------------- Discrete controller at 125 Hz ----------------
  when sample(0, Ts) then
    Fn_meas_d := Fn_tool;
    if time < t_approach then
      // Phase 0: impedance approach motion (ramp reference)
      phase_d := 0.0;
      for i in 1:6 loop
        q_ref_d[i] := q_init[i] + (q_grasp[i] - q_init[i])*min(time/t_approach, 1.0);
      end for;
      z_corr_d := 0.0;
    elseif Fn_meas_d > F_contact_thresh then
      // Phase 2: force regulation (integral action on normal force)
      phase_d := 2.0;
      for i in 1:6 loop
        q_ref_d[i] := q_grasp[i];
      end for;
      q_ref_d[2] := q_grasp[2] + z_corr_d;
      q_ref_d[3] := q_grasp[3] + z_corr_d;
      z_corr_d := z_corr_d + Kf*(Fn_desired - Fn_meas_d)*Ts;
    else
      // Phase 1: contact-seek (hold grasp reference)
      phase_d := 1.0;
      for i in 1:6 loop
        q_ref_d[i] := q_grasp[i];
      end for;
      z_corr_d := 0.0;
    end if;
  end when;

  // ---------------- Kinematic connections ----------------
  connect(base.frame_b, pedestal.frame_a);
  connect(pedestal.frame_b, j1.frame_a);
  connect(j1.frame_b, link1.frame_a);
  connect(link1.frame_b, j2.frame_a);
  connect(j2.frame_b, link2.frame_a);
  connect(link2.frame_b, j3.frame_a);
  connect(j3.frame_b, link3.frame_a);
  connect(link3.frame_b, j4.frame_a);
  connect(j4.frame_b, link4.frame_a);
  connect(link4.frame_b, j5.frame_a);
  connect(j5.frame_b, link5.frame_a);
  connect(link5.frame_b, j6.frame_a);
  connect(j6.frame_b, link6.frame_a);

  // ---------------- Wrist sensor + tool ----------------
  connect(link6.frame_b, wristForce.frame_a);
  connect(wristForce.frame_b, wristTorque.frame_a);
  connect(wristTorque.frame_b, tool.frame_a);
  connect(tool.frame_b, tipSensor.frame_a);
  connect(tool.frame_b, contactForce.frame_a);

  // ---------------- Object interactions ----------------
  connect(contactForce.frame_b, object.frame_a);
  connect(object.frame_a, objSensor.frame_a);
  connect(object.frame_a, tableForce.frame_a);
  connect(object.frame_a, distForce.frame_a);

  // ---------------- Force input drivers ----------------
  connect(rex_table_x.y, tableForce.force[1]);
  connect(rex_table_y.y, tableForce.force[2]);
  connect(rex_table_z.y, tableForce.force[3]);
  connect(rex_dist_x.y,  distForce.force[1]);
  connect(rex_dist_y.y,  distForce.force[2]);
  connect(rex_dist_z.y,  distForce.force[3]);
  connect(rex_contact_x.y, contactForce.f[1]);
  connect(rex_contact_y.y, contactForce.f[2]);
  connect(rex_contact_z.y, contactForce.f[3]);

  // ---------------- Actuator connections ----------------
  connect(rex_act1.y, act1.tau);
  connect(rex_act2.y, act2.tau);
  connect(rex_act3.y, act3.tau);
  connect(rex_act4.y, act4.tau);
  connect(rex_act5.y, act5.tau);
  connect(rex_act6.y, act6.tau);
  connect(act1.flange, j1.flange_a);
  connect(act1.support, j1.bearing);
  connect(act2.flange, j2.flange_a);
  connect(act2.support, j2.bearing);
  connect(act3.flange, j3.flange_a);
  connect(act3.support, j3.bearing);
  connect(act4.flange, j4.flange_a);
  connect(act4.support, j4.bearing);
  connect(act5.flange, j5.flange_a);
  connect(act5.support, j5.bearing);
  connect(act6.flange, j6.flange_a);
  connect(act6.support, j6.bearing);

  annotation (
    experiment(StopTime = 12.0, Interval = 0.008, Tolerance = 1.0e-6),
    Documentation(info="Standalone contact-rich manipulation plant+controller. "
      "Z-Y-Y-X-Y-X six-revolute arm, capsule(cylinder) links, six-axis wrist sensor, "
      "replaceable rigid tool, saturated joint efforts (<=110 N.m), rigid table with "
      "friction 0.78 and restitution 0.03, 7.2 N tangential disturbance over middle third, "
      "125 Hz impedance/force-regulation controller over 12 s. Capsule links approximated "
      "by cylinders (MSL has no capsule primitive). Geometric and inertial constants are "
      "nominal because they are not specified in the requirement."));
end ContactArmGraspC;