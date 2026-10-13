model TriTugInspectB
  constant Real pi = 3.141592653589793;

  // Given physical data
  parameter Real chassisMass(unit="kg") = 38.0 "given logistics chassis mass";
  parameter Real payloadMass(unit="kg") = 20.0 "given payload mass";
  parameter Real m(unit="kg") = chassisMass + payloadMass "total inertial mass";
  parameter Real wheelRadius(unit="m") = 0.15 "given front drive-and-steer wheel radius";
  parameter Real torqueLimit(unit="N.m") = 27.9 "given allowed effort-command magnitude";
  parameter Real steerLimit(unit="rad") = 0.60 "given steering travel";
  parameter Real speedRef(unit="m/s") = 0.8 "required path speed";
  parameter Real sideLoad(unit="N") = 63.0 "given middle-third side-load disturbance";
  parameter Real corridorHalfWidth(unit="m") = 0.9 "half of fixed 1.8 m wall spacing";
  parameter Real lidarRangeMax(unit="m") = 15.0 "given planar lidar range";

  // Mission timing
  parameter Real tEnd(unit="s") = 10.0 "mission duration";
  parameter Real samplePeriod(unit="s") = 0.01 "100 Hz synchronized trace sampling";

  // Scenario geometry for centered S-corridor with two recessed alcoves
  parameter Real pathLength(unit="m") = 8.0 "route length for 10 s at 0.8 m/s";
  parameter Real pathAmplitude(unit="m") = 0.30 "chosen S-curve lateral amplitude";
  parameter Real kPath = 2.0*pi*pathAmplitude/pathLength "path slope scale";
  parameter Real theta_ref0(unit="rad") = atan(kPath) "initial path tangent heading";
  parameter Real sAlcove1(unit="m") = pathLength/3.0 "first alcove station";
  parameter Real sAlcove2(unit="m") = 2.0*pathLength/3.0 "second alcove station";
  parameter Real alcoveDepth(unit="m") = 0.30 "chosen recess depth";
  parameter Real alcoveSigma(unit="m") = 0.40 "chosen recess width";

  // Unspecified physical parameters kept as well-posed placeholders
  parameter Real L_eff(unit="m") = 1.0 "effective wheelbase; physical wheelbase not stated";
  parameter Real Jsteer(unit="kg.m2") = 1.0 "steering-axis inertia; not specified";
  parameter Real bSteer(unit="N.m.s/rad") = 6.0 "steering-axis damping; not specified";
  parameter Real kLat(unit="N.s/m") = 1500.0 "lateral damping; not specified";

  // Controller gains
  parameter Real KpV(unit="N.m/(m/s)") = 100.0;
  parameter Real KpDelta(unit="N.m/rad") = 300.0;
  parameter Real KdDelta(unit="N.m.s/rad") = 40.0;
  parameter Real kHead(unit="1/s") = 3.0;
  parameter Real kLatCtrl(unit="1/(s.m)") = 2.5;
  parameter Real kObs(unit="1/(s.m2)") = 5.0;
  parameter Real clearanceMargin(unit="m") = 0.30 "obstacle-avoidance activation clearance";

  // Estimator fusion gains
  parameter Real Kx(unit="1/s") = 5.0;
  parameter Real Ky(unit="1/s") = 5.0;
  parameter Real Ktheta(unit="1/s") = 5.0;
  parameter Real Kv(unit="1/s") = 5.0;
  parameter Real Ko(unit="1/s") = 10.0;
  parameter Real Kvy(unit="1/s") = 5.0;

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
  Real x(start=0.0, unit="m") "world x";
  Real y(start=0.0, unit="m") "world y";
  Real theta(start=theta_ref0, unit="rad") "heading";
  Real v(start=speedRef, unit="m/s") "body longitudinal speed";
  Real vy(start=0.0, unit="m/s") "body lateral speed";
  Real delta(start=0.0, unit="rad") "front steering angle";
  Real deltaDot(start=0.0, unit="rad/s") "steering rate";
  Real sPos(start=0.0, unit="m") "path-length progress";
  Real omega(unit="rad/s") "yaw rate";
  Real F_side(unit="N") "active side load";
  Real xdot(unit="m/s") "world x velocity";
  Real ydot(unit="m/s") "world y velocity";
  Real speed(unit="m/s") "planar speed";

  // Commands
  Real tauDriveRaw(unit="N.m");
  Real tauDrive(unit="N.m");
  Real tauSteerRaw(unit="N.m");
  Real tauSteer(unit="N.m");
  Real deltaRef(unit="rad");
  Real omegaRef(unit="rad/s");

  // True path and corridor observables
  Real sTrueRef(unit="m");
  Real xRefTrue(unit="m");
  Real yRefTrue(unit="m");
  Real dydxTrue(unit="1");
  Real thetaRefTrue(unit="rad");
  Real halfWidthEffTrue(unit="m");
  Real eLatTrue(unit="m");
  Real primaryTrackError(unit="m");
  Real minClearance(unit="m");
  Real headingError(unit="rad");
  Real routeCompletion;

  // Controller path/obstacle variables
  Real sCtrl(unit="m");
  Real xRefCtrl(unit="m");
  Real yRefCtrl(unit="m");
  Real dydxCtrl(unit="1");
  Real d2ydx2Ctrl(unit="1/m");
  Real thetaRefCtrl(unit="rad");
  Real dtheta_dsCtrl(unit="rad/m");
  Real pathOmegaHat(unit="rad/s");
  Real halfWidthEffCtrl(unit="m");
  Real eLatHat(unit="m");
  Real eHeadingHat(unit="rad");
  Real clearanceHat(unit="m");
  Real kObsActive(unit="1/(s.m)");

  // Sensors
  Real vOdom(unit="m/s");
  Real gyro(unit="rad/s");
  Real imuAccel(unit="m/s2");
  Real lidarRange(unit="m");
  Boolean lidarValid;
  Real lidarWeight;
  Real lidarX(unit="m");
  Real lidarY(unit="m");
  Real lidarTheta(unit="rad");

  // Estimator states
  Real xHat(start=0.0, unit="m");
  Real yHat(start=0.0, unit="m");
  Real thetaHat(start=theta_ref0, unit="rad");
  Real vHat(start=speedRef, unit="m/s");
  Real vyHat(start=0.0, unit="m/s");
  Real omegaHat(start=0.0, unit="rad/s");

  // Finite diagonal covariance states
  Real Px(start=1.0);
  Real Py(start=1.0);
  Real Ptheta(start=1.0);
  Real Pv(start=1.0);
  Real Pomega(start=1.0);
  Real Pvy(start=1.0);

