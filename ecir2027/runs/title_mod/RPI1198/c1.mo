model MarinePairResilientD
  // Physical and embodiment parameters (stated values are from the request;
  // unspecified physical details are finite assumptions and commented as such).
  parameter Real m(unit="kg")=80 "mass of each AUV";
  parameter Real b(unit="N.s/m")=60 "linear hydrodynamic damping (unspecified, finite assumption)";
  parameter Real FthrusterMax(unit="N")=105 "per-thruster bound";
  parameter Real FdistX(unit="N")=40 "one shared environmental disturbance applied only during dropout";
  parameter Real tau_modem(unit="s")=0.05 "finite acoustic modem delay (unspecified, finite assumption)";
  parameter Real Ts(unit="s")=0.005 "200 Hz control and sensor sample period";
  parameter Real tRoute(unit="s")=8.0 "route completion time";
  parameter Real tDropStart(unit="s")=6.0 "communication dropout start (inside middle third of 14 s)";
  parameter Real tDropEnd(unit="s")=7.0 "communication dropout end, 1 s finite dropout";
  parameter Real tRecoverEval(unit="s")=10.0 "recovered formation evaluation time";
  parameter Real L(unit="m")=2.0 "requested formation separation along surge";
  parameter Real xEnd(unit="m")=10.0 "route end surge position";
  parameter Real zEnd(unit="m")=3.0 "route end depth (positive downward)";
  parameter Real safeDist(unit="m")=1.2 "collision avoidance threshold";
  parameter Real kp=4 "position gain (1/s^2)";
  parameter Real kd=10 "velocity gain (1/s)";
  parameter Real kform=0.2 "distributed formation coupling gain";
  parameter Real kcoll(unit="N/m")=200 "collision repulsion gain";
  parameter Real routeTol(unit="m")=0.5 "route completion tolerance";
  parameter Real eps(unit="m2")=1e-6 "zero-error branch for norms (m^2)";

  // Physical states of the AUV pair
  output Real x1(unit="m", start=0) "AUV1 surge position";
  output Real z1(unit="m", start=0) "AUV1 depth";
  output Real vx1(unit="m/s", start=0) "AUV1 surge velocity";
  output Real vz1(unit="m/s", start=0) "AUV1 heave velocity";
  output Real x2(unit="m", start=-L) "AUV2 surge position";
  output Real z2(unit="m", start=0) "AUV2 depth";
  output Real vx2(unit="m/s", start=0) "AUV2 surge velocity";
  output Real vz2(unit="m/s", start=0) "AUV2 heave velocity";

  // Eight bidirectional thruster channels, each bounded to [-105, 105] N
  output Real u1s1(unit="N", start=0) "AUV1 surge thruster 1";
  output Real u1s2(unit="N", start=0) "AUV1 surge thruster 2";
  output Real u1h1(unit="N", start=0) "AUV1 heave thruster 1";
  output Real u1h2(unit="N", start=0) "AUV1 heave thruster 2";
  output Real u2s1(unit="N", start=0) "AUV2 surge thruster 1";
  output Real u2s2(unit="N", start=0) "AUV2 surge thruster 2";
  output Real u2h1(unit="N", start=0) "AUV2 heave thruster 1";
  output Real u2h2(unit="N", start=0) "AUV2 heave thruster 2";

  // Local proprioceptive and exteroceptive sensor traces
  output Real imuAx1(unit="m/s2") "AUV1 IMU surge acceleration";
  output Real imuAz1(unit="m/s2") "AUV1 IMU heave acceleration";
  output Real imuAx2(unit="m/s2") "AUV2 IMU surge acceleration";
  output Real imuAz2(unit="m/s2") "AUV2 IMU heave acceleration";
  output Real depth1(unit="m") "AUV1 pressure depth";
  output Real depth2(unit="m") "AUV2 pressure depth";
  output Real dvlVx1(unit="m/s") "AUV1 DVL surge velocity";
  output Real dvlVz1(unit="m/s") "AUV1 DVL heave velocity";
  output Real dvlVx2(unit="m/s") "AUV2 DVL surge velocity";
  output Real dvlVz2(unit="m/s") "AUV2 DVL heave velocity";

  // Last-received peer state with timestamps
  output Real rx1X(unit="m", start=-L) "AUV1 last-received AUV2 surge";
  output Real rx1Z(unit="m", start=0) "AUV1 last-received AUV2 depth";
  output Real rx1Vx(unit="m/s", start=0) "AUV1 last-received AUV2 surge velocity";
  output Real rx1Vz(unit="m/s", start=0) "AUV1 last-received AUV2 heave velocity";
  output Real rx1Time(unit="s", start=0) "AUV1 timestamp of last peer state";
  output Real rx2X(unit="m", start=0) "AUV2 last-received AUV1 surge";
  output Real rx2Z(unit="m", start=0) "AUV2 last-received AUV1 depth";
  output Real rx2Vx(unit="m/s", start=0) "AUV2 last-received AUV1 surge velocity";
  output Real rx2Vz(unit="m/s", start=0) "AUV2 last-received AUV1 heave velocity";
  output Real rx2Time(unit="s", start=0) "AUV2 timestamp of last peer state";

  // Finite predicted peer estimates used by distributed control during dropout
  output Real x2hat1(unit="m") "AUV1 predicted AUV2 surge";
  output Real z2hat1(unit="m") "AUV1 predicted AUV2 depth";
  output Real vx2hat1(unit="m/s") "AUV1 predicted AUV2 surge velocity";
  output Real vz2hat1(unit="m/s") "AUV1 predicted AUV2 heave velocity";
  output Real x1hat2(unit="m") "AUV2 predicted AUV1 surge";
  output Real z1hat2(unit="m") "AUV2 predicted AUV1 depth";
  output Real vx1hat2(unit="m/s") "AUV2 predicted AUV1 surge velocity";
  output Real vz1hat2(unit="m/s") "AUV2 predicted AUV1 heave velocity";

  // Requirement traces and flags
  output Boolean dropoutActive "true during controlled 1 s communication dropout";
  output Real routeProgress "dimensionless route fraction";
  output Real primaryTrackingError(unit="m") "AUV1 route tracking error";
  output Real formationError(unit="m") "pair formation error";
  output Real formationErrorDegraded(unit="m", start=0) "formation error sampled at dropout end";
  output Real formationErrorRecovered(unit="m", start=0) "formation error sampled after recovery";
  output Real primaryTrackingErrorAt91(unit="m", start=0) "primary tracking error sampled at 9.1 s";
  output Real routeCompletedFlag(start=0) "1 when route completed within tolerance";

