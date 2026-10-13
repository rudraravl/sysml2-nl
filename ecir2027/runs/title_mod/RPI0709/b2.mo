model AirStageTrackA
  constant Real R_air = 287.052873 "J/(kg.K) specific gas constant of air";
  constant Real T_air = 293.15 "K chamber gas temperature (isothermal)";
  constant Real Patm = 101325.0 "Pa atmospheric pressure";
  constant Real g = 9.81 "m/s2 gravitational acceleration";

  parameter Real m_carriage = 42.0 "kg vertical carriage mass";
  parameter Real L = 0.70 "m cylinder stroke";
  parameter Real A1 = 0.0019635 "m2 cap-side area";
  parameter Real A2 = 0.0016493 "m2 rod-side area";
  parameter Real Vd1 = 0.0001374 "m3 cap-side dead volume";
  parameter Real Vd2 = 0.0001374 "m3 rod-side dead volume";
  parameter Real b_vis = 500.0 "N.s/m viscous friction coefficient";
  parameter Real Cleak = 1.0e-12 "kg/(s.Pa) interchamber leakage conductance";
  parameter Real Ps = 7.0e5 "Pa supply/pump pressure";
  parameter Real P_relief = 8.5e5 "Pa chamber relief pressure";
  parameter Real Krelief = 1.0e-7 "kg/(s.Pa) relief valve conductance";

  parameter Real Kp_pos = 8000.0 "N/m position gain";
  parameter Real Kd_pos = 400.0 "N.s/m velocity gain";
  parameter Real Kp_p1 = 3.0e-6 "kg/(s.N) chamber-1 flow gain";
  parameter Real Kp_p2 = 3.0e-6 "kg/(s.N) chamber-2 flow gain";
  parameter Real Ki_p1 = 5.0e-7 "kg/(s.N.s) chamber-1 integral gain";
  parameter Real Ki_p2 = 5.0e-7 "kg/(s.N.s) chamber-2 integral gain";
  parameter Real u_max = 0.011 "kg/s per-valve command magnitude limit";
  parameter Real Ts = 0.0125 "s controller sample period (80 Hz)";

  parameter Real t_end = 8.0 "s total run time";
  parameter Real t_dist_start = 8.0/3.0 "s payload disturbance start";
  parameter Real t_dist_end = 16.0/3.0 "s payload disturbance end";
  parameter Real F_payload = 110.0 "N payload step disturbance magnitude";

  parameter Real seg1_t0 = 0.5 "s";
  parameter Real seg1_t1 = 3.0 "s";
  parameter Real seg1_x0 = 0.0 "m";
  parameter Real seg1_x1 = 0.35 "m";
  parameter Real seg2_t0 = 4.5 "s";
  parameter Real seg2_t1 = 7.0 "s";
  parameter Real seg2_x0 = 0.35 "m";
  parameter Real seg2_x1 = 0.70 "m";

  parameter Real x_min_allowed = -0.01 "m";
  parameter Real x_max_allowed = 0.75 "m";
  parameter Real P_max_allowed = 9.0e5 "Pa";
  parameter Real P_min_allowed = 3.0e4 "Pa";
  parameter Real supply_flow_max = 0.022 "kg/s";
  parameter Real a_max_allowed = 30.0 "m/s2";
  parameter Real track_err_bound = 0.05 "m";
  parameter Real track_err_bound_final = 0.024 "m";
  parameter Real relief_max = Krelief * (P_max_allowed - P_relief) "kg/s";

  parameter Real P2_0 = Patm "Pa";
  parameter Real P1_0 = (m_carriage * g + P2_0 * A2) / A1 "Pa";
  parameter Real V1_0 = Vd1 "m3";
  parameter Real V2_0 = Vd2 + A2 * L "m3";
  parameter Real m1_0 = P1_0 * V1_0 / (R_air * T_air) "kg";
  parameter Real m2_0 = P2_0 * V2_0 / (R_air * T_air) "kg";

  Real x(start = 0.0, fixed = true) "m carriage position";
  Real v(start = 0.0, fixed = true) "m/s carriage velocity";
  Real m1(start = m1_0, fixed = true) "kg cap-side chamber mass";
  Real m2(start = m2_0, fixed = true) "kg rod-side chamber mass";

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
  Real x_ref "m reference position";
  Real v_ref "m/s reference velocity";
  Real a_ref "m/s2 reference acceleration";

  Real r1 "normalized time for segment 1";
  Real rc1 "clamped normalized time for segment 1";
  Real s1 "smooth step for segment 1";
  Real ds1 "derivative of smooth step for segment 1";
  Real dds1 "second derivative of smooth step for segment 1";

  Real r2 "normalized time for segment 2";
  Real rc2 "clamped normalized time for segment 2";
  Real s2 "smooth step for segment 2";
  Real ds2 "derivative of smooth step for segment 2";
  Real dds2 "second derivative of smooth step for segment 2";

  discrete Real u1f(start = 0.0, fixed = true) "kg/s cap-side fill valve command";
  discrete Real u1e(start = 0.0, fixed = true) "kg/s cap-side exhaust valve command";
  discrete Real u2f(start = 0.0, fixed = true) "kg/s rod-side fill valve command";
  discrete Real u2e(start = 0.0, fixed = true) "kg/s rod-side exhaust valve command";
  discrete Real integ1(start = 0.0, fixed = true) "kg/s chamber-1 integral state";
  discrete Real integ2(start = 0.0, fixed = true) "kg/s chamber-2 integral state";
  discrete Real e_x_d(start = 0.0, fixed = true) "m position error sample";
  discrete Real e_v_d(start = 0.0, fixed = true) "m/s velocity error sample";
  discrete Real F_ff_d(start = 0.0, fixed = true) "N feedforward force sample";
  discrete Real F_err_d(start = 0.0, fixed = true) "N force error sample";
  discrete Real q1_ff_d(start = 0.0, fixed = true) "kg/s chamber-1 feedforward flow";
  discrete Real q2_ff_d(start = 0.0, fixed = true) "kg/s chamber-2 feedforward flow";
  discrete Real q1n_d(start = 0.0, fixed = true) "kg/s net chamber-1 mass flow";
  discrete Real q2n_d(start = 0.0, fixed = true) "kg/s net chamber-2 mass flow";
  discrete Real qsat1_d(start = 0.0, fixed = true) "kg/s saturated chamber-1 command";
  discrete Real qsat2_d(start = 0.0, fixed = true) "kg/s saturated chamber-2 command";

