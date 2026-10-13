model MonoHopWalkC
  "MonoHopWalkC: floating-base legged robot with phase-based joint impedance and body-attitude control"
  // Objective: periodic forward gait at 0.4 m/s, nominal body height
  // Max command: 874 N; 63 N body push during middle third (4-8 s of 12 s)
  // 10 kg cylindrical body, telescoping leg 0.30-0.60 m, 15 kN/m spring, 170 N.s/m damper
  // Spherical foot on rigid plane, friction 0.85, gravity 9.81
  // 125 Hz control; sensors: encoders, IMU, foot force

  // ===== Specified physical parameters =====
  parameter Real m_body(unit="kg") = 10.0 "Body mass";
  parameter Real L_min(unit="m") = 0.30 "Minimum leg length";
  parameter Real L_max(unit="m") = 0.60 "Maximum leg length";
  parameter Real k_leg(unit="N/m") = 15000.0 "Leg spring stiffness";
  parameter Real c_leg(unit="N.s/m") = 170.0 "Leg damper coefficient";
  parameter Real F_max(unit="N") = 874.0 "Maximum actuator command magnitude";
  parameter Real mu = 0.85 "Ground friction coefficient";
  parameter Real g(unit="m/s2") = 9.81 "Gravity";
  parameter Real v_des(unit="m/s") = 0.4 "Desired forward speed";
  parameter Real F_push(unit="N") = 63.0 "Push disturbance force";

  // ===== Assumed parameters (not specified in requirement) =====
  parameter Real I_body(unit="kg.m2") = 0.2 "Body pitch inertia (assumed; cylinder dimensions not specified)";
  parameter Real L_nom(unit="m") = 0.45 "Nominal leg length (midpoint of 0.30-0.60 range)";
  parameter Real h_nom(unit="m") = 0.45 "Nominal body height (assumed; body height not explicitly stated)";
  parameter Real r_foot(unit="m") = 0.03 "Foot sphere radius (assumed; not specified)";
  parameter Real m_foot(unit="kg") = 0.5 "Foot mass (assumed; leg mass not specified)";
  parameter Real k_contact(unit="N/m") = 20000.0 "Contact stiffness (assumed; not specified)";
  parameter Real c_contact(unit="N.s/m") = 300.0 "Contact damping (assumed; not specified)";
  parameter Real k_stop(unit="N/m") = 100000.0 "Leg mechanical stop stiffness (assumed)";
  parameter Real v_eps(unit="m/s") = 0.05 "Friction regularization velocity (assumed)";
  parameter Real tau_max(unit="N.m") = 100.0 "Maximum hip torque (assumed; not specified)";

  // ===== Control parameters (assumed; not specified) =====
  parameter Real dt_ctrl(unit="s") = 0.008 "Control period, 125 Hz";
  parameter Real t_push_start(unit="s") = 4.0 "Push disturbance start (middle third of 12 s)";
  parameter Real t_push_end(unit="s") = 8.0 "Push disturbance end (middle third of 12 s)";
  parameter Real kp_att(unit="N.m/rad") = 200.0 "Body attitude P gain (assumed)";
  parameter Real kd_att(unit="N.m.s/rad") = 30.0 "Body attitude D gain (assumed)";
  parameter Real kp_phi(unit="N.m/rad") = 150.0 "Leg angle P gain (assumed)";
  parameter Real kd_phi(unit="N.m.s/rad") = 15.0 "Leg angle D gain (assumed)";
  parameter Real kp_v(unit="N.m.s/m") = 80.0 "Forward velocity gain (assumed)";
  parameter Real k_imp_stance(unit="N/m") = 5000.0 "Stance virtual impedance stiffness (assumed)";
  parameter Real c_imp_stance(unit="N.s/m") = 50.0 "Stance virtual impedance damping (assumed)";
  parameter Real k_imp_flight(unit="N/m") = 2000.0 "Flight virtual impedance stiffness (assumed)";
  parameter Real c_imp_flight(unit="N.s/m") = 30.0 "Flight virtual impedance damping (assumed)";
  parameter Real F_hop_bias(unit="N") = 150.0 "Hop energy injection bias (assumed)";
  parameter Real phi_des_coeff(unit="s") = 0.3 "Leg placement angle coefficient (assumed)";

  // ===== Continuous states =====
  Real x_b(start=0.0, fixed=true) "Body x position [m]";
  Real z_b(start=0.48, fixed=true) "Body z position [m]";
  Real vx_b(start=0.0, fixed=true) "Body x velocity [m/s]";
  Real vz_b(start=0.0, fixed=true) "Body z velocity [m/s]";
  Real theta(start=0.0, fixed=true) "Body pitch angle [rad]";
  Real omega(start=0.0, fixed=true) "Body pitch rate [rad/s]";
  Real x_f(start=0.0, fixed=true) "Foot x position [m]";
  Real z_f(start=0.03, fixed=true) "Foot z position [m]";
  Real vx_f(start=0.0, fixed=true) "Foot x velocity [m/s]";
  Real vz_f(start=0.0, fixed=true) "Foot z velocity [m/s]";

  // ===== Algebraic variables =====
  Real L "Leg length [m]";
  Real phi "Leg angle from vertical [rad]";
  Real dL "Leg length rate [m/s]";
  Real dphi "Leg angular rate [rad/s]";
  Real sin_phi "sin(phi)";
  Real cos_phi "cos(phi)";
  Real penetration "Ground penetration [m]";
  Real F_normal "Normal contact force [N]";
  Real F_friction "Friction force [N]";
  Real F_spring "Leg spring force [N]";
  Real F_damper "Leg damper force [N]";
  Real F_stop "Leg stop force [N]";
  Real F_axial "Total axial leg force [N]";
  Real F_dist "Disturbance force [N]";
  Real ax_b "Body x acceleration [m/s2]";
  Real az_b "Body z acceleration [m/s2]";

  // ===== Discrete control variables =====
  discrete Real F_cmd(start=0.0) "Bounded actuator command [N]";
  discrete Real tau_hip(start=0.0) "Bounded hip torque [N.m]";
  discrete Boolean in_contact(start=true) "Contact flag";
  discrete Integer n_contacts(start=1) "Supporting contact count";
  discrete Real phase(start=0.0) "Gait phase (0=stance, 1=flight)";
  discrete Real F_cmd_raw(start=0.0) "Raw actuator command before bounding [N]";
  discrete Real tau_raw(start=0.0) "Raw hip torque before bounding [N.m]";

  // ===== Sensors =====
  Real sensor_phi "Joint encoder: leg angle [rad]";
  Real sensor_L "Joint encoder: leg length [m]";
  Real sensor_theta "IMU: body pitch [rad]";
  Real sensor_omega "IMU: body pitch rate [rad/s]";
  Real sensor_ax "IMU: body x acceleration [m/s2]";
  Real sensor_az "IMU: body z acceleration [m/s2]";
  Real sensor_Ffoot "Foot contact force sensor [N]";

  // ===== Performance metrics =====
  Real v_fwd "Forward speed [m/s]";
  Real tracking_error "Primary speed tracking error |v_des - vx_b| [m/s]";
  Real forward_progress "Forward distance traveled [m]";
  Real body_height "Body height [m]";
  Real body_attitude "Body pitch angle [rad]";
  Real cmd_bound_ok "Command bound check (1=within, 0=exceeded)";
  Real leg_bound_ok "Leg length bound check (1=within, 0=exceeded)";

