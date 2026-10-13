model CartesianToolGraspB
  // ===== Requirement-specified parameters =====
  parameter Real m_tool = 2.5 "tool carriage mass [kg] (from requirement)";
  parameter Real x_lim = 0.10 "X travel bound [m] (from requirement, +/-)";
  parameter Real y_lim = 0.10 "Y travel bound [m] (from requirement, +/-)";
  parameter Real z_lim = 0.30 "Z travel bound [m] (from requirement, +/-)";
  parameter Real F_max = 287.0 "allowed actuator command magnitude per axis [N] (from requirement)";
  parameter Real mu = 0.78 "friction coefficient (from requirement)";
  parameter Real e_rest = 0.03 "coefficient of restitution (from requirement)";
  parameter Real F_dist = 5.6 "tangential disturbance load [N] (from requirement)";
  parameter Real g = 9.81 "gravitational acceleration [m/s2]";
  parameter Real t_end = 10.0 "mission duration [s] (from requirement)";
  parameter Real dt_out = 0.01 "output sample interval [s] (100 Hz, from requirement)";
  parameter Real err_thresh = 0.018 "primary tracking error threshold after 6.5 s [m] (from requirement)";

  // ===== Assumed parameters (not specified in requirement; engineering assumptions) =====
  parameter Real m_obj = 0.5 "object mass [kg] (ASSUMED; requirement does not specify)";
  parameter Real h_obj = 0.04 "object height [m] (ASSUMED; requirement does not specify)";
  parameter Real k_grip = 2000.0 "grip contact stiffness [N/m] (ASSUMED)";
  parameter Real d_contact = 145.0 "grip contact damping base [N.s/m] (ASSUMED)";
  parameter Real K_imp = 800.0 "impedance stiffness [N/m] (ASSUMED controller gain)";
  parameter Real B_imp = 90.0 "impedance damping [N.s/m] (ASSUMED controller gain)";
  parameter Real K_force = 2.0 "force regulation gain (ASSUMED controller gain)";
  parameter Real B_force = 250.0 "force loop damping [N.s/m] (ASSUMED controller gain)";
  parameter Real F_grasp_des = 20.0 "desired grasp normal force [N] (ASSUMED)";
  parameter Real Fg_ramp = 0.5 "grasp force ramp duration [s] (ASSUMED)";
  parameter Real v_thresh = 1.0e-3 "friction regularization velocity [m/s] (ASSUMED; avoids div-by-zero)";
  parameter Real x_target = 0.05 "X grasp target [m] (ASSUMED mission target)";
  parameter Real y_target = 0.0 "Y grasp target [m] (ASSUMED mission target)";
  parameter Real z_target = 0.04 "Z target = object top [m] (ASSUMED mission target)";
  parameter Real z_home = 0.20 "Z home position [m] (ASSUMED initial tool height)";

  // ===== Tool states (actuator state) =====
  Real x_t(start=0.0, fixed=true) "tool X position [m]";
  Real y_t(start=0.0, fixed=true) "tool Y position [m]";
  Real z_t(start=0.20, fixed=true) "tool Z position [m]";
  Real vx_t(start=0.0, fixed=true) "tool X velocity [m/s]";
  Real vy_t(start=0.0, fixed=true) "tool Y velocity [m/s]";
  Real vz_t(start=0.0, fixed=true) "tool Z velocity [m/s]";

  // ===== Object pose (object rests on rigid table; X is dynamic, Y=Z=0) =====
  Real x_o(start=0.05, fixed=true) "object X position [m]";
  Real vx_o(start=0.0, fixed=true) "object X velocity [m/s]";
  Real y_o "object Y position [m] (= 0, rigid table constraint)";
  Real z_o "object Z position [m] (= 0, rigid table surface)";
  Real vy_o "object Y velocity [m/s] (= 0)";
  Real vz_o "object Z velocity [m/s] (= 0)";

  // ===== Commands and actuator outputs =====
  Real Fx_cmd "X force command [N]";
  Real Fy_cmd "Y force command [N]";
  Real Fz_cmd "Z force command [N]";
  Real Fx_act "X actuator force [N]";
  Real Fy_act "Y actuator force [N]";
  Real Fz_act "Z actuator force [N]";
  Real Fg_cmd "commanded grasp normal force [N]";

  // ===== Sensors =====
  Real Fn_table "table normal contact force [N] (rigid table reaction)";
  Real Fn_grasp "grasp normal contact force [N]";
  Real F_grip_friction "grip tangential friction force on object [N]";
  Real F_table_friction "table tangential friction force on object [N]";
  Real F_dist_applied "applied tangential disturbance [N]";

  // ===== Tracking =====
  Real err_x "X tracking error [m]";
  Real err_y "Y tracking error [m]";
  Real err_z "Z tracking error [m]";
  Real tracking_error "primary tracking error [m]";

  // ===== Mission phase =====
  Real phase "mission phase (1=approach, 2=grasp+disturbance, 3=hold)";
protected
  Real grip_pen "tool grip penetration into object [m]";
  Real v_rel_x "relative tangential velocity object-tool in X [m/s]";
  Real t1 "phase 1 end time [s]";
  Real t2 "phase 2 end time [s]";
  Real d_eff "effective contact damping coefficient [N.s/m]";
  Real n_grip "regularized friction divisor for grip (>= v_thresh, no NaN)";
  Real n_table "regularized friction divisor for table (>= v_thresh, no NaN)";
