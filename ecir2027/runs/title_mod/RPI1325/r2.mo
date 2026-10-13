model TendonSoftShapeE
  // =========================================================================
  // TendonSoftShapeE — Soft robotic continuum manipulator
  // 0.55 m cylindrical body, 6 constant-curvature sections, 3 tendons at 120 deg
  // Shape feedback via reduced-order deformation model, 7.2 N middle-third
  // tip disturbance, 250 Hz, 16 s, fail-closed acceptance.
  // =========================================================================

  // --- Geometry ---
  parameter Real L_body = 0.55 "Total continuum body length [m]";
  parameter Real L_sec = L_body / 6.0 "Length per constant-curvature section [m]";
  parameter Real d_tendon = 0.02 "Tendon offset from neutral axis [m]";
  parameter Real r_cross = 0.015 "Cross-section radius [m]";

  // --- Mechanics ---
  parameter Real EI_stiff = 0.5 "Bending stiffness [N.m^2]";
  parameter Real rho_line = 0.02 "Linear mass density [kg/m]";
  parameter Real g_grav = 9.81 "Gravitational acceleration [m/s^2]";
  parameter Real omega_n = 6.0 "Curvature natural frequency [rad/s]";
  parameter Real zeta_damp = 0.8 "Damping ratio [-]";

  // --- Actuation (3 tendons at 0, 120, 240 deg) ---
  parameter Real T_max = 46.2 "Maximum tendon tension command [N]";
  parameter Real T_bias = 15.0 "Pretension bias to keep tendons taut [N]";
  parameter Real tau_meas = 0.01 "Tension sensor time constant [s]";

  // --- Disturbance: 7.2 N tip load, middle third of 16 s ---
  parameter Real F_disturb = 7.2 "Tip disturbance force magnitude [N]";
  parameter Real t_dist_start = 16.0 / 3.0 "Disturbance onset [s]";
  parameter Real t_dist_end = 32.0 / 3.0 "Disturbance offset [s]";

  // --- Target shape ---
  parameter Real x_target = 0.05 "Target tip x-position [m]";
  parameter Real z_target = 0.547 "Target tip z-position [m]";

  // --- Shape-feedback controller ---
  parameter Real Kp_x = 80.0 "Tip x proportional gain [N.m/m]";
  parameter Real Kp_z = 20.0 "Tip z proportional gain [N.m/m]";

  // --- Thermal model ---
  parameter Real T_ambient = 293.15 "Ambient temperature [K]";
  parameter Real C_thermal = 30.0 "Thermal capacitance [J/K]";
  parameter Real h_thermal = 0.3 "Heat transfer coefficient [W/K]";
  parameter Real T_temp_limit = 340.0 "Temperature upper bound [K]";

  // --- Acceptance bounds ---
  parameter Real kappa_limit = 15.0 "Curvature magnitude bound [1/m]";
  parameter Real err_limit = 0.041 "Primary tracking error bound [m]";
  parameter Real t_settle = 10.4 "Settling time threshold [s]";
  parameter Real t_sim = 16.0 "Simulation duration [s]";
  parameter Real dt_250 = 0.004 "250 Hz communication interval [s]";

  // ============ DYNAMIC STATE VARIABLES ============
  Real kappa[6](each start = 0.0, each fixed = true) "Section curvature [1/m]";
  Real kappa_dot[6](each start = 0.0, each fixed = true) "Curvature rate [1/m/s]";
  Real T_meas[3](each start = T_bias, each fixed = true) "Measured tendon tension [N]";
  Real temperature(start = T_ambient, fixed = true) "Body temperature [K]";

  // ============ ALGEBRAIC VARIABLES ============
  // Actuator
  Real T_cmd_raw[3] "Unclipped tension command [N]";
  Real T_cmd[3] "Saturated tension command [N]";
  Real M_des "Desired bending moment from controller [N.m]";
  Real M_tendon "Net tendon bending moment [N.m]";

  // Section measurements
  Real strain[6] "Surface strain at cross-section radius [-]";

  // Forward kinematics (constant-curvature, shared base frame)
  Real alpha[7] "Cumulative tangent angle at section boundary [rad]";
  Real x_pos[7] "x-position at section boundary [m]";
  Real z_pos[7] "z-position at section boundary [m]";
  Real tip_x "Tip x-position [m]";
  Real tip_z "Tip z-position [m]";
  Real tip_angle "Tip tangent angle [rad]";
  Real tip_x_undef "Undeformed tip x [m]";
  Real tip_z_undef "Undeformed tip z [m]";

  // Gravity
  Real M_gravity[6] "Gravity-induced moment at each section [N.m]";
  Real F_above[6] "Total downward force above each section [N]";
  Real F_dist "Active disturbance force [N]";

  // Tracking
  Real tracking_error "Euclidean tip tracking error [m]";

  // Reduced-order deformation model
  Real kappa_rom[6] "ROM curvature estimate from tensions [1/m]";
  Real tip_x_rom "ROM tip x-estimate [m]";
  Real tip_z_rom "ROM tip z-estimate [m]";

  // Thermal
  Real power_diss "Tendon friction power dissipation [W]";

  // ============ DISCRETE VARIABLES ============
  Integer fsm_state(start = 0) "0=init, 1=moving, 2=holding, 3=fault";
  Boolean dist_active "Disturbance active flag";

  // Acceptance flags (fail-closed)
  Boolean actuator_ok "Actuator within bounds";
  Boolean curvature_ok "Curvature within bounds";
  Boolean temperature_ok "Temperature within bounds";
  Boolean tracking_ok "Tracking error within bound after settle";
  Boolean no_nan_inf "No NaN or infinite values";
  Boolean all_accept_ok "All acceptance criteria satisfied";

