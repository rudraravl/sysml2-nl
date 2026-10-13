model AssemblyArmRejectF
  "Fixed-base 4-DOF articulated manipulator (Z-Y-Y-X): hold target, reject lateral disturbance"

  // --- Link parameters ---
  parameter Real L[4] = {0.50, 0.40, 0.28, 0.16} "capsule-link lengths [m]";
  parameter Real m[4] = {7.0, 5.0, 3.0, 1.0} "link masses [kg]";
  parameter Real lc[4] = {0.25, 0.20, 0.14, 0.08} "link COM offsets [m]";
  parameter Real Ieff[4] = {2.0, 1.5, 0.3, 0.05} "effective joint inertias [kg.m2]";
  parameter Real b[4] = {0.5, 0.4, 0.2, 0.05} "joint viscous damping [N.m.s/rad]";

  // --- Environment ---
  parameter Real g_acc = 9.81 "gravitational acceleration [m/s2]";
  parameter Real r_cap = 0.04 "capsule radius [m]";

  // --- Actuation ---
  parameter Real tau_max = 134.0 "maximum joint effort [N.m]";

  // --- Control gains ---
  parameter Real Kp[4] = {150.0, 100.0, 60.0, 20.0} "position feedback gains";
  parameter Real Kd[4] = {20.0, 15.0, 6.0, 1.5} "velocity feedback gains";
  parameter Real Ki[4] = {50.0, 35.0, 20.0, 8.0} "integral disturbance rejection gains";
  parameter Real xi_max[4] = {3.0, 3.0, 3.0, 3.0} "integrator limits [rad.s]";

  // --- Target ---
  parameter Real q_ref[4] = {0.5, 0.3, -0.2, 0.1} "joint target [rad]";

  // --- Disturbance ---
  parameter Real F_dist = 26.1 "lateral disturbance force magnitude [N]";
  parameter Real t_start_dist = 20.0 / 3.0 "disturbance start time [s]";
  parameter Real t_end_dist = 40.0 / 3.0 "disturbance end time [s]";

  // --- Collision ---
  parameter Real k_col = 8000.0 "collision penalty stiffness [N/m]";

  // --- Timing ---
  parameter Real dt = 0.002 "sample period [s] (500 Hz)";

  // --- Dynamic states ---
  Real q[4](each start = 0.0, each fixed = true) "joint angles [rad]";
  Real w[4](each start = 0.0, each fixed = true) "joint angular velocities [rad/s]";
  Real xi[4](each start = 0.0, each fixed = true) "integral error states [rad.s]";

  // --- Torques ---
  Real tau_cmd[4] "unsaturated command [N.m]";
  Real tau_sat[4] "saturated applied torque [N.m]";
  Real tau_grav[4] "gravity torque on each joint [N.m]";
  Real tau_dist[4] "disturbance torque on each joint [N.m]";
  Real tau_col[4] "collision penalty torque [N.m]";

  // --- Kinematics ---
  Real px[4] "joint x-position [m]";
  Real py[4] "joint y-position [m]";
  Real pz[4] "joint z-position [m]";
  Real cx[4] "link center x [m]";
  Real cy[4] "link center y [m]";
  Real cz[4] "link center z [m]";
  Real d13 "distance between links 1 and 3 [m]";
  Real d14 "distance between links 1 and 4 [m]";
  Real d24 "distance between links 2 and 4 [m]";
  Real pen13 "penetration links 1-3 [m]";
  Real pen14 "penetration links 1-4 [m]";
  Real pen24 "penetration links 2-4 [m]";
  Real reach "horizontal reach [m]";
  Real height_ee "end-effector height [m]";

  // --- Sensors and observation ---
  Real wrench[3] "wrist wrench sensor [N]";
  Real tracking_error[4] "per-joint absolute tracking error [rad]";
  Real primary_error "maximum tracking error across joints [rad]";
  discrete Real peak_deviation(start = 0.0, fixed = true) "running peak deviation [rad]";
  Boolean dist_active "disturbance active flag";

  // --- Verification flags ---
  Boolean finite_states;
  Boolean no_collision;
  Boolean peak_ok;
  Boolean recovered;
  Boolean no_nan_inf;

  // --- Anti-windup flags ---
  Boolean aw1 "anti-windup flag joint 1";
  Boolean aw2 "anti-windup flag joint 2";
  Boolean aw3 "anti-windup flag joint 3";
  Boolean aw4 "anti-windup flag joint 4";

