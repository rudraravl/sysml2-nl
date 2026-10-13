model AirStageTrackA
  // ---- Carriage and cylinder (assumed where not stated in requirement) ----
  parameter Real m_carriage(unit="kg") = 42.0 "carriage mass";
  parameter Real stroke(unit="m") = 0.70 "travel";
  parameter Real A_cap(unit="m2") = 0.0050 "cap-side area (assumed, unequal to rod)";
  parameter Real A_rod(unit="m2") = 0.0030 "rod-side area (assumed, unequal to cap)";
  parameter Real V_Adead(unit="m3") = 5.0e-5 "cap-side dead volume (assumed)";
  parameter Real V_Bdead(unit="m3") = 5.0e-5 "rod-side dead volume (assumed)";
  parameter Real P_supply(unit="Pa") = 7.0e5 "supply pressure (assumed)";
  parameter Real P_atm(unit="Pa") = 1.01325e5 "atmospheric pressure";
  parameter Real P_relief(unit="Pa") = 8.0e5 "relief-valve pressure bound (assumed)";
  parameter Real R_air(unit="J/(kg.K)") = 287.0 "specific gas constant of air";
  parameter Real T_air(unit="K") = 293.15 "gas temperature (assumed isothermal)";
  parameter Real n_poly = 1.2 "polytropic exponent (assumed)";
  parameter Real b_visc(unit="N.s/m") = 50.0 "viscous friction coefficient (assumed)";
  parameter Real k_leak(unit="kg/(s.Pa)") = 1.0e-9 "inter-chamber leakage conductance (assumed)";
  parameter Real k_relief(unit="kg/(s.Pa)") = 1.0e-6 "relief valve conductance (assumed)";
  parameter Real m_dot_max(unit="kg/s") = 0.011 "command magnitude limit";

  // ---- Scenario timing ----
  parameter Real t_sim(unit="s") = 8.0 "scenario duration";
  parameter Real f_ctrl(unit="Hz") = 80.0 "control / sample rate";
  parameter Real t_payload_start(unit="s") = 2.6667 "middle-third start";
  parameter Real t_payload_end(unit="s") = 5.3333 "middle-third end";
  parameter Real F_payload(unit="N") = 110.0 "payload disturbance magnitude";
  parameter Real t_seg1(unit="s") = 4.0 "first segment duration (assumed)";
  parameter Real x_seg1(unit="m") = 0.45 "first-segment target (assumed within stroke)";
  parameter Real x_final(unit="m") = 0.70 "final target equals stroke";
  parameter Real t_check(unit="s") = 5.2 "primary tracking-error check time";

  // ---- Controller gains (assumed tuning) ----
  parameter Real P_nom(unit="Pa") = 3.0e5 "nominal chamber pressure (assumed)";
  parameter Real Kff = 1.0 "feedforward gain";
  parameter Real Kp_pos(unit="kg/(m.s)") = 0.20 "position-to-flow feedback gain (assumed)";
  parameter Real Kp_pres(unit="kg/(s.Pa)") = 2.0e-7 "pressure-to-flow feedback gain (assumed)";

  // ---- Bounds ----
  parameter Real a_bound(unit="m/s2") = 12.0 "acceleration bound (assumed)";
  parameter Real e_traj_bound(unit="m") = 0.060 "overall trajectory-error bound (assumed)";
  parameter Real e_traj_final(unit="m") = 0.024 "primary tracking-error bound after 5.2 s";
  parameter Real x_margin(unit="m") = 1.0e-3 "travel margin";
  parameter Real p_margin(unit="Pa") = 1.0e5 "pressure margin";

  // ---- States ----
  Real x(unit="m", start=0.0, fixed=true) "carriage position (upward positive)";
  Real v(unit="m/s", start=0.0, fixed=true) "carriage velocity";
  Real a(unit="m/s2") "carriage acceleration";
  Real P_A(unit="Pa", start=2.0e5, fixed=true) "cap-side pressure";
  Real P_B(unit="Pa", start=1.95993e5, fixed=true) "rod-side pressure";

  // ---- Derived quantities ----
  Real V_A(unit="m3") "cap-side volume";
  Real V_B(unit="m3") "rod-side volume";

  // ---- Mass flows ----
  Real m_dot_A_fill(unit="kg/s") "cap-side fill mass flow";
  Real m_dot_A_exhaust(unit="kg/s") "cap-side exhaust mass flow";
  Real m_dot_B_fill(unit="kg/s") "rod-side fill mass flow";
  Real m_dot_B_exhaust(unit="kg/s") "rod-side exhaust mass flow";
  Real m_dot_leak(unit="kg/s") "inter-chamber leakage (A->B positive)";
  Real m_dot_supply(unit="kg/s") "total supply (pump) flow";
  Real m_dot_A_relief(unit="kg/s") "cap-side relief flow";
  Real m_dot_B_relief(unit="kg/s") "rod-side relief flow";

  // ---- Commands ----
  Real u_A_raw(unit="kg/s") "cap-side raw command";
  Real u_B_raw(unit="kg/s") "rod-side raw command";
  Real u_A(unit="kg/s") "cap-side limited command";
  Real u_B(unit="kg/s") "rod-side limited command";

  // ---- Trajectory ----
  Real x_ref(unit="m") "reference position";
  Real v_ref(unit="m/s") "reference velocity";
  Real a_ref(unit="m/s2") "reference acceleration";

  // ---- Controller internals ----
  Real F_ff(unit="N") "feedforward force (trajectory-based only)";
  Real P_A_ref(unit="Pa") "cap-side reference pressure";
  Real P_B_ref(unit="Pa") "rod-side reference pressure";
  Real e_pos(unit="m") "position tracking error (ref - actual)";

  // ---- Disturbance ----
  Real F_dist(unit="N") "payload disturbance force (downward)";

  // ---- Records / bounds ----
  Real e_traj(unit="m") "absolute trajectory error";
  discrete Real e_traj_after(unit="m") "tracking error sampled at 5.2 s";
  Boolean b_travel "travel bound satisfied";
  Boolean b_pressure "pressure bound satisfied";
  Boolean b_flow "flow bound satisfied";
  Boolean b_accel "acceleration bound satisfied";
  Boolean b_traj "trajectory-error bound satisfied";
  Boolean b_traj_final "primary tracking-error bound satisfied";
  Boolean b_relief "relief-valve inactive bound satisfied";
  Boolean b_finite "no NaN/infinite physical, control, or estimator values";

