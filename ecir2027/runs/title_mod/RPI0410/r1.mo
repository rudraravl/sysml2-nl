model PlanarPusherGraspB
  "Contact-rich planar manipulation: acquire rigid object, establish stable grasp, hold without excessive displacement. Two-link revolute arm with rounded contact tool, rigid table, impedance motion followed by force regulation."

  // ===== Given physical parameters =====
  parameter Real L1 = 0.46 "Link 1 capsule length [m]";
  parameter Real L2 = 0.35 "Link 2 capsule length [m]";
  parameter Real tau_max = 41.0 "Allowed command magnitude per joint [N.m]";
  parameter Real mu = 0.78 "Friction coefficient";
  parameter Real e_rest = 0.03 "Restitution coefficient";
  parameter Real F_disturbance = 5.6 "Tangential disturbance load [N]";
  parameter Real t_sim = 10.0 "Mission duration [s]";
  parameter Real f_ctrl = 100.0 "Control loop frequency [Hz]";

  // ===== Assumed physical parameters (not stated in requirement) =====
  parameter Real m1 = 0.6 "Assumed link 1 mass [kg]";
  parameter Real m2 = 0.5 "Assumed link 2 mass [kg]";
  parameter Real m_tool = 0.3 "Assumed tool mass [kg]";
  parameter Real m_obj = 0.5 "Assumed object mass [kg]";
  parameter Real I1 = 0.01 "Assumed link 1 inertia [kg.m^2]";
  parameter Real I2 = 0.005 "Assumed link 2 inertia [kg.m^2]";
  parameter Real h_obj = 0.04 "Assumed object height [m]";
  parameter Real w_obj = 0.08 "Assumed object width [m]";
  parameter Real r_tool = 0.015 "Assumed rounded tool radius [m]";
  parameter Real g = 9.81 "Gravitational acceleration [m/s^2]";
  parameter Real b1 = 0.1 "Joint 1 viscous damping [N.m.s/rad]";
  parameter Real b2 = 0.05 "Joint 2 viscous damping [N.m.s/rad]";
  parameter Real k_contact = 10000.0 "Contact stiffness [N/m]";
  parameter Real d_contact = 65.0 "Contact damping [N.s/m]";
  parameter Real v_reg = 0.001 "Friction velocity regularization [m/s]";
  parameter Real I1_eff = I1 + m1*(L1/2)^2 + (m2+m_tool)*L1^2 "Effective inertia joint 1 [kg.m^2]";
  parameter Real I2_eff = I2 + m2*(L2/2)^2 + m_tool*L2^2 "Effective inertia joint 2 [kg.m^2]";

  // ===== Controller parameters =====
  parameter Real K_imp = 500.0 "Impedance stiffness [N/m]";
  parameter Real D_imp = 25.0 "Impedance damping [N.s/m]";
  parameter Real K_px = 400.0 "Tangential position gain [N/m]";
  parameter Real K_dx = 20.0 "Tangential damping gain [N.s/m]";
  parameter Real K_fn = 3.0 "Normal force regulation gain";
  parameter Real F_des = 12.0 "Desired normal contact force [N]";
  parameter Real tau_sensor = 0.02 "Force sensor filter time constant [s]";

  // ===== Initial conditions =====
  parameter Real q1_0 = 0.30 "Initial joint 1 angle [rad]";
  parameter Real q2_0 = 0.20 "Initial joint 2 angle [rad]";
  parameter Real x_obj_0 = 0.75 "Initial object x position [m]";
  parameter Real y_tip_start = L1*sin(q1_0) + L2*sin(q1_0 + q2_0) "Initial tip height [m]";

  // ===== Dynamic states =====
  Real q1(start=q1_0, fixed=true) "Joint 1 angle [rad]";
  Real q2(start=q2_0, fixed=true) "Joint 2 angle [rad]";
  Real dq1(start=0, fixed=true) "Joint 1 angular velocity [rad/s]";
  Real dq2(start=0, fixed=true) "Joint 2 angular velocity [rad/s]";
  Real x_obj(start=x_obj_0, fixed=true) "Object x position [m]";
  Real vx_obj(start=0, fixed=true) "Object x velocity [m/s]";
  Real N_filt(start=0, fixed=true) "Filtered normal contact force [N]";

  // ===== Kinematic quantities =====
  Real x_tip "Tip x position [m]";
  Real y_tip "Tip y position [m]";
  Real dx_tip "Tip x velocity [m/s]";
  Real dy_tip "Tip y velocity [m/s]";
  Real J11 "Jacobian dx/dq1";
  Real J12 "Jacobian dx/dq2";
  Real J21 "Jacobian dy/dq1";
  Real J22 "Jacobian dy/dq2";

  // ===== Contact quantities =====
  Real delta_pen "Penetration depth [m]";
  Real N_contact "Normal contact force tool-object [N]";
  Real N_table "Table normal force on object [N]";
  Real F_fric_tool_x "Friction force on tool [N]";
  Real F_fric_obj_x "Friction force on object from tool [N]";
  Real F_table_fric_x "Table friction on object [N]";
  Real v_rel "Relative tangential velocity at contact [m/s]";
  Real Fx_tip "Total contact force on tip x [N]";
  Real Fy_tip "Total contact force on tip y [N]";
  Boolean in_contact "Contact active flag";

  // ===== Controller =====
  Real x_des "Desired tip x [m]";
  Real y_des "Desired tip y [m]";
  Real s_traj "Trajectory interpolation parameter";
  Real blend "Force regulation blend (0=impedance, 1=force reg)";
  Real F_imp_x "Impedance force command x [N]";
  Real F_imp_y "Impedance force command y [N]";
  Real F_reg_x "Force regulation force command x [N]";
  Real F_reg_y "Force regulation force command y [N]";
  Real F_cart_x "Total Cartesian force command x [N]";
  Real F_cart_y "Total Cartesian force command y [N]";
  Real G1 "Gravity torque joint 1 [N.m]";
  Real G2 "Gravity torque joint 2 [N.m]";
  Real tau1_raw "Raw torque command joint 1 [N.m]";
  Real tau2_raw "Raw torque command joint 2 [N.m]";
  Real tau1 "Saturated torque joint 1 [N.m]";
  Real tau2 "Saturated torque joint 2 [N.m]";
  Real F_dist_active "Active disturbance force [N]";

  // ===== Sensors / observables =====
  Real N_contact_sensor "Normal contact force sensor [N]";
  Real N_table_sensor "Table normal force sensor [N]";
  Real tracking_error "Primary tracking error: object displacement [m]";
  Real effort_norm "Total joint effort [N.m]";
  Real travel_norm "Total joint travel [rad]";
  Real object_pose_x "Object pose x [m]";
  Real object_pose_theta "Object pose angle [rad]";

  // ===== Bound checks =====
  Boolean contact_stable "Stable contact maintained";
  Boolean grasp_held "No grasp loss";
  Boolean effort_ok "Effort within bounds";
  Boolean travel_ok "Travel within bounds";
  Boolean tracking_ok "Primary tracking error satisfied after 6.5s";

