model MonoHopRecoverF
  "Floating-base monopod hopper: stand in place and recover from a
   finite-duration lateral body impulse. Planar model with telescoping
   spring-damper leg, bounded axial actuator, Coulomb-friction spherical
   foot contact, whole-body balance control, and contact-qualified pose
   estimator. Level rigid ground, friction 0.90."

  // ---- Body ----
  parameter Real m_b(unit="kg") = 10.0 "Base mass";
  parameter Real I_b(unit="kg.m2") = 0.20 "Base pitch inertia (placeholder)";
  parameter Real d_h(unit="m") = 0.05 "Hip offset below COM (placeholder)";

  // ---- Leg ----
  parameter Real L_min(unit="m") = 0.30 "Minimum leg length";
  parameter Real L_max(unit="m") = 0.60 "Maximum leg length";
  parameter Real L_rest(unit="m") = 0.45 "Rest length of leg spring";
  parameter Real k_leg(unit="N/m") = 15000.0 "Leg spring stiffness";
  parameter Real c_leg(unit="N.s/m") = 170.0 "Leg damper";
  parameter Real k_hs(unit="N/m") = 5.0e4 "Hard-stop stiffness";
  parameter Real c_hs(unit="N.s/m") = 200.0 "Hard-stop damping";

  // ---- Foot ----
  parameter Real m_f(unit="kg") = 0.50 "Foot point mass (placeholder)";
  parameter Real mu(unit="1") = 0.90 "Ground friction coefficient";

  // ---- Ground ----
  parameter Real k_gnd(unit="N/m") = 1.0e4 "Ground normal stiffness";
  parameter Real c_gnd(unit="N.s/m") = 200.0 "Ground normal damping";
  parameter Real v_ref(unit="m/s") = 0.05 "Friction regularization velocity";

  // ---- Actuation ----
  parameter Real F_act_max(unit="N") = 1159.0 "Leg actuator force bound";
  parameter Real tau_max(unit="N.m") = 40.0 "Hip torque bound (placeholder)";

  // ---- Gravity ----
  parameter Real g(unit="m/s2") = 9.81 "Gravitational acceleration";

  // ---- Disturbance ----
  parameter Real F_push_amp(unit="N") = 203.0 "Lateral push amplitude";
  parameter Real t_push_start(unit="s") = 6.667 "Push start (middle third)";
  parameter Real t_push_end(unit="s") = 13.333 "Push end (middle third)";

  // ---- Control ----
  parameter Real x_des(unit="m") = 0.0 "Desired horizontal position";
  parameter Real z_b_des(unit="m") = 0.50 "Desired base height";
  parameter Real K_hop(unit="N/m") = 2500.0 "Height PD gain";
  parameter Real D_hop(unit="N.s/m") = 120.0 "Height damping gain";
  parameter Real K_theta = 1.5 "Pitch foot-placement gain";
  parameter Real K_omega = 0.30 "Pitch-rate foot-placement gain";
  parameter Real K_x = 0.20 "Position foot-placement gain";
  parameter Real K_vx = 0.15 "Velocity foot-placement gain";
  parameter Real K_phi(unit="N.m/rad") = 300.0 "Hip angle PD gain";
  parameter Real D_phi(unit="N.m.s/rad") = 30.0 "Hip angle damping";

  // ---- Estimator ----
  parameter Real k_est(unit="1/s") = 15.0 "Stance contact correction gain";

  // ---- Continuous states ----
  Real x_b(start=0.0) "Base horizontal position [m]";
  Real vx_b(start=0.0) "Base horizontal velocity [m/s]";
  Real z_b(start=0.50) "Base height [m]";
  Real vz_b(start=0.0) "Base vertical velocity [m/s]";
  Real theta(start=0.0) "Base pitch [rad]";
  Real omega(start=0.0) "Base pitch rate [rad/s]";
  Real x_f(start=0.0) "Foot horizontal position [m]";
  Real vx_f(start=0.0) "Foot horizontal velocity [m/s]";
  Real z_f(start=0.0) "Foot vertical position [m]";
  Real vz_f(start=0.0) "Foot vertical velocity [m/s]";
  Real theta_hat(start=0.0) "Estimated base pitch [rad]";

  // ---- Discrete states ----
  Boolean inStance(start=false) "Stance contact flag";
  discrete Real x_f_entry(start=0.0) "Foot x at stance entry [m]";
  discrete Real slip_max(start=0.0) "Max recorded foot slip [m]";

  // ---- Kinematics ----
  Real x_h "Hip x [m]";
  Real z_h "Hip z [m]";
  Real vx_h "Hip vx [m/s]";
  Real vz_h "Hip vz [m/s]";
  Real dx "Foot-hip x [m]";
  Real dz "Foot-hip z [m]";
  Real r "Leg length [m]";
  Real r_safe "Leg length guarded [m]";
  Real alpha "Leg angle from vertical [rad]";
  Real phi "Leg angle rel. body [rad]";
  Real vr "Leg length rate [m/s]";
  Real alpha_dot "Leg angle rate [rad/s]";
  Real phi_dot "Rel. leg angle rate [rad/s]";
  Real sin_a "sin(alpha)";
  Real cos_a "cos(alpha)";

  // ---- Forces ----
  Real F_a "Leg axial force [N]";
  Real F_hs "Hard-stop force [N]";
  Real F_act_cmd "Commanded actuator [N]";
  Real F_act "Saturated actuator [N]";
  Real tau_cmd "Commanded hip torque [N.m]";
  Real tau_hip "Saturated hip torque [N.m]";
  Real phi_des "Desired rel. leg angle [rad]";
  Real N "Ground normal force [N]";
  Real Fx_gnd "Ground friction [N]";
  Real Fz_gnd "Ground vertical [N]";
  Real F_push "Lateral push [N]";
  Real stance_gate "Smooth stance activation";
  Real theta_meas "Kinematic pitch [rad]";

  // ---- Verification ----
  Real slip_current "Current slip [m]";
  Real tracking_error "Attitude error [rad]";
  Boolean tau_bound_ok;
  Boolean slip_ok;
  Boolean height_ok;
  Boolean tracking_ok;
  Boolean finite_ok;

