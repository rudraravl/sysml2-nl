model JointPathMoveE
  "Three-revolute-joint (Z-Y-Y) arm executing synchronized cubic point-to-point trajectory with PID+FF control at 250 Hz and 6% payload disturbance"

  // ===== Physical structure parameters =====
  parameter Real L1 = 0.50 "Link 1 length [m]";
  parameter Real L2 = 0.38 "Link 2 length [m]";
  parameter Real L3 = 0.24 "Link 3 length [m]";
  parameter Real g_acc = 9.81 "Gravitational acceleration [m/s^2]";

  // Link and payload masses (assumed for dynamics; not stated in requirement)
  parameter Real m1 = 2.0 "Link 1 mass [kg]";
  parameter Real m2 = 1.5 "Link 2 mass [kg]";
  parameter Real m3 = 1.0 "Link 3 mass [kg]";
  parameter Real mp_nom = 0.50 "Nominal payload mass [kg]";

  // Joint inertias (effective lumped)
  parameter Real J1 = 0.80 "Joint 1 effective inertia [kg.m^2]";
  parameter Real J2 = 0.40 "Joint 2 effective inertia [kg.m^2]";
  parameter Real J3 = 0.12 "Joint 3 effective inertia [kg.m^2]";

  // Joint damping
  parameter Real b1 = 0.20 "Joint 1 viscous damping [N.m.s/rad]";
  parameter Real b2 = 0.15 "Joint 2 viscous damping [N.m.s/rad]";
  parameter Real b3 = 0.08 "Joint 3 viscous damping [N.m.s/rad]";

  // ===== Control parameters =====
  parameter Real Kp1 = 80.0 "Joint 1 proportional gain [N.m/rad]";
  parameter Real Kp2 = 80.0 "Joint 2 proportional gain [N.m/rad]";
  parameter Real Kp3 = 60.0 "Joint 3 proportional gain [N.m/rad]";
  parameter Real Kd1 = 12.0 "Joint 1 derivative gain [N.m.s/rad]";
  parameter Real Kd2 = 12.0 "Joint 2 derivative gain [N.m.s/rad]";
  parameter Real Kd3 = 8.0  "Joint 3 derivative gain [N.m.s/rad]";
  parameter Real Ki1 = 15.0 "Joint 1 integral gain [N.m/(rad.s)]";
  parameter Real Ki2 = 15.0 "Joint 2 integral gain [N.m/(rad.s)]";
  parameter Real Ki3 = 10.0 "Joint 3 integral gain [N.m/(rad.s)]";
  parameter Real Kvff1 = 0.20 "Joint 1 velocity feedforward gain [N.m.s/rad]";
  parameter Real Kvff2 = 0.15 "Joint 2 velocity feedforward gain [N.m.s/rad]";
  parameter Real Kvff3 = 0.08 "Joint 3 velocity feedforward gain [N.m.s/rad]";
  parameter Real tau_max = 93.5 "Maximum torque magnitude per joint [N.m]";
  parameter Real Ts = 0.004 "Control sample period [s] (250 Hz)";
  parameter Real int_max = 5.0 "Integral anti-windup clamp magnitude [rad.s]";

  // ===== Trajectory waypoints =====
  parameter Real t_mid = 16.0 / 3.0 "Midpoint arrival time [s]";
  parameter Real t_final = 32.0 / 3.0 "Final arrival time [s]";
  parameter Real T_end = 16.0 "Total run duration [s]";

  parameter Real q1_0 = 0.0 "Start position joint 1 [rad]";
  parameter Real q1_m = Modelica.Constants.pi / 4.0 "Midpoint position joint 1 [rad]";
  parameter Real q1_f = Modelica.Constants.pi / 2.0 "Final position joint 1 [rad]";
  parameter Real q2_0 = 0.0 "Start position joint 2 [rad]";
  parameter Real q2_m = Modelica.Constants.pi / 6.0 "Midpoint position joint 2 [rad]";
  parameter Real q2_f = Modelica.Constants.pi / 3.0 "Final position joint 2 [rad]";
  parameter Real q3_0 = 0.0 "Start position joint 3 [rad]";
  parameter Real q3_m = Modelica.Constants.pi / 12.0 "Midpoint position joint 3 [rad]";
  parameter Real q3_f = Modelica.Constants.pi / 6.0 "Final position joint 3 [rad]";

  // ===== Acceptance bounds =====
  parameter Real pos_bound = Modelica.Constants.pi "Position bound [rad]";
  parameter Real vel_bound = 5.0 "Velocity bound [rad/s]";
  parameter Real acc_bound = 50.0 "Acceleration bound [rad/s^2]";
  parameter Real track_bound = 0.027 "Tracking error bound after 10.4 s [rad]";
  parameter Real settle_vel = 0.05 "Settling velocity threshold [rad/s]";
  parameter Real t_track_check = 10.4 "Tracking error check start time [s]";
  parameter Real finite_bound = 1e38 "Finite value check bound";

  // ===== Continuous states =====
  Real q1(start = q1_0, fixed = true) "Joint 1 position [rad]";
  Real q1d(start = 0.0, fixed = true) "Joint 1 velocity [rad/s]";
  Real q1dd "Joint 1 acceleration [rad/s^2]";
  Real q2(start = q2_0, fixed = true) "Joint 2 position [rad]";
  Real q2d(start = 0.0, fixed = true) "Joint 2 velocity [rad/s]";
  Real q2dd "Joint 2 acceleration [rad/s^2]";
  Real q3(start = q3_0, fixed = true) "Joint 3 position [rad]";
  Real q3d(start = 0.0, fixed = true) "Joint 3 velocity [rad/s]";
  Real q3dd "Joint 3 acceleration [rad/s^2]";

  // ===== Continuous trajectory references =====
  Real q1_ref "Reference position joint 1 [rad]";
  Real q2_ref "Reference position joint 2 [rad]";
  Real q3_ref "Reference position joint 3 [rad]";
  Real qd1_ref "Reference velocity joint 1 [rad/s]";
  Real qd2_ref "Reference velocity joint 2 [rad/s]";
  Real qd3_ref "Reference velocity joint 3 [rad/s]";
  Real qdd1_ref "Reference acceleration joint 1 [rad/s^2]";
  Real qdd2_ref "Reference acceleration joint 2 [rad/s^2]";
  Real qdd3_ref "Reference acceleration joint 3 [rad/s^2]";

  // ===== Payload =====
  Real mp "Payload mass [kg]";
  Real dpayload "Payload disturbance fraction";

  // ===== Gravity torques =====
  Real grav2 "Gravity torque joint 2 [N.m]";
  Real grav3 "Gravity torque joint 3 [N.m]";

  // ===== Collision geometry =====
  Real z_tip "End-effector height above base plane [m]";
  Real r_tip "End-effector radial reach from Z axis [m]";

  // ===== Tracking errors =====
  Real e1_track "Tracking error joint 1 [rad]";
  Real e2_track "Tracking error joint 2 [rad]";
  Real e3_track "Tracking error joint 3 [rad]";

  // ===== Discrete controller variables (250 Hz zero-order-hold) =====
  discrete Real tau1_cmd(start = 0.0) "Commanded torque joint 1 [N.m]";
  discrete Real tau2_cmd(start = 0.0) "Commanded torque joint 2 [N.m]";
  discrete Real tau3_cmd(start = 0.0) "Commanded torque joint 3 [N.m]";
  discrete Real tau1_raw_d "Raw unsaturated torque joint 1 [N.m]";
  discrete Real tau2_raw_d "Raw unsaturated torque joint 2 [N.m]";
  discrete Real tau3_raw_d "Raw unsaturated torque joint 3 [N.m]";
  discrete Real e1_int(start = 0.0) "Integral error joint 1 [rad.s]";
  discrete Real e2_int(start = 0.0) "Integral error joint 2 [rad.s]";
  discrete Real e3_int(start = 0.0) "Integral error joint 3 [rad.s]";
  discrete Real e1_int_raw "Unclamped integral error joint 1 [rad.s]";
  discrete Real e2_int_raw "Unclamped integral error joint 2 [rad.s]";
  discrete Real e3_int_raw "Unclamped integral error joint 3 [rad.s]";
  discrete Real q1_enc(start = 0.0) "Encoder position joint 1 [rad]";
  discrete Real q2_enc(start = 0.0) "Encoder position joint 2 [rad]";
  discrete Real q3_enc(start = 0.0) "Encoder position joint 3 [rad]";
  discrete Real qd1_enc(start = 0.0) "Encoder velocity joint 1 [rad/s]";
  discrete Real qd2_enc(start = 0.0) "Encoder velocity joint 2 [rad/s]";
  discrete Real qd3_enc(start = 0.0) "Encoder velocity joint 3 [rad/s]";
  discrete Real q1_ref_d "Sampled reference position joint 1 [rad]";
  discrete Real q2_ref_d "Sampled reference position joint 2 [rad]";
  discrete Real q3_ref_d "Sampled reference position joint 3 [rad]";
  discrete Real qd1_ref_d "Sampled reference velocity joint 1 [rad/s]";
  discrete Real qd2_ref_d "Sampled reference velocity joint 2 [rad/s]";
  discrete Real qd3_ref_d "Sampled reference velocity joint 3 [rad/s]";
  discrete Real qdd1_ref_d "Sampled reference acceleration joint 1 [rad/s^2]";
  discrete Real qdd2_ref_d "Sampled reference acceleration joint 2 [rad/s^2]";
  discrete Real qdd3_ref_d "Sampled reference acceleration joint 3 [rad/s^2]";
  discrete Real grav2_ff "Gravity feedforward joint 2 [N.m]";
  discrete Real grav3_ff "Gravity feedforward joint 3 [N.m]";
  discrete Real mp_d "Sampled payload mass [kg]";
  discrete Boolean sat1(start = false) "Joint 1 torque saturation flag";
  discrete Boolean sat2(start = false) "Joint 2 torque saturation flag";
  discrete Boolean sat3(start = false) "Joint 3 torque saturation flag";
  discrete Boolean fail_latch(start = false) "Latched acceptance failure";

  // ===== Acceptance flags =====
  Boolean pos_ok "Position bounds satisfied";
  Boolean vel_ok "Velocity bounds satisfied";
  Boolean acc_ok "Acceleration bounds satisfied";
  Boolean eff_ok "Effort bounds satisfied";
  Boolean settled "Terminal settling satisfied";
  Boolean tracking_ok "Tracking error bound satisfied after 10.4 s";
  Boolean finite_ok "All physical values finite";
  Boolean no_collision "No self-collision detected";
  Boolean accept "Overall acceptance (fail-closed)";

