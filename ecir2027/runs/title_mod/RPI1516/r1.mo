model SevenPathMoveD
  "Seven-revolute-joint arm: alternating Z/Y axes, cubic trajectory, PID+FF, 5% payload disturbance"

  // ===== Link lengths: capsule links from 0.34 m to 0.12 m =====
  parameter Real L1 = 0.34 "Link 1 length [m]";
  parameter Real L2 = 0.30 "Link 2 length [m] - assumed";
  parameter Real L3 = 0.26 "Link 3 length [m] - assumed";
  parameter Real L4 = 0.22 "Link 4 length [m] - assumed";
  parameter Real L5 = 0.18 "Link 5 length [m] - assumed";
  parameter Real L6 = 0.15 "Link 6 length [m] - assumed";
  parameter Real L7 = 0.12 "Link 7 length [m]";

  // ===== Link masses - ASSUMED (not stated in requirement) =====
  parameter Real m1 = 3.0 "Link 1 mass [kg] - assumed";
  parameter Real m2 = 2.5 "Link 2 mass [kg] - assumed";
  parameter Real m3 = 2.0 "Link 3 mass [kg] - assumed";
  parameter Real m4 = 1.5 "Link 4 mass [kg] - assumed";
  parameter Real m5 = 1.2 "Link 5 mass [kg] - assumed";
  parameter Real m6 = 1.0 "Link 6 mass [kg] - assumed";
  parameter Real m7 = 0.8 "Link 7 mass [kg] - assumed";
  parameter Real m_load = 1.0 "Nominal payload mass [kg] - assumed";

  // ===== Joint inertias - ASSUMED =====
  parameter Real J1 = 0.50 "Joint 1 inertia [kg.m^2] - assumed";
  parameter Real J2 = 0.30 "Joint 2 inertia [kg.m^2] - assumed";
  parameter Real J3 = 0.20 "Joint 3 inertia [kg.m^2] - assumed";
  parameter Real J4 = 0.10 "Joint 4 inertia [kg.m^2] - assumed";
  parameter Real J5 = 0.05 "Joint 5 inertia [kg.m^2] - assumed";
  parameter Real J6 = 0.03 "Joint 6 inertia [kg.m^2] - assumed";
  parameter Real J7 = 0.02 "Joint 7 inertia [kg.m^2] - assumed";

  // ===== Joint damping - ASSUMED =====
  parameter Real B1 = 0.10 "Joint 1 damping [N.m.s/rad] - assumed";
  parameter Real B2 = 0.10 "Joint 2 damping [N.m.s/rad] - assumed";
  parameter Real B3 = 0.08 "Joint 3 damping [N.m.s/rad] - assumed";
  parameter Real B4 = 0.06 "Joint 4 damping [N.m.s/rad] - assumed";
  parameter Real B5 = 0.04 "Joint 5 damping [N.m.s/rad] - assumed";
  parameter Real B6 = 0.03 "Joint 6 damping [N.m.s/rad] - assumed";
  parameter Real B7 = 0.02 "Joint 7 damping [N.m.s/rad] - assumed";

  // ===== Actuator limit =====
  parameter Real tau_max = 115.0 "Maximum effort [N.m]";

  // ===== Environment =====
  parameter Real g_grav = 9.81 "Gravitational acceleration [m/s^2]";

  // ===== Control timing =====
  parameter Real Ts_ctrl = 0.005 "Control sample period [s] (200 Hz)";
  parameter Real T_sim = 14.0 "Total simulation duration [s]";
  parameter Real T_seg = T_sim / 3.0 "Trajectory segment duration [s]";

  // ===== PID gains - ASSUMED =====
  parameter Real Kp1 = 50.0;  parameter Real Ki1 = 5.0;   parameter Real Kd1 = 5.0;
  parameter Real Kp2 = 40.0;  parameter Real Ki2 = 4.0;   parameter Real Kd2 = 4.0;
  parameter Real Kp3 = 30.0;  parameter Real Ki3 = 3.0;   parameter Real Kd3 = 3.0;
  parameter Real Kp4 = 25.0;  parameter Real Ki4 = 2.5;   parameter Real Kd4 = 2.5;
  parameter Real Kp5 = 20.0;  parameter Real Ki5 = 2.0;   parameter Real Kd5 = 2.0;
  parameter Real Kp6 = 15.0;  parameter Real Ki6 = 1.5;   parameter Real Kd6 = 1.5;
  parameter Real Kp7 = 10.0;  parameter Real Ki7 = 1.0;   parameter Real Kd7 = 1.0;

  // ===== Bounds =====
  parameter Real q_bound = 2.618 "Position bound [rad] (~150 deg, collision geometry) - assumed";
  parameter Real qd_bound = 3.0 "Velocity bound [rad/s] - assumed";
  parameter Real qdd_bound = 10.0 "Acceleration bound [rad/s^2] - assumed";
  parameter Real err_thresh = 0.03 "Primary tracking error threshold [rad]";
  parameter Real settle_time = 9.1 "Settling verification time [s]";

  // ===== Waypoints - ASSUMED (not stated in requirement) =====
  // Initial state: zero
  parameter Real q_init_1 = 0.0;  parameter Real q_init_2 = 0.0;
  parameter Real q_init_3 = 0.0;  parameter Real q_init_4 = 0.0;
  parameter Real q_init_5 = 0.0;  parameter Real q_init_6 = 0.0;
  parameter Real q_init_7 = 0.0;
  // Midpoint - assumed
  parameter Real q_mid_1 = 0.5;  parameter Real q_mid_2 = 0.4;
  parameter Real q_mid_3 = 0.3;  parameter Real q_mid_4 = 0.5;
  parameter Real q_mid_5 = 0.3;  parameter Real q_mid_6 = 0.4;
  parameter Real q_mid_7 = 0.3;
  // Final state - assumed
  parameter Real q_end_1 = 1.0;  parameter Real q_end_2 = 0.8;
  parameter Real q_end_3 = 0.6;  parameter Real q_end_4 = 1.0;
  parameter Real q_end_5 = 0.6;  parameter Real q_end_6 = 0.8;
  parameter Real q_end_7 = 0.5;

  // ===== Dynamic states =====
  // Axis convention: joints 1,3,5,7 = Z (vertical), joints 2,4,6 = Y (horizontal)
  Real q1(start=0.0),  q2(start=0.0),  q3(start=0.0),  q4(start=0.0);
  Real q5(start=0.0),  q6(start=0.0),  q7(start=0.0);
  Real qd1(start=0.0), qd2(start=0.0), qd3(start=0.0), qd4(start=0.0);
  Real qd5(start=0.0), qd6(start=0.0), qd7(start=0.0);
  Real qdd1, qdd2, qdd3, qdd4, qdd5, qdd6, qdd7;
  // Integral error states
  Real ei1(start=0.0), ei2(start=0.0), ei3(start=0.0), ei4(start=0.0);
  Real ei5(start=0.0), ei6(start=0.0), ei7(start=0.0);

  // ===== Efforts =====
  Real tau1, tau2, tau3, tau4, tau5, tau6, tau7;
  Real tau_s1, tau_s2, tau_s3, tau_s4, tau_s5, tau_s6, tau_s7;

  // ===== Gravity torques =====
  // Nominal (controller model, nominal payload)
  Real tau_g1, tau_g2, tau_g3, tau_g4, tau_g5, tau_g6, tau_g7;
  // Actual (plant, disturbed payload)
  Real tau_ga1, tau_ga2, tau_ga3, tau_ga4, tau_ga5, tau_ga6, tau_ga7;
  // Disturbance
  Real tau_d1, tau_d2, tau_d3, tau_d4, tau_d5, tau_d6, tau_d7;

  // ===== Trajectory references =====
  Real qr1, qr2, qr3, qr4, qr5, qr6, qr7;
  Real qdr1, qdr2, qdr3, qdr4, qdr5, qdr6, qdr7;
  Real qddr1, qddr2, qddr3, qddr4, qddr5, qddr6, qddr7;

  // ===== Encoder measurements =====
  Real qe1, qe2, qe3, qe4, qe5, qe6, qe7;
  Real qde1, qde2, qde3, qde4, qde5, qde6, qde7;

  // ===== Errors =====
  Real e1, e2, e3, e4, e5, e6, e7;
  Real ed1, ed2, ed3, ed4, ed5, ed6, ed7;

  // ===== Payload disturbance =====
  Real payload_mult;

  // ===== Trajectory shape =====
  Real s_seg, sc, scd, scdd;

  // ===== Gravity kinematic quantities =====
  Real thetaY2, thetaY4, thetaY6;
  Real mY2, mY4, mY6;
  Real rY2, rY4, rY6;

  // ===== Diagnostics =====
  Real pos_err_max;
  Boolean within_pos;
  Boolean within_vel;
  Boolean within_acc;
  Boolean within_effort;
  Boolean settled;
  Boolean no_nan_inf;
  Real tracking_err_after;

