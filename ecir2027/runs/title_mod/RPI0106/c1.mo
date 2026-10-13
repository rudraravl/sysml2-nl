model CoaxLiftSurveyD
  "Instrumented coaxial rotor aerial robot with cable slung payload";

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

  parameter Real wp1_x = 0.0;
  parameter Real wp1_y = 0.0;
  parameter Real wp1_z = 1.5;
  parameter Real wp2_x = 4.0;
  parameter Real wp2_y = 0.0;
  parameter Real wp2_z = 2.5;
  parameter Real wp3_x = 4.0;
  parameter Real wp3_y = 3.0;
  parameter Real wp3_z = 2.5;
  parameter Real wp4_x = 1.0;
  parameter Real wp4_y = 4.0;
  parameter Real wp4_z = 2.0;
  parameter Real t_wp1 = 0.0;
  parameter Real t_wp2 = 4.5;
  parameter Real t_wp3 = 9.0;
  parameter Real t_wp4 = 14.0;

  parameter Real Kp_x = 4.0;
  parameter Real Kd_x = 5.0;
  parameter Real Kp_y = 4.0;
  parameter Real Kd_y = 5.0;
  parameter Real Kp_z = 5.0;
  parameter Real Kd_z = 6.0;

  parameter Real wind_force = 6.0 "Crosswind force [N]";
  parameter Real t_wind_start = 14.0 / 3.0 "Wind start [s]";
  parameter Real t_wind_end = 2.0 * 14.0 / 3.0 "Wind end [s]";

  parameter Real obs1_cx = 2.0;
  parameter Real obs1_cy = -0.80;
  parameter Real obs1_r = 0.30;
  parameter Real obs1_h = 3.0;
  parameter Real obs2_cx = 5.0;
  parameter Real obs2_cy = 1.50;
  parameter Real obs2_r = 0.30;
  parameter Real obs2_h = 3.0;
  parameter Real obs3_cx = 2.0;
  parameter Real obs3_cy = 4.50;
  parameter Real obs3_r = 0.30;
  parameter Real obs3_h = 3.0;

  parameter Real ke_pos = 3.0 "Position correction gain [1/s]";
  parameter Real ke_vel = 4.0 "Velocity correction gain [1/s2]";

  Real x(start = 0.0, fixed = true);
  Real y(start = 0.0, fixed = true);
  Real z(start = 1.5, fixed = true);
  Real vx(start = 0.0, fixed = true);
  Real vy(start = 0.0, fixed = true);
  Real vz(start = 0.0, fixed = true);
  Real ax, ay, az;

  Real phi(start = 0.0, fixed = true);
  Real theta(start = 0.0, fixed = true);
  Real psi(start = 0.0, fixed = true);
  Real phi_cmd, theta_cmd, psi_cmd;

  Real alpha(start = 0.0, fixed = true);
  Real beta(start = 0.0, fixed = true);
  Real omega_alpha(start = 0.0, fixed = true);
  Real omega_beta(start = 0.0, fixed = true);

  Real T_total;
  Real thrust_cmd_raw;
  Real T1, T2, T3, T4, T5, T6, T7, T8;

  Real tau;
  Real mj_pos, mj_vel, mj_acc;
  Real dt_seg;
  Real dx_seg, dy_seg, dz_seg;
  Real sx_seg, sy_seg, sz_seg;
  Real ref_x, ref_y, ref_z;
  Real ref_vx, ref_vy, ref_vz;
  Real ref_ax, ref_ay, ref_az;

  Real err_x, err_y, err_z;
  Real tracking_error;

  Real wind_x;

  Real imu_ax, imu_ay, imu_az;
  Real gps_x, gps_y, gps_z;
  Real alt_z;
  Real cam_x, cam_y, cam_z, cam_ts;

  Real est_x(start = 0.0, fixed = true);
  Real est_y(start = 0.0, fixed = true);
  Real est_z(start = 1.5, fixed = true);
  Real est_vx(start = 0.0, fixed = true);
  Real est_vy(start = 0.0, fixed = true);
  Real est_vz(start = 0.0, fixed = true);

  Real ctrl_ex, ctrl_ey, ctrl_ez;
  Real ax_des, ay_des, az_des;

  Real dist1, dist2, dist3;
  Real min_clearance;
  Real est_finite;
  Real all_finite;

  constant Real pi_val = 3.14159265358979;

