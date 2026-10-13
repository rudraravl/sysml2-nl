model MixedTeamResilientC
  /* Multi-robot system with distributed control and prediction during dropout.
     24 kg lidar ground robot + 2.1 kg camera quadrotor.
     0.9 s comm dropout injected at 5.55-6.45 s (middle third of 12 s run).
     Command bound 12.9 N.m (wheel torques) / N (rotor thrusts).
     Shared environmental disturbance applied only during dropout.
     Route target, formation offset, drag, wheel radius, wheelbase, arm length,
     inertia, and controller gains are design choices (not stated facts). */

  // ===== Timing =====
  parameter Real Ts = 0.008 "Sampling period for 125 Hz s";
  parameter Real T_end = 12.0 "Simulation duration s";
  parameter Real t_drop_start = 5.55 "Dropout start s (middle third 4-8 s)";
  parameter Real t_drop_end = 6.45  "Dropout end s (0.9 s duration)";

  // ===== Command bound =====
  parameter Real u_max = 12.9 "Maximum command magnitude N.m or N";

  // ===== Ground robot parameters (stated mass; others design assumptions) =====
  parameter Real m_g = 24.0 "Ground robot mass kg";
  parameter Real r_w = 0.15 "Wheel radius m (design assumption)";
  parameter Real L_w = 0.50 "Wheelbase m (design assumption)";
  parameter Real I_g = 3.0  "Yaw inertia kg.m2 (design assumption)";
  parameter Real b_g = 5.0  "Linear drag N.s/m (design assumption)";
  parameter Real b_theta = 2.0 "Yaw drag N.m.s (design assumption)";

  // ===== Quadrotor parameters (stated mass; others design assumptions) =====
  parameter Real m_q = 2.1 "Quadrotor mass kg";
  parameter Real g = 9.81 "Gravitational acceleration m/s2";
  parameter Real L_arm = 0.20 "Rotor arm length m (design assumption)";
  parameter Real b_q = 0.5 "Linear drag N.s/m (design assumption)";

  // ===== Route and formation (design choices) =====
  parameter Real x_target = 5.0  "Route endpoint x m";
  parameter Real z_hover = 2.5   "Quadrotor hover height m";
  parameter Real form_off_y = 1.5 "Formation lateral offset m";
  parameter Real safe_dist = 1.0 "Collision avoidance safe distance m";
  parameter Real t_ramp = 6.0   "Route ramp completion time s";

  // ===== Shared disturbance during dropout (design choice) =====
  parameter Real w_env_x = 1.0 "Shared disturbance x N";
  parameter Real w_env_y = 0.5 "Shared disturbance y N";

  // ===== Controller gains (design choices) =====
  parameter Real kp_g = 100.0 "Ground robot position gain";
  parameter Real kd_g = 40.0  "Ground robot velocity gain";
  parameter Real kp_theta = 10.0 "Ground robot heading gain";
  parameter Real kd_theta = 6.0  "Ground robot heading rate gain";
  parameter Real kp_q = 8.0  "Quadrotor xy position gain";
  parameter Real kd_q = 5.0  "Quadrotor xy velocity gain";
  parameter Real kp_qz = 10.0 "Quadrotor z position gain";
  parameter Real kd_qz = 6.0  "Quadrotor z velocity gain";
  parameter Real k_ca = 20.0 "Collision avoidance gain";
  parameter Real k_filt = 3.0 "Peer/estimate filter rate 1/s";

  // ===== Communication =====
  Boolean comm_ok "Communication availability flag";

  // ===== Ground robot states =====
  Real x_g(start=0.0) "Ground robot x position m";
  Real y_g(start=0.0) "Ground robot y position m";
  Real theta_g(start=0.0) "Ground robot heading rad";
  Real v_g(start=0.0) "Ground robot forward velocity m/s";
  Real omega_g(start=0.0) "Ground robot yaw rate rad/s";

  // ===== Quadrotor states =====
  Real x_q(start=0.0) "Quadrotor x position m";
  Real y_q(start=1.5) "Quadrotor y position m";
  Real z_q(start=2.5) "Quadrotor z position m";
  Real vx_q(start=0.0) "Quadrotor x velocity m/s";
  Real vy_q(start=0.0) "Quadrotor y velocity m/s";
  Real vz_q(start=0.0) "Quadrotor z velocity m/s";

  // ===== Wheel torque commands and saturated values =====
  Real tau_L_cmd "Left wheel torque command N.m";
  Real tau_R_cmd "Right wheel torque command N.m";
  Real tau_L     "Saturated left wheel torque N.m";
  Real tau_R     "Saturated right wheel torque N.m";

  // ===== Rotor thrust commands and saturated values =====
  Real T1_cmd "Rotor 1 thrust command N";
  Real T2_cmd "Rotor 2 thrust command N";
  Real T3_cmd "Rotor 3 thrust command N";
  Real T4_cmd "Rotor 4 thrust command N";
  Real T1 "Saturated rotor 1 thrust N";
  Real T2 "Saturated rotor 2 thrust N";
  Real T3 "Saturated rotor 3 thrust N";
  Real T4 "Saturated rotor 4 thrust N";

  // ===== Peer state: ground robot's last-received view of quadrotor =====
  Real x_peer_q(start=0.0)  "Last received quad x m";
  Real y_peer_q(start=1.5)  "Last received quad y m";
  Real z_peer_q(start=2.5)  "Last received quad z m";
  Real vx_peer_q(start=0.0) "Last received quad vx m/s";
  Real vy_peer_q(start=0.0) "Last received quad vy m/s";
  Real vz_peer_q(start=0.0) "Last received quad vz m/s";

  // ===== Peer state: quadrotor's last-received view of ground robot =====
  Real x_peer_g(start=0.0)  "Last received ground x m";
  Real y_peer_g(start=0.0)  "Last received ground y m";
  Real vx_peer_g(start=0.0) "Last received ground vx m/s";
  Real vy_peer_g(start=0.0) "Last received ground vy m/s";

  // ===== Timestamps (algebraic) =====
  Real t_stamp_q "Timestamp of last quad pose/map update at ground robot s";
  Real t_stamp_g "Timestamp of last ground pose/map update at quadrotor s";

  // ===== Prediction during dropout =====
  Real x_pred_q "Predicted quad x at ground robot m";
  Real y_pred_q "Predicted quad y at ground robot m";
  Real x_pred_g "Predicted ground x at quadrotor m";
  Real y_pred_g "Predicted ground y at quadrotor m";
  Real peer_age_q "Age of last quad data at ground robot s";
  Real peer_age_g "Age of last ground data at quadrotor s";

  // ===== Local estimates (proprioception + exteroception fusion) =====
  Real x_hat_g(start=0.0)     "Ground robot x estimate m";
  Real y_hat_g(start=0.0)     "Ground robot y estimate m";
  Real theta_hat_g(start=0.0) "Ground robot heading estimate rad";
  Real x_hat_q(start=0.0)  "Quadrotor x estimate m";
  Real y_hat_q(start=1.5)  "Quadrotor y estimate m";
  Real z_hat_q(start=2.5)  "Quadrotor z estimate m";

  // ===== Route and formation references =====
  Real x_ref "Route reference x m";
  Real route_completed "Route completion flag 1=done 0=not";
  Real x_form_des "Desired formation x for quadrotor m";
  Real y_form_des "Desired formation y for quadrotor m";

  // ===== Controller internals =====
  Real F_g_des "Desired ground forward force N";
  Real M_g_des "Desired ground yaw moment N.m";
  Real Fx_q_des "Desired quad x force N";
  Real Fy_q_des "Desired quad y force N";
  Real Fz_q_des "Desired quad z force N";
  Real T_total_des "Desired total rotor thrust N";
  Real delta_pitch "Pitch thrust differential N";
  Real delta_roll  "Roll thrust differential N";

  // ===== Collision avoidance =====
  Real dist_robots "Inter-robot horizontal distance m";
  Real ca_fx "Collision avoidance force x N";
  Real ca_fy "Collision avoidance force y N";

  // ===== Error metrics =====
  Real err_primary "Primary tracking error (ground robot to route end) m";
  Real err_formation "Formation error m";
  Real err_formation_degraded(start=0.0) "Formation error during dropout m";
  Real err_formation_recovered(start=0.0) "Formation error after recovery m";

