model QuadScoutSurveyA
  /* Free-base quadrotor aerial robot with waypoint tracking, sensor fusion,
     obstacle monitoring, crosswind disturbance, and safety monitors.
     Inertia values estimated from 1.8 kg box fuselage (dimensions not specified).
     Yaw moment coefficient assumed (rotor drag relationship not specified).
     Waypoint deadlines distributed across the 8 s scenario.
     Obstacles placed outside the reference polyline. */

  // ==================== PHYSICAL PARAMETERS ====================
  parameter Real m = 1.8 "kg, fuselage mass";
  parameter Real g_acc = 9.81 "m/s2, gravitational acceleration";
  parameter Real L_arm = 0.22 "m, rotor arm length";
  parameter Real d_arm = L_arm / sqrt(2.0) "m, rotor half-diagonal";
  parameter Real Ixx_val = 0.015 "kg.m2, roll inertia (estimated; box dims not specified)";
  parameter Real Iyy_val = 0.015 "kg.m2, pitch inertia (estimated; box dims not specified)";
  parameter Real Izz_val = 0.030 "kg.m2, yaw inertia (estimated; box dims not specified)";
  parameter Real k_yaw_coeff = 0.005 "N.m per N, rotor yaw moment coefficient (assumed)";
  parameter Real u_max = 8.64 "N, per-rotor command magnitude limit";

  // ==================== WAYPOINT PARAMETERS ====================
  parameter Real wp1x = 0.0 "m";  parameter Real wp1y = 0.0 "m";  parameter Real wp1z = 1.5 "m";
  parameter Real wp2x = 4.0 "m";  parameter Real wp2y = 0.0 "m";  parameter Real wp2z = 2.5 "m";
  parameter Real wp3x = 4.0 "m";  parameter Real wp3y = 3.0 "m";  parameter Real wp3z = 2.5 "m";
  parameter Real wp4x = 1.0 "m";  parameter Real wp4y = 4.0 "m";  parameter Real wp4z = 2.0 "m";
  parameter Real t_wp1 = 0.0 "s";  parameter Real t_wp2 = 2.5 "s";
  parameter Real t_wp3 = 5.0 "s";  parameter Real t_wp4 = 8.0 "s";

  // ==================== OBSTACLE PARAMETERS ====================
  parameter Real obs1cx = -1.5 "m";  parameter Real obs1cy = 1.0 "m";  parameter Real obs1r = 0.5 "m";
  parameter Real obs2cx = 6.0 "m";   parameter Real obs2cy = 1.5 "m";  parameter Real obs2r = 0.5 "m";
  parameter Real obs3cx = 2.0 "m";   parameter Real obs3cy = 5.5 "m";  parameter Real obs3r = 0.6 "m";

  // ==================== DISTURBANCE PARAMETERS ====================
  parameter Real F_wind_mag = 3.0 "N, crosswind magnitude";
  parameter Real t_wind_on = 8.0 / 3.0 "s, middle third start";
  parameter Real t_wind_off = 16.0 / 3.0 "s, middle third end";

  // ==================== CONTROL GAINS ====================
  parameter Real kp_x = 5.0;  parameter Real kd_x = 3.5;
  parameter Real kp_y = 5.0;  parameter Real kd_y = 3.5;
  parameter Real kp_z = 8.0;  parameter Real kd_z = 4.5;
  parameter Real kp_phi = 50.0;   parameter Real kd_phi = 10.0;
  parameter Real kp_theta = 50.0; parameter Real kd_theta = 10.0;
  parameter Real kp_psi = 5.0;    parameter Real kd_psi = 2.0;

  // ==================== ESTIMATOR GAINS ====================
  parameter Real k1_pos = 1.5 "position correction gain";
  parameter Real k2_vel = 0.5 "velocity correction gain";
  parameter Real k1_att = 3.0 "attitude correction gain";
  parameter Real k2_rate = 2.0 "rate correction gain";

  // ==================== SIMULATION ====================
  parameter Real dt_ctrl = 1.0 / 80.0 "s, control and sensor update rate";
  parameter Real T_sim = 8.0 "s, scenario duration";

  // ==================== PHYSICAL STATE ====================
  Real x(start=0.0, fixed=true) "m, inertial x position";
  Real y(start=0.0, fixed=true) "m, inertial y position";
  Real z(start=1.5, fixed=true) "m, inertial z position";
  Real vx(start=0.0, fixed=true) "m/s, inertial x velocity";
  Real vy(start=0.0, fixed=true) "m/s, inertial y velocity";
  Real vz(start=0.0, fixed=true) "m/s, inertial z velocity";
  Real phi(start=0.0, fixed=true) "rad, roll angle";
  Real theta(start=0.0, fixed=true) "rad, pitch angle";
  Real psi(start=0.0, fixed=true) "rad, yaw angle";
  Real pb(start=0.0, fixed=true) "rad/s, body roll rate";
  Real qb(start=0.0, fixed=true) "rad/s, body pitch rate";
  Real rb(start=0.0, fixed=true) "rad/s, body yaw rate";

  // ==================== ESTIMATOR STATE ====================
  Real x_est(start=0.0, fixed=true) "m, estimated x";
  Real y_est(start=0.0, fixed=true) "m, estimated y";
  Real z_est(start=1.5, fixed=true) "m, estimated z";
  Real vx_est(start=0.0, fixed=true) "m/s, estimated vx";
  Real vy_est(start=0.0, fixed=true) "m/s, estimated vy";
  Real vz_est(start=0.0, fixed=true) "m/s, estimated vz";
  Real phi_est(start=0.0, fixed=true) "rad, estimated roll";
  Real theta_est(start=0.0, fixed=true) "rad, estimated pitch";
  Real psi_est(start=0.0, fixed=true) "rad, estimated yaw";
  Real p_est(start=0.0, fixed=true) "rad/s, estimated roll rate";
  Real q_est(start=0.0, fixed=true) "rad/s, estimated pitch rate";
  Real r_est(start=0.0, fixed=true) "rad/s, estimated yaw rate";

  // ==================== OUTPUT VARIABLES ====================
  output Real u1_cmd_out "N, rotor 1 command (pre-saturation)";
  output Real u2_cmd_out "N, rotor 2 command (pre-saturation)";
  output Real u3_cmd_out "N, rotor 3 command (pre-saturation)";
  output Real u4_cmd_out "N, rotor 4 command (pre-saturation)";
  output Real u1_sat_out "N, rotor 1 saturated command";
  output Real u2_sat_out "N, rotor 2 saturated command";
  output Real u3_sat_out "N, rotor 3 saturated command";
  output Real u4_sat_out "N, rotor 4 saturated command";
  output Real T_total_out "N, total thrust";
  output Real Mx_out "N.m, roll moment";
  output Real My_out "N.m, pitch moment";
  output Real Mz_out "N.m, yaw moment";

  output Real gps_x_out "m, GPS x measurement";
  output Real gps_y_out "m, GPS y measurement";
  output Real gps_z_out "m, GPS z measurement";
  output Real alt_z_out "m, altimeter z measurement";
  output Real imu_ax_out "m/s2, IMU accelerometer x (body frame)";
  output Real imu_ay_out "m/s2, IMU accelerometer y (body frame)";
  output Real imu_az_out "m/s2, IMU accelerometer z (body frame)";
  output Real imu_gx_out "rad/s, IMU gyroscope x";
  output Real imu_gy_out "rad/s, IMU gyroscope y";
  output Real imu_gz_out "rad/s, IMU gyroscope z";
  output Real cam_ts_out "s, camera timestamp";

  output Real track_error_out "m, trajectory tracking error";
  output Real track_error_post_out "m, tracking error after 5.2 s";
  output Real x_des_out "m, desired x position";
  output Real y_des_out "m, desired y position";
  output Real z_des_out "m, desired z position";

  output Real thrust_bound_ok_out "1.0 if thrust within bounds, else 0.0";
  output Real att_bound_ok_out "1.0 if attitude within bounds, else 0.0";
  output Real collision_ok_out "1.0 if no collision, else 0.0";
  output Real estimator_finite_ok_out "1.0 if estimator finite, else 0.0";
  output Real no_nan_ok_out "1.0 if all values finite, else 0.0";

  // ==================== INTERNAL VARIABLES ====================
  // Trig shorthands (true attitude)
  Real cph, sph, cth, sth, cps, sps;
  // Trig shorthands (estimated attitude)
  Real cph_e, sph_e, cth_e, sth_e, cps_e, sps_e;

  // Rotation matrix: true third column (body Z in world)
  Real R13, R23, R33;
  // Estimated rotation matrix (full, for IMU transform)
  Real Re11, Re12, Re13, Re21, Re22, Re23, Re31, Re32, Re33;

  // Actual world-frame acceleration
  Real ax_w, ay_w, az_w;
  // Body-frame specific force (accelerometer input)
  Real fbx, fby, fbz;

  // Sensor measurements
  Real gps_x_meas, gps_y_meas, gps_z_meas;
  Real alt_z_meas;
  Real imu_ax_meas, imu_ay_meas, imu_az_meas;
  Real imu_gx_meas, imu_gy_meas, imu_gz_meas;
  Real cam_phi_meas, cam_theta_meas;
  Real cam_ts_val;

  // Estimator intermediate
  Real ax_w_est, ay_w_est, az_w_est;

  // Controller intermediate
  Real x_des, y_des, z_des;
  Real vx_des, vy_des, vz_des;
  Real ax_des, ay_des, az_des;
  Real ax_cmd, ay_cmd, az_cmd;
  Real phi_des_val, theta_des_val, psi_des_val;
  Real T_cmd_val;
  Real phi_err, theta_err, psi_err;
  Real Mx_raw, My_raw, Mz_raw;
  Real u1_cmd, u2_cmd, u3_cmd, u4_cmd;
  Real u1_sat, u2_sat, u3_sat, u4_sat;
  Real T_total, Mx, My, Mz;

  // Wind
  Real F_wind_y_val;

  // Segment interpolation
  Real tau1, tau2, tau3;
  Real s1, s2, s3;
  Real ds1, ds2, ds3;
  Real dds1, dds2, dds3;

  // Obstacle distances and collision flags
  Real dist1, dist2, dist3;
  Real coll1, coll2, coll3;

  // Safety finiteness checks
  Real est_finite_check;
  Real phys_finite_check;
  Real cmd_finite_check;

