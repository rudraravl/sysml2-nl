model AirStageForceA
  // Physical constants
  constant Real p_atm(unit="Pa") = 101325.0;
  constant Real R_air(unit="J/(kg.K)") = 287.05;
  constant Real T_air(unit="K") = 293.15;
  constant Real g(unit="m/s2") = 9.81;

  // Values stated by the requirement
  parameter Real m(unit="kg") = 42.0;
  parameter Real L(unit="m") = 0.70;
  parameter Real w_max(unit="kg/s") = 0.011;
  parameter Real F_dist_amp(unit="N") = 75.0;
  parameter Real Ts(unit="s") = 1.0/80.0;
  parameter Real t_dist_on(unit="s") = 8.0/3.0;
  parameter Real t_dist_off(unit="s") = 16.0/3.0;
  parameter Real F_err_limit(unit="N") = 27.0;

  // Assumed nominal values for facts not stated by the requirement.
  // They are bound so the model is self-contained and FMU-exportable.
  parameter Real A_a(unit="m2") = 0.0019634954084936207 "bore-side area";
  parameter Real A_b(unit="m2") = 0.0014726215563700235 "rod-side area";
  parameter Real Vd_a(unit="m3") = 1.0e-5 "dead volume, chamber A";
  parameter Real Vd_b(unit="m3") = 1.0e-5 "dead volume, chamber B";
  parameter Real p_supply(unit="Pa") = 6.0e5 "supply pressure";
  parameter Real p_relief(unit="Pa") = 7.0e5 "relief pressure";
  parameter Real k_relief(unit="kg/(s.Pa)") = 1.0e-6 "relief conductance";
  parameter Real w_relief_max(unit="kg/s") = 0.1 "relief flow bound";
  parameter Real p_bias(unit="Pa") = 2.0e5 "regulated rod-side pressure";
  parameter Real k_load(unit="N/m") = 5000.0 "compliant load stiffness";
  parameter Real c_load(unit="N.s/m") = 800.0 "compliant load damping";
  parameter Real x_free(unit="m") = 0.33 "fixed support/load zero point";
  parameter Real x0(unit="m") = 0.35 "initial carriage position";
  parameter Real F_cmd(unit="N") = 100.0 "commanded contact force";
  parameter Real Kp_p(unit="kg/(s.Pa)") = 3.0e-7 "inner pressure P gain";
  parameter Real Ki_p(unit="kg/(s2.Pa)") = 3.0e-6 "inner pressure I gain";
  parameter Real Kf(unit="Pa/N") = 300.0 "outer force P gain";
  parameter Real Kfi(unit="Pa/(N.s)") = 100.0 "outer force I gain";
  parameter Real end_margin(unit="m") = 0.02 "no-end-stop margin";
  parameter Real v_hold_limit(unit="m/s") = 0.05 "stable-hold velocity limit";

  // Derived equilibrium pressure
  parameter Real pA0(unit="Pa") = (F_cmd + m*g + p_bias*A_b)/A_a;

  // Continuous physical states
  Real x(start=x0, fixed=true, unit="m");
  Real v(start=0.0, fixed=true, unit="m/s");
  Real pA(start=pA0, fixed=true, unit="Pa");
  Real pB(start=p_bias, fixed=true, unit="Pa");

  // Continuous physical variables
  Real F_contact(unit="N");
  Real F_dist(unit="N");
  Real F_err(unit="N");
  Real Fp(unit="N");
  Real V_A(unit="m3");
  Real V_B(unit="m3");
  Real dpA(unit="Pa/s");
  Real dpB(unit="Pa/s");
  Real w_fillA(unit="kg/s");
  Real w_exhA(unit="kg/s");
  Real w_fillB(unit="kg/s");
  Real w_exhB(unit="kg/s");
  Real w_reliefA(unit="kg/s");
  Real w_reliefB(unit="kg/s");

  // Discrete controller variables
  discrete Real pA_cmd(start=pA0, unit="Pa");
  discrete Real F_int(start=0.0, unit="N.s");
  discrete Real pA_int(start=0.0, unit="Pa.s");
  discrete Real pB_int(start=0.0, unit="Pa.s");
  discrete Real w_fillA_cmd(start=0.0, unit="kg/s");
  discrete Real w_exhA_cmd(start=0.0, unit="kg/s");
  discrete Real w_fillB_cmd(start=0.0, unit="kg/s");
  discrete Real w_exhB_cmd(start=0.0, unit="kg/s");

  // Synchronized 80 Hz traces
  discrete Real x_s(start=x0, unit="m");
  discrete Real v_s(start=0.0, unit="m/s");
  discrete Real pA_s(start=pA0, unit="Pa");
  discrete Real pB_s(start=p_bias, unit="Pa");
  discrete Real F_contact_s(start=F_cmd, unit="N");
  discrete Real F_err_s(start=0.0, unit="N");
  discrete Real w_fillA_s(start=0.0, unit="kg/s");
  discrete Real w_exhA_s(start=0.0, unit="kg/s");
  discrete Real w_fillB_s(start=0.0, unit="kg/s");
  discrete Real w_exhB_s(start=0.0, unit="kg/s");

  // Monitors
  Boolean no_endstop_impact;
  Boolean pressure_bounds_ok;
  Boolean flow_bounds_ok;
  Boolean force_band_ok;
  Boolean stable_hold_ok;
  Boolean finite_ok;

  // Observable outputs
  output Real pA_meas(unit="Pa") = pA;
  output Real pB_meas(unit="Pa") = pB;
  output Real x_meas(unit="m") = x;
  output Real v_meas(unit="m/s") = v;
  output Real F_contact_meas(unit="N") = F_contact;
  output Real F_err_out(unit="N") = F_err;
  output Real Fp_meas(unit="N") = Fp;
  output Real w_fillA_out(unit="kg/s") = w_fillA_cmd;
  output Real w_exhA_out(unit="kg/s") = w_exhA_cmd;
  output Real w_fillB_out(unit="kg/s") = w_fillB_cmd;
  output Real w_exhB_out(unit="kg/s") = w_exhB_cmd;

