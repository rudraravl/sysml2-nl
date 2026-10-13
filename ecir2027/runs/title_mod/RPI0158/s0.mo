model SCARACarryB
  // Geometry and masses
  parameter Real l1=0.48 "link 1 length, m";
  parameter Real l2=0.34 "link 2 length, m";
  parameter Real zTravel=0.30 "prismatic carriage travel, m";
  parameter Real mBase=28.0 "fixed cylindrical base mass, kg";
  parameter Real m1=6.0 "link 1 moving mass, kg";
  parameter Real m2=4.0 "link 2 moving mass, kg";
  parameter Real m3=2.0 "carriage/tool moving mass, kg";
  parameter Real mp=8.4 "injected payload disturbance mass, kg";

  // Actuator bounds
  parameter Real tauMax=77.9 "revolute torque magnitude limit, N.m";
  parameter Real fMax=900.0 "prismatic force magnitude limit, N";
  parameter Real fWristLimit=60.0 "wrist force limit, N";
  parameter Real trackLimit=0.054 "primary tracking error limit after 6.5 s, rad or m";

  // Mission timing
  parameter Real dt=0.01 "control and logging period, s";
  parameter Real Tfinal=10.0 "mission duration, s";
  parameter Real Tmove=3.0 "reference motion duration, s";
  parameter Real T0=10.0/3.0 "middle-third payload start, s";
  parameter Real T1=20.0/3.0 "middle-third payload end, s";
  parameter Real tr=0.05 "payload injection transition time, s";

  // Initial and final pose; not specified in request, selected finite values
  parameter Real q1Start=0.20 "initial joint 1 angle, rad";
  parameter Real q1Final=0.60 "final joint 1 angle, rad";
  parameter Real q2Start=-q1Start "initial joint 2 angle, rad";
  parameter Real q2Final=-q1Final "final joint 2 angle, rad";
  parameter Real zStart=0.05 "initial carriage height, m";
  parameter Real zFinal=0.20 "final carriage height, m";
  parameter Real phiDes=0.0 "requested end-effector Z orientation, rad";

  // Control gains
  parameter Real Kp1=100.0 "joint 1 computed-torque proportional gain, 1/s^2";
  parameter Real Kd1=20.0 "joint 1 computed-torque derivative gain, 1/s";
  parameter Real Kp2=100.0 "joint 2 computed-torque proportional gain, 1/s^2";
  parameter Real Kd2=20.0 "joint 2 computed-torque derivative gain, 1/s";
  parameter Real Kpz=300.0 "prismatic computed-torque proportional gain, 1/s^2";
  parameter Real Kdz=30.0 "prismatic computed-torque derivative gain, 1/s";
  parameter Real Kw=0.5 "wrist-force correction gain";
  parameter Real fCorrMax=20.0 "bounded wrist-force correction magnitude, N";

  // Physical constants
  parameter Real g=9.81 "gravity acceleration, m/s^2";
  parameter Real pi=3.141592653589793;

  // Collision geometry: table dimensions are not specified; placeholder values keep collision enabled
  parameter Boolean collisionEnabled=true "collision model enabled";
  parameter Real zFloor=0.0 "rigid floor plane height, m";
  parameter Real rTip=0.02 "tool tip radius, m";
  parameter Real zTable=0.12 "table top height, m";
  parameter Real xTable=0.40 "table center x, m";
  parameter Real yTable=-0.40 "table center y, m";
  parameter Real rTable=0.05 "table radius, m";
  parameter Real kContact=1.0e5 "contact stiffness, N/m";
  parameter Real dContact=1.0e3 "contact damping, N.s/m";

  // Revolute joint travel limits are not specified; broad placeholder bounds
  parameter Real q1Limit=pi/2.0 "joint 1 travel bound, rad";
  parameter Real q2Limit=pi/2.0 "joint 2 travel bound, rad";
  parameter Real retentionMargin=5.0 "ideal payload retention normal-force margin, N";

  // Physical states
  Real q1(start=q1Start, fixed=true) "joint 1 angle, rad";
  Real qd1(start=0.0, fixed=true) "joint 1 velocity, rad/s";
  Real q2(start=q2Start, fixed=true) "joint 2 angle, rad";
  Real qd2(start=0.0, fixed=true) "joint 2 velocity, rad/s";
  Real z(start=zStart, fixed=true) "prismatic carriage height, m";
  Real zd(start=0.0, fixed=true) "prismatic carriage velocity, m/s";

  // Derived physical quantities
  Real ddq1 "joint 1 acceleration, rad/s^2";
  Real ddq2 "joint 2 acceleration, rad/s^2";
  Real ddz "prismatic acceleration, m/s^2";
  Real mpActive "active payload disturbance mass, kg";
  Real mt "total wrist mass including active payload, kg";
  Real phi "end-effector Z orientation, rad";
  Real xw "end-effector x, m";
  Real yw "end-effector y, m";
  Real zTip "tool tip z, m";
  Real FcontactZ "vertical contact force, N";
  Real baseReactionForce "floor reaction supporting fixed base, N";
  Real payloadRetentionForce "ideal payload retention normal force, N";
  Boolean payloadRetained "payload retention flag";

  // Wrist wrench sensor: tared for scheduled payload gravity, reports residual inertial/contact wrench
  Real wrenchFx "wrist force x, N";
  Real wrenchFy "wrist force y, N";
  Real wrenchFz "wrist force z, N";
  Real wrenchTx "wrist torque x, N.m";
  Real wrenchTy "wrist torque y, N.m";
  Real wrenchTz "wrist torque z, N.m";
  Real wristForceNorm "wrist force magnitude, N";

  // Joint encoders
  Real qEnc1 "encoder joint 1, rad";
  Real qEnc2 "encoder joint 2, rad";
  Real zEnc "encoder prismatic position, m";

  // Reference trajectory
  Real u "normalized motion time";
  Real s "motion profile position";
  Real sd "motion profile velocity, 1/s";
  Real sdd "motion profile acceleration, 1/s^2";
  Real q1Des "desired joint 1, rad";
  Real qd1Des "desired joint 1 velocity, rad/s";
  Real qdd1Des "desired joint 1 acceleration, rad/s^2";
  Real q2Des "desired joint 2, rad";
  Real qd2Des "desired joint 2 velocity, rad/s";
  Real qdd2Des "desired joint 2 acceleration, rad/s^2";
  Real zDes "desired carriage height, m";
  Real qdzDes "desired carriage velocity, m/s";
  Real zddDes "desired carriage acceleration, m/s^2";
  Real phiDesTraj "desired end-effector orientation, rad";
  Real xwDes "desired end-effector x, m";
  Real ywDes "desired end-effector y, m";

  // Tracking and constraint monitors
  Real primaryError "primary tracking error, rad or m";
  Real poseErrorPos "end-effector position error, m";
  Real orientationError "end-effector orientation error, rad";
  Boolean joint1OK;
  Boolean joint2OK;
  Boolean jointZOK;
  Boolean effort1OK;
  Boolean effort2OK;
  Boolean effortFOK;
  Boolean wristForceOK;
  Boolean trackingOK;
  Boolean orientationOK;
  Boolean finiteValuesOK;
  Boolean missionOK;

  // Discrete control commands
  discrete Real tau1Raw(start=0.0) "raw joint 1 torque, N.m";
  discrete Real tau2Raw(start=0.0) "raw joint 2 torque, N.m";
  discrete Real tauFRaw(start=m3*g) "raw prismatic force, N";
  discrete Real tau1Sat(start=0.0) "saturated joint 1 torque, N.m";
  discrete Real tau2Sat(start=0.0) "saturated joint 2 torque, N.m";
  discrete Real tauFSat(start=m3*g) "saturated prismatic force, N";

  // Discrete controller internals
  discrete Real e1c(start=0.0);
  discrete Real e2c(start=0.0);
  discrete Real ezc(start=0.0);
  discrete Real ed1c(start=0.0);
  discrete Real ed2c(start=0.0);
  discrete Real edzc(start=0.0);
  discrete Real ddq1c(start=0.0);
  discrete Real ddq2c(start=0.0);
  discrete Real ddzc(start=0.0);
  discrete Real mtc(start=m3);
  discrete Real cos2c(start=1.0);
  discrete Real sin2c(start=0.0);
  discrete Real M11c(start=1.0);
  discrete Real M12c(start=0.0);
  discrete Real M22c(start=1.0);
  discrete Real bc(start=1.0);
  discrete Real dcc(start=0.0);
  discrete Real C1c(start=0.0);
  discrete Real C2c(start=0.0);
  discrete Real Jx1c(start=0.0);
  discrete Real Jy1c(start=0.0);
  discrete Real Jx2c(start=0.0);
  discrete Real Jy2c(start=0.0);
  discrete Real fXraw(start=0.0);
  discrete Real fYraw(start=0.0);
  discrete Real fZraw(start=0.0);
  discrete Real fCorrX(start=0.0);
  discrete Real fCorrY(start=0.0);
  discrete Real fCorrZ(start=0.0);
  discrete Real fCorr1(start=0.0);
  discrete Real fCorr2(start=0.0);
  discrete Real fCorrF(start=0.0);

  // Sampled sensor memory for one-step-delayed force correction
  discrete Real sensFx(start=0.0);
  discrete Real sensFy(start=0.0);
  discrete Real sensFz(start=0.0);

  // Synchronized 100 Hz traces
  discrete Real logTime(start=0.0);
  discrete Real logQ1(start=q1Start);
  discrete Real logQ2(start=q2Start);
  discrete Real logZ(start=zStart);
  discrete Real logQd1(start=0.0);
  discrete Real logQd2(start=0.0);
  discrete Real logZd(start=0.0);
  discrete Real logTau1(start=0.0);
  discrete Real logTau2(start=0.0);
  discrete Real logTauF(start=m3*g);
  discrete Real logWfx(start=0.0);
  discrete Real logWfy(start=0.0);
  discrete Real logWfz(start=0.0);
  discrete Real logPrimaryError(start=0.0);

