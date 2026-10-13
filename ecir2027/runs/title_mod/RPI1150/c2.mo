model AirTrioResilientD
  "Three quadrotor formation with communication dropout and recovery"
  // Point-mass quadrotor abstraction with bounded rotor-thrust mixing.
  // Unstated details omitted: attitude dynamics, aerodynamic drag, sensor noise, rotor dynamics.

  // Physical parameters
  parameter Real m = 1.8 "quadrotor mass [kg]";
  parameter Real g = 9.81 "gravitational acceleration [m/s2]";
  parameter Real FrotorMax = 12.0 "per-rotor thrust bound [N]";
  parameter Real k_tilt = 2.0 "rotor differential to horizontal force mixing gain";

  // Timing
  parameter Real Ts = 0.005 "200 Hz control and sensor cycle [s]";
  parameter Real T_end = 14.0 "simulation duration [s]";
  parameter Real T_route = 9.0 "route completion time [s]";

  // Route
  parameter Real X0 = 0.0 "route start x [m]";
  parameter Real Xf = 8.0 "route final x [m]";
  parameter Real Y0 = 0.0 "route y [m]";
  parameter Real Z0 = 2.0 "route z [m]";

  // Formation offsets
  parameter Real off2x = -2.0 "robot2 offset x [m]";
  parameter Real off2y = 2.0 "robot2 offset y [m]";
  parameter Real off2z = 0.0 "robot2 offset z [m]";
  parameter Real off3x = -2.0 "robot3 offset x [m]";
  parameter Real off3y = -2.0 "robot3 offset y [m]";
  parameter Real off3z = 0.0 "robot3 offset z [m]";

  // Nominal inter-robot distances
  parameter Real d12 = 2.8284271247461903 "nominal distance robot1-robot2 [m]";
  parameter Real d13 = 2.8284271247461903 "nominal distance robot1-robot3 [m]";
  parameter Real d23 = 4.0 "nominal distance robot2-robot3 [m]";

  // Control gains
  parameter Real Kp = 8.0 "position gain [1/s2]";
  parameter Real Kd = 5.0 "velocity gain [1/s]";
  parameter Real safeDist = 1.5 "collision avoidance distance [m]";
  parameter Real kAvoid = 20.0 "collision avoidance gain [m/s2]";

  // Dropout
  parameter Real tDropStart = 4.7 "communication dropout start [s]";
  parameter Real tDropEnd = 5.7 "communication dropout end [s]";
  parameter Real distForce = 6.0 "shared disturbance force during dropout [N]";
  parameter Real eps = 1e-6 "norm zero-error branch [m]";
  parameter Real fHover = m * g / 4.0 "hover thrust per rotor [N]";

  // Continuous states
  Real p[3, 3] "robot positions [m]";
  Real v[3, 3] "robot velocities [m/s]";
  Real a_acc[3, 3] "robot accelerations [m/s2]";
  Real F[3, 3] "robot body forces [N]";
  Real f[3, 4] "actual rotor thrusts [N]";

  // Sampled sensors (proprioception and exteroception)
  Real gps[3, 3] "sampled GPS positions [m]";
  Real velMeas[3, 3] "sampled velocities [m/s]";
  Real imu[3, 3] "sampled IMU accelerations [m/s2]";
  Real range[3, 3] "sampled peer-relative ranges [m]";
  Real sensorTimestamp "synchronized sensor sample timestamp [s]";

  // Estimates
  Real estp[3, 3] "local position estimates [m]";
  Real estv[3, 3] "local velocity estimates [m/s]";

  // Last-received peer state with timestamps
  Real rxp[3, 3, 3] "last received peer positions [m]";
  Real rxv[3, 3, 3] "last received peer velocities [m/s]";
  Real rxt[3, 3] "last received peer timestamps [s]";

  // Predictions
  Real predp[3, 3, 3] "predicted peer positions [m]";
  Real predv[3, 3, 3] "predicted peer velocities [m/s]";
  Real ades[3, 3] "distributed desired accelerations [m/s2]";
  Real fcmd[3, 4] "rotor thrust commands [N]";

  // Route trajectory
  Real eta;
  Real routeX;
  Real routeY;
  Real routeZ;
  Real routeVx;
  Real routeVy;
  Real routeVz;
  Real routeAx;
  Real routeAy;
  Real routeAz;

  // Status
  Boolean dropoutActive;
  Boolean communicationAvailable;
  Real distForceNow;

  // Metrics
  Real primaryTrackingError;
  Boolean primaryTrackingErrorOK;
  Real formationErr;
  Real degradedFormationError;
  Real recoveredFormationError;
  Real minRange;
  Boolean collisionFree;
  Real actuatorMin;
  Real actuatorMax;
  Boolean actuatorBoundOK;
  Boolean routeCompleted;

