model MarinePairHandoffC
  // ===== Parameters =====
  parameter Real m_auv = 80.0 "AUV mass [kg]";
  parameter Real Fmax = 96.6 "Max command magnitude per thruster [N]";
  parameter Real Ts = 1.0/125.0 "Control/sensor sample period [s]";
  parameter Real delayDist = 0.09 "Disturbed communication delay [s]";
  parameter Real delayNom = 0.001 "Nominal communication delay [s]";
  parameter Real sepMin = 1.0 "Minimum separation [m]";
  parameter Real errThresh = 0.42 "Primary tracking error threshold [m]";
  parameter Real inspectErr = 0.15 "Inspection completion radius [m]";
  parameter Real dwell = 0.8 "Inspection dwell at marker A [s]";
  parameter Real replanTime = 0.1 "Replan duration [s]";
  parameter Real markerA_x = 6.5 "Marker A x in world frame [m]";
  parameter Real markerA_z = 0.5 "Marker A z in world frame [m]";
  parameter Real markerB_x = 1.5 "Marker B x in world frame [m]";
  parameter Real markerB_z = -1.5 "Marker B z in world frame [m]";
  parameter Real start1_x = 0.0 "R1 start x [m]";
  parameter Real start1_z = 0.0 "R1 start z [m]";
  parameter Real start2_x = 0.0 "R2 start x [m]";
  parameter Real start2_z = -1.5 "R2 start z [m]";
  parameter Real standby_x = 0.0 "R2 standby x [m]";
  parameter Real standby_z = -1.5 "R2 standby z [m]";
  parameter Real kp_pos = 180.0 "Position gain [1/s^2]";
  parameter Real kd_vel = 240.0 "Velocity gain [1/s]";
  parameter Real boundMax = 12.0 "World bound [m]";

  // ===== Handoff state constants =====
  constant Real sInspectA = 1.0 "Inspecting marker A";
  constant Real sSend = 2.0 "Sending result";
  constant Real sWait = 3.0 "Waiting for modem";
  constant Real sReceive = 4.0 "Receiving result";
  constant Real sReplan = 5.0 "Replanning R2";
  constant Real sInspectB = 6.0 "Inspecting marker B";
  constant Real sDone = 7.0 "Task complete";

  // ===== Continuous plant states =====
  Real x1(start=start1_x, fixed=true) "R1 x [m]";
  Real z1(start=start1_z, fixed=true) "R1 z [m]";
  Real vx1(start=0.0, fixed=true) "R1 surge velocity [m/s]";
  Real vz1(start=0.0, fixed=true) "R1 heave velocity [m/s]";
  Real x2(start=start2_x, fixed=true) "R2 x [m]";
  Real z2(start=start2_z, fixed=true) "R2 z [m]";
  Real vx2(start=0.0, fixed=true) "R2 surge velocity [m/s]";
  Real vz2(start=0.0, fixed=true) "R2 heave velocity [m/s]";

  // ===== Eight bidirectional thruster channels =====
  Real ch1 "R1 surge ch A [N]";
  Real ch2 "R1 surge ch B [N]";
  Real ch3 "R1 heave ch A [N]";
  Real ch4 "R1 heave ch B [N]";
  Real ch5 "R2 surge ch A [N]";
  Real ch6 "R2 surge ch B [N]";
  Real ch7 "R2 heave ch A [N]";
  Real ch8 "R2 heave ch B [N]";
  Real Fsurge1 "R1 net surge force [N]";
  Real Fheave1 "R1 net heave force [N]";
  Real Fsurge2 "R2 net surge force [N]";
  Real Fheave2 "R2 net heave force [N]";

  // ===== Sampled controller commands =====
  discrete Real u1_cmd(start=0.0) "R1 surge command [N]";
  discrete Real w1_cmd(start=0.0) "R1 heave command [N]";
  discrete Real u2_cmd(start=0.0) "R2 surge command [N]";
  discrete Real w2_cmd(start=0.0) "R2 heave command [N]";

  // ===== Targets =====
  Real x1_tgt "R1 x target [m]";
  Real z1_tgt "R1 z target [m]";
  Real x2_tgt "R2 x target [m]";
  Real z2_tgt "R2 z target [m]";

  // ===== Handoff state =====
  discrete Real handoff(start=sInspectA) "Explicit handoff state";

  // ===== Communication =====
  discrete Real tSend(start=-1.0) "Send time [s]";
  discrete Real tRecv(start=-1.0) "Receive time [s]";
  discrete Real tReachA(start=-10.0) "Time R1 reached marker A [s]";
  discrete Real tInspectB_done(start=-1.0) "Time R2 completed marker B [s]";
  discrete Real txTimestamp(start=0.0) "Timestamp embedded in packet [s]";
  discrete Real txResult(start=0.0) "Inspection result sent [m]";
  discrete Real recvTimestamp(start=0.0) "Received timestamp [s]";
  discrete Real recvResult(start=0.0) "Received result [m]";
  discrete Real appliedDelay(start=0.001) "Delay applied to current packet [s]";
  discrete Real dataAge(start=0.0) "Age of received data at receive [s]";
  discrete Boolean packetReceived(start=false);
  discrete Boolean middleThirdSend(start=false);

  // ===== Local sensors =====
  Real imu1_vx "R1 IMU surge [m/s]";
  Real imu1_vz "R1 IMU heave [m/s]";
  Real depth1 "R1 pressure depth [m]";
  Real dvl1_vx "R1 DVL surge [m/s]";
  Real dvl1_vz "R1 DVL heave [m/s]";
  Real imu2_vx "R2 IMU surge [m/s]";
  Real imu2_vz "R2 IMU heave [m/s]";
  Real depth2 "R2 pressure depth [m]";
  Real dvl2_vx "R2 DVL surge [m/s]";
  Real dvl2_vz "R2 DVL heave [m/s]";

  // ===== Monitoring =====
  Real errA "R1 to marker A error [m]";
  Real errB "R2 to marker B error [m]";
  Real trackingErr "Primary tracking error [m]";
  Real separation "Inter-AUV separation [m]";
  Boolean collision;
  Boolean actuatorOK;
  Boolean separationOK;
  Boolean dataAgeOK;
  Boolean trackingOK;
  Boolean boundOK;
  Boolean taskComplete;
  Boolean noNaN;
  Boolean allOK;

