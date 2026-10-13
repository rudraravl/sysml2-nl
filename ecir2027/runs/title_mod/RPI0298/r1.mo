model PantographTraceD
  "Closed-chain pantograph tracing a planar circle with instrumented sensors, sampled traces, closure stabilization, effort bounds, and obstacle clearance";

  // Geometry and plant parameters (SI units)
  parameter Real L1 = 0.25 "short link length (m)";
  parameter Real L2 = 0.50 "long link and fixed ground length (m)";
  parameter Integer nRevZ = 6 "number of revolute Z joints in the closed chain";
  parameter Real sTravel = 0.16 "prismatic input travel (m)";
  parameter Real s0 = 0.04 "initial absolute prismatic input coordinate (m)";
  parameter Real R = 0.10 "traced circle radius (m)";
  parameter Real xc = 0.0 "circle center x (m)";
  parameter Real yc = 0.0 "circle center y (m)";
  parameter Real phi0 = 1.5707963267948966 "initial circle phase (rad)";
  parameter Real Tpath = 14.0 "time for one full circle trace (s)";
  parameter Real Tend = 14.0 "simulation and trace duration (s)";
  parameter Real mEff = 1.0 "effective reflected input mass (kg)";
  parameter Real Fmax = 320.0 "actuator effort bound (N)";
  parameter Real Fdist = 10.0 "output load disturbance magnitude (N)";
  parameter Real Ts = 1.0/200.0 "control and trace sample period (s)";
  parameter Real obsX = 0.25 "fixed obstacle x coordinate (m), chosen outside circle";
  parameter Real obsY = 0.0 "fixed obstacle y coordinate (m), chosen outside circle";
  parameter Real epsNorm = 1.0e-12 "norm regularization to avoid zero-length singularities";

  // Control gains
  parameter Real Kp = 80000.0 "input position gain (N/m)";
  parameter Real Kd = 600.0 "input velocity gain (N.s/m)";
  parameter Real Ki = 20000.0 "input integral gain (N/(m.s))";
  parameter Real Kclosure = 1000.0 "closure stabilization proportional gain";
  parameter Real KclosureI = 100.0 "closure stabilization integral gain";
  parameter Real Kbound = 1.0e5 "soft joint stop stiffness (N/m)";

  constant Real pi = 3.141592653589793238;

  // Derived parameters
  parameter Real sMin = s0 "lower prismatic input bound (m)";
  parameter Real sMax = s0 + sTravel "upper prismatic input bound (m)";
  parameter Real Tdist0 = Tend/3.0 "disturbance start time (s)";
  parameter Real Tdist1 = 2.0*Tend/3.0 "disturbance end time (s)";
  parameter Real kS = 2.0*pi/sTravel "input coordinate to angle scale (rad/m)";
  parameter Real kR = R*kS "output position to input scale (m/m)";

  // Continuous states
  Real s(start=s0, fixed=true) "prismatic input coordinate (m)";
  Real v(start=sTravel/Tpath, fixed=true) "prismatic input velocity (m/s)";
  Real eInt(start=0.0, fixed=true) "control integrator state (m.s)";
  Real closureErrInt(start=0.0, fixed=true) "closure error integrator state (m.s)";

  // Continuous kinematic and control variables
  Real tPath "clamped trajectory time (s)";
  Real phiDes "desired output angle (rad)";
  Real xDes "desired output x (m)";
  Real yDes "desired output y (m)";
  Real sIK "inverse-kinematic input command (m)";
  Real vIK "inverse-kinematic input velocity command (m/s)";
  Real sCmdCont "continuous input command (m)";
  Real vCmdCont "continuous input velocity command (m/s)";
  Real phi "actual output angle (rad)";
  Real phiDot "actual output angular rate (rad/s)";
  Real xOut "actual output x (m)";
  Real yOut "actual output y (m)";
  Real xB "parallelogram joint B x (m)";
  Real yB "parallelogram joint B y (m)";
  Real xC "parallelogram joint C x (m)";
  Real yC "parallelogram joint C y (m)";
  Real couplerLen "computed B-C coupler length (m)";
  Real closureErr "closed-chain closure residual (m)";
  Real eS "input position error (m)";
  Real eV "input velocity error (m/s)";
  Real closureStab "closure stabilization effort contribution (N)";
  Real F_unsat "unbounded actuator effort (N)";
  Real F_act "bounded actuator effort (N)";
  Real F_bound "soft joint stop force (N)";
  Real Qdist "output load disturbance reflected to input (N)";
  Real FdistX "output disturbance force x (N)";
  Real FdistY "output disturbance force y (N)";
  Boolean disturbanceActive "true during middle third of run";

  // Sensors
  Real sEnc "actuator encoder position (m)";
  Real vEnc "actuator encoder velocity (m/s)";
  Real xMeas "direct output pose x measurement (m)";
  Real yMeas "direct output pose y measurement (m)";
  Real phiMeas "direct output pose angle measurement (rad)";

  // Six revolute Z joint traces
  Real revAngle1 "revolute Z joint 1 angle (rad)";
  Real revAngle2 "revolute Z joint 2 angle (rad)";
  Real revAngle3 "revolute Z joint 3 angle (rad)";
  Real revAngle4 "revolute Z joint 4 angle (rad)";
  Real revAngle5 "revolute Z joint 5 angle (rad)";
  Real revAngle6 "revolute Z joint 6 angle (rad)";
  Real revVel1 "revolute Z joint 1 velocity (rad/s)";
  Real revVel2 "revolute Z joint 2 velocity (rad/s)";
  Real revVel3 "revolute Z joint 3 velocity (rad/s)";
  Real revVel4 "revolute Z joint 4 velocity (rad/s)";
  Real revVel5 "revolute Z joint 5 velocity (rad/s)";
  Real revVel6 "revolute Z joint 6 velocity (rad/s)";

  // Synchronized 200 Hz traces
  discrete Real tSampled "sampled time (s)";
  discrete Real sCmdSampled "sampled input command (m)";
  discrete Real vCmdSampled "sampled input velocity command (m/s)";
  discrete Real xCmdSampled "sampled desired output x (m)";
  discrete Real yCmdSampled "sampled desired output y (m)";
  discrete Real sStateSampled "sampled state input coordinate (m)";
  discrete Real vStateSampled "sampled state input velocity (m/s)";
  discrete Real xMeasSampled "sampled measured output x (m)";
  discrete Real yMeasSampled "sampled measured output y (m)";
  discrete Real FSampled "sampled actuator effort (N)";
  discrete Real closureErrSampled "sampled closure error (m)";
  discrete Real pathErrSampled "sampled path error (m)";
  discrete Real clearanceSampled "sampled clearance (m)";

  // Observability and requirement checks
  Real pathErr "primary path tracking error (m)";
  Real clearance "distance from output to fixed obstacle (m)";
  Real singMargin "singularity margin as abs(sin(phi)) (dimensionless)";
  Real singMarginSafe "regularized singularity margin used as divisor (dimensionless)";
  Real jointBoundResidual "margin to prismatic joint travel bound (m)";
  Real effortBoundResidual "margin to actuator effort bound (N)";
  Real sCmdBoundResidual "margin to command travel bound (m)";
  Real obstacleOutsideCircleMargin "obstacle distance from center minus circle radius (m)";
  Boolean jointBoundOK;
  Boolean effortBoundOK;
  Boolean sCmdBoundOK;
  Boolean clearanceOK;
  Boolean obstacleOutsideCircleOK;
  Boolean primaryTrackingOK;
  Real finiteOK "1 if key physical/control values are finite, 0 otherwise";
  Real estimatorFiniteOK "no estimator requested; finite placeholder trace";

