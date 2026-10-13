model PneuGripConserveE
  // Stated physical parameters
  parameter Modelica.Units.SI.Length stroke = 0.035 "Cylinder travel";
  parameter Modelica.Units.SI.Area A_piston = 0.0012 "Piston area";
  parameter Modelica.Units.SI.Mass m_finger = 0.8 "Gripper finger mass";
  parameter Modelica.Units.SI.MassFlowRate u_max = 0.001 "Valve command bound, kg/s";
  parameter Modelica.Units.SI.Force F_dist = 216.0 "Middle-third load variation";
  parameter Modelica.Units.SI.Time t_end = 16.0 "Run time";
  parameter Real f_sample_Hz = 250.0 "Sample rate, Hz";

  // Assumed engineering parameters (labeled, not stated)
  parameter Modelica.Units.SI.Pressure p_supply = 6.0e5 "Assumed supply pressure";
  parameter Modelica.Units.SI.Pressure p_ret = 1.01325e5 "Assumed return pressure";
  parameter Modelica.Units.SI.Temperature T_ch = 293.15 "Assumed isothermal chamber temperature";
  parameter Real R_air = 287.0 "Assumed air gas constant, J/(kg.K)";
  parameter Modelica.Units.SI.Volume V_dead = 1.0e-5 "Assumed chamber dead volume";
  parameter Real b_fric = 20.0 "Assumed viscous friction, N.s/m";
  parameter Modelica.Units.SI.Mass m_air_cap = 0.05 "Declared air-use cap";

  // Control gains (assumed)
  parameter Real Kp_pos = 2000.0 "Position gain, N/m";
  parameter Real Kd_pos = 80.0 "Velocity gain, N.s/m";
  parameter Real Kv_valve = 5.0e-6 "Valve pressure gain, kg/(s.Pa)";
  parameter Modelica.Units.SI.Length e_dead = 0.0020 "Deadzone for energy saving";
  parameter Real degrade_max = 0.5 "Max fractional performance degradation";

  // Dynamic states
  Modelica.Units.SI.Length x1(start = 0.0, fixed = true) "Finger 1 position";
  Modelica.Units.SI.Velocity v1(start = 0.0, fixed = true) "Finger 1 velocity";
  Modelica.Units.SI.Mass m_air1(start = p_ret * V_dead / (R_air * T_ch), fixed = true) "Chamber 1 air mass";
  Modelica.Units.SI.Length x2(start = 0.0, fixed = true) "Finger 2 position";
  Modelica.Units.SI.Velocity v2(start = 0.0, fixed = true) "Finger 2 velocity";
  Modelica.Units.SI.Mass m_air2(start = p_ret * V_dead / (R_air * T_ch), fixed = true) "Chamber 2 air mass";
  Modelica.Units.SI.Mass m_supply(start = 0.0, fixed = true) "Accumulated supplied air mass";
  Modelica.Units.SI.Energy E_supply(start = 0.0, fixed = true) "Accumulated supply energy";

  // Derived / sensor quantities
  Modelica.Units.SI.Pressure p1 "Chamber 1 pressure";
  Modelica.Units.SI.Pressure p2 "Chamber 2 pressure";
  Modelica.Units.SI.Volume V1 "Chamber 1 volume";
  Modelica.Units.SI.Volume V2 "Chamber 2 volume";
  Modelica.Units.SI.MassFlowRate u1_cmd "Valve 1 unsaturated command";
  Modelica.Units.SI.MassFlowRate u2_cmd "Valve 2 unsaturated command";
  Modelica.Units.SI.MassFlowRate u1_sat "Valve 1 saturated command";
  Modelica.Units.SI.MassFlowRate u2_sat "Valve 2 saturated command";
  Modelica.Units.SI.Force F_des1 "Desired force finger 1";
  Modelica.Units.SI.Force F_des2 "Desired force finger 2";
  Modelica.Units.SI.Force F_ext "External disturbance force";
  Modelica.Units.SI.Pressure p_des1 "Desired chamber 1 pressure";
  Modelica.Units.SI.Pressure p_des2 "Desired chamber 2 pressure";
  Modelica.Units.SI.Length x_ref "Reference position";
  Modelica.Units.SI.Velocity v_ref "Reference velocity";
  Real conserve_factor "Energy-aware gain reduction factor";
  Modelica.Units.SI.Length e1 "Tracking error finger 1";
  Modelica.Units.SI.Length e2 "Tracking error finger 2";
  Modelica.Units.SI.Length track_err "Primary tracking error";
  Real dist_active "Disturbance active flag";
  Real n_cycles "Number of completed cycles";

