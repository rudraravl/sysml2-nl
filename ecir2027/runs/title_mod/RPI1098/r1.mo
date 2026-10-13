model GroundPairHandoffF
  "Two differential-drive robots: divide inspection, timestamped handoff, replan with comm delay";

  // ---- Physical parameters ----
  parameter Real m_robot = 14.0  "robot mass [kg]";
  parameter Real r_wheel = 0.09  "wheel radius [m]";
  parameter Real L_wb = 0.30     "wheelbase [m] (not specified in requirement, assumed for simulation)";
  parameter Real I_body = 0.14   "body yaw inertia [kg.m2] (not specified, estimated from mass)";
  parameter Real b_lin = 3.0    "linear viscous damping [N.s/m]";
  parameter Real b_ang = 0.5    "angular viscous damping [N.m.s/rad]";
  parameter Real tau_max = 12.2  "max wheel torque [N.m]";

  // ---- Control parameters ----
  parameter Real v_max = 1.2     "max velocity [m/s]";
  parameter Real k_dist = 1.8    "distance-to-velocity gain [1/s]";
  parameter Real k_v = 8.0       "velocity tracking gain [1/s]";
  parameter Real k_head = 2.5    "heading gain [1/s]";
  parameter Real k_omega = 3.5   "angular rate gain [1/s]";

  // ---- Timing / disturbance ----
  parameter Real T_sim = 20.0            "simulation duration [s]";
  parameter Real delay_dist = 0.145      "communication delay disturbance [s]";
  parameter Real t_mid_start = 20.0/3.0   "start of middle third [s]";
  parameter Real t_mid_end = 40.0/3.0     "end of middle third [s]";

  // ---- Verification thresholds ----
  parameter Real sep_min = 0.30       "minimum inter-robot separation [m]";
  parameter Real track_thresh = 0.32   "tracking error threshold [m]";
  parameter Real track_check_t = 13.0  "tracking error check time [s]";
  parameter Real data_age_max = 1.0    "max data age [s]";

  // ---- World frame (walls / boundaries) ----
  parameter Real x_wall_min = -1.0  "world x min [m]";
  parameter Real x_wall_max = 9.0   "world x max [m]";
  parameter Real y_wall_min = -1.0  "world y min [m]";
  parameter Real y_wall_max = 4.0   "world y max [m]";

  // ---- Survey markers (common world frame) ----
  parameter Real marker1_x = 7.0  "marker A x [m]";
  parameter Real marker1_y = 0.0  "marker A y [m]";
  parameter Real marker2_x = 7.0  "marker B x [m]";
  parameter Real marker2_y = 3.0  "marker B y [m]";
  parameter Real handoff_x = 3.0  "handoff point x [m]";
  parameter Real handoff_y = 0.0  "handoff point y [m]";

  // ===== Robot 1 continuous states =====
  Real x1(start=0.0, fixed=true)     "R1 x [m]";
  Real y1(start=0.0, fixed=true)     "R1 y [m]";
  Real theta1(start=0.0, fixed=true) "R1 heading [rad]";
  Real v1(start=0.0, fixed=true)     "R1 linear velocity [m/s]";
  Real omega1(start=0.0, fixed=true) "R1 angular velocity [rad/s]";

  // ===== Robot 2 continuous states =====
  Real x2(start=0.0, fixed=true)     "R2 x [m]";
  Real y2(start=3.0, fixed=true)     "R2 y [m]";
  Real theta2(start=0.0, fixed=true) "R2 heading [rad]";
  Real v2(start=0.0, fixed=true)     "R2 linear velocity [m/s]";
  Real omega2(start=0.0, fixed=true) "R2 angular velocity [rad/s]";

  // ===== Actuator commands (four channels) =====
  Real tauR1 "R1 right wheel torque [N.m]";
  Real tauL1 "R1 left wheel torque [N.m]";
  Real tauR2 "R2 right wheel torque [N.m]";
  Real tauL2 "R2 left wheel torque [N.m]";
  Real tauR1_raw, tauL1_raw, tauR2_raw, tauL2_raw "unsaturated torques [N.m]";

  // ===== Phase state machines =====
  Integer phase1(start=0) "R1: 0=inspect, 1=to_handoff, 2=done";
  Integer phase2(start=0) "R2: 0=inspect, 1=wait_handoff, 2=replan, 3=done";

  // ===== Waypoints =====
  Real wx1, wy1 "R1 target waypoint";
  Real wx2, wy2 "R2 target waypoint";
  Real wx2_final, wy2_final "R2 final replan target (depends on received data)";

  // ===== Communication =====
  Boolean data_sent(start=false);
  Boolean data_received(start=false);
  Real send_time(start=-1.0)    "data send timestamp [s]";
  Real recv_time(start=-1.0)    "data receive timestamp [s]";
  Real applied_delay(start=0.0) "delay captured at send instant [s]";
  Real comm_delay               "current comm delay [s]";
  Boolean delay_active          "delay disturbance active flag";
  Real data_age                 "age of received data [s]";
  Integer handoff_state(start=0) "0=before, 1=sent, 2=received, 3=complete";
  Real result_timestamp(start=-1.0) "timestamp embedded in result packet [s]";
  Real result_value(start=0.0)      "inspection result payload";

  // ===== Sensors =====
  Real encR1, encL1, encR2, encL2 "wheel encoder angular rates [rad/s]";
  Real imu_gyro1, imu_gyro2       "IMU gyroscope [rad/s]";
  Real imu_ax1, imu_ax2           "IMU linear acceleration [m/s2]";
  Real lidar1, lidar2             "lidar min range to walls [m]";

  // ===== Tracking / separation =====
  Real dist1, dist2               "distance to current waypoint [m]";
  Real track_err_primary          "primary tracking error [m]";
  Real sep                        "inter-robot separation [m]";

  // ===== Control intermediates =====
  Real theta_des1, theta_des2     "desired heading [rad]";
  Real heading_err1, heading_err2 "wrapped heading error [rad]";
  Real v_des1, v_des2            "desired velocity [m/s]";
  Real a_cmd1, a_cmd2             "commanded linear acceleration [m/s2]";
  Real alpha_cmd1, alpha_cmd2     "commanded angular acceleration [rad/s2]";

  // ===== Inspection dwell timers =====
  Real inspect_timer1(start=0.0) "R1 inspection dwell [s]";
  Real inspect_timer2(start=0.0) "R2 inspection dwell [s]";

  // ===== Task completion flags =====
  Boolean task1_complete(start=false);
  Boolean task2_complete(start=false);

  // ===== Verification flags =====
  Boolean actuator_ok;
  Boolean separation_ok;
  Boolean data_age_ok;
  Boolean handoff_ok;
  Boolean no_collision;
  Boolean task_complete;
  Boolean tracking_ok;
  Boolean no_nan_inf;
  Boolean all_ok;

