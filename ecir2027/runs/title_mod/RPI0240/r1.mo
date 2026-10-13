model AssemblyArmRejectF
  "Fixed-base 4-DOF articulated manipulator: hold nonzero target, reject finite lateral load"

  // --- Link parameters ---
  parameter Real L1 = 0.50 "Link 1 length [m]";
  parameter Real L2 = 0.40 "Link 2 length [m]";
  parameter Real L3 = 0.28 "Link 3 length [m]";
  parameter Real L4 = 0.16 "Link 4 length [m]";
  parameter Real m1 = 7.0 "Link 1 mass [kg]";
  parameter Real m2 = 5.0 "Link 2 mass [kg]";
  parameter Real m3 = 3.0 "Link 3 mass [kg]";
  parameter Real m4 = 1.0 "Link 4 mass [kg]";
  parameter Real g = 9.81 "Gravitational acceleration [m/s^2]";

  // --- Effective joint inertias ---
  parameter Real J1 = 4.0 "Joint 1 (Z-axis) effective inertia [kg.m^2]";
  parameter Real J2 = 1.0 "Joint 2 (Y-axis) effective inertia [kg.m^2]";
  parameter Real J3 = 0.18 "Joint 3 (Y-axis) effective inertia [kg.m^2]";
  parameter Real J4 = 0.012 "Joint 4 (X-axis) effective inertia [kg.m^2]";

  // --- Actuator saturation ---
  parameter Real tau_max = 134.0 "Maximum joint torque [N.m]";

  // --- Saturated state-feedback gains with integral action ---
  parameter Real Kp1 = 500.0 "Joint 1 proportional gain [N.m/rad]";
  parameter Real Kp2 = 500.0 "Joint 2 proportional gain [N.m/rad]";
  parameter Real Kp3 = 250.0 "Joint 3 proportional gain [N.m/rad]";
  parameter Real Kp4 = 120.0 "Joint 4 proportional gain [N.m/rad]";
  parameter Real Kd1 = 65.0 "Joint 1 derivative gain [N.m.s/rad]";
  parameter Real Kd2 = 45.0 "Joint 2 derivative gain [N.m.s/rad]";
  parameter Real Kd3 = 22.0 "Joint 3 derivative gain [N.m.s/rad]";
  parameter Real Kd4 = 10.0 "Joint 4 derivative gain [N.m.s/rad]";
  parameter Real Ki1 = 80.0 "Joint 1 integral gain [N.m/(rad.s)]";
  parameter Real Ki2 = 60.0 "Joint 2 integral gain [N.m/(rad.s)]";
  parameter Real Ki3 = 35.0 "Joint 3 integral gain [N.m/(rad.s)]";
  parameter Real Ki4 = 15.0 "Joint 4 integral gain [N.m/(rad.s)]";

  // --- Nonzero joint target ---
  parameter Real q1_ref = 0.3 "Joint 1 target [rad]";
  parameter Real q2_ref = 0.5 "Joint 2 target [rad]";
  parameter Real q3_ref = -0.4 "Joint 3 target [rad]";
  parameter Real q4_ref = 0.2 "Joint 4 target [rad]";

  // --- Disturbance ---
  parameter Real F_dist = 26.1 "Lateral disturbance force magnitude [N]";
  parameter Real t_dist_on = 6.6667 "Disturbance onset [s] (middle third of 20 s)";
  parameter Real t_dist_off = 13.3333 "Disturbance offset [s] (middle third of 20 s)";
  parameter Real t_ramp = 1.0 "Smooth ramp duration [s]";

  // --- Self-collision ---
  parameter Real d_safe = 0.06 "Safe-pair distance threshold [m]";
  parameter Real d_coll = 0.03 "Collision detection threshold [m]";
  parameter Real k_coll = 1000.0 "Collision repulsion stiffness [N.m/m]";

  // --- Joint states (initialised at target for hold mission) ---
  Real q1(start = 0.3) "Joint 1 angle, Z-axis [rad]";
  Real q2(start = 0.5) "Joint 2 angle, Y-axis [rad]";
  Real q3(start = -0.4) "Joint 3 angle, Y-axis [rad]";
  Real q4(start = 0.2) "Joint 4 angle, X-axis [rad]";
  Real qd1(start = 0.0) "Joint 1 velocity [rad/s]";
  Real qd2(start = 0.0) "Joint 2 velocity [rad/s]";
  Real qd3(start = 0.0) "Joint 3 velocity [rad/s]";
  Real qd4(start = 0.0) "Joint 4 velocity [rad/s]";
  Real xi1(start = 0.0) "Joint 1 integral state [rad.s]";
  Real xi2(start = 0.0) "Joint 2 integral state [rad.s]";
  Real xi3(start = 0.0) "Joint 3 integral state [rad.s]";
  Real xi4(start = 0.0) "Joint 4 integral state [rad.s]";

  // --- Tracking errors ---
  Real e1 "Joint 1 tracking error [rad]";
  Real e2 "Joint 2 tracking error [rad]";
  Real e3 "Joint 3 tracking error [rad]";
  Real e4 "Joint 4 tracking error [rad]";

  // --- Control commands and saturated torques ---
  Real tau1_cmd "Joint 1 raw command [N.m]";
  Real tau2_cmd "Joint 2 raw command [N.m]";
  Real tau3_cmd "Joint 3 raw command [N.m]";
  Real tau4_cmd "Joint 4 raw command [N.m]";
  Real tau1 "Joint 1 saturated torque [N.m]";
  Real tau2 "Joint 2 saturated torque [N.m]";
  Real tau3 "Joint 3 saturated torque [N.m]";
  Real tau4 "Joint 4 saturated torque [N.m]";

  // --- Gravity torques ---
  Real tg1 "Joint 1 gravity torque [N.m]";
  Real tg2 "Joint 2 gravity torque [N.m]";
  Real tg3 "Joint 3 gravity torque [N.m]";
  Real tg4 "Joint 4 gravity torque [N.m]";

  // --- Disturbance ---
  Real F_act "Active disturbance force [N]";
  Real td1 "Joint 1 disturbance torque [N.m]";
  Real td2 "Joint 2 disturbance torque [N.m]";
  Real td3 "Joint 3 disturbance torque [N.m]";
  Real td4 "Joint 4 disturbance torque [N.m]";

  // --- Collision repulsion torques ---
  Real tc1 "Joint 1 collision torque [N.m]";
  Real tc2 "Joint 2 collision torque [N.m]";
  Real tc3 "Joint 3 collision torque [N.m]";
  Real tc4 "Joint 4 collision torque [N.m]";

  // --- Forward kinematics: link centre positions [m] ---
  Real c1x, c1y, c1z;
  Real c2x, c2y, c2z;
  Real c3x, c3y, c3z;
  Real c4x, c4y, c4z;

  // --- Nonadjacent link pair distances ---
  Real d13 "Distance links 1-3 [m]";
  Real d14 "Distance links 1-4 [m]";
  Real d24 "Distance links 2-4 [m]";
  Real d_min_nn "Minimum nonadjacent distance [m]";

  // --- Wrist wrench sensor ---
  Real F_sensor "Wrist lateral force sensor reading [N]";

  // --- Verification observables ---
  Real max_err "Maximum absolute tracking error across joints [rad]";
  discrete Real peak_dev(start = 0.0) "Peak deviation since start [rad]";
  Boolean in_target_band "True when all errors below 0.028 rad";
  Boolean collision_detected "True when any nonadjacent pair below d_coll";

