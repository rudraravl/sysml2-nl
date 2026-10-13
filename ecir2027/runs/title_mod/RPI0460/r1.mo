model VacuumToolGraspD
  "Instrumented contact-rich manipulation: vacuum tool grasp with impedance and force regulation"

  // ===== Physical Constants =====
  parameter Real pi_val = 3.141592653589793 "Pi";
  parameter Real g_acc = 9.81 "Gravitational acceleration [m/s2]";

  // ===== Physical Parameters =====
  parameter Real m_cup = 0.8 "Suction cup mass [kg]";
  parameter Real r_cup = 0.038 "Suction cup radius [m]";
  parameter Real A_cup = pi_val * r_cup * r_cup "Cup effective area [m2]";
  parameter Real m_obj = 0.5 "Object mass [kg] (assumed - not specified in requirement)";

  parameter Real k_cup = 20000.0 "Cup compliance stiffness [N/m] (assumed)";
  parameter Real d_cup = 116.0 "Cup damping [N.s/m] (derived from restitution e=0.03)";
  parameter Real k_table = 100000.0 "Table stiffness [N/m] (assumed)";
  parameter Real d_table = 330.0 "Table damping [N.s/m] (derived from restitution e=0.03)";

  parameter Real mu = 0.78 "Friction coefficient [-]";
  parameter Real e_rest = 0.03 "Restitution coefficient [-]";

  parameter Real F_lin_max = 320.0 "Linear actuator force bound [N]";
  parameter Real P_vac_range = 70000.0 "Vacuum pressure range max magnitude [Pa]";
  parameter Real P_vac_cmd = 15000.0 "Commanded vacuum magnitude [Pa] (within 0-70 kPa range)";

  // Geometry (assumed where not specified)
  parameter Real h_obj = 0.05 "Object height [m] (assumed)";
  parameter Real z_cup0 = 0.10 "Initial cup position [m] (assumed)";
  parameter Real z_contact_target = h_obj "Target contact height [m]";

  // Controller parameters
  parameter Real K_imp = 800.0 "Impedance stiffness [N/m]";
  parameter Real B_imp = 40.0 "Impedance damping [N.s/m]";
  parameter Real F_ref = 75.0 "Reference contact spring force [N]";
  parameter Real Kf = 0.0001 "Force regulation gain [m/(N.s)]";
  parameter Real t_contact = 3.0 "Contact acquisition time [s]";
  parameter Real tau_vac = 0.5 "Vacuum ramp time constant [s]";
  parameter Real T_sim = 14.0 "Total simulation duration [s]";
  parameter Real F_dist_mag = 8.0 "Tangential disturbance magnitude [N]";
  parameter Real dt_sample = 0.005 "Controller sample period [s] (200 Hz)";

  // ===== Dynamic States =====
  Real z_cup(start = z_cup0, fixed = true) "Cup vertical position [m]";
  Real v_cup(start = 0.0, fixed = true) "Cup vertical velocity [m/s]";
  Real z_obj(start = h_obj/2, fixed = true) "Object center vertical position [m]";
  Real vz_obj(start = 0.0, fixed = true) "Object vertical velocity [m/s]";
  Real x_obj(start = 0.0, fixed = true) "Object horizontal position [m]";
  Real vx_obj(start = 0.0, fixed = true) "Object horizontal velocity [m/s]";
  Real z_adj(start = 0.0, fixed = true) "Force regulation position adjustment [m]";

  // ===== Computed Variables =====
  Real z_obj_top "Object top surface height [m]";
  Real pen_cup "Cup-object penetration [m]";
  Real F_spring "Cup spring contact force [N]";
  Real P_vac "Vacuum pressure command [Pa] (gauge, negative)";
  Real F_vac "Vacuum attractive force [N]";
  Real pen_table "Table penetration [m]";
  Real F_table "Table normal force [N]";
  Real F_friction_max "Maximum friction force [N]";
  Real F_dist "Tangential disturbance [N]";
  Real z_ref "Reference height [m]";
  Real F_ff "Feedforward force [N]";
  Real F_cmd_raw "Raw force command [N]";
  Real F_actuator "Saturated actuator force [N]";
  Real tracking_error "Primary tracking error [m]";

  // ===== Synchronized Sensor Outputs (200 Hz traces) =====
  output Real meas_z_cup "Measured cup position [m]";
  output Real meas_v_cup "Measured cup velocity [m/s]";
  output Real meas_F_normal "Measured normal contact force [N]";
  output Real meas_x_obj "Measured object x-pose [m]";
  output Real meas_z_obj "Measured object z-pose [m]";
  output Real meas_P_vac "Measured vacuum pressure [Pa]";
  output Real meas_F_actuator "Measured actuator force [N]";
  output Real meas_F_cmd "Measured force command [N]";

  // ===== Validation Outputs =====
  output Boolean err_ok "Tracking error < 0.015 m after 9.1 s";
  output Boolean bounds_ok "Travel and effort bounds satisfied";
  output Boolean grasp_held "Grasp not lost (vacuum active after acquisition)";
  output Boolean obj_bounded "Object displacement bounded";

