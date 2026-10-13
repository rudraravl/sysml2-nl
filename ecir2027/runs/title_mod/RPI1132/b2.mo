model AirTrioFormD
  import SI = Modelica.SIunits;
  import Modelica.Constants.g_n;

  parameter SI.Mass mQuad = 1.8 "mass of each quadrotor";
  parameter SI.Force rotorMax = 12.0 "per-rotor thrust limit";
  parameter SI.Force rotorMin = 0.0;
  parameter SI.Time actTau = 0.02 "rotor-thrust actuator time constant";
  parameter SI.Frequency controlRate = 200.0 "controller and trace rate";
  parameter SI.Time Ts = 1.0/controlRate;
  parameter SI.Time Tfinal = 14.0;
  parameter SI.Time messageDelay = 0.08;
  parameter SI.Acceleration amax = 12.0 "local acceleration command bound";
  parameter SI.Acceleration formationBound = 2.0 "formation term bound";

  parameter Real kp(unit="1/s2") = 20.0;
  parameter Real kd(unit="1/s") = 8.0;
  parameter Real kform(unit="1/s2") = 5.0;
  parameter Real obsLp(unit="1/s") = 12.0;
  parameter Real obsLv(unit="1/s2") = 64.0;

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

  parameter SI.Force hoverThrust = mQuad*g_n/4.0;

  SI.Position p[3,3](start={{0.0,0.0,3.0},{1.5,1.0,3.0},{-1.5,1.0,3.0}});
  SI.Velocity v[3,3](start={{0.10,0.0,0.0},{0.10,0.0,0.0},{0.10,0.0,0.0}});
  SI.Acceleration a[3,3];
  SI.Force F[3,3];

  SI.Position estP[3,3](start={{0.0,0.0,3.0},{1.5,1.0,3.0},{-1.5,1.0,3.0}});
  SI.Velocity estV[3,3](start={{0.10,0.0,0.0},{0.10,0.0,0.0},{0.10,0.0,0.0}});

  SI.Position pL[3];
  SI.Velocity vL[3];
  SI.Acceleration aL[3];
  SI.Position pD[3,3];

  SI.Position gpsP[3,3];
  SI.Acceleration imuA[3,3];
  SI.Length range12;
  SI.Length range13;
  SI.Length range23;

  SI.Position pRaw1x "scalar copy of p[1,1] for delay";
  SI.Position pRaw1y "scalar copy of p[1,2] for delay";
  SI.Position pRaw1z "scalar copy of p[1,3] for delay";
  SI.Position pRaw2x "scalar copy of p[2,1] for delay";
  SI.Position pRaw2y "scalar copy of p[2,2] for delay";
  SI.Position pRaw2z "scalar copy of p[2,3] for delay";
  SI.Position pRaw3x "scalar copy of p[3,1] for delay";
  SI.Position pRaw3y "scalar copy of p[3,2] for delay";
  SI.Position pRaw3z "scalar copy of p[3,3] for delay";
  SI.Position dpRaw1x "delayed scalar position";
  SI.Position dpRaw1y "delayed scalar position";
  SI.Position dpRaw1z "delayed scalar position";
  SI.Position dpRaw2x "delayed scalar position";
  SI.Position dpRaw2y "delayed scalar position";
  SI.Position dpRaw2z "delayed scalar position";
  SI.Position dpRaw3x "delayed scalar position";
  SI.Position dpRaw3y "delayed scalar position";
  SI.Position dpRaw3z "delayed scalar position";
  SI.Position delayedP[3,3];
  SI.Time commAge;
  Boolean middleThird;

  discrete SI.Acceleration aDes[3,3](start={{0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0}});
  discrete SI.Force rotorCmd[12](start=fill(hoverThrust,12));
  SI.Force rotorRaw[12](start=fill(hoverThrust,12));
  SI.Force rotor[12];

  SI.Force Traw[3];
  Real dir[3,3];
  SI.Force sumRotor[3];

  discrete SI.Time syncTime(start=0.0);
  discrete SI.Position syncP[3,3](start={{0.0,0.0,3.0},{1.5,1.0,3.0},{-1.5,1.0,3.0}});
  discrete SI.Velocity syncV[3,3](start={{0.10,0.0,0.0},{0.10,0.0,0.0},{0.10,0.0,0.0}});
  discrete SI.Force syncCmd[12](start=fill(hoverThrust,12));
  discrete SI.Length syncRange[3](start={0.0,0.0,0.0});
  discrete SI.Time syncCommAge(start=0.0);

  SI.Length minPairwiseSeparation;
  SI.Length formationError;
  SI.Length primaryTrackingError;
  Boolean noCollision;
  Boolean actuatorLimitRespected;
  Boolean trackingConverged;
  SI.Length obsDist1;
  SI.Length obsDist2;
  SI.Length minObsDist;
  SI.Force maxCmd;
  SI.Force minCmd;
  SI.Force maxRotor;
  SI.Force minRotor;

