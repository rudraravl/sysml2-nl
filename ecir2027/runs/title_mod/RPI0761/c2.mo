model BipedTwoClimbE
  parameter Real Ts = 0.004 "controller sample period 250 Hz";
  parameter Real g = 9.81 "standard gravity";
  parameter Real mPelvis = 36 "kg";
  parameter Real lThigh = 0.42 "m";
  parameter Real lShank = 0.40 "m";
  parameter Real lFoot = 0.18 "m";
  parameter Real wFoot = 0.10 "m";
  parameter Real hipSep = 0.30 "m";
  parameter Real rise = 0.16 "m";
  parameter Real tread = 0.30 "m";
  parameter Integer nStairs = 4;
  parameter Real hBodyDes = 0.78 "m";
  parameter Real qMax = 2.0 "rad";
  parameter Real jointInertia = 0.05 "kg.m2";
  parameter Real jointDamping = 2.0 "N.m.s/rad";
  parameter Real kpImp = 300.0 "N.m/rad";
  parameter Real kdImp = 15.0 "N.m.s/rad";
  parameter Real kx = 5000.0 "N/m";
  parameter Real dampX = 500.0 "N.s/m";
  parameter Real kz = 8000.0 "N/m";
  parameter Real dampZ = 800.0 "N.s/m";
  parameter Real contactStiffness = 1.0e5 "N/m";
  parameter Real contactDamping = 1.0e3 "N.s/m";
  parameter Real contactThresh = 5.0 "N";
  parameter Real clearanceTol = 0.0011 "m";
  parameter Real swingClearance = 0.08 "m";
  parameter Real contactPen = 0.001 "m";
  parameter Real Tphase = 1.25 "s per half step";
  parameter Real tauMax = 138.0 "N.m per joint";
  parameter Real payloadForce = 120.0 "N";
  parameter Real friction = 0.88;
  parameter Real trackingLimit = 0.036 "m";
  parameter Real trackingTime = 10.4 "s";
  parameter Real finalTime = 16.0 "s";

  Real x(start=0.15, fixed=true) "pelvis horizontal m";
  Real z(start=0.779, fixed=true) "pelvis vertical m";
  Real vx(start=0, fixed=true) "pelvis horizontal velocity m/s";
  Real vz(start=0, fixed=true) "pelvis vertical velocity m/s";

  Real q1_1(start=0, fixed=true);
  Real q1_2(start=0, fixed=true);
  Real q1_3(start=0.306, fixed=true);
  Real q1_4(start=-0.628, fixed=true);
  Real q1_5(start=0, fixed=true);
  Real q1_6(start=0.322, fixed=true);
  Real q2_1(start=0, fixed=true);
  Real q2_2(start=0, fixed=true);
  Real q2_3(start=0.306, fixed=true);
  Real q2_4(start=-0.628, fixed=true);
  Real q2_5(start=0, fixed=true);
  Real q2_6(start=0.322, fixed=true);

  Real w1_1(start=0, fixed=true);
  Real w1_2(start=0, fixed=true);
  Real w1_3(start=0, fixed=true);
  Real w1_4(start=0, fixed=true);
  Real w1_5(start=0, fixed=true);
  Real w1_6(start=0, fixed=true);
  Real w2_1(start=0, fixed=true);
  Real w2_2(start=0, fixed=true);
  Real w2_3(start=0, fixed=true);
  Real w2_4(start=0, fixed=true);
  Real w2_5(start=0, fixed=true);
  Real w2_6(start=0, fixed=true);

  Real qDes1_1, qDes1_2, qDes1_3, qDes1_4, qDes1_5, qDes1_6;
  Real qDes2_1, qDes2_2, qDes2_3, qDes2_4, qDes2_5, qDes2_6;
  Real qIK1_1, qIK1_2, qIK1_3;
  Real qIK2_1, qIK2_2, qIK2_3;
  Real tauRaw1_1, tauRaw1_2, tauRaw1_3, tauRaw1_4, tauRaw1_5, tauRaw1_6;
  Real tauRaw2_1, tauRaw2_2, tauRaw2_3, tauRaw2_4, tauRaw2_5, tauRaw2_6;
  Real tauCmd1_1, tauCmd1_2, tauCmd1_3, tauCmd1_4, tauCmd1_5, tauCmd1_6;
  Real tauCmd2_1, tauCmd2_2, tauCmd2_3, tauCmd2_4, tauCmd2_5, tauCmd2_6;

  Real footXDes1, footZDes1, footXDes2, footZDes2;
  Real baseXDes, baseZDes;

  discrete Real planOut1(start=0.15);
  discrete Real planOut2(start=-0.001);
  discrete Real planOut3(start=0.15);
  discrete Real planOut4(start=-0.001);
  discrete Real planOut5(start=0.15);
  discrete Real planOut6(start=0.779);

  Real rX1, rZ1, rX2, rZ2;
  Real footX1, footZ1, footX2, footZ2;
  Real vxFoot1, vzFoot1, vxFoot2, vzFoot2;

  Real cX1_1, cX1_2, cZ1_1, cZ1_2;
  Real cX2_1, cX2_2, cZ2_1, cZ2_2;
  Real pen1_1, pen1_2, pen2_1, pen2_2;
  Real Fz1_1, Fz1_2, Fz2_1, Fz2_2;
  Real Fx1_1, Fx1_2, Fx2_1, Fx2_2;
  Boolean contact1_1, contact1_2, contact2_1, contact2_2;
  Integer supportContacts;

  Real depthRange1, depthRange2;
  Real edgeDist1, edgeDist2;
  Boolean edgeDetected1, edgeDetected2;
  Real imuAccX, imuAccY, imuAccZ;
  Real imuGyroX, imuGyroY, imuGyroZ;
  Real enc1_1, enc1_2, enc1_3, enc1_4, enc1_5, enc1_6;
  Real enc2_1, enc2_2, enc2_3, enc2_4, enc2_5, enc2_6;
  Real estBaseX, estBaseZ, estFootX1, estFootZ1, estFootX2, estFootZ2;

  Real FxBase, FzBase, payloadActive;
  Real bodyHeightError, footholdError;
  Real maxAbsQ, maxAbsW, maxAbsTau, sumAbsState;
  Boolean jointBoundsOK, effortBoundsOK, clearanceOK, twoSupportOK;
  Boolean completionOK, trackingOK, noNaNInfOK, bodyHeightOK, acceptanceOK;

