model WheelIMUMapD
  "Instrumented robotic sensing and estimation: differential drive fusing odometry, IMU, and range updates with loop closure";

  // ===== Time schedule =====
  parameter Real T_end = 14.0 "s, total run duration";
  parameter Real f_rate = 200.0 "Hz, declared output rate";
  parameter Real t_mid1 = T_end/3.0 "s, start of middle third";
  parameter Real t_mid2 = 2.0*T_end/3.0 "s, end of middle third";
  parameter Real t_closure = T_end - 1.0 "s, loop-closure activation time";
  parameter Real perturbation = 0.2 "m, controlled landmark perturbation";

  // ===== Robot embodiment =====
  parameter Real m = 16.0 "kg, chassis mass";
  parameter Real r_wheel = 0.08 "m, wheel radius";
  parameter Real L_wheel = 0.40 "m, wheelbase";
  parameter Real I_z = 1.2 "kg.m2, yaw inertia";
  parameter Real c_drag = 2.0 "N.s/m, linear drag";
  parameter Real c_yaw_drag = 0.8 "N.m.s, yaw drag";
  parameter Real tau_max = 10.0 "N.m, per-wheel torque limit";

  // ===== Reference path (closed circle, one loop in T_end) =====
  parameter Real R_path = 1.5 "m, path radius";
  parameter Real w_ref = 2.0*Modelica.Constants.pi/T_end "rad/s, reference yaw rate";
  parameter Real v_ff = R_path*w_ref "m/s, feedforward speed";
  parameter Real omega_ff = w_ref "rad/s, feedforward yaw rate";
  parameter Real x_start = R_path "m";
  parameter Real y_start = 0.0 "m";
  parameter Real theta_start = Modelica.Constants.pi/2 "rad, initial heading";

  // ===== World: landmarks and obstacles =====
  parameter Real lm_x[6] = {2.5, 1.0, -1.5, -2.5, -1.0, 1.5} "m";
  parameter Real lm_y[6] = {1.5, 2.5, 2.0, -1.5, -2.5, -2.0} "m";
  parameter Real obs_x[2] = {0.0, 3.2} "m";
  parameter Real obs_y[2] = {0.0, 1.8} "m";
  parameter Real obs_r[2] = {0.5, 0.4} "m";
  parameter Real robot_radius = 0.20 "m";

  // ===== IMU parameters (six-axis, center-mounted) =====
  parameter Real imu_accel_bias_x = 0.02 "m/s2, accel bias x";
  parameter Real imu_accel_bias_y = 0.01 "m/s2, accel bias y";
  parameter Real imu_accel_bias_z = 0.0 "m/s2, accel bias z";
  parameter Real imu_gyro_bias_x = 0.0 "rad/s, gyro bias x";
  parameter Real imu_gyro_bias_y = 0.0 "rad/s, gyro bias y";
  parameter Real imu_gyro_bias_z = 0.005 "rad/s, gyro bias z";
  parameter Real imu_accel_noise = 0.05 "m/s2, accel noise amplitude";
  parameter Real imu_gyro_noise = 0.01 "rad/s, gyro noise amplitude";

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

  // ===== Covariance parameters (scalar diagonal) =====
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
  Real x(start=x_start) "m";
  Real y(start=y_start) "m";
  Real theta(start=theta_start) "rad";
  Real v(start=v_ff) "m/s";
  Real omega(start=omega_ff) "rad/s";
  Real omega_L "rad/s, left wheel angular velocity";
  Real omega_R "rad/s, right wheel angular velocity";

  // ===== Actuators =====
  Real tau_L_cmd "N.m";
  Real tau_R_cmd "N.m";
  Real tau_L "N.m, limited";
  Real tau_R "N.m, limited";
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
  Real tracking_error "m, primary position tracking error vs reference";

  // ===== IMU six-axis =====
  Real imu_ax "m/s2, body x accel";
  Real imu_ay "m/s2, body y accel";
  Real imu_az "m/s2, body z accel";
  Real imu_wx "rad/s";
  Real imu_wy "rad/s";
  Real imu_wz "rad/s";

  // ===== Odometry =====
  Real odom_v "m/s";
  Real odom_omega "rad/s";

  // ===== Range (fused) and raw exteroceptive preserved separately =====
  Real range_meas[6] "m, fused range updates";
  Real raw_camera[6] "m, preserved raw camera-like ranges";
  Real raw_sonar[6] "m, preserved raw sonar-like ranges";

  // ===== Landmark perturbation =====
  Real perturbation_active;
  Real lm_eff_x[6] "m, effective (possibly perturbed) landmark x for measurement";
  Real lm_eff_y[6] "m, effective (possibly perturbed) landmark y for measurement";

  // ===== Estimator =====
  Real est_x(start=x_start) "m";
  Real est_y(start=y_start) "m";
  Real est_theta(start=theta_start) "rad";
  Real est_v(start=v_ff) "m/s";
  Real est_omega(start=omega_ff) "rad/s";
  Real r_pred[6] "m, predicted ranges";
  Real residual[6] "m, range residuals";
  Real corr_x "m/s, range correction to est_x";
  Real corr_y "m/s, range correction to est_y";

  // ===== Covariance (scalar diagonal states, finite) =====
  Real P11(start=0.01);
  Real P22(start=0.01);
  Real P33(start=0.001);
  Real P44(start=0.1);
  Real P55(start=0.1);
  Real covariance_trace;

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
  output Real covariance_trace_out = covariance_trace;
  output Real output_rate_Hz = f_rate;

