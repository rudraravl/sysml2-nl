model WheelIMULocalizeC
  "Robotic sensing and estimation: 16 kg differential-drive chassis with EKF observer,
   wheel encoders, six-axis IMU, fixed landmark. 125 Hz sample rate, 12 s duration,
   9.2 N.m per-wheel torque limit, 0.036 rad/s bias step injected in middle third."

  // ===== PHYSICAL PARAMETERS (assumed where not specified) =====
  parameter Real m = 16.0 "Chassis mass [kg]";
  parameter Real J = 1.28 "Yaw inertia [kg.m2] (assumed for compact chassis)";
  parameter Real r_w = 0.10 "Wheel radius [m] (assumed)";
  parameter Real L = 0.50 "Wheelbase [m] (assumed)";
  parameter Real Cd = 0.80 "Linear drag coefficient [N.s/m] (assumed)";
  parameter Real Cr = 0.50 "Rotational drag coefficient [N.m.s/rad] (assumed)";

  // ===== ACTUATOR LIMIT =====
  parameter Real tau_max = 9.2 "Maximum wheel torque command magnitude [N.m]";

  // ===== SENSOR SAMPLE RATE =====
  parameter Real f_samp = 125.0 "Sensor sampling frequency [Hz]";
  parameter Real dt_samp = 1.0 / f_samp "Sample period [s]";

  // ===== SIX-AXIS IMU NOISE STD (all declared; planar uses z-gyro, x-accel) =====
  parameter Real sigma_gyro_x = 0.002 "X-gyro noise std [rad/s] (declared, unused planar)";
  parameter Real sigma_gyro_y = 0.002 "Y-gyro noise std [rad/s] (declared, unused planar)";
  parameter Real sigma_gyro_z = 0.002 "Z-gyro noise std [rad/s]";
  parameter Real sigma_accel_x = 0.05 "X-accel noise std [m/s2]";
  parameter Real sigma_accel_y = 0.05 "Y-accel noise std [m/s2] (declared, unused planar)";
  parameter Real sigma_accel_z = 0.05 "Z-accel noise std [m/s2] (declared, unused planar)";

  // ===== SIX-AXIS IMU BIAS STATES (all declared; planar uses z-gyro, x-accel) =====
  parameter Real b_gyro_x_0 = 0.0 "X-gyro bias [rad/s] (declared, unused planar)";
  parameter Real b_gyro_y_0 = 0.0 "Y-gyro bias [rad/s] (declared, unused planar)";
  parameter Real b_gyro_z_0 = 0.01 "Z-gyro bias [rad/s]";
  parameter Real b_accel_x_0 = 0.02 "X-accel bias [m/s2]";
  parameter Real b_accel_y_0 = 0.0 "Y-accel bias [m/s2] (declared, unused planar)";
  parameter Real b_accel_z_0 = 0.0 "Z-accel bias [m/s2] (declared, unused planar)";

  // ===== INJECTED BIAS STEP DISTURBANCE =====
  parameter Real bias_step = 0.036 "Injected sensor-bias step disturbance [rad/s]";

  // ===== ENCODER AND LANDMARK NOISE =====
  parameter Real sigma_enc = 0.01 "Wheel encoder angular velocity noise std [rad/s]";
  parameter Real sigma_lm_r = 0.05 "Landmark range noise std [m]";
  parameter Real sigma_lm_b = 0.02 "Landmark bearing noise std [rad]";

  // ===== OBSERVER GAINS (continuous-time EKF-like) =====
  parameter Real kpx = 1.5 "Position-x correction gain";
  parameter Real kpy = 1.5 "Position-y correction gain";
  parameter Real kpt = 2.0 "Heading correction gain";
  parameter Real kpv = 4.0 "Velocity correction gain";
  parameter Real kpw = 3.0 "Yaw-rate correction gain";
  parameter Real kbg = 0.5 "Gyro bias correction gain";
  parameter Real kba = 0.5 "Accel bias correction gain";

  // ===== CONTROLLER GAINS =====
  parameter Real kp_pos = 1.0 "Longitudinal position feedback gain [1/s]";
  parameter Real kp_lat = 0.5 "Lateral error to yaw-rate gain [rad/m]";
  parameter Real kp_v = 8.0 "Velocity error gain [1/s]";
  parameter Real kp_w = 5.0 "Yaw-rate error gain [1/s]";
  parameter Real kp_h = 2.5 "Heading error to yaw-rate gain [1/s]";

  // ===== REFERENCE PATH (bounded circular route) =====
  parameter Real R_path = 2.5 "Reference path radius [m]";
  parameter Real w_path = 0.30 "Reference path angular rate [rad/s]";
  parameter Real v_path = R_path * w_path "Reference linear speed [m/s]";

  // ===== FIXED LANDMARK (external reference, no ground truth to estimator) =====
  parameter Real lm_x = 5.0 "Landmark x position [m]";
  parameter Real lm_y = 0.0 "Landmark y position [m]";

  // ===== COVARIANCE PARAMETERS =====
  parameter Real Q_pos = 0.001 "Position process noise rate [m2/s]";
  parameter Real Q_vel = 0.010 "Velocity process noise rate [(m/s)2/s]";
  parameter Real Q_att = 0.001 "Attitude process noise rate [rad2/s]";
  parameter Real Q_bias = 1.0e-5 "Bias process noise rate [(rad/s)2/s]";
  parameter Real R_enc_v = 1.0e-4 "Encoder velocity measurement variance [(m/s)2]";
  parameter Real R_enc_w = 1.0e-4 "Encoder yaw-rate measurement variance [(rad/s)2]";
  parameter Real R_lm_r = 2.5e-3 "Landmark range measurement variance [m2]";
  parameter Real R_lm_b = 4.0e-4 "Landmark bearing measurement variance [rad2]";
  parameter Real R_gyro = 4.0e-6 "Gyro measurement variance [(rad/s)2]";
  parameter Real R_accel = 2.5e-3 "Accel measurement variance [(m/s2)2]";
  parameter Real P_min = 1.0e-6 "Covariance floor";

  // ===== TIMESTAMP =====
  Real t_stamp "Synchronized timestamp [s]";

  // ===== PLANT TRUE STATES =====
  Real x(start=0.0, fixed=true) "True x position [m]";
  Real y(start=0.0, fixed=true) "True y position [m]";
  Real theta(start=0.0, fixed=true) "True heading [rad]";
  Real v(start=0.0, fixed=true) "True linear velocity [m/s]";
  Real omega(start=0.0, fixed=true) "True yaw rate [rad/s]";

  // ===== ACTUATOR COMMANDS AND SATURATED OUTPUTS =====
  Real tau_L_cmd "Left wheel torque command [N.m]";
  Real tau_R_cmd "Right wheel torque command [N.m]";
  Real tau_L "Saturated left torque [N.m]";
  Real tau_R "Saturated right torque [N.m]";

  // ===== WHEEL KINEMATICS AND BODY ACCELERATION =====
  Real omega_wL "Left wheel angular velocity [rad/s]";
  Real omega_wR "Right wheel angular velocity [rad/s]";
  Real a_body "Body-frame longitudinal acceleration [m/s2]";

  // ===== BIAS STEP INJECTION SIGNAL =====
  Real bias_inject "Injected bias step [rad/s]";

  // ===== SENSOR MEASUREMENTS (with frame annotations) =====
  Real enc_L_meas "Left encoder measurement [rad/s] (wheel frame)";
  Real enc_R_meas "Right encoder measurement [rad/s] (wheel frame)";
  Real gyro_meas "Z-gyro measurement [rad/s] (body frame)";
  Real accel_meas "X-accel measurement [m/s2] (body frame)";
  Real lm_range_meas "Landmark range measurement [m] (world frame)";
  Real lm_bearing_meas "Landmark bearing measurement [rad] (world frame)";

  // ===== DETERMINISTIC NOISE SIGNALS =====
  Real n_encL, n_encR, n_gyro, n_accel, n_lm_r, n_lm_b;

  // ===== ESTIMATOR STATES =====
  Real x_est(start=0.0, fixed=true) "Estimated x [m]";
  Real y_est(start=0.0, fixed=true) "Estimated y [m]";
  Real theta_est(start=0.01, fixed=true) "Estimated heading [rad]";
  Real v_est(start=0.0, fixed=true) "Estimated velocity [m/s]";
  Real b_gyro_est(start=0.0, fixed=true) "Estimated z-gyro bias [rad/s]";
  Real b_accel_est(start=0.0, fixed=true) "Estimated x-accel bias [m/s2]";
  Real omega_est "Estimated yaw rate [rad/s] (algebraic, from gyro)";

  // ===== ESTIMATOR INTERMEDIATES =====
  Real v_from_enc "Velocity reconstructed from encoders [m/s]";
  Real omega_from_enc "Yaw rate reconstructed from encoders [rad/s]";
  Real exp_lm_range "Expected landmark range from estimate [m]";
  Real exp_lm_bearing "Expected landmark bearing from estimate [rad]";
  Real dir_x "Unit direction x from landmark to estimate";
  Real dir_y "Unit direction y from landmark to estimate";
  Real innov_v "Velocity innovation [m/s]";
  Real innov_w "Yaw rate innovation [rad/s]";
  Real innov_lm_r "Landmark range innovation [m]";
  Real innov_lm_b "Landmark bearing innovation [rad]";

  // ===== COVARIANCE DIAGONAL (finite, positive) =====
  Real P_x(start=0.10, fixed=true) "X position covariance [m2]";
  Real P_y(start=0.10, fixed=true) "Y position covariance [m2]";
  Real P_th(start=0.05, fixed=true) "Heading covariance [rad2]";
  Real P_v(start=0.05, fixed=true) "Velocity covariance [(m/s)2]";
  Real P_bg(start=1.0e-4, fixed=true) "Gyro bias covariance [(rad/s)2]";
  Real P_ba(start=1.0e-4, fixed=true) "Accel bias covariance [(m/s2)2]";
  Real P_w "Yaw rate covariance [(rad/s)2] (algebraic)";

  // ===== REFERENCE TRAJECTORY =====
  Real x_ref "Reference x [m]";
  Real y_ref "Reference y [m]";
  Real theta_ref "Reference heading [rad]";
  Real v_ref "Reference velocity [m/s]";
  Real omega_ref "Reference yaw rate [rad/s]";

  // ===== CONTROLLER INTERMEDIATES =====
  Real err_x_body "Body-frame longitudinal position error [m]";
  Real err_y_body "Body-frame lateral position error [m]";
  Real v_cmd "Commanded velocity [m/s]";
  Real omega_cmd "Commanded yaw rate [rad/s]";
  Real F_total "Total force command [N]";
  Real T_total "Total torque command [N.m]";

  // ===== TRACKING AND ESTIMATION ERROR BANDS =====
  Real err_pos "Position tracking error [m]";
  Real err_att "Attitude tracking error [rad]";
  Real track_err "Primary tracking error [m or rad]";
  Real b_gyro_err "Gyro bias estimation error [rad/s]";
  Real b_accel_err "Accel bias estimation error [m/s2]";

