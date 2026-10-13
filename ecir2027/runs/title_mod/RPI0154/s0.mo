model SCARATraceD
  "Instrumented fixed-base articulated SCARA manipulator with trajectory tracking"

  // ==================== PHYSICAL PARAMETERS ====================
  parameter Modelica.Units.SI.Mass m1 = 6.0 "Link 1 moving mass";
  parameter Modelica.Units.SI.Mass m2 = 4.0 "Link 2 moving mass";
  parameter Modelica.Units.SI.Mass m3 = 2.0 "Carriage (prismatic) moving mass";
  parameter Modelica.Units.SI.Length L1 = 0.48 "Link 1 length";
  parameter Modelica.Units.SI.Length L2 = 0.34 "Link 2 length";
  parameter Modelica.Units.SI.Length z_travel = 0.30 "Prismatic joint travel";
  parameter Modelica.Units.SI.Acceleration g_const = 9.81 "Gravitational acceleration";
  // Base mass 28 kg is fixed; not part of moving dynamics.

  // ==================== ACTUATOR LIMITS ====================
  parameter Real tau1_max = 95.0 "Joint 1 torque saturation limit [N.m]";
  parameter Real tau2_max = 95.0 "Joint 2 torque saturation limit [N.m]";
  parameter Real F3_max = 900.0 "Joint 3 force saturation limit [N]";

  // ==================== OBSTACLE ====================
  parameter Real obs_cx = 0.80 "Obstacle center x-coordinate [m]";
  parameter Real obs_cy = -0.30 "Obstacle center y-coordinate [m]";
  parameter Real obs_r = 0.08 "Obstacle radius [m]";

  // ==================== TRAJECTORY WAYPOINTS ====================
  parameter Real q1_w1 = 0.0 "Waypoint 1, joint 1 [rad]";
  parameter Real q1_w2 = 0.5 "Waypoint 2, joint 1 [rad]";
  parameter Real q1_w3 = 1.0 "Waypoint 3, joint 1 [rad]";
  parameter Real q2_w1 = 0.0 "Waypoint 1, joint 2 [rad]";
  parameter Real q2_w2 = 0.3 "Waypoint 2, joint 2 [rad]";
  parameter Real q2_w3 = 0.6 "Waypoint 3, joint 2 [rad]";
  parameter Real q3_w1 = 0.0 "Waypoint 1, joint 3 [m]";
  parameter Real q3_w2 = 0.15 "Waypoint 2, joint 3 [m]";
  parameter Real q3_w3 = 0.30 "Waypoint 3, joint 3 [m]";
  parameter Real t_seg1 = 14.0/3.0 "End of trajectory segment 1 [s]";
  parameter Real t_seg2 = 28.0/3.0 "End of trajectory segment 2 [s]";
  parameter Real t_total = 14.0 "Total simulation time [s]";
  parameter Real dt_ctrl = 0.005 "Control/sample period [s] (200 Hz)";

  // ==================== CONTROLLER GAINS ====================
  parameter Real Kp1 = 300.0 "Joint 1 proportional gain";
  parameter Real Ki1 = 100.0 "Joint 1 integral gain";
  parameter Real Kd1 = 40.0 "Joint 1 derivative gain";
  parameter Real Kff1 = 1.0 "Joint 1 velocity feedforward gain";
  parameter Real Kp2 = 60.0 "Joint 2 proportional gain";
  parameter Real Ki2 = 30.0 "Joint 2 integral gain";
  parameter Real Kd2 = 8.0 "Joint 2 derivative gain";
  parameter Real Kff2 = 0.5 "Joint 2 velocity feedforward gain";
  parameter Real Kp3 = 200.0 "Joint 3 proportional gain";
  parameter Real Ki3 = 100.0 "Joint 3 integral gain";
  parameter Real Kd3 = 25.0 "Joint 3 derivative gain";
  parameter Real Kff3 = 1.0 "Joint 3 velocity feedforward gain";

  // ==================== JOINT LIMITS ====================
  parameter Real q1_lo = -3.14159 "Joint 1 lower limit [rad]";
  parameter Real q1_hi = 3.14159 "Joint 1 upper limit [rad]";
  parameter Real q2_lo = -3.14159 "Joint 2 lower limit [rad]";
  parameter Real q2_hi = 3.14159 "Joint 2 upper limit [rad]";
  parameter Real q3_lo = 0.0 "Joint 3 lower limit [m]";
  parameter Real q3_hi = 0.30 "Joint 3 upper limit [m]";

  // ==================== STATES ====================
  Real q1(start = q1_w1, fixed = true) "Joint 1 position [rad]";
  Real qd1(start = 0.0, fixed = true) "Joint 1 velocity [rad/s]";
  Real q2(start = q2_w1, fixed = true) "Joint 2 position [rad]";
  Real qd2(start = 0.0, fixed = true) "Joint 2 velocity [rad/s]";
  Real q3(start = q3_w1, fixed = true) "Joint 3 position [m]";
  Real qd3(start = 0.0, fixed = true) "Joint 3 velocity [m/s]";

  // ==================== CONTROLLER STATES ====================
  Real int_e1(start = 0.0, fixed = true) "Integral error joint 1";
  Real int_e2(start = 0.0, fixed = true) "Integral error joint 2";
  Real int_e3(start = 0.0, fixed = true) "Integral error joint 3";

  // ==================== TRAJECTORY REFERENCES ====================
  Real q1_ref "Joint 1 reference position [rad]";
  Real qd1_ref "Joint 1 reference velocity [rad/s]";
  Real qdd1_ref "Joint 1 reference acceleration [rad/s2]";
  Real q2_ref "Joint 2 reference position [rad]";
  Real qd2_ref "Joint 2 reference velocity [rad/s]";
  Real qdd2_ref "Joint 2 reference acceleration [rad/s2]";
  Real q3_ref "Joint 3 reference position [m]";
  Real qd3_ref "Joint 3 reference velocity [m/s]";
  Real qdd3_ref "Joint 3 reference acceleration [m/s2]";

  // ==================== TRACKING ERRORS ====================
  Real e1 "Joint 1 tracking error [rad]";
  Real e2 "Joint 2 tracking error [rad]";
  Real e3 "Joint 3 tracking error [m]";
  Real e_primary "Primary (max) tracking error [rad-or-m]";

  // ==================== COMMANDS ====================
  Real tau1_cmd "Joint 1 unsaturated command [N.m]";
  Real tau2_cmd "Joint 2 unsaturated command [N.m]";
  Real F3_cmd "Joint 3 unsaturated command [N]";
  Real tau1_sat "Joint 1 saturated command [N.m]";
  Real tau2_sat "Joint 2 saturated command [N.m]";
  Real F3_sat "Joint 3 saturated command [N]";

  // ==================== ENCODER MEASUREMENTS ====================
  Real q1_meas "Joint 1 measured position [rad]";
  Real qd1_meas "Joint 1 measured velocity [rad/s]";
  Real q2_meas "Joint 2 measured position [rad]";
  Real qd2_meas "Joint 2 measured velocity [rad/s]";
  Real q3_meas "Joint 3 measured position [m]";
  Real qd3_meas "Joint 3 measured velocity [m/s]";

  // ==================== DISTURBANCE ====================
  Real dist_active "Disturbance active flag (0 or 1)";
  Real dist_torque1 "Disturbance torque on joint 1 [N.m]";
  Real dist_torque2 "Disturbance torque on joint 2 [N.m]";

  // ==================== KINEMATICS ====================
  Real ee_x "End-effector x [m]";
  Real ee_y "End-effector y [m]";
  Real ee_z "End-effector z [m]";
  Real j2x "Joint 2 x-position [m]";
  Real j2y "Joint 2 y-position [m]";
  Real obs_dist_ee "Distance from end-effector to obstacle center [m]";
  Real obs_dist_j2 "Distance from joint 2 to obstacle center [m]";
  Real obs_clearance "Minimum obstacle clearance [m]";

  // ==================== DYNAMICS ====================
  Real M11 "Inertia matrix [1,1] [kg.m2]";
  Real M12 "Inertia matrix [1,2] [kg.m2]";
  Real M22 "Inertia matrix [2,2] [kg.m2]";
  Real C1 "Coriolis/centrifugal torque joint 1 [N.m]";
  Real C2 "Coriolis/centrifugal torque joint 2 [N.m]";
  Real det_M "Determinant of inertia matrix [kg2.m4]";
  Real ddq1 "Joint 1 acceleration [rad/s2]";
  Real ddq2 "Joint 2 acceleration [rad/s2]";

  // ==================== SAFETY CHECKS ====================
  Real q1_limit_margin "Joint 1 limit margin [rad]";
  Real q2_limit_margin "Joint 2 limit margin [rad]";
  Real q3_limit_margin "Joint 3 limit margin [m]";

