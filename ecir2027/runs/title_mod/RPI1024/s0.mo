model OmniCartInspectD
  // ===== Physical parameters =====
  parameter Real m_plat = 25.0 "Platform mass [kg]";
  parameter Real r_wheel = 0.095 "Wheel radius [m]";
  parameter Real a_half = 0.29 "Half platform length [m]";
  parameter Real b_half = 0.23 "Half platform width [m]";
  parameter Real L_geom = a_half + b_half "Wheel geometry parameter [m]";
  parameter Real I_z = m_plat * (0.58 * 0.58 + 0.46 * 0.46) / 12.0 "Yaw inertia [kg.m2]";
  parameter Real tau_max = 12.0 "Max wheel torque [N.m]";
  parameter Real W_corridor = 1.8 "Corridor width [m]";
  parameter Real v_ref = 0.8 "Reference speed [m/s]";
  parameter Real F_disturb = 90.0 "Disturbance force [N]";
  parameter Real T_total = 14.0 "Total duration [s]";
  parameter Real S_amp = 0.35 "S-curve amplitude [m]";
  parameter Real S_period = 8.0 "S-curve spatial period [m]";
  parameter Real omega_s = 2.0 * 3.14159265358979 / S_period "S-curve spatial freq [rad/m]";
  parameter Real x_total = v_ref * T_total "Approx total path length [m]";
  parameter Real lidar_max = 15.0 "Lidar max range [m]";

  // Controller gains
  parameter Real Kp_vx = 60.0 "Forward velocity gain [N.s/m]";
  parameter Real Kp_lat = 300.0 "Lateral position gain [N/m]";
  parameter Real Kd_lat = 80.0 "Lateral velocity damping [N.s/m]";
  parameter Real Ki_lat = 40.0 "Lateral integral gain [N/(m.s)]";
  parameter Real Kp_head = 12.0 "Heading gain [N.m/rad]";
  parameter Real Kp_wz = 6.0 "Yaw rate gain [N.m.s/rad]";
  parameter Real K_rep = 50.0 "Obstacle repulsion gain [N/m]";

  // Estimator parameters
  parameter Real K_ekf_y = 0.5 "Lidar y correction gain";
  parameter Real K_ekf_wz = 0.6 "IMU wz fusion weight";
  parameter Real Q_pos = 0.001 "Process noise position [m^2/s]";
  parameter Real Q_theta = 0.0001 "Process noise heading [rad^2/s]";
  parameter Real R_lidar = 0.01 "Lidar measurement noise [m^2]";
  parameter Real R_imu = 0.0001 "IMU measurement noise [rad^2]";

  // ===== Plant states =====
  Real x(start = 0.0, fixed = true) "X position [m]";
  Real y(start = 0.9, fixed = true) "Y position [m]";
  Real theta(start = 0.0, fixed = true) "Heading [rad]";
  Real vx(start = 0.0, fixed = true) "Body forward velocity [m/s]";
  Real vy(start = 0.0, fixed = true) "Body lateral velocity [m/s]";
  Real wz(start = 0.0, fixed = true) "Yaw rate [rad/s]";

  // Integral state
  Real e_lat_int(start = 0.0, fixed = true) "Lateral error integral [m.s]";

  // Actuator torques
  Real tau1(start = 0.0) "Wheel FL torque [N.m]";
  Real tau2(start = 0.0) "Wheel FR torque [N.m]";
  Real tau3(start = 0.0) "Wheel BL torque [N.m]";
  Real tau4(start = 0.0) "Wheel BR torque [N.m]";
  Real tau1_raw "Unsaturated torque 1 [N.m]";
  Real tau2_raw "Unsaturated torque 2 [N.m]";
  Real tau3_raw "Unsaturated torque 3 [N.m]";
  Real tau4_raw "Unsaturated torque 4 [N.m]";

  // Body forces
  Real Fx_body "Net forward force [N]";
  Real Fy_body "Net lateral force [N]";
  Real Tz_body "Net yaw torque [N.m]";
  Real Fx_cmd "Commanded forward force [N]";
  Real Fy_cmd "Commanded lateral force [N]";
  Real Tz_cmd "Commanded yaw torque [N.m]";
  Real F_dist_y "Disturbance lateral force [N]";
  Real F_rep_y "Repulsive obstacle force [N]";

  // Wheel angular velocities
  Real w1 "Wheel FL angular velocity [rad/s]";
  Real w2 "Wheel FR angular velocity [rad/s]";
  Real w3 "Wheel BL angular velocity [rad/s]";
  Real w4 "Wheel BR angular velocity [rad/s]";

  // ===== Sensors =====
  Real odom_x(start = 0.0, fixed = true) "Odometry x [m]";
  Real odom_y(start = 0.9, fixed = true) "Odometry y [m]";
  Real odom_theta(start = 0.0, fixed = true) "Odometry theta [rad]";
  Real odom_vx "Odometry forward velocity [m/s]";
  Real odom_vy "Odometry lateral velocity [m/s]";
  Real odom_wz "Odometry yaw rate [rad/s]";
  Real imu_wz_meas "IMU yaw rate measurement [rad/s]";
  Real imu_ax_meas "IMU forward acceleration [m/s2]";
  Real imu_ay_meas "IMU lateral acceleration [m/s2]";
  Real lidar_left "Lidar left range [m]";
  Real lidar_right "Lidar right range [m]";
  Real lidar_front "Lidar front range [m]";

  // ===== Estimator =====
  Real est_x(start = 0.0, fixed = true) "Estimated x [m]";
  Real est_y(start = 0.9, fixed = true) "Estimated y [m]";
  Real est_theta(start = 0.0, fixed = true) "Estimated theta [rad]";
  Real est_vx "Estimated forward velocity [m/s]";
  Real est_vy "Estimated lateral velocity [m/s]";
  Real est_wz "Estimated yaw rate [rad/s]";
  Real wall_left_est "Estimated left wall y [m]";
  Real wall_right_est "Estimated right wall y [m]";
  Real y_lidar_meas "Lidar-derived y measurement [m]";

  // Covariance
  Real P_x(start = 0.02, fixed = true) "Covariance x [m^2]";
  Real P_y(start = 0.01, fixed = true) "Covariance y [m^2]";
  Real P_theta(start = 0.01, fixed = true) "Covariance theta [rad^2]";

  // ===== Path reference and metrics =====
  Real y_ref "Reference y [m]";
  Real theta_ref "Reference heading [rad]";
  Real kappa_ref "Reference curvature [1/m]";
  Real denom_curve "Curvature denominator helper";
  Real e_lat "Lateral tracking error (actual) [m]";
  Real e_lat_est "Estimated lateral error [m]";
  Real e_head "Heading error [rad]";
  Real tracking_error "Primary tracking error [m]";
  Real route_completion "Route completion [0-1]";

  // Corridor walls
  Real wall_left "Left wall y [m]";
  Real wall_right "Right wall y [m]";
  Real clearance_left "Clearance to left wall [m]";
  Real clearance_right "Clearance to right wall [m]";
  Real min_clearance "Minimum clearance [m]";

  // ===== Outputs (synchronized traces) =====
  output Real out_x = x "State x [m]";
  output Real out_y = y "State y [m]";
  output Real out_theta = theta "State theta [rad]";
  output Real out_vx = vx "State vx [m/s]";
  output Real out_vy = vy "State vy [m/s]";
  output Real out_wz = wz "State wz [rad/s]";
  output Real out_tau1 = tau1 "Command tau1 [N.m]";
  output Real out_tau2 = tau2 "Command tau2 [N.m]";
  output Real out_tau3 = tau3 "Command tau3 [N.m]";
  output Real out_tau4 = tau4 "Command tau4 [N.m]";
  output Real out_est_x = est_x "Estimator x [m]";
  output Real out_est_y = est_y "Estimator y [m]";
  output Real out_est_theta = est_theta "Estimator theta [rad]";
  output Real out_P_x = P_x "Covariance x [m^2]";
  output Real out_P_y = P_y "Covariance y [m^2]";
  output Real out_P_theta = P_theta "Covariance theta [rad^2]";
  output Real out_tracking_error = tracking_error "Tracking error [m]";
  output Real out_heading_error = e_head "Heading error [rad]";
  output Real out_completion = route_completion "Route completion";
  output Real out_clearance = min_clearance "Min clearance [m]";
  output Real out_lidar_left = lidar_left "Lidar left [m]";
  output Real out_lidar_right = lidar_right "Lidar right [m]";
  output Real out_imu_wz = imu_wz_meas "IMU wz [rad/s]";
  output Real out_odom_x = odom_x "Odometry x [m]";
  output Real out_odom_y = odom_y "Odometry y [m]";

