model ParallelGripPolishA
  "Contact-rich parallel-gripper polishing system with tangential trajectory control and normal-force regulation"

  // === Physical parameters ===
  parameter Real m_palm = 6.0          "Palm mass [kg]";
  parameter Real m_finger = 0.5        "Each finger mass [kg]";
  parameter Real L_travel = 0.05       "Prismatic joint travel [m]";
  parameter Real mu = 0.50             "Friction coefficient between pads and workpiece";
  parameter Real L_path = 0.50         "Surface path length [m]";
  parameter Real k_pad = 10000.0       "Pad stiffness [N/m]";
  parameter Real c_pad = 140.0         "Pad damping [N.s/m]";
  parameter Real F_cmd_max = 32.4      "Per-finger command magnitude limit [N]";
  parameter Real d_contact = 0.035     "Finger position at initial pad contact [m]";
  parameter Real d_init = 0.037        "Initial finger position [m]";
  parameter Real A_surf = 0.015        "Surface curve amplitude [m]";
  parameter Real k_surf = 2.0 * 3.141592653589793 / L_path
                                       "Surface spatial frequency [1/m]";
  parameter Real F_normal_ref = 20.0   "Reference normal gripping force per finger [N]";
  parameter Real F_dist_mag = 3.5      "Disturbance magnitude [N]";
  parameter Real T_total = 8.0         "Total scenario duration [s]";
  parameter Real t_dist_start = T_total / 3.0  "Disturbance start time [s]";
  parameter Real t_dist_end = 2.0 * T_total / 3.0 "Disturbance end time [s]";
  parameter Real f_sample = 80.0      "Control loop frequency [Hz]";
  parameter Real T_sample = 1.0 / f_sample "Control period [s]";
  parameter Real kp_tang = 400.0       "Tangential position gain [N/m]";
  parameter Real ki_tang = 150.0       "Tangential integral gain [N/(m.s)]";
  parameter Real kd_tang = 60.0        "Tangential velocity gain [N.s/m]";
  parameter Real kp_force = 10.0       "Normal force proportional gain";
  parameter Real kd_force = 1.0        "Normal force velocity damping [N.s/m]";
  parameter Real k_stop = 1.0e5        "End-stop stiffness [N/m]";
  parameter Real c_stop = 500.0        "End-stop damping [N.s/m]";
  parameter Real v_eps = 1.0e-3       "Friction velocity regularization [m/s]";
  parameter Real eps_smooth = 1.0e-8  "Smooth approximation epsilon";

  // === Dynamic states ===
  Real s(start = 0.0, fixed = true)         "Path position along surface [m]";
  Real v_s(start = 0.0, fixed = true)       "Path velocity [m/s]";
  Real d_f1(start = d_init, fixed = true)   "Finger 1 prismatic position [m]";
  Real v_f1(start = 0.0, fixed = true)     "Finger 1 velocity [m/s]";
  Real d_f2(start = d_init, fixed = true)   "Finger 2 prismatic position [m]";
  Real v_f2(start = 0.0, fixed = true)     "Finger 2 velocity [m/s]";
  Real s_int(start = 0.0, fixed = true)    "Integral of path tracking error [m.s]";

  // === Surface geometry ===
  Real y_surf        "Surface height at current path position [m]";
  Real theta_surf    "Surface tangent angle [rad]";
  Real kappa_surf    "Surface curvature [1/m]";

  // === Contact and pad forces ===
  Real delta_1       "Pad 1 deflection [m]";
  Real delta_2       "Pad 2 deflection [m]";
  Real F_pad1        "Pad 1 contact force [N]";
  Real F_pad2        "Pad 2 contact force [N]";
  Real F_normal      "Normal gripping force per finger [N]";
  Real F_normal_total "Total normal gripping force [N]";
  Real contact_metric "Continuous contact metric [0..1]";

  // === Friction ===
  Real F_fric        "Tangential friction force on gripper [N]";

  // === End-stop forces ===
  Real F_stop1       "End-stop force finger 1 [N]";
  Real F_stop2       "End-stop force finger 2 [N]";

  // === Actuator commands ===
  Real F_cmd1_raw    "Raw finger 1 command [N]";
  Real F_cmd2_raw    "Raw finger 2 command [N]";
  Real F_cmd1        "Saturated finger 1 command [N]";
  Real F_cmd2        "Saturated finger 2 command [N]";
  Real F_tang_cmd_raw "Raw tangential command [N]";
  Real F_tang_cmd    "Tangential command [N]";
  Real F_ff          "Tangential feedforward force [N]";

  // === Trajectory ===
  Real s_ref         "Reference path position [m]";
  Real v_ref         "Reference path velocity [m/s]";
  Real s_err         "Path tracking error [m]";
  Real s_err_abs     "Absolute path tracking error [m]";

  // === Disturbance ===
  Real F_dist        "Surface-force disturbance [N]";

  // === Sensors ===
  Real enc_f1        "Joint encoder finger 1 [m]";
  Real enc_f2        "Joint encoder finger 2 [m]";
  Real wrench_t      "Wrist wrench tangential component [N]";
  Real wrench_n      "Wrist wrench normal component [N]";
  Real tool_tip_s    "Tool-tip path coordinate [m]";
  Real tool_tip_n    "Tool-tip normal offset [m]";
  Real tool_tip_x    "Tool-tip Cartesian x [m]";
  Real tool_tip_y    "Tool-tip Cartesian y [m]";

  // === Derived and bound-check quantities ===
  Real m_total       "Total gripper mass [kg]";
  Real F_normal_err  "Normal force error [N]";
  Real F_lo_viol     "Normal force below 12 N violation [N]";
  Real F_hi_viol     "Normal force above 30 N violation [N]";
  Real track_err_metric "Tracking error metric [m]";
  Real effort_viol1  "Finger 1 effort bound violation [N]";
  Real effort_viol2  "Finger 2 effort bound violation [N]";
  Real joint_viol1_lo "Finger 1 lower joint bound violation [m]";
  Real joint_viol1_hi "Finger 1 upper joint bound violation [m]";
  Real joint_viol2_lo "Finger 2 lower joint bound violation [m]";
  Real joint_viol2_hi "Finger 2 upper joint bound violation [m]";