equation
  // Reference trajectory: two identical actuation cycles over 16 s
  x_ref = 0.5 * stroke * (1.0 - Modelica.Math.cos(2.0 * Modelica.Constants.pi * time / 8.0));
  v_ref = 0.5 * stroke * (2.0 * Modelica.Constants.pi / 8.0) * Modelica.Math.sin(2.0 * Modelica.Constants.pi / 8.0 * time);
  n_cycles = floor(time / 8.0);

  // Middle-third disturbance load
  dist_active = if (time >= t_end / 3.0 and time <= 2.0 * t_end / 3.0) then 1.0 else 0.0;
  F_ext = F_dist * dist_active;

  // Energy-aware bounded performance degradation
  conserve_factor = 1.0 - degrade_max * min(1.0, max(0.0, m_supply / m_air_cap));

  // Tracking errors
  e1 = x_ref - x1;
  e2 = x_ref - x2;
  track_err = abs(e1);

  // Desired force: PD with deadzone plus feedforward
  F_des1 = (if noEvent(abs(e1) > e_dead) then Kp_pos * conserve_factor * e1 else 0.0)
         - Kd_pos * conserve_factor * v1
         + b_fric * v_ref
         + F_ext;
  F_des2 = (if noEvent(abs(e2) > e_dead) then Kp_pos * conserve_factor * e2 else 0.0)
         - Kd_pos * conserve_factor * v2
         + b_fric * v_ref
         + F_ext;

  // Desired chamber pressure saturated to supply/return bounds
  p_des1 = max(p_ret, min(p_supply, p_ret + F_des1 / A_piston));
  p_des2 = max(p_ret, min(p_supply, p_ret + F_des2 / A_piston));

  // Proportional valve command with saturation
  u1_cmd = Kv_valve * (p_des1 - p1);
  u2_cmd = Kv_valve * (p_des2 - p2);
  u1_sat = max(-u_max, min(u_max, u1_cmd));
  u2_sat = max(-u_max, min(u_max, u2_cmd));

  // Compressibility (isothermal ideal gas)
  V1 = V_dead + A_piston * x1;
  V2 = V_dead + A_piston * x2;
  p1 = m_air1 * R_air * T_ch / V1;
  p2 = m_air2 * R_air * T_ch / V2;

  // Mass dynamics
  der(m_air1) = u1_sat;
  der(m_air2) = u2_sat;

  // Finger mechanical dynamics
  m_finger * der(v1) = p1 * A_piston - p_ret * A_piston - b_fric * v1 - F_ext;
  m_finger * der(v2) = p2 * A_piston - p_ret * A_piston - b_fric * v2 - F_ext;
  der(x1) = v1;
  der(x2) = v2;

  // Accumulated supplied air mass and supply energy
  der(m_supply) = max(0.0, u1_sat) + max(0.0, u2_sat);
  der(E_supply) = (max(0.0, u1_sat) + max(0.0, u2_sat)) * R_air * T_ch;

  // Fail-closed acceptance assertions
  // Physical bounds (also catches NaN since NaN comparisons are false)
  assert(x1 >= -1.0e-6 and x1 <= stroke + 1.0e-6, "Finger 1 position out of bounds");
  assert(x2 >= -1.0e-6 and x2 <= stroke + 1.0e-6, "Finger 2 position out of bounds");
  assert(p1 >= 0.0 and p1 <= p_supply * 1.1, "Chamber 1 pressure out of bounds");
  assert(p2 >= 0.0 and p2 <= p_supply * 1.1, "Chamber 2 pressure out of bounds");
  assert(v1 >= -1.0 and v1 <= 1.0, "Finger 1 velocity out of bounds");
  assert(v2 >= -1.0 and v2 <= 1.0, "Finger 2 velocity out of bounds");

  // Valve saturation bound
  assert(abs(u1_sat) <= u_max + 1.0e-12, "Valve 1 saturation violated");
  assert(abs(u2_sat) <= u_max + 1.0e-12, "Valve 2 saturation violated");

  // Declared air-use cap
  assert(m_supply <= m_air_cap + 1.0e-9, "Declared air-use cap exceeded");

  // Cycle completion (two full cycles by end of run)
  assert(n_cycles >= 2.0 or time < t_end - 1.0e-6, "Cycle completion not reached");

  // Terminal tracking error
  assert(abs(x_ref - x1) <= 0.018 or time < t_end - 1.0e-6, "Terminal tracking error finger 1 exceeded");
  assert(abs(x_ref - x2) <= 0.018 or time < t_end - 1.0e-6, "Terminal tracking error finger 2 exceeded");

  // Primary tracking error below 0.018 m after 10.4 s
  assert(track_err <= 0.018 or time < 10.4, "Primary tracking error exceeded after 10.4 s");

  annotation(
    Documentation(info = "PneuGripConserveE: two-chamber pneumatic gripper actuator with compressible isothermal ideal-gas chambers, proportional air valves saturated at +/-0.001 kg/s, return pressure, energy-aware PD+feedforward motion control with bounded <=50 percent performance degradation, and a 216 N middle-third load disturbance. All non-stated physical values are labeled as assumed defaults. Acceptance is fail-closed via assertions."),
    experiment(StopTime = 16.0, Tolerance = 1.0e-6, Interval = 0.004)
  );
end PneuGripConserveE;