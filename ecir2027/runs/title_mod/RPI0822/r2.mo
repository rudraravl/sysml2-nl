model WheelLegWalkF
  // Requirement-specified constants
  parameter Real bodyMass = 28.0 "kg";
  parameter Real wheelRadius = 0.10 "m";
  parameter Real torqueLimit = 67.1 "N.m per joint/wheel actuator";
  parameter Real groundFriction = 0.85;
  parameter Real g = 9.81 "m/s2";
  parameter Real vRef = 0.4 "m/s";
  parameter Real Fpush = 102.0 "N";
  parameter Real Ts = 0.002 "s, 500 Hz control and trace sampling";
  parameter Real tEnd = 20.0 "s";
  parameter Real tPushStart = tEnd/3.0 "middle third start";
  parameter Real tPushEnd = 2.0*tEnd/3.0 "middle third end";
  parameter Real eMaxAfter13 = 0.08 "m/s";

  // Placeholder values for facts not stated in the request.
  // They are finite initialization/controller placeholders only and are not asserted as requirement facts.
  constant Real pi = 3.141592653589793;
  parameter Real zInit = 0.50 "unknown initial body height placeholder";
  parameter Real IBody = 1.0 "unknown body inertia placeholder";
  parameter Real gaitPeriod = 1.0 "unknown gait period placeholder";
  parameter Real qHip0 = 0.0 "unknown hip offset placeholder";
  parameter Real qKnee0 = 0.30 "unknown knee offset placeholder";
  parameter Real ampHip = 0.10 "unknown hip swing amplitude placeholder";
  parameter Real ampKnee = 0.10 "unknown knee swing amplitude placeholder";
  parameter Real tauJoint = 0.05 "unknown joint tracking time constant placeholder";
  parameter Real KpLeg = 50.0 "unknown leg impedance proportional gain placeholder";
  parameter Real KdLeg = 2.0 "unknown leg impedance derivative gain placeholder";
  parameter Real KwWheel = 10.0 "unknown wheel velocity gain placeholder";
  parameter Real Kz = 2000.0 "unknown body height stiffness placeholder";
  parameter Real Kdz = 200.0 "unknown body height damping placeholder";
  parameter Real KpPitch = 50.0 "unknown attitude proportional gain placeholder";
  parameter Real KdPitch = 10.0 "unknown attitude derivative gain placeholder";
  parameter Real pitchLimit = 0.10 "unknown attitude tolerance placeholder";
  parameter Real contactThreshold = 1.0e-6 "N";
  parameter Real largeFinite = 1.0e30;

  parameter Real hRef(fixed=false) "nominal body height; initialized from initial height because the request does not state a numeric height";

  // Floating-base states
  Real x(start=0.0, fixed=true) "forward position, m";
  Real vx(start=vRef, fixed=true) "forward velocity, m/s";
  Real z(start=zInit, fixed=true) "body height, m";
  Real vz(start=0.0, fixed=true) "vertical velocity, m/s";
  Real pitch(start=0.0, fixed=true) "body pitch, rad";
  Real pitchRate(start=0.0, fixed=true) "body pitch rate, rad/s";

  // Wheel states
  Real thetaWheel1(start=0.0, fixed=true) "wheel 1 angle, rad";
  Real thetaWheel2(start=0.0, fixed=true) "wheel 2 angle, rad";
  Real thetaWheel3(start=0.0, fixed=true) "wheel 3 angle, rad";
  Real thetaWheel4(start=0.0, fixed=true) "wheel 4 angle, rad";

  // Leg joint states
  Real qHip1(start=qHip0, fixed=true) "hip 1 angle, rad";
  Real qHip2(start=qHip0 + ampHip, fixed=true) "hip 2 angle, rad";
  Real qHip3(start=qHip0, fixed=true) "hip 3 angle, rad";
  Real qHip4(start=qHip0 - ampHip, fixed=true) "hip 4 angle, rad";
  Real qKnee1(start=qKnee0, fixed=true) "knee 1 angle, rad";
  Real qKnee2(start=qKnee0 + ampKnee, fixed=true) "knee 2 angle, rad";
  Real qKnee3(start=qKnee0 + 2.0*ampKnee, fixed=true) "knee 3 angle, rad";
  Real qKnee4(start=qKnee0 + ampKnee, fixed=true) "knee 4 angle, rad";

  // Joint velocities and commanded trajectories
  Real qdHip1, qdHip2, qdHip3, qdHip4;
  Real qdKnee1, qdKnee2, qdKnee3, qdKnee4;
  Real qHipDes1, qHipDes2, qHipDes3, qHipDes4;
  Real qKneeDes1, qKneeDes2, qKneeDes3, qKneeDes4;
  Real qdHipDes1, qdHipDes2, qdHipDes3, qdHipDes4;
  Real qdKneeDes1, qdKneeDes2, qdKneeDes3, qdKneeDes4;

  // Phase variables
  Real phase "gait phase in [0,1)";
  Real phi1, phi2, phi3, phi4;
  Real omega;

  // Wheel variables
  Real wWheelDes "desired wheel angular speed, rad/s";
  Real wWheel1, wWheel2, wWheel3, wWheel4;
  Real tauWheelRaw1, tauWheelRaw2, tauWheelRaw3, tauWheelRaw4;
  Real tauWheel1, tauWheel2, tauWheel3, tauWheel4;

  // Contact and force variables
  Real Fz1, Fz2, Fz3, Fz4;
  Real Fx1, Fx2, Fx3, Fx4;
  Real FzTotal, FxWheels, FxDisturb, ax, az;
  Real contact1Indicator, contact2Indicator, contact3Indicator, contact4Indicator;
  Real contactCount "supporting-contact count";
  Real footForce1, footForce2, footForce3, footForce4;

  // Sensors
  Real encoderHip1, encoderHip2, encoderHip3, encoderHip4;
  Real encoderKnee1, encoderKnee2, encoderKnee3, encoderKnee4;
  Real imuPitch, imuPitchRate, imuAccX, imuAccZ;

  // Commands
  Real tauPitchRaw, tauPitchCmd;
  Real hipImp1, hipImp2, hipImp3, hipImp4;
  Real tauHipRaw1, tauHipRaw2, tauHipRaw3, tauHipRaw4;
  Real tauHip1, tauHip2, tauHip3, tauHip4;
  Real tauKnee1, tauKnee2, tauKnee3, tauKnee4;

  // Verification variables
  Real trackingError "primary tracking error, m/s";
  Real torqueBoundsOK;
  Real contactCountOK;
  Real attitudeOK;
  Real forwardProgressOK;
  Real trackingOKafter13;
  Real finiteCheck;
  Real verificationOK;

  // Synchronized 500 Hz traces
  Real logTime(start=0.0);
  Real logX(start=0.0);
  Real logVx(start=vRef);
  Real logZ(start=zInit);
  Real logPitch(start=0.0);
  Real logContactCount(start=4.0);
  Real logTrackingError(start=0.0);
  Real logTauHip1(start=0.0);
  Real logTauHip2(start=0.0);
  Real logTauHip3(start=0.0);
  Real logTauHip4(start=0.0);
  Real logTauKnee1(start=0.0);
  Real logTauKnee2(start=0.0);
  Real logTauKnee3(start=0.0);
  Real logTauKnee4(start=0.0);
  Real logTauWheel1(start=0.0);
  Real logTauWheel2(start=0.0);
  Real logTauWheel3(start=0.0);
  Real logTauWheel4(start=0.0);
  Real logTauPitchCmd(start=0.0);
  Real logFootForce1(start=0.0);
  Real logFootForce2(start=0.0);
  Real logFootForce3(start=0.0);
  Real logFootForce4(start=0.0);
  Real logVerificationOK(start=1.0);

