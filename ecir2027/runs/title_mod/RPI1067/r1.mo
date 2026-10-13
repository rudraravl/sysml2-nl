model TriTugClimbE
  parameter Real m_chassis = 38.0 "Chassis mass [kg]";
  parameter Real m_payload = 20.0 "Payload mass [kg]";
  parameter Real m_total = m_chassis + m_payload "Total mass [kg]";
  parameter Real r_w = 0.15 "Front wheel radius [m]";
  parameter Real I_w = 0.05 "Front wheel inertia [kg.m2]";
  parameter Real mu = 0.76 "Friction coefficient [-]";
  parameter Real tau_max = 37.4 "Max actuator torque [N.m]";
  parameter Real delta_max = 0.60 "Max steering angle [rad]";
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real cr = 0.015 "Rolling resistance coefficient [-]";
  parameter Real front_weight_frac = 0.40 "Front wheel weight fraction [-]";
  parameter Real pi_val = 3.141592653589793 "Pi [-]";
  parameter Real ramp_angle = 12.0 * pi_val / 180.0 "Ramp angle [rad]";
  parameter Real x_ramp_start = 2.0 "Ramp start position [m]";
  parameter Real x_ramp_end = 6.0 "Ramp end position [m]";
  parameter Real x_plateau_end = 8.0 "Descending edge position [m]";
  parameter Real ridge_height = 0.05 "Ridge height [m]";
  parameter Real ridge1_x = 3.5 "First ridge position [m]";
  parameter Real ridge2_x = 6.5 "Second ridge position [m]";
  parameter Real ridge_half_width = 0.20 "Ridge half-width [m]";
  parameter Real v_target = 0.65 "Target cruise speed [m/s]";
  parameter Real kp_speed = 35.0 "Speed controller proportional gain [N]";
  parameter Real ki_speed = 10.0 "Speed controller integral gain [N/s]";
  parameter Real kp_steer = 10.0 "Steering proportional gain [N.m/rad]";
  parameter Real kd_steer = 3.0 "Steering derivative gain [N.m.s/rad]";
  parameter Real I_steer = 0.01 "Steering inertia [kg.m2]";
  parameter Real b_steer = 0.1 "Steering damping [N.m.s/rad]";
  parameter Real slip_threshold = 0.20 "Slip threshold [-]";
  parameter Real v_eps = 0.01 "Velocity epsilon [m/s]";
  parameter Real brake_distance = 2.0 "Braking start distance from edge [m]";
  parameter Real stop_margin_target = 0.20 "Target stopping margin [m]";
  parameter Real k_pitch = 50.0 "Pitch spring gain [1/s2]";
  parameter Real c_pitch = 20.0 "Pitch damping [1/s]";
  parameter Real k_roll = 200.0 "Roll spring gain [1/s2]";
  parameter Real c_roll = 30.0 "Roll damping [1/s]";
  parameter Real I_roll = 5.0 "Roll inertia [kg.m2]";
  parameter Real h_payload = 0.25 "Payload moment arm [m]";
  parameter Real ridge_roll_perturb = 2.0 "Ridge roll perturbation [rad/s2]";
  parameter Real t_sim = 16.0 "Simulation duration [s]";
  parameter Real dist_force_mag = 180.0 "Disturbance force magnitude [N]";
  parameter Real dist_start = t_sim / 3.0 "Disturbance start [s]";
  parameter Real dist_end = 2.0 * t_sim / 3.0 "Disturbance end [s]";
  parameter Real t_check = 10.4 "Tracking check time [s]";
  parameter Real tracking_limit = 0.162 "Tracking error limit [m/s]";
  parameter Real slip_limit = 0.35 "Slip ratio limit [-]";
  parameter Real angle_limit = 0.40 "Roll/pitch limit [rad]";
  parameter Real F_ridge_val = 25.0 "Ridge resistance force [N]";

  Real x(start = 0.0, fixed = true) "Longitudinal position [m]";
  Real v(start = 0.0, fixed = true) "Longitudinal velocity [m/s]";
  Real theta(start = 0.0, fixed = true) "Pitch angle [rad]";
  Real theta_dot(start = 0.0, fixed = true) "Pitch angular velocity [rad/s]";
  Real phi(start = 0.0, fixed = true) "Roll angle [rad]";
  Real phi_dot(start = 0.0, fixed = true) "Roll angular velocity [rad/s]";
  Real omega_w(start = 0.0, fixed = true) "Front wheel angular velocity [rad/s]";
  Real delta_steer(start = 0.0, fixed = true) "Steering angle [rad]";
  Real delta_dot(start = 0.0, fixed = true) "Steering angular velocity [rad/s]";
  Real integ_err(start = 0.0, fixed = true) "Speed error integral [m]";
  discrete Boolean fail_closed(start = false) "Fail-closed latch";

  Real h_terrain "Terrain height [m]";
  Real slope "Terrain slope [rad]";
  Real edge_distance "Distance to descending edge [m]";
  Real h_ridge1 "Ridge 1 height [m]";
  Real h_ridge2 "Ridge 2 height [m]";
  Real slope_ridge1 "Ridge 1 slope contribution [rad]";
  Real slope_ridge2 "Ridge 2 slope contribution [rad]";

  Real F_traction "Traction force [N]";
  Real F_normal_front "Normal force on front wheel [N]";
  Real F_gravity_long "Longitudinal gravity [N]";
  Real F_disturbance "Disturbance force [N]";
  Real F_ridge "Ridge resistance [N]";
  Real F_roll_resist "Rolling resistance [N]";
  Real F_net "Net longitudinal force [N]";
  Real F_traction_max "Max friction traction [N]";
  Real tau_traction_cmd "Traction torque command [N.m]";
  Real tau_steer_cmd "Steering torque command [N.m]";
  Real tau_traction_sat "Saturated traction torque [N.m]";
  Real tau_steer_sat "Saturated steering torque [N.m]";
  Real tau_dist_roll "Disturbance roll torque [N.m]";

  Real slip_ratio "Wheel slip ratio [-]";
  Real v_wheel "Wheel surface speed [m/s]";
  Real slip_correction "Slip correction factor [-]";
  Real ridge_roll_effect "Ridge roll effect [rad/s2]";

  Real v_enc "Encoder speed [m/s]";
  Real theta_imu "IMU pitch [rad]";
  Real phi_imu "IMU roll [rad]";
  Real depth_meas "Depth sensor edge distance [m]";

  Real v_ref "Reference speed [m/s]";
  Real v_err "Speed tracking error [m/s]";

  Boolean disturbance_active "Disturbance active";
  Boolean on_ridge1 "On first ridge";
  Boolean on_ridge2 "On second ridge";

  Boolean slip_ok "Slip acceptance";
  Boolean roll_pitch_ok "Roll/pitch acceptance";
  Boolean actuator_ok "Actuator limits acceptance";
  Boolean tracking_ok "Tracking error acceptance";
  Boolean steering_limit_ok "Steering limit acceptance";
  Boolean stopped_before_edge "Stopped before edge";
  Boolean no_nan_inf "No NaN/Inf";
  Boolean all_acceptance_ok "All acceptance";

