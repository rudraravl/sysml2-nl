model MarinePairResilientD
  import SI = Modelica.Units.SI;

  // Sampling and mission timing
  parameter SI.Frequency fSample=200 "Hz";
  parameter SI.Time Ts=1/fSample "s";
  parameter SI.Time stopTime=14 "s";
  parameter SI.Time dropStart=stopTime/3 "s, middle third start";
  parameter SI.Time dropEnd=dropStart+1 "s, controlled 1 s dropout";
  parameter SI.Time recoverTime=9.1 "s";
  parameter SI.Time modemDelay=Ts "s, finite one-sample acoustic modem delay";
  parameter SI.Time maxPredHorizon=1.0 "s, bounded prediction horizon";

  // Embodiment
  parameter SI.Mass m1=80 "kg";
  parameter SI.Mass m2=80 "kg";
  parameter SI.Force Fmax=105 "N per thruster";
  parameter Real dragX=20 "N.s/m";
  parameter Real dragZ=20 "N.s/m";

  // Route and formation geometry: not specified in requirement; selected finite values
  parameter SI.Position routeEndX=2.8 "m";
  parameter SI.Position formationDx=-1.5 "m";
  parameter SI.Position formationDz=0.5 "m";
  parameter SI.Length safeSeparation=0.8 "m";

  // Distributed control and estimator gains
  parameter Real Kp=200 "N/m";
  parameter Real Kd=300 "N.s/m";
  parameter Real Kf=80 "N/m";
  parameter Real Kcol=1000 "N/m";
  parameter Real Kvel=20 "1/s";
  parameter Real Kdepth=10 "1/s";

  // Shared environmental disturbance during dropout
  parameter SI.Force sharedDistX=-30 "N";
  parameter SI.Force sharedDistZ=10 "N";

  // Physical states
  output SI.Position x1(start=0);
  output SI.Position z1(start=0);
  output SI.Velocity vx1(start=0);
  output SI.Velocity vz1(start=0);
  output SI.Position x2(start=formationDx);
  output SI.Position z2(start=formationDz);
  output SI.Velocity vx2(start=0);
  output SI.Velocity vz2(start=0);

  // Estimator states
  output SI.Position estX1(start=0);
  output SI.Position estZ1(start=0);
  output SI.Velocity estVx1(start=0);
  output SI.Velocity estVz1(start=0);
  output SI.Position estX2(start=formationDx);
  output SI.Position estZ2(start=formationDz);
  output SI.Velocity estVx2(start=0);
  output SI.Velocity estVz2(start=0);

  // Sensors
  output SI.Acceleration imuAx1;
  output SI.Acceleration imuAz1;
  output SI.Acceleration imuAx2;
  output SI.Acceleration imuAz2;
  output SI.Position pressureDepth1;
  output SI.Position pressureDepth2;
  output SI.Velocity dvlVx1;
  output SI.Velocity dvlVz1;
  output SI.Velocity dvlVx2;
  output SI.Velocity dvlVz2;

  // Role-preserving measurement aliases
  SI.Acceleration proprioAx1;
  SI.Acceleration proprioAz1;
  SI.Acceleration proprioAx2;
  SI.Acceleration proprioAz2;
  SI.Position exteroDepth1;
  SI.Position exteroDepth2;
  SI.Velocity exteroDvlVx1;
  SI.Velocity exteroDvlVz1;
  SI.Velocity exteroDvlVx2;
  SI.Velocity exteroDvlVz2;

  // Acoustic modem: delayed peer state and last received peer state with timestamps
  SI.Position peer1DelayedX;
  SI.Position peer1DelayedZ;
  SI.Velocity peer1DelayedVX;
  SI.Velocity peer1DelayedVZ;
  SI.Position peer2DelayedX;
  SI.Position peer2DelayedZ;
  SI.Velocity peer2DelayedVX;
  SI.Velocity peer2DelayedVZ;
  output SI.Position lastPeer1X(start=0);
  output SI.Position lastPeer1Z(start=0);
  output SI.Velocity lastPeer1VX(start=0);
  output SI.Velocity lastPeer1VZ(start=0);
  output SI.Time lastPeer1Time(start=0);
  output SI.Position lastPeer2X(start=formationDx);
  output SI.Position lastPeer2Z(start=formationDz);
  output SI.Velocity lastPeer2VX(start=0);
  output SI.Velocity lastPeer2VZ(start=0);
  output SI.Time lastPeer2Time(start=0);

  // Predicted peer estimates
  output SI.Time dtPeer1;
  output SI.Time dtPeer2;
  output SI.Position peer1EstX;
  output SI.Position peer1EstZ;
  output SI.Velocity peer1EstVX;
  output SI.Velocity peer1EstVZ;
  output SI.Position peer2EstX;
  output SI.Position peer2EstZ;
  output SI.Velocity peer2EstVX;
  output SI.Velocity peer2EstVZ;

  // Route reference
  Real routeProgress;
  SI.Position routeX;
  SI.Position routeZ;
  SI.Velocity routeVX;
  SI.Velocity routeVZ;
  SI.Acceleration routeAX;
  SI.Acceleration routeAZ;

  // Disturbance and communication status
  output Boolean disturbanceActive;
  output Boolean commAvailable;
  output SI.Force FdistX;
  output SI.Force FdistZ;

  // Thruster forces
  SI.Force Fsurge1;
  SI.Force Fheave1;
  SI.Force Fsurge2;
  SI.Force Fheave2;
  SI.Force Fsurge1Cmd;
  SI.Force Fheave1Cmd;
  SI.Force Fsurge2Cmd;
  SI.Force Fheave2Cmd;

  // Eight bidirectional thruster channels
  SI.Force u1Cmd;
  SI.Force u2Cmd;
  SI.Force u3Cmd;
  SI.Force u4Cmd;
  SI.Force u5Cmd;
  SI.Force u6Cmd;
  SI.Force u7Cmd;
  SI.Force u8Cmd;
  SI.Force u1Actual;
  SI.Force u2Actual;
  SI.Force u3Actual;
  SI.Force u4Actual;
  SI.Force u5Actual;
  SI.Force u6Actual;
  SI.Force u7Actual;
  SI.Force u8Actual;
  Boolean u1Saturated;
  Boolean u2Saturated;
  Boolean u3Saturated;
  Boolean u4Saturated;
  Boolean u5Saturated;
  Boolean u6Saturated;
  Boolean u7Saturated;
  Boolean u8Saturated;

  // Formation and collision forces
  SI.Position rel1X;
  SI.Position rel1Z;
  SI.Position formErr1X;
  SI.Position formErr1Z;
  SI.Force Fform1X;
  SI.Force Fform1Z;
  SI.Position rel2X;
  SI.Position rel2Z;
  SI.Position formErr2X;
  SI.Position formErr2Z;
  SI.Force Fform2X;
  SI.Force Fform2Z;
  SI.Length sep1;
  SI.Length sep1Eff;
  SI.Force Fcol1X;
  SI.Force Fcol1Z;
  SI.Length sep2;
  SI.Length sep2Eff;
  SI.Force Fcol2X;
  SI.Force Fcol2Z;

  // Metrics
  output SI.Length separationActual;
  output SI.Length formationErrorActual;
  output SI.Length primaryTrackingError;
  output SI.Length degradedFormationError(start=0);
  output SI.Length degradedPrimaryError(start=0);
  output SI.Length recoveredFormationError(start=0);
  output SI.Length recoveredPrimaryError(start=0);
  output Boolean routeCompleted;
  output Boolean primaryTrackingErrorSatisfied;
  output Boolean collisionAvoidanceActive;
  output Boolean actuatorSaturatedAny;
  output Boolean actuatorBoundRespected;
  output Boolean finiteValuesOk;

  // Synchronized 200 Hz traces
  output SI.Time syncTime(start=0);
  output SI.Position syncX1(start=0);
  output SI.Position syncZ1(start=0);
  output SI.Velocity syncVx1(start=0);
  output SI.Velocity syncVz1(start=0);
  output SI.Position syncX2(start=0);
  output SI.Position syncZ2(start=0);
  output SI.Velocity syncVx2(start=0);
  output SI.Velocity syncVz2(start=0);
  output SI.Force syncFsurge1Cmd(start=0);
  output SI.Force syncFheave1Cmd(start=0);
  output SI.Force syncFsurge2Cmd(start=0);
  output SI.Force syncFheave2Cmd(start=0);
  output SI.Force syncU1Actual(start=0);
  output SI.Force syncU2Actual(start=0);
  output SI.Force syncU3Actual(start=0);
  output SI.Force syncU4Actual(start=0);
  output SI.Force syncU5Actual(start=0);
  output SI.Force syncU6Actual(start=0);
  output SI.Force syncU7Actual(start=0);
  output SI.Force syncU8Actual(start=0);
  output SI.Position syncPressureDepth1(start=0);
  output SI.Position syncPressureDepth2(start=0);
  output SI.Velocity syncDvlVx1(start=0);
  output SI.Velocity syncDvlVz1(start=0);
  output SI.Velocity syncDvlVx2(start=0);
  output SI.Velocity syncDvlVz2(start=0);
  output SI.Acceleration syncImuAx1(start=0);
  output SI.Acceleration syncImuAz1(start=0);
  output SI.Acceleration syncImuAx2(start=0);
  output SI.Acceleration syncImuAz2(start=0);
  output SI.Position syncPeer1X(start=0);
  output SI.Position syncPeer1Z(start=0);
  output SI.Time syncPeer1Time(start=0);
  output SI.Position syncPeer2X(start=0);
  output SI.Position syncPeer2Z(start=0);
  output SI.Time syncPeer2Time(start=0);
  output SI.Length syncFormationError(start=0);
  output SI.Length syncPrimaryError(start=0);

