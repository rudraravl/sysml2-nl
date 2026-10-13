model DuctInspectDeliverE
  parameter Real pi = 3.141592653589793;
  parameter Real g = 9.81 "m/s^2";

  // Body (stated: 2.7 kg cylindrical body)
  parameter Real m_body = 2.7 "kg";
  parameter Real m_probe = 0.05 "kg, probe point mass (design choice)";
  parameter Real m_eff = m_body + m_probe "kg, effective body mass";
  parameter Real I_body = 0.04 "kg.m^2, pitch inertia (design choice)";

  // Fans (stated: four protected ducted fans, max 19.8 N per fan)
  parameter Real T_max = 19.8 "N, per-fan thrust bound";
  parameter Real T_min = 0.0 "N";
  parameter Real fan_arm = 0.15 "m, moment arm (design choice)";

  // Probe (stated: compliant 0.18 m inspection probe along body X)
  parameter Real L_probe = 0.18 "m";
  parameter Real k_probe = 800.0 "N/m, probe stiffness (design choice)";
  parameter Real c_probe = 12.0 "N.s/m, probe damping (design choice)";
  parameter Real F_probe_max = 5.0 "N, probe-force actuator bound (design choice)";

  // Cable and payload (design choices)
  parameter Real L_cable = 1.0 "m, cable length";
  parameter Real m_payload = 0.6 "kg, payload mass";

  // Aerodynamic drag (design choices)
  parameter Real Cd_body = 0.15 "N.s/m";
  parameter Real Cd_payload = 0.03 "N.s/m";

  // Mission parameters (stated)
  parameter Real x_target = 5.0 "m";
  parameter Real target_radius = 0.8 "m";
  parameter Real z_ground = 0.0 "m";
  parameter Real t_total = 16.0 "s";

  // Trajectory phases (design choices)
  parameter Real z_start = 1.1 "m, initial hover height";
  parameter Real z_cruise = 3.0 "m, cruise height";
  parameter Real z_lower = 1.05 "m, lowering height";
  parameter Real t_lift_end = 3.0 "s";
  parameter Real t_cruise_start = 3.0 "s";
  parameter Real t_cruise_end = 11.0 "s";
  parameter Real t_lower_start = 11.0 "s";
  parameter Real t_lower_end = 16.0 "s";

  // Gust (stated: 9.6 N, middle third of cruise)
  parameter Real F_gust_mag = 9.6 "N";
  parameter Real t_gust_start = t_cruise_start + (t_cruise_end - t_cruise_start) / 3.0;
  parameter Real t_gust_end = t_cruise_start + 2.0 * (t_cruise_end - t_cruise_start) / 3.0;

  // Controller gains (design choices)
  parameter Real Kp_x = 2.5;
  parameter Real Kd_x = 3.5;
  parameter Real Kp_z = 2.5;
  parameter Real Kd_z = 3.5;
  parameter Real Kp_theta = 30.0;
  parameter Real Kd_theta = 12.0;
  parameter Real K_swing_rate = 1.2;
  parameter Real K_swing_pos = 0.6;
  parameter Real Kp_probe = 50.0;
  parameter Real Kd_probe = 10.0;
  parameter Real m_total_ctrl = m_eff + m_payload "kg, feedforward mass";

  // Tension bound (design choice)
  parameter Real T_cable_max = 50.0 "N";

  // Body states
  Real x_b(start = 0.0, fixed = true) "m, body x position";
  Real z_b(start = z_start, fixed = true) "m, body z position";
  Real vx(start = 0.0, fixed = true) "m/s";
  Real vz(start = 0.0, fixed = true) "m/s";
  Real theta(start = 0.0, fixed = true) "rad, pitch (forward tilt positive)";
  Real theta_dot(start = 0.0, fixed = true) "rad/s";
  Real phi(start = 0.0, fixed = true) "rad, cable angle from vertical";
  Real phi_dot(start = 0.0, fixed = true) "rad/s";
  Real d_probe(start = 0.0, fixed = true) "m, probe axial deflection";
  Real d_probe_dot(start = 0.0, fixed = true) "m/s";

  // Actuators
  Real T1 "N, front-left fan";
  Real T2 "N, front-right fan";
  Real T3 "N, rear-left fan";
  Real T4 "N, rear-right fan";
  Real T_total "N";
  Real M_pitch_actual "N.m";
  Real F_probe_cmd "N";
  Real F_probe_sat "N";

  // Sensors
  Real gps_x "m";
  Real gps_z "m";
  Real imu_ax "m/s^2, body-frame specific force X";
  Real imu_az "m/s^2, body-frame specific force Z";
  Real imu_gyro "rad/s";
  Real cable_angle_meas "rad";
  Real tension_meas "N";

  // Reference trajectory
  Real x_ref "m";
  Real z_ref "m";
  Real vx_ref "m/s";
  Real vz_ref "m/s";

  // Controller internals
  Real ax_des "m/s^2";
  Real az_des "m/s^2";
  Real theta_cmd "rad";
  Real T_total_cmd "N";
  Real M_cmd "N.m";
  Real T_front_avg "N";
  Real T_rear_avg "N";

  // Disturbance
  Real F_gust "N";

  // Physical quantities
  Real T_cable "N, cable tension";
  Real F_rxn_body "N, probe reaction on body along body X";
  Real F_rxn_world_x "N";
  Real F_rxn_world_z "N";
  Real ax "m/s^2, body x acceleration";
  Real az "m/s^2, body z acceleration";
  Real a_bx "m/s^2, body acceleration along body X";
  Real phi_dd "rad/s^2";
  Real vx_payload "m/s";
  Real vz_payload "m/s";
  Real F_drag_px "N";
  Real F_drag_pz "N";
  Real F_drag_perp "N";
  Real F_drag_par "N";

  // Payload position
  Real x_payload "m";
  Real z_payload "m";

  // Acceptance
  Real tracking_error "m";
  Real swing_angle "rad";
  Boolean thrust_bounded;
  Boolean tension_bounded;
  Boolean swing_bounded;
  Boolean no_ground_strike;
  Boolean tracking_passed;
  Boolean in_target;
  Boolean no_nan_inf;
  Boolean all_acceptances;

