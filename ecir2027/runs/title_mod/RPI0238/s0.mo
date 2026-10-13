model AssemblyArmRejectD
  "Instrumented fixed-base 4-DOF articulated manipulator (Z-Y-Y-X) with saturated state-feedback, integral disturbance rejection, self-collision modeling, and 18 N lateral disturbance during middle third"

  // ===== Link Parameters =====
  parameter Real L1 = 0.50 "Link 1 length [m]";
  parameter Real L2 = 0.40 "Link 2 length [m]";
  parameter Real L3 = 0.28 "Link 3 length [m]";
  parameter Real L4 = 0.16 "Link 4 length [m]";
  parameter Real m1 = 7.0 "Link 1 mass [kg]";
  parameter Real m2 = 5.0 "Link 2 mass [kg]";
  parameter Real m3 = 3.0 "Link 3 mass [kg]";
  parameter Real m4 = 1.0 "Link 4 mass [kg]";

  // ===== Actuator Limit =====
  parameter Real tau_max = 110.0 "Maximum joint torque [N.m]";

  // ===== Joint Friction =====
  parameter Real b1 = 0.5 "Joint 1 viscous friction [N.m.s/rad]";
  parameter Real b2 = 0.5 "Joint 2 viscous friction [N.m.s/rad]";
  parameter Real b3 = 0.3 "Joint 3 viscous friction [N.m.s/rad]";
  parameter Real b4 = 0.1 "Joint 4 viscous friction [N.m.s/rad]";

  // ===== Disturbance =====
  parameter Real F_dist = 18.0 "Disturbance force magnitude [N]";
  parameter Real t_dist_start = 14.0 / 3.0 "Disturbance start time [s]";
  parameter Real t_dist_end = 2.0 * 14.0 / 3.0 "Disturbance end time [s]";

  // ===== Joint Targets (nonzero hold) =====
  parameter Real q1_ref = 0.30 "Joint 1 target [rad]";
  parameter Real q2_ref = 0.40 "Joint 2 target [rad]";
  parameter Real q3_ref = -0.30 "Joint 3 target [rad]";
  parameter Real q4_ref = 0.00 "Joint 4 target [rad]";

  // ===== Controller Gains =====
  parameter Real Kp1 = 200.0 "Joint 1 proportional gain [N.m/rad]";
  parameter Real Kp2 = 300.0 "Joint 2 proportional gain [N.m/rad]";
  parameter Real Kp3 = 150.0 "Joint 3 proportional gain [N.m/rad]";
  parameter Real Kp4 = 50.0 "Joint 4 proportional gain [N.m/rad]";
  parameter Real Kd1 = 20.0 "Joint 1 derivative gain [N.m.s/rad]";
  parameter Real Kd2 = 25.0 "Joint 2 derivative gain [N.m.s/rad]";
  parameter Real Kd3 = 12.0 "Joint 3 derivative gain [N.m.s/rad]";
  parameter Real Kd4 = 5.0 "Joint 4 derivative gain [N.m.s/rad]";
  parameter Real Ki1 = 50.0 "Joint 1 integral gain [N.m/(rad.s)]";
  parameter Real Ki2 = 80.0 "Joint 2 integral gain [N.m/(rad.s)]";
  parameter Real Ki3 = 40.0 "Joint 3 integral gain [N.m/(rad.s)]";
  parameter Real Ki4 = 15.0 "Joint 4 integral gain [N.m/(rad.s)]";

  // ===== Physical Constants =====
  parameter Real g_acc = 9.81 "Gravitational acceleration [m/s^2]";

  // ===== Effective Inertias (uniform rod about end + distal masses) =====
  parameter Real J1 = m1 * L1 ^ 2 / 12.0 + (m2 + m3 + m4) * L1 ^ 2 "Joint 1 inertia [kg.m^2]";
  parameter Real J2 = m2 * L2 ^ 2 / 12.0 + (m3 + m4) * L2 ^ 2 "Joint 2 inertia [kg.m^2]";
  parameter Real J3 = m3 * L3 ^ 2 / 12.0 + m4 * L3 ^ 2 "Joint 3 inertia [kg.m^2]";
  parameter Real J4 = m4 * L4 ^ 2 / 12.0 "Joint 4 inertia [kg.m^2]";

  // ===== Collision Parameters =====
  parameter Real d_safe = 0.08 "Self-collision safe distance [m]";
  parameter Real k_coll = 5000.0 "Self-collision stiffness [N/m]";

  // ===== Continuous States =====
  Real q1(start = 0.27) "Joint 1 angle [rad]";
  Real q2(start = 0.36) "Joint 2 angle [rad]";
  Real q3(start = -0.27) "Joint 3 angle [rad]";
  Real q4(start = 0.0) "Joint 4 angle [rad]";
  Real qd1(start = 0.0) "Joint 1 velocity [rad/s]";
  Real qd2(start = 0.0) "Joint 2 velocity [rad/s]";
  Real qd3(start = 0.0) "Joint 3 velocity [rad/s]";
  Real qd4(start = 0.0) "Joint 4 velocity [rad/s]";
  Real integ1(start = 0.0) "Joint 1 integral state [rad.s]";
  Real integ2(start = 0.0) "Joint 2 integral state [rad.s]";
  Real integ3(start = 0.0) "Joint 3 integral state [rad.s]";
  Real integ4(start = 0.0) "Joint 4 integral state [rad.s]";

  // ===== Discrete State =====
  discrete Real peak_dev(start = 0.0) "Peak deviation [rad]";

  // ===== Controller Outputs =====
  Real tau1_cmd "Joint 1 unsaturated command [N.m]";
  Real tau2_cmd "Joint 2 unsaturated command [N.m]";
  Real tau3_cmd "Joint 3 unsaturated command [N.m]";
  Real tau4_cmd "Joint 4 unsaturated command [N.m]";
  Real tau1 "Joint 1 applied torque [N.m]";
  Real tau2 "Joint 2 applied torque [N.m]";
  Real tau3 "Joint 3 applied torque [N.m]";
  Real tau4 "Joint 4 applied torque [N.m]";

  // ===== Gravity Torques =====
  Real tau1_g "Gravity torque joint 1 [N.m]";
  Real tau2_g "Gravity torque joint 2 [N.m]";
  Real tau3_g "Gravity torque joint 3 [N.m]";
  Real tau4_g "Gravity torque joint 4 [N.m]";

  // ===== Disturbance =====
  Real dist_active "Disturbance active flag [0 or 1]";
  Real tau1_d "Disturbance torque joint 1 [N.m]";
  Real tau2_d "Disturbance torque joint 2 [N.m]";
  Real tau3_d "Disturbance torque joint 3 [N.m]";
  Real tau4_d "Disturbance torque joint 4 [N.m]";

  // ===== Self-Collision =====
  Real d13 "Distance links 1-3 [m]";
  Real d14 "Distance links 1-4 [m]";
  Real d24 "Distance links 2-4 [m]";
  Real pen13 "Penetration pair 1-3 [m]";
  Real pen14 "Penetration pair 1-4 [m]";
  Real pen24 "Penetration pair 2-4 [m]";
  Real d13_q2 "Gradient d13/dq2";
  Real d13_q3 "Gradient d13/dq3";
  Real d14_q2 "Gradient d14/dq2";
  Real d14_q3 "Gradient d14/dq3";
  Real d24_q2 "Gradient d24/dq2";
  Real d24_q3 "Gradient d24/dq3";
  Real tau1_c "Collision torque joint 1 [N.m]";
  Real tau2_c "Collision torque joint 2 [N.m]";
  Real tau3_c "Collision torque joint 3 [N.m]";
  Real tau4_c "Collision torque joint 4 [N.m]";

  // ===== Sensors =====
  Real enc1 "Encoder joint 1 [rad]";
  Real enc2 "Encoder joint 2 [rad]";
  Real enc3 "Encoder joint 3 [rad]";
  Real enc4 "Encoder joint 4 [rad]";
  Real encv1 "Velocity encoder joint 1 [rad/s]";
  Real encv2 "Velocity encoder joint 2 [rad/s]";
  Real encv3 "Velocity encoder joint 3 [rad/s]";
  Real encv4 "Velocity encoder joint 4 [rad/s]";
  Real wr_fx "Wrist wrench force X [N]";
  Real wr_fy "Wrist wrench force Y [N]";
  Real wr_fz "Wrist wrench force Z [N]";
  Real wr_tx "Wrist wrench torque X [N.m]";
  Real wr_ty "Wrist wrench torque Y [N.m]";
  Real wr_tz "Wrist wrench torque Z [N.m]";

  // ===== Tracking =====
  Real err1 "Joint 1 error [rad]";
  Real err2 "Joint 2 error [rad]";
  Real err3 "Joint 3 error [rad]";
  Real err4 "Joint 4 error [rad]";
  Real max_err "Max absolute error [rad]";

  // ===== Forward Kinematics =====
  Real tip_x "Distal end X [m]";
  Real tip_y "Distal end Y [m]";
  Real tip_z "Distal end Z [m]";
  Real p2cx "Link 2 center X [m]";
  Real p2cy "Link 2 center Y [m]";
  Real p2cz "Link 2 center Z [m]";
  Real p3cx "Link 3 center X [m]";
  Real p3cy "Link 3 center Y [m]";
  Real p3cz "Link 3 center Z [m]";
  Real p4cx "Link 4 center X [m]";
  Real p4cy "Link 4 center Y [m]";
  Real p4cz "Link 4 center Z [m]";

  // ===== Collision Kinematics Helpers =====
  Real Rx13 "Radial comp pair 1-3 [m]";
  Real Rz13 "Vertical comp pair 1-3 [m]";
  Real Rx14 "Radial comp pair 1-4 [m]";
  Real Rz14 "Vertical comp pair 1-4 [m]";
  Real Rx24 "Radial comp pair 2-4 [m]";
  Real Rz24 "Vertical comp pair 2-4 [m]";

