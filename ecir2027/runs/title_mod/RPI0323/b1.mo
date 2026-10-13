model StewartTraceE
  import Modelica.Constants.pi;

  // ===== Parameters from the requirement =====
  parameter Real rb = 0.45       "base anchor radius [m]";
  parameter Real rp = 0.32       "moving platform anchor radius [m]";
  parameter Real m_plat = 36.0   "platform mass [kg]";
  parameter Real L_min = 0.55    "minimum strut length [m]";
  parameter Real L_max = 0.85    "maximum strut length [m]";
  parameter Real F_max = 4620.0  "max strut force magnitude per strut [N]";
  parameter Real r_circle = 0.10 "trajectory circle radius [m]";
  parameter Real T_total = 16.0  "total run time [s]";
  parameter Real f_sample = 250.0 "control and sensor rate [Hz]";
  parameter Real dt = 1.0 / f_sample "sample period [s]";
  parameter Real F_dist = 12.0   "middle-third disturbance force magnitude [N]";
  parameter Real track_tol = 0.007 "primary path error tolerance [m]";
  parameter Real track_check_t = 10.4 "tracking check start time [s]";
  parameter Real g = 9.81        "gravity [m/s^2]";

  // ===== Design choices not stated in the requirement =====
  parameter Real h_nom = 0.65    "nominal platform height [m] (not stated; chosen within strut bounds)";
  parameter Real Kp_strut = 20000.0 "strut position gain [N/m] (not stated; tuned)";
  parameter Real Kd_strut = 1000.0  "strut velocity gain [N*s/m] (not stated; tuned)";
  parameter Real closure_tol = track_tol "closure tolerance [m] (not stated; path tolerance reused)";
  parameter Real obs_x = 0.30    "obstacle center x [m] (not stated; chosen outside circle)";
  parameter Real obs_y = 0.0     "obstacle center y [m] (not stated; chosen outside circle)";
  parameter Real obs_r = 0.05    "obstacle radius [m] (not stated; chosen to keep obstacle outside circle)";

  parameter Real beta[6]  = {0, 60, 120, 180, 240, 300}  * pi / 180 "base anchor angles [rad]";
  parameter Real alpha[6] = {30, 90, 150, 210, 270, 330} * pi / 180 "platform anchor angles [rad]";

  // ===== Continuous platform state =====
  Real x(start = r_circle, fixed = true)  "platform center x [m]";
  Real y(start = 0.0, fixed = true)       "platform center y [m]";
  Real z(start = h_nom, fixed = true)     "platform center z [m]";
  Real vx(start = 0.0, fixed = true)      "platform velocity x [m/s]";
  Real vy(start = 0.0, fixed = true)      "platform velocity y [m/s]";
  Real vz(start = 0.0, fixed = true)      "platform velocity z [m/s]";

  // ===== Strut geometry =====
  Real sx[6]       "strut vector x [m]";
  Real sy[6]       "strut vector y [m]";
  Real sz_vec[6]   "strut vector z [m]";
  Real L[6]        "actual strut length [m]";
  Real nx[6]       "strut unit vector x";
  Real ny[6]       "strut unit vector y";
  Real nz[6]       "strut unit vector z";
  Real Ldot[6]     "strut length rate [m/s]";
  Real sum_nz2     "sum of nz^2";

  // ===== Discrete controller and sensor variables at 250 Hz =====
  discrete Real xd_d(start = r_circle)     "desired trajectory x [m]";
  discrete Real yd_d(start = 0.0)         "desired trajectory y [m]";
  discrete Real zd_d(start = h_nom)       "desired trajectory z [m]";
  discrete Real Ld_d[6](each start = 0.70) "desired strut lengths [m]";
  discrete Real u_cmd_d[6](each start = 0.0) "commanded strut force [N]";
  discrete Real u_sat[6](each start = 0.0)   "saturated strut force [N]";
  discrete Real L_enc[6](each start = 0.70)  "encoder strut length [m]";
  discrete Real x_meas(start = r_circle) "direct pose measurement x [m]";
  discrete Real y_meas(start = 0.0)       "direct pose measurement y [m]";
  discrete Real z_meas(start = h_nom)     "direct pose measurement z [m]";
  discrete Real path_error_post(start = 0.0) "max tracking error after check time [m]";
  discrete Boolean accept(start = false) "fail-closed acceptance flag";

  // ===== Continuous reference =====
  Real xd_ref, yd_ref, zd_ref;

  // ===== Metrics and checks =====
  Real closure_err     "closure error norm [m]";
  Real path_error      "tracking error norm [m]";
  Real sing_margin     "singularity margin";
  Real clearance       "obstacle clearance [m]";
  Real joint_viol[6]   "per-strut joint bound violation [m]";
  Real effort_viol[6]  "per-strut effort bound violation [N]";
  Real joint_viol_max  "max joint bound violation [m]";
  Real effort_viol_max "max effort bound violation [N]";
  Real Fdist_x         "disturbance force x [N]";
  Real Fdist_y         "disturbance force y [N]";
  Real M11, M22, M33, M12, M13, M23, detM;
  Boolean no_nan;
  Boolean track_ok, joint_ok, effort_ok, closure_ok, sing_ok, clear_ok;

