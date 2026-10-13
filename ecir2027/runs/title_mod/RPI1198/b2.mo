model MarinePairResilientD
  parameter Real m=80 "kg, mass of each AUV";
  parameter Real b=60 "N.s/m, linear hydrodynamic damping";
  parameter Real FthrusterMax=105 "N, per-thruster bound";
  parameter Real FdistX=40 "N, shared environmental disturbance during dropout";
  parameter Real Ts=0.005 "s, 200 Hz sample period";
  parameter Real tRoute=8.0 "s, route completion time";
  parameter Real tDropStart=6.0 "s, communication dropout start";
  parameter Real tDropEnd=7.0 "s, communication dropout end";
  parameter Real tRecoverEval=10.0 "s, recovered formation evaluation time";
  parameter Real L=2.0 "m, formation separation along surge";
  parameter Real xEnd=10.0 "m, route end surge position";
  parameter Real zEnd=3.0 "m, route end depth";
  parameter Real safeDist=1.2 "m, collision avoidance threshold";
  parameter Real kp=4 "1/s^2, position gain";
  parameter Real kd=10 "1/s, velocity gain";
  parameter Real kform=0.2 "formation coupling gain";
  parameter Real kcoll=200 "N/m, collision repulsion gain";
  parameter Real routeTol=0.5 "m, route completion tolerance";
  parameter Real eps=1e-6 "m^2, zero-error branch for norms";
  constant Real pi=3.14159265358979323846;

  output Real x1(start=0) "m, AUV1 surge position";
  output Real z1(start=0) "m, AUV1 depth";
  output Real vx1(start=0) "m/s, AUV1 surge velocity";
  output Real vz1(start=0) "m/s, AUV1 heave velocity";
  output Real x2(start=-2.0) "m, AUV2 surge position";
  output Real z2(start=0) "m, AUV2 depth";
  output Real vx2(start=0) "m/s, AUV2 surge velocity";
  output Real vz2(start=0) "m/s, AUV2 heave velocity";

  output Real u1s1 "N, AUV1 surge thruster 1";
  output Real u1s2 "N, AUV1 surge thruster 2";
  output Real u1h1 "N, AUV1 heave thruster 1";
  output Real u1h2 "N, AUV1 heave thruster 2";
  output Real u2s1 "N, AUV2 surge thruster 1";
  output Real u2s2 "N, AUV2 surge thruster 2";
  output Real u2h1 "N, AUV2 heave thruster 1";
  output Real u2h2 "N, AUV2 heave thruster 2";

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

  output discrete Real rx1X(start=-2.0) "m, AUV1 last-received AUV2 surge";
  output discrete Real rx1Z(start=0) "m, AUV1 last-received AUV2 depth";
  output discrete Real rx1Vx(start=0) "m/s, AUV1 last-received AUV2 surge velocity";
  output discrete Real rx1Vz(start=0) "m/s, AUV1 last-received AUV2 heave velocity";
  output discrete Real rx1Time(start=0) "s, AUV1 timestamp of last peer state";
  output discrete Real rx2X(start=0) "m, AUV2 last-received AUV1 surge";
  output discrete Real rx2Z(start=0) "m, AUV2 last-received AUV1 depth";
  output discrete Real rx2Vx(start=0) "m/s, AUV2 last-received AUV1 surge velocity";
  output discrete Real rx2Vz(start=0) "m/s, AUV2 last-received AUV1 heave velocity";
  output discrete Real rx2Time(start=0) "s, AUV2 timestamp of last peer state";

  output Real x2hat1 "m, AUV1 predicted AUV2 surge";
  output Real z2hat1 "m, AUV1 predicted AUV2 depth";
  output Real vx2hat1 "m/s, AUV1 predicted AUV2 surge velocity";
  output Real vz2hat1 "m/s, AUV1 predicted AUV2 heave velocity";
  output Real x1hat2 "m, AUV2 predicted AUV1 surge";
  output Real z1hat2 "m, AUV2 predicted AUV1 depth";
  output Real vx1hat2 "m/s, AUV2 predicted AUV1 surge velocity";
  output Real vz1hat2 "m/s, AUV2 predicted AUV1 heave velocity";

  output Boolean dropoutActive "true during 1 s communication dropout";
  output Real routeProgress "dimensionless route fraction";
  output Real primaryTrackingError "m, AUV1 route tracking error";
  output Real formationError "m, pair formation error";
  output discrete Real formationErrorDegraded(start=0) "m, formation error at dropout end";
  output discrete Real formationErrorRecovered(start=0) "m, formation error after recovery";
  output discrete Real primaryTrackingErrorAt91(start=0) "m, primary tracking error at 9.1 s";
  output discrete Real routeCompletedFlag(start=0) "1 when route completed";

