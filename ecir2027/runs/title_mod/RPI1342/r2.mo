model TendonSoftAvoidD
  "Instrumented tendon-driven soft robot with obstacle avoidance, bounded contact, stiffness scheduling, and 200 Hz traces.";

  // Specified embodiment and run parameters
  parameter Real L = 0.55 "continuum body length (m)";
  parameter Integer nSec = 6 "constant-curvature sections";
  parameter Real Ls = L/nSec "section length (m)";
  parameter Real Tmax = 42.0 "per-tendon tension limit (N)";
  parameter Real Ts = 0.005 "200 Hz sampling period (s)";
  parameter Integer N = 2801 "trace length for 14 s at 200 Hz";

  // Three tendons spaced 120 degrees apart
  parameter Real tendonAngle[3] = {0.0, 2.0943951023931953, 4.1887902047863905} "rad";

  // Obstacle and target geometry: not specified by requirement; nominal values selected only to make simulation executable.
  parameter Real targetX = 0.540 "nominal target tip x (m)";
  parameter Real targetY = 0.090 "nominal target tip y (m)";
  parameter Real kTarget = 0.580 "nominal curvature for target (1/m)";
  parameter Real obsX = 0.270 "nominal fixed cylinder center x (m)";
  parameter Real obsY = -0.030 "nominal fixed cylinder center y (m)";
  parameter Real obsR = 0.030 "nominal fixed cylinder radius (m)";
  parameter Real bodyR = 0.008 "nominal body radius (m)";
  parameter Real mu = 0.55 "fixed cylinder friction coefficient";

  // Disturbance: controlled 8 N lateral tip load during middle third of 14 s
  parameter Real FdistMag = 8.0 "lateral tip load magnitude (N)";
  parameter Real tStart = 14.0/3.0 "disturbance start (s)";
  parameter Real tEnd = 28.0/3.0 "disturbance end (s)";

  // Nominal physical/control gains: not specified by requirement; selected for finite executable behavior only.
  parameter Real Kmap = 0.030 "tension-difference to curvature mapping (rad/N)";
  parameter Real T0 = 20.0 "baseline tendon tension (N)";
  parameter Real omega = 6.0 "section curvature natural frequency (rad/s)";
  parameter Real zeta = 0.8 "section damping ratio";
  parameter Real tauT = 0.05 "tendon actuator time constant (s)";
  parameter Real tauContact = 0.02 "contact-force filter time constant (s)";
  parameter Real Kc = 5000.0 "contact penalty stiffness (N/m)";
  parameter Real FcontactMax = 20.0 "bounded normal contact force (N)";
  parameter Real Kcm = 0.10 "contact-force to curvature moment gain";
  parameter Real Kdist = 0.50 "tip-load to curvature disturbance gain";
  parameter Real Kpy = 1.0 "tip-y feedback gain";
  parameter Real Kpx = 0.5 "tip-x feedback gain";
  parameter Real Kcontact = 0.005 "contact-aware curvature correction gain";
  parameter Real Klow = 1.0 "lower stiffness schedule";
  parameter Real Khigh = 3.0 "upper stiffness schedule";
  parameter Real tHold = 7.0 "stiffness hold scheduling time (s)";
  parameter Real tauS = 0.5 "stiffness scheduling time constant (s)";
  parameter Real kMax = 1.5 "nominal deformation bound (1/m)";
  parameter Real Tamb = 293.15 "ambient temperature (K)";
  parameter Real heatGainK = 15.0 "nominal tendon heating scale (K)";
  parameter Real tauTh = 20.0 "nominal thermal time constant (s)";

  // Observable measurements and commands
  output Real actuatorState[3] "measured tendon tensions (N)";
  output Real sectionDeformation[6] "measured section curvatures (1/m)";
  output Real contactForce[6] "distributed contact-force magnitude per section (N)";
  output Real tipPose[3] "measured tip x, y, theta (m, m, rad)";
  output Real tendonTemp[3] "measured tendon temperatures (K)";
  output Real obstacleClearance[6] "section-to-obstacle clearances (m)";
  output Real minObstacleClearance "minimum clearance (m)";
  output Real primaryTrackingError "Euclidean tip-to-target error (m)";
  output Real tensionCommand[3] "bounded tendon tension commands (N)";
  output Real stiffnessSchedule "bounded stiffness factor";

