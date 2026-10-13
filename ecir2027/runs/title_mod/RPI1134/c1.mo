model AirTrioFormF
  "Three quadrotors maintaining formation with bounded commands and mid-mission delay"

  // ----- Given numeric facts -----
  parameter Real m(unit="kg") = 1.8 "quadrotor mass";
  parameter Real maxRotorThrust(unit="N") = 14.6 "per-rotor actuator limit";
  parameter Real messageDelay(unit="s") = 0.116 "controlled delay disturbance";
  parameter Real sampleRate(unit="Hz") = 500.0 "control/update rate";
  parameter Real Ts(unit="s") = 1.0 / sampleRate "sample interval";
  parameter Real T_end(unit="s") = 20.0 "mission duration";
  parameter Real T_start(unit="s") = T_end / 3.0 "middle third start";
  parameter Real T_stop(unit="s") = 2.0 * T_end / 3.0 "middle third stop";
  parameter Real trackTol(unit="m") = 0.24 "primary tracking error threshold after 13 s";

  // ----- Assumed design/mission values (not specified in requirement) -----
  parameter Real vLead(unit="m/s") = 0.2 "assumed leader speed";
  parameter Real leadZ0(unit="m") = 2.0 "assumed leader altitude";
  parameter Real offX1(unit="m") = 0.0 "assumed formation offset";
  parameter Real offY1(unit="m") = 0.6 "assumed formation offset";
  parameter Real offZ1(unit="m") = 0.0 "assumed formation offset";
  parameter Real offX2(unit="m") = -0.5 "assumed formation offset";
  parameter Real offY2(unit="m") = -0.3 "assumed formation offset";
  parameter Real offZ2(unit="m") = 0.0 "assumed formation offset";
  parameter Real offX3(unit="m") = 0.5 "assumed formation offset";
  parameter Real offY3(unit="m") = -0.3 "assumed formation offset";
  parameter Real offZ3(unit="m") = 0.0 "assumed formation offset";
  parameter Real minSep(unit="m") = 0.5 "assumed minimum pairwise separation";
  parameter Real obs1x(unit="m") = 10.0 "assumed obstacle position";
  parameter Real obs1y(unit="m") = 5.0 "assumed obstacle position";
  parameter Real obs1z(unit="m") = 2.0 "assumed obstacle position";
  parameter Real obs2x(unit="m") = -10.0 "assumed obstacle position";
  parameter Real obs2y(unit="m") = -5.0 "assumed obstacle position";
  parameter Real obs2z(unit="m") = 2.0 "assumed obstacle position";
  parameter Real obsRadius(unit="m") = 1.0 "assumed obstacle safety radius";
  parameter Real amax(unit="m/s2") = 5.0 "assumed bounded local command magnitude";
  parameter Real Kp = 10.0 "assumed position gain";
  parameter Real Kd = 5.0 "assumed velocity gain";
  parameter Real Kc = 0.5 "assumed consensus gain";
  parameter Real tauEst(unit="s") = 0.02 "assumed estimator lag";
  parameter Real dmax(unit="N") = 1.0 "assumed differential thrust bound";
  parameter Real kRoll = 0.2 "assumed roll-thrust allocation gain";
  parameter Real kPitch = 0.2 "assumed pitch-thrust allocation gain";
  parameter Real kYaw = 0.2 "assumed yaw-thrust allocation gain";

  // Derived desired ranges
  parameter Real desRange12(unit="m") = sqrt((offX1 - offX2) * (offX1 - offX2) + (offY1 - offY2) * (offY1 - offY2) + (offZ1 - offZ2) * (offZ1 - offZ2));
  parameter Real desRange13(unit="m") = sqrt((offX1 - offX3) * (offX1 - offX3) + (offY1 - offY3) * (offY1 - offY3) + (offZ1 - offZ3) * (offZ1 - offZ3));
  parameter Real desRange23(unit="m") = sqrt((offX2 - offX3) * (offX2 - offX3) + (offY2 - offY3) * (offY2 - offY3) + (offZ2 - offZ3) * (offZ2 - offZ3));

  // Gravity
  constant Real g(unit="m/s2") = 9.80665;

  // ----- Leader trajectory -----
  Real leadX(unit="m"), leadY(unit="m"), leadZ(unit="m");
  Real leadVx(unit="m/s"), leadVy(unit="m/s"), leadVz(unit="m/s");

  // ----- Quadrotor 1 states -----
  Real x1(unit="m", start=offX1, fixed=true);
  Real y1(unit="m", start=offY1, fixed=true);
  Real z1(unit="m", start=leadZ0, fixed=true);
  Real vx1(unit="m/s", start=0.0, fixed=true);
  Real vy1(unit="m/s", start=0.0, fixed=true);
  Real vz1(unit="m/s", start=0.0, fixed=true);

  // ----- Quadrotor 2 states -----
  Real x2(unit="m", start=offX2, fixed=true);
  Real y2(unit="m", start=offY2, fixed=true);
  Real z2(unit="m", start=leadZ0, fixed=true);
  Real vx2(unit="m/s", start=0.0, fixed=true);
  Real vy2(unit="m/s", start=0.0, fixed=true);
  Real vz2(unit="m/s", start=0.0, fixed=true);

  // ----- Quadrotor 3 states -----
  Real x3(unit="m", start=offX3, fixed=true);
  Real y3(unit="m", start=offY3, fixed=true);
  Real z3(unit="m", start=leadZ0, fixed=true);
  Real vx3(unit="m/s", start=0.0, fixed=true);
  Real vy3(unit="m/s", start=0.0, fixed=true);
  Real vz3(unit="m/s", start=0.0, fixed=true);

  // ----- Estimator states -----
  Real estX1(unit="m", start=offX1, fixed=true);
  Real estY1(unit="m", start=offY1, fixed=true);
  Real estZ1(unit="m", start=leadZ0, fixed=true);
  Real estVx1(unit="m/s", start=0.0, fixed=true);
  Real estVy1(unit="m/s", start=0.0, fixed=true);
  Real estVz1(unit="m/s", start=0.0, fixed=true);

  Real estX2(unit="m", start=offX2, fixed=true);
  Real estY2(unit="m", start=offY2, fixed=true);
  Real estZ2(unit="m", start=leadZ0, fixed=true);
  Real estVx2(unit="m/s", start=0.0, fixed=true);
  Real estVy2(unit="m/s", start=0.0, fixed=true);
  Real estVz2(unit="m/s", start=0.0, fixed=true);

  Real estX3(unit="m", start=offX3, fixed=true);
  Real estY3(unit="m", start=offY3, fixed=true);
  Real estZ3(unit="m", start=leadZ0, fixed=true);
  Real estVx3(unit="m/s", start=0.0, fixed=true);
  Real estVy3(unit="m/s", start=0.0, fixed=true);
  Real estVz3(unit="m/s", start=0.0, fixed=true);

  // ----- Delayed (lagged) message states -----
  Real lagX1(unit="m", start=offX1, fixed=true);
  Real lagY1(unit="m", start=offY1, fixed=true);
  Real lagZ1(unit="m", start=leadZ0, fixed=true);
  Real lagX2(unit="m", start=offX2, fixed=true);
  Real lagY2(unit="m", start=offY2, fixed=true);
  Real lagZ2(unit="m", start=leadZ0, fixed=true);
  Real lagX3(unit="m", start=offX3, fixed=true);
  Real lagY3(unit="m", start=offY3, fixed=true);
  Real lagZ3(unit="m", start=leadZ0, fixed=true);

  // ----- Delay scheduling -----
  Real delayTau(unit="s");
  Real commAge(unit="s");
  // msgX etc are the received (possibly delayed) peer positions
  Real msgX1(unit="m"), msgY1(unit="m"), msgZ1(unit="m");
  Real msgX2(unit="m"), msgY2(unit="m"), msgZ2(unit="m");
  Real msgX3(unit="m"), msgY3(unit="m"), msgZ3(unit="m");

  // ----- Desired positions -----
  Real desX1(unit="m"), desY1(unit="m"), desZ1(unit="m");
  Real desX2(unit="m"), desY2(unit="m"), desZ2(unit="m");
  Real desX3(unit="m"), desY3(unit="m"), desZ3(unit="m");

  // ----- Raw and bounded commands -----
  Real rawAccX1(unit="m/s2"), rawAccY1(unit="m/s2"), rawAccZ1(unit="m/s2");
  Real rawAccX2(unit="m/s2"), rawAccY2(unit="m/s2"), rawAccZ2(unit="m/s2");
  Real rawAccX3(unit="m/s2"), rawAccY3(unit="m/s2"), rawAccZ3(unit="m/s2");

  Real cmdAccX1(unit="m/s2"), cmdAccY1(unit="m/s2"), cmdAccZ1(unit="m/s2");
  Real cmdAccX2(unit="m/s2"), cmdAccY2(unit="m/s2"), cmdAccZ2(unit="m/s2");
  Real cmdAccX3(unit="m/s2"), cmdAccY3(unit="m/s2"), cmdAccZ3(unit="m/s2");

  // ----- Rotor thrust groups (12 independent) -----
  Real Fz1(unit="N"), Fz2(unit="N"), Fz3(unit="N");
  Real T1(unit="N"), T2(unit="N"), T3(unit="N");
  Real dRoll1(unit="N"), dPitch1(unit="N"), dYaw1(unit="N");
  Real dRoll2(unit="N"), dPitch2(unit="N"), dYaw2(unit="N");
  Real dRoll3(unit="N"), dPitch3(unit="N"), dYaw3(unit="N");
  Real r11(unit="N"), r12(unit="N"), r13(unit="N"), r14(unit="N");
  Real r21(unit="N"), r22(unit="N"), r23(unit="N"), r24(unit="N");
  Real r31(unit="N"), r32(unit="N"), r33(unit="N"), r34(unit="N");

  // ----- Peer-relative range sensors -----
  Real range12(unit="m"), range13(unit="m"), range23(unit="m");

  // ----- Obstacle distances -----
  Real dist1obs1(unit="m"), dist1obs2(unit="m");
  Real dist2obs1(unit="m"), dist2obs2(unit="m");
  Real dist3obs1(unit="m"), dist3obs2(unit="m");

  // ----- Verification metrics -----
  Real formationError(unit="m");
  Real primaryTrackingError(unit="m");
  Boolean actuatorLimitsOK;
  Boolean pairwiseSeparationOK;
  Boolean noCollisionOK;
  Boolean primaryTrackingErrorOK;
  Boolean finiteValuesOK;
  Boolean verificationOK;

  // Helpers for saturation
  Real rawCmd, boundedCmd;

