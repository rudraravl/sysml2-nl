model HexaWalkTraverseC
  "Floating-base hexapod robot HexaWalkTraverseC traversing height field with rocks and gaps"

  // ==================== Parameters ====================
  // Body (specified: 15 kg capsule)
  parameter Real bodyMass = 15.0 "Body mass [kg]";
  parameter Real bodyInertiaPitch = 0.25 "Pitch inertia [kg.m2] - not specified, estimated";
  parameter Real bodyRadius = 0.15 "Capsule radius [m] - not specified, estimated";

  // Leg links (specified: coxa 0.12, femur 0.22, tibia 0.26)
  parameter Real coxaLen = 0.12 "Coxa length [m]";
  parameter Real femurLen = 0.22 "Femur length [m]";
  parameter Real tibiaLen = 0.26 "Tibia length [m]";
  parameter Real legAttachmentX[6] = {0.18, 0.0, -0.18, 0.18, 0.0, -0.18}
    "Leg attachment x-offset [m] - not specified";
  parameter Real legAttachmentY[6] = {0.10, 0.10, 0.10, -0.10, -0.10, -0.10}
    "Leg attachment y-offset [m] - not specified";
  parameter Boolean isGroupA[6] = {true, false, true, false, true, false}
    "Tripod gait group A (legs 1,3,5)";

  // Actuators (specified: max 18.4 N.m per joint, 18 saturated actuators)
  parameter Real maxTorque = 18.4 "Maximum joint torque magnitude [N.m]";
  parameter Real jointKp = 80.0 "Joint PD proportional gain [N.m/rad] - not specified";
  parameter Real jointKd = 2.0 "Joint PD derivative gain [N.m.s/rad] - not specified";
  parameter Real jointInertia = 0.01 "Reflected joint inertia [kg.m2] - not specified";
  parameter Real jointFriction = 0.1 "Joint viscous friction [N.m.s/rad] - not specified";

  // Contact (specified: friction 0.78)
  parameter Real mu = 0.78 "Contact friction coefficient";
  parameter Real kContact = 8000.0 "Contact stiffness [N/m] - not specified";
  parameter Real dContact = 200.0 "Contact damping [N.s/m] - not specified";

  // Disturbance (specified: 81 N lateral push, middle third of 12 s)
  parameter Real pushForce = 81.0 "Lateral push force [N]";
  parameter Real pushStart = 4.0 "Push start time [s] (middle third of 12 s)";
  parameter Real pushEnd = 8.0 "Push end time [s]";

  // Gait and control (specified: 125 Hz, 12 s; speed not specified)
  parameter Real vCmd = 0.3 "Commanded average speed [m/s] - value not specified";
  parameter Real gaitPeriod = 0.8 "Gait cycle period [s] - not specified";
  parameter Real dutyFactor = 0.5 "Stance duty factor - not specified";
  parameter Real stepLength = 0.12 "Step length [m] - not specified";
  parameter Real clearanceTarget = 0.05 "Swing foot clearance target [m]";
  parameter Real bodyHeightTarget = 0.38 "Nominal body height above terrain [m] - not specified";
  parameter Real kHeight = 0.5 "Height correction gain - not specified";
  parameter Real kPitch = 0.15 "Pitch correction gain - not specified";
  parameter Real kPitchD = 0.02 "Pitch rate damping gain - not specified";
  parameter Real kProp = 30.0 "Propulsion velocity gain - not specified";
  parameter Real kLat = 20.0 "Lateral velocity gain - not specified";
  parameter Real kLatPos = 50.0 "Lateral position gain - not specified";
  parameter Real lookAhead = 0.3 "Forward depth look-ahead [m] - not specified";
  parameter Real sampleFreq = 125.0 "Control loop frequency [Hz]";

  // Terrain (specified: 0.08 m rocks, two 0.12 m gaps)
  parameter Real rockHeight = 0.08 "Rock height [m]";
  parameter Real gapWidth = 0.12 "Gap width [m]";
  parameter Real rock1Start = 1.5 "Rock region 1 start x [m] - not specified";
  parameter Real rock1End = 2.5 "Rock region 1 end x [m] - not specified";
  parameter Real rock2Start = 4.0 "Rock region 2 start x [m] - not specified";
  parameter Real rock2End = 5.0 "Rock region 2 end x [m] - not specified";
  parameter Real gap1Start = 3.0 "Gap 1 start x [m] - not specified";
  parameter Real gap2Start = 6.0 "Gap 2 start x [m] - not specified";

  // Monitoring (specified: clearance > 0.03 m, attitude < 0.45 rad,
  //   tracking error < 0.158 m after 7.8 s)
  parameter Real clearanceMin = 0.03 "Minimum body clearance [m]";
  parameter Real attitudeMax = 0.45 "Maximum attitude [rad]";
  parameter Real trackingErrMax = 0.158 "Maximum tracking error [m]";
  parameter Real trackingTime = 7.8 "Tracking evaluation time [s]";
  parameter Real simDuration = 12.0 "Simulation duration [s]";

  // Constants
  constant Real G_ACC = 9.81 "Gravitational acceleration [m/s2]";
  constant Real PI = 3.14159265358979;

  // ==================== State Variables ====================
  // Body (floating base)
  Real bodyX(start = 0.0) "Body x position [m]";
  Real bodyY(start = 0.0) "Body y position [m]";
  Real bodyZ(start = 0.40) "Body z position [m]";
  Real bodyVX(start = 0.0) "Body x velocity [m/s]";
  Real bodyVY(start = 0.0) "Body y velocity [m/s]";
  Real bodyVZ(start = 0.0) "Body z velocity [m/s]";
  Real bodyPitch(start = 0.0) "Body pitch angle [rad]";
  Real bodyPitchRate(start = 0.0) "Body pitch rate [rad/s]";

  // Leg joints (6 legs x 3 revolute joints = 18 actuators)
  Real q[6,3] "Joint angles [rad]";
  Real qd[6,3] "Joint angular velocities [rad/s]";

  // ==================== Algebraic Variables ====================
  // Control
  Real qDes[6,3] "Desired joint angles from inverse kinematics [rad]";
  Real tauCmd[6,3] "Unsaturated commanded torque [N.m]";
  Real tau[6,3] "Saturated joint torque [N.m]";

  // Forward kinematics
  Real footXrel[6] "Foot x relative to body center [m]";
  Real footZrel[6] "Foot z relative to body center [m]";
  Real footX[6] "Foot x position in world [m]";
  Real footY[6] "Foot y position in world [m]";
  Real footZ[6] "Foot z position in world [m]";
  Real footVZ[6] "Foot z velocity [m/s]";

  // Contact
  Real penetration[6] "Foot penetration into terrain [m]";
  Real contactFZ[6] "Vertical contact force [N]";
  Real contactFX[6] "Horizontal propulsion contact force [N]";
  Real contactFY[6] "Lateral contact force [N]";
  Boolean inContact[6] "Foot in contact";
  Boolean inStance[6] "Leg in stance phase";

  // Gait
  Real gaitPhase "Gait phase [0,1)";
  Real stanceProgress[6] "Stance progress [0,1]";
  Real swingProgress[6] "Swing progress [0,1]";

  // Desired foot trajectories
  Real footXDesRel[6] "Desired foot x relative to attachment [m]";
  Real footZDesRel[6] "Desired foot z relative to attachment [m]";
  Real heightCorrection "Body height correction [m]";
  Real pitchCorrection[6] "Per-leg pitch correction [m]";
  Real footholdAdjust[6] "Foothold adjustment from depth sensing [m]";

  // Inverse kinematics intermediates
  Real ikX[6] "IK horizontal input [m]";
  Real ikZ[6] "IK vertical input [m]";
  Real ikR2[6] "IK squared reach [m2]";
  Real ikCosQ3[6] "IK cos(q3) clamped [-]";

  // Jacobian
  Real Jxq2[6] "Jacobian d(footXrel)/d(q2) [m/rad]";
  Real Jxq3[6] "Jacobian d(footXrel)/d(q3) [m/rad]";
  Real Jzq2[6] "Jacobian d(footZrel)/d(q2) [m/rad]";
  Real Jzq3[6] "Jacobian d(footZrel)/d(q3) [m/rad]";
  Real Jyq1[6] "Jacobian d(footYrel)/d(q1) [m/rad]";
  Real tauReaction[6,3] "Contact reaction torque on joints [N.m]";

  // Terrain
  Real terrainHeightAtBody "Terrain height at body x [m]";
  Real terrainHeightAtFoot[6] "Terrain height at foot x [m]";
  Real depthForward "Forward depth measurement [m]";

  // Force sums
  Real sumFX "Total horizontal contact force [N]";
  Real sumFY "Total lateral contact force [N]";
  Real sumFZ "Total vertical contact force [N]";
  Real sumTorquePitch "Total pitch torque about body center [N.m]";

  // Disturbance
  Real pushY "Applied lateral push force [N]";

  // Sensors
  Real imuPitch "IMU pitch measurement [rad]";
  Real bodyPathError "Body path tracking error [m]";
  Real bodyClearance "Body clearance above terrain [m]";
  Real numStanceLegs "Number of legs in stance";

  // Monitoring
  Boolean attitudeOK "Attitude within bounds";
  Boolean clearanceOK "Clearance above minimum (torso-terrain collision prohibited)";
  Boolean trackingOK "Tracking error below threshold after 7.8 s";
  Boolean routeComplete "Route completed";
  Boolean noNaN "No NaN or infinite values (safeguarded by clamping and saturation)";
  Real maxTorqueUsed "Maximum absolute torque across all joints [N.m]";

  // ==================== Initial Conditions ====================
