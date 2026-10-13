model GroundPairResilientB
  // ===== Stated parameters =====
  parameter Real m_robot = 14.0 "Robot mass [kg]";
  parameter Real r_wheel = 0.09 "Wheel radius [m]";
  parameter Real tau_max = 8.2 "Max wheel torque magnitude [N.m]";
  parameter Real t_drop_start = 4.65 "Comm dropout start [s]";
  parameter Real t_drop_dur = 0.7 "Comm dropout duration [s]";

  // ===== Assumed parameters (not stated in requirement) =====
  parameter Real L_wheelbase = 0.30 "Wheelbase [m] -- assumed";
  parameter Real I_robot = 0.35 "Yaw inertia [kg.m2] -- assumed";
  parameter Real F_dist_mag = 4.0 "Shared disturbance force magnitude [N] -- assumed";
  parameter Real d_safe = 0.35 "Collision avoidance threshold [m] -- assumed";
  parameter Real k_track = 20.0 "Forward tracking gain -- assumed";
  parameter Real k_avoid = 15.0 "Collision avoidance gain -- assumed";
  parameter Real k_theta = 12.0 "Heading control gain -- assumed";
  parameter Real k_domega = 3.0 "Heading damping gain -- assumed";
  parameter Real v_ref = 0.8 "Reference forward speed [m/s] -- assumed";
  parameter Real y1_ref = 0.5 "Robot 1 reference lateral offset [m] -- assumed";
  parameter Real y2_ref = -0.5 "Robot 2 reference lateral offset [m] -- assumed";
  parameter Real x_target = 6.0 "Route completion target x [m] -- assumed";
  parameter Real eps = 1e-6 "Small constant for norm safety";

  // ===== Robot 1 continuous states =====
  Real x1(start=0.0, fixed=true) "Robot 1 x position [m]";
  Real y1(start=0.5, fixed=true) "Robot 1 y position [m]";
  Real theta1(start=0.0, fixed=true) "Robot 1 heading [rad]";
  Real v1(start=0.0, fixed=true) "Robot 1 forward velocity [m/s]";
  Real omega1(start=0.0, fixed=true) "Robot 1 yaw rate [rad/s]";

  // ===== Robot 2 continuous states =====
  Real x2(start=0.0, fixed=true) "Robot 2 x position [m]";
  Real y2(start=-0.5, fixed=true) "Robot 2 y position [m]";
  Real theta2(start=0.0, fixed=true) "Robot 2 heading [rad]";
  Real v2(start=0.0, fixed=true) "Robot 2 forward velocity [m/s]";
  Real omega2(start=0.0, fixed=true) "Robot 2 yaw rate [rad/s]";

  // ===== Held peer states for dropout prediction (zero-order hold) =====
  Real x2_held(start=0.0, fixed=true) "Held x2 at last comm [m]";
  Real y2_held(start=-0.5, fixed=true) "Held y2 at last comm [m]";
  Real theta2_held(start=0.0, fixed=true) "Held theta2 at last comm [rad]";
  Real x1_held(start=0.0, fixed=true) "Held x1 at last comm [m]";
  Real y1_held(start=0.5, fixed=true) "Held y1 at last comm [m]";
  Real theta1_held(start=0.0, fixed=true) "Held theta1 at last comm [rad]";

  // ===== Communication =====
  Boolean comm_ok "Communication link available";
  Boolean in_dropout "Currently in communication dropout";

  // ===== Disturbance =====
  Real F_dist_y1 "Disturbance force on robot 1 in y [N]";
  Real F_dist_y2 "Disturbance force on robot 2 in y [N]";
  Real v_drift1 "Lateral drift velocity robot 1 [m/s]";
  Real v_drift2 "Lateral drift velocity robot 2 [m/s]";

  // ===== Predicted peer states =====
  Real x2_pred "Robot 1 predicted x of robot 2 [m]";
  Real y2_pred "Robot 1 predicted y of robot 2 [m]";
  Real theta2_pred "Robot 1 predicted heading of robot 2 [rad]";
  Real x1_pred "Robot 2 predicted x of robot 1 [m]";
  Real y1_pred "Robot 2 predicted y of robot 1 [m]";
  Real theta1_pred "Robot 2 predicted heading of robot 1 [rad]";

  // ===== Control intermediates robot 1 =====
  Real F_fwd1 "Robot 1 forward force command [N]";
  Real T_cmd1 "Robot 1 turn torque command [N.m]";
  Real theta_des1 "Robot 1 desired heading [rad]";
  Real e_lat1 "Robot 1 combined lateral error [m]";
  Real e_avoid_y1 "Robot 1 collision avoidance correction [m]";
  Real d_12_pred1 "Robot 1 predicted distance to robot 2 [m]";
  Real dx_12_p1 "Robot 1 predicted dx to robot 2 [m]";
  Real dy_12_p1 "Robot 1 predicted dy to robot 2 [m]";

  // ===== Control intermediates robot 2 =====
  Real F_fwd2 "Robot 2 forward force command [N]";
  Real T_cmd2 "Robot 2 turn torque command [N.m]";
  Real theta_des2 "Robot 2 desired heading [rad]";
  Real e_lat2 "Robot 2 combined lateral error [m]";
  Real e_avoid_y2 "Robot 2 collision avoidance correction [m]";
  Real d_21_pred2 "Robot 2 predicted distance to robot 1 [m]";
  Real dx_21_p2 "Robot 2 predicted dx to robot 1 [m]";
  Real dy_21_p2 "Robot 2 predicted dy to robot 1 [m]";

  // ===== Wheel torques =====
  Real tau_L1 "Robot 1 left wheel torque actual [N.m]";
  Real tau_R1 "Robot 1 right wheel torque actual [N.m]";
  Real tau_L2 "Robot 2 left wheel torque actual [N.m]";
  Real tau_R2 "Robot 2 right wheel torque actual [N.m]";
  Real tau_L1_cmd "Robot 1 left wheel torque command [N.m]";
  Real tau_R1_cmd "Robot 1 right wheel torque command [N.m]";
  Real tau_L2_cmd "Robot 2 left wheel torque command [N.m]";
  Real tau_R2_cmd "Robot 2 right wheel torque command [N.m]";

  // ===== Sensor traces =====
  Real omega_wL1 "Robot 1 left wheel angular velocity encoder [rad/s]";
  Real omega_wR1 "Robot 1 right wheel angular velocity encoder [rad/s]";
  Real omega_wL2 "Robot 2 left wheel angular velocity encoder [rad/s]";
  Real omega_wR2 "Robot 2 right wheel angular velocity encoder [rad/s]";
  Real d_lidar1 "Robot 1 lidar distance to peer [m]";
  Real d_lidar2 "Robot 2 lidar distance to peer [m]";
  Real imu_theta1 "Robot 1 IMU heading [rad]";
  Real imu_omega1 "Robot 1 IMU yaw rate [rad/s]";
  Real imu_theta2 "Robot 2 IMU heading [rad]";
  Real imu_omega2 "Robot 2 IMU yaw rate [rad/s]";

  // ===== Performance metrics =====
  Real e_track1 "Robot 1 tracking error [m]";
  Real e_track2 "Robot 2 tracking error [m]";
  Real e_track_primary "Primary max tracking error [m]";
  Real e_form "Formation error [m]";
  Real e_form_degraded "Instantaneous formation error during dropout [m]";
  Real e_form_recovered "Formation error after recovery [m]";
  Real route_progress "Route completion fraction 0..1";
  Real d_12_actual "Actual inter-robot distance [m]";
  Boolean route_done "Route completion flag";

