model CoaxLiftSurveyD
  "Instrumented coaxial-rotor aerial robot with cable-slung payload, multi-sensor fusion, bounded waypoint tracking, and obstacle clearance";

  // Parameters
  parameter Real m_body = 4.4 "Body mass [kg]";
  parameter Real m_payload = 1.2 "Payload mass [kg]";
  parameter Real m_total = m_body + m_payload "Total mass [kg]";
  parameter Real L_cable = 0.70 "Cable length [m]";
  parameter Real g_acc = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real Tmax_rotor = 10.0 "Max thrust per rotor [N]";
  parameter Real Tmax_total = 8.0 * Tmax_rotor "Max total thrust [N]";
  parameter Real tau_att = 0.12 "Attitude time constant [s]";
  parameter Real max_roll = 0.40 "Max roll [rad]";
  parameter Real max_pitch = 0.40 "Max pitch [rad]";

  // Waypoints and deadlines
  parameter Real wp1_x = 0.0, wp1_y = 0.0, wp1_z = 1.5;
  parameter Real wp2_x = 4.0, wp2_y = 0.0, wp2_z = 2.5;
  parameter Real wp3_x = 4.0, wp3_y = 3.0, wp3_z = 2.5;
  parameter Real wp4_x = 1.0, wp4_y = 4.0, wp4_z = 2.0;
  parameter Real t_wp1 = 0.0, t_wp2 = 4.5, t_wp3 = 9.0, t_wp4 = 14.0;

  // Controller gains
  parameter Real Kp_x = 6.0, Kd_x = 6.0;
  parameter Real Kp_y = 6.0, Kd_y = 6.0;
  parameter Real Kp_z = 8.0, Kd_z = 8.0;

  // Crosswind
  parameter Real wind_force = 6.0 "Crosswind force [N]";
  parameter Real t_wind_start = 14.0 / 3.0 "Wind start [s]";
  parameter Real t_wind_end = 2.0 * 14.0 / 3.0 "Wind end [s]";

  // Obstacles
  parameter Real obs1_cx = 2.0, obs1_cy = -0.80, obs1_r = 0.30, obs1_h = 3.0;
  parameter Real obs2_cx = 5.0, obs2_cy = 1.50, obs2_r = 0.30, obs2_h = 3.0;
  parameter Real obs3_cx = 2.0, obs3_cy = 4.50, obs3_r = 0.30, obs3_h = 3.0;

  // Estimator gains
  parameter Real ke_pos = 3.0 "Position correction gain [1/s]";
  parameter Real ke_vel = 4.0 "Velocity correction gain [1/s2]";
  parameter Real eps_div = 1.0e-6 "Division protection epsilon";

  // Dynamic states
  Real x(start = 0.0, fixed = true);
  Real y(start = 0.0, fixed = true);
  Real z(start = 1.5, fixed = true);
  Real vx(start = 0.0, fixed = true);
  Real vy(start = 0.0, fixed = true);
  Real vz(start = 0.0, fixed = true);
  Real phi(start = 0.0, fixed = true);
  Real theta(start = 0.0, fixed = true);
  Real psi(start = 0.0, fixed = true);
  Real alpha(start = 0.0, fixed = true);
  Real omega_alpha(start = 0.0, fixed = true);
  Real beta(start = 0.0, fixed = true);
  Real omega_beta(start = 0.0, fixed = true);
  Real est_x(start = 0.0, fixed = true);
  Real est_y(start = 0.0, fixed = true);
  Real est_z(start = 1.5, fixed = true);
  Real est_vx(start = 0.0, fixed = true);
  Real est_vy(start = 0.0, fixed = true);
  Real est_vz(start = 0.0, fixed = true);

  // Algebraic: plant
  Real ax, ay, az;

  // Algebraic: trajectory
  Real seg_t0, seg_t1, seg_dt, seg_tau;
  Real sx, sy, sz, wx, wy, wz;
  Real mj, mj_v, mj_a;
  Real ref_x, ref_y, ref_z, ref_vx, ref_vy, ref_vz, ref_ax, ref_ay, ref_az;

  // Algebraic: wind
  Real wind_x;

  // Algebraic: sensors
  Real imu_ax, imu_ay, imu_az;
  Real gps_x, gps_y, gps_z;
  Real alt_z;
  Real cam_x, cam_y, cam_z, cam_ts;

  // Algebraic: controller
  Real ctrl_ex, ctrl_ey, ctrl_ez;
  Real ax_des, ay_des, az_des;
  Real theta_cmd_raw, phi_cmd_raw;
  Real phi_cmd, theta_cmd, psi_cmd;
  Real thrust_cmd_raw, T_total, T_safe;
  Real T1, T2, T3, T4, T5, T6, T7, T8;

  // Algebraic: metrics
  Real err_x, err_y, err_z, tracking_error;
  Real dist1, dist2, dist3, min_clearance;
  Real est_finite, all_finite;
  Real track_ok, no_coll1, no_coll2, no_coll3;

