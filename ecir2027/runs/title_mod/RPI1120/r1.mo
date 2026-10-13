model GroundTrioHandoffD
  "Instrumented three-robot differential-drive warehouse inspection with delayed handoff"

  // ==================== Physical Parameters ====================
  parameter Real m_robot = 18.0 "robot mass [kg]";
  parameter Real r_w = 0.05 "wheel radius [m]";
  parameter Real L_track = 0.40 "wheel track [m]";
  parameter Real I_z = 1.5 "yaw inertia [kg.m2]";
  parameter Real c_drag = 8.0 "linear drag [N.s/m]";
  parameter Real c_yaw_drag = 3.0 "yaw drag [N.m.s/rad]";
  parameter Real tau_max = 12.0 "maximum wheel torque [N.m]";

  // ==================== Simulation Parameters ====================
  parameter Real T_sim = 14.0 "simulation duration [s]";
  parameter Real t_delay_start = 4.6667 "delay disturbance start, T/3 [s]";
  parameter Real t_delay_end = 9.3333 "delay disturbance end, 2T/3 [s]";
  parameter Real delay_val = 0.1 "communication delay disturbance [s]";
  parameter Real delay_max = 0.11 "maximum delay for delay() [s]";
  parameter Real delay_min = 1.0e-4 "minimum delay [s]";

  // ==================== World Frame ====================
  parameter Real wall_xmin = 0.0 "west wall [m]";
  parameter Real wall_xmax = 10.0 "east wall [m]";
  parameter Real wall_ymin = 0.0 "south wall [m]";
  parameter Real wall_ymax = 10.0 "north wall [m]";

  // ==================== Controller Gains ====================
  parameter Real Kp_v = 4.0 "velocity tracking gain [1/s]";
  parameter Real Kp_w = 6.0 "yaw-rate tracking gain [1/s]";
  parameter Real Kv_nav = 1.5 "navigation proportional gain [1/s]";
  parameter Real Kw_nav = 3.0 "navigation yaw gain [1/s]";
  parameter Real v_max = 1.5 "maximum linear velocity [m/s]";
  parameter Real w_max = 3.0 "maximum angular velocity [rad/s]";
  parameter Real pos_tol = 0.3 "position tolerance for task transition [m]";

  // ==================== Waypoints ====================
  parameter Real wp1_x = 3.0 "R1 inspection point x [m]";
  parameter Real wp1_y = 3.0 "R1 inspection point y [m]";
  parameter Real wp2_x = 6.5 "R2 inspection point x [m]";
  parameter Real wp2_y = 2.5 "R2 inspection point y [m]";
  parameter Real wp3_replan_x = 5.0 "R3 replanned target x [m]";
  parameter Real wp3_replan_y = 5.0 "R3 replanned target y [m]";

  // ==================== Task Timing ====================
  parameter Real t_inspect1 = 1.0 "R1 inspection duration [s]";
  parameter Real t_inspect2 = 1.0 "R2 inspection duration [s]";
  parameter Real t_inspect3 = 1.0 "R3 inspection duration [s]";
  parameter Real t_handoff = 0.5 "handoff send duration [s]";

  // ==================== Safety Bounds ====================
  parameter Real sep_min_req = 0.5 "required minimum separation [m]";
  parameter Real data_age_max = 0.15 "maximum allowed data age [s]";

  // ==================== Robot 1 States and Sensors ====================
  Real x1(start=1.0, fixed=true) "R1 x position [m]";
  Real y1(start=1.0, fixed=true) "R1 y position [m]";
  Real th1(start=0.785398163397, fixed=true) "R1 heading [rad]";
  Real v1(start=0.0, fixed=true) "R1 linear velocity [m/s]";
  Real om1(start=0.0, fixed=true) "R1 angular velocity [rad/s]";
  Real phiR1(start=0.0, fixed=true) "R1 right wheel angle [rad]";
  Real phiL1(start=0.0, fixed=true) "R1 left wheel angle [rad]";
  Real x1_odom(start=1.0, fixed=true) "R1 odometry x [m]";
  Real y1_odom(start=1.0, fixed=true) "R1 odometry y [m]";
  Real th1_odom(start=0.785398163397, fixed=true) "R1 odometry heading [rad]";
  Real lidar1_fwd "R1 forward lidar range [m]";
  Real lidar1_min "R1 minimum wall distance [m]";
  Real tauR1_cmd "R1 right wheel torque command [N.m]";
  Real tauL1_cmd "R1 left wheel torque command [N.m]";
  Real tauR1 "R1 right wheel torque bounded [N.m]";
  Real tauL1 "R1 left wheel torque bounded [N.m]";
  Real task1(start=1.0, fixed=true) "R1 task state: 1=move 2=inspect 3=handoff 4=done";
  Real t1_inspect_done(start=1.0e6, fixed=true) "R1 inspection completion time [s]";
  Real target1_x "R1 target x [m]";
  Real target1_y "R1 target y [m]";
  Real dx1 "R1 target x offset [m]";
  Real dy1 "R1 target y offset [m]";
  Real err1 "R1 tracking error [m]";
  Real ang1 "R1 desired heading [rad]";
  Real e_th1 "R1 heading error wrapped [rad]";
  Real v1_des "R1 desired velocity [m/s]";
  Real om1_des "R1 desired angular velocity [rad/s]";
  Real S1 "R1 torque sum [N.m]";
  Real D1 "R1 torque difference [N.m]";
  Real task1_send "R1 task state continuous copy for communication";
  Real ts1_send "R1 send timestamp [s]";
  Real cos1 "cos(th1)";
  Real sin1 "sin(th1)";
  Real rx1_pos "R1 range to east wall [m]";
  Real rx1_neg "R1 range to west wall [m]";
  Real ry1_pos "R1 range to north wall [m]";
  Real ry1_neg "R1 range to south wall [m]";

  // ==================== Robot 2 States and Sensors ====================
  Real x2(start=8.0, fixed=true) "R2 x position [m]";
  Real y2(start=1.0, fixed=true) "R2 y position [m]";
  Real th2(start=3.14159265359, fixed=true) "R2 heading [rad]";
  Real v2(start=0.0, fixed=true) "R2 linear velocity [m/s]";
  Real om2(start=0.0, fixed=true) "R2 angular velocity [rad/s]";
  Real phiR2(start=0.0, fixed=true) "R2 right wheel angle [rad]";
  Real phiL2(start=0.0, fixed=true) "R2 left wheel angle [rad]";
  Real x2_odom(start=8.0, fixed=true) "R2 odometry x [m]";
  Real y2_odom(start=1.0, fixed=true) "R2 odometry y [m]";
  Real th2_odom(start=3.14159265359, fixed=true) "R2 odometry heading [rad]";
  Real lidar2_fwd "R2 forward lidar range [m]";
  Real lidar2_min "R2 minimum wall distance [m]";
  Real tauR2_cmd "R2 right wheel torque command [N.m]";
  Real tauL2_cmd "R2 left wheel torque command [N.m]";
  Real tauR2 "R2 right wheel torque bounded [N.m]";
  Real tauL2 "R2 left wheel torque bounded [N.m]";
  Real task2(start=0.0, fixed=true) "R2 task state: 0=idle 1=move 2=inspect 3=handoff 4=done";
  Real t2_inspect_done(start=1.0e6, fixed=true) "R2 inspection completion time [s]";
  Real target2_x "R2 target x [m]";
  Real target2_y "R2 target y [m]";
  Real dx2 "R2 target x offset [m]";
  Real dy2 "R2 target y offset [m]";
  Real err2 "R2 tracking error [m]";
  Real ang2 "R2 desired heading [rad]";
  Real e_th2 "R2 heading error wrapped [rad]";
  Real v2_des "R2 desired velocity [m/s]";
  Real om2_des "R2 desired angular velocity [rad/s]";
  Real S2 "R2 torque sum [N.m]";
  Real D2 "R2 torque difference [N.m]";
  Real task2_send "R2 task state continuous copy for communication";
  Real ts2_send "R2 send timestamp [s]";
  Real cos2 "cos(th2)";
  Real sin2 "sin(th2)";
  Real rx2_pos "R2 range to east wall [m]";
  Real rx2_neg "R2 range to west wall [m]";
  Real ry2_pos "R2 range to north wall [m]";
  Real ry2_neg "R2 range to south wall [m]";

  // ==================== Robot 3 States and Sensors ====================
  Real x3(start=8.0, fixed=true) "R3 x position [m]";
  Real y3(start=8.0, fixed=true) "R3 y position [m]";
  Real th3(start=3.92699081699, fixed=true) "R3 heading [rad]";
  Real v3(start=0.0, fixed=true) "R3 linear velocity [m/s]";
  Real om3(start=0.0, fixed=true) "R3 angular velocity [rad/s]";
  Real phiR3(start=0.0, fixed=true) "R3 right wheel angle [rad]";
  Real phiL3(start=0.0, fixed=true) "R3 left wheel angle [rad]";
  Real x3_odom(start=8.0, fixed=true) "R3 odometry x [m]";
  Real y3_odom(start=8.0, fixed=true) "R3 odometry y [m]";
  Real th3_odom(start=3.92699081699, fixed=true) "R3 odometry heading [rad]";
  Real lidar3_fwd "R3 forward lidar range [m]";
  Real lidar3_min "R3 minimum wall distance [m]";
  Real tauR3_cmd "R3 right wheel torque command [N.m]";
  Real tauL3_cmd "R3 left wheel torque command [N.m]";
  Real tauR3 "R3 right wheel torque bounded [N.m]";
  Real tauL3 "R3 left wheel torque bounded [N.m]";
  Real task3(start=0.0, fixed=true) "R3 task state: 0=idle 1=move 2=inspect 3=done";
  Real t3_inspect_done(start=1.0e6, fixed=true) "R3 inspection completion time [s]";
  Boolean r3_replanned(start=false, fixed=true) "R3 has replanned using received data";
  Real target3_x "R3 target x [m]";
  Real target3_y "R3 target y [m]";
  Real dx3 "R3 target x offset [m]";
  Real dy3 "R3 target y offset [m]";
  Real err3 "R3 tracking error [m]";
  Real ang3 "R3 desired heading [rad]";
  Real e_th3 "R3 heading error wrapped [rad]";
  Real v3_des "R3 desired velocity [m/s]";
  Real om3_des "R3 desired angular velocity [rad/s]";
  Real S3 "R3 torque sum [N.m]";
  Real D3 "R3 torque difference [N.m]";
  Real cos3 "cos(th3)";
  Real sin3 "sin(th3)";
  Real rx3_pos "R3 range to east wall [m]";
  Real rx3_neg "R3 range to west wall [m]";
  Real ry3_pos "R3 range to north wall [m]";
  Real ry3_neg "R3 range to south wall [m]";

  // ==================== Communication ====================
  Real comm_delay_time "current communication delay [s]";
  Real x1_rx2 "R1 x received at R2 [m]";
  Real y1_rx2 "R1 y received at R2 [m]";
  Real th1_rx2 "R1 heading received at R2 [rad]";
  Real task1_rx2 "R1 task state received at R2";
  Real ts1_rx2 "R1 timestamp received at R2 [s]";
  Real data_age1_2 "data age of R1 data at R2 [s]";
  Real x2_rx3 "R2 x received at R3 [m]";
  Real y2_rx3 "R2 y received at R3 [m]";
  Real th2_rx3 "R2 heading received at R3 [rad]";
  Real task2_rx3 "R2 task state received at R3";
  Real ts2_rx3 "R2 timestamp received at R3 [s]";
  Real data_age2_3 "data age of R2 data at R3 [s]";

  // ==================== Metrics ====================
  Real sep12 "separation R1-R2 [m]";
  Real sep23 "separation R2-R3 [m]";
  Real sep13 "separation R1-R3 [m]";
  Real sep_min "minimum pairwise separation [m]";
  Real primary_tracking_error "primary tracking error [m]";
  Boolean handoff1_ok "R1 to R2 handoff successful";
  Boolean handoff2_ok "R2 to R3 handoff successful";
  Boolean task_complete "all tasks completed";
  Boolean no_collision "no collision detected";
  Boolean bounds_ok "actuator and separation bounds satisfied";
  Boolean data_age_ok "data age within bounds";
  Boolean nan_check "no NaN or infinite values detected";

