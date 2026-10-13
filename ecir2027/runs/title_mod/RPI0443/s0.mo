model ContactArmInsertE
  "Contact-rich peg-in-hole insertion with a fixed 6R Z-Y-Y-X-Y-X arm, saturated joint efforts, Cartesian impedance control, 250 Hz traces, and fail-closed acceptance checks."

  record RigidTool
    parameter Real length(min=0)=0.08 "tool length along local -z [m]";
    parameter Real radius(min=0)=0.005 "peg radius [m]";
    parameter Real mass(min=0)=0.10 "tool mass [kg]";
  end RigidTool;

  // Fixed arm structure: Z-Y-Y-X-Y-X revolute axes.
  parameter Integer axes[6] = {3,2,2,1,2,1} "axis codes: 1=X, 2=Y, 3=Z";
  parameter Real base[3] = {0.30,0.0,0.60} "fixed base origin [m]";
  parameter Real linkVec[6,3] =
    {{-0.15,0.0,-0.10},
     {0.0,0.0,-0.10},
     {-0.15,0.0,-0.10},
     {0.0,0.0,-0.10},
     {0.0,0.0,-0.05},
     {0.0,0.0,-0.05}} "capsule link center vectors [m]";
  parameter Real linkRadius[6] = {0.03,0.025,0.02,0.015,0.01,0.008} "capsule radii [m]";
  parameter Real linkMass[6] = {1.0,0.8,0.6,0.4,0.2,0.1} "capsule link masses [kg]";
  parameter Real jointInertia[6] = {0.05,0.04,0.03,0.02,0.01,0.005} "joint inertias [kg.m2]";
  parameter Real jointDamping[6] = {0.20,0.20,0.15,0.10,0.05,0.05} "joint viscous damping [N.m.s/rad]";

  replaceable parameter RigidTool tool = RigidTool(length=0.08, radius=0.005, mass=0.10)
    "replaceable rigid tool; nominal values only, exact tool not specified";

  parameter Real pegRadius = tool.radius "peg radius [m]";
  parameter Real clearance = 0.001 "1 mm radial clearance [m]";
  parameter Real holeRadius = pegRadius + clearance "hole radius [m]";
  parameter Real zEntry = 0.02 "hole entry z [m]";
  parameter Real zBottom = -0.08 "hole bottom z [m]";

  parameter Real tauMax = 132.0 "maximum saturated joint effort [N.m]";
  parameter Real mu = 0.35 "contact friction coefficient";
  parameter Real kLat = 3.0e4 "lateral rigid-collision stiffness [N/m]";
  parameter Real dLat = 20.0 "lateral collision damping [N.s/m]";
  parameter Real kAx = 1.0e5 "axial bottom-collision stiffness [N/m]";
  parameter Real dAx = 50.0 "axial bottom-collision damping [N.s/m]";
  parameter Real vEps = 1.0e-3 "friction sign smoothing velocity [m/s]";

  parameter Real Ts = 0.004 "controller and trace sample time [s], 250 Hz";
  parameter Real tEnd = 16.0 "run time [s]";
  parameter Real T1 = 16.0/3.0 "middle-third disturbance start [s]";
  parameter Real T2 = 32.0/3.0 "middle-third disturbance end [s]";
  parameter Real Fdist = 12.0 "controlled lateral fixture load [N]";

  parameter Real Kxy = 10000.0 "lateral impedance stiffness [N/m]";
  parameter Real Dxy = 150.0 "lateral impedance damping [N.s/m]";
  parameter Real Kz = 6000.0 "axial impedance stiffness [N/m]";
  parameter Real Dz = 120.0 "axial impedance damping [N.s/m]";
  parameter Real Ko = 150.0 "orientation impedance stiffness [N.m/rad]";
  parameter Real Do = 15.0 "orientation impedance damping [N.m.s/rad]";
  parameter Real vInsertMax = 0.012 "bounded insertion speed [m/s]";

  parameter Real F_lat_limit = 80.0 "lateral force limit [N], nominal";
  parameter Real F_ax_limit = 40.0 "axial force limit [N], nominal";
  parameter Real tiltLimit = 0.05 "peg tilt limit [rad], nominal";

  Modelica.Blocks.Sources.SampleTrigger sampleClock(period=Ts, startTime=0.0);

  Real q[6](start={0,0,0,0,0,0}) "joint angles [rad]";
  Real qd[6](start={0,0,0,0,0,0}) "joint velocities [rad/s]";
  Real qdd[6] "joint accelerations [rad/s2]";

  discrete Real tauRaw[6](start={0,0,0,0,0,0}) "raw controller effort [N.m]";
  discrete Real tauSat[6](start={0,0,0,0,0,0}) "saturated actuator command [N.m]";
  discrete Real Fcmd[3](start={0,0,0}) "Cartesian force command [N]";
  discrete Real Tcmd[3](start={0,0,0}) "Cartesian torque command [N.m]";

  discrete Real logTime(start=0.0) "synchronized trace timestamp [s]";
  discrete Real logQ[6](start={0,0,0,0,0,0}) "synchronized joint state trace [rad]";
  discrete Real logQd[6](start={0,0,0,0,0,0}) "synchronized joint velocity trace [rad/s]";
  discrete Real logTau[6](start={0,0,0,0,0,0}) "synchronized command trace [N.m]";
  discrete Real logSensor[6](start={0,0,0,0,0,0}) "synchronized sensor trace, force/torque in wrist frame";

  Real p_tip[3] "peg tip position [m]";
  Real pWrist[3] "wrist position [m]";
  Real R[3,3] "wrist/tool rotation matrix";
  Real Jp[3,6] "tip position Jacobian";
  Real Jo[3,6] "tip angular Jacobian";
  Real v_tip[3] "tip linear velocity [m/s]";
  Real omega[3] "tip angular velocity [rad/s]";

  Real F_contact[3] "contact force at tip [N]";
  Real T_contact[3] "contact torque at tip [N.m]";
  Real FdistValue "current lateral disturbance force [N]";
  Real F_env[3] "external environment force at tip [N]";
  Real tauExt[6] "joint torques from external wrench [N.m]";

  Real deltaP[3] "wrist-to-tip vector [m]";
  Real sensorForceWorld[3] "six-axis sensor force in world frame [N]";
  Real sensorTorqueWorld[3] "six-axis sensor torque in world frame [N.m]";
  Real sensorWrench[6] "six-axis wrist sensor wrench in wrist frame";

  Real dDes "desired insertion depth [m]";
  Real dDesDer "desired insertion speed [m/s]";

  Real insertionDepth "achieved insertion depth [m]";
  Real alignError "radial alignment error [m]";
  Real tilt "peg tilt relative to hole axis [rad]";
  Real F_lat_sensor "lateral force magnitude [N]";
  Real F_ax_sensor "axial force magnitude [N]";

  output Real insertionDepthOut;
  output Real alignErrorOut;
  output Real tiltOut;
  output Real F_latOut;
  output Real F_axOut;
  output Real qOut[6];
  output Real qdOut[6];
  output Real tauOut[6];
  output Real sensorOut[6];
  output Real logTimeOut;
  output Real logQOut[6];
  output Real logQdOut[6];
  output Real logTauOut[6];
  output Real logSensorOut[6];

