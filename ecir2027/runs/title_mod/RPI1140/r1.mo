model AirTrioCoordinateF
  "Three 1.8 kg quadrotors crossing at shared intersection with decentralized reservation, bounded braking, and 0.174 s message delay disturbance"

  // Physical constants
  parameter Real g = 9.81 "gravitational acceleration [m/s^2]";

  // Quadrotor parameters
  parameter Real m = 1.8 "quadrotor mass [kg]";
  parameter Real fMax = 14.6 "maximum thrust per rotor [N]";

  // Simulation parameters
  parameter Real tFinal = 20.0 "simulation duration [s]";
  parameter Real fSample = 500.0 "control frequency [Hz]";
  parameter Real dtSample = 1.0 / fSample "control period [s]";

  // Disturbance
  parameter Real delayDist = 0.174 "message delay during middle third [s]";

  // Geometry
  parameter Real routeHalf = 5.0 "half route length [m]";
  parameter Real diagHalf = routeHalf / sqrt(2.0) "half diagonal start position [m]";
  parameter Real zCruise = 2.0 "cruise altitude [m]";
  parameter Real rInt = 1.2 "intersection reservation radius [m]";
  parameter Real brakeMargin = 0.5 "braking margin before zone [m]";
  parameter Real rSafe = 0.4 "minimum safe separation [m]";

  // Control
  parameter Real Kp = 5.0 "position proportional gain [1/s^2]";
  parameter Real Kd = 3.0 "velocity derivative gain [1/s]";
  parameter Real vCruise = 1.0 "nominal cruise speed [m/s]";
  parameter Real cos45 = 1.0 / sqrt(2.0) "cosine 45 degrees";
  parameter Real sin45 = 1.0 / sqrt(2.0) "sine 45 degrees";
  parameter Real trackErrThreshold = 0.52 "tracking error threshold after 13 s [m]";

  // Route distances (all 10 m)
  parameter Real routeDist1 = 2.0 * routeHalf "robot 1 route distance [m]";
  parameter Real routeDist2 = 2.0 * routeHalf "robot 2 route distance [m]";
  parameter Real routeDist3 = 2.0 * routeHalf "robot 3 route distance [m]";

  // State variables — positions [m]
  Real px1, py1, pz1 "robot 1 position";
  Real px2, py2, pz2 "robot 2 position";
  Real px3, py3, pz3 "robot 3 position";

  // Velocities [m/s]
  Real vx1, vy1, vz1 "robot 1 velocity";
  Real vx2, vy2, vz2 "robot 2 velocity";
  Real vx3, vy3, vz3 "robot 3 velocity";

  // Accelerations [m/s^2]
  Real ax1, ay1, az1 "robot 1 acceleration";
  Real ax2, ay2, az2 "robot 2 acceleration";
  Real ax3, ay3, az3 "robot 3 acceleration";

  // Rotor thrusts [N] — 4 per robot, 12 total
  Real f11, f12, f13, f14 "robot 1 rotor thrusts";
  Real f21, f22, f23, f24 "robot 2 rotor thrusts";
  Real f31, f32, f33, f34 "robot 3 rotor thrusts";

  // Total thrust per robot [N]
  Real fTotal1, fTotal2, fTotal3;
  Real fTotalCmd1, fTotalCmd2, fTotalCmd3;
  Real thrustScale1, thrustScale2, thrustScale3;

  // Thrust vector components [N]
  Real Tx1, Ty1, Tz1, Tx2, Ty2, Tz2, Tx3, Ty3, Tz3;

  // Effective progress [m]
  Real effProg1, effProg2, effProg3;
  Real effVel1, effVel2, effVel3;

  // Desired trajectory
  Real pxDes1, pyDes1, pzDes1, pxDes2, pyDes2, pzDes2, pxDes3, pyDes3, pzDes3;
  Real vxDes1, vyDes1, vzDes1, vxDes2, vyDes2, vzDes2, vxDes3, vyDes3, vzDes3;

  // Delayed peer positions
  Real pxDel1, pyDel1, pzDel1, pxDel2, pyDel2, pzDel2, pxDel3, pyDel3, pzDel3;
  Real delayWeight "0 = no delay, 1 = full delay active";

  // Distance to intersection [m]
  Real distInt1, distInt2, distInt3;
  Boolean inZone1, inZone2, inZone3;

  // Peer in zone (delayed view)
  Boolean peer1InZoneDel "robot 1 in zone, delayed view";
  Boolean peer2InZoneDel "robot 2 in zone, delayed view";
  Boolean peer3InZoneDel "robot 3 in zone, delayed view";

  // Reservation
  Boolean isWaiting1, isWaiting2, isWaiting3;
  Real waitTime1, waitTime2, waitTime3 "accumulated waiting time [s]";

  // Route completion
  Boolean routeComplete1, routeComplete2, routeComplete3;

  // Pairwise distances [m]
  Real dist12, dist13, dist23;
  Real minPairDist "current minimum pairwise distance";
  Real minPairDistRun "running minimum pairwise distance";

  // Tracking errors [m]
  Real trackErr1, trackErr2, trackErr3;
  Real maxTrackErr "current max tracking error across robots";
  Real maxTrackErrAfter13 "max tracking error for t >= 13 s";

  // Verification metrics
  Boolean actuatorOK "all rotor thrusts within bounds";
  Real occCount "number of robots currently in intersection zone";
  Boolean mutualExclOK "at most one robot in intersection zone";
  Boolean noCollision "minimum pairwise distance above safe threshold";
  Boolean noNaNInf "no NaN or infinite values detected";
  Boolean allVerified "all verification criteria satisfied";

