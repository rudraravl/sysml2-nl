model AirTrioResilientD
  "Instrumented three-quadrotor formation with 1 s communication dropout and recovery.
   Unstated details omitted: attitude/yaw dynamics, aerodynamic drag, sensor noise, rotor dynamics.
   The model uses a point-mass quadrotor abstraction with bounded rotor-thrust mixing.";

  // Physical parameters
  parameter Real m(unit="kg") = 1.8 "quadrotor mass";
  parameter Real g_acc(unit="m/s2") = 9.81 "gravitational acceleration";
  parameter Real FrotorMax(unit="N") = 12.0 "per-rotor thrust bound";
  parameter Real k_tilt = 2.0 "rotor differential-to-horizontal-force mixing gain";

  // Control and timing parameters
  parameter Real Ts(unit="s") = 0.005 "200 Hz control and sensor cycle";
  parameter Real T_end(unit="s") = 14.0 "simulation duration";
  parameter Real T_route(unit="s") = 9.0 "route completion time";
  parameter Real Kp = 8.0 "position gain";
  parameter Real Kd = 5.0 "velocity gain";
  parameter Real safeDist(unit="m") = 1.5 "collision avoidance distance";
  parameter Real kAvoid(unit="m/s2") = 20.0 "collision avoidance gain";
  parameter Real eps_n(unit="m") = 1e-6 "norm zero-error branch";

  // Route parameters
  parameter Real X0(unit="m") = 0.0 "route start x";
  parameter Real Xf(unit="m") = 8.0 "route final x";
  parameter Real Y0(unit="m") = 0.0 "route y";
  parameter Real Z0(unit="m") = 2.0 "route z";

  // Formation offsets
  parameter Real off2x(unit="m") = -2.0 "robot2 formation offset x";
  parameter Real off2y(unit="m") = 2.0 "robot2 formation offset y";
  parameter Real off2z(unit="m") = 0.0 "robot2 formation offset z";
  parameter Real off3x(unit="m") = -2.0 "robot3 formation offset x";
  parameter Real off3y(unit="m") = -2.0 "robot3 formation offset y";
  parameter Real off3z(unit="m") = 0.0 "robot3 formation offset z";

  // Desired formation distances (explicit numeric values)
  parameter Real d12(unit="m") = 2.8284271247461903 "desired distance robot1-robot2";
  parameter Real d13(unit="m") = 2.8284271247461903 "desired distance robot1-robot3";
  parameter Real d23(unit="m") = 4.0 "desired distance robot2-robot3";

  // Dropout parameters
  parameter Real tDropStart(unit="s") = 4.7 "communication dropout start";
  parameter Real tDropEnd(unit="s") = 5.7 "communication dropout end";
  parameter Real distForce(unit="N") = 6.0 "shared disturbance force during dropout";

  // Derived constants
  parameter Real middleThirdStart(unit="s") = T_end / 3.0;
  parameter Real middleThirdEnd(unit="s") = 2.0 * T_end / 3.0;
  parameter Real fHover(unit="N") = m * g_acc / 4.0 "hover thrust per rotor";

  // Continuous states
  Real p[3,3](unit="m") "robot positions, p[robot,axis]";
  Real v[3,3](unit="m/s") "robot velocities";

  // Continuous algebraic variables
  Real a_acc[3,3](unit="m/s2") "robot accelerations";
  Real F_body[3,3](unit="N") "robot body forces";
  Real f_rot[3,4](unit="N") "actual rotor thrusts";

  // True sensor values (continuous)
  Real gpsTrue[3,3](unit="m");
  Real velTrue[3,3](unit="m/s");
  Real imuTrue[3,3](unit="m/s2");
  Real rangeTrue[3,3](unit="m");

  // Local estimates (continuous, track discrete samples)
  Real estp[3,3](unit="m") "local position estimates";
  Real estv[3,3](unit="m/s") "local velocity estimates";

  // Sampled sensors (discrete)
  discrete Real gps[3,3](unit="m", start=fill(0.0, 3, 3)) "sampled GPS positions";
  discrete Real velMeas[3,3](unit="m/s", start=fill(0.0, 3, 3)) "sampled velocity";
  discrete Real imu[3,3](unit="m/s2", start=fill(0.0, 3, 3)) "sampled IMU accelerations";
  discrete Real rangeMeas[3,3](unit="m", start=fill(0.0, 3, 3)) "sampled peer-relative ranges";
  discrete Real sensorTimestamp(unit="s", start=0.0) "synchronized sensor sample timestamp";

  // Last-received peer state with timestamps (discrete)
  discrete Real rxp[3,3,3](unit="m", start=fill(0.0, 3, 3, 3)) "last received peer positions";
  discrete Real rxv[3,3,3](unit="m/s", start=fill(0.0, 3, 3, 3)) "last received peer velocities";
  discrete Real rxt[3,3](unit="s", start=fill(0.0, 3, 3)) "last received peer timestamps";

  // Predicted peer state (discrete)
  discrete Real predp[3,3,3](unit="m", start=fill(0.0, 3, 3, 3)) "predicted peer positions";
  discrete Real predv[3,3,3](unit="m/s", start=fill(0.0, 3, 3, 3)) "predicted peer velocities";

  // Distributed control commands (discrete)
  discrete Real ades[3,3](unit="m/s2", start=fill(0.0, 3, 3)) "distributed desired accelerations";
  discrete Real fcmd[3,4](unit="N", start=fill(fHover, 3, 4)) "rotor thrust commands";

  // Route trajectory (continuous)
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

  // Communication and disturbance status
  Boolean dropoutActive "continuous dropout indicator for physics";
  Boolean communicationAvailable "communication link status";
  Real distForceNow(unit="N") "current disturbance force";

  // Metrics
  Real primaryTrackingError(unit="m");
  Boolean primaryTrackingErrorOK;
  Real formationErr(unit="m");
  discrete Real degradedFormationError(unit="m", start=0.0);
  discrete Real recoveredFormationError(unit="m", start=0.0);
  Real minRange(unit="m");
  Boolean collisionFree;
  Real actuatorMinVal(unit="N");
  Real actuatorMaxVal(unit="N");
  Boolean actuatorBoundOK;
  Boolean routeCompleted;

  // Algorithm temporaries
