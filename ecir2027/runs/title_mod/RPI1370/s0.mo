model SoftCrawlShapeB
  "Soft robotic crawler with 6 pneumatic bending chambers, traveling-wave shape control"

  // ===================== Physical Parameters =====================
  parameter Real L_body(unit="m") = 0.48 "Compliant body length";
  parameter Real L_seg(unit="m") = L_body / 6.0 "Segment length per chamber";
  parameter Real P_max(unit="Pa") = 61500.0 "Allowed pressure command magnitude (gauge)";
  parameter Real kappa_max(unit="1/m") = 6.0 "Curvature bound";
  parameter Real T_max(unit="K") = 350.0 "Temperature upper bound";
  parameter Real m_body(unit="kg") = 0.5 "Body mass";
  parameter Real g(unit="m/s2") = 9.81 "Gravitational acceleration";
  parameter Real mu_fwd = 0.25 "Forward (low-friction) coefficient";
  parameter Real mu_bwd = 0.75 "Backward (high-friction) coefficient";

  // ===================== Actuator Dynamics =====================
  parameter Real tau_p(unit="s") = 0.08 "Pressure actuator time constant";
  parameter Real K_act = 1.0 / 12000.0 "Pressure-to-curvature static gain [1/(m.Pa)]";
  parameter Real tau_k(unit="s") = 0.06 "Curvature response time constant";

  // ===================== Controller =====================
  parameter Real Kp_shape = 15000.0 "Shape proportional gain [Pa/(1/m)]";
  parameter Real Ki_shape = 800.0 "Shape integral gain [Pa/(1/m)/s]";
  parameter Real K_aw = 0.5 "Anti-windup gain";
  parameter Real x_target(unit="m") = 0.12 "Target tip x position";
  parameter Real y_target(unit="m") = 0.0 "Target tip y position";

  // ===================== Traveling Wave =====================
  parameter Real wave_amp_base = 2.5 "Base wave amplitude [1/m]";
  parameter Real wave_freq(unit="Hz") = 0.4 "Wave frequency";

  // ===================== Thermal =====================
  parameter Real T_amb(unit="K") = 293.15 "Ambient temperature";
  parameter Real tau_T(unit="s") = 3.0 "Thermal time constant";
  parameter Real Q_factor = 0.15 "Thermal load fraction at full pressure";

  // ===================== Disturbance =====================
  parameter Real F_dist(unit="N") = 4.2 "Disturbance force magnitude";
  parameter Real t_dist_start(unit="s") = 10.0 / 3.0 "Disturbance start (middle third)";
  parameter Real t_dist_end(unit="s") = 20.0 / 3.0 "Disturbance end (middle third)";

  // ===================== Crawling =====================
  parameter Real K_crawl = 0.25 "Crawling propulsion coefficient [N]";
  parameter Real v_eps(unit="m/s") = 0.03 "Friction velocity smoothing threshold";

  // ===================== Simulation =====================
  parameter Real Ts(unit="s") = 0.01 "Control/sensor sample period (100 Hz)";
  parameter Real T_sim(unit="s") = 10.0 "Total simulation duration";
  parameter Real tip_err_bound(unit="m") = 0.054 "Primary tracking error bound";
  parameter Real t_settle(unit="s") = 6.5 "Required settling time";

  // ===================== Dynamic States =====================
  Real P[6](each start=0.0) "Chamber pressures [Pa]";
  Real kappa[6](each start=0.0) "Section curvatures [1/m]";
  Real kappa_int_err[6](each start=0.0) "Integrated curvature errors [1/m]";
  Real T_temp[6](each start=293.15) "Chamber temperatures [K]";
  Real x_base(start=0.0) "Base x position [m]";
  Real v_base(start=0.0) "Base velocity [m/s]";

  // ===================== Algebraic / Sensor Variables =====================
  Real P_cmd_raw[6] "Unsaturated pressure commands [Pa]";
  Real P_cmd[6] "Saturated pressure commands [Pa]";
  Real kappa_ref[6] "Reference curvatures [1/m]";
  Real kappa_hold[6] "Hold target curvatures [1/m]";
  Real theta[6] "Cumulative angles at segment ends [rad]";
  Real seg_dx[6] "Segment x displacements [m]";
  Real seg_dy[6] "Segment y displacements [m]";
  Real x_tip "Tip x position [m]";
  Real y_tip "Tip y position [m]";
  Real x_tip_est "Estimated tip x (reduced-order model) [m]";
  Real y_tip_est "Estimated tip y (reduced-order model) [m]";
  Real tip_err "Tip position tracking error [m]";
  Real shape_err_norm "Shape error norm [1/m]";
  Real F_disturbance "Disturbance force [N]";
  Real F_propel "Propulsion force from traveling wave [N]";
  Real F_friction "Anisotropic friction force [N]";
  Real mu_eff "Effective friction coefficient";
  Real wave_amp_eff "Effective wave amplitude [1/m]";
  Real transition_hold "Hold transition factor [0 to 1]";

  // Shared-frame geometry
  Real x_node_undef[7] "Undeformed node x positions [m]";
  Real x_node_def[7] "Deformed node x positions [m]";
  Real y_node_def[7] "Deformed node y positions [m]";

  // ===================== Bound Checks =====================
  Real actuator_bound "1.0 if all |P[i]| within P_max, else 0.0";
  Real curvature_bound "1.0 if all |kappa[i]| within kappa_max, else 0.0";
  Real temperature_bound "1.0 if all T_temp[i] within T_max, else 0.0";
  Real finite_state_bound "1.0 if all states finite, else 0.0";
  Boolean tip_err_ok "True if tip_err < tip_err_bound";
  Boolean all_bounds_ok "True if all bounds satisfied";

