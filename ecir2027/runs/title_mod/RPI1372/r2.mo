model SoftCrawlShapeD
  "Instrumented soft crawling robot: 6 pneumatic chambers, traveling-wave locomotion, target shape holding"

  // ==================== Parameters ====================
  parameter Integer N = 6 "Number of serial pneumatic bending chambers";
  parameter Real L_total = 0.48 "Total compliant body length [m]";
  parameter Real L_seg = L_total / N "Per-chamber length [m]";
  parameter Real P_max = 75000.0 "Maximum gauge pressure [Pa]";
  parameter Real F_disturb = 6.0 "Tip load disturbance [N]";
  parameter Real T_sim = 14.0 "Simulation duration [s]";
  parameter Real T_conv = 9.1 "Primary tracking convergence deadline [s]";
  parameter Real err_bound = 0.045 "Primary tracking error bound [m]";
  parameter Real g_acc = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real rho = 0.30 "Linear mass density [kg/m]";
  parameter Real J_seg = 0.001 "Segment rotary inertia [kg.m2]";
  parameter Real c_seg = 0.5 "Segment angular damping [N.m.s/rad]";
  parameter Real k_stiff = 20.0 "Segment mechanical stiffness [N.m/rad]";
  parameter Real k_press = 0.0001 "Pressure-to-torque gain [N.m/Pa]";
  parameter Real k_grav = 0.015 "Gravity torque coefficient [N.m]";
  parameter Real k_shape = 50.0 "Shape feedback gain [N.m/rad]";
  parameter Real mu_fwd = 0.05 "Forward (low) friction coefficient";
  parameter Real mu_bwd = 0.35 "Backward (high) friction coefficient";
  parameter Real T_ambient = 293.15 "Ambient temperature [K]";
  parameter Real k_temp_cool = 0.05 "Temperature cooling rate [1/s]";
  parameter Real k_temp_heat = 0.00001 "Temperature heating coefficient [K/Pa]";
  parameter Real tau_press = 0.02 "Pressure actuator time constant [s]";
  parameter Real P_crawl_bias = 20000.0 "Crawl-phase bias pressure [Pa]";
  parameter Real P_crawl_amp = 25000.0 "Crawl-phase wave amplitude [Pa]";
  parameter Real T_wave = 3.0 "Traveling wave period [s]";
  parameter Real F_wave_amp = 0.5 "Crawling propulsion force amplitude [N]";

  // ==================== Segment Dynamic States ====================
  Real theta[6](each start = 0.0) "Bend angle per chamber [rad]";
  Real omega[6](each start = 0.0) "Angular velocity [rad/s]";
  Real P_act[6](each start = 0.0) "Actual chamber pressure [Pa]";

  // ==================== Commands and Sensors ====================
  Real P_cmd[6] "Commanded chamber pressure [Pa]";
  Real kappa[6] "Measured curvature [1/m]";
  Real strain_meas[6] "Measured axial strain [-]";
  Real T_chamber[6](each start = T_ambient) "Chamber temperature [K]";

  // ==================== Forward Kinematics (Actual) ====================
  Real cum_angle[7] "Cumulative angle at joints [rad]";
  Real joint_x[7] "Joint x position [m]";
  Real joint_y[7] "Joint y position [m]";
  Real x_tip "Tip x position [m]";
  Real y_tip "Tip y position [m]";
  Real rel_tip_x "Tip x relative to base [m]";
  Real rel_tip_y "Tip y relative to base [m]";

  // ==================== Target Shape Kinematics ====================
  Real theta_target[6] "Target bend angles [rad]";
  Real cum_angle_t[7] "Target cumulative angles [rad]";
  Real joint_x_t[7] "Target joint x relative to base [m]";
  Real joint_y_t[7] "Target joint y relative to base [m]";
  Real x_tip_target "Target tip x relative to base [m]";
  Real y_tip_target "Target tip y relative to base [m]";

  // ==================== Undeformed Geometry ====================
  Real x_undeformed_tip "Undeformed tip x [m]";

  // ==================== Base Locomotion ====================
  Real x_base(start = 0.0) "Base x position [m]";
  Real v_base(start = 0.0) "Base velocity [m/s]";
  Real F_friction "Friction force [N]";
  Real F_propulsion "Propulsion force [N]";
  Real mu_eff "Effective friction coefficient";

  // ==================== Disturbance ====================
  Boolean disturb_active "Disturbance active flag";
  Real F_tip_x "Tip disturbance x-component [N]";
  Real F_tip_y "Tip disturbance y-component [N]";
  Real disturb_torque[6] "Disturbance torque per segment [N.m]";

  // ==================== Control ====================
  Real wave_phase "Traveling wave phase [rad]";
  Real phase_blend "Smooth phase blend (0=crawl, 1=hold)";
  Integer phase "Discrete FSM phase (0=crawl, 1=hold)";

  // ==================== Error Metrics ====================
  Real tracking_error "Primary tracking error [m]";
  Real shape_error "Shape error norm [rad]";
  Boolean converged "Convergence flag";
  Boolean bounds_ok "All physical bounds satisfied";

