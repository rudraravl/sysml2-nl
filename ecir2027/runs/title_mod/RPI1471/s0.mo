model GantryPathSmoothA
  // ===== Travels and moving masses (SI) =====
  parameter Real Lx = 1.8  "X travel (m)";
  parameter Real Ly = 1.2  "Y travel (m)";
  parameter Real Lz = 0.55 "Z travel (m)";
  parameter Real mx_nom = 18.0 "X moving mass (kg)";
  parameter Real my_nom = 12.0 "Y moving mass (kg)";
  parameter Real mz_nom = 7.0  "Z moving mass (kg)";
  parameter Real F_max = 648.0 "Actuator command magnitude limit (N)";

  // ===== Scenario timing =====
  parameter Real T_end = 8.0   "Scenario duration (s)";
  parameter Real T_move = 6.0  "S-curve move duration (s)";
  parameter Real f_ctrl = 80.0 "Controller / record rate (Hz)";
  parameter Real T_sample = 1.0/f_ctrl "Sample period (s)";

  // ===== Normalized S-curve (symmetric, no cruise, 6 segments) =====
  // Constraint satisfied: amax_n*(t1^2 + 1.5*t1*t2 + 0.5*t2^2) = 0.5
  //   t1=0.5, t2=2.0 -> factor 3.75 -> amax_n = 2/15, jmax_n = amax_n/t1 = 4/15
  parameter Real t1 = 0.5     "jerk-up/down time (s)";
  parameter Real t2 = 2.0     "constant-accel time (s)";
  parameter Real amax_n = 2.0/15.0 "normalized peak accel (1/s^2)";
  parameter Real jmax_n = 4.0/15.0 "normalized peak jerk (1/s^3)";

  // ===== Endpoints (inside travels) =====
  parameter Real x0 = 0.10 "X initial (m)";
  parameter Real xf = 1.60 "X final (m)";
  parameter Real y0 = 0.10 "Y initial (m)";
  parameter Real yf = 1.00 "Y final (m)";
  parameter Real z0 = 0.05 "Z initial (m)";
  parameter Real zf = 0.50 "Z final (m)";

  // ===== Feedback (PD) =====
  parameter Real Kp = 400.0 "position gain (N/m)";
  parameter Real Kd = 170.0 "velocity gain (N.s/m)";  // ~critical damping for X axis
  parameter Real F_fb_limit = 300.0 "feedback correction bound (N)";

  // ===== 4 percent inertia disturbance during middle third =====
  parameter Real T_dist_start = T_end/3.0;
  parameter Real T_dist_end   = 2.0*T_end/3.0;
  parameter Real delta_m_frac = 0.04;

  // ===== Fixed keep-out object outside the nominal path =====
  parameter Real ko_x = -0.30 "keep-out center X (m), outside X travel";
  parameter Real ko_y = 0.60  "keep-out center Y (m)";
  parameter Real ko_z = 0.30  "keep-out center Z (m)";
  parameter Real ko_r = 0.10  "keep-out radius (m)";

  // ===== Trajectory (normalized) =====
  Real sn, snd, sndd;

  // ===== References =====
  Real rx, ry, rz;
  Real rvx, rvy, rvz;
  Real rax, ray, raz;

  // ===== Plant states =====
  Real x(start = x0, fixed = true);
  Real y(start = y0, fixed = true);
  Real z(start = z0, fixed = true);
  Real vx(start = 0.0, fixed = true);
  Real vy(start = 0.0, fixed = true);
  Real vz(start = 0.0, fixed = true);
  Real ax, ay, az;

  // ===== Actual masses (with disturbance) =====
  Real dist_active;
  Real mx_act, my_act, mz_act;

  // ===== Errors =====
  Real ex, ey, ez;
  Real evx, evy, evz;
  Real err_primary;

  // ===== Forces =====
  Real Ffx, Ffy, Ffz;
  Real Fbx, Fby, Fbz;
  Real Fx_cmd, Fy_cmd, Fz_cmd;

  // ===== Sampled traces at controller rate =====
  discrete Real rx_s, ry_s, rz_s;
  discrete Real vx_s, vy_s, vz_s;
  discrete Real ax_s, ay_s, az_s;
  discrete Real Fx_s, Fy_s, Fz_s;
  discrete Real ex_s, ey_s, ez_s;

  // ===== Safety / performance monitors =====
  Real dist_to_ko;
  Real jmax_x, jmax_y, jmax_z;
  Real peak_jerk;
  Real overshoot_x, overshoot_y, overshoot_z;
  Real osx, osy, osz;
  Real overshoot_frac;
  Boolean in_bounds;
  Boolean no_collision;
  Boolean tracking_ok;
  Boolean finite_ok;

