model PlanarPusherPushA
  "Planar two-link capsule arm with rounded tool pushing a rigid box on a table;
   hybrid position-force control, two-segment reference, friction disturbance,
   80 Hz synchronized traces over 8 s."

  // ---- Link and joint parameters ----
  parameter Real L1(unit="m")      = 0.46  "capsule link 1 length";
  parameter Real L2(unit="m")      = 0.35  "capsule link 2 length";
  parameter Real r_link(unit="m")  = 0.020 "capsule link radius";
  parameter Real r_tool(unit="m")  = 0.015 "rounded contact tool radius";
  parameter Real tau_max(unit="N.m")= 36.0  "per-joint command magnitude limit";

  // ---- Joint inertias / damping ----
  parameter Real I1(unit="kg.m2")        = 0.60 "joint 1 reflected inertia";
  parameter Real I2(unit="kg.m2")        = 0.25 "joint 2 reflected inertia";
  parameter Real d1(unit="N.m.s/rad")    = 0.20 "joint 1 viscous damping";
  parameter Real d2(unit="N.m.s/rad")    = 0.20 "joint 2 viscous damping";

  // ---- Box and table ----
  parameter Real m_box(unit="kg")  = 1.50 "box mass";
  parameter Real w_box(unit="m")   = 0.05 "box width along x";
  parameter Real h_box(unit="m")   = 0.10 "box depth along y";
  parameter Real mu_table          = 0.42 "box-table friction coefficient";
  parameter Real mu_tool           = 0.65 "tool-box friction coefficient";
  parameter Real g(unit="m/s2")    = 9.81 "gravitational acceleration";
  parameter Real I_box_yaw(unit="kg.m2") = (1.0/12.0)*m_box*(w_box*w_box + h_box*h_box)
    "box yaw inertia";

  // ---- Contact (tool-box) ----
  parameter Real kc(unit="N/m")   = 800.0 "tool-box normal contact stiffness";
  parameter Real cc(unit="N.s/m") = 15.0  "tool-box normal contact damping";

  // ---- Hybrid position-force control gains ----
  parameter Real F_base(unit="N")     = 8.0  "baseline normal pushing force";
  parameter Real Kp_box(unit="N/m")   = 150.0 "box position (x) gain";
  parameter Real Kd_box(unit="N.s/m") = 30.0  "box velocity (x) gain";
  parameter Real Kp_y(unit="N/m")     = 400.0 "lateral (y) position gain";
  parameter Real Kd_y(unit="N.s/m")   = 40.0  "lateral (y) velocity gain";
  parameter Real F_min(unit="N") = 5.0  "lower contact-force bound";
  parameter Real F_max(unit="N") = 25.0 "upper contact-force bound";

  // ---- Reference trajectory (two segments) ----
  parameter Real x0_box(unit="m") = 0.60 "initial box x";
  parameter Real x_mid(unit="m") = 0.70 "mid box x (end of segment 1)";
  parameter Real x_end(unit="m") = 0.78 "final box x (end of segment 2)";
  parameter Real y_ref(unit="m") = 0.0  "lateral reference";

  // ---- Scenario timing ----
  parameter Real T_end(unit="s")   = 8.0   "scenario duration";
  parameter Real Ts(unit="s")      = 1.0/80.0 "control/sample period";
  parameter Real t_seg1(unit="s")  = 4.0   "segment 1 end / segment 2 start";
  parameter Real t_dist_a(unit="s")= T_end/3.0      "disturbance start";
  parameter Real t_dist_b(unit="s")= 2.0*T_end/3.0  "disturbance end";
  parameter Real F_dist_mag(unit="N") = 3.0 "friction change disturbance";

  // ---- Joint states ----
  Real q1(start=-0.566, unit="rad")  "joint 1 angle";
  Real q2(start= 1.346, unit="rad")  "joint 2 angle";
  Real q1d(start=0.0, unit="rad/s") "joint 1 velocity";
  Real q2d(start=0.0, unit="rad/s") "joint 2 velocity";
  Real tau1_raw(unit="N.m") "raw joint 1 torque command";
  Real tau2_raw(unit="N.m") "raw joint 2 torque command";
  Real tau1(unit="N.m")     "saturated joint 1 torque command";
  Real tau2(unit="N.m")     "saturated joint 2 torque command";

  // ---- End-effector kinematics ----
  Real x_ee(unit="m")   "end-effector x";
  Real y_ee(unit="m")   "end-effector y";
  Real x_eed(unit="m/s") "end-effector x velocity";
  Real y_eed(unit="m/s") "end-effector y velocity";
  Real J11 "planar Jacobian entry (1,1)";
  Real J12 "planar Jacobian entry (1,2)";
  Real J21 "planar Jacobian entry (2,1)";
  Real J22 "planar Jacobian entry (2,2)";

  // ---- Box states ----
  Real x_box(start=x0_box, unit="m")     "box x position";
  Real x_boxd(start=0.0, unit="m/s")    "box x velocity";
  Real theta_box(start=0.0, unit="rad")  "box yaw";
  Real theta_boxd(start=0.0, unit="rad/s") "box yaw rate";
  Real x_front(unit="m") "box front-face x";

  // ---- Contact / friction ----
  Real pen_pos(unit="m")   "positive penetration";
  Real indicator           "smooth contact indicator (0..1)";
  Real rel_vel(unit="m/s") "normal relative velocity";
  Real Fn(unit="N")        "normal contact force (measured)";
  Real Ft(unit="N")        "tangential tool-box friction";
  Real Ffric_table(unit="N") "table friction on box";
  Real F_dist(unit="N")    "friction-change disturbance force";
  Boolean in_disturbance   "true during middle third";

  // ---- Reference and tracking ----
  Real x_ref(unit="m")      "box x reference";
  Real x_refd(unit="m/s")  "box x reference velocity";
  Real x_refdd(unit="m/s2") "box x reference acceleration";
  Real err_x(unit="m")     "primary tracking error (x_ref - x_box)";

  // ---- Task-space commands ----
  Real Fx_cmd_raw(unit="N") "raw commanded end-effector force along x";
  Real Fx_cmd(unit="N")     "clamped commanded end-effector force along x";
  Real Fy_cmd(unit="N") "commanded end-effector force along y (position-controlled)";

  // ---- 80 Hz synchronized sampled traces ----
  discrete Real q1_s(unit="rad");
  discrete Real q2_s(unit="rad");
  discrete Real q1d_s(unit="rad/s");
  discrete Real q2d_s(unit="rad/s");
  discrete Real tau1_s(unit="N.m");
  discrete Real tau2_s(unit="N.m");
  discrete Real x_ee_s(unit="m");
  discrete Real y_ee_s(unit="m");
  discrete Real Fn_s(unit="N");
  discrete Real x_box_s(unit="m");
  discrete Real theta_box_s(unit="rad");
  discrete Real x_ref_s(unit="m");
  discrete Real err_x_s(unit="m");
  discrete Real t_s(unit="s");