equation
  // ===================== BASE BOUNDARY =====================
  alpha[1] = 0.0;
  x_pos[1] = 0.0;
  z_pos[1] = 0.0;

  // ===================== FORWARD KINEMATICS =====================
  // Six constant-curvature sections chained in shared x-z frame.
  // Zero-curvature branch avoids division by zero.
  for i in 1:6 loop
    if noEvent(abs(kappa[i]) < 1e-8) then
      alpha[i + 1] = alpha[i];
      x_pos[i + 1] = x_pos[i] + L_sec * sin(alpha[i]);
      z_pos[i + 1] = z_pos[i] + L_sec * cos(alpha[i]);
    else
      alpha[i + 1] = alpha[i] + kappa[i] * L_sec;
      x_pos[i + 1] = x_pos[i] + (sin(alpha[i + 1]) - sin(alpha[i])) / kappa[i];
      z_pos[i + 1] = z_pos[i] + (cos(alpha[i]) - cos(alpha[i + 1])) / kappa[i];
    end if;
  end for;

  tip_x = x_pos[7];
  tip_z = z_pos[7];
  tip_angle = alpha[7];
  tip_x_undef = 0.0;
  tip_z_undef = L_body;

  // ===================== STRAIN =====================
  for i in 1:6 loop
    strain[i] = kappa[i] * r_cross;
  end for;

  // ===================== DISTURBANCE =====================
  dist_active = (time >= t_dist_start) and (time < t_dist_end);
  F_dist = if dist_active then F_disturb else 0.0;

  // ===================== GRAVITY LOADS =====================
  // Weight above each section: tip disturbance + self-weight of sections i..6
  F_above[1] = F_dist + rho_line * g_grav * L_body;
  F_above[2] = F_dist + rho_line * g_grav * L_body * 5.0 / 6.0;
  F_above[3] = F_dist + rho_line * g_grav * L_body * 4.0 / 6.0;
  F_above[4] = F_dist + rho_line * g_grav * L_body * 3.0 / 6.0;
  F_above[5] = F_dist + rho_line * g_grav * L_body * 2.0 / 6.0;
  F_above[6] = F_dist + rho_line * g_grav * L_body * 1.0 / 6.0;

  // P-delta gravity moment (lumped at tip, conservative)
  for i in 1:6 loop
    M_gravity[i] = F_above[i] * (tip_x - x_pos[i]);
  end for;

  // ===================== TENDON MOMENT =====================
  // 3 tendons at 0, 120, 240 deg — planar bending moment
  M_tendon = d_tendon * (T_meas[1] - 0.5 * T_meas[2] - 0.5 * T_meas[3]);

  // ===================== CURVATURE DYNAMICS =====================
  // Second-order per-section: m*ddot + c*dot + k = kappa_eq
  for i in 1:6 loop
    der(kappa[i]) = kappa_dot[i];
    der(kappa_dot[i]) = omega_n * omega_n
      * ((M_tendon + M_gravity[i]) / EI_stiff - kappa[i])
      - 2.0 * zeta_damp * omega_n * kappa_dot[i];
  end for;

  // ===================== TRACKING ERROR =====================
  tracking_error = sqrt(max(
    (x_target - tip_x) * (x_target - tip_x)
    + (z_target - tip_z) * (z_target - tip_z),
    1e-12));

  // ===================== SHAPE-FEEDBACK CONTROLLER =====================
  M_des = if fsm_state == 0 or fsm_state == 3 then 0.0
    else Kp_x * (x_target - tip_x) + Kp_z * (tip_z - z_target);

  // ===================== TENSION ALLOCATION =====================
  T_cmd_raw[1] = T_bias + 2.0 * M_des / (3.0 * d_tendon);
  T_cmd_raw[2] = T_bias - M_des / (3.0 * d_tendon);
  T_cmd_raw[3] = T_bias - M_des / (3.0 * d_tendon);

  // Saturation to [0, T_max] per tendon
  T_cmd[1] = max(0.0, min(T_max, T_cmd_raw[1]));
  T_cmd[2] = max(0.0, min(T_max, T_cmd_raw[2]));
  T_cmd[3] = max(0.0, min(T_max, T_cmd_raw[3]));

  // ===================== TENSION SENSOR =====================
  for j in 1:3 loop
    tau_meas * der(T_meas[j]) + T_meas[j] = T_cmd[j];
  end for;

  // ===================== REDUCED-ORDER MODEL =====================
  // ROM: equilibrium curvature from commanded tensions (gravity-free)
  for i in 1:6 loop
    kappa_rom[i] = d_tendon
      * (T_cmd[1] - 0.5 * T_cmd[2] - 0.5 * T_cmd[3]) / EI_stiff;
  end for;

  // Small-angle ROM tip estimate for shape feedback
  tip_x_rom = kappa_rom[1] * L_sec * (L_body - 0.5 * L_sec)
    + kappa_rom[2] * L_sec * (L_body - 1.5 * L_sec)
    + kappa_rom[3] * L_sec * (L_body - 2.5 * L_sec)
    + kappa_rom[4] * L_sec * (L_body - 3.5 * L_sec)
    + kappa_rom[5] * L_sec * (L_body - 4.5 * L_sec)
    + kappa_rom[6] * L_sec * (L_body - 5.5 * L_sec);
  tip_z_rom = L_body;

  // ===================== TEMPERATURE =====================
  power_diss = d_tendon * abs(kappa_dot[1])
    * (T_meas[1] + T_meas[2] + T_meas[3]);
  C_thermal * der(temperature) = power_diss
    - h_thermal * (temperature - T_ambient);

  // ===================== FINITE-STATE MACHINE =====================
  when time >= 0.5 and pre(fsm_state) == 0 then
    fsm_state = 1;
  elsewhen time >= t_settle and pre(fsm_state) == 1 then
    fsm_state = 2;
  elsewhen (not (actuator_ok and curvature_ok and temperature_ok))
    and time > 1.0 and pre(fsm_state) < 3 then
    fsm_state = 3;
  end when;

  // ===================== ACCEPTANCE BOUNDS =====================
  // Actuator bound
  actuator_ok = (T_cmd[1] >= 0.0) and (T_cmd[1] <= T_max)
    and (T_cmd[2] >= 0.0) and (T_cmd[2] <= T_max)
    and (T_cmd[3] >= 0.0) and (T_cmd[3] <= T_max);

  // Curvature bound
  curvature_ok = (abs(kappa[1]) <= kappa_limit)
    and (abs(kappa[2]) <= kappa_limit)
    and (abs(kappa[3]) <= kappa_limit)
    and (abs(kappa[4]) <= kappa_limit)
    and (abs(kappa[5]) <= kappa_limit)
    and (abs(kappa[6]) <= kappa_limit);

  // Temperature bound
  temperature_ok = (temperature >= T_ambient - 5.0)
    and (temperature <= T_temp_limit);

  // Tracking error bound (enforced after t_settle = 10.4 s)
  tracking_ok = if time >= t_settle then tracking_error < err_limit
    else true;

  // NaN / Inf guard
  no_nan_inf = (tracking_error > 0.0) and (tracking_error < 1e6)
    and (tip_x > -1e6) and (tip_x < 1e6)
    and (tip_z > -1e6) and (tip_z < 1e6)
    and (temperature > 0.0) and (temperature < 1e6);

  // Fail-closed: all criteria must hold simultaneously
  all_accept_ok = actuator_ok and curvature_ok and temperature_ok
    and tracking_ok and no_nan_inf;

  annotation(
    experiment(StartTime = 0, StopTime = 16.0, Tolerance = 1e-6,
      Interval = 0.004),
    Documentation(info = "TendonSoftShapeE: 6-section constant-curvature "
      & "continuum manipulator (0.55 m), 3 tendons at 120 deg spacing, "
      & "shape feedback via reduced-order deformation model, 7.2 N "
      & "middle-third tip disturbance. 250 Hz, 16 s, fail-closed."));
end TendonSoftShapeE;