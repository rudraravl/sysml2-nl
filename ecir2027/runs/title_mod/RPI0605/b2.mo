model HydCylinderPositionE
  // ---- Cylinder geometry ----
  parameter Real A_a = 0.0040 "Cap-side (piston) area [m2]";
  parameter Real A_b = 0.0032 "Rod-side annular area [m2]";
  parameter Real L_stroke = 0.50 "Stroke [m]";
  parameter Real m = 110 "Moving mass [kg]";
  parameter Real V_a0 = A_a * 0.06 "Cap-side dead volume [m3]";
  parameter Real V_b0 = A_b * 0.06 "Rod-side dead volume [m3]";

  // ---- Fluid ----
  parameter Real Beta = 5.0e8 "Effective fluid bulk modulus [Pa]";
  parameter Real C_leak = 5.0e-14 "Internal leakage conductance [m3/(s.Pa)]";

  // ---- Hydraulic supply (declared) ----
  parameter Real p_s = 14.0e6 "Declared supply pressure [Pa]";
  parameter Real p_t = 0.20e6 "Declared return/tank pressure [Pa]";

  // ---- Valve ----
  parameter Real Q_max = 0.001 "Valve command magnitude bound [m3/s]";

  // ---- End stops ----
  parameter Real k_stop = 1.0e7 "End-stop stiffness [N/m]";
  parameter Real d_stop = 1.0e4 "End-stop damping [N.s/m]";
  parameter Real x_tol = 1.0e-4 "End-stop engagement margin [m]";

  // ---- Friction ----
  parameter Real F_coul = 20.0 "Coulomb friction magnitude [N]";
  parameter Real v_small = 0.005 "Friction smoothing velocity [m/s]";
  parameter Real b_visc = 12000.0 "Viscous damping coefficient [N.s/m]";

  // ---- Reference / scenario ----
  parameter Real x0 = 0.0 "Initial coordinate [m]";
  parameter Real x_target = 0.70 * L_stroke "Target = 70 percent of stroke [m]";

  // ---- Controller (250 Hz pressure-aware PID) ----
  parameter Real Ts = 1.0 / 250.0 "Controller sample period [s]";
  parameter Real Kp = 0.0020 "Proportional gain [m3/s per m]";
  parameter Real Ki = 0.00040 "Integral gain [m3/s per (m.s)]";
  parameter Real Kd = 0.00080 "Velocity-feedback gain [m3/s per (m/s)]";
  parameter Real Kff = 1.0e-8 "Pressure feedforward gain [m3/s per N]";

  // ---- Continuous states ----
  Real x(start = x0, fixed = true) "Piston position [m]";
  Real v(start = 0.0, fixed = true) "Piston velocity [m/s]";
  Real p_a(start = (p_s + p_t) / 2.0, fixed = true) "Cap-side pressure [Pa]";
  Real p_b(start = (p_s + p_t) / 2.0, fixed = true) "Rod-side pressure [Pa]";

  // ---- Discrete controller / valve states ----
  discrete Real u_cmd(start = 0.0) "Valve command [m3/s]";
  discrete Real u_unsat(start = 0.0) "Unsaturated command [m3/s]";
  discrete Real ie(start = 0.0) "Integral of position error [m.s]";
  discrete Real x_s(start = x0) "Sampled position [m]";
  discrete Real v_s(start = 0.0) "Sampled velocity [m/s]";
  discrete Real p_a_s(start = (p_s + p_t) / 2.0) "Sampled cap pressure [Pa]";
  discrete Real p_b_s(start = (p_s + p_t) / 2.0) "Sampled rod pressure [Pa]";
  discrete Boolean saturated(start = false) "Anti-windup flag";

  // ---- Derived / measured ----
  Real F_pressure "Net pressure force [N]";
  Real F_end "End-stop force [N]";
  Real F_ext "External load [N]";
  Real F_fric "Friction force [N]";
  Real Q_leak "Leakage flow a->b [m3/s]";
  Real V_a "Cap-side volume [m3]";
  Real V_b "Rod-side volume [m3]";

  // ---- Synchronized sensor traces ----
  Real y_x "Position sensor [m]";
  Real y_v "Velocity sensor [m/s]";
  Real y_pa "Cap pressure sensor [Pa]";
  Real y_pb "Rod pressure sensor [Pa]";
  Real y_u "Valve command sensor [m3/s]";

  // ---- Acceptance (fail-closed) ----
  Real tracking_error "Absolute position error [m]";
  Boolean pass_travel;
  Boolean pass_valve;
  Boolean pass_pressure;
  Boolean pass_velocity;
  Boolean pass_final;
  Boolean pass_tracking;
  Boolean pass_finite;
  Boolean pass_all;