equation
  // ==================== TRAJECTORY GENERATION ====================
  // Cubic polynomial: s(t)=3s^2-2s^3, s_dot=6s-6s^2, s_ddot=6-12s
  // Phase 1: [0, t_seg1] — state 1 to state 2
  // Phase 2: [t_seg1, t_seg2] — state 2 to state 3 (middle third = disturbance)
  // Phase 3: [t_seg2, t_total] — hold at state 3 (settling)

  // --- Joint 1 reference ---
  if time <= t_seg1 then
    q1_ref = q1_w1 + (q1_w2 - q1_w1) * (3.0*(time/t_seg1)^2 - 2.0*(time/t_seg1)^3);
    qd1_ref = (q1_w2 - q1_w1) * (6.0*(time/t_seg1) - 6.0*(time/t_seg1)^2) / t_seg1;
    qdd1_ref = (q1_w2 - q1_w1) * (6.0 - 12.0*(time/t_seg1)) / (t_seg1^2);
  elseif time <= t_seg2 then
    q1_ref = q1_w2 + (q1_w3 - q1_w2) * (3.0*((time - t_seg1)/(t_seg2 - t_seg1))^2 - 2.0*((time - t_seg1)/(t_seg2 - t_seg1))^3);
    qd1_ref = (q1_w3 - q1_w2) * (6.0*((time - t_seg1)/(t_seg2 - t_seg1)) - 6.0*((time - t_seg1)/(t_seg2 - t_seg1))^2) / (t_seg2 - t_seg1);
    qdd1_ref = (q1_w3 - q1_w2) * (6.0 - 12.0*((time - t_seg1)/(t_seg2 - t_seg1))) / ((t_seg2 - t_seg1)^2);
  else
    q1_ref = q1_w3;
    qd1_ref = 0.0;
    qdd1_ref = 0.0;
  end if;

  // --- Joint 2 reference ---
  if time <= t_seg1 then
    q2_ref = q2_w1 + (q2_w2 - q2_w1) * (3.0*(time/t_seg1)^2 - 2.0*(time/t_seg1)^3);
    qd2_ref = (q2_w2 - q2_w1) * (6.0*(time/t_seg1) - 6.0*(time/t_seg1)^2) / t_seg1;
    qdd2_ref = (q2_w2 - q2_w1) * (6.0 - 12.0*(time/t_seg1)) / (t_seg1^2);
  elseif time <= t_seg2 then
    q2_ref = q2_w2 + (q2_w3 - q2_w2) * (3.0*((time - t_seg1)/(t_seg2 - t_seg1))^2 - 2.0*((time - t_seg1)/(t_seg2 - t_seg1))^3);
    qd2_ref = (q2_w3 - q2_w2) * (6.0*((time - t_seg1)/(t_seg2 - t_seg1)) - 6.0*((time - t_seg1)/(t_seg2 - t_seg1))^2) / (t_seg2 - t_seg1);
    qdd2_ref = (q2_w3 - q2_w2) * (6.0 - 12.0*((time - t_seg1)/(t_seg2 - t_seg1))) / ((t_seg2 - t_seg1)^2);
  else
    q2_ref = q2_w3;
    qd2_ref = 0.0;
    qdd2_ref = 0.0;
  end if;

  // --- Joint 3 reference ---
  if time <= t_seg1 then
    q3_ref = q3_w1 + (q3_w2 - q3_w1) * (3.0*(time/t_seg1)^2 - 2.0*(time/t_seg1)^3);
    qd3_ref = (q3_w2 - q3_w1) * (6.0*(time/t_seg1) - 6.0*(time/t_seg1)^2) / t_seg1;
    qdd3_ref = (q3_w2 - q3_w1) * (6.0 - 12.0*(time/t_seg1)) / (t_seg1^2);
  elseif time <= t_seg2 then
    q3_ref = q3_w2 + (q3_w3 - q3_w2) * (3.0*((time - t_seg1)/(t_seg2 - t_seg1))^2 - 2.0*((time - t_seg1)/(t_seg2 - t_seg1))^3);
    qd3_ref = (q3_w3 - q3_w2) * (6.0*((time - t_seg1)/(t_seg2 - t_seg1)) - 6.0*((time - t_seg1)/(t_seg2 - t_seg1))^2) / (t_seg2 - t_seg1);
    qdd3_ref = (q3_w3 - q3_w2) * (6.0 - 12.0*((time - t_seg1)/(t_seg2 - t_seg1))) / ((t_seg2 - t_seg1)^2);
  else
    q3_ref = q3_w3;
    qd3_ref = 0.0;
    qdd3_ref = 0.0;
  end if;

  // ==================== ENCODERS (SYNCHRONIZED SAMPLES) ====================
  q1_meas = q1;
  qd1_meas = qd1;
  q2_meas = q2;
  qd2_meas = qd2;
  q3_meas = q3;
  qd3_meas = qd3;

  // ==================== TRACKING ERRORS ====================
  e1 = q1_ref - q1_meas;
  e2 = q2_ref - q2_meas;
  e3 = q3_ref - q3_meas;
  e_primary = max(abs(e1), max(abs(e2), abs(e3)));

  // ==================== PID + VELOCITY FEEDFORWARD ====================
  tau1_cmd = Kp1*e1 + Ki1*int_e1 + Kd1*(qd1_ref - qd1_meas) + Kff1*qd1_ref;
  tau2_cmd = Kp2*e2 + Ki2*int_e2 + Kd2*(qd2_ref - qd2_meas) + Kff2*qd2_ref;
  F3_cmd = Kp3*e3 + Ki3*int_e3 + Kd3*(qd3_ref - qd3_meas) + Kff3*qd3_ref + m3*g_const;

  // Anti-windup via conditional integration
  der(int_e1) = if (tau1_sat >= tau1_max - 0.001 and e1 > 0.0) or (tau1_sat <= -tau1_max + 0.001 and e1 < 0.0) then 0.0 else e1;
  der(int_e2) = if (tau2_sat >= tau2_max - 0.001 and e2 > 0.0) or (tau2_sat <= -tau2_max + 0.001 and e2 < 0.0) then 0.0 else e2;
  der(int_e3) = if (F3_sat >= F3_max - 0.001 and e3 > 0.0) or (F3_sat <= -F3_max + 0.001 and e3 < 0.0) then 0.0 else e3;

  // ==================== SATURATION ====================
  tau1_sat = max(-tau1_max, min(tau1_max, tau1_cmd));
  tau2_sat = max(-tau2_max, min(tau2_max, tau2_cmd));
  F3_sat = max(-F3_max, min(F3_max, F3_cmd));

  // ==================== DISTURBANCE ====================
  // 10 N lateral (y-direction) force at end-effector during middle third
  // Mapped to joint torques via Jacobian transpose: tau = J^T * [0; 10]
  dist_active = if (time >= t_seg1 and time <= t_seg2) then 1.0 else 0.0;
  dist_torque1 = dist_active * 10.0 * (L1*cos(q1) + L2*cos(q1 + q2));
  dist_torque2 = dist_active * 10.0 * L2*cos(q1 + q2);

  // ==================== DYNAMICS ====================
  // 2-link planar arm in horizontal plane (point masses at link ends)
  M11 = (m1 + m2 + m3)*L1^2 + (m2 + m3)*L2^2 + 2.0*(m2 + m3)*L1*L2*cos(q2);
  M12 = (m2 + m3)*L2^2 + (m2 + m3)*L1*L2*cos(q2);
  M22 = (m2 + m3)*L2^2;

  C1 = -(m2 + m3)*L1*L2*sin(q2)*(2.0*qd1*qd2 + qd2^2);
  C2 = (m2 + m3)*L1*L2*sin(q2)*qd1^2;

  det_M = M11*M22 - M12^2 + 1.0e-12;

  // Solve M*ddq = tau + dist - C for ddq (Cramer's rule)
  ddq1 = (M22*(tau1_sat + dist_torque1 - C1) - M12*(tau2_sat + dist_torque2 - C2)) / det_M;
  ddq2 = (-M12*(tau1_sat + dist_torque1 - C1) + M11*(tau2_sat + dist_torque2 - C2)) / det_M;

  der(qd1) = ddq1;
  der(qd2) = ddq2;
  der(q1) = qd1;
  der(q2) = qd2;

  // Prismatic joint (vertical, gravity included)
  der(qd3) = (F3_sat - m3*g_const) / m3;
  der(q3) = qd3;

  // ==================== KINEMATICS ====================
  j2x = L1*cos(q1);
  j2y = L1*sin(q1);
  ee_x = j2x + L2*cos(q1 + q2);
  ee_y = j2y + L2*sin(q1 + q2);
  ee_z = q3;

  // ==================== OBSTACLE CLEARANCE ====================
  obs_dist_ee = sqrt((ee_x - obs_cx)^2 + (ee_y - obs_cy)^2 + 1.0e-12);
  obs_dist_j2 = sqrt((j2x - obs_cx)^2 + (j2y - obs_cy)^2 + 1.0e-12);
  obs_clearance = min(obs_dist_ee, obs_dist_j2) - obs_r;

  // ==================== JOINT LIMIT MARGINS ====================
  q1_limit_margin = min(q1 - q1_lo, q1_hi - q1);
  q2_limit_margin = min(q2 - q2_lo, q2_hi - q2);
  q3_limit_margin = min(q3 - q3_lo, q3_hi - q3);

  annotation(
    experiment(StopTime = 14.0, Tolerance = 1.0e-6, Interval = 0.005),
    Documentation(info = "SCARATraceD: Instrumented fixed-base articulated manipulator.
  Two revolute Z-links (0.48 m, 0.34 m) plus prismatic Z-carriage (0.30 m travel).
  Moving masses: 6, 4, 2 kg. Fixed cylindrical base: 28 kg.
  Cubic joint trajectory through three reachable states, stops at last state.
  PID plus velocity-feedforward trajectory control with anti-windup.
  10 N lateral disturbance during middle third (segment 2).
  Actuator saturation: 95 N.m (revolute) / 900 N (prismatic).
  Fixed cylindrical keep-out obstacle at (0.80, -0.30) m, radius 0.08 m,
  placed beside but not on the nominal motion path.
  Synchronized state, command, and sensor traces at 200 Hz for 14 s.
  Requirements: joint limits, obstacle clearance > 0.05 m, overshoot < 12 pct,
  terminal settling, primary tracking error < 0.05 rad-or-m after 9.1 s,
  no NaN or infinite values.")
  );
end SCARATraceD;