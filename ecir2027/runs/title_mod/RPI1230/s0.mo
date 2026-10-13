model MapRigLocalizeF
  "Mobile-base mapping/localization scenario with multi-rate asynchronous EKF."

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
  parameter Real f_imu = 200.0;     parameter Real T_imu = 1.0/f_imu;
  parameter Real f_enc = 100.0;     parameter Real T_enc = 1.0/f_enc;
  parameter Real f_lidar = 10.0;    parameter Real T_lidar = 1.0/f_lidar;
  parameter Real f_cam = 20.0;      parameter Real T_cam = 1.0/f_cam;
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
  parameter Real Lx[4] = {5.0, -5.0, 5.0, -5.0};
  parameter Real Ly[4] = {5.0, 5.0, -5.0, -5.0};

  // ===== Process noise =====
  parameter Real q_pos = 1e-4;
  parameter Real q_v = 1e-3;
  parameter Real q_w = 1e-3;
  parameter Real q_b = 1e-5;

  // ===== True plant state =====
  Real x_true(start=3.0) "true x [m]";
  Real y_true(start=0.0) "true y [m]";
  Real theta_true(start=pi_c/2) "true heading [rad]";
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
  discrete Real z_gyro "IMU gyro [rad/s], body frame";
  discrete Real z_enc "encoder forward speed [m/s], wheel frame";
  discrete Real z_lidar[4] "lidar ranges to landmarks [m], lidar frame";
  discrete Real z_cam_depth "RGB-D forward depth [m], camera frame";
  discrete Real z_imu_time(start=-1.0) "IMU sample timestamp [s]";
  discrete Real z_enc_time(start=-1.0) "encoder sample timestamp [s]";
  discrete Real z_lidar_time(start=-1.0) "lidar sample timestamp [s]";
  discrete Real z_cam_time(start=-1.0) "camera sample timestamp [s]";
  discrete Integer cnt_imu(start=0);
  discrete Integer cnt_enc(start=0);
  discrete Integer cnt_lidar(start=0);
  discrete Integer cnt_cam(start=0);
  discrete Integer ekf_seen_imu(start=0);
  discrete Integer ekf_seen_enc(start=0);
  discrete Integer ekf_seen_lidar(start=0);
  discrete Integer ekf_seen_cam(start=0);

  // ===== EKF: state [x, y, theta, v, omega, b_g] =====
  discrete Real xh[6](start={3.0, 0.0, 1.5707963267948966, 0.0, 0.0, 0.0});
  discrete Real P[6,6] "error covariance";
  Real F_jac[6,6] "Jacobian of continuous dynamics wrt estimated state";
  Real Qmat[6,6] "process noise covariance";

  // EKF temporaries (assigned inside algorithm when)
  discrete Real a_vec[6];
  discrete Real innov;
  discrete Real S_val;
  discrete Real dx_lm, dy_lm, r_pred, hx, hy;
  discrete Real fp_acc, pf_acc;

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

initial equation
  P = diagonal({0.01, 0.01, 0.01, 0.01, 0.01, 1.0e-4});

