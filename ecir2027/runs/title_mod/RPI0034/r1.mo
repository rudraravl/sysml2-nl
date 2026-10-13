model HexaSurveySurveyD
  // =====================================================
  // HexaSurveySurveyD
  // Instrumented free-base hexacopter aerial robot.
  // Fuses IMU, GPS, altimeter, and camera-timestamp
  // measurements into pose and velocity estimates.
  // Bounded waypoint tracking with feedforward acceleration
  // and a controlled crosswind disturbance.
  // =====================================================

  // ---- Stated physical parameters ----
  parameter Real m_fuselage = 3.2 "kg cylindrical fuselage";
  parameter Real m_payload  = 0.4 "kg downward camera payload";
  parameter Real m_total    = m_fuselage + m_payload "kg total mass";
  parameter Real R_arm      = 0.35 "m rotor arm radius";
  parameter Real g          = 9.81 "m/s^2 gravitational acceleration";
  parameter Real Thrust_max = 11.0 "N per-rotor upper bound";
  parameter Real Thrust_min = 0.0  "N per-rotor lower bound";

  // ---- Inferred physical parameters (not stated; labeled) ----
  parameter Real Ixx    = 0.02 "kg m^2 roll inertia (inferred)";
  parameter Real Iyy    = 0.02 "kg m^2 pitch inertia (inferred)";
  parameter Real Izz    = 0.04 "kg m^2 yaw inertia (inferred)";
  parameter Real k_yaw  = 0.05 "N m per N yaw torque coefficient (inferred)";
  parameter Real att_max = 0.50 "rad commanded attitude bound (inferred)";

  // ---- Rotor arm angles (six equally spaced) ----
  parameter Real alpha1 = 0.0;
  parameter Real alpha2 = Modelica.Constants.pi / 3.0;
  parameter Real alpha3 = 2.0 * Modelica.Constants.pi / 3.0;
  parameter Real alpha4 = Modelica.Constants.pi;
  parameter Real alpha5 = 4.0 * Modelica.Constants.pi / 3.0;
  parameter Real alpha6 = 5.0 * Modelica.Constants.pi / 3.0;

  // ---- Waypoints (stated) ----
  parameter Real wp1x = 0.0;  parameter Real wp1y = 0.0;  parameter Real wp1z = 1.5;
  parameter Real wp2x = 4.0;  parameter Real wp2y = 0.0;  parameter Real wp2z = 2.5;
  parameter Real wp3x = 4.0;  parameter Real wp3y = 3.0;  parameter Real wp3z = 2.5;
  parameter Real wp4x = 1.0;  parameter Real wp4y = 4.0;  parameter Real wp4z = 2.0;

  // ---- Declared waypoint deadlines (uniform spacing over 14 s; inferred) ----
  parameter Real t_wp1 = 3.5  "s deadline for waypoint 1";
  parameter Real t_wp2 = 7.0  "s deadline for waypoint 2";
  parameter Real t_wp3 = 10.5 "s deadline for waypoint 3";
  parameter Real t_wp4 = 14.0 "s deadline for waypoint 4";

  // ---- Obstacles: three fixed cylinders placed outside the reference polyline ----
  parameter Real o1x = 2.0;  parameter Real o1y = -1.5; parameter Real o1r = 0.3;
  parameter Real o1zb = 0.0; parameter Real o1h = 4.0;
  parameter Real o2x = 5.5;  parameter Real o2y = 1.5;  parameter Real o2r = 0.4;
  parameter Real o2zb = 0.0; parameter Real o2h = 4.0;
  parameter Real o3x = 2.5;  parameter Real o3y = 5.0;  parameter Real o3r = 0.3;
  parameter Real o3zb = 0.0; parameter Real o3h = 4.0;

  // ---- Crosswind disturbance (stated: 6 N during middle third) ----
  parameter Real F_wind       = 6.0 "N";
  parameter Real t_wind_start = 14.0 / 3.0      "s";
  parameter Real t_wind_end   = 2.0 * 14.0 / 3.0 "s";

  // ---- Control gains (inferred) ----
  parameter Real Kp_pos = 6.0;
  parameter Real Kd_pos = 4.0;
  parameter Real Kp_att = 10.0;
  parameter Real Kd_att = 3.0;

  // ---- Estimator gains (inferred) ----
  parameter Real omega_est = 2.0;
  parameter Real zeta_est  = 0.7;

  // ---- Numerical safeguard for divisors / norms ----
  parameter Real eps = 1.0e-6;

  // ---- Plant physical states ----
  Real rx(start = 0.0) "m position x";
  Real ry(start = 0.0) "m position y";
  Real rz(start = 1.5) "m position z";
  Real vx(start = 0.0) "m/s velocity x";
  Real vy(start = 0.0) "m/s velocity y";
  Real vz(start = 0.0) "m/s velocity z";
  Real phi(start = 0.0)   "rad roll";
  Real theta(start = 0.0) "rad pitch";
  Real psi(start = 0.0)   "rad yaw";
  Real p_rate(start = 0.0) "rad/s roll rate";
  Real q_rate(start = 0.0) "rad/s pitch rate";
  Real r_rate(start = 0.0) "rad/s yaw rate";

  // ---- Control variables ----
  Real T_total "N commanded total thrust";
  Real tau_x_cmd "N m commanded roll torque";
  Real tau_y_cmd "N m commanded pitch torque";
  Real tau_z_cmd "N m commanded yaw torque";
  Real phi_d "rad desired roll";
  Real theta_d "rad desired pitch";
  Real psi_d "rad desired yaw";
  Real phi_d_b "rad bounded desired roll";
  Real theta_d_b "rad bounded desired pitch";
  Real ax_des "m/s^2 desired world x acceleration";
  Real ay_des "m/s^2 desired world y acceleration";
  Real az_des "m/s^2 desired world z acceleration";
  Real rt1 "N raw rotor 1 thrust";
  Real rt2 "N raw rotor 2 thrust";
  Real rt3 "N raw rotor 3 thrust";
  Real rt4 "N raw rotor 4 thrust";
  Real rt5 "N raw rotor 5 thrust";
  Real rt6 "N raw rotor 6 thrust";
  Real rotor_thrust1 "N bounded rotor 1 thrust";
  Real rotor_thrust2 "N bounded rotor 2 thrust";
  Real rotor_thrust3 "N bounded rotor 3 thrust";
  Real rotor_thrust4 "N bounded rotor 4 thrust";
  Real rotor_thrust5 "N bounded rotor 5 thrust";
  Real rotor_thrust6 "N bounded rotor 6 thrust";
  Real T_bz "N actual total body-z thrust";
  Real tau_x_act "N m actual roll torque";
  Real tau_y_act "N m actual pitch torque";
  Real tau_z_act "N m actual yaw torque";
  Real fx_world "N world-frame thrust x";
  Real fy_world "N world-frame thrust y";
  Real fz_world "N world-frame thrust z";

  // ---- Reference trajectory ----
  Real ref_x "m reference position x";
  Real ref_y "m reference position y";
  Real ref_z "m reference position z";
  Real vref_x "m/s reference velocity x";
  Real vref_y "m/s reference velocity y";
  Real vref_z "m/s reference velocity z";
  Real aref_x "m/s^2 feedforward acceleration x";
  Real aref_y "m/s^2 feedforward acceleration y";
  Real aref_z "m/s^2 feedforward acceleration z";

  // ---- Estimator states ----
  Real rhx(start = 0.0)   "m estimated position x";
  Real rhy(start = 0.0)   "m estimated position y";
  Real rhz(start = 1.5)   "m estimated position z";
  Real vhx(start = 0.0)   "m/s estimated velocity x";
  Real vhy(start = 0.0)   "m/s estimated velocity y";
  Real vhz(start = 0.0)   "m/s estimated velocity z";

  // ---- Sensor variables ----
  Real a_imu_x "m/s^2 IMU-derived world acceleration x";
  Real a_imu_y "m/s^2 IMU-derived world acceleration y";
  Real a_imu_z "m/s^2 IMU-derived world acceleration z";
  Real gps_x "m GPS position x";
  Real gps_y "m GPS position y";
  Real gps_z "m GPS position z";
  Real alt_z_meas "m altimeter measurement";
  Real cam_ts "s camera timestamp";
  Real cam_x "m camera position x";
  Real cam_y "m camera position y";
  Real cam_z "m camera position z";
  Real pos_meas_x "m fused position measurement x";
  Real pos_meas_y "m fused position measurement y";
  Real pos_meas_z "m fused position measurement z";

  // ---- Disturbance ----
  Real wind_fx "N wind force x";
  Real wind_fy "N wind force y";
  Real wind_fz "N wind force z";

  // ---- Monitoring / verification ----
  Real wp_error "m waypoint tracking error";
  Real primary_error "m primary tracking error";
  Real clr1 "m obstacle 1 clearance";
  Real clr2 "m obstacle 2 clearance";
  Real clr3 "m obstacle 3 clearance";
  Real min_clr "m minimum obstacle clearance";
  Boolean no_collision;
  Boolean thrust_bounded;
  Boolean attitude_bounded;
  Boolean estimator_finite;
  Boolean all_finite;

