model GroundPairResilientA
  "Two 14 kg differential-drive robots with resilient coordination through 0.5 s communication dropout"

  // ===== Given physical parameters =====
  parameter Real m_robot = 14.0 "Robot mass [kg]";
  parameter Real r_wheel = 0.09 "Wheel radius [m]";
  parameter Real tau_max = 7.2 "Per-wheel torque limit [N.m]";

  // ===== Estimated parameters (not specified in requirement) =====
  parameter Real L_wb = 0.20 "Wheel base [m] - estimated";
  parameter Real J_robot = 0.12 "Yaw inertia [kg.m^2] - estimated";
  parameter Real b_drag = 1.2 "Linear viscous drag [N.s/m] - estimated";
  parameter Real b_yaw = 0.08 "Yaw viscous drag [N.m.s] - estimated";

  // ===== Controller gains (estimated) =====
  parameter Real Kp_track = 2.0 "Route tracking gain";
  parameter Real Kp_v = 20.0 "Velocity loop gain [N.s/m]";
  parameter Real Kp_omega = 3.0 "Angular velocity loop gain [N.m.s/rad]";
  parameter Real Kp_head = 2.5 "Heading-to-yaw-rate gain [1/s]";
  parameter Real Kp_form = 2.0 "Formation tracking gain";
  parameter Real v_max = 1.2 "Max velocity command [m/s]";
  parameter Real safe_dist = 0.5 "Safe distance [m]";
  parameter Real Kp_avoid = 10.0 "Collision avoidance gain [N]";

  // ===== Scenario parameters =====
  parameter Real t_total = 8.0 "Scenario duration [s]";
  parameter Real f_ctrl = 80.0 "Control rate [Hz]";
  parameter Real dt_ctrl = 1.0 / f_ctrl "Control period [s]";
  parameter Real t_drop_start = 3.0 "Dropout start [s] (middle third of 8 s)";
  parameter Real t_drop_dur = 0.5 "Dropout duration [s]";
  parameter Real t_drop_end = t_drop_start + t_drop_dur "Dropout end [s]";
  parameter Real F_dist = 8.0 "Shared disturbance force [N]";

  // ===== Route =====
  parameter Real x_goal = 5.0 "Primary goal x [m]";
  parameter Real y_goal = 0.0 "Primary goal y [m]";
  parameter Real d_form = 1.5 "Formation separation [m]";

  // ===== Robot 1 states (primary) =====
  Real x1(start=0.0, fixed=true) "R1 x [m]";
  Real y1(start=0.0, fixed=true) "R1 y [m]";
  Real theta1(start=0.0, fixed=true) "R1 heading [rad]";
  Real v1(start=0.0, fixed=true) "R1 speed [m/s]";
  Real omega1(start=0.0, fixed=true) "R1 yaw rate [rad/s]";

  // ===== Robot 2 states (follower) =====
  Real x2(start=0.0, fixed=true) "R2 x [m]";
  Real y2(start=d_form, fixed=true) "R2 y [m]";
  Real theta2(start=0.0, fixed=true) "R2 heading [rad]";
  Real v2(start=0.0, fixed=true) "R2 speed [m/s]";
  Real omega2(start=0.0, fixed=true) "R2 yaw rate [rad/s]";

  // ===== Four wheel-torque command channels =====
  Real tau_l1_cmd "R1 left wheel torque cmd [N.m]";
  Real tau_r1_cmd "R1 right wheel torque cmd [N.m]";
  Real tau_l2_cmd "R2 left wheel torque cmd [N.m]";
  Real tau_r2_cmd "R2 right wheel torque cmd [N.m]";
  Real tau_l1_sat "R1 left wheel saturated torque [N.m]";
  Real tau_r1_sat "R1 right wheel saturated torque [N.m]";
  Real tau_l2_sat "R2 left wheel saturated torque [N.m]";
  Real tau_r2_sat "R2 right wheel saturated torque [N.m]";

  // ===== Communication state =====
  Boolean comm_active "Communication available";
  Boolean in_dropout "Dropout active";

  // Frozen peer state captured at dropout start
  Real x1_fr(start=0.0, fixed=true) "R1 x frozen at dropout [m]";
  Real y1_fr(start=0.0, fixed=true) "R1 y frozen at dropout [m]";
  Real th1_fr(start=0.0, fixed=true) "R1 heading frozen at dropout [rad]";
  Real v1_fr(start=0.0, fixed=true) "R1 speed frozen at dropout [m/s]";
  Real x2_fr(start=0.0, fixed=true) "R2 x frozen at dropout [m]";
  Real y2_fr(start=d_form, fixed=true) "R2 y frozen at dropout [m]";
  Real th2_fr(start=0.0, fixed=true) "R2 heading frozen at dropout [rad]";
  Real v2_fr(start=0.0, fixed=true) "R2 speed frozen at dropout [m/s]";

  // Timestamps of last received peer state
  Real t_rx1(start=0.0, fixed=true) "Last rx timestamp at R1 [s]";
  Real t_rx2(start=0.0, fixed=true) "Last rx timestamp at R2 [s]";

  // Predicted peer positions during dropout
  Real x1_pred "Predicted R1 x at R2 [m]";
  Real y1_pred "Predicted R1 y at R2 [m]";
  Real x2_pred "Predicted R2 x at R1 [m]";
  Real y2_pred "Predicted R2 y at R1 [m]";

  // Effective peer positions (actual or predicted)
  Real x1_eff "Effective R1 x at R2 [m]";
  Real y1_eff "Effective R1 y at R2 [m]";
  Real x2_eff "Effective R2 x at R1 [m]";
  Real y2_eff "Effective R2 y at R1 [m]";

  // ===== Sensor traces =====
  Real enc_l1 "R1 left encoder [rad/s]";
  Real enc_r1 "R1 right encoder [rad/s]";
  Real enc_l2 "R2 left encoder [rad/s]";
  Real enc_r2 "R2 right encoder [rad/s]";
  Real imu_g1 "R1 IMU gyro [rad/s]";
  Real imu_g2 "R2 IMU gyro [rad/s]";
  Real lidar1 "R1 lidar range to R2 [m]";
  Real lidar2 "R2 lidar range to R1 [m]";
  Real d_rob "Inter-robot distance [m]";

  // ===== Controller internals =====
  Real v_des1 "R1 desired speed [m/s]";
  Real om_des1 "R1 desired yaw rate [rad/s]";
  Real th_des1 "R1 desired heading [rad]";
  Real th_err1 "R1 heading error [rad]";
  Real F1_des "R1 desired force [N]";
  Real T1_des "R1 desired yaw torque [N.m]";
  Real v_des2 "R2 desired speed [m/s]";
  Real om_des2 "R2 desired yaw rate [rad/s]";
  Real th_des2 "R2 desired heading [rad]";
  Real th_err2 "R2 heading error [rad]";
  Real F2_des "R2 desired force [N]";
  Real T2_des "R2 desired yaw torque [N.m]";
  Real efx "Formation x error [m]";
  Real efy "Formation y error [m]";
  Real efp "Formation pos error magnitude [m]";

  // ===== Error metrics =====
  Real e_track "Primary tracking error [m]";
  Real e_form "Formation error [m]";
  Real e_form_deg "Degraded formation error during dropout [m]";
  Real e_form_rec "Recovered formation error after dropout [m]";

  // ===== Disturbance and collision avoidance =====
  Real Fdx "Disturbance force x [N]";
  Real Fdy "Disturbance force y [N]";
  Real Fax "Collision avoidance force x [N]";
  Real Fay "Collision avoidance force y [N]";

  // ===== Route =====
  Real route_prog "Route progress [0-1]";
  Boolean route_done "Route complete";

