model PlanarPusherPolishE
  "Planar 2R pusher-polish system: contact-rich surface following with normal force regulation.";

  // ===== Parameters from requirement =====
  parameter Real L1 = 0.46 "link 1 length [m]";
  parameter Real L2 = 0.35 "link 2 length [m]";
  parameter Real mu = 0.50 "friction coefficient";
  parameter Real tau_max = 55.0 "per-joint command torque bound [N.m]";
  parameter Real F_dist = 8.4 "tangential disturbance magnitude [N]";
  parameter Real path_len = 0.50 "surface path length [m]";
  parameter Real T_run = 16.0 "run time [s]";
  parameter Real Fn_lo = 12.0 "min normal force [N]";
  parameter Real Fn_hi = 30.0 "max normal force [N]";
  parameter Real Fn_des = 20.0 "desired normal force [N]";
  parameter Real track_tol = 0.018 "primary tracking tolerance after 10.4 s [m]";
  parameter Real Ts = 1.0/250.0 "control/sample period [s]";

  // ===== Assumed parameters (not specified by requirement) =====
  parameter Real m1 = 2.0 "link 1 lumped tip mass [kg]";
  parameter Real m2 = 2.0 "link 2 lumped tip mass [kg]";
  parameter Real g = 9.81 "gravity [m/s^2]";
  parameter Real R_w = 0.50 "workpiece arc radius [m]";
  parameter Real Cwx = 0.0 "workpiece center x [m]";
  parameter Real Cwy = 0.60 "workpiece center y [m]";
  parameter Real theta_start = -0.50 "arc start angle [rad]";
  parameter Real k_n = 5000.0 "normal contact stiffness [N/m]";
  parameter Real b_n = 200.0 "normal contact damping [N.s/m]";
  parameter Real Kp1 = 600.0 "joint 1 P gain [N.m/rad]";
  parameter Real Kd1 = 60.0 "joint 1 D gain [N.m.s/rad]";
  parameter Real Kp2 = 600.0 "joint 2 P gain [N.m/rad]";
  parameter Real Kd2 = 60.0 "joint 2 D gain [N.m.s/rad]";
  parameter Real ki_f = 5.0e-4 "force-loop integral gain [m/(N.s)]";
  parameter Real delta_n0 = 0.004 "initial commanded penetration [m]";

  // ===== Continuous states =====
  Real q1(start=1.6722) "joint 1 angle [rad]";
  Real q2(start=2.4597) "joint 2 angle [rad]";
  Real qd1(start=0.0) "joint 1 velocity [rad/s]";
  Real qd2(start=0.0) "joint 2 velocity [rad/s]";

  // ===== Discrete controller states =====
  discrete Real q1_d(start=1.6722) "desired joint 1 angle [rad]";
  discrete Real q2_d(start=2.4597) "desired joint 2 angle [rad]";
  discrete Real delta_n(start=delta_n0) "commanded normal penetration [m]";
  discrete Real Fn_sample(start=Fn_des) "sampled normal force [N]";

  // ===== Kinematics =====
  Real c1 "cos(q1)";
  Real s1 "sin(q1)";
  Real c12 "cos(q1+q2)";
  Real s12 "sin(q1+q2)";
  Real x_tip "tool tip x [m]";
  Real y_tip "tool tip y [m]";
  Real phi_tip "tool tip orientation [rad]";
  Real x_tip_dot "tool tip x velocity [m/s]";
  Real y_tip_dot "tool tip y velocity [m/s]";

  // ===== Contact geometry =====
  Real dx, dy, dist, n_x, n_y, theta_tip, t_x, t_y;
  Real penetration "normal penetration [m]";
  Real radial_vel "radial velocity (outward+) [m/s]";
  Real Fn_raw "raw normal force [N]";
  Real Fn_contact "normal contact force on tool [N]";
  Real v_t "tangential tool speed [m/s]";
  Real Ft_friction "tangential friction force [N]";
  Real Fc_x "contact force x [N]";
  Real Fc_y "contact force y [N]";

  // ===== Disturbance =====
  Real dist_active "disturbance active flag";
  Real s_des "desired arc length [m]";
  Real theta_des "desired angle [rad]";
  Real t_des_x "desired tangential unit x";
  Real t_des_y "desired tangential unit y";
  Real Fdist_x "disturbance force x [N]";
  Real Fdist_y "disturbance force y [N]";

  // ===== External force and joint torque mapping =====
  Real Fext_x "total external tip force x [N]";
  Real Fext_y "total external tip force y [N]";
  Real tau_ext1 "external joint 1 torque [N.m]";
  Real tau_ext2 "external joint 2 torque [N.m]";

  // ===== Desired target =====
  Real P_des_x, P_des_y, n_des_x, n_des_y, P_target_x, P_target_y;

  // ===== Velocity feedforward =====
  Real det_J, det_J_safe, vx_des, vy_des, qd1_d_ff, qd2_d_ff;

  // ===== Gravity =====
  Real G1 "gravity torque joint 1 [N.m]";
  Real G2 "gravity torque joint 2 [N.m]";

  // ===== Controller =====
  Real tau1_raw "raw joint 1 command [N.m]";
  Real tau2_raw "raw joint 2 command [N.m]";
  Real tau1 "applied joint 1 torque [N.m]";
  Real tau2 "applied joint 2 torque [N.m]";

  // ===== Dynamics =====
  Real M11, M12, M22, Cc1, Cc2, qdd1, qdd2;

  // ===== Sensors =====
  Real q1_meas, q2_meas, Fwrist_x, Fwrist_y, tip_pose_x, tip_pose_y, tip_pose_phi;

  // ===== Metrics =====
  Real s_actual, track_err, path_err, Fn_meas;