equation
  // Payload disturbance schedule
  mpActive = mp*smoothPulse(time, T0, T1, tr);
  mt = m3 + mpActive;

  // Reference motion profile
  u = if time <= Tmove then time/Tmove else 1.0;
  s = if u <= 0.0 then 0.0 elseif u >= 1.0 then 1.0 else 10.0*u^3 - 15.0*u^4 + 6.0*u^5;
  sd = if u <= 0.0 or u >= 1.0 then 0.0 else (30.0*u^2 - 60.0*u^3 + 30.0*u^4)/Tmove;
  sdd = if u <= 0.0 or u >= 1.0 then 0.0 else (60.0*u - 180.0*u^2 + 120.0*u^3)/(Tmove*Tmove);

  q1Des = q1Start + (q1Final - q1Start)*s;
  qd1Des = (q1Final - q1Start)*sd;
  qdd1Des = (q1Final - q1Start)*sdd;
  q2Des = q2Start + (q2Final - q2Start)*s;
  qd2Des = (q2Final - q2Start)*sd;
  qdd2Des = (q2Final - q2Start)*sdd;
  zDes = zStart + (zFinal - zStart)*s;
  qdzDes = (zFinal - zStart)*sd;
  zddDes = (zFinal - zStart)*sdd;
  phiDesTraj = q1Des + q2Des;
  xwDes = l1*cos(q1Des) + l2*cos(phiDesTraj);
  ywDes = l1*sin(q1Des) + l2*sin(phiDesTraj);

  // Kinematics
  phi = q1 + q2;
  xw = l1*cos(q1) + l2*cos(phi);
  yw = l1*sin(q1) + l2*sin(phi);
  zTip = z - rTip;

  // Dynamics mass matrix and Coriolis terms
  M11 = m1*l1^2/3.0 + m2*(l1^2 + l2^2/3.0 + l1*l2*cos(q2)) + mt*(l1^2 + l2^2 + 2.0*l1*l2*cos(q2));
  M12 = m2*(l2^2/3.0 + 0.5*l1*l2*cos(q2)) + mt*(l2^2 + l1*l2*cos(q2));
  M22 = (m2/3.0 + mt)*l2^2;
  b = m2*l1*l2 + 2.0*mt*l1*l2;
  dC = 0.5*m2*l1*l2 + mt*l1*l2;
  C1 = -b*sin(q2)*qd1*qd2 - dC*sin(q2)*qd2^2;
  C2 = dC*sin(q2)*qd1^2;
  Dsafe = if M11*M22 - M12*M12 > 1.0e-9 then M11*M22 - M12*M12 else 1.0e-9;

  // Explicit state derivatives
  der(q1) = qd1;
  der(qd1) = ddq1;
  der(q2) = qd2;
  der(qd2) = ddq2;
  der(z) = zd;
  der(zd) = ddz;

  ddq1 = (M22*(tau1Sat - C1) - M12*(tau2Sat - C2))/Dsafe;
  ddq2 = (M11*(tau2Sat - C2) - M12*(tau1Sat - C1))/Dsafe;
  ddz = (tauFSat - mt*g + FcontactZ)/mt;

  // Collision model for floor and table
  dxT = xw - xTable;
  dyT = yw - yTable;
  rT = sqrt(dxT^2 + dyT^2 + 1.0e-12);
  penF = zFloor - zTip;
  FcF = if noEvent(penF > 0.0) then max(0.0, kContact*penF - dContact*zd) else 0.0;
  penT = zTable - zTip;
  FcT = if noEvent(penT > 0.0 and rT <= rTable + rTip) then max(0.0, kContact*penT - dContact*zd) else 0.0;
  FcontactZ = if collisionEnabled then FcF + FcT else 0.0;

  // Base reaction and payload retention monitor
  baseReactionForce = (mBase + m1 + m2 + m3 + mpActive)*g;
  payloadRetentionForce = if mpActive > 0.0 then max(0.0, mpActive*(g + ddz) + retentionMargin) else 0.0;
  payloadRetained = (mpActive <= 0.0) or (payloadRetentionForce > 0.0);

  // Wrist wrench sensor and encoders
  vxw = -l1*sin(q1)*qd1 - l2*sin(phi)*(qd1 + qd2);
  vyw = l1*cos(q1)*qd1 + l2*cos(phi)*(qd1 + qd2);
  axw = -l1*cos(q1)*qd1^2 - l1*sin(q1)*ddq1 - l2*cos(phi)*(qd1 + qd2)^2 - l2*sin(phi)*(ddq1 + ddq2);
  ayw = -l1*sin(q1)*qd1^2 + l1*cos(q1)*ddq1 - l2*sin(phi)*(qd1 + qd2)^2 + l2*cos(phi)*(ddq1 + ddq2);
  wrenchFx = mpActive*axw;
  wrenchFy = mpActive*ayw;
  wrenchFz = mpActive*ddz + FcontactZ;
  wrenchTx = 0.0;
  wrenchTy = 0.0;
  wrenchTz = 0.0;
  wristForceNorm = sqrt(wrenchFx^2 + wrenchFy^2 + wrenchFz^2 + 1.0e-12);

  qEnc1 = q1;
  qEnc2 = q2;
  zEnc = z;

  // Tracking and constraint monitors
  primaryError = max(abs(q1 - q1Des), max(abs(q2 - q2Des), abs(z - zDes)));
  poseErrorPos = sqrt((xw - xwDes)^2 + (yw - ywDes)^2 + (z - zDes)^2 + 1.0e-12);
  orientationError = abs(phi - phiDes);
  joint1OK = abs(q1) <= q1Limit;
  joint2OK = abs(q2) <= q2Limit;
  jointZOK = z >= -1.0e-6 and z <= zTravel + 1.0e-6;
  effort1OK = abs(tau1Sat) <= tauMax + 1.0e-6;
  effort2OK = abs(tau2Sat) <= tauMax + 1.0e-6;
  effortFOK = abs(tauFSat) <= fMax + 1.0e-6;
  wristForceOK = wristForceNorm <= fWristLimit;
  trackingOK = if time >= 6.5 then primaryError <= trackLimit else true;
  orientationOK = orientationError <= trackLimit;
  finiteValuesOK = Dsafe > 0.0 and mt > 0.0 and wristForceNorm >= 0.0 and rT >= 0.0 and primaryError >= 0.0;
  missionOK = joint1OK and joint2OK and jointZOK and effort1OK and effort2OK and effortFOK and wristForceOK and payloadRetained and trackingOK and orientationOK and finiteValuesOK;

  // Computed-torque control with bounded wrist-force correction at 100 Hz
  when sample(0.0, dt) then
    e1c := q1Des - q1;
    e2c := q2Des - q2;
    ezc := zDes - z;
    ed1c := qd1Des - qd1;
    ed2c := qd2Des - qd2;
    edzc := qdzDes - zd;
    ddq1c := qdd1Des + Kp1*e1c + Kd1*ed1c;
    ddq2c := qdd2Des + Kp2*e2c + Kd2*ed2c;
    ddzc := zddDes + Kpz*ezc + Kdz*edzc;

    mtc := m3 + mpActive;
    cos2c := cos(q2);
    sin2c := sin(q2);
    M11c := m1*l1^2/3.0 + m2*(l1^2 + l2^2/3.0 + l1*l2*cos2c) + mtc*(l1^2 + l2^2 + 2.0*l1*l2*cos2c);
    M12c := m2*(l2^2/3.0 + 0.5*l1*l2*cos2c) + mtc*(l2^2 + l1*l2*cos2c);
    M22c := (m2/3.0 + mtc)*l2^2;
    bc := m2*l1*l2 + 2.0*mtc*l1*l2;
    dcc := 0.5*m2*l1*l2 + mtc*l1*l2;
    C1c := -bc*sin2c*qd1*qd2 - dcc*sin2c*qd2^2;
    C2c := dcc*sin2c*qd1^2;

    fXraw := -Kw*pre(sensFx);
    fYraw := -Kw*pre(sensFy);
    fZraw := -Kw*pre(sensFz);
    (fCorrX, fCorrY, fCorrZ) := saturateVec3(fXraw, fYraw, fZraw, fCorrMax);

    Jx1c := -l1*sin(q1) - l2*sin(q1 + q2);
    Jy1c := l1*cos(q1) + l2*cos(q1 + q2);
    Jx2c := -l2*sin(q1 + q2);
    Jy2c := l2*cos(q1 + q2);
    fCorr1 := Jx1c*fCorrX + Jy1c*fCorrY;
    fCorr2 := Jx2c*fCorrX + Jy2c*fCorrY;
    fCorrF := fCorrZ;

    tau1Raw := M11c*ddq1c + M12c*ddq2c + C1c + fCorr1;
    tau2Raw := M12c*ddq1c + M22c*ddq2c + C2c + fCorr2;
    tauFRaw := mtc*ddzc + mtc*g + fCorrF;

    tau1Sat := max(-tauMax, min(tauMax, tau1Raw));
    tau2Sat := max(-tauMax, min(tauMax, tau2Raw));
    tauFSat := max(-fMax, min(fMax, tauFRaw));

    sensFx := wrenchFx;
    sensFy := wrenchFy;
    sensFz := wrenchFz;

    logTime := time;
    logQ1 := q1;
    logQ2 := q2;
    logZ := z;
    logQd1 := qd1;
    logQd2 := qd2;
    logZd := zd;
    logTau1 := tau1Sat;
    logTau2 := tau2Sat;
    logTauF := tauFSat;
    logWfx := wrenchFx;
    logWfy := wrenchFy;
    logWfz := wrenchFz;
    logPrimaryError := primaryError;
  end when;

  annotation (experiment(StopTime=10.0, Tolerance=1e-6));
end SCARACarryB;