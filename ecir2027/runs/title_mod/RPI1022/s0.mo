model OmniCartInspectB
  "Floating-base mobile robot: S-corridor traversal with sensor fusion and obstacle avoidance"

  // ===== Physical Parameters =====
  parameter Real m = 25.0 "Platform mass [kg]";
  parameter Real r_w = 0.095 "Wheel radius [m]";
  parameter Real gamma = 45.0 "Mecanum roller angle [deg]";
  parameter Real lx = 0.29 "Half length along x [m]";
  parameter Real ly = 0.23 "Half width along y [m]";
  parameter Real I_zz = m*(lx*lx + ly*ly)/12.0 "Yaw moment of inertia [kg.m2]";
  parameter Real tau_max = 9.84 "Max wheel torque [N.m]";
  parameter Real v_ref = 0.8 "Reference forward speed [m/s]";
  parameter Real corridor_hw = 0.9 "Corridor half-width (walls 1.8 m apart) [m]";
  parameter Real F_dist = 63.0 "Side load disturbance magnitude [N]";
  parameter Real amp = 0.35 "S-curve path amplitude [m]";
  parameter Real period = 4.0 "S-curve spatial period [m]";
  parameter Real path_length = 8.0 "Total path length [m]";

  // ===== Controller Gains =====
  parameter Real kp = 10.0 "Position proportional gain [1/s2]";
  parameter Real kd = 5.0 "Velocity damping gain [1/s]";
  parameter Real k_theta = 4.0 "Heading proportional gain [1/s2]";
  parameter Real kd_theta = 2.0 "Heading damping gain [1/s]";
  parameter Real k_obs = 8.0 "Obstacle avoidance gain";
  parameter Real obs_thresh = 0.4 "Obstacle influence threshold [m]";

  // ===== Estimator Parameters =====
  parameter Real alpha_pos = 2.0 "Position correction gain [1/s]";
  parameter Real alpha_vel = 3.0 "Velocity correction gain [1/s]";
  parameter Real cov_decay = 0.1 "Covariance decay rate [1/s]";
  parameter Real cov_drive = 0.001 "Process noise covariance rate [m2/s]";

  // ===== Alcove Parameters =====
  parameter Real alcove1_cx = 2.0 "Alcove 1 center x [m]";
  parameter Real alcove2_cx = 6.0 "Alcove 2 center x [m]";
  parameter Real alcove_sigma = 0.2 "Alcove spatial spread [m]";
  parameter Real alcove_depth = 0.35 "Alcove recess depth [m]";

  // ===== Disturbance Window =====
  parameter Real t_dist_start = 10.0/3.0 "Disturbance start time [s]";
  parameter Real t_dist_end = 20.0/3.0 "Disturbance end time [s]";

  // ===== True Robot State =====
  Real x(start=0.0, fixed=true) "True x position [m]";
  Real y(start=0.0, fixed=true) "True y position [m]";
  Real theta(start=0.0, fixed=true) "True heading [rad]";
  Real vx(start=0.0, fixed=true) "True world x velocity [m/s]";
  Real vy(start=0.0, fixed=true) "True world y velocity [m/s]";
  Real wz(start=0.0, fixed=true) "True yaw rate [rad/s]";

  // Body-frame velocities
  Real vx_b "Body x velocity [m/s]";
  Real vy_b "Body y velocity [m/s]";

  // Wheel angular velocities (odometry)
  Real w1 "FL wheel angular velocity [rad/s]";
  Real w2 "FR wheel angular velocity [rad/s]";
  Real w3 "RL wheel angular velocity [rad/s]";
  Real w4 "RR wheel angular velocity [rad/s]";

  // Wheel torques
  Real tau1_raw "FL unsaturated torque [N.m]";
  Real tau2_raw "FR unsaturated torque [N.m]";
  Real tau3_raw "RL unsaturated torque [N.m]";
  Real tau4_raw "RR unsaturated torque [N.m]";
  Real tau1 "FL saturated torque [N.m]";
  Real tau2 "FR saturated torque [N.m]";
  Real tau3 "RL saturated torque [N.m]";
  Real tau4 "RR saturated torque [N.m]";

  // Body forces from wheels
  Real Fx_b "Body x force from wheels [N]";
  Real Fy_b "Body y force from wheels [N]";
  Real Mz_b "Yaw moment from wheels [N.m]";

  // ===== Reference Path =====
  Real s_ref "Path arc-length parameter [m]";
  Real x_ref "Reference x [m]";
  Real y_ref "Reference y [m]";
  Real theta_ref "Reference heading [rad]";

  // ===== Tracking Errors =====
  Real e_x "Along-track position error [m]";
  Real e_y "Cross-track position error [m]";
  Real e_theta "Heading error [rad]";
  Real e_pos "Primary tracking error (position magnitude) [m]";

  // ===== Corridor Geometry =====
  Real y_centerline "Corridor centerline y at robot x [m]";
  Real alcove_offset "Alcove widening offset [m]";
  Real y_wall_u "Upper wall y [m]";
  Real y_wall_l "Lower wall y [m]";
  Real clr_u "Clearance to upper wall [m]";
  Real clr_l "Clearance to lower wall [m]";
  Real clr_min "Minimum wall clearance [m]";

  // ===== Disturbance =====
  Real Fd_y "Disturbance force in world y [N]";

  // ===== Obstacle Avoidance =====
  Real F_obs_y "Obstacle avoidance force in world y [N]";

  // ===== Controller Intermediates =====
  Real F_world_x_des "Desired world x force [N]";
  Real F_world_y_des "Desired world y force [N]";
  Real Fx_des "Desired body x force [N]";
  Real Fy_des "Desired body y force [N]";
  Real Mz_des "Desired yaw moment [N.m]";

  // ===== Estimator State =====
  Real x_hat(start=0.0, fixed=true) "Estimated x [m]";
  Real y_hat(start=0.0, fixed=true) "Estimated y [m]";
  Real th_hat(start=0.0, fixed=true) "Estimated heading [rad]";
  Real vx_hat(start=0.0, fixed=true) "Estimated vx [m/s]";
  Real vy_hat(start=0.0, fixed=true) "Estimated vy [m/s]";
  Real wz_hat(start=0.0, fixed=true) "Estimated wz [rad/s]";
  Real P_x(start=1.0, fixed=true) "X position covariance [m2]";
  Real P_y(start=1.0, fixed=true) "Y position covariance [m2]";
  Real P_th(start=0.01, fixed=true) "Heading covariance [rad2]";

  // ===== Sensor Outputs =====
  Real lidar_left "Left lidar range [m]";
  Real lidar_right "Right lidar range [m]";
  Real lidar_front "Front lidar range [m]";

  // ===== Mission Status =====
  Real route_progress "Route completion fraction [0-1]";
  Boolean route_complete "Route completion flag";
  Boolean tracking_ok "Primary tracking error below 0.24 m after 6.5 s";
  Boolean clearance_ok "Wall clearance above 0.18 m";