protected
  function rotMat "Rotation matrix for axis 1=X, 2=Y, 3=Z"
    input Integer axis;
    input Real q;
    output Real R[3,3];
  algorithm
    if axis == 1 then
      R := {{1,0,0},{0,Modelica.Math.cos(q),-Modelica.Math.sin(q)},{0,Modelica.Math.sin(q),Modelica.Math.cos(q)}};
    elseif axis == 2 then
      R := {{Modelica.Math.cos(q),0,Modelica.Math.sin(q)},{0,1,0},{-Modelica.Math.sin(q),0,Modelica.Math.cos(q)}};
    else
      R := {{Modelica.Math.cos(q),-Modelica.Math.sin(q),0},{Modelica.Math.sin(q),Modelica.Math.cos(q),0},{0,0,1}};
    end if;
  end rotMat;

  function unitAxis "Unit vector for axis code"
    input Integer axis;
    output Real v[3];
  algorithm
    if axis == 1 then
      v := {1,0,0};
    elseif axis == 2 then
      v := {0,1,0};
    else
      v := {0,0,1};
    end if;
  end unitAxis;

  function crossProduct "3D cross product a x b"
    input Real a[3];
    input Real b[3];
    output Real c[3];
  algorithm
    c := {a[2]*b[3]-a[3]*b[2], a[3]*b[1]-a[1]*b[3], a[1]*b[2]-a[2]*b[1]};
  end crossProduct;

  function kinematics "6R forward kinematics, tip pose, and Jacobians"
    input Real q[6];
    input Integer axes[6];
    input Real linkVec[6,3];
    input Real base[3];
    input Real toolLength;
    output Real p_tip[3];
    output Real pWrist[3];
    output Real Rw[3,3];
    output Real Jp[3,6];
    output Real Jo[3,6];
  protected
    Real Rmat[3,3], Rprev[3,3], p[3], pprev[3], a[3], z[3], pTipVec[3], rv[3], cv[3];
    Real zAxes[3,6], pJoints[3,6];
  algorithm
    Rmat := {{1,0,0},{0,1,0},{0,0,1}};
    p := base;
    for i in 1:6 loop
      Rprev := Rmat;
      pprev := p;
      Rmat := Rprev * rotMat(axes[i], q[i]);
      a := {linkVec[i,1],linkVec[i,2],linkVec[i,3]};
      p := pprev + Rmat*a;
      z := Rprev * unitAxis(axes[i]);
      for k in 1:3 loop
        zAxes[k,i] := z[k];
        pJoints[k,i] := pprev[k];
      end for;
    end for;
    pWrist := p;
    pTipVec := p + Rmat*{0,0,-toolLength};
    p_tip := pTipVec;
    Rw := Rmat;
    for i in 1:6 loop
      z := {zAxes[1,i],zAxes[2,i],zAxes[3,i]};
      pprev := {pJoints[1,i],pJoints[2,i],pJoints[3,i]};
      rv := {pTipVec[1]-pprev[1],pTipVec[2]-pprev[2],pTipVec[3]-pprev[3]};
      cv := crossProduct(z,rv);
      for k in 1:3 loop
        Jp[k,i] := cv[k];
        Jo[k,i] := z[k];
      end for;
    end for;
  end kinematics;

  function mulMatVec "Multiply 3x6 matrix by 6-vector"
    input Real A[3,6];
    input Real x[6];
    output Real y[3];
  algorithm
    for i in 1:3 loop
      y[i] := A[i,1]*x[1]+A[i,2]*x[2]+A[i,3]*x[3]+A[i,4]*x[4]+A[i,5]*x[5]+A[i,6]*x[6];
    end for;
  end mulMatVec;

  function wrenchToJointTorque "Joint torques = J^T * [F; T]"
    input Real Jp[3,6];
    input Real Jo[3,6];
    input Real F[3];
    input Real T[3];
    output Real tau[6];
  protected
    Real J[6,6];
  algorithm
    for r in 1:3 loop
      for c in 1:6 loop
        J[r,c] := Jp[r,c];
        J[r+3,c] := Jo[r,c];
      end for;
    end for;
    for c in 1:6 loop
      tau[c] := 0.0;
      for r in 1:3 loop
        tau[c] := tau[c] + J[r,c]*F[r] + J[r+3,c]*T[r];
      end for;
    end for;
  end wrenchToJointTorque;

  function contactWrench "Regularized rigid collision and friction wrench at peg tip"
    input Real p[3];
    input Real v[3];
    input Real R[3,3];
    input Real clearance;
    input Real zEntry;
    input Real zBottom;
    input Real kLat;
    input Real dLat;
    input Real kAx;
    input Real dAx;
    input Real mu;
    input Real vEps;
    output Real F[3];
    output Real T[3];
  protected
    Real x,y,z,r,nrm,nx,ny,N,vn,vz;
  algorithm
    F := {0,0,0};
    T := {0,0,0};
    x := p[1];
    y := p[2];
    z := p[3];
    r := sqrt(x*x + y*y);
    if r > clearance then
      nrm := if r > 1.0e-9 then r else 1.0e-9;
      nx := x/nrm;
      ny := y/nrm;
      vn := v[1]*nx + v[2]*ny;
      N := kLat*(r - clearance);
      if vn > 0 then
        N := N + dLat*vn;
      end if;
      F[1] := -N*nx;
      F[2] := -N*ny;
      vz := v[3];
      F[3] := F[3] - mu*N*Modelica.Math.tanh(vz/vEps);
    end if;
    if z < zBottom then
      F[3] := F[3] + kAx*(zBottom - z);
      if v[3] < 0 then
        F[3] := F[3] + dAx*(-v[3]);
      end if;
    end if;
  end contactWrench;

  function cartesianImpedance "Bounded Cartesian impedance controller returning joint efforts"
    input Real p[3];
    input Real v[3];
    input Real R[3,3];
    input Real omega[3];
    input Real Jp[3,6];
    input Real Jo[3,6];
    input Real dDes;
    input Real dDesDer;
    input Real zEntry;
    input Real Kxy;
    input Real Dxy;
    input Real Kz;
    input Real Dz;
    input Real Ko;
    input Real Do;
    output Real tau[6];
    output Real F[3];
    output Real T[3];
  protected
    Real pDes[3], eO[3];
  algorithm
    pDes := {0.0,0.0,zEntry - dDes};
    F[1] := Kxy*(pDes[1] - p[1]) - Dxy*v[1];
    F[2] := Kxy*(pDes[2] - p[2]) - Dxy*v[2];
    F[3] := Kz*(pDes[3] - p[3]) - Dz*(v[3] + dDesDer);
    eO := {0.5*(R[2,3]-R[3,2]),0.5*(R[3,1]-R[1,3]),0.5*(R[1,2]-R[2,1])};
    T[1] := -Ko*eO[1] - Do*omega[1];
    T[2] := -Ko*eO[2] - Do*omega[2];
    T[3] := -Ko*eO[3] - Do*omega[3];
    tau := wrenchToJointTorque(Jp,Jo,F,T);
  end cartesianImpedance;