equation
  h_ridge1 = ridge_height * exp(-((x - ridge1_x) / ridge_half_width)^2);
  h_ridge2 = ridge_height * exp(-((x - ridge2_x) / ridge_half_width)^2);
  slope_ridge1 = -2.0 * (x - ridge1_x) / ridge_half_width^2 * h_ridge1;
  slope_ridge2 = -2.0 * (x - ridge2_x) / ridge_half_width^2 * h_ridge2;

  if x < x_ramp_start then
    h_terrain = h_ridge1 + h_ridge2;
    slope = slope_ridge1 + slope_ridge2;
  elseif x < x_ramp_end then
    h_terrain = (x - x_ramp_start) * sin(ramp_angle) + h_ridge1 + h_ridge2;
    slope = ramp_angle + slope_ridge1 + slope_ridge2;
  else
    h_terrain = (x_ramp_end - x_ramp_start) * sin(ramp_angle) + h_ridge1 + h_ridge2;
    slope = slope_ridge1 + slope_ridge2;
  end if;

  edge_distance = x_plateau_end - x;
  on_ridge1 = abs(x - ridge1_x) < ridge_half_width;
  on_ridge2 = abs(x - ridge2_x) < ridge_half_width;

  if on_ridge1 or on_ridge2 then
    F_ridge = F_ridge_val;
  else
    F_ridge = 0.0;
  end if;

  disturbance_active = (time >= dist_start) and (time <= dist_end);
  F_disturbance = if disturbance_active then dist_force_mag else 0.0;
  tau_dist_roll = F_disturbance * h_payload;

  F_gravity_long = m_total * g * sin(slope);
  F_normal_front = front_weight_frac * m_total * g * cos(slope);
  F_roll_resist = cr * m_total * g * cos(slope);

  v_wheel = r_w * omega_w;

  if abs(v) > v_eps then
    slip_ratio = (v_wheel - v) / abs(v);
  else
    slip_ratio = 0.0;
  end if;

  F_traction_max = mu * F_normal_front;

  if abs(tau_traction_sat / r_w) <= F_traction_max then
    F_traction = tau_traction_sat / r_w;
  elseif tau_traction_sat > 0.0 then
    F_traction = F_traction_max;
  else
    F_traction = -F_traction_max;
  end if;

  F_net = F_traction - F_gravity_long - F_roll_resist - F_ridge;

  der(x) = v;
  der(v) = F_net / m_total;

  der(theta) = theta_dot;
  der(theta_dot) = k_pitch * (slope - theta) - c_pitch * theta_dot;

  ridge_roll_effect = if (on_ridge1 or on_ridge2) then ridge_roll_perturb else 0.0;
  der(phi) = phi_dot;
  der(phi_dot) = -k_roll * phi - c_roll * phi_dot + tau_dist_roll / I_roll + ridge_roll_effect;

  der(omega_w) = (tau_traction_sat - F_traction * r_w) / I_w;

  der(delta_steer) = delta_dot;
  der(delta_dot) = (tau_steer_sat - b_steer * delta_dot) / I_steer;

  if edge_distance < stop_margin_target then
    v_ref = 0.0;
  elseif edge_distance < brake_distance then
    v_ref = v_target * (edge_distance - stop_margin_target) / (brake_distance - stop_margin_target);
  else
    v_ref = v_target;
  end if;

  v_err = v_ref - v;

  if abs(v_ref) < 0.001 and abs(v) < 0.01 then
    der(integ_err) = 0.0;
  else
    der(integ_err) = v_err;
  end if;

  if slip_ratio > slip_threshold then
    slip_correction = 0.5;
  elseif slip_ratio < -slip_threshold then
    slip_correction = 0.5;
  else
    slip_correction = 1.0;
  end if;

  tau_traction_cmd = (kp_speed * v_err + ki_speed * integ_err) * slip_correction;
  tau_steer_cmd = -kp_steer * delta_steer - kd_steer * delta_dot;

  if fail_closed then
    tau_traction_sat = 0.0;
  elseif tau_traction_cmd > tau_max then
    tau_traction_sat = tau_max;
  elseif tau_traction_cmd < -tau_max then
    tau_traction_sat = -tau_max;
  else
    tau_traction_sat = tau_traction_cmd;
  end if;

  if tau_steer_cmd > tau_max then
    tau_steer_sat = tau_max;
  elseif tau_steer_cmd < -tau_max then
    tau_steer_sat = -tau_max;
  else
    tau_steer_sat = tau_steer_cmd;
  end if;

  when {abs(slip_ratio) >= slip_limit, abs(phi) >= angle_limit, abs(theta) >= angle_limit} then
    fail_closed = true;
  end when;

  v_enc = v_wheel;
  theta_imu = theta;
  phi_imu = phi;
  depth_meas = if edge_distance > 0.0 then edge_distance else 0.0;

  slip_ok = abs(slip_ratio) < slip_limit;
  roll_pitch_ok = (abs(phi) < angle_limit) and (abs(theta) < angle_limit);
  actuator_ok = (abs(tau_traction_sat) <= tau_max + 0.001) and (abs(tau_steer_sat) <= tau_max + 0.001);
  tracking_ok = (time < t_check) or (abs(v_err) < tracking_limit);
  steering_limit_ok = abs(delta_steer) <= delta_max + 0.001;
  stopped_before_edge = (x < x_plateau_end) and (abs(v) < 0.05) and (time > t_sim - 2.0);
  no_nan_inf = (x > -1.0e10) and (x < 1.0e10) and
               (v > -1.0e10) and (v < 1.0e10) and
               (theta > -1.0e10) and (theta < 1.0e10) and
               (phi > -1.0e10) and (phi < 1.0e10) and
               (tau_traction_sat > -1.0e10) and (tau_traction_sat < 1.0e10) and
               (slip_ratio > -1.0e10) and (slip_ratio < 1.0e10) and
               (v_err > -1.0e10) and (v_err < 1.0e10);
  all_acceptance_ok = slip_ok and roll_pitch_ok and actuator_ok and tracking_ok and
                      steering_limit_ok and stopped_before_edge and no_nan_inf;

  annotation(
    Experiment(StopTime = 16.0, Tolerance = 1e-6, Interval = 0.004),
    Documentation(info = "TriTugClimbE: 38 kg chassis + 20 kg payload, front drive-and-steer wheel (r=0.15 m), two passive rear wheels. Ascends 12 deg ramp, traverses 2 m plateau, stops before descending edge. Slip-aware traction control with bounded braking. 180 N lateral payload disturbance during middle-third. 250 Hz output, 16 s, fail-closed acceptance.")
  );
end TriTugClimbE;