equation
  t1 = t_end/3.0;
  t2 = 2.0*t_end/3.0;
  d_eff = d_contact*(1.0 - e_rest);

  // Rigid table constraints (object held on table surface in Y and Z)
  y_o = 0.0;
  z_o = 0.0;
  vy_o = 0.0;
  vz_o = 0.0;

  // Phase indicator
  phase = if time < t1 then 1.0 elseif time < t2 then 2.0 else 3.0;

  // Grasp force command with smooth ramp at start of phase 2
  Fg_cmd = if time < t1 then 0.0
           elseif time < t1 + Fg_ramp then F_grasp_des*(time - t1)/Fg_ramp
           else F_grasp_des;

  // Tangential disturbance injection during middle third
  F_dist_applied = if (time >= t1 and time < t2) then F_dist else 0.0;

  // Grip penetration (tool pressing down onto object top)
  grip_pen = if noEvent(z_t < h_obj) then h_obj - z_t else 0.0;

  // Compliant grip normal force (damping active during compression: tool moving down)
  Fn_grasp = k_grip*grip_pen + d_eff*(if noEvent(vz_t < 0.0) then -vz_t else 0.0);

  // Rigid table normal reaction (balances gravity + grasp down-force on object)
  Fn_table = m_obj*g + Fn_grasp;

  // Regularized Coulomb friction divisors (zero-error branch: >= v_thresh > 0)
  v_rel_x = vx_o - vx_t;
  n_grip = sqrt(v_rel_x*v_rel_x + v_thresh*v_thresh);
  n_table = sqrt(vx_o*vx_o + v_thresh*v_thresh);
  F_grip_friction = -mu*Fn_grasp*v_rel_x/n_grip;
  F_table_friction = -mu*Fn_table*vx_o/n_table;

  // Tracking errors against mission targets
  err_x = x_target - x_t;
  err_y = y_target - y_t;
  err_z = z_target - z_t;
  tracking_error = sqrt(err_x*err_x + err_y*err_y + err_z*err_z);

  // Control: impedance motion (X, Y always; Z in phase 1), force regulation (Z in phase 2/3)
  Fx_cmd = K_imp*err_x - B_imp*vx_t;
  Fy_cmd = K_imp*err_y - B_imp*vy_t;
  Fz_cmd = if time < t1 then
             K_imp*err_z - B_imp*vz_t + m_tool*g
           else
             m_tool*g - Fg_cmd - K_force*(Fg_cmd - Fn_grasp) - B_force*vz_t;

  // Force-limited actuator saturation (287 N per axis)
  Fx_act = max(-F_max, min(F_max, Fx_cmd));
  Fy_act = max(-F_max, min(F_max, Fy_cmd));
  Fz_act = max(-F_max, min(F_max, Fz_cmd));

  // Tool dynamics (Z up positive)
  der(x_t) = vx_t;
  der(y_t) = vy_t;
  der(z_t) = vz_t;
  m_tool*der(vx_t) = Fx_act - F_grip_friction;
  m_tool*der(vy_t) = Fy_act;
  m_tool*der(vz_t) = Fz_act - m_tool*g + Fn_grasp;

  // Object dynamics (X only; rigid table holds Y and Z)
  der(x_o) = vx_o;
  m_obj*der(vx_o) = F_dist_applied + F_grip_friction + F_table_friction;

  // ===== Requirement checks =====
  assert(abs(x_t) <= x_lim + 1e-6, "X travel bound exceeded");
  assert(abs(y_t) <= y_lim + 1e-6, "Y travel bound exceeded");
  assert(abs(z_t) <= z_lim + 1e-6, "Z travel bound exceeded");
  assert(abs(Fx_act) <= F_max + 1e-6, "X effort bound exceeded");
  assert(abs(Fy_act) <= F_max + 1e-6, "Y effort bound exceeded");
  assert(abs(Fz_act) <= F_max + 1e-6, "Z effort bound exceeded");
  assert(Fn_table >= -1e-6, "Table normal force negative");
  assert(Fn_grasp >= -1e-6, "Grasp normal force negative");
  // No grasp loss once grasp is established (after the ramp)
  assert(time < t1 + Fg_ramp or Fn_grasp >= 0.5*F_grasp_des,
         "Grasp lost: normal force below half of desired");
  // Primary tracking error requirement after 6.5 s
  assert(time < 6.5 or tracking_error <= err_thresh + 1e-6,
         "Primary tracking error exceeded 0.018 m after 6.5 s");
  // NaN/Inf safety is guaranteed structurally: all divisors are bounded below by
  // v_thresh > 0, all square-root arguments are non-negative, and no unbounded
  // nonlinearities are used.

  annotation(
    experiment(StopTime=10.0, Interval=0.01, Tolerance=1e-6),
    Documentation(info="CartesianToolGraspB: acquire rigid object, establish stable grasp, hold without excessive displacement. Three orthogonal prismatic axes (X/Y +/-0.10 m, Z +/-0.30 m), 2.5 kg tool carriage, force-limited 287 N/axis actuators, rigid support table (mu=0.78, e=0.03), impedance + force regulation control, 5.6 N tangential disturbance in middle third, 100 Hz output over 10 s, primary tracking error < 0.018 m after 6.5 s. Parameters not stated in the requirement are marked ASSUMED."));
end CartesianToolGraspB;