model MapRigLocalizeB
  "Robotic sensing and estimation: estimate pose, velocity, and sensor biases while following a bounded route"

  // ============ Physical Parameters (from requirement) ============
  parameter Real mass = 22.0 "Mobile base mass [kg]";
  parameter Real wheel_radius = 0.1 "Wheel radius [m]";
  parameter Real wheel_base = 0.4 "Wheel separation [m]";
  parameter Real Izz = 1.1 "Yaw moment of inertia [kg.m2]";
  parameter Real max_torque = 9.84 "Allowed command magnitude per wheel [N.m]";
  parameter Real lidar_range = 20.0 "Planar lidar maximum range [m]";
  parameter Real drag_lin = 1.0 "Linear drag coefficient [N.s/m]";
  parameter Real drag_yaw = 0.2 "Yaw drag coefficient [N.m.s/rad]";

  // ============ Sensor Rates (explicitly different) ============
  parameter Real rate_imu = 100.0 "IMU sample rate [Hz]";
  parameter Real rate_enc = 50.0 "Wheel encoder sample rate [Hz]";
  parameter Real rate_lidar = 25.0 "Lidar sample rate [Hz]";
  parameter Real rate_rgbd = 10.0 "RGB-D camera sample rate [Hz]";

  // ============ Sensor Standard Deviations ============
  parameter Real std_imu_gyro = 0.01 "IMU gyroscope std dev [rad/s]";
  parameter Real std_imu_acc = 0.1 "IMU accelerometer std dev [m/s2]";
  parameter Real std_enc = 0.005 "Wheel encoder std dev [rad/s]";
  parameter Real std_lidar = 0.05 "Lidar range std dev [m]";
  parameter Real std_rgbd = 0.02 "RGB-D bearing std dev [rad]";

  // ============ Sensor Frame Identifiers ============
  parameter Integer frame_imu = 1 "IMU frame identifier";
  parameter Integer frame_enc = 2 "Wheel encoder frame identifier";
  parameter Integer frame_lidar = 3 "Lidar frame identifier";
  parameter Integer frame_rgbd = 4 "RGB-D camera frame identifier";

  // ============ Disturbance ============
  parameter Real bias_step = 0.028 "Injected sensor-bias step disturbance [unit]";
  parameter Real t_disturb_start = 10.0 / 3.0 "Middle third start time [s]";
  parameter Real t_disturb_end = 20.0 / 3.0 "Middle third end time [s]";

  // ============ Mission Parameters ============
  parameter Real sim_duration = 10.0 "Simulation duration [s]";
  parameter Real tracking_threshold = 0.24 "Primary tracking error threshold [m or rad]";
  parameter Real t_convergence_check = 6.5 "Convergence check time [s]";

  // ============ Bounded Route ============
  parameter Real route_radius = 2.0 "Bounded route radius [m]";
  parameter Real route_omega = 0.5 "Route angular velocity [rad/s]";

  // ============ Fixed Landmarks (external references, no ground truth to estimator) ============
  parameter Real lm1_x = 5.0 "Landmark 1 x position [m]";
  parameter Real lm1_y = 0.0 "Landmark 1 y position [m]";
  parameter Real lm2_x = -3.0 "Landmark 2 x position [m]";
  parameter Real lm2_y = 4.0 "Landmark 2 y position [m]";
  parameter Real lm3_x = 0.0 "Landmark 3 x position [m]";
  parameter Real lm3_y = -5.0 "Landmark 3 y position [m]";

  // ============ Estimator Gains ============
  parameter Real k_lidar_pos = 3.0 "Lidar position correction gain";
  parameter Real k_rgbd_att = 3.0 "RGB-D attitude correction gain";
  parameter Real k_bias_imu = 5.0 "IMU bias estimation gain";
  parameter Real k_bias_enc = 20.0 "Encoder bias estimation gain";
  parameter Real k_bias_lidar = 5.0 "Lidar bias estimation gain";
  parameter Real k_bias_rgbd = 5.0 "RGB-D bias estimation gain";

  // ============ Covariance Parameters ============
  parameter Real Q_pos = 0.001 "Position process noise [m2/s]";
  parameter Real Q_att = 0.001 "Attitude process noise [rad2/s]";
  parameter Real Q_bias = 0.0001 "Bias process noise";
  parameter Real k_cov_decay = 0.5 "Covariance decay rate";

  // ============ Controller Gains ============
  parameter Real k_pos_ctrl = 50.0 "Position controller gain";
  parameter Real k_vel_ctrl = 20.0 "Velocity controller gain";
  parameter Real k_heading_ctrl = 50.0 "Heading controller gain";
  parameter Real k_yawrate_ctrl = 20.0 "Yaw rate controller gain";

  // ============ True States ============
  Real x(start = route_radius, fixed = true) "True x position [m]";
  Real y(start = 0.0, fixed = true) "True y position [m]";
  Real theta(start = 1.57079632679490, fixed = true) "True heading [rad]";
  Real v(start = 1.0, fixed = true) "True forward speed [m/s]";
  Real omega(start = 0.5, fixed = true) "True yaw rate [rad/s]";
  Real vx "True x velocity [m/s]";
  Real vy "True y velocity [m/s]";

  // ============ Actuator (bounded wheel drives) ============
  Real T_left_cmd "Left wheel torque command [N.m]";
  Real T_right_cmd "Right wheel torque command [N.m]";
  Real T_left "Left wheel applied (bounded) torque [N.m]";
  Real T_right "Right wheel applied (bounded) torque [N.m]";
  Real dist_force_cmd "Commanded drive force [N]";
  Real yaw_torque_cmd "Commanded yaw torque [N.m]";
  Real dist_force "Actual drive force [N]";
  Real yaw_torque "Actual yaw torque [N.m]";

  // ============ Route Reference ============
  Real x_ref "Reference x [m]";
  Real y_ref "Reference y [m]";
  Real theta_ref "Reference heading [rad]";
  Real v_ref "Reference forward speed [m/s]";
  Real omega_ref "Reference yaw rate [rad/s]";

  // ============ True Biases ============
  Real b_imu_gyro_true "True IMU gyro bias [rad/s]";
  Real b_enc_true "True encoder bias [rad/s]";
  Real b_lidar_true "True lidar range bias [m]";
  Real b_rgbd_true "True RGB-D bearing bias [rad]";

  // ============ Estimated States (EKF) ============
  Real x_est(start = route_radius, fixed = true) "Estimated x [m]";
  Real y_est(start = 0.0, fixed = true) "Estimated y [m]";
  Real theta_est(start = 1.57079632679490, fixed = true) "Estimated heading [rad]";
  Real b_imu_est(start = 0.0, fixed = true) "Estimated IMU gyro bias [rad/s]";
  Real b_enc_est(start = 0.0, fixed = true) "Estimated encoder bias [rad/s]";
  Real b_lidar_est(start = 0.0, fixed = true) "Estimated lidar range bias [m]";
  Real b_rgbd_est(start = 0.0, fixed = true) "Estimated RGB-D bearing bias [rad]";
  Real v_est "Estimated forward speed [m/s]";
  Real omega_est "Estimated yaw rate [rad/s]";

  // ============ Covariance (finite positive) ============
  Real P_xx(start = 0.5, fixed = true) "Covariance x [m2]";
  Real P_yy(start = 0.5, fixed = true) "Covariance y [m2]";
  Real P_tt(start = 0.1, fixed = true) "Covariance theta [rad2]";
  Real P_bimu(start = 0.01, fixed = true) "Covariance IMU bias";
  Real P_benc(start = 0.01, fixed = true) "Covariance encoder bias";
  Real P_blidar(start = 0.01, fixed = true) "Covariance lidar bias";
  Real P_brgbd(start = 0.01, fixed = true) "Covariance RGB-D bias";

  // ============ Sampled Sensor Measurements (rate, timestamp, frame preserved) ============
  discrete Real meas_imu_gyro(start = 0.5) "Sampled IMU gyro [rad/s], frame 1, 100 Hz";
  discrete Real meas_imu_acc(start = 0.0) "Sampled IMU accel [m/s2], frame 1, 100 Hz";
  discrete Real meas_enc_left(start = 9.0) "Sampled left wheel encoder [rad/s], frame 2, 50 Hz";
  discrete Real meas_enc_right(start = 11.0) "Sampled right wheel encoder [rad/s], frame 2, 50 Hz";
  discrete Real meas_lidar1(start = 3.0) "Sampled lidar range to LM1 [m], frame 3, 25 Hz";
  discrete Real meas_lidar2(start = 6.4031242) "Sampled lidar range to LM2 [m], frame 3, 25 Hz";
  discrete Real meas_lidar3(start = 5.3851648) "Sampled lidar range to LM3 [m], frame 3, 25 Hz";
  discrete Real meas_rgbd_bearing(start = -1.57079632679490) "Sampled RGB-D bearing [rad], frame 4, 10 Hz";

  // ============ Sensor Timestamps ============
  discrete Real ts_imu(start = 0.0) "IMU timestamp [s]";
  discrete Real ts_enc(start = 0.0) "Encoder timestamp [s]";
  discrete Real ts_lidar(start = 0.0) "Lidar timestamp [s]";
  discrete Real ts_rgbd(start = 0.0) "RGB-D timestamp [s]";

  // ============ Error Metrics ============
  Real pos_error "Position estimation error [m]";
  Real att_error "Attitude estimation error [rad]";
  Real tracking_error "Primary tracking error [m or rad]";
  Real route_error "Route following error [m]";
  Real bias_error_imu "IMU bias estimation error [rad/s]";
  Real bias_error_enc "Encoder bias estimation error [rad/s]";
  Real bias_error_lidar "Lidar bias estimation error [m]";
  Real bias_error_rgbd "RGB-D bias estimation error [rad]";
  Boolean converged "Convergence flag: tracking error below threshold after 6.5 s";
  Boolean disturbance_active "Disturbance active flag";

