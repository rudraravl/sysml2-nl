model PlanarPusherPolishE
  "Planar 2R pusher-polish: contact-rich surface following with normal force regulation";

  // === Parameters from requirement ===
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

  // === Assumed parameters (not specified by requirement) ===
  parameter Real m1 = 2.0 "link 1 lumped tip mass [kg]";
  parameter Real m2 = 2.0 "link 2 lumped tip mass [kg]";
  parameter Real g_acc = 9.81 "gravity [m/s^2]";
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

  // === Continuous states ===
  Real q1(start=1.6722) "joint 1 angle [rad]";
  Real q2(start=2.4597) "joint 2 angle [rad]";
  Real qd1(start=0.0) "joint 1 velocity [rad/s]";
  Real qd2(start=0.0) "joint 2 velocity [rad/s]";

  // === Discrete controller state ===
  discrete Real delta_n(start=0.004) "commanded normal penetration [m]";

  // === Kinematics ===
  Real x_tip "tool tip x [m]";
  Real y_tip "tool tip y [m]";
  Real tip_phi "tool tip orientation [rad]";
  Real x_tip_dot "tool tip x velocity [m/s]";
  Real y_tip_dot "tool tip y velocity [m/s]";

  // === Contact ===
  Real dx "tip-to-center x [m]";
  Real dy "tip-to-center y [m]";
  Real dist "tip-to-center distance [m]";
  Real nx "outward normal x";
  Real ny "outward normal y";
  Real tx "tangent x";
  Real ty "tangent y";
  Real penetration "normal penetration [m]";
  Real radial_vel "outward radial velocity [m/s]";
  Real Fn_raw "raw normal force [N]";
  Real Fn_contact "normal contact force [N]";
  Real v_t "tangential speed [m/s]";
  Real Ft "friction force [N]";
  Real Fc_x "contact force x [N]";
  Real Fc_y "contact force y [N]";

  // === Trajectory and disturbance ===
  Real s_des "desired arc length [m]";
  Real theta_des "desired arc angle [rad]";
  Real tdx "desired tangent x";
  Real tdy "desired tangent y";
  Real ndx "desired normal x";
  Real ndy "desired normal y";
  Real dist_flag "disturbance active flag";
  Real Fdist_x "disturbance force x [N]";
  Real Fdist_y "disturbance force y [N]";

  // === Force mapping ===
  Real Fext_x "total external tip force x [N]";
  Real Fext_y "total external tip force y [N]";
  Real tau_ext1 "external joint 1 torque [N.m]";
  Real tau_ext2 "external joint 2 torque [N.m]";

  // === Target ===
  Real Px "target x [m]";
  Real Py "target y [m]";

  // === Feedforward ===
  Real det_J "Jacobian determinant";
  Real det_J_safe "safe Jacobian determinant";
  Real vx_ff "feedforward x velocity [m/s]";
  Real vy_ff "feedforward y velocity [m/s]";
  Real qd1_ff "feedforward joint 1 velocity [rad/s]";
  Real qd2_ff "feedforward joint 2 velocity [rad/s]";

  // === Gravity ===
  Real G1 "gravity torque joint 1 [N.m]";
  Real G2 "gravity torque joint 2 [N.m]";

  // === Controller ===
  Real q1_d "desired joint 1 angle [rad]";
  Real q2_d "desired joint 2 angle [rad]";
  Real tau1_raw "raw joint 1 command [N.m]";
  Real tau2_raw "raw joint 2 command [N.m]";
  Real tau1 "applied joint 1 torque [N.m]";
  Real tau2 "applied joint 2 torque [N.m]";

  // === Dynamics ===
  Real M11 "mass matrix [1,1]";
  Real M12 "mass matrix [1,2]";
  Real M22 "mass matrix [2,2]";
  Real Cc1 "Coriolis joint 1 [N.m]";
  Real Cc2 "Coriolis joint 2 [N.m]";
  Real det_M "mass matrix determinant";
  Real qdd1 "joint 1 acceleration [rad/s^2]";
  Real qdd2 "joint 2 acceleration [rad/s^2]";

  // === Sensors ===
  Real q1_meas "measured joint 1 [rad]";
  Real q2_meas "measured joint 2 [rad]";
  Real Fwrist_x "wrist force x [N]";
  Real Fwrist_y "wrist force y [N]";
  Real tip_pose_x "tip pose x [m]";
  Real tip_pose_y "tip pose y [m]";
  Real tip_pose_phi "tip pose orientation [rad]";

  // === Metrics ===
  Real theta_actual "actual arc angle [rad]";
  Real s_actual "actual arc length [m]";
  Real track_err "tracking error [m]";
  Real path_err "path error [m]";
  Real Fn_meas "measured normal force [N]";

