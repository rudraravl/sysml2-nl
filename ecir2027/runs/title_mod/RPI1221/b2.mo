model WheelIMUMapC
  import SI = Modelica.SIunits;

  // Sampling and duration
  parameter Real fSample = 125 "Declared estimator/output rate [Hz]";
  parameter Real Tend = 12 "Mission duration [s]";
  parameter Real dtEst = 1/fSample "Estimator period [s]";

  // Chassis
  parameter SI.Mass m = 16 "Chassis mass";
  parameter SI.Length rWheel = 0.08 "Wheel radius";
  parameter SI.Length Lwheel = 0.40 "Wheelbase";
  parameter Real Izz = 0.80 "Yaw inertia [kg.m2]";
  parameter Real bDrag = 1.20 "Wheel viscous drag [N.s/m]";
  parameter Real tauMax = 9.20 "Max command magnitude per wheel [N.m]";

  // Reference closed route
  parameter SI.Length Rref = 2.60 "Reference circle radius [m]";
  parameter Real omegaRef = 2*Modelica.Constants.pi/Tend "Reference yaw rate [rad/s]";
  parameter SI.Velocity vRef = Rref*omegaRef "Reference forward speed [m/s]";

  // Landmarks (>=6) and obstacles (>=2)
  parameter SI.Length Lx[6] = {4.0, 0.0, -4.0, 0.0, 3.0, -3.0};
  parameter SI.Length Ly[6] = {0.0, 4.0, 0.0, -4.0, 3.0, -3.0};
  parameter SI.Length Ox[2] = {0.0, -2.5};
  parameter SI.Length Oy[2] = {0.0, 2.5};
  parameter SI.Length Orad[2] = {0.50, 0.45} "Obstacle radius [m]";

  // Landmark perturbation (middle third)
  parameter SI.Length dPert = 0.18 "Landmark perturbation disturbance [m]";
  parameter Real tPertStart = Tend/3;
  parameter Real tPertEnd = 2*Tend/3;

  // Sensor noise and bias (declared)
  parameter Real encNoiseStd = 0.010 "Encoder velocity noise std [m/s]";
  parameter Real gyroBias = 0.0020 "Gyro bias [rad/s]";
  parameter Real gyroNoiseStd = 0.0050 "Gyro noise std [rad/s]";
  parameter Real accelBiasX = 0.030 "Accel x bias [m/s2]";
  parameter Real accelBiasY = 0.030 "Accel y bias [m/s2]";
  parameter Real accelNoiseStd = 0.050 "Accel noise std [m/s2]";
  parameter Real rangeNoiseStd = 0.050 "Range noise std [m]";

  // Controller gains
  parameter Real kpV = 12.0;
  parameter Real kpTheta = 6.0;
  parameter Real kdTheta = 1.5;

  // EKF noise
  parameter Real qPos = 1.0e-4 "Position process variance [m2]";
  parameter Real qTheta = 1.0e-5 "Heading process variance [rad2]";
  parameter Real rRange = 0.050*0.050 "Range measurement variance [m2]";

  // Loop-closure reference (start pose)
  parameter SI.Length xStart = Rref;
  parameter SI.Length yStart = 0.0;
  parameter SI.Angle thetaStart = Modelica.Constants.pi/2;

  // Plant states
  SI.Length x(start=Rref) "True x";
  SI.Length y(start=0.0) "True y";
  SI.Angle theta(start=Modelica.Constants.pi/2) "True heading";
  SI.Velocity vL(start=vRef) "Left wheel linear velocity";
  SI.Velocity vR(start=vRef) "Right wheel linear velocity";
  SI.Angle phiL(start=0.0) "Left wheel angle (encoder)";
  SI.Angle phiR(start=0.0) "Right wheel angle (encoder)";

  // Derived quantities
  SI.Velocity v "Forward speed";
  SI.AngularVelocity omega "Yaw rate";
  Real aForward "Body forward accel [m/s2]";
  Real aLateral "Body lateral accel [m/s2]";

  // Commands
  Real uL_raw(start=0.0) "Raw left wheel command [N.m]";
  Real uR_raw(start=0.0) "Raw right wheel command [N.m]";
  Real tauL "Saturated left wheel torque [N.m]";
  Real tauR "Saturated right wheel torque [N.m]";

  // Reference
  SI.Angle thetaRef;
  SI.Length xRef;
  SI.Length yRef;
  Real thetaErrWrapped;
  SI.Velocity vErr;
  Real turnCmd;

  // Tracking
  SI.Length trackErr;
  Boolean trackErrOK;

  // Encoders
  SI.Velocity encVelL;
  SI.Velocity encVelR;

  // IMU six-axis
  Real axBody;
  Real ayBody;
  Real wzMeas;
  Real azBody(start=0);
  Real wxMeas(start=0);
  Real wyMeas(start=0);

  // Range
  SI.Length rangeMeas[6];
  Real perturbActive;

  // Camera/sonar raw preserved separately
  Real cameraRaw[3] "Raw camera features (preserved separately)";
  Real sonarRaw[2] "Raw sonar ranges to obstacles (preserved separately)";
  SI.Length sonarMeas[2];

  // Obstacle / collision
  SI.Length dObs1;
  SI.Length dObs2;
  SI.Length minObsDist;
  Boolean collisionFree;

  // Estimator state (assigned in algorithm when-block)
  Real xEst(start=Rref) "Estimated x";
  Real yEst(start=0.0) "Estimated y";
  Real thetaEst(start=Modelica.Constants.pi/2) "Estimated heading";
  Real Pxx(start=0.01);
  Real Pxy(start=0.0);
  Real Pxth(start=0.0);
  Real Pyy(start=0.01);
  Real Pyth(start=0.0);
  Real Pthth(start=0.01);

  // Loop closure
  Real loopPosErr(start=0.0) "Loop-closure position error [m]";
  Real loopHeadErr(start=0.0) "Loop-closure heading error [rad]";
  Real loopClosureDone(start=0.0) "Loop closure completion flag";
  Real xEstCorr(start=Rref) "Corrected estimated x";
  Real yEstCorr(start=0.0) "Corrected estimated y";
  Real thetaEstCorr(start=Modelica.Constants.pi/2) "Corrected estimated heading";

  Boolean covFinite "Covariance finite guard";

  // EKF temporaries
