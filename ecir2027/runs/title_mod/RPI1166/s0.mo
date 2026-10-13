model MixedTeamHandoffB
  "Multi-robot inspection handoff: ground robot (24 kg, lidar) and quadrotor (2.1 kg, camera)"
  // Requirement: divide inspection, exchange timestamped result, replan quadrotor
  // using received data. 0.07 s comm delay during middle third. 100 Hz, 10 s.

  // ===== Physical parameters =====
  parameter Real m_g = 24.0 "Ground robot mass [kg]";
  parameter Real m_q = 2.1 "Quadrotor mass [kg]";
  parameter Real tau_max = 11.5 "Max wheel torque magnitude [N.m]";
  parameter Real thrust_max = 11.5 "Max rotor thrust [N]";
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";
  // Design parameters (physical dimensions not specified in requirement)
  parameter Real r_w = 0.1 "Effective wheel radius [m]";
  parameter Real L_wh = 0.3 "Half wheelbase [m]";
  parameter Real I_g = 0.6 "Ground robot yaw inertia [kg.m2]";
  parameter Real arm_q = 1.0 "Quadrotor effective arm length [m]";

  // ===== Mission parameters =====
  parameter Real x_wp1 = 4.0 "Inspection waypoint 1 x [m]";
  parameter Real y_wp1 = 0.0 "Inspection waypoint 1 y [m]";
  parameter Real feature_off_y = 0.5 "Feature offset from wp1 in y [m]";
  parameter Real x_wp2 = 4.0 "Pre-planned follow-up waypoint x [m]";
  parameter Real y_wp2 = 0.5 "Pre-planned follow-up waypoint y [m]";
  parameter Real z_hover = 2.0 "Quadrotor operating height [m]";
  parameter Real delay_dist = 0.07 "Communication delay disturbance [s]";
  parameter Real t_mid_start = 10.0 / 3.0 "Middle third start time [s]";
  parameter Real t_mid_end = 20.0 / 3.0 "Middle third end time [s]";
  parameter Real min_sep = 0.5 "Minimum safe separation [m]";
  parameter Real inspect_radius = 0.3 "Inspection completion radius [m]";
  parameter Real x_wall = 6.0 "World-frame wall x [m]";
  parameter Real y_wall = 5.0 "World-frame wall y [m]";
  parameter Real sample_T = 0.01 "Sampling period for 100 Hz [s]";

  // ===== Controller gains =====
  parameter Real kp_v = 8.0 "Ground velocity P gain";
  parameter Real v_max = 2.0 "Ground max cruise speed [m/s]";
  parameter Real kp_pos = 3.0 "Ground position-to-velocity gain";
  parameter Real kp_w = 3.0 "Ground yaw P gain";
  parameter Real kd_w = 2.0 "Ground yaw D gain";
  parameter Real kp_qz = 5.0 "Quad z P gain";
  parameter Real kd_qz = 3.0 "Quad z D gain";
  parameter Real kp_qxy = 1.5 "Quad xy P gain";
  parameter Real kd_qxy = 2.0 "Quad xy D gain";

  // ===== Ground robot states =====
  Real x_g(start = 0.0) "Ground robot x position [m]";
  Real y_g(start = 0.0) "Ground robot y position [m]";
  Real theta_g(start = 0.0) "Ground robot heading [rad]";
  Real v_g(start = 0.0) "Ground robot forward speed [m/s]";
  Real omega_g(start = 0.0) "Ground robot yaw rate [rad/s]";

  // ===== Ground robot actuators =====
  Real tau_L_cmd "Left wheel torque command [N.m]";
  Real tau_R_cmd "Right wheel torque command [N.m]";
  Real tau_L "Left wheel actual torque [N.m]";
  Real tau_R "Right wheel actual torque [N.m]";

  // ===== Quadrotor states =====
  Real x_q(start = 0.0) "Quadrotor x [m]";
  Real y_q(start = 0.0) "Quadrotor y [m]";
  Real z_q(start = 2.0) "Quadrotor z [m]";
  Real vx_q(start = 0.0) "Quadrotor vx [m/s]";
  Real vy_q(start = 0.0) "Quadrotor vy [m/s]";
  Real vz_q(start = 0.0) "Quadrotor vz [m/s]";

  // ===== Quadrotor actuators =====
  Real T1_cmd "Rotor 1 thrust command [N]";
  Real T2_cmd "Rotor 2 thrust command [N]";
  Real T3_cmd "Rotor 3 thrust command [N]";
  Real T4_cmd "Rotor 4 thrust command [N]";
  Real T1 "Rotor 1 actual thrust [N]";
  Real T2 "Rotor 2 actual thrust [N]";
  Real T3 "Rotor 3 actual thrust [N]";
  Real T4 "Rotor 4 actual thrust [N]";

  // ===== Handoff state machine =====
  Integer handoff_phase(start = 0)
    "0=ground_moving, 1=inspecting, 2=handoff, 3=quad_moving, 4=complete";
  Real phase_timer(start = 0.0) "Timer for current phase [s]";
  Boolean handoff_success(start = false) "Handoff completed flag";
  Boolean task_complete(start = false) "Mission complete flag";

  // ===== Communication (timestamped pose and map exchange) =====
  Real comm_delay_val "Current communication delay [s]";
  Boolean comm_send "Communication send active";
  Boolean comm_recv "Communication receive active";
  Real send_x_g "Sent ground x [m]";
  Real send_y_g "Sent ground y [m]";
  Real send_theta_g "Sent ground heading [rad]";
  Real send_stamp "Sent timestamp [s]";
  Real send_result_x "Sent result x [m]";
  Real send_result_y "Sent result y [m]";
  Real send_result_stamp "Sent result timestamp [s]";
  Real recv_x_g "Received ground x [m]";
  Real recv_y_g "Received ground y [m]";
  Real recv_theta_g "Received ground heading [rad]";
  Real recv_stamp "Received timestamp [s]";
  Real recv_result_x "Received result x [m]";
  Real recv_result_y "Received result y [m]";
  Real recv_result_stamp "Received result timestamp [s]";
  Real data_age "Age of received data [s]";

  // ===== Replanning =====
  Real plan_x "Replanned target x from received data [m]";
  Real plan_y "Replanned target y from received data [m]";

  // ===== Tracking and separation =====
  Real dist_g_wp1 "Ground to wp1 distance [m]";
  Real dist_q_target "Quad to replanned target 3D distance [m]";
  Real track_error_primary "Primary tracking error [m]";
  Real sep "Inter-robot 3D separation [m]";
  Real sep_x, sep_y, sep_z;

  // ===== Sensors =====
  Real lidar_range "Ground lidar range to feature [m]";
  Real lidar_wall "Ground lidar range to wall [m]";
  Real camera_detect "Quad camera detection [0 or 1]";

  // ===== Intermediate variables =====
  Real dx_g, dy_g, dist_to_target_g, angle_to_target_g, angle_err_g;
  Real desired_v_g, M_yaw;
  Real dx_q, dy_q, dz_q;
  Real desired_vx_q, desired_vy_q, desired_vz_q;
  Real T_total, F_x_q, F_y_q;
  Real hover_thrust;
  Real dz_alloc, dx_alloc, dy_alloc;

