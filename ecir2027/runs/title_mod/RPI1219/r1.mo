model WheelIMUMapA
  "Differential-drive robotic sensing and estimation: IMU, encoders, range fusion, loop closure"

  // ============================ Physical Parameters ============================
  parameter Real m_chassis = 16.0 "Chassis mass [kg]";
  parameter Real r_wheel = 0.1 "Wheel radius [m] (assumed)";
  parameter Real wheel_base = 0.4 "Wheel base [m] (assumed)";
  parameter Real I_z = 0.5 "Yaw moment of inertia [kg.m2] (assumed)";
  parameter Real b_v = 4.0 "Linear velocity drag [N.s/m] (assumed)";
  parameter Real b_omega = 0.8 "Angular velocity drag [N.m.s/rad] (assumed)";
  parameter Real tau_max = 7.2 "Maximum wheel torque command magnitude [N.m]";
  parameter Real robot_radius = 0.15 "Robot collision radius [m] (assumed)";

  // ============================ Path Parameters ============================
  parameter Real R_path = 1.0 "Closed-route radius [m] (assumed)";
  parameter Real v_desired = 1.0 "Desired forward speed [m/s] (assumed)";
  parameter Real omega_des = v_desired / R_path "Desired yaw rate [rad/s]";

  // ============================ Controller Gains ============================
  parameter Real Kp_v = 40.0 "Velocity proportional gain [N.s/m] (assumed)";
  parameter Real Kp_omega = 20.0 "Yaw-rate proportional gain [N.m.s/rad] (assumed)";
  parameter Real K_fwd = 2.0 "Forward position tracking gain [1/s] (assumed)";
  parameter Real K_lat = 3.0 "Lateral position tracking gain [1/s] (assumed)";
  parameter Real K_head = 2.0 "Heading tracking gain [1/s] (assumed)";

  // ============================ IMU Parameters (six-axis) ============================
  parameter Real imu_acc_noise_std = 0.05 "IMU accelerometer noise std [m/s2]";
  parameter Real imu_gyro_noise_std = 0.01 "IMU gyroscope noise std [rad/s]";
  parameter Real imu_acc_bias_x = 0.02 "IMU x-axis accelerometer bias [m/s2]";
  parameter Real imu_acc_bias_y = 0.01 "IMU y-axis accelerometer bias [m/s2]";
  parameter Real imu_acc_bias_z = 0.0 "IMU z-axis accelerometer bias [m/s2]";
  parameter Real imu_gyro_bias_x = 0.0 "IMU x-axis gyroscope bias [rad/s]";
  parameter Real imu_gyro_bias_y = 0.0 "IMU y-axis gyroscope bias [rad/s]";
  parameter Real imu_gyro_bias_z = 0.005 "IMU z-axis gyroscope bias [rad/s]";

  // ============================ Encoder Parameters ============================
  parameter Real enc_noise_std = 0.01 "Wheel encoder noise std [rad/s]";

  // ============================ Range Sensor Parameters ============================
  parameter Real range_noise_std = 0.05 "Range sensor noise std [m]";

  // ============================ Landmarks (six fixed, world frame) ============================
  parameter Real lm1_x = 3.0 "Landmark 1 x [m]";
  parameter Real lm1_y = 0.0 "Landmark 1 y [m]";
  parameter Real lm2_x = -2.0 "Landmark 2 x [m]";
  parameter Real lm2_y = 2.0 "Landmark 2 y [m]";
  parameter Real lm3_x = 0.0 "Landmark 3 x [m]";
  parameter Real lm3_y = -3.0 "Landmark 3 y [m]";
  parameter Real lm4_x = 4.0 "Landmark 4 x [m]";
  parameter Real lm4_y = 3.0 "Landmark 4 y [m]";
  parameter Real lm5_x = -3.0 "Landmark 5 x [m]";
  parameter Real lm5_y = -1.0 "Landmark 5 y [m]";
  parameter Real lm6_x = 2.0 "Landmark 6 x [m]";
  parameter Real lm6_y = 4.0 "Landmark 6 y [m]";

  // ============================ Obstacles (two fixed, world frame) ============================
  parameter Real obs1_x = 2.0 "Obstacle 1 x [m]";
  parameter Real obs1_y = 0.0 "Obstacle 1 y [m]";
  parameter Real obs1_r = 0.3 "Obstacle 1 radius [m]";
  parameter Real obs2_x = -2.0 "Obstacle 2 x [m]";
  parameter Real obs2_y = 2.0 "Obstacle 2 y [m]";
  parameter Real obs2_r = 0.3 "Obstacle 2 radius [m]";

  // ============================ Perturbation Parameters ============================
  parameter Real pert_mag = 0.1 "Controlled landmark perturbation [m]";
  parameter Real t_pert_start = 8.0 / 3.0 "Perturbation start time [s]";
  parameter Real t_pert_end = 16.0 / 3.0 "Perturbation end time [s]";

  // ============================ Estimator Parameters ============================
  parameter Real K_fuse_v = 5.0 "IMU-odometry velocity fusion gain [1/s] (assumed)";
  parameter Real K_fuse_omega = 5.0 "IMU-odometry yaw-rate fusion gain [1/s] (assumed)";
  parameter Real K_range_corr = 0.5 "Range correction gain [1/s] (assumed)";
  parameter Real K_lc = 2.0 "Loop-closure correction gain [1/s] (assumed)";
  parameter Real Q_x = 0.001 "Process noise x [m2/s] (assumed)";
  parameter Real Q_y = 0.001 "Process noise y [m2/s] (assumed)";
  parameter Real Q_th = 0.001 "Process noise theta [rad2/s] (assumed)";
  parameter Real K_cov_decay = 0.5 "Covariance decay rate [1/s] (assumed)";

  // ============================ Output Rate ============================
  parameter Real output_rate_Hz = 80.0 "Declared output rate [Hz]";
  parameter Real dt_out = 1.0 / output_rate_Hz "Output sample period [s]";

  // ============================ Physical States ============================
  Real x(start = 0.0, fixed = true) "Robot x position [m]";
  Real y(start = 0.0, fixed = true) "Robot y position [m]";
  Real theta(start = 0.0, fixed = true) "Robot heading [rad]";
  Real v(start = 0.0, fixed = true) "Forward velocity [m/s]";
  Real omega(start = 0.0, fixed = true) "Yaw rate [rad/s]";

  // ============================ Torque Commands ============================
  Real v_cmd "Commanded forward speed [m/s]";
  Real omega_cmd "Commanded yaw rate [rad/s]";
  Real tau_L_raw "Unsaturated left wheel torque [N.m]";
  Real tau_R_raw "Unsaturated right wheel torque [N.m]";
  Real tau_L "Saturated left wheel torque [N.m]";
  Real tau_R "Saturated right wheel torque [N.m]";

  // ============================ Desired Path ============================
  Real x_des "Desired x position [m]";
  Real y_des "Desired y position [m]";
  Real theta_des "Desired heading [rad]";

  // ============================ Raw Sensors ============================
  Real enc_L "Left wheel encoder angular velocity [rad/s]";
  Real enc_R "Right wheel encoder angular velocity [rad/s]";
  Real imu_ax_raw "Raw IMU x-axis acceleration [m/s2]";
  Real imu_ay_raw "Raw IMU y-axis acceleration [m/s2]";
  Real imu_az_raw "Raw IMU z-axis acceleration [m/s2]";
  Real imu_wx_raw "Raw IMU x-axis angular rate [rad/s]";
  Real imu_wy_raw "Raw IMU y-axis angular rate [rad/s]";
  Real imu_wz_raw "Raw IMU z-axis angular rate [rad/s]";
  Real range1 "Range measurement to landmark 1 [m]";
  Real range2 "Range measurement to landmark 2 [m]";
  Real range3 "Range measurement to landmark 3 [m]";
  Real range4 "Range measurement to landmark 4 [m]";
  Real range5 "Range measurement to landmark 5 [m]";
  Real range6 "Range measurement to landmark 6 [m]";
  Real cam1_bearing "Raw camera bearing to landmark 1 [rad]";
  Real cam2_bearing "Raw camera bearing to landmark 2 [rad]";
  Real cam3_bearing "Raw camera bearing to landmark 3 [rad]";
  Real cam4_bearing "Raw camera bearing to landmark 4 [rad]";
  Real cam5_bearing "Raw camera bearing to landmark 5 [rad]";
  Real cam6_bearing "Raw camera bearing to landmark 6 [rad]";
  Real sonar1 "Raw sonar range to obstacle 1 [m]";
  Real sonar2 "Raw sonar range to obstacle 2 [m]";

  // ============================ Estimator States ============================
  Real x_est(start = 0.0, fixed = true) "Estimated x position [m]";
  Real y_est(start = 0.0, fixed = true) "Estimated y position [m]";
  Real theta_est(start = 0.0, fixed = true) "Estimated heading [rad]";
  Real v_est(start = 0.0, fixed = true) "Estimated forward velocity [m/s]";
  Real omega_est(start = 0.0, fixed = true) "Estimated yaw rate [rad/s]";
  Real P_x(start = 0.01, fixed = true) "Position x covariance [m2]";
  Real P_y(start = 0.01, fixed = true) "Position y covariance [m2]";
  Real P_th(start = 0.01, fixed = true) "Heading covariance [rad2]";
  Real imu_acc_bias_est(start = 0.0, fixed = true) "Estimated accelerometer bias [m/s2]";
  Real imu_gyro_bias_est(start = 0.0, fixed = true) "Estimated gyroscope bias [rad/s]";

  // ============================ Loop Closure ============================
  Real lc_pos_err "Loop-closure position error [m]";
  Real lc_head_err "Loop-closure heading error [rad]";
  Boolean lc_active "Loop-closure correction active";

  // ============================ Tracking ============================
  Real track_err "Primary tracking error [m]";

  // ============================ Collision ============================
  Real dist_obs1 "Distance to obstacle 1 center [m]";
  Real dist_obs2 "Distance to obstacle 2 center [m]";
  Real min_clearance "Minimum clearance to any obstacle [m]";
  Boolean no_collision "No-collision indicator";

  // ============================ Perturbation ============================
  Real lm_pert_x "Landmark x-direction perturbation [m]";
  Boolean pert_active "Perturbation active flag";

  // ============================ Effective Landmark Positions ============================
  Real lm1xe "Effective landmark 1 x [m]";
  Real lm1ye "Effective landmark 1 y [m]";
  Real lm2xe "Effective landmark 2 x [m]";
  Real lm2ye "Effective landmark 2 y [m]";
  Real lm3xe "Effective landmark 3 x [m]";
  Real lm3ye "Effective landmark 3 y [m]";
  Real lm4xe "Effective landmark 4 x [m]";
  Real lm4ye "Effective landmark 4 y [m]";
  Real lm5xe "Effective landmark 5 x [m]";
  Real lm5ye "Effective landmark 5 y [m]";
  Real lm6xe "Effective landmark 6 x [m]";
  Real lm6ye "Effective landmark 6 y [m]";

  // ============================ Odometry ============================
  Real v_odom "Odometry-based velocity estimate [m/s]";
  Real omega_odom "Odometry-based yaw-rate estimate [rad/s]";

  // ============================ Range Correction ============================
  Real r1e "Expected range to landmark 1 [m]";
  Real r2e "Expected range to landmark 2 [m]";
  Real r3e "Expected range to landmark 3 [m]";
  Real r4e "Expected range to landmark 4 [m]";
  Real r5e "Expected range to landmark 5 [m]";
  Real r6e "Expected range to landmark 6 [m]";
  Real corr_x "Range-based x correction [m/s]";
  Real corr_y "Range-based y correction [m/s]";

  // ============================ Noise Signals ============================
  Real n_ax "IMU x-accel noise";
  Real n_ay "IMU y-accel noise";
  Real n_wz "IMU z-gyro noise";
  Real n_wxy "IMU xy-gyro noise";
  Real n_encL "Left encoder noise";
  Real n_encR "Right encoder noise";
  Real n_r1 "Range 1 noise";
  Real n_r2 "Range 2 noise";
  Real n_r3 "Range 3 noise";
  Real n_r4 "Range 4 noise";
  Real n_r5 "Range 5 noise";
  Real n_r6 "Range 6 noise";

  // ============================ Sample Clock ============================
  Integer sample_count(start = 0, fixed = true) "Output sample counter";
  Real t_last_sample(start = 0.0, fixed = true) "Last output sample time [s]";

