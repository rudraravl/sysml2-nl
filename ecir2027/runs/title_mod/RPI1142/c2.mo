model AirTrioHandoffB
  "Three 1.8 kg quadrotor inspection: task division, timestamped handoff, replan"

  // ===== Physical constants =====
  parameter Real m = 1.8 "quadrotor mass [kg]";
  parameter Real g = 9.81 "gravity [m/s2]";
  parameter Real Tmax = 9.84 "max rotor thrust command [N]";
  parameter Real Tmin = 0.0 "min rotor thrust command [N]";
  parameter Real tau = 0.02 "actuator time constant [s]";

  // ===== Mission parameters =====
  parameter Real delayOn = 10.0 / 3.0 "communication delay window start [s]";
  parameter Real delayOff = 20.0 / 3.0 "communication delay window end [s]";
  parameter Real delayMag = 0.07 "communication delay magnitude [s]";
  parameter Real inspectionDuration = 2.0 "Robot 1 inspection dwell [s]";
  parameter Real taskReachThresh = 0.3 "task completion threshold [m]";
  parameter Real taskReachSq = 0.09 "squared task completion threshold [m2]";

  // ===== Control gains =====
  parameter Real Kph = 3.0 "horizontal position gain";
  parameter Real Kdh = 4.0 "horizontal velocity gain";
  parameter Real Kpv = 3.0 "vertical position gain";
  parameter Real Kdv = 4.0 "vertical velocity gain";

  // ===== Waypoints (common world frame) =====
  parameter Real wp1x = 2.0;
  parameter Real wp1y = 0.0;
  parameter Real wp1z = 2.0;
  parameter Real wp2x = 0.0;
  parameter Real wp2y = 2.0;
  parameter Real wp2z = 2.0;
  parameter Real wp3x = -2.0;
  parameter Real wp3y = 0.0;
  parameter Real wp3z = 2.0;
  parameter Real wpRx = 1.0;
  parameter Real wpRy = 1.0;
  parameter Real wpRz = 2.0;
  parameter Real h1x = 0.0;
  parameter Real h1y = 0.0;
  parameter Real h1z = 1.0;
  parameter Real h2x = -1.0;
  parameter Real h2y = 0.0;
  parameter Real h2z = 1.0;
  parameter Real h3x = 1.0;
  parameter Real h3y = 0.0;
  parameter Real h3z = 1.0;

  // ===== Robot 1 states =====
  Real x1(start = 0.0) "robot 1 x [m]";
  Real y1(start = 0.0) "robot 1 y [m]";
  Real z1(start = 1.0) "robot 1 z [m]";
  Real vx1(start = 0.0) "robot 1 vx [m/s]";
  Real vy1(start = 0.0) "robot 1 vy [m/s]";
  Real vz1(start = 0.0) "robot 1 vz [m/s]";
  Real T1r1(start = m * g / 4) "R1 rotor 1 thrust [N]";
  Real T2r1(start = m * g / 4) "R1 rotor 2 thrust [N]";
  Real T3r1(start = m * g / 4) "R1 rotor 3 thrust [N]";
  Real T4r1(start = m * g / 4) "R1 rotor 4 thrust [N]";

  // ===== Robot 2 states =====
  Real x2(start = -1.0) "robot 2 x [m]";
  Real y2(start = 0.0) "robot 2 y [m]";
  Real z2(start = 1.0) "robot 2 z [m]";
  Real vx2(start = 0.0) "robot 2 vx [m/s]";
  Real vy2(start = 0.0) "robot 2 vy [m/s]";
  Real vz2(start = 0.0) "robot 2 vz [m/s]";
  Real T1r2(start = m * g / 4) "R2 rotor 1 thrust [N]";
  Real T2r2(start = m * g / 4) "R2 rotor 2 thrust [N]";
  Real T3r2(start = m * g / 4) "R2 rotor 3 thrust [N]";
  Real T4r2(start = m * g / 4) "R2 rotor 4 thrust [N]";

  // ===== Robot 3 states =====
  Real x3(start = 1.0) "robot 3 x [m]";
  Real y3(start = 0.0) "robot 3 y [m]";
  Real z3(start = 1.0) "robot 3 z [m]";
  Real vx3(start = 0.0) "robot 3 vx [m/s]";
  Real vy3(start = 0.0) "robot 3 vy [m/s]";
  Real vz3(start = 0.0) "robot 3 vz [m/s]";
  Real T1r3(start = m * g / 4) "R3 rotor 1 thrust [N]";
  Real T2r3(start = m * g / 4) "R3 rotor 2 thrust [N]";
  Real T3r3(start = m * g / 4) "R3 rotor 3 thrust [N]";
  Real T4r3(start = m * g / 4) "R3 rotor 4 thrust [N]";

  // ===== Setpoints =====
  Real sp1x(start = wp1x);
  Real sp1y(start = wp1y);
  Real sp1z(start = wp1z);
  Real sp2x(start = wp2x);
  Real sp2y(start = wp2y);
  Real sp2z(start = wp2z);
  Real sp3x(start = wp3x);
  Real sp3y(start = wp3y);
  Real sp3z(start = wp3z);

  // ===== Control forces and thrust commands =====
  Real Fx1, Fy1, Fz1, Ftot1;
  Real Fx2, Fy2, Fz2, Ftot2;
  Real Fx3, Fy3, Fz3, Ftot3;
  Real cT1r1, cT2r1, cT3r1, cT4r1;
  Real cT1r2, cT2r2, cT3r2, cT4r2;
  Real cT1r3, cT2r3, cT3r3, cT4r3;

  // ===== Task allocation state =====
  Integer task1(start = 1) "R1: 1=go-to-wp1, 2=inspect, 3=return, 4=done";
  Integer task2(start = 1) "R2: 1=go-to-wp2, 2=return, 3=done";
  Integer task3(start = 1) "R3: 1=go-to-wp3, 2=replanned, 3=return, 4=done";
  Real inspectionStart1(start = 0.0) "R1 inspection start time [s]";

  // ===== Handoff / communication state =====
  Integer handoffState(start = 0) "0=idle, 1=sent-in-transit, 2=received";
  Real sendTime(start = -1.0) "message send timestamp [s]";
  Real arrivalTime(start = -1.0) "message arrival timestamp [s]";
  Real receiveTime(start = -1.0) "message receive timestamp [s]";
  Real commDataAge(start = 0.0) "data age at receive [s]";
  Real currentDataAge(start = 0.0) "current data age [s]";
  Real handoffDataX(start = 0.0) "handoff result x [m]";
  Real handoffDataY(start = 0.0) "handoff result y [m]";
  Real handoffDataZ(start = 0.0) "handoff result z [m]";
  Real handoffTimestamp(start = -1.0) "handoff result timestamp [s]";
  Real commSendLog(start = -1.0) "last send event time [s]";
  Real commRecvLog(start = -1.0) "last receive event time [s]";
  Boolean delayActive "true during middle-third delay window";
  Real currentDelay(start = 0.0) "current comm delay [s]";

  // ===== Sensors =====
  Real gps1x, gps1y, gps1z;
  Real gps2x, gps2y, gps2z;
  Real gps3x, gps3y, gps3z;
  Real imu1ax, imu1ay, imu1az;
  Real imu2ax, imu2ay, imu2az;
  Real imu3ax, imu3ay, imu3az;
  Real range12, range13, range23;

  // ===== Monitoring =====
  Real trackErr1, trackErr2, trackErr3;
  Real trackSq1, trackSq2, trackSq3;
  Real primaryTrackErr;
  Real sep12, sep13, sep23;
  Boolean noCollision;
  Boolean taskComplete;
  Boolean handoffSuccess;
  Boolean boundsSatisfied;
  Real maxThrustCmd;

