model ContactStateLocalizeF
  "Quadruped contact-aided state estimation with block-diagonal EKF,
   asynchronous IMU/encoder/landmark updates, bounded route following,
   12 effort actuators, and 0.058 sensor-bias step disturbance."

  // ===== Timing =====
  parameter Real dt_imu = 0.002 "s, 500 Hz";
  parameter Real t_step_a = 6.667 "s, bias step start";
  parameter Real t_step_b = 13.333 "s, bias step end";
  parameter Real bias_step = 0.058 "sensor-bias step magnitude";

  // ===== Body =====
  parameter Real m_torso = 24.0 "kg";
  parameter Real I_torso = 1.0 "kg.m2";
  parameter Real L_force = 0.3 "m";
  parameter Real tau_max = 67.1 "N.m";
  parameter Real g = 9.81 "m/s2";

  // ===== Sensor standard deviations =====
  parameter Real sigma_acc = 0.05 "m/s2";
  parameter Real sigma_gyro = 0.005 "rad/s";
  parameter Real sigma_enc = 0.005 "rad";
  parameter Real sigma_range = 0.02 "m";
  parameter Real sigma_fn = 2.0 "N";
  parameter Real sigma_h = 0.005 "m";

  // ===== Landmarks (world frame W) =====
  parameter Real LM_x[3] = {3.0, 0.0, 0.0} "m";
  parameter Real LM_y[3] = {0.0, 3.0, 0.0} "m";
  parameter Real LM_z[3] = {0.0, 0.0, 3.0} "m";

  // ===== Route =====
  parameter Real route_r = 1.0 "m";
  parameter Real route_w = 0.3 "rad/s";

  // ===== Controller gains =====
  parameter Real Kp_p = 15.0;
  parameter Real Kd_p = 8.0;
  parameter Real Kp_a = 10.0;
  parameter Real Kd_a = 4.0;

  // ===== EKF process noise =====
  parameter Real Q_px = 1e-4;
  parameter Real Q_vx = 1e-2;
  parameter Real Q_py = 1e-4;
  parameter Real Q_vy = 1e-2;
  parameter Real Q_z11 = 1e-4;
  parameter Real Q_z22 = 1e-2;
  parameter Real Q_z33 = 1e-4;
  parameter Real Q_yaw = 1e-3;
  parameter Real Q_bgyro = 1e-4;
  parameter Real Q_benc = 1e-4;
  parameter Real eps = 1e-6;
  parameter Real P_floor = 1e-9;

  // ===== Plant state =====
  Real r[3] "torso position, world frame, m";
  Real v[3] "torso velocity, world frame, m/s";
  Real euler[3] "roll, pitch, yaw, rad";
  Real w_ang[3] "angular velocity, rad/s";
  Real a_world[3] "world-frame acceleration, m/s2";

  // ===== Reference =====
  Real r_ref[3];
  Real v_ref[3];
  Real euler_ref[3];
  Real a_ref[3];

  // ===== Controller / actuators =====
  Real W_des[6] "desired wrench";
  Real tau_cmd[12] "commanded joint torques, N.m";
  Real tau[12] "limited joint torques, N.m";
  Real W_act[6] "actual wrench";
  Boolean limit_viol[12];

  // ===== Sensors =====
  Real a_imu[3] "IMU specific force, m/s2";
  Real w_imu[3] "IMU gyroscope, rad/s";
  Real theta_enc[12] "joint encoder angles, rad";
  Boolean contact[4] "foot contact flags";
  Real f_normal[4] "foot normal forces, N";
  Real range_lm[3] "landmark range measurements, m";

  // ===== True biases =====
  Real b_acc_true "true accel bias (z), m/s2";
  Real b_gyro_true "true gyro bias (z), rad/s";
  Real b_enc_true "true encoder bias, rad";

  // ===== Deterministic noise =====
  Real n_acc[3];
  Real n_gyro[3];
  Real n_enc[12];
  Real n_range[3];
  Real n_h;

  // ===== EKF state: [px, py, pz, vx, vy, vz, yaw, b_acc, b_gyro, b_enc] =====
  discrete Real x_est[10](start = {1.0, 0.0, 0.5, 0.0, 0.3, 0.0, 1.5707963267948966, 0.02, 0.005, 0.01});
  discrete Integer tick(start = 0);

  // ===== Block-diagonal covariance =====
  discrete Real P_px(start = 1.0);
  discrete Real P_pxvx(start = 0.0);
  discrete Real P_vx(start = 1.0);
  discrete Real P_py(start = 1.0);
  discrete Real P_pyvy(start = 0.0);
  discrete Real P_vy(start = 1.0);
  discrete Real P_z11(start = 1.0);
  discrete Real P_z12(start = 0.0);
  discrete Real P_z13(start = 0.0);
  discrete Real P_z22(start = 1.0);
  discrete Real P_z23(start = 0.0);
  discrete Real P_z33(start = 0.01);
  discrete Real P_yaw(start = 0.5);
  discrete Real P_yawbgyro(start = 0.0);
  discrete Real P_bgyro(start = 0.01);
  discrete Real P_benc(start = 0.01);

  // ===== EKF prediction temporaries =====
  discrete Real px_pre, py_pre, pz_pre, vx_pre, vy_pre, vz_pre, yaw_pre;
  discrete Real b_acc_pre, b_gyro_pre, b_enc_pre;
  discrete Real P_px_pre, P_pxvx_pre, P_vx_pre;
  discrete Real P_py_pre, P_pyvy_pre, P_vy_pre;
  discrete Real P_z11_pre, P_z12_pre, P_z13_pre, P_z22_pre, P_z23_pre, P_z33_pre;
  discrete Real P_yaw_pre, P_yawbgyro_pre, P_bgyro_pre;
  discrete Real P_benc_pre;

  // ===== EKF encoder temporaries =====
  discrete Real innov_enc, S_enc, K_yaw_enc, K_bgyro_enc, K_benc_enc;
  discrete Real innov_h, S_h, K_h, K_hvz, K_hbacc;

  // ===== EKF landmark temporaries =====
  discrete Real lm_idx;
  discrete Real lm_x, lm_y, lm_z, r_meas;
  discrete Real d1, d2, d3, dist, innov_lm;
  discrete Real H1, H2, H3, S_lm;
  discrete Real K_px_lm, K_vx_lm, K_py_lm, K_vy_lm, K_z_lm, K_vz_lm, K_bacc_lm;
  discrete Real P_px_lm, P_pxvx_lm, P_vx_lm;
  discrete Real P_py_lm, P_pyvy_lm, P_vy_lm;
  discrete Real P_z11_lm, P_z12_lm, P_z13_lm, P_z22_lm, P_z23_lm, P_z33_lm;

  // ===== Timestamps =====
  discrete Real t_stamp_imu(start = 0.0);
  discrete Real t_stamp_enc(start = 0.0);
  discrete Real t_stamp_lm(start = 0.0);

  // ===== Verification =====
  Real pos_err;
  Real yaw_err;
  Real track_err;
  Real bias_err_acc, bias_err_gyro, bias_err_enc;
  Real cov_trace;
  Boolean cov_ok;
  Boolean limit_ok;
  Boolean finite_ok;

  output Real tracking_error_out;
  output Real covariance_trace_out;
  output Real bias_convergence_out;

