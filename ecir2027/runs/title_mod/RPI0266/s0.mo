model FiveBarDriveB
  "Five-bar closed-chain robotic mechanism: constant-speed input drive with PI control"

  // === Geometric parameters ===
  parameter Real L_base = 0.25 "Half-distance between base pivots [m]";
  parameter Real L_act = 0.30 "Actuated link length [m]";
  parameter Real L_pas = 0.42 "Passive link length [m]";

  // === Physical parameters (assumed; not specified in requirement) ===
  parameter Real m_link = 1.0 "Actuated link mass [kg] — assumed";
  parameter Real m_coupler = 0.5 "Coupler point mass [kg] — assumed";
  parameter Real J_link = m_link * L_act ^ 2 / 3.0
    "Actuated link inertia about pivot [kg.m2] — assumed";
  parameter Real g_acc = 9.81 "Gravitational acceleration [m/s2]";

  // === Constraint enforcement (penalty method) ===
  parameter Real k_con = 2.0e4 "Constraint spring stiffness [N/m] — assumed";
  parameter Real c_con = 80.0 "Constraint damping [N.s/m] — assumed";

  // === Control ===
  parameter Real omega_ref = 0.05 "Reference angular speed magnitude [rad/s] — assumed";
  parameter Real Kp = 15.0 "PI proportional gain — assumed";
  parameter Real Ki = 80.0 "PI integral gain — assumed";
  parameter Real tau_max = 31.2 "Max actuator torque magnitude [N.m]";

  // === Disturbance ===
  parameter Real F_dist = 5.6 "Disturbance force magnitude [N]";
  parameter Real t_dist_start = 10.0 / 3.0 "Disturbance start time [s]";
  parameter Real t_dist_end = 20.0 / 3.0 "Disturbance end time [s]";

  // === Initial conditions ===
  parameter Real q1_0 = 1.5707963267948966 "Initial angle link 1 (pi/2) [rad]";
  parameter Real q2_0 = 1.5707963267948966 "Initial angle link 2 (pi/2) [rad]";
  parameter Real Px_0 = 0.0 "Initial coupler x [m]";
  parameter Real Py_0 = 0.6375 "Initial coupler y [m]";

  // === Dynamic states ===
  Real q1(start = q1_0, fixed = true) "Actuated joint 1 angle [rad]";
  Real qd1(start = 0.0, fixed = true) "Actuated joint 1 velocity [rad/s]";
  Real q2(start = q2_0, fixed = true) "Actuated joint 2 angle [rad]";
  Real qd2(start = 0.0, fixed = true) "Actuated joint 2 velocity [rad/s]";
  Real Px(start = Px_0, fixed = true) "Coupler point x [m]";
  Real Py(start = Py_0, fixed = true) "Coupler point y [m]";
  Real vPx(start = 0.0, fixed = true) "Coupler point x-velocity [m/s]";
  Real vPy(start = 0.0, fixed = true) "Coupler point y-velocity [m/s]";
  Real integ1(start = 0.0, fixed = true) "PI integral error channel 1";
  Real integ2(start = 0.0, fixed = true) "PI integral error channel 2";
  Real output_travel(start = 0.0, fixed = true) "Cumulative output path length [m]";

  // === Kinematic variables ===
  Real B1x "Link 1 endpoint x [m]";
  Real B1y "Link 1 endpoint y [m]";
  Real B2x "Link 2 endpoint x [m]";
  Real B2y "Link 2 endpoint y [m]";
  Real vB1x "B1 velocity x [m/s]";
  Real vB1y "B1 velocity y [m/s]";
  Real vB2x "B2 velocity x [m/s]";
  Real vB2y "B2 velocity y [m/s]";
  Real L1 "Distance B1 to P [m]";
  Real L2 "Distance B2 to P [m]";
  Real u1x "Unit vector B1->P x";
  Real u1y "Unit vector B1->P y";
  Real u2x "Unit vector B2->P x";
  Real u2y "Unit vector B2->P y";
  Real vrel1 "Relative velocity along passive link 1 [m/s]";
  Real vrel2 "Relative velocity along passive link 2 [m/s]";

  // === Forces and torques ===
  Real F1x "Constraint force on P from link 1 x [N]";
  Real F1y "Constraint force on P from link 1 y [N]";
  Real F2x "Constraint force on P from link 2 x [N]";
  Real F2y "Constraint force on P from link 2 y [N]";
  Real tau_grav1 "Gravity torque link 1 [N.m]";
  Real tau_grav2 "Gravity torque link 2 [N.m]";
  Real tau_con1 "Constraint torque link 1 [N.m]";
  Real tau_con2 "Constraint torque link 2 [N.m]";
  Real tau1 "Actuator 1 saturated torque [N.m]";
  Real tau2 "Actuator 2 saturated torque [N.m]";
  Real tau1_cmd "Unsaturated command 1 [N.m]";
  Real tau2_cmd "Unsaturated command 2 [N.m]";

  // === Control signals ===
  Real e1 "Speed error 1 [rad/s]";
  Real e2 "Speed error 2 [rad/s]";
  Real omega1_ref "Reference speed 1 [rad/s]";
  Real omega2_ref "Reference speed 2 [rad/s]";

  // === Disturbance ===
  Real F_dist_x "Disturbance force x [N]";
  Boolean dist_active "Disturbance active flag";

  // === Sensors and monitors ===
  Real closure_err1 "Loop-closure residual 1 [m]";
  Real closure_err2 "Loop-closure residual 2 [m]";
  Real tracking_err "Primary tracking (closure) error [m]";
  Real dist_B1B2 "Distance between B1 and B2 [m]";
  Real speed_err1 "Speed tracking error 1 [rad/s]";
  Real speed_err2 "Speed tracking error 2 [rad/s]";
  Real tau1_abs "Abs actuator 1 torque [N.m]";
  Real tau2_abs "Abs actuator 2 torque [N.m]";
  Boolean tau1_sat "Actuator 1 saturated";
  Boolean tau2_sat "Actuator 2 saturated";
  Real nonadj_clear_1 "Clearance nonadjacent pair link1-link4 [m]";
  Real nonadj_clear_2 "Clearance nonadjacent pair link2-link3 [m]";
  Real min_clearance "Minimum nonadjacent clearance [m]";

  // === Requirement checks ===
  Boolean closure_ok "Closure error below 0.002 m after 6.5 s";
  Boolean speed_band_ok "Speed within band";
  Boolean tau_bound_ok "Torque within bounds";
  Boolean feasible_refs "Joint references feasible";
  Boolean no_collision "No nonadjacent link collision";

