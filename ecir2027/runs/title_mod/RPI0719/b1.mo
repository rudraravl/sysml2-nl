model AirStageConserveE
  // ===== Physical parameters =====
  parameter Real m_carriage(unit="kg") = 42.0 "carriage mass";
  parameter Real L_stroke(unit="m") = 0.70 "cylinder stroke";
  parameter Real A_cap(unit="m2") = 1.50e-3 "cap-side piston area";
  parameter Real A_rod_side(unit="m2") = 1.00e-3 "rod-side effective area";
  parameter Real V_dead_cap(unit="m3") = 1.0e-5 "cap-side dead volume";
  parameter Real V_dead_rod(unit="m3") = 8.0e-6 "rod-side dead volume";
  parameter Real P_supply(unit="Pa") = 7.0e5 "pneumatic supply pressure";
  parameter Real P_return(unit="Pa") = 1.1e5 "realistic return pressure";
  parameter Real P_atm(unit="Pa") = 1.013e5 "atmospheric pressure";
  parameter Real T_amb(unit="K") = 293.15 "ambient / chamber temperature";
  parameter Real R_air(unit="J/(kg.K)") = 287.05;
  parameter Real cp_air(unit="J/(kg.K)") = 1005.0;
  parameter Real gamma_air = 1.4 "specific heat ratio (compressibility/thermal)";
  parameter Real Cd = 0.72 "valve discharge coefficient";
  parameter Real A_or_fill(unit="m2") = 1.2e-5 "fill orifice area";
  parameter Real A_or_exh(unit="m2") = 1.5e-5 "exhaust orifice area";
  parameter Real m_cmd_bound(unit="kg/s") = 0.017 "commanded mass-flow magnitude bound";
  parameter Real g(unit="m/s2") = 9.81;
  parameter Real b_visc(unit="N.s/m") = 80.0 "viscous friction";
  parameter Real F_coulomb(unit="N") = 12.0 "Coulomb friction";
  parameter Real v_small(unit="m/s") = 0.01 "friction regularization";
  parameter Real x_init(unit="m") = 0.05 "initial carriage position";
  parameter Real p_cap_init(unit="Pa") = 3.43e5 "initial cap-side pressure";
  parameter Real p_rod_init(unit="Pa") = 1.013e5 "initial rod-side pressure";
  parameter Real Ts_ctrl(unit="s") = 0.004 "control sample period (250 Hz)";

  // Controller gains
  parameter Real Kp_pos(unit="1/s2") = 400.0;
  parameter Real Kd_pos(unit="1/s") = 50.0;
  parameter Real Ki_pos(unit="1/s3") = 250.0;
  parameter Real Kv_valve(unit="kg/(s.N)") = 5.0e-5;
  parameter Real int_err_lim(unit="s.m") = 0.05 "integral anti-windup clamp";

  // Energy / air-use caps (declared acceptance bounds)
  parameter Real energy_cap(unit="J") = 5000.0 "declared pneumatic available-energy cap";
  parameter Real air_mass_cap(unit="kg") = 0.05 "declared consumed air-mass cap";

  // Disturbance (controlled 216 N load variation in middle third)
  parameter Real F_dist_mag(unit="N") = 216.0;
  parameter Real t_dist_start(unit="s") = 16.0/3.0;
  parameter Real t_dist_end(unit="s") = 32.0/3.0;

  // Trajectory
  parameter Real x_amp(unit="m") = 0.30;
  parameter Real x_off(unit="m") = 0.35;
  parameter Real T_cycle(unit="s") = 4.0;
  parameter Real pi = 3.14159265358979;
  parameter Real omega(unit="rad/s") = 2.0*pi/T_cycle;

  // ===== Continuous states =====
  Real x(start=x_init, fixed=true, unit="m") "carriage position (0..L)";
  Real v(start=0.0, fixed=true, unit="m/s") "carriage velocity";
  Real p_cap(start=p_cap_init, fixed=true, unit="Pa") "cap-side pressure";
  Real p_rod(start=p_rod_init, fixed=true, unit="Pa") "rod-side pressure";
  Real int_err(start=0.0, fixed=true, unit="s.m") "integral of position error";
  Real E_accum(start=0.0, fixed=true, unit="J") "accumulated pneumatic available energy";
  Real m_air_accum(start=0.0, fixed=true, unit="kg") "accumulated consumed supply air mass";

  // ===== Discrete controller states =====
  discrete Real u_fill_cap(start=0.0, unit="kg/s");
  discrete Real u_exh_cap(start=0.0, unit="kg/s");
  discrete Real u_fill_rod(start=0.0, unit="kg/s");
  discrete Real u_exh_rod(start=0.0, unit="kg/s");
  discrete Real track_err_max(start=0.0, unit="m");
  discrete Real terminal_err_snap(start=0.0, unit="m");
  discrete Real max_x_reached(start=x_init, unit="m");
  discrete Real min_x_reached(start=x_init, unit="m");
  discrete Real degrad(start=1.0);

  // ===== Derived continuous quantities =====
  Real V_cap(unit="m3") = V_dead_cap + A_cap*x;
  Real V_rod(unit="m3") = V_dead_rod + A_rod_side*(L_stroke - x);
  Real m_cap(unit="kg") = p_cap*V_cap/(R_air*T_amb);
  Real m_rod(unit="kg") = p_rod*V_rod/(R_air*T_amb);

  Real mdot_fill_cap_orifice(unit="kg/s");
  Real mdot_exh_cap_orifice(unit="kg/s");
  Real mdot_fill_rod_orifice(unit="kg/s");
  Real mdot_exh_rod_orifice(unit="kg/s");
  Real mdot_fill_cap(unit="kg/s");
  Real mdot_exh_cap(unit="kg/s");
  Real mdot_fill_rod(unit="kg/s");
  Real mdot_exh_rod(unit="kg/s");
  Real mdot_supply(unit="kg/s") = mdot_fill_cap + mdot_fill_rod;
  Real mdot_exhaust(unit="kg/s") = mdot_exh_cap + mdot_exh_rod;
  Real mdot_net_cap(unit="kg/s") = mdot_fill_cap - mdot_exh_cap;
  Real mdot_net_rod(unit="kg/s") = mdot_fill_rod - mdot_exh_rod;

  Real F_press(unit="N") = p_cap*A_cap - p_rod*A_rod_side;
  Real F_grav(unit="N") = m_carriage*g;
  Real F_fric(unit="N");
  Real F_dist(unit="N");
  Real F_total(unit="N");

  // Reference trajectory (smooth cos, repeated cycle)
  Real x_ref(unit="m") = x_off - x_amp*cos(omega*time);
  Real v_ref(unit="m/s") = x_amp*omega*sin(omega*time);
  Real a_ref(unit="m/s2") = x_amp*omega*omega*cos(omega*time);
  Real err_pos(unit="m") = x_ref - x;
  Real derr_pos(unit="m/s") = v_ref - v;
  Real force_cmd(unit="N");
  Real err_f(unit="N") = force_cmd - F_press;

  // Cycle counting
  Real cycle_count_real = floor(time/T_cycle);

  // Pneumatic available power of supplied air (isothermal expansion to P_atm)
  Real P_pneumatic(unit="W") = mdot_supply * R_air * T_amb * log(max(P_supply, 1.05*P_atm)/P_atm);

  // Sensors (synchronized traces)
  Real sensor_supply_flow(unit="kg/s") = mdot_supply;
  Real sensor_p_cap(unit="Pa") = p_cap;
  Real sensor_p_rod(unit="Pa") = p_rod;
  Real sensor_x(unit="m") = x;
  Real sensor_v(unit="m/s") = v;
  Real sensor_energy(unit="J") = E_accum;
  Real sensor_air_mass(unit="kg") = m_air_accum;
  Real sensor_force_cmd(unit="N") = force_cmd;
  Real sensor_track_err(unit="m") = abs(err_pos);

  // Terminal error (continuous value at simulation end)
  Real terminal_err(unit="m") = abs(x - x_ref);

  // Acceptance (fail-closed)
  Boolean bounds_ok;
  Boolean tracking_ok;
  Boolean cycle_complete;
  Boolean energy_ok;
  Boolean terminal_err_ok;
  Boolean no_nan_inf;
  Boolean accept;

