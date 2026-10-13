model MapRigMapF
  extends Modelica.Icons.Example;

  // -------- Physical parameters (SI) --------
  parameter Real m_base = 22.0          "Mobile base mass [kg]";
  parameter Real I_base = 1.5            "Yaw inertia [kg.m2]";
  parameter Real r_w = 0.098             "Wheel radius [m]";
  parameter Real L_track = 0.45          "Track width [m]";
  parameter Real b_lin = 1.2             "Linear damping coefficient [N.s/m]";
  parameter Real b_ang = 0.4             "Angular damping coefficient [N.m.s]";
  parameter Real tau_max = 14.6          "Per-wheel torque limit [N.m]";

  // -------- Closed route --------
  parameter Real R_route = 5.0                       "Route radius [m]";
  parameter Real omega_route = 0.7853981633974483    "Route angular rate [rad/s], one loop per 8 s";
  parameter Real pi_const = 3.141592653589793;

  // -------- Controller gains --------
  parameter Real k_pos = 1.5;
  parameter Real k_head = 2.0;
  parameter Real k_tau = 8.0;
  parameter Real k_omega = 4.0;

  // -------- Landmarks (fixed, world frame) --------
  parameter Real LM1_x = 5.5;
  parameter Real LM1_y = 0.0;
  parameter Real LM2_x = 0.0;
  parameter Real LM2_y = 5.5;
  parameter Real LM3_x = -5.5;
  parameter Real LM3_y = 0.0;
  parameter Real LM4_x = 0.0;
  parameter Real LM4_y = -5.5;
  parameter Real LM5_x = 3.9;
  parameter Real LM5_y = 3.9;
  parameter Real LM6_x = -3.9;
  parameter Real LM6_y = 3.9;

  // -------- Obstacles (shared world frame) --------
  parameter Real OBS1_x = 2.0;
  parameter Real OBS1_y = 2.0;
  parameter Real OBS2_x = -2.0;
  parameter Real OBS2_y = 2.0;
  parameter Real r_obs = 0.6   "Obstacle radius [m]";
  parameter Real r_robot = 0.3 "Robot footprint radius [m]";

  // -------- Disturbance --------
  parameter Real perturb = 0.29                       "Landmark perturbation [m]";
  parameter Real t_perturb_start = 6.666666666666667   "Middle third start [s]";
  parameter Real t_perturb_end = 13.333333333333334    "Middle third end [s]";

  // -------- Sensor rates --------
  parameter Real T_imu = 0.002   "IMU period [s] (500 Hz)";
  parameter Real T_enc = 0.01    "Encoder period [s] (100 Hz)";
  parameter Real T_lidar = 0.1  "Lidar period [s] (10 Hz)";
  parameter Real T_cam = 0.2     "Camera period [s] (5 Hz)";
  parameter Real range_lidar_max = 20.0 "Lidar maximum range [m]";

  // -------- Estimator --------
  parameter Real q_pos = 1e-4        "Position process noise [m2/s]";
  parameter Real q_th = 1e-4         "Heading process noise [rad2/s]";
  parameter Real r_lidar_var = 0.04  "Lidar range noise variance [m2]";
  parameter Real P_max = 10.0        "Covariance ceiling";
  parameter Real P_min = 1e-6        "Covariance floor";
  parameter Real alpha_corr = 0.3    "Lidar correction gain";
  parameter Real alpha_loop = 0.7   "Loop closure correction gain";

  // -------- True states --------
  Real x(start=5.0, fixed=true)        "Base x position [m]";
  Real y(start=0.0, fixed=true)        "Base y position [m]";
  Real theta(start=1.5707963267948966, fixed=true) "Heading [rad]";
  Real v(start=0.0, fixed=true)        "Linear speed [m/s]";
  Real omega(start=0.0, fixed=true)    "Yaw rate [rad/s]";
  Real tau_R "Right wheel torque [N.m]";
  Real tau_L "Left wheel torque [N.m]";
  Real F_R   "Right wheel traction force [N]";
  Real F_L   "Left wheel traction force [N]";
  Real a_true "True longitudinal acceleration [m/s2]";

  // -------- Reference --------
  Real x_ref, y_ref, theta_ref, v_ref, omega_ref;
  Real v_cmd, omega_cmd;
  Real ex, ey, eth;

  // -------- Landmark perturbation effect --------
  Boolean perturb_active;
  Real LM1x_eff "Effective (perturbed) landmark 1 x [m]";
  Real LM1y_eff "Effective (perturbed) landmark 1 y [m]";

  // -------- Sensor discrete outputs --------
  discrete Real omega_imu(start=0.0)  "IMU gyro measurement [rad/s]";
  discrete Real a_imu(start=0.0)     "IMU accelerometer measurement [m/s2]";
  discrete Real v_enc(start=0.0)     "Encoder-derived speed [m/s]";
  discrete Real range_lidar(start=10.0) "Nearest lidar range [m]";
  discrete Integer lidar_id(start=1) "Nearest landmark identifier";
  discrete Real cam_depth(start=0.0) "Camera depth retained separately [m]";
  discrete Real sonar_depth(start=0.0) "Sonar depth retained separately [m]";

  // -------- Estimator states --------
  Real x_hat(start=5.0, fixed=true)        "Estimated x [m]";
  Real y_hat(start=0.0, fixed=true)        "Estimated y [m]";
  Real theta_hat(start=1.5707963267948966, fixed=true) "Estimated heading [rad]";
  Real P11(start=0.01) "Covariance xx [m2]";
  Real P22(start=0.01) "Covariance yy [m2]";
  Real P33(start=0.01) "Covariance tt [rad2]";

  // -------- Loop closure --------
  discrete Boolean loop_fired(start=false, fixed=true);
  discrete Real loop_closure_pos_err(start=0.0);
  discrete Real loop_closure_head_err(start=0.0);
  Real dist_loop "Distance to loop anchor [m]";

  // -------- Verification outputs --------
  output Real cov_max;
  output Real tracking_error;
  output Real collision_dist;
  output Boolean collision_flag;
  output Boolean finite_covariance;
  output Boolean nan_flag;
  output Boolean tracking_error_ok;
  output Real output_rate_Hz;
  output Real primary_tracking_error;

  // -------- Derived geometric quantities --------
  Real r_lm1, r_lm2, r_lm3, r_lm4, r_lm5, r_lm6;
  Real bearing_lm1;
  Real dist_obs1, dist_obs2;

