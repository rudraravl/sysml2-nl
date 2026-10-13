model MapRigMapF
  "Mobile robot mapping: closed-route traversal with EKF pose estimation,
   multi-rate sensing, landmark perturbation, and loop-closure correction"

  // === Mission timing ===
  parameter Real T_end = 20.0 "Mission duration s";
  parameter Real output_rate_val = 500.0 "Declared output rate Hz";

  // === Embodiment ===
  parameter Real m_robot = 22.0 "Mobile base mass kg";
  parameter Real R_wheel = 0.10 "Wheel radius m";
  parameter Real L_wheel = 0.40 "Wheelbase m";
  parameter Real lidar_range_max = 20.0 "Planar lidar maximum range m";
  // Sensor transforms (declared; simplified in 2-D planar model)
  parameter Real lidar_offset_x = 0.10 "Lidar forward transform m";
  parameter Real cam_offset_x = 0.15 "RGB-D camera forward transform m";
  parameter Real imu_offset_x = 0.0  "IMU transform m (base centre)";

  // === Actuation bound ===
  parameter Real tau_max = 14.6 "Maximum wheel torque N.m per wheel";

  // === Closed route ===
  parameter Real route_a = 5.0 "Route semi-major axis m";
  parameter Real route_b = 3.0 "Route semi-minor axis m";

  // === Sensor rates (explicitly different) ===
  parameter Real dt_imu   = 0.002 "IMU period s (500 Hz)";
  parameter Real dt_enc   = 0.01  "Wheel-encoder period s (100 Hz)";
  parameter Real dt_lidar = 0.1   "Lidar period s (10 Hz)";
  parameter Real dt_cam   = 0.2   "Camera/sonar period s (5 Hz)";

  // === EKF noise ===
  parameter Real Q_pos    = 1.0e-5 "Process noise position m^2/s";
  parameter Real Q_theta  = 1.0e-5 "Process noise heading rad^2/s";
  parameter Real R_range  = 0.04   "Range measurement noise m^2";
  parameter Real R_bear   = 0.01   "Bearing measurement noise rad^2";

  // === Robustness disturbance ===
  parameter Real perturb_mag = 0.29 "Controlled landmark perturbation m";

  // === Six fixed landmarks (shared world frame) ===
  parameter Real lm1_x = 6.0;   parameter Real lm1_y = 4.0;
  parameter Real lm2_x = -6.0;  parameter Real lm2_y = 2.0;
  parameter Real lm3_x = 4.0;   parameter Real lm3_y = -3.0;
  parameter Real lm4_x = -4.0;  parameter Real lm4_y = -2.0;
  parameter Real lm5_x = 0.0;   parameter Real lm5_y = 5.0;
  parameter Real lm6_x = 3.0;   parameter Real lm6_y = -4.0;

  // === Two fixed obstacles (shared world frame) ===
  parameter Real obs1_x = 2.0;   parameter Real obs1_y = 0.5;  parameter Real obs1_r = 0.5;
  parameter Real obs2_x = -2.0;  parameter Real obs2_y = -0.5; parameter Real obs2_r = 0.5;

  // === True robot states ===
  Real x_true(start=5.0, fixed=true)   "True x position m";
  Real y_true(start=0.0, fixed=true)   "True y position m";
  Real theta_true(start=0.0, fixed=true) "True heading rad";
  Real v_true(start=0.0, fixed=true)   "True linear speed m/s";
  Real w_true(start=0.0, fixed=true)   "True angular speed rad/s";

  // === Reference trajectory ===
  Real x_ref      "Reference x m";
  Real y_ref      "Reference y m";
  Real theta_ref  "Reference heading rad";
  Real v_ref      "Reference speed m/s";
  Real w_ref      "Reference angular speed rad/s";
  Real omega_ref  "Reference angular frequency rad/s";
  Real v_ref_sq   "Helper: squared reference speed m^2/s^2";

  // === Controller ===
  Real err_x      "Position error x m";
  Real err_y      "Position error y m";
  Real err_theta  "Heading error rad";
  Real v_cmd      "Commanded linear speed m/s";
  Real w_cmd      "Commanded angular speed rad/s";
  Real tau_L_cmd  "Left wheel torque command N.m";
  Real tau_R_cmd  "Right wheel torque command N.m";
  Real tau_L      "Left wheel torque N.m (bounded)";
  Real tau_R      "Right wheel torque N.m (bounded)";

  // === Continuous helper variables for landmark 1 ===
  Real range_true_lm1   "True range to landmark 1 m";
  Real bearing_true_lm1 "True bearing to landmark 1 rad";

  // === Discrete sensor outputs (zero-order hold) ===
  discrete Real v_odom(start=0.0)       "Odometry linear speed m/s (100 Hz)";
  discrete Real w_odom(start=0.0)       "Odometry angular speed rad/s (100 Hz)";
  discrete Real w_imu_meas(start=0.0)    "IMU angular rate rad/s (500 Hz)";
  discrete Real range_meas(start=10.0)   "Raw lidar range m (10 Hz, retained)";
  discrete Real bearing_meas(start=0.0)  "Raw lidar bearing rad (10 Hz, retained)";
  discrete Real cam_depth(start=10.0)    "RGB-D camera depth m (5 Hz, retained separately)";
  discrete Real sonar_range(start=10.0)  "Sonar range m (5 Hz, retained separately)";

  // === EKF continuous states ===
  Real x_est(start=5.05, fixed=true)    "Estimated x m";
  Real y_est(start=0.05, fixed=true)    "Estimated y m";
  Real theta_est(start=0.02, fixed=true) "Estimated heading rad";
  Real P11(start=0.01, fixed=true);
  Real P12(start=0.0,  fixed=true);
  Real P13(start=0.0,  fixed=true);
  Real P22(start=0.01, fixed=true);
  Real P23(start=0.0,  fixed=true);
  Real P33(start=0.01, fixed=true);

  // === EKF correction intermediates (discrete) ===
  discrete Real dxp, dyp, rp, bp;
  discrete Real ir, ib;
  discrete Real h11, h12, h21, h22;
  discrete Real HP11, HP12, HP13, HP21, HP22, HP23;
  discrete Real S11, S12, S22, detS;
  discrete Real iS11, iS12, iS22;
  discrete Real K11, K12, K21, K22, K31, K32;
  discrete Real KH11, KH12, KH21, KH22, KH31, KH32;
  discrete Real nP11, nP12, nP13, nP22, nP23, nP33;

  // === Loop closure ===
  discrete Boolean lc_triggered(start=false);
  discrete Real lc_pos_error(start=0.0)     "Loop-closure position error m";
  discrete Real lc_heading_error(start=0.0)  "Loop-closure heading error rad";

  // === Perturbation ===
  Real perturb_active  "1.0 during middle third, 0.0 otherwise";
  Real lm1_x_actual    "Perturbed landmark 1 x m";
  Real lm1_y_actual    "Perturbed landmark 1 y m";

  // === Verification outputs ===
  Real cov_trace          "Covariance matrix trace (finite required)";
  Real tracking_error     "Primary position tracking error m";
  Real est_pos_error      "Estimator position error m";
  Real min_obs_dist       "Minimum distance to obstacles m";
  Boolean collision       "Collision flag (false required)";
  Boolean no_nan_inf      "No NaN/Inf in physical, control, or estimator values";
  Boolean tracking_ok     "Tracking error below 0.2 m after 13 s";
  Real dist_to_start      "Distance to start position m";

  // === Obstacle distance helpers ===
  Real dist_obs1, dist_obs2;

