model MapRigLocalizeF
  function angDiff
    "Wrap angle difference to [-PI, PI]."
    input Real a;
    input Real b;
    output Real y;
  protected
    constant Real PI = 3.141592653589793;
  algorithm
    y := a - b;
    y := y - 2.0*PI*floor(0.5 + y/(2.0*PI));
  end angDiff;

  constant Real PI = 3.141592653589793;

  // Requirement-specified facts.
  parameter Real mass = 22.0 "kg";
  parameter Real lidarMaxRange = 20.0 "m";
  parameter Real tauMax = 14.6 "N.m";
  parameter Real biasStep = 0.058 "rad/s";
  parameter Real baseRate = 500.0 "Hz";
  parameter Real stopTime = 20.0 "s";
  parameter Real trackingTime = 13.0 "s";
  parameter Real trackingLimit = 0.16 "m-or-rad combined error";

  // Nominal bounded route and plant geometry/dynamics.
  // These values are not requirement facts; they are bounded engineering
  // assumptions needed for a simulatable scenario.
  parameter Real routeRadius = 5.0 "m";
  parameter Real routeRate = 0.2 "rad/s";
  parameter Real wheelRadius = 0.1 "m";
  parameter Real wheelHalf = 0.2 "m";
  parameter Real inertia = 2.0 "kg.m2";
  parameter Real cLin = 2.0 "N.s/m";
  parameter Real cRot = 1.0 "N.m.s/rad";
  parameter Real kpx = 0.5 "1/s";
  parameter Real kpy = 1.0 "1/s";
  parameter Real kth = 1.0 "1/s";
  parameter Real kv = 2.0 "1/s";
  parameter Real kw = 2.0 "1/s";

  // Sensor rates as integer divisors of the 500 Hz base clock.
  parameter Real dtIMU = 1.0/baseRate "s";
  parameter Real dtEnc = 2.0*dtIMU "s";
  parameter Real dtLidar = 5.0*dtIMU "s";
  parameter Real dtCamera = 10.0*dtIMU "s";

  // Offsets prevent simultaneous asynchronous update events.
  parameter Real tOffIMU = 0.0 "s";
  parameter Real tOffEnc = 0.0007 "s";
  parameter Real tOffLidar = 0.0015 "s";
  parameter Real tOffCamera = 0.003 "s";

  // Sensor frame IDs and transforms.
  parameter Real frameIdIMU = 4.0 "1";
  parameter Real frameIdEnc = 3.0 "1";
  parameter Real frameIdLidar = 1.0 "1";
  parameter Real frameIdCamera = 2.0 "1";

  parameter Real imuX = 0.10 "m";
  parameter Real imuY = 0.0 "m";
  parameter Real imuTheta = 0.0 "rad";
  parameter Real encLeftX = -0.20 "m";
  parameter Real encRightX = 0.20 "m";
  parameter Real lidarX = 0.0 "m";
  parameter Real lidarY = 0.0 "m";
  parameter Real lidarTheta = 0.0 "rad";
  parameter Real cameraX = 0.15 "m";
  parameter Real cameraY = 0.0 "m";
  parameter Real cameraTheta = 0.0 "rad";

  // Fixed external landmarks. Estimator receives only sensor outputs.
  parameter Real LMx1 = 8.0 "m";
  parameter Real LMy1 = 0.0 "m";
  parameter Real LMx2 = -4.0 "m";
  parameter Real LMy2 = 6.0 "m";
  parameter Real LMx3 = -4.0 "m";
  parameter Real LMy3 = -6.0 "m";

  // Sensor standard deviations and bias states.
  parameter Real stdIMUOmega = 0.001 "rad/s";
  parameter Real stdIMUAcc = 0.01 "m/s2";
  parameter Real stdEncV = 0.01 "m/s";
  parameter Real stdEncOmega = 0.005 "rad/s";
  parameter Real stdLidarX = 0.05 "m";
  parameter Real stdLidarY = 0.05 "m";
  parameter Real stdLidarTheta = 0.05 "rad";
  parameter Real stdCameraX = 0.08 "m";
  parameter Real stdCameraY = 0.08 "m";
  parameter Real stdCameraTheta = 0.05 "rad";
  parameter Real stdGyroBias = 0.01 "rad/s";
  parameter Real stdEncVb = 0.1 "m/s";
  parameter Real stdOdomBias = 0.1 "rad/s";

  parameter Real biasAccActual = 0.0 "m/s2";
  parameter Real biasEncVActual = 0.0 "m/s";
  parameter Real biasEncOmegaActual = 0.0 "rad/s";
  parameter Real biasLidarXActual = 0.0 "m";
  parameter Real biasLidarYActual = 0.0 "m";
  parameter Real biasLidarThetaActual = 0.0 "rad";
  parameter Real biasCameraXActual = 0.0 "m";
  parameter Real biasCameraYActual = 0.0 "m";
  parameter Real biasCameraThetaActual = 0.0 "rad";

  // Measurement variances.
  parameter Real REncV = stdEncV*stdEncV;
  parameter Real REncOmega = stdEncOmega*stdEncOmega;
  parameter Real RLx = stdLidarX*stdLidarX;
  parameter Real RLy = stdLidarY*stdLidarY;
  parameter Real RLtheta = stdLidarTheta*stdLidarTheta;
  parameter Real RCameraX = stdCameraX*stdCameraX;
  parameter Real RCameraY = stdCameraY*stdCameraY;
  parameter Real RCameraTheta = stdCameraTheta*stdCameraTheta;
  parameter Real RGyro = stdGyroBias*stdGyroBias;
  parameter Real REncVb = stdEncVb*stdEncVb;
  parameter Real REncOmegab = stdOdomBias*stdOdomBias;

  // EKF process noise variance rates.
  parameter Real QLx = 0.01 "m2/s";
  parameter Real QLy = 0.01 "m2/s";
  parameter Real Qtheta = 0.01 "rad2/s";
  parameter Real Qv = 0.01 "(m/s)2/s";
  parameter Real Qomega = 0.01 "(rad/s)2/s";
  parameter Real QGyro = 0.01 "(rad/s)2/s";
  parameter Real QEncVb = 0.0001 "(m/s)2/s";
  parameter Real QOdom = 0.0001 "(rad/s)2/s";

  parameter Real tauEst = 0.02 "s";
  parameter Real posErrorBand = 0.15 "m";
  parameter Real attErrorBand = 0.15 "rad";
  parameter Real biasConvergenceTime = 14.0 "s";
  parameter Real biasConvergenceLimit = 0.02 "rad/s";

  // Plant states.
  Real x(start=5.0, fixed=true, unit="m");
  Real y(start=0.0, fixed=true, unit="m");
  Real theta(start=PI/2, fixed=true, unit="rad");
  Real v(start=1.0, fixed=true, unit="m/s");
  Real omega(start=0.2, fixed=true, unit="rad/s");
  Real F "N";
  Real M "N.m";
  Real tauR "N.m";
  Real tauL "N.m";
  Real tauRcmd "N.m";
  Real tauLcmd "N.m";
  Real Fdes "N";
  Real Mdes "N.m";

  // Reference route.
  Real refX "m";
  Real refY "m";
  Real refTheta "rad";
  Real vRef "m/s";
  Real omegaRef "rad/s";
  Real ex "m";
  Real ey "m";
  Real eth "rad";
  Real vDes "m/s";
  Real omegaDes "rad/s";

  // Estimator states.
  Real xh(start=5.0, fixed=true, unit="m");
  Real yh(start=0.0, fixed=true, unit="m");
  Real thetah(start=PI/2, fixed=true, unit="rad");
  Real vh(start=1.0, fixed=true, unit="m/s");
  Real omegah(start=0.2, fixed=true, unit="rad/s");
  Real bGyroEst(start=0.0, fixed=true, unit="rad/s");
  Real bEncVEst(start=0.0, fixed=true, unit="m/s");
  Real bOdomEst(start=0.0, fixed=true, unit="rad/s");

  // Covariance states.
  discrete Real Pxx(start=1.0, fixed=true, unit="m2");
  discrete Real Pyy(start=1.0, fixed=true, unit="m2");
  discrete Real Ptheta(start=1.0, fixed=true, unit="rad2");
  discrete Real Pv(start=1.0, fixed=true, unit="(m/s)2");
  discrete Real Pomega(start=1.0, fixed=true, unit="(rad/s)2");
  discrete Real PbGyro(start=0.01, fixed=true, unit="(rad/s)2");
  discrete Real PbEncV(start=0.01, fixed=true, unit="(m/s)2");
  discrete Real PbOdom(start=0.01, fixed=true, unit="(rad/s)2");

  // Sensor traces.
  discrete Real omegaIMUsamp(start=0.2, fixed=true, unit="rad/s");
  discrete Real accIMUsamp(start=0.0, fixed=true, unit="m/s2");
  discrete Real lastIMUTime(start=0.0, fixed=true, unit="s");
  discrete Integer imuSeq(start=0, fixed=true);

  discrete Real vEncSamp(start=1.0, fixed=true, unit="m/s");
  discrete Real omegaEncSamp(start=0.2, fixed=true, unit="rad/s");
  discrete Real lastEncTime(start=0.0, fixed=true, unit="s");
  discrete Integer encSeq(start=0, fixed=true);

  discrete Real zLidarXSampled(start=5.0, fixed=true, unit="m");
  discrete Real zLidarYSampled(start=0.0, fixed=true, unit="m");
  discrete Real zLidarThetaSampled(start=PI/2, fixed=true, unit="rad");
  discrete Real rangeL1Samp(start=3.0, fixed=true, unit="m");
  discrete Real bearingL1Samp(start=-PI/2, fixed=true, unit="rad");
  discrete Real rangeL2Samp(start=10.8167, fixed=true, unit="m");
  discrete Real bearingL2Samp(start=0.9828, fixed=true, unit="rad");
  discrete Real rangeL3Samp(start=10.8167, fixed=true, unit="m");
  discrete Real bearingL3Samp(start=-0.9828, fixed=true, unit="rad");
  discrete Real lastLidarTime(start=0.0, fixed=true, unit="s");
  discrete Integer lidarSeq(start=0, fixed=true);

  discrete Real zCameraXSampled(start=5.0, fixed=true, unit="m");
  discrete Real zCameraYSampled(start=0.0, fixed=true, unit="m");
  discrete Real zCameraThetaSampled(start=PI/2, fixed=true, unit="rad");
  discrete Real cameraDepth1Samp(start=2.85, fixed=true, unit="m");
  discrete Real cameraBearing1Samp(start=-PI/2, fixed=true, unit="rad");
  discrete Real lastCameraTime(start=0.0, fixed=true, unit="s");
  discrete Integer cameraSeq(start=0, fixed=true);

  // Continuous sensor values.
  Boolean biasStepActive;
  Real biasGyroActual "rad/s";
  Real omegaIMU_cont "rad/s";
  Real accIMU_cont "m/s2";
  Real vEnc_cont "m/s";
  Real omegaEnc_cont "rad/s";
  Real zLidarX "m";
  Real zLidarY "m";
  Real zLidarTheta "rad";
  Real zCameraX "m";
  Real zCameraY "m";
  Real zCameraTheta "rad";

  // Lidar landmark observation intermediates.
  Real sensorLidarX "m";
  Real sensorLidarY "m";
  Real sensorLidarTheta "rad";
  Real dxw1 "m";
  Real dyw1 "m";
  Real dx1 "m";
  Real dy1 "m";
  Real rangeL1 "m";
  Real bearingL1 "rad";
  Real dxw2 "m";
  Real dyw2 "m";
  Real dx2 "m";
  Real dy2 "m";
  Real rangeL2 "m";
  Real bearingL2 "rad";
  Real dxw3 "m";
  Real dyw3 "m";
  Real dx3 "m";
  Real dy3 "m";
  Real rangeL3 "m";
  Real bearingL3 "rad";

  // Camera landmark observation intermediates.
  Real sensorCameraX "m";
  Real sensorCameraY "m";
  Real sensorCameraTheta "rad";
  Real dxCw1 "m";
  Real dyCw1 "m";
  Real dxC1 "m";
  Real dyC1 "m";
  Real rangeC1 "m";
  Real bearingC1 "rad";
  Real cameraDepth1 "m";

  // Verification variables.
  Real positionError "m";
  Real attitudeError "rad";
  Real primaryTrackingError "m-or-rad";
  Real estPositionError "m";
  Real estAttitudeError "rad";
  Real biasError "rad/s";

