model HexaSurveyDeliverE
  import SI = Modelica.SIunits;
  import PI = Modelica.Constants.PI;

  constant Real Ts(unit="s") = 0.004 "250 Hz control and trace period";
  constant SI.Acceleration g = 9.81;

  // Known physical parameters from the requirement
  parameter SI.Mass m_fus = 3.2 "cylindrical fuselage mass";
  parameter SI.Mass m_cam = 0.4 "downward camera payload mass";
  parameter SI.Mass m_total = m_fus + m_cam;
  parameter SI.Length R_rotor = 0.35 "rotor radius";
  parameter SI.Force T_max = 12.1 "per-rotor command bound";
  parameter SI.Length target_radius = 0.8 "target-zone radius";
  parameter SI.Position x_target = 5.0 "horizontal translation";
  parameter SI.Length z_payload_place = 0.1 "selected finite placement height threshold";
  parameter SI.Length z_ground_payload = 0.0 "no ground-strike threshold for payload";
  parameter SI.Length z_ground_fuselage = 0.2 "no ground-strike threshold for fuselage";

  // Facts not stated are treated as unknown; these are finite, non-singular scenario values only.
  parameter SI.Length L_cable = 1.0 "cable length not specified; finite scenario value";
  parameter Real c_drag(unit="N.s/m") = 0.5 "drag coefficient not specified; finite nominal";
  parameter SI.Inertia J_pitch = m_fus*R_rotor*R_rotor "cylinder inertia not specified; nominal from known mass and rotor radius";
  parameter Real b_pitch(unit="N.m.s/rad") = 0.5 "pitch damping not specified; finite nominal";
  parameter SI.Force T_cable_max = 6.0*T_max "derived tension bound from rotor-thrust bound";

  // Six equally spaced rotor arms
  parameter SI.Length x1 = R_rotor "rotor 1, 0 deg";
  parameter SI.Length x2 = 0.5*R_rotor "rotor 2, 60 deg";
  parameter SI.Length x3 = -0.5*R_rotor "rotor 3, 120 deg";
  parameter SI.Length x4 = -R_rotor "rotor 4, 180 deg";
  parameter SI.Length x5 = -0.5*R_rotor "rotor 5, 240 deg";
  parameter SI.Length x6 = 0.5*R_rotor "rotor 6, 300 deg";
  parameter SI.Length y1 = 0.0;
  parameter SI.Length y2 = 0.5*sqrt(3.0)*R_rotor;
  parameter SI.Length y3 = 0.5*sqrt(3.0)*R_rotor;
  parameter SI.Length y4 = 0.0;
  parameter SI.Length y5 = -0.5*sqrt(3.0)*R_rotor;
  parameter SI.Length y6 = -0.5*sqrt(3.0)*R_rotor;
  parameter Real sum_x2(unit="m2") = x1*x1 + x2*x2 + x3*x3 + x4*x4 + x5*x5 + x6*x6;
  parameter Real Dden(unit="kg2") = m_fus*m_total;

  // Control gains
  parameter Real Kp_x(unit="1/s2") = 15.0;
  parameter Real Kd_x(unit="1/s") = 16.0;
  parameter Real Kp_z(unit="1/s2") = 15.0;
  parameter Real Kd_z(unit="1/s") = 16.0;
  parameter Real K_swing_d(unit="1/s") = 4.0;
  parameter Real Kp_phi(unit="N.m/rad") = 100.0;
  parameter Real Kd_phi(unit="N.m.s/rad") = 25.0;
  parameter SI.Torque M_limit = 4.0;
  parameter SI.Angle phi_limit = 0.6;

  // Physical states
  SI.Position x;
  SI.Velocity vx;
  SI.Position z;
  SI.Velocity vz;
  SI.Angle phi;
  SI.AngularVelocity omega;
  SI.Angle theta;
  SI.AngularVelocity theta_dot;
  Real theta_ddot(unit="rad/s2");

  // Algebraic physical variables
  SI.Acceleration ax_f;
  SI.Acceleration az_f;
  SI.Force T_cable;
  SI.Force T_total_actual;
  SI.Torque M_actual;
  SI.Torque M_roll;
  SI.Force F_gust;
  SI.Force A_f;
  SI.Force B_f;
  Real C_t(unit="N");
  Real s_theta;
  Real c_theta;
  SI.Position x_payload;
  SI.Position z_payload;
  Real tracking_error(unit="m");
  Real target_radius_error(unit="m");

  // Rotor-thrust channels and commands
  discrete SI.Force T1(start=5.886);
  discrete SI.Force T2(start=5.886);
  discrete SI.Force T3(start=5.886);
  discrete SI.Force T4(start=5.886);
  discrete SI.Force T5(start=5.886);
  discrete SI.Force T6(start=5.886);
  discrete SI.Force cmd_T_total(start=35.316);
  discrete SI.Torque cmd_M(start=0.0);
  discrete SI.Angle cmd_phi(start=0.0);
  discrete SI.Acceleration ax_cmd(start=0.0);
  discrete SI.Acceleration az_cmd(start=0.0);

  // Reference trajectory
  discrete SI.Position x_des(start=0.0);
  discrete SI.Velocity vx_des(start=0.0);
  discrete SI.Acceleration ax_traj(start=0.0);
  discrete SI.Position z_des(start=1.2);
  discrete SI.Velocity vz_des(start=0.0);
  discrete SI.Acceleration az_traj(start=0.0);

  // Sensors and estimator traces
  discrete SI.Position sensor_x(start=0.0);
  discrete SI.Position sensor_z(start=1.2);
  discrete SI.Velocity sensor_vx(start=0.0);
  discrete SI.Velocity sensor_vz(start=0.0);
  discrete SI.Angle sensor_phi(start=0.0);
  discrete SI.AngularVelocity sensor_omega(start=0.0);
  discrete SI.Acceleration sensor_ax(start=0.0);
  discrete SI.Acceleration sensor_az(start=0.0);
  discrete SI.Angle sensor_theta(start=0.0);
  discrete SI.AngularVelocity sensor_theta_dot(start=0.0);
  discrete SI.Force sensor_tension(start=3.924);
  discrete SI.Position est_x(start=0.0);
  discrete SI.Position est_z(start=1.2);
  discrete SI.Velocity est_vx(start=0.0);
  discrete SI.Velocity est_vz(start=0.0);
  discrete SI.Angle est_phi(start=0.0);
  discrete SI.AngularVelocity est_omega(start=0.0);
  discrete SI.Acceleration est_ax(start=0.0);
  discrete SI.Acceleration est_az(start=0.0);
  discrete SI.Angle est_theta(start=0.0);
  discrete SI.AngularVelocity est_theta_dot(start=0.0);
  discrete SI.Force est_tension(start=3.924);

  // Synchronized traces
  discrete SI.Time sync_time(start=0.0);
  discrete SI.Position state_x_sync(start=0.0);
  discrete SI.Position state_z_sync(start=1.2);
  discrete SI.Angle state_theta_sync(start=0.0);

