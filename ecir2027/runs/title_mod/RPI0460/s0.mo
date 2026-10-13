model VacuumToolGraspD
  "Instrumented contact-rich vacuum grasp with impedance motion and force regulation"

  // Controller and simulation timing
  parameter Real Ts = 0.005 "controller sample period (s)";
  parameter Real t_descent_end = 1.5 "controller descent end time, control design only (s)";

  // Specified plant facts
  parameter Real m_cup = 0.8 "cup and carriage mass (kg)";
  parameter Real r_cup = 0.038 "suction cup radius (m)";
  parameter Real p_cmd_min = -70.0e3 "minimum gauge pressure command (Pa)";
  parameter Real p_cmd_max = 0.0 "maximum gauge pressure command (Pa)";
  parameter Real F_lin_limit = 320.0 "linear actuator effort bound (N)";
  parameter Real mu_table = 0.78 "table/contact friction coefficient (1)";
  parameter Real e_restitution = 0.03 "table collision restitution (1)";
  parameter Real g = 9.81 "gravity acceleration (m/s2)";
  parameter Real F_disturbance = 8.0 "tangential load disturbance (N)";
  parameter Real t_start_dist = 14.0/3.0 "disturbance start, middle third (s)";
  parameter Real t_end_dist = 28.0/3.0 "disturbance end, middle third (s)";

  // Control design values (not stated plant facts)
  parameter Real F_normal_ref = 10.0 "regulated mechanical normal force (N)";
  parameter Real F_contact_thresh = 1.0 "contact detection threshold (N)";
  parameter Real K_imp = 800.0 "impedance position gain (N/m)";
  parameter Real D_imp = 40.0 "impedance damping gain (N.s/m)";
  parameter Real Kf = 1.0 "force regulation proportional gain (N/N)";
  parameter Real Ki = 10.0 "force regulation integral gain (N/(N.s))";
  parameter Real v_eps = 1.0e-6 "static velocity threshold (m/s)";

  // Unspecified physical values: placeholders for compilation only, not claimed facts
  parameter Real z_tip_start = 0.02 "initial cup-table gap placeholder (m)";
  parameter Real k_contact = 2000.0 "cup compliance placeholder (N/m)";
  parameter Real m_object = 1.0 "object mass placeholder, used only if friction limit is exceeded (kg)";

  // Bounds required by the request
  parameter Real z_travel_min = -0.02 "lower travel bound (m)";
  parameter Real z_travel_max = 0.05 "upper travel bound (m)";
  parameter Real x_obj_bound = 0.015 "object displacement bound (m)";
  parameter Real tracking_bound = 0.015 "primary tracking bound after 9.1 s (m)";

  // Derived constants
  final parameter Real A_cup = Modelica.Constants.pi*r_cup*r_cup "suction cup area (m2)";
  final parameter Real d_contact =
    2.0*sqrt(k_contact*m_cup)*
    abs(log(e_restitution)/sqrt(Modelica.Constants.pi*Modelica.Constants.pi
      + log(e_restitution)*log(e_restitution)))
    "contact damping from restitution (N.s/m)";
  final parameter Real F_vacuum_limit = A_cup*(-p_cmd_min) "vacuum effort at full command (N)";

  // Dynamic states
  Real z_tip(start=z_tip_start, fixed=true) "cup tip vertical position, upward positive (m)";
  Real v_z(start=0.0, fixed=true) "cup tip vertical velocity (m/s)";
  Real x_obj(start=0.0, fixed=true) "object horizontal pose (m)";
  Real v_obj(start=0.0, fixed=true) "object horizontal velocity (m/s)";
  Real object_z(start=0.0) = 0.0 "object vertical pose constrained by rigid table (m)";

  // Discrete controller states
  discrete Real F_cmd_raw(start=m_cup*g) "unbounded linear actuator command (N)";
  discrete Real p_cmd_raw(start=0.0) "unbounded pressure command (Pa)";
  discrete Real intF(start=0.0) "force regulator integrator (N.s)";
  discrete Real mode(start=0.0) "controller mode, 0 impedance, 1 force regulation (1)";
  discrete Boolean contact_detected(start=false) "contact latched";
  discrete Real tick_counter(start=0.0) "synchronized trace counter (1)";
  discrete Real last_sample_time(start=-Ts) "last controller sample time (s)";

  // Algebraic variables
  Real z_ref "vertical reference position (m)";
  Real F_cmd_limited "bounded linear actuator command, positive upward (N)";
  Real p_cmd_limited "bounded pressure command (Pa)";
  Real F_vacuum "vacuum holding force magnitude (N)";
  Real F_contact_mech "mechanical cup-object/table normal contact force (N)";
  Real F_grasp_normal "total grasp normal force including vacuum (N)";
  Real F_table_normal "object-table normal contact force sensor (N)";
  Real F_dist "applied tangential disturbance load (N)";
  Real F_fric_max "friction limit (N)";
  Real F_fric "physical friction force on object, opposing motion (N)";
  Real sgnDist "sign of disturbance (1)";
  Real sgnV "sign of object velocity (1)";
  Real tracking_error "primary vertical tracking error (m)";
  Real object_pose_norm "object pose displacement norm (m)";

  // Observable sensor, command, and state traces
  Real actuator_travel = z_tip "m";
  Real linear_actuator_effort = F_cmd_limited "N";
  Real vacuum_actuator_effort = F_vacuum "N";
  Real primary_tracking_error = tracking_error "m";
  Real object_displacement = object_pose_norm "m";

  Real sensor_actuator_position = z_tip "m";
  Real sensor_actuator_velocity = v_z "m/s";
  Real sensor_actuator_force = F_cmd_limited "N";
  Real sensor_pressure_command = p_cmd_limited "Pa";
  Real sensor_pressure_command_kPa = p_cmd_limited/1000.0 "kPa";
  Real sensor_vacuum_effort = F_vacuum "N";
  Real sensor_contact_force_mech = F_contact_mech "N";
  Real sensor_grasp_normal = F_grasp_normal "N";
  Real sensor_table_normal = F_table_normal "N";
  Real sensor_disturbance_load = F_dist "N";
  Real sensor_friction_force = F_fric "N";
  Real sensor_object_x = x_obj "m";
  Real sensor_object_z = object_z "m";
  Real sensor_object_pose_norm = object_pose_norm "m";

  Real command_force = F_cmd_limited "N";
  Real command_pressure = p_cmd_limited "Pa";
  Real command_pressure_kPa = p_cmd_limited/1000.0 "kPa";
  Real state_time = time "s";
  Real command_time = time "s";
  Real sensor_time = time "s";
  Real controller_tick = tick_counter "1";
  Real controller_sample_time = last_sample_time "s";
  Real controller_mode = mode "1";

  Boolean contact_latched = contact_detected "1";
  Boolean stable_contact = F_contact_mech > 0.0 "1";
  Boolean grasp_ok = F_grasp_normal >= F_disturbance/mu_table + 1.0 "1";
  Boolean grasp_loss = contact_detected and not grasp_ok "1";

