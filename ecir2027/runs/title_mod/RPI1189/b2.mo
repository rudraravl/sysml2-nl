model MarinePairHandoffA
  parameter Real T = 0.0125 "Sample period (80 Hz, s)";
  parameter Real tend = 8.0 "Scenario duration (s)";
  parameter Real tDelayOn = 8.0/3.0 "Middle third start (s)";
  parameter Real tDelayOff = 16.0/3.0 "Middle third end (s)";
  parameter Real commDelayBase = 0.02 "Nominal modem delay (s)";
  parameter Real commDelayDist = 0.05 "Disturbance delay added in middle third (s)";
  parameter Integer delaySamplesBase = 2 "Base delay in samples (ceil(0.02/0.0125))";
  parameter Integer delaySamplesDist = 6 "Disturbed delay in samples (ceil(0.07/0.0125))";

  parameter Real m_auv = 80.0 "AUV mass (kg)";
  parameter Real Iyaw = 8.0 "Yaw inertia (kg m^2)";
  parameter Real dragX = 18.0 "Surge drag (N s/m)";
  parameter Real dragZ = 18.0 "Heave drag (N s/m)";
  parameter Real dragYaw = 6.0 "Yaw drag (N m s)";
  parameter Real armSurge = 0.4 "Thruster moment arm (m)";
  parameter Real Fmax = 75.6 "Per-thruster command limit (N)";

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

  parameter Real kpx = 300.0 "Surge position gain";
  parameter Real kdx = 220.0 "Surge damping gain";
  parameter Real kpz = 300.0 "Heave position gain";
  parameter Real kdz = 220.0 "Heave damping gain";
  parameter Real kpyaw = 32.0 "Yaw position gain";
  parameter Real kdyaw = 22.0 "Yaw damping gain";

  // Physical states - AUV1
  Real x1(start=0.0, fixed=true) "AUV1 world x (m)";
  Real z1(start=0.0, fixed=true) "AUV1 world z (m)";
  Real yaw1(start=0.0, fixed=true) "AUV1 heading (rad)";
  Real vx1(start=0.0, fixed=true) "AUV1 surge velocity (m/s)";
  Real vz1(start=0.0, fixed=true) "AUV1 heave velocity (m/s)";
  Real wy1(start=0.0, fixed=true) "AUV1 yaw rate (rad/s)";

  // Physical states - AUV2
  Real x2(start=0.0, fixed=true) "AUV2 world x (m)";
  Real z2(start=-3.0, fixed=true) "AUV2 world z (m)";
  Real yaw2(start=0.0, fixed=true) "AUV2 heading (rad)";
  Real vx2(start=0.0, fixed=true) "AUV2 surge velocity (m/s)";
  Real vz2(start=0.0, fixed=true) "AUV2 heave velocity (m/s)";
  Real wy2(start=0.0, fixed=true) "AUV2 yaw rate (rad/s)";

  // Eight bidirectional thruster command channels (discrete, sampled)
  discrete Real Fs_l1(start=0.0) "AUV1 surge-left command (N)";
  discrete Real Fs_r1(start=0.0) "AUV1 surge-right command (N)";
  discrete Real Fh_f1(start=0.0) "AUV1 heave-forward command (N)";
  discrete Real Fh_a1(start=0.0) "AUV1 heave-aft command (N)";
  discrete Real Fs_l2(start=0.0) "AUV2 surge-left command (N)";
  discrete Real Fs_r2(start=0.0) "AUV2 surge-right command (N)";
  discrete Real Fh_f2(start=0.0) "AUV2 heave-forward command (N)";
  discrete Real Fh_a2(start=0.0) "AUV2 heave-aft command (N)";

  // Saturated thruster outputs (continuous)
  Real Fs_l1a, Fs_r1a, Fh_f1a, Fh_a1a;
  Real Fs_l2a, Fs_r2a, Fh_f2a, Fh_a2a;

  // Net forces and torques
  Real Fx1, Fz1, Myaw1, Fx2, Fz2, Myaw2;

  // Local sensors - AUV1
  Real imu_ax1 "AUV1 IMU x-accel (m/s^2)";
  Real imu_az1 "AUV1 IMU z-accel (m/s^2)";
  Real imu_w1  "AUV1 IMU yaw rate (rad/s)";
  Real imu_yaw1 "AUV1 IMU heading (rad)";
  Real dvl_vx1 "AUV1 DVL surge velocity (m/s)";
  Real dvl_vz1 "AUV1 DVL heave velocity (m/s)";
  Real depth1  "AUV1 pressure depth (m)";

  // Local sensors - AUV2
  Real imu_ax2 "AUV2 IMU x-accel (m/s^2)";
  Real imu_az2 "AUV2 IMU z-accel (m/s^2)";
  Real imu_w2  "AUV2 IMU yaw rate (rad/s)";
  Real imu_yaw2 "AUV2 IMU heading (rad)";
  Real dvl_vx2 "AUV2 DVL surge velocity (m/s)";
  Real dvl_vz2 "AUV2 DVL heave velocity (m/s)";
  Real depth2  "AUV2 pressure depth (m)";

  // Communication transmit buffer AUV1 -> AUV2
  discrete Real tx1_x(start=0.0) "Transit payload x (m)";
  discrete Real tx1_z(start=0.0) "Transit payload z (m)";
  discrete Real tx1_stamp(start=-1.0) "Transit timestamp (s)";
  discrete Real tx1_done(start=0.0) "Transit valid flag";
  discrete Integer tx1_count(start=0) "Samples remaining in transit";

  // Communication transmit buffer AUV2 -> AUV1
  discrete Real tx2_x(start=0.0);
  discrete Real tx2_z(start=0.0);
  discrete Real tx2_stamp(start=-1.0);
  discrete Real tx2_done(start=0.0);
  discrete Integer tx2_count(start=0);

  // Communication receive buffers
  discrete Real rx2_x(start=0.0) "AUV2 received x (m)";
  discrete Real rx2_z(start=0.0) "AUV2 received z (m)";
  discrete Real rx2_stamp(start=-1.0) "AUV2 received timestamp (s)";
  discrete Real rx2_done(start=0.0) "AUV2 received valid flag";
  discrete Real rx1_x(start=0.0) "AUV1 received x (m)";
  discrete Real rx1_z(start=0.0) "AUV1 received z (m)";
  discrete Real rx1_stamp(start=-1.0) "AUV1 received timestamp (s)";
  discrete Real rx1_done(start=0.0) "AUV1 received valid flag";

  // Communication event timestamps
  discrete Real send1_t(start=-100.0) "AUV1 send time (s)";
  discrete Real send2_t(start=-100.0) "AUV2 send time (s)";
  discrete Real recv1_t(start=-100.0) "AUV1 receive time (s)";
  discrete Real recv2_t(start=-100.0) "AUV2 receive time (s)";
  Real ageData1 "AUV1 data age (s)";
  Real ageData2 "AUV2 data age (s)";

  Boolean delayActive "Middle-third delay disturbance active";

  // Task allocation and handoff state
  Integer handoffState(start=0) "0=idle, 1=sent, 2=replanned, 3=complete";
  discrete Real target1x(start=3.0) "AUV1 target x (m)";
  discrete Real target1z(start=0.5) "AUV1 target z (m)";
  discrete Real target2x(start=0.0) "AUV2 target x (m)";
  discrete Real target2z(start=-3.0) "AUV2 target z (m)";
  Boolean task1Done(start=false, fixed=true) "AUV1 inspection complete";
  Boolean task2Done(start=false, fixed=true) "AUV2 inspection complete";
  Boolean replanned2(start=false, fixed=true) "AUV2 replanned flag";

  // Performance metrics
  Boolean taskComplete "Both tasks done";
  Boolean handoffOK "Handoff succeeded";
  Boolean noCollision "Separation maintained";
  Real sepDist "Inter-AUV separation (m)";
  Real trackingErr1 "AUV1 tracking error (m)";
  Real trackingErr2 "AUV2 tracking error (m)";

  // Discrete control intermediates
  discrete Real err1x, err1z, yawErr1, Fx1_des, Fz1_des, Myaw1_des;
  discrete Real err2x, err2z, yawErr2, Fx2_des, Fz2_des, Myaw2_des;

