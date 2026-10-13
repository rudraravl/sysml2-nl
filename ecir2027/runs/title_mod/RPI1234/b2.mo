model MapRigBridgeD
  "Instrumented 22 kg mobile base with multi-rate sensing and an outage-tolerant state estimator."

  // Physical plant parameters
  parameter Real mBase = 22.0 "kg mobile base mass";
  parameter Real JBase = 2.2 "kg.m2 yaw inertia";
  parameter Real rWheel = 0.10 "m drive wheel radius";
  parameter Real dWheel = 0.30 "m half axle";
  parameter Real tauMax = 12.0 "N.m per-wheel torque limit";

  // Sensor rate parameters
  parameter Real lidarRangeMax = 20.0 "m planar lidar maximum range";
  parameter Real T_imu = 0.005 "s 200 Hz IMU rate";
  parameter Real T_enc = 0.01 "s 100 Hz encoder rate";
  parameter Real T_lidar = 0.1 "s 10 Hz lidar rate";
  parameter Real T_rgb = 0.2 "s 5 Hz RGB-D rate";

  // Sensor transforms relative to base frame
  parameter Real xLidar = 0.15 "m planar lidar x offset";
  parameter Real yLidar = 0.0 "m planar lidar y offset";
  parameter Real thetaLidar = 0.0 "rad planar lidar rotation";
  parameter Real xCam = 0.20 "m forward RGB-D camera x offset";
  parameter Real yCam = 0.0 "m forward RGB-D camera y offset";
  parameter Real thetaCam = 0.0 "rad forward RGB-D camera rotation";

  // Controlled 8 s dropout during middle third of 14 s run
  parameter Real tDropoutStart = 3.0 "s outage start";
  parameter Real tDropoutEnd = 11.0 "s outage end, 8 s duration";

  // Measurement imperfections (deterministic bounded instrumentation noise)
  parameter Real imuBias = 0.001 "rad/s yaw-rate bias";
  parameter Real imuNoiseAmp = 0.0005 "rad/s";
  parameter Real encScaleErr = 0.005 "wheel-encoder scale error";
  parameter Real encNoiseAmp = 0.01 "rad/s";
  parameter Real lidarNoiseX = 0.01 "m";
  parameter Real lidarNoiseY = 0.01 "m";
  parameter Real lidarNoiseTheta = 0.005 "rad";
  parameter Real rgbBiasV = 0.002 "m/s";
  parameter Real rgbBiasOmega = 0.001 "rad/s";
  parameter Real rgbNoiseAmp = 0.002 "m/s";

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
  parameter Real Rx = 2.5e-3 "m2 measurement noise x";
  parameter Real Ry = 2.5e-3 "m2 measurement noise y";
  parameter Real Rtheta = 4.0e-4 "rad2 measurement noise theta";
  parameter Real Pmin = 1.0e-6 "covariance floor";
  parameter Real chi2Gate = 9.0 "normalized innovation-square gate";
  parameter Real outageErrorBound = 1.0 "m-or-rad bounded outage error";

  constant Real PI = 3.141592653589793;

  // Reference trajectory with translation and rotation
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

  // IMU traces at 200 Hz
  output Real t_imu(start = 0.0) "s IMU timestamp";
  output Real imuOmega_meas(start = 0.0) "rad/s IMU yaw-rate measurement";
  output Real imuAcc_meas(start = 0.0) "m/s2 IMU forward acceleration measurement";

  // Encoder traces at 100 Hz
  output Real t_enc(start = 0.0) "s encoder timestamp";
  output Real encOmegaR_meas(start = 0.0) "rad/s right encoder measurement";
  output Real encOmegaL_meas(start = 0.0) "rad/s left encoder measurement";
  output Real v_enc_meas(start = 0.4) "m/s encoder-derived speed";
  output Real omega_enc_meas(start = 0.0) "rad/s encoder-derived yaw rate";

  // Lidar traces at 10 Hz (slow absolute-position sensor)
  output Real t_lidar(start = 0.0) "s lidar timestamp";
  output Boolean lidarValid(start = false) "lidar absolute-position measurement valid";
  output Real lidarX_meas(start = 0.0) "m lidar global x measurement";
  output Real lidarY_meas(start = 0.0) "m lidar global y measurement";
  output Real lidarTheta_meas(start = 0.0) "rad lidar global heading measurement";

  // RGB-D camera traces at 5 Hz
  output Real t_rgb(start = 0.0) "s RGB-D timestamp";
  output Boolean rgbValid(start = true) "RGB-D measurement valid";
  output Real rgbV_meas(start = 0.0) "m/s RGB-D forward speed measurement";
  output Real rgbOmega_meas(start = 0.0) "rad/s RGB-D yaw-rate measurement";
  output Real rgbDepth_meas(start = 2.0) "m RGB-D synthetic scene depth";

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
  output Real covarianceTrace "sum of estimator covariance diagonal";

  // Gating and requirement traces
  output Boolean gateAccepted(start = false) "lidar innovation accepted";
  output Boolean gateRejected(start = false) "lidar innovation rejected";
  output Boolean absoluteDropout "slow absolute-position sensor dropout active";
  output Boolean measurementReturned "slow absolute-position sensor returned";
  output Real dropoutDuration "s dropout duration";
  output Real posError "m estimator position error";
  output Real angleError "rad estimator heading error";
  output Real primaryTrackingError "m-or-rad primary estimator tracking error";
  output Boolean primaryTrackingOk "primary error below 0.35 after 9.1 s";
  output Boolean outageErrorBounded "estimator error bounded during outage";
  output Boolean timestampOrderOk "sensor timestamps ordered with current time";

  // Internal controller variables
  Real ex "m longitudinal route error";
  Real ey "m lateral route error";
  Real eth "rad heading route error";
  Real Fcmd "N commanded total drive force";
  Real Mcmd "N.m commanded yaw moment";
  Real tauRUnlim "N.m unlimited right torque";
  Real tauLUnlim "N.m unlimited left torque";
  Real F "N actual total drive force";
  Real M "N.m actual yaw moment";
  Real thetaErrWrap "wrapped reference-heading error";

  // Internal estimator variables (assigned in lidar when block)
  Real predLidarX(start = 0.0) "m predicted lidar x";
  Real predLidarY(start = 0.0) "m predicted lidar y";
  Real predLidarTheta(start = 0.0) "rad predicted lidar heading";
  Real innovX(start = 0.0) "m position-x innovation";
  Real innovY(start = 0.0) "m position-y innovation";
  Real innovTheta(start = 0.0) "rad heading innovation";
  Real innov2(start = 0.0) "normalized innovation squared";
  Real Kx(start = 0.0) "x Kalman gain";
  Real Ky(start = 0.0) "y Kalman gain";
  Real Ktheta(start = 0.0) "heading Kalman gain";
  Real Pxeff(start = Pmin) "effective x covariance";
  Real Pyeff(start = Pmin) "effective y covariance";
  Real Pthetaeff(start = Pmin) "effective heading covariance";
  Real corrX(start = 0.0) "m x correction applied";
  Real corrY(start = 0.0) "m y correction applied";
  Real corrTh(start = 0.0) "rad heading correction applied";
  Real newPx(start = 1.0e-4) "updated P_x after correction";
  Real newPy(start = 1.0e-4) "updated P_y after correction";
  Real newPth(start = 1.0e-4) "updated P_theta after correction";
  Real thetaInnovWrap "wrapped estimator heading error for diagnostics";

