model GroundTrioFormB
  "Three 18 kg differential-drive warehouse robots in triangular formation following a leader trajectory with bounded wheel torques, distributed formation control, delayed peer messages, and obstacle checks."

  // ===== Physical parameters =====
  parameter Real m_robot  = 18.0  "robot mass [kg]";
  parameter Real Izz      = 0.18  "yaw inertia [kg.m2] (assumed — not specified)";
  parameter Real r_wheel  = 0.05  "wheel radius [m] (assumed — not specified)";
  parameter Real d_wheel  = 0.40  "wheel separation [m] (assumed — not specified)";
  parameter Real tau_max  = 9.84  "max wheel command torque [N.m]";
  parameter Real mu_v     = 1.5   "linear damping [1/s] (assumed)";
  parameter Real mu_w     = 1.2   "rotational damping [1/s] (assumed)";
  parameter Real robot_radius = 0.30 "robot footprint radius [m] (assumed)";

  // ===== Formation and control gains =====
  parameter Real d_form   = 1.50  "nominal formation side length [m] (assumed)";
  parameter Real kp_v     = 1.2   "along-track position gain (assumed)";
  parameter Real kp_w     = 2.5   "heading gain (assumed)";
  parameter Real kv_cmd   = 3.0   "velocity command gain (assumed)";
  parameter Real kw_cmd   = 3.0   "heading command gain (assumed)";
  parameter Real sqrt3_half = 0.866025403784439 "sqrt(3)/2";

  // ===== Communication parameters =====
  parameter Real delay_nominal = 0.0    "nominal peer-message delay [s]";
  parameter Real delay_disturb = 0.056  "disturbance peer-message delay [s]";
  parameter Real delay_max    = 0.20   "delay buffer ceiling [s]";

  // ===== Mission parameters =====
  parameter Real T_end = 10.0 "mission duration [s]";

  // ===== Obstacles (placed outside nominal path) =====
  parameter Real obs1_x = -3.0 "obstacle 1 x [m] (assumed, outside path)";
  parameter Real obs1_y = -3.0 "obstacle 1 y [m]";
  parameter Real obs1_r = 0.50 "obstacle 1 radius [m] (assumed)";
  parameter Real obs2_x = 8.0  "obstacle 2 x [m] (assumed, outside path)";
  parameter Real obs2_y = 4.0  "obstacle 2 y [m]";
  parameter Real obs2_r = 0.50 "obstacle 2 radius [m] (assumed)";

  // ===== Robot 1 states (leader follower) =====
  Real x1(start=0.0)  "robot 1 x [m]";
  Real y1(start=0.0)  "robot 1 y [m]";
  Real th1(start=0.0) "robot 1 heading [rad]";
  Real v1(start=0.0)  "robot 1 linear speed [m/s]";
  Real w1(start=0.0)  "robot 1 angular speed [rad/s]";

  // ===== Robot 2 states =====
  Real x2(start=-1.50) "robot 2 x [m]";
  Real y2(start=0.0)   "robot 2 y [m]";
  Real th2(start=0.0)  "robot 2 heading [rad]";
  Real v2(start=0.0)   "robot 2 linear speed [m/s]";
  Real w2(start=0.0)   "robot 2 angular speed [rad/s]";

  // ===== Robot 3 states =====
  Real x3(start=-0.75) "robot 3 x [m]";
  Real y3(start=1.299) "robot 3 y [m]";
  Real th3(start=0.0)  "robot 3 heading [rad]";
  Real v3(start=0.0)   "robot 3 linear speed [m/s]";
  Real w3(start=0.0)   "robot 3 angular speed [rad/s]";

  // ===== Wheel torque commands (bounded) =====
  Real tau_L1_raw, tau_R1_raw "unbounded robot 1 wheel torques [N.m]";
  Real tau_L2_raw, tau_R2_raw "unbounded robot 2 wheel torques [N.m]";
  Real tau_L3_raw, tau_R3_raw "unbounded robot 3 wheel torques [N.m]";
  Real tau_L1, tau_R1 "bounded robot 1 wheel torques [N.m]";
  Real tau_L2, tau_R2 "bounded robot 2 wheel torques [N.m]";
  Real tau_L3, tau_R3 "bounded robot 3 wheel torques [N.m]";

  // ===== Control intermediates =====
  Real v_cmd1, w_cmd1 "robot 1 desired speed [m/s], yaw rate [rad/s]";
  Real v_cmd2, w_cmd2 "robot 2 desired speed [m/s], yaw rate [rad/s]";
  Real v_cmd3, w_cmd3 "robot 3 desired speed [m/s], yaw rate [rad/s]";
  Real F1, M1 "robot 1 desired force [N], moment [N.m]";
  Real F2, M2 "robot 2 desired force [N], moment [N.m]";
  Real F3, M3 "robot 3 desired force [N], moment [N.m]";
  Real xd2, yd2 "robot 2 desired position from delayed leader [m]";
  Real xd3, yd3 "robot 3 desired position from delayed leader [m]";
  Real th_des2, th_des3 "desired heading robots 2, 3 [rad]";
  Real d_th2, d_th3 "wrapped heading error robots 2, 3 [rad]";

  // ===== Reference trajectory =====
  Real x_ref  "reference x [m]";
  Real y_ref  "reference y [m]";
  Real th_ref "reference heading [rad]";
  Real v_ref  "reference speed [m/s]";

  // ===== Delayed peer messages =====
  Real x1d, y1d, th1d, v1d, w1d "delayed robot 1 state received by peers";
  Real x2d, y2d, th2d "delayed robot 2 pose received by peers";
  Real x3d, y3d, th3d "delayed robot 3 pose received by peers";
  Real delay_time "current applied communication delay [s]";
  Boolean middle_third "true during middle-third disturbance window";

  // ===== Lidar peer-relative ranges =====
  Real range12 "robot 1-2 range [m]";
  Real range13 "robot 1-3 range [m]";
  Real range23 "robot 2-3 range [m]";

  // ===== Performance metrics =====
  Real track_err1 "primary tracking error (robot 1 to ref) [m]";
  Real form_err2  "robot 2 formation error [m]";
  Real form_err3  "robot 3 formation error [m]";
  Real sep12, sep13, sep23 "pairwise separations [m]";
  Real min_sep    "minimum pairwise separation [m]";
  Real comm_age   "current communication age [s]";
  Real obs_dist_min "minimum robot-obstacle distance [m]";
  Boolean no_collision "true if no collision risk";
  Boolean req_track   "true if tracking error < 0.36 m after 6.5 s";
  Boolean actuator_ok "true if all raw commands within bounds";

  // ===== Obstacle distances =====
  Real do1_r1, do1_r2, do1_r3 "distance to obstacle 1 [m]";
  Real do2_r1, do2_r2, do2_r3 "distance to obstacle 2 [m]";

