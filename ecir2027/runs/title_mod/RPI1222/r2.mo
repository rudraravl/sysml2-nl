model WheelIMUMapD
  "Instrumented differential-drive robotic sensing and estimation system";

  function wrapAngle "Wrap angle to (-pi, pi]"
    input Real a;
    output Real b;
  protected
    constant Real PI = 3.14159265358979;
  algorithm
    b := a - 2.0*PI*floor((a + PI)/(2.0*PI));
  end wrapAngle;

  constant Real PI = 3.14159265358979;

  // Physical embodiment. Mass is stated; rotational inertia, wheel radius,
  // track width, and damping are not stated and are assumed for simulation only.
  parameter Real m = 16.0 "chassis mass, kg";
  parameter Real J = 2.0 "assumed yaw inertia, kg.m2";
  parameter Real r = 0.1 "assumed wheel radius, m";
  parameter Real L = 0.5 "assumed track width, m";
  parameter Real cV = 0.2 "assumed linear damping, N.s/m";
  parameter Real cOmega = 0.2 "assumed yaw damping, N.m.s/rad";
  parameter Real tauMax = 10.0 "per-wheel torque limit, N.m";

  // Closed route: circle completed in 14 s.
  parameter Real R_ref = 1.0 "reference circle radius, m";
  parameter Real v_ref = 2.0*PI*R_ref/14.0 "reference speed, m/s";
  parameter Real omega_ref = v_ref/R_ref "reference yaw rate, rad/s";

  // Control gains.
  parameter Real k_v = 5.0;
  parameter Real k_omega = 12.0;
  parameter Real k_theta = 1.5;
  parameter Real k_r = 0.8;
  parameter Real k_e = 0.5;
  parameter Real omegaCmdLim = 2.0 "rad/s";

  // Six fixed landmarks in shared world frame.
  parameter Real lx1 = 1.2, ly1 = 0.0;
  parameter Real lx2 = 0.0, ly2 = 1.2;
  parameter Real lx3 = -1.2, ly3 = 0.0;
  parameter Real lx4 = 0.0, ly4 = -1.2;
  parameter Real lx5 = 0.8, ly5 = 0.8;
  parameter Real lx6 = -0.8, ly6 = -0.8;

  // Two obstacles in shared world frame.
  parameter Real ox1 = 2.5, oy1 = -2.5, robs1 = 0.2;
  parameter Real ox2 = -2.5, oy2 = 2.5, robs2 = 0.2;

  // Controlled landmark perturbation during middle third.
  parameter Real landmarkPerturb = 0.2 "m";
  parameter Real tPerturbStart = 14.0/3.0 "s";
  parameter Real tPerturbEnd = 28.0/3.0 "s";

  // Declared IMU noise and bias parameters.
  parameter Real sigmaAcc = 0.05 "m/s2";
  parameter Real sigmaGyro = 0.001 "rad/s";
  parameter Real biasAccX = 0.02 "m/s2";
  parameter Real biasAccY = 0.01 "m/s2";
  parameter Real biasAccZ = 0.05 "m/s2";
  parameter Real biasGyroX = 0.001 "rad/s";
  parameter Real biasGyroY = 0.001 "rad/s";
  parameter Real biasGyroZ = 0.002 "rad/s";

  // Encoder and range sensor parameters.
  parameter Real sigmaOdom = 0.01 "m/s";
  parameter Real sigmaRange = 0.01 "m";
  parameter Real biasRange = 0.0 "m";

  // Estimator parameters.
  parameter Real kRange = 0.8;
  parameter Real Q_pos = 0.001 "m2";
  parameter Real Q_theta = 0.0001 "rad2";
  parameter Real tauPos = 2.0 "s";
  parameter Real tauTheta = 2.0 "s";
  parameter Real kCovRange = 0.5;

  // Declared output rate.
  parameter Real Ts = 0.005 "s";
  parameter Integer outputRateHz = 200 "Hz";

  // Plant state.
  Real x(start=1.0, fixed=true) "m";
  Real y(start=0.0, fixed=true) "m";
  Real theta(start=PI/2, fixed=true) "rad";
  Real v(start=0.0, fixed=true) "m/s";
  Real omega(start=0.0, fixed=true) "rad/s";

  // Command and actuator variables.
  Real tauSumCmd, tauDiffCmd, tauCmdR, tauCmdL, tauR, tauL;
  Real v_cmd, omega_cmd, theta_des, e_r_est, e_theta_est;

  // Raw sensor variables.
  Real omegaWheelR, omegaWheelL, odomV, odomOmega;
  Real ax, ay, az, gx, gy, gz;
  Real rangeMeas1, rangeMeas2, rangeMeas3, rangeMeas4, rangeMeas5, rangeMeas6;
  Real rawCamera1, rawCamera2, rawCamera3, rawCamera4, rawCamera5, rawCamera6;
  Real rawSonar1, rawSonar2;

  // Estimator state.
  Real x_est(start=1.0, fixed=true) "m";
  Real y_est(start=0.0, fixed=true) "m";
  Real theta_est(start=PI/2, fixed=true) "rad";
  Real Pxx(start=0.1, fixed=true) "m2";
  Real Pyy(start=0.1, fixed=true) "m2";
  Real Ptheta(start=0.01, fixed=true) "rad2";
  Real v_est, omega_est, corrX, corrY;
  Real dx1, dy1, r_est1, r_est1_safe, res1, corrX1, corrY1;
  Real dx2, dy2, r_est2, r_est2_safe, res2, corrX2, corrY2;
  Real dx3, dy3, r_est3, r_est3_safe, res3, corrX3, corrY3;
  Real dx4, dy4, r_est4, r_est4_safe, res4, corrX4, corrY4;
  Real dx5, dy5, r_est5, r_est5_safe, res5, corrX5, corrY5;
  Real dx6, dy6, r_est6, r_est6_safe, res6, corrX6, corrY6;

  // Reference and metric variables.
  Real x_ref, y_ref, theta_ref;
  Real trackingError;
  Real estPosError, estHeadError;
  Real distObs1, distObs2, minClearance;
  Boolean noCollision;
  discrete Real loopClosurePosErr(start=0.0);
  discrete Real loopClosureHeadErr(start=0.0);
  Real perturbX;

