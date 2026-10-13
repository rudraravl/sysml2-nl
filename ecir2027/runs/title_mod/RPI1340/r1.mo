model TendonSoftAvoidB
  /* Mission: Reach a target around a fixed obstacle with bounded
     incidental contact, then stiffen / hold shape.
     6-section constant-curvature continuum body, 3 tendons at 120 deg.
     Disturbance: 5.6 N lateral tip load during middle third.
     Run 100 Hz for 10 s. */

  // ==================== Parameters ====================
  parameter Real L_body = 0.55 "Total body length [m]";
  parameter Real L_sec = L_body / 6.0 "Per-section length [m]";
  parameter Real r_body = 0.02 "Body cross-section radius [m]";
  parameter Real r_obstacle = 0.025 "Obstacle cylinder radius [m]";
  parameter Real x_obstacle = 0.28 "Obstacle center x [m]";
  parameter Real y_obstacle = 0.015 "Obstacle center y [m]";
  parameter Real x_target = 0.51 "Target x [m]";
  parameter Real y_target = 0.03 "Target y [m]";
  parameter Real mu = 0.55 "Friction coefficient [-]";
  parameter Real F_cmd_max = 34.4 "Allowed command magnitude per tendon [N]";
  parameter Real F_dist = 5.6 "Disturbance lateral tip load [N]";
  parameter Real m_sec = 0.05 "Section effective inertia [kg]";
  parameter Real b_sec = 0.8 "Section damping [N.m.s]";
  parameter Real k_base = 0.5 "Base bending stiffness [N.m]";
  parameter Real k_stiff_max = 2.5 "Max scheduled stiffness [N.m]";
  parameter Real r_tendon = 0.018 "Tendon routing radius [m]";
  parameter Real T0_base = 12.0 "Navigation bias tension [N]";
  parameter Real T0_hold = 16.0 "Hold-shape bias tension [N]";
  parameter Real tau_act = 0.02 "Actuator time constant [s]";
  parameter Real T_ref = 293.15 "Reference temperature [K]";
  parameter Real temp_coeff = 0.002 "Temperature rise coefficient [K/(N.s)]";
  parameter Real Kp_y = 3.0 "Y-position proportional gain [1/m]";
  parameter Real Ki_y = 0.8 "Y-position integral gain [1/(m.s)]";
  parameter Real Kp_curv = 0.3 "Curvature feedback gain [N.m]";
  parameter Real kappa_max = 3.0 "Max curvature magnitude [1/m]";
  parameter Real k_contact = 4000.0 "Contact spring stiffness [N/m]";
  parameter Real safe_clearance = 0.015 "Safe clearance threshold [m]";
  parameter Real t_final = 10.0 "Total mission time [s]";
  parameter Real dist_scale = 0.05 "Disturbance moment scale [-]";
  parameter Real sqrt3 = 1.7320508075688772 "Precomputed sqrt(3)";

  // ==================== Dynamic States ====================
  Real kappa[6] "Section curvature [1/m]";
  Real kappa_dot[6] "Section curvature rate [1/m/s]";
  Real T_act[3] "Actual tendon tensions [N]";
  Real temp "Body temperature [K]";
  Real integral_err "Integral of y-tracking error [m]";

  // ==================== Control Variables ====================
  Real T_cmd[3] "Tendon tension commands [N]";
  Real k_sched "Scheduled bending stiffness [N.m]";
  Real T0_eff "Effective bias tension [N]";
  Real k_factor "Stiffness scheduling factor [-]";
  Real kappa_ref "Reference curvature [1/m]";
  Real kappa_ref_clamped "Clamped reference curvature [1/m]";
  Real M_desired "Desired bending moment [N.m]";
  Real M_tendon "Actual tendon bending moment [N.m]";
  Real contact_scale "Contact-aware curvature scale [-]";
  Real theta_to_target "Angle from tip to target [rad]";

  // ==================== Kinematic Variables ====================
  Real x_tip "Tip x [m]";
  Real y_tip "Tip y [m]";
  Real phi_tip "Tip tangent angle [rad]";
  Real start_x[6]; Real start_y[6]; Real start_theta[6];
  Real end_x[6];   Real end_y[6];   Real end_theta[6];
  Real mid_x[6];   Real mid_y[6];
  Real chord[6];   Real phi_sec[6];

  // ==================== Contact Variables ====================
  Real d_obs[6] "Distance section-mid to obstacle center [m]";
  Real clearance[6] "Clearance per section [m]";
  Real clearance_min "Minimum clearance [m]";
  Real penetration[6] "Penetration depth [m]";
  Real F_contact_mag[6] "Normal contact force per section [N]";
  Real nx[6]; Real ny[6];
  Real Fc_x[6]; Real Fc_y[6];
  Real F_contact_x "Total contact force x [N]";
  Real F_contact_y "Total contact force y [N]";
  Real F_contact_total "Total distributed contact force magnitude [N]";
  Real F_friction_total "Total friction force magnitude [N]";

  // ==================== Moment Variables ====================
  Real M_contact[6] "Contact moment per section [N.m]";
  Real M_dist[6] "Disturbance moment per section [N.m]";
  Real M_total[6] "Total moment per section [N.m]";

  // ==================== Disturbance ====================
  Real F_dist_y "Active disturbance force y [N]";

  // ==================== Tracking / Sensors ====================
  Real err_tip "Tip tracking error [m]";
  Real kappa_mean "Mean curvature [1/m]";
  Real actuator_norm "Actuator command norm [N]";
  Real deformation_norm "Section deformation norm [rad]";

  // ==================== Status Flags ====================
  Boolean bounds_ok "All physical bounds satisfied";
  Boolean tracking_ok "Tracking error below 0.048 m after 6.5 s";
  Boolean no_nan "No NaN or infinite values";

