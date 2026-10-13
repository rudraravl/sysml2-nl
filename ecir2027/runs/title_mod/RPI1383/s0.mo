model SoftCrawlCrawlC
  "Soft robotic crawler with phase-shifted pressure gait control, 6 chambers, anisotropic friction"

  // === Body parameters ===
  parameter Real L_body = 0.48 "Total compliant body length [m]";
  parameter Real L_chamber = L_body / 6.0 "Per-chamber length [m]";
  parameter Real m_body = 0.45 "Body mass [kg] — not specified, reasonable value";
  parameter Real g_acc = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real N_total = m_body * g_acc "Total normal force [N]";

  // === Actuator parameters ===
  parameter Real Pmax = 69000.0 "Maximum command pressure [Pa-gauge]";
  parameter Real tau_p = 0.06 "Pressure actuation time constant [s]";
  parameter Real k_bend = 6.5e-6 "Bending gain [rad/Pa]";
  parameter Real theta_max = 0.40 "Maximum bending/curvature angle [rad]";
  parameter Real tau_theta = 0.10 "Bending response time constant [s]";

  // === Anisotropic friction ===
  parameter Real mu_fwd = 0.10 "Forward sliding friction coefficient";
  parameter Real mu_bwd = 0.55 "Backward sliding friction coefficient";
  parameter Real v_eps = 0.004 "Friction smoothing velocity [m/s]";
  parameter Real delta_mu = mu_bwd - mu_fwd "Friction anisotropy";

  // === Gait parameters ===
  parameter Real T_gait = 2.4 "Gait cycle period [s]";
  parameter Real omega_g = 2.0 * Modelica.Constants.pi / T_gait "Gait angular frequency [rad/s]";
  parameter Real v_ref = 0.018 "Reference forward speed [m/s]";
  parameter Real phase_shift = 2.0 * Modelica.Constants.pi / 6.0 "Inter-chamber phase shift [rad]";

  // === Disturbance ===
  parameter Real F_drag_mag = 4.5 "Drag load magnitude [N]";
  parameter Real T_sim = 12.0 "Total simulation time [s]";
  parameter Real t_drag_start = T_sim / 3.0 "Drag onset time [s]";
  parameter Real t_drag_end = 2.0 * T_sim / 3.0 "Drag offset time [s]";
  parameter Real t_smooth = 0.15 "Smoothing time for drag transition [s]";

  // === Surface ridges ===
  parameter Real x_ridge1 = 0.10 "First ridge center position [m]";
  parameter Real x_ridge2 = 0.25 "Second ridge center position [m]";
  parameter Real w_ridge = 0.015 "Ridge half-width [m]";
  parameter Real F_ridge_max = 0.5 "Maximum ridge resistance force [N]";

  // === Sensing ===
  parameter Real strain_noise_amp = 0.003 "Strain sensing noise amplitude [rad]";
  parameter Real odom_scale_err = 0.01 "Odometry scale error fraction";

  // === Sampling ===
  parameter Real f_sample = 125.0 "Sampling frequency [Hz]";

  // === Dynamic states ===
  Real x(start = 0.0, fixed = true) "Body forward displacement [m]";
  Real v(start = 0.001, fixed = true) "Body forward velocity [m/s]";
  Real pAct_1(start = 0.0, fixed = true) "Chamber 1 actual pressure [Pa]";
  Real pAct_2(start = 0.0, fixed = true) "Chamber 2 actual pressure [Pa]";
  Real pAct_3(start = 0.0, fixed = true) "Chamber 3 actual pressure [Pa]";
  Real pAct_4(start = 0.0, fixed = true) "Chamber 4 actual pressure [Pa]";
  Real pAct_5(start = 0.0, fixed = true) "Chamber 5 actual pressure [Pa]";
  Real pAct_6(start = 0.0, fixed = true) "Chamber 6 actual pressure [Pa]";
  Real theta_1(start = 0.0, fixed = true) "Chamber 1 bending angle [rad]";
  Real theta_2(start = 0.0, fixed = true) "Chamber 2 bending angle [rad]";
  Real theta_3(start = 0.0, fixed = true) "Chamber 3 bending angle [rad]";
  Real theta_4(start = 0.0, fixed = true) "Chamber 4 bending angle [rad]";
  Real theta_5(start = 0.0, fixed = true) "Chamber 5 bending angle [rad]";
  Real theta_6(start = 0.0, fixed = true) "Chamber 6 bending angle [rad]";
  Real x_est(start = 0.0, fixed = true) "Odometric displacement estimate [m]";

  // === Command signals ===
  Real pCmd_1 "Chamber 1 commanded pressure [Pa]";
  Real pCmd_2 "Chamber 2 commanded pressure [Pa]";
  Real pCmd_3 "Chamber 3 commanded pressure [Pa]";
  Real pCmd_4 "Chamber 4 commanded pressure [Pa]";
  Real pCmd_5 "Chamber 5 commanded pressure [Pa]";
  Real pCmd_6 "Chamber 6 commanded pressure [Pa]";

  // === Bending targets and strain estimates ===
  Real theta_tgt_1 "Chamber 1 target bending [rad]";
  Real theta_tgt_2 "Chamber 2 target bending [rad]";
  Real theta_tgt_3 "Chamber 3 target bending [rad]";
  Real theta_tgt_4 "Chamber 4 target bending [rad]";
  Real theta_tgt_5 "Chamber 5 target bending [rad]";
  Real theta_tgt_6 "Chamber 6 target bending [rad]";
  Real theta_est_1 "Chamber 1 strain-sensed estimate [rad]";
  Real theta_est_2 "Chamber 2 strain-sensed estimate [rad]";
  Real theta_est_3 "Chamber 3 strain-sensed estimate [rad]";
  Real theta_est_4 "Chamber 4 strain-sensed estimate [rad]";
  Real theta_est_5 "Chamber 5 strain-sensed estimate [rad]";
  Real theta_est_6 "Chamber 6 strain-sensed estimate [rad]";

  // === Contact and friction ===
  Real vc_1, vc_2, vc_3, vc_4, vc_5, vc_6 "Local contact velocities [m/s]";
  Real N_1, N_2, N_3, N_4, N_5, N_6 "Per-chamber normal forces [N]";
  Real mu_1, mu_2, mu_3, mu_4, mu_5, mu_6 "Effective friction coefficients";
  Real Ff_1, Ff_2, Ff_3, Ff_4, Ff_5, Ff_6 "Per-chamber friction forces [N]";
  Real dtheta_1, dtheta_2, dtheta_3, dtheta_4, dtheta_5, dtheta_6 "Bending rates [rad/s]";

  // === Aggregate forces ===
  Real F_friction "Total friction/propulsion force [N]";
  Real F_drag "Drag disturbance force [N]";
  Real F_ridge "Ridge resistance force [N]";
  Real F_net "Net horizontal force [N]";

  // === Metrics ===
  Real x_ref "Reference position [m]";
  Real tracking_error "Cumulative tracking error [m]";
  Real avg_speed "Average forward speed [m/s]";
  Real progress "Net forward progress [m]";
  Real per_cycle_slip "Per-cycle slip [m]";
  Real cycles_real "Completed cycles (real-valued)";
  Real cycle_count "Integer cycle count (real-valued)";
  Real per_cycle_error "Per-cycle tracking error [m/cycle]";
  Real actuator_bound_violation "Pressure bound margin (negative = within bounds) [Pa]";
  Real curvature_bound_violation "Curvature bound margin (negative = within bounds) [rad]";

