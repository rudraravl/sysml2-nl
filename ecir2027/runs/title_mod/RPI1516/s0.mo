model SevenPathMoveD
  "Seven-revolute-joint arm with synchronized PTP trajectory control, "
  "alternating Z/Y axes, capsule links, encoder sensing, effort actuators "
  "with PID + velocity feedforward, 5%% payload disturbance in middle third."

  // ---- Structural parameters ----
  parameter Integer n = 7 "Number of revolute joints";
  parameter Real L[7] = {0.34, 0.30, 0.26, 0.22, 0.18, 0.15, 0.12}
    "Capsule link lengths [m], decreasing 0.34..0.12";
  parameter Real m_link[7] = {3.0, 2.5, 2.0, 1.6, 1.2, 0.9, 0.6}
    "Link masses [kg]";
  parameter Real m_payload_base = 1.0 "Payload base mass [kg]";
  parameter Real g_acc = 9.81 "Gravity acceleration [m/s^2]";
  parameter Real tau_max = 115.0 "Maximum actuator effort [N.m]";
  parameter Real Ts = 0.005 "Control sample period (200 Hz) [s]";
  parameter Real t_mid = 7.0 "Midpoint time [s]";
  parameter Real t_end = 14.0 "Final time [s]";

  // Axis type: 1 = Z (vertical rotation axis), 2 = Y (horizontal rotation axis)
  parameter Integer axis[7] = {1, 2, 1, 2, 1, 2, 1};

  // ---- Declared waypoints (initial state is zero) ----
  // Values below are chosen to satisfy the stated motion; anything not stated
  // in the requirement is treated as an assumption and noted as such.
  parameter Real q_mid[7] = {0.30, 0.25, 0.20, 0.15, 0.10, 0.08, 0.05}
    "Midpoint joint configuration [rad] (assumed)";
  parameter Real q_end[7] = {0.60, 0.50, 0.40, 0.30, 0.20, 0.16, 0.10}
    "Declared final joint configuration [rad] (assumed)";

  // ---- Controller gains (PID + velocity feedforward) ----
  parameter Real Kp[7] = {140, 120, 100, 90, 80, 70, 60}  "Proportional gain";
  parameter Real Kd[7] = {10, 9, 8, 6, 5, 4, 3}           "Derivative gain";
  parameter Real Ki[7] = {6, 5, 4, 3, 2.5, 2, 1.5}        "Integral gain";
  parameter Real Kv[7] = {0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5}
    "Velocity feedforward gain";

  // ---- Physical bounds ----
  parameter Real q_bound  = 3.14 "Position bound [rad]";
  parameter Real qd_bound = 12.0 "Velocity bound [rad/s]";
  parameter Real qdd_bound = 80.0 "Acceleration bound [rad/s^2]";

  // ---- Continuous states ----
  Real q[7](start = zeros(7))  "Joint position [rad] (encoder)";
  Real qd[7](start = zeros(7)) "Joint velocity [rad/s] (encoder)";
  Real qdd[7]                  "Joint acceleration [rad/s^2]";

  // ---- Desired trajectory (cubic interpolation) ----
  Real q_des[7];
  Real qd_des[7];
  Real qdd_des[7];

  // ---- Sensors ----
  Real q_meas[7];
  Real qd_meas[7];

  // ---- Effort ----
  Real tau[7]                       "Saturated actuator effort [N.m]";
  discrete Real tau_cmd[7](each start = 0.0) "Commanded effort [N.m]";
  discrete Real integ_err[7](each start = 0.0) "PID integral state";

  // ---- Effective dynamics quantities ----
  Real J_eff[7];
  Real tau_grav[7];
  Real m_payload;
  Real dist_factor;
protected
  Real m_eff[7];

  // ---- Error and observation signals ----
  Real err[7];
  Real tracking_err_norm "Primary tracking error norm [rad]";
  Real pos_violation;
  Real vel_violation;
  Real acc_violation;
  Real eff_violation;
  Real settling_ok "1 if tracking_err_norm < 0.03 after 9.1 s, else 0";
  Real traj_phase "0=start,1=mid-third,2=end-third";

