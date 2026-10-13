model MarinePairHandoffA
  // ===== Sampling and scenario timing =====
  parameter Real T = 0.0125 "Sample period (80 Hz)";
  parameter Real tend = 8.0 "Scenario duration (s)";
  parameter Real tDelayOn = 8.0/3.0 "Middle third start (s)";
  parameter Real tDelayOff = 16.0/3.0 "Middle third end (s)";
  parameter Real commDelayBase = 0.02 "Nominal acoustic modem propagation delay (s)";
  parameter Real commDelayDist = 0.05 "Controlled delay disturbance added during middle third (s)";

  // ===== Vehicle parameters =====
  parameter Real m_auv = 80.0 "AUV mass (kg)";
  parameter Real Iyaw = 8.0 "Yaw inertia (kg m^2)";
  parameter Real dragX = 18.0 "Surge linear drag (N s/m)";
  parameter Real dragZ = 18.0 "Heave linear drag (N s/m)";
  parameter Real dragYaw = 6.0 "Yaw linear drag (N m s)";
  parameter Real armSurge = 0.4 "Surge thruster yaw moment arm (m)";
  parameter Real Fmax = 75.6 "Per-thruster command magnitude limit (N)";

  // ===== World bounds and survey features (common world frame) =====
  parameter Real wallXmax = 10.0 "Right wall x (m)";
  parameter Real wallXmin = -1.0 "Left wall x (m)";
  parameter Real zTop = 5.0 "Upper vertical bound (m)";
  parameter Real zBot = -8.0 "Lower vertical bound (m)";
  parameter Real sepMin = 1.2 "Minimum inter-AUV separation (m)";
  parameter Real marker1x = 3.0 "Inspection marker 1 x (m)";
  parameter Real marker1z = 0.5 "Inspection marker 1 z (m)";
  parameter Real marker2x = 6.0 "Inspection marker 2 x (m)";
  parameter Real marker2z = -0.5 "Inspection marker 2 z (m)";
  parameter Real home2x = 0.0 "AUV2 home x (m)";
  parameter Real home2z = -3.0 "AUV2 home z (m)";
  parameter Real tolReach = 0.25 "Reach tolerance (m)";

  // ===== AUV1 fixed task target (constant, no discrete reassignment needed) =====
  parameter Real target1x = marker1x "AUV1 target x (m)";
  parameter Real target1z = marker1z "AUV1 target z (m)";

  // ===== Control gains =====
  parameter Real kpx = 300.0 "Surge position gain";
  parameter Real kdx = 220.0 "Surge damping gain";
  parameter Real kpz = 300.0 "Heave position gain";
  parameter Real kdz = 220.0 "Heave damping gain";
  parameter Real kpyaw = 32.0 "Yaw position gain";
  parameter Real kdyaw = 22.0 "Yaw damping gain";

  // ===== AUV1 continuous states =====
  Real x1(start=0.0, fixed=true) "AUV1 world x (m)";
  Real z1(start=0.0, fixed=true) "AUV1 world z (m)";
  Real yaw1(start=0.0, fixed=true) "AUV1 heading (rad)";
  Real vx1(start=0.0, fixed=true) "AUV1 surge velocity (m/s)";
  Real vz1(start=0.0, fixed=true) "AUV1 heave velocity (m/s)";
  Real wy1(start=0.0, fixed=true) "AUV1 yaw rate (rad/s)";

  // ===== AUV2 continuous states =====
  Real x2(start=0.0, fixed=true) "AUV2 world x (m)";
  Real z2(start=-3.0, fixed=true) "AUV2 world z (m)";
  Real yaw2(start=0.0, fixed=true) "AUV2 heading (rad)";
  Real vx2(start=0.0, fixed=true) "AUV2 surge velocity (m/s)";
  Real vz2(start=0.0, fixed=true) "AUV2 heave velocity (m/s)";
  Real wy2(start=0.0, fixed=true) "AUV2 yaw rate (rad/s)";

  // ===== Eight thruster command channels (sampled, bidirectional) =====
  discrete Real Fs_l1(start=0.0) "AUV1 surge-left command (N)";
  discrete Real Fs_r1(start=0.0) "AUV1 surge-right command (N)";
  discrete Real Fh_f1(start=0.0) "AUV1 heave-forward command (N)";
  discrete Real Fh_a1(start=0.0) "AUV1 heave-aft command (N)";
  discrete Real Fs_l2(start=0.0) "AUV2 surge-left command (N)";
  discrete Real Fs_r2(start=0.0) "AUV2 surge-right command (N)";
  discrete Real Fh_f2(start=0.0) "AUV2 heave-forward command (N)";
  discrete Real Fh_a2(start=0.0) "AUV2 heave-aft command (N)";
  // Saturated actual thruster outputs
  Real Fs_l1a, Fs_r1a, Fh_f1a, Fh_a1a;
  Real Fs_l2a, Fs_r2a, Fh_f2a, Fh_a2a;
  // Resultant body-frame forces/torques
  Real Fx1, Fz1, Myaw1, Fx2, Fz2, Myaw2;

  // ===== Local sensors (preserved per AUV) =====
  Real imu_ax1, imu_az1, imu_w1, imu_yaw1;
  Real dvl_vx1, dvl_vz1;
  Real depth1;
  Real imu_ax2, imu_az2, imu_w2, imu_yaw2;
  Real dvl_vx2, dvl_vz2;
  Real depth2;

  // ===== Acoustic modem communication =====
  Real commDelayCurrent "Current effective modem delay (s)";
  Boolean delayActive "True during middle-third delay disturbance";
  discrete Real msg1_x(start=0.0), msg1_z(start=0.0), msg1_stamp(start=-1.0), msg1_done(start=0.0);
  discrete Real msg2_x(start=0.0), msg2_z(start=0.0), msg2_stamp(start=-1.0), msg2_done(start=0.0);
  Real rx1_x, rx1_z, rx1_stamp, rx1_done;
  Real rx2_x, rx2_z, rx2_stamp, rx2_done;
  discrete Real send1_t(start=-100.0), send2_t(start=-100.0);
  discrete Real recv1_t(start=-100.0), recv2_t(start=-100.0);
  discrete Boolean recv1Done(start=false, fixed=true);
  Real ageData1, ageData2;

  // ===== Task allocation, handoff, and replan =====
  Integer handoffState(start=0) "Explicit handoff state machine";
  discrete Real target2x(start=0.0), target2z(start=-3.0);
  Boolean task1Done(start=false, fixed=true);
  Boolean task2Done(start=false, fixed=true);
  Boolean replanned2(start=false, fixed=true);
  Boolean taskComplete, handoffOK, noCollision;
  Real sepDist;
  Real trackingErr1, trackingErr2;

