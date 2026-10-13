model SevenPathMoveD
  "Seven-revolute-joint arm, synchronized PTP trajectory, PID + velocity feedforward, 5% payload disturbance in middle third"

  // Structural parameters
  parameter Integer n = 7 "Number of revolute joints";
  parameter Real L[7] = {0.34, 0.30, 0.26, 0.22, 0.18, 0.15, 0.12}
    "Capsule link lengths [m]";
  parameter Real m_link[7] = {3.0, 2.5, 2.0, 1.6, 1.2, 0.9, 0.6}
    "Link masses [kg]";
  parameter Real m_payload_base = 1.0 "Payload base mass [kg]";
  parameter Real g_acc = 9.81 "Gravity [m/s^2]";
  parameter Real tau_max = 115.0 "Max effort [N.m]";
  parameter Real Ts = 0.005 "Sample period (200 Hz) [s]";
  parameter Real t_mid = 7.0 "Midpoint time [s]";
  parameter Real t_end = 14.0 "Final time [s]";
  parameter Integer axis[7] = {1, 2, 1, 2, 1, 2, 1}
    "1=Z axis (vertical), 2=Y axis (horizontal)";

  // Waypoints — assumed values; requirement only declares final state exists
  parameter Real q_mid[7] = {0.30, 0.25, 0.20, 0.15, 0.10, 0.08, 0.05}
    "Midpoint configuration [rad]";
  parameter Real q_end[7] = {0.60, 0.50, 0.40, 0.30, 0.20, 0.16, 0.10}
    "Final configuration [rad]";

  // Controller gains
  parameter Real Kp[7] = {140, 120, 100, 90, 80, 70, 60} "Proportional";
  parameter Real Kd[7] = {10, 9, 8, 6, 5, 4, 3} "Derivative";
  parameter Real Ki[7] = {6, 5, 4, 3, 2.5, 2, 1.5} "Integral";
  parameter Real Kv[7] = fill(0.5, 7) "Velocity feedforward";

  // Bounds
  parameter Real q_bound = 3.14 "Position bound [rad]";
  parameter Real qd_bound = 12.0 "Velocity bound [rad/s]";
  parameter Real qdd_bound = 80.0 "Acceleration bound [rad/s^2]";

  // Continuous states
  Real q[7](each start = 0.0, each fixed = true) "Joint position [rad]";
  Real qd[7](each start = 0.0, each fixed = true) "Joint velocity [rad/s]";
  Real qdd[7] "Joint acceleration [rad/s^2]";

  // Desired trajectory (cubic interpolation)
  Real q_des[7] "Desired position [rad]";
  Real qd_des[7] "Desired velocity [rad/s]";
  Real qdd_des[7] "Desired acceleration [rad/s^2]";

  // Sensors (encoders)
  Real q_meas[7] "Encoder position [rad]";
  Real qd_meas[7] "Encoder velocity [rad/s]";

  // Effort
  Real tau[7] "Saturated actuator effort [N.m]";
  Real tau_cmd[7](each start = 0.0) "Commanded effort [N.m]";
  Real integ_err[7](each start = 0.0) "PID integral state";

  // Effective dynamics
  Real J_eff[7] "Effective inertia [kg.m^2]";
  Real tau_grav[7] "Gravity torque [N.m]";
  Real m_payload "Payload mass [kg]";
  Real dist_factor "Disturbance multiplier";
  Real m_eff[7] "Effective mass per link [kg]";

  // Error and monitoring signals
  Real err[7] "Tracking error [rad]";
  Real tracking_err_norm "Primary tracking error norm [rad]";
  Real settling_ok "1 if settled after 9.1 s, else 0";
  Real traj_phase "0=start, 1=mid-third, 2=end-third";
  Real max_abs_q "Max abs position [rad]";
  Real max_abs_qd "Max abs velocity [rad/s]";
  Real max_abs_qdd "Max abs acceleration [rad/s^2]";
  Real max_abs_tau "Max abs effort [N.m]";
  Real pos_violation "Position bound violation [rad]";
  Real vel_violation "Velocity bound violation [rad/s]";
  Real acc_violation "Acceleration bound violation [rad/s^2]";
  Real eff_violation "Effort bound violation [N.m]";

equation
  // Payload disturbance: +5% during middle third of 14 s run
  dist_factor = if (time >= t_end/3.0 and time <= 2.0*t_end/3.0) then 1.05 else 1.0;
  m_payload = m_payload_base * dist_factor;
  traj_phase = if time < t_end/3.0 then 0.0
    else if time <= 2.0*t_end/3.0 then 1.0 else 2.0;

  // Effective mass, inertia, gravity torque per joint
  // Z-axis joints: no gravity torque. Y-axis joints: gravity torque from lever arm.
  for i in 1:7 loop
    m_eff[i] = m_link[i]/2.0
      + (if i < 7 then sum(m_link[j] for j in (i+1):7) else 0.0)
      + m_payload;
    J_eff[i] = m_eff[i]*L[i]*L[i];
    tau_grav[i] = if axis[i] == 2 then g_acc*m_eff[i]*L[i]*cos(q[i]) else 0.0;
  end for;

  // Plant dynamics: independent lumped joints with viscous damping
  for i in 1:7 loop
    der(q[i]) = qd[i];
    der(qd[i]) = qdd[i];
    qdd[i] = (tau[i] - tau_grav[i] - 0.3*qd[i]) / J_eff[i];
    tau[i] = max(-tau_max, min(tau_max, tau_cmd[i]));
    q_meas[i] = q[i];
    qd_meas[i] = qd[i];
    err[i] = q_des[i] - q[i];
  end for;

  // Cubic Hermite interpolation with zero endpoint velocities, two segments
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

  // Tracking error norm with well-defined zero branch
  tracking_err_norm = sqrt(sum(err[i]*err[i] for i in 1:7) + 1e-12);

  // Terminal settling: primary tracking error below 0.03 rad after 9.1 s
  settling_ok = if time >= 9.1 then
    (if tracking_err_norm < 0.03 then 1.0 else 0.0) else 0.0;

  // Bounds observability via explicit array comprehensions
  max_abs_q = max({abs(q[i]) for i in 1:7});
  max_abs_qd = max({abs(qd[i]) for i in 1:7});
  max_abs_qdd = max({abs(qdd[i]) for i in 1:7});
  max_abs_tau = max({abs(tau[i]) for i in 1:7});

  pos_violation = max_abs_q - q_bound;
  vel_violation = max_abs_qd - qd_bound;
  acc_violation = max_abs_qdd - qdd_bound;
  eff_violation = max_abs_tau - tau_max;

  // Physical and control bounds assertions
  assert(max_abs_q <= q_bound + 1e-6, "Position bound violated");
  assert(max_abs_qd <= qd_bound + 1e-6, "Velocity bound violated");
  assert(max_abs_qdd <= qdd_bound + 1e-6, "Acceleration bound violated");
  assert(max_abs_tau <= tau_max + 1e-6, "Effort bound violated");

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