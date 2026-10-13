model HydMotorForceA
  // Hydraulic motor force control system HydMotorForceA
  // Bidirectional 48 cm3/rev hydraulic motor, volumetric efficiency 0.92
  // 12:1 gearbox, 130 kg rotary table
  // Pressure-compensated proportional valve, command limit 0.001 m3/s
  // Cascaded pressure and force regulation at 80 Hz, 8 s scenario
  // 75 N load disturbance during middle third (2.667 s to 5.333 s)

  constant Real pi_c = 3.14159265358979 "Pi constant";

  // ===== Motor parameters =====
  parameter Real Dm = 48.0e-6 / (2.0 * pi_c) "Motor displacement [m3/rad]";
  parameter Real eta_v = 0.92 "Volumetric efficiency";
  parameter Real n_gear = 12.0 "Gearbox ratio";

  // ===== Load parameters =====
  parameter Real m_load = 130.0 "Table effective mass [kg]";
  parameter Real r_eff = 0.1 "Effective radius [m] — not specified, assumed";
  parameter Real k_contact = 1.0e5 "Contact stiffness [N/m] — not specified, assumed";
  parameter Real d_contact = 500.0 "Contact damping [N.s/m] — not specified, assumed";
  parameter Real J_motor = 0.01 "Motor rotor inertia [kg.m2] — not specified, assumed";
  parameter Real b_motor = 0.05 "Motor viscous friction [N.m.s/rad] — not specified, assumed";

  // ===== End-stop parameters =====
  parameter Real x_endstop = 0.05 "End-stop position [m] — not specified, assumed";
  parameter Real k_endstop = 1.0e7 "End-stop stiffness [N/m] — not specified, assumed";
  parameter Real d_endstop = 1.0e4 "End-stop damping [N.s/m] — not specified, assumed";

  // ===== Hydraulic parameters =====
  parameter Real P_supply = 21.0e6 "Supply pressure [Pa] — not specified, assumed";
  parameter Real P_relief = 25.0e6 "Relief pressure [Pa] — not specified, assumed";
  parameter Real C_oil = 1.0e-12 "Effective oil compliance [m3/Pa] — not specified, assumed";
  parameter Real k_relief = 1.0e-6 "Relief valve conductance [m3/(s.Pa)] — not specified, assumed";

  // ===== Control parameters =====
  parameter Real Ts_ctrl = 1.0 / 80.0 "Control sample time [s]";
  parameter Real F_cmd_val = 500.0 "Force command setpoint [N] — not specified, assumed";
  parameter Real Kp_force = 5000.0 "Force controller proportional gain [Pa/N] — not specified, assumed";
  parameter Real Ki_force = 20000.0 "Force controller integral gain [Pa/(N.s)] — not specified, assumed";
  parameter Real Kp_press = 2.5e-11 "Pressure controller proportional gain [m3/(s.Pa)] — not specified, assumed";
  parameter Real Ki_press = 1.25e-9 "Pressure controller integral gain [m3/(s.Pa.s)] — not specified, assumed";
  parameter Real u_limit = 0.001 "Valve command magnitude limit [m3/s]";
  parameter Real dP_cmd_limit = 20.0e6 "Pressure command limit [Pa] — not specified, assumed";
  parameter Real aw_force = 0.1 "Force anti-windup gain — not specified, assumed";
  parameter Real aw_press = 0.1 "Pressure anti-windup gain — not specified, assumed";

  // ===== Disturbance =====
  parameter Real F_dist = 75.0 "Disturbance magnitude [N]";
  parameter Real t_dist_start = 8.0 / 3.0 "Disturbance start time [s]";
  parameter Real t_dist_end = 2.0 * 8.0 / 3.0 "Disturbance end time [s]";

  // ===== Dynamic states =====
  Real P_a(start = 1.0e5) "Chamber A pressure [Pa]";
  Real P_b(start = 1.0e5) "Chamber B pressure [Pa]";
  Real omega_m(start = 0.0) "Motor angular velocity [rad/s]";
  Real theta_m(start = 0.0) "Motor angular position [rad]";
  Real x_load(start = 0.0) "Load linear displacement [m]";
  Real F_int(start = 0.0) "Force controller integral state [Pa]";
  Real P_int(start = 0.0) "Pressure controller integral state [m3/s]";

  // ===== Algebraic variables and sensors =====
  Real dP "Measured pressure difference [Pa]";
  Real T_motor "Motor torque [N.m]";
  Real F_motor "Motor output force at table [N]";
  Real F_contact "External contact force [N]";
  Real F_endstop "End-stop force [N]";
  Real F_disturbance "Applied disturbance force [N]";
  Real v_load "Load linear velocity [m/s]";
  Real Q_motor "Motor consumed flow [m3/s]";
  Real Q_relief_a "Relief flow port A [m3/s]";
  Real Q_relief_b "Relief flow port B [m3/s]";
  Real F_cmd "Force command [N]";
  Real F_err "Force tracking error [N]";
  Real dP_cmd "Unsaturated pressure difference command [Pa]";
  Real dP_cmd_sat "Saturated pressure command [Pa]";
  Real u_valve_raw "Unsaturated valve command [m3/s]";
  Real u_valve "Valve flow command [m3/s]";
  Real J_eq "Equivalent inertia at motor shaft [kg.m2]";

