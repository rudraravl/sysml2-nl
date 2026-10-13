model AirTrioHandoffF
  "Three-quadrotor inspection with task allocation, timestamped handoff, and communication delay"

  /* Physical parameters */
  parameter Real m = 1.8 "quadrotor mass [kg]";
  parameter Real g_acc = 9.81 "gravitational acceleration [m/s2]";
  parameter Real Tmax = 14.6 "max rotor thrust [N]";

  /* Control gains */
  parameter Real Kp = 6.0 "position proportional gain [1/s2]";
  parameter Real Kd = 3.5 "position derivative gain [1/s]";
  parameter Real K_rep = 3.0 "inter-robot repulsion gain [m/s2]";
  parameter Real d_safe = 1.2 "safe separation distance [m]";

  /* Communication */
  parameter Real delay_nom = 0.001 "nominal comm delay [s]";
  parameter Real delay_dist = 0.145 "disturbance comm delay [s]";
  parameter Real maxDelay = 0.2 "max delay upper bound [s]";

  /* Timing */
  parameter Real Tsim = 20.0 "total simulation time [s]";
  parameter Real inspectDuration = 1.5 "inspection dwell time [s]";
  parameter Real arriveThresh = 0.3 "arrival threshold [m]";

  /* World-frame survey markers */
  parameter Real markerA_x = 4.0 "marker A x [m]";
  parameter Real markerA_y = 0.0 "marker A y [m]";
  parameter Real markerA_z = 2.0 "marker A z [m]";
  parameter Real markerB_x = 0.0 "marker B x [m]";
  parameter Real markerB_y = 4.0 "marker B y [m]";
  parameter Real markerB_z = 2.0 "marker B z [m]";
  parameter Real markerC_x = -4.0 "marker C x [m]";
  parameter Real markerC_y = 0.0 "marker C y [m]";
  parameter Real markerC_z = 2.0 "marker C z [m]";

  /* Home / staging positions */
  parameter Real home1_x = 0.0 "robot1 home x [m]";
  parameter Real home1_y = -3.0 "robot1 home y [m]";
  parameter Real home1_z = 1.0 "robot1 home z [m]";
  parameter Real home2_x = 2.0 "robot2 home x [m]";
  parameter Real home2_y = -3.0 "robot2 home y [m]";
  parameter Real home2_z = 1.0 "robot2 home z [m]";
  parameter Real home3_x = -2.0 "robot3 home x [m]";
  parameter Real home3_y = -3.0 "robot3 home y [m]";
  parameter Real home3_z = 1.0 "robot3 home z [m]";

  /* ===== Robot 1 continuous states ===== */
  Real x1(start=0.0, fixed=true) "robot1 x [m]";
  Real y1(start=-3.0, fixed=true) "robot1 y [m]";
  Real z1(start=1.0, fixed=true) "robot1 z [m]";
  Real vx1(start=0.0, fixed=true) "robot1 vx [m/s]";
  Real vy1(start=0.0, fixed=true) "robot1 vy [m/s]";
  Real vz1(start=0.0, fixed=true) "robot1 vz [m/s]";

  /* ===== Robot 2 continuous states ===== */
  Real x2(start=2.0, fixed=true) "robot2 x [m]";
  Real y2(start=-3.0, fixed=true) "robot2 y [m]";
  Real z2(start=1.0, fixed=true) "robot2 z [m]";
  Real vx2(start=0.0, fixed=true) "robot2 vx [m/s]";
  Real vy2(start=0.0, fixed=true) "robot2 vy [m/s]";
  Real vz2(start=0.0, fixed=true) "robot2 vz [m/s]";

  /* ===== Robot 3 continuous states ===== */
  Real x3(start=-2.0, fixed=true) "robot3 x [m]";
  Real y3(start=-3.0, fixed=true) "robot3 y [m]";
  Real z3(start=1.0, fixed=true) "robot3 z [m]";
  Real vx3(start=0.0, fixed=true) "robot3 vx [m/s]";
  Real vy3(start=0.0, fixed=true) "robot3 vy [m/s]";
  Real vz3(start=0.0, fixed=true) "robot3 vz [m/s]";

  /* ===== Discrete handoff state machine ===== */
  Integer hs1(start=0) "robot1: 0=goA 1=inspectA 2=doneA";
  Integer hs2(start=0) "robot2: 0=wait 1=goB 2=inspectB 3=doneB";
  Integer hs3(start=0) "robot3: 0=wait 1=goC 2=inspectC 3=doneC";

  Real inspectStart1(start=0.0) "robot1 inspection start [s]";
  Real inspectStart2(start=0.0) "robot2 inspection start [s]";
  Real inspectStart3(start=0.0) "robot3 inspection start [s]";
  Real sendTime1(start=0.0) "robot1 handoff timestamp [s]";
  Real sendTime2(start=0.0) "robot2 handoff timestamp [s]";

  Boolean handoff2Done(start=false) "robot2 received handoff";
  Boolean handoff3Done(start=false) "robot3 received handoff";
  Real dataAge2_recv(start=0.0) "data age at robot2 reception [s]";
  Real dataAge3_recv(start=0.0) "data age at robot3 reception [s]";

  /* ===== Communication channel ===== */
  Real commSignal1 "handoff signal robot1->robot2 (0|1)";
  Real commSignal2 "handoff signal robot2->robot3 (0|1)";
  Real commTime1 "timestamp packet robot1 [s]";
  Real commTime2 "timestamp packet robot2 [s]";
  Real commSignal1_d "delayed handoff signal robot1->robot2";
  Real commSignal2_d "delayed handoff signal robot2->robot3";
  Real commTime1_d "delayed timestamp robot1 [s]";
  Real commTime2_d "delayed timestamp robot2 [s]";
  Boolean recv2 "robot2 reception flag";
  Boolean recv3 "robot3 reception flag";
  Real currentDelay "active communication delay [s]";
  Real dataAge2 "current data age robot2 [s]";
  Real dataAge3 "current data age robot3 [s]";

  /* ===== Reference positions from task allocation ===== */
  Real ref1_x "robot1 ref x [m]";
  Real ref1_y "robot1 ref y [m]";
  Real ref1_z "robot1 ref z [m]";
  Real ref2_x "robot2 ref x [m]";
  Real ref2_y "robot2 ref y [m]";
  Real ref2_z "robot2 ref z [m]";
  Real ref3_x "robot3 ref x [m]";
  Real ref3_y "robot3 ref y [m]";
  Real ref3_z "robot3 ref z [m]";

  /* ===== Desired and actual accelerations ===== */
  Real ax1_des "robot1 desired ax [m/s2]";
  Real ay1_des "robot1 desired ay [m/s2]";
  Real az1_des "robot1 desired az [m/s2]";
  Real ax2_des "robot2 desired ax [m/s2]";
  Real ay2_des "robot2 desired ay [m/s2]";
  Real az2_des "robot2 desired az [m/s2]";
  Real ax3_des "robot3 desired ax [m/s2]";
  Real ay3_des "robot3 desired ay [m/s2]";
  Real az3_des "robot3 desired az [m/s2]";
  Real ax1 "robot1 actual ax [m/s2]";
  Real ay1 "robot1 actual ay [m/s2]";
  Real az1 "robot1 actual az [m/s2]";
  Real ax2 "robot2 actual ax [m/s2]";
  Real ay2 "robot2 actual ay [m/s2]";
  Real az2 "robot2 actual az [m/s2]";
  Real ax3 "robot3 actual ax [m/s2]";
  Real ay3 "robot3 actual ay [m/s2]";
  Real az3 "robot3 actual az [m/s2]";

  /* ===== Thrust vector and allocation ===== */
  Real Fth1_x "robot1 thrust vector x [N]";
  Real Fth1_y "robot1 thrust vector y [N]";
  Real Fth1_z "robot1 thrust vector z [N]";
  Real Fth2_x "robot2 thrust vector x [N]";
  Real Fth2_y "robot2 thrust vector y [N]";
  Real Fth2_z "robot2 thrust vector z [N]";
  Real Fth3_x "robot3 thrust vector x [N]";
  Real Fth3_y "robot3 thrust vector y [N]";
  Real Fth3_z "robot3 thrust vector z [N]";
  Real Fth1_mag "robot1 desired thrust magnitude [N]";
  Real Fth2_mag "robot2 desired thrust magnitude [N]";
  Real Fth3_mag "robot3 desired thrust magnitude [N]";
  Real dir1_x "robot1 thrust dir x";
  Real dir1_y "robot1 thrust dir y";
  Real dir1_z "robot1 thrust dir z";
  Real dir2_x "robot2 thrust dir x";
  Real dir2_y "robot2 thrust dir y";
  Real dir2_z "robot2 thrust dir z";
  Real dir3_x "robot3 thrust dir x";
  Real dir3_y "robot3 thrust dir y";
  Real dir3_z "robot3 thrust dir z";
  Real F1_act "robot1 actual total thrust [N]";
  Real F2_act "robot2 actual total thrust [N]";
  Real F3_act "robot3 actual total thrust [N]";

  /* 12 independent rotor-thrust groups */
  Real T1_1 "robot1 rotor1 thrust [N]";
  Real T1_2 "robot1 rotor2 thrust [N]";
  Real T1_3 "robot1 rotor3 thrust [N]";
  Real T1_4 "robot1 rotor4 thrust [N]";
  Real T2_1 "robot2 rotor1 thrust [N]";
  Real T2_2 "robot2 rotor2 thrust [N]";
  Real T2_3 "robot2 rotor3 thrust [N]";
  Real T2_4 "robot2 rotor4 thrust [N]";
  Real T3_1 "robot3 rotor1 thrust [N]";
  Real T3_2 "robot3 rotor2 thrust [N]";
  Real T3_3 "robot3 rotor3 thrust [N]";
  Real T3_4 "robot3 rotor4 thrust [N]";
  Real dRoll1 "robot1 roll allocation [N]";
  Real dPitch1 "robot1 pitch allocation [N]";
  Real dRoll2 "robot2 roll allocation [N]";
  Real dPitch2 "robot2 pitch allocation [N]";
  Real dRoll3 "robot3 roll allocation [N]";
  Real dPitch3 "robot3 pitch allocation [N]";

  /* ===== Sensors (recorded traces) ===== */
  Real gps1_x "robot1 GPS x [m]";
  Real gps1_y "robot1 GPS y [m]";
  Real gps1_z "robot1 GPS z [m]";
  Real gps2_x "robot2 GPS x [m]";
  Real gps2_y "robot2 GPS y [m]";
  Real gps2_z "robot2 GPS z [m]";
  Real gps3_x "robot3 GPS x [m]";
  Real gps3_y "robot3 GPS y [m]";
  Real gps3_z "robot3 GPS z [m]";
  Real imu1_ax "robot1 IMU ax [m/s2]";
  Real imu1_ay "robot1 IMU ay [m/s2]";
  Real imu1_az "robot1 IMU az [m/s2]";
  Real imu2_ax "robot2 IMU ax [m/s2]";
  Real imu2_ay "robot2 IMU ay [m/s2]";
  Real imu2_az "robot2 IMU az [m/s2]";
  Real imu3_ax "robot3 IMU ax [m/s2]";
  Real imu3_ay "robot3 IMU ay [m/s2]";
  Real imu3_az "robot3 IMU az [m/s2]";
  Real range12 "peer-relative range 1-2 [m]";
  Real range13 "peer-relative range 1-3 [m]";
  Real range23 "peer-relative range 2-3 [m]";

  /* ===== Separation and distances ===== */
  Real d12 "distance robot1-robot2 [m]";
  Real d13 "distance robot1-robot3 [m]";
  Real d23 "distance robot2-robot3 [m]";
  Real minSep "minimum pairwise separation [m]";
  Real minSepEver(start=100.0) "all-time minimum separation [m]";
  Real dist1A "robot1 distance to marker A [m]";
  Real dist2B "robot2 distance to marker B [m]";
  Real dist3C "robot3 distance to marker C [m]";

  /* ===== Repulsion ===== */
  Real rep1x "robot1 repulsion x [m/s2]";
  Real rep1y "robot1 repulsion y [m/s2]";
  Real rep1z "robot1 repulsion z [m/s2]";
  Real rep2x "robot2 repulsion x [m/s2]";
  Real rep2y "robot2 repulsion y [m/s2]";
  Real rep2z "robot2 repulsion z [m/s2]";
  Real rep3x "robot3 repulsion x [m/s2]";
  Real rep3y "robot3 repulsion y [m/s2]";
  Real rep3z "robot3 repulsion z [m/s2]";

  /* ===== Verification metrics ===== */
  Real trackErr1 "robot1 tracking error [m]";
  Real trackErr2 "robot2 tracking error [m]";
  Real trackErr3 "robot3 tracking error [m]";
  Real primaryTrackErr "primary tracking error [m]";
  Real maxThrust "maximum rotor thrust [N]";
  Boolean actuatorOK "actuator bound satisfied";
  Boolean separationOK "separation bound satisfied";
  Boolean dataAgeOK "data age bounded";
  Boolean handoffOK "handoff successful";
  Boolean noCollisionOK "no collision";
  Boolean taskCompleteOK "task completion achieved";
  Boolean trackErrOK "tracking error criterion met";
  Boolean allFinite "no NaN or infinite values";
  Boolean verificationOK "overall verification";

