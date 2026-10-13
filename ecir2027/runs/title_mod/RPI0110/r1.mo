model CoaxLiftDeliverB
  "Free-base coaxial aerial robot: lift, translate 5 m, lower payload into target zone";

  // --- Physical parameters ---
  parameter Real m_p = 4.4 "Platform mass [kg]";
  parameter Real m_l = 1.2 "Payload mass [kg]";
  parameter Real L_cable = 0.70 "Cable length [m]";
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real c_d = 0.05 "Aerodynamic drag coefficient [N.s2/m2]";
  parameter Real f_max_rotor = 8.2 "Max thrust per rotor [N]";
  parameter Real n_rotors = 8.0 "Number of rotor thrust channels";
  parameter Real F_max_total = f_max_rotor * n_rotors "Total max thrust [N]";
  parameter Real T_max = 30.0 "Max cable tension bound [N]";
  parameter Real theta_max = 0.45 "Max swing angle [rad]";
  parameter Real target_radius = 0.80 "Target zone radius [m]";
  parameter Real track_err_max = 0.36 "Max tracking error after 6.5 s [m]";
  parameter Real z_ground = 0.0 "Ground level [m]";
  parameter Real z_min_clearance = 0.50 "Min platform height for no ground strike [m]";
  parameter Real pi = 3.14159265358979 "Pi constant";

  // --- Controller gains ---
  parameter Real kp_x = 20.0 "Horizontal position gain [N/m]";
  parameter Real kd_x = 12.0 "Horizontal velocity gain [N.s/m]";
  parameter Real kp_z = 15.0 "Vertical position gain [N/m]";
  parameter Real kd_z = 8.0 "Vertical velocity gain [N.s/m]";
  parameter Real k_swing = 5.0 "Cable swing damping gain [N.s/rad]";

  // --- Mission timeline ---
  parameter Real x_target = 5.0 "Target horizontal position [m]";
  parameter Real z_cruise = 2.0 "Cruise height [m]";
  parameter Real z_final = 0.80 "Final platform height [m]";
  parameter Real t_lift_end = 2.0 "Lift phase end time [s]";
  parameter Real t_cruise_end = 7.0 "Cruise phase end time [s]";
  parameter Real t_total = 10.0 "Total mission duration [s]";
  parameter Real t_gust_start = 10.0 / 3.0 "Gust start (middle third) [s]";
  parameter Real t_gust_end = 20.0 / 3.0 "Gust end (middle third) [s]";
  parameter Real gust_force = 5.6 "Gust force magnitude [N]";
  parameter Real gust_ramp = 0.20 "Gust ramp duration [s]";

  // --- Initial conditions ---
  parameter Real x_p0 = 0.0 "Initial platform x [m]";
  parameter Real z_p0 = 1.2 "Initial platform z [m]";
  parameter Real vx_p0 = 0.0 "Initial platform vx [m/s]";
  parameter Real vz_p0 = 0.0 "Initial platform vz [m/s]";
  parameter Real theta0 = 0.0 "Initial cable angle [rad]";
  parameter Real theta_dot0 = 0.0 "Initial cable angular rate [rad/s]";

  // --- Dynamic states ---
  Real x_p(start = x_p0, fixed = true) "Platform x position [m]";
  Real z_p(start = z_p0, fixed = true) "Platform z position [m]";
  Real vx_p(start = vx_p0, fixed = true) "Platform x velocity [m/s]";
  Real vz_p(start = vz_p0, fixed = true) "Platform z velocity [m/s]";
  Real theta(start = theta0, fixed = true) "Cable angle from vertical [rad]";
  Real theta_dot(start = theta_dot0, fixed = true) "Cable angular velocity [rad/s]";

  // --- Payload kinematics ---
  Real x_l "Payload x position [m]";
  Real z_l "Payload z position [m]";

  // --- Accelerations ---
  Real ax_p "Platform x acceleration [m/s2]";
  Real az_p "Platform z acceleration [m/s2]";
  Real theta_ddot "Cable angular acceleration [rad/s2]";

  // --- Cable tension ---
  Real T "Cable tension [N]";
  Real denom "Tension denominator (non-singular)";

  // --- Reference trajectory ---
  Real x_ref "Reference x position [m]";
  Real z_ref "Reference z position [m]";
  Real vx_ref "Reference x velocity [m/s]";
  Real vz_ref "Reference z velocity [m/s]";

  // --- Control commands ---
  Real F_x_cmd "Unsaturated horizontal force [N]";
  Real F_z_cmd "Unsaturated vertical force [N]";
  Real F_x "Saturated horizontal force [N]";
  Real F_z "Saturated vertical force [N]";
  Real F_total "Total thrust magnitude [N]";
  Real f_per_rotor "Thrust per rotor [N]";
  Real total_cmd "Unsaturated total thrust [N]";
  Real scale "Thrust saturation scale factor";

  // --- Disturbances ---
  Real gust "Gust force [N]";
  Real drag_x "Aerodynamic drag x [N]";
  Real drag_z "Aerodynamic drag z [N]";

  // --- Sensors ---
  Real imu_ax "IMU x acceleration [m/s2]";
  Real imu_az "IMU z acceleration [m/s2]";
  Real gps_x "GPS x position [m]";
  Real gps_z "GPS z position [m]";
  Real cable_angle_meas "Cable angle measurement [rad]";
  Real tension_meas "Tension measurement [N]";

  // --- Mission metrics ---
  Real tracking_error "Primary platform tracking error [m]";
  Real placement_error "Payload distance from target center [m]";

  // --- Constraint flags ---
  Boolean thrust_bound_ok "Thrust within per-rotor bound";
  Boolean tension_bound_ok "Tension within bounds and positive";
  Boolean swing_ok "Swing below 0.45 rad";
  Boolean no_ground_strike "Platform above ground clearance";
  Boolean tracking_ok "Tracking error below 0.36 m after 6.5 s";
  Boolean target_reached "Payload within 0.8 m target zone";

  // --- Smoothstep helpers ---
  Real ss_x "Smoothstep for horizontal translation";
  Real ss_x_dot "Derivative of ss_x";
  Real ss_z1 "Smoothstep for lift";
  Real ss_z1_dot "Derivative of ss_z1";
  Real ss_z2 "Smoothstep for lower";
  Real ss_z2_dot "Derivative of ss_z2";
  Real ss_g_on "Smoothstep for gust onset";
  Real ss_g_off "Smoothstep for gust offset";