equation
  // ===== Plant dynamics =====
  der(x1) = vx1;
  der(z1) = vz1;
  der(vx1) = Fsurge1 / m_auv;
  der(vz1) = Fheave1 / m_auv;
  der(x2) = vx2;
  der(z2) = vz2;
  der(vx2) = Fsurge2 / m_auv;
  der(vz2) = Fheave2 / m_auv;

  // ===== Targets in common world frame =====
  x1_tgt = markerA_x;
  z1_tgt = markerA_z;
  x2_tgt = if handoff >= sInspectB then (recvResult + (markerB_x - markerA_x)) else standby_x;
  z2_tgt = if handoff >= sInspectB then markerB_z else standby_z;

  // ===== Sampled control and state machine at 125 Hz =====
  when sample(0, Ts) then
    // PD control
    u1_cmd = kp_pos*(x1_tgt - x1) - kd_vel*vx1;
    w1_cmd = kp_pos*(z1_tgt - z1) - kd_vel*vz1;
    u2_cmd = kp_pos*(x2_tgt - x2) - kd_vel*vx2;
    w2_cmd = kp_pos*(z2_tgt - z2) - kd_vel*vz2;

    // State machine
    if handoff < sSend then
      // sInspectA
      if pre(tReachA) < 0.0 and errA < inspectErr then
        tReachA = time;
      end if;
      if pre(tReachA) >= 0.0 and time >= pre(tReachA) + dwell then
        handoff = sSend;
        tSend = time;
        txTimestamp = time;
        txResult = markerA_x;
        middleThirdSend = (time >= 4.0 and time <= 8.0);
        appliedDelay = if (time >= 4.0 and time <= 8.0) then delayDist else delayNom;
      end if;
    elseif handoff < sWait then
      // sSend
      handoff = sWait;
    elseif handoff < sReceive then
      // sWait
      if time >= tSend + appliedDelay then
        handoff = sReceive;
        tRecv = time;
        recvTimestamp = txTimestamp;
        recvResult = txResult;
        packetReceived = true;
        dataAge = time - txTimestamp;
      end if;
    elseif handoff < sReplan then
      // sReceive
      handoff = sReplan;
    elseif handoff < sInspectB then
      // sReplan
      if time >= tRecv + replanTime then
        handoff = sInspectB;
      end if;
    elseif handoff < sDone + 0.5 then
      // sInspectB
      if errB < inspectErr then
        handoff = sDone;
        tInspectB_done = time;
      end if;
    end if;
  end when;

  // ===== Eight thruster channels with saturation at Fmax =====
  ch1 = max(-Fmax, min(Fmax, 0.5*u1_cmd));
  ch2 = max(-Fmax, min(Fmax, 0.5*u1_cmd));
  ch3 = max(-Fmax, min(Fmax, 0.5*w1_cmd));
  ch4 = max(-Fmax, min(Fmax, 0.5*w1_cmd));
  ch5 = max(-Fmax, min(Fmax, 0.5*u2_cmd));
  ch6 = max(-Fmax, min(Fmax, 0.5*u2_cmd));
  ch7 = max(-Fmax, min(Fmax, 0.5*w2_cmd));
  ch8 = max(-Fmax, min(Fmax, 0.5*w2_cmd));

  Fsurge1 = ch1 + ch2;
  Fheave1 = ch3 + ch4;
  Fsurge2 = ch5 + ch6;
  Fheave2 = ch7 + ch8;

  // ===== Sensors =====
  imu1_vx = vx1;
  imu1_vz = vz1;
  depth1 = z1;
  dvl1_vx = vx1;
  dvl1_vz = vz1;
  imu2_vx = vx2;
  imu2_vz = vz2;
  depth2 = z2;
  dvl2_vx = vx2;
  dvl2_vz = vz2;

  // ===== Errors and separation (guarded norms) =====
  errA = sqrt(max((markerA_x - x1)*(markerA_x - x1) + (markerA_z - z1)*(markerA_z - z1), 0.0));
  errB = sqrt(max((markerB_x - x2)*(markerB_x - x2) + (markerB_z - z2)*(markerB_z - z2), 0.0));
  trackingErr = errB;
  separation = sqrt(max((x1 - x2)*(x1 - x2) + (z1 - z2)*(z1 - z2), 1e-9));

  // ===== Requirement monitoring =====
  collision = separation < sepMin;
  actuatorOK = (abs(ch1) <= Fmax + 1e-6) and (abs(ch2) <= Fmax + 1e-6) and
               (abs(ch3) <= Fmax + 1e-6) and (abs(ch4) <= Fmax + 1e-6) and
               (abs(ch5) <= Fmax + 1e-6) and (abs(ch6) <= Fmax + 1e-6) and
               (abs(ch7) <= Fmax + 1e-6) and (abs(ch8) <= Fmax + 1e-6);
  separationOK = separation >= sepMin;
  dataAgeOK = (not packetReceived) or (dataAge <= 0.1);
  trackingOK = (time < 7.8) or (trackingErr <= errThresh);
  boundOK = abs(x1) <= boundMax and abs(z1) <= boundMax and
            abs(x2) <= boundMax and abs(z2) <= boundMax;
  taskComplete = handoff >= sDone;
  noNaN = abs(x1) < 1e6 and abs(z1) < 1e6 and abs(vx1) < 1e6 and abs(vz1) < 1e6 and
          abs(x2) < 1e6 and abs(z2) < 1e6 and abs(vx2) < 1e6 and abs(vz2) < 1e6 and
          abs(Fsurge1) < 1e6 and abs(Fheave1) < 1e6 and
          abs(Fsurge2) < 1e6 and abs(Fheave2) < 1e6;
  allOK = actuatorOK and separationOK and dataAgeOK and trackingOK and boundOK and taskComplete and noNaN and (not collision);

  annotation (
    experiment(StopTime=12.0, Tolerance=1e-6, Interval=0.008),
    Documentation(info="MarinePairHandoffC: two 80 kg AUVs divide an inspection task, exchange a timestamped result over a delayed acoustic modem (0.09 s disturbance during middle third [4,8] s), and replan R2 using received data. Eight bidirectional thruster channels saturate at 96.6 N. Run at 125 Hz for 12 s."));
end MarinePairHandoffC;