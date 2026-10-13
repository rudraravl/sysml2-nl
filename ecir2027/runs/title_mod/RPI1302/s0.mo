model MarineNavLocalizeF
  "Marine underwater vehicle navigation and localization with EKF,
   asynchronous multi-rate sensors, bias estimation, and bounded route following."

  // ===== Constants =====
  constant Real pi = 3.14159265358979323846;

  // ===== Timing =====
  parameter Real dt_sim = 0.002 "Simulation step [s] (500 Hz)";
  parameter Real T_end = 20.0 "Mission duration [s]";

  // ===== Vehicle parameters =====
  parameter Real m_vehicle = 100.0 "Vehicle mass [kg]";
  parameter Real Iz_vehicle = 50.0 "Yaw moment of inertia [kg.m2]";
  parameter Real d_lin = 20.0 "Linear drag coefficient [N.s/m]";
  parameter Real d_ang = 8.0 "Angular drag coefficient [N.m.s/rad]";
  parameter Real thruster_arm = 0.5 "Thruster moment arm [m]";

  // ===== Actuator limit =====
  parameter Real Fmax = 128.0 "Maximum thrust per thruster [N]";

  // ===== Bounded route reference =====
  parameter Real route_amp_x = 7.0 "Route x amplitude [m]";
  parameter Real route_amp_y = 5.0 "Route y amplitude [m]";
  parameter Real route_depth_nom = 2.0 "Nominal operating depth [m]";
  parameter Real route_amp_z = 0.5 "Depth variation amplitude [m]";

  // ===== Fixed landmarks (external references, no ground truth to estimator) =====
  parameter Real lm1_x = 15.0 "Landmark 1 x [m]";
  parameter Real lm1_y = 15.0 "Landmark 1 y [m]";
  parameter Real lm1_z = 0.0 "Landmark 1 z [m]";
  parameter Real lm2_x = -5.0 "Landmark 2 x [m]";
  parameter Real lm2_y = 10.0 "Landmark 2 y [m]";
  parameter Real lm2_z = 0.0 "Landmark 2 z [m]";

  // ===== Sensor extrinsic transforms (body-frame to sensor-frame offsets) =====
  parameter Real imu_ex_x = 0.10 "IMU x offset [m]";
  parameter Real imu_ex_y = 0.0  "IMU y offset [m]";
  parameter Real imu_ex_z = 0.05 "IMU z offset [m]";
  parameter Real dvl_ex_x = -0.10 "DVL x offset [m]";
  parameter Real dvl_ex_y = 0.0   "DVL y offset [m]";
  parameter Real dvl_ex_z = -0.10 "DVL z offset [m]";
  parameter Real depth_ex_z = 0.0 "Pressure sensor z offset [m]";
  parameter Real compass_ex_z = 0.0 "Compass z offset [m]";
  parameter Real acous1_ex_x = 0.20 "Acoustic sensor 1 x offset [m]";
  parameter Real acous1_ex_y = 0.0  "Acoustic sensor 1 y offset [m]";
  parameter Real acous1_ex_z = 0.0  "Acoustic sensor 1 z offset [m]";
  parameter Real acous2_ex_x = -0.20 "Acoustic sensor 2 x offset [m]";
  parameter Real acous2_ex_y = 0.0   "Acoustic sensor 2 y offset [m]";
  parameter Real acous2_ex_z = 0.0   "Acoustic sensor 2 z offset [m]";

  // ===== Sensor standard deviations =====
  parameter Real sigma_imu_acc = 0.05 "IMU accelerometer std [m/s2]";
  parameter Real sigma_imu_gyro = 0.001 "IMU gyroscope std [rad/s]";
  parameter Real sigma_depth = 0.02 "Pressure depth std [m]";
  parameter Real sigma_dvl = 0.02 "Doppler velocity std [m/s]";
  parameter Real sigma_compass = 0.01 "Compass heading std [rad]";
  parameter Real sigma_acous = 0.10 "Acoustic range std [m]";

  // ===== Sensor rates [Hz] =====
  parameter Real rate_imu = 500.0 "IMU rate [Hz]";
  parameter Real rate_depth = 100.0 "Pressure depth rate [Hz]";
  parameter Real rate_dvl = 10.0 "Doppler velocity log rate [Hz]";
  parameter Real rate_compass = 50.0 "Compass rate [Hz]";
  parameter Real rate_acous = 1.0 "Acoustic range rate [Hz]";

  // ===== Bias step disturbance (middle third of mission) =====
  parameter Real bias_step_mag = 0.058 "Sensor-bias step magnitude [m/s2]";
  parameter Real bias_step_start = T_end / 3.0 "Step start [s]";
  parameter Real bias_step_end = 2.0 * T_end / 3.0 "Step end [s]";

  // ===== EKF process noise rates =====
  parameter Real Q_pos = 1e-4 "Position process noise [m2/s]";
  parameter Real Q_vel = 1e-4 "Velocity process noise [(m/s)2/s]";
  parameter Real Q_psi = 1e-5 "Heading process noise [rad2/s]";
  parameter Real Q_bacc = 1e-4 "Accel bias process noise [(m/s2)2/s]";
  parameter Real Q_bgyro = 1e-6 "Gyro bias process noise [(rad/s)2/s]";
  parameter Real Q_bdvl = 1e-6 "DVL bias process noise [(m/s)2/s]";
  parameter Real Q_bdepth = 1e-6 "Depth bias process noise [m2/s]";
  parameter Real Q_bcompass = 1e-6 "Compass bias process noise [rad2/s]";

  // ===== Reference trajectory =====
  Real x_ref "Reference x [m]";
  Real y_ref "Reference y [m]";
  Real z_ref "Reference z [m]";
  Real vx_ref "Reference x-velocity [m/s]";
  Real vy_ref "Reference y-velocity [m/s]";
  Real vz_ref "Reference z-velocity [m/s]";
  Real psi_ref "Reference heading [rad]";

  // ===== True vehicle state =====
  Real x(start=0.0, fixed=true) "True x [m]";
  Real y(start=0.0, fixed=true) "True y [m]";
  Real z(start=0.0, fixed=true) "True z [m]";
  Real psi(start=0.0, fixed=true) "True heading [rad]";
  Real u(start=0.0, fixed=true) "True surge [m/s]";
  Real v(start=0.0, fixed=true) "True sway [m/s]";
  Real w(start=0.0, fixed=true) "True heave [m/s]";
  Real omega(start=0.0, fixed=true) "True yaw rate [rad/s]";
  Real ax_body "True body-x acceleration [m/s2]";
  Real ay_body "True body-y acceleration [m/s2]";
  Real az_body "True body-z acceleration [m/s2]";
  Real alpha_z "True angular acceleration [rad/s2]";

  // ===== Actuation =====
  Real F1_cmd "Thruster 1 command [N]";
  Real F2_cmd "Thruster 2 command [N]";
  Real F3_cmd "Thruster 3 command [N]";
  Real F4_cmd "Thruster 4 command [N]";
  Real F1 "Thruster 1 force (saturated) [N]";
  Real F2 "Thruster 2 force (saturated) [N]";
  Real F3 "Thruster 3 force (saturated) [N]";
  Real F4 "Thruster 4 force (saturated) [N]";
  Real F_surge "Allocated surge force [N]";
  Real F_heave "Allocated heave force [N]";
  Real M_yaw "Allocated yaw moment [N.m]";

  // ===== True sensor biases (disturbance injected into plant) =====
  Real b_accel_true "True accelerometer bias [m/s2]";
  Real b_gyro_true "True gyro bias [rad/s]";

  // ===== Sensor measurements =====
  // IMU — frame: body, rate: 500 Hz
  Real imu_ax_m "IMU x-accel measurement [m/s2]";
  Real imu_ay_m "IMU y-accel measurement [m/s2]";
  Real imu_az_m "IMU z-accel measurement [m/s2]";
  Real imu_wz_m "IMU z-gyro measurement [rad/s]";
  // Pressure depth — frame: world-z (down positive), rate: 100 Hz
  Real depth_m "Depth measurement [m]";
  // DVL — frame: body, rate: 10 Hz
  Real dvl_u_m "DVL surge measurement [m/s]";
  Real dvl_v_m "DVL sway measurement [m/s]";
  Real dvl_w_m "DVL heave measurement [m/s]";
  // Compass — frame: world heading, rate: 50 Hz
  Real compass_m "Compass heading measurement [rad]";
  // Acoustic range — frame: world, rate: 1 Hz
  Real range1_m "Acoustic range to landmark 1 [m]";
  Real range2_m "Acoustic range to landmark 2 [m]";

  // ===== Sensor timestamps =====
  discrete Real t_stamp_depth(start=0.0) "Last depth update [s]";
  discrete Real t_stamp_dvl(start=0.0) "Last DVL update [s]";
  discrete Real t_stamp_compass(start=0.0) "Last compass update [s]";
  discrete Real t_stamp_acous1(start=0.0) "Last acoustic-1 update [s]";
  discrete Real t_stamp_acous2(start=0.0) "Last acoustic-2 update [s]";

  // ===== EKF estimated state =====
  Real xh(start=0.0, fixed=true) "Estimated x [m]";
  Real yh(start=0.0, fixed=true) "Estimated y [m]";
  Real zh(start=0.0, fixed=true) "Estimated z [m]";
  Real psih(start=0.001, fixed=true) "Estimated heading [rad]";
  Real uh(start=0.0, fixed=true) "Estimated surge [m/s]";
  Real vh(start=0.0, fixed=true) "Estimated sway [m/s]";
  Real wh(start=0.0, fixed=true) "Estimated heave [m/s]";
  Real omegah(start=0.0, fixed=true) "Estimated yaw rate [rad/s]";
  // Estimated sensor bias states
  Real b_acc_h(start=0.0, fixed=true) "Estimated accel bias [m/s2]";
  Real b_gyro_h(start=0.0, fixed=true) "Estimated gyro bias [rad/s]";
  Real b_dvl_h(start=0.0, fixed=true) "Estimated DVL bias [m/s]";
  Real b_depth_h(start=0.0, fixed=true) "Estimated depth bias [m]";
  Real b_compass_h(start=0.0, fixed=true) "Estimated compass bias [rad]";

  // ===== EKF covariance (diagonal + key cross terms) =====
  Real P_x(start=1.0, fixed=true);
  Real P_y(start=1.0, fixed=true);
  Real P_z(start=1.0, fixed=true);
  Real P_psi(start=0.1, fixed=true);
  Real P_u(start=1.0, fixed=true);
  Real P_v(start=1.0, fixed=true);
  Real P_w(start=1.0, fixed=true);
  Real P_bacc(start=1.0, fixed=true);
  Real P_bgyro(start=0.1, fixed=true);
  Real P_bdvl(start=0.1, fixed=true);
  Real P_bdepth(start=0.1, fixed=true);
  Real P_bcompass(start=0.1, fixed=true);
  Real P_xu(start=0.0, fixed=true);
  Real P_yv(start=0.0, fixed=true);
  Real P_zw(start=0.0, fixed=true);
  Real P_u_bacc(start=0.0, fixed=true);
  Real P_omega_bgyro(start=0.0, fixed=true);

  // ===== EKF update intermediates (continuous, sampled in when blocks) =====
  Real res_depth, S_depth, K_z_depth, K_bdepth_depth;
  Real res_compass, S_compass, K_psi_comp, K_bcompass_comp;
  Real res_dvl, S_dvl, K_u_dvl, K_bdvl_dvl, K_bacc_dvl;
  Real pred_range1, H_x1, H_y1, H_z1, res_acous1, S_acous1, K_x1, K_y1, K_z1;
  Real pred_range2, H_x2, H_y2, H_z2, res_acous2, S_acous2, K_x2, K_y2, K_z2;

  // ===== Controller intermediates =====
  Real psi_err_ctrl, psi_err_wrap_ctrl;
  Real err_pos_body_x, err_pos_body_y;
  Real vx_ref_body, vy_ref_body;

  // ===== Pseudo-noise (deterministic, avoids RNG for FMU reproducibility) =====
  Real n_acc, n_gyro, n_depth, n_dvl, n_compass, n_acous1, n_acous2;

  // ===== Acoustic sensor world-frame positions =====
  Real ac1_wx, ac1_wy, ac1_wz;
  Real ac2_wx, ac2_wy, ac2_wz;

  // ===== Verification outputs =====
  Real err_x "Estimation error x [m]";
  Real err_y "Estimation error y [m]";
  Real err_z "Estimation error z [m]";
  Real err_psi "Estimation error heading [rad]";
  Real err_u "Estimation error surge [m/s]";
  Real tracking_error "Primary tracking (estimation) error [m]";
  Real pos_error_band "Position error band [m]";
  Real att_error_band "Attitude error band [rad]";
  Real cov_min_val "Minimum diagonal covariance";
  Boolean cov_positive "All diagonal covariances positive";
  Boolean within_band "Errors within tolerance bands";
  Boolean bias_converged "Bias estimate converged to true bias";
  Boolean tracking_ok "Tracking error < 0.16 after 13 s";
  Boolean actuator_ok "All thrusters within 128 N limit";
  Boolean no_nan_inf "No NaN or infinite values detected";
  Boolean all_verified "All verification criteria satisfied";
  Real finite_check "Sum for finiteness check";

