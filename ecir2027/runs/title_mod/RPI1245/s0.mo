model MapRigMapC
  import Modelica.Constants.pi;

  // =================== Parameters ===================
  // Mobile base
  parameter Real m_base     = 22.0  "base mass [kg]";
  parameter Real r_wheel   = 0.10  "wheel radius [m]";
  parameter Real d_wheel    = 0.40  "wheel track width [m]";
  parameter Real I_base     = 0.50  "base yaw inertia [kg.m2]";
  parameter Real drag_lin   = 2.0   "linear viscous drag [N.s/m]";
  parameter Real drag_ang   = 0.5   "angular viscous drag [N.m.s/rad]";
  parameter Real robot_r    = 0.25  "robot collision radius [m]";
  parameter Real tau_max    = 11.0  "max wheel torque magnitude [N.m]";

  // Route (closed circle, single loop in 12 s)
  parameter Real R_route    = 2.0   "route radius [m]";
  parameter Real T_route    = 12.0  "route period [s]";
  parameter Real v_ref      = 2.0*pi*R_route/T_route  "reference linear speed [m/s]";
  parameter Real omega_ref  = 2.0*pi/T_route          "reference angular speed [rad/s]";

  // Landmark perturbation disturbance (middle third of run)
  parameter Real perturb    = 0.18  "landmark perturbation magnitude [m]";

  // Six fixed landmarks (shared world frame) on radius 2 m circle
  parameter Real L1x = 2.0;  parameter Real L1y = 0.0;
  parameter Real L2x = 1.0;  parameter Real L2y = 1.7320508;
  parameter Real L3x = -1.0; parameter Real L3y = 1.7320508;
  parameter Real L4x = -2.0; parameter Real L4y = 0.0;
  parameter Real L5x = -1.0; parameter Real L5y = -1.7320508;
  parameter Real L6x = 1.0;  parameter Real L6y = -1.7320508;

  // Two obstacles in shared world frame
  parameter Real O1x = 0.0; parameter Real O1y = 0.0; parameter Real O1r = 0.50;
  parameter Real O2x = 4.0; parameter Real O2y = 0.0; parameter Real O2r = 0.50;

  // Sensor rates (explicitly different)
  parameter Real dt_enc   = 0.008  "wheel encoder period (125 Hz) [s]";
  parameter Real dt_imu   = 0.005  "IMU period (200 Hz) [s]";
  parameter Real dt_lidar = 0.040  "planar lidar period (25 Hz) [s]";
  parameter Real dt_cam   = 0.0333 "RGB-D camera period (30 Hz) [s]";
  parameter Real dt_sonar = 0.100  "sonar period (10 Hz) [s]";
  parameter Real dt_out   = 0.008  "declared fused output rate (125 Hz) [s]";
  parameter Integer output_rate_Hz = 125 "declared output rate [Hz]";

  // Sensor transforms (relative to base frame)
  parameter Real tf_imu_x  = 0.15; parameter Real tf_imu_y  = 0.0;
  parameter Real tf_lidar_x= 0.10; parameter Real tf_lidar_y= 0.0;
  parameter Real tf_cam_x  = 0.20; parameter Real tf_cam_y  = 0.0;
  parameter Real tf_enc_L_x= -0.05; parameter Real tf_enc_L_y= 0.20;
  parameter Real tf_enc_R_x= -0.05; parameter Real tf_enc_R_y= -0.20;

  // Lidar range limit (20 m planar)
  parameter Real lidar_max = 20.0;

  // Controller gains
  parameter Real kp_long = 2.0;
  parameter Real kp_lat  = 3.0;
  parameter Real kp_th   = 4.0;
  parameter Real kp_v    = 4.0;
  parameter Real kp_om   = 4.0;

  // Estimator gains
  parameter Real k_odom_v  = 2.0;
  parameter Real k_odom_w  = 2.0;
  parameter Real k_range   = 0.05;
  parameter Real k_lc      = 0.5;
  parameter Real Q_pos     = 1.0e-4;
  parameter Real Q_vel     = 1.0e-4;
  parameter Real decay     = 0.01;

  // =================== Plant state ===================
  Real x(start=2.0,      fixed=true) "robot x position [m]";
  Real y(start=0.0,      fixed=true) "robot y position [m]";
  Real theta(start=pi/2, fixed=true) "robot heading [rad]";
  Real v(start=0.0,      fixed=true) "linear velocity [m/s]";
  Real omega(start=0.0,  fixed=true) "angular velocity [rad/s]";

  // Wheel torques (command, bounded, actual)
  Real tau_L_raw, tau_R_raw;
  Real tau_L, tau_R;

  // =================== Reference trajectory ===================
  Real x_ref, y_ref, theta_ref;
  Real e_long, e_lat, e_th;
  Real v_cmd, omega_cmd;
  Real F_des, T_des;

  // =================== Estimator state ===================
  Real x_hat(start=2.0,      fixed=true);
  Real y_hat(start=0.0,      fixed=true);
  Real theta_hat(start=pi/2, fixed=true);
  Real v_hat(start=0.0,      fixed=true);
  Real omega_hat(start=0.0,  fixed=true);

  // Finite diagonal covariance (scalar, explicit)
  Real Pxx(start=0.01, fixed=true);
  Real Pyy(start=0.01, fixed=true);
  Real Ptt(start=0.01, fixed=true);
  Real Pvv(start=0.01, fixed=true);
  Real Pww(start=0.01, fixed=true);

  // Loop-closure error and tracking error
  Real loop_pos_err, loop_head_err;
  Real track_err;
  Real no_collision;

  // Loop closure reference pose (start of closed route)
  constant Real x_start = 2.0;
  constant Real y_start = 0.0;
  constant Real theta_start = pi/2;
  Real lc_active;

  // =================== Sensors (discrete traces) ===================
  discrete Real enc_v(start=0.0, fixed=true);
  discrete Real enc_omega(start=0.0, fixed=true);
  discrete Real imu_omega(start=0.0, fixed=true);
  discrete Real imu_ax(start=0.0, fixed=true);
  discrete Real imu_ay(start=0.0, fixed=true);
  discrete Real lidar1(start=0.0, fixed=true);
  discrete Real lidar2(start=0.0, fixed=true);
  discrete Real lidar3(start=0.0, fixed=true);
  discrete Real lidar4(start=0.0, fixed=true);
  discrete Real lidar5(start=0.0, fixed=true);
  discrete Real lidar6(start=0.0, fixed=true);
  discrete Real cam_depth(start=0.0, fixed=true)   "RGB-D observation, retained separately, not fused";
  discrete Real sonar_range(start=0.0, fixed=true) "Sonar observation, retained separately, not fused";

  // Synchronized output trace variables
  discrete Real out_x(start=2.0, fixed=true);
  discrete Real out_y(start=0.0, fixed=true);
  discrete Real out_th(start=pi/2, fixed=true);
  discrete Real out_cmd_L(start=0.0, fixed=true);
  discrete Real out_cmd_R(start=0.0, fixed=true);
  discrete Real out_track_err(start=0.0, fixed=true);

  // =================== Perturbation ===================
  Boolean perturb_active;
  Real perturb_offset;

  // =================== Lidar range residuals ===================
  Real L1ox, L2ox, L3ox, L4ox, L5ox, L6ox;
  Real r1obs, r2obs, r3obs, r4obs, r5obs, r6obs;
  Real r1hat, r2hat, r3hat, r4hat, r5hat, r6hat;
  Real res1, res2, res3, res4, res5, res6;
  Real bx1, by1, bx2, by2, bx3, by3, bx4, by4, bx5, by5, bx6, by6;
  Real cx1, cy1, cx2, cy2, cx3, cy3, cx4, cy4, cx5, cy5, cx6, cy6;
  Real corr_x_total, corr_y_total;

  // IMU-transformed acceleration (forward/lateral at IMU mount)
  Real imu_ax_body, imu_ay_body;

