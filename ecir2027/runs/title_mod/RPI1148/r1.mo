model AirTrioResilientB
  "Three-quadrotor resilient formation with communication dropout and recovery";

  // Physical parameters
  parameter Real m_quad = 1.8 "Quadrotor mass [kg]";
  parameter Real g_const = 9.81 "Gravitational acceleration [m/s2]";
  parameter Real fMax = 9.84 "Max rotor thrust command per rotor [N]";
  parameter Real dSafe = 1.0 "Minimum safe separation [m]";

  // Control gains
  parameter Real kp_track = 3.0 "Route tracking proportional gain [1/s2]";
  parameter Real kv_track = 2.5 "Route tracking velocity gain [1/s]";
  parameter Real kp_form = 2.0 "Formation position gain [1/s2]";
  parameter Real kv_form = 1.5 "Formation velocity gain [1/s]";
  parameter Real kp_coll = 10.0 "Collision avoidance gain [m/s2]";

  // Formation geometry (equilateral triangle, 1.5 m side)
  parameter Real form12_x = 1.5 "Desired offset Q1->Q2 x [m]";
  parameter Real form12_y = 0.866 "Desired offset Q1->Q2 y [m]";
  parameter Real form12_z = 0.0 "Desired offset Q1->Q2 z [m]";
  parameter Real form13_x = 1.5 "Desired offset Q1->Q3 x [m]";
  parameter Real form13_y = -0.866 "Desired offset Q1->Q3 y [m]";
  parameter Real form13_z = 0.0 "Desired offset Q1->Q3 z [m]";
  parameter Real d23_x = 0.0 "Desired offset Q2->Q3 x [m]";
  parameter Real d23_y = -1.732 "Desired offset Q2->Q3 y [m]";
  parameter Real d23_z = 0.0 "Desired offset Q2->Q3 z [m]";

  // Mission parameters
  parameter Real tDropStart = 3.33 "Communication dropout start [s]";
  parameter Real tDropDur = 0.7 "Dropout duration [s]";
  parameter Real vRoute = 0.35 "Route forward speed [m/s]";
  parameter Real zNom = 2.0 "Nominal flight altitude [m]";

  // Shared disturbance (applied during dropout only)
  parameter Real distX = 0.25 "Shared disturbance force x [N]";
  parameter Real distY = 0.0 "Shared disturbance force y [N]";
  parameter Real distZ = 0.0 "Shared disturbance force z [N]";

  // ===== Robot 1 states =====
  Real x1(start = 0.0) "Q1 x position [m]";
  Real y1(start = 0.0) "Q1 y position [m]";
  Real z1(start = 2.0) "Q1 z position [m]";
  Real vx1(start = 0.0) "Q1 x velocity [m/s]";
  Real vy1(start = 0.0) "Q1 y velocity [m/s]";
  Real vz1(start = 0.0) "Q1 z velocity [m/s]";
  Real u1_1 "Q1 rotor 1 thrust [N]";
  Real u1_2 "Q1 rotor 2 thrust [N]";
  Real u1_3 "Q1 rotor 3 thrust [N]";
  Real u1_4 "Q1 rotor 4 thrust [N]";

  // ===== Robot 2 states =====
  Real x2(start = 1.5) "Q2 x position [m]";
  Real y2(start = 0.866) "Q2 y position [m]";
  Real z2(start = 2.0) "Q2 z position [m]";
  Real vx2(start = 0.0) "Q2 x velocity [m/s]";
  Real vy2(start = 0.0) "Q2 y velocity [m/s]";
  Real vz2(start = 0.0) "Q2 z velocity [m/s]";
  Real u2_1 "Q2 rotor 1 thrust [N]";
  Real u2_2 "Q2 rotor 2 thrust [N]";
  Real u2_3 "Q2 rotor 3 thrust [N]";
  Real u2_4 "Q2 rotor 4 thrust [N]";

  // ===== Robot 3 states =====
  Real x3(start = 1.5) "Q3 x position [m]";
  Real y3(start = -0.866) "Q3 y position [m]";
  Real z3(start = 2.0) "Q3 z position [m]";
  Real vx3(start = 0.0) "Q3 x velocity [m/s]";
  Real vy3(start = 0.0) "Q3 y velocity [m/s]";
  Real vz3(start = 0.0) "Q3 z velocity [m/s]";
  Real u3_1 "Q3 rotor 1 thrust [N]";
  Real u3_2 "Q3 rotor 2 thrust [N]";
  Real u3_3 "Q3 rotor 3 thrust [N]";
  Real u3_4 "Q3 rotor 4 thrust [N]";

  // ===== Communication and disturbance =====
  Boolean commActive "True when peer communication is available";
  Real distAppX "Applied disturbance x [N]";
  Real distAppY "Applied disturbance y [N]";
  Real distAppZ "Applied disturbance z [N]";

  // ===== Last received peer states with timestamps (proprioception + exteroception) =====
  Real lpx1(start = 0.0) "Last received Q1 x [m]";
  Real lpy1(start = 0.0) "Last received Q1 y [m]";
  Real lpz1(start = 2.0) "Last received Q1 z [m]";
  Real lvx1_r(start = 0.0) "Last received Q1 vx [m/s]";
  Real lvy1_r(start = 0.0) "Last received Q1 vy [m/s]";
  Real lvz1_r(start = 0.0) "Last received Q1 vz [m/s]";
  Real lt1(start = 0.0) "Last received timestamp from Q1 [s]";

  Real lpx2(start = 1.5) "Last received Q2 x [m]";
  Real lpy2(start = 0.866) "Last received Q2 y [m]";
  Real lpz2(start = 2.0) "Last received Q2 z [m]";
  Real lvx2_r(start = 0.0) "Last received Q2 vx [m/s]";
  Real lvy2_r(start = 0.0) "Last received Q2 vy [m/s]";
  Real lvz2_r(start = 0.0) "Last received Q2 vz [m/s]";
  Real lt2(start = 0.0) "Last received timestamp from Q2 [s]";

  Real lpx3(start = 1.5) "Last received Q3 x [m]";
  Real lpy3(start = -0.866) "Last received Q3 y [m]";
  Real lpz3(start = 2.0) "Last received Q3 z [m]";
  Real lvx3_r(start = 0.0) "Last received Q3 vx [m/s]";
  Real lvy3_r(start = 0.0) "Last received Q3 vy [m/s]";
  Real lvz3_r(start = 0.0) "Last received Q3 vz [m/s]";
  Real lt3(start = 0.0) "Last received timestamp from Q3 [s]";

  // ===== Predicted peer states (dead-reckoning during dropout) =====
  Real px1, py1, pz1, pvx1, pvy1, pvz1;
  Real px2, py2, pz2, pvx2, pvy2, pvz2;
  Real px3, py3, pz3, pvx3, pvy3, pvz3;

  // ===== Control: desired accelerations =====
  Real ax1, ay1, az1, ax2, ay2, az2, ax3, ay3, az3;

  // ===== Thrust allocation =====
  Real T1, T2, T3 "Total thrust magnitude [N]";
  Real Tb1, Tb2, Tb3 "Bounded total thrust [N]";
  Real s1, s2, s3 "Saturation scale factor [-]";

  // ===== Route trajectory =====
  Real routeX, routeY, routeZ;

  // ===== Formation and tracking errors =====
  Real formErr12 "Formation error Q1-Q2 [m]";
  Real formErr13 "Formation error Q1-Q3 [m]";
  Real formErr23 "Formation error Q2-Q3 [m]";
  Real formErrMax "Maximum formation error [m]";
  Real trackErr1 "Q1 primary tracking error [m]";
  Real formErrDegraded(start = 0.0) "Formation error at end of dropout [m]";
  Real formErrRecovered(start = 0.0) "Formation error after recovery at 6.5 s [m]";
  Real trackErr65(start = 0.0) "Tracking error at 6.5 s [m]";

  // ===== Sensor traces =====
  Real gps1_x, gps1_y, gps1_z;
  Real gps2_x, gps2_y, gps2_z;
  Real gps3_x, gps3_y, gps3_z;
  Real range12, range13, range23;

  // ===== Collision avoidance intermediates =====
  Real dist12, dist13, dist23;
  Real coll1x, coll1y, coll1z;
  Real coll2x, coll2y, coll2z;
  Real coll3x, coll3y, coll3z;

  // ===== Mission status =====
  Boolean routeComplete "Route completed flag";

