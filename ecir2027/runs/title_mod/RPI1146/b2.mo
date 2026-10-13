model AirTrioHandoffF
  // -------- Timing & scenario --------
  parameter Real Tend = 20.0 "s simulation duration";
  parameter Real Ts = 0.002 "s sample period 500 Hz";
  parameter Real tDelayLo = 6.6667 "s middle-third start";
  parameter Real tDelayHi = 13.3333 "s middle-third end";
  parameter Real dDelay = 0.145 "s controlled communication delay";

  // -------- Physical parameters --------
  parameter Real m = 1.8 "kg per quadrotor";
  parameter Real g = 9.81 "m/s^2";
  parameter Real Tmax = 14.6 "N per rotor max";
  parameter Real minSep = 1.0 "m minimum separation";
  parameter Real trackTol = 0.32 "m primary tracking error tolerance";
  parameter Real tCheck = 13.0 "s verification time";
  parameter Real handoffR = 0.5 "m handoff trigger radius";
  parameter Real tauAtt = 0.12 "s attitude time constant";
  parameter Real tauEst = 0.05 "s estimator filter time constant";
  parameter Real Kp_pos = 4.0;
  parameter Real Kd_pos = 4.0;
  parameter Real Kroll = 0.6 "rotor mixing gain roll";
  parameter Real Kpitch = 0.6 "rotor mixing gain pitch";

  // -------- World features (common world frame) --------
  parameter Real WP1x = 3.0; parameter Real WP1y = 0.0; parameter Real WP1z = 2.0;
  parameter Real WP2x = 3.0; parameter Real WP2y = 3.0; parameter Real WP2z = 2.0;
  parameter Real WP3x = 3.0; parameter Real WP3y = 1.5; parameter Real WP3z = 2.0;
  parameter Real WallXmax = 6.0 "m survey wall";
  parameter Real WallYmax = 6.0 "m survey wall";
  parameter Real WallZceil = 5.0 "m ceiling marker";

  // -------- Robot 1 states --------
  Real x1(start=0.0), y1(start=0.0), z1(start=2.0);
  Real vx1(start=0.0), vy1(start=0.0), vz1(start=0.0);
  Real roll1(start=0.0), pitch1(start=0.0);
  Real xh1(start=0.0), yh1(start=0.0), zh1(start=2.0) "estimator";
  Real T11, T12, T13, T14;
  Real Ttot_des1, Ttot1;
  Real err1;

  // -------- Robot 2 states --------
  Real x2(start=0.0), y2(start=3.0), z2(start=2.0);
  Real vx2(start=0.0), vy2(start=0.0), vz2(start=0.0);
  Real roll2(start=0.0), pitch2(start=0.0);
  Real xh2(start=0.0), yh2(start=3.0), zh2(start=2.0);
  Real T21, T22, T23, T24;
  Real Ttot_des2, Ttot2;
  Real err2;

  // -------- Robot 3 states --------
  Real x3(start=1.5), y3(start=1.5), z3(start=2.0);
  Real vx3(start=0.0), vy3(start=0.0), vz3(start=0.0);
  Real roll3(start=0.0), pitch3(start=0.0);
  Real xh3(start=1.5), yh3(start=1.5), zh3(start=2.0);
  Real T31, T32, T33, T34;
  Real Ttot_des3, Ttot3;
  Real err3;

  // -------- Handoff / task allocation --------
  discrete Integer handoffOwner(start=1);
  discrete Boolean msg1Sent(start=false);
  discrete Boolean msg2Sent(start=false);
  discrete Boolean msg1Recv(start=false);
  discrete Boolean msg2Recv(start=false);
  discrete Real msg1SendTime(start=0.0);
  discrete Real msg2SendTime(start=0.0);
  discrete Real msg1Delay(start=0.0);
  discrete Real msg2Delay(start=0.0);
  discrete Real msg1RecvTime(start=0.0);
  discrete Real msg2RecvTime(start=0.0);
  Real dataAge1, dataAge2;
  Real commDelayNow;

  // -------- Per-robot targets --------
  Real tx1, ty1, tz1;
  Real tx2, ty2, tz2;
  Real tx3, ty3, tz3;

  // -------- Intermediate quantities --------
  Real ax1d, ay1d, az1d, ax2d, ay2d, az2d, ax3d, ay3d, az3d;
  Real roll1c, pitch1c, roll2c, pitch2c, roll3c, pitch3c;
  Real d12, d13, d23;
  Real mT1, mT2, mT3;

  // -------- Verification outputs --------
  Real minSeparation;
  Real maxThrust;
  Real primaryTrackErr;
  Boolean handoffSuccess;
  Boolean taskComplete;
  Boolean noCollision;
  Boolean actuatorOK;
  Boolean separationOK;
  Boolean trackingOK;
  Boolean dataAgeOK;
  Boolean allOK;

