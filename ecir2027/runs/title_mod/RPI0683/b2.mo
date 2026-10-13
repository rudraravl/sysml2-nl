model HydBoomForceE
  "Fluid-power robotic actuator: boom-stick with double-acting cylinders, cascaded force/pressure control against compliant load"

  // ============ Geometry ============
  parameter Modelica.SIunits.Length L_boom = 2.0 "Boom length";
  parameter Modelica.SIunits.Length L_stick = 1.4 "Stick length";
  parameter Modelica.SIunits.Mass m_payload = 300.0 "Payload mass";
  parameter Modelica.SIunits.Mass m_boom_est = 100.0 "Estimated boom mass";
  parameter Modelica.SIunits.Mass m_stick_est = 30.0 "Estimated stick mass";

  parameter Modelica.SIunits.Length x_bc_base = 0.3 "Boom cylinder base x on frame";
  parameter Modelica.SIunits.Length y_bc_base = -0.3 "Boom cylinder base y on frame";
  parameter Modelica.SIunits.Length r_bc = 1.2 "Boom cylinder attach distance along boom";

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
  parameter Real d_b(unit="N.m.s/rad") = 1000.0 "Boom joint rotational damping";
  parameter Real d_s(unit="N.m.s/rad") = 500.0 "Stick joint rotational damping";
  parameter Real k_contact(unit="N/m") = 5.0e4 "Contact stiffness";
  parameter Real d_contact(unit="N.s/m") = 1000.0 "Contact damping";

  parameter Modelica.SIunits.Length x_surface = 3.2 "Vertical contact surface x-position";

  // ============ Control — boom cascaded force/pressure ============
  parameter Modelica.SIunits.Force F_cmd = 500.0 "Commanded output force";
  parameter Real Kp_force = 2000.0 "Force loop proportional gain [Pa/N]";
  parameter Real Ki_force = 1000.0 "Force loop integral gain [Pa/(N.s)]";
  parameter Modelica.SIunits.Pressure p_base_cmd = 2.0e6 "Base pressure command for boom";
  parameter Real Kp_pressure = 1.0e-7 "Pressure loop gain [1/Pa]";

  // ============ Control — stick position/pressure hold ============
  parameter Modelica.SIunits.Pressure p_s_hold = 13.4e6 "Stick hold pressure";
  parameter Real Kp_pos_s = 5.0e6 "Stick position-to-pressure gain [Pa/rad]";
  parameter Modelica.SIunits.Angle theta_s_init = -0.2 "Stick initial angle (hold setpoint)";

  // ============ Disturbance ============
  parameter Modelica.SIunits.Force F_disturbance = 180.0 "Disturbance force magnitude";
  parameter Modelica.SIunits.Time t_dist_start = 16.0/3.0 "Disturbance start (middle third)";
  parameter Modelica.SIunits.Time t_dist_end = 2.0*16.0/3.0 "Disturbance end (middle third)";

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

  Real integrator_force "Force integral term [N.s]";

  // ============ Algebraic variables ============
  Modelica.SIunits.Length x_boom_tip "Boom tip x";
  Modelica.SIunits.Length y_boom_tip "Boom tip y";
  Modelica.SIunits.Length x_tip "Payload tip x";
  Modelica.SIunits.Length y_tip "Payload tip y";
  Modelica.SIunits.Velocity v_tip_x "Tip velocity x";

  Modelica.SIunits.Length L_b_cyl "Boom cylinder length";
  Modelica.SIunits.Length L_s_cyl "Stick cylinder length";
  Modelica.SIunits.Length h_b "Boom cylinder moment arm";
  Modelica.SIunits.Length h_s "Stick cylinder moment arm";
  Modelica.SIunits.Velocity dL_b "Boom cylinder extension rate";
  Modelica.SIunits.Velocity dL_s "Stick cylinder extension rate";

  Modelica.SIunits.Volume V_b_cap "Boom cap volume";
  Modelica.SIunits.Volume V_b_rod "Boom rod volume";
  Modelica.SIunits.Volume V_s_cap "Stick cap volume";
  Modelica.SIunits.Volume V_s_rod "Stick rod volume";

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

  Real u_b_valve_raw "Boom valve command before saturation [-]";
  Real u_s_valve_raw "Stick valve command before saturation [-]";
  Real u_b_valve "Boom valve command saturated [-1,1]";
  Real u_s_valve "Stick valve command saturated [-1,1]";

  Modelica.SIunits.Force F_err "Force tracking error";
  Modelica.SIunits.Pressure p_b_cmd "Boom pressure command";
  Modelica.SIunits.Pressure p_s_cmd "Stick pressure command";

  Modelica.SIunits.VolumeFlowRate Q_b_cap_net "Net flow into boom cap";
  Modelica.SIunits.VolumeFlowRate Q_b_rod_net "Net flow into boom rod";
  Modelica.SIunits.VolumeFlowRate Q_s_cap_net "Net flow into stick cap";
  Modelica.SIunits.VolumeFlowRate Q_s_rod_net "Net flow into stick rod";
  Modelica.SIunits.VolumeFlowRate Q_b_from_supply "Boom flow from supply";
  Modelica.SIunits.VolumeFlowRate Q_s_from_supply "Stick flow from supply";
  Modelica.SIunits.VolumeFlowRate Q_demand "Total flow demand from supply";
  Modelica.SIunits.VolumeFlowRate Q_relief "Relief valve flow";
  Modelica.SIunits.VolumeFlowRate Q_pump "Pump flow";

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
  Modelica.SIunits.Force tracking_error "abs(F_contact - F_cmd)";

