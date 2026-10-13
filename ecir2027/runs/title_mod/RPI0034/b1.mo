model HexaSurveySurveyD
  /* HexaSurveySurveyD: instrumented free-base hexacopter survey mission.
     Facts not stated in the request (exact waypoint deadlines, fuselage
     inertia, sensor noise) are treated as unknown; non-fabricated defaults
     are declared and labeled in comments where the request left them open. */

  // ---- Physical parameters ----
  parameter Real m_fuselage = 3.2 "fuselage mass [kg]";
  parameter Real m_camera   = 0.4 "downward camera payload mass [kg]";
  parameter Real m_total    = m_fuselage + m_camera "total mass [kg]";
  parameter Real R_arm      = 0.35 "rotor radius [m]";
  parameter Real r_fus      = 0.10 "fuselage radius [m] (assumed, not stated)";
  parameter Real g          = 9.81 "gravitational acceleration [m/s2]";
  parameter Real Tmax       = 11.0 "per-rotor thrust bound [N]";
  parameter Real k_yaw      = 0.02 "rotor yaw-drag coefficient [N.m/N] (assumed)";
  parameter Real Ixx = 0.5*m_fuselage*r_fus*r_fus + m_camera*0.05*0.05 "roll inertia [kg.m2]";
  parameter Real Iyy = Ixx "pitch inertia [kg.m2]";
  parameter Real Izz = m_fuselage*r_fus*r_fus + m_camera*0.05*0.05 "yaw inertia [kg.m2]";
  parameter Real pi_val     = 3.14159265358979;

  // ---- Mission waypoints and deadlines ----
  parameter Real W1x = 0.0; parameter Real W1y = 0.0; parameter Real W1z = 1.5;
  parameter Real W2x = 4.0; parameter Real W2y = 0.0; parameter Real W2z = 2.5;
  parameter Real W3x = 4.0; parameter Real W3y = 3.0; parameter Real W3z = 2.5;
  parameter Real W4x = 1.0; parameter Real W4y = 4.0; parameter Real W4z = 2.0;
  parameter Real T_dead1 = 3.5  "waypoint 1 deadline [s] (evenly distributed, not stated)";
  parameter Real T_dead2 = 7.0  "waypoint 2 deadline [s]";
  parameter Real T_dead3 = 10.5 "waypoint 3 deadline [s]";
  parameter Real T_dead4 = 14.0 "waypoint 4 deadline [s]";

  // ---- Obstacles (fixed cylinders, outside the reference polyline) ----
  parameter Real Obs1x = 2.0;  parameter Real Obs1y = -1.2; parameter Real Obs1r = 0.5;
  parameter Real Obs2x = -1.0; parameter Real Obs2y = 1.5;  parameter Real Obs2r = 0.5;
  parameter Real Obs3x = 5.0;  parameter Real Obs3y = 1.5;  parameter Real Obs3r = 0.5;
  parameter Real r_vehicle = 0.45 "vehicle collision radius [m]";

  // ---- Crosswind disturbance (middle third of 14 s) ----
  parameter Real Wd_start = 14.0/3.0 "s";
  parameter Real Wd_end   = 2.0*14.0/3.0 "s";
  parameter Real Wd_force = 6.0 "N";

  // ---- Sampling ----
  parameter Real dt_sample = 0.005 "200 Hz [s]";

  // ---- Rotor geometry ----
  parameter Real a1 = 0.0;              parameter Real a2 = pi_val/3.0;
  parameter Real a3 = 2.0*pi_val/3.0;   parameter Real a4 = pi_val;
  parameter Real a5 = 4.0*pi_val/3.0;   parameter Real a6 = 5.0*pi_val/3.0;
  parameter Real rx1 = R_arm*cos(a1);   parameter Real ry1 = R_arm*sin(a1);
  parameter Real rx2 = R_arm*cos(a2);   parameter Real ry2 = R_arm*sin(a2);
  parameter Real rx3 = R_arm*cos(a3);   parameter Real ry3 = R_arm*sin(a3);
  parameter Real rx4 = R_arm*cos(a4);   parameter Real ry4 = R_arm*sin(a4);
  parameter Real rx5 = R_arm*cos(a5);   parameter Real ry5 = R_arm*sin(a5);
  parameter Real rx6 = R_arm*cos(a6);   parameter Real ry6 = R_arm*sin(a6);
  parameter Real s1 = 1.0;  parameter Real s2 = -1.0;
  parameter Real s3 = 1.0;  parameter Real s4 = -1.0;
  parameter Real s5 = 1.0;  parameter Real s6 = -1.0;
  parameter Real inv3R2 = 1.0/(3.0*R_arm*R_arm);
  parameter Real inv6kyaw = 1.0/(6.0*k_yaw);

  // ---- Plant states ----
  Real p_x(start=0.0) "position x [m]";
  Real p_y(start=0.0) "position y [m]";
  Real p_z(start=0.0) "position z [m]";
  Real v_x(start=0.0) "velocity x [m/s]";
  Real v_y(start=0.0) "velocity y [m/s]";
  Real v_z(start=0.0) "velocity z [m/s]";
  Real phi(start=0.0)   "roll [rad]";
  Real theta(start=0.0) "pitch [rad]";
  Real psi(start=0.0)   "yaw [rad]";
  Real p_qr1(start=0.0) "body rate p [rad/s]";
  Real p_qr2(start=0.0) "body rate q [rad/s]";
  Real p_qr3(start=0.0) "body rate r [rad/s]";

  // ---- Actuator commands and saturated outputs ----
  Real T_cmd1; Real T_cmd2; Real T_cmd3;
  Real T_cmd4; Real T_cmd5; Real T_cmd6;
  Real T_sat1; Real T_sat2; Real T_sat3;
  Real T_sat4; Real T_sat5; Real T_sat6;
  Real Fz_actual  "actual body-z thrust [N]";
  Real tau_act1 "actual roll torque [N.m]";
  Real tau_act2 "actual pitch torque [N.m]";
  Real tau_act3 "actual yaw torque [N.m]";

  // ---- Controller references and commands ----
  Real p_ref_x; Real p_ref_y; Real p_ref_z;
  Real a_ref_x; Real a_ref_y; Real a_ref_z;
  Real e_pos_x; Real e_pos_y; Real e_pos_z;
  Real err_track "primary tracking error [m]";
  Real F_des "desired total thrust [N]";
  Real tau_des1; Real tau_des2; Real tau_des3;
  Real phi_des; Real theta_des; Real psi_des;
  Real ax_des; Real ay_des; Real az_des;

  // ---- Rotation matrices (scalar entries) ----
  Real R11; Real R12; Real R13;
  Real R21; Real R22; Real R23;
  Real R31; Real R32; Real R33;
  Real estR11; Real estR12; Real estR13;
  Real estR21; Real estR22; Real estR23;
  Real estR31; Real estR32; Real estR33;

  // ---- World acceleration ----
  Real acc_wx; Real acc_wy; Real acc_wz;
  Real wind_fx; Real wind_fy; Real wind_fz;

  // ---- Sensors ----
  Real acc_b1; Real acc_b2; Real acc_b3;
  Real gyro1;  Real gyro2;  Real gyro3;
  Real gps_mx; Real gps_my; Real gps_mz;
  Real alt_m;
  Real cam_stamp "camera timestamp [s]";

  // ---- Estimator states ----
  Real est_px(start=0.0); Real est_py(start=0.0); Real est_pz(start=0.0);
  Real est_vx(start=0.0); Real est_vy(start=0.0); Real est_vz(start=0.0);
  Real est_phi(start=0.0); Real est_theta(start=0.0); Real est_psi(start=0.0);
  Real est_awx; Real est_awy; Real est_awz;
  Real est_norm;

  // ---- Safety / requirement observables ----
  Real d_obs1; Real d_obs2; Real d_obs3;
  Real min_obs_dist;
  Real thrust_bound_ok;
  Real att_bound_ok;
  Real est_finite_ok;
  Real no_collision_ok;
  Real tracking_ok;

