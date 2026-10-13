model CartesianToolGraspE
  // ==================== Physical parameters ====================
  parameter Real m_tool = 2.5 "Tool carriage mass [kg]";
  parameter Real m_obj = 1.0 "Object mass [kg] — not specified in requirements; assumed";
  parameter Real h_obj = 0.04 "Object height [m] — not specified in requirements; assumed";
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real z_init = 0.20 "Initial tool Z position [m]";

  // ==================== Travel bounds ====================
  parameter Real x_max = 0.10 "X travel max [m]";
  parameter Real x_min = -0.10 "X travel min [m]";
  parameter Real y_max = 0.10 "Y travel max [m]";
  parameter Real y_min = -0.10 "Y travel min [m]";
  parameter Real z_max = 0.30 "Z travel max [m]";
  parameter Real z_min = -0.30 "Z travel min [m]";

  // ==================== Actuator ====================
  parameter Real F_max = 385.0 "Per-axis force limit [N]";

  // ==================== Contact ====================
  parameter Real mu = 0.78 "Friction coefficient";
  parameter Real e_rest = 0.03 "Coefficient of restitution";
  parameter Real k_contact = 2.0e4 "Contact stiffness [N/m]";
  parameter Real d_contact = 330.0 "Contact damping [N.s/m] — tuned for e_rest approximately 0.03";
  parameter Real v_thresh = 1.0e-4 "Friction velocity regularization [m/s]";

  // ==================== Impedance controller ====================
  parameter Real Kp_x = 2000.0 "X impedance stiffness [N/m]";
  parameter Real Kd_x = 80.0 "X impedance damping [N.s/m]";
  parameter Real Kp_y = 2000.0 "Y impedance stiffness [N/m]";
  parameter Real Kd_y = 80.0 "Y impedance damping [N.s/m]";
  parameter Real Kp_z = 3000.0 "Z impedance stiffness [N/m]";
  parameter Real Kd_z = 100.0 "Z impedance damping [N.s/m]";

  // ==================== Force regulation ====================
  parameter Real F_grasp_target = 20.0 "Target grasp normal force [N]";
  parameter Real Kf = 2.0e-3 "Force regulation integral gain [m/(N.s)]";

  // ==================== Disturbance ====================
  parameter Real F_dist = 9.6 "Tangential disturbance magnitude [N]";
  parameter Real t_dist_start = 16.0 / 3.0 "Disturbance start time [s]";
  parameter Real t_dist_end = 2.0 * 16.0 / 3.0 "Disturbance end time [s]";

  // ==================== Control timing ====================
  parameter Real Ts = 1.0 / 250.0 "Control sample period [s]";
  parameter Real t_impedance_end = 3.0 "Impedance phase end time [s]";

  // ==================== Position limit ====================
  parameter Real k_limit = 1.0e5 "Travel limit stiffness [N/m]";
  parameter Real d_limit = 500.0 "Travel limit damping [N.s/m]";

  // ==================== Continuous states: tool ====================
  Real x_tool(start = 0.0, fixed = true) "Tool X position [m]";
  Real y_tool(start = 0.0, fixed = true) "Tool Y position [m]";
  Real z_tool(start = z_init, fixed = true) "Tool Z position [m]";
  Real vx_tool(start = 0.0, fixed = true) "Tool X velocity [m/s]";
  Real vy_tool(start = 0.0, fixed = true) "Tool Y velocity [m/s]";
  Real vz_tool(start = 0.0, fixed = true) "Tool Z velocity [m/s]";

  // ==================== Continuous states: object ====================
  Real x_obj(start = 0.0, fixed = true) "Object X position [m]";
  Real y_obj(start = 0.0, fixed = true) "Object Y position [m]";
  Real vx_obj(start = 0.0, fixed = true) "Object X velocity [m/s]";
  Real vy_obj(start = 0.0, fixed = true) "Object Y velocity [m/s]";

  // ==================== Discrete controller states ====================
  Real x_ref_d(start = 0.0) "Reference X [m]";
  Real y_ref_d(start = 0.0) "Reference Y [m]";
  Real z_ref_d(start = z_init) "Reference Z [m]";
  Real F_cmd_x(start = 0.0) "X actuator command [N]";
  Real F_cmd_y(start = 0.0) "Y actuator command [N]";
  Real F_cmd_z(start = 0.0) "Z actuator command [N]";

  // ==================== Contact and friction ====================
  Real penetration "Tool-object penetration depth [m]";
  Real F_contact "Normal contact force [N]";
  Real v_rel_x "Relative velocity X, object w.r.t. tool [m/s]";
  Real v_rel_y "Relative velocity Y, object w.r.t. tool [m/s]";
  Real v_rel_mag "Relative speed magnitude [m/s]";
  Real f_friction_obj_x "Friction on object from tool, X [N]";
  Real f_friction_obj_y "Friction on object from tool, Y [N]";
  Real f_friction_tool_x "Friction on tool from object, X [N]";
  Real f_friction_tool_y "Friction on tool from object, Y [N]";
  Real v_obj_mag "Object speed [m/s]";
  Real N_table "Table normal force on object [N]";
  Real f_table_obj_x "Table friction on object, X [N]";
  Real f_table_obj_y "Table friction on object, Y [N]";

  // ==================== Disturbance ====================
  Real F_dist_x "Applied disturbance force X [N]";

  // ==================== Position limit forces ====================
  Real F_limit_x "Travel limit force X [N]";
  Real F_limit_y "Travel limit force Y [N]";
  Real F_limit_z "Travel limit force Z [N]";

  // ==================== Actuator output ====================
  Real F_act_x "Saturated X actuator force [N]";
  Real F_act_y "Saturated Y actuator force [N]";
  Real F_act_z "Saturated Z actuator force [N]";

  // ==================== Sensors ====================
  Real F_normal_measured "Measured normal contact force [N]";
  Real track_error "Primary tracking error [m]";
  Real obj_displacement "Object displacement from initial pose [m]";

  // ==================== Acceptance flags ====================
  Boolean bounds_ok "Travel and effort bounds satisfied";
  Boolean contact_ok "Stable contact after grasp";
  Boolean displacement_ok "Bounded object displacement";
  Boolean grasp_ok "No grasp loss during hold";
  Boolean tracking_ok "Tracking error below threshold after 10.4 s";
  Boolean no_nan_ok "No NaN or infinite physical, control, or estimator values";
  Boolean accept "Overall acceptance — fail-closed";

