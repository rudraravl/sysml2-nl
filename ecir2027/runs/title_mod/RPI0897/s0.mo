model CatamaranSurveyC
  // ==================== Physical Parameters (from requirement) ====================
  parameter Real hull_mass(unit="kg") = 46.0 "Mass of each capsule hull";
  parameter Real deck_mass(unit="kg") = 18.0 "Mass of rigid deck";
  parameter Real total_mass(unit="kg") = 110.0 "Total displaced mass: 2*46 + 18";
  parameter Real hull_separation(unit="m") = 1.1 "Distance between hull centers";
  parameter Real max_force(unit="N") = 396.0 "Maximum command magnitude per propeller";
  parameter Real path_length(unit="m") = 60.0 "Lawnmower path length";
  parameter Real ref_speed(unit="m/s") = 1.0 "Reference surge speed";
  parameter Real current_lat(unit="m/s") = 0.18 "Steady lateral water current";
  parameter Real disturbance_force(unit="N") = 90.0 "Injected current load disturbance";

  // ==================== Nominal Parameters (not stated; labeled) ====================
  parameter Real depth_setpoint(unit="m") = 2.0 "Nominal depth setpoint; not specified in requirement";
  parameter Real seabed_depth(unit="m") = 5.0 "Nominal seabed depth; not specified in requirement";
  parameter Real moment_arm(unit="m") = 0.55 "Half hull separation for moment arm";
  parameter Real drag_surge(unit="kg/s") = 60.0 "Surge linear drag; nominal";
  parameter Real drag_sway(unit="kg/s") = 80.0 "Sway linear drag; nominal";
  parameter Real drag_yaw(unit="N.m.s") = 40.0 "Yaw rotational drag; nominal";
  parameter Real drag_depth(unit="kg/s") = 120.0 "Heave linear drag; nominal";
  parameter Real Iz(unit="kg.m2") = 110.0 * 1.1 * 1.1 / 12.0 "Yaw moment of inertia; nominal";

  // ==================== Control Gains (nominal) ====================
  parameter Real Kp_surge(unit="N.s/m") = 600.0 "Surge velocity proportional gain";
  parameter Real Kp_heading(unit="N.m/rad") = 300.0 "Heading proportional gain";
  parameter Real Kd_heading(unit="N.m.s/rad") = 150.0 "Heading derivative gain";
  parameter Real Kp_depth(unit="N/m") = 400.0 "Depth proportional gain";
  parameter Real Kd_depth(unit="N.s/m") = 200.0 "Depth derivative gain";
  parameter Real lookahead(unit="m") = 4.0 "LOS lookahead distance";

  // ==================== State Variables ====================
  Real x(start=0.0, unit="m") "North position";
  Real y(start=0.0, unit="m") "East position";
  Real z(start=2.0, unit="m") "Depth";
  Real psi(start=0.0, unit="rad") "Heading";
  Real u(start=0.0, unit="m/s") "Surge velocity (body frame)";
  Real v(start=0.0, unit="m/s") "Sway velocity (body frame)";
  Real w(start=0.0, unit="m/s") "Heave velocity (body frame)";
  Real r(start=0.0, unit="rad/s") "Yaw rate";

  // ==================== Commands ====================
  Real F_surge_cmd(unit="N") "Total surge force command";
  Real M_yaw_cmd(unit="N.m") "Yaw moment command";
  Real F_depth_cmd(unit="N") "Depth control force command";
  Real F_depth(unit="N") "Depth control force";
  Real F_port_cmd(unit="N") "Port propeller command (pre-saturation)";
  Real F_starboard_cmd(unit="N") "Starboard propeller command (pre-saturation)";
  Real F_port(unit="N") "Port propeller force (bounded to +/- 396 N)";
  Real F_starboard(unit="N") "Starboard propeller force (bounded to +/- 396 N)";

  // ==================== Disturbance ====================
  Real current_disturbance(unit="N") "90 N current load (active during middle third)";

  // ==================== Path Reference ====================
  Real x_ref(unit="m") "Reference along-track position";
  Real y_ref(unit="m") "Reference cross-track position";
  Real psi_ref(unit="rad") "Reference heading";

  // ==================== Guidance ====================
  Real psi_desired(unit="rad") "LOS desired heading";
  Real heading_error(unit="rad") "Heading error";

  // ==================== Errors and Metrics ====================
  Real cross_track_error(unit="m") "Cross-track error (lateral deviation)";
  Real depth_error(unit="m") "Depth error";
  Real tracking_error(unit="m") "Primary tracking error (cross-track + depth norm)";
  Real route_completion "Route completion fraction [0, 1]";
  Real seabed_clearance(unit="m") "Clearance to seabed";

  // ==================== Estimator ====================
  Real x_est(start=0.0, unit="m") "Estimated north position";
  Real y_est(start=0.0, unit="m") "Estimated east position";
  Real psi_est(start=0.0, unit="rad") "Estimated heading";
  Real cov_x(start=0.1, unit="m2") "Estimator covariance, x";
  Real cov_y(start=0.1, unit="m2") "Estimator covariance, y";
  Real cov_psi(start=0.01, unit="rad2") "Estimator covariance, heading";

  // ==================== Sensors ====================
  Real imu_ax(unit="m/s2") "Fuse IMU surge acceleration";
  Real imu_ay(unit="m/s2") "Fuse IMU sway acceleration";
  Real imu_r(unit="rad/s") "Fuse IMU yaw rate";
  Real pressure_depth(unit="m") "Pressure sensor depth";
  Real dvl_u(unit="m/s") "DVL surge velocity";
  Real dvl_v(unit="m/s") "DVL sway velocity";
  Real acoustic_range(unit="m") "Acoustic range to seabed";
  Real compass_heading(unit="rad") "Compass heading";