protected
  Real vOdo(start=0);
  Real wOdo(start=0);
  Real wIMU(start=0);
  Real wFuse(start=0);
  Real cth(start=1);
  Real sth(start=0);
  Real F13(start=0);
  Real F23(start=0);
  Real xp(start=Rref);
  Real yp(start=0);
  Real thp(start=Modelica.Constants.pi/2);
  Real Pxxp(start=0.01);
  Real Pxyp(start=0);
  Real Pxthp(start=0);
  Real Pyyp(start=0.01);
  Real Pythp(start=0);
  Real Pththp(start=0.01);
  Real dmin(start=1);
  Real ddx(start=0);
  Real ddy(start=0);
  Real Hx(start=0);
  Real Hy(start=0);
  Real inn(start=0);
  Real Sinv(start=1);
  Real Kx(start=0);
  Real Ky(start=0);
  Real Kth(start=0);
  constant Real eps = 1.0e-6;

equation
  // Reference closed route
  thetaRef = omegaRef*time;
  xRef = Rref*cos(thetaRef);
  yRef = Rref*sin(thetaRef);

  // Wheel dynamics (per-wheel approximation)
  (m/2)*der(vL) = tauL/rWheel - bDrag*vL;
  (m/2)*der(vR) = tauR/rWheel - bDrag*vR;

  // Kinematics
  v = (vL + vR)/2;
  omega = (vR - vL)/Lwheel;
  der(x) = v*cos(theta);
  der(y) = v*sin(theta);
  der(theta) = omega;
  der(phiL) = vL/rWheel;
  der(phiR) = vR/rWheel;

  // Body-frame accelerations (center-mounted IMU)
  aForward = (der(vL) + der(vR))/2;
  aLateral = -omega*v;

  // IMU measurements (declared bias + deterministic noise surrogate)
  axBody = aForward + accelBiasX + accelNoiseStd*sin(13.0*time + 1.1);
  ayBody = aLateral + accelBiasY + accelNoiseStd*sin(17.0*time + 2.3);
  wzMeas = omega + gyroBias + gyroNoiseStd*sin(11.0*time + 0.7);
  azBody = accelNoiseStd*sin(19.0*time + 3.1);
  wxMeas = gyroNoiseStd*sin(23.0*time + 1.7);
  wyMeas = gyroNoiseStd*sin(29.0*time + 2.9);

  // Encoders
  encVelL = vL + encNoiseStd*sin(31.0*time + 0.3);
  encVelR = vR + encNoiseStd*sin(37.0*time + 1.9);

  // Landmark perturbation (middle third)
  perturbActive = if (time >= tPertStart and time < tPertEnd) then 1.0 else 0.0;

  // Range measurements with perturbation
  for i in 1:6 loop
    rangeMeas[i] = sqrt((x - (Lx[i] + perturbActive*dPert))^2 + (y - Ly[i])^2)
                   + rangeNoiseStd*sin((7.0 + i)*time + i);
  end for;

  // Sonar raw (to obstacles, preserved separately)
  for i in 1:2 loop
    sonarMeas[i] = sqrt((x - Ox[i])^2 + (y - Oy[i])^2) - Orad[i]
                   + rangeNoiseStd*sin((11.0 + i)*time + i);
    sonarRaw[i] = sonarMeas[i];
  end for;

  // Camera raw (preserved separately, model not specified)
  cameraRaw[1] = x + 0.10*sin(41.0*time + 0.5);
  cameraRaw[2] = y + 0.10*sin(43.0*time + 1.5);
  cameraRaw[3] = theta + 0.02*sin(47.0*time + 2.5);

  // Controller
  thetaErrWrapped = atan2(sin(thetaRef - theta), cos(thetaRef - theta));
  vErr = vRef - v;
  turnCmd = kpTheta*thetaErrWrapped + kdTheta*(omegaRef - omega);
  uL_raw = kpV*vErr - turnCmd;
  uR_raw = kpV*vErr + turnCmd;
  tauL = max(-tauMax, min(tauMax, uL_raw));
  tauR = max(-tauMax, min(tauMax, uR_raw));

  // Tracking
  trackErr = sqrt((x - xRef)^2 + (y - yRef)^2);
  trackErrOK = if time > 7.8 then trackErr < 0.263 else true;

  // Obstacle distances
  dObs1 = sqrt((x - Ox[1])^2 + (y - Oy[1])^2);
  dObs2 = sqrt((x - Ox[2])^2 + (y - Oy[2])^2);
  minObsDist = if dObs1 < dObs2 then dObs1 else dObs2;
  collisionFree = minObsDist > max(Orad[1], Orad[2]);

  // Covariance finiteness guard
  covFinite = Pxx > 0.0 and Pyy > 0.0 and Pthth > 0.0
              and Pxx < 1.0e6 and Pyy < 1.0e6 and Pthth < 1.0e6;