equation
  // Synchronized reference route.
  x_ref = R_ref*cos(omega_ref*time);
  y_ref = R_ref*sin(omega_ref*time);
  theta_ref = atan2(y_ref, x_ref) + PI/2;
  trackingError = sqrt((x - x_ref)^2 + (y - y_ref)^2 + 1e-9);

  // Differential-drive plant dynamics.
  der(x) = v*cos(theta);
  der(y) = v*sin(theta);
  der(theta) = omega;
  der(v) = (tauR + tauL)/r/m - cV*v/m;
  der(omega) = (tauR - tauL)*L/(2.0*r*J) - cOmega*omega/J;

  // Path-following controller using fused pose estimate.
  e_r_est = sqrt(x_est^2 + y_est^2 + 1e-9) - R_ref;
  theta_des = atan2(y_est, x_est) + PI/2;
  e_theta_est = wrapAngle(theta_est - theta_des);
  v_cmd = max(0.0, v_ref - k_e*e_r_est);
  omega_cmd = max(-omegaCmdLim, min(omegaCmdLim, omega_ref - k_theta*e_theta_est + k_r*e_r_est));

  // Torque commands with damping compensation and per-wheel saturation.
  tauSumCmd = r*(m*k_v*(v_cmd - v) + cV*v);
  tauDiffCmd = (2.0*r/L)*(J*k_omega*(omega_cmd - omega) + cOmega*omega);
  tauCmdR = 0.5*tauSumCmd + 0.5*tauDiffCmd;
  tauCmdL = 0.5*tauSumCmd - 0.5*tauDiffCmd;
  tauR = max(-tauMax, min(tauMax, tauCmdR));
  tauL = max(-tauMax, min(tauMax, tauCmdL));

  // Wheel encoder observations.
  omegaWheelR = (v + (L/2.0)*omega)/r;
  omegaWheelL = (v - (L/2.0)*omega)/r;
  odomV = r*(omegaWheelR + omegaWheelL)/2.0 + sigmaOdom*sin(2.0*PI*3.0*time);
  odomOmega = r*(omegaWheelR - omegaWheelL)/L + sigmaOdom*cos(2.0*PI*2.0*time);

  // Six-axis IMU observations with declared noise and bias.
  ax = der(v) + sigmaAcc*sin(2.0*PI*5.0*time) + biasAccX;
  ay = omega*v + sigmaAcc*cos(2.0*PI*4.0*time) + biasAccY;
  az = 9.81 + sigmaAcc*sin(2.0*PI*1.0*time) + biasAccZ;
  gx = biasGyroX + sigmaGyro*sin(2.0*PI*6.0*time);
  gy = biasGyroY + sigmaGyro*cos(2.0*PI*7.0*time);
  gz = omega + biasGyroZ + sigmaGyro*sin(2.0*PI*8.0*time);

  // Controlled 0.2 m landmark perturbation during middle third.
  perturbX = if time >= tPerturbStart and time <= tPerturbEnd then landmarkPerturb else 0.0;

  // Raw range observations used for fusion.
  rangeMeas1 = sqrt((x - (lx1 + perturbX))^2 + (y - ly1)^2 + 1e-9) + sigmaRange*sin(2.0*PI*9.0*time) + biasRange;
  rangeMeas2 = sqrt((x - (lx2 + perturbX))^2 + (y - ly2)^2 + 1e-9) + sigmaRange*cos(2.0*PI*10.0*time) + biasRange;
  rangeMeas3 = sqrt((x - (lx3 + perturbX))^2 + (y - ly3)^2 + 1e-9) + sigmaRange*sin(2.0*PI*11.0*time) + biasRange;
  rangeMeas4 = sqrt((x - (lx4 + perturbX))^2 + (y - ly4)^2 + 1e-9) + sigmaRange*cos(2.0*PI*12.0*time) + biasRange;
  rangeMeas5 = sqrt((x - (lx5 + perturbX))^2 + (y - ly5)^2 + 1e-9) + sigmaRange*sin(2.0*PI*13.0*time) + biasRange;
  rangeMeas6 = sqrt((x - (lx6 + perturbX))^2 + (y - ly6)^2 + 1e-9) + sigmaRange*cos(2.0*PI*14.0*time) + biasRange;

  // Raw camera bearings preserved separately, not fused.
  rawCamera1 = wrapAngle(atan2(ly1 - y, (lx1 + perturbX) - x) - theta);
  rawCamera2 = wrapAngle(atan2(ly2 - y, (lx2 + perturbX) - x) - theta);
  rawCamera3 = wrapAngle(atan2(ly3 - y, (lx3 + perturbX) - x) - theta);
  rawCamera4 = wrapAngle(atan2(ly4 - y, (lx4 + perturbX) - x) - theta);
  rawCamera5 = wrapAngle(atan2(ly5 - y, (lx5 + perturbX) - x) - theta);
  rawCamera6 = wrapAngle(atan2(ly6 - y, (lx6 + perturbX) - x) - theta);

  // Raw sonar obstacle ranges preserved separately, not fused.
  rawSonar1 = sqrt((x - ox1)^2 + (y - oy1)^2 + 1e-9);
  rawSonar2 = sqrt((x - ox2)^2 + (y - oy2)^2 + 1e-9);

  // Pose filter: odometry and IMU prediction.
  v_est = odomV;
  omega_est = gz - biasGyroZ;
  der(theta_est) = omega_est;

  // Range update corrections for each landmark using the true fixed map.
  dx1 = x_est - lx1; dy1 = y_est - ly1;
  r_est1 = sqrt(dx1^2 + dy1^2 + 1e-9);
  r_est1_safe = max(r_est1, 0.01);
  res1 = rangeMeas1 - r_est1;
  corrX1 = kRange * res1 * dx1 / r_est1_safe;
  corrY1 = kRange * res1 * dy1 / r_est1_safe;

  dx2 = x_est - lx2; dy2 = y_est - ly2;
  r_est2 = sqrt(dx2^2 + dy2^2 + 1e-9);
  r_est2_safe = max(r_est2, 0.01);
  res2 = rangeMeas2 - r_est2;
  corrX2 = kRange * res2 * dx2 / r_est2_safe;
  corrY2 = kRange * res2 * dy2 / r_est2_safe;

  dx3 = x_est - lx3; dy3 = y_est - ly3;
  r_est3 = sqrt(dx3^2 + dy3^2 + 1e-9);
  r_est3_safe = max(r_est3, 0.01);
  res3 = rangeMeas3 - r_est3;
  corrX3 = kRange * res3 * dx3 / r_est3_safe;
  corrY3 = kRange * res3 * dy3 / r_est3_safe;

  dx4 = x_est - lx4; dy4 = y_est - ly4;
  r_est4 = sqrt(dx4^2 + dy4^2 + 1e-9);
  r_est4_safe = max(r_est4, 0.01);
  res4 = rangeMeas4 - r_est4;
  corrX4 = kRange * res4 * dx4 / r_est4_safe;
  corrY4 = kRange * res4 * dy4 / r_est4_safe;

  dx5 = x_est - lx5; dy5 = y_est - ly5;
  r_est5 = sqrt(dx5^2 + dy5^2 + 1e-9);
  r_est5_safe = max(r_est5, 0.01);
  res5 = rangeMeas5 - r_est5;
  corrX5 = kRange * res5 * dx5 / r_est5_safe;
  corrY5 = kRange * res5 * dy5 / r_est5_safe;

  dx6 = x_est - lx6; dy6 = y_est - ly6;
  r_est6 = sqrt(dx6^2 + dy6^2 + 1e-9);
  r_est6_safe = max(r_est6, 0.01);
  res6 = rangeMeas6 - r_est6;
  corrX6 = kRange * res6 * dx6 / r_est6_safe;
  corrY6 = kRange * res6 * dy6 / r_est6_safe;

  corrX = corrX1 + corrX2 + corrX3 + corrX4 + corrX5 + corrX6;
  corrY = corrY1 + corrY2 + corrY3 + corrY4 + corrY5 + corrY6;
  der(x_est) = v_est*cos(theta_est) + corrX;
  der(y_est) = v_est*sin(theta_est) + corrY;

  // Finite covariance propagation with range-update reduction.
  der(Pxx) = Q_pos - Pxx/tauPos - kCovRange*Pxx;
  der(Pyy) = Q_pos - Pyy/tauPos - kCovRange*Pyy;
  der(Ptheta) = Q_theta - Ptheta/tauTheta;

  // Estimator error metrics.
  estPosError = sqrt((x_est - x)^2 + (y_est - y)^2 + 1e-9);
  estHeadError = abs(wrapAngle(theta_est - theta));

  // Obstacle clearance and collision status.
  distObs1 = sqrt((x - ox1)^2 + (y - oy1)^2 + 1e-9);
  distObs2 = sqrt((x - ox2)^2 + (y - oy2)^2 + 1e-9);
  minClearance = if distObs1 < distObs2 then distObs1 - robs1 else distObs2 - robs2;
  noCollision = minClearance > 0.0;

  // Loop-closure correction near route completion.
  when time >= 13.8 and time <= 13.81 then
    loopClosurePosErr = sqrt((x_est - x)^2 + (y_est - y)^2 + 1e-9);
    loopClosureHeadErr = abs(wrapAngle(theta_est - theta));
    reinit(x_est, x_est + 0.8*(x - x_est));
    reinit(y_est, y_est + 0.8*(y - y_est));
    reinit(theta_est, wrapAngle(theta_est + 0.8*wrapAngle(theta - theta_est)));
    reinit(Pxx, 0.01);
    reinit(Pyy, 0.01);
    reinit(Ptheta, 0.001);
  end when;

  annotation (experiment(StopTime=14.0, Interval=0.005));
end WheelIMUMapD;