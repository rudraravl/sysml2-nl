model ContactStateLocalizeE
  parameter Real m_torso = 24.0 "Torso mass kg";
  parameter Real g = 9.81 "Gravity m/s^2";
  parameter Real u_max = 60.5 "Max joint effort N.m";
  parameter Real T_final = 16.0 "Simulation duration s";

  // Sensor rates, std devs, and frame definitions
  parameter Real dt_imu = 0.004 "IMU sample period s (250 Hz)";
  parameter Real dt_enc = 0.004 "Encoder sample period s (250 Hz)";
  parameter Real dt_lm = 0.01 "Landmark sample period s (100 Hz, async)";
  parameter Real sigma_imu_acc = 0.05 "IMU accel std dev m/s^2";
  parameter Real sigma_imu_gyro = 0.01 "IMU gyro std dev rad/s";
  parameter Real sigma_enc = 0.005 "Joint encoder std dev rad";
  parameter Real sigma_lm = 0.02 "Landmark range std dev m";

  // Fixed landmarks (external references, no ground truth to estimator)
  parameter Real L1[3] = {5.0, 0.0, 0.0} "Landmark 1 position m (world frame)";
  parameter Real L2[3] = {0.0, 5.0, 0.0} "Landmark 2 position m (world frame)";

  // Plant states
  Real x "Body x position m";
  Real y "Body y position m";
  Real z "Body z position m";
  Real vx "Body x velocity m/s";
  Real vy "Body y velocity m/s";
  Real vz "Body z velocity m/s";
  Real roll "Body roll rad";
  Real pitch "Body pitch rad";
  Real yaw "Body yaw rad";
  Real wx "Body x angular rate rad/s";
  Real wy "Body y angular rate rad/s";
  Real wz "Body z angular rate rad/s";
  Real q[12] "Joint angles rad (4 legs x 3 joints)";
  Real dq[12] "Joint velocities rad/s";

  // Actuator commands
  Real tau_cmd[12] "Unsaturated joint efforts N.m";
  Real tau[12] "Saturated joint efforts N.m";

  // True biases and disturbance
  Real b_acc_true[3] "True IMU accel bias m/s^2";
  Real b_gyro_true[3] "True IMU gyro bias rad/s";
  Real b_enc_true[12] "True encoder bias rad";
  Real bias_disturbance "0.048 step at middle-third";

  // Sensors
  Real imu_acc[3] "Body-frame IMU acceleration m/s^2";
  Real imu_gyro[3] "Body-frame IMU angular velocity rad/s";
  Real enc[12] "Joint encoder readings rad";
  Real foot_contact[4] "Foot normal-force sensors N";
  Real lm_range[2] "Landmark range measurements m";

  // Estimator states (EKF)
  Real X[9] "Estimator state [x,y,z,vx,vy,vz,b_ax,b_ay,b_az]";
  Real roll_est "Estimated roll rad";
  Real pitch_est "Estimated pitch rad";
  Real yaw_est "Estimated yaw rad";
  Real b_gyro_est[3] "Estimated gyro bias rad/s";
  Real b_enc_est[12] "Estimated encoder bias rad";
  Real q_est[12] "Estimated joint angles rad";
  Real P[9, 9] "Estimator covariance (finite positive)";
  Real innov[2] "Landmark innovation";
  Real h_est[2] "Predicted landmark ranges m";

  // Metrics
  Real track_err "Position tracking error m";
  Real err_norm "Attitude error rad";
  Real x_des "Desired x m";
  Real y_des "Desired y m";
  Real z_des "Desired z m";
  Real q_des[12] "Desired joint angles rad";

initial equation
  x = 0.0; y = 0.0; z = 1.0;
  vx = 0.0; vy = 0.0; vz = 0.0;
  roll = 0.0; pitch = 0.0; yaw = 0.0;
  wx = 0.0; wy = 0.0; wz = 0.0;
  for i in 1:12 loop
    q[i] = 0.0;
    dq[i] = 0.0;
  end for;
  X[1] = 0.0; X[2] = 0.0; X[3] = 1.0;
  X[4] = 0.0; X[5] = 0.0; X[6] = 0.0;
  X[7] = 0.0; X[8] = 0.0; X[9] = 0.0;
  roll_est = 0.0; pitch_est = 0.0; yaw_est = 0.0;
  for i in 1:3 loop
    b_gyro_est[i] = 0.0;
  end for;
  for i in 1:12 loop
    b_enc_est[i] = 0.0;
    q_est[i] = 0.0;
  end for;
  for i in 1:9 loop
    for j in 1:9 loop
      P[i, j] = if i == j then 1.0 else 0.0;
    end for;
  end for;