protected
  discrete Real e_F(start=0.0, unit="N");
  discrete Real pA_ff(start=pA0, unit="Pa");
  discrete Real pA_cmd_raw(start=pA0, unit="Pa");
  discrete Real e_pA(start=0.0, unit="Pa");
  discrete Real e_pB(start=0.0, unit="Pa");
  discrete Real w_netA_raw(start=0.0, unit="kg/s");
  discrete Real w_netA_sat(start=0.0, unit="kg/s");
  discrete Real w_netB_raw(start=0.0, unit="kg/s");
  discrete Real w_netB_sat(start=0.0, unit="kg/s");

equation
  // Actuator state
  der(x) = v;
  der(v) = (pA*A_a - pB*A_b - m*g - F_contact - F_dist)/m;

  // Compliant mechanical load against fixed support
  F_contact = k_load*(x - x_free) + c_load*v;
  Fp = pA*A_a - pB*A_b;
  F_err = F_cmd - F_contact;

  // Controlled load disturbance during middle third of 8 s scenario
  F_dist = if time >= t_dist_on and time <= t_dist_off then F_dist_amp else 0.0;

  // Chamber volumes with explicit dead volumes
  V_A = Vd_a + A_a*x;
  V_B = Vd_b + A_b*(L - x);

  // Supply-limited fill, independent exhaust, and relief protection
  w_fillA = if pA < p_supply then w_fillA_cmd else 0.0;
  w_exhA = if pA > 0.0 then w_exhA_cmd else 0.0;
  w_reliefA = if pA > p_relief then min(k_relief*(pA - p_relief), w_relief_max) else 0.0;

  w_fillB = if pB < p_supply then w_fillB_cmd else 0.0;
  w_exhB = if pB > 0.0 then w_exhB_cmd else 0.0;
  w_reliefB = if pB > p_relief then min(k_relief*(pB - p_relief), w_relief_max) else 0.0;

  // Pneumatic chamber pressure dynamics
  dpA = (R_air*T_air/V_A)*(w_fillA - w_exhA - w_reliefA) - ((pA + p_atm)/V_A)*(A_a*v);
  dpB = (R_air*T_air/V_B)*(w_fillB - w_exhB - w_reliefB) + ((pB + p_atm)/V_B)*(A_b*v);

  der(pA) = if pA <= 0.0 and dpA < 0.0 then 0.0 else dpA;
  der(pB) = if pB <= 0.0 and dpB < 0.0 then 0.0 else dpB;

  // Requirement monitors
  no_endstop_impact = x > end_margin and x < L - end_margin;
  pressure_bounds_ok = pA >= 0.0 and pA <= p_relief + 1000.0 and
                       pB >= 0.0 and pB <= p_relief + 1000.0;
  flow_bounds_ok = w_fillA_cmd >= -1.0e-12 and w_fillA_cmd <= w_max + 1.0e-12 and
                   w_exhA_cmd >= -1.0e-12 and w_exhA_cmd <= w_max + 1.0e-12 and
                   w_fillB_cmd >= -1.0e-12 and w_fillB_cmd <= w_max + 1.0e-12 and
                   w_exhB_cmd >= -1.0e-12 and w_exhB_cmd <= w_max + 1.0e-12 and
                   w_reliefA >= 0.0 and w_reliefA <= w_relief_max + 1.0e-12 and
                   w_reliefB >= 0.0 and w_reliefB <= w_relief_max + 1.0e-12;
  force_band_ok = if time < 5.2 then true else abs(F_err) <= F_err_limit;
  stable_hold_ok = if time < 7.0 then true else abs(v) <= v_hold_limit;
  finite_ok = abs(x) < 1.0e9 and abs(v) < 1.0e9 and
              abs(pA) < 1.0e9 and abs(pB) < 1.0e9 and
              abs(F_contact) < 1.0e9 and abs(F_err) < 1.0e9 and
              abs(Fp) < 1.0e9 and abs(pA_cmd) < 1.0e9 and
              abs(F_int) < 1.0e9 and abs(pA_int) < 1.0e9 and
              abs(pB_int) < 1.0e9 and abs(w_fillA_cmd) < 1.0e9 and
              abs(w_exhA_cmd) < 1.0e9 and abs(w_fillB_cmd) < 1.0e9 and
              abs(w_exhB_cmd) < 1.0e9;

  assert(no_endstop_impact, "end-stop impact or margin violated");
  assert(pressure_bounds_ok, "pressure bounds violated");
  assert(flow_bounds_ok, "flow bounds violated");
  assert(force_band_ok, "primary force tracking error band violated after 5.2 s");
  assert(stable_hold_ok, "stable hold violated");
  assert(finite_ok, "non-finite physical, control, or estimator value");

