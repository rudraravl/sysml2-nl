model CartesianToolGraspB
  // ---------- Physical parameters ----------
  parameter Real m_tool = 2.5 "tool carriage mass [kg]";
  parameter Real m_obj = 0.5 "object mass [kg] (not specified in requirement; assumed for simulation)";
  parameter Real h_obj = 0.04 "object height [m] (not specified; assumed)";
  parameter Real g = 9.81 "gravitational acceleration [m/s2]";
  parameter Real k_contact = 5.0e3 "contact stiffness [N/m] (not specified; assumed)";
  parameter Real d_contact = 200.0 "contact damping base [N.s/m] (not specified; assumed)";
  parameter Real mu = 0.78 "friction coefficient (table/object and grip)";
  parameter Real e_rest = 0.03 "coefficient of restitution";
  parameter Real F_max = 287.0 "allowed actuator command magnitude per axis [N]";
  // ---------- Travel bounds ----------
  parameter Real x_lim = 0.10 "X travel bound [m]";
  parameter Real y_lim = 0.10 "Y travel bound [m]";
  parameter Real z_lim = 0.30 "Z travel bound [m]";
  // ---------- Controller gains ----------
  parameter Real K_imp = 200.0 "impedance stiffness [N/m]";
  parameter Real B_imp = 40.0 "impedance damping [N.s/m]";
  parameter Real K_force = 10.0 "force regulation gain";
  parameter Real B_force = 400.0 "force loop damping [N.s/m]";
  parameter Real F_grasp_des = 20.0 "desired grasp normal force [N] (not specified; assumed)";
  parameter Real Fg_ramp = 0.5 "grasp force ramp duration [s] (not specified; assumed)";
  parameter Real F_dist = 5.6 "tangential disturbance load [N]";
  parameter Real v_thresh = 1.0e-3 "friction regularization velocity [m/s]";
  // ---------- Mission targets ----------
  parameter Real x_target = 0.05 "X grasp target [m]";
  parameter Real y_target = 0.0 "Y grasp target [m]";
  parameter Real z_target = 0.04 "Z grasp target (object top) [m]";
  parameter Real z_home = 0.20 "Z home position [m]";

  // ---------- Tool states (actuator state) ----------
  Real x_t(start=0.0) "tool X position [m]";
  Real y_t(start=0.0) "tool Y position [m]";
  Real z_t(start=0.20) "tool Z position [m]";
  Real vx_t(start=0.0) "tool X velocity [m/s]";
  Real vy_t(start=0.0) "tool Y velocity [m/s]";
  Real vz_t(start=0.0) "tool Z velocity [m/s]";
  // ---------- Object states (object pose) ----------
  Real x_o(start=0.05) "object X position [m]";
  Real y_o(start=0.0) "object Y position [m]";
  Real z_o(start=0.0) "object Z position [m]";
  Real vx_o(start=0.0) "object X velocity [m/s]";
  Real vy_o(start=0.0) "object Y velocity [m/s]";
  Real vz_o(start=0.0) "object Z velocity [m/s]";
  // ---------- Control commands and saturated actuator outputs ----------
  Real Fx_cmd "X force command [N]";
  Real Fy_cmd "Y force command [N]";
  Real Fz_cmd "Z force command [N]";
  Real Fx_act "X actuator force [N]";
  Real Fy_act "Y actuator force [N]";
  Real Fz_act "Z actuator force [N]";
  Real Fg_cmd "commanded grasp normal force [N]";
  // ---------- Sensors ----------
  Real Fn_table "table normal contact force [N]";
  Real Fn_grasp "grasp normal contact force [N]";
  Real F_grip_friction "grip tangential friction force on object [N]";
  Real F_table_friction "table tangential friction force on object [N]";
  Real F_dist_applied "applied tangential disturbance [N]";
  // ---------- Tracking ----------
  Real err_x "X tracking error [m]";
  Real err_y "Y tracking error [m]";
  Real err_z "Z tracking error [m]";
  Real tracking_error "primary tracking error [m]";
  // ---------- Mission phase ----------
  Real phase "mission phase (1=approach, 2=grasp+disturbance, 3=hold)";
protected
  Real table_pen "object penetration into table [m]";
  Real grip_pen "tool grip penetration into object [m]";
  Real v_rel_x "relative tangential velocity object-tool [m/s]";
  Real t1 "phase 1 end time [s]";
  Real t2 "phase 2 end time [s]";
  Real d_eff "effective contact damping coefficient [N.s/m]";
