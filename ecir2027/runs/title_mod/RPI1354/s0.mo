model SoftGripGraspD
  "Instrumented soft robotic grip: three 0.13 m silicone fingers with four bending sections each,
   pressure control (95 kPa-gauge max) with contact-force redistribution, compliant contact
   (mu=0.70) on rigid support, 4 N tangential disturbance during middle third, 200 Hz, 14 s"

  // ==================== Finger geometry ====================
  parameter Modelica.Units.SI.Length L_finger = 0.13 "Finger length";
  parameter Modelica.Units.SI.Length R_palm = 0.02 "Palm radius";
  parameter Modelica.Units.SI.Length R_obj = 0.04 "Object radius";
  parameter Integer n_sections = 4 "Bending sections per finger";
  parameter Modelica.Units.SI.Length l_seg = L_finger / n_sections "Section length";

  // ==================== Object ====================
  parameter Modelica.Units.SI.Mass m_obj = 0.10 "Object mass";

  // ==================== Actuator limits ====================
  parameter Modelica.Units.SI.Pressure p_max = 95000.0 "Max gauge pressure";
  parameter Modelica.Units.SI.Pressure p_nominal = 14700.0 "Nominal grasping pressure";
  parameter Modelica.Units.SI.Time t_ramp = 2.0 "Pressure ramp duration";

  // ==================== Finger dynamics ====================
  parameter Real I_finger = 5.0e-6 "Bending inertia [kg.m2]";
  parameter Real b_finger = 5.0e-4 "Bending damping [N.m.s/rad]";
  parameter Real k_spring = 0.01 "Restoring stiffness [N.m/rad]";
  parameter Real k_bend = 1.5e-6 "Bending gain (chamber area * moment arm) [N.m/Pa]";
  parameter Real theta_max = 3.0 "Deformation bound [rad]";
  parameter Real theta_soft = 0.85 * theta_max "Soft limit onset [rad]";
  parameter Real k_limit = 1.0 "Limit stiffness [N.m/rad]";

  // ==================== Contact model ====================
  parameter Real k_contact = 500.0 "Contact stiffness [N/m]";
  parameter Real b_contact = 5.0 "Contact damping [N.s/m]";
  parameter Real mu = 0.70 "Friction coefficient on rigid support surface";
  parameter Real v_thresh = 0.01 "Friction velocity smoothing threshold [m/s]";

  // ==================== Force control ====================
  parameter Real F_set = 3.0 "Target total normal grasp force [N]";
  parameter Real N_max = 2.5 "Per-contact force limit [N]";
  parameter Real N_min = 0.10 "Minimum per-contact force for no contact loss [N]";
  parameter Real Kp_force = 50.0 "Force proportional gain [Pa/N]";
  parameter Real Ki_force = 1500.0 "Force integral gain [Pa/(N.s)]";
  parameter Real K_redist = 2000.0 "Contact-force redistribution gain [Pa/N]";
  parameter Real K_boost = 5000.0 "Contact-loss prevention boost [Pa/N]";
  parameter Real F_contact_thresh = 0.3 "Contact detection threshold for anti-windup [N]";

  // ==================== Disturbance ====================
  parameter Modelica.Units.SI.Force F_dist = 4.0 "Tangential disturbance load";
  parameter Modelica.Units.SI.Time t_dist_start = 14.0 / 3.0 "Disturbance start (middle third)";
  parameter Modelica.Units.SI.Time t_dist_end = 2.0 * 14.0 / 3.0 "Disturbance end (middle third)";

  // ==================== Controller timing ====================
  parameter Modelica.Units.SI.Time dt = 1.0 / 200.0 "Control period (200 Hz)";
  parameter Modelica.Units.SI.Time t_end = 14.0 "Simulation duration";

  // ==================== Finger angular positions ====================
  parameter Real alpha1 = 0.0 "Finger 1 base angle [rad]";
  parameter Real alpha2 = 2.0943951023931953 "Finger 2 base angle (2*pi/3) [rad]";
  parameter Real alpha3 = 4.1887902047863905 "Finger 3 base angle (4*pi/3) [rad]";

  // ==================== Tracking requirement ====================
  parameter Real track_thresh = 0.015 "Primary tracking error threshold [m]";
  parameter Modelica.Units.SI.Time t_track = 9.1 "Tracking convergence deadline [s]";

  // ==================== Continuous states (deformation + object pose) ====================
  Real theta1(start = 0.0, fixed = true) "Finger 1 total bending angle [rad]";
  Real omega1(start = 0.0, fixed = true) "Finger 1 angular velocity [rad/s]";
  Real theta2(start = 0.0, fixed = true) "Finger 2 total bending angle [rad]";
  Real omega2(start = 0.0, fixed = true) "Finger 2 angular velocity [rad/s]";
  Real theta3(start = 0.0, fixed = true) "Finger 3 total bending angle [rad]";
  Real omega3(start = 0.0, fixed = true) "Finger 3 angular velocity [rad/s]";

  Real x_obj(start = 0.0, fixed = true) "Object x-position (object pose measurement) [m]";
  Real y_obj(start = 0.0, fixed = true) "Object y-position (object pose measurement) [m]";
  Real vx_obj(start = 0.0, fixed = true) "Object x-velocity [m/s]";
  Real vy_obj(start = 0.0, fixed = true) "Object y-velocity [m/s]";

  // ==================== Discrete states (controller, actuator sensing) ====================
  discrete Real p_cmd1(start = 0.0) "Finger 1 pressure command (actuator sensing) [Pa]";
  discrete Real p_cmd2(start = 0.0) "Finger 2 pressure command (actuator sensing) [Pa]";
  discrete Real p_cmd3(start = 0.0) "Finger 3 pressure command (actuator sensing) [Pa]";
  discrete Real e_F_int(start = 0.0) "Force tracking error integral [N.s]";

  // ==================== Intermediate and sensor variables ====================
  Real p_base "Ramped base pressure [Pa]";
  Real p_sat1 "Finger 1 saturated pressure [Pa]";
  Real p_sat2 "Finger 2 saturated pressure [Pa]";
  Real p_sat3 "Finger 3 saturated pressure [Pa]";

  Real phi1 "Finger 1 per-section angle [rad]";
  Real phi2 "Finger 2 per-section angle [rad]";
  Real phi3 "Finger 3 per-section angle [rad]";

  Real r_tip1 "Finger 1 tip radial position [m]";
  Real r_tip2 "Finger 2 tip radial position [m]";
  Real r_tip3 "Finger 3 tip radial position [m]";
  Real r_tip_dot1 "Finger 1 tip radial velocity [m/s]";
  Real r_tip_dot2 "Finger 2 tip radial velocity [m/s]";
  Real r_tip_dot3 "Finger 3 tip radial velocity [m/s]";

  Real surface1 "Object surface at finger 1 direction [m]";
  Real surface2 "Object surface at finger 2 direction [m]";
  Real surface3 "Object surface at finger 3 direction [m]";

  Real gap1 "Finger 1 contact gap [m]";
  Real gap2 "Finger 2 contact gap [m]";
  Real gap3 "Finger 3 contact gap [m]";
  Real gap_dot1 "Finger 1 gap rate [m/s]";
  Real gap_dot2 "Finger 2 gap rate [m/s]";
  Real gap_dot3 "Finger 3 gap rate [m/s]";

  Real N1 "Finger 1 normal contact force (distributed contact sensing) [N]";
  Real N2 "Finger 2 normal contact force (distributed contact sensing) [N]";
  Real N3 "Finger 3 normal contact force (distributed contact sensing) [N]";
  Real F_total "Total normal grasp force [N]";

  Real v_slide1 "Finger 1 sliding velocity [m/s]";
  Real v_slide2 "Finger 2 sliding velocity [m/s]";
  Real v_slide3 "Finger 3 sliding velocity [m/s]";
  Real f_fric1 "Finger 1 friction force magnitude [N]";
  Real f_fric2 "Finger 2 friction force magnitude [N]";
  Real f_fric3 "Finger 3 friction force magnitude [N]";

  Real Fx_obj "Net force on object in x [N]";
  Real Fy_obj "Net force on object in y [N]";
  Real F_dist_x "Tangential disturbance in x [N]";

  // ==================== Monitoring (bounds and performance) ====================
  Real tracking_error "Primary tracking error: object displacement from center [m]";
  Real contact_loss_flag "Contact loss indicator (0 = all contacts maintained)";
  Real p_violation "Pressure bound violation indicator";
  Real theta_violation "Deformation bound violation indicator";
  Real force_violation "Per-contact force bound violation indicator";

