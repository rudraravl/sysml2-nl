model AirStageConserveB
  /* ============================================================
     AirStageConserveB
     Energy-aware pneumatic double-acting cylinder actuation cycle.
     Stated requirement values are factual; unstated values are
     design assumptions labeled "(assumed)".
     ============================================================ */

  // ---- Stated requirement parameters ----
  parameter Real m_carriage(final unit="kg") = 42        "Carriage mass";
  parameter Real L_stroke(final unit="m")   = 0.70      "Cylinder stroke";
  parameter Real u_max(final unit="kg/s")   = 0.012     "Allowed valve command magnitude";
  parameter Real F_dist(final unit="N")     = 126       "Load variation disturbance";
  parameter Real f_sample(final unit="Hz")  = 100       "Sample rate";
  parameter Real t_end(final unit="s")      = 10        "Simulation duration";
  parameter Real e_track_cap(final unit="m") = 0.024    "Tracking error cap after 6.5 s";
  parameter Real t_check(final unit="s")     = 6.5      "Tracking deadline";

  // ---- Design-assumption parameters (unstated; chosen for feasible operation) ----
  parameter Real A1(final unit="m2") = 0.0050  "Cap-side piston area (assumed)";
  parameter Real A2(final unit="m2") = 0.0030  "Rod-side piston area (assumed)";
  parameter Real V1d(final unit="m3") = 5.0e-5 "Cap-side dead volume (assumed)";
  parameter Real V2d(final unit="m3") = 5.0e-5 "Rod-side dead volume (assumed)";
  parameter Real Ps(final unit="Pa")  = 7.0e5  "Supply pressure (assumed)";
  parameter Real Pr(final unit="Pa")  = 1.0e5  "Return/exhaust pressure (assumed)";
  parameter Real T_gas(final unit="K") = 293.15 "Gas temperature (assumed, isothermal)";
  parameter Real R_air(final unit="J/(kg.K)") = 287.0 "Specific gas constant air";
  parameter Real g(final unit="m/s2") = 9.81   "Gravity";
  parameter Real m_air_cap(final unit="kg") = 0.20 "Declared air-use cap (assumed)";
  parameter Real T_cycle(final unit="s") = 3.3333 "Cycle period: ~3 cycles in 10 s (assumed)";
  // Controller gains (assumed)
  parameter Real Kp(final unit="1/s2") = 18.0  "Position gain (assumed)";
  parameter Real Kd(final unit="1/s")  = 6.0   "Velocity gain (assumed)";
  parameter Real Kf(final unit="(kg/s)/N") = 1.2e-5 "Force-to-flow gain (assumed)";
  // Hard stops (assumed)
  parameter Real ks_stop(final unit="N/m") = 1.0e6 "Hard-stop stiffness (assumed)";
  parameter Real cs_stop(final unit="N/(m/s)") = 1.0e4 "Hard-stop damping (assumed)";

  // ---- Disturbance window (middle third of run) ----
  Real t_dist_start(final unit="s") = t_end / 3.0;
  Real t_dist_end(final unit="s")   = 2.0 * t_end / 3.0;

  // ---- Dynamic states ----
  Real x(final unit="m", start=0.0) "Carriage position (0=retracted, L=extended)";
  Real v(final unit="m/s", start=0.0) "Carriage velocity (upward positive)";
  Real P1(final unit="Pa", start=1.5e5) "Cap-side chamber pressure";
  Real P2(final unit="Pa", start=1.0e5) "Rod-side chamber pressure";
  Real m_air_acc(final unit="kg", start=0.0) "Accumulated supply air mass";
  Real E_acc(final unit="J", start=0.0) "Accumulated supply flow energy";

  // ---- Derived physical quantities ----
  Real V1(final unit="m3") "Cap-side volume";
  Real V2(final unit="m3") "Rod-side volume";
  Real F_pneu(final unit="N") "Net pneumatic force (upward positive)";
  Real F_grav(final unit="N") "Gravity force";
  Real F_dist_inst(final unit="N") "Instantaneous disturbance force";
  Real F_load(final unit="N") "Total load";
  Real F_stop(final unit="N") "Hard-stop force";
  Real P1_gauge(final unit="Pa") "Gauge pressure chamber 1";
  Real P2_gauge(final unit="Pa") "Gauge pressure chamber 2";

  // ---- Reference & control ----
  Real x_ref(final unit="m") "Reference position";
  Real v_ref(final unit="m/s") "Reference velocity";
  Real e_track(final unit="m") "Tracking error";
  Real degrade(final unit="1") "Bounded performance degradation factor (0.3..1.0)";
  Real F_des(final unit="N") "Desired force";
  Real F_err(final unit="N") "Force error";
  Real u1_raw(final unit="kg/s") "Raw net mass flow cmd chamber 1";
  Real u2_raw(final unit="kg/s") "Raw net mass flow cmd chamber 2";
  Real u1_sat(final unit="kg/s") "Saturated net cmd chamber 1";
  Real u2_sat(final unit="kg/s") "Saturated net cmd chamber 2";
  Real fill1(final unit="kg/s") "Fill valve cmd chamber 1 (>=0)";
  Real exh1(final unit="kg/s")  "Exhaust valve cmd chamber 1 (>=0)";
  Real fill2(final unit="kg/s") "Fill valve cmd chamber 2 (>=0)";
  Real exh2(final unit="kg/s")  "Exhaust valve cmd chamber 2 (>=0)";

  // ---- Mass flows ----
  Real m_dot1(final unit="kg/s") "Net mass flow into chamber 1";
  Real m_dot2(final unit="kg/s") "Net mass flow into chamber 2";
  Real m_dot_supply(final unit="kg/s") "Total supply mass flow";

  // ---- Cycle phase ----
  Real cycle_phase(final unit="rad") "Cycle phase";

  // ---- Monitoring / status ----
  Real e_track_abs(final unit="m") "Absolute tracking error";
  Real e_track_late(final unit="m") "Tracking error after deadline";
  Boolean cycle_reached_top "Reached top of stroke at least once";
  Boolean air_cap_ok "Air-use cap satisfied";
  Boolean bounds_ok "Physical bounds satisfied";