equation
  // ==================== TRIGONOMETRIC SHORTHANDS ====================
  cph = cos(phi);    sph = sin(phi);
  cth = cos(theta);  sth = sin(theta);
  cps = cos(psi);    sps = sin(psi);

  cph_e = cos(phi_est);    sph_e = sin(phi_est);
  cth_e = cos(theta_est);  sth_e = sin(theta_est);
  cps_e = cos(psi_est);    sps_e = sin(psi_est);

  // ==================== ROTATION MATRICES ====================
  // True body-Z axis in world frame (third column of R, ZYX convention)
  R13 = cps * sth * cph + sps * sph;
  R23 = sps * sth * cph - cps * sph;
  R33 = cth * cph;

  // Full estimated rotation matrix (body to world, ZYX convention)
  Re11 = cps_e * cth_e;
  Re12 = cps_e * sth_e * sph_e - sps_e * cph_e;
  Re13 = cps_e * sth_e * cph_e + sps_e * sph_e;
  Re21 = sps_e * cth_e;
  Re22 = sps_e * sth_e * sph_e + cps_e * cph_e;
  Re23 = sps_e * sth_e * cph_e - cps_e * sph_e;
  Re31 = -sth_e;
  Re32 = cth_e * sph_e;
  Re33 = cth_e * cph_e;

  // ==================== WAYPOINT TRAJECTORY (smooth interpolation) ====================
  // Segment 1: wp1 -> wp2, t in [0, 2.5] s
  tau1 = max(0.0, min(1.0, time / t_wp2));
  s1   = 3.0 * tau1^2 - 2.0 * tau1^3;
  ds1  = (6.0 * tau1 - 6.0 * tau1^2) / t_wp2;
  dds1 = (6.0 - 12.0 * tau1) / (t_wp2^2);

  // Segment 2: wp2 -> wp3, t in [2.5, 5.0] s
  tau2 = max(0.0, min(1.0, (time - t_wp2) / (t_wp3 - t_wp2)));
  s2   = 3.0 * tau2^2 - 2.0 * tau2^3;
  ds2  = (6.0 * tau2 - 6.0 * tau2^2) / (t_wp3 - t_wp2);
  dds2 = (6.0 - 12.0 * tau2) / ((t_wp3 - t_wp2)^2);

  // Segment 3: wp3 -> wp4, t in [5.0, 8.0] s
  tau3 = max(0.0, min(1.0, (time - t_wp3) / (t_wp4 - t_wp3)));
  s3   = 3.0 * tau3^2 - 2.0 * tau3^3;
  ds3  = (6.0 * tau3 - 6.0 * tau3^2) / (t_wp4 - t_wp3);
  dds3 = (6.0 - 12.0 * tau3) / ((t_wp4 - t_wp3)^2);

  // Desired position
  x_des = if time < t_wp2 then
            wp1x + s1 * (wp2x - wp1x)
          elseif time < t_wp3 then
            wp2x + s2 * (wp3x - wp2x)
          else
            wp3x + s3 * (wp4x - wp3x);

  y_des = if time < t_wp2 then
            wp1y + s1 * (wp2y - wp1y)
          elseif time < t_wp3 then
            wp2y + s2 * (wp3y - wp2y)
          else
            wp3y + s3 * (wp4y - wp3y);

  z_des = if time < t_wp2 then
            wp1z + s1 * (wp2z - wp1z)
          elseif time < t_wp3 then
            wp2z + s2 * (wp3z - wp2z)
          else
            wp3z + s3 * (wp4z - wp3z);

  // Desired velocity
  vx_des = if time < t_wp2 then
             ds1 * (wp2x - wp1x)
           elseif time < t_wp3 then
             ds2 * (wp3x - wp2x)
           else
             ds3 * (wp4x - wp3x);

  vy_des = if time < t_wp2 then
             ds1 * (wp2y - wp1y)
           elseif time < t_wp3 then
             ds2 * (wp3y - wp2y)
           else
             ds3 * (wp4y - wp3y);

  vz_des = if time < t_wp2 then
             ds1 * (wp2z - wp1z)
           elseif time < t_wp3 then
             ds2 * (wp3z - wp2z)
           else
             ds3 * (wp4z - wp3z);

  // Desired feedforward acceleration
  ax_des = if time < t_wp2 then
             dds1 * (wp2x - wp1x)
           elseif time < t_wp3 then
             dds2 * (wp3x - wp2x)
           else
             dds3 * (wp4x - wp3x);

  ay_des = if time < t_wp2 then
             dds1 * (wp2y - wp1y)
           elseif time < t_wp3 then
             dds2 * (wp3y - wp2y)
           else
             dds3 * (wp4y - wp3y);

  az_des = if time < t_wp2 then
             dds1 * (wp2z - wp1z)
           elseif time < t_wp3 then
             dds2 * (wp3z - wp2z)
           else
             dds3 * (wp4z - wp3z);

  // ==================== CROSSWIND DISTURBANCE ====================
  F_wind_y_val = if time >= t_wind_on and time <= t_wind_off then F_wind_mag else 0.0;

  // ==================== SENSOR MODELS ====================
  // GPS: position with bounded sinusoidal error
  gps_x_meas = x + 0.05 * sin(6.2832 * time);
  gps_y_meas = y + 0.05 * sin(6.2832 * time + 1.2);
  gps_z_meas = z + 0.10 * sin(6.2832 * time + 2.3);

  // Altimeter: altitude with small error
  alt_z_meas = z + 0.02 * sin(12.566 * time);

  // IMU: body-frame specific force (accelerometer) and angular rates (gyroscope)
  fbx = cps * cth * ax_w + sps * cth * ay_w - sth * (az_w + g_acc);
  fby = (cps * sth * sph - sps * cph) * ax_w + (sps * sth * sph + cps * cph) * ay_w + cth * sph * (az_w + g_acc);
  fbz = (cps * sth * cph + sps * sph) * ax_w + (sps * sth * cph - cps * sph) * ay_w + cth * cph * (az_w + g_acc);

  imu_ax_meas = fbx + 0.02 * sin(62.832 * time);
  imu_ay_meas = fby + 0.02 * sin(62.832 * time + 1.5);
  imu_az_meas = fbz + 0.02 * sin(62.832 * time + 3.0);
  imu_gx_meas = pb + 0.001 * sin(125.66 * time);
  imu_gy_meas = qb + 0.001 * sin(125.66 * time + 1.0);
  imu_gz_meas = rb + 0.001 * sin(125.66 * time + 2.0);

  // Camera: attitude at 10 Hz with timestamp
  cam_phi_meas   = phi + 0.005 * sin(31.416 * time);
  cam_theta_meas = theta + 0.005 * sin(31.416 * time + 1.0);
  cam_ts_val     = floor(time * 10.0) / 10.0;

  // ==================== ESTIMATOR (Complementary Filter) ====================
  // Transform IMU accelerometer to world frame using estimated attitude
  ax_w_est = Re11 * imu_ax_meas + Re12 * imu_ay_meas + Re13 * imu_az_meas;
  ay_w_est = Re21 * imu_ax_meas + Re22 * imu_ay_meas + Re23 * imu_az_meas;
  az_w_est = Re31 * imu_ax_meas + Re32 * imu_ay_meas + Re33 * imu_az_meas - g_acc;

  // Position: fuse GPS + IMU-derived acceleration
  der(x_est) = vx_est + k1_pos * (gps_x_meas - x_est);
  der(vx_est) = ax_w_est + k2_vel * (gps_x_meas - x_est);

  der(y_est) = vy_est + k1_pos * (gps_y_meas - y_est);
  der(vy_est) = ay_w_est + k2_vel * (gps_y_meas - y_est);

  // Altitude: fuse altimeter + IMU
  der(z_est) = vz_est + k1_pos * (alt_z_meas - z_est);
  der(vz_est) = az_w_est + k2_vel * (alt_z_meas - z_est);

  // Attitude: fuse gyro + camera
  der(phi_est) = p_est + k1_att * (cam_phi_meas - phi_est);
  der(p_est) = imu_gx_meas + k2_rate * (cam_phi_meas - phi_est);

  der(theta_est) = q_est + k1_att * (cam_theta_meas - theta_est);
  der(q_est) = imu_gy_meas + k2_rate * (cam_theta_meas - theta_est);

  // Yaw: gyro integration only (no yaw sensor specified; drift bounded over 8 s)
  der(psi_est) = r_est;
  der(r_est) = imu_gz_meas;

  // ==================== CONTROLLER ====================
  // Bounded waypoint tracking with feedforward acceleration (uses estimated state)
  ax_cmd = ax_des + kp_x * (x_des - x_est) + kd_x * (vx_des - vx_est);
  ay_cmd = ay_des + kp_y * (y_des - y_est) + kd_y * (vy_des - vy_est);
  az_cmd = az_des + kp_z * (z_des - z_est) + kd_z * (vz_des - vz_est);

  // Desired total thrust magnitude
  T_cmd_val = m * sqrt(ax_cmd^2 + ay_cmd^2 + (az_cmd + g_acc)^2);

  // Desired attitude (yaw held at 0)
  theta_des_val = atan2(ax_cmd, az_cmd + g_acc);
  phi_des_val   = -asin(max(-0.99, min(0.99, ay_cmd * m / T_cmd_val)));
  psi_des_val   = 0.0;

  // Attitude errors (using estimated state)
  phi_err   = phi_des_val - phi_est;
  theta_err = theta_des_val - theta_est;
  psi_err   = psi_des_val - psi_est;

  // Attitude controller (PD on estimated attitude and rate)
  Mx_raw = Ixx_val * (kp_phi * phi_err - kd_phi * p_est);
  My_raw = Iyy_val * (kp_theta * theta_err - kd_theta * q_est);
  Mz_raw = Izz_val * (kp_psi * psi_err - kd_psi * r_est);

  // ==================== CONTROL ALLOCATION (X-config) ====================
  u1_cmd = (T_cmd_val + Mx_raw / d_arm - My_raw / d_arm - Mz_raw / k_yaw_coeff) / 4.0;
  u2_cmd = (T_cmd_val - Mx_raw / d_arm - My_raw / d_arm + Mz_raw / k_yaw_coeff) / 4.0;
  u3_cmd = (T_cmd_val - Mx_raw / d_arm + My_raw / d_arm - Mz_raw / k_yaw_coeff) / 4.0;
  u4_cmd = (T_cmd_val + Mx_raw / d_arm + My_raw / d_arm + Mz_raw / k_yaw_coeff) / 4.0;

  // Thrust saturation [0, u_max]
  u1_sat = max(0.0, min(u_max, u1_cmd));
  u2_sat = max(0.0, min(u_max, u2_cmd));
  u3_sat = max(0.0, min(u_max, u3_cmd));
  u4_sat = max(0.0, min(u_max, u4_cmd));

  // Actual thrust and moments from saturated commands
  T_total = u1_sat + u2_sat + u3_sat + u4_sat;
  Mx = d_arm * (u1_sat - u2_sat - u3_sat + u4_sat);
  My = d_arm * (-u1_sat - u2_sat + u3_sat + u4_sat);
  Mz = k_yaw_coeff * (-u1_sat + u2_sat - u3_sat + u4_sat);

  // ==================== PLANT DYNAMICS ====================
  // Translational kinematics
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;

  // Translational dynamics (thrust along body Z, crosswind in y)
  ax_w = (T_total / m) * R13;
  ay_w = (T_total / m) * R23 + F_wind_y_val / m;
  az_w = (T_total / m) * R33 - g_acc;

  der(vx) = ax_w;
  der(vy) = ay_w;
  der(vz) = az_w;

  // Attitude kinematics (ZYX Euler, safeguarded against cos(theta) -> 0)
  der(phi)   = pb + (qb * sph + rb * cph) * sth / max(cth, 0.1);
  der(theta) = qb * cph - rb * sph;
  der(psi)   = (qb * sph + rb * cph) / max(cth, 0.1);

  // Rotational dynamics (rigid body with gyroscopic coupling)
  der(pb) = (Iyy_val - Izz_val) / Ixx_val * qb * rb + Mx / Ixx_val;
  der(qb) = (Izz_val - Ixx_val) / Iyy_val * pb * rb + My / Iyy_val;
  der(rb) = (Ixx_val - Iyy_val) / Izz_val * pb * qb + Mz / Izz_val;

  // ==================== TRACKING ERROR ====================
  track_error_out = sqrt((x - x_des)^2 + (y - y_des)^2 + (z - z_des)^2);
  track_error_post_out = if time >= 5.2 then track_error_out else 0.0;

  // ==================== OBSTACLE COLLISION CHECK ====================
  dist1 = sqrt((x - obs1cx)^2 + (y - obs1cy)^2);
  dist2 = sqrt((x - obs2cx)^2 + (y - obs2cy)^2);
  dist3 = sqrt((x - obs3cx)^2 + (y - obs3cy)^2);

  coll1 = if (dist1 < obs1r and z > 0.0 and z < 4.0) then 1.0 else 0.0;
  coll2 = if (dist2 < obs2r and z > 0.0 and z < 4.0) then 1.0 else 0.0;
  coll3 = if (dist3 < obs3r and z > 0.0 and z < 4.0) then 1.0 else 0.0;

  collision_ok_out = if (coll1 < 0.5 and coll2 < 0.5 and coll3 < 0.5) then 1.0 else 0.0;

  // ==================== SAFETY MONITORS ====================
  // Thrust bounds: each saturated command in [0, u_max]
  thrust_bound_ok_out = if (u1_sat >= 0.0 and u1_sat <= u_max and
                            u2_sat >= 0.0 and u2_sat <= u_max and
                            u3_sat >= 0.0 and u3_sat <= u_max and
                            u4_sat >= 0.0 and u4_sat <= u_max) then 1.0 else 0.0;

  // Attitude bounds: |phi|, |theta| < 1.0 rad (~57 deg)
  att_bound_ok_out = if (abs(phi) < 1.0 and abs(theta) < 1.0) then 1.0 else 0.0;

  // Estimator finiteness (NaN check via x==x, range check for infinity)
  est_finite_check = if (x_est == x_est and x_est > -1.0e8 and x_est < 1.0e8 and
                         y_est == y_est and y_est > -1.0e8 and y_est < 1.0e8 and
                         z_est == z_est and z_est > -1.0e8 and z_est < 1.0e8 and
                         vx_est == vx_est and vx_est > -1.0e8 and vx_est < 1.0e8 and
                         vy_est == vy_est and vy_est > -1.0e8 and vy_est < 1.0e8 and
                         vz_est == vz_est and vz_est > -1.0e8 and vz_est < 1.0e8 and
                         phi_est == phi_est and phi_est > -1.0e8 and phi_est < 1.0e8 and
                         theta_est == theta_est and theta_est > -1.0e8 and theta_est < 1.0e8 and
                         psi_est == psi_est and psi_est > -1.0e8 and psi_est < 1.0e8)
                     then 1.0 else 0.0;
  estimator_finite_ok_out = est_finite_check;

  // Physical state finiteness
  phys_finite_check = if (x == x and x > -1.0e8 and x < 1.0e8 and
                          y == y and y > -1.0e8 and y < 1.0e8 and
                          z == z and z > -1.0e8 and z < 1.0e8 and
                          vx == vx and vx > -1.0e8 and vx < 1.0e8 and
                          vy == vy and vy > -1.0e8 and vy < 1.0e8 and
                          vz == vz and vz > -1.0e8 and vz < 1.0e8 and
                          phi == phi and phi > -1.0e8 and phi < 1.0e8 and
                          theta == theta and theta > -1.0e8 and theta < 1.0e8 and
                          psi == psi and psi > -1.0e8 and psi < 1.0e8 and
                          T_total == T_total and T_total > -1.0e8 and T_total < 1.0e8 and
                          Mx == Mx and Mx > -1.0e8 and Mx < 1.0e8 and
                          My == My and My > -1.0e8 and My < 1.0e8 and
                          Mz == Mz and Mz > -1.0e8 and Mz < 1.0e8)
                      then 1.0 else 0.0;

  // Command finiteness
  cmd_finite_check = if (u1_sat == u1_sat and u1_sat > -1.0e8 and u1_sat < 1.0e8 and
                         u2_sat == u2_sat and u2_sat > -1.0e8 and u2_sat < 1.0e8 and
                         u3_sat == u3_sat and u3_sat > -1.0e8 and u3_sat < 1.0e8 and
                         u4_sat == u4_sat and u4_sat > -1.0e8 and u4_sat < 1.0e8)
                     then 1.0 else 0.0;

  // Combined no-NaN/no-infinity check
  no_nan_ok_out = if (est_finite_check > 0.5 and phys_finite_check > 0.5 and cmd_finite_check > 0.5) then 1.0 else 0.0;

  // ==================== OUTPUT ASSIGNMENTS ====================
  u1_cmd_out = u1_cmd;
  u2_cmd_out = u2_cmd;
  u3_cmd_out = u3_cmd;
  u4_cmd_out = u4_cmd;
  u1_sat_out = u1_sat;
  u2_sat_out = u2_sat;
  u3_sat_out = u3_sat;
  u4_sat_out = u4_sat;
  T_total_out = T_total;
  Mx_out = Mx;
  My_out = My;
  Mz_out = Mz;

  gps_x_out = gps_x_meas;
  gps_y_out = gps_y_meas;
  gps_z_out = gps_z_meas;
  alt_z_out = alt_z_meas;
  imu_ax_out = imu_ax_meas;
  imu_ay_out = imu_ay_meas;
  imu_az_out = imu_az_meas;
  imu_gx_out = imu_gx_meas;
  imu_gy_out = imu_gy_meas;
  imu_gz_out = imu_gz_meas;
  cam_ts_out = cam_ts_val;

  x_des_out = x_des;
  y_des_out = y_des;
  z_des_out = z_des;

  annotation(
    Documentation(info = "QuadScoutSurveyA: Free-base quadrotor with waypoint tracking, multi-sensor fusion, obstacle monitoring, crosswind disturbance, and safety checks. Runs at 80 Hz for 8 s. Inertia values estimated (box dimensions not specified). Yaw moment coefficient assumed (rotor drag relationship not specified). Waypoint deadlines distributed across the 8 s scenario. Three cylindrical obstacles placed outside the reference polyline."),
    experiment(StartTime = 0, StopTime = 8.0, Tolerance = 1e-6, Interval = 0.0125)
  );
end QuadScoutSurveyA;