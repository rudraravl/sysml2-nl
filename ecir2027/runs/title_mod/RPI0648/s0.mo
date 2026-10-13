model HydMotorConserveF
  "Hydraulic motor driving a rotary table through a 12:1 gearbox with
   energy-aware motion control, valve saturation, compressibility,
   thermal effects, and a middle-third load disturbance. All unspecified
   numerical assumptions are labeled (assumed)."

  // ---- Motor displacement and efficiency (given) ----
  parameter Real D_m(unit = "m3/rev") = 48e-6 "Motor displacement per revolution";
  parameter Real eta_v(final min = 0, final max = 1) = 0.92 "Volumetric efficiency";
  parameter Real eta_m(final min = 0, final max = 1) = 0.92
    "Mechanical efficiency (assumed equal to volumetric efficiency)";
  parameter Real n_gear(final min = 1) = 12.0 "Gearbox ratio motor:table";
  parameter Real eta_gear(final min = 0, final max = 1) = 0.95
    "Gearbox mechanical efficiency (assumed)";

  // ---- Mechanical load (given) ----
  parameter Real m_table(unit = "kg") = 130.0 "Table mass";
  parameter Real r_eff(unit = "m") = 0.10
    "Effective radius for linear-equivalent position (assumed)";
  parameter Real J_table(unit = "kg.m2") = 0.5 * m_table * r_eff * r_eff
    "Table moment of inertia about rotation axis";
  parameter Real b_fric(unit = "N.m.s/rad") = 0.5
    "Viscous friction coefficient (assumed)";

  // ---- Hydraulic supply / return / valve (given bounds, assumed values) ----
  parameter Real p_supply(unit = "Pa") = 21.0e6 "Supply pressure (assumed)";
  parameter Real p_return(unit = "Pa") = 0.5e6 "Return pressure (assumed)";
  parameter Real Q_max(unit = "m3/s") = 0.002 "Max valve flow (given bound)";
  parameter Real Beta_e(unit = "Pa") = 1.4e9 "Effective fluid bulk modulus (assumed)";
  parameter Real V_line(unit = "m3") = 1.0e-4 "Line volume per side (assumed)";

  // ---- Disturbance (given) ----
  parameter Real F_dist(unit = "N") = 261.0 "Load disturbance force magnitude";
  parameter Real t_dist_start(unit = "s") = 20.0 / 3.0 "Disturbance start (middle third)";
  parameter Real t_dist_end(unit = "s") = 40.0 / 3.0 "Disturbance end (middle third)";

  // ---- Reference cycle (assumed) ----
  parameter Real f_cycle(unit = "Hz") = 0.1 "Cycle frequency -> 2 full cycles in 20 s";
  parameter Real A_ref(unit = "m") = 0.05 "Linear-equivalent reference amplitude";

  // ---- Energy-aware control (assumed gains) ----
  parameter Real Kp(unit = "m3/(s.m)") = 0.05 "Proportional gain (assumed)";
  parameter Real Kd(unit = "m3/(s2.m)") = 0.002 "Derivative gain (assumed)";
  parameter Real Ki(unit = "m3/(s2.m)") = 0.5 "Integral gain (assumed)";
  parameter Real k_eng_min(final min = 0, final max = 1) = 0.3
    "Minimum control gain factor under energy saturation (bounded degradation)";
  parameter Real E_cap(unit = "J") = 50.0e3 "Declared energy-use cap (assumed)";

  // ---- Observer (assumed) ----
  parameter Real L_obs(unit = "1/s") = 20.0 "Observer bandwidth (assumed)";

  // ---- Thermal (assumed) ----
  parameter Real c_thermal(unit = "J/K") = 2000.0 "Oil lump heat capacity (assumed)";
  parameter Real h_thermal(unit = "W/K") = 5.0 "Heat-loss coefficient (assumed)";
  parameter Real T_amb(unit = "K") = 293.15 "Ambient temperature (assumed)";

  // ---- Dynamic states ----
  Real theta_table(unit = "rad") "Table angular position";
  Real w_table(unit = "rad/s") "Table angular velocity";
  Real p_a(unit = "Pa") "Pressure at motor port A";
  Real p_b(unit = "Pa") "Pressure at motor port B";
  Real E_acc(unit = "J") "Accumulated hydraulic energy drawn from supply";
  Real T_oil(unit = "K") "Oil lump temperature";
  Real integ_e(unit = "m.s") "Integral of tracking error (anti-windup)";
  Real w_hat(unit = "rad/s") "Observer estimate of table angular velocity";
  Real T_dist_hat(unit = "N.m") "Observer estimate of disturbance torque";

  // ---- Computed / sensor signals ----
  Real w_m(unit = "rad/s") "Motor angular velocity";
  Real theta_m(unit = "rad") "Motor angular position";
  Real dp_motor(unit = "Pa") "Motor differential pressure p_a - p_b";
  Real T_m(unit = "N.m") "Motor output torque";
  Real T_table(unit = "N.m") "Torque delivered to table through gearbox";
  Real Q_a_motor(unit = "m3/s") "Flow into motor at port A";
  Real Q_b_motor(unit = "m3/s") "Flow out of motor at port B";
  Real u_cmd "Normalized valve command in [-1, 1]";
  Real Q_cmd(unit = "m3/s") "Unsaturated commanded valve flow";
  Real Q_to_A(unit = "m3/s") "Valve flow into port-A line";
  Real Q_from_B(unit = "m3/s") "Valve flow out of port-B line to return";
  Real Q_supply(unit = "m3/s") "Flow drawn from supply";
  Real P_hyd(unit = "W") "Hydraulic power drawn from supply";
  Real P_loss(unit = "W") "Hydraulic power loss (heat generation)";
  Real y_ref(unit = "m") "Linear-equivalent reference position";
  Real y(unit = "m") "Linear-equivalent table position";
  Real e_track(unit = "m") "Tracking error (reference - actual)";
  Real de(unit = "m/s") "Time derivative of tracking error";
  Real k_eng "Energy-aware gain factor (bounded in [k_eng_min, 1])";
  Real T_dist_load(unit = "N.m") "Disturbance torque applied to table";

