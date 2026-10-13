model WheelIMUMapA
  import Modelica.Constants;
  import Modelica.Math;

  // Physical parameters
  parameter Real m_chassis(unit="kg") = 16.0 "Chassis mass";
  parameter Real wheelRadius(unit="m") = 0.1 "Wheel radius";
  parameter Real wheelBase(unit="m") = 0.4 "Wheel base";
  parameter Real Izz(unit="kg.m2") = 1.28 "Yaw inertia";
  parameter Real tauMax(unit="N.m") = 7.2 "Max wheel torque command magnitude";
  parameter Real outputRate(unit="Hz") = 80.0 "Declared output rate";
  parameter Real dt_out(unit="s") = 1.0 / outputRate "Output sample period";
  parameter Real w_path(unit="rad/s") = 2.0 * Constants.pi / 8.0 "Path angular frequency";

  // IMU noise and bias parameters
  parameter Real imuAccelBias(unit="m/s2") = 0.05 "IMU accelerometer bias";
  parameter Real imuGyroBias(unit="rad/s") = 0.01 "IMU gyroscope bias";
  parameter Real imuAccelNoiseStd(unit="m/s2") = 0.1 "IMU accel noise std dev";
  parameter Real imuGyroNoiseStd(unit="rad/s") = 0.01 "IMU gyro noise std dev";
  parameter Real encNoiseStd(unit="rad/s") = 0.05 "Encoder noise std dev";
  parameter Real rangeNoiseStd(unit="m") = 0.05 "Range noise std dev";

  // Controller gains
  parameter Real Kp_v = 80.0 "Velocity proportional gain";
  parameter Real Kp_w = 15.0 "Heading proportional gain";
  parameter Real Kd_w = 3.0 "Heading derivative gain";
  parameter Real damping_v = 1.0 "Linear damping coefficient";
  parameter Real damping_w = 0.5 "Angular damping coefficient";

  // Estimator gains
  parameter Real Krange = 1.5 "Range correction gain";
  parameter Real Kloop = 3.0 "Loop closure position gain";
  parameter Real Kloop_t = 2.0 "Loop closure heading gain";

  // Landmarks (6 fixed in shared world frame)
  parameter Real LMx[6] = {2.5, -2.5, 0.0, 3.0, -3.0, 1.5} "Landmark x [m]";
  parameter Real LMy[6] = {0.0, 0.0, 2.0, -1.5, 1.5, -2.0} "Landmark y [m]";
  parameter Real lmAngle[6] = {0.5, 1.2, 2.0, 2.8, 3.5, 4.2} "Perturbation direction [rad]";
  parameter Real rangeNoisePhase[6] = {0.0, 1.0, 2.0, 3.0, 4.0, 5.0} "Range noise phase [rad]";

  // Obstacles (2 in shared world frame)
  parameter Real OBx[2] = {1.0, -1.0} "Obstacle x [m]";
  parameter Real OBy[2] = {-0.8, 0.8} "Obstacle y [m]";
  parameter Real OBr[2] = {0.25, 0.25} "Obstacle radius [m]";

  // Plant states
  Real x(start=2.5, fixed=true, unit="m") "True x position";
  Real y(start=0.0, fixed=true, unit="m") "True y position";
  Real theta(start=1.5707963, fixed=true, unit="rad") "True heading";
  Real v(start=0.0, fixed=true, unit="m/s") "True forward velocity";
  Real omega(start=0.0, fixed=true, unit="rad/s") "True yaw rate";
  Real tauL_filt(start=0.0, fixed=true, unit="N.m") "Filtered left wheel torque";
  Real tauR_filt(start=0.0, fixed=true, unit="N.m") "Filtered right wheel torque";

  // Reference trajectory
  Real x_ref(unit="m") "Reference x";
  Real y_ref(unit="m") "Reference y";
  Real theta_ref(unit="rad") "Reference heading";
  Real v_ref(unit="m/s") "Reference velocity magnitude";
  Real omega_ref(unit="rad/s") "Reference yaw rate";
  Real theta_err(unit="rad") "Wrapped heading tracking error";

  // Commands
  Real tauL_cmd(unit="N.m") "Left wheel torque command";
  Real tauR_cmd(unit="N.m") "Right wheel torque command";
  Real tauL(unit="N.m") "Actual left wheel torque";
  Real tauR(unit="N.m") "Actual right wheel torque";
  Real F_des(unit="N") "Desired net force";
  Real M_des(unit="N.m") "Desired net moment";

  // IMU raw observations
  Real imuAx_raw(unit="m/s2") "Raw IMU forward acceleration";
  Real imuAy_raw(unit="m/s2") "Raw IMU lateral acceleration";
  Real imuAz_raw(unit="m/s2") "Raw IMU vertical acceleration";
  Real imuWx_raw(unit="rad/s") "Raw IMU roll rate";
  Real imuWy_raw(unit="rad/s") "Raw IMU pitch rate";
  Real imuWz_raw(unit="rad/s") "Raw IMU yaw rate";

  // Wheel encoder observations
  Real omegaL_enc(unit="rad/s") "Left wheel encoder angular velocity";
  Real omegaR_enc(unit="rad/s") "Right wheel encoder angular velocity";

  // Range measurements
  Real range_meas[6](each unit="m") "Fused range measurements to landmarks";

  // Camera data (preserved separately, not fused)
  Real camera_data[6](each unit="rad") "Camera bearing to each landmark";

  // Sonar data (preserved separately, not fused)
  Real sonar_data[2](each unit="m") "Sonar range to each obstacle";

  // Estimator states
  Real x_est(start=2.5, fixed=true, unit="m") "Estimated x";
  Real y_est(start=0.0, fixed=true, unit="m") "Estimated y";
  Real theta_est(start=1.5707963, fixed=true, unit="rad") "Estimated heading";
  Real v_est(start=0.0, fixed=true, unit="m/s") "Estimated velocity from odometry";
  Real omega_est(start=0.0, fixed=true, unit="rad/s") "Estimated yaw rate from IMU";

  // Finite covariance (diagonal)
  Real Pxx(start=0.01, fixed=true, unit="m2") "Position x covariance";
  Real Pyy(start=0.01, fixed=true, unit="m2") "Position y covariance";
  Real Ptt(start=0.001, fixed=true, unit="rad2") "Heading covariance";

  // Loop closure
  Real loopClosurePosErr(unit="m") "Loop-closure position error";
  Real loopClosureHeadErr(unit="rad") "Loop-closure heading error";
  Real loopClosureActive "Loop closure active flag (0 or 1)";
  Real lcCorr_x(unit="m/s") "Loop closure x correction rate";
  Real lcCorr_y(unit="m/s") "Loop closure y correction rate";
  Real lcCorr_t(unit="rad/s") "Loop closure heading correction rate";

  // Tracking error
  Real trackErr(unit="m") "Primary tracking error (position)";

  // Landmark perturbation
  Real perturbation(unit="m") "Applied landmark perturbation";
  Real LMx_p[6](each unit="m") "Perturbed landmark x";
  Real LMy_p[6](each unit="m") "Perturbed landmark y";

  // Collision monitoring
  Real obsDist1(unit="m") "Distance to obstacle 1 center";
  Real obsDist2(unit="m") "Distance to obstacle 2 center";
  Real minObsClear(unit="m") "Minimum obstacle clearance";

  // Noise signals
  Real n_ax "IMU accel x noise";
  Real n_wz "IMU gyro z noise";
  Real n_encL "Encoder left noise";
  Real n_encR "Encoder right noise";
  Real n_range_1 "Range noise landmark 1";
  Real n_range_2 "Range noise landmark 2";
  Real n_range_3 "Range noise landmark 3";
  Real n_range_4 "Range noise landmark 4";
  Real n_range_5 "Range noise landmark 5";
  Real n_range_6 "Range noise landmark 6";

  // Estimator intermediate variables
  Real rangeCorr_x(unit="m/s") "Range-based x correction";
  Real rangeCorr_y(unit="m/s") "Range-based y correction";
  Real r_exp_1(unit="m") "Expected range landmark 1";
  Real r_exp_2(unit="m") "Expected range landmark 2";
  Real r_exp_3(unit="m") "Expected range landmark 3";
  Real r_exp_4(unit="m") "Expected range landmark 4";
  Real r_exp_5(unit="m") "Expected range landmark 5";
  Real r_exp_6(unit="m") "Expected range landmark 6";
  Real r_diff_1(unit="m") "Range residual landmark 1";
  Real r_diff_2(unit="m") "Range residual landmark 2";
  Real r_diff_3(unit="m") "Range residual landmark 3";
  Real r_diff_4(unit="m") "Range residual landmark 4";
  Real r_diff_5(unit="m") "Range residual landmark 5";
  Real r_diff_6(unit="m") "Range residual landmark 6";
  Real ux_1 "Unit vector x landmark 1";
  Real ux_2 "Unit vector x landmark 2";
  Real ux_3 "Unit vector x landmark 3";
  Real ux_4 "Unit vector x landmark 4";
  Real ux_5 "Unit vector x landmark 5";
  Real ux_6 "Unit vector x landmark 6";
  Real uy_1 "Unit vector y landmark 1";
  Real uy_2 "Unit vector y landmark 2";
  Real uy_3 "Unit vector y landmark 3";
  Real uy_4 "Unit vector y landmark 4";
  Real uy_5 "Unit vector y landmark 5";
  Real uy_6 "Unit vector y landmark 6";

  // Intermediate helper variables
  Real dx_ref "Reference velocity x component";
  Real dy_ref "Reference velocity y component";
  Real speed_sq "Squared reference speed";
  Real ddx_ref "Reference acceleration x component";
  Real ddy_ref "Reference acceleration y component";
  Real accel_cross "Cross product for yaw rate numerator";

