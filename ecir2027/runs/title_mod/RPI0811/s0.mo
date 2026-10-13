model MonoHopRecoverA
  "Floating-base one-legged hopper with balance control, contact estimation, and traces."

  // Scenario timing
  constant Integer N_samples = 641 "samples at 80 Hz over 8 s";
  parameter Real Ts = 0.0125 "s, control/estimator/sample period";
  parameter Real T_total = 8.0 "s";

  // Physical parameters stated by the request
  parameter Real m_body = 10.0 "kg";
  parameter Real g = 9.81 "m/s2";
  parameter Real L_min = 0.30 "m";
  parameter Real L_max = 0.60 "m";
  parameter Real k_leg = 15000.0 "N/m";
  parameter Real c_leg = 170.0 "N.s/m";
  parameter Real F_act_max = 684.0 "N";
  parameter Real mu_ground = 0.90 "friction coefficient";

  // Parameters not stated; finite non-singular placeholders or omitted behavior
  parameter Real L_rest = 0.45
    "m, spring rest length not stated; mid-range nominal used for initial stance";
  parameter Real I_body = 0.0
    "kg.m2, cylindrical body inertia not stated; omitted from effective foot inertia";
  parameter Real tau_max = 100.0
    "N.m, torque bound not stated; finite placeholder bound for controller saturation";
  parameter Real k_stop = 1.0e5 "N/m, leg hard-stop stiffness not stated";
  parameter Real c_stop = 1.0e3 "N.s/m, leg hard-stop damping not stated";
  parameter Real c_slip = 1.0e5 "N.s/m, contact slip regularization not stated";
  parameter Real N_thresh = 1.0 "N, contact detection threshold";
  parameter Real N_qual = 10.0 "N, force-qualified stance threshold";

  // Derived initial leg length under static compression
  parameter Real L0 = L_rest - m_body*g/k_leg "m, static compressed leg length";
  parameter Real z_des = L0 "m, desired body height";

  // Controlled push disturbance
  parameter Real F_push = 70.0 "N";
  parameter Real T_push_start = T_total/3 "s, middle third start";
  parameter Real T_push_end = 2*T_total/3 "s, middle third end";

  // Controller design choices
  parameter Real Kp_z = 200.0 "N/m";
  parameter Real Kd_z = 20.0 "N.s/m";
  parameter Real A_hop = 50.0 "N, hopping energy injection amplitude";
  parameter Real f_hop = 1.5 "Hz, hopping frequency";
  parameter Real Kp_phi = 800.0 "N.m/rad";
  parameter Real Kd_phi = 80.0 "N.m.s/rad";
  parameter Real K_est = 0.5 "1/sample, estimator correction gain";

  // Continuous physical states
  Real L(start=L0) "m, telescoping leg length";
  Real dL(start=0) "m/s, leg length rate";
  Real phi(start=0) "rad, base/leg attitude from vertical";
  Real phi_dot(start=0) "rad/s, attitude rate";
  Real xf(start=0) "m, foot horizontal position on ground";

  // Discrete control/estimator states
  discrete Real F_cmd(start=0) "N, bounded leg actuator command";
  discrete Real tau_cmd(start=0) "N.m, bounded torque command";
  discrete Real phi_hat(start=0) "rad, estimated attitude";
  discrete Real phi_dot_hat(start=0) "rad/s, estimated attitude rate";
  discrete Real x_hat(start=0) "m, estimated base x";
  discrete Real z_hat(start=L0) "m, estimated base z";
  Integer i(start=0) "sample counter";

  // Synchronized traces at 80 Hz
  output discrete Real trace_t[N_samples](start=fill(0.0,N_samples)) "s";
  output discrete Real trace_x[N_samples](start=fill(0.0,N_samples)) "m";
  output discrete Real trace_z[N_samples](start=fill(0.0,N_samples)) "m";
  output discrete Real trace_phi[N_samples](start=fill(0.0,N_samples)) "rad";
  output discrete Real trace_xf[N_samples](start=fill(0.0,N_samples)) "m";
  output discrete Real trace_F_cmd[N_samples](start=fill(0.0,N_samples)) "N";
  output discrete Real trace_tau_cmd[N_samples](start=fill(0.0,N_samples)) "N.m";
  output discrete Real trace_phi_hat[N_samples](start=fill(0.0,N_samples)) "rad";
  output discrete Real trace_N[N_samples](start=fill(0.0,N_samples)) "N";
  output discrete Real trace_contact[N_samples](start=fill(0.0,N_samples)) "1/0";
  output discrete Real trace_error[N_samples](start=fill(0.0,N_samples)) "rad";

  // Current observable outputs
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

  // Intermediate variables
  Real x_body "m";
  Real z_body "m";
  Real vz "m/s";
  Real F_leg "N";
  Real F_spring "N";
  Real F_stop "N";
  Real F_act "N";
  Real F_push_x "N";
  Real F_hop "N";
  Real tau_hip "N.m";
  Real N "N";
  Real F_req "N";
  Real F_friction "N";
  Real I_eff "kg.m2";
  Real e_track "rad";
  Real omega_imu "rad/s";
  Boolean contact;
  Boolean stance_est;