equation
  // Floating-base planar kinematics with front drive-and-steer mapping
  xdot = v*cos(theta) - vy*sin(theta);
  ydot = v*sin(theta) + vy*cos(theta);
  der(x) = xdot;
  der(y) = ydot;
  der(theta) = omega;
  omega = v*tan(delta)/L_eff;
  speed = sqrt(max(v*v + vy*vy, 0.0));
  der(sPos) = speed;
  der(v) = tauDrive/(m*wheelRadius);
  der(vy) = (F_side - kLat*vy)/m;
  F_side = if time >= tEnd/3.0 and time <= 2.0*tEnd/3.0 then sideLoad else 0.0;

  // Effort-controlled steering axis
  der(deltaDot) = (tauSteer - bSteer*deltaDot)/Jsteer;
  der(delta) = deltaDot;

  // True corridor/path observables
  sTrueRef = max(0.0, min(x, pathLength));
  xRefTrue = sTrueRef;
  dydxTrue = kPath*cos(2.0*pi*sTrueRef/pathLength);
  thetaRefTrue = atan(dydxTrue);
  yRefTrue = pathAmplitude*sin(2.0*pi*sTrueRef/pathLength);
  halfWidthEffTrue = corridorHalfWidth
    + alcoveDepth*exp(-((sTrueRef - sAlcove1)/alcoveSigma)^2)
    + alcoveDepth*exp(-((sTrueRef - sAlcove2)/alcoveSigma)^2);
  eLatTrue = (y - yRefTrue)*cos(thetaRefTrue) - (x - xRefTrue)*sin(thetaRefTrue);
  primaryTrackError = sqrt(max((x - xRefTrue)^2 + (y - yRefTrue)^2, 0.0));
  minClearance = max(0.0, halfWidthEffTrue - abs(eLatTrue));
  headingError = atan2(sin(theta - thetaRefTrue), cos(theta - thetaRefTrue));
  routeCompletion = max(0.0, min(sPos/pathLength, 1.0));

  // Localization-aware path tracking with obstacle avoidance
  sCtrl = max(0.0, min(xHat, pathLength));
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
  clearanceHat = max(0.0, halfWidthEffCtrl - abs(eLatHat));
  kObsActive = kObs*max(0.0, clearanceMargin - clearanceHat);
  omegaRef = pathOmegaHat - kHead*eHeadingHat - (kLatCtrl + kObsActive)*eLatHat;
  deltaRef = max(min(atan(L_eff*omegaRef/max(vHat, 0.1)), steerLimit), -steerLimit);

  // Effort commands with magnitude limits
  tauDriveRaw = KpV*(speedRef - vHat);
  tauDrive = max(min(tauDriveRaw, torqueLimit), -torqueLimit);
  tauSteerRaw = KpDelta*(deltaRef - delta) - KdDelta*deltaDot;
  tauSteer = max(min(tauSteerRaw, torqueLimit), -torqueLimit);

  // Sensors: wheel odometry, IMU, and 15 m planar lidar pose
  vOdom = v + 0.01*sin(10.0*time);
  gyro = omega + 0.002*sin(13.0*time);
  imuAccel = tauDrive/(m*wheelRadius) + 0.02*sin(7.0*time);
  lidarRange = sqrt(max(x*x + y*y, 0.0));
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

  // Requirement checks
  assert(abs(tauDrive) <= torqueLimit + 1.0e-6, "drive command magnitude violated");
  assert(abs(tauSteer) <= torqueLimit + 1.0e-6, "steer command magnitude violated");
  assert(abs(delta) <= steerLimit + 1.0e-6, "steering travel violated");
  assert(minClearance > 0.18, "wall clearance below 0.18 m");
  assert(time < 6.5 or primaryTrackError <= 0.24, "primary tracking error requirement violated after 6.5 s");
  assert(time < 9.999 or routeCompletion >= 0.999, "route completion requirement violated");

  annotation(experiment(StopTime=10.0, Interval=0.01, Tolerance=1.0e-4));
end TriTugInspectB;