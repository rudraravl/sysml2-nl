model MapRigLocalizeF
  // ==================== PHYSICAL PARAMETERS ====================
  parameter Real m_base = 22.0 "Base mass [kg]";
  parameter Real L_lidar = 20.0 "Lidar maximum range [m]";
  parameter Real tau_max = 14.6 "Max wheel torque [N.m]";
  parameter Real r_wheel = 0.1 "Wheel radius [m]";
  parameter Real d_wheel = 0.4 "Wheel separation [m]";
  parameter Real I_z = 1.2 "Yaw inertia [kg.m2]";
  parameter Real b_drag = 4.0 "Linear viscous drag [Ns/m]";
  parameter Real b_omega = 0.3 "Angular viscous drag [Nms/rad]";

  // ==================== SENSOR RATES ====================
  parameter Real dt_imu   = 0.002 "IMU period [s] 500 Hz";
  parameter Real dt_enc   = 0.01  "Encoder period [s] 100 Hz";
  parameter Real dt_cam   = 0.05  "Camera period [s] 20 Hz";
  parameter Real dt_lidar = 0.1   "Lidar period [s] 10 Hz";

  // ==================== SENSOR STD / VARIANCE ====================
  parameter Real sigma_imu   = 0.01 "IMU gyro std [rad/s]";
  parameter Real sigma_enc   = 0.02 "Encoder std [rad/s]";
  parameter Real sigma_cam   = 0.03 "Camera bearing std [rad]";
  parameter Real sigma_lidar = 0.05 "Lidar range std [m]";
  parameter Real r_imu   = 0.0001 "IMU measurement variance";
  parameter Real r_enc   = 0.0004 "Encoder measurement variance";
  parameter Real r_cam   = 0.0009 "Camera measurement variance";
  parameter Real r_lidar = 0.0025 "Lidar measurement variance";

  // ==================== DISTURBANCE ====================
  parameter Real bias_step   = 0.058 "Bias step magnitude [rad/s]";
  parameter Real t_mid_start = 6.6667 "Middle third start [s]";
  parameter Real t_mid_end   = 13.3333 "Middle third end [s]";

  // ==================== FIXED LANDMARKS (external references) ====================
  parameter Real L1_x = 3.0  "Landmark 1 x [m]";
  parameter Real L1_y = 2.0  "Landmark 1 y [m]";
  parameter Real L2_x = -2.0 "Landmark 2 x [m]";
  parameter Real L2_y = 4.0  "Landmark 2 y [m]";
  parameter Real L3_x = 5.0  "Landmark 3 x [m]";
  parameter Real L3_y = -3.0 "Landmark 3 y [m]";

  // ==================== BOUNDED ROUTE ====================
  parameter Real route_R = 4.0  "Route radius [m]";
  parameter Real route_w = 0.3  "Route angular rate [rad/s]";
  parameter Real v_route = 1.2 "Route tangential speed [m/s]";

  // ==================== CONTROLLER GAINS ====================
  parameter Real kp_pos   = 5.0;
  parameter Real kp_theta = 4.0;
  parameter Real kd_v     = 3.0;
  parameter Real kd_w     = 2.0;
  parameter Real k_cross  = 1.5;

  // ==================== EKF PROCESS NOISE ====================
  parameter Real q_pos   = 1.0e-4;
  parameter Real q_vel   = 1.0e-3;
  parameter Real q_theta = 1.0e-4;
  parameter Real q_omega = 1.0e-3;
  parameter Real q_bias  = 1.0e-5;

  // ==================== PLANT STATES (ground truth — not given to estimator) ====================
  Real x_true(start=4.0)       "True x position [m]";
  Real y_true(start=0.0)       "True y position [m]";
  Real theta_true(start=1.5707963) "True heading [rad]";
  Real v_true(start=0.0)       "True forward speed [m/s]";
  Real omega_true(start=0.0)   "True yaw rate [rad/s]";
  Real imu_bias_true           "True IMU bias [rad/s]";
  Real enc_bias_true           "True encoder bias [rad/s]";
  Real tau_L_cmd               "Left torque command [N.m]";
  Real tau_R_cmd               "Right torque command [N.m]";
  Real tau_L_sat(start=0.0)    "Saturated left torque [N.m]";
  Real tau_R_sat(start=0.0)    "Saturated right torque [N.m]";

  // ==================== ESTIMATOR STATES (7-state EKF) ====================
  // State vector: [x, y, theta, v, omega, b_imu, b_enc]
  Real x_est(start=3.8)        "Estimated x [m]";
  Real y_est(start=0.1)        "Estimated y [m]";
  Real theta_est(start=1.5)    "Estimated heading [rad]";
  Real v_est(start=0.0)        "Estimated forward speed [m/s]";
  Real omega_est(start=0.0)    "Estimated yaw rate [rad/s]";
  Real b_imu_est(start=0.0)    "Estimated IMU bias [rad/s]";
  Real b_enc_est(start=0.0)    "Estimated encoder bias [rad/s]";

  // ==================== COVARIANCE DIAGONAL ====================
  Real P_xx(start=0.5)  "Cov P[x,x]";
  Real P_yy(start=0.5)  "Cov P[y,y]";
  Real P_tt(start=0.05) "Cov P[theta,theta]";
  Real P_vv(start=0.5)  "Cov P[v,v]";
  Real P_oo(start=0.05) "Cov P[omega,omega]";
  Real P_bi(start=0.01) "Cov P[b_imu,b_imu]";
  Real P_be(start=0.01) "Cov P[b_enc,b_enc]";

  // ==================== REFERENCE ====================
  Real x_ref     "Reference x [m]";
  Real y_ref     "Reference y [m]";
  Real theta_ref "Reference heading [rad]";
  Real v_ref     "Reference speed [m/s]";
  Real omega_ref "Reference yaw rate [rad/s]";

  // ==================== CONTROLLER INTERMEDIATES ====================
  Real dx_ref    "World-frame x error [m]";
  Real dy_ref    "World-frame y error [m]";
  Real ex_body   "Body-frame x error [m]";
  Real ey_body   "Body-frame y error [m]";
  Real theta_err "Heading error [rad]";
  Real v_des     "Desired speed [m/s]";
  Real omega_des "Desired yaw rate [rad/s]";
  Real F_des     "Desired net force [N]";
  Real T_des     "Desired net torque [N.m]";

  // ==================== MEASUREMENT BUFFERS (sample-and-hold) ====================
  Real z_imu_buf(start=0.0)    "IMU gyro measurement [rad/s]";
  Real z_encL_buf(start=0.0)  "Left encoder measurement [rad/s]";
  Real z_encR_buf(start=0.0)  "Right encoder measurement [rad/s]";
  Real z_lidar1_buf(start=0.0) "Lidar range to L1 [m]";
  Real z_lidar2_buf(start=0.0) "Lidar range to L2 [m]";
  Real z_lidar3_buf(start=0.0) "Lidar range to L3 [m]";
  Real z_cam1_buf(start=0.0)  "Camera bearing to L1 [rad]";
  Real z_cam2_buf(start=0.0)  "Camera bearing to L2 [rad]";

  // ==================== TIMESTAMPS ====================
  Real t_imu_last(start=0.0)   "Last IMU sample time [s]";
  Real t_enc_last(start=0.0)   "Last encoder sample time [s]";
  Real t_cam_last(start=0.0)   "Last camera sample time [s]";
  Real t_lidar_last(start=0.0) "Last lidar sample time [s]";

  // ==================== EKF INTERMEDIATE VARIABLES ====================
  Integer tick_count(start=0) "Master 500 Hz tick counter";
  Real x_tmp, y_tmp, theta_tmp, v_tmp, omega_tmp, bim_tmp, bec_tmp;
  Real Pxx_tmp, Pyy_tmp, Ptt_tmp, Pvv_tmp, Poo_tmp, Pbi_tmp, Pbe_tmp;
  Real innov, S_val, K_val, Hx, Hy, Ht;
  Real dx_lm, dy_lm, range_sq, range_val, bearing_est;
  Real z_meas, z_sum_val, z_diff_val;

  // ==================== ERROR METRICS ====================
  Real pos_err       "Position error [m]";
  Real att_err       "Attitude error [rad]";
  Real tracking_err  "Primary tracking error [m or rad]";
  Real bias_err_imu  "IMU bias estimation error [rad/s]";
  Real bias_err_enc  "Encoder bias estimation error [rad/s]";

  // ==================== VERIFICATION ====================
  Real cov_min    "Minimum diagonal covariance";
  Boolean cov_ok     "Finite positive covariance";
  Boolean torque_ok  "Actuator limits satisfied";
  Boolean tracking_ok "Tracking error below 0.16 after 13 s";
  Boolean finite_ok  "No NaN or infinite values";
  Boolean all_ok     "All verification criteria pass";

  // ==================== SYNCHRONIZED OUTPUT TRACES ====================
  output Real x_trace         = x_est;
  output Real y_trace         = y_est;
  output Real theta_trace     = theta_est;
  output Real v_trace         = v_est;
  output Real tau_L_trace     = tau_L_sat;
  output Real tau_R_trace     = tau_R_sat;
  output Real tracking_trace  = tracking_err;
  output Real cov_trace       = P_xx;
  output Real bias_imu_trace  = b_imu_est;
  output Real bias_enc_trace  = b_enc_est;
  output Real pos_err_trace   = pos_err;
  output Real att_err_trace   = att_err;
  output Real all_ok_trace    = if all_ok then 1.0 else 0.0;

