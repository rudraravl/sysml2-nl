model ParallelGripPushA
  // ===== Parameters from requirement =====
  parameter Real m_palm = 6.0 "Fixed palm mass [kg]";
  parameter Real m_finger = 0.5 "Each finger mass [kg]";
  parameter Real finger_travel = 0.05 "Prismatic joint travel [m]";
  parameter Real mu_table = 0.42 "Box-table friction coefficient";
  parameter Real mu_tool = 0.65 "Tool-box friction coefficient";
  parameter Real F_cmd_max = 32.4 "Per-finger command magnitude limit [N]";
  parameter Real T_sim = 8.0 "Scenario duration [s]";
  parameter Real f_ctrl = 80.0 "Control loop frequency [Hz]";
  parameter Real dt_ctrl = 1.0 / f_ctrl "Control period [s]";
  parameter Real F_disturb_val = 3.0 "Disturbance friction change [N]";

  // ===== Assumed parameters (not stated in requirement) =====
  parameter Real m_box = 1.0 "Box mass [kg] (assumed)";
  parameter Real I_box = 0.002 "Box yaw inertia [kg.m2] (assumed)";
  parameter Real W_box = 0.03 "Box half-width in y [m] (assumed)";
  parameter Real L_box = 0.05 "Box half-length in x [m] (assumed)";
  parameter Real k_pad = 10000.0 "Compliant pad stiffness [N/m] (assumed)";
  parameter Real d_pad = 100.0 "Compliant pad damping [N.s/m] (assumed)";
  parameter Real g_acc = 9.81 "Gravitational acceleration [m/s2] (assumed)";
  parameter Real F_n_ref = 15.0 "Normal force reference [N] (within 5-25 N)";
  parameter Real x_ref_seg1 = 0.10 "Segment 1 endpoint x [m] (assumed)";
  parameter Real x_ref_seg2 = 0.20 "Segment 2 endpoint x [m] (assumed)";
  parameter Real Kp_x = 200.0 "Position control proportional gain (assumed)";
  parameter Real Kd_x = 10.0 "Position control derivative gain (assumed)";
  parameter Real Kp_n = 3.0 "Normal force control gain (assumed)";
  parameter Real v_thresh = 0.005 "Friction regularization velocity [m/s] (assumed)";
  parameter Real d_yaw = 0.05 "Yaw rotational damping [N.m.s/rad] (assumed)";

  // ===== Finger states (prismatic joints in y / closure direction) =====
  Real y_fL(start = -finger_travel / 2, fixed = true) "Left finger y-position [m]";
  Real vy_fL(start = 0, fixed = true) "Left finger y-velocity [m/s]";
  Real y_fR(start = finger_travel / 2, fixed = true) "Right finger y-position [m]";
  Real vy_fR(start = 0, fixed = true) "Right finger y-velocity [m/s]";

  // ===== Box planar pose and velocities =====
  Real x_box(start = 0, fixed = true) "Box x-position (push direction) [m]";
  Real vx_box(start = 0, fixed = true) "Box x-velocity [m/s]";
  Real y_box(start = 0, fixed = true) "Box y-position (normal direction) [m]";
  Real vy_box(start = 0, fixed = true) "Box y-velocity [m/s]";
  Real psi(start = 0, fixed = true) "Box yaw angle [rad]";
  Real psi_dot(start = 0, fixed = true) "Box yaw rate [rad/s]";

  // ===== Contact and friction forces =====
  Real F_n_L "Left pad normal contact force [N]";
  Real F_n_R "Right pad normal contact force [N]";
  Real F_n_total "Total measured normal force [N]";
  Real F_t_L "Left tangential (push) force on box [N]";
  Real F_t_R "Right tangential (push) force on box [N]";
  Real F_push "Net push force on box in x [N]";
  Real F_table "Table friction force on box [N]";

  // ===== Actuator commands =====
  Real F_cmd_L_zoh(start = 0) "Zero-order-hold left finger command [N]";
  Real F_cmd_R_zoh(start = 0) "Zero-order-hold right finger command [N]";
  Real F_push_cmd_zoh(start = 0) "Zero-order-hold push command [N]";
  Real F_cmd_L "Bounded left finger command [N]";
  Real F_cmd_R "Bounded right finger command [N]";
  Real F_push_cmd "Push force command [N]";

  // ===== Reference, tracking, disturbance =====
  Real x_ref "Two-segment planar position reference [m]";
  Real track_error "Primary tracking error |x_ref - x_box| [m]";
  Boolean disturb_active "Disturbance active during middle third";
  Boolean contact_established "Contact force above threshold";
  Boolean contact_force_valid "Contact force within 5-25 N when established";
  Boolean tracking_valid "Tracking error below 0.054 m after 5.2 s";

