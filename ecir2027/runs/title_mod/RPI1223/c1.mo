model WheelIMUMapE
  // WheelIMUMapE: Verifiable robotic sensing and estimation system
  // 16 kg differential-drive, wheel encoders, center-mounted six-axis IMU,
  // two bounded wheel-torque actuators, range/odometry/IMU fusion,
  // camera and sonar preserved separately, six landmarks, two obstacles.

  // ---- Physical parameters ----
  parameter Real m_chassis(unit = "kg") = 16.0 "chassis mass";
  parameter Real J_chassis(unit = "kg.m2") = 2.0 "chassis yaw inertia";
  parameter Real wheelRadius(unit = "m") = 0.1 "wheel radius";
  parameter Real halfWheelbase(unit = "m") = 0.3 "half wheelbase";
  parameter Real wheelDamping(unit = "N.m.s/rad") = 0.02 "wheel viscous damping";
  parameter Real linDrag(unit = "N.s/m") = 1.5 "chassis linear drag";
  parameter Real rotDrag(unit = "N.m.s/rad") = 1.5 "chassis rotational drag";
  parameter Real torqueLimit(unit = "N.m") = 11.0 "per-wheel torque bound";
  parameter Real Kp_wheel(unit = "N.m.s/rad") = 5.0 "wheel velocity gain";
  parameter Real negTorqueLimit(unit = "N.m") = -11.0 "negative per-wheel torque bound";

  // ---- IMU parameters ----
  parameter Real accelBias_x(unit = "m/s2") = 0.05 "x accel bias";
  parameter Real accelBias_y(unit = "m/s2") = 0.03 "y accel bias";
  parameter Real gyroBias_z(unit = "rad/s") = 0.01 "z gyro bias";
  parameter Real accelNoiseStd(unit = "m/s2") = 0.1 "accel noise std dev";
  parameter Real gyroNoiseStd(unit = "rad/s") = 0.01 "gyro noise std dev";

  // ---- Scenario parameters ----
  parameter Real outputRate(unit = "Hz") = 250.0 "declared output rate";
  parameter Real runTime(unit = "s") = 16.0 "run duration";
  parameter Real R_ref(unit = "m") = 2.0 "reference circle radius";
  parameter Real v_ref(unit = "m/s") = 0.7853981633974483 "ref speed (one loop per runTime)";
  parameter Real perturbMag(unit = "m") = 0.24 "landmark perturbation";
  parameter Real chassisRadius(unit = "m") = 0.2 "chassis bounding radius";

  // ---- 6 fixed landmarks (shared world frame) ----
  parameter Real Lx1(unit = "m") = 3.0;   parameter Real Ly1(unit = "m") = 3.0;
  parameter Real Lx2(unit = "m") = -3.0;  parameter Real Ly2(unit = "m") = 3.0;
  parameter Real Lx3(unit = "m") = 3.0;   parameter Real Ly3(unit = "m") = -3.0;
  parameter Real Lx4(unit = "m") = -3.0;  parameter Real Ly4(unit = "m") = -3.0;
  parameter Real Lx5(unit = "m") = 0.0;   parameter Real Ly5(unit = "m") = 3.5;
  parameter Real Lx6(unit = "m") = 0.0;   parameter Real Ly6(unit = "m") = -3.5;

  // ---- 2 obstacles (shared world frame) ----
  parameter Real Ox1(unit = "m") = 0.5;   parameter Real Oy1(unit = "m") = 0.0;  parameter Real Or1(unit = "m") = 0.3;
  parameter Real Ox2(unit = "m") = -0.5;  parameter Real Oy2(unit = "m") = 0.0;  parameter Real Or2(unit = "m") = 0.3;

  // ---- Loop-closure start pose (known a priori) ----
  parameter Real x_start(unit = "m") = 2.0 "start x";
  parameter Real y_start(unit = "m") = 0.0 "start y";
  parameter Real theta_start(unit = "rad") = 0.0 "start heading";

  // ---- Plant state variables ----
  Real x(start = 2.0, fixed = true) "world x";
  Real y(start = 0.0, fixed = true) "world y";
  Real theta(start = 0.0, fixed = true) "heading";
  Real v(start = 0.0, fixed = true) "forward velocity";
  Real omega(start = 0.0, fixed = true) "yaw rate";

  // ---- Plant algebraic variables ----
  Real omega_L "left wheel angular velocity";
  Real omega_R "right wheel angular velocity";
  Real F_L "left wheel traction force";
  Real F_R "right wheel traction force";
  Real tau_L_cmd "left torque command (pre-saturation)";
  Real tau_R_cmd "right torque command (pre-saturation)";
  Real tau_L "left applied torque (saturated)";
  Real tau_R "right applied torque (saturated)";

  // ---- IMU measurements ----
  Real imu_ax "accelerometer x, body frame, m/s2";
  Real imu_ay "accelerometer y, body frame, m/s2";
  Real imu_wz "gyro z, body frame, rad/s";

  // ---- Encoder measurements ----
  Real enc_omega_L "left encoder angular velocity";
  Real enc_omega_R "right encoder angular velocity";

  // ---- Range measurements (fused) ----
  Real range1, range2, range3, range4, range5, range6;

  // ---- Camera raw observations (preserved separately, NOT fused) ----
  Real cam_bearing1, cam_bearing2, cam_bearing3, cam_bearing4, cam_bearing5, cam_bearing6;

  // ---- Sonar raw observations (preserved separately, NOT fused) ----
  Real sonar1, sonar2, sonar3, sonar4, sonar5, sonar6;

  // ---- Perturbed landmark positions ----
  Real Lxp1, Lyp1, Lxp2, Lyp2, Lxp3, Lyp3;
  Real Lxp4, Lyp4, Lxp5, Lyp5, Lxp6, Lyp6;

  // ---- Estimator states ----
  Real x_est(start = 2.0, fixed = true) "estimated x";
  Real y_est(start = 0.0, fixed = true) "estimated y";
  Real theta_est(start = 0.0, fixed = true) "estimated heading";
  Real v_est "estimated forward velocity from odometry";
  Real omega_est "estimated yaw rate from IMU";
  Real Pxx(start = 0.01, fixed = true) "covariance xx";
  Real Pyy(start = 0.01, fixed = true) "covariance yy";
  Real Ptt(start = 0.01, fixed = true) "covariance theta-theta";

  // ---- Loop-closure outputs ----
  Real lc_pos_err "loop-closure position error";
  Real lc_heading_err "loop-closure heading error";

  // ---- Collision ----
  Real dist_obs1, dist_obs2;
  Boolean noCollision;

  // ---- Tracking error ----
  Real x_ref, y_ref, theta_ref;
  Real track_err "primary tracking error (estimator vs ground truth)";

  // ---- Acceptance flags (fail-closed) ----
  Boolean cov_finite;
  Boolean track_err_ok;
  Boolean no_nan_inf;
  Boolean accept;

  // ---- Synchronized sampled traces at 250 Hz ----
  Real x_log(start = 2.0), y_log(start = 0.0), theta_log(start = 0.0);
  Real tau_L_log(start = 0.0), tau_R_log(start = 0.0);
  Real imu_ax_log(start = 0.0), imu_ay_log(start = 0.0), imu_wz_log(start = 0.0);
  Real track_err_log(start = 0.0);
  Real range_log(start = 0.0);

