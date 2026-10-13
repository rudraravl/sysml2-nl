model TendonSoftAvoidB
  // ============================================================
  // TendonSoftAvoidB: Soft robotic continuum body (0.55 m) with
  // 6 constant-curvature sections, 3 tendons at 120 deg spacing.
  // Contact-aware shape control with bounded stiffness scheduling.
  // Mission: reach target around fixed obstacle, bounded incidental
  // contact, then stiffen/hold shape. 100 Hz for 10 s.
  // ============================================================

  // ===== Physical Parameters =====
  parameter Real L_body = 0.55 "Total continuum body length [m]";
  parameter Real L_sec = L_body / 6.0 "Per-section length [m]";
  parameter Real r_tendon = 0.012 "Tendon routing radius [m]";
  parameter Real r_body = 0.008 "Body cross-section radius [m]";
  parameter Real EI = 0.040 "Flexural rigidity [N.m^2]";
  parameter Real T_max = 34.4 "Maximum allowed tendon command [N]";
  parameter Real T_bias = 14.0 "Pre-tension bias [N]";
  parameter Real mu_obstacle = 0.55 "Obstacle friction coefficient [-]";
  parameter Real r_obstacle = 0.030 "Obstacle cylinder radius [m]";
  parameter Real x_obstacle = 0.25 "Obstacle center x [m]";
  parameter Real y_obstacle = 0.04 "Obstacle center y [m]";
  parameter Real x_target = 0.42 "Target x [m]";
  parameter Real y_target = 0.20 "Target y [m]";
  parameter Real tau_curv = 0.05 "Curvature response time constant [s]";
  parameter Real tau_act = 0.02 "Actuator response time constant [s]";
  parameter Real k_contact = 500.0 "Contact spring stiffness [N/m]";
  parameter Real F_dist = 5.6 "Lateral tip disturbance force [N]";
  parameter Real temp_amb = 293.15 "Ambient temperature [K]";
  parameter Real thermal_R = 4.0 "Thermal resistance [K/W]";
  parameter Real thermal_C = 80.0 "Thermal capacitance [J/K]";
  parameter Real k_thermal = 0.0008 "Actuator thermal coupling [W/N^2]";
  parameter Real d_safe = 0.008 "Safe clearance distance [m]";
  parameter Real K_track_y = 80.0 "Y-tracking feedback gain";
  parameter Real K_track_x = 40.0 "X-tracking feedback gain";
  parameter Real K_avoid = 10.0 "Obstacle avoidance gain";

  // ===== Bound Parameters =====
  parameter Real T_bound = 34.4 "Actuator tension bound [N]";
  parameter Real kappa_bound = 8.0 "Curvature deformation bound [1/m]";
  parameter Real F_contact_bound = 25.0 "Contact force bound [N]";
  parameter Real temp_bound = 340.0 "Temperature bound [K]";
  parameter Real clearance_bound = -0.003 "Minimum clearance bound [m]";
  parameter Real tip_error_bound = 0.048 "Tip error bound after 6.5 s [m]";

  // ===== Dynamic States =====
  Real kappa[6](each start = 0.0) "Section curvatures [1/m]";
  Real T_meas[3](each start = T_bias) "Measured tendon tensions [N]";
  Real temp(start = temp_amb) "Actuator temperature [K]";

  // ===== Forward Kinematics =====
  Real x_sec[7] "Section node x [m]";
  Real y_sec[7] "Section node y [m]";
  Real theta_sec[7] "Section node tangent angle [rad]";
  Real dtheta[6] "Section arc angle [rad]";
  Real dx_local[6] "Local x displacement [m]";
  Real dy_local[6] "Local y displacement [m]";
  Real x_tip "Tip x [m]";
  Real y_tip "Tip y [m]";
  Real theta_tip "Tip angle [rad]";

  // ===== Contact =====
  Real mid_x[6] "Section midpoint x [m]";
  Real mid_y[6] "Section midpoint y [m]";
  Real d_obs_sec[6] "Distance to obstacle center [m]";
  Real contact_normal_y[6] "Contact normal y-component [-]";
  Real penetration_sec[6] "Penetration depth [m]";
  Real F_contact_sec[6] "Section contact force [N]";
  Real F_contact_total "Total distributed contact force [N]";
  Real F_friction_total "Total friction force [N]";
  Real clearance "Minimum obstacle clearance [m]";
  Boolean in_contact "Contact flag";

  // ===== Control =====
  Real kappa_ff "Feedforward average curvature [1/m]";
  Real kappa_des[6] "Desired section curvatures [1/m]";
  Real T_cmd[3] "Commanded tendon tensions [N]";
  Real T_delta[3] "Tension deltas from bias [N]";
  Real tracking_error "Primary tip tracking error [m]";
  Real error_x "X tracking error [m]";
  Real error_y "Y tracking error [m]";
  Real stiffness_factor "Bounded stiffness scheduling factor";
  Real K_shape "Effective shape control gain";
  Real phase "Mission phase indicator";
  Real F_lateral "Lateral tip disturbance [N]";
  Real lever_dist[6] "Lever arm from section midpoint to tip [m]";

  // ===== Coupling Weights =====
  Real w[6, 3] "Tendon-to-section curvature coupling";
  Real wy[6] "Y-curvature sensitivity weights";
  Real wx[6] "X-curvature sensitivity weights";

  // ===== Bounds Monitoring =====
  Real max_T "Maximum measured tension [N]";
  Real abs_kappa[6] "Absolute curvature values [1/m]";
  Real max_kappa "Maximum curvature magnitude [1/m]";
  Real max_F_contact "Maximum section contact force [N]";
  Real final_tip_error "Final tip error [m]";