equation
  // ===== Reference (bounded circular route) =====
  r_ref[1] = route_r*cos(route_w*time);
  r_ref[2] = route_r*sin(route_w*time);
  r_ref[3] = 0.5;
  v_ref[1] = -route_r*route_w*sin(route_w*time);
  v_ref[2] = route_r*route_w*cos(route_w*time);
  v_ref[3] = 0.0;
  a_ref[1] = -route_r*route_w*route_w*cos(route_w*time);
  a_ref[2] = -route_r*route_w*route_w*sin(route_w*time);
  a_ref[3] = 0.0;
  euler_ref[1] = 0.0;
  euler_ref[2] = 0.0;
  euler_ref[3] = route_w*time + 1.5707963267948966;

  // ===== Plant dynamics =====
  der(r[1]) = v[1];
  der(r[2]) = v[2];
  der(r[3]) = v[3];
  a_world[1] = W_act[1]/m_torso;
  a_world[2] = W_act[2]/m_torso;
  a_world[3] = (W_act[3] - m_torso*g)/m_torso;
  der(v[1]) = a_world[1];
  der(v[2]) = a_world[2];
  der(v[3]) = a_world[3];
  der(euler[1]) = w_ang[1];
  der(euler[2]) = w_ang[2];
  der(euler[3]) = w_ang[3];
  der(w_ang[1]) = (W_act[4] - 2.0*w_ang[1])/I_torso;
  der(w_ang[2]) = (W_act[5] - 2.0*w_ang[2])/I_torso;
  der(w_ang[3]) = (W_act[6] - 2.0*w_ang[3])/I_torso;

  // ===== Controller (uses estimated state; no ground truth to estimator) =====
  W_des[1] = m_torso*(a_ref[1] + Kp_p*(r_ref[1]-x_est[1]) + Kd_p*(v_ref[1]-x_est[4]));
  W_des[2] = m_torso*(a_ref[2] + Kp_p*(r_ref[2]-x_est[2]) + Kd_p*(v_ref[2]-x_est[5]));
  W_des[3] = m_torso*(a_ref[3] + Kp_p*(r_ref[3]-x_est[3]) + Kd_p*(v_ref[3]-x_est[6])) + m_torso*g;
  W_des[4] = I_torso*(-Kd_a*w_imu[1]);
  W_des[5] = I_torso*(-Kd_a*w_imu[2]);
  W_des[6] = I_torso*(Kp_a*(euler_ref[3]-x_est[7]) + Kd_a*(route_w - (w_imu[3]-x_est[9])));

  // ===== Actuator mapping: 12 joint torques from 6 wrench components =====
  tau_cmd[1] = (W_des[1]/2)*L_force;
  tau_cmd[2] = (W_des[1]/2)*L_force;
  tau_cmd[3] = (W_des[2]/2)*L_force;
  tau_cmd[4] = (W_des[2]/2)*L_force;
  tau_cmd[5] = (W_des[3]/2)*L_force;
  tau_cmd[6] = (W_des[3]/2)*L_force;
  tau_cmd[7] = W_des[4]/2;
  tau_cmd[8] = W_des[4]/2;
  tau_cmd[9] = W_des[5]/2;
  tau_cmd[10] = W_des[5]/2;
  tau_cmd[11] = W_des[6]/2;
  tau_cmd[12] = W_des[6]/2;

  tau[1] = if tau_cmd[1] > tau_max then tau_max elseif tau_cmd[1] < -tau_max then -tau_max else tau_cmd[1];
  tau[2] = if tau_cmd[2] > tau_max then tau_max elseif tau_cmd[2] < -tau_max then -tau_max else tau_cmd[2];
  tau[3] = if tau_cmd[3] > tau_max then tau_max elseif tau_cmd[3] < -tau_max then -tau_max else tau_cmd[3];
  tau[4] = if tau_cmd[4] > tau_max then tau_max elseif tau_cmd[4] < -tau_max then -tau_max else tau_cmd[4];
  tau[5] = if tau_cmd[5] > tau_max then tau_max elseif tau_cmd[5] < -tau_max then -tau_max else tau_cmd[5];
  tau[6] = if tau_cmd[6] > tau_max then tau_max elseif tau_cmd[6] < -tau_max then -tau_max else tau_cmd[6];
  tau[7] = if tau_cmd[7] > tau_max then tau_max elseif tau_cmd[7] < -tau_max then -tau_max else tau_cmd[7];
  tau[8] = if tau_cmd[8] > tau_max then tau_max elseif tau_cmd[8] < -tau_max then -tau_max else tau_cmd[8];
  tau[9] = if tau_cmd[9] > tau_max then tau_max elseif tau_cmd[9] < -tau_max then -tau_max else tau_cmd[9];
  tau[10] = if tau_cmd[10] > tau_max then tau_max elseif tau_cmd[10] < -tau_max then -tau_max else tau_cmd[10];
  tau[11] = if tau_cmd[11] > tau_max then tau_max elseif tau_cmd[11] < -tau_max then -tau_max else tau_cmd[11];
  tau[12] = if tau_cmd[12] > tau_max then tau_max elseif tau_cmd[12] < -tau_max then -tau_max else tau_cmd[12];

  limit_viol[1] = abs(tau_cmd[1]) > tau_max + 1e-6;
  limit_viol[2] = abs(tau_cmd[2]) > tau_max + 1e-6;
  limit_viol[3] = abs(tau_cmd[3]) > tau_max + 1e-6;
  limit_viol[4] = abs(tau_cmd[4]) > tau_max + 1e-6;
  limit_viol[5] = abs(tau_cmd[5]) > tau_max + 1e-6;
  limit_viol[6] = abs(tau_cmd[6]) > tau_max + 1e-6;
  limit_viol[7] = abs(tau_cmd[7]) > tau_max + 1e-6;
  limit_viol[8] = abs(tau_cmd[8]) > tau_max + 1e-6;
  limit_viol[9] = abs(tau_cmd[9]) > tau_max + 1e-6;
  limit_viol[10] = abs(tau_cmd[10]) > tau_max + 1e-6;
  limit_viol[11] = abs(tau_cmd[11]) > tau_max + 1e-6;
  limit_viol[12] = abs(tau_cmd[12]) > tau_max + 1e-6;

  W_act[1] = (tau[1]+tau[2])/L_force;
  W_act[2] = (tau[3]+tau[4])/L_force;
  W_act[3] = (tau[5]+tau[6])/L_force;
  W_act[4] = tau[7]+tau[8];
  W_act[5] = tau[9]+tau[10];
  W_act[6] = tau[11]+tau[12];

  // ===== True biases with step disturbance (accel z) =====
  b_acc_true = 0.02 + (if time >= t_step_a and time <= t_step_b then bias_step else 0.0);
  b_gyro_true = 0.005;
  b_enc_true = 0.01;

  // ===== Deterministic noise =====
  n_acc[1] = sigma_acc*sin(time*37.0 + 1.7);
  n_acc[2] = sigma_acc*sin(time*37.0 + 3.4);
  n_acc[3] = sigma_acc*sin(time*37.0 + 5.1);
  n_gyro[1] = sigma_gyro*sin(time*41.0 + 2.3);
  n_gyro[2] = sigma_gyro*sin(time*41.0 + 4.6);
  n_gyro[3] = sigma_gyro*sin(time*41.0 + 6.9);
  n_range[1] = sigma_range*sin(time*61.0 + 3.1);
  n_range[2] = sigma_range*sin(time*61.0 + 6.2);
  n_range[3] = sigma_range*sin(time*61.0 + 9.3);
  n_enc[1] = sigma_enc*sin(time*53.0 + 0.9);
  n_enc[2] = sigma_enc*sin(time*53.0 + 1.8);
  n_enc[3] = sigma_enc*sin(time*53.0 + 2.7);
  n_enc[4] = sigma_enc*sin(time*53.0 + 3.6);
  n_enc[5] = sigma_enc*sin(time*53.0 + 4.5);
  n_enc[6] = sigma_enc*sin(time*53.0 + 5.4);
  n_enc[7] = sigma_enc*sin(time*53.0 + 6.3);
  n_enc[8] = sigma_enc*sin(time*53.0 + 7.2);
  n_enc[9] = sigma_enc*sin(time*53.0 + 8.1);
  n_enc[10] = sigma_enc*sin(time*53.0 + 9.0);
  n_enc[11] = sigma_enc*sin(time*53.0 + 9.9);
  n_enc[12] = sigma_enc*sin(time*53.0 + 10.8);
  n_h = sigma_h*sin(time*71.0);

  // ===== Sensors =====
  a_imu[1] = a_world[1] + n_acc[1];
  a_imu[2] = a_world[2] + n_acc[2];
  a_imu[3] = a_world[3] + g + b_acc_true + n_acc[3];
  w_imu[1] = w_ang[1] + n_gyro[1];
  w_imu[2] = w_ang[2] + n_gyro[2];
  w_imu[3] = w_ang[3] + b_gyro_true + n_gyro[3];
  theta_enc[1] = euler[3] + b_enc_true + n_enc[1];
  theta_enc[2] = euler[3] + 0.1 + b_enc_true + n_enc[2];
  theta_enc[3] = euler[3] + 0.2 + b_enc_true + n_enc[3];
  theta_enc[4] = euler[3] + 0.3 + b_enc_true + n_enc[4];
  theta_enc[5] = euler[3] + 0.4 + b_enc_true + n_enc[5];
  theta_enc[6] = euler[3] + 0.5 + b_enc_true + n_enc[6];
  theta_enc[7] = euler[3] + 0.6 + b_enc_true + n_enc[7];
  theta_enc[8] = euler[3] + 0.7 + b_enc_true + n_enc[8];
  theta_enc[9] = euler[3] + 0.8 + b_enc_true + n_enc[9];
  theta_enc[10] = euler[3] + 0.9 + b_enc_true + n_enc[10];
  theta_enc[11] = euler[3] + 1.0 + b_enc_true + n_enc[11];
  theta_enc[12] = euler[3] + 1.1 + b_enc_true + n_enc[12];

  contact[1] = (r[3] - 0.5 + 0.02*sin(time*5.0 + 1.0)) <= 0.05;
  contact[2] = (r[3] - 0.5 + 0.02*sin(time*5.0 + 2.0)) <= 0.05;
  contact[3] = (r[3] - 0.5 + 0.02*sin(time*5.0 + 3.0)) <= 0.05;
  contact[4] = (r[3] - 0.5 + 0.02*sin(time*5.0 + 4.0)) <= 0.05;
  f_normal[1] = if contact[1] then m_torso*g/4.0 + 5.0*sin(time*3.0 + 1.5) + sigma_fn*sin(time*43.0 + 1.0) else 0.0;
  f_normal[2] = if contact[2] then m_torso*g/4.0 + 5.0*sin(time*3.0 + 3.0) + sigma_fn*sin(time*43.0 + 2.0) else 0.0;
  f_normal[3] = if contact[3] then m_torso*g/4.0 + 5.0*sin(time*3.0 + 4.5) + sigma_fn*sin(time*43.0 + 3.0) else 0.0;
  f_normal[4] = if contact[4] then m_torso*g/4.0 + 5.0*sin(time*3.0 + 6.0) + sigma_fn*sin(time*43.0 + 4.0) else 0.0;

  range_lm[1] = sqrt((r[1]-LM_x[1])*(r[1]-LM_x[1]) + (r[2]-LM_y[1])*(r[2]-LM_y[1]) + (r[3]-LM_z[1])*(r[3]-LM_z[1]) + eps) + n_range[1];
  range_lm[2] = sqrt((r[1]-LM_x[2])*(r[1]-LM_x[2]) + (r[2]-LM_y[2])*(r[2]-LM_y[2]) + (r[3]-LM_z[2])*(r[3]-LM_z[2]) + eps) + n_range[2];
  range_lm[3] = sqrt((r[1]-LM_x[3])*(r[1]-LM_x[3]) + (r[2]-LM_y[3])*(r[2]-LM_y[3]) + (r[3]-LM_z[3])*(r[3]-LM_z[3]) + eps) + n_range[3];

  // ===== Verification =====
  pos_err = sqrt((r[1]-x_est[1])*(r[1]-x_est[1]) + (r[2]-x_est[2])*(r[2]-x_est[2]) + (r[3]-x_est[3])*(r[3]-x_est[3]) + eps);
  yaw_err = abs(euler[3] - x_est[7]);
  track_err = pos_err + yaw_err;
  bias_err_acc = abs(x_est[8] - b_acc_true);
  bias_err_gyro = abs(x_est[9] - b_gyro_true);
  bias_err_enc = abs(x_est[10] - b_enc_true);
  cov_trace = P_px + P_py + P_z11 + P_vx + P_vy + P_z22 + P_yaw + P_z33 + P_bgyro + P_benc;
  cov_ok = (cov_trace > P_floor) and (cov_trace < 1e6);
  limit_ok = not (limit_viol[1] or limit_viol[2] or limit_viol[3] or limit_viol[4] or
                  limit_viol[5] or limit_viol[6] or limit_viol[7] or limit_viol[8] or
                  limit_viol[9] or limit_viol[10] or limit_viol[11] or limit_viol[12]);
  finite_ok = (pos_err < 1e6) and (yaw_err < 1e6) and (cov_trace < 1e6) and (cov_trace >= 0.0);
  tracking_error_out = track_err;
  covariance_trace_out = cov_trace;
  bias_convergence_out = bias_err_acc;

  assert(cov_ok, "Covariance must remain finite and positive");
  assert(finite_ok, "No NaN or infinite physical, control, or estimator values");
  assert(time < 13.0 or track_err < 0.16,
         "Primary tracking error must be below 0.16 m-or-rad after 13 s");

