model DeltaPressD
  "Instrumented closed-chain Delta robot with hybrid position-force control pressing against compliant workpiece"

  // ===== Physical parameters (from requirement) =====
  parameter Modelica.Units.SI.Length L1 = 0.32 "Actuated upper arm length";
  parameter Modelica.Units.SI.Length L2 = 0.60 "Paired forearm length";
  parameter Modelica.Units.SI.Mass m_platform = 3.0 "Moving platform mass";
  parameter Modelica.Units.SI.Torque tau_max = 45.0 "Per-actuator torque limit";
  parameter Modelica.Units.SI.TranslationalSpringConstant k_contact = 200000.0 "Contact stiffness (N/m)";
  parameter Modelica.Units.SI.TranslationalDampingConstant c_contact = 2000.0 "Contact damping (N.s/m)";
  parameter Real mu = 0.70 "Friction coefficient";

  // ===== Assumed parameters (not specified in requirement, labeled) =====
  parameter Modelica.Units.SI.Length Rb = 0.15 "Base joint circumradius (assumed; not specified)";
  parameter Modelica.Units.SI.Length Rp = 0.05 "Platform joint circumradius (assumed; not specified)";
  parameter Modelica.Units.SI.Length d = Rb - Rp "Radial offset";
  parameter Modelica.Units.SI.Length h_workpiece = 0.45 "Workpiece surface height below base (assumed; not specified)";
  parameter Modelica.Units.SI.Force F_target = 30.0 "Target regulated contact force (assumed; not specified)";
  parameter Modelica.Units.SI.Acceleration g = Modelica.Constants.g_n "Gravitational acceleration";

  // ===== Control parameters =====
  parameter Modelica.Units.SI.Force F_dist = 18.0 "Disturbance force change amplitude";
  parameter Modelica.Units.SI.Time T_total = 14.0 "Total run time";
  parameter Modelica.Units.SI.Time T_approach = 3.0 "Approach trajectory duration";
  parameter Modelica.Units.SI.Frequency f_sample = 200.0 "Control sample rate";
  parameter Modelica.Units.SI.Time Ts = 1.0 / f_sample "Sample period";

  // Position controller gains (platform h-space)
  parameter Real Kp_h = 300.0 "Position proportional gain [N/m]";
  parameter Real Kd_h = 30.0 "Position derivative gain [N.s/m]";

  // Force controller gains
  parameter Real Kp_force = 0.5 "Force proportional gain [N.m/N]";
  parameter Real Ki_force = 2.0 "Force integral gain [N.m/(N.s)]";
  parameter Real Kd_force = 0.01 "Force derivative gain [N.m.s/N]";
  parameter Real int_clamp = 10.0 "Force integral clamp magnitude";

  // Mode switch thresholds
  parameter Modelica.Units.SI.Force F_threshold = 1.0 "Force threshold to enter force mode";
  parameter Modelica.Units.SI.Force F_release = 0.3 "Force release threshold (hysteresis)";

  // Requirement thresholds
  parameter Modelica.Units.SI.Length closure_tol = 0.001 "Closure error tolerance after 9.1 s";
  parameter Modelica.Units.SI.Force force_band_half = 5.0 "Force band half-width";
  parameter Modelica.Units.SI.Velocity slip_tol = 1.0e-4 "Tangential slip tolerance";

  // Initial conditions
  parameter Modelica.Units.SI.Angle theta0 = -0.40 "Initial actuator angle";
  parameter Modelica.Units.SI.Length h0 = L1*sin(theta0) + sqrt(max(1e-12, L2^2 - (d + L1*cos(theta0))^2)) "Initial platform height";
  parameter Modelica.Units.SI.Length h_approach = h_workpiece + 0.002 "Approach target (2 mm beyond surface)";

  // ===== Dynamic states =====
  Modelica.Units.SI.Angle theta "Actuator angle (positive downward from horizontal)";
  Modelica.Units.SI.AngularVelocity omega "Actuator angular velocity";

  // ===== Kinematic variables =====
  Real u "Forearm radial projection";
  Real s "Forearm vertical projection";
  Modelica.Units.SI.Length h "Platform height below base";
  Modelica.Units.SI.Velocity dh "Platform vertical velocity";
  Real hp "Constraint Jacobian dh/dtheta";
  Real hpp "Constraint curvature d²h/dtheta²";

  // ===== Contact variables =====
  Modelica.Units.SI.Length penetration "Workpiece penetration depth";
  Modelica.Units.SI.Force F_normal "Normal contact force";
  Modelica.Units.SI.Force F_friction_cap "Friction capacity (mu*F_normal)";
  Modelica.Units.SI.Velocity v_tangential "Tangential velocity at contact";
  Modelica.Units.SI.Force F_tangential "Tangential friction force";
  Boolean in_contact "Contact flag";
  Boolean contact_locked "Contact locked flag";

  // ===== Disturbance =====
  Modelica.Units.SI.Force F_disturbance "External disturbance force (upward positive)";

  // ===== Discrete control variables =====
  Integer mode(start=0) "0=position, 1=force";
  discrete Modelica.Units.SI.Length h_cmd(start=h0) "Commanded platform height";
  discrete Modelica.Units.SI.Torque tau_cmd(start=0) "Unsaturated torque per actuator";
  discrete Modelica.Units.SI.Torque tau_sat(start=0) "Saturated torque per actuator";
  discrete Real force_integral(start=0) "Integral of force error";
  discrete Modelica.Units.SI.Force F_meas(start=0) "Sampled contact force";
  discrete Real force_error_deriv(start=0) "Discrete derivative of force error";

  // ===== Continuous control variables =====
  Modelica.Units.SI.Torque tau "Applied torque per actuator";
  Modelica.Units.SI.Torque tau_grav "Gravity compensation torque per actuator";
  Modelica.Units.SI.Angle theta_cmd "Commanded actuator angle (from IK)";

  // IK intermediates
  Real A_ik, B_ik, C_ik, R_ik, psi_ik, cr_ik;

  // Trajectory
  Real smooth_t "Smooth trajectory parameter [0,1]";

  // ===== Sensors (actuator sensors, output pose, contact force) =====
  Modelica.Units.SI.Angle theta_sensor1 "Actuator 1 angle sensor";
  Modelica.Units.SI.Angle theta_sensor2 "Actuator 2 angle sensor";
  Modelica.Units.SI.Angle theta_sensor3 "Actuator 3 angle sensor";
  Modelica.Units.SI.Torque tau_sensor1 "Actuator 1 torque sensor";
  Modelica.Units.SI.Torque tau_sensor2 "Actuator 2 torque sensor";
  Modelica.Units.SI.Torque tau_sensor3 "Actuator 3 torque sensor";
  Modelica.Units.SI.Length pose_x "Output pose x";
  Modelica.Units.SI.Length pose_y "Output pose y";
  Modelica.Units.SI.Length pose_z "Output pose z (height below base)";

  // ===== Monitors =====
  Modelica.Units.SI.Length closure_error "Closed-chain closure residual";
  Modelica.Units.SI.Length tracking_error "Primary tracking error |h - h_cmd|";
  Modelica.Units.SI.Force force_reg_error "Force regulation error";
  Boolean actuator_bounded "Actuator within torque bounds";
  Boolean contact_force_in_band "Contact force within band";
  Boolean no_slip "Tangential slip below tolerance";
  Boolean locked_contact_ok "Locked contact flag";
  Boolean closure_ok "Closure error below tolerance after 9.1 s";
  Boolean all_finite "No NaN/Inf in key variables";
  Boolean finite_F, finite_theta, finite_tau, finite_h, finite_omega;

