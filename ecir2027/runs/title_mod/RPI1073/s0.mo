model TriTugInspectE
  constant Real pi = 3.141592653589793;

  // Run and sampling
  parameter Real Ts(unit="s") = 0.004 "250 Hz controller, estimator, and acceptance sampling";
  parameter Real T_run(unit="s") = 16.0;
  parameter Real v_ref(unit="m/s") = 0.8;

  // Corridor and path
  parameter Real path_length(unit="m") = 12.8;
  parameter Real path_end_x(unit="m") = 12.66 "Not specified; finite S-corridor end selected for simulation only";
  parameter Real path_amplitude(unit="m") = 0.40 "Not specified; finite S-corridor amplitude selected for simulation only";
  parameter Real corridor_width(unit="m") = 1.8;
  parameter Real half_width(unit="m") = 0.9;
  parameter Real alcove_depth(unit="m") = 0.30 "Not specified; finite recess selected for simulation only";
  parameter Real alcove1_start(unit="m") = 3.0 "Not specified; finite alcove placement selected for simulation only";
  parameter Real alcove1_end(unit="m") = 4.0;
  parameter Real alcove2_start(unit="m") = 8.0 "Not specified; finite alcove placement selected for simulation only";
  parameter Real alcove2_end(unit="m") = 9.0;

  // Plant: stated masses and front wheel
  parameter Real m_chassis(unit="kg") = 38.0;
  parameter Real m_payload(unit="kg") = 20.0;
  parameter Real m_total(unit="kg") = 58.0;
  parameter Real r_w(unit="m") = 0.15;
  parameter Real steer_travel(unit="rad") = 0.60;
  parameter Real tau_max(unit="N.m") = 37.4;

  // Plant: geometry and dynamics not specified; finite values selected for simulation only
  parameter Real Lwb(unit="m") = 0.80;
  parameter Real Tr(unit="m") = 0.60;
  parameter Real J_z(unit="kg.m2") = 4.8333;
  parameter Real b_u(unit="N.s/m") = 10.0;
  parameter Real b_v(unit="N.s/m") = 20.0;
  parameter Real b_r(unit="N.m.s/rad") = 10.0;
  parameter Real C_f(unit="N/rad") = 3000.0;
  parameter Real C_r(unit="N/rad") = 3000.0;
  parameter Real J_s(unit="kg.m2") = 0.05;
  parameter Real b_s(unit="N.m.s/rad") = 0.5;
  parameter Real k_center(unit="N.m/rad") = 1.0;

  // Disturbance
  parameter Real F_side(unit="N") = 108.0;
  parameter Real t_side_start(unit="s") = T_run/3.0;
  parameter Real t_side_end(unit="s") = 2.0*T_run/3.0;

  // Sensors: noise levels not specified; finite values selected for simulation only
  parameter Real lidar_range(unit="m") = 15.0;
  parameter Real wheel_noise(unit="rad/s") = 0.01;
  parameter Real imu_rate_noise(unit="rad/s") = 0.001;
  parameter Real imu_accel_noise(unit="m/s2") = 0.02;
  parameter Real lidar_pos_noise(unit="m") = 0.02;
  parameter Real lidar_theta_noise(unit="rad") = 0.005;

  // Estimator: gains and covariance rates not specified; finite values selected for simulation only
  parameter Real alpha_l(unit="1/s") = 5.0;
  parameter Real alpha_th(unit="1/s") = 5.0;
  parameter Real beta_v(unit="1/s") = 1.0;
  parameter Real Qodom(unit="m2/s") = 1.0e-4;
  parameter Real Qimu(unit="rad2/s") = 1.0e-5;

  // Controller: gains not specified; finite stabilizing values selected for simulation only
  parameter Real k_y(unit="rad/m") = 2.0;
  parameter Real k_th = 1.5;
  parameter Real k_r(unit="s") = 0.2;
  parameter Real k_v(unit="s/m") = 0.1;
  parameter Real k_avoid(unit="rad/m") = 1.0;
  parameter Real guard_margin(unit="m") = 0.30 "Controller guard margin, not acceptance threshold";
  parameter Real k_delta(unit="N.m/rad") = 50.0;
  parameter Real k_omega(unit="N.m.s/rad") = 2.0;
  parameter Real k_u(unit="N.m.s/m") = 100.0;
  parameter Real k_x(unit="N.m/m") = 10.0;

  // Plant states
  Real x(start=0, unit="m") "Planar x position at rear axle center";
  Real y(start=0, unit="m") "Planar y position at rear axle center";
  Real theta(start=0, unit="rad") "Planar heading";
  Real u(start=0.8, unit="m/s") "Body longitudinal velocity";
  Real v(start=0, unit="m/s") "Body lateral velocity";
  Real r(start=0, unit="rad/s") "Yaw rate";
  Real delta_state(start=0, unit="rad") "Unclipped steering angle state";
  Real delta(start=0, unit="rad") "Front steering angle, limited to travel";
  Real omega_delta(start=0, unit="rad/s") "Steering axis angular velocity";

  // Path reference states
  Real x_ref(start=0, unit="m");
  Real s_ref(start=0, unit="m") "Reference arc-length progress";
  Real s_actual(start=0, unit="m") "Actual traveled arc length";

  // Wheel speeds
  Real omega_f(unit="rad/s") "Front drive wheel rolling speed";
  Real omega_rl(unit="rad/s") "Passive rear-left wheel rolling speed";
  Real omega_rr(unit="rad/s") "Passive rear-right wheel rolling speed";

  // Forces and torques
  Real F_trac(unit="N") "Front traction force along wheel plane";
  Real Fyf(unit="N") "Front lateral tire force";
  Real Fr_lat(unit="N") "Rear passive lateral force";
  Real Ff_long(unit="N") "Front force body x component";
  Real Ff_lat(unit="N") "Front force body y component";
  Real F_side_applied(unit="N") "Controlled side load";
  Real tau_trac(unit="N.m") "Bounded front traction torque";
  Real tau_steer(unit="N.m") "Bounded front steering torque";
  discrete Real tau_trac_cmd(start=1.2, unit="N.m") "Sampled traction torque command";
  discrete Real tau_steer_cmd(start=0, unit="N.m") "Sampled steering torque command";

  // Path variables
  Real k_path(unit="1/m");
  Real y_ref(unit="m");
  Real dydx_ref;
  Real d2y_ref(unit="1/m");
  Real theta_ref(unit="rad");
  Real curvature_ref(unit="1/m");
  Real vx(unit="m/s") "World x velocity";
  Real vy(unit="m/s") "World y velocity";
  Real speed_sq(unit="(m/s)2");
  Real u_safe(unit="m/s");

  // Wall geometry and clearance
  Real y_c_at_x(unit="m");
  Real left_recess(unit="m");
  Real right_recess(unit="m");
  Real y_wall_left(unit="m");
  Real y_wall_right(unit="m");
  Real clear_left(unit="m");
  Real clear_right(unit="m");
  Real wall_clear(unit="m");
  Real y_c_hat(unit="m");
  Real left_recess_hat(unit="m");
  Real right_recess_hat(unit="m");
  Real y_wall_left_hat(unit="m");
  Real y_wall_right_hat(unit="m");
  Real clear_left_hat(unit="m");
  Real clear_right_hat(unit="m");

  // Sensors
  Real omega_rl_m(unit="rad/s");
  Real omega_rr_m(unit="rad/s");
  Real u_odom(unit="m/s");
  Real r_odom(unit="rad/s");
  Real r_imu(unit="rad/s");
  Real a_x_imu(unit="m/s2");
  Real a_y_imu(unit="m/s2");
  Real odom_x(start=0, unit="m");
  Real odom_y(start=0, unit="m");
  Real odom_theta(start=0, unit="rad");
  Boolean lidar_valid;
  Real lidar_noise_x(unit="m");
  Real lidar_noise_y(unit="m");
  Real lidar_noise_theta(unit="rad");
  Real lidar_x(unit="m");
  Real lidar_y(unit="m");
  Real lidar_theta(unit="rad");

  // Estimator states
  Real x_hat(start=0, unit="m");
  Real y_hat(start=0, unit="m");
  Real theta_hat(start=0, unit="rad");
  Real v_hat(start=0, unit="m/s");
  Real Pxx(start=0.1, unit="m2");
  Real Pyy(start=0.1, unit="m2");
  Real Pth(start=0.01, unit="rad2");

  // Controller variables
  Real e_x_hat(unit="m");
  Real e_y_hat(unit="m");
  Real e_th_hat_raw(unit="rad");
  Real e_th_hat(unit="rad");
  Real delta_ff(unit="rad");
  Real delta_side_ff(unit="rad");
  Real right_need(unit="m");
  Real left_need(unit="m");
  Real delta_avoid(unit="rad");
  Real delta_des(unit="rad");
  Real speed_sq_meas(unit="(m/s)2");
  Real speed_meas(unit="m/s");
  Real tau_trac_ff(unit="N.m");

  // Acceptance observables
  Real e_x_primary(unit="m");
  Real e_y_primary(unit="m");
  Real heading_error(unit="rad");
  Boolean wall_clear_ok;
  Boolean tracking_ok;
  Boolean heading_ok;
  Boolean cov_ok;
  Boolean route_done;
  discrete Boolean finite_all(start=true);
  discrete Boolean finite_violation(start=false);
  discrete Boolean cov_violation(start=false);
  discrete Boolean wall_clear_violation(start=false);
  discrete Boolean tracking_violation(start=false);
  discrete Boolean route_violation(start=false);
  discrete Boolean heading_violation(start=false);
  Boolean accept;

  // Synchronized 250 Hz traces
  discrete Real trace_time(start=0, unit="s");
  discrete Real trace_x(start=0, unit="m");
  discrete Real trace_y(start=0, unit="m");
  discrete Real trace_theta(start=0, unit="rad");
  discrete Real trace_u(start=0.8, unit="m/s");
  discrete Real trace_v(start=0, unit="m/s");
  discrete Real trace_delta(start=0, unit="rad");
  discrete Real trace_tau_trac_cmd(start=1.2, unit="N.m");
  discrete Real trace_tau_steer_cmd(start=0, unit="N.m");
  discrete Real trace_x_hat(start=0, unit="m");
  discrete Real trace_y_hat(start=0, unit="m");
  discrete Real trace_theta_hat(start=0, unit="rad");
  discrete Real trace_lidar_x(start=0, unit="m");
  discrete Real trace_lidar_y(start=0, unit="m");
  discrete Real trace_lidar_theta(start=0, unit="rad");
  discrete Real trace_wall_clear(start=0.9, unit="m");
  discrete Real trace_e_y_primary(start=0, unit="m");
  discrete Real trace_heading_error(start=0, unit="rad");
  discrete Boolean trace_accept(start=false);

