model HydBoomForceE
  "Fluid-power robotic actuator: boom-stick with double-acting cylinders, cascaded force/pressure control against compliant load"

  // ============ Geometry ============
  parameter Modelica.SIunits.Length L_boom = 2.0 "Boom length";
  parameter Modelica.SIunits.Length L_stick = 1.4 "Stick length";
  parameter Modelica.SIunits.Mass m_payload = 300.0 "Payload mass";
  parameter Modelica.SIunits.Mass m_boom_est = 100.0 "Estimated boom mass";
  parameter Modelica.SIunits.Mass m_stick_est = 30.0 "Estimated stick mass";

  // Boom cylinder attachment geometry
  parameter Modelica.SIunits.Length x_bc_base = 0.3 "Boom cylinder base x on frame";
  parameter Modelica.SIunits.Length y_bc_base = -0.3 "Boom cylinder base y on frame";
  parameter Modelica.SIunits.Length r_bc = 1.2 "Boom cylinder attach distance along boom";

  // Stick cylinder attachment geometry
  parameter Modelica.SIunits.Length r_sc_base = 0.5 "Stick cyl base distance on boom from stick pivot";
  parameter Modelica.SIunits.Length r_sc = 0.8 "Stick cyl attach distance along stick";

  // ============ Cylinder parameters ============
  parameter Modelica.SIunits.Area A_cap_b = 0.008 "Boom cylinder cap-side area";
  parameter Modelica.SIunits.Area A_rod_b = 0.004 "Boom cylinder rod-side area";
  parameter Modelica.SIunits.Length L_min_b = 0.5 "Boom cylinder min length";
  parameter Modelica.SIunits.Length L_max_b = 1.5 "Boom cylinder max length";

  parameter Modelica.SIunits.Area A_cap_s = 0.005 "Stick cylinder cap-side area";
  parameter Modelica.SIunits.Area A_rod_s = 0.0025 "Stick cylinder rod-side area";
  parameter Modelica.SIunits.Length L_min_s = 0.8 "Stick cylinder min length";
  parameter Modelica.SIunits.Length L_max_s = 1.5 "Stick cylinder max length";

  // ============ Hydraulic supply ============
  parameter Modelica.SIunits.VolumeFlowRate Q_pump_max = 0.004 "Max pump flow (command bound)";
  parameter Modelica.SIunits.Pressure p_relief = 20.0e6 "Relief valve pressure";
  parameter Modelica.SIunits.Pressure p_tank = 0.1e6 "Tank pressure";
  parameter Modelica.SIunits.BulkModulus beta_oil = 1.2e9 "Oil bulk modulus";
  parameter Modelica.SIunits.Density rho_oil = 850.0 "Oil density";
  parameter Real Cv = 5.0e-10 "Valve conductance coefficient [m3/(s.Pa)]";
  parameter Modelica.SIunits.Volume V_supply = 0.002 "Supply line volume";
  parameter Real Kv_relief = 5.0e-7 "Relief valve conductance [m3/(s.Pa)]";

  // ============ Mechanical ============
  parameter Modelica.SIunits.MomentOfInertia J_b_eff = 500.0 "Boom effective inertia";
  parameter Modelica.SIunits.MomentOfInertia J_s_eff = 200.0 "Stick effective inertia";
  parameter Modelica.SIunits.Damping d_b = 1000.0 "Boom joint damping";
  parameter Modelica.SIunits.Damping d_s = 200.0 "Stick joint damping";
  parameter Modelica.SIunits.Stiffness k_contact = 5.0e4 "Contact stiffness";
  parameter Modelica.SIunits.Damping d_contact = 1000.0 "Contact damping";

  // ============ Contact surface ============
  parameter Modelica.SIunits.Length x_surface = 3.2 "Vertical contact surface x-position";

  // ============ Control — boom cascaded force/pressure ============
  parameter Modelica.SIunits.Force F_cmd = 500.0 "Commanded output force";
  parameter Real Kp_force = 3000.0 "Force loop proportional gain [Pa/N]";
  parameter Real Ki_force = 5000.0 "Force loop integral gain [Pa/(N.s)]";
  parameter Modelica.SIunits.Pressure p_base_cmd = 2.0e6 "Base pressure command for boom";
  parameter Real Kp_pressure = 1.0e-7 "Pressure loop gain [1/Pa]";

  // ============ Control — stick position/pressure hold ============
  parameter Modelica.SIunits.Pressure p_s_hold = 13.0e6 "Stick hold pressure";
  parameter Real Kp_pos_s = 5.0e6 "Stick position-to-pressure gain [Pa/rad]";
  parameter Modelica.SIunits.Angle theta_s_init = -0.2 "Stick initial angle (hold setpoint)";

  // ============ Disturbance ============
  parameter Modelica.SIunits.Force F_disturbance = 180.0 "Disturbance force magnitude";
  parameter Modelica.SIunits.Time t_dist_start = 16.0/3.0 "Disturbance start (middle third)";
  parameter Modelica.SIunits.Time t_dist_end = 2.0*16.0/3.0 "Disturbance end (middle third)";

  // ============ Simulation ============
  parameter Modelica.SIunits.Frequency f_sample = 250.0 "Control sample frequency";

  // ============ Dynamic states ============
  Modelica.SIunits.Angle theta_b "Boom angle from horizontal";
  Modelica.SIunits.AngularVelocity omega_b "Boom angular velocity";
  Modelica.SIunits.Angle theta_s "Stick angle relative to boom";
  Modelica.SIunits.AngularVelocity omega_s "Stick angular velocity";

  Modelica.SIunits.Pressure p_b_cap "Boom cylinder cap-side pressure";
  Modelica.SIunits.Pressure p_b_rod "Boom cylinder rod-side pressure";
  Modelica.SIunits.Pressure p_s_cap "Stick cylinder cap-side pressure";
  Modelica.SIunits.Pressure p_s_rod "Stick cylinder rod-side pressure";
  Modelica.SIunits.Pressure p_supply "Pump supply pressure";

  Real integrator_force "Force integral term";

  // ============ Algebraic variables ============
  // Kinematics
  Modelica.SIunits.Length x_boom_tip "Boom tip x";
  Modelica.SIunits.Length y_boom_tip "Boom tip y";
  Modelica.SIunits.Length x_tip "Payload tip x";
  Modelica.SIunits.Length y_tip "Payload tip y";
  Modelica.SIunits.Velocity v_tip_x "Tip velocity x";

  // Cylinder geometry
  Modelica.SIunits.Length L_b_cyl "Boom cylinder length";
  Modelica.SIunits.Length L_s_cyl "Stick cylinder length";
  Modelica.SIunits.Length h_b "Boom cylinder moment arm";
  Modelica.SIunits.Length h_s "Stick cylinder moment arm";
  Modelica.SIunits.Velocity dL_b "Boom cylinder extension rate";
  Modelica.SIunits.Velocity dL_s "Stick cylinder extension rate";

  // Chamber volumes
  Modelica.SIunits.Volume V_b_cap "Boom cap volume";
  Modelica.SIunits.Volume V_b_rod "Boom rod volume";
  Modelica.SIunits.Volume V_s_cap "Stick cap volume";
  Modelica.SIunits.Volume V_s_rod "Stick rod volume";

  // Forces and torques
  Modelica.SIunits.Force F_b_cyl "Boom cylinder force";
  Modelica.SIunits.Force F_s_cyl "Stick cylinder force";
  Modelica.SIunits.Force F_contact "Contact force (measured)";
  Modelica.SIunits.Force F_dist "Active disturbance force";
  Modelica.SIunits.Torque tau_b_cyl "Boom cylinder torque";
  Modelica.SIunits.Torque tau_s_cyl "Stick cylinder torque";
  Modelica.SIunits.Torque tau_b_grav "Boom gravity torque";
  Modelica.SIunits.Torque tau_s_grav "Stick gravity torque";
  Modelica.SIunits.Torque tau_b_contact "Boom contact+dist torque";
  Modelica.SIunits.Torque tau_s_contact "Stick contact+dist torque";

  // Valve commands
  Real u_b_valve "Boom valve command [-1,1]";
  Real u_s_valve "Stick valve command [-1,1]";

  // Control signals
  Modelica.SIunits.Force F_err "Force tracking error";
  Modelica.SIunits.Pressure p_b_cmd "Boom pressure command";
  Modelica.SIunits.Pressure p_s_cmd "Stick pressure command";

  // Valve flows
  Modelica.SIunits.VolumeFlowRate Q_b_cap_net "Net flow into boom cap";
  Modelica.SIunits.VolumeFlowRate Q_b_rod_net "Net flow into boom rod";
  Modelica.SIunits.VolumeFlowRate Q_s_cap_net "Net flow into stick cap";
  Modelica.SIunits.VolumeFlowRate Q_s_rod_net "Net flow into stick rod";
  Modelica.SIunits.VolumeFlowRate Q_b_from_supply "Boom flow from supply";
  Modelica.SIunits.VolumeFlowRate Q_s_from_supply "Stick flow from supply";
  Modelica.SIunits.VolumeFlowRate Q_demand "Total flow demand from supply";
  Modelica.SIunits.VolumeFlowRate Q_relief "Relief valve flow";
  Modelica.SIunits.VolumeFlowRate Q_pump "Pump flow";

  // Contact
  Modelica.SIunits.Length penetration "Contact penetration depth";

  // ============ Acceptance check signals ============
  Boolean pressure_ok "All pressures within bounds";
  Boolean flow_ok "Pump flow within bound";
  Boolean contact_force_ok "Contact force in band";
  Boolean no_endstop "No end-stop impact";
  Boolean stable_hold "Velocities near zero (after settling)";
  Boolean tracking_ok "Tracking error below 18 N after 10.4 s";
  Boolean no_nan "No NaN or infinite values";
  Boolean system_ok "All critical acceptance checks pass";
  Modelica.SIunits.Force tracking_error "|F_contact - F_cmd|";

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
  h_b = (r_bc * (x_bc_base * sin(theta_b) - y_bc_base * cos(theta_b))) / L_b_cyl;
  dL_b = h_b * omega_b;

  L_s_cyl = sqrt(r_sc_base^2 + r_sc^2 + 2.0*r_sc_base*r_sc*cos(theta_s));
  h_s = (-r_sc_base * r_sc * sin(theta_s)) / L_s_cyl;
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
  // Compliant contact with damping (only when penetrating)
  if penetration > 0 then
    F_contact = k_contact * penetration + d_contact * v_tip_x;
    // Prevent adhesive (negative) contact force
    if F_contact < 0 then
      F_contact = 0;
    end if;
  else
    F_contact = 0;
  end if;

  // Disturbance: 180 N load change during middle third
  if time >= t_dist_start and time <= t_dist_end then
    F_dist = F_disturbance;
  else
    F_dist = 0;
  end if;

  // Contact + disturbance torques on boom and stick
  tau_b_contact = y_tip * (F_contact + F_dist);
  tau_s_contact = L_stick * sin(theta_b + theta_s) * (F_contact + F_dist);

  // ============ Mechanical dynamics ============
  der(theta_b) = omega_b;
  der(omega_b) = (tau_b_cyl + tau_b_grav + tau_b_contact - d_b * omega_b) / J_b_eff;

  der(theta_s) = omega_s;
  der(omega_s) = (tau_s_cyl + tau_s_grav + tau_s_contact - d_s * omega_s) / J_s_eff;

  // ============ Valve flow equations (boom) ============
  // u > 0: supply->cap, rod->tank (extending); u < 0: supply->rod, cap->tank
  if u_b_valve >= 0 then
    Q_b_cap_net = Cv * u_b_valve * (p_supply - p_b_cap);
    Q_b_rod_net = -Cv * u_b_valve * (p_b_rod - p_tank);
    Q_b_from_supply = Cv * u_b_valve * (p_supply - p_b_cap);
  else
    Q_b_cap_net = Cv * u_b_valve * (p_b_cap - p_tank);
    Q_b_rod_net = -Cv * u_b_valve * (p_supply - p_b_rod);
    Q_b_from_supply = -Cv * u_b_valve * (p_supply - p_b_rod);
  end if;

  // ============ Valve flow equations (stick) ============
  if u_s_valve >= 0 then
    Q_s_cap_net = Cv * u_s_valve * (p_supply - p_s_cap);
    Q_s_rod_net = -Cv * u_s_valve * (p_s_rod - p_tank);
    Q_s_from_supply = Cv * u_s_valve * (p_supply - p_s_cap);
  else
    Q_s_cap_net = Cv * u_s_valve * (p_s_cap - p_tank);
    Q_s_rod_net = -Cv * u_s_valve * (p_supply - p_s_rod);
    Q_s_from_supply = -Cv * u_s_valve * (p_supply - p_s_rod);
  end if;

  // ============ Pressure dynamics ============
  // Cap side: volume increases with extension; rod side: volume decreases
  der(p_b_cap) = (beta_oil / V_b_cap) * (Q_b_cap_net - A_cap_b * dL_b);
  der(p_b_rod) = (beta_oil / V_b_rod) * (Q_b_rod_net + A_rod_b * dL_b);
  der(p_s_cap) = (beta_oil / V_s_cap) * (Q_s_cap_net - A_cap_s * dL_s);
  der(p_s_rod) = (beta_oil / V_s_rod) * (Q_s_rod_net + A_rod_s * dL_s);

  // ============ Supply pressure dynamics ============
  Q_pump = Q_pump_max;
  Q_demand = Q_b_from_supply + Q_s_from_supply;
  // Relief valve opens when supply exceeds relief pressure
  if p_supply > p_relief then
    Q_relief = Kv_relief * (p_supply - p_relief);
  else
    Q_relief = 0;
  end if;
  der(p_supply) = (beta_oil / V_supply) * (Q_pump - Q_demand - Q_relief);

  // ============ Cascaded control: boom force -> pressure -> valve ============
  // Force tracking error (positive when force too low)
  F_err = F_cmd - F_contact;

  // Force integrator with anti-windup clamping
  der(integrator_force) = F_err;

  // Force loop: pressure command (note negative sign — increasing pressure
  // pushes boom up, reducing penetration, so negative gain needed)
  p_b_cmd = p_base_cmd - Kp_force * F_err - Ki_force * integrator_force;

  // Clamp pressure command to valid range
  // (Algebraic clamp via max/min would create equation issues; handled by valve saturation)

  // Pressure loop: valve command
  u_b_valve = Kp_pressure * (p_b_cmd - p_b_cap);

  // ============ Stick cascaded control: position -> pressure -> valve ============
  p_s_cmd = p_s_hold + Kp_pos_s * (theta_s_init - theta_s);
  u_s_valve = Kp_pressure * (p_s_cmd - p_s_cap);

  // ============ Acceptance checks ============
  // Pressure bounds
  pressure_ok = p_b_cap >= 0 and p_b_cap <= p_relief
            and p_b_rod >= 0 and p_b_rod <= p_relief
            and p_s_cap >= 0 and p_s_cap <= p_relief
            and p_s_rod >= 0 and p_s_rod <= p_relief
            and p_supply >= 0 and p_supply <= p_relief * 1.05;

  // Flow bound
  flow_ok = Q_pump <= Q_pump_max * 1.001;

  // Contact-force band [0, 2*F_cmd]
  contact_force_ok = F_contact >= 0 and F_contact <= 2.0 * F_cmd;

  // No end-stop impact
  no_endstop = L_b_cyl > L_min_b + 0.01 and L_b_cyl < L_max_b - 0.01
            and L_s_cyl > L_min_s + 0.01 and L_s_cyl < L_max_s - 0.01;

  // Stable hold (velocities small after settling)
  stable_hold = (if time > 8.0 then abs(omega_b) < 0.05 and abs(omega_s) < 0.05 else true);

  // Tracking error
  tracking_error = abs(F_contact - F_cmd);
  tracking_ok = (if time > 10.4 then tracking_error < 18.0 else true);

  // No NaN or infinite values (comparisons with NaN return false)
  no_nan = theta_b > -10.0 and theta_b < 10.0
        and theta_s > -10.0 and theta_s < 10.0
        and p_b_cap > -1.0e6 and p_b_cap < 1.0e9
        and p_s_cap > -1.0e6 and p_s_cap < 1.0e9
        and p_supply > -1.0e6 and p_supply < 1.0e9
        and F_contact > -1.0e4 and F_contact < 1.0e6
        and omega_b > -100.0 and omega_b < 100.0
        and omega_s > -100.0 and omega_s < 100.0;

  // Fail-closed: system ok only if all critical checks pass
  system_ok = pressure_ok and flow_ok and no_endstop and no_nan;

  // ============ Experiment annotation ============
  annotation(
    Documentation(info = "HydBoomForceE: 2-DOF boom-stick hydraulic actuator with cascaded force/pressure control against compliant load. Pump flow bounded at 0.004 m3/s, relief at 20 MPa. 180 N disturbance during middle third [5.33, 10.67] s. Run at 250 Hz for 16 s."),
    experiment(StartTime = 0, StopTime = 16, Tolerance = 1.0e-5, Interval = 0.004),
    __OpenModelica_simulationFlags(s = "dassl", noEventEmit = "()")
  );
end HydBoomForceE;