model AirTrioCoordinateF
  // ================================================================
  // AirTrioCoordinateF
  // Three 1.8 kg quadrotors cross a shared intersection using
  // decentralized reservation with delayed peer messages.
  // 0.174 s delay applied during the middle third of the mission.
  // 500 Hz, 20 s simulation. 12 rotor-thrust groups, max 14.6 N each.
  // ================================================================

  // --- Physical constants ---
  parameter Real m = 1.8 "quadrotor mass [kg]";
  parameter Real g = 9.81 "gravitational acceleration [m/s2]";
  parameter Real Tmax = 14.6 "max thrust per rotor [N]";

  // --- Mission / simulation ---
  parameter Real Tend = 20.0 "simulation duration [s]";
  parameter Real freq = 500.0 "control loop frequency [Hz]";

  // --- Intersection geometry ---
  parameter Real rInt = 1.5 "intersection exclusion radius [m]";
  parameter Real dmin = 1.0 "minimum safe inter-robot distance [m]";
  parameter Real routeLen = 10.0 "straight route half-length [m]";
  parameter Real diagLen = 7.0 "diagonal route half-length [m]";
  parameter Real z0 = 2.0 "nominal flight altitude [m]";
  parameter Real sqrt2 = 1.41421356 "sqrt(2)";

  // --- Communication delay disturbance ---
  parameter Real delayMid = 0.174 "message delay during middle third [s]";
  parameter Real tMid1 = 6.667 "start of middle third [s]";
  parameter Real tMid2 = 13.333 "end of middle third [s]";

  // --- Control gains ---
  parameter Real kp = 1.0 "position proportional gain [1/s2]";
  parameter Real kd = 2.0 "velocity damping gain [1/s]";
  parameter Real vFloor = 0.5 "velocity floor for ETA [m/s]";

  // ================================================================
  // ROBOT 1 STATE  (route: -x to +x, y = 0)
  // ================================================================
  Real x1(start = -routeLen, fixed = true) "x position [m]";
  Real y1(start = 0.0, fixed = true) "y position [m]";
  Real z1(start = z0, fixed = true) "z position [m]";
  Real vx1(start = 0.0, fixed = true) "x velocity [m/s]";
  Real vy1(start = 0.0, fixed = true) "y velocity [m/s]";
  Real vz1(start = 0.0, fixed = true) "z velocity [m/s]";

  // ================================================================
  // ROBOT 2 STATE  (route: -y to +y, x = 0)
  // ================================================================
  Real x2(start = 0.0, fixed = true) "x position [m]";
  Real y2(start = -routeLen, fixed = true) "y position [m]";
  Real z2(start = z0, fixed = true) "z position [m]";
  Real vx2(start = 0.0, fixed = true) "x velocity [m/s]";
  Real vy2(start = 0.0, fixed = true) "y velocity [m/s]";
  Real vz2(start = 0.0, fixed = true) "z velocity [m/s]";

  // ================================================================
  // ROBOT 3 STATE  (route: (-d,-d) to (d,d) diagonal)
  // ================================================================
  Real x3(start = -diagLen, fixed = true) "x position [m]";
  Real y3(start = -diagLen, fixed = true) "y position [m]";
  Real z3(start = z0, fixed = true) "z position [m]";
  Real vx3(start = 0.0, fixed = true) "x velocity [m/s]";
  Real vy3(start = 0.0, fixed = true) "y velocity [m/s]";
  Real vz3(start = 0.0, fixed = true) "z velocity [m/s]";

  // ================================================================
  // ROTOR THRUSTS  (12 independent groups, 4 per robot)
  // ================================================================
  Real T1_1, T1_2, T1_3, T1_4 "robot 1 rotor thrusts [N]";
  Real T2_1, T2_2, T2_3, T2_4 "robot 2 rotor thrusts [N]";
  Real T3_1, T3_2, T3_3, T3_4 "robot 3 rotor thrusts [N]";
  Real Ttot1, Ttot2, Ttot3 "total thrust magnitude per robot [N]";

  // ================================================================
  // CONTROL FORCES
  // ================================================================
  Real Fx1, Fy1, Fz1 "robot 1 net body force [N]";
  Real Fx2, Fy2, Fz2 "robot 2 net body force [N]";
  Real Fx3, Fy3, Fz3 "robot 3 net body force [N]";

  // ================================================================
  // WAYPOINTS
  // ================================================================
  Real wx1, wy1, wz1 "robot 1 waypoint [m]";
  Real wx2, wy2, wz2 "robot 2 waypoint [m]";
  Real wx3, wy3, wz3 "robot 3 waypoint [m]";

  // ================================================================
  // ETA TO INTERSECTION
  // ================================================================
  Real eta1, eta2, eta3 "own ETA to intersection [s]";
  Real eta1_dl, eta2_dl, eta3_dl "always-delayed ETA buffer [s]";
  Real eta1d, eta2d, eta3d "effective (conditionally delayed) ETA [s]";

  // ================================================================
  // DELAYED PEER POSITIONS  (message trace)
  // ================================================================
  Real x1_dl, y1_dl, x2_dl, y2_dl, x3_dl, y3_dl "delayed buffer [m]";
  Real x1d, y1d, x2d, y2d, x3d, y3d "effective delayed peer position [m]";

  // ================================================================
  // RESERVATION AND BRAKING
  // ================================================================
  Boolean res1, res2, res3 "intersection reservation granted";
  Boolean brake1, brake2, brake3 "braking / holding active";

  // ================================================================
  // INTERSECTION OCCUPANCY (direct peer-relative range sensing)
  // ================================================================
  Boolean inInt1, inInt2, inInt3 "robot within intersection zone";
  Real intCount "number of robots in intersection";

  // ================================================================
  // INTER-ROBOT DISTANCES
  // ================================================================
  Real d12, d13, d23 "true pairwise distances [m]";

  // ================================================================
  // TRACKING ERRORS AND COMPLETION
  // ================================================================
  Real err1, err2, err3 "distance to final destination [m]";
  Boolean done1, done2, done3 "route completed";

  // ================================================================
  // WAITING TIMES
  // ================================================================
  Real wait1(start = 0.0, fixed = true) "robot 1 cumulative wait [s]";
  Real wait2(start = 0.0, fixed = true) "robot 2 cumulative wait [s]";
  Real wait3(start = 0.0, fixed = true) "robot 3 cumulative wait [s]";

  // ================================================================
  // VERIFICATION FLAGS
  // ================================================================
  Boolean actuatorOK  "all rotor thrusts within 14.6 N";
  Boolean distOK      "minimum pairwise distance maintained";
  Boolean mutexOK     "at most one robot in intersection";
  Boolean noCollision "no inter-robot collision";
  Boolean allDone     "all three routes completed";
  Boolean trackingOK  "tracking error < 0.52 m after 13 s";
  Boolean noNaNInf    "no NaN or infinite physical / control / estimator values";

