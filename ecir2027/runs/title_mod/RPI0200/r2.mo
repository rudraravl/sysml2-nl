model RailArmTraceB
  "Fixed-base articulated manipulator: 1.4 m X-rail carriage + 2-revolute planar arm following cubic joint trajectory through three reachable states with PID+velocity-feedforward control, joint-limit enforcement, cylindrical keep-out obstacle, and 7 N lateral disturbance during middle third."

  // ===== Physical parameters (from requirement) =====
  parameter Real L_rail = 1.4   "Rail length [m]";
  parameter Real m_carriage = 18.0 "Carriage mass [kg]";
  parameter Real l1 = 0.46      "Link 1 length [m]";
  parameter Real l2 = 0.31      "Link 2 length [m]";
  parameter Real joint_lim = 1.5 "Joint limit magnitude [rad]";
  parameter Real tau_max = 69.7  "Max rotary actuator torque [N.m]";
  parameter Real F_max = 800.0   "Max linear actuator force [N]";

  // Link dynamics — NOT specified in requirement; engineering assumptions for compilability
  parameter Real m1 = 2.0  "Link 1 mass [kg] — assumption, not stated in requirement";
  parameter Real m2 = 1.5  "Link 2 mass [kg] — assumption, not stated in requirement";
  parameter Real J1 = 0.50 "Joint 1 effective inertia [kg.m2] — assumption";
  parameter Real J2 = 0.05 "Joint 2 effective inertia [kg.m2] — assumption";
  parameter Real b_x = 50.0 "Rail viscous friction [N.s/m] — assumption";
  parameter Real b1 = 0.50  "Joint 1 viscous friction [N.m.s/rad] — assumption";
  parameter Real b2 = 0.05  "Joint 2 viscous friction [N.m.s/rad] — assumption";

  // ===== Cylindrical keep-out obstacle (beside, not on, nominal path) =====
  parameter Real obs_x = 1.20 "Obstacle center x [m]";
  parameter Real obs_y = 0.90 "Obstacle center y [m]";
  parameter Real obs_r = 0.05 "Obstacle radius [m]";
  parameter Real clearance_req = 0.05 "Required minimum clearance [m]";

  // ===== Disturbance =====
  parameter Real F_dist_mag = 7.0 "Lateral disturbance magnitude [N]";

  // ===== Trajectory timing =====
  parameter Real t_a = 10.0/3.0 "End of segment 0 (first third) [s]";
  parameter Real t_b = 20.0/3.0 "End of segment 1 (middle third end) [s]";
  parameter Real t_end = 10.0   "Mission duration [s]";

  // ===== Three reachable waypoint states =====
  parameter Real q0_x  = 0.30  "State 0 rail position [m]";
  parameter Real q0_t1 = 0.00  "State 0 joint 1 [rad]";
  parameter Real q0_t2 = 0.00  "State 0 joint 2 [rad]";
  parameter Real q1_x  = 0.70  "State 1 rail position [m]";
  parameter Real q1_t1 = 0.50  "State 1 joint 1 [rad]";
  parameter Real q1_t2 = 0.30  "State 1 joint 2 [rad]";
  parameter Real q2_x  = 1.00  "State 2 rail position [m]";
  parameter Real q2_t1 = 1.00  "State 2 joint 1 [rad]";
  parameter Real q2_t2 = -0.50 "State 2 joint 2 [rad]";

  // Intermediate velocities for C1-continuous cubic Hermite through waypoint 1
  parameter Real v_x  = (q2_x  - q0_x)  / t_b "Rail intermediate slope [m/s]";
  parameter Real v_t1 = (q2_t1 - q0_t1) / t_b "Joint 1 intermediate slope [rad/s]";
  parameter Real v_t2 = (q2_t2 - q0_t2) / t_b "Joint 2 intermediate slope [rad/s]";

  // ===== PID + velocity-feedforward gains =====
  parameter Real Kp_x  = 2000.0 "Rail proportional gain";
  parameter Real Ki_x  = 100.0  "Rail integral gain";
  parameter Real Kd_x  = 280.0  "Rail derivative gain";
  parameter Real Kff_x = 50.0   "Rail velocity feedforward gain";
  parameter Real Kp_1  = 110.0  "Joint 1 proportional gain";
  parameter Real Ki_1  = 15.0   "Joint 1 integral gain";
  parameter Real Kd_1  = 10.0   "Joint 1 derivative gain";
  parameter Real Kff_1 = 0.50   "Joint 1 velocity feedforward gain";
  parameter Real Kp_2  = 20.0   "Joint 2 proportional gain";
  parameter Real Ki_2  = 2.0    "Joint 2 integral gain";
  parameter Real Kd_2  = 1.5    "Joint 2 derivative gain";
  parameter Real Kff_2 = 0.05   "Joint 2 velocity feedforward gain";

  // ===== Control loop period =====
  parameter Real Ts = 0.01 "Control loop period [s] (100 Hz)";

  // ===== Dynamic states =====
  Real x(start = q0_x, fixed = true)         "Rail carriage position [m]";
  Real x_dot(start = 0.0, fixed = true)       "Rail velocity [m/s]";
  Real theta1(start = q0_t1, fixed = true)     "Joint 1 angle [rad]";
  Real theta1_dot(start = 0.0, fixed = true)   "Joint 1 velocity [rad/s]";
  Real theta2(start = q0_t2, fixed = true)     "Joint 2 angle [rad]";
  Real theta2_dot(start = 0.0, fixed = true)   "Joint 2 velocity [rad/s]";

  // PID integrator states
  Real int_err_x(start = 0.0, fixed = true)   "Rail integral error";
  Real int_err_1(start = 0.0, fixed = true)   "Joint 1 integral error";
  Real int_err_2(start = 0.0, fixed = true)   "Joint 2 integral error";

  // ===== Reference trajectory =====
  Real x_ref            "Rail reference position [m]";
  Real x_ref_dot        "Rail reference velocity [m/s]";
  Real theta1_ref       "Joint 1 reference [rad]";
  Real theta1_ref_dot   "Joint 1 reference velocity [rad/s]";
  Real theta2_ref       "Joint 2 reference [rad]";
  Real theta2_ref_dot   "Joint 2 reference velocity [rad/s]";

  // ===== Control commands (state + command traces) =====
  Real F_cmd    "Unsaturated force command [N]";
  Real tau1_cmd "Unsaturated joint 1 torque command [N.m]";
  Real tau2_cmd "Unsaturated joint 2 torque command [N.m]";
  Real F_sat    "Saturated force applied [N]";
  Real tau1_sat "Saturated joint 1 torque applied [N.m]";
  Real tau2_sat "Saturated joint 2 torque applied [N.m]";

  // ===== Sensor traces (synchronized encoders) =====
  Real x_enc          "Rail encoder position [m]";
  Real x_dot_enc      "Rail encoder velocity [m/s]";
  Real theta1_enc     "Joint 1 encoder position [rad]";
  Real theta1_dot_enc "Joint 1 encoder velocity [rad/s]";
  Real theta2_enc     "Joint 2 encoder position [rad]";
  Real theta2_dot_enc "Joint 2 encoder velocity [rad/s]";

  // ===== Forward kinematics =====
  Real ee_x         "End-effector x [m]";
  Real ee_y         "End-effector y [m]";
  Real obs_dist     "Distance from end-effector to obstacle center [m]";
  Real obs_clearance "Obstacle clearance (distance - radius) [m]";

  // ===== Disturbance =====
  Real F_dist_y  "Active lateral disturbance force [N]";
  Real dist_tau1 "Disturbance torque on joint 1 via Jacobian transpose [N.m]";
  Real dist_tau2 "Disturbance torque on joint 2 via Jacobian transpose [N.m]";

  // ===== Tracking errors =====
  Real err_x  "Rail tracking error [m]";
  Real err_t1 "Joint 1 tracking error [rad]";
  Real err_t2 "Joint 2 tracking error [rad]";
  Real primary_err "Primary tracking error (max absolute) [rad-or-m]";

  // ===== Joint limit reaction (penalty spring-damper) =====
  Real limit_tau1 "Joint 1 limit reaction torque [N.m]";
  Real limit_tau2 "Joint 2 limit reaction torque [N.m]";

  // ===== Jacobian elements (y-row for disturbance mapping) =====
  Real J21 "Jacobian row 2, col 2: d(ee_y)/d(theta1)";
  Real J22 "Jacobian row 2, col 3: d(ee_y)/d(theta2)";

