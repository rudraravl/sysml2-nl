model HydCylinderConserveB
  "Fluid-power robotic actuator: energy-aware motion control with bounded degradation"

  // --- Piston geometry ---
  parameter Modelica.Units.SI.Area A_piston = 0.0040 "Piston (cap) side area";
  parameter Modelica.Units.SI.Area A_rod = 0.0032 "Rod side annular area";
  parameter Modelica.Units.SI.Length L_stroke = 0.50 "Cylinder stroke";
  parameter Modelica.Units.SI.Length L_dead_a = 0.02 "Dead volume cap side length equiv";
  parameter Modelica.Units.SI.Length L_dead_b = 0.02 "Dead volume rod side length equiv";
  parameter Modelica.Units.SI.Mass m_load = 110.0 "Moving mass";
  parameter Modelica.Units.SI.Pressure p_supply = 20.0e5 "Supply pressure";
  parameter Modelica.Units.SI.Pressure p_tank = 5.0e5 "Return/tank pressure";
  parameter Modelica.Units.SI.VolumeFlowRate Q_cmd_max = 0.001 "Allowed command magnitude";
  parameter Modelica.Units.SI.BulkModulus beta_eff = 1.6e9 "Effective fluid bulk modulus";
  parameter Real b_visc = 5000.0 "Viscous friction coefficient N.s/m";
  parameter Modelica.Units.SI.Force F_coulomb = 50.0 "Coulomb friction magnitude";
  parameter Modelica.Units.SI.Force F_disturb = 126.0 "Disturbance load variation";
  parameter Modelica.Units.SI.Length x0 = 0.05 "Initial piston position";
  parameter Modelica.Units.SI.Velocity v0 = 0.0 "Initial piston velocity";

  // --- Controller gains ---
  parameter Real Kp = 12000.0 "Position gain N/m";
  parameter Real Kd = 350.0 "Velocity gain N.s/m";
  parameter Real Ke = 0.0008 "Energy penalty gain (conservation term)";
  parameter Modelica.Units.SI.Energy E_cap = 900.0 "Declared energy-use cap";
  parameter Modelica.Units.SI.Time t_start_dist = 10.0 / 3.0 "Middle-third start";
  parameter Modelica.Units.SI.Time t_end_dist = 2.0 * 10.0 / 3.0 "Middle-third end";
  parameter Modelica.Units.SI.Time t_final = 10.0 "Mission duration";
  parameter Modelica.Units.SI.Length eps_track = 0.024 "Tracking requirement after 6.5 s";

  // --- Cycle reference ---
  parameter Modelica.Units.SI.Length x_ref_low = 0.05;
  parameter Modelica.Units.SI.Length x_ref_high = 0.45;
  parameter Modelica.Units.SI.Time t_cycle = 2.5 "Cycle period";

  // --- Orifice ---
  parameter Real Cq = 0.7 "Discharge coefficient";
  parameter Modelica.Units.SI.Density rho_oil = 850.0 "Oil density";

  // --- State variables ---
  Modelica.Units.SI.Length x "Piston position (cap end at 0)";
  Modelica.Units.SI.Velocity v "Piston velocity";
  Modelica.Units.SI.Pressure p_a "Cap-side chamber pressure";
  Modelica.Units.SI.Pressure p_b "Rod-side chamber pressure";
  Modelica.Units.SI.VolumeFlowRate Q_a "Flow into cap side from valve";
  Modelica.Units.SI.VolumeFlowRate Q_b "Flow out of rod side to valve";
  Modelica.Units.SI.VolumeFlowRate Q_supply "Supply flow through valve";
  Modelica.Units.SI.Force F_act "Net actuator force";
  Modelica.Units.SI.Force F_load "Total external load";
  Modelica.Units.SI.Energy E_acc "Accumulated hydraulic energy";
  Modelica.Units.SI.Power P_hyd "Instantaneous hydraulic power";
  Modelica.Units.SI.Force F_dist "Active disturbance";

  // --- Valve command ---
  Modelica.Units.SI.VolumeFlowRate u_cmd "Raw controller command";
  Modelica.Units.SI.VolumeFlowRate u_sat "Saturated valve command";
  Real u_norm "Normalized valve spool position [-1,1]";

  // --- Reference and tracking ---
  Modelica.Units.SI.Length x_ref "Reference position";
  Modelica.Units.SI.Length track_err "Tracking error";
  Boolean track_ok "Tracking requirement satisfied after 6.5 s";

  // --- Chamber volumes ---
  Modelica.Units.SI.Volume V_a "Cap-side volume";
  Modelica.Units.SI.Volume V_b "Rod-side volume";

  // --- Energy cap flag ---
  Boolean energy_ok "Energy cap respected";

  // --- Bounded degradation factor ---
  Real degradation "Bounded performance degradation factor [0.3,1]";

  // --- Safe sqrt argument holders ---
  Real dp_sa "Supply to cap pressure diff";
  Real dp_at "Cap to tank pressure diff";
  Real dp_bt "Rod to tank pressure diff";
  Real dp_sb "Supply to rod pressure diff";

