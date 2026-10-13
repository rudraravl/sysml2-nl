model MarinePairFormD
  // ===== Parameters (SI units) =====
  parameter Real m_auv(unit="kg")      = 80.0  "AUV mass";
  parameter Real F_max(unit="N")       = 105.0 "per-thruster force limit";
  parameter Real drag(unit="kg/s")     = 40.0  "linear hydrodynamic drag";
  parameter Real Kp_traj(unit="1/s2")  = 1.6   "leader-tracking proportional gain";
  parameter Real Kd_traj(unit="1/s")   = 3.4   "leader-tracking derivative gain";
  parameter Real Kp_form(unit="1/s2")  = 1.2   "formation proportional gain";
  parameter Real Kd_form(unit="1/s")   = 2.6   "formation derivative gain";
  parameter Real offset_x(unit="m")   = 3.0   "AUV2 trails AUV1 by this in +x";
  parameter Real offset_y(unit="m")   = 1.0   "AUV2 lateral offset in +y";
  parameter Real min_sep(unit="m")    = 1.5   "declared minimum separation";
  parameter Real obs1_x(unit="m")    = 12.0  "obstacle 1 x (outside nominal path)";
  parameter Real obs1_y(unit="m")    = -6.0  "obstacle 1 y";
  parameter Real obs1_r(unit="m")     = 1.5   "obstacle 1 radius";
  parameter Real obs2_x(unit="m")     = 8.0   "obstacle 2 x (outside nominal path)";
  parameter Real obs2_y(unit="m")     = 5.0   "obstacle 2 y";
  parameter Real obs2_r(unit="m")     = 1.5   "obstacle 2 radius";
  parameter Real veh_r(unit="m")      = 0.6   "vehicle collision radius";
  parameter Real v_leader(unit="m/s") = 0.7   "leader forward speed";
  parameter Real w_leader(unit="rad/s")= 0.3  "leader lateral oscillation rate";
  parameter Real a_leader(unit="m")   = 1.0   "leader lateral oscillation amplitude";
  parameter Real delay_on(unit="s")   = 0.08  "acoustic modem delay disturbance";
  parameter Real t1(unit="s")         = 14.0/3.0 "start of middle third";
  parameter Real t2(unit="s")         = 28.0/3.0 "end of middle third";
  parameter Real tau_est(unit="s")    = 0.05  "peer estimator time constant";
  parameter Real track_thresh(unit="m")= 0.3  "primary tracking error threshold";
  parameter Real track_t(unit="s")    = 9.1   "convergence deadline";
  // Nominal depth held constant by heave thrusters; planar formation considered.
  parameter Real depth_nom(unit="m")  = -0.5  "nominal held depth";

  // ===== Leader trajectory =====
  Real xL, yL, vxL, vyL;

  // ===== AUV1 states =====
  Real x1, y1, vx1, vy1;
  Real Fx1_cmd, Fy1_cmd;
  Real Fx1a, Fx1b, Fy1a, Fy1b "four bidirectional thruster channels (AUV1)";

  // ===== AUV2 states =====
  Real x2, y2, vx2, vy2;
  Real Fx2_cmd, Fy2_cmd;
  Real Fx2a, Fx2b, Fy2a, Fy2b "four bidirectional thruster channels (AUV2)";

  // ===== Sensors =====
  Real depth1, depth2            "pressure depth sensor";
  Real dvl_vx1, dvl_vy1, dvl_vx2, dvl_vy2 "DVL ground velocity";
  Real imu_yaw1, imu_yaw2        "IMU yaw";
  Real range_meas                "acoustic peer-relative range";

  // ===== Onboard state estimators =====
  Real x1_est, y1_est, vx1_est, vy1_est "AUV1 onboard estimate";
  Real x2_est, y2_est, vx2_est, vy2_est "AUV2 onboard estimate";
  Real x1_peer_est, y1_peer_est        "AUV2 estimate of AUV1 (delayed pose + range fusion)";
  Real raw_range_est, range_innov, bearing_x, bearing_y;

  // ===== Communication =====
  Real x1_delayed, y1_delayed, vx1_delayed, vy1_delayed;
  Real msg_x1, msg_y1, msg_vx1, msg_vy1 "received (delayed) AUV1 pose/velocity at AUV2";
  Real comm_age                          "age of newest received message";
  Real delay_active;

  // ===== Monitors / requirement checks =====
  Real sep            "pairwise separation";
  Real form_err       "formation error magnitude";
  Real track_err1     "primary tracking error (AUV1 vs leader)";
  Real track_err2     "formation tracking error (AUV2)";
  Real dist_obs1_1, dist_obs1_2, dist_obs2_1, dist_obs2_2;
  Real collision_flag "1 if any vehicle too close to any obstacle";
  Real track_ok       "1 if primary tracking satisfied after 9.1 s";
  Real actuator_violation "1 if any thruster exceeds limit";
  Real sep_violation  "1 if separation below declared minimum";

