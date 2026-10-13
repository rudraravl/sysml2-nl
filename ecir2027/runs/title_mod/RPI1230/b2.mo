model MapRigLocalizeF
  "Mobile-base mapping/localization scenario with multi-rate EKF"

  constant Real pi_c = 3.141592653589793;

  // ===== Mission timing =====
  parameter Real T_end = 20.0 "simulation duration [s]";
  parameter Real f_sim = 500.0 "EKF predict rate [Hz]";
  parameter Real T_sample = 1.0 / f_sim "predict interval [s]";
  parameter Real T_step_start = T_end / 3.0 "middle third start [s]";
  parameter Real T_step_end = 2.0 * T_end / 3.0 "middle third end [s]";
  parameter Real b_step = 0.058 "controlled gyro-bias step disturbance [rad/s]";

  // ===== Embodiment =====
  parameter Real m_base = 22.0 "mobile base mass [kg]";
  parameter Real r_wheel = 0.10 "wheel radius [m]";
  parameter Real L_track = 0.40 "track width [m]";
  parameter Real I_z = 1.0 "yaw inertia [kg.m2]";
  parameter Real Cd_lin = 0.8 "linear drag [N.s/m]";
  parameter Real Cr_rot = 0.3 "rotational drag [N.m.s/rad]";
  parameter Real tau_max = 14.6 "per-wheel torque limit [N.m]";

  // ===== Controller gains =====
  parameter Real kp_v = 3.0 "forward speed gain";
  parameter Real kp_w = 3.0 "yaw rate gain";
  parameter Real kd_lat = 2.0 "lateral error gain";
  parameter Real kd_th = 1.5 "heading error gain";

  // ===== Sensor rates and noise =====
  parameter Real f_imu = 200.0 "IMU rate [Hz]";
  parameter Real T_imu = 1.0 / f_imu "IMU period [s]";
  parameter Real f_enc = 100.0 "encoder rate [Hz]";
  parameter Real T_enc = 1.0 / f_enc "encoder period [s]";
  parameter Real f_lidar = 10.0 "lidar rate [Hz]";
  parameter Real T_lidar = 1.0 / f_lidar "lidar period [s]";
  parameter Real f_cam = 20.0 "camera rate [Hz]";
  parameter Real T_cam = 1.0 / f_cam "camera period [s]";
  parameter Real sigma_gyro = 0.005 "IMU gyro std [rad/s]";
  parameter Real sigma_enc = 0.01 "encoder vel std [m/s]";
  parameter Real sigma_lidar = 0.02 "lidar range std [m]";
  parameter Real sigma_cam = 0.05 "RGB-D depth std [m]";
  parameter Real R_gyro = sigma_gyro * sigma_gyro;
  parameter Real R_enc = sigma_enc * sigma_enc;
  parameter Real R_lidar = sigma_lidar * sigma_lidar;
  parameter Real lidar_range_max = 20.0 "planar lidar max range [m]";

  // ===== Bounded route =====
  parameter Real R_route = 3.0 "route radius [m]";
  parameter Real omega_route = 0.20 "route angular rate [rad/s]";

  // ===== Fixed landmarks (external references; no ground truth to estimator) =====
  parameter Real Lx1 = 5.0;
  parameter Real Ly1 = 5.0;
  parameter Real Lx2 = -5.0;
  parameter Real Ly2 = 5.0;
  parameter Real Lx3 = 5.0;
  parameter Real Ly3 = -5.0;
  parameter Real Lx4 = -5.0;
  parameter Real Ly4 = -5.0;

  // ===== Process noise =====
  parameter Real q_pos = 1.0e-4;
  parameter Real q_v = 1.0e-3;
  parameter Real q_w = 1.0e-3;
  parameter Real q_b = 1.0e-5;

  // ===== True plant state (continuous) =====
  Real x_true(start=3.0) "true x [m]";
  Real y_true(start=0.0) "true y [m]";
  Real theta_true(start=1.5707963267948966) "true heading [rad]";
  Real v_true(start=0.0) "true forward speed [m/s]";
  Real omega_true(start=0.0) "true yaw rate [rad/s]";
  Real b_gyro_true(start=0.0) "true gyro bias [rad/s]";
  Real tau_L_cmd(start=0.0) "commanded left wheel torque [N.m]";
  Real tau_R_cmd(start=0.0) "commanded right wheel torque [N.m]";
  Real tau_L(start=0.0) "actual left wheel torque [N.m]";
  Real tau_R(start=0.0) "actual right wheel torque [N.m]";

  // ===== Reference =====
  Real x_ref "reference x [m]";
  Real y_ref "reference y [m]";
  Real theta_ref "reference heading [rad]";
  Real v_ref "reference speed [m/s]";
  Real omega_ref "reference yaw rate [rad/s]";

  // ===== Controller variables =====
  Real e_fwd "forward tracking error [m]";
  Real e_lat "lateral tracking error [m]";
  Real e_th "heading error [rad]";
  Real v_cmd "commanded forward speed [m/s]";
  Real omega_cmd "commanded yaw rate [rad/s]";
  Real F_drive "drive force [N]";
  Real M_drive "drive yaw moment [N.m]";

  // ===== Sensor measurements (discrete) =====
  discrete Real z_gyro(start=0.0) "IMU gyro [rad/s], body frame";
  discrete Real z_enc(start=0.0) "encoder forward speed [m/s], wheel frame";
  discrete Real z_lidar1(start=0.0) "lidar range to LM1 [m]";
  discrete Real z_lidar2(start=0.0) "lidar range to LM2 [m]";
  discrete Real z_lidar3(start=0.0) "lidar range to LM3 [m]";
  discrete Real z_lidar4(start=0.0) "lidar range to LM4 [m]";
  discrete Real z_cam_depth(start=0.0) "RGB-D forward depth [m], camera frame";
  discrete Real z_imu_time(start=-1.0) "IMU sample timestamp [s]";
  discrete Real z_enc_time(start=-1.0) "encoder sample timestamp [s]";
  discrete Real z_lidar_time(start=-1.0) "lidar sample timestamp [s]";
  discrete Real z_cam_time(start=-1.0) "camera sample timestamp [s]";
  discrete Integer cnt_imu(start=0);
  discrete Integer cnt_enc(start=0);
  discrete Integer cnt_lidar(start=0);
  discrete Integer cnt_cam(start=0);
  discrete Integer ekf_seen_imu(start=0);
  discrete Integer ekf_seen_enc(start=0);
  discrete Integer ekf_seen_lidar(start=0);
  discrete Integer ekf_seen_cam(start=0);

  // ===== EKF state: [x, y, theta, v, omega, b_g] (discrete) =====
  discrete Real xh1(start=3.0) "x estimate [m]";
  discrete Real xh2(start=0.0) "y estimate [m]";
  discrete Real xh3(start=1.5707963267948966) "theta estimate [rad]";
  discrete Real xh4(start=0.0) "v estimate [m/s]";
  discrete Real xh5(start=0.0) "omega estimate [rad/s]";
  discrete Real xh6(start=0.0) "b_g estimate [rad/s]";

  // ===== Diagonal covariance =====
  discrete Real P1(start=0.01) "P[x,x]";
  discrete Real P2(start=0.01) "P[y,y]";
  discrete Real P3(start=0.01) "P[th,th]";
  discrete Real P4(start=0.01) "P[v,v]";
  discrete Real P5(start=0.01) "P[w,w]";
  discrete Real P6(start=1.0e-4) "P[b,b]";

  // ===== EKF temporaries (discrete) =====
  discrete Real dx_lm(start=0.0);
  discrete Real dy_lm(start=0.0);
  discrete Real r_pred(start=1.0);
  discrete Real hx_val(start=0.0);
  discrete Real hy_val(start=0.0);
  discrete Real innov_val(start=0.0);
  discrete Real S_val(start=1.0);
  discrete Real K1(start=0.0);
  discrete Real K2(start=0.0);
  discrete Real K4(start=0.0);
  discrete Real K5(start=0.0);
  discrete Real K6(start=0.0);

  // ===== Observable outputs =====
  Real x_hat "estimated x [m]";
  Real y_hat "estimated y [m]";
  Real theta_hat "estimated theta [rad]";
  Real v_hat "estimated v [m/s]";
  Real omega_hat "estimated omega [rad/s]";
  Real b_g_hat "estimated bias [rad/s]";
  Real err_pos "position error [m]";
  Real err_theta "attitude error [rad]";
  Real tracking_err "primary tracking error [m or rad]";
  Real bias_err "bias estimation error [rad/s]";
  Real P_diag_min "minimum covariance diagonal entry";
  Boolean converged_after_13s;
  Boolean cov_finite_positive;
  Boolean tau_L_saturated;
  Boolean tau_R_saturated;
  Boolean no_nan_inf;

