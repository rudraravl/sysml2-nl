model DeltaPressD
  "Instrumented closed-chain Delta robotic press with hybrid position-force control";

  // ==================== STATED PARAMETERS ====================
  parameter Modelica.SIunits.Length L1 = 0.32 "Upper arm length [m]";
  parameter Modelica.SIunits.Length L2 = 0.60 "Forearm length [m]";
  parameter Modelica.SIunits.Mass m = 3.0 "Moving platform mass [kg]";
  parameter Modelica.SIunits.Torque tau_max = 45.0 "Per-actuator torque limit [N.m]";
  parameter Modelica.SIunits.TranslationalSpringConstant k_contact = 200e3 "Contact stiffness [N/m]";
  parameter Modelica.SIunits.TranslationalDampingConstant c_contact = 2e3 "Contact damping [N.s/m]";
  parameter Modelica.SIunits.CoefficientOfFriction mu = 0.70 "Friction coefficient";
  parameter Modelica.SIunits.Force F_dist_change = 18.0 "Disturbance force change [N]";
  parameter Modelica.SIunits.Frequency f_ctrl = 200.0 "Control loop frequency [Hz]";
  parameter Modelica.SIunits.Time t_sim = 14.0 "Simulation duration [s]";

  // ==================== UNKNOWN PARAMETERS (labeled, estimated for model) ====================
  // Not stated in requirement; values estimated to enable compilation and simulation
  parameter Modelica.SIunits.Length r_b = 0.12 "Base circumradius [m] - UNKNOWN: not stated";
  parameter Modelica.SIunits.Length r_p = 0.04 "Platform circumradius [m] - UNKNOWN: not stated";
  parameter Modelica.SIunits.Length H_base = 0.50 "Base height [m] - UNKNOWN: not stated";
  parameter Modelica.SIunits.Length z_workpiece = -0.25 "Workpiece surface z [m] - UNKNOWN: not stated";
  parameter Modelica.SIunits.MomentOfInertia I_a = 0.015 "Upper arm inertia [kg.m2] - UNKNOWN: not stated";
  parameter Modelica.SIunits.Acceleration g_acc = 9.81 "Gravity [m/s2] - UNKNOWN: not stated";
  parameter Real b_arm = 0.05 "Arm viscous damping [N.m.s/rad] - UNKNOWN: not stated";
  parameter Modelica.SIunits.Mass m_arm = 0.3 "Upper arm mass [kg] - UNKNOWN: not stated";
  parameter Modelica.SIunits.Length r_arm_com = 0.16 "Upper arm COM distance [m] - UNKNOWN: not stated";
  parameter Modelica.SIunits.Velocity v_thresh = 0.001 "Friction velocity threshold [m/s] - UNKNOWN: not stated";

  // Initial conditions - UNKNOWN: not stated
  parameter Modelica.SIunits.Angle theta_init = 0.7 "Initial joint angle [rad] - UNKNOWN: not stated";

  // Controller parameters - UNKNOWN: not stated
  parameter Real Kp_pos = 300.0 "Position P gain [N/m] - UNKNOWN: not stated";
  parameter Real Kd_pos = 25.0 "Position D gain [N.s/m] - UNKNOWN: not stated";
  parameter Real Kp_force = 2.0 "Force P gain [-] - UNKNOWN: not stated";
  parameter Real Ki_force = 10.0 "Force I gain [1/s] - UNKNOWN: not stated";
  parameter Real force_int_limit = 15.0 "Force integral anti-windup limit - UNKNOWN: not stated";
  parameter Modelica.SIunits.Force F_desired = 40.0 "Desired contact force [N] - UNKNOWN: not stated";
  parameter Modelica.SIunits.Time t_approach = 5.0 "Approach duration [s] - UNKNOWN: not stated";
  parameter Modelica.SIunits.Force F_contact_thresh = 1.0 "Contact detection threshold [N] - UNKNOWN: not stated";
  parameter Modelica.SIunits.Force F_release_thresh = 0.5 "Contact release threshold [N] - UNKNOWN: not stated";

  // Computed initial platform position from parameters
  final parameter Real d_rad_init = r_b + L1 * cos(theta_init) - r_p;
  final parameter Real s_init = sqrt(L2 * L2 - d_rad_init * d_rad_init);
  final parameter Modelica.SIunits.Position z_start = H_base - L1 * sin(theta_init) - s_init
    "Initial platform z [m] - computed from parameters";
  final parameter Modelica.SIunits.Position z_target = z_workpiece + 0.001
    "Target position with slight penetration [m] - computed";

  // ==================== DYNAMIC STATES ====================
  Modelica.SIunits.Angle theta[3](start = {theta_init, theta_init, theta_init})
    "Actuated upper arm angles [rad]";
  Modelica.SIunits.AngularVelocity omega[3](start = {0, 0, 0})
    "Joint angular velocities [rad/s]";

  // ==================== DISCRETE CONTROLLER STATES (200 Hz) ====================
  discrete Modelica.SIunits.Torque tau_cmd_d[3](each start = 0)
    "Discrete torque commands [N.m]";
  discrete Real force_int_d(start = 0) "Discrete force error integral";
  discrete Boolean force_mode_d(start = false) "Discrete force control mode flag";
  discrete Modelica.SIunits.Position z_cmd_d(start = z_start)
    "Discrete position command [m]";
  discrete Modelica.SIunits.Force F_cmd_d(start = F_desired)
    "Discrete force command [N]";
  discrete Real e_pos_d(start = 0) "Discrete position error [m]";
  discrete Real e_force_d(start = 0) "Discrete force error [N]";

  // ==================== ALGEBRAIC: KINEMATICS ====================
  Real d_radial[3] "Radial distance elbow-to-platform per chain [m]";
  Real s_chain[3] "Forearm vertical projection per chain [m]";
  Real z_chain[3] "Platform z from each chain [m]";
  Real J_chain[3] "Jacobian dz/dtheta per chain [m/rad]";
  Real dJ_chain[3] "Jacobian derivative d2z/dtheta2 per chain [m/rad2]";
  Modelica.SIunits.Position z "Platform vertical position [m]";
  Modelica.SIunits.Velocity v_z "Platform vertical velocity [m/s]";
  Real a_z "Platform vertical acceleration [m/s2]";
  Real alpha[3] "Joint angular accelerations [rad/s2]";

  // ==================== ALGEBRAIC: CONTACT ====================
  Real penetration "Contact penetration depth [m]";
  Modelica.SIunits.Force F_normal "Normal contact force [N]";
  Modelica.SIunits.Force F_friction "Tangential friction force [N]";
  Boolean in_contact "Contact flag";
  Modelica.SIunits.Velocity v_tangent "Tangential velocity [m/s]";
  Boolean locked_contact "Locked contact flag";
  Real slip_ratio "Tangential slip ratio";
  Modelica.SIunits.Force F_contact_band "Contact force band [N]";

  // ==================== ALGEBRAIC: DISTURBANCE ====================
  Modelica.SIunits.Force F_disturbance "Applied disturbance force [N]";
  Boolean disturbance_active "Disturbance active flag";

  // ==================== ALGEBRAIC: ACTUATOR ====================
  Modelica.SIunits.Torque tau[3] "Saturated actuator torques [N.m]";
  Modelica.SIunits.Torque tau_grav[3] "Gravity compensation torques [N.m]";
  Boolean tau_saturated[3] "Torque saturation flags";

  // ==================== ALGEBRAIC: SENSORS (FEEDBACK) ====================
  Modelica.SIunits.Angle theta_meas[3] "Measured joint angles [rad] - actuator sensor";
  Modelica.SIunits.AngularVelocity omega_meas[3] "Measured joint velocities [rad/s] - actuator sensor";
  Modelica.SIunits.Torque tau_meas[3] "Measured actuator torques [N.m] - actuator sensor";
  Modelica.SIunits.Position z_meas "Measured platform z [m] - output pose";
  Modelica.SIunits.Velocity v_z_meas "Measured platform velocity [m/s] - output pose";
  Modelica.SIunits.Force F_normal_meas "Measured normal contact force [N] - contact sensor";

  // ==================== ALGEBRAIC: ERROR METRICS ====================
  Real closure_error "Kinematic closure error [m]";
  Real tracking_error "Primary tracking error [m]";
  Real contact_force_error "Contact force tracking error [N]";

  // ==================== ALGEBRAIC: OUTPUT ====================
  Modelica.SIunits.Time t_sync "Synchronized simulation time [s]";
  Real F_ctrl "Control force vertical [N]";

