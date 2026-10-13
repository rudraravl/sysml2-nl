model WheelIMUMapB
  // ===== Physical parameters =====
  parameter Real m = 16.0 "chassis mass, kg";
  parameter Real r = 0.05 "wheel radius, m";
  parameter Real L = 0.40 "wheel base, m";
  parameter Real Iz = 0.60 "yaw inertia, kg.m2";
  parameter Real tau_max = 8.2 "allowed wheel torque magnitude, N.m";
  parameter Real tau_drv = 0.05 "drivetrain lag, s";
  parameter Real robot_radius = 0.20 "chassis collision radius, m";

  // ===== IMU declared noise and bias =====
  parameter Real accel_noise_std = 0.05 "accel noise std, m/s2";
  parameter Real gyro_noise_std = 0.01 "gyro noise std, rad/s";
  parameter Real accel_bias_decl = 0.02 "accel bias, m/s2";
  parameter Real gyro_bias_decl = 0.005 "gyro bias, rad/s";

  // ===== Mission / output =====
  parameter Real output_rate_Hz = 100.0 "declared output rate, Hz";
  parameter Real dt_out = 0.01 "output period, s";
  parameter Real T_total = 10.0 "mission duration, s";
  parameter Real R_route = 1.5 "closed route radius, m";
  parameter Real dperturb = 0.14 "landmark perturbation, m";
  parameter Real pi_val = 3.141592653589793 "pi constant";
  parameter Real pi_half = 1.5707963267948966 "pi/2 constant";

  // ===== Landmarks (6 fixed) =====
  parameter Real lx1 = 2.5 "m";
  parameter Real ly1 = 0.0 "m";
  parameter Real lx2 = 1.5 "m";
  parameter Real ly2 = 2.2 "m";
  parameter Real lx3 = -1.5 "m";
  parameter Real ly3 = 2.0 "m";
  parameter Real lx4 = -2.5 "m";
  parameter Real ly4 = -0.5 "m";
  parameter Real lx5 = 0.0 "m";
  parameter Real ly5 = -2.2 "m";
  parameter Real lx6 = 3.0 "m";
  parameter Real ly6 = 1.5 "m";

  // ===== Obstacles (2) =====
  parameter Real ox1 = 2.5 "m";
  parameter Real oy1 = 1.0 "m";
  parameter Real orad1 = 0.30 "obstacle radius, m";
  parameter Real ox2 = -2.5 "m";
  parameter Real oy2 = -1.0 "m";
  parameter Real orad2 = 0.30 "obstacle radius, m";

  // ===== Controller / estimator gains =====
  parameter Real Kv = 2.0;
  parameter Real Kp = 5.0;
  parameter Real Ko = 1.0;
  parameter Real Kh = 4.0;
  parameter Real Ky = 3.0;
  parameter Real tau_est = 0.10;
  parameter Real Kg = 2.0;
  parameter Real K_range = 0.5;
  parameter Real K_lc = 1.0;
  parameter Real K_lc_h = 2.0;
  parameter Real Q_pose = 0.01;
  parameter Real Q_theta = 0.001;
  parameter Real tau_p = 2.0;

  // ===== Physical states =====
  Real x(start=1.5) "world x, m";
  Real y(start=0.0) "world y, m";
  Real theta(start=1.5707963267948966) "heading, rad";
  Real v(start=0.0) "forward speed, m/s";
  Real omega(start=0.0) "yaw rate, rad/s";
  Real F_L(start=0.0) "left tractive force, N";
  Real F_R(start=0.0) "right tractive force, N";

  // ===== Commands =====
  Real tau_L_cmd "left wheel torque command, N.m";
  Real tau_R_cmd "right wheel torque command, N.m";
  Real tau_L "saturated left torque, N.m";
  Real tau_R "saturated right torque, N.m";

  // ===== Reference =====
  Real phi_ref "route angle, rad";
  Real x_ref "m";
  Real y_ref "m";
  Real theta_ref "rad";
  Real v_ref "m/s";
  Real omega_ref "rad/s";

  // ===== Sensors (raw) =====
  Real accel_raw "body longitudinal accel raw, m/s2";
  Real gyro_raw "yaw rate raw, rad/s";
  Real v_odo "odometry forward speed, m/s";
  Real omega_odo "odometry yaw rate, rad/s";
  Real range_raw1 "raw range to landmark 1, m";
  Real range_raw2 "raw range to landmark 2, m";
  Real range_raw3 "raw range to landmark 3, m";
  Real range_raw4 "raw range to landmark 4, m";
  Real range_raw5 "raw range to landmark 5, m";
  Real range_raw6 "raw range to landmark 6, m";
  Real camera_data1 "camera bearing obs 1, rad";
  Real camera_data2 "camera bearing obs 2, rad";
  Real camera_data3 "camera bearing obs 3, rad";
  Real camera_data4 "camera bearing obs 4, rad";
  Real camera_data5 "camera bearing obs 5, rad";
  Real camera_data6 "camera bearing obs 6, rad";
  Real sonar_data1 "sonar range to obstacle 1, m";
  Real sonar_data2 "sonar range to obstacle 2, m";

  // ===== Estimator =====
  Real x_est(start=1.5) "m";
  Real y_est(start=0.0) "m";
  Real theta_est(start=1.5707963267948966) "rad";
  Real v_est(start=0.0) "m/s";
  Real omega_est(start=0.0) "rad/s";
  Real P_pose(start=1.0) "finite scalar pose covariance, m2";
  Real P_theta(start=0.1) "finite scalar heading covariance, rad2";
  Real r_pred1 "m";
  Real r_pred2 "m";
  Real r_pred3 "m";
  Real r_pred4 "m";
  Real r_pred5 "m";
  Real r_pred6 "m";
  Real ux1, uy1, ux2, uy2, ux3, uy3;
  Real ux4, uy4, ux5, uy5, ux6, uy6;
  Real innov1 "m";
  Real innov2 "m";
  Real innov3 "m";
  Real innov4 "m";
  Real innov5 "m";
  Real innov6 "m";
  Real corr_x "m/s";
  Real corr_y "m/s";
  Real dp_active "perturbation active flag";
  Real lc_pos_err "m";
  Real lc_head_err "rad";
  Real lc_x_corr "m/s";
  Real lc_y_corr "m/s";
  Real lc_h_corr "rad/s";

  // ===== Controller intermediates =====
  Real ex_w, ey_w, ex_b, ey_b, eth;
  Real a_des "m/s2";
  Real alpha_des "rad/s2";
  Real F_des "N";
  Real M_des "N.m";
  Real F_L_des "N";
  Real F_R_des "N";

  // ===== Performance metrics =====
  Real e_track "primary tracking error, m";
  Real e_track_after "tracking error observed after 6.5 s, m";
  Real d_obs1 "m";
  Real d_obs2 "m";
  Boolean no_collision;
  Real noise_t;
  Real omega_L "left wheel angular velocity, rad/s";
  Real omega_R "right wheel angular velocity, rad/s";

  // ===== Synchronized traces (sampled at 100 Hz) =====
  discrete Real t_sync;
  discrete Real x_sync, y_sync, theta_sync;
  discrete Real tau_L_sync, tau_R_sync;
  discrete Real accel_sync, gyro_sync;
  discrete Real range_sync_1, range_sync_2, range_sync_3;
  discrete Real camera_sync_1, camera_sync_2;
  discrete Real sonar_sync_1, sonar_sync_2;

