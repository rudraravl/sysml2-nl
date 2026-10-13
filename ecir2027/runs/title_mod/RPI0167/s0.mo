model SCARARejectE
  "SCARA reject: hold nonzero joint targets while rejecting finite-duration lateral load"

  // ===================== Physical parameters =====================
  parameter Real m_base = 28.0 "Fixed base mass [kg]";
  parameter Real m1 = 6.0     "Link 1 moving mass [kg]";
  parameter Real m2 = 4.0     "Link 2 moving mass [kg]";
  parameter Real m3 = 2.0     "Carriage moving mass [kg]";
  parameter Real L1 = 0.48    "Link 1 length [m]";
  parameter Real L2 = 0.34    "Link 2 length [m]";
  parameter Real dz_max = 0.30 "Prismatic Z travel [m]";
  parameter Real g = 9.81     "Gravitational acceleration [m/s2]";

  // Derived link properties (uniform cylindrical links about revolute axes)
  parameter Real r1 = 0.5 * L1 "Link 1 COM radius [m]";
  parameter Real r2 = 0.5 * L2 "Link 2 COM radius [m]";
  parameter Real I1 = m1 * r1 * r1 / 3.0 "Link 1 inertia about joint 1 [kg.m2]";
  parameter Real I2 = m2 * r2 * r2 / 3.0 "Link 2 inertia about joint 2 [kg.m2]";

  // Joint damping
  parameter Real b1 = 0.05 "Joint 1 viscous damping [N.m.s/rad]";
  parameter Real b2 = 0.05 "Joint 2 viscous damping [N.m.s/rad]";
  parameter Real b3 = 2.0  "Joint 3 viscous damping [N.s/m]";

  // ===================== Actuator saturation =====================
  parameter Real tau_max = 105.0 "Max revolute actuator torque [N.m]";
  parameter Real F_max   = 900.0 "Max prismatic actuator force [N]";

  // ===================== Controller (250 Hz) =====================
  parameter Real Ts = 0.004 "Control sample period [s]";

  parameter Real Kp1 = 200.0;
  parameter Real Kd1 = 15.0;
  parameter Real Ki1 = 100.0;
  parameter Real Kp2 = 150.0;
  parameter Real Kd2 = 12.0;
  parameter Real Ki2 = 80.0;
  parameter Real Kp3 = 400.0;
  parameter Real Kd3 = 50.0;
  parameter Real Ki3 = 200.0;

  parameter Real int_max1 = 50.0;
  parameter Real int_max2 = 40.0;
  parameter Real int_max3 = 100.0;

  // ===================== Joint targets (nonzero) =====================
  parameter Real q1_ref = 0.5  "Joint 1 target [rad]";
  parameter Real q2_ref = -0.3 "Joint 2 target [rad]";
  parameter Real q3_ref = 0.15 "Joint 3 target [m]";

  // ===================== Disturbance =====================
  parameter Real F_dist = 21.6  "Lateral disturbance force [N]";
  parameter Real t_dist_start = 5.3333333 "Disturbance start [s] (16/3)";
  parameter Real t_dist_end   = 10.6666667 "Disturbance end [s] (2*16/3)";

  // ===================== Self-collision =====================
  parameter Real q2_collision_limit = 3.04159 "Collision threshold [rad] (~pi-0.1)";
  parameter Real k_collision = 5000.0 "Collision stiffness [N.m/rad]";

  // ===================== Prismatic stops =====================
  parameter Real k_stop = 1.0e5 "Prismatic stop stiffness [N/m]";

  // ===================== Continuous states =====================
  Real q1(start = 0.5)   "Joint 1 angle [rad]";
  Real qd1(start = 0.0)  "Joint 1 velocity [rad/s]";
  Real q2(start = -0.3)  "Joint 2 angle [rad]";
  Real qd2(start = 0.0)  "Joint 2 velocity [rad/s]";
  Real q3(start = 0.15)  "Joint 3 position [m]";
  Real qd3(start = 0.0)  "Joint 3 velocity [m/s]";

  // Continuous tracking errors
  Real e1 "Joint 1 tracking error [rad]";
  Real e2 "Joint 2 tracking error [rad]";
  Real e3 "Joint 3 tracking error [m]";

  // ===================== Discrete controller states =====================
  discrete Real int_e1(start = 0.0) "Integral error joint 1";
  discrete Real int_e2(start = 0.0) "Integral error joint 2";
  discrete Real int_e3(start = 0.0) "Integral error joint 3";
  discrete Real tau1_h(start = 0.0) "Held (saturated) torque joint 1 [N.m]";
  discrete Real tau2_h(start = 0.0) "Held (saturated) torque joint 2 [N.m]";
  discrete Real F3_h(start = 0.0)   "Held (saturated) force joint 3 [N]";
  discrete Real tau1_raw(start = 0.0) "Unsaturated torque 1 [N.m]";
  discrete Real tau2_raw(start = 0.0) "Unsaturated torque 2 [N.m]";
  discrete Real F3_raw(start = 0.0)   "Unsaturated force 3 [N]";
  discrete Real sat1(start = 0.0) "Saturation flag joint 1";
  discrete Real sat2(start = 0.0) "Saturation flag joint 2";
  discrete Real sat3(start = 0.0) "Saturation flag joint 3";

  // Discrete monitoring
  discrete Real peak_dev12(start = 0.0) "Peak revolute deviation [rad]";
  discrete Real peak_dev3(start = 0.0)  "Peak prismatic deviation [m]";
  discrete Real max_err_post(start = 0.0) "Max tracking error after 10.4 s [rad-or-m]";

  // ===================== Disturbance and collision signals =====================
  Real dist_active   "Active disturbance force [N]";
  Real tau1_dist     "Disturbance torque on joint 1 [N.m]";
  Real tau2_dist     "Disturbance torque on joint 2 [N.m]";
  Real collision_tau "Self-collision repulsive torque [N.m]";
  Real q3_stop       "Prismatic stop force [N]";

  // ===================== Mass matrix and dynamics =====================
  Real M11, M12, M22, det_M;
  Real h_term, c1, c2;
  Real dd1, dd2;

  // ===================== Sensors =====================
  Real enc1   "Encoder joint 1 [rad]";
  Real enc2   "Encoder joint 2 [rad]";
  Real enc3   "Encoder joint 3 [m]";
  Real fx_wrist "Wrist force x [N]";
  Real fy_wrist "Wrist force y [N]";
  Real fz_wrist "Wrist force z [N]";
  Real tz_wrist "Wrist torque z [N.m]";

  // ===================== End-effector =====================
  Real x_ee "End-effector x [m]";
  Real y_ee "End-effector y [m]";
  Real z_ee "End-effector z [m]";

  // ===================== Acceptance =====================
  Boolean no_collision;
  Boolean finite_states;
  Boolean in_band_post;