equation
  // ================== Reference trajectory (bounded route) ==================
  x_ref = route_amp_x * sin(2.0 * pi * time / 20.0);
  y_ref = route_amp_y * sin(4.0 * pi * time / 20.0);
  z_ref = route_depth_nom + route_amp_z * sin(2.0 * pi * time / 10.0);
  vx_ref = route_amp_x * (2.0 * pi / 20.0) * cos(2.0 * pi * time / 20.0);
  vy_ref = route_amp_y * (4.0 * pi / 20.0) * cos(4.0 * pi * time / 20.0);
  vz_ref = route_amp_z * (2.0 * pi / 10.0) * cos(2.0 * pi * time / 10.0);
  psi_ref = atan2(vy_ref, vx_ref);

  // ================== True vehicle dynamics ==================
  der(x) = cos(psi) * u - sin(psi) * v;
  der(y) = sin(psi) * u + cos(psi) * v;
  der(z) = w;
  der(psi) = omega;

  F_surge = F1 + F2;
  F_heave = F3 + F4;
  M_yaw = (F2 - F1) * thruster_arm;

  ax_body = (F_surge - d_lin * u) / m_vehicle;
  ay_body = (-d_lin * v) / m_vehicle;
  az_body = (F_heave - d_lin * w) / m_vehicle;
  alpha_z = (M_yaw - d_ang * omega) / Iz_vehicle;

  der(u) = ax_body;
  der(v) = ay_body;
  der(w) = az_body;
  der(omega) = alpha_z;

  // ================== Actuator saturation (<= 128 N per thruster) ==================
  F1 = if F1_cmd > Fmax then Fmax elseif F1_cmd < -Fmax then -Fmax else F1_cmd;
  F2 = if F2_cmd > Fmax then Fmax elseif F2_cmd < -Fmax then -Fmax else F2_cmd;
  F3 = if F3_cmd > Fmax then Fmax elseif F3_cmd < -Fmax then -Fmax else F3_cmd;
  F4 = if F4_cmd > Fmax then Fmax elseif F4_cmd < -Fmax then -Fmax else F4_cmd;

  // ================== Controller (PD, uses estimated state only) ==================
  err_pos_body_x = cos(psih) * (x_ref - xh) + sin(psih) * (y_ref - yh);
  err_pos_body_y = -sin(psih) * (x_ref - xh) + cos(psih) * (y_ref - yh);
  vx_ref_body = cos(psih) * vx_ref + sin(psih) * vy_ref;
  vy_ref_body = -sin(psih) * vx_ref + cos(psih) * vy_ref;
  psi_err_ctrl = psi_ref - psih;
  psi_err_wrap_ctrl = if psi_err_ctrl > pi then psi_err_ctrl - 2.0 * pi
    elseif psi_err_ctrl < -pi then psi_err_ctrl + 2.0 * pi else psi_err_ctrl;

  F1_cmd = 30.0 * err_pos_body_x + 20.0 * (vx_ref_body - uh)
         - 40.0 * psi_err_wrap_ctrl - 10.0 * omegah;
  F2_cmd = 30.0 * err_pos_body_x + 20.0 * (vx_ref_body - uh)
         + 40.0 * psi_err_wrap_ctrl + 10.0 * omegah;
  F3_cmd = 100.0 * (z_ref - zh) + 30.0 * (vz_ref - wh);
  F4_cmd = 100.0 * (z_ref - zh) + 30.0 * (vz_ref - wh);

  // ================== Bias step disturbance (middle third) ==================
  b_accel_true = if (time >= bias_step_start and time <= bias_step_end) then bias_step_mag else 0.0;
  b_gyro_true = 0.0;

  // ================== Pseudo-noise signals ==================
  n_acc = sigma_imu_acc * sin(2.0 * pi * 13.0 * time + 1.0);
  n_gyro = sigma_imu_gyro * sin(2.0 * pi * 17.0 * time + 2.0);
  n_depth = sigma_depth * sin(2.0 * pi * 23.0 * time + 3.0);
  n_dvl = sigma_dvl * sin(2.0 * pi * 29.0 * time + 4.0);
  n_compass = sigma_compass * sin(2.0 * pi * 31.0 * time + 5.0);
  n_acous1 = sigma_acous * sin(2.0 * pi * 7.0 * time + 6.0);
  n_acous2 = sigma_acous * sin(2.0 * pi * 11.0 * time + 7.0);

  // ================== Sensor models ==================
  // IMU (body frame, 500 Hz) with extrinsic lever-arm
  imu_ax_m = ax_body - omega * omega * imu_ex_x + b_accel_true + n_acc;
  imu_ay_m = ay_body + alpha_z * imu_ex_x + n_acc * 0.5;
  imu_az_m = az_body + n_acc * 0.3;
  imu_wz_m = omega + b_gyro_true + n_gyro;

  // Pressure depth (world-z, 100 Hz)
  depth_m = z + depth_ex_z + n_depth;

  // DVL (body frame, 10 Hz) with extrinsic lever-arm
  dvl_u_m = u - omega * dvl_ex_y + n_dvl;
  dvl_v_m = v + omega * dvl_ex_x + n_dvl * 0.5;
  dvl_w_m = w + n_dvl * 0.3;

  // Compass (world heading, 50 Hz)
  compass_m = psi + compass_ex_z + n_compass;

  // Acoustic range (world frame, 1 Hz) with extrinsic offset
  ac1_wx = x + cos(psi) * acous1_ex_x - sin(psi) * acous1_ex_y;
  ac1_wy = y + sin(psi) * acous1_ex_x + cos(psi) * acous1_ex_y;
  ac1_wz = z + acous1_ex_z;
  range1_m = sqrt(max((ac1_wx - lm1_x) * (ac1_wx - lm1_x)
                    + (ac1_wy - lm1_y) * (ac1_wy - lm1_y)
                    + (ac1_wz - lm1_z) * (ac1_wz - lm1_z), 1e-10)) + n_acous1;

  ac2_wx = x + cos(psi) * acous2_ex_x - sin(psi) * acous2_ex_y;
  ac2_wy = y + sin(psi) * acous2_ex_x + cos(psi) * acous2_ex_y;
  ac2_wz = z + acous2_ex_z;
  range2_m = sqrt(max((ac2_wx - lm2_x) * (ac2_wx - lm2_x)
                    + (ac2_wy - lm2_y) * (ac2_wy - lm2_y)
                    + (ac2_wz - lm2_z) * (ac2_wz - lm2_z), 1e-10)) + n_acous2;

  // ================== EKF prediction (continuous, IMU-driven) ==================
  der(xh) = cos(psih) * uh - sin(psih) * vh;
  der(yh) = sin(psih) * uh + cos(psih) * vh;
  der(zh) = wh;
  der(psih) = omegah;
  der(uh) = imu_ax_m - b_acc_h;
  der(vh) = imu_ay_m;
  der(wh) = imu_az_m;
  der(omegah) = imu_wz_m - b_gyro_h;
  der(b_acc_h) = 0.0;
  der(b_gyro_h) = 0.0;
  der(b_dvl_h) = 0.0;
  der(b_depth_h) = 0.0;
  der(b_compass_h) = 0.0;

  // Covariance propagation (simplified Riccati for diagonal + cross terms)
  der(P_x) = 2.0 * P_xu + Q_pos;
  der(P_y) = 2.0 * P_yv + Q_pos;
  der(P_z) = 2.0 * P_zw + Q_pos;
  der(P_psi) = Q_psi;
  der(P_u) = Q_vel;
  der(P_v) = Q_vel;
  der(P_w) = Q_vel;
  der(P_bacc) = Q_bacc;
  der(P_bgyro) = Q_bgyro;
  der(P_bdvl) = Q_bdvl;
  der(P_bdepth) = Q_bdepth;
  der(P_bcompass) = Q_bcompass;
  der(P_xu) = P_u;
  der(P_yv) = P_v;
  der(P_zw) = P_w;
  der(P_u_bacc) = -P_bacc;
  der(P_omega_bgyro) = -P_bgyro;

  // ================== EKF update intermediates (continuous) ==================
  // Depth update (z and depth-bias)
  res_depth = depth_m - (zh + b_depth_h);
  S_depth = max(P_z + P_bdepth + sigma_depth * sigma_depth, 1e-10);
  K_z_depth = P_z / S_depth;
  K_bdepth_depth = P_bdepth / S_depth;

  // Compass update (heading and compass-bias), residual wrapped to [-pi,pi]
  res_compass = atan2(sin(compass_m - psih - b_compass_h),
                     cos(compass_m - psih - b_compass_h));
  S_compass = max(P_psi + P_bcompass + sigma_compass * sigma_compass, 1e-10);
  K_psi_comp = P_psi / S_compass;
  K_bcompass_comp = P_bcompass / S_compass;

  // DVL update (surge velocity, DVL-bias, and accel-bias via cross-covariance)
  res_dvl = dvl_u_m - (uh + b_dvl_h);
  S_dvl = max(P_u + P_bdvl + sigma_dvl * sigma_dvl, 1e-10);
  K_u_dvl = P_u / S_dvl;
  K_bdvl_dvl = P_bdvl / S_dvl;
  K_bacc_dvl = P_u_bacc / S_dvl;

  // Acoustic range 1 update (nonlinear, EKF Jacobian)
  pred_range1 = sqrt(max((xh - lm1_x) * (xh - lm1_x)
                       + (yh - lm1_y) * (yh - lm1_y)
                       + (zh - lm1_z) * (zh - lm1_z), 1e-10));
  H_x1 = (xh - lm1_x) / max(pred_range1, 1e-6);
  H_y1 = (yh - lm1_y) / max(pred_range1, 1e-6);
  H_z1 = (zh - lm1_z) / max(pred_range1, 1e-6);
  res_acous1 = range1_m - pred_range1;
  S_acous1 = max(H_x1 * H_x1 * P_x + H_y1 * H_y1 * P_y + H_z1 * H_z1 * P_z
               + sigma_acous * sigma_acous, 1e-10);
  K_x1 = P_x * H_x1 / S_acous1;
  K_y1 = P_y * H_y1 / S_acous1;
  K_z1 = P_z * H_z1 / S_acous1;

  // Acoustic range 2 update
  pred_range2 = sqrt(max((xh - lm2_x) * (xh - lm2_x)
                       + (yh - lm2_y) * (yh - lm2_y)
                       + (zh - lm2_z) * (zh - lm2_z), 1e-10));
  H_x2 = (xh - lm2_x) / max(pred_range2, 1e-6);
  H_y2 = (yh - lm2_y) / max(pred_range2, 1e-6);
  H_z2 = (zh - lm2_z) / max(pred_range2, 1e-6);
  res_acous2 = range2_m - pred_range2;
  S_acous2 = max(H_x2 * H_x2 * P_x + H_y2 * H_y2 * P_y + H_z2 * H_z2 * P_z
               + sigma_acous * sigma_acous, 1e-10);
  K_x2 = P_x * H_x2 / S_acous2;
  K_y2 = P_y * H_y2 / S_acous2;
  K_z2 = P_z * H_z2 / S_acous2;

  // ================== Asynchronous EKF updates (staggered when blocks) ==================

  // Depth sensor: 100 Hz, offset 1 ms
  when sample(0.001, 1.0 / rate_depth) then
    reinit(zh, zh + K_z_depth * res_depth);
    reinit(b_depth_h, b_depth_h + K_bdepth_depth * res_depth);
    reinit(P_z, max(P_z * (1.0 - K_z_depth), 1e-12));
    reinit(P_bdepth, max(P_bdepth * (1.0 - K_bdepth_depth), 1e-12));
    reinit(P_zw, P_zw * (1.0 - K_z_depth));
    t_stamp_depth = time;
  end when;

  // Compass: 50 Hz, offset 2 ms
  when sample(0.002, 1.0 / rate_compass) then
    reinit(psih, psih + K_psi_comp * res_compass);
    reinit(b_compass_h, b_compass_h + K_bcompass_comp * res_compass);
    reinit(P_psi, max(P_psi * (1.0 - K_psi_comp), 1e-12));
    reinit(P_bcompass, max(P_bcompass * (1.0 - K_bcompass_comp), 1e-12));
    reinit(P_omega_bgyro, P_omega_bgyro * (1.0 - K_psi_comp));
    t_stamp_compass = time;
  end when;

  // DVL: 10 Hz, offset 3 ms
  when sample(0.003, 1.0 / rate_dvl) then
    reinit(uh, uh + K_u_dvl * res_dvl);
    reinit(b_dvl_h, b_dvl_h + K_bdvl_dvl * res_dvl);
    reinit(b_acc_h, b_acc_h + K_bacc_dvl * res_dvl);
    reinit(P_u, max(P_u * (1.0 - K_u_dvl), 1e-12));
    reinit(P_bdvl, max(P_bdvl * (1.0 - K_bdvl_dvl), 1e-12));
    reinit(P_bacc, max(P_bacc - K_bacc_dvl * P_u_bacc, 1e-12));
    reinit(P_u_bacc, P_u_bacc * (1.0 - K_u_dvl));
    reinit(P_xu, P_xu * (1.0 - K_u_dvl));
    t_stamp_dvl = time;
  end when;

  // Acoustic range sensor 1: 1 Hz, offset 4 ms
  when sample(0.004, 1.0 / rate_acous) then
    reinit(xh, xh + K_x1 * res_acous1);
    reinit(yh, yh + K_y1 * res_acous1);
    reinit(zh, zh + K_z1 * res_acous1);
    reinit(P_x, max(P_x * (1.0 - K_x1 * H_x1), 1e-12));
    reinit(P_y, max(P_y * (1.0 - K_y1 * H_y1), 1e-12));
    reinit(P_z, max(P_z * (1.0 - K_z1 * H_z1), 1e-12));
    reinit(P_xu, P_xu * (1.0 - K_x1 * H_x1));
    reinit(P_yv, P_yv * (1.0 - K_y1 * H_y1));
    reinit(P_zw, P_zw * (1.0 - K_z1 * H_z1));
    t_stamp_acous1 = time;
  end when;

  // Acoustic range sensor 2: 1 Hz, offset 5 ms
  when sample(0.005, 1.0 / rate_acous) then
    reinit(xh, xh + K_x2 * res_acous2);
    reinit(yh, yh + K_y2 * res_acous2);
    reinit(zh, zh + K_z2 * res_acous2);
    reinit(P_x, max(P_x * (1.0 - K_x2 * H_x2), 1e-12));
    reinit(P_y, max(P_y * (1.0 - K_y2 * H_y2), 1e-12));
    reinit(P_z, max(P_z * (1.0 - K_z2 * H_z2), 1e-12));
    reinit(P_xu, P_xu * (1.0 - K_x2 * H_x2));
    reinit(P_yv, P_yv * (1.0 - K_y2 * H_y2));
    reinit(P_zw, P_zw * (1.0 - K_z2 * H_z2));
    t_stamp_acous2 = time;
  end when;

  // ================== Verification criteria ==================
  err_x = x - xh;
  err_y = y - yh;
  err_z = z - zh;
  err_psi = psi - psih;
  err_u = u - uh;

  tracking_error = sqrt(err_x * err_x + err_y * err_y + err_z * err_z);
  pos_error_band = tracking_error;
  att_error_band = abs(err_psi);

  cov_min_val = min(P_x, min(P_y, min(P_z, min(P_psi, min(P_u, min(P_v,
    min(P_w, min(P_bacc, min(P_bgyro, min(P_bdvl, min(P_bdepth, P_bcompass)))))))))));
  cov_positive = cov_min_val > 0.0;

  within_band = (tracking_error < 1.0) and (abs(err_psi) < 0.5);
  bias_converged = (time > 8.0) and (abs(b_acc_h - b_accel_true) < 0.04);
  tracking_ok = (time >= 13.0) and (tracking_error < 0.16);
  actuator_ok = (abs(F1) <= Fmax + 1e-6) and (abs(F2) <= Fmax + 1e-6)
              and (abs(F3) <= Fmax + 1e-6) and (abs(F4) <= Fmax + 1e-6);

  finite_check = abs(x) + abs(y) + abs(z) + abs(psi) + abs(u) + abs(v) + abs(w)
               + abs(omega) + abs(xh) + abs(yh) + abs(zh) + abs(psih) + abs(uh)
               + abs(vh) + abs(wh) + abs(omegah) + abs(b_acc_h) + abs(b_gyro_h)
               + abs(b_dvl_h) + abs(b_depth_h) + abs(b_compass_h) + abs(P_x)
               + abs(P_y) + abs(P_z) + abs(P_psi) + abs(P_u) + abs(F1) + abs(F2)
               + abs(F3) + abs(F4) + abs(depth_m) + abs(dvl_u_m) + abs(compass_m)
               + abs(range1_m) + abs(range2_m);
  no_nan_inf = (finite_check == finite_check) and (finite_check < 1e12);

  all_verified = cov_positive and within_band and bias_converged and tracking_ok
               and actuator_ok and no_nan_inf;

  annotation(
    experiment(StartTime = 0, StopTime = 20, Tolerance = 1e-6, Interval = 0.002),
    Documentation(info = "Underwater vehicle EKF navigation with asynchronous
      multi-rate sensor fusion (IMU 500 Hz, depth 100 Hz, compass 50 Hz, DVL 10 Hz,
      acoustic 1 Hz). A 0.058 m/s2 accelerometer bias step is injected during the
      middle third (6.67–13.33 s). Two fixed landmarks provide external references
      without ground-truth leak. Four thrusters are bounded at 128 N. Verification
      requires finite positive covariance, error bands, bias convergence, actuator
      limits, tracking error < 0.16 m after 13 s, and no NaN/Inf.")
  );
end MarineNavLocalizeF;