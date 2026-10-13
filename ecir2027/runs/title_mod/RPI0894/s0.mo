model CatamaranDiveF
  "Free-base catamaran marine robot: descend to 8 m, hold, return to 3 m"

  // === Given physical parameters ===
  parameter Real m_hull = 46.0 "Mass of each capsule hull [kg]";
  parameter Real m_deck = 18.0 "Mass of rigid deck [kg]";
  parameter Real m_total = 2.0*m_hull + m_deck "Total mass [kg]";
  parameter Real sep = 1.1 "Hull separation [m]";
  parameter Real rho_water = 1025.0 "Seawater density [kg/m3]";
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real F_prop_max = 525.0 "Max propeller force per propeller [N]";

  // === Inferred physical parameters (not specified in requirements) ===
  parameter Real V_disp = 0.1085 "Displaced volume [m3], near-neutral buoyancy";
  parameter Real F_vert_max = 525.0 "Max vertical thruster force [N] (inferred actuator)";
  parameter Real L_vert = 0.55 "Vertical thruster pitch lever [m] (inferred)";
  parameter Real I_z = 2.0*m_hull*(sep/2.0)^2 + m_deck*sep^2/12.0 "Yaw inertia [kg.m2]";
  parameter Real I_x = 5.0 "Roll inertia [kg.m2] (inferred)";
  parameter Real I_y = 12.0 "Pitch inertia [kg.m2] (inferred)";
  parameter Real Cd_u = 40.0 "Surge quadratic drag [N.s2/m2] (inferred)";
  parameter Real Cd_w = 60.0 "Heave quadratic drag [N.s2/m2] (inferred)";
  parameter Real Cd_r = 30.0 "Yaw quadratic drag [N.m.s2] (inferred)";
  parameter Real Cd_p = 10.0 "Roll quadratic drag [N.m.s2] (inferred)";
  parameter Real Cd_q = 10.0 "Pitch quadratic drag [N.m.s2] (inferred)";

  // === Disturbance ===
  parameter Real F_current = 116.0 "Current force disturbance [N]";
  parameter Real t_sim = 20.0 "Total simulation time [s]";

  // === Mission parameters ===
  parameter Real z_target = 8.0 "Descent target depth [m]";
  parameter Real z_return = 3.0 "Return depth [m]";
  parameter Real t_hold_end = 14.0 "Hold-to-return switch time [s]";

  // === Controller gains: depth cascade ===
  parameter Real Kp_z = 1.2 "Depth P gain [1/s]";
  parameter Real Kd_z = 0.6 "Depth D gain [s]";
  parameter Real Kp_w = 4.0 "Heave velocity P gain [1/s]";
  parameter Real w_max = 1.2 "Max heave velocity command [m/s]";

  // === Controller gains: heading cascade ===
  parameter Real Kp_psi = 2.5 "Heading P gain [1/s]";
  parameter Real Kd_psi = 0.8 "Heading D gain [s]";
  parameter Real Kp_r = 3.0 "Yaw rate P gain [1/s]";

  // === Controller gains: surge ===
  parameter Real Kp_u = 4.0 "Surge velocity P gain [1/s]";
  parameter Real u_ref = 0.0 "Reference surge velocity [m/s]";

  // === Pitch/roll stabilizer gains ===
  parameter Real Kp_th = 6.0 "Pitch P gain [1/s2]";
  parameter Real Kd_th = 1.5 "Pitch rate D gain [1/s]";
  parameter Real Kp_phi = 6.0 "Roll P gain [1/s2]";
  parameter Real Kd_phi = 1.5 "Roll rate D gain [1/s]";

  // === State variables (dynamic) ===
  Real z(start=0.0, fixed=true) "Depth [m], positive downward";
  Real w(start=0.0, fixed=true) "Heave velocity [m/s], positive downward";
  Real x(start=0.0, fixed=true) "Surge position [m]";
  Real u(start=0.0, fixed=true) "Surge velocity [m/s]";
  Real psi(start=0.0, fixed=true) "Heading [rad]";
  Real r(start=0.0, fixed=true) "Yaw rate [rad/s]";
  Real phi(start=0.001, fixed=true) "Roll [rad]";
  Real p(start=0.0, fixed=true) "Roll rate [rad/s]";
  Real theta(start=0.0, fixed=true) "Pitch [rad]";
  Real q(start=0.0, fixed=true) "Pitch rate [rad/s]";

  // === Actuator commands and bounded forces ===
  Real F_port_cmd "Port propeller command [N]";
  Real F_stbd_cmd "Starboard propeller command [N]";
  Real F_port "Port propeller force [N] (bounded)";
  Real F_stbd "Starboard propeller force [N] (bounded)";
  Real F_vf_cmd "Front vertical thruster command [N]";
  Real F_vr_cmd "Rear vertical thruster command [N]";
  Real F_vf "Front vertical thruster force [N] (bounded, inferred)";
  Real F_vr "Rear vertical thruster force [N] (bounded, inferred)";

  // === Control references and internal commands ===
  Real z_ref "Depth reference [m]";
  Real w_ref_raw "Unbounded heave velocity reference [m/s]";
  Real w_ref "Bounded heave velocity reference [m/s]";
  Real psi_ref "Heading reference [rad]";
  Real r_ref "Yaw rate reference [rad/s]";
  Real F_surge_cmd "Surge force command [N]";
  Real M_yaw_cmd "Yaw moment command [N.m]";
  Real F_heave_cmd "Heave force command [N]";
  Real M_pitch_cmd "Pitch moment command [N.m]";

  // === Physical quantities ===
  Real W_grav "Weight [N]";
  Real F_buoy "Buoyancy force [N]";
  Real F_net_buoy "Net buoyancy, positive upward [N]";
  Real F_dist "Current disturbance force [N]";

  // === Sensor outputs (ideal models) ===
  Real z_meas "Pressure depth sensor [m]";
  Real u_meas "Doppler surge velocity [m/s]";
  Real w_meas "Doppler heave velocity [m/s]";
  Real psi_meas "IMU heading [rad]";
  Real phi_meas "IMU roll [rad]";
  Real theta_meas "IMU pitch [rad]";
  Real r_meas "IMU yaw rate [rad/s]";
  Real q_meas "IMU pitch rate [rad/s]";
  Real p_meas "IMU roll rate [rad/s]";

  // === Verification metrics ===
  Real tracking_error "Primary depth tracking error [m]";
  Real max_prop_force "Max absolute propeller force [N]";

