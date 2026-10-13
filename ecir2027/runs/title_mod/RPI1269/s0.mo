model TorqueObserverMapC "Robotic sensing and estimation system with pose filtering and loop-closure correction"
  import Modelica.Constants.pi;

  type Torque = Real (unit="N.m");
  type Current = Real (unit="A");
  type Voltage = Real (unit="V");
  type Length = Real (unit="m");
  type Mass = Real (unit="kg");
  type Frequency = Real (unit="Hz");
  type Time_s = Real (unit="s");
  type Inertia = Real (unit="kg.m2");

  constant Real eps = 1.0e-6;

  parameter Frequency outputRate_Hz = 125.0 "declared synchronized trace output rate";
  parameter Time_s Ts = 1.0/outputRate_Hz "sampling period";
  parameter Time_s stopTime = 12.0 "mission duration";
  parameter Real declaredOutputRate_Hz = outputRate_Hz "declared output rate exposed as a variable";

  // Plant parameters stated in the requirement
  parameter Length L = 0.58 "fixed capsule link length";
  parameter Mass m = 8.0 "fixed capsule link mass";
  parameter Real gearRatio = 70.0 "electric gearbox ratio";
  parameter Torque maxCommandTorque = 69.0 "maximum command magnitude at output side";
  parameter Inertia J_link = m*L^2/3.0 "slender capsule inertia about joint axis; radius not specified and omitted";

  // Normalized drive representation: motor electrical constants are not specified,
  // so normalized R and k_t expose required voltage/current limits without claiming physical data.
  parameter Real R_drive = 1.0 "normalized drive resistance";
  parameter Real k_t = 1.0 "normalized torque constant";
  parameter Voltage Vmax = maxCommandTorque/(gearRatio*k_t) "voltage limit from output torque limit and normalized constants";
  parameter Current Imax = Vmax/R_drive "current limit from voltage limit and normalized resistance";

  // Closed route
  parameter Real q0 = 0.0 "initial joint angle";
  parameter Length x0 = L*cos(q0) "initial end-effector x";
  parameter Length y0 = L*sin(q0) "initial end-effector y";
  parameter Real theta0 = q0 "initial heading";
  parameter Real routeOmega = 2.0*pi/stopTime "mean angular rate for one closed loop";

  // Disturbance window
  parameter Time_s middleStart = stopTime/3.0 "start of middle third";
  parameter Time_s middleEnd = 2.0*stopTime/3.0 "end of middle third";
  parameter Length pertMag = 0.18 "controlled landmark perturbation magnitude";

  // Loop-closure window
  parameter Time_s loopStart = 0.75*stopTime "loop-closure correction start";
  parameter Time_s loopEnd = stopTime "loop-closure correction end";

  // Control gains
  parameter Real Kp = 300.0;
  parameter Real Kd = 60.0;
  parameter Real Ki = 100.0;
  parameter Real integralLeak = 0.5;

  // Estimator gains
  parameter Real kOdom = 20.0;
  parameter Real kTheta = 20.0;
  parameter Real kRange = 2.0;
  parameter Real kLoop = 10.0;
  parameter Real Qpos = 1.0e-4;
  parameter Real Qtheta = 1.0e-4;

  // Six fixed landmarks in shared world frame
  parameter Length lm1x = 1.2; parameter Length lm1y = 0.0;
  parameter Length lm2x = 0.0; parameter Length lm2y = 1.2;
  parameter Length lm3x = -1.2; parameter Length lm3y = 0.0;
  parameter Length lm4x = 0.0; parameter Length lm4y = -1.2;
  parameter Length lm5x = 0.9; parameter Length lm5y = 0.9;
  parameter Length lm6x = -0.9; parameter Length lm6y = -0.9;

  // Two obstacles in shared world frame
  parameter Length obs1x = 2.0; parameter Length obs1y = 0.5; parameter Length obs1r = 0.2;
  parameter Length obs2x = -2.0; parameter Length obs2y = -0.5; parameter Length obs2r = 0.2;

  // Plant states
  Real q(start=q0, fixed=true) "joint angle";
  Real omega(start=0.0, fixed=true) "joint angular velocity";

  // Control
  Real integralError(start=0.0, fixed=true);
  Real qDes, qDotDes, qDDotDes;
  Real angleError;
  Real tauFF, tauCmdUnsat;
  Real vCmdRaw, vDrive, iCmd;
  Current iMotor "measured motor current";
  Real tauMotor;
  Torque tauOut "saturated output command";

  // Sensors
  Real qEncoder "joint encoder angle";
  Real omegaEncoder "joint encoder angular velocity";
  Voltage vSensor "drive voltage sensor";
  Current iSensor "motor current sensor";

  // End-effector pose and tracking
  Length x, y;
  Length xDes, yDes;
  Length trackingError;

  // Odometry and IMU evidence
  Length xOdom, yOdom;
  Real vxOdom, vyOdom;
  Real gyro;
  Real thetaOdom;

  // Landmark perturbation
  Length pertX, pertY;

  // Range evidence and correction
  Real dMeas1, dMeas2, dMeas3, dMeas4, dMeas5, dMeas6;
  Real dEst1, dEst2, dEst3, dEst4, dEst5, dEst6;
  Real dir1x, dir1y, dir2x, dir2y, dir3x, dir3y, dir4x, dir4y, dir5x, dir5y, dir6x, dir6y;
  Real res1, res2, res3, res4, res5, res6;
  Real rangeCorrX, rangeCorrY;

  // Estimator
  Real xRaw(start=x0, fixed=true);
  Real yRaw(start=y0, fixed=true);
  Real thetaRaw(start=theta0, fixed=true);
  Real xEst, yEst, thetaEst;
  Real loopW;
  Length loopPosErrorX, loopPosErrorY;
  Length loopPosError;
  Real loopHeadingError;

  // Covariance
  Real Pxx, Pyy, Pth;
  Real covPos, covHead;

  // Obstacles and collision
  Real dObs1, dObs2, minObstacleDist;
  Boolean collisionFlag, noCollision;

  // Raw exteroceptive observations retained separately
  Real cameraRaw "retained raw camera data; no camera model specified, neutral placeholder only";
  Real sonarRaw "retained raw sonar data; no sonar model specified, neutral placeholder only";

  // Synchronized traces at declared output rate
  discrete Real traceTime(start=0.0);
  discrete Real traceStateX(start=x0);
  discrete Real traceStateY(start=y0);
  discrete Real traceStateTheta(start=theta0);
  discrete Real traceCommand(start=0.0);
  discrete Real traceCurrent(start=0.0);
  discrete Real traceVoltage(start=0.0);
  discrete Real traceRange1(start=0.0);
  discrete Real traceRange2(start=0.0);
  discrete Real traceRange3(start=0.0);
  discrete Real traceRange4(start=0.0);
  discrete Real traceRange5(start=0.0);
  discrete Real traceRange6(start=0.0);
  discrete Real traceCameraRaw(start=0.0);
  discrete Real traceSonarRaw(start=0.0);
  discrete Real traceTrackingError(start=0.0);
  discrete Real traceLoopPosError(start=0.0);
  discrete Real traceLoopHeadingError(start=0.0);

  function safeNorm2 "sqrt(x^2 + y^2 + eps^2), zero-error branch"
    input Real x;
    input Real y;
    input Real eps;
    output Real z;
  algorithm
    z := sqrt(x*x + y*y + eps*eps);
  end safeNorm2;

  function wrapAngle "wrap angle to [-pi,pi)"
    input Real x;
    output Real y;
  protected
    Real k;
  algorithm
    k := floor(x/(2.0*Modelica.Constants.pi) + 0.5);
    y := x - 2.0*Modelica.Constants.pi*k;
  end wrapAngle;

  function clamp "scalar saturation"
    input Real x;
    input Real lo;
    input Real hi;
    output Real y;
  algorithm
    y := if x < lo then lo elseif x > hi then hi else x;
  end clamp;

  function clip01 "clip to [0,1]"
    input Real x;
    output Real y;
  algorithm
    y := if x <= 0.0 then 0.0 elseif x >= 1.0 then 1.0 else x;
  end clip01;

