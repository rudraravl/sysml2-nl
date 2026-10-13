model SoftCrawlAvoidD
  "Instrumented soft robotic crawler: 6-chamber pneumatic bending, obstacle avoidance, bounded stiffness scheduling"

  // === Body parameters ===
  parameter Real L_total = 0.48 "Total compliant body length [m]";
  parameter Real L_sec = 0.08 "Per-section length [m]";
  parameter Real p_max = 75000.0 "Maximum chamber pressure [Pa-gauge]";
  parameter Real mu_fwd = 0.04 "Forward ground friction coefficient [-]";
  parameter Real mu_bwd = 0.30 "Backward ground friction coefficient (anisotropic) [-]";
  parameter Real mu_obstacle = 0.55 "Obstacle cylinder friction coefficient [-]";
  parameter Real m_base = 1.0 "Effective base mass [kg]";
  parameter Real c_drag = 1.0 "Ground drag coefficient [N.s/m]";
  parameter Real F_prop_avg = 0.016 "Average propulsive force from anisotropic crawling [N]";

  // === Bending dynamics ===
  parameter Real k_bend = 1.2e-4 "Bending gain [rad/(Pa.s^2)]";
  parameter Real c_bend = 3.0 "Bending damping [1/s]";
  parameter Real k_stiff_base = 80.0 "Base stiffness schedule [1/s^2]";
  parameter Real k_stiff_hold = 500.0 "Hold stiffness schedule [1/s^2]";

  // === Obstacle ===
  parameter Real R_obstacle = 0.025 "Obstacle cylinder radius [m]";
  parameter Real x_obstacle = 0.25 "Obstacle center x [m]";
  parameter Real y_obstacle = -0.01 "Obstacle center y [m]";
  parameter Real k_contact = 2000.0 "Obstacle contact stiffness [N/m]";
  parameter Real c_contact = 15.0 "Obstacle contact damping [N.s/m]";

  // === Target ===
  parameter Real x_target = 0.60 "Target x position [m]";
  parameter Real y_target = 0.05 "Target y position [m]";

  // === Disturbance ===
  parameter Real F_disturb = 8.0 "Lateral tip load disturbance [N]";

  // === Tip compliance ===
  parameter Real m_tip = 0.3 "Effective tip mass [kg]";
  parameter Real k_tip = 300.0 "Tip compliance stiffness [N/m]";
  parameter Real c_tip = 10.0 "Tip compliance damping [N.s/m]";

  // === Traveling wave ===
  parameter Real freq_wave = 0.4 "Traveling wave frequency [Hz]";
  parameter Real p_bias = 20000.0 "Chamber pressure bias [Pa]";
  parameter Real p_wave_amp = 25000.0 "Chamber pressure wave amplitude [Pa]";

  // === Contact-aware steering ===
  parameter Real k_steer = 8000.0 "Steering pressure gain [Pa]";
  parameter Real R_steer = 0.05 "Steering activation radius [m]";

  // === Dynamic states ===
  Real x_base(start = 0.0, fixed = true) "Base x position [m]";
  Real v_base(start = 0.0, fixed = true) "Base velocity [m/s]";
  Real phi[6](each start = 0.0, each fixed = true) "Section bending angles [rad]";
  Real phi_rate[6](each start = 0.0, each fixed = true) "Section bending rates [rad/s]";
  Real phi_ref[6](each start = 0.0, each fixed = true) "Shape reference angles [rad]";
  Real d_filt[6](each start = 1.0, each fixed = true) "Filtered obstacle distance [m]";
  Real dx_tip(start = 0.0, fixed = true) "Tip compliance displacement x [m]";
  Real dy_tip(start = 0.0, fixed = true) "Tip compliance displacement y [m]";
  Real dvx_tip(start = 0.0, fixed = true) "Tip compliance velocity x [m/s]";
  Real dvy_tip(start = 0.0, fixed = true) "Tip compliance velocity y [m/s]";

  // === Command signals ===
  Real p[6] "Chamber pressure commands [Pa-gauge]";
  Real p_steer_cmd[6] "Contact-aware steering pressure [Pa]";
  Real k_stiff "Scheduled stiffness [1/s^2]";
  Real hold_factor "Hold transition factor [-]";
  Real F_prop "Propulsive crawling force [N]";
  Real wave_phase "Traveling wave phase [rad]";

  // === Kinematic chain ===
  Real theta_sec[6] "Section base orientations [rad]";
  Real x_base_sec[6] "Section base x [m]";
  Real y_base_sec[6] "Section base y [m]";
  Real x_sec[6] "Section center x [m]";
  Real y_sec[6] "Section center y [m]";
  Real x_tip "Tip x position [m]";
  Real y_tip "Tip y position [m]";
  Real theta_tip "Tip orientation [rad]";

  // === Contact sensing ===
  Real d_obstacle[6] "Obstacle clearance per section [m]";
  Real F_contact[6] "Contact force per section [N]";
  Real F_contact_total "Total contact force [N]";
  Real F_obstacle_friction "Obstacle Coulomb friction on base [N]";
  Real clearance "Minimum obstacle clearance [m]";

  // === Disturbance ===
  Real F_lat "Lateral disturbance force [N]";

  // === Tracking ===
  Real err_x "Tip x tracking error [m]";
  Real err_y "Tip y tracking error [m]";
  Real tip_error "Tip tracking error norm [m]";

  // === Instrumentation ===
  Real T_body "Body temperature estimate [K]";
  Real max_phi "Maximum section deformation [rad]";
  Real max_p "Maximum chamber pressure [Pa]";

