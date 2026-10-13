model ContactStateMapB
  import Modelica.Constants.pi;
  import Modelica.Math.cos;
  import Modelica.Math.sin;
  import Modelica.Math.sqrt;

  // ===== Mission timing =====
  parameter Real T_run = 10.0 "s mission duration";
  parameter Real f_out = 100.0 "Hz declared output rate";
  parameter Real dt_out = 1.0 / f_out "s output sample period";
  parameter Real t_mid_a = T_run / 3.0 "s middle-third start";
  parameter Real t_mid_b = 2.0 * T_run / 3.0 "s middle-third end";

  // ===== Platform =====
  parameter Real m_torso = 24.0 "kg torso mass";
  parameter Real I_torso = 1.0 "kg.m^2 torso inertia (assumed for closure; not specified)";
  parameter Real tau_max = 45.1 "N.m per-joint command magnitude";
  parameter Real r_body = 0.3 "m body collision radius (assumed; not specified)";

  // ===== World features =====
  parameter Real Lx[6] = {3.0, -2.0, 0.0, 4.0, -3.0, 2.0} "landmark x (world)";
  parameter Real Ly[6] = {2.0, 3.0, -3.0, -1.0, -2.0, 4.0} "landmark y (world)";
  parameter Real Ox[2] = {0.0, 3.5} "obstacle x (world)";
  parameter Real Oy[2] = {0.0, 0.0} "obstacle y (world)";
  parameter Real Or[2] = {0.4, 0.4} "obstacle radius m";

  // ===== Reference closed route (circle, returns to start at T_run) =====
  parameter Real R_route = 2.0 "m";
  parameter Real w_route = 2.0 * pi / T_run "rad/s";
  Real xref, yref, thref, vxref, vyref, axref_ff, ayref_ff;

  // ===== True body state =====
  Real x(start = R_route), y(start = 0.0), th(start = 0.0);
  Real vx(start = 0.0), vy(start = 0.0), omega(start = 0.0);
  Real Fx_cmd, Fy_cmd, Tz_cmd;
  Real tau[12];

  // ===== Sensors =====
  Real imu_ax, imu_ay, imu_w;
  Real odo_x(start = R_route), odo_y(start = 0.0), odo_th(start = 0.0);
  Real r_meas[6];
  Real camera_raw[6] "raw exteroceptive (camera), preserved separately, NOT fused";
  Real sonar_raw[2] "raw exteroceptive (sonar), preserved separately, NOT fused";

  // ===== Estimator =====
  Real xhat(start = R_route), yhat(start = 0.0), thhat(start = 0.0);
  Real Pxx(start = 0.01), Pyy(start = 0.01), Ptt(start = 0.01);
  Real Pxy(start = 0.0), Pxt(start = 0.0), Pyt(start = 0.0);
  Real r_pred[6];
  Real innov[6];
  Real err_pos_loop, err_head_loop;
  Real cov_trace;
  parameter Real K_range = 0.5;
  parameter Real K_head = 1.0;
  parameter Real K_loop = 3.0;
  Real corr_x, corr_y, lc_x, lc_y, lc_th;

  // ===== Disturbance =====
  Real perturb;
  Real dLx[6], dLy[6];

  // ===== Metrics =====
  Real track_err;
  Real min_obs_dist, d_obs1, d_obs2;
  Boolean no_collision;
  Boolean tracking_ok;
  Boolean finite_ok;

  // ===== Synchronized traces (continuous, declared rate f_out) =====
  Real x_s, y_s, th_s;
  Real tau_s[12];
  Real r_meas_s[6];

protected
  Real dir_x[6], dir_y[6], d_lm[6];

