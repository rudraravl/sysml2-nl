model ROVDockF
  import Modelica.Constants.g;

  // ---- Physical parameters ----
  parameter Real m = 115.0 "robot mass [kg]";
  parameter Real Lx = 1.1 "frame length [m]";
  parameter Real Ly = 0.78 "frame width [m]";
  parameter Real Lz = 0.58 "frame height [m]";
  parameter Real Iz = m*(Lx*Lx + Ly*Ly)/12.0 "yaw inertia [kg.m2]";
  parameter Real mx = 0.2*m "added mass surge [kg]";
  parameter Real my = 0.2*m "added mass sway [kg]";
  parameter Real mz_a = 0.1*Iz "added yaw inertia [kg.m2]";
  parameter Real W = m*g "weight [N]";
  parameter Real B = 1.02*W "buoyancy [N], slightly positive (heave/roll/pitch not modeled in 3DOF planar)";

  // ---- Thruster geometry and limits ----
  parameter Real Fmax = 201.0 "per-thruster limit [N]";
  parameter Real half_x = Lx/2 "half length [m]";
  parameter Real half_y = Ly/2 "half width [m]";
  parameter Real c45 = 0.7071067811865476 "cos(45 deg)";
  parameter Real Mzu = (half_x - half_y)*c45 "unit yaw moment per thruster [m]";
  parameter Real pinvFx = c45*0.5 "allocation gain, force [N/N]";
  parameter Real pinvMz = 1.0/(4.0*Mzu) "allocation gain, moment [N/(N.m)]";

  // ---- Dock / capture ring ----
  parameter Real x_dock = 8.0 "dock x [m]";
  parameter Real y_dock = 0.0 "dock y [m]";
  parameter Real psi_dock = 0.0 "dock heading [rad]";
  parameter Real rcap = 0.12 "capture radius [m]";
  parameter Real Kc = 2000.0 "contact stiffness [N/m]";
  parameter Real Dc = 1500.0 "contact damping [Ns/m]";

  // ---- Current and disturbance ----
  parameter Real c_speed = 0.25 "cross-current speed [m/s] (+y world)";
  parameter Real Fdist = 203.0 "controlled disturbance force [N]";
  parameter Real t_start_dist = 20.0/3.0 "disturbance start [s]";
  parameter Real t_end_dist = 40.0/3.0 "disturbance end [s]";

  // ---- Control gains ----
  parameter Real v_max = 1.0 "approach speed limit [m/s]";
  parameter Real Kp_pos = 3.0 "position-to-velocity gain [1/s]";
  parameter Real Kp_u = 2000.0 "surge P gain [N/(m/s)]";
  parameter Real Kp_v = 2500.0 "sway P gain [N/(m/s)]";
  parameter Real Kp_psi = 120.0 "yaw P gain [N.m]";
  parameter Real Kd_psi = 50.0 "yaw D gain [N.m.s]";

  // ---- Drag ----
  parameter Real Ku = 80.0 "quadratic surge drag [N s2/m2]";
  parameter Real Kv = 80.0 "quadratic sway drag [N s2/m2]";
  parameter Real Kul = 150.0 "linear surge drag [Ns/m]";
  parameter Real Kvl = 150.0 "linear sway drag [Ns/m]";
  parameter Real Kr = 30.0 "quadratic yaw drag [N.m s2]";
  parameter Real Krlin = 20.0 "linear yaw drag [N.m s]";

  // ---- States ----
  Real x(start=0.0, fixed=true) "world x [m]";
  Real y(start=0.0, fixed=true) "world y [m]";
  Real psi(start=0.0, fixed=true) "yaw [rad]";
  Real u(start=0.0, fixed=true) "body surge velocity [m/s]";
  Real v(start=0.0, fixed=true) "body sway velocity [m/s]";
  Real r(start=0.0, fixed=true) "yaw rate [rad/s]";

  // ---- Kinematics ----
  Real cp "cos(psi)";
  Real sp "sin(psi)";
  Real vx "world x velocity [m/s]";
  Real vy "world y velocity [m/s]";

  // ---- Current / disturbance ----
  Real u_rel "relative surge to current [m/s]";
  Real v_rel "relative sway to current [m/s]";
  Real Fdist_y "disturbance world y [N]";
  Real Fdist_bx "disturbance body x [N]";
  Real Fdist_by "disturbance body y [N]";

  // ---- Errors and control ----
  Real ex "world x error [m]";
  Real ey "world y error [m]";
  Real d "distance to dock [m]";
  Real d_safe "distance safe lower bound [m]";
  Real ex_body "forward error in body [m]";
  Real ey_body "lateral error in body [m]";
  Real u_des_raw "raw desired surge [m/s]";
  Real v_des_raw "raw desired sway [m/s]";
  Real u_des "saturated desired surge [m/s]";
  Real v_des "saturated desired sway [m/s]";
  Real psi_des "desired heading [rad]";
  Real epsi "heading error [rad]";
  Real Fx_cmd "commanded surge force [N]";
  Real Fy_cmd "commanded sway force [N]";
  Real Mz_cmd "commanded yaw moment [N.m]";

  // ---- Thrusters ----
  Real u1 "thruster 1 command [N]";
  Real u2 "thruster 2 command [N]";
  Real u3 "thruster 3 command [N]";
  Real u4 "thruster 4 command [N]";
  Real u5 "thruster 5 command [N] (vertical, planar-neutral)";
  Real u6 "thruster 6 command [N] (vertical, planar-neutral)";
  Real u1s "thruster 1 saturated [N]";
  Real u2s "thruster 2 saturated [N]";
  Real u3s "thruster 3 saturated [N]";
  Real u4s "thruster 4 saturated [N]";
  Real u5s "thruster 5 saturated [N]";
  Real u6s "thruster 6 saturated [N]";
  Real Fx_thr "actual thruster surge [N]";
  Real Fy_thr "actual thruster sway [N]";
  Real Mz_thr "actual thruster yaw moment [N.m]";
  Real Fthr_max "max abs thruster [N]";

  // ---- Contact ----
  Real pen "penetration [m]";
  Real ndirx "unit x robot->dock";
  Real ndiry "unit y robot->dock";
  Real closing_rate "closing rate on dock [m/s]";
  Real Fcontact "contact force magnitude [N]";
  Real Fc_wx "contact world x [N]";
  Real Fc_wy "contact world y [N]";
  Real Fc_bx "contact body x [N]";
  Real Fc_by "contact body y [N]";
  Boolean captured "capture flag";

  // ---- Total wrench ----
  Real Fx_total "total body surge force [N]";
  Real Fy_total "total body sway force [N]";
  Real Mz_total "total yaw moment [N.m]";

  // ---- Observables / sensors ----
  Real track_err "tracking error [m]";
  Real lat_err "lateral alignment error [m]";
  Real yaw_err "yaw alignment error [rad]";
  Real speed "robot speed [m/s]";

  // ---- Verification flags ----
  Boolean actuator_ok;
  Boolean speed_ok;
  Boolean lateral_ok;
  Boolean yaw_ok;
  Boolean contact_ok;
  Boolean track_ok;
  Boolean capture_ok;
  Boolean no_nan_inf;

