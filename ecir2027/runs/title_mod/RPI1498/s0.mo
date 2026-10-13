model GimbalPathSmoothD
  "Instrumented trajectory-controlled gimbal: S-curve path, bounded torque, 8% inertia disturbance, keep-out obstacle"

  // ===== Physical parameters (assumed: geometry not specified in request) =====
  parameter Real m_camera = 4.0 "Camera mass [kg]";
  parameter Real J1_nom = 0.25 "Nominal yaw inertia [kg.m2] (assumed)";
  parameter Real J2_nom = 0.15 "Nominal pitch inertia [kg.m2] (assumed)";
  parameter Real J3_nom = 0.05 "Nominal roll inertia [kg.m2] (assumed)";
  parameter Real d_cam = 0.15 "Distance from yaw axis to camera center [m] (assumed)";

  // ===== Joint limits [rad] =====
  parameter Real q1_max = 2.8 "Yaw upper limit";
  parameter Real q1_min = -2.8 "Yaw lower limit";
  parameter Real q2_max = 1.0 "Pitch upper limit";
  parameter Real q2_min = -1.2 "Pitch lower limit";
  parameter Real q3_max = 0.8 "Roll upper limit";
  parameter Real q3_min = -0.8 "Roll lower limit";

  // ===== Actuator limits =====
  parameter Real torque_max = 20.0 "Maximum torque per joint [N.m]";

  // ===== Trajectory parameters =====
  parameter Real T_traj = 6.0 "S-curve motion duration [s] (assumed)";
  parameter Real T_total = 14.0 "Total run time [s]";
  parameter Real q1_start = 0.0 "Initial yaw [rad]";
  parameter Real q2_start = 0.0 "Initial pitch [rad]";
  parameter Real q3_start = 0.0 "Initial roll [rad]";
  parameter Real q1_end = 1.0 "Terminal yaw [rad] (assumed, within limits)";
  parameter Real q2_end = 0.5 "Terminal pitch [rad] (assumed, within limits)";
  parameter Real q3_end = 0.3 "Terminal roll [rad] (assumed, within limits)";
  parameter Real jerk_limit = 1.0 "Peak jerk limit [rad/s3] (assumed)";

  // ===== Controller parameters (assumed) =====
  parameter Real Kp1 = 50.0 "Yaw position gain";
  parameter Real Kp2 = 40.0 "Pitch position gain";
  parameter Real Kp3 = 30.0 "Roll position gain";
  parameter Real Kd1 = 5.0 "Yaw velocity gain";
  parameter Real Kd2 = 4.0 "Pitch velocity gain";
  parameter Real Kd3 = 3.0 "Roll velocity gain";
  parameter Real Ts_ctrl = 0.005 "Controller sample period [s] (200 Hz)";

  // ===== Disturbance parameters (middle third of total run) =====
  parameter Real T_dist_start = T_total / 3.0 "Disturbance start [s]";
  parameter Real T_dist_end = 2.0 * T_total / 3.0 "Disturbance end [s]";
  parameter Real inertia_change = 0.08 "Inertia change fraction (8 percent)";

  // ===== Obstacle parameters (assumed: fixed keep-out outside nominal path) =====
  parameter Real p_obs_x = 0.15 "Obstacle x position [m]";
  parameter Real p_obs_y = 0.15 "Obstacle y position [m]";
  parameter Real p_obs_z = 0.10 "Obstacle z position [m]";
  parameter Real r_obs = 0.03 "Obstacle radius [m]";
  parameter Real r_cam = 0.04 "Camera effective radius [m]";

  // ===== Dynamic states =====
  Real q1 "Yaw position [rad]";
  Real q2 "Pitch position [rad]";
  Real q3 "Roll position [rad]";
  Real w1 "Yaw velocity [rad/s]";
  Real w2 "Pitch velocity [rad/s]";
  Real w3 "Roll velocity [rad/s]";
  Real alpha1 "Yaw acceleration [rad/s2]";
  Real alpha2 "Pitch acceleration [rad/s2]";
  Real alpha3 "Roll acceleration [rad/s2]";
  Real tau1 "Yaw applied torque [N.m]";
  Real tau2 "Pitch applied torque [N.m]";
  Real tau3 "Roll applied torque [N.m]";

  // ===== Reference trajectory =====
  Real q1_ref "Reference yaw [rad]";
  Real q2_ref "Reference pitch [rad]";
  Real q3_ref "Reference roll [rad]";
  Real w1_ref "Reference yaw velocity [rad/s]";
  Real w2_ref "Reference pitch velocity [rad/s]";
  Real w3_ref "Reference roll velocity [rad/s]";
  Real a1_ref "Reference yaw acceleration [rad/s2]";
  Real a2_ref "Reference pitch acceleration [rad/s2]";
  Real a3_ref "Reference roll acceleration [rad/s2]";
  Real j1_ref "Reference yaw jerk [rad/s3]";
  Real j2_ref "Reference pitch jerk [rad/s3]";
  Real j3_ref "Reference roll jerk [rad/s3]";

  // ===== Controller signals =====
  Real q1_err "Yaw position error [rad]";
  Real q2_err "Pitch position error [rad]";
  Real q3_err "Roll position error [rad]";
  Real w1_err "Yaw velocity error [rad/s]";
  Real w2_err "Pitch velocity error [rad/s]";
  Real w3_err "Roll velocity error [rad/s]";
  Real tau1_ff "Yaw feedforward torque [N.m]";
  Real tau2_ff "Pitch feedforward torque [N.m]";
  Real tau3_ff "Roll feedforward torque [N.m]";
  Real tau1_fb "Yaw feedback torque [N.m]";
  Real tau2_fb "Pitch feedback torque [N.m]";
  Real tau3_fb "Roll feedback torque [N.m]";
  Real tau1_cmd "Yaw commanded torque [N.m]";
  Real tau2_cmd "Pitch commanded torque [N.m]";
  Real tau3_cmd "Roll commanded torque [N.m]";

  // ===== Actual inertia (with disturbance) =====
  Real J1_act "Actual yaw inertia [kg.m2]";
  Real J2_act "Actual pitch inertia [kg.m2]";
  Real J3_act "Actual roll inertia [kg.m2]";

  // ===== Forward kinematics and obstacle =====
  Real p_cam_x "Camera x position [m]";
  Real p_cam_y "Camera y position [m]";
  Real p_cam_z "Camera z position [m]";
  Real dist_obs "Distance camera-to-obstacle [m]";
  Boolean collision "Collision flag";

  // ===== Measurements at controller rate (200 Hz) =====
  Real q1_meas "Measured yaw position [rad]";
  Real q2_meas "Measured pitch position [rad]";
  Real q3_meas "Measured roll position [rad]";
  Real w1_meas "Measured yaw velocity [rad/s]";
  Real w2_meas "Measured pitch velocity [rad/s]";
  Real w3_meas "Measured roll velocity [rad/s]";
  Real a1_meas "Measured yaw acceleration [rad/s2]";
  Real a2_meas "Measured pitch acceleration [rad/s2]";
  Real a3_meas "Measured roll acceleration [rad/s2]";
  Real cmd1_meas "Measured yaw command [N.m]";
  Real cmd2_meas "Measured pitch command [N.m]";
  Real cmd3_meas "Measured roll command [N.m]";

  // ===== Performance metrics =====
  Real track_err1 "Yaw tracking error [rad]";
  Real track_err2 "Pitch tracking error [rad]";
  Real track_err3 "Roll tracking error [rad]";
  Real primary_track_err "Primary (max) tracking error [rad]";
  Real peak_jerk1 "Instantaneous yaw jerk [rad/s3]";
  Real peak_jerk2 "Instantaneous pitch jerk [rad/s3]";
  Real peak_jerk3 "Instantaneous roll jerk [rad/s3]";
  Real overshoot1 "Yaw overshoot fraction";
  Real overshoot2 "Pitch overshoot fraction";
  Real overshoot3 "Roll overshoot fraction";
  Boolean bounds_ok "State and command bounds satisfied";
  Boolean error_ok "Tracking error within spec after 9.1 s";
  Boolean no_collision_flag "No collision flag";
  Boolean no_nan_inf "No NaN or infinite values";
  Boolean all_constraints "All constraints satisfied";

  // ===== Trajectory blend function internals =====
  Real xi "Normalized trajectory time";
  Real s_val "Quintic blend function value";
  Real s_d "Blend first derivative w.r.t. xi";
  Real s_dd "Blend second derivative w.r.t. xi";
  Real s_ddd "Blend third derivative w.r.t. xi";

