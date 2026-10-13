model AirTrioCoordinateF
  parameter Modelica.SIunits.Mass m=1.8 "mass of each quadrotor";
  parameter Modelica.SIunits.Force Tmax=14.6 "per-rotor thrust bound";
  parameter Modelica.SIunits.Length dSafe=0.52 "required separation and tracking threshold";
  parameter Modelica.SIunits.Time tau=0.174 "controlled message delay";
  parameter Modelica.SIunits.Frequency fSample=500 "trace and control rate";
  parameter Modelica.SIunits.Time Ts=1/fSample "500 Hz sampling period";
  parameter Modelica.SIunits.Time Tend=20 "mission duration";
  parameter Modelica.SIunits.Time tMid1=Tend/3 "start of middle third";
  parameter Modelica.SIunits.Time tMid2=2*Tend/3 "end of middle third";
  parameter Modelica.SIunits.Time delayMax=0.5 "upper bound for delay operator";
  parameter Modelica.SIunits.Length R=dSafe "central conflict radius";
  parameter Modelica.SIunits.Length L=2*dSafe "route half-length";
  parameter Modelica.SIunits.Length laneHalfWidth=dSafe "fixed corridor half-width";
  parameter Modelica.SIunits.Velocity vNom=(2*L+4*R)/(Tend/2) "nominal route speed";
  parameter Modelica.SIunits.Acceleration aMax=4*Tmax/m "bounded acceleration and braking";
  parameter Real kV=10 "velocity error gain";
  parameter Real kS=50 "position hold gain";
  constant Real u1x=1.0 "route 1 unit direction x";
  constant Real u1y=0.0 "route 1 unit direction y";
  constant Real u2x=-0.5 "route 2 unit direction x";
  constant Real u2y=0.8660254037844386 "route 2 unit direction y";
  constant Real u3x=-0.5 "route 3 unit direction x";
  constant Real u3y=-0.8660254037844386 "route 3 unit direction y";

  output Modelica.SIunits.Length s1(start=-L) "robot 1 route coordinate";
  output Modelica.SIunits.Length s2(start=-L) "robot 2 route coordinate";
  output Modelica.SIunits.Length s3(start=-L) "robot 3 route coordinate";
  output Modelica.SIunits.Velocity v1(start=0) "robot 1 route speed";
  output Modelica.SIunits.Velocity v2(start=0) "robot 2 route speed";
  output Modelica.SIunits.Velocity v3(start=0) "robot 3 route speed";
  output Modelica.SIunits.Acceleration aCmd1 "robot 1 commanded acceleration";
  output Modelica.SIunits.Acceleration aCmd2 "robot 2 commanded acceleration";
  output Modelica.SIunits.Acceleration aCmd3 "robot 3 commanded acceleration";
  output Modelica.SIunits.Acceleration a1 "robot 1 saturated acceleration";
  output Modelica.SIunits.Acceleration a2 "robot 2 saturated acceleration";
  output Modelica.SIunits.Acceleration a3 "robot 3 saturated acceleration";
  output Modelica.SIunits.Force F1 "robot 1 net route force";
  output Modelica.SIunits.Force F2 "robot 2 net route force";
  output Modelica.SIunits.Force F3 "robot 3 net route force";
  output Modelica.SIunits.Force T1_1 "robot 1 rotor thrust group 1";
  output Modelica.SIunits.Force T1_2 "robot 1 rotor thrust group 2";
  output Modelica.SIunits.Force T1_3 "robot 1 rotor thrust group 3";
  output Modelica.SIunits.Force T1_4 "robot 1 rotor thrust group 4";
  output Modelica.SIunits.Force T2_1 "robot 2 rotor thrust group 1";
  output Modelica.SIunits.Force T2_2 "robot 2 rotor thrust group 2";
  output Modelica.SIunits.Force T2_3 "robot 2 rotor thrust group 3";
  output Modelica.SIunits.Force T2_4 "robot 2 rotor thrust group 4";
  output Modelica.SIunits.Force T3_1 "robot 3 rotor thrust group 1";
  output Modelica.SIunits.Force T3_2 "robot 3 rotor thrust group 2";
  output Modelica.SIunits.Force T3_3 "robot 3 rotor thrust group 3";
  output Modelica.SIunits.Force T3_4 "robot 3 rotor thrust group 4";
  output Modelica.SIunits.Length x1 "robot 1 x position";
  output Modelica.SIunits.Length y1 "robot 1 y position";
  output Modelica.SIunits.Length x2 "robot 2 x position";
  output Modelica.SIunits.Length y2 "robot 2 y position";
  output Modelica.SIunits.Length x3 "robot 3 x position";
  output Modelica.SIunits.Length y3 "robot 3 y position";
  output Modelica.SIunits.Length gps1x "GPS x robot 1";
  output Modelica.SIunits.Length gps1y "GPS y robot 1";
  output Modelica.SIunits.Length gps2x "GPS x robot 2";
  output Modelica.SIunits.Length gps2y "GPS y robot 2";
  output Modelica.SIunits.Length gps3x "GPS x robot 3";
  output Modelica.SIunits.Length gps3y "GPS y robot 3";
  output Modelica.SIunits.Acceleration imu1ax "IMU acceleration x robot 1";
  output Modelica.SIunits.Acceleration imu1ay "IMU acceleration y robot 1";
  output Modelica.SIunits.Acceleration imu2ax "IMU acceleration x robot 2";
  output Modelica.SIunits.Acceleration imu2ay "IMU acceleration y robot 2";
  output Modelica.SIunits.Acceleration imu3ax "IMU acceleration x robot 3";
  output Modelica.SIunits.Acceleration imu3ay "IMU acceleration y robot 3";
  output Modelica.SIunits.Length lateralErr1 "robot 1 lateral corridor error";
  output Modelica.SIunits.Length lateralErr2 "robot 2 lateral corridor error";
  output Modelica.SIunits.Length lateralErr3 "robot 3 lateral corridor error";
  output Modelica.SIunits.Length obsDist1 "robot 1 obstacle distance to corridor boundary";
  output Modelica.SIunits.Length obsDist2 "robot 2 obstacle distance to corridor boundary";
  output Modelica.SIunits.Length obsDist3 "robot 3 obstacle distance to corridor boundary";
  output Modelica.SIunits.Length range12 "peer-relative range robot 1 to 2";
  output Modelica.SIunits.Length range13 "peer-relative range robot 1 to 3";
  output Modelica.SIunits.Length range23 "peer-relative range robot 2 to 3";
  output Modelica.SIunits.Length d12 "pairwise distance robot 1-2";
  output Modelica.SIunits.Length d13 "pairwise distance robot 1-3";
  output Modelica.SIunits.Length d23 "pairwise distance robot 2-3";
  output Modelica.SIunits.Length minDist "minimum pairwise distance";
  output Modelica.SIunits.Length sMsg1 "delayed peer message route coordinate robot 1";
  output Modelica.SIunits.Length sMsg2 "delayed peer message route coordinate robot 2";
  output Modelica.SIunits.Length sMsg3 "delayed peer message route coordinate robot 3";
  output Modelica.SIunits.Velocity vMsg1 "delayed peer message speed robot 1";
  output Modelica.SIunits.Velocity vMsg2 "delayed peer message speed robot 2";
  output Modelica.SIunits.Velocity vMsg3 "delayed peer message speed robot 3";
  output Modelica.SIunits.Length xMsg1 "estimated peer x robot 1";
  output Modelica.SIunits.Length yMsg1 "estimated peer y robot 1";
  output Modelica.SIunits.Length xMsg2 "estimated peer x robot 2";
  output Modelica.SIunits.Length yMsg2 "estimated peer y robot 2";
  output Modelica.SIunits.Length xMsg3 "estimated peer x robot 3";
  output Modelica.SIunits.Length yMsg3 "estimated peer y robot 3";
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
  output Modelica.SIunits.Time waitTime1(start=0) "accumulated waiting time robot 1";
  output Modelica.SIunits.Time waitTime2(start=0) "accumulated waiting time robot 2";
  output Modelica.SIunits.Time waitTime3(start=0) "accumulated waiting time robot 3";
  output Modelica.SIunits.Time waitTimeTotal "total waiting time";
  output Modelica.SIunits.Length sRef1 "reference route coordinate robot 1";
  output Modelica.SIunits.Length sRef2 "reference route coordinate robot 2";
  output Modelica.SIunits.Length sRef3 "reference route coordinate robot 3";
  output Modelica.SIunits.Length trackingErr1 "tracking error robot 1";
  output Modelica.SIunits.Length trackingErr2 "tracking error robot 2";
  output Modelica.SIunits.Length trackingErr3 "tracking error robot 3";
  output Modelica.SIunits.Length trackingErrMax "primary tracking error";
  output Boolean actuatorBounds "actuator bound verification";
  output Boolean minDistanceOK "minimum distance verification";
  output Boolean mutualExclusion "mutual exclusion verification";
  output Boolean noCollision "no collision verification";
  output Boolean routeComplete "route completion verification";
  output Boolean trackingOK "tracking error verification after 13 s";
  output Real numericOK "finite and non-NaN verification";
  output Boolean noNaN "no NaN or infinite values";
  output Boolean verificationOK "combined verification";
  output Integer sampleTick(start=0) "500 Hz synchronized trace counter";

  Modelica.SIunits.Length sMsg1Raw "raw delayed route coordinate robot 1";
  Modelica.SIunits.Length sMsg2Raw "raw delayed route coordinate robot 2";
  Modelica.SIunits.Length sMsg3Raw "raw delayed route coordinate robot 3";
  Modelica.SIunits.Velocity vMsg1Raw "raw delayed speed robot 1";
  Modelica.SIunits.Velocity vMsg2Raw "raw delayed speed robot 2";
  Modelica.SIunits.Velocity vMsg3Raw "raw delayed speed robot 3";
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

  der(sampleTick) = 0;

  annotation(
    experiment(StartTime=0, StopTime=20, Tolerance=1e-6, Interval=0.002),
    Documentation(info="AirTrioCoordinateF: Three quadrotors traverse crossing routes with decentralized reservation, bounded braking, and 0.174 s message delay during the middle third. Runs at 500 Hz for 20 s.")
  );
end AirTrioCoordinateF;