equation
  // ===== Cubic Hermite trajectory: three segments =====
  if time < t_a then
    // Segment 0: state 0 -> state 1, start at rest
    x_ref          = hermitePos(time, 0.0, t_a, q0_x,  q1_x,  0.0, v_x);
    x_ref_dot      = hermiteVel(time, 0.0, t_a, q0_x,  q1_x,  0.0, v_x);
    theta1_ref     = hermitePos(time, 0.0, t_a, q0_t1, q1_t1, 0.0, v_t1);
    theta1_ref_dot = hermiteVel(time, 0.0, t_a, q0_t1, q1_t1, 0.0, v_t1);
    theta2_ref     = hermitePos(time, 0.0, t_a, q0_t2, q1_t2, 0.0, v_t2);
    theta2_ref_dot = hermiteVel(time, 0.0, t_a, q0_t2, q1_t2, 0.0, v_t2);
  elseif time < t_b then
    // Segment 1: state 1 -> state 2, end at rest
    x_ref          = hermitePos(time, t_a, t_b, q1_x,  q2_x,  v_x,  0.0);
    x_ref_dot      = hermiteVel(time, t_a, t_b, q1_x,  q2_x,  v_x,  0.0);
    theta1_ref     = hermitePos(time, t_a, t_b, q1_t1, q2_t1, v_t1, 0.0);
    theta1_ref_dot = hermiteVel(time, t_a, t_b, q1_t1, q2_t1, v_t1, 0.0);
    theta2_ref     = hermitePos(time, t_a, t_b, q1_t2, q2_t2, v_t2, 0.0);
    theta2_ref_dot = hermiteVel(time, t_a, t_b, q1_t2, q2_t2, v_t2, 0.0);
  else
    // Segment 2: hold at state 2 (stop)
    x_ref          = q2_x;
    x_ref_dot      = 0.0;
    theta1_ref     = q2_t1;
    theta1_ref_dot = 0.0;
    theta2_ref     = q2_t2;
    theta2_ref_dot = 0.0;
  end if;

  // ===== Synchronized encoder sensors (ideal) =====
  x_enc          = x;
  x_dot_enc      = x_dot;
  theta1_enc     = theta1;
  theta1_dot_enc = theta1_dot;
  theta2_enc     = theta2;
  theta2_dot_enc = theta2_dot;

  // ===== Tracking errors (reference - measured) =====
  err_x  = x_ref      - x_enc;
  err_t1 = theta1_ref - theta1_enc;
  err_t2 = theta2_ref - theta2_enc;
  primary_err = max(abs(err_x), max(abs(err_t1), abs(err_t2)));

  // ===== PID + velocity-feedforward control law =====
  F_cmd   = Kp_x * err_x  + Ki_x * int_err_x  + Kd_x * (x_ref_dot      - x_dot_enc)      + Kff_x * x_ref_dot;
  tau1_cmd = Kp_1 * err_t1 + Ki_1 * int_err_1 + Kd_1 * (theta1_ref_dot - theta1_dot_enc) + Kff_1 * theta1_ref_dot;
  tau2_cmd = Kp_2 * err_t2 + Ki_2 * int_err_2 + Kd_2 * (theta2_ref_dot - theta2_dot_enc) + Kff_2 * theta2_ref_dot;

  // ===== Actuator saturation =====
  F_sat    = max(-F_max,   min(F_max,   F_cmd));
  tau1_sat = max(-tau_max, min(tau_max, tau1_cmd));
  tau2_sat = max(-tau_max, min(tau_max, tau2_cmd));

  // ===== Anti-windup: conditional integration stops when saturated in error direction =====
  der(int_err_x) = if (F_cmd > F_max   and err_x  > 0) or (F_cmd < -F_max   and err_x  < 0) then 0.0 else err_x;
  der(int_err_1) = if (tau1_cmd > tau_max and err_t1 > 0) or (tau1_cmd < -tau_max and err_t1 < 0) then 0.0 else err_t1;
  der(int_err_2) = if (tau2_cmd > tau_max and err_t2 > 0) or (tau2_cmd < -tau_max and err_t2 < 0) then 0.0 else err_t2;

  // ===== Forward kinematics (planar 2-link arm on rail) =====
  ee_x = x + l1 * cos(theta1) + l2 * cos(theta1 + theta2);
  ee_y = l1 * sin(theta1) + l2 * sin(theta1 + theta2);

  // ===== Obstacle clearance =====
  obs_dist = sqrt(max((ee_x - obs_x)^2 + (ee_y - obs_y)^2, 1e-12));
  obs_clearance = obs_dist - obs_r;

  // ===== Jacobian (y-row) for disturbance mapping: tau = J^T * F_ee =====
  J21 = l1 * cos(theta1) + l2 * cos(theta1 + theta2);
  J22 = l2 * cos(theta1 + theta2);

  // ===== Lateral disturbance (7 N in y, active during middle third only) =====
  F_dist_y  = if time >= t_a and time <= t_b then F_dist_mag else 0.0;
  dist_tau1 = J21 * F_dist_y;
  dist_tau2 = J22 * F_dist_y;

  // ===== Joint limit reaction (penalty spring-damper, activates only at limits) =====
  limit_tau1 = if theta1 > joint_lim then
                 -500.0 * (theta1 - joint_lim) - 50.0 * theta1_dot
               elseif theta1 < -joint_lim then
                 -500.0 * (theta1 + joint_lim) - 50.0 * theta1_dot
               else
                 0.0;
  limit_tau2 = if theta2 > joint_lim then
                 -200.0 * (theta2 - joint_lim) - 20.0 * theta2_dot
               elseif theta2 < -joint_lim then
                 -200.0 * (theta2 + joint_lim) - 20.0 * theta2_dot
               else
                 0.0;

  // ===== Plant dynamics (decoupled effective-inertia model) =====
  // Rail prismatic joint
  der(x) = x_dot;
  (m_carriage + m1 + m2) * der(x_dot) = F_sat - b_x * x_dot;

  // Joint 1 revolute
  der(theta1) = theta1_dot;
  J1 * der(theta1_dot) = tau1_sat - b1 * theta1_dot + dist_tau1 + limit_tau1;

  // Joint 2 revolute
  der(theta2) = theta2_dot;
  J2 * der(theta2_dot) = tau2_sat - b2 * theta2_dot + dist_tau2 + limit_tau2;

  // ===== Safety assertions (warning level, non-aborting) =====
  assert(obs_clearance >= 0.0, "End-effector penetrates obstacle", AssertionLevel.warning);
  assert(abs(theta1) <= joint_lim + 0.01, "Joint 1 near or beyond limit", AssertionLevel.warning);
  assert(abs(theta2) <= joint_lim + 0.01, "Joint 2 near or beyond limit", AssertionLevel.warning);

  annotation(
    experiment(StopTime = 10.0, Interval = 0.01, Tolerance = 1e-6),
    Documentation(info = "RailArmTraceB: Fixed-base articulated manipulator on 1.4 m X-rail with 2-revolute planar arm (0.46 m, 0.31 m links). Follows cubic Hermite joint trajectory through three reachable states (0->1->2) and holds at state 2. PID + velocity-feedforward control at 100 Hz. 7 N lateral disturbance injected during middle third (t_a to t_b). Cylindrical keep-out obstacle beside nominal path. Joint limits +/-1.5 rad. Actuator limits 69.7 N.m (rotary) and 800 N (linear). Link masses and inertias are engineering assumptions — not specified in the original requirement."));
end RailArmTraceB;