model HydCylinderPositionE
  // ---- Cylinder geometry ----
  parameter Real A_a(unit="m2") = 0.0040 "Cap-side (piston) area";
  parameter Real A_b(unit="m2") = 0.0032 "Rod-side annular area";
  parameter Real L(unit="m") = 0.50 "Stroke";
  parameter Real m_mass(unit="kg") = 110 "Moving mass";
  parameter Real V_a0(unit="m3") = A_a*0.06 "Cap-side dead volume";
  parameter Real V_b0(unit="m3") = A_b*0.06 "Rod-side dead volume";

  // ---- Fluid ----
  parameter Real Beta(unit="Pa") = 5.0e8 "Effective fluid bulk modulus (oil with entrained air)";
  parameter Real C_leak(unit="m3/(s.Pa)") = 5.0e-14 "Internal cross-port leakage conductance";

  // ---- Hydraulic supply (declared) ----
  parameter Real p_s(unit="Pa") = 14.0e6 "Declared supply pressure";
  parameter Real p_t(unit="Pa") = 0.20e6 "Declared return/tank pressure";

  // ---- Valve ----
  parameter Real Q_max(unit="m3/s") = 0.001 "Valve command magnitude bound";

  // ---- End stops ----
  parameter Real k_stop(unit="N/m") = 1.0e7 "End-stop stiffness";
  parameter Real d_stop(unit="N.s/m") = 1.0e4 "End-stop damping";
  parameter Real x_tol_stop(unit="m") = 1.0e-4 "End-stop engagement margin";

  // ---- Friction ----
  parameter Real F_friction(unit="N") = 20.0 "Coulomb friction magnitude";
  parameter Real v_small(unit="m/s") = 0.005 "Friction smoothing velocity";
  parameter Real b_visc(unit="N.s/m") = 12000.0 "Viscous damping coefficient";

  // ---- Reference / scenario ----
  parameter Real x0(unit="m") = 0.0 "Initial coordinate";
  parameter Real x_target(unit="m") = 0.70*L "Target = 70% of available travel";
  parameter Real t_end(unit="s") = 16.0 "Run duration";
  parameter Real t_track(unit="s") = 10.4 "Tracking-error check start time";
  parameter Real e_track_limit(unit="m") = 0.011 "Allowed tracking error after t_track";

  // ---- Controller (250 Hz, pressure-aware PID) ----
  parameter Real Ts(unit="s") = 1.0/250.0 "Controller sample period";
  parameter Real Kp = 0.0020 "Proportional gain (m3/s per m)";
  parameter Real Ki = 0.00040 "Integral gain (m3/s per (m.s))";
  parameter Real Kd = 0.00080 "Velocity-feedback gain (m3/s per (m/s))";
  parameter Real Kff = 1.0e-8 "Pressure feedforward gain (m3/s per N)";
  parameter Real F_ff(unit="N") = 0.0 "Open-loop force feedforward";

  // ---- Continuous states ----
  Real x(start=x0, fixed=true, unit="m") "Piston position";
  Real v(start=0, fixed=true, unit="m/s") "Piston velocity";
  Real p_a(start=(p_s+p_t)/2, fixed=true, unit="Pa") "Cap-side pressure";
  Real p_b(start=(p_s+p_t)/2, fixed=true, unit="Pa") "Rod-side pressure";

  // ---- Discrete controller / valve states ----
  discrete Real u_cmd(start=0.0, unit="m3/s") "Valve command";
  discrete Real u_unsat(start=0.0) "Unsaturated command";
  discrete Real ie(start=0.0) "Integral of position error";
  discrete Real x_s(start=x0) "Sampled position";
  discrete Real v_s(start=0.0) "Sampled velocity";
  discrete Real p_a_s(start=(p_s+p_t)/2) "Sampled cap pressure";
  discrete Real p_b_s(start=(p_s+p_t)/2) "Sampled rod pressure";
  discrete Boolean saturated(start=false) "Anti-windup flag";

  // ---- Derived / measured ----
  Real F_pressure(unit="N") "Net pressure force";
  Real F_end(unit="N") "End-stop force";
  Real F_ext(unit="N") "External load (middle third)";
  Real F_fric(unit="N") "Friction force";
  Real Q_leak(unit="m3/s") "Leakage flow a->b";
  Real V_a(unit="m3") "Cap-side volume";
  Real V_b(unit="m3") "Rod-side volume";

  // ---- Synchronized sensor traces ----
  Real y_x(unit="m") "Position sensor";
  Real y_v(unit="m/s") "Velocity sensor";
  Real y_pa(unit="Pa") "Cap pressure sensor";
  Real y_pb(unit="Pa") "Rod pressure sensor";
  Real y_u(unit="m3/s") "Valve command sensor";

  // ---- Acceptance (fail-closed) ----
  Real tracking_error;
  Boolean pass_travel;
  Boolean pass_valve;
  Boolean pass_pressure;
  Boolean pass_velocity;
  Boolean pass_final;
  Boolean pass_tracking;
  Boolean pass_finite;
  Boolean pass_all;

