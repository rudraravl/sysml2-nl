model HydCylinderConserveE
  // ===== Physical parameters (SI units) =====
  parameter Real A_p = 0.0040 "Piston (cap-side) area [m2]";
  parameter Real A_r = 0.0032 "Rod-side area [m2]";
  parameter Real L_stroke = 0.50 "Cylinder stroke [m]";
  parameter Real m_load = 110.0 "Moving mass [kg]";
  parameter Real P_supply = 3.5e6 "Supply pressure [Pa]";
  parameter Real P_tank = 3.0e5 "Return (tank) pressure [Pa]";
  parameter Real beta_eff = 1.0e9 "Effective bulk modulus (oil+compliance) [Pa]";
  parameter Real V_dead = 5.0e-5 "Dead volume per chamber [m3]";
  parameter Real b_visc = 500.0 "Viscous damping [N.s/m]";
  parameter Real Q_max = 0.001 "Valve command magnitude bound [m3/s]";

  // ===== Controller parameters =====
  parameter Real Kp_pos = 0.2 "Position proportional gain [(m3/s)/m]";
  parameter Real Kd_pos = 0.005 "Velocity derivative gain [(m3/s)/(m/s)]";
  parameter Real ff_factor = 0.95 "Feedforward scaling factor [-]";
  parameter Real x_offset = 0.25 "Reference center position [m]";
  parameter Real x_amp = 0.03 "Reference amplitude [m]";
  parameter Real f_cycle = 0.5 "Cycle frequency [Hz]";

  // ===== Energy management =====
  parameter Real E_cap = 50000.0 "Declared energy-use cap [J]";
  parameter Real F_dist_mag = 216.0 "Disturbance force magnitude [N]";

  // ===== Acceptance thresholds =====
  parameter Real err_threshold = 0.018 "Primary tracking error threshold after 10.4 s [m]";
  parameter Real term_err_threshold = 0.015 "Terminal error threshold [m]";
  parameter Real t_check = 10.4 "Tracking error check time [s]";

  // ===== Numerical constants =====
  constant Real pi_val = 3.141592653589793;
  constant Real eps_p = 1.0 "Pressure sqrt floor [Pa]";

  // ===== Dynamic states =====
  Real x(start = 0.25, fixed = true) "Piston position [m]";
  Real v(start = 0.0, fixed = true) "Piston velocity [m/s]";
  Real P_cap(start = 1.4e6, fixed = true) "Cap-side chamber pressure [Pa]";
  Real P_rod(start = 1.75e6, fixed = true) "Rod-side chamber pressure [Pa]";
  Real E_acc(start = 0.0, fixed = true) "Accumulated hydraulic energy [J]";

  // ===== Valve and flow =====
  Real u_cmd "Unsaturated valve command [m3/s]";
  Real u_sat "Saturated valve command [m3/s]";
  Real pos_u "Extend (positive) command component [m3/s]";
  Real neg_u "Retract (negative) command component [m3/s]";
  Real Q_s_to_cap "Supply to cap-side flow [m3/s]";
  Real Q_s_to_rod "Supply to rod-side flow [m3/s]";
  Real Q_cap_to_t "Cap-side to tank flow [m3/s]";
  Real Q_rod_to_t "Rod-side to tank flow [m3/s]";
  Real Q_supply "Total supply flow [m3/s]";
  Real Q_tank "Total return flow [m3/s]";

  // ===== Volumes and forces =====
  Real V_cap "Cap-side chamber volume [m3]";
  Real V_rod "Rod-side chamber volume [m3]";
  Real F_hydraulic "Net hydraulic force [N]";
  Real F_dist "Disturbance force [N]";

  // ===== Reference and control =====
  Real x_ref "Reference position [m]";
  Real v_ref "Reference velocity [m/s]";
  Real tracking_error "Tracking error (x_ref - x) [m]";
  Real energy_fraction "Fraction of energy cap consumed [-]";
  Real gain_reduction "Energy-aware gain reduction factor [-]";
  Real Kp_eff "Effective proportional gain [(m3/s)/m]";

  // ===== Orifice pressure scaling =====
  Real dP_ref "Reference pressure drop [Pa]";
  Real sqrt_sc "Orifice scale supply-to-cap [-]";
  Real sqrt_rt "Orifice scale rod-to-tank [-]";
  Real sqrt_sr "Orifice scale supply-to-rod [-]";
  Real sqrt_ct "Orifice scale cap-to-tank [-]";

  // ===== Synchronized sensor traces =====
  Real Q_supply_meas "Measured supply flow [m3/s]";
  Real P_supply_meas "Measured supply pressure [Pa]";
  Real x_meas "Measured position [m]";
  Real v_meas "Measured velocity [m/s]";
  Real P_cap_meas "Measured cap-side pressure [Pa]";
  Real P_rod_meas "Measured rod-side pressure [Pa]";
  Real E_acc_meas "Measured accumulated energy [J]";
  Real u_cmd_meas "Measured valve command [m3/s]";

  // ===== Acceptance checks =====
  Real err_at_check "Tracking error at/after check time [m]";
  Real terminal_error "Terminal tracking error [m]";
  Real energy_within_cap "1 if within cap, else 0";
  Real tracking_ok "1 if tracking OK after check, else 0";
  Real terminal_ok "1 if terminal OK, else 0";
  Real physical_ok "1 if bounds satisfied, else 0";
  Real cycle_complete "1 if cycle completed, else 0";
  Real no_nan_inf "1 if all finite, else 0";
  Real all_accept "1 if all pass (fail-closed), else 0";

