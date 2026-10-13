model FourBarPositionE
  "Closed-chain four-bar mechanism: position control, bounded load, verification"
  extends Modelica.Icons.Example;

  // ===== Mechanism parameters =====
  parameter Modelica.Units.SI.Length a=0.20 "Crank length [m]";
  parameter Modelica.Units.SI.Length b=0.44 "Coupler length [m]";
  parameter Modelica.Units.SI.Length c=0.35 "Rocker length [m]";
  parameter Modelica.Units.SI.Length d=0.50 "Ground pivot separation [m]";
  parameter Modelica.Units.SI.Mass mCrank=1.0 "Crank mass [kg]";
  parameter Modelica.Units.SI.Mass mCoupler=2.0 "Coupler mass [kg]";
  parameter Modelica.Units.SI.Mass mRocker=1.0 "Rocker mass [kg]";

  // ===== Control parameters =====
  parameter Modelica.Units.SI.Torque tauMax=27.5 "Max torque magnitude [N.m]";
  parameter Real Kp=300.0 "Position gain [N.m/rad]";
  parameter Real Kd=20.0 "Velocity gain [N.m.s/rad]";
  parameter Modelica.Units.SI.Angle thetaDesired=1.0 "Desired nonzero crank angle [rad]";
  parameter Modelica.Units.SI.Time tRamp=5.0 "Smooth ramp duration [s]";
  parameter Modelica.Units.SI.Time tSettle=10.4 "Settling acceptance time [s]";
  parameter Modelica.Units.SI.Length poseTol=0.005 "Pose error tolerance [m]";

  // ===== Load =====
  parameter Modelica.Units.SI.Force Fload=16.8 "Platform load magnitude [N]";

  // ===== Collision =====
  parameter Modelica.Units.SI.Length linkWidth=0.02 "Link half-width for collision [m]";

  // ===== World =====
  inner Modelica.Mechanics.MultiBody.World world(
    enableAnimation=false,
    g=9.81,
    n={0,0,-1})
    annotation(Placement(transformation(extent={{-180,60},{-160,80}})));

  // ===== Ground link =====
  Modelica.Mechanics.MultiBody.Parts.FixedTranslation groundLink(
    r={d,0,0},
    animation=false)
    annotation(Placement(transformation(extent={{40,-50},{60,-30}})));

  // ===== Crank revolute joint (driven) =====
  Modelica.Mechanics.MultiBody.Joints.Revolute crankJoint(
    n={0,0,1},
    useAxisFlange=true,
    animation=false,
    phi(fixed=true, start=0),
    w(fixed=true, start=0))
    annotation(Placement(transformation(extent={{-80,20},{-60,40}})));

  // ===== Crank body =====
  Modelica.Mechanics.MultiBody.Parts.BodyShape crankBody(
    r={a,0,0},
    r_CM={a/2,0,0},
    m=mCrank,
    I_11=1e-4,
    I_22=1e-4,
    I_33=mCrank*a*a/12,
    animation=false)
    annotation(Placement(transformation(extent={{-40,20},{-20,40}})));

  // ===== Pin joint 1 (crank-coupler) =====
  Modelica.Mechanics.MultiBody.Joints.Revolute pin1(
    n={0,0,1},
    animation=false,
    phi(start=0.915),
    w(start=0))
    annotation(Placement(transformation(extent={{0,20},{20,40}})));

  // ===== Coupler body (output platform) =====
  Modelica.Mechanics.MultiBody.Parts.BodyShape couplerBody(
    r={b,0,0},
    r_CM={b/2,0,0},
    m=mCoupler,
    I_11=1e-4,
    I_22=1e-4,
    I_33=mCoupler*b*b/12,
    animation=false)
    annotation(Placement(transformation(extent={{40,20},{60,40}})));

  // ===== Pin joint 2 (coupler-rocker) =====
  Modelica.Mechanics.MultiBody.Joints.Revolute pin2(
    n={0,0,1},
    animation=false,
    phi(start=-2.395),
    w(start=0))
    annotation(Placement(transformation(extent={{80,20},{100,40}})));

  // ===== Rocker body =====
  Modelica.Mechanics.MultiBody.Parts.BodyShape rockerBody(
    r={c,0,0},
    r_CM={c/2,0,0},
    m=mRocker,
    I_11=1e-4,
    I_22=1e-4,
    I_33=mRocker*c*c/12,
    animation=false)
    annotation(Placement(transformation(extent={{80,-20},{60,-40}})));

  // ===== Rocker joint — planar loop constraint (cut joint) =====
  Modelica.Mechanics.MultiBody.Joints.RevolutePlanarLoopConstraint rockerJoint(
    n={0,0,1},
    animation=false,
    phi(start=1.48),
    w(start=0))
    annotation(Placement(transformation(extent={{20,-40},{0,-20}})));

  // ===== Crank torque actuator =====
  Modelica.Mechanics.Rotational.Sources.Torque crankTorque(useSupport=false)
    annotation(Placement(transformation(extent={{-80,60},{-60,80}})));

  // ===== Coupler midpoint for load application =====
  Modelica.Mechanics.MultiBody.Parts.FixedTranslation couplerMid(
    r={b/2,0,0},
    animation=false)
    annotation(Placement(transformation(extent={{40,60},{60,80}})));

  // ===== Platform load (16.8 N downward in Y) =====
  Modelica.Mechanics.MultiBody.Forces.WorldForce platformLoad(animation=false)
    annotation(Placement(transformation(extent={{80,60},{100,80}})));

  // ===== Actuator coordinates (observable) =====
  Modelica.Units.SI.Angle theta "Crank angle [rad]";
  Modelica.Units.SI.AngularVelocity omega "Crank angular velocity [rad/s]";

  // ===== Forward kinematics variables =====
  Real P1x "Crank end X [m]";
  Real P1y "Crank end Y [m]";
  Real P2x "Coupler-rocker pin X [m]";
  Real P2y "Coupler-rocker pin Y [m]";
  Real L "Distance P1 to rocker pivot [m]";
  Real cosAlpha "Cosine of coupler interior angle at P1";
  Real sinAlpha "Sine of coupler interior angle at P1";
  Real phiDir "Direction from P1 to P3 [rad]";
  Real couplerAngle "Coupler orientation [rad]";
  Real rockerAngle "Rocker angle from P3 to P2 [rad]";
  Real outputPoseX "Output platform center X [m]";
  Real outputPoseY "Output platform center Y [m]";
  Real outputPoseTheta "Output platform orientation [rad]";

  // ===== Controller variables =====
  Real thetaRef "Reference crank angle [rad]";
  Real dthetaRef "Reference angular velocity [rad/s]";
  Real thetaErr "Tracking error [rad]";
  Real tauCmd "Unsaturated torque command [N.m]";
  Real tauSat "Saturated torque applied [N.m]";

  // ===== Desired output pose variables =====
  Real desP1x "Desired crank end X [m]";
  Real desP1y "Desired crank end Y [m]";
  Real desL "Desired distance P1 to P3 [m]";
  Real desCosAlpha "Desired coupler angle cosine";
  Real desSinAlpha "Desired coupler angle sine";
  Real desPhiDir "Desired direction P1 to P3 [rad]";
  Real desCouplerAngle "Desired coupler orientation [rad]";
  Real desOutputX "Desired output X [m]";
  Real desOutputY "Desired output Y [m]";
  Real poseError "Output pose error norm [m]";

  // ===== Closure residual =====
  Real closureResX "Loop closure residual X [m]";
  Real closureResY "Loop closure residual Y [m]";
  Real closureResidual "Loop closure residual norm [m]";

  // ===== Reaction force computation =====
  Real D_R "Determinant for reaction force 2x2 system";
  Real F_R "Rocker axial force magnitude [N]";

  // ===== Collision =====
  Real minDistCrankRocker "Min distance crank segment to rocker segment [m]";
  Real minDistCouplerGround "Min distance coupler segment to ground segment [m]";
  Boolean selfCollision "Self-collision detected";

  // ===== Reaction forces (observable) =====
  Real fCrankX "Crank pivot reaction force X [N]";
  Real fCrankY "Crank pivot reaction force Y [N]";
  Real fRockerX "Rocker pivot reaction force X [N]";
  Real fRockerY "Rocker pivot reaction force Y [N]";

  // ===== Health / acceptance =====
  Boolean noNaN "No NaN or Inf in physical, control, or estimator values";
  Boolean torqueBounded "Applied torque within +/- tauMax";
  Boolean travelBounded "Crank travel within non-singular mechanism range";
  Boolean poseAccepted "Pose error below tolerance after settle time";
  Boolean acceptance "Fail-closed overall acceptance";

