model ElectroSoftShapeA
  "Dielectric-elastomer membrane soft robot with HV shape control"

  // --- Physical constants ---
  constant Real g = 9.81 "Gravitational acceleration [m/s2]";
  constant Real eps0 = 8.854187817e-12 "Vacuum permittivity [F/m]";

  // --- Geometry (from requirement) ---
  parameter Real L0 = 0.20 "Undeformed length [m]";
  parameter Real W = 0.05 "Undeformed width [m]";
  parameter Real t0 = 0.8e-3 "Undeformed thickness [m]";
  parameter Real A0 = L0 * W "Undeformed membrane area [m2]";

  // --- Material (assumed where not stated) ---
  parameter Real eps_r = 3.0 "Relative permittivity [-], assumed";
  parameter Real rho = 1000.0 "Density [kg/m3], assumed";
  parameter Real sigma_leak = 1.0e-13 "Leakage conductivity [S/m], assumed";
  parameter Real cp_therm = 1700.0 "Specific heat [J/(kg.K)], assumed";
  parameter Real h_conv = 15.0 "Convection coefficient [W/(m2.K)], assumed";
  parameter Real T_amb = 293.15 "Ambient temperature [K]";

  // --- Reduced-order mechanics (assumed lumped) ---
  parameter Real m_eff = 0.01 "Effective moving mass [kg], assumed";
  parameter Real k_spring = 100.0 "Equivalent elastic stiffness [N/m], assumed";
  parameter Real c_damp = 1.0 "Viscous damping [N.s/m], assumed";
  parameter Real k_act = 2.3148e-7 "Actuation force gain [N/V2], tuned";

  // --- Actuator (from requirement) ---
  parameter Real V_max = 3.6e3 "Command voltage magnitude limit [V]";
  parameter Real V_slew = 5.0e3 "Voltage slew rate [V/s], assumed";

  // --- Control (assumed) ---
  parameter Real V_ff = 3.6e3 "Feedforward holding voltage [V]";
  parameter Real Kp_ctrl = 1.0e5 "Proportional gain [V/m], assumed";
  parameter Real target_delta = 0.03 "Declared target elongation [m]";
  parameter Real target_tip_x = L0 + target_delta "Target tip x-position [m]";

  // --- Disturbance (from requirement) ---
  parameter Real F_dist = 3.0 "Tip load disturbance [N]";
  parameter Real t_dist_start = 8.0 / 3.0 "Disturbance start [s]";
  parameter Real t_dist_end = 16.0 / 3.0 "Disturbance end [s]";

  // --- Sampling (from requirement) ---
  parameter Real dt_sample = 1.0 / 80.0 "Control sample period [s]";
  parameter Real t_end = 8.0 "Scenario duration [s]";

  // --- Bounds (from requirement) ---
  parameter Real track_bound = 0.061 "Tracking error bound [m]";
  parameter Real t_track_check = 5.2 "Tracking check time [s]";

  // --- Continuous states ---
  Real delta(start = 0.0, fixed = true) "Elongation [m]";
  Real delta_dot(start = 0.0, fixed = true) "Elongation rate [m/s]";
  Real V_cmd(start = 0.0, fixed = true) "Slew-limited voltage [V]";
  Real T_membrane(start = T_amb, fixed = true) "Membrane temperature [K]";

  // --- Discrete control states ---
  discrete Real error_d(start = 0.0, fixed = true) "Sampled shape error [m]";
  discrete Real V_raw_d(start = 0.0, fixed = true) "Raw voltage command [V]";
  discrete Real V_target_d(start = 0.0, fixed = true) "Target voltage after saturation [V]";
  discrete Real fsm_state(start = 0.0, fixed = true) "Finite state machine [0=idle,1=move,2=hold]";
  discrete Real track_err_logged(start = 0.0, fixed = true) "Error logged near 5.2 s [m]";
  discrete Real shape_err_final(start = 0.0, fixed = true) "Final shape error [m]";
  discrete Real b_actuator(start = 1.0, fixed = true) "Actuator bound [0/1]";
  discrete Real b_strain(start = 1.0, fixed = true) "Strain bound [0/1]";
  discrete Real b_temp(start = 1.0, fixed = true) "Temperature bound [0/1]";
  discrete Real b_fsm(start = 1.0, fixed = true) "State bound [0/1]";
  discrete Real b_shape(start = 1.0, fixed = true) "Shape error bound [0/1]";
  discrete Real b_track(start = 1.0, fixed = true) "Tracking bound [0/1]";
  discrete Real b_all(start = 1.0, fixed = true) "All bounds satisfied [0/1]";

  // --- Computed/observable quantities ---
  Real eps "Absolute permittivity [F/m]";
  Real mass_membrane "Membrane mass [kg]";
  Real stretch "Stretch ratio [-]";
  Real t_current "Current thickness [m]";
  Real A_cross "Cross-sectional area [m2]";
  Real C_dea "DEA capacitance [F]";
  Real V "Applied voltage [V]";
  Real P_maxwell "Maxwell pressure [Pa]";
  Real F_maxwell "Maxwell actuation force [N]";
  Real F_elastic "Elastic restoring force [N]";
  Real F_viscous "Viscous force [N]";
  Real F_gravity "Gravity force [N]";
  Real F_disturbance "Disturbance force [N]";
  Real I_leak "Leakage current [A]";
  Real Q_elec "Electric charge [C]";
  Real strain "Axial strain [-]";
  Real strain_rate "Strain rate [1/s]";
  Real curvature "Section curvature [1/m]";
  Real F_tension "Membrane tension [N]";
  Real tip_x "Actuated tip x [m]";
  Real tip_y "Actuated tip y [m]";
  Real tip_x_0 "Undeformed tip x [m]";
  Real tip_y_0 "Undeformed tip y [m]";
  Real tracking_error "Tip tracking error [m]";

  // --- Sensors ---
  Real sensor_force "Tendon force sensor [N]";
  Real sensor_strain "Strain sensor [-]";
  Real sensor_curvature "Curvature sensor [1/m]";
  Real sensor_tip_x "Tip x sensor [m]";
  Real sensor_tip_y "Tip y sensor [m]";
  Real sensor_temp "Temperature sensor [K]";

