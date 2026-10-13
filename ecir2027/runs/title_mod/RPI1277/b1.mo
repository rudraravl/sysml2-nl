model ContactStateLocalizeE
  // Plant parameters
  parameter Real m_torso = 24.0 "Torso mass in kg";
  parameter Real g = 9.81 "Gravity m/s^2";
  parameter Real k_force = 2.0 "Force mapping gain";
  parameter Real k_torque = 1.0 "Torque mapping gain";
  parameter Real u_max = 60.5 "Max joint effort N.m";
  parameter Real T_final = 16.0 "Simulation duration s";

  // Sensor rates and standard deviations (250 Hz base)
  parameter Real dt_imu = 0.004 "IMU rate 250 Hz";
  parameter Real dt_enc = 0.004 "Encoder rate 250 Hz";
  parameter Real dt_lm = 0.01 "Landmark rate 100 Hz (asynchronous)";
  parameter Real sigma_imu_acc = 0.05 "IMU accel std dev";
  parameter Real sigma_imu_gyro = 0.01 "IMU gyro std dev";
  parameter Real sigma_enc = 0.005 "Joint encoder std dev";
  parameter Real sigma_lm = 0.02 "Landmark range std dev";

  // Fixed landmarks (external references)
  parameter Real L1[3] = {5.0, 0.0, 0.0} "Landmark 1 position";
  parameter Real L2[3] = {0.0, 5.0, 0.0} "Landmark 2 position";

  // True states
  Real x, y, z;
  Real vx, vy, vz;
  Real roll, pitch, yaw;
  Real wx, wy, wz;
  Real q[12] "Joint angles";
  Real dq[12] "Joint velocities";

  // Commands
  Real tau_raw[12] "Raw joint efforts before saturation";
  Real tau[12] "Saturated joint efforts";

  // True biases and disturbance
  Real b_acc_true[3];
  Real b_gyro_true[3];
  Real b_enc_true[12];
  Real bias_disturbance;

  // Sensors
  Real imu_acc[3] "Body IMU acceleration";
  Real imu_gyro[3] "Body IMU angular velocity";
  Real enc[12] "Joint encoders";
  Real foot_contact[4] "Foot normal force sensors";
  Real lm_range[2] "Landmark ranges";

  // Estimator states
  Real X[9] "State vector [x,y,z,vx,vy,vz,b_ax,b_ay,b_az]";
  Real roll_est, pitch_est, yaw_est;
  Real b_gyro_est[3];
  Real b_enc_est[12];
  Real q_est[12];

  // Covariance and filter matrices
  Real P[9, 9];
  Real F_mat[9, 9];
  Real H_mat[2, 9];
  Real Q_mat[9, 9];
  Real R_mat[2, 2];
  Real K_mat[9, 2];
  Real KH[9, 9];
  Real innov[2];
  Real h_est[2];
  Real h_est_safe[2];

  // Tracking and acceptance metrics
  Real track_err;
  Real err_norm;
  Real x_des, y_des, z_des;
  Real q_des[12];

initial equation
  x = 0; y = 0; z = 1.0;
  vx = 0; vy = 0; vz = 0;
  roll = 0; pitch = 0; yaw = 0;
  wx = 0; wy = 0; wz = 0;
  for i in 1:12 loop
    q[i] = 0; dq[i] = 0;
  end for;

  X[1] = 0; X[2] = 0; X[3] = 1.0;
  X[4] = 0; X[5] = 0; X[6] = 0;
  X[7] = 0; X[8] = 0; X[9] = 0;
  roll_est = 0; pitch_est = 0; yaw_est = 0;
  for i in 1:3 loop
    b_gyro_est[i] = 0;
  end for;
  for i in 1:12 loop
    b_enc_est[i] = 0;
    q_est[i] = 0;
  end for;

  for i in 1:9 loop
    for j in 1:9 loop
      if i == j then
        P[i, j] = 1.0;
      else
        P[i, j] = 0.0;
      end if;
    end for;
  end for;

