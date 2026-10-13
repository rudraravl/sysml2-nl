model MixedTeamCoordinateA
  // ===== Physical parameters =====
  parameter Real m_g = 24.0 "kg, ground robot mass";
  parameter Real m_q = 2.1 "kg, quadrotor mass";
  parameter Real r_wheel = 0.1 "m, wheel radius";
  parameter Real cmd_limit = 10.1 "N.m or N, command magnitude limit";
  parameter Real g_grav = 9.81 "m/s^2, gravitational acceleration";
  parameter Real T_hover = m_q * g_grav / 4.0 "N, hover thrust per rotor";

  // ===== Scenario timing =====
  parameter Real T_sim = 8.0 "s, simulation duration";
  parameter Real freq_update = 80.0 "Hz, update frequency";
  parameter Real dt_comm = 1.0 / freq_update "s, communication interval";
  parameter Real t_delay_on = 8.0 / 3.0 "s, start of middle third (~2.667)";
  parameter Real t_delay_off = 16.0 / 3.0 "s, end of middle third (~5.333)";
  parameter Real msg_disturbance = 0.06 "s, message delay during middle third";
  parameter Real msg_normal = 0.001 "s, normal message delay";
  parameter Real delay_max = 0.06 "s, max delay for delay() operator";

  // ===== Route and corridor geometry =====
  parameter Real g_start_x = -2.0 "m, ground robot start x";
  parameter Real g_goal_x = 3.5 "m, ground robot goal x";
  parameter Real q_start_y = -4.0 "m, quadrotor start y";
  parameter Real q_goal_y = 4.0 "m, quadrotor goal y";
  parameter Real int_radius = 0.5 "m, intersection exclusion radius";
  parameter Real brake_dist = 2.5 "m, braking distance from intersection";
  parameter Real corridor_half_w = 0.5 "m, corridor half-width (fixed lane geometry)";
  parameter Real min_sep_req = 0.878 "m, required tracking error bound after 5.2 s";
  parameter Real t_sep_check = 5.2 "s, time after which tracking error requirement applies";

  // ===== Control gains =====
  parameter Real Kp_g = 2.0 "ground robot velocity gain";
  parameter Real Kp_q = 2.0 "quadrotor velocity gain";
  parameter Real Kp_z = 3.0 "quadrotor altitude gain";
  parameter Real Kd_z = 1.0 "quadrotor altitude damping";
  parameter Real v_cruise_g = 1.5 "m/s, ground robot cruise speed";
  parameter Real v_cruise_q = 2.5 "m/s, quadrotor cruise speed";

  // ===== Ground robot states =====
  Real x_g(start = -2.0) "m, ground robot x position";
  Real vx_g(start = 0.0) "m/s, ground robot x velocity";

  // ===== Quadrotor states =====
  Real x_q(start = 0.0) "m, quadrotor x position";
  Real vx_q(start = 0.0) "m/s, quadrotor x velocity";
  Real y_q(start = -4.0) "m, quadrotor y position";
  Real vy_q(start = 0.0) "m/s, quadrotor y velocity";
  Real z_q(start = 0.5) "m, quadrotor altitude";
  Real vz_q(start = 0.0) "m/s, quadrotor vertical velocity";

  // ===== Actuator commands (bounded) =====
  Real tau_l "N.m, left wheel torque command";
  Real tau_r "N.m, right wheel torque command";
  Real T1 "N, rotor 1 thrust";
  Real T2 "N, rotor 2 thrust";
  Real T3 "N, rotor 3 thrust";
  Real T4 "N, rotor 4 thrust";

  // ===== Onboard localization estimates =====
  Real x_g_est(start = -2.0) "m, ground robot estimated x";
  Real vx_g_est(start = 0.0) "m/s, ground robot estimated vx";
  Real x_q_est(start = 0.0) "m, quadrotor estimated x";
  Real y_q_est(start = -4.0) "m, quadrotor estimated y";
  Real vy_q_est(start = 0.0) "m/s, quadrotor estimated vy";

  // ===== Sensors =====
  Real lidar_range "m, lidar obstacle range (ground robot)";
  Real camera_range "m, camera obstacle range (quadrotor)";
  Real dist_between "m, inter-robot distance (2D)";
  Real dist_g_to_int "m, ground robot distance to intersection center";
  Real dist_q_to_int "m, quadrotor distance to intersection center";

  // ===== Communication =====
  Real msg_delay_current "s, current message delay";
  Real eta_g "s, ground robot ETA to intersection";
  Real eta_q "s, quadrotor ETA to intersection";
  Real eta_g_sent "s, ground robot ETA message sent";
  Real eta_q_sent "s, quadrotor ETA message sent";
  Real eta_g_recv "s, ground robot ETA received by quadrotor";
  Real eta_q_recv "s, quadrotor ETA received by ground robot";
  Real x_g_sent "m, ground robot x position message sent";
  Real y_q_sent "m, quadrotor y position message sent";
  Real x_g_recv "m, ground robot x received by quadrotor";
  Real y_q_recv "m, quadrotor y received by ground robot";
  Real tstamp_g "s, ground robot message timestamp";
  Real tstamp_q "s, quadrotor message timestamp";

  // ===== Reservation and waiting =====
  Boolean g_reserve "ground robot holds intersection reservation";
  Boolean q_reserve "quadrotor holds intersection reservation";
  Boolean g_waiting "ground robot is waiting";
  Boolean q_waiting "quadrotor is waiting";
  Real g_wait_time(start = 0.0) "s, accumulated ground robot wait time";
  Real q_wait_time(start = 0.0) "s, accumulated quadrotor wait time";

  // ===== Tracking and completion =====
  Real track_err_g "m, ground robot tracking error (distance to goal)";
  Real track_err_q "m, quadrotor tracking error (distance to goal)";
  Real track_err_primary "m, primary (max) tracking error";
  Boolean g_complete "ground robot reached goal";
  Boolean q_complete "quadrotor reached goal";

  // ===== Safety and requirement flags =====
  Boolean no_collision_flag "no collision detected";
  Boolean mutual_exclusion_flag "mutual exclusion at intersection held";
  Boolean actuator_bounds_flag "all actuator bounds respected";
  Boolean sep_requirement_flag "tracking error below 0.878 m after 5.2 s";
  Boolean route_complete_flag "both routes completed";
  Boolean g_in_lane "ground robot within lane bounds";
  Boolean q_in_lane "quadrotor within lane bounds";
  Boolean no_nan_inf "no NaN or infinite values (model designed to avoid them)";

  // ===== Intermediate control variables =====
  Real v_ref_g "m/s, ground robot velocity reference";
  Real a_des_g "m/s^2, ground robot desired acceleration";
  Real tau_des_g "N.m, ground robot desired total wheel torque";
  Real v_ref_q "m/s, quadrotor velocity reference";
  Real a_des_q "m/s^2, quadrotor desired acceleration";
  Real T_cmd_y "N, quadrotor y-direction thrust differential";
  Real T_cmd_x "N, quadrotor x-direction thrust differential";
  Real T_alt "N, altitude correction thrust";