equation
  // ===== AUV1 dynamics =====
  der(x1) = vx1;
  der(z1) = vz1;
  der(yaw1) = wy1;
  m_auv*der(vx1) = Fx1 - dragX*vx1;
  m_auv*der(vz1) = Fz1 - dragZ*vz1;
  Iyaw*der(wy1) = Myaw1 - dragYaw*wy1;
  Fx1 = Fs_l1a + Fs_r1a;
  Fz1 = Fh_f1a + Fh_a1a;
  Myaw1 = (Fs_r1a - Fs_l1a)*armSurge;

  // ===== AUV2 dynamics =====
  der(x2) = vx2;
  der(z2) = vz2;
  der(yaw2) = wy2;
  m_auv*der(vx2) = Fx2 - dragX*vx2;
  m_auv*der(vz2) = Fz2 - dragZ*vz2;
  Iyaw*der(wy2) = Myaw2 - dragYaw*wy2;
  Fx2 = Fs_l2a + Fs_r2a;
  Fz2 = Fh_f2a + Fh_a2a;
  Myaw2 = (Fs_r2a - Fs_l2a)*armSurge;

  // ===== Per-thruster command saturation (actuator bounds) =====
  Fs_l1a = if Fs_l1 > Fmax then Fmax elseif Fs_l1 < -Fmax then -Fmax else Fs_l1;
  Fs_r1a = if Fs_r1 > Fmax then Fmax elseif Fs_r1 < -Fmax then -Fmax else Fs_r1;
  Fh_f1a = if Fh_f1 > Fmax then Fmax elseif Fh_f1 < -Fmax then -Fmax else Fh_f1;
  Fh_a1a = if Fh_a1 > Fmax then Fmax elseif Fh_a1 < -Fmax then -Fmax else Fh_a1;
  Fs_l2a = if Fs_l2 > Fmax then Fmax elseif Fs_l2 < -Fmax then -Fmax else Fs_l2;
  Fs_r2a = if Fs_r2 > Fmax then Fmax elseif Fs_r2 < -Fmax then -Fmax else Fs_r2;
  Fh_f2a = if Fh_f2 > Fmax then Fmax elseif Fh_f2 < -Fmax then -Fmax else Fh_f2;
  Fh_a2a = if Fh_a2 > Fmax then Fmax elseif Fh_a2 < -Fmax then -Fmax else Fh_a2;

  // ===== AUV1 local sensors =====
  imu_ax1 = der(vx1);
  imu_az1 = der(vz1);
  imu_w1 = wy1;
  imu_yaw1 = yaw1;
  dvl_vx1 = vx1;
  dvl_vz1 = vz1;
  depth1 = z1;

  // ===== AUV2 local sensors =====
  imu_ax2 = der(vx2);
  imu_az2 = der(vz2);
  imu_w2 = wy2;
  imu_yaw2 = yaw2;
  dvl_vx2 = vx2;
  dvl_vz2 = vz2;
  depth2 = z2;

  // ===== Modem delay disturbance (controlled, middle third only) =====
  delayActive = (time >= tDelayOn) and (time < tDelayOff);
  commDelayCurrent = if delayActive then commDelayBase + commDelayDist else commDelayBase;

  // Delayed received message signals (variable delay, max 0.2 s)
  rx2_x = delay(msg1_x, commDelayCurrent, 0.2);
  rx2_z = delay(msg1_z, commDelayCurrent, 0.2);
  rx2_stamp = delay(msg1_stamp, commDelayCurrent, 0.2);
  rx2_done = delay(msg1_done, commDelayCurrent, 0.2);
  rx1_x = delay(msg2_x, commDelayCurrent, 0.2);
  rx1_z = delay(msg2_z, commDelayCurrent, 0.2);
  rx1_stamp = delay(msg2_stamp, commDelayCurrent, 0.2);
  rx1_done = delay(msg2_done, commDelayCurrent, 0.2);

  // Recorded communication data age (bounded by reach of scenario)
  ageData2 = if rx2_done > 0.5 then time - rx2_stamp else 0.0;
  ageData1 = if rx1_done > 0.5 then time - rx1_stamp else 0.0;

  // ===== Separation, tracking errors, and status flags =====
  sepDist = sqrt(max(1e-6, (x1-x2)*(x1-x2) + (z1-z2)*(z1-z2)));
  noCollision = sepDist >= sepMin;
  trackingErr1 = sqrt(max(1e-6, (x1-target1x)*(x1-target1x) + (z1-target1z)*(z1-target1z)));
  trackingErr2 = sqrt(max(1e-6, (x2-target2x)*(x2-target2x) + (z2-target2z)*(z2-target2z)));
  taskComplete = task1Done and task2Done;
  handoffOK = replanned2 and (handoffState >= 2);

  // ===== Discrete task allocation, handoff, and local control at 80 Hz =====
  when sample(0, T) then
    // --- AUV1 reaches marker1: declare task1 done, send timestamped result ---
    if not pre(task1Done) and abs(x1 - marker1x) < tolReach and abs(z1 - marker1z) < tolReach then
      task1Done = true;
      send1_t = time;
      msg1_x = x1;
      msg1_z = z1;
      msg1_stamp = time;
      msg1_done = 1.0;
      handoffState = 1;
    end if;

    // --- AUV2 receives AUV1's timestamped result and replans using received data ---
    if rx2_done > 0.5 and not pre(replanned2) then
      recv2_t = time;
      target2x = marker2x + (rx2_x - marker1x);
      target2z = marker2z + (rx2_z - marker1z);
      replanned2 = true;
      handoffState = 2;
    end if;

    // --- AUV2 reaches its replanned target: complete handoff, send result back ---
    if pre(replanned2) and not pre(task2Done) and abs(x2 - target2x) < tolReach and abs(z2 - target2z) < tolReach then
      task2Done = true;
      send2_t = time;
      msg2_x = x2;
      msg2_z = z2;
      msg2_stamp = time;
      msg2_done = 1.0;
      handoffState = 3;
    end if;

    // --- AUV1 records receipt of AUV2's timestamped result ---
    if rx1_done > 0.5 and not pre(recv1Done) then
      recv1_t = time;
      recv1Done = true;
    end if;

    // --- AUV1 local motion control (tracks marker1 then holds) ---
    Fs_l1 = 0.5*(kpx*(target1x - x1) - kdx*vx1 - (kpyaw*(-yaw1) - kdyaw*wy1)/armSurge);
    Fs_r1 = 0.5*(kpx*(target1x - x1) - kdx*vx1 + (kpyaw*(-yaw1) - kdyaw*wy1)/armSurge);
    Fh_f1 = 0.5*(kpz*(target1z - z1) - kdz*vz1);
    Fh_a1 = 0.5*(kpz*(target1z - z1) - kdz*vz1);

    // --- AUV2 local motion control (waits at home, then tracks replanned target) ---
    Fs_l2 = 0.5*(kpx*(target2x - x2) - kdx*vx2 - (kpyaw*(-yaw2) - kdyaw*wy2)/armSurge);
    Fs_r2 = 0.5*(kpx*(target2x - x2) - kdx*vx2 + (kpyaw*(-yaw2) - kdyaw*wy2)/armSurge);
    Fh_f2 = 0.5*(kpz*(target2z - z2) - kdz*vz2);
    Fh_a2 = 0.5*(kpz*(target2z - z2) - kdz*vz2);
  end when;

  annotation(
    experiment(StartTime=0, StopTime=8.0, Tolerance=1e-6, Interval=0.0125),
    Documentation(info="MarinePairHandoffA: two 80 kg AUVs with surge/heave thrusters, local sensors (IMU, depth, DVL), and delayed acoustic modem. Eight bidirectional thruster channels limited to 75.6 N each. Inspection task divided between AUV1 (marker1) and AUV2 (marker2). AUV1 sends a timestamped result upon completion; AUV2 replans its target using the received data. Both robots record send, receive, and data age. Controlled 0.05 s delay disturbance applied during the middle third of the 8 s scenario. Sampled at 80 Hz."));
end MarinePairHandoffA;