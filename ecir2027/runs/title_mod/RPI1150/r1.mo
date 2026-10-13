model AirTrioResilientD
  // Unspecified route geometry, formation offsets, and disturbance magnitude are represented by finite bounded values.

  function norm3
    input Real x[3];
    output Real y;
  algorithm
    y := sqrt(x[1]*x[1] + x[2]*x[2] + x[3]*x[3]);
  end norm3;

  function unit3
    input Real x[3];
    output Real u[3];
  protected
    Real n;
  algorithm
    n := sqrt(x[1]*x[1] + x[2]*x[2] + x[3]*x[3]);
    if n < 1e-9 then
      u := {0.0,0.0,1.0};
    else
      u := {x[1]/n, x[2]/n, x[3]/n};
    end if;
  end unit3;

  parameter Real m = 1.8 "kg";
  parameter Real g = 9.81 "m/s2";
  parameter Real Tmax = 12.0 "N per rotor";
  parameter Real dt = 0.005 "s, 200 Hz";
  parameter Real routeT = 6.5 "s";
  parameter Real routeX = 10.0 "m";
  parameter Real alt = 5.0 "m";
  parameter Real dropoutStart = 6.5 "s";
  parameter Real dropoutDur = 1.0 "s";
  parameter Real dropoutEnd = dropoutStart + dropoutDur "s";
  parameter Real distForceX = 3.0 "N, shared environmental disturbance during dropout";
  parameter Real kPos = 25.0 "1/s2";
  parameter Real kVel = 7.5 "1/s";
  parameter Real kColl = 5.0 "acceleration gain";
  parameter Real activeRadius = 1.5 "m";
  parameter Real safeRange = 0.05 "m";
  parameter Real kGps = 1.0 "1/s";
  parameter Real rel2[3] = {2.0,0.0,0.0} "m";
  parameter Real rel3[3] = {0.0,2.0,0.0} "m";
  parameter Real gravityVec[3] = {0.0,0.0,-g} "m/s2";
  parameter Real p0[3,3] = {{0.0,0.0,alt},{2.0,0.0,alt},{0.0,2.0,alt}} "m";

  Real p[3,3];
  Real v[3,3];
  Real a[3,3];
  Real T[3,4];
  Real Fsum[3];
  Real nvec[3,3];
  Real sensorGPS[3,3];
  Real imuAcc[3,3];
  Real rangeMeas[3,3];
  Real r1d[3], r1v[3], r1a[3];
  Real r2d[3], r3d[3];
  Real routeProgress, uRoute;
  Real primaryTrackErr, formationError, minRange;
  Real disturbanceForceX;
  Boolean commAvail, dropoutActive, collisionAvoidanceActive;

  discrete Real Tcmd[3,4](start=fill(m*g/4,3,4));
  discrete Real Fcmd[3,3](start=fill(0.0,3,3));
  discrete Real Fmag[3](start=fill(0.0,3));
  discrete Real propPos[3,3](start=p0);
  discrete Real propVel[3,3](start=fill(0.0,3,3));
  discrete Real estPos[3,3](start=p0);
  discrete Real estVel[3,3](start=fill(0.0,3,3));
  discrete Real estAcc[3,3](start=fill(0.0,3,3));
  discrete Real lastRxPos[3,3,3](start=fill(0.0,3,3,3));
  discrete Real lastRxVel[3,3,3](start=fill(0.0,3,3,3));
  discrete Real lastRxTime[3,3](start=fill(0.0,3,3));
  discrete Real predPeerPos[3,3,3](start=fill(0.0,3,3,3));
  discrete Real predPeerVel[3,3,3](start=fill(0.0,3,3,3));
  discrete Real formationErrorDegraded(start=0.0);
  discrete Real formationErrorRecovered(start=0.0);
  discrete Real primaryTrackErrAfter9p1(start=0.0);
  discrete Real syncTime(start=0.0);
  discrete Real stateTrace[3,3](start=p0);
  discrete Real velocityTrace[3,3](start=fill(0.0,3,3));
  discrete Real commandTrace[3,4](start=fill(m*g/4,3,4));
  discrete Real rotorThrustTrace[3,4](start=fill(m*g/4,3,4));
  discrete Real gpsTrace[3,3](start=p0);
  discrete Real imuTrace[3,3](start=fill(0.0,3,3));
  discrete Real estTrace[3,3](start=p0);
  discrete Real estVelTrace[3,3](start=fill(0.0,3,3));
  discrete Real rangeTrace[3,3](start=fill(0.0,3,3));
  discrete Real peerPosTrace[3,3,3](start=fill(0.0,3,3,3));
  discrete Real peerVelTrace[3,3,3](start=fill(0.0,3,3,3));
  discrete Real peerTimeTrace[3,3](start=fill(0.0,3,3));
  Boolean routeCompleted(start=false);
  Boolean meetsTrackingAfter9p1(start=false);
  Integer syncCounter(start=0);

