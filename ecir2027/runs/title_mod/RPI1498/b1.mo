model GimbalPathSmoothD
  "Instrumented trajectory-controlled gimbal with S-curve path, bounded torque, inertia disturbance, and keep-out obstacle"

  // Physical parameters (assumed: detailed geometry not specified in request)
  parameter Real m_camera = 4.0 "Camera mass [kg]";
  parameter Real J1_nom = 0.25 "Nominal yaw inertia [kg.m2] (assumed)";
  parameter Real J2_nom = 0.15 "Nominal pitch inertia [kg.m2] (assumed)";
  parameter Real J3_nom = 0.05 "Nominal roll inertia [kg.m2] (assumed)";
  parameter Real d_cam = 0.15 "Lever arm from yaw axis to camera center [m] (assumed)";

  // Joint limits [rad]
  parameter Real q1_max = 2.8 "Yaw upper limit [rad]";
  parameter Real q1_min = -2.8 "Yaw lower limit [rad]";
  parameter Real q2_max = 1.0 "Pitch upper limit [rad]";
  parameter Real q2_min = -1.2 "Pitch lower limit [rad]";
  parameter Real q3_max = 0.8 "Roll upper limit [rad]";
  parameter Real q3_min = -0.8 "Roll lower limit [rad]";

  // Actuator limit
  parameter Real torque_max = 20.0 "Maximum torque per joint [N.m]";

  // Trajectory parameters (assumed endpoints within limits)
  parameter Real T_traj = 4.0 "S-curve motion duration [s] (assumed)";
  parameter Real T_total = 14.0 "Total run time [s]";
  parameter Real q1_end = 1.0 "Terminal yaw [rad] (assumed, within limits)";
  parameter Real q2_end = 0.5 "Terminal pitch [rad] (assumed, within limits)";
  parameter Real q3_end = 0.3 "Terminal roll [rad] (assumed, within limits)";
  parameter Real jerk_limit = 1.0 "Peak jerk limit [rad/s3] (assumed)";

  // Controller gains (assumed)
  parameter Real Kp1 = 60.0 "Yaw position gain";
  parameter Real Kp2 = 50.0 "Pitch position gain";
  parameter Real Kp3 = 40.0 "Roll position gain";
  parameter Real Kd1 = 8.0 "Yaw velocity gain";
  parameter Real Kd2 = 6.0 "Pitch velocity gain";
  parameter Real Kd3 = 5.0 "Roll velocity gain";

  // Disturbance: 8% inertia change during middle third of total run
  parameter Real T_dist_start = T_total / 3.0 "Disturbance start [s]";
  parameter Real T_dist_end = 2.0 * T_total / 3.0 "Disturbance end [s]";
  parameter Real inertia_change = 0.08 "Inertia change fraction (8 percent)";

  // Fixed keep-out obstacle (assumed: placed outside nominal camera path)
  parameter Real p_obs_x = 0.30 "Obstacle x position [m] (assumed)";
  parameter Real p_obs_y = 0.30 "Obstacle y position [m] (assumed)";
  parameter Real p_obs_z = 0.20 "Obstacle z position [m] (assumed)";
  parameter Real r_obs = 0.03 "Obstacle radius [m] (assumed)";
  parameter Real r_cam = 0.04 "Camera effective radius [m] (assumed)";

  // Dynamic states
  Real q1 "Yaw position [rad]";
  Real q2 "Pitch position [rad]";
  Real q3 "Roll position [rad]";
  Real w1 "Yaw velocity [rad/s]";
  Real w2 "Pitch velocity [rad/s]";
  Real w3 "Roll velocity [rad/s]";

  // Torque signals
  Real tau1 "Yaw applied torque [N.m]";
  Real tau2 "Pitch applied torque [N.m]";
  Real tau3 "Roll applied torque [N.m]";
  Real tau1_cmd "Yaw commanded torque [N.m]";
  Real tau2_cmd "Pitch commanded torque [N.m]";
  Real tau3_cmd "Roll commanded torque [N.m]";

  // Reference trajectory
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

  // Acceleration (plant output)
  Real alpha1 "Yaw acceleration [rad/s2]";
  Real alpha2 "Pitch acceleration [rad/s2]";
  Real alpha3 "Roll acceleration [rad/s2]";

  // Actual inertia with disturbance
  Real J1_act "Actual yaw inertia [kg.m2]";
  Real J2_act "Actual pitch inertia [kg.m2]";
  Real J3_act "Actual roll inertia [kg.m2]";

  // Forward kinematics and obstacle
  Real p_cam_x "Camera x position [m]";
  Real p_cam_y "Camera y position [m]";
  Real p_cam_z "Camera z position [m]";
  Real dist_obs "Distance camera-to-obstacle [m]";
  Boolean collision "Collision flag";

  // Synchronized measurements at controller rate (200 Hz)
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

  // Performance metrics
  Real track_err1 "Yaw tracking error [rad]";
  Real track_err2 "Pitch tracking error [rad]";
  Real track_err3 "Roll tracking error [rad]";
  Real primary_track_err "Primary (max) tracking error [rad]";
  Real peak_jerk1 "Yaw jerk magnitude [rad/s3]";
  Real peak_jerk2 "Pitch jerk magnitude [rad/s3]";
  Real peak_jerk3 "Roll jerk magnitude [rad/s3]";
  Real peak_jerk "Overall peak jerk [rad/s3]";
  Real overshoot1 "Yaw overshoot fraction";
  Real overshoot2 "Pitch overshoot fraction";
  Real overshoot3 "Roll overshoot fraction";
  Real overshoot "Overall overshoot fraction";

  // Constraint flags
  Boolean bounds_ok "State and command bounds satisfied";
  Boolean error_ok "Tracking error within spec after 9.1 s";
  Boolean no_collision_flag "No collision";
  Boolean all_ok "All constraints satisfied";

  // Trajectory blend internals
  Real xi "Normalized trajectory time";
  Real s_val "Quintic blend value";
  Real s_d "Blend first derivative";
  Real s_dd "Blend second derivative";
  Real s_ddd "Blend third derivative";

