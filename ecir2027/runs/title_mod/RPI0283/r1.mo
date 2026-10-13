model FiveBarPressA
  "Closed-chain five-bar parallel mechanism with hybrid position/force control"

  // === Geometry [m] ===
  parameter Real L1 = 0.30 "Actuated link length [m]";
  parameter Real L2 = 0.42 "Passive link length [m]";
  parameter Real bx = 0.25 "Half base pivot distance [m]";
  parameter Real y_surface = 0.50 "Workpiece surface height [m]";

  // === Inertial parameters (design assumptions; masses not specified in requirement) ===
  parameter Real m_a = 1.0 "Actuated link mass [kg]";
  parameter Real I_a = 0.03 "Actuated link inertia about base pivot [kg.m2]";
  parameter Real m_p = 0.50 "Lumped end-point mass representing passive links [kg]";
  parameter Real grav = 9.81 "Gravitational acceleration [m/s2]";

  // === Contact parameters ===
  parameter Real k_c = 200000.0 "Contact stiffness [N/m]";
  parameter Real c_c = 2000.0 "Contact damping [N.s/m]";
  parameter Real mu_f = 0.70 "Friction coefficient [1]";
  parameter Real v_eps = 0.001 "Friction smoothing velocity [m/s]";

  // === Actuator parameters ===
  parameter Real tau_max = 27.4 "Maximum actuator torque magnitude [N.m]";

  // === Control parameters ===
  parameter Real F_base = 30.0 "Base desired normal contact force [N]";
  parameter Real F_dist = 9.0 "Disturbance force magnitude [N]";
  parameter Real Kpf = 50.0 "Force controller proportional gain";
  parameter Real Kif = 300.0 "Force controller integral gain";
  parameter Real Kpx = 600.0 "Position controller proportional gain (tangential)";
  parameter Real Kdx = 60.0 "Position controller derivative gain (tangential)";
  parameter Real Kpy = 800.0 "Approach controller proportional gain (normal)";
  parameter Real Kdy_app = 80.0 "Approach controller derivative gain (normal)";
  parameter Real x_des = 0.0 "Desired tangential position [m]";
  parameter Real int_lim = 50.0 "Force integral anti-windup limit [N.s]";

  // === Timing ===
  parameter Real T_total = 8.0 "Total simulation duration [s]";
  parameter Real Ts = 0.0125 "Controller sample period = 1/80 [s]";
  parameter Real T_dist_start = T_total / 3.0 "Disturbance start time [s]";
  parameter Real T_dist_end = 2.0 * T_total / 3.0 "Disturbance end time [s]";

  // === Continuous states ===
  Real q1(start = 1.570796326794897, fixed = true) "Actuated joint 1 angle [rad]";
  Real q2(start = 1.570796326794897, fixed = true) "Actuated joint 2 angle [rad]";
  Real q1_dot(start = 0.0, fixed = true) "Joint 1 angular velocity [rad/s]";
  Real q2_dot(start = 0.0, fixed = true) "Joint 2 angular velocity [rad/s]";

  // === Discrete controller states ===
  discrete Real force_integral(start = 0.0) "Force error integral [N.s]";
  discrete Real Fy_cmd(start = 0.0) "Endpoint normal force command [N]";
  discrete Real Fx_cmd(start = 0.0) "Endpoint tangential force command [N]";

  // === Forward kinematics ===
  Real B1x "Actuated link 1 end x [m]";
  Real B1y "Actuated link 1 end y [m]";
  Real B2x "Actuated link 2 end x [m]";
  Real B2y "Actuated link 2 end y [m]";
  Real dx_k "B2-B1 x component [m]";
  Real dy_k "B2-B1 y component [m]";
  Real d_k "Distance B1-B2 [m]";
  Real d_safe "Protected distance for division [m]";
  Real h2 "Squared passive-link height [m2]";
  Real h "Passive-link height [m]";
  Real h_safe "Protected height for division [m]";
  Real Px "End point x position [m]";
  Real Py "End point y position [m]";
  Real Px_dot "End point x velocity [m/s]";
  Real Py_dot "End point y velocity [m/s]";

  // === Jacobian ===
  Real dx_q1, dy_q1, dx_q2, dy_q2 "Partial derivatives of dx, dy";
  Real d_q1, d_q2 "Partial derivatives of d";
  Real h_q1, h_q2 "Partial derivatives of h";
  Real J11 "dPx/dq1";
  Real J12 "dPx/dq2";
  Real J21 "dPy/dq1";
  Real J22 "dPy/dq2";

  // === Contact ===
  Real delta "Penetration depth (positive = contact) [m]";
  Real Fn "Normal contact force [N]";
  Real Ft "Tangential friction force [N]";
  Boolean in_contact "Contact detected";
  Boolean locked "Contact locked (static friction)";

  // === Disturbance ===
  Real F_disturbance "External disturbance force on P in +y [N]";

  // === Mass matrix ===
  Real M11, M12, M21, M22 "Mass matrix elements [kg.m2]";
  Real detM "Mass matrix determinant [kg2.m4]";
  Real detM_safe "Protected determinant for division [kg2.m4]";

  // === Gravity torques ===
  Real G1 "Gravity torque on joint 1 [N.m]";
  Real G2 "Gravity torque on joint 2 [N.m]";

  // === Control torques ===
  Real tau1_unsat "Unsaturated actuator 1 torque command [N.m]";
  Real tau2_unsat "Unsaturated actuator 2 torque command [N.m]";
  Real tau1_sat "Saturated actuator 1 torque [N.m]";
  Real tau2_sat "Saturated actuator 2 torque [N.m]";

  // === Dynamics ===
  Real RHS1 "Right-hand side joint 1 [N.m]";
  Real RHS2 "Right-hand side joint 2 [N.m]";
  Real q1_ddot "Joint 1 angular acceleration [rad/s2]";
  Real q2_ddot "Joint 2 angular acceleration [rad/s2]";

  // === Monitoring outputs ===
  Real closure_error "Loop closure error [m]";
  Real tracking_error "Tangential tracking error [m]";
  Real contact_force_band "Force tracking error magnitude [N]";
  Real tangential_slip "Tangential slip speed [m/s]";
  Real F_desired "Continuous desired force for monitoring [N]";