protected
  Real e1x, e1y, e1z, ev1x, ev1y, ev1z;
  Real e2x, e2y, e2z, ev2x, ev2y, ev2z;
  Real e3x, e3y, e3z, ev3x, ev3y, ev3z;
  Real pdes2x, pdes2y, pdes2z, pdes3x, pdes3y, pdes3z;
  Real Tcmd, Fxcmd, Fycmd, raw1, raw2, raw3, raw4;
  Real dtPred;
  Real r12, r13, r23;
  Real rep12x, rep12y, rep12z, rep13x, rep13y, rep13z;
  Real rep21x, rep21y, rep21z, rep23x, rep23y, rep23z;
  Real rep31x, rep31y, rep31z, rep32x, rep32y, rep32z;
  Real rangeTrue12, rangeTrue13, rangeTrue23;

initial equation
  p[1,1] = 0.0;  p[1,2] = 0.0;  p[1,3] = 2.0;
  p[2,1] = -2.0; p[2,2] = 2.0;  p[2,3] = 2.0;
  p[3,1] = -2.0; p[3,2] = -2.0; p[3,3] = 2.0;
  for i in 1:3 loop
    for k in 1:3 loop
      v[i,k] = 0.0;
    end for;
  end for;
  gps = fill(0.0, 3, 3);
  velMeas = fill(0.0, 3, 3);
  imu = fill(0.0, 3, 3);
  range = fill(0.0, 3, 3);
  sensorTimestamp = 0.0;
  rxp = fill(0.0, 3, 3, 3);
  rxv = fill(0.0, 3, 3, 3);
  rxt = fill(0.0, 3, 3);
  predp = fill(0.0, 3, 3, 3);
  predv = fill(0.0, 3, 3, 3);
  ades = fill(0.0, 3, 3);
  fcmd = fill(fHover, 3, 4);
  degradedFormationError = 0.0;
  recoveredFormationError = 0.0;