equation
  // ===== Trajectory: segment selection =====
  seg_t0 = noEvent(if time < t_wp2 then t_wp1 elseif time < t_wp3 then t_wp2 elseif time < t_wp4 then t_wp3 else t_wp4);
  seg_t1 = noEvent(if time < t_wp2 then t_wp2 elseif time < t_wp3 then t_wp3 elseif time < t_wp4 then t_wp4 else t_wp4);
  sx = noEvent(if time < t_wp2 then wp1_x elseif time < t_wp3 then wp2_x elseif time < t_wp4 then wp3_x else wp4_x);
  sy = noEvent(if time < t_wp2 then wp1_y elseif time < t_wp3 then wp2_y elseif time < t_wp4 then wp3_y else wp4_y);
  sz = noEvent(if time < t_wp2 then wp1_z elseif time < t_wp3 then wp2_z elseif time < t_wp4 then wp3_z else wp4_z);
  wx = noEvent(if time < t_wp2 then wp2_x elseif time < t_wp3 then wp3_x elseif time < t_wp4 then wp4_x else wp4_x);
  wy = noEvent(if time < t_wp2 then wp2_y elseif time < t_wp3 then wp3_y elseif time < t_wp4 then wp4_y else wp4_y);
  wz = noEvent(if time < t_wp2 then wp2_z elseif time < t_wp3 then wp3_z elseif time < t_wp4 then wp4_z else wp4_z);
  seg_dt = noEvent(if time < t_wp4 then seg_t1 - seg_t0 else 1.0);
  seg_tau = noEvent(if time < t_wp4 then (time - seg_t0) / seg_dt else 1.0);

  // ===== Minimum-jerk profile =====
  mj = 10.0 * seg_tau * seg_tau * seg_tau - 15.0 * seg_tau * seg_tau * seg_tau * seg_tau + 6.0 * seg_tau * seg_tau * seg_tau * seg_tau * seg_tau;
  mj_v = 30.0 * seg_tau * seg_tau - 60.0 * seg_tau * seg_tau * seg_tau + 30.0 * seg_tau * seg_tau * seg_tau * seg_tau;
  mj_a = 60.0 * seg_tau - 180.0 * seg_tau * seg_tau + 120.0 * seg_tau * seg_tau * seg_tau;

  ref_x = noEvent(if time < t_wp4 then sx + (wx - sx) * mj else wp4_x);
  ref_y = noEvent(if time < t_wp4 then sy + (wy - sy) * mj else wp4_y);
  ref_z = noEvent(if time < t_wp4 then sz + (wz - sz) * mj else wp4_z);
  ref_vx = noEvent(if time < t_wp4 then (wx - sx) * mj_v / seg_dt else 0.0);
  ref_vy = noEvent(if time < t_wp4 then (wy - sy) * mj_v / seg_dt else 0.0);
  ref_vz = noEvent(if time < t_wp4 then (wz - sz) * mj_v / seg_dt else 0.0);
  ref_ax = noEvent(if time < t_wp4 then (wx - sx) * mj_a / (seg_dt * seg_dt) else 0.0);
  ref_ay = noEvent(if time < t_wp4 then (wy - sy) * mj_a / (seg_dt * seg_dt) else 0.0);
  ref_az = noEvent(if time < t_wp4 then (wz - sz) * mj_a / (seg_dt * seg_dt) else 0.0);

  // ===== Wind disturbance =====
  wind_x = noEvent(if time >= t_wind_start and time <= t_wind_end then wind_force else 0.0);

  // ===== Sensor models =====
  imu_ax = ax + 0.02 * sin(6.283185307 * 5.0 * time);
  imu_ay = ay + 0.02 * sin(6.283185307 * 7.0 * time);
  imu_az = az + 0.02 * sin(6.283185307 * 3.0 * time);
  gps_x = x + 0.08 * sin(6.283185307 * 0.3 * time);
  gps_y = y + 0.08 * cos(6.283185307 * 0.4 * time);
  gps_z = z + 0.08 * sin(6.283185307 * 0.35 * time);
  alt_z = z + 0.02 * sin(6.283185307 * 1.0 * time);
  cam_x = x + 0.04 * sin(6.283185307 * 0.5 * time + 1.0);
  cam_y = y + 0.04 * cos(6.283185307 * 0.6 * time);
  cam_z = z + 0.04 * sin(6.283185307 * 0.55 * time);
  cam_ts = time;

  // ===== Estimator: complementary filter fusing IMU + GPS + altimeter + camera =====
  der(est_x) = est_vx + ke_pos * (gps_x - est_x) + 0.5 * ke_pos * (cam_x - est_x);
  der(est_vx) = imu_ax + ke_vel * (gps_x - est_x);
  der(est_y) = est_vy + ke_pos * (gps_y - est_y) + 0.5 * ke_pos * (cam_y - est_y);
  der(est_vy) = imu_ay + ke_vel * (gps_y - est_y);
  der(est_z) = est_vz + ke_pos * (alt_z - est_z) + 0.5 * ke_pos * (cam_z - est_z) + 0.3 * ke_pos * (gps_z - est_z);
  der(est_vz) = imu_az + ke_vel * (alt_z - est_z);

  // ===== Controller: bounded waypoint tracking with feedforward acceleration =====
  ctrl_ex = ref_x - est_x;
  ctrl_ey = ref_y - est_y;
  ctrl_ez = ref_z - est_z;
  ax_des = ref_ax + Kp_x * ctrl_ex + Kd_x * (ref_vx - est_vx);
  ay_des = ref_ay + Kp_y * ctrl_ey + Kd_y * (ref_vy - est_vy);
  az_des = ref_az + Kp_z * ctrl_ez + Kd_z * (ref_vz - est_vz);

  // Thrust command (bounded)
  thrust_cmd_raw = m_total * (az_des + g_acc) / (cos(theta) * cos(phi) + eps_div);
  T_total = noEvent(if thrust_cmd_raw < 0.0 then 0.0 elseif thrust_cmd_raw > Tmax_total then Tmax_total else thrust_cmd_raw);

  // Attitude commands (bounded, small-angle inversion with safe divisor)
  T_safe = noEvent(if T_total < 1.0 then 1.0 else T_total);
  theta_cmd_raw = m_total * ax_des / T_safe;
  phi_cmd_raw = -m_total * ay_des / T_safe;
  theta_cmd = noEvent(if theta_cmd_raw > max_pitch then max_pitch elseif theta_cmd_raw < -max_pitch then -max_pitch else theta_cmd_raw);
  phi_cmd = noEvent(if phi_cmd_raw > max_roll then max_roll elseif phi_cmd_raw < -max_roll then -max_roll else phi_cmd_raw);
  psi_cmd = 0.0;

  // Attitude dynamics (first-order tracking)
  der(phi) = (phi_cmd - phi) / tau_att;
  der(theta) = (theta_cmd - theta) / tau_att;
  der(psi) = (psi_cmd - psi) / tau_att;

  // ===== Rotor thrust distribution (8 channels, equal split) =====
  T1 = noEvent(if T_total / 8.0 < 0.0 then 0.0 elseif T_total / 8.0 > Tmax_rotor then Tmax_rotor else T_total / 8.0);
  T2 = T1;
  T3 = T1;
  T4 = T1;
  T5 = T1;
  T6 = T1;
  T7 = T1;
  T8 = T1;

  // ===== Plant dynamics =====
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  der(vx) = ax;
  der(vy) = ay;
  der(vz) = az;

  ax = (T_total * sin(theta) * cos(phi) + wind_x + m_payload * g_acc * sin(alpha)) / m_total;
  ay = (-T_total * sin(phi) * cos(theta) + m_payload * g_acc * sin(beta)) / m_total;
  az = (T_total * cos(theta) * cos(phi) - m_total * g_acc) / m_total;

  // Pendulum dynamics (cable-slung payload, planar decoupled)
  der(alpha) = omega_alpha;
  der(omega_alpha) = -(ax * cos(alpha) + g_acc * sin(alpha)) / L_cable;
  der(beta) = omega_beta;
  der(omega_beta) = -(ay * cos(beta) + g_acc * sin(beta)) / L_cable;

  // ===== Tracking error =====
  err_x = ref_x - x;
  err_y = ref_y - y;
  err_z = ref_z - z;
  tracking_error = sqrt(err_x * err_x + err_y * err_y + err_z * err_z + eps_div);

  // ===== Collision distances =====
  dist1 = sqrt((x - obs1_cx) * (x - obs1_cx) + (y - obs1_cy) * (y - obs1_cy) + eps_div) - obs1_r;
  dist2 = sqrt((x - obs2_cx) * (x - obs2_cx) + (y - obs2_cy) * (y - obs2_cy) + eps_div) - obs2_r;
  dist3 = sqrt((x - obs3_cx) * (x - obs3_cx) + (y - obs3_cy) * (y - obs3_cy) + eps_div) - obs3_r;
  min_clearance = noEvent(if dist1 < dist2 then (if dist1 < dist3 then dist1 else dist3) else (if dist2 < dist3 then dist2 else dist3));

  // ===== Finiteness indicators =====
  est_finite = noEvent(if (abs(est_x) < 1.0e4 and abs(est_y) < 1.0e4 and abs(est_z) < 1.0e4 and abs(est_vx) < 1.0e3 and abs(est_vy) < 1.0e3 and abs(est_vz) < 1.0e3) then 1.0 else 0.0);
  all_finite = noEvent(if (abs(x) < 1.0e4 and abs(y) < 1.0e4 and abs(z) < 1.0e4 and abs(vx) < 1.0e3 and abs(vy) < 1.0e3 and abs(vz) < 1.0e3 and abs(T_total) < 1.0e5 and abs(phi) < 10.0 and abs(theta) < 10.0 and abs(ax) < 1.0e3 and abs(ay) < 1.0e3 and abs(az) < 1.0e3 and est_finite > 0.5) then 1.0 else 0.0);

  // ===== Assert condition variables =====
  track_ok = noEvent(if time < 9.1 then 1.0 elseif tracking_error < 0.35 then 1.0 else 0.0);
  no_coll1 = noEvent(if (dist1 >= 0.0 or z >= obs1_h or z <= 0.0) then 1.0 else 0.0);
  no_coll2 = noEvent(if (dist2 >= 0.0 or z >= obs2_h or z <= 0.0) then 1.0 else 0.0);
  no_coll3 = noEvent(if (dist3 >= 0.0 or z >= obs3_h or z <= 0.0) then 1.0 else 0.0);

  // ===== Requirement assertions =====
  assert(T_total <= Tmax_total + 1.0e-6, "Thrust bound violated");
  assert(T1 <= Tmax_rotor + 1.0e-6, "Rotor thrust bound violated");
  assert(abs(phi) <= max_roll + 0.01, "Roll bound violated");
  assert(abs(theta) <= max_pitch + 0.01, "Pitch bound violated");
  assert(track_ok > 0.5, "Primary tracking error exceeds 0.35 m after 9.1 s");
  assert(est_finite > 0.5, "Estimator values not finite");
  assert(all_finite > 0.5, "Physical, control, or estimator values not finite");
  assert(no_coll1 > 0.5, "Collision with obstacle 1");
  assert(no_coll2 > 0.5, "Collision with obstacle 2");
  assert(no_coll3 > 0.5, "Collision with obstacle 3");

  annotation(
    Documentation(info = "CoaxLiftSurveyD: 4.4 kg cargo platform with four coaxial counter-rotating rotor pairs (8 channels, 10 N max each). Carries 1.2 kg payload on 0.70 m massless cable. Tracks waypoints [0,0,1.5], [4,0,2.5], [4,3,2.5], [1,4,2] m at deadlines 0, 4.5, 9.0, 14.0 s. Fuses IMU, GPS, altimeter, and camera into pose/velocity estimates via complementary filter. 6 N crosswind during middle third (4.67-9.33 s). Three fixed cylindrical obstacles outside reference polyline. Minimum-jerk reference with PD feedforward acceleration control. 200 Hz output for 14 s. Unknown facts (not modeled): rotor arm geometry, motor dynamics, exact sensor update rates, camera FOV, obstacle material properties."),
    experiment(StartTime = 0, StopTime = 14.0, Tolerance = 1.0e-6, Interval = 0.005)
  );
end CoaxLiftSurveyD;