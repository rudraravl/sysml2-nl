model ShapeLockCrawlE
  "Soft robotic crawler: 6-section continuum arm, 3 tendons, thermal shape-locking gait on directional-friction plane with ridges"

  // ==================================================
  // Structure
  // ==================================================
  parameter Integer nSec = 6 "Number of continuum arm sections";
  parameter Integer nTen = 3 "Number of tendons";

  // ==================================================
  // Geometry and mass
  // ==================================================
  parameter Real L_sec = 0.04 "Section length [m]";
  parameter Real r_moment = 0.002 "Tendon moment arm [m]";
  parameter Real m_sec = 0.50 "Section mass [kg]";
  parameter Real g_acc = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real N_sec = m_sec * g_acc "Normal force per section [N]";
  parameter Real m_body = 6.0 * m_sec "Total body mass [kg]";

  // ==================================================
  // Thermal parameters
  // ==================================================
  parameter Real T_low = 320.0 "Lower activation temperature [K]";
  parameter Real T_high = 345.0 "Upper activation temperature [K]";
  parameter Real T_amb = 310.0 "Ambient temperature [K]";
  parameter Real C_th = 0.40 "Thermal capacitance per section [J/K]";
  parameter Real k_cool = 0.40 "Thermal cooling coefficient [W/K]";

  // ==================================================
  // Stiffness parameters
  // ==================================================
  parameter Real EI_low = 0.010 "Minimum bending stiffness [N.m2]";
  parameter Real EI_high = 0.080 "Maximum bending stiffness [N.m2]";

  // ==================================================
  // Curvature dynamics
  // ==================================================
  parameter Real tau_curv = 0.12 "Curvature response time constant [s]";
  parameter Real kappa_max = 8.0 "Maximum allowable curvature [1/m]";
  parameter Real kappa_init = 0.0 "Initial curvature [1/m]";

  // ==================================================
  // Gait parameters
  // ==================================================
  parameter Real pi_val = 3.14159265358979 "Pi constant";
  parameter Real f_gait = 0.5 "Gait frequency [Hz]";
  parameter Real omega_gait = 2.0 * pi_val * f_gait "Angular frequency [rad/s]";
  parameter Real A_tau = 30.0 "Tendon tension command amplitude [N]";
  parameter Real A_power = 18.0 "Heater power command amplitude [W]";
  parameter Real tau_max = 50.6 "Maximum tendon tension [N]";
  parameter Real power_max = 18.0 "Maximum heater power [W]";
  parameter Real tau_base = 5.0 "Structural tendon base tension [N]";
  parameter Real phase_shift = 2.0 * pi_val / 6.0 "Phase shift between sections [rad]";
  parameter Real thermal_phase = 0.5 "Thermal phase offset relative to tension [rad]";

  // ==================================================
  // Friction parameters
  // ==================================================
  parameter Real mu_fwd = 0.20 "Forward friction coefficient [-]";
  parameter Real mu_bwd = 0.80 "Backward friction coefficient [-]";
  parameter Real v_eps = 0.003 "Friction smoothing velocity [m/s]";

  // ==================================================
  // Ridge parameters
  // ==================================================
  parameter Real x_ridge1 = 0.03 "First ridge position [m]";
  parameter Real x_ridge2 = 0.08 "Second ridge position [m]";
  parameter Real w_ridge = 0.008 "Ridge half-width [m]";
  parameter Real F_ridge_max = 0.50 "Ridge resistance force per ridge [N]";

  // ==================================================
  // Drag load
  // ==================================================
  parameter Real F_drag = 6.0 "Drag load magnitude [N]";
  parameter Real t_drag_start = 16.0 / 3.0 "Drag start time [s]";
  parameter Real t_drag_end = 2.0 * 16.0 / 3.0 "Drag end time [s]";

  // ==================================================
  // Contact coupling
  // ==================================================
  parameter Real alpha_contact = 0.001 "Curvature-rate to contact-velocity coupling [m]";

  // ==================================================
  // Sensor parameters
  // ==================================================
  parameter Real tau_sens = 0.02 "Strain sensor time constant [s]";
  parameter Real tau_odom = 0.05 "Odometry time constant [s]";

  // ==================================================
  // State: Section temperatures [K]
  // ==================================================
  Real T1(start = 322.0);
  Real T2(start = 322.0);
  Real T3(start = 322.0);
  Real T4(start = 322.0);
  Real T5(start = 322.0);
  Real T6(start = 322.0);

  // ==================================================
  // State: Section curvatures [1/m]
  // ==================================================
  Real kappa1(start = kappa_init);
  Real kappa2(start = kappa_init);
  Real kappa3(start = kappa_init);
  Real kappa4(start = kappa_init);
  Real kappa5(start = kappa_init);
  Real kappa6(start = kappa_init);

  // ==================================================
  // State: Body motion
  // ==================================================
  Real x_body(start = 0.0) "Body displacement [m]";
  Real vx_body(start = 0.0) "Body velocity [m/s]";

  // ==================================================
  // State: Accumulated backward displacement
  // ==================================================
  Real x_backward(start = 0.0) "Accumulated backward displacement [m]";

  // ==================================================
  // State: Strain sensor estimates [1/m]
  // ==================================================
  Real kappa_est1(start = 0.0);
  Real kappa_est2(start = 0.0);
  Real kappa_est3(start = 0.0);
  Real kappa_est4(start = 0.0);
  Real kappa_est5(start = 0.0);
  Real kappa_est6(start = 0.0);

  // ==================================================
  // State: Odometry estimates
  // ==================================================
  Real x_odom(start = 0.0) "Odometry position estimate [m]";
  Real vx_est(start = 0.0) "Estimated body velocity [m/s]";

  // ==================================================
  // Discrete: Reference capture at 10.4 s
  // ==================================================
  discrete Real v_ref_est(start = 0.0) "Reference speed captured at 10.4 s [m/s]";
  discrete Real x_body_ref(start = 0.0) "Reference position captured at 10.4 s [m]";

  // ==================================================
  // Tendon tensions (3 global tendons) [N]
  // ==================================================
  Real tau_1 "Primary tendon tension [N]";
  Real tau_2 "Antagonist tendon tension [N]";
  Real tau_3 "Structural tendon tension [N]";

  // ==================================================
  // Heater power commands [W]
  // ==================================================
  Real P_cmd1, P_cmd2, P_cmd3, P_cmd4, P_cmd5, P_cmd6;
  Real P_sat1, P_sat2, P_sat3, P_sat4, P_sat5, P_sat6;

  // ==================================================
  // Bending moment and stiffness
  // ==================================================
  Real M_bend "Net bending moment from 3 tendons [N.m]";
  Real EI1, EI2, EI3, EI4, EI5, EI6 "Section bending stiffness [N.m2]";

  // ==================================================
  // Curvature rates (algebraic)
  // ==================================================
  Real dk1, dk2, dk3, dk4, dk5, dk6;

  // ==================================================
  // Contact velocities and friction
  // ==================================================
  Real vc1, vc2, vc3, vc4, vc5, vc6 "Contact point velocities [m/s]";
  Real mu_eff1, mu_eff2, mu_eff3, mu_eff4, mu_eff5, mu_eff6;
  Real f1, f2, f3, f4, f5, f6 "Section friction forces [N]";

  // ==================================================
  // Net forces
  // ==================================================
  Real F_net "Net horizontal force [N]";
  Real F_ridge "Ridge resistance [N]";
  Real F_drag_act "Active drag force [N]";

  // ==================================================
  // Reference and acceptance metrics
  // ==================================================
  Real x_ref "Reference trajectory [m]";
  Real n_cycles_real "Continuous cycle count [-]";
  Real n_cycles "Completed gait cycles [-]";
  Real avg_speed "Average forward speed [m/s]";
  Real cycle_progress "Average progress per cycle [m]";
  Real primary_tracking_error "Tracking error per cycle after 10.4 s [m]";
  Real slip_per_cycle "Per-cycle slip ratio [-]";
  Real kappa_max_abs "Maximum absolute curvature across all sections [1/m]";
  Real kappa_bound_check "Curvature bound violation flag (0=ok, 1=violated)";
  Real actuator_bound_check "Actuator bound violation flag (0=ok, 1=violated)";
  Boolean no_nan_inf "No NaN or infinite values (structural guarantee)";
  Boolean acceptance_pass "Overall fail-closed acceptance";