equation
  // Smooth finite route over 14 s
  routeProgress = 0.5*(1 - cos(Modelica.Constants.pi*time/stopTime));
  routeX = routeEndX*routeProgress;
  routeZ = 0.0;
  routeVX = routeEndX*Modelica.Constants.pi/(2*stopTime)*sin(Modelica.Constants.pi*time/stopTime);
  routeVZ = 0.0;
  routeAX = routeEndX*Modelica.Constants.pi^2/(2*stopTime^2)*cos(Modelica.Constants.pi*time/stopTime);
  routeAZ = 0.0;

  // Dropout and shared disturbance
  disturbanceActive = time >= dropStart and time < dropEnd;
  commAvailable = not disturbanceActive;
  FdistX = if disturbanceActive then sharedDistX else 0.0;
  FdistZ = if disturbanceActive then sharedDistZ else 0.0;

  // AUV dynamics
  der(x1) = vx1;
  der(z1) = vz1;
  m1*der(vx1) = Fsurge1 + FdistX - dragX*vx1;
  m1*der(vz1) = Fheave1 + FdistZ - dragZ*vz1;

  der(x2) = vx2;
  der(z2) = vz2;
  m2*der(vx2) = Fsurge2 + FdistX - dragX*vx2;
  m2*der(vz2) = Fheave2 + FdistZ - dragZ*vz2;

  // Actual thruster forces
  Fsurge1 = u1Actual + u2Actual;
  Fheave1 = u3Actual + u4Actual;
  Fsurge2 = u5Actual + u6Actual;
  Fheave2 = u7Actual + u8Actual;

  // Sensors
  imuAx1 = (Fsurge1 + FdistX - dragX*vx1)/m1;
  imuAz1 = (Fheave1 + FdistZ - dragZ*vz1)/m1;
  pressureDepth1 = z1;
  dvlVx1 = vx1;
  dvlVz1 = vz1;

  imuAx2 = (Fsurge2 + FdistX - dragX*vx2)/m2;
  imuAz2 = (Fheave2 + FdistZ - dragZ*vz2)/m2;
  pressureDepth2 = z2;
  dvlVx2 = vx2;
  dvlVz2 = vz2;

  proprioAx1 = imuAx1;
  proprioAz1 = imuAz1;
  proprioAx2 = imuAx2;
  proprioAz2 = imuAz2;
  exteroDepth1 = pressureDepth1;
  exteroDepth2 = pressureDepth2;
  exteroDvlVx1 = dvlVx1;
  exteroDvlVz1 = dvlVz1;
  exteroDvlVx2 = dvlVx2;
  exteroDvlVz2 = dvlVz2;

  // Delayed acoustic modem signals
  peer1DelayedX = delay(x1, modemDelay, stopTime + 1);
  peer1DelayedZ = delay(z1, modemDelay, stopTime + 1);
  peer1DelayedVX = delay(vx1, modemDelay, stopTime + 1);
  peer1DelayedVZ = delay(vz1, modemDelay, stopTime + 1);
  peer2DelayedX = delay(x2, modemDelay, stopTime + 1);
  peer2DelayedZ = delay(z2, modemDelay, stopTime + 1);
  peer2DelayedVX = delay(vx2, modemDelay, stopTime + 1);
  peer2DelayedVZ = delay(vz2, modemDelay, stopTime + 1);

  // Local estimators using proprioception and exteroception
  der(estX1) = estVx1;
  der(estZ1) = estVz1 + Kdepth*(exteroDepth1 - estZ1);
  der(estVx1) = proprioAx1 + Kvel*(exteroDvlVx1 - estVx1);
  der(estVz1) = proprioAz1 + Kvel*(exteroDvlVz1 - estVz1);

  der(estX2) = estVx2;
  der(estZ2) = estVz2 + Kdepth*(exteroDepth2 - estZ2);
  der(estVx2) = proprioAx2 + Kvel*(exteroDvlVx2 - estVx2);
  der(estVz2) = proprioAz2 + Kvel*(exteroDvlVz2 - estVz2);

  // Bounded peer prediction from last received peer state
  dtPeer1 = max(0.0, min(time - lastPeer1Time, maxPredHorizon));
  peer1EstX = lastPeer1X + lastPeer1VX*dtPeer1;
  peer1EstZ = lastPeer1Z + lastPeer1VZ*dtPeer1;
  peer1EstVX = lastPeer1VX;
  peer1EstVZ = lastPeer1VZ;

  dtPeer2 = max(0.0, min(time - lastPeer2Time, maxPredHorizon));
  peer2EstX = lastPeer2X + lastPeer2VX*dtPeer2;
  peer2EstZ = lastPeer2Z + lastPeer2VZ*dtPeer2;
  peer2EstVX = lastPeer2VX;
  peer2EstVZ = lastPeer2VZ;

  // Distributed formation control
  rel1X = peer2EstX - estX1;
  rel1Z = peer2EstZ - estZ1;
  formErr1X = rel1X - formationDx;
  formErr1Z = rel1Z - formationDz;
  Fform1X = Kf*formErr1X;
  Fform1Z = Kf*formErr1Z;

  rel2X = estX2 - peer1EstX;
  rel2Z = estZ2 - peer1EstZ;
  formErr2X = rel2X - formationDx;
  formErr2Z = rel2Z - formationDz;
  Fform2X = -Kf*formErr2X;
  Fform2Z = -Kf*formErr2Z;

  // Collision avoidance with zero-safe norm branch
  sep1 = sqrt((estX1 - peer2EstX)^2 + (estZ1 - peer2EstZ)^2 + 1e-6);
  sep1Eff = max(sep1, 0.01);
  if noEvent(sep1 < safeSeparation) then
    Fcol1X = Kcol*(safeSeparation - sep1)*(estX1 - peer2EstX)/sep1Eff;
    Fcol1Z = Kcol*(safeSeparation - sep1)*(estZ1 - peer2EstZ)/sep1Eff;
  else
    Fcol1X = 0.0;
    Fcol1Z = 0.0;
  end if;

  sep2 = sqrt((estX2 - peer1EstX)^2 + (estZ2 - peer1EstZ)^2 + 1e-6);
  sep2Eff = max(sep2, 0.01);
  if noEvent(sep2 < safeSeparation) then
    Fcol2X = Kcol*(safeSeparation - sep2)*(estX2 - peer1EstX)/sep2Eff;
    Fcol2Z = Kcol*(safeSeparation - sep2)*(estZ2 - peer1EstZ)/sep2Eff;
  else
    Fcol2X = 0.0;
    Fcol2Z = 0.0;
  end if;

  // Distributed PD commands with feedforward and formation/collision terms
  Fsurge1Cmd = m1*routeAX + Kp*(routeX - estX1) + Kd*(routeVX - estVx1) + dragX*estVx1 + Fform1X + Fcol1X;
  Fheave1Cmd = m1*routeAZ + Kp*(routeZ - estZ1) + Kd*(routeVZ - estVz1) + dragZ*estVz1 + Fform1Z + Fcol1Z;
  Fsurge2Cmd = m2*routeAX + Kp*((routeX + formationDx) - estX2) + Kd*(routeVX - estVx2) + dragX*estVx2 + Fform2X + Fcol2X;
  Fheave2Cmd = m2*routeAZ + Kp*((routeZ + formationDz) - estZ2) + Kd*(routeVZ - estVz2) + dragZ*estVz2 + Fform2Z + Fcol2Z;

  // Eight channel commands and per-thruster saturation
  u1Cmd = 0.5*Fsurge1Cmd;
  u2Cmd = 0.5*Fsurge1Cmd;
  u3Cmd = 0.5*Fheave1Cmd;
  u4Cmd = 0.5*Fheave1Cmd;
  u5Cmd = 0.5*Fsurge2Cmd;
  u6Cmd = 0.5*Fsurge2Cmd;
  u7Cmd = 0.5*Fheave2Cmd;
  u8Cmd = 0.5*Fheave2Cmd;

  u1Actual = max(-Fmax, min(Fmax, u1Cmd));
  u2Actual = max(-Fmax, min(Fmax, u2Cmd));
  u3Actual = max(-Fmax, min(Fmax, u3Cmd));
  u4Actual = max(-Fmax, min(Fmax, u4Cmd));
  u5Actual = max(-Fmax, min(Fmax, u5Cmd));
  u6Actual = max(-Fmax, min(Fmax, u6Cmd));
  u7Actual = max(-Fmax, min(Fmax, u7Cmd));
  u8Actual = max(-Fmax, min(Fmax, u8Cmd));

  u1Saturated = abs(u1Cmd) > Fmax + 1e-6;
  u2Saturated = abs(u2Cmd) > Fmax + 1e-6;
  u3Saturated = abs(u3Cmd) > Fmax + 1e-6;
  u4Saturated = abs(u4Cmd) > Fmax + 1e-6;
  u5Saturated = abs(u5Cmd) > Fmax + 1e-6;
  u6Saturated = abs(u6Cmd) > Fmax + 1e-6;
  u7Saturated = abs(u7Cmd) > Fmax + 1e-6;
  u8Saturated = abs(u8Cmd) > Fmax + 1e-6;

  // Metrics and verification
  separationActual = sqrt((x2 - x1)^2 + (z2 - z1)^2 + 1e-6);
  formationErrorActual = sqrt(((x2 - x1) - formationDx)^2 + ((z2 - z1) - formationDz)^2 + 1e-12);
  primaryTrackingError = sqrt((x1 - routeX)^2 + (z1 - routeZ)^2 + 1e-12);
  routeCompleted = time >= stopTime;
  primaryTrackingErrorSatisfied = time >= recoverTime and recoveredPrimaryError < 0.6;
  collisionAvoidanceActive = noEvent(sep1 < safeSeparation) or noEvent(sep2 < safeSeparation) or noEvent(separationActual < safeSeparation);
  actuatorSaturatedAny = u1Saturated or u2Saturated or u3Saturated or u4Saturated or u5Saturated or u6Saturated or u7Saturated or u8Saturated;
  actuatorBoundRespected = noEvent(abs(u1Actual) <= Fmax + 1e-6 and abs(u2Actual) <= Fmax + 1e-6 and abs(u3Actual) <= Fmax + 1e-6 and abs(u4Actual) <= Fmax + 1e-6 and abs(u5Actual) <= Fmax + 1e-6 and abs(u6Actual) <= Fmax + 1e-6 and abs(u7Actual) <= Fmax + 1e-6 and abs(u8Actual) <= Fmax + 1e-6);
  finiteValuesOk = noEvent(abs(x1) < 1e9 and abs(z1) < 1e9 and abs(vx1) < 1e9 and abs(vz1) < 1e9 and
    abs(x2) < 1e9 and abs(z2) < 1e9 and abs(vx2) < 1e9 and abs(vz2) < 1e9 and
    abs(estX1) < 1e9 and abs(estZ1) < 1e9 and abs(estVx1) < 1e9 and abs(estVz1) < 1e9 and
    abs(estX2) < 1e9 and abs(estZ2) < 1e9 and abs(estVx2) < 1e9 and abs(estVz2) < 1e9 and
    abs(peer1EstX) < 1e9 and abs(peer1EstZ) < 1e9 and abs(peer2EstX) < 1e9 and abs(peer2EstZ) < 1e9 and
    abs(u1Actual) < 1e9 and abs(u2Actual) < 1e9 and abs(u3Actual) < 1e9 and abs(u4Actual) < 1e9 and
    abs(u5Actual) < 1e9 and abs(u6Actual) < 1e9 and abs(u7Actual) < 1e9 and abs(u8Actual) < 1e9 and
    abs(imuAx1) < 1e9 and abs(imuAz1) < 1e9 and abs(imuAx2) < 1e9 and abs(imuAz2) < 1e9 and
    abs(primaryTrackingError) < 1e9 and abs(formationErrorActual) < 1e9);

