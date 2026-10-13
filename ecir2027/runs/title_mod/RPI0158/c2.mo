model SCARACarryB
  // Geometry and masses
  parameter Real l1=0.48 "link 1 length, m";
  parameter Real l2=0.34 "link 2 length, m";
  parameter Real zTravel=0.30 "prismatic carriage travel, m";
  parameter Real mBase=28.0 "fixed cylindrical base mass, kg";
  parameter Real m1=6.0 "link 1 moving mass, kg";
  parameter Real m2=4.0 "link 2 moving mass, kg";
  parameter Real m3=2.0 "carriage/tool moving mass, kg";
  parameter Real mp=8.4 "injected payload disturbance mass, kg";

  // Actuator bounds
  parameter Real tauMax=77.9 "revolute torque magnitude limit, N.m";
  parameter Real fMax=900.0 "prismatic force magnitude limit, N";
  parameter Real fWristLimit=60.0 "wrist force limit, N";
  parameter Real trackLimit=0.054 "primary tracking error limit after 6.5 s";

  // Mission timing
  parameter Real Tfinal=10.0 "mission duration, s";
  parameter Real Tmove=3.0 "reference motion duration, s";
  parameter Real T0=10.0/3.0 "middle-third payload start, s";
  parameter Real T1=20.0/3.0 "middle-third payload end, s";
  parameter Real tr=0.05 "payload injection transition time, s";

  // Initial and final pose
  parameter Real q1Start=0.20 "initial joint 1 angle, rad";
  parameter Real q1Final=0.60 "final joint 1 angle, rad";
  parameter Real q2Start=-0.20 "initial joint 2 angle, rad";
  parameter Real q2Final=-0.60 "final joint 2 angle, rad";
  parameter Real zStart=0.05 "initial carriage height, m";
  parameter Real zFinal=0.20 "final carriage height, m";
  parameter Real phiDes=0.0 "requested end-effector Z orientation, rad";

  // Control gains
  parameter Real Kp1=100.0 "joint 1 proportional gain, 1/s^2";
  parameter Real Kd1=20.0 "joint 1 derivative gain, 1/s";
  parameter Real Kp2=100.0 "joint 2 proportional gain, 1/s^2";
  parameter Real Kd2=20.0 "joint 2 derivative gain, 1/s";
  parameter Real Kpz=300.0 "prismatic proportional gain, 1/s^2";
  parameter Real Kdz=30.0 "prismatic derivative gain, 1/s";
  parameter Real Kw=0.5 "wrist-force correction gain";
  parameter Real fCorrMax=20.0 "bounded wrist-force correction magnitude, N";

  // Physical constants
  parameter Real g=9.81 "gravity acceleration, m/s^2";
  parameter Real pi=3.141592653589793;

  // Collision geometry
  parameter Real zFloor=0.0 "rigid floor plane height, m";
  parameter Real rTip=0.02 "tool tip radius, m";
  parameter Real zTable=0.12 "table top height, m";
  parameter Real xTable=0.40 "table center x, m";
  parameter Real yTable=-0.40 "table center y, m";
  parameter Real rTable=0.05 "table radius, m";
  parameter Real kContact=1.0e5 "contact stiffness, N/m";
  parameter Real dContact=1.0e3 "contact damping, N.s/m";

  // Joint travel limits
  parameter Real q1Limit=1.5707963 "joint 1 travel bound, rad";
  parameter Real q2Limit=1.5707963 "joint 2 travel bound, rad";

  // Physical states
  Real q1(start=q1Start, fixed=true) "joint 1 angle, rad";
  Real qd1(start=0.0, fixed=true) "joint 1 velocity, rad/s";
  Real q2(start=q2Start, fixed=true) "joint 2 angle, rad";
  Real qd2(start=0.0, fixed=true) "joint 2 velocity, rad/s";
  Real z(start=zStart, fixed=true) "prismatic carriage height, m";
  Real zd(start=0.0, fixed=true) "prismatic carriage velocity, m/s";

  // Actuator commands (continuous-time, sampled via ZOH approximated as continuous)
  Real tau1Raw "raw joint 1 torque, N.m";
  Real tau2Raw "raw joint 2 torque, N.m";
  Real tauFRaw "raw prismatic force, N";
  Real tau1Sat "saturated joint 1 torque, N.m";
  Real tau2Sat "saturated joint 2 torque, N.m";
  Real tauFSat "saturated prismatic force, N";

  // Derived physical quantities
  Real ddq1 "joint 1 acceleration, rad/s^2";
  Real ddq2 "joint 2 acceleration, rad/s^2";
  Real ddz "prismatic acceleration, m/s^2";
  Real mpActive "active payload disturbance mass, kg";
  Real mt "total wrist mass including active payload, kg";
  Real phi "end-effector Z orientation, rad";
  Real xw "end-effector x, m";
  Real yw "end-effector y, m";
  Real zTip "tool tip z, m";

  // Dynamics intermediate variables
  Real M11 "mass matrix element 11";
  Real M12 "mass matrix element 12";
  Real M22 "mass matrix element 22";
  Real bCor "Coriolis coefficient";
  Real dC "Coriolis coefficient";
  Real C1 "Coriolis term joint 1";
  Real C2 "Coriolis term joint 2";
  Real Dsafe "determinant safeguard";

  // Collision
  Real dxT "table x offset, m";
  Real dyT "table y offset, m";
  Real rT "table radial distance, m";
  Real penF "floor penetration, m";
  Real FcF "floor contact force, N";
  Real penT "table penetration, m";
  Real FcT "table contact force, N";
  Real FcontactZ "vertical contact force, N";
  Real baseReactionForce "floor reaction supporting fixed base, N";
  Real payloadRetentionForce "payload retention normal force, N";
  Boolean payloadRetained "payload retention flag";

  // Wrist wrench sensor
  Real axw "end-effector x acceleration, m/s^2";
  Real ayw "end-effector y acceleration, m/s^2";
  Real wrenchFx "wrist force x, N";
  Real wrenchFy "wrist force y, N";
  Real wrenchFz "wrist force z, N";
  Real wrenchTx "wrist torque x, N.m";
  Real wrenchTy "wrist torque y, N.m";
  Real wrenchTz "wrist torque z, N.m";
  Real wristForceNorm "wrist force magnitude, N";

  // Joint encoders
  Real qEnc1 "encoder joint 1, rad";
  Real qEnc2 "encoder joint 2, rad";
  Real zEnc "encoder prismatic position, m";

  // Reference trajectory
  Real u "normalized motion time";
  Real sProf "motion profile position";
  Real sd "motion profile velocity, 1/s";
  Real sdd "motion profile acceleration, 1/s^2";
  Real q1Des "desired joint 1, rad";
  Real qd1Des "desired joint 1 velocity, rad/s";
  Real qdd1Des "desired joint 1 acceleration, rad/s^2";
  Real q2Des "desired joint 2, rad";
  Real qd2Des "desired joint 2 velocity, rad/s";
  Real qdd2Des "desired joint 2 acceleration, rad/s^2";
  Real zDes "desired carriage height, m";
  Real zdDes "desired carriage velocity, m/s";
  Real zddDes "desired carriage acceleration, m/s^2";
  Real phiDesTraj "desired end-effector orientation, rad";
  Real xwDes "desired end-effector x, m";
  Real ywDes "desired end-effector y, m";

  // Tracking and constraint monitors
  Real primaryError "primary tracking error, rad or m";
  Real poseErrorPos "end-effector position error, m";
  Real orientationError "end-effector orientation error, rad";
  Real e1 "tracking error joint 1, rad";
  Real e2 "tracking error joint 2, rad";
  Real ez "tracking error prismatic, m";
  Real ed1 "velocity error joint 1, rad/s";
  Real ed2 "velocity error joint 2, rad/s";
  Real edz "velocity error prismatic, m/s";
  Real ddq1c "computed acceleration joint 1, rad/s^2";
  Real ddq2c "computed acceleration joint 2, rad/s^2";
  Real ddzc "computed acceleration prismatic, m/s^2";
  Real fXraw "raw wrist correction x, N";
  Real fYraw "raw wrist correction y, N";
  Real fZraw "raw wrist correction z, N";
  Real fCorrMagRaw "correction magnitude raw, N";
  Real fCorrScale "correction scale factor";
  Real fCorrX "bounded correction x, N";
  Real fCorrY "bounded correction y, N";
  Real fCorrZ "bounded correction z, N";
  Real Jx1 "Jacobian element x1";
  Real Jy1 "Jacobian element y1";
  Real Jx2 "Jacobian element x2";
  Real Jy2 "Jacobian element y2";
  Real fCorr1 "correction joint 1, N.m";
  Real fCorr2 "correction joint 2, N.m";
  Real fCorrF "correction prismatic, N";
  Boolean joint1OK;
  Boolean joint2OK;
  Boolean jointZOK;
  Boolean effort1OK;
  Boolean effort2OK;
  Boolean effortFOK;
  Boolean wristForceOK;
  Boolean trackingOK;
  Boolean orientationOK;
  Boolean finiteValuesOK;
  Boolean missionOK;

  // Payload schedule
  Real rise1 "rise portion";
  Real pulseVal "smooth pulse value for payload";

