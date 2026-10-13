model FourBarDriveB
  "Closed-chain four-bar mechanism with PI speed control, torque saturation, disturbance, and sensors."

  // Stated geometry
  parameter Modelica.SIunits.Length L0 = 0.50 "fixed pivot separation";
  parameter Modelica.SIunits.Length L1 = 0.20 "crank length";
  parameter Modelica.SIunits.Length L2 = 0.44 "coupler length";
  parameter Modelica.SIunits.Length L3 = 0.35 "rocker length";

  // Stated control and disturbance limits
  parameter Modelica.SIunits.Torque tauMax = 20.5 "allowed command magnitude";
  parameter Modelica.SIunits.Torque distTorque = 5.6 "middle-third load disturbance magnitude";
  parameter Modelica.SIunits.Time tStart = 10/3 "start of middle third";
  parameter Modelica.SIunits.Time tStop = 20/3 "end of middle third";
  parameter Modelica.SIunits.Length closureTol = 0.002 "primary closure tolerance after 6.5 s";

  // Unknown but bound placeholders required for simulation/FMU generation
  parameter Modelica.SIunits.AngularVelocity omega_ref = 0.30 "unknown constant speed setpoint placeholder";
  parameter Modelica.SIunits.AngularVelocity speedBand = 0.10 "unknown speed band placeholder";
  parameter Real kp = 20.0 "unknown PI gain placeholder";
  parameter Modelica.SIunits.Time Ti = 0.05 "unknown PI time constant placeholder";
  parameter Modelica.SIunits.Density linkDensity = 1000.0 "unknown link density placeholder";
  parameter Modelica.SIunits.Length linkWidth = 0.02 "unknown link cross-section width/height placeholder";
  parameter Modelica.SIunits.Angle theta1_start = 0.5 "unknown initial crank angle placeholder";
  parameter Modelica.SIunits.Angle theta3_start = 1.4672 "matching initial rocker guess for theta1_start";
  parameter Modelica.SIunits.Angle theta2_start = 0.6092 "matching initial coupler guess for theta1_start";
  parameter Modelica.SIunits.Time sampleDt = 0.01 "100 Hz synchronized trace period";

  inner Modelica.Mechanics.MultiBody.World world(
    gravityType = Modelica.Mechanics.MultiBody.Types.GravityTypes.UniformGravity,
    g = 9.81,
    n = {0,-1,0});

  Modelica.Mechanics.MultiBody.Parts.Fixed fixedA(r = {0,0,0});
  Modelica.Mechanics.MultiBody.Parts.Fixed fixedD(r = {L0,0,0});

  Modelica.Mechanics.MultiBody.Joints.Revolute revA(
    axis = {0,0,1},
    stateSelect = StateSelect.always,
    angle(start = theta1_start, fixed = true),
    w(start = omega_ref, fixed = true));

  Modelica.Mechanics.MultiBody.Parts.BodyBox crank(
    r = {L1,0,0},
    width = linkWidth,
    height = linkWidth,
    density = linkDensity);

  Modelica.Mechanics.MultiBody.Joints.Revolute revB(
    axis = {0,0,1},
    stateSelect = StateSelect.prefer,
    angle(start = theta2_start - theta1_start));

  Modelica.Mechanics.MultiBody.Parts.BodyBox coupler(
    r = {L2,0,0},
    width = linkWidth,
    height = linkWidth,
    density = linkDensity);

  Modelica.Mechanics.MultiBody.Joints.RevolutePlanarLoopConstraint revC(axis = {0,0,1});

  Modelica.Mechanics.MultiBody.Parts.BodyBox rocker(
    r = {L3,0,0},
    width = linkWidth,
    height = linkWidth,
    density = linkDensity);

  Modelica.Mechanics.MultiBody.Joints.Revolute revD(
    axis = {0,0,1},
    stateSelect = StateSelect.prefer,
    angle(start = theta3_start));

  Modelica.Mechanics.Rotational.Sources.Torque torqueA(useSupport = true);
  Modelica.Mechanics.Rotational.Sources.Torque torqueD(useSupport = true);

  // Continuous and sampled observables
  Real tauCmd;
  Real tauDist;
  Boolean distActive;
  Boolean collisionOk;

  Real theta1 = revA.angle;
  Real theta3 = revD.angle;
  Real theta2 = revA.angle + revB.angle;

  Real Bx = L1*Modelica.Math.cos(theta1);
  Real By = L1*Modelica.Math.sin(theta1);
  Real Cx = L0 + L3*Modelica.Math.cos(theta3);
  Real Cy = L3*Modelica.Math.sin(theta3);

  Real resX = Bx + L2*Modelica.Math.cos(theta2) - Cx;
  Real resY = By + L2*Modelica.Math.sin(theta2) - Cy;
  Real closureNorm = Modelica.Math.sqrt(resX*resX + resY*resY);
  Real lengthRes = Modelica.Math.sqrt((Cx - Bx)*(Cx - Bx) + (Cy - By)*(Cy - By)) - L2;

  Real outPoseX = Cx;
  Real outPoseY = Cy;
  Real outPoseAngleWrapped = Modelica.Math.atan2(Modelica.Math.sin(theta3), Modelica.Math.cos(theta3));
  Real outputTravel = abs(theta3 - theta3_start);

  Real jointRefA = theta1;
  Real jointRefB = revB.angle;
  Real jointRefC = theta2 - theta3;
  Real jointRefD = theta3;

  Real actuatorTorqueValid;
  Real speedBandValid;
  Real closureValid;
  Real primaryTrackingValid;
  Real jointReferencesValid;
  Real collisionOkReal;

  Real sensorAngleA(start = theta1_start);
  Real sensorOmegaA(start = omega_ref);
  Real sensorTauCmd(start = 0.0);
  Real sensorSpeedError(start = 0.0);
  Real sensorOutAngle(start = theta3_start);
  Real sensorOutAngleWrapped(start = theta3_start);
  Real sensorOutPoseX(start = 0.0);
  Real sensorOutPoseY(start = 0.0);
  Real sensorOutputTravel(start = 0.0);
  Real sensorResX(start = 0.0);
  Real sensorResY(start = 0.0);
  Real sensorClosureNorm(start = 0.0);
  Real sensorLengthRes(start = 0.0);
  Real sensorCollisionOk(start = 1.0);
  Real sensorDistActive(start = 0.0);

  Modelica.Blocks.Sources.Constant omegaRef(k = omega_ref);
  Modelica.Blocks.Sources.RealExpression crankSpeed(y = revA.w);
  Modelica.Blocks.Math.Feedback speedError;
  Modelica.Blocks.Continuous.PI speedPI(
    k = kp,
    T = Ti,
    initType = Modelica.Blocks.Types.Init.InitialState);
  Modelica.Blocks.Nonlinear.Limiter lim(uMax = tauMax, uMin = -tauMax);
  Modelica.Blocks.Sources.RealExpression tauDistExpr(y = tauDist);

