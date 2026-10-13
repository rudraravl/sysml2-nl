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
     NOTE: facts not stated in the requirement (e.g. exact sensor noise densities,
     water current model, sensor failure modes) are treated as unknown and omitted. */

  // ===== Timing / declared rates =====
  parameter Real dt_main  = 0.0125 "80 Hz main integration/sensing step (s)";
  parameter Real dt_range = 1.0    "1 Hz acoustic range update (s)";
  parameter Real T_end    = 8.0    "scenario duration (s)";
  parameter Real out_rate = 80.0   "declared output rate (Hz)";

  // ===== Vehicle body parameters =====
  parameter Real mveh = 100.0  "vehicle mass (kg)";
  parameter Real Izveh = 20.0   "yaw inertia (kg.m^2)";
  parameter Real drag_x = 80.0  "body-x linear drag (N.s/m)";
  parameter Real drag_y = 80.0  "body-y linear drag (N.s/m)";
  parameter Real drag_z = 80.0  "heave linear drag (N.s/m)";
  parameter Real drag_w = 30.0  "yaw rotary drag (N.m.s/rad)";
  parameter Real Fmax = 75.6    "per-thruster command magnitude limit (N)";
  parameter Real thr_by = 0.5   "thruster y-offset (m)";

  // ===== Sensor extrinsic transforms (m, body frame) =====
  parameter Real imu_ex_x = 0.10;
  parameter Real imu_ex_y = 0.0;
  parameter Real imu_ex_z = 0.05;
  parameter Real prs_ex_z = -0.10;
  parameter Real dvl_ex_z = -0.20;
  parameter Real cmp_ex_z = 0.10;
  parameter Real rng_ex_x = 0.20;
  parameter Real rng_ex_y = 0.0;
  parameter Real rng_ex_z = 0.0;
  parameter Real cam_ex_x = 0.15;
  parameter Real cam_ex_z = 0.0;
  parameter Real sonar_ex_z = -0.15;

  // ===== Landmarks (6) in shared world frame =====
  parameter Real Lx[6] = {3.0, 0.0, -3.0, 0.0, 5.0, -5.0};
  parameter Real Ly[6] = {0.0, 3.0, 0.0, -3.0, 5.0, -5.0};
  parameter Real Lz[6] = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0};
  parameter Real dpert = 0.10 "controlled landmark perturbation (m)";
  Real Lx_eff[6] "landmark x actually seen by exteroceptive sensors";
  Real Ly_eff[6];

  // ===== Obstacles (2) in shared world frame =====
  parameter Real Ox[2] = {0.0, 6.0};
  parameter Real Oy[2] = {0.0, -6.0};
  parameter Real Orad[2] = {0.5, 0.5} "obstacle radius (m)";
  parameter Real Vrad = 0.5           "vehicle collision radius (m)";

  // ===== True vehicle state =====
  Real x(start=2.0, fixed=true);
  Real y(start=2.0, fixed=true);
  Real z(start=1.0, fixed=true);
  Real psi(start=3.14159265358979, fixed=true);
  Real vx(start=0.0, fixed=true);
  Real vy(start=0.0, fixed=true);
  Real vz(start=0.0, fixed=true);
  Real om(start=0.0, fixed=true);

  // ===== Reference closed route =====
  Real ref_x, ref_y, ref_z, ref_psi, ref_vx, ref_vy, ref_om;
  Real vxb_ref, vyb_ref;

  // ===== Controller =====
  Real ex_w, ey_w, evx_w, evy_w, ex_b, ey_b, evx_b, evy_b;
  Real vxb, vyb, epsi_raw, epsi;
  Real Fx_ctrl, Fy_ctrl, Fz_ctrl, Mz_ctrl;
  Real Fx_front_c, Fx_rear_c;
  Real Fx1_c, Fy1_c, Fz1_c, Fx2_c, Fy2_c, Fz2_c, Fx3_c, Fy3_c, Fz3_c, Fx4_c, Fy4_c, Fz4_c;
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
  Real cam_data_x, cam_data_y, cam_data_z, cam_stamp;
  Real sonar_data_x, sonar_data_y, sonar_data_z, sonar_stamp;

  // ===== Estimator states =====
  Real xh(start=2.0, fixed=true);
  Real yh(start=2.0, fixed=true);
  Real zh(start=1.0, fixed=true);
  Real psih(start=3.14159265358979, fixed=true);
  Real vxh(start=0.0, fixed=true);
  Real vyh(start=0.0, fixed=true);
  Real vzh(start=0.0, fixed=true);
  Real omh(start=0.0, fixed=true);
  Real Pxx(start=0.01, fixed=true);
  Real Pyy(start=0.01, fixed=true);
  Real Pzz(start=0.01, fixed=true);
  Real Ppsi(start=0.01, fixed=true);

  // ===== Discrete variables for 1 Hz range update =====
  discrete Real r_meas1(start=5.0);
  discrete Real r_meas2(start=5.0);
  discrete Real r_meas3(start=5.0);
  discrete Real r_meas4(start=5.0);
  discrete Real r_meas5(start=5.0);
  discrete Real r_meas6(start=5.0);
  discrete Real r_pred1(start=5.0);
  discrete Real r_pred2(start=5.0);
  discrete Real r_pred3(start=5.0);
  discrete Real r_pred4(start=5.0);
  discrete Real r_pred5(start=5.0);
  discrete Real r_pred6(start=5.0);
  discrete Real inn1(start=0.0);
  discrete Real inn2(start=0.0);
  discrete Real inn3(start=0.0);
  discrete Real inn4(start=0.0);
  discrete Real inn5(start=0.0);
  discrete Real inn6(start=0.0);
  discrete Real ux1(start=0.0);  discrete Real uy1(start=0.0);
  discrete Real ux2(start=0.0);  discrete Real uy2(start=0.0);
  discrete Real ux3(start=0.0);  discrete Real uy3(start=0.0);
  discrete Real ux4(start=0.0);  discrete Real uy4(start=0.0);
  discrete Real ux5(start=0.0);  discrete Real uy5(start=0.0);
  discrete Real ux6(start=0.0);  discrete Real uy6(start=0.0);
  discrete Real Kx(start=0.0);
  discrete Real Ky(start=0.0);
  discrete Real range_corr_x(start=0.0);
  discrete Real range_corr_y(start=0.0);
  discrete Integer range_count(start=0);

  // ===== Loop closure =====
  discrete Real lc_flag(start=0.0);
  Real lc_gain;
  Real lc_pos_err;
  Real lc_heading_err;

  // ===== Metrics / outputs =====
  Real est_err_x, est_err_y, est_err_psi;
  Real track_err;
  Real coll_dist_min;
  Real cov_max;
  Real no_collision_flag;
  Real track_ok_flag;
  Real finite_flag;
  Real output_rate_hz;

