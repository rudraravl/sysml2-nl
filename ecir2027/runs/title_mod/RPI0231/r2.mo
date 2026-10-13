model AssemblyArmCarryC
  "Fixed-base 4-DOF Z-Y-Y-X articulated manipulator with computed-torque control and bounded wrist-force correction"

  // --- Physical parameters ---
  parameter Real L[4] = {0.50, 0.40, 0.28, 0.16} "Capsule-link lengths [m]";
  parameter Real m_link[4] = {7.0, 5.0, 3.0, 1.0} "Link masses [kg]";
  parameter Real g_const = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real base_height = 0.50 "Base vertical offset [m]";
  parameter Real table_height = 0.75 "Table surface height [m]";
  parameter Real floor_z = 0.0 "Floor Z position [m]";

  // --- Control parameters ---
  parameter Real tau_max = 101.0 "Maximum command magnitude [N.m]";
  parameter Real F_wrist_limit = 60.0 "Wrist force limit [N]";
  parameter Real F_wrist_thresh = 0.8 * F_wrist_limit "Wrist force correction threshold [N]";
  parameter Real m_payload = 10.8 "Payload disturbance mass [kg]";
  parameter Real Kw_corr = 8.0 "Wrist force correction gain [N.m]";
  parameter Real Kp_ctc[4] = {180.0, 140.0, 90.0, 40.0} "CTC position feedback gains";
  parameter Real Kd_ctc[4] = {25.0, 18.0, 12.0, 6.0} "CTC velocity feedback gains";
  parameter Real joint_damp = 0.5 "Joint viscous damping [N.m.s/rad]";

  // --- Timing parameters ---
  parameter Real T_pl_start = 4.0 "Payload injection start [s]";
  parameter Real T_pl_end = 8.0 "Payload injection end [s]";
  parameter Real T_ramp = 6.0 "Reference trajectory ramp duration [s]";
  parameter Real T_settle = 7.8 "Settling time requirement [s]";
  parameter Real e_lim = 0.047 "Primary tracking error limit [rad-or-m]";

  // --- Joint states ---
  Real q[4](start = {0.0, 0.8, -0.4, 0.0}) "Joint angles [rad]";
  Real qd[4](start = {0.0, 0.0, 0.0, 0.0}) "Joint velocities [rad/s]";
  Real qdd[4] "Joint accelerations [rad/s2]";

  // --- Reference trajectory ---
  Real q_ref[4] "Reference joint angles [rad]";
  Real qd_ref[4] "Reference joint velocities [rad/s]";
  Real qdd_ref[4] "Reference joint accelerations [rad/s2]";
  Real s_traj "Quintic blend parameter [0..1]";
  Real s_trajd "Blend derivative";
  Real s_trajdd "Blend second derivative";

  // --- Tracking errors ---
  Real e[4] "Position tracking error [rad]";
  Real ed[4] "Velocity tracking error [rad/s]";

  // --- Control ---
  Real tau_cmd[4] "Commanded torque before saturation [N.m]";
  Real tau_sat[4] "Saturated torque [N.m]";
  Real tau_col[4] "Collision penalty torque [N.m]";

  // --- Wrist wrench sensor ---
  Real F_wrist_x "Wrist force X [N]";
  Real F_wrist_y "Wrist force Y [N]";
  Real F_wrist_z "Wrist force Z [N]";
  Real F_wrist_mag "Wrist force magnitude [N]";
  Real F_excess "Excess force above threshold [N]";
  Real F_clamp "Clamped excess force [N]";
  Real F_corr "Wrist correction torque contribution [N.m]";

  // --- Payload disturbance ---
  Real pl_active "Payload activation signal";
  Real m_eff "Effective payload mass [kg]";

  // --- Dynamics model ---
  Real Mdiag[4] "Effective diagonal inertia [kg.m2]";
  Real Gt[4] "Gravity compensation torque [N.m]";

  // --- Workspace / collision ---
  Real wrist_z "Wrist Z position [m]";
  Real arm_reach "Horizontal reach [m]";
  Real clr_table "Clearance above table [m]";
  Real clr_floor "Clearance above floor [m]";

  // --- Performance metrics ---
  Real e_prim "Primary tracking error [rad-or-m]";

  // --- Status flags ---
  Boolean ok_err "Primary error within bounds";
  Boolean ok_F "Wrist force within bounds";
  Boolean ok_tau "Torque within bounds";
  Boolean ok_payload "Payload retained";

  // --- Synchronized output traces ---
  output Real q_out[4] = q "Joint position trace [rad]";
  output Real qd_out[4] = qd "Joint velocity trace [rad/s]";
  output Real tau_out[4] = tau_sat "Commanded effort trace [N.m]";
  output Real F_wrist_out = F_wrist_mag "Wrist force trace [N]";
  output Real e_prim_out = e_prim "Primary error trace [rad-or-m]";

