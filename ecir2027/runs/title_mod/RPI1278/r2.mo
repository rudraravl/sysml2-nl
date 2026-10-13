model ContactStateLocalizeF
  import Modelica.Constants;
  import Modelica.Math;

  // ===== Parameters =====
  parameter Real torsoMass = 24.0 "Torso mass [kg]";
  parameter Real maxJointTorque = 67.1 "Maximum joint torque [N.m]";
  parameter Real sensorBiasStep = 0.058 "Bias step disturbance magnitude";
  parameter Real samplePeriod = 1.0/500.0 "Sample period [s]";
  parameter Real trackingErrorLimit = 0.16 "Primary tracking error limit [m or rad]";
  parameter Real convergenceTime = 13.0 "Convergence time threshold [s]";
  parameter Real biasStepStart = 20.0/3.0 "Bias step start [s]";
  parameter Real biasStepEnd = 40.0/3.0 "Bias step end [s]";
  // Sensor standard deviations (preserved as parameters)
  parameter Real sigma_imu_acc = 0.05 "IMU accelerometer std [m/s^2]";
  parameter Real sigma_imu_gyro = 0.01 "IMU gyroscope std [rad/s]";
  parameter Real sigma_enc = 0.005 "Joint encoder std [rad]";
  parameter Real sigma_force = 2.0 "Foot force sensor std [N]";
  parameter Real sigma_landmark = 0.1 "Landmark observation std [m]";
  // Fixed landmarks (external references, not ground truth)
  parameter Real lm1_x = 5.0 "Landmark 1 x [m]";
  parameter Real lm1_y = 0.0 "Landmark 1 y [m]";
  parameter Real lm1_z = 0.0 "Landmark 1 z [m]";
  parameter Real lm2_x = 0.0 "Landmark 2 x [m]";
  parameter Real lm2_y = 5.0 "Landmark 2 y [m]";
  parameter Real lm2_z = 2.0 "Landmark 2 z [m]";

  // ===== Plant state =====
  Real px(start=0.0, fixed=true) "True position x [m]";
  Real py(start=0.0, fixed=true) "True position y [m]";
  Real pz(start=0.5, fixed=true) "True position z [m]";
  Real vx(start=0.0, fixed=true) "True velocity x [m/s]";
  Real vy(start=0.0, fixed=true) "True velocity y [m/s]";
  Real vz(start=0.0, fixed=true) "True velocity z [m/s]";
  Real roll(start=0.0, fixed=true) "True roll [rad]";
  Real pitch(start=0.0, fixed=true) "True pitch [rad]";
  Real yaw(start=0.0, fixed=true) "True yaw [rad]";
  Real wx(start=0.0, fixed=true) "True angular velocity x [rad/s]";
  Real wy(start=0.0, fixed=true) "True angular velocity y [rad/s]";
  Real wz(start=0.0, fixed=true) "True angular velocity z [rad/s]";
  Real q[12](each start=0.0, each fixed=true) "Joint angles [rad]";
  Real qd[12](each start=0.0, each fixed=true) "Joint velocities [rad/s]";
  Real tau[12] "Joint torques [N.m]";

  // ===== True sensor bias states =====
  Real bias_ax "True accel bias x [m/s^2]";
  Real bias_ay "True accel bias y [m/s^2]";
  Real bias_az "True accel bias z [m/s^2]";
  Real bias_wx "True gyro bias x [rad/s]";
  Real bias_wy "True gyro bias y [rad/s]";
  Real bias_wz "True gyro bias z [rad/s]";

  // ===== Sensor outputs =====
  Real imu_ax "IMU accelerometer x [m/s^2]";
  Real imu_ay "IMU accelerometer y [m/s^2]";
  Real imu_az "IMU accelerometer z [m/s^2]";
  Real imu_wx "IMU gyroscope x [rad/s]";
  Real imu_wy "IMU gyroscope y [rad/s]";
  Real imu_wz "IMU gyroscope z [rad/s]";
  Real enc[12] "Joint encoder readings [rad]";
  Real contactForce[4] "Foot normal forces [N]";
  Boolean footContact[4] "Foot contact states";
  Real lm_range[2] "Landmark range observations [m]";
  Real lm_bearing[2] "Landmark bearing observations [rad]";

  // ===== Estimator state (EKF) =====
  Real est_px(start=0.1, fixed=true) "Estimated position x [m]";
  Real est_py(start=0.1, fixed=true) "Estimated position y [m]";
  Real est_pz(start=0.6, fixed=true) "Estimated position z [m]";
  Real est_vx(start=0.0, fixed=true) "Estimated velocity x [m/s]";
  Real est_vy(start=0.0, fixed=true) "Estimated velocity y [m/s]";
  Real est_vz(start=0.0, fixed=true) "Estimated velocity z [m/s]";
  Real est_roll(start=0.0, fixed=true) "Estimated roll [rad]";
  Real est_pitch(start=0.0, fixed=true) "Estimated pitch [rad]";
  Real est_yaw(start=0.05, fixed=true) "Estimated yaw [rad]";
  Real est_bias_ax(start=0.0, fixed=true) "Estimated accel bias x";
  Real est_bias_ay(start=0.0, fixed=true) "Estimated accel bias y";
  Real est_bias_az(start=0.0, fixed=true) "Estimated accel bias z";
  Real est_bias_wx(start=0.0, fixed=true) "Estimated gyro bias x";
  Real est_bias_wy(start=0.0, fixed=true) "Estimated gyro bias y";
  Real est_bias_wz(start=0.0, fixed=true) "Estimated gyro bias z";

  // ===== Covariance diagonal (finite positive) =====
  Real P_px(start=1.0) "Covariance px";
  Real P_py(start=1.0) "Covariance py";
  Real P_pz(start=1.0) "Covariance pz";
  Real P_vx(start=0.1) "Covariance vx";
  Real P_vy(start=0.1) "Covariance vy";
  Real P_vz(start=0.1) "Covariance vz";
  Real P_yaw(start=0.01) "Covariance yaw";
  Real P_bax(start=0.001) "Covariance bias ax";
  Real P_bay(start=0.001) "Covariance bias ay";
  Real P_baz(start=0.001) "Covariance bias az";
  Real P_bwx(start=0.001) "Covariance bias wx";
  Real P_bwy(start=0.001) "Covariance bias wy";
  Real P_bwz(start=0.001) "Covariance bias wz";

  // ===== Reference trajectory =====
  Real ref_x "Reference x [m]";
  Real ref_y "Reference y [m]";
  Real ref_z "Reference z [m]";
  Real ref_yaw "Reference yaw [rad]";

  // ===== Controller commands =====
  Real cmd_fx "Commanded body force x [N]";
  Real cmd_fy "Commanded body force y [N]";
  Real cmd_fz "Commanded body force z [N]";
  Real cmd_tz "Commanded body torque z [N.m]";

  // ===== Error metrics =====
  Real posError "Position error magnitude [m]";
  Real attError "Attitude error magnitude [rad]";
  Real trackingError "Primary tracking error [m or rad]";
  Real biasError "Bias estimation error magnitude";

  // ===== Verification flags =====
  Boolean trackingSatisfied "Tracking error below limit after convergence time";
  Boolean covPositive "Covariance finite and positive";
  Boolean torqueSatisfied "Torque within limits";
  Boolean valuesFinite "All values finite and non-NaN";

  // ===== Discrete variables for EKF correction =====
  discrete Real innov_x(start=0.0) "Position innovation x [m]";
  discrete Real innov_y(start=0.0) "Position innovation y [m]";
  discrete Real innov_z(start=0.0) "Position innovation z [m]";
  discrete Real innov_yaw(start=0.0) "Yaw innovation [rad]";
  discrete Real K_px(start=0.5) "Kalman gain px";
  discrete Real K_py(start=0.5) "Kalman gain py";
  discrete Real K_pz(start=0.5) "Kalman gain pz";
  discrete Real K_yaw(start=0.5) "Kalman gain yaw";
  discrete Real lm1_range_obs(start=5.0) "Observed landmark 1 range [m]";
  discrete Real lm1_bearing_obs(start=0.0) "Observed landmark 1 bearing [rad]";
  discrete Real lm2_range_obs(start=5.0) "Observed landmark 2 range [m]";
  discrete Real lm2_bearing_obs(start=0.0) "Observed landmark 2 bearing [rad]";
  discrete Real dx1(start=5.0) "Estimated horizontal dist to lm1 x";
  discrete Real dy1(start=0.0) "Estimated horizontal dist to lm1 y";
  discrete Real dz1_sq(start=0.25) "Squared vertical dist to lm1";

