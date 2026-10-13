model SevenPathMoveD
  "Seven-revolute-joint arm trajectory control with PID and velocity feedforward";

  parameter Integer n = 7 "Number of revolute joints";
  parameter Real L[7] = {0.34, 0.30, 0.26, 0.22, 0.18, 0.15, 0.12}
    "Capsule link lengths [m]";
  parameter Real m_link[7] = {3.0, 2.5, 2.0, 1.6, 1.2, 0.9, 0.6}
    "Link masses [kg]";
  parameter Real m_payload_base = 1.0 "Payload base mass [kg]";
  parameter Real g_acc = 9.81 "Gravity acceleration [m/s^2]";
  parameter Real tau_max = 115.0 "Maximum actuator effort [N.m]";
  parameter Real Ts = 0.005 "Control sample period (200 Hz) [s]";
  parameter Real t_mid = 7.0 "Midpoint time [s]";
  parameter Real t_end = 14.0 "Final time [s]";
  parameter Integer axis[7] = {1, 2, 1, 2, 1, 2, 1}
    "Axis type: 1=Z, 2=Y";
  parameter Real q_mid[7] = {0.30, 0.25, 0.20, 0.15, 0.10, 0.08, 0.05}
    "Midpoint joint configuration [rad]";
  parameter Real q_end[7] = {0.60, 0.50, 0.40, 0.30, 0.20, 0.16, 0.10}
    "Final joint configuration [rad]";
  parameter Real Kp[7] = {140.0, 120.0, 100.0, 90.0, 80.0, 70.0, 60.0};
  parameter Real Kd[7] = {10.0, 9.0, 8.0, 6.0, 5.0, 4.0, 3.0};
  parameter Real Ki[7] = {6.0, 5.0, 4.0, 3.0, 2.5, 2.0, 1.5};
  parameter Real Kv[7] = {0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5};
  parameter Real q_bound = 3.14 "Position bound [rad]";
  parameter Real qd_bound = 12.0 "Velocity bound [rad/s]";
  parameter Real qdd_bound = 80.0 "Acceleration bound [rad/s^2]";

  Real q[7](each start = 0.0) "Joint position [rad] (encoder)";
  Real qd[7](each start = 0.0) "Joint velocity [rad/s] (encoder)";
  Real qdd[7] "Joint acceleration [rad/s^2]";
  Real q_des[7] "Desired position [rad]";
  Real qd_des[7] "Desired velocity [rad/s]";
  Real qdd_des[7] "Desired acceleration [rad/s^2]";
  Real q_meas[7] "Measured position [rad]";
  Real qd_meas[7] "Measured velocity [rad/s]";
  Real tau[7] "Saturated effort [N.m]";
  discrete Real tau_cmd[7](each start = 0.0) "Commanded effort [N.m]";
  discrete Real integ_err[7](each start = 0.0) "PID integral state";
  Real J_eff[7] "Effective inertia";
  Real tau_grav[7] "Gravity torque [N.m]";
  Real m_payload "Payload mass [kg]";
  Real dist_factor "Disturbance factor";
  Real err[7] "Tracking error [rad]";
  Real tracking_err_norm "Tracking error norm [rad]";
  Real pos_violation "Position bound violation";
  Real vel_violation "Velocity bound violation";
  Real acc_violation "Acceleration bound violation";
  Real eff_violation "Effort bound violation";
  Real settling_ok "Settling indicator";
  Real traj_phase "Trajectory phase";
protected
  Real m_eff[7] "Effective mass [kg]";
  Real abs_q[7] "Absolute positions";
  Real abs_qd[7] "Absolute velocities";
  Real abs_qdd[7] "Absolute accelerations";
  Real abs_tau[7] "Absolute efforts";