protected
  discrete SI.Length eP[3,3];
  discrete SI.Velocity eV[3,3];
  discrete SI.Acceleration form[3,3];
  discrete SI.Force TrawAlg[3];
  discrete SI.Force TcmdAlg[3];
  discrete SI.Force baseCmd;

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
    pD[i,1] = pL[1] + offset[i,1];
    pD[i,2] = pL[2] + offset[i,2];
    pD[i,3] = pL[3] + offset[i,3];
  end for;

  for i in 1:3 loop
    der(p[i,1]) = v[i,1];
    der(p[i,2]) = v[i,2];
    der(p[i,3]) = v[i,3];
    der(v[i,1]) = a[i,1];
    der(v[i,2]) = a[i,2];
    der(v[i,3]) = a[i,3];
    gpsP[i,1] = p[i,1];
    gpsP[i,2] = p[i,2];
    gpsP[i,3] = p[i,3];
    imuA[i,1] = a[i,1];
    imuA[i,2] = a[i,2];
    imuA[i,3] = a[i,3];
    a[i,1] = F[i,1]/mQuad;
    a[i,2] = F[i,2]/mQuad;
    a[i,3] = F[i,3]/mQuad - g_n;
  end for;

  for i in 1:3 loop
    Traw[i] = mQuad*sqrt(max(0.0, aDes[i,1]*aDes[i,1] + aDes[i,2]*aDes[i,2] + (aDes[i,3] + g_n)*(aDes[i,3] + g_n)));
    if noEvent(Traw[i] > 1.0e-6) then
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
    der(estP[i,1]) = estV[i,1] + obsLp*(gpsP[i,1] - estP[i,1]);
    der(estP[i,2]) = estV[i,2] + obsLp*(gpsP[i,2] - estP[i,2]);
    der(estP[i,3]) = estV[i,3] + obsLp*(gpsP[i,3] - estP[i,3]);
    der(estV[i,1]) = imuA[i,1] + obsLv*(gpsP[i,1] - estP[i,1]);
    der(estV[i,2]) = imuA[i,2] + obsLv*(gpsP[i,2] - estP[i,2]);
    der(estV[i,3]) = imuA[i,3] + obsLv*(gpsP[i,3] - estP[i,3]);
  end for;

  range12 = sqrt(max(0.0, (p[1,1]-p[2,1])*(p[1,1]-p[2,1]) + (p[1,2]-p[2,2])*(p[1,2]-p[2,2]) + (p[1,3]-p[2,3])*(p[1,3]-p[2,3])));
  range13 = sqrt(max(0.0, (p[1,1]-p[3,1])*(p[1,1]-p[3,1]) + (p[1,2]-p[3,2])*(p[1,2]-p[3,2]) + (p[1,3]-p[3,3])*(p[1,3]-p[3,3])));
  range23 = sqrt(max(0.0, (p[2,1]-p[3,1])*(p[2,1]-p[3,1]) + (p[2,2]-p[3,2])*(p[2,2]-p[3,2]) + (p[2,3]-p[3,3])*(p[2,3]-p[3,3])));

  middleThird = time >= Tfinal/3.0 and time <= 2.0*Tfinal/3.0;
  commAge = if middleThird then messageDelay else 0.0;

  pRaw1x = p[1,1];
  pRaw1y = p[1,2];
  pRaw1z = p[1,3];
  pRaw2x = p[2,1];
  pRaw2y = p[2,2];
  pRaw2z = p[2,3];
  pRaw3x = p[3,1];
  pRaw3y = p[3,2];
  pRaw3z = p[3,3];

  dpRaw1x = delay(pRaw1x, messageDelay, messageDelay);
  dpRaw1y = delay(pRaw1y, messageDelay, messageDelay);
  dpRaw1z = delay(pRaw1z, messageDelay, messageDelay);
  dpRaw2x = delay(pRaw2x, messageDelay, messageDelay);
  dpRaw2y = delay(pRaw2y, messageDelay, messageDelay);
  dpRaw2z = delay(pRaw2z, messageDelay, messageDelay);
  dpRaw3x = delay(pRaw3x, messageDelay, messageDelay);
  dpRaw3y = delay(pRaw3y, messageDelay, messageDelay);
  dpRaw3z = delay(pRaw3z, messageDelay, messageDelay);

  delayedP[1,1] = if middleThird then dpRaw1x else p[1,1];
  delayedP[1,2] = if middleThird then dpRaw1y else p[1,2];
  delayedP[1,3] = if middleThird then dpRaw1z else p[1,3];
  delayedP[2,1] = if middleThird then dpRaw2x else p[2,1];
  delayedP[2,2] = if middleThird then dpRaw2y else p[2,2];
  delayedP[2,3] = if middleThird then dpRaw2z else p[2,3];
  delayedP[3,1] = if middleThird then dpRaw3x else p[3,1];
  delayedP[3,2] = if middleThird then dpRaw3y else p[3,2];
  delayedP[3,3] = if middleThird then dpRaw3z else p[3,3];

  formationError = sqrt(max(0.0, (
    ((p[1,1]-p[2,1]) - (offset[1,1]-offset[2,1]))*((p[1,1]-p[2,1]) - (offset[1,1]-offset[2,1])) +
    ((p[1,2]-p[2,2]) - (offset[1,2]-offset[2,2]))*((p[1,2]-p[2,2]) - (offset[1,2]-offset[2,2])) +
    ((p[1,3]-p[2,3]) - (offset[1,3]-offset[2,3]))*((p[1,3]-p[2,3]) - (offset[1,3]-offset[2,3])) +
    ((p[1,1]-p[3,1]) - (offset[1,1]-offset[3,1]))*((p[1,1]-p[3,1]) - (offset[1,1]-offset[3,1])) +
    ((p[1,2]-p[3,2]) - (offset[1,2]-offset[3,2]))*((p[1,2]-p[3,2]) - (offset[1,2]-offset[3,2])) +
    ((p[1,3]-p[3,3]) - (offset[1,3]-offset[3,3]))*((p[1,3]-p[3,3]) - (offset[1,3]-offset[3,3])) +
    ((p[2,1]-p[3,1]) - (offset[2,1]-offset[3,1]))*((p[2,1]-p[3,1]) - (offset[2,1]-offset[3,1])) +
    ((p[2,2]-p[3,2]) - (offset[2,2]-offset[3,2]))*((p[2,2]-p[3,2]) - (offset[2,2]-offset[3,2])) +
    ((p[2,3]-p[3,3]) - (offset[2,3]-offset[3,3]))*((p[2,3]-p[3,3]) - (offset[2,3]-offset[3,3]))
    )/3.0));

  primaryTrackingError = sqrt(max(0.0, (p[1,1]-pL[1])*(p[1,1]-pL[1]) + (p[1,2]-pL[2])*(p[1,2]-pL[2]) + (p[1,3]-pL[3])*(p[1,3]-pL[3])));

  minPairwiseSeparation = min(range12, min(range13, range23));

  obsDist1 = min(
    sqrt(max(0.0, (p[1,1]-obstacles[1,1])*(p[1,1]-obstacles[1,1]) + (p[1,2]-obstacles[1,2])*(p[1,2]-obstacles[1,2]) + (p[1,3]-obstacles[1,3])*(p[1,3]-obstacles[1,3]))),
    min(
    sqrt(max(0.0, (p[2,1]-obstacles[1,1])*(p[2,1]-obstacles[1,1]) + (p[2,2]-obstacles[1,2])*(p[2,2]-obstacles[1,2]) + (p[2,3]-obstacles[1,3])*(p[2,3]-obstacles[1,3]))),
    sqrt(max(0.0, (p[3,1]-obstacles[1,1])*(p[3,1]-obstacles[1,1]) + (p[3,2]-obstacles[1,2])*(p[3,2]-obstacles[1,2]) + (p[3,3]-obstacles[1,3])*(p[3,3]-obstacles[1,3])))));
  obsDist2 = min(
    sqrt(max(0.0, (p[1,1]-obstacles[2,1])*(p[1,1]-obstacles[2,1]) + (p[1,2]-obstacles[2,2])*(p[1,2]-obstacles[2,2]) + (p[1,3]-obstacles[2,3])*(p[1,3]-obstacles[2,3]))),
    min(
    sqrt(max(0.0, (p[2,1]-obstacles[2,1])*(p[2,1]-obstacles[2,1]) + (p[2,2]-obstacles[2,2])*(p[2,2]-obstacles[2,2]) + (p[2,3]-obstacles[2,3])*(p[2,3]-obstacles[2,3]))),
    sqrt(max(0.0, (p[3,1]-obstacles[2,1])*(p[3,1]-obstacles[2,1]) + (p[3,2]-obstacles[2,2])*(p[3,2]-obstacles[2,2]) + (p[3,3]-obstacles[2,3])*(p[3,3]-obstacles[2,3])))));
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
      TrawAlg[i] := mQuad*sqrt(max(0.0, aDes[i,1]*aDes[i,1] + aDes[i,2]*aDes[i,2] + (aDes[i,3] + g_n)*(aDes[i,3] + g_n)));
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