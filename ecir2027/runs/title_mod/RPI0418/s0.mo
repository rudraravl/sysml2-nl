model PlanarPusherInsertD

  function clamp "Scalar saturation"
    input Real x;
    input Real lo;
    input Real hi;
    output Real y;
  algorithm
    y := if x < lo then lo elseif x > hi then hi else x;
  end clamp;

  function smoothStep "C1 smooth unit step on [0,1]"
    input Real u;
    output Real y;
  algorithm
    if u <= 0.0 then
      y := 0.0;
    elseif u >= 1.0 then
      y := 1.0;
    else
      y := u*u*u*(10.0 - 15.0*u + 6.0*u*u);
    end if;
  end smoothStep;

  function regSign "Regularized sign with finite zero branch"
    input Real x;
    input Real eps;
    output Real y;
  algorithm
    if x > eps then
      y := 1.0;
    elseif x < -eps then
      y := -1.0;
    else
      y := x/eps;
    end if;
  end regSign;

  // Embodiment parameters (all SI)
  parameter Real L1 = 0.46 "m, first capsule link length";
  parameter Real L2 = 0.35 "m, second capsule link length";
  parameter Real radialClearance = 0.001 "m, radial peg-hole clearance";
  parameter Real insertionTarget = 0.06 "m, required insertion depth";
  parameter Real mu = 0.35 "contact friction coefficient";
  parameter Real tauMax = 50.0 "N.m, per-joint torque limit";

  // Mission timing and controller rate
  parameter Real Ts = 0.005 "s, 200 Hz control/sample period";
  parameter Real runTime = 14.0 "s";
  parameter Real tAlign = 9.1 "s, alignment deadline";
  parameter Real tDistStart = 14.0/3.0 "s, middle third start";
  parameter Real tDistEnd = 28.0/3.0 "s, middle third end";
  parameter Real disturbanceForce = 10.0 "N, lateral fixture load";

  // Insertion speed bound: selected to complete 0.001 m approach plus 0.06 m insertion after 9.1 s
  parameter Real vInsertMax = 0.015 "m/s, bounded insertion speed";

  // Initial joint pose and coordinate setpoints
  parameter Real q1_start = 1.0 "rad";
  parameter Real q2_start = 0.28 "rad";
  parameter Real x_start = L1*cos(q1_start) + L2*cos(q1_start + q2_start) "m";
  parameter Real y_start = L1*sin(q1_start) + L2*sin(q1_start + q2_start) "m";
  parameter Real phi_start = q1_start + q2_start "rad";
  parameter Real holeEntryStandoff = 0.001 "m, axial approach gap selected for deterministic contact onset";
  parameter Real lateralSetpointOffset = 0.008 "m, initial lateral alignment error";
  parameter Real xEntry = x_start - holeEntryStandoff "m, hole entry axial coordinate";
  parameter Real yHole = y_start - lateralSetpointOffset "m, hole lateral setpoint";
  parameter Real phiDes = phi_start "rad, hole/tool axis orientation";

  // Actuator-side dynamics (link mass distribution not specified; finite inertias used for simulation only)
  parameter Real jointInertia1 = 0.10 "kg.m2";
  parameter Real jointInertia2 = 0.05 "kg.m2";
  parameter Real jointDamping1 = 50.0 "N.m.s/rad";
  parameter Real jointDamping2 = 20.0 "N.m.s/rad";

  // Cartesian impedance gains
  parameter Real KpX = 5000.0 "N/m";
  parameter Real KdX = 500.0 "N.s/m";
  parameter Real KpY = 8000.0 "N/m";
  parameter Real KdY = 800.0 "N.s/m";
  parameter Real KpPhi = 200.0 "N.m/rad";
  parameter Real KdPhi = 20.0 "N.m.s/rad";

  // Regularized rigid collision (peg/fixture); stiffness/damping not specified, finite values used for deterministic simulation
  parameter Real contactStiffness = 5.0e4 "N/m";
  parameter Real contactDamping = 5.0e2 "N.s/m";

  // Derived conservative Cartesian force and moment limits from given torque limit and geometry
  parameter Real Jmin = 0.05 "minimum Jacobian-norm divisor guard";
  parameter Real JmaxGlobal = sqrt(2.0)*(L1 + L2) "m";
  parameter Real forceLimit = tauMax / max(JmaxGlobal, Jmin) "N";
  parameter Real Mlimit = tauMax / max(sqrt(2.0), Jmin) "N.m";
  parameter Real axialForceLimit = forceLimit "N";
  parameter Real lateralForceLimit = forceLimit "N";

  parameter Real posEps = 1.0e-6 "m";
  parameter Real velEps = 1.0e-4 "m/s";

  // Physical state
  Real q1(start=q1_start) "rad";
  Real q2(start=q2_start) "rad";
  Real w1(start=0.0) "rad/s";
  Real w2(start=0.0) "rad/s";

  // Cartesian kinematics
  Real phi "rad";
  Real x "m, axial insertion coordinate";
  Real y "m, lateral alignment coordinate";
  Real vx "m/s";
  Real vy "m/s";
  Real phidot "rad/s";
  Real J11 "m/rad";
  Real J12 "m/rad";
  Real J21 "m/rad";
  Real J22 "m/rad";

  // Insertion and alignment observables
  Real axialDepth "m";
  Real insertionDepth "m";
  Real lateralError "m";
  Real alignmentError "m";
  Real primaryTrackingError "m";
  Real pegTilt "rad";
  Real actualInsertionSpeed "m/s";

  // Commanded traces
  discrete Real xDes(start=x_start) "m";
  discrete Real yDes(start=y_start) "m";
  discrete Real phiDesCmd(start=phi_start) "rad";
  discrete Real depthDes(start=0.0) "m";
  discrete Real xd_des(start=0.0) "m/s";
  discrete Real yd_des(start=0.0) "m/s";
  discrete Real phid_des(start=0.0) "rad/s";
  discrete Real Fx_cmd(start=0.0) "N, axial force command";
  discrete Real Fy_cmd(start=0.0) "N, lateral force command";
  discrete Real M_cmd(start=0.0) "N.m, moment command";
  discrete Real tau1_cmd(start=0.0) "N.m";
  discrete Real tau2_cmd(start=0.0) "N.m";
  Real tau1_sat "N.m";
  Real tau2_sat "N.m";
  Real commandedInsertionSpeed "m/s";

  // Contact and disturbance
  Real Fx_contact "N";
  Real Fy_contact "N";
  Real M_contact "N.m";
  Real Fn "N";
  Real penetration "m";
  Real normalDir;
  Real approach "m/s";
  Real Fdist_y "N";
  Boolean middleThirdActive;
  Real tauContact1 "N.m";
  Real tauContact2 "N.m";

  // Joint sensing
  Real q1_meas "rad";
  Real q2_meas "rad";
  Real q1d_meas "rad/s";
  Real q2d_meas "rad/s";

  // Six-axis contact wrench measurement (planar components populated)
  Real wrenchFx "N";
  Real wrenchFy "N";
  Real wrenchFz "N";
  Real wrenchTx "N.m";
  Real wrenchTy "N.m";
  Real wrenchTz "N.m";

  // Estimator passthrough (no estimator specified; sensor values preserved without fabricated dynamics)
  Real q1_est "rad";
  Real q2_est "rad";
  Real q1d_est "rad/s";
  Real q2d_est "rad/s";
  Real wrenchFx_est "N";
  Real wrenchFy_est "N";
  Real wrenchTz_est "N.m";

  discrete Integer tick(start=0) "synchronized sample counter";
  Boolean boundedInsertionSpeedOK;

