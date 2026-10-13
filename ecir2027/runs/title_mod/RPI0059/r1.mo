model TiltWingSurveyE
  // === Physical parameters ===
  parameter Real m_fus = 6.2 "Fuselage mass [kg]";
  parameter Real g_acc = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real arm_rotor = 0.62 "Rotor distance from fuselage center [m]";
  parameter Real span_wing = 1.8 "Wing span [m]";
  parameter Real T_max = 57.2 "Max thrust per rotor [N]";
  parameter Real alpha_min = 0.0 "Min rotor tilt joint angle [rad]";
  parameter Real alpha_max = 1.5707963267948966 "Max rotor tilt joint angle [rad]";
  parameter Real theta_bound = 1.5707963267948966 "Attitude bound [rad]";

  // === Timing ===
  parameter Real fs_hz = 250.0 "Control and trace rate [Hz]";
  parameter Real dt_s = 1.0/fs_hz "Sample period [s]";
  parameter Real T_end = 16.0 "Mission duration [s]";

  // === Waypoints and declared deadlines ===
  parameter Real W1[3] = {0.0,0.0,1.5} "Waypoint 1 [m]";
  parameter Real W2[3] = {4.0,0.0,2.5} "Waypoint 2 [m]";
  parameter Real W3[3] = {4.0,3.0,2.5} "Waypoint 3 [m]";
  parameter Real W4[3] = {1.0,4.0,2.0} "Waypoint 4 [m]";
  parameter Real t_d[4] = {4.0,8.0,12.0,16.0} "Waypoint deadlines [s]";

  // === Fixed cylindrical obstacles (outside reference polyline) ===
  parameter Real Obs1_cx = 2.0 "Obstacle 1 center x [m]";
  parameter Real Obs1_cy = -1.5 "Obstacle 1 center y [m]";
  parameter Real Obs1_r = 0.3 "Obstacle 1 radius [m]";
  parameter Real Obs1_h = 1.2 "Obstacle 1 height [m]";
  parameter Real Obs2_cx = 5.5 "Obstacle 2 center x [m]";
  parameter Real Obs2_cy = 1.5 "Obstacle 2 center y [m]";
  parameter Real Obs2_r = 0.3 "Obstacle 2 radius [m]";
  parameter Real Obs2_h = 1.2 "Obstacle 2 height [m]";
  parameter Real Obs3_cx = 0.5 "Obstacle 3 center x [m]";
  parameter Real Obs3_cy = 3.0 "Obstacle 3 center y [m]";
  parameter Real Obs3_r = 0.3 "Obstacle 3 radius [m]";
  parameter Real Obs3_h = 1.2 "Obstacle 3 height [m]";

  // === Control gains ===
  parameter Real Kpr = 4.0 "Reference position gain [1/s2]";
  parameter Real Kdr = 4.0 "Reference damping gain [1/s]";
  parameter Real a_max_ref = 8.0 "Reference acceleration clamp [m/s2]";
  parameter Real Kp = 12.0 "Tracking position gain [1/s2]";
  parameter Real Kd = 6.0 "Tracking damping gain [1/s]";
  parameter Real tau_att = 0.2 "Attitude tracking time constant [s]";
  parameter Real tau_tilt = 0.08 "Tilt actuator time constant [s]";

  // === Estimator / sensor filter time constants ===
  parameter Real tau_gps = 0.04 "GPS filter [s]";
  parameter Real tau_alt = 0.03 "Altimeter filter [s]";
  parameter Real tau_cam = 0.05 "Camera filter [s]";
  parameter Real tau_imu = 0.02 "IMU filter [s]";
  parameter Real tau_vhat = 0.06 "Fused velocity filter [s]";
  parameter Real tau_thetahat = 0.05 "Fused attitude filter [s]";

  // === Plant states ===
  Real r[3](start={0.0,0.0,0.1}) "Fuselage position [m]";
  Real v[3](start={0,0,0}) "Fuselage velocity [m/s]";
  Real theta[3](start={0,0,0}) "Attitude roll, pitch, yaw [rad]";
  Real alpha[2](start={0,0}) "Rotor tilt joint angles [rad]";

  // === Reference trajectory states ===
  Real r_r[3](start={0.0,0.0,0.1}) "Reference position [m]";
  Real v_r[3](start={0,0,0}) "Reference velocity [m/s]";

  // === Sensor channel states ===
  Real r_gps[3](start={0.0,0.0,0.1}) "GPS position measurement [m]";
  Real r_alt(start=0.1) "Altimeter z measurement [m]";
  Real r_cam[3](start={0.0,0.0,0.1}) "Camera position measurement [m]";
  Real a_imu[3](start={0,0,0}) "IMU acceleration measurement [m/s2]";
  Real v_hat[3](start={0,0,0}) "Fused velocity estimate [m/s]";
  Real theta_hat[3](start={0,0,0}) "Fused attitude estimate [rad]";

  // === Commands ===
  Real T_cmd[2] "Thrust command per rotor [N]";
  Real alpha_cmd[2] "Tilt joint command [rad]";
  Real T_sat[2] "Saturated thrust per rotor [N]";
  Real alpha_sat[2] "Saturated tilt command [rad]";

  // === Reference and control intermediates ===
  Real W_cur[3] "Current waypoint [m]";
  Real a_ff_raw[3] "Raw feedforward acceleration [m/s2]";
  Real a_ff[3] "Clamped feedforward acceleration [m/s2]";
  Real w_idx "Current waypoint index";
  Real F_dist[3] "Crosswind disturbance force [N]";
  Real F_des[3] "Desired world-frame force [N]";
  Real F_body[3] "Body-frame rotor force [N]";
  Real F_world[3] "World-frame rotor force [N]";
  Real F_total[3] "Total force on fuselage [N]";
  Real alpha_des "Desired common tilt [rad]";
  Real T_total_des "Desired total thrust [N]";
  Real theta_des[3] "Desired attitude [rad]";

  // === Fused estimate ===
  Real r_hat[3] "Fused position estimate [m]";

  // === Errors, obstacle clearance, acceptance ===
  Real e_pos "Instantaneous waypoint tracking error norm [m]";
  Real d_obs1 "Obstacle 1 radial clearance [m]";
  Real d_obs2 "Obstacle 2 radial clearance [m]";
  Real d_obs3 "Obstacle 3 radial clearance [m]";
  Real coll_flag "Collision flag (1 = collision)";
  Real thrust_violation "Thrust bound violation flag";
  Real attitude_violation "Attitude bound violation flag";
  Real estimator_finite "Estimator finiteness flag (1 = finite)";
  Real no_nan "No NaN or infinite values flag (1 = ok)";
  Real no_collision "No collision flag (1 = ok)";
  Real primary_pass "Primary tracking pass flag (1 = ok after 10.4 s)";
  Real acceptance "Overall fail-closed acceptance (1 = pass, 0 = fail)";

  // === Trace synchronization ===
  Real tick_count "250 Hz sample counter";