equation
  // ===== Communication availability: dropout in middle third =====
  commActive = not (time >= tDropStart and time < tDropStart + tDropDur);

  // ===== Shared environmental disturbance applied only during dropout =====
  distAppX = if not commActive then distX else 0.0;
  distAppY = if not commActive then distY else 0.0;
  distAppZ = if not commActive then distZ else 0.0;

  // ===== Route trajectory: forward motion in x at constant altitude =====
  routeX = vRoute * time;
  routeY = 0.0;
  routeZ = zNom;

  // ===== Predicted peer states (actual during comm, dead-reckoning during dropout) =====
  px1 = if commActive then x1 else lpx1 + lvx1_r * (time - lt1);
  py1 = if commActive then y1 else lpy1 + lvy1_r * (time - lt1);
  pz1 = if commActive then z1 else lpz1 + lvz1_r * (time - lt1);
  pvx1 = if commActive then vx1 else lvx1_r;
  pvy1 = if commActive then vy1 else lvy1_r;
  pvz1 = if commActive then vz1 else lvz1_r;

  px2 = if commActive then x2 else lpx2 + lvx2_r * (time - lt2);
  py2 = if commActive then y2 else lpy2 + lvy2_r * (time - lt2);
  pz2 = if commActive then z2 else lpz2 + lvz2_r * (time - lt2);
  pvx2 = if commActive then vx2 else lvx2_r;
  pvy2 = if commActive then vy2 else lvy2_r;
  pvz2 = if commActive then vz2 else lvz2_r;

  px3 = if commActive then x3 else lpx3 + lvx3_r * (time - lt3);
  py3 = if commActive then y3 else lpy3 + lvy3_r * (time - lt3);
  pz3 = if commActive then z3 else lpz3 + lvz3_r * (time - lt3);
  pvx3 = if commActive then vx3 else lvx3_r;
  pvy3 = if commActive then vy3 else lvy3_r;
  pvz3 = if commActive then vz3 else lvz3_r;

  // ===== Last received states hold (zero derivative; reinit at dropout start) =====
  der(lpx1) = 0.0;  der(lpy1) = 0.0;  der(lpz1) = 0.0;
  der(lvx1_r) = 0.0; der(lvy1_r) = 0.0; der(lvz1_r) = 0.0; der(lt1) = 0.0;
  der(lpx2) = 0.0;  der(lpy2) = 0.0;  der(lpz2) = 0.0;
  der(lvx2_r) = 0.0; der(lvy2_r) = 0.0; der(lvz2_r) = 0.0; der(lt2) = 0.0;
  der(lpx3) = 0.0;  der(lpy3) = 0.0;  der(lpz3) = 0.0;
  der(lvx3_r) = 0.0; der(lvy3_r) = 0.0; der(lvz3_r) = 0.0; der(lt3) = 0.0;

  // ===== Degraded/recovered error capture state variables =====
  der(formErrDegraded) = 0.0;
  der(formErrRecovered) = 0.0;
  der(trackErr65) = 0.0;

  // ===== Peer-relative range sensing (collision distances from predicted peers) =====
  dist12 = sqrt(max((px2 - x1) * (px2 - x1) + (py2 - y1) * (py2 - y1) + (pz2 - z1) * (pz2 - z1), 0.0001));
  dist13 = sqrt(max((px3 - x1) * (px3 - x1) + (py3 - y1) * (py3 - y1) + (pz3 - z1) * (pz3 - z1), 0.0001));
  dist23 = sqrt(max((px3 - x2) * (px3 - x2) + (py3 - y2) * (py3 - y2) + (pz3 - z2) * (pz3 - z2), 0.0001));

  // ===== Collision avoidance accelerations: Q1 =====
  coll1x = (if dist12 < dSafe then kp_coll * (dSafe - dist12) * (x1 - px2) / max(dist12, 0.01) else 0.0)
         + (if dist13 < dSafe then kp_coll * (dSafe - dist13) * (x1 - px3) / max(dist13, 0.01) else 0.0);
  coll1y = (if dist12 < dSafe then kp_coll * (dSafe - dist12) * (y1 - py2) / max(dist12, 0.01) else 0.0)
         + (if dist13 < dSafe then kp_coll * (dSafe - dist13) * (y1 - py3) / max(dist13, 0.01) else 0.0);
  coll1z = (if dist12 < dSafe then kp_coll * (dSafe - dist12) * (z1 - pz2) / max(dist12, 0.01) else 0.0)
         + (if dist13 < dSafe then kp_coll * (dSafe - dist13) * (z1 - pz3) / max(dist13, 0.01) else 0.0);

  // ===== Collision avoidance accelerations: Q2 =====
  coll2x = (if dist12 < dSafe then kp_coll * (dSafe - dist12) * (x2 - px1) / max(dist12, 0.01) else 0.0)
         + (if dist23 < dSafe then kp_coll * (dSafe - dist23) * (x2 - px3) / max(dist23, 0.01) else 0.0);
  coll2y = (if dist12 < dSafe then kp_coll * (dSafe - dist12) * (y2 - py1) / max(dist12, 0.01) else 0.0)
         + (if dist23 < dSafe then kp_coll * (dSafe - dist23) * (y2 - py3) / max(dist23, 0.01) else 0.0);
  coll2z = (if dist12 < dSafe then kp_coll * (dSafe - dist12) * (z2 - pz1) / max(dist12, 0.01) else 0.0)
         + (if dist23 < dSafe then kp_coll * (dSafe - dist23) * (z2 - pz3) / max(dist23, 0.01) else 0.0);

  // ===== Collision avoidance accelerations: Q3 =====
  coll3x = (if dist13 < dSafe then kp_coll * (dSafe - dist13) * (x3 - px1) / max(dist13, 0.01) else 0.0)
         + (if dist23 < dSafe then kp_coll * (dSafe - dist23) * (x3 - px2) / max(dist23, 0.01) else 0.0);
  coll3y = (if dist13 < dSafe then kp_coll * (dSafe - dist13) * (y3 - py1) / max(dist13, 0.01) else 0.0)
         + (if dist23 < dSafe then kp_coll * (dSafe - dist23) * (y3 - py2) / max(dist23, 0.01) else 0.0);
  coll3z = (if dist13 < dSafe then kp_coll * (dSafe - dist13) * (z3 - pz1) / max(dist13, 0.01) else 0.0)
         + (if dist23 < dSafe then kp_coll * (dSafe - dist23) * (z3 - pz2) / max(dist23, 0.01) else 0.0);

  // ===== Distributed control: Q1 (leader, route tracking + formation) =====
  ax1 = kp_track * (routeX - x1) - kv_track * vx1
      + 0.5 * kp_form * (px2 - x1 - form12_x) - 0.5 * kv_form * (pvx2 - vx1)
      + 0.5 * kp_form * (px3 - x1 - form13_x) - 0.5 * kv_form * (pvx3 - vx1)
      + coll1x;
  ay1 = kp_track * (routeY - y1) - kv_track * vy1
      + 0.5 * kp_form * (py2 - y1 - form12_y) - 0.5 * kv_form * (pvy2 - vy1)
      + 0.5 * kp_form * (py3 - y1 - form13_y) - 0.5 * kv_form * (pvy3 - vy1)
      + coll1y;
  az1 = kp_track * (routeZ - z1) - kv_track * vz1
      + 0.5 * kp_form * (pz2 - z1 - form12_z) - 0.5 * kv_form * (pvz2 - vz1)
      + 0.5 * kp_form * (pz3 - z1 - form13_z) - 0.5 * kv_form * (pvz3 - vz1)
      + coll1z;

  // ===== Distributed control: Q2 (follower, formation with Q1 and Q3) =====
  ax2 = kp_form * (px1 - x2 + form12_x) - kv_form * (pvx1 - vx2)
      + 0.5 * kp_form * (px3 - x2 - d23_x) - 0.5 * kv_form * (pvx3 - vx2)
      + coll2x;
  ay2 = kp_form * (py1 - y2 + form12_y) - kv_form * (pvy1 - vy2)
      + 0.5 * kp_form * (py3 - y2 - d23_y) - 0.5 * kv_form * (pvy3 - vy2)
      + coll2y;
  az2 = kp_form * (pz1 - z2 + form12_z) - kv_form * (pvz1 - vz2)
      + 0.5 * kp_form * (pz3 - z2 - d23_z) - 0.5 * kv_form * (pvz3 - vz2)
      + coll2z;

  // ===== Distributed control: Q3 (follower, formation with Q1 and Q2) =====
  ax3 = kp_form * (px1 - x3 + form13_x) - kv_form * (pvx1 - vx3)
      + 0.5 * kp_form * (px2 - x3 + d23_x) - 0.5 * kv_form * (pvx2 - vx3)
      + coll3x;
  ay3 = kp_form * (py1 - y3 + form13_y) - kv_form * (pvy1 - vy3)
      + 0.5 * kp_form * (py2 - y3 - d23_y) - 0.5 * kv_form * (pvy2 - vy3)
      + coll3y;
  az3 = kp_form * (pz1 - z3 + form13_z) - kv_form * (pvz1 - vz3)
      + 0.5 * kp_form * (pz2 - z3 + d23_z) - 0.5 * kv_form * (pvz2 - vz3)
      + coll3z;

  // ===== Thrust allocation: total thrust magnitude from desired acceleration =====
  T1 = sqrt(max((m_quad * ax1) * (m_quad * ax1)
              + (m_quad * ay1) * (m_quad * ay1)
              + (m_quad * (az1 + g_const)) * (m_quad * (az1 + g_const)), 0.0001));
  T2 = sqrt(max((m_quad * ax2) * (m_quad * ax2)
              + (m_quad * ay2) * (m_quad * ay2)
              + (m_quad * (az2 + g_const)) * (m_quad * (az2 + g_const)), 0.0001));
  T3 = sqrt(max((m_quad * ax3) * (m_quad * ax3)
              + (m_quad * ay3) * (m_quad * ay3)
              + (m_quad * (az3 + g_const)) * (m_quad * (az3 + g_const)), 0.0001));

  // ===== Twelve independent rotor-thrust commands with actuator bounds =====
  u1_1 = if T1 / 4.0 > fMax then fMax else T1 / 4.0;
  u1_2 = if T1 / 4.0 > fMax then fMax else T1 / 4.0;
  u1_3 = if T1 / 4.0 > fMax then fMax else T1 / 4.0;
  u1_4 = if T1 / 4.0 > fMax then fMax else T1 / 4.0;
  u2_1 = if T2 / 4.0 > fMax then fMax else T2 / 4.0;
  u2_2 = if T2 / 4.0 > fMax then fMax else T2 / 4.0;
  u2_3 = if T2 / 4.0 > fMax then fMax else T2 / 4.0;
  u2_4 = if T2 / 4.0 > fMax then fMax else T2 / 4.0;
  u3_1 = if T3 / 4.0 > fMax then fMax else T3 / 4.0;
  u3_2 = if T3 / 4.0 > fMax then fMax else T3 / 4.0;
  u3_3 = if T3 / 4.0 > fMax then fMax else T3 / 4.0;
  u3_4 = if T3 / 4.0 > fMax then fMax else T3 / 4.0;

  // ===== Bounded total thrust and saturation scale factor =====
  Tb1 = u1_1 + u1_2 + u1_3 + u1_4;
  Tb2 = u2_1 + u2_2 + u2_3 + u2_4;
  Tb3 = u3_1 + u3_2 + u3_3 + u3_4;
  s1 = Tb1 / max(T1, 0.01);
  s2 = Tb2 / max(T2, 0.01);
  s3 = Tb3 / max(T3, 0.01);

  // ===== Quadrotor dynamics: Q1 =====
  der(x1) = vx1;
  der(y1) = vy1;
  der(z1) = vz1;
  m_quad * der(vx1) = m_quad * ax1 * s1 + distAppX;
  m_quad * der(vy1) = m_quad * ay1 * s1 + distAppY;
  m_quad * der(vz1) = m_quad * (az1 + g_const) * s1 + distAppZ - m_quad * g_const;

  // ===== Quadrotor dynamics: Q2 =====
  der(x2) = vx2;
  der(y2) = vy2;
  der(z2) = vz2;
  m_quad * der(vx2) = m_quad * ax2 * s2 + distAppX;
  m_quad * der(vy2) = m_quad * ay2 * s2 + distAppY;
  m_quad * der(vz2) = m_quad * (az2 + g_const) * s2 + distAppZ - m_quad * g_const;

  // ===== Quadrotor dynamics: Q3 =====
  der(x3) = vx3;
  der(y3) = vy3;
  der(z3) = vz3;
  m_quad * der(vx3) = m_quad * ax3 * s3 + distAppX;
  m_quad * der(vy3) = m_quad * ay3 * s3 + distAppY;
  m_quad * der(vz3) = m_quad * (az3 + g_const) * s3 + distAppZ - m_quad * g_const;

  // ===== GPS sensor traces (local proprioception + exteroception) =====
  gps1_x = x1; gps1_y = y1; gps1_z = z1;
  gps2_x = x2; gps2_y = y2; gps2_z = z2;
  gps3_x = x3; gps3_y = y3; gps3_z = z3;

  // ===== Peer-relative range sensor traces =====
  range12 = sqrt(max((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2) + (z1 - z2) * (z1 - z2), 0.0001));
  range13 = sqrt(max((x1 - x3) * (x1 - x3) + (y1 - y3) * (y1 - y3) + (z1 - z3) * (z1 - z3), 0.0001));
  range23 = sqrt(max((x2 - x3) * (x2 - x3) + (y2 - y3) * (y2 - y3) + (z2 - z3) * (z2 - z3), 0.0001));

  // ===== Formation error metrics =====
  formErr12 = sqrt(max((x2 - x1 - form12_x) * (x2 - x1 - form12_x)
                     + (y2 - y1 - form12_y) * (y2 - y1 - form12_y)
                     + (z2 - z1 - form12_z) * (z2 - z1 - form12_z), 0.0));
  formErr13 = sqrt(max((x3 - x1 - form13_x) * (x3 - x1 - form13_x)
                     + (y3 - y1 - form13_y) * (y3 - y1 - form13_y)
                     + (z3 - z1 - form13_z) * (z3 - z1 - form13_z), 0.0));
  formErr23 = sqrt(max((x3 - x2 - d23_x) * (x3 - x2 - d23_x)
                     + (y3 - y2 - d23_y) * (y3 - y2 - d23_y)
                     + (z3 - z2 - d23_z) * (z3 - z2 - d23_z), 0.0));
  formErrMax = max(formErr12, max(formErr13, formErr23));

  // ===== Primary tracking error (Q1 to route) =====
  trackErr1 = sqrt(max((x1 - routeX) * (x1 - routeX)
                     + (y1 - routeY) * (y1 - routeY)
                     + (z1 - routeZ) * (z1 - routeZ), 0.0));

  // ===== Route completion flag =====
  routeComplete = time >= 9.5;

  // ===== Capture last received peer state at dropout start =====
  when time >= tDropStart then
    reinit(lpx1, x1);   reinit(lpy1, y1);   reinit(lpz1, z1);
    reinit(lvx1_r, vx1); reinit(lvy1_r, vy1); reinit(lvz1_r, vz1);
    reinit(lt1, time);
    reinit(lpx2, x2);   reinit(lpy2, y2);   reinit(lpz2, z2);
    reinit(lvx2_r, vx2); reinit(lvy2_r, vy2); reinit(lvz2_r, vz2);
    reinit(lt2, time);
    reinit(lpx3, x3);   reinit(lpy3, y3);   reinit(lpz3, z3);
    reinit(lvx3_r, vx3); reinit(lvy3_r, vy3); reinit(lvz3_r, vz3);
    reinit(lt3, time);
  end when;

  // ===== Capture degraded formation error at dropout end =====
  when time >= tDropStart + tDropDur then
    reinit(formErrDegraded, formErrMax);
  end when;

  // ===== Capture recovered formation error and tracking error at 6.5 s =====
  when time >= 6.5 then
    reinit(formErrRecovered, formErrMax);
    reinit(trackErr65, trackErr1);
  end when;

  annotation(
    experiment(StartTime = 0, StopTime = 10.0, Tolerance = 1e-6, Interval = 0.01),
    Documentation(info = "AirTrioResilientB: Three 1.8 kg quadrotors (12 independent rotor
      thrust groups bounded at 9.84 N per rotor) maintaining a coordinated triangular
      formation through a 0.7 s communication dropout in the middle third of a 10 s
      mission at 100 Hz. Distributed control uses local proprioception, GPS
      exteroception, peer-relative range sensing, and last-received peer state with
      timestamps. During dropout, dead-reckoning prediction maintains formation.
      A shared environmental disturbance is applied during the dropout. Formation
      error is captured as degraded (end of dropout) and recovered (at 6.5 s).
      Primary tracking error must remain below 0.72 m after 6.5 s."));
end AirTrioResilientB;