equation
  // --- Traveling wave ---
  wave_phase = 2.0 * Modelica.Constants.pi * freq_wave * time;

  // --- Bounded stiffness scheduling: smooth hold transition after 9.1 s ---
  hold_factor = 1.0 / (1.0 + exp(-10.0 * (time - 9.1)));
  k_stiff = k_stiff_base + (k_stiff_hold - k_stiff_base) * hold_factor;

  // --- Propulsive force (anisotropic friction crawling, brakes on hold) ---
  F_prop = (F_prop_avg + 0.004 * sin(wave_phase)) * (1.0 - hold_factor);

  // --- Obstacle Coulomb friction on base ---
  F_obstacle_friction = -mu_obstacle * F_contact_total * tanh(v_base / 0.01);

  // --- Base dynamics ---
  der(x_base) = v_base;
  der(v_base) = (F_prop - c_drag * v_base + F_obstacle_friction) / m_base;

  // --- Filtered obstacle distance (breaks algebraic loop for steering) ---
  for i in 1:6 loop
    der(d_filt[i]) = (d_obstacle[i] - d_filt[i]) / 0.05;
  end for;

  // --- Contact-aware steering pressure ---
  for i in 1:6 loop
    p_steer_cmd[i] = k_steer * noEvent(if d_filt[i] < R_steer then (R_steer - d_filt[i]) / R_steer else 0.0);
  end for;

  // --- Bounded chamber pressure commands: bias + traveling wave + steering ---
  for i in 1:6 loop
    p[i] = max(0.0, min(p_max,
      p_bias
      + p_wave_amp * sin(wave_phase + (i - 1) * 2.0 * Modelica.Constants.pi / 6.0)
      + p_steer_cmd[i]));
  end for;

  // --- Shape reference: tracks phi before hold, freezes after ---
  for i in 1:6 loop
    der(phi_ref[i]) = (phi[i] - phi_ref[i]) / (0.3 + 999.7 * hold_factor);
  end for;

  // --- Bending dynamics: pressure-driven with shape-hold stiffness ---
  for i in 1:6 loop
    der(phi[i]) = phi_rate[i];
    der(phi_rate[i]) = k_bend * p[i] - k_stiff * (phi[i] - phi_ref[i]) - c_bend * phi_rate[i];
  end for;

  // --- Serial kinematic chain ---
  theta_sec[1] = phi[1];
  x_base_sec[1] = x_base;
  y_base_sec[1] = 0.0;
  for i in 2:6 loop
    theta_sec[i] = theta_sec[i - 1] + phi[i];
    x_base_sec[i] = x_base_sec[i - 1] + L_sec * cos(theta_sec[i - 1]);
    y_base_sec[i] = y_base_sec[i - 1] + L_sec * sin(theta_sec[i - 1]);
  end for;
  for i in 1:6 loop
    x_sec[i] = x_base_sec[i] + 0.5 * L_sec * cos(theta_sec[i]);
    y_sec[i] = y_base_sec[i] + 0.5 * L_sec * sin(theta_sec[i]);
  end for;
  theta_tip = theta_sec[6];
  x_tip = x_base_sec[6] + L_sec * cos(theta_sec[6]) + dx_tip;
  y_tip = y_base_sec[6] + L_sec * sin(theta_sec[6]) + dy_tip;

  // --- Obstacle contact detection and penalty force ---
  for i in 1:6 loop
    d_obstacle[i] = sqrt((x_sec[i] - x_obstacle) ^ 2 + (y_sec[i] - y_obstacle) ^ 2) - R_obstacle;
    F_contact[i] = noEvent(if d_obstacle[i] < 0.0 then -k_contact * d_obstacle[i] else 0.0);
  end for;
  F_contact_total = F_contact[1] + F_contact[2] + F_contact[3] + F_contact[4] + F_contact[5] + F_contact[6];
  clearance = min(min(min(min(min(d_obstacle[1], d_obstacle[2]), d_obstacle[3]), d_obstacle[4]), d_obstacle[5]), d_obstacle[6]);

  // --- Lateral tip disturbance during middle third ---
  F_lat = noEvent(if time >= 14.0 / 3.0 and time <= 2.0 * 14.0 / 3.0 then F_disturb else 0.0);

  // --- Tip compliance dynamics (disturbance + contact coupling) ---
  der(dx_tip) = dvx_tip;
  der(dvx_tip) = (F_lat * cos(theta_tip) - k_tip * dx_tip - c_tip * dvx_tip) / m_tip;
  der(dy_tip) = dvy_tip;
  der(dvy_tip) = (F_lat * sin(theta_tip) - k_tip * dy_tip - c_tip * dvy_tip + F_contact_total * 0.03) / m_tip;

  // --- Tracking error ---
  err_x = x_target - x_tip;
  err_y = y_target - y_tip;
  tip_error = sqrt(err_x * err_x + err_y * err_y);

  // --- Instrumentation: temperature, deformation bound, pressure bound ---
  T_body = 293.15 + 5.0 * (1.0 - exp(-time / 8.0)) + 0.005 * abs(F_contact_total);
  max_phi = max(abs(phi[1]), max(abs(phi[2]), max(abs(phi[3]), max(abs(phi[4]), max(abs(phi[5]), abs(phi[6]))))));
  max_p = max(p[1], max(p[2], max(p[3], max(p[4], max(p[5], p[6])))));

end SoftCrawlAvoidD;