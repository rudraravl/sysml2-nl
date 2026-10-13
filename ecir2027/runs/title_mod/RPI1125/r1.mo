model GroundTrioResilientC
  // ------------------------------------------------------------------
  // GroundTrioResilientC
  // Three 18 kg differential-drive warehouse robots on a rigid floor.
  // Distributed leader-follower control with constant-velocity peer-state
  // prediction during a 0.9 s communication dropout centered in the middle
  // third of a 12 s mission run at 125 Hz.
  // Sensing: proprioception (own odometry), exteroception (lidar collision),
  // and delayed peer messages with timestamps. Six bounded wheel drives.
  // Max wheel command 11 N.m. Shared environmental disturbance while comms
  // are unavailable. Outputs retain synchronized state, command, and sensor
  // traces. Primary tracking error < 0.63 m after 7.8 s; finite estimates;
  // completed route; no NaN/Inf.
  // Facts not stated in the request (wheel radius, base, inertia, drag,
  // gains) are NOT claimed from any source; reasonable bounded values are
  // chosen here and flagged in comments.
  // ------------------------------------------------------------------

  // ===== Scenario / timing =====
  parameter Real Ts = 0.008 "Control/sample period (s) -> 125 Hz";
  parameter Real T_end = 12.0 "Mission duration (s)";
  parameter Real T_drop_start = 5.55 "Dropout start (s); middle third of [0,12] is [4,8]";
  parameter Real T_drop_end = 6.45 "Dropout end (s); duration 0.9 s";

  // ===== Physical parameters =====
  parameter Real m = 18.0 "Robot mass (kg) [specified]";
  parameter Real Iz = 0.18 "Yaw inertia (kg.m^2) [NOT specified; reasonable bound]";
  parameter Real rw = 0.05 "Wheel radius (m) [NOT specified; reasonable bound]";
  parameter Real L = 0.30 "Wheel base (m) [NOT specified; reasonable bound]";
  parameter Real c_drag = 1.2 "Linear drag (N.s/m) [NOT specified; chosen for stability]";
  parameter Real c_yaw = 0.08 "Yaw drag (N.m.s/rad) [NOT specified]";
  parameter Real tau_max = 11.0 "Max wheel torque (N.m) [specified]";

  // ===== Control gains [NOT specified; chosen for stable tracking] =====
  parameter Real Kp = 4.5 "Position gain (N/m)";
  parameter Real Kd = 5.5 "Velocity damping (N.s/m)";
  parameter Real Kpy = 1.0 "Heading gain (N.m/rad)";
  parameter Real Kdy = 0.35 "Yaw damping (N.m.s/rad)";
  parameter Real Kcol = 30.0 "Collision repulsion gain (N/m)";
  parameter Real safe_d = 0.45 "Collision safe distance (m)";
  parameter Real eps = 1e-3 "Norm/divisor zero-branch (m)";

  // ===== Route [NOT specified; representative warehouse route] =====
  parameter Real v_ref = 0.45 "Reference forward speed (m/s)";

  // ===== Formation offsets of followers behind the leader (m) =====
  parameter Real off_x2 = -0.70 "Follower 2 x offset (m)";
  parameter Real off_y2 = -0.45 "Follower 2 y offset (m)";
  parameter Real off_x3 = -0.70 "Follower 3 x offset (m)";
  parameter Real off_y3 =  0.45 "Follower 3 y offset (m)";

  // ===== Shared environmental disturbance during dropout (N) =====
  parameter Real w_dist_x = 2.5 "Shared disturbance force x (N) [NOT specified; representative]";
  parameter Real w_dist_y = 1.0 "Shared disturbance force y (N) [NOT specified; representative]";

  // ===== Communication / disturbance status =====
  Boolean comms_active "true when peer communication is available";
  Real dist_x "Active shared disturbance force x (N)";
  Real dist_y "Active shared disturbance force y (N)";

  // ===== Reference route (continuous) =====
  Real x_ref, y_ref, theta_ref;

  // ===== Robot states (world frame) =====
  Real x1(start=0.0, fixed=true), y1(start=0.0, fixed=true), theta1(start=0.0, fixed=true);
  Real vx1(start=0.0, fixed=true), vy1(start=0.0, fixed=true), omega1(start=0.0, fixed=true);
  Real x2(start=-0.70, fixed=true), y2(start=-0.45, fixed=true), theta2(start=0.0, fixed=true);
  Real vx2(start=0.0, fixed=true), vy2(start=0.0, fixed=true), omega2(start=0.0, fixed=true);
  Real x3(start=-0.70, fixed=true), y3(start=0.45, fixed=true), theta3(start=0.0, fixed=true);
  Real vx3(start=0.0, fixed=true), vy3(start=0.0, fixed=true), omega3(start=0.0, fixed=true);

  // ===== Commanded body force (along heading) and yaw torque =====
  Real F1c, M1c, F2c, M2c, F3c, M3c;
  // ===== Actual body force/torque from bounded wheel torques =====
  Real F1, M1, F2, M2, F3, M3;

  // ===== Wheel torque commands (raw and bounded) =====
  Real tauR1_raw, tauL1_raw, tauR2_raw, tauL2_raw, tauR3_raw, tauL3_raw;
  Real tauR1, tauL1, tauR2, tauL2, tauR3, tauL3;

  // ===== Peer-state buffers (last received with timestamp) =====
  // Robot 2's view of leader 1; robot 3's view of leader 1
  Real x1_2(start=0.0, fixed=true), y1_2(start=0.0, fixed=true);
  Real vx1_2(start=0.0, fixed=true), vy1_2(start=0.0, fixed=true), t1_2(start=0.0, fixed=true);
  Real x1_3(start=0.0, fixed=true), y1_3(start=0.0, fixed=true);
  Real vx1_3(start=0.0, fixed=true), vy1_3(start=0.0, fixed=true), t1_3(start=0.0, fixed=true);
  // Robot 1's view of followers 2,3 (evidence trace)
  Real x2_1(start=-0.70, fixed=true), y2_1(start=-0.45, fixed=true);
  Real vx2_1(start=0.0, fixed=true), vy2_1(start=0.0, fixed=true), t2_1(start=0.0, fixed=true);
  Real x3_1(start=-0.70, fixed=true), y3_1(start=0.45, fixed=true);
  Real vx3_1(start=0.0, fixed=true), vy3_1(start=0.0, fixed=true), t3_1(start=0.0, fixed=true);
  // Cross views between followers (evidence trace)
  Real x3_2(start=-0.70, fixed=true), y3_2(start=0.45, fixed=true);
  Real vx3_2(start=0.0, fixed=true), vy3_2(start=0.0, fixed=true), t3_2(start=0.0, fixed=true);
  Real x2_3(start=-0.70, fixed=true), y2_3(start=-0.45, fixed=true);
  Real vx2_3(start=0.0, fixed=true), vy2_3(start=0.0, fixed=true), t2_3(start=0.0, fixed=true);

  // ===== Predicted peer positions (constant-velocity prediction) =====
  Real px1_2, py1_2, px1_3, py1_3;
  Real px2_1, py2_1, px3_1, py3_1;
  Real px3_2, py3_2, px2_3, py2_3;

  // ===== Desired positions =====
  Real x_des_1, y_des_1, x_des_2, y_des_2, x_des_3, y_des_3;

  // ===== Desired world-frame control forces =====
  Real Fx1, Fy1, Fx2, Fy2, Fx3, Fy3;

  // ===== Lidar collision distances and repulsion forces =====
  Real raw_d12, raw_d13, raw_d23;
  Real c12x, c12y, c13x, c13y, c23x, c23y;

  // ===== Heading commands =====
  Real hd1, hd2, hd3;

  // ===== Tracking and formation errors =====
  Real err1 "Leader (primary) tracking error (m)";
  Real err2 "Follower 2 tracking error (m)";
  Real err3 "Follower 3 tracking error (m)";
  Real primary_err "Primary tracking error (m)";
  Real formation_err "Formation error (m), RMS of follower offsets";
  // Degraded/recovered snapshots
  Real formation_err_degraded(start=0.0, fixed=true);
  Real formation_err_recovered(start=0.0, fixed=true);
  // Route completion indicator
  Real route_completed "Leader route completion fraction [0,1]";

