model MonoHopRecoverA
  "Floating-base one-legged hopper: balance control, contact estimation, recovery from lateral impulse."

  // Stated physical parameters
  parameter Real m_body = 10.0 "kg";
  parameter Real g = 9.81 "m/s2";
  parameter Real L_min = 0.30 "m";
  parameter Real L_max = 0.60 "m";
  parameter Real k_leg = 15000.0 "N/m";
  parameter Real c_leg = 170.0 "N.s/m";
  parameter Real F_act_max = 684.0 "N";
  parameter Real mu_ground = 0.90 "friction coefficient";

  // Scenario parameters (stated)
  parameter Real Ts = 0.0125 "s, 80 Hz control period";
  parameter Real T_total = 8.0 "s";
  parameter Real F_push = 70.0 "N";
  parameter Real T_push_start = T_total/3 "s, middle third start";
  parameter Real T_push_end = 2*T_total/3 "s, middle third end";

  // Placeholder parameters (not stated; finite values chosen for buildability)
  parameter Real L_rest = 0.45 "m, spring rest length (not stated; nominal mid-range)";
  parameter Real k_stop = 1.0e5 "N/m, hard-stop stiffness (not stated; finite placeholder)";
  parameter Real c_stop = 1.0e3 "N.s/m, hard-stop damping (not stated; finite placeholder)";
  parameter Real c_slip = 1.0e5 "N.s/m, slip regularization (not stated; finite placeholder)";
  parameter Real N_thresh = 1.0 "N, contact detection threshold";
  parameter Real N_qual = 10.0 "N, force-qualified stance threshold";
  parameter Real tau_max = 100.0 "N.m, torque bound (not stated; finite placeholder)";
  parameter Real I_min = 0.01 "kg.m2, inertia floor to avoid singularity (not stated)";

  // Derived parameters
  parameter Real L0 = L_rest - m_body*g/k_leg "m, static equilibrium leg length";
  parameter Real z_des = L0 "m, desired body height";

  // Control gains (not stated; tuned for stability)
  parameter Real Kp_z = 200.0 "N/m";
  parameter Real Kd_z = 20.0 "N.s/m";
  parameter Real A_hop = 50.0 "N, hopping energy injection amplitude";
  parameter Real f_hop = 1.5 "Hz, hopping frequency";
  parameter Real Kp_phi = 800.0 "N.m/rad";
  parameter Real Kd_phi = 80.0 "N.m.s/rad";
  parameter Real K_est = 0.5 "1/sample, estimator correction gain";

  // Continuous dynamic states
  Real L(start=L0) "m, telescoping leg length";
  Real dL(start=0) "m/s, leg length rate";
  Real phi(start=0) "rad, body/leg attitude from vertical";
  Real phi_dot(start=0) "rad/s, attitude rate";
  Real xf(start=0) "m, foot horizontal position";

  // Discrete controller and estimator states
  discrete Real F_cmd(start=0) "N, bounded leg actuator command";
  discrete Real tau_cmd(start=0) "N.m, bounded torque command";
  discrete Real phi_hat(start=0) "rad, estimated attitude from IMU + kinematics";
  discrete Real phi_dot_hat(start=0) "rad/s, estimated attitude rate";
  discrete Real x_hat(start=0) "m, estimated base x";
  discrete Real z_hat(start=L0) "m, estimated base z";
  discrete Boolean stance_est(start=false) "force-qualified stance estimate";

  // Continuous auxiliary variables
  Real x_body "m, body horizontal position";
  Real z_body "m, body height";
  Real vz "m/s, body vertical velocity";
  Real F_spring "N";
  Real F_stop "N";
  Real F_leg "N, total axial leg force";
  Real N_normal "N, ground normal force";
  Real F_req_lat "N, required lateral force";
  Real F_friction "N, friction force";
  Real F_push_x "N, external push disturbance";
  Real F_hop "N, hopping energy injection signal";
  Real e_track "rad, primary tracking error";
  Boolean contact "stance contact flag";

  // Observable outputs
  output Real y_body_x = x_body "m";
  output Real y_body_z = z_body "m";
  output Real y_attitude = phi "rad";
  output Real y_tracking_error = e_track "rad";
  output Real y_foot_slip = abs(xf) "m";
  output Real y_contact = if contact then 1.0 else 0.0 "1/0";
  output Real y_leg_force = F_leg "N";
  output Real y_actuator_command = F_cmd "N";
  output Real y_torque_command = tau_cmd "N.m";
  output Real y_estimator_attitude = phi_hat "rad";
  output Real y_normal_force = N_normal "N";

equation
  // Kinematics: body position relative to foot on ground
  x_body = xf + L*sin(phi);
  z_body = L*cos(phi);
  vz = dL*cos(phi) - L*sin(phi)*phi_dot;

  // External lateral push disturbance during middle third of scenario
  F_push_x = if time >= T_push_start and time < T_push_end then F_push else 0.0;

  // Continuous hopping energy injection signal
  F_hop = A_hop*sin(2*Modelica.Constants.pi*f_hop*time);

  // Leg axial force: spring-damper + actuator + hard stops
  F_spring = k_leg*(L_rest - L) - c_leg*dL;
  F_stop = if L < L_min then k_stop*(L_min - L) - c_stop*dL
           elseif L > L_max then k_stop*(L_max - L) - c_stop*dL
           else 0.0;
  F_leg = F_spring + F_cmd + F_stop;

  // Ground contact: normal force and contact flag
  N_normal = max(0.0, F_leg*cos(phi));
  contact = N_normal > N_thresh;

  // Friction with slip regularization (Coulomb cone)
  F_req_lat = F_leg*sin(phi);
  F_friction = if contact then
    max(min(F_req_lat, mu_ground*N_normal), -mu_ground*N_normal)
    else 0.0;
  der(xf) = if contact then (F_req_lat - F_friction)/c_slip else 0.0;

  // Radial dynamics (polar coordinates about foot)
  der(L) = dL;
  m_body*der(dL) = F_leg + m_body*L*phi_dot*phi_dot
                   - m_body*g*cos(phi) + F_push_x*sin(phi);

  // Angular dynamics (polar coordinates about foot)
  der(phi) = phi_dot;
  (m_body*L*L + I_min)*der(phi_dot) = m_body*g*L*sin(phi)
                       - 2.0*m_body*L*dL*phi_dot
                       + tau_cmd + F_push_x*L*cos(phi);

  // Primary tracking error (attitude estimate magnitude)
  e_track = abs(phi_hat);

when sample(0, Ts) then
  // Bounded leg actuator: height PD + hopping energy injection
  F_cmd = max(min(Kp_z*(z_des - z_body) - Kd_z*vz + F_hop, F_act_max), -F_act_max);

  // Bounded torque: balance PD on estimated attitude
  tau_cmd = max(min(Kp_phi*(0.0 - pre(phi_hat)) - Kd_phi*pre(phi_dot_hat), tau_max), -tau_max);

  // Estimator: IMU integration + kinematic correction when force-qualified stance
  stance_est = N_normal > N_qual;
  phi_hat = pre(phi_hat) + Ts*phi_dot
            + K_est*((if stance_est then phi else pre(phi_hat)) - pre(phi_hat));
  phi_dot_hat = phi_dot;
  x_hat = if stance_est then x_body else pre(x_hat);
  z_hat = if stance_est then z_body else pre(z_hat);
end when;

  annotation(experiment(StopTime=8.0, Tolerance=1e-4));
end MonoHopRecoverA;