equation
  // Disturbance: 0.048 step at middle third (t >= T_final/3)
  bias_disturbance = if time >= T_final / 3.0 then 0.048 else 0.0;

  // True bias states with disturbance
  for i in 1:3 loop
    b_acc_true[i] = 0.02 + bias_disturbance;
    b_gyro_true[i] = 0.01 + bias_disturbance;
  end for;
  for i in 1:12 loop
    b_enc_true[i] = 0.005 + bias_disturbance;
  end for;

  // Desired bounded trajectory
  x_des = 2.0 * (1 - exp(-0.5 * time)) * cos(2 * 3.14159 * time / 16.0);
  y_des = 2.0 * (1 - exp(-0.5 * time)) * sin(2 * 3.14159 * time / 16.0);
  z_des = 1.0;
  for i in 1:12 loop
    q_des[i] = 0.5 * sin(2 * 3.14159 * time / 4.0 + i);
  end for;

  // Controller (PD) - raw commands
  tau_raw[1] = (50.0 * (x_des - x) + 10.0 * (-vx)) / 4 + (20.0 * (-roll) + 5.0 * (-wx)) / 2 + 10.0 * (q_des[1] - q[1]) - 2.0 * dq[1];
  tau_raw[2] = (50.0 * (x_des - x) + 10.0 * (-vx)) / 4 - (20.0 * (-roll) + 5.0 * (-wx)) / 2 + 10.0 * (q_des[2] - q[2]) - 2.0 * dq[2];
  tau_raw[3] = (50.0 * (y_des - y) + 10.0 * (-vy)) / 4 + (20.0 * (-pitch) + 5.0 * (-wy)) / 2 + 10.0 * (q_des[3] - q[3]) - 2.0 * dq[3];
  tau_raw[4] = (50.0 * (y_des - y) + 10.0 * (-vy)) / 4 - (20.0 * (-pitch) + 5.0 * (-wy)) / 2 + 10.0 * (q_des[4] - q[4]) - 2.0 * dq[4];
  tau_raw[5] = (50.0 * (z_des - z) + 10.0 * (-vz) + m_torso * g) / 4 + (20.0 * (0 - yaw) + 5.0 * (-wz)) / 2 + 10.0 * (q_des[5] - q[5]) - 2.0 * dq[5];
  tau_raw[6] = (50.0 * (z_des - z) + 10.0 * (-vz) + m_torso * g) / 4 - (20.0 * (0 - yaw) + 5.0 * (-wz)) / 2 + 10.0 * (q_des[6] - q[6]) - 2.0 * dq[6];
  tau_raw[7] = (50.0 * (z_des - z) + 10.0 * (-vz) + m_torso * g) / 4 + 10.0 * (q_des[7] - q[7]) - 2.0 * dq[7];
  tau_raw[8] = (50.0 * (z_des - z) + 10.0 * (-vz) + m_torso * g) / 4 + 10.0 * (q_des[8] - q[8]) - 2.0 * dq[8];
  tau_raw[9] = (50.0 * (y_des - y) + 10.0 * (-vy)) / 4 + 10.0 * (q_des[9] - q[9]) - 2.0 * dq[9];
  tau_raw[10] = (50.0 * (y_des - y) + 10.0 * (-vy)) / 4 + 10.0 * (q_des[10] - q[10]) - 2.0 * dq[10];
  tau_raw[11] = (50.0 * (x_des - x) + 10.0 * (-vx)) / 4 + 10.0 * (q_des[11] - q[11]) - 2.0 * dq[11];
  tau_raw[12] = (50.0 * (x_des - x) + 10.0 * (-vx)) / 4 + 10.0 * (q_des[12] - q[12]) - 2.0 * dq[12];

  // Actuator saturation (60.5 N.m) - no algebraic loop
  for i in 1:12 loop
    tau[i] = if tau_raw[i] > u_max then u_max else if tau_raw[i] < -u_max then -u_max else tau_raw[i];
  end for;

  // Plant dynamics
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  der(vx) = k_force * (tau[1] + tau[2] + tau[11] + tau[12]) / m_torso;
  der(vy) = k_force * (tau[3] + tau[4] + tau[9] + tau[10]) / m_torso;
  der(vz) = k_force * (tau[5] + tau[6] + tau[7] + tau[8]) / m_torso - g;
  der(roll) = wx;
  der(pitch) = wy;
  der(yaw) = wz;
  der(wx) = k_torque * (tau[1] - tau[2]) / m_torso;
  der(wy) = k_torque * (tau[3] - tau[4]) / m_torso;
  der(wz) = k_torque * (tau[5] - tau[6]) / m_torso;
  for i in 1:12 loop
    der(q[i]) = dq[i];
    der(dq[i]) = tau[i] - 0.1 * dq[i];
  end for;

  // Sensors
  imu_acc[1] = der(vx) + b_acc_true[1];
  imu_acc[2] = der(vy) + b_acc_true[2];
  imu_acc[3] = der(vz) + b_acc_true[3];
  imu_gyro[1] = wx + b_gyro_true[1];
  imu_gyro[2] = wy + b_gyro_true[2];
  imu_gyro[3] = wz + b_gyro_true[3];
  for i in 1:12 loop
    enc[i] = q[i] + b_enc_true[i];
  end for;
  for i in 1:4 loop
    foot_contact[i] = if q[i] > 0.1 then abs(tau[i]) else 0.0;
  end for;
  lm_range[1] = sqrt((x - L1[1]) ^ 2 + (y - L1[2]) ^ 2 + (z - L1[3]) ^ 2);
  lm_range[2] = sqrt((x - L2[1]) ^ 2 + (y - L2[2]) ^ 2 + (z - L2[3]) ^ 2);

  // Estimator: Continuous-time EKF (Kalman-Bucy)
  der(X[1]) = X[4] + K_mat[1, 1] * innov[1] + K_mat[1, 2] * innov[2];
  der(X[2]) = X[5] + K_mat[2, 1] * innov[1] + K_mat[2, 2] * innov[2];
  der(X[3]) = X[6] + K_mat[3, 1] * innov[1] + K_mat[3, 2] * innov[2];
  der(X[4]) = imu_acc[1] - X[7] + K_mat[4, 1] * innov[1] + K_mat[4, 2] * innov[2];
  der(X[5]) = imu_acc[2] - X[8] + K_mat[5, 1] * innov[1] + K_mat[5, 2] * innov[2];
  der(X[6]) = imu_acc[3] - X[9] + K_mat[6, 1] * innov[1] + K_mat[6, 2] * innov[2];
  der(X[7]) = K_mat[7, 1] * innov[1] + K_mat[7, 2] * innov[2];
  der(X[8]) = K_mat[8, 1] * innov[1] + K_mat[8, 2] * innov[2];
  der(X[9]) = K_mat[9, 1] * innov[1] + K_mat[9, 2] * innov[2];

  // Attitude estimation
  der(roll_est) = imu_gyro[1] - b_gyro_est[1];
  der(pitch_est) = imu_gyro[2] - b_gyro_est[2];
  der(yaw_est) = imu_gyro[3] - b_gyro_est[3];
  der(b_gyro_est[1]) = 0.01 * (0 - roll_est);
  der(b_gyro_est[2]) = 0.01 * (0 - pitch_est);
  der(b_gyro_est[3]) = 0.01 * (0 - yaw_est);

  // Joint estimation
  for i in 1:12 loop
    q_est[i] = enc[i] - b_enc_est[i];
    der(b_enc_est[i]) = 0.1 * (enc[i] - q_est[i] - b_enc_est[i]);
  end for;

  // Measurement model and innovation
  h_est[1] = sqrt((X[1] - L1[1]) ^ 2 + (X[2] - L1[2]) ^ 2 + (X[3] - L1[3]) ^ 2);
  h_est[2] = sqrt((X[1] - L2[1]) ^ 2 + (X[2] - L2[2]) ^ 2 + (X[3] - L2[3]) ^ 2);
  h_est_safe[1] = if h_est[1] > 0.001 then h_est[1] else 0.001;
  h_est_safe[2] = if h_est[2] > 0.001 then h_est[2] else 0.001;
  innov[1] = lm_range[1] - h_est[1];
  innov[2] = lm_range[2] - h_est[2];

  // Jacobian F (state transition linearization)
  F_mat[1,1]=0; F_mat[1,2]=0; F_mat[1,3]=0; F_mat[1,4]=1; F_mat[1,5]=0; F_mat[1,6]=0; F_mat[1,7]=0; F_mat[1,8]=0; F_mat[1,9]=0;
  F_mat[2,1]=0; F_mat[2,2]=0; F_mat[2,3]=0; F_mat[2,4]=0; F_mat[2,5]=1; F_mat[2,6]=0; F_mat[2,7]=0; F_mat[2,8]=0; F_mat[2,9]=0;
  F_mat[3,1]=0; F_mat[3,2]=0; F_mat[3,3]=0; F_mat[3,4]=0; F_mat[3,5]=0; F_mat[3,6]=1; F_mat[3,7]=0; F_mat[3,8]=0; F_mat[3,9]=0;
  F_mat[4,1]=0; F_mat[4,2]=0; F_mat[4,3]=0; F_mat[4,4]=0; F_mat[4,5]=0; F_mat[4,6]=0; F_mat[4,7]=-1; F_mat[4,8]=0; F_mat[4,9]=0;
  F_mat[5,1]=0; F_mat[5,2]=0; F_mat[5,3]=0; F_mat[5,4]=0; F_mat[5,5]=0; F_mat[5,6]=0; F_mat[5,7]=0; F_mat[5,8]=-1; F_mat[5,9]=0;
  F_mat[6,1]=0; F_mat[6,2]=0; F_mat[6,3]=0; F_mat[6,4]=0; F_mat[6,5]=0; F_mat[6,6]=0; F_mat[6,7]=0; F_mat[6,8]=0; F_mat[6,9]=-1;
  F_mat[7,1]=0; F_mat[7,2]=0; F_mat[7,3]=0; F_mat[7,4]=0; F_mat[7,5]=0; F_mat[7,6]=0; F_mat[7,7]=0; F_mat[7,8]=0; F_mat[7,9]=0;
  F_mat[8,1]=0; F_mat[8,2]=0; F_mat[8,3]=0; F_mat[8,4]=0; F_mat[8,5]=0; F_mat[8,6]=0; F_mat[8,7]=0; F_mat[8,8]=0; F_mat[8,9]=0;
  F_mat[9,1]=0; F_mat[9,2]=0; F_mat[9,3]=0; F_mat[9,4]=0; F_mat[9,5]=0; F_mat[9,6]=0; F_mat[9,7]=0; F_mat[9,8]=0; F_mat[9,9]=0;

  // Jacobian H (measurement)
  H_mat[1,1] = (X[1] - L1[1]) / h_est_safe[1];
  H_mat[1,2] = (X[2] - L1[2]) / h_est_safe[1];
  H_mat[1,3] = (X[3] - L1[3]) / h_est_safe[1];
  H_mat[1,4] = 0; H_mat[1,5] = 0; H_mat[1,6] = 0; H_mat[1,7] = 0; H_mat[1,8] = 0; H_mat[1,9] = 0;
  H_mat[2,1] = (X[1] - L2[1]) / h_est_safe[2];
  H_mat[2,2] = (X[2] - L2[2]) / h_est_safe[2];
  H_mat[2,3] = (X[3] - L2[3]) / h_est_safe[2];
  H_mat[2,4] = 0; H_mat[2,5] = 0; H_mat[2,6] = 0; H_mat[2,7] = 0; H_mat[2,8] = 0; H_mat[2,9] = 0;

  // Noise matrices
  for i in 1:9 loop
    for j in 1:9 loop
      if i == j then
        Q_mat[i, j] = 0.01;
      else
        Q_mat[i, j] = 0.0;
      end if;
    end for;
  end for;
  R_mat[1,1] = sigma_lm ^ 2; R_mat[1,2] = 0;
  R_mat[2,1] = 0;             R_mat[2,2] = sigma_lm ^ 2;

  // Kalman Gain (approximate, diagonal R)
  for i in 1:9 loop
    K_mat[i,1] = (P[i,1]*H_mat[1,1] + P[i,2]*H_mat[1,2] + P[i,3]*H_mat[1,3]) / R_mat[1,1];
    K_mat[i,2] = (P[i,1]*H_mat[2,1] + P[i,2]*H_mat[2,2] + P[i,3]*H_mat[2,3]) / R_mat[2,2];
  end for;

  // KH matrix
  for i in 1:9 loop
    for j in 1:9 loop
      KH[i,j] = K_mat[i,1]*H_mat[1,j] + K_mat[i,2]*H_mat[2,j];
    end for;
  end for;

  // Covariance Riccati equation (expanded)
  for i in 1:9 loop
    for j in 1:9 loop
      der(P[i,j]) = F_mat[i,1]*P[1,j] + F_mat[i,2]*P[2,j] + F_mat[i,3]*P[3,j] + F_mat[i,4]*P[4,j] + F_mat[i,5]*P[5,j] + F_mat[i,6]*P[6,j] + F_mat[i,7]*P[7,j] + F_mat[i,8]*P[8,j] + F_mat[i,9]*P[9,j]
                  + P[i,1]*F_mat[j,1] + P[i,2]*F_mat[j,2] + P[i,3]*F_mat[j,3] + P[i,4]*F_mat[j,4] + P[i,5]*F_mat[j,5] + P[i,6]*F_mat[j,6] + P[i,7]*F_mat[j,7] + P[i,8]*F_mat[j,8] + P[i,9]*F_mat[j,9]
                  + Q_mat[i,j]
                  - KH[i,1]*P[1,j] - KH[i,2]*P[2,j] - KH[i,3]*P[3,j] - KH[i,4]*P[4,j] - KH[i,5]*P[5,j] - KH[i,6]*P[6,j] - KH[i,7]*P[7,j] - KH[i,8]*P[8,j] - KH[i,9]*P[9,j];
    end for;
  end for;

  // Acceptance metrics
  track_err = sqrt((x - X[1]) ^ 2 + (y - X[2]) ^ 2 + (z - X[3]) ^ 2);
  err_norm = sqrt((roll - roll_est) ^ 2 + (pitch - pitch_est) ^ 2 + (yaw - yaw_est) ^ 2);

  // Fail-closed assertions
  assert(noEvent(track_err < 0.18 or time < 10.4), "Primary tracking error > 0.18 after 10.4s");
  assert(noEvent(err_norm < 0.18 or time < 10.4), "Attitude error > 0.18 after 10.4s");
  for i in 1:12 loop
    assert(noEvent(abs(tau[i]) <= u_max + 0.001), "Actuator limit exceeded");
  end for;
  for i in 1:9 loop
    assert(noEvent(P[i,i] > 0.0), "Covariance not positive");
  end for;
  assert(noEvent(x < 1e10 and x > -1e10), "Physical value out of bounds");
  assert(noEvent(y < 1e10 and y > -1e10), "Physical value out of bounds");
  assert(noEvent(z < 1e10 and z > -1e10), "Physical value out of bounds");
  assert(noEvent(X[1] < 1e10 and X[1] > -1e10), "Estimator value out of bounds");
  assert(noEvent(X[2] < 1e10 and X[2] > -1e10), "Estimator value out of bounds");
  assert(noEvent(X[3] < 1e10 and X[3] > -1e10), "Estimator value out of bounds");
  assert(noEvent(tau[1] < 1e10 and tau[1] > -1e10), "Control value out of bounds");

end ContactStateLocalizeE;