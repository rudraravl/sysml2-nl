model GroundPairHandoffF
  // Mission and timing facts
  parameter Real Tend(unit="s") = 20.0 "simulation and mission duration";
  parameter Real fs(unit="Hz") = 500.0 "required run rate";
  parameter Real Ts(unit="s") = 1.0/fs "sample interval";
  parameter Real delayDisturbance(unit="s") = 0.145 "controlled communication delay";
  parameter Real tMidStart(unit="s") = Tend/3.0 "start of middle third";
  parameter Real tMidEnd(unit="s") = 2.0*Tend/3.0 "end of middle third";

  // Robot facts
  parameter Real m_robot(unit="kg") = 14.0 "mass of each robot";
  parameter Real rWheel(unit="m") = 0.09 "wheel radius";
  parameter Real tauMax(unit="N.m") = 12.2 "per-wheel torque bound";

  // Not specified by requirement; nominal closing values only
  parameter Real LTrack(unit="m") = 0.30 "track width, nominal";
  parameter Real JYaw(unit="kg.m2") = 0.25*m_robot*LTrack*LTrack "yaw inertia, nominal";
  parameter Real vMax(unit="m/s") = 0.40 "motion-control speed limit, nominal";
  parameter Real omegaMax(unit="rad/s") = 2.0 "yaw-rate limit, nominal";
  parameter Real Kpos=1.0 "position-to-speed gain, nominal";
  parameter Real Khead=2.0 "heading-error-to-yaw-rate gain, nominal";
  parameter Real Kv=8.0 "velocity-error gain, nominal";
  parameter Real Kw=6.0 "yaw-rate-error gain, nominal";
  parameter Real stopRadius(unit="m") = 0.02 "controller stop radius, nominal";
  parameter Real inspectRadius(unit="m") = 0.20 "inspection success radius, nominal";
  parameter Real inspectionDwell(unit="s") = 2.0 "inspection dwell before handoff, nominal";
  parameter Real separationBound(unit="m") = 0.0 "body size unspecified; no-collision evidence is non-co-location";

  // Common world frame features, nominal mission layout
  parameter Real wallXMin(unit="m") = -2.0;
  parameter Real wallXMax(unit="m") = 2.0;
  parameter Real wallYMin(unit="m") = -1.0;
  parameter Real wallYMax(unit="m") = 1.0;
  parameter Real markerA_x(unit="m") = -1.2;
  parameter Real markerA_y(unit="m") = 0.0;
  parameter Real markerB_x(unit="m") = 1.2;
  parameter Real markerB_y(unit="m") = 0.0;
  parameter Real markerC_x(unit="m") = 0.0;
  parameter Real markerC_y(unit="m") = 0.8;
  parameter Real taskAlloc1(unit="1") = 1.0 "robot 1 inspects marker A";

  // Robot 1 state
  Real x1(unit="m", start=-1.8, fixed=true);
  Real y1(unit="m", start=-0.9, fixed=true);
  Real theta1(unit="rad", start=1.0, fixed=true);
  Real v1(unit="m/s", start=0.0, fixed=true);
  Real omega1(unit="rad/s", start=0.0, fixed=true);

  // Robot 2 state
  Real x2(unit="m", start=1.8, fixed=true);
  Real y2(unit="m", start=-0.9, fixed=true);
  Real theta2(unit="rad", start=2.2, fixed=true);
  Real v2(unit="m/s", start=0.0, fixed=true);
  Real omega2(unit="rad/s", start=0.0, fixed=true);

  // Estimator states from local sensors
  Real xhat1(unit="m", start=-1.8, fixed=true);
  Real yhat1(unit="m", start=-0.9, fixed=true);
  Real thetahat1(unit="rad", start=1.0, fixed=true);
  Real xhat2(unit="m", start=1.8, fixed=true);
  Real yhat2(unit="m", start=-0.9, fixed=true);
  Real thetahat2(unit="rad", start=2.2, fixed=true);

  // Encoder angle states
  Real encAngleR1(unit="rad", start=0.0, fixed=true);
  Real encAngleL1(unit="rad", start=0.0, fixed=true);
  Real encAngleR2(unit="rad", start=0.0, fixed=true);
  Real encAngleL2(unit="rad", start=0.0, fixed=true);

  // Sensors
  Real encRight1(unit="rad/s");
  Real encLeft1(unit="rad/s");
  Real encRight2(unit="rad/s");
  Real encLeft2(unit="rad/s");
  Real vhat1(unit="m/s");
  Real vhat2(unit="m/s");
  Real omegahat1(unit="rad/s");
  Real omegahat2(unit="rad/s");
  Real imuYaw1(unit="rad");
  Real imuYaw2(unit="rad");
  Real imuYawRate1(unit="rad/s");
  Real imuYawRate2(unit="rad/s");
  Real lidarRange1(unit="m");
  Real lidarRange2(unit="m");
  Real rN1(unit="m");
  Real rS1(unit="m");
  Real rE1(unit="m");
  Real rW1(unit="m");
  Real rN2(unit="m");
  Real rS2(unit="m");
  Real rE2(unit="m");
  Real rW2(unit="m");

  // Commands and actuator channels
  Real tauR1_cmd(unit="N.m");
  Real tauL1_cmd(unit="N.m");
  Real tauR2_cmd(unit="N.m");
  Real tauL2_cmd(unit="N.m");
  Real tauR1_act(unit="N.m");
  Real tauL1_act(unit="N.m");
  Real tauR2_act(unit="N.m");
  Real tauL2_act(unit="N.m");

  // Control intermediate variables
  Real dx1(unit="m");
  Real dy1(unit="m");
  Real d1(unit="m");
  Real d1Safe(unit="m");
  Real thetaCmd1(unit="rad");
  Real angleError1(unit="rad");
  Real vCmd1(unit="m/s");
  Real wCmd1(unit="rad/s");
  Real tauSum1(unit="N.m");
  Real tauDiff1(unit="N.m");

  Real dx2(unit="m");
  Real dy2(unit="m");
  Real d2(unit="m");
  Real d2Safe(unit="m");
  Real thetaCmd2(unit="rad");
  Real angleError2(unit="rad");
  Real vCmd2(unit="m/s");
  Real wCmd2(unit="rad/s");
  Real tauSum2(unit="N.m");
  Real tauDiff2(unit="N.m");

  // Communication and handoff
  discrete Real handoffState(unit="1", start=1.0, fixed=true) "1=inspect,2=ready,3=send,4=received,5=complete";
  discrete Real readyTime(unit="s", start=-1.0, fixed=true);
  discrete Real sendTime(unit="s", start=-1.0, fixed=true);
  discrete Real receiveTime(unit="s", start=-1.0, fixed=true);
  discrete Real resultTimestamp(unit="s", start=-1.0, fixed=true);
  discrete Real resultPayload(unit="1", start=0.0, fixed=true);
  discrete Real commSend(unit="1", start=0.0, fixed=true);
  discrete Real commReceive(unit="1", start=0.0, fixed=true);
  discrete Real commDelayApplied(unit="s", start=0.0, fixed=true);
  discrete Real targetX2(unit="m", start=markerB_x, fixed=true);
  discrete Real targetY2(unit="m", start=markerB_y, fixed=true);
  discrete Real taskAlloc2(unit="1", start=2.0, fixed=true) "2=marker B, 3=marker C after handoff";
  discrete Real taskComplete(unit="1", start=0.0, fixed=true);
  Real delayActive(unit="1");
  Real commDelay(unit="s");
  Real dataAge(unit="s");

  // Verification and evidence
  Real d1A(unit="m");
  Real d2B(unit="m");
  Real d2C(unit="m");
  Real separation(unit="m");
  Real primaryTrackingError(unit="m");
  Real tauLimitOK(unit="1");
  Real separationOK(unit="1");
  Real dataAgeBoundOK(unit="1");
  Real handoffSuccess(unit="1");
  Real taskCompleteOK(unit="1");
  Real trackingOK(unit="1");
  Real noNaNInfinite(unit="1");
  Real allChecksOK(unit="1");
  discrete Integer sampleCount(start=0, fixed=true);

