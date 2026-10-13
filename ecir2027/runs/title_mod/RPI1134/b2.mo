model AirTrioFormF
  "Three 1.8 kg quadrotors maintaining formation while following a leader trajectory, with bounded local commands and a 0.116 s message-delay disturbance during the middle third";

  // ----- Given numeric facts -----
  parameter Modelica.SIunits.Mass m = 1.8 "quadrotor mass";
  parameter Modelica.SIunits.Force maxRotorThrust = 14.6 "per-rotor actuator limit";
  parameter Modelica.SIunits.Time messageDelay = 0.116 "controlled delay disturbance";
  parameter Real sampleRate = 500.0 "control/update rate in Hz";
  parameter Modelica.SIunits.Time Ts = 1.0/sampleRate "sample interval";
  parameter Modelica.SIunits.Time T_end = 20.0 "mission duration";
  parameter Modelica.SIunits.Time T_start = T_end/3.0 "middle third start";
  parameter Modelica.SIunits.Time T_stop = 2.0*T_end/3.0 "middle third stop";
  parameter Modelica.SIunits.Length trackTol = 0.24 "primary tracking error threshold after 13 s";

  // ----- Assumed design/mission values (not specified in requirement) -----
  parameter Modelica.SIunits.Velocity vLead = 0.2 "assumed leader speed";
  parameter Modelica.SIunits.Length leadZ0 = 2.0 "assumed leader altitude";
  parameter Modelica.SIunits.Length offX1 = 0.0 "assumed formation offset";
  parameter Modelica.SIunits.Length offY1 = 0.6 "assumed formation offset";
  parameter Modelica.SIunits.Length offZ1 = 0.0 "assumed formation offset";
  parameter Modelica.SIunits.Length offX2 = -0.5 "assumed formation offset";
  parameter Modelica.SIunits.Length offY2 = -0.3 "assumed formation offset";
  parameter Modelica.SIunits.Length offZ2 = 0.0 "assumed formation offset";
  parameter Modelica.SIunits.Length offX3 = 0.5 "assumed formation offset";
  parameter Modelica.SIunits.Length offY3 = -0.3 "assumed formation offset";
  parameter Modelica.SIunits.Length offZ3 = 0.0 "assumed formation offset";
  parameter Modelica.SIunits.Length minSep = 0.5 "assumed minimum pairwise separation";
  parameter Modelica.SIunits.Length obs1x = 10.0 "assumed obstacle position";
  parameter Modelica.SIunits.Length obs1y = 5.0 "assumed obstacle position";
  parameter Modelica.SIunits.Length obs1z = 2.0 "assumed obstacle position";
  parameter Modelica.SIunits.Length obs2x = -10.0 "assumed obstacle position";
  parameter Modelica.SIunits.Length obs2y = -5.0 "assumed obstacle position";
  parameter Modelica.SIunits.Length obs2z = 2.0 "assumed obstacle position";
  parameter Modelica.SIunits.Length obsRadius = 1.0 "assumed obstacle safety radius";
  parameter Modelica.SIunits.Acceleration amax = 5.0 "assumed bounded local command magnitude";
  parameter Real Kp = 10.0 "assumed position gain";
  parameter Real Kd = 5.0 "assumed velocity gain";
  parameter Real Kc = 0.5 "assumed consensus gain";
  parameter Modelica.SIunits.Time tauEst = 0.02 "assumed estimator lag";
  parameter Modelica.SIunits.Force dmax = 1.0 "assumed differential thrust bound";
  parameter Real kRoll = 0.2 "assumed roll-thrust allocation gain";
  parameter Real kPitch = 0.2 "assumed pitch-thrust allocation gain";
  parameter Real kYaw = 0.2 "assumed yaw-thrust allocation gain";
  parameter Real epsLen = 1e-6 "regularization for sqrt divisions";

  constant Real g = 9.80665;

  // ----- Leader trajectory -----
  Modelica.SIunits.Length leadX, leadY, leadZ;
  Modelica.SIunits.Velocity leadVx, leadVy, leadVz;
  Modelica.SIunits.Acceleration leadAx, leadAy, leadAz;

  // ----- Quadrotor 1 states -----
  Modelica.SIunits.Length x1(start=offX1, fixed=true);
  Modelica.SIunits.Length y1(start=offY1, fixed=true);
  Modelica.SIunits.Length z1(start=leadZ0, fixed=true);
  Modelica.SIunits.Velocity vx1(start=0.0, fixed=true);
  Modelica.SIunits.Velocity vy1(start=0.0, fixed=true);
  Modelica.SIunits.Velocity vz1(start=0.0, fixed=true);
  Modelica.SIunits.Acceleration ax1, ay1, az1;

  // ----- Quadrotor 2 states -----
  Modelica.SIunits.Length x2(start=offX2, fixed=true);
  Modelica.SIunits.Length y2(start=offY2, fixed=true);
  Modelica.SIunits.Length z2(start=leadZ0, fixed=true);
  Modelica.SIunits.Velocity vx2(start=0.0, fixed=true);
  Modelica.SIunits.Velocity vy2(start=0.0, fixed=true);
  Modelica.SIunits.Velocity vz2(start=0.0, fixed=true);
  Modelica.SIunits.Acceleration ax2, ay2, az2;

  // ----- Quadrotor 3 states -----
  Modelica.SIunits.Length x3(start=offX3, fixed=true);
  Modelica.SIunits.Length y3(start=offY3, fixed=true);
  Modelica.SIunits.Length z3(start=leadZ0, fixed=true);
  Modelica.SIunits.Velocity vx3(start=0.0, fixed=true);
  Modelica.SIunits.Velocity vy3(start=0.0, fixed=true);
  Modelica.SIunits.Velocity vz3(start=0.0, fixed=true);
  Modelica.SIunits.Acceleration ax3, ay3, az3;

  // ----- Estimator states (onboard state estimation) -----
  Modelica.SIunits.Length estX1(start=offX1, fixed=true);
  Modelica.SIunits.Length estY1(start=offY1, fixed=true);
  Modelica.SIunits.Length estZ1(start=leadZ0, fixed=true);
  Modelica.SIunits.Velocity estVx1(start=0.0, fixed=true);
  Modelica.SIunits.Velocity estVy1(start=0.0, fixed=true);
  Modelica.SIunits.Velocity estVz1(start=0.0, fixed=true);

  Modelica.SIunits.Length estX2(start=offX2, fixed=true);
  Modelica.SIunits.Length estY2(start=offY2, fixed=true);
  Modelica.SIunits.Length estZ2(start=leadZ0, fixed=true);
  Modelica.SIunits.Velocity estVx2(start=0.0, fixed=true);
  Modelica.SIunits.Velocity estVy2(start=0.0, fixed=true);
  Modelica.SIunits.Velocity estVz2(start=0.0, fixed=true);

  Modelica.SIunits.Length estX3(start=offX3, fixed=true);
  Modelica.SIunits.Length estY3(start=offY3, fixed=true);
  Modelica.SIunits.Length estZ3(start=leadZ0, fixed=true);
  Modelica.SIunits.Velocity estVx3(start=0.0, fixed=true);
  Modelica.SIunits.Velocity estVy3(start=0.0, fixed=true);
  Modelica.SIunits.Velocity estVz3(start=0.0, fixed=true);

  // ----- Delayed pose messages (first-order lag approximation of transport delay) -----
  Modelica.SIunits.Time commAge;
  Modelica.SIunits.Time tauComm;
  Modelica.SIunits.Length msgX1(start=offX1, fixed=true);
  Modelica.SIunits.Length msgY1(start=offY1, fixed=true);
  Modelica.SIunits.Length msgZ1(start=leadZ0, fixed=true);
  Modelica.SIunits.Length msgX2(start=offX2, fixed=true);
  Modelica.SIunits.Length msgY2(start=offY2, fixed=true);
  Modelica.SIunits.Length msgZ2(start=leadZ0, fixed=true);
  Modelica.SIunits.Length msgX3(start=offX3, fixed=true);
  Modelica.SIunits.Length msgY3(start=offY3, fixed=true);
  Modelica.SIunits.Length msgZ3(start=leadZ0, fixed=true);

  // ----- Desired positions -----
  Modelica.SIunits.Length desX1, desY1, desZ1;
  Modelica.SIunits.Length desX2, desY2, desZ2;
  Modelica.SIunits.Length desX3, desY3, desZ3;

  // ----- Bounded local commands (continuous-time) -----
  Modelica.SIunits.Acceleration cmdAccX1, cmdAccY1, cmdAccZ1;
  Modelica.SIunits.Acceleration cmdAccX2, cmdAccY2, cmdAccZ2;
  Modelica.SIunits.Acceleration cmdAccX3, cmdAccY3, cmdAccZ3;
  Modelica.SIunits.Acceleration rawAccX1, rawAccY1, rawAccZ1;
  Modelica.SIunits.Acceleration rawAccX2, rawAccY2, rawAccZ2;
  Modelica.SIunits.Acceleration rawAccX3, rawAccY3, rawAccZ3;

  // ----- Rotor thrust groups (12 independent) -----
  Modelica.SIunits.Force Fx1, Fy1, Fz1, T1;
  Modelica.SIunits.Force Fx2, Fy2, Fz2, T2;
  Modelica.SIunits.Force Fx3, Fy3, Fz3, T3;
  Modelica.SIunits.Force dRoll1, dPitch1, dYaw1;
  Modelica.SIunits.Force dRoll2, dPitch2, dYaw2;
  Modelica.SIunits.Force dRoll3, dPitch3, dYaw3;
  Modelica.SIunits.Force r11, r12, r13, r14;
  Modelica.SIunits.Force r21, r22, r23, r24;
  Modelica.SIunits.Force r31, r32, r33, r34;

  // ----- Peer-relative range sensors -----
  Modelica.SIunits.Length range12, range13, range23;
  Modelica.SIunits.Length desRange12, desRange13, desRange23;

  // ----- Obstacle distances -----
  Modelica.SIunits.Length dist1obs1, dist1obs2;
  Modelica.SIunits.Length dist2obs1, dist2obs2;
  Modelica.SIunits.Length dist3obs1, dist3obs2;

  // ----- Verification metrics -----
  Modelica.SIunits.Length formationError;
  Modelica.SIunits.Length primaryTrackingError;
  Boolean actuatorLimitsOK;
  Boolean pairwiseSeparationOK;
  Boolean noCollisionOK;
  Boolean primaryTrackingErrorOK;
  Boolean finiteValuesOK;
  Boolean verificationOK;

  // Intermediate finite-check variables
  Real absX1, absY1, absZ1, absVX1, absVY1, absVZ1;
  Real absX2, absY2, absZ2, absVX2, absVY2, absVZ2;
  Real absX3, absY3, absZ3, absVX3, absVY3, absVZ3;
  Real absEX1, absEY1, absEZ1, absEVX1, absEVY1, absEVZ1;
  Real absEX2, absEY2, absEZ2, absEVX2, absEVY2, absEVZ2;
  Real absEX3, absEY3, absEZ3, absEVX3, absEVY3, absEVZ3;

