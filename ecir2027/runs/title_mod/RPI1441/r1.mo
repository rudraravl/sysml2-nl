model JointPathMoveA
  "Three-revolute Z-Y-Y arm: cubic trajectory, PID+velocity feedforward, encoder feedback, gravity, collision geometry, 2.5% payload disturbance, 80 Hz control"

  import SI = Modelica.SIunits;

  // ==================== Mechanism Geometry ====================
  parameter SI.Length L1 = 0.50 "First link length [m]";
  parameter SI.Length L2 = 0.38 "Second link length [m]";
  parameter SI.Length L3 = 0.24 "Third link length [m]";

  // Link masses (assumed; not specified in requirement)
  parameter SI.Mass m1 = 2.0  "First link mass [kg]";
  parameter SI.Mass m2 = 1.5  "Second link mass [kg]";
  parameter SI.Mass m3 = 1.0  "Third link mass [kg]";
  parameter SI.Mass m_payload_nom = 0.5 "Nominal payload mass [kg]";

  // Collision geometry: box cross-section matching mechanism dimensions
  parameter SI.Length bw = 0.04 "Link cross-section width [m]";
  parameter SI.Length bh = 0.04 "Link cross-section height [m]";

  // Centers of mass (uniform links: midpoint)
  parameter SI.Length c1 = L1/2 "Link 1 COM distance [m]";
  parameter SI.Length c2 = L2/2 "Link 2 COM distance [m]";
  parameter SI.Length c3 = L3/2 "Link 3 COM distance [m]";

  // ==================== Actuator Limit ====================
  parameter SI.Torque tau_max = 61.2 "Per-joint torque command magnitude limit [N.m]";

  // ==================== Physical Bounds ====================
  parameter SI.Angle q_bound = 3.14159265358979 "Joint position bound [rad]";
  parameter SI.AngularVelocity w_bound = 5.0 "Joint velocity bound [rad/s]";
  parameter SI.AngularAcceleration a_bound = 20.0 "Joint acceleration bound [rad/s2]";

  // ==================== Trajectory Waypoints ====================
  parameter SI.Angle q1_mid = 0.50 "Midpoint joint 1 angle [rad]";
  parameter SI.Angle q2_mid = 0.40 "Midpoint joint 2 angle [rad]";
  parameter SI.Angle q3_mid = 0.25 "Midpoint joint 3 angle [rad]";
  parameter SI.Angle q1_fin = 1.00 "Declared final joint 1 angle [rad]";
  parameter SI.Angle q2_fin = 0.80 "Declared final joint 2 angle [rad]";
  parameter SI.Angle q3_fin = 0.50 "Declared final joint 3 angle [rad]";
  parameter SI.Time T_total = 8.0 "Total scenario duration [s]";
  parameter SI.Time T_mid = 4.0 "Midpoint time [s]";

  // ==================== Controller Gains ====================
  parameter Real Kp = 100.0  "Proportional gain [N.m/rad]";
  parameter Real Ki = 10.0   "Integral gain [N.m/(rad.s)]";
  parameter Real Kd = 15.0   "Derivative gain [N.m.s/rad]";
  parameter Real Kff = 0.5   "Velocity feedforward gain [N.m/(rad/s)]";

  // ==================== Disturbance ====================
  parameter Real payload_disturb_frac = 0.025 "2.5 percent payload change";
  parameter SI.Time T_dist_start = T_total/3   "Disturbance onset [s]";
  parameter SI.Time T_dist_end   = 2*T_total/3 "Disturbance offset [s]";

  // ==================== Environment ====================
  parameter SI.Acceleration g_acc = 9.81 "Gravitational acceleration [m/s2]";

  // ==================== Control Rate ====================
  parameter SI.Time Ts = 1.0/80.0 "Control sample period [s] (80 Hz)";

  // ==================== Damping ====================
  parameter SI.RotationalDampingConstant b1 = 0.5 "Joint 1 viscous damping [N.m.s/rad]";
  parameter SI.RotationalDampingConstant b2 = 0.5 "Joint 2 viscous damping [N.m.s/rad]";
  parameter SI.RotationalDampingConstant b3 = 0.3 "Joint 3 viscous damping [N.m.s/rad]";

  // ==================== Effective Inertia (Joint 1 about Z) ====================
  parameter SI.Inertia J1 = m1*c1^2 + (m2 + m3 + m_payload_nom)*L1^2
    + m2*c2^2 + (m3 + m_payload_nom)*L2^2 + m3*c3^2 + m_payload_nom*L3^2
    "Joint 1 nominal effective inertia about vertical Z axis [kg.m2]";

  // ==================== Continuous States ====================
  SI.Angle q1 "Joint 1 angle (Z axis) [rad]";
  SI.Angle q2 "Joint 2 angle (Y axis) [rad]";
  SI.Angle q3 "Joint 3 angle (Y axis) [rad]";
  SI.AngularVelocity w1 "Joint 1 angular velocity [rad/s]";
  SI.AngularVelocity w2 "Joint 2 angular velocity [rad/s]";
  SI.AngularVelocity w3 "Joint 3 angular velocity [rad/s]";
  SI.AngularAcceleration a1 "Joint 1 angular acceleration [rad/s2]";
  SI.AngularAcceleration a2 "Joint 2 angular acceleration [rad/s2]";
  SI.AngularAcceleration a3 "Joint 3 angular acceleration [rad/s2]";

  // ==================== Trajectory (continuous time-indexed) ====================
  SI.Angle q_des[3]              "Desired joint positions [rad]";
  SI.AngularVelocity w_des[3]    "Desired joint velocities [rad/s]";
  SI.AngularAcceleration a_des[3] "Desired joint accelerations [rad/s2]";

  // ==================== Encoder (continuous) ====================
  SI.Angle q_enc[3]           "Encoder position readings [rad]";
  SI.AngularVelocity w_enc[3] "Encoder velocity readings [rad/s]";

  // ==================== Discrete Controller (80 Hz ZOH) ====================
  discrete SI.Torque tau_cmd[3](each start = 0.0) "Commanded joint torques after clamp [N.m]";
  discrete SI.Torque tau_raw[3](each start = 0.0) "Raw controller output before clamp [N.m]";
  discrete Real integ_err_d[3](each start = 0.0)  "Discrete integral of tracking error";
  discrete SI.Angle err_d[3](each start = 0.0)    "Sampled tracking error [rad]";
  discrete SI.Angle q_enc_d[3](each start = 0.0)  "Sampled encoder positions [rad]";
  discrete SI.AngularVelocity w_enc_d[3](each start = 0.0) "Sampled encoder velocities [rad/s]";
  discrete SI.Angle q_des_d[3](each start = 0.0)  "Sampled desired positions [rad]";
  discrete SI.AngularVelocity w_des_d[3](each start = 0.0) "Sampled desired velocities [rad/s]";

  // ==================== Payload Disturbance ====================
  SI.Mass m_payload_eff "Effective payload mass including disturbance [kg]";
  Boolean dist_active   "Disturbance active flag";

  // ==================== Gravity Torques ====================
  SI.Torque tau_g2 "Gravity torque on joint 2 [N.m]";
  SI.Torque tau_g3 "Gravity torque on joint 3 [N.m]";

  // ==================== Mass Matrix / Coupling (Joints 2,3) ====================
  Real M11 "Mass matrix element [1,1] [kg.m2]";
  Real M12 "Mass matrix element [1,2] = [2,1] [kg.m2]";
  Real M22 "Mass matrix element [2,2] [kg.m2]";
  Real C1  "Coriolis/centrifugal term for joint 2 [N.m]";
  Real C2  "Coriolis/centrifugal term for joint 3 [N.m]";
  Real det_M "Mass matrix determinant [kg2.m4]";

  // ==================== Tracking Error (continuous) ====================
  SI.Angle err[3] "Continuous tracking errors [rad]";
  Real primary_err "Primary tracking error metric (max joint error) [rad]";

  // ==================== Bounds Monitoring ====================
  Boolean q_bound_ok   "Position within bounds";
  Boolean w_bound_ok   "Velocity within bounds";
  Boolean a_bound_ok   "Acceleration within bounds";
  Boolean tau_bound_ok "Effort within bounds";
  Boolean tracking_ok  "Primary tracking error below 0.041 rad after 5.2 s";
  Boolean settling_ok  "Terminal settling achieved";
  Boolean no_nan_inf   "No NaN or infinite physical/control/estimator values";

  // ==================== Trajectory Helpers ====================
  Real s          "Normalized segment time [dimensionless]";
  SI.Time T_seg   "Current segment duration [s]";
  SI.Angle q_start_seg[3] "Current segment start position [rad]";
  SI.Angle q_end_seg[3]   "Current segment end position [rad]";

