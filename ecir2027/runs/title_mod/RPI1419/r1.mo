model ElectroSoftShapeC
  "Reduced-order dielectric-elastomer soft robot with shape feedback control"

  // ===== Physical constants =====
  constant Real eps0 = 8.854187817e-12 "F/m vacuum permittivity";
  constant Real g = 9.81 "m/s^2 gravitational acceleration";

  // ===== Stated parameters =====
  parameter Real L0 = 0.20 "m undeformed membrane length";
  parameter Real W_mem = 0.05 "m membrane width";
  parameter Real t0 = 0.8e-3 "m membrane thickness";
  parameter Real Vmax = 4600.0 "V max command magnitude (4.6 kV)";
  parameter Real Fdist = 5.4 "N tip load disturbance";
  parameter Real Ts = 1.0 / 125.0 "s control period (125 Hz)";
  parameter Real Tend = 12.0 "s total run time";
  parameter Real Tdist_on = 4.0 "s disturbance start (middle third of 12 s)";
  parameter Real Tdist_off = 8.0 "s disturbance end (middle third of 12 s)";
  parameter Real Tcheck = 7.8 "s tracking-error check time";
  parameter Real err_threshold = 0.047 "m primary tracking error bound after 7.8 s";

  // ===== Assumed parameters (not stated in request; labeled for transparency) =====
  parameter Real eps_r = 3.2 "relative permittivity (assumed: silicone DEA)";
  parameter Real E_young = 2.0e4 "Pa Young's modulus (assumed: soft elastomer)";
  parameter Real E_ve = 5.0e3 "Pa viscoelastic modulus (assumed)";
  parameter Real tau_ve = 0.12 "s viscoelastic time constant (assumed)";
  parameter Real c_damp = 0.5 "N.s/m structural damping (assumed)";
  parameter Real rho_mass = 1100.0 "kg/m3 membrane density (assumed)";
  parameter Real c_p = 1700.0 "J/(kg.K) specific heat (assumed)";
  parameter Real h_conv = 10.0 "W/(m2.K) convection coefficient (assumed)";
  parameter Real T_amb = 293.15 "K ambient temperature (assumed)";
  parameter Real rho_elec = 1.0e13 "ohm.m electrical resistivity (assumed)";
  parameter Real tip_mass = 0.010 "kg tip payload mass (assumed)";
  parameter Real k_lateral = 150.0 "N/m lateral bending stiffness (assumed)";
  parameter Real c_lateral = 1.5 "N.s/m lateral damping (assumed)";
  parameter Real SlewRate = 20000.0 "V/s HV channel slew rate (assumed)";
  parameter Real tau_hv = 0.01 "s HV channel time constant (assumed)";
  parameter Real x_target_set = 0.260 "m target tip x-position (assumed: 30% strain)";
  parameter Real Kp_ctrl = 100000.0 "V/m proportional gain (assumed)";
  parameter Real Kd_ctrl = 500.0 "V.s/m derivative gain (assumed)";

  // ===== Derived constants =====
  final parameter Real eps_dea = eps0 * eps_r "F/m absolute permittivity";
  final parameter Real A0 = W_mem * t0 "m2 cross-section";
  final parameter Real A_surf = 2.0 * W_mem * L0 "m2 surface area both sides";
  final parameter Real m_mem = rho_mass * L0 * W_mem * t0 "kg membrane mass";
  final parameter Real m_eff = m_mem / 3.0 + tip_mass "kg effective mass";
  final parameter Real R_leak = rho_elec * t0 / (W_mem * L0) "ohm leakage resistance";
  final parameter Real C_dea = eps_dea * W_mem * L0 / t0 "F DEA capacitance";
  final parameter Real k_spring = E_young * A0 / L0 "N/m axial stiffness";

  // ===== Dynamic states =====
  Real x_tip(start = L0, fixed = true) "m tip x-position (elongation direction)";
  Real v_tip(start = 0.0, fixed = true) "m/s tip x-velocity";
  Real y_tip(start = 0.0, fixed = true) "m tip y-position (lateral deflection)";
  Real v_y_tip(start = 0.0, fixed = true) "m/s tip y-velocity";
  Real T_mem(start = T_amb, fixed = true) "K membrane temperature";
  Real sigma_ve(start = 0.0, fixed = true) "Pa viscoelastic stress internal state";
  Real V_act(start = 0.0, fixed = true) "V actual HV channel output (slew-limited)";

  // ===== Discrete states =====
  Integer fsm_state(start = 0) "FSM: 0=INIT 1=TRACK 2=DISTURBED 3=HOLD";
  discrete Real V_cmd_sampled(start = 0.0) "V sampled controller command at 125 Hz";

  // ===== Intermediate variables =====
  Real strain "dimensionless axial strain";
  Real t_mem "m current membrane thickness";
  Real L_act "m actuated membrane length";
  Real p_maxwell "Pa Maxwell electrostatic pressure";
  Real F_act "N actuation force along x";
  Real F_spring "N elastic restoring force";
  Real F_damp "N structural damping force";
  Real F_ve "N viscoelastic force";
  Real F_gravity "N gravity force on effective mass";
  Real F_disturbance "N applied lateral disturbance force";
  Real I_leak "A leakage current through membrane";
  Real P_leak "W leakage power dissipation";
  Real V_cmd_clamped "V clamped command [0, Vmax]";
  Real slew_cmd "V/s slew-limited derivative command";

  // ===== Sensors =====
  Real strain_sensor "dimensionless strain reading";
  Real curvature "1/m reduced-order curvature estimate";
  Real tip_force_sensor "N internal force/pressure sensor";
  Real temp_sensor "K temperature sensor";
  Real V_sensor "V voltage sensor";
  Real tip_pose_x_sensor "m tip x-position sensor";
  Real tip_pose_y_sensor "m tip y-position sensor";

  // ===== Tracking and shape error =====
  Real tracking_error "m primary x-axis tracking error";
  Real shape_error "m Euclidean shape error to target";

  // ===== Shared-frame geometry (undeformed vs actuated) =====
  Real x_undeformed_tip = L0 "m undeformed tip x in shared frame";
  Real y_undeformed_tip = 0.0 "m undeformed tip y in shared frame";
  Real x_actuated_tip = x_tip "m actuated tip x in shared frame";
  Real y_actuated_tip = y_tip "m actuated tip y in shared frame";

  // ===== Bound checks =====
  Boolean actuator_bound_ok "V_act within [0, Vmax]";
  Boolean strain_bound_ok "strain within physical limits";
  Boolean temp_bound_ok "temperature within safe range";
  Boolean fsm_bound_ok "FSM in valid state";
  Boolean finite_state_ok "all states finite (no NaN/Inf)";
  Boolean shape_error_ok "shape error below 0.047 m after 7.8 s";
  Boolean all_bounds_ok "all bound checks satisfied";