protected
  // States
  Real k[6](start = {0.0,0.0,0.0,0.0,0.0,0.0}) "section curvature";
  Real q[6](start = {0.0,0.0,0.0,0.0,0.0,0.0}) "curvature rate";
  Real Traw[3](start = {20.0,20.0,20.0}) "unsaturated tendon tension";
  Real fn[6](start = {0.0,0.0,0.0,0.0,0.0,0.0}) "filtered normal contact force";
  Real temp[3](start = {293.15,293.15,293.15}) "tendon temperature";
  Real stiffScheduleState(start = Klow) "scheduled stiffness state";

  // Algebraic variables
  Real T[3] "saturated measured tension";
  Real TcmdRaw[3] "unbounded command";
  Real Tcmd[3] "bounded command";
  Real kcmd "desired curvature";
  Real kref[6] "curvature reference from tendons";
  Real contactMoment[6];
  Real distMoment[6];
  Real fnTarget[6];
  Real ft[6];
  Real clearance[6];
  Real penetration[6];
  Real xNode[7];
  Real yNode[7];
  Real thetaNode[7];
  Real xMid[6];
  Real yMid[6];
  Real tipX;
  Real tipY;
  Real tipTheta;
  Real ex;
  Real ey;
  Real Fdist;
  Real Kstiff;
  Real contactForceSum;

  // Synchronized state, command, and sensor traces at 200 Hz
  Real traceTime[N];
  Real traceState[N,6];
  Real traceActuator[N,3];
  Real traceCommand[N,3];
  Real traceContact[N,6];
  Real traceClearance[N,6];
  Real traceTip[N,3];
  Integer traceIdx(start = 0);

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

  function arcDeltaX
    input Real k;
    input Real Ls;
    input Real theta0;
    output Real dx;
  protected
    Real phi;
  algorithm
    phi := k*Ls;
    if abs(k) < 1e-9 then
      dx := Ls*cos(theta0);
    else
      dx := (sin(theta0 + phi) - sin(theta0))/k;
    end if;
  end arcDeltaX;

  function arcDeltaY
    input Real k;
    input Real Ls;
    input Real theta0;
    output Real dy;
  protected
    Real phi;
  algorithm
    phi := k*Ls;
    if abs(k) < 1e-9 then
      dy := Ls*sin(theta0);
    else
      dy := (cos(theta0) - cos(theta0 + phi))/k;
    end if;
  end arcDeltaY;

  function min6
    input Real v[6];
    output Real m;
  algorithm
    m := v[1];
    for i in 2:6 loop
      if v[i] < m then
        m := v[i];
      end if;
    end for;
  end min6;

