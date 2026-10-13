model MarineNavMapC
  // ============================================================
  // MarineNavMapC
  // Underwater vehicle pose filtering with loop-closure correction.
  // 125 Hz, 12 s, 4 bounded thrusters, 6 landmarks, 2 obstacles.
  // ============================================================

  // --- Simulation ---
  parameter Real fs = 125.0 "Hz estimator/loop rate";
  parameter Real Tend = 12.0 "s total mission time";
  parameter Real output_rate = 125.0 "Hz declared output rate";

  // --- Vehicle ---
  parameter Real m = 100.0 "kg";
  parameter Real d_lin = 50.0 "N s/m";
  parameter Real Iz = 10.0 "kg m^2";
  parameter Real d_yaw = 15.0 "N m s/rad";
  parameter Real L_arm = 0.6 "m thruster moment arm";
  parameter Real Fmax = 96.6 "N max per thruster";

  // --- Extrinsic transforms (declared, m and rad) ---
  parameter Real imu_off_x = 0.15 "m";
  parameter Real imu_off_y = 0.0 "m";
  parameter Real imu_off_yaw = 0.0 "rad";
  parameter Real dvl_off_x = -0.10 "m";
  parameter Real dvl_off_y = 0.05 "m";
  parameter Real dvl_off_yaw = 0.0 "rad";
  parameter Real compass_off_x = 0.0 "m";
  parameter Real compass_off_y = 0.0 "m";
  parameter Real compass_off_yaw = 0.02 "rad";
  parameter Real range_off_x = 0.20 "m";
  parameter Real range_off_y = 0.0 "m";
  parameter Real depth_off_z = 0.05 "m";

  // --- Waypoints (closed route) ---
  parameter Real Wx[5] = {0.0, 4.0, 4.0, 0.0, 0.0};
  parameter Real Wy[5] = {0.0, 0.0, 4.0, 4.0, 0.0};
  parameter Real wp_tol = 0.4 "m";

  // --- Landmarks (6 fixed, shared world frame) ---
  parameter Real Lx[6] = {1.0, 4.0, 4.5, 1.5, 3.5, 2.5};
  parameter Real Ly[6] = {1.0, 1.0, 4.0, 4.0, 2.5, 3.5};

  // --- Obstacles (2) ---
  parameter Real Ox[2] = {1.5, 2.5};
  parameter Real Oy[2] = {1.5, 2.5};
  parameter Real Orad[2] = {0.4, 0.4};

  // --- Disturbance ---
  parameter Real perturbMag = 0.18 "m landmark perturbation";

  // --- Controller gains ---
  parameter Real Kp_pos = 40.0;
  parameter Real Kd_pos = 6.0;
  parameter Real Kp_yaw = 40.0;
  parameter Real Kd_yaw = 5.0;

  // --- Estimator ---
  parameter Real Q_pos = 0.0008 "m^2/s process noise";
  parameter Real R_range = 0.02 "m^2 range noise";
  parameter Real K_range = 0.15 "range update gain";
  parameter Real K_compass = 0.5 "compass fusion gain";

  // --- Vehicle states ---
  Real x(start=0.0) "m";
  Real y(start=0.0) "m";
  Real z "m";
  Real yaw(start=0.0) "rad";
  Real vx(start=0.0) "m/s";
  Real vy(start=0.0) "m/s";
  Real vz "m/s";
  Real vyaw(start=0.0) "rad/s";

  // --- Thrusters (4 bounded) ---
  Real f1 "N", f2 "N", f3 "N", f4 "N";
  Real f1r "N", f2r "N", f3r "N", f4r "N";
  Real Fsurge "N", Myaw "N m";

  // --- Controller ---
  Integer wpI(start=2);
  Real xref "m", yref "m";
  Real des_yaw "rad", yaw_err "rad";
  Real dist2wp "m";
  Real Fsurge_cmd "N", Myaw_cmd "N m";
  Real align "1";

  // --- Disturbance ---
  Boolean perturb_active;
  Real Lx_obs[6], Ly_obs[6];

  // --- Sensors (raw exteroceptive retained) ---
  Real imu_ax "m/s^2", imu_ay "m/s^2", imu_gz "rad/s";
  Real depth_meas "m";
  Real dvx_body "m/s", dvy_body "m/s";
  Real compass_meas "rad";
  Real range_true[6] "m";
  Real range_meas[6] "m";

  // --- Estimator states ---
  Real xhat(start=0.0) "m";
  Real yhat(start=0.0) "m";
  Real yawhat(start=0.0) "rad";
  Real vxhat "m/s", vyhat "m/s";
  Real Pxx(start=0.01) "m^2";
  Real Pyy(start=0.01) "m^2";
  Real Pyaw(start=0.001) "rad^2";

  // --- Estimator intermediates ---
  Real pred_range[6] "m";
  Real res[6] "m";
  Real corr_x "m", corr_y "m";

  // --- Loop closure ---
  Boolean loop_closed(start=false);
  discrete Real loop_pos_err(start=0.0) "m";
  discrete Real loop_yaw_err(start=0.0) "rad";

  // --- Safety / metrics ---
  Real track_err "m";
  Real obs_dist1 "m", obs_dist2 "m";
  Real min_obs_dist "m";
  Boolean no_collision;
  Real cov_pos "m";

