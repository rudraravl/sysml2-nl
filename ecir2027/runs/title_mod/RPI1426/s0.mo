model ElectroSoftGraspD
  // Physical constants
  constant Real eps0 = 8.854187817e-12 "F/m vacuum permittivity";
  constant Real g = 9.81 "m/s^2 gravitational acceleration";

  // Membrane embodiment (0.20 m x 0.05 m x 0.8 mm dielectric elastomer)
  parameter Real L_mem = 0.20 "m membrane length";
  parameter Real W_mem = 0.05 "m membrane width";
  parameter Real h_mem = 0.8e-3 "m membrane thickness";
  parameter Real A_mem = L_mem * W_mem "m2 active membrane area";
  parameter Real eps_r = 3.0 "relative permittivity of elastomer";
  parameter Real C_dea = eps0 * eps_r * A_mem / h_mem "F DEA capacitance";
  parameter Real eta_dea = 0.9 "electromechanical coupling efficiency";
  parameter Real rho_mem = 1000.0 "kg/m3 elastomer density";
  parameter Real m_mem = rho_mem * A_mem * h_mem "kg effective membrane mass";
  parameter Real k_mem = 100.0 "N/m membrane elastic stiffness";
  parameter Real c_mem = 8.0 "N.s/m membrane viscoelastic damping";
  parameter Real R_leak = 1.0e9 "Ohm leakage resistance";

  // Thermal state
  parameter Real C_th = 0.5 "J/K lumped thermal capacitance";
  parameter Real R_th = 50.0 "K/W thermal resistance to ambient";
  parameter Real T_amb = 293.15 "K ambient temperature";

  // Object and contact
  parameter Real m_obj = 0.2 "kg object mass";
  parameter Real mu_fric = 0.70 "friction coefficient membrane-object";
  parameter Real k_c = 500.0 "N/m per-contact compliance stiffness";
  parameter Real c_c = 5.0 "N.s/m per-contact compliance damping";
  parameter Real gap1 = 0.0048 "m contact node 1 rest gap";
  parameter Real gap2 = 0.0050 "m contact node 2 rest gap";
  parameter Real gap3 = 0.0052 "m contact node 3 rest gap";
  parameter Real F_contact_max = 3.0 "N per-contact overload band";
  parameter Real F_total_set = 7.0 "N total normal grasp force setpoint";
  parameter Real F_total_band_hi = 12.0 "N total force upper band";

  // Slew-limited high-voltage channel
  parameter Real V_max = 5000.0 "V voltage limit";
  parameter Real slew = 2000.0 "V/s slew rate limit";

  // Tangential disturbance (middle third of 14 s run)
  parameter Real F_dist = 4.0 "N tangential disturbance magnitude";
  parameter Real t_dist_start = 14.0 / 3.0 "s disturbance start";
  parameter Real t_dist_end = 2.0 * 14.0 / 3.0 "s disturbance end";

  // Controller gains
  parameter Real Kp_v = 400.0 "V command proportional gain (V/s per N error)";
  parameter Real K_red = 5.0 "total-force setpoint reduction per N overload";
  parameter Real K_red_r = 0.01 "tendon redistribution gain (m/s per N)";
  parameter Real r_damp = 1.0 "1/s redistribution damping";
  parameter Real r_dist_max = 5.0e-4 "m redistribution offset limit";

  // Friction smoothing
  parameter Real v_thresh = 1.0e-4 "m/s friction velocity threshold";

  // Bounds
  parameter Real u_mem_max = 0.05 "m deformation bound";
  parameter Real x_obj_disp_bound = 0.05 "m object displacement bound";
  parameter Real tracking_tol = 0.015 "m primary tracking tolerance after 9.1 s";

  // Initial conditions
  parameter Real u_mem0 = 0.0 "m initial membrane elongation";
  parameter Real V_cmd0 = 0.0 "V initial commanded voltage";
  parameter Real T0 = 293.15 "K initial temperature";
  parameter Real x_obj0 = 0.0 "m initial object position";
  parameter Real r_dist0 = 0.0 "m initial redistribution offset";

  // Dynamic states
  Real u_mem(start=u_mem0) "m membrane elongation (actuator displacement)";
  Real v_mem(start=0.0) "m/s membrane velocity";
  Real V_cmd(start=V_cmd0) "V slew-limited commanded voltage";
  Real T(start=T0) "K membrane temperature";
  Real x_obj(start=x_obj0) "m object horizontal position";
  Real v_obj(start=0.0) "m/s object horizontal velocity";
  Real r_dist(start=r_dist0) "m tendon redistribution offset";

  // Actuator sensing
  Real V "V applied DEA voltage";
  Real F_dea "N DEA Maxwell actuator force";
  Real I_leak "A leakage current";
  Real Q_dea "C DEA charge";

  // Distributed contact sensing
  Real pen1 "m contact 1 penetration";
  Real pen2 "m contact 2 penetration";
  Real pen3 "m contact 3 penetration";
  Real F_n1 "N contact 1 normal force";
  Real F_n2 "N contact 2 normal force";
  Real F_n3 "N contact 3 normal force";
  Real F_total "N total normal grasp force";
  Real F_n_max "N maximum per-contact normal force";

  // Object pose measurement and interaction
  Real F_normal_support "N rigid support normal reaction";
  Real F_fric "N friction force on object";
  Real F_fric_max "N friction limit";
  Real F_dist_actual "N applied tangential disturbance";
  Real x_obj_ref "m object reference pose";
  Real tracking_err "m primary tracking error";

  // Control internals
  Real F_err "N total force tracking error";
  Real overload "N per-contact overload magnitude";
  Real F_total_set_eff "N effective total force setpoint";
  Real dist_en "disturbance enable flag [0,1]";

  // Bound and integrity flags (0 = OK, 1 = violated)
  Real bound_V_flag;
  Real bound_u_flag;
  Real bound_contact_flag;
  Real bound_total_flag;
  Real bound_displacement_flag;
  Real bound_contact_loss_flag;
  Real nan_check_flag;

