model JointPathMoveA
  "Trajectory-controlled 3R robotic arm (Z-Y-Y) with cubic interpolation, PID + velocity feedforward, encoder feedback, gravity, collision geometry, and 2.5% payload disturbance"

  // ===== Mechanism parameters =====
  parameter Real a1 = 0.50 "Link 1 length (vertical Z-axis offset) [m]";
  parameter Real a2 = 0.38 "Link 2 length [m]";
  parameter Real a3 = 0.24 "Link 3 length [m]";
  parameter Real m1 = 2.0 "Link 1 mass [kg]";
  parameter Real m2 = 1.5 "Link 2 mass [kg]";
  parameter Real m3 = 1.0 "Link 3 mass [kg]";
  parameter Real mp_nom = 0.5 "Nominal payload mass [kg]";
  parameter Real g_acc = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real J1_base = 0.5 "Joint 1 (Z) effective inertia [kg.m2]";
  parameter Real lc2 = a2 / 2.0 "Link 2 center of mass [m]";
  parameter Real lc3 = a3 / 2.0 "Link 3 center of mass [m]";
  parameter Real I2 = m2 * a2 * a2 / 12.0 "Link 2 inertia about COM [kg.m2]";
  parameter Real I3 = m3 * a3 * a3 / 12.0 "Link 3 inertia about COM [kg.m2]";

  // ===== Actuator =====
  parameter Real tau_max = 61.2 "Maximum torque per joint [N.m]";

  // ===== Control timing =====
  parameter Real Ts = 1.0 / 80.0 "Control loop period (80 Hz) [s]";
  parameter Real T_end = 8.0 "Scenario duration [s]";
  parameter Real T_seg1 = 3.0 "End of segment 1 (start->midpoint) [s]";
  parameter Real T_seg2 = 5.0 "End of segment 2 (midpoint->final) [s]";

  // ===== Trajectory waypoints (declared parameters) =====
  parameter Real q1_start = 0.0 "Joint 1 start angle [rad]";
  parameter Real q2_start = 0.0 "Joint 2 start angle [rad]";
  parameter Real q3_start = 0.0 "Joint 3 start angle [rad]";
  parameter Real q1_mid = 0.5 "Joint 1 midpoint angle [rad]";
  parameter Real q2_mid = 0.4 "Joint 2 midpoint angle [rad]";
  parameter Real q3_mid = 0.3 "Joint 3 midpoint angle [rad]";
  parameter Real q1_final = 1.0 "Joint 1 final angle [rad]";
  parameter Real q2_final = 0.8 "Joint 2 final angle [rad]";
  parameter Real q3_final = 0.5 "Joint 3 final angle [rad]";

  // ===== PID + feedforward gains =====
  parameter Real Kp1 = 100.0 "Joint 1 proportional gain";
  parameter Real Kp2 = 80.0  "Joint 2 proportional gain";
  parameter Real Kp3 = 60.0  "Joint 3 proportional gain";
  parameter Real Ki1 = 20.0  "Joint 1 integral gain";
  parameter Real Ki2 = 15.0  "Joint 2 integral gain";
  parameter Real Ki3 = 10.0  "Joint 3 integral gain";
  parameter Real Kd1 = 10.0  "Joint 1 derivative gain";
  parameter Real Kd2 = 8.0   "Joint 2 derivative gain";
  parameter Real Kd3 = 5.0   "Joint 3 derivative gain";
  parameter Real Kvff1 = 0.9 "Joint 1 velocity feedforward gain";
  parameter Real Kvff2 = 0.9 "Joint 2 velocity feedforward gain";
  parameter Real Kvff3 = 0.9 "Joint 3 velocity feedforward gain";
  parameter Real Kaff1 = 0.1 "Joint 1 acceleration feedforward gain";
  parameter Real Kaff2 = 0.1 "Joint 2 acceleration feedforward gain";
  parameter Real Kaff3 = 0.1 "Joint 3 acceleration feedforward gain";

  // ===== Disturbance =====
  parameter Real dist_frac = 0.025 "Payload disturbance fraction (2.5%)";
  parameter Real T_dist_start = T_end / 3.0 "Disturbance onset [s]";
  parameter Real T_dist_end = 2.0 * T_end / 3.0 "Disturbance end [s]";
  parameter Real T_dist_ramp = 0.3 "Disturbance ramp time [s]";

  // ===== Bounds =====
  parameter Real q_bound = 3.14159265358979 "Position bound [rad]";
  parameter Real qd_bound = 5.0 "Velocity bound [rad/s]";
  parameter Real qdd_bound = 20.0 "Acceleration bound [rad/s2]";

  // ===== Continuous states =====
  Real q1(start = q1_start, fixed = true) "Joint 1 position (Z axis) [rad]";
  Real q2(start = q2_start, fixed = true) "Joint 2 position (Y axis) [rad]";
  Real q3(start = q3_start, fixed = true) "Joint 3 position (Y axis) [rad]";
  Real qd1(start = 0.0, fixed = true) "Joint 1 velocity [rad/s]";
  Real qd2(start = 0.0, fixed = true) "Joint 2 velocity [rad/s]";
  Real qd3(start = 0.0, fixed = true) "Joint 3 velocity [rad/s]";

  // ===== Discrete controller variables (sampled at 80 Hz) =====
  discrete Real q1_des(start = q1_start) "Desired joint 1 position [rad]";
  discrete Real q2_des(start = q2_start) "Desired joint 2 position [rad]";
  discrete Real q3_des(start = q3_start) "Desired joint 3 position [rad]";
  discrete Real qd1_des(start = 0.0) "Desired joint 1 velocity [rad/s]";
  discrete Real qd2_des(start = 0.0) "Desired joint 2 velocity [rad/s]";
  discrete Real qd3_des(start = 0.0) "Desired joint 3 velocity [rad/s]";
  discrete Real qdd1_des(start = 0.0) "Desired joint 1 accel [rad/s2]";
  discrete Real qdd2_des(start = 0.0) "Desired joint 2 accel [rad/s2]";
  discrete Real qdd3_des(start = 0.0) "Desired joint 3 accel [rad/s2]";
  discrete Real tau1_cmd(start = 0.0) "Joint 1 torque command [N.m]";
  discrete Real tau2_cmd(start = 0.0) "Joint 2 torque command [N.m]";
  discrete Real tau3_cmd(start = 0.0) "Joint 3 torque command [N.m]";
  discrete Real err_int1(start = 0.0) "Joint 1 integral error";
  discrete Real err_int2(start = 0.0) "Joint 2 integral error";
  discrete Real err_int3(start = 0.0) "Joint 3 integral error";
  discrete Real enc1_pos(start = 0.0) "Encoder 1 position [rad]";
  discrete Real enc2_pos(start = 0.0) "Encoder 2 position [rad]";
  discrete Real enc3_pos(start = 0.0) "Encoder 3 position [rad]";
  discrete Real enc1_vel(start = 0.0) "Encoder 1 velocity [rad/s]";
  discrete Real enc2_vel(start = 0.0) "Encoder 2 velocity [rad/s]";
  discrete Real enc3_vel(start = 0.0) "Encoder 3 velocity [rad/s]";

  // ===== Continuous computed variables =====
  Real tau1 "Joint 1 applied torque (saturated) [N.m]";
  Real tau2 "Joint 2 applied torque (saturated) [N.m]";
  Real tau3 "Joint 3 applied torque (saturated) [N.m]";
  Real mp_eff "Effective payload mass (with disturbance) [kg]";
  Real dist_signal "Disturbance activation signal [0..1]";

  Real M11 "Mass matrix element [1,1] [kg.m2]";
  Real M12 "Mass matrix element [1,2] [kg.m2]";
  Real M22 "Mass matrix element [2,2] [kg.m2]";
  Real Mdet "Mass matrix determinant [kg2.m4]";
  Real Cor2 "Coriolis/centrifugal torque joint 2 [N.m]";
  Real Cor3 "Coriolis/centrifugal torque joint 3 [N.m]";
  Real G2 "Gravity torque joint 2 (actual) [N.m]";
  Real G3 "Gravity torque joint 3 (actual) [N.m]";
  Real G2_nom "Gravity torque joint 2 (nominal for controller) [N.m]";
  Real G3_nom "Gravity torque joint 3 (nominal for controller) [N.m]";
  Real qdd1 "Joint 1 acceleration [rad/s2]";
  Real qdd2 "Joint 2 acceleration [rad/s2]";
  Real qdd3 "Joint 3 acceleration [rad/s2]";

  // Continuous trajectory traces
  Real q1_traj "Continuous trajectory joint 1 [rad]";
  Real q2_traj "Continuous trajectory joint 2 [rad]";
  Real q3_traj "Continuous trajectory joint 3 [rad]";
  Real qd1_traj "Continuous trajectory velocity joint 1 [rad/s]";
  Real qd2_traj "Continuous trajectory velocity joint 2 [rad/s]";
  Real qd3_traj "Continuous trajectory velocity joint 3 [rad/s]";
  Real qdd1_traj "Continuous trajectory accel joint 1 [rad/s2]";
  Real qdd2_traj "Continuous trajectory accel joint 2 [rad/s2]";
  Real qdd3_traj "Continuous trajectory accel joint 3 [rad/s2]";

  // Tracking
  Real track_err1 "Joint 1 tracking error [rad]";
  Real track_err2 "Joint 2 tracking error [rad]";
  Real track_err3 "Joint 3 tracking error [rad]";
  Real track_err_norm "Euclidean norm of tracking error [rad]";
  Real track_err_primary "Primary (max abs) tracking error [rad]";

  // Bound monitors
  Real pos_violation "Position bound violation (positive=exceeded) [rad]";
  Real vel_violation "Velocity bound violation [rad/s]";
  Real acc_violation "Acceleration bound violation [rad/s2]";
  Real eff_violation "Effort bound violation [N.m]";

  // Terminal settling
  Boolean settled "True if tracking error < 0.041 after 5.2 s";

  // Finite check
  Boolean all_finite "True if all physical and control values are finite";

  // Collision geometry
  Real min_clearance "Minimum joint clearance for self-collision [rad]";