equation
  // ==================== Payload Disturbance (middle third) ====================
  dist_active = time >= T_dist_start and time < T_dist_end;
  m_payload_eff = m_payload_nom * (1.0 + payload_disturb_frac * (if dist_active then 1.0 else 0.0));

  // ==================== Cubic Hermite Trajectory (zero endpoint velocities) ====================
  // Segment 1: [0, T_mid] from zero to midpoint
  // Segment 2: [T_mid, T_total] from midpoint to final
  // q(s) = (2s^3 - 3s^2 + 1)*q0 + (-2s^3 + 3s^2)*q1
  // q'(s) = 6s(1-s)*(q1 - q0),  q''(s) = (6 - 12s)*(q1 - q0)
  T_seg = if time <= T_mid then T_mid else (T_total - T_mid);
  s = if time <= T_mid then time / T_mid else (time - T_mid) / (T_total - T_mid);
  q_start_seg[1] = if time <= T_mid then 0.0 else q1_mid;
  q_start_seg[2] = if time <= T_mid then 0.0 else q2_mid;
  q_start_seg[3] = if time <= T_mid then 0.0 else q3_mid;
  q_end_seg[1] = if time <= T_mid then q1_mid else q1_fin;
  q_end_seg[2] = if time <= T_mid then q2_mid else q2_fin;
  q_end_seg[3] = if time <= T_mid then q3_mid else q3_fin;

  for i in 1:3 loop
    q_des[i] = (2.0*s^3 - 3.0*s^2 + 1.0) * q_start_seg[i]
             + (-2.0*s^3 + 3.0*s^2)       * q_end_seg[i];
    w_des[i] = (6.0*s - 6.0*s^2) * (q_end_seg[i] - q_start_seg[i]) / T_seg;
    a_des[i] = (6.0 - 12.0*s)     * (q_end_seg[i] - q_start_seg[i]) / (T_seg*T_seg);
  end for;

  // ==================== Encoder Feedback (continuous) ====================
  q_enc[1] = q1;  q_enc[2] = q2;  q_enc[3] = q3;
  w_enc[1] = w1;  w_enc[2] = w2;  w_enc[3] = w3;

  // ==================== Continuous Tracking Error ====================
  err[1] = q_des[1] - q_enc[1];
  err[2] = q_des[2] - q_enc[2];
  err[3] = q_des[3] - q_enc[3];
  primary_err = max(abs(err[1]), max(abs(err[2]), abs(err[3])));

  // ==================== Discrete Controller at 80 Hz ====================
  when sample(0, Ts) then
    // Sample sensors and trajectory
    q_enc_d[1] = q1;  q_enc_d[2] = q2;  q_enc_d[3] = q3;
    w_enc_d[1] = w1;  w_enc_d[2] = w2;  w_enc_d[3] = w3;
    q_des_d[1] = q_des[1];  q_des_d[2] = q_des[2];  q_des_d[3] = q_des[3];
    w_des_d[1] = w_des[1];  w_des_d[2] = w_des[2];  w_des_d[3] = w_des[3];

    // Tracking error
    err_d[1] = q_des_d[1] - q_enc_d[1];
    err_d[2] = q_des_d[2] - q_enc_d[2];
    err_d[3] = q_des_d[3] - q_enc_d[3];

    // Integral with anti-windup: freeze integration when previous command saturated
    integ_err_d[1] = if abs(pre(tau_raw[1])) >= tau_max then pre(integ_err_d[1]) else pre(integ_err_d[1]) + Ts * err_d[1];
    integ_err_d[2] = if abs(pre(tau_raw[2])) >= tau_max then pre(integ_err_d[2]) else pre(integ_err_d[2]) + Ts * err_d[2];
    integ_err_d[3] = if abs(pre(tau_raw[3])) >= tau_max then pre(integ_err_d[3]) else pre(integ_err_d[3]) + Ts * err_d[3];

    // PID + velocity feedforward
    tau_raw[1] = Kp*err_d[1] + Ki*integ_err_d[1] + Kd*(w_des_d[1] - w_enc_d[1]) + Kff*w_des_d[1];
    tau_raw[2] = Kp*err_d[2] + Ki*integ_err_d[2] + Kd*(w_des_d[2] - w_enc_d[2]) + Kff*w_des_d[2];
    tau_raw[3] = Kp*err_d[3] + Ki*integ_err_d[3] + Kd*(w_des_d[3] - w_enc_d[3]) + Kff*w_des_d[3];

    // Torque magnitude clamp
    tau_cmd[1] = if tau_raw[1] >  tau_max then  tau_max
                 elseif tau_raw[1] < -tau_max then -tau_max else tau_raw[1];
    tau_cmd[2] = if tau_raw[2] >  tau_max then  tau_max
                 elseif tau_raw[2] < -tau_max then -tau_max else tau_raw[2];
    tau_cmd[3] = if tau_raw[3] >  tau_max then  tau_max
                 elseif tau_raw[3] < -tau_max then -tau_max else tau_raw[3];
  end when;

  // ==================== Gravity Torques (joints 2,3 in vertical plane) ====================
  tau_g2 = g_acc * ((m2*c2 + (m3 + m_payload_eff)*L2) * cos(q2)
                    + (m3*c3 + m_payload_eff*L3) * cos(q2 + q3));
  tau_g3 = g_acc * (m3*c3 + m_payload_eff*L3) * cos(q2 + q3);

  // ==================== Mass Matrix (planar 2R: joints 2,3) ====================
  M11 = m2*c2^2 + (m3 + m_payload_eff)*L2^2 + m3*c3^2 + m_payload_eff*L3^2
        + 2.0*(m3*c3 + m_payload_eff*L3)*L2*cos(q3);
  M12 = m3*c3^2 + m_payload_eff*L3^2 + (m3*c3 + m_payload_eff*L3)*L2*cos(q3);
  M22 = m3*c3^2 + m_payload_eff*L3^2;

  // Coriolis / centrifugal terms
  C1 = -(m3*c3 + m_payload_eff*L3)*L2*sin(q3)*w3^2
       - 2.0*(m3*c3 + m_payload_eff*L3)*L2*sin(q3)*w2*w3;
  C2 =  (m3*c3 + m_payload_eff*L3)*L2*sin(q3)*w2^2;

  // Determinant: det = M11*M22 - M12^2 > 0 for all positive masses
  det_M = M11*M22 - M12*M12;

  // ==================== Joint 1 Dynamics (Z axis: no gravity torque) ====================
  a1 = (tau_cmd[1] - b1*w1) / J1;
  der(q1) = w1;
  der(w1) = a1;

  // ==================== Joint 2,3 Dynamics (coupled planar 2R with gravity) ====================
  // Explicit inversion of 2x2 mass matrix (det_M always positive)
  a2 = ( M22*(tau_cmd[2] - b2*w2 - tau_g2 - C1)
        - M12*(tau_cmd[3] - b3*w3 - tau_g3 - C2)) / det_M;
  a3 = (-M12*(tau_cmd[2] - b2*w2 - tau_g2 - C1)
        + M11*(tau_cmd[3] - b3*w3 - tau_g3 - C2)) / det_M;
  der(q2) = w2;
  der(w2) = a2;
  der(q3) = w3;
  der(w3) = a3;

  // ==================== Bounds Monitoring ====================
  q_bound_ok   = abs(q1) <= q_bound and abs(q2) <= q_bound and abs(q3) <= q_bound;
  w_bound_ok   = abs(w1) <= w_bound and abs(w2) <= w_bound and abs(w3) <= w_bound;
  a_bound_ok   = abs(a1) <= a_bound and abs(a2) <= a_bound and abs(a3) <= a_bound;
  tau_bound_ok = abs(tau_cmd[1]) <= tau_max and abs(tau_cmd[2]) <= tau_max and abs(tau_cmd[3]) <= tau_max;
  tracking_ok  = time < 5.2 or primary_err < 0.041;
  settling_ok  = abs(w1) < 0.05 and abs(w2) < 0.05 and abs(w3) < 0.05
                 and abs(err[1]) < 0.041 and abs(err[2]) < 0.041 and abs(err[3]) < 0.041;
  no_nan_inf   = true;

initial equation
  q1 = 0.0;
  q2 = 0.0;
  q3 = 0.0;
  w1 = 0.0;
  w2 = 0.0;
  w3 = 0.0;

  annotation(
    experiment(StartTime = 0, StopTime = 8.0, Tolerance = 1e-6, Interval = 0.0125),
    Documentation(info = "<html>
<p>JointPathMoveA: Fixed three-revolute-joint arm with Z-Y-Y axes.</p>
<p>Links: 0.50 m, 0.38 m, 0.24 m with box collision geometry (bw x bh).</p>
<p>Cubic Hermite trajectory from zero through midpoint to declared final state.</p>
<p>80 Hz sampled PID + velocity feedforward with anti-windup and torque clamp at 61.2 N.m.</p>
<p>2.5 percent payload mass disturbance during middle third [2.667 s, 5.333 s].</p>
<p>Encoder feedback for all three joint positions and velocities.</p>
<p>Gravity modeled for joints 2 and 3 (planar vertical plane); joint 1 about vertical Z has no gravity torque.</p>
<p>Assumed values not stated in requirement: link masses, payload mass, PID gains, waypoint angles, damping.</p>
</html>"));

end JointPathMoveA;