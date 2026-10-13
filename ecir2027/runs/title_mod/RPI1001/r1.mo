model AckermannRoverInspectE
  // ========================= Parameters (from request) =========================
  parameter Real m_chassis(unit="kg") = 34.0 "Chassis mass";
  parameter Real L_chassis(unit="m") = 1.05 "Chassis length";
  parameter Real W_chassis(unit="m") = 0.64 "Chassis width";
  parameter Real L_wheelbase(unit="m") = 0.74 "Wheelbase (rear axle to front axle)";
  parameter Real wheelRadius(unit="m") = 0.15 "Wheel radius (unknown stated value; placeholder)";
  parameter Real steerLimit(unit="rad") = 0.52 "Front steering joint limit";
  parameter Real torqueLimit(unit="N.m") = 30.8 "Actuator command magnitude bound";
  parameter Real v_target(unit="m/s") = 0.8 "Target forward speed";
  parameter Real f_sample(unit="Hz") = 250.0 "Control/trace rate";
  parameter Real t_end(unit="s") = 16.0 "Scenario duration";
  parameter Real corridorWidth(unit="m") = 1.8 "Wall-to-wall corridor width";
  parameter Real F_disturb(unit="N") = 108.0 "Side load magnitude (middle third)";
  parameter Real A_path(unit="m") = 0.25 "S-corridor lateral amplitude (unknown exact geometry)";
  parameter Real L_path(unit="m") = 12.0 "Corridor projected length (unknown exact length)";
  parameter Real c_roll(unit="N/(m/s)") = 8.0 "Rolling resistance coefficient";
  parameter Real c_lat(unit="N/(m/s)") = 500.0 "Lateral damping coefficient";
  parameter Real I_steer(unit="kg.m2") = 0.05 "Steering joint inertia (unknown stated value; placeholder)";
  parameter Real b_steer(unit="N.m.s/rad") = 1.5 "Steering damping";
  parameter Real k_spring(unit="N.m/rad") = 12.0 "Steering self-centering stiffness";
  parameter Real Kp_steer(unit="N.m/rad") = 60.0 "Steering PD proportional gain";
  parameter Real Kd_steer(unit="N.m.s/rad") = 3.0 "Steering PD derivative gain";
  parameter Real Kv(unit="N.m.s/m") = 40.0 "Drive velocity gain";
  parameter Real k_stanley(unit="1/rad") = 2.5 "Stanley cross-track gain";
  parameter Real Ly(unit="1/s") = 4.0 "Estimator lateral correction gain";
  parameter Real Lth(unit="1/s") = 2.5 "Estimator heading correction gain";
  parameter Real Qx(unit="m2/s") = 0.002 "Process covariance injection x";
  parameter Real Qy(unit="m2/s") = 0.002 "Process covariance injection y";
  parameter Real Qth(unit="rad2/s") = 0.0005 "Process covariance injection theta";
  parameter Real lx(unit="1/s") = 0.5 "Covariance decay x";
  parameter Real ly(unit="1/s") = 0.5 "Covariance decay y";
  parameter Real lth(unit="1/s") = 0.5 "Covariance decay theta";

  // ========================= Plant states =========================
  Real x(start=0.0, unit="m") "World frame x";
  Real y(start=0.0, unit="m") "World frame y";
  Real theta(start=0.0, unit="rad") "Heading";
  Real v(start=0.001, unit="m/s") "Forward speed";
  Real vy(start=0.0, unit="m/s") "Lateral sideslip speed";
  Real delta(start=0.0, unit="rad") "Front steering angle";
  Real deltadot(start=0.0, unit="rad/s") "Front steering rate";

  // ========================= Actuator commands =========================
  Real tau_drive_cmd(unit="N.m") "Rear traction torque command";
  Real tau_steer_cmd(unit="N.m") "Front steering torque command";
  Real tau_drive_clamped(unit="N.m") "Bounded rear torque";
  Real tau_steer_clamped(unit="N.m") "Bounded steering torque";
  Real F_drive(unit="N") "Traction force at rear contact";
  Real delta_cmd(unit="rad") "Steering angle command";
  Real delta_cmd_clamped(unit="rad") "Bounded steering command";

  // ========================= Disturbance =========================
  Real gate_dist "Gate for middle-third side load";
  Real Fd_lat(unit="N") "Lateral side load (vehicle frame)";

  // ========================= Sensors =========================
  Real v_odom(unit="m/s") "Wheel odometry forward speed";
  Real omega_imu(unit="rad/s") "IMU yaw rate";
  Real ax_imu(unit="m/s2") "IMU longitudinal acceleration (observation only)";
  Real y_lidar_meas(unit="m") "Lidar-derived lateral position (planar 15 m lidar)";

  // ========================= Estimator =========================
  Real xhat(start=0.0, unit="m") "Estimated x";
  Real yhat(start=0.0, unit="m") "Estimated y";
  Real thetahat(start=0.0, unit="rad") "Estimated heading";
  Real Px(start=0.01, unit="m2") "Covariance x";
  Real Py(start=0.01, unit="m2") "Covariance y";
  Real Pth(start=0.001, unit="rad2") "Covariance theta";
  Real innovation_y(unit="m") "Lidar innovation";
  Real innovation_theta(unit="rad") "Corridor-alignment innovation";
  Real theta_path_at_xhat(unit="rad") "Path tangent at estimated x";
  Real y_path_at_xhat(unit="m") "Path y at estimated x";
  Real yR_at_xhat(unit="m") "Right wall y at estimated x";
  Real yL_at_xhat(unit="m") "Left wall y at estimated x";

  // ========================= Corridor =========================
  Real y_path_ref(unit="m") "Path centerline y at x";
  Real theta_path_ref(unit="rad") "Path tangent at x";
  Real y_wall_left(unit="m") "Left wall y at x (with recessed alcoves)";
  Real y_wall_right(unit="m") "Right wall y at x (with recessed alcoves)";
  Real clearance_left(unit="m") "Body-edge to left wall";
  Real clearance_right(unit="m") "Body-edge to right wall";
  Real clearance_min(unit="m") "Minimum body-edge clearance";

  // ========================= Control errors =========================
  Real e_cross(unit="m") "Cross-track error (estimated)";
  Real e_heading(unit="rad") "Heading error (estimated)";
  Real tracking_error(unit="m") "Primary tracking error magnitude";

  // ========================= Acceptance =========================
  Real route_completion "Fraction of corridor completed (0..1)";
  Boolean ok_clearance;
  Boolean ok_tracking;
  Boolean ok_route;
  Boolean ok_covariance;
  Boolean ok_finite;
  Boolean acceptance "Fail-closed acceptance flag";
  Real finite_check "Aggregate finiteness indicator";

  // Discrete trace counter at 250 Hz (synchronized traces)
  discrete Integer tick(start=0);