equation
  // ===== Forward kinematics (simplified capsule centres) =====
  // Link 1: vertical along Z from base
  c1x = 0.0;
  c1y = 0.0;
  c1z = L1 / 2.0;

  // Link 2: from joint 2 in the arm plane rotated by q1 about Z
  c2x = (L2 / 2.0) * cos(q2) * cos(q1);
  c2y = (L2 / 2.0) * cos(q2) * sin(q1);
  c2z = L1 + (L2 / 2.0) * sin(q2);

  // Link 3: continues from link 2 end
  c3x = (L2 * cos(q2) + (L3 / 2.0) * cos(q2 + q3)) * cos(q1);
  c3y = (L2 * cos(q2) + (L3 / 2.0) * cos(q2 + q3)) * sin(q1);
  c3z = L1 + L2 * sin(q2) + (L3 / 2.0) * sin(q2 + q3);

  // Link 4: distal, roll about X does not change centre in arm plane
  c4x = (L2 * cos(q2) + L3 * cos(q2 + q3) + (L4 / 2.0) * cos(q2 + q3)) * cos(q1);
  c4y = (L2 * cos(q2) + L3 * cos(q2 + q3) + (L4 / 2.0) * cos(q2 + q3)) * sin(q1);
  c4z = L1 + L2 * sin(q2) + L3 * sin(q2 + q3) + (L4 / 2.0) * sin(q2 + q3);

  // ===== Collision distances (nonadjacent: 1-3, 1-4, 2-4) =====
  d13 = sqrt((c1x - c3x)^2 + (c1y - c3y)^2 + (c1z - c3z)^2);
  d14 = sqrt((c1x - c4x)^2 + (c1y - c4y)^2 + (c1z - c4z)^2);
  d24 = sqrt((c2x - c4x)^2 + (c2y - c4y)^2 + (c2z - c4z)^2);
  d_min_nn = min(d13, min(d14, d24));

  // ===== Soft collision repulsion =====
  // Repulsion acts on joints 2 and 3 to push distal links away from base links
  tc1 = 0.0;
  tc2 = (if d13 < d_safe then k_coll * (d_safe - d13) else 0.0)
      + (if d14 < d_safe then k_coll * 0.7 * (d_safe - d14) else 0.0);
  tc3 = (if d13 < d_safe then -k_coll * (d_safe - d13) else 0.0)
      + (if d14 < d_safe then -k_coll * 0.7 * (d_safe - d14) else 0.0)
      + (if d24 < d_safe then k_coll * 0.5 * (d_safe - d24) else 0.0);
  tc4 = 0.0;

  // ===== Gravity torques =====
  tg1 = 0.0;
  tg2 = g * cos(q2) * (m2 * L2 / 2.0 + (m3 + m4) * L2)
      + g * cos(q2 + q3) * (m3 * L3 / 2.0 + m4 * L3)
      + g * cos(q2 + q3) * m4 * L4 / 2.0;
  tg3 = g * cos(q2 + q3) * (m3 * L3 / 2.0 + m4 * L3)
      + g * cos(q2 + q3) * m4 * L4 / 2.0;
  tg4 = 0.0;

  // ===== Disturbance force profile (smooth raised-cosine window) =====
  F_act = if time < t_dist_on then 0.0
          else if time < t_dist_on + t_ramp then
            F_dist * (1.0 - cos(Modelica.Constants.pi * (time - t_dist_on) / t_ramp)) / 2.0
          else if time < t_dist_off - t_ramp then F_dist
          else if time < t_dist_off then
            F_dist * (1.0 + cos(Modelica.Constants.pi * (time - t_dist_off + t_ramp) / t_ramp)) / 2.0
          else 0.0;

  // Disturbance torques from lateral force at distal link via effective lever arms
  td1 = F_act * (L2 * cos(q2) + L3 * cos(q2 + q3) + L4 * cos(q2 + q3));
  td2 = F_act * (L3 * cos(q2 + q3) + L4 * cos(q2 + q3));
  td3 = F_act * L4 * cos(q2 + q3) * 0.5;
  td4 = 0.0;

  // ===== Tracking errors =====
  e1 = q1_ref - q1;
  e2 = q2_ref - q2;
  e3 = q3_ref - q3;
  e4 = q4_ref - q4;

  // ===== Integral states (disturbance rejection) =====
  der(xi1) = e1;
  der(xi2) = e2;
  der(xi3) = e3;
  der(xi4) = e4;

  // ===== Saturated PD+I control with gravity compensation =====
  tau1_cmd = Kp1 * e1 - Kd1 * qd1 + Ki1 * xi1 + tg1;
  tau2_cmd = Kp2 * e2 - Kd2 * qd2 + Ki2 * xi2 + tg2;
  tau3_cmd = Kp3 * e3 - Kd3 * qd3 + Ki3 * xi3 + tg3;
  tau4_cmd = Kp4 * e4 - Kd4 * qd4 + Ki4 * xi4 + tg4;

  // Torque saturation at +/- tau_max
  tau1 = if tau1_cmd > tau_max then tau_max
         else if tau1_cmd < -tau_max then -tau_max
         else tau1_cmd;
  tau2 = if tau2_cmd > tau_max then tau_max
         else if tau2_cmd < -tau_max then -tau_max
         else tau2_cmd;
  tau3 = if tau3_cmd > tau_max then tau_max
         else if tau3_cmd < -tau_max then -tau_max
         else tau3_cmd;
  tau4 = if tau4_cmd > tau_max then tau_max
         else if tau4_cmd < -tau_max then -tau_max
         else tau4_cmd;

  // ===== Manipulator dynamics =====
  der(q1) = qd1;
  der(q2) = qd2;
  der(q3) = qd3;
  der(q4) = qd4;

  J1 * der(qd1) = tau1 + td1 - tg1 - tc1;
  J2 * der(qd2) = tau2 + td2 - tg2 - tc2;
  J3 * der(qd3) = tau3 + td3 - tg3 - tc3;
  J4 * der(qd4) = tau4 + td4 - tg4 - tc4;

  // ===== Wrist wrench sensor =====
  F_sensor = F_act;

  // ===== Verification observables =====
  max_err = max(abs(e1), max(abs(e2), max(abs(e3), abs(e4))));

  when max_err > peak_dev then
    peak_dev = max_err;
  end when;

  in_target_band = max_err < 0.028;
  collision_detected = d_min_nn < d_coll;

  annotation(
    experiment(StartTime = 0.0, StopTime = 20.0, Tolerance = 1e-6, Interval = 0.002),
    Documentation(info = "AssemblyArmRejectF: 4-DOF fixed-base articulated manipulator (Z, Y, Y, X axes).
      Link lengths 0.50, 0.40, 0.28, 0.16 m; masses 7, 5, 3, 1 kg.
      Mission: hold nonzero joint target {0.3, 0.5, -0.4, 0.2} rad while rejecting 26.1 N
      lateral disturbance applied during middle third (6.667 - 13.333 s) with 1 s smooth ramps.
      Control: saturated PD+I state feedback with gravity compensation, |tau| <= 134 N.m.
      Self-collision: soft repulsion for nonadjacent pairs (1-3, 1-4, 2-4).
      Run at 500 Hz (Interval = 2 ms) for 20 s.
      Verification: finite states, no self-collision, peak deviation < 0.18 rad,
      primary tracking error < 0.028 rad after 13 s, recovery to target band,
      no NaN or infinite values.")
  );
end AssemblyArmRejectF;