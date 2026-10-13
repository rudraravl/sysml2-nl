model TriTugInspectB
  import SI = Modelica.SIunits;
  import Modelica.Constants.pi;
  import Modelica.Math.atan2;

  // Given physical data
  parameter SI.Mass chassisMass = 38.0 "given logistics chassis mass";
  parameter SI.Mass payloadMass = 20.0 "given payload mass";
  parameter SI.Mass m = chassisMass + payloadMass "total inertial mass";
  parameter SI.Length wheelRadius = 0.15 "given front drive-and-steer wheel radius";
  parameter SI.Torque torqueLimit = 27.9 "given allowed effort-command magnitude";
  parameter SI.Angle steerLimit = 0.60 "given steering travel";
  parameter SI.Velocity speedRef = 0.8 "required path speed";
  parameter SI.Force sideLoad = 63.0 "given middle-third side-load disturbance";
  parameter SI.Length corridorHalfWidth = 0.9 "half of fixed 1.8 m wall spacing";
  parameter SI.Length lidarRangeMax = 15.0 "given planar lidar range";

  // Mission timing and trace storage
  parameter SI.Time tEnd = 10.0 "mission duration";
  parameter SI.Time samplePeriod = 0.01 "100 Hz synchronized trace sampling";
  parameter Integer Nlog = 1002 "trace capacity for 0 to 10 s at 100 Hz";

  // Scenario geometry chosen to form a centered S-corridor with two recessed alcoves
  parameter SI.Length pathLength = 8.0 "route length for 10 s at 0.8 m/s";
  parameter SI.Length pathAmplitude = 0.30 "chosen S-curve lateral amplitude";
  parameter Real kPath = 2.0*pi*pathAmplitude/pathLength "path slope scale";
  parameter SI.Angle theta_ref0 = atan(kPath) "initial path tangent heading";
  parameter SI.Length sAlcove1 = pathLength/3.0 "first alcove station";
  parameter SI.Length sAlcove2 = 2.0*pathLength/3.0 "second alcove station";
  parameter SI.Length alcoveDepth = 0.30 "chosen recess depth";
  parameter SI.Length alcoveSigma = 0.40 "chosen recess width";

  // Unspecified physical parameters kept as well-posed placeholders
  parameter SI.Length L_eff = 1.0 "effective wheelbase; physical wheelbase not stated";
  parameter Real Jsteer(unit = "kg.m2") = 1.0 "steering-axis inertia; not specified";
  parameter Real bSteer(unit = "N.m.s/rad") = 6.0 "steering-axis damping; not specified";
  parameter Real kLat(unit = "N.s/m") = 1500.0 "lateral damping; not specified";

  // Controller gains
  parameter Real KpV(unit = "N.m/(m/s)") = 100.0;
  parameter Real KpDelta(unit = "N.m/rad") = 300.0;
  parameter Real KdDelta(unit = "N.m.s/rad") = 40.0;
  parameter Real kHead(unit = "1/s") = 3.0;
  parameter Real kLatCtrl(unit = "1/(s.m)") = 2.5;
  parameter Real kObs(unit = "1/(s.m2)") = 5.0;
  parameter SI.Length clearanceMargin = 0.30 "obstacle-avoidance activation clearance";

  // Estimator fusion gains
  parameter Real Kx(unit = "1/s") = 5.0;
  parameter Real Ky(unit = "1/s") = 5.0;
  parameter Real Ktheta(unit = "1/s") = 5.0;
  parameter Real Kv(unit = "1/s") = 5.0;
  parameter Real Ko(unit = "1/s") = 10.0;
  parameter Real Kvy(unit = "1/s") = 5.0;

  // Finite diagonal covariance model parameters
  parameter Real Qx = 1.0e-5;
  parameter Real Qy = 1.0e-5;
  parameter Real Qtheta = 1.0e-5;
  parameter Real Qv = 1.0e-5;
  parameter Real Qomega = 1.0e-5;
  parameter Real Qvy = 1.0e-5;
  parameter Real lambdaPx = 0.1;
  parameter Real lambdaPy = 0.1;
  parameter Real lambdaPtheta = 0.1;
  parameter Real lambdaPv = 0.1;
  parameter Real lambdaPomega = 0.1;
  parameter Real lambdaPvy = 0.1;

  // Physical states
  SI.Length x(start = 0.0) "world x";
  SI.Length y(start = 0.0) "world y";
  SI.Angle theta(start = theta_ref0) "heading";
  SI.Velocity v(start = speedRef) "body longitudinal speed";
  SI.Velocity vy(start = 0.0) "body lateral speed";
  SI.Angle delta(start = 0.0) "front steering angle";
  Real deltaDot(start = 0.0, unit = "rad/s") "steering rate";
  SI.Length sPos(start = 0.0) "path-length progress";
  SI.AngularVelocity omega "yaw rate";
  SI.Force F_side "active side load";
  SI.Velocity xdot "world x velocity";
  SI.Velocity ydot "world y velocity";
  SI.Velocity speed "planar speed";
  SI.Acceleration a_long "longitudinal acceleration";

  // Commands
  SI.Torque tauDriveRaw;
  SI.Torque tauDrive;
  SI.Torque tauSteerRaw;
  SI.Torque tauSteer;
  SI.Angle deltaRef;
  SI.AngularVelocity omegaRef;

  // True path and corridor observables
  SI.Length sTrueRef;
  SI.Length xRefTrue;
  SI.Length yRefTrue;
  Real dydxTrue(unit = "1");
  SI.Angle thetaRefTrue;
  SI.Length halfWidthEffTrue;
  SI.Length eLatTrue;
  Real trackError2(unit = "m2");
  SI.Length primaryTrackError;
  SI.Length clearanceVal;
  SI.Length minClearance;
  SI.Angle headingError;
  Real routeCompletion(unit = "1");

  // Controller path/obstacle variables
  SI.Length sCtrl;
  SI.Length xRefCtrl;
  SI.Length yRefCtrl;
  Real dydxCtrl(unit = "1");
  Real d2ydx2Ctrl(unit = "1/m");
  SI.Angle thetaRefCtrl;
  Real dtheta_dsCtrl(unit = "rad/m");
  SI.AngularVelocity pathOmegaHat;
  SI.Length halfWidthEffCtrl;
  SI.Length eLatHat;
  SI.Angle eHeadingHat;
  SI.Length clearanceHatVal;
  SI.Length clearanceHat;
  Real kObsActiveVal(unit = "m");
  Real kObsActive(unit = "1/(s.m)");
  Real vHat_safe(unit = "m/s");
  Real atan_val(unit = "rad");

  // Sensors
  SI.Velocity vOdom;
  SI.AngularVelocity gyro;
  SI.Acceleration imuAccel;
  SI.Length lidarRange;
  Boolean lidarValid;
  Real lidarWeight(unit = "1");
  SI.Length lidarX;
  SI.Length lidarY;
  SI.Angle lidarTheta;
  Real xy2(unit = "m2");
  Real v2(unit = "(m/s)2");

  // Estimator states
  SI.Length xHat(start = 0.0);
  SI.Length yHat(start = 0.0);
  SI.Angle thetaHat(start = theta_ref0);
  SI.Velocity vHat(start = speedRef);
  SI.Velocity vyHat(start = 0.0);
  SI.AngularVelocity omegaHat(start = 0.0);

  // Finite diagonal covariance states
  Real Px(start = 1.0, unit = "1");
  Real Py(start = 1.0, unit = "1");
  Real Ptheta(start = 1.0, unit = "1");
  Real Pv(start = 1.0, unit = "1");
  Real Pomega(start = 1.0, unit = "1");
  Real Pvy(start = 1.0, unit = "1");

  // Synchronized traces
  Real stateLog[7, Nlog](each start = 0.0);
  Real commandLog[3, Nlog](each start = 0.0);
  Real sensorLog[6, Nlog](each start = 0.0);
  Real estimatorLog[4, Nlog](each start = 0.0);
  Integer logIndex(start = 1);