equation
  // ===== SYNCHRONIZED TIMESTAMP =====
  t_stamp = time;

  // ===== BIAS STEP INJECTION (middle third: 4 s to 8 s of 12 s) =====
  if time >= 4.0 and time <= 8.0 then
    bias_inject = bias_step;
  else
    bias_inject = 0.0;
  end if;

  // ===== PLANT DYNAMICS (differential drive) =====
  // F_L = tau_L / r_w,  F_R = tau_R / r_w
  // m * der(v) = F_L + F_R - Cd * v
  // J * der(omega) = (F_R - F_L) * L/2 - Cr * omega
  der(x) = v * cos(theta);
  der(y) = v * sin(theta);
  der(theta) = omega;
  der(v) = (tau_L / r_w + tau_R / r_w - Cd * v) / m;
  der(omega) = ((tau_R - tau_L) / r_w * L / 2.0 - Cr * omega) / J;

  // Body acceleration from dynamics (avoids der(v) in sensor path)
  a_body = (tau_L / r_w + tau_R / r_w - Cd * v) / m;

  // Wheel angular velocities
  omega_wL = (v - omega * L / 2.0) / r_w;
  omega_wR = (v + omega * L / 2.0) / r_w;

  // ===== DETERMINISTIC BOUNDED NOISE (sinusoidal for FMU reproducibility) =====
  n_encL = sigma_enc * sin(2.0 * 3.14159265358979 * 7.3 * time);
  n_encR = sigma_enc * sin(2.0 * 3.14159265358979 * 7.7 * time + 1.3);
  n_gyro = sigma_gyro_z * sin(2.0 * 3.14159265358979 * 5.3 * time + 0.7);
  n_accel = sigma_accel_x * sin(2.0 * 3.14159265358979 * 3.7 * time + 2.1);
  n_lm_r = sigma_lm_r * sin(2.0 * 3.14159265358979 * 4.1 * time + 0.3);
  n_lm_b = sigma_lm_b * sin(2.0 * 3.14159265358979 * 6.1 * time + 1.7);

  // ===== SENSOR MODELS (noise + bias, no ground truth to estimator) =====
  // Wheel encoders (wheel frame)
  enc_L_meas = omega_wL + n_encL;
  enc_R_meas = omega_wR + n_encR;
  // IMU z-gyro (body frame) with true bias + step injection + noise
  gyro_meas = omega + b_gyro_z_0 + bias_inject + n_gyro;
  // IMU x-accel (body frame) with true bias + noise
  accel_meas = a_body + b_accel_x_0 + n_accel;
  // Landmark range and bearing (world frame)
  lm_range_meas = sqrt((x - lm_x)^2 + (y - lm_y)^2) + n_lm_r;
  lm_bearing_meas = atan2(lm_y - y, lm_x - x) - theta + n_lm_b;

  // ===== REFERENCE TRAJECTORY (bounded circular path, starts at origin) =====
  x_ref = R_path * sin(w_path * time);
  y_ref = R_path * (1.0 - cos(w_path * time));
  theta_ref = w_path * time;
  v_ref = v_path;
  omega_ref = w_path;

  // ===== CONTROLLER (feedback from estimated state, no ground truth) =====
  // Position error in body frame
  err_x_body = (x_ref - x_est) * cos(theta_est) + (y_ref - y_est) * sin(theta_est);
  err_y_body = -(x_ref - x_est) * sin(theta_est) + (y_ref - y_est) * cos(theta_est);
  // Cascaded velocity and yaw-rate commands
  v_cmd = v_ref + kp_pos * err_x_body;
  omega_cmd = omega_ref + kp_h * (theta_ref - theta_est) + kp_lat * err_y_body;
  // Force and torque commands from PD on estimated velocity and yaw rate
  F_total = m * kp_v * (v_cmd - v_est) + Cd * v_est;
  T_total = J * kp_w * (omega_cmd - omega_est) + Cr * omega_est;
  // Map to per-wheel torques
  tau_L_cmd = F_total * r_w / 2.0 - T_total * r_w / L;
  tau_R_cmd = F_total * r_w / 2.0 + T_total * r_w / L;
  // Actuator saturation
  tau_L = max(-tau_max, min(tau_max, tau_L_cmd));
  tau_R = max(-tau_max, min(tau_max, tau_R_cmd));

  // ===== ESTIMATOR (continuous-time EKF-like, asynchronous architecture) =====
  // Encoder-based reconstruction
  v_from_enc = (enc_L_meas + enc_R_meas) * r_w / 2.0;
  omega_from_enc = (enc_R_meas - enc_L_meas) * r_w / L;
  // Expected landmark measurements from estimate (zero-error branch: +1e-6 floor)
  exp_lm_range = sqrt((x_est - lm_x)^2 + (y_est - lm_y)^2 + 1.0e-6);
  exp_lm_bearing = atan2(lm_y - y_est, lm_x - x_est) - theta_est;
  // Unit direction from landmark to estimate
  dir_x = (x_est - lm_x) / exp_lm_range;
  dir_y = (y_est - lm_y) / exp_lm_range;
  // Innovations
  innov_v = v_from_enc - v_est;
  innov_w = omega_from_enc - omega_est;
  innov_lm_r = lm_range_meas - exp_lm_range;
  innov_lm_b = lm_bearing_meas - exp_lm_bearing;
  // Algebraic yaw-rate estimate from gyro minus estimated bias
  omega_est = gyro_meas - b_gyro_est;
  // State propagation with innovation corrections
  der(x_est) = v_est * cos(theta_est) + kpx * innov_lm_r * dir_x;
  der(y_est) = v_est * sin(theta_est) + kpy * innov_lm_r * dir_y;
  der(theta_est) = omega_est + kpt * innov_lm_b;
  der(v_est) = (accel_meas - b_accel_est) + kpv * innov_v;
  der(b_gyro_est) = -kbg * innov_w;
  der(b_accel_est) = -kba * innov_v;

  // ===== COVARIANCE PROPAGATION (simplified scalar, finite and positive) =====
  // der(P) = Q - k*P  =>  P_ss = Q/k > 0,  P cannot cross zero
  der(P_x) = Q_pos - kpx * P_x;
  der(P_y) = Q_pos - kpy * P_y;
  der(P_th) = Q_att - kpt * P_th;
  der(P_v) = Q_vel - kpv * P_v;
  der(P_bg) = Q_bias - kbg * P_bg;
  der(P_ba) = Q_bias - kba * P_ba;
  P_w = R_gyro + P_bg;

  // ===== TRACKING ERROR BANDS =====
  err_pos = sqrt((x - x_ref)^2 + (y - y_ref)^2);
  err_att = abs(theta - theta_ref);
  track_err = max(err_pos, err_att);

  // ===== BIAS CONVERGENCE METRICS =====
  b_gyro_err = (b_gyro_z_0 + bias_inject) - b_gyro_est;
  b_accel_err = b_accel_x_0 - b_accel_est;

  annotation(
    experiment(StartTime = 0, StopTime = 12.0, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info = "WheelIMULocalizeC: 125 Hz, 12 s. Plant: 16 kg differential drive. "
      "Sensors: wheel encoders, 6-axis IMU (planar: z-gyro, x-accel), fixed landmark. "
      "Estimator: continuous-time EKF-like observer with bias states. "
      "Bias step 0.036 rad/s injected at t=4..8 s. Torque limit 9.2 N.m per wheel. "
      "Asynchronous update architecture via continuous-time innovation feedback. "
      "Assumed parameters (J, r_w, L, Cd, Cr) are labeled; values not stated in "
      "requirements are treated as design assumptions.")
  );
end WheelIMULocalizeC;