model GroundTrioFormE
  "Verifiable three-robot differential-drive formation: leader tracking, declared offsets, bounded wheel commands, delayed peer messages, sensors, and fail-closed acceptance."

  import Modelica.Units.SI;

  // Given values
  parameter SI.Mass mRobot=18 "given robot mass";
  parameter SI.Torque tauMax=13.2 "given per-wheel command magnitude bound";
  parameter SI.Time Ts=0.004 "given 250 Hz control period";
  parameter SI.Time Tfinal=16 "given run time";
  parameter SI.Time Tdelay=0.096 "given middle-third message delay";
  parameter SI.Time Ttracking=10.4 "given primary tracking evaluation time";
  parameter SI.Length primaryTrackingLimit=0.27 "given primary tracking bound";

  // Placeholder values for facts not stated in the request
  parameter SI.Length wheelRadius=0.1 "placeholder; wheel radius not specified";
  parameter SI.Length track=0.4 "placeholder; track width not specified";
  parameter SI.Inertia Izz=1.0 "placeholder; yaw inertia not specified";
  parameter Real dragForce(unit="N.s/m")=2.0 "placeholder; translational damping not specified";
  parameter Real yawDamping(unit="N.m.s/rad")=1.0 "placeholder; yaw damping not specified";
  parameter SI.Time tauActTau=0.02 "placeholder; actuator time constant not specified";
  parameter SI.Velocity vLeader=0.2 "placeholder; leader speed not specified";
  parameter SI.Angle leaderTheta=0.0 "placeholder; leader heading not specified";
  parameter SI.AngularVelocity leaderOmega=0.0 "placeholder; leader yaw rate not specified";
  parameter SI.Length offset2X=-0.6 "declared relative offset; numeric value not specified, placeholder";
  parameter SI.Length offset2Y=0.5 "declared relative offset; numeric value not specified, placeholder";
  parameter SI.Length offset3X=-0.6 "declared relative offset; numeric value not specified, placeholder";
  parameter SI.Length offset3Y=-0.5 "declared relative offset; numeric value not specified, placeholder";
  parameter SI.Length minSeparation=0.3 "declared minimum separation; numeric value not specified, placeholder";
  parameter SI.Length formationErrorLimit=0.27 "formation error tolerance not specified; placeholder set to stated tracking bound";
  parameter SI.Length robotRadius=0.15 "placeholder; robot collision radius not specified";
  parameter SI.Length obstacleRadius=0.2 "placeholder; obstacle collision radius not specified";
  parameter SI.Length obstacle1X=1.6 "placeholder obstacle outside nominal path";
  parameter SI.Length obstacle1Y=3.0 "placeholder obstacle outside nominal path";
  parameter SI.Length obstacle2X=1.6 "placeholder obstacle outside nominal path";
  parameter SI.Length obstacle2Y=-3.0 "placeholder obstacle outside nominal path";
  parameter SI.Length obstacle3X=4.5 "placeholder obstacle outside nominal path";
  parameter SI.Length obstacle3Y=0.0 "placeholder obstacle outside nominal path";
  parameter Real KpTrack(unit="1/s2")=2.0 "placeholder controller gain; not specified";
  parameter Real KdTrack(unit="1/s")=3.0 "placeholder controller gain; not specified";
  parameter Real KpYaw(unit="1/s2")=3.0 "placeholder controller gain; not specified";
  parameter Real KdYaw(unit="1/s")=2.0 "placeholder controller gain; not specified";
  parameter Real Klat(unit="1/m")=1.0 "placeholder lateral correction gain; not specified";
  parameter Real Ksep(unit="N/m")=5.0 "placeholder separation safety gain; not specified";

  parameter SI.Length epsLen=1e-9 "zero-error guard for lengths";
  parameter SI.Torque epsTau=1e-9 "zero-error guard for torques";
  parameter SI.Time epsTime=1e-9 "zero-error guard for times";
  parameter Real big=1e30 "finite-value guard for NaN/inf checks";

  // State traces
  output SI.Position x1(start=0.0, fixed=true) "state trace robot 1 x";
  output SI.Position y1(start=0.0, fixed=true) "state trace robot 1 y";
  output SI.Angle theta1(start=0.0, fixed=true) "state trace robot 1 heading";
  output SI.Velocity v1(start=0.0, fixed=true) "state trace robot 1 speed";
  output SI.AngularVelocity omega1(start=0.0, fixed=true) "state trace robot 1 yaw rate";

  output SI.Position x2(start=-0.6, fixed=true) "state trace robot 2 x";
  output SI.Position y2(start=0.5, fixed=true) "state trace robot 2 y";
  output SI.Angle theta2(start=0.0, fixed=true) "state trace robot 2 heading";
  output SI.Velocity v2(start=0.0, fixed=true) "state trace robot 2 speed";
  output SI.AngularVelocity omega2(start=0.0, fixed=true) "state trace robot 2 yaw rate";

  output SI.Position x3(start=-0.6, fixed=true) "state trace robot 3 x";
  output SI.Position y3(start=-0.5, fixed=true) "state trace robot 3 y";
  output SI.Angle theta3(start=0.0, fixed=true) "state trace robot 3 heading";
  output SI.Velocity v3(start=0.0, fixed=true) "state trace robot 3 speed";
  output SI.AngularVelocity omega3(start=0.0, fixed=true) "state trace robot 3 yaw rate";

  // Command traces
  output SI.Torque tauActL1(start=0.0, fixed=true) "actuator trace robot 1 left wheel";
  output SI.Torque tauActR1(start=0.0, fixed=true) "actuator trace robot 1 right wheel";
  output SI.Torque tauActL2(start=0.0, fixed=true) "actuator trace robot 2 left wheel";
  output SI.Torque tauActR2(start=0.0, fixed=true) "actuator trace robot 2 right wheel";
  output SI.Torque tauActL3(start=0.0, fixed=true) "actuator trace robot 3 left wheel";
  output SI.Torque tauActR3(start=0.0, fixed=true) "actuator trace robot 3 right wheel";

  output SI.Torque tauBoundedL1(start=0.0) "bounded command trace robot 1 left wheel";
  output SI.Torque tauBoundedR1(start=0.0) "bounded command trace robot 1 right wheel";
  output SI.Torque tauBoundedL2(start=0.0) "bounded command trace robot 2 left wheel";
  output SI.Torque tauBoundedR2(start=0.0) "bounded command trace robot 2 right wheel";
  output SI.Torque tauBoundedL3(start=0.0) "bounded command trace robot 3 left wheel";
  output SI.Torque tauBoundedR3(start=0.0) "bounded command trace robot 3 right wheel";

  // Leader trajectory and acceptance traces
  output SI.Position leaderX "leader trajectory x";
  output SI.Position leaderY "leader trajectory y";
  output SI.Length primaryTrackingError "primary leader tracking error";
  output SI.Length formationError "formation offset error";
  output SI.Length minSeparationMeas "measured minimum pairwise separation";
  output SI.Time communicationAge "peer message age";
  output SI.Length lidarMin1 "lidar minimum range robot 1";
  output SI.Length lidarMin2 "lidar minimum range robot 2";
  output SI.Length lidarMin3 "lidar minimum range robot 3";
  output SI.Length range12Meas "peer-relative range robot 1 to robot 2";
  output SI.Length range13Meas "peer-relative range robot 1 to robot 3";
  output SI.Length range23Meas "peer-relative range robot 2 to robot 3";

  output Boolean actuatorLimitOK "actuator limit acceptance flag";
  output Boolean separationOK "minimum separation acceptance flag";
  output Boolean formationErrorOK "formation error acceptance flag";
  output Boolean communicationAgeOK "communication age acceptance flag";
  output Boolean noCollision "no collision acceptance flag";
  output Boolean trackingOK "primary tracking acceptance flag";
  output Boolean noNaNInf "finite-value acceptance flag";
  output Boolean accept(start=true) "fail-closed overall acceptance flag";

  Boolean middleThird "middle-third delay disturbance window";

  SI.Position delayedX1;
  SI.Position delayedY1;
  SI.Angle delayedTheta1;
  SI.Velocity delayedV1;
  SI.AngularVelocity delayedOmega1;
  SI.Position delayedX2;
  SI.Position delayedY2;
  SI.Angle delayedTheta2;
  SI.Velocity delayedV2;
  SI.AngularVelocity delayedOmega2;
  SI.Position delayedX3;
  SI.Position delayedY3;
  SI.Angle delayedTheta3;
  SI.Velocity delayedV3;
  SI.AngularVelocity delayedOmega3;

  SI.Position msgX1;
  SI.Position msgY1;
  SI.Angle msgTheta1;
  SI.Velocity msgV1;
  SI.AngularVelocity msgOmega1;
  SI.Position msgX2;
  SI.Position msgY2;
  SI.Angle msgTheta2;
  SI.Velocity msgV2;
  SI.AngularVelocity msgOmega2;
  SI.Position msgX3;
  SI.Position msgY3;
  SI.Angle msgTheta3;
  SI.Velocity msgV3;
  SI.AngularVelocity msgOmega3;

  SI.Position estX1;
  SI.Position estY1;
  SI.Angle estTheta1;
  SI.Velocity estV1;
  SI.AngularVelocity estOmega1;
  SI.Position estX2;
  SI.Position estY2;
  SI.Angle estTheta2;
  SI.Velocity estV2;
  SI.AngularVelocity estOmega2;
  SI.Position estX3;
  SI.Position estY3;
  SI.Angle estTheta3;
  SI.Velocity estV3;
  SI.AngularVelocity estOmega3;

  SI.Position odoX1;
  SI.Position odoY1;
  SI.Angle odoTheta1;
  SI.Velocity odoV1;
  SI.AngularVelocity odoOmega1;
  SI.Position odoX2;
  SI.Position odoY2;
  SI.Angle odoTheta2;
  SI.Velocity odoV2;
  SI.AngularVelocity odoOmega2;
  SI.Position odoX3;
  SI.Position odoY3;
  SI.Angle odoTheta3;
  SI.Velocity odoV3;
  SI.AngularVelocity odoOmega3;

  SI.Length range21Meas;
  SI.Length range31Meas;
  SI.Length range32Meas;
  SI.Length minRange1;
  SI.Length minRange2;
  SI.Length minRange3;
  SI.Force safeF1;
  SI.Force safeF2;
  SI.Force safeF3;

  SI.Length sep12;
  SI.Length sep13;
  SI.Length sep23;

  SI.Length lidar1O1;
  SI.Length lidar1O2;
  SI.Length lidar1O3;
  SI.Length lidar2O1;
  SI.Length lidar2O2;
  SI.Length lidar2O3;
  SI.Length lidar3O1;
  SI.Length lidar3O2;
  SI.Length lidar3O3;

  SI.Length offsetErr2;
  SI.Length offsetErr3;

  SI.Length desiredX2;
  SI.Length desiredY2;
  SI.Length desiredX3;
  SI.Length desiredY3;

  SI.Length errForward1;
  SI.Length errLateral1;
  SI.Velocity errV1;
  SI.Angle errTheta1;
  SI.Length errForward2;
  SI.Length errLateral2;
  SI.Velocity errV2;
  SI.Angle errTheta2;
  SI.AngularVelocity errOmega2;
  SI.Length errForward3;
  SI.Length errLateral3;
  SI.Velocity errV3;
  SI.Angle errTheta3;
  SI.AngularVelocity errOmega3;

  SI.Force Fdes1;
  SI.Force Fdes2;
  SI.Force Fdes3;
  SI.Torque Mdes1;
  SI.Torque Mdes2;
  SI.Torque Mdes3;
  SI.Torque tauRawL1;
  SI.Torque tauRawR1;
  SI.Torque tauRawL2;
  SI.Torque tauRawR2;
  SI.Torque tauRawL3;
  SI.Torque tauRawR3;
  SI.Torque magRaw1;
  SI.Torque magRaw2;
  SI.Torque magRaw3;
  Real scale1;
  Real scale2;
  Real scale3;

