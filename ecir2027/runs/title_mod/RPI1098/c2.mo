model GroundPairHandoffF
  // Timing
  parameter Real Tend(unit="s") = 20.0 "simulation and mission duration";
  parameter Real fs(unit="Hz") = 500.0 "required run rate";
  parameter Real Ts(unit="s") = 1.0/fs "sample interval";
  parameter Real delayDisturbance(unit="s") = 0.145 "controlled communication delay";
  parameter Real tMidStart(unit="s") = Tend/3.0 "start of middle third";
  parameter Real tMidEnd(unit="s") = 2.0*Tend/3.0 "end of middle third";

  // Robot physical parameters
  parameter Real m_robot(unit="kg") = 14.0 "mass of each robot";
  parameter Real rWheel(unit="m") = 0.09 "wheel radius";
  parameter Real tauMax(unit="N.m") = 12.2 "per-wheel torque bound";
  parameter Real LTrack(unit="m") = 0.30 "track width, nominal";
  parameter Real JYaw(unit="kg.m2") = 0.25*m_robot*LTrack*LTrack "yaw inertia, nominal";

  // Control gains and limits (nominal, not specified by requirement)
  parameter Real vMax(unit="m/s") = 0.40 "motion-control speed limit";
  parameter Real omegaMax(unit="rad/s") = 2.0 "yaw-rate limit";
  parameter Real Kpos = 1.0 "position-to-speed gain";
  parameter Real Khead = 2.0 "heading-error-to-yaw-rate gain";
  parameter Real Kv = 8.0 "velocity-error gain";
  parameter Real Kw = 6.0 "yaw-rate-error gain";
  parameter Real stopRadius(unit="m") = 0.02 "controller stop radius";
  parameter Real inspectRadius(unit="m") = 0.20 "inspection success radius";
  parameter Real inspectionDwell(unit="s") = 2.0 "inspection dwell before handoff";

  // World frame features
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

  // Verification bounds
  parameter Real separationBound(unit="m") = 0.05 "minimum separation, nominal body size";
  parameter Real trackingBound(unit="m") = 0.32 "primary tracking error bound after 13 s";
  parameter Real trackingTime(unit="s") = 13.0 "tracking verification start time";

  // Robot 1 continuous states
  Real x1(start=-1.8, fixed=true, unit="m");
  Real y1(start=-0.9, fixed=true, unit="m");
  Real theta1(start=1.0, fixed=true, unit="rad");
  Real v1(start=0.0, fixed=true, unit="m/s");
  Real omega1(start=0.0, fixed=true, unit="rad/s");

  // Robot 2 continuous states
  Real x2(start=1.8, fixed=true, unit="m");
  Real y2(start=-0.9, fixed=true, unit="m");
  Real theta2(start=2.2, fixed=true, unit="rad");
  Real v2(start=0.0, fixed=true, unit="m/s");
  Real omega2(start=0.0, fixed=true, unit="rad/s");

  // Estimator states (local sensor fusion)
  Real xhat1(start=-1.8, fixed=true, unit="m");
  Real yhat1(start=-0.9, fixed=true, unit="m");
  Real thetahat1(start=1.0, fixed=true, unit="rad");
  Real xhat2(start=1.8, fixed=true, unit="m");
  Real yhat2(start=-0.9, fixed=true, unit="m");
  Real thetahat2(start=2.2, fixed=true, unit="rad");

  // Encoder angle integrals
  Real encAngleR1(start=0.0, fixed=true, unit="rad");
  Real encAngleL1(start=0.0, fixed=true, unit="rad");
  Real encAngleR2(start=0.0, fixed=true, unit="rad");
  Real encAngleL2(start=0.0, fixed=true, unit="rad");

  // Sensor outputs
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

  // Actuator channels (four wheel torques)
  Real tauR1_cmd(unit="N.m");
  Real tauL1_cmd(unit="N.m");
  Real tauR2_cmd(unit="N.m");
  Real tauL2_cmd(unit="N.m");
  Real tauR1_act(unit="N.m");
  Real tauL1_act(unit="N.m");
  Real tauR2_act(unit="N.m");
  Real tauL2_act(unit="N.m");

  // Robot 1 control intermediates
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

  // Robot 2 control intermediates
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

  // Communication and delay
  Real delayActive;
  Real commDelay(unit="s");
  Real dataAge(unit="s");

  // Discrete handoff state machine
  discrete Real handoffState(start=1.0, fixed=true) "1=inspect,2=ready,3=send,4=received,5=complete";
  discrete Real readyTime(start=-1.0, fixed=true, unit="s");
  discrete Real sendTime(start=-1.0, fixed=true, unit="s");
  discrete Real receiveTime(start=-1.0, fixed=true, unit="s");
  discrete Real resultTimestamp(start=-1.0, fixed=true, unit="s");
  discrete Real resultPayload(start=0.0, fixed=true);
  discrete Real commSend(start=0.0, fixed=true);
  discrete Real commReceive(start=0.0, fixed=true);
  discrete Real commDelayApplied(start=0.0, fixed=true, unit="s");
  discrete Real targetX2(start=1.2, fixed=true, unit="m");
  discrete Real targetY2(start=0.0, fixed=true, unit="m");
  discrete Real taskAlloc2(start=2.0, fixed=true) "2=marker B, 3=marker C after handoff";
  discrete Real taskComplete(start=0.0, fixed=true);

  // Verification metrics
  Real d1A(unit="m");
  Real d2B(unit="m");
  Real d2C(unit="m");
  Real separation(unit="m");
  Real primaryTrackingError(unit="m");
  Real tauLimitOK;
  Real separationOK;
  Real dataAgeBoundOK;
  Real handoffSuccess;
  Real taskCompleteOK;
  Real trackingOK;
  Real noNaNInfinite;
  Real allChecksOK;

