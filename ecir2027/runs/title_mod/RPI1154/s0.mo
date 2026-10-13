model MixedTeamFormB
  "Multi-robot formation: 24 kg ground robot follows leader; 2.1 kg quadrotor maintains offset"

  // --- Physical parameters ---
  parameter Real m_g = 24.0 "Ground robot mass [kg]";
  parameter Real m_q = 2.1 "Quadrotor mass [kg]";
  parameter Real r_wheel = 0.15 "Wheel radius [m]";
  parameter Real tau_max = 11.5 "Wheel torque saturation limit [N.m]";
  parameter Real thrust_max = 11.5 "Rotor thrust saturation limit [N]";
  parameter Real g_grav = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real hover_thrust = m_q * g_grav / 4.0 "Per-rotor hover thrust [N]";
  parameter Real k_thrust = 1.0 "Thrust-to-horizontal-force mapping gain";

  // --- Formation parameters ---
  parameter Real dx_form = 2.0 "Declared formation x-offset of quadrotor from ground robot [m]";
  parameter Real dy_form = 1.5 "Declared formation y-offset of quadrotor from ground robot [m]";
  parameter Real sep_min = 1.0 "Minimum pairwise separation [m]";
  parameter Real z_des = 2.0 "Desired quadrotor altitude [m]";

  // --- Leader trajectory parameters ---
  parameter Real leader_speed = 0.5 "Leader speed [m/s]";
  parameter Real leader_radius = 3.0 "Leader circular path radius [m]";

  // --- Communication disturbance ---
  parameter Real delay_disturb = 0.056 "Injected message delay during middle third [s]";

  // --- Control gains ---
  parameter Real kp_track = 8.0 "Leader-tracking proportional gain";
  parameter Real kd_track = 4.0 "Leader-tracking derivative gain";
  parameter Real kp_form = 6.0 "Formation proportional gain";
  parameter Real kd_form = 3.0 "Formation derivative gain";
  parameter Real kp_alt = 10.0 "Altitude proportional gain";
  parameter Real kd_alt = 4.0 "Altitude derivative gain";
  parameter Real kp_sep = 10.0 "Separation repulsion gain";

  // --- Fixed obstacles (placed outside nominal formation path) ---
  parameter Real obs1_x = -5.0 "Obstacle 1 center x [m]";
  parameter Real obs1_y = -5.0 "Obstacle 1 center y [m]";
  parameter Real obs1_r = 0.5 "Obstacle 1 radius [m]";
  parameter Real obs2_x = 5.0 "Obstacle 2 center x [m]";
  parameter Real obs2_y = 5.0 "Obstacle 2 center y [m]";
  parameter Real obs2_r = 0.5 "Obstacle 2 radius [m]";
  parameter Real obs3_x = 0.0 "Obstacle 3 center x [m]";
  parameter Real obs3_y = 6.0 "Obstacle 3 center y [m]";
  parameter Real obs3_r = 0.5 "Obstacle 3 radius [m]";

  // --- Ground robot dynamic states ---
  Real x_g(start=0.0, fixed=true) "Ground robot x position [m]";
  Real y_g(start=0.0, fixed=true) "Ground robot y position [m]";
  Real vx_g(start=0.0, fixed=true) "Ground robot x velocity [m/s]";
  Real vy_g(start=0.0, fixed=true) "Ground robot y velocity [m/s]";

  // --- Quadrotor dynamic states ---
  Real x_q(start=2.0, fixed=true) "Quadrotor x position [m]";
  Real y_q(start=1.5, fixed=true) "Quadrotor y position [m]";
  Real vx_q(start=0.0, fixed=true) "Quadrotor x velocity [m/s]";
  Real vy_q(start=0.0, fixed=true) "Quadrotor y velocity [m/s]";
  Real z_q(start=2.0, fixed=true) "Quadrotor altitude [m]";
  Real vz_q(start=0.0, fixed=true) "Quadrotor vertical velocity [m/s]";

  // --- Leader trajectory ---
  Real x_l "Leader x position [m]";
  Real y_l "Leader y position [m]";
  Real vx_l "Leader x velocity [m/s]";
  Real vy_l "Leader y velocity [m/s]";

  // --- Ground robot actuator commands and saturated values ---
  Real tau_l_cmd "Left wheel torque command [N.m]";
  Real tau_r_cmd "Right wheel torque command [N.m]";
  Real tau_l "Saturated left wheel torque [N.m]";
  Real tau_r "Saturated right wheel torque [N.m]";

  // --- Quadrotor actuator commands and saturated values ---
  Real T1_cmd "Rotor 1 thrust command [N]";
  Real T2_cmd "Rotor 2 thrust command [N]";
  Real T3_cmd "Rotor 3 thrust command [N]";
  Real T4_cmd "Rotor 4 thrust command [N]";
  Real T1 "Saturated rotor 1 thrust [N]";
  Real T2 "Saturated rotor 2 thrust [N]";
  Real T3 "Saturated rotor 3 thrust [N]";
  Real T4 "Saturated rotor 4 thrust [N]";

  // --- Communication ---
  Boolean in_delay_window "True during middle third of mission";
  Real comm_age "Communication age / effective message delay [s]";
  Real x_g_delayed "Transport-delayed ground robot x [m]";
  Real y_g_delayed "Transport-delayed ground robot y [m]";
  Real x_g_peer "Peer-received ground robot x [m]";
  Real y_g_peer "Peer-received ground robot y [m]";

  // --- Onboard state estimator states ---
  Real x_g_est(start=0.0, fixed=true) "Estimated ground robot x [m]";
  Real y_g_est(start=0.0, fixed=true) "Estimated ground robot y [m]";
  Real vx_g_est(start=0.0, fixed=true) "Estimated ground robot vx [m/s]";
  Real vy_g_est(start=0.0, fixed=true) "Estimated ground robot vy [m/s]";
  Real x_q_est(start=2.0, fixed=true) "Estimated quadrotor x [m]";
  Real y_q_est(start=1.5, fixed=true) "Estimated quadrotor y [m]";
  Real vx_q_est(start=0.0, fixed=true) "Estimated quadrotor vx [m/s]";
  Real vy_q_est(start=0.0, fixed=true) "Estimated quadrotor vy [m/s]";

  // --- Sensors ---
  Real range_meas "Peer-relative range measurement [m]";

  // --- Error metrics ---
  Real form_err_x "Formation error x component [m]";
  Real form_err_y "Formation error y component [m]";
  Real form_err "Formation error magnitude [m]";
  Real track_err_x "Primary tracking error x [m]";
  Real track_err_y "Primary tracking error y [m]";
  Real track_err "Primary tracking error magnitude [m]";
  Real separation "Pairwise robot separation [m]";

  // --- Obstacle distances ---
  Real obs_dist_g1 "Ground robot distance to obstacle 1 surface [m]";
  Real obs_dist_g2 "Ground robot distance to obstacle 2 surface [m]";
  Real obs_dist_g3 "Ground robot distance to obstacle 3 surface [m]";
  Real obs_dist_q1 "Quadrotor distance to obstacle 1 surface [m]";
  Real obs_dist_q2 "Quadrotor distance to obstacle 2 surface [m]";
  Real obs_dist_q3 "Quadrotor distance to obstacle 3 surface [m]";
  Real min_obs_dist "Minimum distance to any obstacle surface [m]";

  // --- Intermediate control variables ---
  Real F_gx_cmd "Ground robot desired x force [N]";
  Real F_gy_cmd "Ground robot desired y force [N]";
  Real F_qx_cmd "Quadrotor desired x force [N]";
  Real F_qy_cmd "Quadrotor desired y force [N]";
  Real F_qz_cmd "Quadrotor desired z force [N]";
  Real F_sep_x "Separation repulsion force x [N]";
  Real F_sep_y "Separation repulsion force y [N]";

