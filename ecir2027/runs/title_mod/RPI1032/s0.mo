model OmniCartBrakeF
  // ===== Embodiment parameters =====
  parameter Real m = 25.0 "Platform mass [kg]";
  parameter Real r = 0.095 "Mecanum wheel radius [m]";
  parameter Real mu = 0.70 "Floor friction coefficient [1]";
  parameter Real tauMax = 14.6 "Per-wheel torque limit [N.m]";
  parameter Real rollerAngleDeg = 45.0 "Mecanum roller angle [deg]";
  parameter Real W = 0.58 "Footprint width [m]";
  parameter Real L = 0.46 "Footprint length [m]";
  parameter Real g = 9.81 "Gravity [m/s2]";

  // ===== Mission parameters =====
  parameter Real vRef = 1.2 "Target cruise speed [m/s]";
  parameter Real xBarrier = 7.0 "Barrier position ahead of origin [m]";
  parameter Real safetyRange = 1.4 "Obstacle safety range [m]";
  parameter Real Fpayload = 261.0 "Payload disturbance weight [N]";
  parameter Real Tsim = 20.0 "Total mission time [s]";

  // ===== Control / timing =====
  parameter Real ctrlRate = 500.0 "Control loop rate [Hz]";
  parameter Real camRate = 30.0 "Depth camera rate [Hz]";
  parameter Real kp = 60.0 "Speed controller proportional gain";
  parameter Real vTol = 0.02 "Cruise transition speed tolerance [m/s]";
  parameter Real stopTol = 0.02 "Stopped speed tolerance [m/s]";

  // ===== Continuous states =====
  Real x(start=0.0, fixed=true) "Forward position [m]";
  Real vx(start=0.0, fixed=true) "Forward velocity [m/s]";
  Real ax "Forward acceleration [m/s2]";

  // ===== Forces and effective mass =====
  Real Fn "Normal force [N]";
  Real FdriveMax "Friction-limited max drive force [N]";
  Real Fdrive "Total drive force from four wheels [N]";
  Real Ffriction "Friction force transmitted to body [N]";
  Real FpayloadEff "Payload weight active [N]";
  Real mEff "Effective mass including payload [kg]";
  Boolean inPayloadWindow "Payload disturbance active flag";

  // ===== Wheel torques =====
  Real tau1 "Wheel 1 torque [N.m]";
  Real tau2 "Wheel 2 torque [N.m]";
  Real tau3 "Wheel 3 torque [N.m]";
  Real tau4 "Wheel 4 torque [N.m]";
  discrete Real tauCmd(start=0.0) "Commanded per-wheel torque [N.m]";

  // ===== Control state machine =====
  Integer state(start=0) "0=ACCEL,1=CRUISE,2=BRAKE,3=STOPPED";
  Real vCmd "Commanded speed [m/s]";
  Real rangeToBarrier "Distance to barrier [m]";
  Boolean obstacleDetected "Obstacle within safety range";
  discrete Real vAtBrakeStart(start=0.0) "Velocity at brake onset [m/s]";
  Boolean brakeMonotonic "Braking monotonicity flag";

  // ===== Sensors =====
  Real xEnc "Encoder position [m]";
  Real vEnc "Encoder velocity [m/s]";
  Real axImu "IMU forward acceleration [m/s2]";
  discrete Real depthRange(start=7.0) "Depth camera range to obstacle [m]";

  // ===== Verification =====
  Real trackingError "Distance remaining to barrier [m]";
  Real residualSpeed "abs(vx) [m/s]";
  Boolean speedLimitOK;
  Boolean effortLimitOK;
  Boolean noCollision;
  Boolean residualSpeedOK;
  Boolean trackingOK;
  Boolean noNaNInf;
  Boolean allVerified;