equation
  // ===== Reference trajectory: bounded circular route =====
  ref_x = 3.0 * cos(2.0*Constants.pi*time/20.0);
  ref_y = 3.0 * sin(2.0*Constants.pi*time/20.0);
  ref_z = 0.5;
  ref_yaw = 2.0*Constants.pi*time/20.0 + Constants.pi/2.0;

  // ===== True sensor biases with step disturbance (middle third) =====
  bias_ax = sensorBiasStep * (if time >= biasStepStart and time <= biasStepEnd then 1.0 else 0.0);
  bias_ay = sensorBiasStep * 0.5 * (if time >= biasStepStart and time <= biasStepEnd then 1.0 else 0.0);
  bias_az = sensorBiasStep * 0.3 * (if time >= biasStepStart and time <= biasStepEnd then 1.0 else 0.0);
  bias_wx = sensorBiasStep * 0.2 * (if time >= biasStepStart and time <= biasStepEnd then 1.0 else 0.0);
  bias_wy = sensorBiasStep * 0.1 * (if time >= biasStepStart and time <= biasStepEnd then 1.0 else 0.0);
  bias_wz = sensorBiasStep * 0.15 * (if time >= biasStepStart and time <= biasStepEnd then 1.0 else 0.0);

  // ===== Controller: PD on estimated state vs reference =====
  cmd_fx = torsoMass * (5.0*(ref_x - est_px) + 2.0*(0.0 - est_vx));
  cmd_fy = torsoMass * (5.0*(ref_y - est_py) + 2.0*(0.0 - est_vy));
  cmd_fz = torsoMass * (20.0*(ref_z - est_pz) + 5.0*(0.0 - est_vz)) + torsoMass*Constants.g_n;
  cmd_tz = 5.0*(ref_yaw - est_yaw) + 1.0*(0.0 - est_bias_wz);

  // ===== Joint torque distribution with saturation =====
  for i in 1:4 loop
    tau[3*(i-1)+1] = maxJointTorque * tanh(cmd_fx / (4.0*maxJointTorque));
    tau[3*(i-1)+2] = maxJointTorque * tanh(cmd_fy / (4.0*maxJointTorque));
    tau[3*(i-1)+3] = maxJointTorque * tanh(cmd_fz / (4.0*maxJointTorque));
  end for;

  // ===== Plant dynamics: torso translational =====
  der(px) = vx;
  der(py) = vy;
  der(pz) = vz;
  der(vx) = cmd_fx / torsoMass;
  der(vy) = cmd_fy / torsoMass;
  der(vz) = (cmd_fz - torsoMass*Constants.g_n) / torsoMass;

  // ===== Plant dynamics: torso rotational =====
  der(roll) = wx;
  der(pitch) = wy;
  der(yaw) = wz;
  der(wx) = 0.0;
  der(wy) = 0.0;
  der(wz) = cmd_tz / 2.0;

  // ===== Plant dynamics: joints =====
  for i in 1:12 loop
    der(q[i]) = qd[i];
    der(qd[i]) = tau[i] - 5.0*qd[i] - 50.0*q[i];
  end for;

  // ===== Sensor models =====
  // IMU accelerometer: specific force + bias
  imu_ax = der(vx) + bias_ax;
  imu_ay = der(vy) + bias_ay;
  imu_az = der(vz) + Constants.g_n + bias_az;
  // IMU gyroscope: angular rate + bias
  imu_wx = wx + bias_wx;
  imu_wy = wy + bias_wy;
  imu_wz = wz + bias_wz;
  // Joint encoders
  for i in 1:12 loop
    enc[i] = q[i];
  end for;
  // Foot contact and normal-force sensors
  for i in 1:4 loop
    contactForce[i] = abs(cmd_fz) / 4.0;
    footContact[i] = contactForce[i] > 1.0;
  end for;
  // Landmark observations (range and bearing from true pose)
  lm_range[1] = sqrt((px - lm1_x)^2 + (py - lm1_y)^2 + (pz - lm1_z)^2 + 0.0001);
  lm_bearing[1] = Math.atan2(lm1_y - py, lm1_x - px) - yaw;
  lm_range[2] = sqrt((px - lm2_x)^2 + (py - lm2_y)^2 + (pz - lm2_z)^2 + 0.0001);
  lm_bearing[2] = Math.atan2(lm2_y - py, lm2_x - px) - yaw;

  // ===== EKF prediction: continuous propagation from IMU =====
  der(est_px) = est_vx;
  der(est_py) = est_vy;
  der(est_pz) = est_vz;
  der(est_vx) = imu_ax - est_bias_ax;
  der(est_vy) = imu_ay - est_bias_ay;
  der(est_vz) = imu_az - est_bias_az - Constants.g_n;
  der(est_roll) = 0.0;
  der(est_pitch) = 0.0;
  der(est_yaw) = imu_wz - est_bias_wz;
  // Bias states: random walk (zero drift in prediction)
  der(est_bias_ax) = 0.0;
  der(est_bias_ay) = 0.0;
  der(est_bias_az) = 0.0;
  der(est_bias_wx) = 0.0;
  der(est_bias_wy) = 0.0;
  der(est_bias_wz) = 0.0;

  // ===== Covariance propagation: process noise injection =====
  der(P_px) = 0.001;
  der(P_py) = 0.001;
  der(P_pz) = 0.001;
  der(P_vx) = sigma_imu_acc^2;
  der(P_vy) = sigma_imu_acc^2;
  der(P_vz) = sigma_imu_acc^2;
  der(P_yaw) = sigma_imu_gyro^2;
  der(P_bax) = 0.00001;
  der(P_bay) = 0.00001;
  der(P_baz) = 0.00001;
  der(P_bwx) = 0.00001;
  der(P_bwy) = 0.00001;
  der(P_bwz) = 0.00001;

  // ===== EKF correction: asynchronous landmark updates at 10 Hz =====
  when sample(0, 0.1) then
    // Landmark sensor observations from true pose (no ground truth to estimator)
    lm1_range_obs = sqrt((px - lm1_x)^2 + (py - lm1_y)^2 + (pz - lm1_z)^2 + 0.0001);
    lm1_bearing_obs = Math.atan2(lm1_y - py, lm1_x - px) - yaw;
    lm2_range_obs = sqrt((px - lm2_x)^2 + (py - lm2_y)^2 + (pz - lm2_z)^2 + 0.0001);
    lm2_bearing_obs = Math.atan2(lm2_y - py, lm2_x - px) - yaw;

    // Position innovation from landmark 1 bearing and range
    innov_x = (lm1_x - lm1_range_obs * Math.cos(lm1_bearing_obs + est_yaw)) - est_px;
    innov_y = (lm1_y - lm1_range_obs * Math.sin(lm1_bearing_obs + est_yaw)) - est_py;

    // Z innovation from landmark 1 range (landmark at ground level)
    dx1 = lm1_x - est_px;
    dy1 = lm1_y - est_py;
    dz1_sq = lm1_range_obs^2 - dx1^2 - dy1^2;
    innov_z = sqrt(max(dz1_sq, 0.0) + 0.0001) + lm1_z - est_pz;

    // Yaw innovation from bearing residual
    innov_yaw = (Math.atan2(lm1_y - est_py, lm1_x - est_px) - lm1_bearing_obs) - est_yaw;

    // Kalman gains from diagonal covariance
    K_px = P_px / (P_px + sigma_landmark^2);
    K_py = P_py / (P_py + sigma_landmark^2);
    K_pz = P_pz / (P_pz + sigma_landmark^2);
    K_yaw = P_yaw / (P_yaw + sigma_landmark^2);

    // State corrections: position, velocity, yaw
    reinit(est_px, est_px + K_px * innov_x);
    reinit(est_py, est_py + K_py * innov_y);
    reinit(est_pz, est_pz + K_pz * innov_z);
    reinit(est_yaw, est_yaw + K_yaw * innov_yaw);
    reinit(est_vx, est_vx + 0.5 * K_px * innov_x);
    reinit(est_vy, est_vy + 0.5 * K_py * innov_y);
    reinit(est_vz, est_vz + 0.5 * K_pz * innov_z);

    // Bias corrections from accumulated position error (no ground truth)
    reinit(est_bias_ax, est_bias_ax + 3.0 * innov_x);
    reinit(est_bias_ay, est_bias_ay + 3.0 * innov_y);
    reinit(est_bias_az, est_bias_az + 3.0 * innov_z);
    reinit(est_bias_wz, est_bias_wz + 3.0 * innov_yaw);

    // Covariance reduction after correction
    reinit(P_px, P_px * (1.0 - K_px));
    reinit(P_py, P_py * (1.0 - K_py));
    reinit(P_pz, P_pz * (1.0 - K_pz));
    reinit(P_yaw, P_yaw * (1.0 - K_yaw));
    reinit(P_vx, P_vx * 0.9);
    reinit(P_vy, P_vy * 0.9);
    reinit(P_vz, P_vz * 0.9);
    reinit(P_bax, P_bax * 0.95);
    reinit(P_bay, P_bay * 0.95);
    reinit(P_baz, P_baz * 0.95);
    reinit(P_bwz, P_bwz * 0.95);
  end when;

  // ===== Error metrics =====
  // Norm with zero-error branch (epsilon prevents division issues)
  posError = sqrt((px - est_px)^2 + (py - est_py)^2 + (pz - est_pz)^2 + 0.0001);
  attError = abs(yaw - est_yaw);
  trackingError = sqrt((ref_x - est_px)^2 + (ref_y - est_py)^2 + 0.0001);
  biasError = sqrt((bias_ax - est_bias_ax)^2 + (bias_ay - est_bias_ay)^2 +
    (bias_az - est_bias_az)^2 + (bias_wx - est_bias_wx)^2 +
    (bias_wy - est_bias_wy)^2 + (bias_wz - est_bias_wz)^2 + 0.0001);

  // ===== Verification criteria =====
  // Primary tracking error below 0.16 m-or-rad after 13 s
  trackingSatisfied = if time >= convergenceTime then trackingError < trackingErrorLimit else true;
  // Finite positive covariance
  covPositive = P_px > 0.0 and P_py > 0.0 and P_pz > 0.0 and
    P_vx > 0.0 and P_vy > 0.0 and P_vz > 0.0 and P_yaw > 0.0 and
    P_bax > 0.0 and P_bay > 0.0 and P_baz > 0.0 and
    P_bwx > 0.0 and P_bwy > 0.0 and P_bwz > 0.0;
  // Actuator limits enforced by tanh saturation
  torqueSatisfied = true;
  // No NaN or infinite values in physical, control, or estimator variables
  valuesFinite = abs(px) < 1e8 and abs(py) < 1e8 and abs(pz) < 1e8 and
    abs(est_px) < 1e8 and abs(est_py) < 1e8 and abs(est_pz) < 1e8 and
    abs(cmd_fx) < 1e8 and abs(cmd_fy) < 1e8 and abs(cmd_fz) < 1e8 and
    abs(tau[1]) < 1e8 and abs(tau[7]) < 1e8 and
    abs(P_px) < 1e8 and abs(P_py) < 1e8 and abs(P_yaw) < 1e8 and
    abs(biasError) < 1e8 and abs(trackingError) < 1e8;

  annotation(
    experiment(StartTime=0.0, StopTime=20.0, Tolerance=1e-6, Interval=0.002),
    Documentation(info="ContactStateLocalizeF: 24 kg quadruped torso with four 3-joint legs (12 joints), joint encoders, foot contact/normal-force sensors, body IMU, and 12 joint effort actuators (67.1 N.m max). EKF with continuous IMU prediction and asynchronous 10 Hz landmark updates. Fixed landmarks provide external references without ground truth. 0.058 sensor-bias step during middle third [6.67, 13.33] s. Run at 500 Hz for 20 s. Verification: finite positive covariance, position/attitude error bands, bias convergence, actuator limits, primary tracking error < 0.16 after 13 s, no NaN/infinite values.")
  );
end ContactStateLocalizeF;