protected
  parameter Real v_reg = 0.002 "Friction velocity regularization [m/s]";
  parameter Real eps = 1e-9 "Small number for zero branches";

equation
  // --- Geometry ---
  z_obj_top = z_obj + h_obj/2;

  // --- Cup-Object Contact (compliant suction cup, collision enabled) ---
  pen_cup = max(0.0, z_obj_top - z_cup);
  F_spring = if pen_cup > eps then
    max(0.0, k_cup * pen_cup + d_cup * (vz_obj - v_cup))
  else 0.0;
  // F_spring > 0: pushes cup up, object down

  // --- Vacuum Pressure Command (0 to -70 kPa gauge range) ---
  P_vac = if time >= t_contact then
    -P_vac_cmd * (1.0 - exp(-(time - t_contact)/tau_vac))
  else 0.0;
  F_vac = abs(P_vac) * A_cup;
  // F_vac attractive: pulls object up, cup down

  // --- Table Contact (rigid support, collision enabled) ---
  pen_table = max(0.0, h_obj/2 - z_obj);
  F_table = if pen_table > eps then
    max(0.0, k_table * pen_table - d_table * vz_obj)
  else 0.0;
  // F_table > 0: pushes object up

  // --- Friction (Coulomb with regularization, mu=0.78) ---
  // Grip from vacuum + table normal; both resist tangential motion
  F_friction_max = mu * (F_table + F_vac);

  // --- Tangential Disturbance: 8 N during middle third ---
  F_dist = if (time >= T_sim/3.0 and time <= 2.0*T_sim/3.0) then
    F_dist_mag else 0.0;

  // --- Controller: Impedance Motion then Force Regulation ---
  // Phase 1 (0 to t_contact): impedance descent to contact
  // Phase 2 (t_contact onward): force regulation via reference adjustment
  z_ref = if time < t_contact then
    z_cup0 - (z_cup0 - z_contact_target) * (1.0 - exp(-3.0 * time / t_contact))
  else
    z_contact_target - z_adj;

  // Force regulation integral: adjusts reference to regulate contact force
  der(z_adj) = if time >= t_contact then Kf * (F_spring - F_ref) else 0.0;

  // Feedforward: cup gravity (impedance handles contact and vacuum effects)
  F_ff = m_cup * g_acc;

  // Impedance control law
  F_cmd_raw = K_imp * (z_ref - z_cup) + B_imp * (0.0 - v_cup) + F_ff;

  // Actuator saturation (bounded to +/-320 N linear)
  F_actuator = if F_cmd_raw > F_lin_max then F_lin_max
    else if F_cmd_raw < -F_lin_max then -F_lin_max
    else F_cmd_raw;

  // --- Cup/Carriage Dynamics (vertical prismatic) ---
  der(z_cup) = v_cup;
  m_cup * der(v_cup) = F_actuator + F_spring - F_vac - m_cup * g_acc;

  // --- Object Vertical Dynamics ---
  der(z_obj) = vz_obj;
  m_obj * der(vz_obj) = -F_spring + F_vac - m_obj * g_acc + F_table;

  // --- Object Horizontal Dynamics (tangential) ---
  der(x_obj) = vx_obj;
  m_obj * der(vx_obj) = F_dist - F_friction_max * tanh(vx_obj / v_reg);

  // --- Tracking Error ---
  tracking_error = abs(z_ref - z_cup);

  // --- Synchronized Sensor Measurements ---
  meas_z_cup = z_cup;
  meas_v_cup = v_cup;
  meas_F_normal = F_spring;
  meas_x_obj = x_obj;
  meas_z_obj = z_obj;
  meas_P_vac = P_vac;
  meas_F_actuator = F_actuator;
  meas_F_cmd = F_cmd_raw;

  // --- Validation Flags ---
  err_ok = if time >= 9.1 then tracking_error < 0.015 else true;
  bounds_ok = (abs(z_cup - z_cup0) <= 0.2) and (abs(F_actuator) <= F_lin_max + eps);
  grasp_held = (time < t_contact) or (abs(P_vac) > 100.0);
  obj_bounded = (abs(x_obj) <= 0.02) and (abs(z_obj - h_obj/2) <= 0.02);

  annotation (
    Documentation(info="Instrumented vacuum-tool grasp system.
      Vertical prismatic carriage with 0.8 kg compliant suction cup (r=0.038 m).
      Vacuum pressure command range: 0 to -70 kPa gauge.
      Linear actuator bounded to 320 N.
      Impedance motion followed by force regulation.
      8 N tangential disturbance during middle third (4.67-9.33 s).
      200 Hz control, 14 s duration.
      Tracking error < 0.015 m after 9.1 s.
      Note: Object mass, cup stiffness, table stiffness, and controller gains
      are assumed (not specified in requirement)."),
    experiment(StopTime = 14.0, Interval = 0.005, Tolerance = 1e-6)
  );
end VacuumToolGraspD;