equation
  // ==================== Contact model (compliant, damped; collision enabled) ====================
  penetration = h_obj - z_tool;
  F_contact = if penetration > 0.0 then max(0.0, k_contact * penetration - d_contact * vz_tool) else 0.0;

  // ==================== Tool-object Coulomb friction ====================
  v_rel_x = vx_obj - vx_tool;
  v_rel_y = vy_obj - vy_tool;
  v_rel_mag = sqrt(v_rel_x * v_rel_x + v_rel_y * v_rel_y) + v_thresh;
  f_friction_obj_x = -(mu * F_contact) * v_rel_x / v_rel_mag;
  f_friction_obj_y = -(mu * F_contact) * v_rel_y / v_rel_mag;
  f_friction_tool_x = -f_friction_obj_x;
  f_friction_tool_y = -f_friction_obj_y;

  // ==================== Table-object friction (rigid support table) ====================
  v_obj_mag = sqrt(vx_obj * vx_obj + vy_obj * vy_obj) + v_thresh;
  N_table = m_obj * g + F_contact;
  f_table_obj_x = -(mu * N_table) * vx_obj / v_obj_mag;
  f_table_obj_y = -(mu * N_table) * vy_obj / v_obj_mag;

  // ==================== Disturbance (middle third of 16 s) ====================
  F_dist_x = if time >= t_dist_start and time <= t_dist_end then F_dist else 0.0;

  // ==================== Travel limit forces (soft walls) ====================
  if x_tool > x_max then
    F_limit_x = -k_limit * (x_tool - x_max) - d_limit * vx_tool;
  elseif x_tool < x_min then
    F_limit_x = -k_limit * (x_tool - x_min) - d_limit * vx_tool;
  else
    F_limit_x = 0.0;
  end if;

  if y_tool > y_max then
    F_limit_y = -k_limit * (y_tool - y_max) - d_limit * vy_tool;
  elseif y_tool < y_min then
    F_limit_y = -k_limit * (y_tool - y_min) - d_limit * vy_tool;
  else
    F_limit_y = 0.0;
  end if;

  if z_tool > z_max then
    F_limit_z = -k_limit * (z_tool - z_max) - d_limit * vz_tool;
  elseif z_tool < z_min then
    F_limit_z = -k_limit * (z_tool - z_min) - d_limit * vz_tool;
  else
    F_limit_z = 0.0;
  end if;

  // ==================== Actuator saturation ====================
  F_act_x = max(-F_max, min(F_max, F_cmd_x));
  F_act_y = max(-F_max, min(F_max, F_cmd_y));
  F_act_z = max(-F_max, min(F_max, F_cmd_z));

  // ==================== Tool dynamics (3 prismatic axes, 2.5 kg carriage) ====================
  der(x_tool) = vx_tool;
  der(y_tool) = vy_tool;
  der(z_tool) = vz_tool;
  der(vx_tool) = (F_act_x + f_friction_tool_x + F_limit_x) / m_tool;
  der(vy_tool) = (F_act_y + f_friction_tool_y + F_limit_y) / m_tool;
  der(vz_tool) = (F_act_z - m_tool * g + F_contact + F_limit_z) / m_tool;

  // ==================== Object dynamics (XY, Z constrained on rigid table) ====================
  der(x_obj) = vx_obj;
  der(y_obj) = vy_obj;
  der(vx_obj) = (f_friction_obj_x + F_dist_x + f_table_obj_x) / m_obj;
  der(vy_obj) = (f_friction_obj_y + f_table_obj_y) / m_obj;

  // ==================== Sensors ====================
  F_normal_measured = F_contact;
  track_error = sqrt((x_ref_d - x_tool) * (x_ref_d - x_tool)
                   + (y_ref_d - y_tool) * (y_ref_d - y_tool)
                   + (z_ref_d - z_tool) * (z_ref_d - z_tool));
  obj_displacement = sqrt(x_obj * x_obj + y_obj * y_obj);

  // ==================== Acceptance criteria ====================
  bounds_ok = (x_tool >= x_min - 1.0e-3) and (x_tool <= x_max + 1.0e-3) and
              (y_tool >= y_min - 1.0e-3) and (y_tool <= y_max + 1.0e-3) and
              (z_tool >= z_min - 1.0e-3) and (z_tool <= z_max + 1.0e-3) and
              (abs(F_act_x) <= F_max + 1.0) and
              (abs(F_act_y) <= F_max + 1.0) and
              (abs(F_act_z) <= F_max + 1.0);

  contact_ok = if time > t_impedance_end + 1.0 then F_contact > 1.0 else true;
  displacement_ok = obj_displacement < 0.05;
  grasp_ok = if time > t_impedance_end + 1.0 then F_contact > 1.0 else true;
  tracking_ok = if time > 10.4 then track_error < 0.013 else true;

  no_nan_ok = (abs(x_tool) < 1.0e10) and (abs(y_tool) < 1.0e10) and (abs(z_tool) < 1.0e10) and
              (abs(vx_tool) < 1.0e10) and (abs(vy_tool) < 1.0e10) and (abs(vz_tool) < 1.0e10) and
              (abs(x_obj) < 1.0e10) and (abs(y_obj) < 1.0e10) and
              (abs(vx_obj) < 1.0e10) and (abs(vy_obj) < 1.0e10) and
              (abs(F_cmd_x) < 1.0e10) and (abs(F_cmd_y) < 1.0e10) and (abs(F_cmd_z) < 1.0e10) and
              (abs(F_contact) < 1.0e10);

  accept = bounds_ok and contact_ok and displacement_ok and grasp_ok and tracking_ok and no_nan_ok;

  // ==================== Discrete controller at 250 Hz ====================
  when sample(0, Ts) then
    if time < t_impedance_end then
      // Phase 1: Impedance motion — ramp Z from initial to object contact
      x_ref_d := 0.0;
      y_ref_d := 0.0;
      z_ref_d := z_init + (h_obj - z_init) * min(time / t_impedance_end, 1.0);
    else
      // Phase 2: Force regulation — integral action on normal force error
      x_ref_d := 0.0;
      y_ref_d := 0.0;
      z_ref_d := pre(z_ref_d) - Kf * (F_grasp_target - F_contact) * Ts;
    end if;

    // Impedance command with Z gravity compensation
    F_cmd_x := max(-F_max, min(F_max, Kp_x * (x_ref_d - x_tool) - Kd_x * vx_tool));
    F_cmd_y := max(-F_max, min(F_max, Kp_y * (y_ref_d - y_tool) - Kd_y * vy_tool));
    F_cmd_z := max(-F_max, min(F_max, Kp_z * (z_ref_d - z_tool) - Kd_z * vz_tool + m_tool * g));
  end when;

  annotation(
    experiment(StartTime = 0, StopTime = 16, Tolerance = 1.0e-6, Interval = 0.004),
    Documentation(info = "CartesianToolGraspE: Three-axis Cartesian tool with impedance motion, force-regulated grasp, and middle-third tangential disturbance. Object mass (1.0 kg) and height (0.04 m) are not specified in requirements; assumed for simulation. Contact damping tuned for restitution approximately 0.03. Control loop runs at 250 Hz for 16 s.")
  );
end CartesianToolGraspE;