model MapRigMapF
  "Robotic mapping: closed-route traversal with multi-rate sensor fusion, loop-closure correction, and verification";

  // ===== Stated Parameters =====
  parameter Real m_base = 22.0 "Mobile base mass [kg]";
  parameter Real lidar_range_max = 20.0 "Planar lidar maximum range [m]";
  parameter Real tau_max = 14.6 "Maximum wheel torque [N.m per wheel]";
  parameter Real perturbation = 0.29 "Landmark perturbation magnitude [m]";
  parameter Real t_sim = 20.0 "Simulation duration [s]";
  parameter Real tracking_threshold = 0.2 "Tracking error threshold after 13 s [m]";
  parameter Real t_track_check = 13.0 "Time after which tracking error is checked [s]";

  // ===== Assumed Physical Parameters =====
  parameter Real r_wheel = 0.1 "Wheel radius [m] (assumed)";
  parameter Real L_wheel = 0.5 "Wheelbase [m] (assumed)";
  parameter Real I_base = 1.5 "Base moment of inertia [kg.m2] (assumed)";
  parameter Real base_r = 0.3 "Base collision radius [m] (assumed)";
  parameter Real R_path = 3.0 "Closed route radius [m] (assumed)";
  parameter Real pi_val = 3.14159265358979 "Pi constant";
  parameter Real v_des = 4.0 * pi_val * R_path / t_sim
    "Desired speed for 2 loops in 20 s [m/s] (assumed)";

  // ===== Control Gains =====
  parameter Real kp_v = 3.0 "Velocity control gain (assumed)";
  parameter Real kp_o = 3.0 "Turn rate control gain (assumed)";
  parameter Real k_pos = 0.5 "Position error gain (assumed)";
  parameter Real k_head = 0.5 "Heading error gain (assumed)";

  // ===== Estimator Gains =====
  parameter Real K_range = 0.15 "Range update gain (assumed)";
  parameter Real K_heading = 0.1 "Heading update gain (assumed)";
  parameter Real K_cov = 0.3 "Covariance reduction per update (assumed)";
  parameter Real Q_pos = 1e-4 "Position process noise [m2/s] (assumed)";
  parameter Real Q_th = 1e-5 "Heading process noise [rad2/s] (assumed)";
  parameter Real P0_pos = 0.01 "Initial position covariance [m2] (assumed)";
  parameter Real P0_th = 0.001 "Initial heading covariance [rad2] (assumed)";
  parameter Real K_lc_pos = 0.4 "Loop closure position correction gain (assumed)";
  parameter Real K_lc_head = 0.3 "Loop closure heading correction gain (assumed)";
  parameter Real K_lc_cov = 0.2 "Loop closure covariance reduction factor (assumed)";
  parameter Real lc_dist_threshold = 1.0 "Loop closure proximity threshold [m] (assumed)";
  parameter Real lc_time_min = 8.0 "Minimum time for loop closure [s] (assumed)";

  // ===== Sensor Sample Periods =====
  parameter Real T_imu = 0.005 "IMU sample period [s]";
  parameter Real T_lidar = 0.1 "Lidar sample period [s]";
  parameter Real T_enc = 0.002 "Encoder sample period [s]";
  parameter Real T_cam = 0.2 "Camera sample period [s]";
  parameter Real T_sonar = 0.05 "Sonar sample period [s]";
  parameter Real f_out = 500.0 "Declared output rate [Hz]";

  // ===== Disturbance Timing =====
  parameter Real t_mid_start = t_sim / 3.0 "Middle third start [s]";
  parameter Real t_mid_end = 2.0 * t_sim / 3.0 "Middle third end [s]";

  // ===== Landmarks (6 fixed) =====
  parameter Real LM_x_1 = 5.0 "Landmark 1 x [m]";
  parameter Real LM_y_1 = 3.0 "Landmark 1 y [m]";
  parameter Real LM_x_2 = -3.0 "Landmark 2 x [m]";
  parameter Real LM_y_2 = 4.0 "Landmark 2 y [m]";
  parameter Real LM_x_3 = 4.0 "Landmark 3 x [m]";
  parameter Real LM_y_3 = -3.0 "Landmark 3 y [m]";
  parameter Real LM_x_4 = -4.0 "Landmark 4 x [m]";
  parameter Real LM_y_4 = -4.0 "Landmark 4 y [m]";
  parameter Real LM_x_5 = 3.0 "Landmark 5 x [m]";
  parameter Real LM_y_5 = 5.0 "Landmark 5 y [m]";
  parameter Real LM_x_6 = -5.0 "Landmark 6 x [m]";
  parameter Real LM_y_6 = -5.0 "Landmark 6 y [m]";

  // ===== Obstacles (2 fixed) =====
  parameter Real OBS_x_1 = 2.0 "Obstacle 1 x [m]";
  parameter Real OBS_y_1 = 1.0 "Obstacle 1 y [m]";
  parameter Real OBS_r_1 = 0.5 "Obstacle 1 radius [m]";
  parameter Real OBS_x_2 = -2.0 "Obstacle 2 x [m]";
  parameter Real OBS_y_2 = -1.0 "Obstacle 2 y [m]";
  parameter Real OBS_r_2 = 0.5 "Obstacle 2 radius [m]";

  // ===== True States =====
  Real x(start = R_path, fixed = true) "True x position [m]";
  Real y(start = 0.0, fixed = true) "True y position [m]";
  Real theta(start = pi_val / 2.0, fixed = true) "True heading [rad]";
  Real v(start = 0.0, fixed = true) "True forward velocity [m/s]";
  Real omega(start = 0.0, fixed = true) "True angular velocity [rad/s]";
  Real tau_L "Left wheel torque [N.m]";
  Real tau_R "Right wheel torque [N.m]";

  // ===== Controller Variables =====
  Real x_des "Desired x [m]";
  Real y_des "Desired y [m]";
  Real theta_des "Desired heading [rad]";
  Real v_cmd "Velocity command [m/s]";
  Real omega_cmd "Turn rate command [rad/s]";
  Real a_des "Desired forward acceleration [m/s2]";
  Real alpha_des "Desired angular acceleration [rad/s2]";
  Real tau_L_des "Desired left torque [N.m]";
  Real tau_R_des "Desired right torque [N.m]";
  Real tracking_error "Primary tracking error [m]";
  Real des_pos_err "Desired position error magnitude [m]";

  // ===== Discrete Sensor Variables =====
  discrete Real imu_omega(start = 0.0, fixed = true) "Sampled IMU angular rate [rad/s]";
  discrete Real imu_ax(start = 0.0, fixed = true) "Sampled IMU forward acceleration [m/s2]";
  discrete Real enc_v(start = 0.0, fixed = true) "Sampled encoder velocity [m/s]";
  discrete Real enc_omega(start = 0.0, fixed = true) "Sampled encoder angular rate [rad/s]";
  discrete Real lidar_log_1(start = 0.0, fixed = true) "Lidar range to LM1 [m] (retained)";
  discrete Real lidar_log_2(start = 0.0, fixed = true) "Lidar range to LM2 [m] (retained)";
  discrete Real lidar_log_3(start = 0.0, fixed = true) "Lidar range to LM3 [m] (retained)";
  discrete Real lidar_log_4(start = 0.0, fixed = true) "Lidar range to LM4 [m] (retained)";
  discrete Real lidar_log_5(start = 0.0, fixed = true) "Lidar range to LM5 [m] (retained)";
  discrete Real lidar_log_6(start = 0.0, fixed = true) "Lidar range to LM6 [m] (retained)";
  discrete Real cam_raw_depth(start = 0.0, fixed = true) "Camera raw depth [m] (retained)";
  discrete Real sonar_raw(start = 0.0, fixed = true) "Sonar raw range [m] (retained)";

  // ===== Estimator States =====
  Real x_est(start = R_path, fixed = true) "Estimated x position [m]";
  Real y_est(start = 0.0, fixed = true) "Estimated y position [m]";
  Real theta_est(start = pi_val / 2.0, fixed = true) "Estimated heading [rad]";
  Real Pxx(start = P0_pos, fixed = true) "Covariance P_xx [m2]";
  Real Pyy(start = P0_pos, fixed = true) "Covariance P_yy [m2]";
  Real Ptt(start = P0_th, fixed = true) "Covariance P_theta_theta [rad2]";
  Real Pxy(start = 0.0, fixed = true) "Covariance P_xy [m2]";
  Real Pxt(start = 0.0, fixed = true) "Covariance P_x_theta [m*rad]";
  Real Pyt(start = 0.0, fixed = true) "Covariance P_y_theta [m*rad]";

  // ===== Loop Closure =====
  Boolean loop_closure_flag(start = false, fixed = true) "Loop closure triggered";
  Real lc_pos_error "Loop closure position error [m]";
  Real lc_head_error "Loop closure heading error [rad]";

  // ===== Helper Variables =====
  Real perturb_active "Perturbation active (1.0 or 0.0)";
  Real LM_xo_1 "Observed LM1 x [m]";
  Real LM_yo_1 "Observed LM1 y [m]";
  Real LM_xo_2 "Observed LM2 x [m]";
  Real LM_yo_2 "Observed LM2 y [m]";
  Real LM_xo_3 "Observed LM3 x [m]";
  Real LM_yo_3 "Observed LM3 y [m]";
  Real LM_xo_4 "Observed LM4 x [m]";
  Real LM_yo_4 "Observed LM4 y [m]";
  Real LM_xo_5 "Observed LM5 x [m]";
  Real LM_yo_5 "Observed LM5 y [m]";
  Real LM_xo_6 "Observed LM6 x [m]";
  Real LM_yo_6 "Observed LM6 y [m]";
  Real range_true_1 "True range to LM1 [m]";
  Real range_true_2 "True range to LM2 [m]";
  Real range_true_3 "True range to LM3 [m]";
  Real range_true_4 "True range to LM4 [m]";
  Real range_true_5 "True range to LM5 [m]";
  Real range_true_6 "True range to LM6 [m]";
  Real range_est_1 "Estimated range to LM1 [m]";
  Real range_est_2 "Estimated range to LM2 [m]";
  Real range_est_3 "Estimated range to LM3 [m]";
  Real range_est_4 "Estimated range to LM4 [m]";
  Real range_est_5 "Estimated range to LM5 [m]";
  Real range_est_6 "Estimated range to LM6 [m]";
  Real innov_1 "Range innovation LM1 [m]";
  Real innov_2 "Range innovation LM2 [m]";
  Real innov_3 "Range innovation LM3 [m]";
  Real innov_4 "Range innovation LM4 [m]";
  Real innov_5 "Range innovation LM5 [m]";
  Real innov_6 "Range innovation LM6 [m]";
  Real corr_x "Combined x correction [m]";
  Real corr_y "Combined y correction [m]";
  Real dist_to_start_est "Estimated distance to start [m]";
  Real bearing_lm1_est "Bearing to LM1 from estimate [rad]";

  // ===== Verification Variables =====
  Real det_P "Covariance determinant";
  Real obs_dist_1 "Clearance to obstacle 1 [m]";
  Real obs_dist_2 "Clearance to obstacle 2 [m]";
  Real min_obs_dist "Minimum obstacle clearance [m]";
  Boolean no_collision "No collision flag";
  Boolean finite_covariance "Finite covariance flag";
  Boolean tracking_ok "Tracking error below threshold after 13 s";
  Boolean no_nan_inf "No NaN or infinite values flag";
  Real output_rate_actual "Declared output rate [Hz]";

