model SCARARejectC
  "Fixed-base SCARA manipulator with saturated state-feedback control and integral disturbance rejection"

  // ---- Physical parameters ----
  parameter Real m_base = 28.0 "Fixed cylindrical base mass [kg]";
  parameter Real m1 = 6.0 "Link 1 moving mass [kg]";
  parameter Real m2 = 4.0 "Link 2 moving mass [kg]";
  parameter Real m3 = 2.0 "Prismatic carriage mass [kg]";
  parameter Real L1 = 0.48 "Link 1 length [m]";
  parameter Real L2 = 0.34 "Link 2 length [m]";
  parameter Real L3_travel = 0.30 "Prismatic travel [m]";
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";

  // ---- Self-collision barrier (nonadjacent: link1 <-> carriage/link3) ----
  parameter Real q2_lim = 2.5 "Joint 2 soft limit preventing fold-back [rad]";
  parameter Real k_coll = 800.0 "Collision barrier stiffness [N.m/rad]";
  parameter Real c_coll = 25.0 "Collision barrier damping [N.m.s/rad]";
  parameter Real q3_lo = 0.0 "Prismatic lower travel [m]";
  parameter Real q3_hi = 0.30 "Prismatic upper travel [m]";
  parameter Real k_coll_z = 20000.0 "Prismatic end-stop stiffness [N/m]";
  parameter Real c_coll_z = 200.0 "Prismatic end-stop damping [N.s/m]";
  parameter Real detM_eps = 1e-9 "Determinant safeguard floor [kg2.m4]";

  // ---- Actuator saturation limits ----
  parameter Real tau1_max = 87.4 "Revolute joint 1 torque limit [N.m]";
  parameter Real tau2_max = 87.4 "Revolute joint 2 torque limit [N.m]";
  parameter Real F3_max = 900.0 "Prismatic joint force limit [N]";

  // ---- Nonzero joint targets ----
  parameter Real q1_ref = 0.60 "Joint 1 target angle [rad]";
  parameter Real q2_ref = -0.50 "Joint 2 target angle [rad]";
  parameter Real q3_ref = 0.15 "Joint 3 target position [m]";

  // ---- Controller gains ----
  parameter Real Kp1 = 82.0 "Joint 1 proportional gain [N.m/rad]";
  parameter Real Kd1 = 37.0 "Joint 1 derivative gain [N.m.s/rad]";
  parameter Real Ki1 = 25.0 "Joint 1 integral gain [N.m/rad]";
  parameter Real Kp2 = 11.0 "Joint 2 proportional gain [N.m/rad]";
  parameter Real Kd2 = 5.0 "Joint 2 derivative gain [N.m.s/rad]";
  parameter Real Ki2 = 4.0 "Joint 2 integral gain [N.m/rad]";
  parameter Real Kp3 = 72.0 "Joint 3 proportional gain [N/m]";
  parameter Real Kd3 = 21.6 "Joint 3 derivative gain [N.s/m]";
  parameter Real Ki3 = 20.0 "Joint 3 integral gain [N/m]";

  // ---- Disturbance profile ----
  parameter Real F_dist = 16.2 "Lateral disturbance magnitude [N]";
  parameter Real t_d_on = 4.0 "Disturbance on time [s]";
  parameter Real t_d_off = 8.0 "Disturbance off time [s]";

  // ---- Sample rate ----
  parameter Real Ts = 1.0/125.0 "Output sample period [s]";

  // ---- Dynamic states ----
  Real q1(start=0.0, fixed=true) "Joint 1 angle [rad]";
  Real q1_dot(start=0.0, fixed=true) "Joint 1 angular velocity [rad/s]";
  Real q2(start=0.0, fixed=true) "Joint 2 angle [rad]";
  Real q2_dot(start=0.0, fixed=true) "Joint 2 angular velocity [rad/s]";
  Real q3(start=0.0, fixed=true) "Joint 3 vertical position [m]";
  Real q3_dot(start=0.0, fixed=true) "Joint 3 vertical velocity [m/s]";
  Real xi1(start=0.0, fixed=true) "Integral state joint 1";
  Real xi2(start=0.0, fixed=true) "Integral state joint 2";
  Real xi3(start=0.0, fixed=true) "Integral state joint 3";

  // ---- Commands (saturated) ----
  Real tau1_cmd "Joint 1 unsaturated command [N.m]";
  Real tau2_cmd "Joint 2 unsaturated command [N.m]";
  Real F3_cmd "Joint 3 unsaturated command [N]";
  Real tau1_sat "Joint 1 saturated actuator torque [N.m]";
  Real tau2_sat "Joint 2 saturated actuator torque [N.m]";
  Real F3_sat "Joint 3 saturated actuator force [N]";

  // ---- Sensor / instrumentation traces ----
  Real enc1 "Encoder reading joint 1 [rad]";
  Real enc2 "Encoder reading joint 2 [rad]";
  Real enc3 "Encoder reading joint 3 [m]";
  Real wrench_x "Wrist wrench sensor x-channel [N]";
  Real wrench_y "Wrist wrench sensor y-channel [N]";
  Real wrench_z "Wrist wrench sensor z-channel [N]";
  Real F_dist_active "Active lateral disturbance force [N]";

  // ---- Cartesian state (synchronized trace) ----
  Real x_wrist "Wrist x position [m]";
  Real y_wrist "Wrist y position [m]";
  Real z_wrist "Wrist z position [m]";

  // ---- Dynamics intermediates ----
  Real M11 "Inertia matrix element 11 [kg.m2]";
  Real M12 "Inertia matrix element 12 [kg.m2]";
  Real M22 "Inertia matrix element 22 [kg.m2]";
  Real h "Coriolis coupling coefficient [kg.m2]";
  Real detM "Inertia matrix determinant [kg2.m4]";
  Real detM_safe "Safeguarded determinant [kg2.m4]";
  Real R1 "Right-hand side joint 1 [N.m]";
  Real R2 "Right-hand side joint 2 [N.m]";
  Real tau1_dist "Disturbance torque joint 1 [N.m]";
  Real tau2_dist "Disturbance torque joint 2 [N.m]";
  Real tau2_coll "Collision torque joint 2 [N.m]";
  Real F3_endstop "Prismatic end-stop force [N]";
  Real tau3_grav_ff "Gravity feedforward joint 3 [N]";

  // ---- Tracking metrics ----
  Real e1 "Joint 1 tracking error [rad]";
  Real e2 "Joint 2 tracking error [rad]";
  Real e3 "Joint 3 tracking error [m]";
  Real e1_abs "Absolute joint 1 error [rad]";
  Real e2_abs "Absolute joint 2 error [rad]";
  Real e3_abs "Absolute joint 3 error [m]";
  Real peak_dev "Peak angular deviation [rad]";
  Real e1_late "Joint 1 error after 7.8 s [rad]";
  Real e2_late "Joint 2 error after 7.8 s [rad]";
  Real e3_late "Joint 3 error after 7.8 s [m]";
  Real primary_err_late "Primary tracking error after 7.8 s [rad or m]";

  // ---- Anti-windup flags ----
  Boolean sat1 "Joint 1 saturation flag";
  Boolean sat2 "Joint 2 saturation flag";
  Boolean sat3 "Joint 3 saturation flag";

