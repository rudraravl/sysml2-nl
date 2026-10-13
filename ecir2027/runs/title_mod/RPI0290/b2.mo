model PantographDriveB
  parameter Modelica.SIunits.Length L_short = 0.25 "short parallelogram link length";
  parameter Modelica.SIunits.Length L_long = 0.50 "long parallelogram and fixed base link length";
  parameter Modelica.SIunits.Length travel = 0.16 "prismatic input travel";
  parameter Modelica.SIunits.Length d0 = 0.45 "actuator length at zero input travel";
  parameter Modelica.SIunits.Force Fmax = 262 "allowed command magnitude";
  parameter Modelica.SIunits.Force FdistMag = 5.6 "middle-third load disturbance magnitude";
  parameter Modelica.SIunits.Time Tfinal = 10 "mission duration";
  parameter Modelica.SIunits.Velocity vRef = travel / Tfinal "constant input speed reference";
  parameter Modelica.SIunits.Mass mEff = 10.0 "effective actuator and link inertia";
  parameter Modelica.SIunits.Acceleration g = 9.80665 "gravity acceleration";
  parameter Real Kp = 5000.0 "PI proportional gain";
  parameter Real Ki = 50000.0 "PI integral gain";

  parameter Real c0 = (d0 * d0 - L_short * L_short - L_long * L_long) / (2.0 * L_short * L_long);
  parameter Real s0 = sqrt(max(1.0 - c0 * c0, 1.0e-12));
  parameter Modelica.SIunits.Position xOut0 = L_long + L_short * c0;
  parameter Modelica.SIunits.Position yOut0 = L_short * s0;

  Modelica.SIunits.Length s(start = 0.0, fixed = true) "input travel coordinate";
  Modelica.SIunits.Velocity v(start = 0.0, fixed = true) "input speed";
  Real Iint(start = 0.0, fixed = true) "PI integral state";

  Modelica.SIunits.Length d "actuator length";
  Real cTheta "cos of short link angle";
  Real sTheta "sin of short link angle";
  Modelica.SIunits.Angle theta "short link angle";
  Modelica.SIunits.Position xB "moving pivot B x";
  Modelica.SIunits.Position yB "moving pivot B y";
  Modelica.SIunits.Position xC "output pivot C x";
  Modelica.SIunits.Position yC "output pivot C y";
  Modelica.SIunits.Position xOut "output x position";
  Modelica.SIunits.Position yOut "output y position";
  Modelica.SIunits.Angle phiOut "output orientation";
  Modelica.SIunits.Length outputTravel "cumulative output travel";

  Modelica.SIunits.Velocity eSpeed "input speed error";
  Modelica.SIunits.Force FcmdUnsat "unsaturated PI command";
  Modelica.SIunits.Force Fcmd "saturated command";
  Modelica.SIunits.Force Fdist "applied disturbance force";
  Modelica.SIunits.Force Fgrav "gravity generalized force";
  Modelica.SIunits.Force Fnet "net actuator force";
  Modelica.SIunits.Force FnetBounded "net force after travel-bound enforcement";

  Modelica.SIunits.Angle phi1 "revolute Z joint 1";
  Modelica.SIunits.Angle phi2 "revolute Z joint 2";
  Modelica.SIunits.Angle phi3 "revolute Z joint 3";
  Modelica.SIunits.Angle phi4 "revolute Z joint 4";
  Modelica.SIunits.Angle phi5 "revolute Z joint 5";
  Modelica.SIunits.Angle phi6 "revolute Z joint 6";

  Modelica.SIunits.Length rAB "loop-closure residual AB";
  Modelica.SIunits.Length rBC "loop-closure residual BC";
  Modelica.SIunits.Length rCD "loop-closure residual CD";
  Modelica.SIunits.Length rDA "loop-closure residual DA";
  Modelica.SIunits.Length rAC "loop-closure residual AC";
  Modelica.SIunits.Length closureErrorNorm "norm of all closure residuals";
  Modelica.SIunits.Length primaryTrackingError "primary tracking error";

  Modelica.SIunits.Length sep_AB_CD "separation of nonadjacent links AB and CD";
  Modelica.SIunits.Length sep_BC_DA "separation of nonadjacent links BC and DA";

  Real speedBandValid "speed band validity";
  Real actuatorBoundsValid "actuator bound validity";
  Real closureErrorsValid "closure error validity";
  Real collisionPrevented "nonadjacent collision prevention flag";
  Real jointRefsValid "joint reference validity";
  Real finiteCheckValid "finite-value check";

