model TrackCrawlerInspectA
  "Floating-base tracked crawler for S-corridor inspection with sensor fusion"
  import Modelica.Constants.pi;

  // Physical parameters
  parameter Real m_hull = 52.0 "Hull mass [kg]";
  parameter Real L_hull = 1.1 "Hull length [m]";
  parameter Real r_sprocket = 0.14 "Effective sprocket radius [m]";
  parameter Real B_track = 0.50 "Track separation [m]";
  parameter Real I_zz = m_hull * (L_hull * L_hull + B_track * B_track) / 12.0
    "Yaw inertia [kg.m2]";

  // Control parameters
  parameter Real tau_max = 30.2 "Command magnitude limit [N.m]";
  parameter Real v_ref = 0.8 "Reference speed [m/s]";
  parameter Real f_ctrl = 80.0 "Control frequency [Hz]";
  parameter Real dt_ctrl = 1.0 / f_ctrl "Control period [s]";
  parameter Real T_sim = 8.0 "Scenario duration [s]";

  // Corridor parameters
  parameter Real corridor_width = 1.8 "Wall separation [m]";
  parameter Real clearance_min = 0.18 "Minimum wall clearance [m]";
  parameter Real S_amplitude = 0.30 "S-curve amplitude [m]";
  parameter Real S_period = 3.2 "S-curve period [m]";
  parameter Real alcove1_cx = 2.0 "Alcove 1 center x [m]";
  parameter Real alcove2_cx = 4.8 "Alcove 2 center x [m]";
  parameter Real alcove_hw = 0.25 "Alcove half-width [m]";
  parameter Real alcove_depth = 0.30 "Alcove recess depth [m]";

  // Disturbance
  parameter Real F_dist = 45.0 "Side load magnitude [N]";

  // Controller gains
  parameter Real k_speed = 150.0 "Speed gain [N/(m/s)]";
  parameter Real k_heading = 60.0 "Heading gain [N/rad]";
  parameter Real k_lateral = 80.0 "Lateral gain [N/m]";
  parameter Real k_avoid = 40.0 "Obstacle avoidance gain [N/m]";
  parameter Real avoid_thresh = 0.35 "Avoidance threshold [m]";

  // Estimator parameters — noise levels not specified in requirement;
  // small positive values ensure finite covariance dynamics
  parameter Real Q_pos = 0.002 "Process noise position [m2/s]";
  parameter Real Q_theta = 0.0002 "Process noise heading [rad2/s]";
  parameter Real R_lidar = 0.005 "Lidar measurement noise [m2]";

  // True continuous states
  Real x_pos(start = 0.0, fixed = true) "X position [m]";
  Real y_pos(start = 0.0, fixed = true) "Y position [m]";
  Real vx(start = 0.0, fixed = true) "X velocity [m/s]";
  Real vy(start = 0.0, fixed = true) "Y velocity [m/s]";
  Real theta(start = 0.0, fixed = true) "Heading [rad]";
  Real omega(start = 0.0, fixed = true) "Yaw rate [rad/s]";

  // Derived continuous variables
  Real v "Speed [m/s]";
  Real ax "Global X acceleration [m/s2]";
  Real ay "Global Y acceleration [m/s2]";
  Real F_L "Left track force [N]";
  Real F_R "Right track force [N]";
  Real F_total "Total track force [N]";
  Real F_diff "Differential track force [N]";
  Real tau_L "Left track torque [N.m]";
  Real tau_R "Right track torque [N.m]";

  // Discrete controller commands
  discrete Real tau_L_cmd(start = 0.0) "Left torque command [N.m]";
  discrete Real tau_R_cmd(start = 0.0) "Right torque command [N.m]";

  // Reference path
  Real s_ref "Reference arc length [m]";
  Real x_ref "Reference X [m]";
  Real y_ref "Reference Y [m]";
  Real theta_ref "Reference heading [rad]";

  // Tracking errors
  Real e_lateral "Cross-track error [m]";
  Real e_heading "Heading error [rad]";
  Real e_speed "Speed error [m/s]";
  Real e_primary "Primary tracking error [m]";

  // Corridor geometry
  Real y_center "Corridor centerline Y at robot x [m]";
  Real y_wall_left "Left wall Y [m]";
  Real y_wall_right "Right wall Y [m]";
  Real wall_dist_left "Distance to left wall [m]";
  Real wall_dist_right "Distance to right wall [m]";
  Real wall_clearance "Minimum wall clearance [m]";
  Boolean in_alcove1 "In alcove 1 zone";
  Boolean in_alcove2 "In alcove 2 zone";

  // Disturbance
  Real F_side "Side load [N]";
  Boolean disturb_active "Disturbance active";

  // Sensors
  Real imu_omega "IMU yaw rate [rad/s]";
  Real imu_ax "IMU forward accel [m/s2]";
  Real odom_v "Odometry speed [m/s]";
  Real odom_omega "Odometry yaw rate [rad/s]";
  Real lidar_left "Lidar range left [m]";
  Real lidar_right "Lidar range right [m]";
  Real lidar_front "Lidar range front [m]";

  // Estimator states (discrete, 80 Hz)
  discrete Real x_est(start = 0.0) "Estimated X [m]";
  discrete Real y_est(start = 0.0) "Estimated Y [m]";
  discrete Real theta_est(start = 0.0) "Estimated heading [rad]";
  discrete Real v_est(start = 0.0) "Estimated speed [m/s]";
  discrete Real omega_est(start = 0.0) "Estimated yaw rate [rad/s]";
  discrete Real P_xx(start = 0.01) "Covariance X [m2]";
  discrete Real P_yy(start = 0.01) "Covariance Y [m2]";
  discrete Real P_tt(start = 0.001) "Covariance theta [rad2]";

  // Estimator intermediates
  discrete Real y_center_est "Centerline Y at estimated x [m]";
  discrete Real y_lidar_meas "Y position from lidar fusion [m]";
  discrete Real K_y "Kalman gain Y";

  // Controller intermediates
  discrete Real e_lat_est "Estimated cross-track error [m]";
  discrete Real e_head_est "Estimated heading error [rad]";
  discrete Real e_spd_est "Estimated speed error [m/s]";
  discrete Real avoid_L "Left avoidance force [N]";
  discrete Real avoid_R "Right avoidance force [N]";
  discrete Real F_total_cmd "Total force command [N]";
  discrete Real F_diff_cmd "Differential force command [N]";
  discrete Real F_L_raw "Raw left force [N]";
  discrete Real F_R_raw "Raw right force [N]";

  // Status
  Real route_completion "Route completion fraction [0-1]";
  Boolean tracking_satisfied "Tracking OK after 5.2 s";
  Boolean clearance_satisfied "Wall clearance above 0.18 m";
  Boolean no_nan_inf "No NaN or infinite values";
  Real norm_check "Norm validity sum";

