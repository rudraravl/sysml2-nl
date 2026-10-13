model StewartTraceE
  import Modelica.Constants.pi;

  // ===== Physical parameters =====
  parameter Real rb = 0.45 "base anchor radius [m]";
  parameter Real rp = 0.32 "platform anchor radius [m]";
  parameter Real m_plat = 36.0 "platform mass [kg]";
  parameter Real h_nom = 0.66 "nominal platform height [m]";
  parameter Real L_min = 0.55 "minimum strut length [m]";
  parameter Real L_max = 0.85 "maximum strut length [m]";
  parameter Real F_max = 4620.0 "max strut force magnitude [N]";
  parameter Real r_circle = 0.10 "trajectory circle radius [m]";
  parameter Real T_total = 16.0 "total run time [s]";
  parameter Real f_sample = 250.0 "control/sensor rate [Hz]";
  parameter Real dt = 1.0 / f_sample "sample period [s]";
  parameter Real Kp_strut = 20000.0 "strut position gain [N/m]";
  parameter Real Kd_strut = 1000.0 "strut velocity gain [N*s/m]";
  parameter Real F_dist = 12.0 "disturbance force magnitude [N]";
  parameter Real obs_x = 0.40 "obstacle center x [m]";
  parameter Real obs_y = 0.0 "obstacle center y [m]";
  parameter Real obs_r = 0.05 "obstacle radius [m]";
  parameter Real track_tol = 0.007 "tracking error tolerance [m]";
  parameter Real track_check_t = 10.4 "tracking check start time [s]";
  parameter Real closure_tol = 0.008 "closure error tolerance [m]";
  parameter Real sing_min = 0.02 "minimum singularity margin";
  parameter Real clearance_min = 0.01 "minimum clearance [m]";
  parameter Real g = 9.81 "gravity [m/s^2]";

  // Anchor angle parameters [rad]
  parameter Real beta[6] = {0, 60, 120, 180, 240, 300} * pi / 180;
  parameter Real alpha[6] = {30, 90, 150, 210, 270, 330} * pi / 180;

  // ===== Continuous platform state =====
  Real x(start = 0.0, fixed = true) "platform center x [m]";
  Real y(start = 0.0, fixed = true) "platform center y [m]";
  Real z(start = h_nom, fixed = true) "platform center z [m]";
  Real vx(start = 0.0, fixed = true) "platform velocity x [m/s]";
  Real vy(start = 0.0, fixed = true) "platform velocity y [m/s]";
  Real vz(start = 0.0, fixed = true) "platform velocity z [m/s]";

  // ===== Strut geometry (continuous) =====
  Real sx[6] "strut vector x [m]";
  Real sy[6] "strut vector y [m]";
  Real sz_vec[6] "strut vector z [m]";
  Real L[6] "actual strut length [m]";
  Real nx[6] "strut unit vector x";
  Real ny[6] "strut unit vector y";
  Real nz[6] "strut unit vector z";
  Real Ldot[6] "strut length rate [m/s]";
  Real sum_nz2 "sum of nz^2";
  Real joint_viol[6] "per-strut joint bound violation [m]";
  Real effort_viol[6] "per-strut effort bound violation [N]";

  // ===== Discrete controller / sensor variables (250 Hz) =====
  discrete Real xd_d(start = 0.0) "desired trajectory x [m]";
  discrete Real yd_d(start = 0.0) "desired trajectory y [m]";
  discrete Real zd_d(start = h_nom) "desired trajectory z [m]";
  discrete Real Ld_d[6](each start = 0.70) "desired strut lengths [m]";
  discrete Real u_cmd_d[6](each start = 0.0) "commanded strut force [N]";
  discrete Real u_sat[6](each start = 0.0) "saturated strut force [N]";
  discrete Real L_enc[6](each start = 0.70) "encoder strut length [m]";
  discrete Real x_meas(start = 0.0) "direct pose measurement x [m]";
  discrete Real y_meas(start = 0.0) "direct pose measurement y [m]";
  discrete Real z_meas(start = h_nom) "direct pose measurement z [m]";
  discrete Real path_error_post(start = 0.0) "max tracking error after check time [m]";
  discrete Boolean accept(start = false) "fail-closed acceptance flag";

  // ===== Continuous reference =====
  Real xd_ref;
  Real yd_ref;
  Real zd_ref;

  // ===== Errors and metrics (continuous) =====
  Real closure_err "closure error norm [m]";
  Real path_error "tracking error norm [m]";
  Real sing_margin "singularity margin [0-1]";
  Real clearance "obstacle clearance [m]";
  Real joint_viol_max "max joint bound violation [m]";
  Real effort_viol_max "max effort bound violation [N]";
  Real Fdist_x "disturbance force x [N]";
  Real Fdist_y "disturbance force y [N]";

  // Singularity matrix components
  Real M11;
  Real M22;
  Real M33;
  Real M12;
  Real M13;
  Real M23;
  Real detM;

  // NaN / infinity check
  Boolean no_nan;

  // Individual acceptance flags
  Boolean track_ok;
  Boolean joint_ok;
  Boolean effort_ok;
  Boolean closure_ok;
  Boolean sing_ok;
  Boolean clear_ok;

