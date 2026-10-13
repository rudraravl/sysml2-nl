model AirTrioHandoffF
  "Three-quadrotor inspection task division with timestamped handoff and communication delay"

  // ===== Physical Constants =====
  parameter Real g = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real m = 1.8 "Quadrotor mass [kg]";
  parameter Real Tmax = 14.6 "Max thrust per rotor [N]";

  // ===== Simulation Parameters =====
  parameter Real Tsim = 20.0 "Simulation duration [s]";
  parameter Real fs = 500.0 "Sampling frequency [Hz]";

  // ===== Communication Parameters =====
  parameter Real delayNominal = 0.001 "Nominal communication delay [s]";
  parameter Real delayDist = 0.145 "Disturbance communication delay [s]";

  // ===== Control Gains =====
  parameter Real kp = 2.5 "Position proportional gain [1/s2]";
  parameter Real kd = 3.5 "Velocity derivative gain [1/s]";

  // ===== World Frame Survey Markers (Inspection Targets) =====
  parameter Real marker1x = 5.0 "Survey marker 1 x [m]";
  parameter Real marker1y = 0.0 "Survey marker 1 y [m]";
  parameter Real marker1z = 3.0 "Survey marker 1 z [m]";
  parameter Real marker2x = 0.0 "Survey marker 2 x [m]";
  parameter Real marker2y = 5.0 "Survey marker 2 y [m]";
  parameter Real marker2z = 3.0 "Survey marker 2 z [m]";
  parameter Real marker3x = -5.0 "Survey marker 3 x [m]";
  parameter Real marker3y = 0.0 "Survey marker 3 y [m]";
  parameter Real marker3z = 3.0 "Survey marker 3 z [m]";
  parameter Real wallX = 10.0 "Boundary wall x position [m]";

  // Feature discovered by robot 1 during inspection (sent in handoff)
  parameter Real featureX = 3.0 "Feature x position [m]";
  parameter Real featureY = 2.0 "Feature y position [m]";
  parameter Real featureZ = 3.0 "Feature z position [m]";

  // ===== Safety and Verification Parameters =====
  parameter Real minSeparation = 1.0 "Minimum safe separation [m]";
  parameter Real trackingThreshold = 0.32 "Max tracking error after 13 s [m]";
  parameter Real maxDataAge = 1.0 "Max acceptable data age [s]";
  parameter Real inspectTime = 5.0 "Required inspection hover time [s]";
  parameter Real nearRadius = 0.8 "Near-target radius for inspection [m]";
  parameter Real completeRadius = 0.5 "Task completion radius [m]";
  parameter Real eps = 1.0e-6 "Small constant for numerical safety";

  // ===== Communication Delay =====
  Boolean inMiddleThird "In middle third of simulation";
  Real commDelay "Current communication delay [s]";

  // ===== Robot 1 States =====
  Real r1x(start=0.0, fixed=true) "Robot 1 x position [m]";
  Real r1y(start=0.0, fixed=true) "Robot 1 y position [m]";
  Real r1z(start=0.0, fixed=true) "Robot 1 z position [m]";
  Real v1x(start=0.0, fixed=true) "Robot 1 x velocity [m/s]";
  Real v1y(start=0.0, fixed=true) "Robot 1 y velocity [m/s]";
  Real v1z(start=0.0, fixed=true) "Robot 1 z velocity [m/s]";

  // ===== Robot 2 States =====
  Real r2x(start=2.0, fixed=true) "Robot 2 x position [m]";
  Real r2y(start=0.0, fixed=true) "Robot 2 y position [m]";
  Real r2z(start=0.0, fixed=true) "Robot 2 z position [m]";
  Real v2x(start=0.0, fixed=true) "Robot 2 x velocity [m/s]";
  Real v2y(start=0.0, fixed=true) "Robot 2 y velocity [m/s]";
  Real v2z(start=0.0, fixed=true) "Robot 2 z velocity [m/s]";

  // ===== Robot 3 States =====
  Real r3x(start=-2.0, fixed=true) "Robot 3 x position [m]";
  Real r3y(start=0.0, fixed=true) "Robot 3 y position [m]";
  Real r3z(start=0.0, fixed=true) "Robot 3 z position [m]";
  Real v3x(start=0.0, fixed=true) "Robot 3 x velocity [m/s]";
  Real v3y(start=0.0, fixed=true) "Robot 3 y velocity [m/s]";
  Real v3z(start=0.0, fixed=true) "Robot 3 z velocity [m/s]";

  // ===== Rotor Thrusts (12 Independent Groups) =====
  Real T1_1 "Robot 1 rotor 1 thrust [N]";
  Real T1_2 "Robot 1 rotor 2 thrust [N]";
  Real T1_3 "Robot 1 rotor 3 thrust [N]";
  Real T1_4 "Robot 1 rotor 4 thrust [N]";
  Real T2_1 "Robot 2 rotor 1 thrust [N]";
  Real T2_2 "Robot 2 rotor 2 thrust [N]";
  Real T2_3 "Robot 2 rotor 3 thrust [N]";
  Real T2_4 "Robot 2 rotor 4 thrust [N]";
  Real T3_1 "Robot 3 rotor 1 thrust [N]";
  Real T3_2 "Robot 3 rotor 2 thrust [N]";
  Real T3_3 "Robot 3 rotor 3 thrust [N]";
  Real T3_4 "Robot 3 rotor 4 thrust [N]";

  // ===== Control Forces =====
  Real F1x "Robot 1 x control force [N]";
  Real F1y "Robot 1 y control force [N]";
  Real F1z "Robot 1 z control force [N]";
  Real F2x "Robot 2 x control force [N]";
  Real F2y "Robot 2 y control force [N]";
  Real F2z "Robot 2 z control force [N]";
  Real F3x "Robot 3 x control force [N]";
  Real F3y "Robot 3 y control force [N]";
  Real F3z "Robot 3 z control force [N]";
  Real F1mag "Robot 1 total thrust magnitude [N]";
  Real F2mag "Robot 2 total thrust magnitude [N]";
  Real F3mag "Robot 3 total thrust magnitude [N]";

  // ===== Control References =====
  Real rx1_ref "Robot 1 x reference [m]";
  Real ry1_ref "Robot 1 y reference [m]";
  Real rz1_ref "Robot 1 z reference [m]";
  Real rx2_ref "Robot 2 x reference [m]";
  Real ry2_ref "Robot 2 y reference [m]";
  Real rz2_ref "Robot 2 z reference [m]";
  Real rx3_ref "Robot 3 x reference [m]";
  Real ry3_ref "Robot 3 y reference [m]";
  Real rz3_ref "Robot 3 z reference [m]";

  // ===== GPS Sensors =====
  Real gps1x "Robot 1 GPS x [m]";
  Real gps1y "Robot 1 GPS y [m]";
  Real gps1z "Robot 1 GPS z [m]";
  Real gps2x "Robot 2 GPS x [m]";
  Real gps2y "Robot 2 GPS y [m]";
  Real gps2z "Robot 2 GPS z [m]";
  Real gps3x "Robot 3 GPS x [m]";
  Real gps3y "Robot 3 GPS y [m]";
  Real gps3z "Robot 3 GPS z [m]";

  // ===== IMU Sensors (Accelerometer) =====
  Real imu1x "Robot 1 IMU x accel [m/s2]";
  Real imu1y "Robot 1 IMU y accel [m/s2]";
  Real imu1z "Robot 1 IMU z accel [m/s2]";
  Real imu2x "Robot 2 IMU x accel [m/s2]";
  Real imu2y "Robot 2 IMU y accel [m/s2]";
  Real imu2z "Robot 2 IMU z accel [m/s2]";
  Real imu3x "Robot 3 IMU x accel [m/s2]";
  Real imu3y "Robot 3 IMU y accel [m/s2]";
  Real imu3z "Robot 3 IMU z accel [m/s2]";

  // ===== Peer-Relative Range Sensors =====
  Real d12 "Range robot1-robot2 [m]";
  Real d13 "Range robot1-robot3 [m]";
  Real d23 "Range robot2-robot3 [m]";

  // ===== Communication State =====
  discrete Real sendTime(start=-1.0) "Last send timestamp [s]";
  discrete Real recvTime(start=-1.0) "Last receive timestamp [s]";
  discrete Real dataAge(start=0.0) "Data age of last received message [s]";
  discrete Real commBufferX(start=0.0) "Buffered data X [m]";
  discrete Real commBufferY(start=0.0) "Buffered data Y [m]";
  discrete Real commBufferZ(start=0.0) "Buffered data Z [m]";
  Real commTimer(start=100.0, fixed=true) "Communication countdown timer [s]";
  Boolean commInFlight(start=false) "Message in flight";

  // ===== Handoff State Machine =====
  Integer handoffState(start=1) "1=inspect,2=sending,3=replanned,4=done";
  Boolean replanReceived(start=false) "Robot 2 received replan data";
  Boolean handoffDone(start=false) "Handoff completed successfully";
  Boolean taskComplete(start=false) "All tasks completed";
  Real inspectTimer(start=0.0, fixed=true) "Inspection hover timer [s]";
  Boolean nearTarget1 "Robot 1 within inspection radius of target 1";

  // ===== Replanned Target for Robot 2 =====
  discrete Real p2x_replan(start=0.0) "Replanned target X [m]";
  discrete Real p2y_replan(start=5.0) "Replanned target Y [m]";
  discrete Real p2z_replan(start=3.0) "Replanned target Z [m]";

  // ===== Verification Metrics =====
  Real primaryError "Primary tracking error (robot 2) [m]";
  Real separationMin "Minimum pairwise separation [m]";
  Real maxT1 "Max rotor thrust robot 1 [N]";
  Real maxT2 "Max rotor thrust robot 2 [N]";
  Real maxT3 "Max rotor thrust robot 3 [N]";
  Real peakThrust "Peak rotor thrust across all 12 [N]";

  // ===== Verification Flags =====
  Boolean actuatorOK "Actuator bounds satisfied";
  Boolean separationOK "Separation bounds satisfied";
  Boolean dataAgeOK "Data age bounded";
  Boolean handoffOK "Handoff successful";
  Boolean noCollision "No collision detected";
  Boolean taskOK "Task completion achieved";
  Boolean trackingOK "Primary tracking error below threshold after 13 s";
  Boolean noNaN "No NaN or infinite values";
  Boolean allVerified "All verification criteria met";

