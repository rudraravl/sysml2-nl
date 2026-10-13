model AirTrioHandoffB
  "Multi-robot inspection: task division, timestamped handoff, and replanning";

  // ===== Physical parameters =====
  parameter Real m = 1.8 "quadrotor mass [kg]";
  parameter Real g = 9.81 "gravitational acceleration [m/s^2]";
  parameter Real fMax = 9.84 "max rotor thrust command [N]";
  parameter Real tauDir = 0.08 "thrust direction lag time constant [s]";

  // ===== Control gains =====
  parameter Real kp = 5.0 "position proportional gain [1/s^2]";
  parameter Real kd = 3.5 "position derivative gain [1/s]";

  // ===== Mission timing =====
  parameter Real tSend = 3.5 "handoff send time [s]";
  parameter Real tMidStart = 10.0/3.0 "middle third start [s]";
  parameter Real tMidEnd = 20.0/3.0 "middle third end [s]";
  parameter Real delayDist = 0.07 "injected communication delay [s]";
  parameter Real delayNominal = 0.001 "nominal communication delay [s]";
  parameter Real handoffDelay = if (tSend >= tMidStart and tSend <= tMidEnd) then delayDist else delayNominal
    "delay applicable at handoff send time [s]";

  // ===== Survey features (inspection waypoints in common world frame) =====
  parameter Real wx1 = 2.0 "survey feature 1 x [m]";
  parameter Real wy1 = 0.0 "survey feature 1 y [m]";
  parameter Real wz1 = 1.5 "survey feature 1 z [m]";
  parameter Real wx2 = 0.0 "survey feature 2 x [m]";
  parameter Real wy2 = 2.0 "survey feature 2 y [m]";
  parameter Real wz2 = 1.5 "survey feature 2 z [m]";
  parameter Real wx3 = -2.0 "survey feature 3 x [m]";
  parameter Real wy3 = 0.0 "survey feature 3 y [m]";
  parameter Real wz3 = 1.5 "survey feature 3 z [m]";
  parameter Real homeX = 0.0 "home base x [m]";
  parameter Real homeY = 0.0 "home base y [m]";
  parameter Real homeZ = 0.0 "home base z [m]";

  // ===== Safety bounds =====
  parameter Real sepMin = 0.3 "minimum separation [m]";
  parameter Real eps = 0.01 "epsilon for norm zero-error branch";
  parameter Real dataAgeBound = 10.0 "max allowed data age [s]";
  parameter Real trackErrBound = 0.48 "max primary tracking error after 6.5 s [m]";
  parameter Real trackErrCompletion = 0.3 "tracking error for task completion [m]";

  // ===== Robot 1 state (primary) =====
  Real x1(start=0.0, fixed=true) "R1 x position [m]";
  Real y1(start=0.0, fixed=true) "R1 y position [m]";
  Real z1(start=0.0, fixed=true) "R1 z position [m]";
  Real vx1(start=0.0, fixed=true) "R1 x velocity [m/s]";
  Real vy1(start=0.0, fixed=true) "R1 y velocity [m/s]";
  Real vz1(start=0.0, fixed=true) "R1 z velocity [m/s]";
  Real nx1(start=0.0, fixed=true) "R1 thrust direction x";
  Real ny1(start=0.0, fixed=true) "R1 thrust direction y";
  Real nz1(start=1.0, fixed=true) "R1 thrust direction z";
  Real Tcmd1 "R1 commanded total thrust [N]";
  Real Tact1 "R1 actual total thrust [N]";
  Real f1r1 "R1 rotor 1 thrust [N]";
  Real f1r2 "R1 rotor 2 thrust [N]";
  Real f1r3 "R1 rotor 3 thrust [N]";
  Real f1r4 "R1 rotor 4 thrust [N]";

  // ===== Robot 2 state =====
  Real x2(start=0.5, fixed=true) "R2 x position [m]";
  Real y2(start=0.0, fixed=true) "R2 y position [m]";
  Real z2(start=0.0, fixed=true) "R2 z position [m]";
  Real vx2(start=0.0, fixed=true) "R2 x velocity [m/s]";
  Real vy2(start=0.0, fixed=true) "R2 y velocity [m/s]";
  Real vz2(start=0.0, fixed=true) "R2 z velocity [m/s]";
  Real nx2(start=0.0, fixed=true) "R2 thrust direction x";
  Real ny2(start=0.0, fixed=true) "R2 thrust direction y";
  Real nz2(start=1.0, fixed=true) "R2 thrust direction z";
  Real Tcmd2 "R2 commanded total thrust [N]";
  Real Tact2 "R2 actual total thrust [N]";
  Real f2r1 "R2 rotor 1 thrust [N]";
  Real f2r2 "R2 rotor 2 thrust [N]";
  Real f2r3 "R2 rotor 3 thrust [N]";
  Real f2r4 "R2 rotor 4 thrust [N]";

  // ===== Robot 3 state =====
  Real x3(start=-0.5, fixed=true) "R3 x position [m]";
  Real y3(start=0.0, fixed=true) "R3 y position [m]";
  Real z3(start=0.0, fixed=true) "R3 z position [m]";
  Real vx3(start=0.0, fixed=true) "R3 x velocity [m/s]";
  Real vy3(start=0.0, fixed=true) "R3 y velocity [m/s]";
  Real vz3(start=0.0, fixed=true) "R3 z velocity [m/s]";
  Real nx3(start=0.0, fixed=true) "R3 thrust direction x";
  Real ny3(start=0.0, fixed=true) "R3 thrust direction y";
  Real nz3(start=1.0, fixed=true) "R3 thrust direction z";
  Real Tcmd3 "R3 commanded total thrust [N]";
  Real Tact3 "R3 actual total thrust [N]";
  Real f3r1 "R3 rotor 1 thrust [N]";
  Real f3r2 "R3 rotor 2 thrust [N]";
  Real f3r3 "R3 rotor 3 thrust [N]";
  Real f3r4 "R3 rotor 4 thrust [N]";

  // ===== Desired positions (task allocation output) =====
  Real x1d "R1 desired x [m]";
  Real y1d "R1 desired y [m]";
  Real z1d "R1 desired z [m]";
  Real x2d "R2 desired x [m]";
  Real y2d "R2 desired y [m]";
  Real z2d "R2 desired z [m]";
  Real x3d "R3 desired x [m]";
  Real y3d "R3 desired y [m]";
  Real z3d "R3 desired z [m]";

  // ===== Communication: send, receive, data age =====
  Boolean sendDone(start=false) "R1 has sent timestamped result";
  Boolean recvDone(start=false) "R2 has received result";
  Real tSendActual(start=0.0) "actual send timestamp [s]";
  Real tRecvActual(start=0.0) "actual receive timestamp [s]";
  Real dataAge(start=0.0) "data age since reception [s]";
  Real commDelay "current communication delay [s]";
  Integer handoffState(start=0) "0=pre-handoff, 1=sent, 2=received/replanned";

  // ===== Local sensors: GPS, IMU, peer-relative range =====
  Real gpsX1 "R1 GPS x [m]";
  Real gpsY1 "R1 GPS y [m]";
  Real gpsZ1 "R1 GPS z [m]";
  Real gpsX2 "R2 GPS x [m]";
  Real gpsY2 "R2 GPS y [m]";
  Real gpsZ2 "R2 GPS z [m]";
  Real gpsX3 "R3 GPS x [m]";
  Real gpsY3 "R3 GPS y [m]";
  Real gpsZ3 "R3 GPS z [m]";
  Real imuAx1 "R1 IMU accel x [m/s^2]";
  Real imuAy1 "R1 IMU accel y [m/s^2]";
  Real imuAz1 "R1 IMU accel z [m/s^2]";
  Real imuAx2 "R2 IMU accel x [m/s^2]";
  Real imuAy2 "R2 IMU accel y [m/s^2]";
  Real imuAz2 "R2 IMU accel z [m/s^2]";
  Real imuAx3 "R3 IMU accel x [m/s^2]";
  Real imuAy3 "R3 IMU accel y [m/s^2]";
  Real imuAz3 "R3 IMU accel z [m/s^2]";
  Real range12 "R1-R2 peer-relative range [m]";
  Real range13 "R1-R3 peer-relative range [m]";
  Real range23 "R2-R3 peer-relative range [m]";

  // ===== Performance metrics and status flags =====
  Real err1 "R1 tracking error [m]";
  Real err2 "R2 tracking error [m]";
  Real err3 "R3 tracking error [m]";
  Real primaryErr "primary (R1) tracking error [m]";
  Real minSep "minimum pairwise separation [m]";
  Boolean collision "collision flag";
  Boolean taskComplete "all inspection tasks complete";
  Boolean dataAgeBounded "data age within bound";
  Boolean handoffSuccess "handoff completed successfully";
  Boolean trackErrOK "primary tracking error satisfies bound after 6.5 s";

  // ===== Intermediate control variables =====
  Real Fx1 "R1 desired force x [N]";
  Real Fy1 "R1 desired force y [N]";
  Real Fz1 "R1 desired force z [N]";
  Real Fmag1 "R1 desired force magnitude [N]";
  Real nxd1 "R1 desired thrust dir x";
  Real nyd1 "R1 desired thrust dir y";
  Real nzd1 "R1 desired thrust dir z";
  Real Fx2 "R2 desired force x [N]";
  Real Fy2 "R2 desired force y [N]";
  Real Fz2 "R2 desired force z [N]";
  Real Fmag2 "R2 desired force magnitude [N]";
  Real nxd2 "R2 desired thrust dir x";
  Real nyd2 "R2 desired thrust dir y";
  Real nzd2 "R2 desired thrust dir z";
  Real Fx3 "R3 desired force x [N]";
  Real Fy3 "R3 desired force y [N]";
  Real Fz3 "R3 desired force z [N]";
  Real Fmag3 "R3 desired force magnitude [N]";
  Real nxd3 "R3 desired thrust dir x";
  Real nyd3 "R3 desired thrust dir y";
  Real nzd3 "R3 desired thrust dir z";