initial equation
  theta_table = 0.0;
  w_table = 0.0;
  p_a = p_return;
  p_b = p_return;
  E_acc = 0.0;
  T_oil = T_amb;
  integ_e = 0.0;
  w_hat = 0.0;
  T_dist_hat = 0.0;

equation
  // Reference cycle and linear-equivalent position
  y_ref = A_ref * (1.0 - cos(2.0 * Modelica.Constants.pi * f_cycle * time)) / 2.0;
  y = r_eff * theta_table;
  e_track = y_ref - y;
  de = A_ref * Modelica.Constants.pi * f_cycle *
       sin(2.0 * Modelica.Constants.pi * f_cycle * time) - r_eff * w_table;

  // Energy-aware bounded gain degradation (smooth ramp over [0.7*E_cap, E_cap])
  k_eng = 1.0 - (1.0 - k_eng_min) *
        max(0.0, min(1.0, (E_acc - 0.7 * E_cap) / (0.3 * E_cap)));

  // Disturbance torque (middle third), smooth-sign to oppose motion
  T_dist_load = if (time >= t_dist_start and time <= t_dist_end)
                then F_dist * r_eff * Modelica.Math.tanh(w_table / 0.01)
                else 0.0;

  // Valve command (PI+D with energy-aware gain factor), saturated
  Q_cmd = k_eng * (Kp * e_track + Kd * de + Ki * integ_e);
  u_cmd = max(-1.0, min(1.0, Q_cmd / Q_max));

  // Pressure-compensated proportional valve: u>0 -> supply->A, B->return
  Q_to_A = u_cmd * Q_max;
  Q_from_B = u_cmd * Q_max;
  Q_supply = abs(u_cmd) * Q_max;

  // Motor kinematics
  w_m = n_gear * w_table;
  theta_m = n_gear * theta_table;
  dp_motor = p_a - p_b;

  // Motor flows (volumetric efficiency)
  Q_a_motor = D_m * w_m / eta_v;
  Q_b_motor = D_m * w_m / eta_v;

  // Motor torque and gearbox transmission
  T_m = D_m * dp_motor * eta_m;
  T_table = T_m * n_gear * eta_gear;

  // Line pressure dynamics (fluid compressibility)
  der(p_a) = (Beta_e / V_line) * (Q_to_A - Q_a_motor);
  der(p_b) = (Beta_e / V_line) * (Q_b_motor - Q_from_B);

  // Table mechanical dynamics
  J_table * der(w_table) = T_table - b_fric * w_table - T_dist_load;
  der(theta_table) = w_table;

  // Accumulated supply energy
  P_hyd = p_supply * Q_supply;
  der(E_acc) = P_hyd;

  // Thermal lump: hydraulic losses converted to heat
  P_loss = max(0.0, p_supply * Q_supply - T_m * w_m);
  c_thermal * der(T_oil) = P_loss - h_thermal * (T_oil - T_amb);

  // Integral action with anti-windup (freeze when valve saturated)
  der(integ_e) = if (abs(u_cmd) < 0.999) then e_track else 0.0;

  // Disturbance-torque observer (Luenberger-type, well-defined gains)
  J_table * der(w_hat) = T_table - b_fric * w_hat - T_dist_hat
                         + L_obs * J_table * (w_table - w_hat);
  der(T_dist_hat) = L_obs * J_table * (w_table - w_hat);

end HydMotorConserveF;