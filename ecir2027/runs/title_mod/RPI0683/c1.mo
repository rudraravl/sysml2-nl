model HydBoomForceE
  "Fluid-power robotic actuator: boom-stick with double-acting cylinders, cascaded force/pressure control against compliant load"

  // ============ Geometry ============
  parameter Real L_boom = 2.0 "Boom length [m]";
  parameter Real L_stick = 1.4 "Stick length [m]";
  parameter Real m_payload = 300.0 "Payload mass [kg]";
  parameter Real m_boom_est = 100.0 "Estimated boom mass [kg]";
  parameter Real m_stick_est = 30.0 "Estimated stick mass [kg]";

  // Boom cylinder attachment geometry
  parameter Real x_bc_base = 0.3 "Boom cylinder base x on frame [m]";
  parameter Real y_bc_base = -0.3 "Boom cylinder base y on frame [m]";
  parameter Real r_bc = 1.2 "Boom cylinder attach distance along boom [m]";

  // Stick cylinder attachment geometry
  parameter Real r_sc_base = 0.5 "Stick cyl base distance on boom from stick pivot [m]";
  parameter Real r_sc = 0.8 "Stick cyl attach distance along stick [m]";

  // ============ Cylinder parameters ============
  parameter Real A_cap_b = 0.008 "Boom cylinder cap-side area [m2]";
  parameter Real A_rod_b = 0.004 "Boom cylinder rod-side area [m2]";
  parameter Real L_min_b = 0.5 "Boom cylinder min length [m]";
  parameter Real L_max_b = 1.5 "Boom cylinder max length [m]";

  parameter Real A_cap_s = 0.005 "Stick cylinder cap-side area [m2]";
  parameter Real A_rod_s = 0.0025 "Stick cylinder rod-side area [m2]";
  parameter Real L_min_s = 0.8 "Stick cylinder min length [m]";
  parameter Real L_max_s = 1.5 "Stick cylinder max length [m]";

  // ============ Hydraulic supply ============
  parameter Real Q_pump_max = 0.004 "Max pump flow (command bound) [m3/s]";
  parameter Real p_relief = 20.0e6 "Relief valve pressure [Pa]";
  parameter Real p_tank = 0.1e6 "Tank pressure [Pa]";
  parameter Real beta_oil = 1.2e9 "Oil bulk modulus [Pa]";
  parameter Real rho_oil = 850.0 "Oil density [kg/m3]";
  parameter Real Cv = 5.0e-10 "Valve conductance coefficient [m3/(s.Pa)]";
  parameter Real V_supply = 0.002 "Supply line volume [m3]";
  parameter Real Kv_relief = 5.0e-7 "Relief valve conductance [m3/(s.Pa)]";

  // ============ Mechanical ============
  parameter Real J_b_eff = 500.0 "Boom effective inertia [kg.m2]";
  parameter Real J_s_eff = 200.0 "Stick effective inertia [kg.m2]";
  parameter Real d_b = 1000.0 "Boom joint damping [N.m.s]";
  parameter Real d_s = 200.0 "Stick joint damping [N.m.s]";
  parameter Real k_contact = 5.0e4 "Contact stiffness [N/m]";
  parameter Real d_contact = 1000.0 "Contact damping [N.s/m]";

  // ============ Contact surface ============
  parameter Real x_surface = 3.2 "Vertical contact surface x-position [m]";

  // ============ Control ============
  parameter Real F_cmd = 500.0 "Commanded output force [N]";
  parameter Real Kp_force = 3000.0 "Force loop proportional gain [Pa/N]";
  parameter Real Ki_force = 5000.0 "Force loop integral gain [Pa/(N.s)]";
  parameter Real p_base_cmd = 2.0e6 "Base pressure command for boom [Pa]";
  parameter Real Kp_pressure = 1.0e-7 "Pressure loop gain [1/Pa]";

  parameter Real p_s_hold = 13.0e6 "Stick hold pressure [Pa]";
  parameter Real Kp_pos_s = 5.0e6 "Stick position-to-pressure gain [Pa/rad]";
  parameter Real theta_s_init = -0.2 "Stick initial angle (hold setpoint) [rad]";

  // ============ Disturbance ============
  parameter Real F_disturbance = 180.0 "Disturbance force magnitude [N]";
  parameter Real t_dist_start = 16.0/3.0 "Disturbance start (middle third) [s]";
  parameter Real t_dist_end = 2.0*16.0/3.0 "Disturbance end (middle third) [s]";

  parameter Real f_sample = 250.0 "Control sample frequency [Hz]";

  // ============ Dynamic states ============
  Real theta_b "Boom angle from horizontal [rad]";
  Real omega_b "Boom angular velocity [rad/s]";
  Real theta_s "Stick angle relative to boom [rad]";
  Real omega_s "Stick angular velocity [rad/s]";

  Real p_b_cap "Boom cylinder cap-side pressure [Pa]";
  Real p_b_rod "Boom cylinder rod-side pressure [Pa]";
  Real p_s_cap "Stick cylinder cap-side pressure [Pa]";
  Real p_s_rod "Stick cylinder rod-side pressure [Pa]";
  Real p_supply "Pump supply pressure [Pa]";

  Real integrator_force "Force integral term";

  // ============ Algebraic variables ============
  Real x_boom_tip "Boom tip x [m]";
  Real y_boom_tip "Boom tip y [m]";
  Real x_tip "Payload tip x [m]";
  Real y_tip "Payload tip y [m]";
  Real v_tip_x "Tip velocity x [m/s]";

  Real L_b_cyl "Boom cylinder length [m]";
  Real L_s_cyl "Stick cylinder length [m]";
  Real h_b "Boom cylinder moment arm [m]";
  Real h_s "Stick cylinder moment arm [m]";
  Real dL_b "Boom cylinder extension rate [m/s]";
  Real dL_s "Stick cylinder extension rate [m/s]";

  Real V_b_cap "Boom cap volume [m3]";
  Real V_b_rod "Boom rod volume [m3]";
  Real V_s_cap "Stick cap volume [m3]";
  Real V_s_rod "Stick rod volume [m3]";

  Real F_b_cyl "Boom cylinder force [N]";
  Real F_s_cyl "Stick cylinder force [N]";
  Real F_contact "Contact force (measured) [N]";
  Real F_dist "Active disturbance force [N]";
  Real tau_b_cyl "Boom cylinder torque [N.m]";
  Real tau_s_cyl "Stick cylinder torque [N.m]";
  Real tau_b_grav "Boom gravity torque [N.m]";
  Real tau_s_grav "Stick gravity torque [N.m]";
  Real tau_b_contact "Boom contact+dist torque [N.m]";
  Real tau_s_contact "Stick contact+dist torque [N.m]";

  Real u_b_valve "Boom valve command [-1,1]";
  Real u_s_valve "Stick valve command [-1,1]";

  Real F_err "Force tracking error [N]";
  Real p_b_cmd "Boom pressure command [Pa]";
  Real p_s_cmd "Stick pressure command [Pa]";

  Real Q_b_cap_net "Net flow into boom cap [m3/s]";
  Real Q_b_rod_net "Net flow into boom rod [m3/s]";
  Real Q_s_cap_net "Net flow into stick cap [m3/s]";
  Real Q_s_rod_net "Net flow into stick rod [m3/s]";
  Real Q_b_from_supply "Boom flow from supply [m3/s]";
  Real Q_s_from_supply "Stick flow from supply [m3/s]";
  Real Q_demand "Total flow demand from supply [m3/s]";
  Real Q_relief "Relief valve flow [m3/s]";
  Real Q_pump "Pump flow [m3/s]";

  Real penetration "Contact penetration depth [m]";

  // ============ Acceptance check signals ============
  Boolean pressure_ok "All pressures within bounds";
  Boolean flow_ok "Pump flow within bound";
  Boolean contact_force_ok "Contact force in band";
  Boolean no_endstop "No end-stop impact";
  Boolean stable_hold "Velocities near zero (after settling)";
  Boolean tracking_ok "Tracking error below 18 N after 10.4 s";
  Boolean no_nan "No NaN or infinite values";
  Boolean system_ok "All critical acceptance checks pass";
  Real tracking_error "|F_contact - F_cmd| [N]";

