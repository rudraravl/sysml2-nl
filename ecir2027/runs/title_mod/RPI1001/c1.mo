model AckermannRoverInspectE
  "Floating-base Ackermann rover inspecting an S-corridor at 0.8 m/s with fused localization, bounded actuators, side-load disturbance and fail-closed acceptance."

  // ===================== Parameters (from requirement) =====================
  // Chassis / geometry
  parameter Real m_chassis = 34.0 "chassis mass [kg]";
  parameter Real L_chassis = 1.05 "chassis length [m]";
  parameter Real W_chassis = 0.64 "chassis width [m]";
  parameter Real L_wheelbase = 0.74 "wheelbase [m]";
  // wheel radius not specified in requirement; nominal value retained so the
  // plant structure (rear-wheel drive torque->force) is fully represented.
  parameter Real r_wheel = 0.18 "wheel radius [m] (nominal, not specified in request)";

  // Actuator bounds
  parameter Real delta_max = 0.52 "front steering joint limit [rad]";
  parameter Real tau_cmd_max = 30.8 "actuator command magnitude bound [N.m]";
  parameter Real tau_drive_max = 30.8 "rear traction torque bound [N.m]";
  parameter Real tau_steer_max = 30.8 "front steering torque bound [N.m]";

  // Mission
  parameter Real v_ref = 0.8 "reference speed [m/s]";
  parameter Real corridor_width = 1.8 "wall spacing [m]";
  parameter Real corridor_half_width = 0.9 "half wall spacing [m]";
  parameter Real clearance_min = 0.18 "minimum wall clearance [m]";
  parameter Real track_err_thresh = 0.18 "primary tracking error threshold after 10.4 s [m]";
  parameter Real t_eval = 10.4 "tracking-error evaluation time [s]";
  parameter Real t_end = 16.0 "scenario duration [s]";
  parameter Real sample_Hz = 250.0 "synchronized trace rate [Hz]";

  // S-corridor centerline
  parameter Real A_s = 0.5 "S-curve amplitude [m]";
  parameter Real S_total = 12.8 "total centerline length [m] (= v_ref*t_end)";
  parameter Real L_lookahead = 1.6 "pure-pursuit lookahead distance [m]";

  // Two recessed alcoves
  parameter Real alcove_depth = 0.45 "recess depth [m]";
  parameter Real alcove_half_len = 0.6 "half length along arc length [m]";
  parameter Real alcove1_s = 3.2 "first alcove center arc length [m]";
  parameter Real alcove2_s = 9.6 "second alcove center arc length [m]";

  // Disturbance
  parameter Real F_side_load = 108.0 "controlled side load magnitude [N]";
  parameter Real t_dist_start = 5.3333333 "middle-third start [s]";
  parameter Real t_dist_end = 10.6666667 "middle-third end [s]";
  parameter Real h_side = 0.15 "side-load yaw moment arm [m] (nominal, not specified)";

  // Controller gains
  parameter Real K_v = 60.0 "speed tracking gain [(N.m)/(m/s)]";
  parameter Real K_steer_p = 2.5 "steering proportional gain [N.m/rad]";
  parameter Real K_steer_d = 0.4 "steering damping gain [N.m.s/rad]";
  parameter Real drag_coef = 8.0 "rolling resistance [N.s/m]";

  // Tire / body dynamics (nominal, structural)
  parameter Real C_f = 4000.0 "front cornering stiffness [N/rad]";
  parameter Real C_r = 4000.0 "rear cornering stiffness [N/rad]";
  parameter Real a_cg = 0.37 "CoM to front axle [m]";
  parameter Real b_cg = 0.37 "CoM to rear axle [m]";
  parameter Real I_zz = (1.0/12.0)*m_chassis*(L_chassis*L_chassis + W_chassis*W_chassis) "yaw inertia [kg.m^2]";
  parameter Real J_steer = 0.3 "steering joint inertia [kg.m^2] (nominal)";
  parameter Real b_steer = 1.2 "steering joint damping [N.m.s/rad] (nominal)";
  parameter Real c_lat = 20.0 "lateral velocity damping [N.s/m] (nominal)";

  // Estimator / sensor fusion
  parameter Real Q_pos = 0.001 "position process noise [m^2/s]";
  parameter Real Q_head = 0.001 "heading process noise [rad^2/s]";
  parameter Real Q_odom = 0.005 "odometry noise injection [m^2/s]";
  parameter Real Q_imu = 0.002 "IMU noise injection [rad^2/s]";
  parameter Real beta_lidar = 0.8 "lidar position correction rate [1/s]";
  parameter Real beta_imu = 0.5 "imu/heading correction rate [1/s]";
  parameter Real lidar_range_max = 15.0 "planar lidar maximum range [m]";
  parameter Real noise_v = 0.01 "odometry speed noise amplitude [m/s]";
  parameter Real noise_r = 0.001 "IMU yaw-rate noise amplitude [rad/s]";
  parameter Real noise_lidar = 0.02 "lidar map-match noise amplitude [m]";
  parameter Real noise_head = 0.005 "fused heading noise amplitude [rad]";

  // ===================== Plant states =====================
  Real x(start=0.0, fixed=true) "chassis x [m]";
  Real y(start=0.0, fixed=true) "chassis y [m]";
  Real theta(start=0.0, fixed=true) "chassis heading [rad]";
  Real v(start=0.05, fixed=true) "longitudinal speed [m/s]";
  Real vy(start=0.0, fixed=true) "lateral speed [m/s]";
  Real r_yaw(start=0.0, fixed=true) "yaw rate [rad/s]";
  Real delta(start=0.0, fixed=true) "front steering angle [rad]";
  Real omega_delta(start=0.0, fixed=true) "steering joint rate [rad/s]";

  // ===================== Commands / actuators =====================
  Real tau_drive_cmd "rear traction torque command [N.m]";
  Real tau_steer_cmd "front steering torque command [N.m]";
  Real tau_drive_sat "saturated drive torque [N.m]";
  Real tau_steer_sat "saturated steer torque [N.m]";
  Real delta_cmd "pure-pursuit desired steering [rad]";
  Real delta_eff "steering angle used in tire force [rad]";

  // ===================== Path tracking =====================
  Real s_proj "projected arc length [m]";
  Real y_ref "centerline lateral position [m]";
  Real theta_ref "centerline heading [rad]";
  Real s_target "lookahead arc length [m]";
  Real x_target "lookahead x [m]";
  Real y_target "lookahead y [m]";
  Real alpha_pp "pure-pursuit bearing error [rad]";
  Real cross_track "signed lateral tracking error [m]";
  Real heading_err "heading error [rad]";
  Real primary_track_err "primary (absolute lateral) tracking error [m]";

  // ===================== Disturbance =====================
  Real F_side "active side load [N]";
  Real M_dist "side-load yaw moment [N.m]";

  // ===================== Corridor / clearance / lidar =====================
  Real corridor_hw_local "local corridor half-width including alcoves [m]";
  Real lateral_dev "absolute lateral deviation from centerline [m]";
  Real wall_clearance "minimum wall clearance [m]";
  Real lidar_range "planar lidar nearest-wall range [m]";
  Boolean lidar_valid "lidar measurement valid (within 15 m)";

  // ===================== Sensors =====================
  Real odom_v "wheel odometry speed measurement [m/s]";
  Real odom_delta "wheel odometry steering measurement [rad]";
  Real imu_yawrate "IMU yaw rate measurement [rad/s]";
  Real lidar_x "lidar map-match x measurement [m]";
  Real lidar_y "lidar map-match y measurement [m]";
  Real head_meas "fused heading measurement [rad]";

  // ===================== Estimator states =====================
  Real x_hat(start=0.0, fixed=true) "estimated x [m]";
  Real y_hat(start=0.0, fixed=true) "estimated y [m]";
  Real theta_hat(start=0.0, fixed=true) "estimated heading [rad]";
  Real P_pos(start=0.5, fixed=true) "position covariance [m^2]";
  Real P_head(start=0.1, fixed=true) "heading covariance [rad^2]";
  Real est_pos_err "estimator position error magnitude [m]";

  // ===================== Acceptance / traces =====================
  Real s_progress "route progress arc length [m]";
  Boolean clearance_ok "instantaneous wall clearance above 0.18 m";
  Boolean track_ok "primary tracking error below 0.18 m after 10.4 s";
  Boolean route_complete "route completion reached";
  Boolean finite_ok "no NaN/infinite or out-of-bound physical/control/estimator values";
  Boolean covariance_ok "covariance finite and positive";
  Boolean accept "fail-closed acceptance flag";
  discrete Boolean clearance_violated(start=false) "latched clearance violation";
  discrete Real track_err_sampled(start=0.0) "tracking error sampled at 10.4 s";

