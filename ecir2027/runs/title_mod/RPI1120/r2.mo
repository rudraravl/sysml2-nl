model GroundTrioHandoffD
  "Instrumented multi-robot system: three 18 kg differential-drive warehouse robots
   with odometry, lidar, delayed peer messages, task allocation, and handoff.
   Communication delay disturbance of 0.1 s during middle third of 14 s run.
   Control loop at 200 Hz. Robot 3 replans upon receiving timestamped handoff."

  // ==================== Physical Parameters ====================
  parameter Real m_robot = 18.0 "Robot mass [kg]";
  parameter Real r_wheel = 0.1 "Wheel radius [m]";
  parameter Real L_track = 0.4 "Track width [m]";
  parameter Real J_wheel = 0.01 "Wheel moment of inertia [kg.m2]";
  parameter Real b_wheel = 0.05 "Wheel viscous friction [N.m.s/rad]";
  parameter Real tau_max = 12.0 "Maximum wheel torque [N.m]";
  parameter Real Kv = 20.0 "Wheel velocity tracking gain [N.m.s/rad]";
  parameter Real Kwp = 2.5 "Waypoint heading gain [1/s]";
  parameter Real v_max = 1.0 "Maximum linear velocity [m/s]";
  parameter Real omega_max = 2.0 "Maximum angular velocity [rad/s]";
  parameter Real dt_ctrl = 0.005 "Control sample period [s] (200 Hz)";
  parameter Real inspect_duration = 1.5 "Inspection dwell time [s]";
  parameter Real arrive_thresh = 0.15 "Waypoint arrival threshold [m]";
  parameter Real safety_dist = 0.8 "Repulsion activation distance [m]";
  parameter Real rep_gain = 0.3 "Repulsion offset gain [m]";

  // ==================== World Frame ====================
  parameter Real x_wall_p = 6.0 "Positive X wall [m]";
  parameter Real x_wall_n = -6.0 "Negative X wall [m]";
  parameter Real y_wall_p = 6.0 "Positive Y wall [m]";
  parameter Real y_wall_n = -6.0 "Negative Y wall [m]";

  // ==================== Task Waypoints (survey markers) ====================
  parameter Real wp1_x = 3.0 "R1 inspection waypoint X [m]";
  parameter Real wp1_y = 0.0 "R1 inspection waypoint Y [m]";
  parameter Real wp2_x = -1.0 "R2 inspection waypoint X [m]";
  parameter Real wp2_y = 3.0 "R2 inspection waypoint Y [m]";
  parameter Real wp3_x = 0.0 "R3 initial waypoint X [m]";
  parameter Real wp3_y = 1.0 "R3 initial waypoint Y [m]";
  parameter Real wp3r_x = 2.0 "R3 replanned waypoint X [m]";
  parameter Real wp3r_y = -2.0 "R3 replanned waypoint Y [m]";

  // ==================== Communication Parameters ====================
  parameter Real delay_nominal = 0.001 "Nominal comm delay [s]";
  parameter Real delay_disturb = 0.1 "Disturbance comm delay [s]";
  parameter Real delay_max = 0.2 "Maximum comm delay buffer [s]";
  parameter Real t_mid_start = 14.0 / 3.0 "Middle third start [s]";
  parameter Real t_mid_end = 28.0 / 3.0 "Middle third end [s]";

  // ==================== Robot 1 Continuous States ====================
  Real x1(start = 0.0, fixed = true) "R1 X position [m]";
  Real y1(start = -4.0, fixed = true) "R1 Y position [m]";
  Real th1(start = 0.0, fixed = true) "R1 heading [rad]";
  Real w1L(start = 0.0, fixed = true) "R1 left wheel angular velocity [rad/s]";
  Real w1R(start = 0.0, fixed = true) "R1 right wheel angular velocity [rad/s]";
  Real t1L "R1 left wheel torque [N.m]";
  Real t1R "R1 right wheel torque [N.m]";
  Real v1 "R1 linear velocity [m/s]";
  Real om1 "R1 angular velocity [rad/s]";
  Real x1o "R1 odometry X estimate [m]";
  Real y1o "R1 odometry Y estimate [m]";
  Real th1o "R1 odometry heading estimate [rad]";
  Real lid1 "R1 lidar minimum wall range [m]";
  Real t1L_cmd "R1 left torque command [N.m]";
  Real t1R_cmd "R1 right torque command [N.m]";
  Real w1L_ref "R1 left wheel velocity reference [rad/s]";
  Real w1R_ref "R1 right wheel velocity reference [rad/s]";

  // ==================== Robot 2 Continuous States ====================
  Real x2(start = -4.0, fixed = true) "R2 X position [m]";
  Real y2(start = -2.0, fixed = true) "R2 Y position [m]";
  Real th2(start = 0.0, fixed = true) "R2 heading [rad]";
  Real w2L(start = 0.0, fixed = true) "R2 left wheel angular velocity [rad/s]";
  Real w2R(start = 0.0, fixed = true) "R2 right wheel angular velocity [rad/s]";
  Real t2L "R2 left wheel torque [N.m]";
  Real t2R "R2 right wheel torque [N.m]";
  Real v2 "R2 linear velocity [m/s]";
  Real om2 "R2 angular velocity [rad/s]";
  Real x2o "R2 odometry X estimate [m]";
  Real y2o "R2 odometry Y estimate [m]";
  Real th2o "R2 odometry heading estimate [rad]";
  Real lid2 "R2 lidar minimum wall range [m]";
  Real t2L_cmd "R2 left torque command [N.m]";
  Real t2R_cmd "R2 right torque command [N.m]";
  Real w2L_ref "R2 left wheel velocity reference [rad/s]";
  Real w2R_ref "R2 right wheel velocity reference [rad/s]";

  // ==================== Robot 3 Continuous States ====================
  Real x3(start = 3.0, fixed = true) "R3 X position [m]";
  Real y3(start = 4.0, fixed = true) "R3 Y position [m]";
  Real th3(start = 0.0, fixed = true) "R3 heading [rad]";
  Real w3L(start = 0.0, fixed = true) "R3 left wheel angular velocity [rad/s]";
  Real w3R(start = 0.0, fixed = true) "R3 right wheel angular velocity [rad/s]";
  Real t3L "R3 left wheel torque [N.m]";
  Real t3R "R3 right wheel torque [N.m]";
  Real v3 "R3 linear velocity [m/s]";
  Real om3 "R3 angular velocity [rad/s]";
  Real x3o "R3 odometry X estimate [m]";
  Real y3o "R3 odometry Y estimate [m]";
  Real th3o "R3 odometry heading estimate [rad]";
  Real lid3 "R3 lidar minimum wall range [m]";
  Real t3L_cmd "R3 left torque command [N.m]";
  Real t3R_cmd "R3 right torque command [N.m]";
  Real w3L_ref "R3 left wheel velocity reference [rad/s]";
  Real w3R_ref "R3 right wheel velocity reference [rad/s]";

  // ==================== Discrete Task State Machines ====================
  discrete Integer s1(start = 0) "R1 state: 0=move, 1=inspect, 2=send, 3=done";
  discrete Integer s2(start = 0) "R2 state: 0=move, 1=inspect, 2=send, 3=done";
  discrete Integer s3(start = 0) "R3 state: 0=move, 1=inspect, 2=wait_handoff, 3=replan_move, 4=done";
  discrete Real t_s1(start = 0.0) "R1 state entry time [s]";
  discrete Real t_s2(start = 0.0) "R2 state entry time [s]";
  discrete Real t_s3(start = 0.0) "R3 state entry time [s]";

  // ==================== Handoff and Replan Flags ====================
  Real hf1(start = 0.0) "R1 handoff result flag";
  Real hf2(start = 0.0) "R2 handoff result flag";
  Real replan3(start = 0.0) "R3 replan triggered flag";

  // ==================== Current Waypoint Targets ====================
  discrete Real wpx1(start = wp1_x) "R1 current target X [m]";
  discrete Real wpy1(start = wp1_y) "R1 current target Y [m]";
  discrete Real wpx2(start = wp2_x) "R2 current target X [m]";
  discrete Real wpy2(start = wp2_y) "R2 current target Y [m]";
  discrete Real wpx3(start = wp3_x) "R3 current target X [m]";
  discrete Real wpy3(start = wp3_y) "R3 current target Y [m]";

  // ==================== Sampled Control References ====================
  discrete Real v1r(start = 0.0) "R1 velocity reference [m/s]";
  discrete Real om1r(start = 0.0) "R1 angular velocity reference [rad/s]";
  discrete Real v2r(start = 0.0) "R2 velocity reference [m/s]";
  discrete Real om2r(start = 0.0) "R2 angular velocity reference [rad/s]";
  discrete Real v3r(start = 0.0) "R3 velocity reference [m/s]";
  discrete Real om3r(start = 0.0) "R3 angular velocity reference [rad/s]";

  // ==================== Repulsion Navigation Targets ====================
  discrete Real tgt1x(start = wp1_x) "R1 navigation target X [m]";
  discrete Real tgt1y(start = wp1_y) "R1 navigation target Y [m]";
  discrete Real tgt2x(start = wp2_x) "R2 navigation target X [m]";
  discrete Real tgt2y(start = wp2_y) "R2 navigation target Y [m]";
  discrete Real tgt3x(start = wp3_x) "R3 navigation target X [m]";
  discrete Real tgt3y(start = wp3_y) "R3 navigation target Y [m]";
  discrete Real d12_d(start = 10.0) "Sampled separation R1-R2 [m]";
  discrete Real d13_d(start = 10.0) "Sampled separation R1-R3 [m]";
  discrete Real d23_d(start = 10.0) "Sampled separation R2-R3 [m]";

  // ==================== Navigation Variables (continuous) ====================
  Real d1_nav "R1 navigation distance [m]";
  Real psi1_nav "R1 navigation bearing [rad]";
  Real e1_nav "R1 navigation heading error [rad]";
  Real d2_nav "R2 navigation distance [m]";
  Real psi2_nav "R2 navigation bearing [rad]";
  Real e2_nav "R2 navigation heading error [rad]";
  Real d3_nav "R3 navigation distance [m]";
  Real psi3_nav "R3 navigation bearing [rad]";
  Real e3_nav "R3 navigation heading error [rad]";

  // ==================== Communication ====================
  Real comm_d "Current communication delay [s]";
  Real time_d "Delayed timestamp [s]";

  // Shared delayed signals (one delay per broadcast signal)
  Real dx1_d "Delayed R1 position X [m]";
  Real dy1_d "Delayed R1 position Y [m]";
  Real dhf1_d "Delayed R1 handoff flag";
  Real dx2_d "Delayed R2 position X [m]";
  Real dy2_d "Delayed R2 position Y [m]";
  Real dhf2_d "Delayed R2 handoff flag";
  Real dx3_d "Delayed R3 position X [m]";
  Real dy3_d "Delayed R3 position Y [m]";

  // Received messages at each robot
  Real dx1_2 "R2 receives R1 X [m]";
  Real dy1_2 "R2 receives R1 Y [m]";
  Real dhf1_2 "R2 receives R1 handoff flag";
  Real dts1_2 "R2 receives R1 timestamp [s]";
  Real dx1_3 "R3 receives R1 X [m]";
  Real dy1_3 "R3 receives R1 Y [m]";
  Real dhf1_3 "R3 receives R1 handoff flag";
  Real dts1_3 "R3 receives R1 timestamp [s]";
  Real dx2_1 "R1 receives R2 X [m]";
  Real dy2_1 "R1 receives R2 Y [m]";
  Real dhf2_1 "R1 receives R2 handoff flag";
  Real dts2_1 "R1 receives R2 timestamp [s]";
  Real dx2_3 "R3 receives R2 X [m]";
  Real dy2_3 "R3 receives R2 Y [m]";
  Real dhf2_3 "R3 receives R2 handoff flag";
  Real dts2_3 "R3 receives R2 timestamp [s]";
  Real dx3_1 "R1 receives R3 X [m]";
  Real dy3_1 "R1 receives R3 Y [m]";
  Real dts3_1 "R1 receives R3 timestamp [s]";
  Real dx3_2 "R2 receives R3 X [m]";
  Real dy3_2 "R2 receives R3 Y [m]";
  Real dts3_2 "R2 receives R3 timestamp [s]";

  // Send and receive activity indicators
  Real send1 "R1 send activity indicator";
  Real send2 "R2 send activity indicator";
  Real send3 "R3 send activity indicator";
  Real recv1 "R1 receive activity indicator";
  Real recv2 "R2 receive activity indicator";
  Real recv3 "R3 receive activity indicator";

  // Data ages per link
  Real age_2_1 "Data age of R1 msg at R2 [s]";
  Real age_3_1 "Data age of R1 msg at R3 [s]";
  Real age_1_2 "Data age of R2 msg at R1 [s]";
  Real age_3_2 "Data age of R2 msg at R3 [s]";
  Real age_1_3 "Data age of R3 msg at R1 [s]";
  Real age_2_3 "Data age of R3 msg at R2 [s]";
  Real max_data_age "Maximum data age across all links [s]";

  // ==================== Performance Metrics ====================
  Real err1 "R1 tracking error to waypoint [m]";
  Real err2 "R2 tracking error to waypoint [m]";
  Real err3 "R3 tracking error to waypoint [m]";
  Real primary_err "Primary robot (R1) tracking error [m]";
  Real sep12 "Instantaneous separation R1-R2 [m]";
  Real sep13 "Instantaneous separation R1-R3 [m]";
  Real sep23 "Instantaneous separation R2-R3 [m]";
  discrete Real min_sep12(start = 20.0) "Minimum separation R1-R2 [m]";
  discrete Real min_sep13(start = 20.0) "Minimum separation R1-R3 [m]";
  discrete Real min_sep23(start = 20.0) "Minimum separation R2-R3 [m]";
  Real min_sep_all "Overall minimum pairwise separation [m]";
  Boolean no_collision "No collision flag";
  Boolean handoff_success "Handoff success flag";
  Boolean task_complete "All tasks complete flag";

