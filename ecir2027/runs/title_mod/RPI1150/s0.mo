model AirTrioResilientD
  "Instrumented three-quadrotor formation with 1 s communication dropout and recovery.
   Unstated details omitted: attitude/yaw dynamics, aerodynamic drag, sensor noise, rotor dynamics.
   The model uses a point-mass quadrotor abstraction with bounded rotor-thrust mixing.";

  parameter Real m(unit="kg") = 1.8 "quadrotor mass";
  parameter Real g(unit="m/s2") = 9.81 "gravitational acceleration";
  parameter Real FrotorMax(unit="N") = 12.0 "per-rotor thrust bound";
  parameter Real k_tilt = 2.0
    "assumed rotor differential-to-horizontal-force mixing gain; rotor geometry not specified";
  parameter Real Ts(unit="s") = 0.005 "200 Hz control and sensor cycle";
  parameter Real T_end(unit="s") = 14.0 "simulation duration";
  parameter Real T_route(unit="s") = 9.0 "route completion time";
  parameter Real X0(unit="m") = 0.0 "route start x";
  parameter Real Xf(unit="m") = 8.0 "route final x";
  parameter Real Y0(unit="m") = 0.0 "route y";
  parameter Real Z0(unit="m") = 2.0 "route z";
  parameter Real off2x(unit="m") = -2.0 "robot2 formation offset x";
  parameter Real off2y(unit="m") = 2.0 "robot2 formation offset y";
  parameter Real off2z(unit="m") = 0.0 "robot2 formation offset z";
  parameter Real off3x(unit="m") = -2.0 "robot3 formation offset x";
  parameter Real off3y(unit="m") = -2.0 "robot3 formation offset y";
  parameter Real off3z(unit="m") = 0.0 "robot3 formation offset z";
  parameter Real d12(unit="m") = sqrt(off2x^2 + off2y^2 + off2z^2);
  parameter Real d13(unit="m") = sqrt(off3x^2 + off3y^2 + off3z^2);
  parameter Real d23(unit="m") = sqrt((off2x - off3x)^2 + (off2y - off3y)^2 + (off2z - off3z)^2);
  parameter Real Kp(unit="1/s2") = 8.0 "position gain";
  parameter Real Kd(unit="1/s") = 5.0 "velocity gain";
  parameter Real safeDist(unit="m") = 1.5 "collision avoidance distance";
  parameter Real kAvoid(unit="m/s2") = 20.0 "collision avoidance gain";
  parameter Real tDropStart(unit="s") = 4.7 "communication dropout start";
  parameter Real tDropEnd(unit="s") = 5.7 "communication dropout end";
  parameter Real distForce(unit="N") = 6.0 "shared disturbance force during dropout";
  parameter Real eps(unit="m") = 1e-6 "norm zero-error branch";
  parameter Real middleThirdStart(unit="s") = T_end/3.0;
  parameter Real middleThirdEnd(unit="s") = 2.0*T_end/3.0;
  parameter Real fHover(unit="N") = m*g/4.0 "hover thrust per rotor";

  function repulseComp
    input Real c1;
    input Real c2;
    input Real r;
    input Real safeDistIn;
    input Real k;
    input Real epsIn;
    output Real a;
  protected
    Real n;
    Real r2;
  algorithm
    r2 := max(r, epsIn);
    n := max(0.0, safeDistIn - r);
    a := k*n*(c1 - c2)/(r2*r2);
  end repulseComp;

  Real p[3,3](unit="m") "robot positions";
  Real v[3,3](unit="m/s") "robot velocities";
  Real a[3,3](unit="m/s2") "robot accelerations";
  Real F[3,3](unit="N") "robot body forces";
  Real f[3,4](unit="N", min=0, max=FrotorMax) "actual rotor thrusts";
  discrete Real fcmd[3,4](unit="N", min=0, max=FrotorMax, start=fill(fHover,3,4)) "rotor thrust commands";

  Real gpsTrue[3,3](unit="m");
  Real velTrue[3,3](unit="m/s");
  Real imuTrue[3,3](unit="m/s2");
  Real rangeTrue[3,3](unit="m");

  discrete Real gps[3,3](unit="m", start=fill(0.0,3,3)) "sampled GPS positions";
  discrete Real velMeas[3,3](unit="m/s", start=fill(0.0,3,3)) "sampled velocity measurements";
  discrete Real imu[3,3](unit="m/s2", start=fill(0.0,3,3)) "sampled IMU accelerations";
  discrete Real range[3,3](unit="m", start=fill(0.0,3,3)) "sampled peer-relative ranges";
  discrete Real sensorTimestamp(unit="s", start=0.0) "synchronized sensor sample timestamp";

  Real estp[3,3](unit="m") "local position estimates";
  Real estv[3,3](unit="m/s") "local velocity estimates";

  discrete Real rxp[3,3,3](unit="m", start=fill(0.0,3,3,3)) "last received peer positions";
  discrete Real rxv[3,3,3](unit="m/s", start=fill(0.0,3,3,3)) "last received peer velocities";
  discrete Real rxt[3,3](unit="s", start=fill(0.0,3,3)) "last received peer timestamps";

  discrete Real predp[3,3,3](unit="m", start=fill(0.0,3,3,3)) "predicted peer positions";
  discrete Real predv[3,3,3](unit="m/s", start=fill(0.0,3,3,3)) "predicted peer velocities";
  discrete Real ades[3,3](unit="m/s2", start=fill(0.0,3,3)) "distributed desired accelerations";

  Real eta;
  Real routeX(unit="m");
  Real routeY(unit="m");
  Real routeZ(unit="m");
  Real routeVx(unit="m/s");
  Real routeVy(unit="m/s");
  Real routeVz(unit="m/s");
  Real routeAx(unit="m/s2");
  Real routeAy(unit="m/s2");
  Real routeAz(unit="m/s2");

  Boolean dropoutActive;
  Boolean communicationAvailable;
  Real distForceNow(unit="N");

  Real primaryTrackingError(unit="m");
  Boolean primaryTrackingErrorOK;
  Real formationErr(unit="m");
  discrete Real degradedFormationError(unit="m", start=0.0);
  discrete Real recoveredFormationError(unit="m", start=0.0);
  Real minRange(unit="m");
  Boolean collisionFree;
  Real actuatorMin(unit="N");
  Real actuatorMax(unit="N");
  Boolean actuatorBoundOK;
  Boolean routeCompleted;

