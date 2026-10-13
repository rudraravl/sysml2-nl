model CartesianToolPushE
  // Physical parameters (SI units)
  parameter Real m_tool = 2.5 "kg, specified tool carriage mass";
  parameter Real m_box = 1.3 "kg, object mass not specified; chosen to close the model";
  parameter Real I_box = 0.001 "kg.m2, object inertia not specified; chosen to close the model";
  parameter Real L_box = 0.04 "m, object length not specified; chosen to close the model";
  parameter Real h_box = 0.05 "m, object height not specified; chosen to close the model";
  parameter Real g = 9.81 "m/s2";
  parameter Real mu_table = 0.42 "box-table friction coefficient";
  parameter Real mu_toolbox = 0.65 "tool-box friction coefficient";
  parameter Real k_c = 8000 "N/m, contact stiffness not specified; chosen to close the model";
  parameter Real d_c = 50 "N.s/m, contact damping not specified; chosen to close the model";
  parameter Real x_stroke = 0.10 "m";
  parameter Real y_stroke = 0.10 "m";
  parameter Real z_stroke = 0.30 "m";
  parameter Real F_act_max = 385 "N per axis";
  parameter Real F_contact_min = 5.1 "N";
  parameter Real F_contact_max = 24.0 "N";
  parameter Real v_eps_friction = 1.0e-4 "m/s";
  parameter Real v_eps_tangential = 0.01 "m/s";
  parameter Real Ts = 0.004 "s, 250 Hz control and trace period";
  parameter Real pi = 3.141592653589793;
  parameter Real x0 = 0 "m";
  parameter Real y0 = 0 "m";
  parameter Real theta0 = 0 "rad";
  parameter Real x_ref1 = 0.05 "m, first segment end";
  parameter Real x_ref2 = 0.08 "m, second segment end";
  parameter Real z_ref = h_box/2 "m";

  // Control gains
  parameter Real Kp_tool = 10000 "N/m";
  parameter Real Kd_tool = 400 "N.s/m";
  parameter Real Kp_pos = 800 "N/m";
  parameter Real Kd_pos = 200 "N.s/m";
  parameter Real Kp_y = 4000 "N/m";
  parameter Real Kd_y = 200 "N.s/m";
  parameter Real Kp_z = 4000 "N/m";
  parameter Real Kd_z = 200 "N.s/m";

  // Tool carriage states
  Real x_t(start = x0 - L_box/2 + F_contact_min/k_c) "m";
  Real y_t(start = y0) "m";
  Real z_t(start = z_ref) "m";
  Real vx_t(start = 0) "m/s";
  Real vy_t(start = 0) "m/s";
  Real vz_t(start = 0) "m/s";

  // Object planar states
  Real x_box(start = x0) "m";
  Real y_box(start = y0) "m";
  Real theta_box(start = theta0) "rad";
  Real vx_box(start = 0) "m/s";
  Real vy_box(start = 0) "m/s";
  Real omega_box(start = 0) "rad/s";

  // Contact and friction
  Real p "m, normal penetration";
  Real F_n "N, measured normal contact force";
  Real F_ty "N, tool-box tangential friction on box in y";
  Real F_tz_tool "N, tool-box tangential friction on tool in z";
  Real F_table_x "N";
  Real F_table_y "N";
  Real F_dist_x "N, controlled middle-third friction change";
  Real tau_yaw "N.m";
  Boolean disturbanceActive;

  // Reference
  Real x_ref "m";
  Real vx_ref "m/s";
  Real y_ref = 0 "m";
  Real theta_ref = 0 "rad";
  Real primaryTrackingError "m";
  Real F_ff "N, feedforward resistance";

  // Estimator value
  Real estimatorFriction "N, estimated resistive friction";

  // Discrete control commands
  Real F_n_ref(start = F_contact_min) "N";
  Real F_n_ref_raw(start = F_contact_min) "N";
  Real p_des(start = F_contact_min/k_c) "m";
  Real Fx_cmd_raw(start = F_contact_min) "N";
  Real Fy_cmd_raw(start = 0) "N";
  Real Fz_cmd_raw(start = m_tool*g) "N";
  Real Fx_cmd(start = F_contact_min) "N";
  Real Fy_cmd(start = 0) "N";
  Real Fz_cmd(start = m_tool*g) "N";

  // Synchronized 250 Hz traces
  output Real sampleTime(start = 0) "s";
  output Real sampleXbox(start = x0) "m";
  output Real sampleYbox(start = y0) "m";
  output Real sampleTheta(start = theta0) "rad";
  output Real sampleVxbox(start = 0) "m/s";
  output Real sampleXtool(start = x0 - L_box/2 + F_contact_min/k_c) "m";
  output Real sampleContactForce(start = F_contact_min) "N";
  output Real sampleFxcmd(start = F_contact_min) "N";
  output Real sampleFycmd(start = 0) "N";
  output Real sampleFzcmd(start = m_tool*g) "N";
  output Real sampleTrackingError(start = 0) "m";
  output Real sampleEstimatorFriction(start = 0) "N";
  Integer sampleIndex(start = 0);