protected
  Real s, sdot, sddot;
  Real xRef1, xRef2, zRef1, zRef2;
  Real vxRef1, vzRef1, vxRef2, vzRef2;
  Real axRef1, azRef1, axRef2, azRef2;
  Real dt1, dt2;
  Real dx12, dz12, d12, dx21, dz21, d21;
  Real Fcoll1x, Fcoll1z, Fcoll2x, Fcoll2z;
  Real Fsurge1, Fheave1, Fsurge2, Fheave2;
  Real Fsurge1_sat, Fheave1_sat, Fsurge2_sat, Fheave2_sat;
  Real Fdist;

equation
  // Communication dropout and shared disturbance
  dropoutActive = time >= tDropStart and time < tDropEnd;
  Fdist = if dropoutActive then FdistX else 0.0;

  // Smooth finite route reference
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

  // Dead-reckoning prediction from last-received peer state
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

  // Sensors
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

  // Collision avoidance with zero-error branch
  dx12 = x1 - x2hat1;
  dz12 = z1 - z2hat1;
  d12 = sqrt(dx12*dx12 + dz12*dz12 + eps);
  Fcoll1x = if noEvent(d12 < safeDist) then kcoll*(safeDist - d12)*dx12/d12 else 0.0;
  Fcoll1z = if noEvent(d12 < safeDist) then kcoll*(safeDist - d12)*dz12/d12 else 0.0;

  dx21 = x2 - x1hat2;
  dz21 = z2 - z1hat2;
  d21 = sqrt(dx21*dx21 + dz21*dz21 + eps);
  Fcoll2x = if noEvent(d21 < safeDist) then kcoll*(safeDist - d21)*dx21/d21 else 0.0;
  Fcoll2z = if noEvent(d21 < safeDist) then kcoll*(safeDist - d21)*dz21/d21 else 0.0;

  // Distributed control with prediction during dropout
  Fsurge1 = m*(axRef1 + kp*((xRef1 - x1) + kform*((x2hat1 + L) - x1)) + kd*((vxRef1 - vx1) + kform*(vx2hat1 - vx1))) + b*vx1 + Fcoll1x;
  Fsurge1_sat = max(-2.0*FthrusterMax, min(2.0*FthrusterMax, Fsurge1));
  u1s1 = max(-FthrusterMax, min(FthrusterMax, Fsurge1_sat/2.0));
  u1s2 = u1s1;
  Fheave1 = m*(azRef1 + kp*((zRef1 - z1) + kform*(z2hat1 - z1)) + kd*((vzRef1 - vz1) + kform*(vz2hat1 - vz1))) + b*vz1 + Fcoll1z;
  Fheave1_sat = max(-2.0*FthrusterMax, min(2.0*FthrusterMax, Fheave1));
  u1h1 = max(-FthrusterMax, min(FthrusterMax, Fheave1_sat/2.0));
  u1h2 = u1h1;

  Fsurge2 = m*(axRef2 + kp*((xRef2 - x2) + kform*((x1hat2 - L) - x2)) + kd*((vxRef2 - vx2) + kform*(vx1hat2 - vx2))) + b*vx2 + Fcoll2x;
  Fsurge2_sat = max(-2.0*FthrusterMax, min(2.0*FthrusterMax, Fsurge2));
  u2s1 = max(-FthrusterMax, min(FthrusterMax, Fsurge2_sat/2.0));
  u2s2 = u2s1;
  Fheave2 = m*(azRef2 + kp*((zRef2 - z2) + kform*(z1hat2 - z2)) + kd*((vzRef2 - vz2) + kform*(vz1hat2 - vz2))) + b*vz2 + Fcoll2z;
  Fheave2_sat = max(-2.0*FthrusterMax, min(2.0*FthrusterMax, Fheave2));
  u2h1 = max(-FthrusterMax, min(FthrusterMax, Fheave2_sat/2.0));
  u2h2 = u2h1;

  // Discrete state and measurement updates at 200 Hz
  when sample(0, Ts) then
    // Acoustic modem: update peer state when communication available
    if not (time >= tDropStart and time < tDropEnd) then
      rx1X = x2;
      rx1Z = z2;
      rx1Vx = vx2;
      rx1Vz = vz2;
      rx1Time = time;
      rx2X = x1;
      rx2Z = z1;
      rx2Vx = vx1;
      rx2Vz = vz1;
      rx2Time = time;
    end if;

    // Degraded formation error sample at dropout end
    if abs(time - tDropEnd) <= Ts/2 then
      formationErrorDegraded = formationError;
    end if;

    // Recovered formation error sample
    if abs(time - tRecoverEval) <= Ts/2 then
      formationErrorRecovered = formationError;
    end if;

    // Primary tracking error sample at 9.1 s
    if abs(time - 9.1) <= Ts/2 then
      primaryTrackingErrorAt91 = primaryTrackingError;
    end if;

    // Route completion latch
    if time >= tRoute and abs(x1 - xEnd) <= routeTol and abs(z1 - zEnd) <= routeTol then
      routeCompletedFlag = 1.0;
    end if;
  end when;

  annotation(experiment(StopTime=14, Tolerance=1e-6, Interval=0.005));
end MarinePairResilientD;