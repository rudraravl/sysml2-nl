model DuctInspectSurveyA
  "Free-base ducted-fan aerial robot for inspection survey"

  // === Physical parameters ===
  parameter Real m = 2.7 "body mass [kg]";
  parameter Real g = 9.81 "gravitational acceleration [m/s2]";
  parameter Real L_probe = 0.18 "compliant inspection probe length along body X [m]";
  // Probe stiffness/damping not specified; compliance not modeled
  parameter Real d_arm = 0.20 "duct fan moment arm [m]";
  parameter Real J_roll = 0.015 "roll moment of inertia [kg.m2]";
  parameter Real J_pitch = 0.015 "pitch moment of inertia [kg.m2]";

  // === Actuator limits ===
  parameter Real F_fan_max = 13.0 "per-fan thrust command magnitude limit [N]";
  parameter Real F_probe_max = 13.0 "probe-force command magnitude limit [N]";
  parameter Real tau_fan = 0.015 "fan actuator time constant [s]";
  parameter Real tau_probe = 0.02 "probe actuator time constant [s]";

  // === Controller gains ===
  parameter Real Kp_pos = 4.0 "position proportional gain [1/s2]";
  parameter Real Kd_pos = 3.5 "position derivative gain [1/s]";
  parameter Real Kp_att = 12.0 "attitude proportional gain [1/s2]";
  parameter Real Kd_att = 5.0 "attitude rate derivative gain [1/s]";

  // === Waypoints and deadlines ===
  parameter Real wp_x[4] = {0.0, 4.0, 4.0, 1.0} "waypoint x [m]";
  parameter Real wp_y[4] = {0.0, 0.0, 3.0, 4.0} "waypoint y [m]";
  parameter Real wp_z[4] = {1.5, 2.5, 2.5, 2.0} "waypoint z [m]";
  parameter Real wp_t[4] = {0.0, 2.667, 5.333, 8.0} "waypoint deadlines [s]";

  // === Obstacles (fixed cylinders outside reference polyline) ===
  parameter Real obs_x[3] = {2.0, 5.5, 2.5} "obstacle center x [m]";
  parameter Real obs_y[3] = {-1.0, 1.5, 5.0} "obstacle center y [m]";
  parameter Real obs_r[3] = {0.25, 0.25, 0.25} "obstacle radius [m]";

  // === Estimator gains ===
  parameter Real L1 = 4.0 "estimator position correction gain [1/s]";
  parameter Real L2 = 9.0 "estimator velocity correction gain [1/s2]";
  parameter Real L_att = 5.0 "attitude estimator gain [1/s]";

  // === Disturbance ===
  parameter Real F_crosswind = 3.0 "crosswind disturbance force [N]";

  // === True states ===
  Real x(start=0.0, fixed=true) "position x [m]";
  Real y(start=0.0, fixed=true) "position y [m]";
  Real z(start=1.5, fixed=true) "position z [m]";
  Real vx(start=0.0, fixed=true) "velocity x [m/s]";
  Real vy(start=0.0, fixed=true) "velocity y [m/s]";
  Real vz(start=0.0, fixed=true) "velocity z [m/s]";
  Real phi(start=0.0, fixed=true) "roll angle [rad]";
  Real theta(start=0.0, fixed=true) "pitch angle [rad]";
  Real phidot(start=0.0, fixed=true) "roll rate [rad/s]";
  Real thetadot(start=0.0, fixed=true) "pitch rate [rad/s]";

  // === Fan thrusts ===
  Real T1(start=6.62, fixed=true) "fan 1 thrust [N]";
  Real T2(start=6.62, fixed=true) "fan 2 thrust [N]";
  Real T3(start=6.62, fixed=true) "fan 3 thrust [N]";
  Real T4(start=6.62, fixed=true) "fan 4 thrust [N]";
  Real Tc1 "fan 1 thrust command [N]";
  Real Tc2 "fan 2 thrust command [N]";
  Real Tc3 "fan 3 thrust command [N]";
  Real Tc4 "fan 4 thrust command [N]";
  Real T_total "total thrust [N]";
  Real T_total_cmd "total thrust command [N]";

  // === Probe force actuator ===
  Real F_probe(start=0.0, fixed=true) "probe force along body X [N]";
  Real F_probe_cmd "probe force command [N]";

  // === Trajectory references ===
  Real rx_des "desired position x [m]";
  Real ry_des "desired position y [m]";
  Real rz_des "desired position z [m]";
  Real vx_des "desired velocity x [m/s]";
  Real vy_des "desired velocity y [m/s]";
  Real vz_des "desired velocity z [m/s]";
  Real ax_ff "feedforward acceleration x [m/s2]";
  Real ay_ff "feedforward acceleration y [m/s2]";
  Real az_ff "feedforward acceleration z [m/s2]";

  // === Controller outputs ===
  Real ax_cmd "commanded acceleration x [m/s2]";
  Real ay_cmd "commanded acceleration y [m/s2]";
  Real az_cmd "commanded acceleration z [m/s2]";
  Real phi_cmd "commanded roll [rad]";
  Real theta_cmd "commanded pitch [rad]";
  Real tau_r "roll torque command [N.m]";
  Real tau_p "pitch torque command [N.m]";

  // === Estimator states ===
  Real x_est(start=0.0, fixed=true) "estimated x [m]";
  Real y_est(start=0.0, fixed=true) "estimated y [m]";
  Real z_est(start=1.5, fixed=true) "estimated z [m]";
  Real vx_est(start=0.0, fixed=true) "estimated vx [m/s]";
  Real vy_est(start=0.0, fixed=true) "estimated vy [m/s]";
  Real vz_est(start=0.0, fixed=true) "estimated vz [m/s]";
  Real phi_est(start=0.0, fixed=true) "estimated roll [rad]";
  Real theta_est(start=0.0, fixed=true) "estimated pitch [rad]";

  // === Sensor measurements ===
  Real ax_imu "IMU specific force x in world frame [m/s2]";
  Real ay_imu "IMU specific force y in world frame [m/s2]";
  Real az_imu "IMU specific force z in world frame [m/s2]";
  Real x_gps "GPS fused x measurement [m]";
  Real y_gps "GPS fused y measurement [m]";
  Real z_alt "altimeter fused z measurement [m]";

  // === Disturbance ===
  Real F_wind_y "crosswind force in y [N]";

  // === Probe tip observable ===
  Real probe_tip_x "probe tip position x [m]";
  Real probe_tip_y "probe tip position y [m]";
  Real probe_tip_z "probe tip position z [m]";

  // === Monitoring ===
  Real wp_error "3D waypoint tracking error [m]";
  Real obs_dist1 "distance to obstacle 1 surface [m]";
  Real obs_dist2 "distance to obstacle 2 surface [m]";
  Real obs_dist3 "distance to obstacle 3 surface [m]";
  Real min_obs_dist "minimum obstacle clearance [m]";
  Real est_norm "estimator state norm [m]";

