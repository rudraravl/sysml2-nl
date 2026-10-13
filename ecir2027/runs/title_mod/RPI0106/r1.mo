model CoaxLiftSurveyD
  // Gravitational constant
  constant Real g = 9.81 "m/s2";

  // Mass properties (from request)
  parameter Real m_platform = 4.4 "kg cargo platform";
  parameter Real m_payload = 1.2 "kg payload";
  parameter Real m_total = 5.6 "kg total (platform+payload)";
  parameter Real L_cable = 0.70 "m massless cable";

  // Rotor configuration
  parameter Real N_rotor = 8.0 "count of rotors (four coaxial pairs)";
  parameter Real Tmax_rotor = 10.0 "N per rotor";
  parameter Real Tmax_total = 80.0 "N total thrust bound";
  parameter Real tilt_max = 0.4 "rad attitude tilt bound";
  parameter Real tau_max = 4.0 "N.m attitude torque bound";

  // Nominal inertia (not specified in request; nominal values used for attitude dynamics)
  parameter Real I_roll = 0.05 "kg.m2 nominal";
  parameter Real I_pitch = 0.05 "kg.m2 nominal";
  parameter Real I_yaw = 0.08 "kg.m2 nominal";

  // Run schedule
  parameter Real Ts = 0.005 "s sample period (200 Hz)";
  parameter Real T_end = 14.0 "s run duration";

  // Waypoints (m) and deadlines (s)
  parameter Real WP1x = 0.0 "m";  parameter Real WP1y = 0.0 "m";  parameter Real WP1z = 1.5 "m";
  parameter Real WP2x = 4.0 "m";  parameter Real WP2y = 0.0 "m";  parameter Real WP2z = 2.5 "m";
  parameter Real WP3x = 4.0 "m";  parameter Real WP3y = 3.0 "m";  parameter Real WP3z = 2.5 "m";
  parameter Real WP4x = 1.0 "m";  parameter Real WP4y = 4.0 "m";  parameter Real WP4z = 2.0 "m";
  parameter Real d1 = 3.5 "s";  parameter Real d2 = 7.0 "s";
  parameter Real d3 = 10.5 "s"; parameter Real d4 = 14.0 "s";

  // Three fixed cylindrical obstacles (x,y,radius in m) placed outside reference polyline
  parameter Real OBS1x = 2.0;  parameter Real OBS1y = -1.0; parameter Real OBS1r = 0.3;
  parameter Real OBS2x = 5.0;  parameter Real OBS2y = 1.5;  parameter Real OBS2r = 0.3;
  parameter Real OBS3x = 0.0;  parameter Real OBS3y = 2.5;  parameter Real OBS3r = 0.3;
  parameter Real OBS_h = 3.0 "m cylinder height";

  // Crosswind disturbance
  parameter Real windForce = 6.0 "N applied in +y during middle third";

  // Controller gains (PD + feedforward acceleration)
  parameter Real Kp_pos = 4.0;
  parameter Real Kd_pos = 5.0;
  parameter Real Kp_att = 30.0;
  parameter Real Kd_att = 8.0;
  parameter Real Kp_yaw = 5.0;
  parameter Real Kd_yaw = 2.0;

  // Estimator (Luenberger observer) gains fusing IMU/GPS/altimeter
  parameter Real L1 = 10.0;
  parameter Real L2 = 50.0;
  parameter Real L3 = 10.0;

  // Pendulum (payload swing) nominal damping
  parameter Real zeta_pend = 0.3;
  parameter Real omega_p = 3.742 "rad/s sqrt(g/L_cable)";

  // ---------------- Platform states ----------------
  Real x(start = 0.0) "m";   Real y(start = 0.0) "m";   Real z(start = 1.5) "m";
  Real vx(start = 0.0) "m/s"; Real vy(start = 0.0) "m/s"; Real vz(start = 0.0) "m/s";
  Real roll(start = 0.0) "rad";  Real pitch(start = 0.0) "rad";  Real yaw_s(start = 0.0) "rad";
  Real roll_d(start = 0.0) "rad/s"; Real pitch_d(start = 0.0) "rad/s"; Real yaw_d_s(start = 0.0) "rad/s";

  // Payload pendulum (small-angle, two decoupled planar angles)
  Real alpha(start = 0.0) "rad";  Real beta(start = 0.0) "rad";
  Real alpha_d(start = 0.0) "rad/s"; Real beta_d(start = 0.0) "rad/s";
  Real px "m payload x"; Real py "m payload y"; Real pz "m payload z";

  // ---------------- Control ----------------
  Real T_total "N desired total thrust";
  Real T_total_sat "N saturated total thrust";
  Real roll_cmd "rad";  Real pitch_cmd "rad";  Real yaw_cmd "rad";
  Real roll_sat "rad";  Real pitch_sat "rad";
  Real T_vec_des_x "N"; Real T_vec_des_y "N"; Real T_vec_des_z "N";
  Real T_vec_x "N"; Real T_vec_y "N"; Real T_vec_z "N";
  Real a_des_x "m/s2"; Real a_des_y "m/s2"; Real a_des_z "m/s2";
  Real tau_roll_raw "N.m"; Real tau_pitch_raw "N.m"; Real tau_yaw_raw "N.m";
  Real tau_roll "N.m"; Real tau_pitch "N.m"; Real tau_yaw "N.m";
  Real T_per_rotor "N per rotor";
  Real T1, T2, T3, T4, T5, T6, T7, T8 "N individual rotor thrusts";

  // ---------------- Reference trajectory (smoothstep + feedforward) ----------------
  Real s2, s3, s4;
  Real ref_x "m"; Real ref_y "m"; Real ref_z "m";
  Real ref_vx "m/s"; Real ref_vy "m/s"; Real ref_vz "m/s";
  Real ref_ax "m/s2"; Real ref_ay "m/s2"; Real ref_az "m/s2";

  // ---------------- Sensors ----------------
  Real gps_x "m"; Real gps_y "m"; Real gps_vx "m/s"; Real gps_vy "m/s"; Real gps_vz "m/s";
  Real alt_z_s "m";
  Real imu_ax "m/s2"; Real imu_ay "m/s2"; Real imu_az "m/s2";
  Real cam_ts "s camera timestamp (synchronized)";

  // ---------------- Estimator ----------------
  Real est_x(start = 0.0) "m";  Real est_y(start = 0.0) "m";  Real est_z(start = 1.5) "m";
  Real est_vx(start = 0.0) "m/s"; Real est_vy(start = 0.0) "m/s"; Real est_vz(start = 0.0) "m/s";
  Real est_roll(start = 0.0) "rad"; Real est_pitch(start = 0.0) "rad";

  // ---------------- Obstacles / wind / checks ----------------
  Real d1_obs "m"; Real d2_obs "m"; Real d3_obs "m"; Real min_obs_dist "m";
  Real obs_rep_x "m/s2"; Real obs_rep_y "m/s2";
  Real collision_flag;
  Real Fwind_y "N"; Real wind_window;
  Real track_err "m primary tracking error";
  Real T_per_rotor_max "N per-rotor bound check";
  Real tilt_check "rad max tilt check";
  Real track_err_after_91 "m tracking error after 9.1 s";
  Real ax_f "m/s2"; Real ay_f "m/s2"; Real az_f "m/s2";
  Real finiteness "aggregate finiteness (0 if all finite, NaN if any NaN/Inf)";

