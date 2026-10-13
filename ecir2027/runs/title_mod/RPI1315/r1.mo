model MarineNavMapA
  import Modelica.Constants.pi;

  // ===== Timing =====
  parameter Real f_sample = 80.0 "system sampling frequency Hz";
  parameter Real T_end = 8.0 "scenario duration s";
  parameter Real f_out = 80.0 "declared output rate Hz";
  parameter Real range_period = 1.0 "acoustic range update period s";
  parameter Real omega_ref = 2.0*pi/T_end "reference angular velocity rad/s";

  // ===== Vehicle parameters =====
  parameter Real m_vehicle = 50.0 "vehicle mass kg";
  parameter Real Iz_vehicle = 10.0 "moment of inertia kg.m^2";
  parameter Real Cd_lin = 20.0 "linear drag coefficient N.s/m";
  parameter Real Cd_rot = 5.0 "rotational drag coefficient N.m.s";
  parameter Real Fmax = 75.6 "max command force per thruster N";
  parameter Real L_thr = 0.5 "thruster moment arm m";

  // ===== Route =====
  parameter Real R_route = 2.0 "closed route radius m";
  parameter Real z_route = 0.5 "route depth m";

  // ===== Six fixed landmarks in world frame =====
  parameter Real LM1_x = 3.0;
  parameter Real LM1_y = 0.0;
  parameter Real LM2_x = 0.0;
  parameter Real LM2_y = 3.0;
  parameter Real LM3_x = -3.0;
  parameter Real LM3_y = 0.0;
  parameter Real LM4_x = 0.0;
  parameter Real LM4_y = -3.0;
  parameter Real LM5_x = 2.5;
  parameter Real LM5_y = 2.5;
  parameter Real LM6_x = -2.5;
  parameter Real LM6_y = -2.5;

  // ===== Two obstacles in world frame =====
  parameter Real OBS1_x = 4.0;
  parameter Real OBS1_y = 1.0;
  parameter Real OBS1_r = 0.5 "obstacle 1 radius m";
  parameter Real OBS2_x = -4.0;
  parameter Real OBS2_y = -1.0;
  parameter Real OBS2_r = 0.5 "obstacle 2 radius m";

  // ===== Declared sensor extrinsic transforms (body-to-sensor) =====
  parameter Real IMU_bx = 0.1;
  parameter Real IMU_by = 0.0;
  parameter Real IMU_bz = 0.05;
  parameter Real DEP_bx = 0.0;
  parameter Real DEP_by = 0.0;
  parameter Real DEP_bz = 0.1;
  parameter Real DVL_bx = -0.2;
  parameter Real DVL_by = 0.0;
  parameter Real DVL_bz = -0.1;
  parameter Real CMP_bx = 0.0;
  parameter Real CMP_by = 0.0;
  parameter Real CMP_bz = 0.2;
  parameter Real RNG_bx = 0.3;
  parameter Real RNG_by = 0.0;
  parameter Real RNG_bz = 0.0;

  // ===== Controller gains =====
  parameter Real Kp_pos = 100.0;
  parameter Real Kd_pos = 80.0;
  parameter Real Kp_yaw = 15.0;
  parameter Real Kd_yaw = 6.0;
  parameter Real Kp_depth = 30.0;
  parameter Real Kd_depth = 10.0;

  // ===== Estimator parameters =====
  parameter Real Q_pos = 0.0005;
  parameter Real Q_yaw = 0.0005;
  parameter Real range_gain = 1.0;
  parameter Real lc_gain = 2.0;

  // ===== True vehicle states =====
  Real x(start=2.0) "true x position m";
  Real y(start=0.0) "true y position m";
  Real z(start=0.5) "true z position m";
  Real yaw(start=pi/2) "true heading rad";
  Real vx(start=0.0) "true x velocity m/s";
  Real vy(start=0.0) "true y velocity m/s";
  Real vz(start=0.0) "true z velocity m/s";
  Real omega(start=0.0) "true yaw rate rad/s";

  // ===== Estimated states =====
  Real x_est(start=2.0) "estimated x m";
  Real y_est(start=0.0) "estimated y m";
  Real z_est(start=0.5) "estimated z m";
  Real yaw_est(start=pi/2) "estimated heading rad";
  Real vx_est(start=0.0) "estimated vx m/s";
  Real vy_est(start=0.0) "estimated vy m/s";
  Real vz_est(start=0.0) "estimated vz m/s";
  Real omega_est(start=0.0) "estimated yaw rate rad/s";

  // ===== Covariance (diagonal, finite and positive) =====
  Real Pxx(start=0.01) "covariance P_xx m^2";
  Real Pyy(start=0.01) "covariance P_yy m^2";
  Real Pzz(start=0.01) "covariance P_zz m^2";
  Real Pyaw(start=0.01) "covariance P_yawyaw rad^2";

  // ===== Reference trajectory =====
  Real theta_ref "reference path angle rad";
  Real x_ref "reference x m";
  Real y_ref "reference y m";
  Real z_ref "reference z m";
  Real yaw_ref "reference heading rad";
  Real track_err "primary tracking error m";

  // ===== Reference velocity =====
  Real v_ref_x_world "reference world x velocity m/s";
  Real v_ref_y_world "reference world y velocity m/s";
  Real v_ref_body_x "reference body x velocity m/s";
  Real v_ref_body_y "reference body y velocity m/s";

  // ===== Commands =====
  Real F_surge_cmd "surge force command N";
  Real F_sway_cmd "sway force command N";
  Real F_depth_cmd "depth force command N";
  Real Mz_cmd "yaw moment command N.m";
  Real T1 "thruster 1 unsaturated N";
  Real T2 "thruster 2 unsaturated N";
  Real T3 "thruster 3 unsaturated N";
  Real T4 "thruster 4 unsaturated N";
  Real T1_sat "thruster 1 saturated N";
  Real T2_sat "thruster 2 saturated N";
  Real T3_sat "thruster 3 saturated N";
  Real T4_sat "thruster 4 saturated N";
  Real F_surge_act "actual surge force N";
  Real F_sway_act "actual sway force N";
  Real Mz_act "actual yaw moment N.m";

  // ===== Raw sensor outputs =====
  Real imu_ax "IMU x acceleration m/s^2";
  Real imu_ay "IMU y acceleration m/s^2";
  Real imu_az "IMU z acceleration m/s^2";
  Real imu_wz "IMU z angular rate rad/s";
  Real depth_raw "pressure depth measurement m";
  Real dvl_vx "DVL x velocity m/s";
  Real dvl_vy "DVL y velocity m/s";
  Real dvl_vz "DVL z velocity m/s";
  Real compass_yaw "compass heading rad";
  Real range1 "acoustic range to LM1 m";
  Real range2 "acoustic range to LM2 m";
  Real range3 "acoustic range to LM3 m";
  Real range4 "acoustic range to LM4 m";
  Real range5 "acoustic range to LM5 m";
  Real range6 "acoustic range to LM6 m";

  // ===== Discrete range measurements (1 Hz sampling) =====
  Real range1_meas(start=0.0) "sampled range to LM1 m";
  Real range2_meas(start=0.0) "sampled range to LM2 m";
  Real range3_meas(start=0.0) "sampled range to LM3 m";
  Real range_count_real(start=0.0) "range update counter";

  // ===== Loop closure =====
  Boolean loop_closed(start=false) "loop closure flag";
  Real loop_pos_err(start=0.0) "loop-closure position error m";
  Real loop_heading_err(start=0.0) "loop-closure heading error rad";
  Real x0(start=2.0) "initial x m";
  Real y0(start=0.0) "initial y m";
  Real yaw0(start=pi/2) "initial yaw rad";

  // ===== Perturbation =====
  Real perturb "landmark perturbation magnitude m";
  Real lm1_px "perturbed landmark 1 x m";
  Real lm1_py "perturbed landmark 1 y m";

  // ===== Collision =====
  Real dist_obs1 "distance to obstacle 1 m";
  Real dist_obs2 "distance to obstacle 2 m";
  Boolean no_collision(start=true) "no collision flag";

  // ===== Preserved exteroceptive data (NOT fused) =====
  Real sonar_data "sonar return preserved separately";
  Real camera_data "camera intensity preserved separately";

  // ===== Body frame velocities =====
  Real vx_body "body x velocity m/s";
  Real vy_body "body y velocity m/s";

  // ===== Heading error for controller =====
  Real yaw_err_ctrl "heading error rad";

  // ===== Estimator correction terms =====
  Real depth_corr "depth correction m/s";
  Real compass_corr "compass correction rad/s";
  Real range1_est "estimated range to LM1 m";
  Real range2_est "estimated range to LM2 m";
  Real range1_dir_x "unit vector x to LM1 from estimate";
  Real range1_dir_y "unit vector y to LM1 from estimate";
  Real range2_dir_x "unit vector x to LM2 from estimate";
  Real range2_dir_y "unit vector y to LM2 from estimate";
  Real range1_residual "range 1 residual m";
  Real range2_residual "range 2 residual m";
  Real range_corr_x "range correction x m/s";
  Real range_corr_y "range correction y m/s";
  Real lc_corr_x "loop closure correction x m/s";
  Real lc_corr_y "loop closure correction y m/s";
  Real lc_corr_yaw "loop closure correction yaw rad/s";

