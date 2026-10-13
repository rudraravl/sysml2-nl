model PantographDriveB
  parameter Modelica.SIunits.Length L_short = 0.25 "short parallelogram link length";
  parameter Modelica.SIunits.Length L_long = 0.50 "long parallelogram and fixed base link length";
  parameter Modelica.SIunits.Length travel = 0.16 "prismatic input travel";
  parameter Modelica.SIunits.Length d0 = 0.50 "actuator length at zero input travel; datum selected within valid diagonal range";
  parameter Modelica.SIunits.Force Fmax = 262 "allowed command magnitude";
  parameter Modelica.SIunits.Force FdistMag = 5.6 "middle-third load disturbance magnitude";
  parameter Modelica.SIunits.Time Tfinal = 10 "mission duration";
  parameter Modelica.SIunits.Frequency fSample = 100 "synchronized trace and sensor rate";
  parameter Modelica.SIunits.Time dt = 1.0/fSample "sample period";
  parameter Integer N = 1000 "number of synchronized samples";
  parameter Modelica.SIunits.Velocity vRef = travel/Tfinal "constant input speed";
  parameter Modelica.SIunits.Mass mEff = 10.0 "unknown effective actuator/link inertia, normalized for dynamics";
  parameter Modelica.SIunits.Acceleration g = 9.80665 "gravity acceleration";
  parameter Real Kp = 5000.0 "PI proportional gain";
  parameter Real Ki = 50000.0 "PI integral gain";

  Modelica.SIunits.Length s(start=0.0, fixed=true) "input travel coordinate";
  Modelica.SIunits.Velocity v(start=0.0, fixed=true) "input speed";
  Real Iint(start=0.0, fixed=true) "PI integral state";
  Modelica.SIunits.Length d "actuator length";
  Modelica.SIunits.Velocity eSpeed "input speed error";
  Modelica.SIunits.Force FcmdUnsat "unsaturated PI command";
  Modelica.SIunits.Force Fcmd "saturated command";
  Modelica.SIunits.Force Fdist "applied disturbance force";
  Modelica.SIunits.Force Fgrav "gravity generalized force";
  Modelica.SIunits.Force Fnet "net actuator force";
  Modelica.SIunits.Force FnetBounded "net force after travel-bound enforcement";

  Real cTheta "cos(angle of short link with base)";
  Real sTheta "sin(angle of short link with base)";
  Real sThetaSafe "sin with zero-error guard";
  Modelica.SIunits.Angle theta "short link angle";
  Modelica.SIunits.Position xB "moving pivot B x";
  Modelica.SIunits.Position yB "moving pivot B y";
  Modelica.SIunits.Position xC "output pivot C x";
  Modelica.SIunits.Position yC "output pivot C y";
  Modelica.SIunits.Position xOut "output x position";
  Modelica.SIunits.Position yOut "output y position";
  Modelica.SIunits.Angle phiOut "output orientation";
  Modelica.SIunits.Length outputTravel "cumulative output travel";

  Modelica.SIunits.Angle phi1 "revolute Z joint 1 (at A, link AB)";
  Modelica.SIunits.Angle phi2 "revolute Z joint 2 (at B, link BC)";
  Modelica.SIunits.Angle phi3 "revolute Z joint 3 (at C, link CD)";
  Modelica.SIunits.Angle phi4 "revolute Z joint 4 (at D, link DA)";
  Modelica.SIunits.Angle phi5 "revolute Z joint 5 (at A, actuator)";
  Modelica.SIunits.Angle phi6 "revolute Z joint 6 (at C, actuator)";

  Modelica.SIunits.Length rAB "loop-closure residual AB";
  Modelica.SIunits.Length rBC "loop-closure residual BC";
  Modelica.SIunits.Length rCD "loop-closure residual CD";
  Modelica.SIunits.Length rDA "loop-closure residual DA";
  Modelica.SIunits.Length rAC "loop-closure residual AC";
  Modelica.SIunits.Length closureErrorNorm "norm of all closure residuals";
  Modelica.SIunits.Length primaryTrackingError "primary tracking error";

  Modelica.SIunits.Length sep_AB_CD "separation of nonadjacent links AB and CD";
  Modelica.SIunits.Length sep_BC_DA "separation of nonadjacent links BC and DA";

  Modelica.SIunits.Velocity speedBandMin "lower speed band";
  Modelica.SIunits.Velocity speedBandMax "upper speed band";
  Real speedBandValid "speed band validity";
  Real actuatorBoundsValid "actuator bound validity";
  Real closureErrorsValid "closure error validity";
  Real collisionPrevented "nonadjacent collision prevention flag";
  Real jointRefsValid "joint reference validity";
  Real finiteCheckValid "finite-value check";

  Integer n(start=0) "trace sample counter";
  Real traceTime[N] "synchronized time trace";
  Real traceS[N] "actuator position trace";
  Real traceV[N] "actuator speed trace";
  Real traceFcmd[N] "saturated command trace";
  Real traceClosure[N] "closure error norm trace";
  Real traceXout[N] "output x trace";
  Real traceYout[N] "output y trace";
  Real traceRAB[N] "residual AB trace";
  Real traceRBC[N] "residual BC trace";
  Real traceRCD[N] "residual CD trace";
  Real traceRDA[N] "residual DA trace";
  Real traceRAC[N] "residual AC trace";

  parameter Real c0 = (d0*d0 - L_short*L_short - L_long*L_long)/(2.0*L_short*L_long);
  parameter Real s0 = sqrt(max(1.0 - c0*c0, 1.0e-12));
  parameter Modelica.SIunits.Position xOut0 = L_long + L_short*c0;
  parameter Modelica.SIunits.Position yOut0 = L_short*s0;

