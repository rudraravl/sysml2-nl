model GroundTrioResilientD
  "Instrumented three-robot differential-drive warehouse fleet with communication dropout resilience"

  // ===== Simulation timing =====
  parameter Real T_sim = 14.0           "Total simulation duration [s]";
  parameter Real dt_ctrl = 0.005        "Control period [s] (200 Hz)";

  // ===== Communication dropout (middle third of 14 s) =====
  parameter Real T_drop_start = 4.67    "Dropout start [s]";
  parameter Real T_drop_end   = 5.67    "Dropout end [s] (1 s dropout)";

  // ===== Robot physical parameters =====
  parameter Real m_robot  = 18.0        "Robot mass [kg]";
  parameter Real I_robot  = 0.72        "Yaw moment of inertia [kg.m2]";
  parameter Real r_wheel  = 0.10        "Wheel radius [m]";
  parameter Real track_w  = 0.40        "Track width [m]";
  parameter Real tau_max  = 12.0        "Wheel torque bound [N.m]";
  parameter Real mu_f     = 3.0         "Linear friction [N.s/m]";
  parameter Real mu_r     = 2.0         "Rotational friction [N.m.s/rad]";

  // ===== Formation geometry =====
  parameter Real form_dx   = 1.2        "Formation longitudinal spacing [m]";
  parameter Real form_dy   = 1.5        "Formation lateral spacing [m]";
  parameter Real safe_dist = 0.8        "Collision avoidance trigger [m]";
  parameter Real eps_dist  = 0.001      "Distance guard [m]";

  // ===== Control gains =====
  parameter Real k_form = 0.3           "Formation correction gain";
  parameter Real k_rep  = 3.0           "Repulsion gain [N]";
  parameter Real k_v    = 1.5           "Position error to velocity gain [1/s]";
  parameter Real k_w    = 2.5           "Lateral error to yaw rate gain [1/(s.m)]";
  parameter Real k_pv   = 10.0          "Velocity tracking gain [N.s/m]";
  parameter Real k_pw   = 8.0           "Yaw rate tracking gain [N.m.s/rad]";

  // ===== Peer state convergence correction =====
  parameter Real k_corr   = 5.0         "Peer position convergence gain [1/s]";
  parameter Real k_corr_v = 10.0        "Peer velocity convergence gain [1/s]";

  // ===== Route =====
  parameter Real route_speed      = 0.7  "Reference forward speed [m/s]";
  parameter Real route_end        = 7.0  "Route end x-position [m]";
  parameter Real tracking_thresh  = 0.6  "Primary tracking threshold [m]";

  // ===== Reference offsets per robot =====
  parameter Real ref_off_x[3] = {0.0, -1.2, -1.2}  "Robot ref x offsets [m]";
  parameter Real ref_off_y[3] = {0.0, -1.5,  1.5}  "Robot ref y offsets [m]";

  // ===== Desired relative positions (i relative to j) =====
  parameter Real desired_dx[3,3] = {{0.0,  1.2,  1.2},
                                     {-1.2,  0.0,  0.0},
                                     {-1.2,  0.0,  0.0}}  "Desired dx(i,j) [m]";
  parameter Real desired_dy[3,3] = {{0.0,  1.5, -1.5},
                                     {-1.5,  0.0, -3.0},
                                     { 1.5,  3.0,  0.0}}  "Desired dy(i,j) [m]";

  // ===== Desired inter-robot distances =====
  parameter Real d12_des = 1.9209372     "Desired dist 1-2 [m]";
  parameter Real d13_des = 1.9209372     "Desired dist 1-3 [m]";
  parameter Real d23_des = 3.0           "Desired dist 2-3 [m]";

  // ===== Clock and communication =====
  Real t_clock(start = 0.0)               "Master clock [s]";
  Boolean comm_active                     "Communication link active";

  // ===== Disturbance (shared) =====
  Real dist_long                          "Shared longitudinal disturbance [N]";
  Real dist_yaw                           "Shared yaw disturbance [N.m]";

  // ===== Reference trajectory =====
  Real ref_x_global                       "Global reference x [m]";
  Real ref_x[3]                           "Per-robot reference x [m]";
  Real ref_y[3]                           "Per-robot reference y [m]";

  // ===== Robot physical states =====
  Real x[3](start = {0.0, -1.2, -1.2})    "Robot x position [m]";
  Real y[3](start = {0.0, -1.5,  1.5})    "Robot y position [m]";
  Real theta[3](start = {0.0, 0.0, 0.0})  "Robot heading [rad]";
  Real v[3](start = {0.0, 0.0, 0.0})      "Linear velocity [m/s]";
  Real w[3](start = {0.0, 0.0, 0.0})      "Angular velocity [rad/s]";

  // ===== Wheel torques =====
  Real tau_R_cmd[3]                       "Right wheel torque command [N.m]";
  Real tau_L_cmd[3]                       "Left wheel torque command [N.m]";
  Real tau_R[3]                           "Saturated right torque [N.m]";
  Real tau_L[3]                           "Saturated left torque [N.m]";

  // ===== Odometry (local proprioception) =====
  Real x_odom[3](start = {0.0, -1.2, -1.2})   "Odometric x [m]";
  Real y_odom[3](start = {0.0, -1.5,  1.5})   "Odometric y [m]";
  Real theta_odom[3](start = {0.0, 0.0, 0.0})  "Odometric heading [rad]";
  Real v_odom[3]                              "Odometric linear vel [m/s]";
  Real w_odom[3]                              "Odometric angular vel [rad/s]";
  Real t_odom[3](start = {0.0, 0.0, 0.0})     "Odometry timestamp [s]";

  // ===== Lidar (exteroception) =====
  Real lidar_dist[3,3]                    "Lidar pairwise distance [m]";
  Real t_lidar[3](start = {0.0, 0.0, 0.0}) "Lidar timestamp [s]";

  // ===== Peer state (last-received with timestamps) =====
  Real peer_x[3,3]                        "Peer x estimate [m]";
  Real peer_y[3,3]                        "Peer y estimate [m]";
  Real peer_theta[3,3]                    "Peer heading estimate [rad]";
  Real peer_v[3,3]                        "Peer velocity estimate [m/s]";
  Real peer_w[3,3]                        "Peer yaw rate estimate [rad/s]";
  Real t_peer[3,3]                        "Last peer msg timestamp [s]";

  // Peer hold states (for prediction during dropout)
  Real peer_x_hold[3,3](start     = {{0.0,-1.2,-1.2}, {0.0,-1.2,-1.2}, {0.0,-1.2,-1.2}})  "Held peer x [m]";
  Real peer_y_hold[3,3](start     = {{0.0,-1.5, 1.5}, {0.0,-1.5, 1.5}, {0.0,-1.5, 1.5}})  "Held peer y [m]";
  Real peer_theta_hold[3,3](start = {{0.0,0.0,0.0}, {0.0,0.0,0.0}, {0.0,0.0,0.0}})        "Held peer heading [rad]";
  Real peer_v_hold[3,3](start     = {{0.0,0.0,0.0}, {0.0,0.0,0.0}, {0.0,0.0,0.0}})        "Held peer velocity [m/s]";
  Real peer_w_hold[3,3](start     = {{0.0,0.0,0.0}, {0.0,0.0,0.0}, {0.0,0.0,0.0}})        "Held peer yaw rate [rad/s]";

  // ===== Control intermediates =====
  Real form_corr_x[3]                    "Formation correction x [m]";
  Real form_corr_y[3]                    "Formation correction y [m]";
  Real rep_x[3]                           "Repulsion force x [N]";
  Real rep_y[3]                           "Repulsion force y [N]";
  Real e_x[3]                             "Total position error x [m]";
  Real e_y[3]                             "Total position error y [m]";
  Real e_long[3]                          "Body-frame longitudinal error [m]";
  Real e_lat[3]                           "Body-frame lateral error [m]";
  Real v_ref[3]                           "Reference velocity [m/s]";
  Real w_ref[3]                           "Reference yaw rate [rad/s]";
  Real F_des[3]                           "Desired force [N]";
  Real T_des[3]                           "Desired torque [N.m]";

  // ===== Acceleration helpers =====
  Real a_robot[3]                         "Robot linear acceleration [m/s2]";
  Real alpha_robot[3]                     "Robot angular acceleration [rad/s2]";

  // ===== Metrics =====
  Real dist12                             "Actual distance 1-2 [m]";
  Real dist13                             "Actual distance 1-3 [m]";
  Real dist23                             "Actual distance 2-3 [m]";
  Real formation_error                    "Current formation error [m]";
  Real tracking_error_primary             "Primary robot tracking error [m]";
  Boolean route_completed                 "Route completed flag";
  Boolean tracking_ok                     "Tracking below threshold after 9.1 s";

