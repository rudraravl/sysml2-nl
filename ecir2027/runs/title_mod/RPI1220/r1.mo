model WheelIMUMapB
  // ===== Physical Parameters =====
  parameter Real m_chassis = 16.0 "Chassis mass [kg]";
  parameter Real R_wheel = 0.1 "Wheel radius [m]";
  parameter Real L_half = 0.3 "Half wheelbase [m]";
  parameter Real J_wheel = 0.04 "Wheel inertia [kg.m2]";
  parameter Real b_wheel = 0.3 "Wheel viscous friction [N.m.s/rad]";
  parameter Real tau_max = 8.2 "Max wheel torque per wheel [N.m]";
  parameter Real robot_r = 0.2 "Robot body radius [m]";

  // ===== Mission Parameters =====
  parameter Real T_mission = 10.0 "Mission duration [s]";
  parameter Real f_sample = 100.0 "Declared output rate [Hz]";
  parameter Real dt_sample = 0.01 "Sample interval [s]";

  // ===== IMU Noise and Bias Parameters =====
  parameter Real gyro_bias_decl = 0.002 "Declared gyro bias [rad/s]";
  parameter Real gyro_noise_std = 0.001 "Gyro noise std [rad/s]";
  parameter Real accel_bias_decl = 0.05 "Declared accel bias [m/s2]";
  parameter Real accel_noise_std = 0.02 "Accel noise std [m/s2]";
  parameter Real enc_noise_std = 0.005 "Encoder noise std [rad]";
  parameter Real range_noise_std = 0.05 "Range noise std [m]";

  // ===== Landmarks (6 fixed in world frame) =====
  parameter Real LM_x[6] = {0.5, 5.0, 5.5, 5.0, 0.5, -0.5};
  parameter Real LM_y[6] = {0.5, 0.5, 2.5, 4.5, 4.5, 2.5};

  // ===== Obstacles (2 in world frame) =====
  parameter Real OBS_x[2] = {2.0, 3.0};
  parameter Real OBS_y[2] = {1.5, 3.5};
  parameter Real OBS_r[2] = {0.3, 0.3};

  // ===== Perturbation (middle third) =====
  parameter Real pert_mag = 0.14 "Landmark perturbation disturbance [m]";
  parameter Real t_pert_start = 3.333333333 "Perturbation start [s]";
  parameter Real t_pert_end = 6.666666667 "Perturbation end [s]";

  // ===== Controller Gains =====
  parameter Real kp_v = 8.0 "Velocity tracking gain";
  parameter Real kp_omega = 4.0 "Angular velocity tracking gain";
  parameter Real kp_w = 10.0 "Wheel velocity loop gain";

  // ===== Estimator Parameters =====
  parameter Real range_gain = 0.5 "Range update gain";
  parameter Real Q_pos = 0.001 "Position process noise rate [m2/s]";
  parameter Real Q_theta = 0.0001 "Heading process noise rate [rad2/s]";
  parameter Real gyro_gain = 0.5 "Gyro covariance update gain";

  // ===== Path (closed circular route) =====
  parameter Real path_cx = 2.5 "Path center x [m]";
  parameter Real path_cy = 2.5 "Path center y [m]";
  parameter Real path_r = 2.5 "Path radius [m]";
  parameter Real path_omega = 0.6283185307 "Path angular frequency [rad/s]";

  // ===== Plant States =====
  Real x(start = 5.0, fixed = true) "True x position [m]";
  Real y(start = 2.5, fixed = true) "True y position [m]";
  Real theta(start = 1.5707963268, fixed = true) "True heading [rad]";
  Real w_R(start = 0.0, fixed = true) "Right wheel angular velocity [rad/s]";
  Real w_L(start = 0.0, fixed = true) "Left wheel angular velocity [rad/s]";

  // ===== Torques =====
  Real tau_R_cmd "Right torque command [N.m]";
  Real tau_L_cmd "Left torque command [N.m]";
  Real tau_R "Right actual torque [N.m]";
  Real tau_L "Left actual torque [N.m]";

  // ===== Derived Kinematics =====
  Real v "True linear velocity [m/s]";
  Real omega "True angular velocity [rad/s]";
  Real a_x_body "Body frame x acceleration [m/s2]";
  Real a_y_body "Body frame y acceleration [m/s2]";

  // ===== Reference =====
  Real x_ref "Reference x [m]";
  Real y_ref "Reference y [m]";
  Real theta_ref "Reference heading [rad]";
  Real v_ref "Reference velocity [m/s]";
  Real omega_ref "Reference angular velocity [rad/s]";
  Real dx_ref "Reference x velocity [m/s]";
  Real dy_ref "Reference y velocity [m/s]";

  // ===== Tracking Errors =====
  Real err_x "Estimated tracking error x [m]";
  Real err_y "Estimated tracking error y [m]";
  Real err_pos "Estimated tracking position error [m]";
  Real err_theta_raw "Raw heading error [rad]";
  Real err_theta "Wrapped heading error [rad]";
  Real true_err_pos "True tracking position error [m]";

  // ===== Controller =====
  Real v_cmd "Commanded velocity [m/s]";
  Real omega_cmd "Commanded angular velocity [rad/s]";
  Real w_R_des "Desired right wheel velocity [rad/s]";
  Real w_L_des "Desired left wheel velocity [rad/s]";

  // ===== IMU Measurements =====
  Real imu_gyro "Gyroscope measurement [rad/s]";
  Real imu_ax "Accelerometer x measurement [m/s2]";
  Real imu_ay "Accelerometer y measurement [m/s2]";

  // ===== Wheel Encoder Measurements =====
  Real enc_R(start = 0.0, fixed = true) "Right wheel encoder accumulated [rad]";
  Real enc_L(start = 0.0, fixed = true) "Left wheel encoder accumulated [rad]";
  Real enc_R_vel "Right wheel encoder velocity [rad/s]";
  Real enc_L_vel "Left wheel encoder velocity [rad/s]";

  // ===== Odometry =====
  Real odo_v "Odometry velocity [m/s]";
  Real odo_omega "Odometry angular velocity [rad/s]";

  // ===== Range Measurements =====
  Real range_meas[6] "Range to each landmark [m]";
  Real range_true[6] "True range to each landmark [m]";

  // ===== Camera/Sonar Raw Data (preserved separately, not fused) =====
  Real camera_bearing[6] "Raw camera bearing to landmarks [rad]";
  Real sonar_range[2] "Raw sonar range to obstacles [m]";

  // ===== Estimator States =====
  Real x_est(start = 5.0, fixed = true) "Estimated x [m]";
  Real y_est(start = 2.5, fixed = true) "Estimated y [m]";
  Real theta_est(start = 1.5707963268, fixed = true) "Estimated heading [rad]";
  Real v_est "Estimated velocity [m/s]";
  Real omega_est "Estimated angular velocity [rad/s]";

  // ===== Estimator Covariance (3x3, finite) =====
  Real P11(start = 0.01, fixed = true) "Covariance P11 [m2]";
  Real P22(start = 0.01, fixed = true) "Covariance P22 [m2]";
  Real P33(start = 0.01, fixed = true) "Covariance P33 [rad2]";
  Real P12(start = 0.0, fixed = true) "Covariance P12 [m2]";
  Real P13(start = 0.0, fixed = true) "Covariance P13 [m.rad]";
  Real P23(start = 0.0, fixed = true) "Covariance P23 [m.rad]";
  Real det_P "Covariance determinant";
  Real trace_P "Covariance trace";

  // ===== Range-Based Correction =====
  Real range_est[6] "Estimated range to each landmark [m]";
  Real range_innov[6] "Range innovation [m]";
  Real corr_x "Range correction rate x [m/s]";
  Real corr_y "Range correction rate y [m/s]";

  // ===== Loop Closure =====
  Real loop_closure_pos_err "Loop closure position error [m]";
  Real loop_closure_head_err "Loop closure heading error [rad]";
  Real lc_blend "Loop closure blend factor";
  Real x_est_final "Final estimated x [m]";
  Real y_est_final "Final estimated y [m]";
  Real theta_est_final "Final estimated heading [rad]";

  // ===== Perturbed Landmark Positions =====
  Real LM_x_eff[6] "Effective landmark x with perturbation [m]";
  Real LM_y_eff[6] "Effective landmark y with perturbation [m]";
  Real pert_step "Perturbation step function";

  // ===== Collision =====
  Real dist_obs[2] "Distance to each obstacle center [m]";
  Real min_obs_clear "Minimum obstacle clearance [m]";
  Boolean collision "Collision flag";

  // ===== Output Sampling (100 Hz) =====
  Integer output_count(start = 0) "Output sample counter";
  Real sampled_x "Sampled true x [m]";
  Real sampled_y "Sampled true y [m]";
  Real sampled_x_est "Sampled estimated x [m]";
  Real sampled_y_est "Sampled estimated y [m]";

  // ===== Noise Signals (deterministic pseudo-random) =====
  Real noise1, noise2, noise3, noise4, noise5;
  Real gyro_n "Gyro noise value [rad/s]";
  Real ax_n "Accel x noise [m/s2]";
  Real ay_n "Accel y noise [m/s2]";
  Real encR_n "Encoder R noise [rad/s]";
  Real encL_n "Encoder L noise [rad/s]";
  Real range_n "Range noise [m]";

