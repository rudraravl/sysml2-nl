model FiveBarTraceC
  "Closed-chain five-bar parallel mechanism with inverse-kinematic trajectory control tracing a circle"

  // ===== Specified parameters =====
  parameter Real L1 = 0.30 "Actuated link length [m]";
  parameter Real L2 = 0.42 "Passive link length [m]";
  parameter Real baseHalf = 0.25 "Half-distance between base pivots [m]";
  parameter Real r_circle = 0.10 "Target circle radius [m]";
  parameter Real tau_max = 35.0 "Maximum torque command per actuator [N.m]";
  parameter Real F_dist = 9.0 "Output load disturbance magnitude [N]";
  parameter Real T_total = 12.0 "Total run time [s]";
  parameter Real f_ctrl = 125.0 "Control loop frequency [Hz]";

  // ===== Assumed parameters (not stated in requirement) =====
  parameter Real cx = 0.0 "Circle center x [m] — not specified";
  parameter Real cy = 0.45 "Circle center y [m] — not specified";
  parameter Real T_cycle = 6.0 "Circle tracing period [s] — not specified";
  parameter Real J_a = 0.05 "Actuated link inertia about base [kg.m2] — not specified";
  parameter Real m_link = 0.5 "Actuated link mass [kg] — not specified";
  parameter Real m_payload = 1.0 "Endpoint payload mass [kg] — not specified";
  parameter Real b_joint = 0.10 "Joint viscous damping [N.m.s/rad] — not specified";
  parameter Real g_acc = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real Kp = 200.0 "Joint PD proportional gain [N.m/rad] — not specified";
  parameter Real Kd = 20.0 "Joint PD derivative gain [N.m.s/rad] — not specified";
  parameter Real Kc = 50.0 "Cartesian closure-stabilization gain [N/m] — not specified";
  parameter Real obs_x = 0.25 "Obstacle center x [m] — not specified";
  parameter Real obs_y = 0.25 "Obstacle center y [m] — not specified";
  parameter Real obs_r = 0.04 "Obstacle safety radius [m] — not specified";
  parameter Real joint_lim = 3.14159265358979 "Joint angle limit magnitude [rad] — not specified";

  // ===== Constants and derived parameters =====
  constant Real pi = 3.141592653589793;
  parameter Real Ts = 1.0 / f_ctrl "Control sampling period [s]";
  parameter Real eps_safe = 1e-9 "Numerical safety epsilon for division protection";
  parameter Real eps_jac = 1e-6 "Finite-difference step for Jacobian [rad]";

  // ===== Dynamic states =====
  Real theta1(start = 1.703) "Left actuated joint angle [rad]";
  Real theta2(start = 0.830) "Right actuated joint angle [rad]";
  Real omega1(start = 0.0) "Left joint angular velocity [rad/s]";
  Real omega2(start = 0.0) "Right joint angular velocity [rad/s]";

  // ===== Forward kinematics (nominal) =====
  Real E1x "Left elbow x [m]";
  Real E1y "Left elbow y [m]";
  Real E2x "Right elbow x [m]";
  Real E2y "Right elbow y [m]";
  Real dx_fk "Inter-elbow x [m]";
  Real dy_fk "Inter-elbow y [m]";
  Real d_len "Inter-elbow distance [m]";
  Real h_perp "Perpendicular offset to endpoint [m]";
  Real Px "Endpoint x [m]";
  Real Py "Endpoint y [m]";

  // ===== Forward kinematics (perturb theta1 for Jacobian) =====
  Real E1x_a, E1y_a, E2x_a, E2y_a, dx_a, dy_a, d_a, h_a, Px_a, Py_a;

  // ===== Forward kinematics (perturb theta2 for Jacobian) =====
  Real E1x_b, E1y_b, E2x_b, E2y_b, dx_b, dy_b, d_b, h_b, Px_b, Py_b;

  // ===== Jacobian and mass matrix =====
  Real J11 "dPx/dtheta1 [m/rad]";
  Real J12 "dPx/dtheta2 [m/rad]";
  Real J21 "dPy/dtheta1 [m/rad]";
  Real J22 "dPy/dtheta2 [m/rad]";
  Real det_J "Jacobian determinant [m^2/rad^2]";
  Real M11, M12, M22, det_M;

  // ===== Reference trajectory and inverse kinematics =====
  Real x_ref "Reference endpoint x [m]";
  Real y_ref "Reference endpoint y [m]";
  Real dL_ref, dR_ref, alphaL_ref, alphaR_ref;
  Real cosBetaL_ref, cosBetaR_ref, betaL_ref, betaR_ref;
  Real theta1_ref "Reference left joint angle [rad]";
  Real theta2_ref "Reference right joint angle [rad]";

  // ===== Control =====
  Real grav1 "Gravity torque on left link [N.m]";
  Real grav2 "Gravity torque on right link [N.m]";
  Real tau1_raw "Unsaturated left torque command [N.m]";
  Real tau2_raw "Unsaturated right torque command [N.m]";
  discrete Real tau1_d(start = 0.0) "Sampled saturated left torque [N.m]";
  discrete Real tau2_d(start = 0.0) "Sampled saturated right torque [N.m]";
  Real tau1 "Applied left torque [N.m]";
  Real tau2 "Applied right torque [N.m]";

  // ===== Disturbance =====
  Real dist_active "Disturbance active flag";
  Real F_dist_x "Disturbance force x component [N]";
  Real F_dist_y "Disturbance force y component [N]";

  // ===== Sensors =====
  Real enc1 "Left encoder reading [rad]";
  Real enc2 "Right encoder reading [rad]";
  Real pose_x "Output pose x measurement [m]";
  Real pose_y "Output pose y measurement [m]";

  // ===== Metrics =====
  Real closure_err "Closure constraint error [m]";
  Real path_err "Path tracking error [m]";
  Real singularity_margin "Distance to nearest kinematic singularity [m]";
  Real clearance "Obstacle clearance [m]";
  Real joint1_bound "Joint 1 bound indicator (1=ok, 0=violation)";
  Real joint2_bound "Joint 2 bound indicator (1=ok, 0=violation)";
  Real effort1_bound "Effort 1 bound indicator (1=ok, 0=violation)";
  Real effort2_bound "Effort 2 bound indicator (1=ok, 0=violation)";