equation
  // Reference S path
  k_path = 2.0*pi/path_end_x;
  y_ref = path_amplitude*sin(k_path*x_ref);
  dydx_ref = path_amplitude*k_path*cos(k_path*x_ref);
  d2y_ref = -path_amplitude*k_path*k_path*sin(k_path*x_ref);
  theta_ref = atan(dydx_ref);
  curvature_ref = d2y_ref/((1.0 + dydx_ref*dydx_ref)*sqrt(1.0 + dydx_ref*dydx_ref));
  der(x_ref) = v_ref/sqrt(1.0 + dydx_ref*dydx_ref);
  der(s_ref) = v_ref;

  // Actual planar kinematics
  vx = u*cos(theta) - v*sin(theta);
  vy = u*sin(theta) + v*cos(theta);
  der(x) = vx;
  der(y) = vy;
  der(theta) = r;
  speed_sq = vx*vx + vy*vy;
  der(s_actual) = if speed_sq > 1.0e-12 then sqrt(speed_sq) else 0.0;

  // Actuator saturation and effort control
  tau_trac = max(-tau_max, min(tau_max, tau_trac_cmd));
  tau_steer = max(-tau_max, min(tau_max, tau_steer_cmd));
  F_trac = tau_trac/r_w;

  // Safe denominators
  u_safe = if u > 0.1 then u else 0.1;

  // Tire forces: simple linear slip model, finite values selected for simulation only
  Fyf = C_f*(delta - atan((v + Lwb*r)/u_safe));
  Fr_lat = -C_r*atan(v/u_safe);
  Ff_long = F_trac*cos(delta) - Fyf*sin(delta);
  Ff_lat = F_trac*sin(delta) + Fyf*cos(delta);

  // Controlled middle-third side load
  F_side_applied = if time >= t_side_start and time <= t_side_end then F_side else 0.0;

  // Chassis dynamics
  m_total*der(u) = Ff_long - b_u*u;
  m_total*der(v) = Ff_lat + Fr_lat + F_side_applied - b_v*v;
  J_z*der(r) = Lwb*Ff_lat - b_r*r;

  // Steering axis dynamics and travel limit
  J_s*der(omega_delta) = tau_steer - b_s*omega_delta - k_center*delta_state;
  der(delta_state) = omega_delta;
  delta = max(-steer_travel, min(steer_travel, delta_state));

  // Wheel rolling speeds
  omega_f = (u*cos(delta) + (v + Lwb*r)*sin(delta))/r_w;
  omega_rl = (u - r*Tr/2.0)/r_w;
  omega_rr = (u + r*Tr/2.0)/r_w;

  // Wheel odometry
  omega_rl_m = omega_rl + wheel_noise*sin(2.0*pi*13.0*time);
  omega_rr_m = omega_rr + wheel_noise*sin(2.0*pi*17.0*time + 1.0);
  u_odom = (omega_rl_m + omega_rr_m)*r_w/2.0;
  r_odom = (omega_rr_m - omega_rl_m)*r_w/Tr;
  der(odom_x) = u_odom*cos(odom_theta);
  der(odom_y) = u_odom*sin(odom_theta);
  der(odom_theta) = r_odom;

  // IMU
  r_imu = r + imu_rate_noise*sin(2.0*pi*11.0*time);
  a_x_imu = (Ff_long - b_u*u)/m_total - r*v + imu_accel_noise*sin(2.0*pi*9.0*time);
  a_y_imu = (Ff_lat + Fr_lat + F_side_applied - b_v*v)/m_total + r*u + imu_accel_noise*cos(2.0*pi*9.0*time);

  // Lidar pose measurement with 15 m range limit
  lidar_noise_x = lidar_pos_noise*sin(2.0*pi*0.7*time);
  lidar_noise_y = lidar_pos_noise*cos(2.0*pi*0.6*time);
  lidar_noise_theta = lidar_theta_noise*sin(2.0*pi*1.3*time);
  lidar_valid = wall_clear <= lidar_range;
  lidar_x = if lidar_valid then x + lidar_noise_x else x_hat;
  lidar_y = if lidar_valid then y + lidar_noise_y else y_hat;
  lidar_theta = if lidar_valid then theta + lidar_noise_theta else theta_hat;

  // Fused localization estimator
  der(x_hat) = u_odom*cos(theta_hat) - v_hat*sin(theta_hat) + alpha_l*(lidar_x - x_hat);
  der(y_hat) = u_odom*sin(theta_hat) + v_hat*cos(theta_hat) + alpha_l*(lidar_y - y_hat);
  der(theta_hat) = r_imu + alpha_th*(lidar_theta - theta_hat);
  der(v_hat) = a_y_imu - beta_v*v_hat;

  // Finite covariance propagation
  der(Pxx) = Qodom - 2.0*alpha_l*Pxx;
  der(Pyy) = Qodom - 2.0*alpha_l*Pyy;
  der(Pth) = Qimu - 2.0*alpha_th*Pth;

  // Walls and clearances
  y_c_at_x = path_amplitude*sin(k_path*x);
  left_recess = if x >= alcove1_start and x <= alcove1_end then alcove_depth else 0.0;
  right_recess = if x >= alcove2_start and x <= alcove2_end then alcove_depth else 0.0;
  y_wall_left = y_c_at_x + half_width + left_recess;
  y_wall_right = y_c_at_x - half_width - right_recess;
  clear_left = y_wall_left - y;
  clear_right = y - y_wall_right;
  wall_clear = if clear_left < clear_right then clear_left else clear_right;

  y_c_hat = path_amplitude*sin(k_path*x_hat);
  left_recess_hat = if x_hat >= alcove1_start and x_hat <= alcove1_end then alcove_depth else 0.0;
  right_recess_hat = if x_hat >= alcove2_start and x_hat <= alcove2_end then alcove_depth else 0.0;
  y_wall_left_hat = y_c_hat + half_width + left_recess_hat;
  y_wall_right_hat = y_c_hat - half_width - right_recess_hat;
  clear_left_hat = y_wall_left_hat - y_hat;
  clear_right_hat = y_hat - y_wall_right_hat;

  // Localization-aware path tracking and obstacle avoidance
  e_x_hat = cos(theta_ref)*(x_hat - x_ref) + sin(theta_ref)*(y_hat - y_ref);
  e_y_hat = -sin(theta_ref)*(x_hat - x_ref) + cos(theta_ref)*(y_hat - y_ref);
  e_th_hat_raw = theta_hat - theta_ref;
  e_th_hat = e_th_hat_raw - 2.0*pi*floor((e_th_hat_raw + pi)/(2.0*pi));

  delta_ff = atan(Lwb*curvature_ref);
  delta_side_ff = -F_side_applied/C_f;
  right_need = max(0.0, guard_margin - clear_right_hat);
  left_need = max(0.0, guard_margin - clear_left_hat);
  delta_avoid = k_avoid*(right_need - left_need);
  delta_des = max(-steer_travel, min(steer_travel,
             delta_ff + delta_side_ff
             - k_y*e_y_hat - k_th*e_th_hat
             - k_r*r_imu - k_v*v_hat
             + delta_avoid));

  speed_sq_meas = u_odom*u_odom + v_hat*v_hat;
  speed_meas = if speed_sq_meas > 1.0e-12 then sqrt(speed_sq_meas) else 0.0;
  tau_trac_ff = b_u*v_ref*r_w;

  // Primary acceptance observables
  e_x_primary = cos(theta_ref)*(x - x_ref) + sin(theta_ref)*(y - y_ref);
  e_y_primary = -sin(theta_ref)*(x - x_ref) + cos(theta_ref)*(y - y_ref);
  heading_error = (theta - theta_ref) - 2.0*pi*floor((theta - theta_ref + pi)/(2.0*pi));

  // Acceptance conditions
  wall_clear_ok = wall_clear > 0.18;
  tracking_ok = if time >= 10.4 then abs(e_y_primary) < 0.18 else true;
  cov_ok = Pxx > 0.0 and Pyy > 0.0 and Pth > 0.0 and Pxx < 1.0e6 and Pyy < 1.0e6 and Pth < 1.0e6;
  route_done = s_actual >= path_length - 1.0e-3;
  heading_ok = abs(heading_error) <= pi and finite_all;
  accept = if time >= T_run then
           (not (finite_violation or cov_violation or wall_clear_violation or tracking_violation or route_violation or heading_violation)) and route_done
           else false;