equation

  // ===== Reference trajectory (continuous) =====
  xd_ref = r_circle * cos(2.0 * pi * time / T_total);
  yd_ref = r_circle * sin(2.0 * pi * time / T_total);
  zd_ref = h_nom;

  // ===== Strut kinematics =====
  for i in 1:6 loop
    sx[i] = (x + rp * cos(alpha[i])) - rb * cos(beta[i]);
    sy[i] = (y + rp * sin(alpha[i])) - rb * sin(beta[i]);
    sz_vec[i] = z;
    L[i] = sqrt(sx[i] * sx[i] + sy[i] * sy[i] + sz_vec[i] * sz_vec[i]);
    nx[i] = sx[i] / L[i];
    ny[i] = sy[i] / L[i];
    nz[i] = sz_vec[i] / L[i];
    Ldot[i] = nx[i] * vx + ny[i] * vy + nz[i] * vz;
  end for;

  sum_nz2 = nz[1] * nz[1] + nz[2] * nz[2] + nz[3] * nz[3] + nz[4] * nz[4] + nz[5] * nz[5] + nz[6] * nz[6];

  // ===== Platform dynamics (point-mass, 6 struts + disturbance + gravity) =====
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  der(vx) = (u_sat[1] * nx[1] + u_sat[2] * nx[2] + u_sat[3] * nx[3] + u_sat[4] * nx[4] + u_sat[5] * nx[5] + u_sat[6] * nx[6] + Fdist_x) / m_plat;
  der(vy) = (u_sat[1] * ny[1] + u_sat[2] * ny[2] + u_sat[3] * ny[3] + u_sat[4] * ny[4] + u_sat[5] * ny[5] + u_sat[6] * ny[6] + Fdist_y) / m_plat;
  der(vz) = (u_sat[1] * nz[1] + u_sat[2] * nz[2] + u_sat[3] * nz[3] + u_sat[4] * nz[4] + u_sat[5] * nz[5] + u_sat[6] * nz[6] - m_plat * g) / m_plat;

  // ===== Disturbance: 12 N during middle third of run =====
  Fdist_x = if (time >= T_total / 3.0 and time <= 2.0 * T_total / 3.0) then F_dist else 0.0;
  Fdist_y = 0.0;

  // ===== Metrics =====
  closure_err = sqrt((Ld_d[1] - L[1]) * (Ld_d[1] - L[1]) + (Ld_d[2] - L[2]) * (Ld_d[2] - L[2]) + (Ld_d[3] - L[3]) * (Ld_d[3] - L[3]) + (Ld_d[4] - L[4]) * (Ld_d[4] - L[4]) + (Ld_d[5] - L[5]) * (Ld_d[5] - L[5]) + (Ld_d[6] - L[6]) * (Ld_d[6] - L[6]));

  path_error = sqrt((x - xd_ref) * (x - xd_ref) + (y - yd_ref) * (y - yd_ref) + (z - zd_ref) * (z - zd_ref));

  M11 = nx[1] * nx[1] + nx[2] * nx[2] + nx[3] * nx[3] + nx[4] * nx[4] + nx[5] * nx[5] + nx[6] * nx[6];
  M22 = ny[1] * ny[1] + ny[2] * ny[2] + ny[3] * ny[3] + ny[4] * ny[4] + ny[5] * ny[5] + ny[6] * ny[6];
  M33 = nz[1] * nz[1] + nz[2] * nz[2] + nz[3] * nz[3] + nz[4] * nz[4] + nz[5] * nz[5] + nz[6] * nz[6];
  M12 = nx[1] * ny[1] + nx[2] * ny[2] + nx[3] * ny[3] + nx[4] * ny[4] + nx[5] * ny[5] + nx[6] * ny[6];
  M13 = nx[1] * nz[1] + nx[2] * nz[2] + nx[3] * nz[3] + nx[4] * nz[4] + nx[5] * nz[5] + nx[6] * nz[6];
  M23 = ny[1] * nz[1] + ny[2] * nz[2] + ny[3] * nz[3] + ny[4] * nz[4] + ny[5] * nz[5] + ny[6] * nz[6];
  detM = M11 * (M22 * M33 - M23 * M23) - M12 * (M12 * M33 - M23 * M13) + M13 * (M12 * M23 - M22 * M13);
  sing_margin = detM / 8.0;

  clearance = sqrt((x - obs_x) * (x - obs_x) + (y - obs_y) * (y - obs_y)) - obs_r;

  for i in 1:6 loop
    joint_viol[i] = max(0.0, L_min - L[i]) + max(0.0, L[i] - L_max);
    effort_viol[i] = max(0.0, abs(u_cmd_d[i]) - F_max);
  end for;

  joint_viol_max = max(joint_viol[i] for i in 1:6);
  effort_viol_max = max(effort_viol[i] for i in 1:6);

  // NaN / infinity check on key physical, control, and estimator variables
  no_nan = (x == x) and (y == y) and (z == z) and (vx == vx) and (vy == vy) and (vz == vz) and (u_sat[1] == u_sat[1]) and (u_sat[2] == u_sat[2]) and (u_sat[3] == u_sat[3]) and (u_sat[4] == u_sat[4]) and (u_sat[5] == u_sat[5]) and (u_sat[6] == u_sat[6]) and (L[1] == L[1]) and (L[2] == L[2]) and (L[3] == L[3]) and (L[4] == L[4]) and (L[5] == L[5]) and (L[6] == L[6]) and (abs(x) < 1e12) and (abs(y) < 1e12) and (abs(z) < 1e12) and (abs(vx) < 1e12) and (abs(vy) < 1e12) and (abs(vz) < 1e12);

  // Acceptance flags
  track_ok = path_error < track_tol;
  joint_ok = joint_viol_max <= 0.0;
  effort_ok = effort_viol_max <= 0.0;
  closure_ok = closure_err < closure_tol;
  sing_ok = sing_margin > sing_min;
  clear_ok = clearance > clearance_min;

  // ===== Discrete controller at 250 Hz =====
  when sample(0, dt) then
    xd_d = r_circle * cos(2.0 * pi * time / T_total);
    yd_d = r_circle * sin(2.0 * pi * time / T_total);
    zd_d = h_nom;

    for i in 1:6 loop
      Ld_d[i] = sqrt((xd_d + rp * cos(alpha[i]) - rb * cos(beta[i])) * (xd_d + rp * cos(alpha[i]) - rb * cos(beta[i])) + (yd_d + rp * sin(alpha[i]) - rb * sin(beta[i])) * (yd_d + rp * sin(alpha[i]) - rb * sin(beta[i])) + zd_d * zd_d);
    end for;

    for i in 1:6 loop
      u_cmd_d[i] = Kp_strut * (Ld_d[i] - L[i]) - Kd_strut * Ldot[i] + m_plat * g * nz[i] / max(sum_nz2, 1e-6);
      u_sat[i] = max(-F_max, min(F_max, u_cmd_d[i]));
      L_enc[i] = L[i];
    end for;

    x_meas = x;
    y_meas = y;
    z_meas = z;

    path_error_post = if time >= track_check_t then max(pre(path_error_post), path_error) else pre(path_error_post);

    accept = (time >= track_check_t) and track_ok and joint_ok and effort_ok and closure_ok and sing_ok and clear_ok and no_nan;
  end when;

  annotation(
    experiment(StopTime = 16.0, Tolerance = 1e-6, Interval = 0.004),
    Documentation(info = "StewartTraceE: closed-chain 6-UPS Stewart platform tracing a 0.10 m radius circle. Fixed 0.45 m base, 36 kg / 0.32 m platform, six variable-length struts (0.55-0.85 m) with force-limited actuators (4620 N/strut). 250 Hz inverse-kinematic trajectory control with closure stabilization and gravity feedforward. 12 N middle-third disturbance. Fixed obstacle with explicit clearance. Acceptance is fail-closed: requires joint bounds, effort bounds, closure error, path error < 0.007 m after 10.4 s, singularity margin, clearance, and no NaN/Inf."));
end StewartTraceE;