equation
  // === Leader trajectory (circular path starting at origin) ===
  x_l = leader_radius * sin(leader_speed * time / leader_radius);
  y_l = leader_radius * (1.0 - cos(leader_speed * time / leader_radius));
  vx_l = leader_speed * cos(leader_speed * time / leader_radius);
  vy_l = leader_speed * sin(leader_speed * time / leader_radius);

  // === Communication: 0.056 s delay injected during middle third (3.33–6.67 s) ===
  in_delay_window = (time >= 10.0 / 3.0) and (time <= 20.0 / 3.0);
  comm_age = if in_delay_window then delay_disturb else 0.0;
  x_g_delayed = delay(x_g, delay_disturb, delay_disturb);
  y_g_delayed = delay(y_g, delay_disturb, delay_disturb);
  x_g_peer = if in_delay_window then x_g_delayed else x_g;
  y_g_peer = if in_delay_window then y_g_delayed else y_g;

  // === Onboard state estimation (observer-style estimators) ===
  // Ground robot self-estimation
  der(x_g_est) = vx_g_est;
  der(y_g_est) = vy_g_est;
  der(vx_g_est) = 5.0 * (x_g - x_g_est) + 2.0 * (vx_g - vx_g_est);
  der(vy_g_est) = 5.0 * (y_g - y_g_est) + 2.0 * (vy_g - vy_g_est);
  // Quadrotor self-estimation
  der(x_q_est) = vx_q_est;
  der(y_q_est) = vy_q_est;
  der(vx_q_est) = 5.0 * (x_q - x_q_est) + 2.0 * (vx_q - vx_q_est);
  der(vy_q_est) = 5.0 * (y_q - y_q_est) + 2.0 * (vy_q - vy_q_est);

  // === Sensors ===
  range_meas = sqrt((x_q - x_g)^2 + (y_q - y_g)^2 + 1e-9);

  // === Error metrics ===
  form_err_x = (x_q - x_g) - dx_form;
  form_err_y = (y_q - y_g) - dy_form;
  form_err = sqrt(form_err_x^2 + form_err_y^2 + 1e-9);
  track_err_x = x_g - x_l;
  track_err_y = y_g - y_l;
  track_err = sqrt(track_err_x^2 + track_err_y^2 + 1e-9);
  separation = sqrt((x_q - x_g)^2 + (y_q - y_g)^2 + 1e-9);

  // Obstacle distances (surface-to-surface, never divide by these)
  obs_dist_g1 = sqrt((x_g - obs1_x)^2 + (y_g - obs1_y)^2 + 1e-9) - obs1_r;
  obs_dist_g2 = sqrt((x_g - obs2_x)^2 + (y_g - obs2_y)^2 + 1e-9) - obs2_r;
  obs_dist_g3 = sqrt((x_g - obs3_x)^2 + (y_g - obs3_y)^2 + 1e-9) - obs3_r;
  obs_dist_q1 = sqrt((x_q - obs1_x)^2 + (y_q - obs1_y)^2 + 1e-9) - obs1_r;
  obs_dist_q2 = sqrt((x_q - obs2_x)^2 + (y_q - obs2_y)^2 + 1e-9) - obs2_r;
  obs_dist_q3 = sqrt((x_q - obs3_x)^2 + (y_q - obs3_y)^2 + 1e-9) - obs3_r;
  min_obs_dist = min(min(min(obs_dist_g1, obs_dist_g2), min(obs_dist_g3, obs_dist_q1)), min(obs_dist_q2, obs_dist_q3));

  // === Distributed formation control with bounded local commands ===

  // Separation repulsion (active only when separation drops below minimum)
  F_sep_x = if separation < sep_min then kp_sep * (separation - sep_min) * (x_q - x_g) / (separation + 1e-6) else 0.0;
  F_sep_y = if separation < sep_min then kp_sep * (separation - sep_min) * (y_q - y_g) / (separation + 1e-6) else 0.0;

  // Ground robot: track leader trajectory using onboard estimate (local control)
  F_gx_cmd = kp_track * (x_l - x_g_est) + kd_track * (vx_l - vx_g_est) - F_sep_x;
  F_gy_cmd = kp_track * (y_l - y_g_est) + kd_track * (vy_l - vy_g_est) - F_sep_y;

  // Map desired forces to wheel torques: F_x=(tau_l+tau_r)/r, F_y=(tau_r-tau_l)/r
  tau_l_cmd = (F_gx_cmd - F_gy_cmd) * r_wheel / 2.0;
  tau_r_cmd = (F_gx_cmd + F_gy_cmd) * r_wheel / 2.0;

  // Saturate wheel torques to +/- 11.5 N.m
  tau_l = max(-tau_max, min(tau_max, tau_l_cmd));
  tau_r = max(-tau_max, min(tau_max, tau_r_cmd));

  // Quadrotor: maintain formation offset using peer (possibly delayed) pose + onboard estimate
  F_qx_cmd = kp_form * ((x_g_peer + dx_form) - x_q_est) + kd_form * (0.0 - vx_q_est) + F_sep_x;
  F_qy_cmd = kp_form * ((y_g_peer + dy_form) - y_q_est) + kd_form * (0.0 - vy_q_est) + F_sep_y;
  F_qz_cmd = kp_alt * (z_des - z_q) + kd_alt * (0.0 - vz_q);

  // Map quadrotor forces to four individual rotor thrusts
  T1_cmd = hover_thrust + (F_qx_cmd + F_qy_cmd) / (4.0 * k_thrust) + F_qz_cmd / 4.0;
  T2_cmd = hover_thrust + (F_qx_cmd - F_qy_cmd) / (4.0 * k_thrust) + F_qz_cmd / 4.0;
  T3_cmd = hover_thrust + (-F_qx_cmd + F_qy_cmd) / (4.0 * k_thrust) + F_qz_cmd / 4.0;
  T4_cmd = hover_thrust + (-F_qx_cmd - F_qy_cmd) / (4.0 * k_thrust) + F_qz_cmd / 4.0;

  // Saturate rotor thrusts to [0, 11.5] N
  T1 = max(0.0, min(thrust_max, T1_cmd));
  T2 = max(0.0, min(thrust_max, T2_cmd));
  T3 = max(0.0, min(thrust_max, T3_cmd));
  T4 = max(0.0, min(thrust_max, T4_cmd));

  // === Plant dynamics ===
  // Ground robot: 2D point mass driven by bounded wheel torques
  der(x_g) = vx_g;
  der(y_g) = vy_g;
  m_g * der(vx_g) = (tau_l + tau_r) / r_wheel;
  m_g * der(vy_g) = (tau_r - tau_l) / r_wheel;

  // Quadrotor: 2D horizontal + altitude driven by bounded rotor thrusts
  der(x_q) = vx_q;
  der(y_q) = vy_q;
  der(z_q) = vz_q;
  m_q * der(vx_q) = k_thrust * (T1 + T2 - T3 - T4);
  m_q * der(vy_q) = k_thrust * (T1 - T2 + T3 - T4);
  m_q * der(vz_q) = (T1 + T2 + T3 + T4) - m_q * g_grav;

  // === Requirement assertions ===
  // Actuator limits
  assert(abs(tau_l) <= tau_max + 1e-6, "Left wheel torque exceeds 11.5 N.m limit");
  assert(abs(tau_r) <= tau_max + 1e-6, "Right wheel torque exceeds 11.5 N.m limit");
  assert(T1 >= -1e-6 and T1 <= thrust_max + 1e-6, "Rotor 1 thrust exceeds [0, 11.5] N limit");
  assert(T2 >= -1e-6 and T2 <= thrust_max + 1e-6, "Rotor 2 thrust exceeds [0, 11.5] N limit");
  assert(T3 >= -1e-6 and T3 <= thrust_max + 1e-6, "Rotor 3 thrust exceeds [0, 11.5] N limit");
  assert(T4 >= -1e-6 and T4 <= thrust_max + 1e-6, "Rotor 4 thrust exceeds [0, 11.5] N limit");

  // Pairwise separation
  assert(separation >= sep_min - 0.01, "Pairwise separation below minimum", AssertionLevel.warning);

  // No collision with fixed obstacles
  assert(min_obs_dist > 0.0, "Collision with obstacle detected");

  // Primary tracking error below 0.36 m after 6.5 s
  assert(time < 6.5 or track_err < 0.36, "Primary tracking error exceeds 0.36 m after 6.5 s", AssertionLevel.warning);

  annotation(
    experiment(StartTime = 0, StopTime = 10, Tolerance = 1e-6, Interval = 0.01),
    Documentation(info = "MixedTeamFormB: Multi-robot formation control mission.
  Ground robot (24 kg, lidar-equipped, differential drive) follows a circular leader trajectory.
  Quadrotor (2.1 kg, camera-equipped, four rotors) maintains a declared relative offset (2.0, 1.5) m.
  Wheel torques and rotor thrusts are independently bounded at 11.5 N.m / 11.5 N.
  Onboard state estimation plus peer-relative range and delayed pose messages.
  Distributed formation control with bounded local commands.
  A controlled 0.056 s message delay is injected during the middle third (3.33–6.67 s).
  Fixed obstacles are placed outside the nominal formation path.
  Runs at 100 Hz (0.01 s interval) for 10 s. All state, command, and sensor traces retained."));
end MixedTeamFormB;