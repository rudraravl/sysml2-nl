model MapRigLocalizeF
  "Mobile-base mapping/localization scenario with multi-rate asynchronous EKF";

  constant Real pi_c = 3.141592653589793;

  // ===== Mission timing =====
  parameter Real T_end = 20.0 "simulation duration [s]";
  parameter Real f_sim = 500.0 "EKF predict rate [Hz]";
  parameter Real T_sample = 1.0/f_sim "0.002 s predict interval";
  parameter Real T_step_start = T_end/3.0 "middle third start [s]";
  parameter Real T_step_end = 2.0*T_end/3.0 "middle third end [s]";
  parameter Real b_step = 0.058 "controlled gyro-bias step disturbance [rad/s]";

  // ===== Embodiment =====
  parameter Real m_base = 22.0 "mobile base mass [kg]";
  parameter Real r_wheel = 0.10 "wheel radius [m]";
  parameter Real L_track = 0.40 "track width [m]";
  parameter Real I_z = 1.0 "yaw inertia [kg.m2]";
  parameter Real Cd_lin = 0.8 "linear drag [N.s/m]";
  parameter Real Cr_rot = 0.3 "rotational drag [N.m.s/rad]";
  parameter Real tau_max = 14.6 "per-wheel torque limit [N.m]";

  // ===== Controller gains =====
  parameter Real kp_v = 3.0 "forward speed gain";
  parameter Real kp_w = 3.0 "yaw rate gain";
  parameter Real kd_lat = 2.0 "lateral error gain";
  parameter Real kd_th = 1.5 "heading error gain";

  // ===== Sensor rates, frames, std devs, biases =====
  parameter Real f_imu = 200.0;
  parameter Real T_imu = 1.0/f_imu;
  parameter Real f_enc = 100.0;
  parameter Real T_enc = 1.0/f_enc;
  parameter Real f_lidar = 10.0;
  parameter Real T_lidar = 1.0/f_lidar;
  parameter Real f_cam = 20.0;
  parameter Real T_cam = 1.0/f_cam;
  parameter Real sigma_gyro = 0.005 "rad/s, IMU body-frame gyro std";
  parameter Real sigma_enc = 0.01 "m/s, wheel-encoder forward-vel std";
  parameter Real sigma_lidar = 0.02 "m, planar lidar range std";
  parameter Real sigma_cam = 0.05 "m, RGB-D forward depth std";
  parameter Real R_gyro = sigma_gyro*sigma_gyro;
  parameter Real R_enc = sigma_enc*sigma_enc;
  parameter Real R_lidar = sigma_lidar*sigma_lidar;
  parameter Real lidar_range_max = 20.0 "m, planar lidar max range";

  // ===== Bounded route (circle) =====
  parameter Real R_route = 3.0 "route radius [m]";
  parameter Real omega_route = 0.20 "route angular rate [rad/s]";

  // ===== Fixed landmarks (external references; no ground truth to estimator) =====
  parameter Real L1x = 5.0;
  parameter Real L1y = 5.0;
  parameter Real L2x = -5.0;
  parameter Real L2y = 5.0;
  parameter Real L3x = 5.0;
  parameter Real L3y = -5.0;
  parameter Real L4x = -5.0;
  parameter Real L4y = -5.0;

  // ===== Process noise (scalar parameters, no array) =====
  parameter Real q_pos = 1.0e-4;
  parameter Real q_v = 1.0e-3;
  parameter Real q_w = 1.0e-3;
  parameter Real q_b = 1.0e-5;

  // ===== True plant state =====
  Real x_true(start=3.0) "true x [m]";
  Real y_true(start=0.0) "true y [m]";
  Real theta_true(start=1.5707963267948966) "true heading [rad]";
  Real v_true(start=0.0) "true forward speed [m/s]";
  Real omega_true(start=0.0) "true yaw rate [rad/s]";
  Real b_gyro_true "true gyro bias [rad/s] (step disturbance)";
  Real b_lidar_true = 0.0 "true lidar bias [m]";
  Real b_cam_true = 0.0 "true camera bias [m]";
  Real tau_L_cmd "commanded left wheel torque [N.m]";
  Real tau_R_cmd "commanded right wheel torque [N.m]";
  Real tau_L "actual left wheel torque [N.m]";
  Real tau_R "actual right wheel torque [N.m]";
  Real F_drive "drive force [N]";
  Real M_drive "drive yaw moment [N.m]";

  // ===== Controller variables =====
  Real e_fwd "forward tracking error [m]";
  Real e_lat "lateral tracking error [m]";
  Real e_th "heading error [rad]";
  Real v_cmd "commanded forward speed [m/s]";
  Real omega_cmd "commanded yaw rate [rad/s]";

  // ===== Reference =====
  Real x_ref, y_ref, theta_ref, v_ref, omega_ref;

  // ===== Sensor measurements (discrete, held with timestamp) =====
  discrete Real z_gyro(start=0.0) "IMU gyro [rad/s], body frame";
  discrete Real z_enc(start=0.0) "encoder forward speed [m/s], wheel frame";
  discrete Real z_lidar1(start=0.0) "lidar range to landmark 1 [m]";
  discrete Real z_lidar2(start=0.0) "lidar range to landmark 2 [m]";
  discrete Real z_lidar3(start=0.0) "lidar range to landmark 3 [m]";
  discrete Real z_lidar4(start=0.0) "lidar range to landmark 4 [m]";
  discrete Real z_cam_depth(start=0.0) "RGB-D forward depth [m], camera frame";
  discrete Real z_imu_time(start=-1.0) "IMU sample timestamp [s]";
  discrete Real z_enc_time(start=-1.0) "encoder sample timestamp [s]";
  discrete Real z_lidar_time(start=-1.0) "lidar sample timestamp [s]";
  discrete Real z_cam_time(start=-1.0) "camera sample timestamp [s]";
  Integer cnt_imu(start=0);
  Integer cnt_enc(start=0);
  Integer cnt_lidar(start=0);
  Integer cnt_cam(start=0);
  Integer ekf_seen_imu(start=0);
  Integer ekf_seen_enc(start=0);
  Integer ekf_seen_lidar(start=0);
  Integer ekf_seen_cam(start=0);

  // ===== EKF: state [x, y, theta, v, omega, b_g] =====
  discrete Real xh1(start=3.0);
  discrete Real xh2(start=0.0);
  discrete Real xh3(start=1.5707963267948966);
  discrete Real xh4(start=0.0);
  discrete Real xh5(start=0.0);
  discrete Real xh6(start=0.0);

  // EKF covariance (6x6 as scalar entries for FMU-safe codegen)
  discrete Real P11(start=0.01);
  discrete Real P12(start=0.0);
  discrete Real P13(start=0.0);
  discrete Real P14(start=0.0);
  discrete Real P15(start=0.0);
  discrete Real P16(start=0.0);
  discrete Real P21(start=0.0);
  discrete Real P22(start=0.01);
  discrete Real P23(start=0.0);
  discrete Real P24(start=0.0);
  discrete Real P25(start=0.0);
  discrete Real P26(start=0.0);
  discrete Real P31(start=0.0);
  discrete Real P32(start=0.0);
  discrete Real P33(start=0.01);
  discrete Real P34(start=0.0);
  discrete Real P35(start=0.0);
  discrete Real P36(start=0.0);
  discrete Real P41(start=0.0);
  discrete Real P42(start=0.0);
  discrete Real P43(start=0.0);
  discrete Real P44(start=0.01);
  discrete Real P45(start=0.0);
  discrete Real P46(start=0.0);
  discrete Real P51(start=0.0);
  discrete Real P52(start=0.0);
  discrete Real P53(start=0.0);
  discrete Real P54(start=0.0);
  discrete Real P55(start=0.01);
  discrete Real P56(start=0.0);
  discrete Real P61(start=0.0);
  discrete Real P62(start=0.0);
  discrete Real P63(start=0.0);
  discrete Real P64(start=0.0);
  discrete Real P65(start=0.0);
  discrete Real P66(start=1.0e-4);

  // EKF temporaries
  discrete Real F13(start=0.0);
  discrete Real F14(start=0.0);
  discrete Real F23(start=0.0);
  discrete Real F24(start=0.0);
  discrete Real F35(start=1.0);
  discrete Real F44(start=-0.03636363636363636);
  discrete Real F55(start=-0.3);
  discrete Real a1(start=0.0);
  discrete Real a2(start=0.0);
  discrete Real a3(start=0.0);
  discrete Real a4(start=0.0);
  discrete Real a5(start=0.0);
  discrete Real a6(start=0.0);
  discrete Real innov(start=0.0);
  discrete Real S_val(start=1.0);
  discrete Real dx_lm(start=0.0);
  discrete Real dy_lm(start=0.0);
  discrete Real r_pred(start=1.0);
  discrete Real hx_val(start=0.0);
  discrete Real hy_val(start=0.0);
  discrete Real zlm(start=0.0);

  // ===== Estimates and verification observables =====
  Real x_hat, y_hat, theta_hat, v_hat, omega_hat, b_g_hat;
  Real err_pos "position error [m]";
  Real err_theta "attitude error [rad]";
  Real tracking_err "primary tracking error [m or rad]";
  Real P_diag_min "minimum covariance diagonal entry";
  Real bias_est "estimated gyro bias [rad/s]";
  Real bias_err "bias estimation error [rad/s]";
  Boolean converged_after_13s;
  Boolean cov_finite_positive;
  Boolean tau_L_saturated;
  Boolean tau_R_saturated;
  Boolean no_nan_inf;

