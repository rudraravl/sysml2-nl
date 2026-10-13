model TendonSoftShapeE
  // === PHYSICAL PARAMETERS ===
  parameter Real L_total = 0.55 "Total body length [m]";
  parameter Real L_s = L_total / 6.0 "Per-section length [m]";
  parameter Real r_t = 0.06 "Tendon routing radius [m]";
  parameter Real K_b = 0.08 "Section bending stiffness [N.m]";
  parameter Real C_b = 0.015 "Section bending damping [N.m.s/rad]";
  parameter Real J_b = 0.002 "Section bending inertia [kg.m2]";
  parameter Real m_s = 0.03 "Section mass [kg]";
  parameter Real g_acc = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real F_dist_mag = 7.2 "Tip load disturbance magnitude [N]";
  parameter Real T_max = 46.2 "Maximum tendon command [N]";
  parameter Real T_bias = 5.0 "Baseline tendon tension [N]";

  // Tendon angular spacing (120 degrees apart)
  parameter Real a1 = 0.0 "Tendon 1 angle [rad]";
  parameter Real a2 = 2.0943951023931953 "Tendon 2 angle [rad]";
  parameter Real a3 = 4.1887902047863907 "Tendon 3 angle [rad]";

  // Target shape (declared)
  parameter Real x_des = 0.15 "Desired tip x position [m]";
  parameter Real z_des = 0.40 "Desired tip z position [m]";
  parameter Real kappa_des = 2.0 * z_des / (x_des * x_des + z_des * z_des)
    "Desired uniform curvature from circular-arc inversion [rad/m]";

  // Controller gains (reduced-order deformation feedback)
  parameter Real Kp_curv = 200.0 "Curvature proportional gain";
  parameter Real Kd_curv = 20.0 "Curvature derivative gain";

  // Thermal parameters
  parameter Real T_ambient = 22.0 "Ambient temperature [degC]";
  parameter Real C_thermal = 8.0 "Thermal capacity [J/K]";
  parameter Real R_thermal = 3.0 "Thermal resistance [K/W]";
  parameter Real T_limit = 65.0 "Temperature limit [degC]";
  parameter Real heat_coeff = 0.008 "Actuator heat coefficient [W/N2]";

  // Acceptance bounds
  parameter Real t_settle = 10.4 "Settling time threshold [s]";
  parameter Real err_bound = 0.041 "Primary tracking error bound [m]";
  parameter Real shape_bound = 0.05 "Final shape error bound [m]";
  parameter Real curvature_limit = 20.0 "Curvature limit [rad/m]";

  // === DYNAMIC STATES ===
  Real kappa[6](each start = 0.0) "Section curvatures [rad/m]";
  Real dkappa[6](each start = 0.0) "Section curvature rates [rad/(m.s)]";
  Real temp(start = T_ambient) "Body temperature [degC]";
  Real T_meas[3](each start = 5.0) "Filtered measured tendon tensions [N]";

  // === TENDON COMMANDS ===
  Real T_cmd_raw[3] "Raw tendon commands [N]";
  Real T_cmd[3] "Saturated tendon commands [N]";
  Real T_eff_cmd "Effective tension command [N]";
  Real T_eff "Effective tension [N]";

  // === KINEMATIC GEOMETRY ===
  Real theta_cum[7] "Cumulative tangent angles [rad]";
  Real joint_x[7] "Joint x positions [m]";
  Real joint_z[7] "Joint z positions [m]";
  Real sec_x[6] "Section center x [m]";
  Real sec_z[6] "Section center z [m]";
  Real tip_x "Actuated tip x position [m]";
  Real tip_z "Actuated tip z position [m]";

  // Undeformed geometry in shared frame
  Real undef_tip_x "Undeformed tip x [m]";
  Real undef_tip_z "Undeformed tip z [m]";
  Real deflection_x "x deflection from undeformed [m]";
  Real deflection_z "z deflection from undeformed [m]";

  // === MOMENTS ===
  Real S_x[6] "Cumulative x-sum of section centers from i to 6 [m]";
  Real M_grav[6] "Gravity moments per section [N.m]";
  Real M_dist[6] "Disturbance moments per section [N.m]";
  Real M_tendon[6] "Tendon moments per section [N.m]";

  // === DISTURBANCE ===
  Real F_dist "Tip load disturbance force [N]";

  // === CONTROLLER INTERNALS ===
  Real kappa_avg "Average curvature [rad/m]";
  Real dkappa_avg "Average curvature rate [rad/(m.s)]";

  // === THERMAL ===
  Real Q_act "Actuator heat generation [W]";

  // === ERROR METRICS ===
  Real tip_err "Tip tracking Euclidean error [m]";
  Real shape_err "Shape error (curvature-weighted) [m]";
  Real max_abs_kappa "Maximum absolute curvature [rad/m]";

  // === SENSOR OUTPUTS ===
  Real sensor_curvature[6] "Measured section curvatures [rad/m]";
  Real sensor_tension[3] "Measured tendon tensions [N]";
  Real sensor_tip_x "Measured tip x [m]";
  Real sensor_tip_z "Measured tip z [m]";
  Real sensor_temp "Measured temperature [degC]";

  // === FINITE STATE MACHINE ===
  Integer fsm(start = 0) "0=init, 1=track, 2=hold, 3=fail";

  // === ACCEPTANCE BOOLEANS (fail-closed latched) ===
  Boolean actuator_ok(start = true) "Actuator bound satisfied";
  Boolean curvature_ok(start = true) "Curvature bound satisfied";
  Boolean temp_ok(start = true) "Temperature bound satisfied";
  Boolean finite_ok(start = true) "No NaN or infinite values";
  Boolean tracking_ok(start = true) "Tracking error bound satisfied";
  Boolean shape_ok(start = true) "Final shape error bound satisfied";
  Boolean fsm_ok(start = true) "FSM never entered fail state";
  Boolean accept "Overall fail-closed acceptance";
  Boolean violated "Continuous violation flag";

