model CoaxLiftSurveyD
  parameter Real m_body = 4.4 "Body mass [kg]";
  parameter Real m_payload = 1.2 "Payload mass [kg]";
  parameter Real m_total = 5.6 "Total mass [kg]";
  parameter Real L_cable = 0.70 "Cable length [m]";
  parameter Real g_acc = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real Tmax_rotor = 10.0 "Max thrust per rotor [N]";
  parameter Real Tmax_total = 80.0 "Max total thrust [N]";
  parameter Real tau_att = 0.12 "Attitude time constant [s]";
  parameter Real lim_roll = 0.40 "Roll limit [rad]";
  parameter Real lim_pitch = 0.40 "Pitch limit [rad]";

  parameter Real wp1[3] = {0.0, 0.0, 1.5};
  parameter Real wp2[3] = {4.0, 0.0, 2.5};
  parameter Real wp3[3] = {4.0, 3.0, 2.5};
  parameter Real wp4[3] = {1.0, 4.0, 2.0};
  parameter Real t_wp1 = 0.0;
  parameter Real t_wp2 = 4.5;
  parameter Real t_wp3 = 9.0;
  parameter Real t_wp4 = 14.0;

  parameter Real Kp_pos = 4.0;
  parameter Real Kd_pos = 5.0;
  parameter Real Kp_z = 6.0;
  parameter Real Kd_z = 7.0;

  parameter Real wind_force = 6.0;
  parameter Real t_wind_start = 4.6666667;
  parameter Real t_wind_end = 9.3333333;

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

  parameter Real ke_pos = 3.0;
  parameter Real ke_vel = 4.0;

  Real x(start = 0.0, fixed = true);
  Real y(start = 0.0, fixed = true);
  Real z(start = 1.5, fixed = true);
  Real vx(start = 0.0, fixed = true);
  Real vy(start = 0.0, fixed = true);
  Real vz(start = 0.0, fixed = true);
  Real ax;
  Real ay;
  Real az;

  Real phi(start = 0.0, fixed = true);
  Real theta(start = 0.0, fixed = true);
  Real psi(start = 0.0, fixed = true);
  Real phi_cmd;
  Real theta_cmd;
  Real psi_cmd;

  Real T_total;
  Real T1, T2, T3, T4, T5, T6, T7, T8;

  Real tau;
  Real mj_pos;
  Real mj_vel;
  Real mj_acc;
  Real dt_seg;
  Real sx, sy, sz;
  Real dxs, dys, dzs;
  Real ref_x, ref_y, ref_z;
  Real ref_vx, ref_vy, ref_vz;
  Real ref_ax, ref_ay, ref_az;

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

  Real dist1, dist2, dist3;
  Real min_clearance;
  Real est_finite;
  Real all_finite;
  Real safe_div;

protected
  constant Real pi_val = 3.14159265358979;
  Real tau3, tau4, tau5;
  Real err_x, err_y, err_z;
  Real ctrl_ex, ctrl_ey, ctrl_ez;
  Real ax_des, ay_des, az_des;
  Real thrust_raw;
  Real cos_ph, cos_th, ctp;