equation
  // --- Crosswind disturbance (middle third of 8 s scenario: 2.667..5.333 s) ---
  F_wind_y = if (time >= 2.667 and time <= 5.333) then F_crosswind else 0.0;

  // --- Trajectory generation (piecewise linear with constant-velocity feedforward) ---
  if time < wp_t[2] then
    rx_des = wp_x[1] + (wp_x[2] - wp_x[1]) * time / (wp_t[2] - wp_t[1]);
    ry_des = wp_y[1] + (wp_y[2] - wp_y[1]) * time / (wp_t[2] - wp_t[1]);
    rz_des = wp_z[1] + (wp_z[2] - wp_z[1]) * time / (wp_t[2] - wp_t[1]);
    vx_des = (wp_x[2] - wp_x[1]) / (wp_t[2] - wp_t[1]);
    vy_des = (wp_y[2] - wp_y[1]) / (wp_t[2] - wp_t[1]);
    vz_des = (wp_z[2] - wp_z[1]) / (wp_t[2] - wp_t[1]);
  elseif time < wp_t[3] then
    rx_des = wp_x[2] + (wp_x[3] - wp_x[2]) * (time - wp_t[2]) / (wp_t[3] - wp_t[2]);
    ry_des = wp_y[2] + (wp_y[3] - wp_y[2]) * (time - wp_t[2]) / (wp_t[3] - wp_t[2]);
    rz_des = wp_z[2] + (wp_z[3] - wp_z[2]) * (time - wp_t[2]) / (wp_t[3] - wp_t[2]);
    vx_des = (wp_x[3] - wp_x[2]) / (wp_t[3] - wp_t[2]);
    vy_des = (wp_y[3] - wp_y[2]) / (wp_t[3] - wp_t[2]);
    vz_des = (wp_z[3] - wp_z[2]) / (wp_t[3] - wp_t[2]);
  else
    rx_des = wp_x[3] + (wp_x[4] - wp_x[3]) * (time - wp_t[3]) / (wp_t[4] - wp_t[3]);
    ry_des = wp_y[3] + (wp_y[4] - wp_y[3]) * (time - wp_t[3]) / (wp_t[4] - wp_t[3]);
    rz_des = wp_z[3] + (wp_z[4] - wp_z[3]) * (time - wp_t[3]) / (wp_t[4] - wp_t[3]);
    vx_des = (wp_x[4] - wp_x[3]) / (wp_t[4] - wp_t[3]);
    vy_des = (wp_y[4] - wp_y[3]) / (wp_t[4] - wp_t[3]);
    vz_des = (wp_z[4] - wp_z[3]) / (wp_t[4] - wp_t[3]);
  end if;

  // Feedforward acceleration: zero within constant-velocity segments
  ax_ff = 0.0;
  ay_ff = 0.0;
  az_ff = 0.0;

  // --- IMU measurement (specific force in world frame from thrust + attitude) ---
  ax_imu = (T_total / m) * sin(theta);
  ay_imu = -(T_total / m) * sin(phi) * cos(theta);
  az_imu = (T_total / m) * cos(phi) * cos(theta);

  // --- GPS / altimeter / camera fused position measurements ---
  // Sensor noise/latency parameters not specified; idealized fusion
  x_gps = x;
  y_gps = y;
  z_alt = z;

  // --- Estimator: Luenberger observer fusing IMU + GPS + altimeter + camera ---
  der(x_est) = vx_est + L1 * (x_gps - x_est);
  der(vx_est) = ax_imu + L2 * (x_gps - x_est);
  der(y_est) = vy_est + L1 * (y_gps - y_est);
  der(vy_est) = ay_imu + L2 * (y_gps - y_est);
  der(z_est) = vz_est + L1 * (z_alt - z_est);
  der(vz_est) = az_imu - g + L2 * (z_alt - z_est);
  der(phi_est) = phidot + L_att * (phi - phi_est);
  der(theta_est) = thetadot + L_att * (theta - theta_est);

  // --- Bounded waypoint tracking with feedforward acceleration ---
  ax_cmd = ax_ff + Kp_pos * (rx_des - x_est) + Kd_pos * (vx_des - vx_est);
  ay_cmd = ay_ff + Kp_pos * (ry_des - y_est) + Kd_pos * (vy_des - vy_est);
  az_cmd = az_ff + Kp_pos * (rz_des - z_est) + Kd_pos * (vz_des - vz_est);

  // --- Thrust and attitude commands from desired acceleration ---
  T_total_cmd = m * sqrt(max(ax_cmd * ax_cmd + ay_cmd * ay_cmd + (az_cmd + g) * (az_cmd + g), 1e-6));
  theta_cmd = atan2(ax_cmd, az_cmd + g);
  phi_cmd = atan2(-ay_cmd, sqrt(max(ax_cmd * ax_cmd + (az_cmd + g) * (az_cmd + g), 1e-6)));

  // --- Attitude controller (PD on attitude error using estimated states) ---
  tau_r = J_roll * (Kp_att * (phi_cmd - phi_est) - Kd_att * phidot);
  tau_p = J_pitch * (Kp_att * (theta_cmd - theta_est) - Kd_att * thetadot);

  // --- Fan allocation (plus config: front, rear, right, left) ---
  Tc1 = max(0.0, min(F_fan_max, T_total_cmd / 4.0 + tau_p / (2.0 * d_arm)));
  Tc2 = max(0.0, min(F_fan_max, T_total_cmd / 4.0 - tau_p / (2.0 * d_arm)));
  Tc3 = max(0.0, min(F_fan_max, T_total_cmd / 4.0 + tau_r / (2.0 * d_arm)));
  Tc4 = max(0.0, min(F_fan_max, T_total_cmd / 4.0 - tau_r / (2.0 * d_arm)));

  // --- Fan actuator dynamics (first-order lag) ---
  der(T1) = (Tc1 - T1) / tau_fan;
  der(T2) = (Tc2 - T2) / tau_fan;
  der(T3) = (Tc3 - T3) / tau_fan;
  der(T4) = (Tc4 - T4) / tau_fan;
  T_total = T1 + T2 + T3 + T4;

  // --- Probe force actuator (along body X, bounded) ---
  F_probe_cmd = 0.0;
  der(F_probe) = (max(-F_probe_max, min(F_probe_max, F_probe_cmd)) - F_probe) / tau_probe;

  // --- Plant translational dynamics ---
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  der(vx) = ax_imu + F_probe * cos(theta) / m;
  der(vy) = ay_imu + F_wind_y / m;
  der(vz) = az_imu - g - F_probe * sin(theta) / m;

  // --- Plant attitude dynamics ---
  der(phi) = phidot;
  der(theta) = thetadot;
  J_roll * der(phidot) = tau_r;
  J_pitch * der(thetadot) = tau_p;

  // --- Probe tip position (body X with pitch only; yaw = 0) ---
  probe_tip_x = x + L_probe * cos(theta);
  probe_tip_y = y;
  probe_tip_z = z - L_probe * sin(theta);

  // --- Monitoring: waypoint tracking error ---
  wp_error = sqrt(max((rx_des - x) * (rx_des - x) + (ry_des - y) * (ry_des - y) + (rz_des - z) * (rz_des - z), 1e-10));

  // --- Monitoring: obstacle clearance (horizontal distance to cylinder surface) ---
  obs_dist1 = sqrt(max((x - obs_x[1]) * (x - obs_x[1]) + (y - obs_y[1]) * (y - obs_y[1]), 1e-10)) - obs_r[1];
  obs_dist2 = sqrt(max((x - obs_x[2]) * (x - obs_x[2]) + (y - obs_y[2]) * (y - obs_y[2]), 1e-10)) - obs_r[2];
  obs_dist3 = sqrt(max((x - obs_x[3]) * (x - obs_x[3]) + (y - obs_y[3]) * (y - obs_y[3]), 1e-10)) - obs_r[3];
  min_obs_dist = min(obs_dist1, min(obs_dist2, obs_dist3));

  // --- Monitoring: estimator finiteness (state norm) ---
  est_norm = sqrt(max(x_est * x_est + y_est * y_est + z_est * z_est + vx_est * vx_est + vy_est * vy_est + vz_est * vz_est, 1e-10));

  annotation(
    experiment(StartTime=0, StopTime=8, Tolerance=1e-6, Interval=0.0125),
    Documentation(info="Ducted-fan aerial inspection robot (DuctInspectSurveyA). 2.7 kg cylindrical body, four protected ducted fans (13 N/fan limit), 0.18 m compliant probe along body X. Tracks 4 3D waypoints over 8 s at 80 Hz. 3 N crosswind during middle third (2.667-5.333 s). Luenberger estimator fuses IMU, GPS, altimeter, camera. Three fixed cylindrical obstacles placed outside reference polyline. Waypoint deadlines: 0, 2.667, 5.333, 8 s.")
  );
end DuctInspectSurveyA;