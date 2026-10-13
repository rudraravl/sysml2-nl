model AirTrioFormB
  "Three 1.8 kg quadrotors follow a leader trajectory, maintain nominal relative offsets, use delayed peer pose messages during the middle third, and enforce bounded rotor thrust.";

  // Physical constants
  parameter Real m = 1.8 "quadrotor mass, kg";
  parameter Real g = 9.81 "gravitational acceleration, m/s^2";
  parameter Real thrustMaxPerRotor = 9.84 "allowed rotor-thrust command magnitude, N";
  parameter Real FmaxTotal = 4.0*thrustMaxPerRotor "total thrust limit per quadrotor, N";

  // Mission timing
  parameter Real Tdelay = 0.056 "injected message delay, s";
  parameter Real TendMission = 10.0 "mission duration, s";
  parameter Real TstartDelay = TendMission/3.0 "start of middle third, s";
  parameter Real TendDelay = 2.0*TendMission/3.0 "end of middle third, s";
  parameter Real primaryTrackThreshold = 0.36 "primary tracking error limit after 6.5 s, m";
  parameter Real tauTrack = 0.01 "delayed-pose tracking time constant outside delay window, s";

  // Leader trajectory (nominal representative values; exact amplitudes/rate not stated)
  parameter Real leaderAmpX = 1.0 "nominal leader path amplitude x, m";
  parameter Real leaderAmpY = 1.0 "nominal leader path amplitude y, m";
  parameter Real leaderOmega = 0.628 "nominal leader angular rate, rad/s";
  parameter Real leaderZ = 1.0 "nominal leader height, m";

  // Nominal formation offsets
  parameter Real off1x = 0.0;
  parameter Real off1y = 0.0;
  parameter Real off2x = 1.0;
  parameter Real off2y = 0.0;
  parameter Real off3x = 0.0;
  parameter Real off3y = 1.0;

  // Placeholder obstacles placed outside nominal path (exact obstacle locations not stated)
  parameter Real obs1x = 10.0;
  parameter Real obs1y = 10.0;
  parameter Real obs2x = -10.0;
  parameter Real obs2y = -10.0;
  parameter Real collisionRadius = 0.10 "placeholder minimum-separation/collision radius, m; actual minimum separation not stated";

  // Control gains
  parameter Real kp = 12.0 "position gain, 1/s^2";
  parameter Real kd = 5.0 "velocity gain, 1/s";
  parameter Real ksep = 1.0 "peer separation gain, 1/s^2";

  // Leader state
  Real pLx, pLy, pLz;
  Real vLx, vLy, vLz;
  Real aLx, aLy, aLz;

  // Robot positions and velocities (states)
  Real p1x, p1y, p1z;
  Real v1x, v1y, v1z;
  Real p2x, p2y, p2z;
  Real v2x, v2y, v2z;
  Real p3x, p3y, p3z;
  Real v3x, v3y, v3z;

  // Delayed (broadcast) pose states; pure transport delay approximated by a
  // first-order lag for FMU code-generation compatibility.
  Real dp1x, dp1y, dp1z;
  Real dp2x, dp2y, dp2z;
  Real dp3x, dp3y, dp3z;
  Real tauEff "effective delayed-pose time constant, s";

  // Desired trajectories
  Real pd1x, pd1y, pd1z;
  Real vd1x, vd1y, vd1z;
  Real pd2x, pd2y, pd2z;
  Real vd2x, vd2y, vd2z;
  Real pd3x, pd3y, pd3z;
  Real vd3x, vd3y, vd3z;

  // Estimated states (onboard state estimation; idealized here)
  Real pe1x, pe1y, pe1z;
  Real ve1x, ve1y, ve1z;
  Real pe2x, pe2y, pe2z;
  Real ve2x, ve2y, ve2z;
  Real pe3x, pe3y, pe3z;
  Real ve3x, ve3y, ve3z;

  // Communication age / delay window
  Boolean inDelayWindow;
  Real commDelay;
  Real commAge;

  // Peer-relative ranges (instant range sensing)
  Real r12, r13, r23;
  Real desiredR12, desiredR13, desiredR23;

  // Direction unit vectors toward peers (using delayed peer poses)
  Real n12, n13, n21, n23, n31, n32;
  Real dir12x, dir12y, dir12z;
  Real dir13x, dir13y, dir13z;
  Real dir21x, dir21y, dir21z;
  Real dir23x, dir23y, dir23z;
  Real dir31x, dir31y, dir31z;
  Real dir32x, dir32y, dir32z;

  // Commanded accelerations
  Real a1x, a1y, a1z;
  Real a2x, a2y, a2z;
  Real a3x, a3y, a3z;

  // Forces and saturation
  Real F1x, F1y, F1z, F1mag, F1magSat, u1x, u1y, u1z;
  Real F2x, F2y, F2z, F2mag, F2magSat, u2x, u2y, u2z;
  Real F3x, F3y, F3z, F3mag, F3magSat, u3x, u3y, u3z;
  Real aAct1x, aAct1y, aAct1z;
  Real aAct2x, aAct2y, aAct2z;
  Real aAct3x, aAct3y, aAct3z;

  // Rotor thrusts (equal split per quadrotor)
  Real T11, T12, T13, T14;
  Real T21, T22, T23, T24;
  Real T31, T32, T33, T34;

  // Metrics
  Real trackErr1, trackErr2, trackErr3;
  Real primaryTrackErr;
  Real formErr;
  Real minPairSep;
  Real obs1Dist1, obs1Dist2, obs1Dist3;
  Real obs2Dist1, obs2Dist2, obs2Dist3;
  Real minObsDist;

  // Requirement flags
  Boolean actuatorLimitsOK;
  Boolean pairSepOK;
  Boolean noCollision;
  Boolean primaryTrackOK;
  Boolean obstacleClearOK;
  Boolean finiteOK;
  Real finiteSum;