equation
  // ============================
  // Reference trajectory (input-shaped via raised-cosine smoothstep)
  // ============================

  // Horizontal: translate during cruise phase
  ss_x = if time <= t_lift_end then 0.0
         else if time >= t_cruise_end then 1.0
         else 0.5 * (1.0 - cos(pi * (time - t_lift_end) / (t_cruise_end - t_lift_end)));

  ss_x_dot = if time <= t_lift_end then 0.0
             else if time >= t_cruise_end then 0.0
             else 0.5 * pi / (t_cruise_end - t_lift_end) *
                  sin(pi * (time - t_lift_end) / (t_cruise_end - t_lift_end));

  // Vertical: lift phase
  ss_z1 = if time <= 0.0 then 0.0
          else if time >= t_lift_end then 1.0
          else 0.5 * (1.0 - cos(pi * time / t_lift_end));

  ss_z1_dot = if time <= 0.0 then 0.0
              else if time >= t_lift_end then 0.0
              else 0.5 * pi / t_lift_end * sin(pi * time / t_lift_end);

  // Vertical: lower phase
  ss_z2 = if time <= t_cruise_end then 0.0
          else if time >= t_total then 1.0
          else 0.5 * (1.0 - cos(pi * (time - t_cruise_end) / (t_total - t_cruise_end)));

  ss_z2_dot = if time <= t_cruise_end then 0.0
              else if time >= t_total then 0.0
              else 0.5 * pi / (t_total - t_cruise_end) *
                   sin(pi * (time - t_cruise_end) / (t_total - t_cruise_end));

  x_ref = x_target * ss_x;
  z_ref = z_p0 + (z_cruise - z_p0) * ss_z1 + (z_final - z_cruise) * ss_z2;
  vx_ref = x_target * ss_x_dot;
  vz_ref = (z_cruise - z_p0) * ss_z1_dot + (z_final - z_cruise) * ss_z2_dot;

  // ============================
  // Gust disturbance (middle third of mission)
  // ============================
  ss_g_on = if time <= t_gust_start then 0.0
            else if time >= t_gust_start + gust_ramp then 1.0
            else 0.5 * (1.0 - cos(pi * (time - t_gust_start) / gust_ramp));

  ss_g_off = if time <= t_gust_end then 0.0
             else if time >= t_gust_end + gust_ramp then 1.0
             else 0.5 * (1.0 - cos(pi * (time - t_gust_end) / gust_ramp));

  gust = gust_force * (ss_g_on - ss_g_off);

  // ============================
  // Aerodynamic drag (quadratic, smoothed near zero)
  // ============================
  drag_x = c_d * vx_p * sqrt(vx_p * vx_p + 1e-10);
  drag_z = c_d * vz_p * sqrt(vz_p * vz_p + 1e-10);

  // ============================
  // Controller: PD position tracking + cable-swing damping
  // ============================
  F_x_cmd = kp_x * (x_ref - x_p) + kd_x * (vx_ref - vx_p)
            - k_swing * theta_dot * cos(theta);
  F_z_cmd = kp_z * (z_ref - z_p) + kd_z * (vz_ref - vz_p)
            + (m_p + m_l) * g;

  // ============================
  // Thrust saturation (preserve direction, limit magnitude)
  // ============================
  total_cmd = sqrt(F_x_cmd * F_x_cmd + F_z_cmd * F_z_cmd + 1e-10);
  scale = if total_cmd > F_max_total then F_max_total / total_cmd else 1.0;
  F_x = F_x_cmd * scale;
  F_z = F_z_cmd * scale;
  F_total = sqrt(F_x * F_x + F_z * F_z + 1e-10);
  f_per_rotor = F_total / n_rotors;

  // ============================
  // Cable tension (explicit closed-form, non-singular)
  // ============================
  denom = 1.0 + (m_l / m_p) * (cos(theta) * cos(theta) - sin(theta) * sin(theta));
  T = (m_l * g * cos(theta)
       - (m_l / m_p) * sin(theta) * (F_x + gust - drag_x)
       + (m_l / m_p) * cos(theta) * (F_z - m_p * g - drag_z)
       + m_l * L_cable * theta_dot * theta_dot) / denom;

  // ============================
  // Platform dynamics
  // ============================
  ax_p = (F_x + gust - T * sin(theta) - drag_x) / m_p;
  az_p = (F_z - m_p * g - T * cos(theta) - drag_z) / m_p;

  // ============================
  // Cable swing dynamics
  // ============================
  theta_ddot = -(g * sin(theta) + ax_p * cos(theta) + az_p * sin(theta)) / L_cable;

  // ============================
  // State integration
  // ============================
  der(x_p) = vx_p;
  der(z_p) = vz_p;
  der(vx_p) = ax_p;
  der(vz_p) = az_p;
  der(theta) = theta_dot;
  der(theta_dot) = theta_ddot;

  // ============================
  // Payload position
  // ============================
  x_l = x_p + L_cable * sin(theta);
  z_l = z_p - L_cable * cos(theta);

  // ============================
  // Sensor outputs (ideal, synchronized traces)
  // ============================
  imu_ax = ax_p;
  imu_az = az_p;
  gps_x = x_p;
  gps_z = z_p;
  cable_angle_meas = theta;
  tension_meas = max(T, 0.0);

  // ============================
  // Mission metrics
  // ============================
  tracking_error = sqrt((x_ref - x_p) * (x_ref - x_p)
                        + (z_ref - z_p) * (z_ref - z_p) + 1e-12);
  placement_error = sqrt((x_target - x_l) * (x_target - x_l)
                         + (z_ground - z_l) * (z_ground - z_l) + 1e-12);

  // ============================
  // Constraint checks
  // ============================
  thrust_bound_ok = f_per_rotor <= f_max_rotor;
  tension_bound_ok = (T >= 0.0) and (T <= T_max);
  swing_ok = abs(theta) <= theta_max;
  no_ground_strike = z_p >= z_min_clearance;
  tracking_ok = (time < 6.5) or (tracking_error <= track_err_max);
  target_reached = placement_error <= target_radius;

  annotation(
    experiment(StartTime = 0, StopTime = 10, Tolerance = 1e-6, Interval = 0.01),
    Documentation(info = "CoaxLiftDeliverB: 8-rotor coaxial aerial robot lifting a 1.2 kg
      payload on a 0.70 m cable, translating 5 m horizontally, and lowering into a
      0.8 m-radius target zone. Input-shaped position control with cable-swing damping.
      5.6 N lateral gust injected during the middle third. Simulated at 100 Hz for 10 s."));
end CoaxLiftDeliverB;