equation
  // Reference route: positive forward speed plus sinusoidal yaw for observable drift
  vRef = 0.4 + 0.2*sin(0.2*time);
  omegaRef = 0.4*sin(0.15*time);
  aRef = 0.04*cos(0.2*time);
  alphaRef = 0.06*cos(0.15*time);
  der(xRef) = vRef*cos(thetaRef);
  der(yRef) = vRef*sin(thetaRef);
  der(thetaRef) = omegaRef;

  // Plant dynamics: unicycle with bounded wheel torques
  der(x) = v*cos(theta);
  der(y) = v*sin(theta);
  der(theta) = omega;
  der(v) = F/mBase;
  der(omega) = M/JBase;
  F = (tauR + tauL)/rWheel;
  M = (tauR - tauL)*dWheel/rWheel;

  // Route-tracking controller
  ex = (xRef - x)*cos(theta) + (yRef - y)*sin(theta);
  ey = -(xRef - x)*sin(theta) + (yRef - y)*cos(theta);
  thetaErrWrap = Modelica.Math.atan2(sin(thetaRef - theta), cos(thetaRef - theta));
  eth = thetaErrWrap;
  vCmd = vRef + kX*ex;
  omegaCmd = omegaRef + kY*ey + kTh*eth;
  Fcmd = mBase*(aRef + kV*(vRef - v) + kX*ex);
  Mcmd = JBase*(alphaRef + kO*(omegaRef - omega) + kY*ey + kTh*eth);
  tauRUnlim = (rWheel/2.0)*(Fcmd + Mcmd/dWheel);
  tauLUnlim = (rWheel/2.0)*(Fcmd - Mcmd/dWheel);
  tauR = if tauRUnlim > tauMax then tauMax elseif tauRUnlim < -tauMax then -tauMax else tauRUnlim;
  tauL = if tauLUnlim > tauMax then tauMax elseif tauLUnlim < -tauMax then -tauMax else tauLUnlim;

  // Dropout and recovery indicators
  absoluteDropout = time >= tDropoutStart and time < tDropoutEnd;
  measurementReturned = time >= tDropoutEnd;
  dropoutDuration = tDropoutEnd - tDropoutStart;

  // Multi-rate estimator propagation using inertial and proprioceptive holds
  der(x_hat) = v_hat*cos(theta_hat);
  der(y_hat) = v_hat*sin(theta_hat);
  der(theta_hat) = imuOmega_meas;
  der(v_hat) = (v_enc_meas - v_hat)/T_enc;
  der(omega_hat) = (omega_enc_meas - omega_hat)/T_enc;

  // Covariance propagation; grows during absolute-position outage
  der(P_x) = Qx;
  der(P_y) = Qy;
  der(P_theta) = Qtheta;
  der(P_v) = Qv;
  der(P_omega) = Qomega;
  covarianceTrace = P_x + P_y + P_theta + P_v + P_omega;

  // Primary estimator tracking error in m-or-rad
  posError = sqrt((x - x_hat)*(x - x_hat) + (y - y_hat)*(y - y_hat));
  thetaInnovWrap = Modelica.Math.atan2(sin(theta - theta_hat), cos(theta - theta_hat));
  angleError = abs(thetaInnovWrap);
  primaryTrackingError = if posError > angleError then posError else angleError;
  primaryTrackingOk = if time >= 9.1 then primaryTrackingError < 0.35 else true;
  outageErrorBounded = if absoluteDropout then primaryTrackingError <= outageErrorBound else true;
  timestampOrderOk = time >= t_imu and time >= t_enc and time >= t_lidar and time >= t_rgb;

  assert(rWheel > 0.0, "Drive wheel radius must be positive");
  assert(dWheel > 0.0, "Half axle must be positive");
  assert(Pmin > 0.0, "Covariance floor must be positive");

  // IMU at 200 Hz: inertial propagation continues during dropout
  when sample(0, T_imu) then
    t_imu = time;
    imuOmega_meas = omega + imuBias + imuNoiseAmp*sin(2.0*PI*13.0*time);
    imuAcc_meas = F/mBase + imuNoiseAmp*sin(2.0*PI*11.0*time);
  end when;

  // Wheel encoders at 100 Hz: proprioceptive propagation continues during dropout
  when sample(0, T_enc) then
    t_enc = time;
    encOmegaR_meas = (v + dWheel*omega)/rWheel*(1.0 + encScaleErr) + encNoiseAmp*sin(2.0*PI*7.0*time);
    encOmegaL_meas = (v - dWheel*omega)/rWheel*(1.0 - encScaleErr) + encNoiseAmp*cos(2.0*PI*7.0*time);
    v_enc_meas = rWheel*(encOmegaR_meas + encOmegaL_meas)/2.0;
    omega_enc_meas = rWheel*(encOmegaR_meas - encOmegaL_meas)/(2.0*dWheel);
  end when;

  // Forward RGB-D camera at 5 Hz: local visual/depth trace
  when sample(0, T_rgb) then
    t_rgb = time;
    rgbValid = true;
    rgbV_meas = v + rgbBiasV + rgbNoiseAmp*sin(2.0*PI*2.0*time);
    rgbOmega_meas = omega + rgbBiasOmega + rgbNoiseAmp*cos(2.0*PI*3.0*time);
    rgbDepth_meas = 2.0 + 0.5*cos(0.5*time) + rgbNoiseAmp*sin(2.0*PI*1.5*time);
  end when;

  // Slow absolute-position lidar at 10 Hz with innovation gating and controlled outage
  when sample(0, T_lidar) then
    t_lidar = time;
    lidarValid = not absoluteDropout;

    // Hold measurements during dropout window
    if absoluteDropout then
      lidarX_meas = pre(lidarX_meas);
      lidarY_meas = pre(lidarY_meas);
      lidarTheta_meas = pre(lidarTheta_meas);
    else
      lidarX_meas = x + xLidar*cos(theta) - yLidar*sin(theta) + lidarNoiseX*sin(2.0*PI*3.0*time);
      lidarY_meas = y + xLidar*sin(theta) + yLidar*cos(theta) + lidarNoiseY*cos(2.0*PI*5.0*time);
      lidarTheta_meas = theta + thetaLidar + lidarNoiseTheta*sin(2.0*PI*2.0*time);
    end if;

    // Predicted measurement from estimator state
    predLidarX = x_hat + xLidar*cos(theta_hat) - yLidar*sin(theta_hat);
    predLidarY = y_hat + xLidar*sin(theta_hat) + yLidar*cos(theta_hat);
    predLidarTheta = theta_hat + thetaLidar;

    // Innovation
    innovX = lidarX_meas - predLidarX;
    innovY = lidarY_meas - predLidarY;
    innovTheta = Modelica.Math.atan2(sin(lidarTheta_meas - predLidarTheta), cos(lidarTheta_meas - predLidarTheta));

    // Effective covariance with floor to avoid division by zero
    Pxeff = if P_x > Pmin then P_x else Pmin;
    Pyeff = if P_y > Pmin then P_y else Pmin;
    Pthetaeff = if P_theta > Pmin then P_theta else Pmin;

    // Normalized innovation squared
    innov2 = innovX*innovX/Pxeff + innovY*innovY/Pyeff + innovTheta*innovTheta/Pthetaeff;

    // Gating decision
    gateAccepted = (not absoluteDropout) and (innov2 <= chi2Gate);
    gateRejected = (not absoluteDropout) and (innov2 > chi2Gate);

    // Kalman gains
    Kx = Pxeff/(Pxeff + Rx);
    Ky = Pyeff/(Pyeff + Ry);
    Ktheta = Pthetaeff/(Pthetaeff + Rtheta);

    // Correction amounts (zero when not accepted or during dropout)
    corrX = if gateAccepted then Kx*innovX else 0.0;
    corrY = if gateAccepted then Ky*innovY else 0.0;
    corrTh = if gateAccepted then Ktheta*innovTheta else 0.0;
    newPx = if gateAccepted then (1.0 - Kx)*Pxeff else P_x;
    newPy = if gateAccepted then (1.0 - Ky)*Pyeff else P_y;
    newPth = if gateAccepted then (1.0 - Ktheta)*Pthetaeff else P_theta;

    // Apply correction via reinit (no-op when correction is zero)
    reinit(x_hat, x_hat + corrX);
    reinit(y_hat, y_hat + corrY);
    reinit(theta_hat, theta_hat + corrTh);
    reinit(P_x, newPx);
    reinit(P_y, newPy);
    reinit(P_theta, newPth);
  end when;

  annotation(experiment(StopTime = 14.0, Interval = 0.005, Tolerance = 1.0e-6));
end MapRigBridgeD;