equation
  // ============ Inertia matrix (2R planar, point masses at link ends) ============
  M11 = m1*L1*L1 + (m2 + m3)*(L1*L1 + 2.0*L1*L2*cos(q2) + L2*L2);
  M12 = (m2 + m3)*(L1*L2*cos(q2) + L2*L2);
  M22 = (m2 + m3)*L2*L2;
  h = -(m2 + m3)*L1*L2*sin(q2);

  // ============ Determinant with zero-error safeguard ============
  detM = M11*M22 - M12*M12;
  detM_safe = noEvent(if detM > detM_eps then detM else detM_eps);

  // ============ Disturbance (lateral force at wrist, x-direction) ============
  F_dist_active = noEvent(if time >= t_d_on and time <= t_d_off then F_dist else 0.0);

  // ============ Cartesian wrist state ============
  x_wrist = L1*cos(q1) + L2*cos(q1 + q2);
  y_wrist = L1*sin(q1) + L2*sin(q1 + q2);
  z_wrist = q3;

  // ============ Jacobian-transpose disturbance torques ============
  tau1_dist = F_dist_active*(-L1*sin(q1) - L2*sin(q1 + q2));
  tau2_dist = F_dist_active*(-L2*sin(q1 + q2));

  // ============ Wrist wrench sensor (reaction to applied load) ============
  wrench_x = -F_dist_active;
  wrench_y = 0.0;
  wrench_z = 0.0;

  // ============ Encoder traces ============
  enc1 = q1;
  enc2 = q2;
  enc3 = q3;

  // ============ Self-collision barrier (link1 <-> carriage via joint 2) ============
  tau2_coll = noEvent(if q2 > q2_lim then -k_coll*(q2 - q2_lim) - c_coll*q2_dot
                      else if q2 < -q2_lim then -k_coll*(q2 + q2_lim) - c_coll*q2_dot
                      else 0.0);

  // ============ Prismatic end-stop barrier (carriage travel) ============
  F3_endstop = noEvent(if q3 > q3_hi then -k_coll_z*(q3 - q3_hi) - c_coll_z*q3_dot
                       else if q3 < q3_lo then -k_coll_z*(q3 - q3_lo) - c_coll_z*q3_dot
                       else 0.0);

  // ============ Gravity feedforward for vertical prismatic joint ============
  tau3_grav_ff = m3*g;

  // ============ Tracking errors ============
  e1 = q1_ref - q1;
  e2 = q2_ref - q2;
  e3 = q3_ref - q3;
  e1_abs = abs(e1);
  e2_abs = abs(e2);
  e3_abs = abs(e3);
  peak_dev = noEvent(if e1_abs > e2_abs then e1_abs else e2_abs);

  // Late-window metrics (after 7.8 s)
  e1_late = noEvent(if time >= 7.8 then e1 else 0.0);
  e2_late = noEvent(if time >= 7.8 then e2 else 0.0);
  e3_late = noEvent(if time >= 7.8 then e3 else 0.0);
  primary_err_late = noEvent(if abs(e1_late) >= abs(e2_late) and abs(e1_late) >= abs(e3_late) then abs(e1_late)
                             else if abs(e2_late) >= abs(e3_late) then abs(e2_late)
                             else abs(e3_late));

  // ============ Saturated state-feedback + integral with anti-windup ============
  tau1_cmd = Kp1*e1 - Kd1*q1_dot + Ki1*xi1;
  tau2_cmd = Kp2*e2 - Kd2*q2_dot + Ki2*xi2;
  F3_cmd = Kp3*e3 - Kd3*q3_dot + Ki3*xi3 + tau3_grav_ff;

  // Saturation flags
  sat1 = tau1_cmd > tau1_max or tau1_cmd < -tau1_max;
  sat2 = tau2_cmd > tau2_max or tau2_cmd < -tau2_max;
  sat3 = F3_cmd > F3_max or F3_cmd < -F3_max;

  // Conditional (anti-windup) integration
  der(xi1) = if sat1 then 0.0 else e1;
  der(xi2) = if sat2 then 0.0 else e2;
  der(xi3) = if sat3 then 0.0 else e3;

  // Saturated actuator outputs
  tau1_sat = noEvent(if tau1_cmd > tau1_max then tau1_max
                     else if tau1_cmd < -tau1_max then -tau1_max
                     else tau1_cmd);
  tau2_sat = noEvent(if tau2_cmd > tau2_max then tau2_max
                     else if tau2_cmd < -tau2_max then -tau2_max
                     else tau2_cmd);
  F3_sat = noEvent(if F3_cmd > F3_max then F3_max
                   else if F3_cmd < -F3_max then -F3_max
                   else F3_cmd);

  // ============ Explicit equations of motion ============
  // Coriolis/centrifugal terms: C1 = h*q2d^2 + 2*h*q1d*q2d, C2 = -h*q1d^2
  R1 = tau1_sat + tau1_dist - (h*q2_dot*q2_dot + 2.0*h*q1_dot*q2_dot);
  R2 = tau2_sat + tau2_dist + tau2_coll + h*q1_dot*q1_dot;

  // Solved explicitly via 2x2 matrix inverse
  der(q1_dot) = (M22*R1 - M12*R2) / detM_safe;
  der(q2_dot) = (M11*R2 - M12*R1) / detM_safe;

  // Prismatic vertical dynamics (gravity along Z, feedforward cancels at steady state)
  der(q3_dot) = (F3_sat - m3*g + F3_endstop) / m3;

  // ============ Kinematic state integration ============
  der(q1) = q1_dot;
  der(q2) = q2_dot;
  der(q3) = q3_dot;

  annotation(
    experiment(StartTime=0, StopTime=12, Tolerance=1e-6, Interval=0.008),
    Documentation(info="SCARARejectC: Fixed-base articulated SCARA with two Z-revolute links (0.48 m, 0.34 m) and a Z-prismatic carriage (0.30 m travel). "
                       "28 kg base. Moving masses 6/4/2 kg. Saturated state-feedback with integral disturbance rejection (87.4 N.m revolute, 900 N prismatic). "
                       "16.2 N lateral wrist load injected during middle third (4-8 s). Gravity modeled on vertical prismatic axis; self-collision between "
                       "nonadjacent link1 and carriage modeled via soft barrier on joint 2. Traces at 125 Hz over 12 s."));
end SCARARejectC;