model WheelIMUMapA
  import Modelica.Constants;
  import Modelica.Math;

  // ===== Physical parameters =====
  parameter Real m_chassis(unit="kg") = 16.0 "Chassis mass";
  parameter Real wheelRadius(unit="m") = 0.1 "Wheel radius";
  parameter Real wheelBase(unit="m") = 0.4 "Wheel base";
  parameter Real Izz(unit="kg.m2") = 1.28 "Yaw inertia";
  parameter Real tauMax(unit="N.m") = 7.2 "Max wheel torque command magnitude";
  parameter Real outputRate(unit="Hz") = 80.0 "Declared output rate";
  parameter Real dt_out(unit="s") = 1.0 / outputRate "Output sample period";

  // ===== IMU noise and bias parameters =====
  parameter Real imuAccelBias(unit="m/s2") = 0.05 "IMU accelerometer bias";
  parameter Real imuGyroBias(unit="rad/s") = 0.01 "IMU gyroscope bias";
  parameter Real imuAccelNoiseStd(unit="m/s2") = 0.1 "IMU accel noise std dev";
  parameter Real imuGyroNoiseStd(unit="rad/s") = 0.01 "IMU gyro noise std dev";
  parameter Real encNoiseStd(unit="rad/s") = 0.05 "Encoder noise std dev";
  parameter Real rangeNoiseStd(unit="m") = 0.05 "Range noise std dev";

  // ===== Controller gains =====
  parameter Real Kp_v = 80.0 "Velocity proportional gain";
  parameter Real Kp_w = 15.0 "Heading proportional gain";
  parameter Real Kd_w = 3.0 "Heading derivative gain";
  parameter Real damping_v = 1.0 "Linear damping coefficient";
  parameter Real damping_w = 0.5 "Angular damping coefficient";

  // ===== Estimator gains =====
  parameter Real Krange = 1.5 "Range correction gain";
  parameter Real Kloop = 3.0 "Loop closure position gain";
  parameter Real Kloop_t = 2.0 "Loop closure heading gain";

  // ===== Landmarks (6 fixed in shared world frame) =====
  parameter Real LMx[6] = {2.5, -2.5, 0.0, 3.0, -3.0, 1.5} "Landmark x [m]";
  parameter Real LMy[6] = {0.0, 0.0, 2.0, -1.5, 1.5, -2.0} "Landmark y [m]";
  parameter Real lmAngle[6] = {0.5, 1.2, 2.0, 2.8, 3.5, 4.2} "Perturbation direction [rad]";
  parameter Real rangeNoisePhase[6] = {0.0, 1.0, 2.0, 3.0, 4.0, 5.0} "Range noise phase [rad]";

  // ===== Obstacles (2 in shared world frame) =====
  parameter Real OBx[2] = {1.0, -1.0} "Obstacle x [m]";
  parameter Real OBy[2] = {-0.8, 0.8} "Obstacle y [m]";
  parameter Real OBr[2] = {0.25, 0.25} "Obstacle radius [m]";

  // ===== Path parameters =====
  constant Real w_path = 2.0 * Constants.pi / 8.0 "Path angular frequency [rad/s]";

  // ===== Plant states =====
  Real x(start=2.5, fixed=true, unit="m") "True x position";
  Real y(start=0.0, fixed=true, unit="m") "True y position";
  Real theta(start=1.5707963, fixed=true, unit="rad") "True heading";
  Real v(start=0.0, fixed=true, unit="m/s") "True forward velocity";
  Real omega(start=0.0, fixed=true, unit="rad/s") "True yaw rate";
  Real tauL_filt(start=0.0, fixed=true, unit="N.m") "Filtered left wheel torque";
  Real tauR_filt(start=0.0, fixed=true, unit="N.m") "Filtered right wheel torque";

  // ===== Reference trajectory =====
  Real x_ref(unit="m") "Reference x";
  Real y_ref(unit="m") "Reference y";
  Real theta_ref(unit="rad") "Reference heading";
  Real v_ref(unit="m/s") "Reference velocity magnitude";
  Real omega_ref(unit="rad/s") "Reference yaw rate";
  Real theta_err(unit="rad") "Wrapped heading tracking error";

  // ===== Commands =====
  Real tauL_cmd(unit="N.m") "Left wheel torque command";
  Real tauR_cmd(unit="N.m") "Right wheel torque command";
  Real tauL(unit="N.m") "Actual left wheel torque";
  Real tauR(unit="N.m") "Actual right wheel torque";
  Real F_des(unit="N") "Desired net force";
  Real M_des(unit="N.m") "Desired net moment";

  // ===== IMU raw observations (6-axis, preserved) =====
  Real imuAx_raw(unit="m/s2") "Raw IMU forward acceleration";
  Real imuAy_raw(unit="m/s2") "Raw IMU lateral acceleration";
  Real imuAz_raw(unit="m/s2") "Raw IMU vertical acceleration";
  Real imuWx_raw(unit="rad/s") "Raw IMU roll rate";
  Real imuWy_raw(unit="rad/s") "Raw IMU pitch rate";
  Real imuWz_raw(unit="rad/s") "Raw IMU yaw rate";

  // ===== Wheel encoder observations =====
  Real omegaL_enc(unit="rad/s") "Left wheel encoder angular velocity";
  Real omegaR_enc(unit="rad/s") "Right wheel encoder angular velocity";

  // ===== Range measurements (exteroceptive, fused into estimator) =====
  Real range_meas[6](each unit="m") "Fused range measurements to landmarks";

  // ===== Camera data (preserved separately, not fused) =====
  Real camera_data[6](each unit="rad") "Camera bearing to each landmark (preserved)";

  // ===== Sonar data (preserved separately, not fused) =====
  Real sonar_data[2](each unit="m") "Sonar range to each obstacle (preserved)";

  // ===== Estimator states (pose filter with loop closure) =====
  Real x_est(start=2.5, fixed=true, unit="m") "Estimated x";
  Real y_est(start=0.0, fixed=true, unit="m") "Estimated y";
  Real theta_est(start=1.5707963, fixed=true, unit="rad") "Estimated heading";
  Real v_est(start=0.0, fixed=true, unit="m/s") "Estimated velocity from odometry";
  Real omega_est(start=0.0, fixed=true, unit="rad/s") "Estimated yaw rate from IMU";

  // ===== Finite covariance (diagonal) =====
  Real Pxx(start=0.01, fixed=true, unit="m2") "Position x covariance";
  Real Pyy(start=0.01, fixed=true, unit="m2") "Position y covariance";
  Real Ptt(start=0.001, fixed=true, unit="rad2") "Heading covariance";

  // ===== Loop closure =====
  Real loopClosurePosErr(unit="m") "Loop-closure position error";
  Real loopClosureHeadErr(unit="rad") "Loop-closure heading error";
  Real loopClosureActive "Loop closure active flag (0 or 1)";
  Real lcCorr_x(unit="m/s") "Loop closure x correction rate";
  Real lcCorr_y(unit="m/s") "Loop closure y correction rate";
  Real lcCorr_t(unit="rad/s") "Loop closure heading correction rate";

  // ===== Tracking error =====
  Real trackErr(unit="m") "Primary tracking error (position)";

  // ===== Landmark perturbation =====
  Real perturbation(unit="m") "Applied landmark perturbation";
  Real LMx_p[6](each unit="m") "Perturbed landmark x";
  Real LMy_p[6](each unit="m") "Perturbed landmark y";

  // ===== Collision monitoring =====
  Real obsDist1(unit="m") "Distance to obstacle 1 center";
  Real obsDist2(unit="m") "Distance to obstacle 2 center";
  Real minObsClear(unit="m") "Minimum obstacle clearance";

  // ===== Noise signals =====
  Real n_ax "IMU accel x noise";
  Real n_wz "IMU gyro z noise";
  Real n_encL "Encoder left noise";
  Real n_encR "Encoder right noise";
  Real n_range[6] "Range measurement noise per landmark";

  // ===== Estimator intermediate variables =====
  Real rangeCorr_x(unit="m/s") "Range-based x correction";
  Real rangeCorr_y(unit="m/s") "Range-based y correction";
  Real r_exp[6](each unit="m") "Expected range from estimated pose";
  Real r_diff[6](each unit="m") "Range residual";
  Real ux[6] "Unit vector x from landmark to estimate";
  Real uy[6] "Unit vector y from landmark to estimate";