algorithm
  when sample(0, Ts) then
    // Effort commands bounded by 37.4 N.m
    tau_trac_cmd := max(-tau_max, min(tau_max, tau_trac_ff + k_u*(v_ref - speed_meas) - k_x*e_x_hat));
    tau_steer_cmd := max(-tau_max, min(tau_max, k_delta*(delta_des - delta) - k_omega*omega_delta));

    // Finite-value and covariance latching
    finite_all := abs(x) < 1.0e9 and abs(y) < 1.0e9 and abs(theta) < 1.0e9 and
                  abs(u) < 1.0e9 and abs(v) < 1.0e9 and abs(r) < 1.0e9 and
                  abs(delta_state) < 1.0e9 and abs(delta) < 1.0e9 and abs(omega_delta) < 1.0e9 and
                  abs(omega_f) < 1.0e9 and abs(omega_rl) < 1.0e9 and abs(omega_rr) < 1.0e9 and
                  abs(vx) < 1.0e9 and abs(vy) < 1.0e9 and abs(s_actual) < 1.0e9 and
                  abs(F_trac) < 1.0e9 and abs(Fyf) < 1.0e9 and abs(Fr_lat) < 1.0e9 and
                  abs(Ff_long) < 1.0e9 and abs(Ff_lat) < 1.0e9 and abs(F_side_applied) < 1.0e9 and
                  abs(tau_trac) < 1.0e9 and abs(tau_steer) < 1.0e9 and
                  abs(tau_trac_cmd) < 1.0e9 and abs(tau_steer_cmd) < 1.0e9 and abs(delta_des) < 1.0e9 and
                  abs(x_hat) < 1.0e9 and abs(y_hat) < 1.0e9 and abs(theta_hat) < 1.0e9 and abs(v_hat) < 1.0e9 and
                  abs(Pxx) < 1.0e9 and abs(Pyy) < 1.0e9 and abs(Pth) < 1.0e9 and
                  abs(odom_x) < 1.0e9 and abs(odom_y) < 1.0e9 and abs(odom_theta) < 1.0e9 and
                  abs(u_odom) < 1.0e9 and abs(r_odom) < 1.0e9 and abs(r_imu) < 1.0e9 and
                  abs(a_x_imu) < 1.0e9 and abs(a_y_imu) < 1.0e9 and
                  abs(lidar_x) < 1.0e9 and abs(lidar_y) < 1.0e9 and abs(lidar_theta) < 1.0e9 and
                  abs(e_y_primary) < 1.0e9 and abs(heading_error) < 1.0e9;

    if not finite_all then
      finite_violation := true;
    end if;

    if not cov_ok then
      cov_violation := true;
    end if;

    if not wall_clear_ok then
      wall_clear_violation := true;
    end if;

    if time >= 10.4 and abs(e_y_primary) >= 0.18 then
      tracking_violation := true;
    end if;

    if time >= T_run and not route_done then
      route_violation := true;
    end if;

    if abs(heading_error) > pi then
      heading_violation := true;
    end if;

    // Synchronized traces at 250 Hz
    trace_time := time;
    trace_x := x;
    trace_y := y;
    trace_theta := theta;
    trace_u := u;
    trace_v := v;
    trace_delta := delta;
    trace_tau_trac_cmd := tau_trac_cmd;
    trace_tau_steer_cmd := tau_steer_cmd;
    trace_x_hat := x_hat;
    trace_y_hat := y_hat;
    trace_theta_hat := theta_hat;
    trace_lidar_x := lidar_x;
    trace_lidar_y := lidar_y;
    trace_lidar_theta := lidar_theta;
    trace_wall_clear := wall_clear;
    trace_e_y_primary := e_y_primary;
    trace_heading_error := heading_error;
    trace_accept := (time >= T_run) and
                    (not (finite_violation or cov_violation or wall_clear_violation or tracking_violation or route_violation or heading_violation)) and
                    route_done;
  end when;

end TriTugInspectE;

annotation(experiment(StartTime=0, StopTime=16, Tolerance=1.0e-6, Interval=0.004));