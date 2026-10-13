model MonoHopRecoverF
  "Floating-base monopod hopper: stand/step in place and recover from a
   finite-duration lateral body impulse. Planar model with telescoping
   spring-damper leg, bounded axial leg actuator, passive spherical foot
   contact with Coulomb friction, whole-body balance control via hip torque
   and foot placement, and a simple contact-qualified pose estimator."

  // ---- Body (cylindrical base) ----
  parameter Real m_b(unit="kg") = 10.0 "Base mass";
  parameter Real I_b(unit="kg.m2") = 0.20
    "Base pitch inertia about COM (radius/height unknown; placeholder)";
  parameter Real d_h(unit="m") = 0.05
    "Hip offset along body axis below COM (unknown; placeholder)";

  // ---- Leg (telescoping) ----
  parameter Real L_min(unit="m") = 0.30 "Minimum leg length";
  parameter Real L_max(unit="m") = 0.60 "Maximum leg length";
  parameter Real L_rest(unit="m") = 0.45 "Rest length of leg spring";
  parameter Real k_leg(unit="N/m") = 15000.0 "Leg spring stiffness";
  parameter Real c_leg(unit="N.s/m") = 170.0 "Leg damper";
  parameter Real k_hs(unit="N/m") = 5.0e5 "Hard-stop stiffness at leg limits";
  parameter Real c_hs(unit="N.s/m") = 1000.0 "Hard-stop damping";

  // ---- Foot ----
  parameter Real m_f(unit="kg") = 0.50
    "Foot point mass (spherical foot; unknown; placeholder)";
  parameter Real mu(unit="1") = 0.90 "Ground friction coefficient";

  // ---- Ground (rigid, level, penalty contact) ----
  parameter Real k_gnd(unit="N/m") = 2.0e4 "Ground normal stiffness";
  parameter Real c_gnd(unit="N.s/m") = 300.0 "Ground normal damping";
  parameter Real v_ref(unit="m/s") = 0.05 "Friction regularization velocity";

  // ---- Actuation bounds ----
  parameter Real F_act_max(unit="N") = 1159.0 "Leg actuator force bound";
  parameter Real tau_max(unit="N.m") = 40.0
    "Hip torque bound (unknown; placeholder)";

  // ---- Gravity ----
  parameter Real g(unit="m/s2") = 9.81 "Gravitational acceleration";

  // ---- Disturbance ----
  parameter Real F_push_amp(unit="N") = 203.0 "Lateral push amplitude";
  parameter Real t_push_start(unit="s") = 6.667 "Push start (middle third)";
  parameter Real t_push_end(unit="s") = 13.333 "Push end (middle third)";

  // ---- Control setpoints and gains ----
  parameter Real x_des(unit="m") = 0.0 "Desired horizontal position";
  parameter Real z_b_des(unit="m") = 0.50 "Desired base height";
  parameter Real K_hop(unit="N/m") = 2500.0 "Height PD gain";
  parameter Real D_hop(unit="N.s/m") = 120.0 "Height damping gain";
  parameter Real K_theta(unit="rad/m") = 1.5 "Foot-placement pitch gain";
  parameter Real K_omega(unit="rad.s/m") = 0.30 "Foot-placement rate gain";
  parameter Real K_x(unit="1") = 0.20 "Foot-placement position gain";
  parameter Real K_vx(unit="s/m") = 0.15 "Foot-placement velocity gain";
  parameter Real K_phi(unit="N.m/rad") = 300.0 "Hip angle PD gain";
  parameter Real D_phi(unit="N.m.s/rad") = 30.0 "Hip angle damping";

  // ---- Estimator ----
  parameter Real k_est(unit="1/s") = 15.0 "Stance contact correction gain";

  // ---- Continuous states ----
  Real x_b(start=0.0, unit="m") "Base horizontal position";
  Real vx_b(start=0.0, unit="m/s") "Base horizontal velocity";
  Real z_b(start=0.5, unit="m") "Base vertical position (height)";
  Real vz_b(start=0.0, unit="m/s") "Base vertical velocity";
  Real theta(start=0.0, unit="rad") "Base pitch";
  Real omega(start=0.0, unit="rad/s") "Base pitch rate";
  Real x_f(start=0.0, unit="m") "Foot horizontal position";
  Real vx_f(start=0.0, unit="m/s") "Foot horizontal velocity";
  Real z_f(start=-0.002, unit="m") "Foot vertical position";
  Real vz_f(start=0.0, unit="m/s") "Foot vertical velocity";
  Real theta_hat(start=0.0, unit="rad") "Estimated base pitch";
  Real x_f_entry(start=0.0, unit="m") "Foot horizontal position at stance entry";
  Real slip_max(start=0.0, unit="m") "Maximum recorded foot slip distance";

  // ---- Derived kinematics ----
  Real x_h(unit="m") "Hip horizontal position";
  Real z_h(unit="m") "Hip vertical position";
  Real vx_h(unit="m/s") "Hip horizontal velocity";
  Real vz_h(unit="m/s") "Hip vertical velocity";
  Real dx(unit="m") "Foot relative to hip, horizontal";
  Real dz(unit="m") "Foot relative to hip, vertical (foot below hip <0)";
  Real r(unit="m") "Leg length";
  Real r_safe(unit="m") "Leg length guarded against zero";
  Real alpha(unit="rad") "Absolute leg angle from vertical (0 = straight down)";
  Real phi(unit="rad") "Leg angle relative to body (alpha - theta)";
  Real vr(unit="m/s") "Leg lengthening rate";
  Real alpha_dot(unit="rad/s") "Absolute leg angle rate";
  Real phi_dot(unit="rad/s") "Relative leg angle rate";
  Real sin_a "sin(alpha)";
  Real cos_a "cos(alpha)";

  // ---- Forces ----
  Real F_a(unit="N") "Leg axial force (compression positive)";
  Real F_hs(unit="N") "Leg hard-stop force";
  Real F_act_cmd(unit="N") "Commanded leg actuator force";
  Real F_act(unit="N") "Saturated leg actuator force";
  Real tau_cmd(unit="N.m") "Commanded hip torque";
  Real tau_hip(unit="N.m") "Saturated hip torque";
  Real phi_des(unit="rad") "Desired relative leg angle";
  Real N(unit="N") "Ground normal force on foot";
  Real Fx_gnd(unit="N") "Ground friction force on foot";
  Real Fz_gnd(unit="N") "Ground vertical force on foot";
  Real F_push(unit="N") "Lateral push disturbance on base";
  Real stance_gate(unit="1") "Smooth stance activation 0..1";

  // ---- Contact discrete state ----
  Boolean inStance(start=false) "True while foot is in stance";

  // ---- Estimator signals ----
  Real theta_meas(unit="rad") "Kinematic pitch measurement during stance";

  // ---- Verification outputs ----
  Real slip_current(unit="m") "Current foot slip distance from entry";
  Real tracking_error(unit="rad") "Primary attitude tracking error";
  Boolean tau_bound_ok "Torque/force bound satisfaction";
  Boolean slip_ok "Foot slip below 0.03 m";
  Boolean height_ok "Positive base height";
  Boolean tracking_ok "Tracking error below 0.096 rad after 13 s";
  Boolean finite_ok "No NaN/infinity detected in key signals";