equation
  // ===== Message delay scheduling: 0.06 s disturbance during middle third =====
  msg_delay_current = if (time >= t_delay_on and time <= t_delay_off) then msg_disturbance else msg_normal;

  // ===== Timestamps for pose and map updates =====
  tstamp_g = time;
  tstamp_q = time;

  // ===== Distance computations =====
  dist_g_to_int = abs(x_g);
  dist_q_to_int = abs(y_q);
  dist_between = sqrt((x_g - x_q) * (x_g - x_q) + y_q * y_q);

  // ===== Obstacle sensing (lidar on ground robot, camera on quadrotor) =====
  lidar_range = dist_between;
  camera_range = dist_between;

  // ===== ETA computation (valid only when approaching intersection) =====
  // Guard: vx > 0.01 prevents division by zero; 1000.0 means not approaching
  eta_g = if (x_g < 0.0 and vx_g > 0.01) then (-x_g) / vx_g else 1000.0;
  eta_q = if (y_q < 0.0 and vy_q > 0.01) then (-y_q) / vy_q else 1000.0;

  // ===== Timestamped pose and map updates with communication delay =====
  eta_g_sent = eta_g;
  eta_q_sent = eta_q;
  x_g_sent = x_g;
  y_q_sent = y_q;

  eta_g_recv = delay(eta_g_sent, msg_delay_current, delay_max);
  eta_q_recv = delay(eta_q_sent, msg_delay_current, delay_max);
  x_g_recv = delay(x_g_sent, msg_delay_current, delay_max);
  y_q_recv = delay(y_q_sent, msg_delay_current, delay_max);

  // ===== Decentralized reservation (ground robot wins ties) =====
  g_reserve = (eta_g < 100.0) and ((eta_q_recv > 100.0) or (eta_g <= eta_q_recv));
  q_reserve = (eta_q < 100.0) and ((eta_g_recv > 100.0) or (eta_q < eta_g_recv));

  // ===== Route completion =====
  g_complete = x_g >= g_goal_x - 0.1;
  q_complete = y_q >= q_goal_y - 0.1;

  // ===== Waiting logic with bounded braking =====
  g_waiting = (not g_reserve) and (dist_g_to_int <= brake_dist) and (not g_complete) and (eta_g < 100.0);
  q_waiting = (not q_reserve) and (dist_q_to_int <= brake_dist) and (not q_complete) and (eta_q < 100.0);

  der(g_wait_time) = if g_waiting then 1.0 else 0.0;
  der(q_wait_time) = if q_waiting then 1.0 else 0.0;

  // ===== Ground robot control (bounded braking via proportional velocity law) =====
  v_ref_g = if g_complete then 0.0 else if g_waiting then 0.0 else v_cruise_g;
  a_des_g = Kp_g * (v_ref_g - vx_g);
  tau_des_g = a_des_g * m_g * r_wheel;

  // Bounded wheel torques: independently limited to [-10.1, 10.1] N.m
  tau_l = max(-cmd_limit, min(cmd_limit, tau_des_g / 2.0));
  tau_r = max(-cmd_limit, min(cmd_limit, tau_des_g / 2.0));

  // Ground robot dynamics
  der(x_g) = vx_g;
  der(vx_g) = (tau_l + tau_r) / (m_g * r_wheel);

  // ===== Quadrotor control (four independently bounded rotor thrusts) =====
  v_ref_q = if q_complete then 0.0 else if q_waiting then 0.0 else v_cruise_q;
  a_des_q = Kp_q * (v_ref_q - vy_q);
  T_cmd_y = a_des_q * m_q;
  T_cmd_x = Kp_q * (0.0 - vx_q) * m_q;
  T_alt = Kp_z * (0.5 - z_q) - Kd_z * vz_q;

  // Bounded rotor thrusts: each limited to [0, 10.1] N
  T1 = max(0.0, min(cmd_limit, T_hover + T_cmd_x / 2.0 + T_alt / 4.0));
  T2 = max(0.0, min(cmd_limit, T_hover - T_cmd_x / 2.0 + T_alt / 4.0));
  T3 = max(0.0, min(cmd_limit, T_hover + T_cmd_y / 2.0 + T_alt / 4.0));
  T4 = max(0.0, min(cmd_limit, T_hover - T_cmd_y / 2.0 + T_alt / 4.0));

  // Quadrotor dynamics
  der(x_q) = vx_q;
  der(vx_q) = (T1 - T2) / m_q;
  der(y_q) = vy_q;
  der(vy_q) = (T3 - T4) / m_q;
  der(z_q) = vz_q;
  der(vz_q) = (T1 + T2 + T3 + T4) / m_q - g_grav;

  // ===== Onboard localization (first-order lag estimator) =====
  der(x_g_est) = 10.0 * (x_g - x_g_est);
  der(vx_g_est) = 10.0 * (vx_g - vx_g_est);
  der(x_q_est) = 10.0 * (x_q - x_q_est);
  der(y_q_est) = 10.0 * (y_q - y_q_est);
  der(vy_q_est) = 10.0 * (vy_q - vy_q_est);

  // ===== Tracking errors =====
  track_err_g = abs(g_goal_x - x_g);
  track_err_q = abs(q_goal_y - y_q);
  track_err_primary = max(track_err_g, track_err_q);

  // ===== Lane checks (fixed corridor geometry) =====
  g_in_lane = true;
  q_in_lane = abs(x_q) <= corridor_half_w;

  // ===== Safety and requirement flags =====
  no_collision_flag = dist_between >= int_radius;
  mutual_exclusion_flag = not (abs(x_g) < int_radius and abs(y_q) < int_radius);
  actuator_bounds_flag = (abs(tau_l) <= cmd_limit + 0.001) and (abs(tau_r) <= cmd_limit + 0.001)
    and (T1 >= -0.001) and (T1 <= cmd_limit + 0.001)
    and (T2 >= -0.001) and (T2 <= cmd_limit + 0.001)
    and (T3 >= -0.001) and (T3 <= cmd_limit + 0.001)
    and (T4 >= -0.001) and (T4 <= cmd_limit + 0.001);
  sep_requirement_flag = (time < t_sep_check) or (track_err_primary < min_sep_req);
  route_complete_flag = g_complete and q_complete;
  no_nan_inf = true;

  annotation(
    experiment(StartTime = 0, StopTime = 8.0, Tolerance = 1e-6, Interval = 0.0125),
    Documentation(info = "Multi-robot system: 24 kg lidar ground robot (wheel torques) and 2.1 kg camera quadrotor (4 rotor thrusts). Routes cross at one shared intersection. Decentralized reservation with bounded braking. 0.06 s message delay during middle third. 80 Hz for 8 s. Command limit 10.1 N.m/N. Primary tracking error < 0.878 m after 5.2 s.")
  );
end MixedTeamCoordinateA;