model VacuumToolPushE
  "Contact-rich manipulation: vacuum tool pushes box along two-segment planar reference
   with hybrid position-force control, bounded actuators, friction disturbance, and fail-closed acceptance."

  // ===== Requirement-specified parameters =====
  parameter Modelica.Units.SI.Mass m_cup = 0.8 "Suction cup mass";
  parameter Modelica.Units.SI.Radius r_cup = 0.038 "Suction cup radius";
  parameter Modelica.Units.SI.Pressure p_vac_lo = 0 "Vacuum command lower bound (0 kPa gauge)";
  parameter Modelica.Units.SI.Pressure p_vac_hi = -70000 "Vacuum command upper bound (-70 kPa gauge)";
  parameter Modelica.Units.SI.Force F_lin_bound = 352 "Linear actuator command magnitude bound";
  parameter Real mu_box_table = 0.42 "Box-table friction coefficient";
  parameter Real mu_tool_box = 0.65 "Tool-box friction coefficient";
  parameter Modelica.Units.SI.Force F_disturb = 7.2 "Friction change disturbance magnitude";
  parameter Modelica.Units.SI.Frequency f_sample = 250 "Control loop frequency (Hz)";
  parameter Modelica.Units.SI.Time T_sim = 16 "Simulation duration";
  parameter Modelica.Units.SI.Time T_settle = 10.4 "Tracking error evaluation time";
  parameter Modelica.Units.SI.Length track_tol = 0.036 "Tracking error tolerance";
  parameter Modelica.Units.SI.Force F_contact_lo = 5 "Min acceptable contact force";
  parameter Modelica.Units.SI.Force F_contact_hi = 25 "Max acceptable contact force";

  // ===== Assumed parameters (not stated in requirement, labeled as assumed) =====
  parameter Modelica.Units.SI.Mass m_box = 0.5 "Box mass -- assumed, not specified";
  parameter Modelica.Units.SI.Inertia J_box = 0.002 "Box yaw inertia -- assumed";
  parameter Modelica.Units.SI.Mass m_car = 1.5 "Carriage mass -- assumed";
  parameter Modelica.Units.SI.Length h_box = 0.04 "Box height -- assumed";
  parameter Modelica.Units.SI.Length L_cup0 = 0.01 "Cup rest length -- assumed";
  parameter Modelica.Units.SI.Length e_offset = 0.003 "Contact yaw moment arm -- assumed";
  parameter Real(unit="N/m") k_cup = 3000 "Cup compliance stiffness -- assumed";
  parameter Real(unit="N.s/m") c_cup = 60 "Cup damping -- assumed";
  parameter Real(unit="N/m") k_car = 500 "Carriage vertical stiffness -- assumed";
  parameter Real(unit="N.s/m") c_car = 60 "Carriage vertical damping -- assumed";
  parameter Modelica.Units.SI.Acceleration g = 9.81 "Standard gravity";
  parameter Modelica.Units.SI.Length z_table = 0.0 "Table surface height";
  parameter Modelica.Units.SI.Length L1 = 0.2 "Segment 1 planar distance -- assumed";
  parameter Modelica.Units.SI.Length L2 = 0.2 "Segment 2 planar distance -- assumed";
  parameter Modelica.Units.SI.Time T_seg1 = 8.0 "Segment 1 duration";
  parameter Modelica.Units.SI.Time T_seg2 = 8.0 "Segment 2 duration";
  parameter Modelica.Units.SI.Force F_n_target = 18.0 "Target normal force -- assumed";
  parameter Real kp_pos = 500.0 "Position control proportional gain";
  parameter Real kd_pos = 50.0 "Position control derivative gain";
  parameter Real kp_vac = 200.0 "Vacuum pressure gain (Pa per N of force error)";
  parameter Modelica.Units.SI.Time tau_vac = 0.05 "Vacuum actuator first-order time constant";
  parameter Real d_yaw = 0.01 "Yaw damping coefficient -- assumed";
  parameter Real v_eps = 0.005 "Friction velocity regularization threshold (m/s)";
  final parameter Modelica.Units.SI.Length z_rest = 0.047 "Carriage spring rest position -- assumed";

  // ===== Derived constants =====
  final parameter Modelica.Units.SI.Area A_cup = Modelica.Constants.pi * r_cup * r_cup;
  final parameter Modelica.Units.SI.Time Ts = 1.0 / f_sample;
  final parameter Modelica.Units.SI.Time T_dist_start = T_sim / 3.0;
  final parameter Modelica.Units.SI.Time T_dist_end = 2.0 * T_sim / 3.0;

  // ===== Continuous states =====
  Modelica.Units.SI.Length z_c(start = 0.047) "Carriage vertical position";
  Modelica.Units.SI.Velocity vz_c(start = 0) "Carriage vertical velocity";
  Modelica.Units.SI.Length x_t(start = 0) "Tool x position";
  Modelica.Units.SI.Velocity vx_t(start = 0) "Tool x velocity";
  Modelica.Units.SI.Length y_t(start = 0) "Tool y position";
  Modelica.Units.SI.Velocity vy_t(start = 0) "Tool y velocity";
  Modelica.Units.SI.Length x_b(start = 0) "Box x position";
  Modelica.Units.SI.Velocity vx_b(start = 0) "Box x velocity";
  Modelica.Units.SI.Length y_b(start = 0) "Box y position";
  Modelica.Units.SI.Velocity vy_b(start = 0) "Box y velocity";
  Modelica.Units.SI.Angle theta_b(start = 0) "Box yaw angle";
  Modelica.Units.SI.AngularVelocity omega_b(start = 0) "Box yaw rate";
  Modelica.Units.SI.Pressure p_vac(start = 0) "Actual vacuum pressure (gauge)";

  // ===== Discrete control signals (250 Hz zero-order hold) =====
  discrete Modelica.Units.SI.Force F_lin_x_d(start = 0) "Discrete linear actuator force x";
  discrete Modelica.Units.SI.Force F_lin_y_d(start = 0) "Discrete linear actuator force y";
  discrete Modelica.Units.SI.Pressure p_vac_cmd_d(start = 0) "Discrete vacuum command";
  discrete Modelica.Units.SI.Force F_lin_x_raw(start = 0) "Unsaturated linear force x";
  discrete Modelica.Units.SI.Force F_lin_y_raw(start = 0) "Unsaturated linear force y";
  discrete Modelica.Units.SI.Force F_lin_mag_raw(start = 0) "Unsaturated force magnitude";

  // ===== Actuator outputs (applied) =====
  Modelica.Units.SI.Force F_lin_x "Applied linear actuator force x";
  Modelica.Units.SI.Force F_lin_y "Applied linear actuator force y";
  Modelica.Units.SI.Force F_lin_mag "Linear actuator force magnitude";
  Modelica.Units.SI.Pressure p_vac_cmd "Vacuum pressure command";

  // ===== Contact and friction =====
  Modelica.Units.SI.Length delta "Cup deflection (compression positive)";
  Modelica.Units.SI.Velocity v_delta "Cup deflection rate";
  Modelica.Units.SI.Force F_normal "Normal contact force";
  Modelica.Units.SI.Force F_suction "Suction force from vacuum";
  Modelica.Units.SI.Force F_tb_x "Tool-box friction force x";
  Modelica.Units.SI.Force F_tb_y "Tool-box friction force y";
  Modelica.Units.SI.Force F_bt_x "Box-table friction force x";
  Modelica.Units.SI.Force F_bt_y "Box-table friction force y";
  Modelica.Units.SI.Force N_table "Table normal force on box";
  Modelica.Units.SI.Torque tau_yaw "Net yaw torque on box";
  Real dist_active "Disturbance active flag (1.0 or 0.0)";
  Real F_bt_eff "Effective box-table friction force magnitude";

  // ===== Reference trajectory =====
  Modelica.Units.SI.Length x_ref "Reference x";
  Modelica.Units.SI.Length y_ref "Reference y";
  Modelica.Units.SI.Velocity vx_ref "Reference x velocity";
  Modelica.Units.SI.Velocity vy_ref "Reference y velocity";
  Integer segment "Active segment (1 or 2)";

  // ===== Measurements and acceptance =====
  Modelica.Units.SI.Length track_err "Primary tracking error";
  Modelica.Units.SI.Force F_n_err "Normal force error";
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
  F_lin_mag = Modelica.Math.sqrt(F_lin_x * F_lin_x + F_lin_y * F_lin_y);

  // ===== Reference trajectory: two-segment planar =====
  // Segment 1 (0 to T_seg1): smooth move in +x from 0 to L1
  // Segment 2 (T_seg1 to T_sim): smooth move in +y from 0 to L2
  segment = if time < T_seg1 then 1 else 2;
  if time < T_seg1 then
    x_ref = L1 * (1.0 - Modelica.Math.cos(Modelica.Constants.pi * time / T_seg1)) / 2.0;
    y_ref = 0.0;
    vx_ref = L1 * Modelica.Constants.pi / (2.0 * T_seg1) *
             Modelica.Math.sin(Modelica.Constants.pi * time / T_seg1);
    vy_ref = 0.0;
  else
    x_ref = L1;
    y_ref = L2 * (1.0 - Modelica.Math.cos(Modelica.Constants.pi * (time - T_seg1) / T_seg2)) / 2.0;
    vx_ref = 0.0;
    vy_ref = L2 * Modelica.Constants.pi / (2.0 * T_seg2) *
             Modelica.Math.sin(Modelica.Constants.pi * (time - T_seg1) / T_seg2);
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
  F_tb_x = mu_tool_box * F_normal * Modelica.Math.tanh((vx_t - vx_b) / v_eps);
  F_tb_y = mu_tool_box * F_normal * Modelica.Math.tanh((vy_t - vy_b) / v_eps);
  F_bt_x = F_bt_eff * Modelica.Math.tanh(vx_b / v_eps);
  F_bt_y = F_bt_eff * Modelica.Math.tanh(vy_b / v_eps);

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
  track_err = Modelica.Math.sqrt((x_b - x_ref) * (x_b - x_ref) + (y_b - y_ref) * (y_b - y_ref));
  F_n_err = F_n_target - F_normal;

  // ===== Acceptance checks (fail-closed) =====
  contact_in_range = (F_normal >= F_contact_lo) and (F_normal <= F_contact_hi);
  track_ok = if time >= T_settle then (track_err < track_tol) else true;
  actuator_ok = (F_lin_mag <= F_lin_bound + 1e-3) and
                (p_vac >= p_vac_hi - 1.0) and (p_vac <= p_vac_lo + 1.0);
  no_nan_inf = (F_normal == F_normal) and (track_err == track_err) and
               (x_b == x_b) and (y_b == y_b) and (theta_b == theta_b) and
               (z_c == z_c) and (p_vac == p_vac) and
               (F_lin_x == F_lin_x) and (F_lin_y == F_lin_y) and
               (F_lin_mag == F_lin_mag) and (p_vac_cmd == p_vac_cmd);
  fail_closed = contact_in_range and track_ok and actuator_ok and no_nan_inf;

