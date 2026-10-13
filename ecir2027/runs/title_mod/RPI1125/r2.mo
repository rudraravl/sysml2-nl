model GroundTrioResilientC
  // GroundTrioResilientC: Three 18 kg differential-drive warehouse robots
  // with distributed formation control, prediction during communication
  // dropout, collision avoidance, bounded wheel drives, and recovery.
  // Operates at 125 Hz for 12 s with a 0.9 s dropout in the middle third.

  // --- Physical parameters (assumed for typical 18 kg warehouse robot) ---
  parameter Real m_robot = 18.0 "Robot mass [kg]";
  parameter Real r_w = 0.05 "Wheel radius [m]";
  parameter Real L_wb = 0.30 "Wheelbase [m]";
  parameter Real I_body = 0.5 "Body yaw inertia [kg.m2]";
  parameter Real b_lin = 2.0 "Linear viscous drag [N.s/m]";
  parameter Real c_rot = 0.5 "Rotational viscous drag [N.m.s/rad]";

  // --- Actuator limit ---
  parameter Real tau_max = 11.0 "Max wheel torque [N.m]";

  // --- Control gains ---
  parameter Real k_pos = 40.0 "Position stiffness [N/m]";
  parameter Real k_damp = 25.0 "Velocity damping [N.s/m]";
  parameter Real k_theta = 4.0 "Heading gain [N.m/rad]";
  parameter Real k_omega = 3.0 "Angular rate gain [N.m.s/rad]";
  parameter Real k_form = 0.3 "Formation coupling gain [-]";
  parameter Real k_coll = 8.0 "Collision avoidance gain [N/m]";
  parameter Real d_safe = 0.6 "Safe inter-robot distance [m]";

  // --- Route ---
  parameter Real v_route = 0.8 "Route speed [m/s]";
  parameter Real x_end = 8.0 "Route end x [m]";

  // --- Communication dropout (middle third: 4-8 s) ---
  parameter Real t_drop_start = 5.55 "Dropout start [s]";
  parameter Real t_drop_dur = 0.9 "Dropout duration [s]";

  // --- Environmental disturbance ---
  parameter Real dist_force = 3.0 "Shared disturbance force during dropout [N]";

  // --- Control period (125 Hz) ---
  parameter Real dt_ctrl = 0.008 "Control / comm period [s]";

  // --- Communication state ---
  Boolean comm_available;

  // --- Robot 1 states ---
  Real r1_x(start = 0.0) "Position x [m]";
  Real r1_y(start = 0.5) "Position y [m]";
  Real r1_theta(start = 0.0) "Heading [rad]";
  Real r1_v(start = 0.0) "Linear velocity [m/s]";
  Real r1_omega(start = 0.0) "Angular velocity [rad/s]";
  Real r1_tauL "Left wheel torque [N.m]";
  Real r1_tauR "Right wheel torque [N.m]";
  Real r1_tauL_raw "Unbounded left torque [N.m]";
  Real r1_tauR_raw "Unbounded right torque [N.m]";

  // --- Robot 2 states ---
  Real r2_x(start = -0.433);
  Real r2_y(start = -0.25);
  Real r2_theta(start = 0.0);
  Real r2_v(start = 0.0);
  Real r2_omega(start = 0.0);
  Real r2_tauL;
  Real r2_tauR;
  Real r2_tauL_raw;
  Real r2_tauR_raw;

  // --- Robot 3 states ---
  Real r3_x(start = 0.433);
  Real r3_y(start = -0.25);
  Real r3_theta(start = 0.0);
  Real r3_v(start = 0.0);
  Real r3_omega(start = 0.0);
  Real r3_tauL;
  Real r3_tauR;
  Real r3_tauL_raw;
  Real r3_tauR_raw;

  // --- Reference trajectory (formation centre) ---
  Real x_ref_center "Reference centre x [m]";
  Real y_ref_center "Reference centre y [m]";
  Real vx_ref_center "Reference centre vx [m/s]";
  Real r1_x_ref, r1_y_ref;
  Real r2_x_ref, r2_y_ref;
  Real r3_x_ref, r3_y_ref;

  // --- Last-received peer states with timestamps (proprioception + peer msgs) ---
  Real r1_x_lr(start = 0.0) "Last-received x [m]";
  Real r1_y_lr(start = 0.5);
  Real r1_vx_lr(start = 0.0);
  Real r1_vy_lr(start = 0.0);
  Real r1_t_lr(start = 0.0) "Timestamp of last msg [s]";
  Real r2_x_lr(start = -0.433);
  Real r2_y_lr(start = -0.25);
  Real r2_vx_lr(start = 0.0);
  Real r2_vy_lr(start = 0.0);
  Real r2_t_lr(start = 0.0);
  Real r3_x_lr(start = 0.433);
  Real r3_y_lr(start = -0.25);
  Real r3_vx_lr(start = 0.0);
  Real r3_vy_lr(start = 0.0);
  Real r3_t_lr(start = 0.0);

  // --- Predicted peer positions (dead-reckoning during dropout) ---
  Real r1_x_pred, r1_y_pred;
  Real r2_x_pred, r2_y_pred;
  Real r3_x_pred, r3_y_pred;

  // --- Odometry sensor traces ---
  Real r1_odo_x, r1_odo_y, r1_odo_theta;
  Real r2_odo_x, r2_odo_y, r2_odo_theta;
  Real r3_odo_x, r3_odo_y, r3_odo_theta;

  // --- Inter-robot distances ---
  Real d12, d13, d23;

  // --- Disturbance ---
  Real dist_x, dist_y;

  // --- Performance metrics ---
  Real primary_tracking_error "Robot 1 distance to reference [m]";
  Real form_error_degraded "Formation error during dropout [m]";
  Real form_error_recovered "Formation error after dropout [m]";
  Real route_progress "Fraction of route completed [-]";
  Boolean route_completed;

  // --- Control intermediates ---
  Real e1_x, e1_y, F1_wx, F1_wy, F1_fwd, theta1_des, e1_th, omega1_des, T1_des;
  Real e2_x, e2_y, F2_wx, F2_wy, F2_fwd, theta2_des, e2_th, omega2_des, T2_des;
  Real e3_x, e3_y, F3_wx, F3_wy, F3_fwd, theta3_des, e3_th, omega3_des, T3_des;
  Real f1cx, f1cy, f2cx, f2cy, f3cx, f3cy;
  Real c1x, c1y, c2x, c2y, c3x, c3y;