protected
  function segIntersect
    "Planar segment intersection test for nonadjacent centerline collision monitoring."
    input Real p1x;
    input Real p1y;
    input Real p2x;
    input Real p2y;
    input Real p3x;
    input Real p3y;
    input Real p4x;
    input Real p4y;
    output Boolean intersect;
  protected
    Real d1 = (p4x - p3x)*(p1y - p3y) - (p4y - p3y)*(p1x - p3x);
    Real d2 = (p4x - p3x)*(p2y - p3y) - (p4y - p3y)*(p2x - p3x);
    Real d3 = (p2x - p1x)*(p3y - p1y) - (p2y - p1y)*(p3x - p1x);
    Real d4 = (p2x - p1x)*(p4y - p1y) - (p2y - p1y)*(p4x - p1x);
  algorithm
    if ((d1 > 0.0 and d2 < 0.0) or (d1 < 0.0 and d2 > 0.0)) and
       ((d3 > 0.0 and d4 < 0.0) or (d3 < 0.0 and d4 > 0.0)) then
      intersect := true;
    else
      intersect := false;
    end if;
  end segIntersect;

equation
  // Kinematic loop
  connect(fixedA.frame_b, revA.frame_a);
  connect(revA.frame_b, crank.frame_a);
  connect(crank.frame_b, revB.frame_a);
  connect(revB.frame_b, coupler.frame_a);
  connect(coupler.frame_b, revC.frame_b);
  connect(revC.frame_a, rocker.frame_b);
  connect(rocker.frame_a, revD.frame_b);
  connect(revD.frame_a, fixedD.frame_b);

  // Actuation and disturbance
  connect(torqueA.support, revA.flange_a);
  connect(torqueA.flange, revA.flange_b);
  connect(torqueD.support, revD.flange_a);
  connect(torqueD.flange, revD.flange_b);

  // PI speed control with command saturation
  connect(omegaRef.y, speedError.u1);
  connect(crankSpeed.y, speedError.u2);
  connect(speedError.y, speedPI.u);
  connect(speedPI.y, lim.u);
  connect(lim.y, torqueA.tau);
  connect(tauDistExpr.y, torqueD.tau);

  // Command and disturbance
  tauCmd = lim.y;
  distActive = time >= tStart and time <= tStop;
  tauDist = if distActive then -distTorque else 0.0;

  // Nonadjacent centerline collision prevention flag:
  // ground-coupler and crank-rocker pairs.
  collisionOk = not segIntersect(0.0,0.0,L0,0.0,Bx,By,Cx,Cy) and
                not segIntersect(0.0,0.0,Bx,By,L0,0.0,Cx,Cy);

  // Requirement observables
  actuatorTorqueValid = if abs(tauCmd) <= tauMax + 1.0e-6 then 1.0 else 0.0;
  speedBandValid = if abs(revA.w - omega_ref) <= speedBand then 1.0 else 0.0;
  closureValid = if closureNorm <= closureTol then 1.0 else 0.0;
  primaryTrackingValid = if time > 6.5 then (if closureNorm <= closureTol then 1.0 else 0.0) else 1.0;
  jointReferencesValid = 1.0 "no joint reference limits or estimator architecture were stated";
  collisionOkReal = if collisionOk then 1.0 else 0.0;

  // Synchronized 100 Hz state, command, and sensor traces
  when sample(0, sampleDt) then
    sensorAngleA = revA.angle;
    sensorOmegaA = revA.w;
    sensorTauCmd = tauCmd;
    sensorSpeedError = revA.w - omega_ref;
    sensorOutAngle = revD.angle;
    sensorOutAngleWrapped = outPoseAngleWrapped;
    sensorOutPoseX = outPoseX;
    sensorOutPoseY = outPoseY;
    sensorOutputTravel = outputTravel;
    sensorResX = resX;
    sensorResY = resY;
    sensorClosureNorm = closureNorm;
    sensorLengthRes = lengthRes;
    sensorCollisionOk = if collisionOk then 1.0 else 0.0;
    sensorDistActive = if distActive then 1.0 else 0.0;
  end when;

  assert(abs(tauCmd) <= tauMax + 1.0e-6, "Actuator command exceeds allowed magnitude");
  assert(collisionOk, "Nonadjacent link collision detected");
  assert(time <= 6.5 or closureNorm <= closureTol, "Primary closure/tracking error exceeds 0.002 m after 6.5 s");

  annotation (
    experiment(StopTime = 10, Interval = 0.01, Tolerance = 1.0e-6),
    uses(Modelica(version = "4.0.0")));
end FourBarDriveB;