equation
  // Bounded mapping route.
  refX = routeRadius*cos(routeRate*time);
  refY = routeRadius*sin(routeRate*time);
  refTheta = routeRate*time + PI/2;
  vRef = routeRadius*routeRate;
  omegaRef = routeRate;

  // Plant dynamics.
  F = (tauR + tauL)/wheelRadius;
  M = (tauR - tauL)*wheelHalf/wheelRadius;
  der(v) = (F - cLin*v)/mass;
  der(omega) = (M - cRot*omega)/inertia;
  der(x) = v*cos(theta);
  der(y) = v*sin(theta);
  der(theta) = omega;

  // Controller using estimated pose.
  ex = cos(thetah)*(refX - xh) + sin(thetah)*(refY - yh);
  ey = -sin(thetah)*(refX - xh) + cos(thetah)*(refY - yh);
  eth = angDiff(refTheta, thetah);
  vDes = max(-2.0, min(2.0, vRef + kpx*ex));
  omegaDes = max(-1.0, min(1.0, omegaRef + kpy*ey + kth*eth));
  Fdes = cLin*v + mass*kv*(vDes - v);
  Mdes = cRot*omega + inertia*kw*(omegaDes - omega);
  tauRcmd = 0.5*(Fdes*wheelRadius + Mdes*wheelRadius/wheelHalf);
  tauLcmd = 0.5*(Fdes*wheelRadius - Mdes*wheelRadius/wheelHalf);
  tauR = max(-tauMax, min(tauMax, tauRcmd));
  tauL = max(-tauMax, min(tauMax, tauLcmd));

  // Sensor bias disturbance: middle third of 20 s.
  biasStepActive = time >= 20.0/3.0 and time <= 40.0/3.0;
  biasGyroActual = if biasStepActive then biasStep else 0.0;

  // Continuous ideal sensor outputs.
  omegaIMU_cont = omega + biasGyroActual;
  accIMU_cont = (F - cLin*v)/mass + biasAccActual;
  vEnc_cont = v + biasEncVActual;
  omegaEnc_cont = omega + biasEncOmegaActual;
  zLidarX = x + biasLidarXActual;
  zLidarY = y + biasLidarYActual;
  zLidarTheta = theta + biasLidarThetaActual;
  zCameraX = x + biasCameraXActual;
  zCameraY = y + biasCameraYActual;
  zCameraTheta = theta + biasCameraThetaActual;

  // Lidar landmark observations in lidar frame.
  sensorLidarX = x + cos(theta)*lidarX - sin(theta)*lidarY;
  sensorLidarY = y + sin(theta)*lidarX + cos(theta)*lidarY;
  sensorLidarTheta = theta + lidarTheta;

  dxw1 = LMx1 - sensorLidarX;
  dyw1 = LMy1 - sensorLidarY;
  dx1 = cos(sensorLidarTheta)*dxw1 + sin(sensorLidarTheta)*dyw1;
  dy1 = -sin(sensorLidarTheta)*dxw1 + cos(sensorLidarTheta)*dyw1;
  rangeL1 = sqrt(max(dx1*dx1 + dy1*dy1, 1e-12));
  bearingL1 = atan2(dy1, dx1);

  dxw2 = LMx2 - sensorLidarX;
  dyw2 = LMy2 - sensorLidarY;
  dx2 = cos(sensorLidarTheta)*dxw2 + sin(sensorLidarTheta)*dyw2;
  dy2 = -sin(sensorLidarTheta)*dxw2 + cos(sensorLidarTheta)*dyw2;
  rangeL2 = sqrt(max(dx2*dx2 + dy2*dy2, 1e-12));
  bearingL2 = atan2(dy2, dx2);

  dxw3 = LMx3 - sensorLidarX;
  dyw3 = LMy3 - sensorLidarY;
  dx3 = cos(sensorLidarTheta)*dxw3 + sin(sensorLidarTheta)*dyw3;
  dy3 = -sin(sensorLidarTheta)*dxw3 + cos(sensorLidarTheta)*dyw3;
  rangeL3 = sqrt(max(dx3*dx3 + dy3*dy3, 1e-12));
  bearingL3 = atan2(dy3, dx3);

  // Camera landmark observations in forward RGB-D frame.
  sensorCameraX = x + cos(theta)*cameraX - sin(theta)*cameraY;
  sensorCameraY = y + sin(theta)*cameraX + cos(theta)*cameraY;
  sensorCameraTheta = theta + cameraTheta;
  dxCw1 = LMx1 - sensorCameraX;
  dyCw1 = LMy1 - sensorCameraY;
  dxC1 = cos(sensorCameraTheta)*dxCw1 + sin(sensorCameraTheta)*dyCw1;
  dyC1 = -sin(sensorCameraTheta)*dxCw1 + cos(sensorCameraTheta)*dyCw1;
  rangeC1 = sqrt(max(dxC1*dxC1 + dyC1*dyC1, 1e-12));
  bearingC1 = atan2(dyC1, dxC1);
  cameraDepth1 = if rangeC1 <= lidarMaxRange then rangeC1 else -1.0;

  // Estimator prediction.
  der(xh) = vh*cos(thetah);
  der(yh) = vh*sin(thetah);
  der(thetah) = omegah;
  der(vh) = (vEncSamp - bEncVEst - vh)/tauEst;
  der(omegah) = (omegaIMUsamp - bGyroEst - omegah)/tauEst;
  der(bGyroEst) = 0.0;
  der(bEncVEst) = 0.0;
  der(bOdomEst) = 0.0;

  // Verification metrics.
  positionError = sqrt(max((refX - x)*(refX - x) + (refY - y)*(refY - y), 1e-12));
  attitudeError = abs(angDiff(refTheta, theta));
  primaryTrackingError = sqrt(max(positionError*positionError + attitudeError*attitudeError, 1e-12));
  estPositionError = sqrt(max((x - xh)*(x - xh) + (y - yh)*(y - yh), 1e-12));
  estAttitudeError = abs(angDiff(theta, thetah));
  biasError = abs(bGyroEst - biasGyroActual);

  // Asynchronous IMU sampling and covariance prediction.
  when sample(tOffIMU, dtIMU) then
    omegaIMUsamp = omegaIMU_cont;
    accIMUsamp = accIMU_cont;
    lastIMUTime = time;
    imuSeq = pre(imuSeq) + 1;
    Pxx = pre(Pxx) + QLx*dtIMU;
    Pyy = pre(Pyy) + QLy*dtIMU;
    Ptheta = pre(Ptheta) + Qtheta*dtIMU;
    Pv = pre(Pv) + Qv*dtIMU;
    Pomega = pre(Pomega) + Qomega*dtIMU;
    PbGyro = pre(PbGyro) + QGyro*dtIMU;
    PbEncV = pre(PbEncV) + QEncVb*dtIMU;
    PbOdom = pre(PbOdom) + QOdom*dtIMU;
  end when;

  // Asynchronous encoder updates.
  when sample(tOffEnc, dtEnc) then
    vEncSamp = vEnc_cont;
    omegaEncSamp = omegaEnc_cont;
    lastEncTime = time;
    encSeq = pre(encSeq) + 1;

    reinit(vh, pre(vh) + (pre(Pv)/(pre(Pv) + REncV))*(vEnc_cont - pre(bEncVEst) - pre(vh)));
    Pv = pre(Pv)*REncV/(pre(Pv) + REncV) + Qv*dtEnc;

    reinit(bEncVEst, pre(bEncVEst) + (pre(PbEncV)/(pre(PbEncV) + REncVb))*(vEnc_cont - pre(bEncVEst) - pre(vh)));
    PbEncV = pre(PbEncV)*REncVb/(pre(PbEncV) + REncVb) + QEncVb*dtEnc;

    reinit(omegah, pre(omegah) + (pre(Pomega)/(pre(Pomega) + REncOmega))*(omegaEnc_cont - pre(bOdomEst) - pre(omegah)));
    Pomega = pre(Pomega)*REncOmega/(pre(Pomega) + REncOmega) + Qomega*dtEnc;

    reinit(bOdomEst, pre(bOdomEst) + (pre(PbOdom)/(pre(PbOdom) + REncOmegab))*(omegaEnc_cont - pre(bOdomEst) - pre(omegah)));
    PbOdom = pre(PbOdom)*REncOmegab/(pre(PbOdom) + REncOmegab) + QOdom*dtEnc;
  end when;

  // Asynchronous lidar map updates.
  when sample(tOffLidar, dtLidar) then
    zLidarXSampled = zLidarX;
    zLidarYSampled = zLidarY;
    zLidarThetaSampled = zLidarTheta;
    rangeL1Samp = if rangeL1 <= lidarMaxRange then rangeL1 else -1.0;
    bearingL1Samp = bearingL1;
    rangeL2Samp = if rangeL2 <= lidarMaxRange then rangeL2 else -1.0;
    bearingL2Samp = bearingL2;
    rangeL3Samp = if rangeL3 <= lidarMaxRange then rangeL3 else -1.0;
    bearingL3Samp = bearingL3;
    lastLidarTime = time;
    lidarSeq = pre(lidarSeq) + 1;

    reinit(xh, pre(xh) + (pre(Pxx)/(pre(Pxx) + RLx))*(zLidarX - pre(xh)));
    Pxx = pre(Pxx)*RLx/(pre(Pxx) + RLx) + QLx*dtLidar;

    reinit(yh, pre(yh) + (pre(Pyy)/(pre(Pyy) + RLy))*(zLidarY - pre(yh)));
    Pyy = pre(Pyy)*RLy/(pre(Pyy) + RLy) + QLy*dtLidar;

    reinit(thetah, pre(thetah) + (pre(Ptheta)/(pre(Ptheta) + RLtheta))*angDiff(zLidarTheta, pre(thetah)));
    Ptheta = pre(Ptheta)*RLtheta/(pre(Ptheta) + RLtheta) + Qtheta*dtLidar;

    reinit(bGyroEst, pre(bGyroEst) - (pre(PbGyro)/(pre(PbGyro) + RGyro))*angDiff(zLidarTheta, pre(thetah)));
    PbGyro = pre(PbGyro)*RGyro/(pre(PbGyro) + RGyro) + QGyro*dtLidar;
  end when;

  // Asynchronous RGB-D camera updates.
  when sample(tOffCamera, dtCamera) then
    zCameraXSampled = zCameraX;
    zCameraYSampled = zCameraY;
    zCameraThetaSampled = zCameraTheta;
    cameraDepth1Samp = if cameraDepth1 > 0.0 then cameraDepth1 else -1.0;
    cameraBearing1Samp = if cameraDepth1 > 0.0 then bearingC1 else 0.0;
    lastCameraTime = time;
    cameraSeq = pre(cameraSeq) + 1;

    reinit(xh, pre(xh) + (pre(Pxx)/(pre(Pxx) + RCameraX))*(zCameraX - pre(xh)));
    Pxx = pre(Pxx)*RCameraX/(pre(Pxx) + RCameraX) + QLx*dtCamera;

    reinit(yh, pre(yh) + (pre(Pyy)/(pre(Pyy) + RCameraY))*(zCameraY - pre(yh)));
    Pyy = pre(Pyy)*RCameraY/(pre(Pyy) + RCameraY) + QLy*dtCamera;

    reinit(thetah, pre(thetah) + (pre(Ptheta)/(pre(Ptheta) + RCameraTheta))*angDiff(zCameraTheta, pre(thetah)));
    Ptheta = pre(Ptheta)*RCameraTheta/(pre(Ptheta) + RCameraTheta) + Qtheta*dtCamera;

    reinit(bGyroEst, pre(bGyroEst) - (pre(PbGyro)/(pre(PbGyro) + RGyro))*angDiff(zCameraTheta, pre(thetah)));
    PbGyro = pre(PbGyro)*RGyro/(pre(PbGyro) + RGyro) + QGyro*dtCamera;
  end when;

  // Verification criteria.
  assert(Pxx > 0.0 and Pyy > 0.0 and Ptheta > 0.0 and Pv > 0.0 and Pomega > 0.0 and PbGyro > 0.0 and PbEncV > 0.0 and PbOdom > 0.0, "Covariance not finite positive");
  assert(abs(tauR) <= tauMax + 1e-9 and abs(tauL) <= tauMax + 1e-9, "Actuator limit exceeded");
  assert(positionError <= posErrorBand or time <= trackingTime, "Position error band violated after convergence time");
  assert(attitudeError <= attErrorBand or time <= trackingTime, "Attitude error band violated after convergence time");
  assert(estPositionError <= posErrorBand or time <= trackingTime, "Estimator position error band violated");
  assert(estAttitudeError <= attErrorBand or time <= trackingTime, "Estimator attitude error band violated");
  assert(primaryTrackingError < trackingLimit or time <= trackingTime, "Primary tracking error above 0.16 after 13 s");
  assert(biasError < biasConvergenceLimit or time <= biasConvergenceTime, "Gyro bias did not converge");
  assert(abs(x) < 1e9 and abs(y) < 1e9 and abs(theta) < 1e9 and abs(v) < 1e9 and abs(omega) < 1e9 and abs(tauR) < 1e9 and abs(tauL) < 1e9 and abs(xh) < 1e9 and abs(yh) < 1e9 and abs(thetah) < 1e9 and abs(vh) < 1e9 and abs(omegah) < 1e9 and abs(bGyroEst) < 1e9, "NaN or infinite physical/control/estimator value");

  annotation(experiment(StartTime=0, StopTime=20, Tolerance=1e-6, Interval=0.002));
end MapRigLocalizeF;