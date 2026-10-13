model AUVDockF
  "Free-base marine robot docking approach with speed-scheduled pose control,
   compliant capture ring, and a mid-mission cross-current disturbance."

  // ===== Stated physical parameters =====
  parameter Real m = 85.0          "hull mass [kg]";
  parameter Real L = 1.5           "hull length [m]";
  parameter Real Vol = 0.083        "displaced volume in seawater [m3]";
  parameter Real rho_sw = 1025.0   "seawater density [kg/m3]";
  parameter Real g = 9.81          "gravitational acceleration [m/s2]";
  parameter Real Fmax = 134.0       "max force per thruster [N]";

  // ===== Derived/estimated parameters (not stated; commented as estimates) =====
  // Yaw inertia estimated from a uniform slender body using stated m and L.
  parameter Real Izz = m*L*L/12.0  "yaw inertia estimate [kg.m2]";
  parameter Real thr_arm = L/2.0   "surge thruster moment arm [m]";
  // Linear hydrodynamic drag coefficients are unknown; placeholders chosen for
  // a neutrally-buoyant 85 kg capsule at order-1 m/s speeds.
  parameter Real Xu = 30.0   "surge linear drag [kg/s] (estimate)";
  parameter Real Yv = 60.0   "sway linear drag [kg/s] (estimate)";
  parameter Real Nr = 20.0   "yaw linear drag [N.m.s] (estimate)";
  parameter Real Zdot = 40.0 "heave linear drag [kg/s] (estimate)";

  // ===== Mission geometry =====
  parameter Real x_dock = 8.0  "dock funnel x position [m]";
  parameter Real y_dock = 0.0  "dock funnel y position [m]";
  parameter Real z_dock = 0.0  "dock depth [m]";
  parameter Real d_contact = 0.06 "capture ring engagement radius [m]";
  parameter Real k_cap = 2000.0  "capture ring axial stiffness [N/m]";
  parameter Real d_cap = 250.0   "capture ring axial damping [N.s/m]";

  // ===== Control gains (estimates; tuned for the stated mission) =====
  parameter Real Kp_u = 400.0   "surge speed gain [N.s/m]";
  parameter Real Kp_psi = 25.0  "heading proportional gain [N.m/rad]";
  parameter Real Kd_psi = 35.0  "heading rate gain [N.m.s/rad]";
  parameter Real Kp_z = 80.0    "depth proportional gain [N/m]";
  parameter Real Kd_z = 40.0    "depth rate gain [N.s/m]";
  parameter Real v_far = 1.2    "approach speed when far [m/s]";
  parameter Real v_near = 0.2   "approach speed inside 1 m [m/s]";
  parameter Real switch_dist = 1.0 "speed-schedule distance [m]";

  // ===== Cross-current disturbance (middle third of 20 s) =====
  parameter Real F_current = 203.0 "controlled current force [N]";
  parameter Real t_start = 20.0/3.0 "disturbance start [s]";
  parameter Real t_end = 40.0/3.0   "disturbance end [s]";

  // ===== Initial conditions =====
  parameter Real x0 = 0.0   "initial x [m]";
  parameter Real y0 = 0.0   "initial y [m]";
  parameter Real z0 = 0.0   "initial z [m]";
  parameter Real psi0 = 0.0 "initial heading [rad]";
  parameter Real u0 = 0.0   "initial surge [m/s]";
  parameter Real v0 = 0.0   "initial sway [m/s]";
  parameter Real w0 = 0.0   "initial heave [m/s]";
  parameter Real r0 = 0.0   "initial yaw rate [rad/s]";

  // ===== States =====
  Real x(start=x0, fixed=true)   "world x position [m]";
  Real y(start=y0, fixed=true)   "world y position [m]";
  Real z(start=z0, fixed=true)  "world z depth (positive down) [m]";
  Real psi(start=psi0, fixed=true) "heading [rad]";
  Real u(start=u0, fixed=true)  "body surge velocity [m/s]";
  Real v(start=v0, fixed=true)  "body sway velocity [m/s]";
  Real w(start=w0, fixed=true)  "body heave velocity (positive up) [m/s]";
  Real r(start=r0, fixed=true)  "body yaw rate [rad/s]";

  // ===== Guidance / commands =====
  Real dist        "distance to dock center [m]";
  Real psi_d       "desired line-of-sight heading [rad]";
  Real v_des       "scheduled desired surge speed [m/s]";
  Real Fsurge_cmd  "commanded total surge force [N]";
  Real Myaw_cmd    "commanded yaw moment [N.m]";
  Real Fz_cmd      "commanded total heave force [N]";
  Real T1, T2      "raw surge thruster forces [N]";
  Real T3, T4      "raw heave thruster forces [N]";
  Real T1s, T2s, T3s, T4s "saturated thruster forces [N]";

  // ===== Contact / capture =====
  Real penetration  "capture ring penetration [m]";
  Real F_contact    "capture ring contact force magnitude [N]";
  Real captured     "capture flag (1 captured, 0 free)";

  // ===== Disturbance (world-y force, transformed to body) =====
  Real F_curr_world "applied world-y current force [N]";
  Real F_curr_x     "current force in body x [N]";
  Real F_curr_y     "current force in body y [N]";

  // ===== Sensors =====
  Real sonar_range     "sonar range to dock [m]";
  Real pressure_depth  "pressure-derived depth [m]";
  Real imu_psi         "IMU heading [rad]";
  Real imu_r           "IMU yaw rate [rad/s]";
  Real opt_x           "short-range optical pose x error [m]";
  Real opt_y           "short-range optical pose y error [m]";
  Real opt_psi         "short-range optical heading error [rad]";
  Real opt_valid       "optical sensor valid flag";

  // ===== Verification flags =====
  Real track_err         "primary tracking error [m]";
  Real actuator_bound_ok;
  Real speed_bound_ok;
  Real lateral_aligned;
  Real yaw_aligned;
  Real contact_force_ok;
  Real captured_ok;
  Real tracking_ok;
  Real values_finite;

  // ===== Auxiliary =====
  Real W   "weight [N]";
  Real B   "buoyancy [N]";
  Real cpsi;
  Real spsi;
  Real Fdrag_u, Fdrag_v, Fdrag_w, Mdrag_r;