equation
  // ---- Process noise covariance ----
  Qmat = diagonal({q_pos, q_pos, q_pos, q_v, q_w, q_b});

  // ---- Jacobian of continuous dynamics f(x,u) ----
  F_jac[1,1]=0; F_jac[1,2]=0; F_jac[1,3]=-xh[4]*sin(xh[3]); F_jac[1,4]=cos(xh[3]); F_jac[1,5]=0; F_jac[1,6]=0;
  F_jac[2,1]=0; F_jac[2,2]=0; F_jac[2,3]= xh[4]*cos(xh[3]); F_jac[2,4]=sin(xh[3]); F_jac[2,5]=0; F_jac[2,6]=0;
  F_jac[3,1]=0; F_jac[3,2]=0; F_jac[3,3]=0; F_jac[3,4]=0; F_jac[3,5]=1; F_jac[3,6]=0;
  F_jac[4,1]=0; F_jac[4,2]=0; F_jac[4,3]=0; F_jac[4,4]=-Cd_lin/m_base; F_jac[4,5]=0; F_jac[4,6]=0;
  F_jac[5,1]=0; F_jac[5,2]=0; F_jac[5,3]=0; F_jac[5,4]=0; F_jac[5,5]=-Cr_rot/I_z; F_jac[5,6]=0;
  F_jac[6,1]=0; F_jac[6,2]=0; F_jac[6,3]=0; F_jac[6,4]=0; F_jac[6,5]=0; F_jac[6,6]=0;

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
  e_fwd = cos(xh[3])*(x_ref - xh[1]) + sin(xh[3])*(y_ref - xh[2]);
  e_lat = -sin(xh[3])*(x_ref - xh[1]) + cos(xh[3])*(y_ref - xh[2]);
  e_th = theta_ref - xh[3];
  v_cmd = v_ref + kp_v*e_fwd;
  omega_cmd = omega_ref + kd_lat*e_lat + kd_th*e_th;
  F_drive = m_base*kp_v*(v_cmd - xh[4]);
  M_drive = I_z*kp_w*(omega_cmd - xh[5]);
  tau_L_cmd = 0.5*(F_drive*r_wheel - M_drive*2*r_wheel/L_track);
  tau_R_cmd = 0.5*(F_drive*r_wheel + M_drive*2*r_wheel/L_track);
  tau_L = if tau_L_cmd > tau_max then tau_max else if tau_L_cmd < -tau_max then -tau_max else tau_L_cmd;
  tau_R = if tau_R_cmd > tau_max then tau_max else if tau_R_cmd < -tau_max then -tau_max else tau_R_cmd;
  tau_L_saturated = abs(tau_L_cmd) > tau_max;
  tau_R_saturated = abs(tau_R_cmd) > tau_max;

  // ---- Estimate outputs ----
  x_hat = xh[1]; y_hat = xh[2]; theta_hat = xh[3];
  v_hat = xh[4]; omega_hat = xh[5]; b_g_hat = xh[6];
  bias_est = xh[6];
  bias_err = b_gyro_true - xh[6];

  // ---- Verification metrics ----
  err_pos = sqrt((x_true - x_hat)^2 + (y_true - y_hat)^2 + 1.0e-12);
  err_theta = abs(theta_true - theta_hat);
  tracking_err = max(err_pos, err_theta);
  converged_after_13s = time >= 13.0 and tracking_err < 0.16;
  P_diag_min = min(min(min(min(min(P[1,1], P[2,2]), P[3,3]), P[4,4]), P[5,5]), P[6,6]);
  cov_finite_positive = P_diag_min > 0.0 and P_diag_min < 1.0e6;
  no_nan_inf = abs(x_true) < 1.0e6 and abs(y_true) < 1.0e6 and abs(theta_true) < 1.0e6
    and abs(v_true) < 1.0e6 and abs(omega_true) < 1.0e6
    and abs(tau_L) < 1.0e6 and abs(tau_R) < 1.0e6
    and abs(xh[1]) < 1.0e6 and abs(xh[2]) < 1.0e6 and abs(xh[3]) < 1.0e6
    and abs(xh[4]) < 1.0e6 and abs(xh[5]) < 1.0e6 and abs(xh[6]) < 1.0e6
    and abs(P[1,1]) < 1.0e6 and abs(P[6,6]) < 1.0e6;

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
    z_lidar[1] = sqrt((x_true - Lx[1])^2 + (y_true - Ly[1])^2) + b_lidar_true + sigma_lidar*sin(time*13.0 + 1);
    z_lidar[2] = sqrt((x_true - Lx[2])^2 + (y_true - Ly[2])^2) + b_lidar_true + sigma_lidar*sin(time*13.0 + 2);
    z_lidar[3] = sqrt((x_true - Lx[3])^2 + (y_true - Ly[3])^2) + b_lidar_true + sigma_lidar*sin(time*13.0 + 3);
    z_lidar[4] = sqrt((x_true - Lx[4])^2 + (y_true - Ly[4])^2) + b_lidar_true + sigma_lidar*sin(time*13.0 + 4);
    z_lidar_time = time;
    cnt_lidar = pre(cnt_lidar) + 1;
  end when;

  // Forward RGB-D camera 20 Hz, camera frame (depth to landmark 1, capped at range)
  when sample(0.0004, T_cam) then
    z_cam_depth = min(lidar_range_max, sqrt((x_true - Lx[1])^2 + (y_true - Ly[1])^2)) + b_cam_true + sigma_cam*sin(time*3.0);
    z_cam_time = time;
    cnt_cam = pre(cnt_cam) + 1;
  end when;

