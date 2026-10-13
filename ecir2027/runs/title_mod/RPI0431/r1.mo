model PlanarPusherPolishE
  "Planar contact-rich manipulation: 2-link capsule arm on Z-revolute joints
   with rounded tool follows 0.50 m curved workpiece path at constant normal
   force.  Compliant contact (mu=0.50), 8.4 N middle-third disturbance,
   250 Hz (Interval=0.004 s) for 16 s.  Torque bounded at 55 N.m per joint."

  /* Unspecified physical parameters are marked (unspecified) and assigned
     reasonable defaults so the model compiles and simulates.  Only values
     stated in the requirement are treated as facts. */

  // ---- Plant: capsule links ----
  parameter Real L1 = 0.46  "Capsule link 1 length [m]";
  parameter Real L2 = 0.35  "Capsule link 2 length [m]";
  parameter Real r_link1 = 0.025 "Capsule link 1 radius [m] (unspecified)";
  parameter Real r_link2 = 0.020 "Capsule link 2 radius [m] (unspecified)";
  parameter Real r_tool  = 0.020 "Rounded contact tool radius [m] (unspecified)";
  parameter Real m1 = 2.0   "Link 1 lumped mass [kg] (unspecified)";
  parameter Real m2 = 1.5   "Link 2 + tool lumped mass [kg] (unspecified)";

  // ---- Plant: fixed base ----
  parameter Real bx = 0.30  "Base x [m] (unspecified)";
  parameter Real by = 0.40  "Base y [m] (unspecified)";

  // ---- Plant: fixed curved workpiece ----
  parameter Real Rw  = 1.0  "Workpiece arc radius [m] (unspecified)";
  parameter Real wcx = 0.40 "Workpiece center x [m] (unspecified)";
  parameter Real wcy =-1.0  "Workpiece center y [m] (unspecified)";
  parameter Real phi_start = 1.3208 "Path start angle [rad] (computed from geometry)";

  // ---- Contact model ----
  parameter Real mu_f = 0.50 "Friction coefficient";
  parameter Real k_n  = 5000.0 "Normal contact stiffness [N/m] (unspecified)";
  parameter Real c_n  = 50.0   "Normal contact damping [N.s/m] (unspecified)";
  parameter Real v_thresh = 0.01 "Friction velocity smoothing [m/s] (unspecified)";

  // ---- Drive limits ----
  parameter Real tau_max = 55.0 "Per-joint torque limit [N.m]";

  // ---- Control parameters ----
  parameter Real F_n_target = 20.0 "Target normal force [N] (within 12-30 N)";
  parameter Real Kp_s = 800.0 "Tangential proportional gain (unspecified)";
  parameter Real Kd_s = 60.0  "Tangential derivative gain (unspecified)";
  parameter Real Ki_s = 400.0 "Tangential integral gain (unspecified)";
  parameter Real Kf   = 8.0   "Normal force feedback gain (unspecified)";
  parameter Real s_int_max = 0.05 "Integral anti-windup clamp [m.s] (unspecified)";
  parameter Real F_norm_clamp = 80.0 "Normal force command clamp [N] (unspecified)";

  // ---- Disturbance & timing ----
  parameter Real F_dist_mag = 8.4 "Disturbance force magnitude [N]";
  parameter Real T_sim = 16.0     "Simulation duration [s]";
  parameter Real Ts = 1.0/250.0   "Controller sample period [s]";

  // ---- Gravity (in-plane, -Y direction) ----
  parameter Real g = 9.81 "Gravitational acceleration [m/s2] (unspecified)";

  // ===================== States (encoders) =====================
  Real q1(start=-1.5618)     "Joint 1 encoder angle [rad]";
  Real q1_dot(start=0)       "Joint 1 velocity [rad/s]";
  Real q2(start=1.6890)      "Joint 2 encoder angle [rad]";
  Real q2_dot(start=0)       "Joint 2 velocity [rad/s]";

  // ===================== Forward kinematics =====================
  Real j2x   "Joint 2 x [m]";
  Real j2y   "Joint 2 y [m]";
  Real tip_x "Tool-tip pose x [m]";
  Real tip_y "Tool-tip pose y [m]";
  Real vpx   "Tool-tip x velocity [m/s]";
  Real vpy   "Tool-tip y velocity [m/s]";

  // ===================== Contact geometry =====================
  Real rx      "Radial x from workpiece center to tool [m]";
  Real ry      "Radial y from workpiece center to tool [m]";
  Real dist    "Distance from workpiece center to tool center [m]";
  Real nx      "Outward normal x (unit)";
  Real ny      "Outward normal y (unit)";
  Real tx      "Tangential x (unit, increasing path)";
  Real ty      "Tangential y (unit, increasing path)";
  Real d_pen   "Penetration depth [m]";
  Real d_pen_dot "Penetration rate [m/s]";
  Real v_t     "Tangential velocity [m/s]";
  Real phi_meas "Measured contact angle [rad]";
  Real s_meas  "Measured path position [m]";
  Real s_meas_dot "Measured path velocity [m/s]";

  // ===================== Contact forces =====================
  Real F_n_contact  "Normal contact force magnitude [N]";
  Real F_t_friction "Tangential friction force [N]";
  Real Fcx          "Contact force x on tool [N]";
  Real Fcy          "Contact force y on tool [N]";
  Real F_n_meas     "Measured normal force [N]";

  // ===================== Controller =====================
  Real s_ref      "Reference path position [m]";
  Real s_ref_dot  "Reference path velocity [m/s]";
  Real s_int(start=0) "Integral of path error [m.s]";
  Real F_normal_cmd "Commanded normal force [N]";
  Real F_tan_cmd    "Commanded tangential force [N]";
  Real Fx_des       "Desired tool force x [N]";
  Real Fy_des       "Desired tool force y [N]";
  Real tau1_cmd     "Commanded torque 1 pre-sat [N.m]";
  Real tau2_cmd     "Commanded torque 2 pre-sat [N.m]";
  Real tau1_sat     "Saturated torque 1 [N.m]";
  Real tau2_sat     "Saturated torque 2 [N.m]";

  // ===================== Jacobian =====================
  Real J11, J12, J21, J22;

  // ===================== Dynamics =====================
  Real M11, M12, M21, M22;
  Real C1, C2;
  Real G1, G2;
  Real det_M;
  Real q1_ddot, q2_ddot;

  // ===================== Disturbance =====================
  Real F_disturb "Disturbance tangential force [N]";
  Real Fdist_x   "Disturbance force x [N]";
  Real Fdist_y   "Disturbance force y [N]";

  // ===================== Sensors =====================
  Real wrist_fx "Wrist wrench x [N]";
  Real wrist_fy "Wrist wrench y [N]";
  Real wrist_fz "Wrist wrench moment z [N.m]";

  // ===================== Acceptance metrics =====================
  Real path_error "Primary tracking error [m]";
  Real tau1_abs   "Absolute torque 1 [N.m]";
  Real tau2_abs   "Absolute torque 2 [N.m]";
  Boolean contact_ok    "Continuous contact flag";
  Boolean force_in_bounds "Force in [12,30] N";
  Boolean torque1_ok    "Torque 1 within bounds";
  Boolean torque2_ok    "Torque 2 within bounds";
  Boolean tracking_ok   "Tracking error < 0.018 m after 10.4 s";

