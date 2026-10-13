model QuadScoutDeliverD
  parameter Real m_body = 1.8 "kg, fuselage mass";
  parameter Real m_payload = 0.5 "kg, payload mass - not specified, assumed";
  parameter Real L_cable = 1.0 "m, cable length - not specified, assumed";
  parameter Real arm_len = 0.22 "m, rotor arm length";
  parameter Real g = 9.81 "m/s^2";
  parameter Real thrust_max = 12.0 "N, max thrust per rotor";
  parameter Real drag_coef = 0.1 "N*s/m, linear drag - not specified, assumed";
  parameter Real Ixx = 0.02 "kg*m^2 - not specified, assumed";
  parameter Real Iyy = 0.02 "kg*m^2 - not specified, assumed";
  parameter Real Izz = 0.04 "kg*m^2 - not specified, assumed";
  parameter Real Km_yaw = 0.01 "yaw moment coefficient - not specified, assumed";
  parameter Real cable_damp = 0.1 "cable damping - not specified, assumed";

  parameter Real z_init = 1.5 "m, initial body height - not specified, assumed";
  parameter Real z_cruise = 3.5 "m, cruise height - not specified, assumed";
  parameter Real z_final = 1.1 "m, final body height - not specified, assumed";
  parameter Real x_target = 5.0 "m, horizontal translation distance";
  parameter Real target_radius = 0.8 "m, target zone radius";
  parameter Real t_lift = 3.0 "s, lift phase end - not specified, assumed";
  parameter Real t_translate = 10.0 "s, translate phase end - not specified, assumed";
  parameter Real t_total = 14.0 "s, total mission time";
  parameter Real gust_force = 8.0 "N, gust disturbance";
  parameter Real Ts = 0.005 "s, 200 Hz control period";

  parameter Real Kp_x = 25.0 "not specified, assumed";
  parameter Real Kd_x = 10.0 "not specified, assumed";
  parameter Real Kp_z = 10.0 "not specified, assumed";
  parameter Real Kd_z = 8.0 "not specified, assumed";
  parameter Real Kp_phi = 30.0 "not specified, assumed";
  parameter Real Kd_p = 8.0 "not specified, assumed";
  parameter Real Kp_theta = 30.0 "not specified, assumed";
  parameter Real Kd_q = 8.0 "not specified, assumed";
  parameter Real Kp_psi = 10.0 "not specified, assumed";
  parameter Real Kd_r = 3.0 "not specified, assumed";
  parameter Real K_swing = 0.8 "cable swing damping gain - not specified, assumed";
  parameter Real omega_shape = 1.5 "rad/s, input shaping freq - not specified, assumed";
  parameter Real zeta_shape = 1.0 "input shaping damping - not specified, assumed";

  Real x(start=0, fixed=true) "m, body x position";
  Real y(start=0, fixed=true) "m, body y position";
  Real z(start=z_init, fixed=true) "m, body z position";
  Real vx(start=0, fixed=true) "m/s, body x velocity";
  Real vy(start=0, fixed=true) "m/s, body y velocity";
  Real vz(start=0, fixed=true) "m/s, body z velocity";
  Real phi(start=0, fixed=true) "rad, roll angle";
  Real theta(start=0, fixed=true) "rad, pitch angle";
  Real psi(start=0, fixed=true) "rad, yaw angle";
  Real p_ang(start=0, fixed=true) "rad/s, roll rate";
  Real q_ang(start=0, fixed=true) "rad/s, pitch rate";
  Real r_ang(start=0, fixed=true) "rad/s, yaw rate";

  Real alpha(start=0, fixed=true) "rad, cable angle x-z";
  Real beta(start=0, fixed=true) "rad, cable angle y-z";
  Real alpha_dot(start=0, fixed=true) "rad/s, cable rate x-z";
  Real beta_dot(start=0, fixed=true) "rad/s, cable rate y-z";

  Real x_shaped(start=0, fixed=true) "m, shaped x reference";
  Real x_shaped_dot(start=0, fixed=true) "m/s, shaped x rate";
  Real z_shaped(start=z_init, fixed=true) "m, shaped z reference";
  Real z_shaped_dot(start=0, fixed=true) "m/s, shaped z rate";

  Real px "m, payload x";
  Real py "m, payload y";
  Real pz "m, payload z";
  Real total_thrust "N, total rotor thrust";
  Real tension "N, cable tension";
  Real gust "N, gust disturbance";
  Real x_ref "m, x reference";
  Real z_ref "m, z reference";
  Real theta_cmd "rad, commanded pitch";
  Real phi_cmd "rad, commanded roll";
  Real tau_x_cmd "N*m, commanded roll moment";
  Real tau_y_cmd "N*m, commanded pitch moment";
  Real tau_z_cmd "N*m, commanded yaw moment";
  Real tau_x "N*m, actual roll moment";
  Real tau_y "N*m, actual pitch moment";
  Real tau_z "N*m, actual yaw moment";
  Real u1_cmd "N, rotor 1 command";
  Real u2_cmd "N, rotor 2 command";
  Real u3_cmd "N, rotor 3 command";
  Real u4_cmd "N, rotor 4 command";
  Real u1 "N, rotor 1 thrust";
  Real u2 "N, rotor 2 thrust";
  Real u3 "N, rotor 3 thrust";
  Real u4 "N, rotor 4 thrust";
  Real Fx_des "N, desired horizontal force";
  Real Fz_des "N, desired vertical force";
  Real T_des "N, desired total thrust";
  Real z_ddot "m/s^2, body z acceleration";
  Real x_ddot "m/s^2, body x acceleration";
  Real y_ddot "m/s^2, body y acceleration";
  Real alpha_ddot "rad/s^2, cable angular accel x-z";
  Real beta_ddot "rad/s^2, cable angular accel y-z";
  Real m_total "kg, total mass";

  Real x_gps "m, GPS x";
  Real y_gps "m, GPS y";
  Real z_gps "m, GPS z";
  Real vx_gps "m/s, GPS vx";
  Real vy_gps "m/s, GPS vy";
  Real vz_gps "m/s, GPS vz";
  Real phi_imu "rad, IMU roll";
  Real theta_imu "rad, IMU pitch";
  Real psi_imu "rad, IMU yaw";
  Real alpha_meas "rad, cable angle sensor x-z";
  Real beta_meas "rad, cable angle sensor y-z";
  Real tension_meas "N, tension sensor";

  Real tracking_error "m, position tracking error";
  Real swing_angle "rad, max cable swing";
  Real payload_h_dist "m, payload horizontal dist to target";
  Real payload_height "m, payload height above ground";
  Real payload_dist "m, payload 3D dist to target";
  Real max_rotor_thrust "N, max actual rotor thrust";

