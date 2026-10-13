model MarinePairHandoffC
  // ===== Parameters =====
  parameter Real mass = 80.0 "AUV mass [kg]";
  parameter Real maxForce = 96.6 "Max thruster command per channel [N]";
  parameter Real dtCtrl = 1.0/125.0 "Control period [s]";
  parameter Real delayDist = 0.09 "Communication delay disturbance [s]";
  parameter Real tFinal = 12.0 "Total simulation time [s]";
  parameter Real tHandoff = 4.0 "Handoff trigger time [s]";
  parameter Real tMidStart = 4.0 "Middle third start [s]";
  parameter Real tMidEnd = 8.0 "Middle third end [s]";
  parameter Real dragCoef = 8.0 "Linear drag [N/(m/s)]";
  parameter Real sepMin = 1.0 "Minimum inter-robot separation [m]";
  parameter Real errTol = 0.42 "Primary tracking error tolerance [m]";
  parameter Real tErrCheck = 7.8 "Primary error check time [s]";
  parameter Real reachTol = 0.5 "Waypoint reach tolerance [m]";
  parameter Real kp = 120.0 "Proportional gain";
  parameter Real kd = 160.0 "Derivative gain";
  // World-frame survey markers / features
  parameter Real marker1[2] = {2.0, -1.0} "Inspection feature 1 [m]";
  parameter Real marker2[2] = {4.0, -2.0} "Inspection feature 2 [m]";
  parameter Real marker3[2] = {6.0, -2.0} "Inspection feature 3 [m]";
  parameter Real marker4[2] = {7.0, -1.5} "Inspection feature 4 [m]";
  parameter Real x0_1[2] = {0.0, 0.0} "Robot1 initial position [m]";
  parameter Real x0_2[2] = {5.5, -0.5} "Robot2 initial position [m]";

  // ===== Continuous plant states =====
  Real x1(start=x0_1[1]) "Robot1 x position [m]";
  Real z1(start=x0_1[2]) "Robot1 z position (depth) [m]";
  Real vx1(start=0.0) "Robot1 surge velocity [m/s]";
  Real vz1(start=0.0) "Robot1 heave velocity [m/s]";
  Real x2(start=x0_2[1]) "Robot2 x position [m]";
  Real z2(start=x0_2[2]) "Robot2 z position (depth) [m]";
  Real vx2(start=0.0) "Robot2 surge velocity [m/s]";
  Real vz2(start=0.0) "Robot2 heave velocity [m/s]";

  // ===== Eight bidirectional thruster channels (4 per AUV) =====
  Real F1_sL "Robot1 surge-left channel [N]";
  Real F1_sR "Robot1 surge-right channel [N]";
  Real F1_hF "Robot1 heave-front channel [N]";
  Real F1_hB "Robot1 heave-back channel [N]";
  Real F2_sL "Robot2 surge-left channel [N]";
  Real F2_sR "Robot2 surge-right channel [N]";
  Real F2_hF "Robot2 heave-front channel [N]";
  Real F2_hB "Robot2 heave-back channel [N]";

  // Net commanded forces (discrete, updated at 125 Hz)
  discrete Real u1x(start=0.0) "Robot1 net surge command [N]";
  discrete Real u1z(start=0.0) "Robot1 net heave command [N]";
  discrete Real u2x(start=0.0) "Robot2 net surge command [N]";
  discrete Real u2z(start=0.0) "Robot2 net heave command [N]";

  // ===== Local sensors =====
  Real depth1 "Robot1 pressure-depth sensor [m]";
  Real depth2 "Robot2 pressure-depth sensor [m]";
  Real dvl1x "Robot1 DVL surge velocity [m/s]";
  Real dvl1z "Robot1 DVL heave velocity [m/s]";
  Real dvl2x "Robot2 DVL surge velocity [m/s]";
  Real dvl2z "Robot2 DVL heave velocity [m/s]";
  Real imu1h "Robot1 IMU heading [rad]";
  Real imu2h "Robot2 IMU heading [rad]";

  // ===== Delayed acoustic modem =====
  discrete Real sendTime(start=-1.0) "Last send timestamp [s]";
  discrete Real recvTime(start=-1.0) "Last receive timestamp [s]";
  discrete Real dataAge(start=0.0) "Age of most recent received data [s]";
  discrete Real maxDataAge(start=0.0) "Maximum observed data age [s]";
  discrete Real msgTimestamp(start=-1.0) "Timestamp embedded in message [s]";
  discrete Real msgDataX(start=0.0) "Message payload x [m]";
  discrete Real msgDataZ(start=0.0) "Message payload z [m]";
  discrete Real pendingDeliveryTime(start=-1.0) "Scheduled delivery time [s]";
  discrete Boolean messageInFlight(start=false) "Message in transit";
  discrete Boolean handoffSent(start=false) "Handoff evidence sent";
  discrete Boolean handoffReceived(start=false) "Handoff evidence received";
  Boolean inMiddleThird "True during middle third of mission";
  Real effectiveDelay "Current applied communication delay [s]";

  // ===== Task allocation and targets =====
  discrete Integer task1(start=1) "Robot1 task index (1=m1,2=m2,3=loiter)";
  discrete Integer task2(start=0) "Robot2 task index (0=loiter,1=m3,2=m4)";
  discrete Real tx1(start=marker1[1]) "Robot1 target x [m]";
  discrete Real tz1(start=marker1[2]) "Robot1 target z [m]";
  discrete Real tx2(start=x0_2[1]) "Robot2 target x [m]";
  discrete Real tz2(start=x0_2[2]) "Robot2 target z [m]";
  discrete Real handoffDataX(start=0.0) "Received handoff position x [m]";
  discrete Real handoffDataZ(start=0.0) "Received handoff position z [m]";
  discrete Real replanOffset(start=0.0) "Replan distance derived from received data [m]";

  // ===== Synchronized traces and verification flags =====
  Real trackingErr1 "Robot1 tracking error [m]";
  Real trackingErr2 "Robot2 tracking error [m]";
  Real separation "Inter-robot separation [m]";
  Real primaryErr "Primary (active inspector) tracking error [m]";
  Boolean boundCmd "All thruster channels within magnitude bound";
  Boolean boundSep "Separation within lower bound";
  Boolean boundAge "Data age bounded by delay budget";
  Boolean handoffOK "Handoff successful";
  Boolean noCollision "No collision";
  Boolean taskComplete "Inspection task completed";
  Boolean primaryOK "Primary error below tolerance after 7.8 s";
  Boolean finiteOK "No NaN or infinite values";