protected
  Real raw_imu_gyro "Raw IMU gyro [rad/s]";
  Real raw_imu_acc "Raw IMU accel [m/s2]";
  Real raw_enc_left "Raw left wheel encoder [rad/s]";
  Real raw_enc_right "Raw right wheel encoder [rad/s]";
  Real raw_lidar1 "Raw lidar range to LM1 [m]";
  Real raw_lidar2 "Raw lidar range to LM2 [m]";
  Real raw_lidar3 "Raw lidar range to LM3 [m]";
  Real raw_rgbd_bearing "Raw RGB-D bearing [rad]";
  Real range1_true "True range to LM1 [m]";
  Real range2_true "True range to LM2 [m]";
  Real range3_true "True range to LM3 [m]";
  Real range1_est "Estimated range to LM1 [m]";
  Real range2_est "Estimated range to LM2 [m]";
  Real range3_est "Estimated range to LM3 [m]";
  Real bearing1_true "True bearing to LM1 [rad]";
  Real bearing1_est "Estimated bearing to LM1 [rad]";
  Real lidar_res1 "Lidar residual LM1 [m]";
  Real lidar_res2 "Lidar residual LM2 [m]";
  Real lidar_res3 "Lidar residual LM3 [m]";
  Real lidar_residual "Average lidar residual [m]";
  Real rgbd_residual "RGB-D bearing residual [rad]";
  Real lidar_corr_x "Lidar x position correction [m]";
  Real lidar_corr_y "Lidar y position correction [m]";
  Real rgbd_corr "RGB-D heading correction [rad]";
  Real pos_err_x "Controller position error x [m]";
  Real pos_err_y "Controller position error y [m]";
  Real heading_err "Controller heading error [rad]";
  Real speed_err "Controller speed error [m/s]";
  Real yawrate_err "Controller yaw rate error [rad/s]";
  Real pos_err_fwd "Forward position error [m]";
  Real noise_imu_gyro "IMU gyro noise [rad/s]";
  Real noise_imu_acc "IMU accel noise [m/s2]";
  Real noise_enc "Encoder noise [rad/s]";
  Real noise_lidar "Lidar noise [m]";
  Real noise_rgbd "RGB-D noise [rad]";

