model HydBoomForceB
  "Fluid-power robotic actuator: boom+stick cylinders, cascaded pressure/force control, compliant load"

  // ===== Mission Parameters (specified) =====
  parameter Real L_boom = 2.0 "Boom length [m]";
  parameter Real L_stick = 1.4 "Stick length [m]";
  parameter Real m_payload = 300.0 "Payload mass [kg]";
  parameter Real Q_cmd_max = 0.003 "Maximum pump command flow [m3/s]";
  parameter Real F_dist_magnitude = 105.0 "Disturbance force magnitude [N]";
  parameter Real T_total = 10.0 "Total mission duration [s]";
  parameter Real F_command = 1500.0 "Commanded output force [N]";

  // ===== Hydraulic Supply Parameters =====
  parameter Real p_supply = 20.0e6 "Supply pressure setpoint [Pa]";
  parameter Real p_relief = 25.0e6 "Relief valve pressure [Pa]";
  parameter Real p_tank = 0.5e6 "Tank pressure [Pa]";
  parameter Real beta_e = 1.2e9 "Effective bulk modulus [Pa]";
  parameter Real V_line = 0.05 "Supply line volume [m3]";
  parameter Real p_margin = 2.0e6 "Pump pressure margin [Pa]";
  parameter Real Cv_relief = 5.0e-6 "Relief valve conductance [m3/(s.sqrt(Pa))]";

  // ===== Boom Cylinder Parameters =====
  parameter Real A_b_piston = 5.0265e-3 "Boom piston area [m2]";
  parameter Real A_b_rod = 2.0106e-3 "Boom rod area [m2]";
  parameter Real V_b_dead = 1.0e-4 "Boom dead volume per chamber [m3]";
  parameter Real x_b_stroke = 1.2 "Boom stroke [m]";
  parameter Real m_boom_struct = 50.0 "Boom structural mass [kg]";
  parameter Real b_boom = 2000.0 "Boom viscous damping [N.s/m]";
  parameter Real k_boom_return = 2.0e5 "Boom return spring [N/m]";
  parameter Real x_b0 = 0.6 "Boom initial position [m]";
  parameter Real Cv_boom = 8.0e-7 "Boom valve conductance [m3/(s.sqrt(Pa))]";
  parameter Real k_endstop = 5.0e6 "End-stop stiffness [N/m]";
  parameter Real x_endstop_margin = 0.05 "End-stop margin [m]";

  // ===== Stick Cylinder Parameters =====
  parameter Real A_s_piston = 2.8274e-3 "Stick piston area [m2]";
  parameter Real A_s_rod = 1.1310e-3 "Stick rod area [m2]";
  parameter Real V_s_dead = 6.0e-5 "Stick dead volume per chamber [m3]";
  parameter Real x_s_stroke = 0.9 "Stick stroke [m]";
  parameter Real m_stick_struct = 30.0 "Stick structural mass [kg]";
  parameter Real b_stick = 1500.0 "Stick viscous damping [N.s/m]";
  parameter Real k_stick_return = 1.5e5 "Stick return spring [N/m]";
  parameter Real x_s0 = 0.45 "Stick initial position [m]";
  parameter Real Cv_stick = 5.0e-7 "Stick valve conductance [m3/(s.sqrt(Pa))]";

  // ===== Contact Parameters =====
  parameter Real k_contact = 1.0e5 "Contact stiffness [N/m]";
  parameter Real b_contact = 3.0e3 "Contact damping [N.s/m]";
  parameter Real x_contact_nom = 0.585 "Contact spring rest position [m]";

  // ===== Controller Parameters =====
  parameter Real Kp_force = 1.0e4 "Force P gain [Pa/N]";
  parameter Real Ki_force = 2.0e3 "Force I gain [Pa/(N.s)]";
  parameter Real Kp_press = 1.0e-7 "Pressure P gain [1/Pa]";
  parameter Real Ki_press = 1.0e-8 "Pressure I gain [1/(Pa.s)]";
  parameter Real Kp_stick_pos = 5.0 "Stick position P gain [1/m]";
  parameter Real Kd_stick_pos = 50.0 "Stick position D gain [s/m]";
  parameter Real u_sat = 1.0 "Valve command saturation [-]";
  parameter Real p_bias_boom = 1.0979e6 "Boom pressure controller bias [Pa]";

  // ===== Dynamic States =====
  // Boom cylinder
  Real x_boom(start=x_b0, fixed=true) "Boom piston position [m]";
  Real v_boom(start=0.0, fixed=true) "Boom piston velocity [m/s]";
  Real p_boom_a(start=1.0979e6, fixed=true) "Boom cap-end pressure [Pa]";
  Real p_boom_b(start=2.0e6, fixed=true) "Boom rod-end pressure [Pa]";

  // Stick cylinder
  Real x_stick(start=x_s0, fixed=true) "Stick piston position [m]";
  Real v_stick(start=0.0, fixed=true) "Stick piston velocity [m/s]";
  Real p_stick_a(start=0.8004e6, fixed=true) "Stick cap-end pressure [Pa]";
  Real p_stick_b(start=2.0e6, fixed=true) "Stick rod-end pressure [Pa]";

  // Supply line
  Real p_line(start=p_supply, fixed=true) "Supply line pressure [Pa]";

  // Controller integrators
  Real force_int(start=0.0, fixed=true) "Force loop integrator [N.s]";
  Real press_int(start=0.0, fixed=true) "Pressure loop integrator [Pa.s]";

  // ===== Algebraic Variables =====
  Real Q_pump "Pump output flow [m3/s]";
  Real Q_relief "Relief valve flow [m3/s]";
  Real Q_boom_a "Boom cap-end flow [m3/s]";
  Real Q_boom_b "Boom rod-end flow [m3/s]";
  Real Q_stick_a "Stick cap-end flow [m3/s]";
  Real Q_stick_b "Stick rod-end flow [m3/s]";
  Real Q_supply_boom "Boom supply draw [m3/s]";
  Real Q_supply_stick "Stick supply draw [m3/s]";

  Real u_boom_raw "Boom raw valve command [-]";
  Real u_boom "Boom saturated valve command [-]";
  Real u_stick_raw "Stick raw valve command [-]";
  Real u_stick "Stick saturated valve command [-]";

  Real F_err "Force tracking error [N]";
  Real p_ref_boom "Boom pressure reference [Pa]";
  Real p_err_boom "Boom pressure error [Pa]";

  Real F_boom_hyd "Boom hydraulic force [N]";
  Real F_stick_hyd "Stick hydraulic force [N]";
  Real F_contact "Contact spring force [N]";
  Real F_contact_damp "Contact damping force [N]";
  Real F_disturbance "Disturbance force [N]";
  Real F_boom_endstop "Boom end-stop force [N]";
  Real F_stick_endstop "Stick end-stop force [N]";
  Real F_meas "Measured contact force [N]";

  Real F_tracking_err "Primary tracking error [N]";

  Real boom_end_margin "Boom end-stop margin [m]";
  Real stick_end_margin "Stick end-stop margin [m]";
  Real p_boom_max "Max boom chamber pressure [Pa]";
  Real p_stick_max "Max stick chamber pressure [Pa]";
  Real Q_total_demand "Total flow demand [m3/s]";

  Boolean dist_active "Disturbance active flag";

  Real m_boom_eq "Boom equivalent mass [kg]";
  Real m_stick_eq "Stick equivalent mass [kg]";

