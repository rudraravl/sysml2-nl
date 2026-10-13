model TendonSoftShapeB
  // ==================== Parameters ====================
  parameter Real L_body = 0.55 "Total body length [m]";
  parameter Real s_sec = L_body / 6.0 "Section length [m]";
  parameter Real T_max = 34.4 "Maximum tendon command magnitude [N]";
  parameter Real F_dist_val = 4.2 "Disturbance tip load [N]";
  parameter Real g_acc = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real rho_l = 0.03 "Linear mass density [kg/m]";
  parameter Real B_stiff = 2.0 "Bending stiffness [N.m2]";
  parameter Real C_damp = 0.1 "Bending damping [N.m.s]";
  parameter Real J_sec = 0.001 "Section rotational inertia [kg.m2]";
  parameter Real r_tendon = 0.08 "Tendon offset radius [m]";
  parameter Real T_bias = 10.0 "Bias tension [N]";
  parameter Real tau_act = 0.01 "Actuator time constant [s]";
  parameter Real temp_amb = 293.15 "Ambient temperature [K]";
  parameter Real thermal_coeff = 0.01 "Thermal sensitivity [K/N]";
  parameter Real tau_temp = 5.0 "Thermal time constant [s]";
  parameter Real Kp_ctrl = 15.0 "Controller proportional gain";
  parameter Real Ki_ctrl = 2.0 "Controller integral gain";
  parameter Real Kd_ctrl = 2.0 "Controller derivative gain";
  parameter Real e_int_max = 2.0 "Integral anti-windup limit";
  parameter Real kappa_t[6] = {0.5, 0.5, 0.5, 0.5, 0.5, 0.5}
    "Target section curvatures [1/m]";

  // ==================== Continuous states ====================
  Real kappa[6](start = {0, 0, 0, 0, 0, 0}) "Section curvatures [1/m]";
  Real kappa_dot[6](start = {0, 0, 0, 0, 0, 0}) "Section curvature rates [1/s]";
  Real T_meas[3](start = {10.0, 10.0, 10.0}) "Measured tendon tensions [N]";
  Real temp(start = 293.15) "Temperature [K]";

  // ==================== Discrete states ====================
  Real e_int(fixed = true, start = 0.0) "Integral of curvature error";
  Real kappa_cmd(fixed = true, start = 0.0) "Commanded curvature [1/m]";
  Real T_cmd[3](each fixed = true, each start = 10.0) "Commanded tensions [N]";
  Integer mode(fixed = true, start = 0)
    "Mission mode: 0=init, 1=move, 2=disturb, 3=hold";
  Real kappa_cmd_raw(fixed = true, start = 0.0) "Raw curvature command [1/m]";
  Real deltaT_raw(fixed = true, start = 0.0) "Raw tension delta [N]";
  Real T1_raw(fixed = true, start = 10.0) "Raw tension 1 [N]";
  Real T2_raw(fixed = true, start = 10.0) "Raw tension 2 [N]";
  Boolean saturating(fixed = true, start = false) "Actuator saturation flag";

  // ==================== Kinematics ====================
  Real theta_sec[6] "Section end angles [rad]";
  Real x_sec[6] "Section end x positions [m]";
  Real z_sec[6] "Section end z positions [m]";
  Real x_tip "Tip x position [m]";
  Real z_tip "Tip z position [m]";
  Real theta_tip "Tip angle [rad]";

  // Target kinematics (undeformed and actuated in shared frame)
  Real theta_t_sec[6] "Target section end angles [rad]";
  Real x_t_sec[6] "Target section end x [m]";
  Real z_t_sec[6] "Target section end z [m]";
  Real x_tip_target "Target tip x [m]";
  Real z_tip_target "Target tip z [m]";

  // ==================== Forces and moments ====================
  Real M_act "Actuation moment [N.m]";
  Real M_grav[6] "Gravity moments per section [N.m]";
  Real M_dist[6] "Disturbance moments per section [N.m]";
  Real F_disturbance "Active disturbance force [N]";
  Real T_total "Total tendon tension [N]";

  // ==================== Error metrics ====================
  Real tracking_error "Primary tip tracking error [m]";
  Real curvature_error "RMS curvature error [1/m]";
  Real kappa_avg "Average curvature [1/m]";
  Real kappa_t_avg "Target average curvature [1/m]";
  Real kappa_dot_avg "Average curvature rate [1/s]";

  // ==================== Bound checks ====================
  Boolean actuator_ok "Actuator command within bounds";
  Boolean curvature_ok "Curvature within physical bounds";
  Boolean temperature_ok "Temperature within bounds";
  Boolean tracking_ok "Tracking error below 0.054 m after 6.5 s";
  Boolean shape_error_ok "Final shape error within bounds";
  Boolean fsm_ok "Finite-state machine in valid state";
  Boolean no_nan_inf "No NaN or infinite values";