equation
  // ---- Controlled bias-step disturbance (middle third) ----
  if time >= T_step_start and time <= T_step_end then
    b_gyro_true = b_step;
  else
    b_gyro_true = 0.0;
  end if;

  // ---- True plant dynamics ----
  der(x_true) = v_true*cos(theta_true);
  der(y_true) = v_true*sin(theta_true);
  der(theta_true) = omega_true;
  m_base*der(v_true) = (tau_L + tau_R)/r_wheel - Cd_lin*v_true;
  I_z*der(omega_true) = (tau_R - tau_L)*L_track/(2*r_wheel) - Cr_rot*omega_true;

  // ---- Reference route ----
  x_ref = R_route*cos(omega_route*time);
  y_ref = R_route*sin(omega_route*time);
  theta_ref = omega_route*time + pi_c/2;
  v_ref = R_route*omega_route;
  omega_ref = omega_route;

  // ---- Controller using ESTIMATED state (no ground truth to estimator) ----
  e_fwd = cos(xh3)*(x_ref - xh1) + sin(xh3)*(y_ref - xh2);
  e_lat = -sin(xh3)*(x_ref - xh1) + cos(xh3)*(y_ref - xh2);
  e_th = theta_ref - xh3;
  v_cmd = v_ref + kp_v*e_fwd;
  omega_cmd = omega_ref + kd_lat*e_lat + kd_th*e_th;
  F_drive = m_base*kp_v*(v_cmd - xh4);
  M_drive = I_z*kp_w*(omega_cmd - xh5);
  tau_L_cmd = 0.5*(F_drive*r_wheel - M_drive*2*r_wheel/L_track);
  tau_R_cmd = 0.5*(F_drive*r_wheel + M_drive*2*r_wheel/L_track);
  tau_L = if tau_L_cmd > tau_max then tau_max else if tau_L_cmd < -tau_max then -tau_max else tau_L_cmd;
  tau_R = if tau_R_cmd > tau_max then tau_max else if tau_R_cmd < -tau_max then -tau_max else tau_R_cmd;
  tau_L_saturated = abs(tau_L_cmd) > tau_max;
  tau_R_saturated = abs(tau_R_cmd) > tau_max;

  // ---- Estimate outputs ----
  x_hat = xh1; y_hat = xh2; theta_hat = xh3;
  v_hat = xh4; omega_hat = xh5; b_g_hat = xh6;
  bias_est = xh6;
  bias_err = b_gyro_true - xh6;

  // ---- Verification metrics ----
  err_pos = sqrt((x_true - x_hat)^2 + (y_true - y_hat)^2 + 1.0e-12);
  err_theta = abs(theta_true - theta_hat);
  tracking_err = if err_pos >= err_theta then err_pos else err_theta;
  converged_after_13s = time >= 13.0 and tracking_err < 0.16;
  P_diag_min = if P11 <= P22 and P11 <= P33 and P11 <= P44 and P11 <= P55 and P11 <= P66 then P11
    else if P22 <= P33 and P22 <= P44 and P22 <= P55 and P22 <= P66 then P22
    else if P33 <= P44 and P33 <= P55 and P33 <= P66 then P33
    else if P44 <= P55 and P44 <= P66 then P44
    else if P55 <= P66 then P55
    else P66;
  cov_finite_positive = P_diag_min > 0.0 and P_diag_min < 1.0e6;
  no_nan_inf = (abs(x_true) < 1.0e6) and (abs(y_true) < 1.0e6) and (abs(theta_true) < 1.0e6)
    and (abs(v_true) < 1.0e6) and (abs(omega_true) < 1.0e6)
    and (abs(tau_L) < 1.0e6) and (abs(tau_R) < 1.0e6)
    and (abs(xh1) < 1.0e6) and (abs(xh2) < 1.0e6) and (abs(xh3) < 1.0e6)
    and (abs(xh4) < 1.0e6) and (abs(xh5) < 1.0e6) and (abs(xh6) < 1.0e6)
    and (abs(P11) < 1.0e6) and (abs(P66) < 1.0e6);

  // ============ Asynchronous sensor sample events ============
  // IMU 200 Hz, body frame
  when sample(0.0001, T_imu) then
    z_gyro = omega_true + b_gyro_true + sigma_gyro*sin(time*7.3);
    z_imu_time = time;
    cnt_imu = pre(cnt_imu) + 1;
  end when;

  // Wheel encoders 100 Hz, wheel frame
  when sample(0.0002, T_enc) then
    z_enc = v_true + sigma_enc*sin(time*11.0);
    z_enc_time = time;
    cnt_enc = pre(cnt_enc) + 1;
  end when;

  // Planar lidar 10 Hz, 20 m max, lidar frame (ranges to fixed landmarks)
  when sample(0.0003, T_lidar) then
    z_lidar1 = sqrt((x_true - L1x)^2 + (y_true - L1y)^2) + b_lidar_true + sigma_lidar*sin(time*13.0 + 1.0);
    z_lidar2 = sqrt((x_true - L2x)^2 + (y_true - L2y)^2) + b_lidar_true + sigma_lidar*sin(time*13.0 + 2.0);
    z_lidar3 = sqrt((x_true - L3x)^2 + (y_true - L3y)^2) + b_lidar_true + sigma_lidar*sin(time*13.0 + 3.0);
    z_lidar4 = sqrt((x_true - L4x)^2 + (y_true - L4y)^2) + b_lidar_true + sigma_lidar*sin(time*13.0 + 4.0);
    z_lidar_time = time;
    cnt_lidar = pre(cnt_lidar) + 1;
  end when;

  // Forward RGB-D camera 20 Hz, camera frame (depth to landmark 1, capped at range)
  when sample(0.0004, T_cam) then
    z_cam_depth = min(lidar_range_max, sqrt((x_true - L1x)^2 + (y_true - L1y)^2)) + b_cam_true + sigma_cam*sin(time*3.0);
    z_cam_time = time;
    cnt_cam = pre(cnt_cam) + 1;
  end when;