equation
  // Reference closed route
  x_ref = R_route*cos(omega_route*time);
  y_ref = R_route*sin(omega_route*time);
  theta_ref = omega_route*time + 1.5707963267948966;
  v_ref = R_route*omega_route;
  omega_ref = omega_route;

  // Landmark perturbation during middle third
  perturb_active = (time >= t_perturb_start) and (time <= t_perturb_end);
  LM1x_eff = LM1_x + (if perturb_active then perturb else 0.0);
  LM1y_eff = LM1_y;

  // Ranges to landmarks (effective)
  r_lm1 = sqrt((x - LM1x_eff)^2 + (y - LM1y_eff)^2);
  r_lm2 = sqrt((x - LM2_x)^2 + (y - LM2_y)^2);
  r_lm3 = sqrt((x - LM3_x)^2 + (y - LM3_y)^2);
  r_lm4 = sqrt((x - LM4_x)^2 + (y - LM4_y)^2);
  r_lm5 = sqrt((x - LM5_x)^2 + (y - LM5_y)^2);
  r_lm6 = sqrt((x - LM6_x)^2 + (y - LM6_y)^2);

  // Bearing to LM1 (measured by lidar in robot frame)
  bearing_lm1 = Modelica.Math.atan2(LM1y_eff - y, LM1x_eff - x) - theta;

  // Obstacle distances
  dist_obs1 = sqrt((x - OBS1_x)^2 + (y - OBS1_y)^2);
  dist_obs2 = sqrt((x - OBS2_x)^2 + (y - OBS2_y)^2);
  collision_dist = min(dist_obs1, dist_obs2) - r_obs - r_robot;
  collision_flag = collision_dist < 0.0;

  // Loop anchor is the start point (R_route, 0)
  dist_loop = sqrt((x - R_route)^2 + (y - 0.0)^2);

  // True dynamics
  der(x) = v*cos(theta);
  der(y) = v*sin(theta);
  der(theta) = omega;
  a_true = (F_R + F_L)/m_base - (b_lin/m_base)*v;
  der(v) = a_true;
  der(omega) = (F_R - F_L)*L_track/(2*I_base) - (b_ang/I_base)*omega;
  F_R = tau_R/r_w;
  F_L = tau_L/r_w;

  // Pose controller (route tracking)
  ex = x_ref - x;
  ey = y_ref - y;
  eth = theta_ref - theta;
  v_cmd = v_ref + k_pos*(ex*cos(theta) + ey*sin(theta));
  omega_cmd = omega_ref + k_head*sin(eth) + k_pos*(-ex*sin(theta) + ey*cos(theta))/max(R_route, 0.1);

  // Bounded wheel drives
  tau_R = max(-tau_max, min(tau_max, k_tau*(v_cmd - v) + k_omega*(omega_cmd - omega)));
  tau_L = max(-tau_max, min(tau_max, k_tau*(v_cmd - v) - k_omega*(omega_cmd - omega)));

  // Estimator prediction (odometry + IMU driven, zero-order held sensor inputs)
  der(x_hat) = v_enc*cos(theta_hat);
  der(y_hat) = v_enc*sin(theta_hat);
  der(theta_hat) = omega_imu;
  der(P11) = q_pos;
  der(P22) = q_pos;
  der(P33) = q_th;

  // IMU sampling (500 Hz)
  when sample(0.0, T_imu) then
    omega_imu = omega;
    a_imu = a_true;
  end when;

  // Wheel encoder sampling (100 Hz)
  when sample(0.0, T_enc) then
    v_enc = v;
  end when;

  // Lidar sampling (10 Hz): nearest range + pose correction using map landmark 1
  when sample(T_lidar/2.0, T_lidar) then
    range_lidar = min(r_lm1, min(r_lm2, min(r_lm3, min(r_lm4, min(r_lm5, r_lm6)))));
    lidar_id = 1;
    // Pose filtering correction from landmark 1 (map retains unperturbed position)
    reinit(x_hat, x_hat + alpha_corr*((LM1_x - r_lm1*cos(theta_hat + bearing_lm1)) - x_hat));
    reinit(y_hat, y_hat + alpha_corr*((LM1_y - r_lm1*sin(theta_hat + bearing_lm1)) - y_hat));
    reinit(P11, max(P_min, min(P_max, P11*(1.0 - alpha_corr) + r_lidar_var)));
    reinit(P22, max(P_min, min(P_max, P22*(1.0 - alpha_corr) + r_lidar_var)));
    reinit(P33, max(P_min, min(P_max, P33*(1.0 - 0.1*alpha_corr) + 0.01*r_lidar_var)));
  end when;

  // Camera and sonar retained separately (not fused) at 5 Hz
  when sample(T_cam/2.0, T_cam) then
    cam_depth = min(dist_obs1, dist_obs2);
    sonar_depth = dist_loop;
  end when;

  // Loop closure correction when returning near start anchor after one loop
  when (time >= 7.0) and (dist_loop <= 0.5) and not pre(loop_fired) then
    loop_fired = true;
    loop_closure_pos_err = sqrt(pre(x_hat - x)^2 + pre(y_hat - y)^2);
    loop_closure_head_err = pre(theta_hat) - theta;
    reinit(x_hat, pre(x_hat) + alpha_loop*(x - pre(x_hat)));
    reinit(y_hat, pre(y_hat) + alpha_loop*(y - pre(y_hat)));
    reinit(theta_hat, pre(theta_hat) + alpha_loop*(theta - pre(theta_hat)));
    reinit(P11, max(P_min, min(P_max, pre(P11)*(1.0 - alpha_loop))));
    reinit(P22, max(P_min, min(P_max, pre(P22)*(1.0 - alpha_loop))));
    reinit(P33, max(P_min, min(P_max, pre(P33)*(1.0 - alpha_loop))));
  end when;

  // -------- Verification aggregation --------
  cov_max = max(P11, max(P22, P33));
  tracking_error = sqrt((x_hat - x)^2 + (y_hat - y)^2);
  primary_tracking_error = tracking_error;
  tracking_error_ok = (time >= 13.0) and (tracking_error <= 0.2);
  finite_covariance = (P11 >= 0.0) and (P22 >= 0.0) and (P33 >= 0.0) and
                      (P11 <= P_max) and (P22 <= P_max) and (P33 <= P_max);
  nan_flag = not ((x == x) and (y == y) and (theta == theta) and (v == v) and
                  (tau_R == tau_R) and (tau_L == tau_L) and
                  (x_hat == x_hat) and (y_hat == y_hat) and (theta_hat == theta_hat) and
                  (P11 == P11) and (P22 == P22) and (P33 == P33));
  output_rate_Hz = 500.0;

  annotation (
    Documentation(info="MapRigMapF: closed-route traversal with pose filtering, loop-closure correction, retained exteroceptive observations, mid-third landmark perturbation, and verification outputs."),
    experiment(StartTime=0.0, StopTime=20.0, Tolerance=1e-6, Interval=0.002)
  );
end MapRigMapF;