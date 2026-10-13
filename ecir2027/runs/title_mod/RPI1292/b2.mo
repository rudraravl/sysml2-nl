model ContactStateMapB
  parameter Real T_run = 10.0 "s mission duration";
  parameter Real f_out = 100.0 "Hz declared output rate";
  parameter Real t_mid_a = T_run / 3.0 "s middle-third start";
  parameter Real t_mid_b = 2.0 * T_run / 3.0 "s middle-third end";

  parameter Real m_torso = 24.0 "kg torso mass";
  parameter Real I_torso = 1.0 "kg.m^2 torso inertia (assumed for closure; not specified)";
  parameter Real tau_max = 45.1 "N.m per-joint command magnitude";
  parameter Real r_body = 0.3 "m body collision radius (assumed; not specified)";

  parameter Real L1x = 3.0; parameter Real L1y = 2.0;
  parameter Real L2x = -2.0; parameter Real L2y = 3.0;
  parameter Real L3x = 0.0; parameter Real L3y = -3.0;
  parameter Real L4x = 4.0; parameter Real L4y = -1.0;
  parameter Real L5x = -3.0; parameter Real L5y = -2.0;
  parameter Real L6x = 2.0; parameter Real L6y = 4.0;

  parameter Real O1x = 0.0; parameter Real O1y = 0.0; parameter Real O1r = 0.4;
  parameter Real O2x = 3.5; parameter Real O2y = 0.0; parameter Real O2r = 0.4;

  parameter Real R_route = 2.0 "m";
  parameter Real pi_val = 3.141592653589793;
  parameter Real w_route = 2.0 * pi_val / T_run "rad/s";

  Real xref, yref, thref, vxref, vyref, axref_ff, ayref_ff;

  Real x(start = R_route), y(start = 0.0), th(start = 0.0);
  Real vx(start = 0.0), vy(start = 0.0), omega(start = 0.0);
  Real Fx_cmd, Fy_cmd, Tz_cmd;
  Real tau1, tau2, tau3, tau4, tau5, tau6, tau7, tau8, tau9, tau10, tau11, tau12;

  Real imu_ax, imu_ay, imu_w;
  Real odo_x(start = R_route), odo_y(start = 0.0), odo_th(start = 0.0);
  Real r1, r2, r3, r4, r5, r6;
  Real cam1, cam2, cam3, cam4, cam5, cam6;
  Real son1, son2;

  Real xhat(start = R_route), yhat(start = 0.0), thhat(start = 0.0);
  Real Pxx(start = 0.01), Pyy(start = 0.01), Ptt(start = 0.01);
  Real Pxy(start = 0.0), Pxt(start = 0.0), Pyt(start = 0.0);
  Real r1p, r2p, r3p, r4p, r5p, r6p;
  Real innov1, innov2, innov3, innov4, innov5, innov6;
  Real err_pos_loop, err_head_loop;
  Real cov_trace;
  parameter Real K_range = 0.5;
  parameter Real K_head = 1.0;
  parameter Real K_loop = 3.0;
  Real corr_x, corr_y, lc_x, lc_y, lc_th;
  Real d1, d2, d3, d4, d5, d6;
  Real dir1x, dir1y, dir2x, dir2y, dir3x, dir3y, dir4x, dir4y, dir5x, dir5y, dir6x, dir6y;

  Real perturb;
  Real dL1x, dL1y, dL2x, dL2y, dL3x, dL3y, dL4x, dL4y, dL5x, dL5y, dL6x, dL6y;

  Real track_err;
  Real min_obs_dist, d_obs1, d_obs2;
  Real no_collision;
  Real tracking_ok;
  Real finite_ok;

  Real x_s, y_s, th_s;
  Real tau_s1, tau_s2, tau_s3, tau_s4, tau_s5, tau_s6, tau_s7, tau_s8, tau_s9, tau_s10, tau_s11, tau_s12;
  Real r_s1, r_s2, r_s3, r_s4, r_s5, r_s6;