protected
  function terrainHeight
    input Real xIn;
    input Real treadIn;
    input Real riseIn;
    input Integer nStairsIn;
    output Real h;
  protected
    Integer i;
    Real tmp;
  algorithm
    tmp := xIn / treadIn;
    i := integer(floor(tmp));
    if i < 0 then
      i := 0;
    end if;
    if i > nStairsIn then
      i := nStairsIn;
    end if;
    h := i * riseIn;
  end terrainHeight;

  function clampReal
    input Real xIn;
    input Real lo;
    input Real hi;
    output Real y;
  algorithm
    if xIn < lo then
      y := lo;
    elseif xIn > hi then
      y := hi;
    else
      y := xIn;
    end if;
  end clampReal;

  function finiteCheck
    input Real xIn;
    output Boolean ok;
  algorithm
    ok := abs(xIn) < 1e20;
  end finiteCheck;

  function legIK
    input Real dx;
    input Real dz;
    input Real lT;
    input Real lS;
    output Real qH;
    output Real qK;
    output Real qA;
  protected
    Real L2, c2;
  algorithm
    L2 := dx * dx + dz * dz;
    c2 := (L2 - lT * lT - lS * lS) / (2.0 * lT * lS);
    if c2 > 1.0 then
      c2 := 1.0;
    elseif c2 < -1.0 then
      c2 := -1.0;
    end if;
    qK := -Modelica.Math.acos(c2);
    qH := Modelica.Math.atan2(dx, -dz) - Modelica.Math.atan2(lS * Modelica.Math.sin(qK), lT + lS * Modelica.Math.cos(qK));
    qA := -(qH + qK);
  end legIK;

  function maxAbsScalar
    input Real a1;
    input Real a2;
    input Real a3;
    input Real a4;
    input Real a5;
    input Real a6;
    input Real b1;
    input Real b2;
    input Real b3;
    input Real b4;
    input Real b5;
    input Real b6;
    output Real m;
  protected
    Real tmp;
  algorithm
    m := abs(a1);
    tmp := abs(a2); if tmp > m then m := tmp; end if;
    tmp := abs(a3); if tmp > m then m := tmp; end if;
    tmp := abs(a4); if tmp > m then m := tmp; end if;
    tmp := abs(a5); if tmp > m then m := tmp; end if;
    tmp := abs(a6); if tmp > m then m := tmp; end if;
    tmp := abs(b1); if tmp > m then m := tmp; end if;
    tmp := abs(b2); if tmp > m then m := tmp; end if;
    tmp := abs(b3); if tmp > m then m := tmp; end if;
    tmp := abs(b4); if tmp > m then m := tmp; end if;
    tmp := abs(b5); if tmp > m then m := tmp; end if;
    tmp := abs(b6); if tmp > m then m := tmp; end if;
  end maxAbsScalar;

