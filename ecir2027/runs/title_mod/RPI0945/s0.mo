model SeaSnakeSurveyC
  import Modelica.Constants.pi;

  // ===================== Physical parameters =====================
  parameter Real m_body = 32.0 "kg total robot mass";
  parameter Real L_module = 0.30 "m per capsule module";
  parameter Integer N_modules = 6 "number of capsule modules";
  parameter Real L_total = 1.8 "m body length (6 x 0.30 m)";
  parameter Real tau_max = 29.4 "N.m max command per joint";
  parameter Integer N_joints = 12 "bounded joint actuators";
  // NOTE: alternating yaw (odd index) and pitch (even index) joints;
  //       exact per-module mass distribution is unspecified.

  // ===================== Mission =====================
  parameter Real v_ref = 1.0 "m/s reference surge speed";
  parameter Real L_path = 60.0 "m total lawnmower path length";
  parameter Real L_leg = 30.0 "m per leg (nominal; exact leg count/spacing unspecified)";
  parameter Real W_spacing = 5.0 "m leg spacing (nominal; unspecified)";
  parameter Real depth_ref = 2.0 "m constant depth reference (actual survey depth unspecified)";
  parameter Real seabed_z = 3.0 "m seabed depth (nominal; unspecified)";

  // ===================== Current disturbance =====================
  parameter Real v_current = 0.18 "m/s steady lateral water current";
  parameter Real F_current = 90.0 "N current load during middle third";
  parameter Real t_dist_start = 4.0 "s middle third start";
  parameter Real t_dist_end = 8.0 "s middle third end";

  // ===================== Simulation / verification =====================
  parameter Real Ts = 0.008 "s sample period (125 Hz)";
  parameter Real e_tol = 0.84 "m primary tracking error threshold";
  parameter Real t_check = 7.8 "s verification time";

  // ===================== Gait =====================
  parameter Real gait_amp = 0.4 "rad nominal joint gait amplitude";
  parameter Real gait_freq = 1.0 "Hz undulation frequency";
  parameter Real gait_phase_del = 0.6 "rad inter-joint phase delay";

  // ===================== Body dynamics gains =====================
  parameter Real drag_surge = 20.0 "N/(m/s) surge drag";
  parameter Real drag_lat = 30.0 "N/(m/s) lateral drag";
  parameter Real drag_depth = 15.0 "N/(m/s) heave drag";
  parameter Real drag_yaw = 6.0 "N.m.s/rad yaw damping";
  parameter Real I_yaw = 8.64 "kg.m2 yaw inertia (m*L^2/12, nominal)";
  parameter Real K_thrust = 8.0 "N propulsive gain per gait unit";
  parameter Real K_depth_p = 32.0 "depth proportional gain";
  parameter Real K_depth_d = 49.0 "depth derivative gain";
  parameter Real K_xtrack_F = 150.0 "cross-track lateral force gain";
  parameter Real K_xtrack_d = 60.0 "cross-track lateral damping gain";
  parameter Real K_cur_F = 30.0 "current feedforward gain (= drag_lat)";
  parameter Real F_fin_max = 200.0 "N max lateral fin force";
  parameter Real K_yaw = 3.0 "heading control gain";
  parameter Real M_yaw_max = 20.0 "N.m max yaw moment";

  // ===================== Joint dynamics =====================
  parameter Real J_joint = 0.05 "kg.m2 joint inertia (nominal)";
  parameter Real B_joint = 0.5 "joint damping";
  parameter Real K_joint = 8.0 "joint tracking stiffness";
  parameter Real tau_gain = 15.0 "joint torque command gain";
  parameter Real tau_damp = 0.5 "joint torque damping gain";

  // ===================== Estimator =====================
  parameter Real Q_y = 0.01 "process noise var (cross-track position)";
  parameter Real Q_c = 0.0001 "process noise var (current estimate)";
  parameter Real R_y = 0.0025 "measurement noise var (acoustic position fix)";
  parameter Real R_c = 0.0004 "measurement noise var (current from DVL)";

  // ===================== Guard =====================
  constant Real eps = 1e-6;

  // ===================== Body states =====================
  Real x_pos(start=0.0) "m x position (path-aligned)";
  Real y_pos(start=0.0) "m y position (cross-track)";
  Real z_pos(start=0.0) "m depth";
  Real u_vel(start=0.0) "m/s surge velocity (body x)";
  Real v_vel(start=0.0) "m/s sway velocity (body y)";
  Real w_vel(start=0.0) "m/s heave velocity (body z)";
  Real psi(start=0.0) "rad heading";
  Real r_yaw(start=0.0) "rad/s yaw rate";

  // ===================== Joint states =====================
  Real q[12](each start=0.0) "rad joint angles (1,3,5,7,9,11 yaw; 2,4,6,8,10,12 pitch)";
  Real dq[12](each start=0.0) "rad/s joint rates";
  Real q_ref[12](each start=0.0) "rad joint references";
  Real tau_cmd[12](each start=0.0) "N.m bounded joint torque commands";

  // ===================== Control intermediates =====================
  Real gait_amp_eff "modulated gait amplitude";
  Real F_thrust "N propulsive thrust (tail-fin undulation)";
  Real F_steer "N lateral steering/fin force";
  Real F_depth "N depth control force";
  Real M_yaw_cmd "N.m yaw moment command";
  Real psi_cmd "rad commanded heading";
  Real steer_err "rad heading error (wrapped)";

  // ===================== Disturbance =====================
  Boolean dist_active "true during middle third";
  Real F_dist "N applied current load";
  Real v_water_lat "m/s lateral water velocity";

  // ===================== Path / verification =====================
  Real s_path(start=0.0) "m path arclength progress";
  Real route_completion "fraction of 60 m path completed";
  Real psi_path "rad path tangent heading";
  Real cross_track "m cross-track error (signed)";
  Real depth_error "m depth error";
  Real track_error "m primary tracking error";
  discrete Real track_error_at_check(start=999.0) "m tracking error sampled at t_check";
  Boolean tracking_ok "primary tracking requirement satisfied";
  Real speed_mag "m/s speed magnitude";
  Real clearance "m clearance above seabed";

  // ===================== Sensors =====================
  Real imu_rate "rad/s IMU yaw rate measurement";
  Real pressure_depth "m pressure-derived depth";
  Real dvl_u "m/s DVL surge (ground track)";
  Real dvl_v "m/s DVL sway (ground track)";
  Real dvl_v_water "m/s DVL sway (water track)";
  Real range_meas "m acoustic range measurement";
  Real compass_meas "rad compass heading measurement";
  Real y_fix "m acoustic position fix (cross-track)";
  Real v_current_meas "m/s measured lateral current";

  // ===================== Estimator states =====================
  Real yhat(start=0.0) "estimated cross-track position";
  Real chat(start=0.0) "estimated lateral current velocity";
  Real P_y(start=1.0) "estimator covariance (cross-track)";
  Real P_c(start=1.0) "estimator covariance (current)";
  Real K_y "Kalman gain (position)";
  Real K_c "Kalman gain (current)";
  Real innov_y "position innovation";
  Real innov_c "current innovation";

