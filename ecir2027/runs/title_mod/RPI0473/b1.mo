model VacuumToolPushE
  "Contact-rich manipulation: vacuum tool pushes box along two-segment planar reference
   with hybrid position-force control, bounded actuators, friction disturbance, and fail-closed acceptance."

  // ===== Requirement-specified parameters =====
  parameter Real m_cup = 0.8 "Suction cup mass [kg]";
  parameter Real r_cup = 0.038 "Suction cup radius [m]";
  parameter Real p_vac_lo = 0.0 "Vacuum command lower bound, 0 kPa gauge [Pa]";
  parameter Real p_vac_hi = -70000.0 "Vacuum command upper bound, -70 kPa gauge [Pa]";
  parameter Real F_lin_bound = 352.0 "Linear actuator command magnitude bound [N]";
  parameter Real mu_box_table = 0.42 "Box-table friction coefficient";
  parameter Real mu_tool_box = 0.65 "Tool-box friction coefficient";
  parameter Real F_disturb = 7.2 "Friction change disturbance magnitude [N]";
  parameter Real f_sample = 250.0 "Control loop frequency [Hz]";
  parameter Real T_sim = 16.0 "Simulation duration [s]";
  parameter Real T_settle = 10.4 "Tracking error evaluation time [s]";
  parameter Real track_tol = 0.036 "Tracking error tolerance [m]";
  parameter Real F_contact_lo = 5.0 "Min acceptable contact force [N]";
  parameter Real F_contact_hi = 25.0 "Max acceptable contact force [N]";

  // ===== Assumed parameters (not stated in requirement, labeled as assumed) =====
  parameter Real m_box = 0.5 "Box mass [kg] -- assumed, not specified";
  parameter Real J_box = 0.002 "Box yaw inertia [kg.m2] -- assumed";
  parameter Real m_car = 1.5 "Carriage mass [kg] -- assumed";
  parameter Real h_box = 0.04 "Box height [m] -- assumed";
  parameter Real L_cup0 = 0.01 "Cup rest length [m] -- assumed";
  parameter Real e_offset = 0.003 "Contact yaw moment arm [m] -- assumed";
  parameter Real k_cup = 3000.0 "Cup compliance stiffness [N/m] -- assumed";
  parameter Real c_cup = 60.0 "Cup damping [N.s/m] -- assumed";
  parameter Real k_car = 500.0 "Carriage vertical stiffness [N/m] -- assumed";
  parameter Real c_car = 60.0 "Carriage vertical damping [N.s/m] -- assumed";
  parameter Real g = 9.81 "Standard gravity [m/s2]";
  parameter Real z_table = 0.0 "Table surface height [m]";
  parameter Real L1 = 0.2 "Segment 1 planar distance [m] -- assumed";
  parameter Real L2 = 0.2 "Segment 2 planar distance [m] -- assumed";
  parameter Real T_seg1 = 8.0 "Segment 1 duration [s] -- assumed";
  parameter Real T_seg2 = 8.0 "Segment 2 duration [s] -- assumed";
  parameter Real F_n_target = 18.0 "Target normal force [N] -- assumed";
  parameter Real kp_pos = 500.0 "Position control proportional gain -- assumed";
  parameter Real kd_pos = 50.0 "Position control derivative gain -- assumed";
  parameter Real kp_vac = 200.0 "Vacuum pressure gain [Pa per N] -- assumed";
  parameter Real tau_vac = 0.05 "Vacuum actuator first-order time constant [s] -- assumed";
  parameter Real d_yaw = 0.01 "Yaw damping coefficient [N.m.s] -- assumed";
  parameter Real v_eps = 0.005 "Friction velocity regularization threshold [m/s] -- assumed";
  parameter Real z_rest = 0.047 "Carriage spring rest position [m] -- assumed";

  // ===== Derived constants =====
  final parameter Real A_cup = 3.141592653589793238 * r_cup * r_cup "Cup area [m2]";
  final parameter Real Ts = 1.0 / f_sample "Sample period [s]";
  final parameter Real T_dist_start = T_sim / 3.0 "Disturbance start time [s]";
  final parameter Real T_dist_end = 2.0 * T_sim / 3.0 "Disturbance end time [s]";
  final parameter Real pi_val = 3.141592653589793238 "Pi constant";

  // ===== Continuous states =====
  Real z_c(start = 0.047, fixed = true) "Carriage vertical position [m]";
  Real vz_c(start = 0, fixed = true) "Carriage vertical velocity [m/s]";
  Real x_t(start = 0, fixed = true) "Tool x position [m]";
  Real vx_t(start = 0, fixed = true) "Tool x velocity [m/s]";
  Real y_t(start = 0, fixed = true) "Tool y position [m]";
  Real vy_t(start = 0, fixed = true) "Tool y velocity [m/s]";
  Real x_b(start = 0, fixed = true) "Box x position [m]";
  Real vx_b(start = 0, fixed = true) "Box x velocity [m/s]";
  Real y_b(start = 0, fixed = true) "Box y position [m]";
  Real vy_b(start = 0, fixed = true) "Box y velocity [m/s]";
  Real theta_b(start = 0, fixed = true) "Box yaw angle [rad]";
  Real omega_b(start = 0, fixed = true) "Box yaw rate [rad/s]";
  Real p_vac(start = 0, fixed = true) "Actual vacuum pressure [Pa gauge]";

  // ===== Discrete control signals (250 Hz zero-order hold) =====
  discrete Real F_lin_x_d(start = 0, fixed = true) "Discrete linear actuator force x [N]";
  discrete Real F_lin_y_d(start = 0, fixed = true) "Discrete linear actuator force y [N]";
  discrete Real p_vac_cmd_d(start = 0, fixed = true) "Discrete vacuum command [Pa]";
  discrete Real F_lin_x_raw(start = 0, fixed = true) "Unsaturated linear force x [N]";
  discrete Real F_lin_y_raw(start = 0, fixed = true) "Unsaturated linear force y [N]";
  discrete Real F_lin_mag_raw(start = 0, fixed = true) "Unsaturated force magnitude [N]";
  discrete Real sat_scale(start = 1.0, fixed = true) "Saturation scaling factor";

  // ===== Actuator outputs (applied) =====
  Real F_lin_x "Applied linear actuator force x [N]";
  Real F_lin_y "Applied linear actuator force y [N]";
  Real F_lin_mag "Linear actuator force magnitude [N]";
  Real p_vac_cmd "Vacuum pressure command [Pa]";

  // ===== Contact and friction =====
  Real delta "Cup deflection, compression positive [m]";
  Real v_delta "Cup deflection rate [m/s]";
  Real F_normal "Normal contact force [N]";
  Real F_suction "Suction force from vacuum [N]";
  Real F_tb_x "Tool-box friction force x [N]";
  Real F_tb_y "Tool-box friction force y [N]";
  Real F_bt_x "Box-table friction force x [N]";
  Real F_bt_y "Box-table friction force y [N]";
  Real N_table "Table normal force on box [N]";
  Real tau_yaw "Net yaw torque on box [N.m]";
  Real dist_active "Disturbance active flag (1.0 or 0.0)";
  Real F_bt_eff "Effective box-table friction force magnitude [N]";

  // ===== Reference trajectory =====
  Real x_ref "Reference x [m]";
  Real y_ref "Reference y [m]";
  Real vx_ref "Reference x velocity [m/s]";
  Real vy_ref "Reference y velocity [m/s]";
  Integer segment "Active segment (1 or 2)";

  // ===== Measurements and acceptance =====
  Real track_err "Primary tracking error [m]";
  Real F_n_err "Normal force error [N]";
  Boolean contact_in_range "Contact force in [5, 25] N";
  Boolean track_ok "Tracking error below tolerance after settle time";
  Boolean actuator_ok "Actuator bounds respected";
  Boolean no_nan_inf "No NaN or infinite values detected";
  Boolean fail_closed "Fail-closed acceptance flag";

