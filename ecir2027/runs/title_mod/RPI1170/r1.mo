model MixedTeamHandoffF
  // ===== Physical and mission parameters =====
  parameter Real m_g = 24.0 "ground robot mass [kg]";
  parameter Real m_q = 2.1 "quadrotor mass [kg]";
  parameter Real g = 9.81 "gravitational acceleration [m/s2]";
  parameter Real tau_max = 17.1 "actuator bound: wheel torque [N.m] and rotor thrust [N]";
  parameter Real r_w = 0.10 "ground wheel radius [m]";
  parameter Real L_g = 0.40 "ground half wheelbase [m]";
  parameter Real I_g = 1.50 "ground yaw inertia [kg.m2]";
  parameter Real k_tilt = 0.50 "quadrotor tilt mixing coefficient";
  parameter Real freq_sim = 500.0 "sample/simulation frequency [Hz]";
  parameter Real T_end = 20.0 "mission duration [s]";
  parameter Real delay_dist = 0.145 "communication delay disturbance [s]";
  parameter Real track_thresh = 0.32 "primary tracking error threshold [m]";
  parameter Real track_check_time = 13.0 "tracking verification time [s]";
  parameter Real sep_min = 0.50 "minimum planar separation when quad is low [m]";
  parameter Real v_max_g = 1.50 "ground robot speed limit [m/s]";
  parameter Real om_max_g = 2.00 "ground robot yaw rate limit [rad/s]";
  parameter Real max_delay_buf = 0.20 "upper bound on delay() [s]";
  parameter Real wp_tol = 0.30 "waypoint reached tolerance [m]";
  parameter Real handoff_dur = 0.30 "handoff duration [s]";

  // ===== World features (walls, markers, survey features in common frame) =====
  parameter Real wall_x = 8.00 "wall x in common world frame [m]";
  parameter Real marker1_x = 2.00 "survey marker 1 x [m]";
  parameter Real marker1_y = 0.00 "survey marker 1 y [m]";
  parameter Real marker2_x = 5.00 "survey marker 2 x [m]";
  parameter Real marker2_y = 2.00 "survey marker 2 y [m]";

  // ===== Controller gains =====
  parameter Real kp_v = 1.50;
  parameter Real kp_om = 2.00;
  parameter Real kp_a_v = 6.00;
  parameter Real kp_a_om = 8.00;
  parameter Real kp_q = 5.00;
  parameter Real kd_q = 4.00;

  // ===== Ground robot states =====
  Real x_g(start=0.0, fixed=true) "ground x [m]";
  Real y_g(start=0.0, fixed=true) "ground y [m]";
  Real th_g(start=0.0, fixed=true) "ground heading [rad]";
  Real v_g(start=0.0, fixed=true) "ground forward speed [m/s]";
  Real om_g(start=0.0, fixed=true) "ground yaw rate [rad/s]";
  Real tau_l_cmd "left wheel torque command [N.m]";
  Real tau_r_cmd "right wheel torque command [N.m]";
  Real tau_l "left wheel torque applied [N.m]";
  Real tau_r "right wheel torque applied [N.m]";

  // ===== Quadrotor states =====
  Real x_q(start=1.0, fixed=true) "quad x [m]";
  Real y_q(start=1.0, fixed=true) "quad y [m]";
  Real z_q(start=0.0, fixed=true) "quad z [m]";
  Real vx_q(start=0.0, fixed=true) "quad x velocity [m/s]";
  Real vy_q(start=0.0, fixed=true) "quad y velocity [m/s]";
  Real vz_q(start=0.0, fixed=true) "quad z velocity [m/s]";
  Real t1_cmd "rotor 1 thrust command [N]";
  Real t2_cmd "rotor 2 thrust command [N]";
  Real t3_cmd "rotor 3 thrust command [N]";
  Real t4_cmd "rotor 4 thrust command [N]";
  Real t1 "rotor 1 thrust applied [N]";
  Real t2 "rotor 2 thrust applied [N]";
  Real t3 "rotor 3 thrust applied [N]";
  Real t4 "rotor 4 thrust applied [N]";
  Real Fx_q "quad body x force [N]";
  Real Fy_q "quad body y force [N]";
  Real Fz_q "quad body z force [N]";

  // ===== Handoff state machine =====
  // 0: ground_mission, 1: handoff_pending, 2: quad_mission, 3: complete
  Integer state(start=0) "handoff state";
  Real state_timer(start=0.0) "handoff timer [s]";
  Integer wp_idx_g(start=0) "ground waypoint index";
  Integer wp_idx_q(start=0) "quad waypoint index";

  // ===== Waypoints and tracking =====
  Real wp_x_g "ground waypoint x [m]";
  Real wp_y_g "ground waypoint y [m]";
  Real wp_x_q "quad waypoint x [m]";
  Real wp_y_q "quad waypoint y [m]";
  Real wp_z_q "quad waypoint z [m]";
  Real track_err "primary tracking error [m]";
  Real track_err_at_check(start=10.0) "tracking error sampled at check time [m]";

  // ===== Communication (timestamped pose/map) =====
  Real tx_x_g "transmitted ground x [m]";
  Real tx_y_g "transmitted ground y [m]";
  Real tx_th_g "transmitted ground heading [rad]";
  Real tx_t_g "transmitted timestamp [s]";
  Real rx_x_g "received ground x [m]";
  Real rx_y_g "received ground y [m]";
  Real rx_th_g "received ground heading [rad]";
  Real rx_t_g "received timestamp [s]";
  Real data_age "data age of received message [s]";
  Real delay_active "current communication delay [s]";

  // ===== Sensors (local to each robot) =====
  Real lidar_range "ground lidar range to wall [m]";
  Real cam_x "quad camera observed marker x in world frame [m]";
  Real cam_y "quad camera observed marker y in world frame [m]";

  // ===== Separation =====
  Real sep_xy "horizontal separation between robots [m]";
  Real min_planar_sep_when_low(start=100.0) "min planar sep when quad is low [m]";

  // ===== Intermediate control variables =====
  Real psi_wp "waypoint heading [rad]";
  Real e_psi "heading error [rad]";
  Real d_wp "waypoint distance ground [m]";
  Real v_cmd "ground speed command [m/s]";
  Real om_cmd "ground yaw rate command [rad/s]";
  Real a_v "ground forward acceleration command [m/s2]";
  Real a_om "ground yaw acceleration command [rad/s2]";
  Real ex_q "quad x position error [m]";
  Real ey_q "quad y position error [m]";
  Real ez_q "quad z position error [m]";
  Real Fx_cmd "quad x force command [N]";
  Real Fy_cmd "quad y force command [N]";
  Real Fz_cmd "quad z force command [N]";

  // ===== Verification latches and flags =====
  Boolean collision_occurred(start=false) "collision latch";
  Boolean handoff_done(start=false) "handoff success latch";
  Boolean task_complete(start=false) "task completion latch";
  Boolean ok_actuator "actuator bounds respected";
  Boolean ok_separation "separation bounds respected";
  Boolean ok_data_age "data age bounded";
  Boolean ok_handoff "handoff successful";
  Boolean ok_no_collision "no collision";
  Boolean ok_task "task completed";
  Boolean ok_track "tracking error within threshold after 13 s";
  Boolean ok_no_nan "no NaN or infinite values";
  Boolean all_ok "all verification criteria satisfied";

