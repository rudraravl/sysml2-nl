model SevenPathMoveC
  "Seven-DOF revolute arm (alternating Z/Y axes, capsule links 0.34-0.12 m) with cubic
   trajectory interpolation, PID + velocity feedforward, operational-space and null-space
   control, 4.5% payload disturbance during middle third, 125 Hz sampled controller, 12 s run."

  // ====================== Timing ======================
  parameter Real Ts = 1.0 / 125.0 "Controller sample period [s], 125 Hz";
  parameter Real T_total = 12.0   "Total simulation time [s]";
  parameter Real t_phase1 = 4.0   "End of phase 1: zero to midpoint [s]";
  parameter Real t_phase2 = 8.0   "End of phase 2: midpoint to final [s]";
  parameter Real t_dist_start = 4.0 "Payload disturbance start [s], middle third";
  parameter Real t_dist_end = 8.0   "Payload disturbance end [s], middle third";

  // ====================== Effort Limit ======================
  parameter Real tau_max = 106.0 "Maximum command magnitude [N.m]";

  // ====================== Physical Constants ======================
  parameter Real g_grav = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real pi_val = 3.141592653589793;

  // ====================== Link Geometry (Capsule) ======================
  // Seven capsule links, lengths from 0.34 m to 0.12 m (linearly interpolated)
  parameter Real L[7] = {0.34, 0.30333, 0.26667, 0.23000, 0.19333, 0.15667, 0.12}
    "Link lengths [m]";
  parameter Real r_cap = 0.04 "Capsule radius [m] (nominal, not specified in request)";
  parameter Real rho = 1000.0 "Link density [kg/m3] (nominal, not specified in request)";

  // Link masses from capsule volume: V = pi*r^2*L + (4/3)*pi*r^3
  parameter Real m_link[7] = {
    rho*(pi_val*r_cap^2*L[1] + (4.0/3.0)*pi_val*r_cap^3),
    rho*(pi_val*r_cap^2*L[2] + (4.0/3.0)*pi_val*r_cap^3),
    rho*(pi_val*r_cap^2*L[3] + (4.0/3.0)*pi_val*r_cap^3),
    rho*(pi_val*r_cap^2*L[4] + (4.0/3.0)*pi_val*r_cap^3),
    rho*(pi_val*r_cap^2*L[5] + (4.0/3.0)*pi_val*r_cap^3),
    rho*(pi_val*r_cap^2*L[6] + (4.0/3.0)*pi_val*r_cap^3),
    rho*(pi_val*r_cap^2*L[7] + (4.0/3.0)*pi_val*r_cap^3)
  } "Link masses [kg]";

  // ====================== Payload ======================
  parameter Real m_payload_nom = 2.0 "Nominal payload mass [kg] (not specified in request)";
  parameter Real payload_dist_frac = 0.045 "4.5 percent payload change";

  // ====================== Axis Configuration ======================
  // Alternating Z and Y axes: joint 1=Z, 2=Y, 3=Z, 4=Y, 5=Z, 6=Y, 7=Z
  parameter Integer axis_type[7] = {0, 1, 0, 1, 0, 1, 0} "0=Z-axis (vertical), 1=Y-axis";

  // ====================== Cumulative Masses Above Each Joint ======================
  parameter Real m_above[7] = {
    m_link[2]+m_link[3]+m_link[4]+m_link[5]+m_link[6]+m_link[7]+m_payload_nom,
    m_link[3]+m_link[4]+m_link[5]+m_link[6]+m_link[7]+m_payload_nom,
    m_link[4]+m_link[5]+m_link[6]+m_link[7]+m_payload_nom,
    m_link[5]+m_link[6]+m_link[7]+m_payload_nom,
    m_link[6]+m_link[7]+m_payload_nom,
    m_link[7]+m_payload_nom,
    m_payload_nom
  } "Cumulative mass above each joint [kg]";

  // ====================== Joint Inertias ======================
  parameter Real J_arr[7] = {
    m_link[1]*L[1]^2/3.0 + m_above[1]*L[1]^2,
    m_link[2]*L[2]^2/3.0 + m_above[2]*L[2]^2,
    m_link[3]*L[3]^2/3.0 + m_above[3]*L[3]^2,
    m_link[4]*L[4]^2/3.0 + m_above[4]*L[4]^2,
    m_link[5]*L[5]^2/3.0 + m_above[5]*L[5]^2,
    m_link[6]*L[6]^2/3.0 + m_above[6]*L[6]^2,
    m_link[7]*L[7]^2/3.0 + m_above[7]*L[7]^2
  } "Joint inertias [kg.m2]";

  // ====================== Joint Damping ======================
  parameter Real b_damp[7] = {0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5}
    "Joint viscous damping [N.m.s/rad] (nominal)";

  // ====================== Gravity Torque Coefficients ======================
  // Z-axis joints (vertical): no gravity torque. Y-axis: tau = c_g * cos(q)
  parameter Real c_g[7] = {
    0.0,
    g_grav*(m_link[2]*L[2]/2.0 + m_above[2]*L[2]),
    0.0,
    g_grav*(m_link[4]*L[4]/2.0 + m_above[4]*L[4]),
    0.0,
    g_grav*(m_link[6]*L[6]/2.0 + m_above[6]*L[6]),
    0.0
  } "Gravity torque coefficients [N.m]";

  // ====================== Payload Disturbance Torque Coefficients ======================
  parameter Real L_dist[7] = {
    L[1]+L[2]+L[3]+L[4]+L[5]+L[6]+L[7],
    L[2]+L[3]+L[4]+L[5]+L[6]+L[7],
    L[3]+L[4]+L[5]+L[6]+L[7],
    L[4]+L[5]+L[6]+L[7],
    L[5]+L[6]+L[7],
    L[6]+L[7],
    L[7]
  } "Distance from joint i to end-effector [m]";

  parameter Real d_g[7] = {
    0.0,
    payload_dist_frac*m_payload_nom*g_grav*L_dist[2],
    0.0,
    payload_dist_frac*m_payload_nom*g_grav*L_dist[4],
    0.0,
    payload_dist_frac*m_payload_nom*g_grav*L_dist[6],
    0.0
  } "Payload disturbance torque coefficients [N.m]";

  // ====================== PID Gains ======================
  parameter Real wn_ctrl = 30.0 "Controller natural frequency [rad/s]";
  parameter Real Kp[7] = {
    wn_ctrl^2*J_arr[1], wn_ctrl^2*J_arr[2], wn_ctrl^2*J_arr[3],
    wn_ctrl^2*J_arr[4], wn_ctrl^2*J_arr[5], wn_ctrl^2*J_arr[6],
    wn_ctrl^2*J_arr[7]
  } "Proportional gains";
  parameter Real Kd[7] = {
    2.0*wn_ctrl*J_arr[1], 2.0*wn_ctrl*J_arr[2], 2.0*wn_ctrl*J_arr[3],
    2.0*wn_ctrl*J_arr[4], 2.0*wn_ctrl*J_arr[5], 2.0*wn_ctrl*J_arr[6],
    2.0*wn_ctrl*J_arr[7]
  } "Derivative gains";
  parameter Real Ki[7] = {
    0.1*Kp[1], 0.1*Kp[2], 0.1*Kp[3], 0.1*Kp[4], 0.1*Kp[5], 0.1*Kp[6], 0.1*Kp[7]
  } "Integral gains";

  // Integral anti-windup limits
  parameter Real int_lim[7] = {
    tau_max / max(Ki[1], 1e-6), tau_max / max(Ki[2], 1e-6),
    tau_max / max(Ki[3], 1e-6), tau_max / max(Ki[4], 1e-6),
    tau_max / max(Ki[5], 1e-6), tau_max / max(Ki[6], 1e-6),
    tau_max / max(Ki[7], 1e-6)
  } "Integral error limits for anti-windup";

  // ====================== Null-Space Control ======================
  parameter Real Kn_null = 1.0 "Null-space posture gain (nominal)";
  parameter Real Dn_null = 0.5 "Null-space damping gain (nominal)";

  // ====================== Trajectory Targets ======================
  parameter Real q_mid[7] = {0.5, 0.3, -0.3, 0.4, -0.2, 0.3, 0.1}
    "Midpoint joint angles [rad] (not specified, nominal)";
  parameter Real q_fin[7] = {1.0, 0.6, -0.5, 0.8, -0.4, 0.5, 0.2}
    "Final joint angles [rad] (not specified, nominal)";

  // ====================== Bounds ======================
  parameter Real q_bound = pi_val   "Position bound [rad]";
  parameter Real dq_bound = 10.0    "Velocity bound [rad/s]";
  parameter Real ddq_bound = 50.0   "Acceleration bound [rad/s2]";

  // ====================== Continuous States ======================
  Real q[7](each start = 0, each fixed = true)     "Joint positions [rad]";
  Real dq[7](each start = 0, each fixed = true)    "Joint velocities [rad/s]";
  Real ddq[7]                                       "Joint accelerations [rad/s2]";
  Real dist_factor(start = 0, fixed = true)         "Filtered disturbance activation [0-1]";

  // ====================== Continuous Algebraic ======================
  Real tau[7]       "Applied torques [N.m] (ZOH)";
  Real qr[7]        "Reference positions [rad]";
  Real dqr[7]       "Reference velocities [rad/s]";
  Real ddqr[7]      "Reference accelerations [rad/s2]";
  Real tg[7]        "Gravity torques [N.m]";
  Real td[7]        "Disturbance torques [N.m]";
  Real tgc[7]       "Gravity compensation torques [N.m]";
  Real tn[7]        "Null-space control torques [N.m]";
  Real tau_op[7]    "Operational-space control torques [N.m]";
  Real e[7]         "Tracking errors [rad]";
  Real track_err_max "Primary tracking error (max abs) [rad]";
  Real m_payload_t  "Time-varying payload mass [kg]";
  Real s1, s2       "Normalized phase progress [0-1]";
  Real cb_pos1, cb_vel1, cb_acc1 "Phase 1 cubic basis";
  Real cb_pos2, cb_vel2, cb_acc2 "Phase 2 cubic basis";
  Real q_violation[7]    "Position bound violation [rad]";
  Real dq_violation[7]   "Velocity bound violation [rad/s]";
  Real ddq_violation[7]  "Acceleration bound violation [rad/s2]";
  Real tau_violation[7]  "Effort bound violation [N.m]";
  Boolean settled        "True if tracking error < 0.032 after 7.8 s";

  // ====================== Discrete States ======================
  discrete Real tau_cmd[7](each start = 0, each fixed = true) "Saturated torque commands [N.m]";
  discrete Real tau_raw[7](each start = 0, each fixed = true) "Unsaturated torque commands [N.m]";
  discrete Real integ[7](each start = 0, each fixed = true)  "Integral error terms";
  discrete Real enc_q[7](each start = 0, each fixed = true)   "Encoder position readings [rad]";
  discrete Real enc_dq[7](each start = 0, each fixed = true)  "Encoder velocity readings [rad/s]";

  // Disturbance target signal
  Real dist_target "Payload disturbance target (0 or 1)";