equation
  // ===== Leader trajectory =====
  leadX = vLead * time;
  leadY = 0.0;
  leadZ = leadZ0;
  leadVx = vLead;
  leadVy = 0.0;
  leadVz = 0.0;

  // ===== Desired formation positions =====
  desX1 = leadX + offX1;
  desY1 = leadY + offY1;
  desZ1 = leadZ + offZ1;
  desX2 = leadX + offX2;
  desY2 = leadY + offY2;
  desZ2 = leadZ + offZ2;
  desX3 = leadX + offX3;
  desY3 = leadY + offY3;
  desZ3 = leadZ + offZ3;

  // ===== Delay scheduling =====
  // When in the middle third, communication experiences 0.116 s lag
  // modeled as a first-order lag with tau = messageDelay
  delayTau = if (time >= T_start and time <= T_stop) then messageDelay else 0.001;

  // Lagged peer position states (first-order transport approximation)
  der(lagX1) = (x1 - lagX1) / delayTau;
  der(lagY1) = (y1 - lagY1) / delayTau;
  der(lagZ1) = (z1 - lagZ1) / delayTau;
  der(lagX2) = (x2 - lagX2) / delayTau;
  der(lagY2) = (y2 - lagY2) / delayTau;
  der(lagZ2) = (z2 - lagZ2) / delayTau;
  der(lagX3) = (x3 - lagX3) / delayTau;
  der(lagY3) = (y3 - lagY3) / delayTau;
  der(lagZ3) = (z3 - lagZ3) / delayTau;

  // Messages received: delayed during middle third, direct otherwise
  msgX1 = if (time >= T_start and time <= T_stop) then lagX1 else x1;
  msgY1 = if (time >= T_start and time <= T_stop) then lagY1 else y1;
  msgZ1 = if (time >= T_start and time <= T_stop) then lagZ1 else z1;
  msgX2 = if (time >= T_start and time <= T_stop) then lagX2 else x2;
  msgY2 = if (time >= T_start and time <= T_stop) then lagY2 else y2;
  msgZ2 = if (time >= T_start and time <= T_stop) then lagZ2 else z2;
  msgX3 = if (time >= T_start and time <= T_stop) then lagX3 else x3;
  msgY3 = if (time >= T_start and time <= T_stop) then lagY3 else y3;
  msgZ3 = if (time >= T_start and time <= T_stop) then lagZ3 else z3;

  commAge = if (time >= T_start and time <= T_stop) then messageDelay else 0.0;

  // ===== Quadrotor dynamics =====
  // Robot 1
  der(x1) = vx1;
  der(y1) = vy1;
  der(z1) = vz1;
  der(vx1) = cmdAccX1;
  der(vy1) = cmdAccY1;
  der(vz1) = cmdAccZ1;

  // Robot 2
  der(x2) = vx2;
  der(y2) = vy2;
  der(z2) = vz2;
  der(vx2) = cmdAccX2;
  der(vy2) = cmdAccY2;
  der(vz2) = cmdAccZ2;

  // Robot 3
  der(x3) = vx3;
  der(y3) = vy3;
  der(z3) = vz3;
  der(vx3) = cmdAccX3;
  der(vy3) = cmdAccY3;
  der(vz3) = cmdAccZ3;

  // ===== Estimator dynamics (first-order filter) =====
  der(estX1) = (x1 - estX1) / tauEst;
  der(estY1) = (y1 - estY1) / tauEst;
  der(estZ1) = (z1 - estZ1) / tauEst;
  der(estVx1) = (vx1 - estVx1) / tauEst;
  der(estVy1) = (vy1 - estVy1) / tauEst;
  der(estVz1) = (vz1 - estVz1) / tauEst;

  der(estX2) = (x2 - estX2) / tauEst;
  der(estY2) = (y2 - estY2) / tauEst;
  der(estZ2) = (z2 - estZ2) / tauEst;
  der(estVx2) = (vx2 - estVx2) / tauEst;
  der(estVy2) = (vy2 - estVy2) / tauEst;
  der(estVz2) = (vz2 - estVz2) / tauEst;

  der(estX3) = (x3 - estX3) / tauEst;
  der(estY3) = (y3 - estY3) / tauEst;
  der(estZ3) = (z3 - estZ3) / tauEst;
  der(estVx3) = (vx3 - estVx3) / tauEst;
  der(estVy3) = (vy3 - estVy3) / tauEst;
  der(estVz3) = (vz3 - estVz3) / tauEst;

  // ===== Distributed formation control (continuous, bounded) =====
  // Robot 1 raw command
  rawAccX1 = Kp * (desX1 - estX1) + Kd * (leadVx - estVx1) + Kc * (((msgX2 - msgX1) - (offX1 - offX2)) + ((msgX3 - msgX1) - (offX1 - offX3)));
  rawAccY1 = Kp * (desY1 - estY1) + Kd * (leadVy - estVy1) + Kc * (((msgY2 - msgY1) - (offY1 - offY2)) + ((msgY3 - msgY1) - (offY1 - offY3)));
  rawAccZ1 = Kp * (desZ1 - estZ1) + Kd * (leadVz - estVz1) + Kc * (((msgZ2 - msgZ1) - (offZ1 - offZ2)) + ((msgZ3 - msgZ1) - (offZ1 - offZ3)));

  // Robot 2 raw command
  rawAccX2 = Kp * (desX2 - estX2) + Kd * (leadVx - estVx2) + Kc * (((msgX1 - msgX2) - (offX2 - offX1)) + ((msgX3 - msgX2) - (offX2 - offX3)));
  rawAccY2 = Kp * (desY2 - estY2) + Kd * (leadVy - estVy2) + Kc * (((msgY1 - msgY2) - (offY2 - offY1)) + ((msgY3 - msgY2) - (offY2 - offY3)));
  rawAccZ2 = Kp * (desZ2 - estZ2) + Kd * (leadVz - estVz2) + Kc * (((msgZ1 - msgZ2) - (offZ2 - offZ1)) + ((msgZ3 - msgZ2) - (offZ2 - offZ3)));

  // Robot 3 raw command
  rawAccX3 = Kp * (desX3 - estX3) + Kd * (leadVx - estVx3) + Kc * (((msgX1 - msgX3) - (offX3 - offX1)) + ((msgX2 - msgX3) - (offX3 - offX2)));
  rawAccY3 = Kp * (desY3 - estY3) + Kd * (leadVy - estVy3) + Kc * (((msgY1 - msgY3) - (offY3 - offY1)) + ((msgY2 - msgY3) - (offY3 - offY2)));
  rawAccZ3 = Kp * (desZ3 - estZ3) + Kd * (leadVz - estVz3) + Kc * (((msgZ1 - msgZ3) - (offZ3 - offZ1)) + ((msgZ2 - msgZ3) - (offZ3 - offZ2)));

  // Bounded local commands using if-then-else saturation
  cmdAccX1 = if rawAccX1 > amax then amax else if rawAccX1 < -amax then -amax else rawAccX1;
  cmdAccY1 = if rawAccY1 > amax then amax else if rawAccY1 < -amax then -amax else rawAccY1;
  cmdAccZ1 = if rawAccZ1 > amax then amax else if rawAccZ1 < -amax then -amax else rawAccZ1;

  cmdAccX2 = if rawAccX2 > amax then amax else if rawAccX2 < -amax then -amax else rawAccX2;
  cmdAccY2 = if rawAccY2 > amax then amax else if rawAccY2 < -amax then -amax else rawAccY2;
  cmdAccZ2 = if rawAccZ2 > amax then amax else if rawAccZ2 < -amax then -amax else rawAccZ2;

  cmdAccX3 = if rawAccX3 > amax then amax else if rawAccX3 < -amax then -amax else rawAccX3;
  cmdAccY3 = if rawAccY3 > amax then amax else if rawAccY3 < -amax then -amax else rawAccY3;
  cmdAccZ3 = if rawAccZ3 > amax then amax else if rawAccZ3 < -amax then -amax else rawAccZ3;

  // ===== Thrust allocation =====
  // Robot 1
  Fz1 = m * (g + cmdAccZ1);
  T1 = Fz1;
  dRoll1 = if (kRoll * cmdAccY1 > dmax) then dmax else if (kRoll * cmdAccY1 < -dmax) then -dmax else kRoll * cmdAccY1;
  dPitch1 = if (kPitch * cmdAccX1 > dmax) then dmax else if (kPitch * cmdAccX1 < -dmax) then -dmax else kPitch * cmdAccX1;
  dYaw1 = if (kYaw * cmdAccZ1 > dmax) then dmax else if (kYaw * cmdAccZ1 < -dmax) then -dmax else kYaw * cmdAccZ1;
  r11 = T1 / 4.0 + dRoll1 + dPitch1 - dYaw1;
  r12 = T1 / 4.0 - dRoll1 + dPitch1 + dYaw1;
  r13 = T1 / 4.0 + dRoll1 - dPitch1 + dYaw1;
  r14 = T1 / 4.0 - dRoll1 - dPitch1 - dYaw1;

  // Robot 2
  Fz2 = m * (g + cmdAccZ2);
  T2 = Fz2;
  dRoll2 = if (kRoll * cmdAccY2 > dmax) then dmax else if (kRoll * cmdAccY2 < -dmax) then -dmax else kRoll * cmdAccY2;
  dPitch2 = if (kPitch * cmdAccX2 > dmax) then dmax else if (kPitch * cmdAccX2 < -dmax) then -dmax else kPitch * cmdAccX2;
  dYaw2 = if (kYaw * cmdAccZ2 > dmax) then dmax else if (kYaw * cmdAccZ2 < -dmax) then -dmax else kYaw * cmdAccZ2;
  r21 = T2 / 4.0 + dRoll2 + dPitch2 - dYaw2;
  r22 = T2 / 4.0 - dRoll2 + dPitch2 + dYaw2;
  r23 = T2 / 4.0 + dRoll2 - dPitch2 + dYaw2;
  r24 = T2 / 4.0 - dRoll2 - dPitch2 - dYaw2;

  // Robot 3
  Fz3 = m * (g + cmdAccZ3);
  T3 = Fz3;
  dRoll3 = if (kRoll * cmdAccY3 > dmax) then dmax else if (kRoll * cmdAccY3 < -dmax) then -dmax else kRoll * cmdAccY3;
  dPitch3 = if (kPitch * cmdAccX3 > dmax) then dmax else if (kPitch * cmdAccX3 < -dmax) then -dmax else kPitch * cmdAccX3;
  dYaw3 = if (kYaw * cmdAccZ3 > dmax) then dmax else if (kYaw * cmdAccZ3 < -dmax) then -dmax else kYaw * cmdAccZ3;
  r31 = T3 / 4.0 + dRoll3 + dPitch3 - dYaw3;
  r32 = T3 / 4.0 - dRoll3 + dPitch3 + dYaw3;
  r33 = T3 / 4.0 + dRoll3 - dPitch3 + dYaw3;
  r34 = T3 / 4.0 - dRoll3 - dPitch3 - dYaw3;

  // ===== Peer-relative range sensing =====
  range12 = sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2) + (z1 - z2) * (z1 - z2));
  range13 = sqrt((x1 - x3) * (x1 - x3) + (y1 - y3) * (y1 - y3) + (z1 - z3) * (z1 - z3));
  range23 = sqrt((x2 - x3) * (x2 - x3) + (y2 - y3) * (y2 - y3) + (z2 - z3) * (z2 - z3));

  // ===== Obstacle distances =====
  dist1obs1 = sqrt((x1 - obs1x) * (x1 - obs1x) + (y1 - obs1y) * (y1 - obs1y) + (z1 - obs1z) * (z1 - obs1z));
  dist1obs2 = sqrt((x1 - obs2x) * (x1 - obs2x) + (y1 - obs2y) * (y1 - obs2y) + (z1 - obs2z) * (z1 - obs2z));
  dist2obs1 = sqrt((x2 - obs1x) * (x2 - obs1x) + (y2 - obs1y) * (y2 - obs1y) + (z2 - obs1z) * (z2 - obs1z));
  dist2obs2 = sqrt((x2 - obs2x) * (x2 - obs2x) + (y2 - obs2y) * (y2 - obs2y) + (z2 - obs2z) * (z2 - obs2z));
  dist3obs1 = sqrt((x3 - obs1x) * (x3 - obs1x) + (y3 - obs1y) * (y3 - obs1y) + (z3 - obs1z) * (z3 - obs1z));
  dist3obs2 = sqrt((x3 - obs2x) * (x3 - obs2x) + (y3 - obs2y) * (y3 - obs2y) + (z3 - obs2z) * (z3 - obs2z));

  // ===== Verification metrics =====
  formationError = sqrt(((range12 - desRange12) * (range12 - desRange12) + (range13 - desRange13) * (range13 - desRange13) + (range23 - desRange23) * (range23 - desRange23)) / 3.0);

  primaryTrackingError = sqrt(((x1 + x2 + x3) / 3.0 - leadX) * ((x1 + x2 + x3) / 3.0 - leadX) + ((y1 + y2 + y3) / 3.0 - leadY) * ((y1 + y2 + y3) / 3.0 - leadY) + ((z1 + z2 + z3) / 3.0 - leadZ) * ((z1 + z2 + z3) / 3.0 - leadZ));

  actuatorLimitsOK = r11 >= 0.0 and r11 <= maxRotorThrust and r12 >= 0.0 and r12 <= maxRotorThrust and r13 >= 0.0 and r13 <= maxRotorThrust and r14 >= 0.0 and r14 <= maxRotorThrust and r21 >= 0.0 and r21 <= maxRotorThrust and r22 >= 0.0 and r22 <= maxRotorThrust and r23 >= 0.0 and r23 <= maxRotorThrust and r24 >= 0.0 and r24 <= maxRotorThrust and r31 >= 0.0 and r31 <= maxRotorThrust and r32 >= 0.0 and r32 <= maxRotorThrust and r33 >= 0.0 and r33 <= maxRotorThrust and r34 >= 0.0 and r34 <= maxRotorThrust;

  pairwiseSeparationOK = range12 >= minSep and range13 >= minSep and range23 >= minSep;

  noCollisionOK = dist1obs1 > obsRadius and dist1obs2 > obsRadius and dist2obs1 > obsRadius and dist2obs2 > obsRadius and dist3obs1 > obsRadius and dist3obs2 > obsRadius;

  primaryTrackingErrorOK = (time < 13.0) or (primaryTrackingError < trackTol);

  finiteValuesOK = abs(x1) < 1e9 and abs(y1) < 1e9 and abs(z1) < 1e9 and abs(vx1) < 1e9 and abs(vy1) < 1e9 and abs(vz1) < 1e9 and abs(x2) < 1e9 and abs(y2) < 1e9 and abs(z2) < 1e9 and abs(vx2) < 1e9 and abs(vy2) < 1e9 and abs(vz2) < 1e9 and abs(x3) < 1e9 and abs(y3) < 1e9 and abs(z3) < 1e9 and abs(vx3) < 1e9 and abs(vy3) < 1e9 and abs(vz3) < 1e9 and abs(estX1) < 1e9 and abs(estY1) < 1e9 and abs(estZ1) < 1e9 and abs(estVx1) < 1e9 and abs(estVy1) < 1e9 and abs(estVz1) < 1e9 and abs(estX2) < 1e9 and abs(estY2) < 1e9 and abs(estZ2) < 1e9 and abs(estVx2) < 1e9 and abs(estVy2) < 1e9 and abs(estVz2) < 1e9 and abs(estX3) < 1e9 and abs(estY3) < 1e9 and abs(estZ3) < 1e9 and abs(estVx3) < 1e9 and abs(estVy3) < 1e9 and abs(estVz3) < 1e9 and abs(cmdAccX1) < 1e9 and abs(cmdAccY1) < 1e9 and abs(cmdAccZ1) < 1e9 and abs(cmdAccX2) < 1e9 and abs(cmdAccY2) < 1e9 and abs(cmdAccZ2) < 1e9 and abs(cmdAccX3) < 1e9 and abs(cmdAccY3) < 1e9 and abs(cmdAccZ3) < 1e9 and abs(r11) < 1e9 and abs(r12) < 1e9 and abs(r13) < 1e9 and abs(r14) < 1e9 and abs(r21) < 1e9 and abs(r22) < 1e9 and abs(r23) < 1e9 and abs(r24) < 1e9 and abs(r31) < 1e9 and abs(r32) < 1e9 and abs(r33) < 1e9 and abs(r34) < 1e9;

  verificationOK = actuatorLimitsOK and pairwiseSeparationOK and noCollisionOK and primaryTrackingErrorOK and finiteValuesOK;

  assert(actuatorLimitsOK, "Actuator limit violation");
  assert(pairwiseSeparationOK, "Pairwise separation violation");
  assert(noCollisionOK, "Collision with obstacle");
  assert(primaryTrackingErrorOK, "Primary tracking error above threshold after 13 s");
  assert(finiteValuesOK, "Non-finite physical, control, or estimator value");

  annotation(
    experiment(StopTime = 20.0, Interval = 0.002, Tolerance = 1e-6),
    Documentation(info = "Three 1.8 kg quadrotors follow a leader trajectory maintaining formation offsets with bounded local commands. A 0.116 s message-delay disturbance is applied during the middle third of the 20 s mission at 500 Hz. Values not given in the requirement are marked as assumed. State, command, and sensor traces are retained as model variables."));
end AirTrioFormF;