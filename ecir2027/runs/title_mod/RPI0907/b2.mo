model CatamaranDockA
  // ---- Physical parameters (from requirement only) ----
  parameter Real m_hull(unit="kg") = 46 "mass of each capsule hull";
  parameter Real m_deck(unit="kg") = 18 "mass of rigid deck";
  parameter Real m(unit="kg") = 2.0*m_hull + m_deck "total dry mass";
  parameter Real hullSep(unit="m") = 1.1 "hull separation";
  parameter Real d(unit="m") = hullSep/2.0 "half separation (propeller lever)";
  parameter Real Izz(unit="kg.m2") = 2.0*m_hull*d*d + m_deck*d*d "yaw inertia about center";
  parameter Real Fmax(unit="N") = 310 "per-propeller command magnitude limit";
  parameter Real Fcurrent(unit="N") = 70 "current disturbance force (middle third)";
  parameter Real fs(unit="Hz") = 80 "control and sensor sampling rate";
  parameter Real Ts(unit="s") = 1.0/fs "sampling period";
  parameter Real tFinal(unit="s") = 8.0 "scenario duration";
  parameter Real tMid1(unit="s") = tFinal/3.0 "start of middle third";
  parameter Real tMid2(unit="s") = 2.0*tFinal/3.0 "end of middle third";

  // ---- Dock / capture ring geometry ----
  parameter Real xDock(unit="m") = 0.0 "fixed funnel center x";
  parameter Real yDock(unit="m") = 0.0 "fixed funnel center y";
  parameter Real captureRadius(unit="m") = 0.25 "compliant capture ring radius";
  parameter Real kCap(unit="N/m") = 1200 "capture ring stiffness";
  parameter Real bCap(unit="N.s/m") = 80 "capture ring damping";

  // ---- Hydrodynamic linear drag ----
  parameter Real Xu(unit="N.s/m") = 60 "surge drag coefficient";
  parameter Real Yv(unit="N.s/m") = 90 "sway drag coefficient";
  parameter Real Nr(unit="N.m.s") = 40 "yaw drag coefficient";

  // ---- Speed-scheduled pose control gains ----
  parameter Real Kp_u(unit="N.s/m") = 500 "surge speed gain";
  parameter Real Kp_r(unit="N.m") = 90 "heading gain";
  parameter Real Kd_r(unit="N.m.s") = 18 "yaw-rate damping gain";
  parameter Real uApproach(unit="m/s") = 3.0 "commanded approach speed (dist > 1 m)";
  parameter Real uDock(unit="1/s") = 0.5 "docking speed scale (dist < 1 m)";

  // ---- Initial conditions ----
  parameter Real x0(unit="m") = -8.0 "initial surge position (8 m from dock)";
  parameter Real y0(unit="m") = 0.0 "initial lateral position";
  parameter Real psi0(unit="rad") = 0.0 "initial heading (toward dock)";

  // ---- Continuous states ----
  Real x(start=x0, fixed=true) "global x";
  Real y(start=y0, fixed=true) "global y";
  Real psi(start=psi0, fixed=true) "heading";
  Real u(start=0, fixed=true) "body-frame surge";
  Real v(start=0, fixed=true) "body-frame sway";
  Real r(start=0, fixed=true) "yaw rate";

  // ---- Continuous algebraic helpers ----
  Real cosP, sinP;
  Real dx "dock-relative x";
  Real dy "dock-relative y";
  Real dist "Euclidean distance to dock center";
  Real pen "penetration into capture ring";
  Real captureGain "smooth capture activation";
  Real vx_glob "global x velocity";
  Real vy_glob "global y velocity";
  Real vr "radial velocity toward dock";
  Real FcurrentGx "current force global x";
  Real FcurrentGy "current force global y";
  Real FcurrentBx "current force body x";
  Real FcurrentBy "current force body y";
  Real FcapGx "capture force global x";
  Real FcapGy "capture force global y";
  Real FcapBx "capture force body x";
  Real FcapBy "capture force body y";
  Real FcontactMag "capture contact force magnitude";
  Boolean captured "capture status observable";

  // ---- Discrete control and sensor traces (sampled at 80 Hz) ----
  discrete Real Fport(start=0) "port propeller thrust (held)";
  discrete Real Fstbd(start=0) "starboard propeller thrust (held)";
  discrete Real sonarDist(start=8.0) "sonar range to dock";
  discrete Real pressureDepth(start=0.0) "pressure-derived depth (free base)";
  discrete Real imuAccelX(start=0.0) "IMU surge acceleration";
  discrete Real imuAccelY(start=0.0) "IMU sway acceleration";
  discrete Real imuRate(start=0.0) "IMU yaw rate";
  discrete Real u_meas(start=0.0) "estimated surge";
  discrete Real v_meas(start=0.0) "estimated sway";
  discrete Real opticalX(start=-8.0) "short-range optical pose x";
  discrete Real opticalY(start=0.0) "short-range optical pose y";
  discrete Real opticalPsi(start=0.0) "short-range optical pose heading";
  discrete Real psi_d(start=0.0) "commanded heading";
  discrete Real psiErrWrapped(start=0.0) "wrapped heading error (-pi,pi]";
  discrete Real u_cmd(start=0.0) "scheduled surge speed command";
  discrete Real Fsurge_cmd(start=0.0) "total surge force command";
  discrete Real Fyaw_cmd(start=0.0) "yaw torque command";
  discrete Real Fport_raw(start=0.0) "unclamped port force";
  discrete Real Fstbd_raw(start=0.0) "unclamped starboard force";
  discrete Real Fport_trace(start=0.0) "port command trace";
  discrete Real Fstbd_trace(start=0.0) "starboard command trace";
  discrete Real trackErr(start=8.0) "primary tracking error = dist";
  discrete Real contactForceTrace(start=0.0) "contact force trace";

