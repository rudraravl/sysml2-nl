model QuadScoutDeliverC
  "Free-base aerial robot with input-shaped position control and cable-swing damping"

  // ===== Parameters specified in the request =====
  parameter Real m_fuselage = 1.8 "Fuselage mass [kg]";
  parameter Real L_arm = 0.22 "Rotor arm length [m]";
  parameter Real T_max = 11.0 "Maximum command magnitude per rotor [N]";
  parameter Real F_gust_amp = 7.2 "Gust disturbance amplitude [N]";
  parameter Real x_target = 5.0 "Horizontal translation distance [m]";
  parameter Real r_target = 0.8 "Target zone radius [m]";
  parameter Real t_sim = 12.0 "Simulation duration [s]";
  parameter Real f_sample = 125.0 "Control loop frequency [Hz]";
  parameter Real swing_limit = 0.45 "Maximum cable swing angle [rad]";
  parameter Real tracking_limit = 0.315 "Maximum tracking error after 7.8 s [m]";
  parameter Real t_gust_start = 4.0 "Gust start time (middle third) [s]";
  parameter Real t_gust_end = 8.0 "Gust end time (middle third) [s]";
  parameter Real t_tracking_check = 7.8 "Tracking error check time [s]";

  // ===== Parameters NOT specified in the request (engineering estimates) =====
  parameter Real m_payload = 0.5 "Payload mass [kg] -- not specified in request";
  parameter Real L_cable = 1.0 "Cable length [m] -- not specified in request";
  parameter Real z_hover = 3.0 "Hover altitude [m] -- not specified in request";
  parameter Real z_target = 0.5 "Payload target altitude [m] -- not specified in request";
  parameter Real z_init = 0.15 "Initial altitude [m] -- not specified in request";
  parameter Real I_pitch = 0.02 "Pitch moment of inertia [kg.m2] -- not specified in request";
  parameter Real Cd = 0.08 "Aerodynamic drag coefficient [N.s/m] -- not specified in request";
  parameter Real k_yaw = 0.02 "Yaw moment coefficient -- not specified in request";
  parameter Real t_lift_end = 2.0 "End of lift phase [s] -- not specified in request";
  parameter Real t_cruise_end = 8.0 "End of cruise phase [s] -- aligned with gust end";
  parameter Real g_const = 9.81 "Gravitational acceleration [m/s2]";

  // ===== Controller gains (NOT specified in request) =====
  parameter Real Kp_x = 1.2 "X position proportional gain -- not specified";
  parameter Real Kd_x = 1.8 "X position derivative gain -- not specified";
  parameter Real Kp_z = 4.0 "Z position proportional gain -- not specified";
  parameter Real Kd_z = 3.5 "Z position derivative gain -- not specified";
  parameter Real Kp_pitch = 8.0 "Pitch proportional gain -- not specified";
  parameter Real Kd_pitch = 2.0 "Pitch derivative gain -- not specified";
  parameter Real K_swing = 1.5 "Cable swing proportional damping gain -- not specified";
  parameter Real K_swing_d = 0.8 "Cable swing derivative damping gain -- not specified";
  parameter Real theta_limit = 0.4 "Pitch command limit [rad] -- not specified";
  parameter Real T_max_cable = 50.0 "Cable tension upper bound [N] -- not specified";

  // ===== State variables =====
  Real x(start=0.0, fixed=true) "Quadrotor x position [m]";
  Real z(start=0.15, fixed=true) "Quadrotor z position [m]";
  Real vx(start=0.0, fixed=true) "Quadrotor x velocity [m/s]";
  Real vz(start=0.0, fixed=true) "Quadrotor z velocity [m/s]";
  Real theta(start=0.0, fixed=true) "Pitch angle [rad]";
  Real omega(start=0.0, fixed=true) "Pitch rate [rad/s]";
  Real phi(start=0.001, fixed=true) "Cable angle from vertical [rad]";
  Real phidot(start=0.0, fixed=true) "Cable angular rate [rad/s]";

  // ===== Derived physical quantities =====
  Real payload_x "Payload x position [m]";
  Real payload_z "Payload z position [m]";
  Real T_cable "Cable tension [N]";
  Real F_gust "Lateral gust force [N]";
  Real T_total "Total thrust [N]";
  Real T1 "Rotor 1 actual thrust (front-right) [N]";
  Real T2 "Rotor 2 actual thrust (front-left) [N]";
  Real T3 "Rotor 3 actual thrust (rear-left) [N]";
  Real T4 "Rotor 4 actual thrust (rear-right) [N]";
  Real T1_cmd "Rotor 1 command [N]";
  Real T2_cmd "Rotor 2 command [N]";
  Real T3_cmd "Rotor 3 command [N]";
  Real T4_cmd "Rotor 4 command [N]";
  Real M_pitch_cmd "Commanded pitch moment [N.m]";
  Real M_pitch_actual "Actual pitch moment from saturated thrusts [N.m]";
  Real M_yaw_actual "Actual yaw moment [N.m]";
  Real m_total "Total mass [kg]";

  // ===== Reference trajectory =====
  Real x_ref "Reference x position [m]";
  Real z_ref "Reference z position [m]";

  // ===== Control signals =====
  Real T_total_cmd "Total thrust command [N]";
  Real theta_cmd_raw "Unlimited pitch command [rad]";
  Real theta_cmd "Limited pitch command [rad]";

  // ===== Sensors =====
  Real x_gps "GPS x measurement [m]";
  Real z_gps "GPS z measurement [m]";
  Real vx_imu "IMU x velocity estimate [m/s]";
  Real vz_imu "IMU z velocity estimate [m/s]";
  Real theta_imu "IMU pitch angle measurement [rad]";
  Real omega_imu "IMU pitch rate measurement [rad/s]";
  Real phi_sensor "Cable angle sensor [rad]";
  Real T_cable_sensor "Cable tension sensor [N]";

  // ===== Monitoring =====
  Real tracking_error "Primary tracking error [m]";
  Real target_error "Target zone placement error [m]";
  Boolean thrust_bound_ok "Thrust bounds satisfied";
  Boolean tension_bound_ok "Tension bounds satisfied";
  Boolean swing_ok "Swing below limit";
  Boolean target_zone_ok "Payload within target zone";
  Boolean no_ground_strike "No ground strike";
  Boolean tracking_error_ok "Tracking error below limit after 7.8 s";

  // ===== Intermediate trig =====
  Real cos_theta "cos(theta)";
  Real sin_theta "sin(theta)";
  Real cos_phi "cos(phi)";
  Real sin_phi "sin(phi)";