algorithm
  when sample(0.0, Ts) then
    // Outer force loop: cascaded to inner pressure setpoint
    e_F := F_cmd - F_contact;
    pA_ff := (F_cmd + m*g + F_dist + p_bias*A_b)/A_a;
    pA_cmd_raw := pA_ff + Kf*e_F + Kfi*F_int;
    pA_cmd := max(0.0, min(p_supply, pA_cmd_raw));

    // Force integrator anti-windup
    if (pA_cmd_raw >= 0.0 and pA_cmd_raw <= p_supply) then
      F_int := F_int + Ts*e_F;
    elseif (pA_cmd_raw > p_supply and e_F < 0.0) then
      F_int := F_int + Ts*e_F;
    elseif (pA_cmd_raw < 0.0 and e_F > 0.0) then
      F_int := F_int + Ts*e_F;
    end if;

    // Inner pressure loop for chamber A
    e_pA := pA_cmd - pA;
    w_netA_raw := Kp_p*e_pA + Ki_p*pA_int;
    w_netA_sat := max(-w_max, min(w_max, w_netA_raw));
    if abs(w_netA_raw) <= w_max then
      pA_int := pA_int + Ts*e_pA;
    elseif w_netA_raw > w_max and e_pA < 0.0 then
      pA_int := pA_int + Ts*e_pA;
    elseif w_netA_raw < -w_max and e_pA > 0.0 then
      pA_int := pA_int + Ts*e_pA;
    end if;
    w_fillA_cmd := max(w_netA_sat, 0.0);
    w_exhA_cmd := max(-w_netA_sat, 0.0);

    // Inner pressure loop for chamber B
    e_pB := p_bias - pB;
    w_netB_raw := Kp_p*e_pB + Ki_p*pB_int;
    w_netB_sat := max(-w_max, min(w_max, w_netB_raw));
    if abs(w_netB_raw) <= w_max then
      pB_int := pB_int + Ts*e_pB;
    elseif w_netB_raw > w_max and e_pB < 0.0 then
      pB_int := pB_int + Ts*e_pB;
    elseif w_netB_raw < -w_max and e_pB > 0.0 then
      pB_int := pB_int + Ts*e_pB;
    end if;
    w_fillB_cmd := max(w_netB_sat, 0.0);
    w_exhB_cmd := max(-w_netB_sat, 0.0);

    // Synchronized 80 Hz state, command, and sensor traces
    x_s := x;
    v_s := v;
    pA_s := pA;
    pB_s := pB;
    F_contact_s := F_contact;
    F_err_s := F_err;
    w_fillA_s := w_fillA_cmd;
    w_exhA_s := w_exhA_cmd;
    w_fillB_s := w_fillB_cmd;
    w_exhB_s := w_exhB_cmd;
  end when;

  annotation(experiment(StopTime=8.0, Interval=0.0125, Tolerance=1e-6));
end AirStageForceA;