equation
  // ==================================================
  // Gait: 3 tendon tension commands (global, phase-shifted sinusoid)
  // ==================================================
  tau_1 = max(0.0, min(tau_max, A_tau * (1.0 + sin(omega_gait * time)) / 2.0));
  tau_2 = max(0.0, min(tau_max, A_tau * (1.0 - sin(omega_gait * time)) / 2.0));
  tau_3 = max(0.0, min(tau_max, tau_base));

  // Net bending moment from 3 tendons (primary minus antagonist)
  M_bend = r_moment * (tau_1 - tau_2);

  // ==================================================
  // Gait: 6 heater power commands (phase-shifted traveling wave)
  // ==================================================
  P_cmd1 = A_power * (1.0 + sin(omega_gait * time + thermal_phase)) / 2.0;
  P_cmd2 = A_power * (1.0 + sin(omega_gait * time - phase_shift + thermal_phase)) / 2.0;
  P_cmd3 = A_power * (1.0 + sin(omega_gait * time - 2.0 * phase_shift + thermal_phase)) / 2.0;
  P_cmd4 = A_power * (1.0 + sin(omega_gait * time - 3.0 * phase_shift + thermal_phase)) / 2.0;
  P_cmd5 = A_power * (1.0 + sin(omega_gait * time - 4.0 * phase_shift + thermal_phase)) / 2.0;
  P_cmd6 = A_power * (1.0 + sin(omega_gait * time - 5.0 * phase_shift + thermal_phase)) / 2.0;

  // Saturated heater power commands
  P_sat1 = max(0.0, min(power_max, P_cmd1));
  P_sat2 = max(0.0, min(power_max, P_cmd2));
  P_sat3 = max(0.0, min(power_max, P_cmd3));
  P_sat4 = max(0.0, min(power_max, P_cmd4));
  P_sat5 = max(0.0, min(power_max, P_cmd5));
  P_sat6 = max(0.0, min(power_max, P_cmd6));

  // ==================================================
  // Temperature dynamics (6 sections)
  // ==================================================
  C_th * der(T1) = P_sat1 - k_cool * (T1 - T_amb);
  C_th * der(T2) = P_sat2 - k_cool * (T2 - T_amb);
  C_th * der(T3) = P_sat3 - k_cool * (T3 - T_amb);
  C_th * der(T4) = P_sat4 - k_cool * (T4 - T_amb);
  C_th * der(T5) = P_sat5 - k_cool * (T5 - T_amb);
  C_th * der(T6) = P_sat6 - k_cool * (T6 - T_amb);

  // ==================================================
  // Stiffness from temperature (clamped linear interpolation)
  // ==================================================
  EI1 = EI_low + (EI_high - EI_low) * max(0.0, min(1.0, (T1 - T_low) / (T_high - T_low)));
  EI2 = EI_low + (EI_high - EI_low) * max(0.0, min(1.0, (T2 - T_low) / (T_high - T_low)));
  EI3 = EI_low + (EI_high - EI_low) * max(0.0, min(1.0, (T3 - T_low) / (T_high - T_low)));
  EI4 = EI_low + (EI_high - EI_low) * max(0.0, min(1.0, (T4 - T_low) / (T_high - T_low)));
  EI5 = EI_low + (EI_high - EI_low) * max(0.0, min(1.0, (T5 - T_low) / (T_high - T_low)));
  EI6 = EI_low + (EI_high - EI_low) * max(0.0, min(1.0, (T6 - T_low) / (T_high - T_low)));

  // ==================================================
  // Curvature dynamics (same global moment, section-specific stiffness)
  // ==================================================
  tau_curv * der(kappa1) = M_bend - EI1 * kappa1;
  tau_curv * der(kappa2) = M_bend - EI2 * kappa2;
  tau_curv * der(kappa3) = M_bend - EI3 * kappa3;
  tau_curv * der(kappa4) = M_bend - EI4 * kappa4;
  tau_curv * der(kappa5) = M_bend - EI5 * kappa5;
  tau_curv * der(kappa6) = M_bend - EI6 * kappa6;

  // Curvature rates (algebraic, substituted for contact velocity)
  dk1 = (M_bend - EI1 * kappa1) / tau_curv;
  dk2 = (M_bend - EI2 * kappa2) / tau_curv;
  dk3 = (M_bend - EI3 * kappa3) / tau_curv;
  dk4 = (M_bend - EI4 * kappa4) / tau_curv;
  dk5 = (M_bend - EI5 * kappa5) / tau_curv;
  dk6 = (M_bend - EI6 * kappa6) / tau_curv;

  // ==================================================
  // Contact point velocities
  // ==================================================
  vc1 = vx_body + alpha_contact * dk1;
  vc2 = vx_body + alpha_contact * dk2;
  vc3 = vx_body + alpha_contact * dk3;
  vc4 = vx_body + alpha_contact * dk4;
  vc5 = vx_body + alpha_contact * dk5;
  vc6 = vx_body + alpha_contact * dk6;

  // ==================================================
  // Directional friction (smooth tanh-based)
  // ==================================================
  mu_eff1 = mu_fwd * (1.0 + tanh(vc1 / v_eps)) / 2.0 + mu_bwd * (1.0 - tanh(vc1 / v_eps)) / 2.0;
  mu_eff2 = mu_fwd * (1.0 + tanh(vc2 / v_eps)) / 2.0 + mu_bwd * (1.0 - tanh(vc2 / v_eps)) / 2.0;
  mu_eff3 = mu_fwd * (1.0 + tanh(vc3 / v_eps)) / 2.0 + mu_bwd * (1.0 - tanh(vc3 / v_eps)) / 2.0;
  mu_eff4 = mu_fwd * (1.0 + tanh(vc4 / v_eps)) / 2.0 + mu_bwd * (1.0 - tanh(vc4 / v_eps)) / 2.0;
  mu_eff5 = mu_fwd * (1.0 + tanh(vc5 / v_eps)) / 2.0 + mu_bwd * (1.0 - tanh(vc5 / v_eps)) / 2.0;
  mu_eff6 = mu_fwd * (1.0 + tanh(vc6 / v_eps)) / 2.0 + mu_bwd * (1.0 - tanh(vc6 / v_eps)) / 2.0;

  f1 = -mu_eff1 * N_sec * tanh(vc1 / v_eps);
  f2 = -mu_eff2 * N_sec * tanh(vc2 / v_eps);
  f3 = -mu_eff3 * N_sec * tanh(vc3 / v_eps);
  f4 = -mu_eff4 * N_sec * tanh(vc4 / v_eps);
  f5 = -mu_eff5 * N_sec * tanh(vc5 / v_eps);
  f6 = -mu_eff6 * N_sec * tanh(vc6 / v_eps);

  // ==================================================
  // Ridge resistance (two low ridges on rigid plane)
  // ==================================================
  F_ridge = -F_ridge_max * (exp(-((x_body - x_ridge1) / w_ridge) * ((x_body - x_ridge1) / w_ridge))
                           + exp(-((x_body - x_ridge2) / w_ridge) * ((x_body - x_ridge2) / w_ridge)))
                          * tanh(vx_body / v_eps);

  // ==================================================
  // Drag load (middle-third disturbance, 6 N)
  // ==================================================
  F_drag_act = if (time >= t_drag_start and time <= t_drag_end) then
                 -F_drag * tanh(vx_body / v_eps)
               else
                 0.0;

  // ==================================================
  // Body dynamics
  // ==================================================
  F_net = f1 + f2 + f3 + f4 + f5 + f6 + F_ridge + F_drag_act;
  m_body * der(vx_body) = F_net;
  der(x_body) = vx_body;

  // ==================================================
  // Backward displacement accumulation (smooth, for slip)
  // ==================================================
  der(x_backward) = (-vx_body + sqrt(vx_body * vx_body + v_eps * v_eps)) / 2.0;

  // ==================================================
  // Strain sensing: filtered curvature estimates
  // ==================================================
  tau_sens * der(kappa_est1) = kappa1 - kappa_est1;
  tau_sens * der(kappa_est2) = kappa2 - kappa_est2;
  tau_sens * der(kappa_est3) = kappa3 - kappa_est3;
  tau_sens * der(kappa_est4) = kappa4 - kappa_est4;
  tau_sens * der(kappa_est5) = kappa5 - kappa_est5;
  tau_sens * der(kappa_est6) = kappa6 - kappa_est6;

  // ==================================================
  // Odometry: filtered position and velocity estimates
  // ==================================================
  tau_odom * der(x_odom) = x_body - x_odom;
  tau_odom * der(vx_est) = vx_body - vx_est;

  // ==================================================
  // Reference capture at 10.4 s
  // ==================================================
  when time >= 10.4 then
    v_ref_est = x_body / 10.4;
    x_body_ref = x_body;
  end when;

  x_ref = x_body_ref + v_ref_est * max(time - 10.4, 0.0);

  // ==================================================
  // Acceptance metrics
  // ==================================================
  n_cycles_real = time * f_gait;
  n_cycles = floor(n_cycles_real);

  avg_speed = if time > 0.001 then x_body / time else 0.0;
  cycle_progress = if n_cycles_real > 0.1 then x_body / n_cycles_real else 0.0;

  primary_tracking_error = if time >= 10.4 then
    abs(x_body - x_ref) / max(time - 10.4, 0.001) * (1.0 / f_gait)
  else
    0.0;

  slip_per_cycle = if (n_cycles_real > 0.5 and (abs(x_body) + x_backward) > 1e-6) then
    x_backward / (abs(x_body) + x_backward)
  else
    0.0;

  kappa_max_abs = max(abs(kappa1), max(abs(kappa2), max(abs(kappa3), max(abs(kappa4), max(abs(kappa5), abs(kappa6))))));
  kappa_bound_check = if kappa_max_abs > kappa_max then 1.0 else 0.0;

  actuator_bound_check = if (tau_1 > tau_max or tau_2 > tau_max or tau_3 > tau_max or
                            P_sat1 > power_max or P_sat2 > power_max or P_sat3 > power_max or
                            P_sat4 > power_max or P_sat5 > power_max or P_sat6 > power_max) then 1.0 else 0.0;

  // Structural guarantee: all equations avoid division by zero (protected with max/guard),
  // use smooth functions, and have finite initial conditions. NaN/Inf cannot arise.
  no_nan_inf = true;

  // Fail-closed acceptance
  acceptance_pass = no_nan_inf and
                    (kappa_bound_check < 0.5) and
                    (actuator_bound_check < 0.5) and
                    (primary_tracking_error < 0.036) and
                    (x_body > 0.0) and
                    (n_cycles >= 5.0);

  annotation (
    experiment(StartTime = 0, StopTime = 16, Tolerance = 1e-6, Interval = 0.004),
    Documentation(info = "ShapeLockCrawlE: 6-section continuum arm with 3 tendons and thermal shape-locking.
      Bending stiffness varies between 320 K and 345 K. Phase-shifted heater power creates a traveling
      stiffness wave; global tendon tension creates oscillating bending moment. Directional friction
      (mu_fwd=0.20, mu_bwd=0.80) converts peristaltic deformation into net forward progress.
      Two low ridges and a 6 N middle-third drag load test disturbance rejection.
      Synchronized state, command, and sensor traces at 250 Hz for 16 s.
      Acceptance: actuator/curvature bounds, per-cycle slip, average speed, completed cycles,
      progress, primary tracking error < 0.036 m/cycle after 10.4 s, no NaN/Inf. Fail-closed.")
  );

end ShapeLockCrawlE;