protected
  Boolean commAvailable;
  Real s;
  Real sdot;
  Real sddot;
  Real xRef1(unit="m"), xRef2(unit="m"), zRef1(unit="m"), zRef2(unit="m");
  Real vxRef1(unit="m/s"), vzRef1(unit="m/s"), vxRef2(unit="m/s"), vzRef2(unit="m/s");
  Real axRef1(unit="m/s2"), azRef1(unit="m/s2"), axRef2(unit="m/s2"), azRef2(unit="m/s2");
  Real x2_delayed(unit="m"), z2_delayed(unit="m"), x1_delayed(unit="m"), z1_delayed(unit="m");
  Real vx2_delayed(unit="m/s"), vz2_delayed(unit="m/s"), vx1_delayed(unit="m/s"), vz1_delayed(unit="m/s");
  Real dt1(unit="s"), dt2(unit="s");
  Real dx12(unit="m"), dz12(unit="m"), d12(unit="m"), dx21(unit="m"), dz21(unit="m"), d21(unit="m");
  Real Fcoll1x(unit="N"), Fcoll1z(unit="N"), Fcoll2x(unit="N"), Fcoll2z(unit="N");
  Real Fsurge1_raw(unit="N"), Fsurge1_sat(unit="N"), Fheave1_raw(unit="N"), Fheave1_sat(unit="N");
  Real Fsurge2_raw(unit="N"), Fsurge2_sat(unit="N"), Fheave2_raw(unit="N"), Fheave2_sat(unit="N");

