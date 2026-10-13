model CoaxLiftDeliverB
  // Physical parameters (stated values are bound; assumed values are commented)
  parameter Real M_platform = 4.4 "kg";
  parameter Real m_payload = 1.2 "kg";
  parameter Real L_cable = 0.70 "m";
  parameter Real g_accel = 9.81 "m/s2";
  parameter Real TmaxRotor = 8.2 "N";
  parameter Real rArm = 0.25 "m, assumed arm lever, not specified";
  parameter Real J_pitch = 0.12 "kg m2, assumed pitch inertia, not specified";
  parameter Real cDrag = 0.40 "N s/m, assumed linear aerodynamic drag, not specified";
  parameter Real TcableMax = 40.0 "N, assumed safe cable-tension bound, not specified";

  // Mission timing and target
  parameter Real samplePeriod = 0.01 "s, 100 Hz";
  parameter Real zStart = 1.0 "m";
  parameter Real zCruise = 2.0 "m";
  parameter Real zFinal = 0.8 "m";
  parameter Real xTarget = 5.0 "m";
  parameter Real zTarget = 0.0 "m";
  parameter Real targetRadius = 0.8 "m";
  parameter Real liftDur = 2.0 "s";
  parameter Real transStart = 2.0 "s";
  parameter Real transDur = 5.0 "s";
  parameter Real lowerStart = 7.0 "s";
  parameter Real lowerDur = 3.0 "s";
  parameter Real gustStart = 10.0/3.0 "s";
  parameter Real gustEnd = 20.0/3.0 "s";
  parameter Real gustForce = 5.6 "N";

  // Controller gains
  parameter Real Kp_x = 8.0 "1/s2";
  parameter Real Kd_x = 6.0 "1/s";
  parameter Real Kp_z = 5.0 "1/s2";
  parameter Real Kd_z = 4.0 "1/s";
  parameter Real K_swing_rate = 1.2 "m/(rad/s), cable-swing damping";
  parameter Real Kp_theta = 12.0 "N m/rad";
  parameter Real Kd_theta = 6.0 "N m s/rad";
  parameter Real axLimit = 2.5 "m/s2";
  parameter Real azMin = -2.5 "m/s2";
  parameter Real azMax = 2.5 "m/s2";
  parameter Real thetaLimit = 0.25 "rad";
  parameter Real tauMax = 1.5 "N m";

  // Continuous states
  Real x(start = 0.0) "m";
  Real z(start = zStart) "m";
  Real vx(start = 0.0) "m/s";
  Real vz(start = 0.0) "m/s";
  Real theta(start = 0.0) "rad";
  Real omega(start = 0.0) "rad/s";
  Real phi(start = 0.0) "rad";
  Real phidot(start = 0.0) "rad/s";

  // Algebraic physical variables
  Real ax "m/s2";
  Real az "m/s2";
  Real alpha "rad/s2";
  Real Ttot "N";
  Real tau "N m";
  Real Tfront "N";
  Real Trear "N";
  Real Fx "N";
  Real Fz "N";
  Real FdragX "N";
  Real FdragZ "N";
  Real Fgust "N";
  Real Tcable "N";
  Real payloadX "m";
  Real payloadZ "m";
  Real primaryError "m";
  Real targetError "m";

  // Reference shaping
  Real etaLift;
  Real etaTrans;
  Real etaLower;
  Real sLift, sLiftVel, sLiftAcc;
  Real sTrans, sTransVel, sTransAcc;
  Real sLower, sLowerVel, sLowerAcc;
  Real xref, xrefVel, xrefAcc;
  Real zref, zrefVel, zrefAcc;

  // Sensors
  Real gpsX "m";
  Real gpsZ "m";
  Real gpsVx "m/s";
  Real gpsVz "m/s";
  Real imuAccX "m/s2";
  Real imuAccZ "m/s2";
  Real imuPitch "rad";
  Real imuPitchRate "rad/s";
  Real cableAngle "rad";
  Real cableAngleRate "rad/s";
  Real cableTension "N";

  // Discrete controller and traces
  discrete Real u1(start = (M_platform + m_payload)*g_accel/8.0) "N";
  discrete Real u2(start = (M_platform + m_payload)*g_accel/8.0) "N";
  discrete Real u3(start = (M_platform + m_payload)*g_accel/8.0) "N";
  discrete Real u4(start = (M_platform + m_payload)*g_accel/8.0) "N";
  discrete Real u5(start = (M_platform + m_payload)*g_accel/8.0) "N";
  discrete Real u6(start = (M_platform + m_payload)*g_accel/8.0) "N";
  discrete Real u7(start = (M_platform + m_payload)*g_accel/8.0) "N";
  discrete Real u8(start = (M_platform + m_payload)*g_accel/8.0) "N";
  discrete Real uFrontCmd(start = (M_platform + m_payload)*g_accel/8.0) "N";
  discrete Real uRearCmd(start = (M_platform + m_payload)*g_accel/8.0) "N";
  discrete Real TtotCmd(start = (M_platform + m_payload)*g_accel) "N";
  discrete Real tauCmd(start = 0.0) "N m";
  discrete Real axCmd(start = 0.0) "m/s2";
  discrete Real azCmd(start = 0.0) "m/s2";
  discrete Real thetaDes(start = 0.0) "rad";
  discrete Real errX(start = 0.0) "m";
  discrete Real errZ(start = 0.0) "m";
  discrete Real errVx(start = 0.0) "m/s";
  discrete Real errVz(start = 0.0) "m/s";
  discrete Real estX(start = 0.0) "m";
  discrete Real estZ(start = zStart) "m";
  discrete Real estVx(start = 0.0) "m/s";
  discrete Real estVz(start = 0.0) "m/s";
  discrete Real estTheta(start = 0.0) "rad";
  discrete Real estOmega(start = 0.0) "rad/s";
  discrete Real estPhi(start = 0.0) "rad";
  discrete Real estPhidot(start = 0.0) "rad/s";

  // Synchronized 100 Hz traces
  discrete Real sTime(start = 0.0) "s";
  discrete Real sX(start = 0.0) "m";
  discrete Real sZ(start = zStart) "m";
  discrete Real sVx(start = 0.0) "m/s";
  discrete Real sVz(start = 0.0) "m/s";
  discrete Real sTheta(start = 0.0) "rad";
  discrete Real sPhi(start = 0.0) "rad";
  discrete Real sPayloadX(start = 0.0) "m";
  discrete Real sPayloadZ(start = zStart - L_cable) "m";
  discrete Real sTension(start = m_payload*g_accel) "N";
  discrete Real sGpsX(start = 0.0) "m";
  discrete Real sGpsZ(start = zStart) "m";
  discrete Real sImuPitch(start = 0.0) "rad";
  discrete Real sCableAngle(start = 0.0) "rad";
  discrete Real sU1(start = (M_platform + m_payload)*g_accel/8.0) "N";
  discrete Real sU2(start = (M_platform + m_payload)*g_accel/8.0) "N";
  discrete Real sU3(start = (M_platform + m_payload)*g_accel/8.0) "N";
  discrete Real sU4(start = (M_platform + m_payload)*g_accel/8.0) "N";
  discrete Real sU5(start = (M_platform + m_payload)*g_accel/8.0) "N";
  discrete Real sU6(start = (M_platform + m_payload)*g_accel/8.0) "N";
  discrete Real sU7(start = (M_platform + m_payload)*g_accel/8.0) "N";
  discrete Real sU8(start = (M_platform + m_payload)*g_accel/8.0) "N";
  discrete Real sPrimaryError(start = 0.0) "m";
  discrete Real sTargetError(start = 0.0) "m";
  discrete Real sGust(start = 0.0) "N";

