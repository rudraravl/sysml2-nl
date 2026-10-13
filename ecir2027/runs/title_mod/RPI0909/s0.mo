model CatamaranDockC
  // ===== Physical parameters =====
  parameter Real m_hull(unit = "kg") = 46.0 "Mass of each capsule hull";
  parameter Real m_deck(unit = "kg") = 18.0 "Mass of rigid deck";
  parameter Real m_total(unit = "kg") = 2.0 * m_hull + m_deck "Total vehicle mass";
  parameter Real L_hull(unit = "m") = 1.1 "Hull separation";
  parameter Real h_half(unit = "m") = L_hull / 2.0 "Half hull separation";
  parameter Real Iz(unit = "kg.m2") = m_total * h_half * h_half / 1.5 "Yaw moment of inertia";

  // ===== Actuator limits =====
  parameter Real F_max(unit = "N") = 396.0 "Maximum command magnitude per propeller";

  // ===== Current disturbance =====
  parameter Real F_current(unit = "N") = 126.0 "Controlled current force disturbance";
  parameter Real t_dist_start(unit = "s") = 4.0 "Disturbance start (middle third of 12 s)";
  parameter Real t_dist_end(unit = "s") = 8.0 "Disturbance end";

  // ===== Dock geometry =====
  parameter Real x_dock(unit = "m") = 8.0 "Fixed docking funnel x position";
  parameter Real y_dock(unit = "m") = 0.0 "Dock funnel y position";
  parameter Real psi_dock(unit = "rad") = 0.0 "Dock approach heading";

  // ===== Compliant capture ring =====
  parameter Real x_ring(unit = "m") = 7.85 "Capture ring contact x";
  parameter Real k_ring(unit = "N/m") = 800.0 "Capture ring stiffness";
  parameter Real c_ring(unit = "N.s/m") = 300.0 "Capture ring damping";
  parameter Real F_contact_limit(unit = "N") = 500.0 "Contact force safety limit";

  // ===== Funnel lateral guidance =====
  parameter Real x_funnel(unit = "m") = 7.5 "Funnel entry x";
  parameter Real k_funnel(unit = "N/m") = 4000.0 "Funnel lateral stiffness";
  parameter Real c_funnel(unit = "N.s/m") = 80.0 "Funnel lateral damping";

  // ===== Hydrodynamic drag =====
  parameter Real Cd_surge(unit = "N.s/m") = 20.0 "Surge drag coefficient";
  parameter Real Cd_lat(unit = "N.s/m") = 400.0 "Lateral drag coefficient";
  parameter Real Cd_yaw(unit = "N.m.s/rad") = 8.0 "Yaw drag coefficient";

  // ===== Control gains =====
  parameter Real v_max(unit = "m/s") = 1.2 "Maximum approach speed";
  parameter Real v_min(unit = "m/s") = 0.02 "Minimum creep speed";
  parameter Real kv(unit = "1/s") = 0.15 "Distance-to-velocity gain";
  parameter Real kd_v(unit = "N.s/m") = 300.0 "Velocity tracking gain";
  parameter Real kp_pos(unit = "N/m") = 600.0 "Position holding gain";
  parameter Real kp_psi(unit = "N.m/rad") = 400.0 "Heading proportional gain";
  parameter Real kd_psi(unit = "N.m.s/rad") = 100.0 "Heading damping gain";
  parameter Real look_ahead(unit = "m") = 1.5 "LOS look-ahead distance";
  parameter Real kp_cross(unit = "rad/m") = 0.5 "Cross-track heading correction";

  // ===== Sample time =====
  parameter Real Ts(unit = "s") = 1.0 / 125.0 "Control loop sample time";

  // ===== Dynamic states =====
  Real x(start = 0.0, unit = "m") "Surge position toward dock";
  Real vx(start = 0.0, unit = "m/s") "Surge velocity";
  Real y(start = 0.15, unit = "m") "Lateral position";
  Real vy(start = 0.0, unit = "m/s") "Lateral velocity";
  Real psi(start = 0.08, unit = "rad") "Heading";
  Real omega(start = 0.0, unit = "rad/s") "Yaw rate";

  // ===== Control commands =====
  Real F_surge_cmd(unit = "N") "Total surge force command";
  Real M_yaw_cmd(unit = "N.m") "Yaw moment command";
  Real Fp_cmd(unit = "N") "Port propeller raw command";
  Real Fs_cmd(unit = "N") "Starboard propeller raw command";
  Real Fp_sat(unit = "N") "Port propeller saturated command";
  Real Fs_sat(unit = "N") "Starboard propeller saturated command";

  // ===== Disturbance =====
  Real F_dist_active(unit = "N") "Active current disturbance force";

  // ===== Contact and funnel =====
  Real penetration(unit = "m") "Capture ring penetration depth";
  Real F_contact(unit = "N") "Capture ring contact force";
  Real F_funnel_y(unit = "N") "Funnel lateral guidance force";

  // ===== Guidance variables =====
  Real dist_to_dock(unit = "m") "Euclidean distance to dock";
  Real speed_factor "Speed scheduling factor (1 far, <1 near)";
  Real v_ref(unit = "m/s") "Speed-scheduled velocity reference";
  Real x_target(unit = "m") "LOS guidance target x";
  Real los_angle(unit = "rad") "Line-of-sight angle to target";
  Real blend "LOS-to-dock-heading blend factor";
  Real psi_des(unit = "rad") "Desired heading";
  Real heading_err(unit = "rad") "Wrapped heading error";
  Real kp_pos_active(unit = "N/m") "Active position gain";

  // ===== Sensors =====
  Real sonar_range(unit = "m") "Sonar distance to dock";
  Real pressure_depth(unit = "m") "Pressure-based depth reading";
  Real imu_yaw_rate(unit = "rad/s") "IMU yaw rate measurement";
  Real optical_x(unit = "m") "Short-range optical relative x";
  Real optical_y(unit = "m") "Short-range optical relative y";
  Real optical_psi(unit = "rad") "Short-range optical relative heading";
  Real optical_valid "Optical pose sensor validity (1 valid, 0 invalid)";

  // ===== Tracking and status =====
  Real track_error(unit = "m") "Primary tracking error";
  Real capture_flag "Capture established flag (1 captured, 0 not)";

