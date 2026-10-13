model SoftCrawlShapeD
  "Instrumented soft crawling robot: 6-chamber pneumatic, 0.48 m body, traveling-wave crawl, shape hold, 6 N mid-third tip disturbance";

  // ---- Body geometry ----
  parameter Real L_body = 0.48 "Total compliant body length [m]";
  parameter Real L_seg = L_body / 6.0 "Per-segment length [m]";
  parameter Real m_total = 0.30 "Total body mass [kg]";
  parameter Real d_seg = 0.024 "Segment outer diameter [m]";

  // ---- Actuator limits ----
  parameter Real p_max = 75000.0 "Max chamber gauge pressure [Pa]";
  parameter Real k_pressure = 6.667e-5 "Pressure-to-curvature gain [1/(m.Pa)]";
  parameter Real tau_p = 0.04 "Chamber pressure time constant [s]";
  parameter Real K_pc = 5.0e5 "Curvature proportional feedback gain [Pa/(1/m)]";

  // ---- Load and gravity curvature (reduced-order) ----
  parameter Real k_load = 0.15 "Tip-load-to-curvature gain [1/(m.N)]";
  parameter Real k_grav = 0.02 "Gravity sag curvature scale [1/m]";
  parameter Real g = 9.81 "Gravitational acceleration [m/s^2]";
  parameter Real pi = 3.141592653589793;

  // ---- Anisotropic friction ----
  parameter Real mu_fwd = 0.05 "Forward (low) friction coefficient";
  parameter Real mu_bwd = 0.20 "Backward (high) friction coefficient";
  parameter Real v_eps = 0.01 "Friction smoothing velocity [m/s]";

  // ---- Thermal ----
  parameter Real T_env = 293.15 "Ambient temperature [K]";
  parameter Real h_conv = 4.0 "Convective heat-transfer coefficient [W/(m2.K)]";
  parameter Real A_surf = 0.045 "Body surface area [m2]";
  parameter Real C_thermal = 80.0 "Thermal capacity [J/K]";
  parameter Real R_pneu = 2.0e-10 "Pneumatic dissipation coefficient [W/Pa^2]";

  // ---- Disturbance schedule ----
  parameter Real F_dist = 6.0 "Tip disturbance load [N]";
  parameter Real t_dist_start = 14.0 / 3.0 "Disturbance start (middle third) [s]";
  parameter Real t_dist_end = 2.0 * 14.0 / 3.0 "Disturbance end (middle third) [s]";

  // ---- Control schedule ----
  parameter Real t_crawl_end = 7.0 "Crawl-to-hold transition time [s]";
  parameter Real t_trans = 0.15 "Smooth transition duration [s]";
  parameter Real kappa_hold = 3.0 "Hold target curvature [1/m]";
  parameter Real kappa_wave_amp = 2.0 "Traveling-wave curvature amplitude [1/m]";
  parameter Real kappa_wave_off = 2.0 "Traveling-wave curvature offset [1/m]";
  parameter Real wave_period = 3.0 "Traveling-wave period [s]";

  // ---- Bounds ----
  parameter Real dt_sample = 1.0 / 200.0 "Sample period (200 Hz) [s]";
  parameter Real t_settle = 9.1 "Tracking settling time [s]";
  parameter Real e_track_bound = 0.045 "Primary tracking error bound [m]";
  parameter Real e_shape_bound = 0.04 "Final shape-error bound [m]";
  parameter Real T_bound = 340.0 "Temperature upper bound [K]";
  parameter Real kappa_bound = 25.0 "Curvature magnitude bound [1/m]";

  // ---- Dynamic states ----
  Real p_act_1 "Actual chamber 1 pressure [Pa]";
  Real p_act_2 "Actual chamber 2 pressure [Pa]";
  Real p_act_3 "Actual chamber 3 pressure [Pa]";
  Real p_act_4 "Actual chamber 4 pressure [Pa]";
  Real p_act_5 "Actual chamber 5 pressure [Pa]";
  Real p_act_6 "Actual chamber 6 pressure [Pa]";
  Real x_base "Base (root) position in world frame [m]";
  Real v_base "Base velocity [m/s]";
  Real T_seg "Representative body temperature [K]";

  // ---- Command and reference ----
  Real kappa_ref_1 "Reference curvature segment 1 [1/m]";
  Real kappa_ref_2 "Reference curvature segment 2 [1/m]";
  Real kappa_ref_3 "Reference curvature segment 3 [1/m]";
  Real kappa_ref_4 "Reference curvature segment 4 [1/m]";
  Real kappa_ref_5 "Reference curvature segment 5 [1/m]";
  Real kappa_ref_6 "Reference curvature segment 6 [1/m]";
  Real p_cmd_1 "Commanded pressure chamber 1 [Pa]";
  Real p_cmd_2 "Commanded pressure chamber 2 [Pa]";
  Real p_cmd_3 "Commanded pressure chamber 3 [Pa]";
  Real p_cmd_4 "Commanded pressure chamber 4 [Pa]";
  Real p_cmd_5 "Commanded pressure chamber 5 [Pa]";
  Real p_cmd_6 "Commanded pressure chamber 6 [Pa]";
  Real p_sat_1 "Saturated pressure chamber 1 [Pa]";
  Real p_sat_2 "Saturated pressure chamber 2 [Pa]";
  Real p_sat_3 "Saturated pressure chamber 3 [Pa]";
  Real p_sat_4 "Saturated pressure chamber 4 [Pa]";
  Real p_sat_5 "Saturated pressure chamber 5 [Pa]";
  Real p_sat_6 "Saturated pressure chamber 6 [Pa]";

  // ---- Reduced-order deformation ----
  Real kappa_1 "Measured curvature segment 1 [1/m]";
  Real kappa_2 "Measured curvature segment 2 [1/m]";
  Real kappa_3 "Measured curvature segment 3 [1/m]";
  Real kappa_4 "Measured curvature segment 4 [1/m]";
  Real kappa_5 "Measured curvature segment 5 [1/m]";
  Real kappa_6 "Measured curvature segment 6 [1/m]";
  Real kappa_load_1 "Disturbance-induced curvature 1 [1/m]";
  Real kappa_load_2 "Disturbance-induced curvature 2 [1/m]";
  Real kappa_load_3 "Disturbance-induced curvature 3 [1/m]";
  Real kappa_load_4 "Disturbance-induced curvature 4 [1/m]";
  Real kappa_load_5 "Disturbance-induced curvature 5 [1/m]";
  Real kappa_load_6 "Disturbance-induced curvature 6 [1/m]";
  Real kappa_grav_1 "Gravity-induced curvature 1 [1/m]";
  Real kappa_grav_2 "Gravity-induced curvature 2 [1/m]";
  Real kappa_grav_3 "Gravity-induced curvature 3 [1/m]";
  Real kappa_grav_4 "Gravity-induced curvature 4 [1/m]";
  Real kappa_grav_5 "Gravity-induced curvature 5 [1/m]";
  Real kappa_grav_6 "Gravity-induced curvature 6 [1/m]";
  Real theta_1 "Cumulative orientation 1 [rad]";
  Real theta_2 "Cumulative orientation 2 [rad]";
  Real theta_3 "Cumulative orientation 3 [rad]";
  Real theta_4 "Cumulative orientation 4 [rad]";
  Real theta_5 "Cumulative orientation 5 [rad]";
  Real theta_6 "Cumulative orientation 6 [rad]";

  // ---- Tip pose (shared frame) ----
  Real x_tip_rel "Tip x relative to base [m]";
  Real y_tip_rel "Tip y relative to base [m]";
  Real x_ref_rel "Reference tip x relative to base [m]";
  Real y_ref_rel "Reference tip y relative to base [m]";
  Real x_tip "Tip x in world frame [m]";
  Real y_tip "Tip y in world frame [m]";
  Real x_tip_undeformed "Undeformed tip x in world frame [m]";
  Real y_tip_undeformed "Undeformed tip y in world frame [m]";

  // ---- Error metrics ----
  Real e_tip "Primary tip tracking error [m]";
  Real e_shape "Shape error metric [m]";

  // ---- Forces and scheduling ----
  Real F_dist_actual "Active disturbance force [N]";
  Real F_prop "Crawl propulsive force [N]";
  Real F_friction "Anisotropic friction force [N]";
  Real wave_phase "Traveling-wave phase [rad]";
  Real alpha_hold "Smooth hold-transition factor [0..1]";
  Real beta_dist "Smooth disturbance-activation factor [0..1]";
  Real tanh_v "Smooth sign of base velocity";
  Real mu_eff "Effective friction coefficient";

  // ---- Finite-state machine ----
  Real fsm_state "0=init, 1=crawl, 2=hold, 3=disturbed";

  // ---- Bound flags ----
  Boolean actuator_ok "Actuator pressure bounds satisfied";
  Boolean curvature_ok "Curvature bounds satisfied";
  Boolean temperature_ok "Temperature bounds satisfied";
  Boolean shape_ok "Final shape-error bound satisfied";
  Boolean tracking_ok "Primary tracking bound satisfied";
  Boolean fsm_ok "FSM state valid";
  Boolean no_nan_inf "No NaN or infinite values detected";

  // ---- 200 Hz synchronized sampled traces ----
  Real time_s(start = 0.0) "Sampled time stamp [s]";
  Real e_tip_s(start = 0.0) "Sampled tip tracking error [m]";
  Real e_shape_s(start = 0.0) "Sampled shape error [m]";
  Real T_s(start = 293.15) "Sampled temperature [K]";
  Real p1_s(start = 0.0) "Sampled pressure chamber 1 [Pa]";
  Real p6_s(start = 0.0) "Sampled pressure chamber 6 [Pa]";
  Real k1_s(start = 0.0) "Sampled curvature segment 1 [1/m]";
  Real k6_s(start = 0.0) "Sampled curvature segment 6 [1/m]";
  Real fsm_s(start = 0.0) "Sampled FSM state";