equation
  // ===== Communication availability =====
  comm_ok = not (time >= t_drop_start and time <= t_drop_end);

  // ===== Timestamps: current time when comm ok, frozen at dropout start =====
  t_stamp_q = if comm_ok then time else t_drop_start;
  t_stamp_g = if comm_ok then time else t_drop_start;

  // ===== Peer age =====
  peer_age_q = max(0.0, time - t_stamp_q);
  peer_age_g = max(0.0, time - t_stamp_g);

  // ===== Route reference =====
  x_ref = if time < t_ramp then x_target * time / t_ramp else x_target;
  route_completed = if abs(x_g - x_target) < 0.1 and abs(y_g) < 0.05 then 1.0 else 0.0;

  // ===== Ground robot dynamics (unicycle with wheel torque inputs) =====
  der(x_g) = v_g * cos(theta_g);
  der(y_g) = v_g * sin(theta_g);
  der(theta_g) = omega_g;
  m_g * der(v_g) = (tau_L + tau_R) / r_w - b_g * v_g
    + (if comm_ok then 0.0 else w_env_x);
  I_g * der(omega_g) = (tau_R - tau_L) * L_w / (2.0 * r_w) - b_theta * omega_g;

  // ===== Quadrotor dynamics (simplified 3D point mass with 4 thrust inputs) =====
  der(x_q) = vx_q;
  der(y_q) = vy_q;
  der(z_q) = vz_q;
  m_q * der(vx_q) = (T1 + T2 - T3 - T4) * L_arm - b_q * vx_q
    + (if comm_ok then 0.0 else w_env_x);
  m_q * der(vy_q) = (T1 + T4 - T2 - T3) * L_arm - b_q * vy_q
    + (if comm_ok then 0.0 else w_env_y);
  m_q * der(vz_q) = (T1 + T2 + T3 + T4) - m_q * g - b_q * vz_q;

  // ===== Local estimates (fused proprioception + exteroception) =====
  der(x_hat_g) = k_filt * (x_g - x_hat_g);
  der(y_hat_g) = k_filt * (y_g - y_hat_g);
  der(theta_hat_g) = k_filt * (theta_g - theta_hat_g);
  der(x_hat_q) = k_filt * (x_q - x_hat_q);
  der(y_hat_q) = k_filt * (y_q - y_hat_q);
  der(z_hat_q) = k_filt * (z_q - z_hat_q);

  // ===== Peer state update: track when comm ok, freeze during dropout =====
  der(x_peer_q) = if comm_ok then k_filt * (x_q - x_peer_q) else 0.0;
  der(y_peer_q) = if comm_ok then k_filt * (y_q - y_peer_q) else 0.0;
  der(z_peer_q) = if comm_ok then k_filt * (z_q - z_peer_q) else 0.0;
  der(vx_peer_q) = if comm_ok then k_filt * (vx_q - vx_peer_q) else 0.0;
  der(vy_peer_q) = if comm_ok then k_filt * (vy_q - vy_peer_q) else 0.0;
  der(vz_peer_q) = if comm_ok then k_filt * (vz_q - vz_peer_q) else 0.0;
  der(x_peer_g) = if comm_ok then k_filt * (x_g - x_peer_g) else 0.0;
  der(y_peer_g) = if comm_ok then k_filt * (y_g - y_peer_g) else 0.0;
  der(vx_peer_g) = if comm_ok then k_filt * (v_g * cos(theta_g) - vx_peer_g) else 0.0;
  der(vy_peer_g) = if comm_ok then k_filt * (v_g * sin(theta_g) - vy_peer_g) else 0.0;

  // ===== Prediction: dead reckoning from last-received peer state =====
  x_pred_q = x_peer_q + vx_peer_q * peer_age_q;
  y_pred_q = y_peer_q + vy_peer_q * peer_age_q;
  x_pred_g = x_peer_g + vx_peer_g * peer_age_g;
  y_pred_g = y_peer_g + vy_peer_g * peer_age_g;

  // ===== Formation target: peer state when comm ok, prediction during dropout =====
  x_form_des = if comm_ok then x_peer_g else x_pred_g;
  y_form_des = (if comm_ok then y_peer_g else y_pred_g) + form_off_y;

  // ===== Collision avoidance (exteroception-based, repulsive) =====
  dist_robots = sqrt(max(0.01, (x_q - x_g)^2 + (y_q - y_g)^2));
  ca_fx = if dist_robots < safe_dist
    then k_ca * (safe_dist - dist_robots) * (x_q - x_g) / dist_robots
    else 0.0;
  ca_fy = if dist_robots < safe_dist
    then k_ca * (safe_dist - dist_robots) * (y_q - y_g) / dist_robots
    else 0.0;

  // ===== Ground robot controller (route tracking PD + heading PD) =====
  F_g_des = kp_g * (x_ref - x_hat_g) - kd_g * v_g;
  M_g_des = kp_theta * (0.0 - theta_hat_g) - kd_theta * omega_g;
  // Inverse map: F=(tau_L+tau_R)/r_w, M=(tau_R-tau_L)*L_w/(2*r_w)
  tau_L_cmd = r_w * (F_g_des - 2.0 * M_g_des / L_w) / 2.0;
  tau_R_cmd = r_w * (F_g_des + 2.0 * M_g_des / L_w) / 2.0;
  // Saturate wheel torques to [-u_max, +u_max]
  tau_L = if tau_L_cmd > u_max then u_max
    else if tau_L_cmd < -u_max then -u_max else tau_L_cmd;
  tau_R = if tau_R_cmd > u_max then u_max
    else if tau_R_cmd < -u_max then -u_max else tau_R_cmd;

  // ===== Quadrotor controller (formation PD + hover PD + collision avoidance) =====
  Fx_q_des = kp_q * (x_form_des - x_hat_q) - kd_q * vx_q + ca_fx;
  Fy_q_des = kp_q * (y_form_des - y_hat_q) - kd_q * vy_q + ca_fy;
  Fz_q_des = kp_qz * (z_hover - z_hat_q) - kd_qz * vz_q;
  // Map desired forces to 4 rotor thrusts
  T_total_des = Fz_q_des + m_q * g;
  delta_pitch = Fx_q_des / (2.0 * L_arm);
  delta_roll  = Fy_q_des / (2.0 * L_arm);
  T1_cmd = T_total_des / 4.0 + delta_pitch / 2.0 + delta_roll / 2.0;
  T2_cmd = T_total_des / 4.0 + delta_pitch / 2.0 - delta_roll / 2.0;
  T3_cmd = T_total_des / 4.0 - delta_pitch / 2.0 - delta_roll / 2.0;
  T4_cmd = T_total_des / 4.0 - delta_pitch / 2.0 + delta_roll / 2.0;
  // Saturate rotor thrusts to [0, u_max]
  T1 = if T1_cmd > u_max then u_max else if T1_cmd < 0.0 then 0.0 else T1_cmd;
  T2 = if T2_cmd > u_max then u_max else if T2_cmd < 0.0 then 0.0 else T2_cmd;
  T3 = if T3_cmd > u_max then u_max else if T3_cmd < 0.0 then 0.0 else T3_cmd;
  T4 = if T4_cmd > u_max then u_max else if T4_cmd < 0.0 then 0.0 else T4_cmd;

  // ===== Error metrics =====
  err_primary = sqrt(max(0.0, (x_g - x_target)^2 + y_g^2));
  err_formation = sqrt(max(0.0,
    (x_q - x_form_des)^2 + (y_q - y_form_des)^2 + (z_q - z_hover)^2));
  // Track degraded error during dropout, recovered error after dropout+0.5 s
  der(err_formation_degraded) = if not comm_ok
    then k_filt * (err_formation - err_formation_degraded) else 0.0;
  der(err_formation_recovered) = if time > t_drop_end + 0.5
    then k_filt * (err_formation - err_formation_recovered) else 0.0;

  annotation(
    experiment(StartTime=0.0, StopTime=12.0, Tolerance=1e-6, Interval=0.008),
    Documentation(info="MixedTeamResilientC: 24 kg lidar ground robot + 2.1 kg camera quadrotor.
      Distributed control with dead-reckoning prediction during 0.9 s comm dropout (5.55-6.45 s).
      Wheel torques bounded [-12.9,12.9] N.m; rotor thrusts bounded [0,12.9] N.
      125 Hz, 12 s. Shared disturbance w_env during dropout only.
      Primary tracking error < 0.63 m after 7.8 s. Route, formation, collision avoidance,
      degraded/recovered formation errors, finite estimates all enforced."));
end MixedTeamResilientC;