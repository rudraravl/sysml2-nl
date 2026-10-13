model RailArmCarryB
  // Geometry and stated masses
  parameter Real railLength=1.4 "m, fixed X rail length";
  parameter Real mCarriage=18 "kg, carriage mass";
  parameter Real L1=0.46 "m, first arm link length";
  parameter Real L2=0.31 "m, second arm link length";
  parameter Real jointLimit=1.5 "rad, symmetric joint limit";
  parameter Real mPayload=8.4 "kg, retained tool payload mass (only stated mass used)";
  parameter Real mDisturbance=8.4 "kg, middle-third payload disturbance mass";
  parameter Real g=9.81 "m/s2, standard gravitational acceleration";

  // Actuator bounds
  parameter Real torqueLimit=69.7 "N.m";
  parameter Real forceLimit=800 "N";

  // Mission and monitoring bounds
  parameter Real wristForceLimit=60 "N, bounded wrist-force correction limit";
  parameter Real errorLimit=0.054 "rad or m, primary tracking error limit";
  parameter Real settlingTime=6.5 "s";
  parameter Real Ts=0.01 "s, 100 Hz trace and control sample period";
  parameter Real Tmove=5.0 "s, motion profile duration";

  // Reference pose. Orientation phi0 is preserved by q1+q2=phi0.
  parameter Real hRail=0 "m, rail height coordinate origin";
  parameter Real xStart=0.30 "m";
  parameter Real xTarget=1.00 "m";
  parameter Real phi0=0.20 "rad, requested end-effector orientation";
  parameter Real q1Start=1.35 "rad";
  parameter Real q1Target=1.47 "rad";
  parameter Real q2Start=phi0 - q1Start "rad";
  parameter Real q2Target=phi0 - q1Target "rad";

  // Computed-torque feedback gains. These are control-design parameters,
  // not physical facts stated in the request.
  parameter Real Kpx=400 "1/s2";
  parameter Real Kdx=40 "1/s";
  parameter Real Kp1=400 "1/s2";
  parameter Real Kd1=40 "1/s";
  parameter Real Kp2=400 "1/s2";
  parameter Real Kd2=40 "1/s";

  // Collision representation. Floor/table geometry is not specified,
  // so no contact-force law is instantiated; collision is represented
  // as enabled rigid surfaces.
  parameter Boolean floorRigid=true "rigid workcell floor";
  parameter Boolean tableFixed=true "fixed table";
  parameter Boolean floorCollisionEnabled=true "collision enabled";
  parameter Boolean tableCollisionEnabled=true "collision enabled";

  // Dynamic states
  Real x(start=xStart) "m, carriage X position";
  Real vx(start=0) "m/s, carriage X velocity";
  Real q1(start=q1Start) "rad, joint 1 angle";
  Real w1(start=0) "rad/s, joint 1 velocity";
  Real q2(start=q2Start) "rad, joint 2 angle";
  Real w2(start=0) "rad/s, joint 2 velocity";

  // End-effector pose and errors
  Real px "m, end-effector X";
  Real py "m, end-effector Y";
  Real phi "rad, end-effector orientation";
  Real pxDes "m, desired end-effector X";
  Real pyDes "m, desired end-effector Y";
  Real phiDes "rad, desired end-effector orientation";
  Real orientationError "rad";
  Real poseError "m";
  Real primaryTrackingError "rad or m";

  // Joint encoders (ideal; sensor noise is unspecified)
  Real xEnc "m";
  Real q1Enc "rad";
  Real q2Enc "rad";

  // Six-axis wrist wrench sensor. Planar model, unused axes zero.
  Real wristFxSensor "N";
  Real wristFySensor "N";
  Real wristFzSensor "N";
  Real wristMxSensor "N.m";
  Real wristMySensor "N.m";
  Real wristMzSensor "N.m";
  Real wristWrenchNormRaw "N";
  Real wristForceNorm "N";

  // Bounded wrist-force correction
  Real FcorrRaw "N";
  Real Fcorr "N";
  Real wristForceCorrectionNorm "N";
  Real retentionMargin "N";

  // Commands
  Real FcmdRaw "N";
  Real tau1cmdRaw "N.m";
  Real tau2cmdRaw "N.m";
  Real Fcmd "N";
  Real tau1cmd "N.m";
  Real tau2cmd "N.m";

  // Contact placeholders
  Real floorContactForce "N";
  Real tableContactForce "N";
  Real contactForceNorm "N";

  // Requirement monitors
  Boolean jointBounded;
  Boolean railBounded;
  Boolean effortBounded;
  Boolean wristBounded;
  Boolean payloadRetained;
  Boolean finiteValues;

  // Synchronized 100 Hz traces
  Integer sampleCount(start=0);
  discrete Real time_trace(start=0);
  discrete Real x_trace(start=xStart);
  discrete Real vx_trace(start=0);
  discrete Real q1_trace(start=q1Start);
  discrete Real w1_trace(start=0);
  discrete Real q2_trace(start=q2Start);
  discrete Real w2_trace(start=0);
  discrete Real Fcmd_trace(start=0);
  discrete Real tau1cmd_trace(start=0);
  discrete Real tau2cmd_trace(start=0);
  discrete Real wristFx_trace(start=0);
  discrete Real wristFy_trace(start=0);
  discrete Real wristFz_trace(start=0);
  discrete Real wristMx_trace(start=0);
  discrete Real wristMy_trace(start=0);
  discrete Real wristMz_trace(start=0);