equation
  dropoutActive = time >= tDropStart and time <= tDropEnd;
  communicationAvailable = not dropoutActive;
  distForceNow = if dropoutActive then distForce else 0.0;

  eta = if time <= T_route then time / T_route else 1.0;
  routeX = X0 + (Xf - X0) * (10.0*eta*eta*eta - 15.0*eta*eta*eta*eta + 6.0*eta*eta*eta*eta*eta);
  routeY = Y0;
  routeZ = Z0;
  routeVx = if time <= T_route then (Xf - X0)/T_route * (30.0*eta*eta - 60.0*eta*eta*eta + 30.0*eta*eta*eta*eta) else 0.0;
  routeVy = 0.0;
  routeVz = 0.0;
  routeAx = if time <= T_route then (Xf - X0)/(T_route*T_route) * (60.0*eta - 180.0*eta*eta + 120.0*eta*eta*eta) else 0.0;
  routeAy = 0.0;
  routeAz = 0.0;

  // True inter-robot ranges
  rangeTrue12 = sqrt(max((p[1,1]-p[2,1])*(p[1,1]-p[2,1]) + (p[1,2]-p[2,2])*(p[1,2]-p[2,2]) + (p[1,3]-p[2,3])*(p[1,3]-p[2,3]), eps*eps));
  rangeTrue13 = sqrt(max((p[1,1]-p[3,1])*(p[1,1]-p[3,1]) + (p[1,2]-p[3,2])*(p[1,2]-p[3,2]) + (p[1,3]-p[3,3])*(p[1,3]-p[3,3]), eps*eps));
  rangeTrue23 = sqrt(max((p[2,1]-p[3,1])*(p[2,1]-p[3,1]) + (p[2,2]-p[3,2])*(p[2,2]-p[3,2]) + (p[2,3]-p[3,3])*(p[2,3]-p[3,3]), eps*eps));

  // Estimates from sampled sensors
  for i in 1:3 loop
    for k in 1:3 loop
      estp[i,k] = gps[i,k];
      estv[i,k] = velMeas[i,k];
    end for;
  end for;

  // Rotor forces and dynamics
  for i in 1:3 loop
    f[i,1] = fcmd[i,1];
    f[i,2] = fcmd[i,2];
    f[i,3] = fcmd[i,3];
    f[i,4] = fcmd[i,4];
    F[i,1] = k_tilt * (f[i,1] - f[i,2] + f[i,3] - f[i,4]);
    F[i,2] = k_tilt * (f[i,1] + f[i,2] - f[i,3] - f[i,4]);
    F[i,3] = f[i,1] + f[i,2] + f[i,3] + f[i,4] - m * g;
    a_acc[i,1] = (F[i,1] + distForceNow) / m;
    a_acc[i,2] = F[i,2] / m;
    a_acc[i,3] = F[i,3] / m;
    for k in 1:3 loop
      der(p[i,k]) = v[i,k];
      der(v[i,k]) = a_acc[i,k];
    end for;
  end for;

  // Metrics
  primaryTrackingError = sqrt(max((p[1,1]-routeX)*(p[1,1]-routeX) + (p[1,2]-routeY)*(p[1,2]-routeY) + (p[1,3]-routeZ)*(p[1,3]-routeZ), eps*eps));
  primaryTrackingErrorOK = if time > 9.1 then primaryTrackingError < 0.6 else true;
  formationErr = max(abs(rangeTrue12 - d12), max(abs(rangeTrue13 - d13), abs(rangeTrue23 - d23)));
  minRange = min(rangeTrue12, min(rangeTrue13, rangeTrue23));
  collisionFree = minRange >= safeDist;
  routeCompleted = time >= T_route;

  actuatorMin = min(f[1,1], min(f[1,2], min(f[1,3], min(f[1,4], min(f[2,1], min(f[2,2], min(f[2,3], min(f[2,4], min(f[3,1], min(f[3,2], min(f[3,3], f[3,4])))))))))));
  actuatorMax = max(f[1,1], max(f[1,2], max(f[1,3], max(f[1,4], max(f[2,1], max(f[2,2], max(f[2,3], max(f[2,4], max(f[3,1], max(f[3,2], max(f[3,3], f[3,4])))))))))));
  actuatorBoundOK = actuatorMin >= -1e-9 and actuatorMax <= FrotorMax + 1e-9;