protected
  Real refPos[3];
  Real refVel[3];
  Real refAcc[3];
  Real aColl[3];
  Real aDes[3];
  Real dir[3];
  Real d;
  Real gain;
  Real dtRx;

initial equation
  for i in 1:3 loop
    for k in 1:3 loop
      p[i,k] = p0[i,k];
      v[i,k] = 0.0;
    end for;
  end for;

equation
  uRoute = max(0.0, min(1.0, time/routeT));
  routeProgress = 10.0*uRoute^3 - 15.0*uRoute^4 + 6.0*uRoute^5;
  r1d = {routeX*routeProgress, 0.0, alt};
  r1v = {routeX*(30.0*uRoute^2 - 60.0*uRoute^3 + 30.0*uRoute^4)/routeT, 0.0, 0.0};
  r1a = {routeX*(60.0*uRoute - 180.0*uRoute^2 + 120.0*uRoute^3)/(routeT^2), 0.0, 0.0};
  r2d = r1d + rel2;
  r3d = r1d + rel3;

  commAvail = not (time >= dropoutStart and time <= dropoutEnd);
  dropoutActive = not commAvail;
  disturbanceForceX = if dropoutActive then distForceX else 0.0;

  for i in 1:3 loop
    sensorGPS[i,:] = p[i,:];
    imuAcc[i,:] = a[i,:];
    for j in 1:3 loop
      if i <> j then
        rangeMeas[i,j] = norm3(p[i,:] - p[j,:]);
      else
        rangeMeas[i,j] = 0.0;
      end if;
    end for;
  end for;

  minRange = min(rangeMeas[1,2], min(rangeMeas[1,3], rangeMeas[2,3]));
  collisionAvoidanceActive = minRange < activeRadius;
  primaryTrackErr = norm3(p[1,:] - r1d);
  formationError = sqrt(norm3(p[2,:] - p[1,:] - rel2)^2 +
                       norm3(p[3,:] - p[1,:] - rel3)^2 +
                       norm3(p[2,:] - p[3,:] - (rel2 - rel3))^2);

  for i in 1:3 loop
    Fsum[i] = T[i,1] + T[i,2] + T[i,3] + T[i,4];
    nvec[i,:] = unit3(Fcmd[i,:]);
    for rot in 1:4 loop
      T[i,rot] = max(0.0, min(Tmax, Tcmd[i,rot]));
    end for;
    for k in 1:3 loop
      der(p[i,k]) = v[i,k];
      der(v[i,k]) = a[i,k];
      a[i,k] = (Fsum[i]*nvec[i,k] + (if k == 1 then disturbanceForceX else 0.0))/m +
               (if k == 3 then -g else 0.0);
    end for;
  end for;