equation

  // ===== Reference trajectory: circle in the plane z = h_nom =====
  xd_ref = r_circle * cos(2.0 * pi * time / T_total);
  yd_ref = r_circle * sin(2.0 * pi * time / T_total);
  zd_ref = h_nom;

  // ===== Strut kinematics =====
  for i in 1:6 loop
    sx[i]     = (x + rp * cos(alpha[i])) - rb * cos(beta[i]);
    sy[i]     = (y + rp * sin(alpha[i])) - rb * sin(beta[i]);
    sz_vec[i] = z;
    L[i]      = sqrt(sx[i]^2 + sy[i]^2 + sz_vec[i]^2);
    nx[i]     = sx[i] / L[i];
    ny[i]     = sy[i] / L[i];
    nz[i]     = sz_vec[i] / L[i];
    Ldot[i]   = nx[i] * vx + ny[i] * vy + nz[i] * vz;
  end for;

  sum_nz2 = nz[1]^2 + nz[2]^2 + nz[3]^2 + nz[4]^2 + nz[5]^2 + nz[6]^2;

  // ===== Platform dynamics: point-mass platform with six strut forces =====
  der(x)  = vx;
  der(y)  = vy;
  der(z)  = vz;
  der(vx) = (u_sat[1] * nx[1] + u_sat[2] * nx[2] + u_sat[3] * nx[3] +
             u_sat[4] * nx[4] + u_sat[5] * nx[5] + u_sat[6] * nx[6] +
             Fdist_x) / m_plat;
  der(vy) = (u_sat[1] * ny[1] + u_sat[2] * ny[2] + u_sat[3] * ny[3] +
             u_sat[4] * ny[4] + u_sat[5] * ny[5] + u_sat[6] * ny[6] +
             Fdist_y) / m_plat;
  der(vz) = (u_sat[1] * nz[1] + u_sat[2] * nz[2] + u_sat[3] * nz[3] +
             u_sat[4] * nz[4] + u_sat[5] * nz[5] + u_sat[6] * nz[6] -
             m_plat * g) / m_plat;

  // ===== Controlled 12 N output load during the middle third =====
  Fdist_x = if (time >= T_total / 3.0 and time <= 2.0 * T_total / 3.0) then F_dist else 0.0;
  Fdist_y = 0.0;

  // ===== Closure error =====
  closure_err = sqrt((Ld_d[1] - L[1])^2 + (Ld_d[2] - L[2])^2 +
                     (Ld_d[3] - L[3])^2 + (Ld_d[4] - L[4])^2 +
                     (Ld_d[5] - L[5])^2 + (Ld_d[6] - L[6])^2);

  // ===== Path tracking error =====
  path_error = sqrt((x - xd_ref)^2 + (y - yd_ref)^2 + (z - zd_ref)^2);

  // ===== Singularity margin from translational Jacobian determinant =====
  M11 = nx[1]^2 + nx[2]^2 + nx[3]^2 + nx[4]^2 + nx[5]^2 + nx[6]^2;
  M22 = ny[1]^2 + ny[2]^2 + ny[3]^2 + ny[4]^2 + ny[5]^2 + ny[6]^2;
  M33 = nz[1]^2 + nz[2]^2 + nz[3]^2 + nz[4]^2 + nz[5]^2 + nz[6]^2;
  M12 = nx[1]*ny[1] + nx[2]*ny[2] + nx[3]*ny[3] + nx[4]*ny[4] + nx[5]*ny[5] + nx[6]*ny[6];
  M13 = nx[1]*nz[1] + nx[2]*nz[2] + nx[3]*nz[3] + nx[4]*nz[4] + nx[5]*nz[5] + nx[6]*nz[6];
  M23 = ny[1]*nz[1] + ny[2]*nz[2] + ny[3]*nz[3] + ny[4]*nz[4] + ny[5]*nz[5] + ny[6]*nz[6];
  detM = M11*(M22*M33 - M23*M23) - M12*(M12*M33 - M13*M23) + M13*(M12*M23 - M22*M13);
  sing_margin = if detM > 0.0 then sqrt(detM) else 0.0;

  // ===== Obstacle clearance =====
  clearance = sqrt((x - obs_x)^2 + (y - obs_y)^2) - obs_r;

  // ===== Joint and effort bound violations =====
  for i in 1:6 loop
    joint_viol[i]  = (if L[i] < L_min then L_min - L[i] else 0.0) +
                     (if L[i] > L_max then L[i] - L_max else 0.0);
    effort_viol[i] = if abs(u_cmd_d[i]) > F_max then abs(u_cmd_d[i]) - F_max else 0.0;
  end for;
  joint_viol_max  = max(joint_viol[i] for i in 1:6);
  effort_viol_max = max(effort_viol[i] for i in 1:6);

  // ===== NaN / infinity check on physical, control, and estimator traces =====
  no_nan =
    (x == x) and (y == y) and (z == z) and
    (vx == vx) and (vy == vy) and (vz == vz) and
    (L[1] == L[1]) and (L[2] == L[2]) and (L[3] == L[3]) and
    (L[4] == L[4]) and (L[5] == L[5]) and (L[6] == L[6]) and
    (u_cmd_d[1] == u_cmd_d[1]) and (u_cmd_d[2] == u_cmd_d[2]) and
    (u_cmd_d[3] == u_cmd_d[3]) and (u_cmd_d[4] == u_cmd_d[4]) and
    (u_cmd_d[5] == u_cmd_d[5]) and (u_cmd_d[6] == u_cmd_d[6]) and
    (u_sat[1] == u_sat[1]) and (u_sat[2] == u_sat[2]) and
    (u_sat[3] == u_sat[3]) and (u_sat[4] == u_sat[4]) and
    (u_sat[5] == u_sat[5]) and (u_sat[6] == u_sat[6]) and
    (L_enc[1] == L_enc[1]) and (L_enc[2] == L_enc[2]) and
    (L_enc[3] == L_enc[3]) and (L_enc[4] == L_enc[4]) and
    (L_enc[5] == L_enc[5]) and (L_enc[6] == L_enc[6]) and
    (x_meas == x_meas) and (y_meas == y_meas) and (z_meas == z_meas) and
    (path_error_post == path_error_post) and
    (abs(x) < 1e12) and (abs(y) < 1e12) and (abs(z) < 1e12) and
    (abs(vx) < 1e12) and (abs(vy) < 1e12) and (abs(vz) < 1e12) and
    (abs(L[1]) < 1e12) and (abs(L[2]) < 1e12) and (abs(L[3]) < 1e12) and
    (abs(L[4]) < 1e12) and (abs(L[5]) < 1e12) and (abs(L[6]) < 1e12) and
    (abs(u_cmd_d[1]) < 1e12) and (abs(u_cmd_d[2]) < 1e12) and
    (abs(u_cmd_d[3]) < 1e12) and (abs(u_cmd_d[4]) < 1e12) and
    (abs(u_cmd_d[5]) < 1e12) and (abs(u_cmd_d[6]) < 1e12) and
    (abs(u_sat[1]) < 1e12) and (abs(u_sat[2]) < 1e12) and
    (abs(u_sat[3]) < 1e12) and (abs(u_sat[4]) < 1e12) and
    (abs(u_sat[5]) < 1e12) and (abs(u_sat[6]) < 1e12) and
    (abs(L_enc[1]) < 1e12) and (abs(L_enc[2]) < 1e12) and
    (abs(L_enc[3]) < 1e12) and (abs(L_enc[4]) < 1e12) and
    (abs(L_enc[5]) < 1e12) and (abs(L_enc[6]) < 1e12) and
    (abs(x_meas) < 1e12) and (abs(y_meas) < 1e12) and (abs(z_meas) < 1e12) and
    (abs(path_error_post) < 1e12);

  // ===== Individual acceptance flags =====
  track_ok   = path_error < track_tol;
  joint_ok   = joint_viol_max <= 0.0;
  effort_ok  = effort_viol_max <= 0.0;
  closure_ok = closure_err < closure_tol;
  sing_ok    = sing_margin > 0.0;
  clear_ok   = clearance > 0.0;

  // ===== Discrete inverse-kinematic controller at 250 Hz =====
  when sample(0.0, dt) then
    // Desired output pose
    xd_d = r_circle * cos(2.0 * pi * time / T_total);
    yd_d = r_circle * sin(2.0 * pi * time / T_total);
    zd_d = h_nom;

    // Inverse kinematics: desired strut lengths from desired pose
    for i in 1:6 loop
      Ld_d[i] = sqrt((xd_d + rp * cos(alpha[i]) - rb * cos(beta[i]))^2 +
                     (yd_d + rp * sin(alpha[i]) - rb * sin(beta[i]))^2 +
                     zd_d^2);
    end for;

    // Force command with closure stabilization, velocity damping, and gravity feedforward
    for i in 1:6 loop
      u_cmd_d[i] = Kp_strut * (Ld_d[i] - L[i]) - Kd_strut * Ldot[i] +
                   m_plat * g * nz[i] / (if sum_nz2 > 1e-6 then sum_nz2 else 1e-6);
      u_sat[i]   = if u_cmd_d[i] > F_max then F_max
                   else if u_cmd_d[i] < -F_max then -F_max
                   else u_cmd_d[i];
      L_enc[i]   = L[i];
    end for;

    // Direct output-pose measurement
    x_meas = x;
    y_meas = y;
    z_meas = z;

    // Running max tracking error after the check time
    path_error_post = if time >= track_check_t
                      then (if pre(path_error_post) > path_error then pre(path_error_post) else path_error)
                      else pre(path_error_post);

    // Fail-closed acceptance: only true after check time when all conditions hold
    accept = (time >= track_check_t) and
             (path_error_post < track_tol) and
             joint_ok and effort_ok and closure_ok and
             sing_ok and clear_ok and no_nan;
  end when;

  annotation(
    experiment(StopTime = 16.0, Tolerance = 1e-6, Interval = 0.004),
    Documentation(info = "StewartTraceE: closed-chain 6-strut Stewart platform tracing a 0.10 m radius circle. Fixed 0.45 m base, 36 kg / 0.32 m platform, six variable-length struts (0.55-0.85 m) with force-limited actuators (4620 N/strut). 250 Hz inverse-kinematic trajectory control with closure stabilization and gravity feedforward. 12 N middle-third disturbance. Fixed obstacle with explicit clearance. Acceptance is fail-closed: requires joint bounds, effort bounds, closure error, path error < 0.007 m after 10.4 s, positive singularity margin, positive clearance, and no NaN/Inf."));
end StewartTraceE;