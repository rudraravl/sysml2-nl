model AssemblyArmCarryC
  "Fixed-base articulated manipulator with computed-torque control and bounded wrist-force correction"
  import SI = Modelica.SIunits;
  import Modelica.Constants.pi;

  // ---------------------- Requirement parameters ----------------------
  parameter SI.Length L1=0.50 "capsule-link length 1";
  parameter SI.Length L2=0.40 "capsule-link length 2";
  parameter SI.Length L3=0.28 "capsule-link length 3";
  parameter SI.Length L4=0.16 "capsule-link length 4";
  parameter SI.Mass m1=7 "link 1 mass";
  parameter SI.Mass m2=5 "link 2 mass";
  parameter SI.Mass m3=3 "link 3 mass";
  parameter SI.Mass m4=1 "link 4 mass";
  parameter SI.Mass m_payload=10.8 "controlled payload disturbance mass";
  parameter SI.Torque tauMax=101 "maximum command magnitude";
  parameter SI.Force wristForceMax=60 "bounded wrist-force correction magnitude";
  parameter Real primaryErrorTol=0.047 "primary tracking error tolerance after 7.8 s";
  parameter SI.Time Ts=1/125 "controller sample period";
  parameter SI.Time tEnd=12 "simulation duration";
  parameter SI.Time trajEnd=7.8 "trajectory completion time";
  parameter SI.Time tMiddleStart=4.0 "start of middle-third payload injection";
  parameter SI.Time tMiddleEnd=8.0 "end of middle-third payload injection";
  parameter Real g=9.81 "gravitational acceleration used by controller";

  // Controller tuning not specified by requirement; selected for stable 125 Hz tracking.
  parameter Real Kp[4]={60,60,40,20} "position feedback gains (1/s^2)";
  parameter Real Kd[4]={12,12,6,3} "velocity feedback gains (1/s)";
  parameter Real Kwrist=1.0 "wrist-force correction gain";
  parameter Real Mdiag[4]={m1*L1^2 + m2*L2^2 + m3*L3^2 + m4*L4^2,
                            m2*L2^2 + m3*L3^2 + m4*L4^2,
                            m3*L3^2 + m4*L4^2,
                            m4*L4^2} "diagonal computed-torque inertia estimate";

  // Joint travel bounds are not specified; a generic revolute bound is used.
  parameter Real qBound[4]={pi,pi,pi,pi} "generic joint travel bounds (rad)";

  // Base height and table/floor geometry are not specified.
  parameter SI.Length baseHeight=0.65 "selected fixed-base height to clear the floor";

  // MSL MultiBody has no collision solver; these flags record that collision is
  // enabled logically, but no contact forces are generated.
  parameter Boolean collisionEnabled=true "collision enabled flag";
  parameter Boolean floorCollisionEnabled=collisionEnabled "floor collision flag";
  parameter Boolean tableCollisionEnabled=collisionEnabled "table collision flag";

  // Trajectory
  parameter Real q0[4]={0,0,0,0} "initial joint angles (rad)";
  parameter Real qT[4]={0,-0.5,0.4,0} "requested final joint angles (rad)";

  // ---------------------- Plant ----------------------
  inner Modelica.Mechanics.MultiBody.World world;

  Modelica.Mechanics.MultiBody.Parts.FixedTranslation base(r={0,0,baseHeight});

  Modelica.Mechanics.MultiBody.Joints.Revolute j1(
    n={0,0,1},
    useAxisFlange=true,
    phi_start=q0[1],
    w_start=0);
  Modelica.Mechanics.MultiBody.Joints.Revolute j2(
    n={0,1,0},
    useAxisFlange=true,
    phi_start=q0[2],
    w_start=0);
  Modelica.Mechanics.MultiBody.Joints.Revolute j3(
    n={0,1,0},
    useAxisFlange=true,
    phi_start=q0[3],
    w_start=0);
  Modelica.Mechanics.MultiBody.Joints.Revolute j4(
    n={1,0,0},
    useAxisFlange=true,
    phi_start=q0[4],
    w_start=0);

  // Link inertias are not specified; uniform slender-rod placeholders are used.
  Modelica.Mechanics.MultiBody.Parts.BodyShape link1(
    r={L1,0,0},
    m=m1,
    r_CM={0.5*L1,0,0},
    I11=0.001,
    I22=m1*L1^2/12,
    I33=m1*L1^2/12);
  Modelica.Mechanics.MultiBody.Parts.BodyShape link2(
    r={L2,0,0},
    m=m2,
    r_CM={0.5*L2,0,0},
    I11=0.001,
    I22=m2*L2^2/12,
    I33=m2*L2^2/12);
  Modelica.Mechanics.MultiBody.Parts.BodyShape link3(
    r={L3,0,0},
    m=m3,
    r_CM={0.5*L3,0,0},
    I11=0.001,
    I22=m3*L3^2/12,
    I33=m3*L3^2/12);
  Modelica.Mechanics.MultiBody.Parts.BodyShape link4(
    r={L4,0,0},
    m=m4,
    r_CM={0.5*L4,0,0},
    I11=0.001,
    I22=m4*L4^2/12,
    I33=m4*L4^2/12);

  // Controlled payload disturbance injected as a wrist force during middle third.
  Modelica.Mechanics.MultiBody.Forces.WorldForce payloadDist;
  Modelica.Blocks.Sources.RealExpression payloadFx(y=payloadForce[1]);
  Modelica.Blocks.Sources.RealExpression payloadFy(y=payloadForce[2]);
  Modelica.Blocks.Sources.RealExpression payloadFz(y=payloadForce[3]);

  // Saturated torque drives
  Modelica.Mechanics.Rotational.Sources.Torque t1(useSupport=true);
  Modelica.Mechanics.Rotational.Sources.Torque t2(useSupport=true);
  Modelica.Mechanics.Rotational.Sources.Torque t3(useSupport=true);
  Modelica.Mechanics.Rotational.Sources.Torque t4(useSupport=true);
  Modelica.Blocks.Sources.RealExpression tauExpr1(y=tauSat[1]);
  Modelica.Blocks.Sources.RealExpression tauExpr2(y=tauSat[2]);
  Modelica.Blocks.Sources.RealExpression tauExpr3(y=tauSat[3]);
  Modelica.Blocks.Sources.RealExpression tauExpr4(y=tauSat[4]);

  // ---------------------- Instrumentation and traces ----------------------
  Real q_meas[4] "joint encoder positions (rad)";
  Real w_meas[4] "joint encoder velocities (rad/s)";
  Real payloadForce[3] "applied payload disturbance force (N)";
  Real wristWrench[6] "six-axis wrist wrench sensor trace [Fx,Fy,Fz,Tx,Ty,Tz]";
  Real measuredWristForceNorm "norm of measured wrist force (N)";
  Real primaryTrackingError "maximum joint tracking error (rad)";
  Real stateTrace[8] "synchronized state trace [q1..q4,w1..w4]";
  Real commandTrace[4] "synchronized command trace [tau1..tau4]";
  Real sensorTrace[6] "synchronized sensor trace [wristWrench]";
  Boolean payloadRetained "payload retention flag";

  // Discrete controller state at 125 Hz
  discrete Real q_ref[4](each start=0.0);
  discrete Real dq_ref[4](each start=0.0);
  discrete Real qdd_ref[4](each start=0.0);
  discrete Real e[4](each start=0.0);
  discrete Real de[4](each start=0.0);
  discrete Real Gcomp[4](each start=0.0);
  discrete Real wristCorr[4](each start=0.0);
  discrete Real tauDes[4](each start=0.0);
  discrete Real tauSat[4](each start=0.0);
  discrete Real FcorrZ(start=0.0);
  discrete Real wristForceNorm(start=0.0);

  // Payload injection
  Boolean payloadActive;