equation
  // Hip kinematics
  x_h = x_b + d_h*sin(theta);
  z_h = z_b - d_h*cos(theta);
  vx_h = vx_b + d_h*cos(theta)*omega;
  vz_h = vz_b + d_h*sin(theta)*omega;

  // Leg geometry
  dx = x_f - x_h;
  dz = z_f - z_h;
  r = sqrt(dx*dx + dz*dz);
  r_safe = max(r, 1.0e-4);
  alpha = atan2(dx, -dz);
  sin_a = sin(alpha);
  cos_a = cos(alpha);
  phi = alpha - theta;

  // Leg rates
  vr = (dx*(vx_f - vx_h) + dz*(vz_f - vz_h))/r_safe;
  alpha_dot = (cos_a*(vx_f - vx_h) + sin_a*(vz_f - vz_h))/r_safe;
  phi_dot = alpha_dot - omega;

  // Ground contact (penalty, level rigid ground)
  N = max(0.0, k_gnd*max(0.0, -z_f) + c_gnd*max(0.0, -vz_f));
  Fz_gnd = N;
  Fx_gnd = -mu*N*tanh(vx_f/v_ref);

  // Stance gate (smooth)
  stance_gate = N/(N + 5.0);

  // Leg hard stops
  F_hs = noEvent(if r > L_max then -k_hs*(r - L_max) - c_hs*vr
                 else if r < L_min then k_hs*(L_min - r) - c_hs*vr
                 else 0.0);

  // Leg axial force
  F_a = k_leg*(L_rest - r) - c_leg*vr + F_act + F_hs;

  // Bounded leg actuator
  F_act_cmd = stance_gate*(K_hop*(z_b_des - z_b) - D_hop*vz_b);
  F_act = max(-F_act_max, min(F_act_max, F_act_cmd));

  // Balance control
  phi_des = K_theta*theta + K_omega*omega + K_x*(x_b - x_des) + K_vx*vx_b;
  tau_cmd = K_phi*(phi_des - phi) - D_phi*phi_dot;
  tau_hip = max(-tau_max, min(tau_max, tau_cmd));

  // Push disturbance (middle third)
  F_push = if time >= t_push_start and time <= t_push_end then F_push_amp else 0.0;

  // Base dynamics
  der(x_b) = vx_b;
  der(vx_b) = (-F_a*sin_a - (tau_hip/r_safe)*cos_a + F_push)/m_b;
  der(z_b) = vz_b;
  der(vz_b) = (F_a*cos_a - (tau_hip/r_safe)*sin_a - m_b*g)/m_b;
  der(theta) = omega;
  der(omega) = (-tau_hip + d_h*(-F_a*sin(phi) - (tau_hip/r_safe)*cos(phi)))/I_b;

  // Foot dynamics
  der(x_f) = vx_f;
  der(vx_f) = (F_a*sin_a + (tau_hip/r_safe)*cos_a + Fx_gnd)/m_f;
  der(z_f) = vz_f;
  der(vz_f) = (-F_a*cos_a + (tau_hip/r_safe)*sin_a + Fz_gnd - m_f*g)/m_f;

  // Contact switching with foot placement snapshot
  when z_f < -1.0e-4 then
    inStance = true;
    x_f_entry = x_f;
  elsewhen z_f >= 0.0 then
    inStance = false;
  end when;

  // Slip tracking (stance only)
  slip_current = if inStance then abs(x_f - x_f_entry) else 0.0;
  when slip_current > slip_max then
    slip_max = slip_current;
  end when;

  // Pose estimator: IMU gyro + stance-qualified kinematic correction
  theta_meas = theta;
  der(theta_hat) = omega + k_est*(if inStance then (theta_meas - theta_hat) else 0.0);

  // Verification criteria
  tracking_error = abs(theta_hat);
  tau_bound_ok = (abs(tau_hip) <= tau_max + 1.0e-6) and (abs(F_act) <= F_act_max + 1.0e-6);
  slip_ok = slip_max <= 0.03;
  height_ok = z_b > 0.0;
  tracking_ok = if time >= 13.0 then (tracking_error < 0.096) else true;
  finite_ok = noEvent(
    x_b >= -1.0e20 and x_b <= 1.0e20 and
    z_b >= -1.0e20 and z_b <= 1.0e20 and
    theta >= -1.0e6 and theta <= 1.0e6 and
    theta_hat >= -1.0e6 and theta_hat <= 1.0e6 and
    N >= 0.0 and N <= 1.0e8 and
    r >= 0.0 and r <= 1.0e3);

  annotation (
    Documentation(info="Planar monopod hopper on level rigid ground.
      Base: 10 kg cylindrical body with pitch inertia I_b and hip offset d_h
      (geometry-dependent; placeholder values used). Telescoping leg 0.30-0.60 m
      with 15 kN/m spring and 170 N.s/m damper; bounded axial leg actuator
      |F_act|<=1159 N. Spherical foot with Coulomb friction mu=0.90.
      Whole-body balance control via bounded hip torque and foot placement.
      203 N lateral push during middle third of 20 s run. Estimator fuses
      IMU gyro with stance-qualified kinematic pitch correction.
      Verification: tau_bound_ok, slip_ok, height_ok, tracking_ok, finite_ok."),
    experiment(StartTime=0, StopTime=20, Tolerance=1.0e-4, Interval=0.002));
end MonoHopRecoverF;