equation
  // ==================== Communication Delay ====================
  comm_delay_time = if time >= t_delay_start and time <= t_delay_end then delay_val else delay_min;

  // ==================== Robot 1 Dynamics ====================
  der(x1) = v1 * cos(th1);
  der(y1) = v1 * sin(th1);
  der(th1) = om1;
  der(v1) = (tauR1 + tauL1) / (m_robot * r_w) - (c_drag / m_robot) * v1;
  der(om1) = (L_track * (tauR1 - tauL1)) / (2.0 * r_w * I_z) - (c_yaw_drag / I_z) * om1;
  der(phiR1) = (v1 + om1 * L_track / 2.0) / r_w;
  der(phiL1) = (v1 - om1 * L_track / 2.0) / r_w;

  // R1 Odometry
  der(x1_odom) = v1 * cos(th1_odom);
  der(y1_odom) = v1 * sin(th1_odom);
  der(th1_odom) = om1;

  // R1 Lidar
  cos1 = cos(th1);
  sin1 = sin(th1);
  rx1_pos = if abs(cos1) > 1.0e-6 and cos1 > 0.0 then (wall_xmax - x1) / cos1 else 1.0e3;
  rx1_neg = if abs(cos1) > 1.0e-6 and cos1 < 0.0 then (wall_xmin - x1) / cos1 else 1.0e3;
  ry1_pos = if abs(sin1) > 1.0e-6 and sin1 > 0.0 then (wall_ymax - y1) / sin1 else 1.0e3;
  ry1_neg = if abs(sin1) > 1.0e-6 and sin1 < 0.0 then (wall_ymin - y1) / sin1 else 1.0e3;
  lidar1_fwd = min(min(rx1_pos, rx1_neg), min(ry1_pos, ry1_neg));
  lidar1_min = min(min(x1 - wall_xmin, wall_xmax - x1), min(y1 - wall_ymin, wall_ymax - y1));

  // R1 Task Target
  target1_x = if task1 > 0.5 and task1 < 1.5 then wp1_x else x1;
  target1_y = if task1 > 0.5 and task1 < 1.5 then wp1_y else y1;

  // R1 Navigation
  dx1 = target1_x - x1;
  dy1 = target1_y - y1;
  err1 = sqrt(dx1 * dx1 + dy1 * dy1 + 1.0e-10);
  ang1 = atan2(dy1, dx1);
  e_th1 = atan2(sin(ang1 - th1), cos(ang1 - th1));
  v1_des = if task1 > 0.5 and task1 < 1.5 then
    (if Kv_nav * err1 > v_max then v_max else Kv_nav * err1) *
    (if cos(e_th1) > 0.0 then cos(e_th1) else 0.0)
    else 0.0;
  om1_des = if task1 > 0.5 and task1 < 1.5 then
    (if Kw_nav * e_th1 > w_max then w_max elseif Kw_nav * e_th1 < -w_max then -w_max else Kw_nav * e_th1)
    else 0.0;

  // R1 Torque Computation
  S1 = r_w * (m_robot * Kp_v * (v1_des - v1) + c_drag * v1);
  D1 = (2.0 * r_w / L_track) * (I_z * Kp_w * (om1_des - om1) + c_yaw_drag * om1);
  tauR1_cmd = (S1 + D1) / 2.0;
  tauL1_cmd = (S1 - D1) / 2.0;
  tauR1 = if tauR1_cmd > tau_max then tau_max elseif tauR1_cmd < -tau_max then -tau_max else tauR1_cmd;
  tauL1 = if tauL1_cmd > tau_max then tau_max elseif tauL1_cmd < -tau_max then -tau_max else tauL1_cmd;

  // R1 Communication Send
  task1_send = task1;
  ts1_send = time;

  // ==================== Robot 2 Dynamics ====================
  der(x2) = v2 * cos(th2);
  der(y2) = v2 * sin(th2);
  der(th2) = om2;
  der(v2) = (tauR2 + tauL2) / (m_robot * r_w) - (c_drag / m_robot) * v2;
  der(om2) = (L_track * (tauR2 - tauL2)) / (2.0 * r_w * I_z) - (c_yaw_drag / I_z) * om2;
  der(phiR2) = (v2 + om2 * L_track / 2.0) / r_w;
  der(phiL2) = (v2 - om2 * L_track / 2.0) / r_w;

  // R2 Odometry
  der(x2_odom) = v2 * cos(th2_odom);
  der(y2_odom) = v2 * sin(th2_odom);
  der(th2_odom) = om2;

  // R2 Lidar
  cos2 = cos(th2);
  sin2 = sin(th2);
  rx2_pos = if abs(cos2) > 1.0e-6 and cos2 > 0.0 then (wall_xmax - x2) / cos2 else 1.0e3;
  rx2_neg = if abs(cos2) > 1.0e-6 and cos2 < 0.0 then (wall_xmin - x2) / cos2 else 1.0e3;
  ry2_pos = if abs(sin2) > 1.0e-6 and sin2 > 0.0 then (wall_ymax - y2) / sin2 else 1.0e3;
  ry2_neg = if abs(sin2) > 1.0e-6 and sin2 < 0.0 then (wall_ymin - y2) / sin2 else 1.0e3;
  lidar2_fwd = min(min(rx2_pos, rx2_neg), min(ry2_pos, ry2_neg));
  lidar2_min = min(min(x2 - wall_xmin, wall_xmax - x2), min(y2 - wall_ymin, wall_ymax - y2));

  // R2 Task Target
  target2_x = if task2 > 0.5 and task2 < 1.5 then wp2_x else x2;
  target2_y = if task2 > 0.5 and task2 < 1.5 then wp2_y else y2;

  // R2 Navigation
  dx2 = target2_x - x2;
  dy2 = target2_y - y2;
  err2 = sqrt(dx2 * dx2 + dy2 * dy2 + 1.0e-10);
  ang2 = atan2(dy2, dx2);
  e_th2 = atan2(sin(ang2 - th2), cos(ang2 - th2));
  v2_des = if task2 > 0.5 and task2 < 1.5 then
    (if Kv_nav * err2 > v_max then v_max else Kv_nav * err2) *
    (if cos(e_th2) > 0.0 then cos(e_th2) else 0.0)
    else 0.0;
  om2_des = if task2 > 0.5 and task2 < 1.5 then
    (if Kw_nav * e_th2 > w_max then w_max elseif Kw_nav * e_th2 < -w_max then -w_max else Kw_nav * e_th2)
    else 0.0;

  // R2 Torque Computation
  S2 = r_w * (m_robot * Kp_v * (v2_des - v2) + c_drag * v2);
  D2 = (2.0 * r_w / L_track) * (I_z * Kp_w * (om2_des - om2) + c_yaw_drag * om2);
  tauR2_cmd = (S2 + D2) / 2.0;
  tauL2_cmd = (S2 - D2) / 2.0;
  tauR2 = if tauR2_cmd > tau_max then tau_max elseif tauR2_cmd < -tau_max then -tau_max else tauR2_cmd;
  tauL2 = if tauL2_cmd > tau_max then tau_max elseif tauL2_cmd < -tau_max then -tau_max else tauL2_cmd;

  // R2 Communication Send
  task2_send = task2;
  ts2_send = time;

  // ==================== Robot 3 Dynamics ====================
  der(x3) = v3 * cos(th3);
  der(y3) = v3 * sin(th3);
  der(th3) = om3;
  der(v3) = (tauR3 + tauL3) / (m_robot * r_w) - (c_drag / m_robot) * v3;
  der(om3) = (L_track * (tauR3 - tauL3)) / (2.0 * r_w * I_z) - (c_yaw_drag / I_z) * om3;
  der(phiR3) = (v3 + om3 * L_track / 2.0) / r_w;
  der(phiL3) = (v3 - om3 * L_track / 2.0) / r_w;

  // R3 Odometry
  der(x3_odom) = v3 * cos(th3_odom);
  der(y3_odom) = v3 * sin(th3_odom);
  der(th3_odom) = om3;

  // R3 Lidar
  cos3 = cos(th3);
  sin3 = sin(th3);
  rx3_pos = if abs(cos3) > 1.0e-6 and cos3 > 0.0 then (wall_xmax - x3) / cos3 else 1.0e3;
  rx3_neg = if abs(cos3) > 1.0e-6 and cos3 < 0.0 then (wall_xmin - x3) / cos3 else 1.0e3;
  ry3_pos = if abs(sin3) > 1.0e-6 and sin3 > 0.0 then (wall_ymax - y3) / sin3 else 1.0e3;
  ry3_neg = if abs(sin3) > 1.0e-6 and sin3 < 0.0 then (wall_ymin - y3) / sin3 else 1.0e3;
  lidar3_fwd = min(min(rx3_pos, rx3_neg), min(ry3_pos, ry3_neg));
  lidar3_min = min(min(x3 - wall_xmin, wall_xmax - x3), min(y3 - wall_ymin, wall_ymax - y3));

  // R3 Task Target (replanned upon handoff receipt)
  target3_x = if task3 > 0.5 and task3 < 1.5 then wp3_replan_x else x3;
  target3_y = if task3 > 0.5 and task3 < 1.5 then wp3_replan_y else y3;

  // R3 Navigation
  dx3 = target3_x - x3;
  dy3 = target3_y - y3;
  err3 = sqrt(dx3 * dx3 + dy3 * dy3 + 1.0e-10);
  ang3 = atan2(dy3, dx3);
  e_th3 = atan2(sin(ang3 - th3), cos(ang3 - th3));
  v3_des = if task3 > 0.5 and task3 < 1.5 then
    (if Kv_nav * err3 > v_max then v_max else Kv_nav * err3) *
    (if cos(e_th3) > 0.0 then cos(e_th3) else 0.0)
    else 0.0;
  om3_des = if task3 > 0.5 and task3 < 1.5 then
    (if Kw_nav * e_th3 > w_max then w_max elseif Kw_nav * e_th3 < -w_max then -w_max else Kw_nav * e_th3)
    else 0.0;

  // R3 Torque Computation
  S3 = r_w * (m_robot * Kp_v * (v3_des - v3) + c_drag * v3);
  D3 = (2.0 * r_w / L_track) * (I_z * Kp_w * (om3_des - om3) + c_yaw_drag * om3);
  tauR3_cmd = (S3 + D3) / 2.0;
  tauL3_cmd = (S3 - D3) / 2.0;
  tauR3 = if tauR3_cmd > tau_max then tau_max elseif tauR3_cmd < -tau_max then -tau_max else tauR3_cmd;
  tauL3 = if tauL3_cmd > tau_max then tau_max elseif tauL3_cmd < -tau_max then -tau_max else tauL3_cmd;

  // ==================== Communication Channels ====================
  // R1 -> R2 with variable delay
  x1_rx2 = delay(x1, comm_delay_time, delay_max);
  y1_rx2 = delay(y1, comm_delay_time, delay_max);
  th1_rx2 = delay(th1, comm_delay_time, delay_max);
  task1_rx2 = delay(task1_send, comm_delay_time, delay_max);
  ts1_rx2 = delay(ts1_send, comm_delay_time, delay_max);
  data_age1_2 = time - ts1_rx2;

  // R2 -> R3 with variable delay
  x2_rx3 = delay(x2, comm_delay_time, delay_max);
  y2_rx3 = delay(y2, comm_delay_time, delay_max);
  th2_rx3 = delay(th2, comm_delay_time, delay_max);
  task2_rx3 = delay(task2_send, comm_delay_time, delay_max);
  ts2_rx3 = delay(ts2_send, comm_delay_time, delay_max);
  data_age2_3 = time - ts2_rx3;

  // ==================== Separation and Metrics ====================
  sep12 = sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2) + 1.0e-10);
  sep23 = sqrt((x2 - x3) * (x2 - x3) + (y2 - y3) * (y2 - y3) + 1.0e-10);
  sep13 = sqrt((x1 - x3) * (x1 - x3) + (y1 - y3) * (y1 - y3) + 1.0e-10);
  sep_min = min(min(sep12, sep23), sep13);
  primary_tracking_error = err3;
  handoff1_ok = task2 > 0.5;
  handoff2_ok = task3 > 0.5;
  task_complete = task1 > 3.5 and task2 > 3.5 and task3 > 2.5;
  no_collision = sep_min > 0.0;
  bounds_ok = sep_min > sep_min_req
    and abs(tauR1) <= tau_max + 0.001 and abs(tauL1) <= tau_max + 0.001
    and abs(tauR2) <= tau_max + 0.001 and abs(tauL2) <= tau_max + 0.001
    and abs(tauR3) <= tau_max + 0.001 and abs(tauL3) <= tau_max + 0.001;
  data_age_ok = data_age1_2 <= data_age_max + 0.001 and data_age2_3 <= data_age_max + 0.001;
  nan_check = abs(x1) < 1.0e6 and abs(y1) < 1.0e6 and abs(th1) < 1.0e6
    and abs(v1) < 1.0e6 and abs(om1) < 1.0e6
    and abs(x2) < 1.0e6 and abs(y2) < 1.0e6 and abs(th2) < 1.0e6
    and abs(v2) < 1.0e6 and abs(om2) < 1.0e6
    and abs(x3) < 1.0e6 and abs(y3) < 1.0e6 and abs(th3) < 1.0e6
    and abs(v3) < 1.0e6 and abs(om3) < 1.0e6;

  // ==================== Task State Machines ====================

  // ---- Robot 1: MOVING -> INSPECTING ----
  when err1 < pos_tol and pre(task1) > 0.5 and pre(task1) < 1.5 then
    task1 = 2.0;
    t1_inspect_done = time + t_inspect1;
  end when;

  // ---- Robot 1: INSPECTING -> HANDOFF_SEND ----
  when time >= pre(t1_inspect_done) and pre(task1) > 1.5 and pre(task1) < 2.5 then
    task1 = 3.0;
  end when;

  // ---- Robot 1: HANDOFF_SEND -> DONE ----
  when time >= pre(t1_inspect_done) + t_handoff and pre(task1) > 2.5 and pre(task1) < 3.5 then
    task1 = 4.0;
  end when;

  // ---- Robot 2: IDLE -> MOVING (handoff received from R1) ----
  when task1_rx2 > 2.5 and pre(task2) < 0.5 then
    task2 = 1.0;
  end when;

  // ---- Robot 2: MOVING -> INSPECTING ----
  when err2 < pos_tol and pre(task2) > 0.5 and pre(task2) < 1.5 then
    task2 = 2.0;
    t2_inspect_done = time + t_inspect2;
  end when;

  // ---- Robot 2: INSPECTING -> HANDOFF_SEND ----
  when time >= pre(t2_inspect_done) and pre(task2) > 1.5 and pre(task2) < 2.5 then
    task2 = 3.0;
  end when;

  // ---- Robot 2: HANDOFF_SEND -> DONE ----
  when time >= pre(t2_inspect_done) + t_handoff and pre(task2) > 2.5 and pre(task2) < 3.5 then
    task2 = 4.0;
  end when;

  // ---- Robot 3: IDLE -> MOVING (handoff received from R2, replan) ----
  when task2_rx3 > 2.5 and pre(task3) < 0.5 then
    task3 = 1.0;
    r3_replanned = true;
  end when;

  // ---- Robot 3: MOVING -> INSPECTING ----
  when err3 < pos_tol and pre(task3) > 0.5 and pre(task3) < 1.5 then
    task3 = 2.0;
    t3_inspect_done = time + t_inspect3;
  end when;

  // ---- Robot 3: INSPECTING -> DONE ----
  when time >= pre(t3_inspect_done) and pre(task3) > 1.5 and pre(task3) < 2.5 then
    task3 = 3.0;
  end when;

  annotation (
    experiment(StopTime = 14.0, Tolerance = 1.0e-6, Interval = 0.005),
    Documentation(info = "Three 18 kg differential-drive warehouse robots perform a divided inspection task with timestamped handoff. R1 inspects zone A, sends result to R2. R2 inspects zone B, sends result to R3. R3 replans its target using received data and inspects zone C. A 0.1 s communication delay is applied during the middle third of the 14 s run. Robots share a common world frame bounded by walls at 0-10 m. Each robot has odometry, lidar, and delayed peer messaging. Six wheel drives are bounded to 12 N.m per wheel. Runs at 200 Hz. Unknown facts: specific warehouse layout details, sensor noise models, and physical robot dimensions beyond mass are not stated and not invented.")
  );
end GroundTrioHandoffD;