equation
  // Pressure difference
  dP = P_a - P_b;

  // Motor torque (ideal; mechanical efficiency not specified)
  T_motor = dP * Dm;

  // Motor volumetric flow
  Q_motor = Dm * omega_m / eta_v;

  // Motor output force at table through gearbox and effective radius
  F_motor = T_motor * n_gear / r_eff;

  // Contact force (compliant load)
  F_contact = k_contact * x_load + d_contact * v_load;

  // End-stop force (engages beyond x_endstop; not triggered in normal operation)
  F_endstop = if x_load > x_endstop then
      k_endstop * (x_load - x_endstop) + d_endstop * max(0.0, v_load)
    elseif x_load < -x_endstop then
      k_endstop * (x_load + x_endstop) + d_endstop * min(0.0, v_load)
    else
      0.0;

  // Load kinematics
  v_load = omega_m * r_eff / n_gear;
  der(x_load) = v_load;

  // Relief flows (over-pressure and cavitation protection)
  Q_relief_a = k_relief * max(0.0, P_a - P_relief) - k_relief * max(0.0, -P_a);
  Q_relief_b = k_relief * max(0.0, P_b - P_relief) - k_relief * max(0.0, -P_b);

  // Chamber pressure dynamics with relief protection
  der(P_a) = (u_valve - Q_motor - Q_relief_a) / C_oil;
  der(P_b) = (Q_motor - u_valve - Q_relief_b) / C_oil;

  // Equivalent inertia at motor shaft
  J_eq = J_motor + m_load * r_eff * r_eff / (n_gear * n_gear);

  // Motor/load dynamics
  der(omega_m) = (T_motor - (F_contact + F_disturbance + F_endstop) * r_eff / n_gear
    - b_motor * omega_m) / J_eq;
  der(theta_m) = omega_m;

  // Disturbance force: 75 N during middle third of 8 s scenario
  F_disturbance = if (time >= t_dist_start and time <= t_dist_end) then F_dist else 0.0;

  // ===== Force command =====
  F_cmd = F_cmd_val;
  F_err = F_cmd - F_contact;

  // ===== Outer loop: force controller (PI with anti-windup) =====
  dP_cmd = Kp_force * F_err + Ki_force * F_int;
  dP_cmd_sat = if dP_cmd > dP_cmd_limit then dP_cmd_limit
    elseif dP_cmd < -dP_cmd_limit then -dP_cmd_limit
    else dP_cmd;
  der(F_int) = F_err - aw_force * (dP_cmd - dP_cmd_sat);

  // ===== Inner loop: pressure controller (PI with anti-windup) =====
  u_valve_raw = Kp_press * (dP_cmd_sat - dP) + Ki_press * P_int;
  u_valve = if u_valve_raw > u_limit then u_limit
    elseif u_valve_raw < -u_limit then -u_limit
    else u_valve_raw;
  der(P_int) = (dP_cmd_sat - dP) - aw_press * (u_valve_raw - u_valve);

  annotation(
    experiment(StartTime = 0, StopTime = 8.0, Tolerance = 1e-6, Interval = 0.0125),
    Documentation(info = "HydMotorForceA: Hydraulic motor force control system.
      Motor: 48 cm3/rev, eta_v=0.92, bidirectional.
      Gearbox: 12:1. Load: 130 kg rotary table via compliant contact.
      Valve: pressure-compensated proportional, cmd limit 0.001 m3/s.
      Control: cascaded pressure (inner) / force (outer) regulation at 80 Hz.
      Disturbance: 75 N during middle third (2.667 to 5.333 s) of 8 s scenario.
      Requirements: force tracking error < 27 N after 5.2 s,
      pressure/flow bounds via relief and saturation,
      no end-stop impact (end-stop at 0.05 m, steady-state at 0.005 m),
      stable hold, no NaN/infinite values."));
end HydMotorForceA;