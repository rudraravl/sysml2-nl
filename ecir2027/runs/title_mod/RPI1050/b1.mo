model TrackCrawlerInspectF
  // Embodiment
  parameter Real m_hull = 52.0 "hull mass [kg]";
  parameter Real L_hull = 1.1 "hull length [m]";
  parameter Real r_sp = 0.14 "sprocket radius [m]";
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
  parameter Real k1 = 2.0 * 3.14159265358979 / lambda_path "path wave number [1/m]";
  // Disturbance
  parameter Real F_dist = 130.0 "side load magnitude [N]";
  // Dynamics
  parameter Real c_drag = 8.0 "longitudinal drag [N.s/m]";
  parameter Real c_lat = 800.0 "lateral track friction [N.s/m]";
  parameter Real c_yaw = 3.0 "yaw damping [N.m.s/rad]";
  // Controller
  parameter Real Kp_speed = 50.0 "speed gain";
  parameter Real Kp_lat = 50.0 "lateral error gain";
  parameter Real Kp_head = 10.0 "heading error gain";
  parameter Real Kp_obs = 30.0 "obstacle avoidance gain";
  // Estimator
  parameter Real k_odom = 0.3 "odometry correction gain";
  parameter Real k_lidar = 0.4 "lidar correction gain";
  parameter Real k_vx = 0.5 "velocity correction gain";
  parameter Real k_theta = 0.05 "heading correction gain";
  parameter Real Q_pos = 0.001 "position process noise [m2/s]";
  parameter Real Q_head = 0.0001 "heading process noise [rad2/s]";

  // Robot states
  Real x(start = 0.0, fixed = true) "global x [m]";
  Real y(start = 0.0, fixed = true) "global y [m]";
  Real theta(start = 0.0, fixed = true) "heading [rad]";
  Real vx(start = 0.0, fixed = true) "forward velocity [m/s]";
  Real vy(start = 0.0, fixed = true) "lateral velocity [m/s]";
  Real omega(start = 0.0, fixed = true) "yaw rate [rad/s]";

  // Actuation
  Real tau_L_cmd "left torque command [N.m]";
  Real tau_R_cmd "right torque command [N.m]";
  Real tau_L "actual left torque [N.m]";
  Real tau_R "actual right torque [N.m]";
  Real F_L "left track force [N]";
  Real F_R "right track force [N]";

  // Path geometry true
  Real y_c "centerline y [m]";
  Real theta_c "centerline heading [rad]";
  Real kappa_c "centerline curvature [1/m]";
  Real slope_kx "path slope";
  Real denom_kx "curvature denominator";

  // Path geometry estimated
  Real y_c_est "est centerline y [m]";
  Real theta_c_est "est centerline heading [rad]";
  Real kappa_c_est "est centerline curvature [1/m]";
  Real slope_kx_est "est path slope";
  Real denom_kx_est "est curvature denominator";

  // Tracking errors
  Real e_lat "lateral error [m]";
  Real e_head "heading error [rad]";
  Real e_speed "speed error [m/s]";
  Real e_track "tracking error [m]";

  // Disturbance
  Real F_side "side load [N]";

  // Corridor
  Real wall_L "left wall [m]";
  Real wall_R "right wall [m]";
  Real clr_L "left clearance [m]";
  Real clr_R "right clearance [m]";
  Real clr_min "min clearance [m]";
  Real alcove_L "left alcove offset [m]";
  Real alcove_R "right alcove offset [m]";

  // Sensors
  Real odom_x(start = 0.0) "odom x [m]";
  Real odom_y(start = 0.0) "odom y [m]";
  Real odom_theta(start = 0.0) "odom heading [rad]";
  Real imu_omega "IMU yaw rate [rad/s]";
  Real imu_ax "IMU accel [m/s2]";
  Real lidar_L_meas "left lidar [m]";
  Real lidar_R_meas "right lidar [m]";
  Real v_odom "odom speed [m/s]";

  // Estimator
  Real est_x(start = 0.0) "est x [m]";
  Real est_y(start = 0.0) "est y [m]";
  Real est_theta(start = 0.0) "est heading [rad]";
  Real est_vx(start = 0.0) "est velocity [m/s]";
  Real est_omega "est yaw rate [rad/s]";
  Real P_11(start = 0.01) "cov P_xx";
  Real P_22(start = 0.01) "cov P_yy";
  Real P_33(start = 0.01) "cov P_thth";

  // Control internals
  Real F_cmd "commanded force [N]";
  Real M_cmd "commanded moment [N.m]";
  Real M_obs "obstacle moment [N.m]";
  Real y_from_lidar "lidar-derived y [m]";
  Real obs_active "obstacle activation";

  // Verification
  discrete Real max_trk_after_13(start = 0.0) "max tracking error after 13s [m]";
  Real distance_traveled(start = 0.0) "distance [m]";
  Boolean trk_ok;
  Boolean clr_ok;
  Boolean head_ok;
  Boolean cov_ok;
  Boolean vals_ok;
  Boolean route_ok;
  Boolean all_verified;

