model HydCylinderConserveB
  "Fluid-power robotic actuator with energy-aware motion control"

  // Piston geometry
  parameter Modelica.Units.SI.Area A_piston = 0.0040 "Piston (cap) side area";
  parameter Modelica.Units.SI.Area A_rod = 0.0032 "Rod side annular area";
  parameter Modelica.Units.SI.Length L_stroke = 0.50 "Cylinder stroke";
  parameter Modelica.Units.SI.Length L_dead = 0.05 "Dead volume length equivalent";
  parameter Modelica.Units.SI.Mass m_load = 110.0 "Moving mass";

  // Supply and return
  parameter Modelica.Units.SI.Pressure p_supply = 7.0e5 "Supply pressure";
  parameter Modelica.Units.SI.Pressure p_tank = 1.5e5 "Return/tank pressure";
  parameter Modelica.Units.SI.VolumeFlowRate Q_cmd_max = 0.001 "Allowed command magnitude";

  // Fluid properties
  parameter Modelica.Units.SI.Pressure beta_eff = 3.0e8 "Effective fluid bulk modulus";
  parameter Real b_visc(unit="N.s/m") = 2000.0 "Viscous friction coefficient";
  parameter Modelica.Units.SI.Force F_coulomb = 30.0 "Coulomb friction magnitude";
  parameter Real Cq = 0.7 "Valve discharge coefficient";
  parameter Modelica.Units.SI.Density rho_oil = 850.0 "Oil density";
  parameter Modelica.Units.SI.Area A_valve_max = 6.0e-5 "Maximum valve orifice area";

  // Disturbance
  parameter Modelica.Units.SI.Force F_disturb = 126.0 "Disturbance load variation";
  parameter Modelica.Units.SI.Time t_start_dist = 10.0/3.0 "Middle-third start";
  parameter Modelica.Units.SI.Time t_end_dist = 2.0*10.0/3.0 "Middle-third end";

  // Controller gains
  parameter Real Kp_flow(unit="m2/s") = 0.01 "Position-to-flow gain";
  parameter Real Kd_flow(unit="m2") = 0.002 "Velocity-to-flow gain";
  parameter Real Ke(unit="1/J") = 1.4e-4 "Energy penalty gain";
  parameter Modelica.Units.SI.Energy E_cap = 5000.0 "Declared energy-use cap";
  parameter Modelica.Units.SI.Length eps_track = 0.024 "Tracking requirement after 6.5 s";

  // Reference trajectory
  parameter Modelica.Units.SI.Length x_ref_min = 0.05 "Minimum reference position";
  parameter Modelica.Units.SI.Length x_ref_max = 0.45 "Maximum reference position";
  parameter Modelica.Units.SI.Time T_cycle = 5.0 "Cycle period";

  // Initial conditions
  parameter Modelica.Units.SI.Length x0 = 0.25 "Initial piston position";
  parameter Modelica.Units.SI.Velocity v0 = 0.0 "Initial piston velocity";
  parameter Modelica.Units.SI.Pressure p_a0 = 4.0e5 "Initial cap-side pressure";
  parameter Modelica.Units.SI.Pressure p_b0 = 5.0e5 "Initial rod-side pressure";

  // State variables
  Modelica.Units.SI.Length x "Piston position from cap end";
  Modelica.Units.SI.Velocity v "Piston velocity";
  Modelica.Units.SI.Pressure p_a "Cap-side chamber pressure";
  Modelica.Units.SI.Pressure p_b "Rod-side chamber pressure";
  Modelica.Units.SI.Energy E_acc "Accumulated supply hydraulic energy";

  // Computed variables
  Modelica.Units.SI.Volume V_a "Cap-side volume";
  Modelica.Units.SI.Volume V_b "Rod-side volume";
  Modelica.Units.SI.VolumeFlowRate Q_a "Flow into cap side";
  Modelica.Units.SI.VolumeFlowRate Q_b "Flow into rod side";
  Modelica.Units.SI.VolumeFlowRate Q_supply "Supply flow through valve";
  Modelica.Units.SI.VolumeFlowRate u_cmd "Raw controller flow command";
  Modelica.Units.SI.VolumeFlowRate u_sat "Saturated flow command";
  Modelica.Units.SI.Force F_act "Net actuator force";
  Modelica.Units.SI.Force F_dist "Active disturbance force";
  Modelica.Units.SI.Power P_hyd "Instantaneous supply hydraulic power";
  Real u_norm "Normalized valve spool command [-1,1]";
  Modelica.Units.SI.Length x_ref "Reference position";
  Modelica.Units.SI.Length track_err "Tracking error";
  Real degradation "Bounded performance degradation [0.3,1]";
  Boolean track_ok "Tracking requirement met";
  Boolean energy_ok "Energy cap respected";

  // Safe square root helper quantities
  Real dp_sa "Supply-to-cap pressure difference";
  Real dp_at "Cap-to-tank pressure difference";
  Real dp_bt "Rod-to-tank pressure difference";
  Real dp_sb "Supply-to-rod pressure difference";