protected
  function isFinite
    "Returns true if x is finite (not NaN, not Inf)"
    input Real x;
    output Boolean y;
  algorithm
    y := (x == x) and (abs(x) < 1e100);
  end isFinite;

  function pointSegDist
    "Minimum distance from point (px,py) to segment (ax,ay)-(bx,by)"
    input Real px;
    input Real py;
    input Real ax;
    input Real ay;
    input Real bx;
    input Real by;
    output Real dist;
  protected
    Real t;
    Real lenSq;
  algorithm
    lenSq := (bx - ax)*(bx - ax) + (by - ay)*(by - ay);
    if lenSq < 1e-12 then
      dist := sqrt((px - ax)*(px - ax) + (py - ay)*(py - ay));
    else
      t := ((px - ax)*(bx - ax) + (py - ay)*(by - ay)) / lenSq;
      if t < 0 then
        t := 0;
      elseif t > 1 then
        t := 1;
      end if;
      dist := sqrt((px - ax - t*(bx - ax))*(px - ax - t*(bx - ax)) + (py - ay - t*(by - ay))*(py - ay - t*(by - ay)));
    end if;
  end pointSegDist;

  function segDist
    "Minimum distance between segments (x1,y1)-(x2,y2) and (x3,y3)-(x4,y4)"
    input Real x1;
    input Real y1;
    input Real x2;
    input Real y2;
    input Real x3;
    input Real y3;
    input Real x4;
    input Real y4;
    output Real dist;
  protected
    Real d1;
    Real d2;
    Real d3;
    Real d4;
  algorithm
    d1 := pointSegDist(x1, y1, x3, y3, x4, y4);
    d2 := pointSegDist(x2, y2, x3, y3, x4, y4);
    d3 := pointSegDist(x3, y3, x1, y1, x2, y2);
    d4 := pointSegDist(x4, y4, x1, y1, x2, y2);
    dist := min(d1, min(d2, min(d3, d4)));
  end segDist;