equation

  // Leader trajectory
  leaderX = vLeader*time;
  leaderY = 0.0;
  middleThird = time >= Tfinal/3 and time < 2*Tfinal/3;

  // Robot 1 plant
  der(x1) = v1*cos(theta1);
  der(y1) = v1*sin(theta1);
  der(theta1) = omega1;
  mRobot*der(v1) = (tauActL1 + tauActR1)/wheelRadius - dragForce*v1;
  Izz*der(omega1) = (tauActR1 - tauActL1)*track/(2*wheelRadius) - yawDamping*omega1;
  der(tauActL1) = (tauBoundedL1 - tauActL1)/tauActTau;
  der(tauActR1) = (tauBoundedR1 - tauActR1)/tauActTau;

  // Robot 2 plant
  der(x2) = v2*cos(theta2);
  der(y2) = v2*sin(theta2);
  der(theta2) = omega2;
  mRobot*der(v2) = (tauActL2 + tauActR2)/wheelRadius - dragForce*v2;
  Izz*der(omega2) = (tauActR2 - tauActL2)*track/(2*wheelRadius) - yawDamping*omega2;
  der(tauActL2) = (tauBoundedL2 - tauActL2)/tauActTau;
  der(tauActR2) = (tauBoundedR2 - tauActR2)/tauActTau;

  // Robot 3 plant
  der(x3) = v3*cos(theta3);
  der(y3) = v3*sin(theta3);
  der(theta3) = omega3;
  mRobot*der(v3) = (tauActL3 + tauActR3)/wheelRadius - dragForce*v3;
  Izz*der(omega3) = (tauActR3 - tauActL3)*track/(2*wheelRadius) - yawDamping*omega3;
  der(tauActL3) = (tauBoundedL3 - tauActL3)/tauActTau;
  der(tauActR3) = (tauBoundedR3 - tauActR3)/tauActTau;

  // Delayed peer pose and velocity messages
  delayedX1 = delay(x1, Tdelay, Tdelay);
  delayedY1 = delay(y1, Tdelay, Tdelay);
  delayedTheta1 = delay(theta1, Tdelay, Tdelay);
  delayedV1 = delay(v1, Tdelay, Tdelay);
  delayedOmega1 = delay(omega1, Tdelay, Tdelay);

  delayedX2 = delay(x2, Tdelay, Tdelay);
  delayedY2 = delay(y2, Tdelay, Tdelay);
  delayedTheta2 = delay(theta2, Tdelay, Tdelay);
  delayedV2 = delay(v2, Tdelay, Tdelay);
  delayedOmega2 = delay(omega2, Tdelay, Tdelay);

  delayedX3 = delay(x3, Tdelay, Tdelay);
  delayedY3 = delay(y3, Tdelay, Tdelay);
  delayedTheta3 = delay(theta3, Tdelay, Tdelay);
  delayedV3 = delay(v3, Tdelay, Tdelay);
  delayedOmega3 = delay(omega3, Tdelay, Tdelay);

  msgX1 = if middleThird then delayedX1 else x1;
  msgY1 = if middleThird then delayedY1 else y1;
  msgTheta1 = if middleThird then delayedTheta1 else theta1;
  msgV1 = if middleThird then delayedV1 else v1;
  msgOmega1 = if middleThird then delayedOmega1 else omega1;

  msgX2 = if middleThird then delayedX2 else x2;
  msgY2 = if middleThird then delayedY2 else y2;
  msgTheta2 = if middleThird then delayedTheta2 else theta2;
  msgV2 = if middleThird then delayedV2 else v2;
  msgOmega2 = if middleThird then delayedOmega2 else omega2;

  msgX3 = if middleThird then delayedX3 else x3;
  msgY3 = if middleThird then delayedY3 else y3;
  msgTheta3 = if middleThird then delayedTheta3 else theta3;
  msgV3 = if middleThird then delayedV3 else v3;
  msgOmega3 = if middleThird then delayedOmega3 else omega3;

  // Onboard state estimation and odometry
  estX1 = x1;
  estY1 = y1;
  estTheta1 = theta1;
  estV1 = v1;
  estOmega1 = omega1;

  estX2 = x2;
  estY2 = y2;
  estTheta2 = theta2;
  estV2 = v2;
  estOmega2 = omega2;

  estX3 = x3;
  estY3 = y3;
  estTheta3 = theta3;
  estV3 = v3;
  estOmega3 = omega3;

  odoX1 = x1;
  odoY1 = y1;
  odoTheta1 = theta1;
  odoV1 = v1;
  odoOmega1 = omega1;

  odoX2 = x2;
  odoY2 = y2;
  odoTheta2 = theta2;
  odoV2 = v2;
  odoOmega2 = omega2;

  odoX3 = x3;
  odoY3 = y3;
  odoTheta3 = theta3;
  odoV3 = v3;
  odoOmega3 = omega3;

  // Peer-relative range sensors
  range12Meas = sqrt((estX1 - msgX2)^2 + (estY1 - msgY2)^2 + epsLen);
  range13Meas = sqrt((estX1 - msgX3)^2 + (estY1 - msgY3)^2 + epsLen);
  range21Meas = sqrt((estX2 - msgX1)^2 + (estY2 - msgY1)^2 + epsLen);
  range23Meas = sqrt((estX2 - msgX3)^2 + (estY2 - msgY3)^2 + epsLen);
  range31Meas = sqrt((estX3 - msgX1)^2 + (estY3 - msgY1)^2 + epsLen);
  range32Meas = sqrt((estX3 - msgX2)^2 + (estY3 - msgY2)^2 + epsLen);

  minRange1 = min(range12Meas, range13Meas);
  minRange2 = min(range21Meas, range23Meas);
  minRange3 = min(range31Meas, range32Meas);

  safeF1 = if minRange1 < minSeparation then Ksep*(minSeparation - minRange1) else 0.0;
  safeF2 = if minRange2 < minSeparation then -Ksep*(minSeparation - minRange2) else 0.0;
  safeF3 = if minRange3 < minSeparation then -Ksep*(minSeparation - minRange3) else 0.0;

  // Pairwise separation
  sep12 = sqrt((x1 - x2)^2 + (y1 - y2)^2 + epsLen);
  sep13 = sqrt((x1 - x3)^2 + (y1 - y3)^2 + epsLen);
  sep23 = sqrt((x2 - x3)^2 + (y2 - y3)^2 + epsLen);
  minSeparationMeas = min(min(sep12, sep13), sep23);

  // Lidar obstacle ranges
  lidar1O1 = sqrt((x1 - obstacle1X)^2 + (y1 - obstacle1Y)^2 + epsLen);
  lidar1O2 = sqrt((x1 - obstacle2X)^2 + (y1 - obstacle2Y)^2 + epsLen);
  lidar1O3 = sqrt((x1 - obstacle3X)^2 + (y1 - obstacle3Y)^2 + epsLen);
  lidar2O1 = sqrt((x2 - obstacle1X)^2 + (y2 - obstacle1Y)^2 + epsLen);
  lidar2O2 = sqrt((x2 - obstacle2X)^2 + (y2 - obstacle2Y)^2 + epsLen);
  lidar2O3 = sqrt((x2 - obstacle3X)^2 + (y2 - obstacle3Y)^2 + epsLen);
  lidar3O1 = sqrt((x3 - obstacle1X)^2 + (y3 - obstacle1Y)^2 + epsLen);
  lidar3O2 = sqrt((x3 - obstacle2X)^2 + (y3 - obstacle2Y)^2 + epsLen);
  lidar3O3 = sqrt((x3 - obstacle3X)^2 + (y3 - obstacle3Y)^2 + epsLen);
  lidarMin1 = min(min(lidar1O1, lidar1O2), lidar1O3);
  lidarMin2 = min(min(lidar2O1, lidar2O2), lidar2O3);
  lidarMin3 = min(min(lidar3O1, lidar3O2), lidar3O3);

  // Formation and tracking metrics
  primaryTrackingError = sqrt((x1 - leaderX)^2 + (y1 - leaderY)^2 + epsLen);
  offsetErr2 = sqrt((x2 - x1 - offset2X)^2 + (y2 - y1 - offset2Y)^2 + epsLen);
  offsetErr3 = sqrt((x3 - x1 - offset3X)^2 + (y3 - y1 - offset3Y)^2 + epsLen);
  formationError = max(max(primaryTrackingError, offsetErr2), offsetErr3);
  communicationAge = if middleThird then Tdelay else 0.0;

  // Acceptance conditions
  actuatorLimitOK = abs(tauBoundedL1) <= tauMax + epsTau and
                     abs(tauBoundedR1) <= tauMax + epsTau and
                     abs(tauBoundedL2) <= tauMax + epsTau and
                     abs(tauBoundedR2) <= tauMax + epsTau and
                     abs(tauBoundedL3) <= tauMax + epsTau and
                     abs(tauBoundedR3) <= tauMax + epsTau;

  separationOK = minSeparationMeas >= minSeparation - epsLen;
  formationErrorOK = formationError <= formationErrorLimit + epsLen;
  communicationAgeOK = communicationAge <= Tdelay + epsTime;
  noCollision = sep12 > 2*robotRadius + epsLen and
                sep13 > 2*robotRadius + epsLen and
                sep23 > 2*robotRadius + epsLen and
                lidarMin1 > obstacleRadius + robotRadius + epsLen and
                lidarMin2 > obstacleRadius + robotRadius + epsLen and
                lidarMin3 > obstacleRadius + robotRadius + epsLen;
  trackingOK = if time >= Ttracking then primaryTrackingError <= primaryTrackingLimit + epsLen else true;

  noNaNInf = abs(x1) < big and abs(y1) < big and abs(theta1) < big and abs(v1) < big and abs(omega1) < big and
             abs(x2) < big and abs(y2) < big and abs(theta2) < big and abs(v2) < big and abs(omega2) < big and
             abs(x3) < big and abs(y3) < big and abs(theta3) < big and abs(v3) < big and abs(omega3) < big and
             abs(tauActL1) < big and abs(tauActR1) < big and abs(tauActL2) < big and abs(tauActR2) < big and abs(tauActL3) < big and abs(tauActR3) < big and
             abs(tauBoundedL1) < big and abs(tauBoundedR1) < big and abs(tauBoundedL2) < big and abs(tauBoundedR2) < big and abs(tauBoundedL3) < big and abs(tauBoundedR3) < big and
             abs(Fdes1) < big and abs(Fdes2) < big and abs(Fdes3) < big and
             abs(Mdes1) < big and abs(Mdes2) < big and abs(Mdes3) < big and
             abs(estX1) < big and abs(estY1) < big and abs(estTheta1) < big and abs(estV1) < big and abs(estOmega1) < big and
             abs(estX2) < big and abs(estY2) < big and abs(estTheta2) < big and abs(estV2) < big and abs(estOmega2) < big and
             abs(estX3) < big and abs(estY3) < big and abs(estTheta3) < big and abs(estV3) < big and abs(estOmega3) < big and
             abs(range12Meas) < big and abs(range13Meas) < big and abs(range23Meas) < big and
             abs(lidarMin1) < big and abs(lidarMin2) < big and abs(lidarMin3) < big and
             abs(primaryTrackingError) < big and abs(formationError) < big and abs(communicationAge) < big;

  when sample(0, Ts) then
    // Robot 1: primary leader tracking
    errForward1 = (leaderX - estX1)*cos(leaderTheta) + (leaderY - estY1)*sin(leaderTheta);
    errLateral1 = -(leaderX - estX1)*sin(leaderTheta) + (leaderY - estY1)*cos(leaderTheta);
    errV1 = vLeader - estV1;
    errTheta1 = Modelica.Math.atan2(sin(leaderTheta + Klat*errLateral1 - estTheta1), cos(leaderTheta + Klat*errLateral1 - estTheta1));
    Fdes1 = mRobot*(KpTrack*errForward1 + KdTrack*errV1) + dragForce*estV1 + safeF1;
    Mdes1 = Izz*(KpYaw*errTheta1 + KdYaw*(leaderOmega - estOmega1)) + yawDamping*estOmega1;
    tauRawL1 = wheelRadius*(Fdes1/2 - Mdes1/track);
    tauRawR1 = wheelRadius*(Fdes1/2 + Mdes1/track);
    magRaw1 = max(abs(tauRawL1), abs(tauRawR1));
    scale1 = if magRaw1 > tauMax then tauMax/max(magRaw1, epsTau) else 1.0;
    tauBoundedL1 = tauRawL1*scale1;
    tauBoundedR1 = tauRawR1*scale1;

    // Robot 2: follower using delayed peer messages from robot 1
    desiredX2 = msgX1 + offset2X*cos(msgTheta1) - offset2Y*sin(msgTheta1);
    desiredY2 = msgY1 + offset2X*sin(msgTheta1) + offset2Y*cos(msgTheta1);
    errForward2 = (desiredX2 - estX2)*cos(msgTheta1) + (desiredY2 - estY2)*sin(msgTheta1);
    errLateral2 = -(desiredX2 - estX2)*sin(msgTheta1) + (desiredY2 - estY2)*cos(msgTheta1);
    errV2 = msgV1 - estV2;
    errTheta2 = Modelica.Math.atan2(sin(msgTheta1 + Klat*errLateral2 - estTheta2), cos(msgTheta1 + Klat*errLateral2 - estTheta2));
    errOmega2 = msgOmega1 - estOmega2;
    Fdes2 = mRobot*(KpTrack*errForward2 + KdTrack*errV2) + dragForce*estV2 + safeF2;
    Mdes2 = Izz*(KpYaw*errTheta2 + KdYaw*errOmega2) + yawDamping*estOmega2;
    tauRawL2 = wheelRadius*(Fdes2/2 - Mdes2/track);
    tauRawR2 = wheelRadius*(Fdes2/2 + Mdes2/track);
    magRaw2 = max(abs(tauRawL2), abs(tauRawR2));
    scale2 = if magRaw2 > tauMax then tauMax/max(magRaw2, epsTau) else 1.0;
    tauBoundedL2 = tauRawL2*scale2;
    tauBoundedR2 = tauRawR2*scale2;

    // Robot 3: follower using delayed peer messages from robot 1
    desiredX3 = msgX1 + offset3X*cos(msgTheta1) - offset3Y*sin(msgTheta1);
    desiredY3 = msgY1 + offset3X*sin(msgTheta1) + offset3Y*cos(msgTheta1);
    errForward3 = (desiredX3 - estX3)*cos(msgTheta1) + (desiredY3 - estY3)*sin(msgTheta1);
    errLateral3 = -(desiredX3 - estX3)*sin(msgTheta1) + (desiredY3 - estY3)*cos(msgTheta1);
    errV3 = msgV1 - estV3;
    errTheta3 = Modelica.Math.atan2(sin(msgTheta1 + Klat*errLateral3 - estTheta3), cos(msgTheta1 + Klat*errLateral3 - estTheta3));
    errOmega3 = msgOmega1 - estOmega3;
    Fdes3 = mRobot*(KpTrack*errForward3 + KdTrack*errV3) + dragForce*estV3 + safeF3;
    Mdes3 = Izz*(KpYaw*errTheta3 + KdYaw*errOmega3) + yawDamping*estOmega3;
    tauRawL3 = wheelRadius*(Fdes3/2 - Mdes3/track);
    tauRawR3 = wheelRadius*(Fdes3/2 + Mdes3/track);
    magRaw3 = max(abs(tauRawL3), abs(tauRawR3));
    scale3 = if magRaw3 > tauMax then tauMax/max(magRaw3, epsTau) else 1.0;
    tauBoundedL3 = tauRawL3*scale3;
    tauBoundedR3 = tauRawR3*scale3;

    accept = pre(accept) and actuatorLimitOK and separationOK and formationErrorOK and communicationAgeOK and noCollision and trackingOK and noNaNInf;
  end when;

  annotation (
    Experiment(StopTime=16, Interval=0.004, Tolerance=1e-6),
    Documentation(info="Three 18 kg differential-drive robots with six bounded wheel drives, odometry, lidar, delayed peer messages, distributed formation control at 250 Hz, and fail-closed acceptance. Values not stated in the request are marked as placeholders and must be replaced with verified calibration data before external acceptance."));
end GroundTrioFormE;