equation
  // === Pressure commands: traveling wave from tail (ch1) to head (ch6) ===
  pCmd_1 = Pmax / 2.0 * (1.0 + sin(omega_g * time));
  pCmd_2 = Pmax / 2.0 * (1.0 + sin(omega_g * time - phase_shift));
  pCmd_3 = Pmax / 2.0 * (1.0 + sin(omega_g * time - 2.0 * phase_shift));
  pCmd_4 = Pmax / 2.0 * (1.0 + sin(omega_g * time - 3.0 * phase_shift));
  pCmd_5 = Pmax / 2.0 * (1.0 + sin(omega_g * time - 4.0 * phase_shift));
  pCmd_6 = Pmax / 2.0 * (1.0 + sin(omega_g * time - 5.0 * phase_shift));

  // === Pressure dynamics (first-order lag) ===
  der(pAct_1) = (pCmd_1 - pAct_1) / tau_p;
  der(pAct_2) = (pCmd_2 - pAct_2) / tau_p;
  der(pAct_3) = (pCmd_3 - pAct_3) / tau_p;
  der(pAct_4) = (pCmd_4 - pAct_4) / tau_p;
  der(pAct_5) = (pCmd_5 - pAct_5) / tau_p;
  der(pAct_6) = (pCmd_6 - pAct_6) / tau_p;

  // === Bending targets (smooth tanh saturation ensures curvature bounds) ===
  theta_tgt_1 = theta_max * tanh(k_bend * pAct_1 / theta_max);
  theta_tgt_2 = theta_max * tanh(k_bend * pAct_2 / theta_max);
  theta_tgt_3 = theta_max * tanh(k_bend * pAct_3 / theta_max);
  theta_tgt_4 = theta_max * tanh(k_bend * pAct_4 / theta_max);
  theta_tgt_5 = theta_max * tanh(k_bend * pAct_5 / theta_max);
  theta_tgt_6 = theta_max * tanh(k_bend * pAct_6 / theta_max);

  // === Bending dynamics (first-order lag) ===
  der(theta_1) = (theta_tgt_1 - theta_1) / tau_theta;
  der(theta_2) = (theta_tgt_2 - theta_2) / tau_theta;
  der(theta_3) = (theta_tgt_3 - theta_3) / tau_theta;
  der(theta_4) = (theta_tgt_4 - theta_4) / tau_theta;
  der(theta_5) = (theta_tgt_5 - theta_5) / tau_theta;
  der(theta_6) = (theta_tgt_6 - theta_6) / tau_theta;

  // === Bending rates (explicit, avoids der() in algebraic equations) ===
  dtheta_1 = (theta_tgt_1 - theta_1) / tau_theta;
  dtheta_2 = (theta_tgt_2 - theta_2) / tau_theta;
  dtheta_3 = (theta_tgt_3 - theta_3) / tau_theta;
  dtheta_4 = (theta_tgt_4 - theta_4) / tau_theta;
  dtheta_5 = (theta_tgt_5 - theta_5) / tau_theta;
  dtheta_6 = (theta_tgt_6 - theta_6) / tau_theta;

  // === Strain sensing estimates (embedded curvature sensing with noise) ===
  theta_est_1 = theta_1 + strain_noise_amp * sin(2.0 * Modelica.Constants.pi * 12.0 * time + 0.3);
  theta_est_2 = theta_2 + strain_noise_amp * sin(2.0 * Modelica.Constants.pi * 12.0 * time + 0.9);
  theta_est_3 = theta_3 + strain_noise_amp * sin(2.0 * Modelica.Constants.pi * 12.0 * time + 1.5);
  theta_est_4 = theta_4 + strain_noise_amp * sin(2.0 * Modelica.Constants.pi * 12.0 * time + 2.1);
  theta_est_5 = theta_5 + strain_noise_amp * sin(2.0 * Modelica.Constants.pi * 12.0 * time + 2.7);
  theta_est_6 = theta_6 + strain_noise_amp * sin(2.0 * Modelica.Constants.pi * 12.0 * time + 3.3);

  // === Odometry (integrated velocity with small scale error) ===
  der(x_est) = v * (1.0 + odom_scale_err * sin(2.0 * Modelica.Constants.pi * 7.0 * time));

  // === Contact velocities ===
  // Bending (dtheta>0) drives contact backward; unbending drives it forward
  vc_1 = v - L_chamber * dtheta_1;
  vc_2 = v - L_chamber * dtheta_2;
  vc_3 = v - L_chamber * dtheta_3;
  vc_4 = v - L_chamber * dtheta_4;
  vc_5 = v - L_chamber * dtheta_5;
  vc_6 = v - L_chamber * dtheta_6;

  // === Normal forces (pressurized chambers reduce ground contact) ===
  N_1 = N_total / 6.0 * (1.0 - 0.35 * pAct_1 / Pmax);
  N_2 = N_total / 6.0 * (1.0 - 0.35 * pAct_2 / Pmax);
  N_3 = N_total / 6.0 * (1.0 - 0.35 * pAct_3 / Pmax);
  N_4 = N_total / 6.0 * (1.0 - 0.35 * pAct_4 / Pmax);
  N_5 = N_total / 6.0 * (1.0 - 0.35 * pAct_5 / Pmax);
  N_6 = N_total / 6.0 * (1.0 - 0.35 * pAct_6 / Pmax);

  // === Smooth directional friction ===
  // mu_eff approaches mu_fwd when vc>0 (forward sliding), mu_bwd when vc<0 (backward sliding)
  mu_1 = mu_fwd + delta_mu * (0.5 - 0.5 * tanh(vc_1 / v_eps));
  mu_2 = mu_fwd + delta_mu * (0.5 - 0.5 * tanh(vc_2 / v_eps));
  mu_3 = mu_fwd + delta_mu * (0.5 - 0.5 * tanh(vc_3 / v_eps));
  mu_4 = mu_fwd + delta_mu * (0.5 - 0.5 * tanh(vc_4 / v_eps));
  mu_5 = mu_fwd + delta_mu * (0.5 - 0.5 * tanh(vc_5 / v_eps));
  mu_6 = mu_fwd + delta_mu * (0.5 - 0.5 * tanh(vc_6 / v_eps));

  // === Friction forces (smooth tanh regularization, no division by zero) ===
  Ff_1 = -N_1 * mu_1 * tanh(vc_1 / v_eps);
  Ff_2 = -N_2 * mu_2 * tanh(vc_2 / v_eps);
  Ff_3 = -N_3 * mu_3 * tanh(vc_3 / v_eps);
  Ff_4 = -N_4 * mu_4 * tanh(vc_4 / v_eps);
  Ff_5 = -N_5 * mu_5 * tanh(vc_5 / v_eps);
  Ff_6 = -N_6 * mu_6 * tanh(vc_6 / v_eps);

  F_friction = Ff_1 + Ff_2 + Ff_3 + Ff_4 + Ff_5 + Ff_6;

  // === Drag disturbance: 4.5 N during middle third (4 s to 8 s), smooth transitions ===
  F_drag = F_drag_mag * 0.5 * (tanh((time - t_drag_start) / t_smooth) - tanh((time - t_drag_end) / t_smooth));

  // === Ridge resistance: two low ridges on rigid plane, smooth Gaussian bumps ===
  F_ridge = F_ridge_max * exp(-((x - x_ridge1) / w_ridge) ^ 2) * (0.5 + 0.5 * tanh(v / v_eps))
          + F_ridge_max * exp(-((x - x_ridge2) / w_ridge) ^ 2) * (0.5 + 0.5 * tanh(v / v_eps));

  // === Body dynamics ===
  F_net = F_friction - F_drag - F_ridge;
  der(x) = v;
  der(v) = F_net / m_body;

  // === Reference and metrics ===
  x_ref = v_ref * time;
  cycles_real = time / T_gait;
  cycle_count = floor(cycles_real);
  avg_speed = x / (time + 0.01);
  progress = x;
  tracking_error = abs(x - x_ref);
  per_cycle_error = tracking_error / (cycles_real + 0.5);
  per_cycle_slip = abs(v * T_gait - v_ref * T_gait);

  // === Bound violation margins (negative = within bounds) ===
  actuator_bound_violation = max(abs(pCmd_1), max(abs(pCmd_2), max(abs(pCmd_3), max(abs(pCmd_4), max(abs(pCmd_5), abs(pCmd_6)))))) - Pmax;
  curvature_bound_violation = max(abs(theta_1), max(abs(theta_2), max(abs(theta_3), max(abs(theta_4), max(abs(theta_5), abs(theta_6)))))) - theta_max;

end SoftCrawlCrawlC;