equation
  // === Total mass ===
  m_total = m_palm + 2.0 * m_finger;

  // === Surface geometry (cosine profile) ===
  y_surf = A_surf * cos(k_surf * s);
  theta_surf = atan(-A_surf * k_surf * sin(k_surf * s));
  kappa_surf = (-A_surf * k_surf * k_surf * cos(k_surf * s))
    / sqrt((1.0 + (A_surf * k_surf * sin(k_surf * s)) * (A_surf * k_surf * sin(k_surf * s))) ^ 3);

  // === Pad contact (compliant normal contact) ===
  delta_1 = max(0.0, d_f1 - d_contact);
  delta_2 = max(0.0, d_f2 - d_contact);
  F_pad1 = k_pad * delta_1 + c_pad * v_f1 * delta_1 / (delta_1 + eps_smooth);
  F_pad2 = k_pad * delta_2 + c_pad * v_f2 * delta_2 / (delta_2 + eps_smooth);
  F_normal = (F_pad1 + F_pad2) / 2.0;
  F_normal_total = F_pad1 + F_pad2;
  contact_metric = (delta_1 / (delta_1 + eps_smooth))
                 * (delta_2 / (delta_2 + eps_smooth));

  // === Friction (Coulomb, regularized) ===
  F_fric = mu * F_normal_total * v_s
         / sqrt(v_s * v_s + v_eps * v_eps);

  // === End-stop forces (soft joint bounds) ===
  F_stop1 = k_stop * max(0.0, -d_f1)
          - c_stop * v_f1 * max(0.0, -d_f1) / (max(0.0, -d_f1) + eps_smooth)
          - k_stop * max(0.0, d_f1 - L_travel)
          - c_stop * v_f1 * max(0.0, d_f1 - L_travel)
                     / (max(0.0, d_f1 - L_travel) + eps_smooth);
  F_stop2 = k_stop * max(0.0, -d_f2)
          - c_stop * v_f2 * max(0.0, -d_f2) / (max(0.0, -d_f2) + eps_smooth)
          - k_stop * max(0.0, d_f2 - L_travel)
          - c_stop * v_f2 * max(0.0, d_f2 - L_travel)
                     / (max(0.0, d_f2 - L_travel) + eps_smooth);

  // === Trajectory reference ===
  s_ref = L_path * time / T_total;
  v_ref = L_path / T_total;
  s_err = s - s_ref;
  s_err_abs = abs(s_err);

  // === Disturbance (middle third of scenario) ===
  F_dist = if time >= t_dist_start then
             (if time <= t_dist_end then F_dist_mag else 0.0)
           else 0.0;

  // === Feedforward ===
  F_ff = mu * 2.0 * F_normal_ref;

  // === Tangential trajectory control (PI + D + feedforward) ===
  der(s_int) = s_ref - s;
  F_tang_cmd_raw = kp_tang * (s_ref - s)
                 + ki_tang * s_int
                 + kd_tang * (v_ref - v_s)
                 + F_ff;
  F_tang_cmd = F_tang_cmd_raw;

  // === Normal-force regulation ===
  F_normal_err = F_normal_ref - F_normal;
  F_cmd1_raw = F_normal_ref + kp_force * (F_normal_ref - F_pad1)
             - kd_force * v_f1;
  F_cmd2_raw = F_normal_ref + kp_force * (F_normal_ref - F_pad2)
             - kd_force * v_f2;
  F_cmd1 = max(-F_cmd_max, min(F_cmd_max, F_cmd1_raw));
  F_cmd2 = max(-F_cmd_max, min(F_cmd_max, F_cmd2_raw));

  // === Plant dynamics: gripper along surface path ===
  der(s) = v_s;
  m_total * der(v_s) = F_tang_cmd - F_fric - F_dist;

  // === Plant dynamics: finger prismatic joints ===
  der(d_f1) = v_f1;
  m_finger * der(v_f1) = F_cmd1 - F_pad1 + F_stop1;
  der(d_f2) = v_f2;
  m_finger * der(v_f2) = F_cmd2 - F_pad2 + F_stop2;

  // === Sensors ===
  enc_f1 = d_f1;
  enc_f2 = d_f2;
  wrench_t = F_tang_cmd;
  wrench_n = F_normal_total;
  tool_tip_s = s;
  tool_tip_n = 0.0;
  tool_tip_x = s;
  tool_tip_y = y_surf;

  // === Bound-check indicators ===
  F_lo_viol = max(0.0, 12.0 - F_normal);
  F_hi_viol = max(0.0, F_normal - 30.0);
  track_err_metric = s_err_abs;
  effort_viol1 = max(0.0, abs(F_cmd1_raw) - F_cmd_max);
  effort_viol2 = max(0.0, abs(F_cmd2_raw) - F_cmd_max);
  joint_viol1_lo = max(0.0, -d_f1);
  joint_viol1_hi = max(0.0, d_f1 - L_travel);
  joint_viol2_lo = max(0.0, -d_f2);
  joint_viol2_hi = max(0.0, d_f2 - L_travel);

  annotation (
    experiment(StartTime = 0, StopTime = 8.0, Tolerance = 1e-6,
               Interval = 0.0125),
    Documentation(info = "ParallelGripPolishA: contact-rich manipulation system.
      Fixed 6 kg palm with two 0.5 kg opposing box fingers on 0.05 m prismatic joints
      and compliant pads. Bounded linear finger actuators (32.4 N per finger).
      Follows 0.50 m curved surface path with constant 20 N normal gripping force.
      Friction coefficient 0.50. Tangential PI+D trajectory control with
      normal-force regulation. 3.5 N disturbance during middle third (2.67-5.33 s).
      Control loop 80 Hz, simulation 8 s. Normal force 12-30 N, tracking error < 0.027 m
      after 5.2 s, continuous contact enforced.")
  );
end ParallelGripPolishA;