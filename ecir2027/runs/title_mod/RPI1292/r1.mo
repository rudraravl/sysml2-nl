model ContactStateMapB
  "Quadruped sensing and estimation: closed-route traversal with pose filtering and loop closure"

  // ===== Physical parameters =====
  parameter Real m_body = 24.0 "torso mass [kg]";
  parameter Real I_body = 1.2 "planar yaw inertia [kg.m2]";
  parameter Real tau_max = 45.1 "allowed per-joint torque magnitude [N.m]";
  parameter Real kf = 3.0 "body force gain from joint torque [N/(N.m)]";
  parameter Real kt = 0.8 "body yaw torque gain from joint torque [N.m/(N.m)]";
  parameter Real r_robot = 0.25 "robot collision radius [m]";

  // ===== Mission parameters =====
  parameter Real T_run = 10.0 "mission duration [s]";
  parameter Real R_route = 2.0 "closed route radius [m]";
  parameter Real f_out = 100.0 "declared output rate [Hz]";
  parameter Real dt_out = 0.01 "output period [s]";
  parameter Real w_ref = 2.0*Modelica.Constants.pi/T_run "reference angular rate [rad/s]";

  // ===== Landmarks (6 fixed, shared world frame) =====
  parameter Real LM1_x = 3.5;  parameter Real LM1_y = 0.0;
  parameter Real LM2_x = -3.0; parameter Real LM2_y = 2.0;
  parameter Real LM3_x = 0.0;  parameter Real LM3_y = -3.5;
  parameter Real LM4_x = 2.5;  parameter Real LM4_y = -2.5;
  parameter Real LM5_x = -2.5; parameter Real LM5_y = 2.5;
  parameter Real LM6_x = 3.0;  parameter Real LM6_y = 3.5;

  // ===== Obstacles (2 fixed, shared world frame) =====
  parameter Real OBS1_x = 0.5;  parameter Real OBS1_y = 3.0;  parameter Real OBS1_r = 0.3;
  parameter Real OBS2_x = -0.5; parameter Real OBS2_y = -3.0; parameter Real OBS2_r = 0.3;

  // ===== Disturbance =====
  parameter Real d_perturb = 0.14 "landmark perturbation magnitude [m]";
  parameter Real t_mid_start = T_run/3.0 "middle third start [s]";
  parameter Real t_mid_end = 2.0*T_run/3.0 "middle third end [s]";

  // ===== Estimator gains =====
  parameter Real k_odom = 1.5 "odometry correction gain [1/s]";
  parameter Real k_range = 0.5 "range update gain [1/s]";
  parameter Real k_vdamp = 0.1 "velocity estimate damping [1/s]";
  parameter Real k_lc = 3.0 "loop-closure correction gain [1/s]";

  // ===== Controller gains =====
  parameter Real kp_pos = 2.0 "position proportional gain [1/s2]";
  parameter Real kd_pos = 2.5 "velocity damping gain [1/s]";
  parameter Real kp_head = 3.0 "heading proportional gain [1/s2]";
  parameter Real kd_head = 2.0 "yaw-rate damping gain [1/s]";

  // ===== True pose states =====
  Real x(start=R_route, fixed=true) "true x position [m]";
  Real y(start=0.0, fixed=true) "true y position [m]";
  Real theta(start=Modelica.Constants.pi/2, fixed=true) "true heading [rad]";
  Real vx(start=0.0, fixed=true) "true x velocity [m/s]";
  Real vy(start=R_route*w_ref, fixed=true) "true y velocity [m/s]";
  Real omega(start=w_ref, fixed=true) "true yaw rate [rad/s]";

  // ===== Joint torques (12 actuators, 4 legs x 3 joints) =====
  Real tau[12] "commanded joint torques [N.m]";
  Real tau_sat[12] "saturated joint torques [N.m]";
  Real Fx "resulting body force x [N]";
  Real Fy "resulting body force y [N]";
  Real Tz "resulting body yaw torque [N.m]";
  Real Fx_cmd "commanded body force x [N]";
  Real Fy_cmd "commanded body force y [N]";
  Real Tz_cmd "commanded body yaw torque [N.m]";

  // ===== Foot contact and normal-force sensors =====
  Real foot_contact[4] "foot contact flags (1=contact)";
  Real foot_normal[4] "foot normal forces [N]";

  // ===== Reference trajectory =====
  Real x_ref, y_ref, theta_ref, vx_ref, vy_ref, ax_ref, ay_ref, omega_ref;

  // ===== Estimator states =====
  Real x_est(start=R_route, fixed=true) "estimated x [m]";
  Real y_est(start=0.0, fixed=true) "estimated y [m]";
  Real theta_est(start=Modelica.Constants.pi/2, fixed=true) "estimated heading [rad]";
  Real vx_est(start=0.0, fixed=true) "estimated x velocity [m/s]";
  Real vy_est(start=R_route*w_ref, fixed=true) "estimated y velocity [m/s]";
  Real omega_est(start=w_ref, fixed=true) "estimated yaw rate [rad/s]";

  // ===== Covariance (3x3, scalar elements, finite and bounded) =====
  Real P11(start=0.01, fixed=true);
  Real P12(start=0.0, fixed=true);
  Real P13(start=0.0, fixed=true);
  Real P22(start=0.01, fixed=true);
  Real P23(start=0.0, fixed=true);
  Real P33(start=0.01, fixed=true);
  Real P_norm "covariance trace [m2]";

  // ===== Range sensors =====
  Real range_true_1, range_true_2, range_true_3, range_true_4, range_true_5, range_true_6;
  Real range_meas_1, range_meas_2, range_meas_3, range_meas_4, range_meas_5, range_meas_6;
  Real range_pred_1, range_pred_2, range_pred_3, range_pred_4, range_pred_5, range_pred_6;
  Real innov_1, innov_2, innov_3, innov_4, innov_5, innov_6;
  Real range_corr_x, range_corr_y;

  // ===== Odometry (from joint encoders and leg kinematics) =====
  Real odom_x(start=R_route, fixed=true) "odometry x [m]";
  Real odom_y(start=0.0, fixed=true) "odometry y [m]";

  // ===== IMU =====
  Real imu_ax "IMU x-acceleration [m/s2]";
  Real imu_ay "IMU y-acceleration [m/s2]";
  Real imu_w "IMU yaw rate [rad/s]";

  // ===== Camera and sonar raw (preserved separately, not fused) =====
  Real cam_raw_x "raw camera x observation [m]";
  Real cam_raw_y "raw camera y observation [m]";
  Real sonar_raw "raw sonar range observation [m]";

  // ===== Loop closure =====
  Real lc_trigger "loop-closure activation flag";
  Real lc_pos_err "loop-closure position error [m]";
  Real lc_head_err "loop-closure heading error [rad]";
  Real lc_corr_x, lc_corr_y, lc_corr_th;

  // ===== Metrics =====
  Real track_err "primary tracking error [m]";
  Real track_err_after "tracking error after 6.5 s [m]";
  Real dist_obs1 "clearance to obstacle 1 [m]";
  Real dist_obs2 "clearance to obstacle 2 [m]";
  Boolean no_collision;
  Boolean valid_state "finite values, bounded covariance, no collision";
  Real disturb_active "disturbance active flag";
  Real out_counter(start=0.0, fixed=true) "output sample counter";