equation
  tau = if time < t_wp2 then (time - t_wp1) / (t_wp2 - t_wp1) elseif time < t_wp3 then (time - t_wp2) / (t_wp3 - t_wp2) elseif time < t_wp4 then (time - t_wp3) / (t_wp4 - t_wp3) else 1.0;

  mj_pos = 10.0 * tau * tau * tau - 15.0 * tau * tau * tau * tau + 6.0 * tau * tau * tau * tau * tau;
  mj_vel = 30.0 * tau * tau - 60.0 * tau * tau * tau + 30.0 * tau * tau * tau * tau;
  mj_acc = 60.0 * tau - 180.0 * tau * tau + 120.0 * tau * tau * tau;

  dt_seg = if time < t_wp2 then (t_wp2 - t_wp1) elseif time < t_wp3 then (t_wp3 - t_wp2) elseif time < t_wp4 then (t_wp4 - t_wp3) else 1.0;

  dx_seg = if time < t_wp2 then (wp2_x - wp1_x) elseif time < t_wp3 then (wp3_x - wp2_x) elseif time < t_wp4 then (wp4_x - wp3_x) else 0.0;
  dy_seg = if time < t_wp2 then (wp2_y - wp1_y) elseif time < t_wp3 then (wp3_y - wp2_y) elseif time < t_wp4 then (wp4_y - wp3_y) else 0.0;
  dz_seg = if time < t_wp2 then (wp2_z - wp1_z) elseif time < t_wp3 then (wp3_z - wp2_z) elseif time < t_wp4 then (wp4_z - wp3_z) else 0.0;

  sx_seg = if time < t_wp2 then wp1_x elseif time < t_wp3 then wp2_x elseif time < t_wp4 then wp3_x else wp4_x;
  sy_seg = if time < t_wp2 then wp1_y elseif time < t_wp3 then wp2_y elseif time < t_wp4 then wp3_y else wp4_y;
  sz_seg = if time < t_wp2 then wp1_z elseif time < t_wp3 then wp2_z elseif time < t_wp4 then wp3_z else wp4_z;

  ref_x = sx_seg + dx_seg * mj_pos;
  ref_y = sy_seg + dy_seg * mj_pos;
  ref_z = sz_seg + dz_seg * mj_pos;

  ref_vx = dx_seg * mj_vel / dt_seg;
  ref_vy = dy_seg * mj_vel / dt_seg;
  ref_vz = dz_seg * mj_vel / dt_seg;

  ref_ax = dx_seg * mj_acc / (dt_seg * dt_seg);
  ref_ay = dy_seg * mj_acc / (dt_seg * dt_seg);
  ref_az = dz_seg * mj_acc / (dt_seg * dt_seg);

  wind_x = if time >= t_wind_start and time <= t_wind_end then wind_force else 0.0;

  imu_ax = ax + 0.02 * sin(2.0 * pi_val * 5.0 * time);
  imu_ay = ay + 0.02 * sin(2.0 * pi_val * 7.0 * time);
  imu_az = az + 0.02 * sin(2.0 * pi_val * 3.0 * time);
  gps_x = x + 0.08 * sin(2.0 * pi_val * 0.3 * time);
  gps_y = y + 0.08 * cos(2.0 * pi_val * 0.4 * time);
  gps_z = z + 0.08 * sin(2.0 * pi_val * 0.35 * time);
  alt_z = z + 0.02 * sin(2.0 * pi_val * 1.0 * time);
  cam_x = x + 0.04 * sin(2.0 * pi_val * 0.5 * time + 1.0);
  cam_y = y + 0.04 * cos(2.0 * pi_val * 0.6 * time);
  cam_z = z + 0.04 * sin(2.0 * pi_val * 0.55 * time);
  cam_ts = time;

  der(est_x) = est_vx + ke_pos * (gps_x - est_x) + 0.5 * ke_pos * (cam_x - est_x);
  der(est_vx) = imu_ax + ke_vel * (gps_x - est_x);
  der(est_y) = est_vy + ke_pos * (gps_y - est_y) + 0.5 * ke_pos * (cam_y - est_y);
  der(est_vy) = imu_ay + ke_vel * (gps_y - est_y);
  der(est_z) = est_vz + ke_pos * (alt_z - est_z) + 0.5 * ke_pos * (cam_z - est_z) + 0.3 * ke_pos * (gps_z - est_z);
  der(est_vz) = imu_az + ke_vel * (alt_z - est_z);

  ctrl_ex = ref_x - est_x;
  ctrl_ey = ref_y - est_y;
  ctrl_ez = ref_z - est_z;
  ax_des = ref_ax + Kp_x * ctrl_ex + Kd_x * (ref_vx - est_vx);
  ay_des = ref_ay + Kp_y * ctrl_ey + Kd_y * (ref_vy - est_vy);
  az_des = ref_az + Kp_z * ctrl_ez + Kd_z * (ref_vz - est_vz);

  thrust_cmd_raw = m_total * (az_des + g_acc) / max(cos(theta) * cos(phi), 0.1);
  T_total = max(0.0, min(Tmax_total, thrust_cmd_raw));

  theta_cmd = max(-max_pitch, min(max_pitch, m_total * ax_des / max(T_total, 1.0)));
  phi_cmd = max(-max_roll, min(max_roll, -m_total * ay_des / max(T_total, 1.0)));
  psi_cmd = 0.0;

  der(phi) = (phi_cmd - phi) / tau_att;
  der(theta) = (theta_cmd - theta) / tau_att;
  der(psi) = (psi_cmd - psi) / tau_att;

  T1 = max(0.0, min(Tmax_rotor, T_total / 8.0));
  T2 = max(0.0, min(Tmax_rotor, T_total / 8.0));
  T3 = max(0.0, min(Tmax_rotor, T_total / 8.0));
  T4 = max(0.0, min(Tmax_rotor, T_total / 8.0));
  T5 = max(0.0, min(Tmax_rotor, T_total / 8.0));
  T6 = max(0.0, min(Tmax_rotor, T_total / 8.0));
  T7 = max(0.0, min(Tmax_rotor, T_total / 8.0));
  T8 = max(0.0, min(Tmax_rotor, T_total / 8.0));

  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  der(vx) = ax;
  der(vy) = ay;
  der(vz) = az;

  m_total * ax = T_total * sin(theta) * cos(phi) + wind_x + m_payload * g_acc * sin(alpha);
  m_total * ay = -T_total * sin(phi) * cos(theta) + m_payload * g_acc * sin(beta);
  m_total * az = T_total * cos(theta) * cos(phi) - m_total * g_acc;

  der(alpha) = omega_alpha;
  der(omega_alpha) = -(ax * cos(alpha) + g_acc * sin(alpha)) / L_cable;
  der(beta) = omega_beta;
  der(omega_beta) = -(ay * cos(beta) + g_acc * sin(beta)) / L_cable;

  err_x = ref_x - x;
  err_y = ref_y - y;
  err_z = ref_z - z;
  tracking_error = sqrt(err_x * err_x + err_y * err_y + err_z * err_z);

  dist1 = sqrt((x - obs1_cx) * (x - obs1_cx) + (y - obs1_cy) * (y - obs1_cy)) - obs1_r;
  dist2 = sqrt((x - obs2_cx) * (x - obs2_cx) + (y - obs2_cy) * (y - obs2_cy)) - obs2_r;
  dist3 = sqrt((x - obs3_cx) * (x - obs3_cx) + (y - obs3_cy) * (y - obs3_cy)) - obs3_r;
  min_clearance = min(dist1, min(dist2, dist3));

  est_finite = if noEvent(abs(est_x) < 1e4 and abs(est_y) < 1e4 and abs(est_z) < 1e4 and abs(est_vx) < 1e3 and abs(est_vy) < 1e3 and abs(est_vz) < 1e3) then 1.0 else 0.0;

  all_finite = if noEvent(abs(x) < 1e4 and abs(y) < 1e4 and abs(z) < 1e4 and abs(vx) < 1e3 and abs(vy) < 1e3 and abs(vz) < 1e3 and abs(T_total) < 1e5 and abs(phi) < 10.0 and abs(theta) < 10.0 and abs(ax) < 1e3 and abs(ay) < 1e3 and abs(az) < 1e3 and est_finite > 0.5) then 1.0 else 0.0;

  assert(T_total <= Tmax_total + 1e-6, "Thrust bound violated");
  assert(T1 <= Tmax_rotor + 1e-6, "Rotor 1 thrust bound violated");
  assert(T2 <= Tmax_rotor + 1e-6, "Rotor 2 thrust bound violated");
  assert(T3 <= Tmax_rotor + 1e-6, "Rotor 3 thrust bound violated");
  assert(T4 <= Tmax_rotor + 1e-6, "Rotor 4 thrust bound violated");
  assert(T5 <= Tmax_rotor + 1e-6, "Rotor 5 thrust bound violated");
  assert(T6 <= Tmax_rotor + 1e-6, "Rotor 6 thrust bound violated");
  assert(T7 <= Tmax_rotor + 1e-6, "Rotor 7 thrust bound violated");
  assert(T8 <= Tmax_rotor + 1e-6, "Rotor 8 thrust bound violated");
  assert(abs(phi) <= max_roll + 0.01, "Roll bound violated");
  assert(abs(theta) <= max_pitch + 0.01, "Pitch bound violated");
  assert(time < 9.1 or tracking_error < 0.35, "Primary tracking error exceeds 0.35 m after 9.1 s");
  assert(est_finite > 0.5, "Estimator values not finite");
  assert(all_finite > 0.5, "Physical control or estimator values not finite");
  assert(dist1 >= 0.0 or z >= obs1_h or z <= 0.0, "Collision with obstacle 1");
  assert(dist2 >= 0.0 or z >= obs2_h or z <= 0.0, "Collision with obstacle 2");
  assert(dist3 >= 0.0 or z >= obs3_h or z <= 0.0, "Collision with obstacle 3");

  annotation(
    Documentation(info = "CoaxLiftSurveyD: 4.4 kg cargo platform with four coaxial counter-rotating rotor pairs (8 channels, 10 N max each). Carries 1.2 kg payload on 0.70 m massless cable. Tracks waypoints [0,0,1.5], [4,0,2.5], [4,3,2.5], [1,4,2] m at deadlines 0, 4.5, 9.0, 14.0 s. Fuses IMU, GPS, altimeter, and camera into pose and velocity estimates via complementary filter. 6 N crosswind during middle third. Three fixed cylindrical obstacles outside reference polyline. Minimum-jerk reference with PD feedforward acceleration control. 200 Hz for 14 s. Unknown facts not modeled: rotor arm geometry, motor dynamics, exact sensor update rates, camera FOV, obstacle material properties."),
    experiment(StartTime = 0, StopTime = 14.0, Tolerance = 1e-6, Interval = 0.005)
  );
end CoaxLiftSurveyD;