protected
  Real s_traj "Normalized trajectory phase parameter";

equation
  // ===== Cubic interpolation trajectory (zero endpoint velocities) =====
  if time < t_mid then
    // Phase 1: zero state -> midpoint
    s_traj = time / t_mid;
    q1_ref = q1_0 + (q1_m - q1_0) * (3.0 * s_traj * s_traj - 2.0 * s_traj * s_traj * s_traj);
    qd1_ref = (q1_m - q1_0) * (6.0 * s_traj - 6.0 * s_traj * s_traj) / t_mid;
    qdd1_ref = (q1_m - q1_0) * (6.0 - 12.0 * s_traj) / (t_mid * t_mid);
    q2_ref = q2_0 + (q2_m - q2_0) * (3.0 * s_traj * s_traj - 2.0 * s_traj * s_traj * s_traj);
    qd2_ref = (q2_m - q2_0) * (6.0 * s_traj - 6.0 * s_traj * s_traj) / t_mid;
    qdd2_ref = (q2_m - q2_0) * (6.0 - 12.0 * s_traj) / (t_mid * t_mid);
    q3_ref = q3_0 + (q3_m - q3_0) * (3.0 * s_traj * s_traj - 2.0 * s_traj * s_traj * s_traj);
    qd3_ref = (q3_m - q3_0) * (6.0 * s_traj - 6.0 * s_traj * s_traj) / t_mid;
    qdd3_ref = (q3_m - q3_0) * (6.0 - 12.0 * s_traj) / (t_mid * t_mid);
  elseif time < t_final then
    // Phase 2: midpoint -> final (with 6% payload disturbance)
    s_traj = (time - t_mid) / (t_final - t_mid);
    q1_ref = q1_m + (q1_f - q1_m) * (3.0 * s_traj * s_traj - 2.0 * s_traj * s_traj * s_traj);
    qd1_ref = (q1_f - q1_m) * (6.0 * s_traj - 6.0 * s_traj * s_traj) / (t_final - t_mid);
    qdd1_ref = (q1_f - q1_m) * (6.0 - 12.0 * s_traj) / ((t_final - t_mid) * (t_final - t_mid));
    q2_ref = q2_m + (q2_f - q2_m) * (3.0 * s_traj * s_traj - 2.0 * s_traj * s_traj * s_traj);
    qd2_ref = (q2_f - q2_m) * (6.0 * s_traj - 6.0 * s_traj * s_traj) / (t_final - t_mid);
    qdd2_ref = (q2_f - q2_m) * (6.0 - 12.0 * s_traj) / ((t_final - t_mid) * (t_final - t_mid));
    q3_ref = q3_m + (q3_f - q3_m) * (3.0 * s_traj * s_traj - 2.0 * s_traj * s_traj * s_traj);
    qd3_ref = (q3_f - q3_m) * (6.0 * s_traj - 6.0 * s_traj * s_traj) / (t_final - t_mid);
    qdd3_ref = (q3_f - q3_m) * (6.0 - 12.0 * s_traj) / ((t_final - t_mid) * (t_final - t_mid));
  else
    // Phase 3: hold at final state
    s_traj = 1.0;
    q1_ref = q1_f;
    qd1_ref = 0.0;
    qdd1_ref = 0.0;
    q2_ref = q2_f;
    qd2_ref = 0.0;
    qdd2_ref = 0.0;
    q3_ref = q3_f;
    qd3_ref = 0.0;
    qdd3_ref = 0.0;
  end if;

  // ===== Payload disturbance: 6% increase during middle third =====
  dpayload = 0.06 * 0.5 * (1.0 + tanh(5.0 * (time - t_mid)))
           * 0.5 * (1.0 + tanh(5.0 * (t_final - time)));
  mp = mp_nom * (1.0 + dpayload);

  // ===== Gravity torques (Z-Y-Y: joint 1 Z-axis has no gravity) =====
  grav2 = (m2 * L2 / 2.0 + m3 * L2 + mp * L2) * g_acc * cos(q2)
        + (m3 * L3 / 2.0 + mp * L3) * g_acc * cos(q2 + q3);
  grav3 = (m3 * L3 / 2.0 + mp * L3) * g_acc * cos(q2 + q3);

  // ===== Plant dynamics =====
  // Joint 1: Z-axis waist rotation, no gravity torque
  der(q1) = q1d;
  q1dd = (tau1_cmd - b1 * q1d) / J1;
  der(q1d) = q1dd;

  // Joint 2: Y-axis shoulder pitch, with gravity
  der(q2) = q2d;
  q2dd = (tau2_cmd - b2 * q2d - grav2) / J2;
  der(q2d) = q2dd;

  // Joint 3: Y-axis elbow pitch, with gravity
  der(q3) = q3d;
  q3dd = (tau3_cmd - b3 * q3d - grav3) / J3;
  der(q3d) = q3dd;

  // ===== Collision geometry =====
  z_tip = L2 * sin(q2) + L3 * sin(q2 + q3);
  r_tip = L1 + L2 * cos(q2) + L3 * cos(q2 + q3);

  // ===== Tracking errors =====
  e1_track = q1_ref - q1;
  e2_track = q2_ref - q2;
  e3_track = q3_ref - q3;

  // ===== Sampled controller at 250 Hz =====
  when sample(0, Ts) then
    // --- Encoder sampling (position and velocity) ---
    q1_enc = q1;
    q2_enc = q2;
    q3_enc = q3;
    qd1_enc = q1d;
    qd2_enc = q2d;
    qd3_enc = q3d;

    // --- Reference sampling ---
    q1_ref_d = q1_ref;
    q2_ref_d = q2_ref;
    q3_ref_d = q3_ref;
    qd1_ref_d = qd1_ref;
    qd2_ref_d = qd2_ref;
    qd3_ref_d = qd3_ref;
    qdd1_ref_d = qdd1_ref;
    qdd2_ref_d = qdd2_ref;
    qdd3_ref_d = qdd3_ref;

    // --- Payload sampling ---
    mp_d = mp;

    // --- Gravity feedforward (using sampled states and payload) ---
    grav2_ff = (m2 * L2 / 2.0 + m3 * L2 + mp_d * L2) * g_acc * cos(q2_enc)
             + (m3 * L3 / 2.0 + mp_d * L3) * g_acc * cos(q2_enc + q3_enc);
    grav3_ff = (m3 * L3 / 2.0 + mp_d * L3) * g_acc * cos(q2_enc + q3_enc);

    // --- PID + velocity feedforward + acceleration feedforward + gravity feedforward ---
    tau1_raw_d = Kp1 * (q1_ref_d - q1_enc) + Ki1 * pre(e1_int)
               + Kd1 * (qd1_ref_d - qd1_enc) + Kvff1 * qd1_ref_d + J1 * qdd1_ref_d;
    tau2_raw_d = Kp2 * (q2_ref_d - q2_enc) + Ki2 * pre(e2_int)
               + Kd2 * (qd2_ref_d - qd2_enc) + Kvff2 * qd2_ref_d + J2 * qdd2_ref_d + grav2_ff;
    tau3_raw_d = Kp3 * (q3_ref_d - q3_enc) + Ki3 * pre(e3_int)
               + Kd3 * (qd3_ref_d - qd3_enc) + Kvff3 * qd3_ref_d + J3 * qdd3_ref_d + grav3_ff;

    // --- Saturation detection ---
    sat1 = abs(tau1_raw_d) > tau_max;
    sat2 = abs(tau2_raw_d) > tau_max;
    sat3 = abs(tau3_raw_d) > tau_max;

    // --- Saturated torque commands (bounded at 93.5 N.m) ---
    tau1_cmd = if tau1_raw_d > tau_max then tau_max else if tau1_raw_d < -tau_max then -tau_max else tau1_raw_d;
    tau2_cmd = if tau2_raw_d > tau_max then tau_max else if tau2_raw_d < -tau_max then -tau_max else tau2_raw_d;
    tau3_cmd = if tau3_raw_d > tau_max then tau_max else if tau3_raw_d < -tau_max then -tau_max else tau3_raw_d;

    // --- Integral update with anti-windup (freeze on current saturation) ---
    e1_int_raw = if sat1 then pre(e1_int) else pre(e1_int) + (q1_ref_d - q1_enc) * Ts;
    e2_int_raw = if sat2 then pre(e2_int) else pre(e2_int) + (q2_ref_d - q2_enc) * Ts;
    e3_int_raw = if sat3 then pre(e3_int) else pre(e3_int) + (q3_ref_d - q3_enc) * Ts;

    // --- Clamp integral ---
    e1_int = if e1_int_raw > int_max then int_max else if e1_int_raw < -int_max then -int_max else e1_int_raw;
    e2_int = if e2_int_raw > int_max then int_max else if e2_int_raw < -int_max then -int_max else e2_int_raw;
    e3_int = if e3_int_raw > int_max then int_max else if e3_int_raw < -int_max then -int_max else e3_int_raw;

    // --- Fail-closed acceptance latch (checked at each sample) ---
    fail_latch = pre(fail_latch)
      or (abs(q1) > pos_bound or abs(q2) > pos_bound or abs(q3) > pos_bound)
      or (abs(q1d) > vel_bound or abs(q2d) > vel_bound or abs(q3d) > vel_bound)
      or (abs(tau1_cmd) > tau_max or abs(tau2_cmd) > tau_max or abs(tau3_cmd) > tau_max)
      or (not (abs(q1) < finite_bound and abs(q2) < finite_bound and abs(q3) < finite_bound
           and abs(q1d) < finite_bound and abs(q2d) < finite_bound and abs(q3d) < finite_bound
           and abs(tau1_cmd) < finite_bound and abs(tau2_cmd) < finite_bound and abs(tau3_cmd) < finite_bound
           and abs(e1_int) < finite_bound and abs(e2_int) < finite_bound and abs(e3_int) < finite_bound));
  end when;

  // ===== Continuous acceptance checks =====
  pos_ok = abs(q1) <= pos_bound and abs(q2) <= pos_bound and abs(q3) <= pos_bound;

  vel_ok = abs(q1d) <= vel_bound and abs(q2d) <= vel_bound and abs(q3d) <= vel_bound;

  acc_ok = abs(q1dd) <= acc_bound and abs(q2dd) <= acc_bound and abs(q3dd) <= acc_bound;

  eff_ok = abs(tau1_cmd) <= tau_max and abs(tau2_cmd) <= tau_max and abs(tau3_cmd) <= tau_max;

  settled = if time >= (T_end - 0.01) then
    (abs(q1d) < settle_vel and abs(q2d) < settle_vel and abs(q3d) < settle_vel
     and abs(e1_track) < track_bound and abs(e2_track) < track_bound and abs(e3_track) < track_bound)
  else true;

  tracking_ok = if time >= t_track_check then
    (abs(e1_track) < track_bound and abs(e2_track) < track_bound and abs(e3_track) < track_bound)
  else true;

  finite_ok = abs(q1) < finite_bound and abs(q2) < finite_bound and abs(q3) < finite_bound
    and abs(q1d) < finite_bound and abs(q2d) < finite_bound and abs(q3d) < finite_bound
    and abs(q1dd) < finite_bound and abs(q2dd) < finite_bound and abs(q3dd) < finite_bound
    and abs(tau1_cmd) < finite_bound and abs(tau2_cmd) < finite_bound and abs(tau3_cmd) < finite_bound
    and abs(e1_int) < finite_bound and abs(e2_int) < finite_bound and abs(e3_int) < finite_bound
    and abs(grav2) < finite_bound and abs(grav3) < finite_bound and abs(mp) < finite_bound;

  no_collision = z_tip >= -0.001 and abs(q3) <= Modelica.Constants.pi;

  accept = pos_ok and vel_ok and acc_ok and eff_ok and settled and tracking_ok
    and finite_ok and no_collision and not fail_latch;

  annotation(
    Documentation(info = "JointPathMoveE: Fixed three-revolute-joint arm (Z-Y-Y axes, links 0.50/0.38/0.24 m) executing synchronized point-to-point cubic trajectory from zero through one midpoint to declared final state. PID control with velocity feedforward, acceleration feedforward, and gravity compensation at 250 Hz. 6 percent payload disturbance during middle third. Effort bounded at 93.5 N.m per joint. Acceptance is fail-closed with position, velocity, acceleration, effort bounds, terminal settling, tracking error below 0.027 rad after 10.4 s, and finite value checks."),
    experiment(StartTime = 0, StopTime = 16.0, Tolerance = 1e-6, Interval = 0.004)
  );
end JointPathMoveE;