algorithm
  when sample(0, Ts) then
    // --- Position control (PD): tool tracks planar reference ---
    F_lin_x_raw := kp_pos * (x_ref - x_t) + kd_pos * (vx_ref - vx_t);
    F_lin_y_raw := kp_pos * (y_ref - y_t) + kd_pos * (vy_ref - vy_t);
    F_lin_mag_raw := Modelica.Math.sqrt(F_lin_x_raw * F_lin_x_raw + F_lin_y_raw * F_lin_y_raw);
    // Saturate linear actuator to magnitude bound
    if F_lin_mag_raw > F_lin_bound then
      F_lin_x_d := F_lin_x_raw * F_lin_bound / (F_lin_mag_raw + 1e-10);
      F_lin_y_d := F_lin_y_raw * F_lin_bound / (F_lin_mag_raw + 1e-10);
    else
      F_lin_x_d := F_lin_x_raw;
      F_lin_y_d := F_lin_y_raw;
    end if;
    // --- Force control: vacuum regulates normal contact force ---
    p_vac_cmd_d := max(p_vac_hi, min(p_vac_lo, -kp_vac * (F_n_target - F_normal)));
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
(8 to 16 s). A controlled 7.2 N friction decrease occurs during the middle third
(5.33 to 10.67 s). Hybrid position-force control runs at 250 Hz (zero-order hold).</p>
<p><b>Acceptance (fail-closed):</b> actuator bounds, contact force in [5, 25] N,
tracking error below 0.036 m after 10.4 s, no NaN or infinite values.</p>
<p><b>Assumed parameters</b> (not stated in requirement): m_box, J_box, m_car,
k_cup, c_cup, k_car, c_car, box dimensions, segment lengths, control gains,
yaw moment arm, yaw damping, friction velocity threshold.</p>
</html>"),
    experiment(StopTime = 16, Tolerance = 1e-6, Interval = 0.004)
  );
end VacuumToolPushE;