model TrackCrawlerInspectF
  // ==================== PARAMETERS ====================
  // Embodiment
  parameter Real m_hull = 52.0 "hull mass [kg]";
  parameter Real L_hull = 1.1 "hull length [m]";
  parameter Real r_sp = 0.14 "effective sprocket radius [m]";
  parameter Real d_tr = 0.50 "track separation [m]";
  parameter Real Izz = m_hull * L_hull * L_hull / 12.0 "yaw inertia [kg.m2]";

  // Actuation
  parameter Real tau_max = 51.2 "max track torque [N.m]";

  // Mission
  parameter Real v_ref = 0.8 "reference speed [m/s]";
  parameter Real T_end = 20.0 "mission duration [s]";
  parameter Real dt_sim = 0.002 "sample period 500 Hz [s]";

  // Environment
  parameter Real w_corridor = 1.8 "corridor width [m]";
  parameter Real d_clear_min = 0.18 "min wall clearance [m]";
  parameter Real A_path = 0.25 "S-curve amplitude [m]";
  parameter Real lambda_path = 8.0 "S-curve wavelength [m]";
  parameter Real lidar_max = 15.0 "lidar max range [m]";
  parameter Real k1 = 2.0 * Modelica.Constants.pi / lambda_path "path wave number [1/m]";

  // Disturbance
  parameter Real F_dist = 130.0 "side load magnitude [N]";

  // Dynamics
  parameter Real c_drag = 8.0 "longitudinal drag [N.s/m]";
  parameter Real c_lat = 800.0 "lateral track friction [N.s/m]";
  parameter Real c_yaw = 3.0 "yaw damping [N.m.s/rad]";

  // Controller gains
  parameter Real Kp_speed = 50.0 "speed gain [N/(m/s)]";
  parameter Real Kp_lat = 50.0 "lateral error gain [N.m/m]";
  parameter Real Kp_head = 10.0 "heading error gain [N.m/rad]";
  parameter Real Kp_obs = 30.0 "obstacle avoidance gain [N.m/m]";

  // Estimator gains
  parameter Real k_odom = 0.3 "odometry correction gain [1/s]";
  parameter Real k_lidar = 0.4 "lidar correction gain [1/s]";
  parameter Real k_vx = 0.5 "velocity correction gain [1/s]";
  parameter Real k_theta = 0.05 "heading correction gain [1/s]";
  parameter Real Q_pos = 0.001 "position process noise [m2/s]";
  parameter Real Q_head = 0.0001 "heading process noise [rad2/s]";

  // ==================== ROBOT STATES ====================
  Real x(start = 0.0, fixed = true) "global x position [m]";
  Real y(start = 0.0, fixed = true) "global y position [m]";
  Real theta(start = 0.0, fixed = true) "heading angle [rad]";
  Real vx(start = 0.0, fixed = true) "body forward velocity [m/s]";
  Real vy(start = 0.0, fixed = true) "body lateral velocity [m/s]";
  Real omega(start = 0.0, fixed = true) "yaw rate [rad/s]";

  // ==================== ACTUATION ====================
  Real tau_L_cmd "left track command torque [N.m]";
  Real tau_R_cmd "right track command torque [N.m]";
  Real tau_L "actual left track torque [N.m]";
  Real tau_R "actual right track torque [N.m]";
  Real F_L "left track tractive force [N]";
  Real F_R "right track tractive force [N]";

  // ==================== PATH GEOMETRY (true) ====================
  Real y_c "centerline y at true x [m]";
  Real theta_c "centerline heading at true x [rad]";
  Real kappa_c "centerline curvature at true x [1/m]";
  Real cos_kx "cos(k1*x) [-]";
  Real sin_kx "sin(k1*x) [-]";
  Real slope_kx "path slope at true x [-]";
  Real denom_kx "curvature denominator at true x [-]";

  // ==================== PATH GEOMETRY (estimated) ====================
  Real y_c_est "centerline y at estimated x [m]";
  Real theta_c_est "centerline heading at estimated x [rad]";
  Real kappa_c_est "centerline curvature at estimated x [1/m]";
  Real cos_kx_est "cos(k1*est_x) [-]";
  Real sin_kx_est "sin(k1*est_x) [-]";
  Real slope_kx_est "path slope at estimated x [-]";
  Real denom_kx_est "curvature denominator at estimated x [-]";

  // ==================== TRACKING ERRORS ====================
  Real e_lat "lateral cross-track error [m]";
  Real e_head "heading error [rad]";
  Real e_speed "speed error [m/s]";
  Real e_track "primary tracking error [m]";

  // ==================== DISTURBANCE ====================
  Real F_side "applied side load force [N]";

  // ==================== CORRIDOR ====================
  Real wall_L "left wall y-position at true x [m]";
  Real wall_R "right wall y-position at true x [m]";
  Real clr_L "clearance to left wall [m]";
  Real clr_R "clearance to right wall [m]";
  Real clr_min "minimum wall clearance [m]";

  // ==================== SENSORS ====================
  Real odom_x(start = 0.0) "odometry x position [m]";
  Real odom_y(start = 0.0) "odometry y position [m]";
  Real odom_theta(start = 0.0) "odometry heading [rad]";
  Real imu_omega "IMU yaw rate measurement [rad/s]";
  Real imu_ax "IMU forward acceleration [m/s2]";
  Real lidar_L_meas "left lidar range [m]";
  Real lidar_R_meas "right lidar range [m]";
  Real v_odom "odometry-derived speed [m/s]";

  // ==================== ESTIMATOR ====================
  Real est_x(start = 0.0) "estimated x [m]";
  Real est_y(start = 0.0) "estimated y [m]";
  Real est_theta(start = 0.0) "estimated heading [rad]";
  Real est_vx(start = 0.0) "estimated forward velocity [m/s]";
  Real est_omega "estimated yaw rate [rad/s]";
  Real P_11(start = 0.01) "estimator covariance P_xx [m2]";
  Real P_22(start = 0.01) "estimator covariance P_yy [m2]";
  Real P_33(start = 0.01) "estimator covariance P_thth [rad2]";
  Real y_from_lidar "lidar-derived lateral position [m]";

  // ==================== CONTROL INTERNALS ====================
  Real F_cmd "commanded total track force [N]";
  Real M_cmd "commanded yaw moment [N.m]";
  Real M_obs "obstacle avoidance moment contribution [N.m]";
  Real obs_factor "obstacle proximity activation factor [-]";

  // ==================== VERIFICATION ====================
  discrete Real max_trk_after_13(start = 0.0) "max tracking error after 13 s [m]";
  Real distance_traveled(start = 0.0) "cumulative distance [m]";
  Boolean trk_ok "tracking error below 0.16 m after 13 s";
  Boolean clr_ok "wall clearance above 0.18 m";
  Boolean cov_ok "estimator covariance finite and positive";
  Boolean vals_ok "no NaN or infinite values";
  Boolean route_ok "route completion achieved";
  Boolean head_ok "heading error bounded";
  Boolean all_verified "all verification criteria satisfied";

