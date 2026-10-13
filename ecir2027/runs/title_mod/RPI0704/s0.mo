model AirStageForceB
  // ---- Physical parameters (SI units) ----
  parameter Real m_carriage = 42.0 "Carriage mass [kg]";
  parameter Real stroke = 0.70 "Cylinder stroke [m]";
  parameter Real r_piston = 0.025 "Piston radius [m]";
  parameter Real r_rod = 0.012 "Rod radius [m]";
  parameter Real A_a = 3.14159265358979*r_piston*r_piston "Cap-side area [m2]";
  parameter Real A_rod = 3.14159265358979*r_rod*r_rod "Rod cross-section area [m2]";
  parameter Real A_b = A_a - A_rod "Rod-side annular area [m2]";
  parameter Real L_dead = 0.02 "Dead-volume equivalent length [m]";
  parameter Real V_a0 = A_a*L_dead "Cap-side dead volume [m3]";
  parameter Real V_b0 = A_b*L_dead "Rod-side dead volume [m3]";
  parameter Real P_supply = 7.0e5 "Pneumatic supply pressure [Pa]";
  parameter Real P_atm = 1.01325e5 "Atmospheric pressure [Pa]";
  parameter Real P_relief = 6.0e5 "Relief valve cracking pressure [Pa]";
  parameter Real R_air = 287.0 "Specific gas constant of air [J/(kg.K)]";
  parameter Real T_air = 293.15 "Chamber gas temperature (isothermal) [K]";
  parameter Real m_dot_max = 0.012 "Allowed valve command magnitude [kg/s]";
  parameter Real k_contact = 1.0e5 "Compliant contact stiffness [N/m]";
  parameter Real d_contact = 1.0e3 "Compliant contact damping [N.s/m]";
  parameter Real x_contact = 0.65 "Contact onset position [m]";
  parameter Real d_friction = 50.0 "Viscous friction coefficient [N.s/m]";
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";

  // ---- Controller parameters ----
  parameter Real Kp_F = 2500.0 "Outer force-loop proportional gain [Pa/N]";
  parameter Real Ki_F = 1500.0 "Outer force-loop integral gain [Pa/(N.s)]";
  parameter Real Kp_p = 5.0e-6 "Inner pressure-loop proportional gain [kg/(s.Pa)]";
  parameter Real Ki_p = 5.0e-7 "Inner pressure-loop integral gain [kg/(s.Pa.s)]";
  parameter Real F_cmd_val = 100.0 "Commanded output (contact) force [N]";
  parameter Real F_dist_val = 105.0 "Disturbance load-change magnitude [N]";
  parameter Real t_dist_start = 10.0/3.0 "Disturbance injection start time [s]";
  parameter Real t_dist_end = 20.0/3.0 "Disturbance injection end time [s]";
  parameter Real Ts = 0.01 "Control / trace sample period (100 Hz) [s]";
  parameter Real t_end = 10.0 "Mission duration [s]";

  // ---- Initial conditions ----
  parameter Real x_start = 0.651 "Initial carriage position [m]";
  parameter Real p_a_start = 3.386e5 "Initial cap-side pressure [Pa]";
  parameter Real p_b_start = 1.01325e5 "Initial rod-side pressure [Pa]";

  // ---- Dynamic states ----
  Real x(start=x_start, fixed=true) "Carriage position [m]";
  Real v(start=0.0, fixed=true) "Carriage velocity [m/s]";
  Real p_a(start=p_a_start, fixed=true) "Cap-side pressure [Pa]";
  Real p_b(start=p_b_start, fixed=true) "Rod-side pressure [Pa]";
  Real integ_F(start=0.0, fixed=true) "Force-loop integrator state [N.s]";
  Real integ_p_a(start=0.0, fixed=true) "Pressure-A loop integrator state [Pa.s]";
  Real integ_p_b(start=0.0, fixed=true) "Pressure-B loop integrator state [Pa.s]";

  // ---- Algebraic / observation variables ----
  Real V_a "Cap-side instantaneous volume [m3]";
  Real V_b "Rod-side instantaneous volume [m3]";
  Real F_actuator "Net actuator force on carriage [N]";
  Real F_gravity "Gravity force [N]";
  Real F_friction "Viscous friction force [N]";
  Real F_contact "External contact force [N]";
  Real F_dist "Disturbance load change [N]";
  Real F_output "Measured output force [N]";
  Real F_error "Primary force tracking error [N]";
  Real p_a_ref "Cap-side pressure reference from outer loop [Pa]";
  Real p_b_ref "Rod-side pressure reference [Pa]";
  Real m_dot_cmd_a_raw "Unsaturated commanded mass flow into chamber A [kg/s]";
  Real m_dot_cmd_b_raw "Unsaturated commanded mass flow into chamber B [kg/s]";
  Real m_dot_cmd_a "Saturated commanded mass flow into A [kg/s]";
  Real m_dot_cmd_b "Saturated commanded mass flow into B [kg/s]";
  Real m_dot_relief_a "Relief valve mass flow from chamber A [kg/s]";
  Real m_dot_relief_b "Relief valve mass flow from chamber B [kg/s]";
  Real m_dot_a "Actual net mass flow into chamber A [kg/s]";
  Real m_dot_b "Actual net mass flow into chamber B [kg/s]";

  // ---- Synchronized sampled traces at 100 Hz ----
  Real x_s(start=x_start) "Sampled carriage position [m]";
  Real v_s(start=0.0) "Sampled carriage velocity [m/s]";
  Real p_a_s(start=p_a_start) "Sampled cap-side pressure [Pa]";
  Real p_b_s(start=p_b_start) "Sampled rod-side pressure [Pa]";
  Real F_contact_s(start=F_cmd_val) "Sampled external contact force [N]";
  Real F_error_s(start=0.0) "Sampled force tracking error [N]";
  Real m_dot_cmd_a_s(start=0.0) "Sampled chamber-A command [kg/s]";
  Real m_dot_cmd_b_s(start=0.0) "Sampled chamber-B command [kg/s]";
  Real F_cmd_s(start=F_cmd_val) "Sampled force command [N]";
  Real p_a_ref_s(start=p_a_start) "Sampled pressure reference [Pa]";

