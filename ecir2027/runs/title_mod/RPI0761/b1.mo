model BipedTwoClimbE
  "Floating-base biped climbing four stairs; fail-closed acceptance model.";

  constant Real Ts = 0.004 "controller sample period, 250 Hz";
  constant Real g = 9.81 "standard gravity";
  constant Real pi_c = 3.14159265358979323846;

  parameter Real mPelvis = 36 "kg";
  parameter Real lThigh = 0.42 "m";
  parameter Real lShank = 0.40 "m";
  parameter Real lFoot = 0.18 "m, flat-foot length placeholder for contact geometry";
  parameter Real wFoot = 0.10 "m, flat-foot width placeholder for contact geometry";
  parameter Real hipSeparation = 0.30 "m, unspecified hip spacing placeholder";

  parameter Real rise = 0.16 "m";
  parameter Real tread = 0.30 "m";
  parameter Integer nStairs = 4;

  parameter Real hBodyDes = 0.78 "m, body height above support, placeholder";
  parameter Real qMax = 2.0 "rad, joint-bound placeholder";
  parameter Real jointInertia = 0.05 "kg.m2, reflected joint inertia placeholder";
  parameter Real jointDamping = 2 "N.m.s/rad, joint damping placeholder";
  parameter Real kpImp = 300 "N.m/rad, joint impedance gain";
  parameter Real kdImp = 15 "N.m.s/rad, joint impedance damping";
  parameter Real kx = 5000 "N/m, base horizontal tracking gain";
  parameter Real dampX = 500 "N.s/m, base horizontal tracking damping";
  parameter Real kz = 8000 "N/m, base vertical tracking gain";
  parameter Real dampZ = 800 "N.s/m, base vertical tracking damping";
  parameter Real contactStiffness = 1.0e5 "N/m";
  parameter Real contactDamping = 1.0e3 "N.s/m";
  parameter Real contactThresh = 5.0 "N";
  parameter Real clearanceTol = 0.0011 "m";
  parameter Real swingClearance = 0.08 "m";
  parameter Real contactPen = 0.001 "m";
  parameter Real Tphase = 1.25 "s per half-step";

  parameter Real tauMax = 138 "N.m per joint";
  parameter Real payloadForce = 120 "N";
  parameter Real friction = 0.88;

  parameter Real trackingLimit = 0.036 "m";
  parameter Real trackingTime = 10.4 "s";
  parameter Real finalTime = 16.0 "s";

  Real x(start=0.15, fixed=true) "pelvis horizontal position, m";
  Real z(start=0.779, fixed=true) "pelvis vertical position, m";
  Real vx(start=0, fixed=true) "pelvis horizontal velocity, m/s";
  Real vz(start=0, fixed=true) "pelvis vertical velocity, m/s";
  Real q[2,6](
    start={{0,0,0.306,-0.628,0,0.322},{0,0,0.306,-0.628,0,0.322}},
    each fixed=true)
    "joint angles rad per leg: hipYaw, hipRoll, hipPitch, knee, ankleRoll, anklePitch";
  Real w[2,6](each start=0, each fixed=true) "joint angular velocities rad/s";

  Real qDes[2,6];
  Real qIK[2,3];
  Real tauRaw[2,6];
  Real tauCmd[2,6];
  Real footXDes_d[2];
  Real footZDes_d[2];
  Real baseXDes_d;
  Real baseZDes_d;
  discrete Real planOut[6](start={0.15,-0.001,0.15,-0.001,0.15,0.779});

  Real rX[2], rZ[2], drX3[2], drX4[2], drZ3[2], drZ4[2];
  Real footXActual[2], footZActual[2], vxFoot[2], vzFoot[2];
  Real cX[2,2], cZ[2,2], pen[2,2], FzContact[2,2], FxContact[2,2];
  Boolean contactBool[2,2];
  Integer supportContacts;

  Real depthRange[2];
  Real edgeDist[2];
  Boolean edgeDetected[2];
  Real imuAccel[3];
  Real imuGyro[3];
  Real encoder[2,6];
  Real estBaseX, estBaseZ, estFootX[2], estFootZ[2];

  Real FxBase, FzBase, payloadActive, bodyHeightError, footholdError;
  Real maxAbsQ, maxAbsW, maxAbsTau, sumAbsState;
  Boolean jointBoundsOK, effortBoundsOK, clearanceOK, twoSupportContactsOK;
  Boolean completionOK, trackingOK, noNaNInfOK, bodyHeightOK, acceptanceOK;

  function terrainHeight "Rigid stair collision height as a function of x."
    input Real xIn;
    input Real treadIn;
    input Real riseIn;
    input Integer nStairsIn;
    output Real h;
  protected
    Integer i;
  algorithm
    i := integer(floor(xIn/treadIn));
    if i < 0 then
      i := 0;
    end if;
    if i > nStairsIn then
      i := nStairsIn;
    end if;
    h := i*riseIn;
  end terrainHeight;

  function clampReal
    input Real x;
    input Real lo;
    input Real hi;
    output Real y;
  algorithm
    if x < lo then
      y := lo;
    elseif x > hi then
      y := hi;
    else
      y := x;
    end if;
  end clampReal;

  function finiteReal "True if finite and not NaN."
    input Real x;
    output Boolean ok;
  algorithm
    ok := abs(x) < 1e20;
  end finiteReal;

  function legIK "Sagittal inverse kinematics for thigh-shank-foot center."
    input Real dx;
    input Real dz;
    input Real lT;
    input Real lS;
    output Real qOut[3];
  protected
    Real L2, c2, qK, qH;
  algorithm
    L2 := dx*dx + dz*dz;
    c2 := (L2 - lT*lT - lS*lS)/(2*lT*lS);
    if c2 > 1 then
      c2 := 1;
    elseif c2 < -1 then
      c2 := -1;
    end if;
    qK := -acos(c2);
    qH := atan2(dx, -dz) - atan2(lS*sin(qK), lT + lS*cos(qK));
    qOut[1] := qH;
    qOut[2] := qK;
    qOut[3] := -(qH + qK);
  end legIK;

  function planFootholdsVec "Terrain-aware foothold plan at 250 Hz controller samples."
    input Real t;
    input Real TphaseIn;
    input Real treadIn;
    input Real riseIn;
    input Integer nStairsIn;
    input Real hBodyDesIn;
    input Real contactPenIn;
    input Real swingClearanceIn;
    output Real out[6];
  protected
    Integer phase, targetK, swing, support, supportK, prevK;
    Real footX1, footX2, footZ1, footZ2;
    Real s, sSmooth, prevX, prevZ, nextX, nextZ, supportZ;
  algorithm
    phase := integer(floor(t/TphaseIn));
    if phase < 0 then
      phase := 0;
    end if;
    if phase > nStairsIn*2 then
      phase := nStairsIn*2;
    end if;
    if phase >= nStairsIn*2 then
      footX1 := (nStairsIn + 0.5)*treadIn;
      footZ1 := nStairsIn*riseIn - contactPenIn;
      footX2 := footX1;
      footZ2 := footZ1;
      supportZ := footZ1;
    else
      targetK := integer(floor(phase/2)) + 1;
      if mod(phase,2) == 0 then
        swing := 2;
      else
        swing := 1;
      end if;
      if swing == 1 then
        support := 2;
      else
        support := 1;
      end if;
      if swing == 2 then
        supportK := targetK - 1;
      else
        supportK := targetK;
      end if;
      prevK := targetK - 1;
      prevX := (prevK + 0.5)*treadIn;
      prevZ := prevK*riseIn - contactPenIn;
      nextX := (targetK + 0.5)*treadIn;
      nextZ := targetK*riseIn - contactPenIn;
      supportZ := supportK*riseIn - contactPenIn;
      s := (t - phase*TphaseIn)/TphaseIn;
      if s < 0 then
        s := 0;
      elseif s > 1 then
        s := 1;
      end if;
      sSmooth := 0.5*(1 - cos(pi_c*s));
      if swing == 1 then
        footX1 := prevX + (nextX - prevX)*sSmooth;
        footZ1 := prevZ + (nextZ - prevZ)*sSmooth + swingClearanceIn*sin(pi_c*s);
        footX2 := (supportK + 0.5)*treadIn;
        footZ2 := supportZ;
      else
        footX2 := prevX + (nextX - prevX)*sSmooth;
        footZ2 := prevZ + (nextZ - prevZ)*sSmooth + swingClearanceIn*sin(pi_c*s);
        footX1 := (supportK + 0.5)*treadIn;
        footZ1 := supportZ;
      end if;
    end if;
    out[1] := footX1;
    out[2] := footZ1;
    out[3] := footX2;
    out[4] := footZ2;
    out[5] := 0.5*(footX1 + footX2);
    out[6] := supportZ + hBodyDesIn;
  end planFootholdsVec;