equation
  // ===== Effective Masses =====
  m_boom_eq = m_payload + m_boom_struct;
  m_stick_eq = m_stick_struct;

  // ===== Disturbance Injection (middle third of T_total) =====
  dist_active = (time >= T_total/3.0) and (time <= 2.0*T_total/3.0);
  F_disturbance = if dist_active then F_dist_magnitude else 0.0;

  // ===== End-Stop Margins =====
  boom_end_margin = min(x_boom, x_b_stroke - x_boom);
  stick_end_margin = min(x_stick, x_s_stroke - x_stick);

  // ===== Soft End-Stop Forces (prevent impact) =====
  F_boom_endstop = k_endstop * (max(x_endstop_margin - x_boom, 0.0)
    - max(x_boom - (x_b_stroke - x_endstop_margin), 0.0));
  F_stick_endstop = k_endstop * (max(x_endstop_margin - x_stick, 0.0)
    - max(x_stick - (x_s_stroke - x_endstop_margin), 0.0));

  // ===== Pump Model (pressure-compensated, flow-limited) =====
  Q_pump = Q_cmd_max * max(0.0, min(1.0, (p_supply + p_margin - p_line) / p_margin));

  // ===== Relief Valve =====
  Q_relief = Cv_relief * sqrt(max(p_line - p_relief, 0.0));

  // ===== Supply Line Pressure Dynamics =====
  Q_total_demand = Q_supply_boom + Q_supply_stick;
  der(p_line) = (beta_e / V_line) * (Q_pump - Q_relief - Q_total_demand);

  // ===== Boom Valve (4/3 proportional) =====
  Q_boom_a = if u_boom >= 0.0 then
    u_boom * Cv_boom * sqrt(max(p_line - p_boom_a, 1.0e3)) else
    u_boom * Cv_boom * sqrt(max(p_boom_a - p_tank, 1.0e3));
  Q_boom_b = if u_boom >= 0.0 then
    -u_boom * Cv_boom * sqrt(max(p_boom_b - p_tank, 1.0e3)) else
    -u_boom * Cv_boom * sqrt(max(p_line - p_boom_b, 1.0e3));
  Q_supply_boom = if u_boom >= 0.0 then Q_boom_a else Q_boom_b;

  // ===== Stick Valve (4/3 proportional) =====
  Q_stick_a = if u_stick >= 0.0 then
    u_stick * Cv_stick * sqrt(max(p_line - p_stick_a, 1.0e3)) else
    u_stick * Cv_stick * sqrt(max(p_stick_a - p_tank, 1.0e3));
  Q_stick_b = if u_stick >= 0.0 then
    -u_stick * Cv_stick * sqrt(max(p_stick_b - p_tank, 1.0e3)) else
    -u_stick * Cv_stick * sqrt(max(p_line - p_stick_b, 1.0e3));
  Q_supply_stick = if u_stick >= 0.0 then Q_stick_a else Q_stick_b;

  // ===== Boom Cylinder Chamber Pressure Dynamics =====
  der(p_boom_a) = (beta_e / (V_b_dead + A_b_piston * x_boom))
    * (Q_boom_a - A_b_piston * v_boom);
  der(p_boom_b) = (beta_e / (V_b_dead + A_b_rod * (x_b_stroke - x_boom)))
    * (A_b_rod * v_boom - Q_boom_b);

  // ===== Stick Cylinder Chamber Pressure Dynamics =====
  der(p_stick_a) = (beta_e / (V_s_dead + A_s_piston * x_stick))
    * (Q_stick_a - A_s_piston * v_stick);
  der(p_stick_b) = (beta_e / (V_s_dead + A_s_rod * (x_s_stroke - x_stick)))
    * (A_s_rod * v_stick - Q_stick_b);

  // ===== Boom Mechanical Dynamics =====
  F_boom_hyd = A_b_piston * p_boom_a - A_b_rod * p_boom_b;
  F_contact = k_contact * (x_boom - x_contact_nom);
  F_contact_damp = b_contact * v_boom;
  F_meas = F_contact;

  der(x_boom) = v_boom;
  m_boom_eq * der(v_boom) = F_boom_hyd
    - b_boom * v_boom
    - k_boom_return * (x_boom - x_b0)
    - (F_contact + F_contact_damp)
    - F_disturbance
    + F_boom_endstop;

  // ===== Stick Mechanical Dynamics =====
  F_stick_hyd = A_s_piston * p_stick_a - A_s_rod * p_stick_b;

  der(x_stick) = v_stick;
  m_stick_eq * der(v_stick) = F_stick_hyd
    - b_stick * v_stick
    - k_stick_return * (x_stick - x_s0)
    + F_stick_endstop;

  // ===== Cascaded Force/Pressure Controller (Boom) =====
  // Outer loop: force regulation -> pressure reference
  F_err = F_command - F_meas;
  der(force_int) = F_err;
  p_ref_boom = p_bias_boom + Kp_force * F_err + Ki_force * force_int;

  // Inner loop: pressure regulation -> valve command
  p_err_boom = p_ref_boom - p_boom_a;
  der(press_int) = p_err_boom;
  u_boom_raw = Kp_press * p_err_boom + Ki_press * press_int;

  // Valve command saturation
  u_boom = if u_boom_raw > u_sat then u_sat
    else if u_boom_raw < -u_sat then -u_sat else u_boom_raw;

  // ===== Stick Position Hold Controller =====
  u_stick_raw = Kp_stick_pos * (x_s0 - x_stick) - Kd_stick_pos * v_stick;
  u_stick = if u_stick_raw > u_sat then u_sat
    else if u_stick_raw < -u_sat then -u_sat else u_stick_raw;

  // ===== Primary Tracking Error =====
  F_tracking_err = F_command - F_meas;

  // ===== Safety Observables =====
  p_boom_max = max(p_boom_a, p_boom_b);
  p_stick_max = max(p_stick_a, p_stick_b);

  annotation (
    experiment(StopTime=10.0, Interval=0.01, Tolerance=1e-6),
    Documentation(info="HydBoomForceB: Fluid-power robotic actuator with cascaded pressure/force control.
      Boom: 2.0 m, Stick: 1.4 m, Payload: 300 kg.
      Two double-acting cylinders sharing a load-sensing pump (Q_max=0.003 m3/s) and relief valve (25 MPa).
      Compliant contact with 105 N disturbance injected during middle third (3.33-6.67 s).
      Primary tracking error requirement: < 24 N after 6.5 s.
      Run at 100 Hz for 10 s (Interval=0.01 s).")
  );
end HydBoomForceB;