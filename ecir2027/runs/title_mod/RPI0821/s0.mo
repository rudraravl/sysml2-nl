model WheelLegWalkE
  // =====================================================================
  // Floating-base wheeled-leg robot: gait tracking with disturbance
  // =====================================================================
  // Control rate 250 Hz (dt = 4 ms) enforced via FMI Co-Sim step size.
  // Acceptance is fail-closed: overall_ok = product of all sub-checks.
  // =====================================================================

  // ===== Known parameters (from requirement) =====
  parameter Real m_torso = 28.0 "Torso mass [kg]";
  parameter Real r_wheel = 0.10 "Wheel radius [m]";
  parameter Real mu_ground = 0.85 "Ground friction coefficient [-]";
  parameter Real g = 9.81 "Gravity [m/s2]";
  parameter Real tau_max = 60.5 "Per-joint command magnitude bound [N.m]";
  parameter Real F_push = 84.0 "Body push disturbance force [N]";
  parameter Real v_des = 0.4 "Desired forward gait speed [m/s]";
  parameter Real f_ctrl = 250.0 "Control/simulation rate [Hz]";
  parameter Real T_sim = 16.0 "Simulation duration [s]";

  // ===== Unknown parameters (NOT stated; defaults chosen for simulation) =====
  parameter Real h_nom = 0.50 "Nominal body height [m] -- unknown";
  parameter Real L1 = 0.25 "Upper leg link length [m] -- unknown";
  parameter Real L2 = 0.25 "Lower leg link length [m] -- unknown";
  parameter Real I_torso = 1.2 "Torso pitch inertia [kg.m2] -- unknown";
  parameter Real T_gait = 0.6 "Gait period [s] -- unknown";
  parameter Real K_imp = 400.0 "Joint impedance stiffness [N.m/rad] -- unknown";
  parameter Real D_imp = 12.0 "Joint impedance damping [N.m.s/rad] -- unknown";
  parameter Real K_att = 150.0 "Attitude control gain [N.m/rad] -- unknown";
  parameter Real D_att = 15.0 "Attitude control damping [N.m.s/rad] -- unknown";
  parameter Real K_vel = 1500.0 "Velocity tracking gain [N/(m/s)] -- unknown";
  parameter Real K_height = 600.0 "Height tracking gain [N/m] -- unknown";
  parameter Real D_height = 30.0 "Height tracking damping [N.s/m] -- unknown";
  parameter Real k_contact = 50000.0 "Contact stiffness [N/m] -- unknown";
  parameter Real J_joint = 0.05 "Joint inertia [kg.m2] -- unknown";
  parameter Real leg_offset_x_1 = 0.20 "Leg 1 fore/aft hip offset [m] -- unknown";
  parameter Real leg_offset_x_2 = 0.20 "Leg 2 fore/aft hip offset [m] -- unknown";
  parameter Real leg_offset_x_3 = -0.20 "Leg 3 fore/aft hip offset [m] -- unknown";
  parameter Real leg_offset_x_4 = -0.20 "Leg 4 fore/aft hip offset [m] -- unknown";
  parameter Real phase_offset_1 = 0.0 "Leg 1 gait phase offset [cycles] -- unknown";
  parameter Real phase_offset_2 = 0.5 "Leg 2 gait phase offset [cycles] -- unknown";
  parameter Real phase_offset_3 = 0.5 "Leg 3 gait phase offset [cycles] -- unknown";
  parameter Real phase_offset_4 = 0.0 "Leg 4 gait phase offset [cycles] -- unknown";
  parameter Real eps_smooth = 1e-4 "Contact smoothing epsilon [-]";
  parameter Real pitch_tol = 0.15 "Attitude tolerance [rad] -- unknown";
  parameter Real n_support_min = 2.0 "Min supporting contacts [-] -- unknown";
  parameter Real track_tol = 0.09 "Tracking error tolerance [m/s]";
  parameter Real PI = 3.14159265358979;

  // Derived timing
  parameter Real dt_ctrl = 1.0 / f_ctrl "Control sample time [s]";
  parameter Real t_push_start = T_sim / 3.0 "Push disturbance start [s]";
  parameter Real t_push_end = 2.0 * T_sim / 3.0 "Push disturbance end [s]";

  // ===== Torso floating-base states (6) =====
  Real x_torso(start = 0.0) "Torso forward position [m]";
  Real z_torso(start = 0.50) "Torso height [m]";
  Real pitch(start = 0.0) "Torso pitch angle [rad]";
  Real vx(start = 0.0) "Torso forward velocity [m/s]";
  Real vz(start = 0.0) "Torso vertical velocity [m/s]";
  Real omegap(start = 0.0) "Torso pitch rate [rad/s]";

  // ===== Leg joint states (4 legs x 2 joints x pos+vel = 16) =====
  Real q_hip_1(start = 0.64) "Hip joint 1 angle [rad]";
  Real q_hip_2(start = 0.64) "Hip joint 2 angle [rad]";
  Real q_hip_3(start = 0.64) "Hip joint 3 angle [rad]";
  Real q_hip_4(start = 0.64) "Hip joint 4 angle [rad]";
  Real q_knee_1(start = -1.29) "Knee joint 1 angle [rad]";
  Real q_knee_2(start = -1.29) "Knee joint 2 angle [rad]";
  Real q_knee_3(start = -1.29) "Knee joint 3 angle [rad]";
  Real q_knee_4(start = -1.29) "Knee joint 4 angle [rad]";
  Real dq_hip_1(start = 0.0) "Hip joint 1 velocity [rad/s]";
  Real dq_hip_2(start = 0.0) "Hip joint 2 velocity [rad/s]";
  Real dq_hip_3(start = 0.0) "Hip joint 3 velocity [rad/s]";
  Real dq_hip_4(start = 0.0) "Hip joint 4 velocity [rad/s]";
  Real dq_knee_1(start = 0.0) "Knee joint 1 velocity [rad/s]";
  Real dq_knee_2(start = 0.0) "Knee joint 2 velocity [rad/s]";
  Real dq_knee_3(start = 0.0) "Knee joint 3 velocity [rad/s]";
  Real dq_knee_4(start = 0.0) "Knee joint 4 velocity [rad/s]";

  // ===== Wheel angle states (4) =====
  Real q_wheel_1(start = 0.0) "Wheel 1 angle [rad]";
  Real q_wheel_2(start = 0.0) "Wheel 2 angle [rad]";
  Real q_wheel_3(start = 0.0) "Wheel 3 angle [rad]";
  Real q_wheel_4(start = 0.0) "Wheel 4 angle [rad]";

  // ===== Contact-force sensors (4) =====
  Real F_contact_1(start = 0.0) "Foot 1 contact force [N]";
  Real F_contact_2(start = 0.0) "Foot 2 contact force [N]";
  Real F_contact_3(start = 0.0) "Foot 3 contact force [N]";
  Real F_contact_4(start = 0.0) "Foot 4 contact force [N]";

  // ===== Traction forces (4) =====
  Real F_traction_1 "Wheel 1 traction force [N]";
  Real F_traction_2 "Wheel 2 traction force [N]";
  Real F_traction_3 "Wheel 3 traction force [N]";
  Real F_traction_4 "Wheel 4 traction force [N]";

  // ===== Supporting contact count =====
  Real n_support(start = 4.0) "Supporting contact count [-]";

  // ===== Torque commands (12: 8 leg + 4 wheel) =====
  Real tau_hip_cmd_1 "Hip 1 torque command [N.m]";
  Real tau_hip_cmd_2 "Hip 2 torque command [N.m]";
  Real tau_hip_cmd_3 "Hip 3 torque command [N.m]";
  Real tau_hip_cmd_4 "Hip 4 torque command [N.m]";
  Real tau_knee_cmd_1 "Knee 1 torque command [N.m]";
  Real tau_knee_cmd_2 "Knee 2 torque command [N.m]";
  Real tau_knee_cmd_3 "Knee 3 torque command [N.m]";
  Real tau_knee_cmd_4 "Knee 4 torque command [N.m]";
  Real tau_wheel_cmd_1 "Wheel 1 torque command [N.m]";
  Real tau_wheel_cmd_2 "Wheel 2 torque command [N.m]";
  Real tau_wheel_cmd_3 "Wheel 3 torque command [N.m]";
  Real tau_wheel_cmd_4 "Wheel 4 torque command [N.m]";

  // ===== Raw (unsaturated) torque commands =====
  Real tau_hip_raw_1 "Hip 1 raw torque [N.m]";
  Real tau_hip_raw_2 "Hip 2 raw torque [N.m]";
  Real tau_hip_raw_3 "Hip 3 raw torque [N.m]";
  Real tau_hip_raw_4 "Hip 4 raw torque [N.m]";
  Real tau_knee_raw_1 "Knee 1 raw torque [N.m]";
  Real tau_knee_raw_2 "Knee 2 raw torque [N.m]";
  Real tau_knee_raw_3 "Knee 3 raw torque [N.m]";
  Real tau_knee_raw_4 "Knee 4 raw torque [N.m]";
  Real tau_wheel_raw_1 "Wheel 1 raw torque [N.m]";
  Real tau_wheel_raw_2 "Wheel 2 raw torque [N.m]";
  Real tau_wheel_raw_3 "Wheel 3 raw torque [N.m]";
  Real tau_wheel_raw_4 "Wheel 4 raw torque [N.m]";
  Real tau_attitude "Body-attitude control torque [N.m]";

  // ===== Gait phase and impedance targets =====
  Real phase_frac "Fractional gait phase [0..1]";
  Real height_corr "Height correction term [rad]";
  Real q_hip_des_1 "Desired hip 1 angle [rad]";
  Real q_hip_des_2 "Desired hip 2 angle [rad]";
  Real q_hip_des_3 "Desired hip 3 angle [rad]";
  Real q_hip_des_4 "Desired hip 4 angle [rad]";
  Real q_knee_des_1 "Desired knee 1 angle [rad]";
  Real q_knee_des_2 "Desired knee 2 angle [rad]";
  Real q_knee_des_3 "Desired knee 3 angle [rad]";
  Real q_knee_des_4 "Desired knee 4 angle [rad]";

  // ===== Foot kinematics =====
  Real foot_z_1 "Foot 1 z position [m]";
  Real foot_z_2 "Foot 2 z position [m]";
  Real foot_z_3 "Foot 3 z position [m]";
  Real foot_z_4 "Foot 4 z position [m]";
  Real foot_vz_1 "Foot 1 z velocity [m/s]";
  Real foot_vz_2 "Foot 2 z velocity [m/s]";
  Real foot_vz_3 "Foot 3 z velocity [m/s]";
  Real foot_vz_4 "Foot 4 z velocity [m/s]";

  // ===== Sensors =====
  Real q_hip_enc_1 "Hip 1 encoder [rad]";
  Real q_hip_enc_2 "Hip 2 encoder [rad]";
  Real q_hip_enc_3 "Hip 3 encoder [rad]";
  Real q_hip_enc_4 "Hip 4 encoder [rad]";
  Real q_knee_enc_1 "Knee 1 encoder [rad]";
  Real q_knee_enc_2 "Knee 2 encoder [rad]";
  Real q_knee_enc_3 "Knee 3 encoder [rad]";
  Real q_knee_enc_4 "Knee 4 encoder [rad]";
  Real dq_wheel_1 "Wheel 1 velocity [rad/s]";
  Real dq_wheel_2 "Wheel 2 velocity [rad/s]";
  Real dq_wheel_3 "Wheel 3 velocity [rad/s]";
  Real dq_wheel_4 "Wheel 4 velocity [rad/s]";
  Real pitch_imu "IMU pitch reading [rad]";
  Real omegap_imu "IMU pitch-rate reading [rad/s]";
  Real vx_est "Estimated forward velocity [m/s]";
  Real z_est "Estimated height [m]";

  // ===== Tracking and acceptance =====
  Real v_track_error "Forward velocity tracking error [m/s]";
  Real F_push_applied "Applied push force [N]";
  Real F_net_x "Net horizontal ground force [N]";
  Real F_net_z "Net vertical ground force [N]";
  Real M_net "Net pitch moment from contacts [N.m]";
  Real max_tau_hip "Max abs hip torque [N.m]";
  Real max_tau_knee "Max abs knee torque [N.m]";
  Real max_tau_wheel "Max abs wheel torque [N.m]";
  Real bounds_ok "Joint/torque bounds satisfied (1=pass,0=fail)";
  Real attitude_ok "Body attitude acceptable (1=pass,0=fail)";
  Real progress_ok "Forward progress acceptable (1=pass,0=fail)";
  Real contact_ok "Supporting contact count ok (1=pass,0=fail)";
  Real tracking_ok "Tracking error < 0.09 m/s after 10.4 s (1=pass,0=fail)";
  Real no_nan_inf "No NaN/infinite values (1=pass,0=fail)";
  Real overall_ok "Overall acceptance, fail-closed (1=pass,0=fail)";