equation
  // ----- Plant dynamics (2-DOF: surge x, heave z) -----
  der(x1) = vx1;
  der(z1) = vz1;
  der(vx1) = (u1x - dragCoef*vx1) / mass;
  der(vz1) = (u1z - dragCoef*vz1) / mass;
  der(x2) = vx2;
  der(z2) = vz2;
  der(vx2) = (u2x - dragCoef*vx2) / mass;
  der(vz2) = (u2z - dragCoef*vz2) / mass;

  // ----- Sensors -----
  depth1 = -z1;
  depth2 = -z2;
  dvl1x = vx1;
  dvl1z = vz1;
  dvl2x = vx2;
  dvl2z = vz2;
  imu1h = 0.0;
  imu2h = 0.0;

  // ----- Thruster channel allocation (equal split of net command) -----
  F1_sL = u1x/2.0;  F1_sR = u1x/2.0;
  F1_hF = u1z/2.0;  F1_hB = u1z/2.0;
  F2_sL = u2x/2.0;  F2_sR = u2x/2.0;
  F2_hF = u2z/2.0;  F2_hB = u2z/2.0;

  // ----- Communication delay schedule -----
  inMiddleThird = (time >= tMidStart) and (time <= tMidEnd);
  effectiveDelay = if inMiddleThird then delayDist else 0.0;

  // ----- Tracking errors and separation -----
  trackingErr1 = sqrt((x1 - tx1)^2 + (z1 - tz1)^2);
  trackingErr2 = sqrt((x2 - tx2)^2 + (z2 - tz2)^2);
  separation = sqrt((x1 - x2)^2 + (z1 - z2)^2 + 1.0e-9);
  primaryErr = if time < tHandoff then trackingErr1 else trackingErr2;

  // ----- Verification flags -----
  boundCmd = abs(F1_sL)<=maxForce and abs(F1_sR)<=maxForce and abs(F1_hF)<=maxForce and abs(F1_hB)<=maxForce and abs(F2_sL)<=maxForce and abs(F2_sR)<=maxForce and abs(F2_hF)<=maxForce and abs(F2_hB)<=maxForce;
  boundSep = separation >= sepMin;
  boundAge = maxDataAge <= delayDist + 1.0e-6;
  handoffOK = handoffSent and handoffReceived;
  noCollision = separation >= sepMin;
  taskComplete = (task2 >= 2) and (trackingErr2 < errTol);
  primaryOK = (time < tErrCheck) or (primaryErr < errTol);
  finiteOK = abs(x1)<1.0e10 and abs(z1)<1.0e10 and abs(x2)<1.0e10 and abs(z2)<1.0e10 and abs(vx1)<1.0e10 and abs(vz1)<1.0e10 and abs(vx2)<1.0e10 and abs(vz2)<1.0e10 and abs(u1x)<1.0e10 and abs(u1z)<1.0e10 and abs(u2x)<1.0e10 and abs(u2z)<1.0e10;

