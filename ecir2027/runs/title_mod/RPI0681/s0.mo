model HydBoomForceC
  "Hydraulic robotic actuator with cascaded pressure and force regulation against compliant load"

  // === Geometry and Mass ===
  parameter Real L_boom = 2.0 "Boom length [m]";
  parameter Real L_stick = 1.4 "Stick length [m]";
  parameter Real m_payload = 300.0 "Payload mass [kg]";
  parameter Real m_eff_stick = 100.0 "Effective reflected mass at stick cylinder [kg]";
  parameter Real m_eff_boom = 50.0 "Effective reflected mass at boom cylinder [kg]";
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";

  // === Cylinder Parameters ===
  parameter Real A_a = 0.002 "Piston (cap-side) area [m2]";
  parameter Real A_b = 0.001 "Rod-side annular area [m2]";
  parameter Real V_dead = 3.0e-3 "Cylinder dead volume per chamber [m3]";
  parameter Real L_cyl = 0.5 "Cylinder stroke [m]";
  parameter Real Beta_e = 3.0e7 "Effective fluid bulk modulus [Pa]";
  parameter Real n_lever = 2.0 "Lever ratio from stick cylinder to end-effector [-]";

  // === Hydraulic Supply (load-sensing pump + relief) ===
  parameter Real p_supply = 1.0e7 "Nominal supply pressure [Pa]";
  parameter Real p_tank = 1.0e5 "Tank / return pressure [Pa]";
  parameter Real p_relief = 1.5e7 "Relief valve cracking pressure [Pa]";
  parameter Real q_max = 0.003 "Maximum pump flow command [m3/s]";
  parameter Real Kv_relief = 5.0e-7 "Relief valve conductance [m3/(s.Pa)]";

  // === Contact ===
  parameter Real k_contact = 2.0e5 "Contact stiffness [N/m]";
  parameter Real b_contact = 2.0e3 "Contact damping [N.s/m]";
  parameter Real x_env = 0.04 "Environment contact position [m]";

  // === Loads ===
  parameter Real F_grav_stick = 2000.0 "Reflected gravity load at stick cylinder [N]";
  parameter Real F_grav_boom = 3000.0 "Reflected gravity load at boom cylinder [N]";
  parameter Real F_dist = 135.0 "Disturbance load change magnitude [N]";

  // === Boom structural compliance ===
  parameter Real k_boom_spring = 1.0e4 "Boom structural stiffness [N/m]";
  parameter Real b_boom_damp = 1.0e3 "Boom structural damping [N.s/m]";

  // === Controller gains ===
  parameter Real F_cmd = 800.0 "Commanded output force [N]";
  parameter Real Kp_f = 2000.0 "Outer force loop proportional gain [Pa/N]";
  parameter Real Ki_f = 3000.0 "Outer force loop integral gain [Pa/(N.s)]";
  parameter Real Kp_p = 3.0e-7 "Inner pressure loop proportional gain [1/Pa]";
  parameter Real Kp_boom = 2.0 "Boom position P gain [1/m]";
  parameter Real Kd_boom = 2.0 "Boom position D gain [s/m]";

  // === Dynamic states ===
  Real x_cyl "Stick cylinder extension [m]";
  Real v_cyl "Stick cylinder velocity [m/s]";
  Real p_a "Stick cylinder cap-side pressure [Pa]";
  Real p_b "Stick cylinder rod-side pressure [Pa]";
  Real x_boom "Boom cylinder extension [m]";
  Real v_boom "Boom cylinder velocity [m/s]";
  Real p_boom "Boom cylinder cap-side pressure [Pa]";
  Real integ_f "Force loop integrator state [Pa]";

  // === Sensors and computed variables ===
  Real x_ee "End-effector position [m]";
  Real v_ee "End-effector velocity [m/s]";
  Real F_contact "Measured external contact force [N]";
  Real F_cyl "Stick cylinder net force [N]";
  Real dp "Stick pressure differential [Pa]";
  Real dp_cmd "Commanded pressure differential [Pa]";
  Real dp_ff "Feedforward pressure differential [Pa]";
  Real F_error "Force tracking error [N]";
  Real u_valve "Stick valve command (clamped) [-]";
  Real u_valve_raw "Stick valve command (unclamped) [-]";
  Real q_a "Flow into stick cap side [m3/s]";
  Real q_b "Flow out of stick rod side [m3/s]";
  Real q_pump "Total pump flow [m3/s]";
  Real F_disturbance "Applied disturbance force [N]";
  Real F_boom_cyl "Boom cylinder net force [N]";
  Real u_boom "Boom valve command [-]";
  Real q_boom "Boom valve flow [m3/s]";
  Real V_a "Stick cap-side volume [m3]";
  Real V_b "Stick rod-side volume [m3]";
  Real V_boom_vol "Boom cap-side volume [m3]";
  Real q_relief_a "Stick cap-side relief flow [m3/s]";
  Real q_relief_b "Stick rod-side relief flow [m3/s]";
  Real abs_u_valve_raw "Absolute unclamped valve command [-]";

