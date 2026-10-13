model AssemblyArmRejectF
  "Fixed-base 4-DOF articulated manipulator (Z-Y-Y-X): hold target, reject lateral disturbance"

  // --- Link parameters ---
  parameter Real L1 = 0.50 "capsule-link length 1 [m]";
  parameter Real L2 = 0.40 "capsule-link length 2 [m]";
  parameter Real L3 = 0.28 "capsule-link length 3 [m]";
  parameter Real L4 = 0.16 "capsule-link length 4 [m]";
  parameter Real m1 = 7.0 "link 1 mass [kg]";
  parameter Real m2 = 5.0 "link 2 mass [kg]";
  parameter Real m3 = 3.0 "link 3 mass [kg]";
  parameter Real m4 = 1.0 "link 4 mass [kg]";
  parameter Real lc1 = 0.25 "link 1 COM offset [m]";
  parameter Real lc2 = 0.20 "link 2 COM offset [m]";
  parameter Real lc3 = 0.14 "link 3 COM offset [m]";
  parameter Real lc4 = 0.08 "link 4 COM offset [m]";
  parameter Real Ieff1 = 2.0 "effective joint 1 inertia [kg.m2]";
  parameter Real Ieff2 = 1.5 "effective joint 2 inertia [kg.m2]";
  parameter Real Ieff3 = 0.3 "effective joint 3 inertia [kg.m2]";
  parameter Real Ieff4 = 0.05 "effective joint 4 inertia [kg.m2]";
  parameter Real b1 = 0.5 "joint 1 viscous damping [N.m.s/rad]";
  parameter Real b2 = 0.4 "joint 2 viscous damping [N.m.s/rad]";
  parameter Real b3 = 0.2 "joint 3 viscous damping [N.m.s/rad]";
  parameter Real b4 = 0.05 "joint 4 viscous damping [N.m.s/rad]";

  // --- Environment ---
  parameter Real g_acc = 9.81 "gravitational acceleration [m/s2]";
  parameter Real r_cap = 0.04 "capsule radius [m]";

  // --- Actuation ---
  parameter Real tau_max = 134.0 "maximum joint effort [N.m]";

  // --- Control gains ---
  parameter Real Kp1 = 150.0 "joint 1 position feedback gain";
  parameter Real Kp2 = 100.0 "joint 2 position feedback gain";
  parameter Real Kp3 = 60.0 "joint 3 position feedback gain";
  parameter Real Kp4 = 20.0 "joint 4 position feedback gain";
  parameter Real Kd1 = 20.0 "joint 1 velocity feedback gain";
  parameter Real Kd2 = 15.0 "joint 2 velocity feedback gain";
  parameter Real Kd3 = 6.0 "joint 3 velocity feedback gain";
  parameter Real Kd4 = 1.5 "joint 4 velocity feedback gain";
  parameter Real Ki1 = 50.0 "joint 1 integral gain";
  parameter Real Ki2 = 35.0 "joint 2 integral gain";
  parameter Real Ki3 = 20.0 "joint 3 integral gain";
  parameter Real Ki4 = 8.0 "joint 4 integral gain";
  parameter Real xi_max1 = 3.0 "joint 1 integrator limit [rad.s]";
  parameter Real xi_max2 = 3.0 "joint 2 integrator limit [rad.s]";
  parameter Real xi_max3 = 3.0 "joint 3 integrator limit [rad.s]";
  parameter Real xi_max4 = 3.0 "joint 4 integrator limit [rad.s]";

  // --- Target ---
  parameter Real q_ref1 = 0.5 "joint 1 target [rad]";
  parameter Real q_ref2 = 0.3 "joint 2 target [rad]";
  parameter Real q_ref3 = -0.2 "joint 3 target [rad]";
  parameter Real q_ref4 = 0.1 "joint 4 target [rad]";

  // --- Disturbance ---
  parameter Real F_dist = 26.1 "lateral disturbance force magnitude [N]";
  parameter Real t_start_dist = 20.0 / 3.0 "disturbance start time [s]";
  parameter Real t_end_dist = 40.0 / 3.0 "disturbance end time [s]";

  // --- Collision ---
  parameter Real k_col = 8000.0 "collision penalty stiffness [N/m]";

  // --- Dynamic states ---
  Real q1(start = 0.0, fixed = true) "joint 1 angle [rad]";
  Real q2(start = 0.0, fixed = true) "joint 2 angle [rad]";
  Real q3(start = 0.0, fixed = true) "joint 3 angle [rad]";
  Real q4(start = 0.0, fixed = true) "joint 4 angle [rad]";
  Real w1(start = 0.0, fixed = true) "joint 1 angular velocity [rad/s]";
  Real w2(start = 0.0, fixed = true) "joint 2 angular velocity [rad/s]";
  Real w3(start = 0.0, fixed = true) "joint 3 angular velocity [rad/s]";
  Real w4(start = 0.0, fixed = true) "joint 4 angular velocity [rad/s]";
  Real xi1(start = 0.0, fixed = true) "joint 1 integral error [rad.s]";
  Real xi2(start = 0.0, fixed = true) "joint 2 integral error [rad.s]";
  Real xi3(start = 0.0, fixed = true) "joint 3 integral error [rad.s]";
  Real xi4(start = 0.0, fixed = true) "joint 4 integral error [rad.s]";

  // --- Torques ---
  Real tau_cmd1 "joint 1 unsaturated command [N.m]";
  Real tau_cmd2 "joint 2 unsaturated command [N.m]";
  Real tau_cmd3 "joint 3 unsaturated command [N.m]";
  Real tau_cmd4 "joint 4 unsaturated command [N.m]";
  Real tau_sat1 "joint 1 saturated torque [N.m]";
  Real tau_sat2 "joint 2 saturated torque [N.m]";
  Real tau_sat3 "joint 3 saturated torque [N.m]";
  Real tau_sat4 "joint 4 saturated torque [N.m]";
  Real tau_grav1 "joint 1 gravity torque [N.m]";
  Real tau_grav2 "joint 2 gravity torque [N.m]";
  Real tau_grav3 "joint 3 gravity torque [N.m]";
  Real tau_grav4 "joint 4 gravity torque [N.m]";
  Real tau_dist1 "joint 1 disturbance torque [N.m]";
  Real tau_dist2 "joint 2 disturbance torque [N.m]";
  Real tau_dist3 "joint 3 disturbance torque [N.m]";
  Real tau_dist4 "joint 4 disturbance torque [N.m]";
  Real tau_col1 "joint 1 collision penalty torque [N.m]";
  Real tau_col2 "joint 2 collision penalty torque [N.m]";
  Real tau_col3 "joint 3 collision penalty torque [N.m]";
  Real tau_col4 "joint 4 collision penalty torque [N.m]";

  // --- Kinematics ---
  Real cx1 "link 1 center x [m]";
  Real cy1 "link 1 center y [m]";
  Real cz1 "link 1 center z [m]";
  Real cx2 "link 2 center x [m]";
  Real cy2 "link 2 center y [m]";
  Real cz2 "link 2 center z [m]";
  Real cx3 "link 3 center x [m]";
  Real cy3 "link 3 center y [m]";
  Real cz3 "link 3 center z [m]";
  Real cx4 "link 4 center x [m]";
  Real cy4 "link 4 center y [m]";
  Real cz4 "link 4 center z [m]";
  Real d13 "distance between links 1 and 3 [m]";
  Real d14 "distance between links 1 and 4 [m]";
  Real d24 "distance between links 2 and 4 [m]";
  Real pen13 "penetration links 1-3 [m]";
  Real pen14 "penetration links 1-4 [m]";
  Real pen24 "penetration links 2-4 [m]";
  Real reach "horizontal reach [m]";

  // --- Sensors and observation ---
  Real wrench1 "wrist wrench x [N]";
  Real wrench2 "wrist wrench y [N]";
  Real wrench3 "wrist wrench z [N]";
  Real te1 "joint 1 tracking error [rad]";
  Real te2 "joint 2 tracking error [rad]";
  Real te3 "joint 3 tracking error [rad]";
  Real te4 "joint 4 tracking error [rad]";
  Real te_max "maximum tracking error [rad]";
  Real peak_deviation(start = 0.0, fixed = true) "running peak deviation [rad]";
  Boolean dist_active "disturbance active flag";

  // --- Verification flags ---
  Boolean finite_states;
  Boolean no_collision;
  Boolean peak_ok;
  Boolean recovered;
  Boolean no_nan_inf;

  // --- Anti-windup condition helpers ---
  Boolean aw1_pos "joint 1 anti-windup positive";
  Boolean aw1_neg "joint 1 anti-windup negative";
  Boolean aw2_pos "joint 2 anti-windup positive";
  Boolean aw2_neg "joint 2 anti-windup negative";
  Boolean aw3_pos "joint 3 anti-windup positive";
  Boolean aw3_neg "joint 3 anti-windup negative";
  Boolean aw4_pos "joint 4 anti-windup positive";
  Boolean aw4_neg "joint 4 anti-windup negative";