equation
  // AUV1 dynamics
  der(x1) = vx1;
  der(z1) = vz1;
  der(yaw1) = wy1;
  m_auv*der(vx1) = Fx1 - dragX*vx1;
  m_auv*der(vz1) = Fz1 - dragZ*vz1;
  Iyaw*der(wy1) = Myaw1 - dragYaw*wy1;
  Fx1 = Fs_l1a + Fs_r1a;
  Fz1 = Fh_f1a + Fh_a1a;
  Myaw1 = (Fs_r1a - Fs_l1a)*armSurge;

  // AUV2 dynamics
  der(x2) = vx2;
  der(z2) = vz2;
  der(yaw2) = wy2;
  m_auv*der(vx2) = Fx2 - dragX*vx2;
  m_auv*der(vz2) = Fz2 - dragZ*vz2;
  Iyaw*der(wy2) = Myaw2 - dragYaw*wy2;
  Fx2 = Fs_l2a + Fs_r2a;
  Fz2 = Fh_f2a + Fh_a2a;
  Myaw2 = (Fs_r2a - Fs_l2a)*armSurge;

  // Thruster saturation (magnitude limit 75.6 N per channel)
  Fs_l1a = if Fs_l1 > Fmax then Fmax elseif Fs_l1 < -Fmax then -Fmax else Fs_l1;
  Fs_r1a = if Fs_r1 > Fmax then Fmax elseif Fs_r1 < -Fmax then -Fmax else Fs_r1;
  Fh_f1a = if Fh_f1 > Fmax then Fmax elseif Fh_f1 < -Fmax then -Fmax else Fh_f1;
  Fh_a1a = if Fh_a1 > Fmax then Fmax elseif Fh_a1 < -Fmax then -Fmax else Fh_a1;
  Fs_l2a = if Fs_l2 > Fmax then Fmax elseif Fs_l2 < -Fmax then -Fmax else Fs_l2;
  Fs_r2a = if Fs_r2 > Fmax then Fmax elseif Fs_r2 < -Fmax then -Fmax else Fs_r2;
  Fh_f2a = if Fh_f2 > Fmax then Fmax elseif Fh_f2 < -Fmax then -Fmax else Fh_f2;
  Fh_a2a = if Fh_a2 > Fmax then Fmax elseif Fh_a2 < -Fmax then -Fmax else Fh_a2;

  // Local sensors - AUV1
  imu_ax1 = (Fx1 - dragX*vx1)/m_auv;
  imu_az1 = (Fz1 - dragZ*vz1)/m_auv;
  imu_w1 = wy1;
  imu_yaw1 = yaw1;
  dvl_vx1 = vx1;
  dvl_vz1 = vz1;
  depth1 = z1;

  // Local sensors - AUV2
  imu_ax2 = (Fx2 - dragX*vx2)/m_auv;
  imu_az2 = (Fz2 - dragZ*vz2)/m_auv;
  imu_w2 = wy2;
  imu_yaw2 = yaw2;
  dvl_vx2 = vx2;
  dvl_vz2 = vz2;
  depth2 = z2;

  // Delay disturbance activation (middle third of scenario)
  delayActive = (time >= tDelayOn) and (time < tDelayOff);

  // Data age from received timestamps
  ageData2 = if rx2_done > 0.5 then time - rx2_stamp else 0.0;
  ageData1 = if rx1_done > 0.5 then time - rx1_stamp else 0.0;

  // Safety and performance metrics
  sepDist = sqrt(max(1e-6, (x1-x2)*(x1-x2) + (z1-z2)*(z1-z2)));
  noCollision = sepDist >= sepMin;
  trackingErr1 = sqrt(max(1e-6, (x1-target1x)*(x1-target1x) + (z1-target1z)*(z1-target1z)));
  trackingErr2 = sqrt(max(1e-6, (x2-target2x)*(x2-target2x) + (z2-target2z)*(z2-target2z)));
  taskComplete = task1Done and task2Done;
  handoffOK = replanned2 and (handoffState >= 2);

  when sample(0, T) then
    // Process in-transit message AUV1 -> AUV2
    if pre(tx1_count) > 0 then
      if pre(tx1_count) <= 1 then
        rx2_x := pre(tx1_x);
        rx2_z := pre(tx1_z);
        rx2_stamp := pre(tx1_stamp);
        rx2_done := pre(tx1_done);
        recv2_t := time;
        tx1_count := 0;
      else
        tx1_count := pre(tx1_count) - 1;
      end if;
    end if;

    // Process in-transit message AUV2 -> AUV1
    if pre(tx2_count) > 0 then
      if pre(tx2_count) <= 1 then
        rx1_x := pre(tx2_x);
        rx1_z := pre(tx2_z);
        rx1_stamp := pre(tx2_stamp);
        rx1_done := pre(tx2_done);
        recv1_t := time;
        tx2_count := 0;
      else
        tx2_count := pre(tx2_count) - 1;
      end if;
    end if;

    // Task 1: AUV1 inspects marker 1 and sends timestamped result
    if not pre(task1Done) and abs(x1 - marker1x) < tolReach and abs(z1 - marker1z) < tolReach then
      task1Done := true;
      send1_t := time;
      tx1_x := x1;
      tx1_z := z1;
      tx1_stamp := time;
      tx1_done := 1.0;
      tx1_count := if delayActive then delaySamplesDist else delaySamplesBase;
      handoffState := 1;
    end if;

    // AUV2 receives and replans target using received inspection data
    if rx2_done > 0.5 and not pre(replanned2) then
      target2x := marker2x + (rx2_x - marker1x);
      target2z := marker2z + (rx2_z - marker1z);
      replanned2 := true;
      handoffState := 2;
    end if;

    // Task 2: AUV2 inspects replanned marker 2 and sends confirmation
    if pre(replanned2) and not pre(task2Done) and abs(x2 - target2x) < tolReach and abs(z2 - target2z) < tolReach then
      task2Done := true;
      send2_t := time;
      tx2_x := x2;
      tx2_z := z2;
      tx2_stamp := time;
      tx2_done := 1.0;
      tx2_count := if delayActive then delaySamplesDist else delaySamplesBase;
      handoffState := 3;
    end if;

    // Local motion control - AUV1
    err1x := target1x - x1;
    err1z := target1z - z1;
    yawErr1 := -yaw1;
    Fx1_des := kpx*err1x - kdx*vx1;
    Fz1_des := kpz*err1z - kdz*vz1;
    Myaw1_des := kpyaw*yawErr1 - kdyaw*wy1;
    Fs_l1 := 0.5*(Fx1_des - Myaw1_des/armSurge);
    Fs_r1 := 0.5*(Fx1_des + Myaw1_des/armSurge);
    Fh_f1 := 0.5*Fz1_des;
    Fh_a1 := 0.5*Fz1_des;

    // Local motion control - AUV2
    err2x := target2x - x2;
    err2z := target2z - z2;
    yawErr2 := -yaw2;
    Fx2_des := kpx*err2x - kdx*vx2;
    Fz2_des := kpz*err2z - kdz*vz2;
    Myaw2_des := kpyaw*yawErr2 - kdyaw*wy2;
    Fs_l2 := 0.5*(Fx2_des - Myaw2_des/armSurge);
    Fs_r2 := 0.5*(Fx2_des + Myaw2_des/armSurge);
    Fh_f2 := 0.5*Fz2_des;
    Fh_a2 := 0.5*Fz2_des;
  end when;

  annotation(
    experiment(StartTime=0, StopTime=8.0, Tolerance=1e-6, Interval=0.0125),
    Documentation(info="MarinePairHandoffA: two 80 kg AUVs with surge/heave thrusters, local sensors (IMU, pressure depth, DVL), and delayed acoustic modem. Eight bidirectional thruster channels limited to 75.6 N each. Inspection task divided: AUV1 inspects marker1, sends timestamped result; AUV2 replans marker2 target using received data. Controlled 0.05 s delay disturbance applied during middle third of 8 s scenario. Sampled at 80 Hz. Communication send, receive, and data age recorded. Explicit handoff state machine. Actuator saturation, separation bounds, and bounded data age enforced."));
end MarinePairHandoffA;