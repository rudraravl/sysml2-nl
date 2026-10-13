model AirStageTrackA
  // ------------------------------------------------------------------
  // Physical constants (SI)
  // ------------------------------------------------------------------
  constant Real R_air = 287.0 "J/(kg.K) specific gas constant of air";
  constant Real T_air = 293.15 "K chamber gas temperature (isothermal)";
  constant Real Patm = 101325.0 "Pa atmospheric pressure";
  constant Real g = 9.81 "m/s2 gravitational acceleration";

  // ------------------------------------------------------------------
  // Plant parameters (assumed values where request is silent)
  // ------------------------------------------------------------------
  parameter Real m_carriage = 42.0 "kg vertical carriage mass";
  parameter Real L = 0.70 "m cylinder stroke";
  parameter Real A1 = 0.0019635 "m2 cap-side area (assumed 50 mm bore)";
  parameter Real A2 = 0.0016493 "m2 rod-side area (assumed 20 mm rod)";
  parameter Real Vd1 = 0.0001374 "m3 cap-side dead volume (assumed)";
  parameter Real Vd2 = 0.0001374 "m3 rod-side dead volume (assumed)";
  parameter Real b_vis = 500.0 "N.s/m viscous friction coefficient (assumed)";
  parameter Real Cleak = 5.0e-10 "kg/(s.Pa) interchamber leakage conductance (assumed)";
  parameter Real Ps = 7.0e5 "Pa supply/pump pressure (assumed)";
  parameter Real P_relief = 8.5e5 "Pa chamber relief pressure (assumed)";
  parameter Real Krelief = 1.0e-7 "kg/(s.Pa) relief valve conductance (assumed)";

  // ------------------------------------------------------------------
  // Controller parameters (assumed)
  // ------------------------------------------------------------------
  parameter Real Kp_pos = 8000.0 "N/m position gain (assumed)";
  parameter Real Kd_pos = 400.0 "N.s/m velocity gain (assumed)";
  parameter Real Kp_p1 = 3.0e-6 "kg/(s.N) chamber-1 force/flow gain (assumed)";
  parameter Real Kp_p2 = 3.0e-6 "kg/(s.N) chamber-2 force/flow gain (assumed)";
  parameter Real Ki_p1 = 1.0e-7 "kg/(s.N.s) chamber-1 integral gain (assumed)";
  parameter Real Ki_p2 = 1.0e-7 "kg/(s.N.s) chamber-2 integral gain (assumed)";
  parameter Real u_max = 0.011 "kg/s per-valve command magnitude limit";
  parameter Real Ts = 0.0125 "s controller sample period (80 Hz)";

  // ------------------------------------------------------------------
  // Scenario timing
  // ------------------------------------------------------------------
  parameter Real t_end = 8.0 "s total run time";
  parameter Real t_dist_start = 8.0/3.0 "s payload disturbance start (middle third)";
  parameter Real t_dist_end = 16.0/3.0 "s payload disturbance end (middle third)";
  parameter Real F_payload = 110.0 "N payload step disturbance magnitude";

  // Trajectory segment timing (two-segment smooth motion over 0.70 m)
  parameter Real seg1_t0 = 0.5 "s";
  parameter Real seg1_t1 = 3.0 "s";
  parameter Real seg1_x0 = 0.0 "m";
  parameter Real seg1_x1 = 0.35 "m";
  parameter Real seg2_t0 = 4.5 "s";
  parameter Real seg2_t1 = 7.0 "s";
  parameter Real seg2_x0 = 0.35 "m";
  parameter Real seg2_x1 = 0.70 "m";

  // Bounds (assumed where request is silent)
  parameter Real x_max_allowed = 0.75 "m travel bound";
  parameter Real P_max_allowed = P_relief "Pa pressure upper bound";
  parameter Real P_min_allowed = 0.5*Patm "Pa pressure lower bound";
  parameter Real supply_flow_max = 2.0*u_max "kg/s supply flow bound";
  parameter Real a_max_allowed = 30.0 "m/s2 acceleration bound";
  parameter Real track_err_bound = 0.05 "m general trajectory-error bound";
  parameter Real track_err_bound_final = 0.024 "m primary bound after 5.2 s";

  // ------------------------------------------------------------------
  // Initial conditions (chosen to balance gravity at rest)
  // ------------------------------------------------------------------