equation
  // ===== Noise Generation =====
  noise1 = sin(13.7 * time) + 0.7 * sin(27.1 * time + 1.1) + 0.5 * sin(53.3 * time + 2.3);
  noise2 = sin(17.3 * time + 0.3) + 0.6 * sin(31.7 * time + 1.7) + 0.4 * sin(61.1 * time + 3.1);
  noise3 = sin(11.1 * time + 0.7) + 0.8 * sin(23.9 * time + 2.1) + 0.3 * sin(47.3 * time + 4.5);
  noise4 = sin(19.7 * time + 1.3) + 0.5 * sin(37.3 * time + 2.9) + 0.6 * sin(71.7 * time + 0.7);
  noise5 = sin(15.1 * time + 2.3) + 0.4 * sin(29.7 * time + 3.7) + 0.7 * sin(57.9 * time + 1.9);

  gyro_n = gyro_noise_std * noise1 / 1.323;
  ax_n = accel_noise_std * noise2 / 1.323;
  ay_n = accel_noise_std * noise3 / 1.323;
  encR_n = enc_noise_std * noise4 / 1.323;
  encL_n = enc_noise_std * noise5 / 1.323;
  range_n = range_noise_std * (noise1 + noise2) / 1.87;

  // ===== Reference Path (closed circular route) =====
  x_ref = path_cx + path_r * cos(path_omega * time);
  y_ref = path_cy + path_r * sin(path_omega * time);
  dx_ref = -path_r * path_omega * sin(path_omega * time);
  dy_ref = path_r * path_omega * cos(path_omega * time);
  theta_ref = atan2(dy_ref, dx_ref);
  v_ref = path_r * path_omega;
  omega_ref = path_omega;

  // ===== Plant Dynamics =====
  J_wheel * der(w_R) = tau_R - b_wheel * w_R;
  J_wheel * der(w_L) = tau_L - b_wheel * w_L;
  v = R_wheel * (w_R + w_L) / 2.0;
  omega = R_wheel * (w_R - w_L) / (2.0 * L_half);
  der(x) = v * cos(theta);
  der(y) = v * sin(theta);
  der(theta) = omega;

  // Body frame accelerations for IMU simulation
  a_x_body = R_wheel * ((tau_R - b_wheel * w_R) + (tau_L - b_wheel * w_L)) / (2.0 * J_wheel);
  a_y_body = v * omega;

  // ===== Torque Saturation =====
  tau_R = if tau_R_cmd > tau_max then tau_max elseif tau_R_cmd < -tau_max then -tau_max else tau_R_cmd;
  tau_L = if tau_L_cmd > tau_max then tau_max elseif tau_L_cmd < -tau_max then -tau_max else tau_L_cmd;

  // ===== Controller (pose filtering with path following) =====
  err_x = x_ref - x_est_final;
  err_y = y_ref - y_est_final;
  err_pos = sqrt(err_x * err_x + err_y * err_y + 1e-10);
  err_theta_raw = theta_ref - theta_est_final;
  err_theta = if err_theta_raw > 3.14159265358979 then err_theta_raw - 6.28318530717959
    elseif err_theta_raw < -3.14159265358979 then err_theta_raw + 6.28318530717959
    else err_theta_raw;

  v_cmd = v_ref + kp_v * err_pos * cos(err_theta);
  omega_cmd = omega_ref + kp_omega * err_theta;
  w_R_des = (v_cmd + omega_cmd * L_half) / R_wheel;
  w_L_des = (v_cmd - omega_cmd * L_half) / R_wheel;
  tau_R_cmd = J_wheel * kp_w * (w_R_des - w_R) + b_wheel * w_R_des;
  tau_L_cmd = J_wheel * kp_w * (w_L_des - w_L) + b_wheel * w_L_des;

  // True tracking error (performance metric)
  true_err_pos = sqrt((x_ref - x) * (x_ref - x) + (y_ref - y) * (y_ref - y) + 1e-10);

  // ===== IMU Measurements =====
  imu_gyro = omega + gyro_bias_decl + gyro_n;
  imu_ax = a_x_body * cos(theta) - a_y_body * sin(theta) + accel_bias_decl + ax_n;
  imu_ay = a_x_body * sin(theta) + a_y_body * cos(theta) + accel_bias_decl + ay_n;

  // ===== Wheel Encoder Measurements =====
  enc_R_vel = w_R + encR_n;
  enc_L_vel = w_L + encL_n;
  der(enc_R) = enc_R_vel;
  der(enc_L) = enc_L_vel;

  // ===== Odometry (fused with IMU in estimator) =====
  odo_v = R_wheel * (enc_R_vel + enc_L_vel) / 2.0;
  odo_omega = R_wheel * (enc_R_vel - enc_L_vel) / (2.0 * L_half);

  // ===== Perturbation Step Function (smooth bump during middle third) =====
  pert_step = 1.0 / (1.0 + exp(-20.0 * (time - t_pert_start)))
           - 1.0 / (1.0 + exp(-20.0 * (time - t_pert_end)));

  // Perturbed landmark positions (actual landmarks shift, estimator map does not)
  for i in 1:6 loop
    LM_x_eff[i] = LM_x[i] + pert_mag * pert_step * cos(i * 1.0472);
    LM_y_eff[i] = LM_y[i] + pert_mag * pert_step * sin(i * 1.0472);
  end for;

  // ===== Range Measurements (from perturbed landmarks) =====
  for i in 1:6 loop
    range_true[i] = sqrt((x - LM_x_eff[i]) * (x - LM_x_eff[i])
                       + (y - LM_y_eff[i]) * (y - LM_y_eff[i]) + 1e-10);
    range_meas[i] = range_true[i] + range_n;
  end for;

  // ===== Camera/Sonar Raw Data (preserved separately, NOT fused) =====
  for i in 1:6 loop
    camera_bearing[i] = atan2(LM_y_eff[i] - y, LM_x_eff[i] - x) - theta;
  end for;

  for i in 1:2 loop
    sonar_range[i] = sqrt((OBS_x[i] - x) * (OBS_x[i] - x)
                        + (OBS_y[i] - y) * (OBS_y[i] - y) + 1e-10);
  end for;

  // ===== Estimator: Fuse Odometry, IMU, and Range =====
  v_est = odo_v;
  omega_est = imu_gyro - gyro_bias_decl;

  // Estimated ranges (using nominal landmark map)
  for i in 1:6 loop
    range_est[i] = sqrt((x_est - LM_x[i]) * (x_est - LM_x[i])
                      + (y_est - LM_y[i]) * (y_est - LM_y[i]) + 1e-10);
    range_innov[i] = range_meas[i] - range_est[i];
  end for;

  // Range-based correction (continuous EKF-like update, scalar explicit)
  corr_x = range_gain * (
    range_innov[1] * (x_est - LM_x[1]) / (range_est[1] + 0.5) +
    range_innov[2] * (x_est - LM_x[2]) / (range_est[2] + 0.5) +
    range_innov[3] * (x_est - LM_x[3]) / (range_est[3] + 0.5) +
    range_innov[4] * (x_est - LM_x[4]) / (range_est[4] + 0.5) +
    range_innov[5] * (x_est - LM_x[5]) / (range_est[5] + 0.5) +
    range_innov[6] * (x_est - LM_x[6]) / (range_est[6] + 0.5)) / 6.0;

  corr_y = range_gain * (
    range_innov[1] * (y_est - LM_y[1]) / (range_est[1] + 0.5) +
    range_innov[2] * (y_est - LM_y[2]) / (range_est[2] + 0.5) +
    range_innov[3] * (y_est - LM_y[3]) / (range_est[3] + 0.5) +
    range_innov[4] * (y_est - LM_y[4]) / (range_est[4] + 0.5) +
    range_innov[5] * (y_est - LM_y[5]) / (range_est[5] + 0.5) +
    range_innov[6] * (y_est - LM_y[6]) / (range_est[6] + 0.5)) / 6.0;

  // Estimator prediction with range correction
  der(x_est) = v_est * cos(theta_est) + corr_x;
  der(y_est) = v_est * sin(theta_est) + corr_y;
  der(theta_est) = omega_est;

  // ===== Covariance Propagation (finite, stable) =====
  der(P11) = Q_pos - 2.0 * range_gain * P11;
  der(P22) = Q_pos - 2.0 * range_gain * P22;
  der(P33) = Q_theta - 2.0 * gyro_gain * P33;
  der(P12) = -2.0 * range_gain * P12;
  der(P13) = -range_gain * P13;
  der(P23) = -range_gain * P23;
  det_P = P11 * P22 * P33 - P33 * P12 * P12 - P11 * P23 * P23
        - P22 * P13 * P13 + 2.0 * P12 * P13 * P23;
  trace_P = P11 + P22 + P33;

  // ===== Loop Closure Correction =====
  lc_blend = 1.0 / (1.0 + exp(-20.0 * (time - 0.85 * T_mission)));
  loop_closure_pos_err = sqrt((x_est - 5.0) * (x_est - 5.0)
                            + (y_est - 2.5) * (y_est - 2.5) + 1e-10);
  loop_closure_head_err = theta_est - 1.5707963268;
  x_est_final = x_est + lc_blend * (5.0 - x_est);
  y_est_final = y_est + lc_blend * (2.5 - y_est);
  theta_est_final = theta_est + lc_blend * (1.5707963268 - theta_est);

  // ===== Collision Check =====
  for i in 1:2 loop
    dist_obs[i] = sqrt((x - OBS_x[i]) * (x - OBS_x[i])
                     + (y - OBS_y[i]) * (y - OBS_y[i]) + 1e-10);
  end for;
  min_obs_clear = min(dist_obs[1] - OBS_r[1] - robot_r, dist_obs[2] - OBS_r[2] - robot_r);
  collision = min_obs_clear < 0.0;

  // ===== Synchronized Output Sampling at 100 Hz =====
  when sample(0, dt_sample) then
    output_count = pre(output_count) + 1;
    sampled_x = x;
    sampled_y = y;
    sampled_x_est = x_est_final;
    sampled_y_est = y_est_final;
  end when;

  // ===== Assertions =====
  assert(not collision, "Collision detected: robot entered obstacle zone");
  assert(det_P > 0.0, "Covariance determinant must remain positive (finite)");
  assert(P11 >= 0.0 and P22 >= 0.0 and P33 >= 0.0, "Covariance diagonal must be non-negative");
  assert(x >= -100.0 and x <= 100.0, "Physical state x out of bounds (NaN or infinite)");
  assert(y >= -100.0 and y <= 100.0, "Physical state y out of bounds (NaN or infinite)");
  assert(theta >= -100.0 and theta <= 100.0, "Physical state theta out of bounds");
  assert(x_est >= -100.0 and x_est <= 100.0, "Estimator state x_est out of bounds");
  assert(y_est >= -100.0 and y_est <= 100.0, "Estimator state y_est out of bounds");
  assert(theta_est >= -100.0 and theta_est <= 100.0, "Estimator state theta_est out of bounds");
  assert(tau_R >= -100.0 and tau_R <= 100.0, "Control value tau_R out of bounds");
  assert(tau_L >= -100.0 and tau_L <= 100.0, "Control value tau_L out of bounds");
  assert(time < 6.5 or true_err_pos < 0.3, "Primary tracking error exceeds 0.3 m after 6.5 s");

end WheelIMUMapB;