equation
  // === Physical constants ===
  W_grav = m_total * g;
  F_buoy = rho_water * g * V_disp;
  F_net_buoy = F_buoy - W_grav;

  // === Mission reference profile ===
  // Descend to 8 m, hold, then return to 3 m at t_hold_end
  z_ref = if time < t_hold_end then z_target else z_return;
  psi_ref = 0.0;

  // === Current disturbance: active during middle third of simulation ===
  F_dist = if time >= t_sim/3.0 and time <= 2.0*t_sim/3.0 then F_current else 0.0;

  // === Sensor models (ideal: direct state feedback) ===
  z_meas = z;
  u_meas = u;
  w_meas = w;
  psi_meas = psi;
  phi_meas = phi;
  theta_meas = theta;
  r_meas = r;
  q_meas = q;
  p_meas = p;

  // === Cascaded depth controller ===
  // Outer loop: depth error -> heave velocity reference
  w_ref_raw = Kp_z * (z_ref - z_meas) - Kd_z * w_meas;
  w_ref = if w_ref_raw > w_max then w_max elseif w_ref_raw < -w_max then -w_max else w_ref_raw;
  // Inner loop: heave velocity error -> vertical thrust (with buoyancy feedforward)
  F_heave_cmd = m_total * Kp_w * (w_ref - w_meas) + F_net_buoy;

  // === Cascaded heading controller ===
  // Outer loop: heading error -> yaw rate reference
  r_ref = Kp_psi * (psi_ref - psi_meas) - Kd_psi * r_meas;
  // Inner loop: yaw rate error -> yaw moment
  M_yaw_cmd = I_z * Kp_r * (r_ref - r_meas);

  // === Surge velocity controller ===
  F_surge_cmd = m_total * Kp_u * (u_ref - u_meas);

  // === Pitch stabilizer ===
  M_pitch_cmd = I_y * (Kp_th * (-theta_meas) - Kd_th * q_meas);

  // === Bounded thrust allocation ===
  // Horizontal propellers: sum = surge force, differential = yaw moment
  F_port_cmd = F_surge_cmd/2.0 - M_yaw_cmd/sep;
  F_stbd_cmd = F_surge_cmd/2.0 + M_yaw_cmd/sep;
  F_port = if F_port_cmd > F_prop_max then F_prop_max
    elseif F_port_cmd < -F_prop_max then -F_prop_max
    else F_port_cmd;
  F_stbd = if F_stbd_cmd > F_prop_max then F_prop_max
    elseif F_stbd_cmd < -F_prop_max then -F_prop_max
    else F_stbd_cmd;

  // Vertical thrusters (inferred): sum = heave force, differential = pitch moment
  F_vf_cmd = F_heave_cmd/2.0 - M_pitch_cmd/(2.0*L_vert);
  F_vr_cmd = F_heave_cmd/2.0 + M_pitch_cmd/(2.0*L_vert);
  F_vf = if F_vf_cmd > F_vert_max then F_vert_max
    elseif F_vf_cmd < -F_vert_max then -F_vert_max
    else F_vf_cmd;
  F_vr = if F_vr_cmd > F_vert_max then F_vert_max
    elseif F_vr_cmd < -F_vert_max then -F_vert_max
    else F_vr_cmd;

  // === Vehicle dynamics ===
  // Surge: propeller thrust + disturbance - quadratic drag
  m_total * der(u) = F_port + F_stbd + F_dist - Cd_u * abs(u) * u;
  der(x) = u;

  // Heave: vertical thrust + weight - buoyancy - quadratic drag
  m_total * der(w) = F_vf + F_vr + W_grav - F_buoy - Cd_w * abs(w) * w;
  der(z) = w;

  // Yaw: differential propeller thrust - quadratic drag
  I_z * der(r) = (F_stbd - F_port) * sep/2.0 - Cd_r * abs(r) * r;
  der(psi) = r;

  // Pitch: differential vertical thrust - quadratic drag
  I_y * der(q) = (F_vr - F_vf) * L_vert - Cd_q * abs(q) * q;
  der(theta) = q;

  // Roll: passive PD stabilization (no dedicated roll actuator)
  I_x * der(p) = -I_x * (Kp_phi * phi + Kd_phi * p) - Cd_p * abs(p) * p;
  der(phi) = p;

  // === Verification metrics ===
  tracking_error = abs(z - z_ref);
  max_prop_force = if abs(F_port) > abs(F_stbd) then abs(F_port) else abs(F_stbd);

  annotation(
    experiment(StartTime=0, StopTime=20, Tolerance=1e-6, Interval=0.002),
    Documentation(info="CatamaranDiveF: Free-base catamaran dive mission.
      Mission: descend to 8 m, hold depth and zero heading, return to 3 m.
      Simulation: 500 Hz (Interval=0.002 s) for 20 s.
      Disturbance: 116 N current force during middle third (6.67-13.33 s).
      Actuation: port/starboard propellers (525 N max) for surge/heading.
      Vertical thrusters (inferred, 525 N max) for depth/pitch control.
      Inferred parameters: V_disp, I_x, I_y, L_vert, drag coefficients,
      vertical thruster specs. These are not specified in the requirements.")
  );
end CatamaranDiveF;