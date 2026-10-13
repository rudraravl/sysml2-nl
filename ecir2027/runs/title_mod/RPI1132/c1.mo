model AirTrioFormD
  import SI = Modelica.Units.SI;
  import Modelica.Constants.g_n;

  parameter SI.Mass mQuad = 1.8 "mass of each quadrotor";
  parameter Real rotorMax = 12.0 "per-rotor thrust limit (N)";
  parameter Real rotorMin = 0.0 "per-rotor thrust minimum (N)";
  parameter SI.Time actTau = 0.02 "rotor-thrust actuator time constant";
  parameter SI.Frequency controlRate = 200.0 "controller and trace rate";
  parameter SI.Time Ts = 1.0/controlRate;
  parameter SI.Time Tfinal = 14.0;
  parameter SI.Time messageDelay = 0.08;
  parameter Real amax = 12.0 "local acceleration command bound";
  parameter Real formationBound = 2.0 "formation term bound";

  parameter Real kp = 20.0;
  parameter Real kd = 8.0;
  parameter Real kform = 5.0;
  parameter Real obsLp = 12.0;
  parameter Real obsLv = 64.0;

  parameter SI.Position leaderX0 = 0.0;
  parameter SI.Position leaderY0 = 0.0;
  parameter SI.Position leaderZ0 = 3.0;
  parameter SI.Velocity leaderVx = 0.10;
  parameter SI.Velocity leaderVy = 0.0;
  parameter SI.Velocity leaderVz = 0.0;

  parameter SI.Position offset[3,3] = {{0.0,0.0,0.0},{1.5,1.0,0.0},{-1.5,1.0,0.0}};
  parameter SI.Position obstacles[2,3] = {{0.7,-3.0,3.0},{0.7,3.0,3.0}};
  parameter SI.Length collisionRadius = 1.0;
  parameter SI.Length minSeparation = 1.0;
  parameter SI.Length trackingThreshold = 0.3;
  parameter SI.Time trackingTime = 9.1;

  parameter Real hoverThrust = mQuad*g_n/4.0;

  Real p[3,3](start={{0.0,0.0,3.0},{1.5,1.0,3.0},{-1.5,1.0,3.0}});
  Real v[3,3](start={{0.10,0.0,0.0},{0.10,0.0,0.0},{0.10,0.0,0.0}});
  Real a[3,3];
  Real F[3,3];

  Real estP[3,3](start={{0.0,0.0,3.0},{1.5,1.0,3.0},{-1.5,1.0,3.0}});
  Real estV[3,3](start={{0.10,0.0,0.0},{0.10,0.0,0.0},{0.10,0.0,0.0}});

  Real pL[3];
  Real vL[3];
  Real aL[3];
  Real pD[3,3];

  Real gpsP[3,3];
  Real imuA[3,3];
  Real range12;
  Real range13;
  Real range23;
  Real delayedP[3,3];
  SI.Time commAge;
  Boolean middleThird;

  discrete Real aDes[3,3](start={{0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0}});
  discrete Real rotorCmd[12](start=fill(0.0,12));
  Real rotorRaw[12](start=fill(0.0,12));
  Real rotor[12];

  Real Traw[3];
  Real dir[3,3];
  Real sumRotor[3];

  SI.Time syncTime(start=0.0);
  discrete Real syncP[3,3](start={{0.0,0.0,3.0},{1.5,1.0,3.0},{-1.5,1.0,3.0}});
  discrete Real syncV[3,3](start={{0.10,0.0,0.0},{0.10,0.0,0.0},{0.10,0.0,0.0}});
  discrete Real syncCmd[12](start=fill(0.0,12));
  discrete Real syncRange[3](start={0.0,0.0,0.0});
  discrete SI.Time syncCommAge(start=0.0);

  Real minPairwiseSeparation;
  Real formationError;
  Real primaryTrackingError;
  Boolean noCollision;
  Boolean actuatorLimitRespected;
  Boolean trackingConverged;
  Real obsDist1;
  Real obsDist2;
  Real minObsDist;
  Real maxCmd;
  Real minCmd;
  Real maxRotor;
  Real minRotor;

protected
  discrete Real eP[3,3];
  discrete Real eV[3,3];
  discrete Real form[3,3];
  discrete Real TrawAlg[3];
  discrete Real TcmdAlg[3];
  discrete Real baseCmd;
  Real delayedPAll[3,3];