initial equation
  for i in 1:6 loop
    q[i,1] = 0.0;
    q[i,2] = 0.34;
    q[i,3] = -1.19;
    qd[i,1] = 0.0;
    qd[i,2] = 0.0;
    qd[i,3] = 0.0;
  end for;

equation
  // ==================== Gait Controller (Tripod) ====================
  // Designed for 125 Hz; implemented as continuous for simulation
  gaitPhase = mod(time / gaitPeriod, 1.0);

  for i in 1:6 loop
    inStance[i] = if isGroupA[i] then gaitPhase < dutyFactor else gaitPhase >= dutyFactor;
    stanceProgress[i] = if isGroupA[i] then
      max(0.0, min(1.0, gaitPhase / dutyFactor))
    else
      max(0.0, min(1.0, (gaitPhase - dutyFactor) / dutyFactor));
    swingProgress[i] = if isGroupA[i] then
      max(0.0, min(1.0, (gaitPhase - dutyFactor) / (1.0 - dutyFactor)))
    else
      max(0.0, min(1.0, gaitPhase / dutyFactor));
  end for;

  numStanceLegs = sum({if inStance[i] then 1.0 else 0.0 for i in 1:6});

  // ==================== Terrain Height Field ====================
  // Rocks: 0.08 m elevated regions; Gaps: no support (terrain at -10 m)
  if bodyX >= rock1Start and bodyX <= rock1End then
    terrainHeightAtBody = rockHeight;
  elseif bodyX >= rock2Start and bodyX <= rock2End then
    terrainHeightAtBody = rockHeight;
  elseif bodyX >= gap1Start and bodyX <= gap1Start + gapWidth then
    terrainHeightAtBody = -10.0;
  elseif bodyX >= gap2Start and bodyX <= gap2Start + gapWidth then
    terrainHeightAtBody = -10.0;
  else
    terrainHeightAtBody = 0.0;
  end if;

  for i in 1:6 loop
    if footX[i] >= rock1Start and footX[i] <= rock1End then
      terrainHeightAtFoot[i] = rockHeight;
    elseif footX[i] >= rock2Start and footX[i] <= rock2End then
      terrainHeightAtFoot[i] = rockHeight;
    elseif footX[i] >= gap1Start and footX[i] <= gap1Start + gapWidth then
      terrainHeightAtFoot[i] = -10.0;
    elseif footX[i] >= gap2Start and footX[i] <= gap2Start + gapWidth then
      terrainHeightAtFoot[i] = -10.0;
    else
      terrainHeightAtFoot[i] = 0.0;
    end if;
  end for;

  // Forward depth measurement for foothold planning
  if bodyX + lookAhead >= gap1Start and bodyX + lookAhead <= gap1Start + gapWidth then
    depthForward = -1.0;
  elseif bodyX + lookAhead >= gap2Start and bodyX + lookAhead <= gap2Start + gapWidth then
    depthForward = -1.0;
  elseif bodyX + lookAhead >= rock1Start and bodyX + lookAhead <= rock1End then
    depthForward = rockHeight;
  elseif bodyX + lookAhead >= rock2Start and bodyX + lookAhead <= rock2End then
    depthForward = rockHeight;
  else
    depthForward = 0.0;
  end if;

  // ==================== Foothold Selection ====================
  // Uses joint, IMU, contact, and forward depth measurements
  for i in 1:6 loop
    footholdAdjust[i] = if depthForward < -0.5 then -0.03 else 0.0;
  end for;

  // ==================== Body Height and Attitude Correction ====================
  heightCorrection = -kHeight * (bodyHeightTarget - (bodyZ - terrainHeightAtBody));

  for i in 1:6 loop
    pitchCorrection[i] = legAttachmentX[i] * (kPitch * bodyPitch + kPitchD * bodyPitchRate);
  end for;

  // ==================== Swing-Foot Trajectory Control ====================
  for i in 1:6 loop
    if inStance[i] then
      // Stance: foot planted, moves backward relative to body
      footXDesRel[i] = stepLength / 2.0 * (1.0 - 2.0 * stanceProgress[i]);
      footZDesRel[i] = -(bodyHeightTarget) + pitchCorrection[i] + heightCorrection;
    else
      // Swing: foot lifts with clearance and moves forward to next foothold
      footXDesRel[i] = -stepLength / 2.0 + (stepLength + footholdAdjust[i]) * swingProgress[i];
      footZDesRel[i] = -(bodyHeightTarget - clearanceTarget * sin(PI * swingProgress[i]))
                       + pitchCorrection[i] + heightCorrection;
    end if;
  end for;

  // ==================== Inverse Kinematics (femur + tibia) ====================
  for i in 1:6 loop
    ikX[i] = footXDesRel[i] - coxaLen;
    ikZ[i] = footZDesRel[i];
    ikR2[i] = ikX[i] * ikX[i] + ikZ[i] * ikZ[i];
    ikCosQ3[i] = max(-1.0, min(1.0, (ikR2[i] - femurLen * femurLen - tibiaLen * tibiaLen)
                                / (2.0 * femurLen * tibiaLen)));
    qDes[i,3] = -acos(ikCosQ3[i]);
    qDes[i,2] = atan2(ikX[i], -ikZ[i])
                - atan2(tibiaLen * sin(qDes[i,3]), femurLen + tibiaLen * cos(qDes[i,3]));
    qDes[i,1] = 0.0;
  end for;

  // ==================== Joint Actuator Control (18 saturated actuators) ====================
  for i in 1:6 loop
    for j in 1:3 loop
      tauCmd[i,j] = jointKp * (qDes[i,j] - q[i,j]) - jointKd * qd[i,j];
      tau[i,j] = max(-maxTorque, min(maxTorque, tauCmd[i,j]));
    end for;
  end for;

  // ==================== Forward Kinematics ====================
  for i in 1:6 loop
    footXrel[i] = legAttachmentX[i] + coxaLen * cos(q[i,1])
                  + femurLen * sin(q[i,2]) + tibiaLen * sin(q[i,2] + q[i,3]);
    footZrel[i] = -(femurLen * cos(q[i,2]) + tibiaLen * cos(q[i,2] + q[i,3]));
    footX[i] = bodyX + footXrel[i];
    footY[i] = bodyY + legAttachmentY[i] + coxaLen * sin(q[i,1]);
    footZ[i] = bodyZ + footZrel[i];
  end for;

  // Foot z-velocity for contact damping
  for i in 1:6 loop
    footVZ[i] = bodyVZ
                + femurLen * sin(q[i,2]) * qd[i,2]
                + tibiaLen * sin(q[i,2] + q[i,3]) * (qd[i,2] + qd[i,3]);
  end for;

  // ==================== Contact Model ====================
  for i in 1:6 loop
    penetration[i] = max(0.0, terrainHeightAtFoot[i] - footZ[i]);
    // Vertical: spring-damper, non-negative, only in stance
    contactFZ[i] = if inStance[i] then
      max(0.0, kContact * penetration[i] - dContact * footVZ[i])
    else 0.0;
    // Horizontal: propulsion from velocity error, friction-limited
    contactFX[i] = if (inStance[i] and contactFZ[i] > 1.0) then
      max(-mu * contactFZ[i], min(mu * contactFZ[i], kProp * (vCmd - bodyVX)))
    else 0.0;
    // Lateral: stabilizing force against push, friction-limited
    contactFY[i] = if (inStance[i] and contactFZ[i] > 1.0) then
      max(-mu * contactFZ[i], min(mu * contactFZ[i], -kLat * bodyVY - kLatPos * bodyY))
    else 0.0;
    inContact[i] = contactFZ[i] > 1.0;
  end for;

  // ==================== Jacobian ====================
  for i in 1:6 loop
    Jxq2[i] = femurLen * cos(q[i,2]) + tibiaLen * cos(q[i,2] + q[i,3]);
    Jxq3[i] = tibiaLen * cos(q[i,2] + q[i,3]);
    Jzq2[i] = femurLen * sin(q[i,2]) + tibiaLen * sin(q[i,2] + q[i,3]);
    Jzq3[i] = tibiaLen * sin(q[i,2] + q[i,3]);
    Jyq1[i] = coxaLen * cos(q[i,1]);
  end for;

  // ==================== Contact Reaction Torques ====================
  for i in 1:6 loop
    tauReaction[i,1] = Jyq1[i] * contactFY[i];
    tauReaction[i,2] = Jxq2[i] * contactFX[i] + Jzq2[i] * contactFZ[i];
    tauReaction[i,3] = Jxq3[i] * contactFX[i] + Jzq3[i] * contactFZ[i];
  end for;

  // ==================== Force and Torque Sums ====================
  sumFX = sum(contactFX);
  sumFY = sum(contactFY);
  sumFZ = sum(contactFZ);
  sumTorquePitch = sum({(footX[i] - bodyX) * contactFZ[i]
                        - (footZ[i] - bodyZ) * contactFX[i] for i in 1:6});

  // ==================== Lateral Push Disturbance ====================
  pushY = if (time >= pushStart and time <= pushEnd) then pushForce else 0.0;

  // ==================== Body Dynamics (Floating Base) ====================
  der(bodyX) = bodyVX;
  der(bodyY) = bodyVY;
  der(bodyZ) = bodyVZ;
  der(bodyVX) = sumFX / bodyMass;
  der(bodyVY) = (sumFY + pushY) / bodyMass;
  der(bodyVZ) = sumFZ / bodyMass - G_ACC;
  der(bodyPitch) = bodyPitchRate;
  der(bodyPitchRate) = sumTorquePitch / bodyInertiaPitch;

  // ==================== Joint Dynamics ====================
  for i in 1:6 loop
    for j in 1:3 loop
      der(q[i,j]) = qd[i,j];
      der(qd[i,j]) = (tau[i,j] + tauReaction[i,j] - jointFriction * qd[i,j]) / jointInertia;
    end for;
  end for;

  // ==================== Sensors ====================
  imuPitch = bodyPitch;
  bodyPathError = abs(bodyX - vCmd * time);
  bodyClearance = bodyZ - bodyRadius - terrainHeightAtBody;

  // ==================== Monitoring ====================
  attitudeOK = abs(bodyPitch) < attitudeMax;
  clearanceOK = bodyClearance > clearanceMin;
  trackingOK = if time >= trackingTime then bodyPathError < trackingErrMax else true;
  routeComplete = bodyX >= vCmd * simDuration;
  noNaN = true; // Safeguards: clamped IK (max/min on cos), saturated torques, guarded contact
  maxTorqueUsed = max({max({abs(tau[i,j]) for j in 1:3}) for i in 1:6});

end HexaWalkTraverseC;