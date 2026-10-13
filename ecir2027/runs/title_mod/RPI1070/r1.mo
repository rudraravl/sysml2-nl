model TriTugInspectB
  "Floating-base mobile robot traversing S-shaped corridor with sensor fusion and obstacle avoidance"

  // ==================== STATED PARAMETERS ====================
  parameter Real m_chassis = 38.0 "Chassis mass [kg]";
  parameter Real m_payload = 20.0 "Payload mass [kg]";
  parameter Real r_w = 0.15 "Front wheel radius [m]";
  parameter Real steer_lim = 0.60 "Steering travel limit [rad]";
  parameter Real tau_max = 27.9 "Max command torque magnitude [N.m]";
  parameter Real v_ref = 0.8 "Reference speed [m/s]";
  parameter Real wall_spacing = 1.8 "Wall-to-wall spacing [m]";
  parameter Real F_side = 63.0 "Side load disturbance [N]";
  parameter Real min_clr_req = 0.18 "Required minimum wall clearance [m]";
  parameter Real track_thresh = 0.24 "Primary tracking error threshold [m]";
  parameter Real t_check = 6.5 "Convergence check time [s]";
  parameter Real T_sim = 10.0 "Total mission time [s]";
  parameter Real dt_s = 0.01 "Sensor/EKF update period [s] (100 Hz)";
  parameter Real lidar_range = 15.0 "Planar lidar range [m]";

  // ==================== ASSUMED PARAMETERS (not stated; required for model completeness) ====================
  parameter Real l_wb = 0.55 "Wheelbase [m] (assumed)";
  parameter Real J_steer = 0.02 "Steering axis inertia [kg.m2] (assumed)";
  parameter Real b_steer = 0.3 "Steering damping [N.m.s/rad] (assumed)";
  parameter Real k_steer_ret = 0.5 "Steering return stiffness [N.m/rad] (assumed)";
  parameter Real k_limit = 200.0 "Steering soft-limit stiffness [N.m/rad] (assumed)";
  parameter Real c_drag = 1.5 "Longitudinal drag [N.s/m] (assumed)";
  parameter Real c_tire = 150.0 "Lateral tire damping [N.s/m] (assumed)";
  parameter Real corridor_length = 8.0 "Corridor length [m] (assumed: v_ref * T_sim)";
  parameter Real S_amp = 0.25 "S-curve lateral amplitude [m] (assumed)";
  parameter Real S_period = 4.0 "S-curve period [m] (assumed)";
  parameter Real alcove1_cx = 2.0 "Alcove 1 center X [m] (assumed)";
  parameter Real alcove1_hw = 0.3 "Alcove 1 half-width [m] (assumed)";
  parameter Real alcove1_d = 0.25 "Alcove 1 depth [m] (assumed)";
  parameter Real alcove2_cx = 5.5 "Alcove 2 center X [m] (assumed)";
  parameter Real alcove2_hw = 0.3 "Alcove 2 half-width [m] (assumed)";
  parameter Real alcove2_d = 0.25 "Alcove 2 depth [m] (assumed)";
  // Controller gains
  parameter Real k_speed = 25.0 "Speed P gain (assumed)";
  parameter Real k_cross = 2.0 "Cross-track gain (assumed)";
  parameter Real k_steer_p = 6.0 "Steer P gain (assumed)";
  parameter Real k_steer_d = 0.4 "Steer D gain (assumed)";
  parameter Real k_obs = 1.0 "Obstacle avoidance gain (assumed)";
  parameter Real obs_margin = 0.25 "Obstacle avoidance margin [m] (assumed)";
  // EKF parameters
  parameter Real alpha_imu = 0.7 "IMU complementary filter weight (assumed)";
  parameter Real q_x = 1.0e-4 "EKF process noise x [m2] (assumed)";
  parameter Real q_y = 1.0e-4 "EKF process noise y [m2] (assumed)";
  parameter Real q_th = 5.0e-5 "EKF process noise theta [rad2] (assumed)";
  parameter Real q_v = 1.0e-3 "EKF process noise v (assumed)";
  parameter Real q_d = 1.0e-4 "EKF process noise delta (assumed)";
  parameter Real r_odom_v = 4.0e-4 "EKF meas noise odom v (assumed)";
  parameter Real r_odom_d = 1.0e-4 "EKF meas noise odom delta (assumed)";
  parameter Real r_imu = 1.0e-4 "EKF meas noise IMU (assumed)";
  parameter Real r_lidar = 9.0e-4 "EKF meas noise lidar (assumed)";

  // Derived constants
  final parameter Real m_total = m_chassis + m_payload "Total mass [kg]";
  final parameter Real wall_half = wall_spacing / 2.0 "Half wall spacing [m]";

  // ==================== PLANT STATES ====================
  Real x(start=0.0, fixed=true) "X position [m]";
  Real y(start=0.0, fixed=true) "Y position [m]";
  Real theta(start=0.0, fixed=true) "Heading [rad]";
  Real v(start=0.01, fixed=true) "Longitudinal velocity [m/s]";
  Real delta(start=0.0, fixed=true) "Steering angle [rad]";
  Real ddelta(start=0.0, fixed=true) "Steering rate [rad/s]";
  Real v_lat(start=0.0, fixed=true) "Lateral velocity [m/s]";

  // ==================== COMMANDS ====================
  Real tau_drive "Drive torque command [N.m]";
  Real tau_steer "Steer torque command [N.m]";
  Real tau_drive_sat "Saturated drive torque [N.m]";
  Real tau_steer_sat "Saturated steer torque [N.m]";
  Real delta_cmd "Commanded steering angle [rad]";
  Real delta_cmd_obs "Obstacle-adjusted steering command [rad]";
  Real tau_limit "Steering soft-limit torque [N.m]";

  // ==================== DISTURBANCE ====================
  Real F_side_y "Applied side load Y [N]";

  // ==================== REFERENCE PATH ====================
  Real y_ref "Reference centerline Y [m]";
  Real theta_ref "Reference heading [rad]";
  Real slope_ref "Reference slope dy/dx";

  // ==================== TRACKING ====================
  Real e_cross "Cross-track error [m]";
  Real e_heading "Heading error [rad]";
  Real e_heading_n "Normalized heading error [rad]";
  Real track_err "Primary tracking error [m]";
  Real route_completion "Route completion [0..1]";

  // ==================== WALLS ====================
  Real y_wall_L "Left wall Y [m]";
  Real y_wall_R "Right wall Y [m]";
  Real clr_L "Clearance to left wall [m]";
  Real clr_R "Clearance to right wall [m]";
  Real clr_min "Minimum wall clearance [m]";
  Real alcove_L "Left alcove indent [m]";
  Real alcove_R "Right alcove indent [m]";

  // ==================== SENSORS ====================
  Real v_odom "Odometry velocity [m/s]";
  Real delta_odom "Odometry steering [rad]";
  Real omega_imu "IMU yaw rate [rad/s]";
  Real lidar_L "Lidar left range [m]";
  Real lidar_R "Lidar right range [m]";
  Real x_pose "Fused X pose [m]";
  Real y_pose "Fused Y pose [m]";
  Real theta_pose "Fused heading [rad]";

  // ==================== ESTIMATOR ====================
  discrete Real x_hat(start=0.0) "Estimated X [m]";
  discrete Real y_hat(start=0.0) "Estimated Y [m]";
  discrete Real theta_hat(start=0.0) "Estimated heading [rad]";
  discrete Real v_hat(start=0.01) "Estimated velocity [m/s]";
  discrete Real delta_hat(start=0.0) "Estimated steering [rad]";
  discrete Real P11(start=0.01) "Covariance x";
  discrete Real P22(start=0.01) "Covariance y";
  discrete Real P33(start=0.001) "Covariance theta";
  discrete Real P44(start=0.01) "Covariance v";
  discrete Real P55(start=0.001) "Covariance delta";
  discrete Real K_v(start=0.0) "Kalman gain velocity";
  discrete Real K_d(start=0.0) "Kalman gain steering";
  discrete Real K_y(start=0.0) "Kalman gain y-position";

  // Discrete sensor samples (for trace recording)
  discrete Real v_odom_s(start=0.01) "Sampled odom velocity [m/s]";
  discrete Real delta_odom_s(start=0.0) "Sampled odom steer [rad]";
  discrete Real omega_imu_s(start=0.0) "Sampled IMU yaw rate [rad/s]";
  discrete Real lidar_L_s(start=0.9) "Sampled lidar left [m]";
  discrete Real lidar_R_s(start=0.9) "Sampled lidar right [m]";

  // Estimator helper variables
  Real y_ref_hat "Estimated reference Y [m]";
  Real theta_ref_hat "Estimated reference heading [rad]";
  Real slope_ref_hat "Estimated reference slope";
  Real alcove_L_hat "Estimated left alcove indent [m]";
  Real alcove_R_hat "Estimated right alcove indent [m]";
  Real y_meas_lidar "Y position measurement from lidar [m]";

  // ==================== STATUS FLAGS ====================
  Boolean track_ok "Tracking error below threshold after convergence time";
  Boolean clearance_ok "Wall clearance above minimum";
  Boolean finite_ok "All physical, control, estimator values finite";
  discrete Real track_err_recorded(start=0.0) "Tracking error recorded at t_check [m]";