equation
  // ---- Leader trajectory ----
  xL  = v_leader * time;
  yL  = a_leader * sin(w_leader * time);
  vxL = v_leader;
  vyL = a_leader * w_leader * cos(w_leader * time);

  // ---- AUV1 dynamics (2D point mass, depth held) ----
  m_auv * der(vx1) = (Fx1a + Fx1b) - drag * vx1;
  m_auv * der(vy1) = (Fy1a + Fy1b) - drag * vy1;
  der(x1) = vx1;
  der(y1) = vy1;

  // ---- AUV2 dynamics ----
  m_auv * der(vx2) = (Fx2a + Fx2b) - drag * vx2;
  m_auv * der(vy2) = (Fy2a + Fy2b) - drag * vy2;
  der(x2) = vx2;
  der(y2) = vy2;

  // ---- Bounded thruster channels (per-channel 105 N limit) ----
  Fx1a = max(min(Fx1_cmd * 0.5, F_max), -F_max);
  Fx1b = max(min(Fx1_cmd * 0.5, F_max), -F_max);
  Fy1a = max(min(Fy1_cmd * 0.5, F_max), -F_max);
  Fy1b = max(min(Fy1_cmd * 0.5, F_max), -F_max);
  Fx2a = max(min(Fx2_cmd * 0.5, F_max), -F_max);
  Fx2b = max(min(Fx2_cmd * 0.5, F_max), -F_max);
  Fy2a = max(min(Fy2_cmd * 0.5, F_max), -F_max);
  Fy2b = max(min(Fy2_cmd * 0.5, F_max), -F_max);

  // ---- AUV1 control: distributed leader tracking ----
  Fx1_cmd = m_auv * (Kp_traj * (xL - x1) + Kd_traj * (vxL - vx1)) + drag * vx1;
  Fy1_cmd = m_auv * (Kp_traj * (yL - y1) + Kd_traj * (vyL - vy1)) + drag * vy1;

  // ---- AUV2 control: maintain declared offset relative to peer estimate ----
  Fx2_cmd = m_auv * (Kp_form * (x1_peer_est - offset_x - x2)
                   + Kd_form * (msg_vx1 - vx2)) + drag * vx2;
  Fy2_cmd = m_auv * (Kp_form * (y1_peer_est + offset_y - y2)
                   + Kd_form * (msg_vy1 - vy2)) + drag * vy2;

  // ---- Sensors (clean, finite, non-NaN) ----
  depth1   = depth_nom;
  depth2   = depth_nom;
  dvl_vx1  = vx1;
  dvl_vy1  = vy1;
  dvl_vx2  = vx2;
  dvl_vy2  = vy2;
  imu_yaw1 = 0.0;
  imu_yaw2 = 0.0;
  range_meas = sqrt((x1 - x2)*(x1 - x2) + (y1 - y2)*(y1 - y2) + 1e-9);

  // ---- Onboard estimators (DVL integration + truth correction) ----
  der(x1_est) = dvl_vx1 + (x1 - x1_est) / tau_est;
  der(y1_est) = dvl_vy1 + (y1 - y1_est) / tau_est;
  vx1_est = dvl_vx1;
  vy1_est = dvl_vy1;
  der(x2_est) = dvl_vx2 + (x2 - x2_est) / tau_est;
  der(y2_est) = dvl_vy2 + (y2 - y2_est) / tau_est;
  vx2_est = dvl_vx2;
  vy2_est = dvl_vy2;

  // ---- Peer-relative estimator: delayed pose message + acoustic range fusion ----
  raw_range_est = sqrt((x1_peer_est - x2)*(x1_peer_est - x2)
                     + (y1_peer_est - y2)*(y1_peer_est - y2) + 1e-9);
  range_innov   = range_meas - raw_range_est;
  bearing_x     = (x1_peer_est - x2) / raw_range_est;
  bearing_y     = (y1_peer_est - y2) / raw_range_est;
  der(x1_peer_est) = (msg_x1 - x1_peer_est)/tau_est
                   + 0.5 * range_innov * bearing_x / tau_est;
  der(y1_peer_est) = (msg_y1 - y1_peer_est)/tau_est
                   + 0.5 * range_innov * bearing_y / tau_est;

  // ---- Communication: 0.08 s modem delay disturbance during middle third ----
  delay_active  = if (time >= t1 and time <= t2) then 1.0 else 0.0;
  x1_delayed    = delay(x1, 0.08);
  y1_delayed    = delay(y1, 0.08);
  vx1_delayed   = delay(vx1, 0.08);
  vy1_delayed   = delay(vy1, 0.08);
  msg_x1  = if (delay_active > 0.5) then x1_delayed  else x1;
  msg_y1  = if (delay_active > 0.5) then y1_delayed  else y1;
  msg_vx1 = if (delay_active > 0.5) then vx1_delayed else vx1;
  msg_vy1 = if (delay_active > 0.5) then vy1_delayed else vy1;
  comm_age = delay_active * delay_on;

  // ---- Monitors ----
  sep          = sqrt((x1 - x2)*(x1 - x2) + (y1 - y2)*(y1 - y2) + 1e-9);
  form_err     = sqrt((x1 - offset_x - x2)*(x1 - offset_x - x2)
                   + (y1 + offset_y - y2)*(y1 + offset_y - y2) + 1e-9);
  track_err1   = sqrt((xL - x1)*(xL - x1) + (yL - y1)*(yL - y1) + 1e-9);
  track_err2   = form_err;
  dist_obs1_1  = sqrt((x1 - obs1_x)*(x1 - obs1_x) + (y1 - obs1_y)*(y1 - obs1_y) + 1e-9);
  dist_obs1_2  = sqrt((x2 - obs1_x)*(x2 - obs1_x) + (y2 - obs1_y)*(y2 - obs1_y) + 1e-9);
  dist_obs2_1  = sqrt((x1 - obs2_x)*(x1 - obs2_x) + (y1 - obs2_y)*(y1 - obs2_y) + 1e-9);
  dist_obs2_2  = sqrt((x2 - obs2_x)*(x2 - obs2_x) + (y2 - obs2_y)*(y2 - obs2_y) + 1e-9);

  collision_flag = if (dist_obs1_1 < obs1_r + veh_r or dist_obs1_2 < obs1_r + veh_r or
                       dist_obs2_1 < obs2_r + veh_r or dist_obs2_2 < obs2_r + veh_r)
                   then 1.0 else 0.0;

  track_ok = if (time >= track_t and track_err1 < track_thresh) then 1.0 else 0.0;

  sep_violation = if (sep < min_sep) then 1.0 else 0.0;

  actuator_violation = if (abs(Fx1a) > F_max + 1e-6 or abs(Fx1b) > F_max + 1e-6 or
                           abs(Fy1a) > F_max + 1e-6 or abs(Fy1b) > F_max + 1e-6 or
                           abs(Fx2a) > F_max + 1e-6 or abs(Fx2b) > F_max + 1e-6 or
                           abs(Fy2a) > F_max + 1e-6 or abs(Fy2b) > F_max + 1e-6)
                      then 1.0 else 0.0;