equation
  // ===== Actuator coordinates =====
  theta = crankJoint.phi;
  omega = crankJoint.w;

  // ===== Analytical forward kinematics from crank angle =====
  P1x = a * cos(theta);
  P1y = a * sin(theta);
  L = sqrt((d - P1x)*(d - P1x) + P1y*P1y);
  cosAlpha = max(-1.0, min(1.0, (b*b + L*L - c*c) / (2.0 * b * max(L, 1e-9))));
  sinAlpha = sqrt(max(1.0 - cosAlpha*cosAlpha, 0.0));
  phiDir = atan2(-P1y, d - P1x);
  P2x = P1x + b * (cos(phiDir)*cosAlpha - sin(phiDir)*sinAlpha);
  P2y = P1y + b * (sin(phiDir)*cosAlpha + cos(phiDir)*sinAlpha);
  couplerAngle = phiDir + atan2(sinAlpha, cosAlpha);
  rockerAngle = atan2(P2y, P2x - d);
  outputPoseX = P1x + (b/2.0) * cos(couplerAngle);
  outputPoseY = P1y + (b/2.0) * sin(couplerAngle);
  outputPoseTheta = couplerAngle;

  // ===== Reference trajectory: smooth ramp then hold =====
  if time <= tRamp then
    thetaRef = thetaDesired * (time/tRamp - 1.0/(2.0*Modelica.Constants.pi) *
      sin(2.0*Modelica.Constants.pi*time/tRamp));
    dthetaRef = thetaDesired/tRamp * (1.0 - cos(2.0*Modelica.Constants.pi*time/tRamp));
  else
    thetaRef = thetaDesired;
    dthetaRef = 0.0;
  end if;

  // ===== Desired output pose via constrained inverse kinematics =====
  desP1x = a * cos(thetaRef);
  desP1y = a * sin(thetaRef);
  desL = sqrt((d - desP1x)*(d - desP1x) + desP1y*desP1y);
  desCosAlpha = max(-1.0, min(1.0, (b*b + desL*desL - c*c) / (2.0 * b * max(desL, 1e-9))));
  desSinAlpha = sqrt(max(1.0 - desCosAlpha*desCosAlpha, 0.0));
  desPhiDir = atan2(-desP1y, d - desP1x);
  desCouplerAngle = desPhiDir + atan2(desSinAlpha, desCosAlpha);
  desOutputX = desP1x + (b/2.0) * cos(desCouplerAngle);
  desOutputY = desP1y + (b/2.0) * sin(desCouplerAngle);

  // ===== Pose error =====
  poseError = sqrt((outputPoseX - desOutputX)*(outputPoseX - desOutputX) +
    (outputPoseY - desOutputY)*(outputPoseY - desOutputY));

  // ===== PD controller with torque saturation =====
  thetaErr = thetaRef - theta;
  tauCmd = Kp * thetaErr + Kd * (dthetaRef - omega);
  if tauCmd > tauMax then
    tauSat = tauMax;
  elseif tauCmd < -tauMax then
    tauSat = -tauMax;
  else
    tauSat = tauCmd;
  end if;

  // ===== Actuator and load inputs =====
  crankTorque.tau = tauSat;
  platformLoad.force = {0, -Fload, 0};

  // ===== Loop closure residual =====
  closureResX = P2x - (d - c * cos(rockerJoint.phi));
  closureResY = P2y - c * sin(rockerJoint.phi);
  closureResidual = sqrt(closureResX*closureResX + closureResY*closureResY);

  // ===== Reaction forces (quasi-static, from torque and load balance) =====
  D_R = P1x * P2y + P1y * (d - P2x);
  F_R = if abs(D_R) > 1e-9 then (-tauSat - P1x * Fload) * c / D_R else 0.0;
  fCrankX = F_R * (d - P2x) / max(c, 1e-9);
  fCrankY = -F_R * P2y / max(c, 1e-9) - Fload;
  fRockerX = -F_R * (d - P2x) / max(c, 1e-9);
  fRockerY = F_R * P2y / max(c, 1e-9);

  // ===== Self-collision checks between link segments =====
  minDistCrankRocker = segDist(0, 0, P1x, P1y, d, 0, P2x, P2y);
  minDistCouplerGround = segDist(P1x, P1y, P2x, P2y, 0, 0, d, 0);
  selfCollision = (minDistCrankRocker < linkWidth) or (minDistCouplerGround < linkWidth);

  // ===== Health checks =====
  noNaN = isFinite(theta) and isFinite(omega) and isFinite(tauSat) and
    isFinite(poseError) and isFinite(outputPoseX) and isFinite(outputPoseY) and
    isFinite(closureResidual) and isFinite(fCrankX) and isFinite(fRockerX) and
    isFinite(tauCmd) and isFinite(fCrankY) and isFinite(fRockerY) and
    isFinite(rockerJoint.phi);
  torqueBounded = abs(tauSat) <= tauMax + 1e-6;
  travelBounded = (L > 0.1) and (abs(cosAlpha) < 0.99);
  poseAccepted = if time >= tSettle then poseError < poseTol else true;

  // Fail-closed acceptance
  acceptance = noNaN and torqueBounded and travelBounded and poseAccepted and
    (not selfCollision) and (closureResidual < 1e-6);

  // ===== Connections: closed kinematic chain =====
  connect(world.frame_b, crankJoint.frame_a)
    annotation(Line(points={{-160,70},{-80,30}}, color={95,95,95}));
  connect(crankJoint.frame_b, crankBody.frame_a)
    annotation(Line(points={{-60,30},{-40,30}}, color={95,95,95}));
  connect(crankBody.frame_b, pin1.frame_a)
    annotation(Line(points={{-20,30},{0,30}}, color={95,95,95}));
  connect(pin1.frame_b, couplerBody.frame_a)
    annotation(Line(points={{20,30},{40,30}}, color={95,95,95}));
  connect(couplerBody.frame_b, pin2.frame_a)
    annotation(Line(points={{60,30},{80,30}}, color={95,95,95}));
  connect(pin2.frame_b, rockerBody.frame_a)
    annotation(Line(points={{100,30},{100,-30},{80,-30}}, color={95,95,95}));
  connect(rockerBody.frame_b, rockerJoint.frame_a)
    annotation(Line(points={{60,-30},{20,-30}}, color={95,95,95}));
  connect(rockerJoint.frame_b, groundLink.frame_b)
    annotation(Line(points={{0,-30},{40,-30},{40,-40},{60,-40}}, color={95,95,95}));
  connect(groundLink.frame_a, world.frame_b)
    annotation(Line(points={{40,-40},{-170,-40},{-170,70},{-160,70}}, color={95,95,95}));

  // ===== Torque flange connection =====
  connect(crankTorque.flange, crankJoint.flange_a)
    annotation(Line(points={{-60,70},{-60,40},{-70,40}}, color={0,0,0}));

  // ===== Coupler midpoint load application =====
  connect(couplerBody.frame_a, couplerMid.frame_a)
    annotation(Line(points={{40,30},{40,70}}, color={95,95,95}));
  connect(couplerMid.frame_b, platformLoad.frame_b)
    annotation(Line(points={{60,70},{80,70}}, color={95,95,95}));

  annotation(
    Documentation(info="<html>
<p>Four-bar closed-chain robotic mechanism with position control, bounded load, and verification.</p>
<ul>
<li>Ground pivots 0.50 m apart, crank 0.20 m, coupler 0.44 m, rocker 0.35 m</li>
<li>Four revolute Z joints (three Revolute + one RevolutePlanarLoopConstraint)</li>
<li>Bounded crank torque (|tau| &le; 27.5 N.m) via PD controller with saturation</li>
<li>16.8 N platform load at coupler middle-third center, applied in -Y</li>
<li>Smooth ramp reference to 1.0 rad crank angle then hold</li>
<li>Self-collision checks between crank/rocker and coupler/ground segments</li>
<li>Loop closure residual, pose error, reaction force, and NaN/Inf health monitors</li>
<li>Fail-closed acceptance: pose error &lt; 0.005 m after 10.4 s, no collision, bounded torque</li>
</ul>
<p>Run at 250 Hz for 16 s (experiment StopTime=16, Interval=0.004).</p>
</html>"),
    experiment(StopTime=16, Interval=0.004, Tolerance=1e-6));
end FourBarPositionE;