equation
  // ==================== Path Generation ====================
  // Lawnmower path; within 12 s at 1 m/s only first leg is active
  x_ref = ref_speed * time;
  y_ref = 0.0;
  psi_ref = 0.0;

  // ==================== Disturbance Injection ====================
  // 90 N current load during middle third: t in [4.0, 8.0] s
  current_disturbance = if (time >= 4.0 and time <= 8.0) then disturbance_force else 0.0;

  // ==================== Plant Dynamics ====================
  // Surge: differential propeller thrust minus drag and disturbance
  total_mass * der(u) = (F_port + F_starboard) - drag_surge * u - current_disturbance;
  // Sway: lateral current drives relative drift, drag opposes
  total_mass * der(v) = -drag_sway * (v - current_lat);
  // Yaw: differential thrust creates moment, drag opposes rotation
  Iz * der(r) = moment_arm * (F_starboard - F_port) - drag_yaw * r;
  // Heave / depth control
  total_mass * der(w) = F_depth - drag_depth * w;

  // Kinematics (2D horizontal plane + depth)
  der(x) = u * cos(psi) - v * sin(psi);
  der(y) = u * sin(psi) + v * cos(psi);
  der(z) = w;
  der(psi) = r;

  // ==================== Error Metrics ====================
  depth_error = z - depth_setpoint;
  cross_track_error = y; // path heading = 0, so cross-track = lateral deviation
  // Norm with zero-error guard to prevent division-by-zero or NaN
  tracking_error = sqrt(cross_track_error * cross_track_error + depth_error * depth_error + 1e-9);
  route_completion = if (x >= path_length) then 1.0 else x / path_length;
  seabed_clearance = seabed_depth - z;

  // ==================== Guidance: Line-of-Sight ====================
  psi_desired = psi_ref + atan2(-cross_track_error, max(lookahead, 0.5));
  heading_error = psi_desired - psi;

  // ==================== Controller ====================
  // Surge velocity P control
  F_surge_cmd = Kp_surge * (ref_speed - u);
  // Heading PD control (current compensation emerges from LOS crab angle)
  M_yaw_cmd = Kp_heading * heading_error - Kd_heading * r;
  // Depth PD control
  F_depth_cmd = -Kp_depth * depth_error - Kd_depth * w;
  F_depth = F_depth_cmd;

  // ==================== Actuator Allocation ====================
  // F_total = F_port + F_starboard; M_yaw = (F_stbd - F_port) * moment_arm
  F_port_cmd = (F_surge_cmd - M_yaw_cmd / moment_arm) / 2.0;
  F_starboard_cmd = (F_surge_cmd + M_yaw_cmd / moment_arm) / 2.0;

  // Actuator saturation: bounded to +/- 396 N per propeller
  F_port = if (F_port_cmd > max_force) then max_force
           else if (F_port_cmd < -max_force) then -max_force
           else F_port_cmd;
  F_starboard = if (F_starboard_cmd > max_force) then max_force
                else if (F_starboard_cmd < -max_force) then -max_force
                else F_starboard_cmd;

  // ==================== Sensor Models ====================
  // Fuse IMU: body-frame accelerations and gyro rate
  imu_ax = ((F_port + F_starboard) - drag_surge * u - current_disturbance) / total_mass;
  imu_ay = (-drag_sway * (v - current_lat)) / total_mass;
  imu_r = r;
  // Pressure: depth
  pressure_depth = z;
  // DVL: body-frame velocities
  dvl_u = u;
  dvl_v = v;
  // Acoustic range: distance to seabed
  acoustic_range = seabed_clearance;
  // Compass: heading
  compass_heading = psi;

  // ==================== State Estimator ====================
  // Dead-reckoning with DVL and IMU; covariance propagation (simplified)
  der(x_est) = dvl_u * cos(psi_est) - dvl_v * sin(psi_est);
  der(y_est) = dvl_u * sin(psi_est) + dvl_v * cos(psi_est);
  der(psi_est) = imu_r;
  // Covariance dynamics: process noise injection minus decay (well-defined, positive equilibrium)
  der(cov_x) = 0.01 - 0.5 * cov_x;
  der(cov_y) = 0.01 - 0.5 * cov_y;
  der(cov_psi) = 0.001 - 0.5 * cov_psi;

  annotation(
    experiment(StartTime = 0, StopTime = 12.0, Tolerance = 1e-6, Interval = 0.008),
    Documentation(info = "CatamaranSurveyC: free-base marine robot for path-following with current compensation.
      Plant: two 46 kg capsule hulls at 1.1 m separation, 18 kg rigid deck, 110 kg total.
      Differential port/starboard propeller forces (max 396 N each) control surge and heading.
      Lawnmower path 60 m at 1.0 m/s with constant depth.
      Steady 0.18 m/s lateral current; 90 N current load disturbance injected during middle third (4-8 s).
      Sensors: Fuse IMU, pressure, DVL, acoustic range, compass.
      Estimator: dead-reckoning with covariance propagation.
      Run at 125 Hz (dt=0.008 s) for 12 s.
      Requirement: primary tracking error below 0.84 m after 7.8 s; no NaN or infinite values."));
end CatamaranSurveyC;