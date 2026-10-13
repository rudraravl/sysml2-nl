model ElectroSoftAvoidB
  /* Mission: reach a target around a fixed cylinder with bounded incidental
     contact, then stiffen/hold shape. Dielectric-elastomer membrane controlled
     by a slew-limited HV channel. Disturbance injected during the middle third.
     Unstated material/geometry facts are explicitly labeled as assumptions.
     Only requirement-stated numeric values are treated as authoritative. */

  // ===== Membrane geometry (stated) =====
  parameter Real L0 = 0.20 "membrane rest length [m]";
  parameter Real w0 = 0.05 "membrane width [m]";
  parameter Real t0 = 0.0008 "membrane thickness [m]";

  // ===== Dielectric-elastomer material (assumed lumped values) =====
  parameter Real eps_r = 4.7 "relative permittivity [-] (assumed)";
  parameter Real eps_0 = 8.854e-12 "vacuum permittivity [F/m]";
  parameter Real Y_mod = 5.0e4 "effective Young's modulus [Pa] (assumed)";
  parameter Real actuation_strain_max = 0.5 "max active strain at V_max [-] (assumed lumped coupling)";
  parameter Real tau_visco = 0.3 "viscoelastic time constant [s] (assumed)";
  parameter Real R_leak = 1.0e10 "leakage resistance [Ohm] (assumed)";
  parameter Real C_th = 0.5 "thermal capacitance [J/K] (assumed)";
  parameter Real G_th = 0.05 "thermal conductance [W/K] (assumed)";
  parameter Real T_amb = 293.15 "ambient temperature [K]";

  // ===== HV channel (stated magnitude; slew assumed) =====
  parameter Real V_max = 4100.0 "max allowed command magnitude [V]";
  parameter Real dVdt_max = 2000.0 "voltage slew limit [V/s] (assumed)";

  // ===== Mechanical lumped parameters (assumed) =====
  parameter Real m_tip = 0.05 "tip mass [kg] (assumed)";
  parameter Real k_base = 8.0 "base axial stiffness [N/m] (assumed)";
  parameter Real k_volt = 40.0 "voltage-dependent axial stiffness [N/m] (assumed)";
  parameter Real c_ax = 1.0 "axial damping [N.s/m] (assumed)";
  parameter Real c_tip = 0.6 "tip translational damping [N.s/m] (assumed)";
  parameter Real k_bend0 = 10.0 "base lateral bending stiffness [N/m] (assumed)";
  parameter Real k_bend_v = 300.0 "voltage-dependent bending stiffness [N/m] (assumed)";
  parameter Real c_bend = 2.0 "lateral damping [N.s/m] (assumed)";

  // ===== Fixed cylindrical obstacle (friction stated; geometry assumed) =====
  parameter Real obs_x = 0.17 "obstacle center x [m] (assumed position)";
  parameter Real obs_y = 0.02 "obstacle center y [m] (assumed position)";
  parameter Real obs_r = 0.02 "obstacle radius [m] (assumed)";
  parameter Real mu = 0.55 "friction coefficient [-]";
  parameter Real k_contact = 1500.0 "contact normal stiffness [N/m] (assumed)";
  parameter Real c_contact = 6.0 "contact normal damping [N.s/m] (assumed)";
  parameter Real v_small = 0.01 "friction regularization velocity [m/s]";

  // ===== Target (assumed) =====
  parameter Real target_x = 0.28 "target x [m] (assumed)";
  parameter Real target_y = 0.00 "target y [m]";

  // ===== Controller (assumed gains) =====
  parameter Real Kp_v = 12000.0 "voltage proportional gain [V/m] (assumed)";
  parameter Real V_hold = 0.85*V_max "shape-hold voltage [V]";
  parameter Real V_stiffen = 0.95*V_max "stiffen voltage [V]";
  parameter Real y_stiffen_thresh = 0.005 "lateral-deviation stiffen threshold [m]";
  parameter Real err_hold_band = 0.02 "near-target band [m]";

  // ===== Disturbance (stated) =====
  parameter Real F_dist = 5.6 "lateral tip load disturbance [N]";
  parameter Real t_dist_start = 10.0/3.0 "disturbance start [s]";
  parameter Real t_dist_end = 20.0/3.0 "disturbance end [s]";

  // ===== Bounds (stated where applicable) =====
  parameter Real bound_deformation = 0.6 "max section deformation [-] (assumed)";
  parameter Real bound_contact_force = 12.0 "max contact force [N] (assumed)";
  parameter Real bound_temperature = 350.0 "max temperature [K] (assumed)";
  parameter Real bound_clearance_min = -0.005 "min obstacle clearance [m] (assumed)";
  parameter Real bound_tip_error = 0.048 "primary tracking error bound after 6.5 s [m]";
  parameter Real t_error_check = 6.5 "error-check time [s]";

  // ===== Dynamic states =====
  Real x(start=0.02, fixed=true) "tip x position [m]";
  Real y(start=0.0, fixed=true) "tip y position [m]";
  Real vx(start=0.0, fixed=true) "tip x velocity [m/s]";
  Real vy(start=0.0, fixed=true) "tip y velocity [m/s]";
  Real V(start=0.0, fixed=true) "actuator voltage [V]";
  Real L_act(start=0.0, fixed=true) "active length contribution [m]";
  Real T(start=T_amb, fixed=true) "membrane temperature [K]";
  Real F_contact_filt(start=0.0, fixed=true) "filtered distributed contact force [N]";
  Real F_contact_imp(start=0.0, fixed=true) "contact force impulse [N.s]";

  // ===== Sensors / computed quantities =====
  Real L "current membrane length [m]";
  Real L_rest "rest length [m]";
  Real strain "section deformation [-]";
  Real k_eff "effective axial stiffness [N/m]";
  Real k_bend "effective bending stiffness [N/m]";
  Real p_maxwell "Maxwell pressure [Pa]";
  Real I_leak "leakage current [A]";
  Real P_leak "leakage power [W]";
  Real P_visco "viscoelastic dissipation [W]";
  Real F_axial "axial membrane force magnitude [N]";
  Real F_contact_n "contact normal force [N]";
  Real F_contact_t "contact friction force [N]";
  Real clearance "obstacle clearance [m]";
  Real tip_error "tip tracking error [m]";
  Real V_cmd "voltage command [V]";
  Real dV_cmd "command - voltage [V]";
  Boolean in_contact;
  Boolean disturbance_active;
  Real F_dist_y "applied disturbance force [N]";
  Real Fx_total "total tip force x [N]";
  Real Fy_total "total tip force y [N]";
  Real cnx "contact normal x (obstacle->tip)";
  Real cny "contact normal y (obstacle->tip)";
  Real ctx "contact tangent x";
  Real cty "contact tangent y";
  Real v_tan "tangential tip velocity [m/s]";
  Real dLdt "membrane length rate [m/s]";
  Real penetration "obstacle penetration [m]";
  Real pen_rate "penetration rate [m/s]";