equation
  // --- Kinematics ---
  x_tip = L1*cos(q1) + L2*cos(q1+q2);
  y_tip = L1*sin(q1) + L2*sin(q1+q2);
  tip_phi = q1 + q2;
  x_tip_dot = -L1*sin(q1)*qd1 - L2*sin(q1+q2)*(qd1+qd2);
  y_tip_dot = L1*cos(q1)*qd1 + L2*cos(q1+q2)*(qd1+qd2);

  // --- Contact geometry ---
  dx = x_tip - Cwx;
  dy = y_tip - Cwy;
  dist = sqrt(dx*dx + dy*dy + 1.0e-9);
  nx = dx/dist;
  ny = dy/dist;
  tx = -ny;
  ty = nx;
  penetration = max(0.0, R_w - dist);
  radial_vel = (dx*x_tip_dot + dy*y_tip_dot)/dist;
  Fn_raw = k_n*penetration - b_n*radial_vel;
  Fn_contact = max(0.0, Fn_raw);
  v_t = tx*x_tip_dot + ty*y_tip_dot;
  Ft = -mu*Fn_contact*tanh(v_t/1.0e-3);
  Fc_x = -Fn_contact*nx + Ft*tx;
  Fc_y = -Fn_contact*ny + Ft*ty;

  // --- Trajectory ---
  s_des = path_len*max(0.0, min(1.0, time/T_run));
  theta_des = theta_start + s_des/R_w;
  tdx = cos(theta_des);
  tdy = sin(theta_des);
  ndx = sin(theta_des);
  ndy = -cos(theta_des);

  // --- Disturbance (middle third) ---
  dist_flag = if time >= T_run/3.0 and time <= 2.0*T_run/3.0 then 1.0 else 0.0;
  Fdist_x = -F_dist*tdx*dist_flag;
  Fdist_y = -F_dist*tdy*dist_flag;

  // --- External force and Jacobian transpose ---
  Fext_x = Fc_x + Fdist_x;
  Fext_y = Fc_y + Fdist_y;
  tau_ext1 = (-L1*sin(q1) - L2*sin(q1+q2))*Fext_x + (L1*cos(q1) + L2*cos(q1+q2))*Fext_y;
  tau_ext2 = (-L2*sin(q1+q2))*Fext_x + (L2*cos(q1+q2))*Fext_y;

  // --- Target (offset inward by delta_n) ---
  Px = Cwx + R_w*sin(theta_des) - delta_n*ndx;
  Py = Cwy - R_w*cos(theta_des) - delta_n*ndy;

  // --- Inverse kinematics (continuous desired joint angles) ---
  q2_d = acos(max(-0.9999, min(0.9999, (Px*Px + Py*Py - L1*L1 - L2*L2)/(2.0*L1*L2))));
  q1_d = atan2(Py, Px) - atan2(L2*sin(q2_d), L1 + L2*cos(q2_d));

  // --- Velocity feedforward ---
  det_J = L1*L2*sin(q2);
  det_J_safe = noEvent(if abs(det_J) < 0.01 then 0.01 else det_J);
  vx_ff = (path_len/T_run)*tdx;
  vy_ff = (path_len/T_run)*tdy;
  qd1_ff = (L2*cos(q1+q2)*vx_ff + L2*sin(q1+q2)*vy_ff)/det_J_safe;
  qd2_ff = (-(L1*cos(q1)+L2*cos(q1+q2))*vx_ff - (L1*sin(q1)+L2*sin(q1+q2))*vy_ff)/det_J_safe;

  // --- Gravity compensation ---
  G1 = (m1+m2)*g_acc*L1*cos(q1) + m2*g_acc*L2*cos(q1+q2);
  G2 = m2*g_acc*L2*cos(q1+q2);

  // --- Controller (PD + gravity comp + velocity ff) ---
  tau1_raw = Kp1*(q1_d - q1) + Kd1*(qd1_ff - qd1) + G1;
  tau2_raw = Kp2*(q2_d - q2) + Kd2*(qd2_ff - qd2) + G2;
  tau1 = max(-tau_max, min(tau_max, tau1_raw));
  tau2 = max(-tau_max, min(tau_max, tau2_raw));

  // --- Plant dynamics (2R point-mass, explicit inversion) ---
  M11 = m1*L1*L1 + m2*(L1*L1 + L2*L2 + 2.0*L1*L2*cos(q2));
  M12 = m2*(L2*L2 + L1*L2*cos(q2));
  M22 = m2*L2*L2;
  Cc1 = -m2*L1*L2*sin(q2)*(2.0*qd1*qd2 + qd2*qd2);
  Cc2 = m2*L1*L2*sin(q2)*qd1*qd1;
  det_M = M11*M22 - M12*M12;
  qdd1 = (M22*(tau1 + tau_ext1 - Cc1 - G1) - M12*(tau2 + tau_ext2 - Cc2 - G2))/(det_M + 1.0e-6);
  qdd2 = (M11*(tau2 + tau_ext2 - Cc2 - G2) - M12*(tau1 + tau_ext1 - Cc1 - G1))/(det_M + 1.0e-6);
  der(q1) = qd1;
  der(q2) = qd2;
  der(qd1) = qdd1;
  der(qd2) = qdd2;

  // --- Sensors ---
  q1_meas = q1;
  q2_meas = q2;
  Fwrist_x = Fext_x;
  Fwrist_y = Fext_y;
  tip_pose_x = x_tip;
  tip_pose_y = y_tip;
  tip_pose_phi = tip_phi;

  // --- Metrics ---
  theta_actual = atan2(dx, -dy);
  s_actual = (theta_actual - theta_start)*R_w;
  track_err = abs(s_des - s_actual);
  path_err = abs(dist - R_w);
  Fn_meas = Fn_contact;

  // --- Discrete force regulator at 250 Hz ---
  when sample(0, 0.004) then
    delta_n = pre(delta_n) + ki_f*(Fn_des - Fn_contact)*0.004;
  end when;

  // --- Acceptance (fail-closed) ---
  assert(abs(q1) < 10.0, "Joint 1 angle out of bounds");
  assert(abs(q2) < 10.0, "Joint 2 angle out of bounds");
  assert(abs(tau1) <= tau_max + 1.0e-6, "Joint 1 effort bound violated");
  assert(abs(tau2) <= tau_max + 1.0e-6, "Joint 2 effort bound violated");
  assert(time <= 0.5 or (Fn_contact >= Fn_lo and Fn_contact <= Fn_hi),
         "Normal force out of [12,30] N");
  assert(time <= 0.5 or penetration > 0.0, "Continuous contact lost");
  assert(time <= 0.5 or path_err < 0.01, "Path error too large");
  assert(time <= 10.4 or track_err < track_tol,
         "Primary tracking error exceeded 0.018 m");
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
    Documentation(info="Planar 2R pusher-polish system. 0.46 m and 0.35 m capsule links on revolute Z joints with rounded contact tool, following a 0.50 m curved workpiece path at 250 Hz for 16 s with normal force regulation and 8.4 N middle-third tangential disturbance. Workpiece curvature, link masses, contact stiffness/damping, and control gains are assumed (not specified by requirement)."));
end PlanarPusherPolishE;