equation
  // ===== Reference trajectory: ellipse, period 8 s (closed route) =====
  x_ref = 2.5 * Math.cos(w_path * time);
  y_ref = 1.5 * Math.sin(w_path * time);

  // Reference velocity magnitude (analytical derivative)
  v_ref = Math.sqrt(max(
    (-2.5 * w_path * Math.sin(w_path * time))^2 +
    ( 1.5 * w_path * Math.cos(w_path * time))^2,
    1e-6));

  // Reference heading from velocity tangent
  theta_ref = Math.atan2(
    1.5 * w_path * Math.cos(w_path * time),
    -2.5 * w_path * Math.sin(w_path * time));

  // Reference yaw rate (analytical second derivative)
  omega_ref = (
    (-2.5 * w_path * Math.sin(w_path * time)) * (-1.5 * w_path * w_path * Math.sin(w_path * time))
    - (1.5 * w_path * Math.cos(w_path * time)) * (-2.5 * w_path * w_path * Math.cos(w_path * time)))
    / max(
      (-2.5 * w_path * Math.sin(w_path * time))^2 +
      (1.5 * w_path * Math.cos(w_path * time))^2,
      1e-6);

  // Wrapped heading error for control
  theta_err = Math.atan2(Math.sin(theta_ref - theta), Math.cos(theta_ref - theta));

  // ===== Controller (PD on velocity and heading) =====
  F_des = Kp_v * (v_ref - v);
  M_des = Kp_w * theta_err - Kd_w * omega;

  // Map to wheel torques with saturation
  tauL_cmd = max(-tauMax, min(tauMax, F_des * wheelRadius / 2.0 - M_des * wheelRadius / wheelBase));
  tauR_cmd = max(-tauMax, min(tauMax, F_des * wheelRadius / 2.0 + M_des * wheelRadius / wheelBase));

  // Torque actuator dynamics (first-order filter)
  der(tauL_filt) = (tauL_cmd - tauL_filt) / 0.02;
  der(tauR_filt) = (tauR_cmd - tauR_filt) / 0.02;
  tauL = tauL_filt;
  tauR = tauR_filt;

  // ===== Plant dynamics (differential drive) =====
  m_chassis * der(v) = (tauL + tauR) / wheelRadius - damping_v * v;
  Izz * der(omega) = (tauR - tauL) * wheelBase / (2.0 * wheelRadius) - damping_w * omega;
  der(x) = v * Math.cos(theta);
  der(y) = v * Math.sin(theta);
  der(theta) = omega;

  // ===== IMU raw observations (6-axis, center-mounted) =====
  n_ax = imuAccelNoiseStd * Math.sin(100.0 * time);
  n_wz = imuGyroNoiseStd * Math.sin(150.0 * time + 0.5);

  imuAx_raw = ((tauL + tauR) / wheelRadius - damping_v * v) / m_chassis + imuAccelBias + n_ax;
  imuAy_raw = omega * v + 0.5 * imuAccelBias + imuAccelNoiseStd * Math.cos(80.0 * time);
  imuAz_raw = 9.81 + 0.1 * imuAccelBias;
  imuWx_raw = 0.1 * imuGyroBias + imuGyroNoiseStd * Math.sin(60.0 * time);
  imuWy_raw = 0.1 * imuGyroBias + imuGyroNoiseStd * Math.cos(70.0 * time);
  imuWz_raw = omega + imuGyroBias + n_wz;

  // ===== Wheel encoder observations =====
  n_encL = encNoiseStd * Math.sin(200.0 * time);
  n_encR = encNoiseStd * Math.cos(200.0 * time + 1.0);
  omegaL_enc = (v - omega * wheelBase / 2.0) / wheelRadius + n_encL;
  omegaR_enc = (v + omega * wheelBase / 2.0) / wheelRadius + n_encR;

  // ===== Landmark perturbation (middle third of 8 s scenario) =====
  perturbation = if (time >= 8.0 / 3.0 and time <= 16.0 / 3.0) then 0.1 else 0.0;
  for i in 1:6 loop
    LMx_p[i] = LMx[i] + perturbation * Math.sin(lmAngle[i]);
    LMy_p[i] = LMy[i] + perturbation * Math.cos(lmAngle[i]);
  end for;

  // ===== Range measurements (fused into estimator) =====
  for i in 1:6 loop
    n_range[i] = rangeNoiseStd * Math.sin(50.0 * time + rangeNoisePhase[i]);
    range_meas[i] = Math.sqrt(max((x - LMx_p[i])^2 + (y - LMy_p[i])^2, 1e-6)) + n_range[i];
  end for;

  // ===== Camera data (bearings, preserved separately) =====
  for i in 1:6 loop
    camera_data[i] = Math.atan2(LMy_p[i] - y, LMx_p[i] - x) - theta;
  end for;

  // ===== Sonar data (ranges to obstacles, preserved separately) =====
  sonar_data[1] = Math.sqrt(max((x - OBx[1])^2 + (y - OBy[1])^2, 1e-6));
  sonar_data[2] = Math.sqrt(max((x - OBx[2])^2 + (y - OBy[2])^2, 1e-6));

  // ===== Estimator: odometry + IMU prediction =====
  v_est = (omegaL_enc + omegaR_enc) * wheelRadius / 2.0;
  omega_est = imuWz_raw - imuGyroBias;

  // Expected ranges and residuals from estimated pose (using nominal landmarks)
  for i in 1:6 loop
    r_exp[i] = Math.sqrt(max((x_est - LMx[i])^2 + (y_est - LMy[i])^2, 1e-6));
    r_diff[i] = range_meas[i] - r_exp[i];
    ux[i] = (x_est - LMx[i]) / max(r_exp[i], 1e-3);
    uy[i] = (y_est - LMy[i]) / max(r_exp[i], 1e-3);
  end for;

  // Range correction (explicit sum over 6 landmarks)
  rangeCorr_x = Krange * (
    r_diff[1] * ux[1] + r_diff[2] * ux[2] + r_diff[3] * ux[3] +
    r_diff[4] * ux[4] + r_diff[5] * ux[5] + r_diff[6] * ux[6]) / 6.0;
  rangeCorr_y = Krange * (
    r_diff[1] * uy[1] + r_diff[2] * uy[2] + r_diff[3] * uy[3] +
    r_diff[4] * uy[4] + r_diff[5] * uy[5] + r_diff[6] * uy[6]) / 6.0;

  // ===== Loop-closure correction (active near end of closed route) =====
  loopClosureActive = if time > 7.0 then 1.0 else 0.0;
  lcCorr_x = Kloop * (2.5 - x_est) * loopClosureActive;
  lcCorr_y = Kloop * (0.0 - y_est) * loopClosureActive;
  lcCorr_t = Kloop_t * (1.5707963 - theta_est) * loopClosureActive;

  // ===== Estimator dynamics: prediction + range correction + loop closure =====
  der(x_est) = v_est * Math.cos(theta_est) + rangeCorr_x + lcCorr_x;
  der(y_est) = v_est * Math.sin(theta_est) + rangeCorr_y + lcCorr_y;
  der(theta_est) = omega_est + lcCorr_t;

  // ===== Covariance propagation (finite, bounded, positive) =====
  der(Pxx) = 0.01 - Pxx * (1.0 + Krange * 0.5 + loopClosureActive * 2.0);
  der(Pyy) = 0.01 - Pyy * (1.0 + Krange * 0.5 + loopClosureActive * 2.0);
  der(Ptt) = 0.001 - Ptt * (1.0 + Kloop_t * 0.5 + loopClosureActive * 2.0);

  // ===== Loop-closure errors =====
  loopClosurePosErr = Math.sqrt(max((x_est - x)^2 + (y_est - y)^2, 1e-10));
  loopClosureHeadErr = Math.atan2(Math.sin(theta_est - theta), Math.cos(theta_est - theta));

  // ===== Primary tracking error =====
  trackErr = Math.sqrt(max((x - x_ref)^2 + (y - y_ref)^2, 1e-10));

  // ===== Collision monitoring =====
  obsDist1 = Math.sqrt(max((x - OBx[1])^2 + (y - OBy[1])^2, 1e-6));
  obsDist2 = Math.sqrt(max((x - OBx[2])^2 + (y - OBy[2])^2, 1e-6));
  minObsClear = min(obsDist1, obsDist2) - 0.25;

  annotation(
    experiment(StopTime = 8.0, Tolerance = 1e-6, Interval = 0.0125),
    Documentation(info = "WheelIMUMapA: Robotic sensing and estimation system.
      16 kg differential-drive chassis with wheel encoders and center-mounted 6-axis IMU.
      Two wheel-torque actuators (7.2 N.m limit). Closed ellipse route (8 s period).
      Fuses odometry, IMU, and range updates; camera and sonar data preserved separately.
      6 fixed landmarks, 2 obstacles in shared world frame.
      Pose filter with loop-closure correction. 0.1 m landmark perturbation in middle third.
      80 Hz output rate, 8 s duration.
      Requirements: finite covariance, loop-closure errors, tracking error < 0.338 m after 5.2 s,
      no collision, no NaN/infinite values.")
  );
end WheelIMUMapA;