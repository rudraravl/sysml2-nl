model SoftCrawlShapeD
  "Instrumented soft crawling robot: 6 serial pneumatic bending chambers,
   anisotropic ground friction, reduced-order piecewise-constant-curvature
   shape feedback, 6 N tip load disturbance during middle third, 200 Hz
   control, 14 s run. Targets a declared shape and holds it."

  // ---- Body / embodiment ----
  parameter Real L = 0.48        "compliant body length [m]";
  parameter Integer N = 6         "number of serial pneumatic bending chambers";
  parameter Real Lseg = L/N       "segment length [m]";
  parameter Real pMax = 75000.0   "chamber pressure limit, gauge [Pa]";
  parameter Real grav = 9.81      "gravity [m/s2]";
  parameter Real segMass = 0.30   "segment mass [kg]";
  parameter Real bodyMass = N*segMass "total body mass [kg]";
  parameter Real kappaLimit = 8.0 "curvature/strain bound magnitude [1/m]";
  parameter Real TempLimit = 353.15 "temperature bound [K] (80 degC)";

  // ---- Segment curvature dynamics ----
  parameter Real cKappa = 8.0e-6 "bending gain per Pa [1/m per Pa]";
  parameter Real Jseg   = 5.0e-4 "segment rotary inertia [kg m2]";
  parameter Real bKappa = 0.08    "curvature damping [N m s]";
  parameter Real kKappa = 1.2     "curvature stiffness [N m]";
  parameter Real pTau   = 0.05    "pneumatic pressure time constant [s]";

  // ---- Anisotropic friction / crawl dynamics ----
  parameter Real muFwd  = 0.02    "forward (slip) friction coefficient";
  parameter Real muBwd  = 0.50    "backward (grip) friction coefficient";
  parameter Real vEps   = 0.01    "friction smoothing velocity [m/s]";
  parameter Real dragC  = 8.0     "crawling viscous drag [N s/m]";
  parameter Real propMax = 1.6    "peak propulsion force during crawl [N]";
  parameter Real reachThresh = 0.02 "reach threshold for hold switch [m]";
  parameter Real reachHyst   = 0.03 "hysteresis band [m]";
  parameter Real kpHold = 400.0  "hold position proportional gain [N/m]";
  parameter Real kdHold = 40.0   "hold position derivative gain [N s/m]";

  // ---- Reference / disturbance timing ----
  parameter Real waveAmp  = 0.5   "traveling-wave curvature amplitude [1/m]";
  parameter Real waveFreq = 0.7   "traveling-wave frequency [Hz]";
  parameter Real wavePhase = 2.0*Modelica.Constants.pi/N "inter-segment phase";
  parameter Real Fdist = 6.0      "tip load disturbance magnitude [N]";
  parameter Real tMidStart = 14.0/3.0 "disturbance start time [s]";
  parameter Real tMidEnd   = 28.0/3.0 "disturbance end time [s]";
  parameter Real xTgt = 0.30      "declared target base position [m]";
  parameter Real tStop = 14.0     "simulation duration [s]";
  parameter Real dtSample = 0.005 "control sample period (200 Hz) [s]";
  parameter Real eps = 1.0e-6     "zero-guard for divisions";

  // ---- Thermal ----
  parameter Real T0   = 293.15    "initial body temperature [K]";
  parameter Real Tamb = 293.15    "ambient temperature [K]";
  parameter Real Cth  = 60.0      "thermal capacitance [J/K]";
  parameter Real Rth  = 0.4       "thermal resistance to ambient [K/W]";
  parameter Real QpMax = 2.0      "max chamber dissipation per chamber [W]";

  // ---- States: chamber pressure ----
  Real pAct[6](each start = 0.0)     "measured chamber pressure, gauge [Pa]";
  discrete Real pCmdD[6](each start = 0.0) "200 Hz pressure command [Pa]";
  Real pCmd[6]                       "pressure command applied [Pa]";

  // ---- States: segment curvature (section strain surrogate) ----
  Real kappa[6](each start = 0.0)    "segment curvature [1/m]";
  Real kappaDot[6](each start = 0.0) "segment curvature rate [1/m/s]";
  Real kappaRef[6]                   "reference curvature profile [1/m]";
  Real kappaTgt[6]                   "declared target curvature profile [1/m]";

  // ---- States: body crawl ----
  Real X(start = 0.0)                "base forward position [m]";
  Real Xdot(start = 0.0)            "base forward velocity [m/s]";
  Real Fprop                         "propulsion force [N]";
  Real Ffriction                     "anisotropic friction force [N]";
  Real Fload                         "applied tip load disturbance [N]";
  Real Fnet                          "net forward force [N]";
  Real Nnormal                       "normal force on ground [N]";
  Real reachErr                      "remaining reach error [m]";
  discrete Boolean reached(start = false) "finite-state: hold latch";

  // ---- Tip pose via piecewise-constant-curvature FKE ----
  Real thetaSeg[6]                   "segment bending angle [rad]";
  Real thCum[6]                      "cumulative angle before segment [rad]";
  Real dxL[6], dyL[6]                "local segment displacement [m]";
  Real accX[7], accY[7], accTh[7]    "running FKE accumulators";
  Real tipXr, tipYr, tipThR          "tip pose relative to base";
  Real tipXg, tipYg, tipThg          "tip pose in shared inertial frame";

  // ---- Temperature state ----
  Real Temp(start = T0)              "measured body temperature [K]";
  Real Qgen                          "generated thermal power [W]";

  // ---- Tracking and shape-error metrics ----
  Real trackErr                      "primary tracking error [m]";
  Real shapeErr                      "final shape error norm [1/m]";

  // ---- Bounds / finite-state invariants ----
  Real pActMin, pActMax, kappaMin, kappaMax;
  Boolean okActuator, okCurvature, okTemp, okFiniteState, okShapeFinal, okTracking, allOK;

