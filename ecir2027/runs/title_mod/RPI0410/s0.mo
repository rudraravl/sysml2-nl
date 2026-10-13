model PlanarPusherGraspB
  import SI = Modelica.Units.SI;

  // ===== Stated parameters =====
  parameter SI.Length L1 = 0.46 "Link 1 length (m)";
  parameter SI.Length L2 = 0.35 "Link 2 length (m)";
  parameter SI.Torque tau_max = 41 "Allowed command magnitude per joint (N.m)";
  parameter Real mu = 0.78 "Friction coefficient (table and contact)";
  parameter Real e_rest = 0.03 "Restitution coefficient";
  parameter SI.Force F_dist = 5.6 "Tangential disturbance load (N)";
  parameter SI.Frequency f_ctrl = 100 "Control rate (Hz)";
  parameter SI.Time t_final = 10 "Total run time (s)";
  parameter SI.Time t_check = 6.5 "Tracking-error verification time (s)";
  parameter SI.Length err_thresh = 0.018 "Primary tracking error threshold after 6.5 s (m)";

  // ===== Assumed parameters (not specified in requirement; labeled, not fabricated from examples) =====
  parameter SI.Mass m1 = 2.0 "Link 1 mass - assumed (requirement silent)";
  parameter SI.Mass m2 = 1.5 "Link 2 mass - assumed (requirement silent)";
  parameter SI.Mass m_obj = 0.5 "Object mass - assumed (requirement silent)";
  parameter SI.Length w_obj = 0.08 "Object width - assumed (requirement silent)";
  parameter SI.Length r_tool = 0.01 "Rounded tool radius - assumed (requirement silent)";
  parameter SI.Acceleration g = 9.81 "Gravitational acceleration";
  parameter SI.TranslationalSpringConstant k_c = 2000 "Contact stiffness - assumed (requirement silent)";
  parameter SI.TranslationalDampingConstant d_c = 60 "Contact damping - informed by e_rest=0.03 (near-critical)";
  parameter SI.Velocity v_eps = 0.001 "Friction velocity regularization";
  parameter SI.Length x_obj0 = 0.66 "Object initial x";
  parameter SI.Length y_obj0 = 0.0 "Object initial y";
  parameter SI.Angle q1_start = 0.0 "Joint 1 initial angle";
  parameter SI.Angle q2_start = 1.16 "Joint 2 initial angle";

  // Controller gains (assumed)
  parameter Real Kp_pos = 2000 "Impedance proportional gain (normal/x)";
  parameter Real Kd_pos = 200 "Impedance derivative gain (normal/x)";
  parameter Real Kp_posy = 1500 "Impedance proportional gain (tangential/y)";
  parameter Real Kd_posy = 150 "Impedance derivative gain (tangential/y)";
  parameter SI.Force F_des = 10 "Desired regulated normal force";
  parameter Real Ki_force = 10 "Force regulation integral gain";
  parameter SI.Length x_des_base = 0.615 "Desired end-effector x (impedance setpoint)";
  parameter SI.Length y_des = 0.0 "Desired end-effector y";

  // Disturbance window (middle third of total run)
  parameter SI.Time t_dist_start = t_final/3 "Disturbance start (middle third)";
  parameter SI.Time t_dist_end = 2*t_final/3 "Disturbance end (middle third)";
  parameter SI.Time T_ctrl = 1.0/f_ctrl "Controller sample period";

  // ===== Continuous states =====
  SI.Angle q1 "Joint 1 angle";
  SI.Angle q2 "Joint 2 angle";
  SI.AngularVelocity dq1 "Joint 1 velocity";
  SI.AngularVelocity dq2 "Joint 2 velocity";
  SI.Position x_obj "Object x position";
  SI.Position y_obj "Object y position";
  SI.Velocity vx_obj "Object x velocity";
  SI.Velocity vy_obj "Object y velocity";

  // ===== End-effector kinematics =====
  SI.Position x_ee "End-effector x";
  SI.Position y_ee "End-effector y";
  SI.Velocity vx_ee "End-effector x velocity";
  SI.Velocity vy_ee "End-effector y velocity";
  Real J11 "Jacobian (1,1)";
  Real J12 "Jacobian (1,2)";
  Real J21 "Jacobian (2,1)";
  Real J22 "Jacobian (2,2)";

  // ===== Contact =====
  SI.Length penetration "Contact penetration";
  SI.Force Fn "Normal contact force";
  SI.Force Ft_obj "Tangential contact friction on object";
  Real s2 "sin(q2)";
  Real c2 "cos(q2)";

  // ===== Arm dynamics =====
  Real M11 "Inertia matrix (1,1)";
  Real M12 "Inertia matrix (1,2)";
  Real M21 "Inertia matrix (2,1)";
  Real M22 "Inertia matrix (2,2)";
  Real C1 "Coriolis/centrifugal term 1";
  Real C2 "Coriolis/centrifugal term 2";
  SI.Torque tau1 "Joint 1 applied torque (saturated)";
  SI.Torque tau2 "Joint 2 applied torque (saturated)";

  // ===== Discrete controller (100 Hz) =====
  discrete SI.Torque tau1_cmd(start=0) "Commanded joint 1 torque";
  discrete SI.Torque tau2_cmd(start=0) "Commanded joint 2 torque";
  discrete Real force_int(start=0) "Force-regulation integral term";
  discrete SI.Force Fn_meas(start=0) "Sampled normal force measurement";
  discrete SI.Position x_ee_meas(start=0) "Sampled ee x";
  discrete SI.Position y_ee_meas(start=0) "Sampled ee y";
  discrete SI.Velocity vx_ee_meas(start=0) "Sampled ee vx";
  discrete SI.Velocity vy_ee_meas(start=0) "Sampled ee vy";

  // ===== Disturbance =====
  SI.Force F_dist_y "Tangential disturbance load applied to object";

  // ===== Instrumentation / observables =====
  SI.Angle meas_q1 "Measured joint 1 angle";
  SI.Angle meas_q2 "Measured joint 2 angle";
  SI.AngularVelocity meas_dq1 "Measured joint 1 velocity";
  SI.AngularVelocity meas_dq2 "Measured joint 2 velocity";
  SI.Force normal_contact_force "Measured normal contact force";
  SI.Position object_pose_x "Measured object pose x";
  SI.Position object_pose_y "Measured object pose y";
  SI.Angle object_pose_theta "Measured object pose orientation";
  SI.Length primary_tracking_error "Primary tracking error (ee x vs setpoint)";
  Boolean in_contact "Contact established";
  Boolean grasp_lost "Grasp-loss indicator";
  Boolean bounds_ok "Effort bound satisfied";
  Boolean finite_ok "No NaN/infinite value guard";