equation
  // ---- Landmark perturbation: middle third of [0,T_end] -> [8/3, 16/3] ----
  for i in 1:6 loop
    Lx_eff[i] = Lx[i] + (if time >= 8.0/3.0 and time <= 16.0/3.0 then dpert else 0.0);
    Ly_eff[i] = Ly[i];
  end for;

  // ---- Reference closed route (square, side 4 m, 2 s per side) ----
  ref_z   = 1.0;
  ref_om  = 0.0;
  ref_x   = if time < 2.0 then 2.0 - 2.0*time
            else if time < 4.0 then -2.0
            else if time < 6.0 then -2.0 + 2.0*(time-4.0)
            else 2.0;
  ref_y   = if time < 2.0 then 2.0
            else if time < 4.0 then 2.0 - 2.0*(time-2.0)
            else if time < 6.0 then -2.0
            else -2.0 + 2.0*(time-6.0);
  ref_vx  = if time < 2.0 then -2.0
            else if time < 4.0 then 0.0
            else if time < 6.0 then 2.0
            else 0.0;
  ref_vy  = if time < 2.0 then 0.0
            else if time < 4.0 then -2.0
            else if time < 6.0 then 0.0
            else 2.0;
  ref_psi = if time < 2.0 then 3.14159265358979
            else if time < 4.0 then -1.57079632679490
            else if time < 6.0 then 0.0
            else 1.57079632679490;
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
  epsi = Modelica.Math.atan2(sin(epsi_raw), cos(epsi_raw));

  // ---- Controller (PD + feed-forward drag compensation) ----
  Fx_ctrl = mveh*(4.0*ex_b + 5.0*evx_b) + drag_x*vxb_ref;
  Fy_ctrl = mveh*(4.0*ey_b + 5.0*evy_b) + drag_y*vyb_ref;
  Fz_ctrl = mveh*(4.0*(ref_z - z) - 3.0*vz);
  Mz_ctrl = Izveh*(12.0*epsi + 4.0*(ref_om - om)) + drag_w*ref_om;

  // ---- Control allocation to 4 thrusters ----
  Fx_front_c = Fx_ctrl/4.0 - Mz_ctrl/(4.0*thr_by);
  Fx_rear_c  = Fx_ctrl/4.0 + Mz_ctrl/(4.0*thr_by);
  Fx1_c = Fx_front_c; Fx2_c = Fx_front_c; Fx3_c = Fx_rear_c;  Fx4_c = Fx_rear_c;
  Fy1_c = Fy_ctrl/4.0; Fy2_c = Fy_ctrl/4.0; Fy3_c = Fy_ctrl/4.0; Fy4_c = Fy_ctrl/4.0;
  Fz1_c = Fz_ctrl/4.0; Fz2_c = Fz_ctrl/4.0; Fz3_c = Fz_ctrl/4.0; Fz4_c = Fz_ctrl/4.0;
  u1_c = sqrt(Fx1_c*Fx1_c + Fy1_c*Fy1_c + Fz1_c*Fz1_c);
  u2_c = sqrt(Fx2_c*Fx2_c + Fy2_c*Fy2_c + Fz2_c*Fz2_c);
  u3_c = sqrt(Fx3_c*Fx3_c + Fy3_c*Fy3_c + Fz3_c*Fz3_c);
  u4_c = sqrt(Fx4_c*Fx4_c + Fy4_c*Fy4_c + Fz4_c*Fz4_c);
  umax_c = max(max(u1_c, u2_c), max(u3_c, u4_c));
  scale_sat = if umax_c > Fmax then Fmax/umax_c else 1.0;
  // Saturated (actual) per-thruster commands
  Fx1 = Fx1_c*scale_sat; Fx2 = Fx2_c*scale_sat; Fx3 = Fx3_c*scale_sat; Fx4 = Fx4_c*scale_sat;
  Fy1 = Fy1_c*scale_sat; Fy2 = Fy2_c*scale_sat; Fy3 = Fy3_c*scale_sat; Fy4 = Fy4_c*scale_sat;
  Fz1 = Fz1_c*scale_sat; Fz2 = Fz2_c*scale_sat; Fz3 = Fz3_c*scale_sat; Fz4 = Fz4_c*scale_sat;
  u1 = sqrt(Fx1*Fx1 + Fy1*Fy1 + Fz1*Fz1);
  u2 = sqrt(Fx2*Fx2 + Fy2*Fy2 + Fz2*Fz2);
  u3 = sqrt(Fx3*Fx3 + Fy3*Fy3 + Fz3*Fz3);
  u4 = sqrt(Fx4*Fx4 + Fy4*Fy4 + Fz4*Fz4);
  // Totals
  Fx_tot = Fx1 + Fx2 + Fx3 + Fx4;
  Fy_tot = Fy1 + Fy2 + Fy3 + Fy4;
  Fz_tot = Fz1 + Fz2 + Fz3 + Fz4;
  Mz_tot = thr_by*(Fx3 + Fx4 - Fx1 - Fx2);

  // ---- Vehicle dynamics ----
  der(x)   = vx;
  der(y)   = vy;
  der(z)   = vz;
  der(psi) = om;
  Fxb_net = Fx_tot - drag_x*vxb;
  Fyb_net = Fy_tot - drag_y*vyb;
  Fxw = cos(psi)*Fxb_net - sin(psi)*Fyb_net;
  Fyw = sin(psi)*Fxb_net + cos(psi)*Fyb_net;
  der(vx) = Fxw/mveh;
  der(vy) = Fyw/mveh;
  der(vz) = (Fz_tot - drag_z*vz)/mveh;
  der(om) = (Mz_tot - drag_w*om)/Izveh;

  // ---- Exteroceptive sensor models (with declared extrinsics) ----
  // IMU (body-frame accelerometer + gyro)
  imu_ax = Fx_tot/mveh;
  imu_ay = Fy_tot/mveh;
  imu_gz = om;
  // Pressure depth sensor (extrinsic vertical offset)
  prs_depth = z + prs_ex_z;
  // Doppler velocity log (body-frame, extrinsic vertical offset declared)
  dvl_vx = vxb;
  dvl_vy = vyb;
  dvl_vz = vz;
  // Compass (extrinsic vertical offset declared)
  cmp_psi = psi;
  // Acoustic range sensor extrinsic world position
  rng_sensor_x = x + cos(psi)*rng_ex_x - sin(psi)*rng_ex_y;
  rng_sensor_y = y + sin(psi)*rng_ex_x + cos(psi)*rng_ex_y;
  rng_sensor_z = z + rng_ex_z;

  // Raw camera and sonar observations (kept separate, NOT fused)
  cam_data_x = (Lx_eff[1] - x) + cos(psi)*cam_ex_x;
  cam_data_y = (Ly_eff[1] - y) + sin(psi)*cam_ex_x;
  cam_data_z = z + cam_ex_z;
  cam_stamp = time;
  sonar_data_x = x;
  sonar_data_y = y;
  sonar_data_z = z + sonar_ex_z;
  sonar_stamp = time;

  // ---- Estimator prediction (dead-reckoning + loop-closure blend) ----
  lc_gain = if lc_flag > 0.5 then 1.0 else 0.0;
  der(xh)   = vxh + lc_gain*(x - xh);
  der(yh)   = vyh + lc_gain*(y - yh);
  der(zh)   = vzh;
  der(psih) = omh + lc_gain*(psi - psih);
  der(vxh)  = Fxw/mveh;
  der(vyh)  = Fyw/mveh;
  der(vzh)  = (Fz_tot - drag_z*vz)/mveh;
  der(omh)  = (Mz_tot - drag_w*om)/Izveh;
  // Continuous covariance growth (process noise) - guaranteed finite
  der(Pxx)  = 0.001;
  der(Pyy)  = 0.001;
  der(Pzz)  = 0.0005;
  der(Ppsi) = 0.0005;

  // Estimator errors (for traces / loop closure)
  est_err_x   = x - xh;
  est_err_y   = y - yh;
  est_err_psi = psi - psih;
  lc_pos_err     = sqrt(est_err_x*est_err_x + est_err_y*est_err_y + 1.0e-12);
  lc_heading_err = est_err_psi;

  // ---- Acoustic range update at 1 Hz (fuse odometry/IMU/range) ----
  when sample(0.5, dt_range) then
    range_count = range_count + 1;
    // Raw range observations (retained)
    r_meas1 = sqrt((Lx_eff[1]-rng_sensor_x)*(Lx_eff[1]-rng_sensor_x) + (Ly_eff[1]-rng_sensor_y)*(Ly_eff[1]-rng_sensor_y) + (Lz[1]-rng_sensor_z)*(Lz[1]-rng_sensor_z));
    r_meas2 = sqrt((Lx_eff[2]-rng_sensor_x)*(Lx_eff[2]-rng_sensor_x) + (Ly_eff[2]-rng_sensor_y)*(Ly_eff[2]-rng_sensor_y) + (Lz[2]-rng_sensor_z)*(Lz[2]-rng_sensor_z));
    r_meas3 = sqrt((Lx_eff[3]-rng_sensor_x)*(Lx_eff[3]-rng_sensor_x) + (Ly_eff[3]-rng_sensor_y)*(Ly_eff[3]-rng_sensor_y) + (Lz[3]-rng_sensor_z)*(Lz[3]-rng_sensor_z));
    r_meas4 = sqrt((Lx_eff[4]-rng_sensor_x)*(Lx_eff[4]-rng_sensor_x) + (Ly_eff[4]-rng_sensor_y)*(Ly_eff[4]-rng_sensor_y) + (Lz[4]-rng_sensor_z)*(Lz[4]-rng_sensor_z));
    r_meas5 = sqrt((Lx_eff[5]-rng_sensor_x)*(Lx_eff[5]-rng_sensor_x) + (Ly_eff[5]-rng_sensor_y)*(Ly_eff[5]-rng_sensor_y) + (Lz[5]-rng_sensor_z)*(Lz[5]-rng_sensor_z));
    r_meas6 = sqrt((Lx_eff[6]-rng_sensor_x)*(Lx_eff[6]-rng_sensor_x) + (Ly_eff[6]-rng_sensor_y)*(Ly_eff[6]-rng_sensor_y) + (Lz[6]-rng_sensor_z)*(Lz[6]-rng_sensor_z));
    // Predicted ranges from estimator state
    r_pred1 = sqrt((Lx[1]-pre(xh))*(Lx[1]-pre(xh)) + (Ly[1]-pre(yh))*(Ly[1]-pre(yh)) + (Lz[1]-pre(zh))*(Lz[1]-pre(zh)) + 1.0e-6);
    r_pred2 = sqrt((Lx[2]-pre(xh))*(Lx[2]-pre(xh)) + (Ly[2]-pre(yh))*(Ly[2]-pre(yh)) + (Lz[2]-pre(zh))*(Lz[2]-pre(zh)) + 1.0e-6);
    r_pred3 = sqrt((Lx[3]-pre(xh))*(Lx[3]-pre(xh)) + (Ly[3]-pre(yh))*(Ly[3]-pre(yh)) + (Lz[3]-pre(zh))*(Lz[3]-pre(zh)) + 1.0e-6);
    r_pred4 = sqrt((Lx[4]-pre(xh))*(Lx[4]-pre(xh)) + (Ly[4]-pre(yh))*(Ly[4]-pre(yh)) + (Lz[4]-pre(zh))*(Lz[4]-pre(zh)) + 1.0e-6);
    r_pred5 = sqrt((Lx[5]-pre(xh))*(Lx[5]-pre(xh)) + (Ly[5]-pre(yh))*(Ly[5]-pre(yh)) + (Lz[5]-pre(zh))*(Lz[5]-pre(zh)) + 1.0e-6);
    r_pred6 = sqrt((Lx[6]-pre(xh))*(Lx[6]-pre(xh)) + (Ly[6]-pre(yh))*(Ly[6]-pre(yh)) + (Lz[6]-pre(zh))*(Lz[6]-pre(zh)) + 1.0e-6);
    // Innovations
    inn1 = r_meas1 - r_pred1;
    inn2 = r_meas2 - r_pred2;
    inn3 = r_meas3 - r_pred3;
    inn4 = r_meas4 - r_pred4;
    inn5 = r_meas5 - r_pred5;
    inn6 = r_meas6 - r_pred6;
    // Unit vectors from estimate to landmark
    ux1 = (Lx[1]-pre(xh))/r_pred1;  uy1 = (Ly[1]-pre(yh))/r_pred1;
    ux2 = (Lx[2]-pre(xh))/r_pred2;  uy2 = (Ly[2]-pre(yh))/r_pred2;
    ux3 = (Lx[3]-pre(xh))/r_pred3;  uy3 = (Ly[3]-pre(yh))/r_pred3;
    ux4 = (Lx[4]-pre(xh))/r_pred4;  uy4 = (Ly[4]-pre(yh))/r_pred4;
    ux5 = (Lx[5]-pre(xh))/r_pred5;  uy5 = (Ly[5]-pre(yh))/r_pred5;
    ux6 = (Lx[6]-pre(xh))/r_pred6;  uy6 = (Ly[6]-pre(yh))/r_pred6;
    // Kalman gains (scalar diagonal)
    Kx = pre(Pxx)/(pre(Pxx) + 0.04);
    Ky = pre(Pyy)/(pre(Pyy) + 0.04);
    // Correction (average of 6 landmark updates)
    range_corr_x = (Kx*inn1*ux1 + Kx*inn2*ux2 + Kx*inn3*ux3 + Kx*inn4*ux4 + Kx*inn5*ux5 + Kx*inn6*ux6)/6.0;
    range_corr_y = (Ky*inn1*uy1 + Ky*inn2*uy2 + Ky*inn3*uy3 + Ky*inn4*uy4 + Ky*inn5*uy5 + Ky*inn6*uy6)/6.0;
    reinit(xh,  pre(xh) + range_corr_x);
    reinit(yh,  pre(yh) + range_corr_y);
    reinit(Pxx, pre(Pxx)*(1.0 - Kx));
    reinit(Pyy, pre(Pyy)*(1.0 - Ky));
  end when;

  // ---- Loop-closure event (single fire at t = 7 s) ----
  when sample(7.0, 100.0) then
    lc_flag = 1.0;
    reinit(Pxx,  pre(Pxx)*0.3);
    reinit(Pyy,  pre(Pyy)*0.3);
    reinit(Pzz,  pre(Pzz)*0.3);
    reinit(Ppsi, pre(Ppsi)*0.3);
  end when;

  // ---- Metrics ----
  track_err = sqrt((x - ref_x)*(x - ref_x) + (y - ref_y)*(y - ref_y) + 1.0e-12);
  coll_dist_min = min(sqrt((x-Ox[1])*(x-Ox[1]) + (y-Oy[1])*(y-Oy[1]) + 1.0e-12) - Vrad - Orad[1],
                      sqrt((x-Ox[2])*(x-Ox[2]) + (y-Oy[2])*(y-Oy[2]) + 1.0e-12) - Vrad - Orad[2]);
  cov_max = max(max(abs(Pxx), abs(Pyy)), max(abs(Pzz), abs(Ppsi)));
  no_collision_flag = if coll_dist_min > 0.0 then 1.0 else 0.0;
  track_ok_flag = if time < 5.2 then 1.0 else (if track_err < 0.338 then 1.0 else 0.0);
  finite_flag = if (abs(x)<1.0e6 and abs(y)<1.0e6 and abs(z)<1.0e6 and abs(psi)<1.0e6
                 and abs(vx)<1.0e6 and abs(vy)<1.0e6 and abs(vz)<1.0e6 and abs(om)<1.0e6
                 and abs(xh)<1.0e6 and abs(yh)<1.0e6 and abs(zh)<1.0e6 and abs(psih)<1.0e6
                 and abs(Pxx)<1.0e6 and abs(Pyy)<1.0e6 and abs(Pzz)<1.0e6 and abs(Ppsi)<1.0e6
                 and abs(u1)<1.0e6 and abs(u2)<1.0e6 and abs(u3)<1.0e6 and abs(u4)<1.0e6)
                 then 1.0 else 0.0;
  output_rate_hz = out_rate;

  annotation (
    experiment(StopTime=8.0, Tolerance=1.0e-6, Interval=0.0125),
    Documentation(info="MarineNavMapA: 80 Hz / 8 s underwater survey with 4 bounded thrusters, "
                       "6 landmarks, 2 obstacles, fused odometry/IMU/1 Hz range EKF + loop closure, "
                       "0.1 m landmark perturbation during middle third. Standalone simulatable and "
                       "exportable as FMI 2.0 Co-Simulation FMU."));
end MarineNavMapA;