equation
  // ===== Reference trajectory (leader path) =====
  x_ref  = 1.5 * time;
  y_ref  = 0.4 * sin(0.5 * time);
  th_ref = atan2(0.4 * 0.5 * cos(0.5 * time), 1.5);
  v_ref  = sqrt(1.5 * 1.5 + (0.4 * 0.5 * cos(0.5 * time)) * (0.4 * 0.5 * cos(0.5 * time)));

  // ===== Delay schedule =====
  middle_third = (time >= T_end / 3.0) and (time <= 2.0 * T_end / 3.0);
  delay_time   = if middle_third then delay_disturb else delay_nominal;

  // ===== Delayed peer states (variable-delay communication) =====
  x1d  = delay(x1,  delay_time, delay_max);
  y1d  = delay(y1,  delay_time, delay_max);
  th1d = delay(th1, delay_time, delay_max);
  v1d  = delay(v1,  delay_time, delay_max);
  w1d  = delay(w1,  delay_time, delay_max);
  x2d  = delay(x2,  delay_time, delay_max);
  y2d  = delay(y2,  delay_time, delay_max);
  th2d = delay(th2, delay_time, delay_max);
  x3d  = delay(x3,  delay_time, delay_max);
  y3d  = delay(y3,  delay_time, delay_max);
  th3d = delay(th3, delay_time, delay_max);

  // ===== Robot 1 dynamics =====
  der(x1)  = v1 * cos(th1);
  der(y1)  = v1 * sin(th1);
  der(th1) = w1;
  der(v1)  = (tau_L1 + tau_R1) / (r_wheel * m_robot) - mu_v * v1;
  der(w1)  = (tau_R1 - tau_L1) * d_wheel / (2.0 * r_wheel * Izz) - mu_w * w1;

  // ===== Robot 2 dynamics =====
  der(x2)  = v2 * cos(th2);
  der(y2)  = v2 * sin(th2);
  der(th2) = w2;
  der(v2)  = (tau_L2 + tau_R2) / (r_wheel * m_robot) - mu_v * v2;
  der(w2)  = (tau_R2 - tau_L2) * d_wheel / (2.0 * r_wheel * Izz) - mu_w * w2;

  // ===== Robot 3 dynamics =====
  der(x3)  = v3 * cos(th3);
  der(y3)  = v3 * sin(th3);
  der(th3) = w3;
  der(v3)  = (tau_L3 + tau_R3) / (r_wheel * m_robot) - mu_v * v3;
  der(w3)  = (tau_R3 - tau_L3) * d_wheel / (2.0 * r_wheel * Izz) - mu_w * w3;

  // ===== Robot 1 control: track reference trajectory =====
  v_cmd1 = v_ref + kp_v * ((x_ref - x1) * cos(th1) + (y_ref - y1) * sin(th1));
  w_cmd1 = kp_w * atan2(sin(th_ref - th1), cos(th_ref - th1));
  F1 = m_robot * (kv_cmd * (v_cmd1 - v1) + mu_v * v1);
  M1 = Izz * (kw_cmd * (w_cmd1 - w1) + mu_w * w1);
  tau_L1_raw = r_wheel * (F1 / 2.0 - M1 / d_wheel);
  tau_R1_raw = r_wheel * (F1 / 2.0 + M1 / d_wheel);
  tau_L1 = if tau_L1_raw >  tau_max then  tau_max
           else if tau_L1_raw < -tau_max then -tau_max
           else tau_L1_raw;
  tau_R1 = if tau_R1_raw >  tau_max then  tau_max
           else if tau_R1_raw < -tau_max then -tau_max
           else tau_R1_raw;

  // ===== Robot 2 control: formation following (delayed leader pose) =====
  xd2 = x1d - d_form * cos(th1d);
  yd2 = y1d - d_form * sin(th1d);
  th_des2 = atan2(yd2 - y2, xd2 - x2);
  d_th2   = atan2(sin(th_des2 - th2), cos(th_des2 - th2));
  v_cmd2  = v1d + kp_v * ((xd2 - x2) * cos(th2) + (yd2 - y2) * sin(th2));
  w_cmd2  = kp_w * d_th2;
  F2 = m_robot * (kv_cmd * (v_cmd2 - v2) + mu_v * v2);
  M2 = Izz * (kw_cmd * (w_cmd2 - w2) + mu_w * w2);
  tau_L2_raw = r_wheel * (F2 / 2.0 - M2 / d_wheel);
  tau_R2_raw = r_wheel * (F2 / 2.0 + M2 / d_wheel);
  tau_L2 = if tau_L2_raw >  tau_max then  tau_max
           else if tau_L2_raw < -tau_max then -tau_max
           else tau_L2_raw;
  tau_R2 = if tau_R2_raw >  tau_max then  tau_max
           else if tau_R2_raw < -tau_max then -tau_max
           else tau_R2_raw;

  // ===== Robot 3 control: formation following (delayed leader pose) =====
  xd3 = x1d - (d_form / 2.0) * cos(th1d) - (d_form * sqrt3_half) * sin(th1d);
  yd3 = y1d - (d_form / 2.0) * sin(th1d) + (d_form * sqrt3_half) * cos(th1d);
  th_des3 = atan2(yd3 - y3, xd3 - x3);
  d_th3   = atan2(sin(th_des3 - th3), cos(th_des3 - th3));
  v_cmd3  = v1d + kp_v * ((xd3 - x3) * cos(th3) + (yd3 - y3) * sin(th3));
  w_cmd3  = kp_w * d_th3;
  F3 = m_robot * (kv_cmd * (v_cmd3 - v3) + mu_v * v3);
  M3 = Izz * (kw_cmd * (w_cmd3 - w3) + mu_w * w3);
  tau_L3_raw = r_wheel * (F3 / 2.0 - M3 / d_wheel);
  tau_R3_raw = r_wheel * (F3 / 2.0 + M3 / d_wheel);
  tau_L3 = if tau_L3_raw >  tau_max then  tau_max
           else if tau_L3_raw < -tau_max then -tau_max
           else tau_L3_raw;
  tau_R3 = if tau_R3_raw >  tau_max then  tau_max
           else if tau_R3_raw < -tau_max then -tau_max
           else tau_R3_raw;

  // ===== Lidar peer-relative ranges (instantaneous onboard sensor) =====
  range12 = sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2) + 1e-9);
  range13 = sqrt((x1 - x3) * (x1 - x3) + (y1 - y3) * (y1 - y3) + 1e-9);
  range23 = sqrt((x2 - x3) * (x2 - x3) + (y2 - y3) * (y2 - y3) + 1e-9);

  // ===== Pairwise separations =====
  sep12 = range12;
  sep13 = range13;
  sep23 = range23;
  min_sep = min(sep12, min(sep13, sep23));

  // ===== Formation errors (measured against actual leader pose) =====
  track_err1 = sqrt((x_ref - x1) * (x_ref - x1) + (y_ref - y1) * (y_ref - y1) + 1e-9);
  form_err2  = sqrt((x1 - d_form * cos(th1) - x2) * (x1 - d_form * cos(th1) - x2) +
                    (y1 - d_form * sin(th1) - y2) * (y1 - d_form * sin(th1) - y2) + 1e-9);
  form_err3  = sqrt((x1 - (d_form / 2.0) * cos(th1) - (d_form * sqrt3_half) * sin(th1) - x3) *
                    (x1 - (d_form / 2.0) * cos(th1) - (d_form * sqrt3_half) * sin(th1) - x3) +
                    (y1 - (d_form / 2.0) * sin(th1) + (d_form * sqrt3_half) * cos(th1) - y3) *
                    (y1 - (d_form / 2.0) * sin(th1) + (d_form * sqrt3_half) * cos(th1) - y3) + 1e-9);

  // ===== Communication age =====
  comm_age = delay_time;

  // ===== Obstacle distances =====
  do1_r1 = sqrt((x1 - obs1_x) * (x1 - obs1_x) + (y1 - obs1_y) * (y1 - obs1_y) + 1e-9);
  do1_r2 = sqrt((x2 - obs1_x) * (x2 - obs1_x) + (y2 - obs1_y) * (y2 - obs1_y) + 1e-9);
  do1_r3 = sqrt((x3 - obs1_x) * (x3 - obs1_x) + (y3 - obs1_y) * (y3 - obs1_y) + 1e-9);
  do2_r1 = sqrt((x1 - obs2_x) * (x1 - obs2_x) + (y1 - obs2_y) * (y1 - obs2_y) + 1e-9);
  do2_r2 = sqrt((x2 - obs2_x) * (x2 - obs2_x) + (y2 - obs2_y) * (y2 - obs2_y) + 1e-9);
  do2_r3 = sqrt((x3 - obs2_x) * (x3 - obs2_x) + (y3 - obs2_y) * (y3 - obs2_y) + 1e-9);
  obs_dist_min = min(do1_r1, min(do1_r2, min(do1_r3, min(do2_r1, min(do2_r2, do2_r3)))));

  // ===== Collision check =====
  no_collision = (min_sep > 2.0 * robot_radius) and
                 (do1_r1 > robot_radius + obs1_r) and (do1_r2 > robot_radius + obs1_r) and (do1_r3 > robot_radius + obs1_r) and
                 (do2_r1 > robot_radius + obs2_r) and (do2_r2 > robot_radius + obs2_r) and (do2_r3 > robot_radius + obs2_r);

  // ===== Tracking requirement =====
  req_track = (time > 6.5) and (track_err1 < 0.36);

  // ===== Actuator limit check =====
  actuator_ok = (abs(tau_L1_raw) <= tau_max + 1e-6) and (abs(tau_R1_raw) <= tau_max + 1e-6) and
                (abs(tau_L2_raw) <= tau_max + 1e-6) and (abs(tau_R2_raw) <= tau_max + 1e-6) and
                (abs(tau_L3_raw) <= tau_max + 1e-6) and (abs(tau_R3_raw) <= tau_max + 1e-6);

  annotation(
    experiment(StartTime = 0.0, StopTime = 10.0, Interval = 0.01, Tolerance = 1e-6),
    Documentation(info = "GroundTrioFormB: three 18 kg differential-drive warehouse robots in equilateral-triangle formation following a leader reference at 100 Hz for 10 s. Each robot has two bounded wheel drives (9.84 N.m max). Distributed formation control: robot 1 tracks the reference; robots 2 and 3 maintain body-frame offsets relative to the delayed leader pose. A 0.056 s message delay is injected during the middle third (3.33-6.67 s). Lidar provides instantaneous peer-relative ranges; delayed pose messages are communicated. Fixed obstacles are placed outside the nominal path. Onboard state estimation is assumed ideal (estimated state = true state). Parameters not specified in the requirement (wheel radius, inertia, damping, gains, obstacle geometry) are marked as assumed."));
end GroundTrioFormB;