equation
  // --- Disturbance window ---
  dist_active = (time >= t_start_dist) and (time <= t_end_dist);

  // --- Gravity torques (q2 measured from horizontal, q3 relative to link 2, q4 about X) ---
  tau_grav[1] = 0.0;
  tau_grav[2] = -g_acc * (m[2] * lc[2] + m[3] * L[2] + m[4] * L[2]) * cos(q[2]);
  tau_grav[3] = -g_acc * (m[3] * lc[3] + m[4] * L[3]) * cos(q[2] + q[3]);
  tau_grav[4] = -g_acc * m[4] * lc[4] * sin(q[4]);

  // --- Forward kinematics: joint positions ---
  px[1] = 0.0;
  py[1] = 0.0;
  pz[1] = 0.0;
  px[2] = 0.0;
  py[2] = 0.0;
  pz[2] = L[1];
  px[3] = cos(q[1]) * L[2] * cos(q[2]);
  py[3] = sin(q[1]) * L[2] * cos(q[2]);
  pz[3] = L[1] + L[2] * sin(q[2]);
  px[4] = cos(q[1]) * (L[2] * cos(q[2]) + L[3] * cos(q[2] + q[3]));
  py[4] = sin(q[1]) * (L[2] * cos(q[2]) + L[3] * cos(q[2] + q[3]));
  pz[4] = L[1] + L[2] * sin(q[2]) + L[3] * sin(q[2] + q[3]);

  // --- Link centers ---
  cx[1] = 0.0;
  cy[1] = 0.0;
  cz[1] = L[1] / 2.0;
  cx[2] = cos(q[1]) * lc[2] * cos(q[2]);
  cy[2] = sin(q[1]) * lc[2] * cos(q[2]);
  cz[2] = L[1] + lc[2] * sin(q[2]);
  cx[3] = cos(q[1]) * (L[2] * cos(q[2]) + lc[3] * cos(q[2] + q[3]));
  cy[3] = sin(q[1]) * (L[2] * cos(q[2]) + lc[3] * cos(q[2] + q[3]));
  cz[3] = L[1] + L[2] * sin(q[2]) + lc[3] * sin(q[2] + q[3]);
  cx[4] = cos(q[1]) * (L[2] * cos(q[2]) + (L[3] + lc[4]) * cos(q[2] + q[3]));
  cy[4] = sin(q[1]) * (L[2] * cos(q[2]) + (L[3] + lc[4]) * cos(q[2] + q[3]));
  cz[4] = L[1] + L[2] * sin(q[2]) + (L[3] + lc[4]) * sin(q[2] + q[3]);

  // --- Reach and height ---
  reach = cos(q[1]) * (L[2] * cos(q[2]) + (L[3] + L[4]) * cos(q[2] + q[3]));
  height_ee = L[1] + L[2] * sin(q[2]) + (L[3] + L[4]) * sin(q[2] + q[3]);

  // --- Nonadjacent link distances (zero-guarded) ---
  d13 = sqrt((cx[1] - cx[3]) ^ 2 + (cy[1] - cy[3]) ^ 2 + (cz[1] - cz[3]) ^ 2 + 1.0e-12);
  d14 = sqrt((cx[1] - cx[4]) ^ 2 + (cy[1] - cy[4]) ^ 2 + (cz[1] - cz[4]) ^ 2 + 1.0e-12);
  d24 = sqrt((cx[2] - cx[4]) ^ 2 + (cy[2] - cy[4]) ^ 2 + (cz[2] - cz[4]) ^ 2 + 1.0e-12);

  // --- Penetration (positive when overlapping) ---
  pen13 = max(0.0, 2.0 * r_cap - d13);
  pen14 = max(0.0, 2.0 * r_cap - d14);
  pen24 = max(0.0, 2.0 * r_cap - d24);

  // --- Collision penalty torques (repulsive, mapped via lever arms) ---
  tau_col[1] = 0.0;
  tau_col[2] = k_col * (pen13 * L[2] + pen14 * L[2]);
  tau_col[3] = k_col * (pen13 * L[3] + pen14 * L[3] + pen24 * L[3]);
  tau_col[4] = k_col * (pen14 * L[4] + pen24 * L[4]);

  // --- Disturbance torque via Jacobian-transpose of lateral Y-force ---
  tau_dist[1] = if dist_active then cos(q[1]) * reach * F_dist else 0.0;
  tau_dist[2] = if dist_active then sin(q[1]) * (-L[2] * sin(q[2]) - (L[3] + L[4]) * sin(q[2] + q[3])) * F_dist else 0.0;
  tau_dist[3] = if dist_active then sin(q[1]) * (-(L[3] + L[4]) * sin(q[2] + q[3])) * F_dist else 0.0;
  tau_dist[4] = 0.0;

  // --- Anti-windup flags ---
  aw1 = (tau_sat[1] >= tau_max - 0.001 and (q_ref[1] - q[1]) > 0.0) or
        (tau_sat[1] <= -tau_max + 0.001 and (q_ref[1] - q[1]) < 0.0) or
        (xi[1] >= xi_max[1] and (q_ref[1] - q[1]) > 0.0) or
        (xi[1] <= -xi_max[1] and (q_ref[1] - q[1]) < 0.0);
  aw2 = (tau_sat[2] >= tau_max - 0.001 and (q_ref[2] - q[2]) > 0.0) or
        (tau_sat[2] <= -tau_max + 0.001 and (q_ref[2] - q[2]) < 0.0) or
        (xi[2] >= xi_max[2] and (q_ref[2] - q[2]) > 0.0) or
        (xi[2] <= -xi_max[2] and (q_ref[2] - q[2]) < 0.0);
  aw3 = (tau_sat[3] >= tau_max - 0.001 and (q_ref[3] - q[3]) > 0.0) or
        (tau_sat[3] <= -tau_max + 0.001 and (q_ref[3] - q[3]) < 0.0) or
        (xi[3] >= xi_max[3] and (q_ref[3] - q[3]) > 0.0) or
        (xi[3] <= -xi_max[3] and (q_ref[3] - q[3]) < 0.0);
  aw4 = (tau_sat[4] >= tau_max - 0.001 and (q_ref[4] - q[4]) > 0.0) or
        (tau_sat[4] <= -tau_max + 0.001 and (q_ref[4] - q[4]) < 0.0) or
        (xi[4] >= xi_max[4] and (q_ref[4] - q[4]) > 0.0) or
        (xi[4] <= -xi_max[4] and (q_ref[4] - q[4]) < 0.0);

  // --- Saturated state-feedback control with integral disturbance rejection ---
  tau_cmd[1] = Kp[1] * (q_ref[1] - q[1]) - Kd[1] * w[1] + Ki[1] * xi[1] - tau_grav[1];
  tau_cmd[2] = Kp[2] * (q_ref[2] - q[2]) - Kd[2] * w[2] + Ki[2] * xi[2] - tau_grav[2];
  tau_cmd[3] = Kp[3] * (q_ref[3] - q[3]) - Kd[3] * w[3] + Ki[3] * xi[3] - tau_grav[3];
  tau_cmd[4] = Kp[4] * (q_ref[4] - q[4]) - Kd[4] * w[4] + Ki[4] * xi[4] - tau_grav[4];

  tau_sat[1] = max(-tau_max, min(tau_max, tau_cmd[1]));
  tau_sat[2] = max(-tau_max, min(tau_max, tau_cmd[2]));
  tau_sat[3] = max(-tau_max, min(tau_max, tau_cmd[3]));
  tau_sat[4] = max(-tau_max, min(tau_max, tau_cmd[4]));

  // --- Integrator dynamics with anti-windup ---
  der(xi[1]) = if aw1 then 0.0 else (q_ref[1] - q[1]);
  der(xi[2]) = if aw2 then 0.0 else (q_ref[2] - q[2]);
  der(xi[3]) = if aw3 then 0.0 else (q_ref[3] - q[3]);
  der(xi[4]) = if aw4 then 0.0 else (q_ref[4] - q[4]);

  // --- Plant dynamics ---
  der(q[1]) = w[1];
  der(q[2]) = w[2];
  der(q[3]) = w[3];
  der(q[4]) = w[4];

  Ieff[1] * der(w[1]) = tau_sat[1] + tau_grav[1] + tau_dist[1] + tau_col[1] - b[1] * w[1];
  Ieff[2] * der(w[2]) = tau_sat[2] + tau_grav[2] + tau_dist[2] + tau_col[2] - b[2] * w[2];
  Ieff[3] * der(w[3]) = tau_sat[3] + tau_grav[3] + tau_dist[3] + tau_col[3] - b[3] * w[3];
  Ieff[4] * der(w[4]) = tau_sat[4] + tau_grav[4] + tau_dist[4] + tau_col[4] - b[4] * w[4];

  // --- Wrist wrench sensor (force at distal link) ---
  wrench[1] = if dist_active then F_dist else 0.0;
  wrench[2] = 0.0;
  wrench[3] = m[4] * g_acc;

  // --- Tracking error ---
  tracking_error[1] = abs(q[1] - q_ref[1]);
  tracking_error[2] = abs(q[2] - q_ref[2]);
  tracking_error[3] = abs(q[3] - q_ref[3]);
  tracking_error[4] = abs(q[4] - q_ref[4]);

  primary_error = max(max(tracking_error[1], tracking_error[2]),
                      max(tracking_error[3], tracking_error[4]));

  // --- Running peak deviation (single when block) ---
  when primary_error > pre(peak_deviation) then
    peak_deviation = primary_error;
  end when;

  // --- Verification flags ---
  finite_states = (abs(q[1]) < 1.0e6) and (abs(q[2]) < 1.0e6) and
                  (abs(q[3]) < 1.0e6) and (abs(q[4]) < 1.0e6) and
                  (abs(w[1]) < 1.0e6) and (abs(w[2]) < 1.0e6) and
                  (abs(w[3]) < 1.0e6) and (abs(w[4]) < 1.0e6) and
                  (abs(xi[1]) < 1.0e6) and (abs(xi[2]) < 1.0e6) and
                  (abs(xi[3]) < 1.0e6) and (abs(xi[4]) < 1.0e6);

  no_collision = (pen13 < 1.0e-6) and (pen14 < 1.0e-6) and (pen24 < 1.0e-6);
  peak_ok = peak_deviation < 0.18;
  recovered = (time > 13.0) and (primary_error < 0.028);
  no_nan_inf = finite_states and
               (abs(tau_sat[1]) < 1.0e6) and (abs(tau_sat[2]) < 1.0e6) and
               (abs(tau_sat[3]) < 1.0e6) and (abs(tau_sat[4]) < 1.0e6) and
               (abs(tau_cmd[1]) < 1.0e6) and (abs(tau_cmd[2]) < 1.0e6) and
               (abs(tau_cmd[3]) < 1.0e6) and (abs(tau_cmd[4]) < 1.0e6) and
               (abs(wrench[1]) < 1.0e6) and (abs(wrench[2]) < 1.0e6) and (abs(wrench[3]) < 1.0e6);

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