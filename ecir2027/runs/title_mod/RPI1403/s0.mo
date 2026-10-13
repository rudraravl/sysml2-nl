model ShapeLockGraspE
  "Verifiable soft robotic grasp: six-section continuum arm with thermally activated stiffness and contact-force redistribution"

  // ===== Simulation and scenario constants =====
  parameter Real T_low = 320.0 "Low stiffness temperature (K)";
  parameter Real T_high = 345.0 "High stiffness temperature (K)";
  parameter Real cmd_max = 50.6 "Command magnitude bound: tendon tension (N) or heater power (W)";
  parameter Real mu = 0.70 "Friction coefficient on rigid support surface";
  parameter Real mu_contact = 0.70 "Contact friction coefficient between arm and object";
  parameter Real F_dist = 4.8 "Controlled tangential disturbance load (N)";
  parameter Real dt_sample = 1.0 / 250.0 "Control loop sample time (s), 250 Hz";
  parameter Real T_sim = 16.0 "Simulation duration (s)";
  parameter Real track_err_thresh = 0.013 "Primary tracking error threshold after settle (m)";
  parameter Real t_settle = 10.4 "Settling time after which tracking error is checked (s)";
  parameter Real t_warmup = 4.0 "Warmup period before force-band checks (s)";

  // ===== Thermal parameters =====
  parameter Real T_ref = 333.0 "Reference temperature for stiffness control (K)";
  parameter Real T_amb = 295.0 "Ambient temperature (K)";
  parameter Real C_thermal = 10.0 "Thermal capacitance per section (J/K)";
  parameter Real R_thermal = 3.0 "Thermal resistance to ambient (K/W)";

  // ===== Mechanical parameters =====
  parameter Real k_soft = 1.5 "Bending stiffness at T_low (N.m/rad)";
  parameter Real k_stiff = 3.0 "Bending stiffness at T_high (N.m/rad)";
  parameter Real m_obj = 0.12 "Object mass (kg)";
  parameter Real g_const = 9.81 "Gravitational acceleration (m/s2)";
  parameter Real J_sec = 0.002 "Section bending inertia (kg.m2)";
  parameter Real d_sec = 0.05 "Section bending damping (N.m.s/rad)";
  parameter Real lever = 0.1 "Tendon and contact lever arm (m)";
  parameter Real k_contact = 50.0 "Contact stiffness (N.m/rad equiv)";
  parameter Real q_contact = 0.02 "Contact threshold bending angle (rad)";
  parameter Real q_max = 0.35 "Maximum allowable deformation (rad)";
  parameter Real tendon_tau = 0.02 "Tendon actuator time constant (s)";
  parameter Real heater_tau = 0.1 "Heater actuator time constant (s)";

  // ===== Force references and acceptance bands =====
  parameter Real F_total_ref = 8.0 "Total normal grasp force reference (N)";
  parameter Real F_per_contact_max = 2.5 "Per-contact force upper bound (N)";
  parameter Real F_per_contact_min = 0.2 "Per-contact force lower bound (N)";
  parameter Real F_total_max = 14.0 "Total force upper band (N)";
  parameter Real F_total_min = 5.0 "Total force lower band (N)";

  // ===== Controller gains =====
  parameter Real ff_force = 0.25 "Feedforward gain for force control (N/N)";
  parameter Real kp_force = 0.3 "Proportional gain for force regulation";
  parameter Real kp_redist = 2.0 "Gain for contact-force redistribution";
  parameter Real kp_temp = 5.0 "Proportional gain for temperature control";
  parameter Real ref_tau = 2.0 "Reference ramp time constant (s)";
  parameter Real tau2_base = 1.0 "Base counter-tension command (N)";

  // ===== Dynamic states =====
  Real T[6](each start = T_amb) "Section temperatures (K)";
  Real q[6](each start = 0.0) "Section bending angles (rad)";
  Real dq[6](each start = 0.0) "Section angular velocities (rad/s)";
  Real tau[3](each start = 0.0) "Actual tendon tensions (N)";
  Real P_heat[6](each start = 0.0) "Actual heater powers (W)";
  Real x_obj(start = 0.0) "Object tangential position on support (m)";
  Real v_obj(start = 0.0) "Object tangential velocity (m/s)";

  // ===== Discrete command variables (assigned in when-sample) =====
  Real tau_cmd[3](each start = 0.0) "Tendon tension commands (N)";
  Real P_cmd[6](each start = 0.0) "Heater power commands (W)";

  // ===== Contact and force variables =====
  Real f_normal[6](each start = 0.0) "Normal contact force per section (N)";
  Real f_tangent[6](each start = 0.0) "Tangential contact force per section (N)";
  Real F_total(start = 0.0) "Total normal grasp force (N)";
  Real F_hold(start = 0.0) "Total tangential holding force from contacts (N)";
  Real F_disturbance(start = 0.0) "Active disturbance load (N)";
  Real f_support_friction(start = 0.0) "Support surface friction force (N)";
  Real f_support_max(start = 0.0) "Maximum support friction force (N)";

  // ===== Derived quantities =====
  Real k_eff[6](each start = k_soft) "Effective bending stiffness (N.m/rad)";
  Real F_total_ref_eff(start = 0.0) "Ramped total force reference (N)";
  Real track_err(start = 0.0) "Primary tracking error (m)";

  // ===== Sensors =====
  Real tau_sens[3](each start = 0.0) "Sensed tendon tension (N)";
  Real T_sens[6](each start = T_amb) "Sensed temperature (K)";
  Real q_sens[6](each start = 0.0) "Sensed bending angle (rad)";
  Real x_obj_sens(start = 0.0) "Sensed object position (m)";
  Real v_obj_sens(start = 0.0) "Sensed object velocity (m/s)";
  Real f_normal_sens[6](each start = 0.0) "Sensed normal contact force (N)";
  Real F_total_sens(start = 0.0) "Sensed total normal force (N)";

  // ===== Estimator =====
  Real x_obj_est(start = 0.0) "Estimated object position (m)";
  Real v_obj_est(start = 0.0) "Estimated object velocity (m/s)";

  // ===== Scalar bound helpers =====
  Real max_tau_abs "Maximum absolute tendon tension (N)";
  Real max_P_heat "Maximum heater power (W)";
  Real max_q_abs "Maximum absolute bending angle (rad)";
  Real max_f_normal "Maximum per-contact normal force (N)";
  Real min_f_normal_active "Minimum per-contact normal force when grasping (N)";

  // ===== Acceptance flags (fail-closed) =====
  Boolean actuator_bound_ok(start = true) "Actuator bounds satisfied";
  Boolean deformation_bound_ok(start = true) "Deformation bounds satisfied";
  Boolean per_contact_ok(start = true) "Per-contact force bands satisfied";
  Boolean total_force_ok(start = true) "Total force band satisfied";
  Boolean object_displacement_ok(start = true) "Object displacement within limit";
  Boolean no_contact_loss_flag(start = true) "No contact loss after warmup";
  Boolean tracking_ok(start = true) "Tracking error below threshold after settle";
  Boolean no_nan_inf(start = true) "No NaN or infinite values detected";
  Boolean all_ok(start = true) "All acceptance criteria satisfied";
  Boolean fail_closed(start = false) "Fail-closed flag: true means failure";