equation
  // === Fixed depth ===
  z = 0.5;
  vz = 0.0;

  // === Thruster force mapping ===
  Fsurge = f1 + f2 - f3 - f4;
  Myaw = L_arm*(f1 - f2 + f3 - f4);

  // === Vehicle dynamics (2D horizontal plane) ===
  der(x) = vx;
  der(y) = vy;
  der(yaw) = vyaw;
  m*der(vx) = Fsurge*cos(yaw) - d_lin*vx;
  m*der(vy) = Fsurge*sin(yaw) - d_lin*vy;
  Iz*der(vyaw) = Myaw - d_yaw*vyaw;

  // === Waypoint reference ===
  xref = Wx[wpI];
  yref = Wy[wpI];
  des_yaw = atan2(yref - y, xref - x + 1e-6);
  yaw_err = atan2(sin(des_yaw - yaw), cos(des_yaw - yaw));
  dist2wp = sqrt((xref - x)^2 + (yref - y)^2 + 1e-6);

  // === Heading alignment factor (zero thrust when facing away) ===
  align = if cos(yaw_err) > 0.0 then cos(yaw_err) else 0.0;

  // === Controller commands ===
  Fsurge_cmd = Kp_pos*dist2wp*align - Kd_pos*vx;
  Myaw_cmd = Kp_yaw*yaw_err - Kd_yaw*vyaw;

  // === Thruster allocation ===
  f1r = Fsurge_cmd/4.0 + Myaw_cmd/(4.0*L_arm);
  f2r = Fsurge_cmd/4.0 - Myaw_cmd/(4.0*L_arm);
  f3r = -Fsurge_cmd/4.0 + Myaw_cmd/(4.0*L_arm);
  f4r = -Fsurge_cmd/4.0 - Myaw_cmd/(4.0*L_arm);

  // === Saturation at Fmax ===
  f1 = if f1r > Fmax then Fmax elseif f1r < -Fmax then -Fmax else f1r;
  f2 = if f2r > Fmax then Fmax elseif f2r < -Fmax then -Fmax else f2r;
  f3 = if f3r > Fmax then Fmax elseif f3r < -Fmax then -Fmax else f3r;
  f4 = if f4r > Fmax then Fmax elseif f4r < -Fmax then -Fmax else f4r;

  // === Waypoint advance ===
  when dist2wp < wp_tol then
    wpI = if pre(wpI) < 5 then pre(wpI) + 1 else 5;
  end when;

  // === Disturbance: middle third [4, 8] s ===
  perturb_active = (time >= 4.0) and (time <= 8.0);

  // Perturbed landmark observations (raw data retained separately)
  Lx_obs[1] = Lx[1] + (if perturb_active then perturbMag else 0.0);
  Ly_obs[1] = Ly[1];
  Lx_obs[2] = Lx[2] - (if perturb_active then perturbMag else 0.0);
  Ly_obs[2] = Ly[2];
  Lx_obs[3] = Lx[3];
  Ly_obs[3] = Ly[3] + (if perturb_active then perturbMag else 0.0);
  Lx_obs[4] = Lx[4];
  Ly_obs[4] = Ly[4] - (if perturb_active then perturbMag else 0.0);
  Lx_obs[5] = Lx[5] + (if perturb_active then 0.7071*perturbMag else 0.0);
  Ly_obs[5] = Ly[5] + (if perturb_active then 0.7071*perturbMag else 0.0);
  Lx_obs[6] = Lx[6] - (if perturb_active then 0.7071*perturbMag else 0.0);
  Ly_obs[6] = Ly[6] - (if perturb_active then 0.7071*perturbMag else 0.0);

  // === IMU (body-frame accel + gyro, extrinsic offset declared) ===
  imu_ax = (Fsurge*cos(yaw) - d_lin*vx)/m + 0.01*sin(2.0*time);
  imu_ay = (Fsurge*sin(yaw) - d_lin*vy)/m + 0.01*cos(2.0*time);
  imu_gz = vyaw + 0.005*sin(3.0*time);

  // === Pressure depth sensor ===
  depth_meas = z + depth_off_z + 0.002*sin(5.0*time);

  // === Doppler velocity log (body frame at DVL offset) ===
  dvx_body = vx*cos(yaw) + vy*sin(yaw) + 0.002*sin(1.3*time);
  dvy_body = -vx*sin(yaw) + vy*cos(yaw) + 0.002*cos(1.7*time);

  // === Compass ===
  compass_meas = yaw + compass_off_yaw + 0.003*sin(0.7*time);

  // === Acoustic ranges (true and perturbed-measured) ===
  range_true[1] = sqrt((x - Lx[1])^2 + (y - Ly[1])^2 + 1e-6);
  range_true[2] = sqrt((x - Lx[2])^2 + (y - Ly[2])^2 + 1e-6);
  range_true[3] = sqrt((x - Lx[3])^2 + (y - Ly[3])^2 + 1e-6);
  range_true[4] = sqrt((x - Lx[4])^2 + (y - Ly[4])^2 + 1e-6);
  range_true[5] = sqrt((x - Lx[5])^2 + (y - Ly[5])^2 + 1e-6);
  range_true[6] = sqrt((x - Lx[6])^2 + (y - Ly[6])^2 + 1e-6);

  range_meas[1] = sqrt((x - Lx_obs[1])^2 + (y - Ly_obs[1])^2 + 1e-6) + 0.01*sin(0.5*time);
  range_meas[2] = sqrt((x - Lx_obs[2])^2 + (y - Ly_obs[2])^2 + 1e-6) + 0.01*cos(0.5*time);
  range_meas[3] = sqrt((x - Lx_obs[3])^2 + (y - Ly_obs[3])^2 + 1e-6) + 0.01*sin(0.6*time);
  range_meas[4] = sqrt((x - Lx_obs[4])^2 + (y - Ly_obs[4])^2 + 1e-6) + 0.01*cos(0.6*time);
  range_meas[5] = sqrt((x - Lx_obs[5])^2 + (y - Ly_obs[5])^2 + 1e-6) + 0.01*sin(0.4*time);
  range_meas[6] = sqrt((x - Lx_obs[6])^2 + (y - Ly_obs[6])^2 + 1e-6) + 0.01*cos(0.4*time);

  // === Estimator: prediction via Doppler odometry + gyro/compass ===
  vxhat = dvx_body*cos(yawhat) - dvy_body*sin(yawhat);
  vyhat = dvx_body*sin(yawhat) + dvy_body*cos(yawhat);
  der(xhat) = vxhat;
  der(yhat) = vyhat;
  der(yawhat) = imu_gz + K_compass*(compass_meas - yawhat);
  der(Pxx) = Q_pos;
  der(Pyy) = Q_pos;
  der(Pyaw) = 0.0001;

  // === Estimator: predicted ranges using nominal map ===
  pred_range[1] = sqrt((xhat - Lx[1])^2 + (yhat - Ly[1])^2 + 1e-6);
  pred_range[2] = sqrt((xhat - Lx[2])^2 + (yhat - Ly[2])^2 + 1e-6);
  pred_range[3] = sqrt((xhat - Lx[3])^2 + (yhat - Ly[3])^2 + 1e-6);
  pred_range[4] = sqrt((xhat - Lx[4])^2 + (yhat - Ly[4])^2 + 1e-6);
  pred_range[5] = sqrt((xhat - Lx[5])^2 + (yhat - Ly[5])^2 + 1e-6);
  pred_range[6] = sqrt((xhat - Lx[6])^2 + (yhat - Ly[6])^2 + 1e-6);

  // === Range residuals ===
  res[1] = range_meas[1] - pred_range[1];
  res[2] = range_meas[2] - pred_range[2];
  res[3] = range_meas[3] - pred_range[3];
  res[4] = range_meas[4] - pred_range[4];
  res[5] = range_meas[5] - pred_range[5];
  res[6] = range_meas[6] - pred_range[6];

  // === Gauss-Newton correction (explicit scalar) ===
  corr_x = res[1]*(xhat - Lx[1])/pred_range[1]
         + res[2]*(xhat - Lx[2])/pred_range[2]
         + res[3]*(xhat - Lx[3])/pred_range[3]
         + res[4]*(xhat - Lx[4])/pred_range[4]
         + res[5]*(xhat - Lx[5])/pred_range[5]
         + res[6]*(xhat - Lx[6])/pred_range[6];
  corr_y = res[1]*(yhat - Ly[1])/pred_range[1]
         + res[2]*(yhat - Ly[2])/pred_range[2]
         + res[3]*(yhat - Ly[3])/pred_range[3]
         + res[4]*(yhat - Ly[4])/pred_range[4]
         + res[5]*(yhat - Ly[5])/pred_range[5]
         + res[6]*(yhat - Ly[6])/pred_range[6];

  // === Range updates at 1 Hz ===
  when sample(0.0, 1.0) then
    reinit(xhat, xhat + K_range*corr_x);
    reinit(yhat, yhat + K_range*corr_y);
    reinit(Pxx, R_range);
    reinit(Pyy, R_range);
  end when;

  // === Loop closure: when returning near origin after 9 s ===
  when time > 9.0 and (x*x + y*y) < 0.64 and not pre(loop_closed) then
    loop_closed = true;
    loop_pos_err = sqrt(xhat*xhat + yhat*yhat);
    loop_yaw_err = abs(atan2(sin(yawhat), cos(yawhat)));
    reinit(xhat, 0.0);
    reinit(yhat, 0.0);
    reinit(yawhat, 0.0);
    reinit(Pxx, 0.005);
    reinit(Pyy, 0.005);
  end when;

  // === Tracking error (estimator vs true) ===
  track_err = sqrt((xhat - x)^2 + (yhat - y)^2 + 1e-6);

  // === Covariance norm (finite, guarded) ===
  cov_pos = sqrt(Pxx + Pyy + 1e-12);

  // === Collision check ===
  obs_dist1 = sqrt((x - Ox[1])^2 + (y - Oy[1])^2 + 1e-6);
  obs_dist2 = sqrt((x - Ox[2])^2 + (y - Oy[2])^2 + 1e-6);
  min_obs_dist = if obs_dist1 < obs_dist2 then obs_dist1 - Orad[1] else obs_dist2 - Orad[2];
  no_collision = min_obs_dist > 0.0;

  // --- Simulation stop time: set to Tend = 12.0 s in experiment setup ---

end MarineNavMapC;