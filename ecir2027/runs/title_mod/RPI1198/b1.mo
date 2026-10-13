model MarinePairResilientD
  // Parameters with explicit SI units in comments
  parameter Real m=80 "kg, mass of each AUV";
  parameter Real b=60 "N.s/m, linear hydrodynamic damping (unspecified, finite assumption)";
  parameter Real FthrusterMax=105 "N, per-thruster bound";
  parameter Real FdistX=40 "N, shared environmental disturbance applied only during dropout";
  parameter Real Ts=0.005 "s, 200 Hz control and sensor sample period";
  parameter Real tRoute=8.0 "s, route completion time";
  parameter Real tDropStart=6.0 "s, communication dropout start (middle third of 14 s)";
  parameter Real tDropEnd=7.0 "s, communication dropout end, 1 s finite dropout";
  parameter Real tRecoverEval=10.0 "s, recovered formation evaluation time";
  parameter Real L=2.0 "m, requested formation separation along surge";
  parameter Real xEnd=10.0 "m, route end surge position";
  parameter Real zEnd=3.0 "m, route end depth (positive downward)";
  parameter Real safeDist=1.2 "m, collision avoidance threshold";
  parameter Real kp=4 "position gain (1/s^2)";
  parameter Real kd=10 "velocity gain (1/s)";
  parameter Real kform=0.2 "distributed formation coupling gain";
  parameter Real kcoll=200 "N/m, collision repulsion gain";
  parameter Real routeTol=0.5 "m, route completion tolerance";
  parameter Real eps=1e-6 "m^2, zero-error branch for norms";
  constant Real pi=3.14159265358979323846;

  // Physical states of the AUV pair
  output Real x1(start=0) "m, AUV1 surge position";
  output Real z1(start=0) "m, AUV1 depth";
  output Real vx1(start=0) "m/s, AUV1 surge velocity";
  output Real vz1(start=0) "m/s, AUV1 heave velocity";
  output Real x2(start=-2.0) "m, AUV2 surge position";
  output Real z2(start=0) "m, AUV2 depth";
  output Real vx2(start=0) "m/s, AUV2 surge velocity";
  output Real vz2(start=0) "m/s, AUV2 heave velocity";

  // Eight bidirectional thruster channels, each bounded to [-105,105] N
  output Real u1s1(start=0) "N, AUV1 surge thruster 1";
  output Real u1s2(start=0) "N, AUV1 surge thruster 2";
  output Real u1h1(start=0) "N, AUV1 heave thruster 1";
  output Real u1h2(start=0) "N, AUV1 heave thruster 2";
  output Real u2s1(start=0) "N, AUV2 surge thruster 1";
  output Real u2s2(start=0) "N, AUV2 surge thruster 2";
  output Real u2h1(start=0) "N, AUV2 heave thruster 1";
  output Real u2h2(start=0) "N, AUV2 heave thruster 2";

  // Local proprioceptive and exteroceptive sensor traces
  output Real imuAx1 "m/s^2, AUV1 IMU surge acceleration";
  output Real imuAz1 "m/s^2, AUV1 IMU heave acceleration";
  output Real imuAx2 "m/s^2, AUV2 IMU surge acceleration";
  output Real imuAz2 "m/s^2, AUV2 IMU heave acceleration";
  output Real depth1 "m, AUV1 pressure depth";
  output Real depth2 "m, AUV2 pressure depth";
  output Real dvlVx1 "m/s, AUV1 DVL surge velocity";
  output Real dvlVz1 "m/s, AUV1 DVL heave velocity";
  output Real dvlVx2 "m/s, AUV2 DVL surge velocity";
  output Real dvlVz2 "m/s, AUV2 DVL heave velocity";

  // Last-received peer state with timestamps
  output Real rx1X(start=-2.0) "m, AUV1 last-received AUV2 surge";
  output Real rx1Z(start=0) "m, AUV1 last-received AUV2 depth";
  output Real rx1Vx(start=0) "m/s, AUV1 last-received AUV2 surge velocity";
  output Real rx1Vz(start=0) "m/s, AUV1 last-received AUV2 heave velocity";
  output Real rx1Time(start=0) "s, AUV1 timestamp of last peer state";
  output Real rx2X(start=0) "m, AUV2 last-received AUV1 surge";
  output Real rx2Z(start=0) "m, AUV2 last-received AUV1 depth";
  output Real rx2Vx(start=0) "m/s, AUV2 last-received AUV1 surge velocity";
  output Real rx2Vz(start=0) "m/s, AUV2 last-received AUV1 heave velocity";
  output Real rx2Time(start=0) "s, AUV2 timestamp of last peer state";

  // Finite predicted peer estimates used by distributed control during dropout
  output Real x2hat1 "m, AUV1 predicted AUV2 surge";
  output Real z2hat1 "m, AUV1 predicted AUV2 depth";
  output Real vx2hat1 "m/s, AUV1 predicted AUV2 surge velocity";
  output Real vz2hat1 "m/s, AUV1 predicted AUV2 heave velocity";
  output Real x1hat2 "m, AUV2 predicted AUV1 surge";
  output Real z1hat2 "m, AUV2 predicted AUV1 depth";
  output Real vx1hat2 "m/s, AUV2 predicted AUV1 surge velocity";
  output Real vz1hat2 "m/s, AUV2 predicted AUV1 heave velocity";

  // Requirement traces and flags
  output Boolean dropoutActive "true during controlled 1 s communication dropout";
  output Real routeProgress "dimensionless route fraction";
  output Real primaryTrackingError "m, AUV1 route tracking error";
  output Real formationError "m, pair formation error";
  output Real formationErrorDegraded(start=0) "m, formation error sampled at dropout end";
  output Real formationErrorRecovered(start=0) "m, formation error sampled after recovery";
  output Real primaryTrackingErrorAt91(start=0) "m, primary tracking error sampled at 9.1 s";
  output Real routeCompletedFlag(start=0) "1 when route completed within tolerance";

