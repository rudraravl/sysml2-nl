model MarinePairCoordinateA "Two-AUV marine coordination with decentralized intersection reservation"

  // ===== Physical parameters (given or derived) =====
  parameter Real m_robot = 80.0 "AUV mass [kg]";
  parameter Real Fmax = 75.6 "Per-thruster force limit [N]";
  parameter Real depth_nominal = 1.0 "Nominal operating depth [m] (assumed; not specified in request)";
  parameter Real drag = 0.5 "Linear drag coefficient [N.s/m] (assumed; not specified in request)";

  // ===== Route / corridor geometry (assumed; not specified in request) =====
  parameter Real x1_start = -2.0 "AUV1 start x [m]";
  parameter Real x1_target = 2.0 "AUV1 target x [m]";
  parameter Real y2_start = -2.0 "AUV2 start y [m]";
  parameter Real y2_target = 2.0 "AUV2 target y [m]";
  parameter Real R_zone = 1.0 "Intersection reservation zone radius [m]";
  parameter Real R_hold = 1.5 "Holding point distance from intersection [m]";

  // ===== Controller parameters (assumed; not specified in request) =====
  parameter Real v_cruise = 1.0 "Cruise speed reference [m/s]";
  parameter Real d_brake = 1.0 "Braking distance for velocity reference [m]";
  parameter Real Kv = 50.0 "Along-track velocity gain [N.s/m]";
  parameter Real Kp_cross = 20.0 "Cross-track position gain [N/m]";
  parameter Real Kd_cross = 30.0 "Cross-track damping gain [N.s/m]";
  parameter Real tau_safe = 1.0 "Reservation time margin [s]";
  parameter Real tau_est = 0.05 "Estimator time constant [s]";
  parameter Real v_eps = 0.05 "Velocity threshold for ETA [m/s]";

  // ===== Scenario parameters (from request) =====
  parameter Real t_final = 8.0 "Scenario duration [s]";
  parameter Real dt = 0.0125 "Sample interval [s] (80 Hz)";
  parameter Real t_mid_start = 8.0/3.0 "Middle third start [s]";
  parameter Real t_mid_end = 16.0/3.0 "Middle third end [s]";
  parameter Real delay_time = 0.06 "Acoustic modem message delay [s]";
  parameter Real t_check = 5.2 "Tracking error check time [s]";
  parameter Real track_err_limit = 0.878 "Tracking error limit [m]";

  // ===== AUV1 physical states =====
  Real x1(start = x1_start, fixed = true) "AUV1 x position [m]";
  Real y1(start = 0.0, fixed = true) "AUV1 y position [m]";
  Real vx1(start = 0.0, fixed = true) "AUV1 x velocity [m/s]";
  Real vy1(start = 0.0, fixed = true) "AUV1 y velocity [m/s]";

  // ===== AUV2 physical states =====
  Real x2(start = 0.0, fixed = true) "AUV2 x position [m]";
  Real y2(start = y2_start, fixed = true) "AUV2 y position [m]";
  Real vx2(start = 0.0, fixed = true) "AUV2 x velocity [m/s]";
  Real vy2(start = 0.0, fixed = true) "AUV2 y velocity [m/s]";

  // ===== Eight bidirectional thruster channels =====
  Real u1 "AUV1 surge thruster 1 [N]";
  Real u2 "AUV1 surge thruster 2 [N]";
  Real u3 "AUV1 heave thruster 1 [N]";
  Real u4 "AUV1 heave thruster 2 [N]";
  Real u5 "AUV2 surge thruster 1 [N]";
  Real u6 "AUV2 surge thruster 2 [N]";
  Real u7 "AUV2 heave thruster 1 [N]";
  Real u8 "AUV2 heave thruster 2 [N]";

  // ===== Net forces =====
  Real Fx1 "AUV1 net x force [N]";
  Real Fy1 "AUV1 net y force [N]";
  Real Fx2 "AUV2 net x force [N]";
  Real Fy2 "AUV2 net y force [N]";

  // ===== Controller variables =====
  Real s_ref1 "AUV1 along-track reference [m]";
  Real s_ref2 "AUV2 along-track reference [m]";
  Real v_ref1 "AUV1 velocity reference [m/s]";
  Real v_ref2 "AUV2 velocity reference [m/s]";
  Real F_along1_cmd "AUV1 along-track force command [N]";
  Real F_cross1_cmd "AUV1 cross-track force command [N]";
  Real F_along2_cmd "AUV2 along-track force command [N]";
  Real F_cross2_cmd "AUV2 cross-track force command [N]";
  Boolean yield2 "AUV2 yielding flag";
  Boolean cleared1_remote "AUV1 cleared zone from AUV2 perspective";

  // ===== Onboard localization estimator states =====
  Real est_x1(start = x1_start, fixed = true) "AUV1 estimated x [m]";
  Real est_y1(start = 0.0, fixed = true) "AUV1 estimated y [m]";
  Real est_vx1(start = 0.0, fixed = true) "AUV1 estimated vx [m/s]";
  Real est_vy1(start = 0.0, fixed = true) "AUV1 estimated vy [m/s]";
  Real est_x2(start = 0.0, fixed = true) "AUV2 estimated x [m]";
  Real est_y2(start = y2_start, fixed = true) "AUV2 estimated y [m]";
  Real est_vx2(start = 0.0, fixed = true) "AUV2 estimated vx [m/s]";
  Real est_vy2(start = 0.0, fixed = true) "AUV2 estimated vy [m/s]";

  // ===== ETA and delayed acoustic modem =====
  Real t_eta1 "AUV1 ETA to intersection [s]";
  Real t_eta2 "AUV2 ETA to intersection [s]";
  Real x1_msg_delayed "AUV1 x delayed [m]";
  Real vx1_msg_delayed "AUV1 vx delayed [m/s]";
  Real eta1_msg_delayed "AUV1 ETA delayed [s]";
  Real y2_msg_delayed "AUV2 y delayed [m]";
  Real x1_msg_received "AUV1 x received by AUV2 [m]";
  Real vx1_msg_received "AUV1 vx received by AUV2 [m/s]";
  Real eta1_msg_received "AUV1 ETA received by AUV2 [s]";
  Real y2_msg_received "AUV2 y received by AUV1 [m]";
  Boolean in_middle_third "Middle third of scenario flag";

  // ===== Sensor outputs =====
  Real imu_ax1 "AUV1 IMU accel x [m/s2]";
  Real imu_ay1 "AUV1 IMU accel y [m/s2]";
  Real imu_ax2 "AUV2 IMU accel x [m/s2]";
  Real imu_ay2 "AUV2 IMU accel y [m/s2]";
  Real depth1 "AUV1 pressure depth [m]";
  Real depth2 "AUV2 pressure depth [m]";
  Real dvl_vx1 "AUV1 DVL vx [m/s]";
  Real dvl_vy1 "AUV1 DVL vy [m/s]";
  Real dvl_vx2 "AUV2 DVL vx [m/s]";
  Real dvl_vy2 "AUV2 DVL vy [m/s]";

  // ===== Metrics and requirement checks =====
  Real sep_dist "Inter-AUV separation [m]";
  Real min_dist(start = 100.0) "Running minimum distance [m]";
  Real track_err1 "AUV1 tracking error [m]";
  Real track_err2 "AUV2 tracking error [m]";
  Real waiting_time(start = 0.0, fixed = true) "AUV2 accumulated waiting time [s]";
  Boolean in_zone1 "AUV1 in intersection zone";
  Boolean in_zone2 "AUV2 in intersection zone";
  Boolean mutual_exclusion_ok "Mutual exclusion satisfied";
  Boolean no_collision_flag "No collision flag";
  Boolean route1_done "AUV1 route complete";
  Boolean route2_done "AUV2 route complete";
  Boolean actuator_bounded "All actuators within bounds";
  Boolean tracking_ok "Tracking error within limit after check time";
  Boolean min_dist_ok "Minimum distance above safety threshold";