protected
  discrete Real sa(start=0.0);
  discrete Real ex(start=0.0);
  discrete Real ey(start=0.0);
  discrete Real ephi(start=0.0);
  discrete Real FxRaw(start=0.0);
  discrete Real FyRaw(start=0.0);
  discrete Real MRaw(start=0.0);
  discrete Real tau1Raw(start=0.0);
  discrete Real tau2Raw(start=0.0);
  discrete Real scale(start=1.0);

equation
  // Planar two-link kinematics, revolute Z joints
  phi = q1 + q2;
  x = L1*cos(q1) + L2*cos(phi);
  y = L1*sin(q1) + L2*sin(phi);

  J11 = -L1*sin(q1) - L2*sin(phi);
  J12 = -L2*sin(phi);
  J21 = L1*cos(q1) + L2*cos(phi);
  J22 = L2*cos(phi);

  vx = J11*w1 + J12*w2;
  vy = J21*w1 + J22*w2;
  phidot = w1 + w2;

  // Insertion and alignment metrics
  axialDepth = xEntry - x;
  insertionDepth = max(0.0, axialDepth);
  lateralError = y - yHole;
  alignmentError = abs(lateralError);
  primaryTrackingError = alignmentError;
  pegTilt = phi - phiDes;
  actualInsertionSpeed = -vx;

  // Controlled lateral fixture load disturbance during middle third of run
  middleThirdActive = time >= tDistStart and time <= tDistEnd;
  Fdist_y = if middleThirdActive then disturbanceForce else 0.0;

  // Regularized rigid peg/fixture collision with Coulomb friction
  if axialDepth > 0.0 then
    penetration = max(0.0, abs(lateralError) - radialClearance);
    normalDir = regSign(lateralError, posEps);
    approach = max(0.0, normalDir*vy);
    Fn = contactStiffness*penetration + contactDamping*approach;
    Fx_contact = -mu*Fn*regSign(vx, velEps);
    Fy_contact = -normalDir*Fn;
    M_contact = 0.0;
  else
    penetration = 0.0;
    normalDir = 0.0;
    approach = 0.0;
    Fn = 0.0;
    Fx_contact = 0.0;
    Fy_contact = 0.0;
    M_contact = 0.0;
  end if;

  // Environment wrench mapped to joint torques
  tauContact1 = J11*Fx_contact + J21*(Fy_contact + Fdist_y) + M_contact;
  tauContact2 = J12*Fx_contact + J22*(Fy_contact + Fdist_y) + M_contact;

  // Actuator saturation
  tau1_sat = clamp(tau1_cmd, -tauMax, tauMax);
  tau2_sat = clamp(tau2_cmd, -tauMax, tauMax);

  // Joint dynamics
  der(q1) = w1;
  der(q2) = w2;
  der(w1) = (tau1_sat + tauContact1 - jointDamping1*w1)/jointInertia1;
  der(w2) = (tau2_sat + tauContact2 - jointDamping2*w2)/jointInertia2;

  // Joint sensing
  q1_meas = q1;
  q2_meas = q2;
  q1d_meas = w1;
  q2d_meas = w2;

  // Six-axis wrench sensing
  wrenchFx = Fx_contact;
  wrenchFy = Fy_contact + Fdist_y;
  wrenchFz = 0.0;
  wrenchTx = 0.0;
  wrenchTy = 0.0;
  wrenchTz = M_contact;

  // Estimator passthrough
  q1_est = q1_meas;
  q2_est = q2_meas;
  q1d_est = q1d_meas;
  q2d_est = q2d_meas;
  wrenchFx_est = wrenchFx;
  wrenchFy_est = wrenchFy;
  wrenchTz_est = wrenchTz;

  commandedInsertionSpeed = -xd_des;
  boundedInsertionSpeedOK = abs(commandedInsertionSpeed) <= vInsertMax + 1.0e-9;

  // Sampled Cartesian impedance controller at 200 Hz
  when sample(0, Ts) then
    tick = pre(tick) + 1;

    if time <= tAlign then
      sa = smoothStep(time/tAlign);
      xDes = x_start;
      yDes = yHole + (y_start - yHole)*(1.0 - sa);
      phiDesCmd = phiDes;
      depthDes = 0.0;
    else
      sa = 1.0;
      xDes = max(xEntry - insertionTarget, x_start - vInsertMax*(time - tAlign));
      yDes = yHole;
      phiDesCmd = phiDes;
      depthDes = max(0.0, xEntry - xDes);
    end if;

    xd_des = (xDes - pre(xDes))/Ts;
    yd_des = (yDes - pre(yDes))/Ts;
    phid_des = (phiDesCmd - pre(phiDesCmd))/Ts;

    ex = xDes - x;
    ey = yDes - y;
    ephi = phiDesCmd - phi;

    FxRaw = KpX*ex + KdX*(xd_des - vx);
    FyRaw = KpY*ey + KdY*(yd_des - vy);
    MRaw = KpPhi*ephi + KdPhi*(phid_des - phidot);

    Fx_cmd = clamp(FxRaw, -axialForceLimit, axialForceLimit);
    Fy_cmd = clamp(FyRaw, -lateralForceLimit, lateralForceLimit);
    M_cmd = clamp(MRaw, -Mlimit, Mlimit);

    tau1Raw = J11*Fx_cmd + J21*Fy_cmd + M_cmd;
    tau2Raw = J12*Fx_cmd + J22*Fy_cmd + M_cmd;

    scale = tauMax / max(max(abs(tau1Raw), abs(tau2Raw)), tauMax);
    tau1_cmd = scale*tau1Raw;
    tau2_cmd = scale*tau2Raw;
  end when;

  // Requirements checks
  assert(noEvent(abs(tau1_sat) <= tauMax + 1.0e-6), "actuator bound 1 violated");
  assert(noEvent(abs(tau2_sat) <= tauMax + 1.0e-6), "actuator bound 2 violated");
  assert(noEvent(abs(Fx_cmd) <= axialForceLimit + 1.0e-6), "axial force limit violated");
  assert(noEvent(abs(Fy_cmd) <= lateralForceLimit + 1.0e-6), "lateral force limit violated");
  assert(noEvent(abs(commandedInsertionSpeed) <= vInsertMax + 1.0e-6), "insertion speed bound violated");
  assert(time < tAlign or noEvent(primaryTrackingError <= 0.002 + 1.0e-9), "primary alignment requirement violated");
  assert(time < 13.5 or noEvent(insertionDepth >= insertionTarget - 1.0e-6), "insertion depth requirement violated");
  assert(noEvent(abs(q1) < 1.0e3 and abs(q2) < 1.0e3 and abs(x) < 1.0e3 and abs(y) < 1.0e3 and
                 abs(tau1_cmd) < 1.0e3 and abs(Fx_cmd) < 1.0e3 and abs(wrenchFx) < 1.0e6 and
                 abs(pegTilt) < 1.0e3 and abs(q1_est) < 1.0e3), "non-finite/out-of-range physical, control, or estimator value");

  annotation(experiment(StopTime=14, Interval=0.005, Tolerance=1e-6));
end PlanarPusherInsertD;