equation
  // ---- Disturbance window: middle third of simulation ----
  disturb_active = (time > T_sim / 3.0) and (time < 2.0 * T_sim / 3.0);

  // ---- Finite-state machine: crawl then hold ----
  phase = if time < 0.6 * T_sim then 0 else 1;
  phase_blend = 1.0 / (1.0 + exp(-8.0 * (time - 0.6 * T_sim)));

  // ---- Target shape: gentle upward arc (unimodal) ----
  theta_target[1] = 0.0;
  theta_target[2] = 0.12 * sin(Modelica.Constants.pi / 5.0);
  theta_target[3] = 0.12 * sin(2.0 * Modelica.Constants.pi / 5.0);
  theta_target[4] = 0.12 * sin(3.0 * Modelica.Constants.pi / 5.0);
  theta_target[5] = 0.12 * sin(4.0 * Modelica.Constants.pi / 5.0);
  theta_target[6] = 0.0;

  // ---- Undeformed tip (straight body from base) ----
  x_undeformed_tip = x_base + L_total;

  // ---- Target forward kinematics (base at origin, shared frame) ----
  cum_angle_t[1] = 0.0;
  joint_x_t[1] = 0.0;
  joint_y_t[1] = 0.0;
  for i in 1:N loop
    cum_angle_t[i + 1] = cum_angle_t[i] + theta_target[i];
    joint_x_t[i + 1] = joint_x_t[i] + L_seg * cos(cum_angle_t[i + 1]);
    joint_y_t[i + 1] = joint_y_t[i] + L_seg * sin(cum_angle_t[i + 1]);
  end for;
  x_tip_target = joint_x_t[7];
  y_tip_target = joint_y_t[7];

  // ---- Traveling wave phase ----
  wave_phase = 2.0 * Modelica.Constants.pi * time / T_wave;

  // ---- Pressure command: blend crawl (traveling wave) and hold (gravity comp) ----
  for i in 1:N loop
    P_cmd[i] = (1.0 - phase_blend) *
      (P_crawl_bias + P_crawl_amp * sin(wave_phase - 2.0 * Modelica.Constants.pi * (i - 1) / 6.0))
      + phase_blend *
      ((k_stiff * theta_target[i] + k_grav * g_acc * sin(cum_angle_t[i + 1])) / k_press);
    P_cmd[i] = if P_cmd[i] > P_max then P_max else if P_cmd[i] < 0.0 then 0.0 else P_cmd[i];
  end for;

  // ---- Pressure actuator dynamics (first-order lag) ----
  for i in 1:N loop
    der(P_act[i]) = (P_cmd[i] - P_act[i]) / tau_press;
  end for;

  // ---- Curvature and strain sensors ----
  for i in 1:N loop
    kappa[i] = theta[i] / L_seg;
    strain_meas[i] = 0.02 * P_act[i] / P_max;
  end for;

  // ---- Temperature sensor (lumped thermal model per chamber) ----
  for i in 1:N loop
    der(T_chamber[i]) = k_temp_cool * (T_ambient - T_chamber[i]) + k_temp_heat * P_act[i];
  end for;

  // ---- Forward kinematics of actual body ----
  cum_angle[1] = 0.0;
  joint_x[1] = x_base;
  joint_y[1] = 0.0;
  for i in 1:N loop
    cum_angle[i + 1] = cum_angle[i] + theta[i];
    joint_x[i + 1] = joint_x[i] + L_seg * cos(cum_angle[i + 1]);
    joint_y[i + 1] = joint_y[i] + L_seg * sin(cum_angle[i + 1]);
  end for;
  x_tip = joint_x[7];
  y_tip = joint_y[7];
  rel_tip_x = x_tip - x_base;
  rel_tip_y = y_tip;

  // ---- Tip disturbance force (directed against tip orientation) ----
  F_tip_x = if disturb_active then -F_disturb * cos(cum_angle[7]) else 0.0;
  F_tip_y = if disturb_active then -F_disturb * sin(cum_angle[7]) else 0.0;

  // ---- Disturbance torque distributed across segments ----
  for i in 1:N loop
    disturb_torque[i] = if disturb_active then
      (F_tip_y * (joint_x[7] - joint_x[i]) - F_tip_x * (joint_y[7] - joint_y[i])) / 6.0
    else 0.0;
  end for;

  // ---- Crawling propulsion (wave-driven, active during crawl only) ----
  F_propulsion = (1.0 - phase_blend) * F_wave_amp * sin(wave_phase - Modelica.Constants.pi / 4.0);

  // ---- Anisotropic friction (regularized with tanh) ----
  mu_eff = if v_base >= 0.0 then mu_fwd else mu_bwd;
  F_friction = -mu_eff * (rho * L_total * g_acc) * tanh(v_base / 0.01);

  // ---- Base locomotion dynamics ----
  der(x_base) = v_base;
  der(v_base) = (F_propulsion + F_tip_x + F_friction) / (rho * L_total);

  // ---- Segment dynamics: pressure torque, stiffness, gravity, damping, shape feedback, disturbance ----
  for i in 1:N loop
    der(theta[i]) = omega[i];
    der(omega[i]) = (k_press * P_act[i]
                     - k_stiff * theta[i]
                     - k_grav * g_acc * sin(cum_angle[i + 1])
                     - c_seg * omega[i]
                     + phase_blend * k_shape * (theta_target[i] - theta[i])
                     + disturb_torque[i]) / J_seg;
  end for;

  // ---- Primary tracking error: tip pose relative to base vs target ----
  tracking_error = sqrt((rel_tip_x - x_tip_target)^2 + (rel_tip_y - y_tip_target)^2);

  // ---- Shape error norm (expanded for N=6 to avoid array reduction) ----
  shape_error = sqrt(
    (theta[1] - theta_target[1])^2 + (theta[2] - theta_target[2])^2 +
    (theta[3] - theta_target[3])^2 + (theta[4] - theta_target[4])^2 +
    (theta[5] - theta_target[5])^2 + (theta[6] - theta_target[6])^2);

  // ---- Convergence flag ----
  converged = (time > T_conv) and (tracking_error < err_bound);

  // ---- Physical bounds: actuator, curvature, temperature, finite-state, shape-error ----
  bounds_ok = (P_act[1] >= -0.1) and (P_act[1] <= P_max + 0.1)
    and (P_act[2] >= -0.1) and (P_act[2] <= P_max + 0.1)
    and (P_act[3] >= -0.1) and (P_act[3] <= P_max + 0.1)
    and (P_act[4] >= -0.1) and (P_act[4] <= P_max + 0.1)
    and (P_act[5] >= -0.1) and (P_act[5] <= P_max + 0.1)
    and (P_act[6] >= -0.1) and (P_act[6] <= P_max + 0.1)
    and (T_chamber[1] > 250.0) and (T_chamber[1] < 350.0)
    and (T_chamber[6] > 250.0) and (T_chamber[6] < 350.0)
    and (abs(theta[1]) < 5.0) and (abs(theta[6]) < 5.0)
    and (abs(kappa[1]) < 50.0) and (abs(kappa[6]) < 50.0)
    and (phase >= 0) and (phase <= 1);

  // ---- Assertions for tracking error, bounds, and NaN/Inf prevention ----
  assert(time < T_conv or tracking_error < err_bound,
    "Primary tracking error exceeds 0.045 m after 9.1 s");
  assert(bounds_ok, "Physical bound violation: actuator, temperature, curvature, or FSM");
  assert(abs(tracking_error) < 50.0, "Tracking error diverged (NaN/Inf check)");
  assert(abs(shape_error) < 50.0, "Shape error diverged (NaN/Inf check)");

  annotation (
    experiment(StartTime = 0, StopTime = 14.0, Tolerance = 1e-6, Interval = 0.005),
    Documentation(info = "<html>
      <p>SoftCrawlShapeD: 0.48 m compliant body, 6 serial pneumatic bending chambers.</p>
      <p>Traveling-wave crawling (0-8.4 s) then target shape holding (8.4-14 s).</p>
      <p>6 N tip disturbance applied during middle third (4.67-9.33 s).</p>
      <p>200 Hz sample interval, 14 s duration.</p>
      <p>Primary tracking error below 0.045 m required after 9.1 s.</p>
    </html>")
  );
end SoftCrawlShapeD;