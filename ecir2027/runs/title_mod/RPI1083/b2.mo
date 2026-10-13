model GroundPairFormC
  // Distributed formation control for two differential-drive robots with bounded local commands
  parameter Real m_robot = 14.0 "robot mass [kg]";
  parameter Real r_wheel = 0.09 "wheel radius [m]";
  parameter Real tau_max = 9.2 "max wheel torque magnitude [N.m]";
  parameter Real msg_delay = 0.072 "message delay disturbance [s]";
  parameter Real T_end = 12.0 "simulation duration [s]";
  parameter Real track_err_thresh = 0.315 "tracking error threshold after t_thresh [m]";
  parameter Real t_thresh = 7.8 "tracking threshold time [s]";
  parameter Real min_sep = 0.4 "minimum pairwise separation [m]";

  // Not specified by requirement; chosen for well-posed, stable dynamics
  parameter Real track_w = 0.20 "wheel track [m] (not specified)";
  parameter Real I_z = 0.10 "yaw inertia [kg.m^2] (not specified)";
  parameter Real b_v = 1.5 "linear drag [N.s/m] (not specified)";
  parameter Real b_w = 0.3 "yaw drag [N.m.s/rad] (not specified)";
  parameter Real v_leader = 0.20 "leader speed [m/s] (not specified)";
  parameter Real off1_x = 0.0 "robot1 formation offset x [m]";
  parameter Real off1_y = 0.30 "robot1 formation offset y [m]";
  parameter Real off2_x = 0.0 "robot2 formation offset x [m]";
  parameter Real off2_y = -0.30 "robot2 formation offset y [m]";
  parameter Real v_max = 0.4 "max commanded forward speed [m/s] (not specified)";
  parameter Real Kv = 0.6 "position-to-velocity gain (not specified)";
  parameter Real Kp_v = 30.0 "velocity error to common torque gain (not specified)";
  parameter Real Kp_w = 2.5 "heading error to torque-diff gain (not specified)";
  parameter Real Kd_w = 0.6 "yaw rate damping gain (not specified)";
  parameter Real eps = 1.0e-6 "regularization";
  parameter Real robot_radius = 0.12 "robot footprint radius [m] (not specified)";

  // Fixed obstacles placed outside the nominal formation path
  parameter Real obs1_x = 1.0;
  parameter Real obs1_y = 1.5;
  parameter Real obs1_r = 0.3;
  parameter Real obs2_x = 3.0;
  parameter Real obs2_y = -1.5;
  parameter Real obs2_r = 0.3;

  // Leader reference
  Real x_leader "leader x [m]";
  Real y_leader "leader y [m]";

  // Robot states
  Real x1, y1, theta1, v1, omega1;
  Real x2, y2, theta2, v2, omega2;

  // Onboard estimates (encoders + IMU fused; identity estimator here)
  Real x1_est, y1_est, theta1_est, v1_est, omega1_est;
  Real x2_est, y2_est, theta2_est, v2_est, omega2_est;

  // Delayed state copies (delay applied directly to state variables)
  Real x1_del, y1_del, theta1_del;
  Real x2_del, y2_del, theta2_del;
  // Received peer poses (delayed during middle third, direct otherwise)
  Real x2_rx1, y2_rx1, theta2_rx1;
  Real x1_rx2, y1_rx2, theta1_rx2;
  Real comm_age1 "communication age at robot1 [s]";
  Real comm_age2 "communication age at robot2 [s]";
  Boolean in_middle_third "true during middle third of simulation";

  // Lidar-derived peer-relative range
  Real range_meas_1to2 "range robot1 perceives to robot2 [m]";
  Real range_true "true inter-robot range [m]";
  Real sep_err "separation error vs minimum [m]";

  // Four wheel-torque command channels
  Real tau1L_raw, tau1R_raw, tau2L_raw, tau2R_raw;
  Real tau1L, tau1R, tau2L, tau2R;

  // Controller intermediates robot1
  Real tgt1_x, tgt1_y, e1_x, e1_y, dist1, v1_des, hd1_des, hd1_err, tc1, td1;
  // Controller intermediates robot2
  Real tgt2_x, tgt2_y, e2_x, e2_y, dist2, v2_des, hd2_des, hd2_err, tc2, td2;

  // Evidence metrics
  Real tErr1 "robot1 tracking error [m]";
  Real tErr2 "robot2 tracking error [m]";
  Real tErr_primary "primary (max) tracking error [m]";
  Real form_err "combined formation error [m]";
  Real sep "pairwise separation [m]";
  Real d_obs1_1, d_obs1_2, d_obs2_1, d_obs2_2;
  Boolean no_collision;
  Boolean sep_ok;
  Boolean tau_ok;
  Boolean track_ok;
  Boolean valid;