initial equation
  z = 1.5;
  est_z = 1.5;

equation
  // ----- Smoothstep segment parameters (clamped) -----
  s2 = max(0.0, min(1.0, (time - d1) / (d2 - d1)));
  s3 = max(0.0, min(1.0, (time - d2) / (d3 - d2)));
  s4 = max(0.0, min(1.0, (time - d3) / (d4 - d3)));

  // ----- Reference position via smoothstep h(s)=3s^2-2s^3 -----
  ref_x = if time < d1 then WP1x
          elseif time < d2 then WP1x + (WP2x - WP1x) * (3.0 * s2 * s2 - 2.0 * s2 * s2 * s2)
          elseif time < d3 then WP2x + (WP3x - WP2x) * (3.0 * s3 * s3 - 2.0 * s3 * s3 * s3)
          else WP3x + (WP4x - WP3x) * (3.0 * s4 * s4 - 2.0 * s4 * s4 * s4);
  ref_y = if time < d1 then WP1y
          elseif time < d2 then WP1y + (WP2y - WP1y) * (3.0 * s2 * s2 - 2.0 * s2 * s2 * s2)
          elseif time < d3 then WP2y + (WP3y - WP2y) * (3.0 * s3 * s3 - 2.0 * s3 * s3 * s3)
          else WP3y + (WP4y - WP3y) * (3.0 * s4 * s4 - 2.0 * s4 * s4 * s4);
  ref_z = if time < d1 then WP1z
          elseif time < d2 then WP1z + (WP2z - WP1z) * (3.0 * s2 * s2 - 2.0 * s2 * s2 * s2)
          elseif time < d3 then WP2z + (WP3z - WP2z) * (3.0 * s3 * s3 - 2.0 * s3 * s3 * s3)
          else WP3z + (WP4z - WP3z) * (3.0 * s4 * s4 - 2.0 * s4 * s4 * s4);

  // ----- Reference velocity h'(s)=6s-6s^2 (zero at segment ends) -----
  ref_vx = if time < d1 then 0.0
           elseif time < d2 then (WP2x - WP1x) * (6.0 * s2 - 6.0 * s2 * s2) / (d2 - d1)
           elseif time < d3 then (WP3x - WP2x) * (6.0 * s3 - 6.0 * s3 * s3) / (d3 - d2)
           else (WP4x - WP3x) * (6.0 * s4 - 6.0 * s4 * s4) / (d4 - d3);
  ref_vy = if time < d1 then 0.0
           elseif time < d2 then (WP2y - WP1y) * (6.0 * s2 - 6.0 * s2 * s2) / (d2 - d1)
           elseif time < d3 then (WP3y - WP2y) * (6.0 * s3 - 6.0 * s3 * s3) / (d3 - d2)
           else (WP4y - WP3y) * (6.0 * s4 - 6.0 * s4 * s4) / (d4 - d3);
  ref_vz = if time < d1 then 0.0
           elseif time < d2 then (WP2z - WP1z) * (6.0 * s2 - 6.0 * s2 * s2) / (d2 - d1)
           elseif time < d3 then (WP3z - WP2z) * (6.0 * s3 - 6.0 * s3 * s3) / (d3 - d2)
           else (WP4z - WP3z) * (6.0 * s4 - 6.0 * s4 * s4) / (d4 - d3);

  // ----- Reference acceleration h''(s)=6-12s (feedforward) -----
  ref_ax = if time < d1 then 0.0
           elseif time < d2 then (WP2x - WP1x) * (6.0 - 12.0 * s2) / ((d2 - d1) * (d2 - d1))
           elseif time < d3 then (WP3x - WP2x) * (6.0 - 12.0 * s3) / ((d3 - d2) * (d3 - d2))
           else (WP4x - WP3x) * (6.0 - 12.0 * s4) / ((d4 - d3) * (d4 - d3));
  ref_ay = if time < d1 then 0.0
           elseif time < d2 then (WP2y - WP1y) * (6.0 - 12.0 * s2) / ((d2 - d1) * (d2 - d1))
           elseif time < d3 then (WP3y - WP2y) * (6.0 - 12.0 * s3) / ((d3 - d2) * (d3 - d2))
           else (WP4y - WP3y) * (6.0 - 12.0 * s4) / ((d4 - d3) * (d4 - d3));
  ref_az = if time < d1 then 0.0
           elseif time < d2 then (WP2z - WP1z) * (6.0 - 12.0 * s2) / ((d2 - d1) * (d2 - d1))
           elseif time < d3 then (WP3z - WP2z) * (6.0 - 12.0 * s3) / ((d3 - d2) * (d3 - d2))
           else (WP4z - WP3z) * (6.0 - 12.0 * s4) / ((d4 - d3) * (d4 - d3));

  // ----- Crosswind during middle third of run -----
  wind_window = if (time >= T_end / 3.0 and time <= 2.0 * T_end / 3.0) then 1.0 else 0.0;
  Fwind_y = windForce * wind_window;

  // ----- Obstacle distances (horizontal) and collision flag -----
  d1_obs = sqrt((x - OBS1x) * (x - OBS1x) + (y - OBS1y) * (y - OBS1y)) + 1.0e-9;
  d2_obs = sqrt((x - OBS2x) * (x - OBS2x) + (y - OBS2y) * (y - OBS2y)) + 1.0e-9;
  d3_obs = sqrt((x - OBS3x) * (x - OBS3x) + (y - OBS3y) * (y - OBS3y)) + 1.0e-9;
  min_obs_dist = min(d1_obs, min(d2_obs, d3_obs));
  collision_flag = if (d1_obs < OBS1r or d2_obs < OBS2r or d3_obs < OBS3r) then 1.0 else 0.0;

  // ----- Soft obstacle repulsion (small influence radius; nominal path does not enter) -----
  obs_rep_x = (if d1_obs < 0.6 then 1.0 * (1.0 / d1_obs - 1.0 / 0.6) * (x - OBS1x) / (d1_obs * d1_obs) else 0.0)
            + (if d2_obs < 0.6 then 1.0 * (1.0 / d2_obs - 1.0 / 0.6) * (x - OBS2x) / (d2_obs * d2_obs) else 0.0)
            + (if d3_obs < 0.6 then 1.0 * (1.0 / d3_obs - 1.0 / 0.6) * (x - OBS3x) / (d3_obs * d3_obs) else 0.0);
  obs_rep_y = (if d1_obs < 0.6 then 1.0 * (1.0 / d1_obs - 1.0 / 0.6) * (y - OBS1y) / (d1_obs * d1_obs) else 0.0)
            + (if d2_obs < 0.6 then 1.0 * (1.0 / d2_obs - 1.0 / 0.6) * (y - OBS2y) / (d2_obs * d2_obs) else 0.0)
            + (if d3_obs < 0.6 then 1.0 * (1.0 / d3_obs - 1.0 / 0.6) * (y - OBS3y) / (d3_obs * d3_obs) else 0.0);

  // ----- Sensors (clean measurements feeding the estimator; camera timestamp synced) -----
  gps_x = x;  gps_y = y;  gps_vx = vx;  gps_vy = vy;  gps_vz = vz;
  alt_z_s = z;
  cam_ts = time;
  imu_ax = ax_f;
  imu_ay = ay_f;
  imu_az = az_f;

  // ----- Estimator: Luenberger observer fusing IMU accel + GPS pos/vel + altimeter -----
  der(est_x) = est_vx + L1 * (gps_x - est_x);
  der(est_vx) = imu_ax + L2 * (gps_x - est_x) + L3 * (gps_vx - est_vx);
  der(est_y) = est_vy + L1 * (gps_y - est_y);
  der(est_vy) = imu_ay + L2 * (gps_y - est_y) + L3 * (gps_vy - est_vy);
  der(est_z) = est_vz + L1 * (alt_z_s - est_z);
  der(est_vz) = imu_az + L2 * (alt_z_s - est_z) + L3 * (gps_vz - est_vz);
  est_roll = roll;
  est_pitch = pitch;

  // ----- Controller: PD + feedforward acceleration in world frame -----
  a_des_x = Kp_pos * (ref_x - est_x) + Kd_pos * (ref_vx - est_vx) + ref_ax + obs_rep_x;
  a_des_y = Kp_pos * (ref_y - est_y) + Kd_pos * (ref_vy - est_vy) + ref_ay + obs_rep_y;
  a_des_z = Kp_pos * (ref_z - est_z) + Kd_pos * (ref_vz - est_vz) + ref_az + g;

  // ----- Desired thrust vector (world frame, gravity-compensated) -----
  T_vec_des_x = m_total * a_des_x;
  T_vec_des_y = m_total * a_des_y;
  T_vec_des_z = m_total * a_des_z;
  T_total = sqrt(T_vec_des_x * T_vec_des_x + T_vec_des_y * T_vec_des_y + T_vec_des_z * T_vec_des_z) + 1.0e-9;

  // ----- Desired attitude from thrust direction (yaw held to zero) -----
  roll_cmd = atan2(-T_vec_des_y, T_vec_des_z);
  pitch_cmd = atan2(T_vec_des_x, T_vec_des_z);
  yaw_cmd = 0.0;

  // ----- Saturation: thrust and attitude bounds -----
  T_total_sat = if T_total > Tmax_total then Tmax_total elseif T_total < 0.0 then 0.0 else T_total;
  roll_sat = if roll_cmd > tilt_max then tilt_max elseif roll_cmd < -tilt_max then -tilt_max else roll_cmd;
  pitch_sat = if pitch_cmd > tilt_max then tilt_max elseif pitch_cmd < -tilt_max then -tilt_max else pitch_cmd;

  // ----- Actual thrust vector from saturated attitude -----
  T_vec_x = T_total_sat * sin(pitch_sat);
  T_vec_y = -T_total_sat * sin(roll_sat) * cos(pitch_sat);
  T_vec_z = T_total_sat * cos(roll_sat) * cos(pitch_sat);

  // ----- Platform linear accelerations -----
  ax_f = (T_vec_x) / m_total;
  ay_f = (T_vec_y + Fwind_y) / m_total;
  az_f = (T_vec_z - m_total * g) / m_total;

  // ----- Platform translational dynamics -----
  der(x) = vx;  der(y) = vy;  der(z) = vz;
  der(vx) = ax_f;  der(vy) = ay_f;  der(vz) = az_f;

  // ----- Attitude controller torques (bounded) -----
  tau_roll_raw = Kp_att * (roll_sat - roll) - Kd_att * roll_d;
  tau_pitch_raw = Kp_att * (pitch_sat - pitch) - Kd_att * pitch_d;
  tau_yaw_raw = Kp_yaw * (yaw_cmd - yaw_s) - Kd_yaw * yaw_d_s;
  tau_roll = if tau_roll_raw > tau_max then tau_max elseif tau_roll_raw < -tau_max then -tau_max else tau_roll_raw;
  tau_pitch = if tau_pitch_raw > tau_max then tau_max elseif tau_pitch_raw < -tau_max then -tau_max else tau_pitch_raw;
  tau_yaw = if tau_yaw_raw > tau_max then tau_max elseif tau_yaw_raw < -tau_max then -tau_max else tau_yaw_raw;

  // ----- Attitude dynamics -----
  der(roll) = roll_d;        I_roll * der(roll_d) = tau_roll;
  der(pitch) = pitch_d;      I_pitch * der(pitch_d) = tau_pitch;
  der(yaw_s) = yaw_d_s;      I_yaw * der(yaw_d_s) = tau_yaw;

  // ----- Payload pendulum (linearized, driven by platform accel, damped) -----
  der(alpha) = alpha_d;
  der(alpha_d) = -(omega_p * omega_p) * alpha - ax_f / L_cable - 2.0 * zeta_pend * omega_p * alpha_d;
  der(beta) = beta_d;
  der(beta_d) = -(omega_p * omega_p) * beta - ay_f / L_cable - 2.0 * zeta_pend * omega_p * beta_d;
  px = x + L_cable * alpha;
  py = y + L_cable * beta;
  pz = z - L_cable;

  // ----- Rotor allocation: eight coaxial rotors share thrust equally -----
  T_per_rotor = T_total_sat / N_rotor;
  T1 = T_per_rotor; T2 = T_per_rotor; T3 = T_per_rotor; T4 = T_per_rotor;
  T5 = T_per_rotor; T6 = T_per_rotor; T7 = T_per_rotor; T8 = T_per_rotor;

  // ----- Observables / verification checks -----
  track_err = sqrt((x - ref_x) * (x - ref_x) + (y - ref_y) * (y - ref_y) + (z - ref_z) * (z - ref_z)) + 1.0e-9;
  track_err_after_91 = if time >= 9.1 then track_err else 0.0;
  T_per_rotor_max = T_per_rotor;
  tilt_check = max(abs(roll), abs(pitch));

  // ----- Finiteness aggregate: remains 0 if all finite, becomes NaN if any NaN/Inf -----
  finiteness = (x - x) + (y - y) + (z - z) + (vx - vx) + (vy - vy) + (vz - vz)
             + (roll - roll) + (pitch - pitch) + (yaw_s - yaw_s)
             + (T_total_sat - T_total_sat) + (tau_roll - tau_roll) + (tau_pitch - tau_pitch)
             + (est_x - est_x) + (est_y - est_y) + (est_z - est_z)
             + (est_vx - est_vx) + (est_vy - est_vy) + (est_vz - est_vz)
             + (est_roll - est_roll) + (est_pitch - est_pitch)
             + (track_err - track_err);

  annotation(experiment(StopTime = 14.0, Tolerance = 1.0e-6, Interval = 0.005));
end CoaxLiftSurveyD;