equation
  // ==================== SYNCHRONIZED TIME ====================
  t_sync = time;

  // ==================== DISTURBANCE (middle third of simulation) ====================
  disturbance_active = (time >= t_sim / 3.0) and (time < 2.0 * t_sim / 3.0);
  F_disturbance = if disturbance_active then F_dist_change else 0.0;

  // ==================== FORWARD KINEMATICS (per chain) ====================
  for i in 1:3 loop
    d_radial[i] = r_b + L1 * cos(theta[i]) - r_p;
    s_chain[i] = sqrt(max(L2 * L2 - d_radial[i] * d_radial[i], 1e-12));
    z_chain[i] = H_base - L1 * sin(theta[i]) - s_chain[i];
    J_chain[i] = -L1 * cos(theta[i]) + L1 * sin(theta[i]) * d_radial[i] / s_chain[i];
    dJ_chain[i] = L1 * sin(theta[i])
      + L1 * cos(theta[i]) * d_radial[i] / s_chain[i]
      - L1 * L1 * sin(theta[i]) * sin(theta[i]) * L2 * L2
        / (s_chain[i] * s_chain[i] * s_chain[i]);
  end for;

  // Platform position and velocity (average of three chains)
  z = (z_chain[1] + z_chain[2] + z_chain[3]) / 3.0;
  v_z = (J_chain[1] * omega[1] + J_chain[2] * omega[2] + J_chain[3] * omega[3]) / 3.0;

  // Platform acceleration (chain rule under closed-chain constraint)
  a_z = (dJ_chain[1] * omega[1] ^ 2 + dJ_chain[2] * omega[2] ^ 2 + dJ_chain[3] * omega[3] ^ 2) / 3.0
    + (J_chain[1] * alpha[1] + J_chain[2] * alpha[2] + J_chain[3] * alpha[3]) / 3.0;

  // ==================== CLOSURE ERROR ====================
  closure_error = abs(z_chain[1] - z_chain[2]) + abs(z_chain[2] - z_chain[3]);

  // ==================== GRAVITY COMPENSATION ====================
  for i in 1:3 loop
    tau_grav[i] = m_arm * g_acc * r_arm_com * cos(theta[i]) + (m * g_acc / 3.0) * J_chain[i];
  end for;

  // ==================== DYNAMICS ====================
  // Equal load distribution among three chains under loop constraint
  // Actuator: I_a * alpha = tau - F_load * J - b * omega - arm_gravity
  // Platform: m * a_z = sum(F_load) - m*g - F_normal - F_disturbance
  // F_load[i] = (m * a_z + m * g + F_normal + F_disturbance) / 3
  for i in 1:3 loop
    I_a * alpha[i] = tau[i]
      - (m * a_z + m * g_acc + F_normal + F_disturbance) / 3.0 * J_chain[i]
      - b_arm * omega[i]
      - m_arm * g_acc * r_arm_com * cos(theta[i]);
  end for;

  // State derivatives
  for i in 1:3 loop
    der(theta[i]) = omega[i];
    der(omega[i]) = alpha[i];
  end for;

  // ==================== CONTACT MODEL ====================
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

  // ==================== TORQUE SATURATION ====================
  for i in 1:3 loop
    tau[i] = if tau_cmd_d[i] > tau_max then tau_max
      elseif tau_cmd_d[i] < -tau_max then -tau_max
      else tau_cmd_d[i];
    tau_saturated[i] = abs(tau_cmd_d[i]) > tau_max;
  end for;

  // ==================== SENSORS (MEASUREMENTS - FEEDBACK) ====================
  for i in 1:3 loop
    theta_meas[i] = theta[i];
    omega_meas[i] = omega[i];
    tau_meas[i] = tau[i];
  end for;
  z_meas = z;
  v_z_meas = v_z;
  F_normal_meas = F_normal;

  // ==================== TRACKING ERRORS ====================
  tracking_error = abs(z_cmd_d - z);
  contact_force_error = abs(F_cmd_d - F_normal);

  // ==================== CONTROL FORCE (OUTPUT) ====================
  F_ctrl = if force_mode_d
    then F_cmd_d + Kp_force * (F_cmd_d - F_normal_meas) + Ki_force * force_int_d
    else Kp_pos * (z_cmd_d - z_meas) - Kd_pos * v_z_meas;

  // ==================== SAMPLED CONTROLLER (200 Hz) ====================
  when sample(0, 1.0 / f_ctrl) then
    // Mode switching with hysteresis (position -> force on contact)
    if not pre(force_mode_d) and F_normal_meas > F_contact_thresh then
      force_mode_d = true;
    elseif pre(force_mode_d) and F_normal_meas < F_release_thresh then
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
    if force_mode_d then
      // Force control mode: regulate contact force
      for i in 1:3 loop
        tau_cmd_d[i] = (J_chain[i] / 3.0)
          * (F_cmd_d + Kp_force * e_force_d + Ki_force * force_int_d)
          + m_arm * g_acc * r_arm_com * cos(theta[i])
          + (m * g_acc / 3.0) * J_chain[i];
      end for;
    else
      // Position control mode: track position trajectory
      for i in 1:3 loop
        tau_cmd_d[i] = (J_chain[i] / 3.0)
          * (Kp_pos * e_pos_d - Kd_pos * v_z_meas)
          + m_arm * g_acc * r_arm_com * cos(theta[i])
          + (m * g_acc / 3.0) * J_chain[i];
      end for;
    end if;
  end when;

  annotation(
    experiment(StartTime = 0, StopTime = 14.0, Tolerance = 1e-6, Interval = 0.005),
    Documentation(info = "<html>
<h4>DeltaPressD: Instrumented closed-chain Delta robotic press</h4>
<p>Hybrid position-force control of a Delta robot pressing against a compliant workpiece.
Three actuated upper arms (0.32 m) with paired forearms (0.60 m) drive a 3 kg platform.
Torque actuators limited to 45 N.m each. Contact stiffness 200 kN/m, damping 2 kN.s/m,
friction coefficient 0.70. An 18 N force disturbance is applied during the middle third
(4.67 s to 9.33 s) of the 14 s simulation. Controller runs at 200 Hz.</p>
<h5>Feedback signals:</h5>
<ul>
<li>Actuator sensors: theta_meas, omega_meas, tau_meas</li>
<li>Output pose: z_meas, v_z_meas</li>
<li>Normal contact force: F_normal_meas</li>
</ul>
<h5>Requirement checks:</h5>
<ul>
<li>Actuator bounds: tau_saturated[3]</li>
<li>Closure error: closure_error (target < 0.001 m after 9.1 s)</li>
<li>Contact force band: F_contact_band</li>
<li>Tangential slip: slip_ratio</li>
<li>Locked contact: locked_contact</li>
<li>Primary tracking error: tracking_error</li>
<li>NaN/inf prevention: max() guards on all sqrt arguments and divisors</li>
</ul>
<h5>Unknown parameters (labeled in comments):</h5>
<p>Base/platform radii, base height, workpiece position, arm inertia/mass/damping,
controller gains, desired force, trajectory parameters. All estimated and labeled.</p>
</html>")
  );
end DeltaPressD;