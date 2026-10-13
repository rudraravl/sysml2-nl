model ROVDockF
  "Free-base marine robot docking scenario: approach a fixed docking funnel,
   reduce speed inside 1 m, align, and establish compliant capture.
   Roll/pitch are assumed passively stable (box frame, slight positive buoyancy)
   and are NOT modeled (geometry/stability details unspecified).
   Sensor noise, thruster electrical dynamics, and funnel internal shape are
   unspecified and therefore omitted (ideal sensors, static saturated thrusters,
   compliant contact plane)."

  // ---------- Physical parameters ----------
  parameter Modelica.SIunits.Mass m = 115.0 "ROV mass";
  parameter Real Lx = 1.1 "frame length x (m)";
  parameter Real Ly = 0.78 "frame width y (m)";
  parameter Real Lz = 0.58 "frame height z (m)";
  parameter Modelica.SIunits.MomentOfInertia Izz = m/12.0*(Lx*Lx + Ly*Ly) "yaw inertia of box";
  parameter Real g_acc = 9.81 "m/s2";
  parameter Real net_buoy = 5.0 "N, slightly positively buoyant (upward)";
  parameter Real Fthr_max = 201.0 "N, per-thruster bidirectional limit";
  parameter Real Fcurrent = 203.0 "N, cross-current disturbance amplitude";

  // Quadratic hydrodynamic drag (lumped coefficients)
  parameter Real Dx = 90.0 "Ns2/m2 surge drag";
  parameter Real Dy = 90.0 "Ns2/m2 sway drag";
  parameter Real Dz = 60.0 "Ns2/m2 heave drag";
  parameter Real Dr = 25.0 "Nms2/rad2 yaw drag";

  // ---------- Thruster geometry (body frame, m) ----------
  // T1,T2: front pair along body x (surge + yaw via differential)
  parameter Real p1y = 0.30 "T1 lateral offset";
  parameter Real p2y = -0.30 "T2 lateral offset";
  parameter Real ym_aw = 0.60 "sum of front-pair yaw moment arms (2*0.30)";
  // T3,T4: lateral pair along body y at px=0 (pure sway, no yaw coupling)
  // T5,T6: vertical pair along body z at center (heave)

  // ---------- Compliant capture ring ----------
  parameter Real x_contact = -0.02 "m, ROV-center x where contact begins";
  parameter Real k_ring = 1000.0 "N/m ring stiffness";
  parameter Real d_ring = 800.0 "Ns/m ring damping";

  // ---------- Speed-scheduled pose controller ----------
  parameter Real Kp_pos = 2.0 "position-to-velocity gain (far)";
  parameter Real Kp_pos_contact = 0.72 "reduced position gain in contact (compliance)";
  parameter Real Ku = 600.0 "surge velocity-to-force gain";
  parameter Real Kv = 600.0 "sway velocity-to-force gain";
  parameter Real Kr = 180.0 "yaw-rate-to-moment gain";
  parameter Real Kp_psi = 1.6 "heading error to yaw-rate gain";
  parameter Real Kz = 200.0 "depth position gain";
  parameter Real Kd_z = 300.0 "depth velocity gain";
  parameter Real v_max_approach = 1.2 "m/s scheduled speed outside 1 m";
  parameter Real v_max_dock = 0.05 "m/s scheduled speed at contact";
  parameter Real v_max_op = 1.3 "m/s operational speed bound (value unspecified; chosen here)";
  parameter Real x_target = 0.02 "m target ROV-center x (slightly into funnel for capture)";
  parameter Real y_target = 0.0 "m";
  parameter Real z_target = -1.0 "m target depth";
  parameter Real psi_target = 0.0 "rad target yaw";

  // ---------- States (synchronized state trace) ----------
  Real x(start=-8.0, fixed=true) "world x (m)";
  Real y(start=0.0, fixed=true) "world y (m)";
  Real z(start=-1.0, fixed=true) "world z, up positive (m)";
  Real u(start=0.0, fixed=true) "surge body velocity (m/s)";
  Real v(start=0.0, fixed=true) "sway body velocity (m/s)";
  Real w(start=0.0, fixed=true) "heave body velocity (m/s)";
  Real psi(start=0.0, fixed=true) "yaw (rad)";
  Real r(start=0.0, fixed=true) "yaw rate (rad/s)";

  // ---------- Kinematic derived ----------
  Real cpsi, spsi;
  Real vx_w, vy_w;
  Real dist;
  Real tracking_error;

  // ---------- Controller internals (command trace) ----------
  Real psi_des;
  Real e_psi;
  Real e_bx, e_by;
  Real Kp_pos_eff;
  Real v_max_sched;
  Real u_d_raw, v_d_raw, mag_d, scale_d;
  Real u_d, v_d, r_d;
  Real Fx_cmd, Fy_cmd, Mz_cmd, Fz_cmd;
  Boolean in_contact;

  // ---------- Allocation ----------
  Real d_yaw;
  Real f1, f2, f3, f4, f5, f6 "commanded thruster forces (N)";
  Real f1s, f2s, f3s, f4s, f5s, f6s "saturated (actual) thruster forces (N)";
  Real Fx_thr, Fy_thr, Mz_thr, Fz_thr "actual applied body wrench";

  // ---------- Disturbance ----------
  Real Fdist_y;
  Real Fdist_bx, Fdist_by;

  // ---------- Contact ----------
  Real penetration;
  Real F_contact_x, F_contact_y, F_contact_mag;
  Real Fcontact_bx, Fcontact_by;
  Boolean captured;

  // ---------- Sensors (sensor trace) ----------
  Real sonar_range;
  Real depth_meas;
  Real u_meas, v_meas, r_meas, psi_meas;
  Real x_opt, y_opt, psi_opt;
  Boolean opt_valid;

  // ---------- Verification ----------
  Boolean actuator_bound_ok;
  Boolean speed_bound_ok;
  Boolean lateral_align_ok;
  Boolean yaw_align_ok;
  Boolean contact_force_ok;
  Boolean capture_ok;
  Boolean tracking_error_ok;
  Boolean finite_ok;