protected
  discrete Real e1x, e1y, e1z, ev1x, ev1y, ev1z;
  discrete Real e2x, e2y, e2z, ev2x, ev2y, ev2z;
  discrete Real e3x, e3y, e3z, ev3x, ev3y, ev3z;
  discrete Real pdes2x, pdes2y, pdes2z, pdes3x, pdes3y, pdes3z;
  discrete Real Tcmd, Fxcmd, Fycmd, raw1, raw2, raw3, raw4;
  discrete Real dtPred;
  discrete Real r12, r13, r23, n12, n13, n23, nr12, nr13, nr23;
  discrete Real ax1, ay1, az1, ax2, ay2, az2, ax3, ay3, az3;
  discrete Real fminRow1, fminRow2, fminRow3;
  discrete Real fmaxRow1, fmaxRow2, fmaxRow3;

initial equation
  p[1,1] = 0.0;
  p[1,2] = 0.0;
  p[1,3] = 2.0;
  p[2,1] = -2.0;
  p[2,2] = 2.0;
  p[2,3] = 2.0;
  p[3,1] = -2.0;
  p[3,2] = -2.0;
  p[3,3] = 2.0;
  v = fill(0.0, 3, 3);

equation
  // Dropout and communication status
  dropoutActive = time >= tDropStart and time <= tDropEnd;
  communicationAvailable = not dropoutActive;
  distForceNow = if dropoutActive then distForce else 0.0;

  // Route trajectory: 5th order polynomial smooth interpolation
  eta = if time <= T_route then time / T_route else 1.0;
  routeX = X0 + (Xf - X0) * (10.0 * eta^3 - 15.0 * eta^4 + 6.0 * eta^5);
  routeY = Y0;
  routeZ = Z0;
  routeVx = if time <= T_route then (Xf - X0) / T_route * (30.0 * eta^2 - 60.0 * eta^3 + 30.0 * eta^4) else 0.0;
  routeVy = 0.0;
  routeVz = 0.0;
  routeAx = if time <= T_route then (Xf - X0) / T_route^2 * (60.0 * eta - 180.0 * eta^2 + 120.0 * eta^3) else 0.0;
  routeAy = 0.0;
  routeAz = 0.0;

  // True sensor values and estimates
  for i in 1:3 loop
    for k in 1:3 loop
      gpsTrue[i,k] = p[i,k];
      velTrue[i,k] = v[i,k];
      imuTrue[i,k] = a_acc[i,k];
      estp[i,k] = gps[i,k];
      estv[i,k] = velMeas[i,k];
    end for;
  end for;

  // Peer-relative range measurements
  rangeTrue[1,1] = 0.0;
  rangeTrue[2,2] = 0.0;
  rangeTrue[3,3] = 0.0;
  rangeTrue[1,2] = sqrt(max((p[1,1] - p[2,1])^2 + (p[1,2] - p[2,2])^2 + (p[1,3] - p[2,3])^2, eps_n * eps_n));
  rangeTrue[2,1] = rangeTrue[1,2];
  rangeTrue[1,3] = sqrt(max((p[1,1] - p[3,1])^2 + (p[1,2] - p[3,2])^2 + (p[1,3] - p[3,3])^2, eps_n * eps_n));
  rangeTrue[3,1] = rangeTrue[1,3];
  rangeTrue[2,3] = sqrt(max((p[2,1] - p[3,1])^2 + (p[2,2] - p[3,2])^2 + (p[2,3] - p[3,3])^2, eps_n * eps_n));
  rangeTrue[3,2] = rangeTrue[2,3];

  // Rotor thrust to body force mixing and dynamics
  for i in 1:3 loop
    f_rot[i,1] = fcmd[i,1];
    f_rot[i,2] = fcmd[i,2];
    f_rot[i,3] = fcmd[i,3];
    f_rot[i,4] = fcmd[i,4];
    F_body[i,1] = k_tilt * (f_rot[i,1] - f_rot[i,2] + f_rot[i,3] - f_rot[i,4]);
    F_body[i,2] = k_tilt * (f_rot[i,1] + f_rot[i,2] - f_rot[i,3] - f_rot[i,4]);
    F_body[i,3] = f_rot[i,1] + f_rot[i,2] + f_rot[i,3] + f_rot[i,4] - m * g_acc;
    a_acc[i,1] = (F_body[i,1] + distForceNow) / m;
    a_acc[i,2] = F_body[i,2] / m;
    a_acc[i,3] = F_body[i,3] / m;
    der(p[i,1]) = v[i,1];
    der(p[i,2]) = v[i,2];
    der(p[i,3]) = v[i,3];
    der(v[i,1]) = a_acc[i,1];
    der(v[i,2]) = a_acc[i,2];
    der(v[i,3]) = a_acc[i,3];
  end for;

  // Performance metrics
  primaryTrackingError = sqrt(max((p[1,1] - routeX)^2 + (p[1,2] - routeY)^2 + (p[1,3] - routeZ)^2, eps_n * eps_n));
  primaryTrackingErrorOK = if time > 9.1 then primaryTrackingError < 0.6 else true;
  formationErr = max(abs(rangeTrue[1,2] - d12), max(abs(rangeTrue[1,3] - d13), abs(rangeTrue[2,3] - d23)));
  minRange = min(rangeTrue[1,2], min(rangeTrue[1,3], rangeTrue[2,3]));
  collisionFree = minRange >= safeDist;
  routeCompleted = time >= T_route;

  // Actuator bounds (scalar nested min/max)
  fminRow1 = min(f_rot[1,1], min(f_rot[1,2], min(f_rot[1,3], f_rot[1,4])));
  fminRow2 = min(f_rot[2,1], min(f_rot[2,2], min(f_rot[2,3], f_rot[2,4])));
  fminRow3 = min(f_rot[3,1], min(f_rot[3,2], min(f_rot[3,3], f_rot[3,4])));
  actuatorMinVal = min(fminRow1, min(fminRow2, fminRow3));
  fmaxRow1 = max(f_rot[1,1], max(f_rot[1,2], max(f_rot[1,3], f_rot[1,4])));
  fmaxRow2 = max(f_rot[2,1], max(f_rot[2,2], max(f_rot[2,3], f_rot[2,4])));
  fmaxRow3 = max(f_rot[3,1], max(f_rot[3,2], max(f_rot[3,3], f_rot[3,4])));
  actuatorMaxVal = max(fmaxRow1, max(fmaxRow2, fmaxRow3));
  actuatorBoundOK = actuatorMinVal >= -1e-9 and actuatorMaxVal <= FrotorMax + 1e-9;

