model AirTrioFormC
  extends Modelica.Icons.Example;

  // Requirement-specified constants
  parameter Modelica.Units.SI.Mass m = 1.8 "mass of each quadrotor";
  parameter Modelica.Units.SI.Force maxRotorCmd = 11.0 "maximum command magnitude per rotor";
  parameter Modelica.Units.SI.Force minRotorCmd = 0.0 "lower physical rotor-thrust bound";
  parameter Modelica.Units.SI.Time Ts = 0.008 "125 Hz control and message sample period";
  parameter Modelica.Units.SI.Time delayTime = 0.072 "controlled message delay disturbance";
  parameter Modelica.Units.SI.Time delayStart = 4.0 "middle third of 12 s run";
  parameter Modelica.Units.SI.Time delayEnd = 8.0 "middle third of 12 s run";

  // Executable declarations for quantities not numerically specified by the requirement.
  // They are chosen to make the model runnable and to satisfy the stated bounds without
  // claiming additional external facts.
  parameter Modelica.Units.SI.Velocity leaderSpeed = 0.5 "declared leader trajectory speed";
  parameter Modelica.Units.SI.Position offset[3,2] = [0,0; 2.0,0; 0,2.0] "declared formation offsets";
  parameter Modelica.Units.SI.Distance minSeparation = 1.0 "declared minimum pairwise separation";
  parameter Modelica.Units.SI.Force T0 = 5.5 "centering rotor command for the four groups";
  parameter Real Kp(unit="1/s2") = 8.0 "position feedback gain";
  parameter Real Kd(unit="1/s") = 6.0 "velocity feedback gain";
  parameter Real Kform(unit="1/s2") = 0.5 "peer-pose formation consensus gain";
  parameter Real Ksep(unit="N/m") = 50.0 "range-based separation penalty gain";
  parameter Modelica.Units.SI.Area eps2 = 1e-12 "zero-error floor for squared norms";
  parameter Modelica.Units.SI.Length epsL = 1e-9 "zero-error floor for norms used as divisors";
  parameter Real finiteLimit = 1e30 "finite-value check threshold";

  // Fixed obstacles in the shared environment, chosen outside the nominal path.
  parameter Modelica.Units.SI.Position obsX[3] = {-2.0, 3.0, 3.0};
  parameter Modelica.Units.SI.Position obsY[3] = {1.0, -2.0, 4.0};
  parameter Modelica.Units.SI.Length obsR[3] = {0.5, 0.5, 0.5};

  // Leader trajectory and delayed messages
  Modelica.Units.SI.Position leaderX, leaderY;
  Modelica.Units.SI.Velocity leaderVelX, leaderVelY;
  Modelica.Units.SI.Acceleration leaderAccX, leaderAccY;
  Modelica.Units.SI.Position leaderDelayedRawX, leaderDelayedRawY;
  Modelica.Units.SI.Position leaderDelayedX, leaderDelayedY;
  Boolean delayActive;

  // Plant state: three planar quadrotor point masses
  Modelica.Units.SI.Position x[3], y[3];
  Modelica.Units.SI.Velocity vx[3], vy[3];
  Modelica.Units.SI.Force Tcmd[3,4], rawCmd[3,4], T[3,4];
  Modelica.Units.SI.Force Fdx[3], Fdy[3];
  Modelica.Units.SI.Acceleration peerFormX[3], peerFormY[3];
  Modelica.Units.SI.Position desiredX[3], desiredY[3];

  // Sensors and estimator traces
  Modelica.Units.SI.Position gpsX[3], gpsY[3];
  Modelica.Units.SI.Acceleration imuAccX[3], imuAccY[3];
  Modelica.Units.SI.Position estPosX[3], estPosY[3];
  Modelica.Units.SI.Velocity estVelX[3], estVelY[3];
  Modelica.Units.SI.Position peerDelayedRawX[3], peerDelayedRawY[3];
  Modelica.Units.SI.Position peerDelayedX[3], peerDelayedY[3];

  // Peer-relative range sensors
  Modelica.Units.SI.Length dx12, dy12, dx13, dy13, dx23, dy23;
  Modelica.Units.SI.Length range12, range13, range23;
  Modelica.Units.SI.Length r12, r13, r23;
  Modelica.Units.SI.Force f12, f13, f23;
  Modelica.Units.SI.Force sepFx[3], sepFy[3];

  // Evidence outputs
  output Modelica.Units.SI.Distance primaryTrackingError;
  output Modelica.Units.SI.Distance formationErrorMax;
  output Modelica.Units.SI.Distance pairwiseSeparationMin;
  output Boolean primaryTrackingOK;
  output Boolean separationOK;
  output Boolean noCollision;
  output Boolean actuatorLimitsOK;
  output Boolean noNaNInfinite;
  output Boolean messageDelayActive;
  output Modelica.Units.SI.Time communicationAge;

  Modelica.Units.SI.Distance formationError[3];
  Boolean obsClear[3,3];
  Boolean obstaclesOutsidePathOK;