equation
  // ===== Payload disturbance (smooth 2.5% change during middle third) =====
  dist_signal = smoothstep(time, T_dist_start, T_dist_start + T_dist_ramp)
              - smoothstep(time, T_dist_end, T_dist_end + T_dist_ramp);
  mp_eff = mp_nom * (1.0 + dist_frac * dist_signal);

  // ===== Continuous trajectory (cubic, zero velocity at waypoints) =====
  q1_traj = if time <= T_seg1 then
              q1_start + (q1_mid - q1_start) * smoothstep(time, 0.0, T_seg1)
            elseif time <= T_seg2 then
              q1_mid + (q1_final - q1_mid) * smoothstep(time, T_seg1, T_seg2)
            else
              q1_final;
  q2_traj = if time <= T_seg1 then
              q2_start + (q2_mid - q2_start) * smoothstep(time, 0.0, T_seg1)
            elseif time <= T_seg2 then
              q2_mid + (q2_final - q2_mid) * smoothstep(time, T_seg1, T_seg2)
            else
              q2_final;
  q3_traj = if time <= T_seg1 then
              q3_start + (q3_mid - q3_start) * smoothstep(time, 0.0, T_seg1)
            elseif time <= T_seg2 then
              q3_mid + (q3_final - q3_mid) * smoothstep(time, T_seg1, T_seg2)
            else
              q3_final;

  qd1_traj = if time <= T_seg1 then
               (q1_mid - q1_start) * dsmoothstep(time, 0.0, T_seg1)
             elseif time <= T_seg2 then
               (q1_final - q1_mid) * dsmoothstep(time, T_seg1, T_seg2)
             else
               0.0;
  qd2_traj = if time <= T_seg1 then
               (q2_mid - q2_start) * dsmoothstep(time, 0.0, T_seg1)
             elseif time <= T_seg2 then
               (q2_final - q2_mid) * dsmoothstep(time, T_seg1, T_seg2)
             else
               0.0;
  qd3_traj = if time <= T_seg1 then
               (q3_mid - q3_start) * dsmoothstep(time, 0.0, T_seg1)
             elseif time <= T_seg2 then
               (q3_final - q3_mid) * dsmoothstep(time, T_seg1, T_seg2)
             else
               0.0;

  qdd1_traj = if time <= T_seg1 then
                (q1_mid - q1_start) * ddsmoothstep(time, 0.0, T_seg1)
              elseif time <= T_seg2 then
                (q1_final - q1_mid) * ddsmoothstep(time, T_seg1, T_seg2)
              else
                0.0;
  qdd2_traj = if time <= T_seg1 then
                (q2_mid - q2_start) * ddsmoothstep(time, 0.0, T_seg1)
              elseif time <= T_seg2 then
                (q2_final - q2_mid) * ddsmoothstep(time, T_seg1, T_seg2)
              else
                0.0;
  qdd3_traj = if time <= T_seg1 then
                (q3_mid - q3_start) * ddsmoothstep(time, 0.0, T_seg1)
              elseif time <= T_seg2 then
                (q3_final - q3_mid) * ddsmoothstep(time, T_seg1, T_seg2)
              else
                0.0;

  // ===== Plant dynamics =====
  M11 = I2 + I3 + m2 * lc2 * lc2
      + (m3 + mp_eff) * (a2 * a2 + lc3 * lc3 + 2.0 * a2 * lc3 * cos(q3));
  M12 = I3 + (m3 + mp_eff) * (lc3 * lc3 + a2 * lc3 * cos(q3));
  M22 = I3 + (m3 + mp_eff) * lc3 * lc3;
  Mdet = M11 * M22 - M12 * M12;

  Cor2 = -(m3 + mp_eff) * a2 * lc3 * sin(q3) * qd3 * (2.0 * qd2 + qd3);
  Cor3 =  (m3 + mp_eff) * a2 * lc3 * sin(q3) * qd2 * qd2;

  G2 = g_acc * ((m2 * lc2 + (m3 + mp_eff) * a2) * cos(q2)
      + (m3 + mp_eff) * lc3 * cos(q2 + q3));
  G3 = g_acc * (m3 + mp_eff) * lc3 * cos(q2 + q3);

  G2_nom = g_acc * ((m2 * lc2 + (m3 + mp_nom) * a2) * cos(q2)
          + (m3 + mp_nom) * lc3 * cos(q2 + q3));
  G3_nom = g_acc * (m3 + mp_nom) * lc3 * cos(q2 + q3);

  // Joint 1 dynamics (rotation about Z, no gravity, constant inertia)
  qdd1 = tau1 / J1_base;
  der(q1) = qd1;
  der(qd1) = qdd1;

  // Joints 2, 3 dynamics (planar 2R: M * qdd = tau - Cor - G)
  qdd2 = (M22 * (tau2 - Cor2 - G2) - M12 * (tau3 - Cor3 - G3))
       / Mdet;
  qdd3 = (M11 * (tau3 - Cor3 - G3) - M12 * (tau2 - Cor2 - G2))
       / Mdet;
  der(q2) = qd2;
  der(q3) = qd3;
  der(qd2) = qdd2;
  der(qd3) = qdd3;

  // Torque saturation (ZOH from discrete command)
  tau1 = if tau1_cmd > tau_max then tau_max
         elseif tau1_cmd < -tau_max then -tau_max
         else tau1_cmd;
  tau2 = if tau2_cmd > tau_max then tau_max
         elseif tau2_cmd < -tau_max then -tau_max
         else tau2_cmd;
  tau3 = if tau3_cmd > tau_max then tau_max
         elseif tau3_cmd < -tau_max then -tau_max
         else tau3_cmd;

  // ===== Tracking error =====
  track_err1 = q1_des - q1;
  track_err2 = q2_des - q2;
  track_err3 = q3_des - q3;
  track_err_norm = sqrt(track_err1 * track_err1
                      + track_err2 * track_err2
                      + track_err3 * track_err3
                      + 1.0e-12);
  track_err_primary = max(abs(track_err1),
                          max(abs(track_err2), abs(track_err3)));

  // ===== Bound monitoring =====
  pos_violation = max(abs(q1), max(abs(q2), abs(q3))) - q_bound;
  vel_violation = max(abs(qd1), max(abs(qd2), abs(qd3))) - qd_bound;
  acc_violation = max(abs(qdd1), max(abs(qdd2), abs(qdd3))) - qdd_bound;
  eff_violation = max(abs(tau1), max(abs(tau2), abs(tau3))) - tau_max;

  // ===== Terminal settling =====
  settled = (time >= 5.2) and (track_err_primary < 0.041);

  // ===== Collision geometry (minimum elbow angle to prevent self-collision) =====
  min_clearance = q3 + 0.1;

  // ===== Finite value check =====
  all_finite =
    (abs(q1) < 1.0e10) and (abs(q2) < 1.0e10) and (abs(q3) < 1.0e10) and
    (abs(qd1) < 1.0e10) and (abs(qd2) < 1.0e10) and (abs(qd3) < 1.0e10) and
    (abs(tau1) < 1.0e10) and (abs(tau2) < 1.0e10) and (abs(tau3) < 1.0e10) and
    (abs(q1_des) < 1.0e10) and (abs(q2_des) < 1.0e10) and (abs(q3_des) < 1.0e10) and
    (abs(enc1_pos) < 1.0e10) and (abs(enc2_pos) < 1.0e10) and (abs(enc3_pos) < 1.0e10) and
    (abs(enc1_vel) < 1.0e10) and (abs(enc2_vel) < 1.0e10) and (abs(enc3_vel) < 1.0e10) and
    (abs(err_int1) < 1.0e10) and (abs(err_int2) < 1.0e10) and (abs(err_int3) < 1.0e10) and
    (abs(tau1_cmd) < 1.0e10) and (abs(tau2_cmd) < 1.0e10) and (abs(tau3_cmd) < 1.0e10);

  // ===== Discrete controller and encoder at 80 Hz =====
  when sample(0, Ts) then
    q1_des = if time <= T_seg1 then
               q1_start + (q1_mid - q1_start) * smoothstep(time, 0.0, T_seg1)
             elseif time <= T_seg2 then
               q1_mid + (q1_final - q1_mid) * smoothstep(time, T_seg1, T_seg2)
             else
               q1_final;
    q2_des = if time <= T_seg1 then
               q2_start + (q2_mid - q2_start) * smoothstep(time, 0.0, T_seg1)
             elseif time <= T_seg2 then
               q2_mid + (q2_final - q2_mid) * smoothstep(time, T_seg1, T_seg2)
             else
               q2_final;
    q3_des = if time <= T_seg1 then
               q3_start + (q3_mid - q3_start) * smoothstep(time, 0.0, T_seg1)
             elseif time <= T_seg2 then
               q3_mid + (q3_final - q3_mid) * smoothstep(time, T_seg1, T_seg2)
             else
               q3_final;

    qd1_des = if time <= T_seg1 then
                (q1_mid - q1_start) * dsmoothstep(time, 0.0, T_seg1)
              elseif time <= T_seg2 then
                (q1_final - q1_mid) * dsmoothstep(time, T_seg1, T_seg2)
              else
                0.0;
    qd2_des = if time <= T_seg1 then
                (q2_mid - q2_start) * dsmoothstep(time, 0.0, T_seg1)
              elseif time <= T_seg2 then
                (q2_final - q2_mid) * dsmoothstep(time, T_seg1, T_seg2)
              else
                0.0;
    qd3_des = if time <= T_seg1 then
                (q3_mid - q3_start) * dsmoothstep(time, 0.0, T_seg1)
              elseif time <= T_seg2 then
                (q3_final - q3_mid) * dsmoothstep(time, T_seg1, T_seg2)
              else
                0.0;

    qdd1_des = if time <= T_seg1 then
                 (q1_mid - q1_start) * ddsmoothstep(time, 0.0, T_seg1)
               elseif time <= T_seg2 then
                 (q1_final - q1_mid) * ddsmoothstep(time, T_seg1, T_seg2)
               else
                 0.0;
    qdd2_des = if time <= T_seg1 then
                 (q2_mid - q2_start) * ddsmoothstep(time, 0.0, T_seg1)
               elseif time <= T_seg2 then
                 (q2_final - q2_mid) * ddsmoothstep(time, T_seg1, T_seg2)
               else
                 0.0;
    qdd3_des = if time <= T_seg1 then
                 (q3_mid - q3_start) * ddsmoothstep(time, 0.0, T_seg1)
               elseif time <= T_seg2 then
                 (q3_final - q3_mid) * ddsmoothstep(time, T_seg1, T_seg2)
               else
                 0.0;

    enc1_pos = q1;
    enc2_pos = q2;
    enc3_pos = q3;
    enc1_vel = qd1;
    enc2_vel = qd2;
    enc3_vel = qd3;

    err_int1 = pre(err_int1) + Ts * (q1_des - enc1_pos);
    err_int2 = pre(err_int2) + Ts * (q2_des - enc2_pos);
    err_int3 = pre(err_int3) + Ts * (q3_des - enc3_pos);

    tau1_cmd = Kp1 * (q1_des - enc1_pos)
             + Kd1 * (qd1_des - enc1_vel)
             + Ki1 * err_int1
             + Kvff1 * qd1_des
             + Kaff1 * qdd1_des;
    tau2_cmd = Kp2 * (q2_des - enc2_pos)
             + Kd2 * (qd2_des - enc2_vel)
             + Ki2 * err_int2
             + Kvff2 * qd2_des
             + Kaff2 * qdd2_des
             + G2_nom;
    tau3_cmd = Kp3 * (q3_des - enc3_pos)
             + Kd3 * (qd3_des - enc3_vel)
             + Ki3 * err_int3
             + Kvff3 * qd3_des
             + Kaff3 * qdd3_des
             + G3_nom;
  end when;

  annotation(
    experiment(StopTime = 8.0, Tolerance = 1.0e-6, Interval = 0.0125),
    Documentation(info = "<html>
<h3>JointPathMoveA</h3>
<p>Trajectory-controlled 3-revolute-joint robotic arm (Z-Y-Y axes).</p>
<ul>
<li>Link lengths: 0.50 m (vertical Z), 0.38 m, 0.24 m</li>
<li>Cubic trajectory: start (zero) -> midpoint -> declared final state</li>
<li>PID control with velocity and acceleration feedforward</li>
<li>Gravity compensation using nominal model (disturbance is unmodeled)</li>
<li>Encoder feedback: position and velocity sampled at 80 Hz</li>
<li>2.5% payload mass disturbance during middle third of 8 s scenario</li>
<li>Torque saturation at 61.2 N.m per joint</li>
<li>Self-collision geometry monitoring (minimum elbow angle)</li>
<li>Position, velocity, acceleration, and effort bound monitoring</li>
<li>Terminal settling: tracking error below 0.041 rad after 5.2 s</li>
<li>Finite value validation for all physical, control, and estimator variables</li>
</ul>
</html>")
  );
end JointPathMoveA;