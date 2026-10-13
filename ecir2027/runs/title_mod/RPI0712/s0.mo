model AirStageTrackD
  "Instrumented fluid-power robotic actuator: vertical pneumatic stage with two-segment trajectory tracking"

  import Modelica.Constants.pi;

  // === Cylinder and plant parameters ===
  parameter Real m_carriage = 42.0 "Carriage mass [kg]";
  parameter Real L_stroke = 0.70 "Stroke length [m]";
  parameter Real A_A = 1.9635e-3 "Cap-end (blind) area [m2]";
  parameter Real A_B = 1.6493e-3 "Rod-end area [m2]";
  parameter Real V_A0 = 5.0e-6 "Cap-end dead volume [m3]";
  parameter Real V_B0 = 5.0e-6 "Rod-end dead volume [m3]";
  parameter Real P_supply = 6.0e5 "Supply pressure [Pa]";
  parameter Real P_atm = 1.0e5 "Atmospheric / exhaust pressure [Pa]";
  parameter Real P_relief = 8.0e5 "Relief valve cracking pressure [Pa]";
  parameter Real R_gas = 287.05 "Specific gas constant for air [J/(kg.K)]";
  parameter Real T_gas = 293.15 "Gas temperature (isothermal) [K]";
  parameter Real b_visc = 500.0 "Viscous friction coefficient [N.s/m]";
  parameter Real C_leak = 1.0e-10 "Inter-chamber leakage conductance [kg/(s.Pa)]";
  parameter Real C_relief = 5.0e-9 "Relief valve conductance [kg/(s.Pa)]";
  parameter Real g_grav = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real m_dot_max = 0.015 "Proportional valve flow limit [kg/s]";

  // === Disturbance parameters ===
  parameter Real F_dist = 220.0 "Payload step disturbance magnitude [N]";
  parameter Real t_dist_start = 14.0 / 3.0 "Disturbance start (middle third) [s]";
  parameter Real t_dist_end = 28.0 / 3.0 "Disturbance end (middle third) [s]";

  // === Control parameters (cascaded: position -> pressure -> flow) ===
  parameter Real Kp_pres_pos = 5.0e6 "Position error to pressure correction gain [Pa/m]";
  parameter Real Kp_flow_A = 5.0e-8 "Pressure A error to mass flow gain [kg/(s.Pa)]";
  parameter Real Kp_flow_B = 5.0e-8 "Pressure B error to mass flow gain [kg/(s.Pa)]";
  parameter Real P_nom = 3.5e5 "Nominal operating pressure [Pa]";

  // === Simulation parameters ===
  parameter Real dt_sample = 1.0 / 200.0 "Control / output sample period [s]";
  parameter Real t_end = 14.0 "Total run time [s]";

  // === Dynamic states ===
  Real x(start = 0.0, fixed = true) "Carriage position [m]";
  Real v(start = 0.0, fixed = true) "Carriage velocity [m/s]";
  Real P_A(start = 294200.0, fixed = true) "Cap-end chamber pressure [Pa]";
  Real P_B(start = 100000.0, fixed = true) "Rod-end chamber pressure [Pa]";

  // === Derived volumes ===
  Real V_A "Cap-end volume [m3]";
  Real V_B "Rod-end volume [m3]";

  // === Trajectory reference ===
  Real x_ref "Reference position [m]";
  Real v_ref "Reference velocity [m/s]";
  Real a_ref "Reference acceleration [m/s2]";
  Real j_ref "Reference jerk [m/s3]";
  Real F_req "Required force from trajectory [N]";
  Real P_A_ref "Reference cap-end pressure [Pa]";
  Real P_B_ref "Reference rod-end pressure [Pa]";
  Real der_P_A_ref "Reference cap-end pressure rate [Pa/s]";
  Real der_P_B_ref "Reference rod-end pressure rate [Pa/s]";

  // === Control signals ===
  Real P_A_des "Desired cap-end pressure with feedback [Pa]";
  Real P_B_des "Desired rod-end pressure with feedback [Pa]";
  Real e_pos "Position error [m]";
  Real e_PA "Cap-end pressure error [Pa]";
  Real e_PB "Rod-end pressure error [Pa]";
  Real m_dot_ff_A "Feedforward mass flow chamber A [kg/s]";
  Real m_dot_ff_B "Feedforward mass flow chamber B [kg/s]";
  Real m_dot_cmd_A "Commanded net mass flow A [kg/s]";
  Real m_dot_cmd_B "Commanded net mass flow B [kg/s]";
  Real u_A_fill "Fill valve A command [0..1]";
  Real u_A_exh "Exhaust valve A command [0..1]";
  Real u_B_fill "Fill valve B command [0..1]";
  Real u_B_exh "Exhaust valve B command [0..1]";

  // === Mass flows ===
  Real m_dot_A_fill "Cap-end fill valve flow [kg/s]";
  Real m_dot_A_exh "Cap-end exhaust valve flow [kg/s]";
  Real m_dot_B_fill "Rod-end fill valve flow [kg/s]";
  Real m_dot_B_exh "Rod-end exhaust valve flow [kg/s]";
  Real m_dot_relief_A "Cap-end relief valve flow [kg/s]";
  Real m_dot_relief_B "Rod-end relief valve flow [kg/s]";
  Real m_dot_leak "Inter-chamber leakage (A to B) [kg/s]";
  Real m_dot_A_net "Net mass flow into cap end [kg/s]";
  Real m_dot_B_net "Net mass flow into rod end [kg/s]";
  Real m_dot_supply "Total supply flow [kg/s]";

  // === Forces and dynamics ===
  Real F_pneu "Pneumatic force [N]";
  Real F_friction "Viscous friction force [N]";
  Real F_gravity "Gravity force [N]";
  Real F_disturbance "Payload disturbance force [N]";
  Real F_endstop "End-stop force [N]";
  Real a "Carriage acceleration [m/s2]";

  // === Sensor traces ===
  Real x_meas "Measured position [m]";
  Real v_meas "Measured velocity [m/s]";
  Real P_A_meas "Measured cap-end pressure [Pa]";
  Real P_B_meas "Measured rod-end pressure [Pa]";
  Real m_dot_meas "Measured supply flow [kg/s]";
  Real cmd_meas "Measured position command [m]";
  Real a_meas "Measured acceleration [m/s2]";

  // === Error and bound traces ===
  Real e_traj "Trajectory error [m]";
  Boolean travel_ok "Travel bound satisfied";
  Boolean pressure_ok "Pressure bounds satisfied";
  Boolean flow_ok "Valve flow bounds satisfied";
  Boolean e_traj_ok "Trajectory error bound satisfied after 9.1 s";
  Boolean relief_ok "Relief valve inactive (pressure below relief)";

