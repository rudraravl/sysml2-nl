model TendonSoftAvoidB
  "Soft continuum arm navigating around a fixed obstacle with bounded contact and stiffness scheduling"

  // ============ Physical Parameters ============
  parameter Real L_body = 0.55 "Body length [m]";
  parameter Real L_seg = L_body / 6.0 "Section length [m]";
  parameter Real body_r = 0.02 "Body cross-section radius [m]";
  parameter Real r_tendon = 0.018 "Tendon moment arm [m]";
  parameter Real T_max = 34.4 "Max tendon tension command [N]";
  parameter Real T_min = 0.0 "Min tendon tension [N]";
  parameter Real F_preload_nom = 12.0 "Nominal tendon preload [N]";
  parameter Real mu_obstacle = 0.55 "Obstacle friction coefficient [dimensionless]";

  // ============ Obstacle ============
  parameter Real obs_x = 0.25 "Obstacle center x [m]";
  parameter Real obs_y = 0.08 "Obstacle center y [m]";
  parameter Real obs_r = 0.03 "Obstacle radius [m]";

  // ============ Target ============
  parameter Real x_target = 0.50 "Target x [m]";
  parameter Real y_target = 0.15 "Target y [m]";

  // ============ Section Dynamics ============
  parameter Real J_sec = 0.002 "Section bending inertia [kg.m^2]";
  parameter Real k_sec_base = 0.3 "Base section stiffness [N.m/rad]";
  parameter Real c_sec = 0.20 "Section damping [N.m.s/rad]";

  // ============ Contact ============
  parameter Real k_contact = 5000.0 "Contact stiffness [N/m]";

  // ============ Disturbance ============
  parameter Real F_dist = 5.6 "Lateral tip disturbance magnitude [N]";
  parameter Real t_dist_start = 10.0 / 3.0 "Disturbance start [s]";
  parameter Real t_dist_end = 20.0 / 3.0 "Disturbance end [s]";
  parameter Real t_dist_ramp = 0.05 "Disturbance ramp time [s]";

  // ============ Controller ============
  parameter Real Kp_tip = 70.0 "Tip proportional gain [N/m]";
  parameter Real Kd_tip = 3.0 "Tip derivative gain [N.s/m]";
  parameter Real K_int = 0.5 "Integral gain [N/(m.s)]";
  parameter Real tau_int = 100.0 "Integral leak time constant [s]";
  parameter Real k_stiff_min = 1.0 "Min stiffness multiplier";
  parameter Real k_stiff_max = 4.0 "Max stiffness multiplier";

  // ============ Thermal ============
  parameter Real T_ambient = 293.15 "Ambient temperature [K]";
  parameter Real C_thermal = 100.0 "Thermal capacitance [J/K]";
  parameter Real R_thermal = 2.0 "Thermal resistance [K/W]";

  // ============ Bounds ============
  parameter Real bound_actuator = 34.4 "Actuator bound [N]";
  parameter Real bound_deformation = 10.0 "Deformation bound [rad/m]";
  parameter Real bound_contact = 100.0 "Contact force bound [N]";
  parameter Real bound_temperature = 350.0 "Temperature bound [K]";
  parameter Real bound_tip_error = 0.048 "Required tip error [m]";
  parameter Real t_settling = 6.5 "Settling time [s]";

  // ============ Dynamic States ============
  Real kappa[6] "Section curvature [rad/m]";
  Real kappa_dot[6] "Section curvature rate [rad/(m.s)]";
  Real T_meas[3] "Measured tendon tensions [N]";
  Real e_int "Integral of tip y-error with leak [m.s]";
  Real temp_est "Estimated actuator temperature [K]";

  // ============ Kinematics ============
  Real x_node[7] "Node x positions [m]";
  Real y_node[7] "Node y positions [m]";
  Real theta_node[7] "Node tangent angles [rad]";
  Real x_tip "Tip x [m]";
  Real y_tip "Tip y [m]";

  // ============ Contact ============
  Real cdx[6] "Contact x-distance [m]";
  Real cdy[6] "Contact y-distance [m]";
  Real cdist[6] "Contact distance [m]";
  Real clearance[6] "Clearance per section [m]";
  Real cpen[6] "Penetration depth [m]";
  Real Fn[6] "Normal contact force [N]";
  Real Fcx[6] "Contact force x [N]";
  Real Fcy[6] "Contact force y [N]";
  Real Mc[6] "Contact moment per section [N.m]";
  Real v_tan[6] "Tangential velocity proxy [m/s]";

  // ============ Disturbance ============
  Real F_lateral "Lateral tip load [N]";
  Real Md[6] "Disturbance moment per section [N.m]";

  // ============ Actuator ============
  Real T_cmd[3] "Commanded tendon tensions [N]";
  Real T_raw[3] "Unsaturated tensions [N]";
  Real M_tendon "Tendon bending moment [N.m]";

  // ============ Controller ============
  Real e_x "Tip x-error [m]";
  Real e_y "Tip y-error [m]";
  Real tip_error "Euclidean tip error [m]";
  Real tip_vel_est "Estimated tip y-velocity [m/s]";
  Real M_des "Desired bending moment [N.m]";
  Real F_preload "Tendon preload [N]";
  Real k_sched "Scheduled stiffness multiplier";
  Real k_eff "Effective section stiffness [N.m/rad]";
  Real prox_factor "Contact proximity factor";
  Real conv_factor "Convergence factor";
  Real smax "Smooth max of prox and conv";

  // ============ Sensors ============
  Real actuator_norm "Actuator command norm [N]";
  Real deformation_norm "Deformation norm [rad/m]";
  Real contact_force_norm "Contact force norm [N]";
  Real clearance_min "Minimum clearance [m]";
  Real power_dissip "Power dissipation [W]";

  // ============ Bound Flags ============
  Boolean b_act "Actuator bound OK";
  Boolean b_def "Deformation bound OK";
  Boolean b_con "Contact force bound OK";
  Boolean b_tmp "Temperature bound OK";
  Boolean b_clr "Clearance bound OK";
  Boolean b_tip "Tip error bound OK";