equation
  // ===== Kinematics: leg from body to foot =====
  L = sqrt((x_f - x_b)^2 + (z_f - z_b)^2 + 1e-12);
  phi = atan2(x_f - x_b, z_b - z_f);
  sin_phi = sin(phi);
  cos_phi = cos(phi);
  dL = sin_phi * (vx_f - vx_b) - cos_phi * (vz_f - vz_b);
  dphi = (sin_phi * (vz_f - vz_b) + cos_phi * (vx_f - vx_b)) / L;

  // ===== Leg internal forces (spring-damper-actuator + stops) =====
  F_spring = k_leg * (L_nom - L);
  F_damper = -c_leg * dL;
  F_stop = if L < L_min then k_stop * (L_min - L)
           elseif L > L_max then k_stop * (L_max - L)
           else 0.0;
  F_axial = F_spring + F_damper + F_cmd + F_stop;

  // ===== Contact (penalty-based, spherical foot on rigid plane) =====
  penetration = r_foot - z_f;
  F_normal = if penetration > 0.0 then
               max(0.0, k_contact * penetration - c_contact * vz_f)
             else 0.0;
  F_friction = if F_normal > 0.0 then
                 -mu * F_normal * tanh(vx_f / v_eps)
               else 0.0;

  // ===== Disturbance: 63 N push during middle third =====
  F_dist = if time >= t_push_start and time <= t_push_end then F_push else 0.0;

  // ===== Body translational dynamics =====
  // Leg axial force on body: -F_axial * (sin_phi, -cos_phi)
  // Hip torque tangential force on body: (tau_hip/L) * (cos_phi, sin_phi)
  ax_b = (-F_axial * sin_phi + (tau_hip / L) * cos_phi + F_dist) / m_body;
  az_b = (F_axial * cos_phi + (tau_hip / L) * sin_phi - m_body * g) / m_body;

  der(x_b) = vx_b;
  der(z_b) = vz_b;
  der(vx_b) = ax_b;
  der(vz_b) = az_b;

  // ===== Body rotational dynamics =====
  der(theta) = omega;
  der(omega) = tau_hip / I_body;

  // ===== Foot dynamics =====
  der(x_f) = vx_f;
  der(z_f) = vz_f;
  der(vx_f) = (F_axial * sin_phi - (tau_hip / L) * cos_phi + F_friction) / m_foot;
  der(vz_f) = (-F_axial * cos_phi - (tau_hip / L) * sin_phi + F_normal - m_foot * g) / m_foot;

  // ===== Sensor outputs =====
  sensor_phi = phi;
  sensor_L = L;
  sensor_theta = theta;
  sensor_omega = omega;
  sensor_ax = ax_b;
  sensor_az = az_b;
  sensor_Ffoot = F_normal;

  // ===== Performance metrics =====
  v_fwd = vx_b;
  tracking_error = abs(v_des - vx_b);
  forward_progress = x_b;
  body_height = z_b;
  body_attitude = theta;
  cmd_bound_ok = if abs(F_cmd) <= F_max + 1e-6 and abs(tau_hip) <= tau_max + 1e-6 then 1.0 else 0.0;
  leg_bound_ok = if L >= L_min - 1e-6 and L <= L_max + 1e-6 then 1.0 else 0.0;

  // ===== Discrete controller at 125 Hz =====
  when sample(0, dt_ctrl) then
    // Contact detection from foot position
    in_contact = z_f < r_foot + 1e-4;
    n_contacts = if in_contact then 1 else 0;
    phase = if in_contact then 0.0 else 1.0;

    // Phase-based joint impedance: different virtual stiffness/damping per phase
    // Stance: impedance + hop energy injection to sustain periodic gait
    // Flight: impedance to retract/extend leg to nominal for landing
    F_cmd_raw = if in_contact then
      k_imp_stance * (L_nom - L) - c_imp_stance * dL + F_hop_bias
    else
      k_imp_flight * (L_nom - L) - c_imp_flight * dL;

    // Body-attitude control via hip torque + forward velocity regulation
    // Stance: attitude PD + forward velocity error
    // Flight: leg placement for next stance + attitude PD
    tau_raw = if in_contact then
      kp_att * (-theta) - kd_att * omega + kp_v * (v_des - vx_b)
    else
      kp_phi * (v_des * phi_des_coeff / L_nom - phi) - kd_phi * dphi
      + kp_att * (-theta) - kd_att * omega;

    // Enforce joint and torque bounds
    F_cmd = max(-F_max, min(F_max, F_cmd_raw));
    tau_hip = max(-tau_max, min(tau_max, tau_raw));
  end when;

  // ===== Validity assertions: no NaN or infinite values =====
  assert(abs(x_b) < 1e4, "Body x position diverged");
  assert(z_b >= 0.0 and z_b < 1e4, "Body z position invalid");
  assert(abs(vx_b) < 1e3, "Body x velocity diverged");
  assert(abs(vz_b) < 1e3, "Body z velocity diverged");
  assert(abs(theta) < 100.0, "Body pitch diverged");
  assert(L > 0.01 and L < 10.0, "Leg length invalid");
  assert(abs(F_axial) < 1e6, "Leg force diverged");

end MonoHopWalkC;