equation
  // ===== Reference Path (S-curve, centered in corridor) =====
  s_ref = min(v_ref * time, path_length);
  x_ref = s_ref;
  y_ref = amp * sin(2.0*Modelica.Constants.pi * s_ref / period);
  theta_ref = atan2(
    amp * (2.0*Modelica.Constants.pi / period) * cos(2.0*Modelica.Constants.pi * s_ref / period),
    1.0
  );

  // ===== Corridor Geometry (S-shaped walls 1.8 m apart with two recessed alcoves) =====
  y_centerline = amp * sin(2.0*Modelica.Constants.pi * x / period);
  alcove_offset = alcove_depth * exp(-((x - alcove1_cx)/alcove_sigma)^2)
                + alcove_depth * exp(-((x - alcove2_cx)/alcove_sigma)^2);
  y_wall_u = y_centerline + corridor_hw + alcove_offset;
  y_wall_l = y_centerline - corridor_hw - alcove_offset;

  // Clearances (finite, well-defined)
  clr_u = y_wall_u - y;
  clr_l = y - y_wall_l;
  clr_min = min(clr_u, clr_l);
  clearance_ok = clr_min > 0.18;

  // ===== Controlled Disturbance (63 N side load during middle third) =====
  Fd_y = if (time >= t_dist_start and time <= t_dist_end) then F_dist else 0.0;

  // ===== Robot Dynamics (planar rigid body, world frame) =====
  der(x) = vx;
  der(y) = vy;
  der(theta) = wz;
  der(vx) = (Fx_b*cos(theta) - Fy_b*sin(theta)) / m;
  der(vy) = (Fx_b*sin(theta) + Fy_b*cos(theta) + Fd_y) / m;
  der(wz) = Mz_b / I_zz;

  // Body-frame velocities (forward kinematics)
  vx_b = vx*cos(theta) + vy*sin(theta);
  vy_b = -vx*sin(theta) + vy*cos(theta);

  // ===== Mecanum Wheel Kinematics (inverse: body vel -> wheel speeds, 45 deg roller) =====
  w1 = (vx_b - vy_b - (lx + ly)*wz) / r_w;
  w2 = (vx_b + vy_b + (lx + ly)*wz) / r_w;
  w3 = (vx_b + vy_b - (lx + ly)*wz) / r_w;
  w4 = (vx_b - vy_b + (lx + ly)*wz) / r_w;

  // ===== Forward Force Kinematics (saturated torques -> body forces) =====
  Fx_b = (tau1 + tau2 + tau3 + tau4) / (4.0*r_w);
  Fy_b = (-tau1 + tau2 + tau3 - tau4) / (4.0*r_w);
  Mz_b = (-tau1 + tau2 - tau3 + tau4) / (4.0*r_w*(lx + ly));

  // ===== Controller: Localization-Aware Path Tracking + Obstacle Avoidance =====
  // Tracking errors computed from estimated (fused) state
  e_x = x_hat - x_ref;
  e_y = y_hat - y_ref;
  e_theta = th_hat - theta_ref;
  // Norm with zero-error branch to prevent division issues
  e_pos = sqrt(e_x*e_x + e_y*e_y + 1e-10);

  // Obstacle avoidance: repulsive force from walls (continuous at threshold)
  F_obs_y = (if clr_u < obs_thresh then k_obs*(obs_thresh - clr_u)^2 else 0.0)
          - (if clr_l < obs_thresh then k_obs*(obs_thresh - clr_l)^2 else 0.0);

  // Desired world-frame forces (PD controller on estimated state)
  F_world_x_des = m*(kp*(x_ref - x_hat) - kd*vx_hat);
  F_world_y_des = m*(kp*(y_ref - y_hat) - kd*vy_hat) + F_obs_y;

  // Transform to body frame using estimated heading
  Fx_des = F_world_x_des*cos(th_hat) + F_world_y_des*sin(th_hat);
  Fy_des = -F_world_x_des*sin(th_hat) + F_world_y_des*cos(th_hat);
  Mz_des = I_zz*(k_theta*(theta_ref - th_hat) - kd_theta*wz_hat);

  // ===== Inverse Force Kinematics: desired body forces -> wheel torques =====
  tau1_raw = r_w*(Fx_des - Fy_des - Mz_des/(lx + ly));
  tau2_raw = r_w*(Fx_des + Fy_des + Mz_des/(lx + ly));
  tau3_raw = r_w*(Fx_des + Fy_des - Mz_des/(lx + ly));
  tau4_raw = r_w*(Fx_des - Fy_des + Mz_des/(lx + ly));

  // Torque saturation at allowed command magnitude
  tau1 = max(-tau_max, min(tau_max, tau1_raw));
  tau2 = max(-tau_max, min(tau_max, tau2_raw));
  tau3 = max(-tau_max, min(tau_max, tau3_raw));
  tau4 = max(-tau_max, min(tau_max, tau4_raw));

  // ===== Sensor Models (15 m planar lidar, range capped) =====
  lidar_left = min(15.0, max(0.01, clr_u));
  lidar_right = min(15.0, max(0.01, clr_l));
  lidar_front = min(15.0, max(0.01, path_length - x));

  // ===== Estimator: Fused Wheel Odometry + IMU + Lidar (EKF-like) =====
  // Prediction: integrate using saturated commanded body forces
  // Correction: measurement update weighted by covariance (finite, bounded)
  // Sensor measurements are derived from true state (simulation proxy for fused lidar/IMU/odom)
  der(x_hat) = vx_hat + alpha_pos*(P_x/(P_x + 0.01))*(x - x_hat);
  der(y_hat) = vy_hat + alpha_pos*(P_y/(P_y + 0.01))*(y - y_hat);
  der(th_hat) = wz_hat + alpha_pos*(P_th/(P_th + 0.001))*(theta - th_hat);
  der(vx_hat) = (Fx_b*cos(th_hat) - Fy_b*sin(th_hat))/m + alpha_vel*(vx - vx_hat);
  der(vy_hat) = (Fx_b*sin(th_hat) + Fy_b*cos(th_hat))/m + alpha_vel*(vy - vy_hat);
  der(wz_hat) = Mz_b/I_zz + alpha_vel*(wz - wz_hat);

  // Covariance propagation (finite, converges to cov_drive/cov_decay)
  der(P_x) = cov_drive - cov_decay*P_x;
  der(P_y) = cov_drive - cov_decay*P_y;
  der(P_th) = cov_drive*0.01 - cov_decay*P_th;

  // ===== Mission Status =====
  route_progress = min(max(x/path_length, 0.0), 1.0);
  route_complete = route_progress >= 0.95;
  tracking_ok = if time >= 6.5 then e_pos < 0.24 else true;

end OmniCartInspectB;