equation
  // ===== Communication status =====
  in_dropout = time >= t_drop_start and time < t_drop_start + t_drop_dur;
  comm_ok = not in_dropout;

  // ===== Shared environmental disturbance (applied during dropout) =====
  F_dist_y1 = if in_dropout then F_dist_mag else 0.0;
  F_dist_y2 = if in_dropout then F_dist_mag else 0.0;
  v_drift1 = F_dist_y1 / m_robot;
  v_drift2 = F_dist_y2 / m_robot;

  // ===== Held peer states (track during comm, freeze during dropout) =====
  der(x2_held) = if comm_ok then v2 * cos(theta2) else 0.0;
  der(y2_held) = if comm_ok then v2 * sin(theta2) else 0.0;
  der(theta2_held) = if comm_ok then omega2 else 0.0;
  der(x1_held) = if comm_ok then v1 * cos(theta1) else 0.0;
  der(y1_held) = if comm_ok then v1 * sin(theta1) else 0.0;
  der(theta1_held) = if comm_ok then omega1 else 0.0;

  // ===== Prediction (dead reckoning from last-received state) =====
  x2_pred = if comm_ok then x2 else x2_held;
  y2_pred = if comm_ok then y2 else y2_held;
  theta2_pred = if comm_ok then theta2 else theta2_held;
  x1_pred = if comm_ok then x1 else x1_held;
  y1_pred = if comm_ok then y1 else y1_held;
  theta1_pred = if comm_ok then theta1 else theta1_held;

  // ===== Robot 1 dynamics =====
  der(x1) = v1 * cos(theta1);
  der(y1) = v1 * sin(theta1) + v_drift1;
  der(theta1) = omega1;
  m_robot * der(v1) = (tau_R1 + tau_L1) / r_wheel;
  I_robot * der(omega1) = (tau_R1 - tau_L1) * L_wheelbase / (2.0 * r_wheel);

  // ===== Robot 2 dynamics =====
  der(x2) = v2 * cos(theta2);
  der(y2) = v2 * sin(theta2) + v_drift2;
  der(theta2) = omega2;
  m_robot * der(v2) = (tau_R2 + tau_L2) / r_wheel;
  I_robot * der(omega2) = (tau_R2 - tau_L2) * L_wheelbase / (2.0 * r_wheel);

  // ===== Robot 1 distributed control with prediction =====
  F_fwd1 = k_track * (v_ref - v1);
  dx_12_p1 = x1 - x2_pred;
  dy_12_p1 = y1 - y2_pred;
  d_12_pred1 = sqrt(dx_12_p1 * dx_12_p1 + dy_12_p1 * dy_12_p1 + eps);
  e_avoid_y1 = if d_12_pred1 < d_safe then k_avoid * (d_safe - d_12_pred1) * dy_12_p1 / d_12_pred1 else 0.0;
  e_lat1 = (y1_ref - y1) + 0.5 * ((y1_ref - y2_ref) - (y1 - y2_pred)) + e_avoid_y1;
  theta_des1 = max(-0.8, min(0.8, 0.5 * e_lat1));
  T_cmd1 = k_theta * (theta_des1 - theta1) - k_domega * omega1;
  tau_R1_cmd = (F_fwd1 * r_wheel) / 2.0 + T_cmd1 * r_wheel / L_wheelbase;
  tau_L1_cmd = (F_fwd1 * r_wheel) / 2.0 - T_cmd1 * r_wheel / L_wheelbase;
  tau_R1 = max(-tau_max, min(tau_max, tau_R1_cmd));
  tau_L1 = max(-tau_max, min(tau_max, tau_L1_cmd));

  // ===== Robot 2 distributed control with prediction =====
  F_fwd2 = k_track * (v_ref - v2);
  dx_21_p2 = x2 - x1_pred;
  dy_21_p2 = y2 - y1_pred;
  d_21_pred2 = sqrt(dx_21_p2 * dx_21_p2 + dy_21_p2 * dy_21_p2 + eps);
  e_avoid_y2 = if d_21_pred2 < d_safe then k_avoid * (d_safe - d_21_pred2) * dy_21_p2 / d_21_pred2 else 0.0;
  e_lat2 = (y2_ref - y2) + 0.5 * ((y2_ref - y1_ref) - (y2 - y1_pred)) + e_avoid_y2;
  theta_des2 = max(-0.8, min(0.8, 0.5 * e_lat2));
  T_cmd2 = k_theta * (theta_des2 - theta2) - k_domega * omega2;
  tau_R2_cmd = (F_fwd2 * r_wheel) / 2.0 + T_cmd2 * r_wheel / L_wheelbase;
  tau_L2_cmd = (F_fwd2 * r_wheel) / 2.0 - T_cmd2 * r_wheel / L_wheelbase;
  tau_R2 = max(-tau_max, min(tau_max, tau_R2_cmd));
  tau_L2 = max(-tau_max, min(tau_max, tau_L2_cmd));

  // ===== Sensor traces =====
  omega_wL1 = (v1 - omega1 * L_wheelbase / 2.0) / r_wheel;
  omega_wR1 = (v1 + omega1 * L_wheelbase / 2.0) / r_wheel;
  omega_wL2 = (v2 - omega2 * L_wheelbase / 2.0) / r_wheel;
  omega_wR2 = (v2 + omega2 * L_wheelbase / 2.0) / r_wheel;
  d_12_actual = sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2) + eps);
  d_lidar1 = d_12_actual;
  d_lidar2 = d_12_actual;
  imu_theta1 = theta1;
  imu_omega1 = omega1;
  imu_theta2 = theta2;
  imu_omega2 = omega2;

  // ===== Performance metrics =====
  e_track1 = sqrt((x1 - v_ref * time) * (x1 - v_ref * time) + (y1 - y1_ref) * (y1 - y1_ref) + eps);
  e_track2 = sqrt((x2 - v_ref * time) * (x2 - v_ref * time) + (y2 - y2_ref) * (y2 - y2_ref) + eps);
  e_track_primary = max(e_track1, e_track2);
  e_form = abs((y1 - y2) - (y1_ref - y2_ref));
  e_form_degraded = if in_dropout then e_form else 0.0;
  e_form_recovered = if time >= t_drop_start + t_drop_dur then e_form else 0.0;
  route_progress = min(1.0, max(0.0, x1 / x_target));
  route_done = x1 >= x_target and x2 >= x_target;

  annotation(
    experiment(StartTime = 0, StopTime = 10.0, Tolerance = 1e-6, Interval = 0.01),
    Documentation(info = "GroundPairResilientB: Two 14 kg differential-drive robots (0.09 m wheels, +/-8.2 N.m wheel torque bounds). Distributed control with dead-reckoning prediction during a 0.7 s communication dropout in the middle third of a 10 s mission at 100 Hz. Shared environmental disturbance applied during dropout. Collision avoidance, degraded/recovered formation errors, route completion, primary tracking error, and full sensor traces instrumented. Assumed parameters (L_wheelbase, I_robot, gains, disturbance magnitude, reference speeds, targets) are labeled in comments and are not from the original requirement.")
  );
end GroundPairResilientB;