equation
  // ===== Forward kinematics =====
  x_ee  = L1*cos(q1) + L2*cos(q1 + q2);
  y_ee  = L1*sin(q1) + L2*sin(q1 + q2);
  x_eed = -L1*sin(q1)*q1d - L2*sin(q1 + q2)*(q1d + q2d);
  y_eed =  L1*cos(q1)*q1d + L2*cos(q1 + q2)*(q1d + q2d);

  // ===== Jacobian (dx_ee,dy_ee w.r.t. q1,q2) =====
  J11 = -L1*sin(q1) - L2*sin(q1 + q2);
  J12 = -L2*sin(q1 + q2);
  J21 =  L1*cos(q1) + L2*cos(q1 + q2);
  J22 =  L2*cos(q1 + q2);

  // ===== Box front face =====
  x_front = x_box + w_box/2.0;

  // ===== Smooth (event-free) normal contact force =====
  pen_pos   = max(0.0, x_ee - x_front);
  indicator = tanh(pen_pos/0.0005);
  rel_vel   = x_eed - x_boxd;
  Fn = max(0.0, kc*pen_pos + cc*rel_vel*indicator);

  // ===== Tangential tool-box friction (lateral) =====
  Ft = mu_tool*Fn*tanh(y_eed/0.01);

  // ===== Table friction on box (regularized Coulomb) =====
  Ffric_table = mu_table*m_box*g*tanh(x_boxd/0.02);

  // ===== Disturbance: +3 N friction change during middle third =====
  in_disturbance = (time >= t_dist_a) and (time <= t_dist_b);
  F_dist = if in_disturbance then F_dist_mag else 0.0;

  // ===== Two-segment box reference (constant velocity per segment) =====
  if time <= t_seg1 then
    x_ref   = x0_box + (x_mid - x0_box)*(time/t_seg1);
    x_refd  = (x_mid - x0_box)/t_seg1;
    x_refdd = 0.0;
  else
    x_ref   = x_mid + (x_end - x_mid)*((time - t_seg1)/(T_end - t_seg1));
    x_refd  = (x_end - x_mid)/(T_end - t_seg1);
    x_refdd = 0.0;
  end if;

  // ===== Primary tracking error =====
  err_x = x_ref - x_box;

  // ===== Hybrid position-force task-space command =====
  Fx_cmd_raw = F_base + Kp_box*err_x + Kd_box*(x_refd - x_boxd) + m_box*x_refdd;
  Fx_cmd = max(F_min, min(F_max, Fx_cmd_raw));
  Fy_cmd = Kp_y*(y_ref - y_ee) + Kd_y*(0.0 - y_eed);

  // ===== Joint torque commands (Jacobian-transpose mapping) =====
  tau1_raw = J11*Fx_cmd + J21*Fy_cmd;
  tau2_raw = J12*Fx_cmd + J22*Fy_cmd;
  // Actuator saturation (per-joint magnitude limit)
  tau1 = max(-tau_max, min(tau_max, tau1_raw));
  tau2 = max(-tau_max, min(tau_max, tau2_raw));

  // ===== Arm dynamics (horizontal plane; gravity normal to motion) =====
  I1*der(q1d) = tau1 - (J11*Fn + J21*Ft) - d1*q1d;
  I2*der(q2d) = tau2 - (J12*Fn + J22*Ft) - d2*q2d;
  der(q1) = q1d;
  der(q2) = q2d;

  // ===== Box translational dynamics along x =====
  m_box*der(x_boxd) = Fn - Ffric_table - F_dist;
  der(x_box) = x_boxd;

  // ===== Box yaw dynamics =====
  I_box_yaw*der(theta_boxd) = (w_box/2.0)*Ft - 0.5*theta_boxd - 2.0*theta_box;
  der(theta_box) = theta_boxd;

  // ===== 80 Hz synchronized state/command/sensor traces =====
  when sample(0, Ts) then
    t_s        = time;
    q1_s       = q1;
    q2_s       = q2;
    q1d_s      = q1d;
    q2d_s      = q2d;
    tau1_s     = tau1;
    tau2_s     = tau2;
    x_ee_s     = x_ee;
    y_ee_s     = y_ee;
    Fn_s       = Fn;
    x_box_s    = x_box;
    theta_box_s= theta_box;
    x_ref_s    = x_ref;
    err_x_s    = err_x;
  end when;

  annotation (
    experiment(StartTime=0, StopTime=8, Tolerance=1e-6, Interval=0.0125),
    Documentation(info="PlanarPusherPushA: 2-DOF planar capsule arm (0.46 m, 0.35 m)
 on revolute Z joints with rounded tool performs contact-rich pushing of a rigid
 box on a flat table. Hybrid position-force control: x direction regulates
 normal pushing force (clamped to [5,25] N) while tracking a two-segment box
 reference; y direction regulates lateral position. Joint torque commands are
 saturated to ±36 N.m. Box-table friction = 0.42, tool-box friction = 0.65.
 A controlled 3 N friction-change disturbance is applied during the middle third
 of the 8 s scenario. Robot state, contact force, object planar pose, commands,
 and tracking error are sampled and retained at 80 Hz."));
end PlanarPusherPushA;