equation
  // --- Chamber volumes ---
  V_A = V_A0 + A_A * x;
  V_B = V_B0 + A_B * (L_stroke - x);

  // --- Two-segment smooth trajectory (cosine smoothstep: 0 -> 0.35 -> 0.70 m) ---
  if time <= 7.0 then
    x_ref = 0.35 * 0.5 * (1.0 - cos(pi * time / 7.0));
    v_ref = 0.35 * 0.5 * sin(pi * time / 7.0) * pi / 7.0;
    a_ref = 0.35 * 0.5 * cos(pi * time / 7.0) * (pi / 7.0) ^ 2;
    j_ref = -0.35 * 0.5 * sin(pi * time / 7.0) * (pi / 7.0) ^ 3;
  else
    x_ref = 0.35 + 0.35 * 0.5 * (1.0 - cos(pi * (time - 7.0) / 7.0));
    v_ref = 0.35 * 0.5 * sin(pi * (time - 7.0) / 7.0) * pi / 7.0;
    a_ref = 0.35 * 0.5 * cos(pi * (time - 7.0) / 7.0) * (pi / 7.0) ^ 2;
    j_ref = -0.35 * 0.5 * sin(pi * (time - 7.0) / 7.0) * (pi / 7.0) ^ 3;
  end if;

  // --- Required force and reference pressures (feedforward, excludes disturbance) ---
  F_req = m_carriage * a_ref + b_visc * v_ref + m_carriage * g_grav;
  P_A_ref = (F_req + 2.0 * P_nom * A_B) / (A_A + A_B);
  P_B_ref = (2.0 * P_nom * A_A - F_req) / (A_A + A_B);
  der_P_A_ref = (m_carriage * j_ref + b_visc * a_ref) / (A_A + A_B);
  der_P_B_ref = -(m_carriage * j_ref + b_visc * a_ref) / (A_A + A_B);

  // --- Cascaded feedback: position error -> pressure correction ---
  e_pos = x_ref - x;
  P_A_des = P_A_ref + Kp_pres_pos * e_pos;
  P_B_des = P_B_ref - Kp_pres_pos * e_pos;

  // --- Pressure errors ---
  e_PA = P_A_des - P_A;
  e_PB = P_B_des - P_B;

  // --- Feedforward mass flow (isothermal ideal gas: P*V = m*R*T) ---
  m_dot_ff_A = (V_A * der_P_A_ref + P_A_ref * A_A * v_ref) / (R_gas * T_gas);
  m_dot_ff_B = (-P_B_ref * A_B * v_ref + V_B * der_P_B_ref) / (R_gas * T_gas);

  // --- Mass flow commands: feedforward + pressure feedback ---
  m_dot_cmd_A = m_dot_ff_A + Kp_flow_A * e_PA;
  m_dot_cmd_B = m_dot_ff_B + Kp_flow_B * e_PB;

  // --- Valve command saturation [0..1] ---
  u_A_fill = if m_dot_cmd_A > m_dot_max then 1.0 else if m_dot_cmd_A > 0.0 then m_dot_cmd_A / m_dot_max else 0.0;
  u_A_exh = if m_dot_cmd_A < -m_dot_max then 1.0 else if m_dot_cmd_A < 0.0 then -m_dot_cmd_A / m_dot_max else 0.0;
  u_B_fill = if m_dot_cmd_B > m_dot_max then 1.0 else if m_dot_cmd_B > 0.0 then m_dot_cmd_B / m_dot_max else 0.0;
  u_B_exh = if m_dot_cmd_B < -m_dot_max then 1.0 else if m_dot_cmd_B < 0.0 then -m_dot_cmd_B / m_dot_max else 0.0;

  // --- Valve flows (proportional, limited to m_dot_max) ---
  m_dot_A_fill = m_dot_max * u_A_fill;
  m_dot_A_exh = m_dot_max * u_A_exh;
  m_dot_B_fill = m_dot_max * u_B_fill;
  m_dot_B_exh = m_dot_max * u_B_exh;

  // --- Relief valves (crack at P_relief) ---
  m_dot_relief_A = if P_A > P_relief then C_relief * (P_A - P_relief) else 0.0;
  m_dot_relief_B = if P_B > P_relief then C_relief * (P_B - P_relief) else 0.0;

  // --- Inter-chamber leakage ---
  m_dot_leak = C_leak * (P_A - P_B);

  // --- Net mass flows into chambers ---
  m_dot_A_net = m_dot_A_fill - m_dot_A_exh - m_dot_relief_A - m_dot_leak;
  m_dot_B_net = m_dot_B_fill - m_dot_B_exh - m_dot_relief_B + m_dot_leak;

  // --- Total supply flow ---
  m_dot_supply = m_dot_A_fill + m_dot_B_fill;

  // --- Pressure dynamics (isothermal: dP/dt = (R*T*mdot_net - P*dV/dt) / V) ---
  der(P_A) = (R_gas * T_gas * m_dot_A_net - P_A * A_A * v) / V_A;
  der(P_B) = (R_gas * T_gas * m_dot_B_net + P_B * A_B * v) / V_B;

  // --- Forces ---
  F_pneu = P_A * A_A - P_B * A_B;
  F_gravity = -m_carriage * g_grav;
  F_friction = -b_visc * v;
  F_disturbance = if time >= t_dist_start and time <= t_dist_end then -F_dist else 0.0;
  F_endstop = if x < 0.0 then 1.0e7 * (0.0 - x) - 1.0e4 * v
              else if x > L_stroke then -1.0e7 * (x - L_stroke) - 1.0e4 * v
              else 0.0;

  // --- Newton's second law ---
  a = (F_pneu + F_gravity + F_friction + F_disturbance + F_endstop) / m_carriage;
  der(x) = v;
  der(v) = a;

  // --- Sensors (direct measurement, no noise) ---
  x_meas = x;
  v_meas = v;
  P_A_meas = P_A;
  P_B_meas = P_B;
  m_dot_meas = m_dot_supply;
  cmd_meas = x_ref;
  a_meas = a;

  // --- Trajectory error ---
  e_traj = x - x_ref;

  // --- Bound checks ---
  travel_ok = x >= -0.001 and x <= L_stroke + 0.001;
  pressure_ok = P_A >= 0.0 and P_A <= P_relief and P_B >= 0.0 and P_B <= P_relief;
  flow_ok = m_dot_A_fill <= m_dot_max + 1.0e-9 and m_dot_B_fill <= m_dot_max + 1.0e-9
            and m_dot_A_exh <= m_dot_max + 1.0e-9 and m_dot_B_exh <= m_dot_max + 1.0e-9;
  e_traj_ok = if time >= 9.1 then abs(e_traj) <= 0.018 else true;
  relief_ok = P_A <= P_relief and P_B <= P_relief;

  annotation(
    experiment(StartTime = 0.0, StopTime = 14.0, Tolerance = 1.0e-6, Interval = 0.005),
    Documentation(info = "AirStageTrackD: 42 kg vertical pneumatic actuator tracking a two-segment
    smooth trajectory over 0.70 m stroke with 220 N payload disturbance during middle third.
    Double-acting cylinder with unequal areas (A_A > A_B), explicit dead volumes, viscous friction,
    inter-chamber leakage, and relief valves. Independent fill/exhaust proportional valves per chamber
    limited to 0.015 kg/s. Feedforward flow control with cascaded pressure-position feedback.
    Run at 200 Hz (5 ms interval) for 14 s. Steady-state tracking error under 220 N disturbance
    is approximately 0.012 m, satisfying the 0.018 m requirement after 9.1 s.
    Cylinder dimensions, dead volumes, supply pressure, friction and leakage coefficients are
    reasonable engineering assumptions for an unstated pneumatic actuator specification."));
end AirStageTrackD;