equation
  // ===== Forward Kinematics (6 constant-curvature sections) =====
  x_node[1] = 0.0;
  y_node[1] = 0.0;
  theta_node[1] = 0.0;

  for i in 1:6 loop
    theta_node[i+1] = theta_node[i] + kappa[i] * L_seg;
    x_node[i+1] = x_node[i] + L_seg * cos(theta_node[i] + 0.5 * kappa[i] * L_seg);
    y_node[i+1] = y_node[i] + L_seg * sin(theta_node[i] + 0.5 * kappa[i] * L_seg);
  end for;

  x_tip = x_node[7];
  y_tip = y_node[7];

  // ===== Contact Model (penalty + Coulomb friction) =====
  for i in 1:6 loop
    cdx[i] = 0.5 * (x_node[i] + x_node[i+1]) - obs_x;
    cdy[i] = 0.5 * (y_node[i] + y_node[i+1]) - obs_y;
    cdist[i] = sqrt(cdx[i] * cdx[i] + cdy[i] * cdy[i] + 1e-12);
    clearance[i] = cdist[i] - obs_r - body_r;
    // Smooth penetration: zero when no contact, positive when penetrating
    cpen[i] = 0.5 * (sqrt(clearance[i] * clearance[i] + 1e-10) - clearance[i]);
    // Normal penalty force
    Fn[i] = k_contact * cpen[i];
    // Tangential velocity proxy from curvature rate
    v_tan[i] = kappa_dot[i] * L_seg;
    // Total contact force: normal + friction (tangent perpendicular to normal)
    Fcx[i] = (Fn[i] / (cdist[i] + 1e-12)) *
             (cdx[i] + mu_obstacle * cdy[i] * tanh(v_tan[i] / 0.001));
    Fcy[i] = (Fn[i] / (cdist[i] + 1e-12)) *
             (cdy[i] - mu_obstacle * cdx[i] * tanh(v_tan[i] / 0.001));
    // Contact moment on section i about its base node
    Mc[i] = (0.5 * (x_node[i] + x_node[i+1]) - x_node[i]) * Fcy[i]
          - (0.5 * (y_node[i] + y_node[i+1]) - y_node[i]) * Fcx[i];
  end for;

  // ===== Disturbance (smooth pulse in -y during middle third) =====
  F_lateral = -F_dist
              * 0.5 * (1.0 + tanh((time - t_dist_start) / t_dist_ramp))
              * 0.5 * (1.0 - tanh((time - t_dist_end) / t_dist_ramp));

  for i in 1:6 loop
    Md[i] = F_lateral * (x_tip - x_node[i]);
  end for;

  // ===== Tendon-to-Moment Mapping (3 tendons at 0, 120, 240 deg) =====
  // Bending about z: M = r * sin(120) * T2 + r * sin(240) * T3
  //               = r * 0.8660254 * (T2 - T3)
  M_tendon = r_tendon * 0.8660254 * (T_meas[2] - T_meas[3]);

  // ===== Stiffness Scheduling =====
  prox_factor = 0.5 * (1.0 + tanh(50.0 * (0.002 - clearance_min)));
  conv_factor = 0.5 * (1.0 + tanh(50.0 * (0.04 - tip_error)));
  smax = 0.5 * (prox_factor + conv_factor +
               sqrt((prox_factor - conv_factor) * (prox_factor - conv_factor) + 1e-8));
  k_sched = k_stiff_min + (k_stiff_max - k_stiff_min) * smax;
  k_eff = k_sec_base * k_sched;

  // ===== Section Dynamics =====
  for i in 1:6 loop
    J_sec * der(kappa_dot[i]) = M_tendon + Mc[i] + Md[i]
                                - k_eff * kappa[i] - c_sec * kappa_dot[i];
    der(kappa[i]) = kappa_dot[i];
  end for;

  // ===== Tendon Measurement Filter (first-order, tau = 10 ms) =====
  for j in 1:3 loop
    der(T_meas[j]) = (T_cmd[j] - T_meas[j]) / 0.01;
  end for;

  // ===== Contact-Aware Shape Controller =====
  e_x = x_target - x_tip;
  e_y = y_target - y_tip;
  tip_error = sqrt(e_x * e_x + e_y * e_y + 1e-12);

  // Tip velocity estimate from curvature rates (linearized Jacobian)
  tip_vel_est = L_seg * L_seg * (5.5 * kappa_dot[1] + 4.5 * kappa_dot[2] + 3.5 * kappa_dot[3]
                                + 2.5 * kappa_dot[4] + 1.5 * kappa_dot[5] + 0.5 * kappa_dot[6]);

  // Leaky integrator for steady-state error correction
  der(e_int) = e_y - e_int / tau_int;

  // PD + integral moment command
  M_des = Kp_tip * e_y + K_int * e_int - Kd_tip * tip_vel_est;

  // Preload ensures non-negative tensions (tendons pull only)
  F_preload = min(F_preload_nom + 2.0 * abs(M_des) / r_tendon, 3.0 * T_max);

  // Pseudo-inverse: [F_axial; M_bend] = A * [T1; T2; T3], T = A^+ * [F_preload; M_des]
  // A = [1, 1, 1; 0, 0.866, -0.866], A^+ = A^T * (A*A^T)^{-1}
  T_raw[1] = F_preload / 3.0;
  T_raw[2] = F_preload / 3.0 + M_des / (r_tendon * 1.7320508);
  T_raw[3] = F_preload / 3.0 - M_des / (r_tendon * 1.7320508);

  // Bounded saturation
  for j in 1:3 loop
    T_cmd[j] = if T_raw[j] > T_max then T_max
               else if T_raw[j] < T_min then T_min
               else T_raw[j];
  end for;

  // ===== Sensor Aggregation =====
  actuator_norm = sqrt(T_cmd[1] * T_cmd[1] + T_cmd[2] * T_cmd[2] + T_cmd[3] * T_cmd[3] + 1e-12);
  deformation_norm = sqrt(kappa[1] * kappa[1] + kappa[2] * kappa[2] + kappa[3] * kappa[3]
                        + kappa[4] * kappa[4] + kappa[5] * kappa[5] + kappa[6] * kappa[6] + 1e-12);
  contact_force_norm = sqrt(Fn[1] * Fn[1] + Fn[2] * Fn[2] + Fn[3] * Fn[3]
                          + Fn[4] * Fn[4] + Fn[5] * Fn[5] + Fn[6] * Fn[6] + 1e-12);
  clearance_min = min(min(min(min(min(clearance[1], clearance[2]), clearance[3]), clearance[4]), clearance[5]), clearance[6]);

  // Thermal model (Joule heating from section damping)
  power_dissip = c_sec * (kappa_dot[1] * kappa_dot[1] + kappa_dot[2] * kappa_dot[2]
                        + kappa_dot[3] * kappa_dot[3] + kappa_dot[4] * kappa_dot[4]
                        + kappa_dot[5] * kappa_dot[5] + kappa_dot[6] * kappa_dot[6]);
  C_thermal * der(temp_est) = power_dissip - (temp_est - T_ambient) / R_thermal;

  // ===== Bound Assertions =====
  b_act = actuator_norm <= bound_actuator * sqrt(3.0) + 1e-6;
  b_def = deformation_norm <= bound_deformation;
  b_con = contact_force_norm <= bound_contact;
  b_tmp = temp_est <= bound_temperature;
  b_clr = clearance_min >= -0.005;
  b_tip = (time < t_settling) or (tip_error <= bound_tip_error);

  assert(b_act, "Actuator bound exceeded");
  assert(b_def, "Deformation bound exceeded");
  assert(b_con, "Contact force bound exceeded");
  assert(b_tmp, "Temperature bound exceeded");
  assert(b_tip, "Tip error bound exceeded after settling time");