equation
  // Kinematics of base relative to foot
  x_body = xf + L*sin(phi);
  z_body = L*cos(phi);
  vz = dL*cos(phi) - L*sin(phi)*phi_dot;

  // External lateral push, middle third only
  F_push_x = if time >= T_push_start and time < T_push_end then F_push else 0.0;

  // Hopping energy injection command component
  F_hop = A_hop*sin(2*Modelica.Constants.pi*f_hop*time);

  // Leg spring, damper, actuator, and telescoping hard stops
  F_spring = k_leg*(L_rest - L) - c_leg*dL;
  F_stop = if L < L_min then k_stop*(L_min - L) - c_stop*dL
           elseif L > L_max then k_stop*(L_max - L) - c_stop*dL
           else 0.0;
  F_act = F_cmd;
  F_leg = F_spring + F_act + F_stop;

  // Rigid ground contact and Coulomb friction
  N = max(0.0, F_leg*cos(phi));
  contact = N > N_thresh;
  F_req = F_leg*sin(phi);
  F_friction = if contact then max(min(F_req, mu_ground*N), -mu_ground*N) else 0.0;
  der(xf) = if contact then (F_friction - F_req)/c_slip else 0.0;

  // Whole-body stance dynamics about foot pivot
  der(L) = dL;
  m_body*der(dL) = F_leg + m_body*L*phi_dot*phi_dot
                   - m_body*g*cos(phi) + F_push_x*sin(phi);
  der(phi) = phi_dot;
  I_eff = m_body*L*L + I_body;
  I_eff*der(phi_dot) = m_body*g*L*sin(phi)
                       - 2.0*m_body*L*dL*phi_dot
                       + tau_hip + F_push_x*L*cos(phi);

  // Bounded torque actuation
  tau_hip = max(min(tau_cmd, tau_max), -tau_max);

  // Sensors and force-qualified stance estimate
  omega_imu = phi_dot;
  stance_est = N > N_qual;
  e_track = abs(phi_hat);

  // 80 Hz control, estimation, and synchronized trace logging
when sample(0, Ts) then
  i = pre(i) + 1;

  // Bounded linear leg actuator command
  F_cmd = max(min(Kp_z*(z_des - z_body) - Kd_z*vz + F_hop, F_act_max), -F_act_max);

  // Bounded whole-body balance torque command
  tau_cmd = max(min(Kp_phi*(0.0 - pre(phi_hat)) - Kd_phi*pre(phi_dot_hat), tau_max), -tau_max);

  // Base pose estimate from IMU, kinematics, and force-qualified stance contacts
  phi_hat = pre(phi_hat) + Ts*omega_imu
           + K_est*((if stance_est then phi else pre(phi_hat)) - pre(phi_hat));
  phi_dot_hat = omega_imu;
  x_hat = if stance_est then x_body else pre(x_hat);
  z_hat = if stance_est then z_body else pre(z_hat);

  // Retain synchronized traces
  if i <= N_samples then
    trace_t[i] = time;
    trace_x[i] = x_body;
    trace_z[i] = z_body;
    trace_phi[i] = phi;
    trace_xf[i] = xf;
    trace_F_cmd[i] = F_cmd;
    trace_tau_cmd[i] = tau_cmd;
    trace_phi_hat[i] = phi_hat;
    trace_N[i] = N;
    trace_contact[i] = if contact then 1.0 else 0.0;
    trace_error[i] = e_track;
  end if;
end when;

  annotation(experiment(StopTime=8.0, Tolerance=1e-4));
end MonoHopRecoverA;