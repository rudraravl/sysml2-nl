model HydCylinderTrackB
  // Cylinder and payload facts stated by the requirement
  parameter Real A_p(unit="m2") = 0.0040 "Piston-side active area";
  parameter Real A_r(unit="m2") = 0.0032 "Rod-side active area";
  parameter Real L(unit="m") = 0.50 "Cylinder stroke";
  parameter Real m(unit="kg") = 110 "Moving mass";
  parameter Real Qmax(unit="m3/s") = 0.001 "Allowed command magnitude";
  parameter Real Fpayload(unit="N") = 154 "Finite-duration payload step magnitude";
  parameter Real Ts(unit="s") = 0.01 "100 Hz control and trace period";
  parameter Real Trun(unit="s") = 10.0 "Mission duration";

  // Trajectory shape and endpoints: smooth quintic rest-to-rest two-segment path.
  // Segment split and endpoints are explicit assumptions; only bounds and requested
  // numeric facts are asserted as requirements.
  parameter Real T1(unit="s") = 5.0 "First segment duration";
  parameter Real T2(unit="s") = 10.0 "Second segment end time";
  parameter Real x_start(unit="m") = 0.05;
  parameter Real x_mid(unit="m") = 0.45;
  parameter Real x_end(unit="m") = 0.05;

  // Unspecified physical values are explicit finite assumptions
  parameter Real beta(unit="Pa") = 1.0e7 "Effective bulk modulus";
  parameter Real V0A(unit="m3") = 1.0e-4 "Cap-side dead volume";
  parameter Real V0B(unit="m3") = 1.0e-4 "Rod-side dead volume";
  parameter Real b(unit="N.s/m") = 2000.0 "Viscous friction coefficient";
  parameter Real Cleak(unit="m3/(s.Pa)") = 1.0e-14 "Internal leakage conductance";
  parameter Real pSupply(unit="Pa") = 12.5e6 "Assumed supply pressure";
  parameter Real pRelief(unit="Pa") = 1.2*pSupply "Relief-valve pressure bound";
  parameter Real kRel(unit="m3/(s.Pa)") = 1.0e-8 "Relief-valve conductance";
  parameter Real kEnd(unit="N/m") = 1.0e7 "End-stop stiffness";
  parameter Real cEnd(unit="N.s/m") = 1.0e5 "End-stop damping";
  parameter Real pA0(unit="Pa") = 2.0e6 "Initial cap-side pressure";
  parameter Real pB0(unit="Pa") = pA0*A_p/A_r "Initial rod-side pressure for zero net force";

  // Controller gains: explicit assumptions
  parameter Real Kx(unit="m2/s") = 0.002 "Position-to-flow gain";
  parameter Real Kfp(unit="N/m") = 50000.0 "Position-error-to-force gain";
  parameter Real Kpf(unit="m3/(s.N)") = 1.0e-7 "Pressure/force feedback gain";

  // Bounds
  parameter Real eBoundAll(unit="m") = 0.05 "Overall trajectory-error bound";
  parameter Real eMaxFinal(unit="m") = 0.022 "Primary tracking-error bound after 6.5 s";
  parameter Real aBound(unit="m/s2") = 50.0 "Acceleration bound";
  parameter Real QreliefBound(unit="m3/s") = 0.02 "Assumed relief-valve flow bound";

  // Continuous states
  Real x(unit="m", start=x_start, fixed=true) "Piston position";
  Real v(unit="m/s", start=0.0, fixed=true) "Piston velocity";
  Real pA(unit="Pa", start=pA0, fixed=true) "Cap-side chamber pressure";
  Real pB(unit="Pa", start=pB0, fixed=true) "Rod-side chamber pressure";

  // Continuous instrumentation and computed quantities
  Real a(unit="m/s2") "Acceleration";
  Real xd(unit="m") "Desired position";
  Real vd(unit="m/s") "Desired velocity";
  Real ad(unit="m/s2") "Desired acceleration";
  Real e_traj(unit="m") "Tracking error xd - x";
  Real u(unit="m3/s") "Valve command";
  Real Qs(unit="m3/s") "Supply/pump flow through valve";
  Real F_load(unit="N") "Hydraulic extension force";
  Real F_payload(unit="N") "Payload disturbance force";
  Real F_end(unit="N") "End-stop force";
  Real qAin(unit="m3/s") "Flow into cap side from valve";
  Real qBin(unit="m3/s") "Flow into rod side from valve";
  Real qLeak(unit="m3/s") "Internal leakage from A to B";
  Real qRelA(unit="m3/s") "Relief flow from cap side";
  Real qRelB(unit="m3/s") "Relief flow from rod side";
  Real VA(unit="m3") "Cap-side volume";
  Real VB(unit="m3") "Rod-side volume";

  // Synchronized 100 Hz traces
  discrete Real t_log(unit="s", start=0.0);
  discrete Real x_log(unit="m", start=0.0);
  discrete Real v_log(unit="m/s", start=0.0);
  discrete Real pA_log(unit="Pa", start=0.0);
  discrete Real pB_log(unit="Pa", start=0.0);
  discrete Real Qs_log(unit="m3/s", start=0.0);
  discrete Real u_log(unit="m3/s", start=0.0);
  discrete Real e_log(unit="m", start=0.0);
  discrete Real a_log(unit="m/s2", start=0.0);
  discrete Real F_load_log(unit="N", start=0.0);
  discrete Real F_ref_log(unit="N", start=0.0);

  // Discrete control values
  discrete Real u_cmd(unit="m3/s", start=0.0);
  discrete Real u_raw(unit="m3/s", start=0.0);
  discrete Real F_ref(unit="N", start=0.0);

  Real tau1, s1, ds1, dds1;
  Real tau2, s2, ds2, dds2;
  parameter Real Tdist_start(unit="s") = 10.0/3.0 "Middle third start";
  parameter Real Tdist_end(unit="s") = 20.0/3.0 "Middle third end";