equation
  // ===== Tendon-to-curvature coupling weights =====
  // Tendon 1 at 0 deg (positive y bending), Tendon 2 at 120 deg, Tendon 3 at 240 deg
  w[1,1] = 1.2;  w[1,2] = -0.6;  w[1,3] = -0.6;
  w[2,1] = 1.0;  w[2,2] = -0.5;  w[2,3] = -0.5;
  w[3,1] = 0.8;  w[3,2] = -0.4;  w[3,3] = -0.4;
  w[4,1] = 0.6;  w[4,2] = -0.3;  w[4,3] = -0.3;
  w[5,1] = 0.4;  w[5,2] = -0.2;  w[5,3] = -0.2;
  w[6,1] = 0.2;  w[6,2] = -0.1;  w[6,3] = -0.1;

  // Tracking sensitivity weights (proximal sections have more authority)
  wy[1] = 0.30; wy[2] = 0.25; wy[3] = 0.20; wy[4] = 0.15; wy[5] = 0.07; wy[6] = 0.03;
  wx[1] = -0.15; wx[2] = -0.12; wx[3] = -0.10; wx[4] = -0.07; wx[5] = -0.04; wx[6] = -0.02;

  // ===== Base boundary conditions =====
  x_sec[1] = 0.0;
  y_sec[1] = 0.0;
  theta_sec[1] = 0.0;

  // ===== Forward kinematics (constant-curvature per section) =====
  for i in 1:6 loop
    dtheta[i] = kappa[i] * L_sec;
    dx_local[i] = if abs(kappa[i]) > 1e-8 then sin(dtheta[i]) / kappa[i] else L_sec;
    dy_local[i] = if abs(kappa[i]) > 1e-8 then (1.0 - cos(dtheta[i])) / kappa[i] else 0.0;
    x_sec[i+1] = x_sec[i] + dx_local[i] * cos(theta_sec[i]) - dy_local[i] * sin(theta_sec[i]);
    y_sec[i+1] = y_sec[i] + dx_local[i] * sin(theta_sec[i]) + dy_local[i] * cos(theta_sec[i]);
    theta_sec[i+1] = theta_sec[i] + dtheta[i];
  end for;

  x_tip = x_sec[7];
  y_tip = y_sec[7];
  theta_tip = theta_sec[7];

  // ===== Tracking error =====
  error_x = x_target - x_tip;
  error_y = y_target - y_tip;
  tracking_error = sqrt(error_x*error_x + error_y*error_y);
  final_tip_error = tracking_error;

  // ===== Mission phases =====
  // Phase 1: 0-3.33 s (approach, compliant)
  // Phase 2: 3.33-6.67 s (contact + disturbance, moderate stiffness)
  // Phase 3: 6.67-10 s (hold/stiffen, high stiffness)
  phase = if time < 3.33 then 1.0 else if time < 6.67 then 2.0 else 3.0;

  // ===== Bounded stiffness scheduling =====
  stiffness_factor = if phase < 1.5 then 0.6 elseif phase < 2.5 then 1.2 else 2.5;
  K_shape = stiffness_factor;

  // ===== Disturbance injection (middle third) =====
  F_lateral = if time >= 3.33 and time <= 6.67 then F_dist else 0.0;

  // ===== Lever arms from section midpoint to tip =====
  for i in 1:6 loop
    lever_dist[i] = L_body - (i - 0.5) * L_sec;
  end for;

  // ===== Contact detection and force model =====
  for i in 1:6 loop
    mid_x[i] = (x_sec[i] + x_sec[i+1]) / 2.0;
    mid_y[i] = (y_sec[i] + y_sec[i+1]) / 2.0;
    d_obs_sec[i] = sqrt((mid_x[i] - x_obstacle)*(mid_x[i] - x_obstacle) + (mid_y[i] - y_obstacle)*(mid_y[i] - y_obstacle));
    contact_normal_y[i] = if d_obs_sec[i] > 1e-8 then (mid_y[i] - y_obstacle) / d_obs_sec[i] else 0.0;
    penetration_sec[i] = max(0.0, (r_obstacle + r_body) - d_obs_sec[i]);
    F_contact_sec[i] = k_contact * penetration_sec[i];
  end for;

  F_contact_total = sum(F_contact_sec);
  F_friction_total = mu_obstacle * F_contact_total;
  clearance = min(d_obs_sec) - (r_obstacle + r_body);
  in_contact = F_contact_total > 0.001;

  // ===== Feedforward curvature (safe atan2 branch) =====
  kappa_ff = if (abs(x_target) + abs(y_target)) > 1e-8 then 2.0 * atan2(y_target, x_target) / L_body else 0.0;

  // ===== Contact-aware shape controller =====
  for i in 1:6 loop
    kappa_des[i] = kappa_ff
      + K_shape * (K_track_y * error_y * wy[i] + K_track_x * error_x * wx[i])
      + K_avoid * (if clearance < d_safe then (d_safe - clearance) * wy[i] else 0.0);
  end for;

  // ===== Tension command allocation (bounded to [0, T_max]) =====
  for j in 1:3 loop
    T_delta[j] = (EI / r_tendon) * (kappa_des[1]*w[1,j] + kappa_des[2]*w[2,j] + kappa_des[3]*w[3,j]
                                    + kappa_des[4]*w[4,j] + kappa_des[5]*w[5,j] + kappa_des[6]*w[6,j]) / 6.0;
    T_cmd[j] = max(0.0, min(T_max, T_bias + T_delta[j]));
  end for;

  // ===== Actuator dynamics =====
  for j in 1:3 loop
    der(T_meas[j]) = (T_cmd[j] - T_meas[j]) / tau_act;
  end for;

  // ===== Curvature dynamics =====
  for i in 1:6 loop
    der(kappa[i]) = (
      (r_tendon / EI) * (w[i,1]*(T_meas[1]-T_bias) + w[i,2]*(T_meas[2]-T_bias) + w[i,3]*(T_meas[3]-T_bias))
      + F_lateral * lever_dist[i] / EI
      + F_contact_sec[i] * contact_normal_y[i] * L_sec / (2.0 * EI)
      - kappa[i]
    ) / tau_curv;
  end for;

  // ===== Temperature model (actuator power dissipation) =====
  der(temp) = (k_thermal * (T_meas[1]*T_meas[1] + T_meas[2]*T_meas[2] + T_meas[3]*T_meas[3])
    - (temp - temp_amb) / thermal_R) / thermal_C;

  // ===== Bounds monitoring =====
  max_T = max(T_meas);
  for i in 1:6 loop
    abs_kappa[i] = abs(kappa[i]);
  end for;
  max_kappa = max(abs_kappa);
  max_F_contact = max(F_contact_sec);

  annotation(
    experiment(StartTime = 0, StopTime = 10, Tolerance = 1e-6, Interval = 0.01),
    Documentation(info = "TendonSoftAvoidB: 6-section, 3-tendon (120 deg spacing) continuum body. "
      "Contact-aware shape control with bounded stiffness scheduling. "
      "Phase 1 (0-3.33s): approach, Phase 2 (3.33-6.67s): contact + 5.6 N tip disturbance, "
      "Phase 3 (6.67-10s): hold/stiffen. Output at 100 Hz. "
      "Monitors: actuator tension, curvature deformation, contact force, temperature, "
      "obstacle clearance, and tip tracking error bounds.")
  );
end TendonSoftAvoidB;