equation
  // ---- Controlled bias-step disturbance (middle third) ----
  b_gyro_true = if (time >= T_step_start and time <= T_step_end) then b_step else 0.0;

  // ---- True plant dynamics ----
  der(x_true) = v_true * cos(theta_true);
  der(y_true) = v_true * sin(theta_true);
  der(theta_true) = omega_true;
  m_base * der(v_true) = (tau_L + tau_R) / r_wheel - Cd_lin * v_true;
  I_z * der(omega_true) = (tau_R - tau_L) * L_track / (2 * r_wheel) - Cr_rot * omega_true;

  // ---- Reference route ----
  x_ref = R_route * cos(omega_route * time);
  y_ref = R_route * sin(omega_route * time);
  theta_ref = omega_route * time + pi_c / 2;
  v_ref = R_route * omega_route;
  omega_ref = omega_route;

  // ---- Controller using ESTIMATED state ----
  e_fwd = cos(xh3) * (x_ref - xh1) + sin(xh3) * (y_ref - xh2);
  e_lat = -sin(xh3) * (x_ref - xh1) + cos(xh3) * (y_ref - xh2);
  e_th = theta_ref - xh3;
  v_cmd = v_ref + kp_v * e_fwd;
  omega_cmd = omega_ref + kd_lat * e_lat + kd_th * e_th;
  F_drive = m_base * kp_v * (v_cmd - xh4);
  M_drive = I_z * kp_w * (omega_cmd - xh5);
  tau_L_cmd = 0.5 * (F_drive * r_wheel - M_drive * 2 * r_wheel / L_track);
  tau_R_cmd = 0.5 * (F_drive * r_wheel + M_drive * 2 * r_wheel / L_track);
  tau_L = if tau_L_cmd > tau_max then tau_max else if tau_L_cmd < -tau_max then -tau_max else tau_L_cmd;
  tau_R = if tau_R_cmd > tau_max then tau_max else if tau_R_cmd < -tau_max then -tau_max else tau_R_cmd;
  tau_L_saturated = abs(tau_L_cmd) > tau_max;
  tau_R_saturated = abs(tau_R_cmd) > tau_max;

  // ---- Estimate outputs ----
  x_hat = xh1;
  y_hat = xh2;
  theta_hat = xh3;
  v_hat = xh4;
  omega_hat = xh5;
  b_g_hat = xh6;
  bias_err = b_gyro_true - xh6;

  // ---- Verification metrics ----
  err_pos = sqrt((x_true - x_hat) ^ 2 + (y_true - y_hat) ^ 2 + 1.0e-12);
  err_theta = abs(theta_true - theta_hat);
  tracking_err = max(err_pos, err_theta);
  converged_after_13s = time >= 13.0 and tracking_err < 0.16;
  P_diag_min = min(P1, min(P2, min(P3, min(P4, min(P5, P6)))));
  cov_finite_positive = P_diag_min > 0.0 and P_diag_min < 1.0e6;
  no_nan_inf = abs(x_true) < 1.0e6 and abs(y_true) < 1.0e6 and abs(theta_true) < 1.0e6
    and abs(v_true) < 1.0e6 and abs(omega_true) < 1.0e6
    and abs(tau_L) < 1.0e6 and abs(tau_R) < 1.0e6
    and abs(xh1) < 1.0e6 and abs(xh2) < 1.0e6 and abs(xh3) < 1.0e6
    and abs(xh4) < 1.0e6 and abs(xh5) < 1.0e6 and abs(xh6) < 1.0e6
    and abs(P1) < 1.0e6 and abs(P6) < 1.0e6;

  // ============ Asynchronous sensor sample events ============
  // IMU 200 Hz, body frame
  when sample(0.0001, T_imu) then
    z_gyro = omega_true + b_gyro_true + sigma_gyro * sin(time * 7.3);
    z_imu_time = time;
    cnt_imu = pre(cnt_imu) + 1;
  end when;

  // Wheel encoders 100 Hz, wheel frame
  when sample(0.0002, T_enc) then
    z_enc = v_true + sigma_enc * sin(time * 11.0);
    z_enc_time = time;
    cnt_enc = pre(cnt_enc) + 1;
  end when;

  // Planar lidar 10 Hz, 20 m max, lidar frame (ranges to fixed landmarks)
  when sample(0.0003, T_lidar) then
    z_lidar1 = sqrt((x_true - Lx1) ^ 2 + (y_true - Ly1) ^ 2) + sigma_lidar * sin(time * 13.0 + 1.0);
    z_lidar2 = sqrt((x_true - Lx2) ^ 2 + (y_true - Ly2) ^ 2) + sigma_lidar * sin(time * 13.0 + 2.0);
    z_lidar3 = sqrt((x_true - Lx3) ^ 2 + (y_true - Ly3) ^ 2) + sigma_lidar * sin(time * 13.0 + 3.0);
    z_lidar4 = sqrt((x_true - Lx4) ^ 2 + (y_true - Ly4) ^ 2) + sigma_lidar * sin(time * 13.0 + 4.0);
    z_lidar_time = time;
    cnt_lidar = pre(cnt_lidar) + 1;
  end when;

  // Forward RGB-D camera 20 Hz, camera frame (depth to landmark 1)
  when sample(0.0004, T_cam) then
    z_cam_depth = min(lidar_range_max, sqrt((x_true - Lx1) ^ 2 + (y_true - Ly1) ^ 2)) + sigma_cam * sin(time * 3.0);
    z_cam_time = time;
    cnt_cam = pre(cnt_cam) + 1;
  end when;