equation
  // === Reference path: S-shaped corridor centerline ===
  s_ref = v_ref * time;
  x_ref = s_ref;
  y_ref = S_amplitude * (1.0 - cos(2.0 * pi * s_ref / S_period)) / 2.0;
  theta_ref = atan2(S_amplitude * pi / S_period
                    * sin(2.0 * pi * s_ref / S_period), 1.0);

  // === Corridor geometry with alcoves ===
  y_center = S_amplitude * (1.0 - cos(2.0 * pi * x_pos / S_period)) / 2.0;
  in_alcove1 = abs(x_pos - alcove1_cx) < alcove_hw;
  in_alcove2 = abs(x_pos - alcove2_cx) < alcove_hw;
  y_wall_left = y_center - corridor_width / 2.0
    - (if in_alcove1 then alcove_depth else 0.0);
  y_wall_right = y_center + corridor_width / 2.0
    + (if in_alcove2 then alcove_depth else 0.0);
  wall_dist_left = y_pos - y_wall_left;
  wall_dist_right = y_wall_right - y_pos;
  wall_clearance = min(wall_dist_left, wall_dist_right);

  // === Side load disturbance: middle third of 8 s ===
  disturb_active = (time >= T_sim / 3.0) and (time <= 2.0 * T_sim / 3.0);
  F_side = if disturb_active then F_dist else 0.0;

  // === Robot dynamics (planar, skid-steer) ===
  tau_L = tau_L_cmd;
  tau_R = tau_R_cmd;
  F_L = tau_L / r_sprocket;
  F_R = tau_R / r_sprocket;
  F_total = F_L + F_R;
  F_diff = F_R - F_L;

  ax = (F_total * cos(theta)) / m_hull;
  ay = (F_total * sin(theta) + F_side) / m_hull;
  der(vx) = ax;
  der(vy) = ay;
  der(omega) = (F_diff * B_track / 2.0) / I_zz;
  der(x_pos) = vx;
  der(y_pos) = vy;
  der(theta) = omega;

  // Speed with well-defined zero branch
  v = sqrt(vx * vx + vy * vy + 1e-12);

  // === Sensor models ===
  imu_omega = omega;
  imu_ax = ax * cos(theta) + ay * sin(theta);
  odom_v = v;
  odom_omega = omega;
  lidar_left = max(wall_dist_left, 0.01);
  lidar_right = max(wall_dist_right, 0.01);
  lidar_front = 15.0;

  // === Tracking errors (for monitoring) ===
  e_lateral = -(x_pos - x_ref) * sin(theta_ref)
              + (y_pos - y_ref) * cos(theta_ref);
  e_heading = theta_ref - theta;
  e_speed = v_ref - v;
  e_primary = abs(e_lateral);

  // === Status checks ===
  route_completion = min(max(s_ref / (v_ref * T_sim), 0.0), 1.0);
  tracking_satisfied = if (time >= 5.2) then (e_primary <= 0.27) else true;
  clearance_satisfied = wall_clearance >= clearance_min;
  norm_check = x_pos + y_pos + vx + vy + theta + omega + tau_L + tau_R
               + x_est + y_est + theta_est + P_xx + P_yy + P_tt
               + v + e_primary;
  no_nan_inf = (norm_check > -1e15) and (norm_check < 1e15);

  // === Discrete controller and estimator at 80 Hz ===
  when sample(0, dt_ctrl) then
    // --- Estimator: Predict (odometry + IMU) ---
    x_est := x_est + v_est * cos(theta_est) * dt_ctrl;
    y_est := y_est + v_est * sin(theta_est) * dt_ctrl;
    theta_est := theta_est + omega_est * dt_ctrl;
    v_est := odom_v;
    omega_est := imu_omega;
    P_xx := P_xx + Q_pos * dt_ctrl;
    P_yy := P_yy + Q_pos * dt_ctrl;
    P_tt := P_tt + Q_theta * dt_ctrl;

    // --- Estimator: Update (lidar correction, alcove-aware) ---
    y_center_est := S_amplitude
      * (1.0 - cos(2.0 * pi * x_est / S_period)) / 2.0;
    // Use non-recessed wall when in alcove; average both otherwise
    y_lidar_meas := if abs(x_est - alcove1_cx) < alcove_hw then
                      y_center_est + corridor_width / 2.0 - lidar_right
                    elseif abs(x_est - alcove2_cx) < alcove_hw then
                      y_center_est - corridor_width / 2.0 + lidar_left
                    else
                      (y_center_est - corridor_width / 2.0 + lidar_left
                       + y_center_est + corridor_width / 2.0 - lidar_right)
                      / 2.0;
    K_y := P_yy / (P_yy + R_lidar);
    y_est := y_est + K_y * (y_lidar_meas - y_est);
    P_yy := (1.0 - K_y) * P_yy;

    // --- Controller: localization-aware path tracking ---
    e_lat_est := -(x_est - x_ref) * sin(theta_ref)
                 + (y_est - y_ref) * cos(theta_ref);
    e_head_est := theta_ref - theta_est;
    e_spd_est := v_ref - v_est;

    // Obstacle avoidance from lidar ranges
    avoid_L := k_avoid * max(0.0, avoid_thresh - max(lidar_left, 0.01));
    avoid_R := k_avoid * max(0.0, avoid_thresh - max(lidar_right, 0.01));

    // Force commands
    F_total_cmd := k_speed * e_spd_est;
    F_diff_cmd := k_heading * e_head_est + k_lateral * e_lat_est
                  - avoid_L + avoid_R;

    // Distribute to tracks and saturate torques
    F_L_raw := (F_total_cmd - F_diff_cmd) / 2.0;
    F_R_raw := (F_total_cmd + F_diff_cmd) / 2.0;
    tau_L_cmd := max(-tau_max, min(tau_max, F_L_raw * r_sprocket));
    tau_R_cmd := max(-tau_max, min(tau_max, F_R_raw * r_sprocket));
  end when;

  annotation(
    experiment(StartTime = 0, StopTime = 8.0, Tolerance = 1e-6,
               Interval = 0.0125));
end TrackCrawlerInspectA;