initial equation
  F_cmd_raw = m_cup*g;
  p_cmd_raw = 0.0;
  intF = 0.0;
  mode = 0.0;
  contact_detected = false;
  tick_counter = 0.0;
  last_sample_time = -Ts;

equation
  // Parameter sanity
  assert(Ts > 0.0, "sample period must be positive");
  assert(t_descent_end > 0.0, "descent end time must be positive");
  assert(m_cup > 0.0, "cup mass must be positive");
  assert(r_cup > 0.0, "suction cup radius must be positive");
  assert(p_cmd_min < p_cmd_max, "pressure command range invalid");
  assert(F_lin_limit > 0.0, "linear actuator limit must be positive");
  assert(mu_table > 0.0, "friction coefficient must be positive");
  assert(e_restitution > 0.0 and e_restitution <= 1.0, "restitution must be in (0,1]");
  assert(k_contact > 0.0, "contact stiffness placeholder must be positive");
  assert(m_object > 0.0, "object mass placeholder must be positive");
  assert(F_normal_ref > 0.0, "regulated normal force must be positive");
  assert(z_tip_start > 0.0, "initial gap placeholder must be positive");
  assert(F_vacuum_limit <= F_lin_limit + 1.0e-6, "vacuum effort at full pressure exceeds actuator bound");

  // Reference and disturbance
  z_ref = if time <= t_descent_end then z_tip_start*(1.0 - time/t_descent_end) else 0.0;
  F_dist = if time >= t_start_dist and time <= t_end_dist then F_disturbance else 0.0;
  sgnDist = if F_dist > 0.0 then 1.0 elseif F_dist < 0.0 then -1.0 else 0.0;
  sgnV = if v_obj > 0.0 then 1.0 elseif v_obj < 0.0 then -1.0 else 0.0;

  // Bounded actuator commands
  F_cmd_limited = max(-F_lin_limit, min(F_lin_limit, F_cmd_raw));
  p_cmd_limited = max(p_cmd_min, min(p_cmd_max, p_cmd_raw));
  F_vacuum = max(0.0, -p_cmd_limited)*A_cup;

  // Collision-enabled mechanical contact with cup compliance
  F_contact_mech = if z_tip <= 0.0 then max(0.0, k_contact*(-z_tip) + d_contact*(-v_z)) else 0.0;

  // Cup vertical dynamics
  der(z_tip) = v_z;
  m_cup*der(v_z) = F_cmd_limited - m_cup*g + F_contact_mech;

  // Grasp and table normal forces
  F_grasp_normal = max(0.0, F_contact_mech + F_vacuum);
  F_table_normal = max(0.0, F_grasp_normal);

  // Object horizontal dynamics with friction
  F_fric_max = mu_table*F_grasp_normal;
  if abs(v_obj) > v_eps then
    F_fric = -sgnV*F_fric_max;
    der(v_obj) = (F_dist + F_fric)/m_object;
  elseif abs(F_dist) <= F_fric_max then
    F_fric = -F_dist;
    der(v_obj) = 0.0;
  else
    F_fric = -sgnDist*F_fric_max;
    der(v_obj) = (F_dist + F_fric)/m_object;
  end if;
  der(x_obj) = v_obj;

  // Tracking and pose
  tracking_error = abs(z_ref - z_tip);
  object_pose_norm = sqrt(x_obj*x_obj + object_z*object_z);

  // Requirement bounds
  assert(actuator_travel >= z_travel_min and actuator_travel <= z_travel_max, "travel bound violated");
  assert(abs(linear_actuator_effort) <= F_lin_limit + 1.0e-6, "linear actuator effort bound violated");
  assert(vacuum_actuator_effort <= F_lin_limit + 1.0e-6, "vacuum actuator effort bound violated");
  assert(object_displacement <= x_obj_bound + 1.0e-9, "object displacement bound violated");
  assert(time < 3.0 or stable_contact, "stable contact lost after 3 s");
  assert(not (time >= t_start_dist and time <= t_end_dist) or grasp_ok, "grasp loss risk during disturbance");
  assert(time < 9.1 or primary_tracking_error <= tracking_bound + 1.0e-9, "primary tracking error bound violated after 9.1 s");

  // Finite physical, control, and estimator-state checks
  assert(z_tip == z_tip and z_tip < 1.0e12 and z_tip > -1.0e12, "NaN/Inf z_tip");
  assert(v_z == v_z and v_z < 1.0e12 and v_z > -1.0e12, "NaN/Inf v_z");
  assert(x_obj == x_obj and x_obj < 1.0e12 and x_obj > -1.0e12, "NaN/Inf x_obj");
  assert(v_obj == v_obj and v_obj < 1.0e12 and v_obj > -1.0e12, "NaN/Inf v_obj");
  assert(F_cmd_raw == F_cmd_raw and F_cmd_raw < 1.0e12 and F_cmd_raw > -1.0e12, "NaN/Inf F_cmd_raw");
  assert(F_cmd_limited == F_cmd_limited and F_cmd_limited < 1.0e12 and F_cmd_limited > -1.0e12, "NaN/Inf F_cmd_limited");
  assert(p_cmd_raw == p_cmd_raw and p_cmd_raw < 1.0e12 and p_cmd_raw > -1.0e12, "NaN/Inf p_cmd_raw");
  assert(p_cmd_limited == p_cmd_limited and p_cmd_limited < 1.0e12 and p_cmd_limited > -1.0e12, "NaN/Inf p_cmd_limited");
  assert(intF == intF and intF < 1.0e12 and intF > -1.0e12, "NaN/Inf intF");
  assert(mode == mode and mode < 1.0e12 and mode > -1.0e12, "NaN/Inf mode");
  assert(tick_counter == tick_counter and tick_counter < 1.0e12 and tick_counter > -1.0e12, "NaN/Inf tick_counter");
  assert(last_sample_time == last_sample_time and last_sample_time < 1.0e12 and last_sample_time > -1.0e12, "NaN/Inf last_sample_time");
  assert(F_contact_mech == F_contact_mech and F_contact_mech < 1.0e12 and F_contact_mech > -1.0e12, "NaN/Inf F_contact_mech");
  assert(F_vacuum == F_vacuum and F_vacuum < 1.0e12 and F_vacuum > -1.0e12, "NaN/Inf F_vacuum");
  assert(F_grasp_normal == F_grasp_normal and F_grasp_normal < 1.0e12 and F_grasp_normal > -1.0e12, "NaN/Inf F_grasp_normal");
  assert(F_table_normal == F_table_normal and F_table_normal < 1.0e12 and F_table_normal > -1.0e12, "NaN/Inf F_table_normal");
  assert(F_dist == F_dist and F_dist < 1.0e12 and F_dist > -1.0e12, "NaN/Inf F_dist");
  assert(F_fric_max == F_fric_max and F_fric_max < 1.0e12 and F_fric_max > -1.0e12, "NaN/Inf F_fric_max");
  assert(F_fric == F_fric and F_fric < 1.0e12 and F_fric > -1.0e12, "NaN/Inf F_fric");
  assert(tracking_error == tracking_error and tracking_error < 1.0e12 and tracking_error > -1.0e12, "NaN/Inf tracking_error");
  assert(object_pose_norm == object_pose_norm and object_pose_norm < 1.0e12 and object_pose_norm > -1.0e12, "NaN/Inf object_pose_norm");

  // 200 Hz sampled controller: impedance motion, then force regulation and vacuum grasp
  when sample(0.0, Ts) then
    contact_detected := pre(contact_detected) or (F_contact_mech > F_contact_thresh);
    if (pre(contact_detected) or (F_contact_mech > F_contact_thresh)) then
      intF := pre(intF) + Ts*(F_normal_ref - F_contact_mech);
      F_cmd_raw := m_cup*g - Kf*(F_normal_ref - F_contact_mech)
        - Ki*(pre(intF) + Ts*(F_normal_ref - F_contact_mech));
      p_cmd_raw := p_cmd_min;
      mode := 1.0;
    else
      intF := 0.0;
      F_cmd_raw := m_cup*g + K_imp*(z_ref - z_tip) - D_imp*v_z;
      p_cmd_raw := 0.0;
      mode := 0.0;
    end if;
    tick_counter := pre(tick_counter) + 1.0;
    last_sample_time := time;
  end when;

  annotation (experiment(StopTime=14.0, Interval=0.005, Tolerance=1.0e-6));
end VacuumToolGraspD;