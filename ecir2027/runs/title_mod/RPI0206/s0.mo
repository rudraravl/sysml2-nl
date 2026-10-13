model RailArmCarryB
  "Fixed-base articulated manipulator: lift and reposition rigid tool payload preserving end-effector orientation";

  // ===== Physical parameters (specified by request) =====
  parameter Real L_rail = 1.4 "Rail length [m]";
  parameter Real m_carriage = 18.0 "Carriage mass [kg]";
  parameter Real L1 = 0.46 "First link length [m]";
  parameter Real L2 = 0.31 "Second link length [m]";
  parameter Real m_payload = 8.4 "Disturbance payload mass [kg]";
  parameter Real joint_limit = 1.5 "Joint angular limit magnitude [rad]";
  parameter Real tau_max = 69.7 "Max rotary actuator torque magnitude [N.m]";
  parameter Real F_max = 800.0 "Max linear actuator force magnitude [N]";
  parameter Real wrist_force_limit = 60.0 "Wrist force limit [N]";
  parameter Real tracking_threshold = 0.054 "Primary tracking error threshold after 6.5 s [rad or m]";
  parameter Real Ts = 0.01 "Control sampling period [s] (100 Hz)";
  parameter Real T_sim = 10.0 "Mission duration [s]";
  parameter Real g_acc = 9.81 "Gravitational acceleration [m/s2]";

  // ===== Physical parameters (assumed — not specified in request) =====
  parameter Real m1 = 2.5 "First link mass [kg] — assumed";
  parameter Real m2 = 1.5 "Second link mass [kg] — assumed";
  parameter Real I1 = m1 * L1^2 / 12.0 "First link inertia about COM [kg.m2]";
  parameter Real I2 = m2 * L2^2 / 12.0 "Second link inertia about COM [kg.m2]";
  parameter Real r1c = L1 / 2.0 "First link COM distance [m]";
  parameter Real r2c = L2 / 2.0 "Second link COM distance [m]";

  // ===== Controller gains =====
  parameter Real Kp_x = 300.0 "Carriage position proportional gain";
  parameter Real Kd_x = 40.0 "Carriage position derivative gain";
  parameter Real Kp_q = 500.0 "Joint proportional gain";
  parameter Real Kd_q = 50.0 "Joint derivative gain";
  parameter Real Kf_wrist = 0.5 "Wrist force correction gain";
  parameter Real wrist_corr_max = 20.0 "Max wrist force correction magnitude";

  // ===== Trajectory parameters =====
  parameter Real T_rise = 3.0 "Trajectory rise time [s]";
  parameter Real x0_init = 0.7 "Initial carriage position [m]";
  parameter Real xf_final = 0.3 "Final carriage position [m]";
  parameter Real q1_init = 0.0 "Initial joint 1 angle [rad]";
  parameter Real q1_final = 0.4 "Final joint 1 angle [rad]";
  parameter Real phi_des = 0.0 "Desired end-effector orientation [rad]";

  // ===== Collision parameters (assumed — not specified in request) =====
  parameter Real y_floor = 0.0 "Floor height [m]";
  parameter Real y_table = 0.25 "Table top height [m]";
  parameter Real x_table_min = 0.55 "Table left edge X [m]";
  parameter Real x_table_max = 0.85 "Table right edge X [m]";
  parameter Real k_coll = 50000.0 "Collision stiffness [N/m]";
  parameter Real d_coll = 500.0 "Collision damping [N.s/m]";
  parameter Real coll_margin = 0.005 "Collision penetration margin [m]";
  parameter Real k_joint = 1000.0 "Joint limit stiffness [N.m/rad]";
  parameter Real d_joint = 10.0 "Joint limit damping [N.m.s/rad]";
  parameter Real joint_margin = 0.05 "Joint limit activation margin [rad]";

  // ===== States =====
  Real x(start = x0_init, fixed = true) "Carriage position along rail [m]";
  Real vx(start = 0.0, fixed = true) "Carriage velocity [m/s]";
  Real q1(start = q1_init, fixed = true) "Joint 1 angle from vertical [rad]";
  Real dq1(start = 0.0, fixed = true) "Joint 1 velocity [rad/s]";
  Real q2(start = -q1_init + phi_des, fixed = true) "Joint 2 angle [rad]";
  Real dq2(start = 0.0, fixed = true) "Joint 2 velocity [rad/s]";

  // ===== Actuator commands =====
  Real F_cmd "Unsaturated carriage force command [N]";
  Real tau1_cmd "Unsaturated joint 1 torque command [N.m]";
  Real tau2_cmd "Unsaturated joint 2 torque command [N.m]";
  discrete Real F_cmd_d(start = 0.0) "Discrete carriage force command [N]";
  discrete Real tau1_cmd_d(start = 0.0) "Discrete joint 1 torque command [N.m]";
  discrete Real tau2_cmd_d(start = 0.0) "Discrete joint 2 torque command [N.m]";
  Real F_sat "Saturated carriage force [N]";
  Real tau1_sat "Saturated joint 1 torque [N.m]";
  Real tau2_sat "Saturated joint 2 torque [N.m]";

  // ===== Desired trajectory =====
  Real s_traj "Trajectory parameter [0..1]";
  Real ds_traj "Trajectory parameter derivative [1/s]";
  Real dds_traj "Trajectory parameter 2nd derivative [1/s2]";
  Real x_des "Desired carriage position [m]";
  Real vx_des "Desired carriage velocity [m/s]";
  Real ax_des "Desired carriage acceleration [m/s2]";
  Real q1_des "Desired joint 1 angle [rad]";
  Real dq1_des "Desired joint 1 velocity [rad/s]";
  Real ddq1_des "Desired joint 1 acceleration [rad/s2]";
  Real q2_des "Desired joint 2 angle [rad]";
  Real dq2_des "Desired joint 2 velocity [rad/s]";
  Real ddq2_des "Desired joint 2 acceleration [rad/s2]";

  // ===== End effector =====
  Real x_ee "End-effector X position [m]";
  Real y_ee "End-effector Y position [m]";
  Real vy_ee "End-effector Y velocity [m/s]";
  Real phi_ee "End-effector orientation [rad]";
  Real x_ee_des "Desired EE X position [m]";
  Real y_ee_des "Desired EE Y position [m]";
  Real phi_ee_des "Desired EE orientation [rad]";

  // ===== Wrist wrench sensor (six-axis) =====
  Real Fx_wrist "Wrist force X [N]";
  Real Fy_wrist "Wrist force Y [N]";
  Real Fz_wrist "Wrist force Z [N]";
  Real Tx_wrist "Wrist torque X [N.m]";
  Real Ty_wrist "Wrist torque Y [N.m]";
  Real Tz_wrist "Wrist torque Z [N.m]";
  Real F_wrist_mag "Wrist force magnitude [N]";

  // ===== Control errors =====
  Real e_x "Carriage position error [m]";
  Real e_vx "Carriage velocity error [m/s]";
  Real e_q1 "Joint 1 error [rad]";
  Real e_dq1 "Joint 1 velocity error [rad/s]";
  Real e_q2 "Joint 2 error [rad]";
  Real e_dq2 "Joint 2 velocity error [rad/s]";

  // ===== Tracking error =====
  Real tracking_error "Primary tracking error [rad or m]";
  Real tracking_error_check "Tracking error after 6.5 s [rad or m]";

  // ===== Payload disturbance =====
  Boolean payload_active "True during middle third of mission";
  Real m_p "Effective payload mass [kg]";

  // ===== Collision and joint limit forces =====
  Real F_floor_y "Floor collision force at EE [N]";
  Real F_table_y "Table collision force at EE [N]";
  Real F_coll_y "Total vertical collision force at EE [N]";
  Real Q_coll_x "Generalized collision force on x [N]";
  Real Q_coll_q1 "Generalized collision force on q1 [N.m]";
  Real Q_coll_q2 "Generalized collision force on q2 [N.m]";
  Real F_joint1_limit "Joint 1 limit resisting torque [N.m]";
  Real F_joint2_limit "Joint 2 limit resisting torque [N.m]";

  // ===== Dynamics terms =====
  Real c1q "cos(q1)";
  Real s1q "sin(q1)";
  Real c2q "cos(q2)";
  Real s2q "sin(q2)";
  Real c12q "cos(q1+q2)";
  Real s12q "sin(q1+q2)";
  Real alpha_param "Mass coupling alpha [kg.m]";
  Real beta_param "Mass coupling beta [kg.m]";
  Real gamma_param "Mass coupling gamma [kg.m2]";
  Real M11, M12, M13, M21, M22, M23, M31, M32, M33;
  Real Cv1, Cv2, Cv3;
  Real Gv1, Gv2, Gv3;
  Real ax "Carriage acceleration [m/s2]";
  Real ddq1 "Joint 1 acceleration [rad/s2]";
  Real ddq2 "Joint 2 acceleration [rad/s2]";

  // ===== Wrist force correction (bounded) =====
  Real wrist_corr_F "Wrist force correction for carriage [N]";
  Real wrist_corr_t1 "Wrist force correction for joint 1 [N.m]";
  Real wrist_corr_t2 "Wrist force correction for joint 2 [N.m]";

  // ===== Requirement monitors =====
  Real joint1_bound_check "Joint 1 bound [rad]";
  Real joint2_bound_check "Joint 2 bound [rad]";
  Real effort_F_check "Force effort [N]";
  Real effort_t1_check "Torque 1 effort [N.m]";
  Real effort_t2_check "Torque 2 effort [N.m]";
  Real wrist_force_check "Wrist force [N]";