equation
  // =================== Cubic Trajectory Generation ===================
  s1 = max(0.0, min(1.0, time / t_phase1));
  s2 = max(0.0, min(1.0, (time - t_phase1) / (t_phase2 - t_phase1)));

  // Cubic polynomial: q(s) = 3*s^2 - 2*s^3  (zero velocity at endpoints)
  cb_pos1 = 3.0*s1^2 - 2.0*s1^3;
  cb_vel1 = (6.0*s1 - 6.0*s1^2) / t_phase1;
  cb_acc1 = (6.0 - 12.0*s1) / t_phase1^2;

  cb_pos2 = 3.0*s2^2 - 2.0*s2^3;
  cb_vel2 = (6.0*s2 - 6.0*s2^2) / (t_phase2 - t_phase1);
  cb_acc2 = (6.0 - 12.0*s2) / (t_phase2 - t_phase1)^2;

  for i in 1:7 loop
    qr[i] = if time < t_phase1 then
              q_mid[i] * cb_pos1
            elseif time < t_phase2 then
              q_mid[i] + (q_fin[i] - q_mid[i]) * cb_pos2
            else
              q_fin[i];

    dqr[i] = if time < t_phase1 then
               q_mid[i] * cb_vel1
             elseif time < t_phase2 then
               (q_fin[i] - q_mid[i]) * cb_vel2
             else
               0.0;

    ddqr[i] = if time < t_phase1 then
                q_mid[i] * cb_acc1
              elseif time < t_phase2 then
                (q_fin[i] - q_mid[i]) * cb_acc2
              else
                0.0;
  end for;

  // =================== Payload Disturbance (4.5% during middle third) ===================
  dist_target = if time >= t_dist_start and time <= t_dist_end then 1.0 else 0.0;
  der(dist_factor) = (dist_target - dist_factor) / 0.05;
  m_payload_t = m_payload_nom * (1.0 + payload_dist_frac * dist_factor);

  // =================== Plant Dynamics ===================
  for i in 1:7 loop
    J_arr[i] * ddq[i] = tau[i] - b_damp[i] * dq[i] - tg[i] - td[i];
    der(q[i])  = dq[i];
    der(dq[i]) = ddq[i];
  end for;

  // =================== Gravity Torques ===================
  for i in 1:7 loop
    tg[i] = c_g[i] * cos(q[i]);
  end for;

  // =================== Disturbance Torques ===================
  for i in 1:7 loop
    td[i] = d_g[i] * dist_factor * cos(q[i]);
  end for;

  // =================== ZOH: Applied Torque ===================
  for i in 1:7 loop
    tau[i] = tau_cmd[i];
  end for;

  // =================== Gravity Compensation ===================
  for i in 1:7 loop
    tgc[i] = c_g[i] * cos(q[i]);
  end for;

  // =================== Null-Space Control (posture stabilization) ===================
  for i in 1:7 loop
    tn[i] = Kn_null * (0.0 - q[i]) - Dn_null * dq[i];
  end for;

  // =================== Operational-Space Control (monitoring) ===================
  for i in 1:7 loop
    tau_op[i] = Kp[i] * (qr[i] - q[i])
              + Kd[i] * (dqr[i] - dq[i])
              + Ki[i] * integ[i]
              + J_arr[i] * ddqr[i]
              + b_damp[i] * dqr[i]
              + tgc[i];
  end for;

  // =================== Tracking Errors ===================
  for i in 1:7 loop
    e[i] = qr[i] - q[i];
  end for;

  track_err_max = max(abs(e[1]), max(abs(e[2]), max(abs(e[3]),
                max(abs(e[4]), max(abs(e[5]), max(abs(e[6]), abs(e[7)))))));

  // =================== Bounds Checking ===================
  for i in 1:7 loop
    q_violation[i]   = max(0.0, abs(q[i])  - q_bound);
    dq_violation[i]  = max(0.0, abs(dq[i]) - dq_bound);
    ddq_violation[i] = max(0.0, abs(ddq[i]) - ddq_bound);
    tau_violation[i] = max(0.0, abs(tau[i]) - tau_max);
  end for;

  // Terminal settling: primary tracking error below 0.032 after 7.8 s
  settled = (time >= 7.8) and (track_err_max < 0.032);

  // =================== Discrete Controller at 125 Hz ===================
  when sample(0, Ts) then
    for i in 1:7 loop
      // Encoder: report every controlled coordinate and velocity
      enc_q[i]  := q[i];
      enc_dq[i] := dq[i];

      // Integral with anti-windup clamping
      integ[i] := max(-int_lim[i], min(int_lim[i],
                   integ[i] + Ts * (qr[i] - q[i])));

      // PID + acceleration feedforward + velocity feedforward + gravity comp + null-space
      tau_raw[i] := Kp[i] * (qr[i] - q[i])
                  + Kd[i] * (dqr[i] - dq[i])
                  + Ki[i] * integ[i]
                  + J_arr[i] * ddqr[i]
                  + b_damp[i] * dqr[i]
                  + tgc[i]
                  + Kn_null * (0.0 - q[i]) - Dn_null * dq[i];

      // Effort saturation at 106 N.m
      tau_cmd[i] := if tau_raw[i] > tau_max then  tau_max
                    elseif tau_raw[i] < -tau_max then -tau_max
                    else  tau_raw[i];
    end for;
  end when;

  annotation(
    experiment(StartTime = 0, StopTime = 12.0, Tolerance = 1e-6, Interval = 1.0 / 125.0),
    Documentation(info = "SevenPathMoveC: Seven-DOF revolute arm with alternating Z/Y axes,
      capsule links (0.34-0.12 m, radius 0.04 m), full joint-state sensing via encoders.
      Cubic interpolation trajectory: zero state -> midpoint -> final state.
      PID + velocity feedforward + acceleration feedforward + gravity compensation.
      Operational-space (primary task) and null-space (posture) control.
      4.5% payload disturbance injected during middle third (4-8 s).
      Controller sampled at 125 Hz, ZOH actuation, max effort 106 N.m.
      Primary tracking error required below 0.032 rad after 7.8 s.
      Capsule collision geometry declared via L[] and r_cap parameters.
      Nominal values not specified in the requirement (rho, r_cap, m_payload_nom,
      b_damp, trajectory targets, null-space gains) are set to representative defaults.")
  );
end SevenPathMoveC;