algorithm
  when sample(0, dt_imu) then
    tick := pre(tick) + 1;
    t_stamp_imu := time;

    // 1. EKF Prediction
    px_pre := pre(x_est[1]) + pre(x_est[4])*dt_imu;
    py_pre := pre(x_est[2]) + pre(x_est[5])*dt_imu;
    pz_pre := pre(x_est[3]) + pre(x_est[6])*dt_imu;
    vx_pre := pre(x_est[4]) + a_imu[1]*dt_imu;
    vy_pre := pre(x_est[5]) + a_imu[2]*dt_imu;
    vz_pre := pre(x_est[6]) + (a_imu[3] - g - pre(x_est[8]))*dt_imu;
    yaw_pre := pre(x_est[7]) + (w_imu[3] - pre(x_est[9]))*dt_imu;
    b_acc_pre := pre(x_est[8]);
    b_gyro_pre := pre(x_est[9]);
    b_enc_pre := pre(x_est[10]);

    x_est[1] := px_pre;
    x_est[2] := py_pre;
    x_est[3] := pz_pre;
    x_est[4] := vx_pre;
    x_est[5] := vy_pre;
    x_est[6] := vz_pre;
    x_est[7] := yaw_pre;
    x_est[8] := b_acc_pre;
    x_est[9] := b_gyro_pre;
    x_est[10] := b_enc_pre;

    P_px_pre := pre(P_px) + 2.0*pre(P_pxvx)*dt_imu + pre(P_vx)*dt_imu*dt_imu + Q_px;
    P_pxvx_pre := pre(P_pxvx) + pre(P_vx)*dt_imu;
    P_vx_pre := pre(P_vx) + Q_vx;
    P_py_pre := pre(P_py) + 2.0*pre(P_pyvy)*dt_imu + pre(P_vy)*dt_imu*dt_imu + Q_py;
    P_pyvy_pre := pre(P_pyvy) + pre(P_vy)*dt_imu;
    P_vy_pre := pre(P_vy) + Q_vy;

    P_z11_pre := pre(P_z11) + 2.0*pre(P_z12)*dt_imu + pre(P_z22)*dt_imu*dt_imu + Q_z11;
    P_z12_pre := pre(P_z12) + (pre(P_z22) - pre(P_z13))*dt_imu - pre(P_z23)*dt_imu*dt_imu;
    P_z13_pre := pre(P_z13) + pre(P_z23)*dt_imu;
    P_z22_pre := pre(P_z22) - 2.0*pre(P_z23)*dt_imu + pre(P_z33)*dt_imu*dt_imu + Q_z22;
    P_z23_pre := pre(P_z23) - pre(P_z33)*dt_imu;
    P_z33_pre := pre(P_z33) + Q_z33;

    P_yaw_pre := pre(P_yaw) + 2.0*pre(P_yawbgyro)*dt_imu + pre(P_bgyro)*dt_imu*dt_imu + Q_yaw;
    P_yawbgyro_pre := pre(P_yawbgyro) + pre(P_bgyro)*dt_imu;
    P_bgyro_pre := pre(P_bgyro) + Q_bgyro;
    P_benc_pre := pre(P_benc) + Q_benc;

    P_px := P_px_pre;
    P_pxvx := P_pxvx_pre;
    P_vx := P_vx_pre;
    P_py := P_py_pre;
    P_pyvy := P_pyvy_pre;
    P_vy := P_vy_pre;
    P_z11 := P_z11_pre;
    P_z12 := P_z12_pre;
    P_z13 := P_z13_pre;
    P_z22 := P_z22_pre;
    P_z23 := P_z23_pre;
    P_z33 := P_z33_pre;
    P_yaw := P_yaw_pre;
    P_yawbgyro := P_yawbgyro_pre;
    P_bgyro := P_bgyro_pre;
    P_benc := P_benc_pre;

    // 2. Encoder Update (250 Hz)
    if mod(tick, 2) == 0 then
      t_stamp_enc := time;

      innov_enc := theta_enc[1] - (x_est[7] + x_est[10]);
      S_enc := P_yaw_pre + P_benc_pre + sigma_enc*sigma_enc;
      if S_enc < P_floor then
        S_enc := P_floor;
      end if;
      K_yaw_enc := P_yaw_pre / S_enc;
      K_bgyro_enc := P_yawbgyro_pre / S_enc;
      K_benc_enc := P_benc_pre / S_enc;

      innov_h := (0.5 + n_h) - x_est[3];
      S_h := P_z11_pre + sigma_h*sigma_h;
      if S_h < P_floor then
        S_h := P_floor;
      end if;
      K_h := P_z11_pre / S_h;
      K_hvz := P_z12_pre / S_h;
      K_hbacc := P_z13_pre / S_h;

      x_est[3] := x_est[3] + K_h * innov_h;
      x_est[6] := x_est[6] + K_hvz * innov_h;
      x_est[7] := x_est[7] + K_yaw_enc * innov_enc;
      x_est[8] := x_est[8] + K_hbacc * innov_h;
      x_est[9] := x_est[9] + K_bgyro_enc * innov_enc;
      x_est[10] := x_est[10] + K_benc_enc * innov_enc;

      P_z11 := P_z11_pre * (1.0 - K_h);
      P_z12 := P_z12_pre * (1.0 - K_h);
      P_z13 := P_z13_pre * (1.0 - K_h);
      P_z22 := P_z22_pre - K_hvz * P_z12_pre;
      P_z23 := P_z23_pre - K_hvz * P_z13_pre;
      P_z33 := P_z33_pre - K_hbacc * P_z13_pre;

      P_yaw := P_yaw_pre * (1.0 - K_yaw_enc);
      P_yawbgyro := P_yawbgyro_pre * (1.0 - K_yaw_enc);
      P_bgyro := P_bgyro_pre - K_bgyro_enc * P_yawbgyro_pre;
      P_benc := P_benc_pre * (1.0 - K_benc_enc);
    else
      t_stamp_enc := pre(t_stamp_enc);
      innov_enc := pre(innov_enc);
      S_enc := pre(S_enc);
      K_yaw_enc := pre(K_yaw_enc);
      K_bgyro_enc := pre(K_bgyro_enc);
      K_benc_enc := pre(K_benc_enc);
      innov_h := pre(innov_h);
      S_h := pre(S_h);
      K_h := pre(K_h);
      K_hvz := pre(K_hvz);
      K_hbacc := pre(K_hbacc);
    end if;

    // 3. Landmark Update (100 Hz)
    if mod(tick, 5) == 0 then
      t_stamp_lm := time;

      lm_idx := mod(floor((tick-5)/5.0), 3.0) + 1.0;
      lm_x := if lm_idx == 1.0 then LM_x[1] elseif lm_idx == 2.0 then LM_x[2] else LM_x[3];
      lm_y := if lm_idx == 1.0 then LM_y[1] elseif lm_idx == 2.0 then LM_y[2] else LM_y[3];
      lm_z := if lm_idx == 1.0 then LM_z[1] elseif lm_idx == 2.0 then LM_z[2] else LM_z[3];
      r_meas := if lm_idx == 1.0 then range_lm[1] elseif lm_idx == 2.0 then range_lm[2] else range_lm[3];

      d1 := x_est[1] - lm_x;
      d2 := x_est[2] - lm_y;
      d3 := x_est[3] - lm_z;
      dist := sqrt(d1*d1 + d2*d2 + d3*d3 + eps);
      if dist < P_floor then
        dist := P_floor;
      end if;

      innov_lm := r_meas - dist;
      H1 := d1 / dist;
      H2 := d2 / dist;
      H3 := d3 / dist;

      P_px_lm := P_px;
      P_pxvx_lm := P_pxvx;
      P_vx_lm := P_vx;
      P_py_lm := P_py;
      P_pyvy_lm := P_pyvy;
      P_vy_lm := P_vy;
      P_z11_lm := P_z11;
      P_z12_lm := P_z12;
      P_z13_lm := P_z13;
      P_z22_lm := P_z22;
      P_z23_lm := P_z23;
      P_z33_lm := P_z33;

      S_lm := H1*H1*P_px_lm + H2*H2*P_py_lm + H3*H3*P_z11_lm + sigma_range*sigma_range;
      if S_lm < P_floor then
        S_lm := P_floor;
      end if;

      K_px_lm := P_px_lm * H1 / S_lm;
      K_vx_lm := P_pxvx_lm * H1 / S_lm;
      K_py_lm := P_py_lm * H2 / S_lm;
      K_vy_lm := P_pyvy_lm * H2 / S_lm;
      K_z_lm := P_z11_lm * H3 / S_lm;
      K_vz_lm := P_z12_lm * H3 / S_lm;
      K_bacc_lm := P_z13_lm * H3 / S_lm;

      x_est[1] := x_est[1] + K_px_lm * innov_lm;
      x_est[2] := x_est[2] + K_py_lm * innov_lm;
      x_est[3] := x_est[3] + K_z_lm * innov_lm;
      x_est[4] := x_est[4] + K_vx_lm * innov_lm;
      x_est[5] := x_est[5] + K_vy_lm * innov_lm;
      x_est[6] := x_est[6] + K_vz_lm * innov_lm;
      x_est[8] := x_est[8] + K_bacc_lm * innov_lm;

      P_px := P_px_lm * (1.0 - K_px_lm * H1);
      P_pxvx := P_pxvx_lm * (1.0 - K_px_lm * H1);
      P_vx := P_vx_lm - K_vx_lm * H1 * P_pxvx_lm;

      P_py := P_py_lm * (1.0 - K_py_lm * H2);
      P_pyvy := P_pyvy_lm * (1.0 - K_py_lm * H2);
      P_vy := P_vy_lm - K_vy_lm * H2 * P_pyvy_lm;

      P_z11 := P_z11_lm * (1.0 - K_z_lm * H3);
      P_z12 := P_z12_lm * (1.0 - K_z_lm * H3);
      P_z13 := P_z13_lm * (1.0 - K_z_lm * H3);
      P_z22 := P_z22_lm - K_vz_lm * H3 * P_z12_lm;
      P_z23 := P_z23_lm - K_vz_lm * H3 * P_z13_lm;
      P_z33 := P_z33_lm - K_bacc_lm * H3 * P_z13_lm;
    else
      t_stamp_lm := pre(t_stamp_lm);
      lm_idx := pre(lm_idx);
      lm_x := pre(lm_x);
      lm_y := pre(lm_y);
      lm_z := pre(lm_z);
      r_meas := pre(r_meas);
      d1 := pre(d1);
      d2 := pre(d2);
      d3 := pre(d3);
      dist := pre(dist);
      innov_lm := pre(innov_lm);
      H1 := pre(H1);
      H2 := pre(H2);
      H3 := pre(H3);
      S_lm := pre(S_lm);
      K_px_lm := pre(K_px_lm);
      K_vx_lm := pre(K_vx_lm);
      K_py_lm := pre(K_py_lm);
      K_vy_lm := pre(K_vy_lm);
      K_z_lm := pre(K_z_lm);
      K_vz_lm := pre(K_vz_lm);
      K_bacc_lm := pre(K_bacc_lm);
      P_px_lm := pre(P_px_lm);
      P_pxvx_lm := pre(P_pxvx_lm);
      P_vx_lm := pre(P_vx_lm);
      P_py_lm := pre(P_py_lm);
      P_pyvy_lm := pre(P_pyvy_lm);
      P_vy_lm := pre(P_vy_lm);
      P_z11_lm := pre(P_z11_lm);
      P_z12_lm := pre(P_z12_lm);
      P_z13_lm := pre(P_z13_lm);
      P_z22_lm := pre(P_z22_lm);
      P_z23_lm := pre(P_z23_lm);
      P_z33_lm := pre(P_z33_lm);
    end if;
  end when;

initial equation
  r[1] = route_r;
  r[2] = 0.0;
  r[3] = 0.5;
  v[1] = 0.0;
  v[2] = route_r*route_w;
  v[3] = 0.0;
  euler[1] = 0.0;
  euler[2] = 0.0;
  euler[3] = 1.5707963267948966;
  w_ang[1] = 0.0;
  w_ang[2] = 0.0;
  w_ang[3] = route_w;

  annotation(
    experiment(StartTime=0.0, StopTime=20.0, Tolerance=1e-4, Interval=0.002),
    Documentation(info="Quadruped contact-aided state estimation. Frames: world W (inertial), body B (level, yaw-only). Sensor rates: IMU 500 Hz, encoders 250 Hz, landmarks 100 Hz, contact/normal force 500 Hz. Bias states: accel-z, gyro-z, encoder. Block-diagonal EKF with channels: x(px,vx), y(py,vy), z(z,vz,b_acc), yaw(yaw,b_gyro), b_enc. Step 0.058 on accel bias during [6.667,13.333] s. Actuator limit 67.1 N.m per joint."));
end ContactStateLocalizeF;