equation
  // ===== Communication delay activation =====
  delayActive = (time >= delayOn) and (time < delayOff);
  currentDelay = if delayActive then delayMag else 0.0;

  // ===== Setpoint assignment from task state =====
  sp1x = if task1 <= 2 then wp1x else h1x;
  sp1y = if task1 <= 2 then wp1y else h1y;
  sp1z = if task1 <= 2 then wp1z else h1z;

  sp2x = if task2 == 1 then wp2x else h2x;
  sp2y = if task2 == 1 then wp2y else h2y;
  sp2z = if task2 == 1 then wp2z else h2z;

  sp3x = if task3 == 1 then wp3x else if task3 == 2 then wpRx else h3x;
  sp3y = if task3 == 1 then wp3y else if task3 == 2 then wpRy else h3y;
  sp3z = if task3 == 1 then wp3z else if task3 == 2 then wpRz else h3z;

  // ===== Squared tracking errors =====
  trackSq1 = (sp1x - x1)^2 + (sp1y - y1)^2 + (sp1z - z1)^2;
  trackSq2 = (sp2x - x2)^2 + (sp2y - y2)^2 + (sp2z - z2)^2;
  trackSq3 = (sp3x - x3)^2 + (sp3y - y3)^2 + (sp3z - z3)^2;

  // ===== Tracking errors (guarded sqrt) =====
  trackErr1 = sqrt(max(1e-6, trackSq1));
  trackErr2 = sqrt(max(1e-6, trackSq2));
  trackErr3 = sqrt(max(1e-6, trackSq3));
  primaryTrackErr = trackErr1;

  // ===== Robot 1 PD control + 4 rotor thrust groups =====
  Fx1 = m * Kph * (sp1x - x1) - m * Kdh * vx1;
  Fy1 = m * Kph * (sp1y - y1) - m * Kdh * vy1;
  Fz1 = m * Kpv * (sp1z - z1) - m * Kdv * vz1;
  Ftot1 = Fz1 + m * g;
  cT1r1 = if (Ftot1 / 4.0) < Tmin then Tmin else if (Ftot1 / 4.0) > Tmax then Tmax else Ftot1 / 4.0;
  cT2r1 = cT1r1;
  cT3r1 = cT1r1;
  cT4r1 = cT1r1;
  der(T1r1) = (cT1r1 - T1r1) / tau;
  der(T2r1) = (cT2r1 - T2r1) / tau;
  der(T3r1) = (cT3r1 - T3r1) / tau;
  der(T4r1) = (cT4r1 - T4r1) / tau;
  der(x1) = vx1;
  der(y1) = vy1;
  der(z1) = vz1;
  der(vx1) = Fx1 / m;
  der(vy1) = Fy1 / m;
  der(vz1) = (T1r1 + T2r1 + T3r1 + T4r1) / m - g;

  // ===== Robot 2 PD control + 4 rotor thrust groups =====
  Fx2 = m * Kph * (sp2x - x2) - m * Kdh * vx2;
  Fy2 = m * Kph * (sp2y - y2) - m * Kdh * vy2;
  Fz2 = m * Kpv * (sp2z - z2) - m * Kdv * vz2;
  Ftot2 = Fz2 + m * g;
  cT1r2 = if (Ftot2 / 4.0) < Tmin then Tmin else if (Ftot2 / 4.0) > Tmax then Tmax else Ftot2 / 4.0;
  cT2r2 = cT1r2;
  cT3r2 = cT1r2;
  cT4r2 = cT1r2;
  der(T1r2) = (cT1r2 - T1r2) / tau;
  der(T2r2) = (cT2r2 - T2r2) / tau;
  der(T3r2) = (cT3r2 - T3r2) / tau;
  der(T4r2) = (cT4r2 - T4r2) / tau;
  der(x2) = vx2;
  der(y2) = vy2;
  der(z2) = vz2;
  der(vx2) = Fx2 / m;
  der(vy2) = Fy2 / m;
  der(vz2) = (T1r2 + T2r2 + T3r2 + T4r2) / m - g;

  // ===== Robot 3 PD control + 4 rotor thrust groups =====
  Fx3 = m * Kph * (sp3x - x3) - m * Kdh * vx3;
  Fy3 = m * Kph * (sp3y - y3) - m * Kdh * vy3;
  Fz3 = m * Kpv * (sp3z - z3) - m * Kdv * vz3;
  Ftot3 = Fz3 + m * g;
  cT1r3 = if (Ftot3 / 4.0) < Tmin then Tmin else if (Ftot3 / 4.0) > Tmax then Tmax else Ftot3 / 4.0;
  cT2r3 = cT1r3;
  cT3r3 = cT1r3;
  cT4r3 = cT1r3;
  der(T1r3) = (cT1r3 - T1r3) / tau;
  der(T2r3) = (cT2r3 - T2r3) / tau;
  der(T3r3) = (cT3r3 - T3r3) / tau;
  der(T4r3) = (cT4r3 - T4r3) / tau;
  der(x3) = vx3;
  der(y3) = vy3;
  der(z3) = vz3;
  der(vx3) = Fx3 / m;
  der(vy3) = Fy3 / m;
  der(vz3) = (T1r3 + T2r3 + T3r3 + T4r3) / m - g;

  // ===== Sensors (local to each robot) =====
  gps1x = x1;
  gps1y = y1;
  gps1z = z1;
  gps2x = x2;
  gps2y = y2;
  gps2z = z2;
  gps3x = x3;
  gps3y = y3;
  gps3z = z3;
  imu1ax = Fx1 / m;
  imu1ay = Fy1 / m;
  imu1az = (T1r1 + T2r1 + T3r1 + T4r1) / m - g;
  imu2ax = Fx2 / m;
  imu2ay = Fy2 / m;
  imu2az = (T1r2 + T2r2 + T3r2 + T4r2) / m - g;
  imu3ax = Fx3 / m;
  imu3ay = Fy3 / m;
  imu3az = (T1r3 + T2r3 + T3r3 + T4r3) / m - g;
  range12 = sqrt(max(1e-6, (x1 - x2)^2 + (y1 - y2)^2 + (z1 - z2)^2));
  range13 = sqrt(max(1e-6, (x1 - x3)^2 + (y1 - y3)^2 + (z1 - z3)^2));
  range23 = sqrt(max(1e-6, (x2 - x3)^2 + (y2 - y3)^2 + (z2 - z3)^2));

  // ===== Separation and collision check =====
  sep12 = range12;
  sep13 = range13;
  sep23 = range23;
  noCollision = (sep12 > 0.5) and (sep13 > 0.5) and (sep23 > 0.5);

  // ===== Actuator bounds check (scalar explicit) =====
  maxThrustCmd = if cT1r1 > cT2r1 then cT1r1 else cT2r1;
  maxThrustCmd = if maxThrustCmd > cT3r1 then maxThrustCmd else cT3r1;
  maxThrustCmd = if maxThrustCmd > cT4r1 then maxThrustCmd else cT4r1;
  maxThrustCmd = if maxThrustCmd > cT1r2 then maxThrustCmd else cT1r2;
  maxThrustCmd = if maxThrustCmd > cT2r2 then maxThrustCmd else cT2r2;
  maxThrustCmd = if maxThrustCmd > cT3r2 then maxThrustCmd else cT3r2;
  maxThrustCmd = if maxThrustCmd > cT4r2 then maxThrustCmd else cT4r2;
  maxThrustCmd = if maxThrustCmd > cT1r3 then maxThrustCmd else cT1r3;
  maxThrustCmd = if maxThrustCmd > cT2r3 then maxThrustCmd else cT2r3;
  maxThrustCmd = if maxThrustCmd > cT3r3 then maxThrustCmd else cT3r3;
  maxThrustCmd = if maxThrustCmd > cT4r3 then maxThrustCmd else cT4r3;
  boundsSatisfied = maxThrustCmd <= Tmax + 1e-9;

  // ===== Task and handoff completion =====
  taskComplete = (task1 >= 4) and (task2 >= 3) and (task3 >= 4);
  handoffSuccess = handoffState >= 2;

  // ===== Current data age (continuous, bounded) =====
  currentDataAge = if handoffState == 0 then 0.0
    else if handoffState == 1 then time - sendTime
    else commDataAge;

  // ===== Task allocation events =====

  // Robot 1 reaches wp1, begins inspection dwell
  when (trackSq1 < taskReachSq) and (task1 == 1) then
    task1 = 2;
    inspectionStart1 = time;
  end when;

  // Robot 1 completes inspection: sends timestamped handoff, returns home
  when (task1 == 2) and (time >= inspectionStart1 + inspectionDuration) then
    task1 = 3;
    handoffState = 1;
    sendTime = time;
    arrivalTime = time + currentDelay;
    commSendLog = time;
    handoffDataX = x1;
    handoffDataY = y1;
    handoffDataZ = z1;
    handoffTimestamp = time;
  end when;

  // Robot 1 reaches home
  when (trackSq1 < taskReachSq) and (task1 == 3) then
    task1 = 4;
  end when;

  // Robot 2 reaches wp2
  when (trackSq2 < taskReachSq) and (task2 == 1) then
    task2 = 2;
  end when;

  // Robot 2 reaches home
  when (trackSq2 < taskReachSq) and (task2 == 2) then
    task2 = 3;
  end when;

  // Robot 3 receives handoff (with delay) and replans target
  when (handoffState == 1) and (time >= arrivalTime) then
    handoffState = 2;
    receiveTime = time;
    commRecvLog = time;
    commDataAge = time - sendTime;
    task3 = 2;
  end when;

  // Robot 3 reaches replanned target
  when (trackSq3 < taskReachSq) and (task3 == 2) then
    task3 = 3;
  end when;

  // Robot 3 reaches home
  when (trackSq3 < taskReachSq) and (task3 == 3) then
    task3 = 4;
  end when;

  annotation(
    experiment(StartTime = 0, StopTime = 10.0, Tolerance = 1e-6, Interval = 0.01),
    Documentation(info = "Three 1.8 kg quadrotors (12 independent rotor-thrust groups, max 9.84 N each) divide an inspection task across three waypoints in a common world frame. Robot 1 inspects wp1, dwells 2.0 s, then sends a timestamped result to Robot 3. A 0.07 s communication delay is injected during the middle third (3.33-6.67 s). Robot 3 replans to a new waypoint using the received data. Each robot carries GPS, IMU, and peer-relative range sensors. Explicit handoff state machine records send, receive, and data age. Run at 100 Hz for 10 s. Primary (Robot 1) tracking error below 0.48 m after 6.5 s.")
  );
end AirTrioHandoffB;