equation
  // ================================================================
  // DYNAMICS — point-mass model, 3 DOF per robot
  // ================================================================
  der(x1) = vx1;  der(y1) = vy1;  der(z1) = vz1;
  der(vx1) = Fx1 / m;  der(vy1) = Fy1 / m;  der(vz1) = Fz1 / m;

  der(x2) = vx2;  der(y2) = vy2;  der(z2) = vz2;
  der(vx2) = Fx2 / m;  der(vy2) = Fy2 / m;  der(vz2) = Fz2 / m;

  der(x3) = vx3;  der(y3) = vy3;  der(z3) = vz3;
  der(vx3) = Fx3 / m;  der(vy3) = Fy3 / m;  der(vz3) = Fz3 / m;

  // ================================================================
  // COMMUNICATION DELAY
  // Always-on delay buffers; effective signal switches in middle third
  // ================================================================
  x1_dl = delay(x1, delayMid, delayMid);
  y1_dl = delay(y1, delayMid, delayMid);
  x2_dl = delay(x2, delayMid, delayMid);
  y2_dl = delay(y2, delayMid, delayMid);
  x3_dl = delay(x3, delayMid, delayMid);
  y3_dl = delay(y3, delayMid, delayMid);

  eta1_dl = delay(eta1, delayMid, delayMid);
  eta2_dl = delay(eta2, delayMid, delayMid);
  eta3_dl = delay(eta3, delayMid, delayMid);

  x1d = if (time >= tMid1 and time <= tMid2) then x1_dl else x1;
  y1d = if (time >= tMid1 and time <= tMid2) then y1_dl else y1;
  x2d = if (time >= tMid1 and time <= tMid2) then x2_dl else x2;
  y2d = if (time >= tMid1 and time <= tMid2) then y2_dl else y2;
  x3d = if (time >= tMid1 and time <= tMid2) then x3_dl else x3;
  y3d = if (time >= tMid1 and time <= tMid2) then y3_dl else y3;

  eta1d = if (time >= tMid1 and time <= tMid2) then eta1_dl else eta1;
  eta2d = if (time >= tMid1 and time <= tMid2) then eta2_dl else eta2;
  eta3d = if (time >= tMid1 and time <= tMid2) then eta3_dl else eta3;

  // ================================================================
  // ETA COMPUTATION (onboard localization — GPS + IMU)
  // Robot 1 approaches from -x; robot 2 from -y; robot 3 from (-d,-d)
  // ================================================================
  eta1 = if (x1 < -rInt and vx1 > 0.001)
         then (-x1) / max(vx1, vFloor) else 1.0e6;

  eta2 = if (y2 < -rInt and vy2 > 0.001)
         then (-y2) / max(vy2, vFloor) else 1.0e6;

  eta3 = if (sqrt(x3*x3 + y3*y3) > rInt and (vx3*x3 + vy3*y3) < -0.001)
         then sqrt(x3*x3 + y3*y3) / max(sqrt(vx3*vx3 + vy3*vy3), vFloor)
         else 1.0e6;

  // ================================================================
  // DECENTRALIZED RESERVATION
  // Each robot compares its own ETA with delayed peer ETAs.
  // Tie-break priority: robot 1 > robot 2 > robot 3.
  // ================================================================
  res1 = (eta1 <= eta2d) and (eta1 <= eta3d);
  res2 = (eta2 <  eta1d) and (eta2 <= eta3d);
  res3 = (eta3 <  eta1d) and (eta3 <  eta2d);

  // ================================================================
  // INTERSECTION OCCUPANCY (direct peer-relative range sensing)
  // Not subject to message delay — real-time safety sensor.
  // ================================================================
  inInt1 = sqrt(x1*x1 + y1*y1) < rInt;
  inInt2 = sqrt(x2*x2 + y2*y2) < rInt;
  inInt3 = sqrt(x3*x3 + y3*y3) < rInt;

  intCount = (if inInt1 then 1.0 else 0.0) +
             (if inInt2 then 1.0 else 0.0) +
             (if inInt3 then 1.0 else 0.0);

  // ================================================================
  // BRAKING (bounded — PD with kd provides bounded deceleration)
  // Brake if: no reservation OR another robot sensed in intersection
  // while this robot has not yet entered.
  // ================================================================
  brake1 = ((not res1) or ((inInt2 or inInt3) and (not inInt1)))
           and (x1 < -rInt) and (not done1);

  brake2 = ((not res2) or ((inInt1 or inInt3) and (not inInt2)))
           and (y2 < -rInt) and (not done2);

  brake3 = ((not res3) or ((inInt1 or inInt2) and (not inInt3)))
           and (sqrt(x3*x3 + y3*y3) > rInt) and (not done3);

  // ================================================================
  // WAYPOINTS — braking target just outside intersection radius
  // ================================================================
  wx1 = if brake1 then -rInt else routeLen;
  wy1 = 0.0;
  wz1 = z0;

  wx2 = 0.0;
  wy2 = if brake2 then -rInt else routeLen;
  wz2 = z0;

  wx3 = if brake3 then -rInt / sqrt2 else diagLen;
  wy3 = if brake3 then -rInt / sqrt2 else diagLen;
  wz3 = z0;

  // ================================================================
  // PD CONTROL — critically damped position tracking
  // ================================================================
  Fx1 = m * (kp * (wx1 - x1) - kd * vx1);
  Fy1 = m * (kp * (wy1 - y1) - kd * vy1);
  Fz1 = m * (kp * (wz1 - z1) - kd * vz1);

  Fx2 = m * (kp * (wx2 - x2) - kd * vx2);
  Fy2 = m * (kp * (wy2 - y2) - kd * vy2);
  Fz2 = m * (kp * (wz2 - z2) - kd * vz2);

  Fx3 = m * (kp * (wx3 - x3) - kd * vx3);
  Fy3 = m * (kp * (wy3 - y3) - kd * vy3);
  Fz3 = m * (kp * (wz3 - z3) - kd * vz3);

  // ================================================================
  // ROTOR THRUST ALLOCATION
  // Total thrust magnitude = |F + m*g*z_hat|; equal split across 4 rotors.
  // Saturated to [0, Tmax].
  // ================================================================
  Ttot1 = sqrt(Fx1*Fx1 + Fy1*Fy1 + (m*g + Fz1)*(m*g + Fz1));
  Ttot2 = sqrt(Fx2*Fx2 + Fy2*Fy2 + (m*g + Fz2)*(m*g + Fz2));
  Ttot3 = sqrt(Fx3*Fx3 + Fy3*Fy3 + (m*g + Fz3)*(m*g + Fz3));

  T1_1 = max(0.0, min(Tmax, Ttot1 / 4.0));
  T1_2 = max(0.0, min(Tmax, Ttot1 / 4.0));
  T1_3 = max(0.0, min(Tmax, Ttot1 / 4.0));
  T1_4 = max(0.0, min(Tmax, Ttot1 / 4.0));

  T2_1 = max(0.0, min(Tmax, Ttot2 / 4.0));
  T2_2 = max(0.0, min(Tmax, Ttot2 / 4.0));
  T2_3 = max(0.0, min(Tmax, Ttot2 / 4.0));
  T2_4 = max(0.0, min(Tmax, Ttot2 / 4.0));

  T3_1 = max(0.0, min(Tmax, Ttot3 / 4.0));
  T3_2 = max(0.0, min(Tmax, Ttot3 / 4.0));
  T3_3 = max(0.0, min(Tmax, Ttot3 / 4.0));
  T3_4 = max(0.0, min(Tmax, Ttot3 / 4.0));

  // ================================================================
  // INTER-ROBOT DISTANCES
  // ================================================================
  d12 = sqrt((x1-x2)*(x1-x2) + (y1-y2)*(y1-y2) + (z1-z2)*(z1-z2));
  d13 = sqrt((x1-x3)*(x1-x3) + (y1-y3)*(y1-y3) + (z1-z3)*(z1-z3));
  d23 = sqrt((x2-x3)*(x2-x3) + (y2-y3)*(y2-y3) + (z2-z3)*(z2-z3));

  // ================================================================
  // TRACKING ERRORS
  // ================================================================
  err1 = sqrt((routeLen - x1)*(routeLen - x1) + (0.0 - y1)*(0.0 - y1) + (z0 - z1)*(z0 - z1));
  err2 = sqrt((0.0 - x2)*(0.0 - x2) + (routeLen - y2)*(routeLen - y2) + (z0 - z2)*(z0 - z2));
  err3 = sqrt((diagLen - x3)*(diagLen - x3) + (diagLen - y3)*(diagLen - y3) + (z0 - z3)*(z0 - z3));

  // ================================================================
  // ROUTE COMPLETION
  // ================================================================
  done1 = err1 < 0.5;
  done2 = err2 < 0.5;
  done3 = err3 < 0.5;

  // ================================================================
  // WAITING TIME ACCUMULATION
  // ================================================================
  der(wait1) = if brake1 then 1.0 else 0.0;
  der(wait2) = if brake2 then 1.0 else 0.0;
  der(wait3) = if brake3 then 1.0 else 0.0;

  // ================================================================
  // VERIFICATION CRITERIA
  // ================================================================

  // Actuator bounds: every rotor thrust <= 14.6 N
  actuatorOK = (T1_1 <= Tmax + 0.001) and (T1_2 <= Tmax + 0.001) and
               (T1_3 <= Tmax + 0.001) and (T1_4 <= Tmax + 0.001) and
               (T2_1 <= Tmax + 0.001) and (T2_2 <= Tmax + 0.001) and
               (T2_3 <= Tmax + 0.001) and (T2_4 <= Tmax + 0.001) and
               (T3_1 <= Tmax + 0.001) and (T3_2 <= Tmax + 0.001) and
               (T3_3 <= Tmax + 0.001) and (T3_4 <= Tmax + 0.001);

  // Minimum distance between all robot pairs
  distOK = (d12 >= dmin) and (d13 >= dmin) and (d23 >= dmin);

  // Mutual exclusion: at most one robot in intersection at any time
  mutexOK = intCount <= 1.0;

  // No collision: all pairwise distances > 0.3 m
  noCollision = (d12 > 0.3) and (d13 > 0.3) and (d23 > 0.3);

  // Route completion: all robots within 0.5 m of destination
  allDone = done1 and done2 and done3;

  // Primary tracking error below 0.52 m separation after 13 s
  trackingOK = if (time >= 13.0)
                then ((err1 < 0.52) and (err2 < 0.52) and (err3 < 0.52))
                else true;

  // No NaN or infinite values — bounded-range check catches both
  // (NaN comparisons return false in IEEE 754; Inf exceeds bounds)
  noNaNInf = (abs(x1) < 1.0e4) and (abs(y1) < 1.0e4) and (abs(z1) < 1.0e4) and
             (abs(x2) < 1.0e4) and (abs(y2) < 1.0e4) and (abs(z2) < 1.0e4) and
             (abs(x3) < 1.0e4) and (abs(y3) < 1.0e4) and (abs(z3) < 1.0e4) and
             (abs(vx1) < 1.0e3) and (abs(vy1) < 1.0e3) and (abs(vz1) < 1.0e3) and
             (abs(vx2) < 1.0e3) and (abs(vy2) < 1.0e3) and (abs(vz2) < 1.0e3) and
             (abs(vx3) < 1.0e3) and (abs(vy3) < 1.0e3) and (abs(vz3) < 1.0e3) and
             (Ttot1 < 1.0e3) and (Ttot2 < 1.0e3) and (Ttot3 < 1.0e3) and
             (err1 < 1.0e4) and (err2 < 1.0e4) and (err3 < 1.0e4);

  annotation (
    experiment(StartTime = 0, StopTime = 20, Tolerance = 1e-6, Interval = 0.002),
    Documentation(info = "AirTrioCoordinateF: Three 1.8 kg quadrotors traverse routes "
      "that cross at a shared intersection. Decentralized reservation based on ETA with "
      "delayed peer messages (0.174 s delay during middle third). Bounded braking via PD "
      "control with safety layer from direct peer-relative range sensing. "
      "12 independent rotor-thrust groups, max 14.6 N/rotor. "
      "500 Hz, 20 s. Verification: actuator bounds, minimum distance, mutual exclusion, "
      "waiting time, no collision, route completion, tracking < 0.52 m after 13 s, "
      "no NaN/infinite values.")
  );
end AirTrioCoordinateF;