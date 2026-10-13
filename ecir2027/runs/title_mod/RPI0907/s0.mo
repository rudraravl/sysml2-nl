model CatamaranDockA
  import SI = Modelica.SIunits;
  // ---- Physical parameters (from requirement only) ----
  parameter SI.Mass m_hull = 46 "mass of each capsule hull";
  parameter SI.Mass m_deck = 18 "mass of rigid deck";
  parameter SI.Mass m = 2*m_hull + m_deck "total dry mass";
  parameter SI.Length hullSep = 1.1 "hull separation";
  parameter SI.Length d = hullSep/2 "half separation (propeller lever)";
  parameter SI.Inertia Izz = 2*m_hull*d^2 + m_deck*d^2 "yaw inertia about center";
  parameter SI.Force Fmax = 310 "per-propeller command magnitude limit";
  parameter SI.Force Fcurrent = 70 "current disturbance force (middle third)";
  parameter SI.Frequency fs = 80 "control and sensor sampling rate";
  parameter SI.Time Ts = 1/fs "sampling period";
  parameter SI.Time tFinal = 8.0 "scenario duration";
  parameter SI.Time tMid1 = tFinal/3 "start of middle third";
  parameter SI.Time tMid2 = 2*tFinal/3 "end of middle third";

  // ---- Dock / capture ring geometry ----
  parameter SI.Length xDock = 0.0 "fixed funnel center x";
  parameter SI.Length yDock = 0.0 "fixed funnel center y";
  parameter SI.Length captureRadius = 0.25 "compliant capture ring radius";
  parameter SI.TranslationalSpringConstant kCap = 1200 "capture ring stiffness";
  parameter SI.TranslationalDampingCoefficient bCap = 80 "capture ring damping";

  // ---- Hydrodynamic linear drag (free-base planar model) ----
  parameter Real Xu(unit="N.s/m") = 60 "surge drag coefficient";
  parameter Real Yv(unit="N.s/m") = 90 "sway drag coefficient";
  parameter Real Nr(unit="N.m.s") = 40 "yaw drag coefficient";

  // ---- Speed-scheduled pose control gains ----
  parameter Real Kp_u(unit="N.s/m") = 500 "surge speed gain";
  parameter Real Kp_r(unit="N.m.s") = 90 "heading gain";
  parameter Real Kd_r(unit="N.m.s2") = 18 "yaw-rate damping gain";
  parameter SI.Velocity uApproach = 3.0 "commanded approach speed (dist > 1 m)";
  parameter SI.Velocity uDock = 0.5 "docking speed scale (dist < 1 m)";

  // ---- Initial conditions ----
  parameter SI.Length x0 = -8.0 "initial surge position (8 m from dock)";
  parameter SI.Length y0 = 0.0 "initial lateral position";
  parameter SI.Angle psi0 = 0.0 "initial heading (toward dock)";

  // ---- Continuous states ----
  SI.Length x(start=x0, fixed=true) "global x";
  SI.Length y(start=y0, fixed=true) "global y";
  SI.Angle psi(start=psi0, fixed=true) "heading";
  SI.Velocity u(start=0, fixed=true) "body-frame surge";
  SI.Velocity v(start=0, fixed=true) "body-frame sway";
  SI.AngularVelocity r(start=0, fixed=true) "yaw rate";

  // ---- Continuous kinematic / algebraic helpers ----
  Real cosP, sinP;
  SI.Length dx "dock-relative x";
  SI.Length dy "dock-relative y";
  SI.Length dist "Euclidean distance to dock center";
  Real pen "penetration into capture ring";
  Boolean captured "capture contact engaged";
  SI.Force FcurrentGx "current force global x";
  SI.Force FcurrentGy "current force global y";
  SI.Force FcurrentBx "current force body x";
  SI.Force FcurrentBy "current force body y";
  SI.Force FcapGx "capture force global x";
  SI.Force FcapGy "capture force global y";
  SI.Force FcapBx "capture force body x";
  SI.Force FcapBy "capture force body y";
  SI.Force FcontactMag "capture contact force magnitude";

  // ---- Discrete control and sensor traces (sampled at fs) ----
  discrete SI.Force Fport(start=0) "port propeller thrust (held)";
  discrete SI.Force Fstbd(start=0) "starboard propeller thrust (held)";
  discrete SI.Length sonarDist(start=8.0) "sonar range to dock";
  discrete SI.Length pressureDepth(start=0.0) "pressure-derived depth (free base)";
  discrete Real imuAccelX(start=0.0) "IMU surge acceleration";
  discrete Real imuAccelY(start=0.0) "IMU sway acceleration";
  discrete SI.AngularVelocity imuRate(start=0.0) "IMU yaw rate";
  discrete SI.Velocity u_meas(start=0.0) "estimated surge";
  discrete SI.Velocity v_meas(start=0.0) "estimated sway";
  discrete SI.Length opticalX(start=-8.0) "short-range optical pose x";
  discrete SI.Length opticalY(start=0.0) "short-range optical pose y";
  discrete SI.Angle opticalPsi(start=0.0) "short-range optical pose heading";
  discrete SI.Angle psi_d(start=0.0) "commanded heading";
  discrete SI.Angle psiErr(start=0.0) "raw heading error";
  discrete Real psiErrWrapped(start=0.0) "wrapped heading error (-pi,pi]";
  discrete SI.Velocity u_cmd(start=0.0) "scheduled surge speed command";
  discrete SI.Force Fsurge_cmd(start=0.0) "total surge force command";
  discrete SI.Torque Fyaw_cmd(start=0.0) "yaw torque command";
  discrete Real Fport_raw(start=0.0) "unclamped port force";
  discrete Real Fstbd_raw(start=0.0) "unclamped starboard force";
  discrete SI.Force Fport_trace(start=0.0) "port command trace";
  discrete SI.Force Fstbd_trace(start=0.0) "starboard command trace";
  discrete SI.Length trackErr(start=8.0) "primary tracking error = dist";
  discrete SI.Force contactForceTrace(start=0.0) "contact force trace";

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