equation
  // ===== AUV1 dynamics =====
  der(x1) = vx1;
  der(y1) = vy1;
  der(vx1) = (Fx1 - drag * vx1) / m_robot;
  der(vy1) = (Fy1 - drag * vy1) / m_robot;

  // ===== AUV2 dynamics =====
  der(x2) = vx2;
  der(y2) = vy2;
  der(vx2) = (Fx2 - drag * vx2) / m_robot;
  der(vy2) = (Fy2 - drag * vy2) / m_robot;

  // ===== Net thruster forces (8 channels) =====
  Fx1 = u1 + u2;
  Fy1 = u3 + u4;
  Fx2 = u5 + u6;
  Fy2 = u7 + u8;

  // ===== Onboard estimator (first-order tracking filter) =====
  der(est_x1) = (x1 - est_x1) / tau_est;
  der(est_y1) = (y1 - est_y1) / tau_est;
  der(est_vx1) = (vx1 - est_vx1) / tau_est;
  der(est_vy1) = (vy1 - est_vy1) / tau_est;
  der(est_x2) = (x2 - est_x2) / tau_est;
  der(est_y2) = (y2 - est_y2) / tau_est;
  der(est_vx2) = (vx2 - est_vx2) / tau_est;
  der(est_vy2) = (vy2 - est_vy2) / tau_est;

  // ===== ETA to intersection (guarded division) =====
  if est_vx1 > v_eps and est_x1 < 0.0 then
    t_eta1 = (-est_x1) / est_vx1;
  else
    t_eta1 = 100.0;
  end if;

  if est_vy2 > v_eps and est_y2 < 0.0 then
    t_eta2 = (-est_y2) / est_vy2;
  else
    t_eta2 = 100.0;
  end if;

  // ===== Delayed acoustic modem (pure delay) =====
  x1_msg_delayed = delay(est_x1, delay_time);
  vx1_msg_delayed = delay(est_vx1, delay_time);
  eta1_msg_delayed = delay(t_eta1, delay_time);
  y2_msg_delayed = delay(est_y2, delay_time);

  in_middle_third = (time >= t_mid_start) and (time <= t_mid_end);

  x1_msg_received = if in_middle_third then x1_msg_delayed else est_x1;
  vx1_msg_received = if in_middle_third then vx1_msg_delayed else est_vx1;
  eta1_msg_received = if in_middle_third then eta1_msg_delayed else t_eta1;
  y2_msg_received = if in_middle_third then y2_msg_delayed else est_y2;

  // ===== Decentralized reservation: AUV1 has priority, AUV2 yields =====
  cleared1_remote = x1_msg_received > R_zone;
  yield2 = (not cleared1_remote) and (vx1_msg_received > 0.01) and
           (eta1_msg_received < t_eta2 + tau_safe) and
           (est_y2 < R_hold + 0.5);

  // ===== Controller references =====
  s_ref1 = x1_target;
  s_ref2 = if yield2 then -R_hold else y2_target;

  // ===== Along-track velocity reference with bounded braking =====
  v_ref1 = v_cruise * tanh((s_ref1 - x1) / d_brake);
  v_ref2 = v_cruise * tanh((s_ref2 - y2) / d_brake);

  F_along1_cmd = Kv * (v_ref1 - vx1);
  F_along2_cmd = Kv * (v_ref2 - vy2);

  // ===== Cross-track PD controller (lane keeping) =====
  F_cross1_cmd = Kp_cross * (0.0 - y1) - Kd_cross * vy1;
  F_cross2_cmd = Kp_cross * (0.0 - x2) - Kd_cross * vx2;

  // ===== Thruster saturation: 8 channels, each bounded to +/- Fmax =====
  u1 = if F_along1_cmd / 2.0 > Fmax then Fmax elseif F_along1_cmd / 2.0 < -Fmax then -Fmax else F_along1_cmd / 2.0;
  u2 = u1;
  u3 = if F_cross1_cmd / 2.0 > Fmax then Fmax elseif F_cross1_cmd / 2.0 < -Fmax then -Fmax else F_cross1_cmd / 2.0;
  u4 = u3;
  u5 = if F_along2_cmd / 2.0 > Fmax then Fmax elseif F_along2_cmd / 2.0 < -Fmax then -Fmax else F_along2_cmd / 2.0;
  u6 = u5;
  u7 = if F_cross2_cmd / 2.0 > Fmax then Fmax elseif F_cross2_cmd / 2.0 < -Fmax then -Fmax else F_cross2_cmd / 2.0;
  u8 = u7;

  // ===== Sensors =====
  imu_ax1 = (Fx1 - drag * vx1) / m_robot;
  imu_ay1 = (Fy1 - drag * vy1) / m_robot;
  imu_ax2 = (Fx2 - drag * vx2) / m_robot;
  imu_ay2 = (Fy2 - drag * vy2) / m_robot;
  depth1 = depth_nominal;
  depth2 = depth_nominal;
  dvl_vx1 = vx1;
  dvl_vy1 = vy1;
  dvl_vx2 = vx2;
  dvl_vy2 = vy2;

  // ===== Obstacle sensing: inter-AUV separation =====
  sep_dist = sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2));

  // ===== Tracking errors =====
  track_err1 = sqrt((x1 - x1_target) * (x1 - x1_target) + y1 * y1);
  track_err2 = sqrt(x2 * x2 + (y2 - y2_target) * (y2 - y2_target));

  // ===== Waiting time accumulation =====
  der(waiting_time) = if yield2 then 1.0 else 0.0;

  // ===== Zone occupancy =====
  in_zone1 = (abs(x1) < R_zone) and (abs(y1) < R_zone);
  in_zone2 = (abs(x2) < R_zone) and (abs(y2) < R_zone);

  // ===== Requirement checks =====
  mutual_exclusion_ok = not (in_zone1 and in_zone2);
  no_collision_flag = sep_dist > 0.5;
  min_dist_ok = min_dist > 0.5;
  route1_done = track_err1 < 0.1;
  route2_done = track_err2 < 0.1;
  actuator_bounded = (abs(u1) <= Fmax + 0.001) and (abs(u2) <= Fmax + 0.001) and
                     (abs(u3) <= Fmax + 0.001) and (abs(u4) <= Fmax + 0.001) and
                     (abs(u5) <= Fmax + 0.001) and (abs(u6) <= Fmax + 0.001) and
                     (abs(u7) <= Fmax + 0.001) and (abs(u8) <= Fmax + 0.001);
  tracking_ok = (time < t_check) or
                (track_err1 < track_err_limit and track_err2 < track_err_limit);

  // ===== Discrete minimum distance update at 80 Hz =====
  when sample(0, dt) then
    min_dist = if pre(min_dist) < sep_dist then pre(min_dist) else sep_dist;
  end when;

  annotation(
    experiment(StartTime = 0, StopTime = 8.0, Tolerance = 1e-6, Interval = 0.0125));
end MarinePairCoordinateA;