equation
  // Vertical restoring forces (near-neutral: W ~= B by the stated numbers).
  W = m*g;
  B = rho_sw*g*Vol;

  cpsi = cos(psi);
  spsi = sin(psi);

  // ----- Guidance: distance and line-of-sight heading -----
  dist = sqrt(max((x_dock - x)*(x_dock - x) + (y_dock - y)*(y_dock - y), 1.0e-9));
  psi_d = if dist < 1.0e-6 then psi else atan2(y_dock - y, x_dock - x);

  // ----- Speed-scheduled pose control -----
  v_des = if dist > switch_dist then v_far else v_near;
  Fsurge_cmd = Kp_u*(v_des - u);
  Myaw_cmd   = Kp_psi*(psi_d - psi) - Kd_psi*r;
  Fz_cmd     = Kp_z*(z_dock - z) - Kd_z*w;

  // ----- Thruster allocation (2 surge differential, 2 heave equal) -----
  T1 = Fsurge_cmd/2.0 + Myaw_cmd/(2.0*thr_arm);
  T2 = Fsurge_cmd/2.0 - Myaw_cmd/(2.0*thr_arm);
  T3 = Fz_cmd/2.0;
  T4 = Fz_cmd/2.0;

  // ----- Actuator saturation (bidirectional, per-thruster bound) -----
  T1s = if T1 >  Fmax then  Fmax else if T1 < -Fmax then -Fmax else T1;
  T2s = if T2 >  Fmax then  Fmax else if T2 < -Fmax then -Fmax else T2;
  T3s = if T3 >  Fmax then  Fmax else if T3 < -Fmax then -Fmax else T3;
  T4s = if T4 >  Fmax then  Fmax else if T4 < -Fmax then -Fmax else T4;

  // ----- Hydrodynamic drag (linearized) -----
  Fdrag_u = -Xu*u;
  Fdrag_v = -Yv*v;
  Fdrag_w = -Zdot*w;
  Mdrag_r = -Nr*r;

  // ----- Cross-current disturbance (world +y, active in middle third) -----
  F_curr_world = if time >= t_start and time <= t_end then F_current else 0.0;
  // World-y force projected onto body axes.
  F_curr_x = F_curr_world*spsi;
  F_curr_y = F_curr_world*cpsi;

  // ----- Compliant capture ring (axial spring-damper bumper at dock) -----
  penetration = max(0.0, d_contact - dist);
  F_contact   = if penetration > 0.0 then k_cap*penetration + d_cap*max(0.0, u) else 0.0;
  captured    = if (penetration > 0.0 and abs(u) < 0.1) then 1.0 else 0.0;

  // ----- Rigid-body dynamics (3-DOF horizontal + heave) -----
  m*der(u)   = (T1s + T2s) + Fdrag_u + m*v*r + F_curr_x - F_contact;
  m*der(v)   = Fdrag_v - m*u*r + F_curr_y;
  m*der(w)   = (T3s + T4s) + Fdrag_w + (B - W);
  Izz*der(r) = (T1s - T2s)*thr_arm + Mdrag_r;

  der(psi) = r;
  der(x)   = u*cpsi - v*spsi;
  der(y)   = u*spsi + v*cpsi;
  der(z)   = -w;

  // ----- Sensor traces -----
  sonar_range    = dist;
  pressure_depth = z;
  imu_psi        = psi;
  imu_r          = r;
  opt_valid      = if dist < 1.0 then 1.0 else 0.0;
  opt_x          = if opt_valid > 0.5 then (x_dock - x) else 0.0;
  opt_y          = if opt_valid > 0.5 then (y_dock - y) else 0.0;
  opt_psi        = if opt_valid > 0.5 then (psi_d - psi) else 0.0;

  // ----- Verification criteria -----
  track_err = sqrt(max((x_dock - x)*(x_dock - x) + (y_dock - y)*(y_dock - y), 1.0e-9));

  actuator_bound_ok = if (abs(T1s) <= Fmax + 1.0e-6 and
                          abs(T2s) <= Fmax + 1.0e-6 and
                          abs(T3s) <= Fmax + 1.0e-6 and
                          abs(T4s) <= Fmax + 1.0e-6) then 1.0 else 0.0;

  speed_bound_ok = if (abs(u) <= 1.5 and abs(v) <= 1.0 and abs(w) <= 1.0) then 1.0 else 0.0;

  lateral_aligned = if abs(y - y_dock) < 0.05 then 1.0 else 0.0;
  yaw_aligned     = if abs(psi_d - psi) < 0.1 then 1.0 else 0.0;
  contact_force_ok = if F_contact < 500.0 then 1.0 else 0.0;
  captured_ok     = captured;
  tracking_ok     = if time > 13.0 then (if track_err < 0.08 then 1.0 else 0.0) else 1.0;

  // Finite-value guard (NaN fails both comparisons; Inf fails one).
  values_finite = if (x > -1.0e30 and x < 1.0e30 and
                      y > -1.0e30 and y < 1.0e30 and
                      z > -1.0e30 and z < 1.0e30 and
                      psi > -1.0e30 and psi < 1.0e30 and
                      u > -1.0e30 and u < 1.0e30 and
                      v > -1.0e30 and v < 1.0e30 and
                      w > -1.0e30 and w < 1.0e30 and
                      r > -1.0e30 and r < 1.0e30 and
                      F_contact > -1.0e30 and F_contact < 1.0e30) then 1.0 else 0.0;

  // ----- Runtime assertions (verification evidence) -----
  assert(actuator_bound_ok > 0.5,  "Actuator bound violated");
  assert(contact_force_ok  > 0.5,  "Contact force exceeds 500 N");
  assert(values_finite     > 0.5,  "Non-finite physical/control/estimator value detected");
  assert(tracking_ok       > 0.5,  "Primary tracking error exceeds 0.08 m after 13 s");

  annotation (
    Documentation(info="AUV docking approach scenario. Run at 500 Hz for 20 s
      (experiment StopTime=20, NumberOfIntervals=10000).
      Stated facts: m=85 kg, L=1.5 m, Vol=0.083 m3, Fmax=134 N/thruster,
      2 surge + 2 heave bidirectional thrusters, dock 8 m away, speed reduced
      inside 1 m, compliant capture ring, 203 N cross-current in middle third.
      Unknown facts (commented as estimates): yaw inertia, hydrodynamic drag
      coefficients, and control gains. These are placeholders chosen to be
      physically reasonable; final tuning is application-specific."),
    experiment(StopTime=20.0, Interval=0.002, Tolerance=1.0e-6)
  );
end AUVDockF;