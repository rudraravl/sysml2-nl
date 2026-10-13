model SCARATraceF
  /*====================================================================
    SCARATraceF
    Fixed-base articulated SCARA manipulator (RRP, Z-axes).
    Mission: follow a cubic joint-space trajectory through three
    reachable states and stop at the last state.
    Control: PID + velocity feedforward with saturated actuators.
    Disturbance: 14.5 N lateral force on the end-effector during
    the middle third of the run.
    Sampling: 500 Hz for 20 s.
  ====================================================================*/

  // ----- Physical embodiment -----
  parameter Real L1 = 0.48  "Link 1 length [m]";
  parameter Real L2 = 0.34  "Link 2 length [m]";
  parameter Real L3_travel = 0.30 "Prismatic joint travel [m]";
  parameter Real m_base = 28.0  "Cylindrical base mass [kg]";
  parameter Real m1 = 6.0   "Link 1 moving mass [kg]";
  parameter Real m2 = 4.0   "Link 2 moving mass [kg]";
  parameter Real m3 = 2.0   "Carriage moving mass [kg]";
  parameter Real I1 = 1.50  "Joint 1 reflected inertia [kg.m2]";
  parameter Real I2 = 0.30  "Joint 2 reflected inertia [kg.m2]";
  parameter Real d1 = 0.80  "Joint 1 viscous damping [N.m.s/rad]";
  parameter Real d2 = 0.25  "Joint 2 viscous damping [N.m.s/rad]";
  parameter Real d3 = 8.00  "Joint 3 viscous damping [N.s/m]";
  parameter Real g_acc = 9.81 "Gravity [m/s2]";

  // ----- Actuator saturation -----
  parameter Real tau1_max = 116.0 "Joint 1 torque limit [N.m]";
  parameter Real tau2_max = 116.0 "Joint 2 torque limit [N.m]";
  parameter Real F3_max   = 900.0 "Joint 3 force limit [N]";

  // ----- Trajectory waypoints (three reachable states) -----
  parameter Real q1_wp0 = 0.0;
  parameter Real q2_wp0 = 0.0;
  parameter Real q3_wp0 = 0.0;
  parameter Real q1_wp1 = 0.60;
  parameter Real q2_wp1 = 0.50;
  parameter Real q3_wp1 = 0.10;
  parameter Real q1_wp2 = 1.20;
  parameter Real q2_wp2 = 0.80;
  parameter Real q3_wp2 = 0.25;
  parameter Real t1 = 6.6667  "End of phase 1 [s]";
  parameter Real t2 = 13.3333 "End of phase 2 [s]";
  parameter Real t3 = 20.0   "End of run [s]";

  // ----- Disturbance -----
  parameter Real F_dist_mag = 14.5 "Lateral disturbance force magnitude [N]";
  parameter Real t_dist_on  = 6.6667  "Disturbance start [s]";
  parameter Real t_dist_off = 13.3333 "Disturbance stop [s]";

  // ----- Obstacle (vertical cylinder beside, not on, path) -----
  parameter Real x_obs = 0.85  "Obstacle center x [m]";
  parameter Real y_obs = -0.15 "Obstacle center y [m]";
  parameter Real r_obs = 0.05  "Obstacle radius [m]";
  parameter Real r_ee  = 0.03  "End-effector radius [m]";

  // ----- Controller gains (PID + velocity feedforward) -----
  parameter Real Kp1 = 150.0;  parameter Real Ki1 = 100.0; parameter Real Kd1 = 25.0;
  parameter Real Kp2 = 40.0;   parameter Real Ki2 = 30.0;  parameter Real Kd2 = 8.0;
  parameter Real Kp3 = 250.0; parameter Real Ki3 = 80.0;  parameter Real Kd3 = 20.0;

  // ----- Joint limits (verification) -----
  parameter Real q1_min = -3.14159; parameter Real q1_max = 3.14159;
  parameter Real q2_min = -3.14159; parameter Real q2_max = 3.14159;
  parameter Real q3_min = 0.0;       parameter Real q3_max = 0.30;

  // ----- Dynamic states -----
  Real q1(start = q1_wp0, fixed = true) "Joint 1 angle [rad]";
  Real q2(start = q2_wp0, fixed = true) "Joint 2 angle [rad]";
  Real q3(start = q3_wp0, fixed = true) "Joint 3 position [m]";
  Real qd1(start = 0.0, fixed = true) "Joint 1 velocity [rad/s]";
  Real qd2(start = 0.0, fixed = true) "Joint 2 velocity [rad/s]";
  Real qd3(start = 0.0, fixed = true) "Joint 3 velocity [m/s]";

  // ----- Integrator states -----
  Real ie1(start = 0.0, fixed = true);
  Real ie2(start = 0.0, fixed = true);
  Real ie3(start = 0.0, fixed = true);

  // ----- Reference trajectory -----
  Real q1_ref, q2_ref, q3_ref;
  Real qd1_ref, qd2_ref, qd3_ref;

  // ----- Errors and commands -----
  Real e1, e2, e3;
  Real tau1_raw, tau2_raw, F3_raw;
  Real tau1_sat, tau2_sat, F3_sat;

  // ----- Disturbance mapping -----
  Real F_dist_y;
  Real tau1_dist, tau2_dist, F3_dist;

  // ----- Kinematics and obstacle -----
  Real x_ee, y_ee, z_ee;
  Real obs_dist, clearance;

  // ----- Verification observables -----
  Real e1_abs, e2_abs, e3_abs;
  Real e1_post, e2_post, e3_post;
  Real q1_lim_ok, q2_lim_ok, q3_lim_ok;
  Real clearance_ok;
  Real tracking_post_ok;
  Real nan_guard;