initial equation
  px1 = -routeHalf;
  py1 = 0.0;
  pz1 = zCruise;
  px2 = 0.0;
  py2 = -routeHalf;
  pz2 = zCruise;
  px3 = -diagHalf;
  py3 = -diagHalf;
  pz3 = zCruise;
  vx1 = 0.0;
  vy1 = 0.0;
  vz1 = 0.0;
  vx2 = 0.0;
  vy2 = 0.0;
  vz2 = 0.0;
  vx3 = 0.0;
  vy3 = 0.0;
  vz3 = 0.0;
  effProg1 = 0.0;
  effProg2 = 0.0;
  effProg3 = 0.0;
  waitTime1 = 0.0;
  waitTime2 = 0.0;
  waitTime3 = 0.0;
  minPairDistRun = 100.0;
  maxTrackErrAfter13 = 0.0;

equation
  // ===== Message delay disturbance (active during middle third) =====
  delayWeight = if (time >= tFinal / 3.0 and time <= 2.0 * tFinal / 3.0) then 1.0 else 0.0;

  // Delayed positions — fixed delay buffer, weighted by delayWeight
  pxDel1 = (1.0 - delayWeight) * px1 + delayWeight * delay(px1, delayDist, tFinal + 1.0);
  pyDel1 = (1.0 - delayWeight) * py1 + delayWeight * delay(py1, delayDist, tFinal + 1.0);
  pzDel1 = (1.0 - delayWeight) * pz1 + delayWeight * delay(pz1, delayDist, tFinal + 1.0);
  pxDel2 = (1.0 - delayWeight) * px2 + delayWeight * delay(px2, delayDist, tFinal + 1.0);
  pyDel2 = (1.0 - delayWeight) * py2 + delayWeight * delay(py2, delayDist, tFinal + 1.0);
  pzDel2 = (1.0 - delayWeight) * pz2 + delayWeight * delay(pz2, delayDist, tFinal + 1.0);
  pxDel3 = (1.0 - delayWeight) * px3 + delayWeight * delay(px3, delayDist, tFinal + 1.0);
  pyDel3 = (1.0 - delayWeight) * py3 + delayWeight * delay(py3, delayDist, tFinal + 1.0);
  pzDel3 = (1.0 - delayWeight) * pz3 + delayWeight * delay(pz3, delayDist, tFinal + 1.0);

  // ===== Distance to intersection =====
  distInt1 = sqrt(px1 * px1 + py1 * py1 + 1e-10);
  distInt2 = sqrt(px2 * px2 + py2 * py2 + 1e-10);
  distInt3 = sqrt(px3 * px3 + py3 * py3 + 1e-10);
  inZone1 = distInt1 < rInt;
  inZone2 = distInt2 < rInt;
  inZone3 = distInt3 < rInt;

  // ===== Peer in zone (delayed view) =====
  peer1InZoneDel = sqrt(pxDel1 * pxDel1 + pyDel1 * pyDel1 + 1e-10) < rInt;
  peer2InZoneDel = sqrt(pxDel2 * pxDel2 + pyDel2 * pyDel2 + 1e-10) < rInt;
  peer3InZoneDel = sqrt(pxDel3 * pxDel3 + pyDel3 * pyDel3 + 1e-10) < rInt;

  // ===== Decentralized reservation (priority: robot 1 > 2 > 3) =====
  // Robot 1: highest priority, never waits
  isWaiting1 = false;
  // Robot 2: waits if approaching zone and robot 1 is in zone (delayed view)
  isWaiting2 = (distInt2 < rInt + brakeMargin) and (not routeComplete2) and peer1InZoneDel;
  // Robot 3: waits if approaching zone and robot 1 or 2 is in zone (delayed view)
  isWaiting3 = (distInt3 < rInt + brakeMargin) and (not routeComplete3) and (peer1InZoneDel or peer2InZoneDel);

  // ===== Effective progress (freezes when waiting or complete — bounded braking) =====
  der(effProg1) = if (routeComplete1 or isWaiting1) then 0.0 else vCruise;
  der(effProg2) = if (routeComplete2 or isWaiting2) then 0.0 else vCruise;
  der(effProg3) = if (routeComplete3 or isWaiting3) then 0.0 else vCruise;
  effVel1 = if (routeComplete1 or isWaiting1) then 0.0 else vCruise;
  effVel2 = if (routeComplete2 or isWaiting2) then 0.0 else vCruise;
  effVel3 = if (routeComplete3 or isWaiting3) then 0.0 else vCruise;

  // ===== Route completion =====
  routeComplete1 = effProg1 >= routeDist1;
  routeComplete2 = effProg2 >= routeDist2;
  routeComplete3 = effProg3 >= routeDist3;

  // ===== Wait time accumulation =====
  der(waitTime1) = if isWaiting1 then 1.0 else 0.0;
  der(waitTime2) = if isWaiting2 then 1.0 else 0.0;
  der(waitTime3) = if isWaiting3 then 1.0 else 0.0;

  // ===== Desired trajectories =====
  // Robot 1: along x-axis from (-5,0) to (5,0)
  pxDes1 = -routeHalf + effProg1;
  pyDes1 = 0.0;
  pzDes1 = zCruise;
  vxDes1 = effVel1;
  vyDes1 = 0.0;
  vzDes1 = 0.0;

  // Robot 2: along y-axis from (0,-5) to (0,5)
  pxDes2 = 0.0;
  pyDes2 = -routeHalf + effProg2;
  pzDes2 = zCruise;
  vxDes2 = 0.0;
  vyDes2 = effVel2;
  vzDes2 = 0.0;

  // Robot 3: along diagonal from (-d,-d) to (d,d)
  pxDes3 = -diagHalf + effProg3 * cos45;
  pyDes3 = -diagHalf + effProg3 * sin45;
  pzDes3 = zCruise;
  vxDes3 = effVel3 * cos45;
  vyDes3 = effVel3 * sin45;
  vzDes3 = 0.0;

  // ===== Control: thrust vector computation =====
  // Robot 1
  Tx1 = m * (Kp * (pxDes1 - px1) + Kd * (vxDes1 - vx1));
  Ty1 = m * (Kp * (pyDes1 - py1) + Kd * (vyDes1 - vy1));
  Tz1 = m * (Kp * (pzDes1 - pz1) + Kd * (vzDes1 - vz1) + g);
  fTotalCmd1 = sqrt(Tx1 * Tx1 + Ty1 * Ty1 + Tz1 * Tz1 + 1e-10);
  thrustScale1 = if fTotalCmd1 > 1e-6 then min(1.0, 4.0 * fMax / fTotalCmd1) else 0.0;
  fTotal1 = fTotalCmd1 * thrustScale1;
  f11 = fTotal1 / 4.0;
  f12 = fTotal1 / 4.0;
  f13 = fTotal1 / 4.0;
  f14 = fTotal1 / 4.0;

  // Robot 2
  Tx2 = m * (Kp * (pxDes2 - px2) + Kd * (vxDes2 - vx2));
  Ty2 = m * (Kp * (pyDes2 - py2) + Kd * (vyDes2 - vy2));
  Tz2 = m * (Kp * (pzDes2 - pz2) + Kd * (vzDes2 - vz2) + g);
  fTotalCmd2 = sqrt(Tx2 * Tx2 + Ty2 * Ty2 + Tz2 * Tz2 + 1e-10);
  thrustScale2 = if fTotalCmd2 > 1e-6 then min(1.0, 4.0 * fMax / fTotalCmd2) else 0.0;
  fTotal2 = fTotalCmd2 * thrustScale2;
  f21 = fTotal2 / 4.0;
  f22 = fTotal2 / 4.0;
  f23 = fTotal2 / 4.0;
  f24 = fTotal2 / 4.0;

  // Robot 3
  Tx3 = m * (Kp * (pxDes3 - px3) + Kd * (vxDes3 - vx3));
  Ty3 = m * (Kp * (pyDes3 - py3) + Kd * (vyDes3 - vy3));
  Tz3 = m * (Kp * (pzDes3 - pz3) + Kd * (vzDes3 - vz3) + g);
  fTotalCmd3 = sqrt(Tx3 * Tx3 + Ty3 * Ty3 + Tz3 * Tz3 + 1e-10);
  thrustScale3 = if fTotalCmd3 > 1e-6 then min(1.0, 4.0 * fMax / fTotalCmd3) else 0.0;
  fTotal3 = fTotalCmd3 * thrustScale3;
  f31 = fTotal3 / 4.0;
  f32 = fTotal3 / 4.0;
  f33 = fTotal3 / 4.0;
  f34 = fTotal3 / 4.0;

  // ===== Dynamics (point-mass with thrust vectoring) =====
  // Robot 1
  ax1 = Tx1 * thrustScale1 / m;
  ay1 = Ty1 * thrustScale1 / m;
  az1 = Tz1 * thrustScale1 / m - g;
  der(px1) = vx1;
  der(py1) = vy1;
  der(pz1) = vz1;
  der(vx1) = ax1;
  der(vy1) = ay1;
  der(vz1) = az1;

  // Robot 2
  ax2 = Tx2 * thrustScale2 / m;
  ay2 = Ty2 * thrustScale2 / m;
  az2 = Tz2 * thrustScale2 / m - g;
  der(px2) = vx2;
  der(py2) = vy2;
  der(pz2) = vz2;
  der(vx2) = ax2;
  der(vy2) = ay2;
  der(vz2) = az2;

  // Robot 3
  ax3 = Tx3 * thrustScale3 / m;
  ay3 = Ty3 * thrustScale3 / m;
  az3 = Tz3 * thrustScale3 / m - g;
  der(px3) = vx3;
  der(py3) = vy3;
  der(pz3) = vz3;
  der(vx3) = ax3;
  der(vy3) = ay3;
  der(vz3) = az3;

  // ===== Pairwise distances =====
  dist12 = sqrt((px1 - px2) ^ 2 + (py1 - py2) ^ 2 + (pz1 - pz2) ^ 2 + 1e-10);
  dist13 = sqrt((px1 - px3) ^ 2 + (py1 - py3) ^ 2 + (pz1 - pz3) ^ 2 + 1e-10);
  dist23 = sqrt((px2 - px3) ^ 2 + (py2 - py3) ^ 2 + (pz2 - pz3) ^ 2 + 1e-10);
  minPairDist = min(dist12, min(dist13, dist23));

  // Running minimum pairwise distance
  der(minPairDistRun) = 0.0;
  when minPairDist < pre(minPairDistRun) then
    reinit(minPairDistRun, minPairDist);
  end when;

  // ===== Tracking errors =====
  trackErr1 = sqrt((px1 - pxDes1) ^ 2 + (py1 - pyDes1) ^ 2 + (pz1 - pzDes1) ^ 2 + 1e-10);
  trackErr2 = sqrt((px2 - pxDes2) ^ 2 + (py2 - pyDes2) ^ 2 + (pz2 - pzDes2) ^ 2 + 1e-10);
  trackErr3 = sqrt((px3 - pxDes3) ^ 2 + (py3 - pyDes3) ^ 2 + (pz3 - pzDes3) ^ 2 + 1e-10);
  maxTrackErr = max(trackErr1, max(trackErr2, trackErr3));

  // Max tracking error after t = 13 s (sampled at 500 Hz)
  der(maxTrackErrAfter13) = 0.0;
  when sample(13.0, dtSample) then
    reinit(maxTrackErrAfter13, max(maxTrackErr, pre(maxTrackErrAfter13)));
  end when;

  // ===== Intersection occupancy (mutual exclusion) =====
  occCount = (if inZone1 then 1.0 else 0.0) + (if inZone2 then 1.0 else 0.0) + (if inZone3 then 1.0 else 0.0);
  mutualExclOK = occCount <= 1.0;

  // ===== Actuator bounds =====
  actuatorOK = (f11 >= -1e-6 and f11 <= fMax + 1e-6) and
               (f12 >= -1e-6 and f12 <= fMax + 1e-6) and
               (f13 >= -1e-6 and f13 <= fMax + 1e-6) and
               (f14 >= -1e-6 and f14 <= fMax + 1e-6) and
               (f21 >= -1e-6 and f21 <= fMax + 1e-6) and
               (f22 >= -1e-6 and f22 <= fMax + 1e-6) and
               (f23 >= -1e-6 and f23 <= fMax + 1e-6) and
               (f24 >= -1e-6 and f24 <= fMax + 1e-6) and
               (f31 >= -1e-6 and f31 <= fMax + 1e-6) and
               (f32 >= -1e-6 and f32 <= fMax + 1e-6) and
               (f33 >= -1e-6 and f33 <= fMax + 1e-6) and
               (f34 >= -1e-6 and f34 <= fMax + 1e-6);

  // ===== No collision =====
  noCollision = minPairDist >= rSafe;

  // ===== No NaN/Inf (continuous check) =====
  noNaNInf = not (
    px1 <> px1 or py1 <> py1 or pz1 <> pz1 or
    vx1 <> vx1 or vy1 <> vy1 or vz1 <> vz1 or
    px2 <> px2 or py2 <> py2 or pz2 <> pz2 or
    vx2 <> vx2 or vy2 <> vy2 or vz2 <> vz2 or
    px3 <> px3 or py3 <> py3 or pz3 <> pz3 or
    vx3 <> vx3 or vy3 <> vy3 or vz3 <> vz3 or
    abs(px1) > 1e100 or abs(py1) > 1e100 or abs(pz1) > 1e100 or
    abs(px2) > 1e100 or abs(py2) > 1e100 or abs(pz2) > 1e100 or
    abs(px3) > 1e100 or abs(py3) > 1e100 or abs(pz3) > 1e100
  );

  // ===== Overall verification =====
  allVerified = actuatorOK and noCollision and mutualExclOK and noNaNInf and
                routeComplete1 and routeComplete2 and routeComplete3 and
                (maxTrackErrAfter13 < trackErrThreshold);

  annotation (
    Documentation(info = "Three 1.8 kg quadrotors traverse fixed corridor routes that cross at a shared
      central intersection. Decentralized reservation uses priority-based access with bounded braking.
      A controlled 0.174 s message delay disturbance is applied during the middle third of the
      20 s mission at 500 Hz. Verification: actuator bounds (14.6 N/rotor), minimum distance,
      mutual exclusion, waiting time, no collision, route completion, tracking error < 0.52 m
      after 13 s, and no NaN or infinite values."),
    experiment(StopTime = 20.0, Tolerance = 1e-6, Interval = 0.002)
  );
end AirTrioCoordinateF;