initial equation
  hRef = z;

equation
  // Gait phase
  omega = 2.0*pi/gaitPeriod;
  phase = mod(time/gaitPeriod, 1.0);
  phi1 = 2.0*pi*phase + 0.0;
  phi2 = 2.0*pi*phase + pi/2.0;
  phi3 = 2.0*pi*phase + pi;
  phi4 = 2.0*pi*phase + 3.0*pi/2.0;

  // Phase-based desired joint trajectories
  qHipDes1 = qHip0 + ampHip*sin(phi1);
  qHipDes2 = qHip0 + ampHip*sin(phi2);
  qHipDes3 = qHip0 + ampHip*sin(phi3);
  qHipDes4 = qHip0 + ampHip*sin(phi4);

  qKneeDes1 = qKnee0 + ampKnee*(1.0 - cos(phi1));
  qKneeDes2 = qKnee0 + ampKnee*(1.0 - cos(phi2));
  qKneeDes3 = qKnee0 + ampKnee*(1.0 - cos(phi3));
  qKneeDes4 = qKnee0 + ampKnee*(1.0 - cos(phi4));

  qdHipDes1 = ampHip*omega*cos(phi1);
  qdHipDes2 = ampHip*omega*cos(phi2);
  qdHipDes3 = ampHip*omega*cos(phi3);
  qdHipDes4 = ampHip*omega*cos(phi4);

  qdKneeDes1 = ampKnee*omega*sin(phi1);
  qdKneeDes2 = ampKnee*omega*sin(phi2);
  qdKneeDes3 = ampKnee*omega*sin(phi3);
  qdKneeDes4 = ampKnee*omega*sin(phi4);

  // Joint encoder / tracking dynamics
  der(qHip1) = qdHip1;
  der(qHip2) = qdHip2;
  der(qHip3) = qdHip3;
  der(qHip4) = qdHip4;
  qdHip1 = (qHipDes1 - qHip1)/tauJoint;
  qdHip2 = (qHipDes2 - qHip2)/tauJoint;
  qdHip3 = (qHipDes3 - qHip3)/tauJoint;
  qdHip4 = (qHipDes4 - qHip4)/tauJoint;

  der(qKnee1) = qdKnee1;
  der(qKnee2) = qdKnee2;
  der(qKnee3) = qdKnee3;
  der(qKnee4) = qdKnee4;
  qdKnee1 = (qKneeDes1 - qKnee1)/tauJoint;
  qdKnee2 = (qKneeDes2 - qKnee2)/tauJoint;
  qdKnee3 = (qKneeDes3 - qKnee3)/tauJoint;
  qdKnee4 = (qKneeDes4 - qKnee4)/tauJoint;

  // Body-attitude control
  tauPitchRaw = -KpPitch*pitch - KdPitch*pitchRate;
  tauPitchCmd = max(-torqueLimit, min(torqueLimit, tauPitchRaw));

  // Leg impedance commands; front legs receive positive attitude share, rear legs negative
  hipImp1 = KpLeg*(qHipDes1 - qHip1) + KdLeg*(qdHipDes1 - qdHip1);
  hipImp2 = KpLeg*(qHipDes2 - qHip2) + KdLeg*(qdHipDes2 - qdHip2);
  hipImp3 = KpLeg*(qHipDes3 - qHip3) + KdLeg*(qdHipDes3 - qdHip3);
  hipImp4 = KpLeg*(qHipDes4 - qHip4) + KdLeg*(qdHipDes4 - qdHip4);

  tauHipRaw1 = hipImp1 + tauPitchCmd/4.0;
  tauHipRaw2 = hipImp2 + tauPitchCmd/4.0;
  tauHipRaw3 = hipImp3 - tauPitchCmd/4.0;
  tauHipRaw4 = hipImp4 - tauPitchCmd/4.0;

  tauHip1 = max(-torqueLimit, min(torqueLimit, tauHipRaw1));
  tauHip2 = max(-torqueLimit, min(torqueLimit, tauHipRaw2));
  tauHip3 = max(-torqueLimit, min(torqueLimit, tauHipRaw3));
  tauHip4 = max(-torqueLimit, min(torqueLimit, tauHipRaw4));

  tauKnee1 = max(-torqueLimit, min(torqueLimit, KpLeg*(qKneeDes1 - qKnee1) + KdLeg*(qdKneeDes1 - qdKnee1)));
  tauKnee2 = max(-torqueLimit, min(torqueLimit, KpLeg*(qKneeDes2 - qKnee2) + KdLeg*(qdKneeDes2 - qdKnee2)));
  tauKnee3 = max(-torqueLimit, min(torqueLimit, KpLeg*(qKneeDes3 - qKnee3) + KdLeg*(qdKneeDes3 - qdKnee3)));
  tauKnee4 = max(-torqueLimit, min(torqueLimit, KpLeg*(qKneeDes4 - qKnee4) + KdLeg*(qdKneeDes4 - qdKnee4)));

  // Wheel rolling and wheel torque commands
  wWheelDes = vRef/wheelRadius;
  wWheel1 = vx/wheelRadius;
  wWheel2 = vx/wheelRadius;
  wWheel3 = vx/wheelRadius;
  wWheel4 = vx/wheelRadius;

  tauWheelRaw1 = KwWheel*(wWheelDes - wWheel1);
  tauWheelRaw2 = KwWheel*(wWheelDes - wWheel2);
  tauWheelRaw3 = KwWheel*(wWheelDes - wWheel3);
  tauWheelRaw4 = KwWheel*(wWheelDes - wWheel4);

  tauWheel1 = max(-torqueLimit, min(torqueLimit, tauWheelRaw1));
  tauWheel2 = max(-torqueLimit, min(torqueLimit, tauWheelRaw2));
  tauWheel3 = max(-torqueLimit, min(torqueLimit, tauWheelRaw3));
  tauWheel4 = max(-torqueLimit, min(torqueLimit, tauWheelRaw4));

  der(thetaWheel1) = wWheel1;
  der(thetaWheel2) = wWheel2;
  der(thetaWheel3) = wWheel3;
  der(thetaWheel4) = wWheel4;

  // Vertical support forces and contact indicators
  Fz1 = max(0.0, bodyMass*g/4.0 + Kz*(hRef - z) - Kdz*vz);
  Fz2 = max(0.0, bodyMass*g/4.0 + Kz*(hRef - z) - Kdz*vz);
  Fz3 = max(0.0, bodyMass*g/4.0 + Kz*(hRef - z) - Kdz*vz);
  Fz4 = max(0.0, bodyMass*g/4.0 + Kz*(hRef - z) - Kdz*vz);

  contact1Indicator = if Fz1 > contactThreshold then 1.0 else 0.0;
  contact2Indicator = if Fz2 > contactThreshold then 1.0 else 0.0;
  contact3Indicator = if Fz3 > contactThreshold then 1.0 else 0.0;
  contact4Indicator = if Fz4 > contactThreshold then 1.0 else 0.0;
  contactCount = contact1Indicator + contact2Indicator + contact3Indicator + contact4Indicator;

  // Friction-limited horizontal wheel forces
  Fx1 = max(-groundFriction*Fz1, min(groundFriction*Fz1, tauWheel1/wheelRadius));
  Fx2 = max(-groundFriction*Fz2, min(groundFriction*Fz2, tauWheel2/wheelRadius));
  Fx3 = max(-groundFriction*Fz3, min(groundFriction*Fz3, tauWheel3/wheelRadius));
  Fx4 = max(-groundFriction*Fz4, min(groundFriction*Fz4, tauWheel4/wheelRadius));

  FxWheels = Fx1 + Fx2 + Fx3 + Fx4;
  FzTotal = Fz1 + Fz2 + Fz3 + Fz4;

  // Controlled middle-third push disturbance
  FxDisturb = if time >= tPushStart and time < tPushEnd then -Fpush else 0.0;

  // Floating-base dynamics
  ax = (FxWheels + FxDisturb)/bodyMass;
  az = (FzTotal - bodyMass*g)/bodyMass;

  der(x) = vx;
  der(vx) = ax;
  der(z) = vz;
  der(vz) = az;
  der(pitch) = pitchRate;
  der(pitchRate) = tauPitchCmd/IBody;

  // Sensors
  encoderHip1 = qHip1;
  encoderHip2 = qHip2;
  encoderHip3 = qHip3;
  encoderHip4 = qHip4;
  encoderKnee1 = qKnee1;
  encoderKnee2 = qKnee2;
  encoderKnee3 = qKnee3;
  encoderKnee4 = qKnee4;

  imuPitch = pitch;
  imuPitchRate = pitchRate;
  imuAccX = ax;
  imuAccZ = az;

  footForce1 = sqrt(Fx1*Fx1 + Fz1*Fz1);
  footForce2 = sqrt(Fx2*Fx2 + Fz2*Fz2);
  footForce3 = sqrt(Fx3*Fx3 + Fz3*Fz3);
  footForce4 = sqrt(Fx4*Fx4 + Fz4*Fz4);

  // Verification criteria
  trackingError = vx - vRef;

  torqueBoundsOK = if (abs(tauHip1) <= torqueLimit + 1.0e-9 and
                       abs(tauHip2) <= torqueLimit + 1.0e-9 and
                       abs(tauHip3) <= torqueLimit + 1.0e-9 and
                       abs(tauHip4) <= torqueLimit + 1.0e-9 and
                       abs(tauKnee1) <= torqueLimit + 1.0e-9 and
                       abs(tauKnee2) <= torqueLimit + 1.0e-9 and
                       abs(tauKnee3) <= torqueLimit + 1.0e-9 and
                       abs(tauKnee4) <= torqueLimit + 1.0e-9 and
                       abs(tauWheel1) <= torqueLimit + 1.0e-9 and
                       abs(tauWheel2) <= torqueLimit + 1.0e-9 and
                       abs(tauWheel3) <= torqueLimit + 1.0e-9 and
                       abs(tauWheel4) <= torqueLimit + 1.0e-9) then 1.0 else 0.0;

  contactCountOK = if contactCount >= 1.0 then 1.0 else 0.0;
  attitudeOK = if abs(pitch) <= pitchLimit then 1.0 else 0.0;
  forwardProgressOK = if x > 0.0 and vx > 0.0 then 1.0 else 0.0;
  trackingOKafter13 = if time >= 13.0 then if abs(trackingError) < eMaxAfter13 then 1.0 else 0.0 else 1.0;

  finiteCheck = if (
    (x == x) and (x < largeFinite) and (x > -largeFinite) and
    (vx == vx) and (vx < largeFinite) and (vx > -largeFinite) and
    (z == z) and (z < largeFinite) and (z > -largeFinite) and
    (vz == vz) and (vz < largeFinite) and (vz > -largeFinite) and
    (pitch == pitch) and (pitch < largeFinite) and (pitch > -largeFinite) and
    (pitchRate == pitchRate) and (pitchRate < largeFinite) and (pitchRate > -largeFinite) and
    (tauHip1 == tauHip1) and (tauHip1 < largeFinite) and (tauHip1 > -largeFinite) and
    (tauHip2 == tauHip2) and (tauHip2 < largeFinite) and (tauHip2 > -largeFinite) and
    (tauHip3 == tauHip3) and (tauHip3 < largeFinite) and (tauHip3 > -largeFinite) and
    (tauHip4 == tauHip4) and (tauHip4 < largeFinite) and (tauHip4 > -largeFinite) and
    (tauKnee1 == tauKnee1) and (tauKnee1 < largeFinite) and (tauKnee1 > -largeFinite) and
    (tauKnee2 == tauKnee2) and (tauKnee2 < largeFinite) and (tauKnee2 > -largeFinite) and
    (tauKnee3 == tauKnee3) and (tauKnee3 < largeFinite) and (tauKnee3 > -largeFinite) and
    (tauKnee4 == tauKnee4) and (tauKnee4 < largeFinite) and (tauKnee4 > -largeFinite) and
    (tauWheel1 == tauWheel1) and (tauWheel1 < largeFinite) and (tauWheel1 > -largeFinite) and
    (tauWheel2 == tauWheel2) and (tauWheel2 < largeFinite) and (tauWheel2 > -largeFinite) and
    (tauWheel3 == tauWheel3) and (tauWheel3 < largeFinite) and (tauWheel3 > -largeFinite) and
    (tauWheel4 == tauWheel4) and (tauWheel4 < largeFinite) and (tauWheel4 > -largeFinite) and
    (tauPitchCmd == tauPitchCmd) and (tauPitchCmd < largeFinite) and (tauPitchCmd > -largeFinite) and
    (contactCount == contactCount) and (contactCount < largeFinite) and (contactCount > -largeFinite) and
    (trackingError == trackingError) and (trackingError < largeFinite) and (trackingError > -largeFinite) and
    (footForce1 == footForce1) and (footForce1 < largeFinite) and (footForce1 > -largeFinite) and
    (footForce2 == footForce2) and (footForce2 < largeFinite) and (footForce2 > -largeFinite) and
    (footForce3 == footForce3) and (footForce3 < largeFinite) and (footForce3 > -largeFinite) and
    (footForce4 == footForce4) and (footForce4 < largeFinite) and (footForce4 > -largeFinite)
  ) then 1.0 else 0.0;

  verificationOK = if (torqueBoundsOK > 0.5 and
                       contactCountOK > 0.5 and
                       attitudeOK > 0.5 and
                       forwardProgressOK > 0.5 and
                       trackingOKafter13 > 0.5 and
                       finiteCheck > 0.5) then 1.0 else 0.0;

  // Synchronized state, command, and sensor traces at 500 Hz
  when sample(0.0, Ts) then
    logTime = time;
    logX = x;
    logVx = vx;
    logZ = z;
    logPitch = pitch;
    logContactCount = contactCount;
    logTrackingError = trackingError;
    logTauHip1 = tauHip1;
    logTauHip2 = tauHip2;
    logTauHip3 = tauHip3;
    logTauHip4 = tauHip4;
    logTauKnee1 = tauKnee1;
    logTauKnee2 = tauKnee2;
    logTauKnee3 = tauKnee3;
    logTauKnee4 = tauKnee4;
    logTauWheel1 = tauWheel1;
    logTauWheel2 = tauWheel2;
    logTauWheel3 = tauWheel3;
    logTauWheel4 = tauWheel4;
    logTauPitchCmd = tauPitchCmd;
    logFootForce1 = footForce1;
    logFootForce2 = footForce2;
    logFootForce3 = footForce3;
    logFootForce4 = footForce4;
    logVerificationOK = verificationOK;
  end when;

  annotation (experiment(StartTime=0.0, StopTime=20.0, Tolerance=1.0e-6, Interval=0.002));
end WheelLegWalkF;