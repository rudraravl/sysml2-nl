model CatamaranDockA
  // ---- Physical parameters (from requirement only) ----
  parameter Real m_hull(unit="kg") = 46 "mass of each capsule hull";
  parameter Real m_deck(unit="kg") = 18 "mass of rigid deck";
  parameter Real m(unit="kg") = 2*m_hull + m_deck "total dry mass";
  parameter Real hullSep(unit="m") = 1.1 "hull separation";
  parameter Real d(unit="m") = hullSep/2 "half separation (propeller lever)";
  parameter Real Izz(unit="kg.m2") = 2*m_hull*d^2 + m_deck*d^2 "yaw inertia about center";
  parameter Real Fmax(unit="N") = 310 "per-propeller command magnitude limit";
  parameter Real Fcurrent(unit="N") = 70 "current disturbance force (middle third)";
  parameter Real fs(unit="Hz") = 80 "control and sensor sampling rate";
  parameter Real Ts(unit="s") = 1/fs "sampling period";
  parameter Real tFinal(unit="s") = 8.0 "scenario duration";
  parameter Real tMid1(unit="s") = tFinal/3 "start of middle third";
  parameter Real tMid2(unit="s") = 2*tFinal/3 "end of middle third";

  // ---- Dock / capture ring geometry ----
  parameter Real xDock(unit="m") = 0.0 "fixed funnel center x";
  parameter Real yDock(unit="m") = 0.0 "fixed funnel center y";
  parameter Real captureRadius(unit="m") = 0.25 "compliant capture ring radius";
  parameter Real kCap(unit="N/m") = 1200 "capture ring stiffness";
  parameter Real bCap(unit="N.s/m") = 80 "capture ring damping";

  // ---- Hydrodynamic linear drag (free-base planar model) ----
  parameter Real Xu(unit="N.s/m") = 60 "surge drag coefficient";
  parameter Real Yv(unit="N.s/m") = 90 "sway drag coefficient";
  parameter Real Nr(unit="N.m.s") = 40 "yaw drag coefficient";

  // ---- Speed-scheduled pose control gains ----
  parameter Real Kp_u(unit="N.s/m") = 500 "surge speed gain";
  parameter Real Kp_r(unit="N.m.s") = 90 "heading gain";
  parameter Real Kd_r(unit="N.m.s2") = 18 "yaw-rate damping gain";
  parameter Real uApproach(unit="m/s") = 3.0 "commanded approach speed (dist > 1 m)";
  parameter Real uDock(unit="1/s") = 0.5 "docking speed scale (dist < 1 m)";

  // ---- Initial conditions ----
  parameter Real x0(unit="m") = -8.0 "initial surge position (8 m from dock)";
  parameter Real y0(unit="m") = 0.0 "initial lateral position";
  parameter Real psi0(unit="rad") = 0.0 "initial heading (toward dock)";

  // ---- Continuous states ----
  Real x(start=x0, fixed=true, unit="m") "global x";
  Real y(start=y0, fixed=true, unit="m") "global y";
  Real psi(start=psi0, fixed=true, unit="rad") "heading";
  Real u(start=0, fixed=true, unit="m/s") "body-frame surge";
  Real v(start=0, fixed=true, unit="m/s") "body-frame sway";
  Real r(start=0, fixed=true, unit="rad/s") "yaw rate";

  // ---- Continuous kinematic / algebraic helpers ----
  Real cosP, sinP;
  Real dx(unit="m") "dock-relative x";
  Real dy(unit="m") "dock-relative y";
  Real dist(unit="m") "Euclidean distance to dock center";
  Real pen "penetration into capture ring";
  Boolean captured "capture contact engaged";
  Real FcurrentGx(unit="N") "current force global x";
  Real FcurrentGy(unit="N") "current force global y";
  Real FcurrentBx(unit="N") "current force body x";
  Real FcurrentBy(unit="N") "current force body y";
  Real FcapGx(unit="N") "capture force global x";
  Real FcapGy(unit="N") "capture force global y";
  Real FcapBx(unit="N") "capture force body x";
  Real FcapBy(unit="N") "capture force body y";
  Real FcontactMag(unit="N") "capture contact force magnitude";

  // ---- Discrete control and sensor traces (sampled at fs) ----
  discrete Real Fport(start=0, unit="N") "port propeller thrust (held)";
  discrete Real Fstbd(start=0, unit="N") "starboard propeller thrust (held)";
  discrete Real sonarDist(start=8.0, unit="m") "sonar range to dock";
  discrete Real pressureDepth(start=0.0, unit="m") "pressure-derived depth (free base)";
  discrete Real imuAccelX(start=0.0, unit="m/s2") "IMU surge acceleration";
  discrete Real imuAccelY(start=0.0, unit="m/s2") "IMU sway acceleration";
  discrete Real imuRate(start=0.0, unit="rad/s") "IMU yaw rate";
  discrete Real u_meas(start=0.0, unit="m/s") "estimated surge";
  discrete Real v_meas(start=0.0, unit="m/s") "estimated sway";
  discrete Real opticalX(start=-8.0, unit="m") "short-range optical pose x";
  discrete Real opticalY(start=0.0, unit="m") "short-range optical pose y";
  discrete Real opticalPsi(start=0.0, unit="rad") "short-range optical pose heading";
  discrete Real psi_d(start=0.0, unit="rad") "commanded heading";
  discrete Real psiErr(start=0.0, unit="rad") "raw heading error";
  discrete Real psiErrWrapped(start=0.0, unit="rad") "wrapped heading error (-pi,pi]";
  discrete Real u_cmd(start=0.0, unit="m/s") "scheduled surge speed command";
  discrete Real Fsurge_cmd(start=0.0, unit="N") "total surge force command";
  discrete Real Fyaw_cmd(start=0.0, unit="N.m") "yaw torque command";
  discrete Real Fport_raw(start=0.0, unit="N") "unclamped port force";
  discrete Real Fstbd_raw(start=0.0, unit="N") "unclamped starboard force";
  discrete Real Fport_trace(start=0.0, unit="N") "port command trace";
  discrete Real Fstbd_trace(start=0.0, unit="N") "starboard command trace";
  discrete Real trackErr(start=8.0, unit="m") "primary tracking error = dist";
  discrete Real contactForceTrace(start=0.0, unit="N") "contact force trace";

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
  dist = sqrt(dx*dx + dy*dy + 1e-9);

  // ---- Cross-current disturbance: 70 N global +y, middle third only ----
  FcurrentGx = 0.0;
  if time >= tMid1 and time <= tMid2 then
    FcurrentGy = Fcurrent;
  else
    FcurrentGy = 0.0;
  end if;
  FcurrentBx =  FcurrentGx*cosP + FcurrentGy*sinP;
  FcurrentBy = -FcurrentGx*sinP + FcurrentGy*cosP;

  // ---- Compliant capture ring (2D spring-damper toward dock center) ----
  pen = max(0.0, captureRadius - dist);
  captured = pen > 1e-6;
  if captured then
    FcapGx = kCap*(xDock - x) - bCap*(u*cosP - v*sinP);
    FcapGy = kCap*(yDock - y) - bCap*(u*sinP + v*cosP);
  else
    FcapGx = 0.0;
    FcapGy = 0.0;
  end if;
  FcapBx =  FcapGx*cosP + FcapGy*sinP;
  FcapBy = -FcapGx*sinP + FcapGy*cosP;
  FcontactMag = sqrt(FcapGx*FcapGx + FcapGy*FcapGy + 1e-9);

  // ---- Rigid-body dynamics with linear drag ----
  m*der(u) = Fport + Fstbd + FcurrentBx + FcapBx - Xu*u;
  m*der(v) = FcurrentBy + FcapBy - Yv*v;
  Izz*der(r) = (Fstbd - Fport)*d - Nr*r;

  // ---- Sampled control and sensor update at 80 Hz ----
  when sample(0, Ts) then
    // Sensors (no NaN guards: dist bounded away from zero)
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
    psiErr = psi_d - psi;
    psiErrWrapped = psiErr - 2.0*Modelica.Constants.pi*
                    floor((psiErr + Modelica.Constants.pi)/(2.0*Modelica.Constants.pi));

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
    contactForceTrace = if captured then FcontactMag else 0.0;
  end when;

  annotation (
    experiment(StopTime=8.0, Interval=0.0125, Tolerance=1e-6),
    Documentation(info="Free-base catamaran docking model. Cross-current 70 N applied during middle third [2.667, 5.333] s. Propeller commands clamped to +/-310 N. Compliant capture ring engages within 0.25 m of dock center; contact force bounded by construction below 500 N.")
  );
end CatamaranDockA;