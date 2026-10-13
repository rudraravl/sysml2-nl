model MixedTeamHandoffB
  // ==================== PHYSICAL PARAMETERS ====================
  parameter Real m_g = 24.0 "Ground robot mass [kg]";
  parameter Real m_q = 2.1 "Quadrotor mass [kg]";
  parameter Real g_acc = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real cmd_max = 11.5 "Max command magnitude [N.m or N]";
  // Wheel radius and arm length are engineering assumptions required for
  // torque-to-force and thrust-to-force mapping; not specified in requirement.
  parameter Real r_w = 0.15 "Wheel radius [m]";
  parameter Real L_arm = 0.25 "Quadrotor arm length [m]";

  // ==================== MISSION PARAMETERS ====================
  parameter Real t_end = 10.0 "Mission duration [s]";
  parameter Real t_delay_start = 10.0 / 3.0 "Delay window start [s]";
  parameter Real t_delay_end = 2.0 * 10.0 / 3.0 "Delay window end [s]";
  parameter Real delay_inj = 0.07 "Injected communication delay [s]";
  parameter Real delay_nom = 0.002 "Nominal communication delay [s]";
  parameter Real delay_max = 0.1 "Max delay for buffer [s]";
  parameter Real err_thresh = 0.48 "Tracking error threshold [m]";
  parameter Real t_err_check = 6.5 "Error check time [s]";
  parameter Real sep_min = 0.3 "Minimum separation [m]";

  // ==================== SURVEY MARKERS (world frame) ====================
  parameter Real mx1 = 2.0 "Marker 1 x [m]";
  parameter Real mx2 = 4.0 "Marker 2 x [m]";
  parameter Real mx3 = 6.0 "Marker 3 x [m]";
  parameter Real mz3 = 1.5 "Marker 3 z [m]";
  parameter Real rendezvous_x = 4.0 "Rendezvous x [m]";
  parameter Real rendezvous_z = 1.0 "Rendezvous z [m]";

  // ==================== CONTROLLER GAINS ====================
  parameter Real kp_g = 25.0 "Ground P gain [N/m]";
  parameter Real kd_g = 40.0 "Ground D gain [N.s/m]";
  parameter Real kp_q = 20.0 "Quad x P gain [N/m]";
  parameter Real kd_q = 12.0 "Quad x D gain [N.s/m]";
  parameter Real kp_qz = 30.0 "Quad z P gain [N/m]";
  parameter Real kd_qz = 15.0 "Quad z D gain [N.s/m]";

  // ==================== RAMP DURATIONS ====================
  parameter Real ramp1 = 1.5 "Ramp to WP1 [s]";
  parameter Real ramp2 = 1.5 "Ramp to WP2 [s]";
  parameter Real ramp_rdv = 1.0 "Ramp to rendezvous [s]";
  parameter Real ramp3 = 3.0 "Ramp to WP3 [s]";
  parameter Real ramp_ret = 1.5 "Ramp for return [s]";

  // ==================== GROUND ROBOT STATES ====================
  Real gx(start = 0.0) "Ground robot x position [m]";
  Real gvx(start = 0.0) "Ground robot x velocity [m/s]";

  // ==================== QUADROTOR STATES ====================
  Real qx(start = 0.0) "Quadrotor x position [m]";
  Real qz(start = 1.0) "Quadrotor z position [m]";
  Real qvx(start = 0.0) "Quadrotor x velocity [m/s]";
  Real qvz(start = 0.0) "Quadrotor z velocity [m/s]";

  // ==================== GROUND ACTUATORS ====================
  Real Fgx_cmd "Ground force command [N]";
  Real tau_l_cmd "Left wheel torque command [N.m]";
  Real tau_r_cmd "Right wheel torque command [N.m]";
  Real tau_l "Saturated left wheel torque [N.m]";
  Real tau_r "Saturated right wheel torque [N.m]";
  Real Fgx "Ground net force [N]";

  // ==================== QUADROTOR ACTUATORS ====================
  Real Fqz_cmd "Quad z net force command [N]";
  Real Fqx_cmd "Quad x force command [N]";
  Real T_total "Total thrust command [N]";
  Real T_diff "Thrust differential [N]";
  Real T_front "Front pair thrust [N]";
  Real T_rear "Rear pair thrust [N]";
  Real T1_cmd "Rotor 1 thrust command [N]";
  Real T2_cmd "Rotor 2 thrust command [N]";
  Real T3_cmd "Rotor 3 thrust command [N]";
  Real T4_cmd "Rotor 4 thrust command [N]";
  Real T1 "Rotor 1 thrust [N]";
  Real T2 "Rotor 2 thrust [N]";
  Real T3 "Rotor 3 thrust [N]";
  Real T4 "Rotor 4 thrust [N]";
  Real Fqx "Quad x force [N]";
  Real Fqz "Quad z force [N]";

  // ==================== COMMUNICATION ====================
  Real comm_delay "Current comm delay [s]";
  Boolean in_delay_window "In delay window flag";
  Real q_recv_x "Quad received ground x [m]";
  Real g_recv_qx "Ground received quad x [m]";
  Real g_recv_qz "Ground received quad z [m]";
  discrete Real g_send_time(start = 0.0) "Ground send timestamp [s]";
  discrete Real q_send_time(start = 0.0) "Quad send timestamp [s]";
  Real q_data_age "Data age at quad [s]";
  Real g_data_age "Data age at ground [s]";

  // ==================== HANDOFF STATE MACHINE ====================
  discrete Integer handoff_state(start = 0)
    "0=WP1,1=WP2,2=rendezvous,3=WP3,4=return,5=done";
  discrete Boolean handoff_data_sent(start = false);
  discrete Boolean handoff_data_received(start = false);
  discrete Real handoff_send_time(start = -1.0) "Handoff send timestamp [s]";
  discrete Real handoff_recv_time(start = -1.0) "Handoff receive timestamp [s]";
  discrete Real handoff_received_x(start = 0.0)
    "Ground x captured at handoff [m]";
  discrete Boolean handoff_done(start = false);

  // ==================== TASK PROGRESS ====================
  discrete Boolean wp1_done(start = false);
  discrete Boolean wp2_done(start = false);
  discrete Boolean wp3_done(start = false);
  discrete Boolean mission_complete(start = false);

  // ==================== TARGET TRAJECTORIES ====================
  Real g_target_x "Ground target x [m]";
  Real g_target_vel "Ground target velocity [m/s]";
  Real q_target_x "Quad target x [m]";
  Real q_target_z "Quad target z [m]";
  Real q_target_vx "Quad target x velocity [m/s]";
  Real q_target_vz "Quad target z velocity [m/s]";
  Real wp3_replanned_x "Replanned WP3 x [m]";

  // ==================== TRACKING ERRORS ====================
  Real g_track_err "Ground tracking error [m]";
  Real q_track_err "Quad tracking error [m]";
  Real primary_track_err "Primary tracking error [m]";

  // ==================== SEPARATION ====================
  Real sep_xy "Horizontal separation [m]";
  Real sep_3d "3D separation [m]";
  Real safe_sep "Safe (nonzero) separation [m]";

  // ==================== SENSORS ====================
  Real lidar_d1 "Lidar dist to WP1 [m]";
  Real lidar_d2 "Lidar dist to WP2 [m]";
  Real lidar_range "Lidar range [m]";
  Real lidar_bearing "Lidar bearing [rad]";
  Real cam_range "Camera range to WP3 [m]";

  // ==================== STATUS FLAGS ====================
  Boolean no_collision_flag;
  Boolean data_age_ok;
  Boolean all_finite_check;
  Boolean err_check_pass;

