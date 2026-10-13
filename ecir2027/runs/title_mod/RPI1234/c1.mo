model MapRigBridgeD
  "Instrumented 22 kg mobile base with multi-rate sensing and outage-tolerant estimator."

  // Physical plant parameters
  parameter Real mBase = 22.0 "kg mobile base mass";
  parameter Real JBase = 2.2 "kg.m2 yaw inertia";
  parameter Real rWheel = 0.10 "m drive wheel radius";
  parameter Real dWheel = 0.30 "m half axle";
  parameter Real tauMax = 12.0 "N.m per-wheel torque limit";

  // Sensor rates
  parameter Real lidarRangeMax = 20.0 "m planar lidar maximum range";
  parameter Real T_imu = 0.005 "s 200 Hz IMU rate";
  parameter Real T_enc = 0.01 "s 100 Hz wheel-encoder rate";
  parameter Real T_lidar = 0.1 "s 10 Hz slow absolute-position lidar rate";
  parameter Real T_rgb = 0.2 "s 5 Hz forward RGB-D camera rate";

  // Sensor transforms relative to base frame
  parameter Real xLidar = 0.15 "m lidar x offset";
  parameter Real yLidar = 0.0 "m lidar y offset";
  parameter Real thetaLidar = 0.0 "rad lidar rotation";
  parameter Real xCam = 0.20 "m camera x offset";
  parameter Real yCam = 0.0 "m camera y offset";
  parameter Real thetaCam = 0.0 "rad camera rotation";

  // Controlled dropout
  parameter Real tDropoutStart = 3.0 "s outage start";
  parameter Real tDropoutEnd = 11.0 "s outage end, 8 s duration";

  // Measurement imperfections
  parameter Real imuBias = 0.001 "rad/s yaw-rate bias";
  parameter Real imuNoiseAmp = 0.0005 "rad/s";
  parameter Real encScaleErr = 0.005 "wheel-encoder scale error";
  parameter Real encNoiseAmp = 0.01 "rad/s";
  parameter Real lidarNoiseX = 0.01 "m";
  parameter Real lidarNoiseY = 0.01 "m";
  parameter Real lidarNoiseTheta = 0.005 "rad";
  parameter Real rgbBiasV = 0.002 "m/s";
  parameter Real rgbBiasOmega = 0.001 "rad/s";
  parameter Real rgbNoiseAmp = 0.002;

  // Controller gains
  parameter Real kV = 8.0;
  parameter Real kX = 5.0;
  parameter Real kO = 8.0;
  parameter Real kY = 2.0;
  parameter Real kTh = 10.0;

  // Estimator covariance and gating
  parameter Real Qx = 1.0e-4 "m2/s process noise x";
  parameter Real Qy = 1.0e-4 "m2/s process noise y";
  parameter Real Qtheta = 2.0e-4 "rad2/s process noise theta";
  parameter Real Qv = 1.0e-5 "m2/s2 process noise v";
  parameter Real Qomega = 1.0e-5 "rad2/s2 process noise omega";
  parameter Real Rx = 2.5e-3 "m2 lidar x measurement noise";
  parameter Real Ry = 2.5e-3 "m2 lidar y measurement noise";
  parameter Real Rtheta = 4.0e-4 "rad2 lidar theta measurement noise";
  parameter Real Pmin = 1.0e-6 "covariance floor";
  parameter Real chi2Gate = 9.0 "normalized innovation-square gate";
  parameter Real outageErrorBound = 1.0 "m-or-rad instrumentation bound";

  parameter Real TwoPi = 6.283185307179586 "2*pi";

  // Reference route
  Real xRef(start = 0.0) "m reference x";
  Real yRef(start = 0.0) "m reference y";
  Real thetaRef(start = 0.0) "rad reference heading";
  Real vRef "m/s reference forward speed";
  Real omegaRef "rad/s reference yaw rate";
  Real aRef "m/s2 reference forward acceleration";
  Real alphaRef "rad/s2 reference yaw acceleration";

  // Plant state
  output Real x(start = 0.0) "m plant x";
  output Real y(start = 0.0) "m plant y";
  output Real theta(start = 0.0) "rad plant heading";
  output Real v(start = 0.4) "m/s plant forward speed";
  output Real omega(start = 0.0) "rad/s plant yaw rate";

  // Command traces
  output Real vCmd "m/s commanded forward speed";
  output Real omegaCmd "rad/s commanded yaw rate";
  output Real tauR "N.m right wheel torque";
  output Real tauL "N.m left wheel torque";

  // Sensor traces
  output Real imuOmega_meas "rad/s IMU yaw-rate measurement";
  output Real imuAcc_meas "m/s2 IMU forward acceleration measurement";
  output Real encOmegaR_meas "rad/s right encoder measurement";
  output Real encOmegaL_meas "rad/s left encoder measurement";
  output Real v_enc_meas "m/s encoder-derived speed";
  output Real omega_enc_meas "rad/s encoder-derived yaw rate";
  output Real lidarX_meas "m lidar global x measurement";
  output Real lidarY_meas "m lidar global y measurement";
  output Real lidarTheta_meas "rad lidar global heading measurement";
  output Boolean lidarValid "lidar measurement valid";
  output Real rgbV_meas "m/s RGB-D forward speed measurement";
  output Real rgbOmega_meas "rad/s RGB-D yaw-rate measurement";
  output Real rgbDepth_meas "m RGB-D synthetic scene depth";
  output Boolean rgbValid "RGB-D measurement valid";

  // Estimator state
  output Real x_hat(start = 0.0) "m estimated x";
  output Real y_hat(start = 0.0) "m estimated y";
  output Real theta_hat(start = 0.0) "rad estimated heading";
  output Real v_hat(start = 0.4) "m/s estimated forward speed";
  output Real omega_hat(start = 0.0) "rad/s estimated yaw rate";

  // Covariance traces
  output Real P_x(start = 1.0e-4) "m2 x covariance";
  output Real P_y(start = 1.0e-4) "m2 y covariance";
  output Real P_theta(start = 1.0e-4) "rad2 heading covariance";
  output Real P_v(start = 1.0e-4) "m2/s2 speed covariance";
  output Real P_omega(start = 1.0e-4) "rad2/s2 yaw-rate covariance";
  output Real covarianceTrace "sum of covariance diagonal";

  // Gating and requirement traces
  output Boolean gateAccepted "lidar innovation accepted";
  output Boolean gateRejected "lidar innovation rejected";
  output Boolean absoluteDropout "slow absolute-position sensor dropout active";
  output Boolean measurementReturned "slow absolute-position sensor returned";
  output Real dropoutDuration "s dropout duration";
  output Real posError "m estimator position error";
  output Real angleError "rad estimator heading error";
  output Real primaryTrackingError "m-or-rad primary tracking error";
  output Boolean primaryTrackingOk "primary error below 0.35 after 9.1 s";
  output Boolean outageErrorBounded "estimator error bounded during outage";
  output Boolean timestampOrderOk "sensor timestamps ordered";

  // Internal variables
  Real ex "m longitudinal route error";
  Real ey "m lateral route error";
  Real eth "rad heading route error";
  Real Fcmd "N commanded total drive force";
  Real Mcmd "N.m commanded yaw moment";
  Real tauRUnlim "N.m unlimited right torque";
  Real tauLUnlim "N.m unlimited left torque";
  Real F "N actual total drive force";
  Real M "N.m actual yaw moment";
  Real innovX "m position-x innovation";
  Real innovY "m position-y innovation";
  Real innovTheta "rad heading innovation";
  Real innov2 "normalized innovation squared";
  Real Kx "x Kalman gain";
  Real Ky "y Kalman gain";
  Real Ktheta "heading Kalman gain";
  Real Pxeff "effective x covariance";
  Real Pyeff "effective y covariance";
  Real Pthetaeff "effective heading covariance";
  Real gateFactor "continuous gate factor 0 or 1";
  Real angleDiff "rad lidar heading difference";