equation
  // --- Disturbance window ---
  dist_active = (time >= t_start_dist) and (time <= t_end_dist);

  // --- Gravity torques ---
  tau_grav1 = 0.0;
  tau_grav2 = -g_acc * (m2 * lc2 + m3 * L2 + m4 * L2) * cos(q2);
  tau_grav3 = -g_acc * (m3 * lc3 + m4 * L3) * cos(q2 + q3);
  tau_grav4 = -g_acc * m4 * lc4 * sin(q4);

  // --- Link centers (forward kinematics) ---
  cx1 = 0.0;
  cy1 = 0.0;
  cz1 = L1 / 2.0;
  cx2 = cos(q1) * lc2 * cos(q2);
  cy2 = sin(q1) * lc2 * cos(q2);
  cz2 = L1 + lc2 * sin(q2);
  cx3 = cos(q1) * (L2 * cos(q2) + lc3 * cos(q2 + q3));
  cy3 = sin(q1) * (L2 * cos(q2) + lc3 * cos(q2 + q3));
  cz3 = L1 + L2 * sin(q2) + lc3 * sin(q2 + q3);
  cx4 = cos(q1) * (L2 * cos(q2) + L3 * cos(q2 + q3) + lc4 * cos(q2 + q3));
  cy4 = sin(q1) * (L2 * cos(q2) + L3 * cos(q2 + q3) + lc4 * cos(q2 + q3));
  cz4 = L1 + L2 * sin(q2) + (L3 + lc4) * sin(q2 + q3);

  // --- Reach ---
  reach = cos(q1) * (L2 * cos(q2) + (L3 + L4) * cos(q2 + q3));

  // --- Nonadjacent link distances (zero-guarded) ---
  d13 = sqrt((cx1 - cx3) ^ 2 + (cy1 - cy3) ^ 2 + (cz1 - cz3) ^ 2 + 1.0e-12);
  d14 = sqrt((cx1 - cx4) ^ 2 + (cy1 - cy4) ^ 2 + (cz1 - cz4) ^ 2 + 1.0e-12);
  d24 = sqrt((cx2 - cx4) ^ 2 + (cy2 - cy4) ^ 2 + (cz2 - cz4) ^ 2 + 1.0e-12);

  // --- Penetration (positive when overlapping) ---
  pen13 = max(0.0, 2.0 * r_cap - d13);
  pen14 = max(0.0, 2.0 * r_cap - d14);
  pen24 = max(0.0, 2.0 * r_cap - d24);

  // --- Collision penalty torques ---
  tau_col1 = 0.0;
  tau_col2 = k_col * (pen13 * L2 + pen14 * L2);
  tau_col3 = k_col * (pen13 * L3 + pen14 * L3 + pen24 * L3);
  tau_col4 = k_col * (pen14 * L4 + pen24 * L4);

  // --- Disturbance torque via Jacobian-transpose of lateral Y-force ---
  tau_dist1 = if dist_active then cos(q1) * reach * F_dist else 0.0;
  tau_dist2 = if dist_active then sin(q1) * (-L2 * sin(q2) - (L3 + L4) * sin(q2 + q3)) * F_dist else 0.0;
  tau_dist3 = if dist_active then sin(q1) * (-(L3 + L4) * sin(q2 + q3)) * F_dist else 0.0;
  tau_dist4 = 0.0;

  // --- Saturated state-feedback control with integral disturbance rejection ---
  tau_cmd1 = Kp1 * (q_ref1 - q1) - Kd1 * w1 + Ki1 * xi1 - tau_grav1;
  tau_sat1 = max(-tau_max, min(tau_max, tau_cmd1));

  tau_cmd2 = Kp2 * (q_ref2 - q2) - Kd2 * w2 + Ki2 * xi2 - tau_grav2;
  tau_sat2 = max(-tau_max, min(tau_max, tau_cmd2));

  tau_cmd3 = Kp3 * (q_ref3 - q3) - Kd3 * w3 + Ki3 * xi3 - tau_grav3;
  tau_sat3 = max(-tau_max, min(tau_max, tau_cmd3));

  tau_cmd4 = Kp4 * (q_ref4 - q4) - Kd4 * w4 + Ki4 * xi4 - tau_grav4;
  tau_sat4 = max(-tau_max, min(tau_max, tau_cmd4));

  // --- Anti-windup conditions ---
  aw1_pos = (tau_sat1 >= tau_max - 0.001 and (q_ref1 - q1) > 0.0) or (xi1 >= xi_max1 and (q_ref1 - q1) > 0.0);
  aw1_neg = (tau_sat1 <= -tau_max + 0.001 and (q_ref1 - q1) < 0.0) or (xi1 <= -xi_max1 and (q_ref1 - q1) < 0.0);
  aw2_pos = (tau_sat2 >= tau_max - 0.001 and (q_ref2 - q2) > 0.0) or (xi2 >= xi_max2 and (q_ref2 - q2) > 0.0);
  aw2_neg = (tau_sat2 <= -tau_max + 0.001 and (q_ref2 - q2) < 0.0) or (xi2 <= -xi_max2 and (q_ref2 - q2) < 0.0);
  aw3_pos = (tau_sat3 >= tau_max - 0.001 and (q_ref3 - q3) > 0.0) or (xi3 >= xi_max3 and (q_ref3 - q3) > 0.0);
  aw3_neg = (tau_sat3 <= -tau_max + 0.001 and (q_ref3 - q3) < 0.0) or (xi3 <= -xi_max3 and (q_ref3 - q3) < 0.0);
  aw4_pos = (tau_sat4 >= tau_max - 0.001 and (q_ref4 - q4) > 0.0) or (xi4 >= xi_max4 and (q_ref4 - q4) > 0.0);
  aw4_neg = (tau_sat4 <= -tau_max + 0.001 and (q_ref4 - q4) < 0.0) or (xi4 <= -xi_max4 and (q_ref4 - q4) < 0.0);

  // --- Integrator dynamics with anti-windup ---
  der(xi1) = if aw1_pos or aw1_neg then 0.0 else (q_ref1 - q1);
  der(xi2) = if aw2_pos or aw2_neg then 0.0 else (q_ref2 - q2);
  der(xi3) = if aw3_pos or aw3_neg then 0.0 else (q_ref3 - q3);
  der(xi4) = if aw4_pos or aw4_neg then 0.0 else (q_ref4 - q4);

  // --- Plant dynamics ---
  der(q1) = w1;
  der(q2) = w2;
  der(q3) = w3;
  der(q4) = w4;

  Ieff1 * der(w1) = tau_sat1 + tau_grav1 + tau_dist1 + tau_col1 - b1 * w1;
  Ieff2 * der(w2) = tau_sat2 + tau_grav2 + tau_dist2 + tau_col2 - b2 * w2;
  Ieff3 * der(w3) = tau_sat3 + tau_grav3 + tau_dist3 + tau_col3 - b3 * w3;
  Ieff4 * der(w4) = tau_sat4 + tau_grav4 + tau_dist4 + tau_col4 - b4 * w4;

  // --- Wrist wrench sensor ---
  wrench1 = if dist_active then F_dist else 0.0;
  wrench2 = 0.0;
  wrench3 = m4 * g_acc;

  // --- Tracking error ---
  te1 = abs(q1 - q_ref1);
  te2 = abs(q2 - q_ref2);
  te3 = abs(q3 - q_ref3);
  te4 = abs(q4 - q_ref4);

  te_max = max(max(te1, te2), max(te3, te4));

  // --- Running peak deviation (single when clause) ---
  when te_max > pre(peak_deviation) then
    peak_deviation = te_max;
  end when;

  // --- Verification flags ---
  finite_states = (abs(q1) < 1.0e6) and (abs(q2) < 1.0e6) and
                  (abs(q3) < 1.0e6) and (abs(q4) < 1.0e6) and
                  (abs(w1) < 1.0e6) and (abs(w2) < 1.0e6) and
                  (abs(w3) < 1.0e6) and (abs(w4) < 1.0e6) and
                  (abs(xi1) < 1.0e6) and (abs(xi2) < 1.0e6) and
                  (abs(xi3) < 1.0e6) and (abs(xi4) < 1.0e6);

  no_collision = (pen13 < 1.0e-6) and (pen14 < 1.0e-6) and (pen24 < 1.0e-6);
  peak_ok = peak_deviation < 0.18;
  recovered = (time > 13.0) and (te_max < 0.028);
  no_nan_inf = finite_states and
               (abs(tau_sat1) < 1.0e6) and (abs(tau_sat2) < 1.0e6) and
               (abs(tau_sat3) < 1.0e6) and (abs(tau_sat4) < 1.0e6) and
               (abs(tau_cmd1) < 1.0e6) and (abs(tau_cmd2) < 1.0e6) and
               (abs(tau_cmd3) < 1.0e6) and (abs(tau_cmd4) < 1.0e6) and
               (abs(wrench1) < 1.0e6) and (abs(wrench2) < 1.0e6) and (abs(wrench3) < 1.0e6);

  // --- Assertions for verification criteria ---
  assert(no_nan_inf, "Non-finite physical, control, or estimator value detected");
  assert(no_collision, "Self-collision detected between nonadjacent links");
  assert(peak_deviation < 0.18, "Peak deviation exceeds 0.18 rad threshold");

  annotation(
    experiment(StartTime = 0, StopTime = 20.0, Tolerance = 1.0e-6, Interval = 0.002),
    Documentation(info = "AssemblyArmRejectF: 4-DOF fixed-base manipulator (Z-Y-Y-X axes)
      with capsule links of lengths 0.50, 0.40, 0.28, 0.16 m and masses 7, 5, 3, 1 kg.
      Saturated state-feedback (position + velocity) with integral disturbance rejection,
      effort limited to 134 N.m. Gravity modeled on Y and X axes. Self-collision between
      nonadjacent links (1-3, 1-4, 2-4) modeled via capsule penalty. A 26.1 N lateral
      disturbance acts on the distal link during the middle third [6.67 s, 13.33 s].
      Runs at 500 Hz for 20 s. Verification: finite states, no self-collision,
      peak deviation < 0.18 rad, primary tracking error < 0.028 rad after 13 s,
      no NaN or infinite values.")
  );
end AssemblyArmRejectF;