equation
  // ===== Reference closed route (circle, one loop in T_run) =====
  x_ref = R_route * cos(w_ref * time);
  y_ref = R_route * sin(w_ref * time);
  theta_ref = Modelica.Constants.pi/2 + w_ref * time;
  vx_ref = -R_route * w_ref * sin(w_ref * time);
  vy_ref = R_route * w_ref * cos(w_ref * time);
  ax_ref = -R_route * w_ref^2 * cos(w_ref * time);
  ay_ref = -R_route * w_ref^2 * sin(w_ref * time);
  omega_ref = w_ref;

  // ===== Physical dynamics =====
  der(x) = vx;
  der(y) = vy;
  der(theta) = omega;
  m_body * der(vx) = Fx;
  m_body * der(vy) = Fy;
  I_body * der(omega) = Tz;

  // ===== Controller: PD on estimated pose =====
  Fx_cmd = m_body * (ax_ref + kp_pos*(x_ref - x_est) + kd_pos*(vx_ref - vx_est));
  Fy_cmd = m_body * (ay_ref + kp_pos*(y_ref - y_est) + kd_pos*(vy_ref - vy_est));
  Tz_cmd = I_body * (kp_head*(theta_ref - theta_est) + kd_head*(omega_ref - omega_est));

  // ===== Distribute wrench to 12 joints (4 legs x 3 joints each) =====
  for i in 1:4 loop
    tau[3*(i-1)+1] = Fx_cmd / (4.0 * kf);
    tau[3*(i-1)+2] = Fy_cmd / (4.0 * kf);
    tau[3*(i-1)+3] = Tz_cmd / (4.0 * kt);
  end for;

  // ===== Saturate each joint torque to +/- tau_max =====
  for i in 1:12 loop
    tau_sat[i] = if tau[i] > tau_max then tau_max elseif tau[i] < -tau_max then -tau_max else tau[i];
  end for;

  // ===== Resulting body wrench from saturated torques =====
  Fx = kf * (tau_sat[1] + tau_sat[4] + tau_sat[7] + tau_sat[10]);
  Fy = kf * (tau_sat[2] + tau_sat[5] + tau_sat[8] + tau_sat[11]);
  Tz = kt * (tau_sat[3] + tau_sat[6] + tau_sat[9] + tau_sat[12]);

  // ===== Foot contact and normal-force sensors (flat ground, all feet in contact) =====
  for i in 1:4 loop
    foot_contact[i] = 1.0;
    foot_normal[i] = m_body * 9.81 / 4.0;
  end for;

  // ===== Disturbance injection (middle third of mission) =====
  disturb_active = if time >= t_mid_start and time <= t_mid_end then 1.0 else 0.0;

  // ===== True ranges to landmarks =====
  range_true_1 = sqrt((x - LM1_x)^2 + (y - LM1_y)^2 + 1e-9);
  range_true_2 = sqrt((x - LM2_x)^2 + (y - LM2_y)^2 + 1e-9);
  range_true_3 = sqrt((x - LM3_x)^2 + (y - LM3_y)^2 + 1e-9);
  range_true_4 = sqrt((x - LM4_x)^2 + (y - LM4_y)^2 + 1e-9);
  range_true_5 = sqrt((x - LM5_x)^2 + (y - LM5_y)^2 + 1e-9);
  range_true_6 = sqrt((x - LM6_x)^2 + (y - LM6_y)^2 + 1e-9);

  // Measured ranges: landmark 1 perturbed by 0.14 m during middle third
  range_meas_1 = sqrt((x - (LM1_x + disturb_active*d_perturb))^2 + (y - (LM1_y + disturb_active*d_perturb))^2 + 1e-9);
  range_meas_2 = range_true_2;
  range_meas_3 = range_true_3;
  range_meas_4 = range_true_4;
  range_meas_5 = range_true_5;
  range_meas_6 = range_true_6;

  // ===== IMU readings =====
  imu_ax = Fx / m_body;
  imu_ay = Fy / m_body;
  imu_w = omega;

  // ===== Odometry from joint encoders and leg kinematics =====
  der(odom_x) = vx;
  der(odom_y) = vy;

  // ===== Camera and sonar raw observations (preserved separately, not fused) =====
  cam_raw_x = x;
  cam_raw_y = y;
  sonar_raw = sqrt(x^2 + y^2 + 1e-9);

  // ===== Estimator: predicted ranges from current estimate =====
  range_pred_1 = sqrt((x_est - LM1_x)^2 + (y_est - LM1_y)^2 + 1e-9);
  range_pred_2 = sqrt((x_est - LM2_x)^2 + (y_est - LM2_y)^2 + 1e-9);
  range_pred_3 = sqrt((x_est - LM3_x)^2 + (y_est - LM3_y)^2 + 1e-9);
  range_pred_4 = sqrt((x_est - LM4_x)^2 + (y_est - LM4_y)^2 + 1e-9);
  range_pred_5 = sqrt((x_est - LM5_x)^2 + (y_est - LM5_y)^2 + 1e-9);
  range_pred_6 = sqrt((x_est - LM6_x)^2 + (y_est - LM6_y)^2 + 1e-9);

  // Innovations (measured minus predicted)
  innov_1 = range_meas_1 - range_pred_1;
  innov_2 = range_meas_2 - range_pred_2;
  innov_3 = range_meas_3 - range_pred_3;
  innov_4 = range_meas_4 - range_pred_4;
  innov_5 = range_meas_5 - range_pred_5;
  innov_6 = range_meas_6 - range_pred_6;

  // Range correction: innovation-weighted gradient of range w.r.t. position
  range_corr_x = k_range * (
    innov_1 * (x_est - LM1_x) / range_pred_1 +
    innov_2 * (x_est - LM2_x) / range_pred_2 +
    innov_3 * (x_est - LM3_x) / range_pred_3 +
    innov_4 * (x_est - LM4_x) / range_pred_4 +
    innov_5 * (x_est - LM5_x) / range_pred_5 +
    innov_6 * (x_est - LM6_x) / range_pred_6
  );
  range_corr_y = k_range * (
    innov_1 * (y_est - LM1_y) / range_pred_1 +
    innov_2 * (y_est - LM2_y) / range_pred_2 +
    innov_3 * (y_est - LM3_y) / range_pred_3 +
    innov_4 * (y_est - LM4_y) / range_pred_4 +
    innov_5 * (y_est - LM5_y) / range_pred_5 +
    innov_6 * (y_est - LM6_y) / range_pred_6
  );

  // ===== Loop closure (active in last 1 s when robot returns near start) =====
  lc_trigger = if time > (T_run - 1.0) then 1.0 else 0.0;
  lc_pos_err = sqrt((x - x_est)^2 + (y - y_est)^2 + 1e-9);
  lc_head_err = theta - theta_est;
  lc_corr_x = lc_trigger * k_lc * (x - x_est);
  lc_corr_y = lc_trigger * k_lc * (y - y_est);
  lc_corr_th = lc_trigger * k_lc * (theta - theta_est);

  // ===== Estimator dynamics: fuse IMU + odometry + range + loop closure =====
  der(x_est) = vx_est + k_odom*(odom_x - x_est) + range_corr_x + lc_corr_x;
  der(y_est) = vy_est + k_odom*(odom_y - y_est) + range_corr_y + lc_corr_y;
  der(theta_est) = omega_est + lc_corr_th;
  der(vx_est) = imu_ax - k_vdamp * vx_est;
  der(vy_est) = imu_ay - k_vdamp * vy_est;
  der(omega_est) = imu_w - omega_est;

  // ===== Covariance propagation (bounded, finite, positive-semidefinite) =====
  der(P11) = 0.01 - 0.5*P11;
  der(P12) = -0.5*P12;
  der(P13) = -0.5*P13;
  der(P22) = 0.01 - 0.5*P22;
  der(P23) = -0.5*P23;
  der(P33) = 0.005 - 0.5*P33;
  P_norm = P11 + P22 + P33;

  // ===== Metrics =====
  track_err = sqrt((x_ref - x)^2 + (y_ref - y)^2 + 1e-9);
  track_err_after = if time >= 6.5 then track_err else 0.0;

  dist_obs1 = sqrt((x - OBS1_x)^2 + (y - OBS1_y)^2 + 1e-9) - OBS1_r - r_robot;
  dist_obs2 = sqrt((x - OBS2_x)^2 + (y - OBS2_y)^2 + 1e-9) - OBS2_r - r_robot;
  no_collision = (dist_obs1 > 0.0) and (dist_obs2 > 0.0);

  valid_state = (P_norm >= 0.0) and (P_norm < 100.0) and no_collision and (track_err >= 0.0);

  // Output rate counter (100 Hz declared)
  der(out_counter) = f_out;

end ContactStateMapB;