equation
  // ===== Forward kinematics =====
  B1x = -bx + L1 * cos(q1);
  B1y = L1 * sin(q1);
  B2x = bx + L1 * cos(q2);
  B2y = L1 * sin(q2);

  dx_k = B2x - B1x;
  dy_k = B2y - B1y;
  d_k = sqrt(dx_k * dx_k + dy_k * dy_k);
  d_safe = max(d_k, 1.0e-4);
  h2 = L2 * L2 - d_k * d_k / 4.0;
  h = sqrt(max(h2, 0.0));
  h_safe = max(h, 1.0e-4);

  // End point P (upper assembly mode)
  Px = (B1x + B2x) / 2.0 - h * dy_k / d_safe;
  Py = (B1y + B2y) / 2.0 + h * dx_k / d_safe;

  // ===== Jacobian intermediate variables =====
  dx_q1 = L1 * sin(q1);
  dy_q1 = -L1 * cos(q1);
  dx_q2 = -L1 * sin(q2);
  dy_q2 = L1 * cos(q2);

  d_q1 = (dx_k * dx_q1 + dy_k * dy_q1) / d_safe;
  d_q2 = (dx_k * dx_q2 + dy_k * dy_q2) / d_safe;

  h_q1 = -(dx_k * dx_q1 + dy_k * dy_q1) / (4.0 * h_safe);
  h_q2 = -(dx_k * dx_q2 + dy_k * dy_q2) / (4.0 * h_safe);

  // ===== Jacobian =====
  J11 = -L1 * sin(q1) / 2.0
      - (h_q1 * dy_k + h * dy_q1) / d_safe
      + h * dy_k * d_q1 / (d_safe * d_safe);

  J12 = -L1 * sin(q2) / 2.0
      - (h_q2 * dy_k + h * dy_q2) / d_safe
      + h * dy_k * d_q2 / (d_safe * d_safe);

  J21 = L1 * cos(q1) / 2.0
      + (h_q1 * dx_k + h * dx_q1) / d_safe
      - h * dx_k * d_q1 / (d_safe * d_safe);

  J22 = L1 * cos(q2) / 2.0
      + (h_q2 * dx_k + h * dx_q2) / d_safe
      - h * dx_k * d_q2 / (d_safe * d_safe);

  // ===== Endpoint velocity =====
  Px_dot = J11 * q1_dot + J12 * q2_dot;
  Py_dot = J21 * q1_dot + J22 * q2_dot;

  // ===== Contact model =====
  delta = y_surface - Py;
  in_contact = delta > 0.0;
  Fn = if in_contact then max(k_c * delta - c_c * Py_dot, 0.0) else 0.0;
  Ft = if in_contact then -mu_f * Fn * tanh(Px_dot / v_eps) else 0.0;
  locked = in_contact and (abs(Px_dot) < v_eps);

  // ===== Disturbance (external force on end point in +y) =====
  F_disturbance = if (time >= T_dist_start and time <= T_dist_end) then F_dist else 0.0;
  F_desired = F_base;

  // ===== Mass matrix =====
  M11 = I_a + m_p * (J11 * J11 + J21 * J21);
  M22 = I_a + m_p * (J12 * J12 + J22 * J22);
  M12 = m_p * (J11 * J12 + J21 * J22);
  M21 = M12;
  detM = M11 * M22 - M12 * M21;
  detM_safe = max(detM, 1.0e-8);

  // ===== Gravity torques =====
  G1 = m_a * grav * (L1 / 2.0) * cos(q1) + m_p * grav * J21;
  G2 = m_a * grav * (L1 / 2.0) * cos(q2) + m_p * grav * J22;

  // ===== Control torques (gravity compensation + endpoint force command) =====
  tau1_unsat = J11 * Fx_cmd + J21 * Fy_cmd + G1;
  tau2_unsat = J12 * Fx_cmd + J22 * Fy_cmd + G2;
  tau1_sat = max(-tau_max, min(tau_max, tau1_unsat));
  tau2_sat = max(-tau_max, min(tau_max, tau2_unsat));

  // ===== Dynamics: M*q_ddot = tau_sat - G - J^T*[Ft, Fn + F_disturbance] =====
  RHS1 = tau1_sat - G1 - (J11 * Ft + J21 * (Fn + F_disturbance));
  RHS2 = tau2_sat - G2 - (J12 * Ft + J22 * (Fn + F_disturbance));

  q1_ddot = (M22 * RHS1 - M12 * RHS2) / detM_safe;
  q2_ddot = (M11 * RHS2 - M12 * RHS1) / detM_safe;

  // ===== State derivatives =====
  der(q1) = q1_dot;
  der(q2) = q2_dot;
  der(q1_dot) = q1_ddot;
  der(q2_dot) = q2_ddot;

  // ===== Monitoring =====
  closure_error = max(0.0, -h2);
  tracking_error = abs(Px - x_des);
  contact_force_band = abs(Fn - F_desired);
  tangential_slip = abs(Px_dot);