protected
  Real s, sdot, sddot;
  Real xRef1, xRef2, zRef1, zRef2;
  Real vxRef1, vzRef1, vxRef2, vzRef2;
  Real axRef1, azRef1, axRef2, azRef2;
  Real dt1, dt2;
  Real dx12, dz12, d12, dx21, dz21, d21;
  Real Fcoll1x, Fcoll1z, Fcoll2x, Fcoll2z;
  Real Fsurge1_raw, Fheave1_raw, Fsurge2_raw, Fheave2_raw;
  Real Fsurge1_sat, Fheave1_sat, Fsurge2_sat, Fheave2_sat;
  Real Fdist;

equation
  // Dropout and disturbance
  dropoutActive = time >= tDropStart and time < tDropEnd;
  Fdist = if dropoutActive then FdistX else 0.0;

  // Smooth finite route from (0,0) to (xEnd,zEnd), hold after tRoute
  s = if time < tRoute then 0.5*(1.0 - cos(pi*time/tRoute)) else 1.0;
  sdot = if time < tRoute then 0.5*(pi/tRoute)*sin(pi*time/tRoute) else 0.0;
  sddot = if time < tRoute then 0.5*(pi/tRoute)^2*cos(pi*time/tRoute) else 0.0;

  xRef1 = xEnd*s;
  zRef1 = zEnd*s;
  vxRef1 = xEnd*sdot;
  vzRef1 = zEnd*sdot;
  axRef1 = xEnd*sddot;
  azRef1 = zEnd*sddot;
  xRef2 = xRef1 - L;
  zRef2 = zRef1;
  vxRef2 = vxRef1;
  vzRef2 = vzRef1;
  axRef2 = axRef1;
  azRef2 = azRef1;

  routeProgress = s;
  primaryTrackingError = sqrt((x1 - xRef1)^2 + (z1 - zRef1)^2 + eps);
  formationError = sqrt((x2 - x1 + L)^2 + (z2 - z1)^2 + eps);

  // Dead-reckoning prediction from last-received peer state and timestamp
  dt1 = max(time - rx1Time, 0.0);
  x2hat1 = rx1X + rx1Vx*dt1;
  z2hat1 = rx1Z + rx1Vz*dt1;
  vx2hat1 = rx1Vx;
  vz2hat1 = rx1Vz;
  dt2 = max(time - rx2Time, 0.0);
  x1hat2 = rx2X + rx2Vx*dt2;
  z1hat2 = rx2Z + rx2Vz*dt2;
  vx1hat2 = rx2Vx;
  vz1hat2 = rx2Vz;

  // Ideal sensor equations (no noise invented)
  imuAx1 = (u1s1 + u1s2 + Fdist - b*vx1)/m;
  imuAz1 = (u1h1 + u1h2 - b*vz1)/m;
  imuAx2 = (u2s1 + u2s2 + Fdist - b*vx2)/m;
  imuAz2 = (u2h1 + u2h2 - b*vz2)/m;
  depth1 = z1;
  depth2 = z2;
  dvlVx1 = vx1;
  dvlVz1 = vz1;
  dvlVx2 = vx2;
  dvlVz2 = vz2;

  // Plant dynamics
  der(x1) = vx1;
  der(z1) = vz1;
  der(vx1) = imuAx1;
  der(vz1) = imuAz1;
  der(x2) = vx2;
  der(z2) = vz2;
  der(vx2) = imuAx2;
  der(vz2) = imuAz2;