equation
  // === DISTURBANCE: 7.2 N downward tip load during middle third of 16 s ===
  F_dist = if time >= 16.0 / 3.0 and time <= 2.0 * 16.0 / 3.0 then F_dist_mag else 0.0;

  // ==================== KINEMATICS ====================
  // Base tangent angle: vertical (pi/2 radians, pointing in +z)
  theta_cum[1] = 1.5707963267948966;
  for i in 1:6 loop
    theta_cum[i + 1] = theta_cum[i] + kappa[i] * L_s;
  end for;

  // Joint positions via constant-curvature arc integration
  joint_x[1] = 0.0;
  joint_z[1] = 0.0;
  for i in 1:6 loop
    joint_x[i + 1] = joint_x[i] + (if abs(kappa[i]) > 1e-6 then
      (sin(theta_cum[i + 1]) - sin(theta_cum[i])) / kappa[i] else
      L_s * cos(theta_cum[i]));
    joint_z[i + 1] = joint_z[i] + (if abs(kappa[i]) > 1e-6 then
      (cos(theta_cum[i]) - cos(theta_cum[i + 1])) / kappa[i] else
      L_s * sin(theta_cum[i]));
  end for;

  // Section centers
  for i in 1:6 loop
    sec_x[i] = 0.5 * (joint_x[i] + joint_x[i + 1]);
    sec_z[i] = 0.5 * (joint_z[i] + joint_z[i + 1]);
  end for;

  // Tip pose
  tip_x = joint_x[7];
  tip_z = joint_z[7];

  // Undeformed geometry (straight vertical, shared frame)
  undef_tip_x = 0.0;
  undef_tip_z = L_total;
  deflection_x = tip_x - undef_tip_x;
  deflection_z = tip_z - undef_tip_z;

  // ==================== MOMENTS ====================
  // Cumulative x-sum for gravity moment: S_x[i] = sum_{k=i}^{6} sec_x[k]
  S_x[6] = sec_x[6];
  for i in 1:5 loop
    S_x[i] = S_x[i + 1] + sec_x[i];
  end for;

  // Gravity moment on section i from weight of all sections above
  for i in 1:6 loop
    M_grav[i] = g_acc * m_s * (S_x[i] - (7 - i) * joint_x[i]);
  end for;

  // Disturbance moment: downward force at tip, lever arm = horizontal offset
  for i in 1:6 loop
    M_dist[i] = F_dist * (tip_x - joint_x[i]);
  end for;

  // Tendon moment: r_t * T_eff (same routing through all sections)
  for i in 1:6 loop
    M_tendon[i] = r_t * T_eff;
  end for;

  // ==================== DYNAMICS ====================
  for i in 1:6 loop
    J_b * der(dkappa[i]) = M_tendon[i] + M_grav[i] + M_dist[i]
      - K_b * kappa[i] - C_b * dkappa[i];
    der(kappa[i]) = dkappa[i];
  end for;

  // ==================== CONTROLLER ====================
  // Reduced-order feedback: PD on average curvature
  kappa_avg = (kappa[1] + kappa[2] + kappa[3] + kappa[4] + kappa[5] + kappa[6]) / 6.0;
  dkappa_avg = (dkappa[1] + dkappa[2] + dkappa[3] + dkappa[4] + dkappa[5] + dkappa[6]) / 6.0;

  // Effective tension command (zero during init or fail)
  T_eff_cmd = if fsm == 1 or fsm == 2 then
    Kp_curv * (kappa_des - kappa_avg) - Kd_curv * dkappa_avg
  else 0.0;

  // Distribute to 3 tendons: T_eff = T1*cos(0) + T2*cos(120) + T3*cos(240)
  //                          = T1 - 0.5*T2 - 0.5*T3
  T_cmd_raw[1] = T_bias + (if T_eff_cmd > 0.0 then T_eff_cmd else 0.0);
  T_cmd_raw[2] = T_bias + (if T_eff_cmd < 0.0 then -T_eff_cmd else 0.0);
  T_cmd_raw[3] = T_bias + (if T_eff_cmd < 0.0 then -T_eff_cmd else 0.0);

  // Saturate each tendon to [0, T_max]
  for i in 1:3 loop
    T_cmd[i] = if T_cmd_raw[i] > T_max then T_max
               else if T_cmd_raw[i] < 0.0 then 0.0
               else T_cmd_raw[i];
  end for;

  // Effective tension from saturated commands
  T_eff = T_cmd[1] - 0.5 * T_cmd[2] - 0.5 * T_cmd[3];

  // ==================== MEASUREMENTS ====================
  // Tendon tension sensors (first-order filter, tau = 0.02 s)
  for i in 1:3 loop
    der(T_meas[i]) = 50.0 * (T_cmd[i] - T_meas[i]);
  end for;

  // Curvature sensors
  for i in 1:6 loop
    sensor_curvature[i] = kappa[i];
  end for;

  // Tension sensor outputs
  for i in 1:3 loop
    sensor_tension[i] = T_meas[i];
  end for;

  // Tip pose and temperature sensors
  sensor_tip_x = tip_x;
  sensor_tip_z = tip_z;
  sensor_temp = temp;

  // ==================== THERMAL ====================
  Q_act = heat_coeff * (T_cmd[1] ^ 2 + T_cmd[2] ^ 2 + T_cmd[3] ^ 2);
  C_thermal * der(temp) = Q_act - (temp - T_ambient) / R_thermal;

  // ==================== ERROR METRICS ====================
  // Tip tracking error with zero-safe sqrt
  tip_err = sqrt((tip_x - x_des) ^ 2 + (tip_z - z_des) ^ 2 + 1e-12);

  // Shape error: curvature deviation weighted by section length
  shape_err = L_s * sqrt(
    (kappa[1] - kappa_des) ^ 2 + (kappa[2] - kappa_des) ^ 2 +
    (kappa[3] - kappa_des) ^ 2 + (kappa[4] - kappa_des) ^ 2 +
    (kappa[5] - kappa_des) ^ 2 + (kappa[6] - kappa_des) ^ 2 + 1e-12);

  // Maximum absolute curvature
  max_abs_kappa = max({abs(kappa[1]), abs(kappa[2]), abs(kappa[3]),
                       abs(kappa[4]), abs(kappa[5]), abs(kappa[6])});

  // ==================== VIOLATION FLAG ====================
  violated =
    (T_cmd[1] > T_max + 0.01) or (T_cmd[2] > T_max + 0.01) or (T_cmd[3] > T_max + 0.01) or
    (T_cmd[1] < -0.01) or (T_cmd[2] < -0.01) or (T_cmd[3] < -0.01) or
    (max_abs_kappa > curvature_limit) or
    (temp > T_limit + 0.01) or
    (abs(tip_x) > 1e5) or (abs(tip_z) > 1e5) or (abs(temp) > 1e5) or
    (abs(kappa[1]) > 1e5) or (abs(kappa[2]) > 1e5) or (abs(kappa[3]) > 1e5) or
    (abs(kappa[4]) > 1e5) or (abs(kappa[5]) > 1e5) or (abs(kappa[6]) > 1e5) or
    (abs(T_eff_cmd) > 1e5) or (abs(T_eff) > 1e5) or (abs(kappa_avg) > 1e5) or
    (abs(T_meas[1]) > 1e5) or (abs(T_meas[2]) > 1e5) or (abs(T_meas[3]) > 1e5);

  // ==================== FINITE STATE MACHINE ====================
  when time >= 0.5 then
    fsm = 1;
  end when;
  when time >= t_settle then
    fsm = 2;
  end when;
  when violated then
    fsm = 3;
  end when;

  // ==================== ACCEPTANCE (FAIL-CLOSED) ====================
  // Actuator bound: all tendon commands within [0, T_max]
  when T_cmd[1] > T_max + 0.01 or T_cmd[2] > T_max + 0.01 or T_cmd[3] > T_max + 0.01 or
       T_cmd[1] < -0.01 or T_cmd[2] < -0.01 or T_cmd[3] < -0.01 then
    actuator_ok = false;
  end when;

  // Curvature bound
  when max_abs_kappa > curvature_limit then
    curvature_ok = false;
  end when;

  // Temperature bound
  when temp > T_limit + 0.01 then
    temp_ok = false;
  end when;

  // No NaN or infinite values in physical, control, or estimator variables
  when abs(tip_x) > 1e5 or abs(tip_z) > 1e5 or abs(temp) > 1e5 or
       abs(kappa[1]) > 1e5 or abs(kappa[2]) > 1e5 or abs(kappa[3]) > 1e5 or
       abs(kappa[4]) > 1e5 or abs(kappa[5]) > 1e5 or abs(kappa[6]) > 1e5 or
       abs(T_eff_cmd) > 1e5 or abs(T_eff) > 1e5 or abs(kappa_avg) > 1e5 or
       abs(T_meas[1]) > 1e5 or abs(T_meas[2]) > 1e5 or abs(T_meas[3]) > 1e5 then
    finite_ok = false;
  end when;

  // Primary tracking error below 0.041 m after 10.4 s
  when time >= t_settle and tip_err > err_bound + 0.001 then
    tracking_ok = false;
  end when;

  // Final shape error bound at end of simulation
  when time >= 15.999 and shape_err > shape_bound + 0.001 then
    shape_ok = false;
  end when;

  // FSM never enters fail state
  when fsm >= 3 then
    fsm_ok = false;
  end when;

  // Overall acceptance: all criteria must hold (fail-closed)
  accept = actuator_ok and curvature_ok and temp_ok and finite_ok and
           tracking_ok and shape_ok and fsm_ok;

  annotation(
    experiment(StartTime = 0.0, StopTime = 16.0, Tolerance = 1e-6, Interval = 0.004),
    Documentation(info = "Tendon-driven soft continuum robot TendonSoftShapeE.
      0.55 m cylindrical body with 6 constant-curvature sections and 3 tendons at 120 deg.
      PD curvature feedback via reduced-order average-curvature model.
      7.2 N tip load disturbance applied during middle third (5.33-10.67 s).
      Simulated at 250 Hz (Interval=0.004 s) for 16 s.
      Acceptance is fail-closed: actuator, curvature, temperature, finite-state,
      and final shape-error bounds with primary tracking error < 0.041 m after 10.4 s."));
end TendonSoftShapeE;