algorithm
  when sample(0, 1/ctrlRate) then
    // Deterministic emergency-stop state machine transitions
    if state == 0 then
      if rangeToBarrier < safetyRange then
        state := 2;
        vAtBrakeStart := vx;
      elseif abs(vx - vRef) < vTol then
        state := 1;
      end if;
    elseif state == 1 then
      if rangeToBarrier < safetyRange then
        state := 2;
        vAtBrakeStart := vx;
      end if;
    elseif state == 2 then
      if abs(vx) < stopTol then
        state := 3;
      end if;
    end if;

    // Speed-control torque command
    if state == 0 then
      tauCmd := kp * (vRef - vx);
    elseif state == 1 then
      tauCmd := kp * (vRef - vx);
    elseif state == 2 then
      tauCmd := -tauMax;
    else
      tauCmd := 0.0;
    end if;

    // Effort limit clamp
    if tauCmd > tauMax then
      tauCmd := tauMax;
    elseif tauCmd < -tauMax then
      tauCmd := -tauMax;
    end if;
  end when;

  // 30 Hz depth camera sampling
  when sample(0, 1/camRate) then
    depthRange := xBarrier - x;
  end when;

equation
  // Payload disturbance window: middle third of mission
  inPayloadWindow = (time >= Tsim/3.0) and (time <= 2.0*Tsim/3.0);
  FpayloadEff = if inPayloadWindow then Fpayload else 0.0;
  mEff = m + FpayloadEff/g;
  Fn = mEff * g;

  // Four wheels equally commanded for holonomic forward motion
  tau1 = tauCmd;
  tau2 = tauCmd;
  tau3 = tauCmd;
  tau4 = tauCmd;
  Fdrive = (tau1 + tau2 + tau3 + tau4) / r;
  FdriveMax = mu * Fn;

  // Regularized Coulomb friction contact force (zero-error safe)
  Ffriction = FdriveMax * tanh(Fdrive / (FdriveMax + 1e-6));

  // Floating-base planar dynamics (forward axis)
  ax = Ffriction / mEff;
  der(vx) = ax;
  der(x) = vx;

  // Range and command observables
  rangeToBarrier = xBarrier - x;
  vCmd = if state == 2 then 0.0 elseif state == 3 then 0.0 else vRef;
  obstacleDetected = rangeToBarrier < safetyRange;

  // Synchronized sensor traces
  xEnc = x;
  vEnc = vx;
  axImu = ax;

  // ===== Verification criteria =====
  trackingError = xBarrier - x;
  residualSpeed = abs(vx);
  speedLimitOK = abs(vx) <= vRef + 0.05;
  effortLimitOK = (abs(tau1) <= tauMax + 1e-6) and (abs(tau2) <= tauMax + 1e-6) and (abs(tau3) <= tauMax + 1e-6) and (abs(tau4) <= tauMax + 1e-6);
  noCollision = x <= xBarrier - 1e-3;
  residualSpeedOK = (time < 13.0) or (abs(vx) < 0.05);
  trackingOK = (time < 13.0) or ((xBarrier - x) > 0.176);
  brakeMonotonic = (state <> 2) or (vx <= vAtBrakeStart + 1e-4);
  noNaNInf = (x == x) and (vx == vx) and (ax == ax) and (tauCmd == tauCmd) and (Ffriction == Ffriction) and (abs(x) < 1e300) and (abs(vx) < 1e300) and (abs(ax) < 1e300);
  allVerified = speedLimitOK and effortLimitOK and noCollision and residualSpeedOK and trackingOK and brakeMonotonic and noNaNInf;

  annotation(
    experiment(StartTime=0, StopTime=20, Tolerance=1e-6, Interval=0.002),
    Documentation(info="OmniCartBrakeF: floating-base mecanum cart accelerates to 1.2 m/s and emergency-brakes when a fixed barrier 7 m ahead enters a 1.4 m safety range. 25 kg platform, four 0.095 m-radius mecanum wheels at 45 deg roller angle, 0.58 x 0.46 m footprint. Per-wheel torque limited to 14.6 N.m. Floor friction 0.70. A 261 N payload weight disturbance is applied during the middle third of the 20 s mission at 500 Hz control with a 30 Hz depth camera. Lateral and rotational mecanum dynamics are not modeled (treated as unknown); only the forward axis is simulated."));
end OmniCartBrakeF;