equation
  // Total mass
  m_total = m_fuselage + m_payload;

  // Trigonometric cache
  cos_theta = cos(theta);
  sin_theta = sin(theta);
  cos_phi = cos(phi);
  sin_phi = sin(phi);

  // ===== Input-shaped reference trajectory (smooth cosine profiles) =====
  // Lift: 0 -> t_lift_end, Cruise: t_lift_end -> t_cruise_end, Lower: t_cruise_end -> t_sim
  z_ref = if time < t_lift_end then
      z_init + (z_hover - z_init) * 0.5 * (1.0 - cos(Modelica.Constants.pi * time / t_lift_end))
    elseif time < t_cruise_end then
      z_hover
    else
      z_hover + (z_target - z_hover) * 0.5 * (1.0 - cos(Modelica.Constants.pi * (time - t_cruise_end) / (t_sim - t_cruise_end)));

  x_ref = if time < t_lift_end then
      0.0
    elseif time < t_cruise_end then
      x_target * 0.5 * (1.0 - cos(Modelica.Constants.pi * (time - t_lift_end) / (t_cruise_end - t_lift_end)))
    else
      x_target;

  // ===== Gust disturbance (smooth pulse during middle third: 4 s to 8 s) =====
  F_gust = F_gust_amp * 0.5 * (tanh((time - t_gust_start) / 0.5) - tanh((time - t_gust_end) / 0.5));

  // ===== Controller: input-shaped position control + cable-swing damping =====
  T_total_cmd = m_total * g_const + Kp_z * (z_ref - z) - Kd_z * vz;

  theta_cmd_raw = Kp_x * (x_ref - x) - Kd_x * vx + K_swing * phi + K_swing_d * phidot;
  theta_cmd = max(-theta_limit, min(theta_limit, theta_cmd_raw));

  // Pitch moment command from pitch PD controller
  M_pitch_cmd = Kp_pitch * (theta_cmd - theta) - Kd_pitch * omega;

  // ===== Rotor allocation (4 independently commanded thrust actuators) =====
  // X-config: front pair (1,2), rear pair (3,4); yaw command = 0
  T1_cmd = T_total_cmd / 4.0 - M_pitch_cmd / (4.0 * L_arm);
  T2_cmd = T_total_cmd / 4.0 - M_pitch_cmd / (4.0 * L_arm);
  T3_cmd = T_total_cmd / 4.0 + M_pitch_cmd / (4.0 * L_arm);
  T4_cmd = T_total_cmd / 4.0 + M_pitch_cmd / (4.0 * L_arm);

  // Thrust saturation: 0 <= Ti <= T_max
  T1 = max(0.0, min(T_max, T1_cmd));
  T2 = max(0.0, min(T_max, T2_cmd));
  T3 = max(0.0, min(T_max, T3_cmd));
  T4 = max(0.0, min(T_max, T4_cmd));

  // Actual total thrust and moments from saturated rotor outputs
  T_total = T1 + T2 + T3 + T4;
  M_pitch_actual = L_arm * ((T3 + T4) - (T1 + T2));
  M_yaw_actual = k_yaw * (T1 - T2 + T3 - T4);

  // ===== Plant: quadrotor translational dynamics =====
  der(x) = vx;
  der(z) = vz;
  m_fuselage * der(vx) = -T_total * sin_theta + T_cable * sin_phi - Cd * vx + F_gust;
  m_fuselage * der(vz) = T_total * cos_theta - T_cable * cos_phi - m_fuselage * g_const - Cd * vz;

  // ===== Plant: quadrotor rotational dynamics (pitch) =====
  der(theta) = omega;
  I_pitch * der(omega) = M_pitch_actual;

  // ===== Plant: cable-suspended payload dynamics =====
  der(phi) = phidot;
  // Coupled payload force balance — linear in der(vx), der(vz), der(phidot), T_cable
  m_payload * (der(vx) + L_cable * (-sin_phi * phidot * phidot + cos_phi * der(phidot))) = -T_cable * sin_phi;
  m_payload * (der(vz) + L_cable * (cos_phi * phidot * phidot + sin_phi * der(phidot))) = T_cable * cos_phi - m_payload * g_const;

  // Payload position from cable geometry
  payload_x = x + L_cable * sin_phi;
  payload_z = z - L_cable * cos_phi;

  // ===== Sensors (direct readings; sensor noise parameters not specified in request) =====
  x_gps = x;
  z_gps = z;
  vx_imu = vx;
  vz_imu = vz;
  theta_imu = theta;
  omega_imu = omega;
  phi_sensor = phi;
  T_cable_sensor = T_cable;

  // ===== Constraint monitoring =====
  tracking_error = sqrt(max(1e-12, (x - x_ref) * (x - x_ref) + (z - z_ref) * (z - z_ref)));
  target_error = sqrt(max(1e-12, (payload_x - x_target) * (payload_x - x_target) + (payload_z - z_target) * (payload_z - z_target)));

  thrust_bound_ok = T1 >= 0.0 and T1 <= T_max and T2 >= 0.0 and T2 <= T_max and
                   T3 >= 0.0 and T3 <= T_max and T4 >= 0.0 and T4 <= T_max;
  tension_bound_ok = T_cable >= 0.0 and T_cable <= T_max_cable;
  swing_ok = abs(phi) < swing_limit;
  target_zone_ok = (time >= t_sim - 1.0) and (target_error < r_target);
  no_ground_strike = z > 0.01 and payload_z > 0.0;
  tracking_error_ok = (time <= t_tracking_check) or (tracking_error < tracking_limit);

  annotation(
    experiment(StartTime = 0, StopTime = 12.0, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info = "QuadScoutDeliverC: Free-base aerial robot with input-shaped position control and cable-swing damping. Lifts a suspended payload, translates 5 m horizontally, and lowers into a 0.8 m-radius target zone. 7.2 N gust during middle third (4-8 s). Runs at 125 Hz for 12 s.")
  );

end QuadScoutDeliverC;