algorithm
  // Saturate ground wheel torques to +/- tau_max
  tau_l := if tau_l_cmd > tau_max then tau_max
           else if tau_l_cmd < -tau_max then -tau_max
           else tau_l_cmd;
  tau_r := if tau_r_cmd > tau_max then tau_max
           else if tau_r_cmd < -tau_max then -tau_max
           else tau_r_cmd;
  // Saturate rotor thrusts to [0, tau_max]
  t1 := if t1_cmd > tau_max then tau_max else if t1_cmd < 0.0 then 0.0 else t1_cmd;
  t2 := if t2_cmd > tau_max then tau_max else if t2_cmd < 0.0 then 0.0 else t2_cmd;
  t3 := if t3_cmd > tau_max then tau_max else if t3_cmd < 0.0 then 0.0 else t3_cmd;
  t4 := if t4_cmd > tau_max then tau_max else if t4_cmd < 0.0 then 0.0 else t4_cmd;

algorithm
  when time >= track_check_time then
    track_err_at_check := track_err;
  end when;

  when sample(0, 1.0 / freq_sim) then
    // State machine: task allocation and explicit handoff
    if state == 0 then
      if d_wp < wp_tol then
        if wp_idx_g < 1 then
          wp_idx_g := 1;
        else
          state := 1;
          state_timer := 0.0;
        end if;
      end if;
    elseif state == 1 then
      state_timer := state_timer + 1.0 / freq_sim;
      if state_timer >= handoff_dur then
        state := 2;
        handoff_done := true;
      end if;
    elseif state == 2 then
      if track_err < wp_tol then
        if wp_idx_q < 2 then
          wp_idx_q := wp_idx_q + 1;
        else
          state := 3;
          task_complete := true;
        end if;
      end if;
    end if;
    // Collision latch: quad low and close to ground robot
    if z_q < 1.0 and sep_xy < sep_min then
      collision_occurred := true;
    end if;
    // Track minimum planar separation when quad is low
    if z_q < 1.0 and sep_xy < min_planar_sep_when_low then
      min_planar_sep_when_low := sep_xy;
    end if;
  end when;