equation
  // Two-segment smooth planar reference along X
  if time <= 8 then
    x_ref = x_ref1*0.5*(1 - cos(pi*time/8));
    vx_ref = x_ref1*0.5*(pi/8)*sin(pi*time/8);
  else
    x_ref = x_ref1 + (x_ref2 - x_ref1)*0.5*(1 - cos(pi*(time - 8)/8));
    vx_ref = (x_ref2 - x_ref1)*0.5*(pi/8)*sin(pi*(time - 8)/8);
  end if;

  disturbanceActive = time >= 16/3 and time <= 32/3;

  // Normal contact between tool and left face of box
  p = x_t - (x_box - L_box/2);
  if p > 0 then
    F_n = k_c*p + d_c*(vx_t - vx_box);
  else
    F_n = 0.0;
  end if;

  // Tool-box tangential friction
  F_ty = mu_toolbox*F_n*tanh((vy_t - vy_box)/v_eps_tangential);
  F_tz_tool = -mu_toolbox*F_n*tanh(vz_t/v_eps_tangential);

  // Table friction and controlled disturbance
  F_table_x = mu_table*m_box*g*tanh(vx_box/v_eps_friction);
  F_table_y = mu_table*m_box*g*tanh(vy_box/v_eps_friction);
  F_dist_x = if disturbanceActive then 7.2*tanh(vx_box/v_eps_friction) else 0.0;

  // Plant dynamics
  der(x_t) = vx_t;
  der(y_t) = vy_t;
  der(z_t) = vz_t;
  der(vx_t) = (Fx_cmd - F_n)/m_tool;
  der(vy_t) = (Fy_cmd - F_ty)/m_tool;
  der(vz_t) = (Fz_cmd - m_tool*g + F_tz_tool)/m_tool;

  der(x_box) = vx_box;
  der(y_box) = vy_box;
  der(theta_box) = omega_box;
  der(vx_box) = (F_n - F_table_x - F_dist_x)/m_box;
  der(vy_box) = (F_ty - F_table_y)/m_box;
  tau_yaw = 0.0;
  der(omega_box) = tau_yaw/I_box;

  // Feedforward resistance estimate
  F_ff = mu_table*m_box*g*tanh(vx_ref/v_eps_friction) +
         (if disturbanceActive then 7.2*tanh(vx_ref/v_eps_friction) else 0.0);

  // Estimator value
  estimatorFriction = F_table_x + F_dist_x;

  primaryTrackingError = sqrt((x_box - x_ref)^2 + (y_box - y_ref)^2);

  // 250 Hz hybrid position-force controller and synchronized traces
  when sample(0, Ts) then
    F_n_ref_raw = F_ff + Kp_pos*(x_ref - x_box) + Kd_pos*(vx_ref - vx_box);
    F_n_ref = max(F_contact_min, min(F_contact_max, F_n_ref_raw));
    p_des = F_n_ref/k_c;

    Fx_cmd_raw = Kp_tool*(p_des - p) - Kd_tool*(vx_t - vx_box) + F_n;
    Fy_cmd_raw = Kp_y*(y_box - y_t) + Kd_y*(vy_box - vy_t);
    Fz_cmd_raw = m_tool*g + Kp_z*(z_ref - z_t) - Kd_z*vz_t;

    Fx_cmd = max(-F_act_max, min(F_act_max, Fx_cmd_raw));
    Fy_cmd = max(-F_act_max, min(F_act_max, Fy_cmd_raw));
    Fz_cmd = max(-F_act_max, min(F_act_max, Fz_cmd_raw));

    sampleIndex = pre(sampleIndex) + 1;
    sampleTime = time;
    sampleXbox = x_box;
    sampleYbox = y_box;
    sampleTheta = theta_box;
    sampleVxbox = vx_box;
    sampleXtool = x_t;
    sampleContactForce = F_n;
    sampleFxcmd = Fx_cmd;
    sampleFycmd = Fy_cmd;
    sampleFzcmd = Fz_cmd;
    sampleTrackingError = primaryTrackingError;
    sampleEstimatorFriction = estimatorFriction;
  end when;

  // Fail-closed acceptance assertions
  assert(abs(Fx_cmd) <= F_act_max + 1.0e-6, "X actuator command bound violated");
  assert(abs(Fy_cmd) <= F_act_max + 1.0e-6, "Y actuator command bound violated");
  assert(abs(Fz_cmd) <= F_act_max + 1.0e-6, "Z actuator command bound violated");

  assert(abs(x_t) <= x_stroke + 1.0e-6, "X stroke bound violated");
  assert(abs(y_t) <= y_stroke + 1.0e-6, "Y stroke bound violated");
  assert(abs(z_t) <= z_stroke + 1.0e-6, "Z stroke bound violated");

  assert(F_n >= 5.0 - 1.0e-6 and F_n <= 25.0 + 1.0e-6, "contact force out of acceptance range");

  assert(abs(theta_box) <= pi + 1.0e-6, "object yaw out of range");

  if time >= 10.4 then
    assert(primaryTrackingError <= 0.036 + 1.0e-9, "primary tracking error after 10.4 s violated");
  end if;

  assert(x_t == x_t and abs(x_t) < 1.0e30, "x_t non-finite");
  assert(y_t == y_t and abs(y_t) < 1.0e30, "y_t non-finite");
  assert(z_t == z_t and abs(z_t) < 1.0e30, "z_t non-finite");
  assert(vx_t == vx_t and abs(vx_t) < 1.0e30, "vx_t non-finite");
  assert(vy_t == vy_t and abs(vy_t) < 1.0e30, "vy_t non-finite");
  assert(vz_t == vz_t and abs(vz_t) < 1.0e30, "vz_t non-finite");
  assert(x_box == x_box and abs(x_box) < 1.0e30, "x_box non-finite");
  assert(y_box == y_box and abs(y_box) < 1.0e30, "y_box non-finite");
  assert(theta_box == theta_box and abs(theta_box) < 1.0e30, "theta_box non-finite");
  assert(vx_box == vx_box and abs(vx_box) < 1.0e30, "vx_box non-finite");
  assert(vy_box == vy_box and abs(vy_box) < 1.0e30, "vy_box non-finite");
  assert(omega_box == omega_box and abs(omega_box) < 1.0e30, "omega_box non-finite");
  assert(F_n == F_n and abs(F_n) < 1.0e30, "F_n non-finite");
  assert(Fx_cmd == Fx_cmd and abs(Fx_cmd) < 1.0e30, "Fx_cmd non-finite");
  assert(Fy_cmd == Fy_cmd and abs(Fy_cmd) < 1.0e30, "Fy_cmd non-finite");
  assert(Fz_cmd == Fz_cmd and abs(Fz_cmd) < 1.0e30, "Fz_cmd non-finite");
  assert(primaryTrackingError == primaryTrackingError and primaryTrackingError < 1.0e30, "primaryTrackingError non-finite");
  assert(estimatorFriction == estimatorFriction and abs(estimatorFriction) < 1.0e30, "estimatorFriction non-finite");

  when terminal() then
    assert(abs(x_box - x_ref2) <= 0.036 + 1.0e-9, "final object x pose violated");
    assert(abs(y_box - y_ref) <= 0.036 + 1.0e-9, "final object y pose violated");
    assert(abs(theta_box - theta_ref) <= 0.1 + 1.0e-9, "final object yaw violated");
  end when;

  annotation(experiment(StopTime = 16, Tolerance = 1.0e-6));
end CartesianToolPushE;