equation
  r1 = (time - seg1_t0) / (seg1_t1 - seg1_t0);
  rc1 = max(0.0, min(1.0, r1));
  s1 = 3.0 * rc1 * rc1 - 2.0 * rc1 * rc1 * rc1;
  ds1 = 6.0 * rc1 - 6.0 * rc1 * rc1;
  dds1 = 6.0 - 12.0 * rc1;

  r2 = (time - seg2_t0) / (seg2_t1 - seg2_t0);
  rc2 = max(0.0, min(1.0, r2));
  s2 = 3.0 * rc2 * rc2 - 2.0 * rc2 * rc2 * rc2;
  ds2 = 6.0 * rc2 - 6.0 * rc2 * rc2;
  dds2 = 6.0 - 12.0 * rc2;

  x_ref = if time <= seg1_t0 then seg1_x0
          else if time <= seg1_t1 then seg1_x0 + (seg1_x1 - seg1_x0) * s1
          else if time <= seg2_t0 then seg1_x1
          else if time <= seg2_t1 then seg2_x0 + (seg2_x1 - seg2_x0) * s2
          else seg2_x1;

  v_ref = if time <= seg1_t0 then 0.0
          else if time <= seg1_t1 then (seg1_x1 - seg1_x0) * ds1 / (seg1_t1 - seg1_t0)
          else if time <= seg2_t0 then 0.0
          else if time <= seg2_t1 then (seg2_x1 - seg2_x0) * ds2 / (seg2_t1 - seg2_t0)
          else 0.0;

  a_ref = if time <= seg1_t0 then 0.0
          else if time <= seg1_t1 then (seg1_x1 - seg1_x0) * dds1 / ((seg1_t1 - seg1_t0)*(seg1_t1 - seg1_t0))
          else if time <= seg2_t0 then 0.0
          else if time <= seg2_t1 then (seg2_x1 - seg2_x0) * dds2 / ((seg2_t1 - seg2_t0)*(seg2_t1 - seg2_t0))
          else 0.0;

  payload = if time >= t_dist_start and time <= t_dist_end then F_payload else 0.0;

  V1 = Vd1 + A1 * x;
  V2 = Vd2 + A2 * (L - x);
  P1 = m1 * R_air * T_air / V1;
  P2 = m2 * R_air * T_air / V2;

  leak = Cleak * (P1 - P2);
  relief1 = max(0.0, Krelief * (P1 - P_relief));
  relief2 = max(0.0, Krelief * (P2 - P_relief));

  der(m1) = u1f - u1e - relief1 - leak;
  der(m2) = u2f - u2e - relief2 + leak;

  supply_flow = u1f + u2f;

  F_piston = P1 * A1 - P2 * A2;
  a = (F_piston - m_carriage * g - payload - b_vis * v) / m_carriage;
  der(x) = v;
  der(v) = a;

  track_err = x_ref - x;

  when sample(0.0, Ts) then
    e_x_d := x_ref - x;
    e_v_d := v_ref - v;
    F_ff_d := m_carriage * a_ref + b_vis * v_ref + m_carriage * g;
    F_err_d := F_ff_d - (P1 * A1 - P2 * A2) + Kp_pos * e_x_d + Kd_pos * e_v_d;
    q1_ff_d := P1 * A1 * v_ref / (R_air * T_air);
    q2_ff_d := -P2 * A2 * v_ref / (R_air * T_air);
    integ1 := pre(integ1) + Ki_p1 * F_err_d * Ts;
    integ2 := pre(integ2) - Ki_p2 * F_err_d * Ts;
    q1n_d := q1_ff_d + Kp_p1 * F_err_d + integ1;
    q2n_d := q2_ff_d - Kp_p2 * F_err_d + integ2;
    qsat1_d := max(-u_max, min(u_max, q1n_d));
    qsat2_d := max(-u_max, min(u_max, q2n_d));
    u1f := if qsat1_d >= 0.0 then qsat1_d else 0.0;
    u1e := if qsat1_d >= 0.0 then 0.0 else -qsat1_d;
    u2f := if qsat2_d >= 0.0 then qsat2_d else 0.0;
    u2e := if qsat2_d >= 0.0 then 0.0 else -qsat2_d;
  end when;

  assert(x >= x_min_allowed and x <= x_max_allowed, "Travel bound violated");
  assert(P1 >= P_min_allowed and P1 <= P_max_allowed, "Pressure bound violated for chamber 1");
  assert(P2 >= P_min_allowed and P2 <= P_max_allowed, "Pressure bound violated for chamber 2");
  assert(supply_flow >= 0.0 and supply_flow <= supply_flow_max + 1.0e-9, "Supply flow bound violated");
  assert(abs(a) <= a_max_allowed, "Acceleration bound violated");
  assert(abs(track_err) <= track_err_bound, "General trajectory-error bound violated");
  assert(relief1 >= 0.0 and relief1 <= relief_max + 1.0e-6, "Relief-valve bound violated for chamber 1");
  assert(relief2 >= 0.0 and relief2 <= relief_max + 1.0e-6, "Relief-valve bound violated for chamber 2");
  assert(time < 5.2 or abs(track_err) <= track_err_bound_final + 1.0e-9, "Primary tracking error exceeds 0.024 m after 5.2 s");

  annotation(
    Documentation(info = "AirStageTrackA: vertical pneumatic actuator with two-segment smooth position trajectory, independent fill/exhaust proportional valves per chamber (0.011 kg/s command limit), viscous friction, interchamber leakage, relief valves, and a 110 N payload step disturbance during the middle third of an 8 s scenario sampled at 80 Hz. Values not stated in the requirement (bore, rod diameter, dead volumes, supply pressure, relief pressure, friction, leakage conductance, controller gains) are assumed."),
    experiment(StartTime = 0.0, StopTime = 8.0, Tolerance = 1.0e-6, Interval = 0.0125));
end AirStageTrackA;