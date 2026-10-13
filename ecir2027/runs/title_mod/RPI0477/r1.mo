model VacuumToolPolishC
  "Contact-rich manipulation: vacuum tool polishing with tangential trajectory control and normal-force regulation"

  // === Physical parameters (from requirement) ===
  parameter Real m_cup(unit="kg") = 0.8 "Suction cup mass";
  parameter Real r_cup(unit="m") = 0.038 "Suction cup radius";
  parameter Real mu_fric = 0.50 "Friction coefficient";
  parameter Real p_vac_min(unit="Pa") = -70000.0 "Min vacuum pressure gauge (0 to -70 kPa)";
  parameter Real p_vac_max(unit="Pa") = 0.0 "Max vacuum pressure gauge";
  parameter Real F_max_linear(unit="N") = 294.0 "Max linear actuator command magnitude";
  parameter Real L_path(unit="m") = 0.50 "Surface path length";
  parameter Real T_sim(unit="s") = 12.0 "Simulation duration";
  parameter Real F_disturb(unit="N") = 6.3 "Disturbance force magnitude (middle third)";
  parameter Real F_normal_set(unit="N") = 20.0 "Normal force setpoint (within 12-30 N)";
  parameter Real F_normal_min(unit="N") = 12.0 "Minimum allowed normal force";
  parameter Real F_normal_max(unit="N") = 30.0 "Maximum allowed normal force";
  parameter Real track_err_limit(unit="m") = 0.021 "Tracking error limit after 7.8 s";
  parameter Real Ts(unit="s") = 0.008 "Control/sensor sample period (125 Hz)";

  // === Contact and surface parameters (specific values not stated; reasonable for stable contact) ===
  parameter Real k_contact(unit="N/m") = 50000.0 "Normal contact stiffness";
  parameter Real d_contact(unit="N.s/m") = 300.0 "Normal contact damping";
  parameter Real surf_ampl(unit="m") = 0.005 "Curved workpiece profile amplitude (curve shape not specified)";
  parameter Real surf_wavelen(unit="m") = 0.50 "Curved workpiece wavelength (one wave over path)";
  parameter Real v_eps(unit="m/s") = 0.001 "Friction velocity smoothing threshold";
  parameter Real integ_max(unit="N.s") = 5.0 "Integral anti-windup limit";

  // === Controller gains ===
  parameter Real kp_tan(unit="N/m") = 2000.0 "Tangential PD proportional gain";
  parameter Real kd_tan(unit="N.s/m") = 100.0 "Tangential PD derivative gain";
  parameter Real kp_fn = 3.0 "Normal force proportional gain (dimensionless)";
  parameter Real ki_fn(unit="1/s") = 10.0 "Normal force integral gain";

  // === Dynamic states ===
  Real x_tan(start=0.0, unit="m") "Tangential position along path";
  Real v_tan(start=0.0, unit="m/s") "Tangential velocity";
  Real y_tool(start=0.0004, unit="m") "Absolute normal position of tool (downward positive)";
  Real v_nor(start=0.0, unit="m/s") "Absolute normal velocity of tool";
  Real integ_fn(start=0.0, unit="N.s") "Normal force integral error";

  // === Surface profile ===
  Real y_surf(unit="m") "Surface height at current tangential position";
  Real dy_surf "Surface slope dy_surf/dx_tan";
  Real penetration(unit="m") "Tool penetration into surface (positive = contact)";
  Real v_rel_nor(unit="m/s") "Relative normal velocity (tool wrt surface)";

  // === Forces ===
  Real A_cup(unit="m2") "Cup cross-sectional area";
  Real F_normal(unit="N") "Normal contact force";
  Real F_vac(unit="N") "Vacuum suction force";
  Real F_friction(unit="N") "Friction force (opposes tangential motion)";
  Real F_disturbance(unit="N") "Disturbance force";
  Real e_fn(unit="N") "Normal force error";

  // === Control commands ===
  Real F_cmd_tan(unit="N") "Tangential command (unsaturated)";
  Real F_cmd_tan_sat(unit="N") "Tangential command (saturated to +/-294 N)";
  Real p_vac_cmd(unit="Pa") "Vacuum pressure command (unsaturated)";
  Real p_vac_sat(unit="Pa") "Vacuum pressure command (saturated to [-70 kPa, 0])";

  // === Trajectory ===
  Real x_des(unit="m") "Desired tangential position";
  Real v_des(unit="m/s") "Desired tangential velocity";
  Real s_norm "Normalized trajectory time";

  // === Sensors: joint encoders, wrist wrench, tool-tip pose ===
  Real x_tan_enc(unit="m") "Joint encoder: tangential position";
  Real v_tan_enc(unit="m/s") "Joint encoder: tangential velocity";
  Real F_normal_meas(unit="N") "Wrist wrench: normal force measurement";
  Real F_tan_meas(unit="N") "Wrist wrench: tangential force measurement";
  Real x_tip(unit="m") "Tool-tip pose: tangential position";
  Real y_tip(unit="m") "Tool-tip pose: normal position";

  // === Error and status monitors ===
  Real tracking_error(unit="m") "Primary tracking error |x_des - x_tan|";
  Real path_error(unit="m") "Path error";
  Boolean contact_active "Continuous contact maintained";
  Boolean force_in_bounds "Normal force within [12, 30] N";
  Boolean effort_in_bounds "Linear actuator effort within bounds";
  Boolean pressure_in_bounds "Vacuum pressure within bounds";
  Boolean joint_pos_in_bounds "Joint positions within path and contact limits";
  Boolean tracking_ok "Tracking error below 0.021 m after 7.8 s";
  Boolean all_constraints_ok "All constraints satisfied";