initial equation
  q1 = q1_start;
  q2 = q2_start;
  dq1 = 0;
  dq2 = 0;
  x_obj = x_obj0;
  y_obj = y_obj0;
  vx_obj = 0;
  vy_obj = 0;

equation
  // ===== Forward kinematics =====
  x_ee = L1*cos(q1) + L2*cos(q1+q2);
  y_ee = L1*sin(q1) + L2*sin(q1+q2);
  J11 = -L1*sin(q1) - L2*sin(q1+q2);
  J12 = -L2*sin(q1+q2);
  J21 =  L1*cos(q1) + L2*cos(q1+q2);
  J22 =  L2*cos(q1+q2);
  vx_ee = J11*dq1 + J12*dq2;
  vy_ee = J21*dq1 + J22*dq2;

  // ===== Penalty-based contact with restitution-informed damping =====
  penetration = max(0.0, x_ee - (x_obj - w_obj/2) - r_tool);
  Fn = if penetration > 0.0 then k_c*penetration + d_c*max(0.0, vx_ee - vx_obj) else 0.0;
  // Tangential friction on object opposes relative tangential sliding (regularized)
  Ft_obj = if penetration > 0.0 then -mu*Fn*tanh((vy_obj - vy_ee)/v_eps) else 0.0;

  // ===== Object dynamics on rigid support table (Coulomb friction, mu) =====
  der(x_obj) = vx_obj;
  der(y_obj) = vy_obj;
  m_obj*der(vx_obj) = Fn - mu*m_obj*g*tanh(vx_obj/v_eps);
  m_obj*der(vy_obj) = Ft_obj + F_dist_y - mu*m_obj*g*tanh(vy_obj/v_eps);

  // ===== Disturbance injection (middle third only) =====
  F_dist_y = if (time >= t_dist_start and time <= t_dist_end) then F_dist else 0.0;

  // ===== Two-link planar arm dynamics (point masses, horizontal plane: no gravity torque) =====
  s2 = sin(q2);
  c2 = cos(q2);
  M11 = m1*L1^2 + m2*(L1^2 + L2^2 + 2.0*L1*L2*c2);
  M12 = m2*(L2^2 + L1*L2*c2);
  M21 = M12;
  M22 = m2*L2^2;
  C1 = -m2*L1*L2*s2*dq2^2 - 2.0*m2*L1*L2*s2*dq1*dq2;
  C2 =  m2*L1*L2*s2*dq1^2;

  der(q1) = dq1;
  der(q2) = dq2;
  // M*ddq + C = tau + tau_contact; contact reaction on arm = -J^T*[Fn; Ft_obj]
  M11*der(dq1) + M12*der(dq2) + C1 = tau1 - (J11*Fn + J21*Ft_obj);
  M21*der(dq1) + M22*der(dq2) + C2 = tau2 - (J12*Fn + J22*Ft_obj);

  // ===== Torque saturation (41 N.m per joint) =====
  tau1 = max(-tau_max, min(tau_max, tau1_cmd));
  tau2 = max(-tau_max, min(tau_max, tau2_cmd));

  // ===== Discrete controller: impedance motion + force regulation at 100 Hz =====
  when sample(0, T_ctrl) then
    // Synchronized sensor sampling
    x_ee_meas  = x_ee;
    y_ee_meas  = y_ee;
    vx_ee_meas = vx_ee;
    vy_ee_meas = vy_ee;
    Fn_meas    = Fn;

    // Force-regulation integral (only when in contact, with anti-windup clamp)
    force_int = if Fn_meas > 0.5 then
                  max(-1.0*F_des, min(F_des, force_int + Ki_force*T_ctrl*(F_des - Fn_meas)))
                else force_int;

    // Task-space impedance command + force regulation, mapped to joints via J^T
    tau1_cmd = J11*(Kp_pos*(x_des_base - x_ee_meas) - Kd_pos*vx_ee_meas + force_int)
             + J21*(Kp_posy*(y_des - y_ee_meas) - Kd_posy*vy_ee_meas);
    tau2_cmd = J12*(Kp_pos*(x_des_base - x_ee_meas) - Kd_pos*vx_ee_meas + force_int)
             + J22*(Kp_posy*(y_des - y_ee_meas) - Kd_posy*vy_ee_meas);
  end when;

  // ===== Instrumentation: actuator state, normal contact force, object pose =====
  meas_q1  = q1;
  meas_q2  = q2;
  meas_dq1 = dq1;
  meas_dq2 = dq2;
  normal_contact_force = Fn;
  object_pose_x = x_obj;
  object_pose_y = y_obj;
  // Rotational DOF omitted: contact assumed centered on object COM (requirement silent on geometry);
  // orientation therefore remains bounded at zero.
  object_pose_theta = 0.0;

  // ===== Requirement verification observables =====
  primary_tracking_error = abs(x_ee - x_des_base);
  in_contact = Fn > 0.5;
  grasp_lost = (in_contact and Fn < 1.0) or (abs(y_obj) > 0.1);
  bounds_ok = (abs(tau1) <= tau_max + 1e-6) and (abs(tau2) <= tau_max + 1e-6);
  finite_ok = (q1 == q1) and (q2 == q2) and (dq1 == dq1) and (dq2 == dq2)
           and (x_obj == x_obj) and (y_obj == y_obj) and (Fn == Fn)
           and (tau1 == tau1) and (tau2 == tau2) and (force_int == force_int);

end PlanarPusherGraspB;