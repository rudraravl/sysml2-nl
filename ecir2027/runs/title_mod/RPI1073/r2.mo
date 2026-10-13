model TriTugInspectE
  "Front-wheel drive-and-steer tricycle (38kg chassis + 20kg payload) inspecting an S-corridor at 0.8 m/s with fused localization, obstacle avoidance, and 108 N side-load disturbance"

  // ======================== Physical Parameters ========================
  parameter Real m_chassis(unit = "kg") = 38.0   "Chassis mass";
  parameter Real m_payload(unit = "kg") = 20.0  "Payload mass";
  parameter Real m_total(unit = "kg") = m_chassis + m_payload "Total mass";
  parameter Real r_wheel(unit = "m") = 0.15    "Front drive-and-steer wheel radius";
  // Wheelbase not stated in requirement; value assumed for structural completeness
  parameter Real L_wb(unit = "m") = 0.6        "Wheelbase (assumed)";
  parameter Real track_rear(unit = "m") = 0.5  "Rear passive wheel track (assumed)";
  // Steering axis inertia and damping not stated; values assumed
  parameter Real I_steer(unit = "kg.m2") = 0.05     "Steering axis inertia (assumed)";
  parameter Real b_steer(unit = "N.m.s/rad") = 0.8  "Steering damping (assumed)";
  parameter Real k_softstop(unit = "N.m/rad") = 2000.0 "Steering limit spring stiffness (assumed)";
  parameter Real c_drag(unit = "N.s/m") = 5.0  "Longitudinal rolling drag (assumed)";
  parameter Real c_lat(unit = "N.s/m") = 500.0 "Lateral tire damping from passive rear wheels (assumed)";

  // ======================== Actuator Limits ========================
  parameter Real delta_max(unit = "rad") = 0.60        "Steering travel +/-";
  parameter Real tau_max(unit = "N.m") = 37.4          "Command magnitude bound (both axes)";
  parameter Real F_drive_max(unit = "N") = tau_max / r_wheel "Max traction force from torque limit";

  // ======================== Reference ========================
  parameter Real v_ref(unit = "m/s") = 0.8  "Reference speed";

  // ======================== Corridor ========================
  parameter Real w_corridor(unit = "m") = 1.8  "Wall separation";
  parameter Real w_half(unit = "m") = w_corridor / 2.0;
  // Corridor S-curve shape not fully specified; parameters assumed
  parameter Real A_corr(unit = "m") = 0.7      "S-curve amplitude (assumed)";
  parameter Real k_corr(unit = "1/m") = 2.0 * 3.14159265358979 / 10.0 "Spatial frequency (assumed)";
  parameter Real alcove_depth(unit = "m") = 0.3 "Recessed alcove depth (assumed)";
  parameter Real alcove_x1(unit = "m") = 3.0    "Alcove 1 center x (assumed)";
  parameter Real alcove_x2(unit = "m") = 10.0   "Alcove 2 center x (assumed)";
  parameter Real alcove_w(unit = "m") = 0.6     "Alcove half-width sigma (assumed)";
  parameter Real lidar_range_max(unit = "m") = 15.0 "Planar lidar maximum range";

  // ======================== Disturbance ========================
  parameter Real F_side_amp(unit = "N") = 108.0  "Side load magnitude";
  parameter Real t_sim(unit = "s") = 16.0       "Simulation duration";
  parameter Real t_dist_start(unit = "s") = t_sim / 3.0     "Disturbance start (middle third)";
  parameter Real t_dist_end(unit = "s") = 2.0 * t_sim / 3.0 "Disturbance end (middle third)";

  // ======================== Acceptance Thresholds ========================
  parameter Real clearance_min(unit = "m") = 0.18   "Minimum wall clearance";
  parameter Real track_err_thresh(unit = "m") = 0.18 "Tracking error threshold after 10.4s";
  parameter Real t_track_check(unit = "s") = 10.4   "Tracking error check time";
  parameter Real route_length(unit = "m") = 10.0    "Route completion distance (assumed)";

  // ======================== Controller Gains ========================
  parameter Real kp_v(unit = "N.s/m") = 100.0    "Speed control proportional gain";
  parameter Real kp_lat(unit = "rad/m") = 3.0   "Lateral tracking gain";
  parameter Real kp_head(unit = "1") = 1.0       "Heading error gain";
  parameter Real kp_steer(unit = "N.m/rad") = 25.0  "Steering position gain";
  parameter Real kd_steer(unit = "N.m.s/rad") = 2.5 "Steering damping gain";

  // ======================== Estimator Gains ========================
  parameter Real K_odom(unit = "1/s") = 2.0   "Odometry correction gain";
  parameter Real K_lidar(unit = "1/s") = 1.5  "Lidar correction gain";
  parameter Real K_imu(unit = "1/s") = 3.0   "IMU correction gain";
  parameter Real K_v(unit = "1/s") = 2.0      "Speed correction gain";
  parameter Real Q_pos(unit = "m2/s") = 1e-4   "Position process noise covariance rate";
  parameter Real Q_theta(unit = "rad2/s") = 1e-5 "Heading process noise covariance rate";

  // ======================== Sensor Noise (assumed) ========================
  parameter Real noise_odom_pos(unit = "m") = 0.02   "Odometry position noise amplitude";
  parameter Real noise_odom_head(unit = "rad") = 0.01 "Odometry heading noise amplitude";
  parameter Real noise_imu_gyro(unit = "rad/s") = 0.001 "IMU gyro noise amplitude";
  parameter Real noise_imu_ax(unit = "m/s2") = 0.05  "IMU acceleration noise amplitude";
  parameter Real noise_lidar(unit = "m") = 0.02      "Lidar range noise amplitude";
  parameter Real noise_vodom(unit = "m/s") = 0.02     "Speed odometry noise amplitude";

  // ======================== True Plant States ========================
  Real x(start = 0.0, fixed = true, unit = "m")     "Global x position";
  Real y(start = 0.0, fixed = true, unit = "m")     "Global y position";
  Real theta(start = 0.0, fixed = true, unit = "rad") "Heading angle";
  Real v(start = 0.0, fixed = true, unit = "m/s")   "Forward speed";
  Real v_lat(start = 0.0, fixed = true, unit = "m/s") "Lateral slip velocity";
  Real delta(start = 0.0, fixed = true, unit = "rad") "Steering angle";
  Real delta_dot(start = 0.0, fixed = true, unit = "rad/s") "Steering rate";

  // ======================== Estimator States ========================
  Real x_est(start = 0.0, fixed = true, unit = "m")   "Estimated x";
  Real y_est(start = 0.0, fixed = true, unit = "m")   "Estimated y";
  Real theta_est(start = 0.0, fixed = true, unit = "rad") "Estimated heading";
  Real v_est(start = 0.0, fixed = true, unit = "m/s") "Estimated speed";
  Real P11(start = 0.01, fixed = true, unit = "m2")   "Covariance P(x,x)";
  Real P22(start = 0.01, fixed = true, unit = "m2")   "Covariance P(y,y)";
  Real P33(start = 0.001, fixed = true, unit = "rad2") "Covariance P(theta,theta)";

  // ======================== Commands ========================
  Real F_drive_raw(unit = "N")    "Unsaturated traction force command";
  Real tau_steer_raw(unit = "N.m") "Unsaturated steering torque command";
  Real F_drive(unit = "N")       "Saturated traction force";
  Real tau_steer(unit = "N.m")   "Saturated steering torque";
  Real delta_cmd(unit = "rad")   "Commanded steering angle from path tracking";
  Real delta_ff(unit = "rad")    "Feedforward steering from path curvature";
  Real kappa_path(unit = "1/m")  "Path curvature at estimated position";
  Real avoid_gain               "Obstacle avoidance gain multiplier";

  // ======================== Disturbance ========================
  Real F_side_load(unit = "N")   "Applied side load (108 N, middle third)";

  // ======================== Corridor Geometry ========================
  Real y_center(unit = "m")     "Corridor centerline y at current x";
  Real dy_center                "Slope of centerline dy/dx";
  Real theta_center(unit = "rad") "Centerline tangent heading";
  Real y_wall_L(unit = "m")     "Left wall y (with alcove recession)";
  Real y_wall_R(unit = "m")     "Right wall y (with alcove recession)";
  Real alcove_extra(unit = "m") "Alcove wall recession depth";
  Real clearance(unit = "m")    "Minimum clearance to either wall";

  // ======================== Path Tracking ========================
  Real e_lat(unit = "m")        "Estimated lateral tracking error";
  Real e_head(unit = "rad")    "Estimated heading error";
  Real route_dist(start = 0.0, fixed = true, unit = "m") "Distance traveled";
  Real track_err_at_check(start = 0.0) "Sampled tracking error at t=10.4s";

  // ======================== Sensors ========================
  Real odom_x(unit = "m")       "Wheel odometry x";
  Real odom_y(unit = "m")       "Wheel odometry y";
  Real odom_theta(unit = "rad") "Wheel odometry heading";
  Real v_odom(unit = "m/s")    "Wheel odometry speed";
  Real imu_gyro(unit = "rad/s") "IMU yaw rate measurement";
  Real imu_ax(unit = "m/s2")   "IMU longitudinal acceleration";
  Real lidar_L(unit = "m")     "Lidar range to left wall";
  Real lidar_R(unit = "m")     "Lidar range to right wall";
  Real lidar_y(unit = "m")     "Lidar-fused y position estimate";

  // ======================== Intermediate Variables ========================
  Real dc_est                   "Centerline slope at estimated x";
  Real denom_kappa              "Denominator for curvature";
  Real d1_alcove, d2_alcove     "Normalized distances to alcove centers";
  Real tau_softstop(unit = "N.m") "Soft stop torque at steering limits";

  // ======================== Acceptance ========================
  Boolean cov_finite  "Covariance is finite and positive";
  Boolean clear_ok    "Wall clearance above 0.18 m";
  Boolean track_ok    "Tracking error below 0.18 m after 10.4 s";
  Boolean route_ok    "Route completion achieved";
  Boolean no_nan_inf  "No NaN or infinite physical, control, or estimator values";
  Boolean acceptance  "Overall acceptance (fail-closed)";