equation
  // Chamber volumes (well-defined for x in [0, L])
  V_a = V_a0 + A_a*x;
  V_b = V_b0 + A_b*(L - x);

  // Net pressure force on piston
  F_pressure = A_a*p_a - A_b*p_b;

  // Smoothed Coulomb friction + viscous damping
  F_fric = -F_friction*tanh(v/v_small) - b_visc*v;

  // Mechanical end stops (engage beyond soft margin)
  F_end = if x < -x_tol_stop then
            -k_stop*(x + x_tol_stop) - d_stop*v
          elseif x > L + x_tol_stop then
            -k_stop*(x - L - x_tol_stop) - d_stop*v
          else
            0.0;

  // External 120 N disturbance in middle third of travel (opposes extension)
  F_ext = if (x >= L/3.0 and x <= 2.0*L/3.0) then 120.0 else 0.0;

  // Mechanical dynamics
  der(x) = v;
  m_mass*der(v) = F_pressure + F_end + F_fric - F_ext;

  // Leakage (compressible chambers)
  Q_leak = C_leak*(p_a - p_b);

  // Pressure dynamics: continuity with fluid compressibility
  der(p_a) = (Beta/V_a)*(u_cmd - A_a*v - Q_leak);
  der(p_b) = (Beta/V_b)*(-u_cmd + A_b*v + Q_leak);

  // Synchronized sensors
  y_x = x;
  y_v = v;
  y_pa = p_a;
  y_pb = p_b;
  y_u = u_cmd;

  // Tracking error metric
  tracking_error = abs(x - x_target);

  // ---- Acceptance bounds (fail-closed) ----
  pass_travel = (x >= -1.0e-3) and (x <= L + 1.0e-3);
  pass_valve = (abs(u_cmd) <= Q_max + 1.0e-9);
  pass_pressure = (p_a >= -1.0e3) and (p_a <= p_s + 5.0e6)
              and (p_b >= -1.0e3) and (p_b <= p_s + 5.0e6);
  pass_velocity = (abs(v) <= 10.0);
  pass_final = (time < t_end - 1.0e-6) or (abs(x - x_target) <= 0.011);
  pass_tracking = (time < t_track) or (abs(x - x_target) < e_track_limit);
  pass_finite = (abs(x) < 1.0e30) and (abs(v) < 1.0e30)
              and (abs(p_a) < 1.0e30) and (abs(p_b) < 1.0e30)
              and (abs(u_cmd) < 1.0e30) and (abs(ie) < 1.0e30)
              and (abs(tracking_error) < 1.0e30);
  pass_all = pass_travel and pass_valve and pass_pressure and pass_velocity
           and pass_final and pass_tracking and pass_finite;

algorithm
  when sample(0, Ts) then
    // Synchronized sampling of plant state for control and traces
    x_s := x;
    v_s := v;
    p_a_s := p_a;
    p_b_s := p_b;

    // Pressure-aware PID: explicit chamber-pressure feedforward of net force error
    u_unsat := Kp*(x_target - x_s) + Ki*ie - Kd*v_s
             + Kff*(F_ff - (A_a*p_a_s - A_b*p_b_s));

    // Saturate to four-way valve command bound
    if u_unsat > Q_max then
      u_cmd := Q_max;
      saturated := true;
    elseif u_unsat < -Q_max then
      u_cmd := -Q_max;
      saturated := true;
    else
      u_cmd := u_unsat;
      saturated := false;
    end if;

    // Anti-windup: only integrate when not pushing further into saturation
    if (not saturated) or (sign(x_target - x_s) <> sign(u_unsat)) then
      ie := ie + (x_target - x_s)*Ts;
    end if;
  end when;

  annotation(
    experiment(StartTime=0, StopTime=16, Tolerance=1e-6, Interval=0.004),
    Documentation(info="Hydraulic double-acting cylinder position control. Plant: two compressible chambers, four-way proportional valve (flow-commanded), declared supply/return pressure, internal leakage, mechanical end stops. Pressure-aware PID at 250 Hz. 120 N disturbance over middle third of stroke. Target 70% of 0.50 m travel = 0.35 m. Fail-closed acceptance for travel, valve, pressure, velocity, final position, and tracking error after 10.4 s.")
  );
end HydCylinderPositionE;