equation
  // ---- Planar kinematics (3-DOF: surge, sway, yaw) ----
  cosP = cos(psi);
  sinP = sin(psi);
  der(x) = u*cosP - v*sinP;
  der(y) = u*sinP + v*cosP;
  der(psi) = r;

  // ---- Dock relative geometry ----
  dx = xDock - x;
  dy = yDock - y;
  dist = sqrt(dx*dx + dy*dy + 1e-8);

  // ---- Global velocity and radial velocity ----
  vx_glob = u*cosP - v*sinP;
  vy_glob = u*sinP + v*cosP;
  vr = (dx*vx_glob + dy*vy_glob)/dist;

  // ---- Cross-current disturbance: 70 N global +y, middle third only ----
  FcurrentGx = 0.0;
  FcurrentGy = if time >= tMid1 and time <= tMid2 then Fcurrent else 0.0;
  FcurrentBx =  FcurrentGx*cosP + FcurrentGy*sinP;
  FcurrentBy = -FcurrentGx*sinP + FcurrentGy*cosP;

  // ---- Compliant capture ring (smooth spring-damper toward dock center) ----
  pen = max(0.0, captureRadius - dist);
  captureGain = pen/(pen + 0.01);
  captured = pen > 1e-4;
  FcapGx = captureGain*(kCap*pen - bCap*vr)*dx/dist;
  FcapGy = captureGain*(kCap*pen - bCap*vr)*dy/dist;
  FcapBx =  FcapGx*cosP + FcapGy*sinP;
  FcapBy = -FcapGx*sinP + FcapGy*cosP;
  FcontactMag = sqrt(FcapGx*FcapGx + FcapGy*FcapGy);

  // ---- Rigid-body dynamics with linear drag ----
  m*der(u) = Fport + Fstbd + FcurrentBx + FcapBx - Xu*u;
  m*der(v) = FcurrentBy + FcapBy - Yv*v;
  Izz*der(r) = (Fstbd - Fport)*d - Nr*r;

  // ---- Sampled control and sensor update at 80 Hz ----
  when sample(0, Ts) then
    // Sensors
    sonarDist = dist;
    pressureDepth = 0.0;
    imuAccelX = (Fport + Fstbd + FcurrentBx + FcapBx - Xu*u)/m;
    imuAccelY = (FcurrentBy + FcapBy - Yv*v)/m;
    imuRate = r;
    u_meas = u;
    v_meas = v;
    opticalX = if dist < 1.0 then x else pre(opticalX);
    opticalY = if dist < 1.0 then y else pre(opticalY);
    opticalPsi = if dist < 1.0 then psi else pre(opticalPsi);

    // Speed schedule: full approach speed, then reduce inside 1 m
    u_cmd = if dist > 1.0 then uApproach else uDock*dist;

    // Line-of-sight desired heading (guarded for dist ~ 0)
    psi_d = if dist > 1e-4 then atan2(dy, dx) else pre(psi_d);

    // Wrapped heading error via atan2 (avoids floor/pi issues)
    psiErrWrapped = atan2(sin(psi_d - psi), cos(psi_d - psi));

    // Differential propeller commands (surge + yaw) with actuator bounds
    Fsurge_cmd = Kp_u*(u_cmd - u);
    Fyaw_cmd = Kp_r*psiErrWrapped - Kd_r*r;
    Fport_raw = (Fsurge_cmd - Fyaw_cmd/d)/2.0;
    Fstbd_raw = (Fsurge_cmd + Fyaw_cmd/d)/2.0;
    Fport = max(-Fmax, min(Fmax, Fport_raw));
    Fstbd = max(-Fmax, min(Fmax, Fstbd_raw));

    // Synchronized state/command/sensor traces
    Fport_trace = Fport;
    Fstbd_trace = Fstbd;
    trackErr = dist;
    contactForceTrace = FcontactMag;
  end when;

  annotation (
    experiment(StopTime=8.0, Interval=0.0125, Tolerance=1e-6),
    Documentation(info="Free-base catamaran docking model. Two 46 kg hulls, 18 kg deck, 1.1 m separation. Cross-current 70 N applied during middle third [2.667, 5.333] s. Propeller commands clamped to +/-310 N. Compliant capture ring engages within 0.25 m of dock center. Sensors: sonar, pressure, IMU, optical pose. Speed-scheduled LOS control at 80 Hz.")
  );
end CatamaranDockA;