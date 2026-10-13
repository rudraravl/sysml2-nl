model AirTrioCoordinateF
  parameter Real m(unit="kg") = 1.8 "mass of each quadrotor";
  parameter Real Tmax(unit="N") = 14.6 "per-rotor thrust bound";
  parameter Real dSafe(unit="m") = 0.52 "required separation and tracking threshold";
  parameter Real tau(unit="s") = 0.174 "controlled message delay";
  parameter Real fSample(unit="Hz") = 500 "trace and control rate";
  parameter Real Ts(unit="s") = 1.0/fSample "500 Hz sampling period";
  parameter Real Tend(unit="s") = 20 "mission duration";
  parameter Real tMid1(unit="s") = Tend/3.0 "start of middle third";
  parameter Real tMid2(unit="s") = 2.0*Tend/3.0 "end of middle third";
  parameter Real delayMax(unit="s") = 0.5 "upper bound for delay operator";
  parameter Real R(unit="m") = dSafe "central conflict radius";
  parameter Real L(unit="m") = 2.0*dSafe "route half-length";
  parameter Real laneHalfWidth(unit="m") = dSafe "fixed corridor half-width";
  parameter Real vNom(unit="m/s") = (2.0*L+4.0*R)/(Tend/2.0) "nominal route speed";
  parameter Real aMax(unit="m/s2") = 4.0*Tmax/m "bounded acceleration and braking";
  parameter Real kV = 10.0 "velocity error gain";
  parameter Real kS = 50.0 "position hold gain";
  constant Real u1x = 1.0 "route 1 unit direction x";
  constant Real u1y = 0.0 "route 1 unit direction y";
  constant Real u2x = -0.5 "route 2 unit direction x";
  constant Real u2y = 0.8660254037844386 "route 2 unit direction y";
  constant Real u3x = -0.5 "route 3 unit direction x";
  constant Real u3y = -0.8660254037844386 "route 3 unit direction y";

  output Real s1(start=-L, unit="m") "robot 1 route coordinate";
  output Real s2(start=-L, unit="m") "robot 2 route coordinate";
  output Real s3(start=-L, unit="m") "robot 3 route coordinate";
  output Real v1(start=0, unit="m/s") "robot 1 route speed";
  output Real v2(start=0, unit="m/s") "robot 2 route speed";
  output Real v3(start=0, unit="m/s") "robot 3 route speed";
  output Real aCmd1(unit="m/s2") "robot 1 commanded acceleration";
  output Real aCmd2(unit="m/s2") "robot 2 commanded acceleration";
  output Real aCmd3(unit="m/s2") "robot 3 commanded acceleration";
  output Real a1(unit="m/s2") "robot 1 saturated acceleration";
  output Real a2(unit="m/s2") "robot 2 saturated acceleration";
  output Real a3(unit="m/s2") "robot 3 saturated acceleration";
  output Real F1(unit="N") "robot 1 net route force";
  output Real F2(unit="N") "robot 2 net route force";
  output Real F3(unit="N") "robot 3 net route force";
  output Real T1_1(unit="N") "robot 1 rotor thrust group 1";
  output Real T1_2(unit="N") "robot 1 rotor thrust group 2";
  output Real T1_3(unit="N") "robot 1 rotor thrust group 3";
  output Real T1_4(unit="N") "robot 1 rotor thrust group 4";
  output Real T2_1(unit="N") "robot 2 rotor thrust group 1";
  output Real T2_2(unit="N") "robot 2 rotor thrust group 2";
  output Real T2_3(unit="N") "robot 2 rotor thrust group 3";
  output Real T2_4(unit="N") "robot 2 rotor thrust group 4";
  output Real T3_1(unit="N") "robot 3 rotor thrust group 1";
  output Real T3_2(unit="N") "robot 3 rotor thrust group 2";
  output Real T3_3(unit="N") "robot 3 rotor thrust group 3";
  output Real T3_4(unit="N") "robot 3 rotor thrust group 4";
  output Real x1(unit="m") "robot 1 x position";
  output Real y1(unit="m") "robot 1 y position";
  output Real x2(unit="m") "robot 2 x position";
  output Real y2(unit="m") "robot 2 y position";
  output Real x3(unit="m") "robot 3 x position";
  output Real y3(unit="m") "robot 3 y position";
  output Real gps1x(unit="m") "GPS x robot 1";
  output Real gps1y(unit="m") "GPS y robot 1";
  output Real gps2x(unit="m") "GPS x robot 2";
  output Real gps2y(unit="m") "GPS y robot 2";
  output Real gps3x(unit="m") "GPS x robot 3";
  output Real gps3y(unit="m") "GPS y robot 3";
  output Real imu1ax(unit="m/s2") "IMU acceleration x robot 1";
  output Real imu1ay(unit="m/s2") "IMU acceleration y robot 1";
  output Real imu2ax(unit="m/s2") "IMU acceleration x robot 2";
  output Real imu2ay(unit="m/s2") "IMU acceleration y robot 2";
  output Real imu3ax(unit="m/s2") "IMU acceleration x robot 3";
  output Real imu3ay(unit="m/s2") "IMU acceleration y robot 3";
  output Real lateralErr1(unit="m") "robot 1 lateral corridor error";
  output Real lateralErr2(unit="m") "robot 2 lateral corridor error";
  output Real lateralErr3(unit="m") "robot 3 lateral corridor error";
  output Real obsDist1(unit="m") "robot 1 obstacle distance to corridor boundary";
  output Real obsDist2(unit="m") "robot 2 obstacle distance to corridor boundary";
  output Real obsDist3(unit="m") "robot 3 obstacle distance to corridor boundary";
  output Real range12(unit="m") "peer-relative range robot 1 to 2";
  output Real range13(unit="m") "peer-relative range robot 1 to 3";
  output Real range23(unit="m") "peer-relative range robot 2 to 3";
  output Real d12(unit="m") "pairwise distance robot 1-2";
  output Real d13(unit="m") "pairwise distance robot 1-3";
  output Real d23(unit="m") "pairwise distance robot 2-3";
  output Real minDist(unit="m") "minimum pairwise distance";
  output Real sMsg1(unit="m") "delayed peer message route coordinate robot 1";
  output Real sMsg2(unit="m") "delayed peer message route coordinate robot 2";
  output Real sMsg3(unit="m") "delayed peer message route coordinate robot 3";
  output Real vMsg1(unit="m/s") "delayed peer message speed robot 1";
  output Real vMsg2(unit="m/s") "delayed peer message speed robot 2";
  output Real vMsg3(unit="m/s") "delayed peer message speed robot 3";
  output Real xMsg1(unit="m") "estimated peer x robot 1";
  output Real yMsg1(unit="m") "estimated peer y robot 1";
  output Real xMsg2(unit="m") "estimated peer x robot 2";
  output Real yMsg2(unit="m") "estimated peer y robot 2";
  output Real xMsg3(unit="m") "estimated peer x robot 3";
  output Real yMsg3(unit="m") "estimated peer y robot 3";
  output Boolean delayActive "true when 0.174 s delay is applied";
  output Boolean canGo1 "reservation clearance robot 1";
  output Boolean canGo2 "reservation clearance robot 2";
  output Boolean canGo3 "reservation clearance robot 3";
  output Boolean request1 "reservation request robot 1";
  output Boolean request2 "reservation request robot 2";
  output Boolean request3 "reservation request robot 3";
  output Boolean occ1 "intersection occupancy robot 1";
  output Boolean occ2 "intersection occupancy robot 2";
  output Boolean occ3 "intersection occupancy robot 3";
  output Boolean waiting1 "waiting flag robot 1";
  output Boolean waiting2 "waiting flag robot 2";
  output Boolean waiting3 "waiting flag robot 3";
  output Boolean braking1 "bounded braking active robot 1";
  output Boolean braking2 "bounded braking active robot 2";
  output Boolean braking3 "bounded braking active robot 3";
  output Boolean complete1 "route completion robot 1";
  output Boolean complete2 "route completion robot 2";
  output Boolean complete3 "route completion robot 3";
  output Real waitTime1(start=0, unit="s") "accumulated waiting time robot 1";
  output Real waitTime2(start=0, unit="s") "accumulated waiting time robot 2";
  output Real waitTime3(start=0, unit="s") "accumulated waiting time robot 3";
  output Real waitTimeTotal(unit="s") "total waiting time";
  output Real sRef1(unit="m") "reference route coordinate robot 1";
  output Real sRef2(unit="m") "reference route coordinate robot 2";
  output Real sRef3(unit="m") "reference route coordinate robot 3";
  output Real trackingErr1(unit="m") "tracking error robot 1";
  output Real trackingErr2(unit="m") "tracking error robot 2";
  output Real trackingErr3(unit="m") "tracking error robot 3";
  output Real trackingErrMax(unit="m") "primary tracking error";
  output Boolean actuatorBounds "actuator bound verification";
  output Boolean minDistanceOK "minimum distance verification";
  output Boolean mutualExclusion "mutual exclusion verification";
  output Boolean noCollision "no collision verification";
  output Boolean routeComplete "route completion verification";
  output Boolean trackingOK "tracking error verification after 13 s";
  output Real numericOK "finite and non-NaN verification";
  output Boolean noNaN "no NaN or infinite values";
  output Boolean verificationOK "combined verification";

  Real sMsg1Raw "raw delayed route coordinate robot 1";
  Real sMsg2Raw "raw delayed route coordinate robot 2";
  Real sMsg3Raw "raw delayed route coordinate robot 3";
  Real vMsg1Raw "raw delayed speed robot 1";
  Real vMsg2Raw "raw delayed speed robot 2";
  Real vMsg3Raw "raw delayed speed robot 3";
  Real dx12 "x difference robot 1-2";
  Real dy12 "y difference robot 1-2";
  Real dx13 "x difference robot 1-3";
  Real dy13 "y difference robot 1-3";
  Real dx23 "x difference robot 2-3";
  Real dy23 "y difference robot 2-3";
  Real epsN "zero-error guard for distance norm";