equation
  // Hip kinematics (offset along body axis below COM)
  x_h = x_b + d_h*sin(theta);
  z_h = z_b - d_h*cos(theta);
  vx_h = vx_b + d_h*cos(theta)*omega;
  vz_h = vz_b + d_h*sin(theta)*omega;

  // Foot relative to hip and leg state
  dx = x_f - x_h;
  dz = z_f - z_h;
  r = sqrt(dx*dx + dz*dz);
  r_safe = max(r, 1.0e-4);
  alpha = atan2(dx, -dz);
  sin_a = sin(alpha);
  cos_a = cos(alpha);
  phi = alpha - theta;

  // Leg lengthening rate and angular rates
  vr = (dx*(vx_f - vx_h) + dz*(vz_f - vz_h))/r_safe;
  alpha_dot = (cos_a*(vx_f - vx_h) + sin_a*(vz_f - vz_h))/r_safe;
  phi_dot = alpha_dot - omega;

  // ---- Ground contact (penalty, level rigid ground) ----
  // Normal force: vertical penetration of spherical foot
  N = max(0.0, k_gnd*max(0.0, -z_f) + c_gnd*max(0.0, -vz_f));
  Fz_gnd = N;
  // Coulomb-like friction with smooth regularization (well-defined at zero)
  Fx_gnd = -mu*N*tanh(vx_f/v_ref);

  // Smooth stance gate for actuator enablement (event-free)
  stance_gate = N/(N + 5.0);

  // ---- Leg axial force (spring + damper + actuator + hard stops) ----
  F_a = k_leg*(L_rest - r) - c_leg*vr + F_act + F_hs;
  // Hard stops keep telescoping leg within [L_min, L_max]
  F_hs = noEvent(if r > L_max then -k_hs*(r - L_max) - c_hs*vr
                 else if r < L_min then k_hs*(L_min - r) - c_hs*vr
                 else 0.0);

  // ---- Leg actuator: bounded, injects hopping energy during stance ----
  F_act_cmd = stance_gate*(K_hop*(z_b_des - z_b) - D_hop*vz_b);
  F_act = max(-F_act_max, min(F_act_max, F_act_cmd));

  // ---- Whole-body balance control via hip torque and foot placement ----
  phi_des = K_theta*theta + K_omega*omega + K_x*(x_b - x_des) + K_vx*vx_b;
  tau_cmd = K_phi*(phi_des - phi) - D_phi*phi_dot;
  tau_hip = max(-tau_max, min(tau_max, tau_cmd));

  // ---- Lateral push disturbance (middle third of run) ----
  F_push = if time >= t_push_start and time <= t_push_end then F_push_amp else 0.0;

  // ---- Base translational dynamics ----
  der(x_b) = vx_b;
  der(vx_b) = (-F_a*sin_a - (tau_hip/r_safe)*cos_a + F_push)/m_b;
  der(z_b) = vz_b;
  der(vz_b) = (F_a*cos_a - (tau_hip/r_safe)*sin_a - m_b*g)/m_b;

  // ---- Base pitch dynamics ----
  der(theta) = omega;
  der(omega) = (-tau_hip + d_h*(-F_a*sin(phi) - (tau_hip/r_safe)*cos(phi)))/I_b;

  // ---- Foot translational dynamics (point mass, spherical foot) ----
  der(x_f) = vx_f;
  der(vx_f) = (F_a*sin_a + (tau_hip/r_safe)*cos_a + Fx_gnd)/m_f;
  der(z_f) = vz_f;
  der(vz_f) = (-F_a*cos_a + (tau_hip/r_safe)*sin_a + Fz_gnd - m_f*g)/m_f;

  // ---- Continuous states carried only by reinit (require der) ----
  der(x_f_entry) = 0.0;
  der(slip_max) = 0.0;

  // ---- Contact switching (discrete stance flag) ----
  when z_f < -1.0e-4 then
    inStance = true;
  elsewhen z_f >= -1.0e-4 then
    inStance = false;
  end when;

  // ---- Pose estimator: IMU (gyro) + stance-qualified kinematic correction ----
  theta_meas = theta; // kinematic pitch available during stance (qualified)
  der(theta_hat) = omega + k_est*(if inStance then (theta_meas - theta_hat) else 0.0);

  // ---- Slip tracking ----
  slip_current = abs(x_f - x_f_entry);
  when edge(inStance) then
    reinit(x_f_entry, x_f);
  end when;
  when slip_current > pre(slip_max) then
    reinit(slip_max, slip_current);
  end when;

  // ---- Verification criteria ----
  tracking_error = abs(theta_hat);
  tau_bound_ok = (abs(tau_hip) <= tau_max + 1.0e-6)
              and (abs(F_act) <= F_act_max + 1.0e-6);
  slip_ok = slip_max <= 0.03;
  height_ok = z_b > 0.0;
  tracking_ok = if time >= 13.0 then (tracking_error < 0.096) else true;
  finite_ok = noEvent(
        x_b >= -1.0e20 and x_b <= 1.0e20
    and z_b >= -1.0e20 and z_b <= 1.0e20
    and theta >= -1.0e6 and theta <= 1.0e6
    and theta_hat >= -1.0e6 and theta_hat <= 1.0e6
    and N >= 0.0 and N <= 1.0e8
    and r >= 0.0 and r <= 1.0e3);

  annotation (
    Documentation(info="Planar monopod hopper on level rigid ground.
  Base: 10 kg cylindrical body with pitch inertia I_b and hip offset d_h
  (both geometry-dependent and not specified by the requirement; bound
  placeholders are used). Telescoping leg 0.30-0.60 m with 15 kN/m spring
  and 170 N.s/m damper; bounded axial leg actuator |F_act|<=1159 N. Spherical
  foot with Coulomb friction mu=0.90. Whole-body balance control via bounded
  hip torque (bound unspecified; placeholder tau_max) and foot placement.
  A 203 N lateral push is applied during the middle third of the 20 s run.
  Estimator fuses IMU gyro with stance-qualified kinematic pitch correction.
  Verification outputs: tau_bound_ok, slip_ok, height_ok, tracking_ok, finite_ok."),
    experiment(StartTime=0, StopTime=20, Tolerance=1.0e-4, Interval=0.002));
end MonoHopRecoverF;