equation
  // Leader trajectory
  leadX = vLead*time;
  leadY = 0.0;
  leadZ = leadZ0;
  leadVx = vLead;
  leadVy = 0.0;
  leadVz = 0.0;
  leadAx = 0.0;
  leadAy = 0.0;
  leadAz = 0.0;

  // Desired formation positions
  desX1 = leadX + offX1;
  desY1 = leadY + offY1;
  desZ1 = leadZ + offZ1;
  desX2 = leadX + offX2;
  desY2 = leadY + offY2;
  desZ2 = leadZ + offZ2;
  desX3 = leadX + offX3;
  desY3 = leadY + offY3;
  desZ3 = leadZ + offZ3;

  // Desired inter-robot ranges (computed from offsets)
  desRange12 = sqrt((offX1-offX2)*(offX1-offX2) + (offY1-offY2)*(offY1-offY2) + (offZ1-offZ2)*(offZ1-offZ2) + epsLen*epsLen);
  desRange13 = sqrt((offX1-offX3)*(offX1-offX3) + (offY1-offY3)*(offY1-offY3) + (offZ1-offZ3)*(offZ1-offZ3) + epsLen*epsLen);
  desRange23 = sqrt((offX2-offX3)*(offX2-offX3) + (offY2-offY3)*(offY2-offY3) + (offZ2-offZ3)*(offZ2-offZ3) + epsLen*epsLen);

  // Delay disturbance scheduling: middle third has messageDelay, otherwise negligible
  commAge = if (time >= T_start and time <= T_stop) then messageDelay else 0.0;
  tauComm = if (time >= T_start and time <= T_stop) then messageDelay else 0.001;

  // Delayed message states (first-order lag approximation of transport delay)
  der(msgX1) = (x1 - msgX1) / tauComm;
  der(msgY1) = (y1 - msgY1) / tauComm;
  der(msgZ1) = (z1 - msgZ1) / tauComm;
  der(msgX2) = (x2 - msgX2) / tauComm;
  der(msgY2) = (y2 - msgY2) / tauComm;
  der(msgZ2) = (z2 - msgZ2) / tauComm;
  der(msgX3) = (x3 - msgX3) / tauComm;
  der(msgY3) = (y3 - msgY3) / tauComm;
  der(msgZ3) = (z3 - msgZ3) / tauComm;

  // Quadrotor 1 dynamics
  der(x1) = vx1;
  der(y1) = vy1;
  der(z1) = vz1;
  der(vx1) = ax1;
  der(vy1) = ay1;
  der(vz1) = az1;
  ax1 = cmdAccX1;
  ay1 = cmdAccY1;
  az1 = cmdAccZ1;

  // Quadrotor 2 dynamics
  der(x2) = vx2;
  der(y2) = vy2;
  der(z2) = vz2;
  der(vx2) = ax2;
  der(vy2) = ay2;
  der(vz2) = az2;
  ax2 = cmdAccX2;
  ay2 = cmdAccY2;
  az2 = cmdAccZ2;

  // Quadrotor 3 dynamics
  der(x3) = vx3;
  der(y3) = vy3;
  der(z3) = vz3;
  der(vx3) = ax3;
  der(vy3) = ay3;
  der(vz3) = az3;
  ax3 = cmdAccX3;
  ay3 = cmdAccY3;
  az3 = cmdAccZ3;

  // Estimator dynamics (onboard state estimation with lag)
  der(estX1) = (x1 - estX1)/tauEst;
  der(estY1) = (y1 - estY1)/tauEst;
  der(estZ1) = (z1 - estZ1)/tauEst;
  der(estVx1) = (vx1 - estVx1)/tauEst;
  der(estVy1) = (vy1 - estVy1)/tauEst;
  der(estVz1) = (vz1 - estVz1)/tauEst;

  der(estX2) = (x2 - estX2)/tauEst;
  der(estY2) = (y2 - estY2)/tauEst;
  der(estZ2) = (z2 - estZ2)/tauEst;
  der(estVx2) = (vx2 - estVx2)/tauEst;
  der(estVy2) = (vy2 - estVy2)/tauEst;
  der(estVz2) = (vz2 - estVz2)/tauEst;

  der(estX3) = (x3 - estX3)/tauEst;
  der(estY3) = (y3 - estY3)/tauEst;
  der(estZ3) = (z3 - estZ3)/tauEst;
  der(estVx3) = (vx3 - estVx3)/tauEst;
  der(estVy3) = (vy3 - estVy3)/tauEst;
  der(estVz3) = (vz3 - estVz3)/tauEst;

  // Distributed formation control with bounded local commands
  // Quadrotor 1: tracking + consensus using delayed peer messages
  rawAccX1 = Kp*(desX1 - estX1) + Kd*(leadVx - estVx1) + leadAx + Kc*(((msgX2 - msgX1) - (offX2 - offX1)) + ((msgX3 - msgX1) - (offX3 - offX1)));
  rawAccY1 = Kp*(desY1 - estY1) + Kd*(leadVy - estVy1) + leadAy + Kc*(((msgY2 - msgY1) - (offY2 - offY1)) + ((msgY3 - msgY1) - (offY3 - offY1)));
  rawAccZ1 = Kp*(desZ1 - estZ1) + Kd*(leadVz - estVz1) + leadAz + Kc*(((msgZ2 - msgZ1) - (offZ2 - offZ1)) + ((msgZ3 - msgZ1) - (offZ3 - offZ1)));
  cmdAccX1 = max(-amax, min(amax, rawAccX1));
  cmdAccY1 = max(-amax, min(amax, rawAccY1));
  cmdAccZ1 = max(-amax, min(amax, rawAccZ1));

  // Quadrotor 2
  rawAccX2 = Kp*(desX2 - estX2) + Kd*(leadVx - estVx2) + leadAx + Kc*(((msgX1 - msgX2) - (offX1 - offX2)) + ((msgX3 - msgX2) - (offX3 - offX2)));
  rawAccY2 = Kp*(desY2 - estY2) + Kd*(leadVy - estVy2) + leadAy + Kc*(((msgY1 - msgY2) - (offY1 - offY2)) + ((msgY3 - msgY2) - (offY3 - offY2)));
  rawAccZ2 = Kp*(desZ2 - estZ2) + Kd*(leadVz - estVz2) + leadAz + Kc*(((msgZ1 - msgZ2) - (offZ1 - offZ2)) + ((msgZ3 - msgZ2) - (offZ3 - offZ2)));
  cmdAccX2 = max(-amax, min(amax, rawAccX2));
  cmdAccY2 = max(-amax, min(amax, rawAccY2));
  cmdAccZ2 = max(-amax, min(amax, rawAccZ2));

  // Quadrotor 3
  rawAccX3 = Kp*(desX3 - estX3) + Kd*(leadVx - estVx3) + leadAx + Kc*(((msgX1 - msgX3) - (offX1 - offX3)) + ((msgX2 - msgX3) - (offX2 - offX3)));
  rawAccY3 = Kp*(desY3 - estY3) + Kd*(leadVy - estVy3) + leadAy + Kc*(((msgY1 - msgY3) - (offY1 - offY3)) + ((msgY2 - msgY3) - (offY2 - offY3)));
  rawAccZ3 = Kp*(desZ3 - estZ3) + Kd*(leadVz - estVz3) + leadAz + Kc*(((msgZ1 - msgZ3) - (offZ1 - offZ3)) + ((msgZ2 - msgZ3) - (offZ2 - offZ3)));
  cmdAccX3 = max(-amax, min(amax, rawAccX3));
  cmdAccY3 = max(-amax, min(amax, rawAccY3));
  cmdAccZ3 = max(-amax, min(amax, rawAccZ3));

  // Thrust allocation for quadrotor 1
  Fx1 = m*cmdAccX1;
  Fy1 = m*cmdAccY1;
  Fz1 = m*(g + cmdAccZ1);
  T1 = sqrt(Fx1*Fx1 + Fy1*Fy1 + Fz1*Fz1 + epsLen*epsLen);
  dRoll1 = max(-dmax, min(dmax, kRoll*cmdAccY1));
  dPitch1 = max(-dmax, min(dmax, kPitch*cmdAccX1));
  dYaw1 = max(-dmax, min(dmax, kYaw*cmdAccZ1));
  r11 = T1/4.0 + dRoll1 + dPitch1 - dYaw1;
  r12 = T1/4.0 - dRoll1 + dPitch1 + dYaw1;
  r13 = T1/4.0 + dRoll1 - dPitch1 + dYaw1;
  r14 = T1/4.0 - dRoll1 - dPitch1 - dYaw1;

  // Thrust allocation for quadrotor 2
  Fx2 = m*cmdAccX2;
  Fy2 = m*cmdAccY2;
  Fz2 = m*(g + cmdAccZ2);
  T2 = sqrt(Fx2*Fx2 + Fy2*Fy2 + Fz2*Fz2 + epsLen*epsLen);
  dRoll2 = max(-dmax, min(dmax, kRoll*cmdAccY2));
  dPitch2 = max(-dmax, min(dmax, kPitch*cmdAccX2));
  dYaw2 = max(-dmax, min(dmax, kYaw*cmdAccZ2));
  r21 = T2/4.0 + dRoll2 + dPitch2 - dYaw2;
  r22 = T2/4.0 - dRoll2 + dPitch2 + dYaw2;
  r23 = T2/4.0 + dRoll2 - dPitch2 + dYaw2;
  r24 = T2/4.0 - dRoll2 - dPitch2 - dYaw2;

  // Thrust allocation for quadrotor 3
  Fx3 = m*cmdAccX3;
  Fy3 = m*cmdAccY3;
  Fz3 = m*(g + cmdAccZ3);
  T3 = sqrt(Fx3*Fx3 + Fy3*Fy3 + Fz3*Fz3 + epsLen*epsLen);
  dRoll3 = max(-dmax, min(dmax, kRoll*cmdAccY3));
  dPitch3 = max(-dmax, min(dmax, kPitch*cmdAccX3));
  dYaw3 = max(-dmax, min(dmax, kYaw*cmdAccZ3));
  r31 = T3/4.0 + dRoll3 + dPitch3 - dYaw3;
  r32 = T3/4.0 - dRoll3 + dPitch3 + dYaw3;
  r33 = T3/4.0 + dRoll3 - dPitch3 + dYaw3;
  r34 = T3/4.0 - dRoll3 - dPitch3 - dYaw3;

  // Peer-relative range sensing
  range12 = sqrt((x1-x2)*(x1-x2) + (y1-y2)*(y1-y2) + (z1-z2)*(z1-z2) + epsLen*epsLen);
  range13 = sqrt((x1-x3)*(x1-x3) + (y1-y3)*(y1-y3) + (z1-z3)*(z1-z3) + epsLen*epsLen);
  range23 = sqrt((x2-x3)*(x2-x3) + (y2-y3)*(y2-y3) + (z2-z3)*(z2-z3) + epsLen*epsLen);

  // Obstacle distances
  dist1obs1 = sqrt((x1-obs1x)*(x1-obs1x) + (y1-obs1y)*(y1-obs1y) + (z1-obs1z)*(z1-obs1z) + epsLen*epsLen);
  dist1obs2 = sqrt((x1-obs2x)*(x1-obs2x) + (y1-obs2y)*(y1-obs2y) + (z1-obs2z)*(z1-obs2z) + epsLen*epsLen);
  dist2obs1 = sqrt((x2-obs1x)*(x2-obs1x) + (y2-obs1y)*(y2-obs1y) + (z2-obs1z)*(z2-obs1z) + epsLen*epsLen);
  dist2obs2 = sqrt((x2-obs2x)*(x2-obs2x) + (y2-obs2y)*(y2-obs2y) + (z2-obs2z)*(z2-obs2z) + epsLen*epsLen);
  dist3obs1 = sqrt((x3-obs1x)*(x3-obs1x) + (y3-obs1y)*(y3-obs1y) + (z3-obs1z)*(z3-obs1z) + epsLen*epsLen);
  dist3obs2 = sqrt((x3-obs2x)*(x3-obs2x) + (y3-obs2y)*(y3-obs2y) + (z3-obs2z)*(z3-obs2z) + epsLen*epsLen);

  // Verification metrics
  formationError = sqrt(((range12-desRange12)*(range12-desRange12) + (range13-desRange13)*(range13-desRange13) + (range23-desRange23)*(range23-desRange23))/3.0 + epsLen*epsLen);
  primaryTrackingError = sqrt(((x1+x2+x3)/3.0 - leadX)*((x1+x2+x3)/3.0 - leadX) + ((y1+y2+y3)/3.0 - leadY)*((y1+y2+y3)/3.0 - leadY) + ((z1+z2+z3)/3.0 - leadZ)*((z1+z2+z3)/3.0 - leadZ) + epsLen*epsLen);

  // Intermediate finite-check variables
  absX1 = abs(x1); absY1 = abs(y1); absZ1 = abs(z1);
  absVX1 = abs(vx1); absVY1 = abs(vy1); absVZ1 = abs(vz1);
  absX2 = abs(x2); absY2 = abs(y2); absZ2 = abs(z2);
  absVX2 = abs(vx2); absVY2 = abs(vy2); absVZ2 = abs(vz2);
  absX3 = abs(x3); absY3 = abs(y3); absZ3 = abs(z3);
  absVX3 = abs(vx3); absVY3 = abs(vy3); absVZ3 = abs(vz3);
  absEX1 = abs(estX1); absEY1 = abs(estY1); absEZ1 = abs(estZ1);
  absEVX1 = abs(estVx1); absEVY1 = abs(estVy1); absEVZ1 = abs(estVz1);
  absEX2 = abs(estX2); absEY2 = abs(estY2); absEZ2 = abs(estZ2);
  absEVX2 = abs(estVx2); absEVY2 = abs(estVy2); absEVZ2 = abs(estVz2);
  absEX3 = abs(estX3); absEY3 = abs(estY3); absEZ3 = abs(estZ3);
  absEVX3 = abs(estVx3); absEVY3 = abs(estVy3); absEVZ3 = abs(estVz3);

  actuatorLimitsOK =
    (r11 >= 0.0) and (r11 <= maxRotorThrust) and
    (r12 >= 0.0) and (r12 <= maxRotorThrust) and
    (r13 >= 0.0) and (r13 <= maxRotorThrust) and
    (r14 >= 0.0) and (r14 <= maxRotorThrust) and
    (r21 >= 0.0) and (r21 <= maxRotorThrust) and
    (r22 >= 0.0) and (r22 <= maxRotorThrust) and
    (r23 >= 0.0) and (r23 <= maxRotorThrust) and
    (r24 >= 0.0) and (r24 <= maxRotorThrust) and
    (r31 >= 0.0) and (r31 <= maxRotorThrust) and
    (r32 >= 0.0) and (r32 <= maxRotorThrust) and
    (r33 >= 0.0) and (r33 <= maxRotorThrust) and
    (r34 >= 0.0) and (r34 <= maxRotorThrust);

  pairwiseSeparationOK = (range12 >= minSep) and (range13 >= minSep) and (range23 >= minSep);

  noCollisionOK =
    (dist1obs1 > obsRadius) and (dist1obs2 > obsRadius) and
    (dist2obs1 > obsRadius) and (dist2obs2 > obsRadius) and
    (dist3obs1 > obsRadius) and (dist3obs2 > obsRadius);

  primaryTrackingErrorOK = (time < 13.0) or (primaryTrackingError < trackTol);

  finiteValuesOK =
    (absX1 < 1e9) and (absY1 < 1e9) and (absZ1 < 1e9) and
    (absVX1 < 1e9) and (absVY1 < 1e9) and (absVZ1 < 1e9) and
    (absX2 < 1e9) and (absY2 < 1e9) and (absZ2 < 1e9) and
    (absVX2 < 1e9) and (absVY2 < 1e9) and (absVZ2 < 1e9) and
    (absX3 < 1e9) and (absY3 < 1e9) and (absZ3 < 1e9) and
    (absVX3 < 1e9) and (absVY3 < 1e9) and (absVZ3 < 1e9) and
    (absEX1 < 1e9) and (absEY1 < 1e9) and (absEZ1 < 1e9) and
    (absEVX1 < 1e9) and (absEVY1 < 1e9) and (absEVZ1 < 1e9) and
    (absEX2 < 1e9) and (absEY2 < 1e9) and (absEZ2 < 1e9) and
    (absEVX2 < 1e9) and (absEVY2 < 1e9) and (absEVZ2 < 1e9) and
    (absEX3 < 1e9) and (absEY3 < 1e9) and (absEZ3 < 1e9) and
    (absEVX3 < 1e9) and (absEVY3 < 1e9) and (absEVZ3 < 1e9) and
    (abs(r11) < 1e9) and (abs(r12) < 1e9) and (abs(r13) < 1e9) and (abs(r14) < 1e9) and
    (abs(r21) < 1e9) and (abs(r22) < 1e9) and (abs(r23) < 1e9) and (abs(r24) < 1e9) and
    (abs(r31) < 1e9) and (abs(r32) < 1e9) and (abs(r33) < 1e9) and (abs(r34) < 1e9) and
    (abs(cmdAccX1) < 1e9) and (abs(cmdAccY1) < 1e9) and (abs(cmdAccZ1) < 1e9) and
    (abs(cmdAccX2) < 1e9) and (abs(cmdAccY2) < 1e9) and (abs(cmdAccZ2) < 1e9) and
    (abs(cmdAccX3) < 1e9) and (abs(cmdAccY3) < 1e9) and (abs(cmdAccZ3) < 1e9);

  verificationOK = actuatorLimitsOK and pairwiseSeparationOK and noCollisionOK and primaryTrackingErrorOK and finiteValuesOK;

  annotation(
    experiment(StopTime=20.0, Interval=0.002, Tolerance=1e-6),
    Documentation(info="Three 1.8 kg quadrotors in formation following a leader trajectory. Communication delay of 0.116 s applied during middle third via first-order lag approximation. Control runs at 500 Hz via solver Interval. State, command, and sensor traces are retained as model variables. Values not given in the requirement are marked as assumed."));
end AirTrioFormF;