protected
  constant Real pi = Modelica.Constants.pi;
  Real c1 = 0.5*x_seg1*(pi/t_seg1);
  Real c2 = 0.5*x_seg1*(pi/t_seg1)^2;
  Real d1 = 0.5*(x_final - x_seg1)*(pi/(t_sim - t_seg1));
  Real d2 = 0.5*(x_final - x_seg1)*(pi/(t_sim - t_seg1))^2;

equation
  // ---- Volumes ----
  V_A = V_Adead + A_cap*x;
  V_B = V_Bdead + A_rod*(stroke - x);

  // ---- Two-segment smooth trajectory (cosine blends, continuous velocity) ----
  x_ref = if time < t_seg1 then
            x_seg1*0.5*(1.0 - Modelica.Math.cos(pi*time/t_seg1))
          else
            x_seg1 + (x_final - x_seg1)*0.5*(1.0 - Modelica.Math.cos(pi*(time - t_seg1)/(t_sim - t_seg1)));
  v_ref = if time < t_seg1 then
            c1*Modelica.Math.sin(pi*time/t_seg1)
          else
            d1*Modelica.Math.sin(pi*(time - t_seg1)/(t_sim - t_seg1));
  a_ref = if time < t_seg1 then
            c2*Modelica.Math.cos(pi*time/t_seg1)
          else
            d2*Modelica.Math.cos(pi*(time - t_seg1)/(t_sim - t_seg1));

  // ---- Finite-duration payload disturbance (middle third) ----
  F_dist = if time >= t_payload_start and time <= t_payload_end then F_payload else 0.0;

  // ---- Equation of motion (vertical, x upward) ----
  m_carriage*a = P_A*A_cap - P_B*A_rod - m_carriage*Modelica.Constants.g_n - b_visc*v - F_dist;
  der(x) = v;
  der(v) = a;

  // ---- Feedforward (trajectory-only; disturbance unknown to controller) ----
  F_ff = m_carriage*a_ref + m_carriage*Modelica.Constants.g_n + b_visc*v_ref;
  P_A_ref = (F_ff + 2.0*P_nom*A_rod)/(A_cap + A_rod);
  P_B_ref = (2.0*P_nom*A_cap - F_ff)/(A_cap + A_rod);
  e_pos = x_ref - x;

  // ---- Feedforward flow + pressure-position feedback ----
  u_A_raw = Kff*(P_A*A_cap*v_ref/(R_air*T_air)) + Kp_pres*(P_A_ref - P_A) + Kp_pos*e_pos;
  u_B_raw = -Kff*(P_B*A_rod*v_ref/(R_air*T_air)) + Kp_pres*(P_B_ref - P_B) - Kp_pos*e_pos;

  // ---- Command magnitude limit ----
  u_A = if u_A_raw > m_dot_max then m_dot_max else if u_A_raw < -m_dot_max then -m_dot_max else u_A_raw;
  u_B = if u_B_raw > m_dot_max then m_dot_max else if u_B_raw < -m_dot_max then -m_dot_max else u_B_raw;

  // ---- Split command into fill / exhaust (positive = fill, negative = exhaust) ----
  m_dot_A_fill     = if u_A > 0.0 then u_A else 0.0;
  m_dot_A_exhaust  = if u_A < 0.0 then -u_A else 0.0;
  m_dot_B_fill     = if u_B > 0.0 then u_B else 0.0;
  m_dot_B_exhaust  = if u_B < 0.0 then -u_B else 0.0;

  // ---- Inter-chamber leakage (A to B when P_A > P_B) ----
  m_dot_leak = k_leak*(P_A - P_B);

  // ---- Relief valves (vent when pressure exceeds bound) ----
  m_dot_A_relief = if P_A > P_relief then k_relief*(P_A - P_relief) else 0.0;
  m_dot_B_relief = if P_B > P_relief then k_relief*(P_B - P_relief) else 0.0;

  // ---- Pressure dynamics (polytropic, finite dead volumes) ----
  der(P_A) = (n_poly*R_air*T_air/V_A)*(m_dot_A_fill - m_dot_A_exhaust - m_dot_leak - m_dot_A_relief)
             - (n_poly*P_A/V_A)*(A_cap*v);
  der(P_B) = (n_poly*R_air*T_air/V_B)*(m_dot_B_fill - m_dot_B_exhaust + m_dot_leak - m_dot_B_relief)
             - (n_poly*P_B/V_B)*(-A_rod*v);

  // ---- Supply (pump) flow ----
  m_dot_supply = m_dot_A_fill + m_dot_B_fill;

  // ---- Trajectory error ----
  e_traj = abs(x_ref - x);

  // ---- Sample primary tracking error at 5.2 s ----
  when time >= t_check then
    e_traj_after = abs(x_ref - x);
  end when;

  // ---- Bound checks ----
  b_travel    = (x >= -x_margin) and (x <= stroke + x_margin);
  b_pressure  = (P_A <= P_relief + p_margin) and (P_B <= P_relief + p_margin)
                and (P_A >= 0.0) and (P_B >= 0.0);
  b_flow      = (abs(u_A) <= m_dot_max + 1.0e-9) and (abs(u_B) <= m_dot_max + 1.0e-9);
  b_accel     = abs(a) <= a_bound;
  b_traj      = e_traj <= e_traj_bound;
  b_traj_final = (time < t_check) or (abs(x_ref - x) < e_traj_final);
  b_relief    = (m_dot_A_relief <= 1.0e-9) and (m_dot_B_relief <= 1.0e-9);
  // Finite check: detect NaN (x <> x) and Inf; treat as not-finite if outside sane ranges
  b_finite    = (x == x) and (v == v) and (a == a)
                and (P_A == P_A) and (P_B == P_B)
                and (u_A == u_A) and (u_B == u_B)
                and (x_ref == x_ref) and (e_pos == e_pos)
                and (x > -1.0e6) and (x < 1.0e6)
                and (P_A > -1.0e6) and (P_A < 1.0e8)
                and (P_B > -1.0e6) and (P_B < 1.0e8);

  // ---- Hard assertions (with margins so as not to halt a healthy run) ----
  assert(b_travel,    "Travel bound violated");
  assert(b_pressure,  "Pressure bound violated");
  assert(b_flow,      "Flow (command) bound violated");
  assert(b_accel,     "Acceleration bound violated");
  assert(b_traj,      "Trajectory-error bound violated");
  assert(b_traj_final, "Primary tracking error below 0.024 m after 5.2 s violated");
  assert(b_relief,    "Relief-valve bound violated (relief active)");
  assert(b_finite,     "NaN or infinite physical, control, or estimator value detected");

  annotation(
    experiment(StopTime=8.0, Tolerance=1e-6, StartTime=0, Interval=0.0125),
    Documentation(info="AirStageTrackA: vertical pneumatic servo-actuator with two-segment smooth trajectory, feedforward flow + pressure-position feedback, viscous friction, inter-chamber leakage, finite-duration 110 N payload step over the middle third, relief valves, and bound checks. Physical cylinder geometry, supply pressure, gas temperature, friction, leakage, and control gains are assumed (commented) where not specified by the requirement.")
  );
end AirStageTrackA;