protected
  Real L_safe "length guarded against zero [m]";
  Real d_safe "obstacle distance guarded against zero [m]";
  Real Fx_mem "membrane force x component [N]";
  Real Fy_mem "membrane force y component [N]";
  Real Fx_c "contact force x component [N]";
  Real Fy_c "contact force y component [N]";
  Real Fx_damp "tip damping x component [N]";
  Real Fy_damp "tip damping y component [N]";
  Real Fy_bend "lateral bending force [N]";
  Real V_cmd_raw "raw proportional command [V]";
  Real V_cmd_contact "contact-aware command [V]";
  Real V_cmd_stiff "stiffness-scheduled command [V]";
  Real V_cmd_hold "shape-hold command [V]";
  Real V_cmd_clamped "clamped command [V]";
  Real F_contact_n_raw "unclamped contact normal force [N]";
  Real dist_x "x distance to obstacle [m]";
  Real dist_y "y distance to obstacle [m]";
  Real dist2 "squared distance to obstacle [m^2]";
  Real V_norm2 "normalized voltage squared [-]";

equation
  // ----- Membrane kinematics -----
  L = sqrt(x*x + y*y);
  L_safe = max(L, 1e-6);
  dLdt = (x*vx + y*vy) / L_safe;
  L_rest = L0 + L_act;
  strain = (L - L0) / L0;

  // ----- Dielectric-elastomer electromechanics -----
  V_norm2 = (V / V_max) * (V / V_max);
  p_maxwell = eps_0 * eps_r * (V / t0) * (V / t0);
  k_eff = k_base + k_volt * V_norm2;
  k_bend = k_bend0 + k_bend_v * V_norm2;
  der(L_act) = (actuation_strain_max * V_norm2 * L0 - L_act) / tau_visco;

  // ----- Leakage and thermal state -----
  I_leak = V / R_leak;
  P_leak = V * I_leak;
  P_visco = c_ax * dLdt * dLdt;
  der(T) = (P_leak + P_visco - G_th*(T - T_amb)) / C_th;

  // ----- Membrane forces on tip -----
  F_axial = k_eff*(L - L_rest) + c_ax*dLdt;
  Fx_mem = -F_axial * (x / L_safe);
  Fy_mem = -F_axial * (y / L_safe);
  Fy_bend = -k_bend*y - c_bend*vy;
  Fx_damp = -c_tip*vx;
  Fy_damp = -c_tip*vy;

  // ----- Obstacle collision -----
  dist_x = x - obs_x;
  dist_y = y - obs_y;
  dist2 = dist_x*dist_x + dist_y*dist_y;
  d_safe = max(sqrt(dist2), 1e-6);
  clearance = d_safe - obs_r;
  penetration = obs_r - d_safe;
  pen_rate = -(dist_x*vx + dist_y*vy) / d_safe;
  cnx = dist_x / d_safe;
  cny = dist_y / d_safe;
  ctx = -cny;
  cty = cnx;
  v_tan = vx*ctx + vy*cty;
  in_contact = penetration > 0.0;
  F_contact_n_raw = if in_contact then (k_contact*penetration + c_contact*pen_rate) else 0.0;
  F_contact_n = max(F_contact_n_raw, 0.0);
  F_contact_t = -mu * F_contact_n * tanh(v_tan / v_small);
  Fx_c = F_contact_n*cnx + F_contact_t*ctx;
  Fy_c = F_contact_n*cny + F_contact_t*cty;
  der(F_contact_filt) = (F_contact_n - F_contact_filt) / 0.02;
  der(F_contact_imp) = F_contact_n;

  // ----- Disturbance (middle third of 10 s) -----
  disturbance_active = (time >= t_dist_start) and (time <= t_dist_end);
  F_dist_y = if disturbance_active then F_dist else 0.0;

  // ----- Tip dynamics -----
  Fx_total = Fx_mem + Fx_c + Fx_damp;
  Fy_total = Fy_mem + Fy_bend + Fy_c + Fy_damp + F_dist_y;
  der(x) = vx;
  der(y) = vy;
  der(vx) = Fx_total / m_tip;
  der(vy) = Fy_total / m_tip;

  // ----- Contact-aware shape control with bounded stiffness scheduling -----
  V_cmd_raw = Kp_v * (target_x - x);
  V_cmd_contact = if in_contact then V_cmd_raw * 0.45 else V_cmd_raw;
  V_cmd_stiff = if (abs(y) > y_stiffen_thresh) then max(V_cmd_contact, V_stiffen) else V_cmd_contact;
  V_cmd_hold = if (target_x - x) < err_hold_band then max(V_cmd_stiff, V_hold) else V_cmd_stiff;
  V_cmd_clamped = min(max(V_cmd_hold, 0.0), V_max);
  V_cmd = V_cmd_clamped;
  dV_cmd = V_cmd - V;
  der(V) = max(-dVdt_max, min(dVdt_max, dV_cmd));

  // ----- Tracking error -----
  tip_error = sqrt((x - target_x)*(x - target_x) + (y - target_y)*(y - target_y));

  // ----- Bound assertions -----
  assert(V <= V_max + 1e-3, "Actuator voltage bound violated");
  assert(abs(strain) <= bound_deformation, "Section deformation bound violated");
  assert(F_contact_n <= bound_contact_force, "Contact-force bound violated");
  assert(T <= bound_temperature, "Temperature bound violated");
  assert(clearance >= bound_clearance_min, "Obstacle-clearance bound violated");
  assert(time < t_error_check or tip_error <= bound_tip_error,
         "Primary tracking error bound violated after 6.5 s");

  annotation (
    Documentation(info = "ElectroSoftAvoidB: lumped soft-robotic DEA membrane "
      "navigating around a fixed cylinder with contact-aware, stiffness-scheduled "
      "HV control. Disturbance applied during the middle third of the 10 s run. "
      "Unstated material/geometry facts are explicitly labeled as assumptions."),
    experiment(StartTime = 0.0, StopTime = 10.0, Tolerance = 1e-6, Interval = 0.01));
end ElectroSoftAvoidB;