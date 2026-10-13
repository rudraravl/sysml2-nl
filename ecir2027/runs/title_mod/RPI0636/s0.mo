model HydMotorForceF
  "Fluid-power robotic actuator: bidirectional hydraulic motor with cascaded pressure-force control"

  // ==================== Parameters from requirement ====================
  parameter Real D_m(unit = "m3/rev") = 48e-6 "Motor displacement [m3/rev]";
  parameter Real eta_v = 0.92 "Volumetric efficiency";
  parameter Real gear_ratio = 12 "Gearbox ratio";
  parameter Real m_table(unit = "kg") = 130 "Table mass [kg]";
  parameter Real q_max(unit = "m3/s") = 0.002 "Maximum valve flow [m3/s]";
  parameter Real F_dist_val(unit = "N") = 218 "Disturbance load change [N]";

  // ==================== Assumed physical parameters ====================
  parameter Real eta_m = 0.95 "Mechanical efficiency (assumed)";
  parameter Real r_arm(unit = "m") = 0.3 "Contact lever arm [m] (assumed)";
  parameter Real k_contact(unit = "N/m") = 5e4 "Contact stiffness [N/m] (assumed)";
  parameter Real J_motor(unit = "kg.m2") = 0.005 "Motor inertia [kg.m2] (assumed)";
  parameter Real b_motor(unit = "N.m.s") = 2.0 "Motor viscous friction [N.m.s] (assumed)";
  parameter Real beta_oil(unit = "Pa") = 1.2e9 "Oil bulk modulus [Pa] (assumed)";
  parameter Real V_chamber(unit = "m3") = 0.02 "Chamber volume [m3] (assumed)";
  parameter Real K_il(unit = "m3/(s.Pa)") = 8.33e-11 "Internal leakage coeff [m3/(s.Pa)] (assumed)";
  parameter Real K_leak(unit = "m3/(s.Pa)") = 1e-12 "External leakage to tank [m3/(s.Pa)] (assumed)";

  // Supply and protection (assumed)
  parameter Real p_supply(unit = "Pa") = 20e6 "Supply pressure [Pa] (assumed)";
  parameter Real p_tank(unit = "Pa") = 0 "Tank pressure, gauge [Pa]";
  parameter Real p_relief(unit = "Pa") = 25e6 "Relief valve pressure [Pa] (assumed)";
  parameter Real K_relief(unit = "m3/(s.Pa)") = 1e-9 "Relief valve conductance [m3/(s.Pa)] (assumed)";
  parameter Real G_check(unit = "m3/(s.Pa)") = 1e-6 "Tank check-valve conductance [m3/(s.Pa)] (assumed)";

  // Valve dynamics (assumed)
  parameter Real tau_valve(unit = "s") = 0.05 "Valve time constant [s] (assumed)";

  // End-stop (assumed)
  parameter Real theta_max(unit = "rad") = 0.15 "End-stop angle [rad] (assumed)";
  parameter Real k_endstop(unit = "N.m/rad") = 1e6 "End-stop stiffness [N.m/rad] (assumed)";
  parameter Real c_endstop(unit = "N.m.s/rad") = 1e3 "End-stop damping [N.m.s/rad] (assumed)";

  // Control gains (assumed, tuned)
  parameter Real Kp_f(unit = "Pa/N") = 2000 "Force loop proportional gain [Pa/N]";
  parameter Real Ki_f(unit = "Pa/(N.s)") = 10000 "Force loop integral gain [Pa/(N.s)]";
  parameter Real Kp_p(unit = "1/Pa") = 1e-6 "Pressure loop proportional gain [1/Pa]";
  parameter Real Ki_p(unit = "1/(Pa.s)") = 1e-5 "Pressure loop integral gain [1/(Pa.s)]";

  // Command (assumed)
  parameter Real F_cmd_val(unit = "N") = 500 "Commanded force [N] (assumed)";
  parameter Real t_cmd_start(unit = "s") = 0.5 "Command step time [s]";

  // Sampling
  parameter Real dt_sample(unit = "s") = 0.002 "Sample period [s] (500 Hz)";

  // ==================== Derived parameters ====================
  final parameter Real pi_val = 3.14159265358979;
  final parameter Real two_pi = 2.0 * pi_val;
  final parameter Real J_table = m_table * r_arm ^ 2 "Table inertia [kg.m2]";
  final parameter Real J_eff = J_motor + J_table / gear_ratio ^ 2 "Effective inertia at motor [kg.m2]";
  final parameter Real C_h = V_chamber / beta_oil "Hydraulic capacitance [m3/Pa]";
  final parameter Real t_dist_start = 20.0 / 3.0 "Disturbance start [s]";
  final parameter Real t_dist_end = 2.0 * 20.0 / 3.0 "Disturbance end [s]";

  // ==================== Dynamic states ====================
  Real p_a(start = 0, fixed = true) "Chamber A pressure [Pa]";
  Real p_b(start = 0, fixed = true) "Chamber B pressure [Pa]";
  Real theta_motor(start = 0, fixed = true) "Motor angle [rad]";
  Real omega_motor(start = 0, fixed = true) "Motor angular velocity [rad/s]";
  Real q_command(start = 0, fixed = true) "Valve commanded flow [m3/s]";
  Real dp_int(start = 0, fixed = true) "Force loop integral state [Pa]";
  Real u_int(start = 0, fixed = true) "Pressure loop integral state [-]";

  // ==================== Algebraic variables ====================
  Real dp "Differential pressure p_a - p_b [Pa]";
  Real q_motor "Motor volumetric flow [m3/s]";
  Real T_motor "Motor torque [N.m]";
  Real theta_table "Table angle [rad]";
  Real omega_table "Table angular velocity [rad/s]";
  Real F_contact "Contact force [N]";
  Real F_dist "Disturbance force [N]";
  Real F_cmd "Force command [N]";
  Real F_error "Force tracking error [N]";
  Real dp_cmd "Unclamped dp command [Pa]";
  Real dp_cmd_clamped "Clamped dp command [Pa]";
  Real dp_error "Pressure tracking error [Pa]";
  Real u_valve "Valve command signal [-]";
  Real u_valve_clamped "Clamped valve command [-]";
  Real q_relief_a "Relief flow A to tank [m3/s]";
  Real q_relief_b "Relief flow B to tank [m3/s]";
  Real q_check_a "Check-valve flow tank to A [m3/s]";
  Real q_check_b "Check-valve flow tank to B [m3/s]";
  Real T_endstop "End-stop torque [N.m]";

  // Sampled sensor traces at 500 Hz
  Real F_contact_s(start = 0) "Sampled contact force [N]";
  Real p_a_s(start = 0) "Sampled chamber A pressure [Pa]";
  Real p_b_s(start = 0) "Sampled chamber B pressure [Pa]";
  Real omega_motor_s(start = 0) "Sampled motor speed [rad/s]";
  Real q_command_s(start = 0) "Sampled valve flow [m3/s]";
  Real F_cmd_s(start = 0) "Sampled force command [N]";
  Real F_error_s(start = 0) "Sampled force error [N]";

