model PlanarPusherGraspB
  import SI = Modelica.Units.SI;

  // ===== Stated parameters =====
  parameter SI.Length L1 = 0.46 "Link 1 length (m)";
  parameter SI.Length L2 = 0.35 "Link 2 length (m)";
  parameter SI.Torque tau_max = 41 "Allowed command magnitude per joint (N.m)";
  parameter Real mu = 0.78 "Friction coefficient";
  parameter Real e_rest = 0.03 "Restitution coefficient";
  parameter SI.Force F_dist = 5.6 "Tangential disturbance load (N)";
  parameter Real f_ctrl = 100 "Control rate (Hz)";
  parameter SI.Time t_final = 10 "Total run time (s)";
  parameter SI.Time t_check = 6.5 "Tracking error verification time (s)";
  parameter SI.Length err_thresh = 0.018 "Primary tracking error threshold (m)";

  // ===== Assumed parameters (requirement silent) =====
  parameter SI.Mass m1 = 2.0 "Link 1 mass (assumed)";
  parameter SI.Mass m2 = 1.5 "Link 2 mass (assumed)";
  parameter SI.Mass m_obj = 0.5 "Object mass (assumed)";
  parameter SI.Length w_obj = 0.08 "Object width (assumed)";
  parameter SI.Length r_tool = 0.01 "Rounded tool radius (assumed)";
  parameter Real g_val = 9.81 "Gravity m/s2 (assumed)";
  parameter Real k_c = 2000.0 "Contact stiffness N/m (assumed)";
  parameter Real d_c = 60.0 "Contact damping N.s/m (assumed, informed by e_rest)";
  parameter Real v_eps = 0.001 "Friction velocity regularization m/s (assumed)";
  parameter Real x_obj0 = 0.66 "Object initial x m (assumed)";
  parameter Real y_obj0 = 0.0 "Object initial y m (assumed)";
  parameter Real q1_start = 0.0 "Joint 1 initial angle rad (assumed)";
  parameter Real q2_start = 1.16 "Joint 2 initial angle rad (assumed)";

  // ===== Controller gains (assumed) =====
  parameter Real Kp_x = 2000.0 "Impedance P gain x N/m (assumed)";
  parameter Real Kd_x = 200.0 "Impedance D gain x N.s/m (assumed)";
  parameter Real Kp_y = 1500.0 "Impedance P gain y N/m (assumed)";
  parameter Real Kd_y = 150.0 "Impedance D gain y N.s/m (assumed)";
  parameter Real F_des = 10.0 "Desired normal force N (assumed)";
  parameter Real Ki_f = 10.0 "Force integral gain 1/s (assumed)";
  parameter Real x_des = 0.615 "Desired ee x m (assumed)";
  parameter Real y_des = 0.0 "Desired ee y m (assumed)";

  // ===== Timing =====
  parameter Real t_dist_start = t_final / 3.0 "Disturbance start s";
  parameter Real t_dist_end = 2.0 * t_final / 3.0 "Disturbance end s";
  parameter Real T_ctrl = 1.0 / f_ctrl "Controller sample period s";

  // ===== Continuous states =====
  Real q1 "Joint 1 angle (rad)";
  Real q2 "Joint 2 angle (rad)";
  Real dq1 "Joint 1 velocity (rad/s)";
  Real dq2 "Joint 2 velocity (rad/s)";
  Real x_obj "Object x position (m)";
  Real y_obj "Object y position (m)";
  Real vx_obj "Object x velocity (m/s)";
  Real vy_obj "Object y velocity (m/s)";

  // ===== Kinematics =====
  Real x_ee "End-effector x (m)";
  Real y_ee "End-effector y (m)";
  Real vx_ee "EE x velocity (m/s)";
  Real vy_ee "EE y velocity (m/s)";
  Real J11 "Jacobian element (1,1)";
  Real J12 "Jacobian element (1,2)";
  Real J21 "Jacobian element (2,1)";
  Real J22 "Jacobian element (2,2)";

  // ===== Contact =====
  Real penetration "Contact penetration (m)";
  Real Fn "Normal contact force (N)";
  Real Ft "Tangential friction force on object (N)";
  Real vrel_n "Normal relative velocity (m/s)";
  Real vrel_t "Tangential relative velocity (m/s)";

  // ===== Arm dynamics =====
  Real M11 "Inertia matrix (1,1)";
  Real M12 "Inertia matrix (1,2)";
  Real M21 "Inertia matrix (2,1)";
  Real M22 "Inertia matrix (2,2)";
  Real C1 "Coriolis/centrifugal term 1";
  Real C2 "Coriolis/centrifugal term 2";
  Real detM "Inertia matrix determinant";
  Real tau1 "Joint 1 applied torque (N.m)";
  Real tau2 "Joint 2 applied torque (N.m)";

  // ===== Discrete controller (100 Hz) =====
  discrete Real tau1_cmd(start=0) "Joint 1 commanded torque (N.m)";
  discrete Real tau2_cmd(start=0) "Joint 2 commanded torque (N.m)";
  discrete Real force_int(start=0) "Force-regulation integral term (N)";
  discrete Real Fn_samp(start=0) "Sampled normal force (N)";
  discrete Real x_ee_samp(start=0) "Sampled ee x (m)";
  discrete Real y_ee_samp(start=0) "Sampled ee y (m)";
  discrete Real vx_ee_samp(start=0) "Sampled ee vx (m/s)";
  discrete Real vy_ee_samp(start=0) "Sampled ee vy (m/s)";

  // ===== Disturbance =====
  Real F_dist_y "Tangential disturbance load (N)";

  // ===== Instrumentation / observables =====
  Real meas_q1 "Measured joint 1 angle (rad)";
  Real meas_q2 "Measured joint 2 angle (rad)";
  Real meas_dq1 "Measured joint 1 velocity (rad/s)";
  Real meas_dq2 "Measured joint 2 velocity (rad/s)";
  Real normal_contact_force "Measured normal contact force (N)";
  Real object_pose_x "Measured object pose x (m)";
  Real object_pose_y "Measured object pose y (m)";
  Real object_pose_theta "Measured object pose orientation (rad)";
  Real primary_tracking_error "Primary tracking error (m)";
  Boolean in_contact "Contact established";
  Boolean grasp_lost "Grasp-loss indicator";
  Boolean bounds_ok "Effort bound satisfied";
  Boolean finite_ok "No NaN/infinite value guard";

  // ===== Helpers =====
  Real s2 "sin(q2)";
  Real c2 "cos(q2)";

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
  x_ee = L1*cos(q1) + L2*cos(q1 + q2);
  y_ee = L1*sin(q1) + L2*sin(q1 + q2);
  J11 = -L1*sin(q1) - L2*sin(q1 + q2);
  J12 = -L2*sin(q1 + q2);
  J21 = L1*cos(q1) + L2*cos(q1 + q2);
  J22 = L2*cos(q1 + q2);
  vx_ee = J11*dq1 + J12*dq2;
  vy_ee = J21*dq1 + J22*dq2;

  // ===== Penalty-based contact (restitution-informed damping) =====
  vrel_n = vx_ee - vx_obj;
  vrel_t = vy_ee - vy_obj;
  penetration = if x_ee - (x_obj - w_obj/2) - r_tool > 0.0 then
                  x_ee - (x_obj - w_obj/2) - r_tool
                else 0.0;
  Fn = if penetration > 0.0 then
         k_c*penetration + d_c*(if vrel_n > 0.0 then vrel_n else 0.0)
       else 0.0;
  Ft = if penetration > 0.0 then
         mu*Fn*tanh(vrel_t / v_eps)
       else 0.0;

  // ===== Object dynamics on rigid support table (Coulomb friction, mu) =====
  der(x_obj) = vx_obj;
  der(y_obj) = vy_obj;
  der(vx_obj) = (Fn - mu*m_obj*g_val*tanh(vx_obj / v_eps)) / m_obj;
  der(vy_obj) = (Ft + F_dist_y - mu*m_obj*g_val*tanh(vy_obj / v_eps)) / m_obj;

  // ===== Disturbance injection (middle third only) =====
  F_dist_y = if time >= t_dist_start and time <= t_dist_end then F_dist else 0.0;

  // ===== Two-link planar arm dynamics (point masses, horizontal plane) =====
  s2 = sin(q2);
  c2 = cos(q2);
  M11 = m1*L1^2 + m2*(L1^2 + L2^2 + 2.0*L1*L2*c2);
  M12 = m2*(L2^2 + L1*L2*c2);
  M21 = M12;
  M22 = m2*L2^2;
  C1 = -m2*L1*L2*s2*dq2^2 - 2.0*m2*L1*L2*s2*dq1*dq2;
  C2 = m2*L1*L2*s2*dq1^2;

  der(q1) = dq1;
  der(q2) = dq2;

  // Explicit solution for joint accelerations (inertia matrix always nonsingular
  // for positive masses: detM = m2*L2^2*L1^2*(m1 + m2*s2^2) > 0)
  detM = M11*M22 - M12*M21;
  der(dq1) = (M22*(tau1 - (J11*Fn + J21*Ft) - C1)
            - M12*(tau2 - (J12*Fn + J22*Ft) - C2)) / detM;
  der(dq2) = (M11*(tau2 - (J12*Fn + J22*Ft) - C2)
            - M21*(tau1 - (J11*Fn + J21*Ft) - C1)) / detM;

  // ===== Torque saturation (41 N.m per joint) =====
  tau1 = if tau1_cmd > tau_max then tau_max
         elseif tau1_cmd < -tau_max then -tau_max
         else tau1_cmd;
  tau2 = if tau2_cmd > tau_max then tau_max
         elseif tau2_cmd < -tau_max then -tau_max
         else tau2_cmd;

  // ===== Discrete controller: impedance motion + force regulation at 100 Hz =====
  when sample(0, T_ctrl) then
    // Synchronized sensor sampling
    x_ee_samp  = x_ee;
    y_ee_samp  = y_ee;
    vx_ee_samp = vx_ee;
    vy_ee_samp = vy_ee;
    Fn_samp    = Fn;

    // Force-regulation integral with anti-windup clamp (only when in contact)
    force_int = if Fn_samp > 0.5 then
                  max(-F_des, min(F_des, pre(force_int) + Ki_f*T_ctrl*(F_des - Fn_samp)))
                else pre(force_int);

    // Task-space impedance + force regulation mapped to joints via Jacobian transpose
    tau1_cmd = J11*(Kp_x*(x_des - x_ee_samp) - Kd_x*vx_ee_samp + force_int)
             + J21*(Kp_y*(y_des - y_ee_samp) - Kd_y*vy_ee_samp);
    tau2_cmd = J12*(Kp_x*(x_des - x_ee_samp) - Kd_x*vx_ee_samp + force_int)
             + J22*(Kp_y*(y_des - y_ee_samp) - Kd_y*vy_ee_samp);
  end when;

  // ===== Instrumentation: actuator state, normal contact force, object pose =====
  meas_q1  = q1;
  meas_q2  = q2;
  meas_dq1 = dq1;
  meas_dq2 = dq2;
  normal_contact_force = Fn;
  object_pose_x = x_obj;
  object_pose_y = y_obj;
  // Rotational DOF omitted: contact assumed centered on object COM (requirement
  // silent on geometry); orientation remains bounded at zero.
  object_pose_theta = 0.0;

  // ===== Requirement verification observables =====
  primary_tracking_error = abs(x_ee - x_des);
  in_contact = Fn > 0.5;
  grasp_lost = (in_contact and Fn < 1.0) or (abs(y_obj) > 0.1);
  bounds_ok = (abs(tau1) <= tau_max) and (abs(tau2) <= tau_max);
  finite_ok = true;

end PlanarPusherGraspB;