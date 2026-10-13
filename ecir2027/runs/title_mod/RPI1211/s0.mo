model WheelIMUBridgeE
  // ================================================================
  // Robotic sensing and estimation system with slow absolute-position
  // sensor dropout. Differential-drive plant, wheel encoders, center
  // six-axis IMU, multi-rate EKF-like estimator with innovation gating.
  // ================================================================

  // ---- Physical parameters (assumed where not stated) ----
  parameter Real m = 16.0 "chassis mass [kg]";
  parameter Real r = 0.05 "wheel radius [m] (assumption)";
  parameter Real L = 0.3 "wheelbase [m] (assumption)";
  parameter Real Iz = 0.12 "yaw inertia [kg.m2] (assumption)";
  parameter Real tau_max = 11.0 "max wheel torque [N.m]";

  // ---- Timing ----
  parameter Real dt_est = 1.0 / 250.0 "estimator period [s]";
  parameter Real dt_abs = 0.1 "absolute sensor period [s]";
  parameter Real t_drop_start = 3.2 "dropout start [s]";
  parameter Real t_drop_end = 12.8 "dropout end [s], 9.6 s duration";
  parameter Real abs_steps = 25.0 "estimator steps per absolute sample";

  // ---- Six-axis IMU noise and bias (declared for all axes) ----
  parameter Real accel_noise_std_x = 0.005 "accel noise std x [m/s2]";
  parameter Real accel_noise_std_y = 0.0 "accel noise std y [m/s2] (unused 2D)";
  parameter Real accel_noise_std_z = 0.0 "accel noise std z [m/s2] (unused 2D)";
  parameter Real gyro_noise_std_x = 0.0 "gyro noise std x [rad/s] (unused 2D)";
  parameter Real gyro_noise_std_y = 0.0 "gyro noise std y [rad/s] (unused 2D)";
  parameter Real gyro_noise_std_z = 0.002 "gyro noise std z [rad/s]";
  parameter Real accel_bias_x = 0.01 "accel bias x [m/s2]";
  parameter Real accel_bias_y = 0.0 "accel bias y [m/s2] (unused 2D)";
  parameter Real accel_bias_z = 0.0 "accel bias z [m/s2] (unused 2D)";
  parameter Real gyro_bias_x = 0.0 "gyro bias x [rad/s] (unused 2D)";
  parameter Real gyro_bias_y = 0.0 "gyro bias y [rad/s] (unused 2D)";
  parameter Real gyro_bias_z = 0.001 "gyro bias z (yaw) [rad/s]";

  // ---- Encoder parameters ----
  parameter Real encoder_noise_std = 0.005 "encoder wheel-speed noise std [m/s]";

  // ---- Absolute sensor parameters ----
  parameter Real abs_pos_noise_std = 0.02 "absolute pos noise std [m]";
  parameter Real abs_theta_noise_std = 0.01 "absolute heading noise std [rad]";

  // ---- Filter parameters ----
  parameter Real gate_thresh = 0.5 "innovation gate threshold [m]";
  parameter Real Q_pos = 1e-4 "process noise position [(m2)/s]";
  parameter Real Q_theta = 1e-4 "process noise heading [(rad2)/s]";
  parameter Real R_pos = 4e-4 "measurement noise position [m2]";
  parameter Real R_theta = 1e-4 "measurement noise heading [rad2]";
  parameter Real alpha_enc = 0.3 "encoder LPF factor";

  // ---- Controller gains ----
  parameter Real kp_v = 8.0 "velocity P gain";
  parameter Real kp_h = 3.0 "heading P gain";
  parameter Real kd_h = 1.5 "heading D gain";

  // ---- Plant states ----
  Real x(start = 0.0, fixed = true) "x position [m]";
  Real y(start = 0.0, fixed = true) "y position [m]";
  Real theta(start = 0.0, fixed = true) "heading [rad]";
  Real v(start = 0.0, fixed = true) "forward velocity [m/s]";
  Real omega(start = 0.0, fixed = true) "yaw rate [rad/s]";
  Real a_x_true "true forward acceleration [m/s2]";
  Real F_cmd "commanded total force [N]";
  Real T_cmd "commanded yaw torque [N.m]";
  Real tau_R_raw "right wheel torque unsaturated [N.m]";
  Real tau_L_raw "left wheel torque unsaturated [N.m]";
  Real tau_R "right wheel torque [N.m]";
  Real tau_L "left wheel torque [N.m]";

  // ---- Reference trajectory ----
  Real x_ref(start = 0.0, fixed = true) "reference x [m]";
  Real y_ref(start = 0.0, fixed = true) "reference y [m]";
  Real theta_ref(start = 0.0, fixed = true) "reference heading [rad]";
  Real v_ref "reference velocity [m/s]";
  Real omega_ref "reference yaw rate [rad/s]";

  // ---- IMU signals ----
  Real a_x_meas "measured forward accel [m/s2]";
  Real omega_meas "measured yaw rate [rad/s]";

  // ---- Encoder signals ----
  Real v_wheelR_meas "right wheel linear speed measurement [m/s]";
  Real v_wheelL_meas "left wheel linear speed measurement [m/s]";

  // ---- Absolute sensor ----
  Boolean abs_available "true when absolute sensor is available";
  Real x_abs "absolute x measurement [m]";
  Real y_abs "absolute y measurement [m]";
  Real theta_abs "absolute heading measurement [rad]";

  // ---- Estimator states (discrete, 250 Hz) ----
  Real x_est(start = 0.0, fixed = true) "estimated x [m]";
  Real y_est(start = 0.0, fixed = true) "estimated y [m]";
  Real theta_est(start = 0.0, fixed = true) "estimated heading [rad]";
  Real v_est(start = 0.0, fixed = true) "estimated velocity [m/s]";
  Real omega_est(start = 0.0, fixed = true) "estimated yaw rate [rad/s]";
  Real P_x(start = 0.001) "x covariance [m2]";
  Real P_y(start = 0.001) "y covariance [m2]";
  Real P_th(start = 0.001) "heading covariance [rad2]";

  // ---- Estimator intermediates (discrete) ----
  Real x_pred(start = 0.0) "predicted x [m]";
  Real y_pred(start = 0.0) "predicted y [m]";
  Real theta_pred(start = 0.0) "predicted heading [rad]";
  Real P_x_pred(start = 0.001) "predicted x covariance [m2]";
  Real P_y_pred(start = 0.001) "predicted y covariance [m2]";
  Real P_th_pred(start = 0.001) "predicted heading covariance [rad2]";
  Real v_enc(start = 0.0) "velocity from encoders [m/s]";
  Real omega_enc(start = 0.0) "yaw rate from encoders [rad/s]";
  Real innov_x(start = 0.0) "x innovation [m]";
  Real innov_y(start = 0.0) "y innovation [m]";
  Real innov_th(start = 0.0) "heading innovation [rad]";
  Boolean gate_pass(start = false) "innovation gate pass flag";
  Boolean is_abs_sample(start = false) "true at absolute sensor sample steps";
  Real est_counter(start = 0.0) "estimator step counter";
  Real est_timestamp(start = 0.0) "last estimator timestamp [s]";
  Boolean timestamp_ok(start = true) "timestamp monotonicity flag";
  Real P_before(start = 0.001) "covariance captured at dropout start [m2]";
  Real P_max_dropout(start = 0.0) "max covariance during dropout [m2]";

  // ---- Acceptance metrics ----
  Real pos_error "position estimation error [m]";
  Real theta_error_raw "raw heading error [rad]";
  Real theta_error "wrapped heading error [rad]";
  Real primary_error "primary tracking error [m or rad]";
  Boolean no_nan "no NaN or infinite values";
  Boolean cov_grew "covariance grew during dropout";
  Boolean bounded_outage "outage error bounded";
  Boolean recovered "recovered after measurements return";
  Boolean primary_ok "primary error below 0.315 after 10.4 s";
  Boolean passed "overall acceptance (fail-closed)";

