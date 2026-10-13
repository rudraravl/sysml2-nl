model PneuGripConserveE
  // ---------------- Physical parameters (SI units) ----------------
  parameter Real L = 0.035 "Cylinder stroke [m]";
  parameter Real A = 0.0012 "Piston area [m2]";
  parameter Real m_f = 0.8 "Gripper finger mass [kg]";
  parameter Real Ps = 6.0e5 "Supply pressure [Pa]";
  parameter Real Pr = 1.01325e5 "Return (exhaust) pressure [Pa]";
  parameter Real T_gas = 293.15 "Chamber gas temperature [K]";
  parameter Real R_air = 287.0 "Specific gas constant of air [J/(kg.K)]";
  parameter Real V0 = 1.2e-5 "Chamber dead volume [m3]";
  parameter Real b_visc = 60.0 "Viscous friction coefficient [N.s/m]";
  parameter Real k_ret = 200.0 "Return spring stiffness [N/m]";
  parameter Real mdot_max = 0.001 "Valve command magnitude bound [kg/s]";

  // ---------------- Scenario parameters ----------------
  parameter Real freq = 0.5 "Actuation cycle frequency [Hz]";
  parameter Real E_cap = 1500.0 "Declared energy-use cap [J]";
  parameter Real err_bound = 0.018 "Primary tracking error bound after 10.4 s [m]";
  parameter Real t_check = 10.4 "Tracking-error check time [s]";
  parameter Real F_dist = 216.0 "Middle-third disturbance load [N]";
  parameter Real t_d_start = 16.0/3.0 "Disturbance start [s]";
  parameter Real t_d_end = 32.0/3.0 "Disturbance end [s]";

  // ---------------- Controller parameters ----------------
  parameter Real Kp = 9000.0 "Position gain";
  parameter Real Kd = 350.0 "Velocity gain";
  parameter Real Ku = 0.9 "Energy-aware base scale";
  parameter Real scale_floor = 0.2 "Bounded degradation floor";

  // ---------------- Continuous states ----------------
  Real x1(start=0.0, fixed=true) "Finger 1 position [m]";
  Real v1(start=0.0, fixed=true) "Finger 1 velocity [m/s]";
  Real x2(start=0.0, fixed=true) "Finger 2 position [m]";
  Real v2(start=0.0, fixed=true) "Finger 2 velocity [m/s]";
  Real P1(start=Pr, fixed=true) "Cylinder 1 chamber pressure [Pa]";
  Real P2(start=Pr, fixed=true) "Cylinder 2 chamber pressure [Pa]";
  Real E_acc(start=0.0, fixed=true) "Accumulated pneumatic supply energy [J]";
  Real m_acc(start=0.0, fixed=true) "Accumulated supply air mass [kg]";

  // ---------------- Commands, sensors, and traces ----------------
  Real u1_raw "Raw valve 1 command [kg/s]";
  Real u2_raw "Raw valve 2 command [kg/s]";
  Real u1 "Saturated valve 1 command [kg/s]";
  Real u2 "Saturated valve 2 command [kg/s]";
  Real mdot_sup1 "Supply mass flow valve 1 [kg/s]";
  Real mdot_sup2 "Supply mass flow valve 2 [kg/s]";
  Real mdot_sup_total "Total supply mass flow [kg/s]";
  Real x_ref "Reference position trajectory [m]";
  Real v_ref "Reference velocity [m/s]";
  Real err1 "Finger 1 tracking error [m]";
  Real err2 "Finger 2 tracking error [m]";
  Real err_primary "Primary (worst-finger) tracking error [m]";
  Real energy_scale "Energy-aware command scaling [-]";
  Real F_load "Disturbance load on each finger [N]";
  Real specific_energy "Specific supply energy (isothermal) [J/kg]";
  Real gap "Finger gap (closing aperture) [m]";
  Real cycles_completed "Completed actuation cycles [-]";

  // ---------------- Discrete sampled observations ----------------
  discrete Real err_at_check(start=1.0e9) "Primary error sampled at t_check [m]";
  discrete Real E_at_end(start=0.0) "Energy sampled at end [J]";
  discrete Real err_at_end(start=1.0e9) "Primary error sampled at end [m]";

  // ---------------- Acceptance flags ----------------
  Boolean bounds_ok "Physical bounds satisfied";
  Boolean cycle_ok "Cycle completion satisfied";
  Boolean terminal_err_ok "Terminal tracking error satisfied";
  Boolean energy_cap_ok "Declared energy/air-use cap satisfied";
  Boolean tracking_ok "Primary tracking error after 10.4 s satisfied";
  Boolean no_nan "No NaN/infinite physical, control, or estimator values";
  Boolean acceptance "Fail-closed acceptance (all checks passed)";

protected
  Real V1 "Chamber 1 volume [m3]";
  Real V2 "Chamber 2 volume [m3]";
  Real F1 "Net force on finger 1 [N]";
  Real F2 "Net force on finger 2 [N]";
  Real in_dist "Disturbance active indicator [1/0]";
  Real two_pi_f "Angular cycle frequency [rad/s]";

