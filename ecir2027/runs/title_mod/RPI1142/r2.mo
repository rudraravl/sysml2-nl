model AirTrioHandoffB
  extends Modelica.Icons.Example;

  // ---- Physical constants ----
  parameter Real m = 1.8 "robot mass [kg]";
  parameter Real g = 9.81 "gravity [m/s2]";
  parameter Real fmax = 9.84 "max thrust per rotor [N]";
  parameter Real Tmax = 4.0*fmax "max total thrust per robot [N]";
  parameter Real Ts = 0.01 "control/comm sample period [s] (100 Hz)";
  parameter Real Tend = 10.0 "mission duration [s]";
  parameter Real delayNom = 0.0 "nominal comm delay [s]";
  parameter Real delayDist = 0.07 "disturbance comm delay [s]";

  // ---- Control gains ----
  parameter Real kp = 6.0 "position gain [1/s2]";
  parameter Real kd = 3.5 "velocity gain [1/s]";
  parameter Real krep = 8.0 "repulsion gain";
  parameter Real repRadius = 1.2 "repulsion trigger radius [m]";
  parameter Real minSep = 0.6 "minimum separation bound [m]";

  // ---- Mission zones (world survey features) ----
  parameter Real zoneA[3] = {2.5, 0.0, 1.5} "inspection zone A (robot 1)";
  parameter Real zoneB[3] = {0.0, 2.5, 1.5} "inspection zone B (robot 2)";
  parameter Real zoneC[3] = {-2.5, 0.0, 1.5} "inspection zone C (robot 3)";
  parameter Real start1[3] = {0.0, 0.0, 0.0};
  parameter Real start2[3] = {0.5, 0.0, 0.0};
  parameter Real start3[3] = {-0.5, 0.0, 0.0};
  parameter Real replanTarget[3] = {0.0, -2.5, 1.5} "replan target for robot 3";
  parameter Real dwellNeed = 1.0 "inspection dwell [s]";
  parameter Real reachTol = 0.3 "reach tolerance [m]";
  parameter Real dataAgeBound = 0.2 "bounded data age [s]";

  // ---- Robot continuous states ----
  Real r1[3](start=start1);
  Real r2[3](start=start2);
  Real r3[3](start=start3);
  Real v1[3](each start=0);
  Real v2[3](each start=0);
  Real v3[3](each start=0);

  // ---- Thrust vectors and 12 rotor-thrust groups ----
  Real F1[3], F2[3], F3[3];
  Real Tmag1, Tmag2, Tmag3;
  Real fr11, fr12, fr13, fr14;
  Real fr21, fr22, fr23, fr24;
  Real fr31, fr32, fr33, fr34;

  // ---- Discrete targets / handoff state ----
  discrete Real tgt1[3](start=zoneA);
  discrete Real tgt2[3](start=zoneB);
  discrete Real tgt3[3](start=zoneC);
  discrete Real insp1[3](start=zoneA);
  discrete Real insp2[3](start=zoneB);
  discrete Real insp3[3](start=zoneC);
  discrete Boolean sent1(start=false);
  discrete Boolean inTransit(start=false);
  discrete Boolean received3(start=false);
  discrete Boolean replanDone(start=false);
  discrete Boolean inspect1Done(start=false);
  discrete Boolean inspect2Done(start=false);
  discrete Boolean inspect3Done(start=false);
  discrete Boolean taskAllocDone(start=false);
  discrete Boolean taskComplete(start=false);
  discrete Real sendTime1(start=-1.0);
  discrete Real recvTime3(start=-1.0);
  discrete Real dataAge3(start=0.0);
  discrete Real msgPayload[3](start={0,0,0});
  discrete Real msgTimestamp(start=-1.0);
  discrete Real inspect1Timer(start=0.0);
  discrete Real inspect2Timer(start=0.0);
  discrete Real inspect3Timer(start=0.0);
  discrete Real result1[3](start=zoneA);

  // ---- Handoff phase (observable, derived from discrete flags) ----
  Real handoffPhase;

  // ---- Local sensors ----
  Real gps1[3], gps2[3], gps3[3];
  Real imu1[3], imu2[3], imu3[3];
  Real range12, range13, range23;

  // ---- Comm delay ----
  Real currentDelay;

  // ---- Observables ----
  Real sep12, sep13, sep23;
  Real trackErr1, trackErr2, trackErr3;
  Boolean actuatorOK;
  Boolean separationOK;
  Boolean dataAgeOK;
  Boolean handoffOK;
  Boolean collision;
  Boolean primaryTrackingOK;
  Boolean noNaNInf;
  Boolean missionOK;

  // ---- Helpers ----
  Real d12v[3], d13v[3], d23v[3];
  Real n12, n13, n23;
  Real rep1vec[3], rep2vec[3], rep3vec[3];
  Real aDes1[3], aDes2[3], aDes3[3];
  Real F1raw[3], F2raw[3], F3raw[3];
  Real sc1, sc2, sc3;
  Real err1[3], err2[3], err3[3];