equation
  // === Two-segment planar reference trajectory ===
  if time < T_sim / 2.0 then
    x_ref = x_ref_seg1 * time / (T_sim / 2.0);
  else
    x_ref = x_ref_seg1 + (x_ref_seg2 - x_ref_seg1) * (time - T_sim / 2.0) / (T_sim / 2.0);
  end if;

  track_error = abs(x_ref - x_box);

  // === Disturbance: 3 N friction change during middle third of scenario ===
  disturb_active = (time >= T_sim / 3.0) and (time <= 2.0 * T_sim / 3.0);

  // === Compliant pad contact (unilateral spring-damper) ===
  // Left finger penetrates box left face when y_fL > y_box - W_box
  F_n_L = if (y_fL > y_box - W_box) then
    max(0.0, k_pad * (y_fL - y_box + W_box) + d_pad * (vy_fL - vy_box))
  else 0.0;

  // Right finger penetrates box right face when y_fR < y_box + W_box
  F_n_R = if (y_fR < y_box + W_box) then
    max(0.0, k_pad * (y_box + W_box - y_fR) + d_pad * (vy_box - vy_fR))
  else 0.0;

  F_n_total = F_n_L + F_n_R;

  // === Tangential push force (friction-cone limited by tool-box friction) ===
  F_t_L = if F_n_L > 0.5 then
    max(-mu_tool * F_n_L, min(mu_tool * F_n_L, F_push_cmd / 2.0))
  else 0.0;
  F_t_R = if F_n_R > 0.5 then
    max(-mu_tool * F_n_R, min(mu_tool * F_n_R, F_push_cmd / 2.0))
  else 0.0;
  F_push = F_t_L + F_t_R;

  // === Table friction (regularized Coulomb + disturbance) ===
  F_table = -(mu_table * m_box * g_acc + (if disturb_active then F_disturb_val else 0.0))
    * tanh(vx_box / v_thresh);

  // === Box planar dynamics ===
  der(x_box) = vx_box;
  m_box * der(vx_box) = F_push + F_table;
  der(y_box) = vy_box;
  m_box * der(vy_box) = F_n_L - F_n_R;
  der(psi) = psi_dot;
  I_box * der(psi_dot) = W_box * (F_t_L - F_t_R) - d_yaw * psi_dot;

  // === Finger prismatic joint dynamics ===
  // Left finger: actuator pushes +y (closing), contact pushes -y
  der(y_fL) = vy_fL;
  m_finger * der(vy_fL) = F_cmd_L - F_n_L;
  // Right finger: actuator pushes -y (closing), contact pushes +y
  der(y_fR) = vy_fR;
  m_finger * der(vy_fR) = -F_cmd_R + F_n_R;

  // === Hybrid position-force control at 80 Hz ===
  when sample(0, dt_ctrl) then
    // Force control: regulate normal closure force to F_n_ref
    F_cmd_L_zoh = max(0.0, F_n_ref + Kp_n * (F_n_ref - F_n_L));
    F_cmd_R_zoh = max(0.0, F_n_ref + Kp_n * (F_n_ref - F_n_R));
    // Position control: PD regulator for box x-position
    F_push_cmd_zoh = Kp_x * (x_ref - x_box) - Kd_x * vx_box;
  end when;

  // === Actuator bounds (32.4 N per finger) ===
  F_cmd_L = max(0.0, min(F_cmd_max, F_cmd_L_zoh));
  F_cmd_R = max(0.0, min(F_cmd_max, F_cmd_R_zoh));
  F_push_cmd = F_push_cmd_zoh;

  // === Validation: contact force range, tracking error, no NaN ===
  contact_established = F_n_total > 1.0;
  contact_force_valid = (not contact_established) or (F_n_total >= 5.0 and F_n_total <= 25.0);
  tracking_valid = (time < 5.2) or (track_error < 0.054);

  // Palm (m_palm = 6 kg) is fixed / structural — no dynamics required
end ParallelGripPushA;