equation
  // Tendon command and actuator dynamics with per-tendon 42 N limit
  TcmdRaw[1] = T0;
  TcmdRaw[2] = T0 + 0.5*(kcmd/Kmap);
  TcmdRaw[3] = T0 - 0.5*(kcmd/Kmap);

  for j in 1:3 loop
    Tcmd[j] = clampReal(TcmdRaw[j], 0.0, Tmax);
    T[j] = clampReal(Traw[j], 0.0, Tmax);
    der(Traw[j]) = (Tcmd[j] - Traw[j])/tauT;
    actuatorState[j] = T[j];
    tensionCommand[j] = Tcmd[j];
    der(temp[j]) = (Tamb + heatGainK*(T[j]/Tmax)^2 - temp[j])/tauTh;
    tendonTemp[j] = temp[j];
  end for;

  // Bounded stiffness scheduling
  der(stiffScheduleState) = if time >= tHold then (Khigh - stiffScheduleState)/tauS else (Klow - stiffScheduleState)/tauS;
  Kstiff = stiffScheduleState;
  stiffnessSchedule = stiffScheduleState;

  // Disturbance: 8 N lateral load during middle third, applied as generalized curvature disturbance
  Fdist = if time >= tStart and time <= tEnd then -FdistMag else 0.0;

  // Constant-curvature section dynamics controlled by tendon tensions
  for i in 1:6 loop
    kref[i] = Kmap*(T[2] - T[3]);
    der(k[i]) = q[i];
    der(q[i]) = Kstiff*omega*omega*(kref[i] - k[i]) - 2.0*zeta*omega*q[i] + contactMoment[i] + distMoment[i];
    sectionDeformation[i] = k[i];

    clearance[i] = sqrt((xMid[i] - obsX)^2 + (yMid[i] - obsY)^2) - obsR - bodyR;
    obstacleClearance[i] = clearance[i];
    penetration[i] = max(0.0, -clearance[i]);
    fnTarget[i] = clampReal(Kc*penetration[i], 0.0, FcontactMax);
    der(fn[i]) = (fnTarget[i] - fn[i])/tauContact;
    ft[i] = mu*fn[i];
    contactForce[i] = sqrt(fn[i]*fn[i] + ft[i]*ft[i]);
    contactMoment[i] = Kcm*fn[i];
    distMoment[i] = Kdist*Fdist;
  end for;

  // Kinematics of six constant-curvature sections
  xNode[1] = 0.0;
  yNode[1] = 0.0;
  thetaNode[1] = 0.0;
  for i in 1:6 loop
    xNode[i+1] = xNode[i] + arcDeltaX(k[i], Ls, thetaNode[i]);
    yNode[i+1] = yNode[i] + arcDeltaY(k[i], Ls, thetaNode[i]);
    thetaNode[i+1] = thetaNode[i] + k[i]*Ls;
    xMid[i] = 0.5*(xNode[i] + xNode[i+1]);
    yMid[i] = 0.5*(yNode[i] + yNode[i+1]);
  end for;

  tipX = xNode[7];
  tipY = yNode[7];
  tipTheta = thetaNode[7];
  tipPose[1] = tipX;
  tipPose[2] = tipY;
  tipPose[3] = tipTheta;

  // Contact-aware shape control with bounded stiffness scheduling
  ex = tipX - targetX;
  ey = tipY - targetY;
  primaryTrackingError = sqrt(ex*ex + ey*ey);
  contactForceSum = contactForce[1] + contactForce[2] + contactForce[3] + contactForce[4] + contactForce[5] + contactForce[6];
  kcmd = kTarget + Kpy*(targetY - tipY) + Kpx*(tipX - targetX) + Kcontact*contactForceSum;

  minObstacleClearance = min6(clearance);

  // Bounds and finite-value guards
  assert(time < 9.1 or primaryTrackingError <= 0.04, "primary tracking error bound violated after 9.1 s");
  assert(time < 13.999 or primaryTrackingError <= 0.04, "final tip-error bound violated");
  for j in 1:3 loop
    assert(T[j] <= Tmax + 1e-6, "actuator tension bound violated");
    assert(temp[j] >= 250.0 and temp[j] <= 350.0, "temperature bound violated");
  end for;
  for i in 1:6 loop
    assert(abs(k[i]) <= kMax, "deformation bound violated");
    assert(contactForce[i] <= FcontactMax*sqrt(1.0 + mu*mu) + 1e-6, "contact-force bound violated");
  end for;
  assert(minObstacleClearance >= -1e-4, "obstacle-clearance bound violated");
  assert(stiffScheduleState >= Klow - 0.01 and stiffScheduleState <= Khigh + 0.01, "stiffness schedule bound violated");
  assert(abs(tipX) < 1e6 and abs(tipY) < 1e6 and abs(tipTheta) < 1e6 and abs(kcmd) < 1e6 and abs(primaryTrackingError) < 1e6, "non-finite physical/control value detected");

algorithm
  when sample(0.0, Ts) then
    if pre(traceIdx) < N then
      traceIdx := pre(traceIdx) + 1;
      traceTime[traceIdx] := time;
      for j in 1:6 loop
        traceState[traceIdx,j] := k[j];
        traceContact[traceIdx,j] := contactForce[j];
        traceClearance[traceIdx,j] := clearance[j];
      end for;
      for j in 1:3 loop
        traceActuator[traceIdx,j] := T[j];
        traceCommand[traceIdx,j] := Tcmd[j];
        traceTip[traceIdx,j] := tipPose[j];
      end for;
    else
      traceIdx := pre(traceIdx);
    end if;
  end when;

  annotation(experiment(StopTime = 14.0, Interval = 0.005));
end TendonSoftAvoidD;