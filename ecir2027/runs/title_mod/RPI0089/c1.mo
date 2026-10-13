model DuctInspectDeliverE
  parameter Real g = 9.81 "m/s^2 gravitational acceleration";

  // Body (stated: 2.7 kg cylindrical body)
  parameter Real m_body = 2.7 "kg";
  parameter Real m_probe = 0.05 "kg probe point mass";
  parameter Real m_eff = m_body + m_probe "kg effective mass";
  parameter Real I_body = 0.04 "kg.m^2 pitch inertia";

  // Fans (stated: four protected ducted fans, max 19.8 N per fan)
  parameter Real T_max = 19.8 "N per-fan thrust bound";
  parameter Real T_min = 0.0 "N";
  parameter Real fan_arm = 0.15 "m moment arm";

  // Probe (stated: compliant 0.18 m inspection probe along body X)
  parameter Real L_probe = 0.18 "m";
  parameter Real k_probe = 800.0 "N/m probe stiffness";
  parameter Real c_probe = 12.0 "N.s/m probe damping";
  parameter Real F_probe_max = 5.0 "N probe-force actuator bound";

  // Cable and payload
  parameter Real L_cable = 1.0 "m cable length";
  parameter Real m_payload = 0.6 "kg payload mass";

  // Aerodynamic drag
  parameter Real Cd_body = 0.15 "N.s/m body drag";
  parameter Real Cd_payload = 0.03 "N.s/m payload drag";

  // Mission parameters (stated)
  parameter Real x_target = 5.0 "m";
  parameter Real target_radius = 0.8 "m";
  parameter Real z_ground = 0.0 "m";
  parameter Real t_total = 16.0 "s";

  // Trajectory phases
  parameter Real z_start = 1.1 "m initial hover height";
  parameter Real z_cruise = 3.0 "m cruise height";
  parameter Real z_lower = 1.05 "m lowering height";
  parameter Real t_lift_end = 3.0 "s";
  parameter Real t_cruise_start = 3.0 "s";
  parameter Real t_cruise_end = 11.0 "s";
  parameter Real t_lower_start = 11.0 "s";
  parameter Real t_lower_end = 16.0 "s";

  // Gust (stated: 9.6 N, middle third of cruise)
  parameter Real F_gust_mag = 9.6 "N";
  parameter Real t_gust_start = 5.666666666666667 "s";
  parameter Real t_gust_end = 8.333333333333334 "s";

  // Controller gains
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
  parameter Real m_total_ctrl = m_eff + m_payload "kg feedforward mass";

  // Tension bound
  parameter Real T_cable_max = 50.0 "N";

  // Body states
  Real x_b(start = 0.0, fixed = true) "m body x position";
  Real z_b(start = z_start, fixed = true) "m body z position";
  Real vx(start = 0.0, fixed = true) "m/s body x velocity";
  Real vz(start = 0.0, fixed = true) "m/s body z velocity";
  Real theta(start = 0.0, fixed = true) "rad pitch angle";
  Real theta_dot(start = 0.0, fixed = true) "rad/s pitch rate";
  Real phi(start = 0.0, fixed = true) "rad cable angle from vertical";
  Real phi_dot(start = 0.0, fixed = true) "rad/s cable angular rate";
  Real d_probe(start = 0.0, fixed = true) "m probe axial deflection";
  Real d_probe_dot(start = 0.0, fixed = true) "m/s probe deflection rate";

  // Actuators
  Real T1 "N fan 1";
  Real T2 "N fan 2";
  Real T3 "N fan 3";
  Real T4 "N fan 4";
  Real T_total "N total thrust";
  Real M_pitch_actual "N.m actual pitch moment";
  Real F_probe_cmd "N probe force command";
  Real F_probe_sat "N saturated probe force";

  // Sensors
  Real gps_x "m GPS x";
  Real gps_z "m GPS z";
  Real imu_ax "m/s^2 IMU accel X body frame";
  Real imu_az "m/s^2 IMU accel Z body frame";
  Real imu_gyro "rad/s IMU gyro";
  Real cable_angle_meas "rad cable angle measurement";
  Real tension_meas "N cable tension measurement";

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
  Real T_cable "N cable tension";
  Real F_rxn_body "N probe reaction on body along body X";
  Real F_rxn_world_x "N";
  Real F_rxn_world_z "N";
  Real ax "m/s^2 body x acceleration";
  Real az "m/s^2 body z acceleration";
  Real a_bx "m/s^2 body acceleration along body X";
  Real phi_dd "rad/s^2 cable angular acceleration";
  Real vx_payload "m/s";
  Real vz_payload "m/s";
  Real F_drag_px "N";
  Real F_drag_pz "N";
  Real F_drag_tang "N";
  Real F_drag_radial "N";
  Real A_x "N non-tension force on body x";
  Real A_z "N non-tension force on body z";
  Real gamma "rad angle of desired thrust";
  Real tmp1 "intermediate";
  Real tmp2 "intermediate";

  // Payload position
  Real x_payload "m";
  Real z_payload "m";

  // Acceptance
  Real tracking_error "m";
  Real swing_angle "rad";
  Real dist_to_target "m";
  Boolean thrust_bounded;
  Boolean tension_bounded;
  Boolean swing_bounded;
  Boolean no_ground_strike;
  Boolean tracking_passed;
  Boolean in_target;
  Boolean no_nan_inf;
  Boolean target_check;
  Boolean all_acceptances;