equation
  // State dynamics
  der(x) = vx;
  der(z) = vz;
  der(theta) = omega;
  der(phi) = phidot;
  der(vx) = ax;
  der(vz) = az;
  der(omega) = tau / J_pitch;
  der(phidot) = alpha;

  // Input-shaped quintic references
  etaLift = if time < liftDur then time / liftDur else 1.0;
  etaTrans = if time < transStart then 0.0 elseif time < transStart + transDur then (time - transStart) / transDur else 1.0;
  etaLower = if time < lowerStart then 0.0 elseif time < lowerStart + lowerDur then (time - lowerStart) / lowerDur else 1.0;

  sLift = if etaLift < 1.0 then 10.0*etaLift^3 - 15.0*etaLift^4 + 6.0*etaLift^5 else 1.0;
  sLiftVel = if etaLift < 1.0 then (30.0*etaLift^2 - 60.0*etaLift^3 + 30.0*etaLift^4) / liftDur else 0.0;
  sLiftAcc = if etaLift < 1.0 then (60.0*etaLift - 180.0*etaLift^2 + 120.0*etaLift^3) / (liftDur*liftDur) else 0.0;

  sTrans = if etaTrans <= 0.0 then 0.0 elseif etaTrans < 1.0 then 10.0*etaTrans^3 - 15.0*etaTrans^4 + 6.0*etaTrans^5 else 1.0;
  sTransVel = if etaTrans <= 0.0 or etaTrans >= 1.0 then 0.0 else (30.0*etaTrans^2 - 60.0*etaTrans^3 + 30.0*etaTrans^4) / transDur;
  sTransAcc = if etaTrans <= 0.0 or etaTrans >= 1.0 then 0.0 else (60.0*etaTrans - 180.0*etaTrans^2 + 120.0*etaTrans^3) / (transDur*transDur);

  sLower = if etaLower <= 0.0 then 0.0 elseif etaLower < 1.0 then 10.0*etaLower^3 - 15.0*etaLower^4 + 6.0*etaLower^5 else 1.0;
  sLowerVel = if etaLower <= 0.0 or etaLower >= 1.0 then 0.0 else (30.0*etaLower^2 - 60.0*etaLower^3 + 30.0*etaLower^4) / lowerDur;
  sLowerAcc = if etaLower <= 0.0 or etaLower >= 1.0 then 0.0 else (60.0*etaLower - 180.0*etaLower^2 + 120.0*etaLower^3) / (lowerDur*lowerDur);

  xref = xTarget * sTrans;
  xrefVel = xTarget * sTransVel;
  xrefAcc = xTarget * sTransAcc;

  zref = if time < liftDur then zStart + (zCruise - zStart)*sLift elseif time < lowerStart then zCruise else zCruise - (zCruise - zFinal)*sLower;
  zrefVel = if time < liftDur then (zCruise - zStart)*sLiftVel elseif time < lowerStart then 0.0 else -(zCruise - zFinal)*sLowerVel;
  zrefAcc = if time < liftDur then (zCruise - zStart)*sLiftAcc elseif time < lowerStart then 0.0 else -(zCruise - zFinal)*sLowerAcc;

  // Disturbances and drag
  Fgust = if noEvent(time >= gustStart and time <= gustEnd) then gustForce else 0.0;
  FdragX = -cDrag * vx;
  FdragZ = -cDrag * vz;

  // Rotor aggregation
  Ttot = u1 + u2 + u3 + u4 + u5 + u6 + u7 + u8;
  Tfront = u1 + u2 + u3 + u4;
  Trear = u5 + u6 + u7 + u8;
  tau = rArm * (Trear - Tfront);

  // Platform and pendulum coupling
  Fx = Ttot*sin(theta) + FdragX + Fgust;
  Fz = Ttot*cos(theta) + FdragZ - M_platform*g_accel;

  alpha = -(Fx*cos(phi) + Fz*sin(phi)) / (M_platform*L_cable) - (g_accel/L_cable)*sin(phi);

  Tcable = (m_payload*L_cable*phidot*phidot + (m_payload/M_platform)*(Fz*cos(phi) - Fx*sin(phi)) + m_payload*g_accel*cos(phi)) / ((M_platform + m_payload)/M_platform);

  ax = (Fx + Tcable*sin(phi)) / M_platform;
  az = (Fz - Tcable*cos(phi)) / M_platform;

  payloadX = x + L_cable*sin(phi);
  payloadZ = z - L_cable*cos(phi);

  primaryError = sqrt((x - xref)^2 + (z - zref)^2 + 1e-12);
  targetError = sqrt((payloadX - xTarget)^2 + (payloadZ - zTarget)^2 + 1e-12);

  // Ideal instruments
  gpsX = x;
  gpsZ = z;
  gpsVx = vx;
  gpsVz = vz;
  imuAccX = ax;
  imuAccZ = az;
  imuPitch = theta;
  imuPitchRate = omega;
  cableAngle = phi;
  cableAngleRate = phidot;
  cableTension = Tcable;

  // Continuous requirement assertions
  assert(noEvent(abs(phi) < 0.45), "cable swing bound violated");
  assert(noEvent(payloadZ > 0.0), "ground strike detected");
  assert(noEvent(Ttot <= 8.0*TmaxRotor + 1e-6), "total thrust bound violated");
  assert(noEvent(Tcable >= 0.0 and Tcable <= TcableMax + 1e-6), "cable tension bound violated");
  assert(noEvent(time < 6.5 or primaryError < 0.36), "primary tracking error bound violated after 6.5 s");
  assert(noEvent(time < 9.999 or targetError < targetRadius), "target-zone placement failed");
  assert(noEvent(abs(x) < 1e6 and abs(z) < 1e6 and abs(vx) < 1e6 and abs(vz) < 1e6 and abs(theta) < 1e6 and abs(phi) < 1e6 and abs(Tcable) < 1e6 and abs(Ttot) < 1e6), "non-finite physical value detected");

  // 100 Hz controller and synchronized trace update
  when sample(0, samplePeriod) then
    // Ideal estimator from GPS/IMU/cable sensors
    estX = gpsX;
    estZ = gpsZ;
    estVx = gpsVx;
    estVz = gpsVz;
    estTheta = imuPitch;
    estOmega = imuPitchRate;
    estPhi = cableAngle;
    estPhidot = cableAngleRate;

    // Input-shaped position control with cable-swing damping
    errX = xref - estX;
    errZ = zref - estZ;
    errVx = xrefVel - estVx;
    errVz = zrefVel - estVz;

    axCmd = max(-axLimit, min(axLimit, Kp_x*errX + Kd_x*errVx + xrefAcc + K_swing_rate*estPhidot));
    azCmd = max(azMin, min(azMax, Kp_z*errZ + Kd_z*errVz + zrefAcc));
    thetaDes = max(-thetaLimit, min(thetaLimit, atan2(axCmd, azCmd + g_accel)));

    TtotCmd = max(0.0, min(8.0*TmaxRotor, (M_platform + m_payload)*(azCmd + g_accel) / max(cos(thetaDes), 0.1)));
    tauCmd = max(-tauMax, min(tauMax, Kp_theta*(thetaDes - estTheta) - Kd_theta*estOmega));

    uFrontCmd = max(0.0, min(TmaxRotor, (TtotCmd - tauCmd/rArm)/8.0));
    uRearCmd = max(0.0, min(TmaxRotor, (TtotCmd + tauCmd/rArm)/8.0));

    u1 = uFrontCmd;
    u2 = uFrontCmd;
    u3 = uFrontCmd;
    u4 = uFrontCmd;
    u5 = uRearCmd;
    u6 = uRearCmd;
    u7 = uRearCmd;
    u8 = uRearCmd;

    // Synchronized traces
    sTime = time;
    sX = x;
    sZ = z;
    sVx = vx;
    sVz = vz;
    sTheta = theta;
    sPhi = phi;
    sPayloadX = payloadX;
    sPayloadZ = payloadZ;
    sTension = cableTension;
    sGpsX = gpsX;
    sGpsZ = gpsZ;
    sImuPitch = imuPitch;
    sCableAngle = cableAngle;
    sU1 = u1;
    sU2 = u2;
    sU3 = u3;
    sU4 = u4;
    sU5 = u5;
    sU6 = u6;
    sU7 = u7;
    sU8 = u8;
    sPrimaryError = primaryError;
    sTargetError = targetError;
    sGust = Fgust;

    // Discrete requirement checks
    assert(abs(uFrontCmd) <= TmaxRotor + 1e-6, "front rotor command bound violated");
    assert(abs(uRearCmd) <= TmaxRotor + 1e-6, "rear rotor command bound violated");
    assert(abs(axCmd) < 1e6 and abs(azCmd) < 1e6 and abs(thetaDes) < 1e6 and abs(TtotCmd) < 1e6 and abs(tauCmd) < 1e6, "non-finite control value detected");
    assert(abs(estX) < 1e6 and abs(estZ) < 1e6 and abs(estVx) < 1e6 and abs(estVz) < 1e6 and abs(estTheta) < 1e6 and abs(estOmega) < 1e6 and abs(estPhi) < 1e6 and abs(estPhidot) < 1e6, "non-finite estimator value detected");
  end when;

  annotation(experiment(StartTime = 0, StopTime = 10.0, Tolerance = 1e-6, Interval = 0.01));
end CoaxLiftDeliverB;