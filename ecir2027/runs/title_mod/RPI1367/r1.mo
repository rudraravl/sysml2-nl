model SoftGripAvoidE
  "Soft three-finger gripper reaching a target around a fixed cylindrical obstacle.
   Contact-aware shape control, bounded stiffness scheduling, controlled lateral
   tip disturbance, fail-closed acceptance. Geometric placement and material gains
   are design choices for this verifiable scenario (not specified by the requirement)."

  // ---- Geometry / structure ----
  parameter Real L = 0.13 "finger length [m]";
  parameter Real sL = L/4.0 "section length [m]";
  parameter Real fRad = 0.004 "finger half-thickness [m]";
  parameter Real baseAng[3] = {-0.50, 0.0, 0.50} "finger base angles [rad]";

  // ---- Actuation ----
  parameter Real pMax = 105000.0 "command pressure bound [Pa-gauge]";
  parameter Real kappaMax = 15.0 "max chamber curvature [rad/m]";
  parameter Real tauP = 0.05 "pressure lag time constant [s]";

  // ---- Section dynamics ----
  parameter Real Jsec = 5.0e-5 "section rotational inertia [kg m^2]";
  parameter Real csec = 0.05 "section damping [N m s/rad]";
  parameter Real ksec_min = 12.0 "min scheduled stiffness [N m/rad]";
  parameter Real ksec_max = 45.0 "max scheduled stiffness [N m/rad]";

  // ---- Obstacle ----
  parameter Real xObs = 0.055 "obstacle center x [m]";
  parameter Real yObs = 0.0 "obstacle center y [m]";
  parameter Real rObs = 0.018 "obstacle radius [m]";
  parameter Real mu = 0.55 "obstacle friction coefficient";
  parameter Real kc = 1500.0 "contact stiffness [N/m]";

  // ---- Target ----
  parameter Real xTarget = 0.098 "target x [m]";
  parameter Real yTarget = 0.072 "target y [m]";

  // ---- Thermal ----
  parameter Real T_amb = 22.0 "ambient temperature [degC]";
  parameter Real heatRate = 2.5 "heating rate at full pressure [degC/s]";
  parameter Real coolCoeff = 0.05 "cooling coefficient [1/s]";

  // ---- Disturbance ----
  parameter Real Fdist = 9.6 "lateral tip disturbance magnitude [N]";

  // ---- Controller ----
  parameter Real Ts = 0.004 "controller sample period [s] (250 Hz)";
  parameter Real pBiasHold = 12000.0 "hold pressure for lateral fingers [Pa]";
  parameter Real pBias2 = 55000.0 "feedforward pressure for primary finger [Pa]";
  parameter Real Kp_y = 150000.0 "y position gain [Pa/m]";
  parameter Real Kp_x = 100000.0 "x position gain [Pa/m]";
  parameter Real K_avoid = 650000.0 "obstacle avoidance gain [Pa/m]";
  parameter Real clearThr = 0.020 "avoidance clearance threshold [m]";
  parameter Real fscale = 50.0 "friction sign smoothing [s/rad]";
  parameter Real eps = 1.0e-9 "regularization [m^2]";

  // ---- Stiffness scheduling ----
  parameter Real tStiff = 6.0 "stiffening start time [s]";
  parameter Real tRamp = 2.0 "stiffening ramp duration [s]";

  // ---- Acceptance bounds ----
  parameter Real qMax = 1.2 "section deformation bound [rad]";
  parameter Real FcMax = 30.0 "total contact force bound [N]";
  parameter Real TMax = 75.0 "actuator temperature bound [degC]";
  parameter Real penMax = 0.010 "max penetration bound [m]";
  parameter Real trackBound = 0.036 "tracking error bound after 10.4 s [m]";
  parameter Real tTrack = 10.4 "tracking enforcement time [s]";

  // ---- Dynamic states ----
  Real q[3,4](each start=0.15) "section bend angle [rad]";
  Real qd[3,4](each start=0.0) "section bend rate [rad/s]";
  Real pAct[3](start={12000.0, 55000.0, 12000.0}) "actuator pressure [Pa-gauge]";
  Real T[3](each start=22.0) "actuator temperature [degC]";

  // ---- Discrete states ----
  discrete Real pCmd[3](start={12000.0, 55000.0, 12000.0}) "chamber pressure command [Pa-gauge]";
  Boolean fault(start=false) "latched fail-closed fault flag";

  // ---- Kinematic variables ----
  Real cumAng[3,5] "cumulative angle at each joint [rad]";
  Real xj[3,5] "joint x [m]";
  Real yj[3,5] "joint y [m]";
  Real mx[3,4] "section midpoint x [m]";
  Real my[3,4] "section midpoint y [m]";
  Real xTip[3] "tip x [m]";
  Real yTip[3] "tip y [m]";
  Real phiTip[3] "tip orientation [rad]";

  // ---- Contact variables ----
  Real clear[3,4] "obstacle clearance per section [m]";
  Real pen[3,4] "penetration per section [m]";
  Real Fn[3,4] "normal contact force per section [N]";
  Real Fcx[3,4] "contact force x [N]";
  Real Fcy[3,4] "contact force y [N]";
  Real Mcon[3,4] "contact moment on section [N m]";
  Real Mdist[3,4] "disturbance moment on section [N m]";
  Real minClear[3] "min clearance per finger [m]";

  // ---- Aggregated / sensor traces ----
  Real kappa[3] "chamber curvature [rad/m]";
  Real ksec_eff[3] "scheduled section stiffness [N m/rad]";
  Real stiffFactor "stiffness schedule factor [1]";
  Real trackingErr "primary finger tip tracking error [m]";
  Real FcTotal "total distributed contact force [N]";
  Real maxPen "max penetration over all sections [m]";
  Real maxQ "max abs section deformation [rad]";
  Real maxT "max actuator temperature [degC]";
  Boolean inDist "disturbance active window";
  Boolean holdShape "shape held indicator";