equation
  // ===== Communication availability =====
  comm_available = not (time >= t_drop_start and time <= t_drop_start + t_drop_dur);

  // ===== Reference trajectory (formation centre moves along x then stops) =====
  x_ref_center = if v_route * time < x_end then v_route * time else x_end;
  y_ref_center = 0.0;
  vx_ref_center = if v_route * time < x_end then v_route else 0.0;

  // Formation offsets: equilateral triangle, side 0.866 m
  r1_x_ref = x_ref_center + 0.0;
  r1_y_ref = y_ref_center + 0.5;
  r2_x_ref = x_ref_center - 0.433;
  r2_y_ref = y_ref_center - 0.25;
  r3_x_ref = x_ref_center + 0.433;
  r3_y_ref = y_ref_center - 0.25;

  // ===== Last-received state tracking (fast first-order; freezes during dropout) =====
  der(r1_x_lr) = if comm_available then (r1_x - r1_x_lr) / dt_ctrl else 0.0;
  der(r1_y_lr) = if comm_available then (r1_y - r1_y_lr) / dt_ctrl else 0.0;
  der(r1_vx_lr) = if comm_available then (r1_v * cos(r1_theta) - r1_vx_lr) / dt_ctrl else 0.0;
  der(r1_vy_lr) = if comm_available then (r1_v * sin(r1_theta) - r1_vy_lr) / dt_ctrl else 0.0;
  der(r1_t_lr) = if comm_available then 1.0 else 0.0;

  der(r2_x_lr) = if comm_available then (r2_x - r2_x_lr) / dt_ctrl else 0.0;
  der(r2_y_lr) = if comm_available then (r2_y - r2_y_lr) / dt_ctrl else 0.0;
  der(r2_vx_lr) = if comm_available then (r2_v * cos(r2_theta) - r2_vx_lr) / dt_ctrl else 0.0;
  der(r2_vy_lr) = if comm_available then (r2_v * sin(r2_theta) - r2_vy_lr) / dt_ctrl else 0.0;
  der(r2_t_lr) = if comm_available then 1.0 else 0.0;

  der(r3_x_lr) = if comm_available then (r3_x - r3_x_lr) / dt_ctrl else 0.0;
  der(r3_y_lr) = if comm_available then (r3_y - r3_y_lr) / dt_ctrl else 0.0;
  der(r3_vx_lr) = if comm_available then (r3_v * cos(r3_theta) - r3_vx_lr) / dt_ctrl else 0.0;
  der(r3_vy_lr) = if comm_available then (r3_v * sin(r3_theta) - r3_vy_lr) / dt_ctrl else 0.0;
  der(r3_t_lr) = if comm_available then 1.0 else 0.0;

  // ===== Predicted peer positions (actual when comm available, dead-reckon when not) =====
  r1_x_pred = if comm_available then r1_x else r1_x_lr + r1_vx_lr * (time - r1_t_lr);
  r1_y_pred = if comm_available then r1_y else r1_y_lr + r1_vy_lr * (time - r1_t_lr);
  r2_x_pred = if comm_available then r2_x else r2_x_lr + r2_vx_lr * (time - r2_t_lr);
  r2_y_pred = if comm_available then r2_y else r2_y_lr + r2_vy_lr * (time - r2_t_lr);
  r3_x_pred = if comm_available then r3_x else r3_x_lr + r3_vx_lr * (time - r3_t_lr);
  r3_y_pred = if comm_available then r3_y else r3_y_lr + r3_vy_lr * (time - r3_t_lr);

  // ===== Shared environmental disturbance (active only during dropout) =====
  dist_x = if comm_available then 0.0 else dist_force;
  dist_y = 0.0;

  // ===== Inter-robot distances (using predicted positions for collision avoidance) =====
  d12 = sqrt((r1_x_pred - r2_x_pred) ^ 2 + (r1_y_pred - r2_y_pred) ^ 2 + 1e-6);
  d13 = sqrt((r1_x_pred - r3_x_pred) ^ 2 + (r1_y_pred - r3_y_pred) ^ 2 + 1e-6);
  d23 = sqrt((r2_x_pred - r3_x_pred) ^ 2 + (r2_y_pred - r3_y_pred) ^ 2 + 1e-6);

  // ===== Collision avoidance repulsive forces =====
  f1cx = (if d12 < d_safe then k_coll * (d_safe - d12) / d12 * (r1_x_pred - r2_x_pred) else 0.0)
       + (if d13 < d_safe then k_coll * (d_safe - d13) / d13 * (r1_x_pred - r3_x_pred) else 0.0);
  f1cy = (if d12 < d_safe then k_coll * (d_safe - d12) / d12 * (r1_y_pred - r2_y_pred) else 0.0)
       + (if d13 < d_safe then k_coll * (d_safe - d13) / d13 * (r1_y_pred - r3_y_pred) else 0.0);

  f2cx = (if d12 < d_safe then k_coll * (d_safe - d12) / d12 * (r2_x_pred - r1_x_pred) else 0.0)
       + (if d23 < d_safe then k_coll * (d_safe - d23) / d23 * (r2_x_pred - r3_x_pred) else 0.0);
  f2cy = (if d12 < d_safe then k_coll * (d_safe - d12) / d12 * (r2_y_pred - r1_y_pred) else 0.0)
       + (if d23 < d_safe then k_coll * (d_safe - d23) / d23 * (r2_y_pred - r3_y_pred) else 0.0);

  f3cx = (if d13 < d_safe then k_coll * (d_safe - d13) / d13 * (r3_x_pred - r1_x_pred) else 0.0)
       + (if d23 < d_safe then k_coll * (d_safe - d23) / d23 * (r3_x_pred - r2_x_pred) else 0.0);
  f3cy = (if d13 < d_safe then k_coll * (d_safe - d13) / d13 * (r3_y_pred - r1_y_pred) else 0.0)
       + (if d23 < d_safe then k_coll * (d_safe - d23) / d23 * (r3_y_pred - r2_y_pred) else 0.0);

  // ===== Distributed centroid estimates (each robot uses own pos + predicted peers) =====
  c1x = (r1_x + r2_x_pred + r3_x_pred) / 3.0;
  c1y = (r1_y + r2_y_pred + r3_y_pred) / 3.0;
  c2x = (r1_x_pred + r2_x + r3_x_pred) / 3.0;
  c2y = (r1_y_pred + r2_y + r3_y_pred) / 3.0;
  c3x = (r1_x_pred + r2_x_pred + r3_x) / 3.0;
  c3y = (r1_y_pred + r2_y_pred + r3_y) / 3.0;

  // ===== Robot 1 control =====
  e1_x = (r1_x_ref - r1_x) + k_form * (c1x + 0.0 - r1_x);
  e1_y = (r1_y_ref - r1_y) + k_form * (c1y + 0.5 - r1_y);
  theta1_des = atan2(e1_y, e1_x);
  e1_th = atan2(sin(theta1_des - r1_theta), cos(theta1_des - r1_theta));
  omega1_des = k_theta * e1_th;
  F1_wx = k_pos * e1_x - k_damp * (r1_v * cos(r1_theta) - vx_ref_center) + f1cx;
  F1_wy = k_pos * e1_y - k_damp * (r1_v * sin(r1_theta) - 0.0) + f1cy;
  F1_fwd = F1_wx * cos(r1_theta) + F1_wy * sin(r1_theta);
  T1_des = k_omega * (omega1_des - r1_omega);
  r1_tauR_raw = (r_w * F1_fwd / 2.0) + (r_w * T1_des / L_wb);
  r1_tauL_raw = (r_w * F1_fwd / 2.0) - (r_w * T1_des / L_wb);
  r1_tauR = if r1_tauR_raw > tau_max then tau_max else if r1_tauR_raw < -tau_max then -tau_max else r1_tauR_raw;
  r1_tauL = if r1_tauL_raw > tau_max then tau_max else if r1_tauL_raw < -tau_max then -tau_max else r1_tauL_raw;
  // Robot 1 dynamics
  der(r1_x) = r1_v * cos(r1_theta);
  der(r1_y) = r1_v * sin(r1_theta);
  der(r1_theta) = r1_omega;
  der(r1_v) = ((r1_tauR + r1_tauL) / r_w - b_lin * r1_v + dist_x * cos(r1_theta) + dist_y * sin(r1_theta)) / m_robot;
  der(r1_omega) = ((r1_tauR - r1_tauL) * L_wb / (2.0 * r_w) - c_rot * r1_omega) / I_body;
  // Odometry
  r1_odo_x = r1_x;
  r1_odo_y = r1_y;
  r1_odo_theta = r1_theta;

  // ===== Robot 2 control =====
  e2_x = (r2_x_ref - r2_x) + k_form * (c2x - 0.433 - r2_x);
  e2_y = (r2_y_ref - r2_y) + k_form * (c2y - 0.25 - r2_y);
  theta2_des = atan2(e2_y, e2_x);
  e2_th = atan2(sin(theta2_des - r2_theta), cos(theta2_des - r2_theta));
  omega2_des = k_theta * e2_th;
  F2_wx = k_pos * e2_x - k_damp * (r2_v * cos(r2_theta) - vx_ref_center) + f2cx;
  F2_wy = k_pos * e2_y - k_damp * (r2_v * sin(r2_theta) - 0.0) + f2cy;
  F2_fwd = F2_wx * cos(r2_theta) + F2_wy * sin(r2_theta);
  T2_des = k_omega * (omega2_des - r2_omega);
  r2_tauR_raw = (r_w * F2_fwd / 2.0) + (r_w * T2_des / L_wb);
  r2_tauL_raw = (r_w * F2_fwd / 2.0) - (r_w * T2_des / L_wb);
  r2_tauR = if r2_tauR_raw > tau_max then tau_max else if r2_tauR_raw < -tau_max then -tau_max else r2_tauR_raw;
  r2_tauL = if r2_tauL_raw > tau_max then tau_max else if r2_tauL_raw < -tau_max then -tau_max else r2_tauL_raw;
  der(r2_x) = r2_v * cos(r2_theta);
  der(r2_y) = r2_v * sin(r2_theta);
  der(r2_theta) = r2_omega;
  der(r2_v) = ((r2_tauR + r2_tauL) / r_w - b_lin * r2_v + dist_x * cos(r2_theta) + dist_y * sin(r2_theta)) / m_robot;
  der(r2_omega) = ((r2_tauR - r2_tauL) * L_wb / (2.0 * r_w) - c_rot * r2_omega) / I_body;
  r2_odo_x = r2_x;
  r2_odo_y = r2_y;
  r2_odo_theta = r2_theta;

  // ===== Robot 3 control =====
  e3_x = (r3_x_ref - r3_x) + k_form * (c3x + 0.433 - r3_x);
  e3_y = (r3_y_ref - r3_y) + k_form * (c3y - 0.25 - r3_y);
  theta3_des = atan2(e3_y, e3_x);
  e3_th = atan2(sin(theta3_des - r3_theta), cos(theta3_des - r3_theta));
  omega3_des = k_theta * e3_th;
  F3_wx = k_pos * e3_x - k_damp * (r3_v * cos(r3_theta) - vx_ref_center) + f3cx;
  F3_wy = k_pos * e3_y - k_damp * (r3_v * sin(r3_theta) - 0.0) + f3cy;
  F3_fwd = F3_wx * cos(r3_theta) + F3_wy * sin(r3_theta);
  T3_des = k_omega * (omega3_des - r3_omega);
  r3_tauR_raw = (r_w * F3_fwd / 2.0) + (r_w * T3_des / L_wb);
  r3_tauL_raw = (r_w * F3_fwd / 2.0) - (r_w * T3_des / L_wb);
  r3_tauR = if r3_tauR_raw > tau_max then tau_max else if r3_tauR_raw < -tau_max then -tau_max else r3_tauR_raw;
  r3_tauL = if r3_tauL_raw > tau_max then tau_max else if r3_tauL_raw < -tau_max then -tau_max else r3_tauL_raw;
  der(r3_x) = r3_v * cos(r3_theta);
  der(r3_y) = r3_v * sin(r3_theta);
  der(r3_theta) = r3_omega;
  der(r3_v) = ((r3_tauR + r3_tauL) / r_w - b_lin * r3_v + dist_x * cos(r3_theta) + dist_y * sin(r3_theta)) / m_robot;
  der(r3_omega) = ((r3_tauR - r3_tauL) * L_wb / (2.0 * r_w) - c_rot * r3_omega) / I_body;
  r3_odo_x = r3_x;
  r3_odo_y = r3_y;
  r3_odo_theta = r3_theta;

  // ===== Performance metrics =====
  primary_tracking_error = sqrt((r1_x - r1_x_ref) ^ 2 + (r1_y - r1_y_ref) ^ 2 + 1e-6);
  form_error_degraded = if not comm_available then
    sqrt((d12 - 0.866) ^ 2 + (d13 - 0.866) ^ 2 + (d23 - 0.866) ^ 2 + 1e-6) else 0.0;
  form_error_recovered = if comm_available and time > t_drop_start + t_drop_dur then
    sqrt((d12 - 0.866) ^ 2 + (d13 - 0.866) ^ 2 + (d23 - 0.866) ^ 2 + 1e-6) else 0.0;
  route_progress = r1_x / x_end;
  route_completed = r1_x >= 0.99 * x_end;

  annotation(
    experiment(StartTime = 0, StopTime = 12, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info = "GroundTrioResilientC: Three 18 kg differential-drive warehouse robots "
      + "with distributed formation control, dead-reckoning prediction during a 0.9 s "
      + "communication dropout (5.55-6.45 s), collision avoidance, bounded 11 N.m wheel drives, "
      + "and post-dropout formation recovery. 125 Hz, 12 s. "
      + "Assumed physical parameters (wheel radius, inertia, drag) are labelled above."));
end GroundTrioResilientC;