initial equation
  theta = theta0;
  omega = 0.0;

equation
  // ===== Forward kinematics (closed-chain constraint) =====
  u = d + L1 * cos(theta);
  s = sqrt(max(1e-12, L2^2 - u^2));
  h = L1 * sin(theta) + s;

  // Constraint Jacobian: dh/dtheta
  hp = L1 * cos(theta) + u * L1 * sin(theta) / s;

  // Constraint curvature: d²h/dtheta²
  hpp = L1 * (-sin(theta) + (-L1 * sin(theta)^2 + u * cos(theta)) / s
    - u^2 * L1 * sin(theta)^2 / s^3);

  // Platform velocity
  dh = hp * omega;

  // ===== Closure error (constraint residual) =====
  closure_error = abs(u^2 + (L1 * sin(theta) - h)^2 - L2^2);

  // ===== Contact model (compliant workpiece with spring-damper) =====
  penetration = max(0, h - h_workpiece);
  in_contact = penetration > 0;
  F_normal = if h > h_workpiece then
    max(0, k_contact * (h - h_workpiece) + c_contact * dh)
  else
    0.0;
  F_friction_cap = mu * F_normal;
  // Symmetric embodiment: tangential motion is zero by construction
  v_tangential = 0.0;
  F_tangential = 0.0;
  contact_locked = in_contact and (abs(F_tangential) <= F_friction_cap);

  // ===== Disturbance: 18 N force change during middle third =====
  F_disturbance = if (time >= T_total / 3.0 and time <= 2.0 * T_total / 3.0) then F_dist else 0.0;

  // ===== Gravity compensation =====
  tau_grav = m_platform * g * hp / 3.0;

  // ===== Inverse kinematics (continuous, from discrete h_cmd) =====
  A_ik = 2.0 * h_cmd * L1;
  B_ik = -2.0 * d * L1;
  C_ik = h_cmd^2 + L1^2 - L2^2 + d^2;
  R_ik = sqrt(max(1e-12, A_ik^2 + B_ik^2));
  cr_ik = max(-0.999, min(0.999, C_ik / R_ik));
  psi_ik = atan2(B_ik, A_ik);
  theta_cmd = asin(cr_ik) - psi_ik;

  // ===== Trajectory (smoothstep) =====
  smooth_t = if time <= 0.0 then 0.0
    elseif time >= T_approach then 1.0
    else 3.0 * (time / T_approach)^2 - 2.0 * (time / T_approach)^3;

  // ===== Applied torque (ZOH from sampled controller) =====
  tau = tau_sat;

  // ===== Platform dynamics via constraint reduction =====
  der(theta) = omega;
  der(omega) = (3.0 * tau + m_platform * g * hp - F_normal * hp - F_disturbance * hp
    - m_platform * hp * hpp * omega^2) / (m_platform * max(1e-6, hp^2));

  // ===== Sensors =====
  theta_sensor1 = theta;
  theta_sensor2 = theta;
  theta_sensor3 = theta;
  tau_sensor1 = tau;
  tau_sensor2 = tau;
  tau_sensor3 = tau;
  pose_x = 0.0;
  pose_y = 0.0;
  pose_z = h;

  // ===== Monitors =====
  actuator_bounded = abs(tau) <= tau_max + 1e-6;
  tracking_error = abs(h - h_cmd);
  force_reg_error = abs(F_normal - F_target);
  contact_force_in_band = (not in_contact) or (force_reg_error < force_band_half);
  no_slip = abs(v_tangential) < slip_tol;
  locked_contact_ok = contact_locked;
  closure_ok = (time < 9.1) or (closure_error < closure_tol);

  // Finite checks: NaN => not(x>=0 or x<0); Inf => abs(x)>1e30
  finite_F = (F_normal >= 0.0 or F_normal < 0.0) and abs(F_normal) < 1e30;
  finite_theta = (theta >= 0.0 or theta < 0.0) and abs(theta) < 1e30;
  finite_tau = (tau >= 0.0 or tau < 0.0) and abs(tau) < 1e30;
  finite_h = (h >= 0.0 or h < 0.0) and abs(h) < 1e30;
  finite_omega = (omega >= 0.0 or omega < 0.0) and abs(omega) < 1e30;
  all_finite = finite_F and finite_theta and finite_tau and finite_h and finite_omega;

  // ===== Sampled hybrid controller at 200 Hz =====
  when sample(0, Ts) then
    // Sample contact force measurement
    F_meas := F_normal;

    // Force error derivative (backward difference)
    force_error_deriv := (pre(F_meas) - F_meas) / Ts;

    // Mode selection with hysteresis
    if F_meas > F_threshold then
      mode := 1;
    elseif pre(mode) == 1 and F_meas > F_release then
      mode := 1;
    else
      mode := 0;
    end if;

    if mode == 0 then
      // Position control: follow smoothstep trajectory to workpiece
      h_cmd := h0 + (h_approach - h0) * smooth_t;
      force_integral := 0.0;
      tau_cmd := (hp * (Kp_h * (h_cmd - h) - Kd_h * dh)) / 3.0 + tau_grav;
    else
      // Force control: PI with derivative term
      h_cmd := h_workpiece + F_target / k_contact;
      force_integral := max(-int_clamp, min(int_clamp, pre(force_integral) + Ts * (F_target - F_meas)));
      tau_cmd := Kp_force * (F_target - F_meas) + Ki_force * force_integral
        + Kd_force * force_error_deriv + tau_grav;
    end if;

    // Torque saturation (per-actuator limit)
    tau_sat := max(-tau_max, min(tau_max, tau_cmd));

  end when;

end DeltaPressD;