algorithm
  when sample(0, Ts) then
    // Hybrid position/force control at 80 Hz
    if (y_surface - Py) > 0.0 then
      // Contact: force control in normal direction (y)
      force_integral := pre(force_integral) + (F_base - Fn) * Ts;
      // Anti-windup clamping
      if force_integral > int_lim then
        force_integral := int_lim;
      elseif force_integral < -int_lim then
        force_integral := -int_lim;
      end if;
      Fy_cmd := -(Kpf * (F_base - Fn) + Kif * force_integral);
    else
      // No contact: position approach in normal direction (y)
      force_integral := 0.0;
      Fy_cmd := Kpy * (y_surface - Py) - Kdy_app * Py_dot;
    end if;

    // Position control in tangential direction (x) — always active
    Fx_cmd := Kpx * (x_des - Px) - Kdx * Px_dot;
  end when;

annotation(
  experiment(StartTime = 0, StopTime = 8.0, Tolerance = 1.0e-6, Interval = 0.0125),
  Documentation(info = "Five-bar parallel mechanism FiveBarPressA.
    Base pivots at +/-0.25 m. Actuated links 0.30 m, passive links 0.42 m.
    Hybrid position/force control at 80 Hz for 8 s.
    Contact: k=200 kN/m, c=2 kN.s/m, mu=0.70.
    Actuator torque limit 27.4 N.m per joint.
    9 N disturbance force applied during middle third (2.67-5.33 s).
    Inertial parameters (m_a, I_a, m_p) are design assumptions not specified in the requirement.")
);
end FiveBarPressA;