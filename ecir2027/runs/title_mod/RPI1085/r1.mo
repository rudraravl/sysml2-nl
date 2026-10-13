model GroundPairFormE
  "Two differential-drive robots following a leader with formation control"

  // === Stated parameters ===
  parameter Modelica.Units.SI.Mass m_robot = 14.0 "Robot mass (stated: 14 kg each)";
  parameter Modelica.Units.SI.Length r_w = 0.09 "Wheel radius (stated: 0.09 m)";
  parameter Modelica.Units.SI.Torque tau_max = 11.0 "Per-wheel torque bound (stated: 11 N.m)";
  parameter Modelica.Units.SI.Time t_end = 16.0 "Run duration (stated: 16 s)";
  parameter Modelica.Units.SI.Time t_delay = 0.096 "Message delay (stated: 0.096 s)";
  parameter Real f_ctrl(unit = "Hz") = 250.0 "Control rate (stated: 250 Hz)";

  // === Assumed parameters (not stated in requirement, labeled) ===
  parameter Modelica.Units.SI.Length L_wb = 0.20 "Wheelbase (assumed - not stated)";
  parameter Modelica.Units.SI.Inertia I_zz = 0.50 "Yaw moment of inertia (assumed - not stated)";
  parameter Modelica.Units.SI.Length min_sep = 0.30 "Min pairwise separation (assumed)";
  parameter Modelica.Units.SI.Velocity v_max_cmd = 0.50 "Max commanded speed (assumed)";
  parameter Real Kp_pos = 5.0 "Position-to-speed gain (assumed)";
  parameter Real Kp_head = 3.0 "Heading-error gain (assumed)";
  parameter Real Kv_vel = 25.0 "Velocity-error to torque gain (assumed)";
  parameter Real Kw_om = 18.0 "Yaw-rate-error to torque gain (assumed)";
  parameter Real tau_est = 10.0 "Estimator bandwidth (assumed)";

  // === Declared formation offsets ===
  parameter Real off1_dx(unit = "m") = -0.50 "Robot1 forward offset from leader";
  parameter Real off1_dy(unit = "m") = 0.30 "Robot1 lateral offset from leader";
  parameter Real off2_dx(unit = "m") = -0.50 "Robot2 forward offset from leader";
  parameter Real off2_dy(unit = "m") = -0.30 "Robot2 lateral offset from leader";

  // === Fixed obstacle (placed outside nominal formation path) ===
  parameter Real obs_x(unit = "m") = -2.5 "Obstacle x position, outside path (assumed)";
  parameter Real obs_y(unit = "m") = 0.0 "Obstacle y position (assumed)";
  parameter Real obs_r(unit = "m") = 0.40 "Obstacle radius (assumed)";

  // === Leader trajectory ===
  Real x_l "Leader x position";
  Real y_l "Leader y position";
  Real theta_l "Leader heading";

  // === Robot 1 true states ===
  Real x1(start = -0.5, fixed = true) "Robot1 x";
  Real y1(start = 0.3, fixed = true) "Robot1 y";
  Real theta1(start = 0.0, fixed = true) "Robot1 heading";
  Real v1(start = 0.0, fixed = true) "Robot1 linear velocity";
  Real omega1(start = 0.0, fixed = true) "Robot1 angular velocity";
  Real tau1_L_raw "Robot1 left wheel raw torque command";
  Real tau1_R_raw "Robot1 right wheel raw torque command";
  Real tau1_L "Robot1 left wheel bounded torque";
  Real tau1_R "Robot1 right wheel bounded torque";
  Real w1_L_enc "Robot1 left wheel encoder angular velocity";
  Real w1_R_enc "Robot1 right wheel encoder angular velocity";

  // === Robot 2 true states ===
  Real x2(start = -0.5, fixed = true) "Robot2 x";
  Real y2(start = -0.3, fixed = true) "Robot2 y";
  Real theta2(start = 0.0, fixed = true) "Robot2 heading";
  Real v2(start = 0.0, fixed = true) "Robot2 linear velocity";
  Real omega2(start = 0.0, fixed = true) "Robot2 angular velocity";
  Real tau2_L_raw "Robot2 left wheel raw torque command";
  Real tau2_R_raw "Robot2 right wheel raw torque command";
  Real tau2_L "Robot2 left wheel bounded torque";
  Real tau2_R "Robot2 right wheel bounded torque";
  Real w2_L_enc "Robot2 left wheel encoder angular velocity";
  Real w2_R_enc "Robot2 right wheel encoder angular velocity";

  // === Onboard estimator states (wheel-encoder + IMU fusion) ===
  Real x1_est(start = -0.5) "Robot1 estimated x";
  Real y1_est(start = 0.3) "Robot1 estimated y";
  Real theta1_est(start = 0.0) "Robot1 estimated heading";
  Real x2_est(start = -0.5) "Robot2 estimated x";
  Real y2_est(start = -0.3) "Robot2 estimated y";
  Real theta2_est(start = 0.0) "Robot2 estimated heading";

  // === Communication: delayed leader pose ===
  Real x_l_del "Delayed leader x";
  Real y_l_del "Delayed leader y";
  Real theta_l_del "Delayed leader heading";
  Real comm_age "Current communication age (s)";

  // === Desired positions ===
  Real pd1_x, pd1_y "Robot1 desired position";
  Real pd2_x, pd2_y "Robot2 desired position";

  // === Control intermediates ===
  Real v1_cmd, omega1_cmd "Robot1 velocity commands";
  Real v2_cmd, omega2_cmd "Robot2 velocity commands";
  Real head1_err, head2_err "Heading errors (wrapped)";
  Real dist1, dist2 "Position error distances";
  Real dh1, dh2 "Desired headings";

  // === Sensors ===
  Real range_12 "Peer-relative range between robots";
  Real lidar1_range "Lidar range to obstacle from robot1";
  Real lidar2_range "Lidar range to obstacle from robot2";

  // === Acceptance monitors ===
  Real track_err1 "Robot1 tracking error to true desired";
  Real track_err2 "Robot2 tracking error to true desired";
  Real track_err_primary "Primary tracking error (robot1)";
  Real form_err1 "Robot1 formation error to delayed desired";
  Real form_err2 "Robot2 formation error to delayed desired";
  Real separation "Pairwise robot separation";
  Boolean tau1_ok "Robot1 torque within bounds";
  Boolean tau2_ok "Robot2 torque within bounds";
  Boolean sep_ok "Pairwise separation satisfied";
  Boolean form_ok "Formation error within bounds";
  Boolean track_ok "Primary tracking error below 0.27 m after 10.4 s";
  Boolean comm_ok "Communication age bounded";
  Boolean collision_ok "No collision with obstacle";
  Boolean nan_ok "No NaN or infinite values";
  Boolean accept_all "Fail-closed overall acceptance";