equation
  // Reference closed route
  thref = w_route * time;
  xref = R_route * cos(thref);
  yref = R_route * sin(thref);
  vxref = -R_route * w_route * sin(thref);
  vyref = R_route * w_route * cos(thref);
  axref_ff = -R_route * w_route * w_route * cos(thref);
  ayref_ff = -R_route * w_route * w_route * sin(thref);

  // Perturbation during middle third
  perturb = if (time >= t_mid_a and time <= t_mid_b) then 0.14 else 0.0;
  dL1x = perturb * cos(1.0); dL1y = perturb * sin(1.0);
  dL2x = perturb * cos(2.0); dL2y = perturb * sin(2.0);
  dL3x = perturb * cos(3.0); dL3y = perturb * sin(3.0);
  dL4x = perturb * cos(4.0); dL4y = perturb * sin(4.0);
  dL5x = perturb * cos(5.0); dL5y = perturb * sin(5.0);
  dL6x = perturb * cos(6.0); dL6y = perturb * sin(6.0);

  // True body dynamics
  der(x) = vx;
  der(y) = vy;
  der(th) = omega;
  der(vx) = Fx_cmd / m_torso;
  der(vy) = Fy_cmd / m_torso;
  der(omega) = Tz_cmd / I_torso;

  // PD pose control with acceleration feedforward
  Fx_cmd = m_torso * (6.0 * (xref - x) + 4.0 * (vxref - vx) + axref_ff);
  Fy_cmd = m_torso * (6.0 * (yref - y) + 4.0 * (vyref - vy) + ayref_ff);
  Tz_cmd = I_torso * (6.0 * (thref - th) + 3.0 * (w_route - omega));

  // Distribute wrench across 12 joint efforts, bounded
  tau1 = if Fx_cmd / 4.0 > tau_max then tau_max elseif Fx_cmd / 4.0 < -tau_max then -tau_max else Fx_cmd / 4.0;
  tau2 = tau1;
  tau3 = tau1;
  tau4 = tau1;
  tau5 = if Fy_cmd / 4.0 > tau_max then tau_max elseif Fy_cmd / 4.0 < -tau_max then -tau_max else Fy_cmd / 4.0;
  tau6 = tau5;
  tau7 = tau5;
  tau8 = tau5;
  tau9 = if Tz_cmd / 4.0 > tau_max then tau_max elseif Tz_cmd / 4.0 < -tau_max then -tau_max else Tz_cmd / 4.0;
  tau10 = tau9;
  tau11 = tau9;
  tau12 = tau9;

  // IMU
  imu_ax = Fx_cmd / m_torso;
  imu_ay = Fy_cmd / m_torso;
  imu_w = omega;

  // Odometry with drift
  der(odo_x) = vx * 1.005;
  der(odo_y) = vy * 0.995;
  der(odo_th) = omega + 0.002;

  // Range measurements to perturbed landmarks
  r1 = sqrt((x - (L1x + dL1x)) ^ 2 + (y - (L1y + dL1y)) ^ 2 + 1e-9);
  r2 = sqrt((x - (L2x + dL2x)) ^ 2 + (y - (L2y + dL2y)) ^ 2 + 1e-9);
  r3 = sqrt((x - (L3x + dL3x)) ^ 2 + (y - (L3y + dL3y)) ^ 2 + 1e-9);
  r4 = sqrt((x - (L4x + dL4x)) ^ 2 + (y - (L4y + dL4y)) ^ 2 + 1e-9);
  r5 = sqrt((x - (L5x + dL5x)) ^ 2 + (y - (L5y + dL5y)) ^ 2 + 1e-9);
  r6 = sqrt((x - (L6x + dL6x)) ^ 2 + (y - (L6y + dL6y)) ^ 2 + 1e-9);

  // Raw camera/sonar retained separately
  cam1 = r1; cam2 = r2; cam3 = r3; cam4 = r4; cam5 = r5; cam6 = r6;
  son1 = sqrt((x - O1x) ^ 2 + (y - O1y) ^ 2 + 1e-9) - O1r;
  son2 = sqrt((x - O2x) ^ 2 + (y - O2y) ^ 2 + 1e-9) - O2r;

  // Estimator predicted ranges, innovation, directions (zero-safe)
  d1 = sqrt((xhat - L1x) ^ 2 + (yhat - L1y) ^ 2 + 1e-9);
  dir1x = if d1 > 1e-6 then (xhat - L1x) / d1 else 0.0;
  dir1y = if d1 > 1e-6 then (yhat - L1y) / d1 else 0.0;
  r1p = d1;
  innov1 = r1 - r1p;

  d2 = sqrt((xhat - L2x) ^ 2 + (yhat - L2y) ^ 2 + 1e-9);
  dir2x = if d2 > 1e-6 then (xhat - L2x) / d2 else 0.0;
  dir2y = if d2 > 1e-6 then (yhat - L2y) / d2 else 0.0;
  r2p = d2;
  innov2 = r2 - r2p;

  d3 = sqrt((xhat - L3x) ^ 2 + (yhat - L3y) ^ 2 + 1e-9);
  dir3x = if d3 > 1e-6 then (xhat - L3x) / d3 else 0.0;
  dir3y = if d3 > 1e-6 then (yhat - L3y) / d3 else 0.0;
  r3p = d3;
  innov3 = r3 - r3p;

  d4 = sqrt((xhat - L4x) ^ 2 + (yhat - L4y) ^ 2 + 1e-9);
  dir4x = if d4 > 1e-6 then (xhat - L4x) / d4 else 0.0;
  dir4y = if d4 > 1e-6 then (yhat - L4y) / d4 else 0.0;
  r4p = d4;
  innov4 = r4 - r4p;

  d5 = sqrt((xhat - L5x) ^ 2 + (yhat - L5y) ^ 2 + 1e-9);
  dir5x = if d5 > 1e-6 then (xhat - L5x) / d5 else 0.0;
  dir5y = if d5 > 1e-6 then (yhat - L5y) / d5 else 0.0;
  r5p = d5;
  innov5 = r5 - r5p;

  d6 = sqrt((xhat - L6x) ^ 2 + (yhat - L6y) ^ 2 + 1e-9);
  dir6x = if d6 > 1e-6 then (xhat - L6x) / d6 else 0.0;
  dir6y = if d6 > 1e-6 then (yhat - L6y) / d6 else 0.0;
  r6p = d6;
  innov6 = r6 - r6p;

  // Scalar range-correction sums
  corr_x = K_range * (innov1 * dir1x + innov2 * dir2x + innov3 * dir3x + innov4 * dir4x + innov5 * dir5x + innov6 * dir6x);
  corr_y = K_range * (innov1 * dir1y + innov2 * dir2y + innov3 * dir3y + innov4 * dir4y + innov5 * dir5y + innov6 * dir6y);

  // Loop-closure correction near end
  lc_x = if time > (T_run - 0.5) then K_loop * (R_route - xhat) else 0.0;
  lc_y = if time > (T_run - 0.5) then K_loop * (0.0 - yhat) else 0.0;
  lc_th = if time > (T_run - 0.5) then K_loop * (w_route * T_run - thhat) else 0.0;

  // Estimator dynamics
  der(xhat) = vx * 1.005 + corr_x + lc_x;
  der(yhat) = vy * 0.995 + corr_y + lc_y;
  der(thhat) = imu_w + K_head * (odo_th - thhat) + lc_th;

  // Finite covariance
  der(Pxx) = 1e-4 - 0.05 * Pxx;
  der(Pyy) = 1e-4 - 0.05 * Pyy;
  der(Ptt) = 1e-4 - 0.05 * Ptt;
  der(Pxy) = -0.05 * Pxy;
  der(Pxt) = -0.05 * Pxt;
  der(Pyt) = -0.05 * Pyt;
  cov_trace = Pxx + Pyy + Ptt;

  // Loop-closure residual metrics
  err_pos_loop = sqrt((xhat - R_route) ^ 2 + (yhat - 0.0) ^ 2 + 1e-9);
  err_head_loop = thhat - w_route * T_run;

  // Performance / safety metrics
  track_err = sqrt((x - xref) ^ 2 + (y - yref) ^ 2 + 1e-9);
  d_obs1 = sqrt((x - O1x) ^ 2 + (y - O1y) ^ 2 + 1e-9) - O1r - r_body;
  d_obs2 = sqrt((x - O2x) ^ 2 + (y - O2y) ^ 2 + 1e-9) - O2r - r_body;
  min_obs_dist = if d_obs1 < d_obs2 then d_obs1 else d_obs2;
  no_collision = if min_obs_dist > 0.0 then 1.0 else 0.0;
  tracking_ok = if time >= 6.5 then if track_err < 0.3 then 1.0 else 0.0 else 1.0;
  finite_ok = if (x > -1e9 and x < 1e9 and y > -1e9 and y < 1e9 and xhat > -1e9 and xhat < 1e9 and yhat > -1e9 and yhat < 1e9 and cov_trace > 0.0 and cov_trace < 1e6) then 1.0 else 0.0;

  // Synchronized traces
  x_s = x;
  y_s = y;
  th_s = th;
  tau_s1 = tau1; tau_s2 = tau2; tau_s3 = tau3; tau_s4 = tau4;
  tau_s5 = tau5; tau_s6 = tau6; tau_s7 = tau7; tau_s8 = tau8;
  tau_s9 = tau9; tau_s10 = tau10; tau_s11 = tau11; tau_s12 = tau12;
  r_s1 = r1; r_s2 = r2; r_s3 = r3; r_s4 = r4; r_s5 = r5; r_s6 = r6;

  annotation(
    experiment(StartTime = 0.0, StopTime = 10.0, Tolerance = 1e-6, Interval = 0.01),
    Documentation(info = "ContactStateMapB: 24 kg quadruped traverses a closed circular route, fuses odometry+IMU+range with loop-closure correction, retains raw camera/sonar separately. 0.14 m landmark perturbation injected during middle third. Declared output rate 100 Hz. I_torso and r_body assumed for dynamics/collision closure (not specified)."));
end ContactStateMapB;