equation
  // Floating-base planar kinematics with front drive-and-steer mapping
  xdot = v*cos(theta) - vy*sin(theta);
  ydot = v*sin(theta) + vy*cos(theta);
  der(x) = xdot;
  der(y) = ydot;
  der(theta) = omega;
  omega = v*tan(delta)/L_eff;
  v2 = v*v + vy*vy;
  speed = if v2 < 0.0 then 0.0 else sqrt(v2);
  der(sPos) = speed;
  a_long = tauDrive/(m*wheelRadius);
  der(v) = a_long;
  der(vy) = (F_side - kLat*vy)/m;
  F_side = if time >= tEnd/3.0 and time <= 2.0*tEnd/3.0 then sideLoad else 0.0;

  // Effort-controlled steering axis
  der(deltaDot) = (tauSteer - bSteer*deltaDot)/Jsteer;
  der(delta) = deltaDot;

  // True corridor/path observables
  sTrueRef = if x < 0.0 then 0.0 elseif x > pathLength then pathLength else x;
  xRefTrue = sTrueRef;
  dydxTrue = kPath*cos(2.0*pi*sTrueRef/pathLength);
  thetaRefTrue = atan(dydxTrue);
  yRefTrue = pathAmplitude*sin(2.0*pi*sTrueRef/pathLength);
  halfWidthEffTrue = corridorHalfWidth
    + alcoveDepth*exp(-((sTrueRef - sAlcove1)/alcoveSigma)^2)
    + alcoveDepth*exp(-((sTrueRef - sAlcove2)/alcoveSigma)^2);
  eLatTrue = (y - yRefTrue)*cos(thetaRefTrue) - (x - xRefTrue)*sin(thetaRefTrue);
  trackError2 = (x - xRefTrue)^2 + (y - yRefTrue)^2;
  primaryTrackError = if trackError2 < 0.0 then 0.0 else sqrt(trackError2);
  clearanceVal = halfWidthEffTrue - abs(eLatTrue);
  minClearance = if clearanceVal < 0.0 then 0.0 else clearanceVal;
  headingError = atan2(sin(theta - thetaRefTrue), cos(theta - thetaRefTrue));
  routeCompletion = if sPos/pathLength < 0.0 then 0.0 elseif sPos/pathLength > 1.0 then 1.0 else sPos/pathLength;

  // Localization-aware path tracking with obstacle avoidance
  sCtrl = if xHat < 0.0 then 0.0 elseif xHat > pathLength then pathLength else xHat;
  xRefCtrl = sCtrl;
  dydxCtrl = kPath*cos(2.0*pi*sCtrl/pathLength);
  d2ydx2Ctrl = -kPath*(2.0*pi/pathLength)*sin(2.0*pi*sCtrl/pathLength);
  thetaRefCtrl = atan(dydxCtrl);
  yRefCtrl = pathAmplitude*sin(2.0*pi*sCtrl/pathLength);
  dtheta_dsCtrl = d2ydx2Ctrl/(1.0 + dydxCtrl*dydxCtrl);
  pathOmegaHat = vHat*dtheta_dsCtrl;
  halfWidthEffCtrl = corridorHalfWidth
    + alcoveDepth*exp(-((sCtrl - sAlcove1)/alcoveSigma)^2)
    + alcoveDepth*exp(-((sCtrl - sAlcove2)/alcoveSigma)^2);
  eLatHat = (yHat - yRefCtrl)*cos(thetaRefCtrl) - (xHat - xRefCtrl)*sin(thetaRefCtrl);
  eHeadingHat = atan2(sin(thetaHat - thetaRefCtrl), cos(thetaHat - thetaRefCtrl));
  clearanceHatVal = halfWidthEffCtrl - abs(eLatHat);
  clearanceHat = if clearanceHatVal < 0.0 then 0.0 else clearanceHatVal;
  kObsActiveVal = clearanceMargin - clearanceHat;
  kObsActive = kObs * (if kObsActiveVal < 0.0 then 0.0 else kObsActiveVal);
  omegaRef = pathOmegaHat - kHead*eHeadingHat - (kLatCtrl + kObsActive)*eLatHat;
  vHat_safe = if vHat < 0.1 then 0.1 else vHat;
  atan_val = atan(L_eff*omegaRef/vHat_safe);
  deltaRef = if atan_val > steerLimit then steerLimit elseif atan_val < -steerLimit then -steerLimit else atan_val;

  // Effort commands with magnitude limits
  tauDriveRaw = KpV*(speedRef - vHat);
  tauDrive = if tauDriveRaw > torqueLimit then torqueLimit elseif tauDriveRaw < -torqueLimit then -torqueLimit else tauDriveRaw;
  tauSteerRaw = KpDelta*(deltaRef - delta) - KdDelta*deltaDot;
  tauSteer = if tauSteerRaw > torqueLimit then torqueLimit elseif tauSteerRaw < -torqueLimit then -torqueLimit else tauSteerRaw;

  // Sensors: wheel odometry, IMU, and 15 m planar lidar pose
  vOdom = v + 0.01*sin(10.0*time);
  gyro = omega + 0.002*sin(13.0*time);
  imuAccel = a_long + 0.02*sin(7.0*time);
  xy2 = x*x + y*y;
  lidarRange = if xy2 < 0.0 then 0.0 else sqrt(xy2);
  lidarValid = lidarRange <= lidarRangeMax;
  lidarWeight = if lidarValid then 1.0 else 0.0;
  lidarX = if lidarValid then x + 0.02*sin(5.0*time) else xHat;
  lidarY = if lidarValid then y + 0.02*sin(6.0*time) else yHat;
  lidarTheta = if lidarValid then theta + 0.005*sin(3.0*time) else thetaHat;

  // Pose fusion filter
  der(xHat) = vHat*cos(thetaHat) - vyHat*sin(thetaHat) + Kx*lidarWeight*(lidarX - xHat);
  der(yHat) = vHat*sin(thetaHat) + vyHat*cos(thetaHat) + Ky*lidarWeight*(lidarY - yHat);
  der(thetaHat) = omegaHat + Ktheta*lidarWeight*atan2(sin(lidarTheta - thetaHat), cos(lidarTheta - thetaHat));
  der(vHat) = imuAccel + Kv*(vOdom - vHat);
  der(omegaHat) = Ko*(gyro - omegaHat);
  der(vyHat) = (F_side - kLat*vyHat)/m + Kvy*lidarWeight*((lidarY - yHat)*cos(thetaHat) - (lidarX - xHat)*sin(thetaHat));

  // Finite diagonal covariance propagation
  der(Px) = Qx - lambdaPx*Px;
  der(Py) = Qy - lambdaPy*Py;
  der(Ptheta) = Qtheta - lambdaPtheta*Ptheta;
  der(Pv) = Qv - lambdaPv*Pv;
  der(Pomega) = Qomega - lambdaPomega*Pomega;
  der(Pvy) = Qvy - lambdaPvy*Pvy;

  // Synchronized 100 Hz state, command, sensor, and estimator traces
  when sample(0, samplePeriod) then
    stateLog[1, pre(logIndex)] = x;
    stateLog[2, pre(logIndex)] = y;
    stateLog[3, pre(logIndex)] = theta;
    stateLog[4, pre(logIndex)] = v;
    stateLog[5, pre(logIndex)] = vy;
    stateLog[6, pre(logIndex)] = delta;
    stateLog[7, pre(logIndex)] = sPos;
    commandLog[1, pre(logIndex)] = tauDrive;
    commandLog[2, pre(logIndex)] = tauSteer;
    commandLog[3, pre(logIndex)] = deltaRef;
    sensorLog[1, pre(logIndex)] = vOdom;
    sensorLog[2, pre(logIndex)] = gyro;
    sensorLog[3, pre(logIndex)] = imuAccel;
    sensorLog[4, pre(logIndex)] = lidarX;
    sensorLog[5, pre(logIndex)] = lidarY;
    sensorLog[6, pre(logIndex)] = lidarTheta;
    estimatorLog[1, pre(logIndex)] = xHat;
    estimatorLog[2, pre(logIndex)] = yHat;
    estimatorLog[3, pre(logIndex)] = thetaHat;
    estimatorLog[4, pre(logIndex)] = Ptheta;
    logIndex = if pre(logIndex) < Nlog then pre(logIndex) + 1 else Nlog;
  end when;

  // Requirement checks
  assert(noEvent(abs(tauDrive) <= torqueLimit + 1.0e-6), "drive command magnitude violated");
  assert(noEvent(abs(tauSteer) <= torqueLimit + 1.0e-6), "steer command magnitude violated");
  assert(noEvent(abs(delta) <= steerLimit + 1.0e-6), "steering travel violated");
  assert(noEvent(minClearance > 0.18), "wall clearance below 0.18 m");
  assert(noEvent(time < 6.5 or primaryTrackError <= 0.24), "primary tracking error requirement violated after 6.5 s");
  assert(noEvent(time < 9.999 or routeCompletion >= 0.999), "route completion requirement violated");

  annotation(experiment(StopTime = 10.0, Interval = 0.01, Tolerance = 1.0e-4));
end TriTugInspectB;