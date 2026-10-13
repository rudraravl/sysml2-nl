model WheelIMUMapE
  "Differential-drive robotic sensing and estimation with loop closure"

  // ===== Constants =====
  constant Real pi = Modelica.Constants.pi;
  constant Real eps = 1.0e-6 "small constant to avoid division by zero";

  // ===== Physical Parameters =====
  parameter Real m = 16.0 "chassis mass [kg]";
  parameter Real r_wheel = 0.1 "wheel radius [m], assumed";
  parameter Real L_wb = 0.5 "wheelbase [m], assumed";
  parameter Real I_z = 0.8 "yaw moment of inertia [kg.m2], assumed";
  parameter Real mu_v = 1.5 "linear viscous drag coefficient [N.s/m], assumed";
  parameter Real mu_w = 0.8 "rotational viscous drag [N.m.s/rad], assumed";
  parameter Real tau_max = 11.0 "max wheel torque command [N.m]";

  // ===== Simulation Parameters =====
  parameter Real f_sample = 250.0 "declared output rate [Hz]";
  parameter Real dt_sample = 1.0 / f_sample "sample period [s]";
  parameter Real T_end = 16.0 "simulation duration [s]";

  // ===== Route Parameters =====
  parameter Real R_route = 3.0 "closed-route radius [m], assumed";
  parameter Real omega_route = 2.0 * pi / T_end "route angular speed [rad/s]";

  // ===== Landmarks (6 fixed, shared world frame) =====
  parameter Real lm1_x = 4.0 "landmark 1 x [m], assumed";
  parameter Real lm1_y = 0.0 "landmark 1 y [m], assumed";
  parameter Real lm2_x = 2.121 "landmark 2 x [m], assumed";
  parameter Real lm2_y = 2.121 "landmark 2 y [m], assumed";
  parameter Real lm3_x = -2.121 "landmark 3 x [m], assumed";
  parameter Real lm3_y = 2.121 "landmark 3 y [m], assumed";
  parameter Real lm4_x = -4.0 "landmark 4 x [m], assumed";
  parameter Real lm4_y = 0.0 "landmark 4 y [m], assumed";
  parameter Real lm5_x = -2.121 "landmark 5 x [m], assumed";
  parameter Real lm5_y = -2.121 "landmark 5 y [m], assumed";
  parameter Real lm6_x = 2.121 "landmark 6 x [m], assumed";
  parameter Real lm6_y = -2.121 "landmark 6 y [m], assumed";

  // ===== Obstacles (2 fixed, shared world frame) =====
  parameter Real obs1_x = 1.0 "obstacle 1 center x [m], assumed";
  parameter Real obs1_y = 1.0 "obstacle 1 center y [m], assumed";
  parameter Real obs1_r = 0.4 "obstacle 1 radius [m], assumed";
  parameter Real obs2_x = -1.0 "obstacle 2 center x [m], assumed";
  parameter Real obs2_y = -1.0 "obstacle 2 center y [m], assumed";
  parameter Real obs2_r = 0.4 "obstacle 2 radius [m], assumed";

  // ===== IMU Noise and Bias Parameters =====
  parameter Real imu_acc_bias_x = 0.02 "accelerometer x bias [m/s2], assumed";
  parameter Real imu_acc_bias_y = 0.01 "accelerometer y bias [m/s2], assumed";
  parameter Real imu_acc_bias_z = 0.0 "accelerometer z bias [m/s2], assumed";
  parameter Real imu_acc_noise_std = 0.05 "accelerometer noise std [m/s2], assumed";
  parameter Real imu_gyro_bias_z = 0.005 "gyro z bias [rad/s], assumed";
  parameter Real imu_gyro_noise_std = 0.01 "gyro noise std [rad/s], assumed";

  // ===== Encoder Noise Parameters =====
  parameter Real enc_noise_std = 0.02 "encoder velocity noise std [m/s], assumed";

  // ===== Range Sensor Parameters =====
  parameter Real range_noise_std = 0.03 "range measurement noise std [m], assumed";
  parameter Real range_max = 6.0 "max sensing range [m], assumed";

  // ===== Estimator Parameters =====
  parameter Real Q_pos = 1.0e-4 "process noise position [m2/s]";
  parameter Real Q_theta = 1.0e-4 "process noise heading [rad2/s]";
  parameter Real Q_vel = 1.0e-3 "process noise velocity [(m/s)2/s]";
  parameter Real Q_omega = 1.0e-3 "process noise yaw rate [(rad/s)2/s]";
  parameter Real P0_pos = 0.01 "initial position covariance [m2]";
  parameter Real P0_theta = 0.01 "initial heading covariance [rad2]";
  parameter Real P0_vel = 0.01 "initial velocity covariance [(m/s)2]";
  parameter Real P0_omega = 0.01 "initial yaw rate covariance [(rad/s)2]";
  parameter Real K_range = 0.5 "range correction gain [1/s], assumed";
  parameter Real K_lc = 2.0 "loop-closure correction gain [1/s], assumed";
  parameter Real K_v_fuse = 0.5 "IMU-odometry velocity fusion weight";
  parameter Real K_w_fuse = 0.3 "IMU-odometry yaw-rate fusion weight";
  parameter Real alpha_corr = 0.5 "covariance correction rate [1/s], assumed";
  parameter Real alpha_lc = 2.0 "loop-closure covariance rate [1/s], assumed";

  // ===== Perturbation Parameters =====
  parameter Real perturb_mag = 0.24 "landmark perturbation magnitude [m]";
  parameter Real T_third1 = T_end / 3.0 "start of middle third [s]";
  parameter Real T_third2 = 2.0 * T_end / 3.0 "end of middle third [s]";

  // ===== Controller Gains =====
  parameter Real Kp_v = 8.0 "velocity proportional gain, assumed";
  parameter Real Kp_w = 5.0 "yaw-rate proportional gain, assumed";
  parameter Real Kp_pos = 1.5 "position proportional gain, assumed";
  parameter Real Kp_theta = 2.0 "heading proportional gain, assumed";

  // ===== Plant State Variables =====
  Real x(start = R_route, fixed = true) "robot x position [m]";
  Real y(start = 0.0, fixed = true) "robot y position [m]";
  Real theta(start = pi / 2.0, fixed = true) "robot heading [rad]";
  Real v(start = 0.0, fixed = true) "forward velocity [m/s]";
  Real omega(start = 0.0, fixed = true) "angular velocity [rad/s]";
  Real a_body_x "forward acceleration [m/s2]";

  // ===== Torque Command and Actuation =====
  Real tau_L_cmd "left wheel torque command [N.m]";
  Real tau_R_cmd "right wheel torque command [N.m]";
  Real tau_L_act "actual left wheel torque [N.m]";
  Real tau_R_act "actual right wheel torque [N.m]";

  // ===== Reference Trajectory =====
  Real x_ref "reference x [m]";
  Real y_ref "reference y [m]";
  Real theta_ref "reference heading [rad]";
  Real v_ref "reference velocity [m/s]";
  Real omega_ref "reference angular velocity [rad/s]";

  // ===== Controller Errors =====
  Real err_x "x tracking error [m]";
  Real err_y "y tracking error [m]";
  Real err_v_body "velocity error body frame [m/s]";
  Real err_omega "angular velocity error [rad/s]";
  Real track_err "primary tracking error [m]";
  discrete Real tracking_error_104(start = 0.0) "tracking error at t=10.4 s [m]";

  // ===== IMU Sensor Outputs (6-axis) =====
  Real imu_ax "accelerometer x [m/s2]";
  Real imu_ay "accelerometer y [m/s2]";
  Real imu_az "accelerometer z [m/s2]";
  Real imu_gx "gyro x [rad/s]";
  Real imu_gy "gyro y [rad/s]";
  Real imu_gz "gyro z [rad/s]";

  // ===== Wheel Encoder Outputs =====
  Real enc_vL "left encoder linear velocity [m/s]";
  Real enc_vR "right encoder linear velocity [m/s]";
  Real odo_v "odometry velocity [m/s]";
  Real odo_omega "odometry angular velocity [rad/s]";
  Real odo_x(start = R_route, fixed = true) "odometry x [m]";
  Real odo_y(start = 0.0, fixed = true) "odometry y [m]";
  Real odo_theta(start = pi / 2.0, fixed = true) "odometry heading [rad]";

  // ===== Range Sensor Outputs =====
  Real range1 "range to landmark 1 [m]";
  Real range2 "range to landmark 2 [m]";
  Real range3 "range to landmark 3 [m]";
  Real range4 "range to landmark 4 [m]";
  Real range5 "range to landmark 5 [m]";
  Real range6 "range to landmark 6 [m]";

  // ===== Raw Camera and Sonar Data (preserved separately, not fused) =====
  Real cam1_data "camera channel 1 raw observation";
  Real cam2_data "camera channel 2 raw observation";
  Real sonar1_data "sonar channel 1 raw observation";
  Real sonar2_data "sonar channel 2 raw observation";

  // ===== Estimator State =====
  Real x_est(start = R_route, fixed = true) "estimated x [m]";
  Real y_est(start = 0.0, fixed = true) "estimated y [m]";
  Real theta_est(start = pi / 2.0, fixed = true) "estimated heading [rad]";
  Real v_est(start = 0.0, fixed = true) "estimated velocity [m/s]";
  Real omega_est(start = 0.0, fixed = true) "estimated angular velocity [rad/s]";

  // ===== Estimator Covariance (diagonal) =====
  Real P11(start = P0_pos, fixed = true) "covariance x [m2]";
  Real P22(start = P0_pos, fixed = true) "covariance y [m2]";
  Real P33(start = P0_theta, fixed = true) "covariance theta [rad2]";
  Real P44(start = P0_vel, fixed = true) "covariance v [(m/s)2]";
  Real P55(start = P0_omega, fixed = true) "covariance omega [(rad/s)2]";
  Real cov_trace "covariance trace";

  // ===== Map with Perturbation =====
  Real lm1_x_map "map LM1 x [m]";
  Real lm1_y_map "map LM1 y [m]";
  Real lm2_x_map "map LM2 x [m]";
  Real lm2_y_map "map LM2 y [m]";
  Real lm3_x_map "map LM3 x [m]";
  Real lm3_y_map "map LM3 y [m]";
  Real lm4_x_map "map LM4 x [m]";
  Real lm4_y_map "map LM4 y [m]";
  Real lm5_x_map "map LM5 x [m]";
  Real lm5_y_map "map LM5 y [m]";
  Real lm6_x_map "map LM6 x [m]";
  Real lm6_y_map "map LM6 y [m]";
  Boolean perturb_active "perturbation is active flag";

  // ===== Range Prediction and Correction =====
  Real r_pred1 "predicted range LM1 [m]";
  Real r_pred2 "predicted range LM2 [m]";
  Real r_pred3 "predicted range LM3 [m]";
  Real r_pred4 "predicted range LM4 [m]";
  Real r_pred5 "predicted range LM5 [m]";
  Real r_pred6 "predicted range LM6 [m]";
  Real inn1 "range innovation LM1 [m]";
  Real inn2 "range innovation LM2 [m]";
  Real inn3 "range innovation LM3 [m]";
  Real inn4 "range innovation LM4 [m]";
  Real inn5 "range innovation LM5 [m]";
  Real inn6 "range innovation LM6 [m]";
  Real gate1 "range gate LM1";
  Real gate2 "range gate LM2";
  Real gate3 "range gate LM3";
  Real gate4 "range gate LM4";
  Real gate5 "range gate LM5";
  Real gate6 "range gate LM6";
  Real corr_x "total range correction x [m/s]";
  Real corr_y "total range correction y [m/s]";

  // ===== Loop Closure =====
  Boolean loop_closure_detected "loop-closure detection flag";
  Real lc_pos_err "loop-closure position error [m]";
  Real lc_theta_err "loop-closure heading error [rad]";
  Real lc_corr_x "loop-closure x correction [m/s]";
  Real lc_corr_y "loop-closure y correction [m/s]";
  Real lc_corr_theta "loop-closure theta correction [rad/s]";

  // ===== Safety =====
  Real dist_obs1 "distance to obstacle 1 [m]";
  Real dist_obs2 "distance to obstacle 2 [m]";
  Boolean collision "collision flag";
  Boolean fail_closed "fail-closed flag";

  // ===== Validation Outputs =====
  Boolean cov_finite "covariance finiteness flag";
  Boolean no_nan_inf "no NaN/Inf flag";
  Real output_rate "declared output rate [Hz]";

  // ===== Pseudo-noise Signals =====
  Real n_ax "accelerometer x noise";
  Real n_ay "accelerometer y noise";
  Real n_gz "gyro z noise";
  Real n_encL "encoder left noise";
  Real n_encR "encoder right noise";
  Real n_r1 "range 1 noise";
  Real n_r2 "range 2 noise";
  Real n_r3 "range 3 noise";
  Real n_r4 "range 4 noise";
  Real n_r5 "range 5 noise";
  Real n_r6 "range 6 noise";

