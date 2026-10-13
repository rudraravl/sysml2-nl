model MarinePairResilientD
  // Physical and embodiment parameters (stated values from request;
  // unspecified physical details are finite assumptions commented as such).
  parameter Real m=80 "mass of each AUV (kg)";
  parameter Real b=60 "linear hydrodynamic damping (N.s/m, unspecified finite assumption)";
  parameter Real FthrusterMax=105 "per-thruster bound (N)";
  parameter Real FdistX=40 "one shared environmental disturbance during dropout (N)";
  parameter Real tau_modem=0.05 "acoustic modem delay (s, unspecified finite assumption)";
  parameter Real Ts=0.005 "control/sensor sample period (s), 200 Hz";
  parameter Real tRoute=8.0 "route completion time (s)";
  parameter Real tDropStart=6.0 "communication dropout start (s, middle third of 14 s)";
  parameter Real tDropEnd=7.0 "communication dropout end (s), 1 s finite dropout";
  parameter Real tRecoverEval=10.0 "recovered formation evaluation time (s)";
  parameter Real L=2.0 "requested formation separation along surge (m)";
  parameter Real xEnd=10.0 "route end surge position (m)";
  parameter Real zEnd=3.0 "route end depth (m, positive downward)";
  parameter Real safeDist=1.2 "collision avoidance threshold (m)";
  parameter Real kp=4 "position gain (1/s^2)";
  parameter Real kd=10 "velocity gain (1/s)";
  parameter Real kform=0.2 "distributed formation coupling gain";
  parameter Real kcoll=200 "collision repulsion gain (N/m)";
  parameter Real routeTol=0.5 "route completion tolerance (m)";
  parameter Real eps=1e-6 "zero-error branch for norms (m^2)";

  // Continuous physical states of the AUV pair
  Real x1(start=0, fixed=true) "AUV1 surge position (m)";
  Real z1(start=0, fixed=true) "AUV1 depth (m)";
  Real vx1(start=0, fixed=true) "AUV1 surge velocity (m/s)";
  Real vz1(start=0, fixed=true) "AUV1 heave velocity (m/s)";
  Real x2(start=-2.0, fixed=true) "AUV2 surge position (m)";
  Real z2(start=0, fixed=true) "AUV2 depth (m)";
  Real vx2(start=0, fixed=true) "AUV2 surge velocity (m/s)";
  Real vz2(start=0, fixed=true) "AUV2 heave velocity (m/s)";

  // Eight bidirectional thruster channels, each bounded to [-105, 105] N
  Real u1s1 "AUV1 surge thruster 1 (N)";
  Real u1s2 "AUV1 surge thruster 2 (N)";
  Real u1h1 "AUV1 heave thruster 1 (N)";
  Real u1h2 "AUV1 heave thruster 2 (N)";
  Real u2s1 "AUV2 surge thruster 1 (N)";
  Real u2s2 "AUV2 surge thruster 2 (N)";
  Real u2h1 "AUV2 heave thruster 1 (N)";
  Real u2h2 "AUV2 heave thruster 2 (N)";

  // Local proprioceptive and exteroceptive sensor traces
  Real imuAx1 "AUV1 IMU surge acceleration (m/s^2)";
  Real imuAz1 "AUV1 IMU heave acceleration (m/s^2)";
  Real imuAx2 "AUV2 IMU surge acceleration (m/s^2)";
  Real imuAz2 "AUV2 IMU heave acceleration (m/s^2)";
  Real depth1 "AUV1 pressure depth (m)";
  Real depth2 "AUV2 pressure depth (m)";
  Real dvlVx1 "AUV1 DVL surge velocity (m/s)";
  Real dvlVz1 "AUV1 DVL heave velocity (m/s)";
  Real dvlVx2 "AUV2 DVL surge velocity (m/s)";
  Real dvlVz2 "AUV2 DVL heave velocity (m/s)";

  // Last-received peer state with timestamps (discrete, held during dropout)
  discrete Real rx1X(start=-2.0) "AUV1 last-received AUV2 surge (m)";
  discrete Real rx1Z(start=0) "AUV1 last-received AUV2 depth (m)";
  discrete Real rx1Vx(start=0) "AUV1 last-received AUV2 surge velocity (m/s)";
  discrete Real rx1Vz(start=0) "AUV1 last-received AUV2 heave velocity (m/s)";
  discrete Real rx1Time(start=0) "AUV1 timestamp of last peer state (s)";
  discrete Real rx2X(start=0) "AUV2 last-received AUV1 surge (m)";
  discrete Real rx2Z(start=0) "AUV2 last-received AUV1 depth (m)";
  discrete Real rx2Vx(start=0) "AUV2 last-received AUV1 surge velocity (m/s)";
  discrete Real rx2Vz(start=0) "AUV2 last-received AUV1 heave velocity (m/s)";
  discrete Real rx2Time(start=0) "AUV2 timestamp of last peer state (s)";

  // Finite predicted peer estimates used by distributed control during dropout
  Real x2hat1 "AUV1 predicted AUV2 surge (m)";
  Real z2hat1 "AUV1 predicted AUV2 depth (m)";
  Real vx2hat1 "AUV1 predicted AUV2 surge velocity (m/s)";
  Real vz2hat1 "AUV1 predicted AUV2 heave velocity (m/s)";
  Real x1hat2 "AUV2 predicted AUV1 surge (m)";
  Real z1hat2 "AUV2 predicted AUV1 depth (m)";
  Real vx1hat2 "AUV2 predicted AUV1 surge velocity (m/s)";
  Real vz1hat2 "AUV2 predicted AUV1 heave velocity (m/s)";

  // Requirement traces and flags
  Boolean dropoutActive "true during controlled 1 s communication dropout";
  Real routeProgress "dimensionless route fraction";
  Real primaryTrackingError "AUV1 route tracking error (m)";
  Real formationError "pair formation error (m)";
  discrete Real formationErrorDegraded(start=0) "formation error sampled at dropout end (m)";
  discrete Real formationErrorRecovered(start=0) "formation error sampled after recovery (m)";
  discrete Real primaryTrackingErrorAt91(start=0) "primary tracking error sampled at 9.1 s (m)";
  discrete Real routeCompletedFlag(start=0) "1 when route completed within tolerance";