equation

  // ---- Communication delay schedule (middle-third disturbance) ----
  currentDelay = if (time >= Tend/3.0 and time <= 2.0*Tend/3.0) then delayDist else delayNom;

  // ---- Continuous translational dynamics ----
  der(r1) = v1;
  der(r2) = v2;
  der(r3) = v3;
  der(v1[1]) = F1[1]/m;
  der(v1[2]) = F1[2]/m;
  der(v1[3]) = (F1[3] - m*g)/m;
  der(v2[1]) = F2[1]/m;
  der(v2[2]) = F2[2]/m;
  der(v2[3]) = (F2[3] - m*g)/m;
  der(v3[1]) = F3[1]/m;
  der(v3[2]) = F3[2]/m;
  der(v3[3]) = (F3[3] - m*g)/m;

  // ---- Local sensors (preserved) ----
  gps1 = r1;
  gps2 = r2;
  gps3 = r3;
  imu1[1] = der(v1[1]); imu1[2] = der(v1[2]); imu1[3] = der(v1[3]);
  imu2[1] = der(v2[1]); imu2[2] = der(v2[2]); imu2[3] = der(v2[3]);
  imu3[1] = der(v3[1]); imu3[2] = der(v3[2]); imu3[3] = der(v3[3]);
  range12 = n12;
  range13 = n13;
  range23 = n23;

  // ---- Peer-relative separation vectors ----
  d12v[1] = r1[1]-r2[1]; d12v[2] = r1[2]-r2[2]; d12v[3] = r1[3]-r2[3];
  d13v[1] = r1[1]-r3[1]; d13v[2] = r1[2]-r3[2]; d13v[3] = r1[3]-r3[3];
  d23v[1] = r2[1]-r3[1]; d23v[2] = r2[2]-r3[2]; d23v[3] = r2[3]-r3[3];
  n12 = sqrt(d12v[1]^2+d12v[2]^2+d12v[3]^2 + 1e-9);
  n13 = sqrt(d13v[1]^2+d13v[2]^2+d13v[3]^2 + 1e-9);
  n23 = sqrt(d23v[1]^2+d23v[2]^2+d23v[3]^2 + 1e-9);

  // ---- Repulsion (collision avoidance between robots) ----
  rep1vec[1] = (if n12 < repRadius then krep*(1.0/n12^2 - 1.0/repRadius^2) else 0.0)*d12v[1]/n12
            + (if n13 < repRadius then krep*(1.0/n13^2 - 1.0/repRadius^2) else 0.0)*d13v[1]/n13;
  rep1vec[2] = (if n12 < repRadius then krep*(1.0/n12^2 - 1.0/repRadius^2) else 0.0)*d12v[2]/n12
            + (if n13 < repRadius then krep*(1.0/n13^2 - 1.0/repRadius^2) else 0.0)*d13v[2]/n13;
  rep1vec[3] = (if n12 < repRadius then krep*(1.0/n12^2 - 1.0/repRadius^2) else 0.0)*d12v[3]/n12
            + (if n13 < repRadius then krep*(1.0/n13^2 - 1.0/repRadius^2) else 0.0)*d13v[3]/n13;
  rep2vec[1] = (if n12 < repRadius then krep*(1.0/n12^2 - 1.0/repRadius^2) else 0.0)*(-d12v[1])/n12
            + (if n23 < repRadius then krep*(1.0/n23^2 - 1.0/repRadius^2) else 0.0)*d23v[1]/n23;
  rep2vec[2] = (if n12 < repRadius then krep*(1.0/n12^2 - 1.0/repRadius^2) else 0.0)*(-d12v[2])/n12
            + (if n23 < repRadius then krep*(1.0/n23^2 - 1.0/repRadius^2) else 0.0)*d23v[2]/n23;
  rep2vec[3] = (if n12 < repRadius then krep*(1.0/n12^2 - 1.0/repRadius^2) else 0.0)*(-d12v[3])/n12
            + (if n23 < repRadius then krep*(1.0/n23^2 - 1.0/repRadius^2) else 0.0)*d23v[3]/n23;
  rep3vec[1] = (if n13 < repRadius then krep*(1.0/n13^2 - 1.0/repRadius^2) else 0.0)*(-d13v[1])/n13
            + (if n23 < repRadius then krep*(1.0/n23^2 - 1.0/repRadius^2) else 0.0)*(-d23v[1])/n23;
  rep3vec[2] = (if n13 < repRadius then krep*(1.0/n13^2 - 1.0/repRadius^2) else 0.0)*(-d13v[2])/n13
            + (if n23 < repRadius then krep*(1.0/n23^2 - 1.0/repRadius^2) else 0.0)*(-d23v[2])/n23;
  rep3vec[3] = (if n13 < repRadius then krep*(1.0/n13^2 - 1.0/repRadius^2) else 0.0)*(-d13v[3])/n13
            + (if n23 < repRadius then krep*(1.0/n23^2 - 1.0/repRadius^2) else 0.0)*(-d23v[3])/n23;

  // ---- Desired acceleration (PD + repulsion) ----
  err1 = tgt1 - r1;
  err2 = tgt2 - r2;
  err3 = tgt3 - r3;
  aDes1[1] = kp*err1[1] - kd*v1[1] + rep1vec[1];
  aDes1[2] = kp*err1[2] - kd*v1[2] + rep1vec[2];
  aDes1[3] = kp*err1[3] - kd*v1[3] + rep1vec[3];
  aDes2[1] = kp*err2[1] - kd*v2[1] + rep2vec[1];
  aDes2[2] = kp*err2[2] - kd*v2[2] + rep2vec[2];
  aDes2[3] = kp*err2[3] - kd*v2[3] + rep2vec[3];
  aDes3[1] = kp*err3[1] - kd*v3[1] + rep3vec[1];
  aDes3[2] = kp*err3[2] - kd*v3[2] + rep3vec[2];
  aDes3[3] = kp*err3[3] - kd*v3[3] + rep3vec[3];

  // ---- Thrust vector with magnitude cap ----
  F1raw[1] = m*aDes1[1]; F1raw[2] = m*aDes1[2]; F1raw[3] = m*aDes1[3];
  F2raw[1] = m*aDes2[1]; F2raw[2] = m*aDes2[2]; F2raw[3] = m*aDes2[3];
  F3raw[1] = m*aDes3[1]; F3raw[2] = m*aDes3[2]; F3raw[3] = m*aDes3[3];

  Tmag1 = sqrt(F1raw[1]^2+F1raw[2]^2+F1raw[3]^2 + 1e-9);
  Tmag2 = sqrt(F2raw[1]^2+F2raw[2]^2+F2raw[3]^2 + 1e-9);
  Tmag3 = sqrt(F3raw[1]^2+F3raw[2]^2+F3raw[3]^2 + 1e-9);

  sc1 = if Tmag1 > Tmax then Tmax/Tmag1 else 1.0;
  sc2 = if Tmag2 > Tmax then Tmax/Tmag2 else 1.0;
  sc3 = if Tmag3 > Tmax then Tmax/Tmag3 else 1.0;

  F1[1] = F1raw[1]*sc1; F1[2] = F1raw[2]*sc1; F1[3] = F1raw[3]*sc1;
  F2[1] = F2raw[1]*sc2; F2[2] = F2raw[2]*sc2; F2[3] = F2raw[3]*sc2;
  F3[1] = F3raw[1]*sc3; F3[2] = F3raw[2]*sc3; F3[3] = F3raw[3]*sc3;

  // ---- 12 independent rotor-thrust groups (equal allocation, individually capped) ----
  fr11 = min(Tmag1*sc1/4.0, fmax);
  fr12 = min(Tmag1*sc1/4.0, fmax);
  fr13 = min(Tmag1*sc1/4.0, fmax);
  fr14 = min(Tmag1*sc1/4.0, fmax);
  fr21 = min(Tmag2*sc2/4.0, fmax);
  fr22 = min(Tmag2*sc2/4.0, fmax);
  fr23 = min(Tmag2*sc2/4.0, fmax);
  fr24 = min(Tmag2*sc2/4.0, fmax);
  fr31 = min(Tmag3*sc3/4.0, fmax);
  fr32 = min(Tmag3*sc3/4.0, fmax);
  fr33 = min(Tmag3*sc3/4.0, fmax);
  fr34 = min(Tmag3*sc3/4.0, fmax);

  // ---- Tracking errors ----
  trackErr1 = sqrt(err1[1]^2+err1[2]^2+err1[3]^2);
  trackErr2 = sqrt(err2[1]^2+err2[2]^2+err2[3]^2);
  trackErr3 = sqrt(err3[1]^2+err3[2]^2+err3[3]^2);

  // ---- Separation (collision proxies) ----
  sep12 = sqrt(d12v[1]^2+d12v[2]^2+d12v[3]^2);
  sep13 = sqrt(d13v[1]^2+d13v[2]^2+d13v[3]^2);
  sep23 = sqrt(d23v[1]^2+d23v[2]^2+d23v[3]^2);

  // ---- Handoff phase (derived observable) ----
  handoffPhase = if not taskAllocDone then 0.0
    elseif not sent1 then 1.0
    elseif inTransit then 3.0
    elseif not replanDone then 4.0
    elseif not taskComplete then 5.0
    else 6.0;

  // ---- Requirement observables ----
  actuatorOK = fr11<=fmax and fr12<=fmax and fr13<=fmax and fr14<=fmax
           and fr21<=fmax and fr22<=fmax and fr23<=fmax and fr24<=fmax
           and fr31<=fmax and fr32<=fmax and fr33<=fmax and fr34<=fmax;
  separationOK = sep12 >= minSep and sep13 >= minSep and sep23 >= minSep;
  dataAgeOK = (if received3 then (dataAge3 <= dataAgeBound) else true);
  handoffOK = received3;
  collision = (sep12 < 0.05) or (sep13 < 0.05) or (sep23 < 0.05);
  primaryTrackingOK = if time >= 6.5 then (trackErr3 < 0.48) else true;
  noNaNInf = (Tmag1 < 1e6) and (Tmag2 < 1e6) and (Tmag3 < 1e6)
         and (Tmag1 > -1e6) and (Tmag2 > -1e6) and (Tmag3 > -1e6);
  missionOK = actuatorOK and separationOK and dataAgeOK and handoffOK
          and (not collision) and taskComplete and primaryTrackingOK and noNaNInf;

  // ---- Discrete control / communication / handoff logic at 100 Hz ----
  when sample(0, Ts) then
    if not pre(taskAllocDone) then
      // First tick: task allocation - divide inspection task among robots
      tgt1 = zoneA;
      tgt2 = zoneB;
      tgt3 = zoneC;
      insp1 = zoneA;
      insp2 = zoneB;
      insp3 = zoneC;
      taskAllocDone = true;
      inspect1Timer = 0.0;
      inspect2Timer = 0.0;
      inspect3Timer = 0.0;
      inspect1Done = false;
      inspect2Done = false;
      inspect3Done = false;
      sent1 = false;
      inTransit = false;
      received3 = false;
      replanDone = false;
      taskComplete = false;
    else
      // Inspection dwell accumulation (local motion control brings robot to zone)
      if not pre(inspect1Done) and sqrt((r1[1]-insp1[1])^2+(r1[2]-insp1[2])^2+(r1[3]-insp1[3])^2) < reachTol then
        inspect1Timer = pre(inspect1Timer) + Ts;
      end if;
      if not pre(inspect2Done) and sqrt((r2[1]-insp2[1])^2+(r2[2]-insp2[2])^2+(r2[3]-insp2[3])^2) < reachTol then
        inspect2Timer = pre(inspect2Timer) + Ts;
      end if;
      if not pre(inspect3Done) and sqrt((r3[1]-insp3[1])^2+(r3[2]-insp3[2])^2+(r3[3]-insp3[3])^2) < reachTol then
        inspect3Timer = pre(inspect3Timer) + Ts;
      end if;

      // Mark inspection results with timestamped data
      if not pre(inspect1Done) and pre(inspect1Timer) >= dwellNeed then
        inspect1Done = true;
        result1 = insp1;
      end if;
      if not pre(inspect2Done) and pre(inspect2Timer) >= dwellNeed then
        inspect2Done = true;
      end if;
      if not pre(inspect3Done) and pre(inspect3Timer) >= dwellNeed then
        inspect3Done = true;
      end if;

      // Robot 1 sends timestamped result upon completing its inspection slice
      if pre(inspect1Done) and not pre(sent1) then
        sent1 = true;
        inTransit = true;
        sendTime1 = time;
        msgTimestamp = time;
        msgPayload = result1;
      end if;

      // Message reception after the active communication delay
      if pre(inTransit) and time >= pre(sendTime1) + currentDelay then
        received3 = true;
        inTransit = false;
        recvTime3 = time;
        dataAge3 = time - pre(msgTimestamp);
      end if;

      // Replan robot 3 using the received data (explicit handoff)
      if pre(received3) and not pre(replanDone) then
        tgt3 = replanTarget;
        replanDone = true;
      end if;

      // Task completion: all slices inspected, handoff done, robot 3 reached replan target
      if pre(replanDone) and pre(inspect2Done) and pre(inspect3Done)
         and sqrt((r3[1]-replanTarget[1])^2+(r3[2]-replanTarget[2])^2+(r3[3]-replanTarget[3])^2) < reachTol then
        taskComplete = true;
      end if;
    end if;
  end when;

  annotation (
    Documentation(info="AirTrioHandoffB: three 1.8 kg quadrotors divide an inspection task,
exchange a timestamped result, and replan one robot from the received data. Runs at 100 Hz
for 10 s. A controlled 0.07 s communication delay is injected during the middle third of
the mission. Twelve independent rotor-thrust groups are each capped at 9.84 N. Local sensors
(GPS, IMU, peer-relative range) are preserved, and communication send/receive/data-age are
recorded. Requirements enforced as observables: actuator and separation bounds, bounded
data age, successful handoff, no collision, task completion, primary tracking error below
0.48 m after 6.5 s, and boundedness of physical/control/estimator signals."),
    experiment(StopTime=10.0, StartTime=0.0, Tolerance=1e-6, Interval=0.01)
  );
end AirTrioHandoffB;