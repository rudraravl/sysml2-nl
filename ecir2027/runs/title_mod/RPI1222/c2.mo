model WheelIMUMapD
  "Instrumented robotic sensing and estimation: differential drive fusing odometry, IMU, and range updates with loop closure"

  // ===== Time schedule =====
  parameter Real T_end = 14.0 "s";
  parameter Real f_rate = 200.0 "Hz";
  parameter Real dt_out = 1.0 / f_rate "s";
  parameter Real t_mid1 = T_end / 3.0 "s";
  parameter Real t_mid2 = 2.0 * T_end / 3.0 "s";
  parameter Real t_closure = T_end - 1.0 "s";
  parameter Real perturbation = 0.2 "m";

  // ===== Robot embodiment =====
  parameter Real m = 16.0 "kg";
  parameter Real r_wheel = 0.08 "m";
  parameter Real L_wheel = 0.40 "m";
  parameter Real I_z = 1.2 "kg.m2";
  parameter Real c_drag = 2.0 "N.s/m";
  parameter Real c_yaw_drag = 0.8 "N.m.s";
  parameter Real tau_max = 10.0 "N.m";

  // ===== Reference path =====
  parameter Real R_path = 1.5 "m";
  parameter Real w_ref = 2.0 * Modelica.Constants.pi / T_end "rad/s";
  parameter Real v_ff = R_path * w_ref "m/s";
  parameter Real omega_ff = w_ref "rad/s";
  parameter Real x_start = R_path "m";
  parameter Real y_start = 0.0 "m";
  parameter Real theta_start = Modelica.Constants.pi / 2 "rad";

  // ===== World: landmarks and obstacles =====
  parameter Real lm1_x = 2.5 "m";
  parameter Real lm1_y = 1.5 "m";
  parameter Real lm2_x = 1.0 "m";
  parameter Real lm2_y = 2.5 "m";
  parameter Real lm3_x = -1.5 "m";
  parameter Real lm3_y = 2.0 "m";
  parameter Real lm4_x = -2.5 "m";
  parameter Real lm4_y = -1.5 "m";
  parameter Real lm5_x = -1.0 "m";
  parameter Real lm5_y = -2.5 "m";
  parameter Real lm6_x = 1.5 "m";
  parameter Real lm6_y = -2.0 "m";

  parameter Real obs1_x = 0.0 "m";
  parameter Real obs1_y = 0.0 "m";
  parameter Real obs1_r = 0.5 "m";
  parameter Real obs2_x = 3.2 "m";
  parameter Real obs2_y = 1.8 "m";
  parameter Real obs2_r = 0.4 "m";
  parameter Real robot_radius = 0.20 "m";

  // ===== IMU parameters =====
  parameter Real imu_accel_bias_x = 0.02 "m/s2";
  parameter Real imu_accel_bias_y = 0.01 "m/s2";
  parameter Real imu_accel_bias_z = 0.0 "m/s2";
  parameter Real imu_gyro_bias_z = 0.005 "rad/s";
  parameter Real imu_accel_noise = 0.05 "m/s2";
  parameter Real imu_gyro_noise = 0.01 "rad/s";

  // ===== Range sensor =====
  parameter Real range_noise = 0.02 "m";
  parameter Real range_bias = 0.0 "m";

  // ===== Controller / estimator gains =====
  parameter Real Kp_v = 20.0;
  parameter Real Kp_w = 6.0;
  parameter Real K_track_along = 1.5;
  parameter Real K_track_cross = 1.8;
  parameter Real K_track_head = 2.5;
  parameter Real K_fuse = 6.0;
  parameter Real K_imu = 2.0;
  parameter Real K_imu_accel = 0.3;
  parameter Real K_range_corr = 1.2;
  parameter Real K_closure = 0.8;

  // ===== Covariance parameters =====
  parameter Real Q1 = 0.001;
  parameter Real Q2 = 0.001;
  parameter Real Q3 = 0.0001;
  parameter Real Q4 = 0.01;
  parameter Real Q5 = 0.01;
  parameter Real beta1 = 0.6;
  parameter Real beta2 = 0.6;
  parameter Real beta3 = 0.6;
  parameter Real beta4 = 1.0;
  parameter Real beta5 = 1.0;

  // ===== Physical states =====
  Real x(start = x_start, fixed = true) "m";
  Real y(start = y_start, fixed = true) "m";
  Real theta(start = theta_start, fixed = true) "rad";
  Real v(start = v_ff, fixed = true) "m/s";
  Real omega(start = omega_ff, fixed = true) "rad/s";
  Real omega_L "rad/s";
  Real omega_R "rad/s";

  // ===== Actuators =====
  Real tau_L_cmd "N.m";
  Real tau_R_cmd "N.m";
  Real tau_L "N.m";
  Real tau_R "N.m";
  Real F_L_cmd "N";
  Real F_R_cmd "N";
  Real F_des "N";
  Real M_des "N.m";

  // ===== Reference =====
  Real x_ref "m";
  Real y_ref "m";
  Real theta_ref "rad";
  Real along_err "m";
  Real cross_err "m";
  Real head_err "rad";
  Real v_cmd "m/s";
  Real omega_cmd "rad/s";

  // ===== Tracking error =====
  Real tracking_error "m";

  // ===== IMU six-axis =====
  Real imu_ax "m/s2";
  Real imu_ay "m/s2";
  Real imu_az "m/s2";
  Real imu_wx "rad/s";
  Real imu_wy "rad/s";
  Real imu_wz "rad/s";

  // ===== Odometry =====
  Real odom_v "m/s";
  Real odom_omega "rad/s";

  // ===== Range measurements =====
  Real range1 "m";
  Real range2 "m";
  Real range3 "m";
  Real range4 "m";
  Real range5 "m";
  Real range6 "m";
  Real raw_camera1 "m";
  Real raw_camera2 "m";
  Real raw_camera3 "m";
  Real raw_camera4 "m";
  Real raw_camera5 "m";
  Real raw_camera6 "m";
  Real raw_sonar1 "m";
  Real raw_sonar2 "m";
  Real raw_sonar3 "m";
  Real raw_sonar4 "m";
  Real raw_sonar5 "m";
  Real raw_sonar6 "m";

  // ===== Landmark perturbation =====
  Real perturbation_active;
  Real lm1_eff_x "m";
  Real lm2_eff_x "m";
  Real lm3_eff_x "m";
  Real lm4_eff_x "m";
  Real lm5_eff_x "m";
  Real lm6_eff_x "m";

  // ===== Estimator =====
  Real est_x(start = x_start, fixed = true) "m";
  Real est_y(start = y_start, fixed = true) "m";
  Real est_theta(start = theta_start, fixed = true) "rad";
  Real est_v(start = v_ff, fixed = true) "m/s";
  Real est_omega(start = omega_ff, fixed = true) "rad/s";
  Real r_pred1 "m";
  Real r_pred2 "m";
  Real r_pred3 "m";
  Real r_pred4 "m";
  Real r_pred5 "m";
  Real r_pred6 "m";
  Real residual1 "m";
  Real residual2 "m";
  Real residual3 "m";
  Real residual4 "m";
  Real residual5 "m";
  Real residual6 "m";
  Real corr_x "m/s";
  Real corr_y "m/s";

  // ===== Covariance (diagonal, finite) =====
  Real P11(start = 0.01, fixed = true);
  Real P22(start = 0.01, fixed = true);
  Real P33(start = 0.001, fixed = true);
  Real P44(start = 0.1, fixed = true);
  Real P55(start = 0.1, fixed = true);

  // ===== Loop closure =====
  Real closure_active;
  Real loop_pos_error "m";
  Real loop_heading_error "rad";

  // ===== Collision =====
  Real dist_obs1 "m";
  Real dist_obs2 "m";
  Real collision_flag;

  // ===== Outputs =====
  output Real x_out = x;
  output Real y_out = y;
  output Real theta_out = theta;
  output Real v_out = v;
  output Real omega_out = omega;
  output Real tau_L_out = tau_L;
  output Real tau_R_out = tau_R;
  output Real est_x_out = est_x;
  output Real est_y_out = est_y;
  output Real est_theta_out = est_theta;
  output Real est_v_out = est_v;
  output Real est_omega_out = est_omega;
  output Real tracking_error_out = tracking_error;
  output Real loop_pos_error_out = loop_pos_error;
  output Real loop_heading_error_out = loop_heading_error;
  output Real collision_flag_out = collision_flag;
  output Real covariance_trace = P11 + P22 + P33 + P44 + P55;
  output Real output_rate_Hz = f_rate;