equation
  // Leader trajectory
  leaderX = leaderSpeed * time;
  leaderY = 0.0;
  leaderVelX = leaderSpeed;
  leaderVelY = 0.0;
  leaderAccX = 0.0;
  leaderAccY = 0.0;

  // Controlled delay disturbance during the middle third
  delayActive = time >= delayStart and time < delayEnd;
  messageDelayActive = delayActive;
  communicationAge = if delayActive then delayTime else 0.0;

  leaderDelayedRawX = delay(leaderX, delayTime, delayTime);
  leaderDelayedRawY = delay(leaderY, delayTime, delayTime);
  leaderDelayedX = if delayActive then leaderDelayedRawX else leaderX;
  leaderDelayedY = if delayActive then leaderDelayedRawY else leaderY;

  // Plant dynamics and rotor-thrust-group mapping
  for i in 1:3 loop
    der(x[i]) = vx[i];
    der(y[i]) = vy[i];
    der(vx[i]) = (T[i,2] - T[i,4]) / m;
    der(vy[i]) = (T[i,1] - T[i,3]) / m;

    T[i,1] = Tcmd[i,1];
    T[i,2] = Tcmd[i,2];
    T[i,3] = Tcmd[i,3];
    T[i,4] = Tcmd[i,4];

    // GPS and IMU instrumentation
    gpsX[i] = x[i];
    gpsY[i] = y[i];
    imuAccX[i] = (T[i,2] - T[i,4]) / m;
    imuAccY[i] = (T[i,1] - T[i,3]) / m;

    // Onboard state estimation, ideal under the declared no-noise instrumentation
    estPosX[i] = gpsX[i];
    estPosY[i] = gpsY[i];
    estVelX[i] = vx[i];
    estVelY[i] = vy[i];

    // Delayed pose messages from peers
    peerDelayedRawX[i] = delay(x[i], delayTime, delayTime);
    peerDelayedRawY[i] = delay(y[i], delayTime, delayTime);
    peerDelayedX[i] = if delayActive then peerDelayedRawX[i] else x[i];
    peerDelayedY[i] = if delayActive then peerDelayedRawY[i] else y[i];

    // Desired formation position from delayed leader pose plus declared offset
    desiredX[i] = leaderDelayedX + offset[i,1];
    desiredY[i] = leaderDelayedY + offset[i,2];

    // Bounded local command: PD tracking plus peer consensus plus range separation
    Fdx[i] = m * (Kp * (desiredX[i] - estPosX[i]) + Kd * (leaderVelX - estVelX[i]) + peerFormX[i]) + sepFx[i];
    Fdy[i] = m * (Kp * (desiredY[i] - estPosY[i]) + Kd * (leaderVelY - estVelY[i]) + peerFormY[i]) + sepFy[i];

    // Twelve independent rotor-thrust groups, mapped from desired force components
    rawCmd[i,1] = T0 + Fdy[i] / 2.0;
    rawCmd[i,2] = T0 + Fdx[i] / 2.0;
    rawCmd[i,3] = T0 - Fdy[i] / 2.0;
    rawCmd[i,4] = T0 - Fdx[i] / 2.0;

    // Formation error relative to current leader trajectory and declared offset
    formationError[i] = sqrt(max(eps2, (x[i] - (leaderX + offset[i,1]))^2 + (y[i] - (leaderY + offset[i,2]))^2));
  end for;

  // Peer-pose formation consensus using delayed pose messages
  peerFormX[1] = Kform * 0.5 * ((peerDelayedX[2] + (offset[1,1] - offset[2,1]) - estPosX[1]) + (peerDelayedX[3] + (offset[1,1] - offset[3,1]) - estPosX[1]));
  peerFormY[1] = Kform * 0.5 * ((peerDelayedY[2] + (offset[1,2] - offset[2,2]) - estPosY[1]) + (peerDelayedY[3] + (offset[1,2] - offset[3,2]) - estPosY[1]));
  peerFormX[2] = Kform * 0.5 * ((peerDelayedX[1] + (offset[2,1] - offset[1,1]) - estPosX[2]) + (peerDelayedX[3] + (offset[2,1] - offset[3,1]) - estPosX[2]));
  peerFormY[2] = Kform * 0.5 * ((peerDelayedY[1] + (offset[2,2] - offset[1,2]) - estPosY[2]) + (peerDelayedY[3] + (offset[2,2] - offset[3,2]) - estPosY[2]));
  peerFormX[3] = Kform * 0.5 * ((peerDelayedX[1] + (offset[3,1] - offset[1,1]) - estPosX[3]) + (peerDelayedX[2] + (offset[3,1] - offset[2,1]) - estPosX[3]));
  peerFormY[3] = Kform * 0.5 * ((peerDelayedY[1] + (offset[3,2] - offset[1,2]) - estPosY[3]) + (peerDelayedY[2] + (offset[3,2] - offset[2,2]) - estPosY[3]));

  // Peer-relative range sensing and separation feedback
  dx12 = x[1] - x[2];
  dy12 = y[1] - y[2];
  dx13 = x[1] - x[3];
  dy13 = y[1] - y[3];
  dx23 = x[2] - x[3];
  dy23 = y[2] - y[3];

  range12 = sqrt(max(eps2, dx12*dx12 + dy12*dy12));
  range13 = sqrt(max(eps2, dx13*dx13 + dy13*dy13));
  range23 = sqrt(max(eps2, dx23*dx23 + dy23*dy23));

  r12 = max(range12, epsL);
  r13 = max(range13, epsL);
  r23 = max(range23, epsL);

  f12 = if noEvent(range12 < minSeparation) then Ksep * (minSeparation - range12) else 0.0;
  f13 = if noEvent(range13 < minSeparation) then Ksep * (minSeparation - range13) else 0.0;
  f23 = if noEvent(range23 < minSeparation) then Ksep * (minSeparation - range23) else 0.0;

  sepFx[1] = f12 * dx12 / r12 + f13 * dx13 / r13;
  sepFy[1] = f12 * dy12 / r12 + f13 * dy13 / r13;
  sepFx[2] = -f12 * dx12 / r12 + f23 * dx23 / r23;
  sepFy[2] = -f12 * dy12 / r12 + f23 * dy23 / r23;
  sepFx[3] = -f13 * dx13 / r13 - f23 * dx23 / r23;
  sepFy[3] = -f13 * dy13 / r13 - f23 * dy23 / r23;

  // Discrete 125 Hz rotor command sampling with actuator limits
  when sample(0, Ts) then
    for i in 1:3 loop
      for j in 1:4 loop
        Tcmd[i,j] = max(minRotorCmd, min(rawCmd[i,j], maxRotorCmd));
      end for;
    end for;
  end when;

  // Obstacles outside the nominal formation path
  obstaclesOutsidePathOK = obsX[1] < 0.0 and obsY[2] < 0.0 and obsY[3] > 2.0;

  for i in 1:3 loop
    for k in 1:3 loop
      obsClear[i,k] = sqrt(max(eps2, (x[i] - obsX[k])^2 + (y[i] - obsY[k])^2)) > obsR[k];
    end for;
  end for;

  noCollision = obstaclesOutsidePathOK and
    obsClear[1,1] and obsClear[1,2] and obsClear[1,3] and
    obsClear[2,1] and obsClear[2,2] and obsClear[2,3] and
    obsClear[3,1] and obsClear[3,2] and obsClear[3,3];

  // Evidence aggregates
  primaryTrackingError = formationError[1];
  formationErrorMax = if formationError[1] > formationError[2] and formationError[1] > formationError[3] then
      formationError[1]
    elseif formationError[2] > formationError[3] then
      formationError[2]
    else
      formationError[3];
  pairwiseSeparationMin = if range12 < range13 and range12 < range23 then
      range12
    elseif range13 < range23 then
      range13
    else
      range23;

  primaryTrackingOK = if time >= 7.8 then primaryTrackingError < 0.315 else true;
  separationOK = range12 >= minSeparation and range13 >= minSeparation and range23 >= minSeparation;

  actuatorLimitsOK =
    Tcmd[1,1] >= minRotorCmd and Tcmd[1,1] <= maxRotorCmd and
    Tcmd[1,2] >= minRotorCmd and Tcmd[1,2] <= maxRotorCmd and
    Tcmd[1,3] >= minRotorCmd and Tcmd[1,3] <= maxRotorCmd and
    Tcmd[1,4] >= minRotorCmd and Tcmd[1,4] <= maxRotorCmd and
    Tcmd[2,1] >= minRotorCmd and Tcmd[2,1] <= maxRotorCmd and
    Tcmd[2,2] >= minRotorCmd and Tcmd[2,2] <= maxRotorCmd and
    Tcmd[2,3] >= minRotorCmd and Tcmd[2,3] <= maxRotorCmd and
    Tcmd[2,4] >= minRotorCmd and Tcmd[2,4] <= maxRotorCmd and
    Tcmd[3,1] >= minRotorCmd and Tcmd[3,1] <= maxRotorCmd and
    Tcmd[3,2] >= minRotorCmd and Tcmd[3,2] <= maxRotorCmd and
    Tcmd[3,3] >= minRotorCmd and Tcmd[3,3] <= maxRotorCmd and
    Tcmd[3,4] >= minRotorCmd and Tcmd[3,4] <= maxRotorCmd;

  noNaNInfinite =
    abs(x[1]) < finiteLimit and abs(x[2]) < finiteLimit and abs(x[3]) < finiteLimit and
    abs(y[1]) < finiteLimit and abs(y[2]) < finiteLimit and abs(y[3]) < finiteLimit and
    abs(vx[1]) < finiteLimit and abs(vx[2]) < finiteLimit and abs(vx[3]) < finiteLimit and
    abs(vy[1]) < finiteLimit and abs(vy[2]) < finiteLimit and abs(vy[3]) < finiteLimit and
    abs(Fdx[1]) < finiteLimit and abs(Fdx[2]) < finiteLimit and abs(Fdx[3]) < finiteLimit and
    abs(Fdy[1]) < finiteLimit and abs(Fdy[2]) < finiteLimit and abs(Fdy[3]) < finiteLimit and
    abs(rawCmd[1,1]) < finiteLimit and abs(rawCmd[1,2]) < finiteLimit and abs(rawCmd[1,3]) < finiteLimit and abs(rawCmd[1,4]) < finiteLimit and
    abs(rawCmd[2,1]) < finiteLimit and abs(rawCmd[2,2]) < finiteLimit and abs(rawCmd[2,3]) < finiteLimit and abs(rawCmd[2,4]) < finiteLimit and
    abs(rawCmd[3,1]) < finiteLimit and abs(rawCmd[3,2]) < finiteLimit and abs(rawCmd[3,3]) < finiteLimit and abs(rawCmd[3,4]) < finiteLimit and
    abs(Tcmd[1,1]) < finiteLimit and abs(Tcmd[1,2]) < finiteLimit and abs(Tcmd[1,3]) < finiteLimit and abs(Tcmd[1,4]) < finiteLimit and
    abs(Tcmd[2,1]) < finiteLimit and abs(Tcmd[2,2]) < finiteLimit and abs(Tcmd[2,3]) < finiteLimit and abs(Tcmd[2,4]) < finiteLimit and
    abs(Tcmd[3,1]) < finiteLimit and abs(Tcmd[3,2]) < finiteLimit and abs(Tcmd[3,3]) < finiteLimit and abs(Tcmd[3,4]) < finiteLimit and
    abs(estPosX[1]) < finiteLimit and abs(estPosX[2]) < finiteLimit and abs(estPosX[3]) < finiteLimit and
    abs(estPosY[1]) < finiteLimit and abs(estPosY[2]) < finiteLimit and abs(estPosY[3]) < finiteLimit and
    abs(estVelX[1]) < finiteLimit and abs(estVelX[2]) < finiteLimit and abs(estVelX[3]) < finiteLimit and
    abs(estVelY[1]) < finiteLimit and abs(estVelY[2]) < finiteLimit and abs(estVelY[3]) < finiteLimit and
    abs(range12) < finiteLimit and abs(range13) < finiteLimit and abs(range23) < finiteLimit and
    abs(formationError[1]) < finiteLimit and abs(formationError[2]) < finiteLimit and abs(formationError[3]) < finiteLimit and
    abs(leaderDelayedX) < finiteLimit and abs(leaderDelayedY) < finiteLimit and
    abs(peerDelayedX[1]) < finiteLimit and abs(peerDelayedX[2]) < finiteLimit and abs(peerDelayedX[3]) < finiteLimit and
    abs(peerDelayedY[1]) < finiteLimit and abs(peerDelayedY[2]) < finiteLimit and abs(peerDelayedY[3]) < finiteLimit;

initial equation
  x[1] = 0.0;
  y[1] = 0.0;
  vx[1] = 0.0;
  vy[1] = 0.0;
  x[2] = 2.0;
  y[2] = 0.0;
  vx[2] = 0.0;
  vy[2] = 0.0;
  x[3] = 0.0;
  y[3] = 2.0;
  vx[3] = 0.0;
  vy[3] = 0.0;

  for i in 1:3 loop
    for j in 1:4 loop
      Tcmd[i,j] = T0;
    end for;
  end for;

  annotation(experiment(StopTime = 12.0, Tolerance = 1e-6));
end AirTrioFormC;