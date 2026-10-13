model MarinePairResilientD
  // Values not stated in the requirement (damping, route shape, acoustic delay,
  // gains, formation offset) are chosen finite for an executable demonstration.

  // Physical and mission parameters
  parameter Real m_auc(unit="kg") = 80.0 "mass of each AUV";
  parameter Real b_surge(unit="N.s/m") = 20.0 "surge damping coefficient";
  parameter Real b_heave(unit="N.s/m") = 20.0 "heave damping coefficient";
  parameter Real Fmax(unit="N") = 105.0 "per-thruster-channel bound";
  parameter Real Ts(unit="s") = 0.005 "200 Hz control/modem/trace period";
  parameter Real tFinal(unit="s") = 14.0 "simulation duration";
  parameter Real zRef(unit="m") = 1.0 "commanded depth, positive down";
  parameter Real routeLength(unit="m") = 6.0 "straight route length";
  parameter Real vRoute(unit="m/s") = 0.45 "nominal route speed";
  parameter Real routeDuration(unit="s") = routeLength / vRoute;
  parameter Real tDropStart(unit="s") = 6.0 "start of 1 s dropout, inside middle third";
  parameter Real tDropEnd(unit="s") = 7.0 "end of 1 s dropout";
  parameter Real distForce(unit="N") = 30.0 "shared surge disturbance during dropout";
  parameter Real T_modem_delay(unit="s") = 0.05 "finite acoustic modem delay";
  parameter Real dForm(unit="m") = 5.0 "desired surge separation, AUV1 ahead of AUV2";
  parameter Real dSafe(unit="m") = 2.0 "collision-avoidance minimum distance";
  parameter Real kpSurge(unit="1/s2") = 2.0 "surge position gain";
  parameter Real kdSurge(unit="1/s") = 2.0 "surge velocity gain";
  parameter Real kpHeave(unit="1/s2") = 2.0 "heave position gain";
  parameter Real kdHeave(unit="1/s") = 2.0 "heave velocity gain";
  parameter Real kForm = 0.1 "formation-error feedback gain";
  parameter Real kAvoid = 1.0 "collision-avoidance feedback gain";

  // Initial conditions
  parameter Real x1_start(unit="m") = 2.5;
  parameter Real x2_start(unit="m") = -2.5;
  parameter Real z_start(unit="m") = zRef;

  // Plant states
  Real x1(unit="m", start=x1_start) "AUV1 surge position";
  Real z1(unit="m", start=z_start) "AUV1 depth, positive down";
  Real vx1(unit="m/s", start=0.0) "AUV1 surge velocity";
  Real vz1(unit="m/s", start=0.0) "AUV1 heave velocity";

  Real x2(unit="m", start=x2_start) "AUV2 surge position";
  Real z2(unit="m", start=z_start) "AUV2 depth, positive down";
  Real vx2(unit="m/s", start=0.0) "AUV2 surge velocity";
  Real vz2(unit="m/s", start=0.0) "AUV2 heave velocity";

  // Route and disturbance
  Boolean dropoutActive = time >= tDropStart and time < tDropEnd;
  output Boolean modemAvailable = not dropoutActive;
  Real distSurge(unit="N") = if dropoutActive then distForce else 0.0;
  Real xRouteRef(unit="m") = if time < routeDuration then vRoute * time else routeLength;
  Real vRouteRef(unit="m/s") = if time < routeDuration then vRoute else 0.0;

  // Actuator channels: 8 bidirectional subchannels, two per thruster
  discrete Real cmdSurge1Fwd(unit="N", start=0.0);
  discrete Real cmdSurge1Aft(unit="N", start=0.0);
  discrete Real cmdHeave1Down(unit="N", start=0.0);
  discrete Real cmdHeave1Up(unit="N", start=0.0);
  discrete Real cmdSurge2Fwd(unit="N", start=0.0);
  discrete Real cmdSurge2Aft(unit="N", start=0.0);
  discrete Real cmdHeave2Down(unit="N", start=0.0);
  discrete Real cmdHeave2Up(unit="N", start=0.0);

  Real tauSurge1(unit="N") = cmdSurge1Fwd - cmdSurge1Aft;
  Real tauHeave1(unit="N") = cmdHeave1Down - cmdHeave1Up;
  Real tauSurge2(unit="N") = cmdSurge2Fwd - cmdSurge2Aft;
  Real tauHeave2(unit="N") = cmdHeave2Down - cmdHeave2Up;

  output Boolean actuatorBoundsRespected =
    cmdSurge1Fwd >= -1e-9 and cmdSurge1Fwd <= Fmax + 1e-9 and
    cmdSurge1Aft >= -1e-9 and cmdSurge1Aft <= Fmax + 1e-9 and
    cmdHeave1Down >= -1e-9 and cmdHeave1Down <= Fmax + 1e-9 and
    cmdHeave1Up >= -1e-9 and cmdHeave1Up <= Fmax + 1e-9 and
    cmdSurge2Fwd >= -1e-9 and cmdSurge2Fwd <= Fmax + 1e-9 and
    cmdSurge2Aft >= -1e-9 and cmdSurge2Aft <= Fmax + 1e-9 and
    cmdHeave2Down >= -1e-9 and cmdHeave2Down <= Fmax + 1e-9 and
    cmdHeave2Up >= -1e-9 and cmdHeave2Up <= Fmax + 1e-9;

  // Last-received peer state with timestamps
  discrete Real rx2_x(unit="m", start=x2_start) "last received x2 at AUV1";
  discrete Real rx2_z(unit="m", start=z_start) "last received z2 at AUV1";
  discrete Real rx2_vx(unit="m/s", start=0.0) "last received vx2 at AUV1";
  discrete Real rx2_vz(unit="m/s", start=0.0) "last received vz2 at AUV1";
  discrete Real rx2_t(unit="s", start=-T_modem_delay) "timestamp of last received x2";

  discrete Real rx1_x(unit="m", start=x1_start) "last received x1 at AUV2";
  discrete Real rx1_z(unit="m", start=z_start) "last received z1 at AUV2";
  discrete Real rx1_vx(unit="m/s", start=0.0) "last received vx1 at AUV2";
  discrete Real rx1_vz(unit="m/s", start=0.0) "last received vz1 at AUV2";
  discrete Real rx1_t(unit="s", start=-T_modem_delay) "timestamp of last received x1";

  Real lastReceivedPeerX1(unit="m") = rx2_x;
  Real lastReceivedPeerZ1(unit="m") = rx2_z;
  Real lastReceivedPeerVx1(unit="m/s") = rx2_vx;
  Real lastReceivedPeerVz1(unit="m/s") = rx2_vz;
  output Real lastReceivedPeerT1(unit="s") = rx2_t;

  Real lastReceivedPeerX2(unit="m") = rx1_x;
  Real lastReceivedPeerZ2(unit="m") = rx1_z;
  Real lastReceivedPeerVx2(unit="m/s") = rx1_vx;
  Real lastReceivedPeerVz2(unit="m/s") = rx1_vz;
  output Real lastReceivedPeerT2(unit="s") = rx1_t;

  // Predicted peer estimates, updated at 200 Hz
  discrete Real peerEstimate1Age(unit="s", start=T_modem_delay);
  discrete Real peerEstimate1X(unit="m", start=x2_start);
  discrete Real peerEstimate1Z(unit="m", start=z_start);
  discrete Real peerEstimate1Vx(unit="m/s", start=0.0);
  discrete Real peerEstimate1Vz(unit="m/s", start=0.0);

  discrete Real peerEstimate2Age(unit="s", start=T_modem_delay);
  discrete Real peerEstimate2X(unit="m", start=x1_start);
  discrete Real peerEstimate2Z(unit="m", start=z_start);
  discrete Real peerEstimate2Vx(unit="m/s", start=0.0);
  discrete Real peerEstimate2Vz(unit="m/s", start=0.0);

  // Controller references and commanded forces
  discrete Real xRef1Eff(unit="m", start=x1_start);
  discrete Real xRef2Eff(unit="m", start=x2_start);
  discrete Real Fsurge1Des(unit="N", start=0.0);
  discrete Real Fsurge2Des(unit="N", start=0.0);
  discrete Real Fheave1Des(unit="N", start=0.0);
  discrete Real Fheave2Des(unit="N", start=0.0);

  discrete Real sep1, dist1NoZero, dir1, avoid1, fe1, eSurge1, eHeave1;
  discrete Real sep2, dist2NoZero, dir2, avoid2, fe2, eSurge2, eHeave2;

  // Measurements and roles
  Real proprioceptionX1(unit="m") = x1;
  Real proprioceptionZ1(unit="m") = z1;
  Real proprioceptionVx1(unit="m/s") = vx1;
  Real proprioceptionVz1(unit="m/s") = vz1;
  Real proprioceptionX2(unit="m") = x2;
  Real proprioceptionZ2(unit="m") = z2;
  Real proprioceptionVx2(unit="m/s") = vx2;
  Real proprioceptionVz2(unit="m/s") = vz2;

  Real exteroceptionDepth1(unit="m") = z1;
  Real exteroceptionDvlSurge1(unit="m/s") = vx1;
  Real exteroceptionDvlHeave1(unit="m/s") = vz1;
  Real exteroceptionImuYaw1(unit="rad") = 0.0; // straight route; attitude dynamics not specified
  Real exteroceptionImuYawRate1(unit="rad/s") = 0.0;

  Real exteroceptionDepth2(unit="m") = z2;
  Real exteroceptionDvlSurge2(unit="m/s") = vx2;
  Real exteroceptionDvlHeave2(unit="m/s") = vz2;
  Real exteroceptionImuYaw2(unit="rad") = 0.0; // straight route; attitude dynamics not specified
  Real exteroceptionImuYawRate2(unit="rad/s") = 0.0;

  // Metrics
  Real xCenter(unit="m") = (x1 + x2) / 2.0;
  Real zCenter(unit="m") = (z1 + z2) / 2.0;
  output Real primaryTrackingError(unit="m") =
    sqrt(max((xCenter - xRouteRef)^2 + (zCenter - zRef)^2, 0.0));

  Real formationDistance(unit="m") =
    sqrt(max((x1 - x2)^2 + (z1 - z2)^2, 0.0));
  output Real formationError(unit="m") =
    sqrt(max((x1 - x2 - dForm)^2 + (z1 - z2)^2, 0.0));
  output Real degradedFormationError(unit="m") =
    if dropoutActive then formationError else 0.0;
  output Real recoveredFormationError(unit="m") =
    if time >= tDropEnd then formationError else 0.0;
  output Boolean collisionAvoidanceActive = formationDistance < dSafe;
  Real collisionAvoidanceMargin(unit="m") = formationDistance - dSafe;
  output Boolean routeCompleted = xRouteRef >= routeLength - 1e-9;

  // Synchronized 200 Hz traces held as discrete variables
  discrete Real syncStateX1(unit="m", start=x1_start);
  discrete Real syncStateZ1(unit="m", start=z_start);
  discrete Real syncStateVx1(unit="m/s", start=0.0);
  discrete Real syncStateVz1(unit="m/s", start=0.0);
  discrete Real syncStateX2(unit="m", start=x2_start);
  discrete Real syncStateZ2(unit="m", start=z_start);
  discrete Real syncStateVx2(unit="m/s", start=0.0);
  discrete Real syncStateVz2(unit="m/s", start=0.0);

  discrete Real syncCmdSurge1Fwd(unit="N", start=0.0);
  discrete Real syncCmdSurge1Aft(unit="N", start=0.0);
  discrete Real syncCmdHeave1Down(unit="N", start=0.0);
  discrete Real syncCmdHeave1Up(unit="N", start=0.0);
  discrete Real syncCmdSurge2Fwd(unit="N", start=0.0);
  discrete Real syncCmdSurge2Aft(unit="N", start=0.0);
  discrete Real syncCmdHeave2Down(unit="N", start=0.0);
  discrete Real syncCmdHeave2Up(unit="N", start=0.0);

  discrete Real syncSensorDepth1(unit="m", start=z_start);
  discrete Real syncSensorDvlSurge1(unit="m/s", start=0.0);
  discrete Real syncSensorDvlHeave1(unit="m/s", start=0.0);
  discrete Real syncSensorImuYaw1(unit="rad", start=0.0);
  discrete Real syncSensorDepth2(unit="m", start=z_start);
  discrete Real syncSensorDvlSurge2(unit="m/s", start=0.0);
  discrete Real syncSensorDvlHeave2(unit="m/s", start=0.0);
  discrete Real syncSensorImuYaw2(unit="rad", start=0.0);

  discrete Real syncLastReceivedPeerT1(unit="s", start=-T_modem_delay);
  discrete Real syncLastReceivedPeerT2(unit="s", start=-T_modem_delay);
  discrete Real syncPrimaryError(unit="m", start=0.0);
  discrete Real syncFormationError(unit="m", start=0.0);
  discrete Boolean syncDropoutActive(start=false);
  discrete Integer traceSampleIndex(start=0);

