model AUVDockD
  "Instrumented free-base marine robot approaching a fixed docking funnel"

  // ---- Embodiment / mass & geometry ----
  parameter Real m       = 85.0  "kg hull mass";
  parameter Real L_hull  = 1.5   "m hull length";
  parameter Real V_disp  = 0.083 "m3 displaced volume in seawater";
  parameter Real rho_sw  = 1025.0 "kg/m3 seawater density";
  parameter Real ma_x    = 0.2*m "kg added mass in surge";
  parameter Real ma_y    = 1.0*m "kg added mass in sway";
  parameter Real m_u     = m + ma_x "kg effective surge inertia";
  parameter Real m_v     = m + ma_y "kg effective sway inertia";
  parameter Real I_z     = 1.5*m*L_hull^2/12 "kg.m2 yaw inertia (with added mass)";

  // ---- Hydrodynamic drag (linear + quadratic) ----
  parameter Real d_u  = 30.0  "N.s/m";
  parameter Real d_uu = 60.0  "N.s2/m2";
  parameter Real d_v  = 60.0  "N.s/m";
  parameter Real d_vv = 100.0 "N.s2/m2";
  parameter Real d_r  = 15.0  "N.m.s/rad";
  parameter Real d_rr = 30.0  "N.m.s2/rad2";

  // ---- Thrusters ----
  parameter Real F_max  = 110.0 "N per bidirectional thruster";
  parameter Real d_thr  = 0.8   "m surge-thruster lateral separation";

  // ---- Docking funnel / compliant capture ring ----
  parameter Real x_dock    = -0.75 "m AUV center target (nose at funnel plane x=0)";
  parameter Real r_capture  = 0.25 "m funnel capture radius";
  parameter Real k_cap     = 4000.0 "N/m axial compliance";
  parameter Real b_cap     = 400.0  "N.s/m axial damping";
  parameter Real k_lat     = 3000.0 "N/m lateral centering";
  parameter Real b_lat     = 300.0  "N.s/m lateral damping";

  // ---- Disturbance (controlled cross-current) ----
  parameter Real F_dist = 140.0 "N current force magnitude";
  parameter Real t_d1   = 14.0/3.0 "s disturbance start (middle third)";
  parameter Real t_d2   = 28.0/3.0 "s disturbance end (middle third)";
  parameter Real x_cp   = 0.05    "m current center-of-pressure offset";

  // ---- Controller gains ----
  parameter Real Kp_u   = 2.0;
  parameter Real Kp_y   = 3.0;
  parameter Real Kd_y   = 4.0;
  parameter Real Ki_y   = 2.0;
  parameter Real Kp_psi = 4.0;
  parameter Real Kd_psi = 2.5;
  parameter Real Ki_psi = 1.0;
  parameter Real u_cruise = 1.2 "m/s approach speed (far)";
  parameter Real u_approach = 0.3 "m/s reduced speed inside 1 m";

  // ---- Initial conditions ----
  parameter Real x0   = -8.0 "m initial surge position (8 m from funnel)";
  parameter Real y0   = 0.0  "m initial sway position";
  parameter Real psi0 = 0.0  "rad initial heading";
  parameter Real z_depth = 5.0 "m nominal depth read by pressure sensor";

  // ---- Dynamic states ----
  Real x(start=x0,   fixed=true) "m inertial x (surge axis toward funnel)";
  Real y(start=y0,   fixed=true) "m inertial y (lateral)";
  Real psi(start=psi0,fixed=true) "rad yaw heading";
  Real u(start=0, fixed=true) "m/s body-frame surge velocity";
  Real v(start=0, fixed=true) "m/s body-frame sway velocity";
  Real r(start=0, fixed=true) "rad/s body-frame yaw rate";
  Real int_e_y(start=0)   "m.s lateral integral (anti-windup clamped)";
  Real int_e_psi(start=0) "rad.s yaw integral (anti-windup clamped)";

  // ---- Relative pose (body frame, to docking target) ----
  Real e_x_b   "m body-frame axial error to dock";
  Real e_y_b   "m body-frame lateral error to dock";
  Real d_track "m primary tracking range";
  Real u_d     "m/s scheduled desired surge speed";

  // ---- Commands ----
  Real F_x_cmd "N commanded surge force";
  Real F_y_cmd "N commanded sway force";
  Real M_z_cmd "N.m commanded yaw moment";

  // ---- Thruster allocation ----
  Real T1, T2, T3, T4  "N raw thruster commands";
  Real T1s, T2s, T3s, T4s "N saturated thruster forces";
  Real F_x_act "N actual surge force";
  Real F_y_act "N actual sway force";
  Real M_z_act "N.m actual yaw moment";

  // ---- Disturbance ----
  Real window     "dimensionless disturbance enable";
  Real F_dist_x_b "N disturbance body-frame x";
  Real F_dist_y_b "N disturbance body-frame y";
  Real M_dist     "N.m disturbance yaw moment";

  // ---- Contact / capture ----
  Real x_nose "m nose inertial x";
  Real y_nose "m nose inertial y";
  Real delta  "m nose penetration past funnel plane";
  Real F_cx   "N contact axial force";
  Real F_cy   "N contact lateral force";
  Real F_contact_mag "N contact force magnitude";
  Real captured       "dimensionless capture flag";

  // ---- Sensors ----
  Real sonar_range     "m sonar range measurement";
  Real pressure_depth  "m pressure-derived depth";
  Real imu_yawrate     "rad/s IMU yaw rate";
  Real optical_dx      "m optical relative pose x";
  Real optical_dy      "m optical relative pose y";
  Real optical_psi     "rad optical relative pose heading";
  Real optical_inrange "dimensionless optical in-range flag";

  // ---- Metrics ----
  Real track_err "m primary tracking error";
  Real spd      "m/s body speed";