equation
  // ===== Distance to dock (zero-guarded norm) =====
  dist_to_dock = sqrt(max((x_dock - x) * (x_dock - x) + (y_dock - y) * (y_dock - y), 1e-8));

  // ===== Speed scheduling: reduce speed inside 1 m =====
  speed_factor = if dist_to_dock > 1.0 then 1.0
                 else if dist_to_dock > 0.01 then dist_to_dock
                 else 0.01;

  // ===== Velocity reference =====
  v_ref = max(v_min, min(v_max, kv * dist_to_dock)) * speed_factor;

  // ===== Position gain scheduling (ramp inside 1 m) =====
  kp_pos_active = kp_pos * max(0.0, 1.0 - dist_to_dock);

  // ===== LOS guidance with dock-aligned blend =====
  x_target = min(x + look_ahead, x_dock);
  los_angle = atan2(y_dock - y, max(x_target - x, 0.01));
  blend = if dist_to_dock > 1.0 then 0.0
          else if dist_to_dock > 0.3 then (1.0 - dist_to_dock) / 0.7
          else 1.0;
  psi_des = (1.0 - blend) * los_angle + blend * psi_dock + kp_cross * (y_dock - y);

  // ===== Wrapped heading error to [-pi, pi] =====
  heading_err = atan2(sin(psi_des - psi), cos(psi_des - psi));

  // ===== Surge control: velocity tracking + position hold =====
  F_surge_cmd = kd_v * (v_ref - vx) + kp_pos_active * (x_dock - x);

  // ===== Yaw control: PD on heading error =====
  M_yaw_cmd = kp_psi * heading_err + kd_psi * (0.0 - omega);

  // ===== Differential propeller allocation =====
  Fp_cmd = (F_surge_cmd - M_yaw_cmd / h_half) / 2.0;
  Fs_cmd = (F_surge_cmd + M_yaw_cmd / h_half) / 2.0;

  // ===== Actuator saturation =====
  Fp_sat = max(-F_max, min(F_max, Fp_cmd));
  Fs_sat = max(-F_max, min(F_max, Fs_cmd));

  // ===== Current disturbance (middle third of 12 s) =====
  F_dist_active = if time >= t_dist_start and time <= t_dist_end then F_current else 0.0;

  // ===== Compliant capture ring contact =====
  penetration = max(0.0, x - x_ring);
  F_contact = if penetration > 0.0
              then max(0.0, k_ring * penetration + c_ring * vx)
              else 0.0;

  // ===== Funnel lateral guidance =====
  F_funnel_y = if x > x_funnel
               then -k_funnel * y - c_funnel * vy
               else 0.0;

  // ===== Rigid-body planar dynamics =====
  der(x) = vx;
  der(y) = vy;
  der(psi) = omega;

  m_total * der(vx) = (Fp_sat + Fs_sat) * cos(psi) - Cd_surge * vx - F_contact;
  m_total * der(vy) = (Fp_sat + Fs_sat) * sin(psi) + F_dist_active - Cd_lat * vy + F_funnel_y;
  Iz * der(omega) = (Fs_sat - Fp_sat) * h_half - Cd_yaw * omega;

  // ===== Sensor models =====
  sonar_range = dist_to_dock;
  pressure_depth = 0.5;
  imu_yaw_rate = omega;
  optical_valid = if dist_to_dock < 2.0 then 1.0 else 0.0;
  optical_x = x_dock - x;
  optical_y = y_dock - y;
  optical_psi = psi_dock - psi;

  // ===== Tracking and capture status =====
  track_error = dist_to_dock;
  capture_flag = if penetration > 0.001 and abs(vx) < 0.05 then 1.0 else 0.0;

  // ===== Requirement assertions =====
  assert(F_contact <= F_contact_limit + 1.0, "Contact force exceeds 500 N limit");
  assert(time < 7.8 or track_error < 0.105, "Primary tracking error exceeds 0.105 m after 7.8 s");
  assert(abs(Fp_sat) <= F_max + 0.5, "Port propeller command out of bounds");
  assert(abs(Fs_sat) <= F_max + 0.5, "Starboard propeller command out of bounds");
  assert(time < 11.5 or capture_flag > 0.5, "Capture not established by end of simulation");

  annotation(
    experiment(StartTime = 0, StopTime = 12, Tolerance = 1e-6, Interval = 1.0 / 125.0),
    Documentation(info = "CatamaranDockC: Free-base marine catamaran robot with speed-scheduled pose control, compliant capture ring, and cross-current disturbance. Two 46 kg capsule hulls at 1.1 m separation with 18 kg rigid deck. Differential propeller forces (max 396 N each) control surge and heading. Approaches fixed docking funnel from 8 m, reduces speed inside 1 m, aligns heading, and establishes compliant capture. 126 N lateral current disturbance injected during middle third (4-8 s). Sonar, pressure, IMU, and short-range optical pose sensors provide feedback. Runs at 125 Hz for 12 s."));
end CatamaranDockC;