equation
  // ===== Path trigonometry at true x =====
  cos_kx = Modelica.Math.cos(k1 * x);
  sin_kx = Modelica.Math.sin(k1 * x);
  slope_kx = A_path * k1 * cos_kx;
  denom_kx = (1.0 + slope_kx * slope_kx) * Modelica.Math.sqrt(1.0 + slope_kx * slope_kx);
  y_c = A_path * sin_kx;
  theta_c = Modelica.Math.atan(slope_kx);
  kappa_c = -(A_path * k1 * k1 * sin_kx) / denom_kx;

  // ===== Path trigonometry at estimated x =====
  cos_kx_est = Modelica.Math.cos(k1 * est_x);
  sin_kx_est = Modelica.Math.sin(k1 * est_x);
  slope_kx_est = A_path * k1 * cos_kx_est;
  denom_kx_est = (1.0 + slope_kx_est * slope_kx_est) * Modelica.Math.sqrt(1.0 + slope_kx_est * slope_kx_est);
  y_c_est = A_path * sin_kx_est;
  theta_c_est = Modelica.Math.atan(slope_kx_est);
  kappa_c_est = -(A_path * k1 * k1 * sin_kx_est) / denom_kx_est;

  // ===== Corridor walls with two recessed alcoves =====
  // Alcove 1: left wall recessed 0.4 m for x in [3.5, 5.0] m
  // Alcove 2: right wall recessed 0.4 m for x in [9.0, 10.5] m
  wall_L = y_c + w_corridor / 2.0 + (if (x > 3.5 and x < 5.0) then 0.4 else 0.0);
  wall_R = y_c - w_corridor / 2.0 - (if (x > 9.0 and x < 10.5) then 0.4 else 0.0);

  // ===== Wall clearances =====
  clr_L = wall_L - y;
  clr_R = y - wall_R;
  clr_min = if (clr_L < clr_R) then clr_L else clr_R;

  // ===== Disturbance: 130 N side load during middle third =====
  F_side = if (time >= T_end / 3.0 and time <= 2.0 * T_end / 3.0) then F_dist else 0.0;

  // ===== Track forces from torques =====
  F_L = tau_L / r_sp;
  F_R = tau_R / r_sp;

  // ===== Torque saturation at 51.2 N.m =====
  tau_L = if (tau_L_cmd > tau_max) then tau_max
    elseif (tau_L_cmd < -tau_max) then -tau_max
    else tau_L_cmd;
  tau_R = if (tau_R_cmd > tau_max) then tau_max
    elseif (tau_R_cmd < -tau_max) then -tau_max
    else tau_R_cmd;

  // ===== Robot planar dynamics (body frame) =====
  der(x) = vx * Modelica.Math.cos(theta) - vy * Modelica.Math.sin(theta);
  der(y) = vx * Modelica.Math.sin(theta) + vy * Modelica.Math.cos(theta);
  der(theta) = omega;
  der(vx) = (F_L + F_R - c_drag * vx) / m_hull;
  der(vy) = (F_side - c_lat * vy) / m_hull;
  der(omega) = ((F_R - F_L) * d_tr / 2.0 - c_yaw * omega) / Izz;

  // ===== Odometry model with drift biases =====
  der(odom_x) = vx * Modelica.Math.cos(odom_theta) - vy * Modelica.Math.sin(odom_theta) + 0.002;
  der(odom_y) = vx * Modelica.Math.sin(odom_theta) + vy * Modelica.Math.cos(odom_theta) + 0.002;
  der(odom_theta) = omega + 0.0005;
  v_odom = vx + 0.01;

  // ===== IMU measurements with bias =====
  imu_omega = omega + 0.001;
  imu_ax = (F_L + F_R - c_drag * vx) / m_hull + 0.01;

  // ===== Lidar range measurements with small bias =====
  lidar_L_meas = clr_L + 0.005;
  lidar_R_meas = clr_R + 0.005;

  // ===== Lidar-derived lateral position (fuse left and right ranges) =====
  y_from_lidar = y_c_est + (lidar_R_meas - lidar_L_meas) / 2.0;

  // ===== Estimator: fused odometry + IMU + lidar =====
  der(est_x) = est_vx * Modelica.Math.cos(est_theta) + k_odom * (odom_x - est_x);
  der(est_y) = est_vx * Modelica.Math.sin(est_theta) + k_lidar * (y_from_lidar - est_y);
  der(est_theta) = imu_omega + k_theta * (odom_theta - est_theta);
  der(est_vx) = imu_ax + k_vx * (v_odom - est_vx);
  est_omega = imu_omega;

  // ===== Estimator covariance (simplified continuous Riccati) =====
  der(P_11) = Q_pos - k_odom * P_11;
  der(P_22) = Q_pos - k_lidar * P_22;
  der(P_33) = Q_head - k_theta * P_33;

  // ===== Tracking errors from estimator =====
  e_lat = est_y - y_c_est;
  e_head = est_theta - theta_c_est;
  e_speed = v_ref - est_vx;
  e_track = if (e_lat < 0.0) then -e_lat else e_lat;

  // ===== Obstacle avoidance activation =====
  obs_factor = if (lidar_L_meas < 2.0 * d_clear_min) then 1.0
    elseif (lidar_R_meas < 2.0 * d_clear_min) then 1.0
    else 0.0;
  M_obs = Kp_obs * (lidar_R_meas - lidar_L_meas) * obs_factor;

  // ===== Path tracking control with feedforward =====
  F_cmd = Kp_speed * e_speed + c_drag * v_ref;
  M_cmd = -Kp_lat * e_lat - Kp_head * e_head + c_yaw * v_ref * kappa_c_est + M_obs;
  tau_L_cmd = (F_cmd / 2.0 - M_cmd / d_tr) * r_sp;
  tau_R_cmd = (F_cmd / 2.0 + M_cmd / d_tr) * r_sp;

  // ===== Distance traveled =====
  der(distance_traveled) = Modelica.Math.sqrt(vx * vx + vy * vy);

  // ===== Verification criteria =====
  trk_ok = (max_trk_after_13 < 0.16);
  clr_ok = (clr_min > d_clear_min);
  head_ok = (e_head > -0.5 and e_head < 0.5);
  cov_ok = (P_11 > 0.0 and P_11 < 100.0 and
            P_22 > 0.0 and P_22 < 100.0 and
            P_33 > 0.0 and P_33 < 100.0);
  vals_ok = (x > -1e6 and x < 1e6 and
             y > -1e6 and y < 1e6 and
             theta > -1e6 and theta < 1e6 and
             vx > -1e6 and vx < 1e6 and
             est_x > -1e6 and est_x < 1e6 and
             est_y > -1e6 and est_y < 1e6 and
             tau_L > -1e6 and tau_L < 1e6 and
             tau_R > -1e6 and tau_R < 1e6 and
             P_11 > -1e6 and P_11 < 1e6 and
             P_22 > -1e6 and P_22 < 1e6 and
             P_33 > -1e6 and P_33 < 1e6);
  route_ok = (distance_traveled >= 12.0);
  all_verified = trk_ok and clr_ok and head_ok and cov_ok and vals_ok and route_ok;

  // ===== Track maximum tracking error after 13 s at 500 Hz =====
  when sample(13.0, dt_sim) then
    max_trk_after_13 = max(abs(e_track), pre(max_trk_after_13));
  end when;

  annotation(
    experiment(StartTime = 0, StopTime = 20, Tolerance = 1e-6, Interval = 0.002),
    Documentation(info = "TrackCrawlerInspectF: 52 kg tracked capsule robot traversing an S-shaped corridor (1.8 m wide, two alcoves) at 0.8 m/s with skid-steer control (tau_max 51.2 N.m), fused odometry/IMU/15 m lidar localization, 130 N side load in middle third, 500 Hz for 20 s. Verification: finite covariance, clearance > 0.18 m, tracking error < 0.16 m after 13 s, route completion, no NaN/Inf.")
  );
end TrackCrawlerInspectF;