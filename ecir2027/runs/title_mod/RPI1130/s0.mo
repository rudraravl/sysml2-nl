model AirTrioFormB
  "Three 1.8 kg quadrotors follow a leader trajectory, maintain nominal relative offsets, use delayed peer pose messages during the middle third, and enforce bounded rotor thrust."

  // Physical and mission parameters (values from the request)
  parameter Real m = 1.8 "quadrotor mass, kg";
  parameter Real g = 9.81 "gravitational acceleration, m/s^2";
  parameter Real thrustMaxPerRotor = 9.84 "allowed rotor-thrust command magnitude, N";
  parameter Real FmaxTotal = 4.0*thrustMaxPerRotor "total thrust limit per quadrotor, N";
  parameter Real Tdelay = 0.056 "injected message delay, s";
  parameter Real TendMission = 10.0 "mission duration, s";
  parameter Real TstartDelay = TendMission/3.0 "start of middle third, s";
  parameter Real TendDelay = 2.0*TendMission/3.0 "end of middle third, s";
  parameter Real primaryTrackThreshold = 0.36 "primary tracking error limit after 6.5 s, m";

  // Nominal placeholder values for facts not specified by the request.
  // These are chosen only to make a concrete executable model; replace with mission data.
  parameter Real leaderAmpX = 1.0 "nominal leader path amplitude x, m";
  parameter Real leaderAmpY = 1.0 "nominal leader path amplitude y, m";
  parameter Real leaderOmega = 0.628 "nominal leader angular rate, rad/s";
  parameter Real leaderZ = 1.0 "nominal leader height, m";

  parameter Real off1x = 0.0 "nominal offset robot 1 x, m";
  parameter Real off1y = 0.0 "nominal offset robot 1 y, m";
  parameter Real off1z = 0.0 "nominal offset robot 1 z, m";
  parameter Real off2x = 1.0 "nominal offset robot 2 x, m";
  parameter Real off2y = 0.0 "nominal offset robot 2 y, m";
  parameter Real off2z = 0.0 "nominal offset robot 2 z, m";
  parameter Real off3x = 0.0 "nominal offset robot 3 x, m";
  parameter Real off3y = 1.0 "nominal offset robot 3 y, m";
  parameter Real off3z = 0.0 "nominal offset robot 3 z, m";

  parameter Real collisionRadius = 0.10 "placeholder collision radius, m; actual minimum separation not stated";
  parameter Real obs1x = 10.0 "placeholder obstacle 1 x, m";
  parameter Real obs1y = 10.0 "placeholder obstacle 1 y, m";
  parameter Real obs1z = 0.0 "placeholder obstacle 1 z, m";
  parameter Real obs2x = -10.0 "placeholder obstacle 2 x, m";
  parameter Real obs2y = -10.0 "placeholder obstacle 2 y, m";
  parameter Real obs2z = 0.0 "placeholder obstacle 2 z, m";

  // Controller gains (nominal placeholder values)
  parameter Real kp = 12.0 "position gain, 1/s^2";
  parameter Real kd = 5.0 "velocity gain, 1/s";
  parameter Real ksep = 1.0 "peer separation gain, 1/s^2";

  // Leader state
  Real pLx "leader x, m";
  Real pLy "leader y, m";
  Real pLz "leader z, m";
  Real vLx "leader vx, m/s";
  Real vLy "leader vy, m/s";
  Real vLz "leader vz, m/s";
  Real aLx "leader ax, m/s^2";
  Real aLy "leader ay, m/s^2";
  Real aLz "leader az, m/s^2";

  // Robot states
  Real p1x, p1y, p1z "robot 1 position, m";
  Real v1x, v1y, v1z "robot 1 velocity, m/s";
  Real p2x, p2y, p2z "robot 2 position, m";
  Real v2x, v2y, v2z "robot 2 velocity, m/s";
  Real p3x, p3y, p3z "robot 3 position, m";
  Real v3x, v3y, v3z "robot 3 velocity, m/s";

  // Desired states
  Real pd1x, pd1y, pd1z "robot 1 desired position, m";
  Real vd1x, vd1y, vd1z "robot 1 desired velocity, m/s";
  Real pd2x, pd2y, pd2z "robot 2 desired position, m";
  Real vd2x, vd2y, vd2z "robot 2 desired velocity, m/s";
  Real pd3x, pd3y, pd3z "robot 3 desired position, m";
  Real vd3x, vd3y, vd3z "robot 3 desired velocity, m/s";

  // Onboard state estimates (nominal: perfect self estimate)
  Real pe1x, pe1y, pe1z "robot 1 estimated position, m";
  Real ve1x, ve1y, ve1z "robot 1 estimated velocity, m/s";
  Real pe2x, pe2y, pe2z "robot 2 estimated position, m";
  Real ve2x, ve2y, ve2z "robot 2 estimated velocity, m/s";
  Real pe3x, pe3y, pe3z "robot 3 estimated position, m";
  Real ve3x, ve3y, ve3z "robot 3 estimated velocity, m/s";

  // Communication delay
  Boolean inDelayWindow "true during middle third";
  Real commDelay "current message delay, s";
  Real commAge "communication age, s";

  // Delayed peer pose messages
  Real dp12x, dp12y, dp12z "robot 1 received delayed pose of robot 2, m";
  Real dp13x, dp13y, dp13z "robot 1 received delayed pose of robot 3, m";
  Real dp21x, dp21y, dp21z "robot 2 received delayed pose of robot 1, m";
  Real dp23x, dp23y, dp23z "robot 2 received delayed pose of robot 3, m";
  Real dp31x, dp31y, dp31z "robot 3 received delayed pose of robot 1, m";
  Real dp32x, dp32y, dp32z "robot 3 received delayed pose of robot 2, m";

  // Peer-relative range sensors
  Real r12 "range robot 1 to robot 2, m";
  Real r13 "range robot 1 to robot 3, m";
  Real r23 "range robot 2 to robot 3, m";
  Real desiredR12 "desired range 1-2, m";
  Real desiredR13 "desired range 1-3, m";
  Real desiredR23 "desired range 2-3, m";

  // Direction norms and unit directions for distributed separation control
  Real n12, n13, n21, n23, n31, n32;
  Real dir12x, dir12y, dir12z;
  Real dir13x, dir13y, dir13z;
  Real dir21x, dir21y, dir21z;
  Real dir23x, dir23y, dir23z;
  Real dir31x, dir31y, dir31z;
  Real dir32x, dir32y, dir32z;

  // Commanded accelerations
  Real a1x, a1y, a1z "robot 1 commanded acceleration, m/s^2";
  Real a2x, a2y, a2z "robot 2 commanded acceleration, m/s^2";
  Real a3x, a3y, a3z "robot 3 commanded acceleration, m/s^2";

  // Thrust saturation and actual accelerations
  Real F1x, F1y, F1z, F1mag, F1magSat, u1x, u1y, u1z;
  Real F2x, F2y, F2z, F2mag, F2magSat, u2x, u2y, u2z;
  Real F3x, F3y, F3z, F3mag, F3magSat, u3x, u3y, u3z;
  Real aAct1x, aAct1y, aAct1z "robot 1 actual acceleration, m/s^2";
  Real aAct2x, aAct2y, aAct2z "robot 2 actual acceleration, m/s^2";
  Real aAct3x, aAct3y, aAct3z "robot 3 actual acceleration, m/s^2";

  // Twelve independent rotor-thrust command groups
  Real T11, T12, T13, T14 "robot 1 rotor thrusts, N";
  Real T21, T22, T23, T24 "robot 2 rotor thrusts, N";
  Real T31, T32, T33, T34 "robot 3 rotor thrusts, N";
  Real base1, base2, base3 "per-rotor base thrust, N";

  // Tracking and formation error
  Real trackErr1, trackErr2, trackErr3 "per-robot tracking error, m";
  Real primaryTrackErr "primary tracking error, m";
  Real formErr "formation error, m";
  Real minPairSep "minimum pairwise separation, m";

  // Obstacle distances
  Real obs1Dist1, obs1Dist2, obs1Dist3 "distance to obstacle 1, m";
  Real obs2Dist1, obs2Dist2, obs2Dist3 "distance to obstacle 2, m";
  Real minObsDist "minimum obstacle distance, m";

  // Requirement checks
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
  aLy = -leaderAmpY*leaderOmega*leaderOmega*(1.0 - cos(leaderOmega*time));
  aLz = 0.0;

  // Desired formation positions and velocities
  pd1x = pLx + off1x;
  pd1y = pLy + off1y;
  pd1z = pLz + off1z;
  vd1x = vLx;
  vd1y = vLy;
  vd1z = vLz;

  pd2x = pLx + off2x;
  pd2y = pLy + off2y;
  pd2z = pLz + off2z;
  vd2x = vLx;
  vd2y = vLy;
  vd2z = vLz;

  pd3x = pLx + off3x;
  pd3y = pLy + off3y;
  pd3z = pLz + off3z;
  vd3x = vLx;
  vd3y = vLy;
  vd3z = vLz;

  // Onboard state estimation (nominal perfect self estimate)
  pe1x = p1x;
  pe1y = p1y;
  pe1z = p1z;
  ve1x = v1x;
  ve1y = v1y;
  ve1z = v1z;

  pe2x = p2x;
  pe2y = p2y;
  pe2z = p2z;
  ve2x = v2x;
  ve2y = v2y;
  ve2z = v2z;

  pe3x = p3x;
  pe3y = p3y;
  pe3z = p3z;
  ve3x = v3x;
  ve3y = v3y;
  ve3z = v3z;

  // Communication delay disturbance during middle third
  inDelayWindow = time >= TstartDelay and time <= TendDelay;
  commDelay = if inDelayWindow then Tdelay else 0.0;
  commAge = commDelay;

  // Delayed peer pose messages
  dp12x = delay(p2x, commDelay, 0.1);
  dp12y = delay(p2y, commDelay, 0.1);
  dp12z = delay(p2z, commDelay, 0.1);

  dp13x = delay(p3x, commDelay, 0.1);
  dp13y = delay(p3y, commDelay, 0.1);
  dp13z = delay(p3z, commDelay, 0.1);

  dp21x = delay(p1x, commDelay, 0.1);
  dp21y = delay(p1y, commDelay, 0.1);
  dp21z = delay(p1z, commDelay, 0.1);

  dp23x = delay(p3x, commDelay, 0.1);
  dp23y = delay(p3y, commDelay, 0.1);
  dp23z = delay(p3z, commDelay, 0.1);

  dp31x = delay(p1x, commDelay, 0.1);
  dp31y = delay(p1y, commDelay, 0.1);
  dp31z = delay(p1z, commDelay, 0.1);

  dp32x = delay(p2x, commDelay, 0.1);
  dp32y = delay(p2y, commDelay, 0.1);
  dp32z = delay(p2z, commDelay, 0.1);

  // Peer-relative range sensing
  r12 = sqrt((p1x - p2x)^2 + (p1y - p2y)^2 + (p1z - p2z)^2);
  r13 = sqrt((p1x - p3x)^2 + (p1y - p3y)^2 + (p1z - p3z)^2);
  r23 = sqrt((p2x - p3x)^2 + (p2y - p3y)^2 + (p2z - p3z)^2);

  desiredR12 = sqrt((off1x - off2x)^2 + (off1y - off2y)^2 + (off1z - off2z)^2);
  desiredR13 = sqrt((off1x - off3x)^2 + (off1y - off3y)^2 + (off1z - off3z)^2);
  desiredR23 = sqrt((off2x - off3x)^2 + (off2y - off3y)^2 + (off2z - off3z)^2);

  // Direction norms with zero-error branch
  n12 = sqrt((pe1x - dp12x)^2 + (pe1y - dp12y)^2 + (pe1z - dp12z)^2);
  n13 = sqrt((pe1x - dp13x)^2 + (pe1y - dp13y)^2 + (pe1z - dp13z)^2);
  n21 = sqrt((pe2x - dp21x)^2 + (pe2y - dp21y)^2 + (pe2z - dp21z)^2);
  n23 = sqrt((pe2x - dp23x)^2 + (pe2y - dp23y)^2 + (pe2z - dp23z)^2);
  n31 = sqrt((pe3x - dp31x)^2 + (pe3y - dp31y)^2 + (pe3z - dp31z)^2);
  n32 = sqrt((pe3x - dp32x)^2 + (pe3y - dp32y)^2 + (pe3z - dp32z)^2);

  dir12x = if n12 > 1e-9 then (pe1x - dp12x)/n12 else 0.0;
  dir12y = if n12 > 1e-9 then (pe1y - dp12y)/n12 else 0.0;
  dir12z = if n12 > 1e-9 then (pe1z - dp12z)/n12 else 0.0;

  dir13x = if n13 > 1e-9 then (pe1x - dp13x)/n13 else 0.0;
  dir13y = if n13 > 1e-9 then (pe1y - dp13y)/n13 else 0.0;
  dir13z = if n13 > 1e-9 then (pe1z - dp13z)/n13 else 0.0;

  dir21x = if n21 > 1e-9 then (pe2x - dp21x)/n21 else 0.0;
  dir21y = if n21 > 1e-9 then (pe2y - dp21y)/n21 else 0.0;
  dir21z = if n21 > 1e-9 then (pe2z - dp21z)/n21 else 0.0;

  dir23x = if n23 > 1e-9 then (pe2x - dp23x)/n23 else 0.0;
  dir23y = if n23 > 1e-9 then (pe2y - dp23y)/n23 else 0.0;
  dir23z = if n23 > 1e-9 then (pe2z - dp23z)/n23 else 0.0;

  dir31x = if n31 > 1e-9 then (pe3x - dp31x)/n31 else 0.0;
  dir31y = if n31 > 1e-9 then (pe3y - dp31y)/n31 else 0.0;
  dir31z = if n31 > 1e-9 then (pe3z - dp31z)/n31 else 0.0;

  dir32x = if n32 > 1e-9 then (pe3x - dp32x)/n32 else 0.0;
  dir32y = if n32 > 1e-9 then (pe3y - dp32y)/n32 else 0.0;
  dir32z = if n32 > 1e-9 then (pe3z - dp32z)/n32 else 0.0;

  // Distributed formation control with bounded local commands
  a1x = aLx + kp*(pd1x - pe1x) + kd*(vd1x - ve1x) - ksep*(r12 - desiredR12)*dir12x - ksep*(r13 - desiredR13)*dir13x;
  a1y = aLy + kp*(pd1y - pe1y) + kd*(vd1y - ve1y) - ksep*(r12 - desiredR12)*dir12y - ksep*(r13 - desiredR13)*dir13y;
  a1z = aLz + kp*(pd1z - pe1z) + kd*(vd1z - ve1z) - ksep*(r12 - desiredR12)*dir12z - ksep*(r13 - desiredR13)*dir13z;

  a2x = aLx + kp*(pd2x - pe2x) + kd*(vd2x - ve2x) - ksep*(r12 - desiredR12)*dir21x - ksep*(r23 - desiredR23)*dir23x;
  a2y = aLy + kp*(pd2y - pe2y) + kd*(vd2y - ve2y) - ksep*(r12 - desiredR12)*dir21y - ksep*(r23 - desiredR23)*dir23y;
  a2z = aLz + kp*(pd2z - pe2z) + kd*(vd2z - ve2z) - ksep*(r12 - desiredR12)*dir21z - ksep*(r23 - desiredR23)*dir23z;

  a3x = aLx + kp*(pd3x - pe3x) + kd*(vd3x - ve3x) - ksep*(r13 - desiredR13)*dir31x - ksep*(r23 - desiredR23)*dir32x;
  a3y = aLy + kp*(pd3y - pe3y) + kd*(vd3y - ve3y) - ksep*(r13 - desiredR13)*dir31y - ksep*(r23 - desiredR23)*dir32y;
  a3z = aLz + kp*(pd3z - pe3z) + kd*(vd3z - ve3z) - ksep*(r13 - desiredR13)*dir31z - ksep*(r23 - desiredR23)*dir32z;

  // Thrust-vector saturation and actual acceleration
  F1x = m*a1x;
  F1y = m*a1y;
  F1z = m*(a1z + g);
  F1mag = sqrt(F1x^2 + F1y^2 + F1z^2);
  F1magSat = if F1mag > FmaxTotal then FmaxTotal else F1mag;
  u1x = if F1mag > 1e-9 then F1x/F1mag else 0.0;
  u1y = if F1mag > 1e-9 then F1y/F1mag else 0.0;
  u1z = if F1mag > 1e-9 then F1z/F1mag else 1.0;
  aAct1x = F1magSat*u1x/m;
  aAct1y = F1magSat*u1y/m;
  aAct1z = F1magSat*u1z/m - g;

  F2x = m*a2x;
  F2y = m*a2y;
  F2z = m*(a2z + g);
  F2mag = sqrt(F2x^2 + F2y^2 + F2z^2);
  F2magSat = if F2mag > FmaxTotal then FmaxTotal else F2mag;
  u2x = if F2mag > 1e-9 then F2x/F2mag else 0.0;
  u2y = if F2mag > 1e-9 then F2y/F2mag else 0.0;
  u2z = if F2mag > 1e-9 then F2z/F2mag else 1.0;
  aAct2x = F2magSat*u2x/m;
  aAct2y = F2magSat*u2y/m;
  aAct2z = F2magSat*u2z/m - g;

  F3x = m*a3x;
  F3y = m*a3y;
  F3z = m*(a3z + g);
  F3mag = sqrt(F3x^2 + F3y^2 + F3z^2);
  F3magSat = if F3mag > FmaxTotal then FmaxTotal else F3mag;
  u3x = if F3mag > 1e-9 then F3x/F3mag else 0.0;
  u3y = if F3mag > 1e-9 then F3y/F3mag else 0.0;
  u3z = if F3mag > 1e-9 then F3z/F3mag else 1.0;
  aAct3x = F3magSat*u3x/m;
  aAct3y = F3magSat*u3y/m;
  aAct3z = F3magSat*u3z/m - g;

  // Twelve independent rotor-thrust commands, each bounded by construction
  base1 = F1magSat/4.0;
  T11 = base1;
  T12 = base1;
  T13 = base1;
  T14 = base1;

  base2 = F2magSat/4.0;
  T21 = base2;
  T22 = base2;
  T23 = base2;
  T24 = base2;

  base3 = F3magSat/4.0;
  T31 = base3;
  T32 = base3;
  T33 = base3;
  T34 = base3;

  // Robot dynamics
  der(p1x) = v1x;
  der(p1y) = v1y;
  der(p1z) = v1z;
  der(v1x) = aAct1x;
  der(v1y) = aAct1y;
  der(v1z) = aAct1z;

  der(p2x) = v2x;
  der(p2y) = v2y;
  der(p2z) = v2z;
  der(v2x) = aAct2x;
  der(v2y) = aAct2y;
  der(v2z) = aAct2z;

  der(p3x) = v3x;
  der(p3y) = v3y;
  der(p3z) = v3z;
  der(v3x) = aAct3x;
  der(v3y) = aAct3y;
  der(v3z) = aAct3z;

  // Tracking and formation errors
  trackErr1 = sqrt((p1x - pd1x)^2 + (p1y - pd1y)^2 + (p1z - pd1z)^2);
  trackErr2 = sqrt((p2x - pd2x)^2 + (p2y - pd2y)^2 + (p2z - pd2z)^2);
  trackErr3 = sqrt((p3x - pd3x)^2 + (p3y - pd3y)^2 + (p3z - pd3z)^2);
  primaryTrackErr = trackErr1;
  formErr = trackErr1 + trackErr2 + trackErr3;

  // Pairwise separation and collision check
  minPairSep = if r12 <= r13 then (if r12 <= r23 then r12 else r23) else (if r13 <= r23 then r13 else r23);
  pairSepOK = minPairSep > collisionRadius;
  noCollision = pairSepOK;

  // Obstacle distances (obstacles are placeholder locations outside the nominal path)
  obs1Dist1 = sqrt((p1x - obs1x)^2 + (p1y - obs1y)^2 + (p1z - obs1z)^2);
  obs1Dist2 = sqrt((p2x - obs1x)^2 + (p2y - obs1y)^2 + (p2z - obs1z)^2);
  obs1Dist3 = sqrt((p3x - obs1x)^2 + (p3y - obs1y)^2 + (p3z - obs1z)^2);
  obs2Dist1 = sqrt((p1x - obs2x)^2 + (p1y - obs2y)^2 + (p1z - obs2z)^2);
  obs2Dist2 = sqrt((p2x - obs2x)^2 + (p2y - obs2y)^2 + (p2z - obs2z)^2);
  obs2Dist3 = sqrt((p3x - obs2x)^2 + (p3y - obs2y)^2 + (p3z - obs2z)^2);
  minObsDist = if obs1Dist1 <= obs1Dist2 then (if obs1Dist1 <= obs1Dist3 then obs1Dist1 else obs1Dist3) else (if obs1Dist2 <= obs1Dist3 then obs1Dist2 else obs1Dist3);
  minObsDist = if minObsDist <= obs2Dist1 then minObsDist else obs2Dist1;
  minObsDist = if minObsDist <= obs2Dist2 then minObsDist else obs2Dist2;
  minObsDist = if minObsDist <= obs2Dist3 then minObsDist else obs2Dist3;
  obstacleClearOK = minObsDist > collisionRadius;

  // Actuator limit check
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

  // Primary tracking requirement
  primaryTrackOK = if time < 6.5 then true else primaryTrackErr < primaryTrackThreshold;

  // Finite-value guard
  finiteSum =
    abs(p1x) + abs(p1y) + abs(p1z) + abs(v1x) + abs(v1y) + abs(v1z) +
    abs(p2x) + abs(p2y) + abs(p2z) + abs(v2x) + abs(v2y) + abs(v2z) +
    abs(p3x) + abs(p3y) + abs(p3z) + abs(v3x) + abs(v3y) + abs(v3z) +
    abs(aAct1x) + abs(aAct1y) + abs(aAct1z) +
    abs(aAct2x) + abs(aAct2y) + abs(aAct2z) +
    abs(aAct3x) + abs(aAct3y) + abs(aAct3z) +
    abs(T11) + abs(T12) + abs(T13) + abs(T14) +
    abs(T21) + abs(T22) + abs(T23) + abs(T24) +
    abs(T31) + abs(T32) + abs(T33) + abs(T34) +
    abs(pe1x) + abs(pe1y) + abs(pe1z) +
    abs(pe2x) + abs(pe2y) + abs(pe2z) +
    abs(pe3x) + abs(pe3y) + abs(pe3z) +
    primaryTrackErr + formErr + minPairSep + commAge;
  finiteOK = finiteSum > -1e12 and finiteSum < 1e12;

  assert(actuatorLimitsOK, "Actuator limit violated");
  assert(pairSepOK, "Pairwise separation violated");
  assert(noCollision, "Collision detected");
  assert(primaryTrackOK, "Primary tracking error above 0.36 m after 6.5 s");
  assert(obstacleClearOK, "Obstacle clearance violated");
  assert(finiteOK, "Non-finite physical, control, or estimator value detected");

initial equation
  p1x = pd1x;
  p1y = pd1y;
  p1z = pd1z;
  v1x = vd1x;
  v1y = vd1y;
  v1z = vd1z;

  p2x = pd2x;
  p2y = pd2y;
  p2z = pd2z;
  v2x = vd2x;
  v2y = vd2y;
  v2z = vd2z;

  p3x = pd3x;
  p3y = pd3y;
  p3z = pd3z;
  v3x = vd3x;
  v3y = vd3y;
  v3z = vd3z;

  annotation(
    experiment(StopTime = 10.0, Interval = 0.01, Tolerance = 1e-6),
    Documentation(info = "AirTrioFormB: 100 Hz, 10 s formation mission with three 1.8 kg quadrotors, 9.84 N-per-rotor limit, delayed pose messages during middle third, and bounded distributed formation control."));
end AirTrioFormB;