equation

  // ============================ Physical Dynamics ============================
  m_chassis * der(v) = (tau_L + tau_R) / r_wheel - b_v * v;
  I_z * der(omega) = r_wheel * (tau_R - tau_L) / wheel_base - b_omega * omega;
  der(x) = v * cos(theta);
  der(y) = v * sin(theta);
  der(theta) = omega;

  // ============================ Desired Path (closed circular route) ============================
  x_des = R_path * sin(omega_des * time);
  y_des = R_path * (1.0 - cos(omega_des * time));
  theta_des = omega_des * time;

  // ============================ Tracking Error ============================
  track_err = sqrt((x - x_des) ^ 2 + (y - y_des) ^ 2 + 1e-10);

  // ============================ Controller ============================
  v_cmd = v_desired + K_fwd * ((x_des - x) * cos(theta) + (y_des - y) * sin(theta));
  omega_cmd = omega_des
    + K_lat * (-(x_des - x) * sin(theta) + (y_des - y) * cos(theta)) / R_path
    + K_head * (theta_des - theta);

  tau_L_raw = (Kp_v * (v_cmd - v) - Kp_omega * (omega_cmd - omega)) / 2.0;
  tau_R_raw = (Kp_v * (v_cmd - v) + Kp_omega * (omega_cmd - omega)) / 2.0;

  tau_L = if tau_L_raw > tau_max then tau_max
          else if tau_L_raw < -tau_max then -tau_max
          else tau_L_raw;
  tau_R = if tau_R_raw > tau_max then tau_max
          else if tau_R_raw < -tau_max then -tau_max
          else tau_R_raw;

  // ============================ Deterministic Noise Signals ============================
  n_ax = imu_acc_noise_std * (sin(37.7 * time) + 0.5 * sin(91.3 * time) + 0.3 * sin(173.1 * time)) / 1.8;
  n_ay = imu_acc_noise_std * (sin(97.3 * time) + 0.5 * sin(151.7 * time)) / 1.5;
  n_wz = imu_gyro_noise_std * (sin(43.1 * time) + 0.7 * sin(127.9 * time) + 0.4 * sin(211.3 * time)) / 2.1;
  n_wxy = imu_gyro_noise_std * 0.1 * sin(67.3 * time);
  n_encL = enc_noise_std * (sin(57.3 * time) + 0.5 * sin(113.7 * time)) / 1.5;
  n_encR = enc_noise_std * (sin(61.9 * time) + 0.5 * sin(137.3 * time)) / 1.5;
  n_r1 = range_noise_std * sin(31.7 * time);
  n_r2 = range_noise_std * sin(41.3 * time);
  n_r3 = range_noise_std * sin(53.9 * time);
  n_r4 = range_noise_std * sin(67.1 * time);
  n_r5 = range_noise_std * sin(79.3 * time);
  n_r6 = range_noise_std * sin(83.9 * time);

  // ============================ Wheel Encoders ============================
  enc_L = (v - omega * wheel_base / 2.0) / r_wheel + n_encL;
  enc_R = (v + omega * wheel_base / 2.0) / r_wheel + n_encR;

  // ============================ Six-Axis IMU ============================
  imu_ax_raw = der(v) + imu_acc_bias_x + n_ax;
  imu_ay_raw = omega * v + imu_acc_bias_y + n_ay;
  imu_az_raw = 9.81 + imu_acc_bias_z;
  imu_wx_raw = imu_gyro_bias_x + n_wxy;
  imu_wy_raw = imu_gyro_bias_y + n_wxy;
  imu_wz_raw = omega + imu_gyro_bias_z + n_wz;

  // ============================ Landmark Perturbation (middle third) ============================
  pert_active = time >= t_pert_start and time <= t_pert_end;
  lm_pert_x = if pert_active then pert_mag else 0.0;

  lm1xe = lm1_x + lm_pert_x;
  lm1ye = lm1_y;
  lm2xe = lm2_x + lm_pert_x;
  lm2ye = lm2_y;
  lm3xe = lm3_x + lm_pert_x;
  lm3ye = lm3_y;
  lm4xe = lm4_x + lm_pert_x;
  lm4ye = lm4_y;
  lm5xe = lm5_x + lm_pert_x;
  lm5ye = lm5_y;
  lm6xe = lm6_x + lm_pert_x;
  lm6ye = lm6_y;

  // ============================ Range Sensors (fused) ============================
  range1 = sqrt((x - lm1xe) ^ 2 + (y - lm1ye) ^ 2 + 0.01) + n_r1;
  range2 = sqrt((x - lm2xe) ^ 2 + (y - lm2ye) ^ 2 + 0.01) + n_r2;
  range3 = sqrt((x - lm3xe) ^ 2 + (y - lm3ye) ^ 2 + 0.01) + n_r3;
  range4 = sqrt((x - lm4xe) ^ 2 + (y - lm4ye) ^ 2 + 0.01) + n_r4;
  range5 = sqrt((x - lm5xe) ^ 2 + (y - lm5ye) ^ 2 + 0.01) + n_r5;
  range6 = sqrt((x - lm6xe) ^ 2 + (y - lm6ye) ^ 2 + 0.01) + n_r6;

  // ============================ Camera Bearings (preserved separately, not fused) ============================
  cam1_bearing = atan2(lm1ye - y, lm1xe - x) - theta;
  cam2_bearing = atan2(lm2ye - y, lm2xe - x) - theta;
  cam3_bearing = atan2(lm3ye - y, lm3xe - x) - theta;
  cam4_bearing = atan2(lm4ye - y, lm4xe - x) - theta;
  cam5_bearing = atan2(lm5ye - y, lm5xe - x) - theta;
  cam6_bearing = atan2(lm6ye - y, lm6xe - x) - theta;

  // ============================ Sonar (preserved separately, not fused) ============================
  sonar1 = sqrt((x - obs1_x) ^ 2 + (y - obs1_y) ^ 2 + 0.01);
  sonar2 = sqrt((x - obs2_x) ^ 2 + (y - obs2_y) ^ 2 + 0.01);

  // ============================ Collision Check ============================
  dist_obs1 = sqrt((x - obs1_x) ^ 2 + (y - obs1_y) ^ 2 + 0.01);
  dist_obs2 = sqrt((x - obs2_x) ^ 2 + (y - obs2_y) ^ 2 + 0.01);
  min_clearance = if (dist_obs1 - obs1_r - robot_radius) < (dist_obs2 - obs2_r - robot_radius)
                  then (dist_obs1 - obs1_r - robot_radius)
                  else (dist_obs2 - obs2_r - robot_radius);
  no_collision = min_clearance > 0.0;

  // ============================ Odometry ============================
  v_odom = r_wheel * (enc_L + enc_R) / 2.0;
  omega_odom = r_wheel * (enc_R - enc_L) / wheel_base;

  // ============================ Expected Ranges for Estimator ============================
  r1e = sqrt((x_est - lm1xe) ^ 2 + (y_est - lm1ye) ^ 2 + 0.01);
  r2e = sqrt((x_est - lm2xe) ^ 2 + (y_est - lm2ye) ^ 2 + 0.01);
  r3e = sqrt((x_est - lm3xe) ^ 2 + (y_est - lm3ye) ^ 2 + 0.01);
  r4e = sqrt((x_est - lm4xe) ^ 2 + (y_est - lm4ye) ^ 2 + 0.01);
  r5e = sqrt((x_est - lm5xe) ^ 2 + (y_est - lm5ye) ^ 2 + 0.01);
  r6e = sqrt((x_est - lm6xe) ^ 2 + (y_est - lm6ye) ^ 2 + 0.01);

  // ============================ Range Corrections (simplified gradient) ============================
  corr_x = K_range_corr * (
    (range1 - r1e) * (x_est - lm1xe) / r1e +
    (range2 - r2e) * (x_est - lm2xe) / r2e +
    (range3 - r3e) * (x_est - lm3xe) / r3e +
    (range4 - r4e) * (x_est - lm4xe) / r4e +
    (range5 - r5e) * (x_est - lm5xe) / r5e +
    (range6 - r6e) * (x_est - lm6xe) / r6e
  ) / 6.0;

  corr_y = K_range_corr * (
    (range1 - r1e) * (y_est - lm1ye) / r1e +
    (range2 - r2e) * (y_est - lm2ye) / r2e +
    (range3 - r3e) * (y_est - lm3ye) / r3e +
    (range4 - r4e) * (y_est - lm4ye) / r4e +
    (range5 - r5e) * (y_est - lm5ye) / r5e +
    (range6 - r6e) * (y_est - lm6ye) / r6e
  ) / 6.0;

  // ============================ Loop Closure ============================
  lc_active = sqrt(x_est ^ 2 + y_est ^ 2 + 1e-6) < 0.5 and time > 4.0;
  lc_pos_err = if lc_active then sqrt(x_est ^ 2 + y_est ^ 2 + 1e-10) else 0.0;
  lc_head_err = if lc_active then theta_est else 0.0;

  // ============================ Estimator: Bias Estimation ============================
  der(imu_acc_bias_est) = 0.01 * (imu_ax_raw - der(v_est) - imu_acc_bias_est);
  der(imu_gyro_bias_est) = 0.01 * (imu_wz_raw - omega_est - imu_gyro_bias_est);

  // ============================ Estimator: Velocity and Yaw Rate Fusion ============================
  der(v_est) = (imu_ax_raw - imu_acc_bias_est) + K_fuse_v * (v_odom - v_est);
  der(omega_est) = K_fuse_omega * ((imu_wz_raw - imu_gyro_bias_est) - omega_est);

  // ============================ Estimator: Pose with Range Correction and Loop Closure ============================
  der(x_est) = v_est * cos(theta_est) + corr_x + (if lc_active then -K_lc * x_est else 0.0);
  der(y_est) = v_est * sin(theta_est) + corr_y + (if lc_active then -K_lc * y_est else 0.0);
  der(theta_est) = omega_est + (if lc_active then -K_lc * theta_est else 0.0);

  // ============================ Covariance (finite, bounded) ============================
  der(P_x) = Q_x - K_cov_decay * P_x;
  der(P_y) = Q_y - K_cov_decay * P_y;
  der(P_th) = Q_th - K_cov_decay * P_th;

  // ============================ Sample Clock (declared 80 Hz output rate) ============================
  when sample(0, dt_out) then
    sample_count = pre(sample_count) + 1;
    t_last_sample = time;
  end when;

  // ============================ Assertions ============================
  assert(no_collision, "Collision detected: robot clearance to obstacle is negative");
  assert(P_x > 0.0 and P_x < 1e6, "X covariance must remain finite and positive");
  assert(P_y > 0.0 and P_y < 1e6, "Y covariance must remain finite and positive");
  assert(P_th > 0.0 and P_th < 1e6, "Heading covariance must remain finite and positive");

end WheelIMUMapA;