equation
  tau3 = tau * tau * tau;
  tau4 = tau3 * tau;
  tau5 = tau4 * tau;
  mj_pos = 10.0 * tau3 - 15.0 * tau4 + 6.0 * tau5;
  mj_vel = 30.0 * tau * tau - 60.0 * tau3 + 30.0 * tau4;
  mj_acc = 60.0 * tau - 180.0 * tau * tau + 120.0 * tau3;

  if time < t_wp2 then
    tau = (time - t_wp1) / (t_wp2 - t_wp1);
    dt_seg = t_wp2 - t_wp1;
    sx = wp1[1]; sy = wp1[2]; sz = wp1[3];
    dxs = wp2[1] - wp1[1]; dys = wp2[2] - wp1[2]; dzs = wp2[3] - wp1[3];
  elseif time < t_wp3 then
    tau = (time - t_wp2) / (t_wp3 - t_wp2);
    dt_seg = t_wp3 - t_wp2;
    sx = wp2[1]; sy = wp2[2]; sz = wp2[3];
    dxs = wp3[1] - wp2[1]; dys = wp3[2] - wp2[2]; dzs = wp3[3] - wp2[3];
  elseif time < t_wp4 then
    tau = (time - t_wp3) / (t_wp4 - t_wp3);
    dt_seg = t_wp4 - t_wp3;
    sx = wp3[1]; sy = wp3[2]; sz = wp3[3];
    dxs = wp4[1] - wp3[1]; dys = wp4[2] - wp3[2]; dzs = wp4[3] - wp3[3];
  else
    tau = 1.0;
    dt_seg = 1.0;
    sx = wp4[1]; sy = wp4[2]; sz = wp4[3];
    dxs = 0.0; dys = 0.0; dzs = 0.0;
  end if;

  ref_x = sx + dxs * mj_pos;
  ref_y = sy + dys * mj_pos;
  ref_z = sz + dzs * mj_pos;
  ref_vx = dxs * mj_vel / dt_seg;
  ref_vy = dys * mj_vel / dt_seg;
  ref_vz = dzs * mj_vel / dt_seg;
  ref_ax = dxs * mj_acc / (dt_seg * dt_seg);
  ref_ay = dys * mj_acc / (dt_seg * dt_seg);
  ref_az = dzs * mj_acc / (dt_seg * dt_seg);

  if time >= t_wind_start and time <= t_wind_end then
    wind_x = wind_force;
  else
    wind_x = 0.0;
  end if;

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
  der(est_y) = est_vy + ke_pos * (gps_y - est_y) + 0.5 * ke_pos * (cam_y - est_y);
  der(est_z) = est_vz + ke_pos * (alt_z - est_z) + 0.5 * ke_pos * (cam_z - est_z) + 0.3 * ke_pos * (gps_z - est_z);
  der(est_vx) = imu_ax + ke_vel * (gps_x - est_x);
  der(est_vy) = imu_ay + ke_vel * (gps_y - est_y);
  der(est_vz) = imu_az + ke_vel * (alt_z - est_z);

  ctrl_ex = ref_x - est_x;
  ctrl_ey = ref_y - est_y;
  ctrl_ez = ref_z - est_z;
  ax_des = ref_ax + Kp_pos * ctrl_ex + Kd_pos * (ref_vx - est_vx);
  ay_des = ref_ay + Kp_pos * ctrl_ey + Kd_pos * (ref_vy - est_vy);
  az_des = ref_az + Kp_z * ctrl_ez + Kd_z * (ref_vz - est_vz);

  cos_ph = cos(phi);
  cos_th = cos(theta);
  ctp = cos_th * cos_ph;
  safe_div = if ctp > 0.1 then ctp else 0.1;
  thrust_raw = m_total * (az_des + g_acc) / safe_div;

  if thrust_raw < 0.0 then
    T_total = 0.0;
  elseif thrust_raw > Tmax_total then
    T_total = Tmax_total;
  else
    T_total = thrust_raw;
  end if;

  if m_total * ax_des > T_total then
    theta_cmd = lim_pitch;
  elseif m_total * ax_des < -T_total then
    theta_cmd = -lim_pitch;
  else
    theta_cmd = m_total * ax_des / T_total;
  end if;

  if -m_total * ay_des > T_total then
    phi_cmd = lim_roll;
  elseif -m_total * ay_des < -T_total then
    phi_cmd = -lim_roll;
  else
    phi_cmd = -m_total * ay_des / T_total;
  end if;

  psi_cmd = 0.0;
  der(phi) = (phi_cmd - phi) / tau_att;
  der(theta) = (theta_cmd - theta) / tau_att;
  der(psi) = (psi_cmd - psi) / tau_att;

  T1 = T_total / 8.0;
  T2 = T1;
  T3 = T1;
  T4 = T1;
  T5 = T1;
  T6 = T1;
  T7 = T1;
  T8 = T1;

  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  der(vx) = ax;
  der(vy) = ay;
  der(vz) = az;

  m_total * ax = T_total * sin(theta) * cos(phi) + wind_x;
  m_total * ay = -T_total * sin(phi) * cos(theta);
  m_total * az = T_total * cos(theta) * cos(phi) - m_total * g_acc;

  err_x = ref_x - x;
  err_y = ref_y - y;
  err_z = ref_z - z;
  tracking_error = sqrt(err_x * err_x + err_y * err_y + err_z * err_z);

  dist1 = sqrt((x - obs1_cx) * (x - obs1_cx) + (y - obs1_cy) * (y - obs1_cy)) - obs1_r;
  dist2 = sqrt((x - obs2_cx) * (x - obs2_cx) + (y - obs2_cy) * (y - obs2_cy)) - obs2_r;
  dist3 = sqrt((x - obs3_cx) * (x - obs3_cx) + (y - obs3_cy) * (y - obs3_cy)) - obs3_r;

  if dist1 <= dist2 and dist1 <= dist3 then
    min_clearance = dist1;
  elseif dist2 <= dist3 then
    min_clearance = dist2;
  else
    min_clearance = dist3;
  end if;

  est_finite = if noEvent(abs(est_x) < 1.0e4 and abs(est_y) < 1.0e4 and abs(est_z) < 1.0e4 and abs(est_vx) < 1.0e3 and abs(est_vy) < 1.0e3 and abs(est_vz) < 1.0e3) then 1.0 else 0.0;

  all_finite = if noEvent(abs(x) < 1.0e4 and abs(y) < 1.0e4 and abs(z) < 1.0e4 and abs(vx) < 1.0e3 and abs(vy) < 1.0e3 and abs(vz) < 1.0e3 and abs(T_total) < 1.0e5 and abs(phi) < 10.0 and abs(theta) < 10.0 and abs(ax) < 1.0e3 and abs(ay) < 1.0e3 and abs(az) < 1.0e3 and est_finite > 0.5) then 1.0 else 0.0;

  assert(T_total <= Tmax_total + 1.0e-6, "Thrust bound violated");
  assert(T1 <= Tmax_rotor + 1.0e-6, "Rotor thrust bound violated");
  assert(abs(phi) <= lim_roll + 0.01, "Roll bound violated");
  assert(abs(theta) <= lim_pitch + 0.01, "Pitch bound violated");
  assert(time < 9.1 or tracking_error < 0.35, "Primary tracking error exceeds 0.35 m after 9.1 s");
  assert(est_finite > 0.5, "Estimator values not finite");
  assert(all_finite > 0.5, "Values not finite");
  assert(dist1 >= 0.0 or z >= obs1_h or z <= 0.0, "Collision with obstacle 1");
  assert(dist2 >= 0.0 or z >= obs2_h or z <= 0.0, "Collision with obstacle 2");
  assert(dist3 >= 0.0 or z >= obs3_h or z <= 0.0, "Collision with obstacle 3");

  annotation(
    Documentation(info = "CoaxLiftSurveyD: 4.4 kg cargo platform with four coaxial counter-rotating rotor pairs (8 channels, 10 N max each). Carries 1.2 kg payload on 0.70 m massless cable. Tracks waypoints [0,0,1.5], [4,0,2.5], [4,3,2.5], [1,4,2] m. Fuses IMU, GPS, altimeter, and camera into pose and velocity estimates. 6 N crosswind during middle third. Three fixed cylindrical obstacles outside reference polyline. 200 Hz for 14 s. Unknown: rotor arm geometry, motor dynamics, exact sensor rates, camera FOV, obstacle material."),
    experiment(StartTime = 0, StopTime = 14.0, Tolerance = 1.0e-6, Interval = 0.005)
  );
end CoaxLiftSurveyD;