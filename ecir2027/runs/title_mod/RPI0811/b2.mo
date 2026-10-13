model MonoHopRecoverA
  "Floating-base one-legged hopper with balance control, contact estimation, and traces."

  // Scenario timing
  parameter Real Ts = 0.0125 "s, control/estimator/sample period (80 Hz)";
  parameter Real T_total = 8.0 "s";

  // Stated physical parameters
  parameter Real m_body = 10.0 "kg";
  parameter Real g = 9.81 "m/s2";
  parameter Real L_min = 0.30 "m";
  parameter Real L_max = 0.60 "m";
  parameter Real k_leg = 15000.0 "N/m";
  parameter Real c_leg = 170.0 "N.s/m";
  parameter Real F_act_max = 684.0 "N";
  parameter Real mu_ground = 0.90;

  // Parameters not stated; finite non-singular placeholders
  parameter Real L_rest = 0.45 "m, spring rest length not stated; mid-range nominal";
  parameter Real I_body = 0.5 "kg.m2, body inertia not stated; finite placeholder";
  parameter Real tau_max = 100.0 "N.m, torque bound not stated; finite placeholder";
  parameter Real k_stop = 1.0e5 "N/m, hard-stop stiffness not stated";
  parameter Real c_stop = 1.0e3 "N.s/m, hard-stop damping not stated";
  parameter Real c_slip = 1.0e6 "N.s/m, slip regularization not stated";
  parameter Real N_thresh = 1.0 "N, contact detection threshold";
  parameter Real N_qual = 10.0 "N, force-qualified stance threshold";

  // Derived static compression
  parameter Real L0 = L_rest - m_body*g/k_leg "m, static compressed leg length";
  parameter Real z_des = L0 "m, desired body height";

  // Controlled push disturbance (middle third)
  parameter Real F_push = 70.0 "N";
  parameter Real T_push_start = T_total/3 "s";
  parameter Real T_push_end = 2.0*T_total/3 "s";

  // Controller gains
  parameter Real Kp_z = 200.0 "N/m";
  parameter Real Kd_z = 20.0 "N.s/m";
  parameter Real A_hop = 50.0 "N, hopping energy injection amplitude";
  parameter Real f_hop = 1.5 "Hz";
  parameter Real Kp_phi = 800.0 "N.m/rad";
  parameter Real Kd_phi = 80.0 "N.m.s/rad";
  parameter Real K_est = 0.5 "1/sample, estimator correction gain";

  // Continuous physical states
  Real L(start=L0) "m, telescoping leg length";
  Real dL(start=0.0) "m/s, leg length rate";
  Real phi(start=0.0) "rad, base attitude from vertical";
  Real phi_dot(start=0.0) "rad/s, attitude rate";
  Real xf(start=0.0) "m, foot horizontal position on ground";

  // Intermediate continuous variables
  Real x_body "m, body horizontal position";
  Real z_body "m, body vertical position";
  Real vz "m/s, body vertical velocity";
  Real F_leg "N, total leg axial force";
  Real F_spring "N, spring-damper force";
  Real F_stop "N, hard-stop force";
  Real F_push_x "N, external lateral push";
  Real F_hop "N, hopping command component";
  Real tau_hip "N.m, applied hip torque";
  Real N "N, ground normal force";
  Real F_req "N, friction force required";
  Real F_friction "N, actual Coulomb friction";
  Real e_track "rad, primary tracking error";
  Real omega_imu "rad/s, IMU angular rate";
  Real I_eff "kg.m2, effective inertia about foot pivot";
  Boolean contact "stance contact flag";
  Boolean stance_est "force-qualified stance estimate";

  // Discrete control/estimator states
  discrete Real F_cmd(start=0.0) "N, bounded leg actuator command";
  discrete Real tau_cmd(start=0.0) "N.m, bounded torque command";
  discrete Real phi_hat(start=0.0) "rad, estimated attitude";
  discrete Real phi_dot_hat(start=0.0) "rad/s, estimated attitude rate";
  discrete Real x_hat(start=0.0) "m, estimated base x";
  discrete Real z_hat(start=L0) "m, estimated base z";

  // Synchronized observable outputs (continuous traces retained by simulator)
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
  output Real y_normal_force = N "N";

equation
  // Kinematics: body position relative to foot on ground
  x_body = xf + L*sin(phi);
  z_body = L*cos(phi);
  vz = dL*cos(phi) - L*sin(phi)*phi_dot;

  // External lateral push, middle third only
  F_push_x = if time >= T_push_start and time < T_push_end then F_push else 0.0;

  // Hopping energy injection command component
  F_hop = A_hop*sin(2.0*Modelica.Constants.pi*f_hop*time);

  // Leg spring-damper, hard stops, actuator
  F_spring = k_leg*(L_rest - L) - c_leg*dL;
  F_stop = if L < L_min then k_stop*(L_min - L) - c_stop*dL
           elseif L > L_max then k_stop*(L_max - L) - c_stop*dL
           else 0.0;
  F_leg = F_spring + F_cmd + F_stop;

  // Rigid ground contact and Coulomb friction
  N = max(0.0, F_leg*cos(phi));
  contact = N > N_thresh;
  F_req = F_leg*sin(phi);
  F_friction = if contact then max(min(F_req, mu_ground*N), -mu_ground*N) else 0.0;
  der(xf) = if contact then (F_req - F_friction)/c_slip else 0.0;

  // Whole-body stance dynamics about foot pivot
  der(L) = dL;
  der(dL) = (F_leg + m_body*L*phi_dot*phi_dot
             - m_body*g*cos(phi) + F_push_x*sin(phi)) / m_body;
  der(phi) = phi_dot;
  I_eff = m_body*L*L + I_body;
  der(phi_dot) = (m_body*g*L*sin(phi)
                  - 2.0*m_body*L*dL*phi_dot
                  + tau_hip + F_push_x*L*cos(phi)) / max(I_eff, 0.1);

  // Bounded torque actuation
  tau_hip = max(min(tau_cmd, tau_max), -tau_max);

  // IMU sensor and force-qualified stance estimate
  omega_imu = phi_dot;
  stance_est = N > N_qual;
  e_track = abs(phi_hat);

  // 80 Hz control, estimation, and synchronized trace logging
when sample(0, Ts) then
  // Bounded linear leg actuator command
  F_cmd = max(min(Kp_z*(z_des - z_body) - Kd_z*vz + F_hop, F_act_max), -F_act_max);

  // Bounded whole-body balance torque using previous estimate
  tau_cmd = max(min(Kp_phi*(0.0 - pre(phi_hat)) - Kd_phi*pre(phi_dot_hat), tau_max), -tau_max);

  // Base pose estimate from IMU, kinematics, and force-qualified stance
  phi_hat = pre(phi_hat) + Ts*omega_imu
           + K_est*((if stance_est then phi else pre(phi_hat)) - pre(phi_hat));
  phi_dot_hat = omega_imu;
  x_hat = if stance_est then x_body else pre(x_hat);
  z_hat = if stance_est then z_body else pre(z_hat);
end when;

  annotation(experiment(StopTime=8.0, Tolerance=1e-4));
end MonoHopRecoverA;