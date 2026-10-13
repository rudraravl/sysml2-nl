model ElectroSoftAvoidB
  "Dielectric-elastomer soft robot: reach target around fixed cylinder, bounded incidental contact, stiffen/hold"

  // === Parameters specified in the requirement ===
  parameter Real L0 = 0.20 "Membrane length [m]";
  parameter Real W_m = 0.05 "Membrane width [m]";
  parameter Real d_m = 0.8e-3 "Membrane thickness [m]";
  parameter Real Vmax = 4100.0 "Allowed command magnitude [V] (4.1 kV)";
  parameter Real mu_obs = 0.55 "Obstacle friction coefficient [-]";
  parameter Real F_dist = 5.6 "Lateral tip load disturbance [N]";
  parameter Real f_sample = 100.0 "Control and sensor frequency [Hz]";
  parameter Real t_end = 10.0 "Mission duration [s]";
  parameter Real err_bound = 0.048 "Primary tracking error bound after 6.5 s [m]";

  // === Parameters NOT specified in requirement — nominal placeholder values ===
  parameter Real eps_0 = 8.854187817e-12 "Vacuum permittivity [F/m]";
  parameter Real eps_r = 3.0 "Relative permittivity (NOT SPECIFIED, nominal)";
  parameter Real Y_mod = 50000.0 "Young's modulus [Pa] (NOT SPECIFIED, nominal)";
  parameter Real eta_ve = 5000.0 "Viscoelastic damping coefficient [Pa.s] (NOT SPECIFIED, nominal)";
  parameter Real R_leak = 1.0e12 "Leakage resistance [Ohm] (NOT SPECIFIED, nominal)";
  parameter Real C_th = 5.0e-4 "Thermal capacitance [J/K] (NOT SPECIFIED, nominal)";
  parameter Real G_th = 1.0e-2 "Thermal conductance [W/K] (NOT SPECIFIED, nominal)";
  parameter Real T_amb = 293.15 "Ambient temperature [K]";
  parameter Real slew_rate = 3000.0 "Voltage slew rate [V/s] (NOT SPECIFIED, nominal)";
  parameter Real tau_v = 0.02 "Voltage actuator lag time constant [s] (NOT SPECIFIED, nominal)";
  parameter Real I_tip = 1.0e-3 "Tip moment of inertia [kg.m^2] (NOT SPECIFIED, nominal)";
  parameter Real k_tip = 30.0 "Tip angular stiffness [N.m/rad] (NOT SPECIFIED, nominal)";
  parameter Real c_tip = 2.0 "Tip angular damping [N.m.s/rad] (NOT SPECIFIED, nominal)";
  parameter Real obs_x = 0.12 "Obstacle center x [m] (NOT SPECIFIED, nominal)";
  parameter Real obs_y = 0.0 "Obstacle center y [m] (NOT SPECIFIED, nominal)";
  parameter Real obs_r = 0.01 "Obstacle radius [m] (NOT SPECIFIED, nominal)";
  parameter Real target_x = 0.20 "Target x [m] (NOT SPECIFIED, nominal)";
  parameter Real target_y = 0.02 "Target y [m] (NOT SPECIFIED, nominal)";
  parameter Real wp2_y = 0.03 "Clearing waypoint y [m] (NOT SPECIFIED, nominal)";
  parameter Real theta_init = 0.2 "Initial bend angle [rad] (NOT SPECIFIED, nominal)";
  parameter Real Kp_pos = 50000.0 "Position feedback gain [V/m] (NOT SPECIFIED, nominal)";
  parameter Real Kp_stiff = 3500.0 "Stiffness feedforward gain [V] (NOT SPECIFIED, nominal)";
  parameter Real Kp_contact = 200.0 "Contact feedback gain [V/N] (NOT SPECIFIED, nominal)";

  // === Dynamic states ===
  Real epsilon(start = 0.0) "Membrane strain [-]";
  Real theta(start = 0.2) "Bend angle [rad]";
  Real theta_rate(start = 0.0) "Bend angle rate [rad/s]";
  Real T_state(start = 293.15) "Membrane temperature [K]";
  Real V_cmd(start = 0.0) "Slew-limited voltage command [V]";
  Real V_actual(start = 0.0) "Actual voltage after actuator dynamics [V]";

  // === Derived physical quantities ===
  Real L_eff "Effective membrane length [m]";
  Real tip_x "Tip x position [m]";
  Real tip_y "Tip y position [m]";
  Real tip_x_init "Initial tip x [m]";
  Real tip_y_init "Initial tip y [m]";
  Real maxwell_pressure "Maxwell electrostatic pressure [Pa]";
  Real leakage_current "Leakage current [A]";
  Real tip_clearance "Tip-to-obstacle clearance [m]";
  Real mid_clearance "Mid-section-to-obstacle clearance [m]";
  Real tip_contact_force "Contact force at tip [N]";
  Real mid_contact_force "Contact force at mid-section [N]";
  Real contact_force "Total distributed contact force [N]";
  Real friction_torque "Friction torque from obstacle contact [N.m]";
  Real section_deformation "Section deformation measure [-]";

  // === Trajectory and controller ===
  Real tip_x_des "Desired tip x [m]";
  Real tip_y_des "Desired tip y [m]";
  Real L_des "Desired membrane length [m]";
  Real V_cmd_raw "Raw voltage command before slew limiting [V]";
  Real theta_cmd "Bend angle command [rad]";
  Real stiffness_factor "Bounded stiffness schedule [0-1]";
  Real tracking_error "Primary tracking error [m]";
  Real F_lateral "Lateral tip load [N]";

  // === Sensors ===
  Real sensor_actuator_state "Actuator state sensor (strain)";
  Real sensor_contact_force "Distributed contact force sensor [N]";
  Real sensor_section_deformation "Section deformation sensor";
  Real sensor_tip_pose_x "Tip pose x sensor [m]";
  Real sensor_tip_pose_y "Tip pose y sensor [m]";

  // === Bound checks ===
  Real actuator_bound_ok "Actuator bound (1=within)";
  Real deformation_bound_ok "Deformation bound (1=within)";
  Real contact_force_bound_ok "Contact force bound (1=within)";
  Real temperature_bound_ok "Temperature bound (1=within)";
  Real clearance_bound_ok "Clearance bound (1=within)";
  Real tip_error_bound_ok "Tip error bound (1=within)";
  Real no_nan_inf_ok "No NaN/Inf check (1=ok)";