algorithm
  when sample(0, Ts) then
    syncTime := time;
    syncX1 := x1;
    syncZ1 := z1;
    syncVx1 := vx1;
    syncVz1 := vz1;
    syncX2 := x2;
    syncZ2 := z2;
    syncVx2 := vx2;
    syncVz2 := vz2;
    syncFsurge1Cmd := Fsurge1Cmd;
    syncFheave1Cmd := Fheave1Cmd;
    syncFsurge2Cmd := Fsurge2Cmd;
    syncFheave2Cmd := Fheave2Cmd;
    syncU1Actual := u1Actual;
    syncU2Actual := u2Actual;
    syncU3Actual := u3Actual;
    syncU4Actual := u4Actual;
    syncU5Actual := u5Actual;
    syncU6Actual := u6Actual;
    syncU7Actual := u7Actual;
    syncU8Actual := u8Actual;
    syncPressureDepth1 := pressureDepth1;
    syncPressureDepth2 := pressureDepth2;
    syncDvlVx1 := dvlVx1;
    syncDvlVz1 := dvlVz1;
    syncDvlVx2 := dvlVx2;
    syncDvlVz2 := dvlVz2;
    syncImuAx1 := imuAx1;
    syncImuAz1 := imuAz1;
    syncImuAx2 := imuAx2;
    syncImuAz2 := imuAz2;
    syncPeer1X := lastPeer1X;
    syncPeer1Z := lastPeer1Z;
    syncPeer1Time := lastPeer1Time;
    syncPeer2X := lastPeer2X;
    syncPeer2Z := lastPeer2Z;
    syncPeer2Time := lastPeer2Time;
    syncFormationError := formationErrorActual;
    syncPrimaryError := primaryTrackingError;

    if not disturbanceActive then
      lastPeer2X := peer2DelayedX;
      lastPeer2Z := peer2DelayedZ;
      lastPeer2VX := peer2DelayedVX;
      lastPeer2VZ := peer2DelayedVZ;
      lastPeer2Time := max(time - modemDelay, 0.0);

      lastPeer1X := peer1DelayedX;
      lastPeer1Z := peer1DelayedZ;
      lastPeer1VX := peer1DelayedVX;
      lastPeer1VZ := peer1DelayedVZ;
      lastPeer1Time := max(time - modemDelay, 0.0);
    end if;
  end when;

  when time >= dropEnd then
    degradedFormationError := formationErrorActual;
    degradedPrimaryError := primaryTrackingError;
  end when;

  when time >= recoverTime then
    recoveredFormationError := formationErrorActual;
    recoveredPrimaryError := primaryTrackingError;
  end when;

  annotation (experiment(StopTime=14, Tolerance=1e-4));
end MarinePairResilientD;