initial equation
  kappa[1] = 0.0; kappa[2] = 0.0; kappa[3] = 0.0;
  kappa[4] = 0.0; kappa[5] = 0.0; kappa[6] = 0.0;
  kappa_dot[1] = 0.0; kappa_dot[2] = 0.0; kappa_dot[3] = 0.0;
  kappa_dot[4] = 0.0; kappa_dot[5] = 0.0; kappa_dot[6] = 0.0;
  T_meas[1] = F_preload_nom / 3.0;
  T_meas[2] = F_preload_nom / 3.0;
  T_meas[3] = F_preload_nom / 3.0;
  e_int = 0.0;
  temp_est = T_ambient;

  annotation(
    experiment(StartTime = 0.0, StopTime = 10.0, Tolerance = 1e-6, Interval = 0.01),
    Documentation(info = "TendonSoftAvoidB: 6-section continuum soft arm (0.55 m) with 3 tendons at 120 deg "
      "spacing navigating around a fixed cylinder obstacle (friction coeff 0.55). Contact-aware shape control "
      "with bounded stiffness scheduling. 5.6 N lateral tip disturbance during middle third of 10 s mission at "
      "100 Hz. Measures actuator state (T_meas), distributed contact force (Fn, Fcx, Fcy), section deformation "
      "(kappa), and tip pose (x_tip, y_tip). Synchronized state, command, and sensor traces retained. "
      "Unknown facts not stated in the requirement are treated as unknown.")
  );
end TendonSoftAvoidB;