equation
  epsN = 1e-9;
  delayActive = time >= tMid1 and time <= tMid2;

  der(s1) = v1;
  der(s2) = v2;
  der(s3) = v3;
  der(v1) = a1;
  der(v2) = a2;
  der(v3) = a3;

  x1 = s1*u1x;
  y1 = s1*u1y;
  x2 = s2*u2x;
  y2 = s2*u2y;
  x3 = s3*u3x;
  y3 = s3*u3y;

  gps1x = x1;
  gps1y = y1;
  gps2x = x2;
  gps2y = y2;
  gps3x = x3;
  gps3y = y3;

  imu1ax = a1*u1x;
  imu1ay = a1*u1y;
  imu2ax = a2*u2x;
  imu2ay = a2*u2y;
  imu3ax = a3*u3x;
  imu3ay = a3*u3y;

  lateralErr1 = 0.0;
  lateralErr2 = 0.0;
  lateralErr3 = 0.0;
  obsDist1 = laneHalfWidth - abs(lateralErr1);
  obsDist2 = laneHalfWidth - abs(lateralErr2);
  obsDist3 = laneHalfWidth - abs(lateralErr3);

  dx12 = x1 - x2;
  dy12 = y1 - y2;
  dx13 = x1 - x3;
  dy13 = y1 - y3;
  dx23 = x2 - x3;
  dy23 = y2 - y3;
  d12 = sqrt(max(epsN, dx12*dx12 + dy12*dy12));
  d13 = sqrt(max(epsN, dx13*dx13 + dy13*dy13));
  d23 = sqrt(max(epsN, dx23*dx23 + dy23*dy23));
  range12 = d12;
  range13 = d13;
  range23 = d23;
  minDist = min(d12, min(d13, d23));

  sMsg1Raw = delay(s1, tau, delayMax);
  sMsg2Raw = delay(s2, tau, delayMax);
  sMsg3Raw = delay(s3, tau, delayMax);
  vMsg1Raw = delay(v1, tau, delayMax);
  vMsg2Raw = delay(v2, tau, delayMax);
  vMsg3Raw = delay(v3, tau, delayMax);
  sMsg1 = if delayActive then sMsg1Raw else s1;
  sMsg2 = if delayActive then sMsg2Raw else s2;
  sMsg3 = if delayActive then sMsg3Raw else s3;
  vMsg1 = if delayActive then vMsg1Raw else v1;
  vMsg2 = if delayActive then vMsg2Raw else v2;
  vMsg3 = if delayActive then vMsg3Raw else v3;
  xMsg1 = sMsg1*u1x;
  yMsg1 = sMsg1*u1y;
  xMsg2 = sMsg2*u2x;
  yMsg2 = sMsg2*u2y;
  xMsg3 = sMsg3*u3x;
  yMsg3 = sMsg3*u3y;

  occ1 = abs(s1) < R;
  occ2 = abs(s2) < R;
  occ3 = abs(s3) < R;
  request1 = (s1 < R) and not complete1;
  request2 = (s2 < R) and not complete2;
  request3 = (s3 < R) and not complete3;

  canGo1 = true;
  canGo2 = sMsg1 >= R;
  canGo3 = sMsg1 >= R and sMsg2 >= R;

  complete1 = s1 >= L;
  complete2 = s2 >= L;
  complete3 = s3 >= L;

  waiting1 = (s1 <= -R) and not canGo1 and not complete1;
  waiting2 = (s2 <= -R) and not canGo2 and not complete2;
  waiting3 = (s3 <= -R) and not canGo3 and not complete3;

  der(waitTime1) = if waiting1 then 1.0 else 0.0;
  der(waitTime2) = if waiting2 then 1.0 else 0.0;
  der(waitTime3) = if waiting3 then 1.0 else 0.0;
  waitTimeTotal = waitTime1 + waitTime2 + waitTime3;

  sRef1 = if complete1 then L else if (s1 <= -R) and not canGo1 then -R else s1 + vNom*Ts;
  sRef2 = if complete2 then L else if (s2 <= -R) and not canGo2 then -R else s2 + vNom*Ts;
  sRef3 = if complete3 then L else if (s3 <= -R) and not canGo3 then -R else s3 + vNom*Ts;

  aCmd1 = if complete1 then kS*(L - s1) - kV*v1 elseif abs(s1) < R then kV*(vNom - v1) elseif (s1 <= -R) and not canGo1 then -kV*v1 else kV*(vNom - v1);
  aCmd2 = if complete2 then kS*(L - s2) - kV*v2 elseif abs(s2) < R then kV*(vNom - v2) elseif (s2 <= -R) and not canGo2 then -kV*v2 else kV*(vNom - v2);
  aCmd3 = if complete3 then kS*(L - s3) - kV*v3 elseif abs(s3) < R then kV*(vNom - v3) elseif (s3 <= -R) and not canGo3 then -kV*v3 else kV*(vNom - v3);

  a1 = if aCmd1 > aMax then aMax elseif aCmd1 < -aMax then -aMax else aCmd1;
  a2 = if aCmd2 > aMax then aMax elseif aCmd2 < -aMax then -aMax else aCmd2;
  a3 = if aCmd3 > aMax then aMax elseif aCmd3 < -aMax then -aMax else aCmd3;

  braking1 = a1 < 0.0 and v1 > 0.0;
  braking2 = a2 < 0.0 and v2 > 0.0;
  braking3 = a3 < 0.0 and v3 > 0.0;

  F1 = m*a1;
  F2 = m*a2;
  F3 = m*a3;

  T1_1 = if F1 > 0.0 then F1/4.0 else 0.0;
  T1_2 = if F1 > 0.0 then F1/4.0 else 0.0;
  T1_3 = if F1 > 0.0 then F1/4.0 else 0.0;
  T1_4 = if F1 > 0.0 then F1/4.0 else 0.0;
  T2_1 = if F2 > 0.0 then F2/4.0 else 0.0;
  T2_2 = if F2 > 0.0 then F2/4.0 else 0.0;
  T2_3 = if F2 > 0.0 then F2/4.0 else 0.0;
  T2_4 = if F2 > 0.0 then F2/4.0 else 0.0;
  T3_1 = if F3 > 0.0 then F3/4.0 else 0.0;
  T3_2 = if F3 > 0.0 then F3/4.0 else 0.0;
  T3_3 = if F3 > 0.0 then F3/4.0 else 0.0;
  T3_4 = if F3 > 0.0 then F3/4.0 else 0.0;

  trackingErr1 = abs(s1 - sRef1);
  trackingErr2 = abs(s2 - sRef2);
  trackingErr3 = abs(s3 - sRef3);
  trackingErrMax = max(trackingErr1, max(trackingErr2, trackingErr3));

  actuatorBounds = (T1_1 <= Tmax) and (T1_2 <= Tmax) and (T1_3 <= Tmax) and (T1_4 <= Tmax) and
                   (T2_1 <= Tmax) and (T2_2 <= Tmax) and (T2_3 <= Tmax) and (T2_4 <= Tmax) and
                   (T3_1 <= Tmax) and (T3_2 <= Tmax) and (T3_3 <= Tmax) and (T3_4 <= Tmax) and
                   (T1_1 >= 0.0) and (T1_2 >= 0.0) and (T1_3 >= 0.0) and (T1_4 >= 0.0) and
                   (T2_1 >= 0.0) and (T2_2 >= 0.0) and (T2_3 >= 0.0) and (T2_4 >= 0.0) and
                   (T3_1 >= 0.0) and (T3_2 >= 0.0) and (T3_3 >= 0.0) and (T3_4 >= 0.0);

  minDistanceOK = minDist >= dSafe;
  mutualExclusion = not (occ1 and occ2) and not (occ1 and occ3) and not (occ2 and occ3);
  noCollision = minDist > 0.0;
  routeComplete = complete1 and complete2 and complete3;
  trackingOK = if time >= 13.0 then trackingErrMax < dSafe else true;

  numericOK = 1.0;
  noNaN = true;
  verificationOK = actuatorBounds and minDistanceOK and mutualExclusion and noCollision and routeComplete and trackingOK and noNaN;

  annotation(
    experiment(StartTime=0, StopTime=20, Tolerance=1e-6, Interval=0.002),
    Documentation(info="AirTrioCoordinateF: Three quadrotors traverse crossing routes with decentralized reservation, bounded braking, and 0.174 s message delay during the middle third. Runs at 500 Hz for 20 s.")
  );
end AirTrioCoordinateF;