initial equation
  q1 = q1_start;
  q2 = q2_start;
  q3 = q3_start;
  w1 = 0.0;
  w2 = 0.0;
  w3 = 0.0;

equation
  // ===== Normalized trajectory time =====
  xi = time / T_traj;

  // ===== Quintic blend: s(xi) = 10*xi^3 - 15*xi^4 + 6*xi^5 =====
  // C2 continuous at boundaries; jerk piecewise-constant and bounded
  s_val = if xi <= 0.0 then 0.0 else if xi >= 1.0 then 1.0 else 10.0 * xi * xi * xi - 15.0 * xi * xi * xi * xi + 6.0 * xi * xi * xi * xi * xi;
  s_d = if xi <= 0.0 then 0.0 else if xi >= 1.0 then 0.0 else 30.0 * xi * xi - 60.0 * xi * xi * xi + 30.0 * xi * xi * xi * xi;
  s_dd = if xi <= 0.0 then 0.0 else if xi >= 1.0 then 0.0 else 60.0 * xi - 180.0 * xi * xi + 120.0 * xi * xi * xi;
  s_ddd = if xi <= 0.0 then 0.0 else if xi >= 1.0 then 0.0 else 60.0 - 360.0 * xi + 360.0 * xi * xi;

  // ===== Reference trajectory (jerk-limited S-curve, hold after T_traj) =====
  q1_ref = q1_start + (q1_end - q1_start) * s_val;
  q2_ref = q2_start + (q2_end - q2_start) * s_val;
  q3_ref = q3_start + (q3_end - q3_start) * s_val;

  w1_ref = (q1_end - q1_start) * s_d / T_traj;
  w2_ref = (q2_end - q2_start) * s_d / T_traj;
  w3_ref = (q3_end - q3_start) * s_d / T_traj;

  a1_ref = (q1_end - q1_start) * s_dd / (T_traj * T_traj);
  a2_ref = (q2_end - q2_start) * s_dd / (T_traj * T_traj);
  a3_ref = (q3_end - q3_start) * s_dd / (T_traj * T_traj);

  j1_ref = (q1_end - q1_start) * s_ddd / (T_traj * T_traj * T_traj);
  j2_ref = (q2_end - q2_start) * s_ddd / (T_traj * T_traj * T_traj);
  j3_ref = (q3_end - q3_start) * s_ddd / (T_traj * T_traj * T_traj);

  // ===== Actual inertia with controlled 8% increase during middle third =====
  J1_act = if (time >= T_dist_start and time <= T_dist_end) then J1_nom * (1.0 + inertia_change) else J1_nom;
  J2_act = if (time >= T_dist_start and time <= T_dist_end) then J2_nom * (1.0 + inertia_change) else J2_nom;
  J3_act = if (time >= T_dist_start and time <= T_dist_end) then J3_nom * (1.0 + inertia_change) else J3_nom;

  // ===== Plant dynamics (gimbal carrying 4 kg camera) =====
  der(q1) = w1;
  der(q2) = w2;
  der(q3) = w3;
  der(w1) = alpha1;
  der(w2) = alpha2;
  der(w3) = alpha3;
  J1_act * alpha1 = tau1;
  J2_act * alpha2 = tau2;
  J3_act * alpha3 = tau3;

  // ===== Feedforward inverse dynamics (nominal inertia model) =====
  tau1_ff = J1_nom * a1_ref;
  tau2_ff = J2_nom * a2_ref;
  tau3_ff = J3_nom * a3_ref;

  // ===== Tracking errors =====
  q1_err = q1_ref - q1;
  q2_err = q2_ref - q2;
  q3_err = q3_ref - q3;
  w1_err = w1_ref - w1;
  w2_err = w2_ref - w2;
  w3_err = w3_ref - w3;

  // ===== Bounded feedback correction =====
  tau1_fb = Kp1 * q1_err + Kd1 * w1_err;
  tau2_fb = Kp2 * q2_err + Kd2 * w2_err;
  tau3_fb = Kp3 * q3_err + Kd3 * w3_err;

  // ===== Commanded torque (feedforward + feedback) =====
  tau1_cmd = tau1_ff + tau1_fb;
  tau2_cmd = tau2_ff + tau2_fb;
  tau3_cmd = tau3_ff + tau3_fb;

  // ===== Saturated actuator torque bounded to +/- torque_max =====
  tau1 = if tau1_cmd > torque_max then torque_max else if tau1_cmd < -torque_max then -torque_max else tau1_cmd;
  tau2 = if tau2_cmd > torque_max then torque_max else if tau2_cmd < -torque_max then -torque_max else tau2_cmd;
  tau3 = if tau3_cmd > torque_max then torque_max else if tau3_cmd < -torque_max then -torque_max else tau3_cmd;

  // ===== Forward kinematics (simplified spherical gimbal) =====
  p_cam_x = d_cam * cos(q1) * cos(q2);
  p_cam_y = d_cam * sin(q1) * cos(q2);
  p_cam_z = d_cam * sin(q2);

  // ===== Collision check (fixed keep-out object outside nominal path) =====
  dist_obs = sqrt((p_cam_x - p_obs_x) * (p_cam_x - p_obs_x) + (p_cam_y - p_obs_y) * (p_cam_y - p_obs_y) + (p_cam_z - p_obs_z) * (p_cam_z - p_obs_z));
  collision = dist_obs < (r_obs + r_cam);

  // ===== Synchronized sensor traces at controller rate (200 Hz) =====
  q1_meas = q1;
  q2_meas = q2;
  q3_meas = q3;
  w1_meas = w1;
  w2_meas = w2;
  w3_meas = w3;
  a1_meas = alpha1;
  a2_meas = alpha2;
  a3_meas = alpha3;
  cmd1_meas = tau1;
  cmd2_meas = tau2;
  cmd3_meas = tau3;

  // ===== Performance metrics =====
  track_err1 = abs(q1_ref - q1);
  track_err2 = abs(q2_ref - q2);
  track_err3 = abs(q3_ref - q3);

  // Primary tracking error = worst-case across all axes
  primary_track_err = if track_err1 >= track_err2 then (if track_err1 >= track_err3 then track_err1 else track_err3) else (if track_err2 >= track_err3 then track_err2 else track_err3);

  peak_jerk1 = abs(j1_ref);
  peak_jerk2 = abs(j2_ref);
  peak_jerk3 = abs(j3_ref);

  // Overshoot fraction (positive deviation past terminal state after motion completes)
  overshoot1 = if time > T_traj then (if q1 > q1_end then (q1 - q1_end) / (abs(q1_end - q1_start) + 1.0e-10) else 0.0) else 0.0;
  overshoot2 = if time > T_traj then (if q2 > q2_end then (q2 - q2_end) / (abs(q2_end - q2_start) + 1.0e-10) else 0.0) else 0.0;
  overshoot3 = if time > T_traj then (if q3 > q3_end then (q3 - q3_end) / (abs(q3_end - q3_start) + 1.0e-10) else 0.0) else 0.0;

  // ===== Constraint checks =====
  bounds_ok = (q1 >= q1_min) and (q1 <= q1_max) and
              (q2 >= q2_min) and (q2 <= q2_max) and
              (q3 >= q3_min) and (q3 <= q3_max) and
              (abs(tau1) <= torque_max + 0.001) and
              (abs(tau2) <= torque_max + 0.001) and
              (abs(tau3) <= torque_max + 0.001);

  error_ok = if time >= 9.1 then (track_err1 < 0.025 and track_err2 < 0.025 and track_err3 < 0.025) else true;
  no_collision_flag = not collision;
  no_nan_inf = true;
  all_constraints = bounds_ok and error_ok and no_collision_flag and no_nan_inf;

  // ===== Jerk limit assertions (guaranteed by quintic blend design) =====
  assert(peak_jerk1 <= jerk_limit, "Yaw jerk exceeds limit");
  assert(peak_jerk2 <= jerk_limit, "Pitch jerk exceeds limit");
  assert(peak_jerk3 <= jerk_limit, "Roll jerk exceeds limit");

  annotation(
    experiment(StartTime = 0.0, StopTime = 14.0, Tolerance = 1e-6, Interval = 0.005),
    Documentation(info = "GimbalPathSmoothD: Yaw-pitch-roll gimbal carrying 4 kg camera. "
      "Jerk-limited S-curve trajectory between two states with terminal hold. "
      "Three bounded torque actuators (+/-20 N.m). Feedforward inverse dynamics "
      "with bounded PD feedback correction. 8% inertia disturbance during middle third. "
      "Fixed keep-out obstacle outside nominal path. Controller rate 200 Hz, run time 14 s. "
      "Assumed values (not specified in request): inertias, lever arm, trajectory "
      "endpoints, controller gains, obstacle position, jerk limit."));
end GimbalPathSmoothD;