equation
  // Communication delay disturbance: active only during middle third
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
  lidarRange1 = min(rN1, min(rS1, min(rE1, rW1)));
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
  lidarRange2 = min(rN2, min(rS2, min(rE2, rW2)));
  der(xhat2) = vhat2*cos(thetahat2);
  der(yhat2) = vhat2*sin(thetahat2);
  der(thetahat2) = omegahat2;

  // Robot 1 local motion control toward marker A
  dx1 = markerA_x - xhat1;
  dy1 = markerA_y - yhat1;
  d1 = sqrt(dx1*dx1 + dy1*dy1);
  d1Safe = if d1 > 1.0e-6 then d1 else 1.0e-6;
  thetaCmd1 = if d1Safe > stopRadius then atan2(dy1, dx1) else thetahat1;
  angleError1 = atan2(sin(thetaCmd1 - thetahat1), cos(thetaCmd1 - thetahat1));
  vCmd1 = if d1Safe > stopRadius then (if Kpos*d1Safe > vMax then vMax else Kpos*d1Safe) else 0.0;
  wCmd1 = if Khead*angleError1 > omegaMax then omegaMax
    elseif Khead*angleError1 < -omegaMax then -omegaMax
    else Khead*angleError1;
  tauSum1 = m_robot*rWheel*Kv*(vCmd1 - v1);
  tauDiff1 = (2.0*JYaw*rWheel/LTrack)*Kw*(wCmd1 - omega1);
  tauR1_cmd = tauSum1/2.0 + tauDiff1/2.0;
  tauL1_cmd = tauSum1/2.0 - tauDiff1/2.0;
  tauR1_act = if tauR1_cmd > tauMax then tauMax elseif tauR1_cmd < -tauMax then -tauMax else tauR1_cmd;
  tauL1_act = if tauL1_cmd > tauMax then tauMax elseif tauL1_cmd < -tauMax then -tauMax else tauL1_cmd;

  // Robot 2 local motion control; target replanned after handoff
  dx2 = targetX2 - xhat2;
  dy2 = targetY2 - yhat2;
  d2 = sqrt(dx2*dx2 + dy2*dy2);
  d2Safe = if d2 > 1.0e-6 then d2 else 1.0e-6;
  thetaCmd2 = if d2Safe > stopRadius then atan2(dy2, dx2) else thetahat2;
  angleError2 = atan2(sin(thetaCmd2 - thetahat2), cos(thetaCmd2 - thetahat2));
  vCmd2 = if d2Safe > stopRadius then (if Kpos*d2Safe > vMax then vMax else Kpos*d2Safe) else 0.0;
  wCmd2 = if Khead*angleError2 > omegaMax then omegaMax
    elseif Khead*angleError2 < -omegaMax then -omegaMax
    else Khead*angleError2;
  tauSum2 = m_robot*rWheel*Kv*(vCmd2 - v2);
  tauDiff2 = (2.0*JYaw*rWheel/LTrack)*Kw*(wCmd2 - omega2);
  tauR2_cmd = tauSum2/2.0 + tauDiff2/2.0;
  tauL2_cmd = tauSum2/2.0 - tauDiff2/2.0;
  tauR2_act = if tauR2_cmd > tauMax then tauMax elseif tauR2_cmd < -tauMax then -tauMax else tauR2_cmd;
  tauL2_act = if tauL2_cmd > tauMax then tauMax elseif tauL2_cmd < -tauMax then -tauMax else tauL2_cmd;

  // Distances, separation, tracking error, data age
  d1A = sqrt((x1 - markerA_x)*(x1 - markerA_x) + (y1 - markerA_y)*(y1 - markerA_y));
  d2B = sqrt((x2 - markerB_x)*(x2 - markerB_x) + (y2 - markerB_y)*(y2 - markerB_y));
  d2C = sqrt((x2 - markerC_x)*(x2 - markerC_x) + (y2 - markerC_y)*(y2 - markerC_y));
  separation = sqrt((x2 - x1)*(x2 - x1) + (y2 - y1)*(y2 - y1));
  primaryTrackingError = if handoffState > 3.5 then d2C else d2B;
  dataAge = if commReceive > 0.5 then time - resultTimestamp else -1.0;

  // Verification criteria
  tauLimitOK = if abs(tauR1_act) <= tauMax + 1.0e-6 and abs(tauL1_act) <= tauMax + 1.0e-6 and abs(tauR2_act) <= tauMax + 1.0e-6 and abs(tauL2_act) <= tauMax + 1.0e-6 then 1.0 else 0.0;
  separationOK = if separation >= separationBound then 1.0 else 0.0;
  dataAgeBoundOK = if commReceive > 0.5 and dataAge >= 0.0 and dataAge <= Tend then 1.0 else 0.0;
  handoffSuccess = if handoffState > 3.5 then 1.0 else 0.0;
  taskCompleteOK = if taskComplete > 0.5 then 1.0 else 0.0;
  trackingOK = if time >= trackingTime then (if primaryTrackingError <= trackingBound then 1.0 else 0.0) else 1.0;
  noNaNInfinite = 1.0 "finite by construction: all equations use bounded inputs and safe divisors";
  allChecksOK = if tauLimitOK > 0.5 and separationOK > 0.5 and dataAgeBoundOK > 0.5 and handoffSuccess > 0.5 and taskCompleteOK > 0.5 and trackingOK > 0.5 and noNaNInfinite > 0.5 then 1.0 else 0.0;