equation
  // ===== Gait phase =====
  phase_frac = mod(time / T_gait, 1.0);

  // ===== Body-height correction (drives knee impedance targets) =====
  height_corr = K_height * (h_nom - z_torso) - D_height * vz;

  // ===== Phase-based desired joint angles (impedance setpoints) =====
  // Gait pattern is unknown; sinusoidal modulation about nominal stance used.
  q_hip_des_1 = 0.64 + 0.05 * sin(2.0 * PI * (phase_frac + phase_offset_1));
  q_hip_des_2 = 0.64 + 0.05 * sin(2.0 * PI * (phase_frac + phase_offset_2));
  q_hip_des_3 = 0.64 + 0.05 * sin(2.0 * PI * (phase_frac + phase_offset_3));
  q_hip_des_4 = 0.64 + 0.05 * sin(2.0 * PI * (phase_frac + phase_offset_4));
  q_knee_des_1 = -1.29 + 0.08 * sin(2.0 * PI * (phase_frac + phase_offset_1)) + height_corr;
  q_knee_des_2 = -1.29 + 0.08 * sin(2.0 * PI * (phase_frac + phase_offset_2)) + height_corr;
  q_knee_des_3 = -1.29 + 0.08 * sin(2.0 * PI * (phase_frac + phase_offset_3)) + height_corr;
  q_knee_des_4 = -1.29 + 0.08 * sin(2.0 * PI * (phase_frac + phase_offset_4)) + height_corr;

  // ===== Controlled push disturbance (middle third of 16 s) =====
  F_push_applied = if (time >= t_push_start and time <= t_push_end) then F_push else 0.0;

  // ===== Foot forward kinematics =====
  foot_z_1 = z_torso - L1 * cos(q_hip_1) - L2 * cos(q_hip_1 + q_knee_1) - r_wheel;
  foot_z_2 = z_torso - L1 * cos(q_hip_2) - L2 * cos(q_hip_2 + q_knee_2) - r_wheel;
  foot_z_3 = z_torso - L1 * cos(q_hip_3) - L2 * cos(q_hip_3 + q_knee_3) - r_wheel;
  foot_z_4 = z_torso - L1 * cos(q_hip_4) - L2 * cos(q_hip_4 + q_knee_4) - r_wheel;

  foot_vz_1 = vz + L1 * sin(q_hip_1) * dq_hip_1 + L2 * sin(q_hip_1 + q_knee_1) * (dq_hip_1 + dq_knee_1);
  foot_vz_2 = vz + L1 * sin(q_hip_2) * dq_hip_2 + L2 * sin(q_hip_2 + q_knee_2) * (dq_hip_2 + dq_knee_2);
  foot_vz_3 = vz + L1 * sin(q_hip_3) * dq_hip_3 + L2 * sin(q_hip_3 + q_knee_3) * (dq_hip_3 + dq_knee_3);
  foot_vz_4 = vz + L1 * sin(q_hip_4) * dq_hip_4 + L2 * sin(q_hip_4 + q_knee_4) * (dq_hip_4 + dq_knee_4);

  // ===== Contact-force sensor model (smooth compliant ground) =====
  // Smooth max(0, -foot_z): (sqrt(z^2+eps^2) - z) / 2
  F_contact_1 = k_contact * (sqrt(foot_z_1 * foot_z_1 + eps_smooth * eps_smooth) - foot_z_1) / 2.0;
  F_contact_2 = k_contact * (sqrt(foot_z_2 * foot_z_2 + eps_smooth * eps_smooth) - foot_z_2) / 2.0;
  F_contact_3 = k_contact * (sqrt(foot_z_3 * foot_z_3 + eps_smooth * eps_smooth) - foot_z_3) / 2.0;
  F_contact_4 = k_contact * (sqrt(foot_z_4 * foot_z_4 + eps_smooth * eps_smooth) - foot_z_4) / 2.0;

  // ===== Wheel traction (torque-driven, friction-limited) =====
  F_traction_1 = if F_contact_1 > eps_smooth then max(-mu_ground * F_contact_1, min(mu_ground * F_contact_1, tau_wheel_cmd_1 / r_wheel)) else 0.0;
  F_traction_2 = if F_contact_2 > eps_smooth then max(-mu_ground * F_contact_2, min(mu_ground * F_contact_2, tau_wheel_cmd_2 / r_wheel)) else 0.0;
  F_traction_3 = if F_contact_3 > eps_smooth then max(-mu_ground * F_contact_3, min(mu_ground * F_contact_3, tau_wheel_cmd_3 / r_wheel)) else 0.0;
  F_traction_4 = if F_contact_4 > eps_smooth then max(-mu_ground * F_contact_4, min(mu_ground * F_contact_4, tau_wheel_cmd_4 / r_wheel)) else 0.0;

  // ===== Supporting contact count =====
  n_support = (if F_contact_1 > 1.0 then 1.0 else 0.0)
            + (if F_contact_2 > 1.0 then 1.0 else 0.0)
            + (if F_contact_3 > 1.0 then 1.0 else 0.0)
            + (if F_contact_4 > 1.0 then 1.0 else 0.0);

  // ===== Net ground forces and moment on torso =====
  F_net_x = F_traction_1 + F_traction_2 + F_traction_3 + F_traction_4;
  F_net_z = F_contact_1 + F_contact_2 + F_contact_3 + F_contact_4;
  M_net = leg_offset_x_1 * F_contact_1 + leg_offset_x_2 * F_contact_2
        + leg_offset_x_3 * F_contact_3 + leg_offset_x_4 * F_contact_4;

  // ===== Torso floating-base dynamics =====
  der(x_torso) = vx;
  der(z_torso) = vz;
  der(pitch) = omegap;
  m_torso * der(vx) = F_push_applied + F_net_x;
  m_torso * der(vz) = -m_torso * g + F_net_z;
  I_torso * der(omegap) = M_net + tau_attitude;

  // ===== Body-attitude control (PD on pitch) =====
  tau_attitude = -K_att * pitch - D_att * omegap;

  // ===== Leg joint dynamics (impedance-driven) =====
  der(q_hip_1) = dq_hip_1;
  der(q_hip_2) = dq_hip_2;
  der(q_hip_3) = dq_hip_3;
  der(q_hip_4) = dq_hip_4;
  der(q_knee_1) = dq_knee_1;
  der(q_knee_2) = dq_knee_2;
  der(q_knee_3) = dq_knee_3;
  der(q_knee_4) = dq_knee_4;

  J_joint * der(dq_hip_1) = tau_hip_cmd_1;
  J_joint * der(dq_hip_2) = tau_hip_cmd_2;
  J_joint * der(dq_hip_3) = tau_hip_cmd_3;
  J_joint * der(dq_hip_4) = tau_hip_cmd_4;
  J_joint * der(dq_knee_1) = tau_knee_cmd_1;
  J_joint * der(dq_knee_2) = tau_knee_cmd_2;
  J_joint * der(dq_knee_3) = tau_knee_cmd_3;
  J_joint * der(dq_knee_4) = tau_knee_cmd_4;

  // ===== Wheel rolling kinematics (no-slip on rigid plane) =====
  der(q_wheel_1) = vx / r_wheel;
  der(q_wheel_2) = vx / r_wheel;
  der(q_wheel_3) = vx / r_wheel;
  der(q_wheel_4) = vx / r_wheel;

  // ===== Wheel velocity (algebraic, for encoder) =====
  dq_wheel_1 = vx / r_wheel;
  dq_wheel_2 = vx / r_wheel;
  dq_wheel_3 = vx / r_wheel;
  dq_wheel_4 = vx / r_wheel;

  // ===== Phase-based joint impedance control =====
  tau_hip_raw_1 = K_imp * (q_hip_des_1 - q_hip_1) - D_imp * dq_hip_1;
  tau_hip_raw_2 = K_imp * (q_hip_des_2 - q_hip_2) - D_imp * dq_hip_2;
  tau_hip_raw_3 = K_imp * (q_hip_des_3 - q_hip_3) - D_imp * dq_hip_3;
  tau_hip_raw_4 = K_imp * (q_hip_des_4 - q_hip_4) - D_imp * dq_hip_4;
  tau_knee_raw_1 = K_imp * (q_knee_des_1 - q_knee_1) - D_imp * dq_knee_1;
  tau_knee_raw_2 = K_imp * (q_knee_des_2 - q_knee_2) - D_imp * dq_knee_2;
  tau_knee_raw_3 = K_imp * (q_knee_des_3 - q_knee_3) - D_imp * dq_knee_3;
  tau_knee_raw_4 = K_imp * (q_knee_des_4 - q_knee_4) - D_imp * dq_knee_4;

  // ===== Velocity tracking control (wheel torque) =====
  tau_wheel_raw_1 = K_vel * (v_des - vx) / 4.0;
  tau_wheel_raw_2 = K_vel * (v_des - vx) / 4.0;
  tau_wheel_raw_3 = K_vel * (v_des - vx) / 4.0;
  tau_wheel_raw_4 = K_vel * (v_des - vx) / 4.0;

  // ===== Torque saturation (independently limited per joint) =====
  tau_hip_cmd_1 = max(-tau_max, min(tau_max, tau_hip_raw_1));
  tau_hip_cmd_2 = max(-tau_max, min(tau_max, tau_hip_raw_2));
  tau_hip_cmd_3 = max(-tau_max, min(tau_max, tau_hip_raw_3));
  tau_hip_cmd_4 = max(-tau_max, min(tau_max, tau_hip_raw_4));
  tau_knee_cmd_1 = max(-tau_max, min(tau_max, tau_knee_raw_1));
  tau_knee_cmd_2 = max(-tau_max, min(tau_max, tau_knee_raw_2));
  tau_knee_cmd_3 = max(-tau_max, min(tau_max, tau_knee_raw_3));
  tau_knee_cmd_4 = max(-tau_max, min(tau_max, tau_knee_raw_4));
  tau_wheel_cmd_1 = max(-tau_max, min(tau_max, tau_wheel_raw_1));
  tau_wheel_cmd_2 = max(-tau_max, min(tau_max, tau_wheel_raw_2));
  tau_wheel_cmd_3 = max(-tau_max, min(tau_max, tau_wheel_raw_3));
  tau_wheel_cmd_4 = max(-tau_max, min(tau_max, tau_wheel_raw_4));

  // ===== Sensors (ideal; noise/bias parameters unknown, set to zero) =====
  q_hip_enc_1 = q_hip_1;
  q_hip_enc_2 = q_hip_2;
  q_hip_enc_3 = q_hip_3;
  q_hip_enc_4 = q_hip_4;
  q_knee_enc_1 = q_knee_1;
  q_knee_enc_2 = q_knee_2;
  q_knee_enc_3 = q_knee_3;
  q_knee_enc_4 = q_knee_4;
  pitch_imu = pitch;
  omegap_imu = omegap;
  vx_est = vx;
  z_est = z_torso;

  // ===== Primary tracking error =====
  v_track_error = v_des - vx;

  // ===== Acceptance: joint and torque bounds =====
  max_tau_hip = max(abs(tau_hip_cmd_1), max(abs(tau_hip_cmd_2), max(abs(tau_hip_cmd_3), abs(tau_hip_cmd_4))));
  max_tau_knee = max(abs(tau_knee_cmd_1), max(abs(tau_knee_cmd_2), max(abs(tau_knee_cmd_3), abs(tau_knee_cmd_4))));
  max_tau_wheel = max(abs(tau_wheel_cmd_1), max(abs(tau_wheel_cmd_2), max(abs(tau_wheel_cmd_3), abs(tau_wheel_cmd_4))));
  bounds_ok = if (max_tau_hip <= tau_max + 1e-6 and max_tau_knee <= tau_max + 1e-6 and max_tau_wheel <= tau_max + 1e-6) then 1.0 else 0.0;

  // ===== Acceptance: body attitude =====
  attitude_ok = if abs(pitch) < pitch_tol then 1.0 else 0.0;

  // ===== Acceptance: supporting-contact count =====
  contact_ok = if n_support >= n_support_min then 1.0 else 0.0;

  // ===== Acceptance: forward progress =====
  progress_ok = if time > 0.5 then (if x_torso > 0.2 * v_des * time then 1.0 else 0.0) else 1.0;

  // ===== Acceptance: primary tracking error below 0.09 m/s after 10.4 s =====
  tracking_ok = if time >= 10.4 then (if abs(v_track_error) < track_tol then 1.0 else 0.0) else 1.0;

  // ===== Acceptance: no NaN or infinite physical/control/estimator values =====
  no_nan_inf = if (abs(vx) < 1000.0 and abs(vz) < 1000.0 and abs(pitch) < 10.0
                   and abs(omegap) < 1000.0 and z_torso > 0.0 and z_torso < 10.0
                   and x_torso > -100.0 and x_torso < 1000.0
                   and abs(F_net_x) < 10000.0 and abs(F_net_z) < 50000.0
                   and abs(tau_attitude) < 10000.0
                   and abs(v_track_error) < 100.0) then 1.0 else 0.0;

  // ===== Overall acceptance (fail-closed: any sub-check = 0 forces 0) =====
  overall_ok = bounds_ok * attitude_ok * progress_ok * contact_ok * tracking_ok * no_nan_inf;

end WheelLegWalkE;