equation
  // ===== Communication delay disturbance (active during middle third) =====
  delay_active = time >= t_mid_start and time <= t_mid_end;
  comm_delay = if delay_active then delay_dist else 0.0;

  // ===== Inspection dwell timers =====
  if phase1 == 0 and abs(x1 - marker1_x) < 0.3 and abs(y1 - marker1_y) < 0.3 then
    der(inspect_timer1) = 1.0;
  else
    der(inspect_timer1) = 0.0;
  end if;

  if phase2 == 0 and abs(x2 - marker2_x) < 0.3 and abs(y2 - marker2_y) < 0.3 then
    der(inspect_timer2) = 1.0;
  else
    der(inspect_timer2) = 0.0;
  end if;

  // ===== Robot 1 phase transitions =====
  // Phase 0 -> 1: inspection complete at marker A
  when phase1 == 0 and abs(x1 - marker1_x) < 0.2 and abs(y1 - marker1_y) < 0.2 and inspect_timer1 > 0.5 then
    phase1 = 1;
  end when;

  // Phase 1 -> 2: reach handoff point, send timestamped result
  when phase1 == 1 and abs(x1 - handoff_x) < 0.2 and abs(y1 - handoff_y) < 0.2 and not data_sent then
    data_sent = true;
    send_time = time;
    applied_delay = comm_delay;
    result_timestamp = time;
    result_value = 1.0;
    phase1 = 2;
    task1_complete = true;
  end when;

  // ===== Robot 2 phase transitions =====
  // Phase 0 -> 1 or 2: inspection complete at marker B
  when phase2 == 0 and abs(x2 - marker2_x) < 0.2 and abs(y2 - marker2_y) < 0.2 and inspect_timer2 > 0.5 then
    phase2 = if data_received then 2 else 1;
  end when;

  // Data reception with captured delay
  when data_sent and not data_received and time >= send_time + applied_delay then
    data_received = true;
    recv_time = time;
    phase2 = if phase2 == 1 then 2 else phase2;
  end when;

  // Phase 2 -> 3: reach replanned target
  when phase2 == 2 and abs(x2 - wx2_final) < 0.2 and abs(y2 - wy2_final) < 0.2 then
    phase2 = 3;
    task2_complete = true;
  end when;

  // ===== Waypoints =====
  // Robot 1: inspect marker A, then go to handoff point
  if phase1 == 0 then
    wx1 = marker1_x;
    wy1 = marker1_y;
  else
    wx1 = handoff_x;
    wy1 = handoff_y;
  end if;

  // Robot 2: inspect marker B, then replan based on received data
  // Replan target derived from received result: offset from Robot 1's inspection point
  wx2_final = marker1_x + result_value;
  wy2_final = marker1_y + 1.5;

  if phase2 <= 1 then
    wx2 = marker2_x;
    wy2 = marker2_y;
  else
    wx2 = wx2_final;
    wy2 = wy2_final;
  end if;

  // ===== Handoff state machine =====
  if not data_sent then
    handoff_state = 0;
  elseif data_sent and not data_received then
    handoff_state = 1;
  elseif data_received and phase2 < 3 then
    handoff_state = 2;
  else
    handoff_state = 3;
  end if;

  // ===== Data age =====
  if data_received and recv_time > 0.0 then
    data_age = max(0.0, time - recv_time);
  else
    data_age = 0.0;
  end if;

  // ===== Distances =====
  dist1 = sqrt((wx1 - x1)*(wx1 - x1) + (wy1 - y1)*(wy1 - y1) + 1e-9);
  dist2 = sqrt((wx2 - x2)*(wx2 - x2) + (wy2 - y2)*(wy2 - y2) + 1e-9);
  sep = sqrt((x2 - x1)*(x2 - x1) + (y2 - y1)*(y2 - y1) + 1e-9);
  track_err_primary = sqrt((wx2_final - x2)*(wx2_final - x2) + (wy2_final - y2)*(wy2_final - y2) + 1e-9);

  // ===== Heading control =====
  theta_des1 = atan2(wy1 - y1, wx1 - x1);
  theta_des2 = atan2(wy2 - y2, wx2 - x2);
  heading_err1 = atan2(sin(theta_des1 - theta1), cos(theta_des1 - theta1));
  heading_err2 = atan2(sin(theta_des2 - theta2), cos(theta_des2 - theta2));

  // ===== Velocity commands (reduce speed when heading error large) =====
  v_des1 = max(0.0, min(v_max, k_dist * dist1 * cos(heading_err1)));
  v_des2 = max(0.0, min(v_max, k_dist * dist2 * cos(heading_err2)));

  // ===== PD acceleration commands =====
  a_cmd1 = k_v * (v_des1 - v1);
  a_cmd2 = k_v * (v_des2 - v2);
  alpha_cmd1 = k_omega * (k_head * heading_err1 - omega1);
  alpha_cmd2 = k_omega * (k_head * heading_err2 - omega2);

  // ===== Torque computation from desired accelerations (with damping compensation) =====
  // Dynamics: m*dv/dt = (tauR+tauL)/r - b_lin*v
  //           I*dw/dt = (tauR-tauL)*L/(2r) - b_ang*w
  tauR1_raw = (r_wheel*(m_robot*a_cmd1 + b_lin*v1) + (2.0*r_wheel/L_wb)*(I_body*alpha_cmd1 + b_ang*omega1)) / 2.0;
  tauL1_raw = (r_wheel*(m_robot*a_cmd1 + b_lin*v1) - (2.0*r_wheel/L_wb)*(I_body*alpha_cmd1 + b_ang*omega1)) / 2.0;
  tauR2_raw = (r_wheel*(m_robot*a_cmd2 + b_lin*v2) + (2.0*r_wheel/L_wb)*(I_body*alpha_cmd2 + b_ang*omega2)) / 2.0;
  tauL2_raw = (r_wheel*(m_robot*a_cmd2 + b_lin*v2) - (2.0*r_wheel/L_wb)*(I_body*alpha_cmd2 + b_ang*omega2)) / 2.0;

  // ===== Saturate wheel torques =====
  tauR1 = max(-tau_max, min(tau_max, tauR1_raw));
  tauL1 = max(-tau_max, min(tau_max, tauL1_raw));
  tauR2 = max(-tau_max, min(tau_max, tauR2_raw));
  tauL2 = max(-tau_max, min(tau_max, tauL2_raw));

  // ===== Robot 1 dynamics (differential drive) =====
  der(x1) = v1 * cos(theta1);
  der(y1) = v1 * sin(theta1);
  der(theta1) = omega1;
  m_robot * der(v1) = (tauR1 + tauL1) / r_wheel - b_lin * v1;
  I_body * der(omega1) = (tauR1 - tauL1) * L_wb / (2.0 * r_wheel) - b_ang * omega1;

  // ===== Robot 2 dynamics (differential drive) =====
  der(x2) = v2 * cos(theta2);
  der(y2) = v2 * sin(theta2);
  der(theta2) = omega2;
  m_robot * der(v2) = (tauR2 + tauL2) / r_wheel - b_lin * v2;
  I_body * der(omega2) = (tauR2 - tauL2) * L_wb / (2.0 * r_wheel) - b_ang * omega2;

  // ===== Sensors: wheel encoders =====
  encR1 = v1 / r_wheel + omega1 * L_wb / (2.0 * r_wheel);
  encL1 = v1 / r_wheel - omega1 * L_wb / (2.0 * r_wheel);
  encR2 = v2 / r_wheel + omega2 * L_wb / (2.0 * r_wheel);
  encL2 = v2 / r_wheel - omega2 * L_wb / (2.0 * r_wheel);

  // ===== Sensors: IMU (gyroscope + accelerometer) =====
  imu_gyro1 = omega1;
  imu_gyro2 = omega2;
  imu_ax1 = ((tauR1 + tauL1) / r_wheel - b_lin * v1) / m_robot;
  imu_ax2 = ((tauR2 + tauL2) / r_wheel - b_lin * v2) / m_robot;

  // ===== Sensors: lidar (min range to walls) =====
  lidar1 = min(min(x1 - x_wall_min, x_wall_max - x1), min(y1 - y_wall_min, y_wall_max - y1));
  lidar2 = min(min(x2 - x_wall_min, x_wall_max - x2), min(y2 - y_wall_min, y_wall_max - y2));

  // ===== Verification criteria =====
  // Actuator bounds
  actuator_ok = abs(tauR1) <= tau_max + 1e-6 and abs(tauL1) <= tau_max + 1e-6 and
               abs(tauR2) <= tau_max + 1e-6 and abs(tauL2) <= tau_max + 1e-6;

  // Separation bounds
  separation_ok = sep >= sep_min;

  // Bounded data age
  data_age_ok = (not data_received) or (data_age <= data_age_max);

  // Successful handoff
  handoff_ok = handoff_state >= 2;

  // No collision
  no_collision = sep > 0.01;

  // Task completion
  task_complete = task1_complete and task2_complete;

  // Primary tracking error below threshold after check time
  tracking_ok = if time >= track_check_t then track_err_primary <= track_thresh else true;

  // No NaN or infinite values (NaN comparisons return false; Inf exceeds bound)
  no_nan_inf = abs(x1) < 1e6 and abs(y1) < 1e6 and abs(theta1) < 1e6 and
               abs(x2) < 1e6 and abs(y2) < 1e6 and abs(theta2) < 1e6 and
               abs(v1) < 1e6 and abs(v2) < 1e6 and
               abs(omega1) < 1e6 and abs(omega2) < 1e6 and
               abs(tauR1) < 1e6 and abs(tauL1) < 1e6 and
               abs(tauR2) < 1e6 and abs(tauL2) < 1e6;

  // Aggregate verification
  all_ok = actuator_ok and separation_ok and data_age_ok and handoff_ok and
           no_collision and task_complete and tracking_ok and no_nan_inf;

  annotation(
    experiment(StartTime=0, StopTime=20.0, Tolerance=1e-6, Interval=0.002),
    __OpenModelica_simulationFlags(s="dassl")
  );
end GroundPairHandoffF;