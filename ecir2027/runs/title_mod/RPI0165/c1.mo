model SCARARejectC
  "Fixed-base SCARA manipulator with saturated state-feedback control and integral disturbance rejection"

  // ---- Physical parameters ----
  parameter Real m_base = 28.0 "Fixed cylindrical base mass [kg]";
  parameter Real m1 = 6.0      "Link 1 moving mass [kg]";
  parameter Real m2 = 4.0      "Link 2 moving mass [kg]";
  parameter Real m3 = 2.0      "Prismatic carriage mass [kg]";
  parameter Real L1 = 0.48     "Link 1 length [m]";
  parameter Real L2 = 0.34     "Link 2 length [m]";
  parameter Real L3_travel = 0.30 "Prismatic travel [m]";
  parameter Real g = 9.81      "Gravitational acceleration [m/s2]";

  // ---- Self-collision barrier (nonadjacent: link1 <-> carriage/link3) ----
  parameter Real q2_lim = 2.5   "Joint 2 soft limit preventing fold-back [rad]";
  parameter Real k_coll = 800.0 "Collision barrier stiffness [N.m/rad]";
  parameter Real c_coll = 25.0  "Collision barrier damping [N.m.s/rad]";
  parameter Real q3_lo = 0.0    "Prismatic lower travel [m]";
  parameter Real q3_hi = 0.30   "Prismatic upper travel [m]";
  parameter Real k_coll_z = 20000.0 "Prismatic end-stop stiffness [N/m]";
  parameter Real c_coll_z = 200.0  "Prismatic end-stop damping [N.s/m]";

  // ---- Actuator saturation limits ----
  parameter Real tau1_max = 87.4 "Revolute joint 1 torque limit [N.m]";
  parameter Real tau2_max = 87.4 "Revolute joint 2 torque limit [N.m]";
  parameter Real F3_max   = 900.0 "Prismatic joint force limit [N]";

  // ---- Nonzero joint targets ----
  parameter Real q1_ref = 0.60  "Joint 1 target angle [rad]";
  parameter Real q2_ref = -0.50 "Joint 2 target angle [rad]";
  parameter Real q3_ref = 0.15  "Joint 3 target position [m]";

  // ---- Controller gains ----
  parameter Real Kp1 = 82.0  "Joint 1 proportional gain [N.m/rad]";
  parameter Real Kd1 = 37.0  "Joint 1 derivative gain [N.m.s/rad]";
  parameter Real Ki1 = 25.0  "Joint 1 integral gain [N.m/rad]";
  parameter Real Kp2 = 11.0  "Joint 2 proportional gain [N.m/rad]";
  parameter Real Kd2 = 5.0   "Joint 2 derivative gain [N.m.s/rad]";
  parameter Real Ki2 = 4.0   "Joint 2 integral gain [N.m/rad]";
  parameter Real Kp3 = 72.0  "Joint 3 proportional gain [N/m]";
  parameter Real Kd3 = 21.6  "Joint 3 derivative gain [N.s/m]";
  parameter Real Ki3 = 20.0  "Joint 3 integral gain [N/m]";

  // ---- Disturbance profile ----
  parameter Real F_dist = 16.2  "Lateral disturbance magnitude [N]";
  parameter Real t_d_on  = 4.0  "Disturbance on time [s]";
  parameter Real t_d_off = 8.0  "Disturbance off time [s]";

  // ---- Sample rate ----
  parameter Real Ts = 1.0/125.0 "Output sample period [s]";

  // ---- Dynamic states ----
  Real q1(start=0.0)       "Joint 1 angle [rad]";
  Real q1_dot(start=0.0)   "Joint 1 angular velocity [rad/s]";
  Real q2(start=0.0)       "Joint 2 angle [rad]";
  Real q2_dot(start=0.0)   "Joint 2 angular velocity [rad/s]";
  Real q3(start=0.0)       "Joint 3 vertical position [m]";
  Real q3_dot(start=0.0)   "Joint 3 vertical velocity [m/s]";
  Real xi1(start=0.0)      "Integral state joint 1";
  Real xi2(start=0.0)      "Integral state joint 2";
  Real xi3(start=0.0)      "Integral state joint 3";

  // ---- Commands (saturated) ----
  Real tau1_cmd  "Joint 1 unsaturated command [N.m]";
  Real tau2_cmd  "Joint 2 unsaturated command [N.m]";
  Real F3_cmd    "Joint 3 unsaturated command [N]";
  Real tau1_sat  "Joint 1 saturated actuator torque [N.m]";
  Real tau2_sat  "Joint 2 saturated actuator torque [N.m]";
  Real F3_sat    "Joint 3 saturated actuator force [N]";

  // ---- Sensor / instrumentation traces ----
  Real enc1      "Encoder reading joint 1 [rad]";
  Real enc2      "Encoder reading joint 2 [rad]";
  Real enc3      "Encoder reading joint 3 [m]";
  Real wrench_x  "Wrist wrench sensor x-channel [N]";
  Real wrench_y  "Wrist wrench sensor y-channel [N]";
  Real wrench_z  "Wrist wrench sensor z-channel [N]";
  Real F_dist_active "Active lateral disturbance force [N]";

  // ---- Cartesian state (synchronized trace) ----
  Real x_wrist "Wrist x position [m]";
  Real y_wrist "Wrist y position [m]";
  Real z_wrist "Wrist z position [m]";

  // ---- Dynamics intermediates ----
  Real M11, M12, M22, h;
  Real tau1_dist, tau2_dist;
  Real tau1_coll, tau2_coll;
  Real F3_endstop;
  Real tau3_grav_ff;

  // ---- Tracking metrics ----
  Real e1 "Joint 1 tracking error [rad]";
  Real e2 "Joint 2 tracking error [rad]";
  Real e3 "Joint 3 tracking error [m]";
  Real e1_abs, e2_abs, e3_abs;
  Real peak_dev "Peak angular deviation [rad]";
  Real e1_late  "Joint 1 error after 7.8 s [rad]";
  Real e2_late  "Joint 2 error after 7.8 s [rad]";
  Real e3_late  "Joint 3 error after 7.8 s [m]";
  Real primary_err_late "Primary tracking error after 7.8 s [rad or m]";

  // ---- Anti-windup flags ----
  Boolean sat1, sat2, sat3;