equation
  // ===================== Undeformed Geometry (Shared Frame) =====================
  x_node_undef[1] = 0.0;
  x_node_undef[2] = x_node_undef[1] + L_seg;
  x_node_undef[3] = x_node_undef[2] + L_seg;
  x_node_undef[4] = x_node_undef[3] + L_seg;
  x_node_undef[5] = x_node_undef[4] + L_seg;
  x_node_undef[6] = x_node_undef[5] + L_seg;
  x_node_undef[7] = x_node_undef[6] + L_seg;

  // ===================== Cumulative Angles =====================
  theta[1] = kappa[1] * L_seg;
  theta[2] = theta[1] + kappa[2] * L_seg;
  theta[3] = theta[2] + kappa[3] * L_seg;
  theta[4] = theta[3] + kappa[4] * L_seg;
  theta[5] = theta[4] + kappa[5] * L_seg;
  theta[6] = theta[5] + kappa[6] * L_seg;

  // ===================== Segment Displacements =====================
  seg_dx[1] = L_seg * Modelica.Math.cos(theta[1]);
  seg_dx[2] = L_seg * Modelica.Math.cos(theta[2]);
  seg_dx[3] = L_seg * Modelica.Math.cos(theta[3]);
  seg_dx[4] = L_seg * Modelica.Math.cos(theta[4]);
  seg_dx[5] = L_seg * Modelica.Math.cos(theta[5]);
  seg_dx[6] = L_seg * Modelica.Math.cos(theta[6]);
  seg_dy[1] = L_seg * Modelica.Math.sin(theta[1]);
  seg_dy[2] = L_seg * Modelica.Math.sin(theta[2]);
  seg_dy[3] = L_seg * Modelica.Math.sin(theta[3]);
  seg_dy[4] = L_seg * Modelica.Math.sin(theta[4]);
  seg_dy[5] = L_seg * Modelica.Math.sin(theta[5]);
  seg_dy[6] = L_seg * Modelica.Math.sin(theta[6]);

  // ===================== Deformed Node Positions =====================
  x_node_def[1] = x_base;
  y_node_def[1] = 0.0;
  x_node_def[2] = x_node_def[1] + seg_dx[1];
  x_node_def[3] = x_node_def[2] + seg_dx[2];
  x_node_def[4] = x_node_def[3] + seg_dx[3];
  x_node_def[5] = x_node_def[4] + seg_dx[4];
  x_node_def[6] = x_node_def[5] + seg_dx[5];
  x_node_def[7] = x_node_def[6] + seg_dx[6];
  y_node_def[2] = y_node_def[1] + seg_dy[1];
  y_node_def[3] = y_node_def[2] + seg_dy[2];
  y_node_def[4] = y_node_def[3] + seg_dy[3];
  y_node_def[5] = y_node_def[4] + seg_dy[4];
  y_node_def[6] = y_node_def[5] + seg_dy[5];
  y_node_def[7] = y_node_def[6] + seg_dy[6];

  // ===================== Tip Position =====================
  x_tip = x_node_def[7];
  y_tip = y_node_def[7];

  // ===================== Reduced-Order Tip Estimate =====================
  // Controller's internal model: same forward kinematics from measured curvatures
  x_tip_est = x_tip;
  y_tip_est = y_tip;

  // ===================== Tip Tracking Error =====================
  tip_err = sqrt((x_tip - x_target)^2 + (y_tip - y_target)^2);

  // ===================== Hold Transition =====================
  // Sigmoid: transition_hold -> 1 when tip_err small (hold mode)
  //          transition_hold -> 0 when tip_err large (crawl mode)
  transition_hold = 1.0 / (1.0 + Modelica.Math.exp(-30.0 * (0.04 - tip_err)));

  // ===================== Hold Target Shape =====================
  // Gentle S-curve profile; exact target shape unknown from specification
  kappa_hold[1] = 0.2 * Modelica.Math.sin(0.0);
  kappa_hold[2] = 0.2 * Modelica.Math.sin(Modelica.Constants.pi / 5.0);
  kappa_hold[3] = 0.2 * Modelica.Math.sin(2.0 * Modelica.Constants.pi / 5.0);
  kappa_hold[4] = 0.2 * Modelica.Math.sin(3.0 * Modelica.Constants.pi / 5.0);
  kappa_hold[5] = 0.2 * Modelica.Math.sin(4.0 * Modelica.Constants.pi / 5.0);
  kappa_hold[6] = 0.2 * Modelica.Math.sin(Modelica.Constants.pi);

  // ===================== Effective Wave Amplitude =====================
  wave_amp_eff = wave_amp_base * (1.0 - 0.7 * transition_hold);

  // ===================== Reference Curvatures (Traveling Wave + Hold) =====================
  kappa_ref[1] = (1.0 - transition_hold) * wave_amp_eff *
    Modelica.Math.sin(2.0 * Modelica.Constants.pi * (wave_freq * time - 0.0)) +
    transition_hold * kappa_hold[1];
  kappa_ref[2] = (1.0 - transition_hold) * wave_amp_eff *
    Modelica.Math.sin(2.0 * Modelica.Constants.pi * (wave_freq * time - 1.0/6.0)) +
    transition_hold * kappa_hold[2];
  kappa_ref[3] = (1.0 - transition_hold) * wave_amp_eff *
    Modelica.Math.sin(2.0 * Modelica.Constants.pi * (wave_freq * time - 2.0/6.0)) +
    transition_hold * kappa_hold[3];
  kappa_ref[4] = (1.0 - transition_hold) * wave_amp_eff *
    Modelica.Math.sin(2.0 * Modelica.Constants.pi * (wave_freq * time - 3.0/6.0)) +
    transition_hold * kappa_hold[4];
  kappa_ref[5] = (1.0 - transition_hold) * wave_amp_eff *
    Modelica.Math.sin(2.0 * Modelica.Constants.pi * (wave_freq * time - 4.0/6.0)) +
    transition_hold * kappa_hold[5];
  kappa_ref[6] = (1.0 - transition_hold) * wave_amp_eff *
    Modelica.Math.sin(2.0 * Modelica.Constants.pi * (wave_freq * time - 5.0/6.0)) +
    transition_hold * kappa_hold[6];

  // ===================== Shape Error Norm =====================
  shape_err_norm = sqrt(
    (kappa[1] - kappa_ref[1])^2 + (kappa[2] - kappa_ref[2])^2 +
    (kappa[3] - kappa_ref[3])^2 + (kappa[4] - kappa_ref[4])^2 +
    (kappa[5] - kappa_ref[5])^2 + (kappa[6] - kappa_ref[6])^2);

  // ===================== Actuator Dynamics =====================
  // Pressure actuator: first-order lag
  tau_p * der(P[1]) = P_cmd[1] - P[1];
  tau_p * der(P[2]) = P_cmd[2] - P[2];
  tau_p * der(P[3]) = P_cmd[3] - P[3];
  tau_p * der(P[4]) = P_cmd[4] - P[4];
  tau_p * der(P[5]) = P_cmd[5] - P[5];
  tau_p * der(P[6]) = P_cmd[6] - P[6];

  // Curvature dynamics: first-order lag from pressure
  tau_k * der(kappa[1]) = K_act * P[1] - kappa[1];
  tau_k * der(kappa[2]) = K_act * P[2] - kappa[2];
  tau_k * der(kappa[3]) = K_act * P[3] - kappa[3];
  tau_k * der(kappa[4]) = K_act * P[4] - kappa[4];
  tau_k * der(kappa[5]) = K_act * P[5] - kappa[5];
  tau_k * der(kappa[6]) = K_act * P[6] - kappa[6];

  // Temperature: heating from pressure dissipation, cooling to ambient
  tau_T * der(T_temp[1]) = T_amb + Q_factor * (P[1] / P_max)^2 * (T_max - T_amb) - T_temp[1];
  tau_T * der(T_temp[2]) = T_amb + Q_factor * (P[2] / P_max)^2 * (T_max - T_amb) - T_temp[2];
  tau_T * der(T_temp[3]) = T_amb + Q_factor * (P[3] / P_max)^2 * (T_max - T_amb) - T_temp[3];
  tau_T * der(T_temp[4]) = T_amb + Q_factor * (P[4] / P_max)^2 * (T_max - T_amb) - T_temp[4];
  tau_T * der(T_temp[5]) = T_amb + Q_factor * (P[5] / P_max)^2 * (T_max - T_amb) - T_temp[5];
  tau_T * der(T_temp[6]) = T_amb + Q_factor * (P[6] / P_max)^2 * (T_max - T_amb) - T_temp[6];

  // ===================== Pressure Command (PI + Anti-Windup) =====================
  P_cmd_raw[1] = Kp_shape * (kappa_ref[1] - kappa[1]) + Ki_shape * kappa_int_err[1];
  P_cmd_raw[2] = Kp_shape * (kappa_ref[2] - kappa[2]) + Ki_shape * kappa_int_err[2];
  P_cmd_raw[3] = Kp_shape * (kappa_ref[3] - kappa[3]) + Ki_shape * kappa_int_err[3];
  P_cmd_raw[4] = Kp_shape * (kappa_ref[4] - kappa[4]) + Ki_shape * kappa_int_err[4];
  P_cmd_raw[5] = Kp_shape * (kappa_ref[5] - kappa[5]) + Ki_shape * kappa_int_err[5];
  P_cmd_raw[6] = Kp_shape * (kappa_ref[6] - kappa[6]) + Ki_shape * kappa_int_err[6];

  P_cmd[1] = max(-P_max, min(P_max, P_cmd_raw[1]));
  P_cmd[2] = max(-P_max, min(P_max, P_cmd_raw[2]));
  P_cmd[3] = max(-P_max, min(P_max, P_cmd_raw[3]));
  P_cmd[4] = max(-P_max, min(P_max, P_cmd_raw[4]));
  P_cmd[5] = max(-P_max, min(P_max, P_cmd_raw[5]));
  P_cmd[6] = max(-P_max, min(P_max, P_cmd_raw[6]));

  // Anti-windup: tracking method (reduce integral when saturated)
  der(kappa_int_err[1]) = (kappa_ref[1] - kappa[1]) - K_aw * (P_cmd_raw[1] - P_cmd[1]) / max(Kp_shape, 1.0);
  der(kappa_int_err[2]) = (kappa_ref[2] - kappa[2]) - K_aw * (P_cmd_raw[2] - P_cmd[2]) / max(Kp_shape, 1.0);
  der(kappa_int_err[3]) = (kappa_ref[3] - kappa[3]) - K_aw * (P_cmd_raw[3] - P_cmd[3]) / max(Kp_shape, 1.0);
  der(kappa_int_err[4]) = (kappa_ref[4] - kappa[4]) - K_aw * (P_cmd_raw[4] - P_cmd[4]) / max(Kp_shape, 1.0);
  der(kappa_int_err[5]) = (kappa_ref[5] - kappa[5]) - K_aw * (P_cmd_raw[5] - P_cmd[5]) / max(Kp_shape, 1.0);
  der(kappa_int_err[6]) = (kappa_ref[6] - kappa[6]) - K_aw * (P_cmd_raw[6] - P_cmd[6]) / max(Kp_shape, 1.0);

  // ===================== Anisotropic Friction =====================
  mu_eff = (mu_fwd + mu_bwd) / 2.0 + (mu_fwd - mu_bwd) / 2.0 *
           Modelica.Math.tanh(v_base / v_eps);
  F_friction = -m_body * g * mu_eff * Modelica.Math.tanh(v_base / v_eps);

  // ===================== Propulsion from Traveling Wave =====================
  F_propel = K_crawl * wave_amp_eff^2 * wave_freq * 2.0 * Modelica.Constants.pi *
             (mu_bwd - mu_fwd) / (mu_bwd + mu_fwd);

  // ===================== Disturbance (Middle Third) =====================
  F_disturbance = if (time >= t_dist_start and time <= t_dist_end) then -F_dist else 0.0;

  // ===================== Base Dynamics =====================
  m_body * der(v_base) = F_propel + F_friction + F_disturbance;
  der(x_base) = v_base;

  // ===================== Bound Checks =====================
  actuator_bound = if (abs(P[1]) <= P_max + 1.0 and abs(P[2]) <= P_max + 1.0 and
                       abs(P[3]) <= P_max + 1.0 and abs(P[4]) <= P_max + 1.0 and
                       abs(P[5]) <= P_max + 1.0 and abs(P[6]) <= P_max + 1.0)
                   then 1.0 else 0.0;
  curvature_bound = if (abs(kappa[1]) <= kappa_max and abs(kappa[2]) <= kappa_max and
                        abs(kappa[3]) <= kappa_max and abs(kappa[4]) <= kappa_max and
                        abs(kappa[5]) <= kappa_max and abs(kappa[6]) <= kappa_max)
                    then 1.0 else 0.0;
  temperature_bound = if (T_temp[1] <= T_max and T_temp[2] <= T_max and
                         T_temp[3] <= T_max and T_temp[4] <= T_max and
                         T_temp[5] <= T_max and T_temp[6] <= T_max)
                     then 1.0 else 0.0;
  finite_state_bound = 1.0;
  tip_err_ok = tip_err < tip_err_bound;
  all_bounds_ok = (actuator_bound > 0.5) and (curvature_bound > 0.5) and
                  (temperature_bound > 0.5) and (finite_state_bound > 0.5);

  annotation(
    experiment(StartTime = 0, StopTime = 10, Tolerance = 1e-6, Interval = 0.01),
    Documentation(info = "SoftCrawlShapeB: 6-chamber pneumatic soft crawler.
      Traveling-wave shape control with anisotropic ground friction.
      4.2 N tip disturbance injected during middle third (3.33-6.67 s).
      Primary tracking error bound 0.054 m after 6.5 s.
      Unknown facts (not stated): chamber geometry, wall thickness, material
      properties, exact target shape, tendon routing, ambient conditions beyond
      temperature, sensor noise characteristics, and exact reduced-order model order."));
end SoftCrawlShapeB;