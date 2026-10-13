model CatamaranDockA
  "Free-base marine catamaran docking with compliant capture and cross-current"

  // ===== Stated physical parameters =====
  parameter Real m_hull = 46 "kg, each capsule hull mass (two hulls)";
  parameter Real m_deck = 18 "kg, rigid deck mass";
  parameter Real separation = 1.1 "m, hull center-to-center separation";
  parameter Real F_prop_max = 310 "N, per-propeller command magnitude limit";
  parameter Real F_current = 70 "N, cross-current force disturbance";
  parameter Real t_total = 8 "s, scenario duration";
  parameter Real x_dock = 8 "m, docking funnel axial position (rigid station geometry)";
  parameter Real y_dock = 0 "m, docking funnel lateral position";
  parameter Real x0 = 0 "m, initial surge position (8 m from dock)";
  parameter Real f_ctrl = 80 "Hz, control loop rate";
  parameter Real dt_ctrl = 1/f_ctrl "s, control sample period";

  // ===== Design parameters (numerical values not stated; chosen to satisfy bounds) =====
  parameter Real d_u = 80 "N.s/m, surge linear drag (hull hydrodynamics unspecified)";
  parameter Real d_v = 120 "N.s/m, sway linear drag (hull hydrodynamics unspecified)";
  parameter Real d_r = 30 "N.m.s/rad, yaw linear drag (hull hydrodynamics unspecified)";
  parameter Real v_max = 3.5 "m/s, design speed bound (value not stated in requirement)";
  parameter Real u_far = 3.0 "m/s, scheduled approach speed far from dock";
  parameter Real u_near = 1.0 "m/s, scheduled speed inside 1 m zone";
  parameter Real u_terminal = 0.3 "m/s, scheduled speed inside 0.3 m terminal zone";
  parameter Real k_axial = 2000 "N/m, compliant capture axial stiffness";
  parameter Real c_axial = 300 "N.s/m, compliant capture axial damping";
  parameter Real k_lat = 1500 "N/m, compliant capture lateral stiffness";
  parameter Real c_lat = 150 "N.s/m, compliant capture lateral damping";
  parameter Real funnel_length = 1.0 "m, lateral funnel engagement range";
  parameter Real Kp_u = 400 "surge velocity tracking gain";
  parameter Real Kp_psi = 80 "heading proportional gain";
  parameter Real Kd_psi = 40 "heading derivative gain";
  parameter Real Klat = 1.5 "LOS lateral weighting gain";
  parameter Real psi_lim = 0.5 "rad, heading command clamp";

  // ===== Derived =====
  parameter Real m_total = 2*m_hull + m_deck "kg, total mass";
  parameter Real y_arm = separation/2 "m, propeller lateral moment arm";
  parameter Real Iz = 2*m_hull*(separation/2)^2
    "kg.m^2, yaw inertia from hulls (deck own rotational inertia unknown, neglected)";

  // ===== Continuous states =====
  Real x_pos(start=x0, fixed=true) "m, surge position (toward dock)";
  Real y_pos(start=0, fixed=true) "m, lateral position";
  Real psi(start=0, fixed=true) "rad, heading (CCW from x)";
  Real u(start=0, fixed=true) "m/s, surge velocity";
  Real v(start=0, fixed=true) "m/s, sway velocity";
  Real r(start=0, fixed=true) "rad/s, yaw rate";

  // ===== Continuous variables =====
  Real dx_dock "m, axial distance to dock";
  Real dy_dock "m, lateral offset to dock";
  Real dist_dock "m, Euclidean distance to dock";
  Real u_des "m/s, scheduled desired surge speed";
  Real psi_des "rad, LOS desired heading";
  Real F_dist_y "N, lateral current disturbance (inertial)";
  Real F_contact_x "N, capture axial contact force (inertial)";
  Real F_contact_y "N, capture lateral contact force (inertial)";
  Real F_contact_mag "N, contact force magnitude";
  Real k_lat_eff "N/m, effective lateral funnel stiffness";
  Real F_inertial_x "N, total inertial x force";
  Real F_inertial_y "N, total inertial y force";
  Real F_body_in_x "N, inertial force transformed to body x";
  Real F_body_in_y "N, inertial force transformed to body y";
  Real Fx_body "N, total body x force";
  Real Fy_body "N, total body y force";

  // ===== Sensors =====
  Real sonar_range "m, sonar range to dock";
  Real pressure_depth "m, pressure-derived depth (surface operation reads 0)";
  Real imu_u "m/s, IMU surge velocity";
  Real imu_v "m/s, IMU sway velocity";
  Real imu_r "rad/s, IMU yaw rate";
  Real optical_y "m, short-range optical lateral pose";
  Real optical_psi "rad, short-range optical heading pose";
  Real optical_valid "1.0 if optical pose valid else 0.0";

  // ===== Discrete controller (80 Hz) =====
  discrete Real Fp_cmd(start=0) "N, port propeller command (limited)";
  discrete Real Fs_cmd(start=0) "N, starboard propeller command (limited)";
  discrete Real Fp_raw(start=0) "N, port propeller command (raw)";
  discrete Real Fs_raw(start=0) "N, starboard propeller command (raw)";
  discrete Real F_surge_cmd(start=0) "N, total surge force command";
  discrete Real Mz_cmd(start=0) "N.m, yaw moment command";
  discrete Real u_des_d(start=0) "m/s, sampled scheduled speed";
  discrete Real psi_des_d(start=0) "rad, sampled desired heading";
  discrete Real F_surge_hi(start=0) "N, surge command upper bound given yaw";
  discrete Real F_surge_lo(start=0) "N, surge command lower bound given yaw";
  discrete Real F_surge_l(start=0) "N, limited surge command";
  discrete Real trace_tick(start=0) "80 Hz synchronized trace counter";

  // ===== Metrics =====
  Real primary_track_err "m, primary tracking error";
  Boolean captured "capture flag";
  Boolean speed_bounded "speed within bound";
  Boolean actuators_bounded "actuators within bound";
  Boolean contact_bounded "contact force within bound";