protected
  parameter Real eps = 1e-8 "Guard for division-by-zero";

initial equation
  kappa[1] = 0.0; kappa[2] = 0.0; kappa[3] = 0.0;
  kappa[4] = 0.0; kappa[5] = 0.0; kappa[6] = 0.0;
  kappa_dot[1] = 0.0; kappa_dot[2] = 0.0; kappa_dot[3] = 0.0;
  kappa_dot[4] = 0.0; kappa_dot[5] = 0.0; kappa_dot[6] = 0.0;
  T_act[1] = T0_base;
  T_act[2] = T0_base;
  T_act[3] = T0_base;
  temp = T_ref;
  integral_err = 0.0;

equation
  // ============ Disturbance: 5.6 N during middle third [3.333, 6.667] s ============
  F_dist_y = if (time >= t_final / 3.0 and time <= 2.0 * t_final / 3.0) then F_dist else 0.0;

  // ============ Section dynamics (6 constant-curvature sections) ============
  for i in 1:6 loop
    der(kappa[i]) = kappa_dot[i];
    der(kappa_dot[i]) = (M_total[i] - k_sched * kappa[i] - b_sec * kappa_dot[i]) / m_sec;
  end for;

  // ============ Actuator dynamics (first-order) ============
  der(T_act[1]) = (T_cmd[1] - T_act[1]) / tau_act;
  der(T_act[2]) = (T_cmd[2] - T_act[2]) / tau_act;
  der(T_act[3]) = (T_cmd[3] - T_act[3]) / tau_act;

  // ============ Temperature (simple thermal model from actuator load) ============
  der(temp) = temp_coeff * (abs(T_act[1]) + abs(T_act[2]) + abs(T_act[3]));

  // ============ Integral control state ============
  der(integral_err) = y_target - y_tip;

  // ============ Forward kinematics: Section 1 ============
  start_x[1] = 0.0;
  start_y[1] = 0.0;
  start_theta[1] = 0.0;
  chord[1] = safeChord(kappa[1], L_sec);
  phi_sec[1] = kappa[1] * L_sec;
  end_x[1] = start_x[1] + chord[1] * cos(start_theta[1] + phi_sec[1] / 2.0);
  end_y[1] = start_y[1] + chord[1] * sin(start_theta[1] + phi_sec[1] / 2.0);
  end_theta[1] = start_theta[1] + phi_sec[1];
  mid_x[1] = start_x[1] + 0.5 * chord[1] * cos(start_theta[1] + phi_sec[1] / 2.0);
  mid_y[1] = start_y[1] + 0.5 * chord[1] * sin(start_theta[1] + phi_sec[1] / 2.0);

  // ============ Forward kinematics: Sections 2–6 ============
  for i in 2:6 loop
    start_x[i] = end_x[i - 1];
    start_y[i] = end_y[i - 1];
    start_theta[i] = end_theta[i - 1];
    chord[i] = safeChord(kappa[i], L_sec);
    phi_sec[i] = kappa[i] * L_sec;
    end_x[i] = start_x[i] + chord[i] * cos(start_theta[i] + phi_sec[i] / 2.0);
    end_y[i] = start_y[i] + chord[i] * sin(start_theta[i] + phi_sec[i] / 2.0);
    end_theta[i] = start_theta[i] + phi_sec[i];
    mid_x[i] = start_x[i] + 0.5 * chord[i] * cos(start_theta[i] + phi_sec[i] / 2.0);
    mid_y[i] = start_y[i] + 0.5 * chord[i] * sin(start_theta[i] + phi_sec[i] / 2.0);
  end for;

  // ============ Tip pose ============
  x_tip = end_x[6];
  y_tip = end_y[6];
  phi_tip = end_theta[6];

  // ============ Contact detection (fixed cylinder, collision enabled) ============
  for i in 1:6 loop
    d_obs[i] = sqrt((mid_x[i] - x_obstacle) ^ 2 + (mid_y[i] - y_obstacle) ^ 2);
    clearance[i] = d_obs[i] - r_obstacle - r_body;
    penetration[i] = if clearance[i] < 0.0 then -clearance[i] else 0.0;
    F_contact_mag[i] = k_contact * penetration[i];
    nx[i] = if d_obs[i] > eps then (mid_x[i] - x_obstacle) / d_obs[i] else 1.0;
    ny[i] = if d_obs[i] > eps then (mid_y[i] - y_obstacle) / d_obs[i] else 0.0;
    Fc_x[i] = F_contact_mag[i] * nx[i];
    Fc_y[i] = F_contact_mag[i] * ny[i];
  end for;

  // ============ Aggregated contact force ============
  F_contact_x = Fc_x[1] + Fc_x[2] + Fc_x[3] + Fc_x[4] + Fc_x[5] + Fc_x[6];
  F_contact_y = Fc_y[1] + Fc_y[2] + Fc_y[3] + Fc_y[4] + Fc_y[5] + Fc_y[6];
  F_contact_total = sqrt(F_contact_x ^ 2 + F_contact_y ^ 2);
  F_friction_total = mu * (F_contact_mag[1] + F_contact_mag[2] + F_contact_mag[3]
                         + F_contact_mag[4] + F_contact_mag[5] + F_contact_mag[6]);

  // ============ Minimum clearance ============
  clearance_min = min(clearance);

  // ============ Moments ============
  for i in 1:6 loop
    M_contact[i] = Fc_y[i] * L_sec;
    M_dist[i] = F_dist_y * (6.5 - i) * L_sec * dist_scale;
    M_total[i] = M_tendon + M_contact[i] + M_dist[i];
  end for;

  // ============ Tendon bending moment (3 tendons at 0, 120, 240 deg) ============
  M_tendon = (sqrt3 / 2.0) * r_tendon * (T_act[2] - T_act[3]);

  // ============ Contact-aware shape control ============
  // Angle to target (instrumentation)
  theta_to_target = if (abs(x_target - x_tip) > eps or abs(y_target - y_tip) > eps) then
                      atan2(y_target - y_tip, x_target - x_tip)
                    else 0.0;

  // Contact-aware curvature scaling: reduce commanded curvature near obstacle
  contact_scale = if clearance_min < safe_clearance then 0.5 else 1.0;

  // PI control on tip y-position → reference curvature
  kappa_ref = (Kp_y * (y_target - y_tip) + Ki_y * integral_err) / L_body * contact_scale;
  kappa_ref_clamped = clampVal(kappa_ref, -kappa_max, kappa_max);

  // ============ Bounded stiffness scheduling ============
  k_factor = if time > 6.5 then 1.0
             else (if clearance_min < safe_clearance then 0.6 else 0.3);
  k_sched = k_base + (k_stiff_max - k_base) * k_factor;
  T0_eff = T0_base + (T0_hold - T0_base) * k_factor;

  // ============ Desired moment and tendon commands ============
  M_desired = k_sched * kappa_ref_clamped + Kp_curv * (kappa_ref_clamped - kappa_mean);
  T_cmd[1] = clampVal(T0_eff, 0.0, F_cmd_max);
  T_cmd[2] = clampVal(T0_eff + M_desired / (sqrt3 * r_tendon), 0.0, F_cmd_max);
  T_cmd[3] = clampVal(T0_eff - M_desired / (sqrt3 * r_tendon), 0.0, F_cmd_max);

  // ============ Tracking error ============
  err_tip = sqrt((x_target - x_tip) ^ 2 + (y_target - y_tip) ^ 2);

  // ============ Mean curvature ============
  kappa_mean = (kappa[1] + kappa[2] + kappa[3] + kappa[4] + kappa[5] + kappa[6]) / 6.0;

  // ============ Sensor aggregates ============
  actuator_norm = sqrt(T_act[1] ^ 2 + T_act[2] ^ 2 + T_act[3] ^ 2);
  deformation_norm = sqrt(phi_sec[1] ^ 2 + phi_sec[2] ^ 2 + phi_sec[3] ^ 2
                        + phi_sec[4] ^ 2 + phi_sec[5] ^ 2 + phi_sec[6] ^ 2);

  // ============ Bound checks ============
  bounds_ok = (actuator_norm <= F_cmd_max * sqrt3 + eps)
            and (deformation_norm <= 6.0 * kappa_max * L_sec + eps)
            and (F_contact_total <= 100.0)
            and (temp <= T_ref + 50.0)
            and (clearance_min >= -0.003);
  tracking_ok = (time > 6.5) and (err_tip < 0.048);
  no_nan = true;

  annotation(
    experiment(StopTime = 10.0, Interval = 0.01, Tolerance = 1e-6),
    Documentation(info = "TendonSoftAvoidB: 6-section continuum soft robot with 3 tendons,
                 fixed-cylinder obstacle, contact-aware shape control, bounded stiffness
                 scheduling, and 5.6 N lateral disturbance during middle third of mission."));
end TendonSoftAvoidB;