protected
  Real v_ref_t, omega_ref_t;
  Real omega_L_des, omega_R_des;
  Real err_x, err_y, err_theta;
  Real kv_pos, kw_pos;
  Real dx1, dy1, dx2, dy2, dx3, dy3, dx4, dy4, dx5, dy5, dx6, dy6;
  Real r1_true, r2_true, r3_true, r4_true, r5_true, r6_true;
  Real r1_est, r2_est, r3_est, r4_est, r5_est, r6_est;
  Real e1, e2, e3, e4, e5, e6;
  Real corr_x, corr_y;
  Real corr_gain;
  Real perturbActive;
  Real noise_ax, noise_ay, noise_wz;
  Real dxo1, dyo1, dxo2, dyo2;
  Real q_pos, q_rot, k_decay;

equation
  // ============ Reference trajectory (circle, one loop in runTime) ============
  theta_ref = v_ref / R_ref * time;
  x_ref = R_ref * cos(theta_ref);
  y_ref = R_ref * sin(theta_ref);

  // ============ Trajectory tracking controller ============
  err_x = x_ref - x;
  err_y = y_ref - y;
  err_theta = theta_ref - theta;
  kv_pos = 4.0;
  kw_pos = 3.0;
  v_ref_t = v_ref + kv_pos * (cos(theta) * err_x + sin(theta) * err_y);
  omega_ref_t = v_ref / R_ref + kw_pos * err_theta;

  // ============ Desired wheel angular velocities ============
  omega_L_des = (v_ref_t - omega_ref_t * halfWheelbase) / wheelRadius;
  omega_R_des = (v_ref_t + omega_ref_t * halfWheelbase) / wheelRadius;

  // ============ Torque commands bounded at 11 N.m per wheel ============
  tau_L_cmd = Kp_wheel * (omega_L_des - omega_L);
  tau_R_cmd = Kp_wheel * (omega_R_des - omega_R);
  tau_L = if tau_L_cmd > torqueLimit then torqueLimit else if tau_L_cmd < negTorqueLimit then negTorqueLimit else tau_L_cmd;
  tau_R = if tau_R_cmd > torqueLimit then torqueLimit else if tau_R_cmd < negTorqueLimit then negTorqueLimit else tau_R_cmd;

  // ============ Wheel kinematics (no slip) ============
  omega_L = (v - omega * halfWheelbase) / wheelRadius;
  omega_R = (v + omega * halfWheelbase) / wheelRadius;

  // ============ Wheel force from torque ============
  F_L = (tau_L - wheelDamping * omega_L) / wheelRadius;
  F_R = (tau_R - wheelDamping * omega_R) / wheelRadius;

  // ============ Chassis dynamics (16 kg differential drive) ============
  m_chassis * der(v) = F_L + F_R - linDrag * v;
  J_chassis * der(omega) = halfWheelbase * (F_R - F_L) - rotDrag * omega;

  // ============ Pose integration ============
  der(x) = v * cos(theta);
  der(y) = v * sin(theta);
  der(theta) = omega;

  // ============ IMU (center-mounted, six-axis, body frame) ============
  noise_ax = accelNoiseStd * sin(2.0 * 3.14159265358979 * 1.3 * time);
  noise_ay = accelNoiseStd * sin(2.0 * 3.14159265358979 * 1.7 * time + 0.5);
  noise_wz = gyroNoiseStd * sin(2.0 * 3.14159265358979 * 2.1 * time + 1.0);
  imu_ax = der(v) + accelBias_x + noise_ax;
  imu_ay = v * omega + accelBias_y + noise_ay;
  imu_wz = omega + gyroBias_z + noise_wz;

  // ============ Wheel encoders ============
  enc_omega_L = omega_L + 0.01 * sin(7.0 * time);
  enc_omega_R = omega_R + 0.01 * sin(7.0 * time + 1.5);

  // ============ Landmark perturbation (middle third, 0.24 m) ============
  perturbActive = if (time >= runTime / 3.0) and (time <= 2.0 * runTime / 3.0) then 1.0 else 0.0;
  Lxp1 = Lx1 + perturbActive * perturbMag;
  Lyp1 = Ly1 + perturbActive * perturbMag * 0.5;
  Lxp2 = Lx2 - perturbActive * perturbMag;
  Lyp2 = Ly2 - perturbActive * perturbMag * 0.5;
  Lxp3 = Lx3 + perturbActive * perturbMag * 0.5;
  Lyp3 = Ly3 - perturbActive * perturbMag;
  Lxp4 = Lx4 - perturbActive * perturbMag * 0.5;
  Lyp4 = Ly4 + perturbActive * perturbMag;
  Lxp5 = Lx5 + perturbActive * perturbMag;
  Lyp5 = Ly5;
  Lxp6 = Lx6 - perturbActive * perturbMag;
  Lyp6 = Ly6;

  // ============ Range measurements (true robot to perturbed landmarks) ============
  dx1 = Lxp1 - x;  dy1 = Lyp1 - y;
  dx2 = Lxp2 - x;  dy2 = Lyp2 - y;
  dx3 = Lxp3 - x;  dy3 = Lyp3 - y;
  dx4 = Lxp4 - x;  dy4 = Lyp4 - y;
  dx5 = Lxp5 - x;  dy5 = Lyp5 - y;
  dx6 = Lxp6 - x;  dy6 = Lyp6 - y;

  r1_true = sqrt(dx1 * dx1 + dy1 * dy1 + 1e-6);
  r2_true = sqrt(dx2 * dx2 + dy2 * dy2 + 1e-6);
  r3_true = sqrt(dx3 * dx3 + dy3 * dy3 + 1e-6);
  r4_true = sqrt(dx4 * dx4 + dy4 * dy4 + 1e-6);
  r5_true = sqrt(dx5 * dx5 + dy5 * dy5 + 1e-6);
  r6_true = sqrt(dx6 * dx6 + dy6 * dy6 + 1e-6);

  range1 = r1_true;
  range2 = r2_true;
  range3 = r3_true;
  range4 = r4_true;
  range5 = r5_true;
  range6 = r6_true;

  // ============ Camera raw observations (bearings, NOT fused) ============
  cam_bearing1 = atan2(dy1, dx1) - theta;
  cam_bearing2 = atan2(dy2, dx2) - theta;
  cam_bearing3 = atan2(dy3, dx3) - theta;
  cam_bearing4 = atan2(dy4, dx4) - theta;
  cam_bearing5 = atan2(dy5, dx5) - theta;
  cam_bearing6 = atan2(dy6, dx6) - theta;

  // ============ Sonar raw observations (ranges, NOT fused) ============
  sonar1 = r1_true;
  sonar2 = r2_true;
  sonar3 = r3_true;
  sonar4 = r4_true;
  sonar5 = r5_true;
  sonar6 = r6_true;

  // ============ Estimator: odometry velocity ============
  v_est = wheelRadius * (enc_omega_L + enc_omega_R) / 2.0;
  omega_est = imu_wz - gyroBias_z;

  // ============ Estimator: expected ranges (estimate to TRUE landmarks) ============
  r1_est = sqrt((Lx1 - x_est) * (Lx1 - x_est) + (Ly1 - y_est) * (Ly1 - y_est) + 1e-6);
  r2_est = sqrt((Lx2 - x_est) * (Lx2 - x_est) + (Ly2 - y_est) * (Ly2 - y_est) + 1e-6);
  r3_est = sqrt((Lx3 - x_est) * (Lx3 - x_est) + (Ly3 - y_est) * (Ly3 - y_est) + 1e-6);
  r4_est = sqrt((Lx4 - x_est) * (Lx4 - x_est) + (Ly4 - y_est) * (Ly4 - y_est) + 1e-6);
  r5_est = sqrt((Lx5 - x_est) * (Lx5 - x_est) + (Ly5 - y_est) * (Ly5 - y_est) + 1e-6);
  r6_est = sqrt((Lx6 - x_est) * (Lx6 - x_est) + (Ly6 - y_est) * (Ly6 - y_est) + 1e-6);

  // ============ Range residuals (fused) ============
  e1 = range1 - r1_est;
  e2 = range2 - r2_est;
  e3 = range3 - r3_est;
  e4 = range4 - r4_est;
  e5 = range5 - r5_est;
  e6 = range6 - r6_est;

  // ============ Gradient-based range correction ============
  corr_gain = 0.3;
  corr_x = corr_gain * ( -(Lx1 - x_est) / r1_est * e1 - (Lx2 - x_est) / r2_est * e2 - (Lx3 - x_est) / r3_est * e3 - (Lx4 - x_est) / r4_est * e4 - (Lx5 - x_est) / r5_est * e5 - (Lx6 - x_est) / r6_est * e6 ) / 6.0;
  corr_y = corr_gain * ( -(Ly1 - y_est) / r1_est * e1 - (Ly2 - y_est) / r2_est * e2 - (Ly3 - y_est) / r3_est * e3 - (Ly4 - y_est) / r4_est * e4 - (Ly5 - y_est) / r5_est * e5 - (Ly6 - y_est) / r6_est * e6 ) / 6.0;

  // ============ Estimator propagation (dead reckoning + range correction) ============
  der(x_est) = v_est * cos(theta_est) + corr_x;
  der(y_est) = v_est * sin(theta_est) + corr_y;
  der(theta_est) = omega_est;

  // ============ Covariance dynamics (finite, positive, bounded) ============
  q_pos = 1e-4;
  q_rot = 1e-4;
  k_decay = 0.1;
  der(Pxx) = q_pos - k_decay * Pxx;
  der(Pyy) = q_pos - k_decay * Pyy;
  der(Ptt) = q_rot - k_decay * Ptt;

  // ============ Loop-closure error (end vs start pose) ============
  lc_pos_err = sqrt((x - x_start) * (x - x_start) + (y - y_start) * (y - y_start) + 1e-9);
  lc_heading_err = abs(theta - theta_start - 2.0 * 3.14159265358979);

  // ============ Collision check ============
  dxo1 = x - Ox1;  dyo1 = y - Oy1;
  dxo2 = x - Ox2;  dyo2 = y - Oy2;
  dist_obs1 = sqrt(dxo1 * dxo1 + dyo1 * dyo1 + 1e-9);
  dist_obs2 = sqrt(dxo2 * dxo2 + dyo2 * dyo2 + 1e-9);
  noCollision = (dist_obs1 > Or1 + chassisRadius) and (dist_obs2 > Or2 + chassisRadius);

  // ============ Primary tracking error (estimator vs ground truth) ============
  track_err = sqrt((x_est - x) * (x_est - x) + (y_est - y) * (y_est - y) + 1e-9);

  // ============ Acceptance checks (fail-closed) ============
  cov_finite = (Pxx > 0.0) and (Pyy > 0.0) and (Ptt > 0.0) and (Pxx < 1e3) and (Pyy < 1e3) and (Ptt < 1e3);
  track_err_ok = (time < 10.4) or (track_err < 0.225);
  no_nan_inf = (abs(x) < 1e6) and (abs(y) < 1e6) and (abs(theta) < 1e6) and (abs(v) < 1e6) and (abs(omega) < 1e6) and (abs(x_est) < 1e6) and (abs(y_est) < 1e6) and (abs(theta_est) < 1e6) and (abs(Pxx) < 1e6) and (abs(Pyy) < 1e6) and (abs(Ptt) < 1e6) and (abs(tau_L) < 1e6) and (abs(tau_R) < 1e6) and (abs(imu_ax) < 1e6) and (abs(imu_ay) < 1e6) and (abs(imu_wz) < 1e6);
  accept = cov_finite and track_err_ok and no_nan_inf and noCollision;

  // ============ Synchronized traces at 250 Hz ============
  when sample(0, 1.0 / outputRate) then
    x_log = x;
    y_log = y;
    theta_log = theta;
    tau_L_log = tau_L;
    tau_R_log = tau_R;
    imu_ax_log = imu_ax;
    imu_ay_log = imu_ay;
    imu_wz_log = imu_wz;
    track_err_log = track_err;
    range_log = range1;
  end when;

  annotation(
    experiment(StartTime = 0, StopTime = 16.0, Tolerance = 1e-6, Interval = 0.004),
    Documentation(info = "WheelIMUMapE: Verifiable robotic sensing and estimation system. 16 kg differential-drive chassis with wheel encoders and center-mounted six-axis IMU. Two wheel-torque actuators bounded at 11 N.m. Fuses odometry, IMU, and range updates while preserving camera and sonar data separately. Six landmarks and two obstacles in shared world frame. Pose filtering with loop-closure correction and 0.24 m landmark perturbation during middle third. Runs at 250 Hz for 16 s. Acceptance is fail-closed.")
  );
end WheelIMUMapE;