protected
  discrete Real c2_ik, c2_cl;

equation
  // ---- Kinematics ----
  c1 = cos(q1);
  s1 = sin(q1);
  c12 = cos(q1 + q2);
  s12 = sin(q1 + q2);
  x_tip = L1*c1 + L2*c12;
  y_tip = L1*s1 + L2*s12;
  phi_tip = q1 + q2;
  x_tip_dot = -L1*s1*qd1 - L2*s12*(qd1 + qd2);
  y_tip_dot =  L1*c1*qd1 + L2*c12*(qd1 + qd2);

  // ---- Contact geometry ----
  dx = x_tip - Cwx;
  dy = y_tip - Cwy;
  dist = sqrt(dx*dx + dy*dy + 1.0e-9);
  n_x = dx/dist;
  n_y = dy/dist;
  theta_tip = atan2(dy, dx);
  t_x = cos(theta_tip);
  t_y = sin(theta_tip);
  penetration = max(0.0, R_w - dist);
  radial_vel = (dx*x_tip_dot + dy*y_tip_dot)/dist;
  Fn_raw = k_n*penetration - b_n*radial_vel;
  Fn_contact = max(0.0, Fn_raw);
  v_t = t_x*x_tip_dot + t_y*y_tip_dot;
  Ft_friction = -mu*Fn_contact*tanh(v_t/1.0e-3);
  Fc_x = Fn_contact*n_x + Ft_friction*t_x;
  Fc_y = Fn_contact*n_y + Ft_friction*t_y;

  // ---- Disturbance (middle third, opposing desired motion) ----
  dist_active = if (time >= T_run/3.0 and time <= 2.0*T_run/3.0) then 1.0 else 0.0;
  s_des = path_len*max(0.0, min(1.0, time/T_run));
  theta_des = theta_start + s_des/R_w;
  t_des_x = cos(theta_des);
  t_des_y = sin(theta_des);
  Fdist_x = -F_dist*t_des_x*dist_active;
  Fdist_y = -F_dist*t_des_y*dist_active;

  // ---- External force and Jacobian-transpose mapping ----
  Fext_x = Fc_x + Fdist_x;
  Fext_y = Fc_y + Fdist_y;
  tau_ext1 = (-L1*s1 - L2*s12)*Fext_x + (L1*c1 + L2*c12)*Fext_y;
  tau_ext2 = (-L2*s12)*Fext_x + (L2*c12)*Fext_y;

  // ---- Desired target (continuous; uses discrete delta_n) ----
  P_des_x = Cwx + R_w*sin(theta_des);
  P_des_y = Cwy - R_w*cos(theta_des);
  n_des_x = sin(theta_des);
  n_des_y = -cos(theta_des);
  P_target_x = P_des_x - delta_n*n_des_x;
  P_target_y = P_des_y - delta_n*n_des_y;

  // ---- Velocity feedforward ----
  det_J = L1*L2*sin(q2);
  det_J_safe = max(0.01, det_J);
  vx_des = (path_len/T_run)*t_des_x;
  vy_des = (path_len/T_run)*t_des_y;
  qd1_d_ff = (L2*c12*vx_des + L2*s12*vy_des)/det_J_safe;
  qd2_d_ff = (-(L1*c1 + L2*c12)*vx_des - (L1*s1 + L2*s12)*vy_des)/det_J_safe;

  // ---- Gravity compensation ----
  G1 = (m1 + m2)*g*L1*cos(q1) + m2*g*L2*cos(q1 + q2);
  G2 = m2*g*L2*cos(q1 + q2);

  // ---- Controller (continuous PD + gravity comp + velocity ff) ----
  tau1_raw = Kp1*(q1_d - q1) + Kd1*(qd1_d_ff - qd1) + G1;
  tau2_raw = Kp2*(q2_d - q2) + Kd2*(qd2_d_ff - qd2) + G2;
  tau1 = max(-tau_max, min(tau_max, tau1_raw));
  tau2 = max(-tau_max, min(tau_max, tau2_raw));

  // ---- Plant dynamics (point-mass 2R) ----
  M11 = m1*L1^2 + m2*(L1^2 + L2^2 + 2.0*L1*L2*cos(q2));
  M12 = m2*(L2^2 + L1*L2*cos(q2));
  M22 = m2*L2^2;
  Cc1 = -m2*L1*L2*sin(q2)*(2.0*qd1*qd2 + qd2^2);
  Cc2 =  m2*L1*L2*sin(q2)*qd1^2;
  M11*qdd1 + M12*qdd2 + Cc1 + G1 = tau1 + tau_ext1;
  M12*qdd1 + M22*qdd2 + Cc2 + G2 = tau2 + tau_ext2;
  der(q1) = qd1;
  der(q2) = qd2;
  der(qd1) = qdd1;
  der(qd2) = qdd2;

  // ---- Sensors ----
  q1_meas = q1;
  q2_meas = q2;
  Fwrist_x = Fext_x;
  Fwrist_y = Fext_y;
  tip_pose_x = x_tip;
  tip_pose_y = y_tip;
  tip_pose_phi = phi_tip;

  // ---- Metrics ----
  s_actual = (theta_tip - theta_start)*R_w;
  track_err = abs(s_des - s_actual);
  path_err = abs(dist - R_w);
  Fn_meas = Fn_contact;

  // ---- Discrete controller update at 250 Hz ----
  when sample(0, Ts) then
    Fn_sample = Fn_contact;
    delta_n = pre(delta_n) + ki_f*(Fn_des - Fn_sample)*Ts;
    c2_ik = (P_target_x^2 + P_target_y^2 - L1^2 - L2^2)/(2.0*L1*L2);
    c2_cl = max(-0.9999, min(0.9999, c2_ik));
    q2_d = acos(c2_cl);
    q1_d = atan2(P_target_y, P_target_x) - atan2(L2*sin(q2_d), L1 + L2*cos(q2_d));
  end when;

  // ===== Acceptance (fail-closed) =====
  // Joint and effort bounds
  assert(abs(q1) < 10.0, "Joint 1 angle out of bounds");
  assert(abs(q2) < 10.0, "Joint 2 angle out of bounds");
  assert(abs(tau1) <= tau_max + 1.0e-6, "Joint 1 effort bound violated");
  assert(abs(tau2) <= tau_max + 1.0e-6, "Joint 2 effort bound violated");
  // Normal force in [12,30] N after initial settling
  assert(time <= 0.5 or (Fn_contact >= Fn_lo and Fn_contact <= Fn_hi),
         "Normal force out of [12,30] N");
  // Continuous contact
  assert(time <= 0.5 or penetration > 0.0, "Continuous contact lost");
  // Path error bounded
  assert(time <= 0.5 or path_err < 0.01, "Path error too large");
  // Primary tracking error after 10.4 s
  assert(time <= 10.4 or track_err < track_tol,
         "Primary tracking error exceeded 0.018 m");
  // No NaN or infinite values (physical, control, estimator)
  assert(q1 > -1.0e9 and q1 < 1.0e9, "q1 NaN/inf");
  assert(q2 > -1.0e9 and q2 < 1.0e9, "q2 NaN/inf");
  assert(qd1 > -1.0e9 and qd1 < 1.0e9, "qd1 NaN/inf");
  assert(qd2 > -1.0e9 and qd2 < 1.0e9, "qd2 NaN/inf");
  assert(Fn_contact > -1.0e9 and Fn_contact < 1.0e9, "Fn NaN/inf");
  assert(tau1 > -1.0e9 and tau1 < 1.0e9, "tau1 NaN/inf");
  assert(tau2 > -1.0e9 and tau2 < 1.0e9, "tau2 NaN/inf");
  assert(delta_n > -1.0e9 and delta_n < 1.0e9, "delta_n NaN/inf");
  assert(track_err >= 0.0 and track_err < 1.0e9, "track_err NaN/inf");

  annotation (
    experiment(StopTime = 16.0, Tolerance = 1.0e-6, Interval = 0.004),
    Documentation(info="Planar 2R pusher-polish system. 0.46 m and 0.35 m capsule links on revolute Z joints with a rounded contact tool, following a 0.50 m curved workpiece path at 250 Hz for 16 s with normal force regulation and an 8.4 N middle-third tangential disturbance. Workpiece curvature, link masses, contact stiffness/damping, and control gains are assumed (not specified by the requirement)."));
end PlanarPusherPolishE;