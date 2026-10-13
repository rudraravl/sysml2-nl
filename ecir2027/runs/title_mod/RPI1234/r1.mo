model MapRigBridgeD
  "Instrumented robotic sensing and estimation system with multi-rate EKF and 8s absolute-position dropout"

  // ===== Physical parameters =====
  parameter Real m_base = 22.0 "Mobile base mass [kg]";
  parameter Real r_wheel = 0.10 "Wheel radius [m] (assumed engineering default)";
  parameter Real track_w = 0.50 "Track width [m] (assumed engineering default)";
  parameter Real I_base = 0.45833 "Base yaw inertia [kg.m2] (assumed m*track^2/12)";
  parameter Real tau_max = 12.0 "Maximum wheel torque [N.m]";
  parameter Real lidar_range = 20.0 "Planar lidar maximum range [m]";

  // ===== Timing =====
  parameter Real dt_est = 0.005 "Estimator timestep [s], 200 Hz";
  parameter Real T_total = 14.0 "Total simulation duration [s]";
  parameter Real t_drop_start = 3.0 "Dropout start [s]";
  parameter Real t_drop_end = 11.0 "Dropout end [s], 8 s centered";
  parameter Integer enc_period = 2 "Encoder period in est steps (100 Hz)";
  parameter Integer abs_period = 20 "Absolute sensor period in est steps (10 Hz)";

  // ===== Trajectory (assumed engineering defaults) =====
  parameter Real R_traj = 2.0 "Circular trajectory radius [m]";
  parameter Real w_traj = 0.30 "Trajectory angular rate [rad/s]";

  // ===== Sensor transforms (assumed, base frame) =====
  parameter Real lidar_x = 0.0 "Lidar x offset [m]";
  parameter Real lidar_y = 0.0 "Lidar y offset [m]";
  parameter Real cam_x = 0.15 "Forward RGB-D camera x offset [m]";
  parameter Real cam_y = 0.0 "Forward RGB-D camera y offset [m]";

  // ===== Estimator noise parameters (assumed) =====
  parameter Real Q_pos = 0.001 "Process noise pos variance rate [m2/s]";
  parameter Real Q_theta = 0.001 "Process noise heading var rate [rad2/s]";
  parameter Real R_pos_m = 0.01 "Abs meas noise pos variance [m2]";
  parameter Real R_theta_m = 0.001 "Abs meas noise heading variance [rad2]";
  parameter Real gate_thresh = 25.0 "Innovation gate threshold [chi2, 3 DOF]";
  parameter Real enc_v_bias = 0.01 "Encoder velocity bias [m/s] (assumed)";
  parameter Real imu_w_bias = 0.005 "IMU angular rate bias [rad/s] (assumed)";

  // ===== Controller gains (assumed) =====
  parameter Real Kp_pos = 20.0 "Position proportional gain [N/m]";
  parameter Real Kd_pos = 20.0 "Velocity proportional gain [N/(m/s)]";
  parameter Real Kp_ang = 10.0 "Heading proportional gain [N.m/rad]";
  parameter Real Kd_ang = 5.0 "Angular rate proportional gain [N.m/(rad/s)]";

  // ===== Plant state (continuous) =====
  Real x(start = 0.0, fixed = true) "Base x position [m]";
  Real y(start = 0.0, fixed = true) "Base y position [m]";
  Real theta(start = 0.0, fixed = true) "Base heading [rad]";
  Real v(start = 0.0, fixed = true) "Base forward velocity [m/s]";
  Real omega(start = 0.0, fixed = true) "Base angular velocity [rad/s]";

  // ===== Reference trajectory =====
  Real x_ref "Reference x [m]";
  Real y_ref "Reference y [m]";
  Real theta_ref "Reference heading [rad]";
  Real v_ref "Reference speed [m/s]";
  Real omega_ref "Reference angular rate [rad/s]";

  // ===== Controller =====
  Real F_cmd "Force command [N]";
  Real M_cmd "Moment command [N.m]";
  Real tau_L_raw "Raw left wheel torque [N.m]";
  Real tau_R_raw "Raw right wheel torque [N.m]";
  Real tau_L "Saturated left wheel torque [N.m]";
  Real tau_R "Saturated right wheel torque [N.m]";

  // ===== Sensor signals =====
  Real imu_omega "IMU angular rate [rad/s] (200 Hz)";
  Real imu_accel "IMU forward acceleration [m/s2] (200 Hz)";
  Real enc_v(start = 0.0) "Encoder velocity [m/s] (100 Hz)";
  Real enc_omega(start = 0.0) "Encoder angular rate [rad/s] (100 Hz)";
  Real abs_x(start = 0.0) "Absolute x measurement [m] (10 Hz)";
  Real abs_y(start = 0.0) "Absolute y measurement [m] (10 Hz)";
  Real abs_theta(start = 0.0) "Absolute heading measurement [rad] (10 Hz)";

  // ===== Estimator state (discrete, 200 Hz) =====
  Real x_hat(start = 0.0, fixed = true) "Estimated x [m]";
  Real y_hat(start = 0.0, fixed = true) "Estimated y [m]";
  Real theta_hat(start = 0.0, fixed = true) "Estimated theta [rad]";
  Real v_hat(start = 0.0, fixed = true) "Estimated forward velocity [m/s]";
  Real omega_hat(start = 0.0, fixed = true) "Estimated angular rate [rad/s]";
  Real P00(start = 0.01, fixed = true) "Covariance P00 [m2]";
  Real P11(start = 0.01, fixed = true) "Covariance P11 [m2]";
  Real P22(start = 0.01, fixed = true) "Covariance P22 [rad2]";

  // ===== Estimator intermediates (discrete) =====
  Real x_pred(start = 0.0) "Predicted x [m]";
  Real y_pred(start = 0.0) "Predicted y [m]";
  Real theta_pred(start = 0.0) "Predicted theta [rad]";
  Real P00p(start = 0.01) "Predicted P00 [m2]";
  Real P11p(start = 0.01) "Predicted P11 [m2]";
  Real P22p(start = 0.01) "Predicted P22 [rad2]";
  Real K0(start = 0.0) "Kalman gain x";
  Real K1(start = 0.0) "Kalman gain y";
  Real K2(start = 0.0) "Kalman gain theta";
  Real innov_x(start = 0.0) "Innovation x [m]";
  Real innov_y(start = 0.0) "Innovation y [m]";
  Real innov_t(start = 0.0) "Innovation theta [rad]";
  Real gate_val(start = 0.0) "Gate statistic [chi2]";
  Boolean gate_ok(start = true) "Gate pass flag";

  Integer est_cnt(start = 0) "Estimator step counter";
  Real ts(start = 0.0, fixed = true) "Synchronized timestamp [s]";

  // ===== Dropout =====
  Boolean in_dropout "True during absolute sensor dropout";

  // ===== Error metrics =====
  Real pos_err_est "Position estimation error [m]";
  Real ang_err_est "Angular estimation error [rad]";
  Real pos_err_track "Position tracking error [m]";
  Real ang_err_track "Angular tracking error [rad]";
  Real primary_track_err "Primary tracking error [m or rad]";
  Boolean req_met "Requirement met flag (after 9.1 s)";