equation
  // Payload disturbance: +5%% during middle third of the 14 s run
  dist_factor = if (time >= t_end/3.0 and time <= 2.0*t_end/3.0) then 1.05 else 1.0;
  m_payload   = m_payload_base * dist_factor;
  traj_phase  = if time < t_end/3.0 then 0.0
                else if time <= 2.0*t_end/3.0 then 1.0 else 2.0;

  // Effective mass / inertia / gravity torque per joint.
  // Z-axis joints (axis=1) rotate about vertical: no direct gravity torque.
  // Y-axis joints (axis=2) rotate about horizontal: gravity torque = g*m_eff*L*cos(q).
  for i in 1:7 loop
    m_eff[i]   = m_link[i]/2.0 + sum(m_link[j] for j in (i+1):7) + m_payload;
    J_eff[i]   = m_eff[i]*L[i]*L[i];
    tau_grav[i] = if axis[i] == 2 then g_acc*m_eff[i]*L[i]*cos(q[i]) else 0.0;
  end for;

  // Plant dynamics: independent lumped joints with viscous damping.
  for i in 1:7 loop
    der(q[i])  = qd[i];
    der(qd[i]) = qdd[i];
    qdd[i]     = (tau[i] - tau_grav[i] - 0.3*qd[i]) / J_eff[i];
    // Actuator saturation (effort bound = 115 N.m)
    tau[i]     = max(-tau_max, min(tau_max, tau_cmd[i]));
    // Encoders report every controlled coordinate and velocity
    q_meas[i]  = q[i];
    qd_meas[i] = qd[i];
    err[i]     = q_des[i] - q[i];
  end for;

  // ---- Cubic Hermite trajectory with zero endpoint velocities per segment ----
  // Segment 1: 0 -> t_mid (0 -> q_mid). Segment 2: t_mid -> t_end (q_mid -> q_end).
  for i in 1:7 loop
    if time <= t_mid then
      q_des[i]   = q_mid[i]*(3.0*(time/t_mid)^2 - 2.0*(time/t_mid)^3);
      qd_des[i]  = q_mid[i]*(6.0*(time/t_mid) - 6.0*(time/t_mid)^2)/t_mid;
      qdd_des[i] = q_mid[i]*(6.0 - 12.0*(time/t_mid))/(t_mid*t_mid);
    else
      q_des[i]   = q_mid[i] + (q_end[i] - q_mid[i])*
                   (3.0*((time - t_mid)/(t_end - t_mid))^2
                  - 2.0*((time - t_mid)/(t_end - t_mid))^3);
      qd_des[i]  = (q_end[i] - q_mid[i])*
                   (6.0*((time - t_mid)/(t_end - t_mid))
                  - 6.0*((time - t_mid)/(t_end - t_mid))^2)/(t_end - t_mid);
      qdd_des[i] = (q_end[i] - q_mid[i])*
                   (6.0 - 12.0*((time - t_mid)/(t_end - t_mid)))/
                   ((t_end - t_mid)*(t_end - t_mid));
    end if;
  end for;

  // Tracking error norm with well-defined zero branch.
  tracking_err_norm = sqrt(sum(err[i]*err[i] for i in 1:7) + 1e-12);

  // Terminal settling indicator: primary tracking error below 0.03 rad after 9.1 s.
  settling_ok = if time >= 9.1 then (if tracking_err_norm < 0.03 then 1.0 else 0.0) else 0.0;

  // Bounds observability (positive => violation).
  pos_violation = max(abs(q[i])    for i in 1:7) - q_bound;
  vel_violation = max(abs(qd[i])   for i in 1:7) - qd_bound;
  acc_violation = max(abs(qdd[i])  for i in 1:7) - qdd_bound;
  eff_violation = max(abs(tau[i])  for i in 1:7) - tau_max;

algorithm
  // Discrete 200 Hz controller: PID + velocity feedforward with anti-windup.
  when sample(0, Ts) then
    for i in 1:7 loop
      integ_err[i] := pre(integ_err[i]) + Ts*(q_des[i] - q[i]);
      // Anti-windup clamp
      if integ_err[i] >  40.0 then
        integ_err[i] :=  40.0;
      elseif integ_err[i] < -40.0 then
        integ_err[i] := -40.0;
      end if;
      tau_cmd[i] := Kp[i]*(q_des[i] - q[i])
                  + Kd[i]*(qd_des[i] - qd[i])
                  + Ki[i]*integ_err[i]
                  + Kv[i]*qd_des[i];
    end for;
  end when;

  // Safety assertions for non-finite / out-of-bounds physical and control values.
  for i in 1:7 loop
    assert(not isNaN(q[i]) and not isInf(q[i]),     "Non-finite joint position detected");
    assert(not isNaN(qd[i]) and not isInf(qd[i]),   "Non-finite joint velocity detected");
    assert(not isNaN(qdd[i]) and not isInf(qdd[i]), "Non-finite joint acceleration detected");
    assert(not isNaN(tau[i]) and not isInf(tau[i]), "Non-finite effort detected");
    assert(abs(q[i])  <= q_bound  + 1e-6, "Position bound violated");
    assert(abs(qd[i]) <= qd_bound + 1e-6, "Velocity bound violated");
    assert(abs(qdd[i])<= qdd_bound+ 1e-6, "Acceleration bound violated");
    assert(abs(tau[i])<= tau_max  + 1e-6, "Effort bound violated");
  end for;

  assert(not isNaN(tracking_err_norm) and not isInf(tracking_err_norm),
         "Non-finite tracking error norm");
end SevenPathMoveD;