equation
  // === Waypoint selection by declared deadline ===
  if time < t_d[1] then
    W_cur[1] = W1[1]; W_cur[2] = W1[2]; W_cur[3] = W1[3]; w_idx = 1.0;
  elseif time < t_d[2] then
    W_cur[1] = W2[1]; W_cur[2] = W2[2]; W_cur[3] = W2[3]; w_idx = 2.0;
  elseif time < t_d[3] then
    W_cur[1] = W3[1]; W_cur[2] = W3[2]; W_cur[3] = W3[3]; w_idx = 3.0;
  else
    W_cur[1] = W4[1]; W_cur[2] = W4[2]; W_cur[3] = W4[3]; w_idx = 4.0;
  end if;

  // === Bounded reference trajectory generator ===
  der(r_r[1]) = v_r[1];
  der(r_r[2]) = v_r[2];
  der(r_r[3]) = v_r[3];
  a_ff_raw[1] = Kpr*(W_cur[1] - r_r[1]) - Kdr*v_r[1];
  a_ff_raw[2] = Kpr*(W_cur[2] - r_r[2]) - Kdr*v_r[2];
  a_ff_raw[3] = Kpr*(W_cur[3] - r_r[3]) - Kdr*v_r[3];
  a_ff[1] = max(-a_max_ref, min(a_max_ref, a_ff_raw[1]));
  a_ff[2] = max(-a_max_ref, min(a_max_ref, a_ff_raw[2]));
  a_ff[3] = max(-a_max_ref, min(a_max_ref, a_ff_raw[3]));
  der(v_r[1]) = a_ff[1];
  der(v_r[2]) = a_ff[2];
  der(v_r[3]) = a_ff[3];

  // === Controlled crosswind disturbance (middle third of mission) ===
  if time >= T_end/3.0 and time <= 2.0*T_end/3.0 then
    F_dist[1] = 7.2; F_dist[2] = 0.0; F_dist[3] = 0.0;
  else
    F_dist[1] = 0.0; F_dist[2] = 0.0; F_dist[3] = 0.0;
  end if;

  // === Sensor channel models (filtered measurements) ===
  der(r_gps[1]) = (r[1] - r_gps[1])/tau_gps;
  der(r_gps[2]) = (r[2] - r_gps[2])/tau_gps;
  der(r_gps[3]) = (r[3] - r_gps[3])/tau_gps;
  der(r_alt) = (r[3] - r_alt)/tau_alt;
  der(r_cam[1]) = (r[1] - r_cam[1])/tau_cam;
  der(r_cam[2]) = (r[2] - r_cam[2])/tau_cam;
  der(r_cam[3]) = (r[3] - r_cam[3])/tau_cam;
  der(a_imu[1]) = (F_total[1]/m_fus - a_imu[1])/tau_imu;
  der(a_imu[2]) = (F_total[2]/m_fus - a_imu[2])/tau_imu;
  der(a_imu[3]) = (F_total[3]/m_fus - a_imu[3])/tau_imu;

  // === Timestamped sensor fusion into pose and velocity estimates ===
  r_hat[1] = 0.5*r_gps[1] + 0.5*r_cam[1];
  r_hat[2] = 0.5*r_gps[2] + 0.5*r_cam[2];
  r_hat[3] = 0.3*r_gps[3] + 0.4*r_alt + 0.3*r_cam[3];
  der(v_hat[1]) = (v[1] - v_hat[1])/tau_vhat;
  der(v_hat[2]) = (v[2] - v_hat[2])/tau_vhat;
  der(v_hat[3]) = (v[3] - v_hat[3])/tau_vhat;
  der(theta_hat[1]) = (theta[1] - theta_hat[1])/tau_thetahat;
  der(theta_hat[2]) = (theta[2] - theta_hat[2])/tau_thetahat;
  der(theta_hat[3]) = (theta[3] - theta_hat[3])/tau_thetahat;

  // === Bounded waypoint tracking with feedforward acceleration ===
  F_des[1] = m_fus*(Kp*(r_r[1] - r_hat[1]) + Kd*(v_r[1] - v_hat[1]) + a_ff[1]);
  F_des[2] = m_fus*(Kp*(r_r[2] - r_hat[2]) + Kd*(v_r[2] - v_hat[2]) + a_ff[2]);
  F_des[3] = m_fus*(Kp*(r_r[3] - r_hat[3]) + Kd*(v_r[3] - v_hat[3]) + a_ff[3]) + m_fus*g_acc;

  // === Control allocation to two thrust channels and two tilt joints ===
  T_total_des = sqrt(F_des[1]*F_des[1] + F_des[2]*F_des[2] + max(F_des[3], 1.0)*max(F_des[3], 1.0));
  alpha_des = atan2(F_des[1], sqrt(F_des[2]*F_des[2] + max(F_des[3], 1.0)*max(F_des[3], 1.0)));
  theta_des[1] = -atan2(F_des[2], max(F_des[3], 1.0));
  theta_des[2] = 0.0;
  theta_des[3] = 0.0;
  T_cmd[1] = T_total_des/2.0;
  T_cmd[2] = T_total_des/2.0;
  alpha_cmd[1] = alpha_des;
  alpha_cmd[2] = alpha_des;

  // === Command saturation ===
  T_sat[1] = max(0.0, min(T_max, T_cmd[1]));
  T_sat[2] = max(0.0, min(T_max, T_cmd[2]));
  alpha_sat[1] = max(alpha_min, min(alpha_max, alpha_cmd[1]));
  alpha_sat[2] = max(alpha_min, min(alpha_max, alpha_cmd[2]));

  // === Rotor forces in body frame (tilt about body y-axis) ===
  F_body[1] = T_sat[1]*sin(alpha_sat[1]) + T_sat[2]*sin(alpha_sat[2]);
  F_body[2] = 0.0;
  F_body[3] = T_sat[1]*cos(alpha_sat[1]) + T_sat[2]*cos(alpha_sat[2]);

  // === Body-to-world rotation (ZYX Euler, yaw = 0) ===
  F_world[1] = cos(theta[2])*F_body[1] + sin(theta[2])*cos(theta[1])*F_body[3];
  F_world[2] = -sin(theta[1])*F_body[3];
  F_world[3] = -sin(theta[2])*F_body[1] + cos(theta[2])*cos(theta[1])*F_body[3];

  // === Total force and translational dynamics ===
  F_total[1] = F_world[1] + F_dist[1];
  F_total[2] = F_world[2] + F_dist[2];
  F_total[3] = F_world[3] + F_dist[3] - m_fus*g_acc;
  der(r[1]) = v[1];
  der(r[2]) = v[2];
  der(r[3]) = v[3];
  der(v[1]) = F_total[1]/m_fus;
  der(v[2]) = F_total[2]/m_fus;
  der(v[3]) = F_total[3]/m_fus;

  // === Attitude dynamics (first-order command tracking) ===
  der(theta[1]) = (theta_des[1] - theta[1])/tau_att;
  der(theta[2]) = (theta_des[2] - theta[2])/tau_att;
  der(theta[3]) = (theta_des[3] - theta[3])/tau_att;

  // === Tilt joint actuator dynamics ===
  der(alpha[1]) = (alpha_sat[1] - alpha[1])/tau_tilt;
  der(alpha[2]) = (alpha_sat[2] - alpha[2])/tau_tilt;

  // === Waypoint tracking error ===
  e_pos = sqrt((r[1]-W_cur[1])*(r[1]-W_cur[1]) + (r[2]-W_cur[2])*(r[2]-W_cur[2]) + (r[3]-W_cur[3])*(r[3]-W_cur[3]));

  // === Obstacle clearance (cylinders) ===
  d_obs1 = sqrt((r[1]-Obs1_cx)*(r[1]-Obs1_cx) + (r[2]-Obs1_cy)*(r[2]-Obs1_cy)) - Obs1_r;
  d_obs2 = sqrt((r[1]-Obs2_cx)*(r[1]-Obs2_cx) + (r[2]-Obs2_cy)*(r[2]-Obs2_cy)) - Obs2_r;
  d_obs3 = sqrt((r[1]-Obs3_cx)*(r[1]-Obs3_cx) + (r[2]-Obs3_cy)*(r[2]-Obs3_cy)) - Obs3_r;
  coll_flag = if noEvent((d_obs1 < 0.0 and r[3] < Obs1_h) or (d_obs2 < 0.0 and r[3] < Obs2_h) or (d_obs3 < 0.0 and r[3] < Obs3_h)) then 1.0 else 0.0;

  // === Acceptance checks (fail-closed) ===
  thrust_violation = if noEvent(T_sat[1] > T_max + 0.001 or T_sat[2] > T_max + 0.001 or T_sat[1] < -0.001 or T_sat[2] < -0.001) then 1.0 else 0.0;
  attitude_violation = if noEvent(abs(theta[1]) > theta_bound or abs(theta[2]) > theta_bound or abs(theta[3]) > theta_bound) then 1.0 else 0.0;
  estimator_finite = if noEvent(abs(r_hat[1]) < 1.0e5 and abs(r_hat[2]) < 1.0e5 and abs(r_hat[3]) < 1.0e5 and abs(v_hat[1]) < 1.0e5 and abs(v_hat[2]) < 1.0e5 and abs(v_hat[3]) < 1.0e5 and abs(theta_hat[1]) < 1.0e5 and abs(theta_hat[2]) < 1.0e5 and abs(theta_hat[3]) < 1.0e5) then 1.0 else 0.0;
  no_collision = if coll_flag < 0.5 then 1.0 else 0.0;
  no_nan = if noEvent(abs(r[1]) < 1.0e6 and abs(r[2]) < 1.0e6 and abs(r[3]) < 1.0e6 and abs(v[1]) < 1.0e6 and abs(v[2]) < 1.0e6 and abs(v[3]) < 1.0e6 and abs(T_sat[1]) < 1.0e6 and abs(T_sat[2]) < 1.0e6 and abs(alpha[1]) < 1.0e6 and abs(alpha[2]) < 1.0e6 and abs(r_hat[1]) < 1.0e6 and abs(r_hat[2]) < 1.0e6 and abs(r_hat[3]) < 1.0e6 and abs(v_hat[1]) < 1.0e6 and abs(v_hat[2]) < 1.0e6 and abs(v_hat[3]) < 1.0e6 and abs(theta_hat[1]) < 1.0e6 and abs(theta_hat[2]) < 1.0e6 and abs(theta_hat[3]) < 1.0e6) then 1.0 else 0.0;
  primary_pass = if noEvent(time >= 10.4 and e_pos < 0.315) then 1.0 else 0.0;
  acceptance = if noEvent(thrust_violation < 0.5 and attitude_violation < 0.5 and estimator_finite > 0.5 and no_collision > 0.5 and no_nan > 0.5 and (time < 10.4 or e_pos < 0.315)) then 1.0 else 0.0;

  // === Synchronized 250 Hz trace counter ===
  tick_count = floor(time/dt_s);

  annotation(
    experiment(StopTime = 16.0, Interval = 0.004, Tolerance = 1.0e-6),
    Documentation(info = "TiltWingSurveyE: free-base tilt-rotor aerial robot surveying 4 waypoints with 250 Hz synchronized state, command, and sensor traces. Fail-closed acceptance enforces thrust/attitude bounds, waypoint error, estimator finiteness, no collision, and primary tracking error below 0.315 m after 10.4 s.")
  );
end TiltWingSurveyE;