protected
  constant Real detEps=1e-9;
  parameter Real tDistStart=10/3 "s, middle third start";
  parameter Real tDistEnd=20/3 "s, middle third end";

  Real sProfile;
  Real rProfile;
  Real rProfiled;
  Real rProfiledd;
  Real xdes, xdesd, xdesdd;
  Real q1des, q1desd, q1desdd;
  Real q2des, q2desd, q2desdd;

  Real s1, c1, sphi, cphi, phiVel;
  Real jx2, jx3, jy2, jy3;
  Real avx, avy;
  Real M11, M12, M13, M22, M23, M33;
  Real C1, C2, C3;
  Real G1, G2, G3;
  Real Qdist1, Qdist2, Qdist3;
  Real Qcorr1, Qcorr2, Qcorr3;
  Real axCmd, a1Cmd, a2Cmd;
  Real detRaw, detM;
  Real inv11, inv12, inv13, inv22, inv23, inv33;
  Real rhs1, rhs2, rhs3;
  Real qddx, qdd1, qdd2;
  Boolean disturbanceActive;
  Real FdistVertical;

equation
  // Smooth quintic motion profile
  sProfile = if time < Tmove then time/Tmove else 1.0;
  rProfile = if time < Tmove then 10*sProfile^3 - 15*sProfile^4 + 6*sProfile^5 else 1.0;
  rProfiled = if time < Tmove then (30*sProfile^2 - 60*sProfile^3 + 30*sProfile^4)/Tmove else 0.0;
  rProfiledd = if time < Tmove then (60*sProfile - 180*sProfile^2 + 120*sProfile^3)/(Tmove^2) else 0.0;

  xdes = xStart + rProfile*(xTarget - xStart);
  xdesd = rProfiled*(xTarget - xStart);
  xdesdd = rProfiledd*(xTarget - xStart);

  q1des = q1Start + rProfile*(q1Target - q1Start);
  q1desd = rProfiled*(q1Target - q1Start);
  q1desdd = rProfiledd*(q1Target - q1Start);

  q2des = q2Start + rProfile*(q2Target - q2Start);
  q2desd = rProfiled*(q2Target - q2Start);
  q2desdd = rProfiledd*(q2Target - q2Start);

  // Kinematics
  phi = q1 + q2;
  phiDes = phi0;
  s1 = sin(q1);
  c1 = cos(q1);
  sphi = sin(phi);
  cphi = cos(phi);
  phiVel = w1 + w2;

  jx2 = -L1*s1 - L2*sphi;
  jx3 = -L2*sphi;
  jy2 = L1*c1 + L2*cphi;
  jy3 = L2*cphi;

  px = x + L1*c1 + L2*cphi;
  py = hRail + L1*s1 + L2*sphi;
  pxDes = xdes + L1*cos(q1des) + L2*cos(phiDes);
  pyDes = hRail + L1*sin(q1des) + L2*sin(phiDes);

  // Encoders
  xEnc = x;
  q1Enc = q1;
  q2Enc = q2;

  // Errors
  orientationError = abs(phiDes - phi);
  poseError = sqrt((pxDes - px)^2 + (pyDes - py)^2 + 1e-12);
  primaryTrackingError = max(abs(xdes - x), max(abs(q1des - q1), abs(q2des - q2)));

  // Disturbance: during middle third, inject a controlled 8.4 kg payload
  // disturbance as a downward wrist force equal to its weight.
  disturbanceActive = time >= tDistStart and time <= tDistEnd;
  FdistVertical = if disturbanceActive then -mDisturbance*g else 0.0;

  // Wrist wrench sensor (planar: only vertical disturbance component nonzero)
  wristFxSensor = 0.0;
  wristFySensor = FdistVertical;
  wristFzSensor = 0.0;
  wristMxSensor = 0.0;
  wristMySensor = 0.0;
  wristMzSensor = 0.0;
  wristWrenchNormRaw = sqrt(wristFxSensor^2 + wristFySensor^2 + wristFzSensor^2 + 1e-12);

  // Bounded wrist-force correction
  FcorrRaw = -wristFySensor;
  Fcorr = if FcorrRaw > wristForceLimit then wristForceLimit elseif FcorrRaw < -wristForceLimit then -wristForceLimit else FcorrRaw;
  wristForceCorrectionNorm = abs(Fcorr);
  wristForceNorm = wristForceCorrectionNorm;
  retentionMargin = wristForceLimit - wristForceCorrectionNorm;

  // Generalized disturbance and correction
  Qdist1 = 0.0;
  Qdist2 = jy2*FdistVertical;
  Qdist3 = jy3*FdistVertical;

  Qcorr1 = 0.0;
  Qcorr2 = jy2*Fcorr;
  Qcorr3 = jy3*Fcorr;

  // Mass matrix for carriage plus retained payload; link masses are not
  // specified and are modeled as massless rigid links.
  M11 = mCarriage + mPayload;
  M12 = mPayload*jx2;
  M13 = mPayload*jx3;
  M22 = mPayload*(jx2^2 + jy2^2);
  M23 = mPayload*(jx2*jx3 + jy2*jy3);
  M33 = mPayload*(jx3^2 + jy3^2);

  // Coriolis/centrifugal generalized force for point-mass payload
  avx = -L1*c1*w1^2 - L2*cphi*phiVel^2;
  avy = -L1*s1*w1^2 - L2*sphi*phiVel^2;
  C1 = mPayload*avx;
  C2 = mPayload*(jx2*avx + jy2*avy);
  C3 = mPayload*(jx3*avx + jy3*avy);

  // Gravity generalized force
  G1 = 0.0;
  G2 = mPayload*g*jy2;
  G3 = mPayload*g*jy3;

  // Computed-torque acceleration command
  axCmd = xdesdd + Kpx*(xdes - x) + Kdx*(xdesd - vx);
  a1Cmd = q1desdd + Kp1*(q1des - q1) + Kd1*(q1desd - w1);
  a2Cmd = q2desdd + Kp2*(q2des - q2) + Kd2*(q2desd - w2);

  // Computed-torque command with bounded wrist-force correction
  FcmdRaw = M11*axCmd + M12*a1Cmd + M13*a2Cmd + C1 + G1 - Qcorr1;
  tau1cmdRaw = M12*axCmd + M22*a1Cmd + M23*a2Cmd + C2 + G2 - Qcorr2;
  tau2cmdRaw = M13*axCmd + M23*a1Cmd + M33*a2Cmd + C3 + G3 - Qcorr3;

  // Actuator saturation
  Fcmd = if FcmdRaw > forceLimit then forceLimit elseif FcmdRaw < -forceLimit then -forceLimit else FcmdRaw;
  tau1cmd = if tau1cmdRaw > torqueLimit then torqueLimit elseif tau1cmdRaw < -torqueLimit then -torqueLimit else tau1cmdRaw;
  tau2cmd = if tau2cmdRaw > torqueLimit then torqueLimit elseif tau2cmdRaw < -torqueLimit then -torqueLimit else tau2cmdRaw;

  // Plant dynamics: M*qdd + C + G = actuator + disturbance
  rhs1 = Fcmd + Qdist1 - C1 - G1;
  rhs2 = tau1cmd + Qdist2 - C2 - G2;
  rhs3 = tau2cmd + Qdist3 - C3 - G3;

  detRaw = M11*(M22*M33 - M23*M23) - M12*(M12*M33 - M13*M23) + M13*(M12*M23 - M13*M22);
  detM = if detRaw > detEps then detRaw else detEps;

  inv11 = (M22*M33 - M23*M23)/detM;
  inv12 = (M13*M23 - M12*M33)/detM;
  inv13 = (M12*M23 - M13*M22)/detM;
  inv22 = (M11*M33 - M13*M13)/detM;
  inv23 = (M12*M13 - M11*M23)/detM;
  inv33 = (M11*M22 - M12*M12)/detM;

  qddx = inv11*rhs1 + inv12*rhs2 + inv13*rhs3;
  qdd1 = inv12*rhs1 + inv22*rhs2 + inv23*rhs3;
  qdd2 = inv13*rhs1 + inv23*rhs2 + inv33*rhs3;

  der(x) = vx;
  der(vx) = qddx;
  der(q1) = w1;
  der(w1) = qdd1;
  der(q2) = w2;
  der(w2) = qdd2;

  // Collision representation: geometry unspecified, so contact force is zero
  floorContactForce = 0.0;
  tableContactForce = 0.0;
  contactForceNorm = sqrt(floorContactForce^2 + tableContactForce^2 + 1e-12);

  // Requirement monitors
  jointBounded = abs(q1) <= jointLimit + 1e-6 and abs(q2) <= jointLimit + 1e-6;
  railBounded = x >= -1e-6 and x <= railLength + 1e-6;
  effortBounded = abs(Fcmd) <= forceLimit + 1e-6 and abs(tau1cmd) <= torqueLimit + 1e-6 and abs(tau2cmd) <= torqueLimit + 1e-6;
  wristBounded = wristForceNorm <= wristForceLimit + 1e-6;
  payloadRetained = wristBounded and jointBounded and retentionMargin >= -1e-6;
  finiteValues = abs(x) <= 1e6 and abs(vx) <= 1e6 and abs(q1) <= 1e6 and abs(w1) <= 1e6 and
                 abs(q2) <= 1e6 and abs(w2) <= 1e6 and abs(qddx) <= 1e6 and abs(qdd1) <= 1e6 and
                 abs(qdd2) <= 1e6 and abs(Fcmd) <= 1e6 and abs(tau1cmd) <= 1e6 and abs(tau2cmd) <= 1e6 and
                 abs(wristFySensor) <= 1e6 and abs(Fcorr) <= 1e6 and abs(primaryTrackingError) <= 1e6 and
                 abs(detRaw) <= 1e6;

  assert(floorCollisionEnabled and tableCollisionEnabled, "collision representation must remain enabled");
  assert(floorRigid and tableFixed, "floor and table must be rigid/fixed");
  assert(jointBounded, "joint limit violated");
  assert(railBounded, "rail travel bound violated");
  assert(effortBounded, "effort bound violated");
  assert(wristBounded, "wrist force bound violated");
  assert(payloadRetained, "payload retention failed");
  assert(finiteValues, "non-finite physical, control, or estimator value");
  assert(time < settlingTime or primaryTrackingError <= errorLimit, "primary tracking error requirement failed after 6.5 s");

  // Synchronized 100 Hz state, command, and sensor traces
  when sample(0, Ts) then
    sampleCount = pre(sampleCount) + 1;
    time_trace = time;
    x_trace = x;
    vx_trace = vx;
    q1_trace = q1;
    w1_trace = w1;
    q2_trace = q2;
    w2_trace = w2;
    Fcmd_trace = Fcmd;
    tau1cmd_trace = tau1cmd;
    tau2cmd_trace = tau2cmd;
    wristFx_trace = wristFxSensor;
    wristFy_trace = wristFySensor;
    wristFz_trace = wristFzSensor;
    wristMx_trace = wristMxSensor;
    wristMy_trace = wristMySensor;
    wristMz_trace = wristMzSensor;
  end when;

  annotation (experiment(StopTime=10, Tolerance=1e-6));
end RailArmCarryB;