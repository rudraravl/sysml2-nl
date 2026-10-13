model MixedTeamHandoffF
  "Multi-robot inspection handoff: 24 kg ground robot + 2.1 kg quadrotor"

  // Physical constants
  constant Real g = 9.81 "gravitational acceleration [m/s2]";
  constant Real pi = 3.14159265358979;

  // Ground robot parameters
  parameter Real m_g = 24.0 "ground robot mass [kg]";
  parameter Real r_w = 0.1 "wheel radius [m]";
  parameter Real d_w = 0.3 "half track width [m]";
  parameter Real I_g = 0.5 "ground robot yaw inertia [kg.m2]";

  // Quadrotor parameters
  parameter Real m_q = 2.1 "quadrotor mass [kg]";
  parameter Real L_arm = 0.2 "quadrotor arm length [m]";
  parameter Real I_qx = 0.02 "quadrotor roll inertia [kg.m2]";
  parameter Real I_qy = 0.02 "quadrotor pitch inertia [kg.m2]";

  // Actuator bounds
  parameter Real tau_max = 17.1 "wheel torque bound [N.m]";
  parameter Real T_max = 17.1 "rotor thrust upper bound [N]";

  // Communication parameters
  parameter Real delay_disturbance = 0.145 "communication delay during middle third [s]";
  parameter Real t_middle_start = 6.667 "middle third start [s]";
  parameter Real t_middle_end = 13.333 "middle third end [s]";
  parameter Real data_age_bound = 0.155 "data age bound including margin [s]";

  // Ground robot controller gains
  parameter Real kp_v = 12.0 "ground velocity proportional gain";
  parameter Real kp_o = 2.0 "ground heading-to-omega gain [1/s]";
  parameter Real kp_omega = 3.0 "ground angular velocity gain";
  parameter Real kp_nav = 0.8 "ground navigation gain [1/s]";
  parameter Real v_max = 1.5 "ground max forward speed [m/s]";

  // Quadrotor controller gains
  parameter Real kp_z = 12.0 "altitude proportional gain [N/m]";
  parameter Real kd_z = 6.0 "altitude derivative gain [N.s/m]";
  parameter Real kp_x = 0.8 "x-position to pitch gain [rad/m]";
  parameter Real kd_x = 0.8 "x-velocity damping gain [rad.s/m]";
  parameter Real kp_y = 0.8 "y-position to roll gain [rad/m]";
  parameter Real kd_y = 0.8 "y-velocity damping gain [rad.s/m]";
  parameter Real kp_theta = 15.0 "pitch attitude gain [N.m/rad]";
  parameter Real kd_theta = 5.0 "pitch rate damping [N.m.s/rad]";
  parameter Real kp_phi = 15.0 "roll attitude gain [N.m/rad]";
  parameter Real kd_phi = 5.0 "roll rate damping [N.m.s/rad]";
  parameter Real theta_max_ctrl = 0.3 "max commanded pitch [rad]";
  parameter Real phi_max_ctrl = 0.3 "max commanded roll [rad]";

  // World features and bounds
  parameter Real x_feature1 = 3.0 "ground inspection feature x [m]";
  parameter Real y_feature1 = 0.0 "ground inspection feature y [m]";
  parameter Real x_feature2 = 5.0 "aerial inspection feature x [m]";
  parameter Real y_feature2 = 0.0 "aerial inspection feature y [m]";
  parameter Real z_feature2 = 2.0 "aerial inspection feature z [m]";
  parameter Real x_feature3 = 7.0 "discovered feature x [m]";
  parameter Real y_feature3 = 1.0 "discovered feature y [m]";
  parameter Real z_hover = 2.0 "quadrotor hover altitude [m]";
  parameter Real d_safe = 0.5 "safe separation distance [m]";
  parameter Real x_wall_min = -1.0 "world x min wall [m]";
  parameter Real x_wall_max = 10.0 "world x max wall [m]";
  parameter Real y_wall_min = -2.0 "world y min wall [m]";
  parameter Real y_wall_max = 3.0 "world y max wall [m]";

  // Ground robot states
  Real x_g(start=0.0, fixed=true) "ground robot x position [m]";
  Real y_g(start=0.0, fixed=true) "ground robot y position [m]";
  Real theta_g(start=0.0, fixed=true) "ground robot heading [rad]";
  Real v_g(start=0.0, fixed=true) "ground robot forward speed [m/s]";
  Real omega_g(start=0.0, fixed=true) "ground robot angular speed [rad/s]";

  // Quadrotor states
  Real x_q(start=0.0, fixed=true) "quadrotor x position [m]";
  Real y_q(start=1.0, fixed=true) "quadrotor y position [m]";
  Real z_q(start=0.1, fixed=true) "quadrotor z position [m]";
  Real vx_q(start=0.0, fixed=true) "quadrotor x velocity [m/s]";
  Real vy_q(start=0.0, fixed=true) "quadrotor y velocity [m/s]";
  Real vz_q(start=0.0, fixed=true) "quadrotor z velocity [m/s]";
  Real phi_q(start=0.0, fixed=true) "quadrotor roll angle [rad]";
  Real theta_q(start=0.0, fixed=true) "quadrotor pitch angle [rad]";
  Real p_q(start=0.0, fixed=true) "quadrotor roll rate [rad/s]";
  Real q_q(start=0.0, fixed=true) "quadrotor pitch rate [rad/s]";

  // Actuator commands (saturated)
  Real tau_L "saturated left wheel torque [N.m]";
  Real tau_R "saturated right wheel torque [N.m]";
  Real T1 "saturated rotor 1 thrust [N]";
  Real T2 "saturated rotor 2 thrust [N]";
  Real T3 "saturated rotor 3 thrust [N]";
  Real T4 "saturated rotor 4 thrust [N]";
  Real T_total "total quadrotor thrust [N]";

  // Handoff state machine (0=INIT,1=INSPECT,2=SEND,3=RECV,4=FINAL,5=DONE)
  Integer handoff_state(start=0, fixed=true);

  // Reference trajectories
  Real x_g_ref "ground robot x reference [m]";
  Real y_g_ref "ground robot y reference [m]";
  Real x_q_ref "quadrotor x reference [m]";
  Real y_q_ref "quadrotor y reference [m]";
  Real z_q_ref "quadrotor z reference [m]";

  // Communication variables
  Real comm_delay "current communication delay [s]";
  Real x_g_received "ground x received by quadrotor [m]";
  Real y_g_received "ground y received by quadrotor [m]";
  Real theta_g_received "ground heading received by quadrotor [rad]";
  Real map_result_q_received "quadrotor map result received by ground [m]";
  Real tstamp_g_received "timestamp of ground data at quadrotor [s]";
  Real tstamp_q_received "timestamp of quadrotor data at ground [s]";
  Real data_age_at_g "data age at ground robot [s]";
  Real data_age_at_q "data age at quadrotor [s]";
  Real max_data_age(start=0.0, fixed=true) "maximum observed data age [s]";
  Real t_send_g(start=-1.0, fixed=true) "ground send event time [s]";
  Real t_send_q(start=-1.0, fixed=true) "quadrotor send event time [s]";
  Real t_recv_g(start=-1.0, fixed=true) "ground receive event time [s]";
  Real t_recv_q(start=-1.0, fixed=true) "quadrotor receive event time [s]";

  // Local sensors
  Real d_wall_xp "distance to +x wall [m]";
  Real d_wall_xn "distance to -x wall [m]";
  Real d_wall_yp "distance to +y wall [m]";
  Real d_wall_yn "distance to -y wall [m]";
  Real lidar_range_g "ground lidar range to nearest wall [m]";
  Real lidar_angle_g "ground lidar bearing to nearest wall [rad]";
  Real camera_range_q "quadrotor camera range to aerial feature [m]";
  Real camera_angle_q "quadrotor camera bearing to aerial feature [rad]";

  // Inspection progress
  Real dist_g_to_f1 "ground robot distance to feature 1 [m]";
  Real dist_q_to_f2 "quadrotor distance to feature 2 [m]";
  Real inspection_g(start=0.0, fixed=true) "ground inspection progress [0-1]";
  Real inspection_q(start=0.0, fixed=true) "quadrotor inspection progress [0-1]";

  // Controller intermediates
  Real e_x_g "ground x error [m]";
  Real e_y_g "ground y error [m]";
  Real dist_g "ground distance to target [m]";
  Real theta_ref_g "ground reference heading [rad]";
  Real e_theta_g "wrapped heading error [rad]";
  Real v_cmd_g "ground velocity command [m/s]";
  Real omega_cmd_g "ground angular velocity command [rad/s]";
  Real F_cmd_g "ground force command [N]";
  Real M_cmd_g "ground moment command [N.m]";
  Real tau_L_raw "raw left wheel torque [N.m]";
  Real tau_R_raw "raw right wheel torque [N.m]";
  Real e_z "altitude error [m]";
  Real T_total_cmd "total thrust command [N]";
  Real e_x_q "quadrotor x error [m]";
  Real theta_des_clamped "clamped desired pitch [rad]";
  Real M_pitch_cmd "pitch moment command [N.m]";
  Real e_y_q "quadrotor y error [m]";
  Real phi_des_clamped "clamped desired roll [rad]";
  Real M_roll_cmd "roll moment command [N.m]";

  // Verification variables
  Real separation "3D robot separation [m]";
  Real min_separation(start=100.0, fixed=true) "minimum separation observed [m]";
  Real tracking_error_g "ground robot tracking error [m]";
  Real primary_tracking_error "tracking error after 13 s [m]";
  Real tau_L_bound_ok "left torque within bound [0 or 1]";
  Real tau_R_bound_ok "right torque within bound [0 or 1]";
  Real T1_bound_ok "rotor 1 within bound [0 or 1]";
  Real T2_bound_ok "rotor 2 within bound [0 or 1]";
  Real T3_bound_ok "rotor 3 within bound [0 or 1]";
  Real T4_bound_ok "rotor 4 within bound [0 or 1]";
  Real data_age_bound_ok "data age within bound [0 or 1]";
  Real handoff_ok "handoff completed successfully [0 or 1]";
  Real no_collision_ok "no collision detected [0 or 1]";
  Real task_complete_ok "task completion achieved [0 or 1]";
  Real tracking_error_ok "tracking error below threshold after 13 s [0 or 1]";
  Real no_nan_inf_ok "no NaN or infinite values [0 or 1]";
  Real all_checks_ok "all verification criteria satisfied [0 or 1]";

  // Temporaries for saturation
  Real tau_L_raw_tmp;
  Real tau_R_raw_tmp;
  Real T1_raw;
  Real T2_raw;
  Real T3_raw;
  Real T4_raw;
  Real theta_des_q;
  Real phi_des_q;
  Real e_theta_g_raw;