equation
  // Smooth two-segment quintic trajectory
  tau1 = if time <= 0.0 then 0.0 elseif time >= T1 then 1.0 else time/T1;
  s1 = 10.0*tau1^3 - 15.0*tau1^4 + 6.0*tau1^5;
  ds1 = 30.0*tau1^2 - 60.0*tau1^3 + 30.0*tau1^4;
  dds1 = 60.0*tau1 - 180.0*tau1^2 + 120.0*tau1^3;

  tau2 = if time <= T1 then 0.0 elseif time >= T2 then 1.0 else (time - T1)/(T2 - T1);
  s2 = 10.0*tau2^3 - 15.0*tau2^4 + 6.0*tau2^5;
  ds2 = 30.0*tau2^2 - 60.0*tau2^3 + 30.0*tau2^4;
  dds2 = 60.0*tau2 - 180.0*tau2^2 + 120.0*tau2^3;

  xd = if time <= T1 then x_start + (x_mid - x_start)*s1 else x_mid + (x_end - x_mid)*s2;
  vd = if time <= T1 then (x_mid - x_start)*ds1/T1 else (x_end - x_mid)*ds2/(T2 - T1);
  ad = if time <= T1 then (x_mid - x_start)*dds1/T1^2 else (x_end - x_mid)*dds2/(T2 - T1)^2;

  e_traj = xd - x;

  // Four-way proportional valve metering
  u = u_cmd;
  qAin = u;
  qBin = -u*(A_r/A_p);
  Qs = max(qAin, 0.0) + max(qBin, 0.0);

  // Leakage and relief
  qLeak = Cleak*(pA - pB);
  qRelA = kRel*max(0.0, pA - pRelief);
  qRelB = kRel*max(0.0, pB - pRelief);

  // Chamber volumes and pressure dynamics
  VA = V0A + A_p*x;
  VB = V0B + A_r*(L - x);
  der(pA) = beta/VA*(qAin - qLeak - qRelA - A_p*v);
  der(pB) = beta/VB*(qBin + qLeak - qRelB + A_r*v);

  // Mechanical dynamics
  der(x) = v;
  a = der(v);
  F_load = pA*A_p - pB*A_r;
  F_payload = if time >= Tdist_start and time <= Tdist_end then Fpayload else 0.0;
  F_end = if x < 0.0 then kEnd*(-x) - cEnd*min(v, 0.0)
          elseif x > L then kEnd*(x - L) - cEnd*max(v, 0.0)
          else 0.0;
  m*a = F_load - b*v - F_payload - F_end;

  // 100 Hz sampled feedforward flow control with pressure-position feedback
  when sample(0, Ts) then
    t_log = time;
    x_log = x;
    v_log = v;
    pA_log = pA;
    pB_log = pB;
    Qs_log = Qs;
    u_log = u_cmd;
    e_log = e_traj;
    a_log = a;
    F_load_log = F_load;

    F_ref = m*ad + b*vd + Kfp*e_traj;
    F_ref_log = F_ref;
    u_raw = A_p*vd + Kx*e_traj + Kpf*(F_ref - F_load);
    u_cmd = if u_raw > Qmax then Qmax elseif u_raw < -Qmax then -Qmax else u_raw;
  end when;

  // Bounds and finite-value checks
  assert(x >= -1.0e-4 and x <= L + 1.0e-4, "travel bound violated");
  assert(pA >= 0.0 and pB >= 0.0, "negative chamber pressure");
  assert(pA <= pRelief + 1.0e3 and pB <= pRelief + 1.0e3, "relief-valve pressure bound violated");
  assert(qRelA >= 0.0 and qRelB >= 0.0, "relief-valve sign bound violated");
  assert(qRelA <= QreliefBound + 1.0e-12 and qRelB <= QreliefBound + 1.0e-12, "relief-valve flow bound violated");
  assert(abs(u) <= Qmax + 1.0e-12, "flow/command bound violated");
  assert(Qs >= 0.0 and Qs <= Qmax + 1.0e-12, "supply flow bound violated");
  assert(abs(a) <= aBound, "acceleration bound violated");
  assert(abs(e_traj) <= eBoundAll, "trajectory-error bound violated");
  assert(time <= 6.5 or abs(e_traj) <= eMaxFinal, "primary tracking error after 6.5 s violated");

  assert(x > -1.0e12 and x < 1.0e12 and
         v > -1.0e12 and v < 1.0e12 and
         pA > -1.0e12 and pA < 1.0e12 and
         pB > -1.0e12 and pB < 1.0e12 and
         u > -1.0e12 and u < 1.0e12 and
         Qs > -1.0e12 and Qs < 1.0e12 and
         e_traj > -1.0e12 and e_traj < 1.0e12 and
         F_load > -1.0e12 and F_load < 1.0e12 and
         F_ref > -1.0e12 and F_ref < 1.0e12 and
         u_cmd > -1.0e12 and u_cmd < 1.0e12,
         "non-finite physical, control, or estimator value detected");

  annotation (experiment(StartTime=0, StopTime=10, Tolerance=1e-6, Interval=0.01));
end HydCylinderTrackB;