equation
  // ===== Mass matrix (2-DOF planar revolute arm) =====
  M11 = I1 + I2 + m1 * r1 * r1 + m2 * (L1 * L1 + r2 * r2 + 2.0 * L1 * r2 * cos(q2));
  M12 = I2 + m2 * (r2 * r2 + L1 * r2 * cos(q2));
  M22 = I2 + m2 * r2 * r2;
  det_M = M11 * M22 - M12 * M12 + 1.0e-9;

  // ===== Coriolis / centrifugal terms =====
  h_term = -m2 * L1 * r2 * sin(q2);
  c1 = h_term * qd2 * qd2 + 2.0 * h_term * qd1 * qd2;
  c2 = -h_term * qd1 * qd1;

  // ===== Disturbance (lateral y-force at distal link) =====
  dist_active = if (time >= t_dist_start and time <= t_dist_end) then F_dist else 0.0;
  tau1_dist = dist_active * (L1 * cos(q1) + L2 * cos(q1 + q2));
  tau2_dist = dist_active * L2 * cos(q1 + q2);

  // ===== Self-collision (nonadjacent link 1 and link 3) =====
  collision_tau = if (abs(q2) > q2_collision_limit) then
    -k_collision * (abs(q2) - q2_collision_limit) * sign(q2) else 0.0;

  // ===== Prismatic joint stops =====
  q3_stop = if (q3 < 0.0) then k_stop * (0.0 - q3)
            elseif (q3 > dz_max) then k_stop * (dz_max - q3)
            else 0.0;

  // ===== Tracking errors =====
  e1 = q1_ref - q1;
  e2 = q2_ref - q2;
  e3 = q3_ref - q3;

  // ===== Equations of motion: revolute joints =====
  // M * qdd + C + B*qd = tau + tau_dist - collision
  dd1 = (M22 * (tau1_h - c1 - b1 * qd1 + tau1_dist)
       - M12 * (tau2_h - c2 - b2 * qd2 + tau2_dist - collision_tau)) / det_M;
  dd2 = (M11 * (tau2_h - c2 - b2 * qd2 + tau2_dist - collision_tau)
       - M12 * (tau1_h - c1 - b1 * qd1 + tau1_dist)) / det_M;

  der(q1) = qd1;
  der(qd1) = dd1;
  der(q2) = qd2;
  der(qd2) = dd2;

  // ===== Equation of motion: prismatic joint (vertical, gravity) =====
  der(q3) = qd3;
  der(qd3) = (F3_h - m3 * g - b3 * qd3 + q3_stop) / m3;

  // ===== Encoders =====
  enc1 = q1;
  enc2 = q2;
  enc3 = q3;

  // ===== End-effector position =====
  x_ee = L1 * cos(q1) + L2 * cos(q1 + q2);
  y_ee = L1 * sin(q1) + L2 * sin(q1 + q2);
  z_ee = q3;

  // ===== Wrist wrench sensor (at link2/link3 junction) =====
  fx_wrist = 0.0;
  fy_wrist = dist_active;
  fz_wrist = F3_h - m3 * g;
  tz_wrist = tau2_h;

  // ===== Acceptance criteria =====
  no_collision = abs(q2) < 3.14159265;
  finite_states = (abs(q1) < 1.0e6) and (abs(q2) < 1.0e6) and (abs(q3) < 1.0e6)
                  and (abs(tau1_h) < 1.0e6) and (abs(tau2_h) < 1.0e6) and (abs(F3_h) < 1.0e6);
  in_band_post = (time < 10.4) or (abs(e1) <= 0.032 and abs(e2) <= 0.032 and abs(e3) <= 0.032);

  // ===== Fail-closed assertions =====
  assert(no_collision, "Self-collision between nonadjacent links detected");
  assert(finite_states, "NaN or infinite value detected in physical, control, or estimator state");
  assert(peak_dev12 <= 0.18, "Peak joint deviation exceeded 0.18 rad");
  assert(in_band_post, "Primary tracking error after 10.4 s exceeds 0.032 rad-or-m");

  // ===== Sampled saturated state-feedback controller with integral rejection =====
  when sample(0, Ts) then
    // Integral update with anti-windup clamping
    int_e1 = if (abs(pre(int_e1)) < int_max1) then
               pre(int_e1) + Ts * (q1_ref - q1)
             elseif ((q1_ref - q1) * pre(int_e1) < 0.0) then
               pre(int_e1) + Ts * (q1_ref - q1)
             else
               pre(int_e1);

    int_e2 = if (abs(pre(int_e2)) < int_max2) then
               pre(int_e2) + Ts * (q2_ref - q2)
             elseif ((q2_ref - q2) * pre(int_e2) < 0.0) then
               pre(int_e2) + Ts * (q2_ref - q2)
             else
               pre(int_e2);

    int_e3 = if (abs(pre(int_e3)) < int_max3) then
               pre(int_e3) + Ts * (q3_ref - q3)
             elseif ((q3_ref - q3) * pre(int_e3) < 0.0) then
               pre(int_e3) + Ts * (q3_ref - q3)
             else
               pre(int_e3);

    // Unsaturated commands: state feedback + integral + gravity compensation
    tau1_raw = Kp1 * (q1_ref - q1) + Kd1 * (-qd1) + Ki1 * int_e1;
    tau2_raw = Kp2 * (q2_ref - q2) + Kd2 * (-qd2) + Ki2 * int_e2;
    F3_raw   = Kp3 * (q3_ref - q3) + Kd3 * (-qd3) + Ki3 * int_e3 + m3 * g;

    // Saturated actuator commands (zero-order hold between samples)
    tau1_h = max(-tau_max, min(tau_max, tau1_raw));
    tau2_h = max(-tau_max, min(tau_max, tau2_raw));
    F3_h   = max(-F_max, min(F_max, F3_raw));

    // Saturation flags
    sat1 = if abs(tau1_raw) > tau_max then 1.0 else 0.0;
    sat2 = if abs(tau2_raw) > tau_max then 1.0 else 0.0;
    sat3 = if abs(F3_raw) > F_max then 1.0 else 0.0;

    // Peak deviation tracking
    peak_dev12 = max(pre(peak_dev12), max(abs(q1_ref - q1), abs(q2_ref - q2)));
    peak_dev3  = max(pre(peak_dev3), abs(q3_ref - q3));

    // Post-recovery error tracking
    max_err_post = if (time >= 10.4) then
                     max(pre(max_err_post), max(abs(q1_ref - q1), max(abs(q2_ref - q2), abs(q3_ref - q3))))
                   else
                     0.0;
  end when;

end SCARARejectE;