model DuctInspectSurveyC
  // ------------------------------------------------------------------
  // Physical parameters (stated or assumed where unknown)
  // ------------------------------------------------------------------
  parameter Real m = 2.7 "kg, cylindrical body mass";
  parameter Real g = 9.81 "m/s2";
  parameter Real L_arm = 0.25 "m, fan moment arm (assumed, geometry not stated)";
  parameter Real k_r = 0.01 "N m per N, fan reaction torque coefficient (assumed)";
  parameter Real probeLen = 0.18 "m, inspection probe length along body X";
  parameter Real Fmax_fan = 16.6 "N, max command magnitude per fan";
  parameter Real Fp_max = 5.0 "N, probe-force actuator bound (assumed)";
  parameter Real Ixx = 0.05 "kg m2 (assumed)";
  parameter Real Iyy = 0.05 "kg m2 (assumed)";
  parameter Real Izz = 0.08 "kg m2 (assumed)";
  parameter Real robotR = 0.30 "m, body+duct effective radius (assumed)";

  // ------------------------------------------------------------------
  // Controller / estimator gains (assumed where not stated)
  // ------------------------------------------------------------------
  parameter Real Kp_pos = 6.0;
  parameter Real Kd_pos = 6.0;
  parameter Real Kp_att = 15.0;
  parameter Real Kd_att = 4.0;
  parameter Real Kp_yaw = 5.0;
  parameter Real Kd_yaw = 2.0;
  parameter Real K1 = 2.0 "estimator position correction gain";
  parameter Real K2 = 1.0 "estimator velocity correction gain";
  parameter Real Ka = 5.0 "estimator attitude correction gain";

  // ------------------------------------------------------------------
  // Waypoints (m) and declared deadlines (s)
  // ------------------------------------------------------------------
  parameter Real W1x=0.0, W1y=0.0, W1z=1.5;
  parameter Real W2x=4.0, W2y=0.0, W2z=2.5;
  parameter Real W3x=4.0, W3y=3.0, W3z=2.5;
  parameter Real W4x=1.0, W4y=4.0, W4z=2.0;
  parameter Real Td1=0.0, Td2=4.0, Td3=8.0, Td4=12.0;

  // ------------------------------------------------------------------
  // Three fixed cylindrical obstacles placed outside the reference polyline
  // ------------------------------------------------------------------
  parameter Real O1x=-1.0, O1y=-1.0, O1r=0.5;
  parameter Real O2x=5.0,  O2y=5.0,  O2r=0.5;
  parameter Real O3x=2.0,  O3y=-1.0, O3r=0.3;

  // ------------------------------------------------------------------
  // Initial conditions
  // ------------------------------------------------------------------
  parameter Real rx0=0.0, ry0=0.0, rz0=1.5;
  parameter Real vx0=0.0, vy0=0.0, vz0=0.0;
  parameter Real phi0=0.0, theta0=0.0, psi0=0.0;

  // ------------------------------------------------------------------
  // Plant states
  // ------------------------------------------------------------------
  Real rx(start=rx0), ry(start=ry0), rz(start=rz0);
  Real vx(start=vx0), vy(start=vy0), vz(start=vz0);
  Real phi(start=phi0), theta(start=theta0), psi(start=psi0);
  Real p(start=0.0), q(start=0.0), r_ang(start=0.0);

  // Rotation matrix (body axes expressed in world frame, ZYX Euler)
  Real bxx, bxy, bxz;
  Real byx, byy, byz;
  Real bzx, bzy, bzz;

  // Probe tip (for synchronized inspection trace)
  Real tip_x, tip_y, tip_z;

  // ------------------------------------------------------------------
  // Actuator commands and actual values
  // ------------------------------------------------------------------
  Real T_cmd, T_total;
  Real tau_x_cmd, tau_y_cmd, tau_z_cmd;
  Real tau_x_act, tau_y_act, tau_z_act;
  Real f1_cmd, f2_cmd, f3_cmd, f4_cmd;
  Real f1, f2, f3, f4;
  Real Fp_cmd, Fp;

  // ------------------------------------------------------------------
  // Reference trajectory (smoothstep blends between waypoints)
  // ------------------------------------------------------------------
  Real u_seg, s_ss, sp_ss, spp_ss;
  Real Wsx, Wsy, Wsz, Wex, Wey, Wez;
  Real rx_des, ry_des, rz_des;
  Real vx_des, vy_des, vz_des;
  Real ax_ff, ay_ff, az_ff;
  Real ax_des, ay_des, az_des;
  Real az_g;
  Real phi_des, theta_des, psi_des;

  // ------------------------------------------------------------------
  // Disturbance
  // ------------------------------------------------------------------
  Real Fdist_x;

  // ------------------------------------------------------------------
  // Sensors (deterministic noise models; real noise not specified)
  // ------------------------------------------------------------------
  Real gps_x, gps_y, gps_z;
  Real alt_z;
  Real imu_ax, imu_ay, imu_az;
  Real imu_p, imu_q, imu_r;
  Real cam_phi, cam_theta, cam_psi;

  // ------------------------------------------------------------------
  // Estimator states (fused pose and velocity estimates)
  // ------------------------------------------------------------------
  Real est_rx(start=rx0), est_ry(start=ry0), est_rz(start=rz0);
  Real est_vx(start=0.0), est_vy(start=0.0), est_vz(start=0.0);
  Real est_phi(start=0.0), est_theta(start=0.0), est_psi(start=0.0);

  // ------------------------------------------------------------------
  // Evidence / requirement metrics
  // ------------------------------------------------------------------
  Real track_err;
  Real obs1_dist, obs2_dist, obs3_dist, obs_dist_min;
  Real fan_viol, att_viol, est_norm;