equation
  // ===== Pseudo-noise (deterministic sinusoidal) =====
  n_ax = imu_acc_noise_std * sin(2.0 * pi * 37.0 * time + 0.1);
  n_ay = imu_acc_noise_std * sin(2.0 * pi * 41.0 * time + 0.3);
  n_gz = imu_gyro_noise_std * sin(2.0 * pi * 43.0 * time + 0.7);
  n_encL = enc_noise_std * sin(2.0 * pi * 47.0 * time + 0.5);
  n_encR = enc_noise_std * sin(2.0 * pi * 53.0 * time + 0.9);
  n_r1 = range_noise_std * sin(2.0 * pi * 59.0 * time + 0.2);
  n_r2 = range_noise_std * sin(2.0 * pi * 61.0 * time + 0.4);
  n_r3 = range_noise_std * sin(2.0 * pi * 67.0 * time + 0.6);
  n_r4 = range_noise_std * sin(2.0 * pi * 71.0 * time + 0.8);
  n_r5 = range_noise_std * sin(2.0 * pi * 73.0 * time + 1.0);
  n_r6 = range_noise_std * sin(2.0 * pi * 79.0 * time + 1.2);

  // ===== Plant Dynamics (differential drive) =====
  a_body_x = (tau_L_act + tau_R_act) / (r_wheel * m) - mu_v * v / m;
  der(x) = v * cos(theta);
  der(y) = v * sin(theta);
  der(theta) = omega;
  der(v) = a_body_x;
  der(omega) = (tau_R_act - tau_L_act) * L_wb / (2.0 * r_wheel * I_z) - mu_w * omega / I_z;

  // ===== Torque Saturation and Fail-Closed =====
  tau_L_act = if collision then 0.0
    else (if tau_L_cmd > tau_max then tau_max
    else (if tau_L_cmd < (-tau_max) then (-tau_max) else tau_L_cmd));
  tau_R_act = if collision then 0.0
    else (if tau_R_cmd > tau_max then tau_max
    else (if tau_R_cmd < (-tau_max) then (-tau_max) else tau_R_cmd));
  fail_closed = collision;

  // ===== Reference Trajectory (closed circular route) =====
  x_ref = R_route * cos(omega_route * time);
  y_ref = R_route * sin(omega_route * time);
  theta_ref = omega_route * time + pi / 2.0;
  v_ref = R_route * omega_route;
  omega_ref = omega_route;

  // ===== Controller (proportional with feedforward) =====
  err_x = x_ref - x;
  err_y = y_ref - y;
  err_v_body = (v_ref - v) + Kp_pos * (err_x * cos(theta) + err_y * sin(theta));
  err_omega = (omega_ref - omega) + Kp_theta * (theta_ref - theta);
  tau_L_cmd = Kp_v * err_v_body - Kp_w * err_omega;
  tau_R_cmd = Kp_v * err_v_body + Kp_w * err_omega;
  track_err = sqrt(err_x * err_x + err_y * err_y + eps);

  // ===== IMU Sensor Model (6-axis, center-mounted) =====
  imu_ax = a_body_x + imu_acc_bias_x + n_ax;
  imu_ay = v * omega + imu_acc_bias_y + n_ay;
  imu_az = imu_acc_bias_z;
  imu_gx = 0.0;
  imu_gy = 0.0;
  imu_gz = omega + imu_gyro_bias_z + n_gz;

  // ===== Wheel Encoder Model =====
  enc_vL = v - omega * L_wb / 2.0 + n_encL;
  enc_vR = v + omega * L_wb / 2.0 + n_encR;
  odo_v = (enc_vL + enc_vR) / 2.0;
  odo_omega = (enc_vR - enc_vL) / L_wb;

  // ===== Odometry Dead-Reckoning =====
  der(odo_x) = odo_v * cos(odo_theta);
  der(odo_y) = odo_v * sin(odo_theta);
  der(odo_theta) = odo_omega;

  // ===== Range Sensor Model =====
  range1 = sqrt((x - lm1_x) * (x - lm1_x) + (y - lm1_y) * (y - lm1_y) + eps) + n_r1;
  range2 = sqrt((x - lm2_x) * (x - lm2_x) + (y - lm2_y) * (y - lm2_y) + eps) + n_r2;
  range3 = sqrt((x - lm3_x) * (x - lm3_x) + (y - lm3_y) * (y - lm3_y) + eps) + n_r3;
  range4 = sqrt((x - lm4_x) * (x - lm4_x) + (y - lm4_y) * (y - lm4_y) + eps) + n_r4;
  range5 = sqrt((x - lm5_x) * (x - lm5_x) + (y - lm5_y) * (y - lm5_y) + eps) + n_r5;
  range6 = sqrt((x - lm6_x) * (x - lm6_x) + (y - lm6_y) * (y - lm6_y) + eps) + n_r6;

  // ===== Raw Camera and Sonar Data (preserved separately, not fused) =====
  cam1_data = sin(2.0 * pi * 5.0 * time) * exp(-0.1 * ((x - lm1_x) * (x - lm1_x) + (y - lm1_y) * (y - lm1_y)));
  cam2_data = cos(2.0 * pi * 7.0 * time) * exp(-0.1 * ((x - lm2_x) * (x - lm2_x) + (y - lm2_y) * (y - lm2_y)));
  sonar1_data = sqrt((x - obs1_x) * (x - obs1_x) + (y - obs1_y) * (y - obs1_y) + eps);
  sonar2_data = sqrt((x - obs2_x) * (x - obs2_x) + (y - obs2_y) * (y - obs2_y) + eps);

  // ===== Landmark Map with Middle-Third Perturbation =====
  perturb_active = (time >= T_third1) and (time <= T_third2);
  lm1_x_map = if perturb_active then lm1_x + perturb_mag else lm1_x;
  lm1_y_map = lm1_y;
  lm2_x_map = if perturb_active then lm2_x + perturb_mag else lm2_x;
  lm2_y_map = lm2_y;
  lm3_x_map = if perturb_active then lm3_x + perturb_mag else lm3_x;
  lm3_y_map = lm3_y;
  lm4_x_map = if perturb_active then lm4_x + perturb_mag else lm4_x;
  lm4_y_map = lm4_y;
  lm5_x_map = if perturb_active then lm5_x + perturb_mag else lm5_x;
  lm5_y_map = lm5_y;
  lm6_x_map = if perturb_active then lm6_x + perturb_mag else lm6_x;
  lm6_y_map = lm6_y;

  // ===== Estimator Prediction (fused odometry + IMU) =====
  der(x_est) = v_est * cos(theta_est) + corr_x + lc_corr_x;
  der(y_est) = v_est * sin(theta_est) + corr_y + lc_corr_y;
  der(theta_est) = omega_est + lc_corr_theta;
  der(v_est) = (imu_ax - imu_acc_bias_x) * K_v_fuse + (odo_v - v_est) * (1.0 - K_v_fuse);
  der(omega_est) = (imu_gz - imu_gyro_bias_z) * K_w_fuse + (odo_omega - omega_est) * (1.0 - K_w_fuse);

  // ===== Range Prediction =====
  r_pred1 = sqrt((x_est - lm1_x_map) * (x_est - lm1_x_map) + (y_est - lm1_y_map) * (y_est - lm1_y_map) + eps);
  r_pred2 = sqrt((x_est - lm2_x_map) * (x_est - lm2_x_map) + (y_est - lm2_y_map) * (y_est - lm2_y_map) + eps);
  r_pred3 = sqrt((x_est - lm3_x_map) * (x_est - lm3_x_map) + (y_est - lm3_y_map) * (y_est - lm3_y_map) + eps);
  r_pred4 = sqrt((x_est - lm4_x_map) * (x_est - lm4_x_map) + (y_est - lm4_y_map) * (y_est - lm4_y_map) + eps);
  r_pred5 = sqrt((x_est - lm5_x_map) * (x_est - lm5_x_map) + (y_est - lm5_y_map) * (y_est - lm5_y_map) + eps);
  r_pred6 = sqrt((x_est - lm6_x_map) * (x_est - lm6_x_map) + (y_est - lm6_y_map) * (y_est - lm6_y_map) + eps);

  // ===== Range Innovations =====
  inn1 = range1 - r_pred1;
  inn2 = range2 - r_pred2;
  inn3 = range3 - r_pred3;
  inn4 = range4 - r_pred4;
  inn5 = range5 - r_pred5;
  inn6 = range6 - r_pred6;

  // ===== Range Gating (sigmoid, active when in range) =====
  gate1 = 1.0 / (1.0 + exp(5.0 * (range1 - range_max)));
  gate2 = 1.0 / (1.0 + exp(5.0 * (range2 - range_max)));
  gate3 = 1.0 / (1.0 + exp(5.0 * (range3 - range_max)));
  gate4 = 1.0 / (1.0 + exp(5.0 * (range4 - range_max)));
  gate5 = 1.0 / (1.0 + exp(5.0 * (range5 - range_max)));
  gate6 = 1.0 / (1.0 + exp(5.0 * (range6 - range_max)));

  // ===== Range Correction (gradient descent on innovation) =====
  corr_x = K_range * (
    gate1 * inn1 * (x_est - lm1_x_map) / (r_pred1 + eps) +
    gate2 * inn2 * (x_est - lm2_x_map) / (r_pred2 + eps) +
    gate3 * inn3 * (x_est - lm3_x_map) / (r_pred3 + eps) +
    gate4 * inn4 * (x_est - lm4_x_map) / (r_pred4 + eps) +
    gate5 * inn5 * (x_est - lm5_x_map) / (r_pred5 + eps) +
    gate6 * inn6 * (x_est - lm6_x_map) / (r_pred6 + eps));
  corr_y = K_range * (
    gate1 * inn1 * (y_est - lm1_y_map) / (r_pred1 + eps) +
    gate2 * inn2 * (y_est - lm2_y_map) / (r_pred2 + eps) +
    gate3 * inn3 * (y_est - lm3_y_map) / (r_pred3 + eps) +
    gate4 * inn4 * (y_est - lm4_y_map) / (r_pred4 + eps) +
    gate5 * inn5 * (y_est - lm5_y_map) / (r_pred5 + eps) +
    gate6 * inn6 * (y_est - lm6_y_map) / (r_pred6 + eps));

  // ===== Loop-Closure Detection and Correction =====
  loop_closure_detected = (time > 0.75 * T_end) and
    (sqrt((x_est - R_route) * (x_est - R_route) + y_est * y_est + eps) < 2.0);
  lc_pos_err = sqrt((x_est - R_route) * (x_est - R_route) + y_est * y_est + eps);
  lc_theta_err = theta_est - (2.0 * pi + pi / 2.0);
  lc_corr_x = if loop_closure_detected then K_lc * (R_route - x_est) else 0.0;
  lc_corr_y = if loop_closure_detected then K_lc * (0.0 - y_est) else 0.0;
  lc_corr_theta = if loop_closure_detected then K_lc * (2.0 * pi + pi / 2.0 - theta_est) else 0.0;

  // ===== Covariance Propagation =====
  der(P11) = Q_pos - alpha_corr * P11 - alpha_lc * P11 * (if loop_closure_detected then 1.0 else 0.0);
  der(P22) = Q_pos - alpha_corr * P22 - alpha_lc * P22 * (if loop_closure_detected then 1.0 else 0.0);
  der(P33) = Q_theta - alpha_corr * P33 - alpha_lc * P33 * (if loop_closure_detected then 1.0 else 0.0);
  der(P44) = Q_vel - alpha_corr * P44;
  der(P55) = Q_omega - alpha_corr * P55;
  cov_trace = P11 + P22 + P33 + P44 + P55;

  // ===== Collision Detection =====
  dist_obs1 = sqrt((x - obs1_x) * (x - obs1_x) + (y - obs1_y) * (y - obs1_y) + eps);
  dist_obs2 = sqrt((x - obs2_x) * (x - obs2_x) + (y - obs2_y) * (y - obs2_y) + eps);
  collision = (dist_obs1 < obs1_r) or (dist_obs2 < obs2_r);

  // ===== Validation Flags =====
  cov_finite = (P11 > 0.0) and (P11 < 1.0e6) and
               (P22 > 0.0) and (P22 < 1.0e6) and
               (P33 > 0.0) and (P33 < 1.0e6) and
               (P44 > 0.0) and (P44 < 1.0e6) and
               (P55 > 0.0) and (P55 < 1.0e6);
  no_nan_inf = (abs(x) < 1.0e10) and (abs(y) < 1.0e10) and
               (abs(theta) < 1.0e10) and (abs(v) < 1.0e10) and
               (abs(omega) < 1.0e10) and
               (abs(x_est) < 1.0e10) and (abs(y_est) < 1.0e10) and
               (abs(theta_est) < 1.0e10) and (abs(v_est) < 1.0e10) and
               (abs(omega_est) < 1.0e10) and
               (abs(tau_L_cmd) < 1.0e10) and (abs(tau_R_cmd) < 1.0e10) and
               (abs(tau_L_act) < 1.0e10) and (abs(tau_R_act) < 1.0e10) and
               (abs(P11) < 1.0e10) and (abs(P22) < 1.0e10) and
               (abs(P33) < 1.0e10) and (abs(P44) < 1.0e10) and
               (abs(P55) < 1.0e10) and (abs(cov_trace) < 1.0e10);
  output_rate = f_sample;

  // ===== Capture Tracking Error at t = 10.4 s =====
  when time >= 10.4 then
    tracking_error_104 = sqrt((x - x_ref) * (x - x_ref) + (y - y_ref) * (y - y_ref));
  end when;

  annotation(
    experiment(StartTime = 0, StopTime = 16.0, Tolerance = 1.0e-6, Interval = 0.004),
    Documentation(info = "<html>
<p><b>WheelIMUMapE</b>: Differential-drive robotic sensing and estimation system.</p>
<p>Plant: 16 kg chassis, wheel encoders, center 6-axis IMU, two wheel-torque actuators (11 N.m bound).</p>
<p>Estimation: fused odometry + IMU + range with loop-closure correction; camera/sonar preserved separately.</p>
<p>World: 6 landmarks, 2 obstacles. 0.24 m landmark perturbation during middle third.</p>
<p>Run: 250 Hz, 16 s. Acceptance: finite covariance, loop-closure errors, output rate, no collision,
tracking error below 0.225 m at 10.4 s, no NaN/Inf. Fail-closed on collision.</p>
</html>")
  );
end WheelIMUMapE;