equation
  (p_tip,pWrist,R,Jp,Jo) = kinematics(q,axes,linkVec,base,tool.length);
  v_tip = mulMatVec(Jp,qd);
  omega = mulMatVec(Jo,qd);

  (F_contact,T_contact) = contactWrench(p_tip,v_tip,R,clearance,zEntry,zBottom,kLat,dLat,kAx,dAx,mu,vEps);

  FdistValue = if time >= T1 and time <= T2 then Fdist else 0.0;
  F_env[1] = F_contact[1] + FdistValue;
  F_env[2] = F_contact[2];
  F_env[3] = F_contact[3];

  tauExt = wrenchToJointTorque(Jp,Jo,F_env,T_contact);

  for i in 1:6 loop
    der(q[i]) = qd[i];
    der(qd[i]) = qdd[i];
    qdd[i] = (tauSat[i] + tauExt[i] - jointDamping[i]*qd[i]) / jointInertia[i];
  end for;

  for i in 1:3 loop
    deltaP[i] = p_tip[i] - pWrist[i];
  end for;

  sensorForceWorld = F_env;
  sensorTorqueWorld = T_contact + crossProduct(deltaP,F_env);

  for k in 1:3 loop
    sensorWrench[k] = R[1,k]*sensorForceWorld[1] + R[2,k]*sensorForceWorld[2] + R[3,k]*sensorForceWorld[3];
    sensorWrench[k+3] = R[1,k]*sensorTorqueWorld[1] + R[2,k]*sensorTorqueWorld[2] + R[3,k]*sensorTorqueWorld[3];
  end for;

  dDes = if time < 8.0 then 0.06*(1.0 - Modelica.Math.cos(Modelica.Constants.pi*time/8.0))/2.0 else 0.06;
  dDesDer = if time < 8.0 then 0.06*Modelica.Constants.pi/16.0*Modelica.Math.sin(Modelica.Constants.pi*time/8.0) else 0.0;

  insertionDepth = zEntry - p_tip[3];
  alignError = sqrt(p_tip[1]*p_tip[1] + p_tip[2]*p_tip[2]);
  tilt = Modelica.Math.acos(max(-1.0,min(1.0,R[3,3])));
  F_lat_sensor = sqrt(sensorForceWorld[1]*sensorForceWorld[1] + sensorForceWorld[2]*sensorForceWorld[2]);
  F_ax_sensor = abs(sensorForceWorld[3]);

  insertionDepthOut = insertionDepth;
  alignErrorOut = alignError;
  tiltOut = tilt;
  F_latOut = F_lat_sensor;
  F_axOut = F_ax_sensor;
  qOut = q;
  qdOut = qd;
  tauOut = tauSat;
  sensorOut = sensorWrench;
  logTimeOut = logTime;
  logQOut = logQ;
  logQdOut = logQd;
  logTauOut = logTau;
  logSensorOut = logSensor;

  when sampleClock.y then
    (tauRaw,Fcmd,Tcmd) = cartesianImpedance(p_tip,v_tip,R,omega,Jp,Jo,dDes,dDesDer,zEntry,Kxy,Dxy,Kz,Dz,Ko,Do);
    for i in 1:6 loop
      tauSat[i] = if tauRaw[i] > tauMax then tauMax elseif tauRaw[i] < -tauMax then -tauMax else tauRaw[i];
    end for;
    logTime = time;
    for i in 1:6 loop
      logQ[i] = q[i];
      logQd[i] = qd[i];
      logTau[i] = tauSat[i];
      logSensor[i] = sensorWrench[i];
    end for;
  end when;

  // Acceptance checks, fail-closed.
  assert(noEvent(abs(dDesDer) <= vInsertMax + 1.0e-9), "insertion speed bound violated", AssertionLevel.error);
  assert(noEvent(time < 10.4 or alignError <= 0.002 + 1.0e-9), "primary tracking error after 10.4 s", AssertionLevel.error);
  assert(noEvent(tilt <= tiltLimit + 1.0e-9), "peg tilt limit violated", AssertionLevel.error);
  assert(noEvent(F_lat_sensor <= F_lat_limit + 1.0e-9), "lateral force limit violated", AssertionLevel.error);
  assert(noEvent(F_ax_sensor <= F_ax_limit + 1.0e-9), "axial force limit violated", AssertionLevel.error);

  for i in 1:6 loop
    assert(noEvent(abs(tauSat[i]) <= tauMax + 1.0e-9), "actuator bound violated", AssertionLevel.error);
    assert(noEvent(abs(q[i]) <= 1.0e30), "non-finite joint state", AssertionLevel.error);
    assert(noEvent(abs(qd[i]) <= 1.0e30), "non-finite joint velocity", AssertionLevel.error);
    assert(noEvent(abs(qdd[i]) <= 1.0e30), "non-finite joint acceleration", AssertionLevel.error);
    assert(noEvent(abs(tauSat[i]) <= 1.0e30), "non-finite actuator command", AssertionLevel.error);
    assert(noEvent(abs(tauRaw[i]) <= 1.0e30), "non-finite raw control command", AssertionLevel.error);
    assert(noEvent(abs(tauExt[i]) <= 1.0e30), "non-finite external joint torque", AssertionLevel.error);
    assert(noEvent(abs(sensorWrench[i]) <= 1.0e30), "non-finite sensor value", AssertionLevel.error);
  end for;

  for i in 1:3 loop
    assert(noEvent(abs(p_tip[i]) <= 1.0e30), "non-finite tip position", AssertionLevel.error);
    assert(noEvent(abs(v_tip[i]) <= 1.0e30), "non-finite tip velocity", AssertionLevel.error);
    assert(noEvent(abs(omega[i]) <= 1.0e30), "non-finite angular velocity", AssertionLevel.error);
    assert(noEvent(abs(F_contact[i]) <= 1.0e30), "non-finite contact force", AssertionLevel.error);
    assert(noEvent(abs(F_env[i]) <= 1.0e30), "non-finite environment force", AssertionLevel.error);
    assert(noEvent(abs(Fcmd[i]) <= 1.0e30), "non-finite control force", AssertionLevel.error);
    assert(noEvent(abs(Tcmd[i]) <= 1.0e30), "non-finite control torque", AssertionLevel.error);
  end for;

  when terminal() then
    assert(insertionDepth >= 0.06 - 1.0e-6, "insertion depth below 0.06 m", AssertionLevel.error);
  end when;

  annotation (experiment(StopTime=16, Tolerance=1e-6));
end ContactArmInsertE;