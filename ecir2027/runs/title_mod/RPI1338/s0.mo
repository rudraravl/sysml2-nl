model TendonSoftCrawlF
  "Soft robotic tendon-driven crawler: 6 sections, 3 tendons, directional friction"

  constant Real PI = 3.141592653589793;

  // === Body parameters ===
  parameter Real L_body = 0.55 "Body length [m]";
  parameter Real L_sec = L_body / 6.0 "Section length [m]";
  parameter Real r_tendon = 0.015 "Tendon routing radius [m]";
  parameter Real EI_body = 0.08 "Bending stiffness [N.m^2]";
  parameter Real b_curv = 0.04 "Curvature damping [N.m.s]";
  parameter Real m_body = 0.5 "Total body mass [kg]";
  parameter Real m_sec = m_body / 6.0 "Per-section mass [kg]";
  parameter Real g_const = 9.81 "Gravity [m/s^2]";

  // === Friction ===
  parameter Real mu_fwd = 0.12 "Forward friction coefficient (low) [-]";
  parameter Real mu_bwd = 2.0 "Backward friction coefficient (high) [-]";
  parameter Real v_reg = 0.008 "Friction velocity regularization [m/s]";
  parameter Real kappa_lift = 5.0 "Curvature threshold for full lift-off [1/m]";

  // === Ridges ===
  parameter Real ridge1_pos = 0.08 "Ridge 1 ground position [m]";
  parameter Real ridge2_pos = 0.25 "Ridge 2 ground position [m]";
  parameter Real ridge_hw = 0.012 "Ridge half-width [m]";
  parameter Real ridge_fmult = 3.0 "Ridge friction multiplier [-]";

  // === Gait ===
  parameter Real T_max = 51.2 "Maximum tendon tension [N]";
  parameter Real T_bias = 8.0 "Tension bias [N]";
  parameter Real T_amp = 12.0 "Tension amplitude [N]";
  parameter Real f_gait = 0.5 "Gait frequency [Hz]";
  parameter Real omega_gait = 2.0 * PI * f_gait "Gait angular frequency [rad/s]";
  parameter Real dphase = 2.0 * PI / 3.0 "Inter-tendon phase shift (120 deg) [rad]";
  parameter Real k_wave = PI / 3.0 "Spatial wave number [rad/section]";
  parameter Real K_prop = 0.05 "Propulsion coupling gain [N.s/m]";

  // === Disturbance ===
  parameter Real F_drag_val = 7.25 "Drag load magnitude [N]";
  parameter Real t_sim = 20.0 "Simulation duration [s]";

  // === Verification thresholds ===
  parameter Real err_thresh = 0.032 "Tracking error threshold [m/cycle]";
  parameter Real v_ref = 0.005 "Reference forward speed [m/s]";
  parameter Real kappa_bound = 15.0 "Curvature upper bound [1/m]";

  // === State variables ===
  Real kappa[6] "Section curvature [1/m]";
  Real kappa_dot[6] "Section curvature rate [1/(m.s)]";
  Real kappa_est[6] "Strain-estimated curvature [1/m]";
  Real x_body "Body position from odometry [m]";
  Real v_body "Body velocity [m/s]";
  Real x_ref "Reference position [m]";

  // === Tendon variables ===
  Real T1_cmd "Tendon 1 command [N]";
  Real T2_cmd "Tendon 2 command [N]";
  Real T3_cmd "Tendon 3 command [N]";
  Real T1 "Tendon 1 actual tension [N]";
  Real T2 "Tendon 2 actual tension [N]";
  Real T3 "Tendon 3 actual tension [N]";
  Real M_sec[6] "Section bending moment [N.m]";

  // === Contact and friction ===
  Real contact_frac[6] "Contact fraction per section [-]";
  Real f_normal[6] "Normal force per section [N]";
  Real f_fric[6] "Friction force per section [N]";
  Real x_sec[6] "Section absolute position [m]";
  Real ridge_mult[6] "Ridge friction multiplier per section [-]";
  Real mu_eff[6] "Effective directional friction coefficient [-]";
  Real abs_k[6] "Absolute curvature per section [1/m]";
  Real ridge_e1[6] "Ridge 1 Gaussian kernel [-]";
  Real ridge_e2[6] "Ridge 2 Gaussian kernel [-]";
  Real mu_smooth "Smooth friction direction selector [-]";

  // === Forces ===
  Real F_prop "Propulsive force from gait [N]";
  Real F_fric_sum "Total friction force [N]";
  Real F_drag "Applied drag disturbance [N]";
  Real F_net "Net force on body [N]";

  // === Gait tracking ===
  Real phase "Gait phase [rad]";
  Real n_cycles "Completed gait cycles [-]";
  Real avg_speed "Average forward speed [m/s]";
  Real track_err "Absolute tracking error [m]";
  Real track_err_cycle "Tracking error per cycle [m/cycle]";
  Real slip_cycle "Estimated slip per cycle [m]";
  Real progress "Total forward progress [m]";

  // === Verification ===
  Real max_T "Maximum tendon tension [N]";
  Real max_kappa "Maximum curvature magnitude [1/m]";
  Boolean actuator_ok "Actuator bounds satisfied";
  Boolean curvature_ok "Curvature bounds satisfied";
  Boolean tracking_ok "Tracking error within threshold";
  Boolean no_nan_inf "No NaN or infinite values";
  Boolean all_ok "All verification criteria pass";

