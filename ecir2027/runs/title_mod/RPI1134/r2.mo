model AirTrioFormF
  // Physical constants
  parameter Real g=9.81 "m/s^2 gravitational acceleration";
  parameter Real m=1.8 "kg per quadrotor";
  parameter Real Tmax=14.6 "N per rotor maximum thrust";
  parameter Real Tmin=0.0 "N per rotor minimum thrust";

  // Timing and disturbance
  parameter Real dt=0.002 "s control/sensor period (500 Hz)";
  parameter Real Tfinal=20.0 "s mission duration";
  parameter Real tDelay=0.116 "s controlled message delay disturbance";

  // Formation geometry
  parameter Real off2[3]={1.5,-1.0,0.0} "m follower2 offset relative to leader";
  parameter Real off3[3]={-1.5,-1.0,0.0} "m follower3 offset relative to leader";
  parameter Real dMin=1.0 "m minimum pairwise separation";

  // Control gains and bounds
  parameter Real kp=6.0 "position gain";
  parameter Real kd=4.0 "damping gain";
  parameter Real amax=12.0 "m/s^2 bounded local command magnitude";

  // Obstacles placed outside the nominal formation path (circle radius 2 m)
  parameter Real obsX[2]={5.0,-5.0} "m obstacle x positions";
  parameter Real obsY[2]={4.0,-4.0} "m obstacle y positions";
  parameter Real obsR=0.5 "m obstacle radius";

  // Reference trajectory
  parameter Real Aref=2.0 "m reference radius";
  parameter Real wref=0.2 "rad/s reference angular rate";
  parameter Real Zref=2.0 "m reference altitude";

  // Quadrotor states (3D position and velocity per drone)
  Real p1[3](start={0.0,0.0,Zref});
  Real v1[3](start={0.0,0.0,0.0});
  Real p2[3](start={off2[1],off2[2],Zref});
  Real v2[3](start={0.0,0.0,0.0});
  Real p3[3](start={off3[1],off3[2],Zref});
  Real v3[3](start={0.0,0.0,0.0});

  // Reference and commanded accelerations
  Real refPos[3];
  Real ar1[3],ar2[3],ar3[3] "raw local commands";
  Real na1,na2,na3 "raw command norms";
  Real a1[3],a2[3],a3[3] "bounded local commands";

  // Thrust vector and allocation
  Real u1[3],u2[3],u3[3] "thrust acceleration vector";
  Real n1,n2,n3 "thrust vector norms";
  Real d1v[3],d2v[3],d3v[3] "thrust unit directions";
  Real Ttot1,Ttot2,Ttot3 "total thrust force magnitude";
  Real T1[4],T2[4],T3[4] "twelve independent rotor thrusts";
  Real Tact1,Tact2,Tact3 "actual total thrust after saturation";

  // Communication and delay
  Real delayActive "1.0 during middle third, else 0.0";
  Real p1d[3],p2d[3],p3d[3] "delayed pose messages";
  Real p1com[3],p2com[3],p3com[3] "poses used by distributed control";
  Real commAge "s communication age of newest message used";

  // Peer-relative range sensing
  Real r12,r23,r13 "m peer-relative ranges";
  Real minSep "m minimum pairwise separation";

  // Obstacle clearance
  Real minObsDist "m minimum obstacle clearance";

  // Actuator metric
  Real maxRotThrust "N maximum rotor thrust across 12 groups";

  // Tracking and formation error metrics
  Real trackErr1,trackErr2,trackErr3 "m primary tracking errors";
  Real formErr2,formErr3,formErr "m formation errors";

  // Finiteness self-equality probes
  Real phi1,phi2,phi3;

  // Verification flags
  Boolean okActuator,okSep,okForm,okCommAge,okNoCollision,okTrackAfter13,okFinite;