initial equation
  x = 0.0;
  vx = 0.0;
  z = 1.2;
  vz = 0.0;
  phi = 0.0;
  omega = 0.0;
  theta = 0.0;
  theta_dot = 0.0;

equation
  der(x) = vx;
  der(z) = vz;
  der(phi) = omega;
  der(theta) = theta_dot;
  der(theta_dot) = theta_ddot;
  der(vx) = ax_f;
  der(vz) = az_f;
  J_pitch*der(omega) = M_actual - b_pitch*omega;

  s_theta = sin(theta);
  c_theta = cos(theta);

  F_gust = if time >= 16.0/3.0 and time <= 32.0/3.0 then 9.6 else 0.0;

  T_total_actual = T1 + T2 + T3 + T4 + T5 + T6;
  M_actual = T1*x1 + T2*x2 + T3*x3 + T4*x4 + T5*x5 + T6*x6;
  M_roll = T1*y1 + T2*y2 + T3*y3 + T4*y4 + T5*y5 + T6*y6;

  A_f = T_total_actual*sin(phi) - c_drag*vx + F_gust;
  B_f = T_total_actual*cos(phi) - m_fus*g - c_drag*vz;
  C_t = m_cam*g*c_theta + m_cam*L_cable*theta_dot*theta_dot;

  ax_f = ((A_f + C_t*s_theta)*(m_fus + m_cam*c_theta*c_theta) + (B_f - C_t*c_theta)*(m_cam*s_theta*c_theta))/Dden;
  az_f = ((m_fus + m_cam*s_theta*s_theta)*(B_f - C_t*c_theta) + (m_cam*s_theta*c_theta)*(A_f + C_t*s_theta))/Dden;
  T_cable = C_t + m_cam*az_f*c_theta - m_cam*ax_f*s_theta;
  theta_ddot = -(ax_f*c_theta + az_f*s_theta + g*s_theta)/L_cable;

  x_payload = x + L_cable*sin(theta);
  z_payload = z - L_cable*cos(theta);

  tracking_error = sqrt((x - x_des)*(x - x_des) + (z - z_des)*(z - z_des));
  target_radius_error = abs(x_payload - x_target);

  assert(T1 >= 0.0 and T1 <= T_max and
         T2 >= 0.0 and T2 <= T_max and
         T3 >= 0.0 and T3 <= T_max and
         T4 >= 0.0 and T4 <= T_max and
         T5 >= 0.0 and T5 <= T_max and
         T6 >= 0.0 and T6 <= T_max, "rotor thrust bound failed");
  assert(T_cable >= 0.0 and T_cable <= T_cable_max, "cable tension bound failed");
  assert(abs(theta) <= 0.45, "swing bound failed");
  assert(z >= z_ground_fuselage and z_payload >= z_ground_payload, "ground strike failed");
  assert(time < 10.4 or tracking_error <= 0.27, "primary tracking error bound failed after 10.4 s");
  assert(time < 15.0 or (target_radius_error <= target_radius and z_payload <= z_payload_place), "target-zone placement failed");
  assert(abs(x) < 1e12 and abs(vx) < 1e12 and abs(z) < 1e12 and abs(vz) < 1e12 and
         abs(phi) < 1e12 and abs(omega) < 1e12 and abs(theta) < 1e12 and abs(theta_dot) < 1e12 and
         abs(T_cable) < 1e12 and abs(T_total_actual) < 1e12 and abs(M_actual) < 1e12 and abs(M_roll) < 1e12,
         "nonfinite physical value");
  assert(abs(est_x) < 1e12 and abs(est_z) < 1e12 and abs(est_vx) < 1e12 and abs(est_vz) < 1e12 and
         abs(est_phi) < 1e12 and abs(est_omega) < 1e12 and abs(est_theta) < 1e12 and abs(est_theta_dot) < 1e12 and
         abs(est_ax) < 1e12 and abs(est_az) < 1e12 and abs(est_tension) < 1e12 and
         abs(cmd_phi) < 1e12 and abs(cmd_T_total) < 1e12 and abs(cmd_M) < 1e12 and
         abs(ax_cmd) < 1e12 and abs(az_cmd) < 1e12 and
         abs(T1) < 1e12 and abs(T2) < 1e12 and abs(T3) < 1e12 and abs(T4) < 1e12 and abs(T5) < 1e12 and abs(T6) < 1e12,
         "nonfinite estimator or control value");

  when sample(0, Ts) then
    // IMU, GPS, cable-angle, and tension sensors
    sensor_x = x;
    sensor_z = z;
    sensor_vx = vx;
    sensor_vz = vz;
    sensor_phi = phi;
    sensor_omega = omega;
    sensor_ax = ax_f;
    sensor_az = az_f;
    sensor_theta = theta;
    sensor_theta_dot = theta_dot;
    sensor_tension = T_cable;

    // Ideal estimator from synchronized sensors
    est_x = sensor_x;
    est_z = sensor_z;
    est_vx = sensor_vx;
    est_vz = sensor_vz;
    est_phi = sensor_phi;
    est_omega = sensor_omega;
    est_ax = sensor_ax;
    est_az = sensor_az;
    est_theta = sensor_theta;
    est_theta_dot = sensor_theta_dot;
    est_tension = sensor_tension;

    // Input-shaped position reference
    x_des = if time < 2.0 then 0.0 elseif time < 10.0 then 2.5*(1.0 - cos(PI*(time - 2.0)/8.0)) else x_target;
    vx_des = if time < 2.0 then 0.0 elseif time < 10.0 then 5.0*PI/16.0*sin(PI*(time - 2.0)/8.0) else 0.0;
    ax_traj = if time < 2.0 then 0.0 elseif time < 10.0 then 5.0*PI*PI/64.0*cos(PI*(time - 2.0)/8.0) else 0.0;
    z_des = if time < 2.0 then 1.2 + 0.15*(1.0 - cos(PI*time/2.0)) elseif time < 10.0 then 1.5 elseif time < 14.0 then 1.5 - 0.225*(1.0 - cos(PI*(time - 10.0)/4.0)) else 1.05;
    vz_des = if time < 2.0 then 0.15*PI/2.0*sin(PI*time/2.0) elseif time < 10.0 then 0.0 elseif time < 14.0 then -0.225*PI/4.0*sin(PI*(time - 10.0)/4.0) else 0.0;
    az_traj = if time < 2.0 then 0.15*PI*PI/4.0*cos(PI*time/2.0) elseif time < 10.0 then 0.0 elseif time < 14.0 then -0.225*PI*PI/16.0*cos(PI*(time - 10.0)/4.0) else 0.0;

    // Input-shaped position control with cable-swing damping
    ax_cmd = ax_traj + c_drag*est_vx/m_total + Kp_x*(x_des - est_x) + Kd_x*(vx_des - est_vx) + L_cable*K_swing_d*est_theta_dot;
    az_cmd = az_traj + c_drag*est_vz/m_total + Kp_z*(z_des - est_z) + Kd_z*(vz_des - est_vz);
    cmd_phi = max(-phi_limit, min(phi_limit, Modelica.Math.atan2(ax_cmd, g + az_cmd)));
    cmd_T_total = m_total*sqrt((g + az_cmd)*(g + az_cmd) + ax_cmd*ax_cmd);
    cmd_M = max(-M_limit, min(M_limit, Kp_phi*(cmd_phi - est_phi) - Kd_phi*est_omega));

    // Six bounded rotor-thrust channels allocated from total thrust and pitch moment
    T1 = max(0.0, min(T_max, cmd_T_total/6.0 + cmd_M*x1/sum_x2));
    T2 = max(0.0, min(T_max, cmd_T_total/6.0 + cmd_M*x2/sum_x2));
    T3 = max(0.0, min(T_max, cmd_T_total/6.0 + cmd_M*x3/sum_x2));
    T4 = max(0.0, min(T_max, cmd_T_total/6.0 + cmd_M*x4/sum_x2));
    T5 = max(0.0, min(T_max, cmd_T_total/6.0 + cmd_M*x5/sum_x2));
    T6 = max(0.0, min(T_max, cmd_T_total/6.0 + cmd_M*x6/sum_x2));

    // Synchronized state, command, and sensor traces
    sync_time = time;
    state_x_sync = x;
    state_z_sync = z;
    state_theta_sync = theta;
  end when;

  annotation(experiment(StopTime=16.0, Interval=0.004, Tolerance=1e-6));
end HexaSurveyDeliverE;