algorithm
  // ============ EKF predict + asynchronous updates at 500 Hz ============
  when sample(0.001, T_sample) then
    // ---- Predict (Euler) ----
    xh[1] := pre(xh[1]) + T_sample*pre(xh[4])*cos(pre(xh[3]));
    xh[2] := pre(xh[2]) + T_sample*pre(xh[4])*sin(pre(xh[3]));
    xh[3] := pre(xh[3]) + T_sample*pre(xh[5]);
    xh[4] := pre(xh[4]) + T_sample*((tau_L + tau_R)/(r_wheel*m_base) - (Cd_lin/m_base)*pre(xh[4]));
    xh[5] := pre(xh[5]) + T_sample*((tau_R - tau_L)*L_track/(2*r_wheel*I_z) - (Cr_rot/I_z)*pre(xh[5]));
    xh[6] := pre(xh[6]);

    // Covariance predict: P = P + dt*(F*P + P*F' + Q)
    for i in 1:6 loop
      for j in 1:6 loop
        fp_acc := 0.0;
        pf_acc := 0.0;
        for k in 1:6 loop
          fp_acc := fp_acc + F_jac[i,k]*pre(P[k,j]);
          pf_acc := pf_acc + pre(P[i,k])*F_jac[j,k];
        end for;
        P[i,j] := pre(P[i,j]) + T_sample*(fp_acc + pf_acc + Qmat[i,j]);
      end for;
    end for;

    // ---- IMU gyro update: H = [0 0 0 0 1 1], z = omega + b_g ----
    if cnt_imu > pre(ekf_seen_imu) then
      innov := z_gyro - (xh[5] + xh[6]);
      for i in 1:6 loop
        a_vec[i] := P[i,5] + P[i,6];
      end for;
      S_val := a_vec[5] + a_vec[6] + R_gyro;
      if S_val > 1.0e-12 then
        for i in 1:6 loop
          xh[i] := xh[i] + a_vec[i]/S_val*innov;
        end for;
        for i in 1:6 loop
          for j in 1:6 loop
            P[i,j] := P[i,j] - a_vec[i]*a_vec[j]/S_val;
          end for;
        end for;
      end if;
      ekf_seen_imu := cnt_imu;
    else
      ekf_seen_imu := pre(ekf_seen_imu);
    end if;

    // ---- Encoder update: H = [0 0 0 1 0 0], z = v ----
    if cnt_enc > pre(ekf_seen_enc) then
      innov := z_enc - xh[4];
      for i in 1:6 loop
        a_vec[i] := P[i,4];
      end for;
      S_val := a_vec[4] + R_enc;
      if S_val > 1.0e-12 then
        for i in 1:6 loop
          xh[i] := xh[i] + a_vec[i]/S_val*innov;
        end for;
        for i in 1:6 loop
          for j in 1:6 loop
            P[i,j] := P[i,j] - a_vec[i]*a_vec[j]/S_val;
          end for;
        end for;
      end if;
      ekf_seen_enc := cnt_enc;
    else
      ekf_seen_enc := pre(ekf_seen_enc);
    end if;

    // ---- Lidar range updates: 4 landmarks, sequential scalar updates ----
    if cnt_lidar > pre(ekf_seen_lidar) then
      for lm in 1:4 loop
        dx_lm := xh[1] - Lx[lm];
        dy_lm := xh[2] - Ly[lm];
        r_pred := sqrt(dx_lm*dx_lm + dy_lm*dy_lm + 1.0e-6);
        innov := z_lidar[lm] - r_pred;
        hx := dx_lm/r_pred;
        hy := dy_lm/r_pred;
        for i in 1:6 loop
          a_vec[i] := P[i,1]*hx + P[i,2]*hy;
        end for;
        S_val := hx*a_vec[1] + hy*a_vec[2] + R_lidar;
        if S_val > 1.0e-12 then
          for i in 1:6 loop
            xh[i] := xh[i] + a_vec[i]/S_val*innov;
          end for;
          for i in 1:6 loop
            for j in 1:6 loop
              P[i,j] := P[i,j] - a_vec[i]*a_vec[j]/S_val;
            end for;
          end for;
        end if;
      end for;
      ekf_seen_lidar := cnt_lidar;
    else
      ekf_seen_lidar := pre(ekf_seen_lidar);
    end if;

    // RGB-D camera data recorded (timestamp/frame/std/bias preserved) but
    // not fused in this position-heading EKF.
    ekf_seen_cam := pre(ekf_seen_cam);

    // ---- Covariance diagonal floor (finite positive guarantee) ----
    for i in 1:6 loop
      if P[i,i] < 1.0e-9 then
        P[i,i] := 1.0e-9;
      end if;
    end for;
  end when;

annotation(
  experiment(StartTime=0, StopTime=20, Tolerance=1.0e-6, Interval=0.002),
  Documentation(info="22 kg differential-drive mobile base performing bounded-route mapping/localization.
Sensors (asynchronous, preserved rates/frames/stds/biases): IMU 200 Hz body frame, wheel encoders 100 Hz,
planar lidar 10 Hz (20 m max), forward RGB-D 20 Hz. EKF state [x,y,theta,v,omega,b_g] at 500 Hz predict.
Controlled 0.058 rad/s gyro-bias step applied during middle third (6.67-13.33 s). Per-wheel torque bounded at 14.6 N.m.
Fixed landmarks provided as external references; estimator never receives ground truth. Controller uses estimated state.
Verification: finite positive covariance, tracking error < 0.16 m-or-rad after 13 s, bias convergence, no NaN/Inf."));
end MapRigLocalizeF;