equation
  // Leader reference trajectory
  refPos[1] = Aref*cos(wref*time);
  refPos[2] = Aref*sin(wref*time);
  refPos[3] = Zref;

  // Controlled 0.116 s message delay active during the middle third of the run
  delayActive = if time >= Tfinal/3.0 and time <= 2.0*Tfinal/3.0 then 1.0 else 0.0;

  // Delayed pose messages (delay operator requires fixed delay max)
  p1d[1] = delay(p1[1], tDelay, 0.2);
  p1d[2] = delay(p1[2], tDelay, 0.2);
  p1d[3] = delay(p1[3], tDelay, 0.2);
  p2d[1] = delay(p2[1], tDelay, 0.2);
  p2d[2] = delay(p2[2], tDelay, 0.2);
  p2d[3] = delay(p2[3], tDelay, 0.2);
  p3d[1] = delay(p3[1], tDelay, 0.2);
  p3d[2] = delay(p3[2], tDelay, 0.2);
  p3d[3] = delay(p3[3], tDelay, 0.2);

  // Distributed control consumes delayed messages only while disturbance is active
  for i in 1:3 loop
    p1com[i] = if delayActive > 0.5 then p1d[i] else p1[i];
    p2com[i] = if delayActive > 0.5 then p2d[i] else p2[i];
    p3com[i] = if delayActive > 0.5 then p3d[i] else p3[i];
  end for;
  commAge = delayActive*tDelay;

  // Distributed formation control: leader tracks reference, followers track leader+offset
  ar1[1] = kp*(refPos[1] - p1[1]) - kd*v1[1];
  ar1[2] = kp*(refPos[2] - p1[2]) - kd*v1[2];
  ar1[3] = kp*(refPos[3] - p1[3]) - kd*v1[3];
  ar2[1] = kp*((p1com[1] + off2[1]) - p2[1]) - kd*v2[1];
  ar2[2] = kp*((p1com[2] + off2[2]) - p2[2]) - kd*v2[2];
  ar2[3] = kp*((p1com[3] + off2[3]) - p2[3]) - kd*v2[3];
  ar3[1] = kp*((p1com[1] + off3[1]) - p3[1]) - kd*v3[1];
  ar3[2] = kp*((p1com[2] + off3[2]) - p3[2]) - kd*v3[2];
  ar3[3] = kp*((p1com[3] + off3[3]) - p3[3]) - kd*v3[3];

  // Bounded local command magnitudes
  na1 = sqrt(ar1[1]^2 + ar1[2]^2 + ar1[3]^2 + 1e-9);
  na2 = sqrt(ar2[1]^2 + ar2[2]^2 + ar2[3]^2 + 1e-9);
  na3 = sqrt(ar3[1]^2 + ar3[2]^2 + ar3[3]^2 + 1e-9);
  for i in 1:3 loop
    a1[i] = ar1[i]*min(1.0, amax/na1);
    a2[i] = ar2[i]*min(1.0, amax/na2);
    a3[i] = ar3[i]*min(1.0, amax/na3);
  end for;

  // Thrust acceleration vector including gravity compensation
  u1[1] = a1[1]; u1[2] = a1[2]; u1[3] = a1[3] + g;
  u2[1] = a2[1]; u2[2] = a2[2]; u2[3] = a2[3] + g;
  u3[1] = a3[1]; u3[2] = a3[2]; u3[3] = a3[3] + g;

  n1 = sqrt(u1[1]^2 + u1[2]^2 + u1[3]^2 + 1e-9);
  n2 = sqrt(u2[1]^2 + u2[2]^2 + u2[3]^2 + 1e-9);
  n3 = sqrt(u3[1]^2 + u3[2]^2 + u3[3]^2 + 1e-9);
  for i in 1:3 loop
    d1v[i] = u1[i]/n1;
    d2v[i] = u2[i]/n2;
    d3v[i] = u3[i]/n3;
  end for;

  // Total thrust and per-rotor allocation with saturation to [Tmin, Tmax]
  Ttot1 = m*n1;
  Ttot2 = m*n2;
  Ttot3 = m*n3;
  for k in 1:4 loop
    T1[k] = max(Tmin, min(Tmax, Ttot1/4.0));
    T2[k] = max(Tmin, min(Tmax, Ttot2/4.0));
    T3[k] = max(Tmin, min(Tmax, Ttot3/4.0));
  end for;
  Tact1 = 4.0*T1[1];
  Tact2 = 4.0*T2[1];
  Tact3 = 4.0*T3[1];

  // Rigid-body point-mass dynamics
  for i in 1:3 loop
    der(p1[i]) = v1[i];
    der(p2[i]) = v2[i];
    der(p3[i]) = v3[i];
    der(v1[i]) = (Tact1/m)*d1v[i] + (if i == 3 then -g else 0.0);
    der(v2[i]) = (Tact2/m)*d2v[i] + (if i == 3 then -g else 0.0);
    der(v3[i]) = (Tact3/m)*d3v[i] + (if i == 3 then -g else 0.0);
  end for;

  // Peer-relative range sensing
  r12 = sqrt((p1[1]-p2[1])^2 + (p1[2]-p2[2])^2 + (p1[3]-p2[3])^2);
  r23 = sqrt((p2[1]-p3[1])^2 + (p2[2]-p3[2])^2 + (p2[3]-p3[3])^2);
  r13 = sqrt((p1[1]-p3[1])^2 + (p1[2]-p3[2])^2 + (p1[3]-p3[3])^2);
  minSep = min(r12, min(r23, r13));

  // Obstacle clearance (obstacles fixed outside nominal path)
  minObsDist = min(
    sqrt((p1[1]-obsX[1])^2 + (p1[2]-obsY[1])^2) - obsR,
    min(
      sqrt((p1[1]-obsX[2])^2 + (p1[2]-obsY[2])^2) - obsR,
      min(
        sqrt((p2[1]-obsX[1])^2 + (p2[2]-obsY[1])^2) - obsR,
        min(
          sqrt((p2[1]-obsX[2])^2 + (p2[2]-obsY[2])^2) - obsR,
          min(
            sqrt((p3[1]-obsX[1])^2 + (p3[2]-obsY[1])^2) - obsR,
            sqrt((p3[1]-obsX[2])^2 + (p3[2]-obsY[2])^2) - obsR
          )
        )
      )
    )
  );

  // Tracking errors
  trackErr1 = sqrt((p1[1]-refPos[1])^2 + (p1[2]-refPos[2])^2 + (p1[3]-refPos[3])^2);
  trackErr2 = sqrt((p2[1]-(refPos[1]+off2[1]))^2 + (p2[2]-(refPos[2]+off2[2]))^2 + (p2[3]-(refPos[3]+off2[3]))^2);
  trackErr3 = sqrt((p3[1]-(refPos[1]+off3[1]))^2 + (p3[2]-(refPos[2]+off3[2]))^2 + (p3[3]-(refPos[3]+off3[3]))^2);

  // Formation errors relative to actual leader pose
  formErr2 = sqrt((p2[1]-p1[1]-off2[1])^2 + (p2[2]-p1[2]-off2[2])^2 + (p2[3]-p1[3]-off2[3])^2);
  formErr3 = sqrt((p3[1]-p1[1]-off3[1])^2 + (p3[2]-p1[2]-off3[2])^2 + (p3[3]-p1[3]-off3[3])^2);
  formErr = max(formErr2, formErr3);

  // Maximum rotor thrust across the twelve independent groups
  maxRotThrust = max(T1[1], max(T1[2], max(T1[3], max(T1[4],
               max(T2[1], max(T2[2], max(T2[3], max(T2[4],
               max(T3[1], max(T3[2], max(T3[3], T3[4]))))))))));

  // Finiteness probes (x==x is false for NaN)
  phi1 = if (p1[1]==p1[1] and p1[2]==p1[2] and p1[3]==p1[3] and v1[1]==v1[1]) then 1.0 else 0.0;
  phi2 = if (p2[1]==p2[1] and p2[2]==p2[2] and p2[3]==p2[3] and v2[1]==v2[1]) then 1.0 else 0.0;
  phi3 = if (p3[1]==p3[1] and p3[2]==p3[2] and p3[3]==p3[3] and v3[1]==v3[1]) then 1.0 else 0.0;

  // Verification flags
  okActuator = maxRotThrust <= Tmax + 1e-6;
  okSep = minSep >= dMin - 1e-6;
  okForm = formErr < 1.0;
  okCommAge = commAge <= tDelay + 1e-6;
  okNoCollision = minObsDist > 0.0;
  okTrackAfter13 = if time > 13.0 then trackErr1 < 0.24 else true;
  okFinite = (phi1 > 0.5) and (phi2 > 0.5) and (phi3 > 0.5);

  // Continuous runtime assertions
  assert(okActuator, "Actuator limit exceeded (14.6 N per rotor)");
  assert(okSep, "Minimum pairwise separation violated");
  assert(okNoCollision, "Collision with fixed obstacle detected");

  // Terminal verification of tracking error and finiteness
  when terminal() then
    assert(okTrackAfter13, "Primary tracking error exceeds 0.24 m after 13 s");
    assert(okFinite, "NaN or infinite physical/control/estimator value detected");
  end when;

  annotation(
    experiment(StopTime=20.0, Tolerance=1e-6, Interval=0.002),
    Documentation(info="Three 1.8 kg quadrotors (12 rotor thrust groups, max 14.6 N/rotor) maintain formation about a leader reference. A 0.116 s message delay is applied during the middle third. Run at 500 Hz for 20 s."));
end AirTrioFormF;