protected
  parameter Real pi_val = 3.14159265358979323846;

equation
  // ============ S-corridor centerline (arc-length param, x ~ s) ============
  s_proj = x;
  y_ref = A_s * sin(pi_val * s_proj / (S_total/2.0));
  theta_ref = atan(A_s*(pi_val/(S_total/2.0)) * cos(pi_val*s_proj/(S_total/2.0)));

  // Lookahead (pure pursuit) target
  s_target = s_proj + L_lookahead;
  x_target = s_target;
  y_target = A_s * sin(pi_val * s_target / (S_total/2.0));
  alpha_pp = atan2(y_target - y, x_target - x) - theta;
  // Pure-pursuit steering command (bicycle form), inherently within atan range
  delta_cmd = atan(2.0*L_wheelbase*sin(alpha_pp) / L_lookahead);

  // Tracking error metrics
  cross_track = (y - y_ref)*cos(theta_ref) - (x - s_proj)*sin(theta_ref);
  heading_err = theta - theta_ref;
  primary_track_err = abs(cross_track);

  // ============ Speed controller (rear traction) ============
  tau_drive_cmd = K_v*(v_ref - v);
  tau_drive_sat = max(-tau_drive_max, min(tau_drive_max, tau_drive_cmd));

  // ============ Steering controller (front steering) ============
  tau_steer_cmd = K_steer_p*(delta_cmd - delta) - K_steer_d*omega_delta;
  tau_steer_sat = max(-tau_steer_max, min(tau_steer_max, tau_steer_cmd));

  // ============ Steering joint dynamics with hard limit ============
  J_steer * der(omega_delta) = tau_steer_sat - b_steer*omega_delta;
  der(delta) = omega_delta
               - 100.0*max(0.0, delta - delta_max)
               + 100.0*max(0.0, -delta_max - delta);
  delta_eff = max(-delta_max, min(delta_max, delta));

  // ============ Chassis dynamics (planar bicycle with lateral slip) ============
  der(x) = v*cos(theta) - vy*sin(theta);
  der(y) = v*sin(theta) + vy*cos(theta);
  der(theta) = r_yaw;
  der(v) = (tau_drive_sat/r_wheel - drag_coef*v) / m_chassis;
  // lateral: tire forces + side load + damping + centripetal coupling
  der(vy) = (F_yf_func(vy, r_yaw, delta_eff, v) + F_yr_func(vy, r_yaw, v) + F_side - c_lat*vy)/m_chassis - r_yaw*v;
  der(r_yaw) = (a_cg*F_yf_func(vy, r_yaw, delta_eff, v) - b_cg*F_yr_func(vy, r_yaw, v) + M_dist) / I_zz;

  // ============ Controlled 108 N side-load disturbance (middle third) ============
  F_side = if (time >= t_dist_start and time <= t_dist_end) then F_side_load else 0.0;
  M_dist = F_side * h_side;

  // ============ Corridor walls with two recessed alcoves ============
  corridor_hw_local = corridor_half_width
                      + alcove_depth*alcove_mask(s_proj, alcove1_s, alcove_half_len)
                      + alcove_depth*alcove_mask(s_proj, alcove2_s, alcove_half_len);
  lateral_dev = abs(cross_track);
  // clearance from chassis edge to nearest wall
  wall_clearance = corridor_hw_local - lateral_dev - W_chassis/2.0;
  // planar lidar range to nearest wall (from chassis center)
  lidar_range = corridor_hw_local - lateral_dev;
  lidar_valid = lidar_range < lidar_range_max;

  // ============ Sensors ============
  odom_v = v + noise_v*sin(7.0*time);
  odom_delta = delta_eff + 0.002*sin(9.0*time);
  imu_yawrate = r_yaw + noise_r*sin(11.0*time);
  lidar_x = x + noise_lidar*sin(3.0*time);
  lidar_y = y + noise_lidar*cos(3.0*time);
  head_meas = theta + noise_head*sin(5.0*time);

  // ============ Localization fusion (odometry + IMU + lidar) ============
  // Prediction from odometry/IMU, correction from lidar map-match (when valid)
  der(x_hat) = odom_v*cos(theta_hat)
               + (if lidar_valid then beta_lidar*(lidar_x - x_hat) else 0.0);
  der(y_hat) = odom_v*sin(theta_hat)
               + (if lidar_valid then beta_lidar*(lidar_y - y_hat) else 0.0);
  der(theta_hat) = imu_yawrate + beta_imu*(head_meas - theta_hat);
  // Finite, positive covariance dynamics (process noise in, measurement info out)
  der(P_pos) = Q_pos + Q_odom - beta_lidar*P_pos;
  der(P_head) = Q_head + Q_imu - beta_imu*P_head;
  est_pos_err = sqrt_safe((x - x_hat)*(x - x_hat) + (y - y_hat)*(y - y_hat));

  // ============ Acceptance / fail-closed ============
  s_progress = x;
  route_complete = s_progress >= (S_total - 1.0);
  clearance_ok = wall_clearance > clearance_min;
  track_ok = (time >= t_eval) and (track_err_sampled < track_err_thresh);
  covariance_ok = (P_pos > 0.0) and (P_head > 0.0) and (P_pos < 1000.0) and (P_head < 1000.0);
  finite_ok = (abs(x) < 1.0e7) and (abs(y) < 1.0e7) and (abs(theta) < 1.0e7)
              and (abs(v) < 1.0e7) and (abs(vy) < 1.0e7) and (abs(r_yaw) < 1.0e7)
              and (abs(delta) < 1.0e7) and (abs(omega_delta) < 1.0e7)
              and (abs(x_hat) < 1.0e7) and (abs(y_hat) < 1.0e7) and (abs(theta_hat) < 1.0e7)
              and (abs(tau_drive_sat) <= tau_cmd_max + 1.0e-6)
              and (abs(tau_steer_sat) <= tau_cmd_max + 1.0e-6);
  accept = clearance_ok and track_ok and route_complete and finite_ok and covariance_ok and (not clearance_violated);

  // Latched clearance violation (fail-closed)
  when wall_clearance < clearance_min then
    clearance_violated = true;
  end when;

  // Sample primary tracking error at evaluation time
  when time >= t_eval then
    track_err_sampled = primary_track_err;
  end when;

  annotation (
    experiment(StopTime = 16.0, Interval = 0.004, Tolerance = 1e-6),
    Documentation(info = "AckermannRoverInspectE: 250 Hz, 16 s scenario. Ackermann plant represented as a planar dynamic bicycle model (rear-wheel drive, front steering) with bounded 30.8 N.m actuators and +-0.52 rad steering joints. Localization fuses wheel odometry, IMU and 15 m planar lidar via a complementary filter with finite covariance. A controlled 108 N side load is applied during the middle third. Corridor walls are 1.8 m apart with two recessed alcoves. Acceptance is fail-closed: finite values, wall clearance > 0.18 m, primary tracking error < 0.18 m after 10.4 s, route completion, finite covariance. Unspecified structural parameters (wheel radius, steering inertia/damping, moment arm, cornering stiffness) are marked nominal and are design choices, not asserted facts.")
  );