protected
  parameter Real P2_0 = Patm "Pa initial rod-side pressure";
  parameter Real P1_0 = (m_carriage*g + P2_0*A2)/A1 "Pa initial cap-side pressure";
  parameter Real V1_0 = Vd1 + A1*0.0 "m3";
  parameter Real V2_0 = Vd2 + A2*L "m3";
  parameter Real m1_0 = P1_0*V1_0/(R_air*T_air) "kg";
  parameter Real m2_0 = P2_0*V2_0/(R_air*T_air) "kg";

  // Discrete controller temporaries
  discrete Real e_x_d;
  discrete Real e_v_d;
  discrete Real F_ff_d;
  discrete Real F_err_d;
  discrete Real q1_ff_d;
  discrete Real q2_ff_d;
  discrete Real qsat1_d;
  discrete Real qsat2_d;

public
  // ------------------------------------------------------------------
  // Continuous states
  // ------------------------------------------------------------------
  Real x(start=0.0, fixed=true) "m carriage position";
  Real v(start=0.0, fixed=true) "m/s carriage velocity";
  Real m1(start=m1_0) "kg cap-side chamber mass";
  Real m2(start=m2_0) "kg rod-side chamber mass";

  // Derived physical quantities
  Real V1 "m3 cap-side volume";
  Real V2 "m3 rod-side volume";
  Real P1 "Pa cap-side pressure";
  Real P2 "Pa rod-side pressure";
  Real a "m/s2 carriage acceleration";
  Real F_piston "N net piston force";
  Real payload "N applied payload disturbance force";
  Real leak "kg/s interchamber leakage mass flow";
  Real relief1 "kg/s cap-side relief flow";
  Real relief2 "kg/s rod-side relief flow";
  Real supply_flow "kg/s total supply/pump mass flow";
  Real track_err "m trajectory tracking error";

  // Trajectory references
  Real x_ref "m reference position";
  Real v_ref "m/s reference velocity";
  Real a_ref "m/s2 reference acceleration";

  // Valve commands (discrete, held between samples)
  discrete Real u1f "kg/s cap-side fill valve command";
  discrete Real u1e "kg/s cap-side exhaust valve command";
  discrete Real u2f "kg/s rod-side fill valve command";
  discrete Real u2e "kg/s rod-side exhaust valve command";
  discrete Real q1n_d "kg/s net chamber-1 mass flow (pre-split)";
  discrete Real q2n_d "kg/s net chamber-2 mass flow (pre-split)";
  discrete Real integ1 "chamber-1 integral state";
  discrete Real integ2 "chamber-2 integral state";

  // ------------------------------------------------------------------
  // Trajectory helper functions (two-segment smooth step)
  // ------------------------------------------------------------------
protected
  function sstep
    input Real t;
    input Real t0;
    input Real t1;
    output Real s "normalized smooth step in [0,1]";
  algorithm
    if t1 - t0 > 1.0e-9 then
      s := (t - t0)/(t1 - t0);
    else
      s := 0.0;
    end if;
    s := max(0.0, min(1.0, s));
    s := 3.0*s*s - 2.0*s*s*s;
  end sstep;

  function sstep_d
    "first derivative of smooth step w.r.t. time"
    input Real t;
    input Real t0;
    input Real t1;
    output Real d "1/s derivative";
  protected
    Real s;
  algorithm
    if t1 - t0 > 1.0e-9 then
      s := (t - t0)/(t1 - t0);
    else
      s := 0.0;
    end if;
    s := max(0.0, min(1.0, s));
    d := (6.0*s - 6.0*s*s)/(t1 - t0);
  end sstep_d;

  function sstep_dd
    "second derivative of smooth step w.r.t. time"
    input Real t;
    input Real t0;
    input Real t1;
    output Real dd "1/s2 second derivative";
  protected
    Real s;
  algorithm
    if t1 - t0 > 1.0e-9 then
      s := (t - t0)/(t1 - t0);
    else
      s := 0.0;
    end if;
    s := max(0.0, min(1.0, s));
    dd := (6.0 - 12.0*s)/((t1 - t0)*(t1 - t0));
  end sstep_dd;