algorithm
  when sample(0, Ts) then
    // Sample sensors: local proprioception and exteroception
    for i in 1:3 loop
      for k in 1:3 loop
        gps[i,k] := gpsTrue[i,k];
        velMeas[i,k] := velTrue[i,k];
        imu[i,k] := imuTrue[i,k];
      end for;
    end for;
    for i in 1:3 loop
      for j in 1:3 loop
        rangeMeas[i,j] := rangeTrue[i,j];
      end for;
    end for;
    sensorTimestamp := time;

    // Update last-received peer state with timestamps
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

    // Predict peer state using constant-velocity model during dropout
    for i in 1:3 loop
      for j in 1:3 loop
        dtPred := time - rxt[i,j];
        for k in 1:3 loop
          predp[i,j,k] := rxp[i,j,k] + rxv[i,j,k] * dtPred;
          predv[i,j,k] := rxv[i,j,k];
        end for;
      end for;
    end for;

    // Collision avoidance repulsion (inlined, zero-error branch protected)
    r12 := max(rangeMeas[1,2], eps_n);
    r13 := max(rangeMeas[1,3], eps_n);
    r23 := max(rangeMeas[2,3], eps_n);
    n12 := max(0.0, safeDist - rangeMeas[1,2]);
    n13 := max(0.0, safeDist - rangeMeas[1,3]);
    n23 := max(0.0, safeDist - rangeMeas[2,3]);
    nr12 := kAvoid * n12 / (r12 * r12);
    nr13 := kAvoid * n13 / (r13 * r13);
    nr23 := kAvoid * n23 / (r23 * r23);

    // Robot 1: primary route tracking with collision avoidance
    e1x := routeX - gps[1,1];
    e1y := routeY - gps[1,2];
    e1z := routeZ - gps[1,3];
    ev1x := routeVx - velMeas[1,1];
    ev1y := routeVy - velMeas[1,2];
    ev1z := routeVz - velMeas[1,3];
    ax1 := nr12 * (gps[1,1] - gps[2,1]) + nr13 * (gps[1,1] - gps[3,1]);
    ay1 := nr12 * (gps[1,2] - gps[2,2]) + nr13 * (gps[1,2] - gps[3,2]);
    az1 := nr12 * (gps[1,3] - gps[2,3]) + nr13 * (gps[1,3] - gps[3,3]);
    ades[1,1] := Kp * e1x + Kd * ev1x + routeAx + ax1;
    ades[1,2] := Kp * e1y + Kd * ev1y + routeAy + ay1;
    ades[1,3] := Kp * e1z + Kd * ev1z + routeAz + az1;

    // Robot 2: formation tracking relative to predicted robot 1
    pdes2x := predp[2,1,1] + off2x;
    pdes2y := predp[2,1,2] + off2y;
    pdes2z := predp[2,1,3] + off2z;
    e2x := pdes2x - gps[2,1];
    e2y := pdes2y - gps[2,2];
    e2z := pdes2z - gps[2,3];
    ev2x := predv[2,1,1] - velMeas[2,1];
    ev2y := predv[2,1,2] - velMeas[2,2];
    ev2z := predv[2,1,3] - velMeas[2,3];
    ax2 := nr12 * (gps[2,1] - gps[1,1]) + nr23 * (gps[2,1] - gps[3,1]);
    ay2 := nr12 * (gps[2,2] - gps[1,2]) + nr23 * (gps[2,2] - gps[3,2]);
    az2 := nr12 * (gps[2,3] - gps[1,3]) + nr23 * (gps[2,3] - gps[3,3]);
    ades[2,1] := Kp * e2x + Kd * ev2x + ax2;
    ades[2,2] := Kp * e2y + Kd * ev2y + ay2;
    ades[2,3] := Kp * e2z + Kd * ev2z + az2;

    // Robot 3: formation tracking relative to predicted robot 1
    pdes3x := predp[3,1,1] + off3x;
    pdes3y := predp[3,1,2] + off3y;
    pdes3z := predp[3,1,3] + off3z;
    e3x := pdes3x - gps[3,1];
    e3y := pdes3y - gps[3,2];
    e3z := pdes3z - gps[3,3];
    ev3x := predv[3,1,1] - velMeas[3,1];
    ev3y := predv[3,1,2] - velMeas[3,2];
    ev3z := predv[3,1,3] - velMeas[3,3];
    ax3 := nr13 * (gps[3,1] - gps[1,1]) + nr23 * (gps[3,1] - gps[2,1]);
    ay3 := nr13 * (gps[3,2] - gps[1,2]) + nr23 * (gps[3,2] - gps[2,2]);
    az3 := nr13 * (gps[3,3] - gps[1,3]) + nr23 * (gps[3,3] - gps[2,3]);
    ades[3,1] := Kp * e3x + Kd * ev3x + ax3;
    ades[3,2] := Kp * e3y + Kd * ev3y + ay3;
    ades[3,3] := Kp * e3z + Kd * ev3z + az3;

    // Rotor thrust allocation with actuator bounds
    for i in 1:3 loop
      Tcmd := max(0.0, min(4.0 * FrotorMax, m * (g_acc + ades[i,3])));
      Fxcmd := m * ades[i,1];
      Fycmd := m * ades[i,2];
      raw1 := Tcmd / 4.0 + Fxcmd / (4.0 * k_tilt) + Fycmd / (4.0 * k_tilt);
      raw2 := Tcmd / 4.0 - Fxcmd / (4.0 * k_tilt) + Fycmd / (4.0 * k_tilt);
      raw3 := Tcmd / 4.0 + Fxcmd / (4.0 * k_tilt) - Fycmd / (4.0 * k_tilt);
      raw4 := Tcmd / 4.0 - Fxcmd / (4.0 * k_tilt) - Fycmd / (4.0 * k_tilt);
      fcmd[i,1] := max(0.0, min(FrotorMax, raw1));
      fcmd[i,2] := max(0.0, min(FrotorMax, raw2));
      fcmd[i,3] := max(0.0, min(FrotorMax, raw3));
      fcmd[i,4] := max(0.0, min(FrotorMax, raw4));
    end for;

    // Degraded and recovered formation error traces
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