equation
  // ===== Master clock =====
  der(t_clock) = 1.0;

  // ===== Communication link =====
  comm_active = not (t_clock >= T_drop_start and t_clock < T_drop_end);

  // ===== Shared environmental disturbance (active only during dropout) =====
  dist_long = if (t_clock >= T_drop_start and t_clock < T_drop_end) then 3.0 else 0.0;
  dist_yaw  = if (t_clock >= T_drop_start and t_clock < T_drop_end) then 0.5 else 0.0;

  // ===== Reference trajectory =====
  ref_x_global = min(route_speed * t_clock, route_end);
  for i in 1:3 loop
    ref_x[i] = ref_x_global + ref_off_x[i];
    ref_y[i] = ref_off_y[i];
  end for;

  // ===== Robot dynamics and odometry =====
  for i in 1:3 loop
    // Kinematic state
    der(x[i])     = v[i] * cos(theta[i]);
    der(y[i])     = v[i] * sin(theta[i]);
    der(theta[i]) = w[i];

    // Newton-Euler dynamics with shared disturbance
    m_robot * der(v[i]) = (tau_R[i] + tau_L[i]) / r_wheel - mu_f * v[i] + dist_long;
    I_robot * der(w[i]) = (tau_R[i] - tau_L[i]) * track_w / (2.0 * r_wheel) - mu_r * w[i] + dist_yaw;

    // Acceleration helpers for peer prediction tracking
    a_robot[i]     = ((tau_R[i] + tau_L[i]) / r_wheel - mu_f * v[i] + dist_long) / m_robot;
    alpha_robot[i] = ((tau_R[i] - tau_L[i]) * track_w / (2.0 * r_wheel) - mu_r * w[i] + dist_yaw) / I_robot;

    // Odometry (ideal local proprioception with timestamp)
    der(x_odom[i])     = v[i] * cos(theta[i]);
    der(y_odom[i])     = v[i] * sin(theta[i]);
    der(theta_odom[i]) = w[i];
    v_odom[i]          = v[i];
    w_odom[i]          = w[i];
    der(t_odom[i])     = 1.0;
    der(t_lidar[i])    = 1.0;

    // Actuator saturation (bounded wheel drives)
    tau_R[i] = max(-tau_max, min(tau_max, tau_R_cmd[i]));
    tau_L[i] = max(-tau_max, min(tau_max, tau_L_cmd[i]));
  end for;

  // ===== Peer state tracking with prediction during dropout =====
  for i in 1:3 loop
    for j in 1:3 loop
      // During comm: track true state with convergence correction
      // During dropout: predict using frozen velocity (dead reckoning)
      der(peer_x_hold[i,j]) = if comm_active then
        v[j] * cos(theta[j]) + k_corr * (x[j] - peer_x_hold[i,j])
      else
        peer_v_hold[i,j] * cos(peer_theta_hold[i,j]);

      der(peer_y_hold[i,j]) = if comm_active then
        v[j] * sin(theta[j]) + k_corr * (y[j] - peer_y_hold[i,j])
      else
        peer_v_hold[i,j] * sin(peer_theta_hold[i,j]);

      der(peer_theta_hold[i,j]) = if comm_active then
        w[j] + k_corr * (theta[j] - peer_theta_hold[i,j])
      else
        peer_w_hold[i,j];

      der(peer_v_hold[i,j]) = if comm_active then
        a_robot[j] + k_corr_v * (v[j] - peer_v_hold[i,j])
      else
        0.0;

      der(peer_w_hold[i,j]) = if comm_active then
        alpha_robot[j] + k_corr_v * (w[j] - peer_w_hold[i,j])
      else
        0.0;

      // Timestamp freezes during dropout
      der(t_peer[i,j]) = if comm_active then 1.0 else 0.0;

      // Peer estimate: true during comm, predicted (held) during dropout
      peer_x[i,j]     = if comm_active then x[j]     else peer_x_hold[i,j];
      peer_y[i,j]     = if comm_active then y[j]     else peer_y_hold[i,j];
      peer_theta[i,j] = if comm_active then theta[j] else peer_theta_hold[i,j];
      peer_v[i,j]     = if comm_active then v[j]     else peer_v_hold[i,j];
      peer_w[i,j]     = if comm_active then w[j]     else peer_w_hold[i,j];
    end for;
  end for;

  // Initialize timestamps for peer messages
  for i in 1:3 loop
    for j in 1:3 loop
      // t_peer starts at 0 via initial equation below
    end for;
  end for;