equation
  d = d0 + s;
  cTheta = (d * d - L_short * L_short - L_long * L_long) / (2.0 * L_short * L_long);
  sTheta = sqrt(max(1.0 - cTheta * cTheta, 1.0e-12));
  theta = atan2(sTheta, cTheta);

  xB = L_short * cTheta;
  yB = L_short * sTheta;
  xC = L_long + L_short * cTheta;
  yC = L_short * sTheta;

  xOut = xC;
  yOut = yC;
  phiOut = 0.0;
  outputTravel = sqrt(max((xOut - xOut0) * (xOut - xOut0) + (yOut - yOut0) * (yOut - yOut0), 0.0));

  rAB = sqrt(max(xB * xB + yB * yB, 0.0)) - L_short;
  rBC = sqrt(max((xC - xB) * (xC - xB) + (yC - yB) * (yC - yB), 0.0)) - L_long;
  rCD = sqrt(max((L_long - xC) * (L_long - xC) + yC * yC, 0.0)) - L_short;
  rDA = sqrt(max(L_long * L_long, 0.0)) - L_long;
  rAC = d - sqrt(max(xC * xC + yC * yC, 0.0));
  closureErrorNorm = sqrt(max(rAB * rAB + rBC * rBC + rCD * rCD + rDA * rDA + rAC * rAC, 0.0));
  primaryTrackingError = closureErrorNorm;

  phi1 = atan2(yB, xB);
  phi2 = atan2(yC - yB, xC - xB);
  phi3 = atan2(-yC, L_long - xC);
  phi4 = Modelica.Constants.pi;
  phi5 = atan2(yC, xC);
  phi6 = atan2(-yC, -xC);

  sep_AB_CD = L_long * sTheta;
  sep_BC_DA = L_short * sTheta;

  speedBandValid = if v >= -1.0e-6 and v <= vRef + 1.0e-6 then 1.0 else 0.0;
  actuatorBoundsValid = if s >= -1.0e-9 and s <= travel + 1.0e-9 then 1.0 else 0.0;
  closureErrorsValid = if closureErrorNorm <= 0.002 then 1.0 else 0.0;
  collisionPrevented = if sep_AB_CD > 0.0 and sep_BC_DA > 0.0 then 1.0 else 0.0;
  jointRefsValid = 1.0;
  finiteCheckValid = if abs(s) < 1.0e6 and abs(v) < 1.0e6 and abs(Fcmd) < 1.0e6 and abs(Iint) < 1.0e6 then 1.0 else 0.0;

  Fdist = if time >= Tfinal / 3.0 and time <= 2.0 * Tfinal / 3.0 then -FdistMag else 0.0;
  Fgrav = mEff * g * cTheta * d / (L_long * max(sTheta, 1.0e-12));

  eSpeed = vRef - v;
  FcmdUnsat = Kp * eSpeed + Ki * Iint;
  der(Iint) = if FcmdUnsat > Fmax and eSpeed > 0.0 then 0.0
    elseif FcmdUnsat < -Fmax and eSpeed < 0.0 then 0.0
    else eSpeed;
  Fcmd = max(-Fmax, min(Fmax, FcmdUnsat));

  Fnet = Fcmd + Fdist + Fgrav;
  FnetBounded = if s <= 0.0 and Fnet < 0.0 then 0.0
    elseif s >= travel and Fnet > 0.0 then 0.0
    else Fnet;
  der(s) = v;
  der(v) = FnetBounded / mEff;

  assert(s >= -1.0e-9 and s <= travel + 1.0e-9, "actuator travel bound violated");
  assert(abs(Fcmd) <= Fmax + 1.0e-9, "command magnitude violated");
  assert(cTheta >= -1.0 and cTheta <= 1.0, "diagonal length violates closure range");
  assert(sep_AB_CD > 0.0 and sep_BC_DA > 0.0, "nonadjacent link separation collapsed");
  assert(time < 6.5 or primaryTrackingError <= 0.002, "primary tracking error exceeds 0.002 m after 6.5 s");
  assert(finiteCheckValid > 0.5, "non-finite value detected");

  annotation (experiment(StopTime = 10, Tolerance = 1e-6));
end PantographDriveB;