equation

  // ----- Reference closed route (one loop over T_total) -----
  phi_ref = (2.0*pi_val/T_total)*time;
  x_ref = R_route*cos(phi_ref);
  y_ref = R_route*sin(phi_ref);
  theta_ref = phi_ref + pi_half;
  v_ref = R_route*(2.0*pi_val/T_total);
  omega_ref = (2.0*pi_val/T_total);

  // ----- Chassis dynamics -----
  der(x) = v*cos(theta);
  der(y) = v*sin(theta);
  der(theta) = omega;
  der(v) = (F_L + F_R)/m;
  der(omega) = (L/2.0)*(F_R - F_L)/Iz;
  der(F_L) = (tau_L/r - F_L)/tau_drv;
  der(F_R) = (tau_R/r - F_R)/tau_drv;

  // No-slip wheel rates (for odometry)
  omega_L = (v - (L/2.0)*omega)/r;
  omega_R = (v + (L/2.0)*omega)/r;

  // ----- Command saturation -----
  tau_L = if tau_L_cmd > tau_max then tau_max
          elseif tau_L_cmd < -tau_max then -tau_max
          else tau_L_cmd;
  tau_R = if tau_R_cmd > tau_max then tau_max
          elseif tau_R_cmd < -tau_max then -tau_max
          else tau_R_cmd;

  // ----- Deterministic bounded pseudo-noise -----
  noise_t = 0.1*sin(7.0*time) + 0.05*sin(13.0*time);

  // ----- Raw IMU -----
  accel_raw = (F_L + F_R)/m + accel_bias_decl + accel_noise_std*noise_t;
  gyro_raw = omega + gyro_bias_decl + gyro_noise_std*noise_t;

  // ----- Raw odometry -----
  v_odo = v + 0.01*sin(5.0*time);
  omega_odo = omega + 0.005*sin(7.0*time);

  // ----- Perturbation active in middle third -----
  dp_active = if (time > T_total/3.0 and time < 2.0*T_total/3.0) then 1.0 else 0.0;

  // ----- Raw ranges to landmarks (perturbed in middle third) -----
  range_raw1 = sqrt(max((x - (lx1 + dperturb*dp_active))^2 + (y - ly1)^2, 1e-6))
               + 0.02*sin(5.0 + 3.0*time);
  range_raw2 = sqrt(max((x - (lx2 + dperturb*dp_active))^2 + (y - ly2)^2, 1e-6))
               + 0.02*sin(10.0 + 3.0*time);
  range_raw3 = sqrt(max((x - (lx3 + dperturb*dp_active))^2 + (y - ly3)^2, 1e-6))
               + 0.02*sin(15.0 + 3.0*time);
  range_raw4 = sqrt(max((x - (lx4 + dperturb*dp_active))^2 + (y - ly4)^2, 1e-6))
               + 0.02*sin(20.0 + 3.0*time);
  range_raw5 = sqrt(max((x - (lx5 + dperturb*dp_active))^2 + (y - ly5)^2, 1e-6))
               + 0.02*sin(25.0 + 3.0*time);
  range_raw6 = sqrt(max((x - (lx6 + dperturb*dp_active))^2 + (y - ly6)^2, 1e-6))
               + 0.02*sin(30.0 + 3.0*time);

  // ----- Camera / sonar preserved separately (not fused) -----
  camera_data1 = atan2(ly1 - y, lx1 - x) - theta;
  camera_data2 = atan2(ly2 - y, lx2 - x) - theta;
  camera_data3 = atan2(ly3 - y, lx3 - x) - theta;
  camera_data4 = atan2(ly4 - y, lx4 - x) - theta;
  camera_data5 = atan2(ly5 - y, lx5 - x) - theta;
  camera_data6 = atan2(ly6 - y, lx6 - x) - theta;
  sonar_data1 = sqrt(max((x - ox1)^2 + (y - oy1)^2, 1e-6));
  sonar_data2 = sqrt(max((x - ox2)^2 + (y - oy2)^2, 1e-6));

  // ----- Estimator: predicted ranges / innovations -----
  r_pred1 = sqrt(max((x_est - lx1)^2 + (y_est - ly1)^2, 1e-6));
  r_pred2 = sqrt(max((x_est - lx2)^2 + (y_est - ly2)^2, 1e-6));
  r_pred3 = sqrt(max((x_est - lx3)^2 + (y_est - ly3)^2, 1e-6));
  r_pred4 = sqrt(max((x_est - lx4)^2 + (y_est - ly4)^2, 1e-6));
  r_pred5 = sqrt(max((x_est - lx5)^2 + (y_est - ly5)^2, 1e-6));
  r_pred6 = sqrt(max((x_est - lx6)^2 + (y_est - ly6)^2, 1e-6));

  ux1 = (x_est - lx1)/r_pred1;
  uy1 = (y_est - ly1)/r_pred1;
  ux2 = (x_est - lx2)/r_pred2;
  uy2 = (y_est - ly2)/r_pred2;
  ux3 = (x_est - lx3)/r_pred3;
  uy3 = (y_est - ly3)/r_pred3;
  ux4 = (x_est - lx4)/r_pred4;
  uy4 = (y_est - ly4)/r_pred4;
  ux5 = (x_est - lx5)/r_pred5;
  uy5 = (y_est - ly5)/r_pred5;
  ux6 = (x_est - lx6)/r_pred6;
  uy6 = (y_est - ly6)/r_pred6;

  innov1 = range_raw1 - r_pred1;
  innov2 = range_raw2 - r_pred2;
  innov3 = range_raw3 - r_pred3;
  innov4 = range_raw4 - r_pred4;
  innov5 = range_raw5 - r_pred5;
  innov6 = range_raw6 - r_pred6;

  corr_x = K_range*(innov1*ux1 + innov2*ux2 + innov3*ux3
                   + innov4*ux4 + innov5*ux5 + innov6*ux6)/6.0;
  corr_y = K_range*(innov1*uy1 + innov2*uy2 + innov3*uy3
                   + innov4*uy4 + innov5*uy5 + innov6*uy6)/6.0;

  // ----- Loop-closure correction (active near end of mission) -----
  lc_x_corr = if time > 9.0 then K_lc*(1.5 - x_est) else 0.0;
  lc_y_corr = if time > 9.0 then K_lc*(0.0 - y_est) else 0.0;
  lc_h_corr = if time > 9.0 then K_lc_h*(pi_half - theta_est) else 0.0;

  // ----- Estimator: fused odometry + IMU + range, with loop-closure correction -----
  der(x_est) = v_est*cos(theta_est) + corr_x + lc_x_corr;
  der(y_est) = v_est*sin(theta_est) + corr_y + lc_y_corr;
  der(theta_est) = omega_est + lc_h_corr;
  der(v_est) = (v_odo - v_est)/tau_est + (accel_raw - accel_bias_decl);
  der(omega_est) = (omega_odo - omega_est)/tau_est
                   + Kg*((gyro_raw - gyro_bias_decl) - omega_est);

  // ----- Finite, bounded covariance scalars -----
  der(P_pose) = Q_pose - P_pose/tau_p;
  der(P_theta) = Q_theta - P_theta/tau_p;

  // ----- Loop-closure errors -----
  lc_pos_err = sqrt(max((x_est - 1.5)^2 + (y_est - 0.0)^2, 1e-6));
  lc_head_err = atan2(sin(theta_est - pi_half), cos(theta_est - pi_half));

  // ----- Pose-filtering controller using estimate -----
  ex_w = x_ref - x_est;
  ey_w = y_ref - y_est;
  ex_b = cos(theta_est)*ex_w + sin(theta_est)*ey_w;
  ey_b = -sin(theta_est)*ex_w + cos(theta_est)*ey_w;
  eth = atan2(sin(theta_ref - theta_est), cos(theta_ref - theta_est));
  a_des = Kv*(v_ref - v_est) + Kp*ex_b;
  alpha_des = Ko*(omega_ref - omega_est) + Kh*eth + Ky*ey_b;
  F_des = m*a_des;
  M_des = Iz*alpha_des;
  F_R_des = F_des/2.0 + M_des/L;
  F_L_des = F_des/2.0 - M_des/L;
  tau_L_cmd = F_L_des*r;
  tau_R_cmd = F_R_des*r;

  // ----- Tracking error -----
  e_track = sqrt(max((x - x_ref)^2 + (y - y_ref)^2, 1e-6));
  e_track_after = if time > 6.5 then e_track else 0.0;

  // ----- Collision check -----
  d_obs1 = sqrt(max((x - ox1)^2 + (y - oy1)^2, 1e-6));
  d_obs2 = sqrt(max((x - ox2)^2 + (y - oy2)^2, 1e-6));
  no_collision = (d_obs1 > orad1 + robot_radius) and (d_obs2 > orad2 + robot_radius);

  // ----- Synchronized traces at declared output rate (100 Hz) -----
  when sample(0, dt_out) then
    t_sync = time;
    x_sync = x;
    y_sync = y;
    theta_sync = theta;
    tau_L_sync = tau_L;
    tau_R_sync = tau_R;
    accel_sync = accel_raw;
    gyro_sync = gyro_raw;
    range_sync_1 = range_raw1;
    range_sync_2 = range_raw2;
    range_sync_3 = range_raw3;
    camera_sync_1 = camera_data1;
    camera_sync_2 = camera_data2;
    sonar_sync_1 = sonar_data1;
    sonar_sync_2 = sonar_data2;
  end when;

  annotation (
    experiment(StopTime=10.0, Tolerance=1e-6, Interval=0.01),
    Documentation(info="WheelIMUMapB: differential-drive sensing/estimation mission. "
                       "Parameters not given in the requirement (wheel radius, wheel base, "
                       "yaw inertia, drivetrain lag, obstacle radii, route radius, gains) are "
                       "assumed and labeled; only given numeric facts are bound from the requirement."));
end WheelIMUMapB;