equation
  // ============ Reference closed route ============
  x_ref     = R_route*cos(2.0*pi*time/T_route);
  y_ref     = R_route*sin(2.0*pi*time/T_route);
  theta_ref = 2.0*pi*time/T_route + pi/2;

  // ============ Plant dynamics (differential drive) ============
  der(x)     = v*cos(theta);
  der(y)     = v*sin(theta);
  der(theta) = omega;
  m_base*der(v)     = (tau_L + tau_R)/r_wheel - drag_lin*v;
  I_base*der(omega) = (tau_R - tau_L)*d_wheel/(2.0*r_wheel) - drag_ang*omega;

  // ============ Body-frame tracking errors ============
  e_long = (x_ref - x)*cos(theta) + (y_ref - y)*sin(theta);
  e_lat  = -(x_ref - x)*sin(theta) + (y_ref - y)*cos(theta);
  e_th   = theta_ref - theta;

  // ============ Bounded wheel torque commands ============
  v_cmd     = v_ref     + kp_long*e_long;
  omega_cmd = omega_ref + kp_lat*e_lat + kp_th*e_th;
  F_des = m_base*kp_v*(v_cmd - v);
  T_des = I_base*kp_om*(omega_cmd - omega);
  tau_L_raw = r_wheel/2.0*(F_des - 2.0*T_des/d_wheel);
  tau_R_raw = r_wheel/2.0*(F_des + 2.0*T_des/d_wheel);
  tau_L = if tau_L_raw >  tau_max then  tau_max
          else if tau_L_raw < -tau_max then -tau_max
          else tau_L_raw;
  tau_R = if tau_R_raw >  tau_max then  tau_max
          else if tau_R_raw < -tau_max then -tau_max
          else tau_R_raw;

  // ============ Perturbation (middle third: 4 s < t < 8 s) ============
  perturb_active = (time > T_route/3.0) and (time < 2.0*T_route/3.0);
  perturb_offset = if perturb_active then perturb else 0.0;

  // ============ Observed landmark positions (world frame, with perturbation) ============
  L1ox = L1x + perturb_offset;
  L2ox = L2x + perturb_offset;
  L3ox = L3x + perturb_offset;
  L4ox = L4x + perturb_offset;
  L5ox = L5x + perturb_offset;
  L6ox = L6x + perturb_offset;

  // ============ Range observations (truth, capped at 20 m) ============
  r1obs = if sqrt((x-L1ox)^2 + (y-L1y)^2 + 1.0e-9) > lidar_max then lidar_max
          else sqrt((x-L1ox)^2 + (y-L1y)^2 + 1.0e-9);
  r2obs = if sqrt((x-L2ox)^2 + (y-L2y)^2 + 1.0e-9) > lidar_max then lidar_max
          else sqrt((x-L2ox)^2 + (y-L2y)^2 + 1.0e-9);
  r3obs = if sqrt((x-L3ox)^2 + (y-L3y)^2 + 1.0e-9) > lidar_max then lidar_max
          else sqrt((x-L3ox)^2 + (y-L3y)^2 + 1.0e-9);
  r4obs = if sqrt((x-L4ox)^2 + (y-L4y)^2 + 1.0e-9) > lidar_max then lidar_max
          else sqrt((x-L4ox)^2 + (y-L4y)^2 + 1.0e-9);
  r5obs = if sqrt((x-L5ox)^2 + (y-L5y)^2 + 1.0e-9) > lidar_max then lidar_max
          else sqrt((x-L5ox)^2 + (y-L5y)^2 + 1.0e-9);
  r6obs = if sqrt((x-L6ox)^2 + (y-L6y)^2 + 1.0e-9) > lidar_max then lidar_max
          else sqrt((x-L6ox)^2 + (y-L6y)^2 + 1.0e-9);

  // ============ Range residuals w.r.t. estimate ============
  r1hat = sqrt((x_hat-L1ox)^2 + (y_hat-L1y)^2 + 1.0e-9);
  r2hat = sqrt((x_hat-L2ox)^2 + (y_hat-L2y)^2 + 1.0e-9);
  r3hat = sqrt((x_hat-L3ox)^2 + (y_hat-L3y)^2 + 1.0e-9);
  r4hat = sqrt((x_hat-L4ox)^2 + (y_hat-L4y)^2 + 1.0e-9);
  r5hat = sqrt((x_hat-L5ox)^2 + (y_hat-L5y)^2 + 1.0e-9);
  r6hat = sqrt((x_hat-L6ox)^2 + (y_hat-L6y)^2 + 1.0e-9);
  res1 = r1obs - r1hat;
  res2 = r2obs - r2hat;
  res3 = r3obs - r3hat;
  res4 = r4obs - r4hat;
  res5 = r5obs - r5hat;
  res6 = r6obs - r6hat;
  bx1 = (x_hat - L1ox)/r1hat; by1 = (y_hat - L1y)/r1hat;
  bx2 = (x_hat - L2ox)/r2hat; by2 = (y_hat - L2y)/r2hat;
  bx3 = (x_hat - L3ox)/r3hat; by3 = (y_hat - L3y)/r3hat;
  bx4 = (x_hat - L4ox)/r4hat; by4 = (y_hat - L4y)/r4hat;
  bx5 = (x_hat - L5ox)/r5hat; by5 = (y_hat - L5y)/r5hat;
  bx6 = (x_hat - L6ox)/r6hat; by6 = (y_hat - L6y)/r6hat;
  cx1 = k_range*bx1*res1; cy1 = k_range*by1*res1;
  cx2 = k_range*bx2*res2; cy2 = k_range*by2*res2;
  cx3 = k_range*bx3*res3; cy3 = k_range*by3*res3;
  cx4 = k_range*bx4*res4; cy4 = k_range*by4*res4;
  cx5 = k_range*bx5*res5; cy5 = k_range*by5*res5;
  cx6 = k_range*bx6*res6; cy6 = k_range*by6*res6;
  corr_x_total = cx1 + cx2 + cx3 + cx4 + cx5 + cx6;
  corr_y_total = cy1 + cy2 + cy3 + cy4 + cy5 + cy6;

  // ============ IMU body-frame accelerations at IMU transform ============
  imu_ax_body = (tau_L + tau_R)/r_wheel/m_base - drag_lin*v/m_base
                - tf_imu_x*omega^2;
  imu_ay_body = v*omega + tf_imu_x*der(omega);

  // ============ Estimator: odometry + IMU propagation ============
  der(x_hat)     = v_hat*cos(theta_hat) + lc_active*k_lc*(x_start - x_hat);
  der(y_hat)     = v_hat*sin(theta_hat) + lc_active*k_lc*(y_start - y_hat);
  der(theta_hat) = omega_hat             + lc_active*k_lc*(theta_start - theta_hat);
  der(v_hat)     = k_odom_v*(enc_v - v_hat);
  der(omega_hat) = k_odom_w*(imu_omega - omega_hat);

  // Loop closure activates in final 2 s of the closed route
  lc_active = if time > 10.0 then 1.0 else 0.0;

  // ============ Finite covariance evolution ============
  der(Pxx) = Q_pos - decay*Pxx;
  der(Pyy) = Q_pos - decay*Pyy;
  der(Ptt) = Q_pos - decay*Ptt;
  der(Pvv) = Q_vel - decay*Pvv;
  der(Pww) = Q_vel - decay*Pww;

  // ============ Loop-closure error metrics ============
  loop_pos_err  = sqrt((x_hat - x_start)^2 + (y_hat - y_start)^2 + 1.0e-9);
  loop_head_err = theta_hat - theta_start;

  // ============ Tracking error and collision check ============
  track_err = sqrt((x - x_ref)^2 + (y - y_ref)^2 + 1.0e-9);
  no_collision =
    if (sqrt((x - O1x)^2 + (y - O1y)^2 + 1.0e-9) > robot_r + O1r)
       and (sqrt((x - O2x)^2 + (y - O2y)^2 + 1.0e-9) > robot_r + O2r)
    then 1.0 else 0.0;

  // ============ Sensor sampling (explicit different rates) ============
  when sample(0, dt_enc) then
    enc_v     = v;
    enc_omega = omega;
  end when;

  when sample(0, dt_imu) then
    imu_omega = omega;
    imu_ax    = imu_ax_body;
    imu_ay    = imu_ay_body;
  end when;

  when sample(0, dt_lidar) then
    lidar1 = r1obs;
    lidar2 = r2obs;
    lidar3 = r3obs;
    lidar4 = r4obs;
    lidar5 = r5obs;
    lidar6 = r6obs;
    reinit(x_hat, x_hat + corr_x_total);
    reinit(y_hat, y_hat + corr_y_total);
    reinit(Pxx, 0.9*Pxx);
    reinit(Pyy, 0.9*Pyy);
  end when;

  when sample(0, dt_cam) then
    // Forward RGB-D camera observation retained separately, not fused into pose filter
    cam_depth = min(lidar_max, sqrt((x - O2x)^2 + (y - O2y)^2 + 1.0e-9));
  end when;

  when sample(0, dt_sonar) then
    // Sonar observation retained separately, not fused into pose filter
    sonar_range = min(5.0, sqrt((x - O1x)^2 + (y - O1y)^2 + 1.0e-9));
  end when;

  // ============ Synchronized output trace at declared rate (125 Hz) ============
  when sample(0, dt_out) then
    out_x         = x;
    out_y         = y;
    out_th        = theta;
    out_cmd_L     = tau_L;
    out_cmd_R     = tau_R;
    out_track_err = track_err;
  end when;

  annotation (
    Documentation(info="MapRigMapC: 22 kg differential-drive mobile base traversing a closed circular route (R=2 m, T=12 s). Wheel torque bounded to +-11 N.m. Six fixed landmarks and two obstacles share a world frame. A 0.18 m landmark perturbation is injected during the middle third (4-8 s). Wheel encoders (125 Hz), IMU (200 Hz), 20 m planar lidar (25 Hz) are fused into a pose filter with finite diagonal covariance; forward RGB-D camera (30 Hz) and sonar (10 Hz) observations are retained separately. Loop-closure correction activates after t=10 s. Declared output rate: 125 Hz. Sensor transforms are explicit parameters."),
    experiment(StopTime=12.0, Tolerance=1.0e-6, Interval=0.008));
end MapRigMapC;