equation

  // ===== Communication Delay Disturbance =====
  // 0.145 s during middle third, nominal otherwise
  inMiddleThird = time >= Tsim / 3.0 and time <= 2.0 * Tsim / 3.0;
  commDelay = if inMiddleThird then delayDist else delayNominal;

  // Communication timer countdown
  der(commTimer) = if commInFlight then -1.0 else 0.0;

  // ===== Peer-Relative Range Sensing =====
  d12 = sqrt((r1x - r2x)^2 + (r1y - r2y)^2 + (r1z - r2z)^2 + eps);
  d13 = sqrt((r1x - r3x)^2 + (r1y - r3y)^2 + (r1z - r3z)^2 + eps);
  d23 = sqrt((r2x - r3x)^2 + (r2y - r3y)^2 + (r2z - r3z)^2 + eps);

  // ===== GPS Sensing =====
  gps1x = r1x;  gps1y = r1y;  gps1z = r1z;
  gps2x = r2x;  gps2y = r2y;  gps2z = r2z;
  gps3x = r3x;  gps3y = r3y;  gps3z = r3z;

  // ===== IMU Sensing (Specific Force / Acceleration) =====
  imu1x = F1x / m;  imu1y = F1y / m;  imu1z = F1z / m - g;
  imu2x = F2x / m;  imu2y = F2y / m;  imu2z = F2z / m - g;
  imu3x = F3x / m;  imu3y = F3y / m;  imu3z = F3z / m - g;

  // ===== Task Allocation: Reference Generation =====
  // Robot 1 inspects marker 1 (fixed)
  rx1_ref = marker1x;  ry1_ref = marker1y;  rz1_ref = marker1z;
  // Robot 2 inspects marker 2 initially, replans after handoff
  rx2_ref = if replanReceived then p2x_replan else marker2x;
  ry2_ref = if replanReceived then p2y_replan else marker2y;
  rz2_ref = if replanReceived then p2z_replan else marker2z;
  // Robot 3 inspects marker 3 (fixed)
  rx3_ref = marker3x;  ry3_ref = marker3y;  rz3_ref = marker3z;

  // ===== PD Position Control =====
  // Robot 1
  F1x = m * kp * (rx1_ref - r1x) - m * kd * v1x;
  F1y = m * kp * (ry1_ref - r1y) - m * kd * v1y;
  F1z = m * kp * (rz1_ref - r1z) - m * kd * v1z + m * g;
  // Robot 2
  F2x = m * kp * (rx2_ref - r2x) - m * kd * v2x;
  F2y = m * kp * (ry2_ref - r2y) - m * kd * v2y;
  F2z = m * kp * (rz2_ref - r2z) - m * kd * v2z + m * g;
  // Robot 3
  F3x = m * kp * (rx3_ref - r3x) - m * kd * v3x;
  F3y = m * kp * (ry3_ref - r3y) - m * kd * v3y;
  F3z = m * kp * (rz3_ref - r3z) - m * kd * v3z + m * g;

  // ===== Total Thrust Magnitude =====
  F1mag = sqrt(F1x^2 + F1y^2 + F1z^2 + eps);
  F2mag = sqrt(F2x^2 + F2y^2 + F2z^2 + eps);
  F3mag = sqrt(F3x^2 + F3y^2 + F3z^2 + eps);

  // ===== Rotor Thrust Allocation (Equal Sharing, Bounded) =====
  T1_1 = max(0.0, min(Tmax, F1mag / 4.0));
  T1_2 = max(0.0, min(Tmax, F1mag / 4.0));
  T1_3 = max(0.0, min(Tmax, F1mag / 4.0));
  T1_4 = max(0.0, min(Tmax, F1mag / 4.0));
  T2_1 = max(0.0, min(Tmax, F2mag / 4.0));
  T2_2 = max(0.0, min(Tmax, F2mag / 4.0));
  T2_3 = max(0.0, min(Tmax, F2mag / 4.0));
  T2_4 = max(0.0, min(Tmax, F2mag / 4.0));
  T3_1 = max(0.0, min(Tmax, F3mag / 4.0));
  T3_2 = max(0.0, min(Tmax, F3mag / 4.0));
  T3_3 = max(0.0, min(Tmax, F3mag / 4.0));
  T3_4 = max(0.0, min(Tmax, F3mag / 4.0));

  // ===== Robot 1 Dynamics =====
  der(r1x) = v1x;  der(r1y) = v1y;  der(r1z) = v1z;
  m * der(v1x) = F1x;
  m * der(v1y) = F1y;
  m * der(v1z) = F1z - m * g;

  // ===== Robot 2 Dynamics =====
  der(r2x) = v2x;  der(r2y) = v2y;  der(r2z) = v2z;
  m * der(v2x) = F2x;
  m * der(v2y) = F2y;
  m * der(v2z) = F2z - m * g;

  // ===== Robot 3 Dynamics =====
  der(r3x) = v3x;  der(r3y) = v3y;  der(r3z) = v3z;
  m * der(v3x) = F3x;
  m * der(v3y) = F3y;
  m * der(v3z) = F3z - m * g;

  // ===== Inspection Progress =====
  nearTarget1 = sqrt((r1x - marker1x)^2 + (r1y - marker1y)^2 + (r1z - marker1z)^2 + eps) < nearRadius;
  der(inspectTimer) = if (nearTarget1 and handoffState == 1) then 1.0 else 0.0;

  // ===== Handoff State Machine: State 1 -> 2 (Inspection Complete, Send) =====
  when handoffState == 1 and inspectTimer >= inspectTime then
    handoffState = 2;
    commInFlight = true;
    reinit(commTimer, commDelay);
    commBufferX = featureX;
    commBufferY = featureY;
    commBufferZ = featureZ;
    sendTime = time;
  end when;

  // ===== Handoff State Machine: State 2 -> 3 (Receive Delayed Data, Replan) =====
  when commInFlight and commTimer <= 0.0 then
    commInFlight = false;
    recvTime = time;
    dataAge = recvTime - sendTime;
    replanReceived = true;
    p2x_replan = commBufferX;
    p2y_replan = commBufferY;
    p2z_replan = commBufferZ;
    handoffState = 3;
    handoffDone = true;
  end when;

  // ===== Handoff State Machine: State 3 -> 4 (Task Complete) =====
  when handoffState == 3 and
       sqrt((r2x - p2x_replan)^2 + (r2y - p2y_replan)^2 + (r2z - p2z_replan)^2 + eps) < completeRadius and
       sqrt((r3x - marker3x)^2 + (r3y - marker3y)^2 + (r3z - marker3z)^2 + eps) < completeRadius then
    handoffState = 4;
    taskComplete = true;
  end when;

  // ===== Verification Metrics =====
  primaryError = sqrt((r2x - rx2_ref)^2 + (r2y - ry2_ref)^2 + (r2z - rz2_ref)^2 + eps);
  separationMin = min(d12, min(d13, d23));

  maxT1 = max(max(T1_1, T1_2), max(T1_3, T1_4));
  maxT2 = max(max(T2_1, T2_2), max(T2_3, T2_4));
  maxT3 = max(max(T3_1, T3_2), max(T3_3, T3_4));
  peakThrust = max(maxT1, max(maxT2, maxT3));

  // ===== Verification Flags =====
  actuatorOK = peakThrust <= Tmax + eps;
  separationOK = separationMin >= minSeparation;
  dataAgeOK = (not replanReceived) or (dataAge >= 0.0 and dataAge <= maxDataAge);
  handoffOK = handoffDone;
  noCollision = separationMin >= 0.5;
  taskOK = taskComplete;
  trackingOK = (time < 13.0) or (primaryError < trackingThreshold);
  noNaN = (abs(r1x) < 1e30) and (abs(r1y) < 1e30) and (abs(r1z) < 1e30) and
          (abs(r2x) < 1e30) and (abs(r2y) < 1e30) and (abs(r2z) < 1e30) and
          (abs(r3x) < 1e30) and (abs(r3y) < 1e30) and (abs(r3z) < 1e30) and
          (abs(v1x) < 1e30) and (abs(v2x) < 1e30) and (abs(v3x) < 1e30) and
          (abs(F1x) < 1e30) and (abs(F2x) < 1e30) and (abs(F3x) < 1e30) and
          (abs(T1_1) < 1e30) and (abs(T2_1) < 1e30) and (abs(T3_1) < 1e30) and
          (abs(primaryError) < 1e30) and (abs(d12) < 1e30) and
          (abs(commTimer) < 1e30) and (abs(inspectTimer) < 1e30);
  allVerified = actuatorOK and separationOK and dataAgeOK and handoffOK and
                noCollision and taskOK and trackingOK and noNaN;

  annotation(
    experiment(StartTime=0.0, StopTime=20.0, Tolerance=1e-6, Interval=0.002),
    Documentation(info="AirTrioHandoffF: Three 1.8 kg quadrotors (12 rotors total, max 14.6 N/rotor) performing divided inspection with timestamped handoff and replanning.

  Mission: Robot 1 inspects marker 1, discovers feature, sends timestamped result to robot 2. Robot 2 receives delayed data and replans to inspect the discovered feature. Robot 3 independently inspects marker 3.

  Embodiment: Three 1.8 kg quadrotors, each with 4 rotors, IMU, GPS, and peer-relative range sensing.

  Actuation: 12 independent rotor-thrust groups, each bounded by 14.6 N.

  Control: PD position control with task allocation and explicit handoff state machine (inspect -> send -> replan -> done).

  Disturbance: 0.145 s communication delay during middle third (6.67 s to 13.33 s).

  Timing: 500 Hz for 20 s with synchronized state, command, and sensor traces.

  Verification: Actuator bounds, separation bounds, bounded data age, successful handoff, no collision, task completion, primary tracking error < 0.32 m after 13 s, no NaN or infinite values.")
  );
end AirTrioHandoffF;