equation
  // Chamber volumes (explicit dead volumes included)
  V_a = V_a0 + A_a*x;
  V_b = V_b0 + A_b*(stroke - x);

  // Force inventory on vertical carriage
  F_actuator = p_a*A_a - p_b*A_b;
  F_gravity = m_carriage*g;
  F_friction = d_friction*v;
  F_contact = if x > x_contact then k_contact*(x - x_contact) + d_contact*v else 0.0;
  F_dist = if time >= t_dist_start and time <= t_dist_end then F_dist_val else 0.0;
  F_output = F_contact;
  F_error = F_cmd_val - F_output;

  // Carriage translational dynamics
  der(x) = v;
  m_carriage*der(v) = F_actuator - F_gravity - F_friction - F_contact - F_dist;

  // Pneumatic chamber pressure dynamics (isothermal ideal gas)
  der(p_a) = (R_air*T_air/V_a)*m_dot_a - (p_a/V_a)*A_a*v;
  der(p_b) = (R_air*T_air/V_b)*m_dot_b + (p_b/V_b)*A_b*v;

  // Relief protection (over-pressure venting to atmosphere)
  m_dot_relief_a = if p_a > P_relief then (p_a - P_relief)*1.0e-6 else 0.0;
  m_dot_relief_b = if p_b > P_relief then (p_b - P_relief)*1.0e-6 else 0.0;

  // Actual net mass flows into chambers (command limited by valve saturation and reduced by relief)
  m_dot_a = m_dot_cmd_a - m_dot_relief_a;
  m_dot_b = m_dot_cmd_b - m_dot_relief_b;

  // Cascaded controller integrators
  der(integ_F) = F_error;
  der(integ_p_a) = p_a_ref - p_a;
  der(integ_p_b) = p_b_ref - p_b;

  // Outer (force) loop: produces cap-side pressure reference
  // Quasi-static balance: p_a*A_a - P_atm*A_b = m*g + F_cmd  =>  p_a_ref baseline
  p_a_ref = (m_carriage*g + F_cmd_val + P_atm*A_b)/A_a + Kp_F*F_error + Ki_F*integ_F;
  p_b_ref = P_atm;

  // Inner (pressure) loops: produce mass-flow commands
  m_dot_cmd_a_raw = Kp_p*(p_a_ref - p_a) + Ki_p*integ_p_a;
  m_dot_cmd_b_raw = Kp_p*(p_b_ref - p_b) + Ki_p*integ_p_b;
  m_dot_cmd_a = if m_dot_cmd_a_raw > m_dot_max then m_dot_max
                else if m_dot_cmd_a_raw < -m_dot_max then -m_dot_max
                else m_dot_cmd_a_raw;
  m_dot_cmd_b = if m_dot_cmd_b_raw > m_dot_max then m_dot_max
                else if m_dot_cmd_b_raw < -m_dot_max then -m_dot_max
                else m_dot_cmd_b_raw;

  // Synchronized state/command/sensor traces sampled at 100 Hz
  when sample(0, Ts) then
    x_s = x;
    v_s = v;
    p_a_s = p_a;
    p_b_s = p_b;
    F_contact_s = F_contact;
    F_error_s = F_error;
    m_dot_cmd_a_s = m_dot_cmd_a;
    m_dot_cmd_b_s = m_dot_cmd_b;
    F_cmd_s = F_cmd_val;
    p_a_ref_s = p_a_ref;
  end when;

  annotation(
    experiment(StartTime=0, StopTime=10.0, Tolerance=1e-6, Interval=0.01),
    Documentation(info="AirStageForceB: vertical pneumatic actuator establishing a commanded contact force against a compliant load. Double-acting cylinder with unequal areas and explicit dead volumes, independent fill/exhaust proportional valves (command magnitude bounded at 0.012 kg/s), fixed support, compliant contact, supply limitation, and relief protection. Cascaded pressure (inner) and force (outer) regulation. A 105 N load-change disturbance is injected during the middle third (3.33 s to 6.67 s). Chamber pressures, actuator state, and external contact force are measured; synchronized state, command, and sensor traces are retained at 100 Hz for 10 s. Unstated geometric/physical details are treated as unknowns and represented by clearly-commented assumed parameters."),
    Diagram(),
    Icon()
  );
end AirStageForceB;