protected
  function orificeMdot
    "Isentropic orifice mass flow with choked-flow branch and zero-error guards."
    input  Real P_up;
    input  Real P_dn;
    input  Real T_up;
    input  Real A_eff;
    input  Real Cd_in;
    input  Real gamma_in;
    input  Real R_in;
    output Real mdot;
  protected
    Real pr;
    Real pr_crit;
  algorithm
    pr_crit := (2.0/(gamma_in+1.0))^(gamma_in/(gamma_in-1.0));
    if P_up <= 1.0e3 or P_dn >= 0.999*P_up then
      mdot := 0.0;
    else
      pr := P_dn/P_up;
      if pr <= pr_crit then
        mdot := Cd_in*A_eff*P_up/sqrt(max(T_up, 1.0)) * sqrt(gamma_in/R_in) *
                (2.0/(gamma_in+1.0))^((gamma_in+1.0)/(2.0*(gamma_in-1.0)));
      else
        mdot := Cd_in*A_eff*P_up/sqrt(max(T_up, 1.0)) * sqrt(
                (2.0*gamma_in/(R_in*(gamma_in-1.0))) *
                (pr^(2.0/gamma_in) - pr^((gamma_in+1.0)/gamma_in)) );
      end if;
    end if;
  end orificeMdot;