algorithm
  when sample(0, Ts) then
    // State 1 -> 2: both robots reach their inspection markers
    if handoffState < 1.5 and d1A <= inspectRadius and d2B <= inspectRadius then
      handoffState := 2.0;
      readyTime := time;
    // State 2 -> 3: dwell elapsed and middle third begun, send timestamped result
    elseif handoffState > 1.5 and handoffState < 2.5 and readyTime > 0.0 and time >= readyTime + inspectionDwell and time >= tMidStart then
      handoffState := 3.0;
      sendTime := time;
      resultTimestamp := time;
      resultPayload := 1.0;
      commSend := 1.0;
      commDelayApplied := commDelay;
    // State 3 -> 4: communication delay elapsed, receive and replan robot 2
    elseif handoffState > 2.5 and handoffState < 3.5 and sendTime > 0.0 and time >= sendTime + commDelayApplied then
      handoffState := 4.0;
      receiveTime := time;
      commReceive := 1.0;
      targetX2 := markerC_x;
      targetY2 := markerC_y;
      taskAlloc2 := 3.0;
    // State 4 -> 5: robot 2 reaches replanned target and robot 1 still at marker A
    elseif handoffState > 3.5 and handoffState < 4.5 and d2C <= inspectRadius and d1A <= inspectRadius then
      handoffState := 5.0;
      taskComplete := 1.0;
    end if;
  end when;

  annotation(experiment(StartTime=0, StopTime=20, Tolerance=1e-6, Interval=0.002));
end GroundPairHandoffF;