equation
  // ===== Reference circle trajectory =====
  x_ref = cx + r_circle * cos(2.0 * pi * time / T_cycle);
  y_ref = cy + r_circle * sin(2.0 * pi * time / T_cycle);

  // ===== Inverse kinematics (elbow-outward configuration) =====
  dL_ref = sqrt((x_ref + baseHalf)^2 + y_ref^2);
  dR_ref = sqrt((x_ref - baseHalf)^2 + y_ref^2);
  alphaL_ref = atan2(y_ref, x_ref + baseHalf);
  alphaR_ref = atan2(y_ref, x_ref - baseHalf);
  cosBetaL_ref = (L1^2 + dL_ref^2 - L2^2) / (2.0 * L1 * max(dL_ref, eps_safe));
  cosBetaR_ref = (L1^2 + dR_ref^2 - L2^2) / (2.0 * L1 * max(dR_ref, eps_safe));
  betaL_ref = acos(max(-1.0, min(1.0, cosBetaL_ref)));
  betaR_ref = acos(max(-1.0, min(1.0, cosBetaR_ref)));
  theta1_ref = alphaL_ref + betaL_ref;
  theta2_ref = alphaR_ref - betaR_ref;

  // ===== Forward kinematics (nominal) =====
  E1x = -baseHalf + L1 * cos(theta1);
  E1y = L1 * sin(theta1);
  E2x = baseHalf + L1 * cos(theta2);
  E2y = L1 * sin(theta2);
  dx_fk = E2x - E1x;
  dy_fk = E2y - E1y;
  d_len = sqrt(dx_fk^2 + dy_fk^2);
  h_perp = sqrt(max(L2^2 - (d_len / 2.0)^2, eps_safe));
  Px = (E1x + E2x) / 2.0 + h_perp * (-dy_fk / max(d_len, eps_safe));
  Py = (E1y + E2y) / 2.0 + h_perp * (dx_fk / max(d_len, eps_safe));

  // ===== Forward kinematics (perturb theta1 by +eps_jac) =====
  E1x_a = -baseHalf + L1 * cos(theta1 + eps_jac);
  E1y_a = L1 * sin(theta1 + eps_jac);
  E2x_a = baseHalf + L1 * cos(theta2);
  E2y_a = L1 * sin(theta2);
  dx_a = E2x_a - E1x_a;
  dy_a = E2y_a - E1y_a;
  d_a = sqrt(dx_a^2 + dy_a^2);
  h_a = sqrt(max(L2^2 - (d_a / 2.0)^2, eps_safe));
  Px_a = (E1x_a + E2x_a) / 2.0 + h_a * (-dy_a / max(d_a, eps_safe));
  Py_a = (E1y_a + E2y_a) / 2.0 + h_a * (dx_a / max(d_a, eps_safe));

  // ===== Forward kinematics (perturb theta2 by +eps_jac) =====
  E1x_b = -baseHalf + L1 * cos(theta1);
  E1y_b = L1 * sin(theta1);
  E2x_b = baseHalf + L1 * cos(theta2 + eps_jac);
  E2y_b = L1 * sin(theta2 + eps_jac);
  dx_b = E2x_b - E1x_b;
  dy_b = E2y_b - E1y_b;
  d_b = sqrt(dx_b^2 + dy_b^2);
  h_b = sqrt(max(L2^2 - (d_b / 2.0)^2, eps_safe));
  Px_b = (E1x_b + E2x_b) / 2.0 + h_b * (-dy_b / max(d_b, eps_safe));
  Py_b = (E1y_b + E2y_b) / 2.0 + h_b * (dx_b / max(d_b, eps_safe));

  // ===== Jacobian via finite differences =====
  J11 = (Px_a - Px) / eps_jac;
  J12 = (Px_b - Px) / eps_jac;
  J21 = (Py_a - Py) / eps_jac;
  J22 = (Py_b - Py) / eps_jac;
  det_J = J11 * J22 - J12 * J21;

  // ===== Mass matrix (actuated link inertia + payload coupling, Coriolis omitted) =====
  M11 = J_a + m_payload * (J11^2 + J21^2);
  M12 = m_payload * (J11 * J12 + J21 * J22);
  M22 = J_a + m_payload * (J12^2 + J22^2);
  det_M = max(M11 * M22 - M12^2, eps_safe);

  // ===== Gravity torques on actuated links =====
  grav1 = -m_link * g_acc * (L1 / 2.0) * cos(theta1);
  grav2 = -m_link * g_acc * (L1 / 2.0) * cos(theta2);

  // ===== Disturbance (middle third: 4 s to 8 s, tangential to circle) =====
  dist_active = if (time >= T_total / 3.0 and time <= 2.0 * T_total / 3.0) then 1.0 else 0.0;
  F_dist_x = dist_active * F_dist * (-sin(2.0 * pi * time / T_cycle));
  F_dist_y = dist_active * F_dist * (cos(2.0 * pi * time / T_cycle));

  // ===== Control law: joint PD + Cartesian closure-stabilization + gravity compensation =====
  tau1_raw = Kp * (theta1_ref - theta1) + Kd * (-omega1)
           + Kc * (J11 * (x_ref - Px) + J21 * (y_ref - Py)) - grav1;
  tau2_raw = Kp * (theta2_ref - theta2) + Kd * (-omega2)
           + Kc * (J12 * (x_ref - Px) + J22 * (y_ref - Py)) - grav2;

  // ===== Discrete sampling at 125 Hz with torque saturation =====
  when sample(0, Ts) then
    tau1_d = max(-tau_max, min(tau_max, tau1_raw));
    tau2_d = max(-tau_max, min(tau_max, tau2_raw));
  end when;

  tau1 = tau1_d;
  tau2 = tau2_d;

  // ===== Dynamics: M(q) * q_ddot = tau - b*qdot + grav + J^T * F_dist =====
  der(theta1) = omega1;
  der(theta2) = omega2;
  der(omega1) = (M22 * (tau1 - b_joint * omega1 + grav1 + J11 * F_dist_x + J21 * F_dist_y)
              -  M12 * (tau2 - b_joint * omega2 + grav2 + J12 * F_dist_x + J22 * F_dist_y)) / det_M;
  der(omega2) = (-M12 * (tau1 - b_joint * omega1 + grav1 + J11 * F_dist_x + J21 * F_dist_y)
              +  M11 * (tau2 - b_joint * omega2 + grav2 + J12 * F_dist_x + J22 * F_dist_y)) / det_M;

  // ===== Sensors: actuator encoders and direct output-pose measurement =====
  enc1 = theta1;
  enc2 = theta2;
  pose_x = Px;
  pose_y = Py;

  // ===== Metrics =====
  // Closure error: residual in passive link lengths (zero by construction)
  closure_err = abs(sqrt((Px - E1x)^2 + (Py - E1y)^2) - L2)
             + abs(sqrt((Px - E2x)^2 + (Py - E2y)^2) - L2);

  // Path tracking error: Euclidean distance from reference to endpoint
  path_err = sqrt((x_ref - Px)^2 + (y_ref - Py)^2);

  // Singularity margin: distance from passive-link collinearity (d=0 or d=2*L2)
  singularity_margin = min(d_len, 2.0 * L2 - d_len);

  // Obstacle clearance: endpoint-to-obstacle distance minus safety radius
  clearance = sqrt((Px - obs_x)^2 + (Py - obs_y)^2) - obs_r;

  // Joint and effort bound indicators
  joint1_bound = if (abs(theta1) <= joint_lim) then 1.0 else 0.0;
  joint2_bound = if (abs(theta2) <= joint_lim) then 1.0 else 0.0;
  effort1_bound = if (abs(tau1) <= tau_max) then 1.0 else 0.0;
  effort2_bound = if (abs(tau2) <= tau_max) then 1.0 else 0.0;

  annotation(
    experiment(StartTime = 0, StopTime = 12, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info = "<html>
<p>FiveBarTraceC: Closed-chain five-bar parallel mechanism with inverse-kinematic
trajectory control. Traces a planar circle of radius 0.10 m.</p>
<p>Two base pivots at plus or minus 0.25 m support two 0.30 m actuated links and
two 0.42 m passive links meeting at one planar endpoint. Two base-joint torque
actuators drive the parallel mechanism.</p>
<p>Control runs at 125 Hz for 12 s. A 9 N disturbance is injected during the
middle third (4 to 8 s). One fixed obstacle outside the circle requires explicit
clearance monitoring.</p>
<p>Sensors: actuator encoders and direct output-pose measurement.</p>
<p>Metrics: closure error, path error, singularity margin, clearance, joint and
effort bounds. Primary tracking error target: below 0.008 m after 7.8 s.</p>
<p>Parameters not stated in the requirement (circle center, tracing period, link
masses and inertias, damping, controller gains, obstacle position, joint limits)
are assumed and labeled as such in their declarations.</p>
</html>")
  );
end FiveBarTraceC;