equation
  // ===== Corridor geometry (actual, with two recessed alcoves) =====
  if x >= 3.0 and x <= 4.0 then
    wall_left = -0.35;
    wall_right = 1.8;
  elseif x >= 9.0 and x <= 10.0 then
    wall_left = 0.0;
    wall_right = 2.15;
  else
    wall_left = 0.0;
    wall_right = 1.8;
  end if;

  clearance_left = y - wall_left - b_half;
  clearance_right = wall_right - y - b_half;
  min_clearance = if clearance_left < clearance_right then clearance_left else clearance_right;

  // ===== Reference path (S-shaped corridor centerline) =====
  y_ref = 0.9 + S_amp * sin(omega_s * x);
  theta_ref = atan(S_amp * omega_s * cos(omega_s * x));
  denom_curve = 1.0 + (S_amp * omega_s * cos(omega_s * x)) * (S_amp * omega_s * cos(omega_s * x));
  kappa_ref = (S_amp * omega_s * omega_s * (-sin(omega_s * x))) / (denom_curve * sqrt(denom_curve));

  // Errors
  e_lat = y - y_ref;
  e_lat_est = est_y - y_ref;
  e_head = theta - theta_ref;
  tracking_error = if e_lat >= 0.0 then e_lat else -e_lat;
  route_completion = if x / x_total > 1.0 then 1.0 elseif x / x_total < 0.0 then 0.0 else x / x_total;

  // ===== Disturbance: 90 N side load during middle third =====
  if time >= T_total / 3.0 and time <= 2.0 * T_total / 3.0 then
    F_dist_y = F_disturb;
  else
    F_dist_y = 0.0;
  end if;

  // ===== Obstacle avoidance repulsion =====
  if clearance_left < 0.3 then
    F_rep_y = K_rep * (0.3 - clearance_left);
  elseif clearance_right < 0.3 then
    F_rep_y = -K_rep * (0.3 - clearance_right);
  else
    F_rep_y = 0.0;
  end if;

  // ===== Integral state (localization-aware) =====
  der(e_lat_int) = e_lat_est;

  // ===== Controller: localization-aware path tracking =====
  Fx_cmd = Kp_vx * (v_ref - est_vx);
  Fy_cmd = -Kp_lat * e_lat_est - Kd_lat * est_vy - Ki_lat * e_lat_int + F_rep_y;
  Tz_cmd = -Kp_head * (est_theta - theta_ref) + Kp_wz * (v_ref * kappa_ref - est_wz);

  // ===== Inverse mecanum dynamics: body force to wheel torque =====
  // 45 deg roller angle, standard mecanum mapping
  tau1_raw = (r_wheel / 4.0) * (Fx_cmd - Fy_cmd - Tz_cmd / L_geom);
  tau2_raw = (r_wheel / 4.0) * (Fx_cmd + Fy_cmd + Tz_cmd / L_geom);
  tau3_raw = (r_wheel / 4.0) * (Fx_cmd + Fy_cmd - Tz_cmd / L_geom);
  tau4_raw = (r_wheel / 4.0) * (Fx_cmd - Fy_cmd + Tz_cmd / L_geom);

  // Torque saturation (12 N.m limit)
  tau1 = if tau1_raw > tau_max then tau_max elseif tau1_raw < -tau_max then -tau_max else tau1_raw;
  tau2 = if tau2_raw > tau_max then tau_max elseif tau2_raw < -tau_max then -tau_max else tau2_raw;
  tau3 = if tau3_raw > tau_max then tau_max elseif tau3_raw < -tau_max then -tau_max else tau3_raw;
  tau4 = if tau4_raw > tau_max then tau_max elseif tau4_raw < -tau_max then -tau_max else tau4_raw;

  // ===== Forward mecanum dynamics: wheel torque to body force =====
  Fx_body = (1.0 / r_wheel) * (tau1 + tau2 + tau3 + tau4);
  Fy_body = (1.0 / r_wheel) * (-tau1 + tau2 + tau3 - tau4);
  Tz_body = (L_geom / r_wheel) * (-tau1 + tau2 - tau3 + tau4);

  // ===== Plant dynamics (planar floating base) =====
  der(x) = cos(theta) * vx - sin(theta) * vy;
  der(y) = sin(theta) * vx + cos(theta) * vy;
  der(theta) = wz;
  m_plat * der(vx) = Fx_body;
  m_plat * der(vy) = Fy_body + F_dist_y;
  I_z * der(wz) = Tz_body;

  // ===== Wheel kinematics (forward: body vel to wheel rates) =====
  w1 = (1.0 / r_wheel) * (vx - vy - L_geom * wz);
  w2 = (1.0 / r_wheel) * (vx + vy + L_geom * wz);
  w3 = (1.0 / r_wheel) * (vx + vy - L_geom * wz);
  w4 = (1.0 / r_wheel) * (vx - vy + L_geom * wz);

  // ===== Wheel odometry sensor =====
  odom_vx = (r_wheel / 4.0) * (w1 + w2 + w3 + w4);
  odom_vy = (r_wheel / 4.0) * (-w1 + w2 + w3 - w4);
  odom_wz = (r_wheel / (4.0 * L_geom)) * (-w1 + w2 - w3 + w4);
  der(odom_x) = cos(odom_theta) * odom_vx - sin(odom_theta) * odom_vy;
  der(odom_y) = sin(odom_theta) * odom_vx + cos(odom_theta) * odom_vy;
  der(odom_theta) = odom_wz;

  // ===== IMU sensor =====
  imu_wz_meas = wz;
  imu_ax_meas = Fx_body / m_plat - wz * vy;
  imu_ay_meas = (Fy_body + F_dist_y) / m_plat + wz * vx;

  // ===== Lidar sensor (planar, 15 m max) =====
  lidar_left = if y - wall_left > 0.0 then y - wall_left else 0.0;
  lidar_right = if wall_right - y > 0.0 then wall_right - y else 0.0;
  lidar_front = lidar_max;

  // ===== Estimator: fuse odometry + IMU + lidar =====
  // Wall lookup at estimated position
  if est_x >= 3.0 and est_x <= 4.0 then
    wall_left_est = -0.35;
    wall_right_est = 1.8;
  elseif est_x >= 9.0 and est_x <= 10.0 then
    wall_left_est = 0.0;
    wall_right_est = 2.15;
  else
    wall_left_est = 0.0;
    wall_right_est = 1.8;
  end if;

  // Lidar-derived y position from side ranges
  y_lidar_meas = (wall_left_est + lidar_left + wall_right_est - lidar_right) / 2.0;

  // Fused body velocities: odometry for linear, IMU-weighted for angular
  est_vx = odom_vx;
  est_vy = odom_vy;
  est_wz = K_ekf_wz * imu_wz_meas + (1.0 - K_ekf_wz) * odom_wz;

  // Estimator state propagation with lidar correction on y
  der(est_x) = cos(est_theta) * est_vx - sin(est_theta) * est_vy;
  der(est_y) = sin(est_theta) * est_vx + cos(est_theta) * est_vy + K_ekf_y * (y_lidar_meas - est_y);
  der(est_theta) = est_wz;

  // Covariance propagation (finite, bounded: Riccati-like)
  der(P_x) = Q_pos - P_x * P_x / (R_lidar * 10.0);
  der(P_y) = Q_pos - P_y * P_y / R_lidar;
  der(P_theta) = Q_theta - P_theta * P_theta / R_imu;

  annotation(
    experiment(StartTime = 0.0, StopTime = 14.0, Tolerance = 1e-6, Interval = 0.005),
    Documentation(info = "OmniCartInspectD: 25 kg mecanum-wheel inspection platform (0.095 m radius wheels, 45 deg roller angle, 0.58 x 0.46 m footprint). Fuses wheel odometry, IMU, and 15 m planar lidar for planar pose estimation. Traverses an S-shaped corridor (1.8 m wide walls, two recessed alcoves) at 0.8 m/s with a 90 N side-load disturbance applied during the middle third. Four wheel-torque actuators limited to 12 N.m. Designed for 200 Hz operation over 14 s. Controller uses localization-aware path tracking with obstacle repulsion and integral lateral correction.")
  );
end OmniCartInspectD;