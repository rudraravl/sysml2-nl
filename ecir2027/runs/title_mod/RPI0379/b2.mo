model ParallelGripPolishA
  "Contact-rich parallel-gripper polishing system with tangential trajectory control and normal-force regulation";

  // Physical parameters
  parameter Real m_palm = 6.0 "Palm mass [kg]";
  parameter Real m_finger = 0.5 "Each finger mass [kg]";
  parameter Real L_travel = 0.05 "Prismatic joint travel [m]";
  parameter Real mu = 0.50 "Friction coefficient between pads and workpiece";
  parameter Real L_path = 0.50 "Surface path length [m]";
  parameter Real k_pad = 10000.0 "Pad stiffness [N/m]";
  parameter Real c_pad = 140.0 "Pad damping [N.s/m]";
  parameter Real F_cmd_max = 32.4 "Per-finger command magnitude limit [N]";
  parameter Real d_contact = 0.035 "Finger position at initial pad contact [m]";
  parameter Real d_init = 0.037 "Initial finger position [m]";
  parameter Real A_surf = 0.015 "Surface curve amplitude [m]";
  parameter Real k_surf = 2.0 * 3.14159265358979 / L_path "Surface spatial frequency [1/m]";
  parameter Real F_normal_ref = 20.0 "Reference normal gripping force per finger [N]";
  parameter Real F_dist_mag = 3.5 "Disturbance magnitude [N]";
  parameter Real T_total = 8.0 "Total scenario duration [s]";
  parameter Real t_dist_start = T_total / 3.0 "Disturbance start time [s]";
  parameter Real t_dist_end = 2.0 * T_total / 3.0 "Disturbance end time [s]";
  parameter Real kp_tang = 400.0 "Tangential position gain [N/m]";
  parameter Real ki_tang = 60.0 "Tangential integral gain [N/(m.s)]";
  parameter Real kd_tang = 35.0 "Tangential velocity gain [N.s/m]";
  parameter Real kp_force = 8.0 "Normal force proportional gain";
  parameter Real kd_force = 1.0 "Normal force velocity damping [N.s/m]";
  parameter Real k_stop = 1.0e5 "End-stop stiffness [N/m]";
  parameter Real c_stop = 500.0 "End-stop damping [N.s/m]";
  parameter Real v_eps = 1.0e-3 "Friction velocity regularization [m/s]";
  parameter Real eps_smooth = 1.0e-8 "Smooth approximation epsilon";

  // Dynamic states
  Real s(start = 0.0, fixed = true) "Path position along surface [m]";
  Real v_s(start = 0.0, fixed = true) "Path velocity [m/s]";
  Real d_f1(start = 0.037, fixed = true) "Finger 1 prismatic position [m]";
  Real v_f1(start = 0.0, fixed = true) "Finger 1 velocity [m/s]";
  Real d_f2(start = 0.037, fixed = true) "Finger 2 prismatic position [m]";
  Real v_f2(start = 0.0, fixed = true) "Finger 2 velocity [m/s]";
  Real s_int(start = 0.0, fixed = true) "Integral of path tracking error [m.s]";

  // Intermediate variables
  Real m_total "Total gripper mass [kg]";
  Real y_surf "Surface height at current path position [m]";
  Real delta_1 "Pad 1 deflection [m]";
  Real delta_2 "Pad 2 deflection [m]";
  Real F_pad1 "Pad 1 contact force [N]";
  Real F_pad2 "Pad 2 contact force [N]";
  Real F_normal "Normal gripping force per finger [N]";
  Real F_normal_total "Total normal gripping force [N]";
  Real contact_metric "Continuous contact metric [0..1]";
  Real F_fric "Tangential friction force on gripper [N]";
  Real neg_f1 "Lower stop penetration finger 1 [m]";
  Real ovr_f1 "Upper stop penetration finger 1 [m]";
  Real neg_f2 "Lower stop penetration finger 2 [m]";
  Real ovr_f2 "Upper stop penetration finger 2 [m]";
  Real F_stop1 "End-stop force finger 1 [N]";
  Real F_stop2 "End-stop force finger 2 [N]";
  Real F_cmd1_raw "Raw finger 1 command [N]";
  Real F_cmd2_raw "Raw finger 2 command [N]";
  Real F_cmd1 "Saturated finger 1 command [N]";
  Real F_cmd2 "Saturated finger 2 command [N]";
  Real F_tang_cmd "Tangential command [N]";
  Real F_ff "Tangential feedforward force [N]";
  Real s_ref "Reference path position [m]";
  Real v_ref "Reference path velocity [m/s]";
  Real s_err "Path tracking error [m]";
  Real s_err_abs "Absolute path tracking error [m]";
  Real F_dist "Surface-force disturbance [N]";

  // Sensors
  Real enc_f1 "Joint encoder finger 1 [m]";
  Real enc_f2 "Joint encoder finger 2 [m]";
  Real wrench_t "Wrist wrench tangential component [N]";
  Real wrench_n "Wrist wrench normal component [N]";
  Real tool_tip_x "Tool-tip Cartesian x [m]";
  Real tool_tip_y "Tool-tip Cartesian y [m]";

  // Bound-check indicators
  Real F_lo_viol "Normal force below 12 N violation [N]";
  Real F_hi_viol "Normal force above 30 N violation [N]";
  Real track_err_metric "Tracking error metric [m]";
  Real effort_viol1 "Finger 1 effort bound violation [N]";
  Real effort_viol2 "Finger 2 effort bound violation [N]";
  Real joint_viol1_lo "Finger 1 lower joint bound violation [m]";
  Real joint_viol1_hi "Finger 1 upper joint bound violation [m]";
  Real joint_viol2_lo "Finger 2 lower joint bound violation [m]";
  Real joint_viol2_hi "Finger 2 upper joint bound violation [m]";

  // Local helpers for smooth positive part
  Real r_d1 "Residual d_f1 - d_contact [m]";
  Real r_d2 "Residual d_f2 - d_contact [m]";
  Real r_neg1 "Residual -d_f1 [m]";
  Real r_ovr1 "Residual d_f1 - L_travel [m]";
  Real r_neg2 "Residual -d_f2 [m]";
  Real r_ovr2 "Residual d_f2 - L_travel [m]";