equation
  // ===== Ground robot dynamics (differential drive) =====
  der(x_g) = v_g * cos(th_g);
  der(y_g) = v_g * sin(th_g);
  der(th_g) = om_g;
  m_g * der(v_g) = (tau_r + tau_l) / r_w;
  I_g * der(om_g) = (tau_r - tau_l) * L_g / r_w;

  // ===== Quadrotor dynamics (point mass, attitude abstracted) =====
  Fz_q = t1 + t2 + t3 + t4;
  Fx_q = k_tilt * (t1 + t2 - t3 - t4);
  Fy_q = k_tilt * (t1 - t2 + t3 - t4);
  m_q * der(vx_q) = Fx_q;
  m_q * der(vy_q) = Fy_q;
  m_q * der(vz_q) = Fz_q - m_q * g;
  der(x_q) = vx_q;
  der(y_q) = vy_q;
  der(z_q) = vz_q;

  // ===== Waypoint selection (task allocation) =====
  // Ground robot inspects markers along x-axis
  wp_x_g = if wp_idx_g <= 0 then 2.0 else 4.0;
  wp_y_g = 0.0;
  // Quadrotor hovers at start during ground mission, then uses received
  // ground pose (replan using received data) as first waypoint after handoff
  wp_x_q = if state <= 1 then 1.0
           else if wp_idx_q <= 0 then rx_x_g
           else if wp_idx_q == 1 then 5.0
           else 5.0;
  wp_y_q = if state <= 1 then 1.0
           else if wp_idx_q <= 0 then rx_y_g
           else if wp_idx_q == 1 then 1.0
           else 2.0;
  wp_z_q = 2.0;

  // ===== Primary tracking error (active robot) =====
  track_err = if state <= 1 then
                sqrt((wp_x_g - x_g)^2 + (wp_y_g - y_g)^2)
              else
                sqrt((wp_x_q - x_q)^2 + (wp_y_q - y_q)^2 + (wp_z_q - z_q)^2);

  // ===== Ground robot local motion control =====
  psi_wp = atan2(wp_y_g - y_g, wp_x_g - x_g);
  e_psi = atan2(sin(psi_wp - th_g), cos(psi_wp - th_g));
  d_wp = sqrt((wp_x_g - x_g)^2 + (wp_y_g - y_g)^2);
  v_cmd = if d_wp < 0.05 then 0.0
          else if kp_v * d_wp > v_max_g then v_max_g
          else kp_v * d_wp;
  om_cmd = if kp_om * e_psi > om_max_g then om_max_g
           else if kp_om * e_psi < -om_max_g then -om_max_g
           else kp_om * e_psi;
  a_v = kp_a_v * (v_cmd - v_g);
  a_om = kp_a_om * (om_cmd - om_g);
  tau_r_cmd = r_w * (m_g * a_v / 2.0 + I_g * a_om / (2.0 * L_g));
  tau_l_cmd = r_w * (m_g * a_v / 2.0 - I_g * a_om / (2.0 * L_g));

  // ===== Quadrotor local motion control =====
  ex_q = wp_x_q - x_q;
  ey_q = wp_y_q - y_q;
  ez_q = wp_z_q - z_q;
  Fx_cmd = kp_q * ex_q - kd_q * vx_q;
  Fy_cmd = kp_q * ey_q - kd_q * vy_q;
  Fz_cmd = kp_q * ez_q - kd_q * vz_q + m_q * g;
  t1_cmd = Fz_cmd / 4.0 + Fx_cmd / (4.0 * k_tilt) + Fy_cmd / (4.0 * k_tilt);
  t2_cmd = Fz_cmd / 4.0 + Fx_cmd / (4.0 * k_tilt) - Fy_cmd / (4.0 * k_tilt);
  t3_cmd = Fz_cmd / 4.0 - Fx_cmd / (4.0 * k_tilt) + Fy_cmd / (4.0 * k_tilt);
  t4_cmd = Fz_cmd / 4.0 - Fx_cmd / (4.0 * k_tilt) - Fy_cmd / (4.0 * k_tilt);

  // ===== Communication: timestamped pose/map with delay disturbance =====
  tx_x_g = x_g;
  tx_y_g = y_g;
  tx_th_g = th_g;
  tx_t_g = time;
  delay_active = if (time > T_end / 3.0 and time < 2.0 * T_end / 3.0)
                 then delay_dist else 1e-6;
  rx_x_g = delay(tx_x_g, delay_active, max_delay_buf);
  rx_y_g = delay(tx_y_g, delay_active, max_delay_buf);
  rx_th_g = delay(tx_th_g, delay_active, max_delay_buf);
  rx_t_g = delay(tx_t_g, delay_active, max_delay_buf);
  data_age = max(0.0, time - rx_t_g);

  // ===== Local sensors =====
  lidar_range = max(0.01, wall_x - x_g);
  cam_x = marker2_x;
  cam_y = marker2_y;

  // ===== Separation =====
  sep_xy = sqrt((x_q - x_g)^2 + (y_q - y_g)^2);

  // ===== Verification criteria =====
  ok_actuator = abs(tau_l) <= tau_max + 1e-6 and abs(tau_r) <= tau_max + 1e-6
                and t1 >= -1e-6 and t1 <= tau_max + 1e-6
                and t2 >= -1e-6 and t2 <= tau_max + 1e-6
                and t3 >= -1e-6 and t3 <= tau_max + 1e-6
                and t4 >= -1e-6 and t4 <= tau_max + 1e-6;
  ok_separation = min_planar_sep_when_low >= sep_min;
  ok_data_age = data_age <= delay_dist + 1e-3;
  ok_handoff = handoff_done;
  ok_no_collision = not collision_occurred;
  ok_task = task_complete;
  ok_track = track_err_at_check <= track_thresh;
  ok_no_nan = (x_g == x_g) and (y_g == y_g) and (th_g == th_g) and (v_g == v_g)
              and (x_q == x_q) and (y_q == y_q) and (z_q == z_q)
              and (vx_q == vx_q) and (vy_q == vy_q) and (vz_q == vz_q)
              and (tau_l == tau_l) and (tau_r == tau_r)
              and (t1 == t1) and (t2 == t2) and (t3 == t3) and (t4 == t4)
              and (abs(x_g) < 1e20) and (abs(y_g) < 1e20) and (abs(z_q) < 1e20)
              and (abs(v_g) < 1e20) and (abs(vx_q) < 1e20) and (abs(vz_q) < 1e20);
  all_ok = ok_actuator and ok_separation and ok_data_age and ok_handoff
           and ok_no_collision and ok_task and ok_track and ok_no_nan;

  annotation(
    experiment(StopTime = 20.0, Interval = 0.002, Tolerance = 1e-6),
    Documentation(info = "Multi-robot handoff scenario: 24 kg lidar ground robot and 2.1 kg camera quadrotor divide an inspection task, exchange timestamped pose/map updates over a channel with a controlled 0.145 s delay disturbance during the middle third, and replan the quadrotor using the received ground pose. Wheel torques and four rotor thrusts are independently bounded at 17.1 N.m/N. Runs at 500 Hz for 20 s with synchronized state, command, and sensor traces. Verification: actuator bounds, separation bounds, bounded data age, successful handoff, no collision, task completion, primary tracking error below 0.32 m after 13 s, and no NaN or infinite values.")
  );
end MixedTeamHandoffF;