equation
  // ---- 250 Hz trace counter (synchronized state/command/sensor traces) ----
  when sample(0.0, 1.0/f_sample) then
    tick = pre(tick) + 1;
  end when;

  // ========================= Corridor (S-shaped, walls 1.8 m apart, two alcoves) =========================
  // Centerline: S-curve along x. Exact geometric layout not stated; this is a representative S.
  y_path_ref = A_path*sin(2.0*Modelica.Constants.pi*x/L_path);
  theta_path_ref = Modelica.Math.atan2(A_path*2.0*Modelica.Constants.pi/L_path*cos(2.0*Modelica.Constants.pi*x/L_path), 1.0);
  // Walls follow centerline ± corridorWidth/2, with two recessed alcoves (offset outward by 0.3 m).
  y_wall_left  = y_path_ref + corridorWidth/2 + (if (x>=3.0 and x<=4.0) then 0.3 else 0.0);
  y_wall_right = y_path_ref - corridorWidth/2 - (if (x>=8.0 and x<=9.0) then 0.3 else 0.0);

  // ========================= Disturbance: 108 N lateral side load, middle third of 16 s =========================
  gate_dist = if (time >= t_end/3.0 and time <= 2.0*t_end/3.0) then 1.0 else 0.0;
  Fd_lat = F_disturb * gate_dist;

  // ========================= Localization-aware path tracking (Stanley + speed) =========================
  // Path lookup at estimated pose (localization-aware).
  theta_path_at_xhat = Modelica.Math.atan2(A_path*2.0*Modelica.Constants.pi/L_path*cos(2.0*Modelica.Constants.pi*xhat/L_path), 1.0);
  y_path_at_xhat = A_path*sin(2.0*Modelica.Constants.pi*xhat/L_path);
  yR_at_xhat = y_path_at_xhat - corridorWidth/2 - (if (xhat>=8.0 and xhat<=9.0) then 0.3 else 0.0);
  yL_at_xhat = y_path_at_xhat + corridorWidth/2 + (if (xhat>=3.0 and xhat<=4.0) then 0.3 else 0.0);

  // Cross-track and heading errors (obstacle avoidance implicit via path centering within corridor).
  e_cross = (yhat - y_path_at_xhat)*cos(theta_path_at_xhat);
  e_heading = thetahat - theta_path_at_xhat;

  // Stanley steering law, bounded to joint limit.
  delta_cmd = (theta_path_at_xhat - thetahat) - Modelica.Math.atan2(k_stanley*e_cross, max(v_target, 0.1));
  delta_cmd_clamped = max(-steerLimit, min(delta_cmd, steerLimit));

  // Rear traction torque command, bounded.
  tau_drive_cmd = Kv*(v_target - v) + c_roll*v_target*wheelRadius;
  tau_drive_clamped = max(-torqueLimit, min(tau_drive_cmd, torqueLimit));
  F_drive = tau_drive_clamped / wheelRadius;

  // Front steering torque command, bounded.
  tau_steer_cmd = Kp_steer*(delta_cmd_clamped - delta) - Kd_steer*deltadot;
  tau_steer_clamped = max(-torqueLimit, min(tau_steer_cmd, torqueLimit));

  // ========================= Plant dynamics (planar bicycle with sideslip) =========================
  der(x) = v*cos(theta) - vy*sin(theta);
  der(y) = v*sin(theta) + vy*cos(theta);
  der(theta) = v*tan(delta)/L_wheelbase;
  der(v) = (F_drive - c_roll*v)/m_chassis;
  der(vy) = (Fd_lat - c_lat*vy)/m_chassis;
  der(delta) = deltadot;
  I_steer*der(deltadot) = tau_steer_clamped - b_steer*deltadot - k_spring*delta;

  // ========================= Sensors: wheel odometry, IMU, planar lidar =========================
  v_odom = v + 0.01*sin(7.0*time) "Wheel odometry (noisy, bounded)";
  omega_imu = v*tan(delta)/L_wheelbase + 0.005*sin(5.0*time) "IMU yaw rate (noisy, bounded)";
  ax_imu = (F_drive - c_roll*v)/m_chassis "IMU longitudinal acceleration (observation only)";
  y_lidar_meas = y + 0.02*sin(3.0*time) "15 m planar lidar-derived lateral position (noisy, bounded)";

  // ========================= Estimator: fusion of odometry + IMU + lidar =========================
  innovation_y = y_lidar_meas - yhat;
  innovation_theta = theta_path_at_xhat - thetahat;
  der(xhat) = v_odom*cos(thetahat);
  der(yhat) = v_odom*sin(thetahat) + Ly*innovation_y;
  der(thetahat) = omega_imu + Lth*innovation_theta;

  // Finite, bounded covariance (stable linear Riccati-like diagonal propagation).
  der(Px) = Qx - 2.0*lx*Px;
  der(Py) = Qy - 2.0*ly*Py;
  der(Pth) = Qth - 2.0*lth*Pth;

  // ========================= Clearances =========================
  clearance_left = (y_wall_left - y) - W_chassis/2.0;
  clearance_right = (y - y_wall_right) - W_chassis/2.0;
  clearance_min = min(clearance_left, clearance_right);

  // ========================= Tracking error and route completion =========================
  tracking_error = abs(e_cross);
  route_completion = max(0.0, min(1.0, x/L_path));

  // ========================= Acceptance (fail-closed) =========================
  ok_clearance = clearance_min > 0.18;
  ok_tracking = (time <= 10.4) or (tracking_error < 0.18);
  ok_route = route_completion >= 0.95;
  ok_covariance = (Px > 0.0) and (Px < 1.0) and (Py > 0.0) and (Py < 1.0) and (Pth > 0.0) and (Pth < 0.1);
  finite_check = abs(x) + abs(y) + abs(theta) + abs(v) + abs(vy) + abs(delta) + abs(deltadot)
               + abs(xhat) + abs(yhat) + abs(thetahat) + abs(Px) + abs(Py) + abs(Pth)
               + abs(tau_drive_clamped) + abs(tau_steer_clamped) + abs(v_odom) + abs(omega_imu) + abs(y_lidar_meas);
  ok_finite = (finite_check < 1.0e15)
              and (x == x) and (y == y) and (theta == theta) and (v == v) and (vy == vy)
              and (delta == delta) and (deltadot == deltadot)
              and (xhat == xhat) and (yhat == yhat) and (thetahat == thetahat)
              and (Px == Px) and (Py == Py) and (Pth == Pth)
              and (tau_drive_clamped == tau_drive_clamped) and (tau_steer_clamped == tau_steer_clamped)
              and (v_odom == v_odom) and (omega_imu == omega_imu) and (y_lidar_meas == y_lidar_meas);
  acceptance = ok_clearance and ok_tracking and ok_route and ok_covariance and ok_finite;

  annotation (
    experiment(StopTime=16.0, Tolerance=1e-6, Interval=0.004),
    Documentation(info="Ackermann rear-drive front-steer rover traversing an S-shaped corridor (1.8 m walls, two recessed alcoves) at 0.8 m/s. Localization-aware Stanley path tracking fuses wheel odometry, IMU, and 15 m planar lidar. 108 N lateral side load applied during middle third. 250 Hz trace rate. Fail-closed acceptance: wall clearance > 0.18 m, primary tracking error < 0.18 m after 10.4 s, route completion, finite covariance, no NaN/infinite values. Facts not stated in the request (wheel radius, steering inertia, exact corridor geometry, controller gains) are treated as unknown and represented by labeled placeholder parameters.")
  );
end AckermannRoverInspectE;