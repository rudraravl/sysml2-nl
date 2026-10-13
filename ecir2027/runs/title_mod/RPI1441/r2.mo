model JointPathMoveA
  "Three-revolute Z-Y-Y robotic arm: trajectory control with cubic interpolation, PID + velocity feedforward, 2.5 percent payload disturbance"

  // ===== Link lengths (given) =====
  parameter Modelica.Units.SI.Length a1 = 0.50 "Link 1 length [m] (given)";
  parameter Modelica.Units.SI.Length a2 = 0.38 "Link 2 length [m] (given)";
  parameter Modelica.Units.SI.Length a3 = 0.24 "Link 3 length [m] (given)";

  // ===== Inertial parameters (NOT specified — placeholder values) =====
  parameter Modelica.Units.SI.Mass m1 = 2.0 "Link 1 lumped mass [kg] (NOT specified — placeholder)";
  parameter Modelica.Units.SI.Mass m2 = 1.5 "Link 2 lumped mass [kg] (NOT specified — placeholder)";
  parameter Modelica.Units.SI.Mass m3 = 1.0 "Link 3 / payload lumped mass [kg] (NOT specified — placeholder)";
  parameter Modelica.Units.SI.Acceleration g_acc = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real b1 = 0.10 "Joint 1 viscous friction [N.m.s/rad] (NOT specified — placeholder)";
  parameter Real b2 = 0.05 "Joint 2 viscous friction [N.m.s/rad] (NOT specified — placeholder)";
  parameter Real b3 = 0.05 "Joint 3 viscous friction [N.m.s/rad] (NOT specified — placeholder)";

  // ===== Torque saturation limit (given) =====
  parameter Modelica.Units.SI.Torque tau_max = 61.2 "Command magnitude limit per joint [N.m] (given)";

  // ===== Waypoints (final state declared; values NOT specified — placeholders) =====
  parameter Modelica.Units.SI.Angle q_mid1 = 0.6 "Midpoint joint 1 [rad] (NOT specified — placeholder)";
  parameter Modelica.Units.SI.Angle q_mid2 = 0.5 "Midpoint joint 2 [rad] (NOT specified — placeholder)";
  parameter Modelica.Units.SI.Angle q_mid3 = 0.3 "Midpoint joint 3 [rad] (NOT specified — placeholder)";
  parameter Modelica.Units.SI.Angle q_fin1 = 1.2 "Final joint 1 [rad] (declared; value NOT specified — placeholder)";
  parameter Modelica.Units.SI.Angle q_fin2 = 0.9 "Final joint 2 [rad] (declared; value NOT specified — placeholder)";
  parameter Modelica.Units.SI.Angle q_fin3 = 0.6 "Final joint 3 [rad] (declared; value NOT specified — placeholder)";
  parameter Modelica.Units.SI.Time t_seg1 = 4.0 "Time to reach midpoint [s]";
  parameter Modelica.Units.SI.Time t_end = 8.0 "Total scenario duration [s]";

  // ===== Controller gains (NOT specified — placeholder values) =====
  parameter Real Kp1 = 40.0 "Joint 1 proportional gain (NOT specified — placeholder)";
  parameter Real Kp2 = 25.0 "Joint 2 proportional gain (NOT specified — placeholder)";
  parameter Real Kp3 = 10.0 "Joint 3 proportional gain (NOT specified — placeholder)";
  parameter Real Ki1 = 5.0  "Joint 1 integral gain (NOT specified — placeholder)";
  parameter Real Ki2 = 3.0  "Joint 2 integral gain (NOT specified — placeholder)";
  parameter Real Ki3 = 1.0  "Joint 3 integral gain (NOT specified — placeholder)";
  parameter Real Kd1 = 5.0  "Joint 1 derivative gain (NOT specified — placeholder)";
  parameter Real Kd2 = 3.0  "Joint 2 derivative gain (NOT specified — placeholder)";
  parameter Real Kd3 = 1.5  "Joint 3 derivative gain (NOT specified — placeholder)";
  parameter Real Kvf1 = 0.5 "Joint 1 velocity feedforward gain (NOT specified — placeholder)";
  parameter Real Kvf2 = 0.3 "Joint 2 velocity feedforward gain (NOT specified — placeholder)";
  parameter Real Kvf3 = 0.1 "Joint 3 velocity feedforward gain (NOT specified — placeholder)";

  // ===== Bounds (position/velocity/acceleration NOT numerically specified) =====
  parameter Real pos_bound = 3.14159 "Position bound [rad] (NOT specified — placeholder)";
  parameter Real vel_bound = 5.0 "Velocity bound [rad/s] (NOT specified — placeholder)";
  parameter Real acc_bound = 20.0 "Acceleration bound [rad/s2] (NOT specified — placeholder)";

  // ===== Scenario parameters (given) =====
  parameter Modelica.Units.SI.Frequency fs = 80.0 "Sensor/control sample frequency [Hz] (given)";
  parameter Real payload_change_pct = 0.025 "Payload change fraction, 2.5 percent (given)";
  parameter Real track_err_bound = 0.041 "Tracking error bound [rad] after settling (given)";
  parameter Modelica.Units.SI.Time t_settle = 5.2 "Settling time threshold [s] (given)";

  // ===== Collision geometry limits (NOT specified — placeholder) =====
  parameter Real q_lim = 3.14159 "Joint limit [rad] for collision geometry (NOT specified — placeholder)";

  // ===== Continuous state variables =====
  Modelica.Units.SI.Angle q1 "Joint 1 angle (Z axis)";
  Modelica.Units.SI.Angle q2 "Joint 2 angle (Y axis)";
  Modelica.Units.SI.Angle q3 "Joint 3 angle (Y axis)";
  Modelica.Units.SI.AngularVelocity qd1 "Joint 1 velocity";
  Modelica.Units.SI.AngularVelocity qd2 "Joint 2 velocity";
  Modelica.Units.SI.AngularVelocity qd3 "Joint 3 velocity";
  Modelica.Units.SI.AngularAcceleration qdd1 "Joint 1 acceleration";
  Modelica.Units.SI.AngularAcceleration qdd2 "Joint 2 acceleration";
  Modelica.Units.SI.AngularAcceleration qdd3 "Joint 3 acceleration";

  // ===== Desired trajectory (continuous) =====
  Modelica.Units.SI.Angle q_des1, q_des2, q_des3;
  Modelica.Units.SI.AngularVelocity qd_des1, qd_des2, qd_des3;
  Modelica.Units.SI.AngularAcceleration qdd_des1, qdd_des2, qdd_des3;

  // ===== Applied torques (saturated) =====
  Modelica.Units.SI.Torque tau1, tau2, tau3;

  // ===== Discrete command (controller output, zero-order hold) =====
  discrete Modelica.Units.SI.Torque tau1_cmd(start=0.0), tau2_cmd(start=0.0), tau3_cmd(start=0.0);

  // ===== Discrete controller states =====
  discrete Real e1_int(start=0.0), e2_int(start=0.0), e3_int(start=0.0);

  // ===== Encoder readings (discrete, sampled at fs) =====
  discrete Modelica.Units.SI.Angle q_enc1(start=0.0), q_enc2(start=0.0), q_enc3(start=0.0);
  discrete Modelica.Units.SI.AngularVelocity qd_enc1(start=0.0), qd_enc2(start=0.0), qd_enc3(start=0.0);

  // ===== Tracking errors (continuous) =====
  Real e1, e2, e3;
  Real track_err "Primary tracking error norm [rad]";

  // ===== Payload disturbance =====
  Real payload_factor "Payload mass multiplier";
  Real m3_eff "Effective payload mass [kg]";

  // ===== Dynamics quantities (actual configuration) =====
  Real c3, s3, c2, c23;
  Real M11, M12, M22, detM;
  Real C1_dyn, C2_dyn;
  Real G1_dyn, G2_dyn;
  Real J1_eff;

  // ===== Feedforward dynamics at desired trajectory (nominal m3) =====
  Real c3d, s3d, c2d, c23d;
  Real M11d, M12d, M22d;
  Real C1d, C2d;
  Real G1d, G2d;
  Real J1d;

  // ===== Status flags =====
  Boolean collision "Collision flag";
  Boolean bounds_ok "Bounds satisfied";
  Boolean track_ok "Tracking within bound after settling";
  Boolean no_nan_inf "No NaN or infinite values";

  // ===== Intermediate =====
  Real tau1_raw, tau2_raw, tau3_raw;