end AckermannRoverInspectE;

function F_yf_func "Front tire lateral force [N]"
  input Real vy_in "lateral speed [m/s]";
  input Real r_in "yaw rate [rad/s]";
  input Real delta_eff_in "effective steering [rad]";
  input Real v_in "longitudinal speed [m/s]";
  output Real F_yf "front lateral force [N]";
protected
  Real v_safe;
  Real alpha_f;
algorithm
  v_safe := if v_in > 0.05 then v_in else 0.05;
  alpha_f := atan((vy_in + 0.37*r_in)/v_safe) - delta_eff_in;
  F_yf := -4000.0 * alpha_f;
end F_yf_func;

function F_yr_func "Rear tire lateral force [N]"
  input Real vy_in "lateral speed [m/s]";
  input Real r_in "yaw rate [rad/s]";
  input Real v_in "longitudinal speed [m/s]";
  output Real F_yr "rear lateral force [N]";
protected
  Real v_safe;
  Real alpha_r;
algorithm
  v_safe := if v_in > 0.05 then v_in else 0.05;
  alpha_r := atan((vy_in - 0.37*r_in)/v_safe);
  F_yr := -4000.0 * alpha_r;
end F_yr_func;

function alcove_mask "Rectangular mask: 1 inside alcove band, else 0"
  input Real s "arc length [m]";
  input Real s0 "alcove center [m]";
  input Real half_len "half length [m]";
  output Real m_out "0 or 1";
algorithm
  m_out := if abs(s - s0) < half_len then 1.0 else 0.0;
end alcove_mask;

function sqrt_safe "Square root with zero-error branch"
  input Real x_in "nonnegative input";
  output Real y_out "square root";
algorithm
  y_out := if x_in > 0.0 then sqrt(x_in) else 0.0;
end sqrt_safe;