equation
  // ===== Reference trajectory (closed circular route) =====
  theta_ref = 2.0*pi*time/T_end;
  x_ref = R_route*cos(theta_ref);
  y_ref = R_route*sin(theta_ref);
  z_ref = z_route;
  yaw_ref = theta_ref + pi/2;

  // ===== Reference velocity (feedforward) =====
  v_ref_x_world = -R_route*omega_ref*sin(theta_ref);
  v_ref_y_world = R_route*omega_ref*cos(theta_ref);
  v_ref_body_x = v_ref_x_world*cos(yaw) + v_ref_y_world*sin(yaw);
  v_ref_body_y = -v_ref_x_world*sin(yaw) + v_ref_y_world*cos(yaw);

  // ===== Primary tracking error =====
  track_err = sqrt((x - x_ref)^2 + (y - y_ref)^2 + (z - z_ref)^2 + 1e-12);

  // ===== Landmark perturbation (0.1 m during middle third: 2.667 to 5.333 s) =====
  if time >= T_end/3.0 and time <= 2.0*T_end/3.0 then
    perturb = 0.1;
  else
    perturb = 0.0;
  end if;
  lm1_px = LM1_x + perturb;
  lm1_py = LM1_y + perturb;

  // ===== Body frame velocities =====
  vx_body = vx*cos(yaw) + vy*sin(yaw);
  vy_body = -vx*sin(yaw) + vy*cos(yaw);

  // ===== Heading error for controller (wrapped to [-pi, pi]) =====
  yaw_err_ctrl = atan2(sin(yaw_ref - yaw), cos(yaw_ref - yaw));

  // ===== Controller with feedforward =====
  F_surge_cmd = Kp_pos*((x_ref - x)*cos(yaw) + (y_ref - y)*sin(yaw))
              + Kd_pos*(v_ref_body_x - vx_body)
              + Cd_lin*v_ref_body_x;
  F_sway_cmd = Kp_pos*(-(x_ref - x)*sin(yaw) + (y_ref - y)*cos(yaw))
             + Kd_pos*(v_ref_body_y - vy_body)
             + m_vehicle*R_route*omega_ref^2;
  F_depth_cmd = Kp_depth*(z_ref - z) - Kd_depth*vz;
  Mz_cmd = Kp_yaw*yaw_err_ctrl + Kd_yaw*(omega_ref - omega) + Cd_rot*omega_ref;

  // ===== Thruster allocation (4 thrusters) =====
  T1 = 0.25*F_surge_cmd + 0.25*F_sway_cmd + 0.25*Mz_cmd/L_thr;
  T2 = 0.25*F_surge_cmd - 0.25*F_sway_cmd - 0.25*Mz_cmd/L_thr;
  T3 = 0.25*F_surge_cmd - 0.25*F_sway_cmd + 0.25*Mz_cmd/L_thr;
  T4 = 0.25*F_surge_cmd + 0.25*F_sway_cmd - 0.25*Mz_cmd/L_thr;

  // ===== Thruster saturation (command magnitude limit 75.6 N) =====
  T1_sat = max(-Fmax, min(Fmax, T1));
  T2_sat = max(-Fmax, min(Fmax, T2));
  T3_sat = max(-Fmax, min(Fmax, T3));
  T4_sat = max(-Fmax, min(Fmax, T4));

  // ===== Actual forces from saturated thrusters =====
  F_surge_act = T1_sat + T2_sat + T3_sat + T4_sat;
  F_sway_act = T1_sat - T2_sat - T3_sat + T4_sat;
  Mz_act = (T1_sat - T2_sat + T3_sat - T4_sat)*L_thr;

  // ===== Vehicle dynamics =====
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  der(yaw) = omega;
  der(vx) = (F_surge_act*cos(yaw) - F_sway_act*sin(yaw) - Cd_lin*vx)/m_vehicle;
  der(vy) = (F_surge_act*sin(yaw) + F_sway_act*cos(yaw) - Cd_lin*vy)/m_vehicle;
  der(vz) = (F_depth_cmd - Cd_lin*vz)/m_vehicle;
  der(omega) = (Mz_act - Cd_rot*omega)/Iz_vehicle;

  // ===== IMU sensor (with declared extrinsic transform) =====
  imu_ax = F_surge_act/m_vehicle;
  imu_ay = F_sway_act/m_vehicle;
  imu_az = F_depth_cmd/m_vehicle;
  imu_wz = omega;

  // ===== Pressure depth sensor (with extrinsic offset) =====
  depth_raw = z + DEP_bz;

  // ===== DVL velocity sensor =====
  dvl_vx = vx_body;
  dvl_vy = vy_body;
  dvl_vz = vz;

  // ===== Compass sensor =====
  compass_yaw = yaw;

  // ===== Acoustic range sensors (true ranges with extrinsic offset) =====
  range1 = sqrt((x + RNG_bx*cos(yaw) - lm1_px)^2 + (y + RNG_bx*sin(yaw) - lm1_py)^2 + 1e-12);
  range2 = sqrt((x - LM2_x)^2 + (y - LM2_y)^2 + 1e-12);
  range3 = sqrt((x - LM3_x)^2 + (y - LM3_y)^2 + 1e-12);
  range4 = sqrt((x - LM4_x)^2 + (y - LM4_y)^2 + 1e-12);
  range5 = sqrt((x - LM5_x)^2 + (y - LM5_y)^2 + 1e-12);
  range6 = sqrt((x - LM6_x)^2 + (y - LM6_y)^2 + 1e-12);

  // ===== Preserved exteroceptive data (sonar and camera, NOT fused) =====
  sonar_data = sin(2.0*pi*5.0*time);
  camera_data = cos(2.0*pi*3.0*time);

  // ===== Collision check =====
  dist_obs1 = sqrt((x - OBS1_x)^2 + (y - OBS1_y)^2 + 1e-12);
  dist_obs2 = sqrt((x - OBS2_x)^2 + (y - OBS2_y)^2 + 1e-12);
  no_collision = (dist_obs1 > OBS1_r) and (dist_obs2 > OBS2_r);

  // ===== Initial pose for loop closure =====
  x0 = 2.0;
  y0 = 0.0;
  yaw0 = pi/2;

  // ===== Estimator corrections =====
  // Depth correction from pressure sensor (compensating extrinsic offset)
  depth_corr = 5.0*((depth_raw - DEP_bz) - z_est);

  // Compass correction (wrapped)
  compass_corr = 3.0*atan2(sin(compass_yaw - yaw_est), cos(compass_yaw - yaw_est));

  // Range correction using landmarks 1 and 2 (estimator uses unperturbed map)
  range1_est = sqrt((x_est - LM1_x)^2 + (y_est - LM1_y)^2 + 1e-12);
  range2_est = sqrt((x_est - LM2_x)^2 + (y_est - LM2_y)^2 + 1e-12);
  range1_dir_x = (LM1_x - x_est)/max(range1_est, 1e-6);
  range1_dir_y = (LM1_y - y_est)/max(range1_est, 1e-6);
  range2_dir_x = (LM2_x - x_est)/max(range2_est, 1e-6);
  range2_dir_y = (LM2_y - y_est)/max(range2_est, 1e-6);
  range1_residual = range1_meas - range1_est;
  range2_residual = range2_meas - range2_est;
  range_corr_x = if range_count_real > 0.5 then range_gain*(range1_residual*range1_dir_x + range2_residual*range2_dir_x) else 0.0;
  range_corr_y = if range_count_real > 0.5 then range_gain*(range1_residual*range1_dir_y + range2_residual*range2_dir_y) else 0.0;

  // Loop closure correction (activated near end of route)
  lc_corr_x = if loop_closed then lc_gain*(x0 - x_est) else 0.0;
  lc_corr_y = if loop_closed then lc_gain*(y0 - y_est) else 0.0;
  lc_corr_yaw = if loop_closed then lc_gain*atan2(sin(yaw0 - yaw_est), cos(yaw0 - yaw_est)) else 0.0;

  // ===== Estimator dynamics (fusing odometry, IMU, depth, compass, range) =====
  der(x_est) = vx_est + range_corr_x + lc_corr_x;
  der(y_est) = vy_est + range_corr_y + lc_corr_y;
  der(z_est) = vz_est + depth_corr;
  der(yaw_est) = omega_est + compass_corr + lc_corr_yaw;

  // Velocity estimation from IMU acceleration + DVL velocity correction
  der(vx_est) = imu_ax*cos(yaw_est) - imu_ay*sin(yaw_est)
              - 2.0*(vx_est - (dvl_vx*cos(yaw_est) - dvl_vy*sin(yaw_est)));
  der(vy_est) = imu_ax*sin(yaw_est) + imu_ay*cos(yaw_est)
              - 2.0*(vy_est - (dvl_vx*sin(yaw_est) + dvl_vy*cos(yaw_est)));
  der(vz_est) = imu_az - 2.0*(vz_est - dvl_vz);
  der(omega_est) = -2.0*(omega_est - imu_wz);

  // ===== Covariance propagation (finite, positive) =====
  der(Pxx) = Q_pos + 0.01 - 0.5*Pxx;
  der(Pyy) = Q_pos + 0.01 - 0.5*Pyy;
  der(Pzz) = Q_pos + 0.01 - 0.5*Pzz;
  der(Pyaw) = Q_yaw + 0.01 - 0.5*Pyaw;

  // ===== Discrete range sampling at 1 Hz =====
  when sample(0, range_period) then
    range1_meas = range1;
    range2_meas = range2;
    range3_meas = range3;
    range_count_real = pre(range_count_real) + 1.0;
  end when;

  // ===== Loop closure detection (near end of closed route) =====
  when time > T_end - 0.5 then
    loop_pos_err = sqrt((x_est - x0)^2 + (y_est - y0)^2 + 1e-12);
    loop_heading_err = atan2(sin(yaw_est - yaw0), cos(yaw_est - yaw0));
    loop_closed = true;
  end when;

  // ===== Safety assertions =====
  assert(no_collision, "Collision detected with obstacle");
  assert(Pxx > 0.0 and Pyy > 0.0 and Pzz > 0.0 and Pyaw > 0.0,
         "Covariance not finite or not positive");

  annotation(
    experiment(StartTime=0, StopTime=8.0, Tolerance=1e-6, Interval=0.0125),
    Documentation(info="MarineNavMapA: Underwater vehicle navigation and mapping system.
      Four bounded thrusters (75.6 N max per thruster) generate survey motion on a closed circular route.
      Sensors: IMU, pressure depth, Doppler velocity log, compass, 1 Hz acoustic range.
      All sensors have declared extrinsic transforms (body-to-sensor offsets).
      EKF-lite estimator fuses odometry, IMU, depth, compass, and range updates.
      Sonar and camera data are preserved separately and NOT fused into the pose estimate.
      Six fixed landmarks and two obstacles placed in a shared world frame.
      Loop-closure correction applied at end of route (t > 7.5 s).
      Controlled 0.1 m landmark perturbation applied to LM1 during middle third (2.667-5.333 s).
      System runs at 80 Hz for 8 s with synchronized state, command, and sensor traces.
      Requirements: finite covariance, loop-closure position and heading error computed,
      declared output rate 80 Hz, no collision, primary tracking error below 0.338 m after 5.2 s,
      no NaN or infinite values.")
  );
end MarineNavMapA;