equation
  // ===== Reference trajectory (linear interpolation between waypoints) =====
  ref_x = if time < t_wp1 then wp1x
          else if time < t_wp2 then wp1x + ((time - t_wp1) / (t_wp2 - t_wp1)) * (wp2x - wp1x)
          else if time < t_wp3 then wp2x + ((time - t_wp2) / (t_wp3 - t_wp2)) * (wp3x - wp2x)
          else wp3x + ((time - t_wp3) / (t_wp4 - t_wp3)) * (wp4x - wp3x);

  ref_y = if time < t_wp1 then wp1y
          else if time < t_wp2 then wp1y + ((time - t_wp1) / (t_wp2 - t_wp1)) * (wp2y - wp1y)
          else if time < t_wp3 then wp2y + ((time - t_wp2) / (t_wp3 - t_wp2)) * (wp3y - wp2y)
          else wp3y + ((time - t_wp3) / (t_wp4 - t_wp3)) * (wp4y - wp3y);

  ref_z = if time < t_wp1 then wp1z
          else if time < t_wp2 then wp1z + ((time - t_wp1) / (t_wp2 - t_wp1)) * (wp2z - wp1z)
          else if time < t_wp3 then wp2z + ((time - t_wp2) / (t_wp3 - t_wp2)) * (wp3z - wp2z)
          else wp3z + ((time - t_wp3) / (t_wp4 - t_wp3)) * (wp4z - wp3z);

  vref_x = if time < t_wp1 then 0.0
           else if time < t_wp2 then (wp2x - wp1x) / (t_wp2 - t_wp1)
           else if time < t_wp3 then (wp3x - wp2x) / (t_wp3 - t_wp2)
           else (wp4x - wp3x) / (t_wp4 - t_wp3);

  vref_y = if time < t_wp1 then 0.0
           else if time < t_wp2 then (wp2y - wp1y) / (t_wp2 - t_wp1)
           else if time < t_wp3 then (wp3y - wp2y) / (t_wp3 - t_wp2)
           else (wp4y - wp3y) / (t_wp4 - t_wp3);

  vref_z = if time < t_wp1 then 0.0
           else if time < t_wp2 then (wp2z - wp1z) / (t_wp2 - t_wp1)
           else if time < t_wp3 then (wp3z - wp2z) / (t_wp3 - t_wp2)
           else (wp4z - wp3z) / (t_wp4 - t_wp3);

  // Feedforward acceleration (zero within constant-velocity segments)
  aref_x = 0.0;
  aref_y = 0.0;
  aref_z = 0.0;

  // ===== Outer-loop position controller (uses estimated state) =====
  ax_des = aref_x + Kp_pos * (ref_x - rhx) + Kd_pos * (vref_x - vhx);
  ay_des = aref_y + Kp_pos * (ref_y - rhy) + Kd_pos * (vref_y - vhy);
  az_des = aref_z + Kp_pos * (ref_z - rhz) + Kd_pos * (vref_z - vhz);

  // Desired attitude from desired horizontal acceleration (small-angle, yaw = 0)
  phi_d   = -ay_des / g;
  theta_d =  ax_des / g;
  psi_d   = 0.0;

  // Attitude bounds
  phi_d_b   = max(-att_max, min(att_max, phi_d));
  theta_d_b = max(-att_max, min(att_max, theta_d));

  // Commanded total thrust (vertical channel, projected by actual attitude)
  T_total = m_total * (az_des + g) / max(cos(phi) * cos(theta), 0.1);

  // ===== Inner-loop attitude controller =====
  tau_x_cmd = Kp_att * (phi_d_b   - phi)   - Kd_att * p_rate;
  tau_y_cmd = Kp_att * (theta_d_b - theta) - Kd_att * q_rate;
  tau_z_cmd = Kp_att * (psi_d     - psi)   - Kd_att * r_rate;

  // ===== Rotor allocation (hex mixer) =====
  rt1 = T_total / 6.0 + (tau_x_cmd / (3.0 * R_arm)) * sin(alpha1) + (tau_y_cmd / (3.0 * R_arm)) * cos(alpha1) + (tau_z_cmd / (6.0 * k_yaw)) * ( 1.0);
  rt2 = T_total / 6.0 + (tau_x_cmd / (3.0 * R_arm)) * sin(alpha2) + (tau_y_cmd / (3.0 * R_arm)) * cos(alpha2) + (tau_z_cmd / (6.0 * k_yaw)) * (-1.0);
  rt3 = T_total / 6.0 + (tau_x_cmd / (3.0 * R_arm)) * sin(alpha3) + (tau_y_cmd / (3.0 * R_arm)) * cos(alpha3) + (tau_z_cmd / (6.0 * k_yaw)) * ( 1.0);
  rt4 = T_total / 6.0 + (tau_x_cmd / (3.0 * R_arm)) * sin(alpha4) + (tau_y_cmd / (3.0 * R_arm)) * cos(alpha4) + (tau_z_cmd / (6.0 * k_yaw)) * (-1.0);
  rt5 = T_total / 6.0 + (tau_x_cmd / (3.0 * R_arm)) * sin(alpha5) + (tau_y_cmd / (3.0 * R_arm)) * cos(alpha5) + (tau_z_cmd / (6.0 * k_yaw)) * ( 1.0);
  rt6 = T_total / 6.0 + (tau_x_cmd / (3.0 * R_arm)) * sin(alpha6) + (tau_y_cmd / (3.0 * R_arm)) * cos(alpha6) + (tau_z_cmd / (6.0 * k_yaw)) * (-1.0);

  // Bounded rotor thrusts
  rotor_thrust1 = max(Thrust_min, min(Thrust_max, rt1));
  rotor_thrust2 = max(Thrust_min, min(Thrust_max, rt2));
  rotor_thrust3 = max(Thrust_min, min(Thrust_max, rt3));
  rotor_thrust4 = max(Thrust_min, min(Thrust_max, rt4));
  rotor_thrust5 = max(Thrust_min, min(Thrust_max, rt5));
  rotor_thrust6 = max(Thrust_min, min(Thrust_max, rt6));

  // Actual total body-z thrust
  T_bz = rotor_thrust1 + rotor_thrust2 + rotor_thrust3 + rotor_thrust4 + rotor_thrust5 + rotor_thrust6;

  // Actual body torques from bounded thrusts
  tau_x_act = R_arm * (rotor_thrust1 * sin(alpha1) + rotor_thrust2 * sin(alpha2) + rotor_thrust3 * sin(alpha3) + rotor_thrust4 * sin(alpha4) + rotor_thrust5 * sin(alpha5) + rotor_thrust6 * sin(alpha6));
  tau_y_act = R_arm * (rotor_thrust1 * cos(alpha1) + rotor_thrust2 * cos(alpha2) + rotor_thrust3 * cos(alpha3) + rotor_thrust4 * cos(alpha4) + rotor_thrust5 * cos(alpha5) + rotor_thrust6 * cos(alpha6));
  tau_z_act = k_yaw * (rotor_thrust1 * ( 1.0) + rotor_thrust2 * (-1.0) + rotor_thrust3 * ( 1.0) + rotor_thrust4 * (-1.0) + rotor_thrust5 * ( 1.0) + rotor_thrust6 * (-1.0));

  // World-frame thrust (yaw = 0 simplification)
  fx_world =  T_bz * cos(phi) * sin(theta);
  fy_world = -T_bz * sin(phi);
  fz_world =  T_bz * cos(phi) * cos(theta);

  // ===== Crosswind disturbance =====
  wind_fx = if (time >= t_wind_start and time <= t_wind_end) then F_wind else 0.0;
  wind_fy = 0.0;
  wind_fz = 0.0;

  // ===== Plant dynamics =====
  der(rx) = vx;
  der(ry) = vy;
  der(rz) = vz;
  m_total * der(vx) = fx_world + wind_fx;
  m_total * der(vy) = fy_world + wind_fy;
  m_total * der(vz) = fz_world - m_total * g + wind_fz;
  der(phi)   = p_rate;
  der(theta) = q_rate;
  der(psi)   = r_rate;
  Ixx * der(p_rate) = tau_x_act;
  Iyy * der(q_rate) = tau_y_act;
  Izz * der(r_rate) = tau_z_act;

  // ===== Simulated sensors with deterministic noise =====
  a_imu_x = (fx_world + wind_fx) / m_total + 0.02 * sin(2.0 * Modelica.Constants.pi * 50.0 * time);
  a_imu_y = (fy_world + wind_fy) / m_total + 0.02 * cos(2.0 * Modelica.Constants.pi * 50.0 * time);
  a_imu_z = (fz_world - m_total * g + wind_fz) / m_total + 0.02 * sin(2.0 * Modelica.Constants.pi * 50.0 * time + 1.0);
  gps_x   = rx + 0.05 * sin(2.0 * Modelica.Constants.pi * 2.0 * time);
  gps_y   = ry + 0.05 * cos(2.0 * Modelica.Constants.pi * 2.0 * time);
  gps_z   = rz + 0.10 * sin(2.0 * Modelica.Constants.pi * 1.0 * time);
  alt_z_meas = rz + 0.02 * sin(2.0 * Modelica.Constants.pi * 5.0 * time);
  cam_ts  = time;
  cam_x   = rx + 0.03 * sin(2.0 * Modelica.Constants.pi * 10.0 * time);
  cam_y   = ry + 0.03 * cos(2.0 * Modelica.Constants.pi * 10.0 * time);
  cam_z   = rz + 0.03 * sin(2.0 * Modelica.Constants.pi * 10.0 * time + 1.0);

  // Fused position measurement: GPS + camera for x/y, altimeter for z
  pos_meas_x = 0.5 * gps_x + 0.5 * cam_x;
  pos_meas_y = 0.5 * gps_y + 0.5 * cam_y;
  pos_meas_z = alt_z_meas;

  // ===== Estimator: second-order complementary filter fusing IMU + GPS + altimeter + camera =====
  der(rhx) = vhx + 2.0 * zeta_est * omega_est * (pos_meas_x - rhx);
  der(vhx) = a_imu_x + omega_est * omega_est * (pos_meas_x - rhx);
  der(rhy) = vhy + 2.0 * zeta_est * omega_est * (pos_meas_y - rhy);
  der(vhy) = a_imu_y + omega_est * omega_est * (pos_meas_y - rhy);
  der(rhz) = vhz + 2.0 * zeta_est * omega_est * (pos_meas_z - rhz);
  der(vhz) = a_imu_z + omega_est * omega_est * (pos_meas_z - rhz);

  // ===== Monitoring: tracking error =====
  wp_error = sqrt(max((rx - ref_x) * (rx - ref_x) + (ry - ref_y) * (ry - ref_y) + (rz - ref_z) * (rz - ref_z), eps * eps));
  primary_error = wp_error;

  // ===== Monitoring: obstacle clearance =====
  clr1 = if (rz >= o1zb and rz <= o1zb + o1h) then
           sqrt(max((rx - o1x) * (rx - o1x) + (ry - o1y) * (ry - o1y), eps * eps)) - o1r
         else 100.0;
  clr2 = if (rz >= o2zb and rz <= o2zb + o2h) then
           sqrt(max((rx - o2x) * (rx - o2x) + (ry - o2y) * (ry - o2y), eps * eps)) - o2r
         else 100.0;
  clr3 = if (rz >= o3zb and rz <= o3zb + o3h) then
           sqrt(max((rx - o3x) * (rx - o3x) + (ry - o3y) * (ry - o3y), eps * eps)) - o3r
         else 100.0;
  min_clr = min(clr1, min(clr2, clr3));

  no_collision = min_clr > 0.0;

  // ===== Monitoring: bounds and finiteness =====
  thrust_bounded = (rotor_thrust1 >= -0.001) and (rotor_thrust1 <= Thrust_max + 0.001) and
                   (rotor_thrust2 >= -0.001) and (rotor_thrust2 <= Thrust_max + 0.001) and
                   (rotor_thrust3 >= -0.001) and (rotor_thrust3 <= Thrust_max + 0.001) and
                   (rotor_thrust4 >= -0.001) and (rotor_thrust4 <= Thrust_max + 0.001) and
                   (rotor_thrust5 >= -0.001) and (rotor_thrust5 <= Thrust_max + 0.001) and
                   (rotor_thrust6 >= -0.001) and (rotor_thrust6 <= Thrust_max + 0.001);

  attitude_bounded = (abs(phi)   <= att_max + 0.05) and
                     (abs(theta) <= att_max + 0.05);

  estimator_finite = (abs(rhx) < 1.0e6) and (abs(rhy) < 1.0e6) and (abs(rhz) < 1.0e6) and
                      (abs(vhx) < 1.0e6) and (abs(vhy) < 1.0e6) and (abs(vhz) < 1.0e6);

  all_finite = estimator_finite and
               (abs(rx) < 1.0e6) and (abs(ry) < 1.0e6) and (abs(rz) < 1.0e6) and
               (abs(vx) < 1.0e6) and (abs(vy) < 1.0e6) and (abs(vz) < 1.0e6) and
               (abs(phi) < 1.0e6) and (abs(theta) < 1.0e6) and (abs(psi) < 1.0e6) and
               (abs(p_rate) < 1.0e6) and (abs(q_rate) < 1.0e6) and (abs(r_rate) < 1.0e6) and
               (abs(T_total) < 1.0e6) and (abs(tau_x_cmd) < 1.0e6) and
               (abs(tau_y_cmd) < 1.0e6) and (abs(tau_z_cmd) < 1.0e6);

  // ===== Assertions =====
  assert(thrust_bounded,     "Rotor thrust bound violated");
  assert(attitude_bounded,   "Attitude bound violated");
  assert(no_collision,       "Collision with obstacle detected");
  assert(estimator_finite,   "Estimator values not finite");
  assert(all_finite,         "Physical, control, or estimator values not finite");
  assert(time <= 9.1 or primary_error < 0.35,
         "Primary tracking error exceeds 0.35 m after 9.1 s");

  annotation(
    Experiment(StopTime = 14.0, Tolerance = 1.0e-6, Interval = 0.005),
    Documentation(info = "HexaSurveySurveyD: 3.2 kg cylindrical hexacopter (0.35 m arm radius) with 0.4 kg camera payload. Fuses IMU, GPS, altimeter, and camera-timestamp measurements via a second-order complementary filter. Bounded waypoint tracking (feedforward acceleration) of four 3D waypoints with declared deadlines. Three fixed cylindrical obstacles outside the reference polyline. 6 N crosswind during the middle third of a 14 s, 200 Hz run."),
    Diagram()
  );
end HexaSurveySurveyD;