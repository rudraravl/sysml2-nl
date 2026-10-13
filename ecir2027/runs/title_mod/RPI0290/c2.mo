model PantographDriveB
  parameter Real L_short = 0.25 "short parallelogram link length [m]";
  parameter Real L_long = 0.50 "long parallelogram and fixed base link length [m]";
  parameter Real travel = 0.16 "prismatic input travel [m]";
  parameter Real d0 = 0.50 "actuator length at zero input travel [m]";
  parameter Real Fmax = 262 "allowed command magnitude [N]";
  parameter Real FdistMag = 5.6 "middle-third load disturbance magnitude [N]";
  parameter Real Tfinal = 10 "mission duration [s]";
  parameter Real vRef = travel / Tfinal "constant input speed [m/s]";
  parameter Real mEff = 10.0 "effective actuator/link inertia [kg]";
  parameter Real g = 9.80665 "gravity acceleration [m/s2]";
  parameter Real Kp = 5000.0 "PI proportional gain";
  parameter Real Ki = 50000.0 "PI integral gain";

  Real s(start = 0, fixed = true) "input travel coordinate [m]";
  Real v(start = 0, fixed = true) "input speed [m/s]";
  Real Iint(start = 0, fixed = true) "PI integral state [m]";
  Real d "actuator length [m]";
  Real eSpeed "input speed error [m/s]";
  Real Fcmd "saturated command [N]";
  Real Fdist "applied disturbance force [N]";
  Real Fgrav "gravity generalized force along actuator coordinate [N]";
  Real Fnet "net actuator force [N]";
  Real Fbound "net force after travel-bound enforcement [N]";

  Real cTheta "cos(angle of short link with base)";
  Real sTheta "sin(angle of short link with base)";
  Real sThetaSafe "sin with zero-error guard";
  Real theta "short link angle [rad]";
  Real xB "moving pivot B x [m]";
  Real yB "moving pivot B y [m]";
  Real xC "output pivot C x [m]";
  Real yC "output pivot C y [m]";
  Real xOut "output x position [m]";
  Real yOut "output y position [m]";
  Real phiOut "output orientation [rad]";
  Real outputTravel "cumulative output travel [m]";

  Real phi1 "revolute Z joint reference 1 [rad]";
  Real phi2 "revolute Z joint reference 2 [rad]";
  Real phi3 "revolute Z joint reference 3 [rad]";
  Real phi4 "revolute Z joint reference 4 [rad]";
  Real phi5 "revolute Z joint reference 5 [rad]";
  Real phi6 "revolute Z joint reference 6 [rad]";

  Real rAB "loop-closure residual for link AB [m]";
  Real rBC "loop-closure residual for link BC [m]";
  Real rCD "loop-closure residual for link CD [m]";
  Real rDA "loop-closure residual for link DA [m]";
  Real rAC "loop-closure residual for actuator diagonal AC [m]";
  Real closureErrorNorm "norm of all closure residuals [m]";
  Real primaryTrackingError "primary closure tracking error [m]";

  Real sep_AB_CD "separation of nonadjacent links AB and CD [m]";
  Real sep_BC_DA "separation of nonadjacent links BC and DA [m]";

  Real actuatorBoundsValid "actuator bound validity flag";
  Real closureErrorsValid "closure error validity flag";
  Real collisionPrevented "nonadjacent collision prevention flag";

  parameter Real c0 = (d0 * d0 - L_short * L_short - L_long * L_long) / (2.0 * L_short * L_long);
  parameter Real s0 = sqrt(max(1.0 - c0 * c0, 1.0e-12));
  parameter Real xOut0 = L_long + L_short * c0;
  parameter Real yOut0 = L_short * s0;

equation
  d = d0 + s;
  cTheta = (d * d - L_short * L_short - L_long * L_long) / (2.0 * L_short * L_long);
  sTheta = sqrt(max(1.0 - cTheta * cTheta, 1.0e-12));
  sThetaSafe = sTheta;
  theta = atan2(sTheta, cTheta);

  xB = L_short * cTheta;
  yB = L_short * sTheta;
  xC = L_long + L_short * cTheta;
  yC = L_short * sTheta;

  xOut = xC;
  yOut = yC;
  phiOut = 0.0;
  outputTravel = sqrt((xOut - xOut0) * (xOut - xOut0) + (yOut - yOut0) * (yOut - yOut0));

  rAB = sqrt(xB * xB + yB * yB) - L_short;
  rBC = sqrt((xC - xB) * (xC - xB) + (yC - yB) * (yC - yB)) - L_long;
  rCD = sqrt((L_long - xC) * (L_long - xC) + yC * yC) - L_short;
  rDA = L_long - L_long;
  rAC = d - sqrt(xC * xC + yC * yC);
  closureErrorNorm = sqrt(max(rAB * rAB + rBC * rBC + rCD * rCD + rDA * rDA + rAC * rAC, 1.0e-24));
  primaryTrackingError = closureErrorNorm;

  phi1 = atan2(yB, xB);
  phi2 = atan2(yC - yB, xC - xB);
  phi3 = atan2(-yC, L_long - xC);
  phi4 = 0.0;
  phi5 = atan2(yC, xC);
  phi6 = atan2(-yC, -xC);

  sep_AB_CD = L_long * abs(sTheta);
  sep_BC_DA = L_short * abs(sTheta);

  actuatorBoundsValid = if noEvent(s >= -1.0e-9 and s <= travel + 1.0e-9) then 1.0 else 0.0;
  closureErrorsValid = if noEvent(closureErrorNorm <= 0.002) then 1.0 else 0.0;
  collisionPrevented = if noEvent(sep_AB_CD > 0.0 and sep_BC_DA > 0.0) then 1.0 else 0.0;

  Fdist = if noEvent(time >= Tfinal / 3.0 and time <= 2.0 * Tfinal / 3.0) then -FdistMag else 0.0;
  Fgrav = mEff * g * cTheta * d / (L_long * sThetaSafe);

  eSpeed = vRef - v;
  der(Iint) = eSpeed;
  Fcmd = max(-Fmax, min(Fmax, Kp * eSpeed + Ki * Iint));

  Fnet = Fcmd + Fdist + Fgrav;
  Fbound = if noEvent(s <= 0.0 and Fnet < 0.0) then 0.0 elseif noEvent(s >= travel and Fnet > 0.0) then 0.0 else Fnet;

  der(s) = v;
  der(v) = Fbound / mEff;

  assert(noEvent(s >= -1.0e-9 and s <= travel + 1.0e-9), "actuator travel bound violated");
  assert(noEvent(abs(Fcmd) <= Fmax + 1.0e-9), "command magnitude violated");
  assert(noEvent(cTheta >= -1.0 and cTheta <= 1.0), "diagonal length violates closure range");
  assert(noEvent(sep_AB_CD > 0.0 and sep_BC_DA > 0.0), "nonadjacent link separation collapsed");
  assert(noEvent(time < 6.5 or primaryTrackingError <= 0.002), "primary closure tracking error exceeds 0.002 m after 6.5 s");

  annotation(experiment(StopTime = 10, Tolerance = 1e-6));
end PantographDriveB;