public
equation
  // ------------------------------------------------------------------
  // Trajectory generation (continuous, two-segment smooth profile)
  // ------------------------------------------------------------------
  x_ref = if time < seg1_t0 then seg1_x0
          else if time < seg1_t1 then seg1_x0 + (seg1_x1 - seg1_x0)*sstep(time, seg1_t0, seg1_t1)
          else if time < seg2_t0 then seg1_x1
          else if time < seg2_t1 then seg2_x0 + (seg2_x1 - seg2_x0)*sstep(time, seg2_t0, seg2_t1)
          else seg2_x1;

  v_ref = if time < seg1_t0 then 0.0
          else if time < seg1_t1 then (seg1_x1 - seg1_x0)*sstep_d(time, seg1_t0, seg1_t1)
          else if time < seg2_t0 then 0.0
          else if time < seg2_t1 then (seg2_x1 - seg2_x0)*sstep_d(time, seg2_t0, seg2_t1)
          else 0.0;

  a_ref = if time < seg1_t0 then 0.0
          else if time < seg1_t1 then (seg1_x1 - seg1_x0)*sstep_dd(time, seg1_t0, seg1_t1)
          else if time < seg2_t0 then 0.0
          else if time < seg2_t1 then (seg2_x1 - seg2_x0)*sstep_dd(time, seg2_t0, seg2_t1)
          else 0.0;

  // ------------------------------------------------------------------
  // Payload disturbance (finite-duration step, middle third of scenario)
  // ------------------------------------------------------------------
  payload = if (time >= t_dist_start and time <= t_dist_end) then F_payload else 0.0;

  // ------------------------------------------------------------------
  // Chamber volumes, pressures (isothermal ideal gas)
  // ------------------------------------------------------------------
  V1 = Vd1 + A1*x;
  V2 = Vd2 + A2*(L - x);
  P1 = m1 * R_air * T_air / V1;
  P2 = m2 * R_air * T_air / V2;

  // ------------------------------------------------------------------
  // Leakage and relief flows
  // ------------------------------------------------------------------
  leak = Cleak * (P1 - P2);
  relief1 = max(0.0, Krelief * (P1 - P_relief));
  relief2 = max(0.0, Krelief * (P2 - P_relief));

  // ------------------------------------------------------------------
  // Chamber mass dynamics
  // ------------------------------------------------------------------
  der(m1) = u1f - u1e - relief1 - leak;
  der(m2) = u2f - u2e - relief2 + leak;

  // ------------------------------------------------------------------
  // Supply / pump flow (sum of fill commands)
  // ------------------------------------------------------------------
  supply_flow = u1f + u2f;

  // ------------------------------------------------------------------
  // Mechanical dynamics (vertical motion, upward positive)
  // ------------------------------------------------------------------
  F_piston = P1 * A1 - P2 * A2;
  a = (F_piston - m_carriage * g - payload - b_vis * v) / m_carriage;
  der(x) = v;
  der(v) = a;

  // ------------------------------------------------------------------
  // Tracking error
  // ------------------------------------------------------------------
  track_err = x_ref - x;

  // ------------------------------------------------------------------
  // Discrete controller: feedforward flow + pressure/position feedback
  // sampled at 80 Hz
  // ------------------------------------------------------------------
  when sample(0.0, Ts) then
    e_x_d := x_ref - x;
    e_v_d := v_ref - v;

    // Feedforward force required for reference motion plus gravity
    // (payload disturbance is NOT feedforward compensated by design)
    F_ff_d := m_carriage * a_ref + b_vis * v_ref + m_carriage * g;

    // Force error including position/velocity feedback
    F_err_d := F_ff_d - (P1 * A1 - P2 * A2) + Kp_pos * e_x_d + Kd_pos * e_v_d;

    // Feedforward mass flow from reference velocity (isothermal)
    q1_ff_d := P1 * A1 * v_ref / (R_air * T_air);
    q2_ff_d := -P2 * A2 * v_ref / (R_air * T_air);

    // Integral states (simple, with per-sample gain)
    integ1 := pre(integ1) + Ki_p1 * F_err_d * Ts;
    integ2 := pre(integ2) - Ki_p2 * F_err_d * Ts;

    // Net commanded chamber mass flows
    q1n_d := q1_ff_d + Kp_p1 * F_err_d + integ1;
    q2n_d := q2_ff_d - Kp_p2 * F_err_d + integ2;

    // Per-valve command magnitude limit (0.011 kg/s)
    qsat1_d := max(-u_max, min(u_max, q1n_d));
    qsat2_d := max(-u_max, min(u_max, q2n_d));

    // Split net flow into independent fill and exhaust valve commands
    u1f := if qsat1_d >= 0.0 then qsat1_d else 0.0;
    u1e := if qsat1_d >= 0.0 then 0.0 else -qsat1_d;
    u2f := if qsat2_d >= 0.0 then qsat2_d else 0.0;
    u2e := if qsat2_d >= 0.0 then 0.0 else -qsat2_d;
  end when;

  // ------------------------------------------------------------------
  // Physical, control, and estimator integrity checks
  // ------------------------------------------------------------------
  // No NaN / infinity checks (x == x is false for NaN)
  assert(x == x, "NaN detected in x");
  assert(v == v, "NaN detected in v");
  assert(m1 == m1, "NaN detected in m1");
  assert(m2 == m2, "NaN detected in m2");
  assert(P1 == P1, "NaN detected in P1");
  assert(P2 == P2, "NaN detected in P2");
  assert(u1f == u1f, "NaN detected in u1f");
  assert(u1e == u1e, "NaN detected in u1e");
  assert(u2f == u2f, "NaN detected in u2f");
  assert(u2e == u2e, "NaN detected in u2e");
  assert(x > -1.0e6 and x < 1.0e6, "Infinite value detected in x");
  assert(v > -1.0e6 and v < 1.0e6, "Infinite value detected in v");
  assert(P1 > -1.0e6 and P1 < 1.0e7, "Infinite value detected in P1");
  assert(P2 > -1.0e6 and P2 < 1.0e7, "Infinite value detected in P2");

  // Travel bound
  assert(x >= -0.001 and x <= x_max_allowed,
    "Travel bound violated: x outside admissible range");

  // Pressure bounds
  assert(P1 >= P_min_allowed and P1 <= P_max_allowed,
    "Pressure bound violated for chamber 1");
  assert(P2 >= P_min_allowed and P2 <= P_max_allowed,
    "Pressure bound violated for chamber 2");

  // Supply flow bound
  assert(supply_flow >= 0.0 and supply_flow <= supply_flow_max + 1.0e-9,
    "Supply flow bound violated");

  // Acceleration bound
  assert(abs(a) <= a_max_allowed,
    "Acceleration bound violated");

  // General trajectory-error bound
  assert(abs(track_err) <= track_err_bound,
    "General trajectory-error bound violated");

  // Relief-valve flow bounds (nonnegative and finite)
  assert(relief1 >= 0.0 and relief1 <= Krelief * (P_max_allowed - P_relief) + 1.0e-6,
    "Relief-valve bound violated for chamber 1");
  assert(relief2 >= 0.0 and relief2 <= Krelief * (P_max_allowed - P_relief) + 1.0e-6,
    "Relief-valve bound violated for chamber 2");

  // Primary tracking-error bound after 5.2 s
  assert(time < 5.2 or abs(track_err) <= track_err_bound_final + 1.0e-9,
    "Primary tracking error exceeds 0.024 m after 5.2 s");

  annotation(
    Documentation(info = "AirStageTrackA: vertical pneumatic actuator with two-segment smooth position trajectory, independent fill/exhaust proportional valves per chamber (0.011 kg/s command limit), viscous friction, interchamber leakage, relief valves, and a 110 N payload step disturbance during the middle third of an 8 s scenario sampled at 80 Hz. Values for bore, rod, dead volumes, supply pressure, relief pressure, friction, leakage, and controller gains are assumed because they are not stated in the requirement."),
    experiment(StartTime = 0.0, StopTime = 8.0, Tolerance = 1.0e-6, Interval = 0.0125));
end AirStageTrackA;