protected
  constant Real pi = 3.141592653589793;

equation
  // Cup cross-sectional area
  A_cup = pi * r_cup * r_cup;

  // Normalized trajectory time
  s_norm = time / T_sim;

  // Desired trajectory: quintic polynomial over 0.50 m in 12 s (smooth start/stop, zero end-point velocity)
  if s_norm <= 1.0 then
    x_des = L_path * (10.0 * s_norm^3 - 15.0 * s_norm^4 + 6.0 * s_norm^5);
    v_des = (L_path / T_sim) * (30.0 * s_norm^2 - 60.0 * s_norm^3 + 30.0 * s_norm^4);
  else
    x_des = L_path;
    v_des = 0.0;
  end if;

  // Curved workpiece profile (sinusoidal; specific curve shape not specified in requirement)
  y_surf = surf_ampl * sin(2.0 * pi * x_tan / surf_wavelen);
  dy_surf = (surf_ampl * 2.0 * pi / surf_wavelen) * cos(2.0 * pi * x_tan / surf_wavelen);

  // Contact kinematics: penetration and relative normal velocity
  penetration = y_tool - y_surf;
  v_rel_nor = v_nor - dy_surf * v_tan;

  // Normal contact force (compliant unilateral contact)
  if penetration > 0.0 then
    F_normal = k_contact * penetration + d_contact * v_rel_nor;
  else
    F_normal = 0.0;
  end if;

  // Disturbance: 6.3 N opposing tangential motion during middle third (4 s to 8 s)
  if time >= T_sim / 3.0 and time <= 2.0 * T_sim / 3.0 then
    F_disturbance = F_disturb;
  else
    F_disturbance = 0.0;
  end if;

  // Vacuum suction force: negative gauge pressure produces positive force toward surface
  F_vac = -p_vac_sat * A_cup;

  // Regularized Coulomb friction (smooth sign via tanh to avoid discontinuity at zero velocity)
  F_friction = mu_fric * abs(F_normal) * tanh(v_tan / v_eps);

  // Normal force error
  e_fn = F_normal_set - F_normal;

  // Normal force controller: PI with feedforward and anti-windup
  if integ_fn > integ_max and e_fn > 0.0 then
    der(integ_fn) = 0.0;
  elseif integ_fn < -integ_max and e_fn < 0.0 then
    der(integ_fn) = 0.0;
  else
    der(integ_fn) = e_fn;
  end if;

  // Vacuum pressure command: feedforward + PI correction
  p_vac_cmd = -(F_normal_set + kp_fn * e_fn + ki_fn * integ_fn) / A_cup;

  // Vacuum pressure saturation [p_vac_min, p_vac_max]
  if p_vac_cmd < p_vac_min then
    p_vac_sat = p_vac_min;
  elseif p_vac_cmd > p_vac_max then
    p_vac_sat = p_vac_max;
  else
    p_vac_sat = p_vac_cmd;
  end if;

  // Tangential PD controller
  F_cmd_tan = kp_tan * (x_des - x_tan) + kd_tan * (v_des - v_tan);

  // Linear actuator effort saturation [-294 N, 294 N]
  if F_cmd_tan > F_max_linear then
    F_cmd_tan_sat = F_max_linear;
  elseif F_cmd_tan < -F_max_linear then
    F_cmd_tan_sat = -F_max_linear;
  else
    F_cmd_tan_sat = F_cmd_tan;
  end if;

  // === Plant dynamics ===
  // Tangential: linear actuator drives along surface; friction and disturbance oppose
  der(x_tan) = v_tan;
  m_cup * der(v_tan) = F_cmd_tan_sat - F_friction - F_disturbance;

  // Normal: vacuum pulls toward surface; compliant contact resists
  der(y_tool) = v_nor;
  m_cup * der(v_nor) = F_vac - F_normal;

  // === Sensor readings ===
  x_tan_enc = x_tan;
  v_tan_enc = v_tan;
  F_normal_meas = F_normal;
  F_tan_meas = F_cmd_tan_sat - F_friction;
  x_tip = x_tan;
  y_tip = y_tool;

  // === Error metrics ===
  tracking_error = abs(x_des - x_tan);
  path_error = tracking_error;

  // === Status monitors ===
  contact_active = penetration > 0.0 and F_normal > 0.0;
  force_in_bounds = (F_normal >= F_normal_min) and (F_normal <= F_normal_max);
  effort_in_bounds = abs(F_cmd_tan_sat) <= F_max_linear;
  pressure_in_bounds = (p_vac_sat >= p_vac_min) and (p_vac_sat <= p_vac_max);
  joint_pos_in_bounds = (x_tan >= 0.0) and (x_tan <= L_path) and (penetration > 0.0);
  tracking_ok = (time < 7.8) or (tracking_error < track_err_limit);
  all_constraints_ok = force_in_bounds and effort_in_bounds and pressure_in_bounds
    and contact_active and tracking_ok and joint_pos_in_bounds;

  // === Safety assertions: no NaN/infinite, bounded physical and control values ===
  assert(tracking_error < 1.0, "Tracking error exceeded 1 m - possible numerical issue");
  assert(abs(F_normal) < 500.0, "Normal force exceeded 500 N - possible numerical issue");
  assert(abs(v_tan) < 10.0, "Tangential velocity exceeded 10 m/s - possible numerical issue");
  assert(abs(p_vac_sat) <= 70000.0, "Vacuum pressure out of range - possible numerical issue");

  annotation(
    experiment(StartTime=0, StopTime=12.0, Tolerance=1e-6, Interval=0.008),
    Documentation(info="Vacuum tool polishing system: tangential trajectory control with normal-force regulation.
  - 0.50 m surface path, 12 s duration, 125 Hz control/sensor rate
  - Normal force regulated to 20 N (within 12-30 N) via vacuum pressure (0 to -70 kPa gauge)
  - Linear actuator bounded at 294 N; vacuum actuator bounded at -70 kPa
  - 6.3 N disturbance injected during middle third (4-8 s)
  - Compliant contact with friction coefficient 0.50 on curved workpiece
  - Feedback: joint encoders, wrist wrench, tool-tip pose
  - Tracking error below 0.021 m required after 7.8 s
  - All state, command, and sensor traces synchronized as continuous variables")
  );

end VacuumToolPolishC;