equation
  // ==================== Pressure ramp (gentle approach) ====================
  p_base = p_nominal * min(1.0, time / t_ramp);

  // ==================== Disturbance: 4 N tangential during middle third ====================
  F_dist_x = if time >= t_dist_start and time <= t_dist_end then F_dist else 0.0;

  // ==================== Pressure saturation (actuator bound: 95 kPa) ====================
  p_sat1 = max(0.0, min(p_max, p_cmd1));
  p_sat2 = max(0.0, min(p_max, p_cmd2));
  p_sat3 = max(0.0, min(p_max, p_cmd3));

  // ==================== Four-section kinematic chain ====================
  phi1 = theta1 / n_sections;
  phi2 = theta2 / n_sections;
  phi3 = theta3 / n_sections;

  r_tip1 = R_palm + l_seg * (cos(phi1) + cos(2.0 * phi1) + cos(3.0 * phi1) + cos(4.0 * phi1));
  r_tip2 = R_palm + l_seg * (cos(phi2) + cos(2.0 * phi2) + cos(3.0 * phi2) + cos(4.0 * phi2));
  r_tip3 = R_palm + l_seg * (cos(phi3) + cos(2.0 * phi3) + cos(3.0 * phi3) + cos(4.0 * phi3));

  r_tip_dot1 = l_seg * (-sin(phi1) - 2.0 * sin(2.0 * phi1) - 3.0 * sin(3.0 * phi1) - 4.0 * sin(4.0 * phi1)) * (omega1 / n_sections);
  r_tip_dot2 = l_seg * (-sin(phi2) - 2.0 * sin(2.0 * phi2) - 3.0 * sin(3.0 * phi2) - 4.0 * sin(4.0 * phi2)) * (omega2 / n_sections);
  r_tip_dot3 = l_seg * (-sin(phi3) - 2.0 * sin(2.0 * phi3) - 3.0 * sin(3.0 * phi3) - 4.0 * sin(4.0 * phi3)) * (omega3 / n_sections);

  // ==================== Object surface projection along each finger direction ====================
  surface1 = R_obj + x_obj * cos(alpha1) + y_obj * sin(alpha1);
  surface2 = R_obj + x_obj * cos(alpha2) + y_obj * sin(alpha2);
  surface3 = R_obj + x_obj * cos(alpha3) + y_obj * sin(alpha3);

  // ==================== Contact gaps and rates ====================
  gap1 = r_tip1 - surface1;
  gap2 = r_tip2 - surface2;
  gap3 = r_tip3 - surface3;

  gap_dot1 = r_tip_dot1 - (vx_obj * cos(alpha1) + vy_obj * sin(alpha1));
  gap_dot2 = r_tip_dot2 - (vx_obj * cos(alpha2) + vy_obj * sin(alpha2));
  gap_dot3 = r_tip_dot3 - (vx_obj * cos(alpha3) + vy_obj * sin(alpha3));

  // ==================== Compliant contact normal forces ====================
  N1 = if gap1 < 0.0 then k_contact * (-gap1) + b_contact * max(0.0, -gap_dot1) else 0.0;
  N2 = if gap2 < 0.0 then k_contact * (-gap2) + b_contact * max(0.0, -gap_dot2) else 0.0;
  N3 = if gap3 < 0.0 then k_contact * (-gap3) + b_contact * max(0.0, -gap_dot3) else 0.0;

  F_total = N1 + N2 + N3;

  // ==================== Friction (Coulomb with smoothing, mu = 0.70) ====================
  v_slide1 = vx_obj * (-sin(alpha1)) + vy_obj * cos(alpha1);
  v_slide2 = vx_obj * (-sin(alpha2)) + vy_obj * cos(alpha2);
  v_slide3 = vx_obj * (-sin(alpha3)) + vy_obj * cos(alpha3);

  f_fric1 = mu * N1 * tanh(v_slide1 / v_thresh);
  f_fric2 = mu * N2 * tanh(v_slide2 / v_thresh);
  f_fric3 = mu * N3 * tanh(v_slide3 / v_thresh);

  // ==================== Object dynamics ====================
  Fx_obj = (-N1 * cos(alpha1) + f_fric1 * sin(alpha1))
         + (-N2 * cos(alpha2) + f_fric2 * sin(alpha2))
         + (-N3 * cos(alpha3) + f_fric3 * sin(alpha3))
         + F_dist_x;
  Fy_obj = (-N1 * sin(alpha1) - f_fric1 * cos(alpha1))
         + (-N2 * sin(alpha2) - f_fric2 * cos(alpha2))
         + (-N3 * sin(alpha3) - f_fric3 * cos(alpha3));

  der(x_obj) = vx_obj;
  der(y_obj) = vy_obj;
  der(vx_obj) = Fx_obj / m_obj;
  der(vy_obj) = Fy_obj / m_obj;

  // ==================== Finger bending dynamics with deformation limit ====================
  der(theta1) = omega1;
  I_finger * der(omega1) = k_bend * p_sat1 - b_finger * omega1 - k_spring * theta1
                           - k_limit * max(0.0, theta1 - theta_soft);

  der(theta2) = omega2;
  I_finger * der(omega2) = k_bend * p_sat2 - b_finger * omega2 - k_spring * theta2
                           - k_limit * max(0.0, theta2 - theta_soft);

  der(theta3) = omega3;
  I_finger * der(omega3) = k_bend * p_sat3 - b_finger * omega3 - k_spring * theta3
                           - k_limit * max(0.0, theta3 - theta_soft);

  // ==================== Discrete force controller at 200 Hz ====================
  // PI on total normal force with anti-windup, per-contact redistribution, and
  // contact-loss prevention boost. Pressure commands bounded to [0, 95 kPa].
  when sample(0, dt) then
    // Anti-windup: integrate only when contact is established
    e_F_int = if F_total > F_contact_thresh then pre(e_F_int) + (F_set - F_total) * dt else 0.0;

    // Finger 1: base + PI force + redistribution + contact-loss boost
    p_cmd1 = max(0.0, min(p_max,
      p_base
      + Kp_force * (F_set - F_total)
      + Ki_force * pre(e_F_int)
      - K_redist * max(0.0, N1 - N_max)
      + 0.5 * K_redist * (max(0.0, N2 - N_max) + max(0.0, N3 - N_max))
      + K_boost * max(0.0, N_min - N1)
    ));

    // Finger 2
    p_cmd2 = max(0.0, min(p_max,
      p_base
      + Kp_force * (F_set - F_total)
      + Ki_force * pre(e_F_int)
      - K_redist * max(0.0, N2 - N_max)
      + 0.5 * K_redist * (max(0.0, N1 - N_max) + max(0.0, N3 - N_max))
      + K_boost * max(0.0, N_min - N2)
    ));

    // Finger 3
    p_cmd3 = max(0.0, min(p_max,
      p_base
      + Kp_force * (F_set - F_total)
      + Ki_force * pre(e_F_int)
      - K_redist * max(0.0, N3 - N_max)
      + 0.5 * K_redist * (max(0.0, N1 - N_max) + max(0.0, N2 - N_max))
      + K_boost * max(0.0, N_min - N3)
    ));
  end when;

  // ==================== Synchronized monitoring traces ====================
  // Primary tracking error (object displacement from grasp center)
  tracking_error = sqrt(x_obj * x_obj + y_obj * y_obj);

  // Contact loss: any per-finger normal force below N_min
  contact_loss_flag = if (N1 < N_min) or (N2 < N_min) or (N3 < N_min) then 1.0 else 0.0;

  // Actuator bound violation
  p_violation = if (p_cmd1 > p_max + 1.0) or (p_cmd2 > p_max + 1.0) or (p_cmd3 > p_max + 1.0) then 1.0 else 0.0;

  // Deformation bound violation
  theta_violation = if (theta1 > theta_max) or (theta2 > theta_max) or (theta3 > theta_max) then 1.0 else 0.0;

  // Per-contact force bound violation
  force_violation = if (N1 > N_max) or (N2 > N_max) or (N3 > N_max) then 1.0 else 0.0;

  annotation(
    experiment(StartTime = 0, StopTime = 14.0, Tolerance = 1e-6, Interval = 0.005),
    Documentation(info = "SoftGripGraspD: Instrumented soft robotic grip system.
      Embodiment: Three 0.13 m silicone fingers on a rigid palm, each with one pressure
      chamber represented by four bending sections. Three chamber-pressure commands
      limited to 95 kPa-gauge.

      Behavior: Conforms around a fragile object and regulates total normal grasp force
      (F_set = 3.0 N) without local overload (N_max = 2.5 N per contact). Contact-force
      redistribution reduces over-loaded contacts and boosts weak ones to prevent loss.

      Contact: Compliant collision (spring-damper) with friction coefficient 0.70 on a
      rigid support surface.

      Disturbance: 4 N tangential load applied during middle third [4.67, 9.33] s.

      Controller: 200 Hz discrete PI force control with anti-windup and redistribution.

      Requirements: Actuator and deformation bounds, per-contact and total force bands,
      object displacement (tracking_error), no contact loss (contact_loss_flag), primary
      tracking error below 0.015 m after 9.1 s, no NaN/infinite values.

      Traces: theta1/2/3, omega1/2/3 (deformation state), p_cmd1/2/3, p_sat1/2/3 (actuator
      command/sensing), N1/2/3, F_total (distributed contact sensing), x_obj, y_obj,
      vx_obj, vy_obj (object pose measurement), tracking_error, all bound violation flags.")
  );
end SoftGripGraspD;