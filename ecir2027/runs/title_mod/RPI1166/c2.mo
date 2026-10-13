model MixedTeamHandoffB
  "Multi-robot inspection handoff: ground robot (24 kg, lidar) and quadrotor (2.1 kg, camera)"

  // Physical parameters
  parameter Real m_g = 24.0 "Ground robot mass [kg]";
  parameter Real m_q = 2.1 "Quadrotor mass [kg]";
  parameter Real tau_max = 11.5 "Max wheel torque magnitude [N.m]";
  parameter Real thrust_max = 11.5 "Max rotor thrust [N]";
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real r_w = 0.1 "Effective wheel radius [m]";
  parameter Real L_wh = 0.3 "Half wheelbase [m]";
  parameter Real I_g = 0.6 "Ground robot yaw inertia [kg.m2]";
  parameter Real arm_q = 1.0 "Quadrotor effective arm length [m]";

  // Mission parameters
  parameter Real x_wp1 = 4.0 "Inspection waypoint 1 x [m]";
  parameter Real y_wp1 = 0.0 "Inspection waypoint 1 y [m]";
  parameter Real feature_off_y = 0.5 "Feature offset from wp1 in y [m]";
  parameter Real z_hover = 2.0 "Quadrotor operating height [m]";
  parameter Real delay_dist = 0.07 "Disturbed communication delay [s]";
  parameter Real delay_normal = 0.001 "Normal communication delay [s]";
  parameter Real t_mid_start = 10.0 / 3.0 "Middle third start time [s]";
  parameter Real t_mid_end = 20.0 / 3.0 "Middle third end time [s]";
  parameter Real min_sep = 0.5 "Minimum safe separation [m]";
  parameter Real inspect_radius = 0.3 "Inspection completion radius [m]";
  parameter Real x_wall = 6.0 "World-frame wall x [m]";

  // Controller gains
  parameter Real kp_v = 8.0 "Ground velocity P gain";
  parameter Real v_max = 2.0 "Ground max cruise speed [m/s]";
  parameter Real kp_pos = 3.0 "Ground position-to-velocity gain";
  parameter Real kp_w = 3.0 "Ground yaw P gain";
  parameter Real kd_w = 2.0 "Ground yaw D gain";
  parameter Real kp_qz = 5.0 "Quad z P gain";
  parameter Real kd_qz = 3.0 "Quad z D gain";
  parameter Real kp_qxy = 2.5 "Quad xy P gain";
  parameter Real kd_qxy = 3.0 "Quad xy D gain";

  // Ground robot states
  Real x_g(start = 0.0) "Ground robot x position [m]";
  Real y_g(start = 0.0) "Ground robot y position [m]";
  Real theta_g(start = 0.0) "Ground robot heading [rad]";
  Real v_g(start = 0.0) "Ground robot forward speed [m/s]";
  Real omega_g(start = 0.0) "Ground robot yaw rate [rad/s]";

  // Ground robot actuators
  Real tau_L_cmd "Left wheel torque command [N.m]";
  Real tau_R_cmd "Right wheel torque command [N.m]";
  Real tau_L "Left wheel actual torque [N.m]";
  Real tau_R "Right wheel actual torque [N.m]";

  // Quadrotor states
  Real x_q(start = 0.0) "Quadrotor x [m]";
  Real y_q(start = 0.0) "Quadrotor y [m]";
  Real z_q(start = 2.0) "Quadrotor z [m]";
  Real vx_q(start = 0.0) "Quadrotor vx [m/s]";
  Real vy_q(start = 0.0) "Quadrotor vy [m/s]";
  Real vz_q(start = 0.0) "Quadrotor vz [m/s]";

  // Quadrotor actuators
  Real T1_cmd "Rotor 1 thrust command [N]";
  Real T2_cmd "Rotor 2 thrust command [N]";
  Real T3_cmd "Rotor 3 thrust command [N]";
  Real T4_cmd "Rotor 4 thrust command [N]";
  Real T1 "Rotor 1 actual thrust [N]";
  Real T2 "Rotor 2 actual thrust [N]";
  Real T3 "Rotor 3 actual thrust [N]";
  Real T4 "Rotor 4 actual thrust [N]";

  // Handoff state machine
  Integer handoff_phase(start = 0)
    "0=ground_moving, 1=inspecting, 2=handoff, 3=quad_moving, 4=complete";
  Real phase_timer(start = 0.0) "Timer for current phase [s]";
  Boolean handoff_success(start = false) "Handoff completed flag";
  Boolean task_complete(start = false) "Mission complete flag";

  // Communication
  Real comm_delay_val "Current communication delay [s]";
  Boolean comm_send "Communication send active";
  Boolean comm_recv "Communication receive active";

  // Communication lag states (first-order lag approximating delay)
  Real lag_x_g(start = 0.0) "Lagged ground x [m]";
  Real lag_y_g(start = 0.0) "Lagged ground y [m]";
  Real lag_theta_g(start = 0.0) "Lagged ground heading [rad]";
  Real lag_result_x(start = 4.0) "Lagged result x [m]";
  Real lag_result_y(start = 0.5) "Lagged result y [m]";

  // Received signals
  Real recv_x_g "Received ground x [m]";
  Real recv_y_g "Received ground y [m]";
  Real recv_theta_g "Received ground heading [rad]";
  Real recv_result_x "Received result x [m]";
  Real recv_result_y "Received result y [m]";
  Real data_age "Age of received data [s]";

  // Replanning
  Real plan_x "Replanned target x from received data [m]";
  Real plan_y "Replanned target y from received data [m]";

  // Tracking and separation
  Real dist_g_wp1 "Ground to wp1 distance [m]";
  Real dist_q_target "Quad to replanned target 3D distance [m]";
  Real track_error_primary "Primary tracking error [m]";
  Real sep "Inter-robot 3D separation [m]";
  Real sep_x "Separation x [m]";
  Real sep_y "Separation y [m]";
  Real sep_z "Separation z [m]";

  // Sensors
  Real lidar_range "Ground lidar range to feature [m]";
  Real lidar_wall "Ground lidar range to wall [m]";
  Real camera_detect "Quad camera detection [0 or 1]";

  // Intermediate variables
  Real dx_g "Ground dx to target [m]";
  Real dy_g "Ground dy to target [m]";
  Real dist_to_target_g "Ground distance to target [m]";
  Real angle_to_target_g "Ground angle to target [rad]";
  Real angle_err_g "Ground heading error [rad]";
  Real desired_v_g "Ground desired speed [m/s]";
  Real M_yaw "Ground yaw torque [N.m]";
  Real dx_q "Quad dx to target [m]";
  Real dy_q "Quad dy to target [m]";
  Real dz_q "Quad dz to target [m]";
  Real desired_vx_q "Quad desired vx [m/s]";
  Real desired_vy_q "Quad desired vy [m/s]";
  Real desired_vz_q "Quad desired vz [m/s]";
  Real T_total "Quad total thrust [N]";
  Real F_x_q "Quad x force [N]";
  Real F_y_q "Quad y force [N]";
  Real hover_thrust "Quad hover thrust per rotor [N]";
  Real dz_alloc "Quad z thrust allocation [N]";
  Real dx_alloc "Quad x thrust allocation [N]";
  Real dy_alloc "Quad y thrust allocation [N]";
  Boolean in_middle_third "True during middle third of mission";

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

  desired_v_g = if handoff_phase == 0 then
    (if abs(angle_err_g) > 0.5 then 0.0 else
     (if kp_pos * dist_to_target_g > v_max then v_max else kp_pos * dist_to_target_g))
    else 0.0;

  M_yaw = kp_w * angle_err_g - kd_w * omega_g;

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
  plan_x = if handoff_phase >= 3 then recv_result_x else x_wp1;
  plan_y = if handoff_phase >= 3 then recv_result_y else y_wp1 + feature_off_y;

  dx_q = if handoff_phase >= 3 then plan_x - x_q else 0.0;
  dy_q = if handoff_phase >= 3 then plan_y - y_q else 0.0;
  dz_q = z_hover - z_q;

  desired_vx_q = kp_qxy * dx_q - kd_qxy * vx_q;
  desired_vy_q = kp_qxy * dy_q - kd_qxy * vy_q;
  desired_vz_q = kp_qz * dz_q - kd_qz * vz_q;

  hover_thrust = m_q * g / 4.0;

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
  when handoff_phase == 0 and dist_to_target_g < inspect_radius then
    handoff_phase = 1;
    reinit(phase_timer, 0.0);
  end when;

  when handoff_phase == 1 and phase_timer > 1.0 then
    handoff_phase = 2;
    reinit(phase_timer, 0.0);
  end when;

  when handoff_phase == 2 and phase_timer > 0.2 then
    handoff_phase = 3;
    handoff_success = true;
    reinit(phase_timer, 0.0);
  end when;

  when handoff_phase == 3 and dist_q_target < inspect_radius then
    handoff_phase = 4;
    task_complete = true;
    reinit(phase_timer, 0.0);
  end when;

  // ===== Communication with timestamped exchange =====
  in_middle_third = time >= t_mid_start and time <= t_mid_end;
  comm_delay_val = if in_middle_third then delay_dist else delay_normal;

  comm_send = handoff_phase >= 2;
  comm_recv = handoff_phase >= 2;

  // First-order lag dynamics approximating communication delay
  der(lag_x_g) = (x_g - lag_x_g) / comm_delay_val;
  der(lag_y_g) = (y_g - lag_y_g) / comm_delay_val;
  der(lag_theta_g) = (theta_g - lag_theta_g) / comm_delay_val;
  der(lag_result_x) = (x_wp1 - lag_result_x) / comm_delay_val;
  der(lag_result_y) = ((y_wp1 + feature_off_y) - lag_result_y) / comm_delay_val;

  // Received signals from lagged buffers
  recv_x_g = lag_x_g;
  recv_y_g = lag_y_g;
  recv_theta_g = lag_theta_g;
  recv_result_x = lag_result_x;
  recv_result_y = lag_result_y;

  // Data age bounded by current communication delay
  data_age = if comm_recv then comm_delay_val else 0.0;

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
  sep_z = z_q;
  sep = sqrt(sep_x * sep_x + sep_y * sep_y + sep_z * sep_z + 1e-9);

  // ===== Local sensors =====
  lidar_range = dist_to_target_g;
  lidar_wall = sqrt((x_wall - x_g) * (x_wall - x_g) + 1e-9);
  camera_detect = if handoff_phase >= 3 and dist_q_target < 2.0 then 1.0 else 0.0;

end MixedTeamHandoffB;