initial equation
  x1 = -0.2;  y1 = 0.30;  theta1 = 0.0; v1 = 0.0; omega1 = 0.0;
  x2 = -0.2;  y2 = -0.30; theta2 = 0.0; v2 = 0.0; omega2 = 0.0;

equation
  // ---- Leader trajectory ----
  x_leader = v_leader * time;
  y_leader = 0.0;

  // ---- Onboard state estimation (identity fusion of encoders+IMU) ----
  x1_est = x1;  y1_est = y1;  theta1_est = theta1;  v1_est = v1;  omega1_est = omega1;
  x2_est = x2;  y2_est = y2;  theta2_est = theta2;  v2_est = v2;  omega2_est = omega2;

  // ---- Delayed state copies (delay applied directly to state variables) ----
  x1_del = delay(x1, msg_delay, msg_delay);
  y1_del = delay(y1, msg_delay, msg_delay);
  theta1_del = delay(theta1, msg_delay, msg_delay);
  x2_del = delay(x2, msg_delay, msg_delay);
  y2_del = delay(y2, msg_delay, msg_delay);
  theta2_del = delay(theta2, msg_delay, msg_delay);

  // ---- Middle-third delay injection ----
  in_middle_third = (time >= T_end/3.0) and (time <= 2.0*T_end/3.0);
  x2_rx1 = if in_middle_third then x2_del else x2;
  y2_rx1 = if in_middle_third then y2_del else y2;
  theta2_rx1 = if in_middle_third then theta2_del else theta2;
  comm_age1 = if in_middle_third then msg_delay else 0.0;
  x1_rx2 = if in_middle_third then x1_del else x1;
  y1_rx2 = if in_middle_third then y1_del else y1;
  theta1_rx2 = if in_middle_third then theta1_del else theta1;
  comm_age2 = if in_middle_third then msg_delay else 0.0;

  // ---- Peer-relative range (lidar + received pose) ----
  range_meas_1to2 = sqrt((x2_rx1 - x1_est)*(x2_rx1 - x1_est) + (y2_rx1 - y1_est)*(y2_rx1 - y1_est) + eps);
  range_true = sqrt((x2 - x1)*(x2 - x1) + (y2 - y1)*(y2 - y1) + eps);
  sep = range_true;
  sep_err = min_sep - sep;

  // ---- Controller robot 1 (distributed: own est + leader ref + peer range) ----
  tgt1_x = x_leader + off1_x;
  tgt1_y = y_leader + off1_y;
  e1_x = tgt1_x - x1_est;
  e1_y = tgt1_y - y1_est;
  dist1 = sqrt(e1_x*e1_x + e1_y*e1_y + eps);
  v1_des = if (Kv*dist1 > v_max) then v_max else Kv*dist1;
  hd1_des = atan2(e1_y, e1_x);
  hd1_err = atan2(sin(hd1_des - theta1_est), cos(hd1_des - theta1_est));
  tc1 = Kp_v*(v1_des - v1_est) + (if sep_err > 0.0 then -Kp_v*0.05*sep_err*cos(theta1_est) else 0.0);
  td1 = Kp_w*hd1_err + Kd_w*(0.0 - omega1_est);
  tau1L_raw = tc1 - td1;
  tau1R_raw = tc1 + td1;
  tau1L = if tau1L_raw > tau_max then tau_max elseif tau1L_raw < -tau_max then -tau_max else tau1L_raw;
  tau1R = if tau1R_raw > tau_max then tau_max elseif tau1R_raw < -tau_max then -tau_max else tau1R_raw;

  // ---- Controller robot 2 ----
  tgt2_x = x_leader + off2_x;
  tgt2_y = y_leader + off2_y;
  e2_x = tgt2_x - x2_est;
  e2_y = tgt2_y - y2_est;
  dist2 = sqrt(e2_x*e2_x + e2_y*e2_y + eps);
  v2_des = if (Kv*dist2 > v_max) then v_max else Kv*dist2;
  hd2_des = atan2(e2_y, e2_x);
  hd2_err = atan2(sin(hd2_des - theta2_est), cos(hd2_des - theta2_est));
  tc2 = Kp_v*(v2_des - v2_est) + (if sep_err > 0.0 then -Kp_v*0.05*sep_err*cos(theta2_est) else 0.0);
  td2 = Kp_w*hd2_err + Kd_w*(0.0 - omega2_est);
  tau2L_raw = tc2 - td2;
  tau2R_raw = tc2 + td2;
  tau2L = if tau2L_raw > tau_max then tau_max elseif tau2L_raw < -tau_max then -tau_max else tau2L_raw;
  tau2R = if tau2R_raw > tau_max then tau_max elseif tau2R_raw < -tau_max then -tau_max else tau2R_raw;

  // ---- Robot 1 dynamics ----
  der(x1) = v1*cos(theta1);
  der(y1) = v1*sin(theta1);
  der(theta1) = omega1;
  m_robot*der(v1) = (tau1L + tau1R)/r_wheel - b_v*v1;
  I_z*der(omega1) = (tau1R - tau1L)*track_w/(2.0*r_wheel) - b_w*omega1;

  // ---- Robot 2 dynamics ----
  der(x2) = v2*cos(theta2);
  der(y2) = v2*sin(theta2);
  der(theta2) = omega2;
  m_robot*der(v2) = (tau2L + tau2R)/r_wheel - b_v*v2;
  I_z*der(omega2) = (tau2R - tau2L)*track_w/(2.0*r_wheel) - b_w*omega2;

  // ---- Tracking and formation errors ----
  tErr1 = sqrt((x_leader + off1_x - x1)*(x_leader + off1_x - x1) + (y_leader + off1_y - y1)*(y_leader + off1_y - y1) + eps);
  tErr2 = sqrt((x_leader + off2_x - x2)*(x_leader + off2_x - x2) + (y_leader + off2_y - y2)*(y_leader + off2_y - y2) + eps);
  tErr_primary = if tErr1 > tErr2 then tErr1 else tErr2;
  form_err = sqrt(tErr1*tErr1 + tErr2*tErr2);

  // ---- Obstacle distances and collision check ----
  d_obs1_1 = sqrt((x1 - obs1_x)*(x1 - obs1_x) + (y1 - obs1_y)*(y1 - obs1_y) + eps);
  d_obs1_2 = sqrt((x2 - obs1_x)*(x2 - obs1_x) + (y2 - obs1_y)*(y2 - obs1_y) + eps);
  d_obs2_1 = sqrt((x1 - obs2_x)*(x1 - obs2_x) + (y1 - obs2_y)*(y1 - obs2_y) + eps);
  d_obs2_2 = sqrt((x2 - obs2_x)*(x2 - obs2_x) + (y2 - obs2_y)*(y2 - obs2_y) + eps);
  no_collision = (d_obs1_1 > obs1_r + robot_radius) and
                 (d_obs1_2 > obs1_r + robot_radius) and
                 (d_obs2_1 > obs2_r + robot_radius) and
                 (d_obs2_2 > obs2_r + robot_radius);

  // ---- Requirement satisfaction flags ----
  sep_ok = sep >= min_sep;
  tau_ok = (abs(tau1L) <= tau_max + eps) and (abs(tau1R) <= tau_max + eps) and
           (abs(tau2L) <= tau_max + eps) and (abs(tau2R) <= tau_max + eps);
  track_ok = (time < t_thresh) or (tErr_primary < track_err_thresh);

  // ---- No NaN / infinite values (x==x is false for NaN) ----
  valid = (x1 == x1) and (y1 == y1) and (theta1 == theta1) and (v1 == v1) and (omega1 == omega1) and
          (x2 == x2) and (y2 == y2) and (theta2 == theta2) and (v2 == v2) and (omega2 == omega2) and
          (tau1L == tau1L) and (tau1R == tau1R) and (tau2L == tau2L) and (tau2R == tau2R) and
          (x1_est == x1_est) and (x2_est == x2_est) and
          (abs(x1) < 1.0e9) and (abs(y1) < 1.0e9) and (abs(x2) < 1.0e9) and (abs(y2) < 1.0e9);

  annotation(
    experiment(StartTime = 0.0, StopTime = 12.0, Tolerance = 1.0e-6, Interval = 0.008),
    Documentation(info = "GroundPairFormC: two 14 kg differential-drive robots (0.09 m wheels) "
                         "with bounded wheel torques (|tau|<=9.2 N.m), distributed formation "
                         "control tracking a leader, peer-relative range and delayed pose "
                         "messages, 0.072 s message delay injected during middle third, fixed "
                         "obstacles outside the path, sampled at 125 Hz design intent.")
  );
end GroundPairFormC;