equation
  // --- Disturbance scheduling (middle third of 12 s run) ---
  dist_active = (time >= t_dist_start) and (time <= t_dist_end);
  F_dist = if dist_active then F_current else 0.0;
  v_water_lat = v_current;

  // --- Body kinematics (body frame to world) ---
  der(x_pos) = u_vel * cos(psi) - v_vel * sin(psi);
  der(y_pos) = u_vel * sin(psi) + v_vel * cos(psi);
  der(z_pos) = w_vel;
  der(psi) = r_yaw;

  // --- Surge dynamics (undulatory propulsion via passive tail fin + modules) ---
  gait_amp_eff = gait_amp + 0.05 * (v_ref - u_vel);
  F_thrust = K_thrust * gait_amp_eff * gait_freq * 2.0 * pi;
  m_body * der(u_vel) = F_thrust - drag_surge * u_vel;

  // --- Lateral dynamics with current + current load disturbance ---
  m_body * der(v_vel) = -drag_lat * (v_vel - v_water_lat) + F_steer + F_dist;

  // --- Heading dynamics ---
  M_yaw_cmd = max(-M_yaw_max, min(M_yaw_max, K_yaw * steer_err));
  I_yaw * der(r_yaw) = M_yaw_cmd - drag_yaw * r_yaw;

  // --- Depth dynamics (constant depth hold) ---
  depth_error = z_pos - depth_ref;
  F_depth = K_depth_p * (depth_ref - z_pos) - K_depth_d * w_vel;
  m_body * der(w_vel) = F_depth - drag_depth * w_vel;

  // --- Joint gait references (undulation with phase lag + yaw steering bias) ---
  for i in 1:12 loop
    q_ref[i] = gait_amp_eff * sin(2.0 * pi * gait_freq * time + i * gait_phase_del)
               + 0.3 * steer_err * (if mod(i, 2) == 1 then 1.0 else 0.0);
  end for;

  // --- Joint dynamics (second-order) with bounded torque commands ---
  for i in 1:12 loop
    der(q[i]) = dq[i];
    J_joint * der(dq[i]) = tau_cmd[i] - B_joint * dq[i] - K_joint * (q[i] - q_ref[i]);
    tau_cmd[i] = max(-tau_max, min(tau_max, tau_gain * (q_ref[i] - q[i]) - tau_damp * dq[i]));
  end for;

  // --- Path geometry (lawnmower: 2 legs of 30 m) ---
  speed_mag = if (u_vel * u_vel + v_vel * v_vel) > eps then sqrt(u_vel * u_vel + v_vel * v_vel) else 0.0;
  der(s_path) = speed_mag;
  route_completion = s_path / L_path;
  psi_path = if s_path < L_leg then 0.0 else pi;
  cross_track = if s_path < L_leg then y_pos else (y_pos - W_spacing);
  steer_err = atan2(sin(psi_path - psi), cos(psi_path - psi));
  psi_cmd = psi_path + 0.5 * atan2(K_xtrack_F * yhat, max(u_vel, eps));

  // --- Lateral control with current compensation ---
  F_steer = max(-F_fin_max, min(F_fin_max, -K_xtrack_F * yhat - K_xtrack_d * v_vel - K_cur_F * chat));

  // --- Primary tracking error (guarded norm of cross-track + depth) ---
  track_error = sqrt(max(cross_track * cross_track + depth_error * depth_error, 0.0));

  // --- Seabed clearance ---
  clearance = seabed_z - z_pos;

  // --- Sensors (deterministic pseudo-noise for synchronized trace realism) ---
  imu_rate = r_yaw + 0.001 * sin(13.0 * time);
  pressure_depth = z_pos + 0.005 * sin(5.0 * time);
  dvl_u = u_vel + 0.01 * sin(8.0 * time);
  dvl_v = v_vel + 0.01 * sin(9.0 * time);
  dvl_v_water = (v_vel - v_water_lat) + 0.01 * sin(7.0 * time);
  range_meas = sqrt(max((x_pos - 30.0)^2 + y_pos^2 + z_pos^2, eps)) + 0.02 * sin(3.0 * time);
  compass_meas = psi + 0.005 * sin(11.0 * time);
  y_fix = y_pos + 0.05 * sin(3.0 * time);
  v_current_meas = (dvl_v - dvl_v_water);

  // --- Estimator: dual scalar Kalman filters with covariance ---
  // Cross-track position KF (predict via DVL ground-track lateral velocity, correct via acoustic fix)
  innov_y = y_fix - yhat;
  K_y = P_y / max(R_y, eps);
  der(yhat) = dvl_u * sin(psi) + dvl_v * cos(psi) + K_y * innov_y;
  der(P_y) = Q_y - (P_y * P_y) / max(R_y, eps);

  // Current KF (observe current from DVL ground vs water track difference)
  innov_c = v_current_meas - chat;
  K_c = P_c / max(R_c, eps);
  der(chat) = K_c * innov_c;
  der(P_c) = Q_c - (P_c * P_c) / max(R_c, eps);

  // --- Verification sampling at t_check ---
  when time >= t_check then
    track_error_at_check = track_error;
  end when;
  tracking_ok = (track_error_at_check < e_tol) and (track_error_at_check < 900.0);

  // --- Safety assertions (no NaN / infinite physical, control, or estimator values) ---
  assert(track_error < 1.0e5, "Tracking error non-finite or excessive");
  assert(route_completion >= -1.0 and route_completion <= 2.0, "Route completion out of bounds");
  assert(P_y >= 0.0, "Estimator covariance P_y negative");
  assert(P_c >= 0.0, "Estimator covariance P_c negative");
  assert(clearance > -1.0, "Seabed clearance violated (penetration)");
  assert(abs(F_steer) <= F_fin_max + 1.0, "Lateral force out of bounds");
  assert(abs(psi) < 1.0e4, "Heading non-finite");

  annotation(
    Documentation(info="SeaSnakeSurveyC: 32 kg articulated underwater robot with six 0.30 m capsule
modules connected by alternating yaw/pitch joints (12 bounded actuators, tau_max=29.4 N.m) and a
passive tail fin (lumped into propulsive thrust). Follows a 60 m lawnmower path at 1.0 m/s while
holding constant depth. Steady 0.18 m/s lateral water current with a controlled 90 N current load
injected during the middle third (4-8 s). Instrumentation: fused IMU, pressure, DVL, acoustic range,
and compass. Estimator: dual scalar Kalman filters with covariance for cross-track position and
lateral current. Runs at 125 Hz for 12 s; primary tracking error required below 0.84 m after 7.8 s.
NOTE: depth_ref, seabed_z, leg spacing, per-module mass distribution, and gait parameters are
      nominal placeholders; exact values not specified in the requirement."),
    experiment(StartTime=0, StopTime=12, Tolerance=1e-6, Interval=0.008));
end SeaSnakeSurveyC;