initial equation
  x_cyl = 0.02;
  v_cyl = 0.0;
  p_a = 1.5e6;
  p_b = 1.0e5;
  x_boom = 0.1;
  v_boom = 0.0;
  p_boom = 2.0e6;
  integ_f = 0.0;

equation
  // ===== End-effector kinematics =====
  x_ee = n_lever * x_cyl;
  v_ee = n_lever * v_cyl;

  // ===== Compliant contact force =====
  F_contact = k_contact * (x_ee - x_env) + b_contact * v_ee;

  // ===== Disturbance: 135 N during middle third (4-8 s of 12 s) =====
  F_disturbance = if time >= 4.0 and time <= 8.0 then F_dist else 0.0;

  // ===== Stick cylinder force and pressure differential =====
  F_cyl = p_a * A_a - p_b * A_b;
  dp = p_a - p_b;

  // ===== Chamber volumes =====
  V_a = V_dead + A_a * x_cyl;
  V_b = V_dead + A_b * (L_cyl - x_cyl);
  V_boom_vol = V_dead + A_a * x_boom;

  // ===== Relief valve protection (overpressure) =====
  q_relief_a = if p_a > p_relief then Kv_relief * (p_a - p_relief) else 0.0;
  q_relief_b = if p_b > p_relief then Kv_relief * (p_b - p_relief) else 0.0;

  // ===== Valve flows (linear valve, command in [-1, 1]) =====
  q_a = u_valve * q_max;
  q_b = u_valve * q_max;
  q_boom = u_boom * q_max * 0.3;

  // ===== Pump flow (shared, supply-limited) =====
  q_pump = abs(u_valve) * q_max + abs(u_boom) * q_max * 0.3;

  // ===== Stick pressure dynamics (continuity) =====
  der(p_a) = (Beta_e / V_a) * (q_a - A_a * v_cyl - q_relief_a);
  der(p_b) = (Beta_e / V_b) * (A_b * v_cyl - q_b - q_relief_b);

  // ===== Stick mechanical dynamics =====
  der(v_cyl) = (F_cyl - n_lever * F_contact - F_grav_stick - F_disturbance) / m_eff_stick;
  der(x_cyl) = v_cyl;

  // ===== Cascaded controller — outer force loop =====
  F_error = F_cmd - F_contact;
  dp_ff = (n_lever * F_cmd + F_grav_stick) / A_a;

  // Anti-windup: halt integration when valve saturates
  abs_u_valve_raw = abs(u_valve_raw);
  der(integ_f) = if abs_u_valve_raw < 0.999 then F_error else 0.0;

  dp_cmd = dp_ff + Kp_f * F_error + Ki_f * integ_f;

  // ===== Inner pressure loop (proportional) =====
  u_valve_raw = Kp_p * (dp_cmd - dp);
  u_valve = max(-1.0, min(1.0, u_valve_raw));

  // ===== Boom cylinder — position hold with gravity compensation =====
  F_boom_cyl = p_boom * A_a - p_tank * A_b;
  u_boom = max(-1.0, min(1.0, Kp_boom * (0.1 - x_boom) - Kd_boom * v_boom));

  der(p_boom) = (Beta_e / V_boom_vol) * (q_boom - A_a * v_boom);
  der(v_boom) = (F_boom_cyl - F_grav_boom - k_boom_spring * (x_boom - 0.1) - b_boom_damp * v_boom) / m_eff_boom;
  der(x_boom) = v_boom;

  annotation(
    experiment(StartTime = 0, StopTime = 12, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info = "HydBoomForceC: Hydraulic boom-and-stick robotic actuator with cascaded pressure (inner) and force (outer) regulation. Two double-acting cylinders share a load-sensing pump (q_max = 0.003 m3/s) and relief valve. The stick cylinder regulates contact force against a compliant environment; the boom cylinder holds position against gravity. A 135 N load disturbance is injected during the middle third (4-8 s). Chamber pressures, actuator state, and contact force are measured as synchronized sensor traces."),
    Diagram(graphics = {Text(extent = {{-100, 80}, {100, 60}}, textString = "HydBoomForceC")})
  );
end HydBoomForceC;