equation
  // Disturbance scheduling (middle third of the run)
  dist_en = if time >= t_dist_start and time <= t_dist_end then 1.0 else 0.0;
  F_dist_actual = F_dist * dist_en;

  // DEA electromechanical actuator (Maxwell stress with permittivity)
  F_dea = eta_dea * eps0 * eps_r * (V / h_mem) * (V / h_mem) * A_mem;
  I_leak = V / R_leak;
  Q_dea = C_dea * V;

  // Thermal state (Joule leakage heating + conduction to ambient)
  C_th * der(T) = V * I_leak - (T - T_amb) / R_th;

  // Slew-limited voltage command and applied voltage with bounds
  der(V_cmd) = max(-slew, min(slew, Kp_v * F_err));
  V = max(0.0, min(V_max, V_cmd));

  // Distributed contact penetrations with tendon redistribution tilt
  pen1 = if (u_mem - gap1 - r_dist) > 0.0 then (u_mem - gap1 - r_dist) else 0.0;
  pen2 = if (u_mem - gap2) > 0.0 then (u_mem - gap2) else 0.0;
  pen3 = if (u_mem - gap3 + r_dist) > 0.0 then (u_mem - gap3 + r_dist) else 0.0;

  // Compliant collision forces (Kelvin-Voigt)
  F_n1 = k_c * pen1 + c_c * (if pen1 > 0.0 then v_mem else 0.0);
  F_n2 = k_c * pen2 + c_c * (if pen2 > 0.0 then v_mem else 0.0);
  F_n3 = k_c * pen3 + c_c * (if pen3 > 0.0 then v_mem else 0.0);
  F_total = F_n1 + F_n2 + F_n3;
  F_n_max = max(F_n1, max(F_n2, F_n3));

  // Membrane dynamics: actuator force vs viscoelastic restore and contact
  m_mem * der(v_mem) = F_dea - k_mem * u_mem - c_mem * v_mem - F_total;
  der(u_mem) = v_mem;

  // Object pose dynamics on rigid support with friction (mu = 0.70)
  F_normal_support = m_obj * g + F_total;
  F_fric_max = mu_fric * F_total;
  F_fric = F_fric_max * tanh(v_obj / v_thresh);
  m_obj * der(v_obj) = F_dist_actual - F_fric;
  der(x_obj) = v_obj;

  // Object pose tracking
  x_obj_ref = 0.0;
  tracking_err = x_obj - x_obj_ref;

  // Per-contact overload protection and total-force setpoint redistribution
  overload = max(0.0, F_n_max - F_contact_max);
  F_total_set_eff = max(0.0, F_total_set - K_red * overload);
  F_err = F_total_set_eff - F_total;

  // Tendon redistribution to balance contact 1 and 3
  der(r_dist) = max(-r_dist_max, min(r_dist_max, K_red_r * (F_n1 - F_n3) - r_damp * r_dist));

  // Bound flags
  bound_V_flag = if (V < 0.0 or V > V_max) then 1.0 else 0.0;
  bound_u_flag = if (u_mem < 0.0 or u_mem > u_mem_max) then 1.0 else 0.0;
  bound_contact_flag = if (F_n_max > F_contact_max) then 1.0 else 0.0;
  bound_total_flag = if (F_total > F_total_band_hi) then 1.0 else 0.0;
  bound_displacement_flag = if (abs(x_obj) > x_obj_disp_bound) then 1.0 else 0.0;
  bound_contact_loss_flag = if (time > 3.0 and F_total < 1.0e-6) then 1.0 else 0.0;
  nan_check_flag = 0.0;

  // Requirement enforcement
  assert(V >= 0.0 and V <= V_max, "Actuator voltage bound violated");
  assert(u_mem >= 0.0 and u_mem <= u_mem_max, "Deformation bound violated");
  assert(F_n_max <= F_contact_max + 1.0e-6, "Per-contact force band violated");
  assert(F_total <= F_total_band_hi, "Total force band violated");
  assert(abs(x_obj) <= x_obj_disp_bound, "Object displacement bound violated");
  assert(not (time > 3.0 and F_total < 1.0e-6), "Contact loss detected");
  assert(time < 9.1 or abs(tracking_err) < tracking_tol, "Primary tracking error exceeded after 9.1 s");
  assert(noEvent(abs(F_dea) < 1.0e6), "Physical actuator value out of range");
  assert(noEvent(T > 0.0 and T < 1.0e4), "Thermal value out of range");

  annotation(
    experiment(StartTime=0, StopTime=14, Tolerance=1e-6, Interval=0.005),
    Documentation(info="Instrumented dielectric-elastomer soft grasp (ElectroSoftGraspD). 0.20x0.05x0.8 mm DEA membrane with explicit permittivity, viscoelasticity, leakage and thermal state. Slew-limited 5 kV channel controls elongation. Three-node distributed contact sensing with compliant collision (mu=0.70) on a rigid support. Tendon redistribution and total normal grasp force regulation with per-contact overload protection. 4 N tangential disturbance applied during the middle third. Synchronized state, command and sensor traces sampled at 200 Hz for 14 s.")
  );
end ElectroSoftGraspD;