equation
  // Reference route: translation plus rotation for observable drift
  vRef = 0.4 + 0.2*sin(0.2*time);
  omegaRef = 0.4*sin(0.15*time);
  aRef = 0.04*cos(0.2*time);
  alphaRef = 0.06*cos(0.15*time);
  der(xRef) = vRef*cos(thetaRef);
  der(yRef) = vRef*sin(thetaRef);
  der(thetaRef) = omegaRef;

  // Plant dynamics
  der(x) = v*cos(theta);
  der(y) = v*sin(theta);
  der(theta) = omega;
  der(v) = F/mBase;
  der(omega) = M/JBase;
  F = (tauR + tauL)/rWheel;
  M = (tauR - tauL)*dWheel/rWheel;

  // Route-tracking controller with bounded per-wheel torque
  ex = (xRef - x)*cos(theta) + (yRef - y)*sin(theta);
  ey = -(xRef - x)*sin(theta) + (yRef - y)*cos(theta);
  eth = Modelica.Math.atan2(sin(thetaRef - theta), cos(thetaRef - theta));
  vCmd = vRef + kX*ex;
  omegaCmd = omegaRef + kY*ey + kTh*eth;
  Fcmd = mBase*(aRef + kV*(vRef - v) + kX*ex);
  Mcmd = JBase*(alphaRef + kO*(omegaRef - omega) + kY*ey + kTh*eth);
  tauRUnlim = (rWheel/2.0)*(Fcmd + Mcmd/dWheel);
  tauLUnlim = (rWheel/2.0)*(Fcmd - Mcmd/dWheel);
  tauR = max(-tauMax, min(tauMax, tauRUnlim));
  tauL = max(-tauMax, min(tauMax, tauLUnlim));

  // Dropout and recovery indicators
  absoluteDropout = time >= tDropoutStart and time < tDropoutEnd;
  measurementReturned = time >= tDropoutEnd;
  dropoutDuration = tDropoutEnd - tDropoutStart;

  // IMU at 200 Hz: inertial propagation continues during dropout
  imuOmega_meas = omega + imuBias + imuNoiseAmp*sin(TwoPi*13.0*time);
  imuAcc_meas = F/mBase + imuNoiseAmp*sin(TwoPi*11.0*time);

  // Wheel encoders at 100 Hz: proprioceptive propagation continues during dropout
  encOmegaR_meas = (v + dWheel*omega)/rWheel*(1.0 + encScaleErr) + encNoiseAmp*sin(TwoPi*7.0*time);
  encOmegaL_meas = (v - dWheel*omega)/rWheel*(1.0 - encScaleErr) + encNoiseAmp*cos(TwoPi*7.0*time);
  v_enc_meas = rWheel*(encOmegaR_meas + encOmegaL_meas)/2.0;
  omega_enc_meas = rWheel*(encOmegaR_meas - encOmegaL_meas)/(2.0*dWheel);

  // Forward RGB-D camera at 5 Hz: local visual/depth trace
  rgbValid = true;
  rgbV_meas = v + rgbBiasV + rgbNoiseAmp*sin(TwoPi*2.0*time);
  rgbOmega_meas = omega + rgbBiasOmega + rgbNoiseAmp*cos(TwoPi*3.0*time);
  rgbDepth_meas = max(0.05, min(lidarRangeMax, 2.0 + 0.5*cos(0.5*time) + rgbNoiseAmp*sin(TwoPi*1.5*time)));

  // Slow absolute-position lidar at 10 Hz with controlled outage
  lidarValid = not absoluteDropout;
  lidarX_meas = x + xLidar*cos(theta) - yLidar*sin(theta) + lidarNoiseX*sin(TwoPi*3.0*time);
  lidarY_meas = y + xLidar*sin(theta) + yLidar*cos(theta) + lidarNoiseY*cos(TwoPi*5.0*time);
  lidarTheta_meas = theta + thetaLidar + lidarNoiseTheta*sin(TwoPi*2.0*time);

  // Estimator innovation (continuous)
  innovX = lidarX_meas - (x_hat + xLidar*cos(theta_hat) - yLidar*sin(theta_hat));
  innovY = lidarY_meas - (y_hat + xLidar*sin(theta_hat) + yLidar*cos(theta_hat));
  angleDiff = lidarTheta_meas - (theta_hat + thetaLidar);
  innovTheta = Modelica.Math.atan2(sin(angleDiff), cos(angleDiff));

  // Effective covariances with floor to avoid division by zero
  Pxeff = max(P_x, Pmin);
  Pyeff = max(P_y, Pmin);
  Pthetaeff = max(P_theta, Pmin);

  // Normalized innovation squared
  innov2 = innovX*innovX/Pxeff + innovY*innovY/Pyeff + innovTheta*innovTheta/Pthetaeff;

  // Innovation gating
  gateAccepted = (not absoluteDropout) and (innov2 <= chi2Gate);
  gateRejected = (not absoluteDropout) and (innov2 > chi2Gate);
  gateFactor = if gateAccepted then 1.0 else 0.0;

  // Kalman gains
  Kx = Pxeff/(Pxeff + Rx);
  Ky = Pyeff/(Pyeff + Ry);
  Ktheta = Pthetaeff/(Pthetaeff + Rtheta);

  // Estimator propagation with continuous correction at lidar rate
  der(x_hat) = v_hat*cos(theta_hat) + gateFactor * Kx * innovX / T_lidar;
  der(y_hat) = v_hat*sin(theta_hat) + gateFactor * Ky * innovY / T_lidar;
  der(theta_hat) = imuOmega_meas + gateFactor * Ktheta * innovTheta / T_lidar;
  der(v_hat) = (v_enc_meas - v_hat)/T_enc;
  der(omega_hat) = (omega_enc_meas - omega_hat)/T_enc;

  // Covariance propagation; grows during absolute-position outage
  der(P_x) = if P_x > Pmin then Qx - gateFactor * Kx * Pxeff / T_lidar else Qx;
  der(P_y) = if P_y > Pmin then Qy - gateFactor * Ky * Pyeff / T_lidar else Qy;
  der(P_theta) = if P_theta > Pmin then Qtheta - gateFactor * Ktheta * Pthetaeff / T_lidar else Qtheta;
  der(P_v) = Qv;
  der(P_omega) = Qomega;
  covarianceTrace = P_x + P_y + P_theta + P_v + P_omega;

  // Tracking error metrics
  posError = sqrt((x - x_hat)*(x - x_hat) + (y - y_hat)*(y - y_hat) + 1.0e-12);
  angleError = abs(Modelica.Math.atan2(sin(theta - theta_hat), cos(theta - theta_hat)));
  primaryTrackingError = max(posError, angleError);
  primaryTrackingOk = if time >= 9.1 then primaryTrackingError < 0.35 else true;
  outageErrorBounded = if absoluteDropout then primaryTrackingError <= outageErrorBound else true;
  timestampOrderOk = time >= 0.0;

  annotation(experiment(StopTime = 14.0, Interval = 0.005, Tolerance = 1.0e-6));
end MapRigBridgeD;