equation
  // Rigid station geometry
  dx_dock = x_dock - x_pos;
  dy_dock = y_dock - y_pos;
  dist_dock = sqrt(dx_dock*dx_dock + dy_dock*dy_dock);

  // Speed-scheduled desired surge speed (reduces inside 1 m, terminal inside 0.3 m)
  if dx_dock > 1.0 then
    u_des = u_far;
  elseif dx_dock > 0.3 then
    u_des = u_near;
  elseif dx_dock > 0.0 then
    u_des = u_terminal;
  else
    u_des = 0.0;
  end if;

  // LOS heading with lateral weighting, clamped (lateral and yaw alignment)
  psi_des = max(-psi_lim, min(psi_lim, atan2(-Klat*y_pos, max(dx_dock, 0.3))));

  // Cross-current disturbance: middle third of scenario
  if time >= t_total/3 and time <= 2*t_total/3 then
    F_dist_y = F_current;
  else
    F_dist_y = 0.0;
  end if;

  // Compliant capture ring: axial one-sided stop at dock face
  if x_pos >= x_dock then
    F_contact_x = -k_axial*(x_pos - x_dock) - c_axial*u;
  else
    F_contact_x = 0.0;
  end if;

  // Compliant capture ring: lateral funnel with ramped stiffness
  if dx_dock > 0.0 and dx_dock < funnel_length then
    k_lat_eff = k_lat*(funnel_length - dx_dock)/funnel_length;
    F_contact_y = -k_lat_eff*(y_pos - y_dock) - c_lat*v;
  elseif dx_dock <= 0.0 then
    k_lat_eff = k_lat;
    F_contact_y = -k_lat*(y_pos - y_dock) - c_lat*v;
  else
    k_lat_eff = 0.0;
    F_contact_y = 0.0;
  end if;

  F_contact_mag = sqrt(F_contact_x*F_contact_x + F_contact_y*F_contact_y);

  // Inertial forces transformed to body frame
  F_inertial_x = F_contact_x;
  F_inertial_y = F_dist_y + F_contact_y;
  F_body_in_x = F_inertial_x*cos(psi) + F_inertial_y*sin(psi);
  F_body_in_y = -F_inertial_x*sin(psi) + F_inertial_y*cos(psi);

  Fx_body = (Fp_cmd + Fs_cmd) - d_u*u + F_body_in_x;
  Fy_body = -d_v*v + F_body_in_y;

  // Discrete controller at 80 Hz (zero-order hold, contact transition via scheduled speed)
  when sample(0, dt_ctrl) loop
    trace_tick = pre(trace_tick) + 1;
    u_des_d = u_des;
    psi_des_d = psi_des;
    // Surge velocity tracking with drag feedforward
    F_surge_cmd = Kp_u*(u_des_d - u) + d_u*u;
    // Heading PD
    Mz_cmd = Kp_psi*(psi_des_d - psi) - Kd_psi*r;
    // Anti-saturation allocation preserving yaw authority
    F_surge_hi = 2*F_prop_max - abs(Mz_cmd)/y_arm;
    F_surge_lo = -2*F_prop_max + abs(Mz_cmd)/y_arm;
    F_surge_l = max(F_surge_lo, min(F_surge_hi, F_surge_cmd));
    Fp_raw = (F_surge_l - Mz_cmd/y_arm)/2;
    Fs_raw = (F_surge_l + Mz_cmd/y_arm)/2;
    Fp_cmd = max(-F_prop_max, min(F_prop_max, Fp_raw));
    Fs_cmd = max(-F_prop_max, min(F_prop_max, Fs_raw));
  end when;

  // 3-DOF planar dynamics (z-up, psi CCW)
  der(u) = Fx_body/m_total + v*r;
  der(v) = Fy_body/m_total - u*r;
  der(r) = (y_arm*(Fs_cmd - Fp_cmd) - d_r*r)/Iz;
  der(x_pos) = u*cos(psi) - v*sin(psi);
  der(y_pos) = u*sin(psi) + v*cos(psi);
  der(psi) = r;

  // Sensors
  sonar_range = max(0.0, dx_dock);
  pressure_depth = 0.0;
  imu_u = u;
  imu_v = v;
  imu_r = r;
  optical_valid = if dx_dock < 1.0 then 1.0 else 0.0;
  optical_y = if dx_dock < 1.0 then y_pos else 0.0;
  optical_psi = if dx_dock < 1.0 then psi else 0.0;

  // Metrics
  primary_track_err = dist_dock;
  captured = dx_dock < 0.05 and abs(dy_dock) < 0.10 and abs(psi) < 0.10;
  speed_bounded = abs(u) <= v_max + 1e-6 and abs(v) <= v_max + 1e-6;
  actuators_bounded = abs(Fp_cmd) <= F_prop_max + 1e-6 and abs(Fs_cmd) <= F_prop_max + 1e-6;
  contact_bounded = F_contact_mag < 500.0;

  // Bounds assertions (requirements)
  assert(actuators_bounded, "Propeller command exceeds 310 N limit");
  assert(speed_bounded, "Speed exceeds design bound");
  assert(contact_bounded, "Contact force exceeds 500 N", AssertionLevel.warning);
  assert(time < 5.2 or primary_track_err < 0.135,
         "Primary tracking error exceeds 0.135 m after 5.2 s", AssertionLevel.warning);

  annotation(
    experiment(StartTime=0, StopTime=8, Tolerance=1e-6, Interval=0.0125),
    Documentation(info="CatamaranDockA: two 46 kg capsule hulls (1.1 m separation) with 18 kg rigid deck, port/starboard propellers (310 N limit each). Differential thrust controls surge and heading. Speed-scheduled pose control with LOS guidance and contact transition. Compliant capture ring (axial stop + lateral funnel). 70 N cross-current in middle third. Discrete control at 80 Hz for 8 s with synchronized state/command/sensor traces. Hull hydrodynamic drag coefficients, design speed bound, and capture stiffness are design estimates (physical values not stated in requirement). Deck own rotational inertia is unknown and neglected.")
  );
end CatamaranDockA;