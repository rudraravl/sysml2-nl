model TendonSoftAvoidC
  // ==================== Specified Parameters ====================
  parameter Real F_max = 38.6 "Maximum command magnitude per tendon [N]";
  parameter Real F_dist_val = 7.2 "Lateral tip load disturbance magnitude [N]";
  parameter Real mu = 0.55 "Obstacle friction coefficient";
  parameter Real f_sample = 125.0 "Control loop sample rate [Hz]";
  parameter Real T_sim = 12.0 "Total simulation time [s]";
  parameter Real L_total = 0.55 "Cylindrical continuum body length [m]";
  parameter Integer n_sections = 6 "Number of constant-curvature sections";
  parameter Integer n_tendons = 3 "Number of tendons spaced 120 deg apart";

  // ==================== Assumed Parameters (not specified in request) ====================
  parameter Real L_s = L_total / n_sections "Per-section arc length [m]";
  parameter Real r_tendon = 0.10 "Tendon moment-arm radius [m]";
  parameter Real EI_val = 5.0 "Flexural rigidity [N.m^2]";
  parameter Real tau = 2.0 "Section curvature response time constant [s]";
  parameter Real r_obstacle = 0.02 "Fixed cylinder obstacle radius [m]";
  parameter Real x_obstacle = 0.02 "Obstacle center x [m]";
  parameter Real z_obstacle = 0.27 "Obstacle center z [m]";
  parameter Real x_target = 0.05 "Target tip x [m]";
  parameter Real z_target = 0.55 "Target tip z [m]";
  parameter Real k_contact = 500.0 "Contact penalty stiffness [N/m]";
  parameter Real penetration_tol = 0.0005 "Allowed penetration tolerance [m]";
  parameter Real k_thermal = 0.00005 "Thermal rise coefficient [K/(N^2.s)]";
  parameter Real k_cool = 0.02 "Cooling rate constant [1/s]";
  parameter Real T_amb = 293.15 "Ambient temperature [K]";
  parameter Real eps = 1.0e-6 "Singularity guard for division";
  parameter Real T_reach = 7.8 "Target reach time specification [s]";
  parameter Real T_baseline = 13.0 "Baseline tendon tension [N]";
  parameter Real tau_act = 0.05 "Actuator first-order time constant [s]";
  parameter Real k_pos = 25.0 "Proportional position feedback gain [N/m]";
  parameter Real k_avoid = 30.0 "Obstacle avoidance gain [N]";
  parameter Real d_safe = 0.010 "Safe clearance threshold [m]";
  parameter Real k_ff = 0.50 "Disturbance feedforward gain";
  parameter Real k_stiff_low = 0.80 "Low stiffness scheduling gain";
  parameter Real k_stiff_high = 2.00 "High stiffness scheduling gain";
  parameter Real kappa_target = 2.0 * atan(x_target / z_target) / L_total "Target curvature for nominal pose [1/m]";
  parameter Real M_nominal = EI_val * kappa_target "Nominal bending moment for target pose [N.m]";
  parameter Real M_max_pos = 2.0 * r_tendon * (F_max - T_baseline) / 3.0 "Max positive tendon moment [N.m]";
  parameter Real M_max_neg = 2.0 * r_tendon * T_baseline / 3.0 "Max negative tendon moment [N.m]";

  // ==================== Dynamic State Variables ====================
  Real kappa[6] "Section curvature states [1/m]";
  Real T_act[3] "Actual tendon tensions [N]";
  Real temp "Actuator winding temperature [K]";

  // ==================== Forward Kinematics ====================
  Real theta[7] "Tangent angle at each node [rad]";
  Real node_x[7] "Node x positions [m]";
  Real node_z[7] "Node z positions [m]";
  Real sec_x[6] "Section center x [m]";
  Real sec_z[6] "Section center z [m]";

  // ==================== Tip Pose (measured) ====================
  Real tip_x "Tip x position [m]";
  Real tip_z "Tip z position [m]";
  Real tip_theta "Tip tangent angle [rad]";

  // ==================== Contact Instrumentation ====================
  Real dist_obs[6] "Distance from section center to obstacle center [m]";
  Real clearance[6] "Obstacle clearance per section [m]";
  Real F_normal[6] "Normal contact force per section [N]";
  Real F_friction[6] "Friction force per section [N]";
  Real F_contact_x[6] "Contact force x-component [N]";
  Real M_contact[6] "Contact-induced bending moment per section [N.m]";
  Real min_clearance "Minimum obstacle clearance across all sections [m]";
  Real max_F_contact "Maximum contact force across all sections [N]";
  Real total_contact "Total distributed contact force (normal+friction) [N]";

  // ==================== Disturbance ====================
  Real F_tip_dist "Active lateral tip disturbance force [N]";
  Real M_tip[6] "Tip-disturbance generalized moment per section [N.m]";

  // ==================== Controller ====================
  Real stiffness_gain "Bounded stiffness scheduling gain";
  Real M_cmd "Unlimited commanded bending moment [N.m]";
  Real M_limited "Saturation-limited bending moment [N.m]";
  Real M_tendon "Realized tendon bending moment [N.m]";
  Real T_cmd[3] "Commanded tendon tensions [N]";
  Real x_des "Desired tip x trajectory [m]";
  Real z_des "Desired tip z trajectory [m]";
  Real t_norm "Normalized trajectory time";
  Real avoid_term "Obstacle avoidance feedback term [N]";

  // ==================== Error and Bounds ====================
  Real tip_error "Euclidean tip-to-target error [m]";
  Real tracking_error "Primary tracking error (valid for t >= 7.8 s) [m]";
  Real max_T_act "Maximum actual tendon tension [N]";
  Real max_kappa_abs "Maximum absolute curvature [1/m]";