protected
  discrete Real e1x,e1y,e1z,ev1x,ev1y,ev1z;
  discrete Real e2x,e2y,e2z,ev2x,ev2y,ev2z;
  discrete Real e3x,e3y,e3z,ev3x,ev3y,ev3z;
  discrete Real pdes2x,pdes2y,pdes2z,pdes3x,pdes3y,pdes3z;
  discrete Real Tcmd,Fxcmd,Fycmd,raw1,raw2,raw3,raw4;
  discrete Real dtPred;

initial equation
  p = {{0.0,0.0,2.0},{-2.0,2.0,2.0},{-2.0,-2.0,2.0}};
  v = fill(0.0,3,3);

equation
  dropoutActive = time >= tDropStart and time <= tDropEnd;
  communicationAvailable = not dropoutActive;
  distForceNow = if dropoutActive then distForce else 0.0;
  assert(tDropStart >= middleThirdStart and tDropEnd <= middleThirdEnd, "dropout not in middle third");
  assert(abs((tDropEnd - tDropStart) - 1.0) < 1e-9, "dropout duration not 1 s");

  eta = if time <= T_route then time/T_route else 1.0;
  routeX = X0 + (Xf - X0)*(10.0*eta^3 - 15.0*eta^4 + 6.0*eta^5);
  routeY = Y0;
  routeZ = Z0;
  routeVx = if time <= T_route then (Xf - X0)/T_route*(30.0*eta^2 - 60.0*eta^3 + 30.0*eta^4) else 0.0;
  routeVy = 0.0;
  routeVz = 0.0;
  routeAx = if time <= T_route then (Xf - X0)/T_route^2*(60.0*eta - 180.0*eta^2 + 120.0*eta^3) else 0.0;
  routeAy = 0.0;
  routeAz = 0.0;

  for i in 1:3 loop
    for k in 1:3 loop
      gpsTrue[i,k] = p[i,k];
      velTrue[i,k] = v[i,k];
      imuTrue[i,k] = a[i,k];
      estp[i,k] = gps[i,k];
      estv[i,k] = velMeas[i,k];
    end for;
  end for;

  rangeTrue[1,2] = sqrt(max((p[1,1]-p[2,1])^2 + (p[1,2]-p[2,2])^2 + (p[1,3]-p[2,3])^2, eps*eps));
  rangeTrue[2,1] = rangeTrue[1,2];
  rangeTrue[1,3] = sqrt(max((p[1,1]-p[3,1])^2 + (p[1,2]-p[3,2])^2 + (p[1,3]-p[3,3])^2, eps*eps));
  rangeTrue[3,1] = rangeTrue[1,3];
  rangeTrue[2,3] = sqrt(max((p[2,1]-p[3,1])^2 + (p[2,2]-p[3,2])^2 + (p[2,3]-p[3,3])^2, eps*eps));
  rangeTrue[3,2] = rangeTrue[2,3];
  rangeTrue[1,1] = 0.0;
  rangeTrue[2,2] = 0.0;
  rangeTrue[3,3] = 0.0;

  for i in 1:3 loop
    f[i,1] = fcmd[i,1];
    f[i,2] = fcmd[i,2];
    f[i,3] = fcmd[i,3];
    f[i,4] = fcmd[i,4];
    F[i,1] = k_tilt*(f[i,1] - f[i,2] + f[i,3] - f[i,4]);
    F[i,2] = k_tilt*(f[i,1] + f[i,2] - f[i,3] - f[i,4]);
    F[i,3] = f[i,1] + f[i,2] + f[i,3] + f[i,4] - m*g;
    a[i,1] = (F[i,1] + distForceNow)/m;
    a[i,2] = F[i,2]/m;
    a[i,3] = F[i,3]/m;
    for k in 1:3 loop
      der(p[i,k]) = v[i,k];
      der(v[i,k]) = a[i,k];
    end for;
  end for;

  primaryTrackingError = sqrt(max((p[1,1]-routeX)^2 + (p[1,2]-routeY)^2 + (p[1,3]-routeZ)^2, eps*eps));
  primaryTrackingErrorOK = if time > 9.1 then primaryTrackingError < 0.6 else true;
  formationErr = max(abs(rangeTrue[1,2]-d12), max(abs(rangeTrue[1,3]-d13), abs(rangeTrue[2,3]-d23)));
  minRange = min(rangeTrue[1,2], min(rangeTrue[1,3], rangeTrue[2,3]));
  collisionFree = minRange >= safeDist;
  routeCompleted = time >= T_route;

  actuatorMin = min(f[1,1], min(f[1,2], min(f[1,3], min(f[1,4], min(f[2,1], min(f[2,2], min(f[2,3], min(f[2,4], min(f[3,1], min(f[3,2], min(f[3,3], f[3,4]))))))))))));
  actuatorMax = max(f[1,1], max(f[1,2], max(f[1,3], max(f[1,4], max(f[2,1], max(f[2,2], max(f[2,3], max(f[2,4], max(f[3,1], max(f[3,2], max(f[3,3], f[3,4]))))))))))));
  actuatorBoundOK = actuatorMin >= -1e-9 and actuatorMax <= FrotorMax + 1e-9;

  assert(primaryTrackingErrorOK, "primary tracking error above 0.6 m after 9.1 s");
  assert(collisionFree, "collision avoidance failed");
  assert(actuatorBoundOK, "rotor thrust bound violated");
  assert(primaryTrackingError < 1e6 and formationErr < 1e6 and degradedFormationError < 1e6 and recoveredFormationError < 1e6, "non-finite value detected");
  assert(time <= T_end + 1e-9 or routeCompleted, "route not completed");