equation
  // Plant dynamics
  der(x1) = vx1;
  der(z1) = vz1;
  der(vx1) = (tauSurge1 - b_surge * vx1 + distSurge) / m_auc;
  der(vz1) = (tauHeave1 - b_heave * vz1) / m_auc;

  der(x2) = vx2;
  der(z2) = vz2;
  der(vx2) = (tauSurge2 - b_surge * vx2 + distSurge) / m_auc;
  der(vz2) = (tauHeave2 - b_heave * vz2) / m_auc;

  when sample(0, Ts) then
    // Delayed acoustic modem; no updates during dropout
    if not dropoutActive then
      rx2_x := delay(x2, T_modem_delay, T_modem_delay);
      rx2_z := delay(z2, T_modem_delay, T_modem_delay);
      rx2_vx := delay(vx2, T_modem_delay, T_modem_delay);
      rx2_vz := delay(vz2, T_modem_delay, T_modem_delay);
      rx2_t := time - T_modem_delay;

      rx1_x := delay(x1, T_modem_delay, T_modem_delay);
      rx1_z := delay(z1, T_modem_delay, T_modem_delay);
      rx1_vx := delay(vx1, T_modem_delay, T_modem_delay);
      rx1_vz := delay(vz1, T_modem_delay, T_modem_delay);
      rx1_t := time - T_modem_delay;
    end if;

    // Distributed prediction from last-received peer state and timestamp
    peerEstimate1Age := max(time - rx2_t, 0.0);
    peerEstimate1X := rx2_x + rx2_vx * peerEstimate1Age;
    peerEstimate1Z := rx2_z + rx2_vz * peerEstimate1Age;
    peerEstimate1Vx := rx2_vx;
    peerEstimate1Vz := rx2_vz;

    peerEstimate2Age := max(time - rx1_t, 0.0);
    peerEstimate2X := rx1_x + rx1_vx * peerEstimate2Age;
    peerEstimate2Z := rx1_z + rx1_vz * peerEstimate2Age;
    peerEstimate2Vx := rx1_vx;
    peerEstimate2Vz := rx1_vz;

    // AUV1 distributed control with formation and collision avoidance
    sep1 := x1 - peerEstimate1X;
    dist1NoZero := max(abs(sep1), 1.0e-6);
    dir1 := sep1 / dist1NoZero;
    avoid1 := max(0.0, dSafe - dist1NoZero);
    fe1 := sep1 - dForm;
    xRef1Eff := xRouteRef + dForm / 2.0 - kForm * fe1 + dir1 * avoid1 * kAvoid;
    eSurge1 := xRef1Eff - x1;
    eHeave1 := zRef - z1;
    Fsurge1Des := b_surge * vx1 + m_auc * kpSurge * eSurge1 + m_auc * kdSurge * (vRouteRef - vx1);
    Fheave1Des := b_heave * vz1 + m_auc * kpHeave * eHeave1 - m_auc * kdHeave * vz1;
    cmdSurge1Fwd := if Fsurge1Des >= 0.0 then min(Fsurge1Des, Fmax) else 0.0;
    cmdSurge1Aft := if Fsurge1Des < 0.0 then min(-Fsurge1Des, Fmax) else 0.0;
    cmdHeave1Down := if Fheave1Des >= 0.0 then min(Fheave1Des, Fmax) else 0.0;
    cmdHeave1Up := if Fheave1Des < 0.0 then min(-Fheave1Des, Fmax) else 0.0;

    // AUV2 distributed control with formation and collision avoidance
    sep2 := peerEstimate2X - x2;
    dist2NoZero := max(abs(sep2), 1.0e-6);
    dir2 := sep2 / dist2NoZero;
    avoid2 := max(0.0, dSafe - dist2NoZero);
    fe2 := sep2 - dForm;
    xRef2Eff := xRouteRef - dForm / 2.0 + kForm * fe2 - dir2 * avoid2 * kAvoid;
    eSurge2 := xRef2Eff - x2;
    eHeave2 := zRef - z2;
    Fsurge2Des := b_surge * vx2 + m_auc * kpSurge * eSurge2 + m_auc * kdSurge * (vRouteRef - vx2);
    Fheave2Des := b_heave * vz2 + m_auc * kpHeave * eHeave2 - m_auc * kdHeave * vz2;
    cmdSurge2Fwd := if Fsurge2Des >= 0.0 then min(Fsurge2Des, Fmax) else 0.0;
    cmdSurge2Aft := if Fsurge2Des < 0.0 then min(-Fsurge2Des, Fmax) else 0.0;
    cmdHeave2Down := if Fheave2Des >= 0.0 then min(Fheave2Des, Fmax) else 0.0;
    cmdHeave2Up := if Fheave2Des < 0.0 then min(-Fheave2Des, Fmax) else 0.0;

    // Synchronized state, command, and sensor traces at 200 Hz
    syncStateX1 := x1;
    syncStateZ1 := z1;
    syncStateVx1 := vx1;
    syncStateVz1 := vz1;
    syncStateX2 := x2;
    syncStateZ2 := z2;
    syncStateVx2 := vx2;
    syncStateVz2 := vz2;

    syncCmdSurge1Fwd := cmdSurge1Fwd;
    syncCmdSurge1Aft := cmdSurge1Aft;
    syncCmdHeave1Down := cmdHeave1Down;
    syncCmdHeave1Up := cmdHeave1Up;
    syncCmdSurge2Fwd := cmdSurge2Fwd;
    syncCmdSurge2Aft := cmdSurge2Aft;
    syncCmdHeave2Down := cmdHeave2Down;
    syncCmdHeave2Up := cmdHeave2Up;

    syncSensorDepth1 := z1;
    syncSensorDvlSurge1 := vx1;
    syncSensorDvlHeave1 := vz1;
    syncSensorImuYaw1 := 0.0;
    syncSensorDepth2 := z2;
    syncSensorDvlSurge2 := vx2;
    syncSensorDvlHeave2 := vz2;
    syncSensorImuYaw2 := 0.0;

    syncLastReceivedPeerT1 := rx2_t;
    syncLastReceivedPeerT2 := rx1_t;
    syncPrimaryError := primaryTrackingError;
    syncFormationError := formationError;
    syncDropoutActive := dropoutActive;
    traceSampleIndex := pre(traceSampleIndex) + 1;
  end when;

  annotation(experiment(StopTime=14.0, Tolerance=1e-4, Interval=0.005));
end MarinePairResilientD;