equation
  m_total = m_body + m_payload;

  // Trajectory reference: lift, translate, lower
  if time <= t_lift then
    z_ref = z_init + (z_cruise - z_init) * 0.5 * (1.0 - cos(Modelica.Constants.pi * time / t_lift));
    x_ref = 0.0;
  elseif time <= t_translate then
    z_ref = z_cruise;
    x_ref = x_target * 0.5 * (1.0 - cos(Modelica.Constants.pi * (time - t_lift) / (t_translate - t_lift)));
  else
    z_ref = z_cruise + (z_final - z_cruise) * 0.5 * (1.0 - cos(Modelica.Constants.pi * (time - t_translate) / (t_total - t_translate)));
    x_ref = x_target;
  end if;

  // Input shaping filter (second-order, critically damped)
  der(x_shaped) = x_shaped_dot;
  der(x_shaped_dot) = omega_shape * omega_shape * (x_ref - x_shaped) - 2.0 * zeta_shape * omega_shape * x_shaped_dot;
  der(z_shaped) = z_shaped_dot;
  der(z_shaped_dot) = omega_shape * omega_shape * (z_ref - z_shaped) - 2.0 * zeta_shape * omega_shape * z_shaped_dot;

  // Gust during middle third of mission
  if time >= t_total / 3.0 and time <= 2.0 * t_total / 3.0 then
    gust = gust_force;
  else
    gust = 0.0;
  end if;

  // Position control with cable-swing damping
  Fx_des = Kp_x * (x_shaped - x) - Kd_x * vx - K_swing * alpha_dot;
  Fz_des = Kp_z * (z_shaped - z) - Kd_z * vz + m_total * g;

  // Attitude commands from desired forces
  theta_cmd = Modelica.Math.atan2(Fx_des, max(Fz_des, 0.1));
  phi_cmd = -K_swing * beta_dot;

  // Attitude control
  tau_x_cmd = Kp_phi * (phi_cmd - phi) - Kd_p * p_ang;
  tau_y_cmd = Kp_theta * (theta_cmd - theta) - Kd_q * q_ang;
  tau_z_cmd = Kp_psi * (0.0 - psi) - Kd_r * r_ang;

  // Desired total thrust
  T_des = Fz_des / (cos(theta) * cos(phi) + 0.01);

  // Rotor mixing (plus configuration)
  u1_cmd = T_des / 4.0 - tau_y_cmd / (2.0 * arm_len) + tau_z_cmd / (4.0 * Km_yaw);
  u2_cmd = T_des / 4.0 - tau_x_cmd / (2.0 * arm_len) - tau_z_cmd / (4.0 * Km_yaw);
  u3_cmd = T_des / 4.0 + tau_y_cmd / (2.0 * arm_len) + tau_z_cmd / (4.0 * Km_yaw);
  u4_cmd = T_des / 4.0 + tau_x_cmd / (2.0 * arm_len) - tau_z_cmd / (4.0 * Km_yaw);

  // Thrust saturation [0, thrust_max] per rotor
  u1 = if u1_cmd < 0.0 then 0.0 elseif u1_cmd > thrust_max then thrust_max else u1_cmd;
  u2 = if u2_cmd < 0.0 then 0.0 elseif u2_cmd > thrust_max then thrust_max else u2_cmd;
  u3 = if u3_cmd < 0.0 then 0.0 elseif u3_cmd > thrust_max then thrust_max else u3_cmd;
  u4 = if u4_cmd < 0.0 then 0.0 elseif u4_cmd > thrust_max then thrust_max else u4_cmd;

  // Actual thrust and moments from saturated rotors
  total_thrust = u1 + u2 + u3 + u4;
  tau_x = arm_len * (u4 - u2);
  tau_y = arm_len * (u3 - u1);
  tau_z = Km_yaw * (u1 - u2 + u3 - u4);

  // Vertical dynamics: tension resolved analytically (no algebraic loop)
  z_ddot = (total_thrust * cos(theta) * cos(phi) - m_total * g - drag_coef * vz) / m_total;

  // Cable tension from payload vertical equilibrium
  tension = m_payload * (g + z_ddot) / (cos(alpha) * cos(beta) + 0.01);

  // Horizontal dynamics
  x_ddot = (total_thrust * sin(theta) + tension * sin(alpha) * cos(beta) - drag_coef * vx + gust) / m_body;
  y_ddot = (-total_thrust * sin(phi) + tension * sin(beta) - drag_coef * vy) / m_body;

  // Cable pendulum dynamics
  alpha_ddot = -(g / L_cable) * sin(alpha) - (x_ddot * cos(alpha)) / L_cable - cable_damp * alpha_dot;
  beta_ddot = -(g / L_cable) * sin(beta) - (y_ddot * cos(beta)) / L_cable - cable_damp * beta_dot;

  // State integration
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  der(vx) = x_ddot;
  der(vy) = y_ddot;
  der(vz) = z_ddot;

  der(phi) = p_ang;
  der(theta) = q_ang;
  der(psi) = r_ang;
  der(p_ang) = tau_x / Ixx;
  der(q_ang) = tau_y / Iyy;
  der(r_ang) = tau_z / Izz;

  der(alpha) = alpha_dot;
  der(beta) = beta_dot;
  der(alpha_dot) = alpha_ddot;
  der(beta_dot) = beta_ddot;

  // Payload position
  px = x + L_cable * sin(alpha) * cos(beta);
  py = y + L_cable * sin(beta);
  pz = z - L_cable * cos(alpha) * cos(beta);

  // Sensors (ideal; noise parameters not specified)
  x_gps = x;
  y_gps = y;
  z_gps = z;
  vx_gps = vx;
  vy_gps = vy;
  vz_gps = vz;
  phi_imu = phi;
  theta_imu = theta;
  psi_imu = psi;
  alpha_meas = alpha;
  beta_meas = beta;
  tension_meas = tension;

  // Performance metrics
  tracking_error = sqrt((x - x_shaped) * (x - x_shaped) + (z - z_shaped) * (z - z_shaped));
  swing_angle = if abs(alpha) > abs(beta) then abs(alpha) else abs(beta);
  payload_h_dist = sqrt((px - x_target) * (px - x_target) + py * py);
  payload_height = pz;
  payload_dist = sqrt((px - x_target) * (px - x_target) + py * py + pz * pz);
  max_rotor_thrust = if u1 > u2 then (if u1 > u3 then (if u1 > u4 then u1 else u4) else (if u3 > u4 then u3 else u4)) else (if u2 > u3 then (if u2 > u4 then u2 else u4) else (if u3 > u4 then u3 else u4));

  annotation(experiment(StopTime = 14.0, Interval = 0.005, Tolerance = 1e-6));
end QuadScoutDeliverD;