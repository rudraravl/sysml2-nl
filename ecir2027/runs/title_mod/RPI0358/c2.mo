model DeltaPressD "Instrumented closed-chain Delta robotic press with hybrid position-force control"

  // ===================== STATED PARAMETERS =====================
  parameter Real L1(unit="m") = 0.32 "Upper arm length [m]";
  parameter Real L2(unit="m") = 0.60 "Forearm length [m]";
  parameter Real m(unit="kg") = 3.0 "Moving platform mass [kg]";
  parameter Real tau_max(unit="N.m") = 45.0 "Per-actuator torque limit [N.m]";
  parameter Real k_contact(unit="N/m") = 200e3 "Contact stiffness [N/m]";
  parameter Real c_contact(unit="N.s/m") = 2e3 "Contact damping [N.s/m]";
  parameter Real mu = 0.70 "Friction coefficient [-]";
  parameter Real F_dist_change(unit="N") = 18.0 "Disturbance force change [N]";
  parameter Real f_ctrl(unit="Hz") = 200.0 "Control loop frequency [Hz]";
  parameter Real t_sim(unit="s") = 14.0 "Simulation duration [s]";

  // ===================== UNKNOWN PARAMETERS (estimated, labeled) =====================
  parameter Real r_b(unit="m") = 0.12 "Base circumradius [m] - UNKNOWN: not stated";
  parameter Real r_p(unit="m") = 0.04 "Platform circumradius [m] - UNKNOWN: not stated";
  parameter Real H_base(unit="m") = 0.50 "Base height [m] - UNKNOWN: not stated";
  parameter Real z_workpiece(unit="m") = -0.25 "Workpiece surface z [m] - UNKNOWN: not stated";
  parameter Real I_a(unit="kg.m2") = 0.015 "Upper arm inertia [kg.m2] - UNKNOWN: not stated";
  parameter Real g_acc(unit="m/s2") = 9.81 "Gravity [m/s2] - UNKNOWN: not stated";
  parameter Real b_arm(unit="N.m.s/rad") = 0.05 "Arm viscous damping [N.m.s/rad] - UNKNOWN: not stated";
  parameter Real m_arm(unit="kg") = 0.3 "Upper arm mass [kg] - UNKNOWN: not stated";
  parameter Real r_arm_com(unit="m") = 0.16 "Upper arm COM distance [m] - UNKNOWN: not stated";
  parameter Real v_thresh(unit="m/s") = 0.001 "Friction velocity threshold [m/s] - UNKNOWN: not stated";
  parameter Real theta_init(unit="rad") = 0.7 "Initial joint angle [rad] - UNKNOWN: not stated";

  // Controller parameters - UNKNOWN: not stated
  parameter Real Kp_pos = 300.0 "Position P gain [1/s2] - UNKNOWN";
  parameter Real Kd_pos = 25.0 "Position D gain [1/s] - UNKNOWN";
  parameter Real Kp_force = 2.0 "Force P gain [-] - UNKNOWN";
  parameter Real Ki_force = 10.0 "Force I gain [1/s] - UNKNOWN";
  parameter Real force_int_limit = 15.0 "Force integral anti-windup limit - UNKNOWN";
  parameter Real F_desired(unit="N") = 40.0 "Desired contact force [N] - UNKNOWN";
  parameter Real t_approach(unit="s") = 5.0 "Approach duration [s] - UNKNOWN";
  parameter Real F_contact_thresh(unit="N") = 1.0 "Contact detection threshold [N] - UNKNOWN";
  parameter Real F_release_thresh(unit="N") = 0.5 "Contact release threshold [N] - UNKNOWN";

  // Computed constants
  final parameter Real d_rad_init = r_b + L1 * cos(theta_init) - r_p;
  final parameter Real s_init = sqrt(max(L2 * L2 - d_rad_init * d_rad_init, 1e-12));
  final parameter Real z_start(unit="m") = H_base - L1 * sin(theta_init) - s_init
    "Initial platform z [m] - computed";
  final parameter Real z_target(unit="m") = z_workpiece - F_desired / k_contact
    "Target z for desired contact force [m] - computed";

  // ===================== DYNAMIC STATES =====================
  Real theta[3](each unit="rad", each start=theta_init) "Actuated upper arm angles [rad]";
  Real omega[3](each unit="rad/s", each start=0) "Joint angular velocities [rad/s]";

  // ===================== DISCRETE CONTROLLER STATES (200 Hz) =====================
  discrete Real tau_cmd_d[3](each unit="N.m", each start=0) "Discrete torque commands [N.m]";
  discrete Real force_int_d(start=0) "Discrete force error integral";
  discrete Boolean force_mode_d(start=false) "Force control mode flag";
  discrete Real z_cmd_d(unit="m", start=0) "Discrete position command [m]";
  discrete Real F_cmd_d(unit="N", start=40) "Discrete force command [N]";
  discrete Real e_pos_d(unit="m", start=0) "Discrete position error [m]";
  discrete Real e_force_d(unit="N", start=0) "Discrete force error [N]";

  // ===================== ALGEBRAIC: KINEMATICS =====================
  Real d_radial[3] "Radial distance elbow-to-platform per chain [m]";
  Real s_chain[3] "Forearm vertical projection per chain [m]";
  Real z_chain[3] "Platform z from each chain [m]";
  Real J_chain[3] "Jacobian dz/dtheta per chain [m/rad]";
  Real dJ_chain[3] "Jacobian derivative per chain [m/rad2]";
  Real z(unit="m") "Platform vertical position [m]";
  Real v_z(unit="m/s") "Platform vertical velocity [m/s]";
  Real a_z(unit="m/s2") "Platform vertical acceleration [m/s2]";
  Real alpha[3](each unit="rad/s2") "Joint angular accelerations [rad/s2]";

  // ===================== ALGEBRAIC: CONTACT =====================
  Real penetration(unit="m") "Contact penetration depth [m]";
  Real F_normal(unit="N") "Normal contact force [N]";
  Real F_friction(unit="N") "Tangential friction force [N]";
  Boolean in_contact "Contact flag";
  Real v_tangent(unit="m/s") "Tangential velocity [m/s]";
  Boolean locked_contact "Locked contact flag";
  Real slip_ratio "Tangential slip ratio";
  Real F_contact_band(unit="N") "Contact force band [N]";

  // ===================== ALGEBRAIC: DISTURBANCE =====================
  Real F_disturbance(unit="N") "Applied disturbance force [N]";
  Boolean disturbance_active "Disturbance active flag";

  // ===================== ALGEBRAIC: ACTUATOR =====================
  Real tau[3](each unit="N.m") "Saturated actuator torques [N.m]";
  Boolean tau_saturated[3] "Torque saturation flags";

  // ===================== SENSORS (FEEDBACK) =====================
  Real theta_meas[3](each unit="rad") "Measured joint angles [rad] - actuator sensor";
  Real omega_meas[3](each unit="rad/s") "Measured joint velocities [rad/s] - actuator sensor";
  Real tau_meas[3](each unit="N.m") "Measured actuator torques [N.m] - actuator sensor";
  Real z_meas(unit="m") "Measured platform z [m] - output pose";
  Real v_z_meas(unit="m/s") "Measured platform velocity [m/s] - output pose";
  Real F_normal_meas(unit="N") "Measured normal contact force [N] - contact sensor";

  // ===================== ERROR METRICS =====================
  Real closure_error "Kinematic closure error [m]";
  Real tracking_error "Primary tracking error [m]";
  Real contact_force_error "Contact force tracking error [N]";