protected
  discrete Real trajX;
  discrete Real trajS;
  discrete Real trajSd;
  discrete Real trajSdd;
  discrete Real q2m;
  discrete Real q3m;
  discrete Real q23m;
  discrete Real xEnd2m;
  discrete Real xEnd3m;
  discrete Real G2m;
  discrete Real G3m;
  discrete Real mAct;
  discrete Real FzExpected;
  discrete Real FzErr;
  discrete Real FcorrDes;
  Boolean activePayload;

equation
  // Encoder feedback
  q_meas[1] = j1.phi;
  q_meas[2] = j2.phi;
  q_meas[3] = j3.phi;
  q_meas[4] = j4.phi;
  w_meas[1] = j1.w;
  w_meas[2] = j2.w;
  w_meas[3] = j3.w;
  w_meas[4] = j4.w;

  // Payload disturbance injection
  payloadActive = time >= tMiddleStart and time <= tMiddleEnd;
  payloadForce[1] = 0.0;
  payloadForce[2] = 0.0;
  payloadForce[3] = if payloadActive then -m_payload*g else 0.0;

  // Ideal six-axis wrist wrench sensor trace
  wristWrench[1] = payloadForce[1];
  wristWrench[2] = payloadForce[2];
  wristWrench[3] = payloadForce[3];
  wristWrench[4] = 0.0;
  wristWrench[5] = 0.0;
  wristWrench[6] = 0.0;

  measuredWristForceNorm = sqrt(max(0.0, wristWrench[1]^2 + wristWrench[2]^2 + wristWrench[3]^2));

  // Synchronized traces
  stateTrace[1] = q_meas[1];
  stateTrace[2] = q_meas[2];
  stateTrace[3] = q_meas[3];
  stateTrace[4] = q_meas[4];
  stateTrace[5] = w_meas[1];
  stateTrace[6] = w_meas[2];
  stateTrace[7] = w_meas[3];
  stateTrace[8] = w_meas[4];
  commandTrace[1] = tauSat[1];
  commandTrace[2] = tauSat[2];
  commandTrace[3] = tauSat[3];
  commandTrace[4] = tauSat[4];
  sensorTrace[1] = wristWrench[1];
  sensorTrace[2] = wristWrench[2];
  sensorTrace[3] = wristWrench[3];
  sensorTrace[4] = wristWrench[4];
  sensorTrace[5] = wristWrench[5];
  sensorTrace[6] = wristWrench[6];

  // Payload is rigidly retained at the wrist in this model (no release DOF).
  payloadRetained = true;

  // Primary tracking error in rad-or-m equivalent (here rad)
  primaryTrackingError = max(abs(q_meas[1] - q_ref[1]),
                          max(abs(q_meas[2] - q_ref[2]),
                          max(abs(q_meas[3] - q_ref[3]),
                              abs(q_meas[4] - q_ref[4]))));

  // Requirement assertions
  assert(noEvent(abs(q_meas[1]) <= qBound[1]), "joint 1 travel bound violated");
  assert(noEvent(abs(q_meas[2]) <= qBound[2]), "joint 2 travel bound violated");
  assert(noEvent(abs(q_meas[3]) <= qBound[3]), "joint 3 travel bound violated");
  assert(noEvent(abs(q_meas[4]) <= qBound[4]), "joint 4 travel bound violated");
  assert(noEvent(abs(tauSat[1]) <= tauMax + 1e-6), "effort bound 1 violated");
  assert(noEvent(abs(tauSat[2]) <= tauMax + 1e-6), "effort bound 2 violated");
  assert(noEvent(abs(tauSat[3]) <= tauMax + 1e-6), "effort bound 3 violated");
  assert(noEvent(abs(tauSat[4]) <= tauMax + 1e-6), "effort bound 4 violated");
  assert(noEvent(wristForceNorm <= wristForceMax + 1e-6), "bounded wrist-force correction exceeded 60 N");
  assert(noEvent(payloadRetained), "payload retention lost");
  assert(noEvent(time < trajEnd or primaryTrackingError <= primaryErrorTol),
         "primary tracking error exceeded 0.047 after 7.8 s");

  // ---------------------- 125 Hz computed-torque controller ----------------------
  when sample(0, Ts) then
    activePayload := payloadActive;
    mAct := if activePayload then m_payload else 0.0;

    // Quintic smooth-step trajectory from q0 to qT over [0, trajEnd]
    trajX := if time <= 0.0 or time >= trajEnd then 0.0 else time/trajEnd;
    trajS := if time <= 0.0 then 0.0 elseif time >= trajEnd then 1.0
            else 10.0*trajX^3 - 15.0*trajX^4 + 6.0*trajX^5;
    trajSd := if time <= 0.0 or time >= trajEnd then 0.0
             else 30.0*trajX^2 - 60.0*trajX^3 + 30.0*trajX^4;
    trajSdd := if time <= 0.0 or time >= trajEnd then 0.0
              else 60.0*trajX - 180.0*trajX^2 + 120.0*trajX^3;

    q2m := q_meas[2];
    q3m := q_meas[3];
    q23m := q2m + q3m;

    // Gravity compensation for the planar Z,Y,Y,X chain with q1=0 and q4 axis along link 4.
    // Joint 1 has zero gravity torque about z; joint 4 has zero gravity torque when CM is on its x axis.
    G2m := g*(m2*(0.5*L2)*cos(q2m)
            + m3*(L2*cos(q2m) + 0.5*L3*cos(q23m))
            + m4*(L2*cos(q2m) + L3*cos(q23m) + 0.5*L4*cos(q23m))
            + mAct*(L2*cos(q2m) + L3*cos(q23m) + L4*cos(q23m)));
    G3m := g*(m3*(0.5*L3)*cos(q23m)
            + m4*(L3*cos(q23m) + 0.5*L4*cos(q23m))
            + mAct*(L3*cos(q23m) + L4*cos(q23m)));

    // Bounded wrist-force correction based on residual wrench after expected payload
    FzExpected := if activePayload then -m_payload*g else 0.0;
    FzErr := wristWrench[3] - FzExpected;
    FcorrDes := -Kwrist*FzErr;
    FcorrZ := if FcorrDes > wristForceMax then wristForceMax
              elseif FcorrDes < -wristForceMax then -wristForceMax
              else FcorrDes;
    wristForceNorm := abs(FcorrZ);

    xEnd2m := L2*cos(q2m) + L3*cos(q23m) + L4*cos(q23m);
    xEnd3m := L3*cos(q23m) + L4*cos(q23m);

    for i in 1:4 loop
      q_ref[i] := q0[i] + (qT[i] - q0[i])*trajS;
      dq_ref[i] := (qT[i] - q0[i])*trajSd;
      qdd_ref[i] := (qT[i] - q0[i])*trajSdd;
      e[i] := q_ref[i] - q_meas[i];
      de[i] := dq_ref[i] - w_meas[i];
      Gcomp[i] := 0.0;
      wristCorr[i] := 0.0;
    end for;

    Gcomp[2] := -G2m;
    Gcomp[3] := -G3m;
    wristCorr[2] := -xEnd2m*FcorrZ;
    wristCorr[3] := -xEnd3m*FcorrZ;

    for i in 1:4 loop
      tauDes[i] := Mdiag[i]*(qdd_ref[i] + Kp[i]*e[i] + Kd[i]*de[i]) + Gcomp[i] + wristCorr[i];
      tauSat[i] := if tauDes[i] > tauMax then tauMax
                   elseif tauDes[i] < -tauMax then -tauMax
                   else tauDes[i];
    end for;
  end when;

  // ---------------------- Connections ----------------------
  connect(world.frame_b, base.frame_a);
  connect(base.frame_b, j1.frame_a);
  connect(j1.frame_b, link1.frame_a);
  connect(link1.frame_b, j2.frame_a);
  connect(j2.frame_b, link2.frame_a);
  connect(link2.frame_b, j3.frame_a);
  connect(j3.frame_b, link3.frame_a);
  connect(link3.frame_b, j4.frame_a);
  connect(j4.frame_b, link4.frame_a);
  connect(link4.frame_b, payloadDist.frame_b);

  connect(payloadFx.y, payloadDist.force[1]);
  connect(payloadFy.y, payloadDist.force[2]);
  connect(payloadFz.y, payloadDist.force[3]);

  connect(tauExpr1.y, t1.tau);
  connect(tauExpr2.y, t2.tau);
  connect(tauExpr3.y, t3.tau);
  connect(tauExpr4.y, t4.tau);

  connect(t1.flange, j1.axis);
  connect(t1.support, j1.support);
  connect(t2.flange, j2.axis);
  connect(t2.support, j2.support);
  connect(t3.flange, j3.axis);
  connect(t3.support, j3.support);
  connect(t4.flange, j4.axis);
  connect(t4.support, j4.support);

  annotation (
    Documentation(info="AssemblyArmCarryC: four-axis Z,Y,Y,X articulated manipulator with saturated computed-torque control and bounded wrist-force correction. Payload disturbance is injected during the middle third [4,8] s. Floor/table collision is enabled as a logical flag only; MSL MultiBody does not provide a contact solver and no contact forces are generated."),
    experiment(StopTime=12, Tolerance=1e-6, Interval=0.008));
end AssemblyArmCarryC;