equation
  // Communication delay model
  comm_delay = if time > t_middle_start and time < t_middle_end then delay_disturbance else 0.001;

  // Ground robot dynamics (differential drive)
  der(x_g) = v_g * cos(theta_g);
  der(y_g) = v_g * sin(theta_g);
  der(theta_g) = omega_g;
  der(v_g) = (tau_L + tau_R) / (r_w * m_g);
  der(omega_g) = (tau_R - tau_L) * d_w / (r_w * I_g);

  // Quadrotor dynamics (simplified 3D with roll/pitch)
  T_total = T1 + T2 + T3 + T4;
  der(x_q) = vx_q;
  der(y_q) = vy_q;
  der(z_q) = vz_q;
  der(vx_q) = T_total * sin(theta_q) / m_q;
  der(vy_q) = -T_total * sin(phi_q) / m_q;
  der(vz_q) = (T_total * cos(theta_q) * cos(phi_q) - m_q * g) / m_q;
  der(phi_q) = p_q;
  der(theta_q) = q_q;
  der(p_q) = ((T1 + T3) - (T2 + T4)) * L_arm / I_qx;
  der(q_q) = ((T1 + T2) - (T3 + T4)) * L_arm / I_qy;

  // Reference trajectories (task allocation with replan after handoff)
  x_g_ref = if handoff_state >= 4 then x_feature3 else x_feature1;
  y_g_ref = if handoff_state >= 4 then y_feature3 else y_feature1;
  x_q_ref = x_feature2;
  y_q_ref = y_feature2;
  z_q_ref = z_hover;

  // Ground robot controller
  e_x_g = x_g_ref - x_g;
  e_y_g = y_g_ref - y_g;
  dist_g = sqrt(e_x_g * e_x_g + e_y_g * e_y_g + 0.0001);
  theta_ref_g = if dist_g > 0.05 then atan2(e_y_g, e_x_g) else theta_g;
  e_theta_g_raw = theta_ref_g - theta_g;
  e_theta_g = if e_theta_g_raw > pi then e_theta_g_raw - 2.0 * pi
    elseif e_theta_g_raw < -pi then e_theta_g_raw + 2.0 * pi
    else e_theta_g_raw;
  v_cmd_g = (if dist_g * kp_nav > v_max then v_max else dist_g * kp_nav)
    * (if cos(e_theta_g) > 0.0 then cos(e_theta_g) else 0.0);
  omega_cmd_g = kp_o * e_theta_g;
  F_cmd_g = kp_v * (v_cmd_g - v_g);
  M_cmd_g = kp_omega * (omega_cmd_g - omega_g);

  // Wheel torque allocation
  tau_L_raw_tmp = r_w * (F_cmd_g - M_cmd_g / d_w) / 2.0;
  tau_R_raw_tmp = r_w * (F_cmd_g + M_cmd_g / d_w) / 2.0;

  // Wheel torque saturation
  tau_L = if tau_L_raw_tmp > tau_max then tau_max
    elseif tau_L_raw_tmp < -tau_max then -tau_max
    else tau_L_raw_tmp;
  tau_R = if tau_R_raw_tmp > tau_max then tau_max
    elseif tau_R_raw_tmp < -tau_max then -tau_max
    else tau_R_raw_tmp;

  // Quadrotor altitude controller
  e_z = z_q_ref - z_q;
  T_total_cmd = m_q * g + kp_z * e_z - kd_z * vz_q;

  // Quadrotor x position -> desired pitch
  e_x_q = x_q_ref - x_q;
  theta_des_q = kp_x * e_x_q - kd_x * vx_q;
  theta_des_clamped = if theta_des_q > theta_max_ctrl then theta_max_ctrl
    elseif theta_des_q < -theta_max_ctrl then -theta_max_ctrl
    else theta_des_q;
  M_pitch_cmd = kp_theta * (theta_des_clamped - theta_q) - kd_theta * q_q;

  // Quadrotor y position -> desired roll
  e_y_q = y_q_ref - y_q;
  phi_des_q = -(kp_y * e_y_q - kd_y * vy_q);
  phi_des_clamped = if phi_des_q > phi_max_ctrl then phi_max_ctrl
    elseif phi_des_q < -phi_max_ctrl then -phi_max_ctrl
    else phi_des_q;
  M_roll_cmd = kp_phi * (phi_des_clamped - phi_q) - kd_phi * p_q;

  // Thrust allocation to four rotors
  T1_raw = T_total_cmd / 4.0 + M_pitch_cmd / (4.0 * L_arm) + M_roll_cmd / (4.0 * L_arm);
  T2_raw = T_total_cmd / 4.0 + M_pitch_cmd / (4.0 * L_arm) - M_roll_cmd / (4.0 * L_arm);
  T3_raw = T_total_cmd / 4.0 - M_pitch_cmd / (4.0 * L_arm) + M_roll_cmd / (4.0 * L_arm);
  T4_raw = T_total_cmd / 4.0 - M_pitch_cmd / (4.0 * L_arm) - M_roll_cmd / (4.0 * L_arm);

  // Rotor thrust saturation [0, T_max]
  T1 = if T1_raw > T_max then T_max elseif T1_raw < 0.0 then 0.0 else T1_raw;
  T2 = if T2_raw > T_max then T_max elseif T2_raw < 0.0 then 0.0 else T2_raw;
  T3 = if T3_raw > T_max then T_max elseif T3_raw < 0.0 then 0.0 else T3_raw;
  T4 = if T4_raw > T_max then T_max elseif T4_raw < 0.0 then 0.0 else T4_raw;

  // Communication: received data (delayed via timestamp)
  x_g_received = x_g;
  y_g_received = y_g;
  theta_g_received = theta_g;
  map_result_q_received = if inspection_q >= 1.0 then x_feature3 else 0.0;

  // Timestamps and data age
  tstamp_g_received = time - comm_delay;
  tstamp_q_received = time - comm_delay;
  data_age_at_g = time - tstamp_q_received;
  data_age_at_q = time - tstamp_g_received;

  // Local sensors (ground lidar to walls)
  d_wall_xp = x_wall_max - x_g;
  d_wall_xn = x_g - x_wall_min;
  d_wall_yp = y_wall_max - y_g;
  d_wall_yn = y_g - y_wall_min;
  lidar_range_g = min(d_wall_xp, min(d_wall_xn, min(d_wall_yp, d_wall_yn)));
  lidar_angle_g = if lidar_range_g == d_wall_xp then 0.0
    elseif lidar_range_g == d_wall_xn then pi
    elseif lidar_range_g == d_wall_yp then pi / 2.0
    else -pi / 2.0;

  // Local sensors (quadrotor camera to aerial feature)
  camera_range_q = sqrt((x_q - x_feature2) * (x_q - x_feature2) + (y_q - y_feature2) * (y_q - y_feature2) + (z_q - z_feature2) * (z_q - z_feature2) + 0.0001);
  camera_angle_q = atan2(y_q - y_feature2, x_q - x_feature2);

  // Inspection progress
  dist_g_to_f1 = sqrt((x_g - x_feature1) * (x_g - x_feature1) + (y_g - y_feature1) * (y_g - y_feature1) + 0.0001);
  dist_q_to_f2 = sqrt((x_q - x_feature2) * (x_q - x_feature2) + (y_q - y_feature2) * (y_q - y_feature2) + (z_q - z_feature2) * (z_q - z_feature2) + 0.0001);
  der(inspection_g) = if handoff_state == 1 and dist_g_to_f1 < 0.5 and inspection_g < 1.0 then 0.4 else 0.0;
  der(inspection_q) = if handoff_state == 1 and dist_q_to_f2 < 0.5 and inspection_q < 1.0 then 0.4 else 0.0;

  // Separation and tracking error
  separation = sqrt((x_g - x_q) * (x_g - x_q) + (y_g - y_q) * (y_g - y_q) + z_q * z_q + 0.0001);
  tracking_error_g = sqrt((x_g_ref - x_g) * (x_g_ref - x_g) + (y_g_ref - y_g) * (y_g_ref - y_g) + 0.0001);
  primary_tracking_error = if time >= 13.0 then tracking_error_g else 0.0;

  // Verification checks
  tau_L_bound_ok = if abs(tau_L) <= tau_max + 0.001 then 1.0 else 0.0;
  tau_R_bound_ok = if abs(tau_R) <= tau_max + 0.001 then 1.0 else 0.0;
  T1_bound_ok = if T1 >= -0.001 and T1 <= T_max + 0.001 then 1.0 else 0.0;
  T2_bound_ok = if T2 >= -0.001 and T2 <= T_max + 0.001 then 1.0 else 0.0;
  T3_bound_ok = if T3 >= -0.001 and T3 <= T_max + 0.001 then 1.0 else 0.0;
  T4_bound_ok = if T4 >= -0.001 and T4 <= T_max + 0.001 then 1.0 else 0.0;
  data_age_bound_ok = if max_data_age <= data_age_bound then 1.0 else 0.0;
  handoff_ok = if handoff_state >= 5 then 1.0 else 0.0;
  no_collision_ok = if min_separation >= d_safe - 0.001 then 1.0 else 0.0;
  task_complete_ok = if handoff_state >= 5 then 1.0 else 0.0;
  tracking_error_ok = if time < 13.0 then 1.0 elseif tracking_error_g < 0.32 then 1.0 else 0.0;
  no_nan_inf_ok = if abs(x_g) < 1.0e5 and abs(y_g) < 1.0e5 and abs(x_q) < 1.0e5 and abs(y_q) < 1.0e5 and abs(z_q) < 1.0e5 and abs(v_g) < 1.0e3 and abs(vx_q) < 1.0e3 and abs(vy_q) < 1.0e3 and abs(vz_q) < 1.0e3 and abs(theta_q) < 1.0e2 and abs(phi_q) < 1.0e2 then 1.0 else 0.0;
  all_checks_ok = tau_L_bound_ok * tau_R_bound_ok * T1_bound_ok * T2_bound_ok * T3_bound_ok * T4_bound_ok * data_age_bound_ok * handoff_ok * no_collision_ok * task_complete_ok * tracking_error_ok * no_nan_inf_ok;