equation
  // Total mass
  m_total = m_palm + 2.0 * m_finger;

  // Surface geometry (cosine profile)
  y_surf = A_surf * cos(k_surf * s);

  // Residuals for smooth positive part
  r_d1 = d_f1 - d_contact;
  r_d2 = d_f2 - d_contact;
  r_neg1 = -d_f1;
  r_ovr1 = d_f1 - L_travel;
  r_neg2 = -d_f2;
  r_ovr2 = d_f2 - L_travel;

  // Smooth positive part for contact deflection
  delta_1 = 0.5 * (r_d1 + sqrt(r_d1 * r_d1 + eps_smooth));
  delta_2 = 0.5 * (r_d2 + sqrt(r_d2 * r_d2 + eps_smooth));

  // Pad contact forces (compliant normal contact)
  F_pad1 = k_pad * delta_1 + c_pad * v_f1 * delta_1 / (delta_1 + eps_smooth);
  F_pad2 = k_pad * delta_2 + c_pad * v_f2 * delta_2 / (delta_2 + eps_smooth);
  F_normal = (F_pad1 + F_pad2) / 2.0;
  F_normal_total = F_pad1 + F_pad2;
  contact_metric = (delta_1 * delta_2) / ((delta_1 + eps_smooth) * (delta_2 + eps_smooth));

  // Friction (Coulomb, regularized)
  F_fric = mu * F_normal_total * v_s / sqrt(v_s * v_s + v_eps * v_eps);

  // End-stop penetrations (smooth positive parts)
  neg_f1 = 0.5 * (r_neg1 + sqrt(r_neg1 * r_neg1 + eps_smooth));
  ovr_f1 = 0.5 * (r_ovr1 + sqrt(r_ovr1 * r_ovr1 + eps_smooth));
  neg_f2 = 0.5 * (r_neg2 + sqrt(r_neg2 * r_neg2 + eps_smooth));
  ovr_f2 = 0.5 * (r_ovr2 + sqrt(r_ovr2 * r_ovr2 + eps_smooth));

  // End-stop forces
  F_stop1 = -k_stop * neg_f1 - c_stop * v_f1 * neg_f1 / (neg_f1 + eps_smooth)
            + k_stop * ovr_f1 + c_stop * v_f1 * ovr_f1 / (ovr_f1 + eps_smooth);
  F_stop2 = -k_stop * neg_f2 - c_stop * v_f2 * neg_f2 / (neg_f2 + eps_smooth)
            + k_stop * ovr_f2 + c_stop * v_f2 * ovr_f2 / (ovr_f2 + eps_smooth);

  // Trajectory reference
  s_ref = L_path * time / T_total;
  v_ref = L_path / T_total;
  s_err = s - s_ref;
  s_err_abs = abs(s_err);

  // Disturbance (middle third of scenario)
  F_dist = if time >= t_dist_start and time <= t_dist_end then F_dist_mag else 0.0;

  // Feedforward
  F_ff = mu * 2.0 * F_normal_ref;

  // Tangential trajectory control (PI + D + feedforward)
  der(s_int) = s_ref - s;
  F_tang_cmd = kp_tang * (s_ref - s) + ki_tang * s_int + kd_tang * (v_ref - v_s) + F_ff;

  // Normal-force regulation (per-finger)
  F_cmd1_raw = F_normal_ref + kp_force * (F_normal_ref - F_pad1) - kd_force * v_f1;
  F_cmd2_raw = F_normal_ref + kp_force * (F_normal_ref - F_pad2) - kd_force * v_f2;
  F_cmd1 = if F_cmd1_raw > F_cmd_max then F_cmd_max elseif F_cmd1_raw < -F_cmd_max then -F_cmd_max else F_cmd1_raw;
  F_cmd2 = if F_cmd2_raw > F_cmd_max then F_cmd_max elseif F_cmd2_raw < -F_cmd_max then -F_cmd_max else F_cmd2_raw;

  // Plant dynamics: gripper along surface path
  der(s) = v_s;
  m_total * der(v_s) = F_tang_cmd - F_fric - F_dist;

  // Plant dynamics: finger prismatic joints
  der(d_f1) = v_f1;
  m_finger * der(v_f1) = F_cmd1 - F_pad1 + F_stop1;
  der(d_f2) = v_f2;
  m_finger * der(v_f2) = F_cmd2 - F_pad2 + F_stop2;

  // Sensors
  enc_f1 = d_f1;
  enc_f2 = d_f2;
  wrench_t = F_tang_cmd;
  wrench_n = F_normal_total;
  tool_tip_x = s;
  tool_tip_y = y_surf;

  // Bound-check indicators
  F_lo_viol = if 12.0 - F_normal > 0.0 then 12.0 - F_normal else 0.0;
  F_hi_viol = if F_normal - 30.0 > 0.0 then F_normal - 30.0 else 0.0;
  track_err_metric = s_err_abs;
  effort_viol1 = if abs(F_cmd1_raw) - F_cmd_max > 0.0 then abs(F_cmd1_raw) - F_cmd_max else 0.0;
  effort_viol2 = if abs(F_cmd2_raw) - F_cmd_max > 0.0 then abs(F_cmd2_raw) - F_cmd_max else 0.0;
  joint_viol1_lo = if -d_f1 > 0.0 then -d_f1 else 0.0;
  joint_viol1_hi = if d_f1 - L_travel > 0.0 then d_f1 - L_travel else 0.0;
  joint_viol2_lo = if -d_f2 > 0.0 then -d_f2 else 0.0;
  joint_viol2_hi = if d_f2 - L_travel > 0.0 then d_f2 - L_travel else 0.0;

  annotation (
    experiment(StartTime = 0, StopTime = 8.0, Tolerance = 1e-6, Interval = 0.0125),
    Documentation(info = "ParallelGripPolishA: contact-rich parallel-gripper polishing with tangential trajectory control and normal-force regulation. Fixed 6 kg palm, two 0.5 kg opposing fingers on 0.05 m prismatic joints, compliant pads, 32.4 N per-finger actuator limit, 0.50 m curved surface path, friction coefficient 0.50, 3.5 N disturbance during middle third, 80 Hz control, 8 s simulation.")
  );
end ParallelGripPolishA;