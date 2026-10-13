model AirTrioResilientA
  "Three-quadrotor resilient formation with 0.5 s communication dropout"

  // ===== Physical Parameters =====
  parameter Real m_robot = 1.8 "Quadrotor mass [kg]";
  parameter Real g_accel = 9.81 "Gravity [m/s2]";
  parameter Real T_max_rotor = 8.64 "Max per-rotor thrust command [N]";
  parameter Real T_min_rotor = 0.0 "Min per-rotor thrust [N]";

  // ===== Scenario Parameters =====
  parameter Real t_drop_start = 3.5 "Communication dropout start [s]";
  parameter Real t_drop_end = 4.0 "Communication dropout end [s]";
  parameter Real z_nominal = 5.0 "Nominal flight altitude [m]";
  parameter Real route_length = 6.0 "Route x-displacement [m]";
  parameter Real route_time = 6.0 "Route completion horizon [s]";
  parameter Real disturbance_force = 2.5 "Shared disturbance magnitude during dropout [N]";
  parameter Real disturbance_dir_x = 0.7071 "Disturbance direction x";
  parameter Real disturbance_dir_y = 0.7071 "Disturbance direction y";

  // ===== Formation Parameters =====
  parameter Real formation_dx_2 = 2.0 "Robot 2 x-offset from leader [m]";
  parameter Real formation_dx_3 = 1.0 "Robot 3 x-offset from leader [m]";
  parameter Real formation_dy_3 = 1.5 "Robot 3 y-offset from leader [m]";
  parameter Real collision_dist = 0.8 "Collision avoidance trigger distance [m]";
  parameter Real collision_gain = 15.0 "Repulsion gain [N/m]";

  // ===== Control Gains =====
  parameter Real kp_pos = 6.0 "Position proportional gain [1/s2]";
  parameter Real kd_pos = 3.5 "Position damping gain [1/s]";

  // ===== Robot State Variables =====
  Real x[3](start={0.0, 2.0, 1.0}) "x positions [m]";
  Real y[3](start={0.0, 0.0, 1.5}) "y positions [m]";
  Real z[3](start={5.0, 5.0, 5.0}) "z positions [m]";
  Real vx[3](start={0.0, 0.0, 0.0}) "x velocities [m/s]";
  Real vy[3](start={0.0, 0.0, 0.0}) "y velocities [m/s]";
  Real vz[3](start={0.0, 0.0, 0.0}) "z velocities [m/s]";

  // ===== Communication and Prediction =====
  Boolean comm_active "True when peer communication is available";
  Real frozen_x[3](start={0.0, 2.0, 1.0}) "Last-received x [m]";
  Real frozen_y[3](start={0.0, 0.0, 1.5}) "Last-received y [m]";
  Real frozen_z[3](start={5.0, 5.0, 5.0}) "Last-received z [m]";
  Real frozen_vx[3](start={0.0, 0.0, 0.0}) "Last-received vx [m/s]";
  Real frozen_vy[3](start={0.0, 0.0, 0.0}) "Last-received vy [m/s]";
  Real frozen_vz[3](start={0.0, 0.0, 0.0}) "Last-received vz [m/s]";
  Real frozen_t(start=0.0) "Timestamp of last received peer state [s]";

  Real leader_pred_x "Predicted leader x [m]";
  Real leader_pred_y "Predicted leader y [m]";
  Real leader_pred_z "Predicted leader z [m]";
  Real leader_pred_vx "Predicted leader vx [m/s]";
  Real leader_pred_vy "Predicted leader vy [m/s]";
  Real leader_pred_vz "Predicted leader vz [m/s]";

  // ===== 12 Independent Rotor Thrusts =====
  Real T1_1, T1_2, T1_3, T1_4 "Robot 1 rotor thrusts [N]";
  Real T2_1, T2_2, T2_3, T2_4 "Robot 2 rotor thrusts [N]";
  Real T3_1, T3_2, T3_3, T3_4 "Robot 3 rotor thrusts [N]";

  // ===== Force Allocation =====
  Real Fx_cmd[3] "Commanded x-force [N]";
  Real Fy_cmd[3] "Commanded y-force [N]";
  Real Fz_cmd[3] "Commanded z-force including gravity [N]";
  Real T_needed[3] "Total thrust magnitude needed [N]";
  Real T_avail[3] "Total thrust available after saturation [N]";
  Real thrust_scale[3] "Saturation scale factor [0-1]";
  Real Fx_act[3] "Actual x-force [N]";
  Real Fy_act[3] "Actual y-force [N]";
  Real Fz_act[3] "Actual z-force excluding gravity [N]";

  // ===== Collision Avoidance =====
  Real dist12 "Distance robot 1-2 [m]";
  Real dist13 "Distance robot 1-3 [m]";
  Real dist23 "Distance robot 2-3 [m]";
  Real rep12_x "Repulsive x-force 1-2 [N]";
  Real rep12_y "Repulsive y-force 1-2 [N]";
  Real rep13_x "Repulsive x-force 1-3 [N]";
  Real rep13_y "Repulsive y-force 1-3 [N]";
  Real rep23_x "Repulsive x-force 2-3 [N]";
  Real rep23_y "Repulsive y-force 2-3 [N]";

  // ===== Disturbance =====
  Real dist_x "Shared disturbance x-force [N]";
  Real dist_y "Shared disturbance y-force [N]";

  // ===== Route =====
  Real route_progress "Route completion fraction [0-1]";
  Real route_x "Desired route x [m]";
  Real route_y "Desired route y [m]";
  Real route_z "Desired route z [m]";
  Real route_vx "Desired route vx [m/s]";
  Real route_vy "Desired route vy [m/s]";
  Real route_vz "Desired route vz [m/s]";

  // ===== Sensor Traces =====
  Real gps_x[3] "GPS x measurement [m]";
  Real gps_y[3] "GPS y measurement [m]";
  Real gps_z[3] "GPS z measurement [m]";
  Real imu_ax[3] "IMU x-accelerometer [m/s2]";
  Real imu_ay[3] "IMU y-accelerometer [m/s2]";
  Real imu_az[3] "IMU z-accelerometer [m/s2]";
  Real range12 "Peer-relative range 1-2 [m]";
  Real range13 "Peer-relative range 1-3 [m]";
  Real range23 "Peer-relative range 2-3 [m]";

  // ===== Performance Metrics =====
  Real primary_tracking_error "Leader route tracking error [m]";
  Real formation_error_2 "Robot 2 formation error [m]";
  Real formation_error_3 "Robot 3 formation error [m]";
  Real formation_error_degraded "Formation error during dropout [m]";
  Real formation_error_recovered "Formation error after recovery [m]";