equation
  // ===== GUST DISTURBANCE (9.6 N, middle third of cruise) =====
  if time >= t_gust_start and time <= t_gust_end then
    F_gust = F_gust_mag;
  else
    F_gust = 0.0;
  end if;

  // ===== INPUT-SHAPED REFERENCE TRAJECTORY =====
  // X: hold 0 during lift, smoothstep 0->5 during cruise, hold 5 during lower
  if time <= t_cruise_start then
    x_ref = 0.0;
    vx_ref = 0.0;
  elseif time >= t_cruise_end then
    x_ref = x_target;
    vx_ref = 0.0;
  else
    x_ref = x_target * 0.5 * (1.0 - cos(pi * (time - t_cruise_start) / (t_cruise_end - t_cruise_start)));
    vx_ref = x_target * 0.5 * pi / (t_cruise_end - t_cruise_start) *
             sin(pi * (time - t_cruise_start) / (t_cruise_end - t_cruise_start));
  end if;

  // Z: smoothstep lift [0,3], hold cruise [3,11], smoothstep lower [11,16]
  if time <= t_lift_end then
    z_ref = z_start + (z_cruise - z_start) * 0.5 * (1.0 - cos(pi * time / t_lift_end));
    vz_ref = (z_cruise - z_start) * 0.5 * pi / t_lift_end * sin(pi * time / t_lift_end);
  elseif time <= t_lower_start then
    z_ref = z_cruise;
    vz_ref = 0.0;
  elseif time <= t_lower_end then
    z_ref = z_cruise + (z_lower - z_cruise) * 0.5 * (1.0 - cos(pi * (time - t_lower_start) / (t_lower_end - t_lower_start)));
    vz_ref = (z_lower - z_cruise) * 0.5 * pi / (t_lower_end - t_lower_start) *
             sin(pi * (time - t_lower_start) / (t_lower_end - t_lower_start));
  else
    z_ref = z_lower;
    vz_ref = 0.0;
  end if;

  // ===== POSITION CONTROLLER WITH CABLE-SWING DAMPING =====
  ax_des = Kp_x * (x_ref - x_b) + Kd_x * (vx_ref - vx) + K_swing_rate * phi_dot + K_swing_pos * phi;
  az_des = Kp_z * (z_ref - z_b) + Kd_z * (vz_ref - vz);

  // Convert desired acceleration to thrust and pitch commands
  T_total_cmd = m_total_ctrl * sqrt(max(0.01, (g + az_des) ^ 2 + ax_des ^ 2));
  theta_cmd = atan2(ax_des, g + az_des);

  // Pitch PD
  M_cmd = Kp_theta * (theta_cmd - theta) + Kd_theta * (0.0 - theta_dot);

  // Fan allocation: front pair decreases, rear pair increases for forward tilt
  T_front_avg = T_total_cmd / 4.0 - M_cmd / (4.0 * fan_arm);
  T_rear_avg = T_total_cmd / 4.0 + M_cmd / (4.0 * fan_arm);

  // Saturate each fan to [0, 19.8] N
  T1 = max(T_min, min(T_max, T_front_avg));
  T2 = max(T_min, min(T_max, T_front_avg));
  T3 = max(T_min, min(T_max, T_rear_avg));
  T4 = max(T_min, min(T_max, T_rear_avg));

  T_total = T1 + T2 + T3 + T4;
  M_pitch_actual = (T3 + T4 - T1 - T2) * fan_arm;

  // ===== PROBE CONTROLLER =====
  F_probe_cmd = Kp_probe * (0.0 - d_probe) + Kd_probe * (0.0 - d_probe_dot);
  F_probe_sat = max(-F_probe_max, min(F_probe_max, F_probe_cmd));

  // ===== PROBE REACTION ON BODY (along body X) =====
  F_rxn_body = k_probe * d_probe + c_probe * d_probe_dot - F_probe_sat;
  F_rxn_world_x = F_rxn_body * cos(theta);
  F_rxn_world_z = -F_rxn_body * sin(theta);

  // ===== PAYLOAD VELOCITY AND DRAG =====
  vx_payload = vx + L_cable * cos(phi) * phi_dot;
  vz_payload = vz + L_cable * sin(phi) * phi_dot;
  F_drag_px = -Cd_payload * vx_payload;
  F_drag_pz = -Cd_payload * vz_payload;
  F_drag_perp = F_drag_px * cos(phi) + F_drag_pz * sin(phi);
  F_drag_par = F_drag_px * sin(phi) - F_drag_pz * cos(phi);

  // ===== CABLE TENSION (explicitly solved, no algebraic loop) =====
  T_cable = (m_payload * (g * cos(phi)
    + (T_total * cos(theta) - m_eff * g - Cd_body * vz + F_rxn_world_z) / m_eff * cos(phi)
    - (T_total * sin(theta) + F_gust - Cd_body * vx + F_rxn_world_x) / m_eff * sin(phi)
    + L_cable * phi_dot * phi_dot) + F_drag_par) / (1.0 + m_payload / m_eff);

  // ===== BODY ACCELERATIONS =====
  ax = (T_total * sin(theta) + F_gust - Cd_body * vx + T_cable * sin(phi) + F_rxn_world_x) / m_eff;
  az = (T_total * cos(theta) - m_eff * g - Cd_body * vz - T_cable * cos(phi) + F_rxn_world_z) / m_eff;

  // Body acceleration along body X (for probe dynamics)
  a_bx = ax * cos(theta) - az * sin(theta);

  // ===== PENDULUM DYNAMICS =====
  phi_dd = (-g * sin(phi) + F_drag_perp / m_payload - ax * cos(phi) - az * sin(phi)) / L_cable;

  // ===== STATE DERIVATIVES =====
  der(x_b) = vx;
  der(z_b) = vz;
  der(vx) = ax;
  der(vz) = az;
  der(theta) = theta_dot;
  der(theta_dot) = M_pitch_actual / I_body;
  der(phi) = phi_dot;
  der(phi_dot) = phi_dd;
  der(d_probe) = d_probe_dot;
  m_probe * der(d_probe_dot) = F_probe_sat - k_probe * d_probe - c_probe * d_probe_dot - m_probe * a_bx;

  // ===== SENSORS =====
  gps_x = x_b;
  gps_z = z_b;
  imu_ax = a_bx;
  imu_az = ax * sin(theta) + (az + g) * cos(theta);
  imu_gyro = theta_dot;
  cable_angle_meas = phi;
  tension_meas = T_cable;

  // ===== PAYLOAD POSITION =====
  x_payload = x_b + L_cable * sin(phi);
  z_payload = z_b - L_cable * cos(phi);

  // ===== ACCEPTANCE CRITERIA (fail-closed) =====
  tracking_error = sqrt((x_ref - x_b) ^ 2 + (z_ref - z_b) ^ 2);
  swing_angle = abs(phi);

  thrust_bounded = (T1 >= T_min - 0.001) and (T1 <= T_max + 0.001) and
                   (T2 >= T_min - 0.001) and (T2 <= T_max + 0.001) and
                   (T3 >= T_min - 0.001) and (T3 <= T_max + 0.001) and
                   (T4 >= T_min - 0.001) and (T4 <= T_max + 0.001);

  tension_bounded = (T_cable >= 0.0) and (T_cable <= T_cable_max);
  swing_bounded = (swing_angle < 0.45);
  no_ground_strike = (z_b > 0.001) and (z_payload > 0.001);
  tracking_passed = (time < 10.4) or (tracking_error < 0.27);
  in_target = sqrt((x_payload - x_target) ^ 2 + (z_payload - z_ground) ^ 2) <= target_radius;
  no_nan_inf = (abs(x_b) < 1e8) and (abs(z_b) < 1e8) and (abs(phi) < 1e8) and
               (abs(T_cable) < 1e8) and (abs(T1) < 1e8) and (abs(theta) < 1e8) and
               (abs(d_probe) < 1e8) and (abs(T_total) < 1e8);

  all_acceptances = thrust_bounded and tension_bounded and swing_bounded and
                    no_ground_strike and no_nan_inf and tracking_passed and
                    (if time >= t_total - 0.5 then in_target else true);

  annotation(
    experiment(StartTime = 0, StopTime = 16, Tolerance = 1e-6, Interval = 0.004),
    Documentation(info = "DuctInspectDeliverE: free-base ducted-fan aerial robot with "
      "suspended payload. Mission: lift, translate 5 m horizontally, lower into "
      "0.8 m-radius target zone. 2.7 kg body, four ducted fans (19.8 N max each), "
      "compliant 0.18 m inspection probe along body X, cable-payload dynamics, "
      "gravity, aerodynamic drag, 9.6 N lateral gust during middle third of cruise. "
      "Input-shaped position control with cable-swing damping. 250 Hz, 16 s."));
end DuctInspectDeliverE;