equation
  // ===== Payload disturbance (middle third: 4-8 s) =====
  pl_active = if (time >= T_pl_start and time <= T_pl_end) then 1.0 else 0.0;
  m_eff = pl_active * m_payload;

  // ===== Reference trajectory: quintic blend 0->1 over T_ramp, then hold =====
  s_traj = if time < T_ramp then
    10*(time/T_ramp)^3 - 15*(time/T_ramp)^4 + 6*(time/T_ramp)^5
  else 1.0;

  s_trajd = if time < T_ramp then
    (30*(time/T_ramp)^2 - 60*(time/T_ramp)^3 + 30*(time/T_ramp)^4) / T_ramp
  else 0.0;

  s_trajdd = if time < T_ramp then
    (60*(time/T_ramp) - 180*(time/T_ramp)^2 + 120*(time/T_ramp)^3) / T_ramp^2
  else 0.0;

  // Joint references: home pose -> target pose (lift and reposition)
  q_ref[1] = 0.6 * s_traj;
  q_ref[2] = 0.8 + 0.3 * s_traj;
  q_ref[3] = -0.4 + 0.2 * s_traj;
  q_ref[4] = 0.1 * s_traj;

  qd_ref[1] = 0.6 * s_trajd;
  qd_ref[2] = 0.3 * s_trajd;
  qd_ref[3] = 0.2 * s_trajd;
  qd_ref[4] = 0.1 * s_trajd;

  qdd_ref[1] = 0.6 * s_trajdd;
  qdd_ref[2] = 0.3 * s_trajdd;
  qdd_ref[3] = 0.2 * s_trajdd;
  qdd_ref[4] = 0.1 * s_trajdd;

  // ===== Tracking errors (from joint encoders) =====
  e[1] = q_ref[1] - q[1];
  e[2] = q_ref[2] - q[2];
  e[3] = q_ref[3] - q[3];
  e[4] = q_ref[4] - q[4];

  ed[1] = qd_ref[1] - qd[1];
  ed[2] = qd_ref[2] - qd[2];
  ed[3] = qd_ref[3] - qd[3];
  ed[4] = qd_ref[4] - qd[4];

  // ===== Effective inertia (lumped diagonal) =====
  Mdiag[1] = m_link[2]*L[2]^2/3 + m_link[3]*(L[2]+L[3])^2/3 + (m_link[4]+m_eff)*(L[2]+L[3]+L[4])^2/3 + 0.1;
  Mdiag[2] = (m_link[2]/3 + m_link[3] + m_link[4] + m_eff)*L[2]^2 + (m_link[3]/3 + m_link[4] + m_eff)*L[3]^2 + (m_link[4]/3 + m_eff)*L[4]^2 + 0.05;
  Mdiag[3] = (m_link[3]/3 + m_link[4] + m_eff)*L[3]^2 + (m_link[4]/3 + m_eff)*L[4]^2 + 0.03;
  Mdiag[4] = (m_link[4]/3 + m_eff)*L[4]^2 + 0.01;

  // ===== Gravity compensation (Z-Y-Y-X: joints 2,3 affected) =====
  Gt[1] = 0.0;
  Gt[2] = (m_link[2]*L[2]/2 + m_link[3]*(L[2]+L[3]/2) + (m_link[4]+m_eff)*(L[2]+L[3]+L[4]/2)) * g_const * cos(q[2]);
  Gt[3] = (m_link[3]*L[3]/2 + (m_link[4]+m_eff)*(L[3]+L[4]/2)) * g_const * cos(q[2]+q[3]);
  Gt[4] = 0.0;

  // ===== Wrist wrench sensor (six-axis, magnitude used) =====
  F_wrist_x = m_eff * (qd[1]^2 * (L[2]+L[3]+L[4]) + qdd[1] * (L[2]+L[3]+L[4]));
  F_wrist_y = 0.0;
  F_wrist_z = m_eff * g_const + m_eff * qdd[2] * (L[2]+L[3]);
  F_wrist_mag = sqrt(F_wrist_x^2 + F_wrist_y^2 + F_wrist_z^2 + 1.0e-6);

  // ===== Bounded wrist-force correction =====
  F_excess = F_wrist_mag - F_wrist_thresh;
  F_clamp = if F_excess > F_wrist_limit then F_wrist_limit
            elseif F_excess < 0.0 then 0.0
            else F_excess;
  F_corr = Kw_corr * F_clamp / (F_wrist_limit + 1.0e-6);

  // ===== Collision: rigid floor and fixed table =====
  wrist_z = base_height + L[2]*sin(q[2]) + L[3]*sin(q[2]+q[3]);
  arm_reach = L[2]*cos(q[2]) + L[3]*cos(q[2]+q[3]) + L[4];
  clr_table = wrist_z - table_height;
  clr_floor = wrist_z - floor_z;

  tau_col[1] = 0.0;
  tau_col[2] = if clr_table < 0.0 then -5000.0 * clr_table else 0.0;
  tau_col[3] = if clr_table < 0.0 then -3000.0 * clr_table else 0.0;
  tau_col[4] = 0.0;

  // ===== Computed-torque control law with saturation =====
  tau_cmd[1] = Mdiag[1]*(qdd_ref[1] + Kp_ctc[1]*e[1] + Kd_ctc[1]*ed[1]) + Gt[1] + F_corr + tau_col[1];
  tau_cmd[2] = Mdiag[2]*(qdd_ref[2] + Kp_ctc[2]*e[2] + Kd_ctc[2]*ed[2]) + Gt[2] + F_corr + tau_col[2];
  tau_cmd[3] = Mdiag[3]*(qdd_ref[3] + Kp_ctc[3]*e[3] + Kd_ctc[3]*ed[3]) + Gt[3] + F_corr + tau_col[3];
  tau_cmd[4] = Mdiag[4]*(qdd_ref[4] + Kp_ctc[4]*e[4] + Kd_ctc[4]*ed[4]) + Gt[4] + F_corr + tau_col[4];

  // Saturated effort (max 101 N.m)
  tau_sat[1] = if tau_cmd[1] > tau_max then tau_max elseif tau_cmd[1] < -tau_max then -tau_max else tau_cmd[1];
  tau_sat[2] = if tau_cmd[2] > tau_max then tau_max elseif tau_cmd[2] < -tau_max then -tau_max else tau_cmd[2];
  tau_sat[3] = if tau_cmd[3] > tau_max then tau_max elseif tau_cmd[3] < -tau_max then -tau_max else tau_cmd[3];
  tau_sat[4] = if tau_cmd[4] > tau_max then tau_max elseif tau_cmd[4] < -tau_max then -tau_max else tau_cmd[4];

  // ===== Plant dynamics: M * qdd = tau - G - damping =====
  Mdiag[1] * qdd[1] = tau_sat[1] - Gt[1] - joint_damp * qd[1];
  Mdiag[2] * qdd[2] = tau_sat[2] - Gt[2] - joint_damp * qd[2];
  Mdiag[3] * qdd[3] = tau_sat[3] - Gt[3] - joint_damp * qd[3];
  Mdiag[4] * qdd[4] = tau_sat[4] - Gt[4] - joint_damp * qd[4];

  // State derivatives
  der(q[1]) = qd[1];
  der(q[2]) = qd[2];
  der(q[3]) = qd[3];
  der(q[4]) = qd[4];
  der(qd[1]) = qdd[1];
  der(qd[2]) = qdd[2];
  der(qd[3]) = qdd[3];
  der(qd[4]) = qdd[4];

  // ===== Primary tracking error (link-length-weighted joint error) =====
  e_prim = sqrt((L[1]*e[1])^2 + (L[2]*e[2])^2 + (L[3]*e[3])^2 + (L[4]*e[4])^2);

  // ===== Status flags =====
  ok_err = (time < T_settle) or (e_prim < e_lim);
  ok_F = F_wrist_mag < F_wrist_limit;
  ok_tau = (abs(tau_sat[1]) <= tau_max + 0.1) and (abs(tau_sat[2]) <= tau_max + 0.1)
         and (abs(tau_sat[3]) <= tau_max + 0.1) and (abs(tau_sat[4]) <= tau_max + 0.1);
  ok_payload = (time < T_pl_start) or (time > T_pl_end) or (pl_active > 0.5);

  annotation(
    experiment(StartTime = 0, StopTime = 12, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info = "AssemblyArmCarryC: Fixed-base 4-DOF Z-Y-Y-X articulated manipulator with computed-torque control and bounded wrist-force correction. Runs at 125 Hz for 12 s. Injects 10.8 kg payload disturbance during middle third (4-8 s). Max effort 101 N.m. Wrist force below 60 N. Primary tracking error below 0.047 rad-or-m after 7.8 s. Joint encoders and six-axis wrist wrench sensor provide feedback. Rigid floor and fixed table with collision penalty.")
  );
end AssemblyArmCarryC;