equation
  // ===== Reference path =====
  x_ref = R_path * Modelica.Math.cos(w_ref * time);
  y_ref = R_path * Modelica.Math.sin(w_ref * time);
  theta_ref = w_ref * time + Modelica.Constants.pi / 2;

  // ===== Path-frame errors =====
  along_err = Modelica.Math.cos(theta_ref) * (x - x_ref) + Modelica.Math.sin(theta_ref) * (y - y_ref);
  cross_err = -Modelica.Math.sin(theta_ref) * (x - x_ref) + Modelica.Math.cos(theta_ref) * (y - y_ref);
  head_err = theta - theta_ref;

  // ===== Commands =====
  v_cmd = v_ff - K_track_along * along_err;
  omega_cmd = omega_ff - K_track_cross * cross_err - K_track_head * head_err;

  // ===== Desired forces/moment =====
  F_des = Kp_v * (v_cmd - v) + c_drag * v;
  M_des = Kp_w * (omega_cmd - omega) + c_yaw_drag * omega;

  // ===== Distribute to wheels =====
  F_L_cmd = F_des / 2.0 - M_des / L_wheel;
  F_R_cmd = F_des / 2.0 + M_des / L_wheel;
  tau_L_cmd = F_L_cmd * r_wheel;
  tau_R_cmd = F_R_cmd * r_wheel;

  // ===== Torque saturation =====
  tau_L = if tau_L_cmd > tau_max then tau_max elseif tau_L_cmd < -tau_max then -tau_max else tau_L_cmd;
  tau_R = if tau_R_cmd > tau_max then tau_max elseif tau_R_cmd < -tau_max then -tau_max else tau_R_cmd;

  // ===== Robot dynamics =====
  der(x) = v * Modelica.Math.cos(theta);
  der(y) = v * Modelica.Math.sin(theta);
  der(theta) = omega;
  der(v) = (tau_L + tau_R) / r_wheel / m - c_drag * v / m;
  der(omega) = ((tau_R - tau_L) / r_wheel) * (L_wheel / 2.0) / I_z - c_yaw_drag * omega / I_z;

  // ===== Wheel angular velocities =====
  omega_L = (v - omega * L_wheel / 2.0) / r_wheel;
  omega_R = (v + omega * L_wheel / 2.0) / r_wheel;

  // ===== IMU six-axis =====
  imu_ax = (tau_L + tau_R) / r_wheel / m - c_drag * v / m + imu_accel_bias_x + imu_accel_noise * Modelica.Math.sin(13.0 * time);
  imu_ay = -omega * v + imu_accel_bias_y + imu_accel_noise * 0.5 * Modelica.Math.cos(7.0 * time);
  imu_az = imu_accel_bias_z;
  imu_wx = 0.0;
  imu_wy = 0.0;
  imu_wz = omega + imu_gyro_bias_z + imu_gyro_noise * Modelica.Math.sin(17.0 * time);

  // ===== Odometry =====
  odom_v = r_wheel * (omega_L + omega_R) / 2.0;
  odom_omega = r_wheel * (omega_R - omega_L) / L_wheel;

  // ===== Landmark perturbation =====
  perturbation_active = if (time >= t_mid1) and (time <= t_mid2) then 1.0 else 0.0;
  lm1_eff_x = lm1_x + perturbation_active * perturbation;
  lm2_eff_x = lm2_x + perturbation_active * perturbation;
  lm3_eff_x = lm3_x + perturbation_active * perturbation;
  lm4_eff_x = lm4_x + perturbation_active * perturbation;
  lm5_eff_x = lm5_x + perturbation_active * perturbation;
  lm6_eff_x = lm6_x + perturbation_active * perturbation;

  // ===== Range measurements =====
  range1 = sqrt((x - lm1_eff_x) ^ 2 + (y - lm1_y) ^ 2 + 1.0e-6) + range_noise * Modelica.Math.sin(5.0 + 11.0 * time) + range_bias;
  range2 = sqrt((x - lm2_eff_x) ^ 2 + (y - lm2_y) ^ 2 + 1.0e-6) + range_noise * Modelica.Math.sin(10.0 + 11.0 * time) + range_bias;
  range3 = sqrt((x - lm3_eff_x) ^ 2 + (y - lm3_y) ^ 2 + 1.0e-6) + range_noise * Modelica.Math.sin(15.0 + 11.0 * time) + range_bias;
  range4 = sqrt((x - lm4_eff_x) ^ 2 + (y - lm4_y) ^ 2 + 1.0e-6) + range_noise * Modelica.Math.sin(20.0 + 11.0 * time) + range_bias;
  range5 = sqrt((x - lm5_eff_x) ^ 2 + (y - lm5_y) ^ 2 + 1.0e-6) + range_noise * Modelica.Math.sin(25.0 + 11.0 * time) + range_bias;
  range6 = sqrt((x - lm6_eff_x) ^ 2 + (y - lm6_y) ^ 2 + 1.0e-6) + range_noise * Modelica.Math.sin(30.0 + 11.0 * time) + range_bias;

  // ===== Raw camera (preserved separately) =====
  raw_camera1 = sqrt((x - lm1_eff_x) ^ 2 + (y - lm1_y) ^ 2 + 1.0e-6) + range_noise * 0.5 * Modelica.Math.sin(3.0 + 5.0 * time);
  raw_camera2 = sqrt((x - lm2_eff_x) ^ 2 + (y - lm2_y) ^ 2 + 1.0e-6) + range_noise * 0.5 * Modelica.Math.sin(6.0 + 5.0 * time);
  raw_camera3 = sqrt((x - lm3_eff_x) ^ 2 + (y - lm3_y) ^ 2 + 1.0e-6) + range_noise * 0.5 * Modelica.Math.sin(9.0 + 5.0 * time);
  raw_camera4 = sqrt((x - lm4_eff_x) ^ 2 + (y - lm4_y) ^ 2 + 1.0e-6) + range_noise * 0.5 * Modelica.Math.sin(12.0 + 5.0 * time);
  raw_camera5 = sqrt((x - lm5_eff_x) ^ 2 + (y - lm5_y) ^ 2 + 1.0e-6) + range_noise * 0.5 * Modelica.Math.sin(15.0 + 5.0 * time);
  raw_camera6 = sqrt((x - lm6_eff_x) ^ 2 + (y - lm6_y) ^ 2 + 1.0e-6) + range_noise * 0.5 * Modelica.Math.sin(18.0 + 5.0 * time);

  // ===== Raw sonar (preserved separately) =====
  raw_sonar1 = sqrt((x - lm1_eff_x) ^ 2 + (y - lm1_y) ^ 2 + 1.0e-6) + range_noise * 0.8 * Modelica.Math.sin(2.0 + 4.0 * time);
  raw_sonar2 = sqrt((x - lm2_eff_x) ^ 2 + (y - lm2_y) ^ 2 + 1.0e-6) + range_noise * 0.8 * Modelica.Math.sin(4.0 + 4.0 * time);
  raw_sonar3 = sqrt((x - lm3_eff_x) ^ 2 + (y - lm3_y) ^ 2 + 1.0e-6) + range_noise * 0.8 * Modelica.Math.sin(6.0 + 4.0 * time);
  raw_sonar4 = sqrt((x - lm4_eff_x) ^ 2 + (y - lm4_y) ^ 2 + 1.0e-6) + range_noise * 0.8 * Modelica.Math.sin(8.0 + 4.0 * time);
  raw_sonar5 = sqrt((x - lm5_eff_x) ^ 2 + (y - lm5_y) ^ 2 + 1.0e-6) + range_noise * 0.8 * Modelica.Math.sin(10.0 + 4.0 * time);
  raw_sonar6 = sqrt((x - lm6_eff_x) ^ 2 + (y - lm6_y) ^ 2 + 1.0e-6) + range_noise * 0.8 * Modelica.Math.sin(12.0 + 4.0 * time);

  // ===== Estimator predicted ranges (nominal landmarks) =====
  r_pred1 = sqrt((est_x - lm1_x) ^ 2 + (est_y - lm1_y) ^ 2 + 1.0e-6);
  r_pred2 = sqrt((est_x - lm2_x) ^ 2 + (est_y - lm2_y) ^ 2 + 1.0e-6);
  r_pred3 = sqrt((est_x - lm3_x) ^ 2 + (est_y - lm3_y) ^ 2 + 1.0e-6);
  r_pred4 = sqrt((est_x - lm4_x) ^ 2 + (est_y - lm4_y) ^ 2 + 1.0e-6);
  r_pred5 = sqrt((est_x - lm5_x) ^ 2 + (est_y - lm5_y) ^ 2 + 1.0e-6);
  r_pred6 = sqrt((est_x - lm6_x) ^ 2 + (est_y - lm6_y) ^ 2 + 1.0e-6);

  residual1 = range1 - r_pred1;
  residual2 = range2 - r_pred2;
  residual3 = range3 - r_pred3;
  residual4 = range4 - r_pred4;
  residual5 = range5 - r_pred5;
  residual6 = range6 - r_pred6;

  // ===== Range corrections (gradient descent) =====
  corr_x = K_range_corr * (
    residual1 * (est_x - lm1_x) / r_pred1 +
    residual2 * (est_x - lm2_x) / r_pred2 +
    residual3 * (est_x - lm3_x) / r_pred3 +
    residual4 * (est_x - lm4_x) / r_pred4 +
    residual5 * (est_x - lm5_x) / r_pred5 +
    residual6 * (est_x - lm6_x) / r_pred6);

  corr_y = K_range_corr * (
    residual1 * (est_y - lm1_y) / r_pred1 +
    residual2 * (est_y - lm2_y) / r_pred2 +
    residual3 * (est_y - lm3_y) / r_pred3 +
    residual4 * (est_y - lm4_y) / r_pred4 +
    residual5 * (est_y - lm5_y) / r_pred5 +
    residual6 * (est_y - lm6_y) / r_pred6);

  // ===== Loop closure =====
  closure_active = if time >= t_closure then 1.0 else 0.0;
  loop_pos_error = sqrt((est_x - x_start) ^ 2 + (est_y - y_start) ^ 2 + 1.0e-9);
  loop_heading_error = est_theta - theta_ref;

  // ===== Estimator dynamics =====
  der(est_v) = K_fuse * (odom_v - est_v) + K_imu_accel * (imu_ax - imu_accel_bias_x);
  der(est_omega) = K_fuse * (odom_omega - est_omega) + K_imu * ((imu_wz - imu_gyro_bias_z) - est_omega);
  der(est_x) = est_v * Modelica.Math.cos(est_theta) + corr_x + closure_active * K_closure * (x_start - est_x);
  der(est_y) = est_v * Modelica.Math.sin(est_theta) + corr_y + closure_active * K_closure * (y_start - est_y);
  der(est_theta) = est_omega + closure_active * K_closure * (theta_ref - est_theta);

  // ===== Covariance (diagonal, finite, stable) =====
  der(P11) = Q1 - (beta1 + K_range_corr * 0.5 + closure_active * K_closure) * P11;
  der(P22) = Q2 - (beta2 + K_range_corr * 0.5 + closure_active * K_closure) * P22;
  der(P33) = Q3 - (beta3 + closure_active * K_closure) * P33;
  der(P44) = Q4 - beta4 * P44;
  der(P55) = Q5 - beta5 * P55;

  // ===== Collision check =====
  dist_obs1 = sqrt((x - obs1_x) ^ 2 + (y - obs1_y) ^ 2 + 1.0e-9);
  dist_obs2 = sqrt((x - obs2_x) ^ 2 + (y - obs2_y) ^ 2 + 1.0e-9);
  collision_flag = if (dist_obs1 < robot_radius + obs1_r) or (dist_obs2 < robot_radius + obs2_r) then 1.0 else 0.0;

  // ===== Tracking error =====
  tracking_error = sqrt((x - x_ref) ^ 2 + (y - y_ref) ^ 2 + 1.0e-9);

  annotation(
    experiment(StopTime = 14.0, Tolerance = 1e-6, Interval = 0.005),
    Documentation(info = "WheelIMUMapD: differential drive with wheel encoders, six-axis IMU, and range fusion. Uses built-in sqrt operator.")
  );
end WheelIMUMapD;