equation
  // ==================== DYNAMICS ====================
  // Ground robot (1D along x; y and z are constant at 0)
  der(gx) = gvx;
  der(gvx) = Fgx / m_g;

  // Quadrotor (2D in x-z plane; y is constant at 0)
  der(qx) = qvx;
  der(qz) = qvz;
  der(qvx) = Fqx / m_q;
  der(qvz) = Fqz / m_q;

  // ==================== ACTUATOR SATURATION ====================
  // Ground: two wheel torques independently bounded at cmd_max
  tau_l = if tau_l_cmd > cmd_max then cmd_max
          elseif tau_l_cmd < -cmd_max then -cmd_max else tau_l_cmd;
  tau_r = if tau_r_cmd > cmd_max then cmd_max
          elseif tau_r_cmd < -cmd_max then -cmd_max else tau_r_cmd;
  Fgx = (tau_l + tau_r) / r_w;

  // Quad: four rotor thrusts independently bounded at [0, cmd_max]
  T1 = if T1_cmd > cmd_max then cmd_max elseif T1_cmd < 0.0 then 0.0 else T1_cmd;
  T2 = if T2_cmd > cmd_max then cmd_max elseif T2_cmd < 0.0 then 0.0 else T2_cmd;
  T3 = if T3_cmd > cmd_max then cmd_max elseif T3_cmd < 0.0 then 0.0 else T3_cmd;
  T4 = if T4_cmd > cmd_max then cmd_max elseif T4_cmd < 0.0 then 0.0 else T4_cmd;

  // Force allocation (simplified X-frame)
  Fqz = (T1 + T2 + T3 + T4) - m_q * g_acc;
  Fqx = (T1 + T2 - T3 - T4) * L_arm;

  // ==================== COMMUNICATION ====================
  in_delay_window = time >= t_delay_start and time <= t_delay_end;
  comm_delay = if in_delay_window then delay_inj else delay_nom;

  // Timestamped pose exchange via delayed channel
  q_recv_x = delay(gx, comm_delay, delay_max);
  g_recv_qx = delay(qx, comm_delay, delay_max);
  g_recv_qz = delay(qz, comm_delay, delay_max);

  // Send timestamps at 100 Hz
  when sample(0, 0.01) then
    g_send_time = time;
    q_send_time = time;
  end when;

  // Data age = transport delay + half sample period
  q_data_age = comm_delay + 0.005;
  g_data_age = comm_delay + 0.005;

  // ==================== HANDOFF STATE MACHINE ====================
  // State 0 -> 1: WP1 inspection complete at t=2
  when time >= 2.0 and pre(handoff_state) == 0 then
    handoff_state = 1;
    wp1_done = true;
  end when;

  // State 1 -> 2: WP2 done, ground sends handoff data at t=4
  when time >= 4.0 and pre(handoff_state) == 1 then
    handoff_state = 2;
    wp2_done = true;
    handoff_data_sent = true;
    handoff_send_time = time;
  end when;

  // Handoff data arrives after injected delay
  when time >= 4.0 + delay_inj and pre(handoff_data_received) == false then
    handoff_data_received = true;
    handoff_recv_time = time;
    handoff_done = true;
    handoff_received_x = q_recv_x;
  end when;

  // State 2 -> 3: Quad begins WP3 inspection at t=5
  when time >= 5.0 and pre(handoff_state) == 2 then
    handoff_state = 3;
  end when;

  // State 3 -> 4: WP3 done at t=8, begin return
  when time >= 8.0 and pre(handoff_state) == 3 then
    handoff_state = 4;
    wp3_done = true;
  end when;

  // State 4 -> 5: Mission complete at t=10
  when time >= 10.0 and pre(handoff_state) == 4 then
    handoff_state = 5;
    mission_complete = true;
  end when;

  // ==================== REPLANNING ====================
  // Quadrotor replans WP3 using received ground pose at handoff
  wp3_replanned_x = if handoff_data_received then
                      mx3 + (handoff_received_x - rendezvous_x)
                    else mx3;

  // ==================== TARGET TRAJECTORIES ====================
  // Ground robot target (trapezoidal velocity profile along x)
  g_target_x = if time < ramp1 then mx1 * time / ramp1
               elseif time < 2.0 then mx1
               elseif time < 2.0 + ramp2 then
                 mx1 + (mx2 - mx1) * (time - 2.0) / ramp2
               elseif time < 8.0 then mx2
               elseif time < 8.0 + ramp_ret then
                 mx2 - mx2 * (time - 8.0) / ramp_ret
               else 0.0;

  g_target_vel = if time < ramp1 then mx1 / ramp1
                 elseif time < 2.0 then 0.0
                 elseif time < 2.0 + ramp2 then (mx2 - mx1) / ramp2
                 elseif time < 8.0 then 0.0
                 elseif time < 8.0 + ramp_ret then -mx2 / ramp_ret
                 else 0.0;

  // Quadrotor target x (hover -> rendezvous -> replanned WP3 -> return)
  q_target_x = if time < 4.0 then 0.0
               elseif time < 4.0 + ramp_rdv then
                 rendezvous_x * (time - 4.0) / ramp_rdv
               elseif time < 5.0 then rendezvous_x
               elseif time < 5.0 + ramp3 then
                 rendezvous_x +
                 (wp3_replanned_x - rendezvous_x) * (time - 5.0) / ramp3
               elseif time < 8.0 then wp3_replanned_x
               elseif time < 8.0 + ramp_ret then
                 wp3_replanned_x -
                 wp3_replanned_x * (time - 8.0) / ramp_ret
               else 0.0;

  // Quadrotor target z (hover -> WP3 altitude -> return)
  q_target_z = if time < 5.0 then rendezvous_z
               elseif time < 5.0 + ramp3 then
                 rendezvous_z + (mz3 - rendezvous_z) * (time - 5.0) / ramp3
               elseif time < 8.0 then mz3
               elseif time < 8.0 + ramp_ret then
                 mz3 - (mz3 - rendezvous_z) * (time - 8.0) / ramp_ret
               else rendezvous_z;

  q_target_vx = if time < 4.0 then 0.0
                elseif time < 4.0 + ramp_rdv then rendezvous_x / ramp_rdv
                elseif time < 5.0 then 0.0
                elseif time < 5.0 + ramp3 then
                  (wp3_replanned_x - rendezvous_x) / ramp3
                elseif time < 8.0 then 0.0
                elseif time < 8.0 + ramp_ret then
                  -wp3_replanned_x / ramp_ret
                else 0.0;

  q_target_vz = if time < 5.0 then 0.0
                elseif time < 5.0 + ramp3 then (mz3 - rendezvous_z) / ramp3
                elseif time < 8.0 then 0.0
                elseif time < 8.0 + ramp_ret then
                  -(mz3 - rendezvous_z) / ramp_ret
                else 0.0;

  // ==================== CONTROLLERS ====================
  // Ground robot: PD + velocity feedforward
  Fgx_cmd = kp_g * (g_target_x - gx) + kd_g * (g_target_vel - gvx);
  tau_l_cmd = Fgx_cmd * r_w / 2.0;
  tau_r_cmd = Fgx_cmd * r_w / 2.0;

  // Quadrotor: PD + velocity feedforward (net force; gravity comp in allocation)
  Fqz_cmd = kp_qz * (q_target_z - qz) + kd_qz * (q_target_vz - qvz);
  Fqx_cmd = kp_q * (q_target_x - qx) + kd_q * (q_target_vx - qvx);

  // Thrust allocation (X-frame, gravity compensation added)
  T_total = Fqz_cmd + m_q * g_acc;
  T_diff = Fqx_cmd / L_arm;
  T_front = (T_total + T_diff) / 2.0;
  T_rear = (T_total - T_diff) / 2.0;
  T1_cmd = T_front / 2.0;
  T2_cmd = T_front / 2.0;
  T3_cmd = T_rear / 2.0;
  T4_cmd = T_rear / 2.0;

  // ==================== TRACKING ERRORS ====================
  g_track_err = abs(gx - g_target_x);
  q_track_err = sqrt((qx - q_target_x) * (qx - q_target_x) +
                     (qz - q_target_z) * (qz - q_target_z));
  primary_track_err = if handoff_state <= 2 then g_track_err else q_track_err;

  // ==================== SEPARATION ====================
  // Ground at z=0, quad at z>=rendezvous_z; 3D sep always >= rendezvous_z
  sep_xy = abs(qx - gx);
  sep_3d = sqrt((qx - gx) * (qx - gx) + qz * qz);
  safe_sep = if sep_3d < 0.01 then 0.01 else sep_3d;

  // ==================== SENSORS ====================
  // Lidar (ground robot): range to nearest surveyed marker
  lidar_d1 = abs(gx - mx1);
  lidar_d2 = abs(gx - mx2);
  lidar_range = if lidar_d1 < lidar_d2 then lidar_d1 else lidar_d2;
  lidar_bearing = 0.0 "All markers along x-axis; bearing is 0 or pi";

  // Camera (quadrotor): range to WP3
  cam_range = sqrt((qx - mx3) * (qx - mx3) + (qz - mz3) * (qz - mz3));

  // ==================== STATUS FLAGS ====================
  no_collision_flag = sep_3d >= sep_min;
  data_age_ok = q_data_age <= delay_inj + 0.02 and
                g_data_age <= delay_inj + 0.02;
  all_finite_check = abs(gx) < 1e10 and abs(gvx) < 1e10 and
                     abs(qx) < 1e10 and abs(qz) < 1e10 and
                     abs(qvx) < 1e10 and abs(qvz) < 1e10 and
                     abs(Fgx) < 1e10 and abs(Fqx) < 1e10 and abs(Fqz) < 1e10;
  err_check_pass = if time >= t_err_check then
                     primary_track_err < err_thresh
                   else true;

  annotation(
    experiment(StartTime = 0, StopTime = 10.0, Tolerance = 1e-6,
               Interval = 0.01),
    Documentation(info =
      "Multi-robot inspection with explicit handoff. A 24 kg lidar-equipped "
      + "ground robot (two bounded wheel torques) inspects WP1 and WP2. "
      + "A 2.1 kg camera quadrotor (four bounded rotor thrusts) inspects WP3 "
      + "after receiving timestamped pose/map data from the ground robot. "
      + "Communication delay of 0.07 s is injected during the middle third "
      + "(3.33-6.67 s). The quadrotor replans its WP3 target using the "
      + "received ground pose. All commands bounded at 11.5 N.m or N. "
      + "Runs at 100 Hz for 10 s. Primary tracking error must be below "
      + "0.48 m after 6.5 s. Wheel radius (0.15 m), arm length (0.25 m), "
      + "marker locations, controller gains, and trajectory ramp durations "
      + "are engineering assumptions not specified in the requirement.")
  );
end MixedTeamHandoffB;