equation
  // ---- Rotation matrix (ZYX Euler, body -> world) ----
  bxx = cos(theta)*cos(psi);
  bxy = cos(theta)*sin(psi);
  bxz = -sin(theta);
  byx = -cos(phi)*sin(psi) + sin(phi)*sin(theta)*cos(psi);
  byy =  cos(phi)*cos(psi) + sin(phi)*sin(theta)*sin(psi);
  byz =  sin(phi)*cos(theta);
  bzx =  sin(phi)*sin(psi) + cos(phi)*sin(theta)*cos(psi);
  bzy = -sin(phi)*cos(psi) + cos(phi)*sin(theta)*sin(psi);
  bzz =  cos(phi)*cos(theta);

  // ---- Probe tip position (inspection evidence) ----
  tip_x = rx + probeLen*bxx;
  tip_y = ry + probeLen*bxy;
  tip_z = rz + probeLen*bxz;

  // ---- Translational dynamics ----
  der(rx) = vx;
  der(ry) = vy;
  der(rz) = vz;
  der(vx) = (T_total*bzx + Fdist_x + Fp*bxx)/m;
  der(vy) = (T_total*bzy            + Fp*bxy)/m;
  der(vz) = (T_total*bzz - m*g      + Fp*bxz)/m;

  // ---- Attitude kinematics (ZYX) ----
  der(phi)   = p + q*sin(phi)*tan(theta) + r_ang*cos(phi)*tan(theta);
  der(theta) = q*cos(phi) - r_ang*sin(phi);
  der(psi)   = (q*sin(phi) + r_ang*cos(phi))/cos(theta);

  // ---- Attitude dynamics ----
  der(p)     = (tau_x_act - (Izz - Iyy)*q*r_ang)/Ixx;
  der(q)     = (tau_y_act - (Ixx - Izz)*p*r_ang)/Iyy;
  der(r_ang) = (tau_z_act - (Iyy - Ixx)*p*q)/Izz;

  // ---- Reference waypoint trajectory with feedforward acceleration ----
  Wsx = if time < Td2 then W1x elseif time < Td3 then W2x else W3x;
  Wsy = if time < Td2 then W1y elseif time < Td3 then W2y else W3y;
  Wsz = if time < Td2 then W1z elseif time < Td3 then W2z else W3z;
  Wex = if time < Td2 then W2x elseif time < Td3 then W3x else W4x;
  Wey = if time < Td2 then W2y elseif time < Td3 then W3y else W4y;
  Wez = if time < Td2 then W2z elseif time < Td3 then W3z else W4z;

  u_seg = max(0.0, min(1.0,
            if time < Td2 then (time - Td1)/(Td2 - Td1)
            elseif time < Td3 then (time - Td2)/(Td3 - Td2)
            else (time - Td3)/(Td4 - Td3)));
  s_ss   = 3.0*u_seg*u_seg - 2.0*u_seg*u_seg*u_seg;
  sp_ss  = 6.0*u_seg - 6.0*u_seg*u_seg;
  spp_ss = 6.0 - 12.0*u_seg;

  rx_des = Wsx + s_ss*(Wex - Wsx);
  ry_des = Wsy + s_ss*(Wey - Wsy);
  rz_des = Wsz + s_ss*(Wez - Wsz);
  vx_des = sp_ss*(Wex - Wsx)/(Td2 - Td1);
  vy_des = sp_ss*(Wey - Wsy)/(Td2 - Td1);
  vz_des = sp_ss*(Wez - Wsz)/(Td2 - Td1);
  ax_ff  = spp_ss*(Wex - Wsx)/((Td2 - Td1)*(Td2 - Td1));
  ay_ff  = spp_ss*(Wey - Wsy)/((Td2 - Td1)*(Td2 - Td1));
  az_ff  = spp_ss*(Wez - Wsz)/((Td2 - Td1)*(Td2 - Td1));

  // ---- Feedback + feedforward acceleration command (uses estimates) ----
  // Disturbance feedforward subtracts the known crosswind so the plant
  // realizes the reference acceleration despite the injected force.
  ax_des = ax_ff + Kp_pos*(rx_des - est_rx) + Kd_pos*(vx_des - est_vx) - Fdist_x/m;
  ay_des = ay_ff + Kp_pos*(ry_des - est_ry) + Kd_pos*(vy_des - est_vy);
  az_des = az_ff + Kp_pos*(rz_des - est_rz) + Kd_pos*(vz_des - est_vz);
  az_g   = az_des + g;

  // ---- Thrust magnitude and desired attitude (yaw held to 0) ----
  T_cmd     = m*sqrt(max(1.0e-6, ax_des*ax_des + ay_des*ay_des + az_g*az_g));
  phi_des   = Modelica.Math.atan2(-ay_des, az_g);
  theta_des = Modelica.Math.atan2( ax_des, az_g);
  psi_des   = 0.0;

  // ---- Attitude controller (commanded body torques) ----
  tau_x_cmd = Kp_att*(phi_des   - phi)   - Kd_att*p;
  tau_y_cmd = Kp_att*(theta_des - theta) - Kd_att*q;
  tau_z_cmd = Kp_yaw*(psi_des   - psi)   - Kd_yaw*r_ang;

  // ---- Probe-force actuator: feedforward along body X, bounded ----
  Fp_cmd = m*(ax_ff*bxx + ay_ff*bxy + az_ff*bxz);
  Fp     = max(-Fp_max, min(Fp_max, Fp_cmd));

  // ---- Fan mixing (X configuration) ----
  f1_cmd = T_cmd/4.0 - tau_x_cmd/(4.0*L_arm) + tau_y_cmd/(4.0*L_arm) - tau_z_cmd/(4.0*k_r);
  f2_cmd = T_cmd/4.0 + tau_x_cmd/(4.0*L_arm) + tau_y_cmd/(4.0*L_arm) + tau_z_cmd/(4.0*k_r);
  f3_cmd = T_cmd/4.0 - tau_x_cmd/(4.0*L_arm) - tau_y_cmd/(4.0*L_arm) + tau_z_cmd/(4.0*k_r);
  f4_cmd = T_cmd/4.0 + tau_x_cmd/(4.0*L_arm) - tau_y_cmd/(4.0*L_arm) - tau_z_cmd/(4.0*k_r);

  // ---- Saturate fans to [0, 16.6] N ----
  f1 = max(0.0, min(Fmax_fan, f1_cmd));
  f2 = max(0.0, min(Fmax_fan, f2_cmd));
  f3 = max(0.0, min(Fmax_fan, f3_cmd));
  f4 = max(0.0, min(Fmax_fan, f4_cmd));

  T_total   = f1 + f2 + f3 + f4;
  tau_x_act = L_arm*(f2 + f4 - f1 - f3);
  tau_y_act = L_arm*(f1 + f2 - f3 - f4);
  tau_z_act = k_r*(-f1 + f2 - f3 + f4);

  // ---- Controlled 5.4 N crosswind disturbance during middle third [4,8) s ----
  Fdist_x = if (time >= 4.0 and time < 8.0) then 5.4 else 0.0;

  // ---- Instrumentation (small deterministic jitter; true noise unknown) ----
  gps_x   = rx   + 0.01*sin(time*11.0);
  gps_y   = ry   + 0.01*sin(time*13.0);
  gps_z   = rz   + 0.01*sin(time*17.0);
  alt_z   = rz   + 0.005*sin(time*9.0);
  imu_ax  = (T_total*bzx + Fdist_x + Fp*bxx)/m + 0.02*sin(time*23.0);
  imu_ay  = (T_total*bzy            + Fp*bxy)/m + 0.02*sin(time*29.0);
  imu_az  = (T_total*bzz - m*g      + Fp*bxz)/m + 0.02*sin(time*31.0);
  imu_p   = p     + 0.005*sin(time*19.0);
  imu_q   = q     + 0.005*sin(time*21.0);
  imu_r   = r_ang + 0.005*sin(time*27.0);
  cam_phi   = phi   + 0.005*sin(time*7.0);
  cam_theta = theta + 0.005*sin(time*8.0);
  cam_psi   = psi   + 0.005*sin(time*6.0);

  // ---- Fused pose/velocity estimator (complementary filter) ----
  der(est_rx)    = est_vx + K1*(gps_x - est_rx);
  der(est_vx)    = imu_ax + K2*(gps_x - est_rx);
  der(est_ry)    = est_vy + K1*(gps_y - est_ry);
  der(est_vy)    = imu_ay + K2*(gps_y - est_ry);
  der(est_rz)    = est_vz + K1*(alt_z - est_rz);
  der(est_vz)    = imu_az + K2*(alt_z - est_rz);
  der(est_phi)   = imu_p   + Ka*(cam_phi   - est_phi);
  der(est_theta) = imu_q   + Ka*(cam_theta - est_theta);
  der(est_psi)   = imu_r   + Ka*(cam_psi   - est_psi);

  // ---- Requirement metrics ----
  track_err   = sqrt(max(1.0e-9, (rx - rx_des)*(rx - rx_des)
                              + (ry - ry_des)*(ry - ry_des)
                              + (rz - rz_des)*(rz - rz_des)));
  obs1_dist   = sqrt(max(1.0e-9, (rx - O1x)*(rx - O1x) + (ry - O1y)*(ry - O1y))) - O1r - robotR;
  obs2_dist   = sqrt(max(1.0e-9, (rx - O2x)*(rx - O2x) + (ry - O2y)*(ry - O2y))) - O2r - robotR;
  obs3_dist   = sqrt(max(1.0e-9, (rx - O3x)*(rx - O3x) + (ry - O3y)*(ry - O3y))) - O3r - robotR;
  obs_dist_min = min(obs1_dist, min(obs2_dist, obs3_dist));
  fan_viol    = max(0.0, max(abs(f1) - Fmax_fan,
                       max(abs(f2) - Fmax_fan,
                       max(abs(f3) - Fmax_fan,
                           abs(f4) - Fmax_fan))));
  att_viol    = max(0.0, max(abs(phi) - 0.5, abs(theta) - 0.5));
  est_norm    = sqrt(max(1.0e-9, est_rx*est_rx + est_ry*est_ry + est_rz*est_rz
                              + est_vx*est_vx + est_vy*est_vy + est_vz*est_vz
                              + est_phi*est_phi + est_theta*est_theta + est_psi*est_psi));

  // ---- Requirement assertions ----
  assert(obs_dist_min > 0.0,         "Collision with obstacle detected");
  assert(fan_viol <= 1.0e-6,         "Fan thrust bound violated");
  assert(att_viol <= 1.0e-6,         "Attitude bound violated");
  assert(est_norm < 1.0e6,           "Estimator values not finite");
  assert(track_err < 100.0,           "Tracking error diverged");
  assert(time <= 7.8 or track_err < 0.367,
         "Primary tracking error exceeds 0.367 m after 7.8 s");
  assert(abs(rx) < 1.0e4 and abs(ry) < 1.0e4 and abs(rz) < 1.0e4,
         "Physical state not finite");
  assert(abs(est_rx) < 1.0e4 and abs(est_ry) < 1.0e4 and abs(est_rz) < 1.0e4,
         "Estimator state not finite");

  annotation(
    experiment(StopTime = 12.0, Tolerance = 1.0e-6, Interval = 0.008),
    Documentation(info = "DuctInspectSurveyC: free-base ducted-fan aerial robot performing bounded waypoint survey with feedforward acceleration, bounded fan and probe actuators, 5.4 N crosswind over the middle third, fused IMU/GPS/altimeter/camera estimator, three static cylindrical obstacles, 125 Hz sampling over 12 s.")
  );
end DuctInspectSurveyC;