equation
  // Declared target shape: a gently curved frozen traveling-wave snapshot.
  for i in 1:6 loop
    kappaTgt[i] = 0.3*waveAmp*sin(wavePhase*(i - 1));
  end for;

  // Reference curvature: traveling wave while crawling, target shape while holding.
  if not reached then
    for i in 1:6 loop
      kappaRef[i] = waveAmp*sin(2.0*Modelica.Constants.pi*waveFreq*time + wavePhase*(i - 1));
    end for;
  else
    for i in 1:6 loop
      kappaRef[i] = kappaTgt[i];
    end for;
  end if;

  // First-order pneumatic actuator dynamics on each chamber.
  for i in 1:6 loop
    der(pAct[i]) = (pCmd[i] - pAct[i])/pTau;
  end for;

  // Second-order reduced-order deformation model per chamber.
  for i in 1:6 loop
    der(kappa[i]) = kappaDot[i];
    Jseg*der(kappaDot[i]) = cKappa*pAct[i] - bKappa*kappaDot[i] - kKappa*kappa[i];
  end for;

  // Reach-error and finite-state hold latch with hysteresis.
  reachErr = xTgt - X;
  when not reached and pre(reachErr) < reachThresh then
    reached = true;
  elsewhen reached and pre(reachErr) > (reachThresh + reachHyst) then
    reached = false;
  end when;

  // Propulsion controller: constant forward drive during crawl,
  // PD hold at the declared target base position once reached.
  if not reached then
    Fprop = propMax*(1.0 - Modelica.Math.exp(-time/0.5));
  else
    Fprop = kpHold*(xTgt - X) + kdHold*(-Xdot);
  end if;

  // Anisotropic ground friction with smooth sign, zero-error branch via vEps.
  Nnormal = bodyMass*grav;
  Ffriction = -Nnormal * Modelica.Math.tanh(Xdot/vEps) *
    (muFwd*0.5*(1.0 + Modelica.Math.tanh(Xdot/vEps)) +
     muBwd*0.5*(1.0 - Modelica.Math.tanh(Xdot/vEps)));

  // Disturbance: 6 N backward tip load during middle third of the run.
  if (time >= tMidStart) and (time <= tMidEnd) then
    Fload = -Fdist;
  else
    Fload = 0.0;
  end if;

  // Crawl dynamics.
  Fnet = Fprop + Ffriction + Fload - dragC*Xdot;
  bodyMass*der(Xdot) = Fnet;
  der(X) = Xdot;

  // 200 Hz sampled shape-feedback pressure command.
  // pCmd = (1/cKappa) * (kappaRef + kp*(kappaRef - kappa)), bounded to [0, pMax].
  when sample(0, dtSample) then
    for i in 1:6 loop
      pCmdD[i] = max(0.0, min(pMax, (1.0/cKappa)*(kappaRef[i] + 3.0*(kappaRef[i] - kappa[i]))));
    end for;
  end when;
  for i in 1:6 loop
    pCmd[i] = pCmdD[i];
  end for;

  // Tip pose via piecewise-constant-curvature forward kinematics.
  for i in 1:6 loop
    thetaSeg[i] = kappa[i]*Lseg;
  end for;
  thCum[1] = 0.0;
  for i in 2:6 loop
    thCum[i] = thCum[i-1] + thetaSeg[i-1];
  end for;
  for i in 1:6 loop
    dxL[i] = if abs(kappa[i]) < eps then Lseg else Modelica.Math.sin(thetaSeg[i])/kappa[i];
    dyL[i] = if abs(kappa[i]) < eps then 0.0  else (1.0 - Modelica.Math.cos(thetaSeg[i]))/kappa[i];
  end for;
  accX[1] = 0.0; accY[1] = 0.0; accTh[1] = 0.0;
  for i in 1:6 loop
    accX[i+1]  = accX[i]  + Modelica.Math.cos(accTh[i])*dxL[i] - Modelica.Math.sin(accTh[i])*dyL[i];
    accY[i+1]  = accY[i]  + Modelica.Math.sin(accTh[i])*dxL[i] + Modelica.Math.cos(accTh[i])*dyL[i];
    accTh[i+1] = accTh[i] + thetaSeg[i];
  end for;
  tipXr  = accX[7];
  tipYr  = accY[7];
  tipThR = accTh[7];

  // Shared inertial frame: base crawls forward, body geometry undeformed/actuated preserved.
  tipXg  = X + tipXr;
  tipYg  = tipYr;
  tipThg = tipThR;

  // Thermal model: chamber pressurization dissipation drives body temperature.
  Qgen = QpMax*((pAct[1] + pAct[2] + pAct[3] + pAct[4] + pAct[5] + pAct[6])/(6.0*pMax));
  der(Temp) = (Qgen - (Temp - Tamb)/Rth)/Cth;

  // Primary tracking error: distance from declared target base position.
  trackErr = abs(xTgt - X);

  // Final shape error: L2 norm of curvature error vs. declared target, zero-guarded.
  shapeErr = Modelica.Math.sqrt(
      (kappa[1]-kappaTgt[1])^2 + (kappa[2]-kappaTgt[2])^2 +
      (kappa[3]-kappaTgt[3])^2 + (kappa[4]-kappaTgt[4])^2 +
      (kappa[5]-kappaTgt[5])^2 + (kappa[6]-kappaTgt[6])^2 + 1.0e-12) - 1.0e-6;

  // Scalar reductions for actuator and curvature bounds.
  pActMin = min(pAct[1], min(pAct[2], min(pAct[3], min(pAct[4], min(pAct[5], pAct[6])))));
  pActMax = max(pAct[1], max(pAct[2], max(pAct[3], max(pAct[4], max(pAct[5], pAct[6])))));
  kappaMin = min(kappa[1], min(kappa[2], min(kappa[3], min(kappa[4], min(kappa[5], kappa[6])))));
  kappaMax = max(kappa[1], max(kappa[2], max(kappa[3], max(kappa[4], max(kappa[5], kappa[6])))));

  // Bound checks (NaN/inf guarded by finite-range assertions).
  okActuator   = (pActMin >= 0.0) and (pActMax <= pMax);
  okCurvature  = (kappaMin >= -kappaLimit) and (kappaMax <= kappaLimit);
  okTemp       = (Temp > 0.0) and (Temp < TempLimit);
  okFiniteState = (X > -1.0e5) and (X < 1.0e5) and
                  (Xdot > -1.0e5) and (Xdot < 1.0e5) and
                  (Temp > 0.0) and (Temp < 1.0e5) and
                  (trackErr < 1.0e6) and (shapeErr < 1.0e6);
  okTracking   = if (time >= 9.1) then (trackErr < 0.045) else true;
  okShapeFinal = if (time >= tStop - 0.1) then (shapeErr < 0.1) else true;
  allOK = okActuator and okCurvature and okTemp and okFiniteState and okTracking and okShapeFinal;

  annotation (
    experiment(StartTime = 0.0, StopTime = 14.0, Tolerance = 1.0e-6,
               Interval = 0.005),
    Documentation(info = "SoftCrawlShapeD: 6-chamber pneumatic soft crawler, 0.48 m body,
      75 kPa-gauge pressure limit, anisotropic ground friction, traveling-wave
      shape feedback at 200 Hz, 6 N tip load disturbance during middle third.
      Primary tracking error required < 0.045 m after 9.1 s; final shape error bounded.
      All measurements (pressure, curvature/strain, tip pose, temperature) preserved.
      Unstated facts (exact material constitutive law, detailed chamber geometry,
      sensor noise models) are intentionally not invented.")
  );
end SoftCrawlShapeD;