equation

  // ===== Trigonometric shorthand =====
  c1q = cos(q1);
  s1q = sin(q1);
  c2q = cos(q2);
  s2q = sin(q2);
  c12q = cos(q1 + q2);
  s12q = sin(q1 + q2);

  // ===== Payload disturbance: active during middle third =====
  payload_active = (time >= T_sim / 3.0) and (time <= 2.0 * T_sim / 3.0);
  m_p = if payload_active then m_payload else 0.0;

  // ===== Trajectory generation (smooth cosine profile) =====
  // Preserves end-effector orientation: q1_des + q2_des = phi_des = const
  s_traj = if time < T_rise then 0.5 * (1.0 - cos(Modelica.Constants.pi * time / T_rise)) else 1.0;
  ds_traj = if time < T_rise then 0.5 * (Modelica.Constants.pi / T_rise) * sin(Modelica.Constants.pi * time / T_rise) else 0.0;
  dds_traj = if time < T_rise then 0.5 * (Modelica.Constants.pi / T_rise)^2 * cos(Modelica.Constants.pi * time / T_rise) else 0.0;

  x_des = x0_init + s_traj * (xf_final - x0_init);
  vx_des = ds_traj * (xf_final - x0_init);
  ax_des = dds_traj * (xf_final - x0_init);
  q1_des = q1_init + s_traj * (q1_final - q1_init);
  dq1_des = ds_traj * (q1_final - q1_init);
  ddq1_des = dds_traj * (q1_final - q1_init);
  q2_des = phi_des - q1_des;
  dq2_des = -dq1_des;
  ddq2_des = -ddq1_des;

  // ===== End-effector kinematics =====
  x_ee = x + L1 * s1q + L2 * s12q;
  y_ee = L1 * c1q + L2 * c12q;
  vy_ee = -L1 * s1q * dq1 - L2 * s12q * (dq1 + dq2);
  phi_ee = q1 + q2;
  x_ee_des = x_des + L1 * sin(q1_des) + L2 * sin(q1_des + q2_des);
  y_ee_des = L1 * cos(q1_des) + L2 * cos(q1_des + q2_des);
  phi_ee_des = q1_des + q2_des;

  // ===== Mass matrix parameters =====
  alpha_param = m1 * r1c + m2 * L1 + m_p * L1;
  beta_param = m2 * r2c + m_p * L2;
  gamma_param = m2 * L1 * r2c + m_p * L1 * L2;

  // ===== Mass matrix (3x3 for [x, q1, q2]) =====
  M11 = m_carriage + m1 + m2 + m_p;
  M12 = alpha_param * c1q + beta_param * c12q;
  M13 = beta_param * c12q;
  M21 = M12;
  M22 = I1 + m1 * r1c^2 + m2 * L1^2 + I2 + m2 * r2c^2 + m_p * L1^2 + m_p * L2^2 + 2.0 * gamma_param * c2q;
  M23 = I2 + m2 * r2c^2 + m_p * L2^2 + gamma_param * c2q;
  M31 = M13;
  M32 = M23;
  M33 = I2 + m2 * r2c^2 + m_p * L2^2;

  // ===== Coriolis and centrifugal terms =====
  Cv1 = -alpha_param * s1q * vx * dq1 - beta_param * s12q * vx * (dq1 + dq2) - beta_param * s12q * (dq1 + dq2)^2;
  Cv2 = -0.5 * alpha_param * s1q * vx^2 - 0.5 * beta_param * s12q * vx^2 - gamma_param * s2q * (dq1 + dq2)^2;
  Cv3 = -0.5 * beta_param * s12q * vx^2 + beta_param * s12q * vx * dq1 + gamma_param * s2q * dq1^2;

  // ===== Gravity terms =====
  Gv1 = 0.0;
  Gv2 = -alpha_param * g_acc * s1q - beta_param * g_acc * s12q;
  Gv3 = -beta_param * g_acc * s12q;

  // ===== Wrist wrench sensor =====
  // Measures force at wrist due to payload dynamics (including gravity)
  Fx_wrist = m_p * (ax + L1 * c1q * ddq1 - L1 * s1q * dq1^2 + L2 * c12q * (ddq1 + ddq2) - L2 * s12q * (dq1 + dq2)^2);
  Fy_wrist = m_p * (-L1 * s1q * ddq1 - L1 * c1q * dq1^2 - L2 * s12q * (ddq1 + ddq2) - L2 * c12q * (dq1 + dq2)^2 + g_acc);
  Fz_wrist = 0.0;
  Tx_wrist = 0.0;
  Ty_wrist = 0.0;
  Tz_wrist = 0.0;
  // Zero-error-safe magnitude computation
  F_wrist_mag = if (Fx_wrist^2 + Fy_wrist^2) > 1e-12 then sqrt(Fx_wrist^2 + Fy_wrist^2) else 0.0;

  // ===== Bounded wrist-force correction via Jacobian transpose =====
  wrist_corr_F = max(-wrist_corr_max, min(wrist_corr_max, Kf_wrist * Fx_wrist));
  wrist_corr_t1 = max(-wrist_corr_max, min(wrist_corr_max, Kf_wrist * (L1 * c1q * Fx_wrist - L1 * s1q * Fy_wrist)));
  wrist_corr_t2 = max(-wrist_corr_max, min(wrist_corr_max, Kf_wrist * (L2 * c12q * Fx_wrist - L2 * s12q * Fy_wrist)));

  // ===== Control errors =====
  e_x = x_des - x;
  e_vx = vx_des - vx;
  e_q1 = q1_des - q1;
  e_dq1 = dq1_des - dq1;
  e_q2 = q2_des - q2;
  e_dq2 = dq2_des - dq2;

  // ===== Computed-torque control (continuous, sampled at 100 Hz) =====
  F_cmd = M11 * ax_des + M12 * ddq1_des + M13 * ddq2_des + Cv1 + Gv1 + Kp_x * e_x + Kd_x * e_vx + wrist_corr_F;
  tau1_cmd = M21 * ax_des + M22 * ddq1_des + M23 * ddq2_des + Cv2 + Gv2 + Kp_q * e_q1 + Kd_q * e_dq1 + wrist_corr_t1;
  tau2_cmd = M31 * ax_des + M32 * ddq1_des + M33 * ddq2_des + Cv3 + Gv3 + Kp_q * e_q2 + Kd_q * e_dq2 + wrist_corr_t2;

  // ===== Discrete control update at 100 Hz (zero-order hold) =====
  when sample(0, Ts) then
    F_cmd_d = F_cmd;
    tau1_cmd_d = tau1_cmd;
    tau2_cmd_d = tau2_cmd;
  end when;

  // ===== Actuator saturation (effort bounds) =====
  F_sat = max(-F_max, min(F_max, F_cmd_d));
  tau1_sat = max(-tau_max, min(tau_max, tau1_cmd_d));
  tau2_sat = max(-tau_max, min(tau_max, tau2_cmd_d));

  // ===== Collision: floor (rigid, spring-damper unilateral) =====
  F_floor_y = if y_ee < y_floor + coll_margin then
      -k_coll * (y_ee - y_floor - coll_margin) - d_coll * min(vy_ee, 0.0)
    else 0.0;

  // ===== Collision: table (collision-enabled fixed surface) =====
  F_table_y = if (x_ee > x_table_min and x_ee < x_table_max and
                  y_ee < y_table + coll_margin and y_ee > y_table - 0.1) then
      -k_coll * (y_ee - y_table - coll_margin) - d_coll * min(vy_ee, 0.0)
    else 0.0;

  F_coll_y = F_floor_y + F_table_y;

  // ===== Map collision force to generalized forces (Jacobian transpose) =====
  Q_coll_x = 0.0;
  Q_coll_q1 = -L1 * s1q * F_coll_y;
  Q_coll_q2 = -L2 * s12q * F_coll_y;

  // ===== Joint limits (spring-damper hard stops, +/- 1.5 rad) =====
  F_joint1_limit = if q1 > joint_limit - joint_margin then
      k_joint * (q1 - (joint_limit - joint_margin)) + d_joint * max(dq1, 0.0)
    else if q1 < -(joint_limit - joint_margin) then
      k_joint * (q1 + (joint_limit - joint_margin)) + d_joint * min(dq1, 0.0)
    else 0.0;

  F_joint2_limit = if q2 > joint_limit - joint_margin then
      k_joint * (q2 - (joint_limit - joint_margin)) + d_joint * max(dq2, 0.0)
    else if q2 < -(joint_limit - joint_margin) then
      k_joint * (q2 + (joint_limit - joint_margin)) + d_joint * min(dq2, 0.0)
    else 0.0;

  // ===== Equations of motion: M*qdd + C + G + joint_limit = tau + Q_coll =====
  M11 * ax + M12 * ddq1 + M13 * ddq2 + Cv1 + Gv1 = F_sat + Q_coll_x;
  M21 * ax + M22 * ddq1 + M23 * ddq2 + Cv2 + Gv2 + F_joint1_limit = tau1_sat + Q_coll_q1;
  M31 * ax + M32 * ddq1 + M33 * ddq2 + Cv3 + Gv3 + F_joint2_limit = tau2_sat + Q_coll_q2;

  // ===== State derivatives =====
  der(x) = vx;
  der(vx) = ax;
  der(q1) = dq1;
  der(dq1) = ddq1;
  der(q2) = dq2;
  der(dq2) = ddq2;

  // ===== Tracking error (primary: max of position and joint errors) =====
  tracking_error = max(abs(e_x), max(abs(e_q1), abs(e_q2)));
  tracking_error_check = if time >= 6.5 then tracking_error else 0.0;

  // ===== Requirement monitors (synchronized traces) =====
  joint1_bound_check = abs(q1);
  joint2_bound_check = abs(q2);
  effort_F_check = abs(F_sat);
  effort_t1_check = abs(tau1_sat);
  effort_t2_check = abs(tau2_sat);
  wrist_force_check = F_wrist_mag;

  // Note: The 8.4 kg payload static weight is ~82.4 N, which exceeds the
  // 60 N wrist force limit. The bounded wrist-force correction mitigates
  // dynamic forces, but the static component may violate the constraint.
  // This tension is noted but not resolved without additional facts.
  //
  // No NaN or infinite values are expected: all denominators have zero-error
  // branches, the mass matrix is positive definite, and all parameters are
  // bound. Link masses (m1, m2), inertias, and collision parameters are
  // assumed values clearly labeled above.

end RailArmCarryB;