protected
  function sat
    input Real u;
    input Real lim;
    output Real y;
  algorithm
    y := if u > lim then lim else if u < -lim then -lim else u;
  end sat;

  function sCurveFirstHalf
    input Real tt;
    input Real t1p, t2p, amaxp, jmaxp;
    output Real s, sd, sdd;
  protected
    Real tau;
  algorithm
    if tt < t1p then
      tau := tt;
      s   := jmaxp*tau*tau*tau/6.0;
      sd  := jmaxp*tau*tau/2.0;
      sdd := jmaxp*tau;
    elseif tt < t1p + t2p then
      tau := tt - t1p;
      s   := jmaxp*t1p*t1p*t1p/6.0 + 0.5*jmaxp*t1p*t1p*tau + 0.5*amaxp*tau*tau;
      sd  := 0.5*jmaxp*t1p*t1p + amaxp*tau;
      sdd := amaxp;
    else
      tau := tt - (t1p + t2p);
      s   := jmaxp*t1p*t1p*t1p/6.0 + 0.5*jmaxp*t1p*t1p*t2p + 0.5*amaxp*t2p*t2p
             + (0.5*jmaxp*t1p*t1p + amaxp*t2p)*tau + 0.5*amaxp*tau*tau - jmaxp*tau*tau*tau/6.0;
      sd  := (0.5*jmaxp*t1p*t1p + amaxp*t2p) + amaxp*tau - jmaxp*tau*tau/2.0;
      sdd := amaxp - jmaxp*tau;
    end if;
  end sCurveFirstHalf;

  function sCurveNorm
    input Real t;
    input Real Tm;
    input Real t1p, t2p, amaxp, jmaxp;
    output Real s, sd, sdd;
  protected
    Real tt, sh, sdh, sddh;
  algorithm
    tt := t;
    if tt <= 0.0 then
      s := 0.0; sd := 0.0; sdd := 0.0;
    elseif tt >= Tm then
      s := 1.0; sd := 0.0; sdd := 0.0;
    elseif tt <= Tm/2.0 then
      (s, sd, sdd) := sCurveFirstHalf(tt, t1p, t2p, amaxp, jmaxp);
    else
      (sh, sdh, sddh) := sCurveFirstHalf(Tm - tt, t1p, t2p, amaxp, jmaxp);
      s   := 1.0 - sh;
      sd  := sdh;
      sdd := -sddh;
    end if;
  end sCurveNorm;