equation
  // ==================== Communication Delay Schedule ====================
  comm_d = if (time >= t_mid_start and time <= t_mid_end) then delay_disturb else delay_nominal;

  // ==================== Shared Delayed Broadcast Signals ====================
  time_d = delay(time, comm_d, delay_max);
  dx1_d = delay(x1, comm_d, delay_max);
  dy1_d = delay(y1, comm_d, delay_max);
  dhf1_d = delay(hf1, comm_d, delay_max);
  dx2_d = delay(x2, comm_d, delay_max);
  dy2_d = delay(y2, comm_d, delay_max);
  dhf2_d = delay(hf2, comm_d, delay_max);
  dx3_d = delay(x3, comm_d, delay_max);
  dy3_d = delay(y3, comm_d, delay_max);

  // ==================== Received Messages ====================
  // R1 receives from R2
  dx2_1 = dx2_d;
  dy2_1 = dy2_d;
  dhf2_1 = dhf2_d;
  dts2_1 = time_d;
  // R1 receives from R3
  dx3_1 = dx3_d;
  dy3_1 = dy3_d;
  dts3_1 = time_d;
  // R2 receives from R1
  dx1_2 = dx1_d;
  dy1_2 = dy1_d;
  dhf1_2 = dhf1_d;
  dts1_2 = time_d;
  // R2 receives from R3
  dx3_2 = dx3_d;
  dy3_2 = dy3_d;
  dts3_2 = time_d;
  // R3 receives from R1
  dx1_3 = dx1_d;
  dy1_3 = dy1_d;
  dhf1_3 = dhf1_d;
  dts1_3 = time_d;
  // R3 receives from R2
  dx2_3 = dx2_d;
  dy2_3 = dy2_d;
  dhf2_3 = dhf2_d;
  dts2_3 = time_d;

  // Send/receive indicators (continuous broadcast)
  send1 = 1.0;
  send2 = 1.0;
  send3 = 1.0;
  recv1 = 1.0;
  recv2 = 1.0;
  recv3 = 1.0;

  // Data ages
  age_2_1 = time - dts1_2;
  age_3_1 = time - dts1_3;
  age_1_2 = time - dts2_1;
  age_3_2 = time - dts2_3;
  age_1_3 = time - dts3_1;
  age_2_3 = time - dts3_2;
  max_data_age = max(max(max(age_2_1, age_3_1), max(age_1_2, age_3_2)), max(age_1_3, age_2_3));

  // ==================== Robot 1 Dynamics ====================
  v1 = (r_wheel / 2.0) * (w1R + w1L);
  om1 = (r_wheel / L_track) * (w1R - w1L);
  der(x1) = v1 * cos(th1);
  der(y1) = v1 * sin(th1);
  der(th1) = om1;
  J_wheel * der(w1L) = t1L - b_wheel * w1L;
  J_wheel * der(w1R) = t1R - b_wheel * w1R;

  // Sensors: odometry and lidar
  x1o = x1;
  y1o = y1;
  th1o = th1;
  lid1 = min(min(x_wall_p - x1, x1 - x_wall_n), min(y_wall_p - y1, y1 - y_wall_n));

  // Wheel velocity references from motion controller
  w1L_ref = (v1r - (L_track / 2.0) * om1r) / r_wheel;
  w1R_ref = (v1r + (L_track / 2.0) * om1r) / r_wheel;

  // Torque commands: feedforward friction plus velocity feedback
  t1L_cmd = b_wheel * w1L_ref + Kv * (w1L_ref - w1L);
  t1R_cmd = b_wheel * w1R_ref + Kv * (w1R_ref - w1R);

  // Saturated actuator torques (bounded to 12 N.m)
  t1L = max(-tau_max, min(tau_max, t1L_cmd));
  t1R = max(-tau_max, min(tau_max, t1R_cmd));

  // ==================== Robot 2 Dynamics ====================
  v2 = (r_wheel / 2.0) * (w2R + w2L);
  om2 = (r_wheel / L_track) * (w2R - w2L);
  der(x2) = v2 * cos(th2);
  der(y2) = v2 * sin(th2);
  der(th2) = om2;
  J_wheel * der(w2L) = t2L - b_wheel * w2L;
  J_wheel * der(w2R) = t2R - b_wheel * w2R;

  x2o = x2;
  y2o = y2;
  th2o = th2;
  lid2 = min(min(x_wall_p - x2, x2 - x_wall_n), min(y_wall_p - y2, y2 - y_wall_n));

  w2L_ref = (v2r - (L_track / 2.0) * om2r) / r_wheel;
  w2R_ref = (v2r + (L_track / 2.0) * om2r) / r_wheel;
  t2L_cmd = b_wheel * w2L_ref + Kv * (w2L_ref - w2L);
  t2R_cmd = b_wheel * w2R_ref + Kv * (w2R_ref - w2R);
  t2L = max(-tau_max, min(tau_max, t2L_cmd));
  t2R = max(-tau_max, min(tau_max, t2R_cmd));

  // ==================== Robot 3 Dynamics ====================
  v3 = (r_wheel / 2.0) * (w3R + w3L);
  om3 = (r_wheel / L_track) * (w3R - w3L);
  der(x3) = v3 * cos(th3);
  der(y3) = v3 * sin(th3);
  der(th3) = om3;
  J_wheel * der(w3L) = t3L - b_wheel * w3L;
  J_wheel * der(w3R) = t3R - b_wheel * w3R;

  x3o = x3;
  y3o = y3;
  th3o = th3;
  lid3 = min(min(x_wall_p - x3, x3 - x_wall_n), min(y_wall_p - y3, y3 - y_wall_n));

  w3L_ref = (v3r - (L_track / 2.0) * om3r) / r_wheel;
  w3R_ref = (v3r + (L_track / 2.0) * om3r) / r_wheel;
  t3L_cmd = b_wheel * w3L_ref + Kv * (w3L_ref - w3L);
  t3R_cmd = b_wheel * w3R_ref + Kv * (w3R_ref - w3R);
  t3L = max(-tau_max, min(tau_max, t3L_cmd));
  t3R = max(-tau_max, min(tau_max, t3R_cmd));

  // ==================== Navigation Variables ====================
  d1_nav = sqrt((tgt1x - x1)^2 + (tgt1y - y1)^2);
  psi1_nav = atan2(tgt1y - y1, tgt1x - x1);
  e1_nav = atan2(sin(psi1_nav - th1), cos(psi1_nav - th1));

  d2_nav = sqrt((tgt2x - x2)^2 + (tgt2y - y2)^2);
  psi2_nav = atan2(tgt2y - y2, tgt2x - x2);
  e2_nav = atan2(sin(psi2_nav - th2), cos(psi2_nav - th2));

  d3_nav = sqrt((tgt3x - x3)^2 + (tgt3y - y3)^2);
  psi3_nav = atan2(tgt3y - y3, tgt3x - x3);
  e3_nav = atan2(sin(psi3_nav - th3), cos(psi3_nav - th3));

  // ==================== Tracking Errors ====================
  err1 = sqrt((wpx1 - x1)^2 + (wpy1 - y1)^2);
  err2 = sqrt((wpx2 - x2)^2 + (wpy2 - y2)^2);
  err3 = sqrt((wpx3 - x3)^2 + (wpy3 - y3)^2);
  primary_err = err1;

  // ==================== Separation Monitoring ====================
  sep12 = sqrt((x1 - x2)^2 + (y1 - y2)^2);
  sep13 = sqrt((x1 - x3)^2 + (y1 - y3)^2);
  sep23 = sqrt((x2 - x3)^2 + (y2 - y3)^2);

  min_sep_all = min(min(min_sep12, min_sep13), min_sep23);
  no_collision = min_sep_all > 0.5;
  handoff_success = replan3 > 0.5;
  task_complete = (s1 >= 3) and (s2 >= 3) and (s3 >= 4);