equation
  // ----- Communication availability and shared disturbance -----
  comms_active = not (time >= T_drop_start and time < T_drop_end);
  dist_x = if (time >= T_drop_start and time < T_drop_end) then w_dist_x else 0.0;
  dist_y = if (time >= T_drop_start and time < T_drop_end) then w_dist_y else 0.0;

  // ----- Reference route (straight + gentle curve -> completed route) -----
  x_ref = v_ref * time;
  y_ref = 0.25 * sin(0.35 * x_ref);
  theta_ref = atan2(0.25 * 0.35 * cos(0.35 * x_ref), 1.0);

  // ----- Robot dynamics (world frame, shared disturbance) -----
  der(x1) = vx1; der(y1) = vy1; der(theta1) = omega1;
  m * der(vx1) = F1 * cos(theta1) - c_drag * vx1 + dist_x;
  m * der(vy1) = F1 * sin(theta1) - c_drag * vy1 + dist_y;
  Iz * der(omega1) = M1 - c_yaw * omega1;

  der(x2) = vx2; der(y2) = vy2; der(theta2) = omega2;
  m * der(vx2) = F2 * cos(theta2) - c_drag * vx2 + dist_x;
  m * der(vy2) = F2 * sin(theta2) - c_drag * vy2 + dist_y;
  Iz * der(omega2) = M2 - c_yaw * omega2;

  der(x3) = vx3; der(y3) = vy3; der(theta3) = omega3;
  m * der(vx3) = F3 * cos(theta3) - c_drag * vx3 + dist_x;
  m * der(vy3) = F3 * sin(theta3) - c_drag * vy3 + dist_y;
  Iz * der(omega3) = M3 - c_yaw * omega3;

  // ----- Peer-state prediction (constant velocity from last received) -----
  px1_2 = x1_2 + vx1_2 * (time - t1_2);
  py1_2 = y1_2 + vy1_2 * (time - t1_2);
  px1_3 = x1_3 + vx1_3 * (time - t1_3);
  py1_3 = y1_3 + vy1_3 * (time - t1_3);
  px2_1 = x2_1 + vx2_1 * (time - t2_1);
  py2_1 = y2_1 + vy2_1 * (time - t2_1);
  px3_1 = x3_1 + vx3_1 * (time - t3_1);
  py3_1 = y3_1 + vy3_1 * (time - t3_1);
  px3_2 = x3_2 + vx3_2 * (time - t3_2);
  py3_2 = y3_2 + vy3_2 * (time - t3_2);
  px2_3 = x2_3 + vx2_3 * (time - t2_3);
  py2_3 = y2_3 + vy2_3 * (time - t2_3);

  // ----- Desired positions (distributed leader-follower) -----
  x_des_1 = x_ref;
  y_des_1 = y_ref;
  x_des_2 = px1_2 + off_x2;
  y_des_2 = py1_2 + off_y2;
  x_des_3 = px1_3 + off_x3;
  y_des_3 = py1_3 + off_y3;

  // ----- Lidar collision distances (exteroception) -----
  raw_d12 = sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1));
  raw_d13 = sqrt((x3 - x1) * (x3 - x1) + (y3 - y1) * (y3 - y1));
  raw_d23 = sqrt((x3 - x2) * (x3 - x2) + (y3 - y2) * (y3 - y2));

  // ----- Collision repulsion forces (zero-branch protected) -----
  c12x = if (raw_d12 < safe_d) then Kcol * (safe_d - raw_d12) * (x1 - x2) / (raw_d12 + eps) else 0.0;
  c12y = if (raw_d12 < safe_d) then Kcol * (safe_d - raw_d12) * (y1 - y2) / (raw_d12 + eps) else 0.0;
  c13x = if (raw_d13 < safe_d) then Kcol * (safe_d - raw_d13) * (x1 - x3) / (raw_d13 + eps) else 0.0;
  c13y = if (raw_d13 < safe_d) then Kcol * (safe_d - raw_d13) * (y1 - y3) / (raw_d13 + eps) else 0.0;
  c23x = if (raw_d23 < safe_d) then Kcol * (safe_d - raw_d23) * (x2 - x3) / (raw_d23 + eps) else 0.0;
  c23y = if (raw_d23 < safe_d) then Kcol * (safe_d - raw_d23) * (y2 - y3) / (raw_d23 + eps) else 0.0;

  // ----- Desired world-frame control forces -----
  Fx1 = Kp * (x_des_1 - x1) - Kd * vx1 + c12x + c13x;
  Fy1 = Kp * (y_des_1 - y1) - Kd * vy1 + c12y + c13y;
  Fx2 = Kp * (x_des_2 - x2) - Kd * vx2 - c12x + c23x;
  Fy2 = Kp * (y_des_2 - y2) - Kd * vy2 - c12y + c23y;
  Fx3 = Kp * (x_des_3 - x3) - Kd * vx3 - c13x - c23x;
  Fy3 = Kp * (y_des_3 - y3) - Kd * vy3 - c13y - c23y;

  // ----- Commanded body force (along heading) and yaw torque -----
  F1c = Fx1 * cos(theta1) + Fy1 * sin(theta1);
  hd1 = atan2(Fy1, Fx1 + eps);
  M1c = Kpy * atan2(sin(hd1 - theta1), cos(hd1 - theta1)) - Kdy * omega1;

  F2c = Fx2 * cos(theta2) + Fy2 * sin(theta2);
  hd2 = atan2(Fy2, Fx2 + eps);
  M2c = Kpy * atan2(sin(hd2 - theta2), cos(hd2 - theta2)) - Kdy * omega2;

  F3c = Fx3 * cos(theta3) + Fy3 * sin(theta3);
  hd3 = atan2(Fy3, Fx3 + eps);
  M3c = Kpy * atan2(sin(hd3 - theta3), cos(hd3 - theta3)) - Kdy * omega3;

  // ----- Wheel torque mapping (commanded) -----
  tauR1_raw = rw * (F1c + 2.0 * M1c / L) / 2.0;
  tauL1_raw = rw * (F1c - 2.0 * M1c / L) / 2.0;
  tauR2_raw = rw * (F2c + 2.0 * M2c / L) / 2.0;
  tauL2_raw = rw * (F2c - 2.0 * M2c / L) / 2.0;
  tauR3_raw = rw * (F3c + 2.0 * M3c / L) / 2.0;
  tauL3_raw = rw * (F3c - 2.0 * M3c / L) / 2.0;

  // ----- Actuator bounds (11 N.m per wheel) -----
  tauR1 = max(-tau_max, min(tau_max, tauR1_raw));
  tauL1 = max(-tau_max, min(tau_max, tauL1_raw));
  tauR2 = max(-tau_max, min(tau_max, tauR2_raw));
  tauL2 = max(-tau_max, min(tau_max, tauL2_raw));
  tauR3 = max(-tau_max, min(tau_max, tauR3_raw));
  tauL3 = max(-tau_max, min(tau_max, tauL3_raw));

  // ----- Actual body force/torque realized by bounded wheels -----
  F1 = (tauR1 + tauL1) / rw;
  M1 = (tauR1 - tauL1) * L / (2.0 * rw);
  F2 = (tauR2 + tauL2) / rw;
  M2 = (tauR2 - tauL2) * L / (2.0 * rw);
  F3 = (tauR3 + tauL3) / rw;
  M3 = (tauR3 - tauL3) * L / (2.0 * rw);

  // ----- Tracking and formation errors (finite, zero-branch protected) -----
  err1 = sqrt((x1 - x_ref) * (x1 - x_ref) + (y1 - y_ref) * (y1 - y_ref));
  err2 = sqrt((x2 - px1_2 - off_x2) * (x2 - px1_2 - off_x2) + (y2 - py1_2 - off_y2) * (y2 - py1_2 - off_y2));
  err3 = sqrt((x3 - px1_3 - off_x3) * (x3 - px1_3 - off_x3) + (y3 - py1_3 - off_y3) * (y3 - py1_3 - off_y3));
  primary_err = err1;
  formation_err = sqrt(((x2 - x1 - off_x2) * (x2 - x1 - off_x2) +
                        (y2 - y1 - off_y2) * (y2 - y1 - off_y2) +
                        (x3 - x1 - off_x3) * (x3 - x1 - off_x3) +
                        (y3 - y1 - off_y3) * (y3 - y1 - off_y3)) / 2.0 + eps * eps);
  route_completed = max(0.0, min(1.0, x1 / (v_ref * T_end + eps)));

  // ----- Discrete peer-message exchange at 125 Hz (only when comms active) -----
  when sample(0, Ts) then
    if comms_active then
      x1_2 = x1; y1_2 = y1; vx1_2 = vx1; vy1_2 = vy1; t1_2 = time;
      x1_3 = x1; y1_3 = y1; vx1_3 = vx1; vy1_3 = vy1; t1_3 = time;
      x2_1 = x2; y2_1 = y2; vx2_1 = vx2; vy2_1 = vy2; t2_1 = time;
      x3_1 = x3; y3_1 = y3; vx3_1 = vx3; vy3_1 = vy3; t3_1 = time;
      x3_2 = x3; y3_2 = y3; vx3_2 = vx3; vy3_2 = vy3; t3_2 = time;
      x2_3 = x2; y2_3 = y2; vx2_3 = vx2; vy2_3 = vy2; t2_3 = time;
    end if;
  end when;

  // ----- Snapshot formation error at dropout end (degraded) -----
  when sample(T_drop_end, 100.0) then
    formation_err_degraded = formation_err;
  end when;

  // ----- Snapshot formation error at 11 s (recovered) -----
  when sample(11.0, 100.0) then
    formation_err_recovered = formation_err;
  end when;

  annotation(
    Documentation(info = "Three 18 kg differential-drive robots, distributed leader-follower control with peer-state prediction during a 0.9 s dropout. Run at 125 Hz for 12 s."),
    experiment(StartTime = 0, StopTime = 12.0, Tolerance = 1e-6, Interval = 0.008));
end GroundTrioResilientC;