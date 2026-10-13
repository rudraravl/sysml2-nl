model GroundPairResilientE
  /* Scenario: two 14 kg differential-drive robots in one shared scene.
     A controlled 1.2 s communication dropout occurs in the middle third of
     a 16 s run at 250 Hz. During the dropout a shared lateral disturbance is
     applied and robot 2 keeps coordinating using dead-reckoned prediction of
     the last-received peer state. Acceptance is fail-closed. */

  // ===== Parameters stated by the requirement =====
  parameter Real m_robot(unit="kg")   = 14.0  "robot mass";
  parameter Real r_wheel(unit="m")    = 0.09  "wheel radius";
  parameter Real tau_max(unit="N.m")  = 11.0  "per-wheel command magnitude bound";
  parameter Real f_ctrl(unit="Hz")    = 250.0 "control / simulation rate";
  parameter Real t_end(unit="s")      = 16.0  "run duration";
  parameter Real t_drop_dur(unit="s") = 1.2   "communication dropout duration";
  parameter Real t_check(unit="s")    = 10.4  "acceptance check time";
  parameter Real e_track_limit(unit="m") = 0.54 "primary tracking error limit after t_check";

  // Dropout placed in the middle third of [0, t_end], 1.2 s centered at 8.0 s.
  parameter Real t_drop_start(unit="s") = 8.0 - t_drop_dur/2 "dropout start";
  parameter Real t_drop_end(unit="s")   = 8.0 + t_drop_dur/2 "dropout end";

  // ===== Parameters NOT stated by the requirement (assumed; labeled) =====
  parameter Real L_base(unit="m")      = 0.30 "wheel base (assumed)";
  parameter Real J_body(unit="kg.m2")   = 0.05 "yaw inertia (assumed)";
  parameter Real c_lin(unit="N.s/m")    = 1.5  "linear drag (assumed)";
  parameter Real c_rot(unit="N.m.s/rad")= 0.5  "rotational drag (assumed)";
  parameter Real x_target(unit="m")     = 5.0  "route terminal x (assumed)";
  parameter Real d_form(unit="m")       = 1.0  "formation lateral offset (assumed)";
  parameter Real v_ref(unit="m/s")      = 0.35 "route cruise speed (assumed)";
  parameter Real F_dist(unit="N")       = 1.5  "shared disturbance magnitude (assumed)";
  parameter Real Kp_pos = 8.0  "position proportional gain (assumed)";
  parameter Real Kd_pos = 4.0  "position derivative gain (assumed)";
  parameter Real Kp_th  = 6.0  "heading proportional gain (assumed)";
  parameter Real Kd_th  = 2.5  "heading derivative gain (assumed)";
  parameter Real r_safe(unit="m") = 0.25 "collision-avoidance radius (assumed)";
  parameter Real eps = 1.0e-6        "zero-error branch guard for divisors";
  parameter Real dt_ctrl(unit="s") = 1.0/f_ctrl "control period";

  // ===== Continuous plant states =====
  Real x1(start=0),     y1(start=0),     theta1(start=0);
  Real vx1(start=0),    vy1(start=0),    omega1(start=0);
  Real x2(start=0),     y2(start=d_form),theta2(start=0);
  Real vx2(start=0),    vy2(start=0),    omega2(start=0);
  Real enc_R1(start=0), enc_L1(start=0), enc_R2(start=0), enc_L2(start=0);

  // ===== Discrete control / communication (zero-order hold at f_ctrl) =====
  discrete Real tau_R1_cmd(start=0), tau_L1_cmd(start=0);
  discrete Real tau_R2_cmd(start=0), tau_L2_cmd(start=0);
  discrete Real x1_rx(start=0), y1_rx(start=0), theta1_rx(start=0);
  discrete Real vx1_rx(start=0), vy1_rx(start=0), omega1_rx(start=0);
  discrete Real x2_rx(start=0), y2_rx(start=0), theta2_rx(start=0);
  discrete Real vx2_rx(start=0), vy2_rx(start=0), omega2_rx(start=0);
  discrete Real t_rx1(start=0), t_rx2(start=0);
  discrete Real e_form_degraded_c(start=0);
  discrete Real e_form_recovered_c(start=0);
  discrete Real e_track_at_check_c(start=1.0e9);
  discrete Boolean degraded_captured(start=false);
  discrete Boolean recovered_captured(start=false);
  discrete Boolean route_captured(start=false);
  discrete Boolean completed_route_c(start=false);

  // ===== Communication / disturbance predicates =====
  Boolean comm_ok, drop_active, dist_active;
  Real F_dist_y;

  // ===== Predicted peer state (dead reckoning) =====
  Real x1_pred, y1_pred, theta1_pred;
  Real x1_used, y1_used, theta1_used;

  // ===== Reference, errors, observables =====
  Real x_ref, y_ref, v_ref_eff;
  Real e_track, e_form, dist_robots, Fy_repulse;
  Real imu_w1, imu_w2, lidar_rel_x, lidar_rel_y;
  Real v1_body, v2_body;
  Real omega_wR1, omega_wL1, omega_wR2, omega_wL2;

  // ===== Intermediate control quantities (observable) =====
  Real Fx_des1, Fy_des1, F_fwd1, M_des1, theta_des1, eth1, norm1;
  Real Fx_des2, Fy_des2, F_fwd2, M_des2, theta_des2, eth2, norm2;

  // ===== Acceptance flags (fail-closed) =====
  Boolean accept_actuator_bounds;
  Boolean accept_no_collision;
  Boolean accept_finite;
  Boolean accept_tracking;
  Boolean accept_formation_recovered;
  Boolean accept_completed_route;
  Boolean accept_overall;