equation
  d = d0 + s;
  cTheta = (d*d - L_short*L_short - L_long*L_long)/(2.0*L_short*L_long);
  sTheta = sqrt(max(1.0 - cTheta*cTheta, 1.0e-12));
  sThetaSafe = max(sTheta, 1.0e-12);
  theta = atan2(sTheta, cTheta);

  xB = L_short*cTheta;
  yB = L_short*sTheta;
  xC = L_long + L_short*cTheta;
  yC = L_short*sTheta;

  xOut = xC;
  yOut = yC;
  phiOut = 0.0;
  outputTravel = sqrt(max((xOut - xOut0)*(xOut - xOut0) + (yOut - yOut0)*(yOut - yOut0), 0.0));

  rAB = sqrt(max(xB*xB + yB*yB, 0.0)) - L_short;
  rBC = sqrt(max((xC - xB)*(xC - xB) + (yC - yB)*(yC - yB), 0.0)) - L_long;
  rCD = sqrt(max((L_long - xC)*(L_long - xC) + yC*yC, 0.0)) - L_short;
  rDA = sqrt(max(L_long*L_long, 0.0)) - L_long;
  rAC = d - sqrt(max(xC*xC + yC*yC, 0.0));
  closureErrorNorm = sqrt(max(rAB*rAB + rBC*rBC + rCD*rCD + rDA*rDA + rAC*rAC, 0.0));
  primaryTrackingError = closureErrorNorm;

  phi1 = atan2(yB, xB);
  phi2 = atan2(yC - yB, xC - xB);
  phi3 = atan2(-yC, L_long - xC);
  phi4 = Modelica.Constants.pi;
  phi5 = atan2(yC, xC);
  phi6 = atan2(-yC, -xC);

  sep_AB_CD = L_long*sTheta;
  sep_BC_DA = L_short*sTheta;

  speedBandMin = 0.0;
  speedBandMax = vRef;
  speedBandValid = if noEvent(v >= -1.0e-6 and v <= vRef + 1.0e-6) then 1.0 else 0.0;
  actuatorBoundsValid = if noEvent(s >= -1.0e-9 and s <= travel + 1.0e-9) then 1.0 else 0.0;
  closureErrorsValid = if noEvent(closureErrorNorm <= 0.002) then 1.0 else 0.0;
  collisionPrevented = if noEvent(sep_AB_CD > 0.0 and sep_BC_DA > 0.0) then 1.0 else 0.0;
  jointRefsValid = if noEvent(abs(phi1) <= Modelica.Constants.pi + 1.0e-9 and abs(phi2) <= Modelica.Constants.pi + 1.0e-9 and abs(phi3) <= Modelica.Constants.pi + 1.0e-9 and abs(phi4) <= Modelica.Constants.pi + 1.0e-9 and abs(phi5) <= Modelica.Constants.pi + 1.0e-9 and abs(phi6) <= Modelica.Constants.pi + 1.0e-9) then 1.0 else 0.0;
  finiteCheckValid = if noEvent(abs(s) < 1.0e6 and abs(v) < 1.0e6 and abs(Fcmd) < 1.0e6 and abs(Iint) < 1.0e6) then 1.0 else 0.0;

  Fdist = if noEvent(time >= Tfinal/3.0 and time <= 2.0*Tfinal/3.0) then -FdistMag else 0.0;
  Fgrav = mEff*g*cTheta*d/(L_long*sThetaSafe);

  eSpeed = vRef - v;
  FcmdUnsat = Kp*eSpeed + Ki*Iint;
  der(Iint) = if noEvent(FcmdUnsat > Fmax and eSpeed > 0.0) then 0.0
               elseif noEvent(FcmdUnsat < -Fmax and eSpeed < 0.0) then 0.0
               else eSpeed;
  Fcmd = max(-Fmax, min(Fmax, FcmdUnsat));

  Fnet = Fcmd + Fdist + Fgrav;
  FnetBounded = if noEvent(s <= 0.0 and Fnet < 0.0) then 0.0
                elseif noEvent(s >= travel and Fnet > 0.0) then 0.0
                else Fnet;
  der(s) = v;
  der(v) = FnetBounded/mEff;

  when sample(0.0, dt) then
    n = if pre(n) < N then pre(n) + 1 else N;
    traceTime[n] = time;
    traceS[n] = s;
    traceV[n] = v;
    traceFcmd[n] = Fcmd;
    traceClosure[n] = closureErrorNorm;
    traceXout[n] = xOut;
    traceYout[n] = yOut;
    traceRAB[n] = rAB;
    traceRBC[n] = rBC;
    traceRCD[n] = rCD;
    traceRDA[n] = rDA;
    traceRAC[n] = rAC;
  end when;

  when s >= travel and v > 0.0 then
    reinit(s, travel);
    reinit(v, 0.0);
  end when;

  when s <= 0.0 and v < 0.0 then
    reinit(s, 0.0);
    reinit(v, 0.0);
  end when;

  assert(noEvent(s >= -1.0e-9 and s <= travel + 1.0e-9), "actuator travel bound violated");
  assert(noEvent(abs(Fcmd) <= Fmax + 1.0e-9), "command magnitude violated");
  assert(noEvent(cTheta >= -1.0 and cTheta <= 1.0), "diagonal length violates closure range");
  assert(noEvent(sep_AB_CD > 0.0 and sep_BC_DA > 0.0), "nonadjacent link separation collapsed; link thickness unknown");
  assert(noEvent(time < 6.5 or primaryTrackingError <= 0.002), "primary closure tracking error exceeds 0.002 m after 6.5 s");
  assert(noEvent(jointRefsValid > 0.5), "invalid joint reference");
  assert(noEvent(finiteCheckValid > 0.5), "non-finite physical/control value detected");

  annotation (experiment(StopTime=10, Tolerance=1e-6));
end PantographDriveB;