equation
  // ==================== Corridor Geometry: S-shaped, 1.8 m walls, two recessed alcoves ====================
  y_center = A_corr * sin(k_corr * x);
  dy_center = A_corr * k_corr * cos(k_corr * x);
  theta_center = atan(dy_center);

  // Recessed alcoves at x=3 m and x=10 m (Gaussian-shaped wall recession, symmetric both sides)
  d1_alcove = (x - alcove_x1) / alcove_w;
  d2_alcove = (x - alcove_x2) / alcove_w;
  alcove_extra = alcove_depth * (exp(-d1_alcove * d1_alcove) + exp(-d2_alcove * d2_alcove));
  y_wall_L = y_center + w_half + alcove_extra;
  y_wall_R = y_center - w_half - alcove_extra;

  clearance = min(y_wall_L - y, y - y_wall_R);

  // ==================== Side Load Disturbance (108 N, middle third of 16 s) ====================
  F_side_load = if (time >= t_dist_start and time <= t_dist_end) then F_side_amp else 0.0;

  // ==================== Vehicle Dynamics ====================
  // Front-wheel drive-and-steer tricycle:
  //   - Front wheel: traction force F_drive along heading, steering torque tau_steer about vertical axis
  //   - Two passive rear wheels: constrain lateral motion (v_lat damped by tire lateral forces c_lat)
  der(x) = v * cos(theta) - v_lat * sin(theta);
  der(y) = v * sin(theta) + v_lat * cos(theta);
  der(theta) = v * tan(delta) / L_wb;
  m_total * der(v) = F_drive - c_drag * v;
  m_total * der(v_lat) = F_side_load - c_lat * v_lat;

  // Steering dynamics: effort-controlled (torque drives steering axis)
  der(delta) = delta_dot;
  I_steer * der(delta_dot) = tau_steer + tau_softstop - b_steer * delta_dot;

  // Soft stop enforcing steering travel +/- 0.60 rad
  tau_softstop = -k_softstop * (max(0.0, delta - delta_max) - max(0.0, -delta_max - delta));

  // ==================== Sensor Models (noisy measurements of true state) ====================
  // Wheel odometry
  odom_x = x + noise_odom_pos * sin(7.0 * time);
  odom_y = y + noise_odom_pos * cos(5.0 * time);
  odom_theta = theta + noise_odom_head * sin(11.0 * time);
  v_odom = v + noise_vodom * sin(13.0 * time);

  // IMU
  imu_gyro = v * tan(delta) / L_wb + noise_imu_gyro * sin(20.0 * time);
  imu_ax = (F_drive - c_drag * v) / m_total + noise_imu_ax * sin(15.0 * time);

  // Planar lidar (15 m max range, measures perpendicular range to left and right walls)
  lidar_L = min(lidar_range_max, y_wall_L - y + noise_lidar * sin(8.0 * time));
  lidar_R = min(lidar_range_max, y - y_wall_R + noise_lidar * cos(6.0 * time));
  // Fuse left and right lidar ranges to derive y position
  lidar_y = (y_wall_L - lidar_L + y_wall_R + lidar_R) / 2.0;

  // ==================== Localization Fusion: complementary filter fusing odometry + IMU + lidar ====================
  der(x_est) = v_est * cos(theta_est) + K_odom * (odom_x - x_est);
  der(y_est) = v_est * sin(theta_est) + K_odom * (odom_y - y_est) + K_lidar * (lidar_y - y_est);
  der(theta_est) = imu_gyro + K_imu * (odom_theta - theta_est);
  der(v_est) = imu_ax + K_v * (v_odom - v_est);

  // Covariance propagation (simplified Riccati: grows with process noise, shrinks with measurement updates)
  der(P11) = Q_pos - 2.0 * K_odom * P11;
  der(P22) = Q_pos - 2.0 * (K_odom + K_lidar) * P22;
  der(P33) = Q_theta - 2.0 * K_imu * P33;

  // ==================== Localization-Aware Path Tracking Controller ====================
  // Estimated lateral error from centerline (uses fused pose)
  e_lat = y_est - A_corr * sin(k_corr * x_est);
  // Estimated heading error (tangent of centerline at estimated x)
  e_head = theta_est - atan(A_corr * k_corr * cos(k_corr * x_est));

  // Path curvature at estimated position for feedforward steering
  dc_est = A_corr * k_corr * cos(k_corr * x_est);
  denom_kappa = (1.0 + dc_est * dc_est) ^ 1.5;
  kappa_path = -A_corr * k_corr * k_corr * sin(k_corr * x_est) / denom_kappa;
  delta_ff = atan(L_wb * kappa_path);

  // Obstacle avoidance: increase correction gain when wall clearance is low
  avoid_gain = 1.0 + max(0.0, 1.0 - clearance / (2.0 * clearance_min));

  // Steering command: path tracking + obstacle avoidance + curvature feedforward, limited to +/- 0.60 rad
  delta_cmd = max(-delta_max, min(avoid_gain * (-kp_lat * e_lat - kp_head * e_head) + delta_ff, delta_max));

  // Speed control: effort-controlled traction with drag feedforward
  F_drive_raw = kp_v * (v_ref - v_est) + c_drag * v_ref;
  F_drive = max(-F_drive_max, min(F_drive_raw, F_drive_max));

  // Steering torque control: effort-controlled steering axis, bounded by 37.4 N.m
  tau_steer_raw = kp_steer * (delta_cmd - delta) - kd_steer * delta_dot;
  tau_steer = max(-tau_max, min(tau_steer_raw, tau_max));

  // ==================== Route Progress ====================
  der(route_dist) = sqrt(v * v + v_lat * v_lat);

  // ==================== Tracking Error Sampling at t = 10.4 s ====================
  when time >= t_track_check then
    track_err_at_check = abs(e_lat);
  end when;

  // ==================== Acceptance Criteria (fail-closed) ====================
  // 1. Finite covariance (positive and bounded)
  cov_finite = P11 > 0.0 and P11 < 1.0 and P22 > 0.0 and P22 < 1.0 and P33 > 0.0 and P33 < 0.1;

  // 2. Wall clearance above 0.18 m
  clear_ok = clearance >= clearance_min;

  // 3. Primary tracking error below 0.18 m after 10.4 s
  track_ok = track_err_at_check < track_err_thresh;

  // 4. Route completion
  route_ok = route_dist >= route_length;

  // 5. No NaN or infinite physical, control, or estimator values
  no_nan_inf = x > -1e6 and x < 1e6 and
               y > -1e6 and y < 1e6 and
               theta > -1e6 and theta < 1e6 and
               v > -1e6 and v < 1e6 and
               v_lat > -1e6 and v_lat < 1e6 and
               delta > -1e6 and delta < 1e6 and
               delta_dot > -1e6 and delta_dot < 1e6 and
               F_drive > -1e6 and F_drive < 1e6 and
               tau_steer > -1e6 and tau_steer < 1e6 and
               x_est > -1e6 and x_est < 1e6 and
               y_est > -1e6 and y_est < 1e6 and
               theta_est > -1e6 and theta_est < 1e6 and
               v_est > -1e6 and v_est < 1e6 and
               P11 > 0.0 and P11 < 1e6 and
               P22 > 0.0 and P22 < 1e6 and
               P33 > 0.0 and P33 < 1e6 and
               clearance > -1e6 and clearance < 1e6;

  // Overall acceptance: all criteria must hold simultaneously (fail-closed)
  acceptance = cov_finite and clear_ok and track_ok and route_ok and no_nan_inf;

  annotation(
    experiment(StartTime = 0, StopTime = 16.0, Tolerance = 1e-6, Interval = 0.004),
    Documentation(info = "TriTugInspectE: 38 kg chassis + 20 kg payload front-wheel drive-and-steer tricycle.
    Front wheel: 0.15 m radius, effort-controlled traction and steering (37.4 N.m bound).
    Two passive rear wheels. Steering travel +/- 0.60 rad.
    S-shaped corridor 1.8 m apart with two recessed alcoves.
    Fuses wheel odometry, IMU, 15 m planar lidar.
    108 N side load disturbance in middle third (5.33-10.67 s).
    Runs at 250 Hz (Interval=0.004) for 16 s.
    Acceptance: finite covariance, clearance > 0.18 m, tracking error < 0.18 m after 10.4 s,
    route completion, no NaN/inf. Fail-closed."));
end TriTugInspectE;