initial equation
  q1 = 0.0;
  q2 = 0.0;
  q3 = 0.0;
  w1 = 0.0;
  w2 = 0.0;
  w3 = 0.0;

equation
  // Normalized trajectory time
  xi = time / T_traj;

  // Quintic blend: s(xi) = 10*xi^3 - 15*xi^4 + 6*xi^5 (C2 continuous, bounded jerk)
  s_val = if xi <= 0.0 then 0.0 else if xi >= 1.0 then 1.0 else 10.0*xi*xi*xi - 15.0*xi*xi*xi*xi + 6.0*xi*xi*xi*xi*xi;
  s_d = if xi <= 0.0 then 0.0 else if xi >= 1.0 then 0.0 else 30.0*xi*xi - 60.0*xi*xi*xi + 30.0*xi*xi*xi*xi;
  s_dd = if xi <= 0.0 then 0.0 else if xi >= 1.0 then 0.0 else 60.0*xi - 180.0*xi*xi + 120.0*xi*xi*xi;
  s_ddd = if xi <= 0.0 then 0.0 else if xi >= 1.0 then 0.0 else 60.0 - 360.0*xi + 360.0*xi*xi;

  // Reference trajectory (jerk-limited S-curve, hold terminal state after T_traj)
  q1_ref = q1_end * s_val;
  q2_ref = q2_end * s_val;
  q3_ref = q3_end * s_val;

  w1_ref = q1_end * s_d / T_traj;
  w2_ref = q2_end * s_d / T_traj;
  w3_ref = q3_end * s_d / T_traj;

  a1_ref = q1_end * s_dd / (T_traj * T_traj);
  a2_ref = q2_end * s_dd / (T_traj * T_traj);
  a3_ref = q3_end * s_dd / (T_traj * T_traj);

  j1_ref = q1_end * s_ddd / (T_traj * T_traj * T_traj);
  j2_ref = q2_end * s_ddd / (T_traj * T_traj * T_traj);
  j3_ref = q3_end * s_ddd / (T_traj * T_traj * T_traj);

  // Actual inertia with controlled 8% increase during middle third
  J1_act = if (time >= T_dist_start) and (time <= T_dist_end) then J1_nom * (1.0 + inertia_change) else J1_nom;
  J2_act = if (time >= T_dist_start) and (time <= T_dist_end) then J2_nom * (1.0 + inertia_change) else J2_nom;
  J3_act = if (time >= T_dist_start) and (time <= T_dist_end) then J3_nom * (1.0 + inertia_change) else J3_nom;

  // Plant dynamics: gimbal carrying 4 kg camera
  der(q1) = w1;
  der(q2) = w2;
  der(q3) = w3;
  alpha1 = tau1 / J1_act;
  alpha2 = tau2 / J2_act;
  alpha3 = tau3 / J3_act;
  der(w1) = alpha1;
  der(w2) = alpha2;
  der(w3) = alpha3;

  // Feedforward inverse dynamics (nominal inertia) plus bounded PD feedback
  tau1_cmd = J1_nom * a1_ref + Kp1 * (q1_ref - q1) + Kd1 * (w1_ref - w1);
  tau2_cmd = J2_nom * a2_ref + Kp2 * (q2_ref - q2) + Kd2 * (w2_ref - w2);
  tau3_cmd = J3_nom * a3_ref + Kp3 * (q3_ref - q3) + Kd3 * (w3_ref - w3);

  // Saturated actuator torque bounded to +/- torque_max
  tau1 = if tau1_cmd > torque_max then torque_max else if tau1_cmd < -torque_max then -torque_max else tau1_cmd;
  tau2 = if tau2_cmd > torque_max then torque_max else if tau2_cmd < -torque_max then -torque_max else tau2_cmd;
  tau3 = if tau3_cmd > torque_max then torque_max else if tau3_cmd < -torque_max then -torque_max else tau3_cmd;

  // Forward kinematics (simplified spherical gimbal model)
  p_cam_x = d_cam * cos(q1) * cos(q2);
  p_cam_y = d_cam * sin(q1) * cos(q2);
  p_cam_z = d_cam * sin(q2);

  // Collision check against fixed keep-out object
  dist_obs = sqrt((p_cam_x - p_obs_x)*(p_cam_x - p_obs_x) + (p_cam_y - p_obs_y)*(p_cam_y - p_obs_y) + (p_cam_z - p_obs_z)*(p_cam_z - p_obs_z));
  collision = dist_obs < (r_obs + r_cam);

  // Synchronized sensor traces at controller rate (200 Hz simulation interval)
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

  // Tracking errors
  track_err1 = abs(q1_ref - q1);
  track_err2 = abs(q2_ref - q2);
  track_err3 = abs(q3_ref - q3);

  // Primary tracking error = worst-case across all axes
  primary_track_err = if track_err1 >= track_err2 then (if track_err1 >= track_err3 then track_err1 else track_err3) else (if track_err2 >= track_err3 then track_err2 else track_err3);

  // Jerk magnitudes
  peak_jerk1 = abs(j1_ref);
  peak_jerk2 = abs(j2_ref);
  peak_jerk3 = abs(j3_ref);
  peak_jerk = if peak_jerk1 >= peak_jerk2 then (if peak_jerk1 >= peak_jerk3 then peak_jerk1 else peak_jerk3) else (if peak_jerk2 >= peak_jerk3 then peak_jerk2 else peak_jerk3);

  // Overshoot fractions (positive deviation past terminal state after motion completes)
  overshoot1 = if time > T_traj then (if q1 > q1_end then (q1 - q1_end) / (abs(q1_end) + 1.0e-10) else 0.0) else 0.0;
  overshoot2 = if time > T_traj then (if q2 > q2_end then (q2 - q2_end) / (abs(q2_end) + 1.0e-10) else 0.0) else 0.0;
  overshoot3 = if time > T_traj then (if q3 > q3_end then (q3 - q3_end) / (abs(q3_end) + 1.0e-10) else 0.0) else 0.0;
  overshoot = if overshoot1 >= overshoot2 then (if overshoot1 >= overshoot3 then overshoot1 else overshoot3) else (if overshoot2 >= overshoot3 then overshoot2 else overshoot3);

  // Constraint checks
  bounds_ok = (q1 >= q1_min) and (q1 <= q1_max) and (q2 >= q2_min) and (q2 <= q2_max) and (q3 >= q3_min) and (q3 <= q3_max) and (abs(tau1) <= torque_max + 0.001) and (abs(tau2) <= torque_max + 0.001) and (abs(tau3) <= torque_max + 0.001);
  error_ok = if time >= 9.1 then (primary_track_err < 0.025) else true;
  no_collision_flag = not collision;
  all_ok = bounds_ok and error_ok and no_collision_flag;

  annotation(
    experiment(StartTime = 0, StopTime = 14, Tolerance = 1e-6, NumberOfIntervals = 2800));
end GimbalPathSmoothD;