initial equation
  for i in 1:3 loop
    for j in 1:3 loop
      t_peer[i,j] = 0.0;
    end for;
  end for;

equation
  // ===== Lidar: true pairwise distances =====
  for i in 1:3 loop
    for j in 1:3 loop
      lidar_dist[i,j] = if i <> j then
        sqrt(max((x[i]-x[j])*(x[i]-x[j]) + (y[i]-y[j])*(y[i]-y[j]), eps_dist*eps_dist))
      else
        10.0;
    end for;
  end for;

  // ===== Formation correction (distributed, using peer estimates) =====
  // Robot 1 (peers 2, 3)
  form_corr_x[1] = (peer_x[1,2] + desired_dx[1,2] - x_odom[1])
                 + (peer_x[1,3] + desired_dx[1,3] - x_odom[1]);
  form_corr_y[1] = (peer_y[1,2] + desired_dy[1,2] - y_odom[1])
                 + (peer_y[1,3] + desired_dy[1,3] - y_odom[1]);
  // Robot 2 (peers 1, 3)
  form_corr_x[2] = (peer_x[2,1] + desired_dx[2,1] - x_odom[2])
                 + (peer_x[2,3] + desired_dx[2,3] - x_odom[2]);
  form_corr_y[2] = (peer_y[2,1] + desired_dy[2,1] - y_odom[2])
                 + (peer_y[2,3] + desired_dy[2,3] - y_odom[2]);
  // Robot 3 (peers 1, 2)
  form_corr_x[3] = (peer_x[3,1] + desired_dx[3,1] - x_odom[3])
                 + (peer_x[3,2] + desired_dx[3,2] - x_odom[3]);
  form_corr_y[3] = (peer_y[3,1] + desired_dy[3,1] - y_odom[3])
                 + (peer_y[3,2] + desired_dy[3,2] - y_odom[3]);

  // ===== Collision avoidance via lidar (repulsive forces) =====
  // Robot 1
  rep_x[1] = (if lidar_dist[1,2] < safe_dist then k_rep * (safe_dist - lidar_dist[1,2]) * (x_odom[1] - peer_x[1,2]) / max(lidar_dist[1,2], eps_dist) else 0.0)
           + (if lidar_dist[1,3] < safe_dist then k_rep * (safe_dist - lidar_dist[1,3]) * (x_odom[1] - peer_x[1,3]) / max(lidar_dist[1,3], eps_dist) else 0.0);
  rep_y[1] = (if lidar_dist[1,2] < safe_dist then k_rep * (safe_dist - lidar_dist[1,2]) * (y_odom[1] - peer_y[1,2]) / max(lidar_dist[1,2], eps_dist) else 0.0)
           + (if lidar_dist[1,3] < safe_dist then k_rep * (safe_dist - lidar_dist[1,3]) * (y_odom[1] - peer_y[1,3]) / max(lidar_dist[1,3], eps_dist) else 0.0);
  // Robot 2
  rep_x[2] = (if lidar_dist[2,1] < safe_dist then k_rep * (safe_dist - lidar_dist[2,1]) * (x_odom[2] - peer_x[2,1]) / max(lidar_dist[2,1], eps_dist) else 0.0)
           + (if lidar_dist[2,3] < safe_dist then k_rep * (safe_dist - lidar_dist[2,3]) * (x_odom[2] - peer_x[2,3]) / max(lidar_dist[2,3], eps_dist) else 0.0);
  rep_y[2] = (if lidar_dist[2,1] < safe_dist then k_rep * (safe_dist - lidar_dist[2,1]) * (y_odom[2] - peer_y[2,1]) / max(lidar_dist[2,1], eps_dist) else 0.0)
           + (if lidar_dist[2,3] < safe_dist then k_rep * (safe_dist - lidar_dist[2,3]) * (y_odom[2] - peer_y[2,3]) / max(lidar_dist[2,3], eps_dist) else 0.0);
  // Robot 3
  rep_x[3] = (if lidar_dist[3,1] < safe_dist then k_rep * (safe_dist - lidar_dist[3,1]) * (x_odom[3] - peer_x[3,1]) / max(lidar_dist[3,1], eps_dist) else 0.0)
           + (if lidar_dist[3,2] < safe_dist then k_rep * (safe_dist - lidar_dist[3,2]) * (x_odom[3] - peer_x[3,2]) / max(lidar_dist[3,2], eps_dist) else 0.0);
  rep_y[3] = (if lidar_dist[3,1] < safe_dist then k_rep * (safe_dist - lidar_dist[3,1]) * (y_odom[3] - peer_y[3,1]) / max(lidar_dist[3,1], eps_dist) else 0.0)
           + (if lidar_dist[3,2] < safe_dist then k_rep * (safe_dist - lidar_dist[3,2]) * (y_odom[3] - peer_y[3,2]) / max(lidar_dist[3,2], eps_dist) else 0.0);

  // ===== Distributed control law =====
  for i in 1:3 loop
    // Total position error: reference tracking + formation correction + collision avoidance
    e_x[i] = (ref_x[i] - x_odom[i]) + k_form * form_corr_x[i] + rep_x[i];
    e_y[i] = (ref_y[i] - y_odom[i]) + k_form * form_corr_y[i] + rep_y[i];

    // Transform to body frame
    e_long[i] =  e_x[i] * cos(theta_odom[i]) + e_y[i] * sin(theta_odom[i]);
    e_lat[i]  = -e_x[i] * sin(theta_odom[i]) + e_y[i] * cos(theta_odom[i]);

    // Velocity commands
    v_ref[i] = k_v * e_long[i];
    w_ref[i] = k_w * e_lat[i];

    // Force/torque commands with friction feedforward
    F_des[i] = k_pv * (v_ref[i] - v[i]) + mu_f * v[i];
    T_des[i] = k_pw * (w_ref[i] - w[i]) + mu_r * w[i];

    // Map to wheel torques
    tau_R_cmd[i] = r_wheel * (F_des[i] / 2.0 + T_des[i] / track_w);
    tau_L_cmd[i] = r_wheel * (F_des[i] / 2.0 - T_des[i] / track_w);
  end for;

  // ===== Pairwise distance metrics =====
  dist12 = sqrt(max((x[1]-x[2])*(x[1]-x[2]) + (y[1]-y[2])*(y[1]-y[2]), eps_dist*eps_dist));
  dist13 = sqrt(max((x[1]-x[3])*(x[1]-x[3]) + (y[1]-y[3])*(y[1]-y[3]), eps_dist*eps_dist));
  dist23 = sqrt(max((x[2]-x[3])*(x[2]-x[3]) + (y[2]-y[3])*(y[2]-y[3]), eps_dist*eps_dist));

  // ===== Formation and tracking metrics =====
  formation_error = (abs(dist12 - d12_des) + abs(dist13 - d13_des) + abs(dist23 - d23_des)) / 3.0;
  tracking_error_primary = sqrt(max((x[1]-ref_x[1])*(x[1]-ref_x[1]) + (y[1]-ref_y[1])*(y[1]-ref_y[1]), 0.0));
  route_completed = ref_x_global >= route_end - 0.01;
  tracking_ok = t_clock >= 9.1 and tracking_error_primary < tracking_thresh;

  annotation(
    experiment(StartTime = 0, StopTime = 14, Tolerance = 1e-6, Interval = 0.005),
    Documentation(info = "Three 18 kg differential-drive warehouse robots with distributed control, "
      + "communication dropout prediction, collision avoidance, and formation recovery. "
      + "1 s dropout in middle third (4.67-5.67 s) with shared disturbance. "
      + "Run at 200 Hz (Interval=0.005 s) for 14 s. "
      + "All states, commands, and sensor traces are observable. "
      + "All divisors are guarded against zero; all sqrt arguments are non-negative. "
      + "Actuator torques bounded to +/-12 N.m per wheel.")
  );
end GroundTrioResilientD;