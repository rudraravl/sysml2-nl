model VacuumToolGraspB
  "Vacuum tool grasp: impedance approach, force regulation, hold"

  // ===== Specified physical parameters =====
  parameter Real m_cup(unit="kg") = 0.8 "Suction cup mass [specified]";
  parameter Real r_cup(unit="m") = 0.038 "Suction cup radius [specified]";
  parameter Real p_cmd_max(unit="Pa") = -70000.0 "Max vacuum gauge pressure command [specified]";
  parameter Real p_cmd_min(unit="Pa") = 0.0 "Min vacuum gauge pressure command [specified]";
  parameter Real F_cmd_max(unit="N") = 262.0 "Max actuator command magnitude [specified]";
  parameter Real mu = 0.78 "Friction coefficient [specified]";
  parameter Real e_rest = 0.03 "Restitution coefficient [specified]";

  // ===== Unspecified physical parameters (nominal values) =====
  parameter Real m_obj(unit="kg") = 0.5 "Object mass [not specified, nominal]";
  parameter Real h_obj(unit="m") = 0.04 "Object height [not specified, nominal]";
  parameter Real k_contact(unit="N/m") = 1.0e4 "Contact stiffness [not specified, nominal]";
  parameter Real b_contact(unit="N.s/m") = 100.0 "Contact damping [not specified, nominal]";
  parameter Real k_table(unit="N/m") = 5.0e4 "Table stiffness [not specified, nominal]";
  parameter Real b_table(unit="N.s/m") = 200.0 "Table damping [not specified, nominal]";
  parameter Real g(unit="m/s2") = 9.81 "Gravitational acceleration";
  parameter Real tau_vacuum(unit="s") = 0.1 "Vacuum response time constant [not specified, nominal]";
  parameter Real v_thresh(unit="m/s") = 0.001 "Friction velocity threshold [not specified, nominal]";
  parameter Real A_cup(unit="m2") = 3.14159265358979 * r_cup * r_cup "Cup contact area [m2]";
  parameter Real p_vac_target(unit="Pa") = -2000.0 "Target vacuum for grasp [not specified, nominal]";

  // ===== Control parameters =====
  parameter Real K_imp(unit="N/m") = 800.0 "Impedance stiffness";
  parameter Real B_imp(unit="N.s/m") = 60.0 "Impedance damping";
  parameter Real F_setpoint(unit="N") = 15.0 "Desired normal contact force";
  parameter Real Kf_reg(unit="N/N") = 10.0 "Force regulation proportional gain";
  parameter Real Kf_int(unit="1/s") = 20.0 "Force regulation integral gain";
  parameter Real v_descent(unit="m/s") = 0.05 "Descent velocity during impedance approach";
  parameter Real y_init(unit="m") = 0.15 "Initial carriage height";
  parameter Real y_ref_target(unit="m") = 0.03 "Impedance reference target height";

  // ===== Disturbance parameters =====
  parameter Real F_dist(unit="N") = 5.6 "Tangential disturbance magnitude [specified]";
  parameter Real t_dist_start(unit="s") = 10.0 / 3.0 "Disturbance start (middle third)";
  parameter Real t_dist_end(unit="s") = 2.0 * 10.0 / 3.0 "Disturbance end (middle third)";

  // ===== Dynamic states: vertical (normal) direction =====
  Real y_carriage(start=0.15, fixed=true) "Carriage vertical position [m]";
  Real v_carriage(start=0.0, fixed=true) "Carriage vertical velocity [m/s]";
  Real y_obj(start=0.02, fixed=true) "Object center vertical position [m]";
  Real v_obj_y(start=0.0, fixed=true) "Object vertical velocity [m/s]";

  // ===== Dynamic states: tangential direction =====
  Real x_obj(start=0.0, fixed=true) "Object tangential position [m]";
  Real v_obj_x(start=0.0, fixed=true) "Object tangential velocity [m/s]";

  // ===== Dynamic states: control =====
  Real y_ref(start=0.15, fixed=true) "Impedance reference position [m]";
  Real force_int(start=0.0, fixed=true) "Force regulation integral state [N]";
  Real p_vacuum_filt(start=0.0, fixed=true) "Filtered vacuum pressure [Pa]";

  // ===== Force and pressure variables =====
  Real F_normal(start=0.0) "Normal contact force cup-object [N]";
  Real F_table_n(start=0.0) "Normal contact force from table [N]";
  Real F_friction(start=0.0) "Tangential friction force [N]";
  Real F_actuator(start=0.0) "Actuator force on carriage [N]";
  Real F_actuator_cmd(start=0.0) "Commanded actuator force [N]";
  Real F_vacuum(start=0.0) "Vacuum grasping force [N]";
  Real p_vacuum(start=0.0) "Vacuum pressure command [Pa]";
  Real F_disturbance(start=0.0) "Applied disturbance force [N]";

  // ===== Performance metrics =====
  Real tracking_error(start=0.0) "Primary tracking error [m]";
  Real obj_displacement(start=0.0) "Object displacement from initial [m]";

  // ===== Phase indicator =====
  Integer phase(start=1) "1=impedance, 2=force_reg+disturbance, 3=hold";

  // ===== Contact and grasp indicators =====
  Boolean in_contact "True if cup-object contact active";
  Boolean on_table "True if object resting on table";
  Boolean grasp_active "True if vacuum grasp active";
  Boolean grasp_lost "True if grasp lost";

  // ===== Penetration variables =====
  Real pen_cup(start=0.0) "Cup-object penetration depth [m]";
  Real pen_table(start=0.0) "Object-table penetration depth [m]";

  // ===== Sampled traces at 100 Hz =====
  Real y_carriage_s(start=0.15) "Sampled carriage position [m]";
  Real v_carriage_s(start=0.0) "Sampled carriage velocity [m/s]";
  Real y_obj_s(start=0.02) "Sampled object y position [m]";
  Real x_obj_s(start=0.0) "Sampled object x position [m]";
  Real F_normal_s(start=0.0) "Sampled normal contact force [N]";
  Real F_table_n_s(start=0.0) "Sampled table normal force [N]";
  Real F_actuator_s(start=0.0) "Sampled actuator force [N]";
  Real p_vacuum_s(start=0.0) "Sampled vacuum pressure [Pa]";
  Real tracking_error_s(start=0.0) "Sampled tracking error [m]";
  Real phase_s(start=1.0) "Sampled phase indicator";