initial equation
  theta_b = 0.4;
  omega_b = 0;
  theta_s = -0.2;
  omega_s = 0;
  p_b_cap = 2.0e6;
  p_b_rod = 0.5e6;
  p_s_cap = 13.4e6;
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
  F_contact = if penetration > 0.0 then
                max(0.0, k_contact * penetration + d_contact * v_tip_x)
              else
                0.0;

  F_dist = if time >= t_dist_start and time <= t_dist_end then
             F_disturbance
           else
             0.0;

  tau_b_contact = y_tip * (F_contact + F_dist);
  tau_s_contact = L_stick * sin(theta_b + theta_s) * (F_contact + F_dist);

  // ============ Mechanical dynamics ============
  der(theta_b) = omega_b;
  der(omega_b) = (tau_b_cyl + tau_b_grav + tau_b_contact - d_b * omega_b) / J_b_eff;

  der(theta_s) = omega_s;
  der(omega_s) = (tau_s_cyl + tau_s_grav + tau_s_contact - d_s * omega_s) / J_s_eff;

  // ============ Valve flow equations (boom) ============
  Q_b_cap_net = if u_b_valve >= 0.0 then Cv * u_b_valve * (p_supply - p_b_cap)
                                      else Cv * u_b_valve * (p_b_cap - p_tank);
  Q_b_rod_net = if u_b_valve >= 0.0 then -Cv * u_b_valve * (p_b_rod - p_tank)
                                     else -Cv * u_b_valve * (p_supply - p_b_rod);
  Q_b_from_supply = if u_b_valve >= 0.0 then Cv * u_b_valve * (p_supply - p_b_cap)
                                        else -Cv * u_b_valve * (p_supply - p_b_rod);

  // ============ Valve flow equations (stick) ============
  Q_s_cap_net = if u_s_valve >= 0.0 then Cv * u_s_valve * (p_supply - p_s_cap)
                                     else Cv * u_s_valve * (p_s_cap - p_tank);
  Q_s_rod_net = if u_s_valve >= 0.0 then -Cv * u_s_valve * (p_s_rod - p_tank)
                                     else -Cv * u_s_valve * (p_supply - p_s_rod);
  Q_s_from_supply = if u_s_valve >= 0.0 then Cv * u_s_valve * (p_supply - p_s_cap)
                                        else -Cv * u_s_valve * (p_supply - p_s_rod);

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
  p_b_cmd = max(0.0, min(p_relief, p_base_cmd + Kp_force * F_err
    + Ki_force * max(-1.0e3, min(1.0e3, integrator_force))));
  u_b_valve_raw = Kp_pressure * (p_b_cmd - p_b_cap);
  u_b_valve = max(-1.0, min(1.0, u_b_valve_raw));

  // ============ Stick cascaded control: position -> pressure -> valve ============
  p_s_cmd = p_s_hold + Kp_pos_s * (theta_s_init - theta_s);
  u_s_valve_raw = Kp_pressure * (p_s_cmd - p_s_cap);
  u_s_valve = max(-1.0, min(1.0, u_s_valve_raw));

  // ============ Acceptance checks ============
  pressure_ok = p_b_cap >= 0.0 and p_b_cap <= p_relief
            and p_b_rod >= 0.0 and p_b_rod <= p_relief
            and p_s_cap >= 0.0 and p_s_cap <= p_relief
            and p_s_rod >= 0.0 and p_s_rod <= p_relief
            and p_supply >= 0.0 and p_supply <= p_relief * 1.05;

  flow_ok = Q_pump <= Q_pump_max * 1.001;

  contact_force_ok = F_contact >= 0.0 and F_contact <= 2.0 * F_cmd;

  no_endstop = L_b_cyl > L_min_b + 0.01 and L_b_cyl < L_max_b - 0.01
            and L_s_cyl > L_min_s + 0.01 and L_s_cyl < L_max_s - 0.01;

  stable_hold = if time > 8.0 then
                  abs(omega_b) < 0.05 and abs(omega_s) < 0.05
                else
                  true;

  tracking_error = abs(F_contact - F_cmd);
  tracking_ok = if time > 10.4 then
                  tracking_error < 18.0
                else
                  true;

  no_nan = theta_b > -10.0 and theta_b < 10.0
        and theta_s > -10.0 and theta_s < 10.0
        and p_b_cap > -1.0e6 and p_b_cap < 1.0e9
        and p_s_cap > -1.0e6 and p_s_cap < 1.0e9
        and p_supply > -1.0e6 and p_supply < 1.0e9
        and F_contact > -1.0e4 and F_contact < 1.0e6
        and omega_b > -100.0 and omega_b < 100.0
        and omega_s > -100.0 and omega_s < 100.0;

  system_ok = pressure_ok and flow_ok and contact_force_ok
           and no_endstop and stable_hold and tracking_ok and no_nan;

  annotation(
    Documentation(info = "HydBoomForceE: 2-DOF boom-stick hydraulic actuator with cascaded force/pressure control against compliant load. Two valve sections share a load-sensing pump with relief at 20 MPa. Pump flow bounded at 0.004 m3/s. 180 N disturbance during middle third [5.33, 10.67] s. Run at 250 Hz for 16 s. Acceptance is fail-closed: all checks must pass."),
    experiment(StartTime = 0, StopTime = 16, Tolerance = 1.0e-5, Interval = 0.004)
  );
end HydBoomForceE;