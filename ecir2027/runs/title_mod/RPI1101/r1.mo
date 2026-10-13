model GroundPairResilientC
  // ---- Physical parameters ----
  parameter Real m = 14.0 "robot mass [kg]";
  parameter Real r = 0.09 "wheel radius [m]";
  parameter Real b = 0.18 "wheel base [m] (not stated in requirement; assumed finite)";
  parameter Real I_y = 1.2 "yaw inertia [kg.m2] (not stated; assumed finite)";
  parameter Real tauMax = 9.2 "max wheel torque magnitude [N.m]";

  // ---- Mission parameters ----
  parameter Real Ts = 1.0/125 "sample period [s]";
  parameter Real Tend = 12.0 "mission duration [s]";
  parameter Real tDropStart = 5.0 "dropout start [s], within middle third (4-8 s)";
  parameter Real tDropEnd = 5.9 "dropout end [s], 0.9 s duration";
  parameter Real routeSpeed = 0.7 "route reference speed [m/s]";
  parameter Real formOffX = 1.0 "formation offset x [m]";
  parameter Real formOffY = 0.5 "formation offset y [m]";
  parameter Real distForce = 3.0 "shared environmental disturbance force [N]";
  parameter Real safeDist = 0.6 "collision avoidance safe distance [m]";
  parameter Real kAvoid = 2.5 "collision avoidance gain";
  parameter Real kpV = 4.0 "linear velocity loop gain";
  parameter Real kpW = 5.0 "angular velocity loop gain";
  parameter Real kpH = 1.5 "heading P gain";
  parameter Real eps = 1.0e-9 "regularization for divisors";

  // ---- Communication & disturbance ----
  Boolean commOK "communication available flag";
  Real fEnvX "shared environmental disturbance x [N]";
  Real fEnvY "shared environmental disturbance y [N]";

  // ---- Robot 1 (leader) states ----
  Real x1, y1, th1, v1, w1;
  Real tauR1, tauL1;
  Real x1Ref, y1Ref;

  // ---- Robot 2 (follower) states ----
  Real x2, y2, th2, v2, w2;
  Real tauR2, tauL2;

  // ---- Last-received peer states with timestamps ----
  discrete Real x1Last, y1Last, th1Last, v1Last, w1Last, t1Last;
  discrete Real x2Last, y2Last, th2Last, v2Last, w2Last, t2Last;

  // ---- Predicted (finite-estimate) peer states ----
  Real x1Pred, y1Pred, th1Pred;
  Real x2Pred, y2Pred, th2Pred;

  // ---- Seen peer state (actual if commOK, predicted if dropout) ----
  Real x1Seen, y1Seen;
  Real x2Seen, y2Seen;

  // ---- Sensors ----
  Real encR1, encL1, encR2, encL2 "wheel encoder angular positions [rad]";
  Real imuW1, imuW2 "IMU yaw rate [rad/s]";
  Real lidarRange "inter-robot lidar range [m]";

  // ---- Control intermediates ----
  Real v_des1, w_des1, v_des2, w_des2;
  Real tauSum1, tauDiff1, tauSum2, tauDiff2;
  Real tauR1raw, tauL1raw, tauR2raw, tauL2raw;
  Real hd1, hd2, hdErr1, hdErr2;
  Real ex1, ey1, dist1, ex2, ey2, dist2;
  Real rep1, rep2, x1Tgt, y1Tgt, x2Tgt, y2Tgt;
  Real ax12, ay12, d12, ax21, ay21, d21;

  // ---- Observables: errors & latches ----
  Real trackErr1 "primary route tracking error [m]";
  Real trackErr2 "follower tracking error [m]";
  Real formErrActual "instantaneous formation error [m]";
  discrete Real formErrDeg(start=0.0) "degraded formation error at dropout end [m]";
  discrete Real formErrRec(start=0.0) "recovered formation error at mission end [m]";
  discrete Boolean routeDone(start=false) "route completion flag";

initial equation
  x1 = 0.0; y1 = 0.0; th1 = 0.0; v1 = 0.0; w1 = 0.0;
  x2 = formOffX; y2 = formOffY; th2 = 0.0; v2 = 0.0; w2 = 0.0;
  encR1 = 0.0; encL1 = 0.0; encR2 = 0.0; encL2 = 0.0;