equation
  // Chamber volumes
  V_a = V_a0 + A_a * x;
  V_b = V_b0 + A_b * (L_stroke - x);

  // Net pressure force on piston
  F_pressure = A_a * p_a - A_b * p_b;

  // Smoothed Coulomb friction + viscous damping
  F_fric = -F_coul * tanh(v / v_small) - b_visc * v;

  // Mechanical end stops
  F_end = if x < -x_tol then
           -k_stop * (x + x_tol) - d_stop * v
         elseif x > L_stroke + x_tol then
           -k_stop * (x - L_stroke - x_tol) - d_stop * v
         else
           0.0;

  // External 120 N disturbance in middle third of travel (opposes extension)
  F_ext = if (x >= L_stroke / 3.0 and x <= 2.0 * L_stroke / 3.0) then 120.0 else 0.0;

  // Mechanical dynamics
  der(x) = v;
  m * der(v) = F_pressure + F_end + F_fric - F_ext;

  // Internal cross-port leakage
  Q_leak = C_leak * (p_a - p_b);

  // Pressure dynamics: continuity with fluid compressibility
  // u_cmd > 0 meters supply to cap, tank from rod (extension)
  der(p_a) = (Beta / V_a) * (u_cmd - A_a * v - Q_leak);
  der(p_b) = (Beta / V_b) * (-u_cmd + A_b * v + Q_leak);

  // Synchronized sensors
  y_x = x;
  y_v = v;
  y_pa = p_a;
  y_pb = p_b;
  y_u = u_cmd;

  // Tracking error metric
  tracking_error = abs(x - x_target);

  // ---- Acceptance bounds (fail-closed) ----
  pass_travel = (x >= -1.0e-3) and (x <= L_stroke + 1.0e-3);
  pass_valve = (abs(u_cmd) <= Q_max + 1.0e-9);
  pass_pressure = (p_a >= -1.0e3) and (p_a <= p_s + 5.0e6)
               and (p_b >= -1.0e3) and (p_b <= p_s + 5.0e6);
  pass_velocity = (abs(v) <= 10.0);
  pass_final = (time < 16.0 - 1.0e-6) or (abs(x - x_target) <= 0.011);
  pass_tracking = (time < 10.4) or (abs(x - x_target) < 0.011);
  pass_finite = (abs(x) <= 1.0e30) and (abs(v) <= 1.0e30)
             and (abs(p_a) <= 1.0e30) and (abs(p_b) <= 1.0e30)
             and (abs(u_cmd) <= 1.0e30) and (abs(ie) <= 1.0e30)
             and (abs(tracking_error) <= 1.0e30);
  pass_all = pass_travel and pass_valve and pass_pressure and pass_velocity
          and pass_final and pass_tracking and pass_finite;

algorithm
  when sample(0, Ts) then
    // Synchronized sampling of plant state
    x_s := x;
    v_s := v;
    p_a_s := p_a;
    p_b_s := p_b;

    // Pressure-aware PID: position error + integral + velocity feedback
    // plus feedforward of net pressure force
    u_unsat := Kp * (x_target - x_s) + Ki * ie - Kd * v_s
             + Kff * (-(A_a * p_a_s - A_b * p_b_s));

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

    // Anti-windup: integrate unless saturated in same direction as error
    if (not saturated) or ((x_target - x_s) * u_unsat <= 0.0) then
      ie := ie + (x_target - x_s) * Ts;
    else
      ie := ie;
    end if;
  end when;

  annotation(
    experiment(StartTime = 0, StopTime = 16, Tolerance = 1e-6, Interval = 0.004),
    Documentation(info = "Hydraulic double-acting cylinder position control. Plant: two compressible chambers, four-way proportional valve (flow-commanded), declared supply/return pressure, internal leakage, mechanical end stops. Pressure-aware PID at 250 Hz. 120 N disturbance over middle third of stroke. Target 70% of 0.50 m travel = 0.35 m. Fail-closed acceptance for travel, valve, pressure, velocity, final position, and tracking error after 10.4 s.")
  );
end HydCylinderPositionE;