equation
  // --- Differential pressure ---
  dp = p_a - p_b;

  // --- Motor flow and torque ---
  q_motor = D_m * omega_motor / two_pi / eta_v;
  T_motor = D_m * dp / two_pi * eta_m;

  // --- Gearbox kinematics ---
  theta_table = theta_motor / gear_ratio;
  omega_table = omega_motor / gear_ratio;

  // --- Compliant contact force ---
  F_contact = k_contact * r_arm * theta_table;

  // --- End-stop protection (soft limit prevents hard impact) ---
  if theta_table > theta_max then
    T_endstop = k_endstop * (theta_table - theta_max) + c_endstop * omega_table;
  elseif theta_table < -theta_max then
    T_endstop = k_endstop * (theta_table + theta_max) + c_endstop * omega_table;
  else
    T_endstop = 0.0;
  end if;

  // --- Disturbance: 218 N during middle third of 20 s ---
  F_dist = F_dist_val * (if time >= t_dist_start and time <= t_dist_end then 1.0 else 0.0);

  // --- Force command: step at t_cmd_start ---
  F_cmd = F_cmd_val * (if time >= t_cmd_start then 1.0 else 0.0);

  // --- Force tracking error ---
  F_error = F_cmd - F_contact;

  // === Outer loop: force -> differential pressure command ===
  dp_cmd = Kp_f * F_error + dp_int;
  dp_cmd_clamped = if dp_cmd > p_supply then p_supply elseif dp_cmd < 0.0 then 0.0 else dp_cmd;

  // === Inner loop: pressure -> valve command ===
  dp_error = dp_cmd_clamped - dp;
  u_valve = Kp_p * dp_error + u_int;
  u_valve_clamped = if u_valve > 1.0 then 1.0 elseif u_valve < -1.0 then -1.0 else u_valve;

  // --- Pressure-compensated valve dynamics (first-order lag) ---
  der(q_command) = (q_max * u_valve_clamped - q_command) / tau_valve;

  // --- Relief valve flows (over-pressure protection) ---
  q_relief_a = if p_a > p_relief then K_relief * (p_a - p_relief) else 0.0;
  q_relief_b = if p_b > p_relief then K_relief * (p_b - p_relief) else 0.0;

  // --- Tank check valves (prevent cavitation / sub-tank pressure) ---
  q_check_a = if p_tank - p_a > 0.0 then G_check * (p_tank - p_a) else 0.0;
  q_check_b = if p_tank - p_b > 0.0 then G_check * (p_tank - p_b) else 0.0;

  // --- Chamber pressure dynamics ---
  C_h * der(p_a) = q_command - q_motor - q_relief_a - K_il * dp - K_leak * p_a + q_check_a;
  C_h * der(p_b) = -q_command + q_motor - q_relief_b + K_il * dp - K_leak * p_b + q_check_b;

  // --- Mechanical dynamics (reflected to motor side) ---
  der(theta_motor) = omega_motor;
  J_eff * der(omega_motor) = T_motor
    - (F_contact + F_dist) * r_arm / gear_ratio
    - T_endstop / gear_ratio
    - b_motor * omega_motor;

  // === Anti-windup: force loop integral ===
  if (dp_cmd >= p_supply and F_error > 0.0) or (dp_cmd <= 0.0 and F_error < 0.0) then
    der(dp_int) = 0.0;
  else
    der(dp_int) = Ki_f * F_error;
  end if;

  // === Anti-windup: pressure loop integral ===
  if (u_valve >= 1.0 and dp_error > 0.0) or (u_valve <= -1.0 and dp_error < 0.0) then
    der(u_int) = 0.0;
  else
    der(u_int) = Ki_p * dp_error;
  end if;

  // === Sampled sensor traces at 500 Hz ===
  // Verification: pressure bounds (p < p_relief), flow bounds (|q| <= q_max),
  // contact-force band, no end-stop impact (|theta_table| < theta_max),
  // stable hold, tracking error < 16 N after 13 s, no NaN/infinite values.
  when sample(0, dt_sample) then
    F_contact_s = F_contact;
    p_a_s = p_a;
    p_b_s = p_b;
    omega_motor_s = omega_motor;
    q_command_s = q_command;
    F_cmd_s = F_cmd;
    F_error_s = F_error;
  end when;

end HydMotorForceF;