equation
  t1 = 10.0/3.0;
  t2 = 20.0/3.0;
  // Restitution-informed contact damping (low restitution -> high damping)
  d_eff = d_contact*(1.0 - e_rest);

  // Phase indicator (events at phase boundaries)
  phase = if time < t1 then 1.0 elseif time < t2 then 2.0 else 3.0;

  // Grasp force command with smooth ramp at start of phase 2
  Fg_cmd = if time < t1 then 0.0
           elseif time < t1 + Fg_ramp then F_grasp_des*(time - t1)/Fg_ramp
           else F_grasp_des;

  // Tangential disturbance injection during middle third
  F_dist_applied = if (time >= t1 and time < t2) then F_dist else 0.0;

  // Penetrations (non-negative, smooth via noEvent)
  table_pen = if noEvent(z_o < 0.0) then -z_o else 0.0;
  grip_pen = if noEvent(z_t < z_o + h_obj) then (z_o + h_obj) - z_t else 0.0;

  // Compliant normal contact forces (damping active only during compression)
  Fn_table = k_contact*table_pen + d_eff*(if noEvent(vz_o < 0.0) then -vz_o else 0.0);
  Fn_grasp = k_contact*grip_pen + d_eff*(if noEvent(vz_o - vz_t > 0.0) then vz_o - vz_t else 0.0);

  // Regularized Coulomb friction (zero-error branch via v_thresh -> no NaN/Inf)
  v_rel_x = vx_o - vx_t;
  F_grip_friction = -mu*Fn_grasp*v_rel_x/sqrt(v_rel_x*v_rel_x + v_thresh*v_thresh);
  F_table_friction = -mu*Fn_table*vx_o/sqrt(vx_o*vx_o + v_thresh*v_thresh);

  // Tracking errors (against user targets)
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
             K_force*(Fg_cmd - Fn_grasp) - B_force*vz_t + m_tool*g - Fg_cmd;

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

  // Object dynamics (object rests on rigid table)
  der(x_o) = vx_o;
  der(y_o) = vy_o;
  der(z_o) = vz_o;
  m_obj*der(vx_o) = F_dist_applied + F_grip_friction + F_table_friction;
  m_obj*der(vy_o) = 0.0;
  m_obj*der(vz_o) = Fn_table - m_obj*g - Fn_grasp;

  // ---------- Requirement checks ----------
  assert(abs(x_t) <= x_lim + 1e-6, "X travel bound exceeded");
  assert(abs(y_t) <= y_lim + 1e-6, "Y travel bound exceeded");
  assert(abs(z_t) <= z_lim + 1e-6, "Z travel bound exceeded");
  assert(abs(Fx_act) <= F_max + 1e-6, "X effort bound exceeded");
  assert(abs(Fy_act) <= F_max + 1e-6, "Y effort bound exceeded");
  assert(abs(Fz_act) <= F_max + 1e-6, "Z effort bound exceeded");
  assert(Fn_table >= -1e-6, "Table normal force negative");
  assert(Fn_grasp >= -1e-6, "Grasp normal force negative");
  // Finite-value guards via boundedness checks (no NaN/Inf allowed)
  assert(abs(x_t) < 1e6, "Tool X position not finite");
  assert(abs(y_t) < 1e6, "Tool Y position not finite");
  assert(abs(z_t) < 1e6, "Tool Z position not finite");
  assert(abs(x_o) < 1e6, "Object X position not finite");
  assert(abs(y_o) < 1e6, "Object Y position not finite");
  assert(abs(z_o) < 1e6, "Object Z position not finite");
  assert(abs(Fx_act) < 1e6, "Actuator X force not finite");
  assert(abs(Fy_act) < 1e6, "Actuator Y force not finite");
  assert(abs(Fz_act) < 1e6, "Actuator Z force not finite");

  annotation(
    experiment(StopTime=10.0, Interval=0.01, Tolerance=1e-6),
    Documentation(info="CartesianToolGraspB mission: acquire rigid object, establish stable grasp, hold without excessive displacement. Three orthogonal prismatic axes (X/Y +/-0.10 m, Z +/-0.30 m), 2.5 kg tool carriage, force-limited 287 N/axis actuators, rigid table (mu=0.78, e=0.03, collision enabled), impedance + force regulation control, 5.6 N tangential disturbance in middle third, 100 Hz output over 10 s.")
  );
end CartesianToolGraspB;