equation
  // Path geometry at true position
  slope_kx = A_path * k1 * cos(k1 * x);
  y_c = A_path * sin(k1 * x);
  theta_c = atan(slope_kx);
  denom_kx = (1.0 + slope_kx * slope_kx) * sqrt(1.0 + slope_kx * slope_kx);
  kappa_c = -(A_path * k1 * k1 * sin(k1 * x)) / denom_kx;

  // Path geometry at estimated position
  slope_kx_est = A_path * k1 * cos(k1 * est_x);
  y_c_est = A_path * sin(k1 * est_x);
  theta_c_est = atan(slope_kx_est);
  denom_kx_est = (1.0 + slope_kx_est * slope_kx_est) * sqrt(1.0 + slope_kx_est * slope_kx_est);
  kappa_c_est = -(A_path * k1 * k1 * sin(k1 * est_x)) / denom_kx_est;

  // Corridor walls with two recessed alcoves
  alcove_L = if (x > 3.5) and (x < 5.0) then 0.4 else 0.0;
  alcove_R = if (x > 9.0) and (x < 10.5) then 0.4 else 0.0;
  wall_L = y_c + w_corridor / 2.0 + alcove_L;
  wall_R = y_c - w_corridor / 2.0 - alcove_R;

  // Clearances
  clr_L = wall_L - y;
  clr_R = y - wall_R;
  clr_min = if clr_L < clr_R then clr_L else clr_R;

  // Disturbance: 130 N side load during middle third
  F_side = if (time >= T_end / 3.0) and (time <= 2.0 * T_end / 3.0) then F_dist else 0.0;

  // Track forces from torques
  F_L = tau_L / r_sp;
  F_R = tau_R / r_sp;

  // Torque saturation at 51.2 N.m
  tau_L = if tau_L_cmd > tau_max then tau_max elseif tau_L_cmd < -tau_max then -tau_max else tau_L_cmd;
  tau_R = if tau_R_cmd > tau_max then tau_max elseif tau_R_cmd < -tau_max then -tau_max else tau_R_cmd;

  // Robot planar dynamics
  der(x) = vx * cos(theta) - vy * sin(theta);
  der(y) = vx * sin(theta) + vy * cos(theta);
  der(theta) = omega;
  der(vx) = (F_L + F_R - c_drag * vx) / m_hull;
  der(vy) = (F_side - c_lat * vy) / m_hull;
  der(omega) = ((F_R - F_L) * d_tr / 2.0 - c_yaw * omega) / Izz;

  // Odometry with drift biases
  der(odom_x) = vx * cos(odom_theta) - vy * sin(odom_theta) + 0.002;
  der(odom_y) = vx * sin(odom_theta) + vy * cos(odom_theta) + 0.002;
  der(odom_theta) = omega + 0.0005;
  v_odom = vx + 0.01;

  // IMU measurements with bias
  imu_omega = omega + 0.001;
  imu_ax = (F_L + F_R - c_drag * vx) / m_hull + 0.01;

  // Lidar range measurements clamped to max range
  lidar_L_meas = if clr_L + 0.005 > lidar_max then lidar_max else clr_L + 0.005;
  lidar_R_meas = if clr_R + 0.005 > lidar_max then lidar_max else clr_R + 0.005;

  // Lidar-derived lateral position
  y_from_lidar = y_c_est + (lidar_R_meas - lidar_L_meas) / 2.0;

  // Estimator: fused odometry + IMU + lidar
  der(est_x) = est_vx * cos(est_theta) + k_odom * (odom_x - est_x);
  der(est_y) = est_vx * sin(est_theta) + k_lidar * (y_from_lidar - est_y);
  der(est_theta) = imu_omega + k_theta * (odom_theta - est_theta);
  der(est_vx) = imu_ax + k_vx * (v_odom - est_vx);
  est_omega = imu_omega;

  // Estimator covariance
  der(P_11) = Q_pos - k_odom * P_11;
  der(P_22) = Q_pos - k_lidar * P_22;
  der(P_33) = Q_head - k_theta * P_33;

  // Tracking errors from estimator
  e_lat = est_y - y_c_est;
  e_head = est_theta - theta_c_est;
  e_speed = v_ref - est_vx;
  e_track = abs(e_lat);

  // Obstacle avoidance activation
  obs_active = if (lidar_L_meas < 2.0 * d_clear_min) or (lidar_R_meas < 2.0 * d_clear_min) then 1.0 else 0.0;
  M_obs = Kp_obs * (lidar_R_meas - lidar_L_meas) * obs_active;

  // Path tracking control with feedforward
  F_cmd = Kp_speed * e_speed + c_drag * v_ref;
  M_cmd = -Kp_lat * e_lat - Kp_head * e_head + c_yaw * v_ref * kappa_c_est + M_obs;
  tau_L_cmd = (F_cmd / 2.0 - M_cmd / d_tr) * r_sp;
  tau_R_cmd = (F_cmd / 2.0 + M_cmd / d_tr) * r_sp;

  // Distance traveled
  der(distance_traveled) = sqrt(vx * vx + vy * vy);

  // Verification criteria
  clr_ok = clr_min > d_clear_min;
  head_ok = abs(e_head) < 0.5;
  cov_ok = (P_11 > 0.0) and (P_11 < 100.0) and (P_22 > 0.0) and (P_22 < 100.0) and (P_33 > 0.0) and (P_33 < 100.0);
  route_ok = distance_traveled >= 12.0;
  trk_ok = max_trk_after_13 < 0.16;
  vals_ok = (abs(x) < 1e6) and (abs(y) < 1e6) and (abs(theta) < 1e6) and (abs(vx) < 1e6) and (abs(est_x) < 1e6) and (abs(est_y) < 1e6) and (abs(tau_L) < 1e6) and (abs(tau_R) < 1e6) and (abs(P_11) < 1e6) and (abs(P_22) < 1e6) and (abs(P_33) < 1e6);
  all_verified = trk_ok and clr_ok and head_ok and cov_ok and vals_ok and route_ok;

  // Track maximum tracking error after 13 s at 500 Hz
  when sample(13.0, dt_sim) then
    max_trk_after_13 = if abs(e_track) > pre(max_trk_after_13) then abs(e_track) else pre(max_trk_after_13);
  end when;

  annotation(
    experiment(StartTime = 0, StopTime = 20, Tolerance = 1e-6, Interval = 0.002),
    Documentation(info = "TrackCrawlerInspectF: 52 kg tracked capsule robot traversing an S-shaped corridor (1.8 m wide, two alcoves) at 0.8 m/s with skid-steer control (tau_max 51.2 N.m), fused odometry/IMU/15 m lidar localization, 130 N side load in middle third, 500 Hz for 20 s. Verification: finite covariance, clearance > 0.18 m, tracking error < 0.16 m after 13 s, route completion, no NaN/Inf.")
  );
end TrackCrawlerInspectF;