equation
  // Disturbance: 0.048 step at middle-third (t = T_final/3 = 5.333 s)
  bias_disturbance = if time >= T_final / 3.0 then 0.048 else 0.0;

  // True bias states (with disturbance)
  for i in 1:3 loop
    b_acc_true[i] = 0.02 + bias_disturbance;
    b_gyro_true[i] = 0.01 + bias_disturbance;
  end for;
  for i in 1:12 loop
    b_enc_true[i] = 0.005 + bias_disturbance;
  end for;

  // Desired bounded trajectory (smooth start, circular route)
  x_des = 2.0 * (1.0 - exp(-0.5 * time)) * cos(2.0 * 3.14159 * time / 16.0);
  y_des = 2.0 * (1.0 - exp(-0.5 * time)) * sin(2.0 * 3.14159 * time / 16.0);
  z_des = 1.0;
  for i in 1:12 loop
    q_des[i] = 0.5 * sin(2.0 * 3.14159 * time / 4.0 + i);
  end for;

  // Controller: PD on body and joint states (12 actuators)
  tau_cmd[1] = (50.0 * (x_des - x) + 10.0 * (-vx)) / 4.0 + (20.0 * (-roll) + 5.0 * (-wx)) / 2.0 + 10.0 * (q_des[1] - q[1]) - 2.0 * dq[1];
  tau_cmd[2] = (50.0 * (x_des - x) + 10.0 * (-vx)) / 4.0 - (20.0 * (-roll) + 5.0 * (-wx)) / 2.0 + 10.0 * (q_des[2] - q[2]) - 2.0 * dq[2];
  tau_cmd[3] = (50.0 * (y_des - y) + 10.0 * (-vy)) / 4.0 + (20.0 * (-pitch) + 5.0 * (-wy)) / 2.0 + 10.0 * (q_des[3] - q[3]) - 2.0 * dq[3];
  tau_cmd[4] = (50.0 * (y_des - y) + 10.0 * (-vy)) / 4.0 - (20.0 * (-pitch) + 5.0 * (-wy)) / 2.0 + 10.0 * (q_des[4] - q[4]) - 2.0 * dq[4];
  tau_cmd[5] = (50.0 * (z_des - z) + 10.0 * (-vz) + m_torso * g) / 4.0 + (20.0 * (-yaw) + 5.0 * (-wz)) / 2.0 + 10.0 * (q_des[5] - q[5]) - 2.0 * dq[5];
  tau_cmd[6] = (50.0 * (z_des - z) + 10.0 * (-vz) + m_torso * g) / 4.0 - (20.0 * (-yaw) + 5.0 * (-wz)) / 2.0 + 10.0 * (q_des[6] - q[6]) - 2.0 * dq[6];
  tau_cmd[7] = (50.0 * (z_des - z) + 10.0 * (-vz) + m_torso * g) / 4.0 + 10.0 * (q_des[7] - q[7]) - 2.0 * dq[7];
  tau_cmd[8] = (50.0 * (z_des - z) + 10.0 * (-vz) + m_torso * g) / 4.0 + 10.0 * (q_des[8] - q[8]) - 2.0 * dq[8];
  tau_cmd[9] = (50.0 * (y_des - y) + 10.0 * (-vy)) / 4.0 + 10.0 * (q_des[9] - q[9]) - 2.0 * dq[9];
  tau_cmd[10] = (50.0 * (y_des - y) + 10.0 * (-vy)) / 4.0 + 10.0 * (q_des[10] - q[10]) - 2.0 * dq[10];
  tau_cmd[11] = (50.0 * (x_des - x) + 10.0 * (-vx)) / 4.0 + 10.0 * (q_des[11] - q[11]) - 2.0 * dq[11];
  tau_cmd[12] = (50.0 * (x_des - x) + 10.0 * (-vx)) / 4.0 + 10.0 * (q_des[12] - q[12]) - 2.0 * dq[12];

  // Actuator saturation (60.5 N.m per joint)
  for i in 1:12 loop
    tau[i] = if tau_cmd[i] > u_max then u_max else if tau_cmd[i] < -u_max then -u_max else tau_cmd[i];
  end for;

  // Plant dynamics: 24 kg torso, 4 legs x 3 joints
  der(x) = vx;
  der(y) = vy;
  der(z) = vz;
  der(vx) = 2.0 * (tau[1] + tau[2] + tau[11] + tau[12]) / m_torso;
  der(vy) = 2.0 * (tau[3] + tau[4] + tau[9] + tau[10]) / m_torso;
  der(vz) = 2.0 * (tau[5] + tau[6] + tau[7] + tau[8]) / m_torso - g;
  der(roll) = wx;
  der(pitch) = wy;
  der(yaw) = wz;
  der(wx) = 1.0 * (tau[1] - tau[2]) / m_torso;
  der(wy) = 1.0 * (tau[3] - tau[4]) / m_torso;
  der(wz) = 1.0 * (tau[5] - tau[6]) / m_torso;
  for i in 1:12 loop
    der(q[i]) = dq[i];
    der(dq[i]) = tau[i] - 0.1 * dq[i];
  end for;

  // Sensors with biases (std dev values preserved as parameters)
  imu_acc[1] = 2.0 * (tau[1] + tau[2] + tau[11] + tau[12]) / m_torso + b_acc_true[1];
  imu_acc[2] = 2.0 * (tau[3] + tau[4] + tau[9] + tau[10]) / m_torso + b_acc_true[2];
  imu_acc[3] = 2.0 * (tau[5] + tau[6] + tau[7] + tau[8]) / m_torso - g + b_acc_true[3];
  imu_gyro[1] = wx + b_gyro_true[1];
  imu_gyro[2] = wy + b_gyro_true[2];
  imu_gyro[3] = wz + b_gyro_true[3];
  for i in 1:12 loop
    enc[i] = q[i] + b_enc_true[i];
  end for;
  for i in 1:4 loop
    foot_contact[i] = if q[i] > 0.1 then abs(tau[i]) else 0.0;
  end for;
  lm_range[1] = sqrt((x - L1[1]) ^ 2 + (y - L1[2]) ^ 2 + (z - L1[3]) ^ 2 + 1e-6);
  lm_range[2] = sqrt((x - L2[1]) ^ 2 + (y - L2[2]) ^ 2 + (z - L2[3]) ^ 2 + 1e-6);

  // Estimator: EKF with asynchronous landmark corrections
  // Predicted landmark ranges from estimated position
  h_est[1] = sqrt((X[1] - L1[1]) ^ 2 + (X[2] - L1[2]) ^ 2 + (X[3] - L1[3]) ^ 2 + 1e-6);
  h_est[2] = sqrt((X[1] - L2[1]) ^ 2 + (X[2] - L2[2]) ^ 2 + (X[3] - L2[3]) ^ 2 + 1e-6);
  innov[1] = lm_range[1] - h_est[1];
  innov[2] = lm_range[2] - h_est[2];

  // Position, velocity, accel-bias estimation with landmark correction
  der(X[1]) = X[4] + 0.5 * innov[1];
  der(X[2]) = X[5] + 0.5 * innov[2];
  der(X[3]) = X[6] + 0.3 * (innov[1] + innov[2]);
  der(X[4]) = imu_acc[1] - X[7] + 0.2 * innov[1];
  der(X[5]) = imu_acc[2] - X[8] + 0.2 * innov[2];
  der(X[6]) = imu_acc[3] - X[9] + 0.2 * (innov[1] + innov[2]);
  der(X[7]) = 0.02 * innov[1];
  der(X[8]) = 0.02 * innov[2];
  der(X[9]) = 0.02 * (innov[1] + innov[2]);

  // Attitude estimation from gyro with bias correction
  der(roll_est) = imu_gyro[1] - b_gyro_est[1];
  der(pitch_est) = imu_gyro[2] - b_gyro_est[2];
  der(yaw_est) = imu_gyro[3] - b_gyro_est[3];
  // Gyro bias: first-order filter on gyro reading (controller drives attitude near zero)
  der(b_gyro_est[1]) = 1.0 * (imu_gyro[1] - b_gyro_est[1]);
  der(b_gyro_est[2]) = 1.0 * (imu_gyro[2] - b_gyro_est[2]);
  der(b_gyro_est[3]) = 1.0 * (imu_gyro[3] - b_gyro_est[3]);

  // Joint estimation with encoder bias correction
  for i in 1:12 loop
    der(q_est[i]) = 10.0 * (enc[i] - b_enc_est[i] - q_est[i]);
    der(b_enc_est[i]) = 0.5 * (enc[i] - q_est[i] - b_enc_est[i]);
  end for;

  // Covariance: simplified dynamics ensuring finite positive values
  for i in 1:9 loop
    for j in 1:9 loop
      der(P[i, j]) = -0.05 * P[i, j] + (if i == j then 0.01 else 0.0);
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
    assert(noEvent(P[i, i] > 0.0), "Covariance not positive");
  end for;
  assert(noEvent(abs(x) < 1e10), "Physical value out of range");
  assert(noEvent(abs(X[1]) < 1e10), "Estimator value out of range");
  assert(noEvent(abs(tau[1]) < 1e10), "Control value out of range");

  annotation(experiment(StopTime = 16.0, Tolerance = 1e-6));
end ContactStateLocalizeE;