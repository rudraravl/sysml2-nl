model WheelIMUMapB
  // ===== Physical parameters (given or assumed, SI) =====
  parameter Real m = 16.0 "chassis mass, kg (given)";
  parameter Real r = 0.05 "wheel radius, m (assumed)";
  parameter Real L = 0.40 "wheel base, m (assumed)";
  parameter Real Iz = 0.60 "yaw inertia, kg.m2 (assumed)";
  parameter Real tau_max = 8.2 "allowed wheel torque magnitude, N.m (given)";
  parameter Real tau_drv = 0.05 "drivetrain lag, s (assumed)";
  parameter Real robot_radius = 0.20 "chassis collision radius, m (assumed)";

  // ===== IMU declared noise and bias =====
  parameter Real accel_noise_std = 0.05 "accel noise std, m/s2 (declared)";
  parameter Real gyro_noise_std = 0.01 "gyro noise std, rad/s (declared)";
  parameter Real accel_bias_decl = 0.02 "accel bias, m/s2 (declared)";
  parameter Real gyro_bias_decl = 0.005 "gyro bias, rad/s (declared)";

  // ===== Mission / output =====
  parameter Real output_rate_Hz = 100.0 "declared output rate, Hz (given)";
  parameter Real dt_out = 1.0 / output_rate_Hz "s";
  parameter Real T_total = 10.0 "mission duration, s (given)";
  parameter Real R_route = 1.5 "closed route radius, m (assumed)";
  parameter Real dperturb = 0.14 "landmark perturbation, m (given)";
  parameter Real pi_val = 3.141592653589793;
  parameter Real pi_half = 1.5707963267948966;

  // ===== Landmarks (6 fixed) =====
  parameter Real lx[6] = {2.5, 1.5, -1.5, -2.5, 0.0, 3.0} "m";
  parameter Real ly[6] = {0.0, 2.2, 2.0, -0.5, -2.2, 1.5} "m";

  // ===== Obstacles (2) =====
  parameter Real ox[2] = {2.5, -2.5} "m";
  parameter Real oy[2] = {1.0, -1.0} "m";
  parameter Real orad[2] = {0.30, 0.30} "obstacle radius, m (assumed)";

  // ===== Controller / estimator gains (assumed) =====
  parameter Real Kv = 2.0;
  parameter Real Kp = 5.0;
  parameter Real Ko = 1.0;
  parameter Real Kh = 4.0;
  parameter Real Ky = 3.0;
  parameter Real tau_est = 0.10;
  parameter Real Kg = 2.0;
  parameter Real K_range = 0.5;
  parameter Real K_lc = 1.0;
  parameter Real K_lc_h = 2.0;
  parameter Real Q_pose = 0.01;
  parameter Real Q_theta = 0.001;
  parameter Real tau_p = 2.0;

  // ===== Physical states =====
  Real x(start = 1.5) "world x, m";
  Real y(start = 0.0) "world y, m";
  Real theta(start = 1.5707963267948966) "heading, rad";
  Real v(start = 0.0) "forward speed, m/s";
  Real omega(start = 0.0) "yaw rate, rad/s";
  Real F_L(start = 0.0) "left tractive force, N";
  Real F_R(start = 0.0) "right tractive force, N";

  // ===== Wheel kinematics (no-slip) =====
  Real omega_L "left wheel angular velocity, rad/s";
  Real omega_R "right wheel angular velocity, rad/s";

  // ===== Commands =====
  Real tau_L_cmd "left wheel torque command, N.m";
  Real tau_R_cmd "right wheel torque command, N.m";
  Real tau_L "saturated left torque, N.m";
  Real tau_R "saturated right torque, N.m";

  // ===== Reference =====
  Real phi_ref "route angle, rad";
  Real x_ref "m";
  Real y_ref "m";
  Real theta_ref "rad";
  Real v_ref "m/s";
  Real omega_ref "rad/s";

  // ===== Sensors (raw) =====
  Real accel_raw "body longitudinal accel raw, m/s2";
  Real gyro_raw "yaw rate raw, rad/s";
  Real v_odo "odometry forward speed, m/s";
  Real omega_odo "odometry yaw rate, rad/s";
  Real range_raw[6] "raw range to each landmark, m";
  Real camera_data[6] "camera bearing observations (preserved separately), rad";
  Real sonar_data[2] "sonar ranges to obstacles (preserved separately), m";

  // ===== Estimator =====
  Real x_est(start = 1.5) "m";
  Real y_est(start = 0.0) "m";
  Real theta_est(start = 1.5707963267948966) "rad";
  Real v_est(start = 0.0) "m/s";
  Real omega_est(start = 0.0) "rad/s";
  Real P_pose(start = 1.0) "finite scalar pose covariance, m2";
  Real P_theta(start = 0.1) "finite scalar heading covariance, rad2";
  Real r_pred_i[6] "m";
  Real ux_i[6];
  Real uy_i[6];
  Real innov_i[6] "m";
  Real corr_x "m/s";
  Real corr_y "m/s";
  Real dp_active "perturbation active flag";
  Real lc_pos_err "m";
  Real lc_head_err "rad";

  // ===== Controller intermediates =====
  Real ex_w, ey_w, ex_b, ey_b, eth;
  Real a_des "m/s2";
  Real alpha_des "rad/s2";
  Real F_des "N";
  Real M_des "N.m";
  Real F_L_des "N";
  Real F_R_des "N";

  // ===== Performance metrics =====
  Real e_track "primary tracking error, m";
  Real e_track_after "tracking error observed after 6.5 s, m";
  Real d_obs1 "m";
  Real d_obs2 "m";
  Boolean no_collision;
  Real noise_t;

  // ===== Synchronized traces (sampled at 100 Hz) =====
  Real t_sync;
  Real x_sync, y_sync, theta_sync;
  Real tau_L_sync, tau_R_sync;
  Real accel_sync, gyro_sync;
  Real range_sync_1, range_sync_2, range_sync_3;
  Real camera_sync_1, camera_sync_2;
  Real sonar_sync_1, sonar_sync_2;