equation
  // Relative pose of docking target in body frame
  e_x_b = (x_dock - x)*cos(psi) + (0.0 - y)*sin(psi);
  e_y_b = -(x_dock - x)*sin(psi) + (0.0 - y)*cos(psi);
  d_track = sqrt(e_x_b*e_x_b + e_y_b*e_y_b + 1.0e-9);
  spd = sqrt(u*u + v*v + 1.0e-9);

  // Speed-scheduled desired surge speed
  u_d = if d_track > 1.0 then u_cruise else u_approach;

  // Anti-windup conditional integrators
  der(int_e_y) = if abs(int_e_y) < 0.5 then e_y_b
                 else (if e_y_b*sign(int_e_y + 1.0e-12) < 0.0 then e_y_b else 0.0);
  der(int_e_psi) = if abs(int_e_psi) < 0.3 then (-psi)
                   else (if (-psi)*sign(int_e_psi + 1.0e-12) < 0.0 then (-psi) else 0.0);

  // Commands with drag + Coriolis feedforward (PD acts on pure inertia)
  F_x_cmd = m_u*(Kp_u*(u_d - u)) + d_u*u + d_uu*u*abs(u) - m_v*v*r;
  F_y_cmd = m_v*(Kp_y*e_y_b + Ki_y*int_e_y - Kd_y*v) + d_v*v + d_vv*v*abs(v) + m_u*u*r;
  M_z_cmd = I_z*(Kp_psi*(-psi) + Ki_psi*int_e_psi - Kd_psi*r) + d_r*r + d_rr*r*abs(r);

  // Allocation to four thrusters (2 surge differential for yaw, 2 lateral)
  T1 = F_x_cmd/2.0 - M_z_cmd/(2.0*d_thr);
  T2 = F_x_cmd/2.0 + M_z_cmd/(2.0*d_thr);
  T3 = F_y_cmd/2.0;
  T4 = F_y_cmd/2.0;

  // Per-thruster saturation (110 N bidirectional bound)
  T1s = if T1 >  F_max then  F_max else if T1 < -F_max then -F_max else T1;
  T2s = if T2 >  F_max then  F_max else if T2 < -F_max then -F_max else T2;
  T3s = if T3 >  F_max then  F_max else if T3 < -F_max then -F_max else T3;
  T4s = if T4 >  F_max then  F_max else if T4 < -F_max then -F_max else T4;

  F_x_act = T1s + T2s;
  F_y_act = T3s + T4s;
  M_z_act = (T2s - T1s)*d_thr/2.0;

  // Cross-current disturbance (inertial +y), middle third of run
  window = if time >= t_d1 and time <= t_d2 then 1.0 else 0.0;
  F_dist_x_b = F_dist*window*sin(psi);
  F_dist_y_b = F_dist*window*cos(psi);
  M_dist = F_dist_y_b*x_cp;

  // Nose position and compliant contact engagement
  x_nose = x + (L_hull/2.0)*cos(psi);
  y_nose = y + (L_hull/2.0)*sin(psi);
  delta = if x_nose > 0.0 then x_nose else 0.0;

  // Compliant capture ring: axial spring-damper + lateral centering
  F_cx = if delta > 0.0 then (-k_cap*delta - b_cap*u) else 0.0;
  F_cy = if delta > 0.0 then (-k_lat*y_nose - b_lat*v) else 0.0;
  F_contact_mag = if delta > 0.0 then sqrt(F_cx*F_cx + F_cy*F_cy + 1.0e-9) else 0.0;
  captured = if (delta > 0.005) and (abs(y_nose) < r_capture) then 1.0 else 0.0;

  // Rigid-body 3-DOF horizontal dynamics (Fossen form)
  m_u*der(u) = F_x_act + F_dist_x_b + F_cx + m_v*v*r - (d_u*u + d_uu*u*abs(u));
  m_v*der(v) = F_y_act + F_dist_y_b + F_cy - m_u*u*r - (d_v*v + d_vv*v*abs(v));
  I_z*der(r) = M_z_act + M_dist - (d_r*r + d_rr*r*abs(r));

  // Kinematics
  der(x)   = u*cos(psi) - v*sin(psi);
  der(y)   = u*sin(psi) + v*cos(psi);
  der(psi) = r;

  // Sensors (finite, no NaN; optical pose valid short-range, flag otherwise)
  sonar_range    = d_track;
  pressure_depth = z_depth;
  imu_yawrate    = r;
  optical_dx     = e_x_b;
  optical_dy     = e_y_b;
  optical_psi    = psi;
  optical_inrange = if d_track < 2.0 then 1.0 else 0.0;

  // Primary tracking error
  track_err = sqrt((x - x_dock)*(x - x_dock) + y*y + 1.0e-9);

  annotation (
    experiment(StartTime=0, StopTime=14, Tolerance=1e-4, Interval=0.005),
    Documentation(info="200 Hz co-simulation run for 14 s. Buoyancy: rho*V=1025*0.083=85.075 kg ~ neutral vs 85 kg hull.")
  );
end AUVDockD;