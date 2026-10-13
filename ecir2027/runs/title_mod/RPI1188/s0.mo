model MarinePairCoordinateF
  // Requirement-fixed values
  parameter Real m = 80.0 "AUV mass [kg]";
  parameter Real FthrusterMax = 128.0 "per thruster bound [N]";
  parameter Real Tfinal = 20.0 "simulation duration [s]";
  parameter Real samplePeriod = 0.002 "500 Hz trace period [s]";
  parameter Real delayDisturbance = 0.174 "middle-third acoustic modem delay [s]";

  // Explicit runnable assumptions; not stated by the requirement.
  // Route geometry: robot1 travels x=-L..L at z=0; robot2 travels z=-L..L at x=0;
  // intersection at (0,0).
  parameter Real L = 8.0 "route half-length [m]";
  parameter Real rConflict = 1.0 "conflict region radius [m]";
  parameter Real corridorHalfWidth = 0.5 "lane half-width [m]";
  parameter Real safetyMargin = 0.5 "reservation safety margin [m]";
  parameter Real vehicleRadius = 0.3 "collision radius [m]";
  parameter Real amaxPlan = 2.0 "planned bounded braking acceleration [m/s2]";
  parameter Real Kvel = 2.0 "velocity tracking gain [1/s]";
  parameter Real speedRef = 1.5 "cruise speed [m/s]";
  parameter Real delayMax = 0.2 "delay buffer upper bound [s]";
  parameter Real completionTol = 0.05 "route completion tolerance [m]";
  parameter Real FaxleMax = 2.0*FthrusterMax "two channels per axis [N]";

  // Dynamic states
  output Real x1(start=-L, fixed=true) "robot1 surge position [m]";
  output Real z1(start=0.0, fixed=true) "robot1 heave/depth position [m]";
  output Real vx1(start=0.0, fixed=true) "robot1 surge velocity [m/s]";
  output Real vz1(start=0.0, fixed=true) "robot1 heave velocity [m/s]";
  output Real x2(start=0.0, fixed=true) "robot2 surge position [m]";
  output Real z2(start=-L, fixed=true) "robot2 heave/depth position [m]";
  output Real vx2(start=0.0, fixed=true) "robot2 surge velocity [m/s]";
  output Real vz2(start=0.0, fixed=true) "robot2 heave velocity [m/s]";
  output Real waitingTime1(start=0.0, fixed=true) "robot1 waiting time [s]";
  output Real waitingTime2(start=0.0, fixed=true) "robot2 waiting time [s]";
  output Real minDistance(start=100.0, fixed=true) "minimum pairwise distance [m]";

  // Command and actuator traces
  output Real Fx1Cmd "robot1 surge force command [N]";
  output Real Fz1Cmd "robot1 heave force command [N]";
  output Real Fx2Cmd "robot2 surge force command [N]";
  output Real Fz2Cmd "robot2 heave force command [N]";
  output Real f1_surge1 "robot1 surge channel 1 [N]";
  output Real f1_surge2 "robot1 surge channel 2 [N]";
  output Real f1_heave1 "robot1 heave channel 3 [N]";
  output Real f1_heave2 "robot1 heave channel 4 [N]";
  output Real f2_surge1 "robot2 surge channel 5 [N]";
  output Real f2_surge2 "robot2 surge channel 6 [N]";
  output Real f2_heave1 "robot2 heave channel 7 [N]";
  output Real f2_heave2 "robot2 heave channel 8 [N]";

  // Sensor and estimator traces
  output Real depth1 "pressure depth robot1 [m]";
  output Real depth2 "pressure depth robot2 [m]";
  output Real dvlVx1 "DVL surge velocity robot1 [m/s]";
  output Real dvlVz1 "DVL heave velocity robot1 [m/s]";
  output Real dvlVx2 "DVL surge velocity robot2 [m/s]";
  output Real dvlVz2 "DVL heave velocity robot2 [m/s]";
  output Real imuPitch1 "IMU pitch robot1 [rad]";
  output Real imuPitch2 "IMU pitch robot2 [rad]";
  output Real locX1 "localized x robot1 [m]";
  output Real locZ1 "localized z robot1 [m]";
  output Real locX2 "localized x robot2 [m]";
  output Real locZ2 "localized z robot2 [m]";
  output Real obstacleRange1 "obstacle range robot1 [m]";
  output Real obstacleRange2 "obstacle range robot2 [m]";
  output Real peer1X "peer1 x state seen by robot2 [m]";
  output Real peer1Z "peer1 z state seen by robot2 [m]";
  output Real peer1Vx "peer1 vx state seen by robot2 [m/s]";
  output Real peer1Vz "peer1 vz state seen by robot2 [m/s]";
  output Real peer2X "peer2 x state seen by robot1 [m]";
  output Real peer2Z "peer2 z state seen by robot1 [m]";
  output Real peer2Vx "peer2 vx state seen by robot1 [m/s]";
  output Real peer2Vz "peer2 vz state seen by robot1 [m/s]";
  output Real msgDelay1 "applied modem delay robot1 [s]";
  output Real msgDelay2 "applied modem delay robot2 [s]";

  // Reservation and control traces
  output Real reservation1 "robot1 reservation flag";
  output Real reservation2 "robot2 reservation flag";
  output Real allowed2 "robot2 allowed to enter conflict";
  output Real waiting1 "robot1 waiting flag";
  output Real waiting2 "robot2 waiting flag";
  output Real targetZ2 "robot2 heave target [m]";
  output Real corridorDeviation1 "robot1 lane deviation [m]";
  output Real corridorDeviation2 "robot2 lane deviation [m]";
  output Real corridorViolation1 "1 if robot1 leaves lane";
  output Real corridorViolation2 "1 if robot2 leaves lane";

  // Verification traces
  output Real distance "pairwise distance [m]";
  output Real actuatorBoundOk "1 if all thruster bounds satisfied";
  output Real mutualExclusionViolation "1 if both in conflict region";
  output Real mutualExclusionOk "1 if mutual exclusion satisfied";
  output Real collisionViolation "1 if collision";
  output Real noCollisionOk "1 if no collision";
  output Real minDistanceOk "1 if minimum distance above collision radius";
  output Real route1Complete "1 if robot1 route complete";
  output Real route2Complete "1 if robot2 route complete";
  output Real routeCompletionOk "1 if both routes complete";
  output Real trackingError1 "robot1 tracking error [m]";
  output Real trackingError2 "robot2 tracking error [m]";
  output Real primaryTrackingError "max tracking error [m]";
  output Real after13sTrackingError "tracking error after 13 s [m]";
  output Real primaryTrackingErrorOk "1 if tracking error <=0.52 after 13 s";
  output Real finiteValueOk "1 if checked physical/control/estimator values are finite";

  // Internal variables
  Real remX1, remZ1, remX2, remZ2;
  Real vDesX1, vDesZ1, vDesX2, vDesZ2;
  Real Fx1Clamped, Fz1Clamped, Fx2Clamped, Fz2Clamped;
  Real Fx1Actual, Fz1Actual, Fx2Actual, Fz2Actual;
  Real distToConflict1, distToConflict2;
  Boolean request1, request2, peer1Clear, inConflict1, inConflict2, inMiddleThird;
  Real x1Delayed, z1Delayed, vx1Delayed, vz1Delayed;
  Real x2Delayed, z2Delayed, vx2Delayed, vz2Delayed;