equation

  // --- Strain and thickness (incompressibility approximation) ---
  strain = (x_tip - L0) / L0;
  L_act = x_tip;
  t_mem = t0 / (1.0 + strain + 1.0e-9);

  // --- Maxwell electrostatic pressure and actuation force ---
  p_maxwell = eps_dea * (V_act / (t_mem + 1.0e-12)) ^ 2;
  F_act = p_maxwell * W_mem * t0;

  // --- Elastic, damping, and viscoelastic restoring forces ---
  F_spring = k_spring * (x_tip - L0);
  F_damp = c_damp * v_tip;
  F_ve = sigma_ve * A0;

  // --- Viscoelastic internal state (Maxwell element) ---
  der(sigma_ve) = E_ve * (v_tip / L0) - sigma_ve / tau_ve;

  // --- Gravity and disturbance ---
  F_gravity = m_eff * g;
  F_disturbance = if (time >= Tdist_on and time <= Tdist_off) then -Fdist else 0.0;

  // --- Axial dynamics (elongation along x) ---
  m_eff * der(v_tip) = F_act - F_spring - F_damp - F_ve;
  der(x_tip) = v_tip;

  // --- Lateral dynamics (gravity sag + disturbance along y) ---
  m_eff * der(v_y_tip) = F_disturbance - F_gravity - k_lateral * y_tip - c_lateral * v_y_tip;
  der(y_tip) = v_y_tip;

  // --- Leakage current and thermal state ---
  I_leak = V_act / (R_leak + 1.0);
  P_leak = V_act * I_leak;
  m_mem * c_p * der(T_mem) = P_leak - h_conv * A_surf * (T_mem - T_amb);

  // --- Sampled PD controller at 125 Hz ---
  when sample(0, Ts) then
    V_cmd_sampled = Kp_ctrl * (x_target_set - x_tip) - Kd_ctrl * v_tip;
  end when;

  // --- Command clamping to [0, Vmax] ---
  V_cmd_clamped = if V_cmd_sampled > Vmax then Vmax
                  else if V_cmd_sampled < 0.0 then 0.0
                  else V_cmd_sampled;

  // --- Slew-limited HV channel ---
  slew_cmd = if (V_cmd_clamped - V_act) / tau_hv > SlewRate then SlewRate
             else if (V_cmd_clamped - V_act) / tau_hv < -SlewRate then -SlewRate
             else (V_cmd_clamped - V_act) / tau_hv;

  // --- V_act bounded derivative (prevents excursion past [0, Vmax]) ---
  der(V_act) = if (V_act <= 0.0) and (slew_cmd < 0.0) then 0.0
               else if (V_act >= Vmax) and (slew_cmd > 0.0) then 0.0
               else slew_cmd;

  // --- Sensors (synchronized traces) ---
  strain_sensor = strain;
  curvature = 2.0 * y_tip / (L_act * L_act + 1.0e-12);
  tip_force_sensor = F_spring + F_ve + F_damp;
  temp_sensor = T_mem;
  V_sensor = V_act;
  tip_pose_x_sensor = x_tip;
  tip_pose_y_sensor = y_tip;

  // --- Tracking and shape error ---
  tracking_error = abs(x_target_set - x_tip);
  shape_error = sqrt((x_target_set - x_tip) ^ 2 + y_tip ^ 2 + 1.0e-12);

  // --- Finite state machine ---
  when time >= 0.1 then
    fsm_state = 1;
  elsewhen time >= Tdist_on then
    fsm_state = 2;
  elsewhen time >= Tdist_off then
    fsm_state = 3;
  end when;

  // --- Bound checks ---
  actuator_bound_ok = (V_act >= -0.001) and (V_act <= Vmax + 0.001);
  strain_bound_ok = (strain > -0.5) and (strain < 2.0);
  temp_bound_ok = (T_mem > 200.0) and (T_mem < 500.0);
  fsm_bound_ok = (fsm_state >= 0) and (fsm_state <= 3);
  finite_state_ok = (x_tip > -1.0e6) and (x_tip < 1.0e6) and
                    (v_tip > -1.0e6) and (v_tip < 1.0e6) and
                    (y_tip > -1.0e6) and (y_tip < 1.0e6) and
                    (v_y_tip > -1.0e6) and (v_y_tip < 1.0e6) and
                    (T_mem > 0.0) and (T_mem < 1.0e4) and
                    (V_act >= -1.0) and (V_act < 1.0e6) and
                    (sigma_ve > -1.0e8) and (sigma_ve < 1.0e8);
  shape_error_ok = (time < Tcheck) or (shape_error <= err_threshold);
  all_bounds_ok = actuator_bound_ok and strain_bound_ok and temp_bound_ok and
                  fsm_bound_ok and finite_state_ok and shape_error_ok;

annotation(
  experiment(StartTime = 0.0, StopTime = 12.0, Tolerance = 1.0e-6, Interval = 0.008),
  Documentation(info = "ElectroSoftShapeC: Dielectric-elastomer membrane soft robot (0.20 m x 0.05 m x 0.8 mm) "
    "with reduced-order deformation model, shape feedback control at 125 Hz for 12 s. "
    "Max command 4.6 kV, 5.4 N tip load disturbance during middle third (4-8 s). "
    "Primary tracking error required below 0.047 m after 7.8 s. "
    "Parameters not stated in the requirement are labeled as assumed.")
);

end ElectroSoftShapeC;