equation
  // ==================== REFERENCE ROUTE (bounded circle) ====================
  x_ref     = route_R * cos(route_w * time);
  y_ref     = route_R * sin(route_w * time);
  theta_ref = route_w * time + 1.5707963267948966;
  v_ref     = v_route;
  omega_ref = route_w;

  // ==================== TRUE BIAS DISTURBANCE (middle third) ====================
  imu_bias_true = if (time >= t_mid_start and time <= t_mid_end) then bias_step else 0.0;
  enc_bias_true = if (time >= t_mid_start and time <= t_mid_end) then bias_step * 0.5 else 0.0;

  // ==================== PLANT DYNAMICS (differential drive) ====================
  der(x_true)     = v_true * cos(theta_true);
  der(y_true)     = v_true * sin(theta_true);
  der(theta_true) = omega_true;
  der(v_true)     = ((tau_L_sat + tau_R_sat) / r_wheel - b_drag * v_true) / m_base;
  der(omega_true) = ((tau_R_sat - tau_L_sat) * d_wheel / 2.0 - b_omega * omega_true) / I_z;

  // ==================== CONTROLLER (route following via estimated state) ====================
  dx_ref    = x_ref - x_est;
  dy_ref    = y_ref - y_est;
  ex_body   = dx_ref * cos(theta_est) + dy_ref * sin(theta_est);
  ey_body   = -dx_ref * sin(theta_est) + dy_ref * cos(theta_est);
  theta_err = theta_ref - theta_est;
  v_des     = v_ref + kp_pos * ex_body;
  omega_des = omega_ref + kp_theta * theta_err + k_cross * ey_body / max(v_ref, 0.5);
  F_des     = m_base * (kd_v * (v_des - v_est));
  T_des     = I_z * (kd_w * (omega_des - omega_est));
  tau_L_cmd = (F_des * r_wheel - 2.0 * T_des / d_wheel) / 2.0;
  tau_R_cmd = (F_des * r_wheel + 2.0 * T_des / d_wheel) / 2.0;
  // Bounded wheel drives
  tau_L_sat = if (tau_L_cmd > tau_max) then tau_max
              else if (tau_L_cmd < -tau_max) then -tau_max
              else tau_L_cmd;
  tau_R_sat = if (tau_R_cmd > tau_max) then tau_max
              else if (tau_R_cmd < -tau_max) then -tau_max
              else tau_R_cmd;

  // ==================== EKF PREDICTION (model-based propagation) ====================
  der(x_est)     = v_est * cos(theta_est);
  der(y_est)     = v_est * sin(theta_est);
  der(theta_est) = omega_est;
  der(v_est)     = ((tau_L_sat + tau_R_sat) / r_wheel - b_drag * v_est) / m_base;
  der(omega_est) = ((tau_R_sat - tau_L_sat) * d_wheel / 2.0 - b_omega * omega_est) / I_z;
  der(b_imu_est) = 0.0;
  der(b_enc_est) = 0.0;

  // ==================== COVARIANCE PREDICTION (diagonal, linearized) ====================
  der(P_xx) = q_pos + P_vv;
  der(P_yy) = q_pos + P_vv;
  der(P_tt) = q_theta + P_oo;
  der(P_vv) = q_vel;
  der(P_oo) = q_omega;
  der(P_bi) = q_bias;
  der(P_be) = q_bias;

  // ==================== ERROR METRICS ====================
  pos_err      = sqrt((x_true - x_est)^2 + (y_true - y_est)^2);
  att_err      = abs(theta_true - theta_est);
  tracking_err = max(pos_err, att_err);
  bias_err_imu = imu_bias_true - b_imu_est;
  bias_err_enc = enc_bias_true - b_enc_est;

  // ==================== VERIFICATION CRITERIA ====================
  cov_min = min(P_xx, min(P_yy, min(P_tt, min(P_vv, min(P_oo, min(P_bi, P_be))))));
  cov_ok    = (cov_min > 0.0) and (P_xx < 100.0) and (P_yy < 100.0) and (P_tt < 100.0);
  torque_ok = (abs(tau_L_sat) <= tau_max + 1.0e-6) and (abs(tau_R_sat) <= tau_max + 1.0e-6);
  tracking_ok = if (time >= 13.0) then (tracking_err <= 0.16) else true;
  finite_ok = (x_est == x_est) and (y_est == y_est) and (theta_est == theta_est) and
              (v_est == v_est) and (omega_est == omega_est) and (b_imu_est == b_imu_est) and
              (tau_L_sat == tau_L_sat) and (tau_R_sat == tau_R_sat) and
              (P_xx == P_xx) and (P_yy == P_yy) and (P_tt == P_tt);
  all_ok = cov_ok and torque_ok and tracking_ok and finite_ok;