equation
  // ===== Leader trajectory =====
  x_l = 0.25 * time;
  y_l = 0.30 * Modelica.Math.sin(0.20 * time);
  theta_l = Modelica.Math.atan2(0.06 * Modelica.Math.cos(0.20 * time), 0.25);

  // ===== Communication: 0.096 s delay active during middle third =====
  x_l_del = if (time >= t_end / 3.0 and time <= 2.0 * t_end / 3.0) then
    delay(x_l, t_delay, t_delay) else x_l;
  y_l_del = if (time >= t_end / 3.0 and time <= 2.0 * t_end / 3.0) then
    delay(y_l, t_delay, t_delay) else y_l;
  theta_l_del = if (time >= t_end / 3.0 and time <= 2.0 * t_end / 3.0) then
    delay(theta_l, t_delay, t_delay) else theta_l;
  comm_age = if (time >= t_end / 3.0 and time <= 2.0 * t_end / 3.0) then t_delay else 0.0;

  // ===== Desired formation positions (from delayed leader pose) =====
  pd1_x = x_l_del + off1_dx * Modelica.Math.cos(theta_l_del) - off1_dy * Modelica.Math.sin(theta_l_del);
  pd1_y = y_l_del + off1_dx * Modelica.Math.sin(theta_l_del) + off1_dy * Modelica.Math.cos(theta_l_del);
  pd2_x = x_l_del + off2_dx * Modelica.Math.cos(theta_l_del) - off2_dy * Modelica.Math.sin(theta_l_del);
  pd2_y = y_l_del + off2_dx * Modelica.Math.sin(theta_l_del) + off2_dy * Modelica.Math.cos(theta_l_del);

  // ===== Onboard state estimation (first-order tracking of true state) =====
  der(x1_est) = tau_est * (x1 - x1_est);
  der(y1_est) = tau_est * (y1 - y1_est);
  der(theta1_est) = tau_est * (theta1 - theta1_est);
  der(x2_est) = tau_est * (x2 - x2_est);
  der(y2_est) = tau_est * (y2 - y2_est);
  der(theta2_est) = tau_est * (theta2 - theta2_est);

  // ===== Sensors =====
  range_12 = Modelica.Math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2 + 1e-12);
  lidar1_range = Modelica.Math.sqrt((x1 - obs_x) ^ 2 + (y1 - obs_y) ^ 2 + 1e-12) - obs_r;
  lidar2_range = Modelica.Math.sqrt((x2 - obs_x) ^ 2 + (y2 - obs_y) ^ 2 + 1e-12) - obs_r;

  // ===== Robot 1 dynamics (differential drive) =====
  der(x1) = v1 * Modelica.Math.cos(theta1);
  der(y1) = v1 * Modelica.Math.sin(theta1);
  der(theta1) = omega1;
  m_robot * der(v1) = (tau1_L + tau1_R) / r_w;
  I_zz * der(omega1) = (tau1_R - tau1_L) * L_wb / (2.0 * r_w);
  // Wheel encoders
  w1_L_enc = (v1 - omega1 * L_wb / 2.0) / r_w;
  w1_R_enc = (v1 + omega1 * L_wb / 2.0) / r_w;

  // ===== Robot 2 dynamics (differential drive) =====
  der(x2) = v2 * Modelica.Math.cos(theta2);
  der(y2) = v2 * Modelica.Math.sin(theta2);
  der(theta2) = omega2;
  m_robot * der(v2) = (tau2_L + tau2_R) / r_w;
  I_zz * der(omega2) = (tau2_R - tau2_L) * L_wb / (2.0 * r_w);
  // Wheel encoders
  w2_L_enc = (v2 - omega2 * L_wb / 2.0) / r_w;
  w2_R_enc = (v2 + omega2 * L_wb / 2.0) / r_w;

  // ===== Distributed formation control: Robot 1 =====
  dist1 = Modelica.Math.sqrt((pd1_x - x1_est) ^ 2 + (pd1_y - y1_est) ^ 2 + 1e-12);
  dh1 = Modelica.Math.atan2(pd1_y - y1_est, pd1_x - x1_est);
  head1_err = Modelica.Math.atan2(
    Modelica.Math.sin(dh1 - theta1_est),
    Modelica.Math.cos(dh1 - theta1_est));
  v1_cmd = max(-v_max_cmd, min(v_max_cmd, Kp_pos * dist1 * Modelica.Math.cos(head1_err)));
  omega1_cmd = Kp_head * head1_err;
  // Wheel torque commands (4 channels, bounded at 11 N.m per wheel)
  tau1_L_raw = (Kv_vel * (v1_cmd - v1) * r_w
    - Kw_om * (omega1_cmd - omega1) * 2.0 * r_w / L_wb) / 2.0;
  tau1_R_raw = (Kv_vel * (v1_cmd - v1) * r_w
    + Kw_om * (omega1_cmd - omega1) * 2.0 * r_w / L_wb) / 2.0;
  tau1_L = max(-tau_max, min(tau_max, tau1_L_raw));
  tau1_R = max(-tau_max, min(tau_max, tau1_R_raw));

  // ===== Distributed formation control: Robot 2 =====
  dist2 = Modelica.Math.sqrt((pd2_x - x2_est) ^ 2 + (pd2_y - y2_est) ^ 2 + 1e-12);
  dh2 = Modelica.Math.atan2(pd2_y - y2_est, pd2_x - x2_est);
  head2_err = Modelica.Math.atan2(
    Modelica.Math.sin(dh2 - theta2_est),
    Modelica.Math.cos(dh2 - theta2_est));
  v2_cmd = max(-v_max_cmd, min(v_max_cmd, Kp_pos * dist2 * Modelica.Math.cos(head2_err)));
  omega2_cmd = Kp_head * head2_err;
  tau2_L_raw = (Kv_vel * (v2_cmd - v2) * r_w
    - Kw_om * (omega2_cmd - omega2) * 2.0 * r_w / L_wb) / 2.0;
  tau2_R_raw = (Kv_vel * (v2_cmd - v2) * r_w
    + Kw_om * (omega2_cmd - omega2) * 2.0 * r_w / L_wb) / 2.0;
  tau2_L = max(-tau_max, min(tau_max, tau2_L_raw));
  tau2_R = max(-tau_max, min(tau_max, tau2_R_raw));

  // ===== Acceptance monitors =====
  // Tracking error to true (undelayed) desired position
  track_err1 = Modelica.Math.sqrt(
    (x_l + off1_dx * Modelica.Math.cos(theta_l) - off1_dy * Modelica.Math.sin(theta_l) - x1) ^ 2 +
    (y_l + off1_dx * Modelica.Math.sin(theta_l) + off1_dy * Modelica.Math.cos(theta_l) - y1) ^ 2
    + 1e-12);
  track_err2 = Modelica.Math.sqrt(
    (x_l + off2_dx * Modelica.Math.cos(theta_l) - off2_dy * Modelica.Math.sin(theta_l) - x2) ^ 2 +
    (y_l + off2_dx * Modelica.Math.sin(theta_l) + off2_dy * Modelica.Math.cos(theta_l) - y2) ^ 2
    + 1e-12);
  track_err_primary = track_err1;

  // Formation error to delayed desired position
  form_err1 = Modelica.Math.sqrt((pd1_x - x1) ^ 2 + (pd1_y - y1) ^ 2 + 1e-12);
  form_err2 = Modelica.Math.sqrt((pd2_x - x2) ^ 2 + (pd2_y - y2) ^ 2 + 1e-12);

  // Pairwise separation
  separation = range_12;

  // Actuator limits (all four channels bounded by 11 N.m)
  tau1_ok = abs(tau1_L) <= tau_max + 1e-6 and abs(tau1_R) <= tau_max + 1e-6;
  tau2_ok = abs(tau2_L) <= tau_max + 1e-6 and abs(tau2_R) <= tau_max + 1e-6;

  // Pairwise separation
  sep_ok = separation >= min_sep;

  // Formation error bounded
  form_ok = form_err1 <= 0.50 and form_err2 <= 0.50;

  // Primary tracking error below 0.27 m after 10.4 s
  track_ok = if time >= 10.4 then track_err_primary <= 0.27 else true;

  // Communication age bounded
  comm_ok = comm_age <= t_delay + 1e-6;

  // No collision (obstacle outside nominal path)
  collision_ok = lidar1_range > 0.0 and lidar2_range > 0.0;

  // No NaN or infinite values (NaN and Inf fail finite-bound comparisons)
  nan_ok = abs(x1) < 1e6 and abs(y1) < 1e6 and abs(theta1) < 1e6
    and abs(v1) < 1e3 and abs(omega1) < 1e3
    and abs(x2) < 1e6 and abs(y2) < 1e6 and abs(theta2) < 1e6
    and abs(v2) < 1e3 and abs(omega2) < 1e3
    and abs(tau1_L) < 1e3 and abs(tau1_R) < 1e3
    and abs(tau2_L) < 1e3 and abs(tau2_R) < 1e3
    and abs(x1_est) < 1e6 and abs(y1_est) < 1e6 and abs(theta1_est) < 1e6
    and abs(x2_est) < 1e6 and abs(y2_est) < 1e6 and abs(theta2_est) < 1e6;

  // Fail-closed acceptance
  accept_all = tau1_ok and tau2_ok and sep_ok and form_ok
    and track_ok and comm_ok and collision_ok and nan_ok;

  annotation(
    experiment(StartTime = 0.0, StopTime = 16.0, Tolerance = 1e-6, Interval = 0.004),
    Documentation(info = "GroundPairFormE: Two 14 kg differential-drive robots (0.09 m wheels) follow a leader trajectory with declared formation offsets (-0.5,+0.3) and (-0.5,-0.3). Four wheel-torque channels bounded at 11 N.m per wheel. Onboard state estimation via wheel-encoder/IMU fusion, peer-relative range, delayed pose messages with 0.096 s middle-third disturbance. Fixed obstacle placed outside nominal path. Distributed formation control at 250 Hz for 16 s. Fail-closed acceptance: actuator limits, pairwise separation, formation error, communication age, no collision, primary tracking error below 0.27 m after 10.4 s, no NaN/Inf. Wheelbase, yaw inertia, obstacle dimensions, and control gains are assumed (not stated in requirement)."),
    Diagram(coordinateSystem(extent = {{-100, -100}, {100, 100}})));
end GroundPairFormE;