equation
  // ===== Forward Kinematics =====
  // Joint 1 rotates about Z, joint 2 about Y, joint 3 about Y, joint 4 about X
  // Links extend along local Z; q1 rotates the arm plane about world Z
  p2cx = (L2 / 2.0 * sin(q2)) * cos(q1);
  p2cy = (L2 / 2.0 * sin(q2)) * sin(q1);
  p2cz = L1 + L2 / 2.0 * cos(q2);

  p3cx = (L2 * sin(q2) + L3 / 2.0 * sin(q2 + q3)) * cos(q1);
  p3cy = (L2 * sin(q2) + L3 / 2.0 * sin(q2 + q3)) * sin(q1);
  p3cz = L1 + L2 * cos(q2) + L3 / 2.0 * cos(q2 + q3);

  p4cx = (L2 * sin(q2) + (L3 + L4 / 2.0) * sin(q2 + q3)) * cos(q1);
  p4cy = (L2 * sin(q2) + (L3 + L4 / 2.0) * sin(q2 + q3)) * sin(q1);
  p4cz = L1 + L2 * cos(q2) + (L3 + L4 / 2.0) * cos(q2 + q3);

  tip_x = (L2 * sin(q2) + (L3 + L4) * sin(q2 + q3)) * cos(q1);
  tip_y = (L2 * sin(q2) + (L3 + L4) * sin(q2 + q3)) * sin(q1);
  tip_z = L1 + L2 * cos(q2) + (L3 + L4) * cos(q2 + q3);

  // ===== Self-Collision Distances (nonadjacent pairs: 1-3, 1-4, 2-4) =====
  // Link 1 center at [0, 0, L1/2]; q1 cancels in radial-vertical decomposition
  Rx13 = L2 * sin(q2) + L3 / 2.0 * sin(q2 + q3);
  Rz13 = L1 / 2.0 + L2 * cos(q2) + L3 / 2.0 * cos(q2 + q3);
  d13 = sqrt(Rx13 * Rx13 + Rz13 * Rz13 + 1.0e-12);

  Rx14 = L2 * sin(q2) + (L3 + L4 / 2.0) * sin(q2 + q3);
  Rz14 = L1 / 2.0 + L2 * cos(q2) + (L3 + L4 / 2.0) * cos(q2 + q3);
  d14 = sqrt(Rx14 * Rx14 + Rz14 * Rz14 + 1.0e-12);

  Rx24 = L2 / 2.0 * sin(q2) + (L3 + L4 / 2.0) * sin(q2 + q3);
  Rz24 = L2 / 2.0 * cos(q2) + (L3 + L4 / 2.0) * cos(q2 + q3);
  d24 = sqrt(Rx24 * Rx24 + Rz24 * Rz24 + 1.0e-12);

  // Penetration (positive when distance below safe threshold)
  pen13 = max(0.0, d_safe - d13);
  pen14 = max(0.0, d_safe - d14);
  pen24 = max(0.0, d_safe - d24);

  // Gradients of distance w.r.t. joint angles (for repulsive generalized force)
  d13_q2 = (Rx13 * (L2 * cos(q2) + L3 / 2.0 * cos(q2 + q3)) + Rz13 * (-L2 * sin(q2) - L3 / 2.0 * sin(q2 + q3))) / max(d13, 0.01);
  d13_q3 = (Rx13 * (L3 / 2.0 * cos(q2 + q3)) + Rz13 * (-L3 / 2.0 * sin(q2 + q3))) / max(d13, 0.01);

  d14_q2 = (Rx14 * (L2 * cos(q2) + (L3 + L4 / 2.0) * cos(q2 + q3)) + Rz14 * (-L2 * sin(q2) - (L3 + L4 / 2.0) * sin(q2 + q3))) / max(d14, 0.01);
  d14_q3 = (Rx14 * ((L3 + L4 / 2.0) * cos(q2 + q3)) + Rz14 * (-(L3 + L4 / 2.0) * sin(q2 + q3))) / max(d14, 0.01);

  d24_q2 = (Rx24 * (L2 / 2.0 * cos(q2) + (L3 + L4 / 2.0) * cos(q2 + q3)) + Rz24 * (-L2 / 2.0 * sin(q2) - (L3 + L4 / 2.0) * sin(q2 + q3))) / max(d24, 0.01);
  d24_q3 = (Rx24 * ((L3 + L4 / 2.0) * cos(q2 + q3)) + Rz24 * (-(L3 + L4 / 2.0) * sin(q2 + q3))) / max(d24, 0.01);

  // Collision torques: repulsive generalized force = k * pen * dd/dq
  // Distances depend only on q2, q3 (q1 cancels; q4 does not affect positions)
  tau1_c = 0.0;
  tau2_c = k_coll * (pen13 * d13_q2 + pen14 * d14_q2 + pen24 * d24_q2);
  tau3_c = k_coll * (pen13 * d13_q3 + pen14 * d14_q3 + pen24 * d24_q3);
  tau4_c = 0.0;

  // ===== Gravity Torques =====
  // Joint 1 (Z axis): rotation about vertical, no gravity torque
  tau1_g = 0.0;
  // Joint 2 (Y axis): gravity torque from links 2, 3, 4
  tau2_g = g_acc * (
    m2 * (L2 / 2.0) * sin(q2) +
    m3 * (L2 * sin(q2) + L3 / 2.0 * sin(q2 + q3)) +
    m4 * (L2 * sin(q2) + (L3 + L4 / 2.0) * sin(q2 + q3)));
  // Joint 3 (Y axis): gravity torque from links 3, 4
  tau3_g = g_acc * (
    m3 * (L3 / 2.0) * sin(q2 + q3) +
    m4 * ((L3 + L4 / 2.0) * sin(q2 + q3)));
  // Joint 4 (X axis): rotation along link axis, negligible gravity torque
  tau4_g = 0.0;

  // ===== Disturbance: 18 N lateral (world Y) at distal end, middle third =====
  dist_active = if time >= t_dist_start and time <= t_dist_end then 1.0 else 0.0;

  // Torques from lateral Y force at distal end on each joint
  // Joint 1 (Z): tau_z = tip_x * F_y
  tau1_d = tip_x * F_dist * dist_active;
  // Joint 2 (Y): local X force component = sin(q1)*F_y, moment arm = vertical reach from J2
  tau2_d = (L2 * cos(q2) + (L3 + L4) * cos(q2 + q3)) * sin(q1) * F_dist * dist_active;
  // Joint 3 (Y): moment arm from J3 to distal end
  tau3_d = (L3 + L4) * cos(q2 + q3) * sin(q1) * F_dist * dist_active;
  // Joint 4 (X): moment arm from J4 to distal end
  tau4_d = L4 * cos(q2 + q3) * sin(q1) * F_dist * dist_active;

  // ===== Tracking Errors =====
  err1 = q1_ref - q1;
  err2 = q2_ref - q2;
  err3 = q3_ref - q3;
  err4 = q4_ref - q4;
  max_err = max(abs(err1), max(abs(err2), max(abs(err3), abs(err4))));

  // ===== Controller: Saturated State-Feedback + Integral + Gravity Feedforward =====
  tau1_cmd = Kp1 * err1 + Kd1 * (-qd1) + Ki1 * integ1 + tau1_g;
  tau2_cmd = Kp2 * err2 + Kd2 * (-qd2) + Ki2 * integ2 + tau2_g;
  tau3_cmd = Kp3 * err3 + Kd3 * (-qd3) + Ki3 * integ3 + tau3_g;
  tau4_cmd = Kp4 * err4 + Kd4 * (-qd4) + Ki4 * integ4 + tau4_g;

  // Saturated torques (effort limit 110 N.m)
  tau1 = if tau1_cmd > tau_max then tau_max else if tau1_cmd < -tau_max then -tau_max else tau1_cmd;
  tau2 = if tau2_cmd > tau_max then tau_max else if tau2_cmd < -tau_max then -tau_max else tau2_cmd;
  tau3 = if tau3_cmd > tau_max then tau_max else if tau3_cmd < -tau_max then -tau_max else tau3_cmd;
  tau4 = if tau4_cmd > tau_max then tau_max else if tau4_cmd < -tau_max then -tau_max else tau4_cmd;

  // Integral anti-windup: conditional integration stops when saturated and
  // error drives further into saturation
  der(integ1) = if noEvent(abs(tau1_cmd) > tau_max and tau1_cmd * err1 > 0.0) then 0.0 else err1;
  der(integ2) = if noEvent(abs(tau2_cmd) > tau_max and tau2_cmd * err2 > 0.0) then 0.0 else err2;
  der(integ3) = if noEvent(abs(tau3_cmd) > tau_max and tau3_cmd * err3 > 0.0) then 0.0 else err3;
  der(integ4) = if noEvent(abs(tau4_cmd) > tau_max and tau4_cmd * err4 > 0.0) then 0.0 else err4;

  // ===== Plant Dynamics =====
  // J_i * qdd_i = tau_i - b_i*qd_i - tau_grav_i + tau_dist_i + tau_coll_i
  J1 * der(qd1) = tau1 - b1 * qd1 - tau1_g + tau1_d + tau1_c;
  J2 * der(qd2) = tau2 - b2 * qd2 - tau2_g + tau2_d + tau2_c;
  J3 * der(qd3) = tau3 - b3 * qd3 - tau3_g + tau3_d + tau3_c;
  J4 * der(qd4) = tau4 - b4 * qd4 - tau4_g + tau4_d + tau4_c;

  der(q1) = qd1;
  der(q2) = qd2;
  der(q3) = qd3;
  der(q4) = qd4;

  // ===== Sensors =====
  // Encoders: record joint response before, during, and after load
  enc1 = q1;
  enc2 = q2;
  enc3 = q3;
  enc4 = q4;
  encv1 = qd1;
  encv2 = qd2;
  encv3 = qd3;
  encv4 = qd4;

  // Wrist wrench sensor: reaction force/torque at wrist (world frame)
  // Measures disturbance force and gravity load before, during, and after load
  wr_fx = 0.0;
  wr_fy = -F_dist * dist_active;
  wr_fz = -m4 * g_acc;
  wr_tx = tau4;
  wr_ty = m4 * g_acc * (L4 / 2.0) * sin(q2 + q3) * cos(q1);
  wr_tz = m4 * g_acc * (L4 / 2.0) * sin(q2 + q3) * sin(q1);

  // ===== Peak Deviation Tracking (sampled at 200 Hz) =====
  when sample(0.0, 1.0 / 200.0) then
    peak_dev = max(pre(peak_dev), max(abs(err1), max(abs(err2), max(abs(err3), abs(err4)))));
  end when;

  annotation(
    experiment(StartTime = 0, StopTime = 14, Tolerance = 1e-6, Interval = 0.005),
    Documentation(info = "<html>
<p>AssemblyArmRejectD: Fixed-base 4-DOF articulated manipulator with Z-Y-Y-X revolute axes.</p>
<p>Capsule-link lengths: 0.50, 0.40, 0.28, 0.16 m. Masses: 7, 5, 3, 1 kg.</p>
<p>Saturated state-feedback (PD) with integral disturbance rejection and gravity feedforward.</p>
<p>Torque limit: 110 N.m. Disturbance: 18 N lateral at distal end during middle third (4.67-9.33 s).</p>
<p>Self-collision modeled between nonadjacent link pairs via repulsive potential gradient.</p>
<p>Run at 200 Hz (Interval=0.005 s) for 14 s. Synchronized state, command, and sensor traces retained.</p>
</html>")
  );
end AssemblyArmRejectD;