equation
  // --- Explicit permittivity ---
  eps = eps_r * eps0;

  // --- Geometry and mass ---
  mass_membrane = rho * A0 * t0;
  stretch = (L0 + delta) / L0;
  t_current = t0 / max(stretch, 0.01);
  A_cross = W * t_current;
  C_dea = eps * A0 / max(t_current, 1e-6);

  // --- Strain and curvature ---
  strain = delta / L0;
  strain_rate = delta_dot / L0;
  curvature = delta / (L0 * L0);

  // --- Maxwell pressure (physical reference, uses permittivity) ---
  P_maxwell = 0.5 * eps * (V / max(t_current, 1e-6))^2;

  // --- Actuation force (lumped reduced-order model) ---
  F_maxwell = k_act * V * V;

  // --- Viscoelastic forces (Kelvin-Voigt model) ---
  F_elastic = k_spring * delta;
  F_viscous = c_damp * delta_dot;

  // --- Gravity ---
  F_gravity = mass_membrane * g;

  // --- Disturbance: 3 N during middle third of 8 s ---
  if time >= t_dist_start and time <= t_dist_end then
    F_disturbance = F_dist;
  else
    F_disturbance = 0.0;
  end if;

  // --- Equation of motion ---
  m_eff * der(delta_dot) = F_maxwell - F_elastic - F_viscous + F_disturbance;
  der(delta) = delta_dot;

  // --- Leakage ---
  I_leak = sigma_leak * C_dea * V;
  Q_elec = C_dea * V;

  // --- Thermal state: Joule heating from leakage + convection ---
  der(T_membrane) = (I_leak * V - h_conv * 2.0 * A0 * (T_membrane - T_amb))
    / max(mass_membrane * cp_therm, 1e-9);

  // --- Tension ---
  F_tension = max(F_elastic, 0.0);

  // --- Undeformed and actuated geometry in shared frame ---
  tip_x_0 = L0;
  tip_y_0 = 0.0;
  tip_x = L0 + delta;
  tip_y = -F_gravity * L0 / (2.0 * max(F_tension, 1.0));

  // --- Tracking error ---
  tracking_error = target_tip_x - tip_x;

  // --- Slew-limited voltage channel (continuous rate limiter) ---
  V = V_cmd;
  der(V_cmd) = max(-V_slew, min(V_slew, 1.0e5 * (V_target_d - V_cmd)));

  // --- Sensors ---
  sensor_force = F_tension;
  sensor_strain = strain;
  sensor_curvature = curvature;
  sensor_tip_x = tip_x;
  sensor_tip_y = tip_y;
  sensor_temp = T_membrane;

  // --- Discrete control at 80 Hz ---
  when sample(0, dt_sample) then
    // Shape feedback via reduced-order deformation model (delta)
    error_d = target_tip_x - (L0 + delta);

    // P controller with feedforward
    V_raw_d = V_ff + Kp_ctrl * error_d;

    // Saturate to [0, V_max]
    if V_raw_d > V_max then
      V_target_d = V_max;
    elseif V_raw_d < 0.0 then
      V_target_d = 0.0;
    else
      V_target_d = V_raw_d;
    end if;

    // Finite state machine
    if time < 0.5 then
      fsm_state = 0.0; // idle
    elseif abs(error_d) > 0.005 then
      fsm_state = 1.0; // move
    else
      fsm_state = 2.0; // hold
    end if;

    // Log tracking error near 5.2 s
    if abs(time - t_track_check) < dt_sample then
      track_err_logged = abs(error_d);
    else
      track_err_logged = pre(track_err_logged);
    end if;

    // Final shape error
    if time >= t_end - dt_sample then
      shape_err_final = abs(error_d);
    else
      shape_err_final = pre(shape_err_final);
    end if;

    // Bound checks
    b_actuator = if V_cmd >= 0.0 and V_cmd <= V_max * 1.001 then 1.0 else 0.0;
    b_strain = if strain > -0.1 and strain < 0.5 then 1.0 else 0.0;
    b_temp = if T_membrane > 200.0 and T_membrane < 400.0 then 1.0 else 0.0;
    b_fsm = if fsm_state >= 0.0 and fsm_state <= 2.0 then 1.0 else 0.0;
    b_shape = if shape_err_final < track_bound then 1.0 else 0.0;
    b_track = if track_err_logged < track_bound then 1.0 else 0.0;
    b_all = b_actuator * b_strain * b_temp * b_fsm * b_shape * b_track;
  end when;

  annotation(
    experiment(StopTime = 8.0, Tolerance = 1e-6, Interval = 0.0125),
    Documentation(info = "ElectroSoftShapeA: Dielectric-elastomer membrane soft robot.
    Membrane: 0.20 x 0.05 m, 0.8 mm thick. Voltage limit: 3.6 kV.
    3 N tip load disturbance during middle third. 80 Hz control for 8 s.
    Tracking error bound: 0.061 m after 5.2 s.
    Material and control parameters assumed where not specified in requirement.")
  );
end ElectroSoftShapeA;