equation
  // Chamber volumes
  V_a = A_piston * (x + L_dead);
  V_b = A_rod * (L_stroke - x + L_dead);

  // Reference trajectory: smooth sinusoidal cycling
  x_ref = (x_ref_min + x_ref_max) / 2.0 + (x_ref_max - x_ref_min) / 2.0 *
          Modelica.Math.sin(2.0 * Modelica.Constants.pi * time / T_cycle);

  // Tracking error
  track_err = x_ref - x;

  // Energy-aware bounded degradation (inline saturation)
  degradation = if (1.0 - Ke * E_acc) > 1.0 then 1.0
                else if (1.0 - Ke * E_acc) < 0.3 then 0.3
                else (1.0 - Ke * E_acc);

  // Controller: desired flow command with valve saturation
  u_cmd = (Kp_flow * track_err + Kd_flow * (-v)) * degradation;
  u_sat = if u_cmd > Q_cmd_max then Q_cmd_max
          else if u_cmd < -Q_cmd_max then -Q_cmd_max
          else u_cmd;
  u_norm = u_sat / Q_cmd_max;

  // Pressure differences with safe lower bound
  dp_sa = if p_supply - p_a > 1.0e-3 then p_supply - p_a else 1.0e-3;
  dp_at = if p_a - p_tank > 1.0e-3 then p_a - p_tank else 1.0e-3;
  dp_bt = if p_b - p_tank > 1.0e-3 then p_b - p_tank else 1.0e-3;
  dp_sb = if p_supply - p_b > 1.0e-3 then p_supply - p_b else 1.0e-3;

  // Four-way proportional valve orifice flows
  // u_norm > 0: extend (supply->cap, rod->tank)
  // u_norm < 0: retract (cap->tank, supply->rod)
  Q_a = Cq * A_valve_max * sqrt(2.0 / rho_oil) *
        (if u_norm >= 0.0 then
           u_norm * sqrt(dp_sa)
         else
           u_norm * sqrt(dp_at));

  Q_b = Cq * A_valve_max * sqrt(2.0 / rho_oil) *
        (if u_norm >= 0.0 then
           -u_norm * sqrt(dp_bt)
         else
           -u_norm * sqrt(dp_sb));

  // Supply flow: sum of positive flows drawn from supply
  Q_supply = (if Q_a > 0.0 then Q_a else 0.0) + (if Q_b > 0.0 then Q_b else 0.0);

  // Chamber pressure dynamics (fluid compressibility)
  der(p_a) = (beta_eff / V_a) * (Q_a - A_piston * v);
  der(p_b) = (beta_eff / V_b) * (Q_b + A_rod * v);

  // Mechanical dynamics
  F_act = p_a * A_piston - p_b * A_rod;
  F_dist = if time >= t_start_dist and time <= t_end_dist then F_disturb else 0.0;
  m_load * der(v) = F_act - b_visc * v - F_coulomb * Modelica.Math.tanh(v / 0.01) - F_dist;
  der(x) = v;

  // Hydraulic power and accumulated energy from supply
  P_hyd = p_supply * Q_supply;
  der(E_acc) = if P_hyd > 0.0 then P_hyd else 0.0;

  // Diagnostics
  track_ok = (time < 6.5) or (abs(track_err) < eps_track);
  energy_ok = (E_acc <= E_cap);

  // Physical bounds assertions
  assert(x >= -0.001 and x <= L_stroke + 0.001, "Piston position out of bounds");
  assert(p_a > 0.0 and p_a < 5.0e7, "Cap pressure out of physical range");
  assert(p_b > 0.0 and p_b < 5.0e7, "Rod pressure out of physical range");

initial equation
  x = x0;
  v = v0;
  p_a = p_a0;
  p_b = p_b0;
  E_acc = 0.0;

  annotation(
    experiment(StartTime=0, StopTime=10, Tolerance=1e-5, Interval=0.01),
    Documentation(info="Hydraulic double-acting cylinder with compressible chambers, "
      "four-way proportional valve with saturation, energy-aware motion control "
      "with bounded degradation. 126 N disturbance during middle third. "
      "Sinusoidal cycling reference between 0.05 and 0.45 m with 5 s period. "
      "Runs at 100 Hz for 10 s. Energy cap declared at 5000 J. "
      "Tracking error required below 0.024 m after 6.5 s."),
    uses(Modelica(version="4.0.0"))
  );
end HydCylinderConserveB;