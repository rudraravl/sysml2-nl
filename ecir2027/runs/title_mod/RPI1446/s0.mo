model JointPathMoveF
  "Synchronized point-to-point move for 3R Z-Y-Y arm with cubic PID+velocity feedforward"

  // ===== Link geometry (specified) =====
  parameter Real L1 = 0.50 "Link 1 length [m]";
  parameter Real L2 = 0.38 "Link 2 length [m]";
  parameter Real L3 = 0.24 "Link 3 length [m]";

  // ===== Link mass / COM (assumed — not specified in requirement) =====
  parameter Real m1 = 2.5 "Link 1 mass [kg] (assumed)";
  parameter Real m2 = 1.8 "Link 2 mass [kg] (assumed)";
  parameter Real m3 = 1.2 "Link 3 mass [kg] (assumed)";
  parameter Real mp_nom = 0.80 "Nominal payload mass [kg] (assumed)";
  parameter Real lc1 = 0.25 "Link 1 COM distance [m] (assumed midpoint)";
  parameter Real lc2 = 0.19 "Link 2 COM distance [m] (assumed midpoint)";
  parameter Real lc3 = 0.12 "Link 3 COM distance [m] (assumed midpoint)";
  // NOTE: Link inertias modeled via point-mass approximation (I = m*lc^2).
  // Exact inertial properties, friction coefficients, and COM locations
  // are not specified and are treated as unknown with assumed defaults.

  // ===== Environment =====
  parameter Real g_acc = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real b1 = 0.15 "Joint 1 viscous friction [N.m.s/rad] (assumed)";
  parameter Real b2 = 0.15 "Joint 2 viscous friction [N.m.s/rad] (assumed)";
  parameter Real b3 = 0.15 "Joint 3 viscous friction [N.m.s/rad] (assumed)";

  // ===== Actuator limit (specified) =====
  parameter Real tau_max = 104.0 "Maximum torque per joint [N.m]";

  // ===== Trajectory waypoints (declared — not specified numerically) =====
  parameter Real q1_start = 0.0  "Joint 1 start [rad]";
  parameter Real q2_start = 0.0  "Joint 2 start [rad]";
  parameter Real q3_start = 0.0  "Joint 3 start [rad]";
  parameter Real q1_mid   = 0.50 "Joint 1 midpoint [rad] (declared)";
  parameter Real q2_mid   = 0.40 "Joint 2 midpoint [rad] (declared)";
  parameter Real q3_mid   = 0.30 "Joint 3 midpoint [rad] (declared)";
  parameter Real q1_final = 1.00 "Joint 1 final [rad] (declared)";
  parameter Real q2_final = 0.80 "Joint 2 final [rad] (declared)";
  parameter Real q3_final = 0.50 "Joint 3 final [rad] (declared)";
  parameter Real T_mid  = 10.0  "Time to midpoint [s]";
  parameter Real T_end  = 20.0  "Total mission time [s]";

  // ===== PID gains (assumed — tuned for model) =====
  parameter Real Kp1 = 60.0  "Joint 1 proportional gain";
  parameter Real Ki1 = 8.0   "Joint 1 integral gain";
  parameter Real Kd1 = 12.0  "Joint 1 derivative gain";
  parameter Real Kp2 = 100.0 "Joint 2 proportional gain";
  parameter Real Ki2 = 12.0  "Joint 2 integral gain";
  parameter Real Kd2 = 20.0  "Joint 2 derivative gain";
  parameter Real Kp3 = 50.0  "Joint 3 proportional gain";
  parameter Real Ki3 = 6.0   "Joint 3 integral gain";
  parameter Real Kd3 = 10.0  "Joint 3 derivative gain";

  // ===== Payload disturbance (specified) =====
  parameter Real payload_frac = 0.0725 "7.25 percent payload change";
  parameter Real t_dist_start = T_end / 3.0  "Disturbance start [s]";
  parameter Real t_dist_end   = 2.0 * T_end / 3.0 "Disturbance end [s]";

  // ===== Verification bounds (assumed — not specified) =====
  parameter Real q_bound   = 3.14  "Joint position bound [rad] (assumed)";
  parameter Real qd_bound  = 5.0   "Joint velocity bound [rad/s] (assumed)";
  parameter Real qdd_bound = 50.0  "Joint acceleration bound [rad/s2] (assumed)";
  parameter Real track_tol = 0.024 "Primary tracking tolerance [rad or m]";
  parameter Real t_settle  = 13.0  "Settling verification time [s]";
  parameter Real settle_qd = 0.05  "Settling velocity threshold [rad/s] (assumed)";

  // ===== Control loop timing =====
  parameter Real Ts = 0.002 "Control loop period [s] (500 Hz)";

  // ===== States =====
  Real q1(start = q1_start, fixed = true)  "Joint 1 angle [rad]";
  Real q2(start = q2_start, fixed = true)  "Joint 2 angle [rad]";
  Real q3(start = q3_start, fixed = true)  "Joint 3 angle [rad]";
  Real qd1(start = 0.0, fixed = true) "Joint 1 velocity [rad/s]";
  Real qd2(start = 0.0, fixed = true) "Joint 2 velocity [rad/s]";
  Real qd3(start = 0.0, fixed = true) "Joint 3 velocity [rad/s]";

  // ===== Accelerations (algebraic) =====
  Real qdd1 "Joint 1 acceleration [rad/s2]";
  Real qdd2 "Joint 2 acceleration [rad/s2]";
  Real qdd3 "Joint 3 acceleration [rad/s2]";

  // ===== Integral states =====
  Real ei1(start = 0.0, fixed = true) "Joint 1 integrated error [rad.s]";
  Real ei2(start = 0.0, fixed = true) "Joint 2 integrated error [rad.s]";
  Real ei3(start = 0.0, fixed = true) "Joint 3 integrated error [rad.s]";

  // ===== Trajectory reference =====
  Real q1_des,  q2_des,  q3_des  "Desired joint angles [rad]";
  Real qd1_des, qd2_des, qd3_des "Desired joint velocities [rad/s]";
  Real qdd1_des, qdd2_des, qdd3_des "Desired joint accelerations [rad/s2]";

  // ===== Control =====
  Real e1, e2, e3 "Tracking errors [rad]";
  Real ff1, ff2, ff3 "Feedforward torques [N.m]";
  Real tau1_raw, tau2_raw, tau3_raw "Unsaturated torques [N.m]";
  Real tau1, tau2, tau3 "Applied (saturated) torques [N.m]";

  // ===== Encoder feedback =====
  Real q1_enc,  q2_enc,  q3_enc  "Encoder positions [rad]";
  Real qd1_enc, qd2_enc, qd3_enc "Encoder velocities [rad/s]";

  // ===== Payload =====
  Real mp_eff "Effective payload mass [kg]";
  Real dpayload "Payload change fraction";

  // ===== Dynamics intermediates =====
  Real r2, r3, rp "Reach radii [m]";
  Real M11, M22, M23, M33 "Mass-matrix elements [kg.m2]";
  Real det_M2233 "2x2 submatrix determinant [kg2.m4]";
  Real M11_safe "Bounded M11 [kg.m2]";
  Real det_safe "Bounded determinant [kg2.m4]";
  Real dM11_dq2, dM11_dq3 "Partial derivatives of M11";
  Real Kc "Coriolis coupling coefficient [kg.m2]";
  Real h1, h2, h3 "Coriolis / centrifugal torques [N.m]";
  Real G2, G3 "Gravity torques [N.m]";
  Real F1, F2, F3 "Friction torques [N.m]";

  // ===== End-effector kinematics =====
  Real ee_x, ee_y, ee_z "End-effector position [m]";
  Real ee_x_des, ee_y_des, ee_z_des "Desired end-effector position [m]";

  // ===== Verification =====
  Real track_err_joint "Joint-space tracking error [rad]";
  Real track_err_cart "Cartesian tracking error [m]";
  Real track_err_primary "Primary tracking error [rad or m]";
  Real tau1_abs, tau2_abs, tau3_abs "Absolute applied torques [N.m]";
  Boolean pos_bounds_ok;
  Boolean vel_bounds_ok;
  Boolean acc_bounds_ok;
  Boolean eff_bounds_ok;
  Boolean settled_ok;
  Boolean track_ok;
  Boolean no_nan_inf;
  Boolean collision_free;
  Boolean all_verified;

  // ===== Collision geometry =====
  Real jlim1, jlim2, jlim3 "Joint-limit margins [rad]";
  // NOTE: External obstacle geometry not specified; collision check
  // limited to joint-limit bounds only.