equation
  // Chamber volumes
  V_cap = V_dead + A_p * x;
  V_rod = V_dead + A_r * (L_stroke - x);

  // Reference trajectory (repeated sinusoidal cycle)
  x_ref = x_offset + x_amp * sin(2.0 * pi_val * f_cycle * time);
  v_ref = x_amp * 2.0 * pi_val * f_cycle * cos(2.0 * pi_val * f_cycle * time);
  tracking_error = x_ref - x;

  // Disturbance: 216 N during middle third [5.33, 10.67] s
  if time >= 16.0 / 3.0 and time <= 32.0 / 3.0 then
    F_dist = F_dist_mag;
  else
    F_dist = 0.0;
  end if;

  // Energy-aware gain reduction (bounded degradation, max 30%)
  energy_fraction = E_acc / E_cap;
  if energy_fraction < 0.7 then
    gain_reduction = 1.0;
  elseif energy_fraction < 1.0 then
    gain_reduction = 1.0 - 0.3 * (energy_fraction - 0.7) / 0.3;
  else
    gain_reduction = 0.7;
  end if;
  Kp_eff = Kp_pos * gain_reduction;

  // PD + feedforward controller
  u_cmd = Kp_eff * tracking_error + Kd_pos * (v_ref - v) + ff_factor * A_p * v_ref;

  // Valve saturation (smooth tanh, no events)
  u_sat = Q_max * tanh(u_cmd / Q_max);

  // Split into extend/retract components (smooth)
  pos_u = 0.5 * (u_sat + sqrt(u_sat * u_sat + 1.0e-14));
  neg_u = 0.5 * (sqrt(u_sat * u_sat + 1.0e-14) - u_sat);

  // Orifice pressure scaling (prevents unphysical flow at pressure limits)
  dP_ref = P_supply - P_tank;
  sqrt_sc = sqrt(max(eps_p, P_supply - P_cap) / dP_ref);
  sqrt_rt = sqrt(max(eps_p, P_rod - P_tank) / dP_ref);
  sqrt_sr = sqrt(max(eps_p, P_supply - P_rod) / dP_ref);
  sqrt_ct = sqrt(max(eps_p, P_cap - P_tank) / dP_ref);

  // Four-way proportional valve flows
  Q_s_to_cap = pos_u * sqrt_sc;
  Q_rod_to_t = pos_u * sqrt_rt;
  Q_s_to_rod = neg_u * sqrt_sr;
  Q_cap_to_t = neg_u * sqrt_ct;

  // Aggregate flows
  Q_supply = Q_s_to_cap + Q_s_to_rod;
  Q_tank = Q_cap_to_t + Q_rod_to_t;

  // Chamber pressure dynamics (compressibility)
  der(P_cap) = (beta_eff / V_cap) * (Q_s_to_cap - Q_cap_to_t - A_p * v);
  der(P_rod) = (beta_eff / V_rod) * (Q_s_to_rod - Q_rod_to_t + A_r * v);

  // Hydraulic force
  F_hydraulic = P_cap * A_p - P_rod * A_r;

  // Mechanical dynamics
  der(x) = v;
  m_load * der(v) = F_hydraulic - F_dist - b_visc * v;

  // Energy accumulation (supply power minus return recovery)
  der(E_acc) = P_supply * Q_supply - P_tank * Q_tank;

  // Sensor traces (synchronized)
  Q_supply_meas = Q_supply;
  P_supply_meas = P_supply;
  x_meas = x;
  v_meas = v;
  P_cap_meas = P_cap;
  P_rod_meas = P_rod;
  E_acc_meas = E_acc;
  u_cmd_meas = u_sat;

  // ===== Acceptance checks =====

  // Tracking error at/after check time
  if time >= t_check then
    err_at_check = abs(tracking_error);
  else
    err_at_check = 0.0;
  end if;

  // Terminal error
  terminal_error = abs(x - x_ref);

  // Energy within cap
  if E_acc <= E_cap then
    energy_within_cap = 1.0;
  else
    energy_within_cap = 0.0;
  end if;

  // Tracking OK after check time
  if time >= t_check and abs(tracking_error) < err_threshold then
    tracking_ok = 1.0;
  else
    tracking_ok = 0.0;
  end if;

  // Terminal OK
  if terminal_error < term_err_threshold then
    terminal_ok = 1.0;
  else
    terminal_ok = 0.0;
  end if;

  // Physical bounds
  if x >= 0.0 and x <= L_stroke and
     P_cap > 0.0 and P_rod > 0.0 and
     P_cap <= P_supply * 1.1 and P_rod <= P_supply * 1.1 then
    physical_ok = 1.0;
  else
    physical_ok = 0.0;
  end if;

  // Cycle completion (at least one full period)
  if time >= 1.0 / f_cycle then
    cycle_complete = 1.0;
  else
    cycle_complete = 0.0;
  end if;

  // No NaN/infinite (IEEE 754: NaN comparisons return false)
  if x > -1.0e6 and x < 1.0e6 and
     v > -1.0e6 and v < 1.0e6 and
     P_cap > 0.0 and P_cap < 1.0e12 and
     P_rod > 0.0 and P_rod < 1.0e12 and
     E_acc > -1.0e6 and E_acc < 1.0e12 and
     u_cmd > -1.0e6 and u_cmd < 1.0e6 then
    no_nan_inf = 1.0;
  else
    no_nan_inf = 0.0;
  end if;

  // Overall acceptance (fail-closed: all must be 1.0)
  all_accept = energy_within_cap * tracking_ok * terminal_ok *
               physical_ok * cycle_complete * no_nan_inf;

  annotation(
    experiment(StartTime = 0, StopTime = 16, Tolerance = 1e-6, Interval = 0.004),
    Documentation(info = "Double-acting hydraulic cylinder with two compressible chambers, four-way proportional valve with saturation, energy-aware PD+feedforward motion controller, and middle-third 216 N disturbance. 250 Hz for 16 s. Acceptance is fail-closed."),
    Diagram(graphics = {Text(extent = {{-100,100},{100,-100}}, textString = "HydCylinderConserveE")})
  );
end HydCylinderConserveE;