equation
  // ===== Communication status =====
  comm_active = not (time >= t_drop_start and time <= t_drop_end);
  in_dropout = (time >= t_drop_start and time <= t_drop_end);

  // ===== Shared environmental disturbance (only during dropout) =====
  Fdx = if in_dropout then F_dist else 0.0;
  Fdy = if in_dropout then 0.3 * F_dist else 0.0;

  // ===== Frozen states are constants updated at dropout start =====
  der(x1_fr) = 0.0;
  der(y1_fr) = 0.0;
  der(th1_fr) = 0.0;
  der(v1_fr) = 0.0;
  der(x2_fr) = 0.0;
  der(y2_fr) = 0.0;
  der(th2_fr) = 0.0;
  der(v2_fr) = 0.0;

  // ===== Timestamps track time when comm active, freeze during dropout =====
  der(t_rx1) = if comm_active then 1.0 else 0.0;
  der(t_rx2) = if comm_active then 1.0 else 0.0;

  // ===== Capture peer state at dropout start =====
  when time >= t_drop_start then
    reinit(x1_fr, x1);
    reinit(y1_fr, y1);
    reinit(th1_fr, theta1);
    reinit(v1_fr, v1);
    reinit(x2_fr, x2);
    reinit(y2_fr, y2);
    reinit(th2_fr, theta2);
    reinit(v2_fr, v2);
  end when;

  // ===== Dead-reckoning prediction during dropout =====
  x1_pred = x1_fr + v1_fr * max(0.0, time - t_rx2) * cos(th1_fr);
  y1_pred = y1_fr + v1_fr * max(0.0, time - t_rx2) * sin(th1_fr);
  x2_pred = x2_fr + v2_fr * max(0.0, time - t_rx1) * cos(th2_fr);
  y2_pred = y2_fr + v2_fr * max(0.0, time - t_rx1) * sin(th2_fr);

  // ===== Effective peer state: actual when comm active, predicted during dropout =====
  x1_eff = if comm_active then x1 else x1_pred;
  y1_eff = if comm_active then y1 else y1_pred;
  x2_eff = if comm_active then x2 else x2_pred;
  y2_eff = if comm_active then y2 else y2_pred;

  // ===== Robot 1 dynamics (primary) =====
  der(x1) = v1 * cos(theta1);
  der(y1) = v1 * sin(theta1);
  der(theta1) = omega1;
  m_robot * der(v1) = (tau_l1_sat + tau_r1_sat) / r_wheel
    - b_drag * v1
    + (Fdx + Fax) * cos(theta1) + (Fdy + Fay) * sin(theta1);
  J_robot * der(omega1) = (tau_r1_sat - tau_l1_sat) * L_wb / (2.0 * r_wheel)
    - b_yaw * omega1;

  // ===== Robot 2 dynamics (follower) =====
  der(x2) = v2 * cos(theta2);
  der(y2) = v2 * sin(theta2);
  der(theta2) = omega2;
  m_robot * der(v2) = (tau_l2_sat + tau_r2_sat) / r_wheel
    - b_drag * v2
    + (Fdx - Fax) * cos(theta2) + (Fdy - Fay) * sin(theta2);
  J_robot * der(omega2) = (tau_r2_sat - tau_l2_sat) * L_wb / (2.0 * r_wheel)
    - b_yaw * omega2;

  // ===== Proprioceptive sensors (wheel encoders, IMU) =====
  enc_l1 = (v1 - omega1 * L_wb / 2.0) / r_wheel;
  enc_r1 = (v1 + omega1 * L_wb / 2.0) / r_wheel;
  enc_l2 = (v2 - omega2 * L_wb / 2.0) / r_wheel;
  enc_r2 = (v2 + omega2 * L_wb / 2.0) / r_wheel;
  imu_g1 = omega1;
  imu_g2 = omega2;

  // ===== Exteroceptive sensors (lidar) =====
  d_rob = sqrt(max(0.001, (x1 - x2)^2 + (y1 - y2)^2));
  lidar1 = d_rob;
  lidar2 = d_rob;

  // ===== Collision avoidance (repulsive when within safe distance) =====
  Fax = if d_rob < safe_dist then Kp_avoid * (x1 - x2) / max(d_rob, 0.01) else 0.0;
  Fay = if d_rob < safe_dist then Kp_avoid * (y1 - y2) / max(d_rob, 0.01) else 0.0;

  // ===== Robot 1 controller: route following toward goal =====
  th_des1 = atan2(y_goal - y1, x_goal - x1);
  th_err1 = atan2(sin(th_des1 - theta1), cos(th_des1 - theta1));
  v_des1 = max(-v_max, min(v_max,
    Kp_track * sqrt(max(0.0, (x_goal - x1)^2 + (y_goal - y1)^2))));
  om_des1 = Kp_head * th_err1;
  F1_des = Kp_v * (v_des1 - v1);
  T1_des = Kp_omega * (om_des1 - omega1);
  tau_l1_cmd = r_wheel * (F1_des - 2.0 * T1_des / L_wb) / 2.0;
  tau_r1_cmd = r_wheel * (F1_des + 2.0 * T1_des / L_wb) / 2.0;

  // ===== Robot 2 controller: formation following using effective peer state =====
  efx = x1_eff - x2;
  efy = (y1_eff + d_form) - y2;
  efp = sqrt(max(0.0, efx^2 + efy^2));
  th_des2 = atan2(efy, efx);
  th_err2 = atan2(sin(th_des2 - theta2), cos(th_des2 - theta2));
  v_des2 = max(-v_max, min(v_max, Kp_form * efp));
  om_des2 = Kp_head * th_err2;
  F2_des = Kp_v * (v_des2 - v2);
  T2_des = Kp_omega * (om_des2 - omega2);
  tau_l2_cmd = r_wheel * (F2_des - 2.0 * T2_des / L_wb) / 2.0;
  tau_r2_cmd = r_wheel * (F2_des + 2.0 * T2_des / L_wb) / 2.0;

  // ===== Actuator bounds (per-wheel torque saturation) =====
  tau_l1_sat = max(-tau_max, min(tau_max, tau_l1_cmd));
  tau_r1_sat = max(-tau_max, min(tau_max, tau_r1_cmd));
  tau_l2_sat = max(-tau_max, min(tau_max, tau_l2_cmd));
  tau_r2_sat = max(-tau_max, min(tau_max, tau_r2_cmd));

  // ===== Error metrics =====
  e_track = sqrt(max(0.0, (x1 - x_goal)^2 + (y1 - y_goal)^2));
  e_form = sqrt(max(0.0, (x1 - x2)^2 + (y1 + d_form - y2)^2));
  e_form_deg = if in_dropout then e_form else 0.0;
  e_form_rec = if time > t_drop_end then e_form else 0.0;

  // ===== Route completion =====
  route_prog = min(1.0, max(0.0, x1 / x_goal));
  route_done = x1 >= x_goal - 0.1;

  annotation(
    experiment(StopTime = 8.0, Tolerance = 1e-6, Interval = 0.0125),
    Documentation(info = "Two 14 kg differential-drive robots (0.09 m wheels, 7.2 N.m torque limit)
with wheel encoders, IMU, and lidar in one shared scene.
Four wheel-torque channels control the pair with distributed control.
A 0.5 s communication dropout occurs at t=3.0 s (middle third of 8 s scenario).
During dropout, each robot uses dead-reckoning prediction from last-received
peer state with timestamps. A shared environmental disturbance is applied
during the dropout. After recovery, formation is re-established.
Estimated (not specified) parameters: wheel base, yaw inertia, drag coefficients,
controller gains."));
end GroundPairResilientA;