equation
  // kinematics
  cp = cos(psi);
  sp = sin(psi);
  vx = u*cp - v*sp;
  vy = u*sp + v*cp;
  der(x) = vx;
  der(y) = vy;
  der(psi) = r;

  // relative velocity to cross-current (current in world +y)
  u_rel = u - c_speed*sp;
  v_rel = v - c_speed*cp;

  // controlled disturbance during middle third
  Fdist_y = if (time >= t_start_dist and time <= t_end_dist) then Fdist else 0.0;
  Fdist_bx = Fdist_y*sp;
  Fdist_by = Fdist_y*cp;

  // pose errors
  ex = x_dock - x;
  ey = y_dock - y;
  d = sqrt(ex*ex + ey*ey);
  d_safe = max(d, 0.001);
  ex_body = ex*cp + ey*sp;
  ey_body = -ex*sp + ey*cp;
  track_err = d;
  lat_err = abs(ey);
  speed = sqrt(u*u + v*v);

  // speed-scheduled pose control (saturates speed; reduces inside 1 m via position gain)
  u_des_raw = Kp_pos*ex_body;
  v_des_raw = Kp_pos*ey_body;
  u_des = max(-v_max, min(v_max, u_des_raw));
  v_des = max(-v_max, min(v_max, v_des_raw));

  // heading toward dock, guarded near singular point
  psi_des = if d_safe > 0.01 then atan2(ey, ex) else psi_dock;
  epsi = psi_des - psi;
  yaw_err = abs(sin(epsi));

  // control wrench
  Fx_cmd = Kp_u*(u_des - u);
  Fy_cmd = Kp_v*(v_des - v);
  Mz_cmd = Kp_psi*sin(epsi) - Kd_psi*r;

  // thruster allocation (pseudo-inverse of planar wrench map for 4 horizontal + 2 vertical)
  u1 = pinvFx*Fx_cmd + pinvFx*Fy_cmd + pinvMz*Mz_cmd;
  u2 = pinvFx*Fx_cmd - pinvFx*Fy_cmd - pinvMz*Mz_cmd;
  u3 = -pinvFx*Fx_cmd + pinvFx*Fy_cmd - pinvMz*Mz_cmd;
  u4 = -pinvFx*Fx_cmd - pinvFx*Fy_cmd + pinvMz*Mz_cmd;
  u5 = 0.0;
  u6 = 0.0;

  // saturation
  u1s = max(-Fmax, min(Fmax, u1));
  u2s = max(-Fmax, min(Fmax, u2));
  u3s = max(-Fmax, min(Fmax, u3));
  u4s = max(-Fmax, min(Fmax, u4));
  u5s = max(-Fmax, min(Fmax, u5));
  u6s = max(-Fmax, min(Fmax, u6));
  Fthr_max = max({abs(u1s), abs(u2s), abs(u3s), abs(u4s), abs(u5s), abs(u6s)});

  // actual wrench from saturated thrusters
  Fx_thr = c45*(u1s + u2s - u3s - u4s);
  Fy_thr = c45*(u1s - u2s + u3s - u4s);
  Mz_thr = Mzu*(u1s - u2s - u3s + u4s);

  // compliant capture ring (radial spring-damper centered on dock)
  pen = max(0.0, rcap - d);
  ndirx = ex/d_safe;
  ndiry = ey/d_safe;
  closing_rate = -(vx*ndirx + vy*ndiry);
  Fcontact = max(0.0, Kc*pen + Dc*pen*closing_rate);
  captured = pen > 0.0;
  Fc_wx = -Fcontact*ndirx;
  Fc_wy = -Fcontact*ndiry;
  Fc_bx = Fc_wx*cp + Fc_wy*sp;
  Fc_by = -Fc_wx*sp + Fc_wy*cp;

  // total wrench including thrusters, disturbance, contact, and hydrodynamic drag
  Fx_total = Fx_thr + Fdist_bx + Fc_bx - Ku*u_rel*abs(u_rel) - Kul*u_rel;
  Fy_total = Fy_thr + Fdist_by + Fc_by - Kv*v_rel*abs(v_rel) - Kvl*v_rel;
  Mz_total = Mz_thr - Kr*r*abs(r) - Krlin*r;

  // rigid-body planar dynamics (3DOF: surge, sway, yaw)
  (m + mx)*der(u) - (m + my)*v*r = Fx_total;
  (m + my)*der(v) + (m + mx)*u*r = Fy_total;
  (Iz + mz_a)*der(r) = Mz_total;

  // verification criteria
  actuator_ok = Fthr_max <= Fmax + 1e-6;
  speed_ok = speed <= 2.0;
  lateral_ok = lat_err < 0.08;
  yaw_ok = yaw_err < 0.05;
  contact_ok = Fcontact < 500.0;
  track_ok = if time >= 13.0 then track_err < 0.08 else true;
  capture_ok = captured;
  no_nan_inf = (x == x) and (y == y) and (psi == psi) and (u == u) and (v == v) and (r == r)
               and abs(x) < 1e9 and abs(y) < 1e9 and abs(psi) < 1e6
               and abs(u) < 1e6 and abs(v) < 1e6 and abs(r) < 1e6;

  annotation (experiment(StopTime = 20.0, Tolerance = 1e-6, Interval = 0.002));
end ROVDockF;