equation
  // Communication delay schedule (middle third of run)
  commDelayNow = if (time >= tDelayLo and time <= tDelayHi) then dDelay else 0.0;

  // Task allocation: per-robot target depends on handoff owner
  tx1 = if handoffOwner == 1 then WP1x else 0.0;
  ty1 = if handoffOwner == 1 then WP1y else 0.0;
  tz1 = if handoffOwner == 1 then WP1z else 2.0;
  tx2 = if handoffOwner == 2 then WP2x else 0.0;
  ty2 = if handoffOwner == 2 then WP2y else 3.0;
  tz2 = if handoffOwner == 2 then WP2z else 2.0;
  tx3 = if handoffOwner == 3 then WP3x else 1.5;
  ty3 = if handoffOwner == 3 then WP3y else 1.5;
  tz3 = if handoffOwner == 3 then WP3z else 2.0;

  // Tracking errors (sqrt of nonnegative sum; zero-error well-defined)
  err1 = sqrt((x1-tx1)*(x1-tx1) + (y1-ty1)*(y1-ty1) + (z1-tz1)*(z1-tz1));
  err2 = sqrt((x2-tx2)*(x2-tx2) + (y2-ty2)*(y2-ty2) + (z2-tz2)*(z2-tz2));
  err3 = sqrt((x3-tx3)*(x3-tx3) + (y3-ty3)*(y3-ty3) + (z3-tz3)*(z3-tz3));

  // ----- Estimators (first-order sensor filters) -----
  der(xh1) = (x1 - xh1)/tauEst;
  der(yh1) = (y1 - yh1)/tauEst;
  der(zh1) = (z1 - zh1)/tauEst;
  der(xh2) = (x2 - xh2)/tauEst;
  der(yh2) = (y2 - yh2)/tauEst;
  der(zh2) = (z2 - zh2)/tauEst;
  der(xh3) = (x3 - xh3)/tauEst;
  der(yh3) = (y3 - yh3)/tauEst;
  der(zh3) = (z3 - zh3)/tauEst;

  // ----- Robot 1 local motion control + dynamics -----
  ax1d = Kp_pos*(tx1 - xh1) - Kd_pos*vx1;
  ay1d = Kp_pos*(ty1 - yh1) - Kd_pos*vy1;
  az1d = Kp_pos*(tz1 - zh1) - Kd_pos*vz1;
  pitch1c = atan(ax1d / g);
  roll1c  = -atan(ay1d / g);
  Ttot_des1 = max(0.1, min(4.0*Tmax, m*(g + az1d)));
  T11 = max(0.0, min(Tmax, Ttot_des1/4.0 + Kpitch*(pitch1c - pitch1) + Kroll*(roll1c - roll1)));
  T12 = max(0.0, min(Tmax, Ttot_des1/4.0 + Kpitch*(pitch1c - pitch1) - Kroll*(roll1c - roll1)));
  T13 = max(0.0, min(Tmax, Ttot_des1/4.0 - Kpitch*(pitch1c - pitch1) - Kroll*(roll1c - roll1)));
  T14 = max(0.0, min(Tmax, Ttot_des1/4.0 - Kpitch*(pitch1c - pitch1) + Kroll*(roll1c - roll1)));
  Ttot1 = T11 + T12 + T13 + T14;
  der(x1) = vx1;
  der(y1) = vy1;
  der(z1) = vz1;
  der(vx1) = g*tan(pitch1);
  der(vy1) = -g*tan(roll1);
  der(vz1) = Ttot1/m - g;
  der(roll1)  = (roll1c  - roll1)/tauAtt;
  der(pitch1) = (pitch1c - pitch1)/tauAtt;

  // ----- Robot 2 -----
  ax2d = Kp_pos*(tx2 - xh2) - Kd_pos*vx2;
  ay2d = Kp_pos*(ty2 - yh2) - Kd_pos*vy2;
  az2d = Kp_pos*(tz2 - zh2) - Kd_pos*vz2;
  pitch2c = atan(ax2d / g);
  roll2c  = -atan(ay2d / g);
  Ttot_des2 = max(0.1, min(4.0*Tmax, m*(g + az2d)));
  T21 = max(0.0, min(Tmax, Ttot_des2/4.0 + Kpitch*(pitch2c - pitch2) + Kroll*(roll2c - roll2)));
  T22 = max(0.0, min(Tmax, Ttot_des2/4.0 + Kpitch*(pitch2c - pitch2) - Kroll*(roll2c - roll2)));
  T23 = max(0.0, min(Tmax, Ttot_des2/4.0 - Kpitch*(pitch2c - pitch2) - Kroll*(roll2c - roll2)));
  T24 = max(0.0, min(Tmax, Ttot_des2/4.0 - Kpitch*(pitch2c - pitch2) + Kroll*(roll2c - roll2)));
  Ttot2 = T21 + T22 + T23 + T24;
  der(x2) = vx2;
  der(y2) = vy2;
  der(z2) = vz2;
  der(vx2) = g*tan(pitch2);
  der(vy2) = -g*tan(roll2);
  der(vz2) = Ttot2/m - g;
  der(roll2)  = (roll2c  - roll2)/tauAtt;
  der(pitch2) = (pitch2c - pitch2)/tauAtt;

  // ----- Robot 3 -----
  ax3d = Kp_pos*(tx3 - xh3) - Kd_pos*vx3;
  ay3d = Kp_pos*(ty3 - yh3) - Kd_pos*vy3;
  az3d = Kp_pos*(tz3 - zh3) - Kd_pos*vz3;
  pitch3c = atan(ax3d / g);
  roll3c  = -atan(ay3d / g);
  Ttot_des3 = max(0.1, min(4.0*Tmax, m*(g + az3d)));
  T31 = max(0.0, min(Tmax, Ttot_des3/4.0 + Kpitch*(pitch3c - pitch3) + Kroll*(roll3c - roll3)));
  T32 = max(0.0, min(Tmax, Ttot_des3/4.0 + Kpitch*(pitch3c - pitch3) - Kroll*(roll3c - roll3)));
  T33 = max(0.0, min(Tmax, Ttot_des3/4.0 - Kpitch*(pitch3c - pitch3) - Kroll*(roll3c - roll3)));
  T34 = max(0.0, min(Tmax, Ttot_des3/4.0 - Kpitch*(pitch3c - pitch3) + Kroll*(roll3c - roll3)));
  Ttot3 = T31 + T32 + T33 + T34;
  der(x3) = vx3;
  der(y3) = vy3;
  der(z3) = vz3;
  der(vx3) = g*tan(pitch3);
  der(vy3) = -g*tan(roll3);
  der(vz3) = Ttot3/m - g;
  der(roll3)  = (roll3c  - roll3)/tauAtt;
  der(pitch3) = (pitch3c - pitch3)/tauAtt;

  // ----- Peer-relative range sensing (observable) -----
  d12 = sqrt((x1-x2)*(x1-x2) + (y1-y2)*(y1-y2) + (z1-z2)*(z1-z2));
  d13 = sqrt((x1-x3)*(x1-x3) + (y1-y3)*(y1-y3) + (z1-z3)*(z1-z3));
  d23 = sqrt((x2-x3)*(x2-x3) + (y2-y3)*(y2-y3) + (z2-z3)*(z2-z3));

  // ----- Communication: send/receive and data age -----
  dataAge1 = if msg1Recv then (time - msg1SendTime) else 0.0;
  dataAge2 = if msg2Recv then (time - msg2SendTime) else 0.0;

  // ----- Handoff state machine -----
  when handoffOwner == 1 and err1 < handoffR and not msg1Sent then
    msg1Sent := true;
    msg1SendTime := time;
    msg1Delay := if (time >= tDelayLo and time <= tDelayHi) then dDelay else 0.0;
  end when;

  when handoffOwner == 2 and err2 < handoffR and not msg2Sent then
    msg2Sent := true;
    msg2SendTime := time;
    msg2Delay := if (time >= tDelayLo and time <= tDelayHi) then dDelay else 0.0;
  end when;

  when msg1Sent and not msg1Recv and time >= msg1SendTime + msg1Delay then
    msg1Recv := true;
    msg1RecvTime := time;
    handoffOwner := 2;
  elsewhen msg2Sent and not msg2Recv and time >= msg2SendTime + msg2Delay then
    msg2Recv := true;
    msg2RecvTime := time;
    handoffOwner := 3;
  end when;

  // ----- Verification criteria -----
  minSeparation = min({d12, d13, d23});
  mT1 = max({T11, T12, T13, T14});
  mT2 = max({T21, T22, T23, T24});
  mT3 = max({T31, T32, T33, T34});
  maxThrust = max({mT1, mT2, mT3});

  primaryTrackErr = if handoffOwner == 1 then err1 elseif handoffOwner == 2 then err2 else err3;

  handoffSuccess = msg2Recv;
  taskComplete = handoffSuccess and (err3 < handoffR);
  noCollision = minSeparation > minSep;
  actuatorOK = maxThrust <= Tmax + 1e-6;
  separationOK = noCollision;
  trackingOK = (time < tCheck) or (primaryTrackErr < trackTol);
  dataAgeOK = (not msg1Recv or (dataAge1 <= dDelay + 0.01)) and (not msg2Recv or (dataAge2 <= dDelay + 0.01));
  allOK = actuatorOK and separationOK and trackingOK and handoffSuccess and taskComplete and dataAgeOK;

  annotation(
    experiment(StartTime=0.0, StopTime=20.0, Tolerance=1e-6, Interval=0.002),
    Documentation(info="AirTrioHandoffF: three 1.8 kg quadrotors (12 rotor-thrust groups, <=14.6 N/rotor) divide an inspection task with explicit handoff state and a controlled 0.145 s communication delay disturbance in the middle third. Run at 500 Hz for 20 s."));
end AirTrioHandoffF;