equation
  // ============ Inertia matrix (2R planar, point masses at link ends) ============
  M11 = m1*L1^2 + (m2+m3)*(L1^2 + 2.0*L1*L2*cos(q2) + L2^2);
  M12 = (m2+m3)*(L1*L2*cos(q2) + L2^2);
  M22 = (m2+m3)*L2^2;
  h   = -(m2+m3)*L1*L2*sin(q2);

  // ============ Disturbance (lateral force at wrist, x-direction) ============
  F_dist_active = if (time >= t_d_on and time <= t_d_off) then F_dist else 0.0;

  // ============ Cartesian wrist state ============
  x_wrist = L1*cos(q1) + L2*cos(q1+q2);
  y_wrist = L1*sin(q1) + L2*sin(q1+q2);
  z_wrist = q3;

  // ============ Jacobian-transpose disturbance torques ============
  tau1_dist = F_dist_active*(-L1*sin(q1) - L2*sin(q1+q2));
  tau2_dist = F_dist_active*(-L2*sin(q1+q2));

  // ============ Wrist wrench sensor (reaction to applied load) ============
  wrench_x = -F_dist_active;
  wrench_y = 0.0;
  wrench_z = 0.0;

  // ============ Encoder traces ============
  enc1 = q1;
  enc2 = q2;
  enc3 = q3;

  // ============ Self-collision barrier (link1 <-> carriage) ============
  tau1_coll = if (q2 > q2_lim)  then -k_coll*(q2 - q2_lim) - c_coll*q2_dot
              else if (q2 < -q2_lim) then -k_coll*(q2 + q2_lim) - c_coll*q2_dot
              else 0.0;
  tau2_coll = if (q2 > q2_lim)  then -k_coll*(q2 - q2_lim) - c_coll*q2_dot
              else if (q2 < -q2_lim) then -k_coll*(q2 + q2_lim) - c_coll*q2_dot
              else 0.0;

  // ============ Prismatic end-stop barrier (carriage travel) ============
  F3_endstop = if (q3 > q3_hi) then -k_coll_z*(q3 - q3_hi) - c_coll_z*q3_dot
               else if (q3 < q3_lo) then -k_coll_z*(q3 - q3_lo) - c_coll_z*q3_dot
               else 0.0;

  // ============ Gravity feedforward for vertical prismatic joint ============
  tau3_grav_ff = m3*g;

  // ============ Tracking errors ============
  e1 = q1_ref - q1;
  e2 = q2_ref - q2;
  e3 = q3_ref - q3;
  e1_abs = abs(e1);
  e2_abs = abs(e2);
  e3_abs = abs(e3);
  peak_dev = max(e1_abs, e2_abs);

  // Late-window metrics (after 7.8 s)
  e1_late = if (time >= 7.8) then e1 else 0.0;
  e2_late = if (time >= 7.8) then e2 else 0.0;
  e3_late = if (time >= 7.8) then e3 else 0.0;
  primary_err_late = max(max(abs(e1_late), abs(e2_late)), abs(e3_late));

  // ============ Saturated state-feedback + integral with anti-windup ============
  tau1_cmd = Kp1*e1 - Kd1*q1_dot + Ki1*xi1;
  tau2_cmd = Kp2*e2 - Kd2*q2_dot + Ki2*xi2;
  F3_cmd   = Kp3*e3 - Kd3*q3_dot + Ki3*xi3 + tau3_grav_ff;

  // Saturation flags
  sat1 = (tau1_cmd > tau1_max) or (tau1_cmd < -tau1_max);
  sat2 = (tau2_cmd > tau2_max) or (tau2_cmd < -tau2_max);
  sat3 = (F3_cmd   > F3_max)   or (F3_cmd   < -F3_max);

  // Conditional (anti-windup) integration
  der(xi1) = if sat1 then 0.0 else e1;
  der(xi2) = if sat2 then 0.0 else e2;
  der(xi3) = if sat3 then 0.0 else e3;

  // Saturated actuator outputs
  tau1_sat = if (tau1_cmd > tau1_max)  then tau1_max
             else if (tau1_cmd < -tau1_max) then -tau1_max else tau1_cmd;
  tau2_sat = if (tau2_cmd > tau2_max)  then tau2_max
             else if (tau2_cmd < -tau2_max) then -tau2_max else tau2_cmd;
  F3_sat   = if (F3_cmd   > F3_max)    then F3_max
             else if (F3_cmd   < -F3_max)   then -F3_max   else F3_cmd;

  // ============ Equations of motion ============
  // 2R planar revolute dynamics (horizontal plane, no gravity torque)
  M11*der(q1_dot) + M12*der(q2_dot) + h*q2_dot^2 + 2.0*h*q1_dot*q2_dot
      = tau1_sat + tau1_dist + tau1_coll;
  M12*der(q1_dot) + M22*der(q2_dot) - h*q1_dot^2
      = tau2_sat + tau2_dist + tau2_coll;

  // Prismatic vertical dynamics (gravity acts along Z)
  m3*der(q3_dot) = F3_sat - m3*g + F3_endstop;

  // ============ Kinematic state integration ============
  der(q1) = q1_dot;
  der(q2) = q2_dot;
  der(q3) = q3_dot;

  annotation(
    experiment(StartTime=0, StopTime=12, Tolerance=1e-6, Interval=0.008),
    Documentation(info="SCARARejectC: Fixed-base articulated SCARA with two Z-revolute links and a Z-prismatic carriage. Saturated state-feedback with integral disturbance rejection. Lateral wrist load injected during middle third. Gravity modeled on vertical prismatic axis. Self-collision between nonadjacent link1 and carriage modeled via soft barriers."));
end SCARARejectC;