function sat
  input Real x_in;
  input Real x_min;
  input Real x_max;
  output Real y;
algorithm
  if x_in > x_max then
    y := x_max;
  elseif x_in < x_min then
    y := x_min;
  else
    y := x_in;
  end if;
end sat;

function safeSqrt
  input Real x_in;
  output Real y;
algorithm
  if x_in <= 1.0e-6 then
    y := 0.0;
  else
    y := sqrt(x_in);
  end if;
end safeSqrt;

equation
  // --- Chamber volumes ---
  V_a = A_piston * (x + L_dead_a);
  V_b = A_rod * (L_stroke - x + L_dead_b);

  // --- Normalized valve command ---
  u_norm = u_sat / Q_cmd_max;

  // --- Pressure differentials for orifice ---
  dp_sa = p_supply - p_a;
  dp_at = p_a - p_tank;
  dp_bt = p_b - p_tank;
  dp_sb = p_supply - p_b;

  // --- Orifice flow through four-way proportional valve ---
  // Positive u_norm => extend: supply to cap, rod to tank
  // Negative u_norm => retract: cap to tank, supply to rod
  if u_norm >= 0.0 then
    Q_a = Cq * A_piston * safeSqrt(2.0 / rho_oil) * safeSqrt(dp_sa) * u_norm;
    Q_b = Cq * A_rod * safeSqrt(2.0 / rho_oil) * safeSqrt(dp_bt) * u_norm;
    Q_supply = Cq * A_piston * safeSqrt(2.0 / rho_oil) * safeSqrt(dp_sa) * u_norm;
  else
    Q_a = -Cq * A_piston * safeSqrt(2.0 / rho_oil) * safeSqrt(dp_at) * (-u_norm);
    Q_b = -Cq * A_rod * safeSqrt(2.0 / rho_oil) * safeSqrt(dp_sb) * (-u_norm);
    Q_supply = Cq * A_rod * safeSqrt(2.0 / rho_oil) * safeSqrt(dp_sb) * (-u_norm);
  end if;

  // --- Chamber pressure dynamics (compressibility) ---
  der(p_a) = (beta_eff / V_a) * (Q_a - A_piston * v);
  der(p_b) = (beta_eff / V_b) * (A_rod * v - Q_b);

  // --- Mechanical dynamics ---
  F_act = p_a * A_piston - p_b * A_rod;
  F_dist = if (time >= t_start_dist) and (time <= t_end_dist) then F_disturb else 0.0;
  F_load = F_dist;
  m_load * der(v) = F_act - b_visc * v - F_coulomb * tanh(v / 0.01) - F_load;
  der(x) = v;

  // --- Bounded performance degradation ---
  degradation = sat(1.0 - Ke * E_acc, 0.3, 1.0);

  // --- Reference trajectory: square wave cycle ---
  x_ref = if mod(time, t_cycle) < t_cycle / 2.0 then x_ref_high else x_ref_low;

  // --- Energy-aware PD control ---
  track_err = x_ref - x;
  u_cmd = (Kp * track_err + Kd * (-v)) * degradation;

  // --- Valve saturation ---
  u_sat = sat(u_cmd, -Q_cmd_max, Q_cmd_max);

  // --- Hydraulic power and accumulated energy ---
  P_hyd = p_supply * Q_supply;
  der(E_acc) = max(0.0, P_hyd);

  // --- Diagnostics ---
  track_ok = (time < 6.5) or (abs(track_err) < eps_track);
  energy_ok = (E_acc <= E_cap);

  // --- Physical bounds assertions ---
  assert(x >= -0.001 and x <= L_stroke + 0.001, "Piston position out of bounds");
  assert(p_a > 0.0 and p_a < 5.0e7, "Cap pressure out of physical range");
  assert(p_b > 0.0 and p_b < 5.0e7, "Rod pressure out of physical range");
  assert(energy_ok, "Energy cap exceeded");

initial equation
  x = x0;
  v = v0;
  p_a = p_tank + (p_supply - p_tank) * 0.5;
  p_b = p_tank + (p_supply - p_tank) * 0.5;
  E_acc = 0.0;

  annotation(
    experiment(StartTime = 0, StopTime = 10, Tolerance = 1e-5, Interval = 0.01),
    Documentation(info = "Hydraulic double-acting cylinder with compressible chambers, four-way proportional valve with saturation, energy-aware motion control with bounded degradation, 126 N disturbance during middle third of mission. Runs at 100 Hz for 10 s. Energy cap declared at E_cap. Tracking error required below 0.024 m after 6.5 s."),
    uses(Modelica(version = "4.0.0"))
  );
end HydCylinderConserveB;