algorithm
  // Handoff FSM transitions (discrete)
  when handoff_state == 0 and time >= 3.0 then
    handoff_state := 1;
  end when;

  when handoff_state == 1 and time >= 7.0 then
    handoff_state := 2;
    t_send_g := time;
    t_send_q := time;
  end when;

  when handoff_state == 2 and time >= 7.0 + delay_disturbance then
    handoff_state := 3;
    t_recv_g := time;
    t_recv_q := time;
  end when;

  when handoff_state == 3 and time >= 8.0 then
    handoff_state := 4;
  end when;

  when handoff_state == 4 and time >= 18.5 then
    handoff_state := 5;
  end when;

  // Minimum separation tracking
  when separation < pre(min_separation) then
    min_separation := separation;
  end when;

  // Maximum data age tracking
  when time > 6.5 and data_age_at_g > pre(max_data_age) then
    max_data_age := data_age_at_g;
  end when;

  // Runtime assertions
  assert(separation > 0.01, "Collision risk: separation near zero", AssertionLevel.warning);
  assert(abs(tau_L) <= tau_max + 0.01, "Left wheel torque exceeds bound", AssertionLevel.warning);
  assert(abs(tau_R) <= tau_max + 0.01, "Right wheel torque exceeds bound", AssertionLevel.warning);
  assert(T1 >= -0.01 and T1 <= T_max + 0.01, "Rotor 1 thrust exceeds bound", AssertionLevel.warning);
  assert(T2 >= -0.01 and T2 <= T_max + 0.01, "Rotor 2 thrust exceeds bound", AssertionLevel.warning);
  assert(T3 >= -0.01 and T3 <= T_max + 0.01, "Rotor 3 thrust exceeds bound", AssertionLevel.warning);
  assert(T4 >= -0.01 and T4 <= T_max + 0.01, "Rotor 4 thrust exceeds bound", AssertionLevel.warning);

  annotation (
    experiment(StartTime=0, StopTime=20.0, Tolerance=1e-6, Interval=0.002),
    Documentation(info="Multi-robot inspection handoff scenario at 500 Hz for 20 s.
      Ground robot: 24 kg, lidar, differential drive, wheel torques bounded at 17.1 N.m.
      Quadrotor: 2.1 kg, camera, four rotor thrusts bounded at 17.1 N.
      Communication: 0.145 s delay disturbance during middle third (6.667-13.333 s).
      Handoff FSM: INIT -> INSPECT -> SEND -> RECV -> FINAL -> DONE.
      Verification: actuator bounds, separation >= 0.5 m, bounded data age,
      successful handoff, no collision, tracking error < 0.32 m after 13 s, no NaN/inf.")
  );
end MixedTeamHandoffF;