equation
  // ===== Landmark Perturbation =====
  perturb_active = if (time >= t_mid_start) and (time <= t_mid_end) then 1.0 else 0.0;
  LM_xo_1 = LM_x_1 + perturb_active * perturbation * cos(1.0);
  LM_yo_1 = LM_y_1 + perturb_active * perturbation * sin(1.0);
  LM_xo_2 = LM_x_2 + perturb_active * perturbation * cos(2.0);
  LM_yo_2 = LM_y_2 + perturb_active * perturbation * sin(2.0);
  LM_xo_3 = LM_x_3 + perturb_active * perturbation * cos(3.0);
  LM_yo_3 = LM_y_3 + perturb_active * perturbation * sin(3.0);
  LM_xo_4 = LM_x_4 + perturb_active * perturbation * cos(4.0);
  LM_yo_4 = LM_y_4 + perturb_active * perturbation * sin(4.0);
  LM_xo_5 = LM_x_5 + perturb_active * perturbation * cos(5.0);
  LM_yo_5 = LM_y_5 + perturb_active * perturbation * sin(5.0);
  LM_xo_6 = LM_x_6 + perturb_active * perturbation * cos(6.0);
  LM_yo_6 = LM_y_6 + perturb_active * perturbation * sin(6.0);

  // ===== True Plant Dynamics =====
  der(x) = v * cos(theta);
  der(y) = v * sin(theta);
  der(theta) = omega;
  der(v) = (tau_L + tau_R) / (m_base * r_wheel);
  der(omega) = (tau_R - tau_L) * r_wheel / (I_base * L_wheel);

  // ===== Controller: Closed Circular Route =====
  x_des = R_path * cos(v_des * time / R_path);
  y_des = R_path * sin(v_des * time / R_path);
  theta_des = v_des * time / R_path + pi_val / 2.0;

  des_pos_err = sqrt(max({(x_des - x_est) * (x_des - x_est) + (y_des - y_est) * (y_des - y_est), 1e-12}));
  v_cmd = v_des + k_pos * des_pos_err;
  omega_cmd = v_des / R_path + k_head * sin(theta_des - theta_est);

  a_des = kp_v * (v_cmd - v);
  alpha_des = kp_o * (omega_cmd - omega);

  tau_L_des = 0.5 * (m_base * r_wheel * a_des - I_base * L_wheel / r_wheel * alpha_des);
  tau_R_des = 0.5 * (m_base * r_wheel * a_des + I_base * L_wheel / r_wheel * alpha_des);
  tau_L = if tau_L_des > tau_max then tau_max elseif tau_L_des < (-tau_max) then (-tau_max) else tau_L_des;
  tau_R = if tau_R_des > tau_max then tau_max elseif tau_R_des < (-tau_max) then (-tau_max) else tau_R_des;

  tracking_error = sqrt(max({(x - x_des) * (x - x_des) + (y - y_des) * (y - y_des), 1e-12}));

  // ===== True Ranges to Perturbed Landmarks =====
  range_true_1 = sqrt(max({(LM_xo_1 - x) * (LM_xo_1 - x) + (LM_yo_1 - y) * (LM_yo_1 - y), 1e-12}));
  range_true_2 = sqrt(max({(LM_xo_2 - x) * (LM_xo_2 - x) + (LM_yo_2 - y) * (LM_yo_2 - y), 1e-12}));
  range_true_3 = sqrt(max({(LM_xo_3 - x) * (LM_xo_3 - x) + (LM_yo_3 - y) * (LM_yo_3 - y), 1e-12}));
  range_true_4 = sqrt(max({(LM_xo_4 - x) * (LM_xo_4 - x) + (LM_yo_4 - y) * (LM_yo_4 - y), 1e-12}));
  range_true_5 = sqrt(max({(LM_xo_5 - x) * (LM_xo_5 - x) + (LM_yo_5 - y) * (LM_yo_5 - y), 1e-12}));
  range_true_6 = sqrt(max({(LM_xo_6 - x) * (LM_xo_6 - x) + (LM_yo_6 - y) * (LM_yo_6 - y), 1e-12}));

  // ===== Expected Ranges from Estimate to True Landmarks =====
  range_est_1 = sqrt(max({(LM_x_1 - x_est) * (LM_x_1 - x_est) + (LM_y_1 - y_est) * (LM_y_1 - y_est), 1e-12}));
  range_est_2 = sqrt(max({(LM_x_2 - x_est) * (LM_x_2 - x_est) + (LM_y_2 - y_est) * (LM_y_2 - y_est), 1e-12}));
  range_est_3 = sqrt(max({(LM_x_3 - x_est) * (LM_x_3 - x_est) + (LM_y_3 - y_est) * (LM_y_3 - y_est), 1e-12}));
  range_est_4 = sqrt(max({(LM_x_4 - x_est) * (LM_x_4 - x_est) + (LM_y_4 - y_est) * (LM_y_4 - y_est), 1e-12}));
  range_est_5 = sqrt(max({(LM_x_5 - x_est) * (LM_x_5 - x_est) + (LM_y_5 - y_est) * (LM_y_5 - y_est), 1e-12}));
  range_est_6 = sqrt(max({(LM_x_6 - x_est) * (LM_x_6 - x_est) + (LM_y_6 - y_est) * (LM_y_6 - y_est), 1e-12}));

  // ===== Range Innovations =====
  innov_1 = range_true_1 - range_est_1;
  innov_2 = range_true_2 - range_est_2;
  innov_3 = range_true_3 - range_est_3;
  innov_4 = range_true_4 - range_est_4;
  innov_5 = range_true_5 - range_est_5;
  innov_6 = range_true_6 - range_est_6;

  // ===== Combined Corrections =====
  corr_x = ((LM_x_1 - x_est) / range_est_1 * innov_1 +
            (LM_x_2 - x_est) / range_est_2 * innov_2 +
            (LM_x_3 - x_est) / range_est_3 * innov_3 +
            (LM_x_4 - x_est) / range_est_4 * innov_4 +
            (LM_x_5 - x_est) / range_est_5 * innov_5 +
            (LM_x_6 - x_est) / range_est_6 * innov_6) / 6.0;

  corr_y = ((LM_y_1 - y_est) / range_est_1 * innov_1 +
            (LM_y_2 - y_est) / range_est_2 * innov_2 +
            (LM_y_3 - y_est) / range_est_3 * innov_3 +
            (LM_y_4 - y_est) / range_est_4 * innov_4 +
            (LM_y_5 - y_est) / range_est_5 * innov_5 +
            (LM_y_6 - y_est) / range_est_6 * innov_6) / 6.0;

  // ===== Bearing to LM1 from Estimate =====
  bearing_lm1_est = atan2(LM_y_1 - y_est, LM_x_1 - x_est);

  // ===== Estimator Prediction =====
  der(x_est) = enc_v * cos(theta_est);
  der(y_est) = enc_v * sin(theta_est);
  der(theta_est) = imu_omega;

  // ===== Covariance Prediction =====
  der(Pxx) = Q_pos;
  der(Pyy) = Q_pos;
  der(Ptt) = Q_th;
  der(Pxy) = 0.0;
  der(Pxt) = 0.0;
  der(Pyt) = 0.0;

  // ===== Distance to Start =====
  dist_to_start_est = sqrt(max({(x_est - R_path) * (x_est - R_path) + y_est * y_est, 1e-12}));

  // ===== Loop Closure Error Metrics =====
  lc_pos_error = sqrt(max({(x_est - x) * (x_est - x) + (y_est - y) * (y_est - y), 1e-12}));
  lc_head_error = abs(theta_est - theta);

  // ===== Verification Signals =====
  det_P = Pxx * Pyy * Ptt + 2.0 * Pxy * Pxt * Pyt
          - Pxx * Pyt * Pyt - Pyy * Pxt * Pxt - Ptt * Pxy * Pxy;

  obs_dist_1 = sqrt(max({(x - OBS_x_1) * (x - OBS_x_1) + (y - OBS_y_1) * (y - OBS_y_1), 1e-12})) - base_r - OBS_r_1;
  obs_dist_2 = sqrt(max({(x - OBS_x_2) * (x - OBS_x_2) + (y - OBS_y_2) * (y - OBS_y_2), 1e-12})) - base_r - OBS_r_2;
  min_obs_dist = if obs_dist_1 < obs_dist_2 then obs_dist_1 else obs_dist_2;
  no_collision = min_obs_dist > 0.0;

  finite_covariance = (Pxx > 0.0) and (Pyy > 0.0) and (Ptt > 0.0) and
                      (Pxx < 100.0) and (Pyy < 100.0) and (Ptt < 100.0) and
                      (det_P > 0.0) and (det_P < 1.0e6);

  tracking_ok = if time > t_track_check then tracking_error < tracking_threshold else true;

  no_nan_inf = (abs(x) < 1e6) and (abs(y) < 1e6) and (abs(theta) < 1e6) and
               (abs(v) < 1e6) and (abs(omega) < 1e6) and
               (abs(x_est) < 1e6) and (abs(y_est) < 1e6) and (abs(theta_est) < 1e6) and
               (Pxx < 1e6) and (Pyy < 1e6) and (Ptt < 1e6) and
               (abs(tau_L) < 1e6) and (abs(tau_R) < 1e6);

  output_rate_actual = f_out;

  // ===== IMU Sampling at 200 Hz =====
  when sample(0, T_imu) then
    imu_omega = omega + 0.001;
    imu_ax = (tau_L + tau_R) / (m_base * r_wheel) + 0.01;
  end when;

  // ===== Wheel Encoder Sampling at 500 Hz =====
  when sample(0, T_enc) then
    enc_v = v + 0.005;
    enc_omega = omega + 0.002;
  end when;

  // ===== Lidar Sampling + Estimator Correction + Loop Closure at 10 Hz =====
  when sample(0, T_lidar) then
    // Retain raw lidar observations
    lidar_log_1 = range_true_1;
    lidar_log_2 = range_true_2;
    lidar_log_3 = range_true_3;
    lidar_log_4 = range_true_4;
    lidar_log_5 = range_true_5;
    lidar_log_6 = range_true_6;

    // EKF range update with optional loop-closure correction
    if (dist_to_start_est < lc_dist_threshold) and (time > lc_time_min) then
      // Loop closure: correct toward known start pose and reduce covariance
      loop_closure_flag = true;
      reinit(x_est, x_est + K_range * corr_x + K_lc_pos * (R_path - x_est));
      reinit(y_est, y_est + K_range * corr_y + K_lc_pos * (0.0 - y_est));
      reinit(theta_est, theta_est + K_heading * sin(bearing_lm1_est - theta_est) +
             K_lc_head * sin(v_des * time / R_path + pi_val / 2.0 - theta_est));
      reinit(Pxx, Pxx * (1.0 - K_cov) * K_lc_cov);
      reinit(Pyy, Pyy * (1.0 - K_cov) * K_lc_cov);
      reinit(Ptt, Ptt * (1.0 - K_cov) * K_lc_cov);
      reinit(Pxy, Pxy * (1.0 - K_cov) * K_lc_cov);
      reinit(Pxt, Pxt * (1.0 - K_cov) * K_lc_cov);
      reinit(Pyt, Pyt * (1.0 - K_cov) * K_lc_cov);
    else
      // Normal EKF range update only
      loop_closure_flag = false;
      reinit(x_est, x_est + K_range * corr_x);
      reinit(y_est, y_est + K_range * corr_y);
      reinit(theta_est, theta_est + K_heading * sin(bearing_lm1_est - theta_est));
      reinit(Pxx, Pxx * (1.0 - K_cov));
      reinit(Pyy, Pyy * (1.0 - K_cov));
      reinit(Ptt, Ptt * (1.0 - K_cov));
      reinit(Pxy, Pxy * (1.0 - K_cov));
      reinit(Pxt, Pxt * (1.0 - K_cov));
      reinit(Pyt, Pyt * (1.0 - K_cov));
    end if;
  end when;

  // ===== Camera at 5 Hz (raw, retained separately, NOT fused) =====
  when sample(0, T_cam) then
    cam_raw_depth = sqrt(max({(OBS_x_1 - x) * (OBS_x_1 - x) + (OBS_y_1 - y) * (OBS_y_1 - y), 1e-12}));
  end when;

  // ===== Sonar at 20 Hz (raw, retained separately, NOT fused) =====
  when sample(0, T_sonar) then
    sonar_raw = sqrt(max({(OBS_x_2 - x) * (OBS_x_2 - x) + (OBS_y_2 - y) * (OBS_y_2 - y), 1e-12}));
  end when;

  annotation(
    experiment(StartTime = 0, StopTime = 20.0, Tolerance = 1e-6, Interval = 0.002),
    Documentation(info = "MapRigMapF: Robotic mapping scenario. Closed-route traversal with multi-rate sensor fusion (500/200/10/5/20 Hz), loop-closure correction, 0.29 m landmark perturbation during middle third, 6 landmarks, 2 obstacles, 20 m lidar, bounded 14.6 N.m wheel torque, 22 kg base. Verification: finite covariance, loop-closure errors, 500 Hz output, no collision, tracking < 0.2 m after 13 s, no NaN/inf."));
end MapRigMapF;