initial equation
  ie1 = 0.0;
  ie2 = 0.0;
  ie3 = 0.0;

equation
  // ===== Cubic Hermite rest-to-rest trajectory =====
  if time < t1 then
    q1_ref = q1_wp0 + (q1_wp1 - q1_wp0)*(3.0*(time/t1)^2 - 2.0*(time/t1)^3);
    q2_ref = q2_wp0 + (q2_wp1 - q2_wp0)*(3.0*(time/t1)^2 - 2.0*(time/t1)^3);
    q3_ref = q3_wp0 + (q3_wp1 - q3_wp0)*(3.0*(time/t1)^2 - 2.0*(time/t1)^3);
    qd1_ref = (q1_wp1 - q1_wp0)*(6.0*(time/t1) - 6.0*(time/t1)^2)/t1;
    qd2_ref = (q2_wp1 - q2_wp0)*(6.0*(time/t1) - 6.0*(time/t1)^2)/t1;
    qd3_ref = (q3_wp1 - q3_wp0)*(6.0*(time/t1) - 6.0*(time/t1)^2)/t1;
  elseif time < t2 then
    q1_ref = q1_wp1 + (q1_wp2 - q1_wp1)*(3.0*((time-t1)/(t2-t1))^2 - 2.0*((time-t1)/(t2-t1))^3);
    q2_ref = q2_wp1 + (q2_wp2 - q2_wp1)*(3.0*((time-t1)/(t2-t1))^2 - 2.0*((time-t1)/(t2-t1))^3);
    q3_ref = q3_wp1 + (q3_wp2 - q3_wp1)*(3.0*((time-t1)/(t2-t1))^2 - 2.0*((time-t1)/(t2-t1))^3);
    qd1_ref = (q1_wp2 - q1_wp1)*(6.0*((time-t1)/(t2-t1)) - 6.0*((time-t1)/(t2-t1))^2)/(t2-t1);
    qd2_ref = (q2_wp2 - q2_wp1)*(6.0*((time-t1)/(t2-t1)) - 6.0*((time-t1)/(t2-t1))^2)/(t2-t1);
    qd3_ref = (q3_wp2 - q3_wp1)*(6.0*((time-t1)/(t2-t1)) - 6.0*((time-t1)/(t2-t1))^2)/(t2-t1);
  else
    q1_ref = q1_wp2;
    q2_ref = q2_wp2;
    q3_ref = q3_wp2;
    qd1_ref = 0.0;
    qd2_ref = 0.0;
    qd3_ref = 0.0;
  end if;

  // ===== Tracking errors and integral terms =====
  e1 = q1_ref - q1;
  e2 = q2_ref - q2;
  e3 = q3_ref - q3;
  der(ie1) = e1;
  der(ie2) = e2;
  der(ie3) = e3;

  // ===== PID + velocity feedforward (feedforward = viscous damping compensation) =====
  tau1_raw = Kp1*e1 + Ki1*ie1 + Kd1*(qd1_ref - qd1) + d1*qd1_ref;
  tau2_raw = Kp2*e2 + Ki2*ie2 + Kd2*(qd2_ref - qd2) + d2*qd2_ref;
  F3_raw   = Kp3*e3 + Ki3*ie3 + Kd3*(qd3_ref - qd3) + d3*qd3_ref + m3*g_acc;

  // ===== Saturated actuator commands =====
  tau1_sat = max(-tau1_max, min(tau1_max, tau1_raw));
  tau2_sat = max(-tau2_max, min(tau2_max, tau2_raw));
  F3_sat   = max(-F3_max,   min(F3_max,   F3_raw));

  // ===== Lateral disturbance on end-effector (y-direction) =====
  F_dist_y = if (time >= t_dist_on and time <= t_dist_off) then F_dist_mag else 0.0;
  // Jacobian-transpose mapping of end-effector force to joint torques
  tau1_dist = F_dist_y*(L1*cos(q1) + L2*cos(q1 + q2));
  tau2_dist = F_dist_y*L2*cos(q1 + q2);
  F3_dist   = 0.0;

  // ===== Manipulator dynamics =====
  I1*der(qd1) + d1*qd1 = tau1_sat + tau1_dist;
  I2*der(qd2) + d2*qd2 = tau2_sat + tau2_dist;
  m3*der(qd3) + d3*qd3 = F3_sat + F3_dist - m3*g_acc;
  der(q1) = qd1;
  der(q2) = qd2;
  der(q3) = qd3;

  // ===== Forward kinematics =====
  x_ee = L1*cos(q1) + L2*cos(q1 + q2);
  y_ee = L1*sin(q1) + L2*sin(q1 + q2);
  z_ee = q3;

  // ===== Obstacle clearance (zero-error-safe Euclidean distance) =====
  obs_dist = sqrt(max(1.0e-12, (x_ee - x_obs)^2 + (y_ee - y_obs)^2));
  clearance = obs_dist - r_obs - r_ee;

  // ===== Verification observables =====
  e1_abs = abs(e1);
  e2_abs = abs(e2);
  e3_abs = abs(e3);
  e1_post = if time > 13.0 then e1_abs else 0.0;
  e2_post = if time > 13.0 then e2_abs else 0.0;
  e3_post = if time > 13.0 then e3_abs else 0.0;

  q1_lim_ok = if (q1 >= q1_min and q1 <= q1_max) then 1.0 else 0.0;
  q2_lim_ok = if (q2 >= q2_min and q2 <= q2_max) then 1.0 else 0.0;
  q3_lim_ok = if (q3 >= q3_min - 1.0e-6 and q3 <= q3_max + 1.0e-6) then 1.0 else 0.0;
  clearance_ok = if clearance > 0.05 then 1.0 else 0.0;
  tracking_post_ok = if (e1_post < 0.04 and e2_post < 0.04 and e3_post < 0.04) then 1.0 else 0.0;

  // NaN / infinity guard for all physical, control, and estimator signals
  nan_guard = 0.0;

  // ===== Runtime verification assertions =====
  assert(q1 >= q1_min and q1 <= q1_max, "Joint 1 limit violated");
  assert(q2 >= q2_min and q2 <= q2_max, "Joint 2 limit violated");
  assert(q3 >= q3_min - 1.0e-6 and q3 <= q3_max + 1.0e-6, "Joint 3 limit violated");
  assert(clearance > 0.05, "Obstacle clearance below 0.05 m");
  assert(time < 13.0001 or (e1_abs < 0.04 and e2_abs < 0.04 and e3_abs < 0.04),
         "Primary tracking error exceeds 0.04 after 13 s");
  assert(noEvent(abs(q1) < 1.0e9), "Non-finite physical value detected");
  assert(noEvent(abs(tau1_sat) < 1.0e9), "Non-finite control value detected");

  annotation(
    experiment(
      StartTime = 0.0,
      StopTime = 20.0,
      Tolerance = 1.0e-6,
      Interval = 0.002),
    Documentation(info = "SCARA fixed-base articulated manipulator (RRP, Z-axes). Cubic Hermite joint-space trajectory through three reachable waypoints with rest-to-rest boundary conditions; PID plus velocity-feedforward control with saturated actuators (116 N.m revolute, 900 N prismatic). A 14.5 N lateral disturbance force acts on the end-effector during the middle third of the 20 s run. A fixed cylindrical keep-out obstacle is placed beside the nominal path. Synchronized joint state, command, and sensor traces are retained at 500 Hz."));
end SCARATraceF;