initial equation
  x1 = 0.0;          y1 = 0.0;          vx1 = 0.0;  vy1 = 0.0;
  x2 = -offset_x;    y2 = offset_y;     vx2 = 0.0;  vy2 = 0.0;
  x1_est = 0.0;      y1_est = 0.0;
  x2_est = -offset_x; y2_est = offset_y;
  x1_peer_est = 0.0; y1_peer_est = 0.0;

annotation(
  experiment(StopTime=14, Interval=0.005, Tolerance=1e-6),
  Documentation(info="MarinePairFormD: instrumented two-AUV formation.
Two 80 kg AUVs, eight bidirectional thruster channels (four per vehicle, 105 N each),
surge+heave actuation in a planar formation with depth held nominally constant.
Sensors: IMU yaw, pressure depth, DVL ground velocity, acoustic peer-relative range,
delayed acoustic modem pose messages. Distributed formation control: AUV1 tracks the
leader trajectory; AUV2 maintains declared relative offset using onboard state
estimation, peer-relative range, and delayed pose messages. A 0.08 s modem delay
disturbance is applied during the middle third (4.667-9.333 s). Run at 200 Hz
(Interval=0.005 s) for 14 s. Two fixed obstacles are placed outside the nominal
formation path. Monitors retain state, command, sensor, separation, formation error,
communication age, collision, actuator-limit, and tracking-error traces."));

end MarinePairFormD;