initial equation
  q1 = 0.0;
  q2 = 0.0;
  q3 = 0.0;
  qd1 = 0.0;
  qd2 = 0.0;
  qd3 = 0.0;

equation
  // ============================================================
  // Cubic trajectory interpolation: zero -> midpoint -> final
  // Smooth cubic with zero endpoint velocities on each segment
  // ============================================================

  // --- Joint 1 ---
  if time <= t_seg1 then
    q_des1 = q_mid1 * (3.0*(time/t_seg1)^2 - 2.0*(time/t_seg1)^3);
    qd_des1 = (q_mid1/t_seg1) * (6.0*(time/t_seg1) - 6.0*(time/t_seg1)^2);
    qdd_des1 = (q_mid1/t_seg1^2) * (6.0 - 12.0*(time/t_seg1));
  elseif time <= t_end then
    q_des1 = q_mid1 + (q_fin1 - q_mid1) * (3.0*((time-t_seg1)/(t_end-t_seg1))^2 - 2.0*((time-t_seg1)/(t_end-t_seg1))^3);
    qd_des1 = ((q_fin1 - q_mid1)/(t_end-t_seg1)) * (6.0*((time-t_seg1)/(t_end-t_seg1)) - 6.0*((time-t_seg1)/(t_end-t_seg1))^2);
    qdd_des1 = ((q_fin1 - q_mid1)/(t_end-t_seg1)^2) * (6.0 - 12.0*((time-t_seg1)/(t_end-t_seg1)));
  else
    q_des1 = q_fin1;
    qd_des1 = 0.0;
    qdd_des1 = 0.0;
  end if;

  // --- Joint 2 ---
  if time <= t_seg1 then
    q_des2 = q_mid2 * (3.0*(time/t_seg1)^2 - 2.0*(time/t_seg1)^3);
    qd_des2 = (q_mid2/t_seg1) * (6.0*(time/t_seg1) - 6.0*(time/t_seg1)^2);
    qdd_des2 = (q_mid2/t_seg1^2) * (6.0 - 12.0*(time/t_seg1));
  elseif time <= t_end then
    q_des2 = q_mid2 + (q_fin2 - q_mid2) * (3.0*((time-t_seg1)/(t_end-t_seg1))^2 - 2.0*((time-t_seg1)/(t_end-t_seg1))^3);
    qd_des2 = ((q_fin2 - q_mid2)/(t_end-t_seg1)) * (6.0*((time-t_seg1)/(t_end-t_seg1)) - 6.0*((time-t_seg1)/(t_end-t_seg1))^2);
    qdd_des2 = ((q_fin2 - q_mid2)/(t_end-t_seg1)^2) * (6.0 - 12.0*((time-t_seg1)/(t_end-t_seg1)));
  else
    q_des2 = q_fin2;
    qd_des2 = 0.0;
    qdd_des2 = 0.0;
  end if;

  // --- Joint 3 ---
  if time <= t_seg1 then
    q_des3 = q_mid3 * (3.0*(time/t_seg1)^2 - 2.0*(time/t_seg1)^3);
    qd_des3 = (q_mid3/t_seg1) * (6.0*(time/t_seg1) - 6.0*(time/t_seg1)^2);
    qdd_des3 = (q_mid3/t_seg1^2) * (6.0 - 12.0*(time/t_seg1));
  elseif time <= t_end then
    q_des3 = q_mid3 + (q_fin3 - q_mid3) * (3.0*((time-t_seg1)/(t_end-t_seg1))^2 - 2.0*((time-t_seg1)/(t_end-t_seg1))^3);
    qd_des3 = ((q_fin3 - q_mid3)/(t_end-t_seg1)) * (6.0*((time-t_seg1)/(t_end-t_seg1)) - 6.0*((time-t_seg1)/(t_end-t_seg1))^2);
    qdd_des3 = ((q_fin3 - q_mid3)/(t_end-t_seg1)^2) * (6.0 - 12.0*((time-t_seg1)/(t_end-t_seg1)));
  else
    q_des3 = q_fin3;
    qd_des3 = 0.0;
    qdd_des3 = 0.0;
  end if;

  // ============================================================
  // Payload disturbance: 2.5 percent change during middle third
  //   [t_end/3, 2*t_end/3] with smooth cosine bump peaking at t_seg1
  // ============================================================
  if time < t_end/3.0 then
    payload_factor = 1.0;
  elseif time <= 2.0*t_end/3.0 then
    payload_factor = 1.0 + payload_change_pct * 0.5 * (1.0 - cos(2.0*Modelica.Constants.pi*(time - t_end/3.0)/(t_end/3.0)));
  else
    payload_factor = 1.0;
  end if;

  m3_eff = m3 * payload_factor;

  // ============================================================
  // Plant dynamics
  //   Joint 1: Z axis (vertical) — gravity does not produce torque
  //   Joints 2,3: Y axes — planar 2R in vertical plane with gravity
  // ============================================================
  J1_eff = m1*a1^2 + m2*(a1+a2)^2 + m3_eff*(a1+a2+a3)^2;
  qdd1 = (tau1 - b1*qd1) / J1_eff;

  c3 = cos(q3);
  s3 = sin(q3);
  c2 = cos(q2);
  c23 = cos(q2 + q3);

  M11 = m2*a2^2 + m3_eff*(a2^2 + a3^2 + 2.0*a2*a3*c3);
  M12 = m3_eff*(a3^2 + a2*a3*c3);
  M22 = m3_eff*a3^2;
  detM = M11*M22 - M12*M12;

  C1_dyn = -m3_eff*a2*a3*s3*qd3^2 - 2.0*m3_eff*a2*a3*s3*qd2*qd3;
  C2_dyn =  m3_eff*a2*a3*s3*qd2^2;

  G1_dyn = (m2 + m3_eff)*g_acc*a2*c2 + m3_eff*g_acc*a3*c23;
  G2_dyn =  m3_eff*g_acc*a3*c23;

  // detM >= m2*a2^2*m3_eff*a3^2 > 0 for positive masses — never singular
  qdd2 = ( M22*(tau2 - C1_dyn - G1_dyn) - M12*(tau3 - C2_dyn - G2_dyn)) / detM;
  qdd3 = ( M11*(tau3 - C2_dyn - G2_dyn) - M12*(tau2 - C1_dyn - G1_dyn)) / detM;

  // State derivatives
  der(q1) = qd1;
  der(q2) = qd2;
  der(q3) = qd3;
  der(qd1) = qdd1;
  der(qd2) = qdd2;
  der(qd3) = qdd3;

  // ============================================================
  // Feedforward dynamics at desired trajectory (nominal m3)
  // ============================================================
  c3d = cos(q_des3);
  s3d = sin(q_des3);
  c2d = cos(q_des2);
  c23d = cos(q_des2 + q_des3);

  M11d = m2*a2^2 + m3*(a2^2 + a3^2 + 2.0*a2*a3*c3d);
  M12d = m3*(a3^2 + a2*a3*c3d);
  M22d = m3*a3^2;

  C1d = -m3*a2*a3*s3d*qd_des3^2 - 2.0*m3*a2*a3*s3d*qd_des2*qd_des3;
  C2d =  m3*a2*a3*s3d*qd_des2^2;

  G1d = (m2 + m3)*g_acc*a2*c2d + m3*g_acc*a3*c23d;
  G2d =  m3*g_acc*a3*c23d;

  J1d = m1*a1^2 + m2*(a1+a2)^2 + m3*(a1+a2+a3)^2;

  // ============================================================
  // Continuous tracking errors
  // ============================================================
  e1 = q_des1 - q1;
  e2 = q_des2 - q2;
  e3 = q_des3 - q3;
  // epsilon guard ensures well-defined square root at zero error
  track_err = sqrt(e1*e1 + e2*e2 + e3*e3 + 1.0e-12);

  // ============================================================
  // Discrete controller at fs Hz
  //   PID + velocity feedforward + computed-torque feedforward
  // ============================================================
  when sample(0, 1.0/fs) then
    // Encoder feedback: report every controlled coordinate and velocity
    q_enc1 = q1;
    q_enc2 = q2;
    q_enc3 = q3;
    qd_enc1 = qd1;
    qd_enc2 = qd2;
    qd_enc3 = qd3;

    // Integral error with anti-windup clamping
    e1_int = max(-10.0, min(10.0, pre(e1_int) + (q_des1 - q1)/fs));
    e2_int = max(-10.0, min(10.0, pre(e2_int) + (q_des2 - q2)/fs));
    e3_int = max(-10.0, min(10.0, pre(e3_int) + (q_des3 - q3)/fs));

    // Computed-torque feedforward + PID + velocity feedforward
    tau1_cmd = Kp1*(q_des1 - q1) + Ki1*e1_int + Kd1*(qd_des1 - qd1) + J1d*qdd_des1 + Kvf1*qd_des1;
    tau2_cmd = Kp2*(q_des2 - q2) + Ki2*e2_int + Kd2*(qd_des2 - qd2) + (M11d*qdd_des2 + M12d*qdd_des3 + C1d + G1d) + Kvf2*qd_des2;
    tau3_cmd = Kp3*(q_des3 - q3) + Ki3*e3_int + Kd3*(qd_des3 - qd3) + (M12d*qdd_des2 + M22d*qdd_des3 + C2d + G2d) + Kvf3*qd_des3;
  end when;

  // ============================================================
  // Torque saturation (effort bound 61.2 N.m per joint)
  // ============================================================
  tau1_raw = tau1_cmd;
  tau2_raw = tau2_cmd;
  tau3_raw = tau3_cmd;
  tau1 = if tau1_raw > tau_max then tau_max elseif tau1_raw < -tau_max then -tau_max else tau1_raw;
  tau2 = if tau2_raw > tau_max then tau_max elseif tau2_raw < -tau_max then -tau_max else tau2_raw;
  tau3 = if tau3_raw > tau_max then tau_max elseif tau3_raw < -tau_max then -tau_max else tau3_raw;

  // ============================================================
  // Collision geometry (joint limits matching mechanism)
  // ============================================================
  collision = noEvent((q1 < -q_lim) or (q1 > q_lim) or (q2 < -q_lim) or (q2 > q_lim) or (q3 < -q_lim) or (q3 > q_lim));

  // ============================================================
  // Bounds checking: position, velocity, acceleration, effort
  // ============================================================
  bounds_ok = noEvent(
    (abs(q1) <= pos_bound) and (abs(q2) <= pos_bound) and (abs(q3) <= pos_bound)
    and (abs(qd1) <= vel_bound) and (abs(qd2) <= vel_bound) and (abs(qd3) <= vel_bound)
    and (abs(qdd1) <= acc_bound) and (abs(qdd2) <= acc_bound) and (abs(qdd3) <= acc_bound)
    and (abs(tau1) <= tau_max + 1.0e-6) and (abs(tau2) <= tau_max + 1.0e-6) and (abs(tau3) <= tau_max + 1.0e-6)
  );

  // ============================================================
  // Terminal settling: tracking error below 0.041 rad after 5.2 s
  // ============================================================
  track_ok = noEvent(if time >= t_settle then track_err <= track_err_bound else true);

  // ============================================================
  // NaN / infinity check on physical, control, and estimator values
  // ============================================================
  no_nan_inf = noEvent(
    (abs(q1) < 1.0e20) and (abs(q2) < 1.0e20) and (abs(q3) < 1.0e20)
    and (abs(qd1) < 1.0e20) and (abs(qd2) < 1.0e20) and (abs(qd3) < 1.0e20)
    and (abs(qdd1) < 1.0e20) and (abs(qdd2) < 1.0e20) and (abs(qdd3) < 1.0e20)
    and (abs(tau1) < 1.0e20) and (abs(tau2) < 1.0e20) and (abs(tau3) < 1.0e20)
    and (abs(e1) < 1.0e20) and (abs(e2) < 1.0e20) and (abs(e3) < 1.0e20)
    and (abs(track_err) < 1.0e20) and (abs(payload_factor) < 1.0e20) and (abs(m3_eff) < 1.0e20)
  );

  // ============================================================
  // Assertions
  // ============================================================
  assert(no_nan_inf, "NaN or infinite value detected in physical, control, or estimator variables");
  assert(not collision, "Joint collision or limit violation detected");
  assert(track_ok, "Primary tracking error exceeds 0.041 rad after 5.2 s");
  assert(bounds_ok, "Position, velocity, acceleration, or effort bounds violated");

  annotation(
    Experiment(StopTime = 8.0, StartTime = 0, Tolerance = 1e-6, Interval = 0.0125),
    Documentation(info = "Three-revolute Z-Y-Y arm (0.50, 0.38, 0.24 m links) with encoder feedback, "
      ~ "torque-limited actuators (61.2 N.m), cubic trajectory interpolation through a midpoint, "
      ~ "PID + velocity feedforward + computed-torque control at 80 Hz, 2.5 percent payload disturbance "
      ~ "during the middle third of the 8 s scenario. Values not stated in the requirement (masses, "
      ~ "gains, waypoints, bounds) are declared as parameters with placeholder defaults and labeled accordingly.")
  );
end JointPathMoveA;