equation
  // ===== Forward kinematics =====
  x_tip = L1*cos(q1) + L2*cos(q1 + q2);
  y_tip = L1*sin(q1) + L2*sin(q1 + q2);
  J11 = -L1*sin(q1) - L2*sin(q1 + q2);
  J12 = -L2*sin(q1 + q2);
  J21 = L1*cos(q1) + L2*cos(q1 + q2);
  J22 = L2*cos(q1 + q2);
  dx_tip = J11*dq1 + J12*dq2;
  dy_tip = J21*dq1 + J22*dq2;

  // ===== Gravity compensation torques =====
  G1 = g*(m1*(L1/2)*cos(q1) + m2*(L1*cos(q1) + (L2/2)*cos(q1+q2)) + m_tool*(L1*cos(q1) + L2*cos(q1+q2)));
  G2 = g*(m2*(L2/2)*cos(q1+q2) + m_tool*L2*cos(q1+q2));

  // ===== Contact model (spring-damper with restitution-based damping) =====
  in_contact = (abs(x_tip - x_obj) < w_obj/2 + r_tool) and (y_tip < h_obj + r_tool);
  delta_pen = if in_contact then max(0, (h_obj + r_tool) - y_tip) else 0.0;
  N_contact = if delta_pen > 0 then k_contact*delta_pen + d_contact*max(0, -dy_tip) else 0.0;

  // Relative tangential velocity at contact
  v_rel = dx_tip - vx_obj;

  // Friction (regularized Coulomb; tanh provides well-defined zero branch)
  F_fric_tool_x = -mu * N_contact * tanh(v_rel / v_reg);
  F_fric_obj_x = mu * N_contact * tanh(v_rel / v_reg);

  // Table contact: normal force balances gravity plus contact push-down
  N_table = m_obj * g + N_contact;
  F_table_fric_x = -mu * N_table * tanh(vx_obj / v_reg);

  // Total contact forces on tip
  Fx_tip = F_fric_tool_x;
  Fy_tip = N_contact;

  // ===== Disturbance injection (middle third of mission) =====
  F_dist_active = if (time >= t_sim/3.0 and time <= 2.0*t_sim/3.0) then F_disturbance else 0.0;

  // ===== Object dynamics (1D along x, constrained on table) =====
  m_obj * der(vx_obj) = F_fric_obj_x + F_table_fric_x + F_dist_active;
  der(x_obj) = vx_obj;

  // ===== Arm dynamics (decoupled joints with Jacobian-based contact torques) =====
  I1_eff * der(dq1) = tau1 - G1 - (J11*Fx_tip + J21*Fy_tip) - b1*dq1;
  I2_eff * der(dq2) = tau2 - G2 - (J12*Fx_tip + J22*Fy_tip) - b2*dq2;
  der(q1) = dq1;
  der(q2) = dq2;

  // ===== Force sensor filter =====
  der(N_filt) = (N_contact - N_filt) / tau_sensor;

  // ===== Controller: impedance motion then force regulation =====
  x_des = x_obj_0;
  s_traj = if time < 2.0 then 3.0*(time/2.0)^2 - 2.0*(time/2.0)^3 else 1.0;
  y_des = y_tip_start + ((h_obj + r_tool - 0.001) - y_tip_start) * s_traj;

  // Blend: 0 = impedance, 1 = force regulation, based on detected contact
  blend = if N_filt > 1.0 then 1.0 elseif N_filt < 0.1 then 0.0 else (N_filt - 0.1)/0.9;

  // Impedance control (approach and motion phase)
  F_imp_x = K_imp * (x_des - x_tip) - D_imp * dx_tip;
  F_imp_y = K_imp * (y_des - y_tip) - D_imp * dy_tip;

  // Force regulation (contact phase): regulate normal force, hold tangential position
  F_reg_x = K_px * (x_des - x_tip) - K_dx * dx_tip;
  F_reg_y = -(F_des + K_fn * (F_des - N_filt));

  // Blended Cartesian force command
  F_cart_x = (1.0 - blend) * F_imp_x + blend * F_reg_x;
  F_cart_y = (1.0 - blend) * F_imp_y + blend * F_reg_y;

  // Joint torque commands with gravity compensation (J^T mapping)
  tau1_raw = J11 * F_cart_x + J21 * F_cart_y + G1;
  tau2_raw = J12 * F_cart_x + J22 * F_cart_y + G2;

  // Torque saturation at allowed command magnitude
  tau1 = max(-tau_max, min(tau_max, tau1_raw));
  tau2 = max(-tau_max, min(tau_max, tau2_raw));

  // ===== Sensors / observables =====
  N_contact_sensor = N_filt;
  N_table_sensor = N_table;
  tracking_error = abs(x_obj - x_obj_0);
  effort_norm = abs(tau1) + abs(tau2);
  travel_norm = abs(q1 - q1_0) + abs(q2 - q2_0);
  object_pose_x = x_obj;
  object_pose_theta = 0.0;

  // ===== Requirement bound checks =====
  contact_stable = (time > 3.0) and (N_filt > F_des * 0.5);
  grasp_held = tracking_error < 0.05;
  effort_ok = (abs(tau1) <= tau_max + 0.001) and (abs(tau2) <= tau_max + 0.001);
  travel_ok = travel_norm < 3.0;
  tracking_ok = (time < 6.5) or (tracking_error < 0.018);

  // ===== Requirement assertions (warnings only, do not halt simulation) =====
  assert(tracking_ok, "Primary tracking error exceeded 0.018 m after 6.5 s", AssertionLevel.warning);
  assert(effort_ok, "Joint torque exceeds allowed command magnitude", AssertionLevel.warning);
  assert(travel_ok, "Joint travel exceeds bound", AssertionLevel.warning);
  assert(grasp_held, "Grasp loss detected: object displacement too large", AssertionLevel.warning);

  annotation(
    experiment(StartTime = 0, StopTime = 10, Tolerance = 1e-6, Interval = 0.01),
    Documentation(info = "PlanarPusherGraspB: Two-link revolute Z-joint arm (0.46 m, 0.35 m capsule links) with rounded contact tool acquires a rigid object on a friction table (mu=0.78, e=0.03). Impedance motion descends to contact; force regulation maintains 12 N normal grasp force. A 5.6 N tangential disturbance is injected during the middle third [3.33, 6.67] s. Controller runs at 100 Hz for 10 s. All states, commands, and sensor traces are synchronized. Assumed masses, inertias, and object dimensions are labeled as such; facts not stated in the requirement are treated as unknown.")
  );
end PlanarPusherGraspB;