equation
  // === Reference trajectory: circle with translation and rotation ===
  x_ref = R_traj * sin(w_traj * time);
  y_ref = R_traj * (1.0 - cos(w_traj * time));
  theta_ref = w_traj * time;
  v_ref = R_traj * w_traj;
  omega_ref = w_traj;

  // === Plant dynamics (differential drive) ===
  der(x) = v * cos(theta);
  der(y) = v * sin(theta);
  der(theta) = omega;
  der(v) = (tau_L + tau_R) / (r_wheel * m_base);
  der(omega) = (tau_R - tau_L) * track_w / (2.0 * r_wheel * I_base);

  // === Torque saturation (bounded wheel drives) ===
  tau_L = max(-tau_max, min(tau_max, tau_L_raw));
  tau_R = max(-tau_max, min(tau_max, tau_R_raw));

  // === Controller using estimated state ===
  F_cmd = Kp_pos * ((x_ref - x_hat) * cos(theta_hat) + (y_ref - y_hat) * sin(theta_hat))
        + Kd_pos * (v_ref - v_hat);
  M_cmd = Kp_ang * atan2(sin(theta_ref - theta_hat), cos(theta_ref - theta_hat))
        + Kd_ang * (omega_ref - omega_hat);

  // === Wheel torque from force and moment ===
  tau_L_raw = F_cmd * r_wheel / 2.0 - M_cmd * r_wheel / track_w;
  tau_R_raw = F_cmd * r_wheel / 2.0 + M_cmd * r_wheel / track_w;

  // === IMU (200 Hz, continuous with bias) ===
  imu_omega = omega + imu_w_bias;
  imu_accel = (tau_L + tau_R) / (r_wheel * m_base);

  // === Dropout indicator ===
  in_dropout = (time >= t_drop_start) and (time < t_drop_end);

  // === Error metrics ===
  pos_err_est = sqrt((x - x_hat) * (x - x_hat) + (y - y_hat) * (y - y_hat));
  ang_err_est = atan2(sin(theta - theta_hat), cos(theta - theta_hat));
  pos_err_track = sqrt((x - x_ref) * (x - x_ref) + (y - y_ref) * (y - y_ref));
  ang_err_track = atan2(sin(theta - theta_ref), cos(theta - theta_ref));
  primary_track_err = max(pos_err_est, abs(ang_err_est));
  req_met = (time >= 9.1) and (primary_track_err < 0.35);

  // === Estimator: 200 Hz, multi-rate, innovation gating ===
  when sample(0, dt_est) then
    est_cnt = pre(est_cnt) + 1;
    ts = time;

    // --- Encoder update (100 Hz) ---
    if mod(pre(est_cnt) + 1, enc_period) == 0 then
      enc_v = v + enc_v_bias;
      enc_omega = omega;
    else
      enc_v = pre(enc_v);
      enc_omega = pre(enc_omega);
    end if;

    // --- Prediction step (always, uses inertial + proprioceptive) ---
    x_pred = pre(x_hat) + pre(v_hat) * cos(pre(theta_hat)) * dt_est;
    y_pred = pre(y_hat) + pre(v_hat) * sin(pre(theta_hat)) * dt_est;
    theta_pred = pre(theta_hat) + pre(omega_hat) * dt_est;
    P00p = pre(P00) + Q_pos * dt_est;
    P11p = pre(P11) + Q_pos * dt_est;
    P22p = pre(P22) + Q_theta * dt_est;

    // Velocity estimate from latest sensors
    v_hat = enc_v;
    omega_hat = imu_omega;

    // --- Absolute position update (10 Hz, skip during dropout, gated) ---
    if mod(pre(est_cnt) + 1, abs_period) == 0 and not in_dropout then
      // Measurement with lidar transform
      abs_x = x + lidar_x * cos(theta) - lidar_y * sin(theta);
      abs_y = y + lidar_x * sin(theta) + lidar_y * cos(theta);
      abs_theta = theta;

      // Innovation (angle wrapped)
      innov_x = abs_x - x_pred;
      innov_y = abs_y - y_pred;
      innov_t = atan2(sin(abs_theta - theta_pred), cos(abs_theta - theta_pred));

      // Innovation gating (Mahalanobis distance, safe divisor)
      gate_val = innov_x * innov_x / max(P00p, 1.0e-12)
               + innov_y * innov_y / max(P11p, 1.0e-12)
               + innov_t * innov_t / max(P22p, 1.0e-12);

      if gate_val < gate_thresh then
        // Kalman gain (diagonal covariance)
        K0 = P00p / (P00p + R_pos_m);
        K1 = P11p / (P11p + R_pos_m);
        K2 = P22p / (P22p + R_theta_m);
        // State correction
        x_hat = x_pred + K0 * innov_x;
        y_hat = y_pred + K1 * innov_y;
        theta_hat = theta_pred + K2 * innov_t;
        // Covariance reduction
        P00 = (1.0 - K0) * P00p;
        P11 = (1.0 - K1) * P11p;
        P22 = (1.0 - K2) * P22p;
        gate_ok = true;
      else
        // Gate rejected: prediction only
        K0 = 0.0; K1 = 0.0; K2 = 0.0;
        x_hat = x_pred;
        y_hat = y_pred;
        theta_hat = theta_pred;
        P00 = P00p; P11 = P11p; P22 = P22p;
        gate_ok = false;
      end if;
    else
      // No absolute measurement available (dropout or off-cycle)
      abs_x = pre(abs_x);
      abs_y = pre(abs_y);
      abs_theta = pre(abs_theta);
      innov_x = 0.0; innov_y = 0.0; innov_t = 0.0;
      gate_val = 0.0;
      gate_ok = true;
      K0 = 0.0; K1 = 0.0; K2 = 0.0;
      x_hat = x_pred;
      y_hat = y_pred;
      theta_hat = theta_pred;
      P00 = P00p; P11 = P11p; P22 = P22p;
    end if;
  end when;

  // === Safety assertions ===
  assert(x > -1.0e6 and x < 1.0e6, "x out of physical bounds");
  assert(y > -1.0e6 and y < 1.0e6, "y out of physical bounds");
  assert(P00 >= 0.0 and P11 >= 0.0 and P22 >= 0.0, "Negative covariance");
  assert(primary_track_err < 5.0, "Tracking error unbounded");

  annotation(
    experiment(StartTime = 0, StopTime = 14.0, Tolerance = 1e-6, Interval = 0.005),
    Documentation(info = "MapRigBridgeD: 22 kg mobile base carrying 20 m planar lidar, forward RGB-D camera,
      wheel encoders, and IMU at explicitly different rates (200/100/10 Hz) and transforms.
      Multi-rate EKF at 200 Hz with innovation gating (Mahalanobis, chi2 threshold).
      Controlled 8 s absolute-position dropout (t=3..11 s) during middle third of 14 s run.
      Covariance grows during outage; inertial and proprioceptive updates continue.
      Trajectory: circular (translation + rotation) so drift is observable.
      Requirements: timestamp order, bounded outage error, recovery after return,
      primary tracking error < 0.35 m-or-rad after 9.1 s, no NaN or infinite values."));
end MapRigBridgeD;