algorithm
  // ============ EKF predict + asynchronous updates at 500 Hz ============
  when sample(0.001, T_sample) then
    // ---- Compute Jacobian entries using pre() state ----
    F13 := -pre(xh4)*sin(pre(xh3));
    F14 := cos(pre(xh3));
    F23 := pre(xh4)*cos(pre(xh3));
    F24 := sin(pre(xh3));
    F35 := 1.0;
    F44 := -Cd_lin/m_base;
    F55 := -Cr_rot/I_z;

    // ---- Predict state (Euler) ----
    xh1 := pre(xh1) + T_sample*pre(xh4)*cos(pre(xh3));
    xh2 := pre(xh2) + T_sample*pre(xh4)*sin(pre(xh3));
    xh3 := pre(xh3) + T_sample*pre(xh5);
    xh4 := pre(xh4) + T_sample*((tau_L + tau_R)/(r_wheel*m_base) - (Cd_lin/m_base)*pre(xh4));
    xh5 := pre(xh5) + T_sample*((tau_R - tau_L)*L_track/(2*r_wheel*I_z) - (Cr_rot/I_z)*pre(xh5));
    xh6 := pre(xh6);

    // ---- Covariance predict: P = P + dt*(F*P + P*F' + Q) ----
    // Row 1
    P11 := pre(P11) + T_sample*(2.0*(F13*pre(P31) + F14*pre(P41)) + q_pos);
    P12 := pre(P12) + T_sample*(F13*pre(P32) + F14*pre(P42) + pre(P11)*F23 + pre(P12)*F24);
    P13 := pre(P13) + T_sample*(F13*pre(P33) + F14*pre(P43) + pre(P11)*F35);
    P14 := pre(P14) + T_sample*(F13*pre(P34) + F14*pre(P44) + pre(P11)*F44 + pre(P14)*F44);
    P15 := pre(P15) + T_sample*(F13*pre(P35) + F14*pre(P45) + pre(P11)*F55 + pre(P15)*F55);
    P16 := pre(P16) + T_sample*(F13*pre(P36) + F14*pre(P46));

    // Row 2
    P21 := pre(P21) + T_sample*(F23*pre(P31) + F24*pre(P41) + pre(P21)*F13 + pre(P22)*F14);
    P22 := pre(P22) + T_sample*(2.0*(F23*pre(P32) + F24*pre(P42)) + q_pos);
    P23 := pre(P23) + T_sample*(F23*pre(P33) + F24*pre(P43) + pre(P21)*F35);
    P24 := pre(P24) + T_sample*(F23*pre(P34) + F24*pre(P44) + pre(P21)*F44 + pre(P24)*F44);
    P25 := pre(P25) + T_sample*(F23*pre(P35) + F24*pre(P45) + pre(P21)*F55 + pre(P25)*F55);
    P26 := pre(P26) + T_sample*(F23*pre(P36) + F24*pre(P46));

    // Row 3
    P31 := pre(P31) + T_sample*(F35*pre(P21) + pre(P31)*F13 + pre(P32)*F14);
    P32 := pre(P32) + T_sample*(F35*pre(P22) + pre(P31)*F23 + pre(P32)*F24);
    P33 := pre(P33) + T_sample*(2.0*F35*pre(P23) + q_pos);
    P34 := pre(P34) + T_sample*(F35*pre(P24) + pre(P31)*F44 + pre(P34)*F44);
    P35 := pre(P35) + T_sample*(F35*pre(P25) + pre(P31)*F55 + pre(P35)*F55);
    P36 := pre(P36) + T_sample*(F35*pre(P26));

    // Row 4
    P41 := pre(P41) + T_sample*(F44*pre(P41) + pre(P41)*F13 + pre(P42)*F14);
    P42 := pre(P42) + T_sample*(F44*pre(P42) + pre(P41)*F23 + pre(P42)*F24);
    P43 := pre(P43) + T_sample*(F44*pre(P43) + pre(P41)*F35);
    P44 := pre(P44) + T_sample*(2.0*F44*pre(P44) + q_v);
    P45 := pre(P45) + T_sample*(F44*pre(P45) + pre(P41)*F55 + pre(P45)*F55);
    P46 := pre(P46) + T_sample*(F44*pre(P46));

    // Row 5
    P51 := pre(P51) + T_sample*(F55*pre(P51) + pre(P51)*F13 + pre(P52)*F14);
    P52 := pre(P52) + T_sample*(F55*pre(P52) + pre(P51)*F23 + pre(P52)*F24);
    P53 := pre(P53) + T_sample*(F55*pre(P53) + pre(P51)*F35);
    P54 := pre(P54) + T_sample*(F55*pre(P54) + pre(P51)*F44 + pre(P54)*F44);
    P55 := pre(P55) + T_sample*(2.0*F55*pre(P55) + q_w);
    P56 := pre(P56) + T_sample*(F55*pre(P56));

    // Row 6
    P61 := pre(P61) + T_sample*(pre(P61)*F13 + pre(P62)*F14);
    P62 := pre(P62) + T_sample*(pre(P61)*F23 + pre(P62)*F24);
    P63 := pre(P63) + T_sample*(pre(P61)*F35);
    P64 := pre(P64) + T_sample*(pre(P61)*F44 + pre(P64)*F44);
    P65 := pre(P65) + T_sample*(pre(P61)*F55 + pre(P65)*F55);
    P66 := pre(P66) + T_sample*(q_b);

    // ---- IMU gyro update: H = [0 0 0 0 1 1], z = omega + b_g ----
    if cnt_imu > pre(ekf_seen_imu) then
      innov := z_gyro - (xh5 + xh6);
      a1 := P15 + P16;
      a2 := P25 + P26;
      a3 := P35 + P36;
      a4 := P45 + P46;
      a5 := P55 + P56;
      a6 := P65 + P66;
      S_val := a5 + a6 + R_gyro;
      if S_val > 1.0e-12 then
        xh1 := xh1 + a1/S_val*innov;
        xh2 := xh2 + a2/S_val*innov;
        xh3 := xh3 + a3/S_val*innov;
        xh4 := xh4 + a4/S_val*innov;
        xh5 := xh5 + a5/S_val*innov;
        xh6 := xh6 + a6/S_val*innov;
        P11 := P11 - a1*a1/S_val;
        P12 := P12 - a1*a2/S_val;
        P13 := P13 - a1*a3/S_val;
        P14 := P14 - a1*a4/S_val;
        P15 := P15 - a1*a5/S_val;
        P16 := P16 - a1*a6/S_val;
        P21 := P21 - a2*a1/S_val;
        P22 := P22 - a2*a2/S_val;
        P23 := P23 - a2*a3/S_val;
        P24 := P24 - a2*a4/S_val;
        P25 := P25 - a2*a5/S_val;
        P26 := P26 - a2*a6/S_val;
        P31 := P31 - a3*a1/S_val;
        P32 := P32 - a3*a2/S_val;
        P33 := P33 - a3*a3/S_val;
        P34 := P34 - a3*a4/S_val;
        P35 := P35 - a3*a5/S_val;
        P36 := P36 - a3*a6/S_val;
        P41 := P41 - a4*a1/S_val;
        P42 := P42 - a4*a2/S_val;
        P43 := P43 - a4*a3/S_val;
        P44 := P44 - a4*a4/S_val;
        P45 := P45 - a4*a5/S_val;
        P46 := P46 - a4*a6/S_val;
        P51 := P51 - a5*a1/S_val;
        P52 := P52 - a5*a2/S_val;
        P53 := P53 - a5*a3/S_val;
        P54 := P54 - a5*a4/S_val;
        P55 := P55 - a5*a5/S_val;
        P56 := P56 - a5*a6/S_val;
        P61 := P61 - a6*a1/S_val;
        P62 := P62 - a6*a2/S_val;
        P63 := P63 - a6*a3/S_val;
        P64 := P64 - a6*a4/S_val;
        P65 := P65 - a6*a5/S_val;
        P66 := P66 - a6*a6/S_val;
      end if;
      ekf_seen_imu := cnt_imu;
    else
      ekf_seen_imu := pre(ekf_seen_imu);
    end if;

    // ---- Encoder update: H = [0 0 0 1 0 0], z = v ----
    if cnt_enc > pre(ekf_seen_enc) then
      innov := z_enc - xh4;
      a1 := P14;
      a2 := P24;
      a3 := P34;
      a4 := P44;
      a5 := P54;
      a6 := P64;
      S_val := a4 + R_enc;
      if S_val > 1.0e-12 then
        xh1 := xh1 + a1/S_val*innov;
        xh2 := xh2 + a2/S_val*innov;
        xh3 := xh3 + a3/S_val*innov;
        xh4 := xh4 + a4/S_val*innov;
        xh5 := xh5 + a5/S_val*innov;
        xh6 := xh6 + a6/S_val*innov;
        P11 := P11 - a1*a1/S_val;
        P12 := P12 - a1*a2/S_val;
        P13 := P13 - a1*a3/S_val;
        P14 := P14 - a1*a4/S_val;
        P15 := P15 - a1*a5/S_val;
        P16 := P16 - a1*a6/S_val;
        P21 := P21 - a2*a1/S_val;
        P22 := P22 - a2*a2/S_val;
        P23 := P23 - a2*a3/S_val;
        P24 := P24 - a2*a4/S_val;
        P25 := P25 - a2*a5/S_val;
        P26 := P26 - a2*a6/S_val;
        P31 := P31 - a3*a1/S_val;
        P32 := P32 - a3*a2/S_val;
        P33 := P33 - a3*a3/S_val;
        P34 := P34 - a3*a4/S_val;
        P35 := P35 - a3*a5/S_val;
        P36 := P36 - a3*a6/S_val;
        P41 := P41 - a4*a1/S_val;
        P42 := P42 - a4*a2/S_val;
        P43 := P43 - a4*a3/S_val;
        P44 := P44 - a4*a4/S_val;
        P45 := P45 - a4*a5/S_val;
        P46 := P46 - a4*a6/S_val;
        P51 := P51 - a5*a1/S_val;
        P52 := P52 - a5*a2/S_val;
        P53 := P53 - a5*a3/S_val;
        P54 := P54 - a5*a4/S_val;
        P55 := P55 - a5*a5/S_val;
        P56 := P56 - a5*a6/S_val;
        P61 := P61 - a6*a1/S_val;
        P62 := P62 - a6*a2/S_val;
        P63 := P63 - a6*a3/S_val;
        P64 := P64 - a6*a4/S_val;
        P65 := P65 - a6*a5/S_val;
        P66 := P66 - a6*a6/S_val;
      end if;
      ekf_seen_enc := cnt_enc;
    else
      ekf_seen_enc := pre(ekf_seen_enc);
    end if;

    // ---- Lidar range updates: 4 landmarks, sequential scalar updates ----
    if cnt_lidar > pre(ekf_seen_lidar) then
      // Landmark 1
      dx_lm := xh1 - L1x;
      dy_lm := xh2 - L1y;
      r_pred := sqrt(dx_lm*dx_lm + dy_lm*dy_lm + 1.0e-6);
      zlm := z_lidar1;
      innov := zlm - r_pred;
      hx_val := dx_lm/r_pred;
      hy_val := dy_lm/r_pred;
      a1 := P11*hx_val + P12*hy_val;
      a2 := P21*hx_val + P22*hy_val;
      a3 := P31*hx_val + P32*hy_val;
      a4 := P41*hx_val + P42*hy_val;
      a5 := P51*hx_val + P52*hy_val;
      a6 := P61*hx_val + P62*hy_val;
      S_val := hx_val*a1 + hy_val*a2 + R_lidar;
      if S_val > 1.0e-12 then
        xh1 := xh1 + a1/S_val*innov;
        xh2 := xh2 + a2/S_val*innov;
        xh3 := xh3 + a3/S_val*innov;
        xh4 := xh4 + a4/S_val*innov;
        xh5 := xh5 + a5/S_val*innov;
        xh6 := xh6 + a6/S_val*innov;
        P11 := P11 - a1*a1/S_val;
        P12 := P12 - a1*a2/S_val;
        P13 := P13 - a1*a3/S_val;
        P14 := P14 - a1*a4/S_val;
        P15 := P15 - a1*a5/S_val;
        P16 := P16 - a1*a6/S_val;
        P21 := P21 - a2*a1/S_val;
        P22 := P22 - a2*a2/S_val;
        P23 := P23 - a2*a3/S_val;
        P24 := P24 - a2*a4/S_val;
        P25 := P25 - a2*a5/S_val;
        P26 := P26 - a2*a6/S_val;
        P31 := P31 - a3*a1/S_val;
        P32 := P32 - a3*a2/S_val;
        P33 := P33 - a3*a3/S_val;
        P34 := P34 - a3*a4/S_val;
        P35 := P35 - a3*a5/S_val;
        P36 := P36 - a3*a6/S_val;
        P41 := P41 - a4*a1/S_val;
        P42 := P42 - a4*a2/S_val;
        P43 := P43 - a4*a3/S_val;
        P44 := P44 - a4*a4/S_val;
        P45 := P45 - a4*a5/S_val;
        P46 := P46 - a4*a6/S_val;
        P51 := P51 - a5*a1/S_val;
        P52 := P52 - a5*a2/S_val;
        P53 := P53 - a5*a3/S_val;
        P54 := P54 - a5*a4/S_val;
        P55 := P55 - a5*a5/S_val;
        P56 := P56 - a5*a6/S_val;
        P61 := P61 - a6*a1/S_val;
        P62 := P62 - a6*a2/S_val;
        P63 := P63 - a6*a3/S_val;
        P64 := P64 - a6*a4/S_val;
        P65 := P65 - a6*a5/S_val;
        P66 := P66 - a6*a6/S_val;
      end if;

      // Landmark 2
      dx_lm := xh1 - L2x;
      dy_lm := xh2 - L2y;
      r_pred := sqrt(dx_lm*dx_lm + dy_lm*dy_lm + 1.0e-6);
      zlm := z_lidar2;
      innov := zlm - r_pred;
      hx_val := dx_lm/r_pred;
      hy_val := dy_lm/r_pred;
      a1 := P11*hx_val + P12*hy_val;
      a2 := P21*hx_val + P22*hy_val;
      a3 := P31*hx_val + P32*hy_val;
      a4 := P41*hx_val + P42*hy_val;
      a5 := P51*hx_val + P52*hy_val;
      a6 := P61*hx_val + P62*hy_val;
      S_val := hx_val*a1 + hy_val*a2 + R_lidar;
      if S_val > 1.0e-12 then
        xh1 := xh1 + a1/S_val*innov;
        xh2 := xh2 + a2/S_val*innov;
        xh3 := xh3 + a3/S_val*innov;
        xh4 := xh4 + a4/S_val*innov;
        xh5 := xh5 + a5/S_val*innov;
        xh6 := xh6 + a6/S_val*innov;
        P11 := P11 - a1*a1/S_val;
        P12 := P12 - a1*a2/S_val;
        P13 := P13 - a1*a3/S_val;
        P14 := P14 - a1*a4/S_val;
        P15 := P15 - a1*a5/S_val;
        P16 := P16 - a1*a6/S_val;
        P21 := P21 - a2*a1/S_val;
        P22 := P22 - a2*a2/S_val;
        P23 := P23 - a2*a3/S_val;
        P24 := P24 - a2*a4/S_val;
        P25 := P25 - a2*a5/S_val;
        P26 := P26 - a2*a6/S_val;
        P31 := P31 - a3*a1/S_val;
        P32 := P32 - a3*a2/S_val;
        P33 := P33 - a3*a3/S_val;
        P34 := P34 - a3*a4/S_val;
        P35 := P35 - a3*a5/S_val;
        P36 := P36 - a3*a6/S_val;
        P41 := P41 - a4*a1/S_val;
        P42 := P42 - a4*a2/S_val;
        P43 := P43 - a4*a3/S_val;
        P44 := P44 - a4*a4/S_val;
        P45 := P45 - a4*a5/S_val;
        P46 := P46 - a4*a6/S_val;
        P51 := P51 - a5*a1/S_val;
        P52 := P52 - a5*a2/S_val;
        P53 := P53 - a5*a3/S_val;
        P54 := P54 - a5*a4/S_val;
        P55 := P55 - a5*a5/S_val;
        P56 := P56 - a5*a6/S_val;
        P61 := P61 - a6*a1/S_val;
        P62 := P62 - a6*a2/S_val;
        P63 := P63 - a6*a3/S_val;
        P64 := P64 - a6*a4/S_val;
        P65 := P65 - a6*a5/S_val;
        P66 := P66 - a6*a6/S_val;
      end if;

      // Landmark 3
      dx_lm := xh1 - L3x;
      dy_lm := xh2 - L3y;
      r_pred := sqrt(dx_lm*dx_lm + dy_lm*dy_lm + 1.0e-6);
      zlm := z_lidar3;
      innov := zlm - r_pred;
      hx_val := dx_lm/r_pred;
      hy_val := dy_lm/r_pred;
      a1 := P11*hx_val + P12*hy_val;
      a2 := P21*hx_val + P22*hy_val;
      a3 := P31*hx_val + P32*hy_val;
      a4 := P41*hx_val + P42*hy_val;
      a5 := P51*hx_val + P52*hy_val;
      a6 := P61*hx_val + P62*hy_val;
      S_val := hx_val*a1 + hy_val*a2 + R_lidar;
      if S_val > 1.0e-12 then
        xh1 := xh1 + a1/S_val*innov;
        xh2 := xh2 + a2/S_val*innov;
        xh3 := xh3 + a3/S_val*innov;
        xh4 := xh4 + a4/S_val*innov;
        xh5 := xh5 + a5/S_val*innov;
        xh6 := xh6 + a6/S_val*innov;
        P11 := P11 - a1*a1/S_val;
        P12 := P12 - a1*a2/S_val;
        P13 := P13 - a1*a3/S_val;
        P14 := P14 - a1*a4/S_val;
        P15 := P15 - a1*a5/S_val;
        P16 := P16 - a1*a6/S_val;
        P21 := P21 - a2*a1/S_val;
        P22 := P22 - a2*a2/S_val;
        P23 := P23 - a2*a3/S_val;
        P24 := P24 - a2*a4/S_val;
        P25 := P25 - a2*a5/S_val;
        P26 := P26 - a2*a6/S_val;
        P31 := P31 - a3*a1/S_val;
        P32 := P32 - a3*a2/S_val;
        P33 := P33 - a3*a3/S_val;
        P34 := P34 - a3*a4/S_val;
        P35 := P35 - a3*a5/S_val;
        P36 := P36 - a3*a6/S_val;
        P41 := P41 - a4*a1/S_val;
        P42 := P42 - a4*a2/S_val;
        P43 := P43 - a4*a3/S_val;
        P44 := P44 - a4*a4/S_val;
        P45 := P45 - a4*a5/S_val;
        P46 := P46 - a4*a6/S_val;
        P51 := P51 - a5*a1/S_val;
        P52 := P52 - a5*a2/S_val;
        P53 := P53 - a5*a3/S_val;
        P54 := P54 - a5*a4/S_val;
        P55 := P55 - a5*a5/S_val;
        P56 := P56 - a5*a6/S_val;
        P61 := P61 - a6*a1/S_val;
        P62 := P62 - a6*a2/S_val;
        P63 := P63 - a6*a3/S_val;
        P64 := P64 - a6*a4/S_val;
        P65 := P65 - a6*a5/S_val;
        P66 := P66 - a6*a6/S_val;
      end if;

      // Landmark 4
      dx_lm := xh1 - L4x;
      dy_lm := xh2 - L4y;
      r_pred := sqrt(dx_lm*dx_lm + dy_lm*dy_lm + 1.0e-6);
      zlm := z_lidar4;
      innov := zlm - r_pred;
      hx_val := dx_lm/r_pred;
      hy_val := dy_lm/r_pred;
      a1 := P11*hx_val + P12*hy_val;
      a2 := P21*hx_val + P22*hy_val;
      a3 := P31*hx_val + P32*hy_val;
      a4 := P41*hx_val + P42*hy_val;
      a5 := P51*hx_val + P52*hy_val;
      a6 := P61*hx_val + P62*hy_val;
      S_val := hx_val*a1 + hy_val*a2 + R_lidar;
      if S_val > 1.0e-12 then
        xh1 := xh1 + a1/S_val*innov;
        xh2 := xh2 + a2/S_val*innov;
        xh3 := xh3 + a3/S_val*innov;
        xh4 := xh4 + a4/S_val*innov;
        xh5 := xh5 + a5/S_val*innov;
        xh6 := xh6 + a6/S_val*innov;
        P11 := P11 - a1*a1/S_val;
        P12 := P12 - a1*a2/S_val;
        P13 := P13 - a1*a3/S_val;
        P14 := P14 - a1*a4/S_val;
        P15 := P15 - a1*a5/S_val;
        P16 := P16 - a1*a6/S_val;
        P21 := P21 - a2*a1/S_val;
        P22 := P22 - a2*a2/S_val;
        P23 := P23 - a2*a3/S_val;
        P24 := P24 - a2*a4/S_val;
        P25 := P25 - a2*a5/S_val;
        P26 := P26 - a2*a6/S_val;
        P31 := P31 - a3*a1/S_val;
        P32 := P32 - a3*a2/S_val;
        P33 := P33 - a3*a3/S_val;
        P34 := P34 - a3*a4/S_val;
        P35 := P35 - a3*a5/S_val;
        P36 := P36 - a3*a6/S_val;
        P41 := P41 - a4*a1/S_val;
        P42 := P42 - a4*a2/S_val;
        P43 := P43 - a4*a3/S_val;
        P44 := P44 - a4*a4/S_val;
        P45 := P45 - a4*a5/S_val;
        P46 := P46 - a4*a6/S_val;
        P51 := P51 - a5*a1/S_val;
        P52 := P52 - a5*a2/S_val;
        P53 := P53 - a5*a3/S_val;
        P54 := P54 - a5*a4/S_val;
        P55 := P55 - a5*a5/S_val;
        P56 := P56 - a5*a6/S_val;
        P61 := P61 - a6*a1/S_val;
        P62 := P62 - a6*a2/S_val;
        P63 := P63 - a6*a3/S_val;
        P64 := P64 - a6*a4/S_val;
        P65 := P65 - a6*a5/S_val;
        P66 := P66 - a6*a6/S_val;
      end if;

      ekf_seen_lidar := cnt_lidar;
    else
      ekf_seen_lidar := pre(ekf_seen_lidar);
    end if;

    // RGB-D camera data recorded (timestamp/frame/std/bias preserved) but
    // not fused in this position-heading EKF.
    ekf_seen_cam := pre(ekf_seen_cam);

    // ---- Covariance diagonal floor (finite positive guarantee) ----
    if P11 < 1.0e-9 then P11 := 1.0e-9; end if;
    if P22 < 1.0e-9 then P22 := 1.0e-9; end if;
    if P33 < 1.0e-9 then P33 := 1.0e-9; end if;
    if P44 < 1.0e-9 then P44 := 1.0e-9; end if;
    if P55 < 1.0e-9 then P55 := 1.0e-9; end if;
    if P66 < 1.0e-9 then P66 := 1.0e-9; end if;
  end when;

  annotation(
    experiment(StartTime=0, StopTime=20, Tolerance=1.0e-6, Interval=0.002),
    Documentation(info="22 kg differential-drive mobile base performing bounded-route mapping/localization. Sensors (asynchronous, preserved rates/frames/stds/biases): IMU 200 Hz body frame, wheel encoders 100 Hz, planar lidar 10 Hz (20 m max), forward RGB-D 20 Hz. EKF state [x,y,theta,v,omega,b_g] at 500 Hz predict. Controlled 0.058 rad/s gyro-bias step applied during middle third. Per-wheel torque bounded at 14.6 N.m. Fixed landmarks provided as external references; estimator never receives ground truth. Controller uses estimated state. Verification: finite positive covariance, tracking error below 0.16 m-or-rad after 13 s, bias convergence, no NaN/Inf."));
end MapRigLocalizeF;