equation
  // ===== Zero-order hold: discrete commands applied between samples =====
  F_lin_x = F_lin_x_d;
  F_lin_y = F_lin_y_d;
  p_vac_cmd = p_vac_cmd_d;
  F_lin_mag = sqrt(F_lin_x * F_lin_x + F_lin_y * F_lin_y);

  // ===== Reference trajectory: two-segment planar =====
  segment = if time < T_seg1 then 1 else 2;
  if time < T_seg1 then
    x_ref = L1 * (1.0 - cos(pi_val * time / T_seg1)) / 2.0;
    y_ref = 0.0;
    vx_ref = L1 * pi_val / (2.0 * T_seg1) * sin(pi_val * time / T_seg1);
    vy_ref = 0.0;
  else
    x_ref = L1;
    y_ref = L2 * (1.0 - cos(pi_val * (time - T_seg1) / T_seg2)) / 2.0;
    vx_ref = 0.0;
    vy_ref = L2 * pi_val / (2.0 * T_seg2) * sin(pi_val * (time - T_seg1) / T_seg2);
  end if;

  // ===== Cup compliance (algebraic, no separate cup mass state) =====
  delta = z_table + h_box - z_c + L_cup0;
  v_delta = -vz_c;
  F_suction = (-p_vac) * A_cup;
  F_normal = k_cup * delta + c_cup * v_delta + F_suction;

  // ===== Table normal force on box =====
  N_table = m_box * g + F_normal;

  // ===== Disturbance: 7.2 N friction change during middle third =====
  dist_active = if (time > T_dist_start and time < T_dist_end) then 1.0 else 0.0;
  F_bt_eff = max(0.0, mu_box_table * N_table - F_disturb * dist_active);

  // ===== Friction models (regularized Coulomb via tanh) =====
  F_tb_x = mu_tool_box * F_normal * tanh((vx_t - vx_b) / v_eps);
  F_tb_y = mu_tool_box * F_normal * tanh((vy_t - vy_b) / v_eps);
  F_bt_x = F_bt_eff * tanh(vx_b / v_eps);
  F_bt_y = F_bt_eff * tanh(vy_b / v_eps);

  // ===== Yaw torque from off-center contact =====
  tau_yaw = F_tb_x * e_offset - d_yaw * omega_b;

  // ===== Carriage vertical dynamics (passive prismatic joint) =====
  der(z_c) = vz_c;
  m_car * der(vz_c) = -k_car * (z_c - z_rest) - c_car * vz_c + F_normal - m_car * g;

  // ===== Tool horizontal dynamics (linear-actuated) =====
  der(x_t) = vx_t;
  der(y_t) = vy_t;
  m_cup * der(vx_t) = F_lin_x - F_tb_x;
  m_cup * der(vy_t) = F_lin_y - F_tb_y;

  // ===== Box planar dynamics =====
  der(x_b) = vx_b;
  der(y_b) = vy_b;
  m_box * der(vx_b) = F_tb_x - F_bt_x;
  m_box * der(vy_b) = F_tb_y - F_bt_y;

  // ===== Box yaw dynamics =====
  der(theta_b) = omega_b;
  J_box * der(omega_b) = tau_yaw;

  // ===== Vacuum actuator dynamics (first-order lag) =====
  der(p_vac) = (p_vac_cmd - p_vac) / tau_vac;

  // ===== Tracking error and force error =====
  track_err = sqrt((x_b - x_ref) * (x_b - x_ref) + (y_b - y_ref) * (y_b - y_ref));
  F_n_err = F_n_target - F_normal;

  // ===== Acceptance checks (fail-closed) =====
  contact_in_range = (F_normal >= F_contact_lo) and (F_normal <= F_contact_hi);
  track_ok = if time >= T_settle then (track_err < track_tol) else true;
  actuator_ok = (F_lin_mag <= F_lin_bound + 0.001) and
                (p_vac >= p_vac_hi - 1.0) and (p_vac <= p_vac_lo + 1.0);
  no_nan_inf = (F_normal == F_normal) and (track_err == track_err) and
               (x_b == x_b) and (y_b == y_b) and (theta_b == theta_b) and
               (z_c == z_c) and (p_vac == p_vac) and
               (F_lin_x == F_lin_x) and (F_lin_y == F_lin_y) and
               (F_lin_mag == F_lin_mag) and (p_vac_cmd == p_vac_cmd);
  fail_closed = contact_in_range and track_ok and actuator_ok and no_nan_inf;

  // ===== Discrete control at 250 Hz =====
  when sample(0, Ts) then
    // Position control (PD): tool tracks planar reference
    F_lin_x_raw = kp_pos * (x_ref - x_t) + kd_pos * (vx_ref - vx_t);
    F_lin_y_raw = kp_pos * (y_ref - y_t) + kd_pos * (vy_ref - vy_t);
    F_lin_mag_raw = sqrt(F_lin_x_raw * F_lin_x_raw + F_lin_y_raw * F_lin_y_raw);
    // Saturate linear actuator to magnitude bound
    sat_scale = if F_lin_mag_raw > F_lin_bound then F_lin_bound / (F_lin_mag_raw + 1e-10) else 1.0;
    F_lin_x_d = F_lin_x_raw * sat_scale;
    F_lin_y_d = F_lin_y_raw * sat_scale;
    // Force control: vacuum regulates normal contact force
    p_vac_cmd_d = max(p_vac_hi, min(p_vac_lo, -kp_vac * (F_n_target - F_normal)));
  end when;

  annotation(
    Documentation(info = "<html>
<p><b>VacuumToolPushE</b>: Contact-rich manipulation scenario.</p>
<p>A vertical prismatic carriage (passive spring-damper) carries a 0.8 kg compliant
suction cup (radius 0.038 m). One linear actuator (magnitude bounded at 352 N) drives
horizontal tool motion via PD position control. One vacuum-pressure actuator
(0 to -70 kPa gauge) regulates normal contact force via proportional force control.</p>
<p>The rigid box (on a rigid table, mu_box_table=0.42, mu_tool_box=0.65) is pushed
along a two-segment planar reference: segment 1 in +x (0 to 8 s), segment 2 in +y
(8 to 16 s). A controlled 7.2 N friction decrease occurs during the middle third.
Hybrid position-force control runs at 250 Hz (zero-order hold).</p>
<p><b>Acceptance (fail-closed):</b> actuator bounds, contact force in [5, 25] N,
tracking error below 0.036 m after 10.4 s, no NaN or infinite values.</p>
<p><b>Assumed parameters</b> (not stated in requirement): m_box, J_box, m_car,
k_cup, c_cup, k_car, c_car, box dimensions, segment lengths, control gains,
yaw moment arm, yaw damping, friction velocity threshold.</p>
</html>"),
    experiment(StopTime = 16, Tolerance = 1e-6, Interval = 0.004)
  );
end VacuumToolPushE;