equation
  // ----- Reference cycle (closes/opens repeatedly) -----
  two_pi_f = 2.0*Modelica.Constants.pi*freq;
  x_ref = 0.5*L*(1.0 - cos(two_pi_f*time));
  v_ref = L*Modelica.Constants.pi*freq*sin(two_pi_f*time);

  // ----- Tracking errors -----
  err1 = x_ref - x1;
  err2 = x_ref - x2;
  err_primary = max(abs(err1), abs(err2));

  // ----- Sampled observations for acceptance testing -----
  when time >= t_check then
    err_at_check = err_primary;
  end when;
  when time >= 16.0 - 1.0e-6 then
    E_at_end = E_acc;
    err_at_end = err_primary;
  end when;

  // ----- Controlled middle-third disturbance load -----
  in_dist = if (time >= t_d_start and time <= t_d_end) then 1.0 else 0.0;
  F_load = in_dist*F_dist;

  // ----- Isothermal specific supply energy (compressibility effect) -----
  specific_energy = R_air*T_gas*log(max(Ps, 1.0)/max(Pr, 1.0));

  // ----- Energy-aware motion control with bounded degradation -----
  energy_scale = Ku*max(scale_floor, 1.0 - E_acc/E_cap);
  u1_raw = energy_scale*(Kp*err1 + Kd*(v_ref - v1));
  u2_raw = energy_scale*(Kp*err2 + Kd*(v_ref - v2));

  // ----- Valve saturation (command magnitude bounded) -----
  u1 = max(-mdot_max, min(mdot_max, u1_raw));
  u2 = max(-mdot_max, min(mdot_max, u2_raw));

  // ----- Supply flow measurement (only charging draws from supply) -----
  mdot_sup1 = max(0.0, u1);
  mdot_sup2 = max(0.0, u2);
  mdot_sup_total = mdot_sup1 + mdot_sup2;

  // ----- Accumulated energy and air mass -----
  der(E_acc) = mdot_sup_total*specific_energy;
  der(m_acc) = mdot_sup_total;

  // ----- Chamber volumes -----
  V1 = V0 + A*x1;
  V2 = V0 + A*x2;

  // ----- Pressure dynamics (isothermal compressibility) -----
  der(P1) = (R_air*T_gas*u1 - P1*A*v1)/V1;
  der(P2) = (R_air*T_gas*u2 - P2*A*v2)/V2;

  // ----- Force balance on opposing gripper fingers -----
  F1 = P1*A - Pr*A - b_visc*v1 - k_ret*x1 - F_load;
  F2 = P2*A - Pr*A - b_visc*v2 - k_ret*x2 - F_load;

  // ----- Finger dynamics -----
  der(x1) = v1;
  der(v1) = F1/m_f;
  der(x2) = v2;
  der(v2) = F2/m_f;

  // ----- Finger gap (closing aperture) -----
  gap = L - (x1 + x2);

  // ----- Cycle completion counter -----
  cycles_completed = floor(freq*time);

  // ----- Acceptance checks (evaluated at simulation end; fail-closed) -----
  bounds_ok = (x1 >= -1.0e-4) and (x1 <= L + 1.0e-4)
              and (x2 >= -1.0e-4) and (x2 <= L + 1.0e-4)
              and (P1 > 1.0e3) and (P1 < Ps + 2.0e5)
              and (P2 > 1.0e3) and (P2 < Ps + 2.0e5)
              and (abs(u1) <= mdot_max + 1.0e-9)
              and (abs(u2) <= mdot_max + 1.0e-9)
              and (E_acc >= 0.0) and (m_acc >= 0.0);

  cycle_ok = cycles_completed >= (freq*16.0 - 1.5);

  terminal_err_ok = (err_at_end <= err_bound);

  energy_cap_ok = (E_at_end <= E_cap + 1.0e-6) and (m_acc >= 0.0);

  tracking_ok = (err_at_check <= err_bound);

  no_nan = (x1 > -1.0e6) and (x1 < 1.0e6)
           and (x2 > -1.0e6) and (x2 < 1.0e6)
           and (v1 > -1.0e6) and (v1 < 1.0e6)
           and (v2 > -1.0e6) and (v2 < 1.0e6)
           and (P1 > 0.0) and (P1 < 1.0e8)
           and (P2 > 0.0) and (P2 < 1.0e8)
           and (u1 > -1.0e6) and (u1 < 1.0e6)
           and (u2 > -1.0e6) and (u2 < 1.0e6)
           and (E_acc > -1.0e6) and (E_acc < 1.0e9)
           and (m_acc > -1.0e6) and (m_acc < 1.0e6)
           and (energy_scale > 0.0) and (energy_scale < 1.0e6);

  acceptance = bounds_ok and cycle_ok and terminal_err_ok
               and energy_cap_ok and tracking_ok and no_nan;

  annotation(
    experiment(StartTime=0.0, StopTime=16.0, Tolerance=1.0e-6, Interval=0.004),
    Documentation(info="Pneumatic two-finger gripper with energy-aware motion control.
      Two compressible chambers driven by saturated proportional air valves.
      Middle-third 216 N disturbance, isothermal compressibility, return pressure,
      valve saturation, accumulated supply energy and air mass, bounded performance
      degradation, and fail-closed acceptance checks at 250 Hz over 16 s."));
end PneuGripConserveE;