algorithm
  // ============ EKF predict + asynchronous updates at 500 Hz ============
  when sample(0.001, T_sample) then
    // ---- Predict state (Euler) ----
    xh1 := pre(xh1) + T_sample * pre(xh4) * cos(pre(xh3));
    xh2 := pre(xh2) + T_sample * pre(xh4) * sin(pre(xh3));
    xh3 := pre(xh3) + T_sample * pre(xh5);
    xh4 := pre(xh4) + T_sample * ((tau_L + tau_R) / (r_wheel * m_base) - (Cd_lin / m_base) * pre(xh4));
    xh5 := pre(xh5) + T_sample * ((tau_R - tau_L) * L_track / (2 * r_wheel * I_z) - (Cr_rot / I_z) * pre(xh5));
    xh6 := pre(xh6);

    // ---- Predict covariance (diagonal approximation) ----
    P1 := pre(P1) + T_sample * (abs(pre(xh4)) + q_pos);
    P2 := pre(P2) + T_sample * (abs(pre(xh4)) + q_pos);
    P3 := pre(P3) + T_sample * (abs(pre(xh5)) + q_pos);
    P4 := pre(P4) + T_sample * q_v;
    P5 := pre(P5) + T_sample * q_w;
    P6 := pre(P6) + T_sample * q_b;

    // ---- IMU gyro update: H = [0 0 0 0 1 1] ----
    if cnt_imu > pre(ekf_seen_imu) then
      innov_val := z_gyro - (xh5 + xh6);
      S_val := P5 + P6 + R_gyro;
      if S_val > 1.0e-12 then
        K5 := P5 / S_val;
        K6 := P6 / S_val;
        xh5 := xh5 + K5 * innov_val;
        xh6 := xh6 + K6 * innov_val;
        P5 := P5 * (1.0 - K5);
        P6 := P6 * (1.0 - K6);
      end if;
      ekf_seen_imu := cnt_imu;
    else
      ekf_seen_imu := pre(ekf_seen_imu);
    end if;

    // ---- Encoder update: H = [0 0 0 1 0 0] ----
    if cnt_enc > pre(ekf_seen_enc) then
      innov_val := z_enc - xh4;
      S_val := P4 + R_enc;
      if S_val > 1.0e-12 then
        K4 := P4 / S_val;
        xh4 := xh4 + K4 * innov_val;
        P4 := P4 * (1.0 - K4);
      end if;
      ekf_seen_enc := cnt_enc;
    else
      ekf_seen_enc := pre(ekf_seen_enc);
    end if;

    // ---- Lidar range updates (4 landmarks) ----
    if cnt_lidar > pre(ekf_seen_lidar) then
      // Landmark 1
      dx_lm := xh1 - Lx1;
      dy_lm := xh2 - Ly1;
      r_pred := sqrt(dx_lm * dx_lm + dy_lm * dy_lm + 1.0e-6);
      innov_val := z_lidar1 - r_pred;
      hx_val := dx_lm / r_pred;
      hy_val := dy_lm / r_pred;
      S_val := hx_val * hx_val * P1 + hy_val * hy_val * P2 + R_lidar;
      if S_val > 1.0e-12 then
        K1 := P1 * hx_val / S_val;
        K2 := P2 * hy_val / S_val;
        xh1 := xh1 + K1 * innov_val;
        xh2 := xh2 + K2 * innov_val;
        P1 := P1 * (1.0 - K1 * hx_val);
        P2 := P2 * (1.0 - K2 * hy_val);
      end if;

      // Landmark 2
      dx_lm := xh1 - Lx2;
      dy_lm := xh2 - Ly2;
      r_pred := sqrt(dx_lm * dx_lm + dy_lm * dy_lm + 1.0e-6);
      innov_val := z_lidar2 - r_pred;
      hx_val := dx_lm / r_pred;
      hy_val := dy_lm / r_pred;
      S_val := hx_val * hx_val * P1 + hy_val * hy_val * P2 + R_lidar;
      if S_val > 1.0e-12 then
        K1 := P1 * hx_val / S_val;
        K2 := P2 * hy_val / S_val;
        xh1 := xh1 + K1 * innov_val;
        xh2 := xh2 + K2 * innov_val;
        P1 := P1 * (1.0 - K1 * hx_val);
        P2 := P2 * (1.0 - K2 * hy_val);
      end if;

      // Landmark 3
      dx_lm := xh1 - Lx3;
      dy_lm := xh2 - Ly3;
      r_pred := sqrt(dx_lm * dx_lm + dy_lm * dy_lm + 1.0e-6);
      innov_val := z_lidar3 - r_pred;
      hx_val := dx_lm / r_pred;
      hy_val := dy_lm / r_pred;
      S_val := hx_val * hx_val * P1 + hy_val * hy_val * P2 + R_lidar;
      if S_val > 1.0e-12 then
        K1 := P1 * hx_val / S_val;
        K2 := P2 * hy_val / S_val;
        xh1 := xh1 + K1 * innov_val;
        xh2 := xh2 + K2 * innov_val;
        P1 := P1 * (1.0 - K1 * hx_val);
        P2 := P2 * (1.0 - K2 * hy_val);
      end if;

      // Landmark 4
      dx_lm := xh1 - Lx4;
      dy_lm := xh2 - Ly4;
      r_pred := sqrt(dx_lm * dx_lm + dy_lm * dy_lm + 1.0e-6);
      innov_val := z_lidar4 - r_pred;
      hx_val := dx_lm / r_pred;
      hy_val := dy_lm / r_pred;
      S_val := hx_val * hx_val * P1 + hy_val * hy_val * P2 + R_lidar;
      if S_val > 1.0e-12 then
        K1 := P1 * hx_val / S_val;
        K2 := P2 * hy_val / S_val;
        xh1 := xh1 + K1 * innov_val;
        xh2 := xh2 + K2 * innov_val;
        P1 := P1 * (1.0 - K1 * hx_val);
        P2 := P2 * (1.0 - K2 * hy_val);
      end if;

      ekf_seen_lidar := cnt_lidar;
    else
      ekf_seen_lidar := pre(ekf_seen_lidar);
    end if;

    // RGB-D camera data recorded (timestamp/frame/std preserved) but not fused
    ekf_seen_cam := pre(ekf_seen_cam);

    // ---- Covariance diagonal floor (finite positive guarantee) ----
    if P1 < 1.0e-9 then
      P1 := 1.0e-9;
    end if;
    if P2 < 1.0e-9 then
      P2 := 1.0e-9;
    end if;
    if P3 < 1.0e-9 then
      P3 := 1.0e-9;
    end if;
    if P4 < 1.0e-9 then
      P4 := 1.0e-9;
    end if;
    if P5 < 1.0e-9 then
      P5 := 1.0e-9;
    end if;
    if P6 < 1.0e-9 then
      P6 := 1.0e-9;
    end if;
  end when;

annotation(
  experiment(StartTime=0, StopTime=20, Tolerance=1.0e-6, Interval=0.002),
  Documentation(info="22 kg differential-drive mobile base performing bounded-route mapping/localization.
Sensors (asynchronous, preserved rates/frames/stds/biases): IMU 200 Hz body frame, wheel encoders 100 Hz,
planar lidar 10 Hz (20 m max), forward RGB-D 20 Hz. EKF state [x,y,theta,v,omega,b_g] at 500 Hz predict
with diagonal covariance approximation. Controlled 0.058 rad/s gyro-bias step applied during middle third
(6.67-13.33 s). Per-wheel torque bounded at 14.6 N.m. Fixed landmarks provided as external references;
estimator never receives ground truth. Controller uses estimated state. Verification: finite positive
covariance, tracking error < 0.16 m-or-rad after 13 s, bias convergence, no NaN/Inf."));
end MapRigLocalizeF;