equation
  // Reference trajectory: ellipse, period 8 s (closed route)
  x_ref = 2.5 * Math.cos(w_path * time);
  y_ref = 1.5 * Math.sin(w_path * time);

  dx_ref = -2.5 * w_path * Math.sin(w_path * time);
  dy_ref = 1.5 * w_path * Math.cos(w_path * time);
  speed_sq = dx_ref * dx_ref + dy_ref * dy_ref;

  v_ref = Math.sqrt(if speed_sq > 1e-6 then speed_sq else 1e-6);
  theta_ref = Math.atan2(dy_ref, dx_ref);

  ddx_ref = -2.5 * w_path * w_path * Math.cos(w_path * time);
  ddy_ref = -1.5 * w_path * w_path * Math.sin(w_path * time);
  accel_cross = dx_ref * ddy_ref - dy_ref * ddx_ref;
  omega_ref = accel_cross / (if speed_sq > 1e-6 then speed_sq else 1e-6);

  // Wrapped heading error for control
  theta_err = Math.atan2(Math.sin(theta_ref - theta), Math.cos(theta_ref - theta));

  // Controller (PD on velocity and heading)
  F_des = Kp_v * (v_ref - v);
  M_des = Kp_w * theta_err - Kd_w * omega;

  // Map to wheel torques with saturation
  tauL_cmd = if (F_des * wheelRadius / 2.0 - M_des * wheelRadius / wheelBase) > tauMax then tauMax
    elseif (F_des * wheelRadius / 2.0 - M_des * wheelRadius / wheelBase) < -tauMax then -tauMax
    else (F_des * wheelRadius / 2.0 - M_des * wheelRadius / wheelBase);
  tauR_cmd = if (F_des * wheelRadius / 2.0 + M_des * wheelRadius / wheelBase) > tauMax then tauMax
    elseif (F_des * wheelRadius / 2.0 + M_des * wheelRadius / wheelBase) < -tauMax then -tauMax
    else (F_des * wheelRadius / 2.0 + M_des * wheelRadius / wheelBase);

  // Torque actuator dynamics (first-order filter)
  der(tauL_filt) = (tauL_cmd - tauL_filt) / 0.02;
  der(tauR_filt) = (tauR_cmd - tauR_filt) / 0.02;
  tauL = tauL_filt;
  tauR = tauR_filt;

  // Plant dynamics (differential drive)
  m_chassis * der(v) = (tauL + tauR) / wheelRadius - damping_v * v;
  Izz * der(omega) = (tauR - tauL) * wheelBase / (2.0 * wheelRadius) - damping_w * omega;
  der(x) = v * Math.cos(theta);
  der(y) = v * Math.sin(theta);
  der(theta) = omega;

  // IMU raw observations (6-axis, center-mounted)
  n_ax = imuAccelNoiseStd * Math.sin(100.0 * time);
  n_wz = imuGyroNoiseStd * Math.sin(150.0 * time + 0.5);

  imuAx_raw = ((tauL + tauR) / wheelRadius - damping_v * v) / m_chassis + imuAccelBias + n_ax;
  imuAy_raw = omega * v + 0.5 * imuAccelBias + imuAccelNoiseStd * Math.cos(80.0 * time);
  imuAz_raw = 9.81 + 0.1 * imuAccelBias;
  imuWx_raw = 0.1 * imuGyroBias + imuGyroNoiseStd * Math.sin(60.0 * time);
  imuWy_raw = 0.1 * imuGyroBias + imuGyroNoiseStd * Math.cos(70.0 * time);
  imuWz_raw = omega + imuGyroBias + n_wz;

  // Wheel encoder observations
  n_encL = encNoiseStd * Math.sin(200.0 * time);
  n_encR = encNoiseStd * Math.cos(200.0 * time + 1.0);
  omegaL_enc = (v - omega * wheelBase / 2.0) / wheelRadius + n_encL;
  omegaR_enc = (v + omega * wheelBase / 2.0) / wheelRadius + n_encR;

  // Landmark perturbation (middle third of 8 s scenario)
  perturbation = if (time >= 2.6667 and time <= 5.3333) then 0.1 else 0.0;

  LMx_p[1] = LMx[1] + perturbation * Math.sin(lmAngle[1]);
  LMx_p[2] = LMx[2] + perturbation * Math.sin(lmAngle[2]);
  LMx_p[3] = LMx[3] + perturbation * Math.sin(lmAngle[3]);
  LMx_p[4] = LMx[4] + perturbation * Math.sin(lmAngle[4]);
  LMx_p[5] = LMx[5] + perturbation * Math.sin(lmAngle[5]);
  LMx_p[6] = LMx[6] + perturbation * Math.sin(lmAngle[6]);

  LMy_p[1] = LMy[1] + perturbation * Math.cos(lmAngle[1]);
  LMy_p[2] = LMy[2] + perturbation * Math.cos(lmAngle[2]);
  LMy_p[3] = LMy[3] + perturbation * Math.cos(lmAngle[3]);
  LMy_p[4] = LMy[4] + perturbation * Math.cos(lmAngle[4]);
  LMy_p[5] = LMy[5] + perturbation * Math.cos(lmAngle[5]);
  LMy_p[6] = LMy[6] + perturbation * Math.cos(lmAngle[6]);

  // Range measurements (fused into estimator)
  n_range_1 = rangeNoiseStd * Math.sin(50.0 * time + rangeNoisePhase[1]);
  n_range_2 = rangeNoiseStd * Math.sin(50.0 * time + rangeNoisePhase[2]);
  n_range_3 = rangeNoiseStd * Math.sin(50.0 * time + rangeNoisePhase[3]);
  n_range_4 = rangeNoiseStd * Math.sin(50.0 * time + rangeNoisePhase[4]);
  n_range_5 = rangeNoiseStd * Math.sin(50.0 * time + rangeNoisePhase[5]);
  n_range_6 = rangeNoiseStd * Math.sin(50.0 * time + rangeNoisePhase[6]);

  range_meas[1] = Math.sqrt(if (x - LMx_p[1])^2 + (y - LMy_p[1])^2 > 1e-6 then (x - LMx_p[1])^2 + (y - LMy_p[1])^2 else 1e-6) + n_range_1;
  range_meas[2] = Math.sqrt(if (x - LMx_p[2])^2 + (y - LMy_p[2])^2 > 1e-6 then (x - LMx_p[2])^2 + (y - LMy_p[2])^2 else 1e-6) + n_range_2;
  range_meas[3] = Math.sqrt(if (x - LMx_p[3])^2 + (y - LMy_p[3])^2 > 1e-6 then (x - LMx_p[3])^2 + (y - LMy_p[3])^2 else 1e-6) + n_range_3;
  range_meas[4] = Math.sqrt(if (x - LMx_p[4])^2 + (y - LMy_p[4])^2 > 1e-6 then (x - LMx_p[4])^2 + (y - LMy_p[4])^2 else 1e-6) + n_range_4;
  range_meas[5] = Math.sqrt(if (x - LMx_p[5])^2 + (y - LMy_p[5])^2 > 1e-6 then (x - LMx_p[5])^2 + (y - LMy_p[5])^2 else 1e-6) + n_range_5;
  range_meas[6] = Math.sqrt(if (x - LMx_p[6])^2 + (y - LMy_p[6])^2 > 1e-6 then (x - LMx_p[6])^2 + (y - LMy_p[6])^2 else 1e-6) + n_range_6;

  // Camera data (bearings, preserved separately)
  camera_data[1] = Math.atan2(LMy_p[1] - y, LMx_p[1] - x) - theta;
  camera_data[2] = Math.atan2(LMy_p[2] - y, LMx_p[2] - x) - theta;
  camera_data[3] = Math.atan2(LMy_p[3] - y, LMx_p[3] - x) - theta;
  camera_data[4] = Math.atan2(LMy_p[4] - y, LMx_p[4] - x) - theta;
  camera_data[5] = Math.atan2(LMy_p[5] - y, LMx_p[5] - x) - theta;
  camera_data[6] = Math.atan2(LMy_p[6] - y, LMx_p[6] - x) - theta;

  // Sonar data (ranges to obstacles, preserved separately)
  sonar_data[1] = Math.sqrt(if (x - OBx[1])^2 + (y - OBy[1])^2 > 1e-6 then (x - OBx[1])^2 + (y - OBy[1])^2 else 1e-6);
  sonar_data[2] = Math.sqrt(if (x - OBx[2])^2 + (y - OBy[2])^2 > 1e-6 then (x - OBx[2])^2 + (y - OBy[2])^2 else 1e-6);

  // Estimator: odometry + IMU prediction
  v_est = (omegaL_enc + omegaR_enc) * wheelRadius / 2.0;
  omega_est = imuWz_raw - imuGyroBias;

  // Expected ranges and residuals from estimated pose (using nominal landmarks)
  r_exp_1 = Math.sqrt(if (x_est - LMx[1])^2 + (y_est - LMy[1])^2 > 1e-6 then (x_est - LMx[1])^2 + (y_est - LMy[1])^2 else 1e-6);
  r_exp_2 = Math.sqrt(if (x_est - LMx[2])^2 + (y_est - LMy[2])^2 > 1e-6 then (x_est - LMx[2])^2 + (y_est - LMy[2])^2 else 1e-6);
  r_exp_3 = Math.sqrt(if (x_est - LMx[3])^2 + (y_est - LMy[3])^2 > 1e-6 then (x_est - LMx[3])^2 + (y_est - LMy[3])^2 else 1e-6);
  r_exp_4 = Math.sqrt(if (x_est - LMx[4])^2 + (y_est - LMy[4])^2 > 1e-6 then (x_est - LMx[4])^2 + (y_est - LMy[4])^2 else 1e-6);
  r_exp_5 = Math.sqrt(if (x_est - LMx[5])^2 + (y_est - LMy[5])^2 > 1e-6 then (x_est - LMx[5])^2 + (y_est - LMy[5])^2 else 1e-6);
  r_exp_6 = Math.sqrt(if (x_est - LMx[6])^2 + (y_est - LMy[6])^2 > 1e-6 then (x_est - LMx[6])^2 + (y_est - LMy[6])^2 else 1e-6);

  r_diff_1 = range_meas[1] - r_exp_1;
  r_diff_2 = range_meas[2] - r_exp_2;
  r_diff_3 = range_meas[3] - r_exp_3;
  r_diff_4 = range_meas[4] - r_exp_4;
  r_diff_5 = range_meas[5] - r_exp_5;
  r_diff_6 = range_meas[6] - r_exp_6;

  ux_1 = (x_est - LMx[1]) / (if r_exp_1 > 1e-3 then r_exp_1 else 1e-3);
  ux_2 = (x_est - LMx[2]) / (if r_exp_2 > 1e-3 then r_exp_2 else 1e-3);
  ux_3 = (x_est - LMx[3]) / (if r_exp_3 > 1e-3 then r_exp_3 else 1e-3);
  ux_4 = (x_est - LMx[4]) / (if r_exp_4 > 1e-3 then r_exp_4 else 1e-3);
  ux_5 = (x_est - LMx[5]) / (if r_exp_5 > 1e-3 then r_exp_5 else 1e-3);
  ux_6 = (x_est - LMx[6]) / (if r_exp_6 > 1e-3 then r_exp_6 else 1e-3);

  uy_1 = (y_est - LMy[1]) / (if r_exp_1 > 1e-3 then r_exp_1 else 1e-3);
  uy_2 = (y_est - LMy[2]) / (if r_exp_2 > 1e-3 then r_exp_2 else 1e-3);
  uy_3 = (y_est - LMy[3]) / (if r_exp_3 > 1e-3 then r_exp_3 else 1e-3);
  uy_4 = (y_est - LMy[4]) / (if r_exp_4 > 1e-3 then r_exp_4 else 1e-3);
  uy_5 = (y_est - LMy[5]) / (if r_exp_5 > 1e-3 then r_exp_5 else 1e-3);
  uy_6 = (y_est - LMy[6]) / (if r_exp_6 > 1e-3 then r_exp_6 else 1e-3);

  // Range correction (explicit sum over 6 landmarks)
  rangeCorr_x = Krange * (r_diff_1 * ux_1 + r_diff_2 * ux_2 + r_diff_3 * ux_3 + r_diff_4 * ux_4 + r_diff_5 * ux_5 + r_diff_6 * ux_6) / 6.0;
  rangeCorr_y = Krange * (r_diff_1 * uy_1 + r_diff_2 * uy_2 + r_diff_3 * uy_3 + r_diff_4 * uy_4 + r_diff_5 * uy_5 + r_diff_6 * uy_6) / 6.0;

  // Loop-closure correction (active near end of closed route)
  loopClosureActive = if time > 7.0 then 1.0 else 0.0;
  lcCorr_x = Kloop * (2.5 - x_est) * loopClosureActive;
  lcCorr_y = Kloop * (0.0 - y_est) * loopClosureActive;
  lcCorr_t = Kloop_t * (1.5707963 - theta_est) * loopClosureActive;

  // Estimator dynamics: prediction + range correction + loop closure
  der(x_est) = v_est * Math.cos(theta_est) + rangeCorr_x + lcCorr_x;
  der(y_est) = v_est * Math.sin(theta_est) + rangeCorr_y + lcCorr_y;
  der(theta_est) = omega_est + lcCorr_t;

  // Covariance propagation (finite, bounded, positive)
  der(Pxx) = 0.01 - Pxx * (1.0 + Krange * 0.5 + loopClosureActive * 2.0);
  der(Pyy) = 0.01 - Pyy * (1.0 + Krange * 0.5 + loopClosureActive * 2.0);
  der(Ptt) = 0.001 - Ptt * (1.0 + Kloop_t * 0.5 + loopClosureActive * 2.0);

  // Loop-closure errors
  loopClosurePosErr = Math.sqrt(if (x_est - x)^2 + (y_est - y)^2 > 1e-10 then (x_est - x)^2 + (y_est - y)^2 else 1e-10);
  loopClosureHeadErr = Math.atan2(Math.sin(theta_est - theta), Math.cos(theta_est - theta));

  // Primary tracking error
  trackErr = Math.sqrt(if (x - x_ref)^2 + (y - y_ref)^2 > 1e-10 then (x - x_ref)^2 + (y - y_ref)^2 else 1e-10);

  // Collision monitoring
  obsDist1 = Math.sqrt(if (x - OBx[1])^2 + (y - OBy[1])^2 > 1e-6 then (x - OBx[1])^2 + (y - OBy[1])^2 else 1e-6);
  obsDist2 = Math.sqrt(if (x - OBx[2])^2 + (y - OBy[2])^2 > 1e-6 then (x - OBx[2])^2 + (y - OBy[2])^2 else 1e-6);
  minObsClear = (if obsDist1 < obsDist2 then obsDist1 else obsDist2) - 0.25;

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