equation
  // Leader trajectory
  pLx = leaderAmpX*sin(leaderOmega*time);
  pLy = leaderAmpY*(1.0 - cos(leaderOmega*time));
  pLz = leaderZ;
  vLx = leaderAmpX*leaderOmega*cos(leaderOmega*time);
  vLy = leaderAmpY*leaderOmega*sin(leaderOmega*time);
  vLz = 0.0;
  aLx = -leaderAmpX*leaderOmega*leaderOmega*sin(leaderOmega*time);
  aLy = leaderAmpY*leaderOmega*leaderOmega*cos(leaderOmega*time);
  aLz = 0.0;

  // Desired positions = leader + offset
  pd1x = pLx + off1x; pd1y = pLy + off1y; pd1z = pLz;
  vd1x = vLx; vd1y = vLy; vd1z = 0.0;
  pd2x = pLx + off2x; pd2y = pLy + off2y; pd2z = pLz;
  vd2x = vLx; vd2y = vLy; vd2z = 0.0;
  pd3x = pLx + off3x; pd3y = pLy + off3y; pd3z = pLz;
  vd3x = vLx; vd3y = vLy; vd3z = 0.0;

  // Ideal onboard state estimation (GPS + IMU)
  pe1x = p1x; pe1y = p1y; pe1z = p1z;
  ve1x = v1x; ve1y = v1y; ve1z = v1z;
  pe2x = p2x; pe2y = p2y; pe2z = p2z;
  ve2x = v2x; ve2y = v2y; ve2z = v2z;
  pe3x = p3x; pe3y = p3y; pe3z = p3z;
  ve3x = v3x; ve3y = v3y; ve3z = v3z;

  // Delay window and communication age
  inDelayWindow = time >= TstartDelay and time <= TendDelay;
  commDelay = if inDelayWindow then Tdelay else 0.0;
  commAge = commDelay;
  tauEff = if inDelayWindow then Tdelay else tauTrack;

  // Delayed pose dynamics (first-order lag approximation of transport delay)
  der(dp1x) = (p1x - dp1x)/tauEff;
  der(dp1y) = (p1y - dp1y)/tauEff;
  der(dp1z) = (p1z - dp1z)/tauEff;
  der(dp2x) = (p2x - dp2x)/tauEff;
  der(dp2y) = (p2y - dp2y)/tauEff;
  der(dp2z) = (p2z - dp2z)/tauEff;
  der(dp3x) = (p3x - dp3x)/tauEff;
  der(dp3y) = (p3y - dp3y)/tauEff;
  der(dp3z) = (p3z - dp3z)/tauEff;

  // Instant peer-relative range sensing
  r12 = sqrt((p1x - p2x)^2 + (p1y - p2y)^2 + (p1z - p2z)^2);
  r13 = sqrt((p1x - p3x)^2 + (p1y - p3y)^2 + (p1z - p3z)^2);
  r23 = sqrt((p2x - p3x)^2 + (p2y - p3y)^2 + (p2z - p3z)^2);
  desiredR12 = sqrt((off1x - off2x)^2 + (off1y - off2y)^2);
  desiredR13 = sqrt((off1x - off3x)^2 + (off1y - off3y)^2);
  desiredR23 = sqrt((off2x - off3x)^2 + (off2y - off3y)^2);

  // Direction unit vectors from own estimate toward delayed peer pose
  n12 = sqrt((dp2x - pe1x)^2 + (dp2y - pe1y)^2 + (dp2z - pe1z)^2);
  n13 = sqrt((dp3x - pe1x)^2 + (dp3y - pe1y)^2 + (dp3z - pe1z)^2);
  n21 = sqrt((dp1x - pe2x)^2 + (dp1y - pe2y)^2 + (dp1z - pe2z)^2);
  n23 = sqrt((dp3x - pe2x)^2 + (dp3y - pe2y)^2 + (dp3z - pe2z)^2);
  n31 = sqrt((dp1x - pe3x)^2 + (dp1y - pe3y)^2 + (dp1z - pe3z)^2);
  n32 = sqrt((dp2x - pe3x)^2 + (dp2y - pe3y)^2 + (dp2z - pe3z)^2);

  dir12x = if n12 > 1e-6 then (dp2x - pe1x)/n12 else 0.0;
  dir12y = if n12 > 1e-6 then (dp2y - pe1y)/n12 else 0.0;
  dir12z = if n12 > 1e-6 then (dp2z - pe1z)/n12 else 0.0;
  dir13x = if n13 > 1e-6 then (dp3x - pe1x)/n13 else 0.0;
  dir13y = if n13 > 1e-6 then (dp3y - pe1y)/n13 else 0.0;
  dir13z = if n13 > 1e-6 then (dp3z - pe1z)/n13 else 0.0;
  dir21x = if n21 > 1e-6 then (dp1x - pe2x)/n21 else 0.0;
  dir21y = if n21 > 1e-6 then (dp1y - pe2y)/n21 else 0.0;
  dir21z = if n21 > 1e-6 then (dp1z - pe2z)/n21 else 0.0;
  dir23x = if n23 > 1e-6 then (dp3x - pe2x)/n23 else 0.0;
  dir23y = if n23 > 1e-6 then (dp3y - pe2y)/n23 else 0.0;
  dir23z = if n23 > 1e-6 then (dp3z - pe2z)/n23 else 0.0;
  dir31x = if n31 > 1e-6 then (dp1x - pe3x)/n31 else 0.0;
  dir31y = if n31 > 1e-6 then (dp1y - pe3y)/n31 else 0.0;
  dir31z = if n31 > 1e-6 then (dp1z - pe3z)/n31 else 0.0;
  dir32x = if n32 > 1e-6 then (dp2x - pe3x)/n32 else 0.0;
  dir32y = if n32 > 1e-6 then (dp2y - pe3y)/n32 else 0.0;
  dir32z = if n32 > 1e-6 then (dp2z - pe3z)/n32 else 0.0;

  // Distributed formation control with bounded local commands
  a1x = aLx + kp*(pd1x - pe1x) + kd*(vd1x - ve1x) + ksep*(r12 - desiredR12)*dir12x + ksep*(r13 - desiredR13)*dir13x;
  a1y = aLy + kp*(pd1y - pe1y) + kd*(vd1y - ve1y) + ksep*(r12 - desiredR12)*dir12y + ksep*(r13 - desiredR13)*dir13y;
  a1z = aLz + kp*(pd1z - pe1z) + kd*(vd1z - ve1z) + ksep*(r12 - desiredR12)*dir12z + ksep*(r13 - desiredR13)*dir13z;
  a2x = aLx + kp*(pd2x - pe2x) + kd*(vd2x - ve2x) + ksep*(r12 - desiredR12)*dir21x + ksep*(r23 - desiredR23)*dir23x;
  a2y = aLy + kp*(pd2y - pe2y) + kd*(vd2y - ve2y) + ksep*(r12 - desiredR12)*dir21y + ksep*(r23 - desiredR23)*dir23y;
  a2z = aLz + kp*(pd2z - pe2z) + kd*(vd2z - ve2z) + ksep*(r12 - desiredR12)*dir21z + ksep*(r23 - desiredR23)*dir23z;
  a3x = aLx + kp*(pd3x - pe3x) + kd*(vd3x - ve3x) + ksep*(r13 - desiredR13)*dir31x + ksep*(r23 - desiredR23)*dir32x;
  a3y = aLy + kp*(pd3y - pe3y) + kd*(vd3y - ve3y) + ksep*(r13 - desiredR13)*dir31y + ksep*(r23 - desiredR23)*dir32y;
  a3z = aLz + kp*(pd3z - pe3z) + kd*(vd3z - ve3z) + ksep*(r13 - desiredR13)*dir31z + ksep*(r23 - desiredR23)*dir32z;

  // Force commands with magnitude saturation (actuator limits)
  F1x = m*a1x; F1y = m*a1y; F1z = m*(a1z + g);
  F1mag = sqrt(F1x^2 + F1y^2 + F1z^2);
  F1magSat = if F1mag > FmaxTotal then FmaxTotal else F1mag;
  u1x = if F1mag > 1e-6 then F1x/F1mag else 0.0;
  u1y = if F1mag > 1e-6 then F1y/F1mag else 0.0;
  u1z = if F1mag > 1e-6 then F1z/F1mag else 1.0;
  aAct1x = F1magSat*u1x/m;
  aAct1y = F1magSat*u1y/m;
  aAct1z = F1magSat*u1z/m - g;

  F2x = m*a2x; F2y = m*a2y; F2z = m*(a2z + g);
  F2mag = sqrt(F2x^2 + F2y^2 + F2z^2);
  F2magSat = if F2mag > FmaxTotal then FmaxTotal else F2mag;
  u2x = if F2mag > 1e-6 then F2x/F2mag else 0.0;
  u2y = if F2mag > 1e-6 then F2y/F2mag else 0.0;
  u2z = if F2mag > 1e-6 then F2z/F2mag else 1.0;
  aAct2x = F2magSat*u2x/m;
  aAct2y = F2magSat*u2y/m;
  aAct2z = F2magSat*u2z/m - g;

  F3x = m*a3x; F3y = m*a3y; F3z = m*(a3z + g);
  F3mag = sqrt(F3x^2 + F3y^2 + F3z^2);
  F3magSat = if F3mag > FmaxTotal then FmaxTotal else F3mag;
  u3x = if F3mag > 1e-6 then F3x/F3mag else 0.0;
  u3y = if F3mag > 1e-6 then F3y/F3mag else 0.0;
  u3z = if F3mag > 1e-6 then F3z/F3mag else 1.0;
  aAct3x = F3magSat*u3x/m;
  aAct3y = F3magSat*u3y/m;
  aAct3z = F3magSat*u3z/m - g;

  // Per-rotor thrust (equal split, bounded by thrustMaxPerRotor via FmagSat)
  T11 = F1magSat/4.0; T12 = F1magSat/4.0; T13 = F1magSat/4.0; T14 = F1magSat/4.0;
  T21 = F2magSat/4.0; T22 = F2magSat/4.0; T23 = F2magSat/4.0; T24 = F2magSat/4.0;
  T31 = F3magSat/4.0; T32 = F3magSat/4.0; T33 = F3magSat/4.0; T34 = F3magSat/4.0;

  // Plant dynamics (double integrator)
  der(p1x) = v1x; der(p1y) = v1y; der(p1z) = v1z;
  der(v1x) = aAct1x; der(v1y) = aAct1y; der(v1z) = aAct1z;
  der(p2x) = v2x; der(p2y) = v2y; der(p2z) = v2z;
  der(v2x) = aAct2x; der(v2y) = aAct2y; der(v2z) = aAct2z;
  der(p3x) = v3x; der(p3y) = v3y; der(p3z) = v3z;
  der(v3x) = aAct3x; der(v3y) = aAct3y; der(v3z) = aAct3z;

  // Metrics
  trackErr1 = sqrt((p1x - pd1x)^2 + (p1y - pd1y)^2 + (p1z - pd1z)^2);
  trackErr2 = sqrt((p2x - pd2x)^2 + (p2y - pd2y)^2 + (p2z - pd2z)^2);
  trackErr3 = sqrt((p3x - pd3x)^2 + (p3y - pd3y)^2 + (p3z - pd3z)^2);
  primaryTrackErr = trackErr1;
  formErr = trackErr1 + trackErr2 + trackErr3;
  minPairSep = min(r12, min(r13, r23));

  obs1Dist1 = sqrt((p1x - obs1x)^2 + (p1y - obs1y)^2 + p1z^2);
  obs1Dist2 = sqrt((p2x - obs1x)^2 + (p2y - obs1y)^2 + p2z^2);
  obs1Dist3 = sqrt((p3x - obs1x)^2 + (p3y - obs1y)^2 + p3z^2);
  obs2Dist1 = sqrt((p1x - obs2x)^2 + (p1y - obs2y)^2 + p1z^2);
  obs2Dist2 = sqrt((p2x - obs2x)^2 + (p2y - obs2y)^2 + p2z^2);
  obs2Dist3 = sqrt((p3x - obs2x)^2 + (p3y - obs2y)^2 + p3z^2);
  minObsDist = min(obs1Dist1, min(obs1Dist2, min(obs1Dist3, min(obs2Dist1, min(obs2Dist2, obs2Dist3)))));

  // Requirement flags
  actuatorLimitsOK =
    T11 >= 0.0 and T11 <= thrustMaxPerRotor + 1e-9 and
    T12 >= 0.0 and T12 <= thrustMaxPerRotor + 1e-9 and
    T13 >= 0.0 and T13 <= thrustMaxPerRotor + 1e-9 and
    T14 >= 0.0 and T14 <= thrustMaxPerRotor + 1e-9 and
    T21 >= 0.0 and T21 <= thrustMaxPerRotor + 1e-9 and
    T22 >= 0.0 and T22 <= thrustMaxPerRotor + 1e-9 and
    T23 >= 0.0 and T23 <= thrustMaxPerRotor + 1e-9 and
    T24 >= 0.0 and T24 <= thrustMaxPerRotor + 1e-9 and
    T31 >= 0.0 and T31 <= thrustMaxPerRotor + 1e-9 and
    T32 >= 0.0 and T32 <= thrustMaxPerRotor + 1e-9 and
    T33 >= 0.0 and T33 <= thrustMaxPerRotor + 1e-9 and
    T34 >= 0.0 and T34 <= thrustMaxPerRotor + 1e-9;
  pairSepOK = minPairSep > collisionRadius;
  noCollision = pairSepOK;
  obstacleClearOK = minObsDist > collisionRadius;
  primaryTrackOK = if time < 6.5 then true else primaryTrackErr < primaryTrackThreshold;

  finiteSum =
    abs(p1x)+abs(p1y)+abs(p1z)+abs(v1x)+abs(v1y)+abs(v1z)+
    abs(p2x)+abs(p2y)+abs(p2z)+abs(v2x)+abs(v2y)+abs(v2z)+
    abs(p3x)+abs(p3y)+abs(p3z)+abs(v3x)+abs(v3y)+abs(v3z)+
    abs(dp1x)+abs(dp1y)+abs(dp1z)+abs(dp2x)+abs(dp2y)+abs(dp2z)+abs(dp3x)+abs(dp3y)+abs(dp3z)+
    abs(aAct1x)+abs(aAct1y)+abs(aAct1z)+
    abs(aAct2x)+abs(aAct2y)+abs(aAct2z)+
    abs(aAct3x)+abs(aAct3y)+abs(aAct3z)+
    abs(T11)+abs(T12)+abs(T13)+abs(T14)+
    abs(T21)+abs(T22)+abs(T23)+abs(T24)+
    abs(T31)+abs(T32)+abs(T33)+abs(T34)+
    primaryTrackErr+formErr+minPairSep+commAge;
  finiteOK = finiteSum > -1e12 and finiteSum < 1e12;

  assert(actuatorLimitsOK, "Actuator limit violated");
  assert(pairSepOK, "Pairwise separation violated");
  assert(noCollision, "Collision detected");
  assert(primaryTrackOK, "Primary tracking error above 0.36 m after 6.5 s");
  assert(obstacleClearOK, "Obstacle clearance violated");
  assert(finiteOK, "Non-finite physical, control, or estimator value detected");

initial equation
  p1x = off1x; p1y = off1y; p1z = leaderZ;
  v1x = 0.0; v1y = 0.0; v1z = 0.0;
  p2x = off2x; p2y = off2y; p2z = leaderZ;
  v2x = 0.0; v2y = 0.0; v2z = 0.0;
  p3x = off3x; p3y = off3y; p3z = leaderZ;
  v3x = 0.0; v3y = 0.0; v3z = 0.0;
  dp1x = off1x; dp1y = off1y; dp1z = leaderZ;
  dp2x = off2x; dp2y = off2y; dp2z = leaderZ;
  dp3x = off3x; dp3y = off3y; dp3z = leaderZ;

  annotation(
    experiment(StopTime = 10.0, Interval = 0.01, Tolerance = 1e-6),
    Documentation(info = "AirTrioFormB: 100 Hz, 10 s formation mission with three 1.8 kg quadrotors, 9.84 N-per-rotor limit, delayed peer pose messages during the middle third (transport delay approximated by a first-order lag for FMU compatibility), and bounded distributed formation control."));
end AirTrioFormB;