equation
  pL[1] = leaderX0 + leaderVx*time;
  pL[2] = leaderY0 + leaderVy*time;
  pL[3] = leaderZ0 + leaderVz*time;
  vL[1] = leaderVx;
  vL[2] = leaderVy;
  vL[3] = leaderVz;
  aL[1] = 0.0;
  aL[2] = 0.0;
  aL[3] = 0.0;

  for i in 1:3 loop
    for k in 1:3 loop
      pD[i,k] = pL[k] + offset[i,k];
    end for;
  end for;

  for i in 1:3 loop
    for k in 1:3 loop
      der(p[i,k]) = v[i,k];
      der(v[i,k]) = a[i,k];
      gpsP[i,k] = p[i,k];
      imuA[i,k] = a[i,k];
    end for;
    a[i,1] = F[i,1]/mQuad;
    a[i,2] = F[i,2]/mQuad;
    a[i,3] = F[i,3]/mQuad - g_n;
  end for;

  for i in 1:3 loop
    Traw[i] = mQuad*sqrt(max(0.0, aDes[i,1]^2 + aDes[i,2]^2 + (aDes[i,3] + g_n)^2));
    if Traw[i] > 1.0e-6 then
      dir[i,1] = mQuad*aDes[i,1]/Traw[i];
      dir[i,2] = mQuad*aDes[i,2]/Traw[i];
      dir[i,3] = mQuad*(aDes[i,3] + g_n)/Traw[i];
    else
      dir[i,1] = 0.0;
      dir[i,2] = 0.0;
      dir[i,3] = 1.0;
    end if;
    sumRotor[i] = rotor[(i-1)*4+1] + rotor[(i-1)*4+2] + rotor[(i-1)*4+3] + rotor[(i-1)*4+4];
    F[i,1] = sumRotor[i]*dir[i,1];
    F[i,2] = sumRotor[i]*dir[i,2];
    F[i,3] = sumRotor[i]*dir[i,3];
  end for;

  for k in 1:12 loop
    der(rotorRaw[k]) = (rotorCmd[k] - rotorRaw[k])/actTau;
    rotor[k] = max(rotorMin, min(rotorMax, rotorRaw[k]));
  end for;

  for i in 1:3 loop
    for k in 1:3 loop
      der(estP[i,k]) = estV[i,k] + obsLp*(gpsP[i,k] - estP[i,k]);
      der(estV[i,k]) = imuA[i,k] + obsLv*(gpsP[i,k] - estP[i,k]);
    end for;
  end for;

  range12 = sqrt(max(0.0, (p[1,1]-p[2,1])^2 + (p[1,2]-p[2,2])^2 + (p[1,3]-p[2,3])^2));
  range13 = sqrt(max(0.0, (p[1,1]-p[3,1])^2 + (p[1,2]-p[3,2])^2 + (p[1,3]-p[3,3])^2));
  range23 = sqrt(max(0.0, (p[2,1]-p[3,1])^2 + (p[2,2]-p[3,2])^2 + (p[2,3]-p[3,3])^2));

  middleThird = time >= Tfinal/3.0 and time <= 2.0*Tfinal/3.0;
  commAge = if middleThird then messageDelay else 0.0;

  for i in 1:3 loop
    for k in 1:3 loop
      delayedPAll[i,k] = delay(p[i,k], messageDelay, messageDelay);
      delayedP[i,k] = if middleThird then delayedPAll[i,k] else p[i,k];
    end for;
  end for;

  formationError = sqrt(max(0.0, (
    ((p[1,1]-p[2,1]) - (offset[1,1]-offset[2,1]))^2 +
    ((p[1,2]-p[2,2]) - (offset[1,2]-offset[2,2]))^2 +
    ((p[1,3]-p[2,3]) - (offset[1,3]-offset[2,3]))^2 +
    ((p[1,1]-p[3,1]) - (offset[1,1]-offset[3,1]))^2 +
    ((p[1,2]-p[3,2]) - (offset[1,2]-offset[3,2]))^2 +
    ((p[1,3]-p[3,3]) - (offset[1,3]-offset[3,3]))^2 +
    ((p[2,1]-p[3,1]) - (offset[2,1]-offset[3,1]))^2 +
    ((p[2,2]-p[3,2]) - (offset[2,2]-offset[3,2]))^2 +
    ((p[2,3]-p[3,3]) - (offset[2,3]-offset[3,3]))^2
    )/3.0));

  primaryTrackingError = sqrt(max(0.0, (p[1,1]-pL[1])^2 + (p[1,2]-pL[2])^2 + (p[1,3]-pL[3])^2));

  minPairwiseSeparation = min(range12, min(range13, range23));

  obsDist1 = min(
    sqrt(max(0.0, (p[1,1]-obstacles[1,1])^2 + (p[1,2]-obstacles[1,2])^2 + (p[1,3]-obstacles[1,3])^2)),
    min(
    sqrt(max(0.0, (p[2,1]-obstacles[1,1])^2 + (p[2,2]-obstacles[1,2])^2 + (p[2,3]-obstacles[1,3])^2)),
    sqrt(max(0.0, (p[3,1]-obstacles[1,1])^2 + (p[3,2]-obstacles[1,2])^2 + (p[3,3]-obstacles[1,3])^2))));
  obsDist2 = min(
    sqrt(max(0.0, (p[1,1]-obstacles[2,1])^2 + (p[1,2]-obstacles[2,2])^2 + (p[1,3]-obstacles[2,3])^2)),
    min(
    sqrt(max(0.0, (p[2,1]-obstacles[2,1])^2 + (p[2,2]-obstacles[2,2])^2 + (p[2,3]-obstacles[2,3])^2)),
    sqrt(max(0.0, (p[3,1]-obstacles[2,1])^2 + (p[3,2]-obstacles[2,2])^2 + (p[3,3]-obstacles[2,3])^2))));
  minObsDist = min(obsDist1, obsDist2);

  noCollision = minObsDist > collisionRadius and minPairwiseSeparation > minSeparation;

  maxCmd = max(rotorCmd[1], max(rotorCmd[2], max(rotorCmd[3], max(rotorCmd[4], max(rotorCmd[5], max(rotorCmd[6], max(rotorCmd[7], max(rotorCmd[8], max(rotorCmd[9], max(rotorCmd[10], max(rotorCmd[11], rotorCmd[12])))))))))));
  minCmd = min(rotorCmd[1], min(rotorCmd[2], min(rotorCmd[3], min(rotorCmd[4], min(rotorCmd[5], min(rotorCmd[6], min(rotorCmd[7], min(rotorCmd[8], min(rotorCmd[9], min(rotorCmd[10], min(rotorCmd[11], rotorCmd[12])))))))))));
  maxRotor = max(rotor[1], max(rotor[2], max(rotor[3], max(rotor[4], max(rotor[5], max(rotor[6], max(rotor[7], max(rotor[8], max(rotor[9], max(rotor[10], max(rotor[11], rotor[12])))))))))));
  minRotor = min(rotor[1], min(rotor[2], min(rotor[3], min(rotor[4], min(rotor[5], min(rotor[6], min(rotor[7], min(rotor[8], min(rotor[9], min(rotor[10], min(rotor[11], rotor[12])))))))))));
  actuatorLimitRespected = minCmd >= -1.0e-6 and maxCmd <= rotorMax + 1.0e-6 and minRotor >= -1.0e-6 and maxRotor <= rotorMax + 1.0e-6;

  trackingConverged = if time >= trackingTime then primaryTrackingError < trackingThreshold else false;