equation
  dropoutActive = time >= tDropStart and time < tDropEnd;
  commAvailable = not dropoutActive;

  // Smooth finite route from (0,0) to (xEnd,zEnd) and hold after tRoute
  s = if time < tRoute then 0.5*(1.0 - cos(Modelica.Constants.pi*time/tRoute)) else 1.0;
  sdot = if time < tRoute then 0.5*(Modelica.Constants.pi/tRoute)*sin(Modelica.Constants.pi*time/tRoute) else 0.0;
  sddot = if time < tRoute then 0.5*(Modelica.Constants.pi/tRoute)^2*cos(Modelica.Constants.pi*time/tRoute) else 0.0;

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

  // Delayed acoustic modem signals
  x2_delayed = delay(x2, tau_modem, 2.0);
  z2_delayed = delay(z2, tau_modem, 2.0);
  vx2_delayed = delay(vx2, tau_modem, 2.0);
  vz2_delayed = delay(vz2, tau_modem, 2.0);
  x1_delayed = delay(x1, tau_modem, 2.0);
  z1_delayed = delay(z1, tau_modem, 2.0);
  vx1_delayed = delay(vx1, tau_modem, 2.0);
  vz1_delayed = delay(vz1, tau_modem, 2.0);

  // Prediction from last received peer state and timestamp
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
  imuAx1 = (u1s1 + u1s2 + (if dropoutActive then FdistX else 0.0) - b*vx1)/m;
  imuAz1 = (u1h1 + u1h2 - b*vz1)/m;
  imuAx2 = (u2s1 + u2s2 + (if dropoutActive then FdistX else 0.0) - b*vx2)/m;
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
    // Acoustic modem reception with finite delay; no reception during dropout
    if commAvailable and time >= tau_modem then
      rx1X := x2_delayed;
      rx1Z := z2_delayed;
      rx1Vx := vx2_delayed;
      rx1Vz := vz2_delayed;
      rx1Time := time - tau_modem;
      rx2X := x1_delayed;
      rx2Z := z1_delayed;
      rx2Vx := vx1_delayed;
      rx2Vz := vz1_delayed;
      rx2Time := time - tau_modem;
    else
      rx1X := rx1X;
      rx1Z := rx1Z;
      rx1Vx := rx1Vx;
      rx1Vz := rx1Vz;
      rx1Time := rx1Time;
      rx2X := rx2X;
      rx2Z := rx2Z;
      rx2Vx := rx2Vx;
      rx2Vz := rx2Vz;
      rx2Time := rx2Time;
    end if;

    // Degraded and recovered formation error samples
    if abs(time - tDropEnd) <= Ts/2 then
      formationErrorDegraded := formationError;
    else
      formationErrorDegraded := formationErrorDegraded;
    end if;
    if abs(time - tRecoverEval) <= Ts/2 then
      formationErrorRecovered := formationError;
    else
      formationErrorRecovered := formationErrorRecovered;
    end if;
    if abs(time - 9.1) <= Ts/2 then
      primaryTrackingErrorAt91 := primaryTrackingError;
    else
      primaryTrackingErrorAt91 := primaryTrackingErrorAt91;
    end if;

    // Route completion latch
    if time >= tRoute and routeCompletedFlag < 0.5 and abs(x1 - xEnd) <= routeTol and abs(z1 - zEnd) <= routeTol then
      routeCompletedFlag := 1.0;
    else
      routeCompletedFlag := routeCompletedFlag;
    end if;

    // Collision avoidance with zero-error branch in the norm
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

    // Distributed AUV1 control: route plus predicted-peer formation coupling
    Fsurge1_raw := m*(axRef1 + kp*((xRef1 - x1) + kform*((x2hat1 + L) - x1)) + kd*((vxRef1 - vx1) + kform*(vx2hat1 - vx1))) + b*vx1 + Fcoll1x;
    Fsurge1_sat := max(-2.0*FthrusterMax, min(2.0*FthrusterMax, Fsurge1_raw));
    u1s1 := max(-FthrusterMax, min(FthrusterMax, Fsurge1_sat/2.0));
    u1s2 := u1s1;
    Fheave1_raw := m*(azRef1 + kp*((zRef1 - z1) + kform*(z2hat1 - z1)) + kd*((vzRef1 - vz1) + kform*(vz2hat1 - vz1))) + b*vz1 + Fcoll1z;
    Fheave1_sat := max(-2.0*FthrusterMax, min(2.0*FthrusterMax, Fheave1_raw));
    u1h1 := max(-FthrusterMax, min(FthrusterMax, Fheave1_sat/2.0));
    u1h2 := u1h1;

    // Distributed AUV2 control: route plus predicted-peer formation coupling
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