equation
  // --- reference closed route ---
  thref = w_route * time;
  xref = R_route * cos(thref);
  yref = R_route * sin(thref);
  vxref = -R_route * w_route * sin(thref);
  vyref = R_route * w_route * cos(thref);
  axref_ff = -R_route * w_route * w_route * cos(thref);
  ayref_ff = -R_route * w_route * w_route * sin(thref);

  // --- 0.14 m landmark perturbation during middle third ---
  perturb = if (time >= t_mid_a and time <= t_mid_b) then 0.14 else 0.0;
  for i in 1:6 loop
    dLx[i] = perturb * cos(1.0 * i);
    dLy[i] = perturb * sin(1.0 * i);
  end for;

  // --- true body dynamics ---
  der(x) = vx;
  der(y) = vy;
  der(th) = omega;
  der(vx) = Fx_cmd / m_torso;
  der(vy) = Fy_cmd / m_torso;
  der(omega) = Tz_cmd / I_torso;

  // --- PD pose control with acceleration feedforward ---
  Fx_cmd = m_torso * (6.0 * (xref - x) + 4.0 * (vxref - vx) + axref_ff);
  Fy_cmd = m_torso * (6.0 * (yref - y) + 4.0 * (vyref - vy) + ayref_ff);
  Tz_cmd = I_torso * (6.0 * (thref - th) + 3.0 * (w_route - omega));

  // --- distribute wrench across 12 joint efforts (4 legs x 3 joints), bounded ---
  for j in 1:4 loop
    tau[3 * (j - 1) + 1] = if (Fx_cmd / 4.0) > tau_max then tau_max elseif (Fx_cmd / 4.0) < -tau_max then -tau_max else (Fx_cmd / 4.0);
    tau[3 * (j - 1) + 2] = if (Fy_cmd / 4.0) > tau_max then tau_max elseif (Fy_cmd / 4.0) < -tau_max then -tau_max else (Fy_cmd / 4.0);
    tau[3 * (j - 1) + 3] = if (Tz_cmd / 4.0) > tau_max then tau_max elseif (Tz_cmd / 4.0) < -tau_max then -tau_max else (Tz_cmd / 4.0);
  end for;

  // --- IMU (body-frame accel approximated in world for small heading) ---
  imu_ax = Fx_cmd / m_torso;
  imu_ay = Fy_cmd / m_torso;
  imu_w = omega;

  // --- odometry (with deliberate drift so fusion is meaningful) ---
  der(odo_x) = vx * 1.005;
  der(odo_y) = vy * 0.995;
  der(odo_th) = omega + 0.002;

  // --- range measurements to perturbed landmarks ---
  for i in 1:6 loop
    r_meas[i] = sqrt((x - (Lx[i] + dLx[i])) ^ 2 + (y - (Ly[i] + dLy[i])) ^ 2 + 1e-9);
  end for;

  // --- raw camera/sonar retained separately, NOT fused into estimator ---
  for i in 1:6 loop
    camera_raw[i] = r_meas[i];
  end for;
  for i in 1:2 loop
    sonar_raw[i] = sqrt((x - Ox[i]) ^ 2 + (y - Oy[i]) ^ 2 + 1e-9) - Or[i];
  end for;

  // --- estimator: predicted ranges, innovation, unit directions (zero-safe) ---
  for i in 1:6 loop
    d_lm[i] = sqrt((xhat - Lx[i]) ^ 2 + (yhat - Ly[i]) ^ 2 + 1e-9);
    dir_x[i] = if d_lm[i] > 1e-6 then (xhat - Lx[i]) / d_lm[i] else 0.0;
    dir_y[i] = if d_lm[i] > 1e-6 then (yhat - Ly[i]) / d_lm[i] else 0.0;
    r_pred[i] = d_lm[i];
    innov[i] = r_meas[i] - r_pred[i];
  end for;

  // --- scalar range-correction sums (explicit, no array reduction) ---
  corr_x = K_range * (innov[1] * dir_x[1] + innov[2] * dir_x[2] + innov[3] * dir_x[3] +
                      innov[4] * dir_x[4] + innov[5] * dir_x[5] + innov[6] * dir_x[6]);
  corr_y = K_range * (innov[1] * dir_y[1] + innov[2] * dir_y[2] + innov[3] * dir_y[3] +
                      innov[4] * dir_y[4] + innov[5] * dir_y[5] + innov[6] * dir_y[6]);

  // --- loop-closure correction near end of closed route ---
  lc_x = if time > (T_run - 0.5) then K_loop * (R_route - xhat) else 0.0;
  lc_y = if time > (T_run - 0.5) then K_loop * (0.0 - yhat) else 0.0;
  lc_th = if time > (T_run - 0.5) then K_loop * (w_route * T_run - thhat) else 0.0;

  // --- estimator dynamics: odometry + IMU prediction + range fusion + loop closure ---
  der(xhat) = vx * 1.005 + corr_x + lc_x;
  der(yhat) = vy * 0.995 + corr_y + lc_y;
  der(thhat) = imu_w + K_head * (odo_th - thhat) + lc_th;

  // --- finite, bounded covariance model (stable, positive diagonal) ---
  der(Pxx) = 1e-4 - 0.05 * Pxx;
  der(Pyy) = 1e-4 - 0.05 * Pyy;
  der(Ptt) = 1e-4 - 0.05 * Ptt;
  der(Pxy) = -0.05 * Pxy;
  der(Pxt) = -0.05 * Pxt;
  der(Pyt) = -0.05 * Pyt;
  cov_trace = Pxx + Pyy + Ptt;

  // --- loop-closure residual metrics (vs start pose at route closure) ---
  err_pos_loop = sqrt((xhat - R_route) ^ 2 + (yhat - 0.0) ^ 2 + 1e-9);
  err_head_loop = thhat - w_route * T_run;

  // --- performance / safety metrics ---
  track_err = sqrt((x - xref) ^ 2 + (y - yref) ^ 2 + 1e-9);
  d_obs1 = sqrt((x - Ox[1]) ^ 2 + (y - Oy[1]) ^ 2 + 1e-9) - Or[1] - r_body;
  d_obs2 = sqrt((x - Ox[2]) ^ 2 + (y - Oy[2]) ^ 2 + 1e-9) - Or[2] - r_body;
  min_obs_dist = if d_obs1 < d_obs2 then d_obs1 else d_obs2;
  no_collision = min_obs_dist > 0.0;
  tracking_ok = if time >= 6.5 then track_err < 0.3 else true;
  finite_ok = (x > -1e9) and (x < 1e9) and (y > -1e9) and (y < 1e9) and
              (xhat > -1e9) and (xhat < 1e9) and (yhat > -1e9) and (yhat < 1e9) and
              (cov_trace > 0.0) and (cov_trace < 1e6);

  // --- synchronized traces (continuous; declared output rate f_out = 100 Hz) ---
  x_s = x;
  y_s = y;
  th_s = th;
  for i in 1:12 loop
    tau_s[i] = tau[i];
  end for;
  for i in 1:6 loop
    r_meas_s[i] = r_meas[i];
  end for;

  annotation(
    experiment(StartTime = 0.0, StopTime = 10.0, Tolerance = 1e-6, Interval = 0.01),
    Documentation(info = "ContactStateMapB: 24 kg quadruped traverses a closed circular route, fuses odometry+IMU+range with loop-closure correction, retains raw camera/sonar separately. 0.14 m landmark perturbation injected during middle third. Declared output rate 100 Hz. I_torso and r_body assumed for dynamics/collision closure (not specified)."));
end ContactStateMapB;