protected
  parameter Real pi = 3.14159265358979;

equation
  // --- Chamber volumes (explicit dead volumes) ---
  V1 = V1d + A1 * x;
  V2 = V2d + A2 * (L_stroke - x);

  // --- Forces ---
  F_grav = m_carriage * g;
  F_dist_inst = if (time >= t_dist_start and time <= t_dist_end) then F_dist else 0.0;
  F_load = F_grav + F_dist_inst;
  F_pneu = P1 * A1 - P2 * A2;

  // --- Hard stops ---
  F_stop = if x < 0.0 then (-ks_stop * x - cs_stop * v)
           else if x > L_stroke then (-ks_stop * (x - L_stroke) - cs_stop * v)
           else 0.0;

  // --- Newton's second law (upward positive) ---
  der(x) = v;
  m_carriage * der(v) = F_pneu - F_load + F_stop;

  // --- Chamber pressure dynamics: ideal gas, isothermal compressibility ---
  // dP/dt = (R*T/V) * dm/dt - (P/V) * dV/dt
  der(P1) = (R_air * T_gas / noEvent(max(V1, 1.0e-8))) * m_dot1
            - (P1 / noEvent(max(V1, 1.0e-8))) * (A1 * v);
  der(P2) = (R_air * T_gas / noEvent(max(V2, 1.0e-8))) * m_dot2
            - (P2 / noEvent(max(V2, 1.0e-8))) * (-A2 * v);

  // --- Valve mass flows from saturated commands ---
  m_dot1 = u1_sat;
  m_dot2 = u2_sat;
  m_dot_supply = fill1 + fill2;

  // --- Accumulated supply air mass and flow energy ---
  // Flow-work rate from supply: dE/dt = m_dot_supply * R * T  (P/rho = R*T)
  der(m_air_acc) = m_dot_supply;
  der(E_acc) = m_dot_supply * R_air * T_gas;

  // --- Cyclic reference (smooth 0 -> L -> 0) ---
  cycle_phase = 2.0 * pi * time / T_cycle;
  x_ref = 0.5 * L_stroke * (1.0 - cos(cycle_phase));
  v_ref = 0.5 * L_stroke * (2.0 * pi / T_cycle) * sin(cycle_phase);

  // --- Energy-aware bounded performance degradation ---
  // 1.0 when air usage < 80% of cap, linearly drops to 0.3 at cap (bounded).
  degrade = 1.0 - 0.7 * noEvent(max(0.0, min(1.0,
            (m_air_acc - 0.8 * m_air_cap) / (0.2 * m_air_cap))));

  // --- PD position control with feedforward load and degradation ---
  e_track = x_ref - x;
  F_des = m_carriage * (Kp * e_track + Kd * (v_ref - v)) * degrade + F_load;
  F_err = F_des - F_pneu;

  // --- Force error to independent chamber valve commands ---
  u1_raw = Kf * F_err;
  u2_raw = -0.5 * Kf * F_err;

  // --- Valve saturation to allowed command magnitude ---
  u1_sat = noEvent(max(-u_max, min(u_max, u1_raw)));
  u2_sat = noEvent(max(-u_max, min(u_max, u2_raw)));

  // --- Independent fill / exhaust decomposition (non-negative) ---
  fill1 = noEvent(max(0.0, u1_sat));
  exh1  = noEvent(max(0.0, -u1_sat));
  fill2 = noEvent(max(0.0, u2_sat));
  exh2  = noEvent(max(0.0, -u2_sat));

  // --- Instrumentation: gauge pressures ---
  P1_gauge = P1 - Pr;
  P2_gauge = P2 - Pr;

  // --- Monitoring quantities ---
  e_track_abs = noEvent(abs(e_track));
  e_track_late = if time >= t_check then e_track_abs else 0.0;
  cycle_reached_top = noEvent(x >= 0.999 * L_stroke);
  air_cap_ok = noEvent(m_air_acc <= m_air_cap * 1.05);
  bounds_ok = noEvent(x >= -0.002 and x <= L_stroke + 0.002
           and P1 > 0.0 and P2 > 0.0
           and m_air_acc >= 0.0 and E_acc >= 0.0);

  // --- Requirement assertions ---
  assert(time < t_check or e_track_abs < e_track_cap,
         "Primary tracking error exceeds 0.024 m after 6.5 s");
  assert(m_air_acc <= m_air_cap * 1.05,
         "Declared air-use cap exceeded");
  assert(x >= -0.01 and x <= L_stroke + 0.01,
         "Carriage position out of physical bounds");
  assert(P1 > 0.0 and P2 > 0.0,
         "Chamber pressure non-positive (compressibility violated)");
  assert(not (P1 > 1.0e8) and not (P2 > 1.0e8),
         "Pressure unbounded / possibly infinite");
  assert(not (v > 1.0e3),
         "Velocity unbounded / possibly infinite");

annotation(
  experiment(StartTime = 0, StopTime = 10, Tolerance = 1.0e-6, Interval = 0.01),
  Documentation(info = "AirStageConserveB: energy-aware pneumatic actuator.
Completes a repeated actuation cycle (0 to 0.70 m and back) while bounding
accumulated supply air mass.  Middle-third disturbance of 126 N injected.
All unstated parameters (areas, dead volumes, pressures, gains, cap, period)
are design assumptions labeled '(assumed)'; only requirement-stated values
(42 kg, 0.70 m, 0.012 kg/s, 126 N, 100 Hz, 10 s, 0.024 m, 6.5 s) are factual.")
);
end AirStageConserveB;