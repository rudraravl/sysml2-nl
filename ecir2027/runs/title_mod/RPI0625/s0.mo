model HydMotorPositionA
  "Hydraulic motor position control: bidirectional motor driving rotary table through 12:1 gearbox"

  // ==================== Motor parameters ====================
  parameter Real D_motor = 7.6394e-6
    "Motor displacement [m3/rad] = 48e-6 m3/rev / (2*pi) — 48 cm3/rev specified";
  parameter Real eta_v = 0.92 "Volumetric efficiency (specified)";
  parameter Real n_gear = 12.0 "Gearbox ratio motor:table = 12:1 (specified)";

  // ==================== Load parameters ====================
  parameter Real m_eff = 130.0
    "Effective table mass in linear coordinates [kg] — 130 kg specified";
  parameter Real r_table = 1.0
    "Effective table radius [m] — assumed; converts angular to linear travel";

  // ==================== Hydraulic parameters (assumed — not specified) ====================
  parameter Real p_supply = 210e5
    "Supply pressure [Pa] — assumed typical industrial value";
  parameter Real p_return = 5e5
    "Return/tank pressure [Pa] — assumed typical industrial value";
  parameter Real beta = 1.4e9
    "Fluid bulk modulus [Pa] — assumed mineral oil";
  parameter Real V_dead = 100e-6
    "Dead volume per chamber [m3] — assumed";
  parameter Real C_leak = 1e-13
    "Cross-port leakage coefficient [m3/(s*Pa)] — assumed";

  // ==================== Valve parameters ====================
  parameter Real Q_max = 0.001
    "Valve command magnitude limit [m3/s] (specified)";

  // ==================== Travel parameters ====================
  parameter Real L_max = 1.0
    "Maximum travel [m] — assumed; total travel not specified in requirement";
  parameter Real x_target = 0.7 * L_max
    "Target position = 70 percent of available travel [m] (specified)";

  // ==================== End stop parameters (assumed) ====================
  parameter Real k_stop = 1e8 "End stop stiffness [N/m] — assumed";
  parameter Real b_stop = 1e5 "End stop damping [N*s/m] — assumed";

  // ==================== Controller parameters (tuned) ====================
  parameter Real Kp = 0.001 "PID proportional gain [m3/(s*m)]";
  parameter Real Ki = 0.001 "PID integral gain [m3/(s*m*s)]";
  parameter Real Kd = 0.0005 "PID derivative gain [m3/(s*(m/s))]";
  parameter Real K_press = 1e-12 "Pressure feedback gain for damping [m3/(s*Pa)]";
  parameter Real Ts_ctrl = 1.0 / 80.0
    "Controller/communication sample period [s] — 80 Hz specified";

  // ==================== Disturbance parameters ====================
  parameter Real F_load = 50.0
    "External load disturbance magnitude [N] (specified)";
  parameter Real t_scenario = 8.0 "Total scenario duration [s] (specified)";
  parameter Real t_dist_start = t_scenario / 3.0
    "Disturbance start time [s] — middle third of scenario";
  parameter Real t_dist_end = 2.0 * t_scenario / 3.0
    "Disturbance end time [s] — middle third of scenario";

  // ==================== State variables ====================
  Real x(start = 0.0, fixed = true) "Actuator position [m]";
  Real v(start = 0.0, fixed = true) "Actuator velocity [m/s]";
  Real p_a(start = p_return, fixed = true) "Chamber A pressure [Pa]";
  Real p_b(start = p_return, fixed = true) "Chamber B pressure [Pa]";
  Real error_int(start = 0.0, fixed = true) "Integral of position error [m*s]";

  // ==================== Computed / sensor variables ====================
  Real omega_motor "Motor angular velocity [rad/s]";
  Real T_motor "Motor torque at motor shaft [N*m]";
  Real dP "Pressure differential p_a - p_b [Pa]";
  Real V_a "Chamber A volume [m3]";
  Real V_b "Chamber B volume [m3]";
  Real Q_cmd "Unlimited valve command [m3/s]";
  Real Q_cmd_limited "Limited (actual) valve command [m3/s]";
  Real pos_error "Position error x_target - x [m]";
  Real F_stop "End stop reaction force [N]";
  Real F_disturbance "External disturbance force [N]";
  Real F_motor_lin "Motor force at table output [N]";
  Real p_supply_margin "Supply pressure margin [Pa]";
  Boolean saturated "Valve command saturation flag";

equation
  // --- Motor kinematics ---
  // Table linear position x [m] relates to angle via r_table
  // Motor speed = gearbox ratio * table angular speed
  omega_motor = n_gear * v / r_table;

  // --- Chamber volumes (limited-travel rotary actuator model) ---
  V_a = V_dead + D_motor * n_gear * x / r_table;
  V_b = V_dead + D_motor * n_gear * (L_max - x) / r_table;

  // --- Pressure differential ---
  dP = p_a - p_b;

  // --- Motor torque (mechanical efficiency assumed 1.0 — not specified) ---
  T_motor = D_motor * dP;

  // --- Motor force at table output (through gearbox and radius) ---
  F_motor_lin = T_motor * n_gear / r_table;

  // --- Mechanical dynamics ---
  der(x) = v;
  m_eff * der(v) = F_motor_lin - F_stop - F_disturbance;

  // --- End stops: stiff spring-damper outside travel range ---
  F_stop = if x < 0.0 then (-k_stop * x - b_stop * v) else
           if x > L_max then (-k_stop * (x - L_max) - b_stop * v) else 0.0;

  // --- External load disturbance (middle third of 8 s scenario) ---
  F_disturbance = if time >= t_dist_start and time <= t_dist_end then F_load else 0.0;

  // --- Pressure dynamics with fluid compressibility ---
  // Motor flow consumption includes volumetric efficiency (internal leakage via eta_v)
  // Additional cross-port leakage: C_leak * dP
  V_a * der(p_a) = beta * (Q_cmd_limited - D_motor * omega_motor / eta_v - C_leak * dP);
  V_b * der(p_b) = beta * (-Q_cmd_limited + D_motor * omega_motor / eta_v + C_leak * dP);

  // --- Supply pressure margin (monitoring) ---
  p_supply_margin = p_supply - max(p_a, p_b);

  // --- Pressure-aware PID position controller ---
  pos_error = x_target - x;

  // PID with pressure feedback damping
  // Derivative term uses -v directly (no numerical differentiation)
  Q_cmd = Kp * pos_error + Ki * error_int + Kd * (-v) - K_press * dP;

  // --- Valve saturation with magnitude limit ---
  saturated = (Q_cmd > Q_max) or (Q_cmd < -Q_max);
  Q_cmd_limited = if Q_cmd > Q_max then Q_max else
                  if Q_cmd < -Q_max then -Q_max else Q_cmd;

  // --- Anti-windup: freeze integral when valve is saturated ---
  der(error_int) = if saturated then 0.0 else pos_error;

  // Requirement bounds (informational; enforced by controller tuning):
  //   Travel:      0 <= x <= L_max
  //   Valve:       |Q_cmd_limited| <= 0.001 m3/s
  //   Pressure:    p_return <= p_a, p_b <= p_supply (physical; not hard-limited in model)
  //   Velocity:    bounded by valve flow limit and motor displacement
  //   Final pos:   x(8.0) approx x_target = 0.7 m
  //   Tracking:    |pos_error| < 0.016 m for t > 5.2 s
  //   No NaN or infinite physical, control, or estimator values

end HydMotorPositionA;