equation
  // ===== Communication State =====
  comm_active = not (time >= t_drop_start and time < t_drop_end);

  // Freeze last-received peer state at dropout onset with timestamp
  when {initial(), time >= t_drop_start} then
    frozen_x[1] = x[1]; frozen_x[2] = x[2]; frozen_x[3] = x[3];
    frozen_y[1] = y[1]; frozen_y[2] = y[2]; frozen_y[3] = y[3];
    frozen_z[1] = z[1]; frozen_z[2] = z[2]; frozen_z[3] = z[3];
    frozen_vx[1] = vx[1]; frozen_vx[2] = vx[2]; frozen_vx[3] = vx[3];
    frozen_vy[1] = vy[1]; frozen_vy[2] = vy[2]; frozen_vy[3] = vy[3];
    frozen_vz[1] = vz[1]; frozen_vz[2] = vz[2]; frozen_vz[3] = vz[3];
    frozen_t = time;
  end when;

  // Predicted leader state: actual when comm active, dead-reckoning during dropout
  leader_pred_x = if comm_active then x[1] else frozen_x[1] + frozen_vx[1] * (time - frozen_t);
  leader_pred_y = if comm_active then y[1] else frozen_y[1] + frozen_vy[1] * (time - frozen_t);
  leader_pred_z = if comm_active then z[1] else frozen_z[1] + frozen_vz[1] * (time - frozen_t);
  leader_pred_vx = if comm_active then vx[1] else frozen_vx[1];
  leader_pred_vy = if comm_active then vy[1] else frozen_vy[1];
  leader_pred_vz = if comm_active then vz[1] else frozen_vz[1];

  // ===== Route Trajectory (linear, completed by route_time) =====
  route_progress = if time <= route_time then time / route_time else 1.0;
  route_x = route_length * route_progress;
  route_y = 0.0;
  route_z = z_nominal;
  route_vx = if time <= route_time then route_length / route_time else 0.0;
  route_vy = 0.0;
  route_vz = 0.0;

  // ===== Distributed PD Control Commands =====
  // Robot 1 (leader): tracks route directly
  Fx_cmd[1] = m_robot * (kp_pos * (route_x - x[1]) + kd_pos * (route_vx - vx[1]));
  Fy_cmd[1] = m_robot * (kp_pos * (route_y - y[1]) + kd_pos * (route_vy - vy[1]));
  Fz_cmd[1] = m_robot * (kp_pos * (route_z - z[1]) + kd_pos * (route_vz - vz[1]) + g_accel);

  // Robot 2: maintains formation offset relative to predicted leader
  Fx_cmd[2] = m_robot * (kp_pos * (leader_pred_x + formation_dx_2 - x[2]) + kd_pos * (leader_pred_vx - vx[2]));
  Fy_cmd[2] = m_robot * (kp_pos * (leader_pred_y - y[2]) + kd_pos * (leader_pred_vy - vy[2]));
  Fz_cmd[2] = m_robot * (kp_pos * (leader_pred_z - z[2]) + kd_pos * (leader_pred_vz - vz[2]) + g_accel);

  // Robot 3: maintains formation offset relative to predicted leader
  Fx_cmd[3] = m_robot * (kp_pos * (leader_pred_x + formation_dx_3 - x[3]) + kd_pos * (leader_pred_vx - vx[3]));
  Fy_cmd[3] = m_robot * (kp_pos * (leader_pred_y + formation_dy_3 - y[3]) + kd_pos * (leader_pred_vy - vy[3]));
  Fz_cmd[3] = m_robot * (kp_pos * (leader_pred_z - z[3]) + kd_pos * (leader_pred_vz - vz[3]) + g_accel);

  // ===== Shared Environmental Disturbance (active only during dropout) =====
  dist_x = if (time >= t_drop_start and time < t_drop_end) then disturbance_force * disturbance_dir_x else 0.0;
  dist_y = if (time >= t_drop_start and time < t_drop_end) then disturbance_force * disturbance_dir_y else 0.0;

  // ===== Inter-robot Distances =====
  dist12 = sqrt((x[1] - x[2])^2 + (y[1] - y[2])^2 + (z[1] - z[2])^2 + 1.0e-6);
  dist13 = sqrt((x[1] - x[3])^2 + (y[1] - y[3])^2 + (z[1] - z[3])^2 + 1.0e-6);
  dist23 = sqrt((x[2] - x[3])^2 + (y[2] - y[3])^2 + (z[2] - z[3])^2 + 1.0e-6);

  // ===== Collision Avoidance (repulsive forces in horizontal plane) =====
  rep12_x = if dist12 < collision_dist then collision_gain * (collision_dist - dist12) * (x[1] - x[2]) / dist12 else 0.0;
  rep12_y = if dist12 < collision_dist then collision_gain * (collision_dist - dist12) * (y[1] - y[2]) / dist12 else 0.0;
  rep13_x = if dist13 < collision_dist then collision_gain * (collision_dist - dist13) * (x[1] - x[3]) / dist13 else 0.0;
  rep13_y = if dist13 < collision_dist then collision_gain * (collision_dist - dist13) * (y[1] - y[3]) / dist13 else 0.0;
  rep23_x = if dist23 < collision_dist then collision_gain * (collision_dist - dist23) * (x[2] - x[3]) / dist23 else 0.0;
  rep23_y = if dist23 < collision_dist then collision_gain * (collision_dist - dist23) * (y[2] - y[3]) / dist23 else 0.0;

  // ===== Thrust Allocation with Actuator Bounds =====
  T_needed[1] = sqrt(Fx_cmd[1]^2 + Fy_cmd[1]^2 + Fz_cmd[1]^2);
  T_needed[2] = sqrt(Fx_cmd[2]^2 + Fy_cmd[2]^2 + Fz_cmd[2]^2);
  T_needed[3] = sqrt(Fx_cmd[3]^2 + Fy_cmd[3]^2 + Fz_cmd[3]^2);

  T_avail[1] = min(T_needed[1], 4.0 * T_max_rotor);
  T_avail[2] = min(T_needed[2], 4.0 * T_max_rotor);
  T_avail[3] = min(T_needed[3], 4.0 * T_max_rotor);

  thrust_scale[1] = if T_needed[1] > 1.0e-6 then T_avail[1] / T_needed[1] else 0.0;
  thrust_scale[2] = if T_needed[2] > 1.0e-6 then T_avail[2] / T_needed[2] else 0.0;
  thrust_scale[3] = if T_needed[3] > 1.0e-6 then T_avail[3] / T_needed[3] else 0.0;

  Fx_act[1] = Fx_cmd[1] * thrust_scale[1];
  Fx_act[2] = Fx_cmd[2] * thrust_scale[2];
  Fx_act[3] = Fx_cmd[3] * thrust_scale[3];
  Fy_act[1] = Fy_cmd[1] * thrust_scale[1];
  Fy_act[2] = Fy_cmd[2] * thrust_scale[2];
  Fy_act[3] = Fy_cmd[3] * thrust_scale[3];
  Fz_act[1] = Fz_cmd[1] * thrust_scale[1] - m_robot * g_accel;
  Fz_act[2] = Fz_cmd[2] * thrust_scale[2] - m_robot * g_accel;
  Fz_act[3] = Fz_cmd[3] * thrust_scale[3] - m_robot * g_accel;

  // 12 independent rotor thrusts (equal allocation per robot, individually bounded)
  T1_1 = max(T_min_rotor, min(T_max_rotor, T_avail[1] / 4.0));
  T1_2 = T1_1;
  T1_3 = T1_1;
  T1_4 = T1_1;
  T2_1 = max(T_min_rotor, min(T_max_rotor, T_avail[2] / 4.0));
  T2_2 = T2_1;
  T2_3 = T2_1;
  T2_4 = T2_1;
  T3_1 = max(T_min_rotor, min(T_max_rotor, T_avail[3] / 4.0));
  T3_2 = T3_1;
  T3_3 = T3_1;
  T3_4 = T3_1;

  // ===== Newtonian Dynamics =====
  // Robot 1
  der(x[1]) = vx[1];
  der(y[1]) = vy[1];
  der(z[1]) = vz[1];
  der(vx[1]) = (Fx_act[1] + rep12_x + rep13_x + dist_x) / m_robot;
  der(vy[1]) = (Fy_act[1] + rep12_y + rep13_y + dist_y) / m_robot;
  der(vz[1]) = Fz_act[1] / m_robot;

  // Robot 2
  der(x[2]) = vx[2];
  der(y[2]) = vy[2];
  der(z[2]) = vz[2];
  der(vx[2]) = (Fx_act[2] - rep12_x + rep23_x + dist_x) / m_robot;
  der(vy[2]) = (Fy_act[2] - rep12_y + rep23_y + dist_y) / m_robot;
  der(vz[2]) = Fz_act[2] / m_robot;

  // Robot 3
  der(x[3]) = vx[3];
  der(y[3]) = vy[3];
  der(z[3]) = vz[3];
  der(vx[3]) = (Fx_act[3] - rep13_x - rep23_x + dist_x) / m_robot;
  der(vy[3]) = (Fy_act[3] - rep13_y - rep23_y + dist_y) / m_robot;
  der(vz[3]) = Fz_act[3] / m_robot;

  // ===== Sensor Traces =====
  // GPS proprioception/exteroception (position)
  gps_x[1] = x[1]; gps_x[2] = x[2]; gps_x[3] = x[3];
  gps_y[1] = y[1]; gps_y[2] = y[2]; gps_y[3] = y[3];
  gps_z[1] = z[1]; gps_z[2] = z[2]; gps_z[3] = z[3];

  // IMU proprioception (acceleration)
  imu_ax[1] = (Fx_act[1] + rep12_x + rep13_x + dist_x) / m_robot;
  imu_ax[2] = (Fx_act[2] - rep12_x + rep23_x + dist_x) / m_robot;
  imu_ax[3] = (Fx_act[3] - rep13_x - rep23_x + dist_x) / m_robot;
  imu_ay[1] = (Fy_act[1] + rep12_y + rep13_y + dist_y) / m_robot;
  imu_ay[2] = (Fy_act[2] - rep12_y + rep23_y + dist_y) / m_robot;
  imu_ay[3] = (Fy_act[3] - rep13_y - rep23_y + dist_y) / m_robot;
  imu_az[1] = Fz_act[1] / m_robot;
  imu_az[2] = Fz_act[2] / m_robot;
  imu_az[3] = Fz_act[3] / m_robot;

  // Peer-relative range sensing
  range12 = dist12;
  range13 = dist13;
  range23 = dist23;

  // ===== Performance Metrics =====
  primary_tracking_error = sqrt((route_x - x[1])^2 + (route_y - y[1])^2 + (route_z - z[1])^2 + 1.0e-6);
  formation_error_2 = sqrt((x[2] - (x[1] + formation_dx_2))^2 + (y[2] - y[1])^2 + (z[2] - z[1])^2 + 1.0e-6);
  formation_error_3 = sqrt((x[3] - (x[1] + formation_dx_3))^2 + (y[3] - (y[1] + formation_dy_3))^2 + (z[3] - z[1])^2 + 1.0e-6);
  formation_error_degraded = if (time >= t_drop_start and time < t_drop_end) then
    max(formation_error_2, formation_error_3) else 0.0;
  formation_error_recovered = if (time >= t_drop_end) then
    max(formation_error_2, formation_error_3) else 0.0;

  annotation(
    experiment(StopTime = 8.0, Interval = 0.0125, Tolerance = 1e-6),
    Documentation(info = "AirTrioResilientA: three 1.8 kg quadrotors (12 rotors total, 8.64 N/rotor limit) "
      ~ "in a triangular formation. Leader follows a 6 m linear route completed by t=6 s. "
      ~ "Communication dropout t=3.5-4.0 s (0.5 s, middle third of 8 s scenario) with shared disturbance. "
      ~ "Followers use dead-reckoning prediction from last-received peer state during dropout. "
      ~ "Distributed PD control, collision avoidance, GPS/IMU/range sensor traces. "
      ~ "80 Hz sample rate (Interval=0.0125 s), 8 s simulation.")
  );
end AirTrioResilientA;