initial equation
  x_body = 0.0;
  v_body = 0.0;
  x_ref = 0.0;
  for i in 1:6 loop
    kappa[i] = 0.0;
    kappa_dot[i] = 0.0;
    kappa_est[i] = 0.0;
  end for;

equation
  // === Gait phase and cycle count ===
  phase = omega_gait * time;
  n_cycles = floor(time * f_gait);

  // === Phase-shifted tendon tension commands (120 deg apart) ===
  T1_cmd = T_bias + T_amp * sin(phase);
  T2_cmd = T_bias + T_amp * sin(phase + dphase);
  T3_cmd = T_bias + T_amp * sin(phase + 2.0 * dphase);

  // === Saturated tendon tensions ===
  T1 = max(0.0, min(T_max, T1_cmd));
  T2 = max(0.0, min(T_max, T2_cmd));
  T3 = max(0.0, min(T_max, T3_cmd));

  // === Section bending moments from tendon tensions ===
  for i in 1:6 loop
    M_sec[i] = r_tendon * (
      T1 * cos(k_wave * (i - 1)) +
      T2 * cos(k_wave * (i - 1) + dphase) +
      T3 * cos(k_wave * (i - 1) + 2.0 * dphase)
    );
  end for;

  // === Curvature dynamics (second-order per section) ===
  for i in 1:6 loop
    der(kappa[i]) = kappa_dot[i];
    der(kappa_dot[i]) = (M_sec[i] - EI_body * kappa[i] - b_curv * kappa_dot[i]) / (m_sec * L_sec * L_sec + 1e-12);
  end for;

  // === Strain sensor estimation (first-order filter at 60 rad/s) ===
  for i in 1:6 loop
    der(kappa_est[i]) = 60.0 * (kappa[i] - kappa_est[i]);
  end for;

  // === Section absolute positions ===
  for i in 1:6 loop
    x_sec[i] = x_body + (i - 0.5) * L_sec;
  end for;

  // === Ridge friction multipliers (Gaussian bumps) ===
  for i in 1:6 loop
    ridge_e1[i] = exp(-((x_sec[i] - ridge1_pos) / ridge_hw)^2);
    ridge_e2[i] = exp(-((x_sec[i] - ridge2_pos) / ridge_hw)^2);
    ridge_mult[i] = 1.0 + (ridge_fmult - 1.0) * (ridge_e1[i] + ridge_e2[i]);
  end for;

  // === Contact model: curvature reduces contact ===
  for i in 1:6 loop
    abs_k[i] = abs(kappa[i]);
    contact_frac[i] = max(0.0, 1.0 - abs_k[i] / (kappa_lift + 1e-12));
    f_normal[i] = contact_frac[i] * m_sec * g_const;
  end for;

  // === Smooth directional friction selection ===
  mu_smooth = 0.5 - 0.5 * tanh(v_body / v_reg);
  for i in 1:6 loop
    mu_eff[i] = ridge_mult[i] * (mu_fwd + (mu_bwd - mu_fwd) * mu_smooth);
    f_fric[i] = -mu_eff[i] * f_normal[i] * tanh(v_body / v_reg);
  end for;

  // === Propulsive force from curvature-rate gait coupling ===
  F_prop = -K_prop * (
    kappa_dot[1] * contact_frac[1] +
    kappa_dot[2] * contact_frac[2] +
    kappa_dot[3] * contact_frac[3] +
    kappa_dot[4] * contact_frac[4] +
    kappa_dot[5] * contact_frac[5] +
    kappa_dot[6] * contact_frac[6]
  );

  // === Total friction (explicit scalar sum) ===
  F_fric_sum = f_fric[1] + f_fric[2] + f_fric[3] + f_fric[4] + f_fric[5] + f_fric[6];

  // === Drag disturbance (middle third: 6.667 s to 13.333 s) ===
  F_drag = if (time >= t_sim / 3.0 and time <= 2.0 * t_sim / 3.0) then F_drag_val else 0.0;

  // === Body dynamics ===
  F_net = F_prop + F_fric_sum - F_drag;
  der(x_body) = v_body;
  der(v_body) = F_net / (m_body + 1e-12);

  // === Reference trajectory ===
  der(x_ref) = v_ref;

  // === Tracking and performance metrics ===
  progress = x_body;
  avg_speed = x_body / max(time, 0.001);
  track_err = abs(x_ref - x_body);
  track_err_cycle = track_err / max(n_cycles, 1.0);
  slip_cycle = (x_ref - x_body) / max(n_cycles, 1.0);

  // === Verification: actuator bounds ===
  max_T = max(max(T1, T2), T3);
  actuator_ok = max_T <= T_max + 1e-6;

  // === Verification: curvature bounds ===
  max_kappa = max(max(max(abs_k[1], abs_k[2]), max(abs_k[3], abs_k[4])), max(abs_k[5], abs_k[6]));
  curvature_ok = max_kappa <= kappa_bound;

  // === Verification: tracking error after 13 s ===
  tracking_ok = if time >= 13.0 then track_err_cycle <= err_thresh else true;

  // === Verification: no NaN or infinite values ===
  no_nan_inf = (x_body > -1e10) and (x_body < 1e10) and
              (v_body > -1e10) and (v_body < 1e10) and
              (F_net > -1e10) and (F_net < 1e10) and
              (T1 > -1e10) and (T1 < 1e10) and
              (T2 > -1e10) and (T2 < 1e10) and
              (T3 > -1e10) and (T3 < 1e10) and
              (kappa_est[1] > -1e10) and (kappa_est[1] < 1e10) and
              (kappa_est[6] > -1e10) and (kappa_est[6] < 1e10) and
              (F_prop > -1e10) and (F_prop < 1e10) and
              (F_fric_sum > -1e10) and (F_fric_sum < 1e10);

  all_ok = actuator_ok and curvature_ok and tracking_ok and no_nan_inf;

  annotation(
    experiment(StartTime = 0, StopTime = 20, Tolerance = 1e-6, Interval = 0.002),
    Documentation(info = "Soft robotic tendon-driven crawler model.
      6 constant-curvature sections (0.55 m body), 3 tendons spaced 120 deg.
      Phase-shifted tension gait with directional friction on rigid plane.
      Two low ridges modeled as Gaussian friction multipliers.
      7.25 N drag disturbance applied during middle third of 20 s run.
      500 Hz sampling rate (Interval = 0.002 s).
      Verification: actuator bound 51.2 N, curvature bound, tracking error
      below 0.032 m/cycle after 13 s, no NaN or infinite values.")
  );
end TendonSoftCrawlF;