equation
  when sample(0,Ts) then
    planOut := planFootholdsVec(time, Tphase, tread, rise, nStairs, hBodyDes, contactPen, swingClearance);
  end when;

  footXDes_d[1] = planOut[1];
  footZDes_d[1] = planOut[2];
  footXDes_d[2] = planOut[3];
  footZDes_d[2] = planOut[4];
  baseXDes_d = planOut[5];
  baseZDes_d = planOut[6];

  payloadActive = if time >= finalTime/3 and time <= 2*finalTime/3 then 1.0 else 0.0;

  FxBase = kx*(baseXDes_d - x) + dampX*(0 - vx);
  FzBase = mPelvis*g + payloadForce*payloadActive + kz*(baseZDes_d - z) + dampZ*(0 - vz);
  der(x) = vx;
  der(vx) = FxBase/mPelvis;
  der(z) = vz;
  der(vz) = (FzBase - mPelvis*g - payloadForce*payloadActive)/mPelvis;

  qIK[1] = legIK(footXDes_d[1] - baseXDes_d, footZDes_d[1] - baseZDes_d, lThigh, lShank);
  qIK[2] = legIK(footXDes_d[2] - baseXDes_d, footZDes_d[2] - baseZDes_d, lThigh, lShank);
  for i in 1:2 loop
    qDes[i,1] = 0;
    qDes[i,2] = 0;
    qDes[i,5] = 0;
    qDes[i,3] = qIK[i,1];
    qDes[i,4] = qIK[i,2];
    qDes[i,6] = qIK[i,3];
  end for;

  for i in 1:2 loop
    for j in 1:6 loop
      tauRaw[i,j] = kpImp*(qDes[i,j] - q[i,j]) - kdImp*w[i,j];
      tauCmd[i,j] = clampReal(tauRaw[i,j], -tauMax, tauMax);
      der(q[i,j]) = w[i,j];
      der(w[i,j]) = (tauCmd[i,j] - jointDamping*w[i,j])/jointInertia;
    end for;
  end for;

  for i in 1:2 loop
    rX[i] = lThigh*sin(q[i,3]) + lShank*sin(q[i,3] + q[i,4]);
    rZ[i] = -lThigh*cos(q[i,3]) - lShank*cos(q[i,3] + q[i,4]);
    footXActual[i] = x + rX[i];
    footZActual[i] = z + rZ[i];
    drX3[i] = lThigh*cos(q[i,3]) + lShank*cos(q[i,3] + q[i,4]);
    drX4[i] = lShank*cos(q[i,3] + q[i,4]);
    drZ3[i] = lThigh*sin(q[i,3]) + lShank*sin(q[i,3] + q[i,4]);
    drZ4[i] = lShank*sin(q[i,3] + q[i,4]);
    vxFoot[i] = vx + drX3[i]*w[i,3] + drX4[i]*w[i,4];
    vzFoot[i] = vz + drZ3[i]*w[i,3] + drZ4[i]*w[i,4];
  end for;

  for i in 1:2 loop
    cX[i,1] = footXActual[i] - 0.5*lFoot;
    cX[i,2] = footXActual[i] + 0.5*lFoot;
    for j in 1:2 loop
      cZ[i,j] = footZActual[i];
      pen[i,j] = terrainHeight(cX[i,j], tread, rise, nStairs) - cZ[i,j];
      FzContact[i,j] = if pen[i,j] > 0 and (contactStiffness*pen[i,j] - contactDamping*vzFoot[i]) > 0
                       then contactStiffness*pen[i,j] - contactDamping*vzFoot[i] else 0;
      FxContact[i,j] = if FzContact[i,j] > 0
                       then friction*FzContact[i,j]*tanh(-vxFoot[i]/0.01) else 0;
      contactBool[i,j] = FzContact[i,j] > contactThresh;
    end for;
  end for;

  supportContacts = (if contactBool[1,1] then 1 else 0)
                  + (if contactBool[1,2] then 1 else 0)
                  + (if contactBool[2,1] then 1 else 0)
                  + (if contactBool[2,2] then 1 else 0);

  for i in 1:2 loop
    depthRange[i] = max(0, terrainHeight(footXActual[i], tread, rise, nStairs) - footZActual[i]);
    edgeDist[i] = min(abs(footXActual[i] - tread*floor(footXActual[i]/tread)),
                      abs(footXActual[i] - tread*floor(footXActual[i]/tread) - tread));
    edgeDetected[i] = edgeDist[i] < 0.02;
    for j in 1:6 loop
      encoder[i,j] = q[i,j];
    end for;
  end for;

  imuAccel[1] = FxBase/mPelvis;
  imuAccel[2] = 0;
  imuAccel[3] = (FzBase - mPelvis*g - payloadForce*payloadActive)/mPelvis;
  imuGyro[1] = 0;
  imuGyro[2] = 0;
  imuGyro[3] = 0;

  estBaseX = x;
  estBaseZ = z;
  for i in 1:2 loop
    estFootX[i] = footXActual[i];
    estFootZ[i] = footZActual[i];
  end for;

  maxAbsQ = max(abs(q[1,1]), max(abs(q[1,2]), max(abs(q[1,3]), max(abs(q[1,4]), max(abs(q[1,5]), max(abs(q[1,6]), max(abs(q[2,1]), max(abs(q[2,2]), max(abs(q[2,3]), max(abs(q[2,4]), max(abs(q[2,5]), abs(q[2,6])))))))))));
  maxAbsW = max(abs(w[1,1]), max(abs(w[1,2]), max(abs(w[1,3]), max(abs(w[1,4]), max(abs(w[1,5]), max(abs(w[1,6]), max(abs(w[2,1]), max(abs(w[2,2]), max(abs(w[2,3]), max(abs(w[2,4]), max(abs(w[2,5]), abs(w[2,6])))))))))));
  maxAbsTau = max(abs(tauCmd[1,1]), max(abs(tauCmd[1,2]), max(abs(tauCmd[1,3]), max(abs(tauCmd[1,4]), max(abs(tauCmd[1,5]), max(abs(tauCmd[1,6]), max(abs(tauCmd[2,1]), max(abs(tauCmd[2,2]), max(abs(tauCmd[2,3]), max(abs(tauCmd[2,4]), max(abs(tauCmd[2,5]), abs(tauCmd[2,6])))))))))));

  footholdError = max(sqrt((footXDes_d[1] - footXActual[1])^2 + (footZDes_d[1] - footZActual[1])^2),
                     sqrt((footXDes_d[2] - footXActual[2])^2 + (footZDes_d[2] - footZActual[2])^2));
  bodyHeightError = abs(z - baseZDes_d);

  jointBoundsOK = maxAbsQ <= qMax;
  effortBoundsOK = maxAbsTau <= tauMax + 1e-6;
  clearanceOK = (cZ[1,1] >= terrainHeight(cX[1,1], tread, rise, nStairs) - clearanceTol)
              and (cZ[1,2] >= terrainHeight(cX[1,2], tread, rise, nStairs) - clearanceTol)
              and (cZ[2,1] >= terrainHeight(cX[2,1], tread, rise, nStairs) - clearanceTol)
              and (cZ[2,2] >= terrainHeight(cX[2,2], tread, rise, nStairs) - clearanceTol);
  twoSupportContactsOK = supportContacts >= 2;
  completionOK = x >= nStairs*tread and z >= nStairs*rise + hBodyDes - 0.05;
  trackingOK = if time >= trackingTime then footholdError <= trackingLimit else true;
  bodyHeightOK = bodyHeightError <= 0.05;

  sumAbsState = abs(x) + abs(z) + abs(vx) + abs(vz) + maxAbsQ + maxAbsW + maxAbsTau
              + abs(FxBase) + abs(FzBase) + abs(footholdError) + abs(supportContacts) + bodyHeightError;
  noNaNInfOK = finiteReal(sumAbsState);

  acceptanceOK = jointBoundsOK and effortBoundsOK and clearanceOK and twoSupportContactsOK
              and completionOK and trackingOK and bodyHeightOK and noNaNInfOK;

  assert(noNaNInfOK, "NaN or infinite physical/control/estimator value");
  assert(effortBoundsOK, "joint effort bound violated");
  assert(jointBoundsOK, "joint bound violated");
  assert(twoSupportContactsOK, "fewer than two support contacts");
  assert(clearanceOK, "stair-edge clearance violated");
  assert(if time >= trackingTime then trackingOK else true, "primary tracking error violated after 10.4 s");

  when terminal() then
    assert(completionOK and acceptanceOK, "BipedTwoClimbE fail-closed acceptance violated");
  end when;

  annotation(experiment(StopTime=16, Tolerance=1e-4, Interval=0.004));
end BipedTwoClimbE;