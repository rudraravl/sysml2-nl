model TriTugBrakeE
  final constant Integer MODE_ACCEL = 1;
  final constant Integer MODE_CRUISE = 2;
  final constant Integer MODE_BRAKE = 3;
  final constant Integer MODE_HOLD = 4;

  parameter Real m_chassis(unit="kg") = 38.0 "logistics chassis mass";
  parameter Real m_payload(unit="kg") = 20.0 "payload mass";
  parameter Real m_total(unit="kg") = m_chassis + m_payload "total mass";
  parameter Real r_front(unit="m") = 0.15 "front drive-and-steer wheel radius";
  parameter Real steerLimit(unit="rad") = 0.60 "steering travel magnitude";
  parameter Real maxTorque(unit="N.m") = 37.4 "effort command magnitude bound";
  parameter Real vRef(unit="m/s") = 1.2 "commanded cruise speed";
  parameter Real vRefTol(unit="m/s") = 0.01 "speed transition tolerance";
  parameter Real safetyRange(unit="m") = 1.4 "forward obstacle safety range";
  parameter Real xBarrier(unit="m") = 7.0 "fixed barrier position ahead";
  parameter Real mu(unit="1") = 0.70 "rigid floor friction coefficient";
  parameter Real g(unit="m/s2") = 9.81 "gravitational acceleration";
  parameter Real FdistAmp(unit="N") = 216.0 "controlled payload disturbance magnitude";
  parameter Real TdistStart(unit="s") = 16.0/3.0 "middle-third disturbance start";
  parameter Real TdistEnd(unit="s") = 32.0/3.0 "middle-third disturbance end";
  parameter Real Tctrl(unit="s") = 1.0/250.0 "control and estimator sample period";
  parameter Real Tcamera(unit="s") = 1.0/30.0 "depth camera sample period";
  parameter Real KpSpeed(unit="N.m/(m/s)") = 500.0 "speed tracking gain";
  parameter Real KpHold(unit="N.m/(m/s)") = 50.0 "stopped hold velocity gain";
  parameter Real Ksteer(unit="N.m/rad") = 20.0 "steering angle gain";
  parameter Real Dsteer(unit="N.m/(rad/s)") = 2.0 "steering damping gain";
  parameter Real Jsteer(unit="kg.m2") = 0.10 "steering axis inertia placeholder";
  parameter Real bSteer(unit="N.m/(rad/s)") = 0.50 "steering axis damping placeholder";
  parameter Real kSteerStop(unit="N.m/rad") = 10000.0 "steering travel hard-stop stiffness";
  parameter Real estAlpha(unit="1") = 0.10 "disturbance estimator smoothing factor";
  parameter Real vHoldTol(unit="m/s") = 0.04 "speed tolerance for transition to hold";
  parameter Real vStopTol(unit="m/s") = 0.049 "speed tolerance for fail-closed re-brake";
  parameter Real stopMarginTarget(unit="m") = 0.198 "primary stopping-margin target";

  Real x(unit="m", start=0.0) "chassis longitudinal position";
  Real v(unit="m/s", start=0.0) "chassis longitudinal velocity";
  Real theta(unit="rad", start=0.0) "front steering angle";
  Real omegaSteer(unit="rad/s", start=0.0) "front steering angular velocity";

  Real FdistKnown(unit="N") "known controlled longitudinal payload disturbance";
  Real N_total(unit="N") "total normal load on rigid floor";
  Real FfrictionMax(unit="N") "friction force envelope";
  Real FtractionUnbounded(unit="N") "unbounded front traction force";
  Real Ftraction(unit="N") "friction-bounded front traction force";
  Real imuAcceleration(unit="m/s2") "IMU longitudinal acceleration sensor";
  Real encoderFrontSpeed(unit="rad/s") "front wheel encoder angular speed";
  Real encoderFrontPosition(unit="rad") "front wheel encoder angular position";
  Real encoderSteerAngle(unit="rad") "steering encoder angle";
  Real tauSteerStop(unit="N.m") "steering travel hard-stop torque";

  Real tauRear1(unit="N.m") = 0.0 "passive rear wheel 1 torque";
  Real tauRear2(unit="N.m") = 0.0 "passive rear wheel 2 torque";
  Real FtractionRear1(unit="N") = 0.0 "passive rear wheel 1 traction force";
  Real FtractionRear2(unit="N") = 0.0 "passive rear wheel 2 traction force";

  discrete Real tauDriveCmd(unit="N.m", start=0.0) "front traction torque command";
  discrete Real tauSteerCmd(unit="N.m", start=0.0) "front steering torque command";
  discrete Integer mode(start=MODE_ACCEL) "deterministic emergency-stop state machine";
  discrete Real vRefEff(unit="m/s", start=1.2) "effective commanded speed";
  discrete Real FdistEst(unit="N", start=0.0) "estimated payload disturbance";
  discrete Real FdistMeas(unit="N", start=0.0) "measured payload disturbance";
  discrete Real vPrevSample(unit="m/s", start=0.0) "previous sampled speed";
  discrete Boolean brakingMonotonicOK(start=true) "monotonic braking indicator";
  discrete Real cameraDistance(unit="m", start=7.0) "depth camera range to barrier";
  discrete Boolean cameraValid(start=true) "depth camera validity";
  discrete Boolean cameraTrigger(start=false) "obstacle inside safety range";

  Real stoppingMargin(unit="m") "remaining distance to barrier";
  Real primaryTrackingError(unit="m") "stopping-margin tracking error";

  Boolean speedLimitOK "speed limit acceptance";
  Boolean effortLimitOK "effort limit acceptance";
  Boolean noBarrierCollisionOK "no collision acceptance";
  Boolean residualSpeedOK "residual speed acceptance after 10.4 s";
  Boolean primaryTrackingErrorOK "primary tracking-error acceptance after 10.4 s";
  Boolean noNaNInfOK "finite physical, control, and estimator values";
  Boolean failClosedOK "fail-closed emergency-stop behavior";
  Boolean acceptanceOK "aggregate acceptance";