algorithm
  when sample(0, Ts) then
    for i in 1:3 loop
      for k in 1:3 loop
        gps[i,k] := gpsTrue[i,k];
        velMeas[i,k] := velTrue[i,k];
        imu[i,k] := imuTrue[i,k];
      end for;
    end for;
    for i in 1:3 loop
      for j in 1:3 loop
        range[i,j] := rangeTrue[i,j];
      end for;
    end for;
    sensorTimestamp := time;

    for i in 1:3 loop
      for j in 1:3 loop
        if i == j then
          for k in 1:3 loop
            rxp[i,j,k] := gps[i,k];
            rxv[i,j,k] := velMeas[i,k];
          end for;
          rxt[i,j] := time;
        elseif not dropoutActive then
          for k in 1:3 loop
            rxp[i,j,k] := gps[j,k];
            rxv[i,j,k] := velMeas[j,k];
          end for;
          rxt[i,j] := time;
        else
          for k in 1:3 loop
            rxp[i,j,k] := pre(rxp[i,j,k]);
            rxv[i,j,k] := pre(rxv[i,j,k]);
          end for;
          rxt[i,j] := pre(rxt[i,j]);
        end if;
      end for;
    end for;

    for i in 1:3 loop
      for j in 1:3 loop
        dtPred := time - rxt[i,j];
        for k in 1:3 loop
          predp[i,j,k] := rxp[i,j,k] + rxv[i,j,k]*dtPred;
          predv[i,j,k] := rxv[i,j,k];
        end for;
      end for;
    end for;

    e1x := routeX - gps[1,1];
    e1y := routeY - gps[1,2];
    e1z := routeZ - gps[1,3];
    ev1x := routeVx - velMeas[1,1];
    ev1y := routeVy - velMeas[1,2];
    ev1z := routeVz - velMeas[1,3];
    ades[1,1] := Kp*e1x + Kd*ev1x + routeAx
               + repulseComp(gps[1,1],gps[2,1],range[1,2],safeDist,kAvoid,eps)
               + repulseComp(gps[1,1],gps[3,1],range[1,3],safeDist,kAvoid,eps);
    ades[1,2] := Kp*e1y + Kd*ev1y + routeAy
               + repulseComp(gps[1,2],gps[2,2],range[1,2],safeDist,kAvoid,eps)
               + repulseComp(gps[1,2],gps[3,2],range[1,3],safeDist,kAvoid,eps);
    ades[1,3] := Kp*e1z + Kd*ev1z + routeAz
               + repulseComp(gps[1,3],gps[2,3],range[1,2],safeDist,kAvoid,eps)
               + repulseComp(gps[1,3],gps[3,3],range[1,3],safeDist,kAvoid,eps);

    pdes2x := predp[2,1,1] + off2x;
    pdes2y := predp[2,1,2] + off2y;
    pdes2z := predp[2,1,3] + off2z;
    e2x := pdes2x - gps[2,1];
    e2y := pdes2y - gps[2,2];
    e2z := pdes2z - gps[2,3];
    ev2x := predv[2,1,1] - velMeas[2,1];
    ev2y := predv[2,1,2] - velMeas[2,2];
    ev2z := predv[2,1,3] - velMeas[2,3];
    ades[2,1] := Kp*e2x + Kd*ev2x
               + repulseComp(gps[2,1],gps[1,1],range[2,1],safeDist,kAvoid,eps)
               + repulseComp(gps[2,1],gps[3,1],range[2,3],safeDist,kAvoid,eps);
    ades[2,2] := Kp*e2y + Kd*ev2y
               + repulseComp(gps[2,2],gps[1,2],range[2,1],safeDist,kAvoid,eps)
               + repulseComp(gps[2,2],gps[3,2],range[2,3],safeDist,kAvoid,eps);
    ades[2,3] := Kp*e2z + Kd*ev2z
               + repulseComp(gps[2,3],gps[1,3],range[2,1],safeDist,kAvoid,eps)
               + repulseComp(gps[2,3],gps[3,3],range[2,3],safeDist,kAvoid,eps);

    pdes3x := predp[3,1,1] + off3x;
    pdes3y := predp[3,1,2] + off3y;
    pdes3z := predp[3,1,3] + off3z;
    e3x := pdes3x - gps[3,1];
    e3y := pdes3y - gps[3,2];
    e3z := pdes3z - gps[3,3];
    ev3x := predv[3,1,1] - velMeas[3,1];
    ev3y := predv[3,1,2] - velMeas[3,2];
    ev3z := predv[3,1,3] - velMeas[3,3];
    ades[3,1] := Kp*e3x + Kd*ev3x
               + repulseComp(gps[3,1],gps[1,1],range[3,1],safeDist,kAvoid,eps)
               + repulseComp(gps[3,1],gps[2,1],range[3,2],safeDist,kAvoid,eps);
    ades[3,2] := Kp*e3y + Kd*ev3y
               + repulseComp(gps[3,2],gps[1,2],range[3,1],safeDist,kAvoid,eps)
               + repulseComp(gps[3,2],gps[2,2],range[3,2],safeDist,kAvoid,eps);
    ades[3,3] := Kp*e3z + Kd*ev3z
               + repulseComp(gps[3,3],gps[1,3],range[3,1],safeDist,kAvoid,eps)
               + repulseComp(gps[3,3],gps[2,3],range[3,2],safeDist,kAvoid,eps);

    for i in 1:3 loop
      Tcmd := max(0.0, min(4.0*FrotorMax, m*(g + ades[i,3])));
      Fxcmd := m*ades[i,1];
      Fycmd := m*ades[i,2];
      raw1 := Tcmd/4.0 + Fxcmd/(4.0*k_tilt) + Fycmd/(4.0*k_tilt);
      raw2 := Tcmd/4.0 - Fxcmd/(4.0*k_tilt) + Fycmd/(4.0*k_tilt);
      raw3 := Tcmd/4.0 + Fxcmd/(4.0*k_tilt) - Fycmd/(4.0*k_tilt);
      raw4 := Tcmd/4.0 - Fxcmd/(4.0*k_tilt) - Fycmd/(4.0*k_tilt);
      fcmd[i,1] := max(0.0, min(FrotorMax, raw1));
      fcmd[i,2] := max(0.0, min(FrotorMax, raw2));
      fcmd[i,3] := max(0.0, min(FrotorMax, raw3));
      fcmd[i,4] := max(0.0, min(FrotorMax, raw4));
    end for;

    if dropoutActive then
      degradedFormationError := max(pre(degradedFormationError), formationErr);
    else
      degradedFormationError := pre(degradedFormationError);
    end if;
    if time >= 9.1 then
      recoveredFormationError := formationErr;
    else
      recoveredFormationError := pre(recoveredFormationError);
    end if;
  end when;

  annotation(experiment(StartTime=0, StopTime=14, Tolerance=1e-6, Interval=0.005));
end AirTrioResilientD;