algorithm
  when sample(0, dtEst) then
    // EKF prediction from odometry + IMU fusion
    vOdo := (encVelL + encVelR)/2.0;
    wOdo := (encVelR - encVelL)/Lwheel;
    wIMU := wzMeas - gyroBias;
    wFuse := 0.5*(wOdo + wIMU);
    cth := cos(pre(thetaEst));
    sth := sin(pre(thetaEst));
    F13 := -vOdo*dtEst*sth;
    F23 := vOdo*dtEst*cth;
    xp := pre(xEst) + vOdo*dtEst*cth;
    yp := pre(yEst) + vOdo*dtEst*sth;
    thp := pre(thetaEst) + wFuse*dtEst;

    // Covariance prediction
    Pxthp := pre(Pxth) + F13*pre(Pthth);
    Pythp := pre(Pyth) + F23*pre(Pthth);
    Pxxp := pre(Pxx) + F13*pre(Pxth) + F13*Pxthp + qPos;
    Pxyp := pre(Pxy) + F13*pre(Pyth) + F23*Pxthp;
    Pyyp := pre(Pyy) + F23*pre(Pyth) + F23*Pythp + qPos;
    Pththp := pre(Pthth) + qTheta;

    // Sequential range updates
    for i in 1:6 loop
      ddx := xp - Lx[i];
      ddy := yp - Ly[i];
      dmin := sqrt(ddx*ddx + ddy*ddy);
      if dmin > eps then
        Hx := ddx/dmin;
        Hy := ddy/dmin;
        inn := rangeMeas[i] - dmin;
        Sinv := Hx*(Hx*Pxxp + Hy*Pxyp) + Hy*(Hx*Pxyp + Hy*Pyyp) + rRange;
        if Sinv > eps then
          Kx := (Hx*Pxxp + Hy*Pxyp)/Sinv;
          Ky := (Hx*Pxyp + Hy*Pyyp)/Sinv;
          Kth := (Hx*Pxthp + Hy*Pythp)/Sinv;
          xp := xp + Kx*inn;
          yp := yp + Ky*inn;
          thp := thp + Kth*inn;
          Pxxp := Pxxp - Kx*(Hx*Pxxp + Hy*Pxyp);
          Pxyp := Pxyp - Kx*(Hx*Pxyp + Hy*Pyyp);
          Pxthp := Pxthp - Kx*(Hx*Pxthp + Hy*Pythp);
          Pyyp := Pyyp - Ky*(Hx*Pxyp + Hy*Pyyp);
          Pythp := Pythp - Ky*(Hx*Pxthp + Hy*Pythp);
          Pththp := Pththp - Kth*(Hx*Pxthp + Hy*Pythp);
        end if;
      end if;
    end for;

    // Commit estimator state
    xEst := xp;
    yEst := yp;
    thetaEst := thp;
    Pxx := Pxxp;
    Pxy := Pxyp;
    Pxth := Pxthp;
    Pyy := Pyyp;
    Pyth := Pythp;
    Pthth := Pththp;

    // Loop-closure correction near run end
    if time >= Tend - dtEst - 1.0e-9 and pre(loopClosureDone) < 0.5 then
      loopPosErr := sqrt((xp - xStart)^2 + (yp - yStart)^2);
      loopHeadErr := atan2(sin(thp - thetaStart), cos(thp - thetaStart));
      xEstCorr := xp - 0.5*(xp - xStart);
      yEstCorr := yp - 0.5*(yp - yStart);
      thetaEstCorr := thp - 0.5*loopHeadErr;
      loopClosureDone := 1.0;
    else
      loopPosErr := pre(loopPosErr);
      loopHeadErr := pre(loopHeadErr);
      xEstCorr := pre(xEstCorr);
      yEstCorr := pre(yEstCorr);
      thetaEstCorr := pre(thetaEstCorr);
      loopClosureDone := pre(loopClosureDone);
    end if;
  end when;

  annotation (
    Documentation(info="WheelIMUMapC: 16 kg differential-drive chassis, wheel encoders, six-axis center IMU (declared noise/bias), two wheel-torque actuators (max 9.2 N.m), 6 landmarks + 2 obstacles. EKF fuses odometry, IMU gyro and range updates at 125 Hz; camera/sonar raw preserved separately. 0.18 m landmark perturbation in middle third. Loop-closure correction at run end."),
    experiment(StopTime=12, Tolerance=1e-6, Interval=0.008));
end WheelIMUMapC;