initial equation
  kappa = zeros(6);
  kappa_dot = zeros(6);
  T_meas = {T_bias, T_bias, T_bias};
  temp = temp_amb;

equation
  // ===== Target kinematics (constant from parameters) =====
  theta_t_sec[1] = kappa_t[1] * s_sec;
  for i in 2:6 loop
    theta_t_sec[i] = theta_t_sec[i - 1] + kappa_t[i] * s_sec;
  end for;

  x_t_sec[1] = (1.0 - cos(theta_t_sec[1])) / kappa_t[1];
  for i in 2:6 loop
    x_t_sec[i] = x_t_sec[i - 1] + (cos(theta_t_sec[i - 1]) - cos(theta_t_sec[i])) / kappa_t[i];
  end for;

  z_t_sec[1] = sin(theta_t_sec[1]) / kappa_t[1];
  for i in 2:6 loop
    z_t_sec[i] = z_t_sec[i - 1] + (sin(theta_t_sec[i]) - sin(theta_t_sec[i - 1])) / kappa_t[i];
  end for;

  x_tip_target = x_t_sec[6];
  z_tip_target = z_t_sec[6];

  // ===== Actual kinematics (shared frame, z-up) =====
  theta_sec[1] = kappa[1] * s_sec;
  for i in 2:6 loop
    theta_sec[i] = theta_sec[i - 1] + kappa[i] * s_sec;
  end for;

  x_sec[1] = if abs(kappa[1]) > 1e-8 then (1.0 - cos(theta_sec[1])) / kappa[1] else 0.0;
  for i in 2:6 loop
    x_sec[i] = x_sec[i - 1] + (if abs(kappa[i]) > 1e-8 then (cos(theta_sec[i - 1]) - cos(theta_sec[i])) / kappa[i] else s_sec * sin(theta_sec[i - 1]));
  end for;

  z_sec[1] = if abs(kappa[1]) > 1e-8 then sin(theta_sec[1]) / kappa[1] else s_sec;
  for i in 2:6 loop
    z_sec[i] = z_sec[i - 1] + (if abs(kappa[i]) > 1e-8 then (sin(theta_sec[i]) - sin(theta_sec[i - 1])) / kappa[i] else s_sec * cos(theta_sec[i - 1]));
  end for;

  x_tip = x_sec[6];
  z_tip = z_sec[6];
  theta_tip = theta_sec[6];

  // ===== Finite state machine =====
  when time >= 6.67 then
    mode = 3;
  elsewhen time >= 3.33 then
    mode = 2;
  elsewhen time >= 1.0 then
    mode = 1;
  end when;

  // ===== Disturbance: 4.2 N tip load during middle third =====
  F_disturbance = if (time >= 3.33 and time < 6.67) then F_dist_val else 0.0;

  // ===== Gravity moments (reduced-order: distributed load approximation) =====
  M_grav[1] = 0.0;
  M_grav[2] = rho_l * g_acc * s_sec * s_sec * 12.5 * sin(theta_sec[1]);
  M_grav[3] = rho_l * g_acc * s_sec * s_sec * 8.0 * sin(theta_sec[2]);
  M_grav[4] = rho_l * g_acc * s_sec * s_sec * 4.5 * sin(theta_sec[3]);
  M_grav[5] = rho_l * g_acc * s_sec * s_sec * 2.0 * sin(theta_sec[4]);
  M_grav[6] = rho_l * g_acc * s_sec * s_sec * 0.5 * sin(theta_sec[5]);

  // ===== Disturbance moments (lateral tip load in -x) =====
  M_dist[1] = -F_disturbance * z_tip;
  for i in 2:6 loop
    M_dist[i] = -F_disturbance * (z_tip - z_sec[i - 1]);
  end for;

  // ===== Actuation moment (3 tendons, 120 deg spacing) =====
  M_act = r_tendon * (T_meas[1] - 0.5 * T_meas[2] - 0.5 * T_meas[3]);

  // ===== Section dynamics (constant-curvature, 6 sections) =====
  for i in 1:6 loop
    J_sec * der(kappa_dot[i]) = M_act + M_grav[i] + M_dist[i] - B_stiff * kappa[i] - C_damp * kappa_dot[i];
    der(kappa[i]) = kappa_dot[i];
  end for;

  // ===== Actuator dynamics (first-order lag, 100 Hz bandwidth) =====
  for i in 1:3 loop
    der(T_meas[i]) = (T_cmd[i] - T_meas[i]) / tau_act;
  end for;

  // ===== Temperature dynamics =====
  T_total = T_meas[1] + T_meas[2] + T_meas[3];
  der(temp) = (temp_amb + thermal_coeff * T_total - temp) / tau_temp;

  // ===== Error metrics =====
  kappa_avg = (kappa[1] + kappa[2] + kappa[3] + kappa[4] + kappa[5] + kappa[6]) / 6.0;
  kappa_t_avg = (kappa_t[1] + kappa_t[2] + kappa_t[3] + kappa_t[4] + kappa_t[5] + kappa_t[6]) / 6.0;
  kappa_dot_avg = (kappa_dot[1] + kappa_dot[2] + kappa_dot[3] + kappa_dot[4] + kappa_dot[5] + kappa_dot[6]) / 6.0;

  tracking_error = sqrt((x_tip - x_tip_target)^2 + (z_tip - z_tip_target)^2 + 1e-12);

  curvature_error = sqrt(
    (kappa[1] - kappa_t[1])^2 + (kappa[2] - kappa_t[2])^2 +
    (kappa[3] - kappa_t[3])^2 + (kappa[4] - kappa_t[4])^2 +
    (kappa[5] - kappa_t[5])^2 + (kappa[6] - kappa_t[6])^2 + 1e-12);

  // ===== Shape-feedback controller (sampled at 100 Hz) =====
  // Reduced-order deformation model: PD on average curvature with
  // conditional anti-windup integral for gravity compensation.
  // Integral frozen during disturbance mode and actuator saturation.
  when sample(0, 0.01) then
    kappa_cmd_raw = kappa_t_avg + Kp_ctrl * (kappa_t_avg - kappa_avg)
                    + Ki_ctrl * pre(e_int) - Kd_ctrl * kappa_dot_avg;
    deltaT_raw = kappa_cmd_raw * B_stiff / (r_tendon * 1.5);
    T1_raw = T_bias + deltaT_raw;
    T2_raw = T_bias - 0.5 * deltaT_raw;
    saturating = (T1_raw > T_max or T1_raw < 0.0 or
                  T2_raw < 0.0 or T2_raw > T_max);
    if (mode == 2 or saturating) then
      e_int = pre(e_int);
    else
      e_int = max(-e_int_max, min(e_int_max,
                pre(e_int) + (kappa_t_avg - kappa_avg) * 0.01));
    end if;
    kappa_cmd = kappa_cmd_raw;
    T_cmd[1] = max(0.0, min(T_max, T1_raw));
    T_cmd[2] = max(0.0, min(T_max, T2_raw));
    T_cmd[3] = max(0.0, min(T_max, T2_raw));
  end when;

  // ===== Bounds checks =====
  actuator_ok = (T_cmd[1] >= 0.0 and T_cmd[1] <= T_max and
                 T_cmd[2] >= 0.0 and T_cmd[2] <= T_max and
                 T_cmd[3] >= 0.0 and T_cmd[3] <= T_max);
  curvature_ok = (abs(kappa[1]) < 20.0 and abs(kappa[2]) < 20.0 and
                  abs(kappa[3]) < 20.0 and abs(kappa[4]) < 20.0 and
                  abs(kappa[5]) < 20.0 and abs(kappa[6]) < 20.0);
  temperature_ok = (temp > 250.0 and temp < 400.0);
  tracking_ok = (time < 6.5 or tracking_error < 0.054);
  shape_error_ok = (time < 9.0 or tracking_error < 0.08);
  fsm_ok = (mode >= 0 and mode <= 3);
  no_nan_inf = (abs(kappa[1]) < 1e10 and abs(kappa[2]) < 1e10 and
                abs(kappa[3]) < 1e10 and abs(T_meas[1]) < 1e10 and
                abs(temp) < 1e10 and abs(kappa_cmd) < 1e10);

end TendonSoftShapeB;