algorithm
  when sample(0, Ts) then
    // Acoustic modem reception: update peer state when communication available;
    // hold last-received state during dropout (prediction fills the gap)
    if not (time >= tDropStart and time < tDropEnd) then
      rx1X := x2;
      rx1Z := z2;
      rx1Vx := vx2;
      rx1Vz := vz2;
      rx1Time := time;
      rx2X := x1;
      rx2Z := z1;
      rx2Vx := vx1;
      rx2Vz := vz1;
      rx2Time := time;
    end if;

    // Degraded formation error sample at dropout end
    if abs(time - tDropEnd) <= Ts/2 then
      formationErrorDegraded := formationError;
    end if;

    // Recovered formation error sample
    if abs(time - tRecoverEval) <= Ts/2 then
      formationErrorRecovered := formationError;
    end if;

    // Primary tracking error sample at 9.1 s
    if abs(time - 9.1) <= Ts/2 then
      primaryTrackingErrorAt91 := primaryTrackingError;
    end if;

    // Route completion latch
    if time >= tRoute and routeCompletedFlag < 0.5 and abs(x1 - xEnd) <= routeTol and abs(z1 - zEnd) <= routeTol then
      routeCompletedFlag := 1.0;
    end if;

    // Collision avoidance with zero-error branch in the norm (AUV1 vs predicted AUV2)
    dx12 := x1 - x2hat1;
    dz12 := z1 - z2hat1;
    d12 := sqrt(dx12*dx12 + dz12*dz12 + eps);
    if d12 < safeDist then
      Fcoll1x := kcoll*(safeDist - d12)*dx12/d12;
      Fcoll1z := kcoll*(safeDist - d12)*dz12/d12;
    else
      Fcoll1x := 0.0;
      Fcoll1z := 0.0;
    end if;

    // Collision avoidance (AUV2 vs predicted AUV1)
    dx21 := x2 - x1hat2;
    dz21 := z2 - z1hat2;
    d21 := sqrt(dx21*dx21 + dz21*dz21 + eps);
    if d21 < safeDist then
      Fcoll2x := kcoll*(safeDist - d21)*dx21/d21;
      Fcoll2z := kcoll*(safeDist - d21)*dz21/d21;
    else
      Fcoll2x := 0.0;
      Fcoll2z := 0.0;
    end if;

    // Distributed AUV1 control: route tracking plus predicted-peer formation coupling
    Fsurge1_raw := m*(axRef1 + kp*((xRef1 - x1) + kform*((x2hat1 + L) - x1)) + kd*((vxRef1 - vx1) + kform*(vx2hat1 - vx1))) + b*vx1 + Fcoll1x;
    Fsurge1_sat := max(-2.0*FthrusterMax, min(2.0*FthrusterMax, Fsurge1_raw));
    u1s1 := max(-FthrusterMax, min(FthrusterMax, Fsurge1_sat/2.0));
    u1s2 := u1s1;
    Fheave1_raw := m*(azRef1 + kp*((zRef1 - z1) + kform*(z2hat1 - z1)) + kd*((vzRef1 - vz1) + kform*(vz2hat1 - vz1))) + b*vz1 + Fcoll1z;
    Fheave1_sat := max(-2.0*FthrusterMax, min(2.0*FthrusterMax, Fheave1_raw));
    u1h1 := max(-FthrusterMax, min(FthrusterMax, Fheave1_sat/2.0));
    u1h2 := u1h1;

    // Distributed AUV2 control: route tracking plus predicted-peer formation coupling
    Fsurge2_raw := m*(axRef2 + kp*((xRef2 - x2) + kform*((x1hat2 - L) - x2)) + kd*((vxRef2 - vx2) + kform*(vx1hat2 - vx2))) + b*vx2 + Fcoll2x;
    Fsurge2_sat := max(-2.0*FthrusterMax, min(2.0*FthrusterMax, Fsurge2_raw));
    u2s1 := max(-FthrusterMax, min(FthrusterMax, Fsurge2_sat/2.0));
    u2s2 := u2s1;
    Fheave2_raw := m*(azRef2 + kp*((zRef2 - z2) + kform*(z1hat2 - z2)) + kd*((vzRef2 - vz2) + kform*(vz1hat2 - vz2))) + b*vz2 + Fcoll2z;
    Fheave2_sat := max(-2.0*FthrusterMax, min(2.0*FthrusterMax, Fheave2_raw));
    u2h1 := max(-FthrusterMax, min(FthrusterMax, Fheave2_sat/2.0));
    u2h2 := u2h1;
  end when;

  annotation(experiment(StopTime=14, Tolerance=1e-6, Interval=0.005));
end MarinePairResilientD;