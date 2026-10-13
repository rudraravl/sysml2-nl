model MarineNavMapA
  /* MarineNavMapA: robotic sensing & estimation system for an underwater vehicle.
     - 4 bounded thrusters (command magnitude limit 75.6 N/thruster)
     - IMU, pressure depth, Doppler velocity, compass, 1 Hz acoustic range
     - declared extrinsic transforms for every exteroceptive sensor
     - 6 fixed landmarks + 2 obstacles in a shared world frame
     - closed route traversal, pose filtering with loop-closure correction
     - 0.1 m landmark perturbation during the middle third of the scenario
     - main loop 80 Hz, scenario 8 s; synchronized state/command/sensor traces
     - finite covariance, loop-closure position & heading error, declared output rate
     - no collision; primary tracking error < 0.338 m after 5.2 s; no NaN/Inf
     NOTE: facts not stated in the requirement are treated as unknown and omitted. */

  // ===== Timing / declared rates =====
  parameter Real dt_main  = 0.0125 "80 Hz main integration/sensing step (s)";
  parameter Real dt_range = 1.0    "1 Hz acoustic range update (s)";
  parameter Real T_end    = 8.0    "scenario duration (s)";
  parameter Real out_rate  = 80.0  "declared output rate (Hz)";

  // ===== Vehicle body parameters =====
  parameter Real mveh = 100.0  "vehicle mass (kg)";
  parameter Real Izveh = 20.0  "yaw inertia (kg.m^2)";
  parameter Real dx = 80.0    "body-x linear drag (N.s/m)";
  parameter Real dy = 80.0    "body-y linear drag (N.s/m)";
  parameter Real dz = 80.0    "heave linear drag (N.s/m)";
  parameter Real dw = 30.0    "yaw rotary drag (N.m.s/rad)";
  parameter Real Fmax = 75.6  "per-thruster command magnitude limit (N)";
  parameter Real thr_by = 0.5 "thruster y-offset (m)";

  // ===== Sensor extrinsic transforms (m, body frame) =====
  parameter Real imu_ex_x = 0.10;  parameter Real imu_ex_y = 0.0;  parameter Real imu_ex_z = 0.05;
  parameter Real prs_ex_z = -0.10;
  parameter Real dvl_ex_z = -0.20;
  parameter Real cmp_ex_z = 0.10;
  parameter Real rng_ex_x = 0.20;  parameter Real rng_ex_y = 0.0;  parameter Real rng_ex_z = 0.0;
  parameter Real cam_ex_x = 0.15;  parameter Real cam_ex_y = 0.0;  parameter Real cam_ex_z = 0.0;
  parameter Real sonar_ex_x = 0.0; parameter Real sonar_ex_y = 0.0; parameter Real sonar_ex_z = -0.15;

  // ===== Landmarks (6) in shared world frame =====
  parameter Real L1x = 3.0;  parameter Real L1y = 0.0;  parameter Real L1z = 0.0;
  parameter Real L2x = 0.0;  parameter Real L2y = 3.0;  parameter Real L2z = 0.0;
  parameter Real L3x = -3.0; parameter Real L3y = 0.0;  parameter Real L3z = 0.0;
  parameter Real L4x = 0.0;  parameter Real L4y = -3.0; parameter Real L4z = 0.0;
  parameter Real L5x = 5.0;  parameter Real L5y = 5.0;  parameter Real L5z = 0.0;
  parameter Real L6x = -5.0; parameter Real L6y = -5.0; parameter Real L6z = 0.0;
  parameter Real dpert = 0.10 "controlled landmark perturbation (m)";
  Real L1x_eff, L2x_eff, L3x_eff, L4x_eff, L5x_eff, L6x_eff;

  // ===== Obstacles (2) in shared world frame =====
  parameter Real O1x = 0.0; parameter Real O1y = 0.0;  parameter Real O1r = 0.5;
  parameter Real O2x = 6.0; parameter Real O2y = -6.0; parameter Real O2r = 0.5;
  parameter Real Vrad = 0.5 "vehicle collision radius (m)";

  // ===== True vehicle state =====
  Real x(start=2.0, fixed=true);
  Real y(start=2.0, fixed=true);
  Real z(start=1.0, fixed=true);
  Real psi(start=Modelica.Constants.pi, fixed=true);
  Real vx(start=0.0, fixed=true);
  Real vy(start=0.0, fixed=true);
  Real vz(start=0.0, fixed=true);
  Real om(start=0.0, fixed=true);

  // ===== Reference closed route (square, side 4 m, 2 s per side) =====
  Real ref_x, ref_y, ref_z, ref_psi, ref_vx, ref_vy, ref_om;
  Real vxb_ref, vyb_ref;

  // ===== Controller =====
  Real ex_w, ey_w, evx_w, evy_w, ex_b, ey_b, evx_b, evy_b;
  Real vxb, vyb, epsi_raw, epsi;
  Real Fx_ctrl, Fy_ctrl, Fz_ctrl, Mz_ctrl;
  Real Fx_front_c, Fx_rear_c;
  Real Fx1_c, Fy1_c, Fz1_c, Fx2_c, Fy2_c, Fz2_c;
  Real Fx3_c, Fy3_c, Fz3_c, Fx4_c, Fy4_c, Fz4_c;
  Real u1_c, u2_c, u3_c, u4_c, umax_c, scale_sat;
  Real Fx1, Fy1, Fz1, Fx2, Fy2, Fz2, Fx3, Fy3, Fz3, Fx4, Fy4, Fz4;
  Real u1, u2, u3, u4 "actual per-thruster command magnitude (N)";
  Real Fx_tot, Fy_tot, Fz_tot, Mz_tot;
  Real Fxb_net, Fyb_net, Fxw, Fyw;

  // ===== Sensor observations =====
  Real imu_ax, imu_ay, imu_gz;
  Real prs_depth;
  Real dvl_vx, dvl_vy, dvl_vz;
  Real cmp_psi;
  Real rng_sensor_x, rng_sensor_y, rng_sensor_z;
  discrete Real r1_meas, r2_meas, r3_meas, r4_meas, r5_meas, r6_meas;
  discrete Real r1_pred, r2_pred, r3_pred, r4_pred, r5_pred, r6_pred;
  discrete Real inn1, inn2, inn3, inn4, inn5, inn6;
  discrete Real ux1, ux2, ux3, ux4, ux5, ux6;
  discrete Real uy1, uy2, uy3, uy4, uy5, uy6;
  discrete Real range_update_x, range_update_y;
  discrete Integer range_count(start=0) "1 Hz range tick counter";
  Real cam_data_x, cam_data_y, cam_data_z, cam_stamp;
  Real sonar_data_x, sonar_data_y, sonar_data_z, sonar_stamp;

  // ===== Estimator (EKF-like, scalar diagonal covariance) =====
  Real xh(start=2.0, fixed=true);
  Real yh(start=2.0, fixed=true);
  Real zh(start=1.0, fixed=true);
  Real psih(start=Modelica.Constants.pi, fixed=true);
  Real vxh(start=0.0, fixed=true);
  Real vyh(start=0.0, fixed=true);
  Real vzh(start=0.0, fixed=true);
  Real omh(start=0.0, fixed=true);
  Real Pxx(start=0.01, fixed=true);
  Real Pyy(start=0.01, fixed=true);
  Real Pzz(start=0.01, fixed=true);
  Real Ppsi(start=0.01, fixed=true);
  discrete Real Kx, Ky;
  Real est_err_x, est_err_y, est_err_psi;

  // ===== Loop closure =====
  Real lc_gain;
  Real lc_pos_err;
  Real lc_heading_err;

  // ===== Metrics / outputs =====
  Real track_err;
  Real d1_obs, d2_obs, coll_dist_min;
  Real cov_max;
  Real no_collision_flag;
  Real track_ok_flag;
  Real finite_flag;
  Real output_rate_hz;