protected
  discrete Real tauDriveRaw(unit="N.m", start=0.0) "unsaturated drive torque";
  discrete Real tauSteerRaw(unit="N.m", start=0.0) "unsaturated steering torque";

algorithm
  when sample(0.0, Tcamera) then
    cameraDistance := max(0.0, xBarrier - x);
    cameraValid := true;
    cameraTrigger := cameraDistance <= safetyRange;
  end when;

  when sample(0.0, Tctrl) then
    brakingMonotonicOK := (pre(mode) <> MODE_BRAKE) or (v <= pre(vPrevSample) + 1e-9);
    vPrevSample := v;

    FdistMeas := m_total*imuAcceleration - tauDriveCmd/r_front;
    FdistEst := (1.0 - estAlpha)*pre(FdistEst) + estAlpha*FdistMeas;

    mode := pre(mode);
    if pre(mode) == MODE_ACCEL and v >= vRef - vRefTol then
      mode := MODE_CRUISE;
    end if;
    if (cameraTrigger or not cameraValid) and pre(mode) <> MODE_HOLD then
      mode := MODE_BRAKE;
    end if;
    if pre(mode) == MODE_BRAKE and abs(v) <= vHoldTol then
      mode := MODE_HOLD;
    end if;
    if pre(mode) == MODE_HOLD and abs(v) > vStopTol then
      mode := MODE_BRAKE;
    end if;

    vRefEff := if mode == MODE_BRAKE or mode == MODE_HOLD then 0.0 else vRef;

    if mode == MODE_BRAKE then
      tauDriveRaw := -maxTorque;
    elseif mode == MODE_HOLD then
      tauDriveRaw := -r_front*FdistKnown - KpHold*v;
    else
      tauDriveRaw := KpSpeed*(vRef - v);
    end if;
    tauDriveCmd := max(-maxTorque, min(maxTorque, tauDriveRaw));

    tauSteerRaw := Ksteer*(0.0 - theta) - Dsteer*omegaSteer;
    tauSteerCmd := max(-maxTorque, min(maxTorque, tauSteerRaw));
  end when;

equation
  FdistKnown = if time >= TdistStart and time <= TdistEnd then FdistAmp else 0.0;

  N_total = m_total*g;
  FfrictionMax = mu*N_total;

  FtractionUnbounded = tauDriveCmd/r_front;
  Ftraction = max(-FfrictionMax, min(FfrictionMax, FtractionUnbounded));

  der(x) = v;
  der(v) = (Ftraction + FdistKnown)/m_total;

  imuAcceleration = (Ftraction + FdistKnown)/m_total;
  encoderFrontSpeed = v/r_front;
  encoderFrontPosition = x/r_front;
  encoderSteerAngle = theta;

  der(theta) = omegaSteer;
  der(omegaSteer) = (tauSteerCmd + tauSteerStop - bSteer*omegaSteer)/Jsteer;
  tauSteerStop = if theta > steerLimit then -kSteerStop*(theta - steerLimit)
    elseif theta < -steerLimit then -kSteerStop*(theta + steerLimit)
    else 0.0;

  stoppingMargin = xBarrier - x;
  primaryTrackingError = max(0.0, stopMarginTarget - stoppingMargin);

  speedLimitOK = abs(v) <= vRef + 1e-6;
  effortLimitOK = abs(tauDriveCmd) <= maxTorque + 1e-6 and abs(tauSteerCmd) <= maxTorque + 1e-6;
  noBarrierCollisionOK = x < xBarrier - 1e-3;
  residualSpeedOK = (time < 10.4) or (abs(v) < 0.05);
  primaryTrackingErrorOK = (time < 10.4) or (primaryTrackingError < 0.198);
  noNaNInfOK = abs(x) < 1e9 and abs(v) < 1e9 and abs(theta) < 1e9 and
    abs(omegaSteer) < 1e9 and abs(Ftraction) < 1e9 and abs(FdistKnown) < 1e9 and
    abs(imuAcceleration) < 1e9 and abs(tauDriveCmd) < 1e9 and abs(tauSteerCmd) < 1e9 and
    abs(FdistEst) < 1e9 and abs(FdistMeas) < 1e9 and abs(cameraDistance) < 1e9 and
    abs(vPrevSample) < 1e9 and abs(vRefEff) < 1e9;
  failClosedOK = (mode == MODE_BRAKE or mode == MODE_HOLD) or (not cameraTrigger and cameraValid);
  acceptanceOK = speedLimitOK and effortLimitOK and brakingMonotonicOK and
    noBarrierCollisionOK and residualSpeedOK and primaryTrackingErrorOK and
    noNaNInfOK and failClosedOK;

  annotation(experiment(StopTime=16.0, Tolerance=1e-6, Interval=0.004));
end TriTugBrakeE;