algorithm
  when sample(0, dt) then
    // Local proprioception (IMU integration) and finite GPS-corrected estimates.
    for i in 1:3 loop
      for k in 1:3 loop
        propVel[i,k] := pre(propVel[i,k]) + imuAcc[i,k]*dt;
        propPos[i,k] := pre(propPos[i,k]) + pre(propVel[i,k])*dt;
        estPos[i,k] := sensorGPS[i,k];
        estVel[i,k] := propVel[i,k] + kGps*(estPos[i,k] - propPos[i,k]);
        estAcc[i,k] := imuAcc[i,k];
        propPos[i,k] := estPos[i,k];
        propVel[i,k] := estVel[i,k];
      end for;
    end for;

    // Last-received peer state with timestamps; held during dropout.
    if commAvail then
      for i in 1:3 loop
        for j in 1:3 loop
          if i <> j then
            for k in 1:3 loop
              lastRxPos[i,j,k] := estPos[j,k];
              lastRxVel[i,j,k] := estVel[j,k];
            end for;
            lastRxTime[i,j] := time;
          else
            for k in 1:3 loop
              lastRxPos[i,j,k] := pre(lastRxPos[i,j,k]);
              lastRxVel[i,j,k] := pre(lastRxVel[i,j,k]);
            end for;
            lastRxTime[i,j] := pre(lastRxTime[i,j]);
          end if;
        end for;
      end for;
    else
      for i in 1:3 loop
        for j in 1:3 loop
          for k in 1:3 loop
            lastRxPos[i,j,k] := pre(lastRxPos[i,j,k]);
            lastRxVel[i,j,k] := pre(lastRxVel[i,j,k]);
          end for;
          lastRxTime[i,j] := pre(lastRxTime[i,j]);
        end for;
      end for;
    end if;

    // Distributed prediction from last-received peer state.
    for i in 1:3 loop
      for j in 1:3 loop
        dtRx := max(0.0, time - lastRxTime[i,j]);
        for k in 1:3 loop
          predPeerPos[i,j,k] := lastRxPos[i,j,k] + lastRxVel[i,j,k]*dtRx;
          predPeerVel[i,j,k] := lastRxVel[i,j,k];
        end for;
      end for;
    end for;

    // Distributed control, collision avoidance, and bounded rotor commands.
    for i in 1:3 loop
      if i == 1 then
        refPos[1] := r1d[1]; refPos[2] := r1d[2]; refPos[3] := r1d[3];
        refVel[1] := r1v[1]; refVel[2] := r1v[2]; refVel[3] := r1v[3];
        refAcc[1] := r1a[1]; refAcc[2] := r1a[2]; refAcc[3] := r1a[3];
      elseif i == 2 then
        refPos[1] := predPeerPos[2,1,1] + rel2[1];
        refPos[2] := predPeerPos[2,1,2] + rel2[2];
        refPos[3] := predPeerPos[2,1,3] + rel2[3];
        refVel[1] := predPeerVel[2,1,1];
        refVel[2] := predPeerVel[2,1,2];
        refVel[3] := predPeerVel[2,1,3];
        refAcc[1] := 0.0; refAcc[2] := 0.0; refAcc[3] := 0.0;
      else
        refPos[1] := predPeerPos[3,1,1] + rel3[1];
        refPos[2] := predPeerPos[3,1,2] + rel3[2];
        refPos[3] := predPeerPos[3,1,3] + rel3[3];
        refVel[1] := predPeerVel[3,1,1];
        refVel[2] := predPeerVel[3,1,2];
        refVel[3] := predPeerVel[3,1,3];
        refAcc[1] := 0.0; refAcc[2] := 0.0; refAcc[3] := 0.0;
      end if;

      aColl[1] := 0.0;
      aColl[2] := 0.0;
      aColl[3] := 0.0;
      for j in 1:3 loop
        if i <> j then
          d := max(safeRange, rangeMeas[i,j]);
          if d < activeRadius then
            dir[1] := (sensorGPS[i,1] - sensorGPS[j,1])/d;
            dir[2] := (sensorGPS[i,2] - sensorGPS[j,2])/d;
            dir[3] := (sensorGPS[i,3] - sensorGPS[j,3])/d;
            gain := kColl*(1.0/d - 1.0/activeRadius);
            aColl[1] := aColl[1] + gain*dir[1];
            aColl[2] := aColl[2] + gain*dir[2];
            aColl[3] := aColl[3] + gain*dir[3];
          end if;
        end if;
      end for;

      for k in 1:3 loop
        aDes[k] := refAcc[k] + kPos*(refPos[k] - estPos[i,k]) + kVel*(refVel[k] - estVel[i,k]) + aColl[k];
        Fcmd[i,k] := m*(aDes[k] - gravityVec[k]);
      end for;
      Fmag[i] := norm3(Fcmd[i,:]);
      for rot in 1:4 loop
        Tcmd[i,rot] := max(0.0, min(Tmax, Fmag[i]/4.0));
      end for;
    end for;

    // Synchronized state, command, and sensor traces at 200 Hz.
    syncTime := time;
    syncCounter := pre(syncCounter) + 1;
    for i in 1:3 loop
      for k in 1:3 loop
        stateTrace[i,k] := p[i,k];
        velocityTrace[i,k] := v[i,k];
        gpsTrace[i,k] := sensorGPS[i,k];
        imuTrace[i,k] := imuAcc[i,k];
        estTrace[i,k] := estPos[i,k];
        estVelTrace[i,k] := estVel[i,k];
      end for;
      for rot in 1:4 loop
        commandTrace[i,rot] := Tcmd[i,rot];
        rotorThrustTrace[i,rot] := max(0.0, min(Tmax, Tcmd[i,rot]));
      end for;
      for j in 1:3 loop
        rangeTrace[i,j] := rangeMeas[i,j];
        for k in 1:3 loop
          peerPosTrace[i,j,k] := lastRxPos[i,j,k];
          peerVelTrace[i,j,k] := lastRxVel[i,j,k];
        end for;
        peerTimeTrace[i,j] := lastRxTime[i,j];
      end for;
    end for;

    if dropoutActive then
      formationErrorDegraded := formationError;
    elseif time >= dropoutEnd then
      formationErrorRecovered := formationError;
    else
      formationErrorDegraded := pre(formationErrorDegraded);
      formationErrorRecovered := pre(formationErrorRecovered);
    end if;

    if time >= routeT and primaryTrackErr < 0.6 then
      routeCompleted := true;
    else
      routeCompleted := pre(routeCompleted);
    end if;

    if time >= 9.1 then
      meetsTrackingAfter9p1 := primaryTrackErr < 0.6;
      primaryTrackErrAfter9p1 := primaryTrackErr;
    else
      meetsTrackingAfter9p1 := pre(meetsTrackingAfter9p1);
      primaryTrackErrAfter9p1 := pre(primaryTrackErrAfter9p1);
    end if;
  end when;

  annotation(experiment(StopTime=14.0, Interval=0.005, Tolerance=1e-4));
end AirTrioResilientD;