equation
  // Acoustic modem delay disturbance: applied during the middle third of the run.
  inMiddleThird = time >= Tfinal/3.0 and time <= 2.0*Tfinal/3.0;
  msgDelay1 = if inMiddleThird then delayDisturbance else 0.0;
  msgDelay2 = msgDelay1;
  x1Delayed = delay(x1, delayDisturbance, delayMax);
  z1Delayed = delay(z1, delayDisturbance, delayMax);
  vx1Delayed = delay(vx1, delayDisturbance, delayMax);
  vz1Delayed = delay(vz1, delayDisturbance, delayMax);
  x2Delayed = delay(x2, delayDisturbance, delayMax);
  z2Delayed = delay(z2, delayDisturbance, delayMax);
  vx2Delayed = delay(vx2, delayDisturbance, delayMax);
  vz2Delayed = delay(vz2, delayDisturbance, delayMax);
  peer1X = if inMiddleThird then x1Delayed else x1;
  peer1Z = if inMiddleThird then z1Delayed else z1;
  peer1Vx = if inMiddleThird then vx1Delayed else vx1;
  peer1Vz = if inMiddleThird then vz1Delayed else vz1;
  peer2X = if inMiddleThird then x2Delayed else x2;
  peer2Z = if inMiddleThird then z2Delayed else z2;
  peer2Vx = if inMiddleThird then vx2Delayed else vx2;
  peer2Vz = if inMiddleThird then vz2Delayed else vz2;

  // Onboard sensors and localization. Sensor noise is not stated, so ideal traces are used.
  depth1 = z1;
  depth2 = z2;
  dvlVx1 = vx1;
  dvlVz1 = vz1;
  dvlVx2 = vx2;
  dvlVz2 = vz2;
  imuPitch1 = if (abs(vx1) < 1e-12 and abs(vz1) < 1e-12) then 0.0 else atan2(vz1, vx1 + 1e-9);
  imuPitch2 = if (abs(vx2) < 1e-12 and abs(vz2) < 1e-12) then 0.0 else atan2(vz2, vx2 + 1e-9);
  locX1 = x1;
  locZ1 = z1;
  locX2 = x2;
  locZ2 = z2;
  distance = sqrt((x1 - x2)^2 + (z1 - z2)^2);
  obstacleRange1 = distance;
  obstacleRange2 = distance;

  // Fixed corridor geometry
  corridorDeviation1 = abs(z1);
  corridorDeviation2 = abs(x2);
  corridorViolation1 = if corridorDeviation1 > corridorHalfWidth then 1.0 else 0.0;
  corridorViolation2 = if corridorDeviation2 > corridorHalfWidth then 1.0 else 0.0;

  // Decentralized reservation. Robot1 has priority on the shared intersection.
  distToConflict1 = abs(x1);
  distToConflict2 = abs(z2);
  request1 = distToConflict1 <= rConflict + safetyMargin;
  request2 = distToConflict2 <= rConflict + safetyMargin;
  peer1Clear = peer1X > rConflict + safetyMargin;
  reservation1 = if request1 then 1.0 else 0.0;
  allowed2 = if (request2 and peer1Clear) then 1.0 else 0.0;
  reservation2 = allowed2;
  waiting1 = 0.0;
  waiting2 = if (request2 and not peer1Clear) then 1.0 else 0.0;
  targetZ2 = if allowed2 > 0.5 then L else -rConflict;

  // Bounded braking speed profile
  remX1 = L - x1;
  remZ1 = 0.0 - z1;
  remX2 = 0.0 - x2;
  remZ2 = targetZ2 - z2;
  vDesX1 = if remX1 > 0.0 then min(speedRef, sqrt(max(0.0, 2.0*amaxPlan*remX1))) else if remX1 < 0.0 then -min(speedRef, sqrt(max(0.0, 2.0*amaxPlan*(-remX1)))) else 0.0;
  vDesZ1 = if remZ1 > 0.0 then min(speedRef, sqrt(max(0.0, 2.0*amaxPlan*remZ1))) else if remZ1 < 0.0 then -min(speedRef, sqrt(max(0.0, 2.0*amaxPlan*(-remZ1)))) else 0.0;
  vDesX2 = if remX2 > 0.0 then min(speedRef, sqrt(max(0.0, 2.0*amaxPlan*remX2))) else if remX2 < 0.0 then -min(speedRef, sqrt(max(0.0, 2.0*amaxPlan*(-remX2)))) else 0.0;
  vDesZ2 = if remZ2 > 0.0 then min(speedRef, sqrt(max(0.0, 2.0*amaxPlan*remZ2))) else if remZ2 < 0.0 then -min(speedRef, sqrt(max(0.0, 2.0*amaxPlan*(-remZ2)))) else 0.0;

  // Force commands
  Fx1Cmd = m*Kvel*(vDesX1 - vx1);
  Fz1Cmd = m*Kvel*(vDesZ1 - vz1);
  Fx2Cmd = m*Kvel*(vDesX2 - vx2);
  Fz2Cmd = m*Kvel*(vDesZ2 - vz2);

  // Axis clamps
  Fx1Clamped = max(-FaxleMax, min(FaxleMax, Fx1Cmd));
  Fz1Clamped = max(-FaxleMax, min(FaxleMax, Fz1Cmd));
  Fx2Clamped = max(-FaxleMax, min(FaxleMax, Fx2Cmd));
  Fz2Clamped = max(-FaxleMax, min(FaxleMax, Fz2Cmd));

  // Eight bidirectional thruster channels: two per axis per AUV.
  f1_surge1 = max(-FthrusterMax, min(FthrusterMax, Fx1Clamped/2.0));
  f1_surge2 = max(-FthrusterMax, min(FthrusterMax, Fx1Clamped/2.0));
  f1_heave1 = max(-FthrusterMax, min(FthrusterMax, Fz1Clamped/2.0));
  f1_heave2 = max(-FthrusterMax, min(FthrusterMax, Fz1Clamped/2.0));
  f2_surge1 = max(-FthrusterMax, min(FthrusterMax, Fx2Clamped/2.0));
  f2_surge2 = max(-FthrusterMax, min(FthrusterMax, Fx2Clamped/2.0));
  f2_heave1 = max(-FthrusterMax, min(FthrusterMax, Fz2Clamped/2.0));
  f2_heave2 = max(-FthrusterMax, min(FthrusterMax, Fz2Clamped/2.0));

  Fx1Actual = f1_surge1 + f1_surge2;
  Fz1Actual = f1_heave1 + f1_heave2;
  Fx2Actual = f2_surge1 + f2_surge2;
  Fz2Actual = f2_heave1 + f2_heave2;

  // Dynamics: double integrator using stated mass and bounded thruster forces.
  // Hydrodynamic drag coefficients are not stated, so drag is omitted rather than invented.
  der(x1) = vx1;
  der(z1) = vz1;
  der(vx1) = Fx1Actual/m;
  der(vz1) = Fz1Actual/m;
  der(x2) = vx2;
  der(z2) = vz2;
  der(vx2) = Fx2Actual/m;
  der(vz2) = Fz2Actual/m;
  der(waitingTime1) = if waiting1 > 0.5 then 1.0 else 0.0;
  der(waitingTime2) = if waiting2 > 0.5 then 1.0 else 0.0;

  // Minimum distance retained at 500 Hz.
  when sample(0, samplePeriod) then
    minDistance = min(pre(minDistance), sqrt((x1 - x2)^2 + (z1 - z2)^2));
  end when;

  // Verification criteria
  inConflict1 = abs(x1) <= rConflict and abs(z1) <= rConflict;
  inConflict2 = abs(x2) <= rConflict and abs(z2) <= rConflict;
  mutualExclusionViolation = if (inConflict1 and inConflict2) then 1.0 else 0.0;
  collisionViolation = if distance < 2.0*vehicleRadius then 1.0 else 0.0;
  actuatorBoundOk = if (abs(f1_surge1) <= FthrusterMax and abs(f1_surge2) <= FthrusterMax and abs(f1_heave1) <= FthrusterMax and abs(f1_heave2) <= FthrusterMax and abs(f2_surge1) <= FthrusterMax and abs(f2_surge2) <= FthrusterMax and abs(f2_heave1) <= FthrusterMax and abs(f2_heave2) <= FthrusterMax) then 1.0 else 0.0;
  minDistanceOk = if minDistance >= 2.0*vehicleRadius then 1.0 else 0.0;
  noCollisionOk = if collisionViolation <= 0.5 then 1.0 else 0.0;
  mutualExclusionOk = if mutualExclusionViolation <= 0.5 then 1.0 else 0.0;
  route1Complete = if x1 >= L - completionTol then 1.0 else 0.0;
  route2Complete = if z2 >= L - completionTol then 1.0 else 0.0;
  routeCompletionOk = if route1Complete > 0.5 and route2Complete > 0.5 then 1.0 else 0.0;
  trackingError1 = sqrt((x1 - L)^2 + z1^2);
  trackingError2 = sqrt(x2^2 + (z2 - L)^2);
  primaryTrackingError = max(trackingError1, trackingError2);
  after13sTrackingError = if time >= 13.0 then primaryTrackingError else 0.0;
  primaryTrackingErrorOk = if time >= 13.0 then (if primaryTrackingError <= 0.52 then 1.0 else 0.0) else 1.0;

  finiteValueOk = if noEvent(
    abs(x1) < 1e15 and abs(z1) < 1e15 and abs(vx1) < 1e15 and abs(vz1) < 1e15 and
    abs(x2) < 1e15 and abs(z2) < 1e15 and abs(vx2) < 1e15 and abs(vz2) < 1e15 and
    abs(Fx1Cmd) < 1e15 and abs(Fz1Cmd) < 1e15 and abs(Fx2Cmd) < 1e15 and abs(Fz2Cmd) < 1e15 and
    abs(f1_surge1) < 1e15 and abs(f1_surge2) < 1e15 and abs(f1_heave1) < 1e15 and abs(f1_heave2) < 1e15 and
    abs(f2_surge1) < 1e15 and abs(f2_surge2) < 1e15 and abs(f2_heave1) < 1e15 and abs(f2_heave2) < 1e15 and
    abs(depth1) < 1e15 and abs(depth2) < 1e15 and abs(dvlVx1) < 1e15 and abs(dvlVz1) < 1e15 and
    abs(dvlVx2) < 1e15 and abs(dvlVz2) < 1e15 and abs(imuPitch1) <= 3.15 and abs(imuPitch2) <= 3.15 and
    abs(locX1) < 1e15 and abs(locZ1) < 1e15 and abs(locX2) < 1e15 and abs(locZ2) < 1e15 and
    abs(peer1X) < 1e15 and abs(peer1Z) < 1e15 and abs(peer2X) < 1e15 and abs(peer2Z) < 1e15 and
    abs(distance) < 1e15 and abs(primaryTrackingError) < 1e15
  ) then 1.0 else 0.0;

  annotation(experiment(StartTime=0, StopTime=20, Tolerance=1e-6, Interval=0.002));
end MarinePairCoordinateF;