equation
  // === Kinematics ===
  B1x = -L_base + L_act * cos(q1);
  B1y = L_act * sin(q1);
  B2x = L_base + L_act * cos(q2);
  B2y = L_act * sin(q2);

  vB1x = -L_act * sin(q1) * qd1;
  vB1y = L_act * cos(q1) * qd1;
  vB2x = -L_act * sin(q2) * qd2;
  vB2y = L_act * cos(q2) * qd2;

  L1 = sqrt((Px - B1x) ^ 2 + (Py - B1y) ^ 2);
  L2 = sqrt((Px - B2x) ^ 2 + (Py - B2y) ^ 2);

  // Unit vectors with zero-error branch to prevent division by zero
  u1x = (Px - B1x) / max(L1, 1e-8);
  u1y = (Py - B1y) / max(L1, 1e-8);
  u2x = (Px - B2x) / max(L2, 1e-8);
  u2y = (Py - B2y) / max(L2, 1e-8);

  // Relative velocity along each passive link direction
  vrel1 = (vPx - vB1x) * u1x + (vPy - vB1y) * u1y;
  vrel2 = (vPx - vB2x) * u2x + (vPy - vB2y) * u2y;

  // === Constraint forces (penalty spring-damper enforcing rigid passive links) ===
  F1x = -k_con * (L1 - L_pas) * u1x - c_con * vrel1 * u1x;
  F1y = -k_con * (L1 - L_pas) * u1y - c_con * vrel1 * u1y;
  F2x = -k_con * (L2 - L_pas) * u2x - c_con * vrel2 * u2x;
  F2y = -k_con * (L2 - L_pas) * u2y - c_con * vrel2 * u2y;

  // === Gravity torques on actuated links (pendulum effect) ===
  tau_grav1 = -m_link * g_acc * (L_act / 2.0) * cos(q1);
  tau_grav2 = -m_link * g_acc * (L_act / 2.0) * cos(q2);

  // === Constraint torques on actuated links (reaction at B_i) ===
  tau_con1 = L_act * (sin(q1) * F1x - cos(q1) * F1y);
  tau_con2 = L_act * (sin(q2) * F2x - cos(q2) * F2y);

  // === Actuated link dynamics ===
  J_link * der(qd1) = tau1 + tau_grav1 + tau_con1;
  J_link * der(qd2) = tau2 + tau_grav2 + tau_con2;
  der(q1) = qd1;
  der(q2) = qd2;

  // === Coupler point dynamics ===
  m_coupler * der(vPx) = F1x + F2x + F_dist_x;
  m_coupler * der(vPy) = F1y + F2y - m_coupler * g_acc;
  der(Px) = vPx;
  der(Py) = vPy;

  // === Disturbance injection (middle third of 10 s) ===
  dist_active = (time >= t_dist_start) and (time <= t_dist_end);
  F_dist_x = if dist_active then F_dist else 0.0;

  // === PI speed control with command saturation ===
  omega1_ref = omega_ref;
  omega2_ref = -omega_ref;

  e1 = omega1_ref - qd1;
  e2 = omega2_ref - qd2;

  der(integ1) = e1;
  der(integ2) = e2;

  tau1_cmd = Kp * e1 + Ki * integ1;
  tau2_cmd = Kp * e2 + Ki * integ2;

  tau1 = max(-tau_max, min(tau_max, tau1_cmd));
  tau2 = max(-tau_max, min(tau_max, tau2_cmd));

  // === Output travel accumulation ===
  der(output_travel) = sqrt(vPx ^ 2 + vPy ^ 2);

  // === Sensors ===
  closure_err1 = abs(L1 - L_pas);
  closure_err2 = abs(L2 - L_pas);
  tracking_err = max(closure_err1, closure_err2);
  dist_B1B2 = sqrt((B2x - B1x) ^ 2 + (B2y - B1y) ^ 2);
  speed_err1 = abs(qd1 - omega1_ref);
  speed_err2 = abs(qd2 - omega2_ref);
  tau1_abs = abs(tau1);
  tau2_abs = abs(tau2);
  tau1_sat = abs(tau1_cmd) > tau_max;
  tau2_sat = abs(tau2_cmd) > tau_max;

  // === Nonadjacent link collision monitoring ===
  // Pair 1: actuated link 1 (A1 to B1) vs passive link 4 (B2 to P)
  // Pair 2: actuated link 2 (A2 to B2) vs passive link 3 (B1 to P)
  // Symmetric reference trajectory by design prevents collision
  nonadj_clear_1 = sqrt(
    ((-L_base + B1x) / 2.0 - (B2x + Px) / 2.0) ^ 2 +
    ((0.0 + B1y) / 2.0 - (B2y + Py) / 2.0) ^ 2);
  nonadj_clear_2 = sqrt(
    ((L_base + B2x) / 2.0 - (B1x + Px) / 2.0) ^ 2 +
    ((0.0 + B2y) / 2.0 - (B1y + Py) / 2.0) ^ 2);
  min_clearance = min(nonadj_clear_1, nonadj_clear_2);

  // === Requirement checks ===
  closure_ok = (time < 6.5) or (tracking_err < 0.002);
  speed_band_ok = (speed_err1 < 0.01) and (speed_err2 < 0.01);
  tau_bound_ok = (tau1_abs <= tau_max + 1e-6) and (tau2_abs <= tau_max + 1e-6);
  feasible_refs = (dist_B1B2 > 0.01) and (dist_B1B2 < 2.0 * L_pas - 0.01);
  no_collision = min_clearance > 0.001;

  annotation(
    Documentation(info = "Five-bar closed-chain mechanism FiveBarDriveB.
      Two base pivots at +/-0.25 m support two 0.30 m actuated links.
      Two 0.42 m passive links meet at a planar coupler point.
      PI speed control drives both base-joint torque actuators with
      command saturation at 31.2 N.m per actuator.
      Penalty-method spring-damper enforces loop-closure constraints.
      Gravity acts on actuated links and coupler point mass.
      Disturbance: 5.6 N force at coupler during middle third (3.33-6.67 s).
      Nonadjacent link collision monitored via midpoint clearance.
      Output at 100 Hz for 10 s; primary tracking error < 0.002 m closure after 6.5 s.
      Assumed parameters (m_link, m_coupler, J_link, k_con, c_con, gains, omega_ref)
      are labeled in their declarations."),
    experiment(StartTime = 0, StopTime = 10.0, Tolerance = 1e-6, Interval = 0.01)
  );
end FiveBarDriveB;