equation
  // ===== Communication delay model =====
  // 0.07 s during middle third [3.33, 6.67] s, small nominal delay otherwise
  commDelay = if (time >= tMidStart and time <= tMidEnd) then delayDist else delayNominal;

  // ===== Handoff state machine =====
  when time >= tSend then
    sendDone = true;
    tSendActual = time;
    handoffState = 1;
  elsewhen time >= tSend + handoffDelay then
    recvDone = true;
    tRecvActual = time;
    handoffState = 2;
  end when;

  // Data age since reception
  dataAge = if recvDone then (time - tRecvActual) else 0.0;

  // ===== Task allocation with explicit handoff =====
  // R1 inspects feature 1, then returns home after handoff complete
  // R2 inspects feature 2, then takes over feature 1 after receiving R1 result
  // R3 inspects feature 3 throughout
  if handoffState < 2 then
    x1d = wx1; y1d = wy1; z1d = wz1;
  else
    x1d = homeX; y1d = homeY; z1d = homeZ;
  end if;

  if not recvDone then
    x2d = wx2; y2d = wy2; z2d = wz2;
  else
    x2d = wx1; y2d = wy1; z2d = wz1;
  end if;

  x3d = wx3; y3d = wy3; z3d = wz3;

  // ===== Robot 1 dynamics =====
  der(x1) = vx1;
  der(y1) = vy1;
  der(z1) = vz1;
  der(vx1) = (Tact1 / m) * nx1;
  der(vy1) = (Tact1 / m) * ny1;
  der(vz1) = (Tact1 / m) * nz1 - g;

  // Robot 1 PD controller with gravity compensation
  Fx1 = m * (kp * (x1d - x1) - kd * vx1);
  Fy1 = m * (kp * (y1d - y1) - kd * vy1);
  Fz1 = m * (kp * (z1d - z1) - kd * vz1) + m * g;
  Fmag1 = sqrt(Fx1*Fx1 + Fy1*Fy1 + Fz1*Fz1 + eps);
  Tcmd1 = Fmag1;
  nxd1 = Fx1 / Fmag1;
  nyd1 = Fy1 / Fmag1;
  nzd1 = Fz1 / Fmag1;
  der(nx1) = (nxd1 - nx1) / tauDir;
  der(ny1) = (nyd1 - ny1) / tauDir;
  der(nz1) = (nzd1 - nz1) / tauDir;

  // Robot 1 rotor thrust allocation (4 independent groups, clamped)
  f1r1 = max(0.0, min(fMax, Tcmd1 / 4.0));
  f1r2 = max(0.0, min(fMax, Tcmd1 / 4.0));
  f1r3 = max(0.0, min(fMax, Tcmd1 / 4.0));
  f1r4 = max(0.0, min(fMax, Tcmd1 / 4.0));
  Tact1 = f1r1 + f1r2 + f1r3 + f1r4;

  // ===== Robot 2 dynamics =====
  der(x2) = vx2;
  der(y2) = vy2;
  der(z2) = vz2;
  der(vx2) = (Tact2 / m) * nx2;
  der(vy2) = (Tact2 / m) * ny2;
  der(vz2) = (Tact2 / m) * nz2 - g;

  // Robot 2 PD controller with gravity compensation
  Fx2 = m * (kp * (x2d - x2) - kd * vx2);
  Fy2 = m * (kp * (y2d - y2) - kd * vy2);
  Fz2 = m * (kp * (z2d - z2) - kd * vz2) + m * g;
  Fmag2 = sqrt(Fx2*Fx2 + Fy2*Fy2 + Fz2*Fz2 + eps);
  Tcmd2 = Fmag2;
  nxd2 = Fx2 / Fmag2;
  nyd2 = Fy2 / Fmag2;
  nzd2 = Fz2 / Fmag2;
  der(nx2) = (nxd2 - nx2) / tauDir;
  der(ny2) = (nyd2 - ny2) / tauDir;
  der(nz2) = (nzd2 - nz2) / tauDir;

  // Robot 2 rotor thrust allocation
  f2r1 = max(0.0, min(fMax, Tcmd2 / 4.0));
  f2r2 = max(0.0, min(fMax, Tcmd2 / 4.0));
  f2r3 = max(0.0, min(fMax, Tcmd2 / 4.0));
  f2r4 = max(0.0, min(fMax, Tcmd2 / 4.0));
  Tact2 = f2r1 + f2r2 + f2r3 + f2r4;

  // ===== Robot 3 dynamics =====
  der(x3) = vx3;
  der(y3) = vy3;
  der(z3) = vz3;
  der(vx3) = (Tact3 / m) * nx3;
  der(vy3) = (Tact3 / m) * ny3;
  der(vz3) = (Tact3 / m) * nz3 - g;

  // Robot 3 PD controller with gravity compensation
  Fx3 = m * (kp * (x3d - x3) - kd * vx3);
  Fy3 = m * (kp * (y3d - y3) - kd * vy3);
  Fz3 = m * (kp * (z3d - z3) - kd * vz3) + m * g;
  Fmag3 = sqrt(Fx3*Fx3 + Fy3*Fy3 + Fz3*Fz3 + eps);
  Tcmd3 = Fmag3;
  nxd3 = Fx3 / Fmag3;
  nyd3 = Fy3 / Fmag3;
  nzd3 = Fz3 / Fmag3;
  der(nx3) = (nxd3 - nx3) / tauDir;
  der(ny3) = (nyd3 - ny3) / tauDir;
  der(nz3) = (nzd3 - nz3) / tauDir;

  // Robot 3 rotor thrust allocation
  f3r1 = max(0.0, min(fMax, Tcmd3 / 4.0));
  f3r2 = max(0.0, min(fMax, Tcmd3 / 4.0));
  f3r3 = max(0.0, min(fMax, Tcmd3 / 4.0));
  f3r4 = max(0.0, min(fMax, Tcmd3 / 4.0));
  Tact3 = f3r1 + f3r2 + f3r3 + f3r4;

  // ===== Local sensors =====
  // GPS positions in common world frame
  gpsX1 = x1; gpsY1 = y1; gpsZ1 = z1;
  gpsX2 = x2; gpsY2 = y2; gpsZ2 = z2;
  gpsX3 = x3; gpsY3 = y3; gpsZ3 = z3;

  // IMU accelerations (specific force including gravity reaction)
  imuAx1 = (Tact1 / m) * nx1;
  imuAy1 = (Tact1 / m) * ny1;
  imuAz1 = (Tact1 / m) * nz1 - g;
  imuAx2 = (Tact2 / m) * nx2;
  imuAy2 = (Tact2 / m) * ny2;
  imuAz2 = (Tact2 / m) * nz2 - g;
  imuAx3 = (Tact3 / m) * nx3;
  imuAy3 = (Tact3 / m) * ny3;
  imuAz3 = (Tact3 / m) * nz3 - g;

  // Peer-relative range sensing
  range12 = sqrt((x1 - x2)*(x1 - x2) + (y1 - y2)*(y1 - y2) + (z1 - z2)*(z1 - z2) + eps);
  range13 = sqrt((x1 - x3)*(x1 - x3) + (y1 - y3)*(y1 - y3) + (z1 - z3)*(z1 - z3) + eps);
  range23 = sqrt((x2 - x3)*(x2 - x3) + (y2 - y3)*(y2 - y3) + (z2 - z3)*(z2 - z3) + eps);

  // ===== Tracking errors =====
  err1 = sqrt((x1 - x1d)*(x1 - x1d) + (y1 - y1d)*(y1 - y1d) + (z1 - z1d)*(z1 - z1d) + eps);
  err2 = sqrt((x2 - x2d)*(x2 - x2d) + (y2 - y2d)*(y2 - y2d) + (z2 - z2d)*(z2 - z2d) + eps);
  err3 = sqrt((x3 - x3d)*(x3 - x3d) + (y3 - y3d)*(y3 - y3d) + (z3 - z3d)*(z3 - z3d) + eps);
  primaryErr = err1;

  // ===== Separation and collision =====
  minSep = min(range12, min(range13, range23));
  collision = minSep < sepMin;

  // ===== Mission status =====
  handoffSuccess = recvDone and (handoffState == 2);
  dataAgeBounded = dataAge <= dataAgeBound;
  taskComplete = handoffSuccess and (err1 < trackErrCompletion) and (err2 < trackErrCompletion) and (err3 < trackErrCompletion);
  trackErrOK = (time < 6.5) or (primaryErr < trackErrBound);

  annotation(
    experiment(StartTime=0, StopTime=10.0, Tolerance=1e-6, Interval=0.01),
    Documentation(info="Three 1.8 kg quadrotors inspect survey features in a common world frame. R1 inspects feature 1, R2 feature 2, R3 feature 3. At t=3.5 s R1 sends a timestamped result to R2 (0.07 s delay, injected during middle third). R2 receives, replans, and takes over feature 1 while R1 returns home. 12 independent rotor-thrust groups (4 per robot), max 9.84 N/rotor. Local GPS, IMU, and peer-relative range sensors. 100 Hz, 10 s.")
  );
end AirTrioHandoffB;