equation
  // ===== Reference path (closed circle, one loop in T_end) =====
  x_ref = R_path*Modelica.Math.cos(w_ref*time);
  y_ref = R_path*Modelica.Math.sin(w_ref*time);
  theta_ref = w_ref*time + Modelica.Constants.pi/2;

  // ===== Path-frame errors =====
  along_err = Modelica.Math.cos(theta_ref)*(x - x_ref) + Modelica.Math.sin(theta_ref)*(y - y_ref);
  cross_err = -Modelica.Math.sin(theta_ref)*(x - x_ref) + Modelica.Math.cos(theta_ref)*(y - y_ref);
  head_err = theta - theta_ref;

  // ===== Commands =====
  v_cmd = v_ff - K_track_along*along_err;
  omega_cmd = omega_ff - K_track_cross*cross_err - K_track_head*head_err;

  // ===== Desired forces/moment with drag feedforward =====
  F_des = Kp_v*(v_cmd - v) + c_drag*v;
  M_des = Kp_w*(omega_cmd - omega) + c_yaw_drag*omega;

  // ===== Distribute to wheels =====
  F_L_cmd = F_des/2.0 - M_des/L_wheel;
  F_R_cmd = F_des/2.0 + M_des/L_wheel;
  tau_L_cmd = F_L_cmd*r_wheel;
  tau_R_cmd = F_R_cmd*r_wheel;

  // ===== Torque saturation (10 N.m per wheel) =====
  tau_L = if tau_L_cmd > tau_max then tau_max elseif tau_L_cmd < -tau_max then -tau_max else tau_L_cmd;
  tau_R = if tau_R_cmd > tau_max then tau_max elseif tau_R_cmd < -tau_max then -tau_max else tau_R_cmd;

  // ===== Robot dynamics =====
  der(x) = v*Modelica.Math.cos(theta);
  der(y) = v*Modelica.Math.sin(theta);
  der(theta) = omega;
  der(v) = (tau_L + tau_R)/r_wheel/m - c_drag*v/m;
  der(omega) = ((tau_R - tau_L)/r_wheel)*(L_wheel/2.0)/I_z - c_yaw_drag*omega/I_z;

  // ===== Wheel angular velocities (for odometry) =====
  omega_L = (v - omega*L_wheel/2.0)/r_wheel;
  omega_R = (v + omega*L_wheel/2.0)/r_wheel;

  // ===== IMU six-axis (center-mounted) =====
  imu_ax = (tau_L + tau_R)/r_wheel/m - c_drag*v/m + imu_accel_bias_x + imu_accel_noise*Modelica.Math.sin(13.0*time);
  imu_ay = -omega*v + imu_accel_bias_y + imu_accel_noise*0.5*Modelica.Math.cos(7.0*time);
  imu_az = imu_accel_bias_z;
  imu_wx = imu_gyro_bias_x;
  imu_wy = imu_gyro_bias_y;
  imu_wz = omega + imu_gyro_bias_z + imu_gyro_noise*Modelica.Math.sin(17.0*time);

  // ===== Odometry (wheel encoder fusion) =====
  odom_v = r_wheel*(omega_L + omega_R)/2.0;
  odom_omega = r_wheel*(omega_R - omega_L)/L_wheel;

  // ===== Landmark perturbation (controlled disturbance during middle third) =====
  perturbation_active = if (time >= t_mid1) and (time <= t_mid2) then 1.0 else 0.0;

  // ===== Range measurements and raw exteroceptive preservation =====
  lm_eff_x[1] = lm_x[1] + perturbation_active*perturbation;
  lm_eff_y[1] = lm_y[1];
  lm_eff_x[2] = lm_x[2] + perturbation_active*perturbation;
  lm_eff_y[2] = lm_y[2];
  lm_eff_x[3] = lm_x[3] + perturbation_active*perturbation;
  lm_eff_y[3] = lm_y[3];
  lm_eff_x[4] = lm_x[4] + perturbation_active*perturbation;
  lm_eff_y[4] = lm_y[4];
  lm_eff_x[5] = lm_x[5] + perturbation_active*perturbation;
  lm_eff_y[5] = lm_y[5];
  lm_eff_x[6] = lm_x[6] + perturbation_active*perturbation;
  lm_eff_y[6] = lm_y[6];

  range_meas[1] = Modelica.Math.sqrt((x - lm_eff_x[1])^2 + (y - lm_eff_y[1])^2 + 1.0e-6) + range_noise*Modelica.Math.sin(11.0*time) + range_bias;
  range_meas[2] = Modelica.Math.sqrt((x - lm_eff_x[2])^2 + (y - lm_eff_y[2])^2 + 1.0e-6) + range_noise*Modelica.Math.sin(16.0*time) + range_bias;
  range_meas[3] = Modelica.Math.sqrt((x - lm_eff_x[3])^2 + (y - lm_eff_y[3])^2 + 1.0e-6) + range_noise*Modelica.Math.sin(19.0*time) + range_bias;
  range_meas[4] = Modelica.Math.sqrt((x - lm_eff_x[4])^2 + (y - lm_eff_y[4])^2 + 1.0e-6) + range_noise*Modelica.Math.sin(23.0*time) + range_bias;
  range_meas[5] = Modelica.Math.sqrt((x - lm_eff_x[5])^2 + (y - lm_eff_y[5])^2 + 1.0e-6) + range_noise*Modelica.Math.sin(29.0*time) + range_bias;
  range_meas[6] = Modelica.Math.sqrt((x - lm_eff_x[6])^2 + (y - lm_eff_y[6])^2 + 1.0e-6) + range_noise*Modelica.Math.sin(31.0*time) + range_bias;

  raw_camera[1] = Modelica.Math.sqrt((x - lm_eff_x[1])^2 + (y - lm_eff_y[1])^2 + 1.0e-6) + range_noise*0.5*Modelica.Math.sin(8.0*time);
  raw_camera[2] = Modelica.Math.sqrt((x - lm_eff_x[2])^2 + (y - lm_eff_y[2])^2 + 1.0e-6) + range_noise*0.5*Modelica.Math.sin(11.0*time);
  raw_camera[3] = Modelica.Math.sqrt((x - lm_eff_x[3])^2 + (y - lm_eff_y[3])^2 + 1.0e-6) + range_noise*0.5*Modelica.Math.sin(14.0*time);
  raw_camera[4] = Modelica.Math.sqrt((x - lm_eff_x[4])^2 + (y - lm_eff_y[4])^2 + 1.0e-6) + range_noise*0.5*Modelica.Math.sin(17.0*time);
  raw_camera[5] = Modelica.Math.sqrt((x - lm_eff_x[5])^2 + (y - lm_eff_y[5])^2 + 1.0e-6) + range_noise*0.5*Modelica.Math.sin(19.0*time);
  raw_camera[6] = Modelica.Math.sqrt((x - lm_eff_x[6])^2 + (y - lm_eff_y[6])^2 + 1.0e-6) + range_noise*0.5*Modelica.Math.sin(23.0*time);

  raw_sonar[1] = Modelica.Math.sqrt((x - lm_eff_x[1])^2 + (y - lm_eff_y[1])^2 + 1.0e-6) + range_noise*0.8*Modelica.Math.sin(6.0*time);
  raw_sonar[2] = Modelica.Math.sqrt((x - lm_eff_x[2])^2 + (y - lm_eff_y[2])^2 + 1.0e-6) + range_noise*0.8*Modelica.Math.sin(10.0*time);
  raw_sonar[3] = Modelica.Math.sqrt((x - lm_eff_x[3])^2 + (y - lm_eff_y[3])^2 + 1.0e-6) + range_noise*0.8*Modelica.Math.sin(12.0*time);
  raw_sonar[4] = Modelica.Math.sqrt((x - lm_eff_x[4])^2 + (y - lm_eff_y[4])^2 + 1.0e-6) + range_noise*0.8*Modelica.Math.sin(16.0*time);
  raw_sonar[5] = Modelica.Math.sqrt((x - lm_eff_x[5])^2 + (y - lm_eff_y[5])^2 + 1.0e-6) + range_noise*0.8*Modelica.Math.sin(20.0*time);
  raw_sonar[6] = Modelica.Math.sqrt((x - lm_eff_x[6])^2 + (y - lm_eff_y[6])^2 + 1.0e-6) + range_noise*0.8*Modelica.Math.sin(26.0*time);

  // ===== Estimator predicted ranges (uses nominal landmark positions) =====
  r_pred[1] = Modelica.Math.sqrt((est_x - lm_x[1])^2 + (est_y - lm_y[1])^2 + 1.0e-6);
  r_pred[2] = Modelica.Math.sqrt((est_x - lm_x[2])^2 + (est_y - lm_y[2])^2 + 1.0e-6);
  r_pred[3] = Modelica.Math.sqrt((est_x - lm_x[3])^2 + (est_y - lm_y[3])^2 + 1.0e-6);
  r_pred[4] = Modelica.Math.sqrt((est_x - lm_x[4])^2 + (est_y - lm_y[4])^2 + 1.0e-6);
  r_pred[5] = Modelica.Math.sqrt((est_x - lm_x[5])^2 + (est_y - lm_y[5])^2 + 1.0e-6);
  r_pred[6] = Modelica.Math.sqrt((est_x - lm_x[6])^2 + (est_y - lm_y[6])^2 + 1.0e-6);

  residual[1] = range_meas[1] - r_pred[1];
  residual[2] = range_meas[2] - r_pred[2];
  residual[3] = range_meas[3] - r_pred[3];
  residual[4] = range_meas[4] - r_pred[4];
  residual[5] = range_meas[5] - r_pred[5];
  residual[6] = range_meas[6] - r_pred[6];

  // ===== Range corrections (gradient descent on residual sum of squares) =====
  corr_x = K_range_corr * (
    residual[1]*(est_x - lm_x[1])/r_pred[1] +
    residual[2]*(est_x - lm_x[2])/r_pred[2] +
    residual[3]*(est_x - lm_x[3])/r_pred[3] +
    residual[4]*(est_x - lm_x[4])/r_pred[4] +
    residual[5]*(est_x - lm_x[5])/r_pred[5] +
    residual[6]*(est_x - lm_x[6])/r_pred[6]);
  corr_y = K_range_corr * (
    residual[1]*(est_y - lm_y[1])/r_pred[1] +
    residual[2]*(est_y - lm_y[2])/r_pred[2] +
    residual[3]*(est_y - lm_y[3])/r_pred[3] +
    residual[4]*(est_y - lm_y[4])/r_pred[4] +
    residual[5]*(est_y - lm_y[5])/r_pred[5] +
    residual[6]*(est_y - lm_y[6])/r_pred[6]);

  // ===== Loop closure =====
  closure_active = if time >= t_closure then 1.0 else 0.0;
  loop_pos_error = Modelica.Math.sqrt((est_x - x_start)^2 + (est_y - y_start)^2 + 1.0e-9);
  loop_heading_error = est_theta - theta_ref;

  // ===== Estimator dynamics (fuse odometry + IMU + range + loop closure) =====
  der(est_v) = K_fuse*(odom_v - est_v) + K_imu_accel*(imu_ax - imu_accel_bias_x);
  der(est_omega) = K_fuse*(odom_omega - est_omega) + K_imu*((imu_wz - imu_gyro_bias_z) - est_omega);
  der(est_x) = est_v*Modelica.Math.cos(est_theta) + corr_x + closure_active*K_closure*(x_start - est_x);
  der(est_y) = est_v*Modelica.Math.sin(est_theta) + corr_y + closure_active*K_closure*(y_start - est_y);
  der(est_theta) = est_omega + closure_active*K_closure*(theta_ref - est_theta);

  // ===== Covariance (scalar diagonal, finite, stable) =====
  der(P11) = Q1 - (beta1 + K_range_corr*0.5 + closure_active*K_closure)*P11;
  der(P22) = Q2 - (beta2 + K_range_corr*0.5 + closure_active*K_closure)*P22;
  der(P33) = Q3 - (beta3 + closure_active*K_closure)*P33;
  der(P44) = Q4 - beta4*P44;
  der(P55) = Q5 - beta5*P55;
  covariance_trace = P11 + P22 + P33 + P44 + P55;

  // ===== Collision check =====
  dist_obs1 = Modelica.Math.sqrt((x - obs_x[1])^2 + (y - obs_y[1])^2 + 1.0e-9);
  dist_obs2 = Modelica.Math.sqrt((x - obs_x[2])^2 + (y - obs_y[2])^2 + 1.0e-9);
  collision_flag = if (dist_obs1 < robot_radius + obs_r[1]) or (dist_obs2 < robot_radius + obs_r[2]) then 1.0 else 0.0;

  // ===== Tracking error (primary position error vs reference) =====
  tracking_error = Modelica.Math.sqrt((x - x_ref)^2 + (y - y_ref)^2 + 1.0e-9);

  annotation (
    experiment(StopTime=14.0, Tolerance=1e-6, Interval=0.005),
    Documentation(info="WheelIMUMapD: differential-drive (16 kg) with wheel encoders, six-axis IMU, and range fusion. Closed circular route traversed in 14 s at 200 Hz output. Six fixed landmarks and two obstacles in shared world frame. Controlled 0.2 m landmark perturbation applied during middle third. Pose filtering with loop-closure correction in the final second. Raw camera and sonar traces preserved separately.")
  );
end WheelIMUMapD;