algorithm
  when sample(0, dt_ctrl) then
    // ===== Record minimum separations =====
    min_sep12 := min(min_sep12, sep12);
    min_sep13 := min(min_sep13, sep13);
    min_sep23 := min(min_sep23, sep23);

    // ===== Compute instantaneous separations for repulsion =====
    d12_d := sqrt((x1 - x2)^2 + (y1 - y2)^2);
    d13_d := sqrt((x1 - x3)^2 + (y1 - y3)^2);
    d23_d := sqrt((x2 - x3)^2 + (y2 - y3)^2);

    // ===== Repulsion-adjusted navigation targets =====
    // Robot 1
    tgt1x := wpx1;
    tgt1y := wpy1;
    if d12_d < safety_dist and d12_d > 0.01 then
      tgt1x := tgt1x + rep_gain * (x1 - x2) / d12_d;
      tgt1y := tgt1y + rep_gain * (y1 - y2) / d12_d;
    end if;
    if d13_d < safety_dist and d13_d > 0.01 then
      tgt1x := tgt1x + rep_gain * (x1 - x3) / d13_d;
      tgt1y := tgt1y + rep_gain * (y1 - y3) / d13_d;
    end if;

    // Robot 2
    tgt2x := wpx2;
    tgt2y := wpy2;
    if d12_d < safety_dist and d12_d > 0.01 then
      tgt2x := tgt2x + rep_gain * (x2 - x1) / d12_d;
      tgt2y := tgt2y + rep_gain * (y2 - y1) / d12_d;
    end if;
    if d23_d < safety_dist and d23_d > 0.01 then
      tgt2x := tgt2x + rep_gain * (x2 - x3) / d23_d;
      tgt2y := tgt2y + rep_gain * (y2 - y3) / d23_d;
    end if;

    // Robot 3
    tgt3x := wpx3;
    tgt3y := wpy3;
    if d13_d < safety_dist and d13_d > 0.01 then
      tgt3x := tgt3x + rep_gain * (x3 - x1) / d13_d;
      tgt3y := tgt3y + rep_gain * (y3 - y1) / d13_d;
    end if;
    if d23_d < safety_dist and d23_d > 0.01 then
      tgt3x := tgt3x + rep_gain * (x3 - x2) / d23_d;
      tgt3y := tgt3y + rep_gain * (y3 - y2) / d23_d;
    end if;

    // ===== Robot 1 State Machine =====
    if s1 == 0 then
      if err1 < arrive_thresh then
        s1 := 1;
        t_s1 := time;
      end if;
    elseif s1 == 1 then
      if time - t_s1 >= inspect_duration then
        s1 := 2;
      end if;
    elseif s1 == 2 then
      hf1 := 1.0;
      s1 := 3;
    end if;

    // ===== Robot 2 State Machine =====
    if s2 == 0 then
      if err2 < arrive_thresh then
        s2 := 1;
        t_s2 := time;
      end if;
    elseif s2 == 1 then
      if time - t_s2 >= inspect_duration then
        s2 := 2;
      end if;
    elseif s2 == 2 then
      hf2 := 1.0;
      s2 := 3;
    end if;

    // ===== Robot 3 State Machine =====
    if s3 == 0 then
      if err3 < arrive_thresh then
        s3 := 1;
        t_s3 := time;
      end if;
    elseif s3 == 1 then
      if time - t_s3 >= inspect_duration then
        s3 := 2;
      end if;
    elseif s3 == 2 then
      // Wait for timestamped handoff result from R1 or R2 via delayed comm
      if dhf1_3 > 0.5 or dhf2_3 > 0.5 then
        replan3 := 1.0;
        wpx3 := wp3r_x;
        wpy3 := wp3r_y;
        s3 := 3;
        t_s3 := time;
      end if;
    elseif s3 == 3 then
      if err3 < arrive_thresh then
        s3 := 4;
        t_s3 := time;
      end if;
    end if;

    // ===== Local Motion Control References (200 Hz) =====
    // Robot 1
    if s1 == 0 then
      v1r := max(0.0, min(v_max, d1_nav * cos(e1_nav)));
      om1r := max(-omega_max, min(omega_max, Kwp * e1_nav));
    else
      v1r := 0.0;
      om1r := 0.0;
    end if;

    // Robot 2
    if s2 == 0 then
      v2r := max(0.0, min(v_max, d2_nav * cos(e2_nav)));
      om2r := max(-omega_max, min(omega_max, Kwp * e2_nav));
    else
      v2r := 0.0;
      om2r := 0.0;
    end if;

    // Robot 3
    if s3 == 0 or s3 == 3 then
      v3r := max(0.0, min(v_max, d3_nav * cos(e3_nav)));
      om3r := max(-omega_max, min(omega_max, Kwp * e3_nav));
    else
      v3r := 0.0;
      om3r := 0.0;
    end if;

  end when;

  annotation(
    experiment(StartTime = 0, StopTime = 14, Tolerance = 1e-6, Interval = 0.005),
    Documentation(info = "GroundTrioHandoffD: Three 18 kg differential-drive warehouse robots
      with odometry, lidar, and delayed peer messages. Six wheel drives limited to 12 N.m.
      Task allocation divides inspection among three robots in a common world frame.
      Robot 3 replans upon receiving timestamped handoff from Robot 1 or 2.
      Controlled 0.1 s communication delay disturbance during middle third (4.67-9.33 s).
      Control loop runs at 200 Hz for 14 s. Actuator torque, velocity, and separation
      are bounded. Primary tracking error required below 0.4 m after 9.1 s.")
  );
end GroundTrioHandoffD;