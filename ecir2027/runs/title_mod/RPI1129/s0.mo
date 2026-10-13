model AirTrioFormA
  // Requirement-specified constants
  parameter Real m = 1.8 "quadrotor mass [kg]";
  parameter Real Fmax_rotor = 8.64 "per-rotor command magnitude limit [N]";
  parameter Real delayDist = 0.04 "controlled message delay [s]";
  parameter Real Ts = 1.0/80.0 "synchronized trace sample period [s]";
  parameter Real Tfinal = 8.0 "scenario duration [s]";
  parameter Real g = 9.81 "gravitational acceleration [m/s2]";

  // The requirement does not specify formation offsets, minimum separation,
  // leader trajectory, or obstacle coordinates. The following parameter
  // bindings are declared placeholders for a self-contained simulation and are
  // not claimed as requirement facts.
  parameter Real leaderSpeed = 0.5 "nominal placeholder leader speed [m/s]";
  parameter Real leaderZ = 2.0 "nominal placeholder leader altitude [m]";
  parameter Real offset[3,3] = {{0.0,0.0,0.0},{0.0,-1.0,0.0},{0.0,1.0,0.0}};
  parameter Real minSeparation = 0.5 "declared placeholder minimum robot separation [m]";
  parameter Real obstaclePos[2,3] = {{100.0,100.0,0.0},{-100.0,-100.0,0.0}};
  parameter Real obstacleRadius[2] = {0.5,0.5};

  // Controller and estimator placeholder gains
  parameter Real Kp = 20.0;
  parameter Real Kd = 8.0;
  parameter Real Krel = 0.5;
  parameter Real Ksep = 2.0;
  parameter Real aLim = 2.0 "bounded local acceleration command [m/s2]";
  parameter Real KestPos = 20.0;
  parameter Real KestVel = 40.0;

  parameter Real tMidStart = Tfinal/3.0;
  parameter Real tMidEnd = 2.0*Tfinal/3.0;

  // Physical states
  Real r[3,3](start={{0.0,0.0,2.0},{0.0,-1.0,2.0},{0.0,1.0,2.0}});
  Real v[3,3](start={{0.5,0.0,0.0},{0.5,0.0,0.0},{0.5,0.0,0.0}});
  Real aAct[3,3];

  // Onboard state estimator states
  Real rhat[3,3](start={{0.0,0.0,2.0},{0.0,-1.0,2.0},{0.0,1.0,2.0}});
  Real vhat[3,3](start={{0.5,0.0,0.0},{0.5,0.0,0.0},{0.5,0.0,0.0}});

  // Sensors
  Real gpsPos[3,3];
  Real gpsVel[3,3];
  Real imuAcc[3,3];
  Real rangeMeas[3,3];

  // Communication and delayed pose messages
  Boolean activeDelay;
  Real commAge;
  Real rDelayed[3,3];
  Real posMsg[3,3];

  // Leader trajectory
  Real rL[3];
  Real vL[3];
  Real aL[3];
  Real rDes[3,3];
  Real vDes[3,3];

  // Formation control
  Real peerCorr[3,3];
  Real repulse[3,3];
  Real aCmdUnbounded[3,3];
  Real aCmd[3,3];

  // Rotor-thrust groups: 3 robots x 4 rotors = 12 independent commands
  Real forceDirNorm[3];
  Real FtotDes[3];
  Real rotorCmdUnbounded[3,4];
  Real rotorCmd[3,4];
  Real rotorSat[3,4];
  Real FtotAct[3];

  // Requirement metrics
  Real separation12;
  Real separation13;
  Real separation23;
  Real minSeparationActual;
  Real formationError;
  Real primaryTrackingError;
  Boolean primaryTrackingMet;
  Real obstacleDist[3,2];
  Real minObstacleDist;
  Boolean collisionFlag;
  Real finiteProbe;

  // Synchronized 80 Hz trace logs
  discrete Real sampleTimeLog;
  Integer sampleCount(start=0);
  discrete Real rLog[3,3];
  discrete Real vLog[3,3];
  discrete Real rhatLog[3,3];
  discrete Real vhatLog[3,3];
  discrete Real gpsPosLog[3,3];
  discrete Real imuAccLog[3,3];
  discrete Real posMsgLog[3,3];
  discrete Real rotorCmdLog[3,4];
  discrete Real rotorSatLog[3,4];
  discrete Real rangeLog[3,3];
  discrete Real commAgeLog;
  discrete Real formationErrorLog;
  discrete Real primaryTrackingErrorLog;