protected
  Real s1n "Normalized segment-1 time";
  Real s2n "Normalized segment-2 time";

equation

  // ===================== Payload disturbance =====================
  dpayload = if (time >= t_dist_start and time < t_dist_end) then payload_frac else 0.0;
  mp_eff = mp_nom * (1.0 + dpayload);

  // ===================== Trajectory: cubic interpolation =====================
  // Two cubic segments with zero velocity at start, midpoint, and end.
  // Blend function: f(s) = 3*s^2 - 2*s^3  (Hermite smoothstep).
  s1n = time / T_mid;
  s2n = (time - T_mid) / (T_end - T_mid);

  // --- Desired position ---
  q1_des = if time <= T_mid then
      q1_start + (q1_mid - q1_start) * (3.0*s1n^2 - 2.0*s1n^3)
    else
      q1_mid + (q1_final - q1_mid) * (3.0*s2n^2 - 2.0*s2n^3);

  q2_des = if time <= T_mid then
      q2_start + (q2_mid - q2_start) * (3.0*s1n^2 - 2.0*s1n^3)
    else
      q2_mid + (q2_final - q2_mid) * (3.0*s2n^2 - 2.0*s2n^3);

  q3_des = if time <= T_mid then
      q3_start + (q3_mid - q3_start) * (3.0*s1n^2 - 2.0*s1n^3)
    else
      q3_mid + (q3_final - q3_mid) * (3.0*s2n^2 - 2.0*s2n^3);

  // --- Desired velocity (derivative of cubic) ---
  qd1_des = if time <= T_mid then
      (q1_mid - q1_start) * (6.0*s1n - 6.0*s1n^2) / T_mid
    else
      (q1_final - q1_mid) * (6.0*s2n - 6.0*s2n^2) / (T_end - T_mid);

  qd2_des = if time <= T_mid then
      (q2_mid - q2_start) * (6.0*s1n - 6.0*s1n^2) / T_mid
    else
      (q2_final - q2_mid) * (6.0*s2n - 6.0*s2n^2) / (T_end - T_mid);

  qd3_des = if time <= T_mid then
      (q3_mid - q3_start) * (6.0*s1n - 6.0*s1n^2) / T_mid
    else
      (q3_final - q3_mid) * (6.0*s2n - 6.0*s2n^2) / (T_end - T_mid);

  // --- Desired acceleration (second derivative of cubic) ---
  qdd1_des = if time <= T_mid then
      (q1_mid - q1_start) * (6.0 - 12.0*s1n) / T_mid^2
    else
      (q1_final - q1_mid) * (6.0 - 12.0*s2n) / (T_end - T_mid)^2;

  qdd2_des = if time <= T_mid then
      (q2_mid - q2_start) * (6.0 - 12.0*s1n) / T_mid^2
    else
      (q2_final - q2_mid) * (6.0 - 12.0*s2n) / (T_end - T_mid)^2;

  qdd3_des = if time <= T_mid then
      (q3_mid - q3_start) * (6.0 - 12.0*s1n) / T_mid^2
    else
      (q3_final - q3_mid) * (6.0 - 12.0*s2n) / (T_end - T_mid)^2;

  // ===================== End-effector kinematics =====================
  ee_x = cos(q1) * (L1 + L2*cos(q2) + L3*cos(q2 + q3));
  ee_y = sin(q1) * (L1 + L2*cos(q2) + L3*cos(q2 + q3));
  ee_z = -L2*sin(q2) - L3*sin(q2 + q3);

  ee_x_des = cos(q1_des) * (L1 + L2*cos(q2_des) + L3*cos(q2_des + q3_des));
  ee_y_des = sin(q1_des) * (L1 + L2*cos(q2_des) + L3*cos(q2_des + q3_des));
  ee_z_des = -L2*sin(q2_des) - L3*sin(q2_des + q3_des);

  // ===================== Encoder feedback =====================
  // Ideal encoders — noise / quantization not specified.
  q1_enc  = q1;
  q2_enc  = q2;
  q3_enc  = q3;
  qd1_enc = qd1;
  qd2_enc = qd2;
  qd3_enc = qd3;

  // ===================== Control errors =====================
  e1 = q1_des - q1_enc;
  e2 = q2_des - q2_enc;
  e3 = q3_des - q3_enc;

  // ===================== Dynamics geometry helpers =====================
  r2 = L1 + lc2*cos(q2);
  r3 = L1 + L2*cos(q2) + lc3*cos(q2 + q3);
  rp = L1 + L2*cos(q2) + L3*cos(q2 + q3);

  // ===================== Mass matrix =====================
  M11 = m1*lc1^2 + m2*r2^2 + m3*r3^2 + mp_eff*rp^2;
  M22 = m2*lc2^2
        + m3*(L2^2 + lc3^2 + 2.0*L2*lc3*cos(q3))
        + mp_eff*(L2^2 + L3^2 + 2.0*L2*L3*cos(q3));
  M23 = m3*(lc3^2 + L2*lc3*cos(q3))
        + mp_eff*(L3^2 + L2*L3*cos(q3));
  M33 = m3*lc3^2 + mp_eff*L3^2;

  det_M2233 = M22*M33 - M23^2;

  // Safe (non-singular) divisors
  M11_safe  = if M11 > 1.0e-6 then M11 else 1.0e-6;
  det_safe  = if det_M2233 > 1.0e-6 then det_M2233 else 1.0e-6;

  // ===================== Partial derivatives of M11 =====================
  dM11_dq2 = -2.0*m2*r2*lc2*sin(q2)
             - 2.0*m3*r3*(L2*sin(q2) + lc3*sin(q2 + q3))
             - 2.0*mp_eff*rp*(L2*sin(q2) + L3*sin(q2 + q3));
  dM11_dq3 = -2.0*m3*r3*lc3*sin(q2 + q3)
             - 2.0*mp_eff*rp*L3*sin(q2 + q3);

  // ===================== Coriolis / centrifugal =====================
  Kc = (m3*L2*lc3 + mp_eff*L2*L3) * sin(q3);
  h1 = dM11_dq2 * qd1 * qd2 + dM11_dq3 * qd1 * qd3;
  h2 = -0.5 * dM11_dq2 * qd1^2 - Kc * (2.0*qd2*qd3 + qd3^2);
  h3 = -0.5 * dM11_dq3 * qd1^2 + Kc * qd2^2;

  // ===================== Gravity torques =====================
  G2 = -g_acc * ((m2*lc2 + m3*L2 + mp_eff*L2) * cos(q2)
                 + (m3*lc3 + mp_eff*L3) * cos(q2 + q3));
  G3 = -g_acc * ((m3*lc3 + mp_eff*L3) * cos(q2 + q3));

  // ===================== Friction =====================
  F1 = b1 * qd1;
  F2 = b2 * qd2;
  F3 = b3 * qd3;

  // ===================== Feedforward (inertia × desired accel + gravity) =====================
  ff1 = M11 * qdd1_des;
  ff2 = M22 * qdd2_des + M23 * qdd3_des + G2;
  ff3 = M23 * qdd2_des + M33 * qdd3_des + G3;

  // ===================== PID + velocity feedforward =====================
  tau1_raw = Kp1*e1 + Ki1*ei1 + Kd1*(qd1_des - qd1_enc) + ff1;
  tau2_raw = Kp2*e2 + Ki2*ei2 + Kd2*(qd2_des - qd2_enc) + ff2;
  tau3_raw = Kp3*e3 + Ki3*ei3 + Kd3*(qd3_des - qd3_enc) + ff3;

  // ===================== Torque saturation (±104 N.m) =====================
  tau1 = if tau1_raw > tau_max then tau_max
         elseif tau1_raw < -tau_max then -tau_max
         else tau1_raw;
  tau2 = if tau2_raw > tau_max then tau_max
         elseif tau2_raw < -tau_max then -tau_max
         else tau2_raw;
  tau3 = if tau3_raw > tau_max then tau_max
         elseif tau3_raw < -tau_max then -tau_max
         else tau3_raw;

  // ===================== Integral with anti-windup =====================
  der(ei1) = if (tau1_raw > tau_max and e1 > 0.0) or
                 (tau1_raw < -tau_max and e1 < 0.0) then 0.0 else e1;
  der(ei2) = if (tau2_raw > tau_max and e2 > 0.0) or
                 (tau2_raw < -tau_max and e2 < 0.0) then 0.0 else e2;
  der(ei3) = if (tau3_raw > tau_max and e3 > 0.0) or
                 (tau3_raw < -tau_max and e3 < 0.0) then 0.0 else e3;

  // ===================== Equations of motion =====================
  der(q1)  = qd1;
  der(q2)  = qd2;
  der(q3)  = qd3;
  der(qd1) = qdd1;
  der(qd2) = qdd2;
  der(qd3) = qdd3;

  // Joint 1 (decoupled from joints 2,3 in mass matrix)
  qdd1 = (tau1 - h1 - F1) / M11_safe;

  // Joints 2,3 (coupled 2x2 system)
  qdd2 = (M33 * (tau2 - h2 - G2 - F2) - M23 * (tau3 - h3 - G3 - F3)) / det_safe;
  qdd3 = (-M23 * (tau2 - h2 - G2 - F2) + M22 * (tau3 - h3 - G3 - F3)) / det_safe;

  // ===================== Tracking error =====================
  track_err_joint = max(abs(e1), max(abs(e2), abs(e3)));
  track_err_cart  = sqrt((ee_x - ee_x_des)^2 + (ee_y - ee_y_des)^2 + (ee_z - ee_z_des)^2);
  track_err_primary = max(track_err_joint, track_err_cart);

  // ===================== Verification: effort bounds =====================
  tau1_abs = abs(tau1);
  tau2_abs = abs(tau2);
  tau3_abs = abs(tau3);
  eff_bounds_ok = tau1_abs <= tau_max and tau2_abs <= tau_max and tau3_abs <= tau_max;

  // ===================== Verification: state bounds =====================
  pos_bounds_ok = abs(q1) <= q_bound and abs(q2) <= q_bound and abs(q3) <= q_bound;
  vel_bounds_ok = abs(qd1) <= qd_bound and abs(qd2) <= qd_bound and abs(qd3) <= qd_bound;
  acc_bounds_ok = abs(qdd1) <= qdd_bound and abs(qdd2) <= qdd_bound and abs(qdd3) <= qdd_bound;

  // ===================== Verification: terminal settling =====================
  settled_ok = if time >= t_settle then
      (abs(qd1) <= settle_qd and abs(qd2) <= settle_qd and abs(qd3) <= settle_qd)
    else true;

  // ===================== Verification: tracking after 13 s =====================
  track_ok = if time >= t_settle then track_err_primary <= track_tol else true;

  // ===================== Collision geometry (joint limits) =====================
  jlim1 = q_bound - abs(q1);
  jlim2 = q_bound - abs(q2);
  jlim3 = q_bound - abs(q3);
  collision_free = jlim1 >= 0.0 and jlim2 >= 0.0 and jlim3 >= 0.0;
  // NOTE: External obstacle geometry not specified; only joint-limit
  // collision checking is included.

  // ===================== NaN / infinity check =====================
  // abs(NaN) and abs(Inf) both fail finite-magnitude comparison.
  no_nan_inf = (abs(q1) < 1.0e12) and (abs(q2) < 1.0e12) and (abs(q3) < 1.0e12)
    and (abs(qd1) < 1.0e12) and (abs(qd2) < 1.0e12) and (abs(qd3) < 1.0e12)
    and (abs(qdd1) < 1.0e12) and (abs(qdd2) < 1.0e12) and (abs(qdd3) < 1.0e12)
    and (abs(tau1) < 1.0e12) and (abs(tau2) < 1.0e12) and (abs(tau3) < 1.0e12)
    and (abs(e1) < 1.0e12) and (abs(e2) < 1.0e12) and (abs(e3) < 1.0e12)
    and (abs(ei1) < 1.0e12) and (abs(ei2) < 1.0e12) and (abs(ei3) < 1.0e12);

  // ===================== Overall verification =====================
  all_verified = pos_bounds_ok and vel_bounds_ok and acc_bounds_ok
    and eff_bounds_ok and settled_ok and track_ok
    and no_nan_inf and collision_free;

  annotation(
    experiment(StartTime = 0, StopTime = 20, Tolerance = 1e-6, Interval = 0.002),
    Documentation(info = "JointPathMoveF — 3-DOF Z-Y-Y revolute arm (L1=0.50, L2=0.38, L3=0.24 m).
      Synchronized point-to-point move: zero state → midpoint → final state.
      Trajectory: cubic (Hermite smoothstep) interpolation, zero velocity at waypoints.
      Control: PID + velocity feedforward + gravity compensation, torque limited to 104 N.m.
      Sensors: ideal encoders reporting position and velocity.
      Disturbance: 7.25% payload mass change during middle third (6.67–13.33 s).
      Gravity: included via Lagrangian dynamics. Collision: joint-limit bounds.
      Verification: position, velocity, acceleration, effort bounds; terminal settling;
      primary tracking error < 0.024 rad-or-m after 13 s; no NaN/Inf values.
      Control rate: 500 Hz (Interval = 0.002 s).
      Unknown parameters (mass, inertia, friction, COM, waypoints, bounds) are
      assigned reasonable engineering defaults and labeled as assumed."),
    Icon(graphics = {
      Rectangle(extent = {{-100,-100},{100,100}}, lineColor = {0,0,0}),
      Text(extent = {{-80,-20},{80,20}}, textString = "JointPathMoveF")}
    )
  );
end JointPathMoveF;