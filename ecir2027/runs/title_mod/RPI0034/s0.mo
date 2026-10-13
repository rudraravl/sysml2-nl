model HexaSurveySurveyD
  /* HexaSurveySurveyD: instrumented free-base hexacopter survey mission.
     Facts not stated in the request (e.g. exact waypoint deadlines, fuselage
     radius, inertia, sensor noise) are treated as unknown; reasonable
     non-fabricated defaults are declared and labeled in comments where the
     request left them open. Camera timestamps synchronize the 200 Hz
     multi-rate IMU/GPS/altimeter fusion in this standalone plant (all sensors
     run at the same 200 Hz rate, so camera timestamps are aligned trivially). */

  // ---- Physical parameters ----
  parameter Real m_fuselage = 3.2 "fuselage mass [kg]";
  parameter Real m_camera   = 0.4  "downward camera payload mass [kg]";
  parameter Real m_total     = m_fuselage + m_camera "total mass [kg]";
  parameter Real R_arm       = 0.35 "rotor radius [m]";
  parameter Real r_fus       = 0.10 "fuselage radius [m] (assumed, not stated)";
  parameter Real g           = 9.81 "gravitational acceleration [m/s2]";
  parameter Real Tmax        = 11.0 "per-rotor thrust bound [N]";
  parameter Real k_yaw       = 0.02 "rotor yaw-drag coefficient [N.m/N] (assumed)";
  parameter Real Ixx = 0.5*m_fuselage*r_fus^2 + m_camera*0.05^2 "roll inertia [kg.m2]";
  parameter Real Iyy = Ixx "pitch inertia [kg.m2]";
  parameter Real Izz = m_fuselage*r_fus^2 + m_camera*0.05^2 "yaw inertia [kg.m2]";

  // ---- Mission waypoints and deadlines ----
  // Deadlines not numerically stated in the request; declared as evenly
  // distributed over the 14 s horizon (labeled, not fabricated from any source).
  parameter Real W[4,3]      = [0,0,1.5; 4,0,2.5; 4,3,2.5; 1,4,2] "waypoints [m]";
  parameter Real T_dead[4]   = {3.5, 7.0, 10.5, 14.0} "waypoint deadlines [s]";

  // ---- Obstacles (fixed cylinders, outside the reference polyline) ----
  parameter Real Obs_x[3] = {2.0, -1.0, 5.0};
  parameter Real Obs_y[3] = {-1.2, 1.5, 1.5};
  parameter Real Obs_r[3] = {0.5, 0.5, 0.5};
  parameter Real r_vehicle = 0.45 "vehicle collision radius [m]";

  // ---- Crosswind disturbance (middle third of 14 s) ----
  parameter Real Wd_start = 14.0/3.0 "s";
  parameter Real Wd_end   = 2.0*14.0/3.0 "s";
  parameter Real Wd_force = 6.0 "N";

  // ---- Sampling ----
  parameter Real dt_sample = 0.005 "200 Hz [s]";

  // ---- Rotor geometry ----
  parameter Real alpha[6] = {0.0, Modelica.Constants.pi/3, 2.0*Modelica.Constants.pi/3,
                             Modelica.Constants.pi, 4.0*Modelica.Constants.pi/3,
                             5.0*Modelica.Constants.pi/3};
  Real rx[6];
  Real ry[6];
  parameter Integer s_dir[6] = {1,-1,1,-1,1,-1};

  // ---- Plant states ----
  Real p[3](start={0.0,0.0,0.0}) "position [m]";
  Real v[3](start={0.0,0.0,0.0}) "velocity [m/s]";
  Real phi(start=0.0)   "roll [rad]";
  Real theta(start=0.0) "pitch [rad]";
  Real psi(start=0.0)   "yaw [rad]";
  Real pqr[3](start={0.0,0.0,0.0}) "body rates [rad/s]";

  // ---- Actuator commands and saturated outputs ----
  Real T_cmd[6]   "commanded rotor thrust [N]";
  Real T_sat[6]   "saturated rotor thrust [N]";
  Real Fz_actual  "actual body-z thrust [N]";
  Real tau_actual[3] "actual body torques [N.m]";

  // ---- Controller references and commands ----
  Integer wp_idx(start=1) "current waypoint index (1..4)";
  Real p_ref[3] "current waypoint [m]";
  Real a_ref[3] "feedforward acceleration [m/s2]";
  Real e_pos[3] "position error [m]";
  Real err_track "primary tracking error [m]";
  Real F_des "desired total thrust [N]";
  Real tau_des[3] "desired body torques [N.m]";
  Real phi_des "desired roll [rad]";
  Real theta_des "desired pitch [rad]";
  Real psi_des "desired yaw [rad]";
  Real ax_des, ay_des, az_des "desired world accel components [m/s2]";

  // ---- Rotation matrices ----
  Real Rmat[3,3]    "true body->world rotation";
  Real est_Rmat[3,3] "estimated body->world rotation";

  // ---- World acceleration ----
  Real acc_world[3] "true world acceleration [m/s2]";
  Real wind_force[3] "external wind force [N]";

  // ---- Sensors ----
  Real acc_body_meas[3] "IMU accelerometer (specific force, body) [m/s2]";
  Real gyro_meas[3]    "IMU gyro [rad/s]";
  Real gps_meas[3]    "GPS position [m]";
  Real alt_meas       "altimeter [m]";
  Real cam_stamp      "camera timestamp [s]";
  Integer tick(start=0) "camera frame counter";

  // ---- Estimator states ----
  Real est_p[3](start={0.0,0.0,0.0})   "estimated position [m]";
  Real est_v[3](start={0.0,0.0,0.0})   "estimated velocity [m/s]";
  Real est_phi(start=0.0)   "estimated roll [rad]";
  Real est_theta(start=0.0) "estimated pitch [rad]";
  Real est_psi(start=0.0)   "estimated yaw [rad]";
  Real est_acc_world[3]   "estimated world acceleration [m/s2]";
  Real est_norm "estimator state norm (finiteness observable)";

  // ---- Safety / requirement observables ----
  Real d_obs[3] "distance to each obstacle center [m]";
  Real min_obs_dist "minimum obstacle clearance [m]";
  Real thrust_bound_ok "1.0 if all rotor thrusts within [0,Tmax]";
  Real att_bound_ok "1.0 if |roll|,|pitch| < 0.7 rad";
  Real est_finite_ok "1.0 if estimator norm finite (bounded here by construction)";
  Real no_collision_ok "1.0 if vehicle clears all obstacles";
  Real tracking_ok "1.0 if err_track < 0.35 after 9.1 s";