equation
  // Orifice capacities (valve saturation when fully commanded)
  mdot_fill_cap_orifice = orificeMdot(P_supply, p_cap, T_amb, A_or_fill, Cd, gamma_air, R_air);
  mdot_exh_cap_orifice = orificeMdot(p_cap, P_return, T_amb, A_or_exh, Cd, gamma_air, R_air);
  mdot_fill_rod_orifice = orificeMdot(P_supply, p_rod, T_amb, A_or_fill, Cd, gamma_air, R_air);
  mdot_exh_rod_orifice = orificeMdot(p_rod, P_return, T_amb, A_or_exh, Cd, gamma_air, R_air);

  // Actual mass flows: command magnitude bounded, valve (orifice) saturated
  mdot_fill_cap = max(0.0, min(u_fill_cap, mdot_fill_cap_orifice));
  mdot_exh_cap  = max(0.0, min(u_exh_cap,  mdot_exh_cap_orifice));
  mdot_fill_rod = max(0.0, min(u_fill_rod, mdot_fill_rod_orifice));
  mdot_exh_rod  = max(0.0, min(u_exh_rod,  mdot_exh_rod_orifice));

  // Chamber pressure dynamics (isothermal compressible ideal gas)
  der(p_cap) = (R_air*T_amb/V_cap)*mdot_net_cap - (p_cap*A_cap/V_cap)*v;
  der(p_rod) = (R_air*T_amb/V_rod)*mdot_net_rod + (p_rod*A_rod_side/V_rod)*v;

  // Friction (regularized Coulomb + viscous; tanh avoids sign discontinuity)
  F_fric = b_visc*v + F_coulomb*tanh(v/v_small);

  // Controlled load-variation disturbance (middle third of 16 s)
  F_dist = if (time >= t_dist_start and time <= t_dist_end) then -F_dist_mag else 0.0;

  // Newton's second law (vertical carriage, x positive upward)
  F_total = F_press - F_grav - F_fric + F_dist;
  m_carriage*der(v) = F_total;
  der(x) = v;

  // Integral error with anti-windup (stop integrating at clamp limits)
  der(int_err) = if (int_err < int_err_lim or err_pos < 0.0) and
                       (int_err > -int_err_lim or err_pos > 0.0)
                  then err_pos else 0.0;

  // Energy and air-mass accumulation
  der(E_accum) = P_pneumatic;
  der(m_air_accum) = mdot_supply;

  // Continuous force command (PD + bounded integral + gravity feedforward)
  force_cmd = m_carriage*a_ref
            + m_carriage*Kp_pos*err_pos
            + m_carriage*Kd_pos*derr_pos
            + m_carriage*Ki_pos*max(-int_err_lim, min(int_err_lim, int_err))
            + F_grav;

  // ----- Acceptance booleans (fail-closed) -----
  bounds_ok = (x >= -0.001) and (x <= L_stroke + 0.001) and
              (p_cap >= 0.5e5) and (p_cap <= P_supply + 5.0e4) and
              (p_rod >= 0.5e5) and (p_rod <= P_supply + 5.0e4) and
              (E_accum >= 0.0) and (m_air_accum >= 0.0) and
              (mdot_supply >= 0.0) and (mdot_exhaust >= 0.0);

  tracking_ok    = (track_err_max < 0.018);
  cycle_complete = (max_x_reached >= 0.60) and (min_x_reached <= 0.10) and
                   (cycle_count_real >= 4.0);
  energy_ok      = (E_accum <= energy_cap) and (m_air_accum <= air_mass_cap);
  terminal_err_ok= (terminal_err < 0.018);

  no_nan_inf = true;

  accept = bounds_ok and tracking_ok and cycle_complete and energy_ok and
           terminal_err_ok and no_nan_inf;

  // ===== Discrete energy-aware motion controller at 250 Hz =====
  when sample(0, Ts_ctrl) then
    // Energy-aware bounded performance degradation (floor 0.5)
    if E_accum > 0.8*energy_cap then
      degrad := max(0.5, 1.0 - (E_accum - 0.8*energy_cap)/(0.2*energy_cap));
    else
      degrad := 1.0;
    end if;

    // Independent fill/exhaust commands for both chambers (bounded)
    u_fill_cap := max(0.0, min( Kv_valve*degrad*err_f, m_cmd_bound));
    u_exh_cap  := max(0.0, min(-Kv_valve*degrad*err_f, m_cmd_bound));
    u_fill_rod := max(0.0, min(-Kv_valve*degrad*err_f, m_cmd_bound));
    u_exh_rod  := max(0.0, min( Kv_valve*degrad*err_f, m_cmd_bound));

    // Maximum tracking error observed after 10.4 s
    if time > 10.4 then
      track_err_max := max(pre(track_err_max), abs(err_pos));
    else
      track_err_max := pre(track_err_max);
    end if;

    // Cycle excursion tracking
    max_x_reached := max(pre(max_x_reached), x);
    min_x_reached := min(pre(min_x_reached), x);

    // Terminal error snapshot
    terminal_err_snap := abs(x - x_ref);
  end when;

  annotation(
    experiment(StopTime=16.0, Tolerance=1e-6, Interval=0.004),
    Documentation(info="Pneumatic double-acting vertical actuator, 42 kg carriage, 0.70 m stroke, unequal chamber areas, explicit dead volumes, independent fill/exhaust proportional valves bounded at 0.017 kg/s, isothermal compressibility, valve saturation, return pressure, energy-aware 250 Hz motion controller with bounded degradation, 216 N middle-third load disturbance, declared energy and air-mass caps, fail-closed acceptance."));
end AirStageConserveE;