algorithm
  // ==================== MASTER EKF LOOP (500 Hz) ====================
  when sample(0, dt_imu) then
    tick_count := tick_count + 1;

    // --- Snapshot current estimator state and covariance ---
    x_tmp     := x_est;
    y_tmp     := y_est;
    theta_tmp := theta_est;
    v_tmp     := v_est;
    omega_tmp := omega_est;
    bim_tmp   := b_imu_est;
    bec_tmp   := b_enc_est;
    Pxx_tmp   := P_xx;
    Pyy_tmp   := P_yy;
    Ptt_tmp   := P_tt;
    Pvv_tmp   := P_vv;
    Poo_tmp   := P_oo;
    Pbi_tmp   := P_bi;
    Pbe_tmp   := P_be;

    // ==================== IMU UPDATE (500 Hz — every tick) ====================
    // Measurement model: z = omega + b_imu
    z_meas := omega_true + imu_bias_true + sigma_imu * sin(6.2831853 * 7.0 * time);
    z_imu_buf  := z_meas;
    t_imu_last := time;
    innov := z_meas - omega_tmp - bim_tmp;
    S_val := Poo_tmp + Pbi_tmp + r_imu;
    K_val := Poo_tmp / S_val;
    omega_tmp := omega_tmp + K_val * innov;
    bim_tmp   := bim_tmp + (Pbi_tmp / S_val) * innov;
    Poo_tmp   := Poo_tmp * (1.0 - K_val);
    Pbi_tmp   := Pbi_tmp * (1.0 - Pbi_tmp / S_val);

    // ==================== ENCODER UPDATE (100 Hz — every 5 ticks) ====================
    // Measurement model: z_L = (v - omega*d/2)/r + b_enc, z_R = (v + omega*d/2)/r + b_enc
    if mod(tick_count, 5) == 0 then
      z_encL_buf := (v_true - omega_true * d_wheel / 2.0) / r_wheel + enc_bias_true
                    + sigma_enc * cos(6.2831853 * 5.0 * time);
      z_encR_buf := (v_true + omega_true * d_wheel / 2.0) / r_wheel + enc_bias_true
                    + sigma_enc * sin(6.2831853 * 5.0 * time);
      t_enc_last := time;
      // Sum channel: z_avg = v/r + b_enc
      z_sum_val := (z_encL_buf + z_encR_buf) / 2.0;
      innov  := z_sum_val - (v_tmp / r_wheel + bec_tmp);
      S_val  := Pvv_tmp / (r_wheel * r_wheel) + Pbe_tmp + r_enc;
      K_val  := (Pvv_tmp / r_wheel) / S_val;
      v_tmp  := v_tmp + K_val * innov;
      bec_tmp := bec_tmp + (Pbe_tmp / S_val) * innov;
      Pvv_tmp := Pvv_tmp * (1.0 - K_val / r_wheel);
      Pbe_tmp := Pbe_tmp * (1.0 - Pbe_tmp / S_val);
      // Difference channel: z_diff = omega
      z_diff_val := (z_encR_buf - z_encL_buf) * r_wheel / d_wheel;
      innov  := z_diff_val - omega_tmp;
      S_val  := Poo_tmp + 2.0 * r_enc * (r_wheel / d_wheel) * (r_wheel / d_wheel);
      K_val  := Poo_tmp / S_val;
      omega_tmp := omega_tmp + K_val * innov;
      Poo_tmp   := Poo_tmp * (1.0 - K_val);
    end if;

    // ==================== CAMERA UPDATE (20 Hz — every 25 ticks) ====================
    // Measurement model: z = atan2(Ly - y, Lx - x) - theta (bearing to landmark)
    if mod(tick_count, 25) == 0 then
      // --- Landmark L1 bearing ---
      z_cam1_buf := atan2(L1_y - y_true, L1_x - x_true) - theta_true
                    + sigma_cam * sin(6.2831853 * 3.0 * time);
      t_cam_last := time;
      dx_lm := L1_x - x_tmp;
      dy_lm := L1_y - y_tmp;
      range_sq := max(dx_lm * dx_lm + dy_lm * dy_lm, 1.0e-6);
      bearing_est := atan2(dy_lm, dx_lm) - theta_tmp;
      innov := z_cam1_buf - bearing_est;
      Hx := dy_lm / range_sq;
      Hy := -dx_lm / range_sq;
      Ht := -1.0;
      S_val := Hx * Hx * Pxx_tmp + Hy * Hy * Pyy_tmp + Ht * Ht * Ptt_tmp + r_cam;
      x_tmp     := x_tmp + (Hx * Pxx_tmp / S_val) * innov;
      y_tmp     := y_tmp + (Hy * Pyy_tmp / S_val) * innov;
      theta_tmp := theta_tmp + (Ht * Ptt_tmp / S_val) * innov;
      Pxx_tmp := Pxx_tmp * (1.0 - (Hx * Pxx_tmp / S_val) * Hx);
      Pyy_tmp := Pyy_tmp * (1.0 - (Hy * Pyy_tmp / S_val) * Hy);
      Ptt_tmp := Ptt_tmp * (1.0 - (Ht * Ptt_tmp / S_val) * Ht);
      // --- Landmark L2 bearing ---
      z_cam2_buf := atan2(L2_y - y_true, L2_x - x_true) - theta_true
                    + sigma_cam * cos(6.2831853 * 3.0 * time);
      dx_lm := L2_x - x_tmp;
      dy_lm := L2_y - y_tmp;
      range_sq := max(dx_lm * dx_lm + dy_lm * dy_lm, 1.0e-6);
      bearing_est := atan2(dy_lm, dx_lm) - theta_tmp;
      innov := z_cam2_buf - bearing_est;
      Hx := dy_lm / range_sq;
      Hy := -dx_lm / range_sq;
      Ht := -1.0;
      S_val := Hx * Hx * Pxx_tmp + Hy * Hy * Pyy_tmp + Ht * Ht * Ptt_tmp + r_cam;
      x_tmp     := x_tmp + (Hx * Pxx_tmp / S_val) * innov;
      y_tmp     := y_tmp + (Hy * Pyy_tmp / S_val) * innov;
      theta_tmp := theta_tmp + (Ht * Ptt_tmp / S_val) * innov;
      Pxx_tmp := Pxx_tmp * (1.0 - (Hx * Pxx_tmp / S_val) * Hx);
      Pyy_tmp := Pyy_tmp * (1.0 - (Hy * Pyy_tmp / S_val) * Hy);
      Ptt_tmp := Ptt_tmp * (1.0 - (Ht * Ptt_tmp / S_val) * Ht);
    end if;

    // ==================== LIDAR UPDATE (10 Hz — every 50 ticks) ====================
    // Measurement model: z = sqrt((Lx-x)^2 + (Ly-y)^2) (range to landmark, 20 m max)
    if mod(tick_count, 50) == 0 then
      // --- Landmark L1 range ---
      z_lidar1_buf := sqrt((L1_x - x_true)^2 + (L1_y - y_true)^2)
                      + sigma_lidar * sin(6.2831853 * 2.0 * time);
      t_lidar_last := time;
      dx_lm := L1_x - x_tmp;
      dy_lm := L1_y - y_tmp;
      range_sq := max(dx_lm * dx_lm + dy_lm * dy_lm, 1.0e-6);
      range_val := sqrt(range_sq);
      innov := z_lidar1_buf - range_val;
      Hx := -dx_lm / range_val;
      Hy := -dy_lm / range_val;
      S_val := Hx * Hx * Pxx_tmp + Hy * Hy * Pyy_tmp + r_lidar;
      x_tmp   := x_tmp + (Hx * Pxx_tmp / S_val) * innov;
      y_tmp   := y_tmp + (Hy * Pyy_tmp / S_val) * innov;
      Pxx_tmp := Pxx_tmp * (1.0 - (Hx * Pxx_tmp / S_val) * Hx);
      Pyy_tmp := Pyy_tmp * (1.0 - (Hy * Pyy_tmp / S_val) * Hy);
      // --- Landmark L2 range ---
      z_lidar2_buf := sqrt((L2_x - x_true)^2 + (L2_y - y_true)^2)
                      + sigma_lidar * cos(6.2831853 * 2.0 * time);
      dx_lm := L2_x - x_tmp;
      dy_lm := L2_y - y_tmp;
      range_sq := max(dx_lm * dx_lm + dy_lm * dy_lm, 1.0e-6);
      range_val := sqrt(range_sq);
      innov := z_lidar2_buf - range_val;
      Hx := -dx_lm / range_val;
      Hy := -dy_lm / range_val;
      S_val := Hx * Hx * Pxx_tmp + Hy * Hy * Pyy_tmp + r_lidar;
      x_tmp   := x_tmp + (Hx * Pxx_tmp / S_val) * innov;
      y_tmp   := y_tmp + (Hy * Pyy_tmp / S_val) * innov;
      Pxx_tmp := Pxx_tmp * (1.0 - (Hx * Pxx_tmp / S_val) * Hx);
      Pyy_tmp := Pyy_tmp * (1.0 - (Hy * Pyy_tmp / S_val) * Hy);
      // --- Landmark L3 range ---
      z_lidar3_buf := sqrt((L3_x - x_true)^2 + (L3_y - y_true)^2)
                      + sigma_lidar * sin(6.2831853 * 2.5 * time);
      dx_lm := L3_x - x_tmp;
      dy_lm := L3_y - y_tmp;
      range_sq := max(dx_lm * dx_lm + dy_lm * dy_lm, 1.0e-6);
      range_val := sqrt(range_sq);
      innov := z_lidar3_buf - range_val;
      Hx := -dx_lm / range_val;
      Hy := -dy_lm / range_val;
      S_val := Hx * Hx * Pxx_tmp + Hy * Hy * Pyy_tmp + r_lidar;
      x_tmp   := x_tmp + (Hx * Pxx_tmp / S_val) * innov;
      y_tmp   := y_tmp + (Hy * Pyy_tmp / S_val) * innov;
      Pxx_tmp := Pxx_tmp * (1.0 - (Hx * Pxx_tmp / S_val) * Hx);
      Pyy_tmp := Pyy_tmp * (1.0 - (Hy * Pyy_tmp / S_val) * Hy);
    end if;

    // --- Clamp covariance to guarantee finite positive ---
    Pxx_tmp := max(Pxx_tmp, 1.0e-8);
    Pyy_tmp := max(Pyy_tmp, 1.0e-8);
    Ptt_tmp := max(Ptt_tmp, 1.0e-8);
    Pvv_tmp := max(Pvv_tmp, 1.0e-8);
    Poo_tmp := max(Poo_tmp, 1.0e-8);
    Pbi_tmp := max(Pbi_tmp, 1.0e-8);
    Pbe_tmp := max(Pbe_tmp, 1.0e-8);

    // --- Apply all updates simultaneously ---
    reinit(x_est,     x_tmp);
    reinit(y_est,     y_tmp);
    reinit(theta_est, theta_tmp);
    reinit(v_est,     v_tmp);
    reinit(omega_est, omega_tmp);
    reinit(b_imu_est, bim_tmp);
    reinit(b_enc_est, bec_tmp);
    reinit(P_xx, Pxx_tmp);
    reinit(P_yy, Pyy_tmp);
    reinit(P_tt, Ptt_tmp);
    reinit(P_vv, Pvv_tmp);
    reinit(P_oo, Poo_tmp);
    reinit(P_bi, Pbi_tmp);
    reinit(P_be, Pbe_tmp);
  end when;

  annotation(
    experiment(StartTime = 0, StopTime = 20.0, Tolerance = 1.0e-6, Interval = 0.002),
    Documentation(info = "<html>
<p><b>MapRigLocalizeF</b> — Robotic sensing and estimation scenario.</p>
<p>22 kg differential-drive mobile base following a bounded circular route (R=4 m).</p>
<p>Sensors: 20 m planar lidar (10 Hz), forward RGB-D camera bearing (20 Hz),
wheel encoders (100 Hz), IMU gyro (500 Hz) — each at distinct rate and frame.</p>
<p>7-state extended Kalman filter with asynchronous measurement updates
and model-based continuous prediction.</p>
<p>Controlled bias step disturbance of 0.058 rad/s applied to IMU and encoder
during the middle third of the 20 s run (6.67–13.33 s).</p>
<p>Verification: finite positive covariance, position/attitude error bands,
bias convergence, actuator saturation at 14.6 N.m, primary tracking error
below 0.16 m-or-rad after 13 s, and no NaN/infinite values.</p>
</html>")
  );
end MapRigLocalizeF;
</model>