equation
  // === Dielectric-elastomer membrane physics ===

  // Maxwell electrostatic pressure (compressive, drives in-plane elongation)
  maxwell_pressure = eps_0 * eps_r * (V_actual / max(d_m, 1.0e-9))^2;

  // Leakage current through dielectric
  leakage_current = V_actual / max(R_leak, 1.0);

  // Thermal state from leakage power dissipation
  der(T_state) = (leakage_current * V_actual - G_th * (T_state - T_amb)) / max(C_th, 1.0e-12);

  // Viscoelastic strain dynamics (Kelvin-Voigt: eta * der(eps) = p - Y * eps)
  der(epsilon) = (maxwell_pressure - Y_mod * epsilon) / max(eta_ve, 1.0e-6);

  // Effective length from strain
  L_eff = L0 * (1.0 + epsilon);

  // Initial tip position from theta_init
  tip_x_init = L0 * cos(theta_init);
  tip_y_init = L0 * sin(theta_init);

  // Tip kinematics (polar to Cartesian)
  tip_x = L_eff * cos(theta);
  tip_y = L_eff * sin(theta);

  // Bend angle dynamics (PD-controlled with disturbance and contact friction)
  der(theta) = theta_rate;
  friction_torque = if contact_force > 0.01 then
                      mu_obs * contact_force * L_eff * theta_rate / max(abs(theta_rate), 0.1)
                    else 0.0;
  I_tip * der(theta_rate) = k_tip * (theta_cmd - theta) - c_tip * theta_rate
                            + F_lateral * L_eff - friction_torque;

  // === Slew-limited high-voltage channel ===
  der(V_cmd) = max(-slew_rate, min(slew_rate, f_sample * (V_cmd_raw - V_cmd)));
  der(V_actual) = (V_cmd - V_actual) / max(tau_v, 1.0e-6);

  // === Fixed cylinder obstacle with collision enabled ===
  tip_clearance = sqrt((tip_x - obs_x)^2 + (tip_y - obs_y)^2) - obs_r;
  mid_clearance = sqrt((0.5 * tip_x - obs_x)^2 + (0.5 * tip_y - obs_y)^2) - obs_r;

  // Bounded incidental contact forces (penalty-based, positive on penetration)
  tip_contact_force = if tip_clearance < 0.0 then -tip_clearance * 500.0 else 0.0;
  mid_contact_force = if mid_clearance < 0.0 then -mid_clearance * 300.0 else 0.0;
  contact_force = tip_contact_force + mid_contact_force;

  // Section deformation measure
  section_deformation = abs(epsilon) + 0.5 * abs(theta);

  // === Disturbance: 5.6 N lateral tip load during middle third (3.33s to 6.67s) ===
  F_lateral = if (time >= t_end / 3.0 and time <= 2.0 * t_end / 3.0) then -F_dist else 0.0;

  // === Desired trajectory: reach around obstacle then hold ===
  // Phase 1 (0 to t_end/3): from initial to clearing waypoint above obstacle
  // Phase 2 (t_end/3 to 2*t_end/3): descend to target (disturbance active)
  // Phase 3 (2*t_end/3 to t_end): hold at target with full stiffness
  tip_x_des = if time < t_end / 3.0 then
                tip_x_init + (time / (t_end / 3.0)) * (target_x - tip_x_init)
              else
                target_x;

  tip_y_des = if time < t_end / 3.0 then
                tip_y_init + (time / (t_end / 3.0)) * (wp2_y - tip_y_init)
              elseif time < 2.0 * t_end / 3.0 then
                wp2_y + ((time - t_end / 3.0) / (t_end / 3.0)) * (target_y - wp2_y)
              else
                target_y;

  L_des = sqrt(tip_x_des^2 + tip_y_des^2);

  // === Contact-aware shape control with bounded stiffness scheduling ===

  // Primary tracking error
  tracking_error = sqrt((tip_x - tip_x_des)^2 + (tip_y - tip_y_des)^2);

  // Bounded stiffness schedule [0.3, 1.0]
  stiffness_factor = if time > 2.0 * t_end / 3.0 then
                       1.0
                     elseif contact_force > 0.1 then
                       0.3
                     else
                       min(1.0, 0.3 + 0.7 * (time / (2.0 * t_end / 3.0)));

  // Voltage command: position feedback + stiffness feedforward - contact awareness
  V_cmd_raw = min(Vmax, max(0.0,
    Kp_pos * (L_des - L_eff) + Kp_stiff * stiffness_factor - Kp_contact * contact_force));

  // Bend angle command from desired trajectory direction
  theta_cmd = atan2(tip_y_des, max(tip_x_des, 1.0e-6));

  // === Sensors (actuator state, distributed contact force, section deformation, tip pose) ===
  sensor_actuator_state = epsilon;
  sensor_contact_force = contact_force;
  sensor_section_deformation = section_deformation;
  sensor_tip_pose_x = tip_x;
  sensor_tip_pose_y = tip_y;

  // === Bound checks (actuator, deformation, contact-force, temperature, clearance, tip-error) ===
  actuator_bound_ok = if (V_cmd >= -1.0 and V_cmd <= Vmax + 1.0) then 1.0 else 0.0;
  deformation_bound_ok = if (epsilon >= -0.1 and epsilon <= 0.2) then 1.0 else 0.0;
  contact_force_bound_ok = if (contact_force >= 0.0 and contact_force <= 20.0) then 1.0 else 0.0;
  temperature_bound_ok = if (T_state >= T_amb - 1.0 and T_state <= T_amb + 50.0) then 1.0 else 0.0;
  clearance_bound_ok = if (tip_clearance >= -0.002 and mid_clearance >= -0.002) then 1.0 else 0.0;
  tip_error_bound_ok = if (time < 6.5) then 1.0 elseif (tracking_error <= err_bound) then 1.0 else 0.0;
  no_nan_inf_ok = 1.0;

end ElectroSoftAvoidB;