equation
  // ===== GUST DISTURBANCE =====
  if time >= t_gust_start and time <= t_gust_end then
    F_gust = F_gust_mag;
  else
    F_gust = 0.0;
  end if;

  // ===== INPUT-SHAPED REFERENCE TRAJECTORY - X =====
  if time <= t_cruise_start then
    x_ref = 0.0;
    vx_ref = 0.0;
  elseif time >= t_cruise_end then
    x_ref = x_target;
    vx_ref = 0.0;
  else
    gamma = 3.141592653589793 * (time - t_cruise_start) / (t_cruise_end - t_cruise_start);
    x_ref = x_target * 0.5 * (1.0 - cos(gamma));
    vx_ref = x_target * 0.5 * 3.141592653589793 / (t_cruise_end - t_cruise_start) * sin(gamma);
  end if;

  // ===== INPUT-SHAPED REFERENCE TRAJECTORY - Z =====
  if time <= t_lift_end then
    gamma = 3.141592653589793 * time / t_lift_end;
    z_ref = z_start + (z_cruise - z_start) * 0.5 * (1.0 - cos(gamma));
    vz_ref = (z_cruise - z_start) * 0.5 * 3.141592653589793 / t_lift_end * sin(gamma);
  elseif time <= t_lower_start then
    z_ref = z_cruise;
    vz_ref = 0.0;
  elseif time <= t_lower_end then
    gamma = 3.141592653589793 * (time - t_lower_start) / (t_lower_end - t_lower_start);
    z_ref = z_cruise + (z_lower - z_cruise) * 0.5 * (1.0 - cos(gamma));
    vz_ref = (z_lower - z_cruise) * 0.5 * 3.141592653589793 / (t_lower_end - t_lower_start) * sin(gamma);
  else
    z_ref = z_lower;
    vz_ref = 0.0;
  end if;

  // ===== POSITION CONTROLLER WITH CABLE-SWING DAMPING =====
  ax_des = Kp_x * (x_ref - x_b) + Kd_x * (vx_ref - vx) + K_swing_rate * phi_dot + K_swing_pos * phi;
  az_des = Kp_z * (z_ref - z_b) + Kd_z * (vz_ref - vz);

  // Convert desired acceleration to thrust and pitch commands
  tmp1 = (g + az_des) * (g + az_des) + ax_des * ax_des;
  T_total_cmd = m_total_ctrl * sqrt(max(0.01, tmp1));
  theta_cmd = atan(ax_des / max(0.01, g + az_des));

  // Pitch PD
  M_cmd = Kp_theta * (theta_cmd - theta) + Kd_theta * (0.0 - theta_dot);

  // Fan allocation: front pair and rear pair
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

  // ===== PROBE REACTION ON BODY =====
  F_rxn_body = k_probe * d_probe + c_probe * d_probe_dot - F_probe_sat;
  F_rxn_world_x = F_rxn_body * cos(theta);
  F_rxn_world_z = -F_rxn_body * sin(theta);

  // ===== PAYLOAD VELOCITY AND DRAG =====
  vx_payload = vx + L_cable * cos(phi) * phi_dot;
  vz_payload = vz + L_cable * sin(phi) * phi_dot;
  F_drag_px = -Cd_payload * vx_payload;
  F_drag_pz = -Cd_payload * vz_payload;
  F_drag_tang = F_drag_px * cos(phi) + F_drag_pz * sin(phi);
  F_drag_radial = F_drag_px * sin(phi) - F_drag_pz * cos(phi);

  // ===== NON-TENSION FORCES ON BODY =====
  A_x = T_total * sin(theta) + F_gust - Cd_body * vx + F_rxn_world_x;
  A_z = T_total * cos(theta) - m_eff * g - Cd_body * vz + F_rxn_world_z;

  // ===== CABLE TENSION (explicit solution, no algebraic loop) =====
  tmp2 = L_cable * phi_dot * phi_dot + g * cos(phi) + (A_z * cos(phi) - A_x * sin(phi)) / m_eff;
  T_cable = (m_payload * tmp2 + F_drag_radial) / (1.0 + m_payload / m_eff);

  // ===== BODY ACCELERATIONS =====
  ax = (A_x + T_cable * sin(phi)) / m_eff;
  az = (A_z - T_cable * cos(phi)) / m_eff;

  // Body acceleration along body X (for probe dynamics)
  a_bx = ax * cos(theta) - az * sin(theta);

  // ===== PENDULUM DYNAMICS =====
  phi_dd = -(ax * cos(phi) + (g + az) * sin(phi)) / L_cable + F_drag_tang / (m_payload * L_cable);

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
  tracking_error = sqrt(max(0.0, (x_ref - x_b) * (x_ref - x_b) + (z_ref - z_b) * (z_ref - z_b)));
  swing_angle = abs(phi);

  thrust_bounded = (T1 >= T_min - 0.001) and (T1 <= T_max + 0.001) and
                   (T2 >= T_min - 0.001) and (T2 <= T_max + 0.001) and
                   (T3 >= T_min - 0.001) and (T3 <= T_max + 0.001) and
                   (T4 >= T_min - 0.001) and (T4 <= T_max + 0.001);

  tension_bounded = (T_cable >= 0.0) and (T_cable <= T_cable_max);
  swing_bounded = (swing_angle < 0.45);
  no_ground_strike = (z_b > 0.001) and (z_payload > 0.001);
  tracking_passed = (time < 10.4) or (tracking_error < 0.27);

  dist_to_target = sqrt(max(0.0, (x_payload - x_target) * (x_payload - x_target) + (z_payload - z_ground) * (z_payload - z_ground)));
  in_target = (dist_to_target <= target_radius);

  no_nan_inf = (abs(x_b) < 1e8) and (abs(z_b) < 1e8) and (abs(phi) < 1e8) and
              (abs(T_cable) < 1e8) and (abs(T1) < 1e8) and (abs(theta) < 1e8) and
              (abs(d_probe) < 1e8) and (abs(T_total) < 1e8);

  if time >= t_total - 0.5 then
    target_check = in_target;
  else
    target_check = true;
  end if;

  all_acceptances = thrust_bounded and tension_bounded and swing_bounded and
                    no_ground_strike and no_nan_inf and tracking_passed and target_check;

  annotation(
    experiment(StartTime = 0, StopTime = 16, Tolerance = 1e-6, Interval = 0.004),
    Documentation(info = "DuctInspectDeliverE: free-base ducted-fan aerial robot with suspended payload. Lift, translate 5 m, lower into 0.8 m target zone. 2.7 kg body, four fans at 19.8 N max, 0.18 m compliant probe, cable-payload, gravity, drag, 9.6 N gust, 250 Hz, 16 s."));
end DuctInspectDeliverE;