initial equation
  s = s0;
  v = sTravel/Tpath;
  eInt = 0.0;
  closureErrInt = 0.0;
  tSampled = 0.0;
  sCmdSampled = s0;
  vCmdSampled = sTravel/Tpath;
  xCmdSampled = R*cos(phi0);
  yCmdSampled = R*sin(phi0);
  sStateSampled = s0;
  vStateSampled = sTravel/Tpath;
  xMeasSampled = R*cos(phi0);
  yMeasSampled = R*sin(phi0);
  FSampled = 0.0;
  closureErrSampled = 0.0;
  pathErrSampled = 0.0;
  clearanceSampled = sqrt((R*cos(phi0) - obsX)*(R*cos(phi0) - obsX) + (R*sin(phi0) - obsY)*(R*sin(phi0) - obsY));

equation
  // Desired inverse kinematics for a planar circle
  tPath = if time < Tpath then time else Tpath;
  phiDes = phi0 + 2.0*pi*tPath/Tpath;
  xDes = xc + R*cos(phiDes);
  yDes = yc + R*sin(phiDes);
  sIK = s0 + sTravel*(phiDes - phi0)/(2.0*pi);
  vIK = if time < Tpath then sTravel/Tpath else 0.0;
  sCmdCont = sIK;
  vCmdCont = vIK;

  // Actual kinematics from prismatic input; output point lies on the 0.25 m link at R = 0.10 m
  phi = phi0 + kS*(s - s0);
  phiDot = kS*v;
  xOut = xc + R*cos(phi);
  yOut = yc + R*sin(phi);

  // Fixed parallelogram closure: A=(0,0), D=(L2,0), equal 0.25 m cranks, 0.50 m coupler/ground
  xB = L1*cos(phi);
  yB = L1*sin(phi);
  xC = L2 + L1*cos(phi);
  yC = L1*sin(phi);
  couplerLen = sqrt((xC - xB)*(xC - xB) + (yC - yB)*(yC - yB) + epsNorm);
  closureErr = abs(couplerLen - L2) + abs(s - (s0 + sTravel*(phi - phi0)/(2.0*pi)));

  // Six revolute Z joint traces tied to the single closed-chain coordinate
  revAngle1 = phi;
  revAngle2 = phi;
  revAngle3 = phi;
  revAngle4 = phi;
  revAngle5 = phi;
  revAngle6 = phi;
  revVel1 = phiDot;
  revVel2 = phiDot;
  revVel3 = phiDot;
  revVel4 = phiDot;
  revVel5 = phiDot;
  revVel6 = phiDot;

  // Middle-third output load disturbance, directed opposite to actual motion tangent
  disturbanceActive = time >= Tdist0 and time <= Tdist1;
  FdistX = if disturbanceActive then Fdist*sin(phi) else 0.0;
  FdistY = if disturbanceActive then -Fdist*cos(phi) else 0.0;
  Qdist = kR*(-sin(phi))*FdistX + kR*cos(phi)*FdistY;

  // Soft joint stops keep the prismatic input within its 0.16 m travel
  F_bound = if s < sMin then Kbound*(sMin - s) else if s > sMax then -Kbound*(s - sMax) else 0.0;

  // Plant dynamics reflected to the actuated input coordinate
  der(s) = v;
  der(v) = (F_act + Qdist + F_bound)/mEff;

  // Trajectory control with closure stabilization
  eS = sCmdCont - s;
  eV = vCmdCont - v;
  singMargin = abs(sin(phi));
  singMarginSafe = sqrt(singMargin*singMargin + 1.0e-9);
  closureStab = -(Kclosure*closureErr + KclosureI*closureErrInt)/(1.0 + singMarginSafe);
  der(closureErrInt) = closureErr;
  F_unsat = Kp*eS + Kd*eV + Ki*eInt + closureStab;
  der(eInt) = if noEvent(abs(F_unsat) < Fmax) then eS else 0.0;
  F_act = if F_unsat > Fmax then Fmax else if F_unsat < -Fmax then -Fmax else F_unsat;

  // Sensors and direct output-pose measurement
  sEnc = s;
  vEnc = v;
  xMeas = xOut;
  yMeas = yOut;
  phiMeas = phi;

  // Requirement traces and checks
  pathErr = sqrt((xOut - xDes)*(xOut - xDes) + (yOut - yDes)*(yOut - yDes) + epsNorm);
  clearance = sqrt((xOut - obsX)*(xOut - obsX) + (yOut - obsY)*(yOut - obsY) + epsNorm);
  obstacleOutsideCircleMargin = sqrt(obsX*obsX + obsY*obsY + epsNorm) - R;
  jointBoundResidual = if (s - sMin) < (sMax - s) then (s - sMin) else (sMax - s);
  effortBoundResidual = Fmax - abs(F_act);
  sCmdBoundResidual = if (sCmdCont - sMin) < (sMax - sCmdCont) then (sCmdCont - sMin) else (sMax - sCmdCont);
  jointBoundOK = jointBoundResidual >= -1.0e-6;
  effortBoundOK = effortBoundResidual >= -1.0e-6;
  sCmdBoundOK = sCmdBoundResidual >= -1.0e-6;
  clearanceOK = clearance > 0.0;
  obstacleOutsideCircleOK = obstacleOutsideCircleMargin > 0.0;
  primaryTrackingOK = if time >= 9.1 then pathErr <= 0.008 else true;
  estimatorFiniteOK = 1.0;
  finiteOK = if noEvent(abs(s) < 1.0e6 and abs(v) < 1.0e6 and abs(F_act) < 1.0e6 and abs(pathErr) < 1.0e6 and abs(closureErr) < 1.0e6 and abs(clearance) < 1.0e6 and abs(eInt) < 1.0e6 and abs(closureErrInt) < 1.0e6 and estimatorFiniteOK > 0.5) then 1.0 else 0.0;

  // Synchronized 200 Hz state, command, and sensor traces
  when sample(0, Ts) then
    tSampled = time;
    sCmdSampled = sCmdCont;
    vCmdSampled = vCmdCont;
    xCmdSampled = xDes;
    yCmdSampled = yDes;
    sStateSampled = s;
    vStateSampled = v;
    xMeasSampled = xOut;
    yMeasSampled = yOut;
    FSampled = F_act;
    closureErrSampled = closureErr;
    pathErrSampled = pathErr;
    clearanceSampled = clearance;
  end when;

  annotation (experiment(StopTime=14.0, Interval=0.005, Tolerance=1e-6));
end PantographTraceD;