equation

  // ----- Reference closed route (one loop over T_total) -----
  phi_ref = (2.0 * pi_val / T_total) * time;
  x_ref = R_route * cos(phi_ref);
  y_ref = R_route * sin(phi_ref);
  theta_ref = phi_ref + pi_half;
  v_ref = R_route * (2.0 * pi_val / T_total);
  omega_ref = 2.0 * pi_val / T_total;

  // ----- Chassis dynamics -----
  der(x) = v * cos(theta);
  der(y) = v * sin(theta);
  der(theta) = omega;
  der(v) = (F_L + F_R) / m;
  der(omega) = (L / 2.0) * (F_R - F_L) / Iz;
  der(F_L) = (tau_L / r - F_L) / tau_drv;
  der(F_R) = (tau_R / r - F_R) / tau_drv;

  // No-slip wheel rates (for odometry)
  omega_L = (v - (L / 2.0) * omega) / r;
  omega_R = (v + (L / 2.0) * omega) / r;

  // ----- Command saturation -----
  tau_L = if tau_L_cmd > tau_max then tau_max elseif tau_L_cmd < -tau_max then -tau_max else tau_L_cmd;
  tau_R = if tau_R_cmd > tau_max then tau_max elseif tau_R_cmd < -tau_max then -tau_max else tau_R_cmd;

  // ----- Deterministic bounded pseudo-noise (no NaN) -----
  noise_t = 0.1 * sin(7.0 * time) + 0.05 * sin(13.0 * time);

  // ----- Raw IMU (with declared noise and bias) -----
  accel_raw = (F_L + F_R) / m + accel_bias_decl + accel_noise_std * noise_t;
  gyro_raw = omega + gyro_bias_decl + gyro_noise_std * noise_t;

  // ----- Raw odometry (with small noise) -----
  v_odo = v + 0.01 * sin(5.0 * time);
  omega_odo = omega + 0.005 * sin(7.0 * time);

  // ----- Perturbation active in middle third -----
  dp_active = if (time > T_total / 3.0 and time < 2.0 * T_total / 3.0) then 1.0 else 0.0;

  // ----- Raw ranges to landmarks (perturbed in middle third) -----
  for i in 1:6 loop
    range_raw[i] = sqrt(max((x - (lx[i] + dperturb * dp_active)) ^ 2 + (y - ly[i]) ^ 2, 1e-6)) + 0.02 * sin(i * 5.0 + 3.0 * time);
  end for;

  // ----- Camera / sonar preserved separately (not fused) -----
  for i in 1:6 loop
    camera_data[i] = atan2(ly[i] - y, lx[i] - x) - theta;
  end for;
  for k in 1:2 loop
    sonar_data[k] = sqrt(max((x - ox[k]) ^ 2 + (y - oy[k]) ^ 2, 1e-6));
  end for;

  // ----- Estimator: predicted ranges / innovations -----
  for i in 1:6 loop
    r_pred_i[i] = sqrt(max((x_est - lx[i]) ^ 2 + (y_est - ly[i]) ^ 2, 1e-6));
    ux_i[i] = (x_est - lx[i]) / r_pred_i[i];
    uy_i[i] = (y_est - ly[i]) / r_pred_i[i];
    innov_i[i] = range_raw[i] - r_pred_i[i];
  end for;

  corr_x = K_range * (innov_i[1] * ux_i[1] + innov_i[2] * ux_i[2] + innov_i[3] * ux_i[3] + innov_i[4] * ux_i[4] + innov_i[5] * ux_i[5] + innov_i[6] * ux_i[6]) / 6.0;
  corr_y = K_range * (innov_i[1] * uy_i[1] + innov_i[2] * uy_i[2] + innov_i[3] * uy_i[3] + innov_i[4] * uy_i[4] + innov_i[5] * uy_i[5] + innov_i[6] * uy_i[6]) / 6.0;

  // ----- Estimator: fused odometry + IMU + range, with loop-closure correction -----
  der(x_est) = v_est * cos(theta_est) + corr_x + (if time > 9.0 then K_lc * (1.5 - x_est) else 0.0);
  der(y_est) = v_est * sin(theta_est) + corr_y + (if time > 9.0 then K_lc * (0.0 - y_est) else 0.0);
  der(theta_est) = omega_est + (if time > 9.0 then K_lc_h * (pi_half - theta_est) else 0.0);
  der(v_est) = (v_odo - v_est) / tau_est + (accel_raw - accel_bias_decl);
  der(omega_est) = (omega_odo - omega_est) / tau_est + Kg * ((gyro_raw - gyro_bias_decl) - omega_est);

  // ----- Finite, bounded covariance scalars -----
  der(P_pose) = Q_pose - P_pose / tau_p;
  der(P_theta) = Q_theta - P_theta / tau_p;

  // ----- Loop-closure errors (start pose = (1.5,0,pi/2)) -----
  lc_pos_err = sqrt(max((x_est - 1.5) ^ 2 + (y_est - 0.0) ^ 2, 1e-6));
  lc_head_err = atan2(sin(theta_est - pi_half), cos(theta_est - pi_half));

  // ----- Pose-filtering controller using estimate -----
  ex_w = x_ref - x_est;
  ey_w = y_ref - y_est;
  ex_b = cos(theta_est) * ex_w + sin(theta_est) * ey_w;
  ey_b = -sin(theta_est) * ex_w + cos(theta_est) * ey_w;
  eth = atan2(sin(theta_ref - theta_est), cos(theta_ref - theta_est));
  a_des = Kv * (v_ref - v_est) + Kp * ex_b;
  alpha_des = Ko * (omega_ref - omega_est) + Kh * eth + Ky * ey_b;
  F_des = m * a_des;
  M_des = Iz * alpha_des;
  F_R_des = F_des / 2.0 + M_des / L;
  F_L_des = F_des / 2.0 - M_des / L;
  tau_L_cmd = F_L_des * r;
  tau_R_cmd = F_R_des * r;

  // ----- Tracking error -----
  e_track = sqrt(max((x - x_ref) ^ 2 + (y - y_ref) ^ 2, 1e-6));
  e_track_after = if time > 6.5 then e_track else 0.0;

  // ----- Collision check -----
  d_obs1 = sqrt(max((x - ox[1]) ^ 2 + (y - oy[1]) ^ 2, 1e-6));
  d_obs2 = sqrt(max((x - ox[2]) ^ 2 + (y - oy[2]) ^ 2, 1e-6));
  no_collision = (d_obs1 > orad[1] + robot_radius) and (d_obs2 > orad[2] + robot_radius);

  // ----- Synchronized traces at declared output rate (100 Hz) -----
  when sample(0, dt_out) then
    t_sync = time;
    x_sync = x;
    y_sync = y;
    theta_sync = theta;
    tau_L_sync = tau_L;
    tau_R_sync = tau_R;
    accel_sync = accel_raw;
    gyro_sync = gyro_raw;
    range_sync_1 = range_raw[1];
    range_sync_2 = range_raw[2];
    range_sync_3 = range_raw[3];
    camera_sync_1 = camera_data[1];
    camera_sync_2 = camera_data[2];
    sonar_sync_1 = sonar_data[1];
    sonar_sync_2 = sonar_data[2];
  end when;

  annotation(
    experiment(StopTime = 10.0, Tolerance = 1e-6, Interval = 0.01),
    Documentation(info = "WheelIMUMapB: differential-drive sensing/estimation mission. Parameters not given in the requirement (wheel radius, wheel base, yaw inertia, drivetrain lag, obstacle radii, route radius, gains) are assumed and labeled; only given numeric facts are bound from the requirement.")
  );
end WheelIMUMapB;