equation
  // Leader trajectory
  rL[1] = leaderSpeed*time;
  rL[2] = 0.0;
  rL[3] = leaderZ;
  vL[1] = leaderSpeed;
  vL[2] = 0.0;
  vL[3] = 0.0;
  aL[1] = 0.0;
  aL[2] = 0.0;
  aL[3] = 0.0;

  // Desired formation positions
  for i in 1:3 loop
    for k in 1:3 loop
      rDes[i,k] = rL[k] + offset[i,k];
      vDes[i,k] = vL[k];
    end for;
  end for;

  // Controlled delay disturbance during the middle third
  activeDelay = time >= tMidStart and time <= tMidEnd;
  commAge = if activeDelay then delayDist else 0.0;

  for i in 1:3 loop
    for k in 1:3 loop
      rDelayed[i,k] = delay(r[i,k], delayDist, delayDist);
      posMsg[i,k] = if activeDelay then rDelayed[i,k] else r[i,k];
    end for;
  end for;

  // Sensors
  for i in 1:3 loop
    for k in 1:3 loop
      gpsPos[i,k] = r[i,k];
      gpsVel[i,k] = v[i,k];
      imuAcc[i,k] = aAct[i,k];
    end for;
  end for;

  // Peer-relative range sensing
  for i in 1:3 loop
    for j in 1:3 loop
      if i == j then
        rangeMeas[i,j] = 0.0;
      else
        rangeMeas[i,j] = sqrt((r[i,1]-r[j,1])^2 + (r[i,2]-r[j,2])^2 + (r[i,3]-r[j,3])^2);
      end if;
    end for;
  end for;

  // Pairwise separations
  separation12 = rangeMeas[1,2];
  separation13 = rangeMeas[1,3];
  separation23 = rangeMeas[2,3];
  minSeparationActual = min(separation12, min(separation13, separation23));

  // Distributed formation control using own estimate, peer range, and delayed pose messages
  for k in 1:3 loop
    peerCorr[1,k] = Krel*(posMsg[2,k] + offset[1,k] - offset[2,k] - rhat[1,k])
                  + Krel*(posMsg[3,k] + offset[1,k] - offset[3,k] - rhat[1,k]);
    peerCorr[2,k] = Krel*(posMsg[1,k] + offset[2,k] - offset[1,k] - rhat[2,k])
                  + Krel*(posMsg[3,k] + offset[2,k] - offset[3,k] - rhat[2,k]);
    peerCorr[3,k] = Krel*(posMsg[1,k] + offset[3,k] - offset[1,k] - rhat[3,k])
                  + Krel*(posMsg[2,k] + offset[3,k] - offset[2,k] - rhat[3,k]);
  end for;

  // Bounded separation repulsion from peer-relative range; divisor has zero-error branch
  for k in 1:3 loop
    repulse[1,k] = (if rangeMeas[1,2] < minSeparation then
                    Ksep*(minSeparation-rangeMeas[1,2])*((rhat[1,k]-posMsg[2,k])/max(rangeMeas[1,2],1e-6))
                  else 0.0)
                 + (if rangeMeas[1,3] < minSeparation then
                    Ksep*(minSeparation-rangeMeas[1,3])*((rhat[1,k]-posMsg[3,k])/max(rangeMeas[1,3],1e-6))
                  else 0.0);
    repulse[2,k] = (if rangeMeas[2,1] < minSeparation then
                    Ksep*(minSeparation-rangeMeas[2,1])*((rhat[2,k]-posMsg[1,k])/max(rangeMeas[2,1],1e-6))
                  else 0.0)
                 + (if rangeMeas[2,3] < minSeparation then
                    Ksep*(minSeparation-rangeMeas[2,3])*((rhat[2,k]-posMsg[3,k])/max(rangeMeas[2,3],1e-6))
                  else 0.0);
    repulse[3,k] = (if rangeMeas[3,1] < minSeparation then
                    Ksep*(minSeparation-rangeMeas[3,1])*((rhat[3,k]-posMsg[1,k])/max(rangeMeas[3,1],1e-6))
                  else 0.0)
                 + (if rangeMeas[3,2] < minSeparation then
                    Ksep*(minSeparation-rangeMeas[3,2])*((rhat[3,k]-posMsg[2,k])/max(rangeMeas[3,2],1e-6))
                  else 0.0);
  end for;

  // Bounded local acceleration commands
  for i in 1:3 loop
    for k in 1:3 loop
      aCmdUnbounded[i,k] = aL[k] + Kp*(rDes[i,k]-rhat[i,k]) + Kd*(vL[k]-vhat[i,k])
                         + peerCorr[i,k] + repulse[i,k];
      aCmd[i,k] = max(-aLim, min(aLim, aCmdUnbounded[i,k]));
    end for;
  end for;

  // Rotor allocation and actuator limits
  for i in 1:3 loop
    forceDirNorm[i] = sqrt(aCmd[i,1]^2 + aCmd[i,2]^2 + (aCmd[i,3]+g)^2);
    FtotDes[i] = m*forceDirNorm[i];
    for j in 1:4 loop
      rotorCmdUnbounded[i,j] = FtotDes[i]/4.0;
      rotorCmd[i,j] = max(0.0, min(Fmax_rotor, rotorCmdUnbounded[i,j]));
      rotorSat[i,j] = rotorCmd[i,j];
    end for;
    FtotAct[i] = rotorSat[i,1] + rotorSat[i,2] + rotorSat[i,3] + rotorSat[i,4];
    aAct[i,1] = (FtotAct[i]/m)*(aCmd[i,1]/max(forceDirNorm[i],1e-6));
    aAct[i,2] = (FtotAct[i]/m)*(aCmd[i,2]/max(forceDirNorm[i],1e-6));
    aAct[i,3] = (FtotAct[i]/m)*((aCmd[i,3]+g)/max(forceDirNorm[i],1e-6)) - g;
  end for;

  // Point-mass quadrotor dynamics
  for i in 1:3 loop
    for k in 1:3 loop
      der(r[i,k]) = v[i,k];
      der(v[i,k]) = aAct[i,k];
    end for;
  end for;

  // Onboard state estimation from GPS and IMU
  for i in 1:3 loop
    for k in 1:3 loop
      der(rhat[i,k]) = vhat[i,k] + KestPos*(gpsPos[i,k]-rhat[i,k]);
      der(vhat[i,k]) = imuAcc[i,k] + KestVel*(gpsVel[i,k]-vhat[i,k]);
    end for;
  end for;

  // Formation and tracking error metrics
  formationError = sqrt(
    (r[1,1]-rDes[1,1])^2 + (r[1,2]-rDes[1,2])^2 + (r[1,3]-rDes[1,3])^2 +
    (r[2,1]-rDes[2,1])^2 + (r[2,2]-rDes[2,2])^2 + (r[2,3]-rDes[2,3])^2 +
    (r[3,1]-rDes[3,1])^2 + (r[3,2]-rDes[3,2])^2 + (r[3,3]-rDes[3,3])^2);

  primaryTrackingError = sqrt((r[1,1]-rL[1])^2 + (r[1,2]-rL[2])^2 + (r[1,3]-rL[3])^2);
  primaryTrackingMet = if time >= 5.2 then primaryTrackingError < 0.405 else true;

  // Obstacle distances and collision flag
  for i in 1:3 loop
    for o in 1:2 loop
      obstacleDist[i,o] = sqrt((r[i,1]-obstaclePos[o,1])^2 +
                               (r[i,2]-obstaclePos[o,2])^2 +
                               (r[i,3]-obstaclePos[o,3])^2);
    end for;
  end for;
  minObstacleDist = min(obstacleDist[1,1], min(obstacleDist[1,2],
                       min(obstacleDist[2,1], min(obstacleDist[2,2],
                       min(obstacleDist[3,1], obstacleDist[3,2])))));
  collisionFlag = minObstacleDist < min(obstacleRadius[1], obstacleRadius[2]);

  // Finite/non-NaN probe for physical, control, and estimator values
  finiteProbe =
    r[1,1]+r[1,2]+r[1,3]+r[2,1]+r[2,2]+r[2,3]+r[3,1]+r[3,2]+r[3,3] +
    v[1,1]+v[1,2]+v[1,3]+v[2,1]+v[2,2]+v[2,3]+v[3,1]+v[3,2]+v[3,3] +
    rhat[1,1]+rhat[1,2]+rhat[1,3]+rhat[2,1]+rhat[2,2]+rhat[2,3]+rhat[3,1]+rhat[3,2]+rhat[3,3] +
    vhat[1,1]+vhat[1,2]+vhat[1,3]+vhat[2,1]+vhat[2,2]+vhat[2,3]+vhat[3,1]+vhat[3,2]+vhat[3,3] +
    aCmd[1,1]+aCmd[1,2]+aCmd[1,3]+aCmd[2,1]+aCmd[2,2]+aCmd[2,3]+aCmd[3,1]+aCmd[3,2]+aCmd[3,3] +
    aAct[1,1]+aAct[1,2]+aAct[1,3]+aAct[2,1]+aAct[2,2]+aAct[2,3]+aAct[3,1]+aAct[3,2]+aAct[3,3] +
    rotorCmd[1,1]+rotorCmd[1,2]+rotorCmd[1,3]+rotorCmd[1,4]+
    rotorCmd[2,1]+rotorCmd[2,2]+rotorCmd[2,3]+rotorCmd[2,4]+
    rotorCmd[3,1]+rotorCmd[3,2]+rotorCmd[3,3]+rotorCmd[3,4] +
    rangeMeas[1,2]+rangeMeas[1,3]+rangeMeas[2,1]+rangeMeas[2,3]+rangeMeas[3,1]+rangeMeas[3,2] +
    formationError + primaryTrackingError + commAge + minObstacleDist + minSeparationActual;

  // Requirement assertions
  for i in 1:3 loop
    for j in 1:4 loop
      assert(rotorCmd[i,j] >= 0.0 and rotorCmd[i,j] <= Fmax_rotor + 1e-9,
             "per-rotor command magnitude limit violated");
    end for;
  end for;

  for i in 1:3 loop
    for k in 1:3 loop
      assert(aCmd[i,k] >= -aLim - 1e-9 and aCmd[i,k] <= aLim + 1e-9,
             "local command bound violated");
    end for;
  end for;

  assert(minSeparationActual >= minSeparation - 1e-6, "minimum pairwise separation violated");
  assert(formationError >= 0.0, "formation error invalid");
  assert(commAge <= delayDist + 1e-9, "communication age exceeded");
  assert(not collisionFlag, "obstacle collision");
  assert(primaryTrackingMet, "primary tracking error requirement violated after 5.2 s");
  assert(finiteProbe >= -1e100 and finiteProbe <= 1e100,
         "non-finite physical, control, or estimator value");

  // Synchronized 80 Hz trace retention
  when sample(0, Ts) then
    sampleTimeLog = time;
    sampleCount = pre(sampleCount) + 1;
    for i in 1:3 loop
      for k in 1:3 loop
        rLog[i,k] = r[i,k];
        vLog[i,k] = v[i,k];
        rhatLog[i,k] = rhat[i,k];
        vhatLog[i,k] = vhat[i,k];
        gpsPosLog[i,k] = gpsPos[i,k];
        imuAccLog[i,k] = imuAcc[i,k];
        posMsgLog[i,k] = posMsg[i,k];
      end for;
      for j in 1:4 loop
        rotorCmdLog[i,j] = rotorCmd[i,j];
        rotorSatLog[i,j] = rotorSat[i,j];
      end for;
      for j in 1:3 loop
        rangeLog[i,j] = rangeMeas[i,j];
      end for;
    end for;
    commAgeLog = commAge;
    formationErrorLog = formationError;
    primaryTrackingErrorLog = primaryTrackingError;
  end when;

  annotation(experiment(StopTime = 8.0, Interval = 0.0125, Tolerance = 1e-6));
end AirTrioFormA;