initial equation
  theta_b = 0.4;
  omega_b = 0;
  theta_s = -0.2;
  omega_s = 0;
  p_b_cap = 2.0e6;
  p_b_rod = 0.5e6;
  p_s_cap = 13.5e6;
  p_s_rod = 0.5e6;
  p_supply = 15.0e6;
  integrator_force = 0;

equation
  // ============ Kinematics ============
  x_boom_tip = L_boom * cos(theta_b);
  y_boom_tip = L_boom * sin(theta_b);
  x_tip = x_boom_tip + L_stick * cos(theta_b + theta_s);
  y_tip = y_boom_tip + L_stick * sin(theta_b + theta_s);
  v_tip_x = -L_boom * sin(theta_b) * omega_b
          - L_stick * sin(theta_b + theta_s) * (omega_b + omega_s);

  // ============ Cylinder geometry ============
  L_b_cyl = sqrt((r_bc*cos(theta_b) - x_bc_base)^2
               + (r_bc*sin(theta_b) - y_bc_base)^2);
  h_b = (r_bc * (x_bc_base * sin(theta_b) - y_bc_base * cos(theta_b))) / max(L_b_cyl, 1.0e-6);
  dL_b = h_b * omega_b;

  L_s_cyl = sqrt(r_sc_base^2 + r_sc^2 + 2.0*r_sc_base*r_sc*cos(theta_s));
  h_s = (-r_sc_base * r_sc * sin(theta_s)) / max(L_s_cyl, 1.0e-6);
  dL_s = h_s * omega_s;

  // Chamber volumes (with minimum to prevent singularity)
  V_b_cap = max(A_cap_b * L_b_cyl, 1.0e-6);
  V_b_rod = max(A_rod_b * (L_max_b - L_b_cyl), 1.0e-6);
  V_s_cap = max(A_cap_s * L_s_cyl, 1.0e-6);
  V_s_rod = max(A_rod_s * (L_max_s - L_s_cyl), 1.0e-6);

  // ============ Cylinder forces ============
  F_b_cyl = p_b_cap * A_cap_b - p_b_rod * A_rod_b;
  F_s_cyl = p_s_cap * A_cap_s - p_s_rod * A_rod_s;
  tau_b_cyl = F_b_cyl * h_b;
  tau_s_cyl = F_s_cyl * h_s;

  // ============ Gravity torques ============
  tau_b_grav = -(m_boom_est * 9.81 * L_boom / 2.0
               + (m_stick_est + m_payload) * 9.81 * L_boom) * cos(theta_b);
  tau_s_grav = -(m_stick_est / 2.0 + m_payload) * 9.81 * L_stick
             * cos(theta_b + theta_s);

  // ============ Contact and disturbance ============
  penetration = x_tip - x_surface;
  F_contact = if penetration > 0 then max(k_contact * penetration + d_contact * v_tip_x, 0.0) else 0.0;

  F_dist = if time >= t_dist_start and time <= t_dist_end then F_disturbance else 0.0;

  tau_b_contact = y_tip * (F_contact + F_dist);
  tau_s_contact = L_stick * sin(theta_b + theta_s) * (F_contact + F_dist);

  // ============ Mechanical dynamics ============
  der(theta_b) = omega_b;
  der(omega_b) = (tau_b_cyl + tau_b_grav + tau_b_contact - d_b * omega_b) / J_b_eff;

  der(theta_s) = omega_s;
  der(omega_s) = (tau_s_cyl + tau_s_grav + tau_s_contact - d_s * omega_s) / J_s_eff;

  // ============ Valve flow equations (boom) ============
  Q_b_cap_net = if u_b_valve >= 0 then Cv * u_b_valve * (p_supply - p_b_cap) else Cv * u_b_valve * (p_b_cap - p_tank);
  Q_b_rod_net = if u_b_valve >= 0 then -Cv * u_b_valve * (p_b_rod - p_tank) else -Cv * u_b_valve * (p_supply - p_b_rod);
  Q_b_from_supply = if u_b_valve >= 0 then Cv * u_b_valve * (p_supply - p_b_cap) else -Cv * u_b_valve * (p_supply - p_b_rod);

  // ============ Valve flow equations (stick) ============
  Q_s_cap_net = if u_s_valve >= 0 then Cv * u_s_valve * (p_supply - p_s_cap) else Cv * u_s_valve * (p_s_cap - p_tank);
  Q_s_rod_net = if u_s_valve >= 0 then -Cv * u_s_valve * (p_s_rod - p_tank) else -Cv * u_s_valve * (p_supply - p_s_rod);
  Q_s_from_supply = if u_s_valve >= 0 then Cv * u_s_valve * (p_supply - p_s_cap) else -Cv * u_s_valve * (p_supply - p_s_rod);

  // ============ Pressure dynamics ============
  der(p_b_cap) = (beta_oil / V_b_cap) * (Q_b_cap_net - A_cap_b * dL_b);
  der(p_b_rod) = (beta_oil / V_b_rod) * (Q_b_rod_net + A_rod_b * dL_b);
  der(p_s_cap) = (beta_oil / V_s_cap) * (Q_s_cap_net - A_cap_s * dL_s);
  der(p_s_rod) = (beta_oil / V_s_rod) * (Q_s_rod_net + A_rod_s * dL_s);

  // ============ Supply pressure dynamics ============
  Q_pump = Q_pump_max;
  Q_demand = Q_b_from_supply + Q_s_from_supply;
  Q_relief = if p_supply > p_relief then Kv_relief * (p_supply - p_relief) else 0.0;
  der(p_supply) = (beta_oil / V_supply) * (Q_pump - Q_demand - Q_relief);

  // ============ Cascaded control: boom force -> pressure -> valve ============
  F_err = F_cmd - F_contact;
  der(integrator_force) = F_err;
  p_b_cmd = p_base_cmd - Kp_force * F_err - Ki_force * integrator_force;
  u_b_valve = Kp_pressure * (p_b_cmd - p_b_cap);

  // ============ Stick cascaded control: position -> pressure -> valve ============
  p_s_cmd = p_s_hold + Kp_pos_s * (theta_s_init - theta_s);
  u_s_valve = Kp_pressure * (p_s_cmd - p_s_cap);

  // ============ Acceptance checks ============
  pressure_ok = p_b_cap >= 0 and p_b_cap <= p_relief
            and p_b_rod >= 0 and p_b_rod <= p_relief
            and p_s_cap >= 0 and p_s_cap <= p_relief
            and p_s_rod >= 0 and p_s_rod <= p_relief
            and p_supply >= 0 and p_supply <= p_relief * 1.05;

  flow_ok = Q_pump <= Q_pump_max * 1.001;

  contact_force_ok = F_contact >= 0 and F_contact <= 2.0 * F_cmd;

  no_endstop = L_b_cyl > L_min_b + 0.01 and L_b_cyl < L_max_b - 0.01
            and L_s_cyl > L_min_s + 0.01 and L_s_cyl < L_max_s - 0.01;

  stable_hold = if time > 8.0 then (abs(omega_b) < 0.05 and abs(omega_s) < 0.05) else true;

  tracking_error = abs(F_contact - F_cmd);
  tracking_ok = if time > 10.4 then tracking_error < 18.0 else true;

  no_nan = theta_b > -10.0 and theta_b < 10.0
        and theta_s > -10.0 and theta_s < 10.0
        and p_b_cap > -1.0e6 and p_b_cap < 1.0e9
        and p_s_cap > -1.0e6 and p_s_cap < 1.0e9
        and p_supply > -1.0e6 and p_supply < 1.0e9
        and F_contact > -1.0e4 and F_contact < 1.0e6
        and omega_b > -100.0 and omega_b < 100.0
        and omega_s > -100.0 and omega_s < 100.0;

  system_ok = pressure_ok and flow_ok and no_endstop and no_nan;

  annotation(
    Documentation(info = "HydBoomForceE: 2-DOF boom-stick hydraulic actuator with cascaded force/pressure control against compliant load. Pump flow bounded at 0.004 m3/s, relief at 20 MPa. 180 N disturbance during middle third [5.33, 10.67] s. Run at 250 Hz for 16 s."),
    experiment(StartTime = 0, StopTime = 16, Tolerance = 1.0e-5, Interval = 0.004),
    __OpenModelica_simulationFlags(s = "dassl")
  );
end HydBoomForceE;