equation
  // Trajectory generation (continuous)
  (sn, snd, sndd) = sCurveNorm(time, T_move, t1, t2, amax_n, jmax_n);

  rx  = x0 + (xf - x0)*sn;
  ry  = y0 + (yf - y0)*sn;
  rz  = z0 + (zf - z0)*sn;
  rvx = (xf - x0)*snd;
  rvy = (yf - y0)*snd;
  rvz = (zf - z0)*snd;
  rax = (xf - x0)*sndd;
  ray = (yf - y0)*sndd;
  raz = (zf - z0)*sndd;

  // Disturbance schedule (middle third of scenario)
  dist_active = if (time >= T_dist_start) and (time <= T_dist_end) then 1.0 else 0.0;
  mx_act = mx_nom*(1.0 + delta_m_frac*dist_active);
  my_act = my_nom*(1.0 + delta_m_frac*dist_active);
  mz_act = mz_nom*(1.0 + delta_m_frac*dist_active);

  // Plant dynamics (double integrator per axis)
  der(x)  = vx;
  der(y)  = vy;
  der(z)  = vz;
  der(vx) = ax;
  der(vy) = ay;
  der(vz) = az;
  ax = Fx_cmd / mx_act;
  ay = Fy_cmd / my_act;
  az = Fz_cmd / mz_act;

  // Tracking errors
  ex  = rx  - x;
  ey  = ry  - y;
  ez  = rz  - z;
  evx = rvx - vx;
  evy = rvy - vy;
  evz = rvz - vz;

  // Feedforward inverse dynamics (nominal mass)
  Ffx = mx_nom*rax;
  Ffy = my_nom*ray;
  Ffz = mz_nom*raz;

  // Bounded feedback correction
  Fbx = sat(Kp*ex + Kd*evx, F_fb_limit);
  Fby = sat(Kp*ey + Kd*evy, F_fb_limit);
  Fbz = sat(Kp*ez + Kd*evz, F_fb_limit);

  // Bounded total actuator command
  Fx_cmd = sat(Ffx + Fbx, F_max);
  Fy_cmd = sat(Ffy + Fby, F_max);
  Fz_cmd = sat(Ffz + Fbz, F_max);

  // Primary tracking error (Euclidean, guarded against sqrt(0))
  err_primary = sqrt(ex*ex + ey*ey + ez*ez + 1.0e-12);

  // Distance to keep-out object (guarded)
  dist_to_ko = sqrt((x - ko_x)*(x - ko_x) + (y - ko_y)*(y - ko_y) + (z - ko_z)*(z - ko_z) + 1.0e-12);

  // Peak (reference) jerk per axis and overall
  jmax_x = abs(jmax_n*(xf - x0));
  jmax_y = abs(jmax_n*(yf - y0));
  jmax_z = abs(jmax_n*(zf - z0));
  peak_jerk = if (jmax_x >= jmax_y) and (jmax_x >= jmax_z) then jmax_x
              else if jmax_y >= jmax_z then jmax_y else jmax_z;

  // Overshoot beyond target after move completes
  overshoot_x = if time > T_move then abs(x - xf) else 0.0;
  overshoot_y = if time > T_move then abs(y - yf) else 0.0;
  overshoot_z = if time > T_move then abs(z - zf) else 0.0;
  osx = overshoot_x/abs(xf - x0);
  osy = overshoot_y/abs(yf - y0);
  osz = overshoot_z/abs(zf - z0);
  overshoot_frac = if (osx >= osy) and (osx >= osz) then osx
                   else if osy >= osz then osy else osz;

  // Safety / performance booleans
  in_bounds = (x >= 0.0) and (x <= Lx) and (y >= 0.0) and (y <= Ly) and (z >= 0.0) and (z <= Lz)
              and (abs(Fx_cmd) <= F_max + 1.0e-6)
              and (abs(Fy_cmd) <= F_max + 1.0e-6)
              and (abs(Fz_cmd) <= F_max + 1.0e-6);
  no_collision = dist_to_ko > ko_r;
  tracking_ok = (time <= 5.2) or (err_primary < 0.034);
  finite_ok = (abs(x) < 1.0e6) and (abs(y) < 1.0e6) and (abs(z) < 1.0e6)
              and (abs(vx) < 1.0e6) and (abs(vy) < 1.0e6) and (abs(vz) < 1.0e6)
              and (abs(ax) < 1.0e6) and (abs(ay) < 1.0e6) and (abs(az) < 1.0e6)
              and (abs(Fx_cmd) < 1.0e6) and (abs(Fy_cmd) < 1.0e6) and (abs(Fz_cmd) < 1.0e6)
              and (abs(err_primary) < 1.0e6);

  // Sampled recording at controller rate (80 Hz)
  when sample(0, T_sample) then
    rx_s = rx;  ry_s = ry;  rz_s = rz;
    vx_s = vx;  vy_s = vy;  vz_s = vz;
    ax_s = ax;  ay_s = ay;  az_s = az;
    Fx_s = Fx_cmd;  Fy_s = Fy_cmd;  Fz_s = Fz_cmd;
    ex_s = ex;  ey_s = ey;  ez_s = ez;
  end when;

  // Runtime assertions for stated requirements
  assert(in_bounds,        "State or command out of bounds");
  assert(no_collision,     "Collision with keep-out object");
  assert(tracking_ok,      "Primary tracking error exceeded 0.034 m after 5.2 s");
  assert(overshoot_frac < 0.10, "Overshoot exceeded 10 percent");
  assert(finite_ok,        "Non-finite physical/control/estimator value detected");

  annotation (
    experiment(StartTime = 0, StopTime = 8.0, Tolerance = 1.0e-6, Interval = 1.0/80.0),
    Documentation(info = "GantryPathSmoothA: jerk-limited S-curve trajectory control of a 3-axis Cartesian gantry. Feedforward inverse dynamics plus bounded PD feedback. A 4 percent inertia disturbance is applied during the middle third of the 8 s scenario. One fixed keep-out object (outside the nominal X travel) is monitored for collision. State, command, and sensor traces are recorded at the 80 Hz controller rate.")
  );
end GantryPathSmoothA;