equation
  // ===== Ground robot dynamics (differential drive) =====
  der(x_g) = v_g * cos(theta_g);
  der(y_g) = v_g * sin(theta_g);
  der(theta_g) = omega_g;
  der(v_g) = (tau_L + tau_R) / (r_w * m_g);
  der(omega_g) = (tau_R - tau_L) * L_wh / (r_w * I_g);

  // Torque saturation: independently bounded at +/- tau_max
  tau_L = if tau_L_cmd > tau_max then tau_max else if tau_L_cmd < -tau_max then -tau_max else tau_L_cmd;
  tau_R = if tau_R_cmd > tau_max then tau_max else if tau_R_cmd < -tau_max then -tau_max else tau_R_cmd;

  // ===== Ground robot local motion control =====
  dx_g = x_wp1 - x_g;
  dy_g = y_wp1 - y_g;
  dist_to_target_g = sqrt(dx_g * dx_g + dy_g * dy_g + 1e-9);
  angle_to_target_g = atan2(dy_g, dx_g);
  angle_err_g = atan2(sin(angle_to_target_g - theta_g), cos(angle_to_target_g - theta_g));

  // Velocity profile: stop if heading error large, else proportional to distance with cap
  desired_v_g = if handoff_phase == 0 then
    (if abs(angle_err_g) > 0.5 then 0.0 else
     (if kp_pos * dist_to_target_g > v_max then v_max else kp_pos * dist_to_target_g))
    else 0.0;

  // Yaw PD controller
  M_yaw = kp_w * angle_err_g - kd_w * omega_g;

  // Torque allocation: sum drives forward, difference drives yaw
  tau_R_cmd = 0.5 * (r_w * m_g * kp_v * (desired_v_g - v_g) + r_w * M_yaw / L_wh);
  tau_L_cmd = 0.5 * (r_w * m_g * kp_v * (desired_v_g - v_g) - r_w * M_yaw / L_wh);

  // ===== Quadrotor dynamics =====
  T_total = T1 + T2 + T3 + T4;
  der(x_q) = vx_q;
  der(y_q) = vy_q;
  der(z_q) = vz_q;
  der(vz_q) = (T_total - m_q * g) / m_q;
  F_x_q = (T1 + T2 - T3 - T4) * arm_q;
  F_y_q = (T1 - T2 - T3 + T4) * arm_q;
  der(vx_q) = F_x_q / m_q;
  der(vy_q) = F_y_q / m_q;

  // Thrust saturation: independently bounded [0, thrust_max]
  T1 = if T1_cmd > thrust_max then thrust_max else if T1_cmd < 0.0 then 0.0 else T1_cmd;
  T2 = if T2_cmd > thrust_max then thrust_max else if T2_cmd < 0.0 then 0.0 else T2_cmd;
  T3 = if T3_cmd > thrust_max then thrust_max else if T3_cmd < 0.0 then 0.0 else T3_cmd;
  T4 = if T4_cmd > thrust_max then thrust_max else if T4_cmd < 0.0 then 0.0 else T4_cmd;

  // ===== Quadrotor local motion control with replanning =====
  // Before handoff: hold position at origin. After handoff: track received target.
  plan_x = if handoff_phase >= 3 then recv_result_x else 0.0;
  plan_y = if handoff_phase >= 3 then recv_result_y else 0.0;

  dx_q = if handoff_phase >= 3 then plan_x - x_q else 0.0;
  dy_q = if handoff_phase >= 3 then plan_y - y_q else 0.0;
  dz_q = z_hover - z_q;

  desired_vx_q = kp_qxy * dx_q - kd_qxy * vx_q;
  desired_vy_q = kp_qxy * dy_q - kd_qxy * vy_q;
  desired_vz_q = kp_qz * dz_q - kd_qz * vz_q;

  hover_thrust = m_q * g / 4.0;

  // Thrust mixing matrix: hover + vertical + lateral corrections
  dz_alloc = m_q * desired_vz_q / 4.0;
  dx_alloc = m_q * desired_vx_q / (4.0 * arm_q);
  dy_alloc = m_q * desired_vy_q / (4.0 * arm_q);

  T1_cmd = hover_thrust + dz_alloc + dx_alloc + dy_alloc;
  T2_cmd = hover_thrust + dz_alloc + dx_alloc - dy_alloc;
  T3_cmd = hover_thrust + dz_alloc - dx_alloc - dy_alloc;
  T4_cmd = hover_thrust + dz_alloc - dx_alloc + dy_alloc;

  // ===== Phase timer =====
  der(phase_timer) = 1.0;

  // ===== Handoff state transitions =====
  // Phase 0 -> 1: ground robot reaches wp1
  when handoff_phase == 0 and dist_to_target_g < inspect_radius then
    handoff_phase = 1;
    reinit(phase_timer, 0.0);
  end when;

  // Phase 1 -> 2: inspection complete, initiate handoff
  when handoff_phase == 1 and phase_timer > 1.0 then
    handoff_phase = 2;
    reinit(phase_timer, 0.0);
  end when;

  // Phase 2 -> 3: data received (after comm delay), quadrotor replans
  when handoff_phase == 2 and phase_timer > 0.2 then
    handoff_phase = 3;
    handoff_success = true;
    reinit(phase_timer, 0.0);
  end when;

  // Phase 3 -> 4: quadrotor reaches replanned target
  when handoff_phase == 3 and dist_q_target < inspect_radius then
    handoff_phase = 4;
    task_complete = true;
    reinit(phase_timer, 0.0);
  end when;

  // ===== Communication with timestamped exchange =====
  // Delay injected during middle third of 10 s mission
  comm_delay_val = if time >= t_mid_start and time <= t_mid_end then delay_dist else 0.001;

  comm_send = handoff_phase >= 2;
  comm_recv = handoff_phase >= 2;

  // Ground robot sends timestamped pose and inspection result
  send_x_g = x_g;
  send_y_g = y_g;
  send_theta_g = theta_g;
  send_stamp = time;
  send_result_x = x_wp1;
  send_result_y = y_wp1 + feature_off_y;
  send_result_stamp = if handoff_phase >= 2 then time else 0.0;

  // Quadrotor receives with communication delay
  recv_x_g = delay(send_x_g, comm_delay_val, delay_dist);
  recv_y_g = delay(send_y_g, comm_delay_val, delay_dist);
  recv_theta_g = delay(send_theta_g, comm_delay_val, delay_dist);
  recv_stamp = delay(send_stamp, comm_delay_val, delay_dist);
  recv_result_x = delay(send_result_x, comm_delay_val, delay_dist);
  recv_result_y = delay(send_result_y, comm_delay_val, delay_dist);
  recv_result_stamp = delay(send_result_stamp, comm_delay_val, delay_dist);

  // Data age: bounded by communication delay
  data_age = if comm_recv and recv_result_stamp > 0.001 then time - recv_result_stamp else 0.0;

  // ===== Tracking errors =====
  dist_g_wp1 = sqrt((x_g - x_wp1) * (x_g - x_wp1) + (y_g - y_wp1) * (y_g - y_wp1) + 1e-9);
  dist_q_target = if handoff_phase >= 3 then
    sqrt((x_q - plan_x) * (x_q - plan_x) + (y_q - plan_y) * (y_q - plan_y) + (z_q - z_hover) * (z_q - z_hover) + 1e-9)
    else
    sqrt(x_q * x_q + y_q * y_q + (z_q - z_hover) * (z_q - z_hover) + 1e-9);

  // Primary tracking error: active robot's error
  track_error_primary = if handoff_phase <= 1 then dist_g_wp1
    else if handoff_phase >= 3 then dist_q_target
    else dist_g_wp1;

  // ===== Separation (no collision) =====
  sep_x = x_q - x_g;
  sep_y = y_q - y_g;
  sep_z = z_q;  // ground robot at z=0
  sep = sqrt(sep_x * sep_x + sep_y * sep_y + sep_z * sep_z + 1e-9);

  // ===== Local sensors =====
  // Lidar: ground robot measures range to inspection feature and wall
  lidar_range = dist_to_target_g;
  lidar_wall = sqrt((x_wall - x_g) * (x_wall - x_g) + 1e-9);
  // Camera: quadrotor detects feature when close
  camera_detect = if handoff_phase >= 3 and dist_q_target < 2.0 then 1.0 else 0.0;

end MixedTeamHandoffB;