equation
  // Communication availability: dropout during middle third
  commOK = not (time >= tDropStart and time <= tDropEnd);

  // Shared environmental disturbance only during dropout
  if (time >= tDropStart and time <= tDropEnd) then
    fEnvX = distForce;
    fEnvY = 0.0;
  else
    fEnvX = 0.0;
    fEnvY = 0.0;
  end if;

  // ---- Route reference (leader) ----
  x1Ref = routeSpeed * time;
  y1Ref = 0.0;

  // ---- Robot 1 dynamics ----
  der(x1) = v1 * cos(th1);
  der(y1) = v1 * sin(th1);
  der(th1) = w1;
  m * der(v1) = (tauR1 + tauL1) / r + fEnvX * cos(th1) + fEnvY * sin(th1);
  I_y * der(w1) = (tauR1 - tauL1) / r * (b / 2.0);

  // ---- Robot 2 dynamics ----
  der(x2) = v2 * cos(th2);
  der(y2) = v2 * sin(th2);
  der(th2) = w2;
  m * der(v2) = (tauR2 + tauL2) / r + fEnvX * cos(th2) + fEnvY * sin(th2);
  I_y * der(w2) = (tauR2 - tauL2) / r * (b / 2.0);

  // ---- Wheel encoders (angular position of each wheel) ----
  der(encR1) = v1 / r + w1 * b / (2.0 * r);
  der(encL1) = v1 / r - w1 * b / (2.0 * r);
  der(encR2) = v2 / r + w2 * b / (2.0 * r);
  der(encL2) = v2 / r - w2 * b / (2.0 * r);

  // ---- IMU yaw rate ----
  imuW1 = w1;
  imuW2 = w2;

  // ---- Lidar range between robots ----
  lidarRange = sqrt((x2 - x1)^2 + (y2 - y1)^2 + eps);

  // ---- Predicted peer states (constant-velocity finite estimate) ----
  x1Pred = x1Last + v1Last * cos(th1Last) * (time - t1Last);
  y1Pred = y1Last + v1Last * sin(th1Last) * (time - t1Last);
  th1Pred = th1Last + w1Last * (time - t1Last);
  x2Pred = x2Last + v2Last * cos(th2Last) * (time - t2Last);
  y2Pred = y2Last + v2Last * sin(th2Last) * (time - t2Last);
  th2Pred = th2Last + w2Last * (time - t2Last);

  // ---- Seen peer state: actual when commOK, predicted during dropout ----
  x1Seen = if commOK then x1 else x1Pred;
  y1Seen = if commOK then y1 else y1Pred;
  x2Seen = if commOK then x2 else x2Pred;
  y2Seen = if commOK then y2 else y2Pred;

  // ---- Collision avoidance (repulsion magnitudes, finite & non-negative) ----
  ax12 = x2Seen - x1;
  ay12 = y2Seen - y1;
  d12 = sqrt(ax12^2 + ay12^2 + eps);
  rep1 = if d12 < safeDist then kAvoid * (safeDist - d12) else 0.0;

  ax21 = x2 - x1Seen;
  ay21 = y2 - y1Seen;
  d21 = sqrt(ax21^2 + ay21^2 + eps);
  rep2 = if d21 < safeDist then kAvoid * (safeDist - d21) else 0.0;

  // ---- Leader target (route with repulsion away from follower) ----
  x1Tgt = x1Ref - rep1 * ax12 / d12;
  y1Tgt = y1Ref - rep1 * ay12 / d12;
  ex1 = x1Tgt - x1;
  ey1 = y1Tgt - y1;
  dist1 = sqrt(ex1^2 + ey1^2 + eps);
  hd1 = atan2(ey1, ex1);
  hdErr1 = atan2(sin(hd1 - th1), cos(hd1 - th1));
  w_des1 = kpH * hdErr1;
  v_des1 = routeSpeed * cos(hdErr1) * (1.0 - exp(-dist1));

  // ---- Follower target (formation wrt seen leader, with repulsion) ----
  x2Tgt = (x1Seen + formOffX) - rep2 * (x2 - x1Seen) / d21;
  y2Tgt = (y1Seen + formOffY) - rep2 * (y2 - y1Seen) / d21;
  ex2 = x2Tgt - x2;
  ey2 = y2Tgt - y2;
  dist2 = sqrt(ex2^2 + ey2^2 + eps);
  hd2 = atan2(ey2, ex2);
  hdErr2 = atan2(sin(hd2 - th2), cos(hd2 - th2));
  w_des2 = kpH * hdErr2;
  v_des2 = routeSpeed * cos(hdErr2) * (1.0 - exp(-dist2));

  // ---- Wheel torque commands (bounded) ----
  tauSum1 = m * r * kpV * (v_des1 - v1);
  tauDiff1 = 2.0 * I_y * r * kpW * (w_des1 - w1) / b;
  tauR1raw = (tauSum1 + tauDiff1) / 2.0;
  tauL1raw = (tauSum1 - tauDiff1) / 2.0;
  tauR1 = max(-tauMax, min(tauMax, tauR1raw));
  tauL1 = max(-tauMax, min(tauMax, tauL1raw));

  tauSum2 = m * r * kpV * (v_des2 - v2);
  tauDiff2 = 2.0 * I_y * r * kpW * (w_des2 - w2) / b;
  tauR2raw = (tauSum2 + tauDiff2) / 2.0;
  tauL2raw = (tauSum2 - tauDiff2) / 2.0;
  tauR2 = max(-tauMax, min(tauMax, tauR2raw));
  tauL2 = max(-tauMax, min(tauMax, tauL2raw));

  // ---- Tracking & formation errors (finite, no NaN) ----
  trackErr1 = sqrt((x1Ref - x1)^2 + (y1Ref - y1)^2 + eps);
  trackErr2 = sqrt((x2Tgt - x2)^2 + (y2Tgt - y2)^2 + eps);
  formErrActual = sqrt((x2 - (x1 + formOffX))^2 + (y2 - (y1 + formOffY))^2 + eps);

  // ---- Synchronized 125 Hz trace sampling of last-received peer state ----
  when sample(0, Ts) then
    x1Last = if commOK then x1 else pre(x1Last);
    y1Last = if commOK then y1 else pre(y1Last);
    th1Last = if commOK then th1 else pre(th1Last);
    v1Last = if commOK then v1 else pre(v1Last);
    w1Last = if commOK then w1 else pre(w1Last);
    t1Last = if commOK then time else pre(t1Last);
    x2Last = if commOK then x2 else pre(x2Last);
    y2Last = if commOK then y2 else pre(y2Last);
    th2Last = if commOK then th2 else pre(th2Last);
    v2Last = if commOK then v2 else pre(v2Last);
    w2Last = if commOK then w2 else pre(w2Last);
    t2Last = if commOK then time else pre(t2Last);
  end when;

  // ---- Latch degraded formation error at dropout end ----
  when time >= tDropEnd then
    formErrDeg = sqrt((x2 - (x1 + formOffX))^2 + (y2 - (y1 + formOffY))^2 + eps);
  end when;

  // ---- Latch recovered formation error & route completion at mission end ----
  when terminal() then
    formErrRec = sqrt((x2 - (x1 + formOffX))^2 + (y2 - (y1 + formOffY))^2 + eps);
    routeDone = (x1 >= routeSpeed * Tend - 0.5);
  end when;

  annotation (
    Documentation(info="Two 14 kg differential-drive robots (0.09 m wheels) in one shared scene, "
      + "distributed leader-follower control with constant-velocity peer prediction during a "
      + "0.9 s communication dropout (5.0-5.9 s, within the middle third of a 12 s, 125 Hz mission). "
      + "Four bounded wheel-torque channels (|tau|<=9.2 N.m). Shared environmental disturbance applied "
      + "during dropout. Tracks route, formation, collision avoidance, degraded/recovered formation "
      + "errors, and finite estimates. Primary tracking error targeted below 0.63 m after 7.8 s."),
    experiment(StartTime=0.0, StopTime=12.0, Tolerance=1.0e-6, Interval=1.0/125)
  );
end GroundPairResilientC;