equation
  // ===== Phase determination =====
  phase = if time < t_dist_start then 1 else (if time < t_dist_end then 2 else 3);

  // ===== Disturbance injection during middle third =====
  F_disturbance = if (phase == 2) then F_dist else 0.0;

  // ===== Penetration depths (collision enabled) =====
  pen_cup = max(0.0, (y_obj + h_obj / 2.0) - y_carriage);
  pen_table = max(0.0, h_obj / 2.0 - y_obj);

  // ===== Contact detection =====
  in_contact = pen_cup > 0.0;
  on_table = pen_table > 0.0;

  // ===== Normal contact force (cup-object) with restitution =====
  F_normal = if pen_cup > 0.0 then
    max(0.0, k_contact * pen_cup + b_contact * (1.0 + e_rest) * (v_obj_y - v_carriage))
  else 0.0;

  // ===== Table normal contact force with restitution =====
  F_table_n = if pen_table > 0.0 then
    max(0.0, k_table * pen_table + b_table * (1.0 + e_rest) * (-v_obj_y))
  else 0.0;

  // ===== Vacuum pressure command (first-order response) =====
  der(p_vacuum_filt) = ((if in_contact then p_vac_target else p_cmd_min) - p_vacuum_filt) / tau_vacuum;
  p_vacuum = max(p_cmd_max, min(p_cmd_min, p_vacuum_filt));

  // ===== Vacuum grasping force =====
  F_vacuum = abs(p_vacuum) * A_cup;

  // ===== Grasp status =====
  grasp_active = in_contact and (p_vacuum < -100.0);
  grasp_lost = (time > t_dist_start + 0.5) and (not in_contact);

  // ===== Carriage dynamics (vertical) =====
  der(y_carriage) = v_carriage;
  m_cup * der(v_carriage) = F_actuator - m_cup * g + F_normal
    - (if grasp_active then F_vacuum else 0.0);

  // ===== Object dynamics (vertical) =====
  der(y_obj) = v_obj_y;
  m_obj * der(v_obj_y) = -m_obj * g - F_normal + F_table_n
    + (if grasp_active then F_vacuum else 0.0);

  // ===== Object dynamics (tangential) =====
  der(x_obj) = v_obj_x;
  m_obj * der(v_obj_x) = F_disturbance - F_friction;

  // ===== Tangential friction (smooth Coulomb) =====
  F_friction = mu * (F_normal + F_table_n + (if grasp_active then F_vacuum else 0.0))
    * tanh(v_obj_x / v_thresh);

  // ===== Impedance reference trajectory =====
  der(y_ref) = if (phase == 1) and (y_ref > y_ref_target) then -v_descent else 0.0;

  // ===== Force regulation integral (active in phases 2 and 3) =====
  der(force_int) = if phase >= 2 then Kf_int * (F_normal - F_setpoint) else 0.0;

  // ===== Actuator force command =====
  F_actuator_cmd = if phase == 1 then
    // Impedance: spring-damper toward reference + gravity compensation
    K_imp * (y_ref - y_carriage) - B_imp * v_carriage + m_cup * g
  else
    // Force regulation: proportional + integral + gravity compensation
    Kf_reg * (F_normal - F_setpoint) + force_int + m_cup * g;

  // ===== Actuator force saturation =====
  F_actuator = max(-F_cmd_max, min(F_cmd_max, F_actuator_cmd));

  // ===== Tracking error =====
  tracking_error = abs(y_carriage - y_ref);

  // ===== Object displacement from initial position =====
  obj_displacement = sqrt(x_obj * x_obj + (y_obj - 0.02) * (y_obj - 0.02));

  // ===== Sampled sensor traces at 100 Hz =====
  when sample(0, 0.01) then
    y_carriage_s = y_carriage;
    v_carriage_s = v_carriage;
    y_obj_s = y_obj;
    x_obj_s = x_obj;
    F_normal_s = F_normal;
    F_table_n_s = F_table_n;
    F_actuator_s = F_actuator;
    p_vacuum_s = p_vacuum;
    tracking_error_s = tracking_error;
    phase_s = phase;
  end when;

  annotation(
    experiment(StartTime=0, StopTime=10, Tolerance=1e-6, Interval=0.01),
    Documentation(info="Vacuum tool grasp mission (VacuumToolGraspB).
      Phase 1 (0-3.33s): Impedance approach to object on rigid table.
      Phase 2 (3.33-6.67s): Force regulation with 5.6N tangential disturbance.
      Phase 3 (6.67-10s): Hold with force regulation.
      Sensors at 100 Hz: actuator state, normal contact forces, object pose.
      Requirements: tracking error < 0.018m after 6.5s, stable contact,
      bounded object displacement, no grasp loss, effort <= 262N.
      Unspecified object properties use nominal values noted in parameter comments.")
  );
end VacuumToolGraspB;