equation
  // Payload disturbance: +5 percent during middle third of 14 s run
  dist_factor = if (time >= t_end/3.0 and time <= 2.0*t_end/3.0) then 1.05 else 1.0;
  m_payload = m_payload_base * dist_factor;
  traj_phase = if time < t_end/3.0 then 0.0
    else if time <= 2.0*t_end/3.0 then 1.0 else 2.0;

  // Effective mass, inertia, and gravity torque per joint
  for i in 1:7 loop
    m_eff[i] = m_link[i]/2.0 + (if i < 7 then sum(m_link[j] for j in (i+1):7) else 0.0) + m_payload;
    J_eff[i] = m_eff[i]*L[i]*L[i];
    tau_grav[i] = if axis[i] == 2 then g_acc*m_eff[i]*L[i]*cos(q[i]) else 0.0;
  end for;

  // Plant dynamics: lumped joints with viscous damping
  for i in 1:7 loop
    der(q[i]) = qd[i];
    der(qd[i]) = qdd[i];
    qdd[i] = (tau[i] - tau_grav[i] - 0.3*qd[i]) / J_eff[i];
    tau[i] = max(-tau_max, min(tau_max, tau_cmd[i]));
    q_meas[i] = q[i];
    qd_meas[i] = qd[i];
    err[i] = q_des[i] - q[i];
    abs_q[i] = abs(q[i]);
    abs_qd[i] = abs(qd[i]);
    abs_qdd[i] = abs(qdd[i]);
    abs_tau[i] = abs(tau[i]);
  end for;

  // Cubic Hermite trajectory with zero endpoint velocities per segment
  for i in 1:7 loop
    if time <= t_mid then
      q_des[i] = q_mid[i]*(3.0*(time/t_mid)^2 - 2.0*(time/t_mid)^3);
      qd_des[i] = q_mid[i]*(6.0*(time/t_mid) - 6.0*(time/t_mid)^2)/t_mid;
      qdd_des[i] = q_mid[i]*(6.0 - 12.0*(time/t_mid))/(t_mid*t_mid);
    else
      q_des[i] = q_mid[i] + (q_end[i] - q_mid[i])*
        (3.0*((time - t_mid)/(t_end - t_mid))^2
        - 2.0*((time - t_mid)/(t_end - t_mid))^3);
      qd_des[i] = (q_end[i] - q_mid[i])*
        (6.0*((time - t_mid)/(t_end - t_mid))
        - 6.0*((time - t_mid)/(t_end - t_mid))^2)/(t_end - t_mid);
      qdd_des[i] = (q_end[i] - q_mid[i])*
        (6.0 - 12.0*((time - t_mid)/(t_end - t_mid)))/
        ((t_end - t_mid)*(t_end - t_mid));
    end if;
  end for;

  // Tracking error norm with well-defined zero-error branch
  tracking_err_norm = sqrt(err[1]*err[1] + err[2]*err[2] + err[3]*err[3]
    + err[4]*err[4] + err[5]*err[5] + err[6]*err[6] + err[7]*err[7] + 1e-12);

  // Terminal settling indicator
  settling_ok = if time >= 9.1 then (if tracking_err_norm < 0.03 then 1.0 else 0.0) else 0.0;

  // Bounds observability (positive means violation)
  pos_violation = max(abs_q) - q_bound;
  vel_violation = max(abs_qd) - qd_bound;
  acc_violation = max(abs_qdd) - qdd_bound;
  eff_violation = max(abs_tau) - tau_max;

  // Safety assertions
  for i in 1:7 loop
    assert(abs(q[i]) <= q_bound + 1e-6, "Position bound violated");
    assert(abs(qd[i]) <= qd_bound + 1e-6, "Velocity bound violated");
    assert(abs(qdd[i]) <= qdd_bound + 1e-6, "Acceleration bound violated");
    assert(abs(tau[i]) <= tau_max + 1e-6, "Effort bound violated");
  end for;

algorithm
  // Discrete 200 Hz controller: PID + velocity feedforward with anti-windup
  when sample(0, Ts) then
    for i in 1:7 loop
      integ_err[i] := pre(integ_err[i]) + Ts*(q_des[i] - q[i]);
      if integ_err[i] > 40.0 then
        integ_err[i] := 40.0;
      elseif integ_err[i] < -40.0 then
        integ_err[i] := -40.0;
      end if;
      tau_cmd[i] := Kp[i]*(q_des[i] - q[i])
        + Kd[i]*(qd_des[i] - qd[i])
        + Ki[i]*integ_err[i]
        + Kv[i]*qd_des[i];
    end for;
  end when;

end SevenPathMoveD;