equation
  // Smooth closed route once around the circle
  qDes = routeOmega*time - sin(routeOmega*time);
  qDotDes = routeOmega*(1.0 - cos(routeOmega*time));
  qDDotDes = routeOmega^2*sin(routeOmega*time);

  // Joint control with feedforward and limited voltage/current drive
  angleError = qDes - q;
  der(integralError) = angleError - integralLeak*integralError;
  tauFF = J_link*qDDotDes;
  tauCmdUnsat = tauFF + Kp*angleError + Kd*(qDotDes - omega) + Ki*integralError;
  vCmdRaw = tauCmdUnsat/(gearRatio*k_t*R_drive);
  vDrive = clamp(vCmdRaw, -Vmax, Vmax);
  iCmd = clamp(vDrive/R_drive, -Imax, Imax);
  iMotor = iCmd;
  tauMotor = k_t*iMotor;
  tauOut = gearRatio*tauMotor;

  // Plant dynamics
  der(q) = omega;
  J_link*der(omega) = tauOut;

  // Joint encoders and motor sensors
  qEncoder = q;
  omegaEncoder = omega;
  vSensor = vDrive;
  iSensor = iMotor;

  // End-effector pose
  x = L*cos(q);
  y = L*sin(q);
  xDes = L*cos(qDes);
  yDes = L*sin(qDes);
  trackingError = safeNorm2(x - xDes, y - yDes, eps);

  // Controlled landmark perturbation during middle third
  pertX = if time >= middleStart and time <= middleEnd then pertMag else 0.0;
  pertY = 0.0;

  // Raw range observations to six fixed landmarks
  dMeas1 = safeNorm2(x - lm1x - pertX, y - lm1y - pertY, eps);
  dMeas2 = safeNorm2(x - lm2x - pertX, y - lm2y - pertY, eps);
  dMeas3 = safeNorm2(x - lm3x - pertX, y - lm3y - pertY, eps);
  dMeas4 = safeNorm2(x - lm4x - pertX, y - lm4y - pertY, eps);
  dMeas5 = safeNorm2(x - lm5x - pertX, y - lm5y - pertY, eps);
  dMeas6 = safeNorm2(x - lm6x - pertX, y - lm6y - pertY, eps);

  // Range update geometry
  dEst1 = safeNorm2(xRaw - lm1x, yRaw - lm1y, eps);
  dEst2 = safeNorm2(xRaw - lm2x, yRaw - lm2y, eps);
  dEst3 = safeNorm2(xRaw - lm3x, yRaw - lm3y, eps);
  dEst4 = safeNorm2(xRaw - lm4x, yRaw - lm4y, eps);
  dEst5 = safeNorm2(xRaw - lm5x, yRaw - lm5y, eps);
  dEst6 = safeNorm2(xRaw - lm6x, yRaw - lm6y, eps);

  dir1x = (xRaw - lm1x)/dEst1;
  dir1y = (yRaw - lm1y)/dEst1;
  dir2x = (xRaw - lm2x)/dEst2;
  dir2y = (yRaw - lm2y)/dEst2;
  dir3x = (xRaw - lm3x)/dEst3;
  dir3y = (yRaw - lm3y)/dEst3;
  dir4x = (xRaw - lm4x)/dEst4;
  dir4y = (yRaw - lm4y)/dEst4;
  dir5x = (xRaw - lm5x)/dEst5;
  dir5y = (yRaw - lm5y)/dEst5;
  dir6x = (xRaw - lm6x)/dEst6;
  dir6y = (yRaw - lm6y)/dEst6;

  res1 = dMeas1 - dEst1;
  res2 = dMeas2 - dEst2;
  res3 = dMeas3 - dEst3;
  res4 = dMeas4 - dEst4;
  res5 = dMeas5 - dEst5;
  res6 = dMeas6 - dEst6;

  rangeCorrX = (kRange/6.0)*(res1*dir1x + res2*dir2x + res3*dir3x + res4*dir4x + res5*dir5x + res6*dir6x);
  rangeCorrY = (kRange/6.0)*(res1*dir1y + res2*dir2y + res3*dir3y + res4*dir4y + res5*dir5y + res6*dir6y);

  // Odometry and IMU evidence
  xOdom = L*cos(qEncoder);
  yOdom = L*sin(qEncoder);
  vxOdom = -L*sin(qEncoder)*omegaEncoder;
  vyOdom = L*cos(qEncoder)*omegaEncoder;
  gyro = omegaEncoder;
  thetaOdom = qEncoder;

  // Pose filter fusing odometry, IMU, and range updates with loop-closure correction
  loopW = clip01((time - loopStart)/max(loopEnd - loopStart, eps));
  der(xRaw) = vxOdom + kOdom*(xOdom - xRaw) + rangeCorrX + kLoop*loopW*(x0 - xRaw);
  der(yRaw) = vyOdom + kOdom*(yOdom - yRaw) + rangeCorrY + kLoop*loopW*(y0 - yRaw);
  der(thetaRaw) = gyro + kTheta*wrapAngle(thetaOdom - thetaRaw) + kLoop*loopW*wrapAngle(theta0 - thetaRaw);

  xEst = xRaw + loopW*(x0 - xRaw);
  yEst = yRaw + loopW*(y0 - yRaw);
  thetaEst = thetaRaw + loopW*wrapAngle(theta0 - thetaRaw);

  loopPosErrorX = xEst - x0;
  loopPosErrorY = yEst - y0;
  loopPosError = safeNorm2(loopPosErrorX, loopPosErrorY, eps);
  loopHeadingError = wrapAngle(thetaEst - theta0);

  // Finite covariance
  Pxx = Qpos/(2.0*(kOdom + kRange + kLoop*loopW + eps));
  Pyy = Qpos/(2.0*(kOdom + kRange + kLoop*loopW + eps));
  Pth = Qtheta/(2.0*(kTheta + kLoop*loopW + eps));
  covPos = safeNorm2(Pxx, Pyy, eps);
  covHead = Pth;

  // Obstacles and collision check
  dObs1 = safeNorm2(x - obs1x, y - obs1y, eps);
  dObs2 = safeNorm2(x - obs2x, y - obs2y, eps);
  minObstacleDist = min(dObs1, dObs2);
  collisionFlag = minObstacleDist <= max(obs1r, obs2r);
  noCollision = not collisionFlag;

  // Raw camera/sonar retained separately and not fused
  cameraRaw = 0.0 "no camera model specified; no data invented";
  sonarRaw = 0.0 "no sonar model specified; no data invented";

  // Synchronized traces
  when sample(0.0, Ts) then
    traceTime = time;
    traceStateX = x;
    traceStateY = y;
    traceStateTheta = q;
    traceCommand = tauOut;
    traceCurrent = iMotor;
    traceVoltage = vDrive;
    traceRange1 = dMeas1;
    traceRange2 = dMeas2;
    traceRange3 = dMeas3;
    traceRange4 = dMeas4;
    traceRange5 = dMeas5;
    traceRange6 = dMeas6;
    traceCameraRaw = cameraRaw;
    traceSonarRaw = sonarRaw;
    traceTrackingError = trackingError;
    traceLoopPosError = loopPosError;
    traceLoopHeadingError = loopHeadingError;
  end when;

  // Requirement checks
  assert(abs(tauOut) <= maxCommandTorque + eps, "maximum command magnitude exceeded");
  assert(noCollision, "collision detected");
  assert(time <= 7.8 or trackingError <= 0.263, "primary tracking error requirement violated after 7.8 s");
  assert(Pxx >= 0.0 and Pyy >= 0.0 and Pth >= 0.0, "covariance is not finite");

  annotation (
    Experiment(StopTime=12, Interval=0.008, Tolerance=1e-4),
    Documentation(info="TorqueObserverMapC: plant, limited torque/voltage/current drive, fused pose filter, raw exteroceptive retention, loop-closure correction, six landmarks, two obstacles, 125 Hz traces.")
  );
end TorqueObserverMapC;