equation
  // ===== Forward kinematics: constant-curvature chain =====
  theta[1] = 0;
  node_x[1] = 0;
  node_z[1] = 0;

  for j in 1:6 loop
    // Cumulative tangent angle
    theta[j+1] = theta[j] + kappa[j] * L_s;

    // Constant-curvature arc endpoint (singularity-guarded)
    node_x[j+1] = node_x[j] + (if noEvent(abs(kappa[j]) < eps) then
        L_s * sin(theta[j])
      else
        ((1.0 - cos(kappa[j] * L_s)) / kappa[j]) * cos(theta[j]) +
        (sin(kappa[j] * L_s) / kappa[j]) * sin(theta[j]));

    node_z[j+1] = node_z[j] + (if noEvent(abs(kappa[j]) < eps) then
        L_s * cos(theta[j])
      else
        -((1.0 - cos(kappa[j] * L_s)) / kappa[j]) * sin(theta[j]) +
        (sin(kappa[j] * L_s) / kappa[j]) * cos(theta[j]));

    // Section center (midpoint approximation)
    sec_x[j] = (node_x[j] + node_x[j+1]) / 2.0;
    sec_z[j] = (node_z[j] + node_z[j+1]) / 2.0;
  end for;

  // Tip pose
  tip_x = node_x[7];
  tip_z = node_z[7];
  tip_theta = theta[7];

  // ===== Contact model: fixed cylinder with friction =====
  for j in 1:6 loop
    dist_obs[j] = sqrt((sec_x[j] - x_obstacle)^2 + (sec_z[j] - z_obstacle)^2);
    clearance[j] = dist_obs[j] - r_obstacle;
    // Penalty-based normal contact (collision enabled)
    F_normal[j] = k_contact * max(0.0, r_obstacle + penetration_tol - dist_obs[j]);
    // Friction force (Coulomb, magnitude mu * N)
    F_friction[j] = mu * F_normal[j];
    // Contact force direction (radial from obstacle center)
    F_contact_x[j] = F_normal[j] * (sec_x[j] - x_obstacle) / max(dist_obs[j], eps);
    // Generalized bending moment from contact on section j
    M_contact[j] = F_contact_x[j] * L_s / 4.0;
  end for;

  // Scalar reductions for bounds
  min_clearance = min(clearance[1], min(clearance[2], min(clearance[3],
    min(clearance[4], min(clearance[5], clearance[6])))));
  max_F_contact = max(F_normal[1], max(F_normal[2], max(F_normal[3],
    max(F_normal[4], max(F_normal[5], F_normal[6])))));
  total_contact = (F_normal[1] + F_normal[2] + F_normal[3] +
    F_normal[4] + F_normal[5] + F_normal[6]) * (1.0 + mu);

  // ===== Disturbance injection: 7.2 N lateral tip load, middle third (4-8 s) =====
  F_tip_dist = if noEvent(time >= 4.0 and time <= 8.0) then F_dist_val else 0.0;

  // Generalized moment of tip disturbance on each section
  for j in 1:6 loop
    M_tip[j] = F_tip_dist * (L_total - (1.0 * j - 0.5) * L_s);
  end for;

  // ===== Section curvature dynamics (first-order) =====
  for j in 1:6 loop
    tau * der(kappa[j]) = (M_tendon + M_contact[j] + M_tip[j]) / EI_val - kappa[j];
  end for;

  // ===== Tendon moment mapping (3 tendons at 0, 120, 240 deg) =====
  M_tendon = r_tendon * (T_act[1] - 0.5 * T_act[2] - 0.5 * T_act[3]);

  // Actuator dynamics
  der(T_act[1]) = (T_cmd[1] - T_act[1]) / tau_act;
  der(T_act[2]) = (T_cmd[2] - T_act[2]) / tau_act;
  der(T_act[3]) = (T_cmd[3] - T_act[3]) / tau_act;

  // ===== Temperature model (Joule heating + cooling) =====
  der(temp) = k_thermal * (T_act[1]^2 + T_act[2]^2 + T_act[3]^2)
    - k_cool * (temp - T_amb);

  // ===== Controller: contact-aware shape control =====

  // Smooth trajectory to target
  t_norm = min(1.0, time / T_reach);
  x_des = x_target * (1.0 - cos(Modelica.Constants.pi * t_norm)) / 2.0;
  z_des = z_target * t_norm;

  // Bounded stiffness scheduling: ramp from low to high over reach time
  stiffness_gain = k_stiff_low + (k_stiff_high - k_stiff_low) * t_norm;

  // Obstacle avoidance term (increases bending when clearance is low)
  avoid_term = k_avoid * (
    max(0.0, d_safe - clearance[1]) +
    max(0.0, d_safe - clearance[2]) +
    max(0.0, d_safe - clearance[3]) +
    max(0.0, d_safe - clearance[4]) +
    max(0.0, d_safe - clearance[5]) +
    max(0.0, d_safe - clearance[6]));

  // Commanded moment: nominal + P-feedback + disturbance feedforward + avoidance
  M_cmd = stiffness_gain * (M_nominal + k_pos * (x_des - tip_x))
    - k_ff * F_tip_dist + avoid_term;

  // Moment saturation
  M_limited = max(-M_max_neg, min(M_max_pos, M_cmd));

  // Tendon tension commands (balanced mapping, clamped to [0, F_max])
  T_cmd[1] = max(0.0, min(F_max, T_baseline + 2.0 * M_limited / (3.0 * r_tendon)));
  T_cmd[2] = max(0.0, min(F_max, T_baseline - M_limited / (3.0 * r_tendon)));
  T_cmd[3] = max(0.0, min(F_max, T_baseline - M_limited / (3.0 * r_tendon)));

  // ===== Tracking error and bounds =====
  tip_error = sqrt((x_target - tip_x)^2 + (z_target - tip_z)^2);
  tracking_error = if noEvent(time >= 7.8) then tip_error else 0.0;

  max_T_act = max(abs(T_act[1]), max(abs(T_act[2]), abs(T_act[3])));
  max_kappa_abs = max(abs(kappa[1]), max(abs(kappa[2]), max(abs(kappa[3]),
    max(abs(kappa[4]), max(abs(kappa[5]), abs(kappa[6]))))));

  // ===== Initial conditions =====
initial equation
  kappa[1] = 0.0;
  kappa[2] = 0.0;
  kappa[3] = 0.0;
  kappa[4] = 0.0;
  kappa[5] = 0.0;
  kappa[6] = 0.0;
  T_act[1] = T_baseline;
  T_act[2] = T_baseline;
  T_act[3] = T_baseline;
  temp = T_amb;

end TendonSoftAvoidC;