algorithm
  when sample(0.0, Ts) then
    for i in 1:3 loop
      for k in 1:3 loop
        eP[i,k] := pL[k] + offset[i,k] - estP[i,k];
        eV[i,k] := vL[k] - estV[i,k];
        form[i,k] := 0.0;
      end for;
    end for;

    for i in 1:3 loop
      for j in 1:3 loop
        if i <> j then
          for k in 1:3 loop
            form[i,k] := form[i,k] + kform*((offset[i,k] - offset[j,k]) - (estP[i,k] - delayedP[j,k]));
          end for;
        end if;
      end for;
    end for;

    for i in 1:3 loop
      for k in 1:3 loop
        aDes[i,k] := max(-amax, min(amax, aL[k] + kp*eP[i,k] + kd*eV[i,k] + max(-formationBound, min(formationBound, form[i,k]))));
      end for;
    end for;

    for i in 1:3 loop
      TrawAlg[i] := mQuad*sqrt(max(0.0, aDes[i,1]^2 + aDes[i,2]^2 + (aDes[i,3] + g_n)^2));
      TcmdAlg[i] := min(TrawAlg[i], 0.95*4.0*rotorMax);
      baseCmd := TcmdAlg[i]/4.0;
      rotorCmd[(i-1)*4+1] := max(rotorMin, min(rotorMax, baseCmd));
      rotorCmd[(i-1)*4+2] := max(rotorMin, min(rotorMax, baseCmd));
      rotorCmd[(i-1)*4+3] := max(rotorMin, min(rotorMax, baseCmd));
      rotorCmd[(i-1)*4+4] := max(rotorMin, min(rotorMax, baseCmd));
    end for;

    syncTime := time;
    for i in 1:3 loop
      for k in 1:3 loop
        syncP[i,k] := p[i,k];
        syncV[i,k] := v[i,k];
      end for;
    end for;
    for kk in 1:12 loop
      syncCmd[kk] := rotorCmd[kk];
    end for;
    syncRange[1] := range12;
    syncRange[2] := range13;
    syncRange[3] := range23;
    syncCommAge := commAge;
  end when;

  annotation (experiment(StopTime=14.0, Interval=0.005));
end AirTrioFormD;