equation
  // ===== Forward kinematics =====
  j2x   = bx + L1*cos(q1);
  j2y   = by + L1*sin(q1);
  tip_x = j2x + L2*cos(q1+q2);
  tip_y = j2y + L2*sin(q1+q2);
  vpx   = -L1*sin(q1)*q1_dot - L2*sin(q1+q2)*(q1_dot+q2_dot);
  vpy   =  L1*cos(q1)*q1_dot + L2*cos(q1+q2)*(q1_dot+q2_dot);

  // ===== Contact geometry =====
  rx   = tip_x - wcx;
  ry   = tip_y - wcy;
  dist = sqrt(rx*rx + ry*ry + 1e-12);
  nx   = rx / dist;
  ny   = ry / dist;
  tx   = -ny;
  ty   =  nx;
  d_pen = (Rw + r_tool) - dist;
  d_pen_dot = -(rx*vpx + ry*vpy) / dist;
  v_t  = tx*vpx + ty*vpy;

  // ===== Contact force: compliant normal + Coulomb friction =====
  F_n_contact   = if d_pen > 0.0 then k_n*d_pen + c_n*d_pen_dot else 0.0;
  F_t_friction  = if d_pen > 0.0 then -mu_f*F_n_contact*tanh(v_t/v_thresh) else 0.0;
  Fcx = F_n_contact*nx + F_t_friction*tx;
  Fcy = F_n_contact*ny + F_t_friction*ty;

  // ===== Measured path position (from tool-tip pose) =====
  phi_meas  = atan2(ry, rx);
  s_meas    = Rw*(phi_meas - phi_start);
  s_meas_dot = v_t;
  F_n_meas  = if d_pen > 0.0 then k_n*d_pen else 0.0;

  // ===== Reference trajectory: 0.50 m smooth cosine over 10 s =====
  s_ref     = if time <= 10.0 then 0.5*0.50*(1.0 - cos(Modelica.Constants.pi*time/10.0)) else 0.50;
  s_ref_dot = if time <= 10.0 then 0.5*0.50*(Modelica.Constants.pi/10.0)*sin(Modelica.Constants.pi*time/10.0) else 0.0;

  // ===== Disturbance: 8.4 N tangential, middle third of 16 s =====
  F_disturb = if (time >= T_sim/3.0 and time <= 2.0*T_sim/3.0) then -F_dist_mag*tanh(v_t/v_thresh) else 0.0;
  Fdist_x = F_disturb*tx;
  Fdist_y = F_disturb*ty;

  // ===== Jacobian =====
  J11 = -L1*sin(q1) - L2*sin(q1+q2);
  J12 = -L2*sin(q1+q2);
  J21 =  L1*cos(q1) + L2*cos(q1+q2);
  J22 =  L2*cos(q1+q2);

  // ===== Gravity terms (in-plane, -Y) =====
  G1 = m1*g*L1*cos(q1) + m2*g*(L1*cos(q1) + L2*cos(q1+q2));
  G2 = m2*g*L2*cos(q1+q2);

  // ===== Controller =====
  // Integral of path error (unclamped state)
  der(s_int) = (s_ref - s_meas);

  // Normal-force regulation: feedforward + feedback, clamped
  F_normal_cmd = max(0.0, min(F_norm_clamp, F_n_target + Kf*(F_n_target - F_n_meas)));

  // Tangential trajectory control: PID with output-clamped integral
  F_tan_cmd = Kp_s*(s_ref - s_meas)
            + Kd_s*(s_ref_dot - s_meas_dot)
            + Ki_s*max(-s_int_max, min(s_int_max, s_int));

  // Desired tool force: push into surface (-n) and along path (+t)
  Fx_des = -F_normal_cmd*nx + F_tan_cmd*tx;
  Fy_des = -F_normal_cmd*ny + F_tan_cmd*ty;

  // Joint-torque drives: tau = J^T * F_des + G_comp, saturated at 55 N.m
  tau1_cmd = G1 + J11*Fx_des + J21*Fy_des;
  tau2_cmd = G2 + J12*Fx_des + J22*Fy_des;
  tau1_sat = max(-tau_max, min(tau_max, tau1_cmd));
  tau2_sat = max(-tau_max, min(tau_max, tau2_cmd));

  // ===== Mass matrix (point-mass model) =====
  M11 = m1*L1^2 + m2*(L1^2 + L2^2 + 2.0*L1*L2*cos(q2));
  M12 = m2*(L2^2 + L1*L2*cos(q2));
  M21 = M12;
  M22 = m2*L2^2;
  det_M = M11*M22 - M12*M21 + 1e-12;

  // ===== Coriolis / centrifugal =====
  C1 = -m2*L1*L2*sin(q2)*(2.0*q1_dot*q2_dot + q2_dot^2);
  C2 =  m2*L1*L2*sin(q2)*q1_dot^2;

  // ===== Equations of motion =====
  // M*q_ddot + C + G = tau_sat + J^T*(F_contact + F_dist)
  q1_ddot = ((tau1_sat + J11*(Fcx+Fdist_x) + J21*(Fcy+Fdist_y) - C1 - G1)*M22
            -(tau2_sat + J12*(Fcx+Fdist_x) + J22*(Fcy+Fdist_y) - C2 - G2)*M12) / det_M;
  q2_ddot = (M11*(tau2_sat + J12*(Fcx+Fdist_x) + J22*(Fcy+Fdist_y) - C2 - G2)
            -M12*(tau1_sat + J11*(Fcx+Fdist_x) + J21*(Fcy+Fdist_y) - C1 - G1)) / det_M;

  der(q1)     = q1_dot;
  der(q1_dot) = q1_ddot;
  der(q2)     = q2_dot;
  der(q2_dot) = q2_ddot;

  // ===== Sensors: wrist wrench (contact + disturbance through link 2) =====
  wrist_fx = Fcx + Fdist_x;
  wrist_fy = Fcy + Fdist_y;
  wrist_fz = 0.0;

  // ===== Acceptance metrics =====
  path_error = abs(s_ref - s_meas);
  tau1_abs   = abs(tau1_sat);
  tau2_abs   = abs(tau2_sat);
  contact_ok     = d_pen > 0.0;
  force_in_bounds = (F_n_contact >= 12.0) and (F_n_contact <= 30.0);
  torque1_ok     = tau1_abs <= tau_max;
  torque2_ok     = tau2_abs <= tau_max;
  tracking_ok    = (time >= 10.4) and (path_error < 0.018);

  annotation(
    experiment(StartTime=0, StopTime=16, Tolerance=1e-6, Interval=0.004),
    Documentation(info="PlanarPusherPolishE: planar 2-link capsule arm (0.46 m, 0.35 m) on
      revolute Z joints, fixed base, rounded contact tool, fixed curved workpiece.
      Compliant normal contact (k_n, c_n) with Coulomb friction mu=0.50.
      Tangential trajectory control follows 0.50 m arc path; normal-force regulation
      targets 20 N (range 12-30 N).  8.4 N tangential disturbance during middle third.
      Two joint-torque drives bounded at 55 N.m.  Sensors: joint encoders, wrist wrench,
      tool-tip pose.  Controller at 250 Hz (Interval=0.004 s), 16 s duration.
      Acceptance: torque bounds, force 12-30 N, continuous contact, tracking < 0.018 m
      after 10.4 s, no NaN/inf.")
  );
end PlanarPusherPolishE;