equation

  /* ===== Communication delay schedule ===== */
  currentDelay = if (time > Tsim/3.0 and time < 2.0*Tsim/3.0) then delay_dist else delay_nom;

  /* ===== Robot 1 dynamics ===== */
  der(x1) = vx1;
  der(y1) = vy1;
  der(z1) = vz1;
  der(vx1) = ax1;
  der(vy1) = ay1;
  der(vz1) = az1;

  /* ===== Robot 2 dynamics ===== */
  der(x2) = vx2;
  der(y2) = vy2;
  der(z2) = vz2;
  der(vx2) = ax2;
  der(vy2) = ay2;
  der(vz2) = az2;

  /* ===== Robot 3 dynamics ===== */
  der(x3) = vx3;
  der(y3) = vy3;
  der(z3) = vz3;
  der(vx3) = ax3;
  der(vy3) = ay3;
  der(vz3) = az3;

  /* ===== Pairwise distances and range sensors ===== */
  d12 = sqrt((x1-x2)^2 + (y1-y2)^2 + (z1-z2)^2);
  d13 = sqrt((x1-x3)^2 + (y1-y3)^2 + (z1-z3)^2);
  d23 = sqrt((x2-x3)^2 + (y2-y3)^2 + (z2-z3)^2);
  minSep = min(d12, min(d13, d23));
  range12 = d12;
  range13 = d13;
  range23 = d23;

  /* ===== Inter-robot repulsion (collision avoidance) ===== */
  rep1x = (if d12 < d_safe then K_rep*(d_safe - d12)*(x1 - x2)/max(d12, 0.01) else 0.0)
        + (if d13 < d_safe then K_rep*(d_safe - d13)*(x1 - x3)/max(d13, 0.01) else 0.0);
  rep1y = (if d12 < d_safe then K_rep*(d_safe - d12)*(y1 - y2)/max(d12, 0.01) else 0.0)
        + (if d13 < d_safe then K_rep*(d_safe - d13)*(y1 - y3)/max(d13, 0.01) else 0.0);
  rep1z = (if d12 < d_safe then K_rep*(d_safe - d12)*(z1 - z2)/max(d12, 0.01) else 0.0)
        + (if d13 < d_safe then K_rep*(d_safe - d13)*(z1 - z3)/max(d13, 0.01) else 0.0);
  rep2x = (if d12 < d_safe then K_rep*(d_safe - d12)*(x2 - x1)/max(d12, 0.01) else 0.0)
        + (if d23 < d_safe then K_rep*(d_safe - d23)*(x2 - x3)/max(d23, 0.01) else 0.0);
  rep2y = (if d12 < d_safe then K_rep*(d_safe - d12)*(y2 - y1)/max(d12, 0.01) else 0.0)
        + (if d23 < d_safe then K_rep*(d_safe - d23)*(y2 - y3)/max(d23, 0.01) else 0.0);
  rep2z = (if d12 < d_safe then K_rep*(d_safe - d12)*(z2 - z1)/max(d12, 0.01) else 0.0)
        + (if d23 < d_safe then K_rep*(d_safe - d23)*(z2 - z3)/max(d23, 0.01) else 0.0);
  rep3x = (if d13 < d_safe then K_rep*(d_safe - d13)*(x3 - x1)/max(d13, 0.01) else 0.0)
        + (if d23 < d_safe then K_rep*(d_safe - d23)*(x3 - x2)/max(d23, 0.01) else 0.0);
  rep3y = (if d13 < d_safe then K_rep*(d_safe - d13)*(y3 - y1)/max(d13, 0.01) else 0.0)
        + (if d23 < d_safe then K_rep*(d_safe - d23)*(y3 - y2)/max(d23, 0.01) else 0.0);
  rep3z = (if d13 < d_safe then K_rep*(d_safe - d13)*(z3 - z1)/max(d13, 0.01) else 0.0)
        + (if d23 < d_safe then K_rep*(d_safe - d23)*(z3 - z2)/max(d23, 0.01) else 0.0);

  /* ===== Task allocation: reference positions ===== */
  /* Robot 1 goes to marker A immediately */
  ref1_x = markerA_x;
  ref1_y = markerA_y;
  ref1_z = markerA_z;
  /* Robot 2 waits at home, then goes to marker B after handoff */
  ref2_x = if hs2 == 0 then home2_x else markerB_x;
  ref2_y = if hs2 == 0 then home2_y else markerB_y;
  ref2_z = if hs2 == 0 then home2_z else markerB_z;
  /* Robot 3 waits at home, then replans to marker C after receiving handoff data */
  ref3_x = if hs3 == 0 then home3_x else markerC_x;
  ref3_y = if hs3 == 0 then home3_y else markerC_y;
  ref3_z = if hs3 == 0 then home3_z else markerC_z;

  /* ===== Marker arrival distances ===== */
  dist1A = sqrt((x1 - markerA_x)^2 + (y1 - markerA_y)^2 + (z1 - markerA_z)^2);
  dist2B = sqrt((x2 - markerB_x)^2 + (y2 - markerB_y)^2 + (z2 - markerB_z)^2);
  dist3C = sqrt((x3 - markerC_x)^2 + (y3 - markerC_y)^2 + (z3 - markerC_z)^2);

  /* ===== Local motion control: PD + repulsion ===== */
  ax1_des = Kp*(ref1_x - x1) - Kd*vx1 + rep1x;
  ay1_des = Kp*(ref1_y - y1) - Kd*vy1 + rep1y;
  az1_des = Kp*(ref1_z - z1) - Kd*vz1 + rep1z;
  ax2_des = Kp*(ref2_x - x2) - Kd*vx2 + rep2x;
  ay2_des = Kp*(ref2_y - y2) - Kd*vy2 + rep2y;
  az2_des = Kp*(ref2_z - z2) - Kd*vz2 + rep2z;
  ax3_des = Kp*(ref3_x - x3) - Kd*vx3 + rep3x;
  ay3_des = Kp*(ref3_y - y3) - Kd*vy3 + rep3y;
  az3_des = Kp*(ref3_z - z3) - Kd*vz3 + rep3z;

  /* ===== Desired thrust vectors (gravity compensation included) ===== */
  Fth1_x = m * ax1_des;
  Fth1_y = m * ay1_des;
  Fth1_z = m * (az1_des + g_acc);
  Fth1_mag = sqrt(Fth1_x^2 + Fth1_y^2 + Fth1_z^2);
  dir1_x = Fth1_x / max(Fth1_mag, 0.01);
  dir1_y = Fth1_y / max(Fth1_mag, 0.01);
  dir1_z = Fth1_z / max(Fth1_mag, 0.01);

  Fth2_x = m * ax2_des;
  Fth2_y = m * ay2_des;
  Fth2_z = m * (az2_des + g_acc);
  Fth2_mag = sqrt(Fth2_x^2 + Fth2_y^2 + Fth2_z^2);
  dir2_x = Fth2_x / max(Fth2_mag, 0.01);
  dir2_y = Fth2_y / max(Fth2_mag, 0.01);
  dir2_z = Fth2_z / max(Fth2_mag, 0.01);

  Fth3_x = m * ax3_des;
  Fth3_y = m * ay3_des;
  Fth3_z = m * (az3_des + g_acc);
  Fth3_mag = sqrt(Fth3_x^2 + Fth3_y^2 + Fth3_z^2);
  dir3_x = Fth3_x / max(Fth3_mag, 0.01);
  dir3_y = Fth3_y / max(Fth3_mag, 0.01);
  dir3_z = Fth3_z / max(Fth3_mag, 0.01);

  /* ===== 12 independent rotor-thrust groups (bounded 0..Tmax) ===== */
  dRoll1 = 0.05 * m * ay1_des;
  dPitch1 = 0.05 * m * ax1_des;
  dRoll2 = 0.05 * m * ay2_des;
  dPitch2 = 0.05 * m * ax2_des;
  dRoll3 = 0.05 * m * ay3_des;
  dPitch3 = 0.05 * m * ax3_des;

  T1_1 = max(0.0, min(Tmax, Fth1_mag/4.0 + dRoll1 + dPitch1));
  T1_2 = max(0.0, min(Tmax, Fth1_mag/4.0 - dRoll1 + dPitch1));
  T1_3 = max(0.0, min(Tmax, Fth1_mag/4.0 + dRoll1 - dPitch1));
  T1_4 = max(0.0, min(Tmax, Fth1_mag/4.0 - dRoll1 - dPitch1));

  T2_1 = max(0.0, min(Tmax, Fth2_mag/4.0 + dRoll2 + dPitch2));
  T2_2 = max(0.0, min(Tmax, Fth2_mag/4.0 - dRoll2 + dPitch2));
  T2_3 = max(0.0, min(Tmax, Fth2_mag/4.0 + dRoll2 - dPitch2));
  T2_4 = max(0.0, min(Tmax, Fth2_mag/4.0 - dRoll2 - dPitch2));

  T3_1 = max(0.0, min(Tmax, Fth3_mag/4.0 + dRoll3 + dPitch3));
  T3_2 = max(0.0, min(Tmax, Fth3_mag/4.0 - dRoll3 + dPitch3));
  T3_3 = max(0.0, min(Tmax, Fth3_mag/4.0 + dRoll3 - dPitch3));
  T3_4 = max(0.0, min(Tmax, Fth3_mag/4.0 - dRoll3 - dPitch3));

  /* ===== Actual total thrust and acceleration ===== */
  F1_act = T1_1 + T1_2 + T1_3 + T1_4;
  F2_act = T2_1 + T2_2 + T2_3 + T2_4;
  F3_act = T3_1 + T3_2 + T3_3 + T3_4;

  ax1 = (F1_act / m) * dir1_x;
  ay1 = (F1_act / m) * dir1_y;
  az1 = (F1_act / m) * dir1_z - g_acc;

  ax2 = (F2_act / m) * dir2_x;
  ay2 = (F2_act / m) * dir2_y;
  az2 = (F2_act / m) * dir2_z - g_acc;

  ax3 = (F3_act / m) * dir3_x;
  ay3 = (F3_act / m) * dir3_y;
  az3 = (F3_act / m) * dir3_z - g_acc;

  /* ===== GPS and IMU sensor traces ===== */
  gps1_x = x1; gps1_y = y1; gps1_z = z1;
  gps2_x = x2; gps2_y = y2; gps2_z = z2;
  gps3_x = x3; gps3_y = y3; gps3_z = z3;
  imu1_ax = ax1; imu1_ay = ay1; imu1_az = az1;
  imu2_ax = ax2; imu2_ay = ay2; imu2_az = az2;
  imu3_ax = ax3; imu3_ay = ay3; imu3_az = az3;

  /* ===== Communication: send, delay, receive, data age ===== */
  commSignal1 = if hs1 >= 2 then 1.0 else 0.0;
  commSignal2 = if hs2 >= 3 then 1.0 else 0.0;
  commTime1 = if hs1 >= 2 then sendTime1 else 0.0;
  commTime2 = if hs2 >= 3 then sendTime2 else 0.0;

  commSignal1_d = delay(commSignal1, currentDelay, maxDelay);
  commSignal2_d = delay(commSignal2, currentDelay, maxDelay);
  commTime1_d = delay(commTime1, currentDelay, maxDelay);
  commTime2_d = delay(commTime2, currentDelay, maxDelay);

  recv2 = commSignal1_d > 0.5;
  recv3 = commSignal2_d > 0.5;

  dataAge2 = if recv2 then time - commTime1_d else 0.0;
  dataAge3 = if recv3 then time - commTime2_d else 0.0;

  /* ===== Tracking errors ===== */
  trackErr1 = sqrt((x1 - ref1_x)^2 + (y1 - ref1_y)^2 + (z1 - ref1_z)^2);
  trackErr2 = sqrt((x2 - ref2_x)^2 + (y2 - ref2_y)^2 + (z2 - ref2_z)^2);
  trackErr3 = sqrt((x3 - ref3_x)^2 + (y3 - ref3_y)^2 + (z3 - ref3_z)^2);
  primaryTrackErr = max(trackErr1, max(trackErr2, trackErr3));

  /* ===== Verification criteria ===== */
  maxThrust = max(T1_1, max(T1_2, max(T1_3, max(T1_4,
             max(T2_1, max(T2_2, max(T2_3, max(T2_4,
             max(T3_1, max(T3_2, max(T3_3, T3_4)))))))))));

  actuatorOK = maxThrust <= Tmax + 0.001;
  separationOK = minSep > 0.5;
  dataAgeOK = dataAge2_recv <= maxDelay and dataAge3_recv <= maxDelay;
  handoffOK = handoff2Done and handoff3Done;
  noCollisionOK = minSepEver > 0.3;
  taskCompleteOK = hs1 >= 2 and hs2 >= 3 and hs3 >= 3;
  trackErrOK = if time >= 13.0 then primaryTrackErr < 0.32 else true;
  allFinite = abs(x1) < 1e8 and abs(y1) < 1e8 and abs(z1) < 1e8 and
              abs(x2) < 1e8 and abs(y2) < 1e8 and abs(z2) < 1e8 and
              abs(x3) < 1e8 and abs(y3) < 1e8 and abs(z3) < 1e8 and
              abs(maxThrust) < 1e8 and abs(primaryTrackErr) < 1e8;
  verificationOK = actuatorOK and separationOK and dataAgeOK and
                    handoffOK and noCollisionOK and taskCompleteOK and
                    trackErrOK and allFinite;

  /* ===== All-time minimum separation tracking ===== */
  when minSep < pre(minSepEver) then
    minSepEver := minSep;
  end when;

  /* ===== Robot 1 handoff state machine ===== */
  when hs1 == 0 and dist1A < arriveThresh then
    hs1 := 1;
    inspectStart1 := time;
  end when;

  when hs1 == 1 and time - inspectStart1 > inspectDuration then
    hs1 := 2;
    sendTime1 := time;
  end when;

  /* ===== Robot 2 handoff state machine ===== */
  when hs2 == 0 and commSignal1_d > 0.5 then
    hs2 := 1;
    handoff2Done := true;
    dataAge2_recv := time - commTime1_d;
  end when;

  when hs2 == 1 and dist2B < arriveThresh then
    hs2 := 2;
    inspectStart2 := time;
  end when;

  when hs2 == 2 and time - inspectStart2 > inspectDuration then
    hs2 := 3;
    sendTime2 := time;
  end when;

  /* ===== Robot 3 handoff state machine (replans on received data) ===== */
  when hs3 == 0 and commSignal2_d > 0.5 then
    hs3 := 1;
    handoff3Done := true;
    dataAge3_recv := time - commTime2_d;
  end when;

  when hs3 == 1 and dist3C < arriveThresh then
    hs3 := 2;
    inspectStart3 := time;
  end when;

  when hs3 == 2 and time - inspectStart3 > inspectDuration then
    hs3 := 3;
  end when;

  annotation(
    experiment(StartTime=0, StopTime=20.0, Tolerance=1e-6, Interval=0.002),
    Documentation(info="AirTrioHandoffF: Three 1.8 kg quadrotors with 4 rotors each (12 independent rotor-thrust groups, max 14.6 N/rotor) perform sequential inspection of three world-frame survey markers. Robot 1 inspects marker A, sends a timestamped handoff result to Robot 2 which inspects marker B and forwards a timestamped handoff to Robot 3 which replans to inspect marker C using the received data. IMU, GPS, and peer-relative range sensors are recorded. A 0.145 s communication delay disturbance is applied during the middle third (6.67-13.33 s). Runs at 500 Hz (Interval=0.002) for 20 s. Verification: actuator bounds, separation bounds, bounded data age, successful handoff, no collision, task completion, primary tracking error < 0.32 m after 13 s, and no NaN/infinite values.")
  );
end AirTrioHandoffF;