equation
  // ===== Reference trajectory: translation + rotation =====
  v_ref = 0.5;
  omega_ref = 0.3 * sin(0.5 * time);
  der(x_ref) = v_ref * cos(theta_ref);
  der(y_ref) = v_ref * sin(theta_ref);
  der(theta_ref) = omega_ref;

  // ===== Plant dynamics =====
  der(x) = v * cos(theta);
  der(y) = v * sin(theta);
  der(theta) = omega;
  a_x_true = (tau_R + tau_L) / (m * r);
  der(v) = a_x_true;
  der(omega) = (tau_R - tau_L) * L / (2.0 * Iz * r);

  // ===== Controller (bounded wheel torque, uses true state) =====
  F_cmd = kp_v * (v_ref - v);
  T_cmd = kp_h * (theta_ref - theta) + kd_h * (omega_ref - omega);
  tau_R_raw = F_cmd * r / 2.0 + T_cmd * r / L;
  tau_L_raw = F_cmd * r / 2.0 - T_cmd * r / L;
  tau_R = if tau_R_raw > tau_max then tau_max
    else if tau_R_raw < -tau_max then -tau_max
    else tau_R_raw;
  tau_L = if tau_L_raw > tau_max then tau_max
    else if tau_L_raw < -tau_max then -tau_max
    else tau_L_raw;

  // ===== IMU measurements (noise + bias) =====
  a_x_meas = a_x_true + accel_bias_x
    + accel_noise_std_x * (2.0 * (abs(sin(time * 37.0 + 1.3)) - 0.5));
  omega_meas = omega + gyro_bias_z
    + gyro_noise_std_z * (2.0 * (abs(sin(time * 41.0 + 2.7)) - 0.5));

  // ===== Encoder measurements (noise) =====
  v_wheelR_meas = (v + omega * L / 2.0)
    + encoder_noise_std * (2.0 * (abs(sin(time * 53.0 + 0.7)) - 0.5));
  v_wheelL_meas = (v - omega * L / 2.0)
    + encoder_noise_std * (2.0 * (abs(sin(time * 59.0 + 3.1)) - 0.5));

  // ===== Absolute sensor availability (dropout: 3.2 s to 12.8 s) =====
  abs_available = time < t_drop_start or time > t_drop_end;

  // ===== Multi-rate estimator at 250 Hz =====
  when sample(0, dt_est) then
    est_counter = pre(est_counter) + 1.0;
    est_timestamp = time;
    timestamp_ok = pre(timestamp_ok) and (time >= pre(est_timestamp) - 1e-12);

    // Absolute sensor sample every 25 estimator steps (at t = 0.1, 0.2, ...)
    is_abs_sample = (mod(est_counter, abs_steps) > 0.5)
      and (mod(est_counter, abs_steps) < 1.5)
      and (est_counter > 1.5);

    // Encoder-based velocity estimation (low-pass filtered)
    v_enc = (v_wheelR_meas + v_wheelL_meas) / 2.0;
    omega_enc = (v_wheelR_meas - v_wheelL_meas) / L;
    v_est = alpha_enc * v_enc + (1.0 - alpha_enc) * pre(v_est);
    omega_est = alpha_enc * omega_enc + (1.0 - alpha_enc) * pre(omega_est);

    // Prediction: inertial (IMU gyro) + proprioceptive (encoder velocity)
    x_pred = pre(x_est) + pre(v_est) * cos(pre(theta_est)) * dt_est;
    y_pred = pre(y_est) + pre(v_est) * sin(pre(theta_est)) * dt_est;
    theta_pred = pre(theta_est) + omega_meas * dt_est;
    P_x_pred = pre(P_x) + Q_pos * dt_est;
    P_y_pred = pre(P_y) + Q_pos * dt_est;
    P_th_pred = pre(P_th) + Q_theta * dt_est;

    // Track maximum covariance during dropout window
    if time >= t_drop_start and time <= t_drop_end then
      P_max_dropout = max(pre(P_max_dropout), P_x_pred);
    else
      P_max_dropout = pre(P_max_dropout);
    end if;

    // Correction with innovation gating (only when absolute sensor available)
    if is_abs_sample and abs_available then
      x_abs = x + abs_pos_noise_std * (2.0 * (abs(sin(time * 61.0 + 4.1)) - 0.5));
      y_abs = y + abs_pos_noise_std * (2.0 * (abs(sin(time * 67.0 + 5.3)) - 0.5));
      theta_abs = theta + abs_theta_noise_std * (2.0 * (abs(sin(time * 71.0 + 6.7)) - 0.5));

      innov_x = x_abs - x_pred;
      innov_y = y_abs - y_pred;
      innov_th = theta_abs - theta_pred;
      gate_pass = (innov_x * innov_x + innov_y * innov_y < gate_thresh * gate_thresh)
        and (abs(innov_th) < gate_thresh);

      if gate_pass then
        x_est = x_pred + (P_x_pred / (P_x_pred + R_pos)) * innov_x;
        y_est = y_pred + (P_y_pred / (P_y_pred + R_pos)) * innov_y;
        theta_est = theta_pred + (P_th_pred / (P_th_pred + R_theta)) * innov_th;
        P_x = P_x_pred * R_pos / (P_x_pred + R_pos);
        P_y = P_y_pred * R_pos / (P_y_pred + R_pos);
        P_th = P_th_pred * R_theta / (P_th_pred + R_theta);
      else
        x_est = x_pred;
        y_est = y_pred;
        theta_est = theta_pred;
        P_x = P_x_pred;
        P_y = P_y_pred;
        P_th = P_th_pred;
      end if;
    else
      x_est = x_pred;
      y_est = y_pred;
      theta_est = theta_pred;
      P_x = P_x_pred;
      P_y = P_y_pred;
      P_th = P_th_pred;
    end if;
  end when;

  // ===== Capture covariance just before dropout =====
  when time >= t_drop_start then
    P_before = pre(P_x);
  end when;

  // ===== Acceptance metrics =====
  pos_error = sqrt((x - x_est) * (x - x_est) + (y - y_est) * (y - y_est));
  theta_error_raw = theta - theta_est;
  theta_error = if theta_error_raw > 3.14159265358979
    then theta_error_raw - 6.28318530717959
    else if theta_error_raw < -3.14159265358979
    then theta_error_raw + 6.28318530717959
    else theta_error_raw;
  primary_error = max(pos_error, abs(theta_error));

  // NaN / infinity check (fail-closed)
  no_nan = (x == x) and (y == y) and (theta == theta) and (v == v) and (omega == omega)
    and (x_est == x_est) and (y_est == y_est) and (theta_est == theta_est)
    and (v_est == v_est) and (omega_est == omega_est)
    and (tau_R == tau_R) and (tau_L == tau_L)
    and (abs(x) < 1e8) and (abs(y) < 1e8) and (abs(theta) < 1e8)
    and (abs(v) < 1e8) and (abs(omega) < 1e8)
    and (abs(x_est) < 1e8) and (abs(y_est) < 1e8) and (abs(theta_est) < 1e8)
    and (abs(tau_R) < 1e8) and (abs(tau_L) < 1e8);

  // Covariance grew during dropout
  cov_grew = P_max_dropout > P_before + 1e-9;

  // Bounded outage error throughout dropout
  bounded_outage = primary_error < 0.315;

  // Recovery after measurements return
  recovered = pos_error < 0.1 and time > t_drop_end + 1.0;

  // Primary tracking error below 0.315 m-or-rad after 10.4 s
  primary_ok = primary_error < 0.315 and time >= 10.4;

  // Overall acceptance (fail-closed: all must hold)
  passed = no_nan and timestamp_ok and cov_grew and primary_ok
    and bounded_outage and recovered;

  annotation(experiment(StartTime = 0, StopTime = 16, Tolerance = 1e-6, Interval = 0.004));
end WheelIMUBridgeE;