algorithm
  when sample(0, Ts) then
    // Sample proprioceptive and exteroceptive sensors
    for i in 1:3 loop
      for k in 1:3 loop
        gps[i,k] := p[i,k];
        velMeas[i,k] := v[i,k];
        imu[i,k] := a_acc[i,k];
      end for;
    end for;

    range[1,2] := rangeTrue12;
    range[2,1] := rangeTrue12;
    range[1,3] := rangeTrue13;
    range[3,1] := rangeTrue13;
    range[2,3] := rangeTrue23;
    range[3,2] := rangeTrue23;
    range[1,1] := 0.0;
    range[2,2] := 0.0;
    range[3,3] := 0.0;
    sensorTimestamp := time;

    // Update last-received peer state (hold during dropout)
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

    // Predict peer positions using last-received velocity
    for i in 1:3 loop
      for j in 1:3 loop
        dtPred := time - rxt[i,j];
        for k in 1:3 loop
          predp[i,j,k] := rxp[i,j,k] + rxv[i,j,k] * dtPred;
          predv[i,j,k] := rxv[i,j,k];
        end for;
      end for;
    end for;

    // Repulsion helper values
    r12 := max(range[1,2], eps);
    r13 := max(range[1,3], eps);
    r23 := max(range[2,3], eps);

    // Robot 1 control (leader tracks route)
    e1x := routeX - gps[1,1];
    e1y := routeY - gps[1,2];
    e1z := routeZ - gps[1,3];
    ev1x := routeVx - velMeas[1,1];
    ev1y := routeVy - velMeas[1,2];
    ev1z := routeVz - velMeas[1,3];
    rep12x := kAvoid * max(0.0, safeDist - r12) * (gps[1,1] - gps[2,1]) / (r12 * r12);
    rep12y := kAvoid * max(0.0, safeDist - r12) * (gps[1,2] - gps[2,2]) / (r12 * r12);
    rep12z := kAvoid * max(0.0, safeDist - r12) * (gps[1,3] - gps[2,3]) / (r12 * r12);
    rep13x := kAvoid * max(0.0, safeDist - r13) * (gps[1,1] - gps[3,1]) / (r13 * r13);
    rep13y := kAvoid * max(0.0, safeDist - r13) * (gps[1,2] - gps[3,2]) / (r13 * r13);
    rep13z := kAvoid * max(0.0, safeDist - r13) * (gps[1,3] - gps[3,3]) / (r13 * r13);
    ades[1,1] := Kp * e1x + Kd * ev1x + routeAx + rep12x + rep13x;
    ades[1,2] := Kp * e1y + Kd * ev1y + routeAy + rep12y + rep13y;
    ades[1,3] := Kp * e1z + Kd * ev1z + routeAz + rep12z + rep13z;

    // Robot 2 control (maintains formation relative to robot 1)
    pdes2x := predp[2,1,1] + off2x;
    pdes2y := predp[2,1,2] + off2y;
    pdes2z := predp[2,1,3] + off2z;
    e2x := pdes2x - gps[2,1];
    e2y := pdes2y - gps[2,2];
    e2z := pdes2z - gps[2,3];
    ev2x := predv[2,1,1] - velMeas[2,1];
    ev2y := predv[2,1,2] - velMeas[2,2];
    ev2z := predv[2,1,3] - velMeas[2,3];
    rep21x := kAvoid * max(0.0, safeDist - r12) * (gps[2,1] - gps[1,1]) / (r12 * r12);
    rep21y := kAvoid * max(0.0, safeDist - r12) * (gps[2,2] - gps[1,2]) / (r12 * r12);
    rep21z := kAvoid * max(0.0, safeDist - r12) * (gps[2,3] - gps[1,3]) / (r12 * r12);
    rep23x := kAvoid * max(0.0, safeDist - r23) * (gps[2,1] - gps[3,1]) / (r23 * r23);
    rep23y := kAvoid * max(0.0, safeDist - r23) * (gps[2,2] - gps[3,2]) / (r23 * r23);
    rep23z := kAvoid * max(0.0, safeDist - r23) * (gps[2,3] - gps[3,3]) / (r23 * r23);
    ades[2,1] := Kp * e2x + Kd * ev2x + rep21x + rep23x;
    ades[2,2] := Kp * e2y + Kd * ev2y + rep21y + rep23y;
    ades[2,3] := Kp * e2z + Kd * ev2z + rep21z + rep23z;

    // Robot 3 control (maintains formation relative to robot 1)
    pdes3x := predp[3,1,1] + off3x;
    pdes3y := predp[3,1,2] + off3y;
    pdes3z := predp[3,1,3] + off3z;
    e3x := pdes3x - gps[3,1];
    e3y := pdes3y - gps[3,2];
    e3z := pdes3z - gps[3,3];
    ev3x := predv[3,1,1] - velMeas[3,1];
    ev3y := predv[3,1,2] - velMeas[3,2];
    ev3z := predv[3,1,3] - velMeas[3,3];
    rep31x := kAvoid * max(0.0, safeDist - r13) * (gps[3,1] - gps[1,1]) / (r13 * r13);
    rep31y := kAvoid * max(0.0, safeDist - r13) * (gps[3,2] - gps[1,2]) / (r13 * r13);
    rep31z := kAvoid * max(0.0, safeDist - r13) * (gps[3,3] - gps[1,3]) / (r13 * r13);
    rep32x := kAvoid * max(0.0, safeDist - r23) * (gps[3,1] - gps[2,1]) / (r23 * r23);
    rep32y := kAvoid * max(0.0, safeDist - r23) * (gps[3,2] - gps[2,2]) / (r23 * r23);
    rep32z := kAvoid * max(0.0, safeDist - r23) * (gps[3,3] - gps[2,3]) / (r23 * r23);
    ades[3,1] := Kp * e3x + Kd * ev3x + rep31x + rep32x;
    ades[3,2] := Kp * e3y + Kd * ev3y + rep31y + rep32y;
    ades[3,3] := Kp * e3z + Kd * ev3z + rep31z + rep32z;

    // Bounded rotor-thrust mixing (12 independent rotor groups)
    for i in 1:3 loop
      Tcmd := max(0.0, min(4.0 * FrotorMax, m * (g + ades[i,3])));
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

    // Track degraded and recovered formation errors
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

  annotation(experiment(StartTime = 0, StopTime = 14, Tolerance = 1e-6, Interval = 0.005));
end AirTrioResilientD;