algorithm
  when sample(0, dtCtrl) then
    // --- Communication: send handoff evidence ---
    if (not handoffSent) and time >= tHandoff then
      handoffSent := true;
      sendTime := time;
      msgTimestamp := time;
      msgDataX := x1;
      msgDataZ := z1;
      messageInFlight := true;
      pendingDeliveryTime := time + effectiveDelay;
    end if;

    // --- Communication: receive with delay ---
    if messageInFlight and time >= pendingDeliveryTime then
      handoffReceived := true;
      recvTime := time;
      dataAge := time - msgTimestamp;
      handoffDataX := msgDataX;
      handoffDataZ := msgDataZ;
      messageInFlight := false;
      if dataAge > maxDataAge then
        maxDataAge := dataAge;
      end if;
    end if;

    // --- Task allocation: Robot1 (inspects features 1 and 2, then loiters) ---
    if task1 == 1 and sqrt((x1-marker1[1])^2 + (z1-marker1[2])^2) < reachTol then
      task1 := 2;
      tx1 := marker2[1];
      tz1 := marker2[2];
    elseif task1 == 2 and handoffSent then
      task1 := 3;
      tx1 := marker2[1];
      tz1 := marker2[2];
    end if;

    // --- Task allocation: Robot2 (loiters, then replans from received data) ---
    if handoffReceived and task2 == 0 then
      task2 := 1;
      replanOffset := sqrt((marker3[1]-handoffDataX)^2 + (marker3[2]-handoffDataZ)^2);
      tx2 := marker3[1];
      tz2 := marker3[2];
    elseif task2 == 1 and sqrt((x2-marker3[1])^2 + (z2-marker3[2])^2) < reachTol then
      task2 := 2;
      tx2 := marker4[1];
      tz2 := marker4[2];
    end if;

    // --- Local motion control: Robot1 (PD on position and DVL velocity) ---
    u1x := kp*(tx1 - x1) - kd*dvl1x;
    u1z := kp*(tz1 - z1) - kd*dvl1z;
    if u1x > 2.0*maxForce then
      u1x := 2.0*maxForce;
    elseif u1x < -2.0*maxForce then
      u1x := -2.0*maxForce;
    end if;
    if u1z > 2.0*maxForce then
      u1z := 2.0*maxForce;
    elseif u1z < -2.0*maxForce then
      u1z := -2.0*maxForce;
    end if;

    // --- Local motion control: Robot2 (PD on position and DVL velocity) ---
    u2x := kp*(tx2 - x2) - kd*dvl2x;
    u2z := kp*(tz2 - z2) - kd*dvl2z;
    if u2x > 2.0*maxForce then
      u2x := 2.0*maxForce;
    elseif u2x < -2.0*maxForce then
      u2x := -2.0*maxForce;
    end if;
    if u2z > 2.0*maxForce then
      u2z := 2.0*maxForce;
    elseif u2z < -2.0*maxForce then
      u2z := -2.0*maxForce;
    end if;
  end when;

  annotation (
    experiment(StartTime=0, StopTime=12.0, Tolerance=1.0e-6, Interval=1.0/125.0),
    Documentation(info="MarinePairHandoffC: two 80 kg AUVs with surge/heave thrusters, local sensors, delayed acoustic modem, task allocation, handoff, and replan. Runs at 125 Hz for 12 s.")
  );
end MarinePairHandoffC;