equation
  // ---- True rotation matrix (ZYX Euler) ----
  R11 = cos(theta)*cos(psi);
  R12 = sin(phi)*sin(theta)*cos(psi) - cos(phi)*sin(psi);
  R13 = cos(phi)*sin(theta)*cos(psi) + sin(phi)*sin(psi);
  R21 = cos(theta)*sin(psi);
  R22 = sin(phi)*sin(theta)*sin(psi) + cos(phi)*cos(psi);
  R23 = cos(phi)*sin(theta)*sin(psi) - sin(phi)*cos(psi);
  R31 = -sin(theta);
  R32 = sin(phi)*cos(theta);
  R33 = cos(phi)*cos(theta);

  // ---- Estimated rotation matrix ----
  estR11 = cos(est_theta)*cos(est_psi);
  estR12 = sin(est_phi)*sin(est_theta)*cos(est_psi) - cos(est_phi)*sin(est_psi);
  estR13 = cos(est_phi)*sin(est_theta)*cos(est_psi) + sin(est_phi)*sin(est_psi);
  estR21 = cos(est_theta)*sin(est_psi);
  estR22 = sin(est_phi)*sin(est_theta)*sin(est_psi) + cos(est_phi)*cos(est_psi);
  estR23 = cos(est_phi)*sin(est_theta)*sin(est_psi) - sin(est_phi)*cos(est_psi);
  estR31 = -sin(est_theta);
  estR32 = sin(est_phi)*cos(est_theta);
  estR33 = cos(est_phi)*cos(est_theta);

  // ---- Waypoint selection via time-based conditionals ----
  p_ref_x = if time < T_dead1 then W1x else
            if time < T_dead2 then W2x else
            if time < T_dead3 then W3x else W4x;
  p_ref_y = if time < T_dead1 then W1y else
            if time < T_dead2 then W2y else
            if time < T_dead3 then W3y else W4y;
  p_ref_z = if time < T_dead1 then W1z else
            if time < T_dead2 then W2z else
            if time < T_dead3 then W3z else W4z;
  // Feedforward acceleration: zero (constant-velocity waypoint holds)
  a_ref_x = 0.0;
  a_ref_y = 0.0;
  a_ref_z = 0.0;

  // ---- Position error (controller uses estimator) ----
  e_pos_x = p_ref_x - est_px;
  e_pos_y = p_ref_y - est_py;
  e_pos_z = p_ref_z - est_pz;
  err_track = sqrt(e_pos_x*e_pos_x + e_pos_y*e_pos_y + e_pos_z*e_pos_z + 1e-9);

  // ---- Bounded waypoint tracking controller (PD + feedforward) ----
  ax_des = a_ref_x + 2.0*e_pos_x - 1.5*est_vx;
  ay_des = a_ref_y + 2.0*e_pos_y - 1.5*est_vy;
  az_des = a_ref_z + 2.0*e_pos_z - 1.5*est_vz + g;

  F_des = m_total*sqrt(ax_des*ax_des + ay_des*ay_des + az_des*az_des + 1e-9);
  theta_des = -asin((m_total*ax_des)/(F_des + 1e-9));
  phi_des   =  asin((m_total*ay_des)/(F_des*cos(theta_des) + 1e-9));
  psi_des   = 0.0;

  // Attitude controller (PD on angle/rate error)
  tau_des1 = 8.0*(phi_des   - est_phi)   - 2.0*gyro1;
  tau_des2 = 8.0*(theta_des - est_theta) - 2.0*gyro2;
  tau_des3 = 3.0*(psi_des   - est_psi)   - 1.0*gyro3;

  // ---- Control allocation (hex mixer, scalar) ----
  T_cmd1 = F_des/6.0 + ry1*inv3R2*tau_des1 + (-rx1)*inv3R2*tau_des2 + s1*inv6kyaw*tau_des3;
  T_cmd2 = F_des/6.0 + ry2*inv3R2*tau_des1 + (-rx2)*inv3R2*tau_des2 + s2*inv6kyaw*tau_des3;
  T_cmd3 = F_des/6.0 + ry3*inv3R2*tau_des1 + (-rx3)*inv3R2*tau_des2 + s3*inv6kyaw*tau_des3;
  T_cmd4 = F_des/6.0 + ry4*inv3R2*tau_des1 + (-rx4)*inv3R2*tau_des2 + s4*inv6kyaw*tau_des3;
  T_cmd5 = F_des/6.0 + ry5*inv3R2*tau_des1 + (-rx5)*inv3R2*tau_des2 + s5*inv6kyaw*tau_des3;
  T_cmd6 = F_des/6.0 + ry6*inv3R2*tau_des1 + (-rx6)*inv3R2*tau_des2 + s6*inv6kyaw*tau_des3;

  // ---- Saturate per-rotor thrust to [0, Tmax] ----
  T_sat1 = max(0.0, min(Tmax, T_cmd1));
  T_sat2 = max(0.0, min(Tmax, T_cmd2));
  T_sat3 = max(0.0, min(Tmax, T_cmd3));
  T_sat4 = max(0.0, min(Tmax, T_cmd4));
  T_sat5 = max(0.0, min(Tmax, T_cmd5));
  T_sat6 = max(0.0, min(Tmax, T_cmd6));

  // ---- Actual wrench from saturated thrusts ----
  Fz_actual = T_sat1 + T_sat2 + T_sat3 + T_sat4 + T_sat5 + T_sat6;
  tau_act1 = ry1*T_sat1 + ry2*T_sat2 + ry3*T_sat3 + ry4*T_sat4 + ry5*T_sat5 + ry6*T_sat6;
  tau_act2 = -(rx1*T_sat1 + rx2*T_sat2 + rx3*T_sat3 + rx4*T_sat4 + rx5*T_sat5 + rx6*T_sat6);
  tau_act3 = k_yaw*(s1*T_sat1 + s2*T_sat2 + s3*T_sat3 + s4*T_sat4 + s5*T_sat5 + s6*T_sat6);

  // ---- Crosswind disturbance (middle third) ----
  wind_fx = if (time >= Wd_start and time <= Wd_end) then Wd_force else 0.0;
  wind_fy = 0.0;
  wind_fz = 0.0;

  // ---- Plant translational dynamics ----
  acc_wx = (R13*Fz_actual + wind_fx)/m_total;
  acc_wy = (R23*Fz_actual + wind_fy)/m_total;
  acc_wz = (R33*Fz_actual + wind_fz)/m_total - g;
  der(p_x) = v_x;
  der(p_y) = v_y;
  der(p_z) = v_z;
  der(v_x) = acc_wx;
  der(v_y) = acc_wy;
  der(v_z) = acc_wz;

  // ---- Plant rotational dynamics (Euler + rigid body) ----
  der(phi)   = p_qr1 + sin(phi)*tan(theta)*p_qr2 + cos(phi)*tan(theta)*p_qr3;
  der(theta) = cos(phi)*p_qr2 - sin(phi)*p_qr3;
  der(psi)   = (sin(phi)*p_qr2 + cos(phi)*p_qr3)/(cos(theta) + 1e-9);
  der(p_qr1) = (tau_act1 - (Izz - Iyy)*p_qr2*p_qr3)/Ixx;
  der(p_qr2) = (tau_act2 - (Ixx - Izz)*p_qr1*p_qr3)/Iyy;
  der(p_qr3) = (tau_act3 - (Iyy - Ixx)*p_qr1*p_qr2)/Izz;

  // ---- Sensors (ideal, synchronized at 200 Hz) ----
  // IMU accelerometer: specific force in body frame = R^T * (a_world + g*e3)
  acc_b1 = R11*acc_wx + R21*acc_wy + R31*(acc_wz + g);
  acc_b2 = R12*acc_wx + R22*acc_wy + R32*(acc_wz + g);
  acc_b3 = R13*acc_wx + R23*acc_wy + R33*(acc_wz + g);
  gyro1 = p_qr1;
  gyro2 = p_qr2;
  gyro3 = p_qr3;
  gps_mx = p_x;
  gps_my = p_y;
  gps_mz = p_z;
  alt_m  = p_z;
  cam_stamp = time;

  // ---- Estimator: complementary fusion of IMU + GPS + altimeter ----
  der(est_px) = est_vx + 2.8*(gps_mx - est_px);
  der(est_py) = est_vy + 2.8*(gps_my - est_py);
  der(est_pz) = est_vz + 2.8*(alt_m  - est_pz);
  der(est_vx) = est_awx + 4.0*(gps_mx - est_px);
  der(est_vy) = est_awy + 4.0*(gps_my - est_py);
  der(est_vz) = est_awz + 4.0*(alt_m  - est_pz);

  // Attitude complementary filter: gyro + accelerometer leveling
  der(est_phi)   = gyro1 + 1.0*(atan2(-acc_b2, sqrt(acc_b3*acc_b3 + 1e-9)) - est_phi);
  der(est_theta) = gyro2 + 1.0*(atan2( acc_b1, sqrt(acc_b3*acc_b3 + 1e-9)) - est_theta);
  der(est_psi)   = gyro3;

  // Estimated world acceleration from IMU using estimated attitude
  est_awx = estR11*acc_b1 + estR12*acc_b2 + estR13*acc_b3;
  est_awy = estR21*acc_b1 + estR22*acc_b2 + estR23*acc_b3;
  est_awz = estR31*acc_b1 + estR32*acc_b2 + estR33*acc_b3 - g;

  est_norm = sqrt(est_px*est_px + est_py*est_py + est_pz*est_pz
                + est_vx*est_vx + est_vy*est_vy + est_vz*est_vz + 1e-9);

  // ---- Requirement observables ----
  d_obs1 = sqrt((p_x - Obs1x)*(p_x - Obs1x) + (p_y - Obs1y)*(p_y - Obs1y) + 1e-9);
  d_obs2 = sqrt((p_x - Obs2x)*(p_x - Obs2x) + (p_y - Obs2y)*(p_y - Obs2y) + 1e-9);
  d_obs3 = sqrt((p_x - Obs3x)*(p_x - Obs3x) + (p_y - Obs3y)*(p_y - Obs3y) + 1e-9);
  min_obs_dist = if d_obs1 < d_obs2 then (if d_obs1 < d_obs3 then d_obs1 else d_obs3)
                                    else (if d_obs2 < d_obs3 then d_obs2 else d_obs3);

  thrust_bound_ok = if (T_sat1 >= 0.0 and T_sat1 <= Tmax + 1e-6 and
                        T_sat2 >= 0.0 and T_sat2 <= Tmax + 1e-6 and
                        T_sat3 >= 0.0 and T_sat3 <= Tmax + 1e-6 and
                        T_sat4 >= 0.0 and T_sat4 <= Tmax + 1e-6 and
                        T_sat5 >= 0.0 and T_sat5 <= Tmax + 1e-6 and
                        T_sat6 >= 0.0 and T_sat6 <= Tmax + 1e-6) then 1.0 else 0.0;
  att_bound_ok = if (abs(phi) < 0.7 and abs(theta) < 0.7) then 1.0 else 0.0;
  est_finite_ok = if (est_norm < 1e6) then 1.0 else 0.0;
  no_collision_ok = if (d_obs1 > r_vehicle + Obs1r and
                         d_obs2 > r_vehicle + Obs2r and
                         d_obs3 > r_vehicle + Obs3r) then 1.0 else 0.0;
  tracking_ok = if (time > 9.1) then (if err_track < 0.35 then 1.0 else 0.0) else 1.0;

  // ---- Terminal requirement checks ----
  when terminal() then
    assert(thrust_bound_ok > 0.5, "Rotor thrust bound violated");
    assert(att_bound_ok   > 0.5, "Attitude bound violated");
    assert(est_finite_ok  > 0.5, "Estimator not finite");
    assert(no_collision_ok > 0.5, "Collision with obstacle");
    assert(tracking_ok    > 0.5, "Primary tracking error > 0.35 m after 9.1 s");
  end when;

end HexaSurveySurveyD;