equation
  // Communication availability and shared disturbance during dropout.
  comm_ok    = time < t_drop_start or time > t_drop_end;
  drop_active = not comm_ok;
  dist_active = drop_active;
  F_dist_y   = if dist_active then F_dist else 0.0;

  // Reference route for primary robot (clamped cruise along +x).
  v_ref_eff = if x1 < x_target then v_ref else 0.0;
  x_ref = if v_ref*time < x_target then v_ref*time else x_target;
  y_ref = 0.0;

  // Body-frame longitudinal speeds.
  v1_body = vx1*cos(theta1) + vy1*sin(theta1);
  v2_body = vx2*cos(theta2) + vy2*sin(theta2);

  // Wheel angular velocities (proprioception: encoders).
  omega_wR1 = (v1_body + omega1*L_base/2)/r_wheel;
  omega_wL1 = (v1_body - omega1*L_base/2)/r_wheel;
  omega_wR2 = (v2_body + omega2*L_base/2)/r_wheel;
  omega_wL2 = (v2_body - omega2*L_base/2)/r_wheel;

  // Robot 1 plant dynamics.
  der(x1) = vx1;
  der(y1) = vy1;
  der(theta1) = omega1;
  der(vx1) = ((tau_R1_cmd + tau_L1_cmd)/r_wheel*cos(theta1) - c_lin*vx1)/m_robot;
  der(vy1) = ((tau_R1_cmd + tau_L1_cmd)/r_wheel*sin(theta1) - c_lin*vy1 + F_dist_y)/m_robot;
  der(omega1) = ((tau_R1_cmd - tau_L1_cmd)*L_base/(2*r_wheel) - c_rot*omega1)/J_body;

  // Robot 2 plant dynamics.
  der(x2) = vx2;
  der(y2) = vy2;
  der(theta2) = omega2;
  der(vx2) = ((tau_R2_cmd + tau_L2_cmd)/r_wheel*cos(theta2) - c_lin*vx2)/m_robot;
  der(vy2) = ((tau_R2_cmd + tau_L2_cmd)/r_wheel*sin(theta2) - c_lin*vy2 + F_dist_y)/m_robot;
  der(omega2) = ((tau_R2_cmd - tau_L2_cmd)*L_base/(2*r_wheel) - c_rot*omega2)/J_body;

  // Wheel encoder integrals.
  der(enc_R1) = omega_wR1;
  der(enc_L1) = omega_wL1;
  der(enc_R2) = omega_wR2;
  der(enc_L2) = omega_wL2;

  // IMU yaw-rate outputs.
  imu_w1 = omega1;
  imu_w2 = omega2;

  // Lidar: peer (robot 1) pose expressed in robot 2 body frame (exteroception).
  lidar_rel_x =  (x1 - x2)*cos(theta2) + (y1 - y2)*sin(theta2);
  lidar_rel_y = -(x1 - x2)*sin(theta2) + (y1 - y2)*cos(theta2);

  // Peer-state prediction at robot 2 from last received state + timestamp.
  x1_pred = x1_rx + vx1_rx*(time - t_rx1);
  y1_pred = y1_rx + vy1_rx*(time - t_rx1);
  theta1_pred = theta1_rx + omega1_rx*(time - t_rx1);
  // Formation setpoint: lateral (world-y) offset from peer.
  x1_used = x1_pred;
  y1_used = y1_pred + d_form;
  theta1_used = theta1_pred;

  // Inter-robot distance and bounded collision-avoidance repulsion.
  dist_robots = sqrt((x1 - x2)^2 + (y1 - y2)^2);
  Fy_repulse = if dist_robots < r_safe
               then 10.0*(r_safe - dist_robots)*((y2 - y1)/max(dist_robots, eps))
               else 0.0;

  // ===== Robot 1 (primary): world-frame PD with drag feedforward =====
  Fx_des1 = Kp_pos*(x_ref - x1) - Kd_pos*(vx1 - v_ref_eff) + c_lin*v_ref_eff;
  Fy_des1 = Kp_pos*(y_ref - y1) - Kd_pos*vy1;
  norm1 = sqrt(Fx_des1*Fx_des1 + Fy_des1*Fy_des1);
  theta_des1 = if norm1 > eps then Modelica.Math.atan2(Fy_des1, Fx_des1) else theta1;
  eth1 = Modelica.Math.wrapAngle(theta_des1 - theta1);
  F_fwd1 = Fx_des1*cos(theta1) + Fy_des1*sin(theta1);
  M_des1 = Kp_th*eth1 - Kd_th*omega1;

  // ===== Robot 2 (formation): world-frame PD on predicted peer state =====
  Fx_des2 = Kp_pos*(x1_used - x2) - Kd_pos*(vx2 - vx1_rx);
  Fy_des2 = Kp_pos*(y1_used - y2) - Kd_pos*vy2 + Fy_repulse;
  norm2 = sqrt(Fx_des2*Fx_des2 + Fy_des2*Fy_des2);
  theta_des2 = if norm2 > eps then Modelica.Math.atan2(Fy_des2, Fx_des2) else theta2;
  eth2 = Modelica.Math.wrapAngle(theta_des2 - theta2);
  F_fwd2 = Fx_des2*cos(theta2) + Fy_des2*sin(theta2);
  M_des2 = Kp_th*eth2 - Kd_th*omega2;

  // Synchronized error traces.
  e_track = sqrt((x_ref - x1)^2 + (y_ref - y1)^2);
  e_form  = sqrt((x2 - x1)^2 + (y2 - y1 - d_form)^2);

  // ===== 250 Hz discrete control + communication update (ZOH) =====
  when sample(0, dt_ctrl) then
    // Hold last-received peer state during dropout; refresh while available.
    if comm_ok then
      x1_rx = x1; y1_rx = y1; theta1_rx = theta1;
      vx1_rx = vx1; vy1_rx = vy1; omega1_rx = omega1;
      t_rx1 = time;
      x2_rx = x2; y2_rx = y2; theta2_rx = theta2;
      vx2_rx = vx2; vy2_rx = vy2; omega2_rx = omega2;
      t_rx2 = time;
    end if;
    // Four wheel-torque channels, magnitude bounded by tau_max.
    tau_R1_cmd = max(-tau_max, min(tau_max, 0.5*r_wheel*(F_fwd1 + 2.0*M_des1/L_base)));
    tau_L1_cmd = max(-tau_max, min(tau_max, 0.5*r_wheel*(F_fwd1 - 2.0*M_des1/L_base)));
    tau_R2_cmd = max(-tau_max, min(tau_max, 0.5*r_wheel*(F_fwd2 + 2.0*M_des2/L_base)));
    tau_L2_cmd = max(-tau_max, min(tau_max, 0.5*r_wheel*(F_fwd2 - 2.0*M_des2/L_base)));
  end when;

  // ===== Acceptance sample captures =====
  when time >= t_drop_end then
    if not pre(degraded_captured) then
      e_form_degraded_c = sqrt((x2 - x1)^2 + (y2 - y1 - d_form)^2);
      degraded_captured = true;
    end if;
  end when;

  when time >= t_check then
    if not pre(recovered_captured) then
      e_track_at_check_c = sqrt((x_ref - x1)^2 + (y_ref - y1)^2);
      e_form_recovered_c = sqrt((x2 - x1)^2 + (y2 - y1 - d_form)^2);
      recovered_captured = true;
    end if;
  end when;

  when time >= t_end - 0.05 then
    if not pre(route_captured) then
      completed_route_c = (x_target - x1) < 0.3;
      route_captured = true;
    end if;
  end when;

  // ===== Fail-closed acceptance =====
  accept_actuator_bounds =
      abs(tau_R1_cmd) <= tau_max + 1.0e-6 and abs(tau_L1_cmd) <= tau_max + 1.0e-6 and
      abs(tau_R2_cmd) <= tau_max + 1.0e-6 and abs(tau_L2_cmd) <= tau_max + 1.0e-6;

  accept_no_collision = dist_robots > 0.05;

  accept_finite = noEvent(
      abs(x1) < 1.0e6 and abs(y1) < 1.0e6 and abs(theta1) < 1.0e6 and
      abs(vx1) < 1.0e6 and abs(vy1) < 1.0e6 and abs(omega1) < 1.0e6 and
      abs(x2) < 1.0e6 and abs(y2) < 1.0e6 and abs(theta2) < 1.0e6 and
      abs(vx2) < 1.0e6 and abs(vy2) < 1.0e6 and abs(omega2) < 1.0e6 and
      abs(tau_R1_cmd) < 1.0e6 and abs(tau_L1_cmd) < 1.0e6 and
      abs(tau_R2_cmd) < 1.0e6 and abs(tau_L2_cmd) < 1.0e6 and
      abs(x1_rx) < 1.0e6 and abs(y1_rx) < 1.0e6 and abs(theta1_rx) < 1.0e6 and
      abs(vx1_rx) < 1.0e6 and abs(vy1_rx) < 1.0e6 and abs(omega1_rx) < 1.0e6);

  accept_tracking = recovered_captured and (e_track_at_check_c < e_track_limit);
  accept_formation_recovered = recovered_captured and (e_form_recovered_c < 0.30);
  accept_completed_route = completed_route_c;

  accept_overall =
      accept_actuator_bounds and accept_no_collision and accept_finite and
      accept_tracking and accept_formation_recovered and accept_completed_route;

  annotation(
    experiment(StopTime=16.0, Tolerance=1.0e-6, Interval=0.004),
    Documentation(info="GroundPairResilientE: verifiable two-robot differential-drive
      formation scenario with a 1.2 s communication dropout and shared disturbance
      in the middle third of a 16 s, 250 Hz run. Four wheel-torque channels bounded
      at 11 N.m. Acceptance (accept_overall) is fail-closed."));
end GroundPairResilientE;