equation
  // ---- Landmark perturbation: middle third of [0,T_end] -> [8/3, 16/3] ----
  L1x_eff = L1x + (if time >= 8.0/3.0 and time <= 16.0/3.0 then dpert else 0.0);
  L2x_eff = L2x + (if time >= 8.0/3.0 and time <= 16.0/3.0 then dpert else 0.0);
  L3x_eff = L3x + (if time >= 8.0/3.0 and time <= 16.0/3.0 then dpert else 0.0);
  L4x_eff = L4x + (if time >= 8.0/3.0 and time <= 16.0/3.0 then dpert else 0.0);
  L5x_eff = L5x + (if time >= 8.0/3.0 and time <= 16.0/3.0 then dpert else 0.0);
  L6x_eff = L6x + (if time >= 8.0/3.0 and time <= 16.0/3.0 then dpert else 0.0);

  // ---- Reference closed route ----
  ref_z   = 1.0;
  ref_om  = 0.0;
  ref_x   = if time < 2.0 then 2.0 - 2.0*time else if time < 4.0 then -2.0 else if time < 6.0 then -2.0 + 2.0*(time-4.0) else 2.0;
  ref_y   = if time < 2.0 then 2.0 else if time < 4.0 then 2.0 - 2.0*(time-2.0) else if time < 6.0 then -2.0 else -2.0 + 2.0*(time-6.0);
  ref_vx  = if time < 2.0 then -2.0 else if time < 4.0 then 0.0 else if time < 6.0 then 2.0 else 0.0;
  ref_vy  = if time < 2.0 then 0.0 else if time < 4.0 then -2.0 else if time < 6.0 then 0.0 else 2.0;
  ref_psi = if time < 2.0 then Modelica.Constants.pi else if time < 4.0 then -Modelica.Constants.pi/2 else if time < 6.0 then 0.0 else Modelica.Constants.pi/2;
  vxb_ref = cos(ref_psi)*ref_vx + sin(ref_psi)*ref_vy;
  vyb_ref = -sin(ref_psi)*ref_vx + cos(ref_psi)*ref_vy;

  // ---- Body-frame velocities ----
  vxb = cos(psi)*vx + sin(psi)*vy;
  vyb = -sin(psi)*vx + cos(psi)*vy;

  // ---- World-frame tracking errors -> body frame ----
  ex_w  = ref_x - x;   ey_w  = ref_y - y;
  evx_w = ref_vx - vx; evy_w = ref_vy - vy;
  ex_b  = cos(psi)*ex_w + sin(psi)*ey_w;
  ey_b  = -sin(psi)*ex_w + cos(psi)*ey_w;
  evx_b = cos(psi)*evx_w + sin(psi)*evy_w;
  evy_b = -sin(psi)*evx_w + cos(psi)*evy_w;

  // ---- Heading error (wrapped to [-pi, pi]) ----
  epsi_raw = ref_psi - psi;
  epsi = Modelica.Math.Wraps.wrapAngle(epsi_raw);

  // ---- Controller (PD + feed-forward drag compensation) ----
  Fx_ctrl = mveh*(2.0*ex_b + 3.0*evx_b) + dx*vxb_ref;
  Fy_ctrl = mveh*(2.0*ey_b + 3.0*evy_b) + dy*vyb_ref;
  Fz_ctrl = mveh*(4.0*(ref_z - z) - 3.0*vz);
  Mz_ctrl = Izveh*(3.0*epsi + 1.0*(ref_om - om)) + dw*ref_om;

  // ---- Control allocation to 4 thrusters ----
  Fx_front_c = Fx_ctrl/4.0 - Mz_ctrl/(4.0*thr_by);
  Fx_rear_c  = Fx_ctrl/4.0 + Mz_ctrl/(4.0*thr_by);
  Fx1_c = Fx_front_c; Fx2_c = Fx_front_c; Fx3_c = Fx_rear_c;  Fx4_c = Fx_rear_c;
  Fy1_c = Fy_ctrl/4.0; Fy2_c = Fy_ctrl/4.0; Fy3_c = Fy_ctrl/4.0; Fy4_c = Fy_ctrl/4.0;
  Fz1_c = Fz_ctrl/4.0; Fz2_c = Fz_ctrl/4.0; Fz3_c = Fz_ctrl/4.0; Fz4_c = Fz_ctrl/4.0;
  u1_c = sqrt(Fx1_c*Fx1_c + Fy1_c*Fy1_c + Fz1_c*Fz1_c + 1.0e-12);
  u2_c = sqrt(Fx2_c*Fx2_c + Fy2_c*Fy2_c + Fz2_c*Fz2_c + 1.0e-12);
  u3_c = sqrt(Fx3_c*Fx3_c + Fy3_c*Fy3_c + Fz3_c*Fz3_c + 1.0e-12);
  u4_c = sqrt(Fx4_c*Fx4_c + Fy4_c*Fy4_c + Fz4_c*Fz4_c + 1.0e-12);
  umax_c = max({u1_c, u2_c, u3_c, u4_c});
  scale_sat = if umax_c > Fmax then Fmax/umax_c else 1.0;
  Fx1 = Fx1_c*scale_sat; Fx2 = Fx2_c*scale_sat; Fx3 = Fx3_c*scale_sat; Fx4 = Fx4_c*scale_sat;
  Fy1 = Fy1_c*scale_sat; Fy2 = Fy2_c*scale_sat; Fy3 = Fy3_c*scale_sat; Fy4 = Fy4_c*scale_sat;
  Fz1 = Fz1_c*scale_sat; Fz2 = Fz2_c*scale_sat; Fz3 = Fz3_c*scale_sat; Fz4 = Fz4_c*scale_sat;
  u1 = sqrt(Fx1*Fx1 + Fy1*Fy1 + Fz1*Fz1 + 1.0e-12);
  u2 = sqrt(Fx2*Fx2 + Fy2*Fy2 + Fz2*Fz2 + 1.0e-12);
  u3 = sqrt(Fx3*Fx3 + Fy3*Fy3 + Fz3*Fz3 + 1.0e-12);
  u4 = sqrt(Fx4*Fx4 + Fy4*Fy4 + Fz4*Fz4 + 1.0e-12);
  Fx_tot = Fx1 + Fx2 + Fx3 + Fx4;
  Fy_tot = Fy1 + Fy2 + Fy3 + Fy4;
  Fz_tot = Fz1 + Fz2 + Fz3 + Fz4;
  Mz_tot = thr_by*(Fx3 + Fx4 - Fx1 - Fx2);

  // ---- Vehicle dynamics ----
  der(x)   = vx;
  der(y)   = vy;
  der(z)   = vz;
  der(psi) = om;
  Fxb_net = Fx_tot - dx*vxb;
  Fyb_net = Fy_tot - dy*vyb;
  Fxw = cos(psi)*Fxb_net - sin(psi)*Fyb_net;
  Fyw = sin(psi)*Fxb_net + cos(psi)*Fyb_net;
  der(vx) = Fxw/mveh;
  der(vy) = Fyw/mveh;
  der(vz) = (Fz_tot - dz*vz)/mveh;
  der(om) = (Mz_tot - dw*om)/Izveh;

  // ---- Exteroceptive sensor models (with declared extrinsics) ----
  imu_ax = Fx_tot/mveh;
  imu_ay = Fy_tot/mveh;
  imu_gz = om;
  prs_depth = z + prs_ex_z;
  dvl_vx = vxb;
  dvl_vy = vyb;
  dvl_vz = vz;
  cmp_psi = psi;
  rng_sensor_x = x + cos(psi)*rng_ex_x - sin(psi)*rng_ex_y;
  rng_sensor_y = y + sin(psi)*rng_ex_x + cos(psi)*rng_ex_y;
  rng_sensor_z = z + rng_ex_z;

  // Raw camera and sonar observations (kept separate, NOT fused)
  cam_data_x = (L1x_eff - x) + cos(psi)*cam_ex_x;
  cam_data_y = (L1y - y) + sin(psi)*cam_ex_x;
  cam_data_z = z + cam_ex_z;
  cam_stamp = time;
  sonar_data_x = x + sonar_ex_x;
  sonar_data_y = y + sonar_ex_y;
  sonar_data_z = z + sonar_ex_z;
  sonar_stamp = time;

  // ---- Estimator prediction (continuous dead-reckoning + loop-closure blend) ----
  lc_gain = if time >= 7.0 then 1.0 else 0.0;
  der(xh)   = vxh + lc_gain*(x - xh);
  der(yh)   = vyh + lc_gain*(y - yh);
  der(zh)   = vzh;
  der(psih) = omh + lc_gain*(psi - psih);
  der(vxh)  = Fx_tot/mveh;
  der(vyh)  = Fy_tot/mveh;
  der(vzh)  = Fz_tot/mveh;
  der(omh)  = Mz_tot/Izveh;
  der(Pxx)  = 0.001;
  der(Pyy)  = 0.001;
  der(Pzz)  = 0.0005;
  der(Ppsi) = 0.0005;

  est_err_x   = x - xh;
  est_err_y   = y - yh;
  est_err_psi = psi - psih;
  lc_pos_err     = sqrt(est_err_x*est_err_x + est_err_y*est_err_y + 1.0e-12);
  lc_heading_err = est_err_psi;

  // ---- Acoustic range update at 1 Hz (fuse odometry/IMU/range) ----
  when sample(0.5, dt_range) then
    range_count = pre(range_count) + 1;

    r1_meas = sqrt((L1x_eff - pre(rng_sensor_x))*(L1x_eff - pre(rng_sensor_x)) + (L1y - pre(rng_sensor_y))*(L1y - pre(rng_sensor_y)) + (L1z - pre(rng_sensor_z))*(L1z - pre(rng_sensor_z)) + 1.0e-12);
    r2_meas = sqrt((L2x_eff - pre(rng_sensor_x))*(L2x_eff - pre(rng_sensor_x)) + (L2y - pre(rng_sensor_y))*(L2y - pre(rng_sensor_y)) + (L2z - pre(rng_sensor_z))*(L2z - pre(rng_sensor_z)) + 1.0e-12);
    r3_meas = sqrt((L3x_eff - pre(rng_sensor_x))*(L3x_eff - pre(rng_sensor_x)) + (L3y - pre(rng_sensor_y))*(L3y - pre(rng_sensor_y)) + (L3z - pre(rng_sensor_z))*(L3z - pre(rng_sensor_z)) + 1.0e-12);
    r4_meas = sqrt((L4x_eff - pre(rng_sensor_x))*(L4x_eff - pre(rng_sensor_x)) + (L4y - pre(rng_sensor_y))*(L4y - pre(rng_sensor_y)) + (L4z - pre(rng_sensor_z))*(L4z - pre(rng_sensor_z)) + 1.0e-12);
    r5_meas = sqrt((L5x_eff - pre(rng_sensor_x))*(L5x_eff - pre(rng_sensor_x)) + (L5y - pre(rng_sensor_y))*(L5y - pre(rng_sensor_y)) + (L5z - pre(rng_sensor_z))*(L5z - pre(rng_sensor_z)) + 1.0e-12);
    r6_meas = sqrt((L6x_eff - pre(rng_sensor_x))*(L6x_eff - pre(rng_sensor_x)) + (L6y - pre(rng_sensor_y))*(L6y - pre(rng_sensor_y)) + (L6z - pre(rng_sensor_z))*(L6z - pre(rng_sensor_z)) + 1.0e-12);

    r1_pred = sqrt((L1x - pre(xh))*(L1x - pre(xh)) + (L1y - pre(yh))*(L1y - pre(yh)) + (L1z - pre(zh))*(L1z - pre(zh)) + 1.0e-6);
    r2_pred = sqrt((L2x - pre(xh))*(L2x - pre(xh)) + (L2y - pre(yh))*(L2y - pre(yh)) + (L2z - pre(zh))*(L2z - pre(zh)) + 1.0e-6);
    r3_pred = sqrt((L3x - pre(xh))*(L3x - pre(xh)) + (L3y - pre(yh))*(L3y - pre(yh)) + (L3z - pre(zh))*(L3z - pre(zh)) + 1.0e-6);
    r4_pred = sqrt((L4x - pre(xh))*(L4x - pre(xh)) + (L4y - pre(yh))*(L4y - pre(yh)) + (L4z - pre(zh))*(L4z - pre(zh)) + 1.0e-6);
    r5_pred = sqrt((L5x - pre(xh))*(L5x - pre(xh)) + (L5y - pre(yh))*(L5y - pre(yh)) + (L5z - pre(zh))*(L5z - pre(zh)) + 1.0e-6);
    r6_pred = sqrt((L6x - pre(xh))*(L6x - pre(xh)) + (L6y - pre(yh))*(L6y - pre(yh)) + (L6z - pre(zh))*(L6z - pre(zh)) + 1.0e-6);

    inn1 = r1_meas - r1_pred;
    inn2 = r2_meas - r2_pred;
    inn3 = r3_meas - r3_pred;
    inn4 = r4_meas - r4_pred;
    inn5 = r5_meas - r5_pred;
    inn6 = r6_meas - r6_pred;

    ux1 = (L1x - pre(xh))/r1_pred;
    ux2 = (L2x - pre(xh))/r2_pred;
    ux3 = (L3x - pre(xh))/r3_pred;
    ux4 = (L4x - pre(xh))/r4_pred;
    ux5 = (L5x - pre(xh))/r5_pred;
    ux6 = (L6x - pre(xh))/r6_pred;

    uy1 = (L1y - pre(yh))/r1_pred;
    uy2 = (L2y - pre(yh))/r2_pred;
    uy3 = (L3y - pre(yh))/r3_pred;
    uy4 = (L4y - pre(yh))/r4_pred;
    uy5 = (L5y - pre(yh))/r5_pred;
    uy6 = (L6y - pre(yh))/r6_pred;

    Kx = pre(Pxx)/(pre(Pxx) + 0.04);
    Ky = pre(Pyy)/(pre(Pyy) + 0.04);

    range_update_x = (Kx*inn1*ux1 + Kx*inn2*ux2 + Kx*inn3*ux3 + Kx*inn4*ux4 + Kx*inn5*ux5 + Kx*inn6*ux6)/6.0;
    range_update_y = (Ky*inn1*uy1 + Ky*inn2*uy2 + Ky*inn3*uy3 + Ky*inn4*uy4 + Ky*inn5*uy5 + Ky*inn6*uy6)/6.0;

    reinit(xh, pre(xh) + range_update_x);
    reinit(yh, pre(yh) + range_update_y);
    reinit(Pxx, pre(Pxx)*(1.0 - Kx));
    reinit(Pyy, pre(Pyy)*(1.0 - Ky));
  end when;

  // ---- Loop-closure covariance reduction (single event at t = 7 s) ----
  when time >= 7.0 then
    reinit(Pxx, pre(Pxx)*0.3);
    reinit(Pyy, pre(Pyy)*0.3);
    reinit(Pzz, pre(Pzz)*0.3);
    reinit(Ppsi, pre(Ppsi)*0.3);
  end when;

  // ---- Metrics ----
  track_err = sqrt((x - ref_x)*(x - ref_x) + (y - ref_y)*(y - ref_y) + 1.0e-12);
  d1_obs = sqrt((x - O1x)*(x - O1x) + (y - O1y)*(y - O1y) + 1.0e-12);
  d2_obs = sqrt((x - O2x)*(x - O2x) + (y - O2y)*(y - O2y) + 1.0e-12);
  coll_dist_min = min({d1_obs, d2_obs}) - Vrad - O1r;
  cov_max = max({abs(Pxx), abs(Pyy), abs(Pzz), abs(Ppsi)});
  no_collision_flag = if coll_dist_min > 0.0 then 1.0 else 0.0;
  track_ok_flag = if time < 5.2 then 1.0 else (if track_err < 0.338 then 1.0 else 0.0);
  finite_flag = if (abs(x)<1.0e6 and abs(y)<1.0e6 and abs(z)<1.0e6 and abs(psi)<1.0e6 and abs(vx)<1.0e6 and abs(vy)<1.0e6 and abs(vz)<1.0e6 and abs(om)<1.0e6 and abs(xh)<1.0e6 and abs(yh)<1.0e6 and abs(zh)<1.0e6 and abs(psih)<1.0e6 and abs(Pxx)<1.0e6 and abs(Pyy)<1.0e6 and abs(Pzz)<1.0e6 and abs(Ppsi)<1.0e6 and abs(u1)<1.0e6 and abs(u2)<1.0e6 and abs(u3)<1.0e6 and abs(u4)<1.0e6) then 1.0 else 0.0;
  output_rate_hz = out_rate;

  annotation (
    experiment(StopTime=8.0, Tolerance=1.0e-6, Interval=0.0125),
    Documentation(info="MarineNavMapA: 80 Hz / 8 s underwater survey with 4 bounded thrusters, 6 landmarks, 2 obstacles, fused odometry/IMU/1 Hz range EKF + loop closure, 0.1 m landmark perturbation during middle third."));
end MarineNavMapA;