equation
  // Payload disturbance schedule - smooth pulse
  rise1 = if time < T0 then 0.0 elseif time < T0 + tr then 0.5*(1.0 - cos(pi*(time - T0)/tr)) elseif time < T1 - tr then 1.0 elseif time < T1 then 0.5*(1.0 + cos(pi*(time - T1 + tr)/tr)) else 0.0;
  pulseVal = rise1;
  mpActive = mp*pulseVal;
  mt = m3 + mpActive;

  // Reference motion profile
  u = if time <= Tmove then time/Tmove else 1.0;
  sProf = if u <= 0.0 then 0.0 elseif u >= 1.0 then 1.0 else 10.0*u^3 - 15.0*u^4 + 6.0*u^5;
  sd = if u <= 0.0 or u >= 1.0 then 0.0 else (30.0*u^2 - 60.0*u^3 + 30.0*u^4)/Tmove;
  sdd = if u <= 0.0 or u >= 1.0 then 0.0 else (60.0*u - 180.0*u^2 + 120.0*u^3)/(Tmove*Tmove);

  q1Des = q1Start + (q1Final - q1Start)*sProf;
  qd1Des = (q1Final - q1Start)*sd;
  qdd1Des = (q1Final - q1Start)*sdd;
  q2Des = q2Start + (q2Final - q2Start)*sProf;
  qd2Des = (q2Final - q2Start)*sd;
  qdd2Des = (q2Final - q2Start)*sdd;
  zDes = zStart + (zFinal - zStart)*sProf;
  zdDes = (zFinal - zStart)*sd;
  zddDes = (zFinal - zStart)*sdd;
  phiDesTraj = q1Des + q2Des;
  xwDes = l1*cos(q1Des) + l2*cos(phiDesTraj);
  ywDes = l1*sin(q1Des) + l2*sin(phiDesTraj);

  // Kinematics
  phi = q1 + q2;
  xw = l1*cos(q1) + l2*cos(phi);
  yw = l1*sin(q1) + l2*sin(phi);
  zTip = z - rTip;

  // Dynamics mass matrix and Coriolis terms
  M11 = m1*l1^2/3.0 + m2*(l1^2 + l2^2/3.0 + l1*l2*cos(q2)) + mt*(l1^2 + l2^2 + 2.0*l1*l2*cos(q2));
  M12 = m2*(l2^2/3.0 + 0.5*l1*l2*cos(q2)) + mt*(l2^2 + l1*l2*cos(q2));
  M22 = (m2/3.0 + mt)*l2^2;
  bCor = m2*l1*l2 + 2.0*mt*l1*l2;
  dC = 0.5*m2*l1*l2 + mt*l1*l2;
  C1 = -bCor*sin(q2)*qd1*qd2 - dC*sin(q2)*qd2^2;
  C2 = dC*sin(q2)*qd1^2;
  Dsafe = if M11*M22 - M12*M12 > 1.0e-9 then M11*M22 - M12*M12 else 1.0e-9;

  // State derivatives
  der(q1) = qd1;
  der(qd1) = ddq1;
  der(q2) = qd2;
  der(qd2) = ddq2;
  der(z) = zd;
  der(zd) = ddz;

  // Forward dynamics from saturated commands
  ddq1 = (M22*(tau1Sat - C1) - M12*(tau2Sat - C2))/Dsafe;
  ddq2 = (M11*(tau2Sat - C2) - M12*(tau1Sat - C1))/Dsafe;
  ddz = (tauFSat - mt*g + FcontactZ)/mt;

  // Collision model for floor and table
  dxT = xw - xTable;
  dyT = yw - yTable;
  rT = sqrt(dxT*dxT + dyT*dyT + 1.0e-12);
  penF = zFloor - zTip;
  FcF = if noEvent(penF > 0.0) then kContact*penF - dContact*zd else 0.0;
  FcF = if noEvent(penF > 0.0) then (if FcF > 0.0 then FcF else 0.0) else 0.0;
  penT = zTable - zTip;
  FcT = if noEvent(penT > 0.0 and rT <= rTable + rTip) then kContact*penT - dContact*zd else 0.0;
  FcT = if noEvent(penT > 0.0 and rT <= rTable + rTip) then (if FcT > 0.0 then FcT else 0.0) else 0.0;
  FcontactZ = FcF + FcT;

  // Base reaction and payload retention monitor
  baseReactionForce = (mBase + m1 + m2 + m3 + mpActive)*g;
  payloadRetentionForce = if mpActive > 0.0 then mpActive*(g + ddz) else 0.0;
  payloadRetained = (mpActive <= 0.0) or (payloadRetentionForce >= 0.0);

  // Wrist wrench sensor and encoders
  axw = -l1*cos(q1)*qd1^2 - l1*sin(q1)*ddq1 - l2*cos(phi)*(qd1 + qd2)^2 - l2*sin(phi)*(ddq1 + ddq2);
  ayw = -l1*sin(q1)*qd1^2 + l1*cos(q1)*ddq1 - l2*sin(phi)*(qd1 + qd2)^2 + l2*cos(phi)*(ddq1 + ddq2);
  wrenchFx = mpActive*axw;
  wrenchFy = mpActive*ayw;
  wrenchFz = mpActive*ddz + FcontactZ;
  wrenchTx = 0.0;
  wrenchTy = 0.0;
  wrenchTz = 0.0;
  wristForceNorm = sqrt(wrenchFx^2 + wrenchFy^2 + wrenchFz^2 + 1.0e-12);

  qEnc1 = q1;
  qEnc2 = q2;
  zEnc = z;

  // Tracking errors
  e1 = q1Des - q1;
  e2 = q2Des - q2;
  ez = zDes - z;
  ed1 = qd1Des - qd1;
  ed2 = qd2Des - qd2;
  edz = zdDes - zd;

  // Computed-torque control law
  ddq1c = qdd1Des + Kp1*e1 + Kd1*ed1;
  ddq2c = qdd2Des + Kp2*e2 + Kd2*ed2;
  ddzc = zddDes + Kpz*ez + Kdz*edz;

  // Bounded wrist-force correction
  fXraw = -Kw*wrenchFx;
  fYraw = -Kw*wrenchFy;
  fZraw = -Kw*wrenchFz;
  fCorrMagRaw = sqrt(fXraw^2 + fYraw^2 + fZraw^2 + 1.0e-12);
  fCorrScale = if fCorrMagRaw > fCorrMax then fCorrMax/fCorrMagRaw else 1.0;
  fCorrX = fXraw*fCorrScale;
  fCorrY = fYraw*fCorrScale;
  fCorrZ = fZraw*fCorrScale;

  // Jacobian transpose mapping
  Jx1 = -l1*sin(q1) - l2*sin(q1 + q2);
  Jy1 = l1*cos(q1) + l2*cos(q1 + q2);
  Jx2 = -l2*sin(q1 + q2);
  Jy2 = l2*cos(q1 + q2);
  fCorr1 = Jx1*fCorrX + Jy1*fCorrY;
  fCorr2 = Jx2*fCorrX + Jy2*fCorrY;
  fCorrF = fCorrZ;

  // Raw commands
  tau1Raw = M11*ddq1c + M12*ddq2c + C1 + fCorr1;
  tau2Raw = M12*ddq1c + M22*ddq2c + C2 + fCorr2;
  tauFRaw = mt*ddzc + mt*g + fCorrF;

  // Saturated commands
  tau1Sat = if tau1Raw > tauMax then tauMax elseif tau1Raw < -tauMax then -tauMax else tau1Raw;
  tau2Sat = if tau2Raw > tauMax then tauMax elseif tau2Raw < -tauMax then -tauMax else tau2Raw;
  tauFSat = if tauFRaw > fMax then fMax elseif tauFRaw < -fMax then -fMax else tauFRaw;

  // Tracking and constraint monitors
  primaryError = max(abs(q1 - q1Des), max(abs(q2 - q2Des), abs(z - zDes)));
  poseErrorPos = sqrt((xw - xwDes)^2 + (yw - ywDes)^2 + (z - zDes)^2 + 1.0e-12);
  orientationError = abs(phi - phiDes);
  joint1OK = abs(q1) <= q1Limit;
  joint2OK = abs(q2) <= q2Limit;
  jointZOK = z >= -1.0e-6 and z <= zTravel + 1.0e-6;
  effort1OK = abs(tau1Sat) <= tauMax + 1.0e-6;
  effort2OK = abs(tau2Sat) <= tauMax + 1.0e-6;
  effortFOK = abs(tauFSat) <= fMax + 1.0e-6;
  wristForceOK = wristForceNorm <= fWristLimit;
  trackingOK = if time >= 6.5 then primaryError <= trackLimit else true;
  orientationOK = orientationError <= trackLimit;
  finiteValuesOK = Dsafe > 0.0 and mt > 0.0 and wristForceNorm >= 0.0 and rT >= 0.0 and primaryError >= 0.0;
  missionOK = joint1OK and joint2OK and jointZOK and effort1OK and effort2OK and effortFOK and wristForceOK and payloadRetained and trackingOK and orientationOK and finiteValuesOK;

  annotation (experiment(StopTime=10.0, Tolerance=1e-6));
end SCARACarryB;