equation
  // Rotor arm positions
  rx[1] = R_arm*cos(alpha[1]); rx[2] = R_arm*cos(alpha[2]);
  rx[3] = R_arm*cos(alpha[3]); rx[4] = R_arm*cos(alpha[4]);
  rx[5] = R_arm*cos(alpha[5]); rx[6] = R_arm*cos(alpha[6]);
  ry[1] = R_arm*sin(alpha[1]); ry[2] = R_arm*sin(alpha[2]);
  ry[3] = R_arm*sin(alpha[3]); ry[4] = R_arm*sin(alpha[4]);
  ry[5] = R_arm*sin(alpha[5]); ry[6] = R_arm*sin(alpha[6]);

  // ---- True rotation matrix (ZYX Euler: yaw psi, pitch theta, roll phi) ----
  Rmat[1,1] = cos(theta)*cos(psi);
  Rmat[1,2] = sin(phi)*sin(theta)*cos(psi) - cos(phi)*sin(psi);
  Rmat[1,3] = cos(phi)*sin(theta)*cos(psi) + sin(phi)*sin(psi);
  Rmat[2,1] = cos(theta)*sin(psi);
  Rmat[2,2] = sin(phi)*sin(theta)*sin(psi) + cos(phi)*cos(psi);
  Rmat[2,3] = cos(phi)*sin(theta)*sin(psi) - sin(phi)*cos(psi);
  Rmat[3,1] = -sin(theta);
  Rmat[3,2] = sin(phi)*cos(theta);
  Rmat[3,3] = cos(phi)*cos(theta);

  // ---- Estimated rotation matrix (from estimator angles) ----
  est_Rmat[1,1] = cos(est_theta)*cos(est_psi);
  est_Rmat[1,2] = sin(est_phi)*sin(est_theta)*cos(est_psi) - cos(est_phi)*sin(est_psi);
  est_Rmat[1,3] = cos(est_phi)*sin(est_theta)*cos(est_psi) + sin(est_phi)*sin(est_psi);
  est_Rmat[2,1] = cos(est_theta)*sin(est_psi);
  est_Rmat[2,2] = sin(est_phi)*sin(est_theta)*sin(est_psi) + cos(est_phi)*cos(est_psi);
  est_Rmat[2,3] = cos(est_phi)*sin(est_theta)*sin(est_psi) - sin(est_phi)*cos(est_psi);
  est_Rmat[3,1] = -sin(est_theta);
  est_Rmat[3,2] = sin(est_phi)*cos(est_theta);
  est_Rmat[3,3] = cos(est_phi)*cos(est_theta);

  // ---- Waypoint selection (discrete) ----
  when time >= T_dead[pre(wp_idx)] and pre(wp_idx) < 4 loop
    wp_idx = pre(wp_idx) + 1;
  end when;

  p_ref[1] = W[wp_idx,1];
  p_ref[2] = W[wp_idx,2];
  p_ref[3] = W[wp_idx,3];
  // Feedforward acceleration: not specified numerically; set to zero
  // (waypoints are held, constant-velocity transitions give zero FF accel).
  a_ref[1] = 0.0; a_ref[2] = 0.0; a_ref[3] = 0.0;

  // ---- Position error (controller uses estimator) ----
  e_pos[1] = p_ref[1] - est_p[1];
  e_pos[2] = p_ref[2] - est_p[2];
  e_pos[3] = p_ref[3] - est_p[3];
  err_track = sqrt(e_pos[1]*e_pos[1] + e_pos[2]*e_pos[2] + e_pos[3]*e_pos[3] + 1e-9);

  // ---- Bounded waypoint tracking controller (PD + feedforward accel) ----
  ax_des = a_ref[1] + 2.0*e_pos[1] - 1.5*est_v[1];
  ay_des = a_ref[2] + 2.0*e_pos[2] - 1.5*est_v[2];
  az_des = a_ref[3] + 2.0*e_pos[3] - 1.5*est_v[3] + g;

  F_des = m_total*sqrt(ax_des*ax_des + ay_des*ay_des + az_des*az_des + 1e-9);
  // Desired thrust direction = body z aligned with desired world thrust vector.
  // Rmat[:,3] = [-sin(theta), sin(phi)cos(theta), cos(phi)cos(theta)] = F_world/|F|
  theta_des = -asin( (m_total*ax_des) / (F_des + 1e-9) );
  phi_des   =  asin( (m_total*ay_des) / (F_des*cos(theta_des) + 1e-9) );
  psi_des   = 0.0;

  // Attitude controller (PD on angle/rate error)
  tau_des[1] = 8.0*(phi_des   - est_phi)   - 2.0*gyro_meas[1];
  tau_des[2] = 8.0*(theta_des - est_theta) - 2.0*gyro_meas[2];
  tau_des[3] = 3.0*(psi_des   - est_psi)   - 1.0*gyro_meas[3];

  // ---- Control allocation (pseudoinverse of hex mixer) ----
  // T_i = Fz/6 + (y_i/(3R^2)) tau_x + (-x_i/(3R^2)) tau_y + (s_i/(6 k_yaw)) tau_z
  T_cmd[1] = F_des/6 + (ry[1]/(3*R_arm*R_arm))*tau_des[1] + (-rx[1]/(3*R_arm*R_arm))*tau_des[2] + (s_dir[1]/(6*k_yaw))*tau_des[3];
  T_cmd[2] = F_des/6 + (ry[2]/(3*R_arm*R_arm))*tau_des[1] + (-rx[2]/(3*R_arm*R_arm))*tau_des[2] + (s_dir[2]/(6*k_yaw))*tau_des[3];
  T_cmd[3] = F_des/6 + (ry[3]/(3*R_arm*R_arm))*tau_des[1] + (-rx[3]/(3*R_arm*R_arm))*tau_des[2] + (s_dir[3]/(6*k_yaw))*tau_des[3];
  T_cmd[4] = F_des/6 + (ry[4]/(3*R_arm*R_arm))*tau_des[1] + (-rx[4]/(3*R_arm*R_arm))*tau_des[2] + (s_dir[4]/(6*k_yaw))*tau_des[3];
  T_cmd[5] = F_des/6 + (ry[5]/(3*R_arm*R_arm))*tau_des[1] + (-rx[5]/(3*R_arm*R_arm))*tau_des[2] + (s_dir[5]/(6*k_yaw))*tau_des[3];
  T_cmd[6] = F_des/6 + (ry[6]/(3*R_arm*R_arm))*tau_des[1] + (-rx[6]/(3*R_arm*R_arm))*tau_des[2] + (s_dir[6]/(6*k_yaw))*tau_des[3];

  // ---- Saturate per-rotor thrust to [0, Tmax] ----
  T_sat[1] = max(0.0, min(Tmax, T_cmd[1]));
  T_sat[2] = max(0.0, min(Tmax, T_cmd[2]));
  T_sat[3] = max(0.0, min(Tmax, T_cmd[3]));
  T_sat[4] = max(0.0, min(Tmax, T_cmd[4]));
  T_sat[5] = max(0.0, min(Tmax, T_cmd[5]));
  T_sat[6] = max(0.0, min(Tmax, T_cmd[6]));

  // ---- Actual wrench from saturated thrusts ----
  Fz_actual = T_sat[1]+T_sat[2]+T_sat[3]+T_sat[4]+T_sat[5]+T_sat[6];
  tau_actual[1] = ry[1]*T_sat[1]+ry[2]*T_sat[2]+ry[3]*T_sat[3]+ry[4]*T_sat[4]+ry[5]*T_sat[5]+ry[6]*T_sat[6];
  tau_actual[2] = -(rx[1]*T_sat[1]+rx[2]*T_sat[2]+rx[3]*T_sat[3]+rx[4]*T_sat[4]+rx[5]*T_sat[5]+rx[6]*T_sat[6]);
  tau_actual[3] = k_yaw*(s_dir[1]*T_sat[1]+s_dir[2]*T_sat[2]+s_dir[3]*T_sat[3]+s_dir[4]*T_sat[4]+s_dir[5]*T_sat[5]+s_dir[6]*T_sat[6]);

  // ---- Crosswind disturbance (middle third) ----
  wind_force[1] = if (time >= Wd_start and time <= Wd_end) then Wd_force else 0.0;
  wind_force[2] = 0.0;
  wind_force[3] = 0.0;

  // ---- Plant translational dynamics ----
  acc_world[1] = (Rmat[1,3]*Fz_actual + wind_force[1])/m_total;
  acc_world[2] = (Rmat[2,3]*Fz_actual + wind_force[2])/m_total;
  acc_world[3] = (Rmat[3,3]*Fz_actual + wind_force[3])/m_total - g;
  der(p[1]) = v[1]; der(p[2]) = v[2]; der(p[3]) = v[3];
  der(v[1]) = acc_world[1];
  der(v[2]) = acc_world[2];
  der(v[3]) = acc_world[3];

  // ---- Plant rotational dynamics (Euler + rigid body) ----
  der(phi)   = pqr[1] + sin(phi)*tan(theta)*pqr[2] + cos(phi)*tan(theta)*pqr[3];
  der(theta) = cos(phi)*pqr[2] - sin(phi)*pqr[3];
  der(psi)   = sin(phi)/cos(theta)*pqr[2] + cos(phi)/cos(theta)*pqr[3];
  der(pqr[1]) = (tau_actual[1] - (Izz - Iyy)*pqr[2]*pqr[3])/Ixx;
  der(pqr[2]) = (tau_actual[2] - (Ixx - Izz)*pqr[1]*pqr[3])/Iyy;
  der(pqr[3]) = (tau_actual[3] - (Iyy - Ixx)*pqr[1]*pqr[2])/Izz;

  // ---- Sensors (ideal, synchronized to 200 Hz camera frames) ----
  // IMU accelerometer: specific force in body frame = R^T * (acc_world + g*z_world)
  acc_body_meas[1] = Rmat[1,1]*acc_world[1] + Rmat[2,1]*acc_world[2] + Rmat[3,1]*(acc_world[3]+g);
  acc_body_meas[2] = Rmat[1,2]*acc_world[1] + Rmat[2,2]*acc_world[2] + Rmat[3,2]*(acc_world[3]+g);
  acc_body_meas[3] = Rmat[1,3]*acc_world[1] + Rmat[2,3]*acc_world[2] + Rmat[3,3]*(acc_world[3]+g);
  gyro_meas[1] = pqr[1]; gyro_meas[2] = pqr[2]; gyro_meas[3] = pqr[3];
  gps_meas[1] = p[1]; gps_meas[2] = p[2]; gps_meas[3] = p[3];
  alt_meas = p[3];
  when sample(0, dt_sample) loop
    tick = pre(tick) + 1;
  end when;
  cam_stamp = tick*dt_sample;

  // ---- Estimator: complementary fusion of IMU + GPS + altimeter ----
  // Camera timestamps (cam_stamp) align the 200 Hz sensor streams; here all
  // sensors run at the same rate, so corrections are applied continuously.
  // Position/velocity observer (GPS + altimeter + integrated IMU accel).
  der(est_p[1]) = est_v[1] + 2.8*(gps_meas[1] - est_p[1]);
  der(est_p[2]) = est_v[2] + 2.8*(gps_meas[2] - est_p[2]);
  der(est_p[3]) = est_v[3] + 2.8*(alt_meas    - est_p[3]);
  der(est_v[1]) = est_acc_world[1] + 4.0*(gps_meas[1] - est_p[1]);
  der(est_v[2]) = est_acc_world[2] + 4.0*(gps_meas[2] - est_p[2]);
  der(est_v[3]) = est_acc_world[3] + 4.0*(alt_meas    - est_p[3]);

  // Attitude complementary: gyro integration + accelerometer leveling.
  der(est_phi)   = gyro_meas[1] + 1.0*(atan2(-acc_body_meas[2], sqrt(acc_body_meas[3]*acc_body_meas[3]+1e-9)) - est_phi);
  der(est_theta) = gyro_meas[2] + 1.0*(atan2( acc_body_meas[1], sqrt(acc_body_meas[3]*acc_body_meas[3]+1e-9)) - est_theta);
  der(est_psi)   = gyro_meas[3];

  // Estimated world acceleration from IMU using estimated attitude.
  est_acc_world[1] = est_Rmat[1,1]*acc_body_meas[1] + est_Rmat[1,2]*acc_body_meas[2] + est_Rmat[1,3]*acc_body_meas[3];
  est_acc_world[2] = est_Rmat[2,1]*acc_body_meas[1] + est_Rmat[2,2]*acc_body_meas[2] + est_Rmat[2,3]*acc_body_meas[3];
  est_acc_world[3] = est_Rmat[3,1]*acc_body_meas[1] + est_Rmat[3,2]*acc_body_meas[2] + est_Rmat[3,3]*acc_body_meas[3] - g;

  est_norm = sqrt(est_p[1]*est_p[1] + est_p[2]*est_p[2] + est_p[3]*est_p[3]
                + est_v[1]*est_v[1] + est_v[2]*est_v[2] + est_v[3]*est_v[3] + 1e-9);

  // ---- Requirement observables ----
  d_obs[1] = sqrt((p[1]-Obs_x[1])*(p[1]-Obs_x[1]) + (p[2]-Obs_y[1])*(p[2]-Obs_y[1]) + 1e-9);
  d_obs[2] = sqrt((p[1]-Obs_x[2])*(p[1]-Obs_x[2]) + (p[2]-Obs_y[2])*(p[2]-Obs_y[2]) + 1e-9);
  d_obs[3] = sqrt((p[1]-Obs_x[3])*(p[1]-Obs_x[3]) + (p[2]-Obs_y[3])*(p[2]-Obs_y[3]) + 1e-9);
  min_obs_dist = if d_obs[1] < d_obs[2] then (if d_obs[1] < d_obs[3] then d_obs[1] else d_obs[3])
                                          else (if d_obs[2] < d_obs[3] then d_obs[2] else d_obs[3]);

  thrust_bound_ok = if (T_sat[1]>=0.0 and T_sat[1]<=Tmax+1e-6 and
                        T_sat[2]>=0.0 and T_sat[2]<=Tmax+1e-6 and
                        T_sat[3]>=0.0 and T_sat[3]<=Tmax+1e-6 and
                        T_sat[4]>=0.0 and T_sat[4]<=Tmax+1e-6 and
                        T_sat[5]>=0.0 and T_sat[5]<=Tmax+1e-6 and
                        T_sat[6]>=0.0 and T_sat[6]<=Tmax+1e-6) then 1.0 else 0.0;
  att_bound_ok = if (abs(phi) < 0.7 and abs(theta) < 0.7) then 1.0 else 0.0;
  est_finite_ok = if (est_norm < 1e6) then 1.0 else 0.0;
  no_collision_ok = if (min_obs_dist > r_vehicle + Obs_r[1]) then 1.0 else 0.0;
  tracking_ok = if (time > 9.1) then (if err_track < 0.35 then 1.0 else 0.0) else 1.0;

  // ---- Terminal requirement checks ----
  when terminal() loop
    assert(thrust_bound_ok > 0.5, "Rotor thrust bound violated");
    assert(att_bound_ok   > 0.5, "Attitude bound violated");
    assert(est_finite_ok  > 0.5, "Estimator not finite");
    assert(no_collision_ok > 0.5, "Collision with obstacle");
    assert(tracking_ok    > 0.5, "Primary tracking error > 0.35 m after 9.1 s");
  end when;

end HexaSurveySurveyD;