protected
  Boolean commAvailable;
  Real s, sdot, sddot;
  Real xRef1, xRef2, zRef1, zRef2;
  Real vxRef1, vzRef1, vxRef2, vzRef2;
  Real axRef1, azRef1, axRef2, azRef2;
  Real dt1, dt2;
  Real dx12, dz12, d12, dx21, dz21, d21;
  Real Fcoll1x, Fcoll1z, Fcoll2x, Fcoll2z;
  Real Fsurge1_raw, Fsurge1_sat, Fheave1_raw, Fheave1_sat;
  Real Fsurge2_raw, Fsurge2_sat, Fheave2_raw, Fheave2_sat;

equation
  dropoutActive = time >= tDropStart and time < tDropEnd;
  commAvailable = not dropoutActive;

  // Smooth finite route from (0,0) to (xEnd,zEnd), hold after tRoute
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

  // Prediction from last-received peer state with timestamp; modem delay
  // approximated by discrete hold of last received values during dropout
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

  // Collision avoidance with zero-error branch in the norm
  dx12 = x1 - x2hat1;
  dz12 = z1 - z2hat1;
  d12 = sqrt(dx12*dx12 + dz12*dz12 + eps);
  Fcoll1x = if d12 < safeDist then kcoll*(safeDist - d12)*dx12/d12 else 0.0;
  Fcoll1z = if d12 < safeDist then kcoll*(safeDist - d12)*dz12/d12 else 0.0;
  dx21 = x2 - x1hat2;
  dz21 = z2 - z1hat2;
  d21 = sqrt(dx21*dx21 + dz21*dz21 + eps);
  Fcoll2x = if d21 < safeDist then kcoll*(safeDist - d21)*dx21/d21 else 0.0;
  Fcoll2z = if d21 < safeDist then kcoll*(safeDist - d21)*dz21/d21 else 0.0;

  // Distributed AUV1 control: route plus predicted-peer formation coupling
  Fsurge1_raw = m*(axRef1 + kp*((xRef1 - x1) + kform*((x2hat1 + L) - x1)) + kd*((vxRef1 - vx1) + kform*(vx2hat1 - vx1))) + b*vx1 + Fcoll1x;
  Fsurge1_sat = max(-2.0*FthrusterMax, min(2.0*FthrusterMax, Fsurge1_raw));
  u1s1 = max(-FthrusterMax, min(FthrusterMax, Fsurge1_sat/2.0));
  u1s2 = u1s1;
  Fheave1_raw = m*(azRef1 + kp*((zRef1 - z1) + kform*(z2hat1 - z1)) + kd*((vzRef1 - vz1) + kform*(vz2hat1 - vz1))) + b*vz1 + Fcoll1z;
  Fheave1_sat = max(-2.0*FthrusterMax, min(2.0*FthrusterMax, Fheave1_raw));
  u1h1 = max(-FthrusterMax, min(FthrusterMax, Fheave1_sat/2.0));
  u1h2 = u1h1;

  // Distributed AUV2 control: route plus predicted-peer formation coupling
  Fsurge2_raw = m*(axRef2 + kp*((xRef2 - x2) + kform*((x1hat2 - L) - x2)) + kd*((vxRef2 - vx2) + kform*(vx1hat2 - vx2))) + b*vx2 + Fcoll2x;
  Fsurge2_sat = max(-2.0*FthrusterMax, min(2.0*FthrusterMax, Fsurge2_raw));
  u2s1 = max(-FthrusterMax, min(FthrusterMax, Fsurge2_sat/2.0));
  u2s2 = u2s1;
  Fheave2_raw = m*(azRef2 + kp*((zRef2 - z2) + kform*(z1hat2 - z2)) + kd*((vzRef2 - vz2) + kform*(vz1hat2 - vz2))) + b*vz2 + Fcoll2z;
  Fheave2_sat = max(-2.0*FthrusterMax, min(2.0*FthrusterMax, Fheave2_raw));
  u2h1 = max(-FthrusterMax, min(FthrusterMax, Fheave2_sat/2.0));
  u2h2 = u2h1;

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

  // Discrete updates: modem reception (held during dropout) and error sampling
  when sample(0, Ts) then
    rx1X = if commAvailable then x2 else pre(rx1X);
    rx1Z = if commAvailable then z2 else pre(rx1Z);
    rx1Vx = if commAvailable then vx2 else pre(rx1Vx);
    rx1Vz = if commAvailable then vz2 else pre(rx1Vz);
    rx1Time = if commAvailable then time - tau_modem else pre(rx1Time);
    rx2X = if commAvailable then x1 else pre(rx2X);
    rx2Z = if commAvailable then z1 else pre(rx2Z);
    rx2Vx = if commAvailable then vx1 else pre(rx2Vx);
    rx2Vz = if commAvailable then vz1 else pre(rx2Vz);
    rx2Time = if commAvailable then time - tau_modem else pre(rx2Time);

    formationErrorDegraded = if abs(time - tDropEnd) <= Ts/2 then formationError else pre(formationErrorDegraded);
    formationErrorRecovered = if abs(time - tRecoverEval) <= Ts/2 then formationError else pre(formationErrorRecovered);
    primaryTrackingErrorAt91 = if abs(time - 9.1) <= Ts/2 then primaryTrackingError else pre(primaryTrackingErrorAt91);
    routeCompletedFlag = if time >= tRoute and pre(routeCompletedFlag) < 0.5 and abs(x1 - xEnd) <= routeTol and abs(z1 - zEnd) <= routeTol then 1.0 else pre(routeCompletedFlag);
  end when;

  annotation(experiment(StopTime=14, Tolerance=1e-6, Interval=0.005));
end MarinePairResilientD;