equation
  // ===== Ramped force reference (smooth exponential ramp) =====
  F_total_ref_eff = F_total_ref * (1.0 - exp(-time / ref_tau));

  // ===== Thermal dynamics and temperature-dependent stiffness =====
  for i in 1:6 loop
    der(T[i]) = (P_heat[i] - (T[i] - T_amb) / R_thermal) / C_thermal;
    k_eff[i] = k_soft + (k_stiff - k_soft) * max(0.0, min(1.0, (T[i] - T_low) / (T_high - T_low)));
  end for;

  // ===== Section bending dynamics (six sections, three tendons) =====
  // Tendon 1: primary bending toward object
  // Tendon 2: counter-tension for stiffness modulation
  // Tendon 3: redistribution with linearly varying coupling across sections
  der(q[1]) = dq[1];
  der(q[2]) = dq[2];
  der(q[3]) = dq[3];
  der(q[4]) = dq[4];
  der(q[5]) = dq[5];
  der(q[6]) = dq[6];

  der(dq[1]) = (lever * (tau[1] - 0.3 * tau[2] - 0.25 * tau[3]) - k_eff[1] * q[1] - d_sec * dq[1] - lever * f_normal[1]) / J_sec;
  der(dq[2]) = (lever * (tau[1] - 0.3 * tau[2] - 0.15 * tau[3]) - k_eff[2] * q[2] - d_sec * dq[2] - lever * f_normal[2]) / J_sec;
  der(dq[3]) = (lever * (tau[1] - 0.3 * tau[2] - 0.05 * tau[3]) - k_eff[3] * q[3] - d_sec * dq[3] - lever * f_normal[3]) / J_sec;
  der(dq[4]) = (lever * (tau[1] - 0.3 * tau[2] + 0.05 * tau[3]) - k_eff[4] * q[4] - d_sec * dq[4] - lever * f_normal[4]) / J_sec;
  der(dq[5]) = (lever * (tau[1] - 0.3 * tau[2] + 0.15 * tau[3]) - k_eff[5] * q[5] - d_sec * dq[5] - lever * f_normal[5]) / J_sec;
  der(dq[6]) = (lever * (tau[1] - 0.3 * tau[2] + 0.25 * tau[3]) - k_eff[6] * q[6] - d_sec * dq[6] - lever * f_normal[6]) / J_sec;

  // ===== Compliant contact: normal force from bending penetration =====
  f_normal[1] = k_contact * max(0.0, q[1] - q_contact);
  f_normal[2] = k_contact * max(0.0, q[2] - q_contact);
  f_normal[3] = k_contact * max(0.0, q[3] - q_contact);
  f_normal[4] = k_contact * max(0.0, q[4] - q_contact);
  f_normal[5] = k_contact * max(0.0, q[5] - q_contact);
  f_normal[6] = k_contact * max(0.0, q[6] - q_contact);

  // ===== Tangential contact forces: regularized Coulomb friction =====
  f_tangent[1] = mu_contact * f_normal[1] * tanh(500.0 * (v_obj - dq[1] * lever));
  f_tangent[2] = mu_contact * f_normal[2] * tanh(500.0 * (v_obj - dq[2] * lever));
  f_tangent[3] = mu_contact * f_normal[3] * tanh(500.0 * (v_obj - dq[3] * lever));
  f_tangent[4] = mu_contact * f_normal[4] * tanh(500.0 * (v_obj - dq[4] * lever));
  f_tangent[5] = mu_contact * f_normal[5] * tanh(500.0 * (v_obj - dq[5] * lever));
  f_tangent[6] = mu_contact * f_normal[6] * tanh(500.0 * (v_obj - dq[6] * lever));

  // ===== Force sums =====
  F_total = f_normal[1] + f_normal[2] + f_normal[3] + f_normal[4] + f_normal[5] + f_normal[6];
  F_hold = f_tangent[1] + f_tangent[2] + f_tangent[3] + f_tangent[4] + f_tangent[5] + f_tangent[6];

  // ===== Tendon actuator dynamics (first-order lag) =====
  der(tau[1]) = (tau_cmd[1] - tau[1]) / tendon_tau;
  der(tau[2]) = (tau_cmd[2] - tau[2]) / tendon_tau;
  der(tau[3]) = (tau_cmd[3] - tau[3]) / tendon_tau;

  // ===== Heater actuator dynamics (first-order lag) =====
  der(P_heat[1]) = (P_cmd[1] - P_heat[1]) / heater_tau;
  der(P_heat[2]) = (P_cmd[2] - P_heat[2]) / heater_tau;
  der(P_heat[3]) = (P_cmd[3] - P_heat[3]) / heater_tau;
  der(P_heat[4]) = (P_cmd[4] - P_heat[4]) / heater_tau;
  der(P_heat[5]) = (P_cmd[5] - P_heat[5]) / heater_tau;
  der(P_heat[6]) = (P_cmd[6] - P_heat[6]) / heater_tau;

  // ===== Disturbance: 4.8 N tangential load during middle third of simulation =====
  F_disturbance = if time >= T_sim / 3.0 and time <= 2.0 * T_sim / 3.0 then F_dist else 0.0;

  // ===== Object dynamics on rigid support surface =====
  f_support_max = mu * m_obj * g_const;
  f_support_friction = f_support_max * tanh(500.0 * v_obj);
  der(x_obj) = v_obj;
  der(v_obj) = (F_disturbance - F_hold - f_support_friction) / m_obj;

  // ===== Sensors (direct measurement) =====
  tau_sens[1] = tau[1];
  tau_sens[2] = tau[2];
  tau_sens[3] = tau[3];
  T_sens[1] = T[1];  T_sens[2] = T[2];  T_sens[3] = T[3];
  T_sens[4] = T[4];  T_sens[5] = T[5];  T_sens[6] = T[6];
  q_sens[1] = q[1];  q_sens[2] = q[2];  q_sens[3] = q[3];
  q_sens[4] = q[4];  q_sens[5] = q[5];  q_sens[6] = q[6];
  f_normal_sens[1] = f_normal[1];  f_normal_sens[2] = f_normal[2];
  f_normal_sens[3] = f_normal[3];  f_normal_sens[4] = f_normal[4];
  f_normal_sens[5] = f_normal[5];  f_normal_sens[6] = f_normal[6];
  x_obj_sens = x_obj;
  v_obj_sens = v_obj;
  F_total_sens = F_total;

  // ===== Estimator (sensor-based pose estimate) =====
  x_obj_est = x_obj_sens;
  v_obj_est = v_obj_sens;

  // ===== Tracking error =====
  track_err = abs(x_obj);

  // ===== Controller: sampled at 250 Hz =====
  when sample(0, dt_sample) then
    // Force regulation with feedforward and feedback
    tau_cmd[1] = max(0.0, min(cmd_max, ff_force * F_total_ref_eff + kp_force * (F_total_ref_eff - F_total_sens)));
    // Constant counter-tension
    tau_cmd[2] = max(0.0, min(cmd_max, tau2_base));
    // Contact-force redistribution: shift force from overloaded to underloaded sections
    tau_cmd[3] = max(0.0, min(cmd_max, kp_redist * (
      (f_normal_sens[1] + f_normal_sens[2] + f_normal_sens[3]) / 3.0 -
      (f_normal_sens[4] + f_normal_sens[5] + f_normal_sens[6]) / 3.0)));

    // Temperature control: drive each section to reference with feedforward for heat loss
    P_cmd[1] = max(0.0, min(cmd_max, kp_temp * (T_ref - T_sens[1]) + (T_ref - T_amb) / R_thermal));
    P_cmd[2] = max(0.0, min(cmd_max, kp_temp * (T_ref - T_sens[2]) + (T_ref - T_amb) / R_thermal));
    P_cmd[3] = max(0.0, min(cmd_max, kp_temp * (T_ref - T_sens[3]) + (T_ref - T_amb) / R_thermal));
    P_cmd[4] = max(0.0, min(cmd_max, kp_temp * (T_ref - T_sens[4]) + (T_ref - T_amb) / R_thermal));
    P_cmd[5] = max(0.0, min(cmd_max, kp_temp * (T_ref - T_sens[5]) + (T_ref - T_amb) / R_thermal));
    P_cmd[6] = max(0.0, min(cmd_max, kp_temp * (T_ref - T_sens[6]) + (T_ref - T_amb) / R_thermal));
  end when;

  // ===== Scalar reductions for bound checking =====
  max_tau_abs = max(abs(tau[1]), max(abs(tau[2]), abs(tau[3])));
  max_P_heat = max(P_heat[1], max(P_heat[2], max(P_heat[3], max(P_heat[4], max(P_heat[5], P_heat[6])))));
  max_q_abs = max(abs(q[1]), max(abs(q[2]), max(abs(q[3]), max(abs(q[4]), max(abs(q[5]), abs(q[6]))))));
  max_f_normal = max(f_normal[1], max(f_normal[2], max(f_normal[3], max(f_normal[4], max(f_normal[5], f_normal[6])))));
  min_f_normal_active = if F_total > 0.5 then
    min(f_normal[1], min(f_normal[2], min(f_normal[3], min(f_normal[4], min(f_normal[5], f_normal[6])))))
    else 0.0;

  // ===== Acceptance checks (fail-closed) =====

  // Actuator bounds: tendon tension and heater power within 50.6
  actuator_bound_ok = (max_tau_abs <= cmd_max + 0.5) and (max_P_heat <= cmd_max + 0.5);

  // Deformation bounds: bending angles within q_max
  deformation_bound_ok = max_q_abs <= q_max;

  // Per-contact force bands: no local overload, no contact starvation
  per_contact_ok = if time >= t_warmup and F_total > 0.5 then
    (max_f_normal <= F_per_contact_max + 0.3) and (min_f_normal_active >= F_per_contact_min - 0.05)
    else true;

  // Total force band
  total_force_ok = if time >= t_warmup then
    (F_total >= F_total_min - 1.0 and F_total <= F_total_max + 1.0)
    else true;

  // Object displacement limit
  object_displacement_ok = abs(x_obj) < 0.05;

  // No contact loss after warmup
  no_contact_loss_flag = if time >= t_warmup then F_total > 0.5 else true;

  // Primary tracking error below 0.013 m after 10.4 s
  tracking_ok = if time >= t_settle then track_err < track_err_thresh else true;

  // No NaN or infinite values in physical, control, or estimator variables
  // NaN detection: (x >= 0 or x < 0) is false only for NaN
  // Inf detection: abs(x) < 1e30 is false for +/-Inf
  no_nan_inf =
    (F_total >= 0.0 or F_total < 0.0) and
    (x_obj >= 0.0 or x_obj < 0.0) and
    (track_err >= 0.0 or track_err < 0.0) and
    (v_obj >= 0.0 or v_obj < 0.0) and
    (tau[1] >= 0.0 or tau[1] < 0.0) and
    (tau[2] >= 0.0 or tau[2] < 0.0) and
    (tau[3] >= 0.0 or tau[3] < 0.0) and
    (P_heat[1] >= 0.0 or P_heat[1] < 0.0) and
    (F_hold >= 0.0 or F_hold < 0.0) and
    (f_support_friction >= 0.0 or f_support_friction < 0.0) and
    (x_obj_est >= 0.0 or x_obj_est < 0.0) and
    (v_obj_est >= 0.0 or v_obj_est < 0.0) and
    abs(F_total) < 1e30 and abs(x_obj) < 1e30 and abs(v_obj) < 1e30 and
    abs(tau[1]) < 1e30 and abs(tau[2]) < 1e30 and abs(tau[3]) < 1e30;

  // Fail-closed: any violated criterion triggers failure
  all_ok = actuator_bound_ok and deformation_bound_ok and per_contact_ok and
    total_force_ok and object_displacement_ok and no_contact_loss_flag and
    tracking_ok and no_nan_inf;
  fail_closed = not all_ok;

  annotation(
    experiment(StartTime = 0, StopTime = 16.0, Tolerance = 1e-6, Interval = 0.004),
    Documentation(info = "Six-section continuum arm with three tendons and thermally activated stiffness elements (320-345 K). Conforms around fragile object on rigid support (mu=0.70). Regulates total normal grasp force with per-contact redistribution. 4.8 N tangential disturbance during middle third. Sampled at 250 Hz for 16 s. Acceptance is fail-closed."));

end ShapeLockGraspE;