protected
  function sat "Symmetric saturation"
    input Real val;
    input Real lim;
    output Real out;
  algorithm
    if val > lim then
      out := lim;
    elseif val < -lim then
      out := -lim;
    else
      out := val;
    end if;
  end sat;

  function atan2safe "Safe atan2 avoiding division-by-zero branch"
    input Real y_in;
    input Real x_in;
    output Real out;
  algorithm
    if abs(x_in) < 1.0e-10 then
      if y_in >= 0.0 then
        out := Modelica.Constants.pi / 2.0;
      else
        out := -Modelica.Constants.pi / 2.0;
      end if;
    else
      out := Modelica.Math.atan2(y_in, x_in);
    end if;
  end atan2safe;

  function normAng "Normalize angle to [-pi, pi]"
    input Real a;
    output Real out;
  algorithm
    out := atan2safe(Modelica.Math.sin(a), Modelica.Math.cos(a));
  end normAng;

equation
  // ==================== DISTURBANCE: 63 N side load during middle third ====================
  F_side_y = if (time >= T_sim / 3.0) and (time <= 2.0 * T_sim / 3.0) then F_side else 0.0;

  // ==================== REFERENCE S-CURVE PATH ====================
  y_ref = S_amp * Modelica.Math.sin(2.0 * Modelica.Constants.pi * x / S_period);
  slope_ref = (2.0 * Modelica.Constants.pi * S_amp / S_period) * Modelica.Math.cos(2.0 * Modelica.Constants.pi * x / S_period);
  theta_ref = atan2safe(slope_ref, 1.0);

  // ==================== CORRIDOR WALLS WITH TWO RECESSED ALCOVES ====================
  alcove_L = alcove1_d * Modelica.Math.exp(-((x - alcove1_cx)^2) / (2.0 * alcove1_hw^2))
           + alcove2_d * Modelica.Math.exp(-((x - alcove2_cx)^2) / (2.0 * alcove2_hw^2));
  alcove_R = alcove1_d * Modelica.Math.exp(-((x - alcove1_cx - 0.15)^2) / (2.0 * alcove1_hw^2))
           + alcove2_d * Modelica.Math.exp(-((x - alcove2_cx - 0.15)^2) / (2.0 * alcove2_hw^2));
  y_wall_L = y_ref + wall_half + alcove_L;
  y_wall_R = y_ref - wall_half - alcove_R;
  clr_L = y_wall_L - y;
  clr_R = y - y_wall_R;
  clr_min = if clr_L < clr_R then clr_L else clr_R;

  // ==================== PLANT DYNAMICS (kinematic bicycle + lateral disturbance) ====================
  der(x) = v * Modelica.Math.cos(theta);
  der(y) = v * Modelica.Math.sin(theta) + v_lat;
  der(theta) = v * Modelica.Math.tan(sat(delta, steer_lim)) / l_wb;
  der(v) = (tau_drive_sat / r_w - c_drag * v) / m_total;
  der(v_lat) = (F_side_y - c_tire * v_lat) / m_total;
  der(delta) = ddelta;
  tau_limit = if delta > steer_lim then -k_limit * (delta - steer_lim)
              else if delta < -steer_lim then -k_limit * (delta + steer_lim)
              else 0.0;
  J_steer * der(ddelta) = tau_steer_sat + tau_limit - b_steer * ddelta - k_steer_ret * delta;

  // ==================== COMMAND SATURATION (effort-controlled, 27.9 N.m max) ====================
  tau_drive_sat = sat(tau_drive, tau_max);
  tau_steer_sat = sat(tau_steer, tau_max);

  // ==================== CONTROLLER: localization-aware path tracking + obstacle avoidance ====================
  // Speed control via traction effort
  tau_drive = k_speed * (v_ref - v_hat);

  // Path tracking errors from estimated state
  e_cross = y_hat - y_ref;
  e_heading = theta_hat - theta_ref;
  e_heading_n = normAng(e_heading);

  // Stanley-like steering command (well-defined zero-speed branch via max)
  delta_cmd = sat(e_heading_n + atan2safe(k_cross * e_cross, max(abs(v_hat), 0.05)), steer_lim);

  // Obstacle avoidance: bias steering away from nearest wall when within margin
  delta_cmd_obs = sat(delta_cmd
    + k_obs * (max(0.0, obs_margin - clr_L) - max(0.0, obs_margin - clr_R)),
    steer_lim);

  // Steering effort control
  tau_steer = k_steer_p * (delta_cmd_obs - delta_hat) - k_steer_d * ddelta;

  // ==================== TRACKING METRICS ====================
  track_err = abs(y - y_ref);
  route_completion = if x < 0.0 then 0.0 else if x > corridor_length then 1.0 else x / corridor_length;

  // ==================== SENSOR MODELS (deterministic noise, all finite) ====================
  v_odom = v + 0.01 * Modelica.Math.sin(2.0 * Modelica.Constants.pi * 73.0 * time);
  delta_odom = delta + 0.005 * Modelica.Math.sin(2.0 * Modelica.Constants.pi * 97.0 * time);
  omega_imu = v * Modelica.Math.tan(sat(delta, steer_lim)) / l_wb
            + 0.01 * Modelica.Math.sin(2.0 * Modelica.Constants.pi * 89.0 * time);
  lidar_L = max(0.0, min(lidar_range, clr_L)) + 0.02 * Modelica.Math.sin(2.0 * Modelica.Constants.pi * 83.0 * time);
  lidar_R = max(0.0, min(lidar_range, clr_R)) + 0.02 * Modelica.Math.sin(2.0 * Modelica.Constants.pi * 101.0 * time);

  // ==================== ESTIMATOR HELPER EQUATIONS ====================
  y_ref_hat = S_amp * Modelica.Math.sin(2.0 * Modelica.Constants.pi * x_hat / S_period);
  slope_ref_hat = (2.0 * Modelica.Constants.pi * S_amp / S_period) * Modelica.Math.cos(2.0 * Modelica.Constants.pi * x_hat / S_period);
  theta_ref_hat = atan2safe(slope_ref_hat, 1.0);
  alcove_L_hat = alcove1_d * Modelica.Math.exp(-((x_hat - alcove1_cx)^2) / (2.0 * alcove1_hw^2))
              + alcove2_d * Modelica.Math.exp(-((x_hat - alcove2_cx)^2) / (2.0 * alcove2_hw^2));
  alcove_R_hat = alcove1_d * Modelica.Math.exp(-((x_hat - alcove1_cx - 0.15)^2) / (2.0 * alcove1_hw^2))
              + alcove2_d * Modelica.Math.exp(-((x_hat - alcove2_cx - 0.15)^2) / (2.0 * alcove2_hw^2));
  y_meas_lidar = y_ref_hat + (alcove_L_hat - alcove_R_hat) / 2.0 + (lidar_R - lidar_L) / 2.0;

  // ==================== FUSED POSE OUTPUT ====================
  x_pose = x_hat;
  y_pose = y_hat;
  theta_pose = theta_hat;

  // ==================== STATUS FLAGS ====================
  track_ok = if time >= t_check then track_err < track_thresh else true;
  clearance_ok = clr_min > min_clr_req;
  finite_ok = (abs(x) < 1e15) and (abs(y) < 1e15) and (abs(theta) < 1e15)
            and (abs(v) < 1e15) and (abs(delta) < 1e15) and (abs(v_lat) < 1e15)
            and (abs(tau_drive) < 1e15) and (abs(tau_steer) < 1e15)
            and (abs(x_hat) < 1e15) and (abs(y_hat) < 1e15) and (abs(theta_hat) < 1e15)
            and (abs(v_hat) < 1e15) and (abs(delta_hat) < 1e15)
            and (abs(P11) < 1e15) and (abs(P22) < 1e15) and (abs(P33) < 1e15)
            and (abs(P44) < 1e15) and (abs(P55) < 1e15);

  // ==================== DISCRETE EKF UPDATE AT 100 Hz ====================
  // Fuses wheel odometry (v, delta), IMU (yaw rate), and lidar (y from wall geometry)
  when sample(0, dt_s) then
    // Record sampled sensor traces
    v_odom_s = v_odom;
    delta_odom_s = delta_odom;
    omega_imu_s = omega_imu;
    lidar_L_s = lidar_L;
    lidar_R_s = lidar_R;

    // Scalar Kalman gains (denominators always positive: P > 0, R > 0, q > 0)
    K_v = (pre(P44) + q_v * dt_s) / (pre(P44) + q_v * dt_s + r_odom_v);
    K_d = (pre(P55) + q_d * dt_s) / (pre(P55) + q_d * dt_s + r_odom_d);
    K_y = (pre(P22) + q_y * dt_s) / (pre(P22) + q_y * dt_s + r_lidar);

    // Odometry correction for velocity and steering
    v_hat = pre(v_hat) + K_v * (v_odom - pre(v_hat));
    delta_hat = pre(delta_hat) + K_d * (delta_odom - pre(delta_hat));

    // Position prediction from odometry-integrated velocity
    x_hat = pre(x_hat) + pre(v_hat) * Modelica.Math.cos(pre(theta_hat)) * dt_s;

    // Heading: complementary filter blending IMU yaw rate with model prediction
    theta_hat = pre(theta_hat)
              + (alpha_imu * omega_imu
                 + (1.0 - alpha_imu) * pre(v_hat) * Modelica.Math.tan(sat(pre(delta_hat), steer_lim)) / l_wb) * dt_s;

    // Y-position: prediction + lidar correction (lidar interprets wall distances via map)
    y_hat = pre(y_hat) + pre(v_hat) * Modelica.Math.sin(pre(theta_hat)) * dt_s
          + K_y * (y_meas_lidar - (pre(y_hat) + pre(v_hat) * Modelica.Math.sin(pre(theta_hat)) * dt_s));

    // Covariance propagation (diagonal, finite): predict then correct
    P11 = pre(P11) + q_x * dt_s;
    P22 = (pre(P22) + q_y * dt_s) * r_lidar / (pre(P22) + q_y * dt_s + r_lidar);
    P33 = pre(P33) + q_th * dt_s;
    P44 = (pre(P44) + q_v * dt_s) * r_odom_v / (pre(P44) + q_v * dt_s + r_odom_v);
    P55 = (pre(P55) + q_d * dt_s) * r_odom_d / (pre(P55) + q_d * dt_s + r_odom_d);
  end when;

  // Record tracking error at convergence check time
  when time >= t_check then
    track_err_recorded = track_err;
  end when;

  annotation(
    experiment(StopTime = 10.0, Tolerance = 1.0e-6, Interval = 0.01),
    Documentation(info = "<html>
<p><b>TriTugInspectB</b>: Floating-base mobile robot mission model.</p>
<p><b>Stated facts:</b> 38 kg chassis + 20 kg payload (58 kg total),
one 0.15 m-radius front drive-and-steer wheel, two passive rear wheels,
steering travel &plusmn;0.60 rad, effort-controlled traction and steering
with 27.9 N.m max command, 1.8 m wall spacing with two recessed alcoves,
S-shaped corridor, 0.8 m/s reference speed, 63 N side load during middle
third, 100 Hz for 10 s, 15 m lidar range, 0.18 m min clearance,
0.24 m tracking error threshold after 6.5 s.</p>
<p><b>Assumed (not stated):</b> wheelbase, steering inertia/damping/stiffness,
drag and lateral tire coefficients, S-curve geometry, alcove positions and
dimensions, controller gains, EKF noise parameters, corridor length.</p>
</html>")
  );
end TriTugInspectB;