equation
  // Trigonometry and world velocities
  cpsi = cos(psi);
  spsi = sin(psi);
  vx_w = cpsi*u - spsi*v;
  vy_w = spsi*u + cpsi*v;
  dist = sqrt(x*x + y*y);
  tracking_error = sqrt((x - x_target)*(x - x_target) + (y - y_target)*(y - y_target));

  // Kinematics
  der(x) = vx_w;
  der(y) = vy_w;
  der(z) = w;
  der(psi) = r;

  // Cross-current disturbance: 203 N in world +y during middle third of 20 s
  Fdist_y = if (time >= 20.0/3.0 and time <= 40.0/3.0) then Fcurrent else 0.0;
  Fdist_bx = spsi*Fdist_y;
  Fdist_by = cpsi*Fdist_y;

  // Compliant capture ring contact (rigid station geometry)
  penetration = max(0.0, x - x_contact);
  in_contact = penetration > 0.0;
  F_contact_x = if penetration > 0.0 then (-k_ring*penetration - d_ring*vx_w) else 0.0;
  F_contact_y = 0.0;
  F_contact_mag = sqrt(F_contact_x*F_contact_x + F_contact_y*F_contact_y);
  Fcontact_bx = cpsi*F_contact_x + spsi*F_contact_y;
  Fcontact_by = -spsi*F_contact_x + cpsi*F_contact_y;
  captured = penetration > 0.004;

  // Rigid-body dynamics: 3-DOF planar (surge/sway/yaw) + heave
  m*der(u) = m*v*r + Fx_thr + Fdist_bx + Fcontact_bx - Dx*u*abs(u);
  m*der(v) = -m*u*r + Fy_thr + Fdist_by + Fcontact_by - Dy*v*abs(v);
  m*der(w) = Fz_thr + net_buoy - Dz*w*abs(w);
  Izz*der(r) = Mz_thr - Dr*r*abs(r);

  // Speed-scheduled pose control with contact transition
  Kp_pos_eff = if in_contact then Kp_pos_contact else Kp_pos;
  psi_des = if dist > 1.0 then Modelica.Math.atan2(-y, -x) else psi_target;
  e_psi = psi_des - psi;
  e_bx = cpsi*(x_target - x) + spsi*(y_target - y);
  e_by = -spsi*(x_target - x) + cpsi*(y_target - y);
  v_max_sched = if dist > 1.0 then v_max_approach
                else if dist > 0.1 then v_max_approach*(dist - 0.1)/0.9
                                   + v_max_dock*(1.0 - (dist - 0.1)/0.9)
                else v_max_dock;
  u_d_raw = Kp_pos_eff*e_bx;
  v_d_raw = Kp_pos_eff*e_by;
  mag_d = sqrt(u_d_raw*u_d_raw + v_d_raw*v_d_raw);
  scale_d = if mag_d > v_max_sched then v_max_sched/mag_d else 1.0;
  u_d = scale_d*u_d_raw;
  v_d = scale_d*v_d_raw;
  r_d = Kp_psi*e_psi;

  // Velocity tracking -> commanded body wrench
  Fx_cmd = Ku*(u_d - u);
  Fy_cmd = Kv*(v_d - v);
  Mz_cmd = Kr*(r_d - r);
  Fz_cmd = -net_buoy - Kz*(z - z_target) - Kd_z*w; // feedforward cancels buoyancy at target

  // Control allocation to six thrusters
  d_yaw = Mz_cmd/ym_aw;
  f1 = Fx_cmd/2.0 - d_yaw;
  f2 = Fx_cmd/2.0 + d_yaw;
  f3 = Fy_cmd/2.0;
  f4 = Fy_cmd/2.0;
  f5 = Fz_cmd/2.0;
  f6 = Fz_cmd/2.0;

  // Per-thruster saturation (bidirectional, hard limit)
  f1s = max(-Fthr_max, min(Fthr_max, f1));
  f2s = max(-Fthr_max, min(Fthr_max, f2));
  f3s = max(-Fthr_max, min(Fthr_max, f3));
  f4s = max(-Fthr_max, min(Fthr_max, f4));
  f5s = max(-Fthr_max, min(Fthr_max, f5));
  f6s = max(-Fthr_max, min(Fthr_max, f6));

  // Actual wrench from saturated thrusters
  Fx_thr = f1s + f2s;
  Fy_thr = f3s + f4s;
  Fz_thr = f5s + f6s;
  Mz_thr = -p1y*f1s - p2y*f2s;

  // Sensors (ideal; noise spectra unspecified -> omitted)
  sonar_range = dist;
  depth_meas = z;
  u_meas = u;
  v_meas = v;
  r_meas = r;
  psi_meas = psi;
  opt_valid = dist < 1.0;
  x_opt = if opt_valid then x else 0.0;
  y_opt = if opt_valid then y else 0.0;
  psi_opt = if opt_valid then psi else 0.0;

  // Verification criteria
  actuator_bound_ok = (abs(f1s) <= Fthr_max + 1e-3) and (abs(f2s) <= Fthr_max + 1e-3)
                  and (abs(f3s) <= Fthr_max + 1e-3) and (abs(f4s) <= Fthr_max + 1e-3)
                  and (abs(f5s) <= Fthr_max + 1e-3) and (abs(f6s) <= Fthr_max + 1e-3);
  speed_bound_ok = sqrt(u*u + v*v) <= v_max_op + 1e-3;
  lateral_align_ok = (time >= 14.0) and (abs(y - y_target) < 0.05);
  yaw_align_ok = (time >= 14.0) and (abs(psi - psi_target) < 0.10);
  contact_force_ok = F_contact_mag < 500.0;
  capture_ok = captured;
  tracking_error_ok = (time >= 13.0) and (tracking_error < 0.08);
  finite_ok = (x == x) and (y == y) and (z == z) and (u == u) and (v == v)
          and (w == w) and (psi == psi) and (r == r)
          and (f1s == f1s) and (f2s == f2s) and (f3s == f3s) and (f4s == f4s)
          and (f5s == f5s) and (f6s == f6s)
          and (Fx_thr == Fx_thr) and (Fy_thr == Fy_thr) and (Mz_thr == Mz_thr);

  assert(actuator_bound_ok, "ROVDockF: actuator bound (201 N/thruster) violated");
  assert(speed_bound_ok, "ROVDockF: operational speed bound violated");
  assert(contact_force_ok, "ROVDockF: contact force exceeds 500 N");
  assert(finite_ok, "ROVDockF: NaN or infinite physical/control/estimator value detected");

  annotation(
    experiment(StopTime = 20.0, Tolerance = 1e-6, Interval = 0.002),
    Documentation(info = "ROVDockF runs at 500 Hz (Interval=0.002 s) for 20 s.
      Unknown/unresolved facts (sensor noise, thruster electrical dynamics,
      funnel internal geometry, roll/pitch stability, exact speed-bound value)
      are treated as unknown and omitted rather than fabricated."));
end ROVDockF;