equation
  footXDes1 = planOut1;
  footZDes1 = planOut2;
  footXDes2 = planOut3;
  footZDes2 = planOut4;
  baseXDes = planOut5;
  baseZDes = planOut6;

  payloadActive = if time >= finalTime / 3.0 and time <= 2.0 * finalTime / 3.0 then 1.0 else 0.0;

  FxBase = kx * (baseXDes - x) + dampX * (0.0 - vx);
  FzBase = mPelvis * g + payloadForce * payloadActive + kz * (baseZDes - z) + dampZ * (0.0 - vz);
  der(x) = vx;
  der(vx) = FxBase / mPelvis;
  der(z) = vz;
  der(vz) = (FzBase - mPelvis * g - payloadForce * payloadActive) / mPelvis;

  (qIK1_1, qIK1_2, qIK1_3) = legIK(footXDes1 - baseXDes, footZDes1 - baseZDes, lThigh, lShank);
  (qIK2_1, qIK2_2, qIK2_3) = legIK(footXDes2 - baseXDes, footZDes2 - baseZDes, lThigh, lShank);

  qDes1_1 = 0.0;
  qDes1_2 = 0.0;
  qDes1_3 = qIK1_1;
  qDes1_4 = qIK1_2;
  qDes1_5 = 0.0;
  qDes1_6 = qIK1_3;
  qDes2_1 = 0.0;
  qDes2_2 = 0.0;
  qDes2_3 = qIK2_1;
  qDes2_4 = qIK2_2;
  qDes2_5 = 0.0;
  qDes2_6 = qIK2_3;

  tauRaw1_1 = kpImp * (qDes1_1 - q1_1) - kdImp * w1_1;
  tauRaw1_2 = kpImp * (qDes1_2 - q1_2) - kdImp * w1_2;
  tauRaw1_3 = kpImp * (qDes1_3 - q1_3) - kdImp * w1_3;
  tauRaw1_4 = kpImp * (qDes1_4 - q1_4) - kdImp * w1_4;
  tauRaw1_5 = kpImp * (qDes1_5 - q1_5) - kdImp * w1_5;
  tauRaw1_6 = kpImp * (qDes1_6 - q1_6) - kdImp * w1_6;
  tauRaw2_1 = kpImp * (qDes2_1 - q2_1) - kdImp * w2_1;
  tauRaw2_2 = kpImp * (qDes2_2 - q2_2) - kdImp * w2_2;
  tauRaw2_3 = kpImp * (qDes2_3 - q2_3) - kdImp * w2_3;
  tauRaw2_4 = kpImp * (qDes2_4 - q2_4) - kdImp * w2_4;
  tauRaw2_5 = kpImp * (qDes2_5 - q2_5) - kdImp * w2_5;
  tauRaw2_6 = kpImp * (qDes2_6 - q2_6) - kdImp * w2_6;

  tauCmd1_1 = clampReal(tauRaw1_1, -tauMax, tauMax);
  tauCmd1_2 = clampReal(tauRaw1_2, -tauMax, tauMax);
  tauCmd1_3 = clampReal(tauRaw1_3, -tauMax, tauMax);
  tauCmd1_4 = clampReal(tauRaw1_4, -tauMax, tauMax);
  tauCmd1_5 = clampReal(tauRaw1_5, -tauMax, tauMax);
  tauCmd1_6 = clampReal(tauRaw1_6, -tauMax, tauMax);
  tauCmd2_1 = clampReal(tauRaw2_1, -tauMax, tauMax);
  tauCmd2_2 = clampReal(tauRaw2_2, -tauMax, tauMax);
  tauCmd2_3 = clampReal(tauRaw2_3, -tauMax, tauMax);
  tauCmd2_4 = clampReal(tauRaw2_4, -tauMax, tauMax);
  tauCmd2_5 = clampReal(tauRaw2_5, -tauMax, tauMax);
  tauCmd2_6 = clampReal(tauRaw2_6, -tauMax, tauMax);

  der(q1_1) = w1_1;
  der(q1_2) = w1_2;
  der(q1_3) = w1_3;
  der(q1_4) = w1_4;
  der(q1_5) = w1_5;
  der(q1_6) = w1_6;
  der(q2_1) = w2_1;
  der(q2_2) = w2_2;
  der(q2_3) = w2_3;
  der(q2_4) = w2_4;
  der(q2_5) = w2_5;
  der(q2_6) = w2_6;

  der(w1_1) = (tauCmd1_1 - jointDamping * w1_1) / jointInertia;
  der(w1_2) = (tauCmd1_2 - jointDamping * w1_2) / jointInertia;
  der(w1_3) = (tauCmd1_3 - jointDamping * w1_3) / jointInertia;
  der(w1_4) = (tauCmd1_4 - jointDamping * w1_4) / jointInertia;
  der(w1_5) = (tauCmd1_5 - jointDamping * w1_5) / jointInertia;
  der(w1_6) = (tauCmd1_6 - jointDamping * w1_6) / jointInertia;
  der(w2_1) = (tauCmd2_1 - jointDamping * w2_1) / jointInertia;
  der(w2_2) = (tauCmd2_2 - jointDamping * w2_2) / jointInertia;
  der(w2_3) = (tauCmd2_3 - jointDamping * w2_3) / jointInertia;
  der(w2_4) = (tauCmd2_4 - jointDamping * w2_4) / jointInertia;
  der(w2_5) = (tauCmd2_5 - jointDamping * w2_5) / jointInertia;
  der(w2_6) = (tauCmd2_6 - jointDamping * w2_6) / jointInertia;

  rX1 = lThigh * Modelica.Math.sin(q1_3) + lShank * Modelica.Math.sin(q1_3 + q1_4);
  rZ1 = -lThigh * Modelica.Math.cos(q1_3) - lShank * Modelica.Math.cos(q1_3 + q1_4);
  rX2 = lThigh * Modelica.Math.sin(q2_3) + lShank * Modelica.Math.sin(q2_3 + q2_4);
  rZ2 = -lThigh * Modelica.Math.cos(q2_3) - lShank * Modelica.Math.cos(q2_3 + q2_4);

  footX1 = x + rX1;
  footZ1 = z + rZ1;
  footX2 = x + rX2;
  footZ2 = z + rZ2;

  vxFoot1 = vx + (lThigh * Modelica.Math.cos(q1_3) + lShank * Modelica.Math.cos(q1_3 + q1_4)) * w1_3
              + lShank * Modelica.Math.cos(q1_3 + q1_4) * w1_4;
  vzFoot1 = vz + (lThigh * Modelica.Math.sin(q1_3) + lShank * Modelica.Math.sin(q1_3 + q1_4)) * w1_3
              + lShank * Modelica.Math.sin(q1_3 + q1_4) * w1_4;
  vxFoot2 = vx + (lThigh * Modelica.Math.cos(q2_3) + lShank * Modelica.Math.cos(q2_3 + q2_4)) * w2_3
              + lShank * Modelica.Math.cos(q2_3 + q2_4) * w2_4;
  vzFoot2 = vz + (lThigh * Modelica.Math.sin(q2_3) + lShank * Modelica.Math.sin(q2_3 + q2_4)) * w2_3
              + lShank * Modelica.Math.sin(q2_3 + q2_4) * w2_4;

  cX1_1 = footX1 - 0.5 * lFoot;
  cX1_2 = footX1 + 0.5 * lFoot;
  cX2_1 = footX2 - 0.5 * lFoot;
  cX2_2 = footX2 + 0.5 * lFoot;
  cZ1_1 = footZ1;
  cZ1_2 = footZ1;
  cZ2_1 = footZ2;
  cZ2_2 = footZ2;

  pen1_1 = terrainHeight(cX1_1, tread, rise, nStairs) - cZ1_1;
  pen1_2 = terrainHeight(cX1_2, tread, rise, nStairs) - cZ1_2;
  pen2_1 = terrainHeight(cX2_1, tread, rise, nStairs) - cZ2_1;
  pen2_2 = terrainHeight(cX2_2, tread, rise, nStairs) - cZ2_2;

  Fz1_1 = if pen1_1 > 0.0 and (contactStiffness * pen1_1 - contactDamping * vzFoot1) > 0.0
          then contactStiffness * pen1_1 - contactDamping * vzFoot1 else 0.0;
  Fz1_2 = if pen1_2 > 0.0 and (contactStiffness * pen1_2 - contactDamping * vzFoot1) > 0.0
          then contactStiffness * pen1_2 - contactDamping * vzFoot1 else 0.0;
  Fz2_1 = if pen2_1 > 0.0 and (contactStiffness * pen2_1 - contactDamping * vzFoot2) > 0.0
          then contactStiffness * pen2_1 - contactDamping * vzFoot2 else 0.0;
  Fz2_2 = if pen2_2 > 0.0 and (contactStiffness * pen2_2 - contactDamping * vzFoot2) > 0.0
          then contactStiffness * pen2_2 - contactDamping * vzFoot2 else 0.0;

  Fx1_1 = if Fz1_1 > 0.0 then friction * Fz1_1 * Modelica.Math.tanh(-vxFoot1 / 0.01) else 0.0;
  Fx1_2 = if Fz1_2 > 0.0 then friction * Fz1_2 * Modelica.Math.tanh(-vxFoot1 / 0.01) else 0.0;
  Fx2_1 = if Fz2_1 > 0.0 then friction * Fz2_1 * Modelica.Math.tanh(-vxFoot2 / 0.01) else 0.0;
  Fx2_2 = if Fz2_2 > 0.0 then friction * Fz2_2 * Modelica.Math.tanh(-vxFoot2 / 0.01) else 0.0;

  contact1_1 = Fz1_1 > contactThresh;
  contact1_2 = Fz1_2 > contactThresh;
  contact2_1 = Fz2_1 > contactThresh;
  contact2_2 = Fz2_2 > contactThresh;

  supportContacts = (if contact1_1 then 1 else 0) + (if contact1_2 then 1 else 0)
                  + (if contact2_1 then 1 else 0) + (if contact2_2 then 1 else 0);

  depthRange1 = max(0.0, terrainHeight(footX1, tread, rise, nStairs) - footZ1);
  depthRange2 = max(0.0, terrainHeight(footX2, tread, rise, nStairs) - footZ2);
  edgeDist1 = min(abs(footX1 - tread * floor(footX1 / tread)),
                  abs(footX1 - tread * floor(footX1 / tread) - tread));
  edgeDist2 = min(abs(footX2 - tread * floor(footX2 / tread)),
                  abs(footX2 - tread * floor(footX2 / tread) - tread));
  edgeDetected1 = edgeDist1 < 0.02;
  edgeDetected2 = edgeDist2 < 0.02;

  enc1_1 = q1_1;
  enc1_2 = q1_2;
  enc1_3 = q1_3;
  enc1_4 = q1_4;
  enc1_5 = q1_5;
  enc1_6 = q1_6;
  enc2_1 = q2_1;
  enc2_2 = q2_2;
  enc2_3 = q2_3;
  enc2_4 = q2_4;
  enc2_5 = q2_5;
  enc2_6 = q2_6;

  imuAccX = FxBase / mPelvis;
  imuAccY = 0.0;
  imuAccZ = (FzBase - mPelvis * g - payloadForce * payloadActive) / mPelvis;
  imuGyroX = 0.0;
  imuGyroY = 0.0;
  imuGyroZ = 0.0;

  estBaseX = x;
  estBaseZ = z;
  estFootX1 = footX1;
  estFootZ1 = footZ1;
  estFootX2 = footX2;
  estFootZ2 = footZ2;

  maxAbsQ = maxAbsScalar(q1_1, q1_2, q1_3, q1_4, q1_5, q1_6,
                          q2_1, q2_2, q2_3, q2_4, q2_5, q2_6);
  maxAbsW = maxAbsScalar(w1_1, w1_2, w1_3, w1_4, w1_5, w1_6,
                          w2_1, w2_2, w2_3, w2_4, w2_5, w2_6);
  maxAbsTau = maxAbsScalar(tauCmd1_1, tauCmd1_2, tauCmd1_3, tauCmd1_4, tauCmd1_5, tauCmd1_6,
                            tauCmd2_1, tauCmd2_2, tauCmd2_3, tauCmd2_4, tauCmd2_5, tauCmd2_6);

  footholdError = max(Modelica.Math.sqrt((footXDes1 - footX1) * (footXDes1 - footX1)
                                       + (footZDes1 - footZ1) * (footZDes1 - footZ1)),
                      Modelica.Math.sqrt((footXDes2 - footX2) * (footXDes2 - footX2)
                                       + (footZDes2 - footZ2) * (footZDes2 - footZ2)));
  bodyHeightError = abs(z - baseZDes);

  jointBoundsOK = maxAbsQ <= qMax;
  effortBoundsOK = maxAbsTau <= tauMax + 1e-6;
  clearanceOK = (cZ1_1 >= terrainHeight(cX1_1, tread, rise, nStairs) - clearanceTol)
              and (cZ1_2 >= terrainHeight(cX1_2, tread, rise, nStairs) - clearanceTol)
              and (cZ2_1 >= terrainHeight(cX2_1, tread, rise, nStairs) - clearanceTol)
              and (cZ2_2 >= terrainHeight(cX2_2, tread, rise, nStairs) - clearanceTol);
  twoSupportOK = supportContacts >= 2;
  completionOK = x >= nStairs * tread and z >= nStairs * rise + hBodyDes - 0.05;
  trackingOK = if time >= trackingTime then footholdError <= trackingLimit else true;
  bodyHeightOK = bodyHeightError <= 0.05;

  sumAbsState = abs(x) + abs(z) + abs(vx) + abs(vz) + maxAbsQ + maxAbsW + maxAbsTau
              + abs(FxBase) + abs(FzBase) + abs(footholdError) + supportContacts + bodyHeightError;
  noNaNInfOK = finiteCheck(sumAbsState);

  acceptanceOK = jointBoundsOK and effortBoundsOK and clearanceOK and twoSupportOK
              and completionOK and trackingOK and bodyHeightOK and noNaNInfOK;

  assert(noNaNInfOK, "NaN or infinite value detected");
  assert(effortBoundsOK, "joint effort bound violated");
  assert(jointBoundsOK, "joint bound violated");
  assert(twoSupportOK, "fewer than two support contacts");
  assert(clearanceOK, "stair edge clearance violated");
  assert(if time >= trackingTime then trackingOK else true, "primary tracking error violated after 10.4 s");

algorithm
  when sample(0, Ts) then
    (planOut1, planOut2, planOut3, planOut4, planOut5, planOut6) :=
      planFootholds(time, Tphase, tread, rise, nStairs, hBodyDes, contactPen, swingClearance);
  end when;

  when terminal() then
    assert(completionOK and acceptanceOK, "BipedTwoClimbE fail closed acceptance violated");
  end when;

  annotation(experiment(StopTime=16, Tolerance=1e-4, Interval=0.004));
end BipedTwoClimbE;