equation
  // ============ True Plant Dynamics ============
  vx = v * cos(theta);
  vy = v * sin(theta);
  der(x) = vx;
  der(y) = vy;
  der(theta) = omega;
  der(v) = (dist_force - drag_lin * v) / mass;
  der(omega) = (yaw_torque - drag_yaw * omega) / Izz;

  // ============ Bounded Actuator (9.84 N.m per wheel) ============
  T_left = max(-max_torque, min(max_torque, T_left_cmd));
  T_right = max(-max_torque, min(max_torque, T_right_cmd));
  dist_force = (T_left + T_right) / wheel_radius;
  yaw_torque = (T_right - T_left) * wheel_base / (2.0 * wheel_radius);

  // ============ Route Reference (bounded circular path) ============
  x_ref = route_radius * cos(route_omega * time);
  y_ref = route_radius * sin(route_omega * time);
  theta_ref = atan2(cos(route_omega * time), -sin(route_omega * time));
  v_ref = route_radius * route_omega;
  omega_ref = route_omega;

  // ============ Controller (uses estimated state, not ground truth) ============
  pos_err_x = x_ref - x_est;
  pos_err_y = y_ref - y_est;
  heading_err = atan2(sin(theta_ref - theta_est), cos(theta_ref - theta_est));
  speed_err = v_ref - v_est;
  yawrate_err = omega_ref - omega_est;
  pos_err_fwd = cos(theta_est) * pos_err_x + sin(theta_est) * pos_err_y;
  dist_force_cmd = k_pos_ctrl * pos_err_fwd + k_vel_ctrl * speed_err;
  yaw_torque_cmd = k_heading_ctrl * heading_err + k_yawrate_ctrl * yawrate_err;
  T_left_cmd = dist_force_cmd * wheel_radius / 2.0 - yaw_torque_cmd * wheel_radius / wheel_base;
  T_right_cmd = dist_force_cmd * wheel_radius / 2.0 + yaw_torque_cmd * wheel_radius / wheel_base;

  // ============ True Bias with Step Disturbance (middle third) ============
  disturbance_active = time >= t_disturb_start and time < t_disturb_end;
  b_imu_gyro_true = if disturbance_active then bias_step else 0.0;
  b_enc_true = if disturbance_active then bias_step else 0.0;
  b_lidar_true = if disturbance_active then bias_step else 0.0;
  b_rgbd_true = if disturbance_active then bias_step else 0.0;

  // ============ Deterministic Pseudo-Noise ============
  noise_imu_gyro = std_imu_gyro * (sin(time * 37.0) + 0.5 * sin(time * 53.0));
  noise_imu_acc = std_imu_acc * (sin(time * 41.0) + 0.5 * sin(time * 61.0));
  noise_enc = std_enc * (sin(time * 43.0) + 0.5 * sin(time * 59.0));
  noise_lidar = std_lidar * (sin(time * 47.0) + 0.5 * sin(time * 67.0));
  noise_rgbd = std_rgbd * (sin(time * 31.0) + 0.5 * sin(time * 71.0));

  // ============ Raw Sensor Measurements ============
  raw_imu_gyro = omega + b_imu_gyro_true + noise_imu_gyro;
  raw_imu_acc = (dist_force - drag_lin * v) / mass + noise_imu_acc;
  raw_enc_left = (v - omega * wheel_base / 2.0) / wheel_radius + b_enc_true + noise_enc;
  raw_enc_right = (v + omega * wheel_base / 2.0) / wheel_radius + b_enc_true + noise_enc;
  range1_true = sqrt((lm1_x - x) ^ 2 + (lm1_y - y) ^ 2);
  range2_true = sqrt((lm2_x - x) ^ 2 + (lm2_y - y) ^ 2);
  range3_true = sqrt((lm3_x - x) ^ 2 + (lm3_y - y) ^ 2);
  raw_lidar1 = range1_true + b_lidar_true + noise_lidar;
  raw_lidar2 = range2_true + b_lidar_true + noise_lidar;
  raw_lidar3 = range3_true + b_lidar_true + noise_lidar;
  bearing1_true = atan2(lm1_y - y, lm1_x - x) - theta;
  raw_rgbd_bearing = bearing1_true + b_rgbd_true + noise_rgbd;

  // ============ Asynchronous Sensor Sampling (different rates and offsets) ============
  // IMU: 100 Hz, frame 1, no offset
  when sample(0.0, 1.0 / rate_imu) then
    meas_imu_gyro = raw_imu_gyro;
    meas_imu_acc = raw_imu_acc;
    ts_imu = time;
  end when;

  // Wheel encoders: 50 Hz, frame 2, 5 ms offset (asynchronous)
  when sample(0.005, 1.0 / rate_enc) then
    meas_enc_left = raw_enc_left;
    meas_enc_right = raw_enc_right;
    ts_enc = time;
  end when;

  // Lidar: 25 Hz, frame 3, 3 ms offset (asynchronous)
  when sample(0.003, 1.0 / rate_lidar) then
    meas_lidar1 = raw_lidar1;
    meas_lidar2 = raw_lidar2;
    meas_lidar3 = raw_lidar3;
    ts_lidar = time;
  end when;

  // RGB-D camera: 10 Hz, frame 4, 7 ms offset (asynchronous)
  when sample(0.007, 1.0 / rate_rgbd) then
    meas_rgbd_bearing = raw_rgbd_bearing;
    ts_rgbd = time;
  end when;

  // ============ Estimator (continuous-time EKF with asynchronous updates) ============
  // Velocity from encoders (bias-corrected)
  v_est = wheel_radius * (meas_enc_left + meas_enc_right) / 2.0 - b_enc_est * wheel_radius;
  // Yaw rate from IMU (bias-corrected)
  omega_est = meas_imu_gyro - b_imu_est;

  // Predicted ranges from estimated pose
  range1_est = sqrt((lm1_x - x_est) ^ 2 + (lm1_y - y_est) ^ 2);
  range2_est = sqrt((lm2_x - x_est) ^ 2 + (lm2_y - y_est) ^ 2);
  range3_est = sqrt((lm3_x - x_est) ^ 2 + (lm3_y - y_est) ^ 2);

  // Predicted bearing from estimated pose and heading
  bearing1_est = atan2(lm1_y - y_est, lm1_x - x_est) - theta_est;

  // Lidar residuals (measured - predicted, bias-corrected)
  lidar_res1 = meas_lidar1 - b_lidar_est - range1_est;
  lidar_res2 = meas_lidar2 - b_lidar_est - range2_est;
  lidar_res3 = meas_lidar3 - b_lidar_est - range3_est;
  lidar_residual = (lidar_res1 + lidar_res2 + lidar_res3) / 3.0;

  // RGB-D residual
  rgbd_residual = meas_rgbd_bearing - b_rgbd_est - bearing1_est;

  // Position correction from lidar (unit-vector weighted, zero-error safe)
  lidar_corr_x = (lidar_res1 * (x_est - lm1_x) / max(range1_est, 0.01)
                + lidar_res2 * (x_est - lm2_x) / max(range2_est, 0.01)
                + lidar_res3 * (x_est - lm3_x) / max(range3_est, 0.01)) / 3.0;
  lidar_corr_y = (lidar_res1 * (y_est - lm1_y) / max(range1_est, 0.01)
                + lidar_res2 * (y_est - lm2_y) / max(range2_est, 0.01)
                + lidar_res3 * (y_est - lm3_y) / max(range3_est, 0.01)) / 3.0;

  // Heading correction from RGB-D (angle-wrapped)
  rgbd_corr = atan2(sin(rgbd_residual), cos(rgbd_residual));

  // Estimator state dynamics (prediction + correction)
  der(x_est) = v_est * cos(theta_est) + k_lidar_pos * lidar_corr_x;
  der(y_est) = v_est * sin(theta_est) + k_lidar_pos * lidar_corr_y;
  der(theta_est) = omega_est - k_rgbd_att * rgbd_corr;

  // Bias estimation (driven by correction residuals for convergence)
  der(b_imu_est) = k_bias_imu * rgbd_corr;
  der(b_enc_est) = -k_bias_enc * (lidar_corr_x * cos(theta_est) + lidar_corr_y * sin(theta_est));
  der(b_lidar_est) = k_bias_lidar * lidar_residual;
  der(b_rgbd_est) = k_bias_rgbd * rgbd_residual;

  // ============ Covariance Propagation (finite positive, bounded) ============
  der(P_xx) = Q_pos - (k_cov_decay + k_lidar_pos) * P_xx;
  der(P_yy) = Q_pos - (k_cov_decay + k_lidar_pos) * P_yy;
  der(P_tt) = Q_att - (k_cov_decay + k_rgbd_att) * P_tt;
  der(P_bimu) = Q_bias - (k_cov_decay + k_bias_imu) * P_bimu;
  der(P_benc) = Q_bias - (k_cov_decay + k_bias_enc) * P_benc;
  der(P_blidar) = Q_bias - (k_cov_decay + k_bias_lidar) * P_blidar;
  der(P_brgbd) = Q_bias - (k_cov_decay + k_bias_rgbd) * P_brgbd;

  // ============ Error Metrics and Convergence ============
  pos_error = sqrt((x - x_est) ^ 2 + (y - y_est) ^ 2);
  att_error = abs(atan2(sin(theta - theta_est), cos(theta - theta_est)));
  route_error = sqrt((x_ref - x) ^ 2 + (y_ref - y) ^ 2);
  tracking_error = route_error;
  bias_error_imu = abs(b_imu_gyro_true - b_imu_est);
  bias_error_enc = abs(b_enc_true - b_enc_est);
  bias_error_lidar = abs(b_lidar_true - b_lidar_est);
  bias_error_rgbd = abs(b_rgbd_true - b_rgbd_est);
  converged = time >= t_convergence_check and tracking_error < tracking_threshold;

  annotation(
    experiment(StopTime = 10.0, Interval = 0.01, Tolerance = 1e-6),
    Documentation(info = "MapRigLocalizeB: Robotic sensing and estimation system.
      22 kg mobile base with 20 m planar lidar (25 Hz, frame 3), forward RGB-D camera (10 Hz, frame 4),
      wheel encoders (50 Hz, frame 2), and IMU (100 Hz, frame 1) at explicitly different rates and transforms.
      Continuous-time EKF with asynchronous multi-rate updates estimates pose, velocity, and four sensor biases.
      Fixed landmarks (LM1-LM3) provide external references without ground truth to the estimator.
      Bounded wheel drives limited to 9.84 N.m per wheel.
      0.028 sensor-bias step disturbance injected during middle third (3.33 s to 6.67 s).
      Run at 100 Hz for 10 s. Primary tracking error below 0.24 m/rad after 6.5 s.
      Covariance remains finite and positive. Synchronized state, command, and sensor traces retained.")
  );
end MapRigLocalizeB;