protected
  Real d2[3,4];
  Real d[3,4];
  Real nxp[3,4];
  Real nyp[3,4];
  Real tnx[3,4];
  Real tny[3,4];
  Real ftS[3,4];

equation
  // Disturbance window: middle third of 16 s
  inDist = (time >= 16.0/3.0) and (time <= 2.0*16.0/3.0);

  // Forward kinematics of the four bending sections per finger
  for k in 1:3 loop
    cumAng[k,1] = baseAng[k];
    xj[k,1] = 0.0;
    yj[k,1] = 0.0;
    for i in 1:4 loop
      cumAng[k,i+1] = cumAng[k,i] + q[k,i];
      xj[k,i+1] = xj[k,i] + sL*cos(cumAng[k,i+1]);
      yj[k,i+1] = yj[k,i] + sL*sin(cumAng[k,i+1]);
      mx[k,i] = (xj[k,i] + xj[k,i+1])/2.0;
      my[k,i] = (yj[k,i] + yj[k,i+1])/2.0;
    end for;
    xTip[k] = xj[k,5];
    yTip[k] = yj[k,5];
    phiTip[k] = cumAng[k,5];
  end for;

  // Contact against fixed cylinder (midpoint-based, collision enabled)
  for k in 1:3 loop
    for i in 1:4 loop
      d2[k,i] = (mx[k,i] - xObs)^2 + (my[k,i] - yObs)^2;
      d[k,i] = sqrt(d2[k,i] + eps);
      clear[k,i] = d[k,i] - rObs - fRad;
      pen[k,i] = max(0.0, -clear[k,i]);
      Fn[k,i] = kc*pen[k,i];
      nxp[k,i] = (mx[k,i] - xObs)/d[k,i];
      nyp[k,i] = (my[k,i] - yObs)/d[k,i];
      tnx[k,i] = cos(cumAng[k,i+1]);
      tny[k,i] = sin(cumAng[k,i+1]);
      ftS[k,i] = tanh(qd[k,i]*fscale);
      Fcx[k,i] = Fn[k,i]*nxp[k,i] - mu*Fn[k,i]*ftS[k,i]*tnx[k,i];
      Fcy[k,i] = Fn[k,i]*nyp[k,i] - mu*Fn[k,i]*ftS[k,i]*tny[k,i];
      Mcon[k,i] = (sL/2.0)*(cos(cumAng[k,i+1])*Fcy[k,i] - sin(cumAng[k,i+1])*Fcx[k,i]);
      // Controlled lateral (-y) tip load on the primary finger (middle third)
      Mdist[k,i] = -(if (k == 2 and inDist) then Fdist*sL*(5.0 - i) else 0.0);
    end for;
    minClear[k] = min(min(clear[k,1],clear[k,2]), min(clear[k,3],clear[k,4]));
  end for;

  // Chamber curvature from actuator pressure
  for k in 1:3 loop
    kappa[k] = (pAct[k]/pMax)*kappaMax;
  end for;

  // Primary tracking error (finger 2)
  trackingErr = sqrt((xTarget - xTip[2])^2 + (yTarget - yTip[2])^2 + eps);

  // Bounded stiffness scheduling (ramps up after reaching phase)
  stiffFactor = max(0.0, min(1.0, (time - tStiff)/tRamp));
  holdShape = stiffFactor >= 0.999;
  for k in 1:3 loop
    ksec_eff[k] = ksec_min + (ksec_max - ksec_min)*stiffFactor;
  end for;

  // Section dynamics (four bending sections per chamber)
  for k in 1:3 loop
    for i in 1:4 loop
      der(q[k,i]) = qd[k,i];
      Jsec*der(qd[k,i]) =
        - csec*qd[k,i]
        - ksec_eff[k]*(q[k,i] - kappa[k]*sL)
        + Mcon[k,i]
        + Mdist[k,i];
    end for;
  end for;

  // Actuator pressure dynamics
  for k in 1:3 loop
    der(pAct[k]) = (pCmd[k] - pAct[k])/tauP;
  end for;

  // Actuator thermal state
  for k in 1:3 loop
    der(T[k]) = (pAct[k]/pMax)*heatRate - coolCoeff*(T[k] - T_amb);
  end for;

  // Aggregated sensor reductions (scalar explicit form)
  FcTotal =
    Fn[1,1]+Fn[1,2]+Fn[1,3]+Fn[1,4] +
    Fn[2,1]+Fn[2,2]+Fn[2,3]+Fn[2,4] +
    Fn[3,1]+Fn[3,2]+Fn[3,3]+Fn[3,4];
  maxPen = max(
    max(max(pen[1,1],pen[1,2]), max(pen[1,3],pen[1,4])),
    max(
      max(max(pen[2,1],pen[2,2]), max(pen[2,3],pen[2,4])),
      max(max(pen[3,1],pen[3,2]), max(pen[3,3],pen[3,4]))));
  maxQ = max(
    max(max(abs(q[1,1]),abs(q[1,2])), max(abs(q[1,3]),abs(q[1,4]))),
    max(
      max(max(abs(q[2,1]),abs(q[2,2])), max(abs(q[2,3]),abs(q[2,4]))),
      max(max(abs(q[3,1]),abs(q[3,2])), max(abs(q[3,3]),abs(q[3,4])))));
  maxT = max(max(T[1],T[2]),T[3]);

  // ---- Contact-aware shape control, sampled at 250 Hz ----
  when sample(0.0, Ts) then
    // Primary finger: reach target while avoiding obstacle (bounded command)
    pCmd[2] = if pre(fault) then 0.0 else
      max(0.0, min(pMax,
        pBias2
        + Kp_y*(yTarget - yTip[2])
        - Kp_x*(xTarget - xTip[2])
        + K_avoid*max(0.0, clearThr - minClear[2])));
    // Lateral fingers: hold grip shape with contact-aware avoidance
    pCmd[1] = if pre(fault) then 0.0 else
      max(0.0, min(pMax,
        pBiasHold + K_avoid*max(0.0, clearThr - minClear[1])));
    pCmd[3] = if pre(fault) then 0.0 else
      max(0.0, min(pMax,
        pBiasHold + K_avoid*max(0.0, clearThr - minClear[3])));
    // Fail-closed acceptance (latched)
    fault = pre(fault)
      or (maxQ > qMax)
      or (FcTotal > FcMax)
      or (maxT > TMax)
      or (maxPen > penMax)
      or ((time >= tTrack) and (trackingErr > trackBound));
  end when;

  // ---- NaN / infinity guards (terminating = fail-closed) ----
  assert(xTip[2] == xTip[2], "NaN detected in tip pose (x)");
  assert(yTip[2] == yTip[2], "NaN detected in tip pose (y)");
  assert(trackingErr == trackingErr, "NaN detected in tracking error");
  assert(pAct[2] < 1.0e20, "Infinite actuator pressure");
  assert(FcTotal < 1.0e20, "Infinite contact force");
  assert(maxT < 1.0e20, "Infinite temperature");
  assert(maxQ < 1.0e20, "Infinite section deformation");

  annotation(
    experiment(StopTime=16.0, Tolerance=1e-6, Interval=0.004),
    Documentation(info="SoftGripAvoidE: verifiable soft robotic scenario. Three 0.13 m silicone fingers (one pressure chamber each, four bending sections per chamber) surround a rigid palm and reach a target around a fixed frictional cylinder (mu=0.55). Commands bounded at 105 kPa-gauge. Measures actuator state, distributed contact force, section deformation, tip pose, temperature, and obstacle clearance. Contact-aware shape control with bounded stiffness scheduling and a controlled 9.6 N lateral tip load applied in the middle third. Runs at 250 Hz for 16 s with synchronized state, command, and sensor traces. Acceptance is fail-closed via a latched fault that zero-commands all chambers, plus NaN/infinity asserts."));
end SoftGripAvoidE;