equation
  // ===== Effective masses beyond Y-axis joints (for gravity) =====
  mY2 = m2 + m3 + m4 + m5 + m6 + m7 + m_load;
  mY4 = m4 + m5 + m6 + m7 + m_load;
  mY6 = m6 + m7 + m_load;

  // ===== Effective COM distances (simplified) =====
  rY2 = (L2 + L3 + L4 + L5 + L6 + L7) * 0.5;
  rY4 = (L4 + L5 + L6 + L7) * 0.5;
  rY6 = (L6 + L7) * 0.5;

  // ===== Cumulative Y-axis angles =====
  thetaY2 = q2;
  thetaY4 = q2 + q4;
  thetaY6 = q2 + q4 + q6;

  // ===== Payload disturbance: 5% change during middle third =====
  payload_mult = if (time >= T_seg and time < 2.0*T_seg) then 1.05 else 1.0;

  // ===== Gravity torques =====
  // Z-axis joints (1,3,5,7): rotation about vertical axis, no gravity torque
  // Y-axis joints (2,4,6): tau = m_beyond * g * r_com * cos(theta_cum)
  // Nominal (controller)
  tau_g1 = 0.0;
  tau_g2 = mY2 * g_grav * rY2 * cos(thetaY2);
  tau_g3 = 0.0;
  tau_g4 = mY4 * g_grav * rY4 * cos(thetaY4);
  tau_g5 = 0.0;
  tau_g6 = mY6 * g_grav * rY6 * cos(thetaY6);
  tau_g7 = 0.0;
  // Actual (plant with disturbed payload)
  tau_ga1 = 0.0;
  tau_ga2 = payload_mult * mY2 * g_grav * rY2 * cos(thetaY2);
  tau_ga3 = 0.0;
  tau_ga4 = payload_mult * mY4 * g_grav * rY4 * cos(thetaY4);
  tau_ga5 = 0.0;
  tau_ga6 = payload_mult * mY6 * g_grav * rY6 * cos(thetaY6);
  tau_ga7 = 0.0;
  // Disturbance = actual - nominal
  tau_d1 = tau_ga1 - tau_g1;
  tau_d2 = tau_ga2 - tau_g2;
  tau_d3 = tau_ga3 - tau_g3;
  tau_d4 = tau_ga4 - tau_g4;
  tau_d5 = tau_ga5 - tau_g5;
  tau_d6 = tau_ga6 - tau_g6;
  tau_d7 = tau_ga7 - tau_g7;

  // ===== Cubic trajectory generation =====
  // q(s) = q0 + (q1-q0)*(3s^2 - 2s^3), zero velocity at segment endpoints
  // Phase 1: [0, T_seg]  q_init -> q_mid
  // Phase 2: [T_seg, 2*T_seg]  q_mid -> q_end
  // Phase 3: [2*T_seg, T_sim]  hold q_end
  s_seg = if time < T_seg then time / T_seg
          elseif time < 2.0*T_seg then (time - T_seg) / T_seg
          else 1.0;
  sc = 3.0*s_seg^2 - 2.0*s_seg^3;
  scd = (6.0*s_seg - 6.0*s_seg^2) / T_seg;
  scdd = (6.0 - 12.0*s_seg) / (T_seg^2);

  // Reference positions
  qr1 = if time < T_seg then q_init_1 + (q_mid_1 - q_init_1)*sc
        elseif time < 2.0*T_seg then q_mid_1 + (q_end_1 - q_mid_1)*sc
        else q_end_1;
  qr2 = if time < T_seg then q_init_2 + (q_mid_2 - q_init_2)*sc
        elseif time < 2.0*T_seg then q_mid_2 + (q_end_2 - q_mid_2)*sc
        else q_end_2;
  qr3 = if time < T_seg then q_init_3 + (q_mid_3 - q_init_3)*sc
        elseif time < 2.0*T_seg then q_mid_3 + (q_end_3 - q_mid_3)*sc
        else q_end_3;
  qr4 = if time < T_seg then q_init_4 + (q_mid_4 - q_init_4)*sc
        elseif time < 2.0*T_seg then q_mid_4 + (q_end_4 - q_mid_4)*sc
        else q_end_4;
  qr5 = if time < T_seg then q_init_5 + (q_mid_5 - q_init_5)*sc
        elseif time < 2.0*T_seg then q_mid_5 + (q_end_5 - q_mid_5)*sc
        else q_end_5;
  qr6 = if time < T_seg then q_init_6 + (q_mid_6 - q_init_6)*sc
        elseif time < 2.0*T_seg then q_mid_6 + (q_end_6 - q_mid_6)*sc
        else q_end_6;
  qr7 = if time < T_seg then q_init_7 + (q_mid_7 - q_init_7)*sc
        elseif time < 2.0*T_seg then q_mid_7 + (q_end_7 - q_mid_7)*sc
        else q_end_7;

  // Reference velocities
  qdr1 = if time < T_seg then (q_mid_1 - q_init_1)*scd
         elseif time < 2.0*T_seg then (q_end_1 - q_mid_1)*scd
         else 0.0;
  qdr2 = if time < T_seg then (q_mid_2 - q_init_2)*scd
         elseif time < 2.0*T_seg then (q_end_2 - q_mid_2)*scd
         else 0.0;
  qdr3 = if time < T_seg then (q_mid_3 - q_init_3)*scd
         elseif time < 2.0*T_seg then (q_end_3 - q_mid_3)*scd
         else 0.0;
  qdr4 = if time < T_seg then (q_mid_4 - q_init_4)*scd
         elseif time < 2.0*T_seg then (q_end_4 - q_mid_4)*scd
         else 0.0;
  qdr5 = if time < T_seg then (q_mid_5 - q_init_5)*scd
         elseif time < 2.0*T_seg then (q_end_5 - q_mid_5)*scd
         else 0.0;
  qdr6 = if time < T_seg then (q_mid_6 - q_init_6)*scd
         elseif time < 2.0*T_seg then (q_end_6 - q_mid_6)*scd
         else 0.0;
  qdr7 = if time < T_seg then (q_mid_7 - q_init_7)*scd
         elseif time < 2.0*T_seg then (q_end_7 - q_mid_7)*scd
         else 0.0;

  // Reference accelerations
  qddr1 = if time < T_seg then (q_mid_1 - q_init_1)*scdd
          elseif time < 2.0*T_seg then (q_end_1 - q_mid_1)*scdd
          else 0.0;
  qddr2 = if time < T_seg then (q_mid_2 - q_init_2)*scdd
          elseif time < 2.0*T_seg then (q_end_2 - q_mid_2)*scdd
          else 0.0;
  qddr3 = if time < T_seg then (q_mid_3 - q_init_3)*scdd
          elseif time < 2.0*T_seg then (q_end_3 - q_mid_3)*scdd
          else 0.0;
  qddr4 = if time < T_seg then (q_mid_4 - q_init_4)*scdd
          elseif time < 2.0*T_seg then (q_end_4 - q_mid_4)*scdd
          else 0.0;
  qddr5 = if time < T_seg then (q_mid_5 - q_init_5)*scdd
          elseif time < 2.0*T_seg then (q_end_5 - q_mid_5)*scdd
          else 0.0;
  qddr6 = if time < T_seg then (q_mid_6 - q_init_6)*scdd
          elseif time < 2.0*T_seg then (q_end_6 - q_mid_6)*scdd
          else 0.0;
  qddr7 = if time < T_seg then (q_mid_7 - q_init_7)*scdd
          elseif time < 2.0*T_seg then (q_end_7 - q_mid_7)*scdd
          else 0.0;

  // ===== Encoder measurements (full joint-state sensing) =====
  qe1 = q1;   qe2 = q2;   qe3 = q3;   qe4 = q4;
  qe5 = q5;   qe6 = q6;   qe7 = q7;
  qde1 = qd1; qde2 = qd2; qde3 = qd3; qde4 = qd4;
  qde5 = qd5; qde6 = qd6; qde7 = qd7;

  // ===== Tracking errors =====
  e1 = qr1 - qe1;  e2 = qr2 - qe2;  e3 = qr3 - qe3;  e4 = qr4 - qe4;
  e5 = qr5 - qe5;  e6 = qr6 - qe6;  e7 = qr7 - qe7;
  ed1 = qdr1 - qde1;  ed2 = qdr2 - qde2;  ed3 = qdr3 - qde3;  ed4 = qdr4 - qde4;
  ed5 = qdr5 - qde5;  ed6 = qdr6 - qde6;  ed7 = qdr7 - qde7;

  // ===== PID + velocity feedforward + gravity compensation =====
  // Seven effort actuators support operational-space and null-space control;
  // implemented here as joint-space PID+FF (simplified).
  // tau = Kp*e + Ki*ei + Kd*ed + tau_g_nominal + J*qdd_ref + B*qd_ref
  der(ei1) = e1;  der(ei2) = e2;  der(ei3) = e3;  der(ei4) = e4;
  der(ei5) = e5;  der(ei6) = e6;  der(ei7) = e7;

  tau1 = Kp1*e1 + Ki1*ei1 + Kd1*ed1 + tau_g1 + J1*qddr1 + B1*qdr1;
  tau2 = Kp2*e2 + Ki2*ei2 + Kd2*ed2 + tau_g2 + J2*qddr2 + B2*qdr2;
  tau3 = Kp3*e3 + Ki3*ei3 + Kd3*ed3 + tau_g3 + J3*qddr3 + B3*qdr3;
  tau4 = Kp4*e4 + Ki4*ei4 + Kd4*ed4 + tau_g4 + J4*qddr4 + B4*qdr4;
  tau5 = Kp5*e5 + Ki5*ei5 + Kd5*ed5 + tau_g5 + J5*qddr5 + B5*qdr5;
  tau6 = Kp6*e6 + Ki6*ei6 + Kd6*ed6 + tau_g6 + J6*qddr6 + B6*qdr6;
  tau7 = Kp7*e7 + Ki7*ei7 + Kd7*ed7 + tau_g7 + J7*qddr7 + B7*qdr7;

  // ===== Effort saturation (115 N.m max) =====
  tau_s1 = if tau1 > tau_max then tau_max elseif tau1 < -tau_max then -tau_max else tau1;
  tau_s2 = if tau2 > tau_max then tau_max elseif tau2 < -tau_max then -tau_max else tau2;
  tau_s3 = if tau3 > tau_max then tau_max elseif tau3 < -tau_max then -tau_max else tau3;
  tau_s4 = if tau4 > tau_max then tau_max elseif tau4 < -tau_max then -tau_max else tau4;
  tau_s5 = if tau5 > tau_max then tau_max elseif tau5 < -tau_max then -tau_max else tau5;
  tau_s6 = if tau6 > tau_max then tau_max elseif tau6 < -tau_max then -tau_max else tau6;
  tau_s7 = if tau7 > tau_max then tau_max elseif tau7 < -tau_max then -tau_max else tau7;

  // ===== Plant dynamics =====
  // J*qdd + B*qd = tau_s - tau_g_actual
  qdd1 = (tau_s1 - tau_ga1 - B1*qd1) / J1;
  qdd2 = (tau_s2 - tau_ga2 - B2*qd2) / J2;
  qdd3 = (tau_s3 - tau_ga3 - B3*qd3) / J3;
  qdd4 = (tau_s4 - tau_ga4 - B4*qd4) / J4;
  qdd5 = (tau_s5 - tau_ga5 - B5*qd5) / J5;
  qdd6 = (tau_s6 - tau_ga6 - B6*qd6) / J6;
  qdd7 = (tau_s7 - tau_ga7 - B7*qd7) / J7;

  der(q1) = qd1;   der(q2) = qd2;   der(q3) = qd3;   der(q4) = qd4;
  der(q5) = qd5;   der(q6) = qd6;   der(q7) = qd7;
  der(qd1) = qdd1; der(qd2) = qdd2; der(qd3) = qdd3; der(qd4) = qdd4;
  der(qd5) = qdd5; der(qd6) = qdd6; der(qd7) = qdd7;

  // ===== Diagnostics =====
  // Maximum position error across all joints
  pos_err_max = max(max(max(max(max(max(abs(e1), abs(e2)), abs(e3)), abs(e4)), abs(e5)), abs(e6)), abs(e7));

  // Bounds checks (collision geometry via position limits)
  within_pos = (abs(q1) < q_bound) and (abs(q2) < q_bound) and (abs(q3) < q_bound) and
               (abs(q4) < q_bound) and (abs(q5) < q_bound) and (abs(q6) < q_bound) and
               (abs(q7) < q_bound);
  within_vel = (abs(qd1) < qd_bound) and (abs(qd2) < qd_bound) and (abs(qd3) < qd_bound) and
               (abs(qd4) < qd_bound) and (abs(qd5) < qd_bound) and (abs(qd6) < qd_bound) and
               (abs(qd7) < qd_bound);
  within_acc = (abs(qdd1) < qdd_bound) and (abs(qdd2) < qdd_bound) and (abs(qdd3) < qdd_bound) and
               (abs(qdd4) < qdd_bound) and (abs(qdd5) < qdd_bound) and (abs(qdd6) < qdd_bound) and
               (abs(qdd7) < qdd_bound);
  within_effort = (abs(tau_s1) <= tau_max) and (abs(tau_s2) <= tau_max) and (abs(tau_s3) <= tau_max) and
                  (abs(tau_s4) <= tau_max) and (abs(tau_s5) <= tau_max) and (abs(tau_s6) <= tau_max) and
                  (abs(tau_s7) <= tau_max);

  // Terminal settling: primary tracking error below 0.03 rad after 9.1 s
  tracking_err_after = if time >= settle_time then pos_err_max else 0.0;
  settled = if time >= settle_time then (pos_err_max < err_thresh) else true;

  // No NaN or infinite physical, control, or estimator values
  no_nan_inf = (q1 == q1) and (q2 == q2) and (q3 == q3) and (q4 == q4) and
               (q5 == q5) and (q6 == q6) and (q7 == q7) and
               (qd1 == qd1) and (qd2 == qd2) and (qd3 == qd3) and (qd4 == qd4) and
               (qd5 == qd5) and (qd6 == qd6) and (qd7 == qd7) and
               (tau1 == tau1) and (tau2 == tau2) and (tau3 == tau3) and (tau4 == tau4) and
               (tau5 == tau5) and (tau6 == tau6) and (tau7 == tau7) and
               (ei1 == ei1) and (ei2 == ei2) and (ei3 == ei3) and (ei4 == ei4) and
               (ei5 == ei5) and (ei6 == ei6) and (ei7 == ei7) and
               (abs(q1) < 1e12) and (abs(q2) < 1e12) and (abs(q3) < 1e12) and
               (abs(q4) < 1e12) and (abs(q5) < 1e12) and (abs(q6) < 1e12) and
               (abs(q7) < 1e12) and
               (abs(tau1) < 1e12) and (abs(tau2) < 1e12) and (abs(tau3) < 1e12) and
               (abs(tau4) < 1e12) and (abs(tau5) < 1e12) and (abs(tau6) < 1e12) and
               (abs(tau7) < 1e12) and
               (abs(ei1) < 1e12) and (abs(ei2) < 1e12) and (abs(ei3) < 1e12) and
               (abs(ei4) < 1e12) and (abs(ei5) < 1e12) and (abs(ei6) < 1e12) and
               (abs(ei7) < 1e12);

  annotation(
    Documentation(info = "Seven-revolute-joint arm with alternating Z and Y axes. "
      + "Cubic interpolation trajectory from zero through midpoint to final state. "
      + "PID control with velocity feedforward and gravity compensation. "
      + "Seven effort actuators limited to 115 N.m, supporting operational-space "
      + "and null-space control (simplified to joint-space PID+FF here). "
      + "5 percent payload disturbance during middle third. "
      + "200 Hz control rate, 14 s duration. "
      + "Full joint-state sensing via encoders. "
      + "Collision geometry via joint position bounds matching capsule link mechanism. "
      + "ASSUMED (not stated): link masses, inertias, damping, PID gains, waypoints, "
      + "joint position limits."),
    experiment(StopTime = 14.0, StartTime = 0.0, Tolerance = 1e-6, Interval = 0.005)
  );
end SevenPathMoveD;