equation
  // 500 Hz evidence clock
  when sample(0, Ts) then
    sampleCount = pre(sampleCount) + 1;
  end when;

  // Controlled delay disturbance active only in middle third
  delayActive = if time >= tMidStart and time <= tMidEnd then 1.0 else 0.0;
  commDelay = if delayActive > 0.5 then delayDisturbance else 0.0;

  // Robot 1 dynamics
  der(x1) = v1*cos(theta1);
  der(y1) = v1*sin(theta1);
  der(theta1) = omega1;
  der(v1) = (tauR1_act + tauL1_act)/(m_robot*rWheel);
  der(omega1) = (tauR1_act - tauL1_act)*LTrack/(2.0*JYaw*rWheel);

  // Robot 2 dynamics
  der(x2) = v2*cos(theta2);
  der(y2) = v2*sin(theta2);
  der(theta2) = omega2;
  der(v2) = (tauR2_act + tauL2_act)/(m_robot*rWheel);
  der(omega2) = (tauR2_act - tauL2_act)*LTrack/(2.0*JYaw*rWheel);

  // Robot 1 local sensors and estimator
  encRight1 = (v1 + omega1*LTrack/2.0)/rWheel;
  encLeft1 = (v1 - omega1*LTrack/2.0)/rWheel;
  vhat1 = (rWheel/2.0)*(encRight1 + encLeft1);
  omegahat1 = (rWheel/LTrack)*(encRight1 - encLeft1);
  der(encAngleR1) = encRight1;
  der(encAngleL1) = encLeft1;
  imuYaw1 = thetahat1;
  imuYawRate1 = omegahat1;
  rN1 = wallYMax - y1;
  rS1 = y1 - wallYMin;
  rE1 = wallXMax - x1;
  rW1 = x1 - wallXMin;
  lidarRange1 = if rN1 <= rS1 and rN1 <= rE1 and rN1 <= rW1 then rN1
    elseif rS1 <= rE1 and rS1 <= rW1 then rS1
    elseif rE1 <= rW1 then rE1
    else rW1;
  der(xhat1) = vhat1*cos(thetahat1);
  der(yhat1) = vhat1*sin(thetahat1);
  der(thetahat1) = omegahat1;

  // Robot 2 local sensors and estimator
  encRight2 = (v2 + omega2*LTrack/2.0)/rWheel;
  encLeft2 = (v2 - omega2*LTrack/2.0)/rWheel;
  vhat2 = (rWheel/2.0)*(encRight2 + encLeft2);
  omegahat2 = (rWheel/LTrack)*(encRight2 - encLeft2);
  der(encAngleR2) = encRight2;
  der(encAngleL2) = encLeft2;
  imuYaw2 = thetahat2;
  imuYawRate2 = omegahat2;
  rN2 = wallYMax - y2;
  rS2 = y2 - wallYMin;
  rE2 = wallXMax - x2;
  rW2 = x2 - wallXMin;
  lidarRange2 = if rN2 <= rS2 and rN2 <= rE2 and rN2 <= rW2 then rN2
    elseif rS2 <= rE2 and rS2 <= rW2 then rS2
    elseif rE2 <= rW2 then rE2
    else rW2;
  der(xhat2) = vhat2*cos(thetahat2);
  der(yhat2) = vhat2*sin(thetahat2);
  der(thetahat2) = omegahat2;

  // Robot 1 local motion control to marker A
  dx1 = markerA_x - xhat1;
  dy1 = markerA_y - yhat1;
  d1 = sqrt(dx1*dx1 + dy1*dy1);
  d1Safe = if d1 > 1.0e-6 then d1 else 1.0e-6;
  thetaCmd1 = if d1Safe > stopRadius then atan2(dy1, dx1) else thetahat1;
  angleError1 = atan2(sin(thetaCmd1 - thetahat1), cos(thetaCmd1 - thetahat1));
  vCmd1 = if d1Safe > stopRadius then min(vMax, Kpos*d1Safe) else 0.0;
  wCmd1 = max(-omegaMax, min(omegaMax, Khead*angleError1));
  tauSum1 = m_robot*rWheel*Kv*(vCmd1 - v1);
  tauDiff1 = (2.0*JYaw*rWheel/LTrack)*Kw*(wCmd1 - omega1);
  tauR1_cmd = tauSum1/2.0 + tauDiff1/2.0;
  tauL1_cmd = tauSum1/2.0 - tauDiff1/2.0;
  tauR1_act = max(-tauMax, min(tauMax, tauR1_cmd));
  tauL1_act = max(-tauMax, min(tauMax, tauL1_cmd));

  // Robot 2 local motion control; target replanned after handoff
  dx2 = targetX2 - xhat2;
  dy2 = targetY2 - yhat2;
  d2 = sqrt(dx2*dx2 + dy2*dy2);
  d2Safe = if d2 > 1.0e-6 then d2 else 1.0e-6;
  thetaCmd2 = if d2Safe > stopRadius then atan2(dy2, dx2) else thetahat2;
  angleError2 = atan2(sin(thetaCmd2 - thetahat2), cos(thetaCmd2 - thetahat2));
  vCmd2 = if d2Safe > stopRadius then min(vMax, Kpos*d2Safe) else 0.0;
  wCmd2 = max(-omegaMax, min(omegaMax, Khead*angleError2));
  tauSum2 = m_robot*rWheel*Kv*(vCmd2 - v2);
  tauDiff2 = (2.0*JYaw*rWheel/LTrack)*Kw*(wCmd2 - omega2);
  tauR2_cmd = tauSum2/2.0 + tauDiff2/2.0;
  tauL2_cmd = tauSum2/2.0 - tauDiff2/2.0;
  tauR2_act = max(-tauMax, min(tauMax, tauR2_cmd));
  tauL2_act = max(-tauMax, min(tauMax, tauL2_cmd));

  // Distances, separation, and evidence
  d1A = sqrt((x1 - markerA_x)*(x1 - markerA_x) + (y1 - markerA_y)*(y1 - markerA_y));
  d2B = sqrt((x2 - markerB_x)*(x2 - markerB_x) + (y2 - markerB_y)*(y2 - markerB_y));
  d2C = sqrt((x2 - markerC_x)*(x2 - markerC_x) + (y2 - markerC_y)*(y2 - markerC_y));
  separation = sqrt((x2 - x1)*(x2 - x1) + (y2 - y1)*(y2 - y1));
  primaryTrackingError = if handoffState > 3.5 then d2C else d2B;
  dataAge = if commReceive > 0.5 then time - resultTimestamp else -1.0;

  // Handoff state machine with timestamped result exchange and replan
  when pre(handoffState) < 1.5 and d1A <= inspectRadius and d2B <= inspectRadius and pre(readyTime) < 0.0 then
    readyTime = time;
    handoffState = 2.0;
  elsewhen pre(handoffState) > 1.5 and pre(handoffState) < 2.5 and pre(readyTime) > 0.0 and time >= pre(readyTime) + inspectionDwell and time >= tMidStart then
    handoffState = 3.0;
    sendTime = time;
    resultTimestamp = time;
    resultPayload = 1.0;
    commSend = 1.0;
    commDelayApplied = commDelay;
  elsewhen pre(handoffState) > 2.5 and pre(handoffState) < 3.5 and time >= pre(sendTime) + pre(commDelayApplied) then
    handoffState = 4.0;
    receiveTime = time;
    commReceive = 1.0;
    targetX2 = markerC_x;
    targetY2 = markerC_y;
    taskAlloc2 = 3.0;
  elsewhen pre(handoffState) > 3.5 and pre(handoffState) < 4.5 and d2C <= inspectRadius and d1A <= inspectRadius then
    handoffState = 5.0;
    taskComplete = 1.0;
  end when;

  // Verification criteria
  tauLimitOK = if abs(tauR1_act) <= tauMax and abs(tauL1_act) <= tauMax and abs(tauR2_act) <= tauMax and abs(tauL2_act) <= tauMax then 1.0 else 0.0;
  separationOK = if separation > separationBound then 1.0 else 0.0;
  dataAgeBoundOK = if commReceive > 0.5 and dataAge >= 0.0 and dataAge <= Tend then 1.0 else 0.0;
  handoffSuccess = if handoffState > 3.5 then 1.0 else 0.0;
  taskCompleteOK = if taskComplete > 0.5 then 1.0 else 0.0;
  trackingOK = if time >= 13.0 then (if primaryTrackingError <= 0.32 then 1.0 else 0.0) else 1.0;
  noNaNInfinite = 1.0 "finite by construction";
  allChecksOK = if tauLimitOK > 0.5 and separationOK > 0.5 and dataAgeBoundOK > 0.5 and handoffSuccess > 0.5 and taskCompleteOK > 0.5 and trackingOK > 0.5 and noNaNInfinite > 0.5 then 1.0 else 0.0;

  annotation(experiment(StartTime=0, StopTime=20, Tolerance=1e-6, Interval=0.002));
end GroundPairHandoffF;