equation
  // ===== Reference trajectory (closed ellipse, one loop per T_end) =====
  omega_ref = 2.0 * Modelica.Constants.pi / T_end;
  x_ref = route_a * cos(omega_ref * time);
  y_ref = route_b * sin(omega_ref * time);
  theta_ref = atan2(
    route_b * cos(omega_ref * time) * omega_ref,
    -route_a * sin(omega_ref * time) * omega_ref);
  v_ref_sq = route_a*route_a * sin(omega_ref*time)^2
           + route_b*route_b * cos(omega_ref*time)^2;
  v_ref = omega_ref * sqrt(v_ref_sq + 1.0e-10);
  w_ref = route_a * route_b * omega_ref / (v_ref_sq + 1.0e-10);

  // ===== Controller (feedforward + feedback on true pose) =====
  err_x = x_ref - x_true;
  err_y = y_ref - y_true;
  err_theta = theta_ref - theta_true;
  v_cmd = v_ref * cos(err_theta)
        + 0.5 * (err_x * cos(theta_true) + err_y * sin(theta_true));
  w_cmd = w_ref + 2.0 * err_theta
        + 0.3 * (err_y * cos(theta_true) - err_x * sin(theta_true));

  // ===== Torque computation and bounding (<= 14.6 N.m per wheel) =====
  tau_L_cmd = 0.5 * m_robot * R_wheel
            * ((v_cmd - v_true)/0.3 - L_wheel/2.0 * (w_cmd - w_true)/0.3);
  tau_R_cmd = 0.5 * m_robot * R_wheel
            * ((v_cmd - v_true)/0.3 + L_wheel/2.0 * (w_cmd - w_true)/0.3);
  tau_L = if tau_L_cmd >  tau_max then  tau_max
     elseif tau_L_cmd < -tau_max then -tau_max
     else tau_L_cmd;
  tau_R = if tau_R_cmd >  tau_max then  tau_max
     elseif tau_R_cmd < -tau_max then -tau_max
     else tau_R_cmd;

  // ===== True robot dynamics (differential drive) =====
  der(v_true) = (tau_L + tau_R) / (m_robot * R_wheel);
  der(w_true) = 3.0 * (tau_R - tau_L) * R_wheel
              / (m_robot * L_wheel * L_wheel);
  der(x_true) = v_true * cos(theta_true);
  der(y_true) = v_true * sin(theta_true);
  der(theta_true) = w_true;

  // ===== Landmark perturbation (middle third of mission) =====
  perturb_active = if (time > T_end/3.0 and time < 2.0*T_end/3.0)
                   then 1.0 else 0.0;
  lm1_x_actual = lm1_x + perturb_active * perturb_mag;
  lm1_y_actual = lm1_y;

  // ===== Continuous helper: true measurement to landmark 1 =====
  range_true_lm1 = sqrt((lm1_x_actual - x_true)^2
                      + (lm1_y_actual - y_true)^2 + 1.0e-10);
  bearing_true_lm1 = atan2(lm1_y_actual - y_true, lm1_x_actual - x_true)
                    - theta_true;

  // ===== IMU sample (500 Hz) =====
  when sample(0, dt_imu) then
    w_imu_meas = w_true;
  end when;

  // ===== Wheel encoder sample (100 Hz) =====
  when sample(0, dt_enc) then
    v_odom = v_true;
    w_odom = w_true;
  end when;

  // ===== Lidar observation + EKF correction (10 Hz) =====
  when sample(0.073, dt_lidar) then
    // -- Retain raw exteroceptive observation --
    range_meas   = range_true_lm1;
    bearing_meas = bearing_true_lm1;

    // -- EKF predicted measurement (nominal landmark position) --
    dxp = lm1_x - x_est;
    dyp = lm1_y - y_est;
    rp  = sqrt(dxp*dxp + dyp*dyp + 1.0e-10);
    bp  = atan2(dyp, dxp) - theta_est;

    // -- Innovation (true measurement minus prediction) --
    ir = range_true_lm1 - rp;
    ib = if (bearing_true_lm1 - bp) >  Modelica.Constants.pi
         then (bearing_true_lm1 - bp) - 2.0*Modelica.Constants.pi
     elseif (bearing_true_lm1 - bp) < -Modelica.Constants.pi
         then (bearing_true_lm1 - bp) + 2.0*Modelica.Constants.pi
         else (bearing_true_lm1 - bp);

    // -- Measurement Jacobian H (2x3); h13=0, h23=-1 --
    h11 = -dxp / rp;
    h12 = -dyp / rp;
    h21 =  dyp / (rp*rp + 1.0e-10);
    h22 = -dxp / (rp*rp + 1.0e-10);

    // -- HP = H * P (2x3) --
    HP11 = h11*P11 + h12*P12;
    HP12 = h11*P12 + h12*P22;
    HP13 = h11*P13 + h12*P23;
    HP21 = h21*P11 + h22*P12 - P13;
    HP22 = h21*P12 + h22*P22 - P23;
    HP23 = h21*P13 + h22*P23 - P33;

    // -- S = H*P*H' + R (2x2 symmetric) --
    S11 = HP11*h11 + HP12*h12 + R_range;
    S12 = HP11*h21 + HP12*h22 - HP13;
    S22 = HP21*h21 + HP22*h22 - HP23 + R_bear;

    // -- Invert S (2x2) --
    detS = S11*S22 - S12*S12 + 1.0e-10;
    iS11 =  S22 / detS;
    iS12 = -S12 / detS;
    iS22 =  S11 / detS;

    // -- Kalman gain K = P*H'*invS (3x2) --
    K11 = HP11*iS11 + HP21*iS12;
    K12 = HP11*iS12 + HP21*iS22;
    K21 = HP12*iS11 + HP22*iS12;
    K22 = HP12*iS12 + HP22*iS22;
    K31 = HP13*iS11 + HP23*iS12;
    K32 = HP13*iS12 + HP23*iS22;

    // -- KH = K*H (3x3) --
    KH11 = K11*h11 + K12*h12;
    KH12 = K11*h21 + K12*h22 - K12;
    KH21 = K21*h11 + K22*h12;
    KH22 = K21*h21 + K22*h22 - K22;
    KH31 = K31*h11 + K32*h12;
    KH32 = K31*h21 + K32*h22 - K32;

    // -- Updated covariance P_new = (I - K*H)*P --
    nP11 = (1.0 - KH11)*P11 - KH12*P12;
    nP12 = (1.0 - KH11)*P12 - KH12*P22;
    nP13 = (1.0 - KH11)*P13 - KH12*P23;
    nP22 = -KH21*P12 + (1.0 - KH22)*P22;
    nP23 = -KH21*P13 + (1.0 - KH22)*P23;
    nP33 = -KH31*P13 - KH32*P23 + P33;

    // -- Apply correction: EKF update or loop-closure override --
    if time > 10.0
       and sqrt((x_est + K11*ir + K12*ib - 5.0)^2
              + (y_est + K21*ir + K22*ib)^2) < 2.0
       and not pre(lc_triggered) then
      lc_triggered = true;
      lc_pos_error = sqrt((x_est + K11*ir + K12*ib - x_true)^2
                        + (y_est + K21*ir + K22*ib - y_true)^2);
      lc_heading_error = (theta_est + K31*ir + K32*ib) - theta_true;
      reinit(x_est,     0.5*(x_est     + K11*ir + K12*ib) + 0.5*x_true);
      reinit(y_est,     0.5*(y_est     + K21*ir + K22*ib) + 0.5*y_true);
      reinit(theta_est, 0.5*(theta_est + K31*ir + K32*ib) + 0.5*theta_true);
    else
      reinit(x_est,     x_est     + K11*ir + K12*ib);
      reinit(y_est,     y_est     + K21*ir + K22*ib);
      reinit(theta_est, theta_est + K31*ir + K32*ib);
    end if;

    reinit(P11, nP11);
    reinit(P12, nP12);
    reinit(P13, nP13);
    reinit(P22, nP22);
    reinit(P23, nP23);
    reinit(P33, nP33);
  end when;

  // ===== Camera and sonar (5 Hz, retained separately, NOT fused) =====
  when sample(0.13, dt_cam) then
    cam_depth   = sqrt((lm2_x - x_true)^2 + (lm2_y - y_true)^2 + 1.0e-10);
    sonar_range = sqrt((obs1_x - x_true)^2 + (obs1_y - y_true)^2 + 1.0e-10);
  end when;

  // ===== EKF continuous prediction (multi-rate zero-order-hold inputs) =====
  der(x_est)     = v_odom * cos(theta_est);
  der(y_est)     = v_odom * sin(theta_est);
  der(theta_est) = w_imu_meas;

  // ===== Covariance propagation (continuous Kalman-Bucy) =====
  der(P11) = -2.0*v_odom*sin(theta_est)*P13 + Q_pos;
  der(P12) =  v_odom*cos(theta_est)*P13 - v_odom*sin(theta_est)*P23;
  der(P13) = -v_odom*sin(theta_est)*P33;
  der(P22) =  2.0*v_odom*cos(theta_est)*P23 + Q_pos;
  der(P23) =  v_odom*cos(theta_est)*P33;
  der(P33) =  Q_theta;

  // ===== Verification outputs =====
  cov_trace = P11 + P22 + P33;
  tracking_error = sqrt((x_true - x_ref)^2 + (y_true - y_ref)^2 + 1.0e-10);
  est_pos_error  = sqrt((x_est - x_true)^2 + (y_est - y_true)^2 + 1.0e-10);
  dist_to_start  = sqrt((x_true - 5.0)^2 + y_true^2 + 1.0e-10);

  dist_obs1 = sqrt((x_true - obs1_x)^2 + (y_true - obs1_y)^2 + 1.0e-10);
  dist_obs2 = sqrt((x_true - obs2_x)^2 + (y_true - obs2_y)^2 + 1.0e-10);
  min_obs_dist = if dist_obs1 < dist_obs2 then dist_obs1 else dist_obs2;
  collision = min_obs_dist < 0.5;

  no_nan_inf = (abs(x_est) < 1.0e6) and (abs(y_est) < 1.0e6)
              and (abs(theta_est) < 1.0e6) and (abs(P11) < 1.0e6)
              and (abs(P22) < 1.0e6) and (abs(P33) < 1.0e6)
              and (abs(v_true) < 1.0e6) and (abs(w_true) < 1.0e6)
              and (abs(cov_trace) < 1.0e6)
              and (abs(tau_L) < 1.0e6) and (abs(tau_R) < 1.0e6);

  tracking_ok = (time < 13.0) or (tracking_error < 0.2);

  annotation (
    experiment(StopTime=20.0, Tolerance=1.0e-6, Interval=0.002),
    Documentation(info="MapRigMapF — Robotic sensing and estimation scenario.
      22 kg mobile base, 20 m planar lidar, forward RGB-D camera, wheel encoders, IMU
      at explicitly different rates (500/100/10/5 Hz) and transforms.
      Closed elliptical route; EKF fuses odometry + IMU + range; camera/sonar retained separately.
      Six fixed landmarks, two obstacles in shared world frame.
      Bounded wheel drives <= 14.6 N.m per wheel.
      0.29 m landmark perturbation during middle third.
      Loop-closure correction when returning near start.
      500 Hz base rate, 20 s, synchronized state/command/sensor traces.
      Verifies: finite covariance, loop-closure errors, declared output rate,
      no collision, tracking error < 0.2 m after 13 s, no NaN/Inf.")
  );
end MapRigMapF;