initial equation
  x_base = 0.0;
  v_base = 0.0;
  T_seg = T_env;
  p_act_1 = 0.0;
  p_act_2 = 0.0;
  p_act_3 = 0.0;
  p_act_4 = 0.0;
  p_act_5 = 0.0;
  p_act_6 = 0.0;

equation
  // ==================== Smooth scheduling signals ====================
  alpha_hold = 0.5 * (1.0 + tanh((time - t_crawl_end) / t_trans));
  beta_dist = 0.5 * (tanh((time - t_dist_start) / t_trans) - tanh((time - t_dist_end) / t_trans));
  wave_phase = 2.0 * pi * time / wave_period;

  // ==================== Reference curvature ====================
  kappa_ref_1 = (1.0 - alpha_hold) * (kappa_wave_off + kappa_wave_amp * sin(wave_phase)) + alpha_hold * kappa_hold;
  kappa_ref_2 = (1.0 - alpha_hold) * (kappa_wave_off + kappa_wave_amp * sin(wave_phase - pi / 3.0)) + alpha_hold * kappa_hold;
  kappa_ref_3 = (1.0 - alpha_hold) * (kappa_wave_off + kappa_wave_amp * sin(wave_phase - 2.0 * pi / 3.0)) + alpha_hold * kappa_hold;
  kappa_ref_4 = (1.0 - alpha_hold) * (kappa_wave_off + kappa_wave_amp * sin(wave_phase - pi)) + alpha_hold * kappa_hold;
  kappa_ref_5 = (1.0 - alpha_hold) * (kappa_wave_off + kappa_wave_amp * sin(wave_phase - 4.0 * pi / 3.0)) + alpha_hold * kappa_hold;
  kappa_ref_6 = (1.0 - alpha_hold) * (kappa_wave_off + kappa_wave_amp * sin(wave_phase - 5.0 * pi / 3.0)) + alpha_hold * kappa_hold;

  // ==================== Disturbance-induced curvature ====================
  F_dist_actual = F_dist * beta_dist;
  kappa_load_1 = k_load * F_dist_actual * 6.0 / 6.0;
  kappa_load_2 = k_load * F_dist_actual * 5.0 / 6.0;
  kappa_load_3 = k_load * F_dist_actual * 4.0 / 6.0;
  kappa_load_4 = k_load * F_dist_actual * 3.0 / 6.0;
  kappa_load_5 = k_load * F_dist_actual * 2.0 / 6.0;
  kappa_load_6 = k_load * F_dist_actual * 1.0 / 6.0;

  // ==================== Gravity sag curvature ====================
  kappa_grav_1 = k_grav * 6.0 / 6.0;
  kappa_grav_2 = k_grav * 5.0 / 6.0;
  kappa_grav_3 = k_grav * 4.0 / 6.0;
  kappa_grav_4 = k_grav * 3.0 / 6.0;
  kappa_grav_5 = k_grav * 2.0 / 6.0;
  kappa_grav_6 = k_grav * 1.0 / 6.0;

  // ==================== Pressure command (shape feedback) ====================
  p_cmd_1 = kappa_ref_1 / k_pressure + K_pc * (kappa_ref_1 - kappa_1);
  p_cmd_2 = kappa_ref_2 / k_pressure + K_pc * (kappa_ref_2 - kappa_2);
  p_cmd_3 = kappa_ref_3 / k_pressure + K_pc * (kappa_ref_3 - kappa_3);
  p_cmd_4 = kappa_ref_4 / k_pressure + K_pc * (kappa_ref_4 - kappa_4);
  p_cmd_5 = kappa_ref_5 / k_pressure + K_pc * (kappa_ref_5 - kappa_5);
  p_cmd_6 = kappa_ref_6 / k_pressure + K_pc * (kappa_ref_6 - kappa_6);

  // ==================== Pressure saturation (0..75 kPa) ====================
  p_sat_1 = max(0.0, min(p_max, p_cmd_1));
  p_sat_2 = max(0.0, min(p_max, p_cmd_2));
  p_sat_3 = max(0.0, min(p_max, p_cmd_3));
  p_sat_4 = max(0.0, min(p_max, p_cmd_4));
  p_sat_5 = max(0.0, min(p_max, p_cmd_5));
  p_sat_6 = max(0.0, min(p_max, p_cmd_6));

  // ==================== Pressure dynamics (first-order lag) ====================
  der(p_act_1) = (p_sat_1 - p_act_1) / tau_p;
  der(p_act_2) = (p_sat_2 - p_act_2) / tau_p;
  der(p_act_3) = (p_sat_3 - p_act_3) / tau_p;
  der(p_act_4) = (p_sat_4 - p_act_4) / tau_p;
  der(p_act_5) = (p_sat_5 - p_act_5) / tau_p;
  der(p_act_6) = (p_sat_6 - p_act_6) / tau_p;

  // ==================== Reduced-order curvature model ====================
  kappa_1 = k_pressure * p_act_1 + kappa_load_1 + kappa_grav_1;
  kappa_2 = k_pressure * p_act_2 + kappa_load_2 + kappa_grav_2;
  kappa_3 = k_pressure * p_act_3 + kappa_load_3 + kappa_grav_3;
  kappa_4 = k_pressure * p_act_4 + kappa_load_4 + kappa_grav_4;
  kappa_5 = k_pressure * p_act_5 + kappa_load_5 + kappa_grav_5;
  kappa_6 = k_pressure * p_act_6 + kappa_load_6 + kappa_grav_6;

  // ==================== Serial-chain kinematics ====================
  theta_1 = kappa_1 * L_seg;
  theta_2 = theta_1 + kappa_2 * L_seg;
  theta_3 = theta_2 + kappa_3 * L_seg;
  theta_4 = theta_3 + kappa_4 * L_seg;
  theta_5 = theta_4 + kappa_5 * L_seg;
  theta_6 = theta_5 + kappa_6 * L_seg;

  // Actuated tip in body frame
  x_tip_rel = L_seg * (cos(theta_1) + cos(theta_2) + cos(theta_3) + cos(theta_4) + cos(theta_5) + cos(theta_6));
  y_tip_rel = L_seg * (sin(theta_1) + sin(theta_2) + sin(theta_3) + sin(theta_4) + sin(theta_5) + sin(theta_6));

  // Reference (hold-shape) tip in body frame
  x_ref_rel = L_seg * (cos(kappa_hold * L_seg * 1.0) + cos(kappa_hold * L_seg * 2.0) + cos(kappa_hold * L_seg * 3.0)
                     + cos(kappa_hold * L_seg * 4.0) + cos(kappa_hold * L_seg * 5.0) + cos(kappa_hold * L_seg * 6.0));
  y_ref_rel = L_seg * (sin(kappa_hold * L_seg * 1.0) + sin(kappa_hold * L_seg * 2.0) + sin(kappa_hold * L_seg * 3.0)
                     + sin(kappa_hold * L_seg * 4.0) + sin(kappa_hold * L_seg * 5.0) + sin(kappa_hold * L_seg * 6.0));

  // World-frame tip (shared frame with undeformed geometry)
  x_tip = x_base + x_tip_rel;
  y_tip = y_tip_rel;
  x_tip_undeformed = x_base + L_body;
  y_tip_undeformed = 0.0;

  // ==================== Error metrics ====================
  e_tip = sqrt(max(1e-12, (x_tip_rel - x_ref_rel) * (x_tip_rel - x_ref_rel) + (y_tip_rel - y_ref_rel) * (y_tip_rel - y_ref_rel)));
  e_shape = sqrt(max(1e-12,
      (kappa_1 - kappa_ref_1) * (kappa_1 - kappa_ref_1)
    + (kappa_2 - kappa_ref_2) * (kappa_2 - kappa_ref_2)
    + (kappa_3 - kappa_ref_3) * (kappa_3 - kappa_ref_3)
    + (kappa_4 - kappa_ref_4) * (kappa_4 - kappa_ref_4)
    + (kappa_5 - kappa_ref_5) * (kappa_5 - kappa_ref_5)
    + (kappa_6 - kappa_ref_6) * (kappa_6 - kappa_ref_6))) * L_seg / 6.0;

  // ==================== Crawling dynamics ====================
  F_prop = (1.0 - alpha_hold) * 0.5 * sin(wave_phase);
  tanh_v = tanh(v_base / v_eps);
  mu_eff = mu_fwd * (1.0 + tanh_v) / 2.0 + mu_bwd * (1.0 - tanh_v) / 2.0;
  F_friction = -m_total * g * mu_eff * tanh_v;
  der(x_base) = v_base;
  der(v_base) = (F_prop + F_friction - F_dist_actual * 0.02) / m_total;

  // ==================== Thermal model ====================
  der(T_seg) = (R_pneu * (p_act_1 * p_act_1 + p_act_2 * p_act_2 + p_act_3 * p_act_3
              + p_act_4 * p_act_4 + p_act_5 * p_act_5 + p_act_6 * p_act_6)
              - h_conv * A_surf * (T_seg - T_env)) / C_thermal;

  // ==================== Finite-state machine ====================
  fsm_state = if time < 0.5 then 0.0 elseif time < t_crawl_end then 1.0 elseif time < t_dist_end then 3.0 else 2.0;

  // ==================== Bound checks ====================
  actuator_ok = (p_act_1 >= -1.0 and p_act_1 <= p_max + 1.0)
             and (p_act_2 >= -1.0 and p_act_2 <= p_max + 1.0)
             and (p_act_3 >= -1.0 and p_act_3 <= p_max + 1.0)
             and (p_act_4 >= -1.0 and p_act_4 <= p_max + 1.0)
             and (p_act_5 >= -1.0 and p_act_5 <= p_max + 1.0)
             and (p_act_6 >= -1.0 and p_act_6 <= p_max + 1.0);

  curvature_ok = (abs(kappa_1) <= kappa_bound) and (abs(kappa_2) <= kappa_bound)
              and (abs(kappa_3) <= kappa_bound) and (abs(kappa_4) <= kappa_bound)
              and (abs(kappa_5) <= kappa_bound) and (abs(kappa_6) <= kappa_bound);

  temperature_ok = (T_seg >= 250.0) and (T_seg <= T_bound);
  shape_ok = if time >= 13.5 then e_shape <= e_shape_bound else true;
  tracking_ok = if time >= t_settle then e_tip <= e_track_bound else true;
  fsm_ok = (fsm_state >= 0.0) and (fsm_state <= 3.0);

  no_nan_inf = ((e_tip >= 0.0) and (e_tip < 1e6))
            and ((e_shape >= 0.0) and (e_shape < 1e6))
            and ((T_seg > 0.0) and (T_seg < 1e4))
            and ((x_base > -1e3) and (x_base < 1e3))
            and ((v_base > -1e3) and (v_base < 1e3))
            and ((p_act_1 >= 0.0) and (p_act_1 < 1e8))
            and ((p_act_6 >= 0.0) and (p_act_6 < 1e8));

  // ==================== 200 Hz synchronized sampling ====================
  when sample(0, dt_sample) then
    time_s = time;
    e_tip_s = e_tip;
    e_shape_s = e_shape;
    T_s = T_seg;
    p1_s = p_act_1;
    p6_s = p_act_6;
    k1_s = kappa_1;
    k6_s = kappa_6;
    fsm_s = fsm_state;
  end when;

  annotation(
    experiment(StopTime = 14.0, Tolerance = 1e-6, Interval = 1.0 / 200.0),
    Documentation(info = "Soft pneumatic crawler: 6 chambers, 0.48 m, 75 kPa max. "
      "Traveling-wave crawl (0-7 s), hold target shape (7-14 s). "
      "6 N tip disturbance applied during middle third (4.67-9.33 s). "
      "Tracking error < 0.045 m after 9.1 s. 200 Hz sampling."));

end SoftCrawlShapeD;