equation

  // ===================== DISTURBANCE (middle third of simulation) =====================
  disturbance_active = (time >= t_sim / 3.0) and (time < 2.0 * t_sim / 3.0);
  F_disturbance = if disturbance_active then F_dist_change else 0.0;

  // ===================== FORWARD KINEMATICS (per chain) =====================
  for i in 1:3 loop
    d_radial[i] = r_b + L1 * cos(theta[i]) - r_p;
    s_chain[i] = sqrt(max(L2 * L2 - d_radial[i] * d_radial[i], 1e-12));
    z_chain[i] = H_base - L1 * sin(theta[i]) - s_chain[i];
    J_chain[i] = -L1 * cos(theta[i]) - L1 * sin(theta[i]) * d_radial[i] / s_chain[i];
    dJ_chain[i] = L1 * sin(theta[i])
      - L1 * cos(theta[i]) * d_radial[i] / s_chain[i]
      + L1 * L1 * sin(theta[i]) * sin(theta[i]) * L2 * L2
        / (s_chain[i] * s_chain[i] * s_chain[i]);
  end for;

  // Platform position, velocity, acceleration (average of three chains)
  z = (z_chain[1] + z_chain[2] + z_chain[3]) / 3.0;
  v_z = (J_chain[1] * omega[1] + J_chain[2] * omega[2] + J_chain[3] * omega[3]) / 3.0;
  a_z = (dJ_chain[1] * omega[1] * omega[1] + dJ_chain[2] * omega[2] * omega[2] + dJ_chain[3] * omega[3] * omega[3]) / 3.0
    + (J_chain[1] * alpha[1] + J_chain[2] * alpha[2] + J_chain[3] * alpha[3]) / 3.0;

  // ===================== CLOSURE ERROR =====================
  closure_error = abs(z_chain[1] - z_chain[2]) + abs(z_chain[2] - z_chain[3]);

  // ===================== CONTACT MODEL =====================
  penetration = max(z_workpiece - z, 0.0);
  in_contact = z < z_workpiece;

  // Normal contact force (spring-damper, non-negative, zero-error branch guarded)
  F_normal = if z < z_workpiece
    then max(k_contact * (z_workpiece - z) - c_contact * v_z, 0.0)
    else 0.0;

  // Tangential motion (pure vertical press: no lateral dynamics modeled)
  v_tangent = 0.0;

  // Friction force (Coulomb model with smooth approximation, divisor guarded)
  F_friction = mu * F_normal * tanh(v_tangent / max(v_thresh, 1e-9));

  // Slip indicators (divisor guarded against zero)
  slip_ratio = abs(v_tangent) / max(abs(v_tangent) + v_thresh, 1e-9);
  locked_contact = in_contact and (abs(v_tangent) < v_thresh);

  // Contact force band (deviation from commanded force)
  F_contact_band = abs(F_normal - F_cmd_d);

  // ===================== DYNAMICS (per-chain with reflected platform inertia) =====================
  for i in 1:3 loop
    (I_a + (m / 3.0) * J_chain[i] * J_chain[i]) * alpha[i] = tau[i] - b_arm * omega[i]
      + m_arm * g_acc * r_arm_com * cos(theta[i])
      - (m / 3.0) * g_acc * J_chain[i]
      + (F_normal - F_disturbance) / 3.0 * J_chain[i];
  end for;

  // State derivatives
  for i in 1:3 loop
    der(theta[i]) = omega[i];
    der(omega[i]) = alpha[i];
  end for;

  // ===================== TORQUE SATURATION =====================
  for i in 1:3 loop
    tau[i] = if tau_cmd_d[i] > tau_max then tau_max
      elseif tau_cmd_d[i] < -tau_max then -tau_max
      else tau_cmd_d[i];
    tau_saturated[i] = abs(tau_cmd_d[i]) > tau_max;
  end for;

  // ===================== SENSORS (MEASUREMENTS - FEEDBACK) =====================
  for i in 1:3 loop
    theta_meas[i] = theta[i];
    omega_meas[i] = omega[i];
    tau_meas[i] = tau[i];
  end for;
  z_meas = z;
  v_z_meas = v_z;
  F_normal_meas = F_normal;

  // ===================== TRACKING ERRORS =====================
  tracking_error = abs(z_cmd_d - z);
  contact_force_error = abs(F_cmd_d - F_normal);

  // ===================== SAMPLED CONTROLLER (200 Hz) =====================
  when sample(0, 1.0 / f_ctrl) then

    // Mode switching with hysteresis (position -> force on contact)
    if not pre(force_mode_d) and (F_normal_meas > F_contact_thresh) then
      force_mode_d = true;
    elseif pre(force_mode_d) and (F_normal_meas < F_release_thresh) then
      force_mode_d = false;
    else
      force_mode_d = pre(force_mode_d);
    end if;

    // Position command trajectory (smooth ramp to workpiece)
    z_cmd_d = z_start + (z_target - z_start) * min(time / t_approach, 1.0);

    // Force command (constant; disturbance is external on platform)
    F_cmd_d = F_desired;

    // Errors
    e_pos_d = z_cmd_d - z_meas;
    e_force_d = F_cmd_d - F_normal_meas;

    // Force integral with anti-windup
    force_int_d = max(min(pre(force_int_d) + e_force_d / f_ctrl, force_int_limit), -force_int_limit);

    // Torque computation (hybrid position-force control through Jacobian)
    for i in 1:3 loop
      if force_mode_d then
        // Force control mode: regulate contact force
        tau_cmd_d[i] = (m / 3.0) * g_acc * J_chain[i]
          - m_arm * g_acc * r_arm_com * cos(theta[i])
          - (F_cmd_d + Kp_force * e_force_d + Ki_force * force_int_d) / 3.0 * J_chain[i];
      else
        // Position control mode: track position trajectory
        tau_cmd_d[i] = (m / 3.0) * g_acc * J_chain[i]
          - m_arm * g_acc * r_arm_com * cos(theta[i])
          + (Kp_pos * e_pos_d - Kd_pos * v_z_meas) / 3.0 * J_chain[i];
      end if;
    end for;

  end when;

  annotation(
    experiment(StartTime = 0, StopTime = 14.0, Tolerance = 1e-6, Interval = 0.005),
    Documentation(info = "DeltaPressD: Instrumented closed-chain Delta robotic press with hybrid position-force control. Three actuated 0.32 m upper arms and 0.60 m forearms drive a 3 kg platform. Torque limit 45 N.m. Contact stiffness 200 kN/m, damping 2 kN.s/m, friction 0.70. Disturbance 18 N during middle third. Controller at 200 Hz for 14 s. Unknown parameters estimated and labeled.")
  );

end DeltaPressD;